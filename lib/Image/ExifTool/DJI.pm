#------------------------------------------------------------------------------
# File:         DJI.pm
#
# Description:  DJI Phantom maker notes tags
#
# Revisions:    2016-07-25 - P. Harvey Created
#               2017-06-23 - PH Added XMP tags
#------------------------------------------------------------------------------

package Image::ExifTool::DJI;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;
use Image::ExifTool::XMP;
use Image::ExifTool::GPS;

$VERSION = '1.04';

my %convFloat2 = (
    PrintConv => 'sprintf("%+.2f", $val)',
    PrintConvInv => '$val',
);

# DJI maker notes (ref PH, mostly educated guesses based on DJI QuickTime::UserData tags)
%Image::ExifTool::DJI::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This table lists tags found in the maker notes of images from some DJI
        Phantom drones.
    },
    0x01 => { Name => 'Make',       Writable => 'string' },
  # 0x02 - int8u[4]: "1 0 0 0", "1 1 0 0"
    0x03 => { Name => 'SpeedX',     Writable => 'float', %convFloat2 }, # (guess)
    0x04 => { Name => 'SpeedY',     Writable => 'float', %convFloat2 }, # (guess)
    0x05 => { Name => 'SpeedZ',     Writable => 'float', %convFloat2 }, # (guess)
    0x06 => { Name => 'Pitch',      Writable => 'float', %convFloat2 },
    0x07 => { Name => 'Yaw',        Writable => 'float', %convFloat2 },
    0x08 => { Name => 'Roll',       Writable => 'float', %convFloat2 },
    0x09 => { Name => 'CameraPitch',Writable => 'float', %convFloat2 },
    0x0a => { Name => 'CameraYaw',  Writable => 'float', %convFloat2 },
    0x0b => { Name => 'CameraRoll', Writable => 'float', %convFloat2 },
);

# thermal parameters in APP4 of DJI ZH20T images (ref forum11401)
%Image::ExifTool::DJI::ThermalParams = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP4', 2 => 'Image' },
    NOTES => 'Thermal parameters extracted from APP4 of DJI RJPEG files from the ZH20T.',
  # 0x00 - 0xaa551206 - temperature header magic number 
    0x24 => { Name => 'K1', Format => 'float' },
    0x28 => { Name => 'K2', Format => 'float' },
    0x2c => { Name => 'K3', Format => 'float' },
    0x30 => { Name => 'K4', Format => 'float' },
    0x34 => { Name => 'KF', Format => 'float' },
    0x38 => { Name => 'B1', Format => 'float' },
    0x3c => { Name => 'B2', Format => 'float' },
    0x44 => { Name => 'ObjectDistance',     Format => 'int16u' },
    0x46 => { Name => 'RelativeHumidity',   Format => 'int16u' },
    0x48 => { Name => 'Emissivity',         Format => 'int16u' },
    0x4a => { Name => 'Reflection',         Format => 'int16u',  },
    0x4c => { Name => 'AmbientTemperature', Format => 'int16u' }, # (aka D1)
    0x50 => { Name => 'D2', Format => 'int32s' },
    0x54 => { Name => 'KJ', Format => 'int16u' },
    0x56 => { Name => 'DB', Format => 'int16u' },
    0x58 => { Name => 'KK', Format => 'int16u' },
  # 0x500 - 0x55aa1206 - device header magic number 
    # (nothing yet decoded from device header)
);

%Image::ExifTool::DJI::XMP = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-drone-dji', 2 => 'Location' },
    NAMESPACE => 'drone-dji',
    TABLE_DESC => 'XMP DJI',
    VARS => { NO_ID => 1 },
    NOTES => 'XMP tags used by DJI for images from drones.',
    AbsoluteAltitude  => { Writable => 'real' },
    RelativeAltitude  => { Writable => 'real' },
    GimbalRollDegree  => { Writable => 'real' },
    GimbalYawDegree   => { Writable => 'real' },
    GimbalPitchDegree => { Writable => 'real' },
    FlightRollDegree  => { Writable => 'real' },
    FlightYawDegree   => { Writable => 'real' },
    FlightPitchDegree => { Writable => 'real' },
    GpsLatitude => {
        Name => 'GPSLatitude',
        Writable => 'real',
        Avoid => 1,
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lat")',
    },
    GpsLongtitude => { # (sic)
        Name => 'GPSLongtitude',
        Writable => 'real',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lon")',
    },
    GpsLongitude => { #PH (NC)
        Name => 'GPSLongitude',
        Writable => 'real',
        Avoid => 1,
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lon")',
    },
    FlightXSpeed  => { Writable => 'real' },
    FlightYSpeed  => { Writable => 'real' },
    FlightZSpeed  => { Writable => 'real' },
    CamReverse    => { }, # integer?
    GimbalReverse => { }, # integer?
    SelfData      => { Groups => { 2 => 'Image' } },
    CalibratedFocalLength    => { Writable => 'real', Groups => { 2 => 'Image' } },
    CalibratedOpticalCenterX => { Writable => 'real', Groups => { 2 => 'Image' } },
    CalibratedOpticalCenterY => { Writable => 'real', Groups => { 2 => 'Image' } },
    RtkFlag       => { }, # integer?
    RtkStdLon     => { Writable => 'real' },
    RtkStdLat     => { Writable => 'real' },
    RtkStdHgt     => { Writable => 'real' },
    DewarpData    => { Groups => { 2 => 'Image' } },
    DewarpFlag    => { Groups => { 2 => 'Image' } }, # integer?
    Latitude => {
        Name => 'Latitude',
        Writable => 'real',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lat")',
    },
    Longitude => {
        Name => 'Longitude',
        Writable => 'real',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lon")',
    },
);

__END__

=head1 NAME

Image::ExifTool::DJI - DJI Phantom maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
the maker notes in images from some DJI Phantom drones.

=head1 AUTHOR

Copyright 2003-2021, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DJI Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
