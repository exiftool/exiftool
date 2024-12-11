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
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::XMP;
use Image::ExifTool::GPS;
use Image::ExifTool::Protobuf;

$VERSION = '1.10';

sub ProcessDJIInfo($$$);

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

# DJI debug maker notes
%Image::ExifTool::DJI::Info = (
    PROCESS_PROC => \&ProcessDJIInfo,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Tags written by some DJI drones.',
    VARS => { LONG_TAGS => 2 },
    ae_dbg_info         => { Name => 'AEDebugInfo' },
    ae_histogram_info   => { Name => 'AEHistogramInfo' },
    ae_local_histogram  => { Name => 'AELocalHistogram' },
    ae_liveview_histogram_info  => { Name => 'AELiveViewHistogramInfo' },
    ae_liveview_local_histogram => { Name => 'AELiveViewLocalHistogram' },
    awb_dbg_info        => { Name => 'AWBDebugInfo' },
    af_dbg_info         => { Name => 'AFDebugInfo' },
    hiso                => { Name => 'Histogram' },
    xidiri              => { Name => 'Xidiri' },
   'GimbalDegree(Y,P,R)'=> { Name => 'GimbalDegree' },
   'FlightDegree(Y,P,R)'=> { Name => 'FlightDegree' },
    adj_dbg_info        => { Name => 'ADJDebugInfo' },
    sensor_id           => { Name => 'SensorID' },
   'FlightSpeed(X,Y,Z)' => { Name => 'FlightSpeed' },
    hyperlapse_dbg_info => { Name => 'HyperlapsDebugInfo' },
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

# thermal parameters in APP4 of DJI M3T, H20N, M2EA and some M30T images (ref PH/forum11401)
%Image::ExifTool::DJI::ThermalParams2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP4', 2 => 'Image' },
    NOTES => 'Thermal parameters extracted from APP4 of DJI M3T RJPEG files.',
    0x00 => { Name => 'AmbientTemperature',  Format => 'float', PrintConv => 'sprintf("%.1f C",$val)' }, # (NC)
    0x04 => { Name => 'ObjectDistance',      Format => 'float', PrintConv => 'sprintf("%.1f m",$val)' },
    0x08 => { Name => 'Emissivity',          Format => 'float', PrintConv => 'sprintf("%.2f",$val)' },
    0x0c => { Name => 'RelativeHumidity',    Format => 'float', PrintConv => 'sprintf("%g %%",$val*100)' },
    0x10 => { Name => 'ReflectedTemperature',Format => 'float', PrintConv => 'sprintf("%.1f C",$val)' },
    0x65 => { Name => 'IDString',            Format => 'string[16]' }, # (NC)
);

