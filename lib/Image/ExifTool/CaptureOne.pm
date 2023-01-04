#------------------------------------------------------------------------------
# File:         CaptureOne.pm
#
# Description:  Read Capture One EIP and COS files
#
# Revisions:    2009/11/01 - P. Harvey Created
#
# Notes:        The EIP format is a ZIP file containing an image (IIQ or TIFF)
#               and some settings files (COS).  COS files are XML based.
#------------------------------------------------------------------------------

package Image::ExifTool::CaptureOne;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;
use Image::ExifTool::ZIP;

$VERSION = '1.04';

# CaptureOne COS XML tags
# - tags are added dynamically when encountered
# - this table is not listed in tag name docs
%Image::ExifTool::CaptureOne::Main = (
    GROUPS => { 0 => 'XML', 1 => 'XML', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::XMP::ProcessXMP,
    VARS => { NO_ID => 1 },
    ColorCorrections => { ValueConv => '\$val' }, # (long list of floating point numbers)
);

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) attribute list ref, 1) attr hash ref,
#         2) property name ref, 3) property value ref
# Returns: true if value was changed
sub HandleCOSAttrs($$$$)
{
    my ($attrList, $attrs, $prop, $valPt) = @_;
    my $changed;
    if (not length $$valPt and defined $$attrs{K} and defined $$attrs{V}) {
        $$prop = $$attrs{K};
        $$valPt = $$attrs{V};
        # remove these attributes from the list
        my @attrs = @$attrList;
        @$attrList = ( );
        my $a;
        foreach $a (@attrs) {
            if ($a eq 'K' or $a eq 'V') {
                delete $$attrs{$a};
            } else {
                push @$attrList, $a;
            }
        }
        $changed = 1;
    }
    return $changed;
}

#------------------------------------------------------------------------------
# We found a COS property name/value
# Inputs: 0) ExifTool object ref, 1) tag table ref
#         2) reference to array of XMP property names (last is current property)
#         3) property value, 4) attribute hash ref (not used here)
# Returns: 1 if valid tag was found
sub FoundCOS($$$$;$)
{
    my ($et, $tagTablePtr, $props, $val, $attrs) = @_;

    my $tag = $$props[-1];
    unless ($$tagTablePtr{$tag}) {
        $et->VPrint(0, "  | [adding $tag]\n");
        my $name = ucfirst $tag;
        $name =~ tr/-_a-zA-Z0-9//dc;
        return 0 unless length $tag;
        my %tagInfo = ( Name => $tag );
        # try formatting any tag with "Date" in the name as a date
        # (shouldn't affect non-date tags)
        if ($name =~ /Date(?![a-z])/) {
            $tagInfo{Groups} = { 2 => 'Time' };
            $tagInfo{ValueConv} = 'Image::ExifTool::XMP::ConvertXMPDate($val,1)';
            $tagInfo{PrintConv} = '$self->ConvertDateTime($val)';
        }
        AddTagToTable($tagTablePtr, $tag, \%tagInfo);
    }
    # convert from UTF8 to ExifTool Charset
    $val = $et->Decode($val, "UTF8");
    # un-escape XML character entities
    $val = Image::ExifTool::XMP::UnescapeXML($val);
    $et->HandleTag($tagTablePtr, $tag, $val);
    return 0;
}

#------------------------------------------------------------------------------
# Extract information from a COS file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid XML file
sub ProcessCOS($$)
{
    my ($et, $dirInfo) = @_;

    # process using XMP module, but override handling of attributes and tags
    $$dirInfo{XMPParseOpts} = {
        AttrProc => \&HandleCOSAttrs,
        FoundProc => \&FoundCOS,
    };
    my $tagTablePtr = GetTagTable('Image::ExifTool::CaptureOne::Main');
    my $success = $et->ProcessDirectory($dirInfo, $tagTablePtr);
    delete $$dirInfo{XMLParseArgs};
    return $success;
}

#------------------------------------------------------------------------------
# Extract information from a CaptureOne EIP file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1
# Notes: Upon entry to this routine, the file type has already been verified
# and the dirInfo hash contains a ZIP element unique to this process proc:
#   ZIP     - reference to Archive::Zip object for this file
sub ProcessEIP($$)
{
    my ($et, $dirInfo) = @_;
    my $zip = $$dirInfo{ZIP};
    my ($file, $buff, $status, $member, %parseFile);

    $et->SetFileType('EIP');

    # must catch all Archive::Zip warnings
    local $SIG{'__WARN__'} = \&Image::ExifTool::ZIP::WarnProc;
    # find all manifest files
    my @members = $zip->membersMatching('^manifest\d*.xml$');
    # and choose the one with the highest version number (any better ideas?)
    while (@members) {
        my $m = shift @members;
        my $f = $m->fileName();
        next if $file and $file gt $f;
        $member = $m;
        $file = $f;
    }
    # get file names from our chosen manifest file
    if ($member) {
        ($buff, $status) = $zip->contents($member);
        if (not $status) {
            my $foundImage;
            while ($buff =~ m{<(RawPath|SettingsPath)>(.*?)</\1>}sg) {
                $file = $2;
                next unless $file =~ /\.(cos|iiq|jpe?g|tiff?)$/i;
                $parseFile{$file} = 1;    # set flag to parse this file
                $foundImage = 1 unless $file =~ /\.cos$/i;
            }
            # ignore manifest unless it contained a valid image
            undef %parseFile unless $foundImage;
        }
    }
    # extract meta information from embedded files
    my $docNum = 0;
    @members = $zip->members(); # get all members
    foreach $member (@members) {
        # get filename of this ZIP member
        $file = $member->fileName();
        next unless defined $file;
        $et->VPrint(0, "File: $file\n");
        # set the document number and extract ZIP tags
        $$et{DOC_NUM} = ++$docNum;
        Image::ExifTool::ZIP::HandleMember($et, $member);
        if (%parseFile) {
            next unless $parseFile{$file};
        } else {
            # reading the manifest didn't work, so look for image files in the
            # root directory and .cos files in the CaptureOne directory
            next unless $file =~ m{^([^/]+\.(iiq|jpe?g|tiff?)|CaptureOne/.*\.cos)$}i;
        }
        # extract the contents of the file
        # Note: this could use a LOT of memory here for RAW images...
        ($buff, $status) = $zip->contents($member);
        $status and $et->Warn("Error extracting $file"), next;
        if ($file =~ /\.cos$/i) {
            # process Capture One Settings files
            my %dirInfo = (
                DataPt => \$buff,
                DirLen => length $buff,
                DataLen => length $buff,
            );
            ProcessCOS($et, \%dirInfo);
        } else {
            # set HtmlDump error if necessary because it doesn't work with embedded files
            if ($$et{HTML_DUMP}) {
                $$et{HTML_DUMP}{Error} = "Sorry, can't dump images embedded in ZIP files";
            }
            # process IIQ, JPEG and TIFF images
            $et->ExtractInfo(\$buff, { ReEntry => 1 });
        }
        undef $buff;    # (free memory now)
    }
    delete $$et{DOC_NUM};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::CaptureOne - Read Capture One EIP and COS files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Capture One EIP (Enhanced Image Package) and COS (Capture
One Settings) files.

=head1 NOTES

The EIP format is a ZIP file containing an image (IIQ or TIFF) and some
settings files (COS).

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ZIP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

