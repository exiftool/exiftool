#------------------------------------------------------------------------------
# File:         Reconyx.pm
#
# Description:  Reconyx maker notes tags
#
# Revisions:    2011-01-11 - P. Harvey Created
#
# References:   1) RCNX_MN10.pdf (courtesy of Reconyx Inc.)
#               2) ultrafire_makernote.pdf (courtesy of Reconyx Inc.)
#               3) Reconyx private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Reconyx;

use strict;
use vars qw($VERSION);

$VERSION = '1.06';

# info for Type2 version tags
my %versionInfo = (
    Format => 'undef[7]',
    ValueConv => 'sprintf("V%.2x.%.2x %.4x:%.2x:%.2x Rev.%s", unpack("CCvCCa", $val))',
    ValueConvInv => q{
        my @v = $val =~ /^V([0-9a-f]+)\.([0-9a-f]+) (\d{4}):(\d{2}):(\d{2})\s*Rev\.(\w)/i or return undef;
        pack('CCvCCa', map(hex, @v[0..4]), $v[5]);
    },
);

# maker notes for Reconyx Hyperfire cameras (ref PH)
%Image::ExifTool::Reconyx::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    TAG_PREFIX => 'Reconyx',
    FORMAT => 'int16u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => q{
        The following tags are extracted from the maker notes of Reconyx Hyperfire
        cameras such as the HC500, HC600 and PC900.
    },
    0x00 => { #1
        Name => 'MakerNoteVersion',
        PrintConv => 'sprintf("0x%.4x", $val)',
        Writable => 0, # (we use this for identification, 0xf101 --> rev 1.0)
        PrintConvInv => 'hex $val',
    },
    0x01 => { #1
        Name => 'FirmwareVersion',
        Format => 'int16u[3]',
        PrintConv => '$val=~tr/ /./; $val',
        Writable => 0, # (we use this for identification, 0x0003 --> ver 2 or 3)
    },
    0x04 => { #1
        Name => 'FirmwareDate',
        Format => 'int16u[2]',
        ValueConv => q{
            my @v = split(' ',$val);
            sprintf('%.4x:%.2x:%.2x', $v[0], $v[1]>>8, $v[1]&0xff);
        },
        ValueConvInv => q{
            my @v = split(':', $val);
            hex($v[0]) . ' ' . hex($v[1] . $v[2]);
        },
    },
    0x06 => {
        Name => 'TriggerMode',
        Format => 'string[2]',
        PrintConv => {
            C => 'CodeLoc Not Entered', #1
            E => 'External Sensor', #1
            M => 'Motion Detection',
            T => 'Time Lapse',
        },
    },
    0x07 => {
        Name => 'Sequence',
        Format => 'int16u[2]',
        PrintConv => '$val =~ s/ / of /; $val',
        PrintConvInv => 'join(" ", $val=~/\d+/g)',
    },
    0x09 => { #1
        Name => 'EventNumber',
        Format => 'int16u[2]',
        ValueConv => 'my @v=split(" ",$val); ($v[0]<<16) + $v[1]',
        ValueConvInv => '($val>>16) . " " . ($val&0xffff)',
    },
    0x0b => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int16u[6]',
        Groups => { 2 => 'Time' },
        Priority => 0, # (not as reliable as EXIF)
        Shift => 'Time',
        ValueConv => q{
            my @a = split ' ', $val;
            # have seen these values written big-endian when everything else is little-endian
            if ($a[0] & 0xff00 and not $a[0] & 0xff) {
                $_ = ($_ >> 8) | (($_ & 0xff) << 8) foreach @a;
            }
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @a[5,3,4,2,1,0]);
        },
        ValueConvInv => q{
            my @a = ($val =~ /\d+/g);
            return undef unless @a >= 6;
            join ' ', @a[5,4,3,1,2,0];
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x12 => {
        Name => 'MoonPhase',
        Groups => { 2 => 'Time' },
        PrintConv => {
            0 => 'New',
            1 => 'New Crescent',
            2 => 'First Quarter',
            3 => 'Waxing Gibbous',
            4 => 'Full',
            5 => 'Waning Gibbous',
            6 => 'Last Quarter',
            7 => 'Old Crescent',
        },
    },
    0x13 => {
        Name => 'AmbientTemperatureFahrenheit',
        Format => 'int16s',
        PrintConv => '"$val F"',
        PrintConvInv => '$val=~/(-?\d+)/ ? $1 : $val',
    },
    0x14 => {
        Name => 'AmbientTemperature',
        Format => 'int16s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~/(-?\d+)/ ? $1 : $val',
    },
    0x15 => {
        Name => 'SerialNumber',
        Format => 'undef[30]',
        RawConv => '$_ = $self->Decode($val, "UCS2"); s/\0.*//; $_',
        RawConvInv => q{
            $_ = $self->Encode($val, "UCS2");
            $_ = substr($_, 0, 30) if length($_) > 30;
            return $_;
        },
    },
    0x24 => 'Contrast', #1
    0x25 => 'Brightness', #1
    0x26 => 'Sharpness', #1
    0x27 => 'Saturation', #1
    0x28 => {
        Name => 'InfraredIlluminator',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x29 => 'MotionSensitivity', #1
    0x2a => { #1
        Name => 'BatteryVoltage',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '"$val V"',
        PrintConvInv => '$val=~s/ ?V$//; $val',
    },
    0x2b => {
        Name => 'UserLabel',
        Format => 'string[22]', #1 (but manual says 16-char limit)
    },
);

# maker notes for Reconyx UltraFire cameras (ref PH)
%Image::ExifTool::Reconyx::Type2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    TAG_PREFIX => 'Reconyx',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => 'Tags extracted from models such as the UltraFire.',
  # 0x0a - int32u makernote ID 0x00020000 #2
  # 0x0e - int16u makernote size #2
  # 0x12 - int32u public structure ID 0x07f100001 #2
  # 0x16 - int16u public structure size #2 (0x5d = start of public ID to end of UserLabel)
    0x18 => { Name => 'FirmwareVersion',   %versionInfo },
    0x1f => { Name => 'Micro1Version',     %versionInfo }, #2
    0x26 => { Name => 'BootLoaderVersion', %versionInfo }, #2
    0x2d => { Name => 'Micro2Version',     %versionInfo }, #2
    0x34 => {
        Name => 'TriggerMode',
        Format => 'undef[1]',
        PrintConv => {
            M => 'Motion Detection',
            T => 'Time Lapse',
            P => 'Point and Shoot', #2
        },
    },
    0x35 => {
        Name => 'Sequence',
        Format => 'int8u[2]',
        PrintConv => '$val =~ s/ / of /; $val',
        PrintConvInv => 'join(" ", $val=~/\d+/g)',
    },
    0x37 => { #2
        Name => 'EventNumber',
        Format => 'int32u',
    },
    0x3b => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int8u[7]',
        Groups => { 2 => 'Time' },
        Priority => 0, # (not as reliable as EXIF)
        Shift => 'Time',
        ValueConv => q{
            my @a = split ' ', $val;
            $a[5] += pop(@a) * 256;
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', reverse @a);
        },
        ValueConvInv => q{
            my @a = ($val =~ /\d+/g);
            return undef unless @a >= 6;
            unshift @a, ($a[0] >> 8);
            $a[1] -= $a[0] * 256;
            join ' ', @a[6,5,4,3,2,1,0];
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x42 => { #2
        Name => 'DayOfWeek',
        Groups => { 2 => 'Time' },
        PrintConv => {
            0 => 'Sunday',
            1 => 'Monday',
            2 => 'Tuesday',
            3 => 'Wednesday',
            4 => 'Thursday',
            5 => 'Friday',
            6 => 'Saturday',
        },
    },
    0x43 => {
        Name => 'MoonPhase',
        Groups => { 2 => 'Time' },
        PrintConv => {
            0 => 'New',
            1 => 'New Crescent',
            2 => 'First Quarter',
            3 => 'Waxing Gibbous',
            4 => 'Full',
            5 => 'Waning Gibbous',
            6 => 'Last Quarter',
            7 => 'Old Crescent',
        },
    },
    0x44 => {
        Name => 'AmbientTemperatureFahrenheit',
        Format => 'int16s',
        PrintConv => '"$val F"',
        PrintConvInv => '$val=~/(-?\d+)/ ? $1 : $val',
    },
    0x46 => {
        Name => 'AmbientTemperature',
        Format => 'int16s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~/(-?\d+)/ ? $1 : $val',
    },
    0x48 => {
        Name => 'Illumination',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x49 => {
        Name => 'BatteryVoltage',
        Format => 'int16u',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '"$val V"',
        PrintConvInv => '$val=~s/ ?V$//; $val',
    },
    0x4b => {
        Name => 'SerialNumber',
        Format => 'string[15]',
    },
    0x5a => {
        Name => 'UserLabel',
        Format => 'string[21]',
    },
);

# maker notes for Reconyx HF2 PRO cameras (ref 3)
%Image::ExifTool::Reconyx::Type3 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    TAG_PREFIX => 'Reconyx',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => 'Tags extracted from models such as the HF2 PRO.',
  # 0x0a => { Name => 'StructureVersion',   Format => 'int16u' },
  # 0x0c => { Name => 'ParentFileSize',     Format => 'int32u' },
    0x10 => { Name => 'FileNumber',         Format => 'int16u' },
    0x12 => { Name => 'DirectoryNumber',    Format => 'int16u' },
  # 0x14 => { Name => 'DirCreateDate',      Format => 'int16u' },
  # 0x16 => { Name => 'DirCreateTime',      Format => 'int16u' },
  # 0x18 - int16[8] SDCardLabel
  # 0x28 => { Name => 'MakerNoteVersion',   Format => 'int16u' },
    0x2a => {
        Name => 'FirmwareVersion',
        Format => 'int16u[3]',
        ValueConv => 'my @a = split " ",$val; sprintf("%d.%d%c",@a)',
        ValueConvInv => '$val=~/(\d+)\.(\d+)([a-zA-Z])/ ? "$1 $2 ".ord($3) : undef',
    },
    0x30 => {
        Name => 'FirmwareDate',
        Format => 'int16u[2]',
        ValueConv => 'my ($y,$d) = split " ", $val; sprintf("%.4x:%.2x:%.2x",$y,$d>>8,$d&0xff)',
        ValueConvInv => 'my @a=split ":", $val; hex($a[0])." ".hex($a[1].$a[2])',
    },
    0x34 => {
        Name => 'TriggerMode', #PH (NC) (called EventType in the Reconyx code)
        Format => 'string[2]',
        PrintConv => {
            M => 'Motion Detection', # (seen this one only)
            T => 'Time Lapse', # (NC)
            P => 'Point and Shoot', # (NC)
        },
    },
    0x36 => {
        Name => 'Sequence',
        Format => 'int16u[2]',
        PrintConv => '$val =~ s/ / of /; $val',
        PrintConvInv => 'join(" ", $val=~/\d+/g)',
    },
    0x3a => {
        Name => 'EventNumber',
        Format => 'int16u[2]',
        ValueConv => 'my @a=split " ",$val;($a[0]<<16)+$a[1]',
        ValueConvInv => '($val >> 16) . " " . ($val & 0xffff)',
    },
    0x3e => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int16u[6]',
        Groups => { 2 => 'Time' },
        Priority => 0, # (not as reliable as EXIF)
        Shift => 'Time',
        ValueConv => q{
            my @a = split ' ', $val;
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', reverse @a);
        },
        ValueConvInv => q{
            my @a = ($val =~ /\d+/g);
            return undef unless @a >= 6;
            join ' ', @a[6,5,4,3,2,1,0];
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x4a => { #2
        Name => 'DayOfWeek',
        Groups => { 2 => 'Time' },
        Format => 'int16u',
        PrintConv => {
            0 => 'Sunday',
            1 => 'Monday',
            2 => 'Tuesday',
            3 => 'Wednesday',
            4 => 'Thursday',
            5 => 'Friday',
            6 => 'Saturday',
        },
    },
    0x4c => {
        Name => 'MoonPhase',
        Groups => { 2 => 'Time' },
        Format => 'int16u',
        PrintConv => {
            0 => 'New',
            1 => 'New Crescent',
            2 => 'First Quarter',
            3 => 'Waxing Gibbous',
            4 => 'Full',
            5 => 'Waning Gibbous',
            6 => 'Last Quarter',
            7 => 'Old Crescent',
        },
    },
    0x4e => {
        Name => 'AmbientTemperatureFahrenheit',
        Format => 'int16s',
        PrintConv => '"$val F"',
        PrintConvInv => '$val=~/(-?\d+)/ ? $1 : $val',
    },
    0x50 => {
        Name => 'AmbientTemperature',
        Format => 'int16s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~/(-?\d+)/ ? $1 : $val',
    },
    0x52 => { Name => 'Contrast',           Format => 'int16u' },
    0x54 => { Name => 'Brightness',         Format => 'int16u' },
    0x56 => { Name => 'Sharpness',          Format => 'int16u' },
    0x58 => { Name => 'Saturation',         Format => 'int16u' },
    0x5a => { Name => 'Flash',              Format => 'int16u', PrintConv => { 0 => 'Off', 1 => 'On' } },
    0x5c => { Name => 'AmbientInfrared',    Format => 'int16u' },
    0x5e => { Name => 'AmbientLight',       Format => 'int16u' },
    0x60 => { Name => 'MotionSensitivity',  Format => 'int16u' },
    0x62 => { Name => 'BatteryVoltage',     Format => 'int16u' },
    0x64 => { Name => 'BatteryVoltageAvg',  Format => 'int16u' },
    0x66 => { Name => 'BatteryType',        Format => 'int16u' },
    0x68 => { Name => 'UserLabel',          Format => 'string[22]' },
    0x7e => { Name => 'SerialNumber',       Format => 'unicode[15]' },
);

__END__

=head1 NAME

Image::ExifTool::Reconyx - Reconyx maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
maker notes in images from Reconyx cameras.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Reconyx Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
