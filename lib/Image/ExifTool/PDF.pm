#------------------------------------------------------------------------------
# File:         PDF.pm
#
# Description:  Read PDF meta information
#
# Revisions:    07/11/2005 - P. Harvey Created
#               07/25/2005 - P. Harvey Add support for encrypted documents
#
# References:   1) http://www.adobe.com/devnet/pdf/pdf_reference.html
#               2) http://search.cpan.org/dist/Crypt-RC4/
#               3) http://www.adobe.com/devnet/acrobat/pdfs/PDF32000_2008.pdf
#               4) http://www.adobe.com/content/dam/Adobe/en/devnet/pdf/pdfs/adobe_supplement_iso32000.pdf
#               5) http://tools.ietf.org/search/rfc3454
#               6) http://www.armware.dk/RFC/rfc/rfc4013.html
#------------------------------------------------------------------------------

package Image::ExifTool::PDF;

use strict;
use vars qw($VERSION $AUTOLOAD $lastFetched);
use Image::ExifTool qw(:DataAccess :Utils);
require Exporter;

$VERSION = '1.61';

sub FetchObject($$$$);
sub ExtractObject($$;$$);
sub ReadToNested($;$);
sub ProcessDict($$$$;$$);
sub ProcessAcroForm($$$$;$$);
sub ExpandArray($);
sub ReadPDFValue($);
sub CheckPDF($$$);

# $lastFetched - last fetched object reference (used for decryption)
#                (undefined if fetched object was already decrypted, eg. object from stream)

my $cryptInfo;      # encryption object reference (plus additional information)
my $cryptString;    # flag that strings are encrypted
my $cryptStream;    # flag that streams are encrypted
my $lastOffset;     # last fetched object offset
my %streamObjs;     # hash of stream objects
my %fetched;        # dicts fetched in verbose mode (to avoid cyclical recursion)
my $pdfVer;         # version of PDF file being processed (from header)

# filters supported in DecodeStream()
my %supportedFilter = (
    '/FlateDecode' => 1,
    '/Crypt' => 1,
    '/Identity' => 1,  # (not filtered)
    '/DCTDecode' => 1, # (JPEG image - not filtered)
    '/JPXDecode' => 1, # (Jpeg2000 image - not filtered)
    '/LZWDecode' => 1, # (usually a bitmapped image)
    '/ASCIIHexDecode' => 1,
    '/ASCII85Decode' => 1,
    # other standard filters that we currently don't support
    #'/JBIG2Decode' => 0, # (JBIG2 image format not supported)
    #'/CCITTFaxDecode' => 0,
    #'/RunLengthDecode' => 0,
);

# tags in main PDF directories
%Image::ExifTool::PDF::Main = (
    GROUPS => { 2 => 'Document' },
    VARS => { CAPTURE => ['Main','Prev'] },
    Info => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Info' },
        # Adobe Acrobat 10.1.5 will create a duplicate Info dictionary with
        # a different object number when metadata is edited.  This flag
        # is part of a patch to ignore this duplicate information (unless
        # the IgnoreMinorErrors option is used)
        IgnoreDuplicates => 1,
    },
    Root => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Root' },
    },
    Encrypt => {
        NoProcess => 1, # don't process normally (processed in advance)
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Encrypt' },
    },
    _linearized => {
        Name => 'Linearized',
        Notes => 'flag set if document is linearized for fast web display; not a real Tag ID',
        PrintConv => { 'true' => 'Yes', 'false' => 'No' },
    },
);

# tags in PDF Info dictionary
%Image::ExifTool::PDF::Info = (
    GROUPS => { 2 => 'Document' },
    VARS => { CAPTURE => ['Info'] },
    EXTRACT_UNKNOWN => 1, # extract all unknown tags in this directory
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    CHECK_PROC => \&CheckPDF,
    WRITABLE => 'string',
    # set PRIORITY to 0 so most recent Info dictionary takes precedence
    # (Acrobat Pro bug? doesn't use same object/generation number for
    #  new Info dictionary when doing incremental update)
    PRIORITY => 0,
    NOTES => q{
        As well as the tags listed below, the PDF specification allows for
        user-defined tags to exist in the Info dictionary.  These tags, which should
        have corresponding XMP-pdfx entries in the XMP of the PDF XML Metadata
        object, are also extracted by ExifTool.

        B<Writable> specifies the value format, and may be C<string>, C<date>,
        C<integer>, C<real>, C<boolean> or C<name> for PDF tags.
    },
    Title       => { },
    Author      => { Groups => { 2 => 'Author' } },
    Subject     => { },
    Keywords    => {
        List => 'string',  # this is a string list
        Notes => q{
            stored as a string but treated as a comma- or semicolon-separated list of
            items when reading if the string contains commas or semicolons, whichever is
            more numerous, otherwise it is treated a space-separated list of items.  The
            list behaviour may be defeated by setting the API NoPDFList option.  Written
            as a comma-separated string.  Note that the corresponding XMP-pdf:Keywords
            tag is not treated as a list, so the NoPDFList option should be used when
            copying between these two.
        },
    },
    Creator     => { },
    Producer    => { },
    CreationDate => {
        Name => 'CreateDate',
        Writable => 'date',
        PDF2 => 1,  # not deprecated in PDF 2.0
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    ModDate => {
        Name => 'ModifyDate',
        Writable => 'date',
        PDF2 => 1,  # not deprecated in PDF 2.0
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    SourceModified => {
        Name => 'SourceModified',
        Writable => 'date',
        PDF2 => 1,
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    Trapped => {
        Protected => 1,
        # remove leading '/' from '/True' or '/False'
        ValueConv => '$val=~s{^/}{}; $val',
        ValueConvInv => '"/$val"',
    },
    'AAPL:Keywords' => { #PH
        Name => 'AppleKeywords',
        List => 'array', # this is an array of values
        Notes => q{
            keywords written by Apple utilities, although they seem to use PDF:Keywords
            when reading
        },
    },
);

# tags in the PDF Root document catalog
%Image::ExifTool::PDF::Root = (
    GROUPS => { 2 => 'Document' },
    # note: can't capture previous versions of Root since they are not parsed
    VARS => { CAPTURE => ['Root'] },
    NOTES => 'This is the PDF document catalog.',
    MarkInfo => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::MarkInfo' },
    },
    Metadata => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Metadata' },
    },
    Pages => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Pages' },
    },
    Perms => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Perms' },
    },
    AcroForm => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::AcroForm' },
    },
    AF => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::AF' },
    },
    Lang       => 'Language',
    PageLayout => { },
    PageMode   => { },
    Version    => {
        Name => 'PDFVersion',
        RawConv => '$$self{PDFVersion} = $val if $$self{PDFVersion} < $val; $val',
    },
);

# tags extracted from the PDF Encrypt dictionary
%Image::ExifTool::PDF::Encrypt = (
    GROUPS => { 2 => 'Document' },
    NOTES => 'Tags extracted from the document Encrypt dictionary.',
    Filter => {
        Name => 'Encryption',
        Notes => q{
            extracted value is actually a combination of the Filter, SubFilter, V, R and
            Length information from the Encrypt dictionary
        },
    },
    P => {
        Name => 'UserAccess',
        ValueConv => '$val & 0x0f3c',  # ignore reserved bits
        PrintConvColumns => 2,
        PrintConv => { BITMASK => {
            2 => 'Print',
            3 => 'Modify',
            4 => 'Copy',
            5 => 'Annotate',
            8 => 'Fill forms',
            9 => 'Extract',
            10 => 'Assemble',
            11 => 'Print high-res',
        }},
    },
);

# tags in PDF Pages dictionary
%Image::ExifTool::PDF::Pages = (
    GROUPS => { 2 => 'Document' },
    Count => 'PageCount',
    Kids => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Kids' },
    },
);

# tags in PDF Perms dictionary
%Image::ExifTool::PDF::Perms = (
    NOTES => 'Additional document permissions imposed by digital signatures.',
    DocMDP => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Signature' },
    },
    FieldMDP => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Signature' },
    },
    UR3 => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Signature' },
    },
);

# tags in PDF Perms dictionary
%Image::ExifTool::PDF::AcroForm = (
    PROCESS_PROC => \&ProcessAcroForm,
    _has_xfa => {
        Name => 'HasXFA',
        Notes => q{
            this tag is defined if a document contains form fields, and is true if it
            uses XML Forms Architecture; not a real Tag ID
        },
        PrintConv => { 'true' => 'Yes', 'false' => 'No' },
    },
);

# tags extracted from AF dictionary
%Image::ExifTool::PDF::AF = (
    PROCESS_PROC => \&ProcessAF,
    NOTES => 'Processed only for C2PA information if AFRelationship is "/C2PA_Manifest".',
    EF => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::EF' },
    },
);

# tags extracted from EF dictionary
%Image::ExifTool::PDF::EF = (
    F => {
        Name => 'F_', # (don't want single-letter tag names)
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::F' },
    },
);

# tags extracted from F dictionary
%Image::ExifTool::PDF::F = (
    NOTES => 'C2PA JUMBF metadata extracted from "/C2PA_Manifest" file.',
    _stream => {
        Name => 'JUMBF',
        Condition => '$$self{AFRelationship} eq "/C2PA_Manifest"',
        SubDirectory => {
            TagTable  => 'Image::ExifTool::Jpeg2000::Main',
            DirName   => 'JUMBF',
            ByteOrder => 'BigEndian',
        },
    },
);

# tags in PDF Kids dictionary
%Image::ExifTool::PDF::Kids = (
    Metadata => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Metadata' },
    },
    PieceInfo => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::PieceInfo' },
    },
    Resources => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Resources' },
    },
    Kids => {
        Condition => '$self->Options("ExtractEmbedded")',
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Kids' },
    },
);

# tags in PDF Resources dictionary
%Image::ExifTool::PDF::Resources = (
    ColorSpace => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::ColorSpace' },
    },
    XObject => {
        Condition => '$self->Options("ExtractEmbedded")',
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::XObject' },
    },
    Properties => {
        Condition => '$self->Options("ExtractEmbedded")',
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Properties' },
    },
);

# tags in PDF ColorSpace dictionary
%Image::ExifTool::PDF::ColorSpace = (
    DefaultRGB => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::DefaultRGB' },
        ConvertToDict => 1, # (not seen yet, but just in case)
    },
    DefaultCMYK => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::DefaultRGB' },
        # hack: this is stored as an array instead of a dictionary in my
        # sample, so convert to a dictionary to extract the ICCBased element
        ConvertToDict => 1,
    },
    Cs1 => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::DefaultRGB' },
        ConvertToDict => 1, # (just in case)
    },
    CS0 => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::DefaultRGB' },
        ConvertToDict => 1, # (just in case)
    },
);

# tags in PDF DefaultRGB dictionary
%Image::ExifTool::PDF::DefaultRGB = (
    ICCBased => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::ICCBased' },
    },
);

# tags in PDF ICCBased, Cs1 and CS0 dictionaries
%Image::ExifTool::PDF::ICCBased = (
    _stream => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
);

# tags in PDF XObject dictionary (parsed only if ExtractEmbedded is enabled)
%Image::ExifTool::PDF::XObject = (
    EXTRACT_UNKNOWN => 0,   # extract known but numbered tags (Im1, Im2, etc)
    Im => {
        Notes => q{
            the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option enables information to be extracted from these
            embedded images
        },
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Im' },
    },
);

