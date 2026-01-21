#------------------------------------------------------------------------------
# File:         HP.pm
#
# Description:  Hewlett-Packard maker notes tags
#
# Revisions:    2007-05-03 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::HP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

sub ProcessHP($$$);
sub ProcessTDHD($$$);

# HP EXIF-format maker notes (or is it Vivitar?)
%Image::ExifTool::HP::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tables list tags found in the maker notes of some Hewlett-Packard
        camera models.

        The first table lists tags found in the EXIF-format maker notes of the
        PhotoSmart 720 (also used by the Vivitar ViviCam 3705, 3705B and 3715).
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);

# other types of HP maker notes
%Image::ExifTool::HP::Type2 = (
    PROCESS_PROC => \&ProcessHP,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are used by the PhotoSmart E427.',
   'PreviewImage' => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
   'Serial Number' => 'SerialNumber',
   'Lens Shading'  => 'LensShading',
);

%Image::ExifTool::HP::Type4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are used by the PhotoSmart M627.',
    0x0c => {
        Name => 'MaxAperture',
        Format => 'int16u',
        ValueConv => '$val / 10',
    },
    0x10 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x14 => {
        Name => 'CameraDateTime',
        Groups => { 2 => 'Time' },
        Format => 'string[20]',
    },
    0x34 => {
        Name => 'ISO',
        Format => 'int16u',
    },
    0x5c => {
        Name => 'SerialNumber',
        Format => 'string[26]',
        RawConv => '$val =~ s/^SERIAL NUMBER:// ? $val : undef',
    },
);

%Image::ExifTool::HP::Type6 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are used by the PhotoSmart M425, M525 and M527.',
    0x0c => {
        Name => 'FNumber',
        Format => 'int16u',
        ValueConv => '$val / 10',
    },
    0x10 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x14 => {
        Name => 'CameraDateTime',
        Groups => { 2 => 'Time' },
        Format => 'string[20]',
    },
    0x34 => {
        Name => 'ISO',
        Format => 'int16u',
    },
    0x58 => {
        Name => 'SerialNumber',
        Format => 'string[26]',
        RawConv => '$val =~ s/^SERIAL NUMBER:// ? $val : undef',
    },
);

# proprietary format TDHD data written by Photosmart R837 (ref PH)
%Image::ExifTool::HP::TDHD = (
    PROCESS_PROC => \&ProcessTDHD,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from the APP6 "TDHD" segment of Photosmart R837
        JPEG images.  Many other unknown tags exist in is data, and can be seen with
        the L<Unknown|../ExifTool.html#Unknown> (-u) option.
    },
    # (all subdirectories except TDHD and LSLV are automatically recognized
    # by their "type" word of 0x10001)
    TDHD => {
        Name => 'TDHD',
        SubDirectory => { TagTable => 'Image::ExifTool::HP::TDHD' },
    },
    LSLV => {
        Name => 'LSLV',
        SubDirectory => { TagTable => 'Image::ExifTool::HP::TDHD' },
    },
    FWRV => 'FirmwareVersion',
    CMSN => 'SerialNumber', # (unverified)
    # LTEM - some temperature?
);

#------------------------------------------------------------------------------
# Process HP APP6 TDHD metadata (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessTDHD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $pos = $$dirInfo{DirStart};
    my $dirEnd = $pos + $$dirInfo{DirLen};
    my $unknown = $et->Options('Unknown') || $et->Options('Verbose');
    $et->VerboseDir('TDHD', undef, $$dirInfo{DirLen});
    SetByteOrder('II');
    while ($pos + 12 < $dirEnd) {
        my $tag = substr($$dataPt, $pos, 4);
        my $type = Get32u($dataPt, $pos + 4);
        my $size = Get32u($dataPt, $pos + 8);
        $pos += 12;
        last if $size < 0 or $pos + $size > $dirEnd;
        if ($type == 0x10001) {
            # this is a subdirectory containing more tags
            my %dirInfo = (
                DataPt   => $dataPt,
                DataPos  => $dataPos,
                DirStart => $pos,
                DirLen   => $size,
            );
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } else {
            if (not $$tagTablePtr{$tag} and $unknown) {
                my $name = $tag;
                $name =~ tr/-_A-Za-z0-9//dc;    # remove invalid characters
                my %tagInfo = (
                    Name => "HP_TDHD_$name",
                    Unknown => 1,
                );
                # guess format based on data size
                if ($size == 1) {
                    $tagInfo{Format} = 'int8u';
                } elsif ($size == 2) {
                    $tagInfo{Format} = 'int16u';
                } elsif ($size == 4) {
                    $tagInfo{Format} = 'int32s';
                } elsif ($size > 80) {
                    $tagInfo{Binary} = 1;
                }
                AddTagToTable($tagTablePtr, $tag, \%tagInfo);
            }
            $et->HandleTag($tagTablePtr, $tag, undef,
                DataPt  => $dataPt,
                DataPos => $dataPos,
                Start   => $pos,
                Size    => $size,
            );
        }
        $pos += $size;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process HP maker notes
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessHP($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = $$dirInfo{DataLen};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $dataLen - $dirStart;

    # look for known text-type tags
    if ($dirStart or $dirLen != length($$dataPt)) {
        my $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
    }
    my $tagID;
    # brute-force scan for PreviewImage
    if ($$tagTablePtr{PreviewImage} and $$dataPt =~ /(\xff\xd8\xff\xdb.*\xff\xd9)/gs) {
        $et->HandleTag($tagTablePtr, 'PreviewImage', $1);
        # truncate preview to speed subsequent tag scans
        my $buff = substr($$dataPt, 0, pos($$dataPt)-length($1));
        $dataPt = \$buff;
    }
    # scan for other tag ID's
    foreach $tagID (sort(TagTableKeys($tagTablePtr))) {
        next if $tagID eq 'PreviewImage';
        next unless $$dataPt =~ /$tagID:\s*([\x20-\x7e]+)/i;
        $et->HandleTag($tagTablePtr, $tagID, $1);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::HP - Hewlett-Packard maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Hewlett-Packard maker notes.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/HP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
