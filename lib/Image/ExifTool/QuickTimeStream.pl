#------------------------------------------------------------------------------
# File:         QuickTimeStream.pl
#
# Description:  Extract embedded information from QuickTime media data
#
# Revisions:    2018-01-03 - P. Harvey Created
#
# References:   1) https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW130
#               2) http://sergei.nz/files/nvtk_mp42gpx.py
#               3) https://forum.flitsservice.nl/dashcam-info/dod-ls460w-gps-data-uit-mov-bestand-lezen-t87926.html
#               4) https://developers.google.com/streetview/publish/camm-spec
#               5) https://sergei.nz/extracting-gps-data-from-viofo-a119-and-other-novatek-powered-cameras/
#               6) Thomas Allen https://github.com/exiftool/exiftool/pull/62
#------------------------------------------------------------------------------
package Image::ExifTool::QuickTime;

use strict;

use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::QuickTime;

sub Process_tx3g($$$);
sub Process_marl($$$);
sub Process_mebx($$$);
sub ProcessFreeGPS($$$);
sub ProcessFreeGPS2($$$);
sub Process360Fly($$$);

# QuickTime data types that have ExifTool equivalents
# (ref https://developer.apple.com/library/content/documentation/QuickTime/QTFF/Metadata/Metadata.html#//apple_ref/doc/uid/TP40000939-CH1-SW35)
my %qtFmt = (
    0 => 'undef',
    1 => 'string', # (UTF-8)
    # 2 - UTF-16
    # 3 - shift-JIS
    # 4 - UTF-8 sort
    # 5 - UTF-16 sort
    # 13 - JPEG image
    # 14 - PNG image
    # 21 - signed integer (1,2,3 or 4 bytes)
    # 22 - unsigned integer (1,2,3 or 4 bytes)
    23 => 'float',
    24 => 'double',
    # 27 - BMP image
    # 28 - QuickTime atom
    65 => 'int8s',
    66 => 'int16s',
    67 => 'int32s',
    70 => 'float', # float[2] x,y
    71 => 'float', # float[2] width,height
    72 => 'float', # float[4] x,y,width,height
    74 => 'int64s',
    75 => 'int8u',
    76 => 'int16u',
    77 => 'int32u',
    78 => 'int64u',
    79 => 'float', # float[9] transform matrix
    80 => 'float', # float[8] face coordinates
);

# maximums for validating H,M,S,d,m,Y from "freeGPS " metadata
my @dateMax = ( 24, 59, 59, 2200, 12, 31 );

# typical (minimum?) size of freeGPS block
my $gpsBlockSize = 0x8000;

# conversion factors
my $knotsToKph = 1.852; # knots --> km/h
my $mpsToKph   = 3.6;   # m/s   --> km/h

# handler types to process based on MetaFormat/OtherFormat
my %processByMetaFormat = (
    meta => 1,  # ('CTMD' in CR3 images, 'priv' unknown in DJI video)
    data => 1,  # ('RVMI')
    sbtl => 1,  # (subtitle; 'tx3g' in Yuneec drone videos)
    ctbx => 1,  # ('marl' in GM videos)
);

# data lengths for each INSV record type
my %insvDataLen = (
    0x300 => 56,    # accelerometer
    0x400 => 16,    # exposure (ref 6)
    0x600 => 8,     # timestamps (ref 6)
    0x700 => 53,    # GPS
);

# limit the default amount of data we read for some record types
# (to avoid running out of memory)
my %insvLimit = (
    0x300 => [ 'accelerometer', 20000 ],    # maximum of 20000 accelerometer records
);

# tags extracted from various QuickTime data streams
%Image::ExifTool::QuickTime::Stream = (
    GROUPS => { 2 => 'Location' },
    NOTES => q{
        Timed metadata extracted from QuickTime media data and some AVI videos when
        the ExtractEmbedded option is used.  Although most of these tags are
        combined into the single table below, ExifTool currently reads 46 different
        formats of timed GPS metadata from video files.
    },
    VARS => { NO_ID => 1 },
    GPSLatitude  => { PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")', RawConv => '$$self{FoundGPSLatitude} = 1; $val' },
    GPSLongitude => { PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")' },
    GPSAltitude  => { PrintConv => '(sprintf("%.4f", $val) + 0) . " m"' }, # round to 4 decimals
    GPSSpeed     => { PrintConv => 'sprintf("%.4f", $val) + 0' },   # round to 4 decimals
    GPSSpeedRef  => { PrintConv => { K => 'km/h', M => 'mph', N => 'knots' } },
    GPSTrack     => { PrintConv => 'sprintf("%.4f", $val) + 0' },    # round to 4 decimals
    GPSTrackRef  => { PrintConv => { M => 'Magnetic North', T => 'True North' } },
    GPSDateTime  => {
        Groups => { 2 => 'Time' },
        Description => 'GPS Date/Time',
        RawConv => '$$self{FoundGPSDateTime} = 1; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    GPSTimeStamp => { PrintConv => 'Image::ExifTool::GPS::PrintTimeStamp($val)', Groups => { 2 => 'Time' } },
    GPSSatellites=> { },
    GPSDOP       => { Description => 'GPS Dilution Of Precision' },
    Distance     => { PrintConv => '"$val m"' },
    VerticalSpeed=> { PrintConv => '"$val m/s"' },
    FNumber      => { PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)', Groups => { 2 => 'Camera' } },
    ExposureTime => { PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)', Groups => { 2 => 'Camera' } },
    ExposureCompensation => { PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)', Groups => { 2 => 'Camera' } },
    ISO          => { Groups => { 2 => 'Camera' } },
    CameraDateTime=>{ PrintConv => '$self->ConvertDateTime($val)', Groups => { 2 => 'Time' } },
    VideoTimeStamp => { Groups => { 2 => 'Video' } },
    Accelerometer=> { Notes => '3-axis acceleration in units of g' },
    AccelerometerData => { },
    AngularVelocity => { },
    GSensor      => { },
    Car          => { },
    RawGSensor   => {
        # (same as GSensor, but offset by some unknown value)
        ValueConv => 'my @a=split " ",$val; $_/=1000 foreach @a; "@a"',
    },
    Text         => { Groups => { 2 => 'Other' } },
    TimeCode     => { Groups => { 2 => 'Video' } },
    FrameNumber  => { Groups => { 2 => 'Video' } },
    SampleTime   => { Groups => { 2 => 'Video' }, PrintConv => 'ConvertDuration($val)', Notes => 'sample decoding time' },
    SampleDuration=>{ Groups => { 2 => 'Video' }, PrintConv => 'ConvertDuration($val)' },
    UserLabel    => { Groups => { 2 => 'Other' } },
    SampleDateTime => {
        Groups => { 2 => 'Time' },
        ValueConv => q{
            my $str = ConvertUnixTime($val);
            my $frac = $val - int($val);
            if ($frac != 0) {
                $frac = sprintf('%.6f', $frac);
                $frac =~ s/^0//;
                $frac =~ s/0+$//;
                $str .= $frac;
            }
            return $str;
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
#
# timed metadata decoded based on MetaFormat (format of 'meta' or 'data' sample description)
# [or HandlerType, or specific 'vide' type if specified]
#
    mebx => {
        Name => 'mebx',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Keys',
            ProcessProc => \&Process_mebx,
        },
    },
    gpmd => [{
        Name => 'gpmd_GoPro',
        Condition => '$$valPt !~ /^\0\0\xf2\xe1\xf0\xeeTT/',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
    },{
        Name => 'gpmd_Rove', # Rove Stealth 4K encrypted text
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Process_text,
        },
    }],
    fdsc => {
        Name => 'fdsc',
        Condition => '$$valPt =~ /^GPRO/',
        # (other types of "fdsc" samples aren't yet parsed: /^GP\x00/ and /^GP\x04/)
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::fdsc' },
    },
    rtmd => {
        Name => 'rtmd',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::rtmd' },
    },
    marl => {
        Name => 'marl',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::marl' },
    },
    CTMD => { # (Canon Timed MetaData)
        Name => 'CTMD',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CTMD' },
    },
    tx3g => {
        Name => 'tx3g',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::tx3g' },
    },
    RVMI => [{ # data "OtherFormat" written by unknown software
        Name => 'RVMI_gReV',
        Condition => '$$valPt =~ /^gReV/',  # GPS data
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::RVMI_gReV',
            ByteOrder => 'Little-endian',
        },
    },{
        Name => 'RVMI_sReV',
        Condition => '$$valPt =~ /^sReV/',  # sensor data
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::RVMI_sReV',
            ByteOrder => 'Little-endian',
        },
    # (there is also "tReV" data that hasn't been decoded yet)
    }],
    camm => [{
        Name => 'camm0',
        # (according to the spec. the first 2 bytes are reserved and should be zero,
        # but I have a sample where these bytes are non-zero, so allow anything here)
        Condition => '$$valPt =~ /^..\0\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm0',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm1',
        Condition => '$$valPt =~ /^..\x01\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm1',
            ByteOrder => 'Little-Endian',
        },
    },{ # (written by Insta360) - [HandlerType, not MetaFormat]
        Name => 'camm2',
        Condition => '$$valPt =~ /^..\x02\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm2',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm3',
        Condition => '$$valPt =~ /^..\x03\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm3',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm4',
        Condition => '$$valPt =~ /^..\x04\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm4',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm5',
        Condition => '$$valPt =~ /^..\x05\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm5',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm6',
        Condition => '$$valPt =~ /^..\x06\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm6',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm7',
        Condition => '$$valPt =~ /^..\x07\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm7',
            ByteOrder => 'Little-Endian',
        },
    }],
    mett => { # Parrot drones
        Name => 'mett',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::mett' },
    },
    JPEG => { # (in CR3 images) - [vide HandlerType with JPEG in SampleDescription, not MetaFormat]
        Name => 'JpgFromRaw',
        Groups => { 2 => 'Preview' },
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
    text => { # (TomTom Bandit MP4) - [sbtl HandlerType with 'text' in SampleDescription]
        Name => 'PreviewInfo',
        Condition => 'length $$valPt > 12 and Get32u($valPt,4) == length($$valPt) and $$valPt =~ /^.{8}\xff\xd8\xff/s',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::PreviewInfo' },
    },
    INSV => {
        Groups => { 0 => 'Trailer', 1 => 'Insta360' }, # (so these groups will appear in the -listg options)
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::INSV_MakerNotes' },
    },
    Unknown00 => { Unknown => 1 },
    Unknown01 => { Unknown => 1 },
    Unknown02 => { Unknown => 1 },
    Unknown03 => { Unknown => 1 },
);

# tags found in 'camm' type 0 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm0 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => q{
        The camm0 through camm7 tables define tags extracted from the Google Street
        View Camera Motion Metadata of MP4 videos.  See
        L<https://developers.google.com/streetview/publish/camm-spec> for the
        specification.
    },
    4 => {
        Name => 'AngleAxis',
        Notes => 'angle axis orientation in radians in local coordinate system',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 1 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Camera' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'PixelExposureTime',
        Format => 'int32s',
        ValueConv => '$val * 1e-9',
        PrintConv => 'sprintf("%.4g ms", $val * 1000)',
    },
    8 => {
        Name => 'RollingShutterSkewTime',
        Format => 'int32s',
        ValueConv => '$val * 1e-9',
        PrintConv => 'sprintf("%.4g ms", $val * 1000)',
    },
);

# tags found in 'camm' type 2 timed metadata (ref PH, Insta360Pro)
%Image::ExifTool::QuickTime::camm2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'AngularVelocity',
        Notes => 'gyro angular velocity about X, Y and Z axes in rad/s',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 3 timed metadata (ref PH, Insta360Pro)
%Image::ExifTool::QuickTime::camm3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'Acceleration',
        Notes => 'acceleration in the X, Y and Z directions in m/s^2',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 4 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'Position',
        Notes => 'X, Y, Z position in local coordinate system',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 5 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm5 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'GPSLatitude',
        Format => 'double',
        RawConv => '$$self{FoundGPSLatitude} = 1; $val',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    12 => {
        Name => 'GPSLongitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    20 => {
        Name => 'GPSAltitude',
        Format => 'double',
        PrintConv => '$_ = sprintf("%.6f", $val); s/\.?0+$//; "$_ m"',
    },
);

# tags found in 'camm' type 6 timed metadata (ref PH/4, Insta360)
%Image::ExifTool::QuickTime::camm6 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    0x04 => {
        Name => 'GPSDateTime',
        Description => 'GPS Date/Time',
        Groups => { 2 => 'Time' },
        Format => 'double',
        RawConv => '$$self{FoundGPSDateTime} = 1; $val',
        ValueConv => q{
            my $str = ConvertUnixTime($val);
            my $frac = $val - int($val);
            if ($frac != 0) {
                $frac = sprintf('%.6f', $frac);
                $frac =~ s/^0//;
                $frac =~ s/0+$//;
                $str .= $frac;
            }
            return $str . 'Z';
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x0c => {
        Name => 'GPSMeasureMode',
        Format => 'int32u',
        PrintConv => {
            0 => 'No Measurement',
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0x10 => {
        Name => 'GPSLatitude',
        Format => 'double',
        RawConv => '$$self{FoundGPSLatitude} = 1; $val',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    0x18 => {
        Name => 'GPSLongitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    0x20 => {
        Name => 'GPSAltitude',
        Format => 'float',
        PrintConv => '$_ = sprintf("%.3f", $val); s/\.?0+$//; "$_ m"',
    },
    0x24 => { Name => 'GPSHorizontalAccuracy', Format => 'float', Notes => 'metres' },
    0x28 => { Name => 'GPSVerticalAccuracy',   Format => 'float' },
    0x2c => { Name => 'GPSVelocityEast',       Format => 'float', Notes => 'm/s' },
    0x30 => { Name => 'GPSVelocityNorth',      Format => 'float' },
    0x34 => { Name => 'GPSVelocityUp',         Format => 'float' },
    0x38 => { Name => 'GPSSpeedAccuracy',      Format => 'float' },
);

# tags found in 'camm' type 7 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm7 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'MagneticField',
        Format => 'float[3]',
        Notes => 'microtesla',
    },
);

# preview image stored by TomTom Bandit ActionCam
%Image::ExifTool::QuickTime::PreviewInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => 'Preview stored by TomTom Bandit ActionCam.',
    8 => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
        Format => 'undef[$size-8]',
    },
);