# tags in PDF Im# dictionary
%Image::ExifTool::PDF::Im = (
    NOTES => q{
        Information extracted from embedded images with the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option.
        The EmbeddedImage and its metadata are extracted only for JPEG and Jpeg2000
        image formats.
    },
    Width => 'EmbeddedImageWidth',
    Height => 'EmbeddedImageHeight',
    Filter => { Name => 'EmbeddedImageFilter', List => 1 },
    ColorSpace => {
        Name => 'EmbeddedImageColorSpace',
        List => 1,
        RawConv => 'ref $val ? undef : $val', # (ignore color space data)
    },
    Image_stream => {
        Name => 'EmbeddedImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
);

# tags in PDF Properties dictionary
%Image::ExifTool::PDF::Properties = (
    EXTRACT_UNKNOWN => 0,   # extract known but numbered tags (MC0, MC1, etc)
    MC => {
        Notes => q{
            the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option enables information to be extracted from these
            embedded metadata dictionaries
        },
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::MC' },
    }
);

# tags in PDF MC# dictionary
%Image::ExifTool::PDF::MC = (
    Metadata => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Metadata' },
    }
);

# tags in PDF PieceInfo dictionary
%Image::ExifTool::PDF::PieceInfo = (
    AdobePhotoshop => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::AdobePhotoshop' },
    },
    Illustrator => {
        # assume this is an illustrator file if it contains this directory
        # and doesn't have a ".PDF" extension
        Condition => q{
            $self->OverrideFileType("AI") unless $$self{FILE_EXT} and $$self{FILE_EXT} eq 'PDF';
            return 1;
        },
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Illustrator' },
    },
);

# tags in PDF AdobePhotoshop dictionary
%Image::ExifTool::PDF::AdobePhotoshop = (
    Private => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Private' },
    },
);

# tags in PDF Illustrator dictionary
%Image::ExifTool::PDF::Illustrator = (
    Private => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::AIPrivate' },
    },
);

# tags in PDF Private dictionary
%Image::ExifTool::PDF::Private = (
    ImageResources => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::ImageResources' },
    },
);

# tags in PDF AI Private dictionary
%Image::ExifTool::PDF::AIPrivate = (
    GROUPS => { 2 => 'Document' },
    EXTRACT_UNKNOWN => 0,   # extract known but numbered tags
    AIMetaData => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::AIMetaData' },
    },
    AIPrivateData => {
        Notes => q{
            the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option enables information to be extracted from embedded
            PostScript documents in the AIPrivateData# and AIPDFPrivateData# streams
        },
        JoinStreams => 1,   # join streams from numbered tags and process as one
        SubDirectory => { TagTable => 'Image::ExifTool::PostScript::Main' },
    },
    AIPDFPrivateData => {
        JoinStreams => 1,   # join streams from numbered tags and process as one
        SubDirectory => { TagTable => 'Image::ExifTool::PostScript::Main' },
    },
    RoundTripVersion => { },
    ContainerVersion => { },
    CreatorVersion => { },
);

# tags in PDF AIMetaData dictionary
%Image::ExifTool::PDF::AIMetaData = (
    _stream => {
        Name => 'AIStream',
        SubDirectory => { TagTable => 'Image::ExifTool::PostScript::Main' },
    },
);

# tags in PDF ImageResources dictionary
%Image::ExifTool::PDF::ImageResources = (
    _stream => {
        Name => 'PhotoshopStream',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::Main' },
    },
);

# tags in PDF MarkInfo dictionary
%Image::ExifTool::PDF::MarkInfo = (
    GROUPS => { 2 => 'Document' },
    Marked => {
        Name => 'TaggedPDF',
        Notes => "not a Tagged PDF if this tag is missing",
        PrintConv => { 'true' => 'Yes', 'false' => 'No' },
    },
);

