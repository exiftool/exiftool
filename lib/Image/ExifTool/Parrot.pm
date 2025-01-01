#------------------------------------------------------------------------------
# File:         Parrot.pm
#
# Description:  Read timed metadata from Parrot drone videos
#
# Revisions:    2019-10-23 - P. Harvey Created
#
# References:   1) https://developer.parrot.com/docs/pdraw/metadata.html
#               --> changed to https://developer.parrot.com/docs/pdraw/video-metadata.html
#------------------------------------------------------------------------------

package Image::ExifTool::Parrot;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

sub Process_mett($$$);

# tags found in Parrot 'mett' timed metadata (ref 1)
%Image::ExifTool::Parrot::mett = (
    PROCESS_PROC => \&Process_mett,
    # put the 'P' records first in the documentation
    VARS => {
        SORT_PROC => sub { my ($a,$b)=@_; $a=~s/P/A/; $b=~s/P/A/; $a cmp $b },
        LONG_TAGS => 1
    },
    NOTES => q{
        Streaming metadata found in Parrot drone videos. See
        L<https://developer.parrot.com/docs/pdraw/metadata.html> for the
        specification.
    },
    P1 => {
        Name => 'ParrotV1',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::V1' },
    },
    P2 => {
        Name => 'ParrotV2',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::V2' },
    },
    P3 => {
        Name => 'ParrotV3',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::V3' },
    },
    E1 => {
        Name => 'ParrotTimeStamp',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::TimeStamp' },
    },
    E2 => {
        Name => 'ParrotFollowMe',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::FollowMe' },
    },
    E3 => {
        Name => 'ParrotAutomation',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::Automation' },
    },
    # timed metadata written by ARCore (see forum13653)
    'application/arcore-accel' => {
        Name => 'ARCoreAccel',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::ARCoreAccel', ByteOrder => 'II' },
    },
    'application/arcore-gyro' => {
        Name => 'ARCoreGyro',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::ARCoreGyro', ByteOrder => 'II' },
    },
    'application/arcore-video-0' => {
        Name => 'ARCoreVideo',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::ARCoreVideo', ByteOrder => 'II' },
    },
    'application/arcore-custom-event' => {
        Name => 'ARCoreCustom',
        SubDirectory => { TagTable => 'Image::ExifTool::Parrot::ARCoreCustom', ByteOrder => 'II' },
    },
);

