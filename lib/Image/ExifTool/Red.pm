#------------------------------------------------------------------------------
# File:         Red.pm
#
# Description:  Read Redcode R3D video files
#
# Revisions:    2018-01-25 - P. Harvey Created
#
# References:   1) http://www.wikiwand.com/en/REDCODE
#------------------------------------------------------------------------------

package Image::ExifTool::Red;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

sub ProcessR3D($$);

# RED format codes (ref PH)
my %redFormat = (
    0 => 'int8u',
    1 => 'string',
    2 => 'float',
    3 => 'int8u',   # (how is this different than 0?)
    4 => 'int16u',
    5 => 'int8s',   # (not sure about this)
    6 => 'int32s',
    7 => 'undef',   # (mixed-format structure?)
    8 => 'int32u',  # (NC)
    9 => 'undef',   # ? (seen 256 bytes, all zero)
);

# error strings
my $errTrunc = 'Truncated R3D file';

# RED directory tags (ref PH)
%Image::ExifTool::Red::Main = (
    GROUPS => { 2 => 'Camera' },
    NOTES => 'Tags extracted from Redcode R3D video files.',
    VARS => { ALPHA_FIRST => 1 },

    RED1 => { Name => 'Red1Header', SubDirectory => { TagTable => 'Image::ExifTool::Red::RED1' } },
    RED2 => { Name => 'Red2Header', SubDirectory => { TagTable => 'Image::ExifTool::Red::RED2' } },

    # (upper 4 bits of tag ID are the format code)
    # ---- format 1 ----
    0x1000 => 'StartEdgeCode', #1
    0x1001 => { Name => 'StartTimecode', Groups => { 2 => 'Time' } }, #1
    0x1002 => { #1
        Name => 'OtherDate1',
        Groups => { 2 => 'Time' },
        # format is "YYYY_MM_DD[_TZ?]"
        ValueConv => '$val =~ s/(\d{4})_(\d{2})_/$1:$2:/; $val =~ tr/_/ /; $val',
    },
    0x1003 => { #1
        Name => 'OtherDate2',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4})_(\d{2})_/$1:$2:/; $val =~ tr/_/ /; $val',
    },
    0x1004 => { #1
        Name => 'OtherDate3',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4})_(\d{2})_/$1:$2:/; $val =~ tr/_/ /; $val',
    },
    0x1005 => { #1
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/$1:$2:$3 $4:$5:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x1006 => 'SerialNumber', #1
    0x1019 => 'CameraType', #1
    0x101a => { Name => 'ReelNumber', Groups => { 2 => 'Video' } }, #1
    0x101b => { Name => 'Take', Groups => { 2 => 'Video' } },
    0x1023 => { #1
        Name => 'DateCreated',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4})(\d{2})/$1:$2:/; $val',
    },
    0x1024 => { #1
        Name => 'TimeCreated',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{2})(\d{2})/$1:$2:/; $val',
    },
    0x1025 => 'FirmwareVersion', #1
    0x1029 => { Name => 'ReelTimecode', Groups => { 2 => 'Time' } }, #1
    0x102a => 'StorageType', #1
    0x1030 => { #1
        Name => 'StorageFormatDate',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4})(\d{2})/$1:$2:/; $val',
    },
    0x1031 => { #1
        Name => 'StorageFormatTime',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{2})(\d{2})/$1:$2:/; $val',
    },
    0x1032 => 'StorageSerialNumber', #1
    0x1033 => 'StorageModel', #1
    0x1036 => 'AspectRatio', #1
  # 0x1041 - seen 'NA'
    0x1042 => 'Revision', # ? (seen "TODO, rev EPIC-1.0" and "MYSTERIUM X, rev EPIC-1.0")
  # 0x1051 - seen 'C', 'L'
    0x1056 => 'OriginalFileName',
    0x106e => 'LensMake',
    0x106f => 'LensNumber', # (last 2 hex digits are LensType)
    0x1070 => 'LensModel',
    0x1071 => {
        Name => 'Model',
        Description => 'Camera Model Name',
    },
    0x107c => { Name => 'CameraOperator', Groups => { 2 => 'Author' } },
    0x1086 => {
        Name => 'VideoFormat',
        Groups => { 2 => 'Video' },
    },
    0x1096 => 'Filter', # optical low-pass filter
    0x10a0 => 'Brain',
    0x10a1 => 'Sensor',
    # ---- format 2 ----
    0x200d => 'ColorTemperature',
  # 0x200e - (sometimes this is frame rate)
  # 0x2015 - seen '1 1 1' (RGBGain or RGBGamma?)
    0x204b => 'RGBCurves', # (blackx/y,toex/y,midx/y,kneex/y,whitex/y)
    0x2066 => {
        Name => 'OriginalFrameRate',
        Groups => { 2 => 'Video' },
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    # ---- format 4 ----
    0x4037 => { Name => 'CropArea' }, # (NC)
    0x403b => 'ISO',
  # 0x404e - related to CropArea (or "0 0 0 0")
    0x406a => { Name => 'FNumber', ValueConv => '$val / 10' },
    0x406b => 'FocalLength',
  # 0x4084 - related to ISO?
  # 0x4087 - related to ISO?
    # ---- format 6 ----
    0x606c => { Name => 'FocusDistance', ValueConv => '$val/1000', PrintConv => '"$val m"' },
);