# tags found in 'RVMI' 'gReV' timed metadata (ref PH)
%Image::ExifTool::QuickTime::RVMI_gReV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => 'GPS information extracted from the RVMI box of MOV videos.',
    4 => {
        Name => 'GPSLatitude',
        Format => 'int32s',
        RawConv => '$$self{FoundGPSLatitude} = 1; $val',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val/1e6, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    8 => {
        Name => 'GPSLongitude',
        Format => 'int32s',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val/1e6, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    # 12 - int32s: space for altitude? (always zero in my sample)
    16 => {
        Name => 'GPSSpeed', # km/h
        Format => 'int16s',
        ValueConv => '$val / 10',
    },
    18 => {
        Name => 'GPSTrack',
        Format => 'int16u',
        ValueConv => '$val * 2',
    },
);

# tags found in 'RVMI' 'sReV' timed metadata (ref PH)
%Image::ExifTool::QuickTime::RVMI_sReV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => q{
        G-sensor information extracted from the RVMI box of MOV videos.
    },
    4 => {
        Name => 'GSensor',
        Format => 'int16s[3]', # X Y Z
        ValueConv => 'my @a=split " ",$val; $_/=1000 foreach @a; "@a"',
    },
);

# tags found in 'tx3g' sbtl timed metadata (ref PH)
%Image::ExifTool::QuickTime::tx3g = (
    PROCESS_PROC => \&Process_tx3g,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => 'Tags extracted from the tx3g sbtl timed metadata of Yuneec drones.',
    Lat => {
        Name => 'GPSLatitude',
        RawConv => '$$self{FoundGPSLatitude} = 1; $val',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    Lon => {
        Name => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    Alt => {
        Name => 'GPSAltitude',
        ValueConv => '$val =~ s/\s*m$//; $val', # remove " m"
        PrintConv => '"$val m"', # add it back again
    },
    Yaw      => 'Yaw',
    Pitch    => 'Pitch',
    Roll     => 'Roll',
    GimYaw   => 'GimbalYaw',
    GimPitch => 'GimbalPitch',
    GimRoll  => 'GimbalRoll',
);

%Image::ExifTool::QuickTime::INSV_MakerNotes = (
    GROUPS => { 1 => 'MakerNotes', 2 => 'Camera' },
    0x0a => 'SerialNumber',
    0x12 => 'Model',
    0x1a => 'Firmware',
    0x2a => {
        Name => 'Parameters',
        ValueConv => '$val =~ tr/_/ /; $val',
    },
);

%Image::ExifTool::QuickTime::Tags360Fly = (
    PROCESS_PROC => \&Process360Fly,
    NOTES => 'Timed metadata found in MP4 videos from the 360Fly.',
    1 => {
        Name => 'Accel360Fly',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Accel360Fly' },
    },
    2 => {
        Name => 'Gyro360Fly',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Gyro360Fly' },
    },
    3 => {
        Name => 'Mag360Fly',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Mag360Fly' },
    },
    5 => {
        Name => 'GPS360Fly',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::GPS360Fly' },
    },
    6 => {
        Name => 'Rot360Fly',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Rot360Fly' },
    },
    250 => {
        Name => 'Fusion360Fly',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Fusion360Fly' },
    },
);

%Image::ExifTool::QuickTime::Accel360Fly = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    1  => { Name => 'AccelMode', Unknown => 1 }, # (always 2 in my sample)
    2  => {
        Name => 'SampleTime',
        Groups => { 2 => 'Video' },
        Format => 'int64u',
        ValueConv => '$val / 1e6',
        PrintConv => 'ConvertDuration($val)',
    },
    10 => { Name => 'AccelYPR',  Format => 'float[3]' },
);

%Image::ExifTool::QuickTime::Gyro360Fly = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    1  => { Name => 'GyroMode', Unknown => 1 }, # (always 1 in my sample)
    2  => {
        Name => 'SampleTime',
        Groups => { 2 => 'Video' },
        Format => 'int64u',
        ValueConv => '$val / 1e6',
        PrintConv => 'ConvertDuration($val)',
    },
    10 => { Name => 'GyroYPR', Format => 'float[3]' },
);

%Image::ExifTool::QuickTime::Mag360Fly = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    1  => { Name => 'MagMode', Unknown => 1 }, # (always 1 in my sample)
    2  => {
        Name => 'SampleTime',
        Groups => { 2 => 'Video' },
        Format => 'int64u',
        ValueConv => '$val / 1e6',
        PrintConv => 'ConvertDuration($val)',
    },
    10 => { Name => 'MagnetometerXYZ', Format => 'float[3]' },
);

%Image::ExifTool::QuickTime::GPS360Fly = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    1  => { Name => 'GPSMode', Unknown => 1 }, # (always 16 in my sample)
    2  => {
        Name => 'SampleTime',
        Groups => { 2 => 'Video' },
        Format => 'int64u',
        ValueConv => '$val / 1e6',
        PrintConv => 'ConvertDuration($val)',
    },
    10 => { Name => 'GPSLatitude',  Format => 'float', PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")' },
    14 => { Name => 'GPSLongitude', Format => 'float', PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")' },
    18 => { Name => 'GPSAltitude',  Format => 'float', PrintConv => '"$val m"' }, # (questionable accuracy)
    22 => {
        Name => 'GPSSpeed',
        Notes => 'converted to km/hr',
        Format => 'int16u',
        ValueConv => '$val * 0.036',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    24 => { Name => 'GPSTrack',     Format => 'int16u', ValueConv => '$val / 100' },
    26 => { Name => 'Acceleration', Format => 'int16u', ValueConv => '$val / 1000' },
);

%Image::ExifTool::QuickTime::Rot360Fly = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    1  => { Name => 'RotMode', Unknown => 1 }, # (always 1 in my sample)
    2  => {
        Name => 'SampleTime',
        Groups => { 2 => 'Video' },
        Format => 'int64u',
        ValueConv => '$val / 1e6',
        PrintConv => 'ConvertDuration($val)',
    },
    10 => { Name => 'RotationXYZ', Format => 'float[3]' },
);

%Image::ExifTool::QuickTime::Fusion360Fly = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    1  => { Name => 'FusionMode', Unknown => 1 }, # (always 0 in my sample)
    2  => {
        Name => 'SampleTime',
        Groups => { 2 => 'Video' },
        Format => 'int64u',
        ValueConv => '$val / 1e6',
        PrintConv => 'ConvertDuration($val)',
    },
    10 => { Name => 'FusionYPR', Format => 'float[3]' },
);

# tags found in 'marl' ctbx timed metadata (ref PH)
%Image::ExifTool::QuickTime::marl = (
    PROCESS_PROC => \&Process_marl,
    GROUPS => { 2 => 'Other' },
    NOTES => 'Tags extracted from the marl ctbx timed metadata of GM cars.',
);

#------------------------------------------------------------------------------
# Save information from keys in OtherSampleDesc directory for processing timed metadata
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (ref "Timed Metadata Media" here:
#  https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html)
sub SaveMetaKeys($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    return 0 unless $dirLen > 8;
    my $pos = 0;
    my $verbose = $$et{OPTIONS}{Verbose};
    my $oldIndent = $$et{INDENT};
    my $ee = $$et{ee};
    $ee or $ee = $$et{ee} = { };

    $verbose and $et->VerboseDir($$dirInfo{DirName}, undef, $dirLen);

    # loop through metadata key table
    while ($pos + 8 < $dirLen) {
        my $size = Get32u($dataPt, $pos);
        my $id = substr($$dataPt, $pos+4, 4);
        my $end = $pos + $size;
        $end = $dirLen if $end > $dirLen;
        $pos += 8;
        my ($tagID, $format, $pid);
        if ($verbose) {
            $pid = PrintableTagID($id,1);
            $et->VPrint(0, "$oldIndent+ [Metadata Key entry, Local ID=$pid, $size bytes]\n");
            $$et{INDENT} .= '| ';
        }

        while ($pos + 4 < $end) {
            my $len = unpack("x${pos}N", $$dataPt);
            last if $len < 8 or $pos + $len > $end;
            my $tag = substr($$dataPt, $pos + 4, 4);
            $pos += 8;  $len -= 8;
            my $val = substr($$dataPt, $pos, $len);
            $pos += $len;
            my $str;
            if ($tag eq 'keyd') {
                ($tagID = $val) =~ s/^(mdta|fiel)com\.apple\.quicktime\.//;
                $tagID = "Tag_$val" unless $tagID;
                ($str = $val) =~ s/(.{4})/$1 / if $verbose;
            } elsif ($tag eq 'dtyp') {
                next if length $val < 4;
                if (length $val >= 4) {
                    my $ns = unpack('N', $val);
                    if ($ns == 0) {
                        length $val >= 8 or $et->Warn('Short dtyp data'), next;
                        $str = unpack('x4N',$val);
                        $format = $qtFmt{$str} || 'undef';
                    } elsif ($ns == 1) {
                        $str = substr($val, 4);
                        $format = 'undef';
                    } else {
                        $format = 'undef';
                    }
                    $str .= " ($format)" if $verbose and defined $str;
                }
            }
            if ($verbose > 1) {
                if (defined $str) {
                    $str =~ tr/\x00-\x1f\x7f-\xff/./;
                    $str = " = $str";
                } else {
                    $str = '';
                }
                $et->VPrint(1, $$et{INDENT}."- Tag '".PrintableTagID($tag,2)."' ($len bytes)$str\n");
                $et->VerboseDump(\$val);
            }
        }
        if (defined $tagID and defined $format) {
            if ($verbose) {
                my $t2 = PrintableTagID($tagID);
                $et->VPrint(0, "$$et{INDENT}Added Local ID $pid = $t2 ($format)\n");
            }
            $$ee{'keys'}{$id} = { TagID => $tagID, Format => $format };
        }
        $$et{INDENT} = $oldIndent;
    }
    return 1;
}

#------------------------------------------------------------------------------
# We found some tags for this sample, so set document number and save timing information
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) sample time, 3) sample duration
sub FoundSomething($$;$$)
{
    my ($et, $tagTbl, $time, $dur) = @_;
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $et->HandleTag($tagTbl, SampleTime => $time) if defined $time;
    $et->HandleTag($tagTbl, SampleDuration => $dur) if defined $dur;
}

#------------------------------------------------------------------------------
# Approximate GPSDateTime value from sample time and CreateDate
# Inputs: 0) ExifTool ref, 1) tag table ptr, 2) sample time (s)
#         3) true if CreateDate is at end of video
# Notes: Uses ExifTool CreateDateAtEnd as flag to subtract video duration
sub SetGPSDateTime($$$)
{
    my ($et, $tagTbl, $sampleTime) = @_;
    my $value = $$et{VALUE};
    if (defined $sampleTime and $$value{CreateDate}) {
        $sampleTime += $$value{CreateDate}; # adjust sample time to seconds since the epoch
        if ($$et{CreateDateAtEnd}) {        # adjust if CreateDate is at end of video
            return unless $$value{TimeScale} and $$value{Duration};
            $sampleTime -= $$value{Duration} / $$value{TimeScale};
            $et->WarnOnce('Approximating GPSDateTime as CreateDate - Duration + SampleTime', 1);
        } else {
            $et->WarnOnce('Approximating GPSDateTime as CreateDate + SampleTime', 1);
        }
        unless ($et->Options('QuickTimeUTC')) {
            my $tzOff = $$et{tzOff};    # use previously calculated offset
            unless (defined $tzOff) {
                # adjust to UTC, assuming time is local
                my @tm = localtime $$value{CreateDate};
                my @gm = gmtime $$value{CreateDate};
                $tzOff = $$et{tzOff} = Image::ExifTool::GetTimeZone(\@tm, \@gm) * 60;
            }
            $sampleTime -= $tzOff;  # shift from local time to UTC
        }
        $et->HandleTag($tagTbl, GPSDateTime => Image::ExifTool::ConvertUnixTime($sampleTime,0,3) . 'Z');
    }
}

#------------------------------------------------------------------------------
# Handle tags that we found in the subtitle 'text'
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) hash of tag names/values
sub HandleTextTags($$$)
{
    my ($et, $tagTbl, $tags) = @_;
    my $tag;
    delete $$tags{done};
    delete $$tags{GPSTimeStamp} if $$tags{GPSDateTime};
    foreach $tag (sort keys %$tags) {
        $et->HandleTag($tagTbl, $tag => $$tags{$tag});
    }
    $$et{UnknownTextCount} = 0;
    undef %$tags;   # clear the hash
}