# thermal parameters in APP4 of some DJI M30T images (ref PH)
%Image::ExifTool::DJI::ThermalParams3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP4', 2 => 'Image' },
    NOTES => 'Thermal parameters extracted from APP4 of some DJI RJPEG files.',
  # 0x00 - 0xaa553800 - params3 magic number 
    0x04 => { Name => 'RelativeHumidity',    Format => 'int16u' },
    0x06 => { Name => 'ObjectDistance',      Format => 'int16u', ValueConv => '$val / 10' },
    0x08 => { Name => 'Emissivity',          Format => 'int16u', ValueConv => '$val / 100' },
    0x0a => { Name => 'ReflectedTemperature',Format => 'int16u', ValueConv => '$val / 10' },
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
    GpsLongtitude => { # [sic] (misspelt in DJI original file)
        Name => 'GPSLongtitude',
        Writable => 'real',
        Avoid => 1, # (in case someone tries to write "GPSLong*")
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

# metadata in protobuf format (djmd and dbgi meta types, ref PH)
%Image::ExifTool::DJI::Protobuf = (
    GROUPS => { 0 => 'Protobuf', 1 => 'DJI', 2 => 'Location' },
    TAG_PREFIX => '',
    PROCESS_PROC => \&Image::ExifTool::Protobuf::ProcessProtobuf,
    NOTES => q{
        Tags found in protobuf-format DJI meta djmd and dbgi timed metadata.  Only a
        few tags are currently known, but unknown djmd tags may be extracted by
        setting the Unknown option to 1 (or 2 to also extract unknown dbgi debug
        tags).  Tag ID's are composed of the corresponding .proto file name combined
        with the hierarchical protobuf field numbers.  The "dvtm_AVATA2.proto" file
        is used by the DJI Avanta 2, and "dvtm_ac203.proto" by the OsmoAction4.
    },
    Protocol => { },
   # dvtm_ac203_1-1-6 - some version number
    'dvtm_ac203_1-1-10' => 'Model',
    'dvtm_ac203_2-3-1' => { Name => 'FrameWidth',  Format => 'unsigned' },
    'dvtm_ac203_2-3-2' => { Name => 'FrameHeight', Format => 'unsigned' },
    'dvtm_ac203_2-3-3' => { Name => 'FrameRate',   Format => 'float' },
   # dvtm_ac203_3-4-1-4 - model code?
    'dvtm_ac203_3-4-2-1-1' => {
        Name => 'CoordinateUnits',
        Format  => 'unsigned',
        # don't extract this -- just convert to degrees
        RawConv => '$$self{CoordUnits} = $val; undef',
        Hidden => 1,
        # PrintConv => { 0 => 'Radians', 1 => 'Degrees' },
    },
    'dvtm_ac203_3-4-2-1-2' => {
        Name => 'GPSLatitude',
        Format => 'double',
        # set ExifTool GPSLatitude/GPSLongitude members so GPSDateTime will be generated if necessary
        RawConv => '$$self{GPSLatitude} = $$self{CoordUnits} ? $val : $val * 180 / 3.141592653589793', # (NC)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    'dvtm_ac203_3-4-2-1-3' => {
        Name => 'GPSLongitude',
        Format => 'double',
        RawConv => '$$self{GPSLongitude} = $$self{CoordUnits} ? $val : $val * 180 / 3.141592653589793', # (NC)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    'dvtm_ac203_3-4-2-2' => {
        Name => 'GPSAltitude',
        Format => 'unsigned',
        ValueConv => '$val / 1000',
    },
    'dvtm_ac203_3-4-2-6-1' => {
        Name => 'GPSDateTime',
        Format => 'string',
        Groups => { 2 => 'Time' },
        RawConv => '$$self{GPSDateTime} = $val',
        ValueConv => '$val =~ tr/-/:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
   # dvtm_AVATA2_1-1-2 - some version number
   # dvtm_AVATA2_1-1-3 - some version number
    'dvtm_AVATA2_1-1-10' => 'Model',
    'dvtm_AVATA2_2-2-3-1' => 'SerialNumber', # (NC)
    'dvtm_AVATA2_2-3-1' => { Name => 'FrameWidth',  Format => 'unsigned' },
    'dvtm_AVATA2_2-3-2' => { Name => 'FrameHeight', Format => 'unsigned' },
    'dvtm_AVATA2_2-3-3' => { Name => 'FrameRate',   Format => 'float' },
   # dvtm_AVATA2_3-1-1 - frame number (starting at 1)
    'dvtm_AVATA2_3-1-2' => { # (also 3-2-1-6 and 3-4-1-6)
        Name => 'TimeStamp',
        Format => 'unsigned',
        # milliseconds, but I don't know what the zero is
        ValueConv => '$val / 1e6',
    },
   # dvtm_AVATA2_3-2-1-4 - model code?
   # dvtm_AVATA2_3-4-1-4 - model code?
    'dvtm_AVATA2_3-4-4-1-1' => { # (NC) (default seems to be radians if missing)
        Name => 'CoordinateDegrees',
        Format  => 'unsigned',
        RawConv => '$$self{CoordDegrees} = $val; undef',
        Hidden => 1,
    },
    'dvtm_AVATA2_3-4-4-1-2' => {
        Name => 'GPSLatitude',
        Format => 'double',
        RawConv => '$$self{GPSLatitude} = $$self{CoordDegrees} ? $val : $val * 180 / 3.141592653589793', # (NC)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    'dvtm_AVATA2_3-4-4-1-3' => {
        Name => 'GPSLongitude',
        Format => 'double',
        RawConv => '$$self{GPSLongitude} = $$self{CoordDegrees} ? $val : $val * 180 / 3.141592653589793', # (NC)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
);

#------------------------------------------------------------------------------
# Process DJI info (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessDJIInfo($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    if ($dirStart) {
        my $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
    }
    $et->VerboseDir('DJIInfo', undef, length $$dataPt);
    while ($$dataPt =~ /\G\[(.*?)\](?=(\[|$))/sg) {
        my ($tag, $val) = split /:/, $1, 2;
        next unless defined $tag and defined $val;
        if ($val =~ /^([\x20-\x7e]+)\0*$/) {
            $val = $1;
        } else {
            my $buff = $val;
            $val = \$buff;
        }
        if (not $$tagTbl{$tag} and $tag=~ /^[-_a-zA-Z0-9]+$/) {
            my $name = $tag;
            $name =~ s/_([a-z])/_\U$1/g;
            AddTagToTable($tagTbl, $tag, { Name => Image::ExifTool::MakeTagName($name) });
        }
        $et->HandleTag($tagTbl, $tag, $val);
    }
    return 1;
}

__END__

=head1 NAME

Image::ExifTool::DJI - DJI Phantom maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
the maker notes in images from some DJI Phantom drones.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DJI Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
