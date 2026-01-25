#------------------------------------------------------------------------------
# File:         iWork.pm
#
# Description:  Read Apple iWork '09 XML+ZIP files
#
# Revisions:    2009/11/11 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::iWork;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;
use Image::ExifTool::ZIP;

$VERSION = '1.06';

# test for recognized iWork document extensions and outer XML elements
my %iWorkType = (
    # file extensions
    NUMBERS => 'NUMBERS',
    PAGES   => 'PAGES',
    KEY     => 'KEY',
    KTH     => 'KTH',
    NMBTEMPLATE => 'NMBTEMPLATE',
    # we don't support double extensions --
    # "PAGES.TEMPLATE" => 'Apple Pages Template',
    # outer XML elements
    'ls:document' => 'NUMBERS',
    'sl:document' => 'PAGES',
    'key:presentation' => 'KEY',
);

# MIME types for iWork files (Apple has not registered these yet, but these
# are my best guess after doing some googling.  I'm not 100% sure what "sff"
# indicates, but I think it refers to the new "flattened" package format)
my %mimeType = (
    'NUMBERS'       => 'application/x-iwork-numbers-sffnumbers',
    'PAGES'         => 'application/x-iwork-pages-sffpages',
    'KEY'           => 'application/x-iWork-keynote-sffkey',
    'NMBTEMPLATE'   => 'application/x-iwork-numbers-sfftemplate',
    'PAGES.TEMPLATE'=> 'application/x-iwork-pages-sfftemplate',
    'KTH'           => 'application/x-iWork-keynote-sffkth',
);

# iWork tags
%Image::ExifTool::iWork::Main = (
    GROUPS => { 0 => 'XML', 1 => 'XML', 2 => 'Document' },
    PROCESS_PROC => \&Image::ExifTool::XMP::ProcessXMP,
    VARS => { ID_FMT => 'none' },
    NOTES => q{
        The Apple iWork '09 file format is a ZIP archive containing XML files
        similar to the Office Open XML (OOXML) format.  Metadata tags in iWork
        files are extracted even if they don't appear below.
    },
    authors   => { Name => 'Author', Groups => { 2 => 'Author' } },
    comment   => { },
    copyright => { Groups => { 2 => 'Author' } },
    keywords  => { },
    projects  => { List => 1 },
    title     => { },
);

#------------------------------------------------------------------------------
# Generate a tag ID for this XML tag
# Inputs: 0) tag property name list ref
# Returns: tagID
sub GetTagID($)
{
    my $props = shift;
    return 0 if $$props[-1] =~ /^\w+:ID$/;  # ignore ID tags
    return $$props[0] =~ /^.*?:(.*)/ ? $1 : $$props[0];
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

    $et->VPrint(0, "  | - Tag '", join('/',@$props), "'\n") if $verbose > 1;

    # un-escape XML character entities
    $val = Image::ExifTool::XMP::UnescapeXML($val);
    # convert from UTF8 to ExifTool Charset
    $val = $et->Decode($val, 'UTF8');
    my $tag = GetTagID($props) or return 0;

    # add any unknown tags to table
    unless ($$tagTablePtr{$tag}) {
        $et->VPrint(0, "  [adding $tag]\n") if $verbose;
        AddTagToTable($tagTablePtr, $tag, { Name => ucfirst $tag });
    }
    # save the tag
    $et->HandleTag($tagTablePtr, $tag, $val);

    return 1;
}

#------------------------------------------------------------------------------
# Extract information from an iWork file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1
# Notes: Upon entry to this routine, the file type has already been verified
# as ZIP and the dirInfo hash contains a 'ZIP' Archive::Zip object reference
sub Process_iWork($$)
{
    my ($et, $dirInfo) = @_;
    my $zip = $$dirInfo{ZIP};
    my ($type, $index, $indexFile, $status);

    # try to determine the file type
    local $SIG{'__WARN__'} = \&Image::ExifTool::ZIP::WarnProc;
    # trust type given by file extension if available
    $type = $iWorkType{$$et{FILE_EXT}} if $$et{FILE_EXT};
    unless ($type) {
        # read the index file
        my @members = $zip->membersMatching('^index\.(xml|apxl)$');
        if (@members) {
            ($index, $status) = $zip->contents($members[0]);
            unless ($status) {
                $indexFile = $members[0]->fileName();
                if ($index =~ /^\s*<\?xml version=[^<]+<(\w+:\w+)/s) {
                    $type = $iWorkType{$1} if $iWorkType{$1};
                }
            }
        } else {
            @members = $zip->membersMatching('(?i)^.*\.(pages|numbers|key)/Index.*');
            if (@members) {
                my $tmp = $members[0]->fileName();
                $type = $iWorkType{uc $1} if $tmp =~ /\.(pages|numbers|key)/i;
            }
        }
        $type or $type = 'ZIP';     # assume ZIP by default
    }
    $et->SetFileType($type, $mimeType{$type});

    my @members = $zip->members();
    my $docNum = 0;
    my $member;
    foreach $member (@members) {
        # get filename of this ZIP member
        my $file = $member->fileName();
        next unless defined $file;
        $et->VPrint(0, "File: $file\n");
        # set the document number and extract ZIP tags
        $$et{DOC_NUM} = ++$docNum;
        Image::ExifTool::ZIP::HandleMember($et, $member);

        # process only the index XML and JPEG thumbnail/preview files
        next unless $file =~ m{^(index\.(xml|apxl)|QuickLook/Thumbnail\.jpg|[^/]+/preview(-micro|-web)?.jpg)$}i;
        # get the file contents if necessary
        # (CAREFUL! $buff MUST be local since we hand off a value ref to PreviewImage)
        my ($buff, $buffPt);
        if ($indexFile and $indexFile eq $file) {
            # use the index file we already loaded
            $buffPt = \$index;
        } else {
            ($buff, $status) = $zip->contents($member);
            $status and $et->Warn("Error extracting $file"), next;
            $buffPt = \$buff;
        }
        # extract JPEG as PreviewImage (should only be QuickLook/Thumbnail.jpg)
        if ($file =~ /\.jpg$/) {
            my $type = ($file =~ /preview-(\w+)/) ? ($1 eq 'web' ? 'Other' : 'Thumbnail') : 'Preview';
            $et->FoundTag($type . 'Image', $buffPt);
            next;
        }
        # process "metadata" section of XML index file
        next unless $$buffPt =~ /<(\w+):metadata>/g;
        my $ns = $1;
        my $p1 = pos $$buffPt;
        next unless $$buffPt =~ m{</${ns}:metadata>}g;
        # construct XML data from "metadata" section only
        $$buffPt = '<?xml version="1.0"?>' . substr($$buffPt, $p1, pos($$buffPt)-$p1);
        my %dirInfo = (
            DataPt => $buffPt,
            DirLen => length $$buffPt,
            DataLen => length $$buffPt,
            XMPParseOpts => {
                FoundProc => \&FoundTag,
            },
        );
        my $tagTablePtr = GetTagTable('Image::ExifTool::iWork::Main');
        $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        undef $$buffPt; # (free memory now)
    }
    delete $$et{DOC_NUM};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::iWork - Read Apple iWork '09 XML+ZIP files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Apple iWork '09 XML+ZIP files.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/iWork Tags>,
L<Image::ExifTool::TagNames/OOXML Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