#------------------------------------------------------------------------------
# Process subtitle 'text'
# Inputs: 0) ExifTool ref, 1) data ref or dirInfo ref, 2) tag table ref
sub Process_text($$$)
{
    my ($et, $dataPt, $tagTbl) = @_;
    my %tags;

    return if $$et{NoMoreTextDecoding};

    if (ref $dataPt eq 'HASH') {
        my $dirName = $$dataPt{DirName};
        $dataPt = $$dataPt{DataPt};
        $et->VerboseDir($dirName, undef, length($$dataPt));
    }

    while ($$dataPt =~ /\$(\w+)([^\$]*)/g) {
        my ($tag, $dat) = ($1, $2);
        if ($tag =~ /^[A-Z]{2}RMC$/ and $dat =~ /^,(\d{2})(\d{2})(\d+(?:\.\d*)),A?,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/) {
            my $time = "$1:$2:$3";
            if ($$et{LastTime}) {
                if ($$et{LastTime} eq $time) {
                    $$et{DOC_NUM} = $$et{LastDoc};
                } elsif (%tags) {
                    HandleTextTags($et, $tagTbl, \%tags);
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                }
            }
            $$et{LastTime} = $time;
            $$et{LastDoc} = $$et{DOC_NUM};
            my $year = $14 + ($14 >= 70 ? 1900 : 2000);
            my $dateTime = sprintf('%.4d:%.2d:%.2d %sZ', $year, $13, $12, $time);
            $tags{GPSDateTime} = $dateTime;
            $tags{GPSLatitude} = (($4 || 0) + $5/60) * ($6 eq 'N' ? 1 : -1);
            $tags{GPSLongitude} = (($7 || 0) + $8/60) * ($9 eq 'E' ? 1 : -1);
            if (length $10) {
                $tags{GPSSpeed} = $10 * $knotsToKph;
                $tags{GPSSpeedRef} = 'K';
            }
            if (length $11) {
                $tags{GPSTrack} = $11;
                $tags{GPSTrackRef} = 'T';
            }
        } elsif ($tag =~ /^[A-Z]{2}GGA$/ and $dat =~ /^,(\d{2})(\d{2})(\d+(?:\.\d*)?),(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),[1-6]?,(\d+)?,(\.\d+|\d+\.?\d*)?,(-?\d+\.?\d*)?,M?/s) {
            my $time = "$1:$2:$3";
            if ($$et{LastTime}) {
                if ($$et{LastTime} eq $time) {
                    $$et{DOC_NUM} = $$et{LastDoc};
                } elsif (%tags) {
                    HandleTextTags($et, $tagTbl, \%tags);
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                }
            }
            $$et{LastTime} = $time;
            $$et{LastDoc} = $$et{DOC_NUM};
            $tags{GPSTimeStamp} = $time;
            $tags{GPSLatitude} = (($4 || 0) + $5/60) * ($6 eq 'N' ? 1 : -1);
            $tags{GPSLongitude} = (($7 || 0) + $8/60) * ($9 eq 'E' ? 1 : -1);
            $tags{GPSSatellites} = $10 if defined $10;
            $tags{GPSDOP} = $11 if defined $11;
            $tags{GPSAltitude} = $12 if defined $12;
        } elsif ($tag eq 'BEGINGSENSOR' and $dat =~ /^:([-+]\d+\.\d+):([-+]\d+\.\d+):([-+]\d+\.\d+)/) {
            $tags{Accelerometer} = "$1 $2 $3";
        } elsif ($tag eq 'TIME' and $dat =~ /^:(\d+)/) {
            $tags{TimeCode} = $1 / ($$et{MediaTS} || 1);
        } elsif ($tag eq 'BEGIN') {
            $tags{Text} = $dat if length $dat;
            $tags{done} = 1;
        } elsif ($tag ne 'END') {
            $tags{Text} = "\$$tag$dat";
        }
    }
    %tags and HandleTextTags($et, $tagTbl, \%tags), return;

    # check for enciphered binary GPS data
    # BlueSkySea:
    #   0000: 00 00 aa aa aa aa 54 54 98 9a 9b 93 9a 92 98 9a [......TT........]
    #   0010: 9a 9d 9f 9b 9f 9d aa aa aa aa aa aa aa aa aa aa [................]
    #   0020: aa aa aa aa aa a9 e4 9e 92 9f 9b 9f 92 9d 99 ef [................]
    #   0030: 9a 9a 98 9b 93 9d 9d 9c 93 aa aa aa aa aa 9a 99 [................]
    #   0040: 9b aa aa aa aa aa aa aa aa aa aa aa aa aa aa aa [................]
    #   [...]
    #  decrypted:
    #   0000: aa aa 00 00 00 00 fe fe 32 30 31 39 30 38 32 30 [........20190820]
    #   0010: 30 37 35 31 35 37 00 00 00 00 00 00 00 00 00 00 [075157..........]
    #   0020: 00 00 00 00 00 03 4e 34 38 35 31 35 38 37 33 45 [......N48515873E]
    #   0030: 30 30 32 31 39 37 37 36 39 00 00 00 00 00 30 33 [002197769.....03]
    #   0040: 31 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [1...............]
    #   [...]
    # Ambarella A12:
    #   0000: 00 00 f2 e1 f0 ee 54 54 98 9a 9b 93 9b 9b 9b 9c [......TT........]
    #   0010: 9b 9a 9a 93 9a 9b a6 9a 9b 9b 93 9b 9a 9b 9c 9a [................]
    #   0020: 9d 9a 92 9f 93 a9 e4 9f 9f 9e 9f 9b 9b 9c 9d ef [................]
    #   0030: 9a 99 9d 9e 99 9a 9a 9e 9b 81 9a 9b 9f 9d 9a 9a [................]
    #   0040: 9a 87 9a 9a 9a 87 9a 98 99 87 9a 9a 99 87 9a 9a [................]
    #   [...]
    #  decrypted:
    #   0000: aa aa 58 4b 5a 44 fe fe 32 30 31 39 31 31 31 36 [..XKZD..20191116]
    #   0010: 31 30 30 39 30 31 0c 30 31 31 39 31 30 31 36 30 [100901.011910160]
    #   0020: 37 30 38 35 39 03 4e 35 35 34 35 31 31 36 37 45 [70859.N55451167E]
    #   0030: 30 33 37 34 33 30 30 34 31 2b 30 31 35 37 30 30 [037430041+015700]
    #   0040: 30 2d 30 30 30 2d 30 32 33 2d 30 30 33 2d 30 30 [0-000-023-003-00]
    #   [...]
    #   0100: aa 55 57 ed ed 45 58 54 44 00 01 30 30 30 30 31 [.UW..EXTD..00001]
    #   0110: 31 30 38 30 30 30 58 00 58 00 58 00 58 00 58 00 [108000X.X.X.X.X.]
    #   0120: 58 00 58 00 58 00 58 00 00 00 00 00 00 00 00 00 [X.X.X.X.........]
    #   0130: 00 00 00 00 00 00 00                            [.......]
    if ($$dataPt =~ /^\0\0(..\xaa\xaa|\xf2\xe1\xf0\xee)/s and length $$dataPt >= 282) {
        my $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 8, 14)));
        if ($val =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
            $tags{GPSDateTime} = "$1:$2:$3 $4:$5:$6";
            $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 38, 9)));
            if ($val =~ /^([NS])(\d{2})(\d+$)$/) {
                $tags{GPSLatitude} = ($2 + $3 / 600000) * ($1 eq 'S' ? -1 : 1);
            }
            $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 47, 10)));
            if ($val =~ /^([EW])(\d{3})(\d+$)$/) {
                $tags{GPSLongitude} = ($2 + $3 / 600000) * ($1 eq 'W' ? -1 : 1);
            }
            $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 0x39, 5)));
            $tags{GPSAltitude} = $val + 0 if $val =~ /^[-+]\d+$/;
            $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 0x3e, 3)));
            if ($val =~ /^\d+$/) {
                $tags{GPSSpeed} = $val + 0;
                $tags{GPSSpeedRef} = 'K';
            }
            if ($$dataPt =~ /^\0\0..\xaa\xaa/s) { # (BlueSkySea)
                $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 0xad, 12)));
                # the first X,Y,Z accelerometer readings from the AccelerometerData
                if ($val =~ /^([-+]\d{3})([-+]\d{3})([-+]\d{3})$/) {
                    $tags{Accelerometer} = "$1 $2 $3";
                    $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 0xba, 96)));
                    my $order = GetByteOrder();
                    SetByteOrder('II');
                    $val = ReadValue(\$val, 0, 'float');
                    SetByteOrder($order);
                    $tags{AccelerometerData} = $val;
                }
            } else { # (Ambarella)
                my @acc;
                $val = pack('C*', map { $_ ^ 0xaa } unpack('C*', substr($$dataPt, 0x41, 195)));
                push @acc, $1, $2, $3 while $val =~ /\G([-+]\d{3})([-+]\d{3})([-+]\d{3})/g;
                $tags{Accelerometer} = "@acc" if @acc;
            }
        }
        %tags and HandleTextTags($et, $tagTbl, \%tags), return;
    }

    # check for DJI telemetry data, eg:
    # "F/3.5, SS 1000, ISO 100, EV 0, GPS (8.6499, 53.1665, 18), D 24.26m,
    #  H 6.00m, H.S 2.10m/s, V.S 0.00m/s \n"
    if ($$dataPt =~ /GPS \(([-+]?\d*\.\d+),\s*([-+]?\d*\.\d+)/) {
        $$et{CreateDateAtEnd} = 1;  # set flag indicating the file creation date is at the end
        $tags{GPSLatitude} = $2;
        $tags{GPSLongitude} = $1;
        $tags{GPSAltitude} = $1 if $$dataPt =~ /,\s*H\s+([-+]?\d+\.?\d*)m/;
        if ($$dataPt =~ /,\s*H.S\s+([-+]?\d+\.?\d*)/) {
            $tags{GPSSpeed} = $1 * $mpsToKph;
            $tags{GPSSpeedRef} = 'K';
        }
        $tags{Distance} = $1 * $mpsToKph if $$dataPt =~ /,\s*D\s+(\d+\.?\d*)m/;
        $tags{VerticalSpeed} = $1 if $$dataPt =~ /,\s*V.S\s+([-+]?\d+\.?\d*)/;
        $tags{FNumber} = $1 if $$dataPt =~ /\bF\/(\d+\.?\d*)/;
        $tags{ExposureTime} = 1 / $1 if $$dataPt =~ /\bSS\s+(\d+\.?\d*)/;
        $tags{ExposureCompensation} = ($1 / ($2 || 1)) if $$dataPt =~ /\bEV\s+([-+]?\d+\.?\d*)(\/\d+)?/;
        $tags{ISO} = $1 if $$dataPt =~ /\bISO\s+(\d+\.?\d*)/;
        HandleTextTags($et, $tagTbl, \%tags);
        return;
    }

    # check for Mini 0806 dashcam GPS, eg:
    # "A,270519,201555.000,3356.8925,N,08420.2071,W,000.0,331.0M,+01.84,-09.80,-00.61;\n"
    if ($$dataPt =~ /^A,(\d{2})(\d{2})(\d{2}),(\d{2})(\d{2})(\d{2}(\.\d+)?)/) {
        $tags{GPSDateTime} = "20$3:$2:$1 $4:$5:$6Z";
        if ($$dataPt =~ /^A,.*?,.*?,(\d{2})(\d+\.\d+),([NS])/) {
            $tags{GPSLatitude} = ($1 + $2/60) * ($3 eq 'S' ? -1 : 1);
        }
        if ($$dataPt =~ /^A,.*?,.*?,.*?,.*?,(\d{3})(\d+\.\d+),([EW])/) {
            $tags{GPSLongitude} = ($1 + $2/60) * ($3 eq 'W' ? -1 : 1);
        }
        my @a = split ',', $$dataPt;
        $tags{GPSAltitude} = $a[8] if $a[8] and $a[8] =~ s/M$//;
        $tags{GPSSpeed} = $a[7] if $a[7] and $a[7] =~ /^\d+\.\d+$/; # (NC)
        $tags{Accelerometer} = "$a[9] $a[10] $a[11]" if $a[11] and $a[11] =~ s/;\s*$//;
        HandleTextTags($et, $tagTbl, \%tags);
        return;
    }

    # check for Roadhawk dashcam text
    # ".;;;;D?JL;6+;;;D;R?;4;;;;DBB;;O;;;=D;L;;HO71G>F;-?=J-F:FNJJ;DPP-JF3F;;PL=DBRLBF0F;=?DNF-RD-PF;N;?=JF;;?D=F:*6F~"
    # decoded:
    # "X0000.2340Y-000.0720Z0000.9900G0001.0400$GPRMC,082138,A,5330.6683,N,00641.9749,W,012.5,87.86,050213,002.1,A"
    # (note: "002.1" is magnetic variation and is not decoded; it should have ",E" or ",W" afterward for direction)
    if ($$dataPt =~ /\*[0-9A-F]{2}~$/) {
        # (ref https://reverseengineering.stackexchange.com/questions/11582/how-to-reverse-engineer-dash-cam-metadata)
        my @decode = unpack 'C*', '-I8XQWRVNZOYPUTA0B1C2SJ9K.L,M$D3E4F5G6H7';
        my @chars = unpack 'C*', substr($$dataPt, 0, -4);
        foreach (@chars) {
            my $n = $_ - 43;
            $_ = $decode[$n] if $n >= 0 and defined $decode[$n];
        }
        my $buff = pack 'C*', @chars;
        if ($buff =~ /X(.*?)Y(.*?)Z(.*?)G(.*?)\$/) {
            # yup. the decoding worked out
            $tags{Accelerometer} = "$1 $2 $3 $4";
            $$dataPt = $buff;   # (process GPRMC below)
        }
    }

    # check for Thinkware format (and other NMEA RMC), eg:
    # "gsensori,4,512,-67,-12,100;GNRMC,161313.00,A,4529.87489,N,07337.01215,W,6.225,35.34,310819,,,A*52..;
    #  CAR,0,0,0,0.0,0,0,0,0,0,0,0,0"
    if ($$dataPt =~ /[A-Z]{2}RMC,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/ and
        # do some basic sanity checks on the date
        $13 <= 31 and $14 <= 12 and $15 <= 99)
    {
        my $year = $15 + ($15 >= 70 ? 1900 : 2000);
        $tags{GPSDateTime} = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', $year, $14, $13, $1, $2, $3);
        $tags{GPSLatitude} = (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1);
        $tags{GPSLongitude} = (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1);
        if (length $11) {
            $tags{GPSSpeed} = $11 * $knotsToKph;
            $tags{GPSSpeedRef} = 'K';
        }
        if (length $12) {
            $tags{GPSTrack} = $12;
            $tags{GPSTrackRef} = 'T';
        }
    }
    $tags{GSensor} = $1 if $$dataPt =~ /\bgsensori,(.*?)(;|$)/;
    $tags{Car} = $1 if $$dataPt =~ /\bCAR,(.*?)(;|$)/;

    if (%tags) {
        HandleTextTags($et, $tagTbl, \%tags);
    } else {
        $$et{UnknownTextCount} = ($$et{UnknownTextCount} || 0) + 1;
        # give up trying to decode useful information if we haven't found anything for a while
        $$et{NoMoreTextDecoding} = 1 if $$et{UnknownTextCount} > 100;
    }
}

