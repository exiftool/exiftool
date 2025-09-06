#------------------------------------------------------------------------------
# File:         DJI.pm
#
# Description:  DJI Phantom maker notes tags
#
# Revisions:    2016-07-25 - P. Harvey Created
#               2017-06-23 - PH Added XMP tags
#               2024-12-04 - PH Added protobuf tags
#------------------------------------------------------------------------------

package Image::ExifTool::DJI;

use strict;
use vars qw($VERSION %knownProtocol);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::XMP;
use Image::ExifTool::GPS;
use Image::ExifTool::Protobuf;

$VERSION = '1.15';

sub ProcessDJIInfo($$$);
sub ProcessSettings($$$);

%knownProtocol = (
    'dvtm_ac203.proto' => 1,    # Osmo Action 4
    'dvtm_ac204.proto' => 1,    # Osmo Action 5
    'dvtm_AVATA2.proto' => 1,   # Avata 2
    'dvtm_wm265e.proto' => 1,   # Mavic 3
    'dvtm_pm320.proto' => 1,    # Matrice 30
    'dvtm_Mini4_Pro.proto' => 1,    # Matrice 30
    'dvtm_Mini4_Pro.proto' => 1,    # Matrice 30
    'dvtm_dji_neo.proto' => 1,  # Neo
);

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

