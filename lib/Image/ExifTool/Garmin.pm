#------------------------------------------------------------------------------
# File:         Garmin.pm
#
# Description:  Routines to read Garmin FIT files
#
# Revisions:    2026-04-09 - P. Harvey Created
#
# References:   1) https://developer.garmin.com/fit/overview/
#               2) https://developer.garmin.com/fit/protocol/
#               3) https://github.com/garmin/fit-sdk-tools/blob/main/Profile.xlsx
#------------------------------------------------------------------------------

package Image::ExifTool::Garmin;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::GPS;

$VERSION = '1.00';

# ExifTool and FIT format names and invalid values for each FIT base type
my %baseType = (
    0x00 => [ qw(int8u enum),  0xff ],
    0x01 => [ qw(int8s sint8), 0x7f ],
    0x02 => [ qw(int8u uint8), 0xff ],
    0x83 => [ qw(int16s sing16), 0x7fff ],
    0x84 => [ qw(int16u uint16), 0xffff ],
    0x85 => [ qw(int32s sint32), 0x7fffffff ],
    0x86 => [ qw(int32u unit32), 0xffffffff ],
    0x07 => [ qw(string string), '' ],
    0x88 => [ qw(float float32), 'NaN' ],
    0x89 => [ qw(double float64),'NaN' ],
    0x0a => [ qw(int8u uint8z),   0 ],
    0x8b => [ qw(int16u uint16z), 0 ],
    0x8c => [ qw(int32u uint32z), 0 ],
    0x0d => [ qw(undef byte),    0xff ],
    0x8e => [ qw(int64s sint64),  9223372036854775807 ],
    0x8f => [ qw(int64u uint64), 18446744073709551615 ],
    0x90 => [ qw(int64u uint64z), 0 ],
);

my %latInfo = (
    RawConv => '$val == 0x7fffffff ? undef : $val', # ignore invalid value
    ValueConv => '$val * 180 / 0x80000000',
    PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
);

my %lonInfo = (
    RawConv => '$val == 0x7fffffff ? undef : $val',
    ValueConv => '$val * 180 / 0x80000000',
    PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
);

my %timeInfo = (
    # add seconds between Jan 1, 1970 and epoch of Dec 31, 1989
    ValueConv => 'Image::ExifTool::ConvertUnixTime($val + 631065600, 1)',
    PrintConv => '$self->ConvertDateTime($val)',
    IsTimeStamp => 1,
);

my %altInfo = (
    ValueConv => '$val / 5 - 500',      # convert to metres
    PrintConv => '"$val m"',
);

my %speedInfo = (
    ValueConv => '$val * 3.6 / 1000',   # convert to km/h from mm/s
    PrintConv => '"$val km/h"',
);

%Image::ExifTool::Garmin::FIT = (
    GROUPS => { 0 => 'Garmin', 1 => 'File', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    NOTES => q{
        Information extracted from Garmin FIT (Flexible and Interoperable data
        Transfer) files. By default, only timestamps and GPS-related FIT messages
        are decoded, and the rest are marked as Unknown to be extracted only if the
        Unknown (-u) option is used. And unless the ExtractEmbedded (-ee) option is
        used, only the first FIT message of each type is extracted. When both of
        these options are used, a significant amount of information may be
        extracted, and processing times may be lengthy. The family 1 group names of
        the extracted tags correspond to the FIT message names. The first table
        below lists the FIT messages, and subsequent tables list the extracted tags.
        See L<https://developer.garmin.com/fit/> for the specification.
    },
    ProtocolVersion => { },
    0 => {
        Name => 'FileID',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::FileID' },
        Unknown => 1,
    },
    1 => {
        Name => 'Capabilities',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Capabilities' },
        Unknown => 1,
    },
    2 => {
        Name => 'DeviceSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DeviceSettings' },
        Unknown => 1,
    },
    3 => {
        Name => 'UserProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::UserProfile' },
        Unknown => 1,
    },
    4 => {
        Name => 'HRMProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HRMProfile' },
        Unknown => 1,
    },
    5 => {
        Name => 'SDMProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SDMProfile' },
        Unknown => 1,
    },
    6 => {
        Name => 'BikeProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::BikeProfile' },
        Unknown => 1,
    },
    7 => {
        Name => 'ZonesTarget',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ZonesTarget' },
        Unknown => 1,
    },
    8 => {
        Name => 'HRZone',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HRZone' },
        Unknown => 1,
    },
    9 => {
        Name => 'PowerZone',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::PowerZone' },
        Unknown => 1,
    },
    10 => {
        Name => 'MetZone',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MetZone' },
        Unknown => 1,
    },
    12 => {
        Name => 'Sport',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Sport' },
        Unknown => 1,
    },
    13 => {
        Name => 'TrainingSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TrainingSettings' },
        Unknown => 1,
    },
    15 => {
        Name => 'Goal',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Goal' },
        Unknown => 1,
    },
    18 => {
        Name => 'Session',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Session' },
    },
    19 => {
        Name => 'Lap',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Lap' },
    },
    20 => {
        Name => 'Record',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Record' },
    },
    21 => {
        Name => 'Event',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Event' },
        Unknown => 1,
    },
    23 => {
        Name => 'DeviceInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DeviceInfo' },
        Unknown => 1,
    },
    26 => {
        Name => 'Workout',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Workout' },
        Unknown => 1,
    },
    27 => {
        Name => 'WorkoutStep',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WorkoutStep' },
        Unknown => 1,
    },
    28 => {
        Name => 'Schedule',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Schedule' },
        Unknown => 1,
    },
    30 => {
        Name => 'WeightScale',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WeightScale' },
        Unknown => 1,
    },
    31 => {
        Name => 'Course',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Course' },
        Unknown => 1,
    },
    32 => {
        Name => 'CoursePoint',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::CoursePoint' },
    },
    33 => {
        Name => 'Totals',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Totals' },
        Unknown => 1,
    },
    34 => {
        Name => 'Activity',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Activity' },
        Unknown => 1,
    },
    35 => {
        Name => 'Software',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Software' },
        Unknown => 1,
    },
    37 => {
        Name => 'FileCapabilities',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::FileCapabilities' },
        Unknown => 1,
    },
    38 => {
        Name => 'MesgCapabilities',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MesgCapabilities' },
        Unknown => 1,
    },
    39 => {
        Name => 'FieldCapabilities',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::FieldCapabilities' },
        Unknown => 1,
    },
    49 => {
        Name => 'FileCreator',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::FileCreator' },
        Unknown => 1,
    },
    51 => {
        Name => 'BloodPressure',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::BloodPressure' },
        Unknown => 1,
    },
    53 => {
        Name => 'SpeedZone',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SpeedZone' },
        Unknown => 1,
    },
    55 => {
        Name => 'Monitoring',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Monitoring' },
        Unknown => 1,
    },
    72 => {
        Name => 'TrainingFile',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TrainingFile' },
        Unknown => 1,
    },
    78 => {
        Name => 'HRV',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HRV' },
        Unknown => 1,
    },
    80 => {
        Name => 'AntRx',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AntRx' },
        Unknown => 1,
    },
    81 => {
        Name => 'AntTx',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AntTx' },
        Unknown => 1,
    },
    82 => {
        Name => 'AntChannelID',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AntChannelID' },
        Unknown => 1,
    },
    101 => {
        Name => 'Length',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Length' },
        Unknown => 1,
    },
    103 => {
        Name => 'MonitoringInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MonitoringInfo' },
        Unknown => 1,
    },
    105 => 'Pad',
    106 => {
        Name => 'SlaveDevice',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SlaveDevice' },
        Unknown => 1,
    },
    127 => {
        Name => 'Connectivity',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Connectivity' },
        Unknown => 1,
    },
    128 => {
        Name => 'WeatherConditions',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WeatherConditions' },
        Unknown => 1,
    },
    129 => {
        Name => 'WeatherAlert',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WeatherAlert' },
        Unknown => 1,
    },
    131 => {
        Name => 'CadenceZone',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::CadenceZone' },
        Unknown => 1,
    },
    132 => {
        Name => 'HR',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HR' },
        Unknown => 1,
    },
    142 => {
        Name => 'SegmentLap',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SegmentLap' },
    },
    145 => {
        Name => 'MemoGlob',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MemoGlob' },
        Unknown => 1,
    },
    148 => {
        Name => 'SegmentID',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SegmentID' },
        Unknown => 1,
    },
    149 => {
        Name => 'SegmentLeaderboardEntry',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SegmentLeaderboardEntry' },
        Unknown => 1,
    },
    150 => {
        Name => 'SegmentPoint',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SegmentPoint' },
    },
    151 => {
        Name => 'SegmentFile',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SegmentFile' },
        Unknown => 1,
    },
    158 => {
        Name => 'WorkoutSession',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WorkoutSession' },
        Unknown => 1,
    },
    159 => {
        Name => 'WatchfaceSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WatchfaceSettings' },
        Unknown => 1,
    },
    160 => {
        Name => 'GPS', # gps_metadata
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::GPS' },
    },
    161 => {
        Name => 'CameraEvent',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::CameraEvent' },
        Unknown => 1,
    },
    162 => {
        Name => 'TimeStampCorrelation', # timestamp_correlation
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TimeStampCorrelation' },
        Unknown => 1,
    },
    164 => {
        Name => 'GyroscopeData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::GyroscopeData' },
        Unknown => 1,
    },
    165 => {
        Name => 'AccelerometerData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AccelerometerData' },
        Unknown => 1,
    },
    167 => {
        Name => 'ThreeDSensorCalibration',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ThreeDSensorCalibration' },
        Unknown => 1,
    },
    169 => {
        Name => 'VideoFrame',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::VideoFrame' },
        Unknown => 1,
    },
    174 => {
        Name => 'OBDIIData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::OBDIIData' },
        Unknown => 1,
    },
    177 => {
        Name => 'NMEASentence',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::NMEASentence' },
        Unknown => 1,
    },
    178 => {
        Name => 'AviationAttitude',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AviationAttitude' },
        Unknown => 1,
    },
    184 => {
        Name => 'Video',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Video' },
        Unknown => 1,
    },
    185 => {
        Name => 'VideoTitle',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::VideoTitle' },
        Unknown => 1,
    },
    186 => {
        Name => 'VideoDescription',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::VideoDescription' },
        Unknown => 1,
    },
    187 => {
        Name => 'VideoClip',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::VideoClip' },
        Unknown => 1,
    },
    188 => {
        Name => 'OHRSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::OHRSettings' },
        Unknown => 1,
    },
    200 => {
        Name => 'ExdScreenConfiguration',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ExdScreenConfiguration' },
        Unknown => 1,
    },
    201 => {
        Name => 'ExdDataFieldConfiguration',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ExdDataFieldConfiguration' },
        Unknown => 1,
    },
    202 => {
        Name => 'ExdDataConceptConfiguration',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ExdDataConceptConfiguration' },
        Unknown => 1,
    },
    206 => {
        Name => 'FieldDescription',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::FieldDescription' },
        Unknown => 1,
    },
    207 => {
        Name => 'DeveloperDataID',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DeveloperDataID' },
        Unknown => 1,
    },
    208 => {
        Name => 'MagnetometerData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MagnetometerData' },
        Unknown => 1,
    },
    209 => {
        Name => 'BarometerData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::BarometerData' },
        Unknown => 1,
    },
    210 => {
        Name => 'OneDSensorCalibration',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::OneDSensorCalibration' },
        Unknown => 1,
    },
    211 => {
        Name => 'MonitoringHRData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MonitoringHRData' },
        Unknown => 1,
    },
    216 => {
        Name => 'TimeInZone',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TimeInZone' },
        Unknown => 1,
    },
    225 => {
        Name => 'Set',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Set' },
        Unknown => 1,
    },
    227 => {
        Name => 'StressLevel',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::StressLevel' },
        Unknown => 1,
    },
    229 => {
        Name => 'MaxMetData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MaxMetData' },
        Unknown => 1,
    },
    258 => {
        Name => 'DiveSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DiveSettings' },
        Unknown => 1,
    },
    259 => {
        Name => 'DiveGas',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DiveGas' },
        Unknown => 1,
    },
    262 => {
        Name => 'DiveAlarm',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DiveAlarm' },
        Unknown => 1,
    },
    264 => {
        Name => 'ExerciseTitle',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ExerciseTitle' },
        Unknown => 1,
    },
    268 => {
        Name => 'DiveSummary',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DiveSummary' },
        Unknown => 1,
    },
    269 => {
        Name => 'SPO2Data',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SPO2Data' },
        Unknown => 1,
    },
    275 => {
        Name => 'SleepLevel',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepLevel' },
        Unknown => 1,
    },
    285 => {
        Name => 'Jump',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Jump' },
    },
    289 => {
        Name => 'AADAccelFeatures',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AADAccelFeatures' },
        Unknown => 1,
    },
    290 => {
        Name => 'BeatIntervals',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::BeatIntervals' },
        Unknown => 1,
    },
    297 => {
        Name => 'RespirationRate',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::RespirationRate' },
        Unknown => 1,
    },
    302 => {
        Name => 'HSAAccelerometerData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAAccelerometerData' },
        Unknown => 1,
    },
    304 => {
        Name => 'HSAStepData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAStepData' },
        Unknown => 1,
    },
    305 => {
        Name => 'HSA_SPO2Data',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSA_SPO2Data' },
        Unknown => 1,
    },
    306 => {
        Name => 'HSAStressData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAStressData' },
        Unknown => 1,
    },
    307 => {
        Name => 'HSARespirationData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSARespirationData' },
        Unknown => 1,
    },
    308 => {
        Name => 'HSAHeartRateData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAHeartRateData' },
        Unknown => 1,
    },
    312 => {
        Name => 'Split',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Split' },
    },
    313 => {
        Name => 'SplitSummary',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SplitSummary' },
        Unknown => 1,
    },
    314 => {
        Name => 'HSABodyBatteryData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSABodyBatteryData' },
        Unknown => 1,
    },
    315 => {
        Name => 'HSAEvent',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAEvent' },
        Unknown => 1,
    },
    317 => {
        Name => 'ClimbPro',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ClimbPro' },
    },
    319 => {
        Name => 'TankUpdate',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TankUpdate' },
        Unknown => 1,
    },
    323 => {
        Name => 'TankSummary',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TankSummary' },
        Unknown => 1,
    },
    346 => {
        Name => 'SleepAssessment',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepAssessment' },
        Unknown => 1,
    },
    370 => {
        Name => 'HRVStatusSummary',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HRVStatusSummary' },
        Unknown => 1,
    },
    371 => {
        Name => 'HRVValue',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HRVValue' },
        Unknown => 1,
    },
    372 => {
        Name => 'RawBBI',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::RawBBI' },
        Unknown => 1,
    },
    375 => {
        Name => 'DeviceAuxBatteryInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DeviceAuxBatteryInfo' },
        Unknown => 1,
    },
    376 => {
        Name => 'HSAGyroscopeData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAGyroscopeData' },
        Unknown => 1,
    },
    387 => {
        Name => 'ChronoShotSession',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ChronoShotSession' },
        Unknown => 1,
    },
    388 => {
        Name => 'ChronoShotData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ChronoShotData' },
        Unknown => 1,
    },
    389 => {
        Name => 'HSAConfigurationData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAConfigurationData' },
        Unknown => 1,
    },
    393 => {
        Name => 'DiveApneaAlarm',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DiveApneaAlarm' },
        Unknown => 1,
    },
    398 => {
        Name => 'SkinTempOvernight',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SkinTempOvernight' },
        Unknown => 1,
    },
    409 => {
        Name => 'HSAWristTemperatureData',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HSAWristTemperatureData' },
        Unknown => 1,
    },
    412 => {
        Name => 'NapEvent',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::NapEvent' },
        Unknown => 1,
    },
    470 => {
        Name => 'SleepDisruptionSeverityPeriod',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepDisruptionSeverityPeriod' },
        Unknown => 1,
    },
    471 => {
        Name => 'SleepDisruptionOvernightSeverity',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepDisruptionOvernightSeverity' },
        Unknown => 1,
    },
    # 0xff00 => 'MfgRangeMin',
    # 0xfffe => 'MfgRangeMax',
);

