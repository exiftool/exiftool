#------------------------------------------------------------------------------
# File:         MWG.pm
#
# Description:  Metadata Working Group support
#
# Revisions:    2009/10/21 - P. Harvey Created
#
# References:   1) http://www.metadataworkinggroup.org/
#------------------------------------------------------------------------------

package Image::ExifTool::MWG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::XMP;

$VERSION = '1.24';

sub RecoverTruncatedIPTC($$$);
sub ListToString($);
sub StringToList($$);
sub OverwriteStringList($$$$);

my $mwgLoaded;  # flag set if we alreaded Load()ed the MWG tags

# MWG Composite tags
%Image::ExifTool::MWG::Composite = (
    GROUPS => { 0 => 'Composite', 1 => 'MWG', 2 => 'Image' },
    VARS => { NO_ID => 1 },
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    NOTES => q{
        The table below lists special Composite tags which are used to access other
        tags based on the MWG 2.0 recommendations.  These tags are only accessible
        when explicitly loaded, but this is done automatically by the exiftool
        application if MWG is specified as a group for any tag on the command line,
        or manually with the C<-use MWG> option.  Via the API, the MWG Composite
        tags are loaded by calling "C<Image::ExifTool::MWG::Load()>".

        When reading, the value of each MWG tag is B<Derived From> the specified
        tags based on the MWG guidelines.  When writing, the appropriate associated
        tags are written.  The value of the IPTCDigest tag is updated automatically
        when the IPTC is changed if either the IPTCDigest tag didn't exist
        beforehand or its value agreed with the original IPTC digest (indicating
        that the XMP is synchronized with the IPTC).  IPTC information is written
        only if the original file contained IPTC.

        Loading the MWG module activates "strict MWG conformance mode", which has
        the effect of causing EXIF, IPTC and XMP in non-standard locations to be
        ignored when reading, as per the MWG recommendations.  Instead, a "Warning"
        tag is generated when non-standard metadata is encountered.  This feature
        may be disabled by setting C<$Image::ExifTool::MWG::strict = 0> in the
        L<ExifTool config file|../config.html> (or from your Perl script when using the API).  Note
        that the behaviour when writing is not changed:  ExifTool always creates new
        records only in the standard location, but writes new tags to any
        EXIF/IPTC/XMP records that exist.

        Contrary to the EXIF specification, the MWG recommends that EXIF "ASCII"
        string values be stored as UTF-8.  To honour this, the exiftool application
        sets the default internal EXIF string encoding to "UTF8" when the MWG module
        is loaded, but via the API this must be done manually by setting the
        L<CharsetEXIF|../ExifTool.html#CharsetEXIF> option.

        A complication of the MWG specification is that although the MWG:Creator
        property may consist of multiple values, the associated EXIF tag
        (EXIF:Artist) is only a simple string.  To resolve this discrepancy the MWG
        recommends a technique which allows a list of values to be stored in a
        string by using a semicolon-space separator (with quotes around values if
        necessary).  When the MWG module is loaded, ExifTool automatically
        implements this policy and changes EXIF:Artist to a list-type tag.
    },
    Keywords => {
        Flags  => ['Writable','List'],
        Desire => {
            0 => 'IPTC:Keywords', # (64-character limit)
            1 => 'XMP-dc:Subject',
            2 => 'CurrentIPTCDigest',
            3 => 'IPTCDigest',
        },
        RawConv => q{
            return $val[1] if not defined $val[2] or (defined $val[1] and
                             (not defined $val[3] or $val[2] eq $val[3]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[0], $val[1], 64);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            # only write Keywords if IPTC exists (eg. set EditGroup option)
            'IPTC:Keywords'  => '$opts{EditGroup} = 1; $val',
            'XMP-dc:Subject' => '$val',
        },
    },
    Description => {
        Writable => 1,
        Desire => {
            0 => 'EXIF:ImageDescription',
            1 => 'IPTC:Caption-Abstract', # (2000-character limit)
            2 => 'XMP-dc:Description',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            return $val[0] if defined $val[0] and $val[0] !~ /^ *$/;
            return $val[2] if not defined $val[3] or (defined $val[2] and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[1], $val[2], 2000);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'EXIF:ImageDescription' => '$val',
            'IPTC:Caption-Abstract' => '$opts{EditGroup} = 1; $val',
            'XMP-dc:Description'    => '$val',
        },
    },
    DateTimeOriginal => {
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Notes => '"specifies when a photo was taken" - MWG',
        Writable => 1,
        Shift => 0, # don't shift this tag
        Desire => {
            0 => 'Composite:SubSecDateTimeOriginal',
            1 => 'EXIF:DateTimeOriginal',
            2 => 'IPTC:DateCreated',
            3 => 'IPTC:TimeCreated',
            4 => 'XMP-photoshop:DateCreated',
            5 => 'CurrentIPTCDigest',
            6 => 'IPTCDigest',
        },
        # must check for validity in RawConv to avoid hiding a same-named tag,
        # but IPTC dates use a ValueConv so we need to derive the value there
        RawConv => q{
            (defined $val[0] or defined $val[1] or $val[2] or
            (defined $val[4] and (not defined $val[5] or not defined $val[6]
            or $val[5] eq $val[6]))) ? $val : undef
        },
        ValueConv => q{
            return $val[0] if defined $val[0] and $val[0] !~ /^[: ]*$/;
            return $val[1] if defined $val[1] and $val[1] !~ /^[: ]*$/;
            return $val[4] if not defined $val[5] or (defined $val[4] and
                             (not defined $val[6] or $val[5] eq $val[6]));
            return $val[3] ? "$val[2] $val[3]" : $val[2] if $val[2];
            return undef;
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            # set EXIF date/time values according to PrintConv option instead
            # of defaulting to Type=ValueConv to allow reformatting to be applied
            'Composite:SubSecDateTimeOriginal'  => 'delete $opts{Type}; $val',
            'IPTC:DateCreated'                  => '$opts{EditGroup} = 1; $val',
            'IPTC:TimeCreated'                  => '$opts{EditGroup} = 1; $val',
            'XMP-photoshop:DateCreated'         => '$val',
        },
    },
    CreateDate => {
        Groups => { 2 => 'Time' },
        Notes => '"specifies when an image was digitized" - MWG',
        Writable => 1,
        Shift => 0, # don't shift this tag
        Desire => {
            0 => 'Composite:SubSecCreateDate',
            1 => 'EXIF:CreateDate',
            2 => 'IPTC:DigitalCreationDate',
            3 => 'IPTC:DigitalCreationTime',
            4 => 'XMP-xmp:CreateDate',
            5 => 'CurrentIPTCDigest',
            6 => 'IPTCDigest',
        },
        RawConv => q{
            (defined $val[0] or defined $val[1] or $val[2] or
            (defined $val[4] and (not defined $val[5] or not defined $val[6]
            or $val[5] eq $val[6]))) ? $val : undef
        },
        ValueConv => q{
            return $val[0] if defined $val[0] and $val[0] !~ /^[: ]*$/;
            return $val[1] if defined $val[1] and $val[1] !~ /^[: ]*$/;
            return $val[4] if not defined $val[5] or (defined $val[4] and
                             (not defined $val[6] or $val[5] eq $val[6]));
            return $val[3] ? "$val[2] $val[3]" : $val[2] if $val[2];
            return undef;
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'Composite:SubSecCreateDate' => 'delete $opts{Type}; $val',
            'IPTC:DigitalCreationDate'   => '$opts{EditGroup} = 1; $val',
            'IPTC:DigitalCreationTime'   => '$opts{EditGroup} = 1; $val',
            'XMP-xmp:CreateDate'         => '$val',
        },
    },
    ModifyDate => {
        Groups => { 2 => 'Time' },
        Notes => '"specifies when a file was modified by the user" - MWG',
        Writable => 1,
        Shift => 0, # don't shift this tag
        Desire => {
            0 => 'Composite:SubSecModifyDate',
            1 => 'EXIF:ModifyDate',
            2 => 'XMP-xmp:ModifyDate',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            return $val[0] if defined $val[0] and $val[0] !~ /^[: ]*$/;
            return $val[1] if defined $val[1] and $val[1] !~ /^[: ]*$/;
            return $val[2] if not defined $val[3] or not defined $val[4] or $val[3] eq $val[4];
            return undef;
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
        # return empty string from check routines so this tag will never be set
        # (only WriteAlso tags are written), the only difference is a -v2 message
        DelCheck   => '""',
        WriteCheck => '""',
        WriteAlso  => {
            'Composite:SubSecModifyDate' => 'delete $opts{Type}; $val',
            'XMP-xmp:ModifyDate'         => '$val',
        },
    },
    Orientation => {
        Writable   => 1,
        Require    => 'EXIF:Orientation',
        ValueConv  => '$val',
        PrintConv  => \%Image::ExifTool::Exif::orientation,
        DelCheck   => '""',
        WriteCheck => '""',
        WriteAlso  => {
            'EXIF:Orientation' => '$val',
        },
    },
    Rating => {
        Writable   => 1,
        Require    => 'XMP-xmp:Rating',
        ValueConv  => '$val',
        DelCheck   => '""',
        WriteCheck => '""',
        WriteAlso  => {
            'XMP-xmp:Rating' => '$val',
        },
    },
    Copyright => {
        Groups => { 2 => 'Author' },
        Writable => 1,
        Desire => {
            0 => 'EXIF:Copyright',
            1 => 'IPTC:CopyrightNotice', # (128-character limit)
            2 => 'XMP-dc:Rights',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            return $val[0] if defined $val[0] and $val[0] !~ /^ *$/;
            return $val[2] if not defined $val[3] or (defined $val[2] and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[1], $val[2], 128);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'EXIF:Copyright' => q{
                # encode if necessary (not automatic because Format is 'undef')
                my $enc = $self->Options('CharsetEXIF');
                if ($enc) {
                    my $v = $val;
                    $self->Encode($v,$enc);
                    return $v;
                }
                return $val;
            },
            'IPTC:CopyrightNotice' => '$opts{EditGroup} = 1; $val',
            'XMP-dc:Rights'        => '$val',
        },
    },
    Creator => {
        Groups => { 2 => 'Author' },
        Flags  => ['Writable','List'],
        Desire => {
            0 => 'EXIF:Artist',
            1 => 'IPTC:By-line', # (32-character limit)
            2 => 'XMP-dc:Creator',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            return $val[0] if defined $val[0] and $val[0] !~ /^ *$/;
            return $val[2] if not defined $val[3] or (defined $val[2] and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[1], $val[2], 32);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'EXIF:Artist'    => '$val',
            'IPTC:By-line'   => '$opts{EditGroup} = 1; $val',
            'XMP-dc:Creator' => '$val',
        },
    },
    Country => {
        Groups => { 2 => 'Location' },
        Writable => 1,
        Desire => {
            0 => 'IPTC:Country-PrimaryLocationName', # (64-character limit)
            1 => 'XMP-photoshop:Country',
            2 => 'XMP-iptcExt:LocationShownCountryName',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            my $xmpVal = $val[2] || $val[1];
            return $xmpVal if not defined $val[3] or (defined $xmpVal and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[0], $xmpVal, 64);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'IPTC:Country-PrimaryLocationName' => '$opts{EditGroup} = 1; $val',
            'XMP-photoshop:Country'            => '$val', # (legacy)
            'XMP-iptcExt:LocationShownCountryName' => '$val',
        },
    },
    State => {
        Groups => { 2 => 'Location' },
        Writable => 1,
        Desire => {
            0 => 'IPTC:Province-State', # (32-character limit)
            1 => 'XMP-photoshop:State',
            2 => 'XMP-iptcExt:LocationShownProvinceState',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            my $xmpVal = $val[2] || $val[1];
            return $xmpVal if not defined $val[3] or (defined $xmpVal and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[0], $xmpVal, 32);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'IPTC:Province-State' => '$opts{EditGroup} = 1; $val',
            'XMP-photoshop:State' => '$val', # (legacy)
            'XMP-iptcExt:LocationShownProvinceState' => '$val',
        },
    },
    City => {
        Groups => { 2 => 'Location' },
        Writable => 1,
        Desire => {
            0 => 'IPTC:City', # (32-character limit)
            1 => 'XMP-photoshop:City',
            2 => 'XMP-iptcExt:LocationShownCity',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            my $xmpVal = $val[2] || $val[1];
            return $xmpVal if not defined $val[3] or (defined $xmpVal and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[0], $xmpVal, 32);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'IPTC:City'          => '$opts{EditGroup} = 1; $val',
            'XMP-photoshop:City' => '$val', # (legacy)
            'XMP-iptcExt:LocationShownCity' => '$val',
        },
    },
    Location => {
        Groups => { 2 => 'Location' },
        Writable => 1,
        Desire => {
            0 => 'IPTC:Sub-location', # (32-character limit)
            1 => 'XMP-iptcCore:Location',
            2 => 'XMP-iptcExt:LocationShownSublocation',
            3 => 'CurrentIPTCDigest',
            4 => 'IPTCDigest',
        },
        RawConv => q{
            my $xmpVal = $val[2] || $val[1];
            return $xmpVal if not defined $val[3] or (defined $xmpVal and
                             (not defined $val[4] or $val[3] eq $val[4]));
            return Image::ExifTool::MWG::RecoverTruncatedIPTC($val[0], $xmpVal, 32);
        },
        DelCheck   => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteCheck => 'Image::ExifTool::MWG::ReconcileIPTCDigest($self)',
        WriteAlso  => {
            'IPTC:Sub-location'     => '$opts{EditGroup} = 1; $val',
            'XMP-iptcCore:Location' => '$val', # (legacy)
            'XMP-iptcExt:LocationShownSublocation' => '$val',
        },
    },
);

# MWG XMP structures
my %sExtensions = (
    STRUCT_NAME => 'MWG Extensions',
    NAMESPACE   => undef, # variable namespace
    NOTES => q{
        This structure may contain any top-level XMP tags, but none have been
        pre-defined in ExifTool.  Since no flattened tags have been pre-defined,
        RegionExtensions is writable only as a structure (eg.
        C<{xmp-dc:creator=me,rating=5}>).  Fields for this structure are identified
        using the standard ExifTool tag name (with optional leading group name,
        and/or trailing language code, and/or trailing C<#> symbol to disable print
        conversion).
    },
);
my %sRegionStruct = (
    STRUCT_NAME => 'MWG RegionStruct',
    NAMESPACE   => 'mwg-rs',
    Area => { Struct => \%Image::ExifTool::XMP::sArea },
    Type => {
        PrintConv => {
            Face => 'Face',
            Pet => 'Pet',
            Focus => 'Focus',
            BarCode => 'BarCode',
        },
    },
    Name        => { },
    Description => { },
    FocusUsage  => {
        PrintConv => {
            EvaluatedUsed => 'Evaluated, Used',
            EvaluatedNotUsed => 'Evaluated, Not Used',
            NotEvaluatedNotUsed => 'Not Evaluated, Not Used',
        },
    },
    BarCodeValue=> { },
    Extensions  => { Struct => \%sExtensions },
    Rotation    => { # (observed in LR6 XMP)
        Writable => 'real',
        Notes => 'not part of MWG 2.0 spec',
    },
    # Title - seen in sample XMP of MWG 2.0 specification, but not in spec itself
    seeAlso => { Namespace => 'rdfs', Resource => 1 },
);
my %sKeywordStruct;
%sKeywordStruct = (
    STRUCT_NAME => 'MWG KeywordStruct',
    NAMESPACE   => 'mwg-kw',
    Keyword   => { },
    Applied   => { Writable => 'boolean' },
    Children  => { Struct => \%sKeywordStruct, List => 'Bag' },
);

# MWG 2.0 XMP region namespace tags
%Image::ExifTool::MWG::Regions = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-mwg-rs', 2 => 'Image' },
    NAMESPACE => 'mwg-rs',
    NOTES => q{
        Image region metadata defined by the MWG 2.0 specification.  These tags
        may be accessed without the need to load the MWG Composite tags above.  See
        L<https://web.archive.org/web/20180919181934/http://www.metadataworkinggroup.org/pdf/mwg_guidance.pdf>
        for the official specification.
    },
    Regions => {
        Name => 'RegionInfo',
        FlatName => 'Region',
        Struct => {
            STRUCT_NAME => 'MWG RegionInfo',
            NAMESPACE   => 'mwg-rs',
            RegionList => {
                FlatName => 'Region',
                Struct => \%sRegionStruct,
                List => 'Bag',
            },
            AppliedToDimensions => { Struct => \%Image::ExifTool::XMP::sDimensions },
        },
    },
    RegionsRegionList => { Flat => 1, Name => 'RegionList' },
);

# MWG 2.0 XMP hierarchical keyword namespace tags
%Image::ExifTool::MWG::Keywords = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-mwg-kw', 2 => 'Image' },
    NAMESPACE => 'mwg-kw',
    NOTES => q{
        Hierarchical keywords metadata defined by the MWG 2.0 specification. 
        ExifTool unrolls keyword structures to an arbitrary depth of 6 to allow
        individual levels to be accessed with different tag names, and to avoid
        infinite recursion.  See
        L<https://web.archive.org/web/20180919181934/http://www.metadataworkinggroup.org/pdf/mwg_guidance.pdf>
        for the official specification.
    },
    # arbitrarily define only the first 6 levels of the keyword hierarchy
    Keywords => {
        Name => 'KeywordInfo',
        Struct => {
            STRUCT_NAME => 'MWG KeywordInfo',
            NAMESPACE   => 'mwg-kw',
            Hierarchy => { Struct => \%sKeywordStruct, List => 'Bag' },
        },
    },
    KeywordsHierarchy => { Name => 'HierarchicalKeywords', Flat => 1 },
    KeywordsHierarchyKeyword  => { Name => 'HierarchicalKeywords1', Flat => 1 },
    KeywordsHierarchyApplied  => { Name => 'HierarchicalKeywords1Applied', Flat => 1 },
    KeywordsHierarchyChildren => { Name => 'HierarchicalKeywords1Children', Flat => 1 },
    KeywordsHierarchyChildrenKeyword  => { Name => 'HierarchicalKeywords2', Flat => 1 },
    KeywordsHierarchyChildrenApplied  => { Name => 'HierarchicalKeywords2Applied', Flat => 1 },
    KeywordsHierarchyChildrenChildren => { Name => 'HierarchicalKeywords2Children', Flat => 1 },
    KeywordsHierarchyChildrenChildrenKeyword  => { Name => 'HierarchicalKeywords3', Flat => 1 },
    KeywordsHierarchyChildrenChildrenApplied  => { Name => 'HierarchicalKeywords3Applied', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildren => { Name => 'HierarchicalKeywords3Children', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenKeyword  => { Name => 'HierarchicalKeywords4', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenApplied  => { Name => 'HierarchicalKeywords4Applied', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenChildren => { Name => 'HierarchicalKeywords4Children', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenChildrenKeyword  => { Name => 'HierarchicalKeywords5', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenChildrenApplied  => { Name => 'HierarchicalKeywords5Applied', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenChildrenChildren => { Name => 'HierarchicalKeywords5Children', Flat => 1, NoSubStruct => 1 }, # break infinite recursion
    KeywordsHierarchyChildrenChildrenChildrenChildrenChildrenKeyword => { Name => 'HierarchicalKeywords6', Flat => 1 },
    KeywordsHierarchyChildrenChildrenChildrenChildrenChildrenApplied => { Name => 'HierarchicalKeywords6Applied', Flat => 1 },
);

# MWG 2.0 XMP collections namespace tags
%Image::ExifTool::MWG::Collections = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-mwg-coll', 2 => 'Image' },
    NAMESPACE => 'mwg-coll',
    NOTES => q{
        Collections metadata defined by the MWG 2.0 specification.  See
        L<https://web.archive.org/web/20180919181934/http://www.metadataworkinggroup.org/pdf/mwg_guidance.pdf>
        for the official specification.
    },
    Collections => {
        FlatName => '',
        List => 'Bag',
        Struct => {
            STRUCT_NAME => 'MWG CollectionInfo',
            NAMESPACE   => 'mwg-coll',
            CollectionName => { },
            CollectionURI  => { },
        },
    },
);


#------------------------------------------------------------------------------
# Load the MWG Composite tags
sub Load()
{
    return if $mwgLoaded;

    # add our composite tags
    Image::ExifTool::AddCompositeTags('Image::ExifTool::MWG');
    # must also add to lookup so we can write them
    # (since MWG tags aren't in the tag lookup by default)
    Image::ExifTool::AddTagsToLookup(\%Image::ExifTool::MWG::Composite,
                                     'Image::ExifTool::Composite');

    # modify EXIF:Artist to behave as a list-type tag
    my $artist = $Image::ExifTool::Exif::Main{0x13b};
    $$artist{List} = 1;
    $$artist{IsOverwriting} = \&OverwriteStringList;
    $$artist{RawConv} = \&StringToList;

    # enable MWG strict mode if not set already
    # (causes non-standard EXIF, IPTC and XMP to be ignored)
    $Image::ExifTool::MWG::strict = 1 unless defined $Image::ExifTool::MWG::strict;

    $mwgLoaded = 1;
}

#------------------------------------------------------------------------------
# Change a list of values to a string using MWG rules
# Inputs: 0)reference to list of values
# Returns: string of values (and may reformat list entries)
sub ListToString($)
{
    my $vals = shift;
    foreach (@$vals) {
        # double all quotes in value and quote the value if it begins
        # with a quote or contains a semicolon-space separator
        if (/^"/ or /; /) {
            s/"/""/g;       # double all quotes
            $_ = qq{"$_"};  # quote the value
        }
    }
    return join('; ', @$vals);
}

#------------------------------------------------------------------------------
# Change a string value to a list of values using MWG rules
# Inputs: 0) string of values, 1) ExifTool ref
# Returns: value or list reference if more than one value
# Notes: Sets Warning tag on error
sub StringToList($$)
{
    my ($str, $et) = @_;
    my (@vals, $inQuotes);
    my @t = split '; ', $str, -1;
    foreach (@t) {
        my $wasQuotes = $inQuotes;
        $inQuotes = 1 if not $inQuotes and s/^"//;
        if ($inQuotes) {
            # remove the last quote and reset the inQuotes flag if
            # the value ended in an odd number of quotes
            $inQuotes = 0 if s/((^|[^"])("")*)"$/$1/;
            s/""/"/g;   # un-double the contained quotes
        }
        if ($wasQuotes) {
            # previous separator was quoted, so concatinate with previous value
            $vals[-1] .= '; ' . $_;
        } else {
            push @vals, $_;
        }
    }
    $et->Warn('Incorrectly quoted MWG string-list value') if $inQuotes;
    return @vals > 1 ? \@vals : $vals[0];
}

#------------------------------------------------------------------------------
# Handle logic for overwriting EXIF string-type list tag
# Inputs: 0) ExifTool ref, 1) new value hash ref,
#         2) old string value (or undef if it didn't exist), 3) new value ref
# Returns: 1 and sets the new value for the tag
sub OverwriteStringList($$$$)
{
    local $_;
    my ($et, $nvHash, $val, $newValuePt) = @_;
    my (@new, $delIndex);
    my $writeMode = $et->Options('WriteMode');
    if ($writeMode ne 'wcg') {
        if (defined $val) {
            $writeMode =~ /w/i or return 0;
        } else {
            $writeMode =~ /c/i or return 0;
        }
    }
    if ($$nvHash{DelValue} and defined $val) {
        # preserve specified old values
        my $old = StringToList($val, $et);
        my @old = ref $old eq 'ARRAY' ? @$old : $old;
        if (@{$$nvHash{DelValue}}) {
            my %del;
            $del{$_} = 1 foreach @{$$nvHash{DelValue}};
            foreach (@old) {
                $del{$_} or push(@new, $_), next;
                $delIndex or $delIndex = scalar @new;
            }
        } else {
            push @new, @old;
        }
    }
    # add new values (at location of deleted values, if any)
    if ($$nvHash{Value}) {
        if (defined $delIndex) {
            splice @new, $delIndex, 0, @{$$nvHash{Value}};
        } else {
            push @new, @{$$nvHash{Value}};
        }
    }
    if (@new) {
        # convert back to string format
        $$newValuePt = ListToString(\@new);
    } else {
        $$newValuePt = undef;   # delete the tag
    }
    return 1;
}

#------------------------------------------------------------------------------
# Reconcile IPTC digest after writing an MWG tag
# Inputs: 0) ExifTool object ref
# Returns: empty string
sub ReconcileIPTCDigest($)
{
    my $et = shift;

    # set new value for IPTCDigest if not done already
    unless ($Image::ExifTool::Photoshop::iptcDigestInfo and
            $$et{NEW_VALUE}{$Image::ExifTool::Photoshop::iptcDigestInfo})
    {
        # write new IPTCDigest only if it doesn't exist or
        # is the same as the digest of the original IPTC
        my @a; # (capture warning messages)
        @a = $et->SetNewValue('Photoshop:IPTCDigest', 'old', Protected => 1, DelValue => 1);
        @a = $et->SetNewValue('Photoshop:IPTCDigest', 'new', Protected => 1);
    }
    return '';
}

#------------------------------------------------------------------------------
# Recover strings which were truncated by IPTC dataset length limit
# Inputs: 0) IPTC value, 1) XMP value, 2) length limit
# Notes: handles the case where IPTC and/or XMP values are lists
sub RecoverTruncatedIPTC($$$)
{
    my ($iptc, $xmp, $limit) = @_;

    return $iptc unless defined $xmp;
    if (ref $iptc) {
        $xmp = [ $xmp ] unless ref $xmp;
        my ($i, @vals);
        for ($i=0; $i<@$iptc; ++$i) {
            push @vals, RecoverTruncatedIPTC($$iptc[$i], $$xmp[$i], $limit);
        }
        return \@vals;
    } elsif (defined $iptc and length $iptc == $limit) {
        $xmp = $$xmp[0] if ref $xmp;    # take first element of list
        return $xmp if length $xmp > $limit and $iptc eq substr($xmp, 0, $limit);
    }
    return $iptc;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MWG - Metadata Working Group support

=head1 SYNOPSIS

    # enable MWG Composite tags
    use Image::ExifTool::MWG;
    Image::ExifTool::MWG::Load();

    # enable MWG strict mode
    $Image::ExifTool::MWG::strict = 1;

    # disable MWG strict mode
    $Image::ExifTool::MWG::strict = 0;

=head1 DESCRIPTION

The MWG module contains Composite tag definitions which are designed to
simplify implementation of the Metadata Working Group guidelines.  These
special MWG Composite tags are enabled by calling the Load() method:

    use Image::ExifTool::MWG;
    Image::ExifTool::MWG::Load();

By default, loading the MWG Composite tags enables "strict MWG conformance"
unless previously enabled or disabled by the user.  In this mode, ExifTool
will generate a Warning instead of extracting EXIF, IPTC and XMP from
non-standard locations.  The strict mode may be disabled or enabled at any
time by setting the MWG "strict" flag to 0 or 1.  eg)

    $Image::ExifTool::MWG::strict = 0;

This module also contains the MWG XMP tags which are loaded automatically by
ExifTool as required, and are independent of the MWG Composite tags which
must be loaded explicitly as described above.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.metadataworkinggroup.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MWG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