#------------------------------------------------------------------------------
# Extract embedded metadata from media samples
# Inputs: 0) ExifTool ref
# Notes: Also accesses ExifTool RAF*, SET_GROUP1, HandlerType, MetaFormat,
#        ee*, and avcC elements (* = must exist)
sub ProcessSamples($)
{
    my $et = shift;
    my ($raf, $ee) = @$et{qw(RAF ee)};
    my ($i, $buff, $pos, $hdrLen, $hdrFmt, @time, @dur, $oldIndent);

    return unless $ee;
    delete $$et{ee};    # use only once

    # only process specific types of video streams
    my $type = $$et{HandlerType} || '';
    if ($type eq 'vide') {
        if    ($$ee{avcC}) { $type = 'avcC' }
        elsif ($$ee{JPEG}) { $type = 'JPEG' }
        else { return }
    }

    my ($start, $size) = @$ee{qw(start size)};
#
# determine sample start offsets from chunk offsets (stco) and sample-to-chunk table (stsc),
# and sample time/duration from time-to-sample (stts)
#
    unless ($start and $size) {
        return unless $size;
        my ($stco, $stsc, $stts) = @$ee{qw(stco stsc stts)};
        return unless $stco and $stsc and @$stsc;
        $start = [ ];
        my ($nextChunk, $iChunk) = (0, 1);
        my ($chunkStart, $startChunk, $samplesPerChunk, $descIdx, $timeCount, $timeDelta, $time);
        if ($stts and @$stts > 1) {
            $time = 0;
            $timeCount = shift @$stts;
            $timeDelta = shift @$stts;
        }
        my $ts = $$et{MediaTS} || 1;
        foreach $chunkStart (@$stco) {
            if ($iChunk >= $nextChunk and @$stsc) {
                ($startChunk, $samplesPerChunk, $descIdx) = @{shift @$stsc};
                $nextChunk = $$stsc[0][0] if @$stsc;
            }
            @$size < @$start + $samplesPerChunk and $et->WarnOnce('Sample size error'), last;
            my $sampleStart = $chunkStart;
            for ($i=0; ; ) {
                push @$start, $sampleStart;
                if (defined $time) {
                    until ($timeCount) {
                        if (@$stts < 2) {
                            undef $time;
                            last;
                        }
                        $timeCount = shift @$stts;
                        $timeDelta = shift @$stts;
                    }
                    push @time, $time / $ts;
                    push @dur, $timeDelta / $ts;
                    $time += $timeDelta;
                    --$timeCount;
                }
                # (eventually should use the description indices: $descIdx)
                last if ++$i >= $samplesPerChunk;
                $sampleStart += $$size[$#$start];
            }
            ++$iChunk;
        }
        @$start == @$size or $et->WarnOnce('Incorrect sample start/size count'), return;
    }
#
# extract and parse the sample data
#
    my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
    my $verbose = $et->Options('Verbose');
    my $metaFormat = $$et{MetaFormat} || '';
    my $tell = $raf->Tell();

    if ($verbose) {
        $et->VPrint(0, "---- Extract Embedded ----\n");
        $oldIndent = $$et{INDENT};
        $$et{INDENT} = '';
    }
    # get required information from avcC box if parsing video data
    if ($type eq 'avcC') {
        $hdrLen = (Get8u(\$$ee{avcC}, 4) & 0x03) + 1;
        $hdrFmt = ($hdrLen == 4 ? 'N' : $hdrLen == 2 ? 'n' : 'C');
        require Image::ExifTool::H264;
    }
    # loop through all samples
    for ($i=0; $i<@$start and $i<@$size; ++$i) {

        # initialize our flags for setting GPSDateTime
        delete $$et{FoundGPSLatitude};
        delete $$et{FoundGPSDateTime};

        # read the sample data
        my $size = $$size[$i];
        next unless $raf->Seek($$start[$i], 0) and $raf->Read($buff, $size) == $size;

        if ($type eq 'avcC') {
            next if length($buff) <= $hdrLen;
            # scan through all NAL units and send them to ParseH264Video()
            for ($pos=0; ; ) {
                my $len = unpack("x$pos$hdrFmt", $buff);
                last if $pos + $hdrLen + $len > length($buff);
                my $tmp = "\0\0\0\x01" . substr($buff, $pos+$hdrLen, $len);
                Image::ExifTool::H264::ParseH264Video($et, \$tmp);
                $pos += $hdrLen + $len;
                last if $pos + $hdrLen >= length($buff);
            }
            next;
        }
        if ($verbose > 1) {
            my $hdr = $$et{SET_GROUP1} ? "$$et{SET_GROUP1} Type='${type}' Format='${metaFormat}'" : "Type='${type}'";
            $et->VPrint(1, "${hdr}, Sample ".($i+1).' of '.scalar(@$start)." ($size bytes)\n");
            $et->VerboseDump(\$buff, Addr => $$start[$i]);
        }
        if ($type eq 'text') {

            FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
            unless ($buff =~ /^\$BEGIN/) {
                # remove ending "encd" box if it exists
                $buff =~ s/\0\0\0\x0cencd\0\0\x01\0$// and $size -= 12;
                # cameras such as the CanonPowerShotN100 store ASCII time codes with a
                # leading 2-byte integer giving the length of the string
                # (and chapter names start with a 2-byte integer too)
                if ($size >= 2 and unpack('n',$buff) == $size - 2) {
                    next if $size == 2;
                    $buff = substr($buff,2);
                }
                my $val;
                # check for encrypted GPS text as written by E-PRANCE B47FS camera
                if ($buff =~ /^\0/ and $buff =~ /\x0a$/ and length($buff) > 5) {
                    # decode simple ASCII difference cipher,
                    # based on known value of 4th-last char = '*'
                    my $dif = ord('*') - ord(substr($buff, -4, 1));
                    my $tmp = pack 'C*',map { $_=($_+$dif)&0xff } unpack 'C*',substr $buff,1,-1;
                    if ($verbose > 2) {
                        $et->VPrint(0, "[decrypted text]\n");
                        $et->VerboseDump(\$tmp);
                    }
                    if ($tmp =~ /^(.*?)(\$[A-Z]{2}RMC.*)/s) {
                        ($val, $buff) = ($1, $2);
                        $val =~ tr/\t/ /;
                        $et->HandleTag($tagTbl, RawGSensor => $val) if length $val;
                    }
                } elsif ($buff =~ /^(\0.{3})?PNDM/s) {
                    # Garmin Dashcam format (actually binary, not text)
                    my $n = $1 ? 4 : 0; # skip leading 4-byte size word if it exists
                    next if length($buff) < 20 + $n;
                    $et->HandleTag($tagTbl, GPSLatitude  => Get32s(\$buff, 12+$n) * 180/0x80000000);
                    $et->HandleTag($tagTbl, GPSLongitude => Get32s(\$buff, 16+$n) * 180/0x80000000);
                    $et->HandleTag($tagTbl, GPSSpeed => Get16u(\$buff, 8+$n));
                    $et->HandleTag($tagTbl, GPSSpeedRef => 'M');
                    SetGPSDateTime($et, $tagTbl, $time[$i]);
                    next; # all done (don't store/process as text)
                }
                unless (defined $val) {
                    $et->HandleTag($tagTbl, Text => $buff); # just store any other text
                }
            }
            Process_text($et, \$buff, $tagTbl);

        } elsif ($processByMetaFormat{$type}) {

            if ($$tagTbl{$metaFormat}) {
                my $tagInfo = $et->GetTagInfo($tagTbl, $metaFormat, \$buff);
                if ($tagInfo) {
                    FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
                    $$et{ee} = $ee; # need ee information for 'keys'
                    $et->HandleTag($tagTbl, $metaFormat, undef,
                        DataPt  => \$buff,
                        DataPos => 0,
                        Base    => $$start[$i], # (Base must be set for CR3 files)
                        TagInfo => $tagInfo,
                    );
                    delete $$et{ee};
                } elsif ($metaFormat eq 'camm' and $buff =~ /^X/) {
                    # seen 'camm' metadata in this format (X/Y/Z acceleration and G force? + GPRMC + ?)
                    # "X0000.0000Y0000.0000Z0000.0000G0000.0000$GPRMC,000125,V,,,,,000.0,,280908,002.1,N*71~, 794021  \x0a"
                    FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
                    $et->HandleTag($tagTbl, Accelerometer => "$1 $2 $3 $4") if $buff =~ /X(.*?)Y(.*?)Z(.*?)G(.*?)\$/;
                    Process_text($et, \$buff, $tagTbl);
                }
            } elsif ($verbose) {
                $et->VPrint(0, "Unknown $type format ($metaFormat)");
            }

        } elsif ($type eq 'gps ') { # (ie. GPSDataList tag)

            if ($buff =~ /^....freeGPS /s) {
                # decode "freeGPS " data (Novatek)
                ProcessFreeGPS($et, {
                    DataPt => \$buff,
                    DataPos => $$start[$i],
                    SampleTime => $time[$i],
                    SampleDuration => $dur[$i],
                }, $tagTbl) ;
            }

        } elsif ($$tagTbl{$type}) {

            my $tagInfo = $et->GetTagInfo($tagTbl, $type, \$buff);
            if ($tagInfo) {
                FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
                $et->HandleTag($tagTbl, $type, undef,
                    DataPt  => \$buff,
                    DataPos => 0,
                    Base    => $$start[$i], # (Base must be set for CR3 files)
                    TagInfo => $tagInfo,
                );
            }
        }
        # generate approximate GPSDateTime if necessary
        SetGPSDateTime($et, $tagTbl, $time[$i]) if $$et{FoundGPSLatitude} and not $$et{FoundGPSDateTime};
    }
    if ($verbose) {
        $$et{INDENT} = $oldIndent;
        $et->VPrint(0, "--------------------------\n");
    }
    # clean up
    $raf->Seek($tell, 0); # restore original file position
    $$et{DOC_NUM} = 0;
    $$et{HandlerType} = $$et{HanderDesc} = '';
}

#------------------------------------------------------------------------------
# Process "freeGPS " data blocks referenced by a 'gps ' (GPSDataList) atom
# Inputs: 0) ExifTool ref, 1) dirInfo ref {DataPt,SampleTime,SampleDuration}, 2) tagTable ref
# Returns: 1 on success (or 0 on unrecognized or "measurement-void" GPS data)
# Notes:
# - also see ProcessFreeGPS2() below for processing of other types of freeGPS blocks
sub ProcessFreeGPS($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my ($yr, $mon, $day, $hr, $min, $sec, $stat, $lbl);
    my ($lat, $latRef, $lon, $lonRef, $spd, $trk, $alt, @acc, @xtra);

    return 0 if $dirLen < 92;

    if (substr($$dataPt,18,8) eq "\xaa\xaa\xf2\xe1\xf0\xee\x54\x54") {

        # (this is very similar to the encrypted text format)
        # decode encrypted ASCII-based GPS (DashCam Azdome GS63H, ref 5)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 05 01 00 00 [....freeGPS ....]
        #  0010: 01 03 aa aa f2 e1 f0 ee 54 54 98 9a 9b 92 9a 93 [........TT......]
        #  0020: 98 9e 98 98 9e 93 98 92 a6 9f 9f 9c 9d ed fa 8a [................]
        # decrypted (from byte 18):
        #  0000: 00 00 58 4b 5a 44 fe fe 32 30 31 38 30 39 32 34 [..XKZD..20180924]
        #  0010: 32 32 34 39 32 38 0c 35 35 36 37 47 50 20 20 20 [224928.5567GP   ]
        #  0020: 00 00 00 00 00 03 4e 34 30 34 36 34 33 35 30 57 [......N40464350W]
        #  0030: 30 30 37 30 34 30 33 30 38 30 30 30 30 30 30 30 [0070403080000000]
        #  0040: 37 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [7...............]
        #  [...]
        #  00a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 2b 30 39 [.............+09]
        #  00b0: 33 2d 30 30 33 2d 30 30 35 00 00 00 00 00 00 00 [3-003-005.......]
        # header looks like this for EEEkit gps:
        #  0000: 00 00 04 00 66 72 65 65 47 50 53 20 f0 03 00 00 [....freeGPS ....]
        #  0010: 01 03 aa aa f2 e1 f0 ee 54 54 98 9a 98 9a 9a 9f [........TT......]
        #  0020: 9b 93 9b 9c 98 99 99 9f a6 9a 9a 98 9a 9a 9f 9b [................]
        #  0030: 93 9b 9c 98 99 99 9c a9 e4 99 9d 9e 9f 98 9e 9b [................]
        #  0040: 9c fd 9b 98 98 98 9f 9f 9a 9a 93 81 9a 9b 9d 9f [................]
        # decrypted (from byte 18):
        #  0000: 00 00 58 4b 5a 44 fe fe 32 30 32 30 30 35 31 39 [..XKZD..20200519]
        #  0010: 31 36 32 33 33 35 0c 30 30 32 30 30 35 31 39 31 [162335.002005191]
        #  0020: 36 32 33 33 36 03 4e 33 37 34 35 32 34 31 36 57 [62336.N37452416W]
        #  0030: 31 32 32 32 35 35 30 30 39 2b 30 31 37 35 30 31 [122255009+017501]
        #  0040: 31 2b 30 31 34 2b 30 30 32 2b 30 32 36 2b 30 31 [1+014+002+026+01]
        my $n = $dirLen - 18;
        $n = 0x101 if $n > 0x101;
        my $buf2 = pack 'C*', map { $_ ^ 0xaa } unpack 'C*', substr($$dataPt,18,$n);
        if ($et->Options('Verbose') > 1) {
            $et->VPrint(1, '[decrypted freeGPS data]');
            $et->VerboseDump(\$buf2);
        }
        # (extract longitude as 9 digits, not 8, ref PH)
        return 0 unless $buf2 =~ /^.{8}(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}).(.{15})([NS])(\d{8})([EW])(\d{9})(\d{8})?/s;
        ($yr,$mon,$day,$hr,$min,$sec,$lbl,$latRef,$lat,$lonRef,$lon,$spd) = ($1,$2,$3,$4,$5,$6,$7,$8,$9/1e4,$10,$11/1e4,$12);
        if (defined $spd) { # (Azdome)
            $spd += 0;  # remove leading 0's
        } elsif ($buf2 =~ /^.{57}([-+]\d{4})(\d{3})/s) { # (EEEkit)
            # $alt = $1 + 0;  (doesn't look right for my sample, but the Ambarella A12 text has this)
            $spd = $2 + 0;
        }
        $lbl =~ s/\0.*//s;  $lbl =~ s/\s+$//;  # truncate at null and remove trailing spaces
        push @xtra, UserLabel => $lbl if length $lbl;
        # extract accelerometer data (ref PH)
        if ($buf2 =~ /^.{65}(([-+]\d{3})([-+]\d{3})([-+]\d{3})([-+]\d{3})*)/s) {
            $_ = $1;
            @acc = ($2/100, $3/100, $4/100);
            s/([-+])/ $1/g;  s/^ //;
            push @xtra, AccelerometerData => $_;
        } elsif ($buf2 =~ /^.{173}([-+]\d{3})([-+]\d{3})([-+]\d{3})/s) { # (Azdome)
            @acc = ($1/100, $2/100, $3/100);
        }

    } elsif ($$dataPt =~ /^.{52}(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/s) {

        # decode NMEA-format GPS data (NextBase 512GW dashcam, ref PH)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 40 01 00 00 [....freeGPS @...]
        #  0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        #  0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        push @xtra, CameraDateTime => "$1:$2:$3 $4:$5:$6";
        if ($$dataPt =~ /\$[A-Z]{2}RMC,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d+\.\d+),([NS]),(\d+\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/s) {
            ($lat,$latRef,$lon,$lonRef) = ($5,$6,$7,$8);
            $yr = $13 + ($13 >= 70 ? 1900 : 2000);
            ($mon,$day,$hr,$min,$sec) = ($12,$11,$1,$2,$3);
            $spd = $9 * $knotsToKph if length $9;
            $trk = $10 if length $10;
        }
        if ($$dataPt =~ /\$[A-Z]{2}GGA,(\d{2})(\d{2})(\d+(\.\d*)?),(\d+\.\d+),([NS]),(\d+\.\d+),([EW]),[1-6]?,(\d+)?,(\.\d+|\d+\.?\d*)?,(-?\d+\.?\d*)?,M?/s) {
            ($hr,$min,$sec,$lat,$latRef,$lon,$lonRef) = ($1,$2,$3,$5,$6,$7,$8) unless defined $yr;
            $alt = $11;
            unshift @xtra, GPSSatellites => $9;
            unshift @xtra, GPSDOP => $10;
        }
        if (defined $lat) {
            # extract accelerometer readings if GPS was valid
            @acc = unpack('x68V3', $$dataPt);
            # change to signed integer and divide by 256
            map { $_ = $_ - 4294967296 if $_ >= 0x80000000; $_ /= 256 } @acc;
        }

    } elsif ($$dataPt =~ /^.{40}A([NS])([EW])/s) {

        # decode freeGPS from ViofoA119v3 dashcam (similar to Novatek GPS format)
        # 0000: 00 00 40 00 66 72 65 65 47 50 53 20 f0 03 00 00 [..@.freeGPS ....]
        # 0010: 05 00 00 00 2f 00 00 00 03 00 00 00 13 00 00 00 [..../...........]
        # 0020: 09 00 00 00 1b 00 00 00 41 4e 57 00 25 d1 99 45 [........ANW.%..E]
        # 0030: f1 47 40 46 66 66 d2 41 85 eb 83 41 00 00 00 00 [.G@Fff.A...A....]
        ($latRef, $lonRef) = ($1, $2);
        ($hr,$min,$sec,$yr,$mon,$day) = unpack('x16V6', $$dataPt);
        $yr += 2000;
        SetByteOrder('II');
        $lat = GetFloat($dataPt, 0x2c);
        $lon = GetFloat($dataPt, 0x30);
        $spd = GetFloat($dataPt, 0x34) * $knotsToKph; # (convert knots to km/h)
        $trk = GetFloat($dataPt, 0x38);
        SetByteOrder('MM');

    } elsif ($$dataPt =~ /^.{60}A\0{3}.{4}([NS])\0{3}.{4}([EW])\0{3}/s) {

        # decode freeGPS from Akaso dashcam
        # 0000: 00 00 80 00 66 72 65 65 47 50 53 20 60 00 00 00 [....freeGPS `...]
        # 0010: 78 2e 78 78 00 00 00 00 00 00 00 00 00 00 00 00 [x.xx............]
        # 0020: 30 30 30 30 30 00 00 00 00 00 00 00 00 00 00 00 [00000...........]
        # 0030: 12 00 00 00 2f 00 00 00 19 00 00 00 41 00 00 00 [..../.......A...]
        # 0040: 13 b3 ca 44 4e 00 00 00 29 92 fb 45 45 00 00 00 [...DN...)..EE...]
        # 0050: d9 ee b4 41 ec d1 d3 42 e4 07 00 00 01 00 00 00 [...A...B........]
        # 0060: 0c 00 00 00 01 00 00 00 05 00 00 00 00 00 00 00 [................]
        ($latRef, $lonRef) = ($1, $2);
        ($hr, $min, $sec, $yr, $mon, $day) = unpack('x48V3x28V3', $$dataPt);
        SetByteOrder('II');
        $lat = GetFloat($dataPt, 0x40);
        $lon = GetFloat($dataPt, 0x48);
        $spd = GetFloat($dataPt, 0x50);
        $trk = GetFloat($dataPt, 0x54) + 180;   # (why is this off by 180?)
        $trk -= 360 if $trk >= 360;
        SetByteOrder('MM');

    } elsif ($$dataPt =~ /^.{16}YndAkasoCar/s) {

        # Akaso V1 dascham
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 78 00 00 00 [....freeGPS x...]
        #  0010: 59 6e 64 41 6b 61 73 6f 43 61 72 00 00 00 00 00 [YndAkasoCar.....]
        #  0020: 30 30 30 30 30 00 00 00 00 00 00 00 00 00 00 00 [00000...........]
        #  0030: 0e 00 00 00 27 00 00 00 2c 00 00 00 e3 07 00 00 [....'...,.......]
        #  0040: 05 00 00 00 1d 00 00 00 41 4e 45 00 00 00 00 00 [........ANE.....]
        #  0050: f1 4e 3e 3d 90 df ca 40 e3 50 bf 0b 0b 31 a0 40 [.N>=...@.P...1.@]
        #  0060: 4b dc c8 41 9a 79 a7 43 34 58 43 31 4f 37 31 35 [K..A.y.C4XC1O715]
        #  0070: 35 31 32 36 36 35 37 35 59 4e 44 53 0d e7 cc f9 [51266575YNDS....]
        #  0080: 00 00 00 00 05 00 00 00 00 00 00 00 00 00 00 00 [................]
        ($hr,$min,$sec,$yr,$mon,$day,$stat,$latRef,$lonRef) =
            unpack('x48V6a1a1a1x1', $$dataPt);
        # ignore invalid fixes
        return 0 unless $stat eq 'A' and ($latRef eq 'N' or $latRef eq 'S') and
                                         ($lonRef eq 'E' or $lonRef eq 'W');

        $et->WarnOnce("Can't yet decrypt Akaso V1 timed GPS", 1);
        # (see https://exiftool.org/forum/index.php?topic=11320.0)
        return 1;

        SetByteOrder('II');
        $lat = GetDouble($dataPt, 0x50);    # latitude is here, but encrypted somehow
        $lon = GetDouble($dataPt, 0x58);    # longitude is here, but encrypted somehow
        SetByteOrder('MM');
        #my $serialNum = substr($$dataPt, 0x68, 20);

    } elsif ($$dataPt =~ /^.{12}\xac\0\0\0.{44}(.{72})/s) {

        # EACHPAI dash cam
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 ac 00 00 00 [....freeGPS ....]
        #  0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        #  0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        #  0030: 00 00 00 00 00 00 00 00 00 00 00 00 34 57 60 62 [............4W`b]
        #  0040: 5d 53 3c 41 47 45 45 42 42 3e 40 40 40 3c 51 3c []S<AGEEBB>@@@<Q<]
        #  0050: 44 42 44 40 3e 48 46 43 45 3c 5e 3c 40 48 43 41 [DBD@>HFCE<^<@HCA]
        #  0060: 42 3e 46 42 47 48 3c 67 3c 40 3e 40 42 3c 43 3e [B>FBGH<g<@>@B<C>]
        #  0070: 43 41 3c 40 42 40 46 42 40 3c 3c 3c 51 3a 47 46 [CA<@B@FB@<<<Q:GF]
        #  0080: 00 2a 36 35 00 00 00 00 00 00 00 00 00 00 00 00 [.*65............]

        $et->WarnOnce("Can't yet decrypt EACHPAI timed GPS", 1);
        # (see https://exiftool.org/forum/index.php?topic=5095.msg61266#msg61266)
        return 1;

        my $time = pack 'C*', map { $_ ^= 0 } unpack 'C*', $1;
        # bytes 7-12 are the timestamp in ASCII HHMMSS after xor-ing with 0x70
        substr($time,7,6) = pack 'C*', map { $_ ^= 0x70 } unpack 'C*', substr($time,7,6);
        # (other values are currently unknown)

    } else {

        # decode binary GPS format (Viofo A119S, ref 2)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 4c 00 00 00 [....freeGPS L...]
        #  0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        #  0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        # (records are same structure as Type 3 Novatek GPS in ProcessFreeGPS2() below)
        ($hr,$min,$sec,$yr,$mon,$day,$stat,$latRef,$lonRef,$lat,$lon,$spd,$trk) =
            unpack('x48V6a1a1a1x1V4', $$dataPt);
        # ignore invalid fixes
        return 0 unless $stat eq 'A' and ($latRef eq 'N' or $latRef eq 'S') and
                                         ($lonRef eq 'E' or $lonRef eq 'W');
        ($lat,$lon,$spd,$trk) = unpack 'f*', pack 'L*', $lat, $lon, $spd, $trk;
        # lat/lon also stored as doubles by Transcend Driver Pro 230 (ref PH)
        SetByteOrder('II');
        my ($lat2, $lon2, $alt2) = (
            GetDouble($dataPt, 0x70),
            GetDouble($dataPt, 0x80),
          # GetDouble($dataPt, 0x98), # (don't know what this is)
            GetDouble($dataPt,0xa0),
          # GetDouble($dataPt,0xa8)) # (don't know what this is)
        );
        if (abs($lat2-$lat) < 0.001 and abs($lon2-$lon) < 0.001) {
            $lat = $lat2;
            $lon = $lon2;
            $alt = $alt2;
        }
        SetByteOrder('MM');
        $yr += 2000 if $yr < 2000;
        $spd *= $knotsToKph;    # convert speed to km/h
        # ($trk is not confirmed; may be GPSImageDirection, ref PH)
    }
#
# save tag values extracted by above code
#
    FoundSomething($et, $tagTbl, $$dirInfo{SampleTime}, $$dirInfo{SampleDuration});
    # lat/long are in DDDMM.MMMM format
    my $deg = int($lat / 100);
    $lat = $deg + ($lat - $deg * 100) / 60;
    $deg = int($lon / 100);
    $lon = $deg + ($lon - $deg * 100) / 60;
    $sec = '0' . $sec unless $sec =~ /^\d{2}/;   # pad integer part of seconds to 2 digits
    if (defined $yr) {
        my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%sZ',$yr,$mon,$day,$hr,$min,$sec);
        $et->HandleTag($tagTbl, GPSDateTime => $time);
    } elsif (defined $hr) {
        my $time = sprintf('%.2d:%.2d:%sZ',$hr,$min,$sec);
        $et->HandleTag($tagTbl, GPSTimeStamp => $time);
    }
    $et->HandleTag($tagTbl, GPSLatitude  => $lat * ($latRef eq 'S' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSLongitude => $lon * ($lonRef eq 'W' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSAltitude  => $alt) if defined $alt;
    if (defined $spd) {
        $et->HandleTag($tagTbl, GPSSpeed => $spd);
        $et->HandleTag($tagTbl, GPSSpeedRef => 'K');
    }
    if (defined $trk) {
        $et->HandleTag($tagTbl, GPSTrack => $trk);
        $et->HandleTag($tagTbl, GPSTrackRef => 'T');
    }
    while (@xtra) {
        my $tag = shift @xtra;
        $et->HandleTag($tagTbl, $tag => shift @xtra);
    }
    $et->HandleTag($tagTbl, Accelerometer => \@acc) if @acc;
    return 1;
}

#------------------------------------------------------------------------------
# Process "freeGPS " data blocks _not_ referenced by a 'gps ' atom
# Inputs: 0) ExifTool ref, 1) dirInfo ref {DataPt,DataPos,DirLen}, 2) tagTable ref
# Returns: 1 on success
# Notes:
# - also see ProcessFreeGPS() above
sub ProcessFreeGPS2($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my ($yr, $mon, $day, $hr, $min, $sec, $pos, @acc);
    my ($lat, $latRef, $lon, $lonRef, $spd, $trk, $alt, $ddd, $unk);

    return 0 if $dirLen < 82;   # minimum size of block with a single GPS record

    if (substr($$dataPt,0x45,3) eq 'ATC') {

        # header looks like this: (sample 1)
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 38 06 00 00 [....freeGPS 8...]
        #  0010: 49 51 53 32 30 31 33 30 33 30 36 42 00 00 00 00 [IQS20130306B....]
        #  0020: 4d 61 79 20 31 35 20 32 30 31 35 2c 20 31 39 3a [May 15 2015, 19:]
        # (sample 2)
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 4c 06 00 00 [....freeGPS L...]
        #  0010: 32 30 31 33 30 33 31 38 2e 30 31 00 00 00 00 00 [20130318.01.....]
        #  0020: 4d 61 72 20 31 38 20 32 30 31 33 2c 20 31 34 3a [Mar 18 2013, 14:]

        my ($recPos, $lastRecPos, $foundNew);
        my $verbose = $et->Options('Verbose');
        my $dataPos = $$dirInfo{DataPos};
        my $then = $$et{FreeGPS2}{Then};
        $then or $then = $$et{FreeGPS2}{Then} = [ (0) x 6 ];
        # Loop through records in the ATC-type GPS block until we find the most recent.
        # If we have already found one, then we only need to check the first record
        # (in case the buffer wrapped around), and the record after the position of
        # the last record we found, because the others will be old.  Odd, but this
        # is the way it is done...  I have only seen one new 52-byte record in the
        # entire 32 kB block, but the entire device ring buffer (containing 30
        # entries in my samples) is stored every time.  The code below allows for
        # the possibility of missing blocks and multiple new records in a single
        # block, but I have never seen this.  Note that there may be some earlier
        # GPS records at the end of the first block that we will miss decoding, but
        # these should (I believe) be before the start of the video
ATCRec: for ($recPos = 0x30; $recPos + 52 < $dirLen; $recPos += 52) {

            my $a = substr($$dataPt, $recPos, 52); # isolate a single record
            # decrypt record
            my @a = unpack('C*', $a);
            my ($key1, $key2) = @a[0x14, 0x1c];
            $a[$_] ^= $key1 foreach 0x00..0x14, 0x18..0x1b;
            $a[$_] ^= $key2 foreach 0x1c, 0x20..0x32;
            my $b = pack 'C*', @a;
            # unpack and validate date/time
            my @now = unpack 'x13C3x28vC2', $b; # (H-1,M,S,Y,m,d)
            $now[0] = ($now[0] + 1) & 0xff;     # increment hour
            my $i;
            for ($i=0; $i<@dateMax; ++$i) {
                next if $now[$i] <= $dateMax[$i];
                $et->WarnOnce('Invalid GPS date/time');
                next ATCRec;    # ignore this record
            }
            # look for next ATC record in temporal sequence
            foreach $i (3..5, 0..2) {
                if ($now[$i] < $$then[$i]) {
                    last ATCRec if $foundNew;
                    last;
                }
                next if $now[$i] == $$then[$i];
                # we found a more recent record -- extract it and remember its location
                if ($verbose) {
                    $et->VPrint(2, "  + [encrypted GPS record]\n");
                    $et->VerboseDump(\$a, DataPos => $dataPos + $recPos);
                    $et->VPrint(2, "  + [decrypted GPS record]\n");
                    $et->VerboseDump(\$b);
                    #my @v = unpack 'H8VVC4V!CA3V!CA3VvvV!vCCCCH4', $b;
                    #$et->VPrint(2, "  + [unpacked: @v]\n");
                    # values unpacked above (ref PH):
                    #  0) 0x00 4 bytes - byte 0=1, 1=counts to 255, 2=record index, 3=0 (ref 3)
                    #  1) 0x04 4 bytes - int32u: bits 0-4=day, 5-8=mon, 9-19=year (ref 3)
                    #  2) 0x08 4 bytes - int32u: bits 0-5=sec, 6-11=min, 12-16=hour (ref 3)
                    #  3) 0x0c 1 byte  - seen values of 0,1,2 - GPS status maybe?
                    #  4) 0x0d 1 byte  - hour minus 1
                    #  5) 0x0e 1 byte  - minute
                    #  6) 0x0f 1 byte  - second
                    #  7) 0x10 4 bytes - int32s latitude * 1e7
                    #  8) 0x14 1 byte  - always 0 (used for decryption)
                    #  9) 0x15 3 bytes - always "ATC"
                    # 10) 0x18 4 bytes - int32s longitude * 1e7
                    # 11) 0x1c 1 byte  - always 0 (used for decryption)
                    # 12) 0x1d 3 bytes - always "001"
                    # 13) 0x20 4 bytes - int32s speed * 100 (m/s)
                    # 14) 0x24 2 bytes - int16u heading * 100 (-180 to 180 deg)
                    # 15) 0x26 2 bytes - always zero
                    # 16) 0x28 4 bytes - int32s altitude * 1000 (ref 3)
                    # 17) 0x2c 2 bytes - int16u year
                    # 18) 0x2e 1 byte  - month
                    # 19) 0x2f 1 byte  - day
                    # 20) 0x30 1 byte  - unknown
                    # 21) 0x31 1 byte  - always zero
                    # 22) 0x32 2 bytes - checksum ?
                }
                @$then = @now;
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                $trk = Get16s(\$b, 0x24) / 100;
                $trk += 360 if $trk < 0;
                my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', @now[3..5, 0..2]);
                $et->HandleTag($tagTbl, GPSDateTime  => $time);
                $et->HandleTag($tagTbl, GPSLatitude  => Get32s(\$b, 0x10) / 1e7);
                $et->HandleTag($tagTbl, GPSLongitude => Get32s(\$b, 0x18) / 1e7);
                $et->HandleTag($tagTbl, GPSSpeed     => Get32s(\$b, 0x20) / 100 * $mpsToKph);
                $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
                $et->HandleTag($tagTbl, GPSTrack     => $trk);
                $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
                $et->HandleTag($tagTbl, GPSAltitude  => Get32s(\$b, 0x28) / 1000);
                $lastRecPos = $recPos;
                $foundNew = 1;
                # don't skip to location of previous recent record in ring buffer
                # since we found a more recent record here
                delete $$et{FreeGPS2}{RecentRecPos};
                last;
            }
            # skip older records
            my $recentRecPos = $$et{FreeGPS2}{RecentRecPos};
            $recPos = $recentRecPos if $recentRecPos and $recPos < $recentRecPos;
        }
        # save position of most recent record (needed when parsing the next freeGPS block)
        $$et{FreeGPS2}{RecentRecPos} = $lastRecPos;
        return 1;

    } elsif ($$dataPt =~ /^.{60}A\0.{10}([NS])\0.{14}([EW])\0/s) {

        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 08 01 00 00 [....freeGPS ....]
        #  0010: 32 30 31 33 30 38 31 35 2e 30 31 00 00 00 00 00 [20130815.01.....]
        #  0020: 4a 75 6e 20 31 30 20 32 30 31 37 2c 20 31 34 3a [Jun 10 2017, 14:]

        # Type 2 (ref PH):
        # 0x30 - int32u hour
        # 0x34 - int32u minute
        # 0x38 - int32u second
        # 0x3c - int32u GPS status ('A' or 'V')
        # 0x40 - double latitude  (DDMM.MMMMMM)
        # 0x48 - int32u latitude ref  ('N' or 'S')
        # 0x50 - double longitude (DDMM.MMMMMM)
        # 0x58 - int32u longitude ref ('E' or 'W')
        # 0x60 - double speed (knots)
        # 0x68 - double heading (deg)
        # 0x70 - int32u year - 2000
        # 0x74 - int32u month
        # 0x78 - int32u day
        # 0x7c - int32s[3] accelerometer * 1000
        ($latRef, $lonRef) = ($1, $2);
        ($hr,$min,$sec,$yr,$mon,$day,@acc) = unpack('x48V3x52V6', $$dataPt);
        map { $_ = $_ - 4294967296 if $_ >= 0x80000000; $_ /= 1000 } @acc;
        $lat = GetDouble($dataPt, 0x40);
        $lon = GetDouble($dataPt, 0x50);
        $spd = GetDouble($dataPt, 0x60) * $knotsToKph;
        $trk = GetDouble($dataPt, 0x68);

    } elsif ($$dataPt =~ /^.{72}A([NS])([EW])/s) {

        # Type 3 (Novatek GPS, ref 2): (in case it wasn't decoded via 'gps ' atom)
        # 0x30 - int32u hour
        # 0x34 - int32u minute
        # 0x38 - int32u second
        # 0x3c - int32u year - 2000
        # 0x40 - int32u month
        # 0x44 - int32u day
        # 0x48 - int8u  GPS status ('A' or 'V')
        # 0x49 - int8u  latitude ref  ('N' or 'S')
        # 0x4a - int8u  longitude ref ('E' or 'W')
        # 0x4b - 0
        # 0x4c - float  latitude  (DDMM.MMMMMM)
        # 0x50 - float  longitude (DDMM.MMMMMM)
        # 0x54 - float  speed (knots)
        # 0x58 - float  heading (deg)
        # Type 3b, same as above for 0x30-0x4a (ref PH)
        # 0x4c - int32s latitude (decimal degrees * 1e7)
        # 0x50 - int32s longitude (decimal degrees * 1e7)
        # 0x54 - int32s speed (m/s * 100)
        # 0x58 - float  altitude (m * 1000, NC)
        ($latRef, $lonRef) = ($1, $2);
        ($hr,$min,$sec,$yr,$mon,$day) = unpack('x48V6', $$dataPt);
        if (substr($$dataPt, 16, 3) eq 'IQS') {
            # Type 3b (ref PH)
            # header looks like this in my sample:
            #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 4c 00 00 00 [....freeGPS L...]
            #  0010: 49 51 53 5f 41 37 5f 32 30 31 35 30 34 31 37 00 [IQS_A7_20150417.]
            #  0020: 4d 61 72 20 32 39 20 32 30 31 37 2c 20 31 36 3a [Mar 29 2017, 16:]
            $ddd = 1;
            $lat = abs Get32s($dataPt, 0x4c) / 1e7;
            $lon = abs Get32s($dataPt, 0x50) / 1e7;
            $spd = Get32s($dataPt, 0x54) / 100 * $mpsToKph;
            $alt = GetFloat($dataPt, 0x58) / 1000; # (NC)
        } else {
            # Type 3 (ref 2)
            # (no sample with this format)
            $lat = GetFloat($dataPt, 0x4c);
            $lon = GetFloat($dataPt, 0x50);
            $spd = GetFloat($dataPt, 0x54) * $knotsToKph;
            $trk = GetFloat($dataPt, 0x58);
        }

    } else {

        # (look for binary GPS as stored by NextBase 512G, ref PH)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 78 01 00 00 [....freeGPS x...]
        #  0010: 78 2e 78 78 00 00 00 00 00 00 00 00 00 00 00 00 [x.xx............]
        #  0020: 30 30 30 30 30 00 00 00 00 00 00 00 00 00 00 00 [00000...........]

        # followed by a number of 32-byte records in this format (big endian!):
        # 0x30 - int16u unknown (seen: 0x24 0x53 = "$S")
        # 0x32 - int16u speed (m/s * 100)
        # 0x34 - int16s heading (deg * 100) (or GPSImgDirection?)
        # 0x36 - int16u year
        # 0x38 - int8u  month
        # 0x39 - int8u  day
        # 0x3a - int8u  hour
        # 0x3b - int8u  min
        # 0x3c - int16u sec * 10
        # 0x3e - int8u  unknown (seen: 2)
        # 0x3f - int32s latitude (decimal degrees * 1e7)
        # 0x43 - int32s longitude (decimal degrees * 1e7)
        # 0x47 - int8u  unknown (seen: 16)
        # 0x48-0x4f -   all zero
        for ($pos=0x32; ; ) {
            ($spd,$trk,$yr,$mon,$day,$hr,$min,$sec,$unk,$lat,$lon) = unpack "x${pos}nnnCCCCnCNN", $$dataPt;
            # validate record using date/time
            last if $yr < 2000 or $yr > 2200 or
                    $mon < 1 or $mon > 12 or
                    $day < 1 or $day > 31 or
                    $hr > 59 or $min > 59 or $sec > 600;
            # change lat/lon to signed integer and divide by 1e7
            map { $_ = $_ - 4294967296 if $_ >= 0x80000000; $_ /= 1e7 } $lat, $lon;
            $trk -= 0x10000 if $trk >= 0x8000;  # make it signed
            $trk /= 100;
            $trk += 360 if $trk < 0;
            my $time = sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%04.1fZ", $yr, $mon, $day, $hr, $min, $sec/10);
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            $et->HandleTag($tagTbl, GPSDateTime  => $time);
            $et->HandleTag($tagTbl, GPSLatitude  => $lat);
            $et->HandleTag($tagTbl, GPSLongitude => $lon);
            $et->HandleTag($tagTbl, GPSSpeed     => $spd / 100 * $mpsToKph);
            $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
            $et->HandleTag($tagTbl, GPSTrack     => $trk);
            $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
            last if $pos += 0x20 > length($$dataPt) - 0x1e;
        }
        return $$et{DOC_NUM} ? 1 : 0;   # return 0 if nothing extracted
    }
#
# save tag values extracted by above code
#
    return 0 if $mon < 1 or $mon > 12;  # quick sanity check
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $yr += 2000 if $yr < 2000;
    my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', $yr, $mon, $day, $hr, $min, $sec);
    # convert from DDMM.MMMMMM to DD.DDDDDD format if necessary
    unless ($ddd) {
        my $deg = int($lat / 100);
        $lat = $deg + ($lat - $deg * 100) / 60;
        $deg = int($lon / 100);
        $lon = $deg + ($lon - $deg * 100) / 60;
    }
    $et->HandleTag($tagTbl, GPSDateTime  => $time);
    $et->HandleTag($tagTbl, GPSLatitude  => $lat * ($latRef eq 'S' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSLongitude => $lon * ($lonRef eq 'W' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSSpeed     => $spd); # (now in km/h)
    $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
    if (defined $trk) {
        $et->HandleTag($tagTbl, GPSTrack     => $trk);
        $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
    }
    if (defined $alt) {
        $et->HandleTag($tagTbl, GPSAltitude  => $alt);
    }
    $et->HandleTag($tagTbl, Accelerometer => "@acc") if @acc;
    return 1;
}

#------------------------------------------------------------------------------
# Extract embedded information referenced from a track
# Inputs: 0) ExifTool ref, 1) tag name, 2) data ref
sub ParseTag($$$)
{
    local $_;
    my ($et, $tag, $dataPt) = @_;
    my $dataLen = length $$dataPt;

    if ($tag eq 'stsz' or $tag eq 'stz2' and $dataLen > 12) {
        # read the sample sizes
        my ($sz, $num) = unpack('x4N2', $$dataPt);
        my $size = $$et{ee}{size} = [ ];
        if ($tag eq 'stsz') {
            if ($sz == 0) {
                @$size = ReadValue($dataPt, 12, 'int32u', $num, $dataLen-12);
            } else {
                @$size = ($sz) x $num;
            }
        } else {
            $sz &= 0xff;
            if ($sz == 4) {
                my @tmp = ReadValue($dataPt, 12, 'int8u', int(($num+1)/2), $dataLen-12);
                foreach (@tmp) {
                    push @$size, $_ >> 4;
                    push @$size, $_ & 0xff;
                }
            } elsif ($sz == 8 || $sz == 16) {
                @$size = ReadValue($dataPt, 12, "int${sz}u", $num, $dataLen-12);
            }
        }
    } elsif ($tag eq 'stco' or $tag eq 'co64' and $dataLen > 8) {
        # read the chunk offsets
        my $num = unpack('x4N', $$dataPt);
        my $stco = $$et{ee}{stco} = [ ];
        @$stco = ReadValue($dataPt, 8, $tag eq 'stco' ? 'int32u' : 'int64u', $num, $dataLen-8);
    } elsif ($tag eq 'stsc' and $dataLen > 8) {
        # read the sample-to-chunk box
        my $num = unpack('x4N', $$dataPt);
        if ($dataLen >= 8 + $num * 12) {
            my ($i, @stsc);
            for ($i=0; $i<$num; ++$i) {
                # list of (first-chunk, samples-per-chunk, sample-description-index)
                push @stsc, [ unpack('x'.(8+$i*12).'N3', $$dataPt) ];
            }
            $$et{ee}{stsc} = \@stsc;
        }
    } elsif ($tag eq 'stts' and $dataLen > 8) {
        # read the time-to-sample box
        my $num = unpack('x4N', $$dataPt);
        if ($dataLen >= 8 + $num * 8) {
            $$et{ee}{stts} = [ unpack('x8N'.($num*2), $$dataPt) ];
        }
    } elsif ($tag eq 'avcC') {
        # read the AVC compressor configuration
        $$et{ee}{avcC} = $$dataPt if $dataLen >= 7;  # (minimum length is 7)
    } elsif ($tag eq 'JPEG') {
        $$et{ee}{JPEG} = $$dataPt;
    } elsif ($tag eq 'gps ' and $dataLen > 8) {
        # decode Novatek 'gps ' box (ref 2)
        my $num = Get32u($dataPt, 4);
        $num = int(($dataLen - 8) / 8) if $num * 8 + 8 > $dataLen;
        my $start = $$et{ee}{start} = [ ];
        my $size = $$et{ee}{size} = [ ];
        my $i;
        for ($i=0; $i<$num; ++$i) {
            push @$start, Get32u($dataPt, 8 + $i * 8);
            push @$size, Get32u($dataPt, 12 + $i * 8);
        }
        $$et{HandlerType} = $tag;   # fake handler type
        ProcessSamples($et);        # we have all we need to process sample data now
    } elsif ($tag eq 'GPS ') {
        my $pos = 0;
        my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
        SetByteOrder('II');
        while ($pos + 36 < $dataLen) {
            my $dat = substr($$dataPt, $pos, 36);
            last if $dat eq "\x0" x 36;
            my @a = unpack 'VVVVCVCV', $dat;
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            # 0=1, 1=1, 2=secs, 3=?
            SetGPSDateTime($et, $tagTbl, $a[2]);
            my $lat = $a[5] / 1e3;
            my $lon = $a[7] / 1e3;
            my $deg = int($lat / 100);
            $lat = $deg + ($lat - $deg * 100) / 60;
            $deg = int($lon / 100);
            $lon = $deg + ($lon - $deg * 100) / 60;
            $lat = -$lat if $a[4] eq 'S';
            $lon = -$lon if $a[6] eq 'W';
            $et->HandleTag($tagTbl, GPSLatitude  => $lat);
            $et->HandleTag($tagTbl, GPSLongitude => $lon);
            $et->HandleTag($tagTbl, GPSSpeed => $a[3] / 1e3);
            $et->HandleTag($tagTbl, GPSSpeedRef => 'K');
            $pos += 36;
        }
        SetByteOrder('MM');
        delete $$et{DOC_NUM};
    }
}

#------------------------------------------------------------------------------
# Process Yuneec 'tx3g' sbtl metadata (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_tx3g($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    return 0 if length $$dataPt < 2;
    pos($$dataPt) = 2;  # skip 2-byte length word
    $et->HandleTag($tagTablePtr, $1, $2) while $$dataPt =~ /(\w+):([^:]*[^:\s])(\s|$)/sg;
    return 1;
}

#------------------------------------------------------------------------------
# Process GM 'marl' ctbx metadata (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_marl($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    return 0 if length $$dataPt < 2;

    # 8-byte records:
    # byte 0 seems to be tag ID (0=timestamp in sec * 1e7)
    # bytes 1-3 seem to be 24-bit signed integer (unknown meaning)
    # bytes 4-7 are an int32u value, usually a multiple of 10000

    $et->WarnOnce("Can't yet decode timed GM data", 1);
    # (see https://exiftool.org/forum/index.php?topic=11335.msg61393#msg61393)
    return 1;
}

#------------------------------------------------------------------------------
# Process QuickTime 'mebx' timed metadata
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# - uses tag ID keys stored in the ExifTool ee data member by a previous call to SaveMetaKeys
sub Process_mebx($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $ee = $$et{ee} or return 0;
    return 0 unless $$ee{'keys'};
    my $dataPt = $$dirInfo{DataPt};

    # parse using information from 'keys' table (eg. Apple iPhone7+ hevc 'Core Media Data Handler')
    $et->VerboseDir('mebx', undef, length $$dataPt);
    my $pos = 0;
    while ($pos + 8 < length $$dataPt) {
        my $len = Get32u($dataPt, $pos);
        last if $len < 8 or $pos + $len > length $$dataPt;
        my $id = substr($$dataPt, $pos+4, 4);
        my $info = $$ee{'keys'}{$id};
        if ($info) {
            my $tag = $$info{TagID};
            unless ($$tagTbl{$tag}) {
                next unless $tag =~ /^[-\w.]+$/;
                # create info for tags with reasonable id's
                my $name = $tag;
                $name =~ s/[-.](.)/\U$1/g;
                AddTagToTable($tagTbl, $tag, { Name => ucfirst($name) });
            }
            my $val = ReadValue($dataPt, $pos+8, $$info{Format}, undef, $len-8);
            $et->HandleTag($tagTbl, $tag, $val,
                DataPt => $dataPt,
                Base   => $$dirInfo{Base},
                Start  => $pos + 8,
                Size   => $len - 8,
            );
        } else {
            $et->WarnOnce('No key information for mebx ID ' . PrintableTagID($id,1));
        }
        $pos += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process QuickTime '3gf' timed metadata (ref PH, Pittasoft Blackvue dashcam)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_3gf($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $recLen = 10;     # 10-byte record length
    $et->VerboseDir('3gf', undef, $dirLen);
    if ($dirLen > $recLen and not $et->Options('ExtractEmbedded')) {
        $dirLen = $recLen;
        EEWarn($et);
    }
    my $pos;
    for ($pos=0; $pos+$recLen<=$dirLen; $pos+=$recLen) {
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        my $tc = Get32u($dataPt, $pos);
        last if $tc == 0xffffffff;
        my ($x, $y, $z) = (Get16s($dataPt, $pos+4)/10, Get16s($dataPt, $pos+6)/10, Get16s($dataPt, $pos+8)/10);
        $et->HandleTag($tagTbl, TimeCode => $tc / 1000);
        $et->HandleTag($tagTbl, Accelerometer => "$x $y $z");
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Process DuDuBell M1 dashcam / VSYS M6L 'gps0' atom (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_gps0($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $recLen = 32;    # 32-byte record length
    $et->VerboseDir('gps0', undef, $dirLen);
    SetByteOrder('II');
    if ($dirLen > $recLen and not $et->Options('ExtractEmbedded')) {
        $dirLen = $recLen;
        EEWarn($et);
    }
    my $pos;
    for ($pos=0; $pos+$recLen<=$dirLen; $pos+=$recLen) {
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        # lat/long are in DDDMM.MMMM format
        my $lat = GetDouble($dataPt, $pos);
        my $lon = GetDouble($dataPt, $pos+8);
        next if abs($lat) > 9000 or abs($lon) > 18000;
        # (note: this method works fine for negative coordinates)
        my $deg = int($lat / 100);
        $lat = $deg + ($lat - $deg * 100) / 60;
        $deg = int($lon / 100);
        $lon = $deg + ($lon - $deg * 100) / 60;
        my @a = unpack('C*', substr($$dataPt, $pos+22, 6)); # unpack date/time
        $a[0] += 2000;
        $et->HandleTag($tagTbl, GPSDateTime  => sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ", @a));
        $et->HandleTag($tagTbl, GPSLatitude  => $lat);
        $et->HandleTag($tagTbl, GPSLongitude => $lon);
        $et->HandleTag($tagTbl, GPSSpeed     => Get16u($dataPt, $pos+0x14));
        $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
        $et->HandleTag($tagTbl, GPSTrack     => Get8u($dataPt, $pos+0x1c) * 2); # (NC)
        $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
        $et->HandleTag($tagTbl, GPSAltitude  => Get32s($dataPt, $pos + 0x10));
        # yet to be decoded:
        # 0x1d - int8u[3] seen: "1 1 0"
    }
    delete $$et{DOC_NUM};
    SetByteOrder('MM');
    return 1;
}

#------------------------------------------------------------------------------
# Process DuDuBell M1 dashcam / VSYS M6L 'gsen' atom (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_gsen($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $recLen = 3;     # 3-byte record length
    $et->VerboseDir('gsen', undef, $dirLen);
    if ($dirLen > $recLen and not $et->Options('ExtractEmbedded')) {
        $dirLen = $recLen;
        EEWarn($et);
    }
    my $pos;
    for ($pos=0; $pos+$recLen<=$dirLen; $pos+=$recLen) {
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        my @acc = map { $_ /= 16 } unpack "x${pos}c3", $$dataPt;
        $et->HandleTag($tagTbl, Accelerometer => "@acc");
        # (there are no associated timestamps, but these are sampled at 5 Hz in my test video)
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Process RIFF-format trailer written by Auto-Vox dashcam (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Note: This trailer is basically RIFF chunks added to a QuickTime-format file (augh!),
#       but there are differences in the record formats so we can't just call
#       ProcessRIFF to process the gps0 and gsen atoms using the routines above
sub ProcessRIFFTrailer($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my ($buff, $pos);
    SetByteOrder('II');
    for (;;) {
        last unless $raf->Read($buff, 8) == 8;
        my ($tag, $len) = unpack('a4V', $buff);
        last if $tag eq "\0\0\0\0";
        unless ($tag =~ /^[\w ]{4}/ and $len < 0x2000000) {
            $et->Warn('Bad RIFF trailer');
            last;
        }
        $raf->Read($buff, $len) == $len or $et->Warn("Truncated $tag record in RIFF trailer"), last;
        if ($verbose) {
            $et->VPrint(0, "  - RIFF trailer '${tag}' ($len bytes)\n");
            $et->VerboseDump(\$buff, Addr => $raf->Tell() - $len) if $verbose > 2;
            $$et{INDENT} .= '| ';
            $et->VerboseDir($tag, undef, $len) if $tag =~ /^(gps0|gsen)$/;
        }
        if ($tag eq 'gps0') {
            # (similar to record decoded in Process_gps0, but with some differences)
            # 0000: 41 49 54 47 74 46 94 f6 c6 c5 b4 40 34 a2 b4 37 [AITGtF.....@4..7]
            # 0010: f8 7b 8a 40 ff ff 00 00 38 00 77 0a 1a 0c 12 28 [.{.@....8.w....(]
            # 0020: 8d 01 02 40 29 07 00 00                         [...@)...]
            # 0x00 - undef[4] 'AITG'
            # 0x04 - double   latitude  (always positive)
            # 0x0c - double   longitude (always positive)
            # 0x14 - ?        seen hex "ff ff 00 00" (altitude in Process_gps0 record below)
            # 0x18 - int16u   speed in knots (different than km/hr in Process_gps0)
            # 0x1a - int8u[6] yr-1900,mon,day,hr,min,sec (different than -2000 in Process_gps0)
            # 0x20 - int8u    direction in degrees / 2
            # 0x21 - int8u    guessing that this is 1=N, 2=S - PH
            # 0x22 - int8u    guessing that this is 1=E, 2=W - PH
            # 0x23 - ?        seen hex "40"
            # 0x24 - in32u    time since start of video (ms)
            my $recLen = 0x28;
            for ($pos=0; $pos+$recLen<$len; $pos+=$recLen) {
                substr($buff, $pos, 4) eq 'AITG' or $et->Warn('Unrecognized gps0 record'), last;
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                # lat/long are in DDDMM.MMMM format
                my $lat = GetDouble(\$buff, $pos+4);
                my $lon = GetDouble(\$buff, $pos+12);
                $et->Warn('Bad gps0 record') and last if abs($lat) > 9000 or abs($lon) > 18000;
                my $deg = int($lat / 100);
                $lat = $deg + ($lat - $deg * 100) / 60;
                $deg = int($lon / 100);
                $lon = $deg + ($lon - $deg * 100) / 60;
                $lat = -$lat if Get8u(\$buff, $pos+0x21) == 2;   # wild guess
                $lon = -$lon if Get8u(\$buff, $pos+0x22) == 2;   # wild guess
                my @a = unpack('C*', substr($buff, $pos+26, 6)); # unpack date/time
                $a[0] += 1900; # (different than Proces_gps0)
                $et->HandleTag($tagTbl, SampleTime => Get32u(\$buff, $pos + 0x24) / 1000);
                $et->HandleTag($tagTbl, GPSDateTime  => sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ", @a));
                $et->HandleTag($tagTbl, GPSLatitude  => $lat);
                $et->HandleTag($tagTbl, GPSLongitude => $lon);
                $et->HandleTag($tagTbl, GPSSpeed     => Get16u(\$buff, $pos+0x18) * $knotsToKph);
                $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
                $et->HandleTag($tagTbl, GPSTrack     => Get8u(\$buff, $pos+0x20) * 2);
                $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
            }
        } elsif ($tag eq 'gsen') {
            # (similar to record decoded in Process_gsen)
            # 0000: 41 49 54 53 1a 0d 05 ff c8 00 00 00 [AITS........]
            # 0x00 - undef[4] 'AITS'
            # 0x04 - int8s[3] accelerometer readings
            # 0x07 - ?        seen hex "ff"
            # 0x08 - in32u    time since start of video (ms)
            my $recLen = 0x0c;
            for ($pos=0; $pos+$recLen<$len; $pos+=$recLen) {
                substr($buff, $pos, 4) eq 'AITS' or $et->Warn('Unrecognized gsen record'), last;
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                my @acc = map { $_ /= 24 } unpack('x'.($pos+4).'c3', $buff);
                $et->HandleTag($tagTbl, SampleTime => Get32u(\$buff, $pos + 8) / 1000);
                # 0=+Up, 1=+Right, 3=+Forward (calibration of 24 counts/g is a wild guess - PH)
                $et->HandleTag($tagTbl, Accelerometer => "@acc");
            }
        }
        # also seen, but not decoded:
        # gpsa (8 bytes): hex "01 20 00 00 08 03 02 08 "
        # gsea (20 bytes): all zeros
        $$et{INDENT} = substr($$et{INDENT}, 0, -2) if $verbose;
    }
    delete $$et{DOC_NUM};
    SetByteOrder('MM');
    return 1;
}

#------------------------------------------------------------------------------
# Process 'gps ' atom containing NMEA from Pittasoft Blackvue dashcam (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNMEA($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    # parse only RMC sentence (with leading timestamp) for now
    while ($$dataPt =~ /(?:\[(\d+)\])?\$[A-Z]{2}RMC,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d+\.\d+),([NS]),(\d+\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/g) {
        my $tc = $1;    # milliseconds since 1970 (local time)
        my ($lat,$latRef,$lon,$lonRef) = ($6,$7,$8,$9);
        my $yr = $14 + ($14 >= 70 ? 1900 : 2000);
        my ($mon,$day,$hr,$min,$sec) = ($13,$12,$2,$3,$4);
        my ($spd, $trk);
        $spd = $10 * $knotsToKph if length $10;
        $trk = $11 if length $11;
        # lat/long are in DDDMM.MMMM format
        my $deg = int($lat / 100);
        $lat = $deg + ($lat - $deg * 100) / 60;
        $deg = int($lon / 100);
        $lon = $deg + ($lon - $deg * 100) / 60;
        $sec = '0' . $sec unless $sec =~ /^\d{2}/;   # pad integer part of seconds to 2 digits
        my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%sZ',$yr,$mon,$day,$hr,$min,$sec);
        my $sampleTime;
        $sampleTime = ($tc - $$et{StartTime}) / 1000 if $tc and $$et{StartTime};
        FoundSomething($et, $tagTbl, $sampleTime);
        $et->HandleTag($tagTbl, GPSDateTime => $time);
        $et->HandleTag($tagTbl, GPSLatitude  => $lat * ($latRef eq 'S' ? -1 : 1));
        $et->HandleTag($tagTbl, GPSLongitude => $lon * ($lonRef eq 'W' ? -1 : 1));
        if (defined $spd) {
            $et->HandleTag($tagTbl, GPSSpeed => $spd);
            $et->HandleTag($tagTbl, GPSSpeedRef => 'K');
        }
        if (defined $trk) {
            $et->HandleTag($tagTbl, GPSTrack => $trk);
            $et->HandleTag($tagTbl, GPSTrackRef => 'T');
        }
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Process TomTom Bandit Action Cam TTAD atom (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
my %ttLen = ( # lengths of known TomTom records
    0 => 12,    # angular velocity (NC)
    1 => 4,     # ?
    2 => 12,    # ?
    3 => 12,    # accelerometer (NC)
    # (haven't seen a record 4 yet)
    5 => 92,    # GPS
    0xff => 4,  # timecode
);
sub ProcessTTAD($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $pos = 76;

    return 0 if $dirLen < $pos;

    $et->VerboseDir('TTAD', undef, $dirLen);
    SetByteOrder('II');

    my $eeOpt = $et->Options('ExtractEmbedded');
    my $unknown = $et->Options('Unknown');
    my $found = 0;
    my $sampleTime = 0;
    my $resync = 1;
    my $skipped = 0;
    my $warned;

    while ($pos < $dirLen) {
        # get next record type
        my $type = Get8u($dataPt, $pos++);
        # resync if necessary by skipping data until next timecode record
        if ($resync and $type != 0xff) {
            ++$skipped > 0x100 and $et->Warn('Unrecognized or bad TTAD data', 1), last;
            next;
        }
        unless ($ttLen{$type}) {
            # skip unknown records
            $et->Warn("Unknown TTAD record type $type",1) unless $warned;
            $resync = $warned = 1;
            ++$skipped;
            next;
        }
        last if $pos + $ttLen{$type} > $dirLen;
        if ($type == 0xff) {    # timecode?
            my $tm = Get32u($dataPt, $pos);
            # validate timecode if skipping unknown data
            if ($resync) {
                if ($tm < $sampleTime or $tm > $sampleTime + 250) {
                    ++$skipped;
                    next;
                }
                undef $resync;
                $skipped = 0;
            }
            $pos += $ttLen{$type};
            $sampleTime = $tm;
            next;
        }
        unless ($eeOpt) {
            # only extract one of each type without -ee option
            $found & (1 << $type) and $pos += $ttLen{$type}, next;
            $found |= (1 << $type);
        }
        if ($type == 0 or $type == 3) {
            # (these are both just educated guesses - PH)
            FoundSomething($et, $tagTbl, $sampleTime / 1000);
            my @a = map { Get32s($dataPt,$pos+4*$_) / 1000 } 0..2;
            $et->HandleTag($tagTbl, ($type ? 'Accelerometer' : 'AngularVelocity') => "@a");
        } elsif ($type == 5) {
            # example records unpacked with 'dVddddVddddv*'
            # datetime                 ? spd  ele    lat        lon       ? trk   ?     ?      ?      ? ? ? ?     ? ?
            # 2019:03:05 07:52:58.999Z 3 0.02 242    48.0254203 7.8497567 0 45.69 13.34 17.218 17.218 0 0 0 32760 5 0
            # 2019:03:05 07:52:59.999Z 3 0.14 242    48.0254203 7.8497567 0 45.7  12.96 15.662 15.662 0 0 0 32760 5 0
            # 2019:03:05 07:53:00.999Z 3 0.67 243.78 48.0254584 7.8497907 0 50.93  9.16 10.84  10.84  0 0 0 32760 5 0
            # (I think "5" may be the number of satellites.  seen: 5,6,7 - PH)
            FoundSomething($et, $tagTbl, $sampleTime / 1000);
            my $t = GetDouble($dataPt, $pos);
            $et->HandleTag($tagTbl, GPSDateTime  => Image::ExifTool::ConvertUnixTime($t,undef,3).'Z');
            $et->HandleTag($tagTbl, GPSLatitude  => GetDouble($dataPt, $pos+0x1c));
            $et->HandleTag($tagTbl, GPSLongitude => GetDouble($dataPt, $pos+0x24));
            $et->HandleTag($tagTbl, GPSAltitude  => GetDouble($dataPt, $pos+0x14));
            $et->HandleTag($tagTbl, GPSSpeed     => GetDouble($dataPt, $pos+0x0c) * $mpsToKph);
            $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
            $et->HandleTag($tagTbl, GPSTrack     => GetDouble($dataPt, $pos+0x30));
            $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
            if ($unknown) {
                my @a = map { GetDouble($dataPt, $pos+0x38+8*$_) } 0..2;
                $et->HandleTag($tagTbl, Unknown03 => "@a");
            }
        } elsif ($type < 3) {
            # as yet unknown:
            # 1 - int32s[1]? (values around 98k)
            # 2 - int32s[3] (values like "806 8124 4323" -- probably something * 1000 again)
            if ($unknown) {
                FoundSomething($et, $tagTbl, $sampleTime / 1000);
                my $n = $type == 1 ? 0 : 2;
                my @a = map { Get32s($dataPt,$pos+4*$_) } 0..$n;
                $et->HandleTag($tagTbl, "Unknown0$type" => "@a");
            }
        } else {
            $et->WarnOnce("Unknown TTAD record type $type",1);
        }
        # without -ee, stop after we find types 0,3,5 (ie. bitmask 0x29)
        $eeOpt or ($found & 0x29) != 0x29 or EEWarn($et), last;
        $pos += $ttLen{$type};
    }
    SetByteOrder('MM');
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from Insta360 trailer (INSV and INSP files) (ref PH)
# Inputs: 0) ExifTool ref, 1) Optional dirInfo ref for returning trailer info
# Returns: true on success
sub ProcessInsta360($;$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my $raf = $$et{RAF};
    my $offset = $dirInfo ? $$dirInfo{Offset} || 0 : 0;
    my $buff;

    return 0 unless $raf->Seek(-78-$offset, 2) and $raf->Read($buff, 78) == 78 and
        substr($buff,-32) eq "8db42d694ccc418790edff439fe026bf";    # check magic number

    my $verbose = $et->Options('Verbose');
    my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
    my $fileEnd = $raf->Tell();
    my $trailerLen = unpack('x38V', $buff);
    $trailerLen > $fileEnd and $et->Warn('Bad Insta360 trailer size'), return 0;
    if ($dirInfo) {
        $$dirInfo{DirLen} = $trailerLen if $dirInfo;
        $$dirInfo{DataPos} = $fileEnd - $trailerLen;
        if ($$dirInfo{OutFile}) {
            if ($$et{DEL_GROUP}{Insta360}) {
                ++$$et{CHANGED};
            # just copy the trailer when writing
            } elsif ($trailerLen > $fileEnd or not $raf->Seek($$dirInfo{DataPos}, 0) or
                     $raf->Read(${$$dirInfo{OutFile}}, $trailerLen) != $trailerLen)
            {
                return 0;
            } else {
                return 1;
            }
        }
        $et->DumpTrailer($dirInfo) if $verbose or $$et{HTML_DUMP};
    }
    unless ($et->Options('ExtractEmbedded')) {
        # can arrive here when reading Insta360 trailer on JPEG image (INSP file)
        $et->WarnOnce('Use ExtractEmbedded option to extract timed metadata from Insta360 trailer',3);
        return 1;
    }

    my $unknown = $et->Options('Unknown');
    # position relative to end of trailer (avoids using large offsets for files > 2 GB)
    my $epos = -78-$offset;
    my ($i, $p);
    $$et{SET_GROUP0} = 'Trailer';
    $$et{SET_GROUP1} = 'Insta360';
    SetByteOrder('II');
    # loop through all records in the trailer, from last to first
    for (;;) {
        my ($id, $len) = unpack('vV', $buff);
        ($epos -= $len) + $trailerLen < 0 and last;
        $raf->Seek($epos, 2) or last;
        my $dlen = $insvDataLen{$id};
        if ($verbose) {
            $et->VPrint(0, sprintf("Insta360 Record 0x%x (offset 0x%x, %d bytes):\n", $id, $fileEnd + $epos, $len));
        }
        # limit the number of records we read if necessary
        if ($insvLimit{$id} and $len > $insvLimit{$id}[1] * $dlen and
            $et->Warn("Insta360 $insvLimit{$id}[0] data is huge. Processing only the first $insvLimit{$id}[1] records",2))
        {
            $len = $insvLimit{$id}[1] * $dlen;
        }
        $raf->Read($buff, $len) == $len or last;
        $et->VerboseDump(\$buff) if $verbose > 2;
        if ($dlen) {
            $len % $dlen and $et->Warn(sprintf('Unexpected Insta360 record 0x%x length',$id)), last;
            if ($id == 0x300) {
                for ($p=0; $p<$len; $p+=$dlen) {
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                    my @a = map { GetDouble(\$buff, $p + 8 * $_) } 1..6;
                    $et->HandleTag($tagTbl, TimeCode => sprintf('%.3f', Get64u(\$buff, $p) / 1000));
                    $et->HandleTag($tagTbl, Accelerometer => "@a[0..2]"); # (NC)
                    $et->HandleTag($tagTbl, AngularVelocity => "@a[3..5]"); # (NC)
                }
            } elsif ($id == 0x400) {
                for ($p=0; $p<$len; $p+=$dlen) {
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                    $et->HandleTag($tagTbl, TimeCode => sprintf('%.3f', Get64u(\$buff, $p) / 1000));
                    $et->HandleTag($tagTbl, ExposureTime => GetDouble(\$buff, $p + 8)); #6
                }
            } elsif ($id == 0x600) { #6
                for ($p=0; $p<$len; $p+=$dlen) {
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                    $et->HandleTag($tagTbl, VideoTimeStamp => sprintf('%.3f', Get64u(\$buff, $p) / 1000));
                }
            } elsif ($id == 0x700) {
                for ($p=0; $p<$len; $p+=$dlen) {
                    my $tmp = substr($buff, $p, $dlen);
                    my @a = unpack('VVvaa8aa8aa8a8a8', $tmp);
                    next unless $a[3] eq 'A';   # (ignore void fixes)
                    last unless ($a[5] eq 'N' or $a[5] eq 'S') and # (quick validation)
                                ($a[7] eq 'E' or $a[7] eq 'W');
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                    $a[$_] = GetDouble(\$a[$_], 0) foreach 4,6,8,9,10;
                    $a[4] = -abs($a[4]) if $a[5] eq 'S'; # (abs just in case it was already signed)
                    $a[6] = -abs($a[6]) if $a[7] eq 'W';
                    $et->HandleTag($tagTbl, GPSDateTime => Image::ExifTool::ConvertUnixTime($a[0]) . 'Z');
                    $et->HandleTag($tagTbl, GPSLatitude => $a[4]);
                    $et->HandleTag($tagTbl, GPSLongitude => $a[6]);
                    $et->HandleTag($tagTbl, GPSSpeed => $a[8] * $mpsToKph);
                    $et->HandleTag($tagTbl, GPSSpeedRef => 'K');
                    $et->HandleTag($tagTbl, GPSTrack => $a[9]);
                    $et->HandleTag($tagTbl, GPSTrackRef => 'T');
                    $et->HandleTag($tagTbl, GPSAltitude => $a[10]);
                    $et->HandleTag($tagTbl, Unknown02 => "@a[1,2]") if $unknown;
                }
            }
        } elsif ($id == 0x101) {
            my $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::INSV_MakerNotes');
            for ($i=0, $p=0; $i<4; ++$i) {
                last if $p + 2 > $len;
                my ($t, $n) = unpack("x${p}CC", $buff);
                last if $p + 2 + $n > $len;
                my $val = substr($buff, $p+2, $n);
                $et->HandleTag($tagTablePtr, $t, $val);
                $p += 2 + $n;
            }
        }
        ($epos -= 6) + $trailerLen < 0 and last;    # step back to previous record
        $raf->Seek($epos, 2) or last;
        $raf->Read($buff, 6) == 6 or last;
    }
    $$et{DOC_NUM} = 0;
    SetByteOrder('MM');
    delete $$et{SET_GROUP0};
    delete $$et{SET_GROUP1};
    return 1;
}

#------------------------------------------------------------------------------
# Process 360Fly 'uuid' atom containing sensor data
# (ref https://github.com/JamesHeinrich/getID3/blob/master/getid3/module.audio-video.quicktime.php)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process360Fly($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = length $$dataPt;
    my $pos = 16;
    my $lastTime = -1;
    my $streamTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
    while ($pos + 32 <= $dataLen) {
        my $type = ord substr $$dataPt, $pos, 1;
        my $time = Get64u($dataPt, $pos + 2); # (only valid for some types)
        if ($$tagTbl{$type}) {
            if ($time != $lastTime) {
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                $lastTime = $time;
            }
        }
        $et->HandleTag($tagTbl, $type, undef, DataPt => $dataPt, Start => $pos, Size => 32);
        # synthesize GPSDateTime from the timestamp for GPS records
        SetGPSDateTime($et, $streamTbl, $time / 1e6) if $type == 5;
        $pos += 32;
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Scan media data for "freeGPS" metadata if not found already (ref PH)
# Inputs: 0) ExifTool ref
sub ScanMediaData($)
{
    my $et = shift;
    my $raf = $$et{RAF} or return;
    my ($tagTbl, $oldByteOrder, $verbose, $buff, $dataLen);
    my ($pos, $buf2) = (0, '');

    # don't rescan for freeGPS if we already found embedded metadata
    my $dataPos = $$et{VALUE}{MediaDataOffset};
    if ($dataPos and not $$et{DOC_COUNT}) {
        $dataLen = $$et{VALUE}{MediaDataSize};
        if ($dataLen) {
            if ($raf->Seek($dataPos, 0)) {
                $$et{FreeGPS2} = { };   # initialize variable space for FreeGPS2()
            } else {
                undef $dataLen;
            }
        }
    }

    # loop through 'mdat' media data looking for GPS information
    while ($dataLen) {
        last if $pos + $gpsBlockSize > $dataLen;
        last unless $raf->Read($buff, $gpsBlockSize);
        $buff = $buf2 . $buff if length $buf2;
        last if length $buff < $gpsBlockSize;
        # look for "freeGPS " block
        # (found on an absolute 0x8000-byte boundary in all of my samples,
        #  but allow for any alignment when searching)
        if ($buff !~ /\0..\0freeGPS /sg) { # (seen ".." = "\0\x80","\x01\0")
            $buf2 = substr($buff,-12);
            $pos += length($buff)-12;
            # in all of my samples the first freeGPS block is within 2 MB of the start
            # of the mdat, so limit the scan to the first 20 MB to be fast and safe
            next if $tagTbl or $pos < 20e6;
            last;
        } elsif (not $tagTbl) {
            # initialize variables for extracting metadata from this block
            $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            $verbose = $$et{OPTIONS}{Verbose};
            $oldByteOrder = GetByteOrder();
            SetByteOrder('II');
            $et->VPrint(0, "---- Extract Embedded ----\n");
            $$et{INDENT} .= '| ';
        }
        if (pos($buff) > 12) {
            $pos += pos($buff) - 12;
            $buff = substr($buff, pos($buff) - 12);
        }
        # make sure we have the full freeGPS record
        my $len = unpack('N', $buff);
        if ($len < 12) {
            $len = 12;
        } else {
            my $more = $len - length($buff);
            if ($more > 0) {
                last unless $raf->Read($buf2, $more) == $more;
                $buff .= $buf2;
            }
            if ($verbose) {
                $et->VerboseDir('GPS', undef, $len);
                $et->VerboseDump(\$buff, DataPos => $pos + $dataPos);
            }
            my $dirInfo = { DataPt => \$buff, DataPos => $pos + $dataPos, DirLen => $len };
            ProcessFreeGPS2($et, $dirInfo, $tagTbl);
        }
        $pos += $len;
        $buf2 = substr($buff, $len);
    }
    if ($tagTbl) {
        $$et{DOC_NUM} = 0;
        $et->VPrint(0, "--------------------------\n");
        SetByteOrder($oldByteOrder);
        $$et{INDENT} = substr $$et{INDENT}, 0, -2;
    }
    # process Insta360 trailer if it exists
    ProcessInsta360($et);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Extract embedded information from media data

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::QuickTime.

=head1 DESCRIPTION

This file contains routines used by Image::ExifTool to extract embedded
information like GPS tracks from MOV, MP4 and INSV media data.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item Lhttps://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW130>

=item L<http://sergei.nz/files/nvtk_mp42gpx.py>

=item L<https://forum.flitsservice.nl/dashcam-info/dod-ls460w-gps-data-uit-mov-bestand-lezen-t87926.html>

=item L<https://developers.google.com/streetview/publish/camm-spec>

=item L<https://sergei.nz/extracting-gps-data-from-viofo-a119-and-other-novatek-powered-cameras/>

=back

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool::TagNames/QuickTime Stream Tags>,
L<Image::ExifTool::TagNames/GoPro GPMF Tags>,
L<Image::ExifTool::TagNames/Sony rtmd Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