%Image::ExifTool::Garmin::Common = (
    GROUPS => { 0 => 'Garmin', 1 => 'File', 2 => 'Unknown' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    TAG_PREFIX => '',
    NOTES => 'Tags listed here are common to all FIT messages.',
    250 => 'PartIndex',
    253 => { Name => 'TimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    254 => 'MessageIndex',
    # 255 - invalid
);

# developer data tags (filled in at runtime)
%Image::ExifTool::Garmin::Dev = (
    GROUPS => { 0 => 'Garmin', 1 => 'Developer', 2 => 'Unknown' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
);

%Image::ExifTool::Garmin::FileID = (
    GROUPS => { 0 => 'Garmin', 1 => 'FileID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Type',
    1 => 'Manufacturer',
    2 => 'Product',
    3 => 'SerialNumber',
    4 => { Name => 'TimeCreated', %timeInfo, Groups => { 2 => 'Time' } },
    5 => 'Number',
    8 => 'ProductName',
);

%Image::ExifTool::Garmin::FileCreator = (
    GROUPS => { 0 => 'Garmin', 1 => 'FileCreator', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SoftwareVersion',
    1 => 'HardwareVersion',
);

%Image::ExifTool::Garmin::TimeStampCorrelation = (
    GROUPS => { 0 => 'Garmin', 1 => 'TSCorrelation', 2 => 'Time' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FractionalTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    1 => { Name => 'SystemTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'FractionalSystemTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    3 => { Name => 'LocalTimeStamp',    PrintConv => '"$val s"',  Groups => { 2 => 'Time' } },
    4 => { Name => 'TimeStamp_ms',      PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    5 => { Name => 'SystemTimeStamp_ms',PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::Software = (
    GROUPS => { 0 => 'Garmin', 1 => 'Software', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    3 => { Name => 'Version', ValueConv => '$val / 100' },
    5 => 'PartNumber',
);

%Image::ExifTool::Garmin::SlaveDevice = (
    GROUPS => { 0 => 'Garmin', 1 => 'SlaveDevice', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Manufacturer',
    1 => 'Product',
);

%Image::ExifTool::Garmin::Capabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'Capabilities', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Languages',
    1 => 'Sports',
    21 => 'WorkoutsSupported',
    23 => 'ConnectivitySupported',
);

%Image::ExifTool::Garmin::FileCapabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'FileCaps', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Type',
    1 => 'Flags',
    2 => 'Directory',
    3 => 'MaxCount',
    4 => { Name => 'MaxSize', PrintConv => '"$val bytes"' },
);

%Image::ExifTool::Garmin::MesgCapabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'MesgCaps', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'File',
    1 => 'MesgNum',
    2 => 'CountType',
    3 => 'Count',
);

%Image::ExifTool::Garmin::FieldCapabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'FieldCaps', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'File',
    1 => 'MesgNum',
    2 => 'FieldNum',
    3 => 'Count',
);

%Image::ExifTool::Garmin::DeviceSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'DeviceSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ActiveTimeZone',
    1 => 'UtcOffset',
    2 => 'TimeOffset', # [N]
    4 => 'TimeMode',
    5 => 'TimeZoneOffset', # [N] / 4 hr
    12 => 'BacklightMode',
    36 => 'ActivityTrackerEnabled',
    39 => { Name => 'ClockTime', %timeInfo, Groups => { 2 => 'Time' } },
    40 => 'PagesEnabled',
    46 => 'MoveAlertEnabled',
    47 => 'DateMode',
    55 => 'DisplayOrientation',
    56 => 'MountingSide',
    57 => 'DefaultPage',
    58 => { Name => 'AutosyncMinSteps', PrintConv => '"$val steps"' },
    59 => { Name => 'AutosyncMinTime', PrintConv => '"$val minutes"' },
    80 => 'LactateThresholdAutodetectEnabled',
    86 => 'BleAutoUploadEnabled',
    89 => 'AutoSyncFrequency',
    90 => 'AutoActivityDetect',
    94 => 'NumberOfScreens',
    95 => 'SmartNotificationDisplayOrientation',
    134 => 'TapInterface',
    174 => 'TapSensitivity',
);

%Image::ExifTool::Garmin::UserProfile = (
    GROUPS => { 0 => 'Garmin', 1 => 'UserProfile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'FriendlyName',
    1 => 'Gender',
    2 => { Name => 'Age', PrintConv => '"$val years"' },
    3 => { Name => 'Height', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => { Name => 'Weight', ValueConv => '$val / 10', PrintConv => '"$val kg"' },
    5 => 'Language',
    6 => 'ElevSetting',
    7 => 'WeightSetting',
    8 => { Name => 'RestingHeartRate', PrintConv => '"$val bpm"' },
    9 => { Name => 'DefaultMaxRunningHeartRate', PrintConv => '"$val bpm"' },
    10 => { Name => 'DefaultMaxBikingHeartRate', PrintConv => '"$val bpm"' },
    11 => { Name => 'DefaultMaxHeartRate', PrintConv => '"$val bpm"' },
    12 => 'HRSetting',
    13 => 'SpeedSetting',
    14 => 'DistSetting',
    16 => 'PowerSetting',
    17 => 'ActivityClass',
    18 => 'PositionSetting',
    21 => 'TemperatureSetting',
    22 => 'LocalID',
    23 => 'GlobalID', # [6]
    28 => 'WakeTime',
    29 => 'SleepTime',
    30 => 'HeightSetting',
    31 => { Name => 'UserRunningStepLength', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    32 => { Name => 'UserWalkingStepLength', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    47 => 'DepthSetting',
    49 => 'DiveCount',
);

%Image::ExifTool::Garmin::HRMProfile = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRMProfile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Enabled',
    1 => 'HRMAntID',
    2 => 'LogHRV',
    3 => 'HRMAntIDTransType',
);

%Image::ExifTool::Garmin::SDMProfile = (
    GROUPS => { 0 => 'Garmin', 1 => 'SDMProfile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Enabled',
    1 => 'SDMAntID',
    2 => { Name => 'SDMCalFactor', ValueConv => '$val / 10', PrintConv => '"$val %"' },
    3 => { Name => 'Odometer', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => 'SpeedSource',
    5 => 'SDMAntIDTransType',
    7 => 'OdometerRollover',
);

%Image::ExifTool::Garmin::BikeProfile = (
    GROUPS => { 0 => 'Garmin', 1 => 'BikeProfile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Name',
    1 => 'Sport',
    2 => 'SubSport',
    3 => { Name => 'Odometer', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => 'BikeSpdAntID',
    5 => 'BikeCadAntID',
    6 => 'BikeSpdcadAntID',
    7 => 'BikePowerAntID',
    8 => { Name => 'CustomWheelsize', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    9 => { Name => 'AutoWheelsize', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    10 => { Name => 'BikeWeight', ValueConv => '$val / 10', PrintConv => '"$val kg"' },
    11 => { Name => 'PowerCalFactor', ValueConv => '$val / 10', PrintConv => '"$val %"' },
    12 => 'AutoWheelCal',
    13 => 'AutoPowerZero',
    14 => 'ID',
    15 => 'SpdEnabled',
    16 => 'CadEnabled',
    17 => 'SpdcadEnabled',
    18 => 'PowerEnabled',
    19 => { Name => 'CrankLength', ValueConv => '$val / 2 + 110', PrintConv => '"$val mm"' },
    20 => 'Enabled',
    21 => 'BikeSpdAntIDTransType',
    22 => 'BikeCadAntIDTransType',
    23 => 'BikeSpdcadAntIDTransType',
    24 => 'BikePowerAntIDTransType',
    37 => 'OdometerRollover',
    38 => 'FrontGearNum',
    39 => 'FrontGear',
    40 => 'RearGearNum',
    41 => 'RearGear',
    44 => 'ShimanoDi2Enabled',
);

%Image::ExifTool::Garmin::Connectivity = (
    GROUPS => { 0 => 'Garmin', 1 => 'Connectivity', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'BluetoothEnabled',
    1 => 'BluetoothLeEnabled',
    2 => 'AntEnabled',
    3 => 'Name',
    4 => 'LiveTrackingEnabled',
    5 => 'WeatherConditionsEnabled',
    6 => 'WeatherAlertsEnabled',
    7 => 'AutoActivityUploadEnabled',
    8 => 'CourseDownloadEnabled',
    9 => 'WorkoutDownloadEnabled',
    10 => 'GPSEphemerisDownloadEnabled',
    11 => 'IncidentDetectionEnabled',
    12 => 'GrouptrackEnabled',
);

%Image::ExifTool::Garmin::WatchfaceSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'WatchfaceSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Mode',
    1 => 'Layout',
);

%Image::ExifTool::Garmin::OHRSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'OHRSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Enabled',
);

%Image::ExifTool::Garmin::TimeInZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'TimeInZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ReferenceMesg',
    1 => 'ReferenceIndex',
    2 => { Name => 'TimeInHRZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    3 => { Name => 'TimeInSpeedZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    4 => { Name => 'TimeInCadenceZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    5 => { Name => 'TimeInPowerZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    6 => 'HRZoneHighBoundary', # [N] bpm
    7 => 'SpeedZoneHighBoundary', # [N] / 1000 m/s
    8 => 'CadenceZoneHighBondary', # [N] rpm
    9 => 'PowerZoneHighBoundary', # [N] watts
    10 => 'HRCalcType',
    11 => 'MaxHeartRate',
    12 => 'RestingHeartRate',
    13 => 'ThresholdHeartRate',
    14 => 'PwrCalcType',
    15 => 'FunctionalThresholdPower',
);

%Image::ExifTool::Garmin::ZonesTarget = (
    GROUPS => { 0 => 'Garmin', 1 => 'ZonesTarget', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'MaxHeartRate',
    2 => 'ThresholdHeartRate',
    3 => 'FunctionalThresholdPower',
    5 => 'HRCalcType',
    7 => 'PwrCalcType',
);

%Image::ExifTool::Garmin::Sport = (
    GROUPS => { 0 => 'Garmin', 1 => 'Sport', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Sport',
    1 => 'SubSport',
    3 => 'Name',
);

%Image::ExifTool::Garmin::HRZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'HighBpm', PrintConv => '"$val bpm"' },
    2 => 'Name',
);

%Image::ExifTool::Garmin::SpeedZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'SpeedZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'HighValue', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    1 => 'Name',
);

%Image::ExifTool::Garmin::CadenceZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'CadenceZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'HighValue', PrintConv => '"$val rpm"' },
    1 => 'Name',
);

%Image::ExifTool::Garmin::PowerZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'PowerZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'HighValue', PrintConv => '"$val watts"' },
    2 => 'Name',
);

%Image::ExifTool::Garmin::MetZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'MetZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'HighBpm',
    2 => { Name => 'Calories', ValueConv => '$val / 10', PrintConv => '"$val kcal / min"' },
    3 => { Name => 'FatCalories', ValueConv => '$val / 10', PrintConv => '"$val kcal / min"' },
);

%Image::ExifTool::Garmin::TrainingSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'TrainingSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    31 => { Name => 'TargetDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    32 => { Name => 'TargetSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    33 => { Name => 'TargetTime', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    153 => { Name => 'PreciseTargetSpeed', ValueConv => '$val / 1000000', PrintConv => '"$val m/s"' },
);

%Image::ExifTool::Garmin::DiveSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Name',
    1 => 'Model',
    2 => { Name => 'GfLow', PrintConv => '"$val percent"' },
    3 => { Name => 'GfHigh', PrintConv => '"$val percent"' },
    4 => 'WaterType',
    5 => { Name => 'WaterDensity', PrintConv => '"$val kg/m^3"' },
    6 => { Name => 'Po2Warn', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    7 => { Name => 'Po2Critical', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    8 => { Name => 'Po2Deco', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    9 => 'SafetyStopEnabled',
    10 => 'BottomDepth',
    11 => 'BottomTime',
    12 => 'ApneaCountdownEnabled',
    13 => 'ApneaCountdownTime',
    14 => 'BacklightMode',
    15 => 'BacklightBrightness',
    16 => 'BacklightTimeout',
    17 => { Name => 'RepeatDiveInterval', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    18 => { Name => 'SafetyStopTime', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    19 => 'HeartRateSourceType',
    20 => 'HeartRateSource',
    21 => 'TravelGas',
    22 => 'CcrLowSetpointSwitchMode',
    23 => { Name => 'CcrLowSetpoint', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    24 => { Name => 'CcrLowSetpointDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    25 => 'CcrHighSetpointSwitchMode',
    26 => { Name => 'CcrHighSetpoint', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    27 => { Name => 'CcrHighSetpointDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    29 => 'GasConsumptionDisplay',
    30 => 'UpKeyEnabled',
    35 => 'DiveSounds',
    36 => { Name => 'LastStopMultiple', ValueConv => '$val / 10' },
    37 => 'NoFlyTimeMode',
);

%Image::ExifTool::Garmin::DiveAlarm = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveAlarm', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Depth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    1 => { Name => 'Time', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    2 => 'Enabled',
    3 => 'AlarmType',
    4 => 'Sound',
    5 => 'DiveTypes',
    6 => 'ID',
    7 => 'PopupEnabled',
    8 => 'TriggerOnDescent',
    9 => 'TriggerOnAscent',
    10 => 'Repeating',
    11 => { Name => 'Speed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
);

%Image::ExifTool::Garmin::DiveApneaAlarm = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveApneaAlarm', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Depth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    1 => { Name => 'Time', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    2 => 'Enabled',
    3 => 'AlarmType',
    4 => 'Sound',
    5 => 'DiveTypes',
    6 => 'ID',
    7 => 'PopupEnabled',
    8 => 'TriggerOnDescent',
    9 => 'TriggerOnAscent',
    10 => 'Repeating',
    11 => { Name => 'Speed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
);

%Image::ExifTool::Garmin::DiveGas = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveGas', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'HeliumContent', PrintConv => '"$val percent"' },
    1 => { Name => 'OxygenContent', PrintConv => '"$val percent"' },
    2 => 'Status',
    3 => 'Mode',
);

%Image::ExifTool::Garmin::Goal = (
    GROUPS => { 0 => 'Garmin', 1 => 'Goal', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Sport',
    1 => 'SubSport',
    2 => { Name => 'StartDate', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'EndDate', %timeInfo, Groups => { 2 => 'Time' } },
    4 => 'Type',
    5 => 'Value',
    6 => 'Repeat',
    7 => 'TargetValue',
    8 => 'Recurrence',
    9 => 'RecurrenceValue',
    10 => 'Enabled',
    11 => 'Source',
);

%Image::ExifTool::Garmin::Activity = (
    GROUPS => { 0 => 'Garmin', 1 => 'Activity', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    1 => 'NumSessions',
    2 => 'Type',
    3 => 'Event',
    4 => 'EventType',
    5 => 'LocalTimeStamp',
    6 => 'EventGroup',
);

%Image::ExifTool::Garmin::Session = (
    GROUPS => { 0 => 'Garmin', 1 => 'Session', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Event',
    1 => 'EventType',
    2 => { Name => 'GPSDateTime', %timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time' },
    3 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_lat' },
    4 => { Name => 'GPSLongitude', %lonInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_long' },
    5 => 'Sport',
    6 => 'SubSport',
    7 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    8 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    9 => { Name => 'TotalDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    10 => { Name => 'TotalCycles', PrintConv => '"$val cycles"' },
    11 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    13 => { Name => 'TotalFatCalories', PrintConv => '"$val kcal"' },
    14 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    15 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    16 => { Name => 'AvgHeartRate', PrintConv => '"$val bpm"' },
    17 => { Name => 'MaxHeartRate', PrintConv => '"$val bpm"' },
    18 => { Name => 'AvgCadence', PrintConv => '"$val rpm"' },
    19 => { Name => 'MaxCadence', PrintConv => '"$val rpm"' },
    20 => { Name => 'AvgPower', PrintConv => '"$val watts"' },
    21 => { Name => 'MaxPower', PrintConv => '"$val watts"' },
    22 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    23 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    24 => { Name => 'TotalTrainingEffect', ValueConv => '$val / 10' },
    25 => 'FirstLapIndex',
    26 => 'NumLaps',
    27 => 'EventGroup',
    28 => 'Trigger',
    29 => { Name => 'NecLat', %latInfo, Groups => { 2 => 'Location' } },
    30 => { Name => 'NecLong', %lonInfo, Groups => { 2 => 'Location' } },
    31 => { Name => 'SWCLat', %latInfo, Groups => { 2 => 'Location' } },
    32 => { Name => 'SWCLong', %lonInfo, Groups => { 2 => 'Location' } },
    33 => { Name => 'NumLengths', PrintConv => '"$val lengths"' },
    34 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' },
    35 => { Name => 'TrainingStressScore', ValueConv => '$val / 10', PrintConv => '"$val tss"' },
    36 => { Name => 'IntensityFactor', ValueConv => '$val / 1000', PrintConv => '"$val if"' },
    37 => 'LeftRightBalance',
    38 => { Name => 'GPSDestLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_lat' },
    39 => { Name => 'GPSDestLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_long' },
    41 => { Name => 'AvgStrokeCount', ValueConv => '$val / 10', PrintConv => '"$val strokes/lap"' },
    42 => { Name => 'AvgStrokeDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    43 => { Name => 'SwimStroke', PrintConv => '"$val swimStroke"' },
    44 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    45 => { Name => 'ThresholdPower', PrintConv => '"$val watts"' },
    46 => 'PoolLengthUnit',
    47 => { Name => 'NumActiveLengths', PrintConv => '"$val lengths"' },
    48 => { Name => 'TotalWork', PrintConv => '"$val J"' },
    49 => { Name => 'AvgAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    50 => { Name => 'MaxAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    51 => { Name => 'GPSAccuracy', PrintConv => '"$val m"' },
    52 => { Name => 'AvgGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    53 => { Name => 'AvgPosGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    54 => { Name => 'AvgNegGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    55 => { Name => 'MaxPosGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    56 => { Name => 'MaxNegGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    57 => { Name => 'AvgTemperature', PrintConv => '"$val C"' },
    58 => { Name => 'MaxTemperature', PrintConv => '"$val C"' },
    59 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    60 => { Name => 'AvgPosVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    61 => { Name => 'AvgNegVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    62 => { Name => 'MaxPosVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    63 => { Name => 'MaxNegVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    64 => { Name => 'MinHeartRate', PrintConv => '"$val bpm"' },
    65 => { Name => 'TimeInHRZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    66 => { Name => 'TimeInSpeedZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    67 => { Name => 'TimeInCadenceZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    68 => { Name => 'TimeInPowerZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    69 => { Name => 'AvgLapTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    70 => 'BestLapIndex',
    71 => { Name => 'MinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    82 => 'PlayerScore',
    83 => 'OpponentScore',
    84 => 'OpponentName',
    85 => 'StrokeCount', # [N] counts
    86 => 'ZoneCount', # [N] counts
    87 => { Name => 'MaxBallSpeed', ValueConv => '$val / 100', PrintConv => '"$val m/s"' },
    88 => { Name => 'AvgBallSpeed', ValueConv => '$val / 100', PrintConv => '"$val m/s"' },
    89 => { Name => 'AvgVerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    90 => { Name => 'AvgStanceTimePercent', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    91 => { Name => 'AvgStanceTime', ValueConv => '$val / 10', PrintConv => '"$val ms"' },
    92 => { Name => 'AvgFractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    93 => { Name => 'MaxFractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    94 => { Name => 'TotalFractionalCycles', ValueConv => '$val / 128', PrintConv => '"$val cycles"' },
    95 => 'AvgTotalHemoglobinConc', # [N] / 100 g/dL
    96 => 'MinTotalHemoglobinConc', # [N] / 100 g/dL
    97 => 'MaxTotalHemoglobinConc', # [N] / 100 g/dL
    98 => 'AvgSaturatedHemoglobinPercent', # [N] / 10 %
    99 => 'MinSaturatedHemoglobinPercent', # [N] / 10 %
    100 => 'MaxSaturatedHemoglobinPercent', # [N] / 10 %
    101 => { Name => 'AvgLeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    102 => { Name => 'AvgRightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    103 => { Name => 'AvgLeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    104 => { Name => 'AvgRightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    105 => { Name => 'AvgCombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    110 => 'SportProfileName',
    111 => 'SportIndex',
    112 => { Name => 'TimeStanding', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    113 => 'StandCount',
    114 => { Name => 'AvgLeftPco', PrintConv => '"$val mm"' },
    115 => { Name => 'AvgRightPco', PrintConv => '"$val mm"' },
    116 => 'AvgLeftPowerPhase', # [N] / 0.7111111 degrees
    117 => 'AvgLeftPowerPhasePeak', # [N] / 0.7111111 degrees
    118 => 'AvgRightPowerPhase', # [N] / 0.7111111 degrees
    119 => 'AvgRightPowerPhasePeak', # [N] / 0.7111111 degrees
    120 => 'AvgPowerPosition', # [N] watts
    121 => 'MaxPowerPosition', # [N] watts
    122 => 'AvgCadencePosition', # [N] rpm
    123 => 'MaxCadencePosition', # [N] rpm
    124 => { Name => 'EnhancedAvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    125 => { Name => 'EnhancedMaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    126 => { Name => 'EnhancedAvgAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    127 => { Name => 'EnhancedMinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    128 => { Name => 'EnhancedMaxAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    129 => { Name => 'AvgLevMotorPower', PrintConv => '"$val watts"' },
    130 => { Name => 'MaxLevMotorPower', PrintConv => '"$val watts"' },
    131 => { Name => 'LevBatteryConsumption', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    132 => { Name => 'AvgVerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    133 => { Name => 'AvgStanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    134 => { Name => 'AvgStepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    137 => { Name => 'TotalAnaerobicTrainingEffect', ValueConv => '$val / 10' },
    139 => { Name => 'AvgVam', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    140 => { Name => 'AvgDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    141 => { Name => 'MaxDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    142 => { Name => 'SurfaceInterval', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    143 => { Name => 'StartCns', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    144 => { Name => 'EndCns', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    145 => { Name => 'StartN2', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    146 => { Name => 'EndN2', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    147 => 'AvgRespirationRate',
    148 => 'MaxRespirationRate',
    149 => 'MinRespirationRate',
    150 => { Name => 'MinTemperature', PrintConv => '"$val C"' },
    155 => { Name => 'O2Toxicity', PrintConv => '"$val OTUs"' },
    156 => 'DiveNumber',
    168 => { Name => 'TrainingLoadPeak', ValueConv => '$val / 65536' },
    169 => { Name => 'EnhancedAvgRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    170 => { Name => 'EnhancedMaxRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    180 => { Name => 'EnhancedMinRespirationRate', ValueConv => '$val / 100' },
    181 => { Name => 'TotalGrit', PrintConv => '"$val kGrit"' },
    182 => { Name => 'TotalFlow', PrintConv => '"$val Flow"' },
    183 => 'JumpCount',
    186 => { Name => 'AvgGrit', PrintConv => '"$val kGrit"' },
    187 => { Name => 'AvgFlow', PrintConv => '"$val Flow"' },
    192 => 'WorkoutFeel',
    193 => 'WorkoutRpe',
    194 => { Name => 'AvgSPO2', PrintConv => '"$val percent"' },
    195 => { Name => 'AvgStress', PrintConv => '"$val percent"' },
    196 => { Name => 'MetabolicCalories', PrintConv => '"$val kcal"' },
    197 => { Name => 'SdrrHRV', PrintConv => '"$val mS"' },
    198 => { Name => 'RmssdHRV', PrintConv => '"$val mS"' },
    199 => { Name => 'TotalFractionalAscent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    200 => { Name => 'TotalFractionalDescent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    208 => { Name => 'AvgCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    209 => { Name => 'MinCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    210 => { Name => 'MaxCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
);

%Image::ExifTool::Garmin::Lap = (
    GROUPS => { 0 => 'Garmin', 1 => 'Lap', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Event',
    1 => 'EventType',
    2 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time' },
    3 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_lat' },
    4 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_long' },
    5 => { Name => 'GPSDestLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_lat' },
    6 => { Name => 'GPSDestLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_long' },
    7 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    8 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    9 => { Name => 'TotalDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    10 => { Name => 'TotalCycles', PrintConv => '"$val cycles"' },
    11 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    12 => { Name => 'TotalFatCalories', PrintConv => '"$val kcal"' },
    13 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    14 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    15 => { Name => 'AvgHeartRate', PrintConv => '"$val bpm"' },
    16 => { Name => 'MaxHeartRate', PrintConv => '"$val bpm"' },
    17 => { Name => 'AvgCadence', PrintConv => '"$val rpm"' },
    18 => { Name => 'MaxCadence', PrintConv => '"$val rpm"' },
    19 => { Name => 'AvgPower', PrintConv => '"$val watts"' },
    20 => { Name => 'MaxPower', PrintConv => '"$val watts"' },
    21 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    22 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    23 => 'Intensity',
    24 => 'LapTrigger',
    25 => 'Sport',
    26 => 'EventGroup',
    32 => { Name => 'NumLengths', PrintConv => '"$val lengths"' },
    33 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' },
    34 => 'LeftRightBalance',
    35 => 'FirstLengthIndex',
    37 => { Name => 'AvgStrokeDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    38 => 'SwimStroke',
    39 => 'SubSport',
    40 => { Name => 'NumActiveLengths', PrintConv => '"$val lengths"' },
    41 => { Name => 'TotalWork', PrintConv => '"$val J"' },
    42 => { Name => 'AvgAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    43 => { Name => 'MaxAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    44 => { Name => 'GPSAccuracy', PrintConv => '"$val m"' },
    45 => { Name => 'AvgGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    46 => { Name => 'AvgPosGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    47 => { Name => 'AvgNegGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    48 => { Name => 'MaxPosGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    49 => { Name => 'MaxNegGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    50 => { Name => 'AvgTemperature', PrintConv => '"$val C"' },
    51 => { Name => 'MaxTemperature', PrintConv => '"$val C"' },
    52 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    53 => { Name => 'AvgPosVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    54 => { Name => 'AvgNegVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    55 => { Name => 'MaxPosVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    56 => { Name => 'MaxNegVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    57 => { Name => 'TimeInHRZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    58 => { Name => 'TimeInSpeedZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    59 => { Name => 'TimeInCadenceZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    60 => { Name => 'TimeInPowerZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    61 => 'RepetitionNum',
    62 => { Name => 'MinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    63 => { Name => 'MinHeartRate', PrintConv => '"$val bpm"' },
    71 => 'WktStepIndex',
    74 => 'OpponentScore',
    75 => 'StrokeCount', # [N] counts
    76 => 'ZoneCount', # [N] counts
    77 => { Name => 'AvgVerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    78 => { Name => 'AvgStanceTimePercent', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    79 => { Name => 'AvgStanceTime', ValueConv => '$val / 10', PrintConv => '"$val ms"' },
    80 => { Name => 'AvgFractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    81 => { Name => 'MaxFractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    82 => { Name => 'TotalFractionalCycles', ValueConv => '$val / 128', PrintConv => '"$val cycles"' },
    83 => 'PlayerScore',
    84 => 'AvgTotalHemoglobinConc', # [N] / 100 g/dL
    85 => 'MinTotalHemoglobinConc', # [N] / 100 g/dL
    86 => 'MaxTotalHemoglobinConc', # [N] / 100 g/dL
    87 => 'AvgSaturatedHemoglobinPercent', # [N] / 10 %
    88 => 'MinSaturatedHemoglobinPercent', # [N] / 10 %
    89 => 'MaxSaturatedHemoglobinPercent', # [N] / 10 %
    91 => { Name => 'AvgLeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    92 => { Name => 'AvgRightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    93 => { Name => 'AvgLeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    94 => { Name => 'AvgRightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    95 => { Name => 'AvgCombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    98 => { Name => 'TimeStanding', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    99 => 'StandCount',
    100 => { Name => 'AvgLeftPco', PrintConv => '"$val mm"' },
    101 => { Name => 'AvgRightPco', PrintConv => '"$val mm"' },
    102 => 'AvgLeftPowerPhase', # [N] / 0.7111111 degrees
    103 => 'AvgLeftPowerPhasePeak', # [N] / 0.7111111 degrees
    104 => 'AvgRightPowerPhase', # [N] / 0.7111111 degrees
    105 => 'AvgRightPowerPhasePeak', # [N] / 0.7111111 degrees
    106 => 'AvgPowerPosition', # [N] watts
    107 => 'MaxPowerPosition', # [N] watts
    108 => 'AvgCadencePosition', # [N] rpm
    109 => 'MaxCadencePosition', # [N] rpm
    110 => { Name => 'EnhancedAvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    111 => { Name => 'EnhancedMaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    112 => { Name => 'EnhancedAvgAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    113 => { Name => 'EnhancedMinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    114 => { Name => 'EnhancedMaxAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    115 => { Name => 'AvgLevMotorPower', PrintConv => '"$val watts"' },
    116 => { Name => 'MaxLevMotorPower', PrintConv => '"$val watts"' },
    117 => { Name => 'LevBatteryConsumption', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    118 => { Name => 'AvgVerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    119 => { Name => 'AvgStanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    120 => { Name => 'AvgStepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    121 => { Name => 'AvgVam', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    122 => { Name => 'AvgDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    123 => { Name => 'MaxDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    124 => { Name => 'MinTemperature', PrintConv => '"$val C"' },
    136 => { Name => 'EnhancedAvgRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    137 => { Name => 'EnhancedMaxRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    147 => 'AvgRespirationRate',
    148 => 'MaxRespirationRate',
    149 => { Name => 'TotalGrit', PrintConv => '"$val kGrit"' },
    150 => { Name => 'TotalFlow', PrintConv => '"$val Flow"' },
    151 => 'JumpCount',
    153 => { Name => 'AvgGrit', PrintConv => '"$val kGrit"' },
    154 => { Name => 'AvgFlow', PrintConv => '"$val Flow"' },
    156 => { Name => 'TotalFractionalAscent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    157 => { Name => 'TotalFractionalDescent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    158 => { Name => 'AvgCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    159 => { Name => 'MinCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    160 => { Name => 'MaxCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
);

%Image::ExifTool::Garmin::Length = (
    GROUPS => { 0 => 'Garmin', 1 => 'Length', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Event',
    1 => 'EventType',
    2 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    4 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    5 => { Name => 'TotalStrokes', PrintConv => '"$val strokes"' },
    6 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    7 => { Name => 'SwimStroke', PrintConv => '"$val swimStroke"' },
    9 => { Name => 'AvgSwimmingCadence', PrintConv => '"$val strokes/min"' },
    10 => 'EventGroup',
    11 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    12 => 'LengthType',
    18 => 'PlayerScore',
    19 => 'OpponentScore',
    20 => 'StrokeCount', # [N] counts
    21 => 'ZoneCount', # [N] counts
    22 => { Name => 'EnhancedAvgRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    23 => { Name => 'EnhancedMaxRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    24 => 'AvgRespirationRate',
    25 => 'MaxRespirationRate',
);

%Image::ExifTool::Garmin::Record = (
    GROUPS => { 0 => 'Garmin', 1 => 'Record', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    1 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    2 => { Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'altitude' },
    3 => { Name => 'HeartRate', PrintConv => '"$val bpm"' },
    4 => { Name => 'Cadence', PrintConv => '"$val rpm"' },
    5 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    6 => { Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'speed' },
    7 => { Name => 'Power', PrintConv => '"$val watts"' },
    8 => 'CompressedSpeedDistance', # [3] speed,distance / 100,16 m/s,m
    9 => { Name => 'Grade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    10 => 'Resistance',
    11 => { Name => 'TimeFromCourse', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    12 => { Name => 'CycleLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    13 => { Name => 'Temperature', PrintConv => '"$val C"' },
    17 => 'Speed_1s', # [N] / 16 m/s
    18 => 'Cycles',
    19 => { Name => 'TotalCycles', PrintConv => '"$val cycles"' },
    28 => { Name => 'CompressedAccumulatedPower', PrintConv => '"$val watts' },
    29 => { Name => 'AccumulatedPower', PrintConv => '"$val watts"' },
    30 => 'LeftRightBalance',
    31 => { Name => 'GPSAccuracy', PrintConv => '"$val m"' },
    32 => { Name => 'VerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    33 => { Name => 'Calories', PrintConv => '"$val kcal"' },
    39 => { Name => 'VerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    40 => { Name => 'StanceTimePercent', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    41 => { Name => 'StanceTime', ValueConv => '$val / 10', PrintConv => '"$val ms"' },
    42 => 'ActivityType',
    43 => { Name => 'LeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    44 => { Name => 'RightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    45 => { Name => 'LeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    46 => { Name => 'RightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    47 => { Name => 'CombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    48 => { Name => 'Time128', ValueConv => '$val / 128', PrintConv => '"$val s"' },
    49 => 'StrokeType',
    50 => 'Zone',
    51 => { Name => 'BallSpeed', ValueConv => '$val / 100', PrintConv => '"$val m/s"' },
    52 => { Name => 'Cadence256', ValueConv => '$val / 256', PrintConv => '"$val rpm"' },
    53 => { Name => 'FractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    54 => { Name => 'TotalHemoglobinConc', ValueConv => '$val / 100', PrintConv => '"$val g/dL"' },
    55 => { Name => 'TotalHemoglobinConcMin', ValueConv => '$val / 100', PrintConv => '"$val g/dL"' },
    56 => { Name => 'TotalHemoglobinConcMax', ValueConv => '$val / 100', PrintConv => '"$val g/dL"' },
    57 => { Name => 'SaturatedHemoglobinPercent', ValueConv => '$val / 10', PrintConv => '"$val %"' },
    58 => { Name => 'SaturatedHemoglobinPercentMin', ValueConv => '$val / 10', PrintConv => '"$val %"' },
    59 => { Name => 'SaturatedHemoglobinPercentMax', ValueConv => '$val / 10', PrintConv => '"$val %"' },
    62 => 'DeviceIndex',
    67 => { Name => 'LeftPco', PrintConv => '"$val mm"' },
    68 => { Name => 'RightPco', PrintConv => '"$val mm"' },
    69 => 'LeftPowerPhase', # [N] / 0.7111111 degrees
    70 => 'LeftPowerPhasePeak', # [N] / 0.7111111 degrees
    71 => 'RightPowerPhase', # [N] / 0.7111111 degrees
    72 => 'RightPowerPhasePeak', # [N] / 0.7111111 degrees
    73 =>{ Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_speed' },
    78 =>{ Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_altitude' },
    81 => { Name => 'BatterySoc', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    82 => { Name => 'MotorPower', PrintConv => '"$val watts"' },
    83 => { Name => 'VerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    84 => { Name => 'StanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    85 => { Name => 'StepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    87 => { Name => 'CycleLength16', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    91 => { Name => 'AbsolutePressure', PrintConv => '"$val Pa"' },
    92 => { Name => 'Depth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    93 => { Name => 'NextStopDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    94 => { Name => 'NextStopTime', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    95 => { Name => 'TimeToSurface', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    96 => { Name => 'NdlTime', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    97 => { Name => 'CnsLoad', PrintConv => '"$val percent"' },
    98 => { Name => 'N2Load', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    99 => { Name => 'RespirationRate', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    108 => { Name => 'EnhancedRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    114 => 'Grit',
    115 => 'Flow',
    116 => { Name => 'CurrentStress', ValueConv => '$val / 100' },
    117 => { Name => 'EbikeTravelRange', PrintConv => '"$val km"' },
    118 => { Name => 'EbikeBatteryLevel', PrintConv => '"$val percent"' },
    119 => 'EbikeAssistMode',
    120 => { Name => 'EbikeAssistLevelPercent', PrintConv => '"$val percent"' },
    123 => { Name => 'AirTimeRemaining', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    124 => { Name => 'PressureSac', ValueConv => '$val / 100', PrintConv => '"$val bar/min"' },
    125 => { Name => 'VolumeSac', ValueConv => '$val / 100', PrintConv => '"$val L/min"' },
    126 => { Name => 'Rmv', ValueConv => '$val / 100', PrintConv => '"$val L/min"' },
    127 => { Name => 'AscentRate', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    129 => { Name => 'Po2', ValueConv => '$val / 100', PrintConv => '"$val percent"' },
    139 => { Name => 'CoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
);

%Image::ExifTool::Garmin::Event = (
    GROUPS => { 0 => 'Garmin', 1 => 'Event', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Event',
    1 => 'EventType',
    2 => 'Data16',
    3 => 'Data',
    4 => 'EventGroup',
    7 => 'Score',
    8 => 'OpponentScore',
    9 => 'FrontGearNum',
    10 => 'FrontGear',
    11 => 'RearGearNum',
    12 => 'RearGear',
    13 => 'DeviceIndex',
    14 => 'ActivityType',
    15 => { Name => 'StartTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    21 => 'RadarThreatLevelMax',
    22 => 'RadarThreatCount',
    23 => { Name => 'RadarThreatAvgApproachSpeed', ValueConv => '$val / 10', PrintConv => '"$val m/s"' },
    24 => { Name => 'RadarThreatMaxApproachSpeed', ValueConv => '$val / 10', PrintConv => '"$val m/s"' },
);

%Image::ExifTool::Garmin::DeviceInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'DeviceInfo', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'DeviceIndex',
    1 => 'DeviceType',
    2 => 'Manufacturer',
    3 => 'SerialNumber',
    4 => 'Product',
    5 => { Name => 'SoftwareVersion', ValueConv => '$val / 100' },
    6 => 'HardwareVersion',
    7 => { Name => 'CumOperatingTime', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    10 => { Name => 'BatteryVoltage', ValueConv => '$val / 256', PrintConv => '"$val V"' },
    11 => 'BatteryStatus',
    18 => 'SensorPosition',
    19 => 'Descriptor',
    20 => 'AntTransmissionType',
    21 => 'AntDeviceNumber',
    22 => 'AntNetwork',
    25 => 'SourceType',
    27 => 'ProductName',
    32 => { Name => 'BatteryLevel', PrintConv => '"$val %"' },
);

%Image::ExifTool::Garmin::DeviceAuxBatteryInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'AuxBattery', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'DeviceIndex',
    1 => { Name => 'BatteryVoltage', ValueConv => '$val / 256', PrintConv => '"$val V"' },
    2 => 'BatteryStatus',
    3 => 'BatteryIdentifier',
);

%Image::ExifTool::Garmin::TrainingFile = (
    GROUPS => { 0 => 'Garmin', 1 => 'TrainingFile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Type',
    1 => 'Manufacturer',
    2 => 'Product',
    3 => 'SerialNumber',
    4 => { Name => 'TimeCreated', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::WeatherConditions = (
    GROUPS => { 0 => 'Garmin', 1 => 'WeatherConditions', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'WeatherReport',
    1 => { Name => 'Temperature', PrintConv => '"$val C"' },
    2 => 'Condition',
    3 => { Name => 'WindDirection', PrintConv => '"$val degrees"' },
    4 => { Name => 'WindSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    5 => 'PrecipitationProbability',
    6 => { Name => 'TemperatureFeelsLike', PrintConv => '"$val C"' },
    7 => 'RelativeHumidity',
    8 => 'Location',
    9 => { Name => 'ObservedAtTime', %timeInfo, Groups => { 2 => 'Time' } },
    10 => { Name => 'ObservedLocationLat', %latInfo, Groups => { 2 => 'Location' } },
    11 => { Name => 'ObservedLocationLong', %lonInfo, Groups => { 2 => 'Location' } },
    12 => 'DayOfWeek',
    13 => { Name => 'HighTemperature', PrintConv => '"$val C"' },
    14 => { Name => 'LowTemperature', PrintConv => '"$val C"' },
);

%Image::ExifTool::Garmin::WeatherAlert = (
    GROUPS => { 0 => 'Garmin', 1 => 'WeatherAlert', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ReportID',
    1 => { Name => 'IssueTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'ExpireTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => 'Severity',
    4 => 'Type',
);

%Image::ExifTool::Garmin::GPS = (
    GROUPS => { 0 => 'Garmin', 1 => 'GPS', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'GPSLatitude', %latInfo, Notes => 'position_lat' },
    2 => { Name => 'GPSLongitude',%lonInfo, Notes => 'position_long' },
    3 => { Name => 'GPSAltitude', %altInfo, Notes => 'enhanced_altitude' },
    4 => { Name => 'GPSSpeed',  %speedInfo, Notes => 'enhanced_speed' },
    5 => { Name => 'GPSTrack', ValueConv => '$val / 100', Notes => 'heading' }, # (deg)
    6 => { Name => 'GPSDateTime', %timeInfo, Groups => { 2 => 'Time' }, Notes => 'utc_timestamp' },
    7 => {
        Name => 'Velocity',
        Notes => 'm/s in longitude, latitude and altitude directions',
        ValueConv => 'my @a = join " ", map { $_ / 100} split " "',
    },
);

%Image::ExifTool::Garmin::CameraEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'CameraEvent', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => 'CameraEventType',
    2 => 'CameraFileUUID',
    3 => 'CameraOrientation',
);

%Image::ExifTool::Garmin::GyroscopeData = (
    GROUPS => { 0 => 'Garmin', 1 => 'GyroData', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SampleTimeOffset', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'GyroX', # [N] counts
    3 => 'GyroY', # [N] counts
    4 => 'GyroZ', # [N] counts
    5 => 'CalibratedGyroX', # [N] deg/s
    6 => 'CalibratedGyroY', # [N] deg/s
    7 => 'CalibratedGyroZ', # [N] deg/s
);

%Image::ExifTool::Garmin::AccelerometerData = (
    GROUPS => { 0 => 'Garmin', 1 => 'AccelData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SampleTimeOffset', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'AccelX', # [N] counts
    3 => 'AccelY', # [N] counts
    4 => 'AccelZ', # [N] counts
    5 => 'CalibratedAccelX', # [N] g
    6 => 'CalibratedAccelY', # [N] g
    7 => 'CalibratedAccelZ', # [N] g
    8 => 'CompressedCalibratedAccelX', # [N] mG
    9 => 'CompressedCalibratedAccelY', # [N] mG
    10 => 'CompressedCalibratedAccelZ', # [N] mG
);

%Image::ExifTool::Garmin::MagnetometerData = (
    GROUPS => { 0 => 'Garmin', 1 => 'MagData', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SampleTimeOffset', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'MagX', # [N] counts
    3 => 'MagY', # [N] counts
    4 => 'MagZ', # [N] counts
    5 => 'CalibratedMagX', # [N] G
    6 => 'CalibratedMagY', # [N] G
    7 => 'CalibratedMagZ', # [N] G
);

%Image::ExifTool::Garmin::BarometerData = (
    GROUPS => { 0 => 'Garmin', 1 => 'Barometer', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SampleTimeOffset', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'BaroPres', # [N] Pa
);

%Image::ExifTool::Garmin::ThreeDSensorCalibration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ThreeDSensorCal', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SensorType',
    1 => 'CalibrationFactor',
    2 => { Name => 'CalibrationDivisor', PrintConv => '"$val counts"' },
    3 => 'LevelShift',
    4 => 'OffsetCal', # [3]
    5 => 'OrientationMatrix', # [9] / 65535
);

%Image::ExifTool::Garmin::OneDSensorCalibration = (
    GROUPS => { 0 => 'Garmin', 1 => 'OneDSensorCal', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SensorType',
    1 => 'CalibrationFactor',
    2 => { Name => 'CalibrationDivisor', PrintConv => '"$val counts"' },
    3 => 'LevelShift',
    4 => 'OffsetCal',
);

%Image::ExifTool::Garmin::VideoFrame = (
    GROUPS => { 0 => 'Garmin', 1 => 'VideoFrame', 2 => 'Video' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => 'FrameNumber',
);

%Image::ExifTool::Garmin::OBDIIData = (
    GROUPS => { 0 => 'Garmin', 1 => 'OBDIIData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'TimeOffset', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'Pid',
    3 => 'RawData',
    4 => 'PidDataSize',
    5 => 'SystemTime',
    6 => { Name => 'StartTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    7 => { Name => 'StartTimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::NMEASentence = (
    GROUPS => { 0 => 'Garmin', 1 => 'NMEA', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => 'Sentence', # eventually could decode this, but a sample would be helpful
);

%Image::ExifTool::Garmin::AviationAttitude = (
    GROUPS => { 0 => 'Garmin', 1 => 'AviationAttitude', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SystemTime', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'Pitch',       # [N] / 10430.38 radians
    3 => 'Roll',        # [N] / 10430.38 radians
    4 => 'AccelLateral',# [N] / 100 m/s^2
    5 => 'AccelNormal', # [N] / 100 m/s^2
    6 => 'TurnRate',    # [N] / 1024 radians/second
    7 => 'Stage',
    8 => 'AttitudeStageComplete', # [N] %
    9 => 'Track',       # [N] / 10430.38 radians
    10 => 'Validity',
);

%Image::ExifTool::Garmin::Video = (
    GROUPS => { 0 => 'Garmin', 1 => 'Video', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'URL',
    1 => 'HostingProvider',
    2 => { Name => 'Duration', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::VideoTitle = (
    GROUPS => { 0 => 'Garmin', 1 => 'VideoTitle', 2 => 'Video' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'MessageCount',
    1 => 'Text',
);

%Image::ExifTool::Garmin::VideoDescription = (
    GROUPS => { 0 => 'Garmin', 1 => 'VideoDescr', 2 => 'Video' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'MessageCount',
    1 => 'Text',
);

%Image::ExifTool::Garmin::VideoClip = (
    GROUPS => { 0 => 'Garmin', 1 => 'VideoClip', 2 => 'Video' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ClipNumber',
    1 => { Name => 'StartTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    2 => 'StartTimeStamp_ms',
    3 => { Name => 'EndTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    4 => 'EndTimeStamp_ms',
    6 => { Name => 'ClipStart', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    7 => { Name => 'ClipEnd', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::Set = (
    GROUPS => { 0 => 'Garmin', 1 => 'Set', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Duration', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    3 => 'Repetitions',
    4 => { Name => 'Weight', ValueConv => '$val / 16', PrintConv => '"$val kg"' },
    5 => 'SetType',
    6 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    7 => 'Category',
    8 => 'CategorySubtype',
    9 => 'WeightDisplayUnit',
    10 => 'MessageIndex',
    11 => 'WktStepIndex',
);

%Image::ExifTool::Garmin::Jump = (
    GROUPS => { 0 => 'Garmin', 1 => 'Jump', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Distance', PrintConv => '"$val m"' },
    1 => { Name => 'Height', PrintConv => '"$val m"' },
    2 => 'Rotations',
    3 => { Name => 'HangTime', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    4 => 'Score',
    5 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    6 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    7 => { Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'speed' },
    8 => { Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_speed' },
);

%Image::ExifTool::Garmin::Split = (
    GROUPS => { 0 => 'Garmin', 1 => 'Split', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SplitType',
    1 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    2 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    3 => { Name => 'TotalDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    9 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time' },
    13 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    14 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    21 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_lat' },
    22 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_long' },
    23 => { Name => 'GPSDestLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_lat' },
    24 => { Name => 'GPSDestLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_long' },
    25 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    26 => { Name => 'AvgVertSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    27 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
    28 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    74 => { Name => 'StartElevation', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    110 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::SplitSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'SplitSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SplitType',
    3 => 'NumSplits',
    4 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    5 => { Name => 'TotalDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    6 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    7 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    8 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    9 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    10 => { Name => 'AvgHeartRate', PrintConv => '"$val bpm"' },
    11 => { Name => 'MaxHeartRate', PrintConv => '"$val bpm"' },
    12 => { Name => 'AvgVertSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    13 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    77 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::ClimbPro = (
    GROUPS => { 0 => 'Garmin', 1 => 'ClimbPro', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    1 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    2 => 'ClimbProEvent',
    3 => 'ClimbNumber',
    4 => 'ClimbCategory',
    5 => { Name => 'CurrentDist', PrintConv => '"$val m"' },
);

%Image::ExifTool::Garmin::FieldDescription = (
    GROUPS => { 0 => 'Garmin', 1 => 'FieldDescr', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    NOTES => 'Tags used to define custom developer fields.',
    0 => 'DeveloperDataIndex',
    1 => 'FieldDefinitionNumber',
    2 => 'FitBaseTypeID',
    3 => 'FieldName',
    4 => 'Array',
    5 => 'Components',
    6 => 'Scale',
    7 => 'Offset',
    8 => 'Units',
    9 => 'Bits',
    10 => 'Accumulate',
    13 => 'FitBaseUnitID',
    14 => 'NativeMesgNum',
    15 => 'NativeFieldNum',
);

%Image::ExifTool::Garmin::DeveloperDataID = (
    GROUPS => { 0 => 'Garmin', 1 => 'DevDataID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    NOTES => 'Developer identification tags.',
    0 => 'DeveloperID',
    1 => 'ApplicationID',
    2 => 'ManufacturerID',
    3 => 'DeveloperDataIndex',
    4 => 'ApplicationVersion',
);

%Image::ExifTool::Garmin::Course = (
    GROUPS => { 0 => 'Garmin', 1 => 'Course', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    4 => 'Sport',
    5 => 'Name',
    6 => 'Capabilities',
    7 => 'SubSport',
);

%Image::ExifTool::Garmin::CoursePoint = (
    GROUPS => { 0 => 'Garmin', 1 => 'CoursePoint', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'timestamp' },
    2 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    3 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    4 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    5 => 'Type',
    6 => 'Name',
    8 => 'Favorite',
);

%Image::ExifTool::Garmin::SegmentID = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegmentID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Name',
    1 => 'UUID',
    2 => 'Sport',
    3 => 'Enabled',
    4 => 'UserProfilePrimaryKey',
    5 => 'DeviceID',
    6 => 'DefaultRaceLeader',
    7 => 'DeleteStatus',
    8 => 'SelectionType',
);

%Image::ExifTool::Garmin::SegmentLeaderboardEntry = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegLeaderboard', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Name',
    1 => 'Type',
    2 => 'GroupPrimaryKey',
    3 => 'ActivityID',
    4 => { Name => 'SegmentTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    5 => 'ActivityIDString',
);

%Image::ExifTool::Garmin::SegmentPoint = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegPoint', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    2 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    3 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => { Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'altitude' },
    5 => { Name => 'LeaderTime', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    6 => { Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_altitude' },
);

%Image::ExifTool::Garmin::SegmentLap = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegLap', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Event',
    1 => 'EventType',
    2 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time' },
    3 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_lat' },
    4 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_long' },
    5 => { Name => 'GPSDestLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_lat' },
    6 => { Name => 'GPSDestLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_long' },
    7 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    8 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    9 => { Name => 'TotalDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    10 => { Name => 'TotalCycles', PrintConv => '"$val cycles"' },
    11 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    12 => { Name => 'TotalFatCalories', PrintConv => '"$val kcal"' },
    13 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    14 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    15 => { Name => 'AvgHeartRate', PrintConv => '"$val bpm"' },
    16 => { Name => 'MaxHeartRate', PrintConv => '"$val bpm"' },
    17 => { Name => 'AvgCadence', PrintConv => '"$val rpm"' },
    18 => { Name => 'MaxCadence', PrintConv => '"$val rpm"' },
    19 => { Name => 'AvgPower', PrintConv => '"$val watts"' },
    20 => { Name => 'MaxPower', PrintConv => '"$val watts"' },
    21 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    22 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    23 => 'Sport',
    24 => 'EventGroup',
    25 => { Name => 'NecLat', %latInfo, Groups => { 2 => 'Location' } },
    26 => { Name => 'NecLong', %lonInfo, Groups => { 2 => 'Location' } },
    27 => { Name => 'SWCLat', %latInfo, Groups => { 2 => 'Location' } },
    28 => { Name => 'SWCLong', %lonInfo, Groups => { 2 => 'Location' } },
    29 => 'Name',
    30 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' },
    31 => 'LeftRightBalance',
    32 => 'SubSport',
    33 => { Name => 'TotalWork', PrintConv => '"$val J"' },
    34 => { Name => 'AvgAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    35 => { Name => 'MaxAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    36 => { Name => 'GPSAccuracy', PrintConv => '"$val m"' },
    37 => { Name => 'AvgGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    38 => { Name => 'AvgPosGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    39 => { Name => 'AvgNegGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    40 => { Name => 'MaxPosGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    41 => { Name => 'MaxNegGrade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    42 => { Name => 'AvgTemperature', PrintConv => '"$val C"' },
    43 => { Name => 'MaxTemperature', PrintConv => '"$val C"' },
    44 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    45 => { Name => 'AvgPosVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    46 => { Name => 'AvgNegVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    47 => { Name => 'MaxPosVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    48 => { Name => 'MaxNegVerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    49 => { Name => 'TimeInHRZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    50 => { Name => 'TimeInSpeedZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    51 => { Name => 'TimeInCadenceZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    52 => { Name => 'TimeInPowerZone', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    53 => 'RepetitionNum',
    54 => { Name => 'MinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    55 => { Name => 'MinHeartRate', PrintConv => '"$val bpm"' },
    56 => { Name => 'ActiveTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    57 => 'WktStepIndex',
    58 => 'SportEvent',
    59 => { Name => 'AvgLeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    60 => { Name => 'AvgRightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    61 => { Name => 'AvgLeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    62 => { Name => 'AvgRightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    63 => { Name => 'AvgCombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val percent"' },
    64 => 'Status',
    65 => 'UUID',
    66 => { Name => 'AvgFractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    67 => { Name => 'MaxFractionalCadence', ValueConv => '$val / 128', PrintConv => '"$val rpm"' },
    68 => { Name => 'TotalFractionalCycles', ValueConv => '$val / 128', PrintConv => '"$val cycles"' },
    69 => 'FrontGearShiftCount',
    70 => 'RearGearShiftCount',
    71 => { Name => 'TimeStanding', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    72 => 'StandCount',
    73 => { Name => 'AvgLeftPco', PrintConv => '"$val mm"' },
    74 => { Name => 'AvgRightPco', PrintConv => '"$val mm"' },
    75 => 'AvgLeftPowerPhase', # [N] / 0.7111111 degrees
    76 => 'AvgLeftPowerPhasePeak', # [N] / 0.7111111 degrees
    77 => 'AvgRightPowerPhase', # [N] / 0.7111111 degrees
    78 => 'AvgRightPowerPhasePeak', # [N] / 0.7111111 degrees
    79 => 'AvgPowerPosition', # [N] watts
    80 => 'MaxPowerPosition', # [N] watts
    81 => 'AvgCadencePosition', # [N] rpm
    82 => 'MaxCadencePosition', # [N] rpm
    83 => 'Manufacturer',
    84 => { Name => 'TotalGrit', PrintConv => '"$val kGrit"' },
    85 => { Name => 'TotalFlow', PrintConv => '"$val Flow"' },
    86 => { Name => 'AvgGrit', PrintConv => '"$val kGrit"' },
    87 => { Name => 'AvgFlow', PrintConv => '"$val Flow"' },
    89 => { Name => 'TotalFractionalAscent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    90 => { Name => 'TotalFractionalDescent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    91 => { Name => 'EnhancedAvgAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    92 => { Name => 'EnhancedMaxAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    93 => { Name => 'EnhancedMinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
);

%Image::ExifTool::Garmin::SegmentFile = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegFile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'FileUUID',
    3 => 'Enabled',
    4 => 'UserProfilePrimaryKey',
    7 => 'LeaderType',
    8 => 'LeaderGroupPrimaryKey',
    9 => 'LeaderActivityID',
    10 => 'LeaderActivityIDString',
    11 => 'DefaultRaceLeader',
);

%Image::ExifTool::Garmin::Workout = (
    GROUPS => { 0 => 'Garmin', 1 => 'Workout', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    4 => 'Sport',
    5 => 'Capabilities',
    6 => 'NumValidSteps',
    8 => 'WktName',
    11 => 'SubSport',
    14 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    15 => 'PoolLengthUnit',
    17 => 'WktDescription',
);

%Image::ExifTool::Garmin::WorkoutSession = (
    GROUPS => { 0 => 'Garmin', 1 => 'WorkoutSess', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Sport',
    1 => 'SubSport',
    2 => 'NumValidSteps',
    3 => 'FirstStepIndex',
    4 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    5 => 'PoolLengthUnit',
);

%Image::ExifTool::Garmin::WorkoutStep = (
    GROUPS => { 0 => 'Garmin', 1 => 'WorkoutStep', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'WktStepName',
    1 => 'DurationType',
    2 => 'DurationValue',
    3 => 'TargetType',
    4 => 'TargetValue',
    5 => 'CustomTargetValueLow',
    6 => 'CustomTargetValueHigh',
    7 => 'Intensity',
    8 => 'Notes',
    9 => 'Equipment',
    10 => 'ExerciseCategory',
    11 => 'ExerciseName',
    12 => { Name => 'ExerciseWeight', ValueConv => '$val / 100', PrintConv => '"$val kg"' },
    13 => 'WeightDisplayUnit',
    19 => 'SecondaryTargetType',
    20 => 'SecondaryTargetValue',
    21 => 'SecondaryCustomTargetValueLow',
    22 => 'SecondaryCustomTargetValueHigh',
);

%Image::ExifTool::Garmin::ExerciseTitle = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExerciseTitle', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ExerciseCategory',
    1 => 'ExerciseName',
    2 => 'WktStepName',
);

%Image::ExifTool::Garmin::Schedule = (
    GROUPS => { 0 => 'Garmin', 1 => 'Schedule', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Manufacturer',
    1 => 'Product',
    2 => 'SerialNumber',
    3 => { Name => 'TimeCreated', %timeInfo, Groups => { 2 => 'Time' } },
    4 => 'Completed',
    5 => 'Type',
    6 => 'ScheduledTime',
);

%Image::ExifTool::Garmin::Totals = (
    GROUPS => { 0 => 'Garmin', 1 => 'Totals', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimerTime', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => { Name => 'Distance', PrintConv => '"$val m"' },
    2 => { Name => 'Calories', PrintConv => '"$val kcal"' },
    3 => 'Sport',
    4 => { Name => 'ElapsedTime', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    5 => 'Sessions',
    6 => { Name => 'ActiveTime', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    9 => 'SportIndex',
);

%Image::ExifTool::Garmin::WeightScale = (
    GROUPS => { 0 => 'Garmin', 1 => 'WeightScale', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Weight', ValueConv => '$val / 100', PrintConv => '"$val kg"' },
    1 => { Name => 'PercentFat', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    2 => { Name => 'PercentHydration', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    3 => { Name => 'VisceralFatMass', ValueConv => '$val / 100', PrintConv => '"$val kg"' },
    4 => { Name => 'BoneMass', ValueConv => '$val / 100', PrintConv => '"$val kg"' },
    5 => { Name => 'MuscleMass', ValueConv => '$val / 100', PrintConv => '"$val kg"' },
    7 => { Name => 'BasalMet', ValueConv => '$val / 4', PrintConv => '"$val kcal/day"' },
    8 => 'PhysiqueRating',
    9 => { Name => 'ActiveMet', ValueConv => '$val / 4', PrintConv => '"$val kcal/day"' },
    10 => { Name => 'MetabolicAge', PrintConv => '"$val years"' },
    11 => 'VisceralFatRating',
    12 => 'UserProfileIndex',
    13 => { Name => 'Bmi', ValueConv => '$val / 10', PrintConv => '"$val kg/m^2"' },
);

%Image::ExifTool::Garmin::BloodPressure = (
    GROUPS => { 0 => 'Garmin', 1 => 'BloodPress', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'SystolicPressure', PrintConv => '"$val mmHg"' },
    1 => { Name => 'DiastolicPressure', PrintConv => '"$val mmHg"' },
    2 => { Name => 'MeanArterialPressure', PrintConv => '"$val mmHg"' },
    3 => { Name => 'Map_3SampleMean', PrintConv => '"$val mmHg"' },
    4 => { Name => 'MapMorningValues', PrintConv => '"$val mmHg"' },
    5 => { Name => 'MapEveningValues', PrintConv => '"$val mmHg"' },
    6 => { Name => 'HeartRate', PrintConv => '"$val bpm"' },
    7 => 'HeartRateType',
    8 => 'Status',
    9 => 'UserProfileIndex',
);

%Image::ExifTool::Garmin::MonitoringInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'MonitorInfo', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'LocalTimeStamp', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'ActivityType',
    3 => 'CyclesToDistance', # [N] / 5000 m/cycle
    4 => 'CyclesToCalories', # [N] / 5000 kcal/cycle
    5 => { Name => 'RestingMetabolicRate', PrintConv => '"$val kcal / day' },
);

%Image::ExifTool::Garmin::Monitoring = (
    GROUPS => { 0 => 'Garmin', 1 => 'Monitoring', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'DeviceIndex',
    1 => { Name => 'Calories', PrintConv => '"$val kcal"' },
    2 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    3 => { Name => 'Cycles', ValueConv => '$val / 2', PrintConv => '"$val cycles"' },
    4 => { Name => 'ActiveTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    5 => 'ActivityType',
    6 => 'ActivitySubtype',
    7 => 'ActivityLevel',
    8 => { Name => 'Distance_16', ValueConv => '$val / 100', PrintConv => '"$val m"' }, # or * 100?
    9 => { Name => 'Cycles_16', ValueConv => '$val / 2', PrintConv => '"$val cycles (steps)"' }, # or * 2?
    10 => { Name => 'ActiveTime_16', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    11 => 'LocalTimeStamp',
    12 => { Name => 'Temperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    14 => { Name => 'TemperatureMin', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    15 => { Name => 'TemperatureMax', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    16 => 'ActivityTime', # [8] minutes
    19 => { Name => 'ActiveCalories', PrintConv => '"$val kcal"' },
    24 => 'CurrentActivityTypeIntensity',
    25 => { Name => 'TimeStampMin_8', PrintConv => '"$val min"' },
    26 => { Name => 'TimeStamp_16', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    27 => { Name => 'HeartRate', PrintConv => '"$val bpm"' },
    28 => { Name => 'Intensity', ValueConv => '$val / 10' },
    29 => { Name => 'DurationMin', PrintConv => '"$val min"' },
    30 => { Name => 'Duration', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    31 => { Name => 'Ascent', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    32 => { Name => 'Descent', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    33 => { Name => 'ModerateActivityMinutes', PrintConv => '"$val minutes"' },
    34 => { Name => 'VigorousActivityMinutes', PrintConv => '"$val minutes"' },
);

%Image::ExifTool::Garmin::MonitoringHRData = (
    GROUPS => { 0 => 'Garmin', 1 => 'MonitorHRData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'RestingHeartRate', PrintConv => '"$val bpm"' },
    1 => { Name => 'CurrentDayRestingHeartRate', PrintConv => '"$val bpm"' },
);

%Image::ExifTool::Garmin::SPO2Data = (
    GROUPS => { 0 => 'Garmin', 1 => 'SPO2Data', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ReadingSPO2', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    1 => { Name => 'ReadingConfidence', ValueConv => '$val / 1' },
    2 => 'Mode',
);

%Image::ExifTool::Garmin::HR = (
    GROUPS => { 0 => 'Garmin', 1 => 'HR', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FractionalTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    1 => { Name => 'Time256', ValueConv => '$val / 256', PrintConv => '"$val s"' },
    6 => 'FilteredBpm', # [N] bpm
    9 => 'EventTimeStamp', # [N] / 1024 s
    10 => 'EventTimeStamp_12', # [N] / 1024 s
);

%Image::ExifTool::Garmin::StressLevel = (
    GROUPS => { 0 => 'Garmin', 1 => 'StressLevel', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'StressLevelValue',
    1 => { Name => 'StressLevelTime', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::MaxMetData = (
    GROUPS => { 0 => 'Garmin', 1 => 'MaxMetData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'UpdateTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'Vo2Max', ValueConv => '$val / 10', PrintConv => '"$val mL/kg/min"' },
    5 => 'Sport',
    6 => 'SubSport',
    8 => 'MaxMetCategory',
    9 => 'CalibratedData',
    12 => 'HRSource',
    13 => 'SpeedSource',
);

%Image::ExifTool::Garmin::HSABodyBatteryData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSABodyBattery', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'Level', # [N] percent
    2 => 'Charged',
    3 => 'Uncharged',
);

%Image::ExifTool::Garmin::HSAEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAEvent', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'EventID',
);

%Image::ExifTool::Garmin::HSAAccelerometerData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAAccelData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SamplingInterval', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    2 => 'AccelX', # [N] / 1.024 mG
    3 => 'AccelY', # [N] / 1.024 mG
    4 => 'AccelZ', # [N] / 1.024 mG
    5 => 'TimeStamp_32k',
);

%Image::ExifTool::Garmin::HSAGyroscopeData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAGyroData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SamplingInterval', PrintConv => '"$val 1/32768 s' },
    2 => 'GyroX', # [N] / 28.57143 deg/s
    3 => 'GyroY', # [N] / 28.57143 deg/s
    4 => 'GyroZ', # [N] / 28.57143 deg/s
    5 => { Name => 'TimeStamp_32k', PrintConv => '"$val 1/32768 s' },
);

%Image::ExifTool::Garmin::HSAStepData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAStepData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'Steps', # [N] / 1 steps
);

%Image::ExifTool::Garmin::HSA_SPO2Data = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSA_SPO2Data', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'ReadingSPO2', # [N] percent
    2 => 'Confidence',
);

%Image::ExifTool::Garmin::HSAStressData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAStressData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'StressLevel', # [N] / 1 s
);

%Image::ExifTool::Garmin::HSARespirationData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSARespirData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'RespirationRate', # [N] / 100 breaths/min
);

%Image::ExifTool::Garmin::HSAHeartRateData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSA_HRData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'Status',
    2 => 'HeartRate', # [N] / 1 bpm
);

%Image::ExifTool::Garmin::HSAConfigurationData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAConfigData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Data',
    1 => 'DataSize',
);

%Image::ExifTool::Garmin::HSAWristTemperatureData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAWristTemp', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'Value', # [N] / 1000 degC
);

%Image::ExifTool::Garmin::MemoGlob = (
    GROUPS => { 0 => 'Garmin', 1 => 'MemoGlob', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Memo',
    1 => 'MesgNum',
    2 => 'ParentIndex',
    3 => 'FieldNum',
    4 => 'Data',
);

%Image::ExifTool::Garmin::SleepLevel = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepLevel', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SleepLevel',
);

%Image::ExifTool::Garmin::AntChannelID = (
    GROUPS => { 0 => 'Garmin', 1 => 'AntChannelID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ChannelNumber',
    1 => 'DeviceType',
    2 => 'DeviceNumber',
    3 => 'TransmissionType',
    4 => 'DeviceIndex',
);

%Image::ExifTool::Garmin::AntRx = (
    GROUPS => { 0 => 'Garmin', 1 => 'AntRx', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FractionalTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    1 => 'MesgID',
    2 => 'MesgData', # [N]
    3 => 'ChannelNumber',
    4 => 'Data',
);

%Image::ExifTool::Garmin::AntTx = (
    GROUPS => { 0 => 'Garmin', 1 => 'AntTx', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FractionalTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    1 => 'MesgID',
    2 => 'MesgData', # [N]
    3 => 'ChannelNumber',
    4 => 'Data',
);

%Image::ExifTool::Garmin::ExdScreenConfiguration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExdScreenConfig', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ScreenIndex',
    1 => 'FieldCount',
    2 => 'Layout',
    3 => 'ScreenEnabled',
);

%Image::ExifTool::Garmin::ExdDataFieldConfiguration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExdDataFieldConfig', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ScreenIndex',
    1 => 'ConceptField',
    2 => 'FieldID',
    3 => 'ConceptCount',
    4 => 'DisplayType',
    5 => 'Title',
);

%Image::ExifTool::Garmin::ExdDataConceptConfiguration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExdDataConceptConfig', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ScreenIndex',
    1 => 'ConceptField',
    2 => 'FieldID',
    3 => 'ConceptIndex',
    4 => 'DataPage',
    5 => 'ConceptKey',
    6 => 'Scaling',
    8 => 'DataUnits',
    9 => 'Qualifier',
    10 => 'Descriptor',
    11 => 'IsSigned',
);

%Image::ExifTool::Garmin::DiveSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ReferenceMesg',
    1 => 'ReferenceIndex',
    2 => { Name => 'AvgDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    3 => { Name => 'MaxDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    4 => { Name => 'SurfaceInterval', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    5 => { Name => 'StartCns', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    6 => { Name => 'EndCns', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    7 => { Name => 'StartN2', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    8 => { Name => 'EndN2', ValueConv => '$val / 1', PrintConv => '"$val percent"' },
    9 => { Name => 'O2Toxicity', PrintConv => '"$val OTUs"' },
    10 => 'DiveNumber',
    11 => { Name => 'BottomTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    12 => { Name => 'AvgPressureSac', ValueConv => '$val / 100', PrintConv => '"$val bar/min"' },
    13 => { Name => 'AvgVolumeSac', ValueConv => '$val / 100', PrintConv => '"$val L/min"' },
    14 => { Name => 'AvgRmv', ValueConv => '$val / 100', PrintConv => '"$val L/min"' },
    15 => { Name => 'DescentTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    16 => { Name => 'AscentTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    17 => { Name => 'AvgAscentRate', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    22 => { Name => 'AvgDescentRate', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    23 => { Name => 'MaxAscentRate', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    24 => { Name => 'MaxDescentRate', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    25 => { Name => 'HangTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::AADAccelFeatures = (
    GROUPS => { 0 => 'Garmin', 1 => 'AADAccelFeatures', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Time', PrintConv => '"$val s"', Groups => { 2 => 'Time' } },
    1 => 'EnergyTotal',
    2 => 'ZeroCrossCnt',
    3 => 'Instance',
    4 => { Name => 'TimeAboveThreshold', ValueConv => '$val / 25', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::HRV = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRV', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Time', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::BeatIntervals = (
    GROUPS => { 0 => 'Garmin', 1 => 'BeatIntervals', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'Time', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::HRVStatusSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRVStatusSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'WeeklyAverage', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
    1 => { Name => 'LastNightAverage', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
    2 => { Name => 'LastNight_5MinHigh', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
    3 => { Name => 'BaselineLowUpper', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
    4 => { Name => 'BaselineBalancedLower', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
    5 => { Name => 'BaselineBalancedUpper', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
    6 => 'Status',
);

%Image::ExifTool::Garmin::HRVValue = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRVValue', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Value', ValueConv => '$val / 128', PrintConv => '"$val ms"' },
);

%Image::ExifTool::Garmin::RawBBI = (
    GROUPS => { 0 => 'Garmin', 1 => 'RawBBI', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => 'Data', # [N]
    2 => { Name => 'Time', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    3 => 'Quality',
    4 => 'Gap',
);

%Image::ExifTool::Garmin::RespirationRate = (
    GROUPS => { 0 => 'Garmin', 1 => 'RespirationRate', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'RespirationRate', ValueConv => '$val / 100', PrintConv => '"$val breaths/min"' },
);

%Image::ExifTool::Garmin::ChronoShotSession = (
    GROUPS => { 0 => 'Garmin', 1 => 'ChronoShotSession', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'MinSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    1 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    2 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    3 => 'ShotCount',
    4 => 'ProjectileType',
    5 => { Name => 'GrainWeight', ValueConv => '$val / 10', PrintConv => '"$val gr"' },
    6 => { Name => 'StandardDeviation', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
);

%Image::ExifTool::Garmin::ChronoShotData = (
    GROUPS => { 0 => 'Garmin', 1 => 'ChronoShotData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ShotSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    1 => 'ShotNum',
);

%Image::ExifTool::Garmin::TankUpdate = (
    GROUPS => { 0 => 'Garmin', 1 => 'TankUpdate', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Sensor',
    1 => { Name => 'Pressure', ValueConv => '$val / 100', PrintConv => '"$val bar"' },
);

%Image::ExifTool::Garmin::TankSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'TankSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Sensor',
    1 => { Name => 'StartPressure', ValueConv => '$val / 100', PrintConv => '"$val bar"' },
    2 => { Name => 'EndPressure', ValueConv => '$val / 100', PrintConv => '"$val bar"' },
    3 => { Name => 'VolumeUsed', ValueConv => '$val / 100', PrintConv => '"$val L"' },
);

%Image::ExifTool::Garmin::SleepAssessment = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepAssessment', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'CombinedAwakeScore',
    1 => 'AwakeTimeScore',
    2 => 'AwakeningsCountScore',
    3 => 'DeepSleepScore',
    4 => 'SleepDurationScore',
    5 => 'LightSleepScore',
    6 => 'OverallSleepScore',
    7 => 'SleepQualityScore',
    8 => 'SleepRecoveryScore',
    9 => 'RemSleepScore',
    10 => 'SleepRestlessnessScore',
    11 => 'AwakeningsCount',
    14 => 'InterruptionsScore',
    15 => { Name => 'AverageStressDuringSleep', ValueConv => '$val / 100' },
);

%Image::ExifTool::Garmin::SleepDisruptionSeverityPeriod = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepDisruptPeriod', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Severity',
);

%Image::ExifTool::Garmin::SleepDisruptionOvernightSeverity = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepDisruptOvernight', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Severity',
);

%Image::ExifTool::Garmin::NapEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'NapEvent', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    1 => { Name => 'StartTimezoneOffset', PrintConv => '"$val minutes"' },
    2 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'EndTimezoneOffset', PrintConv => '"$val minutes"' },
    4 => 'Feedback',
    5 => 'IsDeleted',
    6 => 'Source',
    7 => { Name => 'UpdateTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::SkinTempOvernight = (
    GROUPS => { 0 => 'Garmin', 1 => 'SkinTempOvernight', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'LocalTimeStamp',
    1 => 'AverageDeviation',
    2 => 'Average_7DayDeviation',
    4 => 'NightlyValue',
);

# set Unknown flag for all unsupported FIT messages
{
    my $key;
    foreach $key (TagTableKeys(\%Image::ExifTool::Garmin::FIT)) {
        next if ref $Image::ExifTool::Garmin::FIT{$key};
        $Image::ExifTool::Garmin::FIT{$key} = {
            Name => $Image::ExifTool::Garmin::FIT{$key},
            Unknown => 1,
        };
    }
}

#------------------------------------------------------------------------------
# Calculate CRC for each byte
# Inputs: 0) running CRC, 1) byte value
# Returns: updated CRC
# - unused here, but included in case it may be helpful later
my @crc_table = (
    0x0000, 0xcc01, 0xd801, 0x1400, 0xf001, 0x3c00, 0x2800, 0xe401,
    0xa001, 0x6c00, 0x7800, 0xb401, 0x5000, 0x9c01, 0x8801, 0x4400
);
sub CRC($$)
{
    my ($crc, $byte) = @_;
    my $tmp;
    # compute checksum of lower four bits of byte
    $tmp = $crc_table[$crc & 0xf];
    $crc = ($crc >> 4) & 0x0fff;
    $crc = $crc ^ $tmp ^ $crc_table[$byte & 0xf];
    # now compute checksum of upper four bits of byte
    $tmp = $crc_table[$crc & 0xf];
    $crc = ($crc >> 4) & 0x0fff;
    $crc = $crc ^ $tmp ^ $crc_table[($byte >> 4) & 0xf];
    return $crc;
}

#------------------------------------------------------------------------------
# Read Garmin FIT file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Return: true on success
sub ProcessFIT($$$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my ($buff, $err, %msg, %done, $i, $pos, $field, %devData);
    my $raf = $$dirInfo{RAF};
    my $unknown = $$et{OPTIONS}{Unknown};
    my $verbose = $$et{OPTIONS}{Verbose};
    my $ee = $$et{OPTIONS}{ExtractEmbedded};
    $unknown or $unknown = 1 if $verbose;

    # verify this is a valid Garmin FIT file
    return 0 unless $raf->Read($buff, 12) == 12 and $buff =~ /^.{8}\.FIT/s;
    $et->SetFileType();
    my $tagTbl = GetTagTable('Image::ExifTool::Garmin::FIT');
    my $common = GetTagTable('Image::ExifTool::Garmin::Common');
    my $devTbl = GetTagTable('Image::ExifTool::Garmin::Dev');
    # clear out old developer tags
    delete $$devTbl{$_} foreach TagTableKeys($devTbl);
    $et->HandleTag($tagTbl, ProtocolVersion => Get8u(\$buff, 1));
    $ee or $et->Warn('Use ExtractEmbedded option to extract all timed metadata', 3);
    my ($hdrLen, $dataLen) = unpack('Cx3V', $buff);
    $raf->Read($buff, $hdrLen-12) if $hdrLen > 12;
    my $timestamp = 0;
    for (;;) {
        my $msgStart = $raf->Tell();
        last if $msgStart >= $hdrLen + $dataLen;
        last unless $raf->Read($buff, 1) == 1;
        my $flags = unpack('C', $buff);
        my $localNum;
        if ($flags & 0x80) { # compressed header
            $localNum = ($flags >> 5) & 0x03;
            # update current timestamp
            my $timeOffset = $flags & 0x1f;
            if ($timeOffset) {
                # the FIT specification is stupid here. The offset should have
                # been defined as a simple difference from the previous timestamp
                # instead of the lower 5 bits with a wrap-around.  Dumb.  All the
                # resulting bit gymnastics are totally unnecessary:
                my $lowBits = $timestamp & 0x1f;
                my $ts = ($timestamp & 0xffffffe0) + $timeOffset;
                $ts += 0x20 if $timeOffset < $lowBits;
                $msg{$localNum}{TS} = [ 253, $ts ]; # [num, new timestamp]
            }
        } else { # normal header
            $localNum = $flags & 0x0f;
            if ($flags & 0x40) {
#
# Process the definition message
#
                unless ($raf->Read($buff, 5) == 5) {
                    if ($raf->Tell() != $hdrLen + $dataLen + 2) { # (+2 for checksum)
                        $err = 'Unexpected end of file';
                    }
                    last;
                }
                SetByteOrder(Get8u(\$buff, 1) ? 'MM' : 'II');
                my $msgNum = Get16u(\$buff, 2);
                my $nFields = Get8u(\$buff, 4);
                my $len = $nFields * 3;
                my $theMsg = $msg{$localNum} = { };  # start new message definition
                $$theMsg{ByteOrder} = GetByteOrder();
                $$theMsg{MessageNum} = $msgNum;
                my $tagInfo = $$tagTbl{$msgNum};
                my ($msgName, $fieldInfo);
                if ($tagInfo) {
                    $$theMsg{Name} = $msgName = $$tagInfo{Name};
                } else {
                    $$theMsg{Name} = $msgName = "Unknown$msgNum";
                    $tagInfo = { Name => $msgName, Unknown => 1 };
                    AddTagToTable($tagTbl, $msgNum, $tagInfo);
                }
                unless ($$tagInfo{SubDirectory}) {
                    # construct table for this subdirectory
                    my $tableName = 'Image::ExifTool::Garmin::' . $msgName;
                    no strict 'refs';
                    my $tbl = \%$tableName;
                    use strict 'refs';
                    %$tbl = (
                        GROUPS => { 0 => 'Garmin', 1 => $msgName, 2 => 'Unknown' },
                        VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
                    );
                    $$tagInfo{SubDirectory}{TagTable} = $tableName;
                }
                my $subTbl = GetTagTable($$tagInfo{SubDirectory}{TagTable});
                $et->VPrint(1, "  + [$msgName definition message (local $localNum)]");
                $raf->Read($buff, $len) == $len or $err = 'Truncated definition message', last;
                my $totSize = 0;
                unless ($$tagInfo{Unknown} and not $unknown) {
                    $fieldInfo = $$theMsg{FieldInfo} = [ ];
                }
                # loop through the message field definitions
                for ($pos=0; $pos<$len; $pos+=3) {
                    my ($num, $size, $type) = unpack "x$pos C3", $buff;
                    if ($baseType{$type}) {
                        # remember offset of timestamp if this message has one
                        if ($num == 253 or $$subTbl{$num} and not $$theMsg{TS} and
                            $$subTbl{$num}{IsTimeStamp})
                        {
                            $$theMsg{TS} = [ $num, $size, $type, $totSize ]
                        }
                        # save field definitions for fields we care about
                        push @$fieldInfo, [ $num, $size, $type ] if $fieldInfo;
                    } else {
                        $et->Warn("Unknown field type $type");
                    }
                    $totSize += $size;
                }
                my $nDev = 0;
                if ($flags & 0x20) { # developer data flag
                    $raf->Read($buff, 1) == 1 or $err = 'Missing developer definition', last;
                    $nDev = Get8u(\$buff, 0);
                    $len = $nDev * 3;
                    $raf->Read($buff, $len) == $len or $err = 'Truncated developer definition', last;
                    # loop through the developer fields
                    for ($i=0,$pos=0; $i<$nDev; ++$i,$pos+=3) {
                        my ($num, $size, $idx) = unpack "x$pos C3", $buff;
                        # fieldInfo[3] is flag for developer field
                        push @$fieldInfo, [ $num, $size, $idx, 1 ] if $fieldInfo;
                        $totSize += $size;
                    }
                }
                $$theMsg{Size} = $totSize;
                if ($verbose > 2) {
                    my $n = $raf->Tell() - $msgStart;
                    $raf->Seek(-$n, 1) and $raf->Read($buff, $n) or $err = 'Seek error', last;
                    my $nDev = $n - 6 - 3 * $nFields;
                    $nDev = ($nDev - 1) / 3 if $nDev;
                    $et->VPrint(1, "    ($nFields data + $nDev developer fields)");
                    $et->VerboseDump(\$buff, DataPos => $raf->Tell() - $n);
                }
                next;
            }
        }
#
# Process the data message
#
        my $theMsg = $msg{$localNum};
        $theMsg or $err = "Missing definition for local message $localNum", last;
        my $dataPos = $raf->Tell();
        my $msgSize = $$theMsg{Size};
        my $msgNum = $$theMsg{MessageNum};
        SetByteOrder($$theMsg{ByteOrder});
        unless ($ee) {
            if ($done{$msgNum}) {
                $raf->Seek($msgSize, 1) or $err = 'Seek error', last;
                next;
            } else {
                $done{$msgNum} = 1;
            }
        }
        $raf->Read($buff, $msgSize) == $msgSize or $err = 'Truncated data message', last;
        my $fieldInfo = $$theMsg{FieldInfo};
        my $msgName = $$theMsg{Name};
        my $tagInfo = $$tagTbl{$msgNum};
        my $subTbl = GetTagTable($$tagInfo{SubDirectory}{TagTable});
        my $oldIndent = $$et{INDENT};
        $$et{INDENT} .= '| ';
        my $comp = ($flags & 0x80) ? 'compressed header, ' : '';
        $et->VerboseDir($$tagInfo{Name}, undef, "(local $localNum) $comp$msgSize");
        if ($verbose > 2) {
            my $tmp = chr($flags) . $buff;
            $et->VerboseDump(\$tmp, DataPos => $raf->Tell() - $msgSize - 1);
        }
        my $ts = $$theMsg{TS};
        if ($ts and $$ts[0] == 253) {
            my ($val, %parms);
            if (defined $$ts[2]) {
                $val = ReadValue(\$buff, $$ts[3], $baseType{$$ts[2]}[0], 1, $$ts[1]);
                %parms = (
                    DataPt  => \$buff,
                    DataPos => $dataPos,
                    Start   => $$ts[3],
                    Size    => $$ts[1],
                    Format  => qq($baseType{$$ts[2]}[0] "$baseType{$$ts[2]}[1]"),
                );
            } else {
                $val = $$ts[1];
            }
            # save TimeStamp tag now for unknown or compressed message
            if ($timestamp != $val) {
                $timestamp = $val;
                # increment document number for GPS data or any message with a new timestamp
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                unless ($fieldInfo and defined $$ts[2]) {
                    # set group 1 to message name
                    $$et{SET_GROUP1} = $$subTbl{GROUPS}{1};
                    $et->HandleTag($common, $$ts[0], $val, %parms);
                    delete $$et{SET_GROUP1};
                }
            }
        }
        # ignore this message unless it contains something else we care about
        $fieldInfo or $$et{INDENT} = $oldIndent, next;
        ($i, $pos) = (0, 0);
        my (%fieldValue, $tbl);
        foreach $field (@$fieldInfo) {
            my ($num, $size, $type) = @$field;
            if (not $$field[3]) { # standard field
                $tbl = $subTbl;
                if (not $$tbl{$num}) {
                    if ($$common{$num}) {
                        $tbl = $common;
                        $$et{SET_GROUP1} = $$subTbl{GROUPS}{1};
                    } else {
                        AddTagToTable($tbl, $num, { Name => "${msgName}_$num", Unknown => 1 });
                    }
                }
            } else { # developer field
#
# Example layout of developer messages:
#
# DevData: app=A idx=0
# DevData: app=B idx=1
# FieldDescr: idx=0 (app A) num=0 type=uint8  name="speed" units="km/h"
# FieldDescr: idx=1 (app B) num=0 type=uint16 name="elev" units="m"
# FieldDescr: idx=1 (app B) num=1 type=string name="model" units=""
# Message XX definition:
#   Fields (2)
#     num=0 size=2 type=uint16 (for example)
#     num=1 size=4 type=uint32 (for example)
#   DevFields (2)
#     num=0 size=1 idx=0 (app A speed)
#     num=0 size=2 idx=1 (app B elev)
#     num=1 size=5 idx=1 (app B model)
# Message XX data:
#     uint16 uint32 unit8(speed) uint16(elev) "A380\0"(model)
#
                $tbl = $devTbl;
                my $idx = $type;
                my $dev = $devData{$idx};
                if ($dev and $$dev{$num} and defined $$dev{$num}{2} and
                    defined $$dev{$num}{3} and defined $$dev{ID}{1})
                {
                    my $id = unpack('H*', $$dev{ID}{1}) . '_' . $$dev{$num}{1};
                    unless ($$tbl{$id}) {
                        my $name = $$dev{$num}{3};
                        $name =~ s/($|_)([a-z])/\U$2/g;
                        $name = Image::ExifTool::MakeTagName($name);
                        my $tagInfo = { Name  => $name },
                        my $units = $$dev{$num}{8};
                        if ($units) {
                            $units =~ tr/-_a-zA-Z0-9\/+*//dc;
                            $$tagInfo{PrintConv} = qq("\$val $units");
                        }
                        AddTagToTable($tbl, $id, $tagInfo);
                    }
                    $type = $$dev{$num}{2};
                    $num = $id;
                } else {
                    $et->Warn('Incomplete developer field definition') if $unknown;
                    $pos += $size;
                    next;
                }
            }
            if ($baseType{$type}) {
                my $fmt = $baseType{$type}[0];
                my $count = $size / Image::ExifTool::FormatSize($fmt);
                if (int($count) == $count) {
                    my $val = ReadValue(\$buff, $pos, $fmt, $count, $size);
                    # ignore invalid values
                    unless ($val eq $baseType{$type}[2]) {
                        $fieldValue{$num} = $val unless $$field[3];
                        my $str = qq($fmt "$baseType{$type}[1]");
                        $str .= ", devIdx=$$field[2]" if $$field[3];
                        $et->HandleTag($tbl, $num, $fmt eq 'undef' ? \$val : $val,
                            DataPt  => \$buff,
                            DataPos => $dataPos,
                            Start   => $pos,
                            Size    => $size,
                            Index   => $i++,
                            Format  => $str,
                        );
                    }
                } else {
                    $et->Warn("Bad count for $fmt $msgName field $num");
                }
            } else {
                $et->Warn("Unknown field type $type");
            }
            delete $$et{SET_GROUP1};
            $pos += $size;
        }
        $$et{INDENT} = $oldIndent;
        # save messages required to decode developer fields
        if ($msgNum == 207) { # DeveloperDataID
            my $idx = $fieldValue{3};   # DeveloperDataIndex
            $devData{$idx}{ID} = { %fieldValue } if defined $idx;
        } elsif ($msgNum == 206) { # FieldDescription
            my $idx = $fieldValue{0};   # DeveloperDataIndex
            my $num = $fieldValue{1};
            if (defined $idx and defined $num) {
                $devData{$idx}{$num} = { %fieldValue };
            }
        }
    }
    $err and $et->Warn($err);
    delete $$et{DOC_NUM};
    return 1;
}

1; #end

__END__

=head1 NAME

Image::ExifTool::Garmin - Routines to read Garmin FIT files

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Garmin FIT (Flexible and Interoperable data Transfer) files.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Garmin Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
