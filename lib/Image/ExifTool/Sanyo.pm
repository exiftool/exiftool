#------------------------------------------------------------------------------
# File:         Sanyo.pm
#
# Description:  Sanyo EXIF maker notes tags
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# Reference:    http://www.exif.org/makernotes/SanyoMakerNote.html
#------------------------------------------------------------------------------

package Image::ExifTool::Sanyo;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.16';

my %offOn = (
    0 => 'Off',
    1 => 'On',
);

%Image::ExifTool::Sanyo::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00ff => {
        # this is an absolute offset in the JPG file... odd - PH
        Name => 'MakerNoteOffset',
        Writable => 'int32u',
    },
    0x0100 => {
        Name => 'SanyoThumbnail',
        Groups => { 2 => 'Preview' },
        Writable => 'undef',
        WriteCheck => '$self->CheckImage(\$val)',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
    0x0200 => {
        Name => 'SpecialMode',
        Writable => 'int32u',
        Count => 3,
    },
    0x0201 => {
        Name => 'SanyoQuality',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0000 => 'Normal/Very Low',
            0x0001 => 'Normal/Low',
            0x0002 => 'Normal/Medium Low',
            0x0003 => 'Normal/Medium',
            0x0004 => 'Normal/Medium High',
            0x0005 => 'Normal/High',
            0x0006 => 'Normal/Very High',
            0x0007 => 'Normal/Super High',
            # have seen 0x11 with HD2000 in '8M-H JPEG' mode - PH
            0x0100 => 'Fine/Very Low',
            0x0101 => 'Fine/Low',
            0x0102 => 'Fine/Medium Low',
            0x0103 => 'Fine/Medium',
            0x0104 => 'Fine/Medium High',
            0x0105 => 'Fine/High',
            0x0106 => 'Fine/Very High',
            0x0107 => 'Fine/Super High',
            0x0200 => 'Super Fine/Very Low',
            0x0201 => 'Super Fine/Low',
            0x0202 => 'Super Fine/Medium Low',
            0x0203 => 'Super Fine/Medium',
            0x0204 => 'Super Fine/Medium High',
            0x0205 => 'Super Fine/High',
            0x0206 => 'Super Fine/Very High',
            0x0207 => 'Super Fine/Super High',
        },
    },
    0x0202 => {
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Macro',
            2 => 'View',
            3 => 'Manual',
        },
    },
    0x0204 => {
        Name => 'DigitalZoom',
        Writable => 'rational64u',
    },
    0x0207 => 'SoftwareVersion',
    0x0208 => 'PictInfo',
    0x0209 => 'CameraID',
    0x020e => {
        Name => 'SequentialShot',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'Standard',
            2 => 'Best',
            3 => 'Adjust Exposure',
        },
    },
    0x020f => {
        Name => 'WideRange',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x0210 => {
        Name => 'ColorAdjustmentMode',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x0213 => {
        Name => 'QuickShot',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x0214 => {
        Name => 'SelfTimer',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    # 0x0215 - Flash?
    0x0216 => {
        Name => 'VoiceMemo',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x0217 => {
        Name => 'RecordShutterRelease',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Record while down',
            1 => 'Press start, press stop',
        },
    },
    0x0218 => {
        Name => 'FlickerReduce',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x0219 => {
        Name => 'OpticalZoomOn',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x021b => {
        Name => 'DigitalZoomOn',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x021d => {
        Name => 'LightSourceSpecial',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x021e => {
        Name => 'Resaved',
        Writable => 'int16u',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    0x021f => {
        Name => 'SceneSelect',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Sport',
            2 => 'TV',
            3 => 'Night',
            4 => 'User 1',
            5 => 'User 2',
            6 => 'Lamp', #PH
        },
    },
    0x0223 => [
        {
            Name => 'ManualFocusDistance',
            Condition => '$format eq "rational64u"',
            Writable => 'rational64u',
        }, { #PH
            Name => 'FaceInfo',
            SubDirectory => { TagTable => 'Image::ExifTool::Sanyo::FaceInfo' },
        },
    ],
    0x0224 => {
        Name => 'SequenceShotInterval',
        Writable => 'int16u',
        PrintConv => {
            0 => '5 frames/s',
            1 => '10 frames/s',
            2 => '15 frames/s',
            3 => '20 frames/s',
        },
    },
    0x0225 => {
        Name => 'FlashMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Force',
            2 => 'Disabled',
            3 => 'Red eye',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x0f00 => {
        Name => 'DataDump',
        Writable => 0,
        Binary => 1,
    },
);

# face detection information (ref PH)
%Image::ExifTool::Sanyo::FaceInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => 'FacesDetected',
    4 => {
        Name => 'FacePosition',
        Format => 'int32u[4]',
        Notes => q{
            left, top, right and bottom coordinates of detected face in an unrotated
            640-pixel-wide image, with increasing Y downwards
        },
    },
);

# tags in Sanyo MOV videos (PH - observations from an E6 sample)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Sanyo::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is found in Sanyo MOV videos.',
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[8]',
    },
    # (01 00 at offset 0x20)
    0x26 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x2a => {
        Name => 'FNumber',
        Format => 'int32u',
        ValueConv => '$val / 10',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x32 => {
        Name => 'ExposureCompensation',
        Format => 'int32s',
        ValueConv => '$val / 10',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    0x44 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
        },
    },
    0x48 => {
        Name => 'FocalLength',
        Format => 'int32u',
        ValueConv => '$val / 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
);

# tags in Sanyo MP4 videos (PH - from C4, C5 and HD1A samples)
# --> very similar to Samsung MP4 information
# (there is still a lot more information here that could be decoded!)
%Image::ExifTool::Sanyo::MP4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is found in Sanyo MP4 videos.',
    0x00 => {
        Name => 'Make',
        Format => 'string[5]',
        PrintConv => 'ucfirst(lc($val))',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[8]',
    },
    # (01 00 at offset 0x28)
    # (0x2e has values 0x31, 0x33 and 0x3c in my samples, but
    # some of the shutter speeds should be around 1/500 or so)
    0x32 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x3a => { # (NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
    },
    0x6a => {
        Name => 'ISO',
        Format => 'int32u',
    },
    0xd1 => {
        Name => 'Software',
        Notes => 'these tags are shifted up by 1 byte for some models like the HD1A',
        Format => 'undef[32]',
        RawConv => q{
            $val =~ /^SANYO/ or return undef;
            $val =~ tr/\0//d;
            $$self{SanyoSledder0xd1} = 1;
            return $val;
        },
    },
    0xd2 => {
        Name => 'Software',
        Format => 'undef[32]',
        RawConv => q{
            $val =~ /^SANYO/ or return undef;
            $val =~ tr/\0//d;
            $$self{SanyoSledder0xd2} = 1;
            return $val;
        },
    },
    0xf1 => {
        Name => 'Thumbnail',
        Condition => '$$self{SanyoSledder0xd1}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sanyo::Thumbnail',
            Base => '$start',
        },
    },
    0xf2 => {
        Name => 'Thumbnail',
        Condition => '$$self{SanyoSledder0xd2}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sanyo::Thumbnail',
            Base => '$start',
        },
    },
);

# thumbnail image information found in MP4 videos (similar in Olympus,Samsung,Sanyo)
%Image::ExifTool::Sanyo::Thumbnail = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    FORMAT => 'int32u',
    1 => 'ThumbnailWidth',
    2 => 'ThumbnailHeight',
    3 => 'ThumbnailLength',
    4 => { Name => 'ThumbnailOffset', IsOffset => 1 },
);


#------------------------------------------------------------------------------
# Patch incorrect offsets in J1, J2, J4, S1, S3 and S4 maker notes
# Inputs: 0) valuePtr, 1) end of previous value, 2) value size, 3) tag ID, 4) write flag
sub FixOffsets($$$$;$)
{
    my ($valuePtr, $valEnd, $size, $tagID, $wFlag) = @_;
    # ignore existing offsets and calculate reasonable values instead
    if ($tagID == 0x100) {
        # just ignore the SanyoThumbnail when writing (pointer is garbage)
        $_[0] = undef if $wFlag;
    } else {
        $_[0] = $valEnd;    # set value pointer to next logical location
        ++$size if $size & 0x01;
        $_[1] += $size;     # update end-of-value pointer
    }
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::Sanyo - Sanyo EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sanyo maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.exif.org/makernotes/SanyoMakerNote.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sanyo Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