# tags in PDF Metadata dictionary
%Image::ExifTool::PDF::Metadata = (
    GROUPS => { 2 => 'Document' },
    XML_stream => { # this is the stream for a Subtype /XML dictionary (not a real tag)
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
);

# tags in PDF signature directories (DocMDP, FieldMDP or UR3)
%Image::ExifTool::PDF::Signature = (
    GROUPS => { 2 => 'Document' },
    ContactInfo => 'SignerContactInfo',
    Location => 'SigningLocation',
    M => {
        Name => 'SigningDate',
        Format => 'date',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Name     => 'SigningAuthority',
    Reason   => 'SigningReason',
    Reference => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::Reference' },
    },
    Prop_AuthTime => {
        Name => 'AuthenticationTime',
        PrintConv => 'ConvertTimeSpan($val) . " ago"',
    },
    Prop_AuthType => 'AuthenticationType',
);

# tags in PDF Reference dictionary
%Image::ExifTool::PDF::Reference = (
    TransformParams => {
        SubDirectory => { TagTable => 'Image::ExifTool::PDF::TransformParams' },
    },
);

# tags in PDF TransformParams dictionary
%Image::ExifTool::PDF::TransformParams = (
    GROUPS => { 2 => 'Document' },
    Annots => {
        Name => 'AnnotationUsageRights',
        Notes => q{
            possible values are Create, Delete, Modify, Copy, Import and Export;
            additional values for UR3 signatures are Online and SummaryView
        },
        List => 1,
    },
    Document => {
        Name => 'DocumentUsageRights',
        Notes => 'only possible value is FullSave',
        List => 1,
    },
    Form => {
        Name => 'FormUsageRights',
        Notes => q{
            possible values are FillIn, Import, Export, SubmitStandalone and
            SpawnTemplate; additional values for UR3 signatures are BarcodePlaintext and
            Online
        },
        List => 1,
    },
    FormEX => {
        Name => 'FormExtraUsageRights',
        Notes => 'UR signatures only; only possible value is BarcodePlaintext',
        List => 1,
    },
    Signature => {
        Name => 'SignatureUsageRights',
        Notes => 'only possible value is Modify',
        List => 1,
    },
    EF => {
        Name => 'EmbeddedFileUsageRights',
        Notes => 'possible values are Create, Delete, Modify and Import',
        List => 1,
    },
    Msg => 'UsageRightsMessage',
    P => {
        Name => 'ModificationPermissions',
        Notes => q{
            1-3 for DocMDP signatures, default 2; true/false for UR3 signatures, default
            false
        },
        PrintConv => {
            1 => 'No changes permitted',
            2 => 'Fill forms, Create page templates, Sign',
            3 => 'Fill forms, Create page templates, Sign, Create/Delete/Edit annotations',
            'true' => 'Restrict all applications to reader permissions',
            'false' => 'Do not restrict applications to reader permissions',
        },
    },
    Action => {
        Name => 'FieldPermissions',
        Notes => 'FieldMDP signatures only',
        PrintConv => {
            'All' => 'Disallow changes to all form fields',
            'Include' => 'Disallow changes to specified form fields',
            'Exclude' => 'Allow changes to specified form fields',
        },
    },
    Fields => {
        Notes => 'FieldMDP signatures only',
        Name => 'FormFields',
        List => 1,
    },
);

# unknown tags for use in verbose option
%Image::ExifTool::PDF::Unknown = (
    GROUPS => { 2 => 'Unknown' },
);

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Convert from PDF to EXIF-style date/time
# Inputs: 0) PDF date/time string (D:YYYYmmddHHMMSS+HH'MM')
# Returns: EXIF date string (YYYY:mm:dd HH:MM:SS+HH:MM)
sub ConvertPDFDate($)
{
    my $date = shift;
    # remove optional 'D:' prefix
    $date =~ s/^D://;
    # fill in default values if necessary
    #              YYYYmmddHHMMSS
    my $default = '00000101000000';
    if (length $date < length $default) {
        $date .= substr($default, length $date);
    }
    $date =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(.*)/ or return $date;
    $date = "$1:$2:$3 $4:$5:$6";
    if ($7) {
        my $tz = $7;
        if ($tz =~ /^\s*Z/i) {
            # ignore any "HH'mm'" after the Z (OS X 10.6 does this)
            $date .= 'Z';
        # tolerate some improper formatting in timezone specification
        } elsif ($tz =~ /^\s*([-+])\s*(\d+)[': ]+(\d*)/) {
            $date .= $1 . $2 . ':' . ($3 || '00');
        }
    }
    return $date;
}

#------------------------------------------------------------------------------
# Locate any object in the XRef tables (including compressed objects)
# Inputs: 0) XRef reference, 1) object reference string (or free object number)
# Returns: offset to object in file or compressed object reference string,
#          0 if object is free, or undefined on error
sub LocateAnyObject($$)
{
    my ($xref, $ref) = @_;
    return undef unless $xref;
    return $$xref{$ref} if exists $$xref{$ref};
    # get the object number
    return undef unless $ref =~ /^(\d+)/;
    my $objNum = $1;
    # return 0 if the object number has been reused (old object is free)
    return 0 if defined $$xref{$objNum};
#
# scan our XRef stream dictionaries for this object
#
    return undef unless $$xref{dicts};
    my $dict;
    foreach $dict (@{$$xref{dicts}}) {
        # quick check to see if the object is in the range for this xref stream
        next if $objNum >= $$dict{Size};
        my $index = $$dict{Index};
        next if $objNum < $$index[0];
        # scan the tables for the specified object
        my $size = $$dict{_entry_size};
        my $num = scalar(@$index) / 2;
        my $tot = 0;
        my $i;
        for ($i=0; $i<$num; ++$i) {
            my $start = $$index[$i*2];
            my $count = $$index[$i*2+1];
            # table is in ascending order, so quit if we have passed the object
            last if $objNum < $start;
            if ($objNum < $start + $count) {
                my $offset = $size * ($objNum - $start + $tot);
                last if $offset + $size > length $$dict{_stream};
                my @c = unpack("x$offset C$size", $$dict{_stream});
                # extract values from this table entry
                # (can be 1, 2, 3, 4, etc.. bytes per value)
                my (@t, $j, $k);
                my $w = $$dict{W};
                for ($j=0; $j<3; ++$j) {
                    # use default value if W entry is 0 (as per spec)
                    # - 0th element defaults to 1, others default to 0
                    $$w[$j] or $t[$j] = ($j ? 0 : 1), next;
                    $t[$j] = shift(@c);
                    for ($k=1; $k < $$w[$j]; ++$k) {
                        $t[$j] = 256 * $t[$j] + shift(@c);
                    }
                }
                # by default, use "o g R" as the xref key
                # (o = object number, g = generation number)
                my $ref2 = "$objNum $t[2] R";
                if ($t[0] == 1) {
                    # normal object reference:
                    # $t[1]=offset of object from start, $t[2]=generation number
                    $$xref{$ref2} = $t[1];
                } elsif ($t[0] == 2) {
                    # compressed object reference:
                    # $t[1]=stream object number, $t[2]=index of object in stream
                    $ref2 = "$objNum 0 R";
                    $$xref{$ref2} = "I$t[2] $t[1] 0 R";
                } elsif ($t[0] == 0) {
                    # free object:
                    # $t[1]=next free object in linked list, $t[2]=generation number
                    $$xref{$ref2} = 0;
                } else {
                    # treat as a null object
                    $$xref{$ref2} = undef;
                }
                $$xref{$objNum} = $t[1];    # remember offsets by object number too
                return $$xref{$ref} if $ref eq $ref2;
                return 0;   # object is free or was reused
            }
            $tot += $count;
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Locate a regular object in the XRef tables (does not include compressed objects)
# Inputs: 0) XRef reference, 1) object reference string (or free object number)
# Returns: offset to object in file, 0 if object is free,
#          or undef on error or if object was compressed
sub LocateObject($$)
{
    my ($xref, $ref) = @_;
    my $offset = LocateAnyObject($xref, $ref);
    return undef if $offset and $offset =~ /^I/;
    return $offset;
}

#------------------------------------------------------------------------------
# Check that the correct object is located at the specified file offset
# Inputs: 0) ExifTool ref, 1) object name, 2) object reference string, 3) file offset
# Returns: first non-blank line at start of object, or undef on error
sub CheckObject($$$$)
{
    my ($et, $tag, $ref, $offset) = @_;
    my ($data, $obj, $dat, $pat);

    my $raf = $$et{RAF};
    $raf->Seek($offset+$$et{PDFBase}, 0) or $et->Warn("Bad $tag offset"), return undef;
    # verify that we are reading the expected object
    ($obj = $ref) =~ s/R/obj/;
    for (;;) {
        $raf->ReadLine($data) or $et->Warn("Error reading $tag data"), return undef;
        last if $data =~ s/^$obj//;
        next if $data =~ /^\s+$/;   # keep reading if this was a blank line
        # handle cases where other whitespace characters are used in the object ID string
        while ($data =~ /^\d+(\s+\d+)?\s*$/) {
            $raf->ReadLine($dat);
            $data .= $dat;
        }
        ($pat = $obj) =~ s/ /\\s+/g;
        unless ($data =~ s/$pat//) {
            $tag = ucfirst $tag;
            $et->Warn("$tag object ($obj) not found at offset $offset");
            return undef;
        }
        last;
    }
    # read the first line of data from the object (ignoring blank lines and comments)
    for (;;) {
        last if $data =~ /\S/ and $data !~ /^\s*%/;
        $raf->ReadLine($data) or $et->Warn("Error reading $tag data"), return undef;
    }
    return $data;
}

#------------------------------------------------------------------------------
# Fetch indirect object from file (from inside a stream if required)
# Inputs: 0) ExifTool object reference, 1) object reference string,
#         2) xref lookup, 3) object name (for warning messages)
# Returns: object data or undefined on error
# Notes: sets $lastFetched to the object reference, or undef if the object
#        was extracted from an encrypted stream
sub FetchObject($$$$)
{
    my ($et, $ref, $xref, $tag) = @_;
    $lastFetched = $ref;    # save this for decoding if necessary
    my $offset = LocateAnyObject($xref, $ref);
    $lastOffset = $offset;
    unless ($offset) {
        $et->Warn("Bad $tag reference") unless defined $offset;
        return undef;
    }
    my ($data, $obj);
    if ($offset =~ s/^I(\d+) //) {
        my $index = $1; # object index in stream
        my ($objNum) = split ' ', $ref; # save original object number
        $ref = $offset; # now a reference to the containing stream object
        $obj = $streamObjs{$ref};
        unless ($obj) {
            # don't try to load the same object stream twice
            return undef if defined $obj;
            $streamObjs{$ref} = '';
            # load the parent object stream
            $obj = FetchObject($et, $ref, $xref, $tag);
            # make sure it contains everything we need
            return undef unless defined $obj and ref($obj) eq 'HASH';
            return undef unless $$obj{First} and $$obj{N};
            return undef unless DecodeStream($et, $obj);
            # add a special '_table' entry to this dictionary which contains
            # the list of object number/offset pairs from the stream header
            my $num = $$obj{N} * 2;
            my @table = split ' ', $$obj{_stream}, $num;
            return undef unless @table == $num;
            # remove everything before first object in stream
            $$obj{_stream} = substr($$obj{_stream}, $$obj{First});
            $table[$num-1] =~ s/^(\d+).*/$1/s;  # trim excess from last number
            $$obj{_table} = \@table;
            # save the object stream so we don't have to re-load it later
            $streamObjs{$ref} = $obj;
        }
        # verify that we have the specified object
        my $i = 2 * $index;
        my $table = $$obj{_table};
        unless ($index < $$obj{N} and $$table[$i] == $objNum) {
            $et->Warn("Bad index for stream object $tag");
            return undef;
        }
        # extract the object at the specified index in the stream
        # (offsets in table are in sequential order, so we can subtract from
        #  the next offset to get the object length)
        $offset = $$table[$i + 1];
        my $len = ($$table[$i + 3] || length($$obj{_stream})) - $offset;
        $data = substr($$obj{_stream}, $offset, $len);
        # avoid re-decrypting data in already decrypted streams
        undef $lastFetched if $cryptStream;
        return ExtractObject($et, \$data);
    }
    # load the start of the object
    $data = CheckObject($et, $tag, $ref, $offset);
    return undef unless defined $data;

    return ExtractObject($et, \$data, $$et{RAF}, $xref);
}

#------------------------------------------------------------------------------
# Convert PDF value to something readable
# Inputs: 0) PDF object data
# Returns: converted object
sub ReadPDFValue($)
{
    my $str = shift;
    # decode all strings in an array
    if (ref $str eq 'ARRAY') {
        # create new list to not alter the original data when rewriting
        my ($val, @vals);
        foreach $val (@$str) {
            push @vals, ReadPDFValue($val);
        }
        return \@vals;
    }
    length $str or return $str;
    my $delim = substr($str, 0, 1);
    if ($delim eq '(') {    # literal string
        $str = $1 if $str =~ /^.*?\((.*)\)/s;   # remove brackets
        # decode escape sequences in literal strings
        while ($str =~ /\\(.)/sg) {
            my $n = pos($str) - 2;
            my $c = $1;
            my $r;
            if ($c =~ /[0-7]/) {
                # get up to 2 more octal digits
                $c .= $1 if $str =~ /\G([0-7]{1,2})/g;
                # convert octal escape code
                $r = chr(oct($c) & 0xff);
            } elsif ($c eq "\x0d") {
                # the string is continued if the line ends with '\'
                # (also remove "\x0d\x0a")
                $c .= $1 if $str =~ /\G(\x0a)/g;
                $r = '';
            } elsif ($c eq "\x0a") {
                $r = '';
            } else {
                # convert escaped characters
                ($r = $c) =~ tr/nrtbf/\n\r\t\b\f/;
            }
            substr($str, $n, length($c)+1) = $r;
            # continue search after this character
            pos($str) = $n + length($r);
        }
        Crypt(\$str, $lastFetched) if $cryptString;
    } elsif ($delim eq '<') {   # hex string
        # decode hex data
        $str =~ tr/0-9A-Fa-f//dc;
        $str .= '0' if length($str) & 0x01; # (by the spec)
        $str = pack('H*', $str);
        Crypt(\$str, $lastFetched) if $cryptString;
    } elsif ($delim eq '/') {   # name
        $str = substr($str, 1);
        # convert escape codes (PDF 1.2 or later)
        $str =~ s/#([0-9a-f]{2})/chr(hex($1))/sgei if $pdfVer >= 1.2;
    }
    return $str;
}

#------------------------------------------------------------------------------
# Extract PDF object from combination of buffered data and file
# Inputs: 0) ExifTool object reference, 1) data reference,
#         2) optional raf reference, 3) optional xref table
# Returns: converted PDF object or undef on error
#          a) dictionary object --> hash reference
#          b) array object --> array reference
#          c) indirect reference --> scalar reference
#          d) string, name, integer, boolean, null --> scalar value
# - updates $$dataPt on return to contain unused data
# - creates two bogus entries ('_stream' and '_tags') in dictionaries to represent
#   the stream data and a list of the tags (not including '_stream' and '_tags')
#   in their original order
sub ExtractObject($$;$$)
{
    my ($et, $dataPt, $raf, $xref) = @_;
    my (@tags, $data, $objData);
    my $dict = { };
    my $delim;

    for (;;) {
        if ($$dataPt =~ /^\s*(<{1,2}|\[|\()/s) {
            $delim = $1;
            $$dataPt =~ s/^\s+//;   # remove leading white space
            $objData = ReadToNested($dataPt, $raf);
            return undef unless defined $objData;
            last;
        } elsif ($$dataPt =~ s{^\s*(\S[^[(/<>\s]*)\s*}{}s) {
#
# extract boolean, numerical, string, name, null object or indirect reference
#
            $objData = $1;
            # look for an indirect reference
            if ($objData =~ /^\d+$/ and $$dataPt =~ s/^(\d+)\s+R//s) {
                $objData .= "$1 R";
                $objData = \$objData;   # return scalar reference
            }
            return $objData;    # return simple scalar or scalar reference
        }
        $raf and $raf->ReadLine($data) or return undef;
        $$dataPt .= $data;
    }
#
# return literal string or hex string without parsing
#
    if ($delim eq '(' or $delim eq '<') {
        return $objData;
#
# extract array
#
    } elsif ($delim eq '[') {
        $objData =~ /^.*?\[(.*)\]/s or return undef;
        my $data = $1;    # brackets removed
        my @list;
        for (;;) {
            last unless $data =~ m{\s*(\S[^[(/<>\s]*)}sg;
            my $val = $1;
            if ($val =~ /^(<{1,2}|\[|\()/) {
                my $pos = pos($data) - length($val);
                # nested dict, array, literal string or hex string
                my $buff = substr($data, $pos);
                $val = ReadToNested(\$buff);
                last unless defined $val;
                pos($data) = $pos + length($val);
                $val = ExtractObject($et, \$val);
            } elsif ($val =~ /^\d/) {
                my $pos = pos($data);
                if ($data =~ /\G\s+(\d+)\s+R/g) {
                    $val = \ "$val $1 R";   # make a reference
                } else {
                    pos($data) = $pos;
                }
            }
            push @list, $val;
        }
        return \@list;
    }
#
# extract dictionary
#
    # Note: entries are not necessarily separated by whitespace (doh!)
    # eg) "/Tag/Name", "/Tag(string)", "/Tag[array]", etc are legal!
    # Also, they may be separated by a comment (eg. "/Tag%comment\nValue"),
    # but comments have already been removed
    while ($objData =~ m{(\s*)/([^/[\]()<>{}\s]+)\s*(\S[^[(/<>\s]*)}sg) {
        my $tag = $2;
        my $val = $3;
        if ($val =~ /^(<{1,2}|\[|\()/) {
            # nested dict, array, literal string or hex string
            $objData = substr($objData, pos($objData)-length($val));
            $val = ReadToNested(\$objData, $raf);
            last unless defined $val;
            $val = ExtractObject($et, \$val);
            pos($objData) = 0;
        } elsif ($val =~ /^\d/) {
            my $pos = pos($objData);
            if ($objData =~ /\G\s+(\d+)\s+R/sg) {
                $val = \ "$val $1 R";   # make a reference
            } else {
                pos($objData) = $pos;
            }
        }
        if ($$dict{$tag}) {
            # duplicate dictionary entries are not allowed
            $et->Warn("Duplicate '${tag}' entry in dictionary (ignored)");
        } else {
            # save the entry
            push @tags, $tag;
            $$dict{$tag} = $val;
        }
    }
    return undef unless @tags;
    $$dict{_tags} = \@tags;
    return $dict unless $raf;   # direct objects can not have streams
#
# extract the stream object
#
    # dictionary must specify stream Length
    my $length = $$dict{Length} or return $dict;
    if (ref $length) {
        $length = $$length;
        my $oldpos = $raf->Tell();
        # get the location of the object specifying the length
        # (compressed objects are not allowed)
        my $offset = LocateObject($xref, $length) or return $dict;
        $offset or $et->Warn('Bad stream Length object'), return $dict;
        $data = CheckObject($et, 'stream Length', $length, $offset);
        defined $data or return $dict;
        $data =~ /^\s*(\d+)/ or $et->Warn('Stream Length not found'), return $dict;
        $length = $1;
        $raf->Seek($oldpos, 0); # restore position to start of stream
    }
    # extract the trailing stream data
    for (;;) {
        # find the stream token
        if ($$dataPt =~ /(\S+)/) {
            last unless $1 eq 'stream';
            # read an extra line because it may contain our \x0a
            $$dataPt .= $data if $raf->ReadLine($data);
            # remove our stream header
            $$dataPt =~ s/^\s*stream(\x0a|\x0d\x0a)//s;
            my $more = $length - length($$dataPt);
            if ($more > 0) {
                unless ($raf->Read($data, $more) == $more) {
                    $et->Warn('Error reading stream data');
                    $$dataPt = '';
                    return $dict;
                }
                $$dict{_stream} = $$dataPt . $data;
                $$dataPt = '';
            } elsif ($more < 0) {
                $$dict{_stream} = substr($$dataPt, 0, $length);
                $$dataPt = substr($$dataPt, $length);
            } else {
                $$dict{_stream} = $$dataPt;
                $$dataPt = '';
            }
            last;
        }
        $raf->ReadLine($data) or last;
        $$dataPt .= $data;
    }
    return $dict;
}

#------------------------------------------------------------------------------
# Read to nested delimiter
# Inputs: 0) data reference, 1) optional raf reference
# Returns: data up to and including matching delimiter (or undef on error)
# - updates data reference with trailing data
# - unescapes characters in literal strings
my %closingDelim = (    # lookup for matching delimiter
    '(' => ')',
    '[' => ']',
    '<' => '>',
   '<<' => '>>',
);
sub ReadToNested($;$)
{
    my ($dataPt, $raf) = @_;
    my @delim = ('');   # closing delimiter list, most deeply nested first
    pos($$dataPt) = 0;  # begin at start of data
    for (;;) {
        unless ($$dataPt =~ /(\\*)(\(|\)|<{1,2}|>{1,2}|\[|\]|%)/g) {
            # must read some more data
            my $buff;
            last unless $raf and $raf->ReadLine($buff);
            $$dataPt .= $buff;
            pos($$dataPt) = length($$dataPt) - length($buff);
            next;
        }
        # are we in a literal string?
        if ($delim[0] eq ')') {
            # ignore escaped delimiters (preceded by odd number of \'s)
            next if length($1) & 0x01;
            # ignore all delimiters but unescaped braces
            next unless $2 eq '(' or $2 eq ')';
        } elsif ($2 eq '%') {
            # ignore the comment
            my $pos = pos($$dataPt) - 1;
            # remove everything from '%' up to but not including newline
            $$dataPt =~ /.*/g;
            my $end = pos($$dataPt);
            $$dataPt = substr($$dataPt, 0, $pos) . substr($$dataPt, $end);
            pos($$dataPt) = $pos;
            next;
        }
        if ($closingDelim{$2}) {
            # push the corresponding closing delimiter
            unshift @delim, $closingDelim{$2};
            next;
        }
        unless ($2 eq $delim[0]) {
            # handle the case where we find a ">>>" and interpret it
            # as ">> >" instead of "> >>"
            next unless $2 eq '>>' and $delim[0] eq '>';
            pos($$dataPt) = pos($$dataPt) - 1;
        }
        shift @delim;               # remove from nesting list
        next if $delim[0];          # keep going if we have more nested delimiters
        my $pos = pos($$dataPt);
        my $buff = substr($$dataPt, 0, $pos);
        $$dataPt = substr($$dataPt, $pos);
        return $buff;   # success!
    }
    return undef;   # didn't find matching delimiter
}

#------------------------------------------------------------------------------
# Decode LZW-encoded data (ref 1)
# Inputs: 0) data reference
# Returns: true on success and data is decoded, or false and data is untouched
sub DecodeLZW($)
{
    my $dataPt = shift;
    return 0 if length $$dataPt < 4;
    my @lzw = (map(chr, 0..255), undef, undef); # LZW code table
    my $mask = 0x01ff;  # mask for least-significant 9 bits
    my @dat = unpack 'n*', $$dataPt . "\0";
    my $word = ($dat[0] << 16) | $dat[1];
    my ($bit, $pos, $bits, $out) = (0, 2, 9, '');
    my $lastVal;
    for (;;) {
        # bits are packed MSB first in PDF LZW (the PDF spec doesn't mention this)
        my $shift = 32 - ($bit + $bits);
        if ($shift < 0) {
            return 0 if $pos >= @dat; # missing EOD marker
            $word = (($word & 0xffff) << 16) | $dat[$pos++]; # read next word
            $bit -= 16;
            $shift += 16;
        };
        my $code = ($word >> $shift) & $mask;
        $bit += $bits;
        my $val = $lzw[$code];
        if (defined $val) {
            # store new code as previous sequence plus 1st char of new sequence
            push @lzw, $lastVal . substr($val, 0, 1) if defined $lastVal;
        } elsif ($code == @lzw) { # new code
            return 0 unless defined $lastVal;
            # we are using the code that we are about to generate, so the last
            # character in the new sequence must be the same as the first
            # character in the previous sequence (makes sense if you think about it)
            $val = $lastVal . substr($lastVal, 0, 1);
            push @lzw, $val;
        } elsif ($code == 256) { # clear table
            splice @lzw, 258;
            $bits = 9;
            $mask = 0x1ff;
            undef $lastVal;
            next;
        } elsif ($code == 257) { # EOD marker
            last;   # all done!
        } else {
            return 0;
        }
        $out .= $val;   # add this byte sequence to the output
        # we added a new entry to the LZW table, so we must increase
        # the bit width if necessary, up to a maximum of 12
        @lzw >= $mask and $bits < 12 and ++$bits, $mask |= $mask << 1;
        $lastVal = $val;
    }
    $$dataPt = $out;    # return decompressed data
    return 1;
}

#------------------------------------------------------------------------------
# Decode filtered stream
# Inputs: 0) ExifTool object reference, 1) dictionary reference
# Returns: true if stream has been decoded OK
sub DecodeStream($$)
{
    local $_;
    my ($et, $dict) = @_;

    return 0 unless $$dict{_stream}; # no stream to decode

    # get list of filters
    my (@filters, @decodeParms, $filter);
    if (ref $$dict{Filter} eq 'ARRAY') {
        @filters = @{$$dict{Filter}};
    } elsif (defined $$dict{Filter}) {
        @filters = ($$dict{Filter});
    }
    # be sure we can process all the filters before we take the time to do the decryption
    foreach $filter (@filters) {
        next if $supportedFilter{$filter};
        $et->Warn("Unsupported Filter $filter");
        return 0;
    }
    # apply decryption first if required (and if the default encryption
    # has not been overridden by a Crypt filter. Note: the Crypt filter
    # must be first in the Filter array: ref 3, page 38)
    unless (defined $$dict{_decrypted} or ($filters[0] and $filters[0] eq '/Crypt')) {
        CryptStream($dict, $lastFetched);
    }
    return 1 unless $$dict{Filter};         # Filter entry is mandatory
    return 0 if defined $$dict{_filtered};  # avoid double-filtering
    $$dict{_filtered} = 1;                  # set flag to prevent double-filtering

    # get array of DecodeParms dictionaries
    if (ref $$dict{DecodeParms} eq 'ARRAY') {
        @decodeParms = @{$$dict{DecodeParms}};
    } else {
        @decodeParms = ($$dict{DecodeParms});
    }

    foreach $filter (@filters) {
        my $decodeParms = shift @decodeParms;

        if ($filter eq '/FlateDecode') {
            # make sure we support the predictor (if used) before decoding
            my $pre;
            if (ref $decodeParms eq 'HASH') {
                $pre = $$decodeParms{Predictor};
                if ($pre and $pre ne '1' and $pre ne '12') {
                    $et->Warn("FlateDecode Predictor $pre currently not supported");
                    return 0;
                }
            }
            if (eval { require Compress::Zlib }) {
                my $inflate = Compress::Zlib::inflateInit();
                my ($buff, $stat);
                $inflate and ($buff, $stat) = $inflate->inflate($$dict{_stream});
                if ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                    $$dict{_stream} = $buff;
                } else {
                    $et->Warn('Error inflating stream');
                    return 0;
                }
            } else {
                $et->Warn('Install Compress::Zlib to process filtered streams');
                return 0;
            }
            next unless $pre and $pre eq '12';  # 12 = 'up' prediction

            # apply anti-predictor
            my $cols = $$decodeParms{Columns};
            unless ($cols) {
                # currently only support 'up' prediction
                $et->Warn('No Columns for decoding stream');
                return 0;
            }
            my @bytes = unpack('C*', $$dict{_stream});
            my @pre = (0) x $cols;  # initialize predictor array
            my $buff = '';
            while (@bytes > $cols) {
                unless (($_ = shift @bytes) == 2) {
                    $et->Warn("Unsupported PNG filter $_"); # (yes, PNG)
                    return 0;
                }
                foreach (@pre) {
                    $_ = ($_ + shift(@bytes)) & 0xff;
                }
                $buff .= pack('C*', @pre);
            }
            $$dict{_stream} = $buff;

        } elsif ($filter eq '/Crypt') {

            # (we shouldn't have to check the _decrypted flag since we
            #  already checked the _filtered flag, but what the heck...)
            next if defined $$dict{_decrypted};
            # assume Identity filter (the default) if DecodeParms are missing
            next unless ref $decodeParms eq 'HASH';
            my $name = $$decodeParms{Name};
            next unless defined $name or $name eq 'Identity';
            if ($name ne 'StdCF') {
                $et->Warn("Unsupported Crypt Filter $name");
                return 0;
            }
            unless ($cryptInfo) {
                $et->Warn('Missing Encrypt StdCF entry');
                return 0;
            }
            # decrypt the stream manually because we want to:
            # 1) ignore $cryptStream (StmF) setting
            # 2) ignore EncryptMetadata setting (I can't find mention of how to
            #    reconcile this in the spec., but this would make sense)
            # 3) avoid adding the crypt key extension (ref 3, page 58, Algorithm 1b)
            # 4) set _decrypted flag so we will recrypt according to StmF when
            #    writing (since we don't yet write Filter'd streams)
            Crypt(\$$dict{_stream}, 'none');
            $$dict{_decrypted} = ($cryptStream ? 1 : 0);

        } elsif ($filter eq '/LZWDecode') {

            # make sure we don't have any unsupported decoding parameters
            if (ref $decodeParms eq 'HASH') {
                if ($$decodeParms{Predictor}) {
                    $et->Warn("LZWDecode Predictor $$decodeParms{Predictor} currently not supported");
                    return 0;
                } elsif ($$decodeParms{EarlyChange}) {
                    $et->Warn("LZWDecode EarlyChange currently not supported");
                    return 0;
                }
            }
            unless (DecodeLZW(\$$dict{_stream})) {
                $et->Warn('LZW decompress error');
                return 0;
            }

        } elsif ($filter eq '/ASCIIHexDecode') {

            $$dict{_stream} =~ s/>.*//; # truncate at '>' (end of data mark)
            $$dict{_stream} =~ tr/0-9a-zA-Z//d; # remove illegal characters
            $$dict{_stream} = pack 'H*', $$dict{_stream};

        } elsif ($filter eq '/ASCII85Decode') {

            my ($err, @out, $i);
            my ($n, $val) = (0, 0);
            foreach (split //, $$dict{_stream}) {
                if ($_ ge '!' and $_ le 'u') {;
                    $val = 85 * $val + ord($_) - 33;
                    next unless ++$n == 5;
                } elsif ($_ eq '~') {
                    $n == 1 and $err = 1;   # error to have a single char in the last group of 5
                    for ($i=$n; $i<5; ++$i) { $val *= 85; }
                } elsif ($_ eq 'z') {
                    $n and $err = 2, last;  # error if 'z' isn't the first char
                    $n = 5;
                } else {
                    next if /^\s$/;         # ignore white space
                    $err = 3, last;         # any other character is an error
                }
                $val = unpack('V', pack('N', $val)); # reverse byte order
                while (--$n > 0) {
                    push @out, $val & 0xff;
                    $val >>= 8;
                }
                last if $_ eq '~';
                # (both $n and $val are zero again now)
            }
            $err and $et->Warn("ASCII85Decode error $err");
            $$dict{_stream} = pack('C*', @out);
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Initialize state for RC4 en/decryption (ref 2)
# Inputs: 0) RC4 key string
# Returns: RC4 key hash reference
sub RC4Init($)
{
    my @key = unpack('C*', shift);
    my @state = (0 .. 255);
    my ($i, $j) = (0, 0);
    while ($i < 256) {
        my $st = $state[$i];
        $j = ($j + $st + $key[$i % scalar(@key)]) & 0xff;
        $state[$i++] = $state[$j];
        $state[$j] = $st;
    }
    return { State => \@state, XY => [ 0, 0 ] };
}

#------------------------------------------------------------------------------
# Apply RC4 en/decryption (ref 2)
# Inputs: 0) data reference, 1) RC4 key hash reference or RC4 key string
# - can call this method directly with a key string, or with with the key
#   reference returned by RC4Init
# - RC4 is a symmetric algorithm, so encryption is the same as decryption
sub RC4Crypt($$)
{
    my ($dataPt, $key) = @_;
    $key = RC4Init($key) unless ref $key eq 'HASH';
    my $state = $$key{State};
    my ($x, $y) = @{$$key{XY}};

    my @data = unpack('C*', $$dataPt);
    foreach (@data) {
         $x = ($x + 1) & 0xff;
         my $stx = $$state[$x];
         $y = ($stx + $y) & 0xff;
         my $sty = $$state[$x] = $$state[$y];
         $$state[$y] = $stx;
         $_ ^= $$state[($stx + $sty) & 0xff];
     }
     $$key{XY} = [ $x, $y ];
     $$dataPt = pack('C*', @data);
}

#------------------------------------------------------------------------------
# Update AES cipher with a bit of data
# Inputs: 0) data
# Returns: encrypted data
my $cipherMore;
sub CipherUpdate($)
{
    my $dat = shift;
    my $pos = 0;
    $dat = $cipherMore . $dat if length $dat;
    while ($pos + 16 <= length($dat)) {
        substr($dat,$pos,16) = Image::ExifTool::AES::Cipher(substr($dat,$pos,16));
        $pos += 16;
    }
    if ($pos < length $dat) {
        $cipherMore = substr($dat,$pos);
        $dat = substr($dat,0,$pos);
    } else {
        $cipherMore = '';
    }
    return $dat;
}

#------------------------------------------------------------------------------
# Get encrypted hash
# Inputs: 0) Password, 1) salt, 2) vector, 3) encryption revision
# Returns: hash
sub GetHash($$$$)
{
    my ($password, $salt, $vector, $rev) = @_;

    # return Rev 5 hash
    return Digest::SHA::sha256($password, $salt, $vector) if $rev == 5;

    # compute Rev 6 hardened hash
    # (ref http://code.google.com/p/origami-pdf/source/browse/lib/origami/encryption.rb)
    my $blockSize = 32;
    my $input = Digest::SHA::sha256($password, $salt, $vector) . ("\0" x 32);
    my $key = substr($input, 0, 16);
    my $iv = substr($input, 16, 16);
    my $h;
    my $x = '';
    my $i = 0;
    while ($i < 64 or $i < ord(substr($x,-1,1))+32) {

        my $block = substr($input, 0, $blockSize);
        $x = '';
        Image::ExifTool::AES::Crypt(\$x, $key, $iv, 1);
        $cipherMore = '';

        my ($j, $digest);
        for ($j=0; $j<64; ++$j)  {
            $x = '';
            $x .= CipherUpdate($password) if length $password;
            $x .= CipherUpdate($block);
            $x .= CipherUpdate($vector) if length $vector;
            if ($j == 0) {
                my @a = unpack('C16', $x);
                my $sum = 0;
                $sum += $_ foreach @a;
                # set SHA block size (32, 48 or 64 bytes = SHA-256, 384 or 512)
                $blockSize = 32 + ($sum % 3) * 16;
                $digest = Digest::SHA->new($blockSize * 8);
            }
            $digest->add($x);
        }

        $h = $digest->digest();
        $key = substr($h, 0, 16);
        substr($input,0,16) = $h;
        $iv = substr($h, 16, 16);
        ++$i;
    }
    return substr($h, 0, 32);
}

#------------------------------------------------------------------------------
# Initialize decryption
# Inputs: 0) ExifTool object reference, 1) Encrypt dictionary reference,
#         2) ID from file trailer dictionary
# Returns: error string or undef on success (and sets $cryptInfo)
sub DecryptInit($$$)
{
    local $_;
    my ($et, $encrypt, $id) = @_;

    undef $cryptInfo;
    unless ($encrypt and ref $encrypt eq 'HASH') {
        return 'Error loading Encrypt object';
    }
    my $filt = $$encrypt{Filter};
    unless ($filt and $filt =~ s/^\///) {
        return 'Encrypt dictionary has no Filter!';
    }
    # extract some interesting tags
    my $ver = $$encrypt{V} || 0;
    my $rev = $$encrypt{R} || 0;
    my $enc = "$filt V$ver";
    $enc .= ".$rev" if $filt eq 'Standard';
    $enc .= " ($1)" if $$encrypt{SubFilter} and $$encrypt{SubFilter} =~ /^\/(.*)/;
    $enc .= ' (' . ($$encrypt{Length} || 40) . '-bit)' if $filt eq 'Standard';
    my $tagTablePtr = GetTagTable('Image::ExifTool::PDF::Encrypt');
    $et->HandleTag($tagTablePtr, 'Filter', $enc);
    if ($filt ne 'Standard') {
        return "Encryption filter $filt currently not supported";
    } elsif (not defined $$encrypt{R}) {
        return 'Standard security handler missing revision';
    }
    unless ($$encrypt{O} and $$encrypt{P} and $$encrypt{U}) {
        return 'Incomplete Encrypt specification';
    }
    if ("$ver.$rev" >= 5.6) {
        # apologize for poor performance (AES is a pure Perl implementation)
        $et->Warn('Decryption is very slow for encryption V5.6 or higher', 3);
    }
    $et->HandleTag($tagTablePtr, 'P', $$encrypt{P});

    my %parm;   # optional parameters extracted from Encrypt dictionary

    if ($ver == 1 or $ver == 2) {
        $cryptString = $cryptStream = 1;
    } elsif ($ver == 4 or $ver == 5) {
        # initialize our $cryptString and $cryptStream flags
        foreach ('StrF', 'StmF') {
            my $flagPt = $_ eq 'StrF' ? \$cryptString : \$cryptStream;
            $$flagPt = $$encrypt{$_};
            undef $$flagPt if $$flagPt and $$flagPt eq '/Identity';
            return "Unsupported $_ encryption $$flagPt" if $$flagPt and $$flagPt ne '/StdCF';
        }
        if ($cryptString or $cryptStream) {
            return 'Missing or invalid Encrypt StdCF entry' unless ref $$encrypt{CF} eq 'HASH' and
                ref $$encrypt{CF}{StdCF} eq 'HASH' and $$encrypt{CF}{StdCF}{CFM};
            my $cryptMeth = $$encrypt{CF}{StdCF}{CFM};
            unless ($cryptMeth =~ /^\/(V2|AESV2|AESV3)$/) {
                return "Unsupported encryption method $cryptMeth";
            }
            # set "_aesv2" or "_aesv3" flag in %$encrypt hash if AES encryption was used
            $$encrypt{'_' . lc($1)} = 1 if $cryptMeth =~ /^\/(AESV2|AESV3)$/;
        }
        if ($ver == 5) {
            # validate OE and UE entries
            foreach ('OE', 'UE') {
                return "Missing Encrypt $_ entry" unless $$encrypt{$_};
                $parm{$_} = ReadPDFValue($$encrypt{$_});
                return "Invalid Encrypt $_ entry" unless length $parm{$_} == 32;
            }
            require Image::ExifTool::AES;   # will need this later
        }
    } else {
        return "Encryption version $ver currently not supported";
    }
    $id or return "Can't decrypt (no document ID)";

    # make sure we have the necessary libraries available
    if ($ver < 5) {
        unless (eval { require Digest::MD5 }) {
            return "Install Digest::MD5 to process encrypted PDF";
        }
    } else {
        unless (eval { require Digest::SHA }) {
            return "Install Digest::SHA to process AES-256 encrypted PDF";
        }
    }

    # calculate file-level en/decryption key
    my $pad = "\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08".
              "\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A";
    my $o = ReadPDFValue($$encrypt{O});
    my $u = ReadPDFValue($$encrypt{U});

    # set flag indicating whether metadata is encrypted
    # (in version 4 and higher, metadata streams may not be encrypted)
    if ($ver < 4 or not $$encrypt{EncryptMetadata} or $$encrypt{EncryptMetadata} !~ /false/i) {
        $$encrypt{_meta} = 1;
    }
    # try no password first, then try provided password if available
    my ($try, $key);
    for ($try=0; ; ++$try) {
        my $password;
        if ($try == 0) {
            $password = '';
        } elsif ($try == 1) {
            $password = $et->Options('Password');
            return 'Document is password protected (use Password option)' unless defined $password;
            # make sure there is no UTF-8 flag on the password
            if ($] >= 5.006 and ($$et{OPTIONS}{EncodeHangs} or
                eval { require Encode; Encode::is_utf8($password) } or $@))
            {
                local $SIG{'__WARN__'} = sub { };
                # repack by hand if Encode isn't available
                $password = ($$et{OPTIONS}{EncodeHangs} or $@) ? pack('C*', unpack($] < 5.010000 ?
                            'U0C*' : 'C0C*', $password)) : Encode::encode('utf8', $password);
            }
        } else {
            return 'Incorrect password';
        }
        if ($ver < 5) {
            if (length $password) {
                # password must be encoding in PDFDocEncoding (ref iso32000)
                $password = $et->Encode($password, 'PDFDoc');
                # truncate or pad the password to exactly 32 bytes
                if (length($password) > 32) {
                    $password = substr($password, 0, 32);
                } elsif (length($password) < 32) {
                    $password .= substr($pad, 0, 32-length($password));
                }
            } else {
                $password = $pad;
            }
            $key = $password . $o . pack('V', $$encrypt{P}) . $id;
            my $rep = 1;
            if ($rev == 3 or $rev == 4) {
                # must add this if metadata not encrypted
                $key .= "\xff\xff\xff\xff" unless $$encrypt{_meta};
                $rep += 50; # repeat MD5 50 more times if revision is 3 or greater
            }
            my ($len, $i, $dat);
            if ($ver == 1) {
                $len = 5;
            } else {
                $len = $$encrypt{Length} || 40;
                $len >= 40 or return 'Bad Encrypt Length';
                $len = int($len / 8);
            }
            for ($i=0; $i<$rep; ++$i) {
                $key = substr(Digest::MD5::md5($key), 0, $len);
            }
            # decrypt U to see if a user password is required
            if ($rev >= 3) {
                $dat = Digest::MD5::md5($pad . $id);
                RC4Crypt(\$dat, $key);
                for ($i=1; $i<=19; ++$i) {
                    my @key = unpack('C*', $key);
                    foreach (@key) { $_ ^= $i; }
                    RC4Crypt(\$dat, pack('C*', @key));
                }
                $dat .= substr($u, 16);
            } else {
                $dat = $pad;
                RC4Crypt(\$dat, $key);
            }
            last if $dat eq $u; # all done if this was the correct key
        } else {
            return 'Invalid O or U Encrypt entries' if length($o) < 48 or length($u) < 48;
            if (length $password) {
                # Note: this should be good for passwords containing reasonable characters,
                # but to be bullet-proof we need to apply the SASLprep (IETF RFC 4013) profile
                # of stringprep (IETF RFC 3454) to the password before encoding in UTF-8
                $password = $et->Encode($password, 'UTF8');
                $password = substr($password, 0, 127) if length($password) > 127;
            }
            # test for the owner password
            my $sha = GetHash($password, substr($o,32,8), substr($u,0,48), $rev);
            if ($sha eq substr($o, 0, 32)) {
                $key = GetHash($password, substr($o,40,8), substr($u,0,48), $rev);
                my $dat = ("\0" x 16) . $parm{OE};
                # decrypt with no padding
                my $err = Image::ExifTool::AES::Crypt(\$dat, $key, 0, 1);
                return $err if $err;
                $key = $dat;    # use this as the file decryption key
                last;
            }
            # test for the user password
            $sha = GetHash($password, substr($u,32,8), '', $rev);
            if ($sha eq substr($u, 0, 32)) {
                $key = GetHash($password, substr($u,40,8), '', $rev);
                my $dat = ("\0" x 16) . $parm{UE};
                my $err = Image::ExifTool::AES::Crypt(\$dat, $key, 0, 1);
                return $err if $err;
                $key = $dat;    # use this as the file decryption key
                last;
            }
        }
    }
    $$encrypt{_key} = $key; # save the file-level encryption key
    $cryptInfo = $encrypt;  # save reference to the file-level Encrypt object
    return undef;           # success!
}

#------------------------------------------------------------------------------
# Decrypt/Encrypt data
# Inputs: 0) data ref
#         1) PDF object reference to use as crypt key extension (may be 'none' to
#            avoid extending the encryption key, as for streams with Crypt Filter)
#         2) encrypt flag (false for decryption)
sub Crypt($$;$)
{
    return unless $cryptInfo;
    my ($dataPt, $keyExt, $encrypt) = @_;
    # do not decrypt if the key extension object is undefined
    # (this doubles as a flag to disable decryption/encryption)
    return unless defined $keyExt;
    my $key = $$cryptInfo{_key};
    # apply the necessary crypt key extension
    unless ($$cryptInfo{_aesv3}) {
        unless ($keyExt eq 'none') {
            # extend crypt key using object and generation number
            unless ($keyExt =~ /^(I\d+ )?(\d+) (\d+)/) {
                $$cryptInfo{_error} = 'Invalid object reference for encryption';
                return;
            }
            $key .= substr(pack('V', $2), 0, 3) . substr(pack('V', $3), 0, 2);
        }
        # add AES-128 salt if necessary (this little gem is conveniently
        # omitted from the Adobe PDF 1.6 documentation, causing me to
        # waste 12 hours trying to figure out why this wasn't working --
        # it appears in ISO32000 though, so I should have been using that)
        $key .= 'sAlT' if $$cryptInfo{_aesv2};
        my $len = length($key);
        $key = Digest::MD5::md5($key);              # get 16-byte MD5 digest
        $key = substr($key, 0, $len) if $len < 16;  # trim if necessary
    }
    # perform the decryption/encryption
    if ($$cryptInfo{_aesv2} or $$cryptInfo{_aesv3}) {
        require Image::ExifTool::AES;
        my $err = Image::ExifTool::AES::Crypt($dataPt, $key, $encrypt);
        $err and $$cryptInfo{_error} = $err;
    } else {
        RC4Crypt($dataPt, $key);
    }
}

#------------------------------------------------------------------------------
# Decrypt/Encrypt stream data
# Inputs: 0) dictionary ref, 1) PDF object reference to use as crypt key extension
sub CryptStream($$)
{
    return unless $cryptStream;
    my ($dict, $keyExt) = @_;
    my $type = $$dict{Type} || '';
    # XRef streams are not encrypted (ref 3, page 50),
    # and Metadata may or may not be encrypted
    if ($cryptInfo and $type ne '/XRef' and
        ($$cryptInfo{_meta} or $type ne '/Metadata'))
    {
        Crypt(\$$dict{_stream}, $keyExt, $$dict{_decrypted});
        # toggle _decrypted flag
        $$dict{_decrypted} = ($$dict{_decrypted} ? undef : 1);
    } else {
        $$dict{_decrypted} = 0; # stream should never be encrypted
    }
}

#------------------------------------------------------------------------------
# Generate a new PDF tag (based on its ID) and add it to a tag table
# Inputs: 0) tag table ref, 1) tag ID
# Returns: tag info ref
sub NewPDFTag($$)
{
    my ($tagTablePtr, $tag) = @_;
    my $name = $tag;
    # translate URL-like escape sequences
    $name =~ s/#([0-9a-f]{2})/chr(hex($1))/ige;
    $name =~ s/[^-\w]+/_/g;         # translate invalid characters to an underline
    $name =~ s/(^|_)([a-z])/\U$2/g; # start words with upper case
    my $tagInfo = { Name => $name };
    AddTagToTable($tagTablePtr, $tag, $tagInfo);
    return $tagInfo;
}

#------------------------------------------------------------------------------
# Process AcroForm dictionary to set HasXMLFormsArchitecture flag
# Inputs: Same as ProcessDict
sub ProcessAcroForm($$$$;$$)
{
    my ($et, $tagTablePtr, $dict, $xref, $nesting, $type) = @_;
    $et->HandleTag($tagTablePtr, '_has_xfa', $$dict{XFA} ? 'true' : 'false');
    return 1 unless $et->Options('Verbose');
    return ProcessDict($et, $tagTablePtr, $dict, $xref, $nesting, $type);
}

#------------------------------------------------------------------------------
# Process AF dictionary to extract C2PA manifest
# Inputs: Same as ProcessDict
sub ProcessAF($$$$;$$)
{
    my ($et, $tagTablePtr, $dict, $xref, $nesting, $type) = @_;
    $$et{AFRelationship} = $$dict{AFRelationship} || '';
    # go no further unless Verbose or this is the C2PA_Manifest item
    return 1 unless $et->Options('Verbose') or $$et{AFRelationship} eq '/C2PA_Manifest';
    return ProcessDict($et, $tagTablePtr, $dict, $xref, $nesting, $type);
}

#------------------------------------------------------------------------------
# Expand array into a string
# Inputs: 0) array ref
# Return: string
sub ExpandArray($)
{
    my $val = shift;
    my @list = @$val;
    foreach (@list) {
        ref $_ eq 'SCALAR' and $_ = "ref($$_)", next;
        ref $_ eq 'ARRAY' and $_ = ExpandArray($_), next;
        defined $_ or $_ = '<undef>', next;
    }
    return '[' . join(',',@list) . ']';
}

#------------------------------------------------------------------------------
# Process PDF dictionary extract tag values
# Inputs: 0) ExifTool object reference, 1) tag table reference
#         2) dictionary reference, 3) cross-reference table reference,
#         4) nesting depth, 5) dictionary capture type
sub ProcessDict($$$$;$$)
{
    local $_;
    my ($et, $tagTablePtr, $dict, $xref, $nesting, $type) = @_;
    my $verbose = $et->Options('Verbose');
    my $unknown = $$tagTablePtr{EXTRACT_UNKNOWN};
    my $embedded = (defined $unknown and not $unknown and $et->Options('ExtractEmbedded'));
    my @tags = @{$$dict{_tags}};
    my ($next, %join, $validInfo);
    my $index = 0;

    $nesting = ($nesting || 0) + 1;
    if ($nesting > 50) {
        $et->Warn('Nesting too deep (directory ignored)');
        return;
    }
    # save entire dictionary for rewriting if specified
    if ($$et{PDF_CAPTURE} and $$tagTablePtr{VARS} and
        $tagTablePtr->{VARS}->{CAPTURE})
    {
        my $name;
        foreach $name (@{$tagTablePtr->{VARS}->{CAPTURE}}) {
            next if $$et{PDF_CAPTURE}{$name};
            # make sure we load the right type if indicated
            next if $type and $type ne $name;
            $$et{PDF_CAPTURE}{$name} = $dict;
            last;
        }
    }
    $validInfo = ($et->Options('Validate') and $tagTablePtr eq \%Image::ExifTool::PDF::Info);
#
# extract information from all tags in the dictionary
#
    for (;;) {
        my ($tag, $isSubDoc);
        if (@tags) {
            $tag = shift @tags;
        } elsif (defined $next and not $next) {
            $tag = 'Next';
            $next = 1;
        } else {
            last;
        }
        my $val = $$dict{$tag};
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo) {
            undef $tagInfo if $$tagInfo{NoProcess};
        } elsif ($embedded and $tag =~ /^(.*?)(\d+)$/ and
            $$tagTablePtr{$1} and (ref $val ne 'SCALAR' or not $fetched{$$val}))
        {
            my ($name, $num) = ($1, $2);
            $tagInfo = $et->GetTagInfo($tagTablePtr, $name);
            if (ref $tagInfo eq 'HASH' and $$tagInfo{JoinStreams}) {
                $fetched{$$val} = 1;
                my $obj = FetchObject($et, $$val, $xref, $tag);
                $join{$name} = [] unless $join{$name};
                next unless ref $obj eq 'HASH' and $$obj{_stream};
                # save all the stream data to join later
                DecodeStream($et, $obj);
                $join{$name}->[$num] = $$obj{_stream};
                undef $tagInfo;    # don't process
            } else {
                $isSubDoc = 1;  # treat as a sub-document
            }
        }
        if ($validInfo and $$et{PDFVersion} >= 2.0 and (not $tagInfo or not $$tagInfo{PDF2})) {
            my $name = $tagInfo ? ":$$tagInfo{Name}" : " Info tag '${tag}'";
            $et->Warn("PDF$name is deprecated in PDF 2.0");
        }
        if ($verbose) {
            my ($val2, $extra);
            if (ref $val eq 'SCALAR') {
                $extra = ", indirect object ($$val)";
                if ($fetched{$$val}) {
                    $val2 = "ref($$val)";
                } elsif ($tag eq 'Next' and not $next) {
                    # handle 'Next' links after all others
                    $next = 0;
                    next;
                } else {
                    $fetched{$$val} = 1;
                    $val = FetchObject($et, $$val, $xref, $tag);
                    unless (defined $val) {
                        my $str;
                        if (defined $lastOffset) {
                            $val2 = '<free>';
                            $str = 'Object was freed';
                        } else {
                            $val2 = '<err>';
                            $str = 'Error reading object';
                        }
                        $et->VPrint(0, "$$et{INDENT}${str}:\n");
                    }
                }
            } elsif (ref $val eq 'HASH') {
                $extra = ', direct dictionary';
            } elsif (ref $val eq 'ARRAY') {
                $extra = ', direct array of ' . scalar(@$val) . ' objects';
            } else {
                $extra = ', direct object';
            }
            my $isSubdir;
            if (ref $val eq 'HASH') {
                $isSubdir = 1;
            } elsif (ref $val eq 'ARRAY') {
                # recurse into objects in arrays only if they are lists of
                # dictionaries or indirect objects which could be dictionaries
                $isSubdir = 1 if @$val;
                foreach (@$val) {
                    next if ref $_ eq 'HASH' or ref $_ eq 'SCALAR';
                    undef $isSubdir;
                    last;
                }
            }
            if ($isSubdir) {
                # create bogus subdirectory to recurse into this dict
                $tagInfo or $tagInfo = {
                    Name => $tag,
                    SubDirectory => { TagTable => 'Image::ExifTool::PDF::Unknown' },
                };
            } else {
                $val2 = ExpandArray($val) if ref $val eq 'ARRAY';
                # generate tag info if we will use it later
                if (not $tagInfo and defined $val and $unknown) {
                    $tagInfo = NewPDFTag($tagTablePtr, $tag);
                }
            }
            $et->VerboseInfo($tag, $tagInfo,
                Value => $val2 || $val,
                Extra => $extra,
                Index => $index++,
            );
            next unless defined $val;
        }
        unless ($tagInfo) {
            # add any tag found in Info dictionary to table
            next unless $unknown;
            $tagInfo = NewPDFTag($tagTablePtr, $tag);
        }
        # increment document number if necessary
        my ($oldDocNum, $oldNumTags);
        if ($isSubDoc) {
            $oldDocNum = $$et{DOC_NUM};
            $oldNumTags = $$et{NUM_FOUND};
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        }
        if ($$tagInfo{SubDirectory}) {
            # process the subdirectory
            my @subDicts;
            if (ref $val eq 'ARRAY') {
                # hack to convert array to dictionary if necessary
                if ($$tagInfo{ConvertToDict} and @$val == 2 and not ref $$val[0]) {
                    my $tg = $$val[0];
                    $tg =~ s(^/)();   # remove name
                    my %dict = ( _tags => [ $tg ], $tg => $$val[1] );
                    @subDicts = ( \%dict );
                } else {
                    @subDicts = @{$val};
                }
            } else {
                @subDicts = ( $val );
            }
            # loop through all values of this tag
            for (;;) {
                my $subDict = shift @subDicts or last;
                # save last fetched object in case we fetch another one here
                my $prevFetched = $lastFetched;
                if (ref $subDict eq 'SCALAR') {
                    # only fetch once (other copies are obsolete)
                    next if $fetched{$$subDict};
                    if ($$tagInfo{IgnoreDuplicates}) {
                        my $flag = "ProcessedPDF_$tag";
                        if ($$et{$flag}) {
                            next if $et->Warn("Ignored duplicate $tag dictionary", 2);
                        } else {
                            $$et{$flag} = 1;
                        }
                    }
                    # load dictionary via an indirect reference
                    $fetched{$$subDict} = 1;
                    my $obj = FetchObject($et, $$subDict, $xref, $tag);
                    unless (defined $obj) {
                        unless (defined $lastOffset) {
                            $et->Warn("Error reading $tag object ($$subDict)");
                        }
                        next;
                    }
                    $subDict = $obj;
                }
                if (ref $subDict eq 'ARRAY') {
                    # convert array of key/value pairs to a hash
                    next if @$subDict < 2;
                    my %hash = ( _tags => [] );
                    while (@$subDict >= 2) {
                        my $key = shift @$subDict;
                        $key =~ s/^\///;
                        push @{$hash{_tags}}, $key;
                        $hash{$key} = shift @$subDict;
                    }
                    $subDict = \%hash;
                } else {
                    next unless ref $subDict eq 'HASH';
                }
                # set flag to re-crypt all strings when rewriting if the dictionary
                # came from an encrypted stream
                $$subDict{_needCrypt}{'*'} = 1 unless $lastFetched;
                my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                if (not $verbose) {
                    my $proc = $$subTablePtr{PROCESS_PROC} || \&ProcessDict;
                    &$proc($et, $subTablePtr, $subDict, $xref, $nesting);
                } elsif ($next) {
                    # handle 'Next' links at this level to avoid deep recursion
                    undef $next;
                    $index = 0;
                    $tagTablePtr = $subTablePtr;
                    $dict = $subDict;
                    @tags = @{$$subDict{_tags}};
                    $et->VerboseDir($tag, scalar(@tags));
                } else {
                    my $oldIndent = $$et{INDENT};
                    my $oldDir = $$et{DIR_NAME};
                    $$et{INDENT} .= '| ';
                    $$et{DIR_NAME} = $tag;
                    $et->VerboseDir($tag, scalar(@{$$subDict{_tags}}));
                    my $proc = $$subTablePtr{PROCESS_PROC} || \&ProcessDict;
                    &$proc($et, $subTablePtr, $subDict, $xref, $nesting);
                    $$et{INDENT} = $oldIndent;
                    $$et{DIR_NAME} = $oldDir;
                }
                $lastFetched = $prevFetched;
            }
        } else {
            # fetch object if necessary
            # (OS X 10.6 writes indirect objects in the Info dictionary!)
            if (ref $val eq 'SCALAR') {
                my $prevFetched = $lastFetched;
                # (note: fetching the same object multiple times is OK here)
                $val = FetchObject($et, $$val, $xref, $tag);
                if (defined $val) {
                    $val = ReadPDFValue($val);
                    # set flag to re-encrypt if necessary if rewritten
                    $$dict{_needCrypt}{$tag} = ($lastFetched ? 0 : 1) if $cryptString;
                    $lastFetched = $prevFetched; # restore last fetched object reference
                }
            } else {
                $val = ReadPDFValue($val);
            }
            if (ref $val) {
                if (ref $val eq 'ARRAY') {
                    delete $$et{LIST_TAGS}{$tagInfo} if $$tagInfo{List};
                    my $v;
                    foreach $v (@$val) {
                        $et->FoundTag($tagInfo, $v);
                    }
                }
            } elsif (defined $val) {
                # convert from UTF-16 (big endian) to UTF-8 or Latin if necessary
                # unless this is binary data (hex-encoded strings would not have been converted)
                my $format = $$tagInfo{Format} || $$tagInfo{Writable} || 'string';
                $val = ConvertPDFDate($val) if $format eq 'date';
                if (not $$tagInfo{Binary} and $val =~ /[\x18-\x1f\x80-\xff]/) {
                    # text string is already in Unicode if it starts with "\xfe\xff",
                    # otherwise we must first convert from PDFDocEncoding
                    $val = $et->Decode($val, ($val=~s/^\xfe\xff// ? 'UCS2' : 'PDFDoc'), 'MM');
                }
                if ($$tagInfo{List} and not $$et{OPTIONS}{NoPDFList}) {
                    # separate tokens in comma or whitespace delimited lists
                    my $comma = $val =~ tr/,/,/;
                    my $semi = $val =~ tr/;/;/;
                    my $split;
                    if ($comma or $semi) {
                        $split = $comma > $semi ? ',+\\s*' : ';+\\s*';
                    } else {
                        $split = ' ';
                    }
                    my @values = split $split, $val;
                    $et->FoundTag($tagInfo, $_) foreach @values;
                } else {
                    # a simple tag value
                    $et->FoundTag($tagInfo, $val);
                }
            }
        }
        if ($isSubDoc) {
            # restore original document number
            $$et{DOC_NUM} = $oldDocNum;
            --$$et{DOC_COUNT} if $oldNumTags == $$et{NUM_FOUND};
        }
    }
#
# extract information from joined streams if necessary
#

    if (%join) {
        my ($tag, $i);
        foreach $tag (sort keys %join) {
            my $list = $join{$tag};
            last unless defined $$list[1] and $$list[1] =~ /^%.*?([\x0d\x0a]*)/;
            my $buff = "%!PS-Adobe-3.0$1";  # add PS header with same line break
            for ($i=1; defined $$list[$i]; ++$i) {
                $buff .= $$list[$i];
                undef $$list[$i];   # free memory
            }
            # increment document number for tags extracted from embedded EPS
            my $oldDocNum = $$et{DOC_NUM};
            my $oldNumTags = $$et{NUM_FOUND};
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            # extract PostScript information
            $et->HandleTag($tagTablePtr, $tag, $buff);
            $$et{DOC_NUM} = $oldDocNum;
            # revert document counter if we didn't add any new tags
            --$$et{DOC_COUNT} if $oldNumTags == $$et{NUM_FOUND};
            delete $$et{DOC_NUM};
        }
    }
#
# extract information from stream object if it exists (eg. Metadata stream)
#
    for (;;) { # (cheap goto)
        last unless $$dict{_stream};
        my $tag = '_stream';
        # add Subtype (if it exists) to stream name and remove leading '/'
        ($tag = $$dict{Subtype} . $tag) =~ s/^\/// if $$dict{Subtype};
        last unless $$tagTablePtr{$tag};
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag) or last;
        my $subdir = $$tagInfo{SubDirectory};
        unless ($subdir) {
            # don't build filter lists across different images
            delete $$et{LIST_TAGS}{$$tagTablePtr{Filter}};
            # we arrive here only when extracting embedded images
            # - only extract known image types and ignore others
            my $filter = $$dict{Filter} || '';
            $filter = @$filter[-1] if ref $filter eq 'ARRAY'; # (get last Filter type)
            my $result;
            if ($filter eq '/DCTDecode' or $filter eq '/JPXDecode') {
                DecodeStream($et, $dict) or last;
                # save the image itself
                $et->FoundTag($tagInfo, \$$dict{_stream});
                # extract information from embedded image
                $result = $et->ExtractInfo(\$$dict{_stream}, { ReEntry => 1 });
            }
            unless ($result) {
                $et->FoundTag('FileType', defined $result ? '(unknown)' : '(unsupported)');
            }
            last;
        }
        # decode stream if necessary
        if ($cryptInfo and ($$cryptInfo{_aesv2} or $$cryptInfo{_aesv3} and
            $$dict{Length} and $$dict{Length} > 10000) and not $$dict{_decrypted} and
            not $$et{PDF_CAPTURE}) # (capturing PDF for writing?)
        {
            my $type = $$dict{Type} || '';
            if ($type ne '/Metadata' or $$dict{Length} > 100000) {
                if ($$et{OPTIONS}{IgnoreMinorErrors}) {
                    $et->Warn("Decrypting large $$tagInfo{Name} (will be slow)");
                } else {
                    $et->Warn("Skipping large AES-encrypted $$tagInfo{Name}", 2);
                    last;
                }
            }
        }
        DecodeStream($et, $dict) or last;
        if ($verbose > 2) {
            $et->VPrint(2,"$$et{INDENT}$$et{DIR_NAME} stream data\n");
            $et->VerboseDump(\$$dict{_stream});
        }
        # extract information from stream
        my %dirInfo = (
            DataPt   => \$$dict{_stream},
            DataLen  => length $$dict{_stream},
            DirStart => 0,
            DirLen   => length $$dict{_stream},
            Parent   => 'PDF',
            DirName  => $$subdir{DirName},
        );
        my $subTablePtr = GetTagTable($$subdir{TagTable});
        unless ($et->ProcessDirectory(\%dirInfo, $subTablePtr)) {
            $et->Warn("Error processing $$tagInfo{Name} information");
        }
        last;
    }
}

#------------------------------------------------------------------------------
# Extract information from PDF file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 0 if not a PDF file, 1 on success, otherwise a negative error number
sub ReadPDF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my ($buff, $encrypt, $id);
#
# validate PDF file
#
    # (linearization dictionary must be in the first 1024 bytes of the file)
    $raf->Read($buff, 1024) >= 8 or return 0;
    $buff =~ /^(\s*)%PDF-(\d+\.\d+)/ or return 0;
    $$et{PDFBase} = length $1 and $et->Warn('PDF header is not at start of file',1);
    $pdfVer = $$et{PDFVersion} = $2;
    $et->SetFileType();   # set the FileType tag
    # store PDFVersion tag
    my $tagTablePtr = GetTagTable('Image::ExifTool::PDF::Root');
    $et->HandleTag($tagTablePtr, 'Version', $pdfVer);
    $tagTablePtr = GetTagTable('Image::ExifTool::PDF::Main');
#
# check for a linearized PDF (only if reading)
#
    my $capture = $$et{PDF_CAPTURE};
    unless ($capture) {
        my $lin = 'false';
        if ($buff =~ /<</g) {
            $buff = substr($buff, pos($buff) - 2);
            my $dict = ExtractObject($et, \$buff);
            if (ref $dict eq 'HASH' and $$dict{Linearized} and $$dict{L}) {
                if (not $$et{VALUE}{FileSize}) {
                    undef $lin; # can't determine if it is linearized
                } elsif ($$dict{L} == $$et{VALUE}{FileSize} - $$et{PDFBase}) {
                    $lin = 'true';
                }
            }
        }
        $et->HandleTag($tagTablePtr, '_linearized', $lin) if $lin;
    }
#
# read the xref tables referenced from startxref at the end of the file
#
    my @xrefOffsets;
    $raf->Seek(0, 2) or return -2;
    # the %%EOF must occur within the last 1024 bytes of the file (PDF spec, appendix H)
    my $len = $raf->Tell();
    $len = 1024 if $len > 1024;
    $raf->Seek(-$len, 2) or return -2;
    $raf->Read($buff, $len) == $len or return -3;
    # find the LAST xref table in the file (may be multiple %%EOF marks,
    # and comments between "startxref" and "%%EOF")
    $buff =~ /^.*startxref(\s+)(\d+)(\s+)((%[^\x0d\x0a]*\s+)*)%%EOF/s or return -4;
    # parse comments to read SEAL information
    if ($4) {
        my @com = split /[\x0d\x0d]+/, $4;
        foreach (@com) {
            /^(%+\s*)<seal seal=/ or next;
            my $dat = substr $_, length($1);
            my $tbl = GetTagTable('Image::ExifTool::XMP::SEAL');
            $et->ProcessDirectory({ DataPt => \$dat }, $tbl);
        }
    }
    my $ws = $1 . $3;
    my $xr = $2;
    push @xrefOffsets, $xr, 'Main';
    # set input record separator
    local $/ = $ws =~ /(\x0d\x0a|\x0d|\x0a)/ ? $1 : "\x0a";
    my (%xref, @mainDicts, %loaded, $mainFree);
    my ($xrefSize, $mainDictSize) = (0, 0);
    # initialize variables to capture when rewriting
    if ($capture) {
        $capture->{startxref} = $xr;
        $capture->{xref} = \%xref;
        $capture->{newline} = $/;
        $capture->{mainFree} = $mainFree = { };
    }
XRef:
    while (@xrefOffsets) {
        my $offset = shift @xrefOffsets;
        my $type = shift @xrefOffsets;
        next if $loaded{$offset};   # avoid infinite recursion
        unless ($raf->Seek($offset+$$et{PDFBase}, 0)) {
            %loaded or return -5;
            $et->Warn('Bad offset for secondary xref table');
            next;
        }
        # Note: care must be taken because ReadLine may read more than we want if
        # the newline sequence for this table is different than the rest of the file
        for (;;) {
            unless ($raf->ReadLine($buff)) {
                %loaded or return -6;
                $et->Warn('Bad offset for secondary xref table');
                next XRef;
            }
            last if $buff =~/\S/;   # skip blank lines
        }
        my $loadXRefStream;
        if ($buff =~ s/^\s*xref\s+//s) {
            # load xref table
            for (;;) {
                # read another line if necessary (skipping blank lines)
                $raf->ReadLine($buff) or return -6 until $buff =~ /\S/;
                last if $buff =~ s/^\s*trailer([\s<[(])/$1/s;
                $buff =~ s/^\s*(\d+)\s+(\d+)\s+//s or return -4;
                my ($start, $num) = ($1, $2);
                $raf->Seek(-length($buff), 1) or return -4;
                my $i;
                for ($i=0; $i<$num; ++$i) {
                    $raf->Read($buff, 20) == 20 or return -6;
                    $buff =~ /^\s*(\d{10}) (\d{5}) (f|n)/s or return -4;
                    my $num = $start + $i;
                    $xrefSize = $num if $num > $xrefSize;
                    # locate object to generate entry from stream if necessary
                    # (must do this before we test $xref{$num})
                    LocateAnyObject(\%xref, $num) if $xref{dicts};
                    # save offset for newest copy of all objects
                    # (or next object number for free objects)
                    unless (defined $xref{$num}) {
                        my ($offset, $gen) = (int($1), int($2));
                        $xref{$num} = $offset;
                        if ($3 eq 'f') {
                            # save free objects in last xref table for rewriting
                            $$mainFree{$num} =  [ $offset, $gen, 'f' ] if $mainFree;
                            next;
                        }
                        # also save offset keyed by object reference string
                        $xref{"$num $gen R"} = $offset;
                    }
                }
                # (I have a sample from Adobe which has an empty xref table)
                # %xref or return -4; # xref table may not be empty
                $buff = '';
            }
            undef $mainFree;    # only do this for the last xref table
        } elsif ($buff =~ s/^\s*(\d+)\s+(\d+)\s+obj//s) {
            # this is a PDF-1.5 cross-reference stream dictionary
            $loadXRefStream = 1;
        } else {
            %loaded or return -4;
            $et->Warn('Invalid secondary xref table');
            next;
        }
        my $mainDict = ExtractObject($et, \$buff, $raf, \%xref);
        unless (ref $mainDict eq 'HASH') {
            %loaded or return -8;
            $et->Warn('Error loading secondary dictionary');
            next;
        }
        # keep track of total trailer dictionary Size
        $mainDictSize = $$mainDict{Size} if $$mainDict{Size} and $$mainDict{Size} > $mainDictSize;
        if ($loadXRefStream) {
            # decode and save our XRef stream from PDF-1.5 file
            # (but parse it later as required to save time)
            # Note: this technique can potentially result in an old object
            # being used if the file was incrementally updated and an older
            # object from an xref table was replaced by a newer object in an
            # xref stream.  But doing so isn't a good idea (if allowed at all)
            # because a PDF 1.4 consumer would also make this same mistake.
            if ($$mainDict{Type} eq '/XRef' and $$mainDict{W} and
                @{$$mainDict{W}} > 2 and $$mainDict{Size} and
                DecodeStream($et, $mainDict))
            {
                # create Index entry if it doesn't exist
                $$mainDict{Index} or $$mainDict{Index} = [ 0, $$mainDict{Size} ];
                # create '_entry_size' entry for internal use
                my $w = $$mainDict{W};
                my $size = 0;
                foreach (@$w) { $size += $_; }
                $$mainDict{_entry_size} = $size;
                # save this stream dictionary to use later if required
                $xref{dicts} = [] unless $xref{dicts};
                push @{$xref{dicts}}, $mainDict;
            } else {
                %loaded or return -9;
                $et->Warn('Invalid xref stream in secondary dictionary');
            }
        }
        $loaded{$offset} = 1;
        # load XRef stream in hybrid file if it exists
        push @xrefOffsets, $$mainDict{XRefStm}, 'XRefStm' if $$mainDict{XRefStm};
        $encrypt = $$mainDict{Encrypt} if $$mainDict{Encrypt};
        undef $encrypt if $encrypt and $encrypt eq 'null'; # (have seen "null")
        if ($$mainDict{ID} and ref $$mainDict{ID} eq 'ARRAY') {
            $id = ReadPDFValue($mainDict->{ID}->[0]);
        }
        push @mainDicts, $mainDict, $type;
        # load previous xref table if it exists
        push @xrefOffsets, $$mainDict{Prev}, 'Prev' if $$mainDict{Prev};
    }
    if ($xrefSize > $mainDictSize) {
        my $str = "Objects in xref table ($xrefSize) exceed trailer dictionary Size ($mainDictSize)";
        $capture ? $et->Error($str) : $et->Warn($str);
    }
#
# extract encryption information if necessary
#
    if ($encrypt) {
        if (ref $encrypt eq 'SCALAR') {
            $encrypt = FetchObject($et, $$encrypt, \%xref, 'Encrypt');
        }
        # generate Encryption tag information
        my $err = DecryptInit($et, $encrypt, $id);
        if ($err) {
            $et->Warn($err);
            $$capture{Error} = $err if $capture;
            return -1;
        }
    }
#
# extract the information beginning with each of the main dictionaries
#
    my $i = 0;
    my $num = (scalar @mainDicts) / 2;
    while (@mainDicts) {
        my $dict = shift @mainDicts;
        my $type = shift @mainDicts;
        if ($verbose) {
            ++$i;
            my $n = scalar(@{$$dict{_tags}});
            $et->VPrint(0, "PDF dictionary ($i of $num) with $n entries:\n");
        }
        ProcessDict($et, $tagTablePtr, $dict, \%xref, 0, $type);
    }
    # handle any decryption errors
    if ($encrypt) {
        my $err = $$encrypt{_error};
        if ($err) {
            $et->Warn($err);
            $$capture{Error} = $err if $capture;
            return -1;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# ReadPDF() warning strings for each error return value
my %pdfWarning = (
    # -1 is reserved as error return value with no associated warning
    -2 => 'Error seeking in file',
    -3 => 'Error reading file',
    -4 => 'Invalid xref table',
    -5 => 'Invalid xref offset',
    -6 => 'Error reading xref table',
    -7 => 'Error reading trailer',
    -8 => 'Error reading main dictionary',
    -9 => 'Invalid xref stream in main dictionary',
);

#------------------------------------------------------------------------------
# Extract information from PDF file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid PDF file
sub ProcessPDF($$)
{
    my ($et, $dirInfo) = @_;

    undef $cryptInfo;   # (must not delete after returning so writer can use it)
    undef $cryptStream;
    undef $cryptString;
    my $result = ReadPDF($et, $dirInfo);
    if ($result < 0) {
        $et->Warn($pdfWarning{$result}) if $pdfWarning{$result};
        $result = 1;
    }
    # clean up and return
    undef %streamObjs;
    undef %fetched;
    return $result;
}

1; # end


__END__

=head1 NAME

Image::ExifTool::PDF - Read PDF meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This code reads meta information from PDF (Adobe Portable Document Format)
files.  It supports object streams introduced in PDF-1.5 but only with a
limited set of Filter and Predictor algorithms, however all standard
encryption methods through PDF-2.0 are supported, including AESV2 (AES-128)
and AESV3 (AES-256).

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://partners.adobe.com/public/developer/pdf/index_reference.html>

=item L<Crypt::RC4|Crypt::RC4>

=item L<http://www.adobe.com/devnet/acrobat/pdfs/PDF32000_2008.pdf>

=item L<http://www.adobe.com/content/dam/Adobe/en/devnet/pdf/pdfs/adobe_supplement_iso32000.pdf>

=item L<http://tools.ietf.org/search/rfc3454>

=item L<http://www.armware.dk/RFC/rfc/rfc4013.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PDF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