# tags found in the Parrot 'mett' V1 timed metadata (ref 1) [untested]
%Image::ExifTool::Parrot::V1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'Parrot version 1 streaming metadata.',
    GROUPS => { 2 => 'Location' },
    4 => {
        Name => 'DroneYaw',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159', # convert from rad to deg
    },
    6 => {
        Name => 'DronePitch',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159',
    },
    8 => {
        Name => 'DroneRoll',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159',
    },
    10 => {
        Name => 'CameraPan',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159',
    },
    12 => {
        Name => 'CameraTilt',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159',
    },
    14 => {
        Name => 'FrameView',        # (W,X,Y,Z)
        Format => 'int16s[4]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x1000 foreach @a; "@a"',
    },
    22 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Camera' },
        Format => 'int16s',
        ValueConv => '$val / 0x100 / 1000',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    24 => {
        Name => 'ISO',
        Groups => { 2 => 'Camera' },
        Format => 'int16s',
    },
    26 => {
        Name => 'WifiRSSI',
        Groups => { 2 => 'Device' },
        Format => 'int8s',
        PrintConv => '"$val dBm"',
    },
    27 => {
        Name => 'Battery',
        Groups => { 2 => 'Device' },
        PrintConv => '"$val %"',
    },
    28 => {
        Name => 'GPSLatitude',
        Format => 'int32s',
        ValueConv => '$val / 0x100000',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    32 => {
        Name => 'GPSLongitude',
        Format => 'int32s',
        ValueConv => '$val / 0x100000',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    36 => {
        Name => 'GPSAltitude',
        Format => 'int32s',
        Mask => 0xffffff00,
        ValueConv => '$val / 0x100',
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    36.1 => {
        Name => 'GPSSatellites',    # (SV count)
        Format => 'int32s',
        Mask => 0xff,
    },
    40 => {
        Name => 'AltitudeFromTakeOff',
        Format => 'int32s',
        ValueConv => '$val / 0x10000',
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    44 => {
        Name => 'DistanceFromHome',
        Format => 'int32u',
        ValueConv => '$val / 0x10000',
    },
    48 => {
        Name => 'SpeedX',
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    50 => {
        Name => 'SpeedY',
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    52 => {
        Name => 'SpeedZ',
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    54 => {
        Name => 'Binning',
        Groups => { 2 => 'Device' },
        Mask => 0x80,
    },
    54.1 => {
        Name => 'FlyingState',
        Groups => { 2 => 'Device' },
        Mask => 0x7f,
        PrintConv => {
            0 => 'Landed',
            1 => 'Taking Off',
            2 => 'Hovering',
            3 => 'Flying',
            4 => 'Landing',
            5 => 'Emergency',
        },
    },
    55 => {
        Name => 'Animation',
        Groups => { 2 => 'Device' },
        Mask => 0x80,
    },
    55.1 => {
        Name => 'PilotingMode',
        Groups => { 2 => 'Device' },
        Mask => 0x7f,
        PrintConv => {
            0 => 'Manual',
            1 => 'Return Home',
            2 => 'Flight Plan',
            3 => 'Follow Me',
        },
    },
);

# tags found in the Parrot 'mett' V2 timed metadata (ref 1) [untested]
%Image::ExifTool::Parrot::V2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    Groups => { 2 => 'Location' },
    NOTES => 'Parrot version 2 basic streaming metadata.',
    4 => {
        Name => 'Elevation',
        Notes => 'estimated distance from ground',
        Format => 'int32s',
        ValueConv => '$val / 0x10000',
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    8 => {
        Name => 'GPSLatitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    12 => {
        Name => 'GPSLongitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    16 => {
        Name => 'GPSAltitude',
        Format => 'int32s',
        Mask => 0xffffff00,
        ValueConv => '$val / 0x100',
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    16.1 => {
        Name => 'GPSSatellites',    # (SV count)
        Format => 'int32s',
        Mask => 0xff,
    },
    20 => {
        Name => 'GPSVelocityNorth', # (m/s)
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    22 => {
        Name => 'GPSVelocityEast',  # (m/s)
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    24 => {
        Name => 'GPSVelocityDown',  # (m/s)
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    26 => {
        Name => 'AirSpeed',         # (m/s)
        Format => 'int16s',
        RawConv => '$val < 0 ? undef : $val',
        ValueConv => '$val / 0x100',
    },
    28 => {
        Name => 'DroneQuaternion',  # (W,X,Y,Z)
        Format => 'int16s[4]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x4000 foreach @a; "@a"',
    },
    36 => {
        Name => 'FrameView',        # (W,X,Y,Z)
        Format => 'int16s[4]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x4000 foreach @a; "@a"',
    },
    44 => {
        Name => 'CameraPan',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159', # convert from rad to deg
    },
    46 => {
        Name => 'CameraTilt',
        Format => 'int16s',
        ValueConv => '$val / 0x1000 * 180 / 3.14159',
    },
    48 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
        ValueConv => '$val / 0x100 / 1000',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    50 => {
        Name => 'ISO',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
    },
    52 => {
        Name => 'Binning',
        Groups => { 2 => 'Device' },
        Mask => 0x80,
    },
    52.1 => {
        Name => 'FlyingState',
        Groups => { 2 => 'Device' },
        Mask => 0x7f,
        PrintConv => {
            0 => 'Landed',
            1 => 'Taking Off',
            2 => 'Hovering',
            3 => 'Flying',
            4 => 'Landing',
            5 => 'Emergency',
            6 => 'User Takeoff',
            7 => 'Motor Ramping',
            8 => 'Emergency Landing',
        },
    },
    53 => {
        Name => 'Animation',
        Groups => { 2 => 'Device' },
        Mask => 0x80,
    },
    53.1 => {
        Name => 'PilotingMode',
        Groups => { 2 => 'Device' },
        Mask => 0x7f,
        PrintConv => {
            0 => 'Manual',
            1 => 'Return Home',
            2 => 'Flight Plan',
            3 => 'Follow Me / Tracking', # (same as 'Tracking')
            4 => 'Magic Carpet',
            5 => 'Move To',
        },
    },
    54 => {
        Name => 'WifiRSSI',
        Groups => { 2 => 'Device' },
        Format => 'int8s',
        PrintConv => '"$val dBm"',
    },
    55 => {
        Name => 'Battery',
        Groups => { 2 => 'Device' },
        PrintConv => '"$val %"',
    },
);

# tags found in the Parrot 'mett' V3 timed metadata (ref 1)
%Image::ExifTool::Parrot::V3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    NOTES => 'Parrot version 3 basic streaming metadata.',
    4 => {
        Name => 'Elevation',
        Notes => 'estimated distance from ground',
        Format => 'int32s',
        ValueConv => '$val / 0x10000',
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    8 => {
        Name => 'GPSLatitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    12 => {
        Name => 'GPSLongitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    16 => {
        Name => 'GPSAltitude',
        Format => 'int32s',
        Mask => 0xffffff00,
        ValueConv => '$val / 0x100',
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    16.1 => {
        Name => 'GPSSatellites',    # (SV count)
        Format => 'int32s',
        Mask => 0xff,
    },
    20 => {
        Name => 'GPSVelocityNorth', # (m/s)
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    22 => {
        Name => 'GPSVelocityEast',  # (m/s)
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    24 => {
        Name => 'GPSVelocityDown',  # (m/s)
        Format => 'int16s',
        ValueConv => '$val / 0x100',
    },
    26 => {
        Name => 'AirSpeed',         # (m/s)
        Format => 'int16s',
        RawConv => '$val < 0 ? undef : $val',
        ValueConv => '$val / 0x100',
    },
    28 => {
        Name => 'DroneQuaternion',  # (W,X,Y,Z)
        Format => 'int16s[4]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x4000 foreach @a; "@a"',
    },
    36 => {
        Name => 'FrameBaseView',    # (W,X,Y,Z without pan/tilt)
        Format => 'int16s[4]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x4000 foreach @a; "@a"',
    },
    44 => {
        Name => 'FrameView',        # (W,X,Y,Z)
        Format => 'int16s[4]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x4000 foreach @a; "@a"',
    },
    52 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
        ValueConv => '$val / 0x100 / 1000',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    54 => {
        Name => 'ISO',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
    },
    56 => {
        Name => 'RedBalance',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
        ValueConv => '$val / 0x4000',
    },
    58 => {
        Name => 'BlueBalance',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
        ValueConv => '$val / 0x4000',
    },
    60 => {
        Name => 'FOV',              # (degrees)
        Description => 'Field Of View',
        Notes => 'horizontal and vertical field of view in degrees',
        Groups => { 2 => 'Image' },
        Format => 'int16u[2]',
        ValueConv => 'my @a = split " ",$val; $_ /= 0x100 foreach @a; "@a"',
    },
    64 => {
        Name => 'LinkGoodput',
        Groups => { 2 => 'Device' },
        Format => 'int32u',
        Mask => 0xffffff00,
        PrintConv => '"$val kbit/s"',
    },
    64.1 => {
        Name => 'LinkQuality',
        Groups => { 2 => 'Device' },
        Format => 'int32u',
        Notes => '0-5',
        Mask => 0xff,
    },
    68 => {
        Name => 'WifiRSSI',
        Groups => { 2 => 'Device' },
        Format => 'int8s',
        PrintConv => '"$val dBm"',
    },
    69 => {
        Name => 'Battery',
        Groups => { 2 => 'Device' },
        PrintConv => '"$val %"',
    },
    70 => {
        Name => 'Binning',
        Groups => { 2 => 'Device' },
        Mask => 0x80,
    },
    70.1 => {
        Name => 'FlyingState',
        Groups => { 2 => 'Device' },
        Mask => 0x7f,
        PrintConv => {
            0 => 'Landed',
            1 => 'Taking Off',
            2 => 'Hovering',
            3 => 'Flying',
            4 => 'Landing',
            5 => 'Emergency',
            6 => 'User Takeoff',
            7 => 'Motor Ramping',
            8 => 'Emergency Landing',
        },
    },
    71 => {
        Name => 'Animation',
        Groups => { 2 => 'Device' },
        Mask => 0x80,
    },
    71.1 => {
        Name => 'PilotingMode',
        Groups => { 2 => 'Device' },
        Mask => 0x7f,
        PrintConv => {
            0 => 'Manual',
            1 => 'Return Home',
            2 => 'Flight Plan',
            3 => 'Follow Me / Tracking', # (same as 'Tracking')
            4 => 'Magic Carpet',
            5 => 'Move To',
        },
    },
);

# tags found in the Parrot 'mett' E1 timestamp timed metadata (ref 1)
%Image::ExifTool::Parrot::TimeStamp = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'Parrot streaming metadata timestamp extension.',
    GROUPS => { 2 => 'Time' },
    4 => {
        Name => 'TimeStamp',
        Format => 'int64u',
        ValueConv => '$val / 1e6',
    },
);

# tags found in the Parrot 'mett' E2 follow-me timed metadata (ref 1) [untested]
%Image::ExifTool::Parrot::FollowMe = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    NOTES => 'Parrot streaming metadata follow-me extension.',
    4 => {
        Name => 'GPSTargetLatitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
    },
    8 => {
        Name => 'GPSTargetLongitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
    },
    12 => {
        Name => 'GPSTargetAltitude',
        Format => 'int32s',
        ValueConv => '$val / 0x10000',
    },
    16 => {
        Name => 'Follow-meMode',
        Groups => { 2 => 'Device' },
        PrintConv => { BITMASK => {
            0 => 'Follow-me enabled',
            1 => 'Follow-me',           # (0=Look-at-me! auggh. see AutomationFlags below)
            2 => 'Angle locked',
        }},
    },
    17 => {
        Name => 'Follow-meAnimation',
        Groups => { 2 => 'Device' },
        PrintConv => {
            0 => 'None',
            1 => 'Orbit',
            2 => 'Boomerang',
            3 => 'Parabola',
            4 => 'Zenith',
        },
    },
);

# tags found in the Parrot 'mett' E3 automation timed metadata (ref 1)
%Image::ExifTool::Parrot::Automation = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    NOTES => 'Parrot streaming metadata automation extension.',
    4 => {
        Name => 'GPSFramingLatitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
    },
    8 => {
        Name => 'GPSFramingLongitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
    },
    12 => {
        Name => 'GPSFramingAltitude',
        Format => 'int32s',
        ValueConv => '$val / 0x10000',
    },
    16 => {
        Name => 'GPSDestLatitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
    },
    20 => {
        Name => 'GPSDestLongitude',
        Format => 'int32s',
        ValueConv => '$val / 0x400000',
    },
    24 => {
        Name => 'GPSDestAltitude',
        Format => 'int32s',
        ValueConv => '$val / 0x10000',
    },
    28 => {
        Name => 'AutomationAnimation',
        Groups => { 2 => 'Device' },
        PrintConv => {
            0 => 'None',
            1 => 'Orbit',
            2 => 'Boomerang',
            3 => 'Parabola',
            4 => 'Dolly Slide',
            5 => 'Dolly Zoom',
            6 => 'Reveal Vertical',
            7 => 'Reveal Horizontal',
            8 => 'Candle',
            9 => 'Flip Front',
            10 => 'Flip Back',
            11 => 'Flip Left',
            12 => 'Flip Right',
            13 => 'Twist Up',
            14 => 'Position Twist Up',
        },
    },
    29 => {
        Name => 'AutomationFlags',
        Groups => { 2 => 'Device' },
        PrintConv => { BITMASK => {
            0 => 'Follow-me enabled',
            1 => 'Look-at-me enabled',  # (really? opposite sense to Follow-meMode above!)
            2 => 'Angle locked',
        }},
    },
);

# ARCore Accel data (ref PH)
%Image::ExifTool::Parrot::ARCoreAccel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    NOTES => 'ARCore accelerometer data.',
    FIRST_ENTRY => 0,
    # 00-04: always 10 34 16 1 29
    4  => {
        Name => 'AccelerometerUnknown',
        Format => 'undef[16]',
        Unknown => 1,
        ValueConv => 'join " ", unpack("Cx4Cx4Cx4C", $val)',
    },
    5  => { # (NC)
        Name => 'Accelerometer',
        Format => 'undef[14]',
        RawConv => 'GetFloat(\$val,0) . " " . GetFloat(\$val,5) . " " . GetFloat(\$val,10)',
    },
    # 05-08: float Accelerometer X
    # 09: 37
    # 10-13: float Accelerometer Y
    # 14: 45
    # 15-18: float Accelerometer Z
    # 19: 48
    # 20-24: 128-255
    # 25: 246 then 247
    # 26: 188
    # 27: 2
    # 28: 56
    # 29-32: 128-255
    # 33: increments slowly (about once every 56 samples or so)
);

# ARCore Gyro data (ref PH)
%Image::ExifTool::Parrot::ARCoreGyro = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    NOTES => 'ARCore accelerometer data.',
    FIRST_ENTRY => 0,
    # 00-04: always 10 34 16 3 29
    4  => {
        Name => 'GyroscopeUnknown',
        Format => 'undef[16]',
        Unknown => 1, # always "29 37 45 48" in my sample, just like AccelerometerUnknown
        ValueConv => 'join " ", unpack("Cx4Cx4Cx4C", $val)',
    },
    5  => { # (NC)
        Name => 'Gyroscope',
        Format => 'undef[14]',
        RawConv => 'GetFloat(\$val,0) . " " . GetFloat(\$val,5) . " " . GetFloat(\$val,10)',
    },
);

%Image::ExifTool::Parrot::ARCoreVideo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
);

%Image::ExifTool::Parrot::ARCoreCustom = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
);

%Image::ExifTool::Parrot::Composite = (
    GPSDateTime => {
        Description => 'GPS Date/Time',
        Groups => { 2 => 'Time' },
        SubDoc => 1,
        Require => {
            0 => 'Parrot:GPSLatitude',  # (avoids creating this tag for other videos)
            1 => 'Main:CreateDate',
            2 => 'SampleTime',
        },
        ValueConv => q{
            my $time = $val[1];
            my $diff = $val[2];
            # handle time zone and shift to UTC
            if ($time =~ s/([-+])(\d{1,2}):?(\d{2})$//) {
                my $secs = (($2 * 60) + $3) * 60;
                $secs *= -1 if $1 eq '+';
                $diff += $secs;
            } elsif ($time !~ s/Z$//) {
                # shift from local time
                $diff += GetUnixTime($time, 1) - GetUnixTime($time);
            }
            my $sign = ($diff =~ s/^-// ? '-' : '');
            $time .= '.000';    # add decimal seconds
            ShiftTime($time, "${sign}0:0:$diff");
            return $time . 'Z';
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Parrot');


#------------------------------------------------------------------------------
# Parse Parrot 'mett' timed metadata
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (this metadata design is really stupid -- you need to know the size of the base structures)
sub Process_mett($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dirEnd = length $$dataPt;
    my $pos = $$dirInfo{DirStart} || 0;
    my $metaType = $$et{MetaType} || '';

    $et->VerboseDir('Parrot mett', undef, $dirEnd);

    if ($$tagTbl{$metaType}) {
        $et->HandleTag($tagTbl, $metaType, undef,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Base    => $$dirInfo{Base},
        );
        return 1;
    }
    while ($pos + 4 < $dirEnd) {
        my ($id, $nwords) = unpack("x${pos}a2n", $$dataPt);
        my $size;
        if ($id !~ /^[EP]\d/) {
            # no ID so this should be a 60-byte V1 recording record, otherwise give up
            last unless $dirEnd == 60;
            $id = 'P1'; # generate a fake ID
            # ignore the first 4 of the record so the fields will align with
            # the other V1 records (unfortunately, this means that we won't
            # decode the V1 recording frame timestamp, but oh well)
            $pos += 4;
            $size = $dirEnd - $pos;
        # must override size for P3 and P3 records since it includes the extensions (augh!)
        } elsif ($id eq 'P2') {
            $size = 56;
        } elsif ($id eq 'P3') {
            $size = 72;
        } else {
            $size = $nwords * 4 + 4;
        }
        last if $pos + $size > $dirEnd;
        $et->HandleTag($tagTbl, $id, undef,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Base    => $$dirInfo{Base},
            Start   => $pos,
            Size    => $size,
        );
        $pos += $size;
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Parrot - Read timed metadata from Parrot drone videos

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
timed metadata from the 'mett' frame found in Parrot drone MP4 videos.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://developer.parrot.com/docs/pdraw/metadata.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Parrot Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