%Image::ExifTool::DJI::Glamour = (
    GROUPS => { 0 => 'QuickTime', 1 => 'DJI', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::DJI::ProcessSettings,
    NOTES => 'Glamour settings used by some DJI models.',
    beauty_enable   => 'BeautyEnable',
    smoother        => 'Smoother',
    whitening       => 'Whitening',
    face_slimming   => 'FaceSlimming',
    eye_enlarge     => 'EyeEnlarge',
    nose_slimming   => 'NoseSlimming',
    mouth_beautify  => 'MouthModify',
    teeth_whitening => 'TeethWhitening',
    leg_longer      => 'LegLonger',
    head_shrinking  => 'HeadShrinking',
    lipstick        => 'Lipstick',
    blush           => 'Blush',
    dark_circle     => 'DarkCircle',
    acne_spot_removal=>'AcneSpotRemoval',
    eyebrows        => 'Eyebrows',
);

# metadata in protobuf format (djmd and dbgi meta types, ref PH)
%Image::ExifTool::DJI::Protobuf = (
    GROUPS => { 0 => 'Protobuf', 1 => 'DJI', 2 => 'Camera' },
    TAG_PREFIX => '',
    PROCESS_PROC => \&Image::ExifTool::Protobuf::ProcessProtobuf,
    NOTES => q{
        Tags found in protobuf-format DJI djmd and dbgi timed metadata.  The known
        tags listed below are extracted by default, but unknown djmd tags may be
        extracted as well by setting the Unknown option to 1, or 2 to also extract
        unknown dbgi debug tags.  Tag ID's are composed of the corresponding .proto
        file name combined with the hierarchical protobuf field numbers.

        ExifTool currently extracts timed GPS plus a few other tags from DJI devices
        which use the following protocols:  dvtm_AVATA2.proto (Avata 2),
        dvtm_ac203.proto (Osmo Action 4), dvtm_ac204.proto (Osmo Action 5),
        dvtm_wm265e.proto (Mavic 3), dvtm_pm320.proto (Matrice 30),
        dvtm_Mini4_Pro.proto (Mini 4 Pro) and dvtm_dji_neo.proto (DJI Neo).

        Note that with the protobuf format, numerical tags missing from the output
        for a given protocol should be considered to have the default value of 0.
    },
    Protocol => {
        Notes => "typically protobuf field 1-1-1, but ExifTool doesn't rely on this",
        RawConv => q{
            unless ($Image::ExifTool::DJI::knownProtocol{$val}) {
                $self->Warn("Unknown protocol $val (please submit sample for testing)");
            }
            return $val;
        },
    },
#
# Osmo Action 4
#
    'dvtm_ac203_1-1-5' => { Name => 'SerialNumber', Notes => 'Osmo Action 4' }, # (NC)
   # dvtm_ac203_1-1-6 - some version number
    'dvtm_ac203_1-1-10' => 'Model',
    'dvtm_ac203_2-3' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
    'dvtm_ac203_3-2-2-1' => { Name => 'ISO', Format => 'float' },
    'dvtm_ac203_3-2-4-1' => { # (NC)
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    'dvtm_ac203_3-2-6-1' => { Name => 'ColorTemperature', Format => 'unsigned' }, # (NC)
   # dvtm_ac203_3-2-9-1 - looks like Z accerometer measurement, but 2 and 3 don't look like other components
    'dvtm_ac203_3-2-10-2' => { Name => 'AccelerometerX', Format => 'float' } , # (NC) left/right
    'dvtm_ac203_3-2-10-3' => { Name => 'AccelerometerY', Format => 'float' } , # (NC) front/back
    'dvtm_ac203_3-2-10-4' => { Name => 'AccelerometerZ', Format => 'float' } , # (NC) up/down
   # dvtm_ac203_3-4-1-4 - model code?
    'dvtm_ac203_3-4-2-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_ac203_3-4-2-2' => {
        Name => 'GPSAltitude',
        Groups => { 2 => 'Location' },
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
#
# Osmo Action 5
#
    'dvtm_ac204_1-1-5' => { Name => 'SerialNumber', Notes => 'Osmo Action 5' }, # (NC)
   # dvtm_ac204_1-1-6 - some version number
    'dvtm_ac204_1-1-10' => 'Model',
    'dvtm_ac204_2-3' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
    'dvtm_ac204_3-2-4-1' => { # (NC)
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    'dvtm_ac204_3-2-6-1' => { Name => 'ColorTemperature', Format => 'unsigned' }, # (NC)
    'dvtm_ac204_3-2-10-2' => { Name => 'AccelerometerX', Format => 'float' } , # (NC) left/right
    'dvtm_ac204_3-2-10-3' => { Name => 'AccelerometerY', Format => 'float' } , # (NC) front/back
    'dvtm_ac204_3-2-10-4' => { Name => 'AccelerometerZ', Format => 'float' } , # (NC) up/down
   # dvtm_ac204_3-4-1-4 - model code?
    'dvtm_ac204_3-4-2-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_ac204_3-4-2-2' => {
        Name => 'GPSAltitude',
        Groups => { 2 => 'Location' },
        Format => 'unsigned',
        ValueConv => '$val / 1000',
    },
    'dvtm_ac204_3-4-2-6-1' => {
        Name => 'GPSDateTime',
        Format => 'string',
        Groups => { 2 => 'Time' },
        RawConv => '$$self{GPSDateTime} = $val',
        ValueConv => '$val =~ tr/-/:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
#
# Avata 2
#
   # dvtm_AVATA2_1-1-2 - some version number
   # dvtm_AVATA2_1-1-3 - some version number
    'dvtm_AVATA2_1-1-5' => { Name => 'SerialNumber', Notes => 'Avata 2' }, # (NC)
    'dvtm_AVATA2_1-1-10' => 'Model',
   # dvtm_AVATA2_2-2-1-4 - model code?
    'dvtm_AVATA2_2-2-3-1' => 'SerialNumber2', # (NC)
    'dvtm_AVATA2_2-3' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
   # dvtm_AVATA2_3-1-1 - frame number (starting at 1)
    'dvtm_AVATA2_3-1-2' => { # (also 3-2-1-6 and 3-4-1-6)
        Name => 'TimeStamp',
        Groups => { 2 => 'Time' },
        Format => 'unsigned',
        # milliseconds, but I don't know what the zero is
        ValueConv => '$val / 1e6',
    },
   # dvtm_AVATA2_3-2-1-4 - model code?
   # dvtm_AVATA2_3-2-1-5 - frame rate?
    'dvtm_AVATA2_3-2-2-1' => { Name => 'ISO', Format => 'float' }, # (NC)
    'dvtm_AVATA2_3-2-4-1' => {
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    'dvtm_AVATA2_3-2-6-1' => { Name => 'ColorTemperature', Format => 'unsigned' }, # (NC)
    'dvtm_AVATA2_3-2-10-1' => { # (NC)
        Name => 'FNumber',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
   # dvtm_AVATA2_3-4-1-4 - model code?
    'dvtm_AVATA2_3-4-3' => { # (NC)
        Name => 'DroneInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::DroneInfo' },
    },
    'dvtm_AVATA2_3-4-4-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_AVATA2_3-4-4-2' => { Name => 'AbsoluteAltitude', Format => 'int64s', ValueConv => '$val / 1000' }, # (NC)
    'dvtm_AVATA2_3-4-5-1' => { Name => 'RelativeAltitude', Format => 'float', ValueConv => '$val / 1000' }, # (NC)
#
# Mavic 3
#
    'dvtm_wm265e_1-1-5' => { Name => 'SerialNumber', Notes => 'Mavic 3' }, # (confirmed)
    'dvtm_wm265e_1-1-10' => 'Model',
    'dvtm_wm265e_2-2' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
   # dvtm_wm265e_3-2-1-4 - model code?
    'dvtm_wm265e_3-2-2-1' => { Name => 'ISO', Format => 'float' },
    'dvtm_wm265e_3-2-3-1' => {
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
   # dvtm_wm265e_3-2-5-1 - unknown rational (xxxx / 1000)
    'dvtm_wm265e_3-2-6-1' => { Name => 'DigitalZoom', Format => 'float' },
    'dvtm_wm265e_3-3-4-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_wm265e_3-3-3' => {
        Name => 'DroneInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::DroneInfo' },
    },
    'dvtm_wm265e_3-3-4-2' => { Name => 'AbsoluteAltitude', Format => 'int64s', ValueConv => '$val / 1000' },
    'dvtm_wm265e_3-3-5-1' => { Name => 'RelativeAltitude', Format => 'float', ValueConv => '$val / 1000' },
    'dvtm_wm265e_3-4-3' => {
        Name => 'GimbalInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GimbalInfo' },
    },
#
# Matrice 30
#
    'dvtm_pm320_1-1-5' => { Name => 'SerialNumber', Notes => 'Matrice 30' },
    'dvtm_pm320_1-1-10' => 'Model',
    'dvtm_pm320_2-2' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
    'dvtm_pm320_3-2-2-1' => { Name => 'ISO', Format => 'float' },
    'dvtm_pm320_3-2-3-1' => {
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    'dvtm_pm320_3-2-4-1' => { # (NC)
        Name => 'FNumber',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    'dvtm_pm320_3-2-6-1' => { Name => 'DigitalZoom', Format => 'float' },
    'dvtm_pm320_3-3-4-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_pm320_3-3-3' => {
        Name => 'DroneInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::DroneInfo' },
    },
    'dvtm_pm320_3-3-4-2' => { Name => 'AbsoluteAltitude', Format => 'int64s', ValueConv => '$val / 1000' },
    'dvtm_pm320_3-3-5-1' => { Name => 'RelativeAltitude', Format => 'float', ValueConv => '$val / 1000' },
    'dvtm_pm320_3-4-3' => {
        Name => 'GimbalInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GimbalInfo' },
    },
#
# Mini 4 Pro
#
    'dvtm_Mini4_Pro_1-1-5' => { Name => 'SerialNumber', Notes => 'Mini 4 Pro' },
    'dvtm_Mini4_Pro_1-1-10' => 'Model',
    'dvtm_Mini4_Pro_2-3' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
    'dvtm_Mini4_Pro_3-2-7-1' => { Name => 'ISO', Format => 'float' },
    'dvtm_Mini4_Pro_3-2-10-1' => {
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    'dvtm_Mini4_Pro_3-2-11-1' => {
        Name => 'FNumber',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    'dvtm_Mini4_Pro_3-2-32-1' => { Name => 'ColorTemperature', Format => 'unsigned' },
   # dvtm_Mini4_Pro_3-2-37-1 - something to do with battery level or time remaining?
    'dvtm_Mini4_Pro_3-3-4-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_Mini4_Pro_3-3-3' => {
        Name => 'DroneInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::DroneInfo' },
    },
    'dvtm_Mini4_Pro_3-3-4-2' => { Name => 'AbsoluteAltitude', Format => 'int64s', ValueConv => '$val / 1000' },
    'dvtm_Mini4_Pro_3-3-5-1' => { Name => 'RelativeAltitude', Format => 'float', ValueConv => '$val / 1000' }, # (NC)
    'dvtm_Mini4_Pro_3-4-3' => {
        Name => 'GimbalInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GimbalInfo' },
    },
#
# DJI Neo (very similar to AVATA2)
#
   # dvtm_dji_neo_1-1-2 - some version number
   # dvtm_dji_neo_1-1-3 - some version number
    'dvtm_dji_neo_1-1-5' => { Name => 'SerialNumber', Notes => 'DJI Neo' }, # (NC)
    'dvtm_dji_neo_1-1-10' => 'Model',
   # dvtm_dji_neo_2-2-1-4 - model code?
   # dvtm_dji_neo_2-2-2-1 - some firmware version?
   # dvtm_dji_neo_2-2-2-2 - some version number?
    'dvtm_dji_neo_2-2-3-1' => 'SerialNumber2', # (NC)
    'dvtm_dji_neo_2-3' => {
        Name => 'FrameInfo', 
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::FrameInfo' },
    },
   # dvtm_dji_neo_3-1-1 - frame number (starting at 1)
    'dvtm_dji_neo_3-1-2' => { # (also 3-2-1-6 and 3-4-1-6)
        Name => 'TimeStamp',
        Groups => { 2 => 'Time' },
        Format => 'unsigned',
        # milliseconds, but I don't know what the zero is
        ValueConv => '$val / 1e6',
    },
   # dvtm_dji_neo_3-2-1-4 - model code?
   # dvtm_dji_neo_3-2-1-5 - frame rate?
    'dvtm_dji_neo_3-2-2-1' => { Name => 'ISO', Format => 'float' }, # (NC)
    'dvtm_dji_neo_3-2-4-1' => {
        Name => 'ShutterSpeed',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    'dvtm_dji_neo_3-2-6-1' => { Name => 'ColorTemperature', Format => 'unsigned' }, # (NC)
    'dvtm_dji_neo_3-2-10-1' => { # (NC)
        Name => 'FNumber',
        Format => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
   # dvtm_dji_neo_3-4-1-4 - model code?
    'dvtm_dji_neo_3-4-3' => { # (NC)
        Name => 'DroneInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::DroneInfo' },
    },
    'dvtm_dji_neo_3-4-4-1' => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::GPSInfo' },
    },
    'dvtm_dji_neo_3-4-4-2' => { Name => 'AbsoluteAltitude', Format => 'int64s', ValueConv => '$val / 1000' }, # (NC)
);

%Image::ExifTool::DJI::DroneInfo = (
    GROUPS => { 0 => 'Protobuf', 1 => 'DJI', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::Protobuf::ProcessProtobuf,
    VARS => { HEX_ID => 0, ID_LABEL => 'Field #' },
    1 => { Name => 'DroneRoll',  Format => 'int64s', ValueConv => '$val / 10' },
    2 => { Name => 'DronePitch', Format => 'int64s', ValueConv => '$val / 10' },
    3 => { Name => 'DroneYaw',   Format => 'int64s', ValueConv => '$val / 10' },
);

%Image::ExifTool::DJI::GimbalInfo = (
    GROUPS => { 0 => 'Protobuf', 1 => 'DJI', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::Protobuf::ProcessProtobuf,
    VARS => { HEX_ID => 0, ID_LABEL => 'Field #' },
    1 => { Name => 'GimbalPitch',Format => 'int64s', ValueConv => '$val / 10' },
    2 => { Name => 'GimbalRoll', Format => 'int64s', ValueConv => '$val / 10' }, # usually 0, so missing
    3 => { Name => 'GimbalYaw',  Format => 'int64s', ValueConv => '$val / 10' },
);

%Image::ExifTool::DJI::FrameInfo = (
    GROUPS => { 0 => 'Protobuf', 1 => 'DJI', 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::Protobuf::ProcessProtobuf,
    VARS => { HEX_ID => 0, ID_LABEL => 'Field #' },
    1 => { Name => 'FrameWidth',  Format => 'unsigned' },
    2 => { Name => 'FrameHeight', Format => 'unsigned' },
    3 => { Name => 'FrameRate',   Format => 'float' },
  # 4-8: seen these values respectively for DJI Neo: 1,8,4,1,4
);

%Image::ExifTool::DJI::GPSInfo = (
    GROUPS => { 0 => 'Protobuf', 1 => 'DJI', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::Protobuf::ProcessProtobuf,
    VARS => { HEX_ID => 0, ID_LABEL => 'Field #' },
    1 => {
        Name => 'CoordinateUnits',
        Format  => 'unsigned',
        Notes => 'not extracted, but used internally to convert coordinates to degrees',
        # don't extract this -- just convert to degrees
        RawConv => '$$self{CoordUnits} = $val; undef',
        # PrintConv => { 0 => 'Radians', 1 => 'Degrees' },
    },
    2 => {
        Name => 'GPSLatitude',
        Format => 'double',
        # set ExifTool GPSLatitude/GPSLongitude members so GPSDateTime will be generated if necessary
        RawConv => '$$self{GPSLatitude} = $$self{CoordUnits} ? $val : $val * 180 / 3.141592653589793', # (NC)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    3 => {
        Name => 'GPSLongitude',
        Format => 'double',
        RawConv => '$$self{GPSLongitude} = $$self{CoordUnits} ? $val : $val * 180 / 3.141592653589793', # (NC)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
);

#------------------------------------------------------------------------------
# Process DJI beauty settings (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessSettings($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    $et->VerboseDir($$dirInfo{DirName}, undef, length(${$$dirInfo{DataPt}}));
    foreach (split /;/, ${$$dirInfo{DataPt}}) {
        my ($tag, $val) = split /=/;
        next unless defined $tag and defined $val;
        $et->HandleTag($tagTbl, $tag, $val, MakeTagInfo => 1);
    }
    return 1;
}

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
        $et->HandleTag($tagTbl, $tag, $val, MakeTagInfo => 1);
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

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DJI Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