# RED1 file header (ref PH)
%Image::ExifTool::Red::RED1 = (
    GROUPS => { 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'Redcode version 1 header.',
  # 0x00 - int32u: length of header
  # 0x04 - string: "RED1"
  # 0x0a - string: "R1"
    0x07 => { Name => 'RedcodeVersion',   Format => 'string[1]' }, #1
  # 0x0e - looks funny; my sample has a value of 43392 here
  # 0x0e => { Name => 'AudioSampleRate',  Format => 'int16u' }, #1
    0x36 => { Name => 'ImageWidth',       Format => 'int16u' }, #1
    0x3a => { Name => 'ImageHeight',      Format => 'int16u' }, #PH (ref 1 gave 0x3c)
    0x3e => { #PH (ref 1 gave 0x42 for denom)
        Name => 'FrameRate',
        Format => 'rational32u',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    0x43 => { Name => 'OriginalFileName', Format => 'string[32]' }, #1
);

# RED2 file header (ref PH)
%Image::ExifTool::Red::RED2 = (
    GROUPS => { 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'Redcode version 2 header.',
  # 0x00 - int32u: length of header
  # 0x04 - string: "RED2"
    0x07 => { Name => 'RedcodeVersion', Format => 'string[1]' },
  # 0x08 - seen 0x05
  # 0x09 - seen 0x0d,0x0f,0x10
  # 0x0a - string: "R2"
  # 0x0c - seen 0x04,0x05,0x07,0x08,0x0b,0x0c
  # 0x0d - seen 0x01,0x08 (and 0x09 in block 1)
  # 0x0e - int16u: seen 3072
  # 0x10 - looks like some sort of 32-byte hash or something (same in other blocks)
  # 0x30-0x3f - mostly 0x00's with a couple of 0x01's
  # 0x40 - int8u: count of 0x18-byte "rdi" records
  # 0x41-0x43 - seen "\0\0\x01"
    # ---- rdi record: (0x18 bytes long) ----
  # 0x44 - string: "rdi#" (where number is index of "rdi" record, starting at \x01)
    0x4c => { Name => 'ImageWidth',     Format => 'int32u' },
    0x50 => { Name => 'ImageHeight',    Format => 'int32u' },
  # 0x54 - seen 0x11,0x13,0x15 (and 0x03 in "rdi\x02" record)
  # 0x55 - seen 0x02
    0x56 => {
        Name => 'FrameRate',
        Format => 'int16u[3]',
        ValueConv => 'my @a = split " ",$val; ($a[1] * 0x10000 + $a[2]) / $a[0]',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    # (immediately following last "rdi" record is a
    #  Red directory beginning with int16u size)
);

#------------------------------------------------------------------------------
# Process metadata from a Redcode R3D video (ref PH)
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid R3D file
sub ProcessR3D($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $pos, $dirLen, $dirEnd);
    my $verbose = $et->Options('Verbose');

    # R3D file structure:
    # - each block starts with int32u block size followed by 4-byte block type
    # - first block type is either "RED1" (version 1) or "RED2" (version 2)
    # - blocks begin on even 0x1000 byte boundaries for version 2 files

    # validate the file header
    return 0 unless $raf->Read($buff, 8) == 8 and $buff =~ /^\0\0..RED(1|2)/s;
    my $ver = $1;
    my $size = unpack('N', $buff);
    return 0 if $size < 8;

    $et->SetFileType();
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::Red::Main');
    my $dataPos = 0;

    # read the first block of the file
    $raf->Read($buf2, $size - 8) == $size - 8 or return $et->Warn($errTrunc);
    $buff .= $buf2;

    # extract tags from the header
    $et->HandleTag($tagTablePtr, "RED$ver", undef, DataPt => \$buff);

    # read the second block from a version 1 file because
    # the first block doesn't contain a Red directory
    if ($ver eq '1') {
        # (read more than we need)
        $raf->Read($buff, 0x10000) or return $et->Warn($errTrunc);
        $dataPos += $size;
        $pos = 0x22;    # directory starts at offset 0x22
    } else {
        # calculate position of Red directory start
        length($buff) < 0x41 and return $et->Warn($errTrunc);
        my $n = Get8u(\$buff, 0x40);    # number of "rdi" records
        $pos = 0x44 + $n * 0x18;
    }
    if ($pos + 8 > length $buff) {
        $dirLen = 0;    # find directory the hard way
    } else {
        $dirLen = Get16u(\$buff, $pos);  # get length of Red directory
        $pos += 2;      # skip length word
    }
    # do sanity check on the directory size (in case our assumptions were wrong)
    if ($dirLen < 300 or $dirLen >= 2048 or $pos + $dirLen > length $buff) {
        # tag 0x1000 with length 0x000f should be near the directory start
        $buff =~ /\0\x0f\x10\0/g or return $et->Warn("Can't find Red directory");
        $pos = pos($buff) - 4;
        $dirEnd = length $buff;
        undef $dirLen;
        $et->Warn('This R3D file is different. Please submit a sample for testing');
    } else {
        $dirEnd = $pos + $dirLen;
    }
    $$et{INDENT} .= '| ', $et->VerboseDir('Red', undef, $dirLen) if $verbose;

    # process the first Red directory
    while ($pos + 4 <= $dirEnd) {
        my $len = Get16u(\$buff, $pos);
        last if $len < 4 or $pos + $len > $dirEnd;
        my $tag = Get16u(\$buff, $pos + 2);
        my $fmt = $redFormat{$tag >> 12};   # format is top 4 bits of tag ID (ref PH)
        $fmt or $dirLen && $et->Warn('Unknown format code'), last;
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => \$buff,
            DataPos => $dataPos,
            Start   => $pos + 4,
            Size    => $len - 4,
            Format  => $fmt,
        );
        $pos += $len;
    }
    $$et{INDENT} = substr($$et{INDENT}, 0, -2) if $verbose;

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Red - Read Redcode R3D video files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read metadata
from Redcode R3D version 1 and 2 video files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.wikiwand.com/en/REDCODE>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Red Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

