#------------------------------------------------------------------------------
# File:         OOXML.pm
#
# Description:  Read Office Open XML+ZIP files
#
# Revisions:    2009/10/31 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::OOXML;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;
use Image::ExifTool::ZIP;

$VERSION = '1.08';

# test for recognized OOXML document extensions
my %isOOXML = (
    DOCX => 1,  DOCM => 1,
    DOTX => 1,  DOTM => 1,
    POTX => 1,  POTM => 1,
    PPAX => 1,  PPAM => 1,
    PPSX => 1,  PPSM => 1,
    PPTX => 1,  PPTM => 1,  THMX => 1,
    XLAM => 1,
    XLSX => 1,  XLSM => 1,  XLSB => 1,
    XLTX => 1,  XLTM => 1,
);

# generate reverse lookup for file type based on MIME
my %fileType;
{
    my $type;
    foreach $type (keys %isOOXML) {
        $fileType{$Image::ExifTool::mimeType{$type}} = $type;
    }
}

# XML attributes to queue
my %queuedAttrs;
my %queueAttrs = (
    fmtid => 1,
    pid   => 1,
    name  => 1,
);

# keep track of items in a vector (to accumulate as a list)
my $vectorCount;
my @vectorVals;

# Office Open XML tags
%Image::ExifTool::OOXML::Main = (
    GROUPS => { 0 => 'XML', 1 => 'XML', 2 => 'Document' },
    PROCESS_PROC => \&Image::ExifTool::XMP::ProcessXMP,
    VARS => { NO_ID => 1 },
    NOTES => q{
        The Office Open XML (OOXML) format was introduced with Microsoft Office 2007
        and is used by file types such as DOCX, PPTX and XLSX.  These are
        essentially ZIP archives containing XML files.  The table below lists some
        tags which have been observed in OOXML documents, but ExifTool will extract
        any tags found from XML files of the OOXML document properties ("docProps")
        directory.

        B<Tips:>

        1) Structural ZIP tags may be ignored (if desired) with C<--ZIP:all> on the
        command line.

        2) Tags may be grouped by their document number in the ZIP archive with the
        C<-g3> or C<-G3> option.
    },
    # These tags all have 1:1 correspondence with FlashPix tags except for:
    #   OOXML            FlashPix
    #   ---------------  -------------
    #   DocSecurity      Security
    #   Application      Software
    #   dc:Description   Comments
    #   dc:Creator       Author
    Application => { },
    AppVersion  => { },
    category    => { },
    Characters  => { },
    CharactersWithSpaces => { },
    CheckedBy   => { },
    Client      => { },
    Company     => { },
    created     => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    createdType => { Hidden => 1, RawConv => 'undef' }, # ignore this XML type name
    DateCompleted => {
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Department  => { },
    Destination => { },
    Disposition => { },
    Division    => { },
    DocSecurity => {
        # (http://msdn.microsoft.com/en-us/library/documentformat.openxml.extendedproperties.documentsecurity.aspx)
        PrintConv => {
            0 => 'None',
            1 => 'Password protected',
            2 => 'Read-only recommended',
            4 => 'Read-only enforced',
            8 => 'Locked for annotations',
        },
    },
    DocumentNumber=> { },
    Editor      => { Groups => { 2 => 'Author'} },
    ForwardTo   => { },
    Group       => { },
    HeadingPairs=> { },
    HiddenSlides=> { },
    HyperlinkBase=>{ },
    HyperlinksChanged => { PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    keywords    => { },
    Language    => { },
    lastModifiedBy => { Groups => { 2 => 'Author'} },
    lastPrinted => {
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Lines       => { },
    LinksUpToDate=>{ PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    Mailstop    => { },
    Manager     => { },
    Matter      => { },
    MMClips     => { },
    modified    => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    modifiedType=> { Hidden => 1, RawConv => 'undef' }, # ignore this XML type name
    Notes       => { },
    Office      => { },
    Owner       => { Groups => { 2 => 'Author'} },
    Pages       => { },
    Paragraphs  => { },
    PresentationFormat => { },
    Project     => { },
    Publisher   => { },
    Purpose     => { },
    ReceivedFrom=> { },
    RecordedBy  => { },
    RecordedDate=> {
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Reference   => { },
    revision    => { Name => 'RevisionNumber' },
    ScaleCrop   => { PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    SharedDoc   => { PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    Slides      => { },
    Source      => { },
    Status      => { },
    TelephoneNumber => { },
    Template    => { },
    TitlesOfParts=>{ },
    TotalTime   => {
        Name => 'TotalEditTime',
        PrintConv => 'ConvertTimeSpan($val, 60)',
    },
    Typist      => { },
    Words       => { },
);

#------------------------------------------------------------------------------
# Generate a tag ID for this XML tag
# Inputs: 0) tag property name list ref
# Returns: tagID and outtermost interesting namespace (or '' if no namespace)
sub GetTagID($)
{
    my $props = shift;
    my ($tag, $prop, $namespace);
    foreach $prop (@$props) {
        # split name into namespace and property name
        # (Note: namespace can be '' for property qualifiers)
        my ($ns, $nm) = ($prop =~ /(.*?):(.*)/) ? ($1, $2) : ('', $prop);
        next if $ns eq 'vt';        # ignore 'vt' properties
        if (defined $tag) {
            $tag .= ucfirst($nm);   # add to tag name
        } elsif ($prop ne 'Properties' and $prop ne 'cp:coreProperties' and
                 $prop ne 'property')
        {
            $tag = $nm;
            # save namespace of first property to contribute to tag name
            $namespace = $ns unless $namespace;
        }
    }
    return ($tag, $namespace || '');
}

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) ExifTool object ref, 1) tag table ref
#         2) reference to array of XMP property names (last is current property)
#         3) property value, 4) attribute hash ref (not used here)
# Returns: 1 if valid tag was found
sub FoundTag($$$$;$)
{
    my ($et, $tagTablePtr, $props, $val, $attrs) = @_;
    return 0 unless @$props;
    my $verbose = $et->Options('Verbose');

    my $tag = $$props[-1];
    $et->VPrint(0, "  | - Tag '", join('/',@$props), "'\n") if $verbose > 1;

    # un-escape XML character entities
    $val = Image::ExifTool::XMP::UnescapeXML($val);
    # convert OOXML-escaped characters (eg. "_x0000d_" is a newline)
    $val =~ s/_x([0-9a-f]{4})_/Image::ExifTool::PackUTF8(hex($1))/gie;
    # convert from UTF8 to ExifTool Charset
    $val = $et->Decode($val, 'UTF8');
    # queue this attribute for later if necessary
    if ($queueAttrs{$tag}) {
        $queuedAttrs{$tag} = $val;
        return 0;
    }
    my $ns;
    ($tag, $ns) = GetTagID($props);
    if (not $tag) {
        # all properties are in ignored namespaces
        # so 'name' from our queued attributes for the tag
        my $name = $queuedAttrs{name} or return 0;
        $name =~ s/(^| )([a-z])/$1\U$2/g;     # start words with uppercase
        ($tag = $name) =~ tr/-_a-zA-Z0-9//dc;
        return 0 unless length $tag;
        unless ($$tagTablePtr{$tag}) {
            my %tagInfo = (
                Name => $tag,
                Description => $name,
            );
            # format as a date/time value if type is 'vt:filetime'
            if ($$props[-1] eq 'vt:filetime') {
                $tagInfo{Groups} = { 2 => 'Time' },
                $tagInfo{Format} = 'date',
                $tagInfo{PrintConv} = '$self->ConvertDateTime($val)';
            }
            $et->VPrint(0, "  | [adding $tag]\n") if $verbose;
            AddTagToTable($tagTablePtr, $tag, \%tagInfo);
        }
    } elsif ($tag eq 'xmlns') {
        # ignore namespaces (for now)
        return 0;
    } elsif (ref $Image::ExifTool::XMP::Main{$ns} eq 'HASH' and
        $Image::ExifTool::XMP::Main{$ns}{SubDirectory})
    {
        # use standard XMP table if it exists
        my $table = $Image::ExifTool::XMP::Main{$ns}{SubDirectory}{TagTable};
        no strict 'refs';
        if ($table and %$table) {
            $tagTablePtr = Image::ExifTool::GetTagTable($table);
        }
    } elsif (@$props > 2 and grep /^vt:vector$/, @$props) {
        # handle vector properties (accumulate as lists)
        if ($$props[-1] eq 'vt:size') {
            $vectorCount = $val;
            undef @vectorVals;
            return 0;
        } elsif ($$props[-1] eq 'vt:baseType') {
            return 0;   # ignore baseType
        } elsif ($vectorCount) {
            --$vectorCount;
            if ($vectorCount) {
                push @vectorVals, $val;
                return 0;
            }
            $val = [ @vectorVals, $val ] if @vectorVals;
            # Note: we will lose any improper-sized vector elements here
        }
    }
    # add any unknown tags to table
    if ($$tagTablePtr{$tag}) {
        my $tagInfo = $$tagTablePtr{$tag};
        if (ref $tagInfo eq 'HASH') {
            # reformat date/time values
            my $fmt = $$tagInfo{Format} || $$tagInfo{Writable} || '';
            $val = Image::ExifTool::XMP::ConvertXMPDate($val) if $fmt eq 'date';
        }
    } else {
        $et->VPrint(0, "  [adding $tag]\n") if $verbose;
        AddTagToTable($tagTablePtr, $tag, { Name => ucfirst $tag });
    }
    # save the tag
    $et->HandleTag($tagTablePtr, $tag, $val);

    # start fresh for next tag
    undef $vectorCount;
    undef %queuedAttrs;

    return 1;
}

#------------------------------------------------------------------------------
# Extract information from an OOXML file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1
# Notes: Upon entry to this routine, the file type has already been verified
# and the dirInfo hash contains 2 elements unique to this process proc:
#   MIME    - mime type of main document from "[Content_Types].xml"
#   ZIP     - reference to Archive::Zip object for this file
sub ProcessDOCX($$)
{
    my ($et, $dirInfo) = @_;
    my $zip = $$dirInfo{ZIP};
    my $tagTablePtr = GetTagTable('Image::ExifTool::OOXML::Main');
    my $mime = $$dirInfo{MIME} || $Image::ExifTool::mimeType{DOCX};

    # set the file type ('DOCX' by default)
    my $fileType = $fileType{$mime};
    if ($fileType) {
        # THMX is a special case because its contents.main MIME types is PPTX
        if ($fileType eq 'PPTX' and $$et{FILE_EXT} and $$et{FILE_EXT} eq 'THMX') {
            $fileType = 'THMX';
        }
    } else {
        $et->VPrint(0, "Unrecognized MIME type: $mime\n");
        # get MIME type according to file extension
        $fileType = $$et{FILE_EXT};
        # default to 'DOCX' if this isn't a known OOXML extension
        $fileType = 'DOCX' unless $fileType and $isOOXML{$fileType};
    }
    $et->SetFileType($fileType);

    # must catch all Archive::Zip warnings
    local $SIG{'__WARN__'} = \&Image::ExifTool::ZIP::WarnProc;
    # extract meta information from all files in ZIP "docProps" directory
    my $docNum = 0;
    my @members = $zip->members();
    my $member;
    foreach $member (@members) {
        # get filename of this ZIP member
        my $file = $member->fileName();
        next unless defined $file;
        $et->VPrint(0, "File: $file\n");
        # set the document number and extract ZIP tags
        $$et{DOC_NUM} = ++$docNum;
        Image::ExifTool::ZIP::HandleMember($et, $member);
        # process only XML and JPEG/WMF thumbnail images in "docProps" directory
        next unless $file =~ m{^docProps/(.*\.xml|(thumbnail\.(jpe?g|wmf)))$}i;
        # get the file contents (CAREFUL! $buff MUST be local since we hand off a value ref)
        my ($buff, $status) = $zip->contents($member);
        $status and $et->Warn("Error extracting $file"), next;
        # extract docProps/thumbnail.(jpg|mwf) as PreviewImage|PreviewMWF
        if ($file =~ /\.(jpe?g|wmf)$/i) {
            my $tag = $file =~ /\.wmf$/i ? 'PreviewWMF' : 'PreviewImage';
            $et->FoundTag($tag, \$buff);
            next;
        }
        # process XML files (docProps/app.xml, docProps/core.xml, docProps/custom.xml)
        my %dirInfo = (
            DataPt => \$buff,
            DirLen => length $buff,
            DataLen => length $buff,
            XMPParseOpts => {
                FoundProc => \&FoundTag,
            },
        );
        $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        undef $buff;    # (free memory now)
    }
    delete $$et{DOC_NUM};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::OOXML - Read Office Open XML+ZIP files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Office Open XML files.  This is the format of Word, Excel
and PowerPoint files written by Microsoft Office 2007 -- essentially ZIP
archives of XML files.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/OOXML Tags>,
L<Image::ExifTool::TagNames/FlashPix Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

