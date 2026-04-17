#------------------------------------------------------------------------------
# File:         Garmin.pm
#
# Description:  Read Garmin FIT files
#
# Revisions:    2026-04-09 - P. Harvey Created
#
# References:   1) https://developer.garmin.com/fit/overview/
#               2) https://developer.garmin.com/fit/protocol/
#               3) https://github.com/garmin/fit-sdk-tools/blob/main/Profile.xlsx
#               4) https://docs.google.com/spreadsheets/d/1x34eRAZ45nbi3U3GyANotgmoQfj0fR49wBxmL-oLogc/
#               5) https://forums.garmin.com/developer/fit-sdk/f/discussion/254469/list-of-undocumented-mesg_num/1223595
#------------------------------------------------------------------------------

package Image::ExifTool::Garmin;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::GPS;

$VERSION = '1.01';

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
);

my %localTime = (
    # add seconds between Jan 1, 1970 and epoch of Dec 31, 1989
    ValueConv => 'Image::ExifTool::ConvertUnixTime($val + 631065600)',
    PrintConv => '$self->ConvertDateTime($val)',
);

my %altInfo = (
    ValueConv => '$val / 5 - 500',      # convert to metres
    PrintConv => '"$val m"',
);

my %speedInfo = (
    ValueConv => '$val * 3.6 / 1000',   # convert to km/h from mm/s
    PrintConv => '"$val km/h"',
);

#----------------------------------------------------------------------
# FIT enumerated types.  First we start with the documented types (ref 2)
#
my %file = (
    1 => 'Device',
    2 => 'Settings',
    3 => 'Sport',
    4 => 'Activity',
    5 => 'Workout',
    6 => 'Course',
    7 => 'Schedules',
    8 => 'Locations', #4
    9 => 'Weight',
    10 => 'Totals',
    11 => 'Goals',
    14 => 'Blood Pressure',
    15 => 'Monitoring A',
    20 => 'Activity Summary',
    28 => 'Monitoring Daily',
    29 => 'Records', #4
    32 => 'Monitoring B',
    33 => 'Multi Sport', #4
    34 => 'Segment',
    35 => 'Segment List',
    37 => 'Clubs', #4
    38 => 'Score Card', #4
    40 => 'Exd Configuration',
    44 => 'Metrics', #4
    49 => 'Sleep', #4
    54 => 'Chrono Shot Session', #4
    56 => 'Pace Band', #4
    61 => 'ECG', #4
    65 => 'Calendar', #4
    68 => 'HRV Status', #4
    72 => 'LHA Backup', #4
    74 => 'PTD Backup', #4
    77 => 'Schedule', #4
);

my %mesgNum = (
    0 => 'File ID',
    1 => 'Capabilities',
    2 => 'Device Settings',
    3 => 'User Profile',
    4 => 'HRM Profile',
    5 => 'SDM Profile',
    6 => 'Bike Profile',
    7 => 'Zones Target',
    8 => 'HR Zone',
    9 => 'Power Zone',
    10 => 'Met Zone',
    12 => 'Sport',
    13 => 'Training Settings',
    14 => 'Data Screen', #4
    15 => 'Goal',
    16 => 'Alert', #4
    17 => 'Range Alert', #4
    18 => 'Session',
    19 => 'Lap',
    20 => 'Record',
    21 => 'Event',
    22 => 'Device Used', #4
    23 => 'Device Info',
    26 => 'Workout',
    27 => 'Workout Step',
    28 => 'Schedule',
    29 => 'Location', #4
    30 => 'Weight Scale',
    31 => 'Course',
    32 => 'Course Point',
    33 => 'Totals',
    34 => 'Activity',
    35 => 'Software',
    37 => 'File Capabilities',
    38 => 'Mesg Capabilities',
    39 => 'Field Capabilities',
    49 => 'File Creator',
    51 => 'Blood Pressure',
    53 => 'Speed Zone',
    55 => 'Monitoring',
    70 => 'Map Layer', #4
    71 => 'Routing', #4
    72 => 'Training File',
    78 => 'HRV',
    79 => 'User Metrics', #4
    80 => 'Ant Rx',
    81 => 'Ant Tx',
    82 => 'Ant Channel ID',
    89 => 'Open Water Event', #4
    101 => 'Length',
    103 => 'Monitoring Info',
    104 => 'Device Status', #4
    105 => 'Pad',
    106 => 'Slave Device',
    113 => 'Best Effort', #4
    114 => 'Personal Record', #4
    127 => 'Connectivity',
    128 => 'Weather Conditions',
    129 => 'Weather Alert',
    131 => 'Cadence Zone',
    132 => 'HR',
    140 => 'Activity Metrics', #4
    141 => 'EPO Status', #4
    142 => 'Segment Lap',
    143 => 'Multisport Settings', #4
    144 => 'Multisport Activity', #4
    145 => 'Memo Glob',
    147 => 'Sensor Settings', #4
    148 => 'Segment ID',
    149 => 'Segment Leaderboard Entry',
    150 => 'Segment Point',
    151 => 'Segment File',
    152 => 'Metronome', #4
    158 => 'Workout Session',
    159 => 'Watchface Settings',
    160 => 'GPS Metadata',
    161 => 'Camera Event',
    162 => 'Time Stamp Correlation',
    164 => 'Gyroscope Data',
    165 => 'Accelerometer Data',
    167 => 'Three D Sensor Calibration',
    169 => 'Video Frame',
    170 => 'Connect IQ Field', #4
    173 => 'Clubs', #4
    174 => 'OBDII Data',
    177 => 'NMEA Sentence',
    178 => 'Aviation Attitude',
    184 => 'Video',
    185 => 'Video Title',
    186 => 'Video Description',
    187 => 'Video Clip',
    188 => 'OHR Settings',
    189 => 'Waypoint Handling', #4
    190 => 'Golf Course', #4
    191 => 'Golf Stats', #4
    192 => 'Score', #4
    193 => 'Hole', #4
    194 => 'Shot', #4
    200 => 'Exd Screen Configuration',
    201 => 'Exd Data Field Configuration',
    202 => 'Exd Data Concept Configuration',
    206 => 'Field Description',
    207 => 'Developer Data ID',
    208 => 'Magnetometer Data',
    209 => 'Barometer Data',
    210 => 'One D Sensor Calibration',
    211 => 'Monitoring HR Data',
    216 => 'Time In Zone',
    222 => 'Alarm Settings', #4
    225 => 'Set',
    227 => 'Stress Level',
    229 => 'Max Met Data',
    243 => 'Music Info', #4
    258 => 'Dive Settings',
    259 => 'Dive Gas',
    262 => 'Dive Alarm',
    264 => 'Exercise Title',
    268 => 'Dive Summary',
    269 => 'SPO2 Data',
    273 => 'Sleep Data Info', #4
    275 => 'Sleep Level',
    285 => 'Jump',
    289 => 'AAD Accel Features',
    290 => 'Beat Intervals',
    297 => 'Respiration Rate',
    302 => 'HSA Accelerometer Data',
    304 => 'HSA Step Data',
    305 => 'HSA SPO2 Data',
    306 => 'HSA Stress Data',
    307 => 'HSA Respiration Data',
    308 => 'HSA Heart Rate Data',
    309 => 'Mtb Cx', #4
    310 => 'Race', #4
    311 => 'Split Time', #4
    312 => 'Split',
    313 => 'Split Summary',
    314 => 'HSA Body Battery Data',
    315 => 'HSA Event',
    317 => 'Climb Pro',
    319 => 'Tank Update',
    321 => 'Power Mode', #4
    323 => 'Tank Summary',
    326 => 'GPS Event', #4
    336 => 'ECG Summary', #4
    337 => 'ECG Raw Sample', #4
    338 => 'ECG Smooth Sample', #4
    346 => 'Sleep Assessment',
    356 => 'Functional Metrics', #4
    358 => 'Race Event', #4
    369 => 'Training Readiness', #4
    370 => 'HRV Status Summary',
    371 => 'HRV Value',
    372 => 'Raw BBI',
    375 => 'Device Aux Battery Info',
    376 => 'HSA Gyroscope Data',
    378 => 'Training Load', #4
    379 => 'Sleep Schedule', #4
    382 => 'Sleep Restless Moments', #4
    387 => 'Chrono Shot Session',
    388 => 'Chrono Shot Data',
    389 => 'HSA Configuration Data',
    393 => 'Dive Apnea Alarm',
    394 => 'CPE Status', #4
    398 => 'Skin Temp Overnight',
    402 => 'Hill Score', #4
    403 => 'Endurance Score', #4
    409 => 'HSA Wrist Temperature Data',
    412 => 'Nap Event',
    428 => 'Workout Schedule', #4
    470 => 'Sleep Disruption Severity Period',
    471 => 'Sleep Disruption Overnight Severity',
);

my %checksum = (
    0 => 'Clear',
    1 => 'Ok',
);

my %fileFlags = (
  BITMASK => {
    1 => 'Read',
    2 => 'Write',
    3 => 'Erase',
  }
);

my %mesgCount = (
    0 => 'Num Per File',
    1 => 'Max Per File',
    2 => 'Max Per File Type',
);

my %dateTime = (
  BITMASK => {
    28 => 'Min',
  }
);

my %localDateTime = (
  BITMASK => {
    28 => 'Min',
  }
);

my %deviceIndex = (
    0 => 'Creator',
);

my %gender = (
    0 => 'Female',
    1 => 'Male',
);

my %language = (
    0 => 'English',
    1 => 'French',
    2 => 'Italian',
    3 => 'German',
    4 => 'Spanish',
    5 => 'Croatian',
    6 => 'Czech',
    7 => 'Danish',
    8 => 'Dutch',
    9 => 'Finnish',
    10 => 'Greek',
    11 => 'Hungarian',
    12 => 'Norwegian',
    13 => 'Polish',
    14 => 'Portuguese',
    15 => 'Slovakian',
    16 => 'Slovenian',
    17 => 'Swedish',
    18 => 'Russian',
    19 => 'Turkish',
    20 => 'Latvian',
    21 => 'Ukrainian',
    22 => 'Arabic',
    23 => 'Farsi',
    24 => 'Bulgarian',
    25 => 'Romanian',
    26 => 'Chinese',
    27 => 'Japanese',
    28 => 'Korean',
    29 => 'Taiwanese',
    30 => 'Thai',
    31 => 'Hebrew',
    32 => 'Brazilian Portuguese',
    33 => 'Indonesian',
    34 => 'Malaysian',
    35 => 'Vietnamese',
    36 => 'Burmese',
    37 => 'Mongolian',
    254 => 'Custom',
);

my %languageBits_0 = (
  BITMASK => {
    0 => 'English',
    1 => 'French',
    2 => 'Italian',
    3 => 'German',
    4 => 'Spanish',
    5 => 'Croatian',
    6 => 'Czech',
    7 => 'Danish',
  }
);

my %languageBits_1 = (
  BITMASK => {
    0 => 'Dutch',
    1 => 'Finnish',
    2 => 'Greek',
    3 => 'Hungarian',
    4 => 'Norwegian',
    5 => 'Polish',
    6 => 'Portuguese',
    7 => 'Slovakian',
  }
);

my %languageBits_2 = (
  BITMASK => {
    0 => 'Slovenian',
    1 => 'Swedish',
    2 => 'Russian',
    3 => 'Turkish',
    4 => 'Latvian',
    5 => 'Ukrainian',
    6 => 'Arabic',
    7 => 'Farsi',
  }
);

my %languageBits_3 = (
  BITMASK => {
    0 => 'Bulgarian',
    1 => 'Romanian',
    2 => 'Chinese',
    3 => 'Japanese',
    4 => 'Korean',
    5 => 'Taiwanese',
    6 => 'Thai',
    7 => 'Hebrew',
  }
);

my %languageBits_4 = (
  BITMASK => {
    0 => 'Brazilian Portuguese',
    1 => 'Indonesian',
    2 => 'Malaysian',
    3 => 'Vietnamese',
    4 => 'Burmese',
    5 => 'Mongolian',
  }
);

my %timeZone = (
    0 => 'Almaty',
    1 => 'Bangkok',
    2 => 'Bombay',
    3 => 'Brasilia',
    4 => 'Cairo',
    5 => 'Cape Verde Is',
    6 => 'Darwin',
    7 => 'Eniwetok',
    8 => 'Fiji',
    9 => 'Hong Kong',
    10 => 'Islamabad',
    11 => 'Kabul',
    12 => 'Magadan',
    13 => 'Mid Atlantic',
    14 => 'Moscow',
    15 => 'Muscat',
    16 => 'Newfoundland',
    17 => 'Samoa',
    18 => 'Sydney',
    19 => 'Tehran',
    20 => 'Tokyo',
    21 => 'Us Alaska',
    22 => 'Us Atlantic',
    23 => 'Us Central',
    24 => 'Us Eastern',
    25 => 'Us Hawaii',
    26 => 'Us Mountain',
    27 => 'Us Pacific',
    28 => 'Other',
    29 => 'Auckland',
    30 => 'Kathmandu',
    31 => 'Europe Western Wet',
    32 => 'Europe Central Cet',
    33 => 'Europe Eastern Eet',
    34 => 'Jakarta',
    35 => 'Perth',
    36 => 'Adelaide',
    37 => 'Brisbane',
    38 => 'Tasmania',
    39 => 'Iceland',
    40 => 'Amsterdam',
    41 => 'Athens',
    42 => 'Barcelona',
    43 => 'Berlin',
    44 => 'Brussels',
    45 => 'Budapest',
    46 => 'Copenhagen',
    47 => 'Dublin',
    48 => 'Helsinki',
    49 => 'Lisbon',
    50 => 'London',
    51 => 'Madrid',
    52 => 'Munich',
    53 => 'Oslo',
    54 => 'Paris',
    55 => 'Prague',
    56 => 'Reykjavik',
    57 => 'Rome',
    58 => 'Stockholm',
    59 => 'Vienna',
    60 => 'Warsaw',
    61 => 'Zurich',
    62 => 'Quebec',
    63 => 'Ontario',
    64 => 'Manitoba',
    65 => 'Saskatchewan',
    66 => 'Alberta',
    67 => 'British Columbia',
    68 => 'Boise',
    69 => 'Boston',
    70 => 'Chicago',
    71 => 'Dallas',
    72 => 'Denver',
    73 => 'Kansas City',
    74 => 'Las Vegas',
    75 => 'Los Angeles',
    76 => 'Miami',
    77 => 'Minneapolis',
    78 => 'New York',
    79 => 'New Orleans',
    80 => 'Phoenix',
    81 => 'Santa Fe',
    82 => 'Seattle',
    83 => 'Washington Dc',
    84 => 'Us Arizona',
    85 => 'Chita',
    86 => 'Ekaterinburg',
    87 => 'Irkutsk',
    88 => 'Kaliningrad',
    89 => 'Krasnoyarsk',
    90 => 'Novosibirsk',
    91 => 'Petropavlovsk Kamchatskiy',
    92 => 'Samara',
    93 => 'Vladivostok',
    94 => 'Mexico Central',
    95 => 'Mexico Mountain',
    96 => 'Mexico Pacific',
    97 => 'Cape Town',
    98 => 'Winkhoek',
    99 => 'Lagos',
    100 => 'Riyahd',
    101 => 'Venezuela',
    102 => 'Australia Lh',
    103 => 'Santiago',
    253 => 'Manual',
    254 => 'Automatic',
);

my %displayMeasure = (
    0 => 'Metric',
    1 => 'Statute',
    2 => 'Nautical',
);

my %displayHeart = (
    0 => 'BPM',
    1 => 'Max',
    2 => 'Reserve',
);

my %displayPower = (
    0 => 'W',
    1 => 'Percent Ftp',
);

my %displayPosition = (
    0 => 'Degree',
    1 => 'Degree Minute',
    2 => 'Degree Minute Second',
    3 => 'Austrian Grid',
    4 => 'British Grid',
    5 => 'Dutch Grid',
    6 => 'Hungarian Grid',
    7 => 'Finnish Grid',
    8 => 'German Grid',
    9 => 'Icelandic Grid',
    10 => 'Indonesian Equatorial',
    11 => 'Indonesian Irian',
    12 => 'Indonesian Southern',
    13 => 'India Zone 0',
    14 => 'India Zone IA',
    15 => 'India Zone IB',
    16 => 'India Zone IIA',
    17 => 'India Zone IIB',
    18 => 'India Zone IIIA',
    19 => 'India Zone IIIB',
    20 => 'India Zone IVA',
    21 => 'India Zone IVB',
    22 => 'Irish Transverse',
    23 => 'Irish Grid',
    24 => 'Loran',
    25 => 'Maidenhead Grid',
    26 => 'Mgrs Grid',
    27 => 'New Zealand Grid',
    28 => 'New Zealand Transverse',
    29 => 'Qatar Grid',
    30 => 'Modified Swedish Grid',
    31 => 'Swedish Grid',
    32 => 'South African Grid',
    33 => 'Swiss Grid',
    34 => 'Taiwan Grid',
    35 => 'United States Grid',
    36 => 'Utm Ups Grid',
    37 => 'West Malayan',
    38 => 'Borneo RSO',
    39 => 'Estonian Grid',
    40 => 'Latvian Grid',
    41 => 'Swedish Ref 99 Grid',
);

my %switch = (
    0 => 'Off',
    1 => 'On',
    2 => 'Auto',
);

my %sportEnum = (
    0 => 'Generic',
    1 => 'Running',
    2 => 'Cycling',
    3 => 'Transition',
    4 => 'Fitness Equipment',
    5 => 'Swimming',
    6 => 'Basketball',
    7 => 'Soccer',
    8 => 'Tennis',
    9 => 'American Football',
    10 => 'Training',
    11 => 'Walking',
    12 => 'Cross Country Skiing',
    13 => 'Alpine Skiing',
    14 => 'Snowboarding',
    15 => 'Rowing',
    16 => 'Mountaineering',
    17 => 'Hiking',
    18 => 'Multisport',
    19 => 'Paddling',
    20 => 'Flying',
    21 => 'E Biking',
    22 => 'Motorcycling',
    23 => 'Boating',
    24 => 'Driving',
    25 => 'Golf',
    26 => 'Hang Gliding',
    27 => 'Horseback Riding',
    28 => 'Hunting',
    29 => 'Fishing',
    30 => 'Inline Skating',
    31 => 'Rock Climbing',
    32 => 'Sailing',
    33 => 'Ice Skating',
    34 => 'Sky Diving',
    35 => 'Snowshoeing',
    36 => 'Snowmobiling',
    37 => 'Stand Up Paddleboarding',
    38 => 'Surfing',
    39 => 'Wakeboarding',
    40 => 'Water Skiing',
    41 => 'Kayaking',
    42 => 'Rafting',
    43 => 'Windsurfing',
    44 => 'Kitesurfing',
    45 => 'Tactical',
    46 => 'Jumpmaster',
    47 => 'Boxing',
    48 => 'Floor Climbing',
    49 => 'Baseball',
    53 => 'Diving',
    56 => 'Shooting',
    58 => 'Winter Sport',
    59 => 'Grinding',
    62 => 'Hiit',
    63 => 'Video Gaming',
    64 => 'Racket',
    65 => 'Wheelchair Push Walk',
    66 => 'Wheelchair Push Run',
    67 => 'Meditation',
    68 => 'Para Sport',
    69 => 'Disc Golf',
    70 => 'Team Sport',
    71 => 'Cricket',
    72 => 'Rugby',
    73 => 'Hockey',
    74 => 'Lacrosse',
    75 => 'Volleyball',
    76 => 'Water Tubing',
    77 => 'Wakesurfing',
    78 => 'Water Sport',
    79 => 'Archery',
    80 => 'Mixed Martial Arts',
    81 => 'Motor Sports',
    82 => 'Snorkeling',
    83 => 'Dance',
    84 => 'Jump Rope',
    85 => 'Pool Apnea',
    86 => 'Mobility',
    87 => 'Geocaching',
    88 => 'Canoeing',
    254 => 'All',
);

my %sportBits_0 = (
  BITMASK => {
    0 => 'Generic',
    1 => 'Running',
    2 => 'Cycling',
    3 => 'Transition',
    4 => 'Fitness Equipment',
    5 => 'Swimming',
    6 => 'Basketball',
    7 => 'Soccer',
  }
);

my %sportBits_1 = (
  BITMASK => {
    0 => 'Tennis',
    1 => 'American Football',
    2 => 'Training',
    3 => 'Walking',
    4 => 'Cross Country Skiing',
    5 => 'Alpine Skiing',
    6 => 'Snowboarding',
    7 => 'Rowing',
  }
);

my %sportBits_2 = (
  BITMASK => {
    0 => 'Mountaineering',
    1 => 'Hiking',
    2 => 'Multisport',
    3 => 'Paddling',
    4 => 'Flying',
    5 => 'E Biking',
    6 => 'Motorcycling',
    7 => 'Boating',
  }
);

my %sportBits_3 = (
  BITMASK => {
    0 => 'Driving',
    1 => 'Golf',
    2 => 'Hang Gliding',
    3 => 'Horseback Riding',
    4 => 'Hunting',
    5 => 'Fishing',
    6 => 'Inline Skating',
    7 => 'Rock Climbing',
  }
);

my %sportBits_4 = (
  BITMASK => {
    0 => 'Sailing',
    1 => 'Ice Skating',
    2 => 'Sky Diving',
    3 => 'Snowshoeing',
    4 => 'Snowmobiling',
    5 => 'Stand Up Paddleboarding',
    6 => 'Surfing',
    7 => 'Wakeboarding',
  }
);

my %sportBits_5 = (
  BITMASK => {
    0 => 'Water Skiing',
    1 => 'Kayaking',
    2 => 'Rafting',
    3 => 'Windsurfing',
    4 => 'Kitesurfing',
    5 => 'Tactical',
    6 => 'Jumpmaster',
    7 => 'Boxing',
  }
);

my %sportBits_6 = (
  BITMASK => {
    0 => 'Floor Climbing',
  }
);

my %subSport = (
    0 => 'Generic',
    1 => 'Treadmill',
    2 => 'Street',
    3 => 'Trail',
    4 => 'Track',
    5 => 'Spin',
    6 => 'Indoor Cycling',
    7 => 'Road',
    8 => 'Mountain',
    9 => 'Downhill',
    10 => 'Recumbent',
    11 => 'Cyclocross',
    12 => 'Hand Cycling',
    13 => 'Track Cycling',
    14 => 'Indoor Rowing',
    15 => 'Elliptical',
    16 => 'Stair Climbing',
    17 => 'Lap Swimming',
    18 => 'Open Water',
    19 => 'Flexibility Training',
    20 => 'Strength Training',
    21 => 'Warm Up',
    22 => 'Match',
    23 => 'Exercise',
    24 => 'Challenge',
    25 => 'Indoor Skiing',
    26 => 'Cardio Training',
    27 => 'Indoor Walking',
    28 => 'E-Bike Fitness',
    29 => 'Bmx',
    30 => 'Casual Walking',
    31 => 'Speed Walking',
    32 => 'Bike To Run Transition',
    33 => 'Run To Bike Transition',
    34 => 'Swim To Bike Transition',
    35 => 'Atv',
    36 => 'Motocross',
    37 => 'Backcountry',
    38 => 'Resort',
    39 => 'Rc Drone',
    40 => 'Wingsuit',
    41 => 'Whitewater',
    42 => 'Skate Skiing',
    43 => 'Yoga',
    44 => 'Pilates',
    45 => 'Indoor Running',
    46 => 'Gravel Cycling',
    47 => 'E-Bike Mountain',
    48 => 'Commuting',
    49 => 'Mixed Surface',
    50 => 'Navigate',
    51 => 'Track Me',
    52 => 'Map',
    53 => 'Single Gas Diving',
    54 => 'Multi Gas Diving',
    55 => 'Gauge Diving',
    56 => 'Apnea Diving',
    57 => 'Apnea Hunting',
    58 => 'Virtual Activity',
    59 => 'Obstacle',
    62 => 'Breathing',
    63 => 'CCR Diving',
    65 => 'Sail Race',
    66 => 'Expedition',
    67 => 'Ultra',
    68 => 'Indoor Climbing',
    69 => 'Bouldering',
    70 => 'Hiit',
    71 => 'Indoor Grinding',
    72 => 'Hunting With Dogs',
    73 => 'Amrap',
    74 => 'Emom',
    75 => 'Tabata',
    77 => 'Esport',
    78 => 'Triathlon',
    79 => 'Duathlon',
    80 => 'Brick',
    81 => 'Swim Run',
    82 => 'Adventure Race',
    83 => 'Trucker Workout',
    84 => 'Pickleball',
    85 => 'Padel',
    86 => 'Indoor Wheelchair Walk',
    87 => 'Indoor Wheelchair Run',
    88 => 'Indoor Hand Cycling',
    90 => 'Field',
    91 => 'Ice',
    92 => 'Ultimate',
    93 => 'Platform',
    94 => 'Squash',
    95 => 'Badminton',
    96 => 'Racquetball',
    97 => 'Table Tennis',
    98 => 'Overland',
    99 => 'Trolling Motor',
    110 => 'Fly Canopy',
    111 => 'Fly Paraglide',
    112 => 'Fly Paramotor',
    113 => 'Fly Pressurized',
    114 => 'Fly Navigate',
    115 => 'Fly Timer',
    116 => 'Fly Altimeter',
    117 => 'Fly Wx',
    118 => 'Fly Vfr',
    119 => 'Fly Ifr',
    121 => 'Dynamic Apnea',
    123 => 'Enduro',
    124 => 'Rucking',
    125 => 'Rally',
    126 => 'Pool Triathlon',
    127 => 'E-Bike Enduro',
    254 => 'All',
);

my %sportEvent = (
    0 => 'Uncategorized',
    1 => 'Geocaching',
    2 => 'Fitness',
    3 => 'Recreation',
    4 => 'Race',
    5 => 'Special Event',
    6 => 'Training',
    7 => 'Transportation',
    8 => 'Touring',
);

my %activityEnum = (
    0 => 'Manual',
    1 => 'Auto Multi Sport',
);

my %intensity = (
    0 => 'Active',
    1 => 'Rest',
    2 => 'Warmup',
    3 => 'Cooldown',
    4 => 'Recovery',
    5 => 'Interval',
    6 => 'Other',
);

my %sessionTrigger = (
    0 => 'Activity End',
    1 => 'Manual',
    2 => 'Auto Multi Sport',
    3 => 'Fitness Equipment',
);

my %autolapTrigger = (
    0 => 'time',
    1 => 'Distance',
    2 => 'Position Start',
    3 => 'Position Lap',
    4 => 'Position Waypoint',
    5 => 'Position Marked',
    6 => 'Off',
    13 => 'Auto Select',
);

my %lapTrigger = (
    0 => 'Manual',
    1 => 'time',
    2 => 'Distance',
    3 => 'Position Start',
    4 => 'Position Lap',
    5 => 'Position Waypoint',
    6 => 'Position Marked',
    7 => 'Session End',
    8 => 'Fitness Equipment',
);

my %timeMode = (
    0 => 'Hour12',
    1 => 'Hour24',
    2 => 'Military',
    3 => 'Hour 12 With Seconds',
    4 => 'Hour 24 With Seconds',
    5 => 'Utc',
);

my %backlightMode = (
    0 => 'Off',
    1 => 'Manual',
    2 => 'Key And Messages',
    3 => 'Auto Brightness',
    4 => 'Smart Notifications',
    5 => 'Key And Messages Night',
    6 => 'Key And Messages And Smart Notifications',
);

my %dateMode = (
    0 => 'Day Month',
    1 => 'Month Day',
);

my %backlightTimeout = (
    0 => 'Infinite',
);

my %eventEnum = (
    0 => 'Timer',
    3 => 'Workout',
    4 => 'Workout Step',
    5 => 'Power Down',
    6 => 'Power Up',
    7 => 'Off Course',
    8 => 'Session',
    9 => 'Lap',
    10 => 'Course Point',
    11 => 'Battery',
    12 => 'Virtual Partner Pace',
    13 => 'HR High Alert',
    14 => 'HR Low Alert',
    15 => 'Speed High Alert',
    16 => 'Speed Low Alert',
    17 => 'Cad High Alert',
    18 => 'Cad Low Alert',
    19 => 'Power High Alert',
    20 => 'Power Low Alert',
    21 => 'Recovery HR',
    22 => 'Battery Low',
    23 => 'Time Duration Alert',
    24 => 'Distance Duration Alert',
    25 => 'Calorie Duration Alert',
    26 => 'Activity',
    27 => 'Fitness Equipment',
    28 => 'Length',
    32 => 'User Marker',
    33 => 'Sport Point',
    36 => 'Calibration',
    39 => 'Performance Condition Alert', #4
    42 => 'Front Gear Change',
    43 => 'Rear Gear Change',
    44 => 'Rider Position Change',
    45 => 'Elev High Alert',
    46 => 'Elev Low Alert',
    47 => 'Comm Timeout',
    54 => 'Auto Activity Detect',
    56 => 'Dive Alert',
    57 => 'Dive Gas Switched',
    71 => 'Tank Pressure Reserve',
    72 => 'Tank Pressure Critical',
    73 => 'Tank Lost',
    74 => 'Sleep Event', #4
    75 => 'Radar Threat Alert',
    76 => 'Tank Battery Low',
    81 => 'Tank Pod Connected',
    82 => 'Tank Pod Disconnected',
);

my %eventType = (
    0 => 'Start',
    1 => 'Stop',
    2 => 'Consecutive Depreciated',
    3 => 'Marker',
    4 => 'Stop All',
    5 => 'Begin Depreciated',
    6 => 'End Depreciated',
    7 => 'End All Depreciated',
    8 => 'Stop Disable',
    9 => 'Stop Disable All',
);

my %timerTrigger = (
    0 => 'Manual',
    1 => 'Auto',
    2 => 'Fitness Equipment',
);

my %fitnessEquipmentState = (
    0 => 'Ready',
    1 => 'In Use',
    2 => 'Paused',
    3 => 'Unknown',
);

my %tone = (
    0 => 'Off',
    1 => 'Tone',
    2 => 'Vibrate',
    3 => 'Tone And Vibrate',
);

my %autoscroll = (
    0 => 'None',
    1 => 'Slow',
    2 => 'Medium',
    3 => 'Fast',
);

my %activityClass = (
    100 => 'Level Max',
);

my %hRZoneCalc = (
    0 => 'Custom',
    1 => 'Percent Max HR',
    2 => 'Percent HRr',
    3 => 'Percent Lthr',
);

my %pwrZoneCalc = (
    0 => 'Custom',
    1 => 'Percent Ftp',
);

my %wktStepDuration = (
    0 => 'time',
    1 => 'Distance',
    2 => 'HR Less Than',
    3 => 'HR Greater Than',
    4 => 'Calories',
    5 => 'Open',
    6 => 'Repeat Until Steps Cmplt',
    7 => 'Repeat Until Time',
    8 => 'Repeat Until Distance',
    9 => 'Repeat Until Calories',
    10 => 'Repeat Until HR Less Than',
    11 => 'Repeat Until HR Greater Than',
    12 => 'Repeat Until Power Less Than',
    13 => 'Repeat Until Power Greater Than',
    14 => 'Power Less Than',
    15 => 'Power Greater Than',
    16 => 'Training Peaks Tss',
    17 => 'Repeat Until Power Last Lap Less Than',
    18 => 'Repeat Until Max Power Last Lap Less Than',
    19 => 'Power 3s Less Than',
    20 => 'Power 10s Less Than',
    21 => 'Power 30s Less Than',
    22 => 'Power 3s Greater Than',
    23 => 'Power 10s Greater Than',
    24 => 'Power 30s Greater Than',
    25 => 'Power Lap Less Than',
    26 => 'Power Lap Greater Than',
    27 => 'Repeat Until Training Peaks Tss',
    28 => 'Repetition Time',
    29 => 'Reps',
    31 => 'Time Only',
);

my %wktStepTarget = (
    0 => 'Speed',
    1 => 'Heart Rate',
    2 => 'Open',
    3 => 'Cadence',
    4 => 'Power',
    5 => 'Grade',
    6 => 'Resistance',
    7 => 'Power 3s',
    8 => 'Power 10s',
    9 => 'Power 30s',
    10 => 'Power Lap',
    11 => 'Swim Stroke',
    12 => 'Speed Lap',
    13 => 'Heart Rate Lap',
);

my %goalEnum = (
    0 => 'time',
    1 => 'Distance',
    2 => 'Calories',
    3 => 'Frequency',
    4 => 'Steps',
    5 => 'Ascent',
    6 => 'Active Minutes',
);

my %goalRecurrence = (
    0 => 'Off',
    1 => 'Daily',
    2 => 'Weekly',
    3 => 'Monthly',
    4 => 'Yearly',
    5 => 'Custom',
);

my %goalSource = (
    0 => 'Auto',
    1 => 'Community',
    2 => 'User',
);

my %scheduleEnum = (
    0 => 'Workout',
    1 => 'Course',
);

my %coursePointEnum = (
    0 => 'Generic',
    1 => 'Summit',
    2 => 'Valley',
    3 => 'Water',
    4 => 'Food',
    5 => 'Danger',
    6 => 'Left',
    7 => 'Right',
    8 => 'Straight',
    9 => 'First Aid',
    10 => 'Fourth Category',
    11 => 'Third Category',
    12 => 'Second Category',
    13 => 'First Category',
    14 => 'Hors Category',
    15 => 'Sprint',
    16 => 'Left Fork',
    17 => 'Right Fork',
    18 => 'Middle Fork',
    19 => 'Slight Left',
    20 => 'Sharp Left',
    21 => 'Slight Right',
    22 => 'Sharp Right',
    23 => 'U Turn',
    24 => 'Segment Start',
    25 => 'Segment End',
    27 => 'Campsite',
    28 => 'Aid Station',
    29 => 'Rest Area',
    30 => 'General Distance',
    31 => 'Service',
    32 => 'Energy Gel',
    33 => 'Sports Drink',
    34 => 'Mile Marker',
    35 => 'Checkpoint',
    36 => 'Shelter',
    37 => 'Meeting Spot',
    38 => 'Overlook',
    39 => 'Toilet',
    40 => 'Shower',
    41 => 'Gear',
    42 => 'Sharp Curve',
    43 => 'Steep Incline',
    44 => 'Tunnel',
    45 => 'Bridge',
    46 => 'Obstacle',
    47 => 'Crossing',
    48 => 'Store',
    49 => 'Transition',
    50 => 'Navaid',
    51 => 'Transport',
    52 => 'Alert',
    53 => 'Info',
);

my %manufacturer = (
    1 => 'Garmin',
    2 => 'Garmin Fr405 Antfs',
    3 => 'Zephyr',
    4 => 'Dayton',
    5 => 'Idt',
    6 => 'Srm',
    7 => 'Quarq',
    8 => 'Ibike',
    9 => 'Saris',
    10 => 'Spark Hk',
    11 => 'Tanita',
    12 => 'Echowell',
    13 => 'Dynastream Oem',
    14 => 'Nautilus',
    15 => 'Dynastream',
    16 => 'Timex',
    17 => 'Metrigear',
    18 => 'Xelic',
    19 => 'Beurer',
    20 => 'Cardiosport',
    21 => 'A And D',
    22 => 'Hmm',
    23 => 'Suunto',
    24 => 'Thita Elektronik',
    25 => 'Gpulse',
    26 => 'Clean Mobile',
    27 => 'Pedal Brain',
    28 => 'Peaksware',
    29 => 'Saxonar',
    30 => 'Lemond Fitness',
    31 => 'Dexcom',
    32 => 'Wahoo Fitness',
    33 => 'Octane Fitness',
    34 => 'Archinoetics',
    35 => 'The Hurt Box',
    36 => 'Citizen Systems',
    37 => 'Magellan',
    38 => 'Osynce',
    39 => 'Holux',
    40 => 'Concept2',
    41 => 'Shimano',
    42 => 'One Giant Leap',
    43 => 'Ace Sensor',
    44 => 'Brim Brothers',
    45 => 'Xplova',
    46 => 'Perception Digital',
    47 => 'Bf1systems',
    48 => 'Pioneer',
    49 => 'Spantec',
    50 => 'Metalogics',
    51 => '4iiiis',
    52 => 'Seiko Epson',
    53 => 'Seiko Epson Oem',
    54 => 'Ifor Powell',
    55 => 'Maxwell Guider',
    56 => 'Star Trac',
    57 => 'Breakaway',
    58 => 'Alatech Technology Ltd',
    59 => 'Mio Technology Europe',
    60 => 'Rotor',
    61 => 'Geonaute',
    62 => 'Id Bike',
    63 => 'Specialized',
    64 => 'Wtek',
    65 => 'Physical Enterprises',
    66 => 'North Pole Engineering',
    67 => 'Bkool',
    68 => 'Cateye',
    69 => 'Stages Cycling',
    70 => 'Sigmasport',
    71 => 'Tomtom',
    72 => 'Peripedal',
    73 => 'Wattbike',
    76 => 'Moxy',
    77 => 'Ciclosport',
    78 => 'Powerbahn',
    79 => 'Acorn Projects Aps',
    80 => 'Lifebeam',
    81 => 'Bontrager',
    82 => 'Wellgo',
    83 => 'Scosche',
    84 => 'Magura',
    85 => 'Woodway',
    86 => 'Elite',
    87 => 'Nielsen Kellerman',
    88 => 'Dk City',
    89 => 'Tacx',
    90 => 'Direction Technology',
    91 => 'Magtonic',
    92 => '1partcarbon',
    93 => 'Inside Ride Technologies',
    94 => 'Sound Of Motion',
    95 => 'Stryd',
    96 => 'Icg',
    97 => 'MiPulse',
    98 => 'Bsx Athletics',
    99 => 'Look',
    100 => 'Campagnolo Srl',
    101 => 'Body Bike Smart',
    102 => 'Praxisworks',
    103 => 'Limits Technology',
    104 => 'Topaction Technology',
    105 => 'Cosinuss',
    106 => 'Fitcare',
    107 => 'Magene',
    108 => 'Giant Manufacturing Co',
    109 => 'Tigrasport',
    110 => 'Salutron',
    111 => 'Technogym',
    112 => 'Bryton Sensors',
    113 => 'Latitude Limited',
    114 => 'Soaring Technology',
    115 => 'Igpsport',
    116 => 'Thinkrider',
    117 => 'Gopher Sport',
    118 => 'Waterrower',
    119 => 'Orangetheory',
    120 => 'Inpeak',
    121 => 'Kinetic',
    122 => 'Johnson Health Tech',
    123 => 'Polar Electro',
    124 => 'Seesense',
    125 => 'Nci Technology',
    126 => 'IQsquare',
    127 => 'Leomo',
    128 => 'Ifit Com',
    129 => 'Coros Byte',
    130 => 'Versa Design',
    131 => 'Chileaf',
    132 => 'Cycplus',
    133 => 'Gravaa Byte',
    134 => 'Sigeyi',
    135 => 'Coospo',
    136 => 'Geoid',
    137 => 'Bosch',
    138 => 'Kyto',
    139 => 'Kinetic Sports',
    140 => 'Decathlon Byte',
    141 => 'Tq Systems',
    142 => 'Tag Heuer',
    143 => 'Keiser Fitness',
    144 => 'Zwift Byte',
    145 => 'Porsche Ep',
    146 => 'Blackbird',
    147 => 'Meilan Byte',
    148 => 'Ezon',
    149 => 'Laisi',
    150 => 'Myzone',
    151 => 'Abawo',
    152 => 'Bafang',
    153 => 'Luhong Technology',
    255 => 'Development',
    257 => 'Healthandlife',
    258 => 'Lezyne',
    259 => 'Scribe Labs',
    260 => 'Zwift',
    261 => 'Watteam',
    262 => 'Recon',
    263 => 'Favero Electronics',
    264 => 'Dynovelo',
    265 => 'Strava',
    266 => 'Precor',
    267 => 'Bryton',
    268 => 'Sram',
    269 => 'Navman',
    270 => 'Cobi',
    271 => 'Spivi',
    272 => 'Mio Magellan',
    273 => 'Evesports',
    274 => 'Sensitivus Gauge',
    275 => 'Podoon',
    276 => 'Life Time Fitness',
    277 => 'Falco E Motors',
    278 => 'Minoura',
    279 => 'Cycliq',
    280 => 'Luxottica',
    281 => 'Trainer Road',
    282 => 'The Sufferfest',
    283 => 'Fullspeedahead',
    284 => 'Virtualtraining',
    285 => 'Feedbacksports',
    286 => 'Omata',
    287 => 'Vdo',
    288 => 'Magneticdays',
    289 => 'Hammerhead',
    290 => 'Kinetic By Kurt',
    291 => 'Shapelog',
    292 => 'Dabuziduo',
    293 => 'Jetblack',
    294 => 'Coros',
    295 => 'Virtugo',
    296 => 'Velosense',
    297 => 'Cycligentinc',
    298 => 'Trailforks',
    299 => 'Mahle Ebikemotion',
    300 => 'Nurvv',
    301 => 'Microprogram',
    302 => 'Zone5cloud',
    303 => 'Greenteg',
    304 => 'Yamaha Motors',
    305 => 'Whoop',
    306 => 'Gravaa',
    307 => 'Onelap',
    308 => 'Monark Exercise',
    309 => 'Form',
    310 => 'Decathlon',
    311 => 'Syncros',
    312 => 'Heatup',
    313 => 'Cannondale',
    314 => 'True Fitness',
    315 => 'RGT Cycling',
    316 => 'Vasa',
    317 => 'Race Republic',
    318 => 'Fazua',
    319 => 'Oreka Training',
    320 => 'Lsec',
    321 => 'Lululemon Studio',
    322 => 'Shanyue',
    323 => 'Spinning Mda',
    324 => 'Hilldating',
    325 => 'Aero Sensor',
    326 => 'Nike',
    327 => 'Magicshine',
    328 => 'Ictrainer',
    329 => 'Absolute Cycling',
    330 => 'Eo Swimbetter',
    331 => 'Mywhoosh',
    332 => 'Ravemen',
    333 => 'Tektro Racing Products',
    334 => 'Darad Innovation Corporation',
    335 => 'Cycloptim',
    337 => 'Runna',
    339 => 'Zepp',
    340 => 'Peloton',
    341 => 'Carv',
    342 => 'Tissot',
    345 => 'Real Velo',
    346 => 'Wetech',
    347 => 'Jespr',
    348 => 'Huawei',
    349 => 'Gotoes',
    5759 => 'Actigraphcorp',
);

my %garminProduct = (
    1 => 'HRM1',
    2 => 'Axh01',
    3 => 'Axb01',
    4 => 'Axb02',
    5 => 'HRM2ss',
    6 => 'Dsi Alf02',
    7 => 'HRM3ss',
    8 => 'HRM Run Single Byte Product ID',
    9 => 'Bsm',
    10 => 'Bcm',
    11 => 'Axs01',
    12 => 'HRM Tri Single Byte Product ID',
    13 => 'HRM4 Run Single Byte Product ID',
    14 => 'Fr225 Single Byte Product ID',
    15 => 'Gen3 Bsm Single Byte Product ID',
    16 => 'Gen3 Bcm Single Byte Product ID',
    22 => 'HRM Fit Single Byte Product ID',
    255 => 'OHR',
    473 => 'Fr301 China',
    474 => 'Fr301 Japan',
    475 => 'Fr301 Korea',
    494 => 'Fr301 Taiwan',
    717 => 'Fr405',
    782 => 'Fr50',
    987 => 'Fr405 Japan',
    988 => 'Fr60',
    1011 => 'Dsi Alf01',
    1018 => 'Fr310xt',
    1036 => 'Edge500',
    1124 => 'Fr110',
    1169 => 'Edge800',
    1199 => 'Edge500 Taiwan',
    1213 => 'Edge500 Japan',
    1253 => 'Chirp',
    1274 => 'Fr110 Japan',
    1325 => 'Edge200',
    1328 => 'Fr910xt',
    1333 => 'Edge800 Taiwan',
    1334 => 'Edge800 Japan',
    1341 => 'Alf04',
    1345 => 'Fr610',
    1360 => 'Fr210 Japan',
    1380 => 'Vector Ss',
    1381 => 'Vector Cp',
    1386 => 'Edge800 China',
    1387 => 'Edge500 China',
    1405 => 'Approach G10',
    1410 => 'Fr610 Japan',
    1422 => 'Edge500 Korea',
    1436 => 'Fr70',
    1446 => 'Fr310xt 4t',
    1461 => 'Amx',
    1482 => 'Fr10',
    1497 => 'Edge800 Korea',
    1499 => 'Swim',
    1537 => 'Fr910xt China',
    1551 => 'Fenix',
    1555 => 'Edge200 Taiwan',
    1561 => 'Edge510',
    1567 => 'Edge810',
    1570 => 'Tempe',
    1600 => 'Fr910xt Japan',
    1619 => 'Mt3333 1', #4
    1620 => 'Mt3333 2', #4
    1621 => 'Mt3333 3', #4
    1623 => 'Fr620',
    1632 => 'Fr220',
    1664 => 'Fr910xt Korea',
    1688 => 'Fr10 Japan',
    1721 => 'Edge810 Japan',
    1735 => 'Virb Elite',
    1736 => 'Edge Touring',
    1742 => 'Edge510 Japan',
    1743 => 'HRM Tri',
    1752 => 'HRM Run',
    1765 => 'Fr920xt',
    1821 => 'Edge510 Asia',
    1822 => 'Edge810 China',
    1823 => 'Edge810 Taiwan',
    1836 => 'Edge1000',
    1837 => 'Vivo Fit',
    1853 => 'Virb Remote',
    1885 => 'Vivo Ki',
    1903 => 'Fr15',
    1907 => 'Vivo Active',
    1918 => 'Edge510 Korea',
    1928 => 'Fr620 Japan',
    1929 => 'Fr620 China',
    1930 => 'Fr220 Japan',
    1931 => 'Fr220 China',
    1936 => 'Approach S6',
    1956 => 'Vivo Smart',
    1967 => 'Fenix2',
    1988 => 'Epix',
    2050 => 'Fenix3',
    2052 => 'Edge1000 Taiwan',
    2053 => 'Edge1000 Japan',
    2061 => 'Fr15 Japan',
    2067 => 'Edge520',
    2070 => 'Edge1000 China',
    2072 => 'Fr620 Russia',
    2073 => 'Fr220 Russia',
    2079 => 'Vector S',
    2100 => 'Edge1000 Korea',
    2130 => 'Fr920xt Taiwan',
    2131 => 'Fr920xt China',
    2132 => 'Fr920xt Japan',
    2134 => 'Virbx',
    2135 => 'Vivo Smart Apac',
    2140 => 'Etrex Touch',
    2147 => 'Edge25',
    2148 => 'Fr25',
    2150 => 'Vivo Fit2',
    2153 => 'Fr225',
    2156 => 'Fr630',
    2157 => 'Fr230',
    2158 => 'Fr735xt',
    2160 => 'Vivo Active Apac',
    2161 => 'Vector 2',
    2162 => 'Vector 2s',
    2172 => 'Virbxe',
    2173 => 'Fr620 Taiwan',
    2174 => 'Fr220 Taiwan',
    2175 => 'Truswing',
    2187 => 'D2airvenu',
    2188 => 'Fenix3 China',
    2189 => 'Fenix3 Twn',
    2192 => 'Varia Headlight',
    2193 => 'Varia Taillight Old',
    2204 => 'Edge Explore 1000',
    2219 => 'Fr225 Asia',
    2225 => 'Varia Radar Taillight',
    2226 => 'Varia Radar Display',
    2238 => 'Edge20',
    2260 => 'Edge520 Asia',
    2261 => 'Edge520 Japan',
    2262 => 'D2 Bravo',
    2266 => 'Approach S20',
    2271 => 'Vivo Smart2',
    2274 => 'Edge1000 Thai',
    2276 => 'Varia Remote',
    2288 => 'Edge25 Asia',
    2289 => 'Edge25 Jpn',
    2290 => 'Edge20 Asia',
    2292 => 'Approach X40',
    2293 => 'Fenix3 Japan',
    2294 => 'Vivo Smart Emea',
    2310 => 'Fr630 Asia',
    2311 => 'Fr630 Jpn',
    2313 => 'Fr230 Jpn',
    2327 => 'HRM4 Run',
    2332 => 'Epix Japan',
    2337 => 'Vivo Active HR',
    2347 => 'Vivo Smart GPS HR',
    2348 => 'Vivo Smart HR',
    2361 => 'Vivo Smart HR Asia',
    2362 => 'Vivo Smart GPS HR Asia',
    2368 => 'Vivo Move',
    2379 => 'Varia Taillight',
    2396 => 'Fr235 Asia',
    2397 => 'Fr235 Japan',
    2398 => 'Varia Vision',
    2406 => 'Vivo Fit3',
    2407 => 'Fenix3 Korea',
    2408 => 'Fenix3 Sea',
    2413 => 'Fenix3 HR',
    2417 => 'Virb Ultra 30',
    2429 => 'Index Smart Scale',
    2431 => 'Fr235',
    2432 => 'Fenix3 Chronos',
    2441 => 'Oregon7xx',
    2444 => 'Rino7xx',
    2457 => 'Epix Korea',
    2473 => 'Fenix3 HR Chn',
    2474 => 'Fenix3 HR Twn',
    2475 => 'Fenix3 HR Jpn',
    2476 => 'Fenix3 HR Sea',
    2477 => 'Fenix3 HR Kor',
    2496 => 'Nautix',
    2497 => 'Vivo Active HR Apac',
    2503 => 'Fr35',
    2512 => 'Oregon7xx Ww',
    2530 => 'Edge 820',
    2531 => 'Edge Explore 820',
    2533 => 'Fr735xt Apac',
    2534 => 'Fr735xt Japan',
    2544 => 'Fenix5s',
    2547 => 'D2 Bravo Titanium',
    2567 => 'Varia Ut800',
    2593 => 'Running Dynamics Pod',
    2599 => 'Edge 820 China',
    2600 => 'Edge 820 Japan',
    2604 => 'Fenix5x',
    2606 => 'Vivo Fit Jr',
    2622 => 'Vivo Smart3',
    2623 => 'Vivo Sport',
    2628 => 'Edge 820 Taiwan',
    2629 => 'Edge 820 Korea',
    2630 => 'Edge 820 Sea',
    2650 => 'Fr35 Hebrew',
    2656 => 'Approach S60',
    2667 => 'Fr35 Apac',
    2668 => 'Fr35 Japan',
    2675 => 'Fenix3 Chronos Asia',
    2687 => 'Virb 360',
    2691 => 'Fr935',
    2697 => 'Fenix5',
    2700 => 'Vivoactive3',
    2713 => 'Edge 1030',
    2727 => 'Fr35 Sea',
    2733 => 'Fr235 China Nfc',
    2769 => 'Foretrex 601 701',
    2772 => 'Vivo Move HR',
    2787 => 'Vector 3',
    2796 => 'Fenix5 Asia',
    2797 => 'Fenix5s Asia',
    2798 => 'Fenix5x Asia',
    2806 => 'Approach Z80',
    2814 => 'Fr35 Korea',
    2819 => 'D2charlie',
    2831 => 'Vivo Smart3 Apac',
    2832 => 'Vivo Sport Apac',
    2833 => 'Fr935 Asia',
    2859 => 'Descent',
    2878 => 'Vivo Fit4',
    2886 => 'Fr645',
    2888 => 'Fr645m',
    2891 => 'Fr30',
    2900 => 'Fenix5s Plus',
    2909 => 'Edge 130',
    2924 => 'Edge 1030 Asia',
    2927 => 'Vivosmart 4',
    2945 => 'Vivo Move HR Asia',
    2957 => 'Mt3333 4', #4
    2962 => 'Approach X10',
    2977 => 'Fr30 Asia',
    2988 => 'Vivoactive3m W',
    3003 => 'Fr645 Asia',
    3004 => 'Fr645m Asia',
    3011 => 'Edge Explore',
    3028 => 'GPSmap66',
    3049 => 'Approach S10',
    3066 => 'Vivoactive3m L',
    3076 => 'Fr245',
    3077 => 'Fr245 Music',
    3085 => 'Approach G80',
    3092 => 'Edge 130 Asia',
    3095 => 'Edge 1030 Bontrager',
    3107 => 'Cxd5603gf', #4
    3110 => 'Fenix5 Plus',
    3111 => 'Fenix5x Plus',
    3112 => 'Edge 520 Plus',
    3113 => 'Fr945',
    3121 => 'Edge 530',
    3122 => 'Edge 830',
    3126 => 'Instinct Esports',
    3134 => 'Fenix5s Plus Apac',
    3135 => 'Fenix5x Plus Apac',
    3142 => 'Edge 520 Plus Apac',
    3143 => 'Descent T1',
    3144 => 'Fr235l Asia',
    3145 => 'Fr245 Asia',
    3163 => 'Vivo Active3m Apac',
    3192 => 'Gen3 Bsm',
    3193 => 'Gen3 Bcm',
    3218 => 'Vivo Smart4 Asia',
    3224 => 'Vivoactive4 Small',
    3225 => 'Vivoactive4 Large',
    3226 => 'Venu',
    3246 => 'Marq Driver',
    3247 => 'Marq Aviator',
    3248 => 'Marq Captain',
    3249 => 'Marq Commander',
    3250 => 'Marq Expedition',
    3251 => 'Marq Athlete',
    3258 => 'Descent Mk2',
    3282 => 'Fr45',
    3284 => 'GPSmap66i',
    3287 => 'Fenix6S Sport',
    3288 => 'Fenix6S',
    3289 => 'Fenix6 Sport',
    3290 => 'Fenix6',
    3291 => 'Fenix6x',
    3299 => 'HRM Dual',
    3300 => 'HRM Pro',
    3308 => 'Vivo Move3 Premium',
    3314 => 'Approach S40',
    3321 => 'Fr245m Asia',
    3349 => 'Edge 530 Apac',
    3350 => 'Edge 830 Apac',
    3378 => 'Vivo Move3',
    3387 => 'Vivo Active4 Small Asia',
    3388 => 'Vivo Active4 Large Asia',
    3389 => 'Vivo Active4 Oled Asia',
    3405 => 'Swim2',
    3411 => 'Mt3333 5', #4
    3420 => 'Marq Driver Asia',
    3421 => 'Marq Aviator Asia',
    3422 => 'Vivo Move3 Asia',
    3441 => 'Fr945 Asia',
    3446 => 'Vivo Active3t Chn',
    3448 => 'Marq Captain Asia',
    3449 => 'Marq Commander Asia',
    3450 => 'Marq Expedition Asia',
    3451 => 'Marq Athlete Asia',
    3461 => 'Index Smart Scale 2',
    3466 => 'Instinct Solar',
    3469 => 'Fr45 Asia',
    3473 => 'Vivoactive3 Daimler',
    3498 => 'Legacy Rey',
    3499 => 'Legacy Darth Vader',
    3500 => 'Legacy Captain Marvel',
    3501 => 'Legacy First Avenger',
    3512 => 'Fenix6s Sport Asia',
    3513 => 'Fenix6s Asia',
    3514 => 'Fenix6 Sport Asia',
    3515 => 'Fenix6 Asia',
    3516 => 'Fenix6x Asia',
    3535 => 'Legacy Captain Marvel Asia',
    3536 => 'Legacy First Avenger Asia',
    3537 => 'Legacy Rey Asia',
    3538 => 'Legacy Darth Vader Asia',
    3542 => 'Descent Mk2s',
    3558 => 'Edge 130 Plus',
    3570 => 'Edge 1030 Plus',
    3578 => 'Rally 200',
    3589 => 'Fr745',
    3596 => 'Venusq Music',
    3599 => 'Venusq Music V2',
    3600 => 'Venusq',
    3615 => 'Lily',
    3624 => 'Marq Adventurer',
    3638 => 'Enduro',
    3639 => 'Swim2 Apac',
    3648 => 'Marq Adventurer Asia',
    3652 => 'Fr945 Lte',
    3702 => 'Descent Mk2 Asia',
    3703 => 'Venu2',
    3704 => 'Venu2s',
    3737 => 'Venu Daimler Asia',
    3739 => 'Marq Golfer',
    3740 => 'Venu Daimler',
    3750 => 'Mt3333 6', #4
    3794 => 'Fr745 Asia',
    3799 => 'Cxd56xxxx 1', #4
    3808 => 'Varia Rct715',
    3809 => 'Lily Asia',
    3812 => 'Edge 1030 Plus Asia',
    3813 => 'Edge 130 Plus Asia',
    3823 => 'Approach S12',
    3837 => 'Venusq Asia',
    3843 => 'Edge 1040',
    3850 => 'Marq Golfer Asia',
    3851 => 'Venu2 Plus',
    3865 => 'Gnss',
    3866 => 'Ag3335mn', #4
    3869 => 'Fr55',
    3872 => 'Enduro Asia',
    3888 => 'Instinct 2',
    3889 => 'Instinct 2s',
    3905 => 'Fenix7s',
    3906 => 'Fenix7',
    3907 => 'Fenix7x',
    3908 => 'Fenix7s Apac',
    3909 => 'Fenix7 Apac',
    3910 => 'Fenix7x Apac',
    3927 => 'Approach G12',
    3930 => 'Descent Mk2s Asia',
    3934 => 'Approach S42',
    3943 => 'Epix Gen2',
    3944 => 'Epix Gen2 Apac',
    3949 => 'Venu2s Asia',
    3950 => 'Venu2 Asia',
    3978 => 'Fr945 Lte Asia',
    3982 => 'Vivo Move Sport',
    3983 => 'Vivomove Trend',
    3986 => 'Approach S12 Asia',
    3990 => 'Fr255 Music',
    3991 => 'Fr255 Small Music',
    3992 => 'Fr255',
    3993 => 'Fr255 Small',
    4001 => 'Approach G12 Asia',
    4002 => 'Approach S42 Asia',
    4005 => 'Descent G1',
    4017 => 'Venu2 Plus Asia',
    4024 => 'Fr955',
    4033 => 'Fr55 Asia',
    4058 => 'Cxd56xxxx 2', #4
    4061 => 'Edge 540',
    4062 => 'Edge 840',
    4063 => 'Vivosmart 5',
    4071 => 'Instinct 2 Asia',
    4105 => 'Marq Gen2',
    4115 => 'Venusq2',
    4116 => 'Venusq2music',
    4124 => 'Marq Gen2 Aviator',
    4125 => 'D2 Air X10',
    4130 => 'HRM Pro Plus',
    4132 => 'Descent G1 Asia',
    4135 => 'Tactix7',
    4155 => 'Instinct Crossover',
    4169 => 'Edge Explore2',
    4197 => 'Cxd56xxxx 3', #4
    4222 => 'Descent Mk3',
    4223 => 'Descent Mk3i',
    4233 => 'Approach S70',
    4257 => 'Fr265 Large',
    4258 => 'Fr265 Small',
    4260 => 'Venu3',
    4261 => 'Venu3s',
    4265 => 'Tacx Neo Smart',
    4266 => 'Tacx Neo2 Smart',
    4267 => 'Tacx Neo2 T Smart',
    4268 => 'Tacx Neo Smart Bike',
    4269 => 'Tacx Satori Smart',
    4270 => 'Tacx Flow Smart',
    4271 => 'Tacx Vortex Smart',
    4272 => 'Tacx Bushido Smart',
    4273 => 'Tacx Genius Smart',
    4274 => 'Tacx Flux Flux S Smart',
    4275 => 'Tacx Flux2 Smart',
    4276 => 'Tacx Magnum',
    4305 => 'Edge 1040 Asia',
    4312 => 'Epix Gen2 Pro 42',
    4313 => 'Epix Gen2 Pro 47',
    4314 => 'Epix Gen2 Pro 51',
    4315 => 'Fr965',
    4341 => 'Enduro2',
    4374 => 'Fenix7s Pro Solar',
    4375 => 'Fenix7 Pro Solar',
    4376 => 'Fenix7x Pro Solar',
    4380 => 'Lily2',
    4394 => 'Instinct 2x',
    4426 => 'Vivoactive5',
    4432 => 'Fr165',
    4433 => 'Fr165 Music',
    4440 => 'Edge 1050',
    4442 => 'Descent T2',
    4446 => 'HRM Fit',
    4472 => 'Marq Gen2 Commander',
    4477 => 'Lily Athlete',
    4525 => 'Rally X10',
    4532 => 'Fenix8 Solar',
    4533 => 'Fenix8 Solar Large',
    4534 => 'Fenix8 Small',
    4536 => 'Fenix8',
    4556 => 'D2 Mach1 Pro',
    4565 => 'Fr970', #4
    4575 => 'Enduro3',
    4583 => 'InstinctE 40mm',
    4584 => 'InstinctE 45mm',
    4585 => 'Instinct3 Solar 45mm',
    4586 => 'Instinct3 Amoled 45mm',
    4587 => 'Instinct3 Amoled 50mm',
    4588 => 'Descent G2',
    4603 => 'Venu X1',
    4606 => 'HRM 200',
    4607 => 'HRM 600', #4
    4625 => 'Vivoactive6',
    4631 => 'Fenix8 Pro',
    4633 => 'Edge 550',
    4634 => 'Edge 850',
    4643 => 'Venu4',
    4644 => 'Venu4s',
    4647 => 'ApproachS44',
    4655 => 'Edge Mtb',
    4656 => 'ApproachS50',
    4666 => 'Fenix E',
    4678 => 'Instinct Crossover Amoled',
    4745 => 'Bounce2',
    4759 => 'Instinct3 Solar 50mm',
    4775 => 'Tactix8 Amoled',
    4776 => 'Tactix8 Solar',
    4825 => 'Approach J1',
    4879 => 'D2 Mach2',
    4944 => 'D2 Air X15',
    10007 => 'SDM4',
    10014 => 'Edge Remote',
    20119 => 'Training Center',
    20533 => 'Tacx Training App Win',
    20534 => 'Tacx Training App Mac',
    20565 => 'Tacx Training App Mac Catalyst',
    30045 => 'Tacx Training App Android',
    30046 => 'Tacx Training App Ios',
    30047 => 'Tacx Training App Legacy',
    65531 => 'Connectiq Simulator',
    65532 => 'Android Antplus Plugin',
    65534 => 'Connect',
);

my %antplusDeviceType = (
    1 => 'Antfs',
    11 => 'Bike Power',
    12 => 'Environment Sensor Legacy',
    15 => 'Multi Sport Speed Distance',
    16 => 'Control',
    17 => 'Fitness Equipment',
    18 => 'Blood Pressure',
    19 => 'Geocache Node',
    20 => 'Light Electric Vehicle',
    25 => 'Env Sensor',
    26 => 'Racquet',
    27 => 'Control Hub',
    30 => 'Running Dynamics', #4
    31 => 'Muscle Oxygen',
    34 => 'Shifting',
    35 => 'Bike Light Main',
    36 => 'Bike Light Shared',
    38 => 'Exd',
    40 => 'Bike Radar',
    46 => 'Bike Aero',
    119 => 'Weight Scale',
    120 => 'Heart Rate',
    121 => 'Bike Speed Cadence',
    122 => 'Bike Cadence',
    123 => 'Bike Speed',
    124 => 'Stride Speed Distance',
);

my %antNetwork = (
    0 => 'Public',
    1 => 'Antplus',
    2 => 'Antfs',
    3 => 'Private',
);

my %workoutCapabilities = (
  BITMASK => {
    0 => 'Interval',
    1 => 'Custom',
    2 => 'Fitness Equipment',
    3 => 'Firstbeat',
    4 => 'New Leaf',
    5 => 'Tcx',
    7 => 'Speed',
    8 => 'Heart Rate',
    9 => 'Distance',
    10 => 'Cadence',
    11 => 'Power',
    12 => 'Grade',
    13 => 'Resistance',
    14 => 'Protected',
  }
);

my %batteryStatus = (
    1 => 'New',
    2 => 'Good',
    3 => 'Ok',
    4 => 'Low',
    5 => 'Critical',
    6 => 'Charging',
    7 => 'Unknown',
);

my %hRType = (
    0 => 'Normal',
    1 => 'Irregular',
);

my %courseCapabilities = (
  BITMASK => {
    0 => 'Processed',
    1 => 'Valid',
    2 => 'time',
    3 => 'Distance',
    4 => 'Position',
    5 => 'Heart Rate',
    6 => 'Power',
    7 => 'Cadence',
    8 => 'Training',
    9 => 'Navigation',
    10 => 'Bikeway',
    12 => 'Aviation',
  }
);

my %workoutHR = (
    100 => 'Bpm Offset',
);

my %workoutPower = (
    1000 => 'Watts Offset',
);

my %bpStatus = (
    0 => 'No Error',
    1 => 'Error Incomplete Data',
    2 => 'Error No Measurement',
    3 => 'Error Data Out Of Range',
    4 => 'Error Irregular Heart Rate',
);

my %swimStroke = (
    0 => 'Freestyle',
    1 => 'Backstroke',
    2 => 'Breaststroke',
    3 => 'Butterfly',
    4 => 'Drill',
    5 => 'Mixed',
    6 => 'Im',
    7 => 'Im By Round',
    8 => 'Rimo',
);

my %activityType = (
    0 => 'Generic',
    1 => 'Running',
    2 => 'Cycling',
    3 => 'Transition',
    4 => 'Fitness Equipment',
    5 => 'Swimming',
    6 => 'Walking',
    8 => 'Sedentary',
    254 => 'All',
);

my %activitySubtype = (
    0 => 'Generic',
    1 => 'Treadmill',
    2 => 'Street',
    3 => 'Trail',
    4 => 'Track',
    5 => 'Spin',
    6 => 'Indoor Cycling',
    7 => 'Road',
    8 => 'Mountain',
    9 => 'Downhill',
    10 => 'Recumbent',
    11 => 'Cyclocross',
    12 => 'Hand Cycling',
    13 => 'Track Cycling',
    14 => 'Indoor Rowing',
    15 => 'Elliptical',
    16 => 'Stair Climbing',
    17 => 'Lap Swimming',
    18 => 'Open Water',
    254 => 'All',
);

my %activityLevel = (
    0 => 'Low',
    1 => 'Medium',
    2 => 'High',
);

my %side = (
    0 => 'Right',
    1 => 'Left',
);

my %lengthType = (
    0 => 'Idle',
    1 => 'Active',
);

my %dayOfWeek = (
    0 => 'Sunday',
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
);

my %connectivityCapabilities = (
  BITMASK => {
    0 => 'Bluetooth',
    1 => 'Bluetooth Le',
    2 => 'Ant',
    3 => 'Activity Upload',
    4 => 'Course Download',
    5 => 'Workout Download',
    6 => 'Live Track',
    7 => 'Weather Conditions',
    8 => 'Weather Alerts',
    9 => 'GPS Ephemeris Download',
    10 => 'Explicit Archive',
    11 => 'Setup Incomplete',
    12 => 'Continue Sync After Software Update',
    13 => 'Connect IQ App Download',
    14 => 'Golf Course Download',
    15 => 'Device Initiates Sync',
    16 => 'Connect IQ Watch App Download',
    17 => 'Connect IQ Widget Download',
    18 => 'Connect IQ Watch Face Download',
    19 => 'Connect IQ Data Field Download',
    20 => 'Connect IQ App Managment',
    21 => 'Swing Sensor',
    22 => 'Swing Sensor Remote',
    23 => 'Incident Detection',
    24 => 'Audio Prompts',
    25 => 'Wifi Verification',
    26 => 'True Up',
    27 => 'Find My Watch',
    28 => 'Remote Manual Sync',
    29 => 'Live Track Auto Start',
    30 => 'Live Track Messaging',
    31 => 'Instant Input',
  }
);

my %weatherReport = (
    0 => 'Current',
    1 => 'Hourly Forecast',
    2 => 'Daily Forecast',
);

my %weatherStatus = (
    0 => 'Clear',
    1 => 'Partly Cloudy',
    2 => 'Mostly Cloudy',
    3 => 'Rain',
    4 => 'Snow',
    5 => 'Windy',
    6 => 'Thunderstorms',
    7 => 'Wintry Mix',
    8 => 'Fog',
    11 => 'Hazy',
    12 => 'Hail',
    13 => 'Scattered Showers',
    14 => 'Scattered Thunderstorms',
    15 => 'Unknown Precipitation',
    16 => 'Light Rain',
    17 => 'Heavy Rain',
    18 => 'Light Snow',
    19 => 'Heavy Snow',
    20 => 'Light Rain Snow',
    21 => 'Heavy Rain Snow',
    22 => 'Cloudy',
);

my %weatherSeverity = (
    0 => 'Unknown',
    1 => 'Warning',
    2 => 'Watch',
    3 => 'Advisory',
    4 => 'Statement',
);

my %weatherSevereType = (
    0 => 'Unspecified',
    1 => 'Tornado',
    2 => 'Tsunami',
    3 => 'Hurricane',
    4 => 'Extreme Wind',
    5 => 'Typhoon',
    6 => 'Inland Hurricane',
    7 => 'Hurricane Force Wind',
    8 => 'Waterspout',
    9 => 'Severe Thunderstorm',
    10 => 'Wreckhouse Winds',
    11 => 'Les Suetes Wind',
    12 => 'Avalanche',
    13 => 'Flash Flood',
    14 => 'Tropical Storm',
    15 => 'Inland Tropical Storm',
    16 => 'Blizzard',
    17 => 'Ice Storm',
    18 => 'Freezing Rain',
    19 => 'Debris Flow',
    20 => 'Flash Freeze',
    21 => 'Dust Storm',
    22 => 'High Wind',
    23 => 'Winter Storm',
    24 => 'Heavy Freezing Spray',
    25 => 'Extreme Cold',
    26 => 'Wind Chill',
    27 => 'Cold Wave',
    28 => 'Heavy Snow Alert',
    29 => 'Lake Effect Blowing Snow',
    30 => 'Snow Squall',
    31 => 'Lake Effect Snow',
    32 => 'Winter Weather',
    33 => 'Sleet',
    34 => 'Snowfall',
    35 => 'Snow And Blowing Snow',
    36 => 'Blowing Snow',
    37 => 'Snow Alert',
    38 => 'Arctic Outflow',
    39 => 'Freezing Drizzle',
    40 => 'Storm',
    41 => 'Storm Surge',
    42 => 'Rainfall',
    43 => 'Areal Flood',
    44 => 'Coastal Flood',
    45 => 'Lakeshore Flood',
    46 => 'Excessive Heat',
    47 => 'Heat',
    48 => 'Weather',
    49 => 'High Heat And Humidity',
    50 => 'Humidex And Health',
    51 => 'Humidex',
    52 => 'Gale',
    53 => 'Freezing Spray',
    54 => 'Special Marine',
    55 => 'Squall',
    56 => 'Strong Wind',
    57 => 'Lake Wind',
    58 => 'Marine Weather',
    59 => 'Wind',
    60 => 'Small Craft Hazardous Seas',
    61 => 'Hazardous Seas',
    62 => 'Small Craft',
    63 => 'Small Craft Winds',
    64 => 'Small Craft Rough Bar',
    65 => 'High Water Level',
    66 => 'Ashfall',
    67 => 'Freezing Fog',
    68 => 'Dense Fog',
    69 => 'Dense Smoke',
    70 => 'Blowing Dust',
    71 => 'Hard Freeze',
    72 => 'Freeze',
    73 => 'Frost',
    74 => 'Fire Weather',
    75 => 'Flood',
    76 => 'Rip Tide',
    77 => 'High Surf',
    78 => 'Smog',
    79 => 'Air Quality',
    80 => 'Brisk Wind',
    81 => 'Air Stagnation',
    82 => 'Low Water',
    83 => 'Hydrological',
    84 => 'Special Weather',
);

my %strokeType = (
    0 => 'No Event',
    1 => 'Other',
    2 => 'Serve',
    3 => 'Forehand',
    4 => 'Backhand',
    5 => 'Smash',
);

my %bodyLocation = (
    0 => 'Left Leg',
    1 => 'Left Calf',
    2 => 'Left Shin',
    3 => 'Left Hamstring',
    4 => 'Left Quad',
    5 => 'Left Glute',
    6 => 'Right Leg',
    7 => 'Right Calf',
    8 => 'Right Shin',
    9 => 'Right Hamstring',
    10 => 'Right Quad',
    11 => 'Right Glute',
    12 => 'Torso Back',
    13 => 'Left Lower Back',
    14 => 'Left Upper Back',
    15 => 'Right Lower Back',
    16 => 'Right Upper Back',
    17 => 'Torso Front',
    18 => 'Left Abdomen',
    19 => 'Left Chest',
    20 => 'Right Abdomen',
    21 => 'Right Chest',
    22 => 'Left Arm',
    23 => 'Left Shoulder',
    24 => 'Left Bicep',
    25 => 'Left Tricep',
    26 => 'Left Brachioradialis',
    27 => 'Left Forearm Extensors',
    28 => 'Right Arm',
    29 => 'Right Shoulder',
    30 => 'Right Bicep',
    31 => 'Right Tricep',
    32 => 'Right Brachioradialis',
    33 => 'Right Forearm Extensors',
    34 => 'Neck',
    35 => 'Throat',
    36 => 'Waist Mid Back',
    37 => 'Waist Front',
    38 => 'Waist Left',
    39 => 'Waist Right',
);

my %segmentLapStatus = (
    0 => 'End',
    1 => 'Fail',
);

my %segmentLeaderboardType = (
    0 => 'Overall',
    1 => 'Personal Best',
    2 => 'Connections',
    3 => 'Group',
    4 => 'Challenger',
    5 => 'Kom',
    6 => 'Qom',
    7 => 'Pr',
    8 => 'Goal',
    9 => 'Carrot',
    10 => 'Club Leader',
    11 => 'Rival',
    12 => 'Last',
    13 => 'Recent Best',
    14 => 'Course Record',
);

my %segmentDeleteStatus = (
    0 => 'Do Not Delete',
    1 => 'Delete One',
    2 => 'Delete All',
);

my %segmentSelectionType = (
    0 => 'Starred',
    1 => 'Suggested',
);

my %sourceType = (
    0 => 'Ant',
    1 => 'Antplus',
    2 => 'Bluetooth',
    3 => 'Bluetooth Low Energy',
    4 => 'Wifi',
    5 => 'Local',
);

my %localDeviceType = (
    0 => 'GPS',
    1 => 'Glonass',
    2 => 'GPS Glonass',
    3 => 'Accelerometer',
    4 => 'Barometer',
    5 => 'Temperature',
    10 => 'Whr',
    12 => 'Sensor Hub',
);

my %bleDeviceType = (
    0 => 'Connected GPS',
    1 => 'Heart Rate',
    2 => 'Bike Power',
    3 => 'Bike Speed Cadence',
    4 => 'Bike Speed',
    5 => 'Bike Cadence',
    6 => 'Footpod',
    7 => 'Bike Trainer',
);

my %displayOrientation = (
    0 => 'Auto',
    1 => 'Portrait',
    2 => 'Landscape',
    3 => 'Portrait Flipped',
    4 => 'Landscape Flipped',
);

my %workoutEquipment = (
    0 => 'None',
    1 => 'Swim Fins',
    2 => 'Swim Kickboard',
    3 => 'Swim Paddles',
    4 => 'Swim Pull Buoy',
    5 => 'Swim Snorkel',
);

my %watchfaceMode = (
    0 => 'Digital',
    1 => 'Analog',
    2 => 'Connect IQ',
    3 => 'Disabled',
);

my %digitalWatchfaceLayout = (
    0 => 'Traditional',
    1 => 'Modern',
    2 => 'Bold',
);

my %analogWatchfaceLayout = (
    0 => 'Minimal',
    1 => 'Traditional',
    2 => 'Modern',
);

my %riderPositionType = (
    0 => 'Seated',
    1 => 'Standing',
    2 => 'Transition To Seated',
    3 => 'Transition To Standing',
);

my %powerPhaseType = (
    0 => 'Power Phase Start Angle',
    1 => 'Power Phase End Angle',
    2 => 'Power Phase Arc Length',
    3 => 'Power Phase Center',
);

my %cameraEventType = (
    0 => 'Video Start',
    1 => 'Video Split',
    2 => 'Video End',
    3 => 'Photo Taken',
    4 => 'Video Second Stream Start',
    5 => 'Video Second Stream Split',
    6 => 'Video Second Stream End',
    7 => 'Video Split Start',
    8 => 'Video Second Stream Split Start',
    11 => 'Video Pause',
    12 => 'Video Second Stream Pause',
    13 => 'Video Resume',
    14 => 'Video Second Stream Resume',
);

my %sensorType = (
    0 => 'Accelerometer',
    1 => 'Gyroscope',
    2 => 'Compass',
    3 => 'Barometer',
    4 => 'Speed', #4
    5 => 'Speed Cadence', #4
    6 => 'Tempe', #4
    8 => 'Shimano Di2', #4
    10 => 'Edge Remote', #4
    12 => 'Smart Trainer', #4
    13 => 'Lights', #4
    14 => 'Radar', #4
    15 => 'Extended Display', #4
    16 => 'Shifting', #4
    17 => 'Muscle O2', #4
    18 => 'Rd Pod', #4
    22 => 'Headphones', #4
    28 => 'Tank Pressure', #4
);

my %bikeLightNetworkConfigType = (
    0 => 'Auto',
    4 => 'Individual',
    5 => 'High Visibility',
    6 => 'Trail',
);

my %commTimeoutType = (
    0 => 'Wildcard Pairing Timeout',
    1 => 'Pairing Timeout',
    2 => 'Connection Lost',
    3 => 'Connection Timeout',
);

my %cameraOrientationType = (
    0 => 'Camera Orientation 0',
    1 => 'Camera Orientation 90',
    2 => 'Camera Orientation 180',
    3 => 'Camera Orientation 270',
);

my %attitudeStage = (
    0 => 'Failed',
    1 => 'Aligning',
    2 => 'Degraded',
    3 => 'Valid',
);

my %attitudeValidity = (
  BITMASK => {
    0 => 'Track Angle Heading Valid',
    1 => 'Pitch Valid',
    2 => 'Roll Valid',
    3 => 'Lateral Body Accel Valid',
    4 => 'Normal Body Accel Valid',
    5 => 'Turn Rate Valid',
    6 => 'Hw Fail',
    7 => 'Mag Invalid',
    8 => 'No GPS',
    9 => 'GPS Invalid',
    10 => 'Solution Coasting',
    11 => 'True Track Angle',
    12 => 'Magnetic Heading',
  }
);

my %autoSyncFrequency = (
    0 => 'Never',
    1 => 'Occasionally',
    2 => 'Frequent',
    3 => 'Once A Day',
    4 => 'Remote',
);

my %exdLayout = (
    0 => 'Full Screen',
    1 => 'Half Vertical',
    2 => 'Half Horizontal',
    3 => 'Half Vertical Right Split',
    4 => 'Half Horizontal Bottom Split',
    5 => 'Full Quarter Split',
    6 => 'Half Vertical Left Split',
    7 => 'Half Horizontal Top Split',
    8 => 'Dynamic',
);

my %exdDisplayType = (
    0 => 'Numerical',
    1 => 'Simple',
    2 => 'Graph',
    3 => 'Bar',
    4 => 'Circle Graph',
    5 => 'Virtual Partner',
    6 => 'Balance',
    7 => 'String List',
    8 => 'String',
    9 => 'Simple Dynamic Icon',
    10 => 'Gauge',
);

my %exdDataUnits = (
    0 => 'No Units',
    1 => 'laps',
    2 => 'mph',
    3 => 'km/h',
    4 => 'ft/h',
    5 => 'm/h',
    6 => 'C',
    7 => 'F',
    8 => 'Zone',
    9 => 'Gear',
    10 => 'RPM',
    11 => 'BPM',
    12 => 'degrees',
    13 => 'mm',
    14 => 'm',
    15 => 'km',
    16 => 'ft',
    17 => 'yards',
    18 => 'kilofeet',
    19 => 'miles',
    20 => 'time',
    21 => 'Enum Turn Type',
    22 => '%',
    23 => 'W',
    24 => 'W/kg',
    25 => 'Enum Battery Status',
    26 => 'Enum Bike Light Beam Angle Mode',
    27 => 'Enum Bike Light Battery Status',
    28 => 'Enum Bike Light Network Config Type',
    29 => 'Lights',
    30 => 's',
    31 => 'minutes',
    32 => 'hours',
    33 => 'Calories',
    34 => 'kJ',
    35 => 'ms',
    36 => 's/mile',
    37 => 's/km',
    38 => 'cm',
    39 => 'Enum Course Point',
    40 => 'bradians',
    41 => 'Enum Sport',
    42 => 'inches Hg',
    43 => 'mm Hg',
    44 => 'mbar',
    45 => 'hPa',
    46 => 'ft/min',
    47 => 'm/min',
    48 => 'm/s',
    49 => 'Eight Cardinal',
);

my %exdQualifiers = (
    0 => 'No Qualifier',
    1 => 'Instantaneous',
    2 => 'Average',
    3 => 'Lap',
    4 => 'Maximum',
    5 => 'Maximum Average',
    6 => 'Maximum Lap',
    7 => 'Last Lap',
    8 => 'Average Lap',
    9 => 'To Destination',
    10 => 'To Go',
    11 => 'To Next',
    12 => 'Next Course Point',
    13 => 'Total',
    14 => 'Three Second Average',
    15 => 'Ten Second Average',
    16 => 'Thirty Second Average',
    17 => 'Percent Maximum',
    18 => 'Percent Maximum Average',
    19 => 'Lap Percent Maximum',
    20 => 'Elapsed',
    21 => 'Sunrise',
    22 => 'Sunset',
    23 => 'Compared To Virtual Partner',
    24 => 'Maximum 24h',
    25 => 'Minimum 24h',
    26 => 'Minimum',
    27 => 'First',
    28 => 'Second',
    29 => 'Third',
    30 => 'Shifter',
    31 => 'Last Sport',
    32 => 'Moving',
    33 => 'Stopped',
    34 => 'Estimated Total',
    242 => 'Zone 9',
    243 => 'Zone 8',
    244 => 'Zone 7',
    245 => 'Zone 6',
    246 => 'Zone 5',
    247 => 'Zone 4',
    248 => 'Zone 3',
    249 => 'Zone 2',
    250 => 'Zone 1',
);

my %exdDescriptors = (
    0 => 'Bike Light Battery Status',
    1 => 'Beam Angle Status',
    2 => 'Batery Level',
    3 => 'Light Network Mode',
    4 => 'Number Lights Connected',
    5 => 'Cadence',
    6 => 'Distance',
    7 => 'Estimated Time Of Arrival',
    8 => 'Heading',
    9 => 'time',
    10 => 'Battery Level',
    11 => 'Trainer Resistance',
    12 => 'Trainer Target Power',
    13 => 'Time Seated',
    14 => 'Time Standing',
    15 => 'Elevation',
    16 => 'Grade',
    17 => 'Ascent',
    18 => 'Descent',
    19 => 'Vertical Speed',
    20 => 'Di2 Battery Level',
    21 => 'Front Gear',
    22 => 'Rear Gear',
    23 => 'Gear Ratio',
    24 => 'Heart Rate',
    25 => 'Heart Rate Zone',
    26 => 'Time In Heart Rate Zone',
    27 => 'Heart Rate Reserve',
    28 => 'Calories',
    29 => 'GPS Accuracy',
    30 => 'GPS Signal Strength',
    31 => 'Temperature',
    32 => 'Time Of Day',
    33 => 'Balance',
    34 => 'Pedal Smoothness',
    35 => 'Power',
    36 => 'Functional Threshold Power',
    37 => 'Intensity Factor',
    38 => 'Work',
    39 => 'Power Ratio',
    40 => 'Normalized Power',
    41 => 'Training Stress Score',
    42 => 'Time On Zone',
    43 => 'Speed',
    44 => 'laps',
    45 => 'Reps',
    46 => 'Workout Step',
    47 => 'Course Distance',
    48 => 'Navigation Distance',
    49 => 'Course Estimated Time Of Arrival',
    50 => 'Navigation Estimated Time Of Arrival',
    51 => 'Course Time',
    52 => 'Navigation Time',
    53 => 'Course Heading',
    54 => 'Navigation Heading',
    55 => 'Power Zone',
    56 => 'Torque Effectiveness',
    57 => 'Timer Time',
    58 => 'Power Weight Ratio',
    59 => 'Left Platform Center Offset',
    60 => 'Right Platform Center Offset',
    61 => 'Left Power Phase Start Angle',
    62 => 'Right Power Phase Start Angle',
    63 => 'Left Power Phase Finish Angle',
    64 => 'Right Power Phase Finish Angle',
    65 => 'Gears',
    66 => 'Pace',
    67 => 'Training Effect',
    68 => 'Vertical Oscillation',
    69 => 'Vertical Ratio',
    70 => 'Ground Contact Time',
    71 => 'Left Ground Contact Time Balance',
    72 => 'Right Ground Contact Time Balance',
    73 => 'Stride Length',
    74 => 'Running Cadence',
    75 => 'Performance Condition',
    76 => 'Course Type',
    77 => 'Time In Power Zone',
    78 => 'Navigation Turn',
    79 => 'Course Location',
    80 => 'Navigation Location',
    81 => 'Compass',
    82 => 'Gear Combo',
    83 => 'Muscle Oxygen',
    84 => 'Icon',
    85 => 'Compass Heading',
    86 => 'GPS Heading',
    87 => 'GPS Elevation',
    88 => 'Anaerobic Training Effect',
    89 => 'Course',
    90 => 'Off Course',
    91 => 'Glide Ratio',
    92 => 'Vertical Distance',
    93 => 'Vmg',
    94 => 'Ambient Pressure',
    95 => 'Pressure',
    96 => 'Vam',
);

my %supportedExdScreenLayouts = (
  BITMASK => {
    0 => 'Full Screen',
    1 => 'Half Vertical',
    2 => 'Half Horizontal',
    3 => 'Half Vertical Right Split',
    4 => 'Half Horizontal Bottom Split',
    5 => 'Full Quarter Split',
    6 => 'Half Vertical Left Split',
    7 => 'Half Horizontal Top Split',
  }
);

my %fitBaseType = (
    0 => 'enum',
    1 => 'sint8',
    2 => 'uint8',
    7 => 'string',
    10 => 'uint8z',
    13 => 'byte',
    131 => 'sint16',
    132 => 'uint16',
    133 => 'sint32',
    134 => 'uint32',
    136 => 'float32',
    137 => 'float64',
    139 => 'uint16z',
    140 => 'uint32z',
    142 => 'sint64',
    143 => 'uint64',
    144 => 'uint64z',
);

my %turnType = (
    0 => 'Arriving Idx',
    1 => 'Arriving Left Idx',
    2 => 'Arriving Right Idx',
    3 => 'Arriving Via Idx',
    4 => 'Arriving Via Left Idx',
    5 => 'Arriving Via Right Idx',
    6 => 'Bear Keep Left Idx',
    7 => 'Bear Keep Right Idx',
    8 => 'Continue Idx',
    9 => 'Exit Left Idx',
    10 => 'Exit Right Idx',
    11 => 'Ferry Idx',
    12 => 'Roundabout 45 Idx',
    13 => 'Roundabout 90 Idx',
    14 => 'Roundabout 135 Idx',
    15 => 'Roundabout 180 Idx',
    16 => 'Roundabout 225 Idx',
    17 => 'Roundabout 270 Idx',
    18 => 'Roundabout 315 Idx',
    19 => 'Roundabout 360 Idx',
    20 => 'Roundabout Neg 45 Idx',
    21 => 'Roundabout Neg 90 Idx',
    22 => 'Roundabout Neg 135 Idx',
    23 => 'Roundabout Neg 180 Idx',
    24 => 'Roundabout Neg 225 Idx',
    25 => 'Roundabout Neg 270 Idx',
    26 => 'Roundabout Neg 315 Idx',
    27 => 'Roundabout Neg 360 Idx',
    28 => 'Roundabout Generic Idx',
    29 => 'Roundabout Neg Generic Idx',
    30 => 'Sharp Turn Left Idx',
    31 => 'Sharp Turn Right Idx',
    32 => 'Turn Left Idx',
    33 => 'Turn Right Idx',
    34 => 'Uturn Left Idx',
    35 => 'Uturn Right Idx',
    36 => 'Icon Inv Idx',
    37 => 'Icon Idx Cnt',
);

my %bikeLightBeamAngleMode = (
    0 => 'Manual',
    1 => 'Auto',
);

my %fitBaseUnit = (
    0 => 'Other',
    1 => 'Kilogram',
    2 => 'Pound',
);

my %setType = (
    0 => 'Rest',
    1 => 'Active',
);

my %maxMetCategory = (
    0 => 'Generic',
    1 => 'Cycling',
);

my %exerciseCategory = (
    0 => 'Bench Press',
    1 => 'Calf Raise',
    2 => 'Cardio',
    3 => 'Carry',
    4 => 'Chop',
    5 => 'Core',
    6 => 'Crunch',
    7 => 'Curl',
    8 => 'Deadlift',
    9 => 'Flye',
    10 => 'Hip Raise',
    11 => 'Hip Stability',
    12 => 'Hip Swing',
    13 => 'Hyperextension',
    14 => 'Lateral Raise',
    15 => 'Leg Curl',
    16 => 'Leg Raise',
    17 => 'Lunge',
    18 => 'Olympic Lift',
    19 => 'Plank',
    20 => 'Plyo',
    21 => 'Pull Up',
    22 => 'Push Up',
    23 => 'Row',
    24 => 'Shoulder Press',
    25 => 'Shoulder Stability',
    26 => 'Shrug',
    27 => 'Sit Up',
    28 => 'Squat',
    29 => 'Total Body',
    30 => 'Triceps Extension',
    31 => 'Warm Up',
    32 => 'Run',
    33 => 'Bike',
    34 => 'Cardio Sensors',
    35 => 'Move',
    36 => 'Pose',
    37 => 'Banded Exercises',
    38 => 'Battle Rope',
    39 => 'Elliptical',
    40 => 'Floor Climb',
    41 => 'Indoor Bike',
    42 => 'Indoor Row',
    43 => 'Ladder',
    44 => 'Sandbag',
    45 => 'Sled',
    46 => 'Sledge Hammer',
    47 => 'Stair Stepper',
    49 => 'Suspension',
    50 => 'Tire',
    52 => 'Run Indoor',
    53 => 'Bike Outdoor',
    65534 => 'Unknown',
);

my %benchPressExerciseName = (
    0 => 'Alternating Dumbbell Chest Press On Swiss Ball',
    1 => 'Barbell Bench Press',
    2 => 'Barbell Board Bench Press',
    3 => 'Barbell Floor Press',
    4 => 'Close Grip Barbell Bench Press',
    5 => 'Decline Dumbbell Bench Press',
    6 => 'Dumbbell Bench Press',
    7 => 'Dumbbell Floor Press',
    8 => 'Incline Barbell Bench Press',
    9 => 'Incline Dumbbell Bench Press',
    10 => 'Incline Smith Machine Bench Press',
    11 => 'Isometric Barbell Bench Press',
    12 => 'Kettlebell Chest Press',
    13 => 'Neutral Grip Dumbbell Bench Press',
    14 => 'Neutral Grip Dumbbell Incline Bench Press',
    15 => 'One Arm Floor Press',
    16 => 'Weighted One Arm Floor Press',
    17 => 'Partial Lockout',
    18 => 'Reverse Grip Barbell Bench Press',
    19 => 'Reverse Grip Incline Bench Press',
    20 => 'Single Arm Cable Chest Press',
    21 => 'Single Arm Dumbbell Bench Press',
    22 => 'Smith Machine Bench Press',
    23 => 'Swiss Ball Dumbbell Chest Press',
    24 => 'Triple Stop Barbell Bench Press',
    25 => 'Wide Grip Barbell Bench Press',
    26 => 'Alternating Dumbbell Chest Press',
);

my %calfRaiseExerciseName = (
    0 => '3 Way Calf Raise',
    1 => '3 Way Weighted Calf Raise',
    2 => '3 Way Single Leg Calf Raise',
    3 => '3 Way Weighted Single Leg Calf Raise',
    4 => 'Donkey Calf Raise',
    5 => 'Weighted Donkey Calf Raise',
    6 => 'Seated Calf Raise',
    7 => 'Weighted Seated Calf Raise',
    8 => 'Seated Dumbbell Toe Raise',
    9 => 'Single Leg Bent Knee Calf Raise',
    10 => 'Weighted Single Leg Bent Knee Calf Raise',
    11 => 'Single Leg Decline Push Up',
    12 => 'Single Leg Donkey Calf Raise',
    13 => 'Weighted Single Leg Donkey Calf Raise',
    14 => 'Single Leg Hip Raise With Knee Hold',
    15 => 'Single Leg Standing Calf Raise',
    16 => 'Single Leg Standing Dumbbell Calf Raise',
    17 => 'Standing Barbell Calf Raise',
    18 => 'Standing Calf Raise',
    19 => 'Weighted Standing Calf Raise',
    20 => 'Standing Dumbbell Calf Raise',
);

my %cardioExerciseName = (
    0 => 'Bob And Weave Circle',
    1 => 'Weighted Bob And Weave Circle',
    2 => 'Cardio Core Crawl',
    3 => 'Weighted Cardio Core Crawl',
    4 => 'Double Under',
    5 => 'Weighted Double Under',
    6 => 'Jump Rope',
    7 => 'Weighted Jump Rope',
    8 => 'Jump Rope Crossover',
    9 => 'Weighted Jump Rope Crossover',
    10 => 'Jump Rope Jog',
    11 => 'Weighted Jump Rope Jog',
    12 => 'Jumping Jacks',
    13 => 'Weighted Jumping Jacks',
    14 => 'Ski Moguls',
    15 => 'Weighted Ski Moguls',
    16 => 'Split Jacks',
    17 => 'Weighted Split Jacks',
    18 => 'Squat Jacks',
    19 => 'Weighted Squat Jacks',
    20 => 'Triple Under',
    21 => 'Weighted Triple Under',
    22 => 'Elliptical',
    23 => 'Spinning',
    24 => 'Pole Paddle Forward Wheelchair',
    25 => 'Pole Paddle Backward Wheelchair',
    26 => 'Pole Handcycle Forward Wheelchair',
    27 => 'Pole Handcycle Backward Wheelchair',
    28 => 'Pole Rainbow Wheelchair',
    29 => 'Double Punch Forward Wheelchair',
    30 => 'Double Punch Down Wheelchair',
    31 => 'Double Punch Sideways Wheelchair',
    32 => 'Double Punch Up Wheelchair',
    33 => 'Sit Ski Wheelchair',
    34 => 'Sitting Jacks Wheelchair',
    35 => 'Punch Forward Wheelchair',
    36 => 'Punch Down Wheelchair',
    37 => 'Punch Sideways Wheelchair',
    38 => 'Punch Up Wheelchair',
    39 => 'Punch Bag Wheelchair',
    40 => 'Pole Dd Ff Uu Wheelchair',
    41 => 'Butterfly Arms Wheelchair',
    42 => 'Punch',
);

my %carryExerciseName = (
    0 => 'Bar Holds',
    1 => 'Farmers Walk',
    2 => 'Farmers Walk On Toes',
    3 => 'Hex Dumbbell Hold',
    4 => 'Overhead Carry',
    5 => 'Dumbbell Waiter Carry',
    6 => 'Farmers Carry Walk Lunge',
    7 => 'Farmers Carry',
    8 => 'Farmers Carry On Toes',
);

my %chopExerciseName = (
    0 => 'Cable Pull Through',
    1 => 'Cable Rotational Lift',
    2 => 'Cable Woodchop',
    3 => 'Cross Chop To Knee',
    4 => 'Weighted Cross Chop To Knee',
    5 => 'Dumbbell Chop',
    6 => 'Half Kneeling Rotation',
    7 => 'Weighted Half Kneeling Rotation',
    8 => 'Half Kneeling Rotational Chop',
    9 => 'Half Kneeling Rotational Reverse Chop',
    10 => 'Half Kneeling Stability Chop',
    11 => 'Half Kneeling Stability Reverse Chop',
    12 => 'Kneeling Rotational Chop',
    13 => 'Kneeling Rotational Reverse Chop',
    14 => 'Kneeling Stability Chop',
    15 => 'Kneeling Woodchopper',
    16 => 'Medicine Ball Wood Chops',
    17 => 'Power Squat Chops',
    18 => 'Weighted Power Squat Chops',
    19 => 'Standing Rotational Chop',
    20 => 'Standing Split Rotational Chop',
    21 => 'Standing Split Rotational Reverse Chop',
    22 => 'Standing Stability Reverse Chop',
);

my %coreExerciseName = (
    0 => 'Abs Jabs',
    1 => 'Weighted Abs Jabs',
    2 => 'Alternating Plate Reach',
    3 => 'Barbell Rollout',
    4 => 'Weighted Barbell Rollout',
    5 => 'Body Bar Oblique Twist',
    6 => 'Cable Core Press',
    7 => 'Cable Side Bend',
    8 => 'Side Bend',
    9 => 'Weighted Side Bend',
    10 => 'Crescent Circle',
    11 => 'Weighted Crescent Circle',
    12 => 'Cycling Russian Twist',
    13 => 'Weighted Cycling Russian Twist',
    14 => 'Elevated Feet Russian Twist',
    15 => 'Weighted Elevated Feet Russian Twist',
    16 => 'Half Turkish Get Up',
    17 => 'Kettlebell Windmill',
    18 => 'Kneeling Ab Wheel',
    19 => 'Weighted Kneeling Ab Wheel',
    20 => 'Modified Front Lever',
    21 => 'Open Knee Tucks',
    22 => 'Weighted Open Knee Tucks',
    23 => 'Side Abs Leg Lift',
    24 => 'Weighted Side Abs Leg Lift',
    25 => 'Swiss Ball Jackknife',
    26 => 'Weighted Swiss Ball Jackknife',
    27 => 'Swiss Ball Pike',
    28 => 'Weighted Swiss Ball Pike',
    29 => 'Swiss Ball Rollout',
    30 => 'Weighted Swiss Ball Rollout',
    31 => 'Triangle Hip Press',
    32 => 'Weighted Triangle Hip Press',
    33 => 'Trx Suspended Jackknife',
    34 => 'Weighted Trx Suspended Jackknife',
    35 => 'U Boat',
    36 => 'Weighted U Boat',
    37 => 'Windmill Switches',
    38 => 'Weighted Windmill Switches',
    39 => 'Alternating Slide Out',
    40 => 'Weighted Alternating Slide Out',
    41 => 'Ghd Back Extensions',
    42 => 'Weighted Ghd Back Extensions',
    43 => 'Overhead Walk',
    44 => 'Inchworm',
    45 => 'Weighted Modified Front Lever',
    46 => 'Russian Twist',
    47 => 'Abdominal Leg Rotations',
    48 => 'Arm And Leg Extension On Knees',
    49 => 'Bicycle',
    50 => 'Bicep Curl With Leg Extension',
    51 => 'Cat Cow',
    52 => 'Corkscrew',
    53 => 'Criss Cross',
    54 => 'Criss Cross With Ball',
    55 => 'Double Leg Stretch',
    56 => 'Knee Folds',
    57 => 'Lower Lift',
    58 => 'Neck Pull',
    59 => 'Pelvic Clocks',
    60 => 'Roll Over',
    61 => 'Roll Up',
    62 => 'Rolling',
    63 => 'Rowing 1',
    64 => 'Rowing 2',
    65 => 'Scissors',
    66 => 'Single Leg Circles',
    67 => 'Single Leg Stretch',
    68 => 'Snake Twist 1 And 2',
    69 => 'Swan',
    70 => 'Swimming',
    71 => 'Teaser',
    72 => 'The Hundred',
    73 => 'Bicep Curl With Leg Extension With Weights',
    75 => 'Hanging L Sit',
    77 => 'Lower Lift With Weights',
    79 => 'Ring L Sit',
    80 => 'Rowing 1 With Weights',
    81 => 'Rowing 2 With Weights',
    82 => 'Scissors With Weights',
    83 => 'Single Leg Stretch With Weights',
    84 => 'Toes To Elbows',
    85 => 'Weighted Criss Cross',
    86 => 'Weighted Double Leg Stretch',
    87 => 'Weighted The Hundred',
    88 => 'L Sit',
    89 => 'Turkish Get Up',
    90 => 'Weighted Ring L Sit',
    91 => 'Weighted Hanging L Sit',
    92 => 'Weighted L Sit',
    93 => 'Side Bend Low Wheelchair',
    94 => 'Side Bend Mid Wheelchair',
    95 => 'Side Bend High Wheelchair',
    96 => 'Seated Side Bend',
);

my %crunchExerciseName = (
    0 => 'Bicycle Crunch',
    1 => 'Cable Crunch',
    2 => 'Circular Arm Crunch',
    3 => 'Crossed Arms Crunch',
    4 => 'Weighted Crossed Arms Crunch',
    5 => 'Cross Leg Reverse Crunch',
    6 => 'Weighted Cross Leg Reverse Crunch',
    7 => 'Crunch Chop',
    8 => 'Weighted Crunch Chop',
    9 => 'Double Crunch',
    10 => 'Weighted Double Crunch',
    11 => 'Elbow To Knee Crunch',
    12 => 'Weighted Elbow To Knee Crunch',
    13 => 'Flutter Kicks',
    14 => 'Weighted Flutter Kicks',
    15 => 'Foam Roller Reverse Crunch On Bench',
    16 => 'Weighted Foam Roller Reverse Crunch On Bench',
    17 => 'Foam Roller Reverse Crunch With Dumbbell',
    18 => 'Foam Roller Reverse Crunch With Medicine Ball',
    19 => 'Frog Press',
    20 => 'Hanging Knee Raise Oblique Crunch',
    21 => 'Weighted Hanging Knee Raise Oblique Crunch',
    22 => 'Hip Crossover',
    23 => 'Weighted Hip Crossover',
    24 => 'Hollow Rock',
    25 => 'Weighted Hollow Rock',
    26 => 'Incline Reverse Crunch',
    27 => 'Weighted Incline Reverse Crunch',
    28 => 'Kneeling Cable Crunch',
    29 => 'Kneeling Cross Crunch',
    30 => 'Weighted Kneeling Cross Crunch',
    31 => 'Kneeling Oblique Cable Crunch',
    32 => 'Knees To Elbow',
    33 => 'Leg Extensions',
    34 => 'Weighted Leg Extensions',
    35 => 'Leg Levers',
    36 => 'Mcgill Curl Up',
    37 => 'Weighted Mcgill Curl Up',
    38 => 'Modified Pilates Roll Up With Ball',
    39 => 'Weighted Modified Pilates Roll Up With Ball',
    40 => 'Pilates Crunch',
    41 => 'Weighted Pilates Crunch',
    42 => 'Pilates Roll Up With Ball',
    43 => 'Weighted Pilates Roll Up With Ball',
    44 => 'Raised Legs Crunch',
    45 => 'Weighted Raised Legs Crunch',
    46 => 'Reverse Crunch',
    47 => 'Weighted Reverse Crunch',
    48 => 'Reverse Crunch On A Bench',
    49 => 'Weighted Reverse Crunch On A Bench',
    50 => 'Reverse Curl And Lift',
    51 => 'Weighted Reverse Curl And Lift',
    52 => 'Rotational Lift',
    53 => 'Weighted Rotational Lift',
    54 => 'Seated Alternating Reverse Crunch',
    55 => 'Weighted Seated Alternating Reverse Crunch',
    56 => 'Seated Leg U',
    57 => 'Weighted Seated Leg U',
    58 => 'Side To Side Crunch And Weave',
    59 => 'Weighted Side To Side Crunch And Weave',
    60 => 'Single Leg Reverse Crunch',
    61 => 'Weighted Single Leg Reverse Crunch',
    62 => 'Skater Crunch Cross',
    63 => 'Weighted Skater Crunch Cross',
    64 => 'Standing Cable Crunch',
    65 => 'Standing Side Crunch',
    66 => 'Step Climb',
    67 => 'Weighted Step Climb',
    68 => 'Swiss Ball Crunch',
    69 => 'Swiss Ball Reverse Crunch',
    70 => 'Weighted Swiss Ball Reverse Crunch',
    71 => 'Swiss Ball Russian Twist',
    72 => 'Weighted Swiss Ball Russian Twist',
    73 => 'Swiss Ball Side Crunch',
    74 => 'Weighted Swiss Ball Side Crunch',
    75 => 'Thoracic Crunches On Foam Roller',
    76 => 'Weighted Thoracic Crunches On Foam Roller',
    77 => 'Triceps Crunch',
    78 => 'Weighted Bicycle Crunch',
    79 => 'Weighted Crunch',
    80 => 'Weighted Swiss Ball Crunch',
    81 => 'Toes To Bar',
    82 => 'Weighted Toes To Bar',
    83 => 'Crunch',
    84 => 'Straight Leg Crunch With Ball',
    86 => 'Leg Climb Crunch',
);

my %curlExerciseName = (
    0 => 'Alternating Dumbbell Biceps Curl',
    1 => 'Alternating Dumbbell Biceps Curl On Swiss Ball',
    2 => 'Alternating Incline Dumbbell Biceps Curl',
    3 => 'Barbell Biceps Curl',
    4 => 'Barbell Reverse Wrist Curl',
    5 => 'Barbell Wrist Curl',
    6 => 'Behind The Back Barbell Reverse Wrist Curl',
    7 => 'Behind The Back One Arm Cable Curl',
    8 => 'Cable Biceps Curl',
    9 => 'Cable Hammer Curl',
    10 => 'Cheating Barbell Biceps Curl',
    11 => 'Close Grip Ez Bar Biceps Curl',
    12 => 'Cross Body Dumbbell Hammer Curl',
    13 => 'Dead Hang Biceps Curl',
    14 => 'Decline Hammer Curl',
    15 => 'Dumbbell Biceps Curl With Static Hold',
    16 => 'Dumbbell Hammer Curl',
    17 => 'Dumbbell Reverse Wrist Curl',
    18 => 'Dumbbell Wrist Curl',
    19 => 'Ez Bar Preacher Curl',
    20 => 'Forward Bend Biceps Curl',
    21 => 'Hammer Curl To Press',
    22 => 'Incline Dumbbell Biceps Curl',
    23 => 'Incline Offset Thumb Dumbbell Curl',
    24 => 'Kettlebell Biceps Curl',
    25 => 'Lying Concentration Cable Curl',
    26 => 'One Arm Preacher Curl',
    27 => 'Plate Pinch Curl',
    28 => 'Preacher Curl With Cable',
    29 => 'Reverse Ez Bar Curl',
    30 => 'Reverse Grip Wrist Curl',
    31 => 'Reverse Grip Barbell Biceps Curl',
    32 => 'Seated Alternating Dumbbell Biceps Curl',
    33 => 'Seated Dumbbell Biceps Curl',
    34 => 'Seated Reverse Dumbbell Curl',
    35 => 'Split Stance Offset Pinky Dumbbell Curl',
    36 => 'Standing Alternating Dumbbell Curls',
    37 => 'Standing Dumbbell Biceps Curl',
    38 => 'Standing Ez Bar Biceps Curl',
    39 => 'Static Curl',
    40 => 'Swiss Ball Dumbbell Overhead Triceps Extension',
    41 => 'Swiss Ball Ez Bar Preacher Curl',
    42 => 'Twisting Standing Dumbbell Biceps Curl',
    43 => 'Wide Grip Ez Bar Biceps Curl',
    44 => 'One Arm Concentration Curl',
    45 => 'Standing Zottman Biceps Curl',
    46 => 'Dumbbell Biceps Curl',
    47 => 'Drag Curl Wheelchair',
    48 => 'Dumbbell Biceps Curl Wheelchair',
    49 => 'Bottle Curl',
    50 => 'Seated Bottle Curl',
);

my %deadliftExerciseName = (
    0 => 'Barbell Deadlift',
    1 => 'Barbell Straight Leg Deadlift',
    2 => 'Dumbbell Deadlift',
    3 => 'Dumbbell Single Leg Deadlift To Row',
    4 => 'Dumbbell Straight Leg Deadlift',
    5 => 'Kettlebell Floor To Shelf',
    6 => 'One Arm One Leg Deadlift',
    7 => 'Rack Pull',
    8 => 'Rotational Dumbbell Straight Leg Deadlift',
    9 => 'Single Arm Deadlift',
    10 => 'Single Leg Barbell Deadlift',
    11 => 'Single Leg Barbell Straight Leg Deadlift',
    12 => 'Single Leg Deadlift With Barbell',
    13 => 'Single Leg Rdl Circuit',
    14 => 'Single Leg Romanian Deadlift With Dumbbell',
    15 => 'Sumo Deadlift',
    16 => 'Sumo Deadlift High Pull',
    17 => 'Trap Bar Deadlift',
    18 => 'Wide Grip Barbell Deadlift',
    20 => 'Kettlebell Deadlift',
    21 => 'Kettlebell Sumo Deadlift',
    23 => 'Romanian Deadlift',
    24 => 'Single Leg Romanian Deadlift Circuit',
    25 => 'Straight Leg Deadlift',
);

my %flyeExerciseName = (
    0 => 'Cable Crossover',
    1 => 'Decline Dumbbell Flye',
    2 => 'Dumbbell Flye',
    3 => 'Incline Dumbbell Flye',
    4 => 'Kettlebell Flye',
    5 => 'Kneeling Rear Flye',
    6 => 'Single Arm Standing Cable Reverse Flye',
    7 => 'Swiss Ball Dumbbell Flye',
    8 => 'Arm Rotations',
    9 => 'Hug A Tree',
    10 => 'Face Down Incline Reverse Flye',
    11 => 'Incline Reverse Flye',
    12 => 'Rear Delt Fly Wheelchair',
);

my %hipRaiseExerciseName = (
    0 => 'Barbell Hip Thrust On Floor',
    1 => 'Barbell Hip Thrust With Bench',
    2 => 'Bent Knee Swiss Ball Reverse Hip Raise',
    3 => 'Weighted Bent Knee Swiss Ball Reverse Hip Raise',
    4 => 'Bridge With Leg Extension',
    5 => 'Weighted Bridge With Leg Extension',
    6 => 'Clam Bridge',
    7 => 'Front Kick Tabletop',
    8 => 'Weighted Front Kick Tabletop',
    9 => 'Hip Extension And Cross',
    10 => 'Weighted Hip Extension And Cross',
    11 => 'Hip Raise',
    12 => 'Weighted Hip Raise',
    13 => 'Hip Raise With Feet On Swiss Ball',
    14 => 'Weighted Hip Raise With Feet On Swiss Ball',
    15 => 'Hip Raise With Head On Bosu Ball',
    16 => 'Weighted Hip Raise With Head On Bosu Ball',
    17 => 'Hip Raise With Head On Swiss Ball',
    18 => 'Weighted Hip Raise With Head On Swiss Ball',
    19 => 'Hip Raise With Knee Squeeze',
    20 => 'Weighted Hip Raise With Knee Squeeze',
    21 => 'Incline Rear Leg Extension',
    22 => 'Weighted Incline Rear Leg Extension',
    23 => 'Kettlebell Swing',
    24 => 'Marching Hip Raise',
    25 => 'Weighted Marching Hip Raise',
    26 => 'Marching Hip Raise With Feet On A Swiss Ball',
    27 => 'Weighted Marching Hip Raise With Feet On A Swiss Ball',
    28 => 'Reverse Hip Raise',
    29 => 'Weighted Reverse Hip Raise',
    30 => 'Single Leg Hip Raise',
    31 => 'Weighted Single Leg Hip Raise',
    32 => 'Single Leg Hip Raise With Foot On Bench',
    33 => 'Weighted Single Leg Hip Raise With Foot On Bench',
    34 => 'Single Leg Hip Raise With Foot On Bosu Ball',
    35 => 'Weighted Single Leg Hip Raise With Foot On Bosu Ball',
    36 => 'Single Leg Hip Raise With Foot On Foam Roller',
    37 => 'Weighted Single Leg Hip Raise With Foot On Foam Roller',
    38 => 'Single Leg Hip Raise With Foot On Medicine Ball',
    39 => 'Weighted Single Leg Hip Raise With Foot On Medicine Ball',
    40 => 'Single Leg Hip Raise With Head On Bosu Ball',
    41 => 'Weighted Single Leg Hip Raise With Head On Bosu Ball',
    42 => 'Weighted Clam Bridge',
    43 => 'Single Leg Swiss Ball Hip Raise And Leg Curl',
    44 => 'Clams',
    45 => 'Inner Thigh Circles',
    46 => 'Inner Thigh Side Lift',
    47 => 'Leg Circles',
    48 => 'Leg Lift',
    49 => 'Leg Lift In External Rotation',
);

my %hipStabilityExerciseName = (
    0 => 'Band Side Lying Leg Raise',
    1 => 'Dead Bug',
    2 => 'Weighted Dead Bug',
    3 => 'External Hip Raise',
    4 => 'Weighted External Hip Raise',
    5 => 'Fire Hydrant Kicks',
    6 => 'Weighted Fire Hydrant Kicks',
    7 => 'Hip Circles',
    8 => 'Weighted Hip Circles',
    9 => 'Inner Thigh Lift',
    10 => 'Weighted Inner Thigh Lift',
    11 => 'Lateral Walks With Band At Ankles',
    12 => 'Pretzel Side Kick',
    13 => 'Weighted Pretzel Side Kick',
    14 => 'Prone Hip Internal Rotation',
    15 => 'Weighted Prone Hip Internal Rotation',
    16 => 'Quadruped',
    17 => 'Quadruped Hip Extension',
    18 => 'Weighted Quadruped Hip Extension',
    19 => 'Quadruped With Leg Lift',
    20 => 'Weighted Quadruped With Leg Lift',
    21 => 'Side Lying Leg Raise',
    22 => 'Weighted Side Lying Leg Raise',
    23 => 'Sliding Hip Adduction',
    24 => 'Weighted Sliding Hip Adduction',
    25 => 'Standing Adduction',
    26 => 'Weighted Standing Adduction',
    27 => 'Standing Cable Hip Abduction',
    28 => 'Standing Hip Abduction',
    29 => 'Weighted Standing Hip Abduction',
    30 => 'Standing Rear Leg Raise',
    31 => 'Weighted Standing Rear Leg Raise',
    32 => 'Supine Hip Internal Rotation',
    33 => 'Weighted Supine Hip Internal Rotation',
    34 => 'Lying Abduction Stretch',
);

my %hipSwingExerciseName = (
    0 => 'Single Arm Kettlebell Swing',
    1 => 'Single Arm Dumbbell Swing',
    2 => 'Step Out Swing',
    3 => 'One Arm Swing',
);

my %hyperextensionExerciseName = (
    0 => 'Back Extension With Opposite Arm And Leg Reach',
    1 => 'Weighted Back Extension With Opposite Arm And Leg Reach',
    2 => 'Base Rotations',
    3 => 'Weighted Base Rotations',
    4 => 'Bent Knee Reverse Hyperextension',
    5 => 'Weighted Bent Knee Reverse Hyperextension',
    6 => 'Hollow Hold And Roll',
    7 => 'Weighted Hollow Hold And Roll',
    8 => 'Kicks',
    9 => 'Weighted Kicks',
    10 => 'Knee Raises',
    11 => 'Weighted Knee Raises',
    12 => 'Kneeling Superman',
    13 => 'Weighted Kneeling Superman',
    14 => 'Lat Pull Down With Row',
    15 => 'Medicine Ball Deadlift To Reach',
    16 => 'One Arm One Leg Row',
    17 => 'One Arm Row With Band',
    18 => 'Overhead Lunge With Medicine Ball',
    19 => 'Plank Knee Tucks',
    20 => 'Weighted Plank Knee Tucks',
    21 => 'Side Step',
    22 => 'Weighted Side Step',
    23 => 'Single Leg Back Extension',
    24 => 'Weighted Single Leg Back Extension',
    25 => 'Spine Extension',
    26 => 'Weighted Spine Extension',
    27 => 'Static Back Extension',
    28 => 'Weighted Static Back Extension',
    29 => 'Superman From Floor',
    30 => 'Weighted Superman From Floor',
    31 => 'Swiss Ball Back Extension',
    32 => 'Weighted Swiss Ball Back Extension',
    33 => 'Swiss Ball Hyperextension',
    34 => 'Weighted Swiss Ball Hyperextension',
    35 => 'Swiss Ball Opposite Arm And Leg Lift',
    36 => 'Weighted Swiss Ball Opposite Arm And Leg Lift',
    37 => 'Superman On Swiss Ball',
    38 => 'Cobra',
    39 => 'Supine Floor Barre',
);

my %lateralRaiseExerciseName = (
    0 => '45 Degree Cable External Rotation',
    1 => 'Alternating Lateral Raise With Static Hold',
    2 => 'Bar Muscle Up',
    3 => 'Bent Over Lateral Raise',
    4 => 'Cable Diagonal Raise',
    5 => 'Cable Front Raise',
    6 => 'Calorie Row',
    7 => 'Combo Shoulder Raise',
    8 => 'Dumbbell Diagonal Raise',
    9 => 'Dumbbell V Raise',
    10 => 'Front Raise',
    11 => 'Leaning Dumbbell Lateral Raise',
    12 => 'Lying Dumbbell Raise',
    13 => 'Muscle Up',
    14 => 'One Arm Cable Lateral Raise',
    15 => 'Overhand Grip Rear Lateral Raise',
    16 => 'Plate Raises',
    17 => 'Ring Dip',
    18 => 'Weighted Ring Dip',
    19 => 'Ring Muscle Up',
    20 => 'Weighted Ring Muscle Up',
    21 => 'Rope Climb',
    22 => 'Weighted Rope Climb',
    23 => 'Scaption',
    24 => 'Seated Lateral Raise',
    25 => 'Seated Rear Lateral Raise',
    26 => 'Side Lying Lateral Raise',
    27 => 'Standing Lift',
    28 => 'Suspended Row',
    29 => 'Underhand Grip Rear Lateral Raise',
    30 => 'Wall Slide',
    31 => 'Weighted Wall Slide',
    32 => 'Arm Circles',
    33 => 'Shaving The Head',
    34 => 'Dumbbell Lateral Raise',
    36 => 'Ring Dip Kipping',
    37 => 'Wall Walk',
    38 => 'Dumbbell Front Raise Wheelchair',
    39 => 'Dumbbell Lateral Raise Wheelchair',
    40 => 'Pole Double Arm Overhead And Forward Wheelchair',
    41 => 'Pole Straight Arm Overhead Wheelchair',
);

my %legCurlExerciseName = (
    0 => 'Leg Curl',
    1 => 'Weighted Leg Curl',
    2 => 'Good Morning',
    3 => 'Seated Barbell Good Morning',
    4 => 'Single Leg Barbell Good Morning',
    5 => 'Single Leg Sliding Leg Curl',
    6 => 'Sliding Leg Curl',
    7 => 'Split Barbell Good Morning',
    8 => 'Split Stance Extension',
    9 => 'Staggered Stance Good Morning',
    10 => 'Swiss Ball Hip Raise And Leg Curl',
    11 => 'Zercher Good Morning',
    12 => 'Band Good Morning',
    13 => 'Bar Good Morning',
);

my %legRaiseExerciseName = (
    0 => 'Hanging Knee Raise',
    1 => 'Hanging Leg Raise',
    2 => 'Weighted Hanging Leg Raise',
    3 => 'Hanging Single Leg Raise',
    4 => 'Weighted Hanging Single Leg Raise',
    5 => 'Kettlebell Leg Raises',
    6 => 'Leg Lowering Drill',
    7 => 'Weighted Leg Lowering Drill',
    8 => 'Lying Straight Leg Raise',
    9 => 'Weighted Lying Straight Leg Raise',
    10 => 'Medicine Ball Leg Drops',
    11 => 'Quadruped Leg Raise',
    12 => 'Weighted Quadruped Leg Raise',
    13 => 'Reverse Leg Raise',
    14 => 'Weighted Reverse Leg Raise',
    15 => 'Reverse Leg Raise On Swiss Ball',
    16 => 'Weighted Reverse Leg Raise On Swiss Ball',
    17 => 'Single Leg Lowering Drill',
    18 => 'Weighted Single Leg Lowering Drill',
    19 => 'Weighted Hanging Knee Raise',
    20 => 'Lateral Stepover',
    21 => 'Weighted Lateral Stepover',
);

my %lungeExerciseName = (
    0 => 'Overhead Lunge',
    1 => 'Lunge Matrix',
    2 => 'Weighted Lunge Matrix',
    3 => 'Alternating Barbell Forward Lunge',
    4 => 'Alternating Dumbbell Lunge With Reach',
    5 => 'Back Foot Elevated Dumbbell Split Squat',
    6 => 'Barbell Box Lunge',
    7 => 'Barbell Bulgarian Split Squat',
    8 => 'Barbell Crossover Lunge',
    9 => 'Barbell Front Split Squat',
    10 => 'Barbell Lunge',
    11 => 'Barbell Reverse Lunge',
    12 => 'Barbell Side Lunge',
    13 => 'Barbell Split Squat',
    14 => 'Core Control Rear Lunge',
    15 => 'Diagonal Lunge',
    16 => 'Drop Lunge',
    17 => 'Dumbbell Box Lunge',
    18 => 'Dumbbell Bulgarian Split Squat',
    19 => 'Dumbbell Crossover Lunge',
    20 => 'Dumbbell Diagonal Lunge',
    21 => 'Dumbbell Lunge',
    22 => 'Dumbbell Lunge And Rotation',
    23 => 'Dumbbell Overhead Bulgarian Split Squat',
    24 => 'Dumbbell Reverse Lunge To High Knee And Press',
    25 => 'Dumbbell Side Lunge',
    26 => 'Elevated Front Foot Barbell Split Squat',
    27 => 'Front Foot Elevated Dumbbell Split Squat',
    28 => 'Gunslinger Lunge',
    29 => 'Lawnmower Lunge',
    30 => 'Low Lunge With Isometric Adduction',
    31 => 'Low Side To Side Lunge',
    32 => 'Lunge',
    33 => 'Weighted Lunge',
    34 => 'Lunge With Arm Reach',
    35 => 'Lunge With Diagonal Reach',
    36 => 'Lunge With Side Bend',
    37 => 'Offset Dumbbell Lunge',
    38 => 'Offset Dumbbell Reverse Lunge',
    39 => 'Overhead Bulgarian Split Squat',
    40 => 'Overhead Dumbbell Reverse Lunge',
    41 => 'Overhead Dumbbell Split Squat',
    42 => 'Overhead Lunge With Rotation',
    43 => 'Reverse Barbell Box Lunge',
    44 => 'Reverse Box Lunge',
    45 => 'Reverse Dumbbell Box Lunge',
    46 => 'Reverse Dumbbell Crossover Lunge',
    47 => 'Reverse Dumbbell Diagonal Lunge',
    48 => 'Reverse Lunge With Reach Back',
    49 => 'Weighted Reverse Lunge With Reach Back',
    50 => 'Reverse Lunge With Twist And Overhead Reach',
    51 => 'Weighted Reverse Lunge With Twist And Overhead Reach',
    52 => 'Reverse Sliding Box Lunge',
    53 => 'Weighted Reverse Sliding Box Lunge',
    54 => 'Reverse Sliding Lunge',
    55 => 'Weighted Reverse Sliding Lunge',
    56 => 'Runners Lunge To Balance',
    57 => 'Weighted Runners Lunge To Balance',
    58 => 'Shifting Side Lunge',
    59 => 'Side And Crossover Lunge',
    60 => 'Weighted Side And Crossover Lunge',
    61 => 'Side Lunge',
    62 => 'Weighted Side Lunge',
    63 => 'Side Lunge And Press',
    64 => 'Side Lunge Jump Off',
    65 => 'Side Lunge Sweep',
    66 => 'Weighted Side Lunge Sweep',
    67 => 'Side Lunge To Crossover Tap',
    68 => 'Weighted Side Lunge To Crossover Tap',
    69 => 'Side To Side Lunge Chops',
    70 => 'Weighted Side To Side Lunge Chops',
    71 => 'Siff Jump Lunge',
    72 => 'Weighted Siff Jump Lunge',
    73 => 'Single Arm Reverse Lunge And Press',
    74 => 'Sliding Lateral Lunge',
    75 => 'Weighted Sliding Lateral Lunge',
    76 => 'Walking Barbell Lunge',
    77 => 'Walking Dumbbell Lunge',
    78 => 'Walking Lunge',
    79 => 'Weighted Walking Lunge',
    80 => 'Wide Grip Overhead Barbell Split Squat',
    81 => 'Alternating Dumbbell Lunge',
    82 => 'Dumbbell Reverse Lunge',
    83 => 'Overhead Dumbbell Lunge',
    84 => 'Scissor Power Switch',
    85 => 'Dumbbell Overhead Walking Lunge',
    86 => 'Curtsy Lunge',
    87 => 'Weighted Curtsy Lunge',
    88 => 'Weighted Shifting Side Lunge',
    89 => 'Weighted Side Lunge And Press',
    90 => 'Weighted Side Lunge Jump Off',
);

my %olympicLiftExerciseName = (
    0 => 'Barbell Hang Power Clean',
    1 => 'Barbell Hang Squat Clean',
    2 => 'Barbell Power Clean',
    3 => 'Barbell Power Snatch',
    4 => 'Barbell Squat Clean',
    5 => 'Clean And Jerk',
    6 => 'Barbell Hang Power Snatch',
    7 => 'Barbell Hang Pull',
    8 => 'Barbell High Pull',
    9 => 'Barbell Snatch',
    10 => 'Barbell Split Jerk',
    11 => 'Clean',
    12 => 'Dumbbell Clean',
    13 => 'Dumbbell Hang Pull',
    14 => 'One Hand Dumbbell Split Snatch',
    15 => 'Push Jerk',
    16 => 'Single Arm Dumbbell Snatch',
    17 => 'Single Arm Hang Snatch',
    18 => 'Single Arm Kettlebell Snatch',
    19 => 'Split Jerk',
    20 => 'Squat Clean And Jerk',
    21 => 'Dumbbell Hang Snatch',
    22 => 'Dumbbell Power Clean And Jerk',
    23 => 'Dumbbell Power Clean And Push Press',
    24 => 'Dumbbell Power Clean And Strict Press',
    25 => 'Dumbbell Snatch',
    26 => 'Medicine Ball Clean',
    27 => 'Clean And Press',
    28 => 'Snatch',
);

my %plankExerciseName = (
    0 => '45 Degree Plank',
    1 => 'Weighted 45 Degree Plank',
    2 => '90 Degree Static Hold',
    3 => 'Weighted 90 Degree Static Hold',
    4 => 'Bear Crawl',
    5 => 'Weighted Bear Crawl',
    6 => 'Cross Body Mountain Climber',
    7 => 'Weighted Cross Body Mountain Climber',
    8 => 'Elbow Plank Pike Jacks',
    9 => 'Weighted Elbow Plank Pike Jacks',
    10 => 'Elevated Feet Plank',
    11 => 'Weighted Elevated Feet Plank',
    12 => 'Elevator Abs',
    13 => 'Weighted Elevator Abs',
    14 => 'Extended Plank',
    15 => 'Weighted Extended Plank',
    16 => 'Full Plank Passe Twist',
    17 => 'Weighted Full Plank Passe Twist',
    18 => 'Inching Elbow Plank',
    19 => 'Weighted Inching Elbow Plank',
    20 => 'Inchworm To Side Plank',
    21 => 'Weighted Inchworm To Side Plank',
    22 => 'Kneeling Plank',
    23 => 'Weighted Kneeling Plank',
    24 => 'Kneeling Side Plank With Leg Lift',
    25 => 'Weighted Kneeling Side Plank With Leg Lift',
    26 => 'Lateral Roll',
    27 => 'Weighted Lateral Roll',
    28 => 'Lying Reverse Plank',
    29 => 'Weighted Lying Reverse Plank',
    30 => 'Medicine Ball Mountain Climber',
    31 => 'Weighted Medicine Ball Mountain Climber',
    32 => 'Modified Mountain Climber And Extension',
    33 => 'Weighted Modified Mountain Climber And Extension',
    34 => 'Mountain Climber',
    35 => 'Weighted Mountain Climber',
    36 => 'Mountain Climber On Sliding Discs',
    37 => 'Weighted Mountain Climber On Sliding Discs',
    38 => 'Mountain Climber With Feet On Bosu Ball',
    39 => 'Weighted Mountain Climber With Feet On Bosu Ball',
    40 => 'Mountain Climber With Hands On Bench',
    41 => 'Mountain Climber With Hands On Swiss Ball',
    42 => 'Weighted Mountain Climber With Hands On Swiss Ball',
    43 => 'Plank',
    44 => 'Plank Jacks With Feet On Sliding Discs',
    45 => 'Weighted Plank Jacks With Feet On Sliding Discs',
    46 => 'Plank Knee Twist',
    47 => 'Weighted Plank Knee Twist',
    48 => 'Plank Pike Jumps',
    49 => 'Weighted Plank Pike Jumps',
    50 => 'Plank Pikes',
    51 => 'Weighted Plank Pikes',
    52 => 'Plank To Stand Up',
    53 => 'Weighted Plank To Stand Up',
    54 => 'Plank With Arm Raise',
    55 => 'Weighted Plank With Arm Raise',
    56 => 'Plank With Knee To Elbow',
    57 => 'Weighted Plank With Knee To Elbow',
    58 => 'Plank With Oblique Crunch',
    59 => 'Weighted Plank With Oblique Crunch',
    60 => 'Plyometric Side Plank',
    61 => 'Weighted Plyometric Side Plank',
    62 => 'Rolling Side Plank',
    63 => 'Weighted Rolling Side Plank',
    64 => 'Side Kick Plank',
    65 => 'Weighted Side Kick Plank',
    66 => 'Side Plank',
    67 => 'Weighted Side Plank',
    68 => 'Side Plank And Row',
    69 => 'Weighted Side Plank And Row',
    70 => 'Side Plank Lift',
    71 => 'Weighted Side Plank Lift',
    72 => 'Side Plank With Elbow On Bosu Ball',
    73 => 'Weighted Side Plank With Elbow On Bosu Ball',
    74 => 'Side Plank With Feet On Bench',
    75 => 'Weighted Side Plank With Feet On Bench',
    76 => 'Side Plank With Knee Circle',
    77 => 'Weighted Side Plank With Knee Circle',
    78 => 'Side Plank With Knee Tuck',
    79 => 'Weighted Side Plank With Knee Tuck',
    80 => 'Side Plank With Leg Lift',
    81 => 'Weighted Side Plank With Leg Lift',
    82 => 'Side Plank With Reach Under',
    83 => 'Weighted Side Plank With Reach Under',
    84 => 'Single Leg Elevated Feet Plank',
    85 => 'Weighted Single Leg Elevated Feet Plank',
    86 => 'Single Leg Flex And Extend',
    87 => 'Weighted Single Leg Flex And Extend',
    88 => 'Single Leg Side Plank',
    89 => 'Weighted Single Leg Side Plank',
    90 => 'Spiderman Plank',
    91 => 'Weighted Spiderman Plank',
    92 => 'Straight Arm Plank',
    93 => 'Weighted Straight Arm Plank',
    94 => 'Straight Arm Plank With Shoulder Touch',
    95 => 'Weighted Straight Arm Plank With Shoulder Touch',
    96 => 'Swiss Ball Plank',
    97 => 'Weighted Swiss Ball Plank',
    98 => 'Swiss Ball Plank Leg Lift',
    99 => 'Weighted Swiss Ball Plank Leg Lift',
    100 => 'Swiss Ball Plank Leg Lift And Hold',
    101 => 'Swiss Ball Plank With Feet On Bench',
    102 => 'Weighted Swiss Ball Plank With Feet On Bench',
    103 => 'Swiss Ball Prone Jackknife',
    104 => 'Weighted Swiss Ball Prone Jackknife',
    105 => 'Swiss Ball Side Plank',
    106 => 'Weighted Swiss Ball Side Plank',
    107 => 'Three Way Plank',
    108 => 'Weighted Three Way Plank',
    109 => 'Towel Plank And Knee In',
    110 => 'Weighted Towel Plank And Knee In',
    111 => 'T Stabilization',
    112 => 'Weighted T Stabilization',
    113 => 'Turkish Get Up To Side Plank',
    114 => 'Weighted Turkish Get Up To Side Plank',
    115 => 'Two Point Plank',
    116 => 'Weighted Two Point Plank',
    117 => 'Weighted Plank',
    118 => 'Wide Stance Plank With Diagonal Arm Lift',
    119 => 'Weighted Wide Stance Plank With Diagonal Arm Lift',
    120 => 'Wide Stance Plank With Diagonal Leg Lift',
    121 => 'Weighted Wide Stance Plank With Diagonal Leg Lift',
    122 => 'Wide Stance Plank With Leg Lift',
    123 => 'Weighted Wide Stance Plank With Leg Lift',
    124 => 'Wide Stance Plank With Opposite Arm And Leg Lift',
    125 => 'Weighted Mountain Climber With Hands On Bench',
    126 => 'Weighted Swiss Ball Plank Leg Lift And Hold',
    127 => 'Weighted Wide Stance Plank With Opposite Arm And Leg Lift',
    128 => 'Plank With Feet On Swiss Ball',
    129 => 'Side Plank To Plank With Reach Under',
    130 => 'Bridge With Glute Lower Lift',
    131 => 'Bridge One Leg Bridge',
    132 => 'Plank With Arm Variations',
    133 => 'Plank With Leg Lift',
    134 => 'Reverse Plank With Leg Pull',
    135 => 'Ring Plank Sprawls',
);

my %plyoExerciseName = (
    0 => 'Alternating Jump Lunge',
    1 => 'Weighted Alternating Jump Lunge',
    2 => 'Barbell Jump Squat',
    3 => 'Body Weight Jump Squat',
    4 => 'Weighted Jump Squat',
    5 => 'Cross Knee Strike',
    6 => 'Weighted Cross Knee Strike',
    7 => 'Depth Jump',
    8 => 'Weighted Depth Jump',
    9 => 'Dumbbell Jump Squat',
    10 => 'Dumbbell Split Jump',
    11 => 'Front Knee Strike',
    12 => 'Weighted Front Knee Strike',
    13 => 'High Box Jump',
    14 => 'Weighted High Box Jump',
    15 => 'Isometric Explosive Body Weight Jump Squat',
    16 => 'Weighted Isometric Explosive Jump Squat',
    17 => 'Lateral Leap And Hop',
    18 => 'Weighted Lateral Leap And Hop',
    19 => 'Lateral Plyo Squats',
    20 => 'Weighted Lateral Plyo Squats',
    21 => 'Lateral Slide',
    22 => 'Weighted Lateral Slide',
    23 => 'Medicine Ball Overhead Throws',
    24 => 'Medicine Ball Side Throw',
    25 => 'Medicine Ball Slam',
    26 => 'Side To Side Medicine Ball Throws',
    27 => 'Side To Side Shuffle Jump',
    28 => 'Weighted Side To Side Shuffle Jump',
    29 => 'Squat Jump Onto Box',
    30 => 'Weighted Squat Jump Onto Box',
    31 => 'Squat Jumps In And Out',
    32 => 'Weighted Squat Jumps In And Out',
    33 => 'Box Jump',
    34 => 'Box Jump Overs',
    35 => 'Box Jump Overs Over The Box',
    36 => 'Star Jump Squats',
    37 => 'Jump Squat',
);

my %pullUpExerciseName = (
    0 => 'Banded Pull Ups',
    1 => '30 Degree Lat Pulldown',
    2 => 'Band Assisted Chin Up',
    3 => 'Close Grip Chin Up',
    4 => 'Weighted Close Grip Chin Up',
    5 => 'Close Grip Lat Pulldown',
    6 => 'Crossover Chin Up',
    7 => 'Weighted Crossover Chin Up',
    8 => 'Ez Bar Pullover',
    9 => 'Hanging Hurdle',
    10 => 'Weighted Hanging Hurdle',
    11 => 'Kneeling Lat Pulldown',
    12 => 'Kneeling Underhand Grip Lat Pulldown',
    13 => 'Lat Pulldown',
    14 => 'Mixed Grip Chin Up',
    15 => 'Weighted Mixed Grip Chin Up',
    16 => 'Mixed Grip Pull Up',
    17 => 'Weighted Mixed Grip Pull Up',
    18 => 'Reverse Grip Pulldown',
    19 => 'Standing Cable Pullover',
    20 => 'Straight Arm Pulldown',
    21 => 'Swiss Ball Ez Bar Pullover',
    22 => 'Towel Pull Up',
    23 => 'Weighted Towel Pull Up',
    24 => 'Weighted Pull Up',
    25 => 'Wide Grip Lat Pulldown',
    26 => 'Wide Grip Pull Up',
    27 => 'Weighted Wide Grip Pull Up',
    28 => 'Burpee Pull Up',
    29 => 'Weighted Burpee Pull Up',
    30 => 'Jumping Pull Ups',
    31 => 'Weighted Jumping Pull Ups',
    32 => 'Kipping Pull Up',
    33 => 'Weighted Kipping Pull Up',
    34 => 'L Pull Up',
    35 => 'Weighted L Pull Up',
    36 => 'Suspended Chin Up',
    37 => 'Weighted Suspended Chin Up',
    38 => 'Pull Up',
    39 => 'Chin Up',
    40 => 'Neutral Grip Chin Up',
    41 => 'Weighted Chin Up',
    42 => 'Band Assisted Pull Up',
    43 => 'Neutral Grip Pull Up',
    44 => 'Weighted Neutral Grip Chin Up',
    45 => 'Weighted Neutral Grip Pull Up',
);

my %pushUpExerciseName = (
    0 => 'Chest Press With Band',
    1 => 'Alternating Staggered Push Up',
    2 => 'Weighted Alternating Staggered Push Up',
    3 => 'Alternating Hands Medicine Ball Push Up',
    4 => 'Weighted Alternating Hands Medicine Ball Push Up',
    5 => 'Bosu Ball Push Up',
    6 => 'Weighted Bosu Ball Push Up',
    7 => 'Clapping Push Up',
    8 => 'Weighted Clapping Push Up',
    9 => 'Close Grip Medicine Ball Push Up',
    10 => 'Weighted Close Grip Medicine Ball Push Up',
    11 => 'Close Hands Push Up',
    12 => 'Weighted Close Hands Push Up',
    13 => 'Decline Push Up',
    14 => 'Weighted Decline Push Up',
    15 => 'Diamond Push Up',
    16 => 'Weighted Diamond Push Up',
    17 => 'Explosive Crossover Push Up',
    18 => 'Weighted Explosive Crossover Push Up',
    19 => 'Explosive Push Up',
    20 => 'Weighted Explosive Push Up',
    21 => 'Feet Elevated Side To Side Push Up',
    22 => 'Weighted Feet Elevated Side To Side Push Up',
    23 => 'Hand Release Push Up',
    24 => 'Weighted Hand Release Push Up',
    25 => 'Handstand Push Up',
    26 => 'Weighted Handstand Push Up',
    27 => 'Incline Push Up',
    28 => 'Weighted Incline Push Up',
    29 => 'Isometric Explosive Push Up',
    30 => 'Weighted Isometric Explosive Push Up',
    31 => 'Judo Push Up',
    32 => 'Weighted Judo Push Up',
    33 => 'Kneeling Push Up',
    34 => 'Weighted Kneeling Push Up',
    35 => 'Medicine Ball Chest Pass',
    36 => 'Medicine Ball Push Up',
    37 => 'Weighted Medicine Ball Push Up',
    38 => 'One Arm Push Up',
    39 => 'Weighted One Arm Push Up',
    40 => 'Weighted Push Up',
    41 => 'Push Up And Row',
    42 => 'Weighted Push Up And Row',
    43 => 'Push Up Plus',
    44 => 'Weighted Push Up Plus',
    45 => 'Push Up With Feet On Swiss Ball',
    46 => 'Weighted Push Up With Feet On Swiss Ball',
    47 => 'Push Up With One Hand On Medicine Ball',
    48 => 'Weighted Push Up With One Hand On Medicine Ball',
    49 => 'Shoulder Push Up',
    50 => 'Weighted Shoulder Push Up',
    51 => 'Single Arm Medicine Ball Push Up',
    52 => 'Weighted Single Arm Medicine Ball Push Up',
    53 => 'Spiderman Push Up',
    54 => 'Weighted Spiderman Push Up',
    55 => 'Stacked Feet Push Up',
    56 => 'Weighted Stacked Feet Push Up',
    57 => 'Staggered Hands Push Up',
    58 => 'Weighted Staggered Hands Push Up',
    59 => 'Suspended Push Up',
    60 => 'Weighted Suspended Push Up',
    61 => 'Swiss Ball Push Up',
    62 => 'Weighted Swiss Ball Push Up',
    63 => 'Swiss Ball Push Up Plus',
    64 => 'Weighted Swiss Ball Push Up Plus',
    65 => 'T Push Up',
    66 => 'Weighted T Push Up',
    67 => 'Triple Stop Push Up',
    68 => 'Weighted Triple Stop Push Up',
    69 => 'Wide Hands Push Up',
    70 => 'Weighted Wide Hands Push Up',
    71 => 'Parallette Handstand Push Up',
    72 => 'Weighted Parallette Handstand Push Up',
    73 => 'Ring Handstand Push Up',
    74 => 'Weighted Ring Handstand Push Up',
    75 => 'Ring Push Up',
    76 => 'Weighted Ring Push Up',
    77 => 'Push Up',
    78 => 'Pilates Pushup',
    79 => 'Dynamic Push Up',
    80 => 'Kipping Handstand Push Up',
    81 => 'Shoulder Tapping Push Up',
    82 => 'Biceps Push Up',
    83 => 'Hindu Push Up',
    84 => 'Pike Push Up',
    85 => 'Wide Grip Push Up',
    86 => 'Weighted Biceps Push Up',
    87 => 'Weighted Hindu Push Up',
    88 => 'Weighted Pike Push Up',
    89 => 'Kipping Parallette Handstand Push Up',
    90 => 'Wall Push Up',
);

my %rowExerciseName = (
    0 => 'Barbell Straight Leg Deadlift To Row',
    1 => 'Cable Row Standing',
    2 => 'Dumbbell Row',
    3 => 'Elevated Feet Inverted Row',
    4 => 'Weighted Elevated Feet Inverted Row',
    5 => 'Face Pull',
    6 => 'Face Pull With External Rotation',
    7 => 'Inverted Row With Feet On Swiss Ball',
    8 => 'Weighted Inverted Row With Feet On Swiss Ball',
    9 => 'Kettlebell Row',
    10 => 'Modified Inverted Row',
    11 => 'Weighted Modified Inverted Row',
    12 => 'Neutral Grip Alternating Dumbbell Row',
    13 => 'One Arm Bent Over Row',
    14 => 'One Legged Dumbbell Row',
    15 => 'Renegade Row',
    16 => 'Reverse Grip Barbell Row',
    17 => 'Rope Handle Cable Row',
    18 => 'Seated Cable Row',
    19 => 'Seated Dumbbell Row',
    20 => 'Single Arm Cable Row',
    21 => 'Single Arm Cable Row And Rotation',
    22 => 'Single Arm Inverted Row',
    23 => 'Weighted Single Arm Inverted Row',
    24 => 'Single Arm Neutral Grip Dumbbell Row',
    25 => 'Single Arm Neutral Grip Dumbbell Row And Rotation',
    26 => 'Suspended Inverted Row',
    27 => 'Weighted Suspended Inverted Row',
    28 => 'T Bar Row',
    29 => 'Towel Grip Inverted Row',
    30 => 'Weighted Towel Grip Inverted Row',
    31 => 'Underhand Grip Cable Row',
    32 => 'V Grip Cable Row',
    33 => 'Wide Grip Seated Cable Row',
    34 => 'Alternating Dumbbell Row',
    35 => 'Inverted Row',
    36 => 'Row',
    37 => 'Weighted Row',
    38 => 'Indoor Row',
    39 => 'Banded Face Pulls',
    40 => 'Chest Supported Dumbbell Row',
    41 => 'Decline Ring Row',
    42 => 'Elevated Ring Row',
    43 => 'Rdl Bent Over Row With Barbell Dumbbell',
    44 => 'Ring Row',
    45 => 'Barbell Row',
    46 => 'Bent Over Row With Barbell',
    47 => 'Bent Over Row With Dumbell',
    48 => 'Seated Underhand Grip Cable Row',
    49 => 'Trx Inverted Row',
    50 => 'Weighted Inverted Row',
    51 => 'Weighted Trx Inverted Row',
    52 => 'Dumbbell Row Wheelchair',
);

my %shoulderPressExerciseName = (
    0 => 'Alternating Dumbbell Shoulder Press',
    1 => 'Arnold Press',
    2 => 'Barbell Front Squat To Push Press',
    3 => 'Barbell Push Press',
    4 => 'Barbell Shoulder Press',
    5 => 'Dead Curl Press',
    6 => 'Dumbbell Alternating Shoulder Press And Twist',
    7 => 'Dumbbell Hammer Curl To Lunge To Press',
    8 => 'Dumbbell Push Press',
    9 => 'Floor Inverted Shoulder Press',
    10 => 'Weighted Floor Inverted Shoulder Press',
    11 => 'Inverted Shoulder Press',
    12 => 'Weighted Inverted Shoulder Press',
    13 => 'One Arm Push Press',
    14 => 'Overhead Barbell Press',
    15 => 'Overhead Dumbbell Press',
    16 => 'Seated Barbell Shoulder Press',
    17 => 'Seated Dumbbell Shoulder Press',
    18 => 'Single Arm Dumbbell Shoulder Press',
    19 => 'Single Arm Step Up And Press',
    20 => 'Smith Machine Overhead Press',
    21 => 'Split Stance Hammer Curl To Press',
    22 => 'Swiss Ball Dumbbell Shoulder Press',
    23 => 'Weight Plate Front Raise',
    24 => 'Dumbbell Shoulder Press',
    25 => 'Military Press',
    27 => 'Strict Press',
    28 => 'Dumbbell Front Raise',
    29 => 'Dumbbell Curl To Overhead Press Wheelchair',
    30 => 'Arnold Press Wheelchair',
    31 => 'Overhead Dumbbell Press Wheelchair',
);

my %shoulderStabilityExerciseName = (
    0 => '90 Degree Cable External Rotation',
    1 => 'Band External Rotation',
    2 => 'Band Internal Rotation',
    3 => 'Bent Arm Lateral Raise And External Rotation',
    4 => 'Cable External Rotation',
    5 => 'Dumbbell Face Pull With External Rotation',
    6 => 'Floor I Raise',
    7 => 'Weighted Floor I Raise',
    8 => 'Floor T Raise',
    9 => 'Weighted Floor T Raise',
    10 => 'Floor Y Raise',
    11 => 'Weighted Floor Y Raise',
    12 => 'Incline I Raise',
    13 => 'Weighted Incline I Raise',
    14 => 'Incline L Raise',
    15 => 'Weighted Incline L Raise',
    16 => 'Incline T Raise',
    17 => 'Weighted Incline T Raise',
    18 => 'Incline W Raise',
    19 => 'Weighted Incline W Raise',
    20 => 'Incline Y Raise',
    21 => 'Weighted Incline Y Raise',
    22 => 'Lying External Rotation',
    23 => 'Seated Dumbbell External Rotation',
    24 => 'Standing L Raise',
    25 => 'Swiss Ball I Raise',
    26 => 'Weighted Swiss Ball I Raise',
    27 => 'Swiss Ball T Raise',
    28 => 'Weighted Swiss Ball T Raise',
    29 => 'Swiss Ball W Raise',
    30 => 'Weighted Swiss Ball W Raise',
    31 => 'Swiss Ball Y Raise',
    32 => 'Weighted Swiss Ball Y Raise',
    33 => 'Cable Internal Rotation',
    34 => 'Lying Internal Rotation',
    35 => 'Seated Dumbbell Internal Rotation',
);

my %shrugExerciseName = (
    0 => 'Barbell Jump Shrug',
    1 => 'Barbell Shrug',
    2 => 'Barbell Upright Row',
    3 => 'Behind The Back Smith Machine Shrug',
    4 => 'Dumbbell Jump Shrug',
    5 => 'Dumbbell Shrug',
    6 => 'Dumbbell Upright Row',
    7 => 'Incline Dumbbell Shrug',
    8 => 'Overhead Barbell Shrug',
    9 => 'Overhead Dumbbell Shrug',
    10 => 'Scaption And Shrug',
    11 => 'Scapular Retraction',
    12 => 'Serratus Chair Shrug',
    13 => 'Weighted Serratus Chair Shrug',
    14 => 'Serratus Shrug',
    15 => 'Weighted Serratus Shrug',
    16 => 'Wide Grip Jump Shrug',
    17 => 'Wide Grip Barbell Shrug',
    18 => 'Behind The Back Shrug',
    19 => 'Dumbbell Shrug Wheelchair',
    20 => 'Shrug Wheelchair',
    21 => 'Shrug Arm Down Wheelchair',
    22 => 'Shrug Arm Mid Wheelchair',
    23 => 'Shrug Arm Up Wheelchair',
    24 => 'Upright Row',
);

my %sitUpExerciseName = (
    0 => 'Alternating Sit Up',
    1 => 'Weighted Alternating Sit Up',
    2 => 'Bent Knee V Up',
    3 => 'Weighted Bent Knee V Up',
    4 => 'Butterfly Sit Up',
    5 => 'Weighted Butterfly Situp',
    6 => 'Cross Punch Roll Up',
    7 => 'Weighted Cross Punch Roll Up',
    8 => 'Crossed Arms Sit Up',
    9 => 'Weighted Crossed Arms Sit Up',
    10 => 'Get Up Sit Up',
    11 => 'Weighted Get Up Sit Up',
    12 => 'Hovering Sit Up',
    13 => 'Weighted Hovering Sit Up',
    14 => 'Kettlebell Sit Up',
    15 => 'Medicine Ball Alternating V Up',
    16 => 'Medicine Ball Sit Up',
    17 => 'Medicine Ball V Up',
    18 => 'Modified Sit Up',
    19 => 'Negative Sit Up',
    20 => 'One Arm Full Sit Up',
    21 => 'Reclining Circle',
    22 => 'Weighted Reclining Circle',
    23 => 'Reverse Curl Up',
    24 => 'Weighted Reverse Curl Up',
    25 => 'Single Leg Swiss Ball Jackknife',
    26 => 'Weighted Single Leg Swiss Ball Jackknife',
    27 => 'The Teaser',
    28 => 'The Teaser Weighted',
    29 => 'Three Part Roll Down',
    30 => 'Weighted Three Part Roll Down',
    31 => 'V Up',
    32 => 'Weighted V Up',
    33 => 'Weighted Russian Twist On Swiss Ball',
    34 => 'Weighted Sit Up',
    35 => 'X Abs',
    36 => 'Weighted X Abs',
    37 => 'Sit Up',
    38 => 'Ghd Sit Ups',
    39 => 'Sit Up Turkish Get Up',
    40 => 'Russian Twist On Swiss Ball',
);

my %squatExerciseName = (
    0 => 'Leg Press',
    1 => 'Back Squat With Body Bar',
    2 => 'Back Squats',
    3 => 'Weighted Back Squats',
    4 => 'Balancing Squat',
    5 => 'Weighted Balancing Squat',
    6 => 'Barbell Back Squat',
    7 => 'Barbell Box Squat',
    8 => 'Barbell Front Squat',
    9 => 'Barbell Hack Squat',
    10 => 'Barbell Hang Squat Snatch',
    11 => 'Barbell Lateral Step Up',
    12 => 'Barbell Quarter Squat',
    13 => 'Barbell Siff Squat',
    14 => 'Barbell Squat Snatch',
    15 => 'Barbell Squat With Heels Raised',
    16 => 'Barbell Stepover',
    17 => 'Barbell Step Up',
    18 => 'Bench Squat With Rotational Chop',
    19 => 'Weighted Bench Squat With Rotational Chop',
    20 => 'Body Weight Wall Squat',
    21 => 'Weighted Wall Squat',
    22 => 'Box Step Squat',
    23 => 'Weighted Box Step Squat',
    24 => 'Braced Squat',
    25 => 'Crossed Arm Barbell Front Squat',
    26 => 'Crossover Dumbbell Step Up',
    27 => 'Dumbbell Front Squat',
    28 => 'Dumbbell Split Squat',
    29 => 'Dumbbell Squat',
    30 => 'Dumbbell Squat Clean',
    31 => 'Dumbbell Stepover',
    32 => 'Dumbbell Step Up',
    33 => 'Elevated Single Leg Squat',
    34 => 'Weighted Elevated Single Leg Squat',
    35 => 'Figure Four Squats',
    36 => 'Weighted Figure Four Squats',
    37 => 'Goblet Squat',
    38 => 'Kettlebell Squat',
    39 => 'Kettlebell Swing Overhead',
    40 => 'Kettlebell Swing With Flip To Squat',
    41 => 'Lateral Dumbbell Step Up',
    42 => 'One Legged Squat',
    43 => 'Overhead Dumbbell Squat',
    44 => 'Overhead Squat',
    45 => 'Partial Single Leg Squat',
    46 => 'Weighted Partial Single Leg Squat',
    47 => 'Pistol Squat',
    48 => 'Weighted Pistol Squat',
    49 => 'Plie Slides',
    50 => 'Weighted Plie Slides',
    51 => 'Plie Squat',
    52 => 'Weighted Plie Squat',
    53 => 'Prisoner Squat',
    54 => 'Weighted Prisoner Squat',
    55 => 'Single Leg Bench Get Up',
    56 => 'Weighted Single Leg Bench Get Up',
    57 => 'Single Leg Bench Squat',
    58 => 'Weighted Single Leg Bench Squat',
    59 => 'Single Leg Squat On Swiss Ball',
    60 => 'Weighted Single Leg Squat On Swiss Ball',
    61 => 'Squat',
    62 => 'Weighted Squat',
    63 => 'Squats With Band',
    64 => 'Staggered Squat',
    65 => 'Weighted Staggered Squat',
    66 => 'Step Up',
    67 => 'Weighted Step Up',
    68 => 'Suitcase Squats',
    69 => 'Sumo Squat',
    70 => 'Sumo Squat Slide In',
    71 => 'Weighted Sumo Squat Slide In',
    72 => 'Sumo Squat To High Pull',
    73 => 'Sumo Squat To Stand',
    74 => 'Weighted Sumo Squat To Stand',
    75 => 'Sumo Squat With Rotation',
    76 => 'Weighted Sumo Squat With Rotation',
    77 => 'Swiss Ball Body Weight Wall Squat',
    78 => 'Weighted Swiss Ball Wall Squat',
    79 => 'Thrusters',
    80 => 'Uneven Squat',
    81 => 'Weighted Uneven Squat',
    82 => 'Waist Slimming Squat',
    83 => 'Wall Ball',
    84 => 'Wide Stance Barbell Squat',
    85 => 'Wide Stance Goblet Squat',
    86 => 'Zercher Squat',
    87 => 'Kbs Overhead',
    88 => 'Squat And Side Kick',
    89 => 'Squat Jumps In N Out',
    90 => 'Pilates Plie Squats Parallel Turned Out Flat And Heels',
    91 => 'Releve Straight Leg And Knee Bent With One Leg Variation',
    92 => 'Alternating Box Dumbbell Step Ups',
    93 => 'Dumbbell Overhead Squat Single Arm',
    94 => 'Dumbbell Squat Snatch',
    95 => 'Medicine Ball Squat',
    97 => 'Wall Ball Squat And Press',
    98 => 'Squat American Swing',
    100 => 'Air Squat',
    101 => 'Dumbbell Thrusters',
    102 => 'Overhead Barbell Squat',
);

my %totalBodyExerciseName = (
    0 => 'Burpee',
    1 => 'Weighted Burpee',
    2 => 'Burpee Box Jump',
    3 => 'Weighted Burpee Box Jump',
    4 => 'High Pull Burpee',
    5 => 'Man Makers',
    6 => 'One Arm Burpee',
    7 => 'Squat Thrusts',
    8 => 'Weighted Squat Thrusts',
    9 => 'Squat Plank Push Up',
    10 => 'Weighted Squat Plank Push Up',
    11 => 'Standing T Rotation Balance',
    12 => 'Weighted Standing T Rotation Balance',
    13 => 'Barbell Burpee',
    15 => 'Burpee Box Jump Over Yes Literally Jumping Over The Box',
    16 => 'Burpee Box Jump Step Up Over',
    17 => 'Lateral Barbell Burpee',
    18 => 'Total Body Burpee Over Bar',
    19 => 'Burpee Box Jump Over',
    20 => 'Burpee Wheelchair',
);

my %moveExerciseName = (
    0 => 'Arch And Curl',
    1 => 'Arm Circles With Ball Band And Weight',
    2 => 'Arm Stretch',
    3 => 'Back Massage',
    4 => 'Belly Breathing',
    5 => 'Bridge With Ball',
    6 => 'Diamond Leg Crunch',
    7 => 'Diamond Leg Lift',
    8 => 'Eight Point Shoulder Opener',
    9 => 'Foot Rolling',
    10 => 'Footwork',
    11 => 'Footwork On Disc',
    12 => 'Forward Fold',
    13 => 'Frog With Band',
    14 => 'Half Roll Up',
    15 => 'Hamstring Curl',
    16 => 'Hamstring Stretch',
    17 => 'Hip Stretch',
    18 => 'Hug A Tree With Ball Band And Weight',
    19 => 'Knee Circles',
    20 => 'Knee Folds On Disc',
    21 => 'Lateral Flexion',
    22 => 'Leg Stretch With Band',
    23 => 'Leg Stretch With Leg Circles',
    24 => 'Lower Lift On Disc',
    25 => 'Lunge Squat',
    26 => 'Lunges With Knee Lift',
    27 => 'Mermaid Stretch',
    28 => 'Neutral Pelvic Position',
    29 => 'Pelvic Clocks On Disc',
    30 => 'Pilates Plie Squats Parallel Turned Out Flat And Heels With Chair',
    31 => 'Piriformis Stretch',
    32 => 'Plank Knee Crosses',
    33 => 'Plank Knee Pulls',
    34 => 'Plank Up Downs',
    35 => 'Prayer Mudra',
    36 => 'Psoas Lunge Stretch',
    37 => 'Ribcage Breathing',
    38 => 'Roll Down',
    39 => 'Roll Up With Weight And Band',
    40 => 'Saw',
    41 => 'Scapular Stabilization',
    42 => 'Scissors On Disc',
    43 => 'Seated Hip Stretchup',
    44 => 'Seated Twist',
    45 => 'Shaving The Head With Ball Band And Weight',
    46 => 'Spinal Twist',
    47 => 'Spinal Twist Stretch',
    48 => 'Spine Stretch Forward',
    49 => 'Squat Open Arm Twist Pose',
    50 => 'Squats With Ball',
    51 => 'Stand And Hang',
    52 => 'Standing Side Stretch',
    53 => 'Standing Single Leg Forward Bend With It Band Opener',
    54 => 'Straight Leg Crunch With Leg Lift',
    55 => 'Straight Leg Crunch With Leg Lift With Ball',
    56 => 'Straight Leg Crunch With Legs Crossed',
    57 => 'Straight Leg Crunch With Legs Crossed With Ball',
    58 => 'Straight Leg Diagonal Crunch',
    59 => 'Straight Leg Diagonal Crunch With Ball',
    60 => 'Tailbone Curl',
    61 => 'Throat Lock',
    62 => 'Tick Tock Side Roll',
    63 => 'Twist',
    64 => 'V Leg Crunches',
    65 => 'V Sit',
    66 => 'Forward Fold Wheelchair',
    67 => 'Forward Fold Plus Wheelchair',
    68 => 'Arm Circles Low Forward Wheelchair',
    69 => 'Arm Circles Mid Forward Wheelchair',
    70 => 'Arm Circles High Forward Wheelchair',
    71 => 'Arm Circles Low Backward Wheelchair',
    72 => 'Arm Circles Mid Backward Wheelchair',
    73 => 'Arm Circles High Backward Wheelchair',
    74 => 'Core Twists Wheelchair',
    75 => 'Arm Raise Wheelchair',
    76 => 'Chest Expand Wheelchair',
    77 => 'Arm Extend Wheelchair',
    78 => 'Forward Bend Wheelchair',
    79 => 'Toe Touch Wheelchair',
    80 => 'Extended Toe Touch Wheelchair',
    81 => 'Seated Arm Circles',
    82 => 'Trunk Rotations',
    83 => 'Seated Trunk Rotations',
    84 => 'Toe Touch',
);

my %poseExerciseName = (
    0 => 'All Fours',
    1 => 'Ankle To Knee',
    2 => 'Baby Cobra',
    3 => 'Boat',
    4 => 'Bound Angle',
    5 => 'Bound Seated Single Leg Forward Bend',
    6 => 'Bow',
    7 => 'Bowed Half Moon',
    8 => 'Bridge',
    9 => 'Cat',
    10 => 'Chair',
    11 => 'Childs',
    12 => 'Corpse',
    13 => 'Cow Face',
    14 => 'Cow',
    15 => 'Devotional Warrior',
    16 => 'Dolphin Plank',
    17 => 'Dolphin',
    18 => 'Down Dog Knee To Nose',
    19 => 'Down Dog Split',
    20 => 'Down Dog Split Open Hip Bent Knee',
    21 => 'Downward Facing Dog',
    22 => 'Eagle',
    23 => 'Easy Seated',
    24 => 'Extended Puppy',
    25 => 'Extended Side Angle',
    26 => 'Fish',
    27 => 'Four Limbed Staff',
    28 => 'Full Split',
    29 => 'Gate',
    30 => 'Half Chair Half Ankle To Knee',
    31 => 'Half Moon',
    32 => 'Head To Knee',
    33 => 'Heron',
    34 => 'Heros',
    35 => 'High Lunge',
    36 => 'Knees Chest Chin',
    37 => 'Lizard',
    38 => 'Locust',
    39 => 'Low Lunge',
    40 => 'Low Lunge Twist',
    41 => 'Low Lunge With Knee Down',
    42 => 'Mermaid',
    43 => 'Mountain',
    44 => 'One Legged Downward Facing Pose Open Hip Bent Knee',
    45 => 'One Legged Pigeon',
    46 => 'Peaceful Warrior',
    47 => 'Plank',
    48 => 'Plow',
    49 => 'Reclined Hand To Foot',
    50 => 'Revolved Half Moon',
    51 => 'Revolved Head To Knee',
    52 => 'Revolved Triangle',
    53 => 'Runners Lunge',
    54 => 'Seated Easy Side Bend',
    55 => 'Seated Easy Twist',
    56 => 'Seated Long Leg Forward Bend',
    57 => 'Seated Wide Leg Forward Bend',
    58 => 'Shoulder Stand',
    59 => 'Side Boat',
    60 => 'Side Plank',
    61 => 'Sphinx',
    62 => 'Squat Open Arm Twist',
    63 => 'Squat Palm Press',
    64 => 'Staff',
    65 => 'Standing Arms Up',
    66 => 'Standing Forward Bend Halfway Up',
    67 => 'Standing Forward Bend',
    68 => 'Standing Side Opener',
    69 => 'Standing Single Leg Forward Bend',
    70 => 'Standing Split',
    71 => 'Standing Wide Leg Forward Bend',
    72 => 'Standing Wide Leg Forward Bend With Twist',
    73 => 'Supine Spinal Twist',
    74 => 'Table Top',
    75 => 'Thread The Needle',
    76 => 'Thunderbolt',
    77 => 'Thunderbolt Pose Both Sides Arm Stretch',
    78 => 'Tree',
    79 => 'Triangle',
    80 => 'Up Dog',
    81 => 'Upward Facing Plank',
    82 => 'Warrior One',
    83 => 'Warrior Three',
    84 => 'Warrior Two',
    85 => 'Wheel',
    86 => 'Wide Side Lunge',
    87 => 'Deep Breathing Wheelchair',
    88 => 'Deep Breathing Low Wheelchair',
    89 => 'Deep Breathing Mid Wheelchair',
    90 => 'Deep Breathing High Wheelchair',
    91 => 'Prayer Wheelchair',
    92 => 'Overhead Prayer Wheelchair',
    93 => 'Cactus Wheelchair',
    94 => 'Breathing Punches Wheelchair',
    95 => 'Breathing Punches Extended Wheelchair',
    96 => 'Breathing Punches Overhead Wheelchair',
    97 => 'Breathing Punches Overhead And Down Wheelchair',
    98 => 'Breathing Punches Side Wheelchair',
    99 => 'Breathing Punches Extended Side Wheelchair',
    100 => 'Breathing Punches Overhead Side Wheelchair',
    101 => 'Breathing Punches Overhead And Down Side Wheelchair',
    102 => 'Left Hand Back Wheelchair',
    103 => 'Triangle Wheelchair',
    104 => 'Thread The Needle Wheelchair',
    105 => 'Neck Flexion And Extension Wheelchair',
    106 => 'Neck Lateral Flexion Wheelchair',
    107 => 'Spine Flexion And Extension Wheelchair',
    108 => 'Spine Rotation Wheelchair',
    109 => 'Spine Lateral Flexion Wheelchair',
    110 => 'Alternative Skiing Wheelchair',
    111 => 'Reach Forward Wheelchair',
    112 => 'Warrior Wheelchair',
    113 => 'Reverse Warrior Wheelchair',
    114 => 'Downward Facing Dog To Cobra',
    115 => 'Seated Cat Cow',
);

my %tricepsExtensionExerciseName = (
    0 => 'Bench Dip',
    1 => 'Weighted Bench Dip',
    2 => 'Body Weight Dip',
    3 => 'Cable Kickback',
    4 => 'Cable Lying Triceps Extension',
    5 => 'Cable Overhead Triceps Extension',
    6 => 'Dumbbell Kickback',
    7 => 'Dumbbell Lying Triceps Extension',
    8 => 'Ez Bar Overhead Triceps Extension',
    9 => 'Incline Dip',
    10 => 'Weighted Incline Dip',
    11 => 'Incline Ez Bar Lying Triceps Extension',
    12 => 'Lying Dumbbell Pullover To Extension',
    13 => 'Lying Ez Bar Triceps Extension',
    14 => 'Lying Triceps Extension To Close Grip Bench Press',
    15 => 'Overhead Dumbbell Triceps Extension',
    16 => 'Reclining Triceps Press',
    17 => 'Reverse Grip Pressdown',
    18 => 'Reverse Grip Triceps Pressdown',
    19 => 'Rope Pressdown',
    20 => 'Seated Barbell Overhead Triceps Extension',
    21 => 'Seated Dumbbell Overhead Triceps Extension',
    22 => 'Seated Ez Bar Overhead Triceps Extension',
    23 => 'Seated Single Arm Overhead Dumbbell Extension',
    24 => 'Single Arm Dumbbell Overhead Triceps Extension',
    25 => 'Single Dumbbell Seated Overhead Triceps Extension',
    26 => 'Single Leg Bench Dip And Kick',
    27 => 'Weighted Single Leg Bench Dip And Kick',
    28 => 'Single Leg Dip',
    29 => 'Weighted Single Leg Dip',
    30 => 'Static Lying Triceps Extension',
    31 => 'Suspended Dip',
    32 => 'Weighted Suspended Dip',
    33 => 'Swiss Ball Dumbbell Lying Triceps Extension',
    34 => 'Swiss Ball Ez Bar Lying Triceps Extension',
    35 => 'Swiss Ball Ez Bar Overhead Triceps Extension',
    36 => 'Tabletop Dip',
    37 => 'Weighted Tabletop Dip',
    38 => 'Triceps Extension On Floor',
    39 => 'Triceps Pressdown',
    40 => 'Weighted Dip',
    41 => 'Alternating Dumbbell Lying Triceps Extension',
    42 => 'Triceps Press',
    43 => 'Dumbbell Kickback Wheelchair',
    44 => 'Overhead Dumbbell Triceps Extension Wheelchair',
);

my %warmUpExerciseName = (
    0 => 'Quadruped Rocking',
    1 => 'Neck Tilts',
    2 => 'Ankle Circles',
    3 => 'Ankle Dorsiflexion With Band',
    4 => 'Ankle Internal Rotation',
    5 => 'Arm Circles',
    6 => 'Bent Over Reach To Sky',
    7 => 'Cat Camel',
    8 => 'Elbow To Foot Lunge',
    9 => 'Forward And Backward Leg Swings',
    10 => 'Groiners',
    11 => 'Inverted Hamstring Stretch',
    12 => 'Lateral Duck Under',
    13 => 'Neck Rotations',
    14 => 'Opposite Arm And Leg Balance',
    15 => 'Reach Roll And Lift',
    16 => 'Scorpion',
    17 => 'Shoulder Circles',
    18 => 'Side To Side Leg Swings',
    19 => 'Sleeper Stretch',
    20 => 'Slide Out',
    21 => 'Swiss Ball Hip Crossover',
    22 => 'Swiss Ball Reach Roll And Lift',
    23 => 'Swiss Ball Windshield Wipers',
    24 => 'Thoracic Rotation',
    25 => 'Walking High Kicks',
    26 => 'Walking High Knees',
    27 => 'Walking Knee Hugs',
    28 => 'Walking Leg Cradles',
    29 => 'Walkout',
    30 => 'Walkout From Push Up Position',
    31 => 'Biceps Stretch',
    32 => 'Glutes Stretch',
    33 => 'Standing Hamstring Stretch',
    34 => 'Stretch 90 90',
    35 => 'Stretch Abs',
    36 => 'Stretch Butterfly',
    37 => 'Stretch Calf',
    38 => 'Stretch Cat Cow',
    39 => 'Stretch Childs Pose',
    40 => 'Stretch Cobra',
    41 => 'Stretch Forearms',
    42 => 'Stretch Forward Glutes',
    43 => 'Stretch Front Split',
    44 => 'Stretch Hamstring',
    45 => 'Stretch Hip Flexor And Quad',
    46 => 'Stretch Lat',
    47 => 'Stretch Levator Scapulae',
    48 => 'Stretch Lunge With Spinal Twist',
    49 => 'Stretch Lunging Hip Flexor',
    50 => 'Stretch Lying Abduction',
    51 => 'Stretch Lying It Band',
    52 => 'Stretch Lying Knee To Chest',
    53 => 'Stretch Lying Piriformis',
    54 => 'Stretch Lying Spinal Twist',
    55 => 'Stretch Neck',
    56 => 'Stretch Obliques',
    57 => 'Stretch Over Under Shoulder',
    58 => 'Stretch Pectoral',
    59 => 'Stretch Pigeon Pose',
    60 => 'Stretch Piriformis',
    61 => 'Stretch Quad',
    62 => 'Stretch Scorpion',
    63 => 'Stretch Shoulder',
    64 => 'Stretch Side',
    65 => 'Stretch Side Lunge',
    66 => 'Stretch Side Split',
    67 => 'Stretch Standing It Band',
    68 => 'Stretch Straddle',
    69 => 'Stretch Triceps',
    70 => 'Stretch Wall Chest And Shoulder',
    71 => 'Neck Rotations Wheelchair',
    72 => 'Half Kneeling Arm Rotation',
    73 => 'Three Way Ankle Mobilization',
    74 => 'Ninety Ninety Hip Switch',
    75 => 'Active Frog',
    76 => 'Shoulder Sweeps',
    77 => 'Ankle Lunges',
    78 => 'Back Roll Foam Roller',
    79 => 'Bear Crawl',
    80 => 'Latissimus Dorsi Foam Roll',
    81 => 'Reverse T Hip Opener',
    82 => 'Shoulder Rolls',
    83 => 'Chest Openers',
    84 => 'Triceps Stretch',
    85 => 'Upper Back Stretch',
    86 => 'Hip Circles',
    87 => 'Ankle Stretch',
    88 => 'Marching In Place',
    89 => 'Triceps Stretch Wheelchair',
    90 => 'Upper Back Stretch Wheelchair',
);

my %runExerciseName = (
    0 => 'Run',
    1 => 'Walk',
    2 => 'Jog',
    3 => 'Sprint',
    4 => 'Run Or Walk',
    5 => 'Speed Walk',
    6 => 'Warm Up',
);

my %bikeExerciseName = (
    0 => 'Bike',
    1 => 'Ride',
    2 => 'Sprint',
);

my %bandedExercisesExerciseName = (
    1 => 'Ab Twist',
    2 => 'Back Extension',
    3 => 'Bicycle Crunch',
    4 => 'Calf Raises',
    5 => 'Chest Press',
    6 => 'Clam Shells',
    7 => 'Curl',
    8 => 'Deadbug',
    9 => 'Deadlift',
    10 => 'Donkey Kick',
    11 => 'External Rotation',
    12 => 'External Rotation At 90 Degree Abduction',
    13 => 'Face Pull',
    14 => 'Fire Hydrant',
    15 => 'Fly',
    16 => 'Front Raise',
    17 => 'Glute Bridge',
    18 => 'Hamstring Curls',
    19 => 'High Plank Leg Lifts',
    20 => 'Hip Extension',
    21 => 'Internal Rotation',
    22 => 'Jumping Jack',
    23 => 'Kneeling Crunch',
    24 => 'Lateral Band Walks',
    25 => 'Lateral Raise',
    26 => 'Latpull',
    27 => 'Leg Abduction',
    28 => 'Leg Adduction',
    29 => 'Leg Extension',
    30 => 'Lunge',
    31 => 'Plank',
    32 => 'Pull Apart',
    33 => 'Push Ups',
    34 => 'Reverse Crunch',
    35 => 'Row',
    36 => 'Shoulder Abduction',
    37 => 'Shoulder Extension',
    38 => 'Shoulder External Rotation',
    39 => 'Shoulder Flexion To 90 Degrees',
    40 => 'Side Plank Leg Lifts',
    41 => 'Side Raise',
    42 => 'Squat',
    43 => 'Squat To Press',
    44 => 'Tricep Extension',
    45 => 'Tricep Kickback',
    46 => 'Upright Row',
    47 => 'Wall Crawl With External Rotation',
    49 => 'Lateral Raise Wheelchair',
    50 => 'Triceps Extension Wheelchair',
    51 => 'Chest Fly Incline Wheelchair',
    52 => 'Chest Fly Decline Wheelchair',
    53 => 'Pull Down Wheelchair',
    54 => 'Straight Arm Pull Down Wheelchair',
    55 => 'Curl Wheelchair',
    56 => 'Overhead Curl Wheelchair',
    57 => 'Face Pull Wheelchair',
    58 => 'Around The World Wheelchair',
    59 => 'Pull Apart Wheelchair',
    60 => 'Side Curl Wheelchair',
    61 => 'Overhead Press Wheelchair',
);

my %battleRopeExerciseName = (
    0 => 'Alternating Figure Eight',
    1 => 'Alternating Jump Wave',
    2 => 'Alternating Kneeling To Standing Wave',
    3 => 'Alternating Lunge Wave',
    4 => 'Alternating Squat Wave',
    5 => 'Alternating Wave',
    6 => 'Alternating Wave With Lateral Shuffle',
    7 => 'Clap Wave',
    8 => 'Double Arm Figure Eight',
    9 => 'Double Arm Side To Side Snake',
    10 => 'Double Arm Side Wave',
    11 => 'Double Arm Slam',
    12 => 'Double Arm Wave',
    13 => 'Grappler Toss',
    14 => 'Hip Toss',
    15 => 'In And Out Wave',
    16 => 'Inside Circle',
    17 => 'Jumping Jacks',
    18 => 'Outside Circle',
    19 => 'Rainbow',
    20 => 'Side Plank Wave',
    21 => 'Sidewinder',
    22 => 'Sitting Russian Twist',
    23 => 'Snake Wave',
    24 => 'Split Jack',
    25 => 'Stage Coach',
    26 => 'Ultimate Warrior',
    27 => 'Upper Cuts',
);

my %ellipticalExerciseName = (
    0 => 'Elliptical',
);

my %floorClimbExerciseName = (
    0 => 'Floor Climb',
);

my %indoorBikeExerciseName = (
    0 => 'Air Bike',
    1 => 'Assault Bike',
    3 => 'Stationary Bike',
);

my %indoorRowExerciseName = (
    0 => 'Rowing Machine',
);

my %ladderExerciseName = (
    0 => 'Agility',
    1 => 'Speed',
);

my %sandbagExerciseName = (
    0 => 'Around The World',
    1 => 'Back Squat',
    2 => 'Bear Crawl Pull Through',
    3 => 'Bear Hug Squat',
    4 => 'Clean',
    5 => 'Clean And Press',
    6 => 'Curl',
    7 => 'Front Carry',
    8 => 'Front Squat',
    9 => 'Lunge',
    10 => 'Overhead Press',
    11 => 'Plank Pull Through',
    12 => 'Rotational Lunge',
    13 => 'Row',
    14 => 'Russian Twist',
    15 => 'Shouldering',
    16 => 'Shoveling',
    17 => 'Side Lunge',
    18 => 'Sprint',
    19 => 'Zercher Squat',
);

my %sledExerciseName = (
    0 => 'Backward Drag',
    1 => 'Chest Press',
    2 => 'Forward Drag',
    3 => 'Low Push',
    4 => 'Push',
    5 => 'Row',
);

my %sledgeHammerExerciseName = (
    0 => 'Lateral Swing',
    1 => 'Hammer Slam',
);

my %stairStepperExerciseName = (
    0 => 'Stair Stepper',
);

my %suspensionExerciseName = (
    0 => 'Chest Fly',
    1 => 'Chest Press',
    2 => 'Crunch',
    3 => 'Curl',
    4 => 'Dip',
    5 => 'Face Pull',
    6 => 'Glute Bridge',
    7 => 'Hamstring Curl',
    8 => 'Hip Drop',
    9 => 'Inverted Row',
    10 => 'Knee Drive Jump',
    11 => 'Knee To Chest',
    12 => 'Lat Pullover',
    13 => 'Lunge',
    14 => 'Mountain Climber',
    15 => 'Pendulum',
    16 => 'Pike',
    17 => 'Plank',
    18 => 'Power Pull',
    19 => 'Pull Up',
    20 => 'Push Up',
    21 => 'Reverse Mountain Climber',
    22 => 'Reverse Plank',
    23 => 'Rollout',
    24 => 'Row',
    25 => 'Side Lunge',
    26 => 'Side Plank',
    27 => 'Single Leg Deadlift',
    28 => 'Single Leg Squat',
    29 => 'Sit Up',
    30 => 'Split',
    31 => 'Squat',
    32 => 'Squat Jump',
    33 => 'Tricep Press',
    34 => 'Y Fly',
);

my %tireExerciseName = (
    0 => 'Flip',
);

my %bikeOutdoorExerciseName = (
    0 => 'Bike',
);

my %runIndoorExerciseName = (
    0 => 'Indoor Track Run',
    1 => 'Treadmill',
);

my %waterType = (
    0 => 'Fresh',
    1 => 'Salt',
    2 => 'En13319',
    3 => 'Custom',
);

my %tissueModelType = (
    0 => 'Zhl 16c',
);

my %diveGasStatus = (
    0 => 'Disabled',
    1 => 'Enabled',
    2 => 'Backup Only',
);

my %diveAlert = (
    0 => 'Ndl Reached',
    1 => 'Gas Switch Prompted',
    2 => 'Near Surface',
    3 => 'Approaching Ndl',
    4 => 'PO2 Warn',
    5 => 'PO2 Crit High',
    6 => 'PO2 Crit Low',
    7 => 'Time Alert',
    8 => 'Depth Alert',
    9 => 'Deco Ceiling Broken',
    10 => 'Deco Complete',
    11 => 'Safety Stop Broken',
    12 => 'Safety Stop Complete',
    13 => 'Cns Warning',
    14 => 'Cns Critical',
    15 => 'Otu Warning',
    16 => 'Otu Critical',
    17 => 'Ascent Critical',
    18 => 'Alert Dismissed By Key',
    19 => 'Alert Dismissed By Timeout',
    20 => 'Battery Low',
    21 => 'Battery Critical',
    22 => 'Safety Stop Started',
    23 => 'Approaching First Deco Stop',
    24 => 'Setpoint Switch Auto Low',
    25 => 'Setpoint Switch Auto High',
    26 => 'Setpoint Switch Manual Low',
    27 => 'Setpoint Switch Manual High',
    28 => 'Auto Setpoint Switch Ignored',
    29 => 'Switched To Open Circuit',
    30 => 'Switched To Closed Circuit',
    32 => 'Tank Battery Low',
    33 => 'PO2 CCR Dil Low',
    34 => 'Deco Stop Cleared',
    35 => 'Apnea Neutral Buoyancy',
    36 => 'Apnea Target Depth',
    37 => 'Apnea Surface',
    38 => 'Apnea High Speed',
    39 => 'Apnea Low Speed',
);

my %diveAlarmType = (
    0 => 'Depth',
    1 => 'time',
    2 => 'Speed',
);

my %diveBacklightMode = (
    0 => 'At Depth',
    1 => 'Always On',
);

my %sleepLevelEnum = (
    0 => 'Unmeasurable',
    1 => 'Awake',
    2 => 'Light',
    3 => 'Deep',
    4 => 'Rem',
);

my %sPO2MeasurementType = (
    0 => 'Off Wrist',
    1 => 'Spot Check',
    2 => 'Continuous Check',
    3 => 'Periodic',
);

my %cCRSetpointSwitchMode = (
    0 => 'Manual',
    1 => 'Automatic',
);

my %diveGasMode = (
    0 => 'Open Circuit',
    1 => 'Closed Circuit Diluent',
);

my %projectileType = (
    0 => 'Arrow',
    1 => 'Rifle Cartridge',
    2 => 'Pistol Cartridge',
    3 => 'Shotshell',
    4 => 'Air Rifle Pellet',
    5 => 'Other',
);

my %faveroProduct = (
    10 => 'Assioma Uno',
    12 => 'Assioma Duo',
);

my %splitType = (
    1 => 'Ascent Split',
    2 => 'Descent Split',
    3 => 'Interval Active',
    4 => 'Interval Rest',
    5 => 'Interval Warmup',
    6 => 'Interval Cooldown',
    7 => 'Interval Recovery',
    8 => 'Interval Other',
    9 => 'Climb Active',
    10 => 'Climb Rest',
    11 => 'Surf Active',
    12 => 'Run Active',
    13 => 'Run Rest',
    14 => 'Workout Round',
    17 => 'Rwd Run',
    18 => 'Rwd Walk',
    21 => 'Windsurf Active',
    22 => 'Rwd Stand',
    23 => 'Transition',
    28 => 'Ski Lift Split',
    29 => 'Ski Run Split',
);

my %climbProEvent = (
    0 => 'Approach',
    1 => 'Start',
    2 => 'Complete',
);

my %gasConsumptionRateType = (
    0 => 'Pressure Sac',
    1 => 'Volume Sac',
    2 => 'Rmv',
);

my %tapSensitivity = (
    0 => 'High',
    1 => 'Medium',
    2 => 'Low',
);

my %radarThreatLevelType = (
    0 => 'Threat Unknown',
    1 => 'Threat None',
    2 => 'Threat Approaching',
    3 => 'Threat Approaching Fast',
);

my %sleepDisruptionSeverity = (
    0 => 'None',
    1 => 'Low',
    2 => 'Medium',
    3 => 'High',
);

my %napPeriodFeedback = (
    0 => 'None',
    1 => 'Multiple Naps During Day',
    2 => 'Jetlag Ideal Timing Ideal Duration',
    3 => 'Jetlag Ideal Timing Long Duration',
    4 => 'Jetlag Late Timing Ideal Duration',
    5 => 'Jetlag Late Timing Long Duration',
    6 => 'Ideal Timing Ideal Duration Low Need',
    7 => 'Ideal Timing Ideal Duration High Need',
    8 => 'Ideal Timing Long Duration Low Need',
    9 => 'Ideal Timing Long Duration High Need',
    10 => 'Late Timing Ideal Duration Low Need',
    11 => 'Late Timing Ideal Duration High Need',
    12 => 'Late Timing Long Duration Low Need',
    13 => 'Late Timing Long Duration High Need',
    14 => 'Ideal Duration Low Need',
    15 => 'Ideal Duration High Need',
    16 => 'Long Duration Low Need',
    17 => 'Long Duration High Need',
);

my %napSource = (
    0 => 'Automatic',
    1 => 'Manual Device',
    2 => 'Manual Gc',
);

my %maxMetSpeedSource = (
    0 => 'Onboard GPS',
    1 => 'Connected GPS',
    2 => 'Cadence',
);

my %maxMetHeartRateSource = (
    0 => 'Whr',
    1 => 'HRM',
);

my %hRVStatus = (
    0 => 'None',
    1 => 'Poor',
    2 => 'Low',
    3 => 'Unbalanced',
    4 => 'Balanced',
);

my %noFlyTimeMode = (
    0 => 'Standard',
    1 => 'Flat 24 Hours',
);

#----------------------------------------------------------------------
# Undocumented enumerated types (ref 4)
#
my %alarmLabel = (
    0 => 'None',
    1 => 'Wake Up',
    2 => 'Workout',
    3 => 'Reminder',
    4 => 'Appointment',
    5 => 'Training',
    6 => 'Class',
    7 => 'Meditate',
    8 => 'Bedtime',
);

my %alarmRepeat = (
  BITMASK => {
    0 => 'Mon',
    1 => 'Tue',
    2 => 'Wed',
    3 => 'Thu',
    4 => 'Fri',
    5 => 'Sat',
    6 => 'Sun',
    7 => 'Once',
  }
);

my %alertMetric = (
    0 => 'time',
    1 => 'Distance',
    2 => 'Calories',
    3 => 'Ascent',
    4 => 'Descent',
    5 => 'Reps',
    7 => 'Smart',
    8 => 'Pacing',
);

my %alertZone = (
    0 => 'Off',
    1 => 'Custom',
    101 => 'Zone 1',
    102 => 'Zone 2',
    103 => 'Zone 3',
    104 => 'Zone 4',
    105 => 'Zone 5',
);

my %allow = (
    0 => 'Do Not Allow',
    1 => 'Allow',
);

my %autoLapMode = (
    0 => 'time',
    1 => 'Distance',
    2 => 'Position',
    6 => 'Manual Only',
);

my %autoPauseSetting = (
    0 => 'Off',
    1 => 'When Stopped',
    2 => 'Custom',
);

my %autoScrollMode = (
    0 => 'Off',
    1 => 'Slow',
    2 => 'Medium',
    3 => 'Fast',
);

my %avoidances = (
  BITMASK => {
    0 => 'U Turns',
    1 => 'Toll Roads',
    2 => 'Major Highways',
    3 => 'Unpaved Roads',
    4 => 'Carpool Lanes',
    5 => 'Interstate Hwy',
    6 => 'Ferries',
    7 => 'Narrow Trails',
    8 => 'Climbing Paths',
  }
);

my %benefit = (
    0 => 'No Benefit',
    1 => 'Recovery',
    2 => 'Base',
    3 => 'Tempo',
    4 => 'Threshold',
    5 => 'VO2 Max',
    6 => 'Anaerobic',
    7 => 'Sprint',
);

my %calculationMethod = (
    0 => 'Minimize Time',
    1 => 'Minimize Distance',
    3 => 'Minimize Ascent',
);

my %climbDetection = (
    1 => 'Cat 4',
    2 => 'Cat 3',
    3 => 'Cat 2',
    4 => 'Cat 1',
    5 => 'Hc',
    6 => 'Uncategorized',
);

my %climbProMode = (
    1 => 'When Navigating',
    2 => 'Always',
);

my %climbProTerrain = (
    0 => 'Paved',
    1 => 'Unpaved',
    3 => 'Mixed',
);

my %connectionType = (
    0 => 'Antplus',
    1 => 'Bluetooth Low Energy',
    2 => 'Bluetooth',
);

my %courseRecalculation = (
    0 => 'Auto Pause',
    1 => 'Auto Reroute',
    2 => 'Prompt Only',
    3 => 'Prompt With Auto Reroute',
);

my %courses = (
    0 => 'Follow Course',
    1 => 'Use Map',
);

my %dataFields = (
    0 => 'Total Calories',
    3 => 'Cadence',
    4 => 'Avg Cadence',
    5 => 'Lap Cadence',
    6 => 'Distance',
    7 => 'Lap Distance',
    9 => 'Altitude',
    11 => 'Grade',
    12 => 'Heading',
    13 => 'Heart Rate',
    14 => 'Avg HR',
    15 => 'Lap HR',
    16 => 'HR Max',
    17 => 'Avg HR Max',
    18 => 'Lap HR Max',
    19 => 'HRr',
    20 => 'Avg HRr',
    21 => 'Lap HRr',
    22 => 'HR Zone',
    23 => 'HR Gauge',
    24 => 'laps',
    28 => 'Ete',
    29 => 'Distance To Next',
    30 => 'Time To Next',
    31 => 'Dest Wpt',
    32 => 'Next Wpt',
    33 => 'Pace',
    34 => 'Avg Pace',
    35 => 'Lap Pace',
    36 => 'Power',
    37 => 'Avg Power',
    39 => 'Lap Power',
    40 => 'Max Power',
    43 => 'Power Zone',
    45 => 'Steps',
    48 => 'Speed',
    49 => 'Avg Speed',
    50 => 'Lap Speed',
    53 => 'Sunrise',
    54 => 'Sunset',
    55 => 'Elapsed Time',
    56 => 'Timer',
    57 => 'Avg Lap Time',
    58 => 'Lap Time',
    59 => 'Time Of Day',
    60 => 'Total Ascent',
    61 => 'Total Descent',
    63 => 'Time Ahead',
    67 => 'Repetition',
    77 => 'Vert Spd',
    78 => 'Temperature',
    80 => '30 S Power',
    84 => 'Last Lap Distance',
    85 => 'Last Lap Pace',
    86 => 'Last Lap Speed',
    87 => 'Last Lap Time',
    91 => 'Maximum Speed',
    92 => 'Bearing',
    93 => 'Eta',
    94 => 'Eta At Next',
    96 => 'Battery Pct',
    97 => 'GPS',
    99 => 'Aerobic Te',
    100 => 'Last Lap Power',
    108 => 'Last Lap Cadence',
    165 => 'Last Lap HR',
    170 => 'Vertical Oscillation',
    171 => 'Avg Vert Osc',
    172 => 'Lap Vert Osc',
    173 => 'Ground Contact Time',
    174 => 'Avg Gct',
    175 => 'Lap Gct',
    187 => 'Last Lap HR Max',
    188 => 'Last Lap HRr',
    197 => 'Dist Remaining',
    199 => 'Time In HR Zone 1',
    200 => 'Time In HR Zone 2',
    201 => 'Time In HR Zone 3',
    202 => 'Time In HR Zone 4',
    203 => 'Time In HR Zone 5',
    214 => '24 Hour Max',
    215 => '24 Hour Min',
    216 => 'Connect IQ Field',
    219 => 'Avg Ascent',
    220 => 'Avg Descent',
    221 => 'Max Ascent',
    222 => 'Max Descent',
    223 => 'Lap Ascent',
    224 => 'Lap Descent',
    225 => 'Last Lap Ascent',
    226 => 'Last Lap Descent',
    227 => 'Min Altitude',
    228 => 'Max Altitude',
    229 => 'GPS Altitude',
    230 => 'Vert Dist To Dest',
    231 => 'Ambient Press',
    233 => 'Glide Ratio',
    234 => 'Glide Ratio Dest',
    235 => 'Vert Speed To Tgt',
    236 => 'Course',
    237 => 'GPS Heading',
    238 => 'Compass Hdg',
    239 => 'Off Course',
    240 => 'Location',
    241 => 'Dest Location',
    242 => 'Lat Lon',
    243 => 'Vel Made Good',
    245 => 'Active Calories',
    246 => 'Next Fork',
    302 => 'Step Distance',
    303 => 'Step Time',
    304 => 'Step Speed',
    305 => 'Step Pace',
    307 => 'Gct Balance',
    308 => 'Avg Gct Bal',
    309 => 'Lap Gct Bal',
    310 => 'Vertical Ratio',
    311 => 'Avg Vert Ratio',
    312 => 'Lap Vert Ratio',
    313 => 'Stride Length',
    314 => 'Avg Stride Len',
    315 => 'Lap Stride Len',
    320 => 'Perform Cond',
    395 => 'Battery Hours',
    423 => 'Muscle O 2 Sat',
    424 => 'Total Hemaglobin',
    433 => 'Anaerobic Te',
    452 => 'Resp Rate',
    455 => 'Total Time',
    462 => 'Est Total Dist',
    478 => 'Load',
    511 => 'Workout Comparison',
    512 => 'Cadence Gauge',
    520 => 'Primary Target',
    522 => 'Duration',
    524 => 'Vert Osc Gauge',
    525 => 'Vert Ratio Gauge',
    526 => 'Ground Contact Time Gauge',
    527 => 'Gct Balance Gauge',
    528 => 'Power Gauge',
    529 => 'Compass Gauge',
    530 => 'Te Gauge',
    531 => 'Asc Des Gauge',
    532 => 'Overall Ahead Behind',
    578 => 'Secondary Target',
    580 => 'Stamina Potential',
    581 => 'Stamina',
    582 => 'Distance Remaining',
    583 => 'Time Remaining',
    585 => 'Gauge Dist',
    586 => 'Altitude Chart',
    587 => 'Barometer Chart',
    588 => 'Heart Rate Chart',
    589 => 'Pace Chart',
    590 => 'Speed Chart',
    591 => 'Power Chart',
    597 => 'Gauge Time',
    610 => 'HR Zones Ratio',
    616 => 'Time Of Day Seconds',
    656 => 'Grade Adjusted Pace',
);

my %durationType = (
    0 => 'time',
    1 => 'Distance',
);

my %enduranceScoreLevel = (
    1 => 'Recreational',
    2 => 'Intermediate',
    3 => 'Trained',
    4 => 'Well-trained',
    5 => 'Expert',
    6 => 'Superior',
    7 => 'Elite',
);

my %ePOCPEStatus = (
    0 => 'Expired',
    1 => 'Current',
);

my %fairway = (
    0 => 'Left',
    1 => 'Right',
    2 => 'Hit',
);

my %genderX = (
    0 => 'Female',
    1 => 'Male',
    2 => 'Not Specified',
);

my %gPSType = (
    11 => 'Ultra Trac Trigger',
    49 => 'Mode Change',
);

my %guideText = (
    0 => 'Never Display',
    1 => 'Always Display',
    2 => 'When Navigating',
);

my %hillScoreLevel = (
    1 => 'Recreational',
    2 => 'Challenger',
    3 => 'Trained',
    4 => 'Skilled',
    5 => 'Expert',
    6 => 'Elite',
);

my %lightSectorsStatus = (
    0 => 'Off',
    1 => 'On',
    2 => 'Auto',
);

my %mapSymbol = (
    0 => 'Airport',
    1 => 'Amusement Park',
    2 => 'Anchor',
    3 => 'Ball Park',
    4 => 'Bank',
    5 => 'Bar',
    6 => 'Block Blue',
    7 => 'Boat Ramp',
    8 => 'Bowling',
    9 => 'Bridge',
    10 => 'Building',
    11 => 'Campground',
    12 => 'Car',
    13 => 'Car Rental',
    14 => 'Car Repair',
    15 => 'Cemetery',
    16 => 'Church',
    17 => 'City Large',
    18 => 'City Medium',
    19 => 'City Small',
    20 => 'Civil',
    21 => 'Controlled Area',
    22 => 'Convenience Store',
    23 => 'Crossing',
    24 => 'Dam',
    25 => 'Skull And Crossbones',
    26 => 'Danger Area',
    27 => 'Department Store',
    28 => 'Diver Down Flag 1',
    29 => 'Diver Down Flag 2',
    30 => 'Drinking Water',
    32 => 'Fast Food',
    33 => 'Fishing Area',
    34 => 'Fitness Center',
    35 => 'Forest',
    36 => 'Gas Station',
    37 => 'Glider Area',
    38 => 'Golf Course',
    39 => 'Lodging',
    40 => 'Hunting Area',
    41 => 'Information',
    42 => 'Live Theater',
    43 => 'Light',
    44 => 'Man Overboard',
    45 => 'Hospital 2',
    46 => 'Mine',
    47 => 'Movie Theater',
    48 => 'Museum',
    49 => 'Oil Field',
    50 => 'Parachute Area',
    51 => 'Park',
    52 => 'Parking 2',
    53 => 'Pharmacy',
    54 => 'Picnic Area',
    55 => 'Pizza',
    56 => 'Post Office',
    57 => 'Rv Park',
    58 => 'Residence',
    59 => 'Restricted Area',
    60 => 'Restaurant',
    61 => 'Restroom',
    62 => 'Scales',
    63 => 'Scenic Area',
    64 => 'School',
    65 => 'Shipwreck',
    66 => 'Shopping Center',
    67 => 'Short Tower',
    68 => 'Shower',
    69 => 'Skiing Area',
    70 => 'Stadium',
    71 => 'Summit',
    72 => 'Swimming Area',
    73 => 'Tall Tower',
    74 => 'Telephone',
    75 => 'Toll Booth',
    76 => 'Trail Head',
    77 => 'Truck Stop',
    78 => 'Tunnel',
    79 => 'Ultralight Area',
    80 => 'Zoo',
    81 => 'Geocache',
    82 => 'Geocache Found',
    83 => 'Flag Blue',
    84 => 'Pin Blue',
    85 => 'Bike Trail',
    86 => 'Ice Skating',
    88 => 'Beacon',
    89 => 'Horn',
    90 => 'Beach',
    91 => 'Buoy White',
    92 => 'Wrecker',
    93 => 'Navaid Amber',
    94 => 'Navaid Black',
    95 => 'Navaid Blue',
    96 => 'Navaid Green White',
    97 => 'Navaid Green',
    98 => 'Navaid Green Red',
    99 => 'Navaid Orange',
    100 => 'Navaid Red Green',
    101 => 'Navaid Red White',
    102 => 'Navaid Red',
    103 => 'Navaid Violet',
    104 => 'Navaid White',
    105 => 'Navaid White Green',
    106 => 'Navaid White Red',
    108 => 'Bell',
    109 => 'Block Green',
    110 => 'Block Red',
    111 => 'Food Source',
    116 => 'Flag Green',
    117 => 'Flag Red',
    118 => 'Pin Green',
    119 => 'Pin Red',
    120 => 'Atv',
    121 => 'Big Game',
    122 => 'Blind',
    123 => 'Blood Trail',
    124 => 'Cover',
    125 => 'Covey',
    127 => 'Furbearer',
    128 => 'Lodge',
    129 => 'Small Game',
    130 => 'Animal Tracks',
    131 => 'Treed Quarry',
    132 => 'Tree Stand',
    133 => 'Truck',
    134 => 'Upland Game',
    135 => 'Waterfowl',
    136 => 'Water Source',
);

my %navigationPrompt = (
    1 => 'Text Only',
    2 => 'Map',
);

my %openWaterEventType = (
    44 => 'Change Stroke',
);

my %orientation = (
    0 => 'North Up',
    1 => 'Track Up',
);

my %powerAveraging = (
    0 => 'Include Zeros',
    1 => 'Do Not Include Zeros',
);

my %powerSaveTimeout = (
    0 => 'Normal',
    1 => 'Extended',
);

my %recordMetric = (
    0 => 'time',
    1 => 'Distance',
    2 => 'Ascent',
    3 => 'Power',
);

my %reliefShading = (
    0 => 'Default',
    1 => 'Off',
    2 => 'On',
);

my %routeRecalculation = (
    0 => 'Automatic',
    1 => 'Off',
    2 => 'Prompted',
);

my %routingMode = (
    0 => 'Automobile Driving',
    1 => 'Road Cycling',
    2 => 'Pedestrian',
    4 => 'Mountain Biking',
    5 => 'Straight Line',
    6 => 'Motorcycle Driving',
    11 => 'Gravel Cycling',
    12 => 'Mixed Surface Cycling',
);

my %routingType = (
    0 => 'Bearing',
    1 => 'Course',
);

my %runningPowerMode = (
    0 => 'Off',
    1 => 'Accessory Mode',
    2 => 'Wrist Only',
    3 => 'Smart Mode',
);

my %satellites = (
    0 => 'Off',
    1 => 'GPS Only',
    2 => 'GPS Glonass',
    3 => 'Ultra Trac',
    5 => 'GPS Galileo',
    7 => 'All Systems',
    8 => 'All Multi Band',
    9 => 'Auto Select',
);

my %screenType = (
    21 => 'Clock',
    22 => 'HR Gauge',
    25 => 'Map',
    26 => 'Virtual Partner',
    27 => 'Run Dynamics',
    30 => 'Music',
    32 => 'Custom Lap Banner',
    35 => 'Compass',
    38 => 'Workout',
    44 => 'Altitude',
    56 => 'Segment',
    57 => 'Group Track List',
    74 => 'Lap Summary',
    104 => 'Climb Pro',
    109 => 'Track Laps',
    122 => 'Track Summary',
    127 => 'Stamina',
    162 => 'Group Ride',
);

my %selfEvaluationStatus = (
    0 => 'Off',
    1 => 'Workouts Only',
    2 => 'Always',
);

my %soundAndVibe = (
    0 => 'Off',
    1 => 'Tone',
    2 => 'Vibration',
    3 => 'Tone And Vibe',
);

my %sportChange = (
    0 => 'Manual Only',
    1 => 'On',
);

my %touchStatus = (
    0 => 'Off',
    1 => 'On',
    2 => 'System',
    3 => 'Map Only',
);

my %trainingReadinessLevel = (
    1 => 'Poor',
    2 => 'Low',
    3 => 'Moderate',
    4 => 'High',
    5 => 'Prime',
);

my %useStatus = (
    0 => 'Off',
    1 => 'Indoor',
    2 => 'Always',
);

my %visibilityStatus = (
    0 => 'Hide',
    1 => 'Show',
);

my %volume = (
    1 => 'Ounces',
    2 => 'Milliliters',
);

my %waypointAction = (
    0 => 'Add To Existing',
    1 => 'Replace Existing',
    2 => 'Delete All',
);

my %windDataStatus = (
    0 => 'Disabled',
    1 => 'Enabled',
);

my %yesNo = (
    0 => 'No',
    1 => 'Yes',
);

my %zoneMetric = (
    0 => 'Heart Rate',
    1 => 'Speed',
    2 => 'Cadence',
    3 => 'Power',
    4 => 'Elevation',
);

#----------------------------------------------------------------------
# Table of all supported Garmin FIT messages
#
%Image::ExifTool::Garmin::FIT = (
    GROUPS => { 0 => 'Garmin', 1 => 'File', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1, ALPHA_FIRST => 1 },
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
    vers => { Name => 'ProtocolVersion', Notes => 'from the FIT file header' },
    Common => {
        Name => 'Common',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Common' },
        Hidden => 2,
    },
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
    14 => { #4
        Name => 'DataScreen',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DataScreen' },
        Unknown => 1,
    },
    15 => {
        Name => 'Goal',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Goal' },
        Unknown => 1,
    },
    16 => { #4
        Name => 'Alert',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Alert' },
        Unknown => 1,
    },
    17 => { #4
        Name => 'RangeAlert',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::RangeAlert' },
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
    22 => { #4
        Name => 'DeviceUsed',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DeviceUsed' },
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
    29 => { #4
        Name => 'Location',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Location' },
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
    70 => { #4
        Name => 'MapLayer',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MapLayer' },
        Unknown => 1,
    },
    71 => { #4
        Name => 'Routing',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Routing' },
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
    79 => { #4
        Name => 'UserMetrics',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::UserMetrics' },
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
    89 => { #4
        Name => 'OpenWaterEvent',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::OpenWaterEvent' },
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
    104 => { #4
        Name => 'DeviceStatus',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::DeviceStatus' },
        Unknown => 1,
    },
    105 => 'Pad',
    106 => {
        Name => 'SlaveDevice',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SlaveDevice' },
        Unknown => 1,
    },
    113 => { #4
        Name => 'BestEffort',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::BestEffort' },
        Unknown => 1,
    },
    114 => { #4
        Name => 'PersonalRecord',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::PersonalRecord' },
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
    140 => { #4
        Name => 'ActivityMetrics',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ActivityMetrics' },
        Unknown => 1,
    },
    141 => { #4
        Name => 'EPOStatus',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::EPOStatus' },
        Unknown => 1,
    },
    142 => {
        Name => 'SegmentLap',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SegmentLap' },
    },
    143 => { #4
        Name => 'MultisportSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MultisportSettings' },
        Unknown => 1,
    },
    144 => { #4
        Name => 'MultisportActivity',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MultisportActivity' },
        Unknown => 1,
    },
    145 => {
        Name => 'MemoGlob',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MemoGlob' },
        Unknown => 1,
    },
    147 => { #4
        Name => 'SensorSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SensorSettings' },
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
    152 => { #4
        Name => 'Metronome',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Metronome' },
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
    170 => { #4
        Name => 'ConnectIQField',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ConnectIQField' },
        Unknown => 1,
    },
    173 => { #4
        Name => 'Clubs',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Clubs' },
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
    189 => { #4
        Name => 'WaypointHandling',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WaypointHandling' },
        Unknown => 1,
    },
    190 => { #4
        Name => 'GolfCourse',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::GolfCourse' },
        Unknown => 1,
    },
    191 => { #4
        Name => 'GolfStats',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::GolfStats' },
        Unknown => 1,
    },
    192 => { #4
        Name => 'Score',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Score' },
        Unknown => 1,
    },
    193 => { #4
        Name => 'Hole',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Hole' },
        Unknown => 1,
    },
    194 => { #4
        Name => 'Shot',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Shot' },
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
    222 => { #4
        Name => 'AlarmSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::AlarmSettings' },
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
    243 => { #4
        Name => 'MusicInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MusicInfo' },
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
    273 => { #4
        Name => 'SleepDataInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepDataInfo' },
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
    309 => { #4
        Name => 'MtbCx',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::MtbCx' },
        Unknown => 1,
    },
    310 => { #4
        Name => 'Race',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::Race' },
        Unknown => 1,
    },
    311 => { #4
        Name => 'SplitTime',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SplitTime' },
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
    321 => { #4
        Name => 'PowerMode',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::PowerMode' },
        Unknown => 1,
    },
    323 => {
        Name => 'TankSummary',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TankSummary' },
        Unknown => 1,
    },
    326 => { #4
        Name => 'GPSEvent',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::GPSEvent' },
        Unknown => 1,
    },
    336 => { #4
        Name => 'ECGSummary',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ECGSummary' },
        Unknown => 1,
    },
    337 => { #4
        Name => 'ECGRawSample',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ECGRawSample' },
        Unknown => 1,
    },
    338 => { #4
        Name => 'ECGSmoothSample',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::ECGSmoothSample' },
        Unknown => 1,
    },
    346 => {
        Name => 'SleepAssessment',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepAssessment' },
        Unknown => 1,
    },
    356 => { #4
        Name => 'FunctionalMetrics',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::FunctionalMetrics' },
        Unknown => 1,
    },
    358 => { #4
        Name => 'RaceEvent',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::RaceEvent' },
        Unknown => 1,
    },
    369 => { #4
        Name => 'TrainingReadiness',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TrainingReadiness' },
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
    378 => { #4
        Name => 'TrainingLoad',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::TrainingLoad' },
        Unknown => 1,
    },
    379 => { #4
        Name => 'SleepSchedule',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepSchedule' },
        Unknown => 1,
    },
    382 => { #4
        Name => 'SleepRestlessMoments',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SleepRestlessMoments' },
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
    394 => { #4
        Name => 'CPEStatus',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::CPEStatus' },
        Unknown => 1,
    },
    398 => {
        Name => 'SkinTempOvernight',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::SkinTempOvernight' },
        Unknown => 1,
    },
    402 => { #4
        Name => 'HillScore',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::HillScore' },
        Unknown => 1,
    },
    403 => { #4
        Name => 'EnduranceScore',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::EnduranceScore' },
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
    428 => { #4
        Name => 'WorkoutSchedule',
        SubDirectory => { TagTable => 'Image::ExifTool::Garmin::WorkoutSchedule' },
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
    NOTES => 'Tags listed here are common to all FIT messages (ie. all tag tables below).',
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

#----------------------------------------------------------------------
# This first group of tables are from the offical Garmin documentation (ref 2)
#
%Image::ExifTool::Garmin::FileID = (
    GROUPS => { 0 => 'Garmin', 1 => 'FileID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FITFileType', PrintConv => \%file, SeparateTable => 'File' },
    1 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
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
    3 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    4 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    5 => { Name => 'SystemTimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
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
    0 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
    1 => 'Product',
);

%Image::ExifTool::Garmin::Capabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'Capabilities', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Languages', # [N]
    1 => 'Sports', # [N]
    21 => { Name => 'WorkoutsSupported', PrintConv => \%workoutCapabilities, SeparateTable => 'WorkoutCapabilities' },
    23 => { Name => 'ConnectivitySupported', PrintConv => \%connectivityCapabilities },
);

%Image::ExifTool::Garmin::FileCapabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'FileCaps', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FileCapabilitiesType', PrintConv => \%file, SeparateTable => 'File' },
    1 => { Name => 'Flags', PrintConv => \%fileFlags },
    2 => 'Directory',
    3 => 'MaxCount',
    4 => { Name => 'MaxSize', PrintConv => '"$val bytes"' },
);

%Image::ExifTool::Garmin::MesgCapabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'MesgCaps', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'File', PrintConv => \%file, SeparateTable => 'File' },
    1 => { Name => 'MesgNum', PrintConv => \%mesgNum, SeparateTable => 'MesgNum' },
    2 => { Name => 'CountType', PrintConv => \%mesgCount },
    3 => 'Count',
);

%Image::ExifTool::Garmin::FieldCapabilities = (
    GROUPS => { 0 => 'Garmin', 1 => 'FieldCaps', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'File', PrintConv => \%file, SeparateTable => 'File' },
    1 => { Name => 'MesgNum', PrintConv => \%mesgNum, SeparateTable => 'MesgNum' },
    2 => 'FieldNum',
    3 => 'Count',
);

%Image::ExifTool::Garmin::DeviceSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'DeviceSettings', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ActiveTimeZone',
    1 => 'UtcOffset',
    2 => 'TimeOffset', # [N] s
    4 => 'TimeMode', # [N]
    5 => 'TimeZoneOffset', # [N] / 4 hr
    8 => 'AlarmsTime', #4 [N] s
    12 => { Name => 'BacklightMode', PrintConv => \%backlightMode },
    28 => 'AlarmsEnabled', #4 [N]
    36 => 'ActivityTrackerEnabled',
    39 => { Name => 'ClockTime', %timeInfo, Groups => { 2 => 'Time' } },
    40 => 'PagesEnabled', # [N]
    46 => 'MoveAlertEnabled',
    47 => { Name => 'DateMode', PrintConv => \%dateMode },
    55 => { Name => 'DisplayOrientation', PrintConv => \%displayOrientation, SeparateTable => 'DisplayOrientation' },
    56 => { Name => 'MountingSide', PrintConv => \%side },
    57 => 'DefaultPage', # [N]
    58 => { Name => 'AutosyncMinSteps', PrintConv => '"$val steps"' },
    59 => { Name => 'AutosyncMinTime', PrintConv => '"$val minutes"' },
    80 => 'LactateThresholdAutodetectEnabled',
    86 => 'BleAutoUploadEnabled',
    89 => { Name => 'AutoSyncFrequency', PrintConv => \%autoSyncFrequency },
    90 => 'AutoActivityDetect',
    92 => 'AlarmsRepeat', #4 [N]
    94 => 'NumberOfScreens',
    95 => { Name => 'SmartNotificationDisplayOrientation', PrintConv => \%displayOrientation, SeparateTable => 'DisplayOrientation' },
    134 => { Name => 'TapInterface', PrintConv => \%switch, SeparateTable => 'Switch' },
    174 => { Name => 'TapSensitivity', PrintConv => \%tapSensitivity },
);

%Image::ExifTool::Garmin::UserProfile = (
    GROUPS => { 0 => 'Garmin', 1 => 'UserProfile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'FriendlyName',
    1 => { Name => 'Gender', PrintConv => \%gender, SeparateTable => 'Gender' },
    2 => { Name => 'Age', PrintConv => '"$val years"' },
    3 => { Name => 'Height', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => { Name => 'Weight', ValueConv => '$val / 10', PrintConv => '"$val kg"' },
    5 => { Name => 'Language', PrintConv => \%language, PrintConvColumns => 2 },
    6 => { Name => 'ElevSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    7 => { Name => 'WeightSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    8 => { Name => 'RestingHeartRate', PrintConv => '"$val bpm"' },
    9 => { Name => 'DefaultMaxRunningHeartRate', PrintConv => '"$val bpm"' },
    10 => { Name => 'DefaultMaxBikingHeartRate', PrintConv => '"$val bpm"' },
    11 => { Name => 'DefaultMaxHeartRate', PrintConv => '"$val bpm"' },
    12 => { Name => 'HRSetting', PrintConv => \%displayHeart },
    13 => { Name => 'SpeedSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    14 => { Name => 'DistSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    16 => { Name => 'PowerSetting', PrintConv => \%displayPower },
    17 => { Name => 'ActivityClass', PrintConv => \%activityClass },
    18 => { Name => 'PositionSetting', PrintConv => \%displayPosition, PrintConvColumns => 2 },
    21 => { Name => 'TemperatureSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    22 => 'LocalID',
    23 => 'GlobalID', # [6]
    24 => { Name => 'YearOfBirth', ValueConv => '$val - -1900' }, #4
    28 => 'WakeTime',
    29 => 'SleepTime',
    30 => { Name => 'HeightSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    31 => { Name => 'UserRunningStepLength', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    32 => { Name => 'UserWalkingStepLength', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    37 => { Name => 'Ltspeed', ValueConv => '$val / 10', PrintConv => '"$val km/h"' }, #4
    41 => { Name => 'TimeLast-LthrUpdate', %timeInfo, Groups => { 2 => 'Time' } }, #4
    47 => { Name => 'DepthSetting', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    49 => 'DiveCount',
    62 => { Name => 'GenderX', PrintConv => \%genderX }, #4
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
    0 => 'BikeProfileName',
    1 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    2 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
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
    19 => { Name => 'CrankLength', ValueConv => '$val / 2 - -110', PrintConv => '"$val mm"' },
    20 => 'Enabled',
    21 => 'BikeSpdAntIDTransType',
    22 => 'BikeCadAntIDTransType',
    23 => 'BikeSpdcadAntIDTransType',
    24 => 'BikePowerAntIDTransType',
    37 => 'OdometerRollover',
    38 => 'FrontGearNum',
    39 => 'FrontGear', # [N]
    40 => 'RearGearNum',
    41 => 'RearGear', # [N]
    44 => 'ShimanoDi2Enabled',
);

%Image::ExifTool::Garmin::Connectivity = (
    GROUPS => { 0 => 'Garmin', 1 => 'Connectivity', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'BluetoothEnabled',
    1 => 'BluetoothLeEnabled',
    2 => 'AntEnabled',
    3 => 'ConnectivityName',
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
    0 => { Name => 'Mode', PrintConv => \%watchfaceMode },
    1 => 'Layout',
);

%Image::ExifTool::Garmin::OHRSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'OHRSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Enabled', PrintConv => \%switch, SeparateTable => 'Switch' },
);

%Image::ExifTool::Garmin::TimeInZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'TimeInZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ReferenceMesg', PrintConv => \%mesgNum, SeparateTable => 'MesgNum' },
    1 => 'ReferenceIndex',
    2 => 'TimeInHRZone', # [N] / 1000 s
    3 => 'TimeInSpeedZone', # [N] / 1000 s
    4 => 'TimeInCadenceZone', # [N] / 1000 s
    5 => 'TimeInPowerZone', # [N] / 1000 s
    6 => 'HRZoneHighBoundary', # [N] bpm
    7 => 'SpeedZoneHighBoundary', # [N] / 1000 m/s
    8 => 'CadenceZoneHighBondary', # [N] rpm
    9 => 'PowerZoneHighBoundary', # [N] watts
    10 => { Name => 'HRCalcType', PrintConv => \%hRZoneCalc, SeparateTable => 'HRZoneCalc' },
    11 => 'MaxHeartRate',
    12 => 'RestingHeartRate',
    13 => 'ThresholdHeartRate',
    14 => { Name => 'PwrCalcType', PrintConv => \%pwrZoneCalc, SeparateTable => 'PwrZoneCalc' },
    15 => 'FunctionalThresholdPower',
);

%Image::ExifTool::Garmin::ZonesTarget = (
    GROUPS => { 0 => 'Garmin', 1 => 'ZonesTarget', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'MaxHeartRate',
    2 => 'ThresholdHeartRate',
    3 => 'FunctionalThresholdPower',
    5 => { Name => 'HRCalcType', PrintConv => \%hRZoneCalc, SeparateTable => 'HRZoneCalc' },
    7 => { Name => 'PwrCalcType', PrintConv => \%pwrZoneCalc, SeparateTable => 'PwrZoneCalc' },
);

%Image::ExifTool::Garmin::Sport = (
    GROUPS => { 0 => 'Garmin', 1 => 'Sport', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    1 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
    3 => 'SportName',
    15 => { Name => 'PopularityRouting', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    17 => { Name => 'NavigationPrompt', PrintConv => \%navigationPrompt }, #4
    18 => { Name => 'SharpBendWarnings', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    21 => { Name => 'WorkoutVideos', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    22 => { Name => 'HighTrafficRoadWarnings', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    23 => { Name => 'RoadHazardWarnings', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    24 => { Name => 'UnpavedRoadWarnings', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
);

%Image::ExifTool::Garmin::HRZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'HighBpm', PrintConv => '"$val bpm"' },
    2 => 'HRZoneName',
);

%Image::ExifTool::Garmin::SpeedZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'SpeedZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'HighValue', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    1 => 'SpeedZoneName',
);

%Image::ExifTool::Garmin::CadenceZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'CadenceZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'HighValue', PrintConv => '"$val rpm"' },
    1 => 'CadenceZoneName',
);

%Image::ExifTool::Garmin::PowerZone = (
    GROUPS => { 0 => 'Garmin', 1 => 'PowerZone', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'HighValue', PrintConv => '"$val watts"' },
    2 => 'PowerZoneName',
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
    2 => { Name => 'VirtualPartnerPace', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    3 => { Name => 'AutoLapMode', PrintConv => \%autoLapMode }, #4
    4 => { Name => 'AutoLapDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' }, #4
    7 => { Name => 'AutoPause', PrintConv => \%autoPauseSetting }, #4
    8 => { Name => 'AutoPauseThreshold', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    12 => { Name => 'PowerAveraging', PrintConv => \%powerAveraging }, #4
    15 => { Name => 'AutoScroll', PrintConv => \%autoScrollMode }, #4
    18 => { Name => 'TimerStartPrompt', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    22 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' }, #4
    25 => { Name => 'AutoSleep', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    27 => { Name => 'Satellites', PrintConv => \%satellites }, #4
    31 => { Name => 'TargetDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    32 => { Name => 'TargetSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    33 => { Name => 'TargetTime', PrintConv => '"$val s"' },
    35 => { Name => 'ThreeDSpeed', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    36 => { Name => 'ThreeDDistance', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    37 => { Name => 'AutoClimb', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    40 => { Name => 'AutoClimbInvertColors', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    41 => { Name => 'AutoClimbVerticalSpeed', ValueConv => '$val / 27.778', PrintConv => '"$val m/h"' }, #4
    42 => { Name => 'AutoClimbModeSwitch', PrintConv => '"$val s"' }, #4
    46 => { Name => 'LapKey', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    50 => { Name => 'WorkoutTargetAlerts', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    51 => { Name => 'TimerStartAuto', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    52 => { Name => 'TimerStartSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    53 => { Name => 'SegmentAlerts', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    57 => { Name => 'CountdownStart', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    63 => { Name => 'ClimbPro', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    67 => { Name => 'TrackConsumption', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    69 => 'BottleSize', #4
    70 => { Name => 'Volume', PrintConv => \%volume }, #4
    80 => { Name => 'MinimumRideDuration', PrintConv => '"$val s"' }, #4
    86 => 'LaneNumber', #4
    87 => { Name => 'BroadcastHeartRate', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    93 => { Name => 'SelfEvaluation', PrintConv => \%selfEvaluationStatus }, #4
    102 => { Name => 'SpeedPro', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    103 => { Name => 'Touch', PrintConv => \%touchStatus }, #4
    106 => { Name => 'RecordTemperature', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    109 => { Name => 'RunningPowerMode', PrintConv => \%runningPowerMode }, #4
    110 => { Name => 'AccountForWind', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    111 => { Name => 'ClimbProMode', PrintConv => \%climbProMode }, #4
    117 => { Name => 'ClimbDetection', PrintConv => \%climbDetection }, #4
    119 => { Name => 'ClimbProTerrain', PrintConv => \%climbProTerrain }, #4
    153 => { Name => 'PreciseTargetSpeed', ValueConv => '$val / 1000000', PrintConv => '"$val m/s"' },
    1001 => { Name => 'GPS', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    1002 => { Name => 'Glonass', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    1003 => { Name => 'Galileo', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
    1004 => { Name => 'Beidou', PrintConv => \%switch, SeparateTable => 'Switch' }, #4
);

%Image::ExifTool::Garmin::DiveSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'DiveSettingsName',
    1 => { Name => 'Model', PrintConv => \%tissueModelType },
    2 => { Name => 'GfLow', PrintConv => '"$val %"' },
    3 => { Name => 'GfHigh', PrintConv => '"$val %"' },
    4 => { Name => 'WaterType', PrintConv => \%waterType },
    5 => { Name => 'WaterDensity', PrintConv => '"$val kg/m^3"' },
    6 => { Name => 'PO2Warn', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    7 => { Name => 'PO2Critical', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    8 => { Name => 'PO2Deco', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    9 => 'SafetyStopEnabled',
    10 => 'BottomDepth',
    11 => 'BottomTime',
    12 => 'ApneaCountdownEnabled',
    13 => 'ApneaCountdownTime',
    14 => { Name => 'BacklightMode', PrintConv => \%diveBacklightMode },
    15 => 'BacklightBrightness',
    16 => { Name => 'BacklightTimeout', PrintConv => \%backlightTimeout },
    17 => { Name => 'RepeatDiveInterval', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    18 => { Name => 'SafetyStopTime', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    19 => { Name => 'HeartRateSourceType', PrintConv => \%sourceType, SeparateTable => 'SourceType' },
    20 => 'HeartRateSource',
    21 => 'TravelGas',
    22 => { Name => 'CCRLowSetpointSwitchMode', PrintConv => \%cCRSetpointSwitchMode, SeparateTable => 'CCRSetpointSwitchMode' },
    23 => { Name => 'CCRLowSetpoint', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    24 => { Name => 'CCRLowSetpointDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    25 => { Name => 'CCRHighSetpointSwitchMode', PrintConv => \%cCRSetpointSwitchMode, SeparateTable => 'CCRSetpointSwitchMode' },
    26 => { Name => 'CCRHighSetpoint', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    27 => { Name => 'CCRHighSetpointDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    29 => { Name => 'GasConsumptionDisplay', PrintConv => \%gasConsumptionRateType },
    30 => 'UpKeyEnabled',
    35 => { Name => 'DiveSounds', PrintConv => \%tone, SeparateTable => 'Tone' },
    36 => { Name => 'LastStopMultiple', ValueConv => '$val / 10' },
    37 => { Name => 'NoFlyTimeMode', PrintConv => \%noFlyTimeMode },
);

%Image::ExifTool::Garmin::DiveAlarm = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveAlarm', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Depth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    1 => { Name => 'Time', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    2 => 'Enabled',
    3 => { Name => 'AlarmType', PrintConv => \%diveAlarmType, SeparateTable => 'DiveAlarmType' },
    4 => { Name => 'Sound', PrintConv => \%tone, SeparateTable => 'Tone' },
    5 => 'DiveTypes', # [N]
    6 => 'ID',
    7 => 'PopupEnabled',
    8 => 'TriggerOnDescent',
    9 => 'TriggerOnAscent',
    10 => 'Repeating',
    11 => { Name => 'Speed', ValueConv => '$val / 1000', PrintConv => '"$val mps"' },
);

%Image::ExifTool::Garmin::DiveApneaAlarm = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveApneaAlarm', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Depth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    1 => { Name => 'Time', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    2 => 'Enabled',
    3 => { Name => 'AlarmType', PrintConv => \%diveAlarmType, SeparateTable => 'DiveAlarmType' },
    4 => { Name => 'Sound', PrintConv => \%tone, SeparateTable => 'Tone' },
    5 => 'DiveTypes', # [N]
    6 => 'ID',
    7 => 'PopupEnabled',
    8 => 'TriggerOnDescent',
    9 => 'TriggerOnAscent',
    10 => 'Repeating',
    11 => { Name => 'Speed', ValueConv => '$val / 1000', PrintConv => '"$val mps"' },
);

%Image::ExifTool::Garmin::DiveGas = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveGas', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'HeliumContent', PrintConv => '"$val %"' },
    1 => { Name => 'OxygenContent', PrintConv => '"$val %"' },
    2 => { Name => 'Status', PrintConv => \%diveGasStatus },
    3 => { Name => 'Mode', PrintConv => \%diveGasMode },
);

%Image::ExifTool::Garmin::Goal = (
    GROUPS => { 0 => 'Garmin', 1 => 'Goal', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    1 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
    2 => { Name => 'StartDate', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'EndDate', %timeInfo, Groups => { 2 => 'Time' } },
    4 => { Name => 'GoalType', PrintConv => \%goalEnum },
    5 => 'Value',
    6 => 'Repeat',
    7 => 'TargetValue',
    8 => { Name => 'Recurrence', PrintConv => \%goalRecurrence },
    9 => 'RecurrenceValue',
    10 => 'Enabled',
    11 => { Name => 'Source', PrintConv => \%goalSource },
);

%Image::ExifTool::Garmin::Activity = (
    GROUPS => { 0 => 'Garmin', 1 => 'Activity', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    1 => 'NumSessions',
    2 => { Name => 'ActivityType', PrintConv => \%activityEnum },
    3 => { Name => 'Event', PrintConv => \%eventEnum, SeparateTable => 'EventEnum' },
    4 => { Name => 'EventType', PrintConv => \%eventType, SeparateTable => 'EventType' },
    5 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    6 => 'EventGroup',
);

%Image::ExifTool::Garmin::Session = (
    GROUPS => { 0 => 'Garmin', 1 => 'Session', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Event', PrintConv => \%eventEnum, SeparateTable => 'EventEnum' },
    1 => { Name => 'EventType', PrintConv => \%eventType, SeparateTable => 'EventType' },
    2 => { Name => 'GPSDateTime', %timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time', IsTimeStamp => 1 },
    3 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_lat' },
    4 => { Name => 'GPSLongitude', %lonInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_long' },
    5 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    6 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
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
    28 => { Name => 'Trigger', PrintConv => \%sessionTrigger },
    29 => { Name => 'NECLatitude',  %latInfo, Groups => { 2 => 'Location' } },
    30 => { Name => 'NECLongitude', %lonInfo, Groups => { 2 => 'Location' } },
    31 => { Name => 'SWCLatitude',  %latInfo, Groups => { 2 => 'Location' } },
    32 => { Name => 'SWCLongitude', %lonInfo, Groups => { 2 => 'Location' } },
    33 => { Name => 'NumLengths', PrintConv => '"$val lengths"' },
    34 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' },
    35 => { Name => 'TrainingStressScore', ValueConv => '$val / 10', PrintConv => '"$val tss"' },
    36 => { Name => 'IntensityFactor', ValueConv => '$val / 1000', PrintConv => '"$val if"' },
    37 => 'LeftRightBalance',
    38 => { Name => 'GPSDestLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_lat' },
    39 => { Name => 'GPSDestLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_long' },
    41 => { Name => 'AvgStrokeCount', ValueConv => '$val / 10', PrintConv => '"$val strokes/lap"' },
    42 => { Name => 'AvgStrokeDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    43 => { Name => 'SwimStroke', PrintConv => \%swimStroke, SeparateTable => 'SwimStroke' },
    44 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    45 => { Name => 'ThresholdPower', PrintConv => '"$val watts"' },
    46 => { Name => 'PoolLengthUnit', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
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
    65 => 'TimeInHRZone', # [N] / 1000 s
    66 => 'TimeInSpeedZone', # [N] / 1000 s
    67 => 'TimeInCadenceZone', # [N] / 1000 s
    68 => 'TimeInPowerZone', # [N] / 1000 s
    69 => { Name => 'AvgLapTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    70 => 'BestLapIndex',
    71 => { Name => 'MinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    78 => { Name => 'WorkTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' }, #4
    79 => { Name => 'AvgSwimCadence', ValueConv => '$val / 10', PrintConv => '"$val strokes/length"' }, #4
    80 => 'AvgSwolf', #4
    82 => 'PlayerScore',
    83 => 'OpponentScore',
    84 => 'OpponentName',
    85 => 'StrokeCount', # [N] counts
    86 => 'ZoneCount', # [N] counts
    87 => { Name => 'MaxBallSpeed', ValueConv => '$val / 100', PrintConv => '"$val m/s"' },
    88 => { Name => 'AvgBallSpeed', ValueConv => '$val / 100', PrintConv => '"$val m/s"' },
    89 => { Name => 'AvgVerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    90 => { Name => 'AvgStanceTimePercent', ValueConv => '$val / 100', PrintConv => '"$val %"' },
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
    101 => { Name => 'AvgLeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    102 => { Name => 'AvgRightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    103 => { Name => 'AvgLeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    104 => { Name => 'AvgRightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    105 => { Name => 'AvgCombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
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
    131 => { Name => 'LevBatteryConsumption', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    132 => { Name => 'AvgVerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    133 => { Name => 'AvgStanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    134 => { Name => 'AvgStepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    137 => { Name => 'TotalAnaerobicTrainingEffect', ValueConv => '$val / 10' },
    139 => { Name => 'AvgVam', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    140 => { Name => 'AvgDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    141 => { Name => 'MaxDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    142 => { Name => 'SurfaceInterval', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    143 => { Name => 'StartCns', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    144 => { Name => 'EndCns', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    145 => { Name => 'StartN2', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    146 => { Name => 'EndN2', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    147 => 'AvgRespirationRate',
    148 => 'MaxRespirationRate',
    149 => 'MinRespirationRate',
    150 => { Name => 'MinTemperature', PrintConv => '"$val C"' },
    151 => 'TotalSets', #4
    152 => { Name => 'Volume', ValueConv => '$val / 100', PrintConv => '"$val kg"' }, #4
    155 => { Name => 'O2Toxicity', PrintConv => '"$val OTUs"' },
    156 => 'DiveNumber',
    168 => { Name => 'TrainingLoadPeak', ValueConv => '$val / 65536' },
    169 => { Name => 'EnhancedAvgRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    170 => { Name => 'EnhancedMaxRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    177 => 'CaloriesConsumed', #4
    178 => { Name => 'EstSweatLoss', PrintConv => '"$val ml"' }, #4
    179 => { Name => 'FluidConsumed', PrintConv => '"$val ml"' }, #4
    180 => { Name => 'EnhancedMinRespirationRate', ValueConv => '$val / 100' },
    181 => { Name => 'TotalGrit', PrintConv => '"$val kGrit"' },
    182 => { Name => 'TotalFlow', PrintConv => '"$val Flow"' },
    183 => 'JumpCount',
    185 => { Name => 'ExecutionScore', PrintConv => '"$val %"' }, #4
    186 => { Name => 'AvgGrit', PrintConv => '"$val kGrit"' },
    187 => { Name => 'AvgFlow', PrintConv => '"$val Flow"' },
    188 => { Name => 'PrimaryBenefit', PrintConv => \%benefit, SeparateTable => 'Benefit' }, #4
    192 => 'WorkoutFeel',
    193 => 'WorkoutRpe',
    194 => { Name => 'AvgSPO2', PrintConv => '"$val %"' },
    195 => { Name => 'AvgStress', PrintConv => '"$val %"' },
    196 => { Name => 'MetabolicCalories', PrintConv => '"$val kcal"' },
    197 => { Name => 'SDRRHRV', PrintConv => '"$val mS"' },
    198 => { Name => 'RMSSD_HRV', PrintConv => '"$val mS"' },
    199 => { Name => 'TotalFractionalAscent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    200 => { Name => 'TotalFractionalDescent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    202 => 'RecoveryHeartRate', #4
    205 => 'BeginningPotential', #4
    206 => 'EndingPotential', #4
    207 => 'MinStamina', #4
    208 => { Name => 'AvgCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    209 => { Name => 'MinCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    210 => { Name => 'MaxCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    211 => { Name => 'GradeAdjustedSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    212 => { Name => 'WindData', PrintConv => \%windDataStatus }, #4
    215 => 'BeginningBodyBattery', #4
    216 => 'EndingBodyBattery', #4
    220 => { Name => 'PackWeight', ValueConv => '$val / 10', PrintConv => '"$val kg"' }, #4
    222 => { Name => 'StepSpeedLossDistance', ValueConv => '$val / 100', PrintConv => '"$val cm/s"' }, #4
    223 => { Name => 'StepSpeedLossPercent', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
    224 => { Name => 'AvgForce', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
    225 => { Name => 'MaxForce', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
    226 => { Name => 'NormalizedForce', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
);

%Image::ExifTool::Garmin::Lap = (
    GROUPS => { 0 => 'Garmin', 1 => 'Lap', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Event', PrintConv => \%eventEnum, SeparateTable => 'EventEnum' },
    1 => { Name => 'EventType', PrintConv => \%eventType, SeparateTable => 'EventType' },
    2 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time', IsTimeStamp => 1 },
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
    23 => { Name => 'Intensity', PrintConv => \%intensity, SeparateTable => 'Intensity' },
    24 => { Name => 'LapTrigger', PrintConv => \%lapTrigger },
    25 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    26 => 'EventGroup',
    27 => { Name => 'NECLatitude',  %latInfo, Groups => { 2 => 'Location' } }, #4
    28 => { Name => 'NECLongitude', %lonInfo, Groups => { 2 => 'Location' } }, #4
    29 => { Name => 'SWCLatitude',  %latInfo, Groups => { 2 => 'Location' } }, #4
    30 => { Name => 'SWCLongitude', %lonInfo, Groups => { 2 => 'Location' } }, #4
    32 => { Name => 'NumLengths', PrintConv => '"$val lengths"' },
    33 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' },
    34 => 'LeftRightBalance',
    35 => 'FirstLengthIndex',
    37 => { Name => 'AvgStrokeDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    38 => { Name => 'SwimStroke', PrintConv => \%swimStroke, SeparateTable => 'SwimStroke' },
    39 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
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
    57 => 'TimeInHRZone', # [N] / 1000 s
    58 => 'TimeInSpeedZone', # [N] / 1000 s
    59 => 'TimeInCadenceZone', # [N] / 1000 s
    60 => 'TimeInPowerZone', # [N] / 1000 s
    61 => 'RepetitionNum',
    62 => { Name => 'MinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    63 => { Name => 'MinHeartRate', PrintConv => '"$val bpm"' },
    71 => 'WktStepIndex',
    73 => 'AvgSwolf', #4
    74 => 'OpponentScore',
    75 => 'StrokeCount', # [N] counts
    76 => 'ZoneCount', # [N] counts
    77 => { Name => 'AvgVerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    78 => { Name => 'AvgStanceTimePercent', ValueConv => '$val / 100', PrintConv => '"$val %"' },
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
    91 => { Name => 'AvgLeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    92 => { Name => 'AvgRightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    93 => { Name => 'AvgLeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    94 => { Name => 'AvgRightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    95 => { Name => 'AvgCombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
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
    117 => { Name => 'LevBatteryConsumption', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    118 => { Name => 'AvgVerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    119 => { Name => 'AvgStanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    120 => { Name => 'AvgStepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    121 => { Name => 'AvgVam', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    122 => { Name => 'AvgDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    123 => { Name => 'MaxDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    124 => { Name => 'MinTemperature', PrintConv => '"$val C"' },
    136 => { Name => 'EnhancedAvgRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    137 => { Name => 'EnhancedMaxRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    145 => 'EstSweatLoss', #4
    147 => 'AvgRespirationRate',
    148 => 'MaxRespirationRate',
    149 => { Name => 'TotalGrit', PrintConv => '"$val kGrit"' },
    150 => { Name => 'TotalFlow', PrintConv => '"$val Flow"' },
    151 => 'JumpCount',
    152 => { Name => 'ExecutionScore', PrintConv => '"$val %"' }, #4
    153 => { Name => 'AvgGrit', PrintConv => '"$val kGrit"' },
    154 => { Name => 'AvgFlow', PrintConv => '"$val Flow"' },
    155 => { Name => 'RestingCalories', PrintConv => '"$val kcal"' }, #4
    156 => { Name => 'TotalFractionalAscent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    157 => { Name => 'TotalFractionalDescent', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    158 => { Name => 'AvgCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    159 => { Name => 'MinCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    160 => { Name => 'MaxCoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    161 => { Name => 'GradeAdjustedSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    163 => { Name => 'Unpaved', PrintConv => '"$val %"' }, #4
    164 => { Name => 'StepSpeedLossDistance', ValueConv => '$val / 100', PrintConv => '"$val cm/s"' }, #4
    165 => { Name => 'StepSpeedLossPercentage', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
    166 => { Name => 'AvgForce', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
    167 => { Name => 'MaxForce', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
    168 => { Name => 'NormalizedForce', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
);

%Image::ExifTool::Garmin::Length = (
    GROUPS => { 0 => 'Garmin', 1 => 'Length', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Event', PrintConv => \%eventEnum, SeparateTable => 'EventEnum' },
    1 => { Name => 'EventType', PrintConv => \%eventType, SeparateTable => 'EventType' },
    2 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    4 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    5 => { Name => 'TotalStrokes', PrintConv => '"$val strokes"' },
    6 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    7 => { Name => 'SwimStroke', PrintConv => \%swimStroke, SeparateTable => 'SwimStroke' },
    9 => { Name => 'AvgSwimmingCadence', PrintConv => '"$val strokes/min"' },
    10 => 'EventGroup',
    11 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    12 => { Name => 'LengthType', PrintConv => \%lengthType },
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
    8 => 'CompressedSpeedDistance', # [3] / 100,16 m/s,m
    9 => { Name => 'Grade', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    10 => 'Resistance',
    11 => { Name => 'TimeFromCourse', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    12 => { Name => 'CycleLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    13 => { Name => 'Temperature', PrintConv => '"$val C"' },
    17 => 'Speed_1s', # [N] / 16 m/s
    18 => { Name => 'Cycles', PrintConv => '"$val cycles"' },
    19 => { Name => 'TotalCycles', PrintConv => '"$val cycles"' },
    28 => { Name => 'CompressedAccumulatedPower', PrintConv => '"$val watts"' },
    29 => { Name => 'AccumulatedPower', PrintConv => '"$val watts"' },
    30 => 'LeftRightBalance',
    31 => { Name => 'GPSAccuracy', PrintConv => '"$val m"' },
    32 => { Name => 'VerticalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    33 => { Name => 'Calories', PrintConv => '"$val kcal"' },
    39 => { Name => 'VerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    40 => { Name => 'StanceTimePercent', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    41 => { Name => 'StanceTime', ValueConv => '$val / 10', PrintConv => '"$val ms"' },
    42 => { Name => 'ActivityType', PrintConv => \%activityType, SeparateTable => 'ActivityType' },
    43 => { Name => 'LeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    44 => { Name => 'RightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    45 => { Name => 'LeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    46 => { Name => 'RightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    47 => { Name => 'CombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    48 => { Name => 'Time128', ValueConv => '$val / 128', PrintConv => '"$val s"' },
    49 => { Name => 'StrokeType', PrintConv => \%strokeType },
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
    62 => { Name => 'DeviceIndex', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    67 => { Name => 'LeftPco', PrintConv => '"$val mm"' },
    68 => { Name => 'RightPco', PrintConv => '"$val mm"' },
    69 => 'LeftPowerPhase', # [N] / 0.7111111 degrees
    70 => 'LeftPowerPhasePeak', # [N] / 0.7111111 degrees
    71 => 'RightPowerPhase', # [N] / 0.7111111 degrees
    72 => 'RightPowerPhasePeak', # [N] / 0.7111111 degrees
    73 =>{ Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_speed' },
    78 =>{ Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_altitude' },
    81 => { Name => 'BatterySoc', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    82 => { Name => 'MotorPower', PrintConv => '"$val watts"' },
    83 => { Name => 'VerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    84 => { Name => 'StanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    85 => { Name => 'StepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' },
    87 => { Name => 'CycleLength16', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    90 => 'PerformanceCondition', #4
    91 => { Name => 'AbsolutePressure', PrintConv => '"$val Pa"' },
    92 => { Name => 'Depth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    93 => { Name => 'NextStopDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    94 => { Name => 'NextStopTime', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    95 => { Name => 'TimeToSurface', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    96 => { Name => 'NdlTime', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    97 => { Name => 'CnsLoad', PrintConv => '"$val %"' },
    98 => { Name => 'N2Load', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    99 => { Name => 'RespirationRate', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    108 => { Name => 'EnhancedRespirationRate', ValueConv => '$val / 100', PrintConv => '"$val Breaths/min"' },
    114 => 'Grit',
    115 => 'Flow',
    116 => { Name => 'CurrentStress', ValueConv => '$val / 100' },
    117 => { Name => 'EbikeTravelRange', PrintConv => '"$val km"' },
    118 => { Name => 'EbikeBatteryLevel', PrintConv => '"$val %"' },
    119 => { Name => 'EbikeAssistMode', PrintConv => '"$val depends on sensor"' },
    120 => { Name => 'EbikeAssistLevelPercent', PrintConv => '"$val %"' },
    121 => { Name => 'TotalAscent', PrintConv => '"$val m"' }, #4
    123 => { Name => 'AirTimeRemaining', PrintConv => '"$val s"' },
    124 => { Name => 'PressureSac', ValueConv => '$val / 100', PrintConv => '"$val bar/min"' },
    125 => { Name => 'VolumeSac', ValueConv => '$val / 100', PrintConv => '"$val L/min"' },
    126 => { Name => 'Rmv', ValueConv => '$val / 100', PrintConv => '"$val L/min"' },
    127 => { Name => 'AscentRate', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    129 => { Name => 'PO2', ValueConv => '$val / 100', PrintConv => '"$val %"' },
    136 => { Name => 'WristHeartRate', PrintConv => '"$val bpm"' }, #4
    137 => 'StaminaPotential', #4
    138 => 'Stamina', #4
    139 => { Name => 'CoreTemperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    140 => { Name => 'GradeAdjustedSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    143 => 'BodyBattery', #4
    144 => { Name => 'ExternalHeartRate', PrintConv => '"$val bpm"' }, #4
    146 => { Name => 'StepSpeedLossDistance', ValueConv => '$val / 100', PrintConv => '"$val cm/s"' }, #4
    147 => { Name => 'StepSpeedLossPercentage', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
    148 => { Name => 'Force', ValueConv => '$val / 1000', PrintConv => '"$val N"' }, #4
);

%Image::ExifTool::Garmin::Event = (
    GROUPS => { 0 => 'Garmin', 1 => 'Event', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Event', PrintConv => \%eventEnum, SeparateTable => 'EventEnum' },
    1 => { Name => 'EventType', PrintConv => \%eventType, SeparateTable => 'EventType' },
    2 => 'Data16',
    3 => 'Data',
    4 => 'EventGroup',
    7 => 'Score',
    8 => 'OpponentScore',
    9 => 'FrontGearNum',
    10 => 'FrontGear',
    11 => 'RearGearNum',
    12 => 'RearGear',
    13 => { Name => 'DeviceIndex', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    14 => { Name => 'ActivityType', PrintConv => \%activityType, SeparateTable => 'ActivityType' },
    15 => { Name => 'StartTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    21 => { Name => 'RadarThreatLevelMax', PrintConv => \%radarThreatLevelType },
    22 => 'RadarThreatCount',
    23 => { Name => 'RadarThreatAvgApproachSpeed', ValueConv => '$val / 10', PrintConv => '"$val m/s"' },
    24 => { Name => 'RadarThreatMaxApproachSpeed', ValueConv => '$val / 10', PrintConv => '"$val m/s"' },
);

%Image::ExifTool::Garmin::DeviceInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'DeviceInfo', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'DeviceIndex', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    1 => 'DeviceType',
    2 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
    3 => 'SerialNumber',
    4 => 'Product',
    5 => { Name => 'SoftwareVersion', ValueConv => '$val / 100' },
    6 => 'HardwareVersion',
    7 => { Name => 'CumOperatingTime', PrintConv => '"$val s"' },
    10 => { Name => 'BatteryVoltage', ValueConv => '$val / 256', PrintConv => '"$val V"' },
    11 => { Name => 'BatteryStatus', PrintConv => \%batteryStatus, SeparateTable => 'BatteryStatus' },
    18 => { Name => 'SensorPosition', PrintConv => \%bodyLocation, PrintConvColumns => 2 },
    19 => 'Descriptor',
    20 => 'AntTransmissionType',
    21 => 'AntDeviceNumber',
    22 => { Name => 'AntNetwork', PrintConv => \%antNetwork },
    24 => 'AntID', #4
    25 => { Name => 'SourceType', PrintConv => \%sourceType, SeparateTable => 'SourceType' },
    27 => 'ProductName',
    32 => { Name => 'BatteryLevel', PrintConv => '"$val %"' },
);

%Image::ExifTool::Garmin::DeviceAuxBatteryInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'AuxBattery', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'DeviceIndex', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    1 => { Name => 'BatteryVoltage', ValueConv => '$val / 256', PrintConv => '"$val V"' },
    2 => { Name => 'BatteryStatus', PrintConv => \%batteryStatus, SeparateTable => 'BatteryStatus' },
    3 => 'BatteryIdentifier',
);

%Image::ExifTool::Garmin::TrainingFile = (
    GROUPS => { 0 => 'Garmin', 1 => 'TrainingFile', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TrainingFileType', PrintConv => \%file, SeparateTable => 'File' },
    1 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
    2 => 'Product',
    3 => 'SerialNumber',
    4 => { Name => 'TimeCreated', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::WeatherConditions = (
    GROUPS => { 0 => 'Garmin', 1 => 'WeatherConditions', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'WeatherReport', PrintConv => \%weatherReport },
    1 => { Name => 'Temperature', PrintConv => '"$val C"' },
    2 => { Name => 'Condition', PrintConv => \%weatherStatus },
    3 => { Name => 'WindDirection', PrintConv => '"$val degrees"' },
    4 => { Name => 'WindSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    5 => 'PrecipitationProbability',
    6 => { Name => 'TemperatureFeelsLike', PrintConv => '"$val C"' },
    7 => 'RelativeHumidity',
    8 => 'Location',
    9 => { Name => 'GPSDateTime', %timeInfo, Groups => { 2 => 'Time' }, Notes => 'observed_at_time', IsTimeStamp => 1 },
    10 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'observed_location_lat' },
    11 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'observed_location_long' },
    12 => { Name => 'DayOfWeek', PrintConv => \%dayOfWeek },
    13 => { Name => 'HighTemperature', PrintConv => '"$val C"' },
    14 => { Name => 'LowTemperature', PrintConv => '"$val C"' },
);

%Image::ExifTool::Garmin::WeatherAlert = (
    GROUPS => { 0 => 'Garmin', 1 => 'WeatherAlert', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ReportID',
    1 => { Name => 'IssueTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'ExpireTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'Severity', PrintConv => \%weatherSeverity },
    4 => { Name => 'WeatherAlertType', PrintConv => \%weatherSevereType, PrintConvColumns => 2 },
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
    6 => { Name => 'GPSDateTime', %timeInfo, Groups => { 2 => 'Time' }, Notes => 'utc_timestamp', IsTimeStamp => 1 },
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
    1 => { Name => 'CameraEventType', PrintConv => \%cameraEventType },
    2 => 'CameraFileUUID',
    3 => { Name => 'CameraOrientation', PrintConv => \%cameraOrientationType },
);

%Image::ExifTool::Garmin::GyroscopeData = (
    GROUPS => { 0 => 'Garmin', 1 => 'GyroData', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => 'SampleTimeOffset', # [N] ms
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
    1 => 'SampleTimeOffset', # [N] ms
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
    1 => 'SampleTimeOffset', # [N] ms
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
    1 => 'SampleTimeOffset', # [N] ms
    2 => 'BaroPres', # [N] Pa
);

%Image::ExifTool::Garmin::ThreeDSensorCalibration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ThreeDSensorCal', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'SensorType', PrintConv => \%sensorType, SeparateTable => 'SensorType' },
    1 => 'CalibrationFactor',
    2 => { Name => 'CalibrationDivisor', PrintConv => '"$val counts"' },
    3 => 'LevelShift',
    4 => 'OffsetCal', # [3]
    5 => 'OrientationMatrix', # [9] / 65535
);

%Image::ExifTool::Garmin::OneDSensorCalibration = (
    GROUPS => { 0 => 'Garmin', 1 => 'OneDSensorCal', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'SensorType', PrintConv => \%sensorType, SeparateTable => 'SensorType' },
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
    1 => 'TimeOffset', # [N] ms
    2 => 'Pid',
    3 => 'RawData', # [N]
    4 => 'PidDataSize', # [N]
    5 => 'SystemTime', # [N]
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
    1 => 'SystemTime', # [N] ms
    2 => 'Pitch', # [N] / 10430.38 radians
    3 => 'Roll', # [N] / 10430.38 radians
    4 => 'AccelLateral', # [N] / 100 m/s^2
    5 => 'AccelNormal', # [N] / 100 m/s^2
    6 => 'TurnRate', # [N] / 1024 radians/second
    7 => 'Stage', # [N]
    8 => 'AttitudeStageComplete', # [N] %
    9 => 'Track', # [N] / 10430.38 radians
    10 => 'Validity', # [N]
);

%Image::ExifTool::Garmin::Video = (
    GROUPS => { 0 => 'Garmin', 1 => 'Video', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'URL',
    1 => 'HostingProvider',
    2 => { Name => 'Duration', PrintConv => '"$val ms"' },
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
    6 => { Name => 'ClipStart', PrintConv => '"$val ms"' },
    7 => { Name => 'ClipEnd', PrintConv => '"$val ms"' },
);

%Image::ExifTool::Garmin::Set = (
    GROUPS => { 0 => 'Garmin', 1 => 'Set', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Duration', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    3 => 'Repetitions',
    4 => { Name => 'Weight', ValueConv => '$val / 16', PrintConv => '"$val kg"' },
    5 => { Name => 'SetType', PrintConv => \%setType },
    6 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    7 => 'Category', # [N]
    8 => 'CategorySubtype', # [N]
    9 => { Name => 'WeightDisplayUnit', PrintConv => \%fitBaseUnit, SeparateTable => 'FitBaseUnit' },
    10 => 'MessageIndex',
    11 => 'WktStepIndex',
);

%Image::ExifTool::Garmin::Jump = (
    GROUPS => { 0 => 'Garmin', 1 => 'Jump', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Distance', PrintConv => '"$val m"' },
    1 => { Name => 'Height', PrintConv => '"$val m"' },
    2 => 'Rotations',
    3 => { Name => 'HangTime', PrintConv => '"$val s"' },
    4 => 'Score',
    5 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    6 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    7 => { Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'speed' },
    8 => { Name => 'GPSSpeed',  %speedInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_speed' },
);

%Image::ExifTool::Garmin::Split = (
    GROUPS => { 0 => 'Garmin', 1 => 'Split', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'SplitType', PrintConv => \%splitType, SeparateTable => 'SplitType' },
    1 => { Name => 'TotalElapsedTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    2 => { Name => 'TotalTimerTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    3 => { Name => 'TotalDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => { Name => 'AvgSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    7 => { Name => 'StartDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' }, #4
    9 => { Name => 'GPSDateTime', %timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time', IsTimeStamp => 1 },
    11 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' }, #4
    12 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' }, #4
    13 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    14 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    15 => { Name => 'AvgHeartRate', PrintConv => '"$val bpm"' }, #4
    16 => { Name => 'MaxHeartRate', PrintConv => '"$val bpm"' }, #4
    21 => { Name => 'GPSLatitude',  %latInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_lat' },
    22 => { Name => 'GPSLongitude', %lonInfo, Groups => { 2 => 'Location' }, Notes => 'start_position_long' },
    23 => { Name => 'GPSDestLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_lat' },
    24 => { Name => 'GPSDestLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'end_position_long' },
    25 => { Name => 'MaxSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    26 => { Name => 'AvgVertSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    27 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
    28 => { Name => 'TotalCalories', PrintConv => '"$val kcal"' },
    32 => { Name => 'AvgTemperature', PrintConv => '"$val C"' }, #4
    33 => { Name => 'MaxTemperature', PrintConv => '"$val C"' }, #4
    34 => { Name => 'MinTemperature', PrintConv => '"$val C"' }, #4
    35 => { Name => 'AvgVerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' }, #4
    36 => { Name => 'AvgVerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
    37 => { Name => 'AvgStanceTime', ValueConv => '$val / 10', PrintConv => '"$val ms"' }, #4
    38 => { Name => 'AvgStanceTimeBalance', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
    39 => { Name => 'AvgStepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' }, #4
    40 => { Name => 'AvgPower', PrintConv => '"$val watts"' }, #4
    41 => { Name => 'MaxPower', PrintConv => '"$val watts"' }, #4
    42 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' }, #4
    67 => 'LapIndex', #4
    74 => { Name => 'StartElevation', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    79 => { Name => 'RestingCalories', PrintConv => '"$val kcal"' }, #4
    93 => { Name => 'GradeAdjustedSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' }, #4
    107 => 'BeginningPotential', #4
    108 => 'EndingPotential', #4
    109 => 'MinStamina', #4
    110 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    130 => { Name => 'StepSpeedLossDistance', ValueConv => '$val / 100', PrintConv => '"$val cm/s"' }, #4
    131 => { Name => 'StepSpeedLossPercentage', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
);

%Image::ExifTool::Garmin::SplitSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'SplitSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'SplitType', PrintConv => \%splitType, SeparateTable => 'SplitType' },
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
    20 => { Name => 'AvgVerticalOscillation', ValueConv => '$val / 10', PrintConv => '"$val mm"' }, #4
    21 => { Name => 'AvgVerticalRatio', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
    22 => { Name => 'AvgStanceTime', ValueConv => '$val / 10', PrintConv => '"$val ms"' }, #4
    24 => { Name => 'AvgStepLength', ValueConv => '$val / 10', PrintConv => '"$val mm"' }, #4
    25 => { Name => 'AvgPower', PrintConv => '"$val watts"' }, #4
    26 => { Name => 'MaxPower', PrintConv => '"$val watts"' }, #4
    27 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' }, #4
    60 => { Name => 'MaxSplitDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' }, #4
    64 => { Name => 'RestingCalories', PrintConv => '"$val kcal"' }, #4
    77 => { Name => 'TotalMovingTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    79 => { Name => 'FirstStartTime', %timeInfo, Groups => { 2 => 'Time' } }, #4
    83 => { Name => 'StepSpeedLossDistance', ValueConv => '$val / 100', PrintConv => '"$val cm/s"' }, #4
    84 => { Name => 'StepSpeedLossPercentage', ValueConv => '$val / 100', PrintConv => '"$val %"' }, #4
);

%Image::ExifTool::Garmin::ClimbPro = (
    GROUPS => { 0 => 'Garmin', 1 => 'ClimbPro', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    1 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    2 => { Name => 'ClimbProEvent', PrintConv => \%climbProEvent },
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
    2 => { Name => 'FitBaseTypeID', PrintConv => \%fitBaseType },
    3 => 'FieldName', # [N]
    4 => 'Array',
    5 => 'Components',
    6 => 'Scale',
    7 => 'Offset',
    8 => 'Units', # [N]
    9 => 'Bits',
    10 => 'Accumulate',
    13 => { Name => 'FitBaseUnitID', PrintConv => \%fitBaseUnit, SeparateTable => 'FitBaseUnit' },
    14 => { Name => 'NativeMesgNum', PrintConv => \%mesgNum, SeparateTable => 'MesgNum' },
    15 => 'NativeFieldNum',
);

%Image::ExifTool::Garmin::DeveloperDataID = (
    GROUPS => { 0 => 'Garmin', 1 => 'DevDataID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    NOTES => 'Developer identification tags.',
    0 => 'DeveloperID', # [N]
    1 => 'ApplicationID', # [N]
    2 => { Name => 'ManufacturerID', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
    3 => 'DeveloperDataIndex',
    4 => 'ApplicationVersion',
);

%Image::ExifTool::Garmin::Course = (
    GROUPS => { 0 => 'Garmin', 1 => 'Course', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    4 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    5 => 'CourseName',
    6 => { Name => 'Capabilities', PrintConv => \%courseCapabilities },
    7 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
);

%Image::ExifTool::Garmin::CoursePoint = (
    GROUPS => { 0 => 'Garmin', 1 => 'CoursePoint', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'timestamp', IsTimeStamp => 1 },
    2 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' },
    3 => { Name => 'GPSLongitude',%lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' },
    4 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    5 => { Name => 'CoursePointType', PrintConv => \%coursePointEnum },
    6 => 'CoursePointName',
    8 => 'Favorite',
);

%Image::ExifTool::Garmin::SegmentID = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegmentID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SegmentIDName',
    1 => 'UUID',
    2 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    3 => 'Enabled',
    4 => 'UserProfilePrimaryKey',
    5 => 'DeviceID',
    6 => 'DefaultRaceLeader',
    7 => { Name => 'DeleteStatus', PrintConv => \%segmentDeleteStatus },
    8 => { Name => 'SelectionType', PrintConv => \%segmentSelectionType },
);

%Image::ExifTool::Garmin::SegmentLeaderboardEntry = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegLeaderboard', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'SegmentLeaderboardName',
    1 => { Name => 'SegLeaderboardType', PrintConv => \%segmentLeaderboardType, SeparateTable => 'SegmentLeaderboardType' },
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
    5 => 'LeaderTime', # [N] / 1000 s
    6 => { Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'enhanced_altitude' },
);

%Image::ExifTool::Garmin::SegmentLap = (
    GROUPS => { 0 => 'Garmin', 1 => 'SegLap', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Event', PrintConv => \%eventEnum, SeparateTable => 'EventEnum' },
    1 => { Name => 'EventType', PrintConv => \%eventType, SeparateTable => 'EventType' },
    2 => { Name => 'GPSDateTime',%timeInfo, Groups => { 2 => 'Time' }, Notes => 'start_time', IsTimeStamp => 1 },
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
    23 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    24 => 'EventGroup',
    25 => { Name => 'NECLatitude',  %latInfo, Groups => { 2 => 'Location' } },
    26 => { Name => 'NECLongitude', %lonInfo, Groups => { 2 => 'Location' } },
    27 => { Name => 'SWCLatitude',  %latInfo, Groups => { 2 => 'Location' } },
    28 => { Name => 'SWCLongitude', %lonInfo, Groups => { 2 => 'Location' } },
    29 => 'SegmentLapName',
    30 => { Name => 'NormalizedPower', PrintConv => '"$val watts"' },
    31 => 'LeftRightBalance',
    32 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
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
    49 => 'TimeInHRZone', # [N] / 1000 s
    50 => 'TimeInSpeedZone', # [N] / 1000 s
    51 => 'TimeInCadenceZone', # [N] / 1000 s
    52 => 'TimeInPowerZone', # [N] / 1000 s
    53 => 'RepetitionNum',
    54 => { Name => 'MinAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    55 => { Name => 'MinHeartRate', PrintConv => '"$val bpm"' },
    56 => { Name => 'ActiveTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    57 => 'WktStepIndex',
    58 => { Name => 'SportEvent', PrintConv => \%sportEvent },
    59 => { Name => 'AvgLeftTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    60 => { Name => 'AvgRightTorqueEffectiveness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    61 => { Name => 'AvgLeftPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    62 => { Name => 'AvgRightPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    63 => { Name => 'AvgCombinedPedalSmoothness', ValueConv => '$val / 2', PrintConv => '"$val %"' },
    64 => { Name => 'Status', PrintConv => \%segmentLapStatus },
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
    83 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
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
    7 => 'LeaderType', # [N]
    8 => 'LeaderGroupPrimaryKey', # [N]
    9 => 'LeaderActivityID', # [N]
    10 => 'LeaderActivityIDString', # [N]
    11 => 'DefaultRaceLeader',
);

%Image::ExifTool::Garmin::Workout = (
    GROUPS => { 0 => 'Garmin', 1 => 'Workout', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    4 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    5 => { Name => 'Capabilities', PrintConv => \%workoutCapabilities, SeparateTable => 'WorkoutCapabilities' },
    6 => 'NumValidSteps',
    8 => 'WorkoutName',
    9 => { Name => 'DurationType', PrintConv => \%wktStepDuration, SeparateTable => 'WktStepDuration' }, #4
    10 => 'DurationValue', #4
    11 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
    14 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    15 => { Name => 'PoolLengthUnit', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
    17 => 'WorkoutDescription',
    20 => 'WorkoutIndex', #4
    21 => { Name => 'Time', ValueConv => '$val / 1000', PrintConv => '"$val s"' }, #4
    22 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' }, #4
);

%Image::ExifTool::Garmin::WorkoutSession = (
    GROUPS => { 0 => 'Garmin', 1 => 'WorkoutSess', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    1 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
    2 => 'NumValidSteps',
    3 => 'FirstStepIndex',
    4 => { Name => 'PoolLength', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    5 => { Name => 'PoolLengthUnit', PrintConv => \%displayMeasure, SeparateTable => 'DisplayMeasure' },
);

%Image::ExifTool::Garmin::WorkoutStep = (
    GROUPS => { 0 => 'Garmin', 1 => 'WorkoutStep', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'WktStepName',
    1 => { Name => 'DurationType', PrintConv => \%wktStepDuration, SeparateTable => 'WktStepDuration' },
    2 => 'DurationValue',
    3 => { Name => 'TargetType', PrintConv => \%wktStepTarget, SeparateTable => 'WktStepTarget' },
    4 => 'TargetValue',
    5 => 'CustomTargetValueLow',
    6 => 'CustomTargetValueHigh',
    7 => { Name => 'Intensity', PrintConv => \%intensity, SeparateTable => 'Intensity' },
    8 => 'Notes',
    9 => { Name => 'Equipment', PrintConv => \%workoutEquipment },
    10 => { Name => 'ExerciseCategory', PrintConv => \%exerciseCategory, SeparateTable => 'ExerciseCategory' },
    11 => 'ExerciseName',
    12 => { Name => 'ExerciseWeight', ValueConv => '$val / 100', PrintConv => '"$val kg"' },
    13 => { Name => 'WeightDisplayUnit', PrintConv => \%fitBaseUnit, SeparateTable => 'FitBaseUnit' },
    18 => { Name => 'SkipLastRecover', PrintConv => \%yesNo, SeparateTable => 'YesNo' }, #4
    19 => { Name => 'SecondaryTargetType', PrintConv => \%wktStepTarget, SeparateTable => 'WktStepTarget' },
    20 => 'SecondaryTargetValue',
    21 => 'SecondaryCustomTargetValueLow',
    22 => 'SecondaryCustomTargetValueHigh',
    31 => 'WorkoutIndex', #4
);

%Image::ExifTool::Garmin::ExerciseTitle = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExerciseTitle', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ExerciseCategory', PrintConv => \%exerciseCategory, SeparateTable => 'ExerciseCategory' },
    1 => 'ExerciseName',
    2 => 'WktStepName', # [N]
);

%Image::ExifTool::Garmin::Schedule = (
    GROUPS => { 0 => 'Garmin', 1 => 'Schedule', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
    1 => 'Product',
    2 => 'SerialNumber',
    3 => { Name => 'TimeCreated', %timeInfo, Groups => { 2 => 'Time' } },
    4 => 'Completed',
    5 => { Name => 'ScheduleType', PrintConv => \%scheduleEnum },
    6 => { Name => 'ScheduledTime', %localTime, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::Totals = (
    GROUPS => { 0 => 'Garmin', 1 => 'Totals', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimerTime', PrintConv => '"$val s"' },
    1 => { Name => 'Distance', PrintConv => '"$val m"' },
    2 => { Name => 'Calories', PrintConv => '"$val kcal"' },
    3 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    4 => { Name => 'ElapsedTime', PrintConv => '"$val s"' },
    5 => 'Sessions',
    6 => { Name => 'ActiveTime', PrintConv => '"$val s"' },
    9 => 'SportIndex',
    10 => 'ActivityProfile', #4
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
    7 => { Name => 'HeartRateType', PrintConv => \%hRType },
    8 => { Name => 'Status', PrintConv => \%bpStatus },
    9 => 'UserProfileIndex',
);

%Image::ExifTool::Garmin::MonitoringInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'MonitorInfo', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    1 => 'ActivityType', # [N]
    3 => 'CyclesToDistance', # [N] / 5000 m/cycle
    4 => 'CyclesToCalories', # [N] / 5000 kcal/cycle
    5 => { Name => 'RestingMetabolicRate', PrintConv => '"$val kcal / day"' },
);

%Image::ExifTool::Garmin::Monitoring = (
    GROUPS => { 0 => 'Garmin', 1 => 'Monitoring', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'DeviceIndex', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    1 => { Name => 'Calories', PrintConv => '"$val kcal"' },
    2 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    3 => { Name => 'Cycles', ValueConv => '$val / 2', PrintConv => '"$val cycles"' },
    4 => { Name => 'ActiveTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    5 => { Name => 'ActivityType', PrintConv => \%activityType, SeparateTable => 'ActivityType' },
    6 => { Name => 'ActivitySubtype', PrintConv => \%activitySubtype },
    7 => { Name => 'ActivityLevel', PrintConv => \%activityLevel },
    8 => { Name => 'Distance_16', PrintConv => '"$val 100 * m"' },
    9 => { Name => 'Cycles_16', PrintConv => '"$val 2 * cycles (steps)"' },
    10 => { Name => 'ActiveTime_16', PrintConv => '"$val s"' },
    11 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    12 => { Name => 'Temperature', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    14 => { Name => 'TemperatureMin', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    15 => { Name => 'TemperatureMax', ValueConv => '$val / 100', PrintConv => '"$val C"' },
    16 => 'ActivityTime', # [8] minutes
    19 => { Name => 'ActiveCalories', PrintConv => '"$val kcal"' },
    24 => 'CurrentActivityTypeIntensity',
    25 => { Name => 'TimeStampMin_8', PrintConv => '"$val min"' },
    26 => { Name => 'TimeStamp_16', PrintConv => '"$val s"' },
    27 => { Name => 'HeartRate', PrintConv => '"$val bpm"' },
    28 => { Name => 'Intensity', ValueConv => '$val / 10' },
    29 => { Name => 'DurationMin', PrintConv => '"$val min"' },
    30 => { Name => 'Duration', PrintConv => '"$val s"' },
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
    0 => { Name => 'ReadingSPO2', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    1 => { Name => 'ReadingConfidence', ValueConv => '$val / 1' },
    2 => { Name => 'Mode', PrintConv => \%sPO2MeasurementType },
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
    3 => 'BodyBattery', #4
);

%Image::ExifTool::Garmin::MaxMetData = (
    GROUPS => { 0 => 'Garmin', 1 => 'MaxMetData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'UpdateTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'VO2Max', ValueConv => '$val / 10', PrintConv => '"$val mL/kg/min"' },
    5 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    6 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
    8 => { Name => 'MaxMetCategory', PrintConv => \%maxMetCategory },
    9 => 'CalibratedData',
    12 => { Name => 'HRSource', PrintConv => \%maxMetHeartRateSource },
    13 => { Name => 'SpeedSource', PrintConv => \%maxMetSpeedSource },
);

%Image::ExifTool::Garmin::HSABodyBatteryData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSABodyBattery', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'Level', # [N] percent
    2 => 'Charged', # [N]
    3 => 'Uncharged', # [N]
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
    1 => { Name => 'SamplingInterval', PrintConv => '"$val ms"' },
    2 => 'AccelX', # [N] / 1.024 mG
    3 => 'AccelY', # [N] / 1.024 mG
    4 => 'AccelZ', # [N] / 1.024 mG
    5 => 'TimeStamp_32k',
);

%Image::ExifTool::Garmin::HSAGyroscopeData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAGyroData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => { Name => 'SamplingInterval', PrintConv => '"$val 1/32768 s"' },
    2 => 'GyroX', # [N] / 28.57143 deg/s
    3 => 'GyroY', # [N] / 28.57143 deg/s
    4 => 'GyroZ', # [N] / 28.57143 deg/s
    5 => { Name => 'TimeStamp_32k', PrintConv => '"$val 1/32768 s"' },
);

%Image::ExifTool::Garmin::HSAStepData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAStepData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'Steps', # [N] / 1 steps
);

%Image::ExifTool::Garmin::HSA_SPO2Data = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSA_SPO2Data', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'ReadingSPO2', # [N] percent
    2 => 'Confidence', # [N]
);

%Image::ExifTool::Garmin::HSAStressData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAStressData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'StressLevel', # [N] / 1 s
);

%Image::ExifTool::Garmin::HSARespirationData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSARespirData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'RespirationRate', # [N] / 100 breaths/min
);

%Image::ExifTool::Garmin::HSAHeartRateData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSA_HRData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'Status',
    2 => 'HeartRate', # [N] / 1 bpm
);

%Image::ExifTool::Garmin::HSAConfigurationData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAConfigData', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Data', # [N]
    1 => 'DataSize',
);

%Image::ExifTool::Garmin::HSAWristTemperatureData = (
    GROUPS => { 0 => 'Garmin', 1 => 'HSAWristTemp', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ProcessingInterval', PrintConv => '"$val s"' },
    1 => 'Value', # [N] / 1000 degC
);

%Image::ExifTool::Garmin::MemoGlob = (
    GROUPS => { 0 => 'Garmin', 1 => 'MemoGlob', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Memo', # [N]
    1 => { Name => 'MesgNum', PrintConv => \%mesgNum, SeparateTable => 'MesgNum' },
    2 => 'ParentIndex',
    3 => 'FieldNum',
    4 => 'Data', # [N]
);

%Image::ExifTool::Garmin::SleepLevel = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepLevel', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'SleepLevel', PrintConv => \%sleepLevelEnum },
);

%Image::ExifTool::Garmin::AntChannelID = (
    GROUPS => { 0 => 'Garmin', 1 => 'AntChannelID', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ChannelNumber',
    1 => 'DeviceType',
    2 => 'DeviceNumber',
    3 => 'TransmissionType',
    4 => { Name => 'DeviceIndex', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
);

%Image::ExifTool::Garmin::AntRx = (
    GROUPS => { 0 => 'Garmin', 1 => 'AntRx', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FractionalTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    1 => 'MesgID',
    2 => 'MesgData', # [N]
    3 => 'ChannelNumber',
    4 => 'Data', # [N]
);

%Image::ExifTool::Garmin::AntTx = (
    GROUPS => { 0 => 'Garmin', 1 => 'AntTx', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'FractionalTimeStamp', ValueConv => '$val / 32768', PrintConv => '"$val s"' },
    1 => 'MesgID',
    2 => 'MesgData', # [N]
    3 => 'ChannelNumber',
    4 => 'Data', # [N]
);

%Image::ExifTool::Garmin::ExdScreenConfiguration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExdScreenConfig', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ScreenIndex',
    1 => 'FieldCount',
    2 => { Name => 'Layout', PrintConv => \%exdLayout },
    3 => 'ScreenEnabled',
);

%Image::ExifTool::Garmin::ExdDataFieldConfiguration = (
    GROUPS => { 0 => 'Garmin', 1 => 'ExdDataFieldConfig', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'ScreenIndex',
    1 => 'ConceptField',
    2 => 'FieldID',
    3 => 'ConceptCount',
    4 => { Name => 'DisplayType', PrintConv => \%exdDisplayType },
    5 => 'Title', # [32]
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
    8 => { Name => 'DataUnits', PrintConv => \%exdDataUnits, PrintConvColumns => 2 },
    9 => { Name => 'Qualifier', PrintConv => \%exdQualifiers, PrintConvColumns => 2 },
    10 => { Name => 'Descriptor', PrintConv => \%exdDescriptors, PrintConvColumns => 2 },
    11 => 'IsSigned',
);

%Image::ExifTool::Garmin::DiveSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'DiveSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'ReferenceMesg', PrintConv => \%mesgNum, SeparateTable => 'MesgNum' },
    1 => 'ReferenceIndex',
    2 => { Name => 'AvgDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    3 => { Name => 'MaxDepth', ValueConv => '$val / 1000', PrintConv => '"$val m"' },
    4 => { Name => 'SurfaceInterval', ValueConv => '$val / 1', PrintConv => '"$val s"' },
    5 => { Name => 'StartCns', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    6 => { Name => 'EndCns', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    7 => { Name => 'StartN2', ValueConv => '$val / 1', PrintConv => '"$val %"' },
    8 => { Name => 'EndN2', ValueConv => '$val / 1', PrintConv => '"$val %"' },
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
    0 => { Name => 'Time', PrintConv => '"$val s"' },
    1 => 'EnergyTotal',
    2 => 'ZeroCrossCnt',
    3 => 'Instance',
    4 => { Name => 'TimeAboveThreshold', ValueConv => '$val / 25', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::HRV = (
    GROUPS => { 0 => 'Garmin', 1 => 'HRV', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Time', # [N] / 1000 s
);

%Image::ExifTool::Garmin::BeatIntervals = (
    GROUPS => { 0 => 'Garmin', 1 => 'BeatIntervals', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'TimeStamp_ms', PrintConv => '"$val ms"', Groups => { 2 => 'Time' } },
    1 => 'Time', # [N] ms
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
    6 => { Name => 'Status', PrintConv => \%hRVStatus },
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
    2 => 'Time', # [N] ms
    3 => 'Quality', # [N]
    4 => 'Gap', # [N]
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
    4 => { Name => 'ProjectileType', PrintConv => \%projectileType },
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
    0 => { Name => 'Severity', PrintConv => \%sleepDisruptionSeverity, SeparateTable => 'SleepDisruptionSeverity' },
);

%Image::ExifTool::Garmin::SleepDisruptionOvernightSeverity = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepDisruptOvernight', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Severity', PrintConv => \%sleepDisruptionSeverity, SeparateTable => 'SleepDisruptionSeverity' },
);

%Image::ExifTool::Garmin::NapEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'NapEvent', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    1 => { Name => 'StartTimezoneOffset', PrintConv => '"$val minutes"' },
    2 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'EndTimezoneOffset', PrintConv => '"$val minutes"' },
    4 => { Name => 'Feedback', PrintConv => \%napPeriodFeedback },
    5 => 'IsDeleted',
    6 => { Name => 'Source', PrintConv => \%napSource },
    7 => { Name => 'UpdateTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::SkinTempOvernight = (
    GROUPS => { 0 => 'Garmin', 1 => 'SkinTempOvernight', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    1 => 'AverageDeviation',
    2 => 'Average_7DayDeviation',
    4 => 'NightlyValue',
);

#----------------------------------------------------------------------
# None of the messages below appear in the offical Garmin documentation
# (they were obtained from ref 4)
#
%Image::ExifTool::Garmin::DataScreen = (
    GROUPS => { 0 => 'Garmin', 1 => 'DataScreen', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    3 => 'NrFields',
    7 => { Name => 'DataFields', PrintConv => \%dataFields, PrintConvColumns => 2 },
    8 => 'Layout',
    9 => 'Position',
    10 => { Name => 'ScreenType', PrintConv => \%screenType },
);

%Image::ExifTool::Garmin::Alert = (
    GROUPS => { 0 => 'Garmin', 1 => 'Alert', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'Metric', PrintConv => \%alertMetric },
    2 => 'Value',
    3 => { Name => 'Status', PrintConv => \%switch, SeparateTable => 'Switch' },
    4 => 'Message',
    5 => { Name => 'Repeat', PrintConv => \%switch, SeparateTable => 'Switch' },
);

%Image::ExifTool::Garmin::RangeAlert = (
    GROUPS => { 0 => 'Garmin', 1 => 'RangeAlert', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'Metric', PrintConv => \%zoneMetric },
    2 => { Name => 'LowStatus', PrintConv => \%alertZone, SeparateTable => 'AlertZone' },
    3 => 'LowValue',
    4 => { Name => 'HighStatus', PrintConv => \%alertZone, SeparateTable => 'AlertZone' },
    5 => 'HighValue',
);

%Image::ExifTool::Garmin::DeviceUsed = (
    GROUPS => { 0 => 'Garmin', 1 => 'DeviceUsed', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'DevSpeed', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    1 => { Name => 'DevDistance', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    2 => { Name => 'DevCadence', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    3 => { Name => 'DevElevation', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    4 => { Name => 'DevHeartRate', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
    6 => { Name => 'DevPower', PrintConv => \%deviceIndex, SeparateTable => 'DeviceIndex' },
);

%Image::ExifTool::Garmin::Location = (
    GROUPS => { 0 => 'Garmin', 1 => 'Location', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'LocationName',
    1 => { Name => 'GPSLatitude', %latInfo, Groups => { 2 => 'Location' }, Notes => 'position_lat' }, #4
    2 => { Name => 'GPSLongitude', %lonInfo, Groups => { 2 => 'Location' }, Notes => 'position_long' }, #4
    3 => { Name => 'LocationSymbol', PrintConv => \%mapSymbol, PrintConvColumns => 2 },
    4 => { Name => 'GPSAltitude', %altInfo, Groups => { 2 => 'Location' }, Notes => 'altitude' },
    5 => { Name => 'EnhancedAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    6 => 'LocationDescription',
);

%Image::ExifTool::Garmin::MapLayer = (
    GROUPS => { 0 => 'Garmin', 1 => 'MapLayer', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    2 => { Name => 'ReliefShading', PrintConv => \%reliefShading },
    11 => { Name => 'Orientation', PrintConv => \%orientation },
    13 => { Name => 'UserLocations', PrintConv => \%visibilityStatus, SeparateTable => 'VisibilityStatus' },
    14 => { Name => 'AutoZoom', PrintConv => \%switch, SeparateTable => 'Switch' },
    15 => { Name => 'GuideText', PrintConv => \%guideText },
    16 => { Name => 'TrackLog', PrintConv => \%visibilityStatus, SeparateTable => 'VisibilityStatus' },
    20 => { Name => 'Courses', PrintConv => \%courses },
    23 => { Name => 'SpotSoundings', PrintConv => \%switch, SeparateTable => 'Switch' },
    24 => { Name => 'LightSectors', PrintConv => \%lightSectorsStatus },
    27 => { Name => 'Segments', PrintConv => \%visibilityStatus, SeparateTable => 'VisibilityStatus' },
    28 => { Name => 'Contours', PrintConv => \%visibilityStatus, SeparateTable => 'VisibilityStatus' },
    29 => 'SomeLabel',
    31 => { Name => 'Popularity', PrintConv => \%switch, SeparateTable => 'Switch' },
);

%Image::ExifTool::Garmin::Routing = (
    GROUPS => { 0 => 'Garmin', 1 => 'Routing', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'RoutingMode', PrintConv => \%routingMode },
    1 => { Name => 'CalculationMethod', PrintConv => \%calculationMethod },
    2 => { Name => 'LockOnRoad', PrintConv => \%switch, SeparateTable => 'Switch' },
    3 => { Name => 'Avoidances', PrintConv => \%avoidances },
    4 => { Name => 'RouteRecalculation', PrintConv => \%routeRecalculation },
    5 => { Name => 'RoutingType', PrintConv => \%routingType },
    7 => { Name => 'CourseRecalculation', PrintConv => \%courseRecalculation },
);

%Image::ExifTool::Garmin::UserMetrics = (
    GROUPS => { 0 => 'Garmin', 1 => 'UserMetrics', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'VO2Max', ValueConv => '$val / 292.5714286', PrintConv => '"$val ml/kg/min"' },
    1 => { Name => 'Age', PrintConv => '"$val yrs"' },
    2 => { Name => 'Height', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    3 => { Name => 'Weight', ValueConv => '$val / 10', PrintConv => '"$val kg"' },
    4 => { Name => 'Gender', PrintConv => \%gender, SeparateTable => 'Gender' },
    6 => { Name => 'MaxHR', PrintConv => '"$val bpm"' },
    8 => { Name => 'RemainingRecoveryTime', PrintConv => '"$val min"' },
    11 => { Name => 'Lthr', PrintConv => '"$val bpm"' },
    12 => { Name => 'Ltpower', PrintConv => '"$val watts"' },
    13 => { Name => 'Ltspeed', ValueConv => '$val / 10', PrintConv => '"$val km/h"' },
    15 => 'BeginningBodyBattery',
    16 => { Name => 'StartOfActivity', %timeInfo, Groups => { 2 => 'Time' } },
    19 => { Name => 'FirstVO2Max', ValueConv => '$val / 18724.57143', PrintConv => '"$val ml/kg/min"' },
    32 => 'BeginningPotential',
    35 => { Name => 'EndOfPreviousActivity', %timeInfo, Groups => { 2 => 'Time' } },
    39 => { Name => 'WakeUpTime', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::DeviceStatus = (
    GROUPS => { 0 => 'Garmin', 1 => 'DeviceStatus', 2 => 'Device' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'BatteryVoltage', ValueConv => '$val / 1000', PrintConv => '"$val V"' },
    2 => { Name => 'BatteryLevel', PrintConv => '"$val %"' },
    3 => { Name => 'Temperature', PrintConv => '"$val C"' },
);

%Image::ExifTool::Garmin::BestEffort = (
    GROUPS => { 0 => 'Garmin', 1 => 'BestEffort', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    2 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    3 => { Name => 'Time', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    4 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    5 => { Name => 'PersonalRecord', PrintConv => \%yesNo, SeparateTable => 'YesNo' },
);

%Image::ExifTool::Garmin::PersonalRecord = (
    GROUPS => { 0 => 'Garmin', 1 => 'PersonalRecord', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Metric', PrintConv => \%recordMetric },
    1 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    2 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    5 => 'Record',
);

%Image::ExifTool::Garmin::ActivityMetrics = (
    GROUPS => { 0 => 'Garmin', 1 => 'ActivityMetrics', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'NewHRMax',
    4 => { Name => 'AerobicTrainingEffect', ValueConv => '$val / 10' },
    7 => { Name => 'VO2Max', ValueConv => '$val / 18724.57143', PrintConv => '"$val ml/kg/min"' },
    9 => { Name => 'RecoveryTime', PrintConv => '"$val min"' },
    11 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    14 => { Name => 'Lthr', PrintConv => '"$val bpm"' },
    15 => { Name => 'Ltpower', PrintConv => '"$val watts"' },
    16 => { Name => 'Ltspeed', ValueConv => '$val / 10', PrintConv => '"$val km/h"' },
    17 => 'EndingPerformanceCondition',
    20 => { Name => 'AnaerobicTrainingEffect', ValueConv => '$val / 10' },
    25 => 'EndingBodyBattery',
    29 => { Name => 'FirstVO2Max', ValueConv => '$val / 18724.57143', PrintConv => '"$val ml/kg/min"' },
    41 => { Name => 'PrimaryBenefit', PrintConv => \%benefit, SeparateTable => 'Benefit' },
    48 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    50 => 'EndingPotential',
    60 => { Name => 'TotalAscent', PrintConv => '"$val m"' },
    61 => { Name => 'TotalDescent', PrintConv => '"$val m"' },
    62 => { Name => 'AveragePower', PrintConv => '"$val watts"' },
    63 => { Name => 'AverageHeartRate', PrintConv => '"$val bpm"' },
);

%Image::ExifTool::Garmin::MultisportSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'MultisportSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'MultisportSettingsName',
    1 => { Name => 'Transitions', PrintConv => \%switch, SeparateTable => 'Switch' },
    2 => 'NumberOfActivities',
    3 => { Name => 'AutoPause', PrintConv => \%allow, SeparateTable => 'Allow' },
    4 => { Name => 'Alerts', PrintConv => \%allow, SeparateTable => 'Allow' },
    5 => { Name => 'AutoLap', PrintConv => \%allow, SeparateTable => 'Allow' },
    6 => { Name => 'PowerSaveTimeout', PrintConv => \%powerSaveTimeout },
    7 => { Name => 'AutoScroll', PrintConv => \%allow, SeparateTable => 'Allow' },
    8 => { Name => 'Repeat', PrintConv => \%switch, SeparateTable => 'Switch' },
    10 => { Name => 'SportChange', PrintConv => \%sportChange },
);

%Image::ExifTool::Garmin::MultisportActivity = (
    GROUPS => { 0 => 'Garmin', 1 => 'MultisportActivity', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    1 => { Name => 'SubSport', PrintConv => \%subSport, SeparateTable => 'SubSport' },
    2 => { Name => 'LockDevice', PrintConv => \%switch, SeparateTable => 'Switch' },
    3 => 'MultisportActivityName',
);

%Image::ExifTool::Garmin::SensorSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'SensorSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'AntID',
    2 => 'SensorSettingsName',
    10 => { Name => 'WheelSizeManual', PrintConv => '"$val mm"' },
    11 => { Name => 'CalibrationFactor', ValueConv => '$val / 10' },
    21 => { Name => 'WheelSizeAuto', PrintConv => '"$val mm"' },
    32 => 'Product',
    33 => { Name => 'Manufacturer', PrintConv => \%manufacturer, SeparateTable => 'Manufacturer' },
    45 => { Name => 'UseForSpeed', PrintConv => \%useStatus, SeparateTable => 'UseStatus' },
    46 => { Name => 'UseForDistance', PrintConv => \%useStatus, SeparateTable => 'UseStatus' },
    51 => { Name => 'ConnectionType', PrintConv => \%connectionType },
    52 => { Name => 'SensorType', PrintConv => \%sensorType, SeparateTable => 'SensorType' },
    91 => 'ProductName',
);

%Image::ExifTool::Garmin::Metronome = (
    GROUPS => { 0 => 'Garmin', 1 => 'Metronome', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Enabled', PrintConv => \%switch, SeparateTable => 'Switch' },
    1 => { Name => 'BeatsPerMinute', PrintConv => '"$val bpm"' },
    2 => 'AlertFrequency',
    3 => { Name => 'SoundAndVibe', PrintConv => \%soundAndVibe, SeparateTable => 'SoundAndVibe' },
);

%Image::ExifTool::Garmin::ConnectIQField = (
    GROUPS => { 0 => 'Garmin', 1 => 'ConnectIQField', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'AppID', # [N]
    2 => 'DataField',
    100 => 'ScreenID',
    101 => 'FieldBits',
);

%Image::ExifTool::Garmin::Clubs = (
    GROUPS => { 0 => 'Garmin', 1 => 'Clubs', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    6 => { Name => 'AverageDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    19 => { Name => 'MaxDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
);

%Image::ExifTool::Garmin::WaypointHandling = (
    GROUPS => { 0 => 'Garmin', 1 => 'WaypointHandling', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Action', PrintConv => \%waypointAction },
);

%Image::ExifTool::Garmin::GolfCourse = (
    GROUPS => { 0 => 'Garmin', 1 => 'GolfCourse', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'CourseID',
    1 => 'GolfCourseName',
    2 => { Name => 'LocalTime', %localTime, Groups => { 2 => 'Time' } },
    3 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    4 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
    8 => 'Out',
    9 => 'In',
    10 => 'Total',
    11 => 'Tee',
    12 => 'Slope',
    21 => 'Rating',
);

%Image::ExifTool::Garmin::GolfStats = (
    GROUPS => { 0 => 'Garmin', 1 => 'GolfStats', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'GolfStatsName',
    2 => 'Out',
    3 => 'In',
    4 => 'Total',
    7 => 'FairwayHit',
    8 => 'Gir',
    9 => 'Putts',
);

%Image::ExifTool::Garmin::Score = (
    GROUPS => { 0 => 'Garmin', 1 => 'Score', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'HoleNumber',
    2 => 'Score',
    5 => 'Putts',
    6 => { Name => 'Fairway', PrintConv => \%fairway },
);

%Image::ExifTool::Garmin::Hole = (
    GROUPS => { 0 => 'Garmin', 1 => 'Hole', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'HoleNumber',
    1 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    2 => 'Par',
    3 => 'Handicap',
    4 => { Name => 'PositionLat', %latInfo, Groups => { 2 => 'Location' } }, # position_lat
    5 => { Name => 'PositionLong', %lonInfo, Groups => { 2 => 'Location' } }, # position_long
);

%Image::ExifTool::Garmin::Shot = (
    GROUPS => { 0 => 'Garmin', 1 => 'Shot', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'HoleNumber',
    2 => { Name => 'StartPositionLat', %latInfo, Groups => { 2 => 'Location' } }, # start_position_lat
    3 => { Name => 'StartPositionLong', %lonInfo, Groups => { 2 => 'Location' } }, # start_position_long
    4 => { Name => 'EndPositionLat', %latInfo, Groups => { 2 => 'Location' } }, # end_position_lat
    5 => { Name => 'EndPositionLong', %lonInfo, Groups => { 2 => 'Location' } }, # end_position_long
    7 => 'ClubType',
);

%Image::ExifTool::Garmin::AlarmSettings = (
    GROUPS => { 0 => 'Garmin', 1 => 'AlarmSettings', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Time', PrintConv => '"$val min"' },
    1 => { Name => 'Repeat', PrintConv => \%alarmRepeat },
    2 => { Name => 'Enabled', PrintConv => \%switch, SeparateTable => 'Switch' },
    3 => { Name => 'Sound', PrintConv => \%soundAndVibe, SeparateTable => 'SoundAndVibe' },
    4 => { Name => 'Backlight', PrintConv => \%switch, SeparateTable => 'Switch' },
    5 => { Name => 'TimeCreated', %timeInfo, Groups => { 2 => 'Time' } },
    8 => { Name => 'Label', PrintConv => \%alarmLabel },
    11 => { Name => 'TimeUpdated', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::MusicInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'MusicInfo', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => 'Title',
    3 => 'Artist',
    4 => 'Genre',
    5 => { Name => 'Duration', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::SleepDataInfo = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepDataInfo', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'SampleLength', PrintConv => '"$val s"' },
    2 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    4 => 'Version',
);

%Image::ExifTool::Garmin::MtbCx = (
    GROUPS => { 0 => 'Garmin', 1 => 'MtbCx', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => { Name => 'GritFlowJumpRecording', PrintConv => \%switch, SeparateTable => 'Switch' },
    2 => { Name => 'JumpAlerts', PrintConv => \%switch, SeparateTable => 'Switch' },
);

%Image::ExifTool::Garmin::Race = (
    GROUPS => { 0 => 'Garmin', 1 => 'Race', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    3 => { Name => 'GoalTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    4 => { Name => 'GoalSpeed', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    5 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    7 => { Name => 'SplitDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
);

%Image::ExifTool::Garmin::SplitTime = (
    GROUPS => { 0 => 'Garmin', 1 => 'SplitTime', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Time', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    1 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    2 => { Name => 'SplitTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    3 => { Name => 'SplitDistance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    4 => { Name => 'SplitSpeeds', ValueConv => '$val / 1000', PrintConv => '"$val m/s"' },
    9 => { Name => 'StartPositionLat', %latInfo, Groups => { 2 => 'Location' } }, # start_position_lat
    10 => { Name => 'StartPositionLong', %lonInfo, Groups => { 2 => 'Location' } }, # start_position_long
    11 => { Name => 'EndPositionLat', %latInfo, Groups => { 2 => 'Location' } }, # end_position_lat
    12 => { Name => 'EndPositionLong', %lonInfo, Groups => { 2 => 'Location' } }, # end_position_long
    13 => { Name => 'StartAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
    14 => { Name => 'EndAltitude', ValueConv => '$val / 5 - 500', PrintConv => '"$val m"' },
);

%Image::ExifTool::Garmin::PowerMode = (
    GROUPS => { 0 => 'Garmin', 1 => 'PowerMode', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'LowBatteryAlert', PrintConv => '"$val s"' },
    1 => 'DefaultMode',
    3 => { Name => 'AutoEnableTime', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::GPSEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'GPSEvent', 2 => 'Location' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'EventType', PrintConv => \%gPSType },
    1 => 'Data',
    100 => { Name => 'GPS_1', PrintConv => \%switch, SeparateTable => 'Switch' },
    101 => { Name => 'Glonass', PrintConv => \%switch, SeparateTable => 'Switch' },
    102 => 'Unknown_1',
    104 => { Name => 'Qzss_1', PrintConv => \%switch, SeparateTable => 'Switch' },
    105 => 'Unknown_2',
    106 => { Name => 'Galileo_1', PrintConv => \%switch, SeparateTable => 'Switch' },
    107 => { Name => 'Beidou_1', PrintConv => \%switch, SeparateTable => 'Switch' },
    108 => { Name => 'AutoSelect', PrintConv => \%switch, SeparateTable => 'Switch' },
    109 => 'Unknown_3',
    110 => 'GPSgalileobeidou_5',
    113 => { Name => 'Qzss_5', PrintConv => \%switch, SeparateTable => 'Switch' },
);

%Image::ExifTool::Garmin::FunctionalMetrics = (
    GROUPS => { 0 => 'Garmin', 1 => 'FunctionalMetrics', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    4 => { Name => 'FunctionalThresholdPower', PrintConv => '"$val watts"' },
    7 => { Name => 'RunningLactateThresholdPower', PrintConv => '"$val watts"' },
    8 => { Name => 'RunningLactateThresholdHR', PrintConv => '"$val bpm"' },
    9 => { Name => 'CyclingLactaceThresholdHR', PrintConv => '"$val bpm"' },
);

%Image::ExifTool::Garmin::RaceEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'RaceEvent', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'EventID',
    2 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    3 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    4 => 'RaceEventName',
    5 => 'Location',
    6 => { Name => 'StartPointLat', %latInfo, Groups => { 2 => 'Location' } }, # start_point_lat
    7 => { Name => 'StartPointLong', %lonInfo, Groups => { 2 => 'Location' } }, # start_point_long
    10 => { Name => 'Distance', ValueConv => '$val / 100', PrintConv => '"$val m"' },
    12 => { Name => 'TargetTime', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
    24 => 'City',
    26 => 'Country',
);

%Image::ExifTool::Garmin::TrainingReadiness = (
    GROUPS => { 0 => 'Garmin', 1 => 'TrainingReadiness', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'TrainingReadiness',
    1 => { Name => 'Level', PrintConv => \%trainingReadinessLevel },
    20 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::TrainingLoad = (
    GROUPS => { 0 => 'Garmin', 1 => 'TrainingLoad', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    3 => 'AcuteTrainingLoad',
    4 => 'ChronicTrainingLoad',
);

%Image::ExifTool::Garmin::SleepSchedule = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepSchedule', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'BedTime', PrintConv => '"$val s"' },
    1 => { Name => 'WakeTime', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::SleepRestlessMoments = (
    GROUPS => { 0 => 'Garmin', 1 => 'SleepRestlessMoments', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'RestlessMomentsCount',
    2 => { Name => 'Durations', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::WorkoutSchedule = (
    GROUPS => { 0 => 'Garmin', 1 => 'WorkoutSchedule', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    1 => 'WorkoutIndex',
    3 => { Name => 'EstBenefit', PrintConv => \%benefit, SeparateTable => 'Benefit' },
    5 => { Name => 'EstAerobicTe', ValueConv => '$val / 10' },
    6 => { Name => 'EstAnaerTe', ValueConv => '$val / 10' },
    7 => { Name => 'Sport', PrintConv => \%sportEnum, SeparateTable => 'SportEnum' },
    9 => { Name => 'Duration', ValueConv => '$val / 1000', PrintConv => '"$val s"' },
);

%Image::ExifTool::Garmin::EPOStatus = (
    GROUPS => { 0 => 'Garmin', 1 => 'EPOStatus', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Status', PrintConv => \%ePOCPEStatus, SeparateTable => 'EPOCPEStatus' },
    1 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::OpenWaterEvent = (
    GROUPS => { 0 => 'Garmin', 1 => 'OpenWaterEvent', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'EventType', PrintConv => \%openWaterEventType },
    5 => { Name => 'SwimStroke', PrintConv => \%swimStroke, SeparateTable => 'SwimStroke' },
);

%Image::ExifTool::Garmin::ECGSummary = (
    GROUPS => { 0 => 'Garmin', 1 => 'ECGSummary', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    2 => 'RawSampleRate',
    3 => 'SmoothSampleRate',
    4 => { Name => 'ECGTimeStamp', %timeInfo, Groups => { 2 => 'Time' } },
    5 => { Name => 'LocalTimeStamp', %localTime, Groups => { 2 => 'Time' } },
    7 => { Name => 'AverageHeartRate', PrintConv => '"$val bpm"' },
    11 => { Name => 'SampleTime', PrintConv => '"$val s"' },
    12 => { Name => 'SDRRHRV', PrintConv => '"$val ms"' },
);

%Image::ExifTool::Garmin::ECGRawSample = (
    GROUPS => { 0 => 'Garmin', 1 => 'ECGRawSample', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Value',
);

%Image::ExifTool::Garmin::ECGSmoothSample = (
    GROUPS => { 0 => 'Garmin', 1 => 'ECGSmoothSample', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'Value',
);

%Image::ExifTool::Garmin::CPEStatus = (
    GROUPS => { 0 => 'Garmin', 1 => 'CPEStatus', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => { Name => 'Status', PrintConv => \%ePOCPEStatus, SeparateTable => 'EPOCPEStatus' },
    1 => { Name => 'StartTime', %timeInfo, Groups => { 2 => 'Time' } },
    2 => { Name => 'EndTime', %timeInfo, Groups => { 2 => 'Time' } },
);

%Image::ExifTool::Garmin::HillScore = (
    GROUPS => { 0 => 'Garmin', 1 => 'HillScore', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'HillScore',
    1 => 'HillStrength',
    2 => 'HillEndurance',
    4 => { Name => 'Level', PrintConv => \%hillScoreLevel },
);

%Image::ExifTool::Garmin::EnduranceScore = (
    GROUPS => { 0 => 'Garmin', 1 => 'EnduranceScore', 2 => 'Other' },
    VARS => { ID_FMT => 'dec', NO_LOOKUP => 1 },
    0 => 'EnduranceScore',
    1 => { Name => 'Level', PrintConv => \%enduranceScoreLevel },
    3 => 'LowerBoundIntermediate',
    4 => 'LowerBoundTrained',
    5 => 'LowerBoundWellTrained',
    6 => 'LowerBoundExpert',
    7 => 'LowerBoundSuperior',
    8 => 'LowerBoundElite',
);

#------------------------------------------------------------------------------
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
    $et->HandleTag($tagTbl, vers => Get8u(\$buff, 1));
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
                            # IsTimeStamp flag is set for timestamps to consider for
                            # incrementing the document number (eg. new GPS fix)
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
            } else {
                $val = $$ts[1];
            }
            # save TimeStamp tag now for unknown or compressed message
            if ($timestamp != $val) {
                $timestamp = $val;
                # increment document number for GPS data or any message with a new timestamp
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                unless ($fieldInfo and defined $$ts[2]) {
                    %parms = (
                        DataPt  => \$buff,
                        DataPos => $dataPos,
                        Start   => $$ts[3],
                        Size    => $$ts[1],
                        Format  => qq($baseType{$$ts[2]}[0] "$baseType{$$ts[2]}[1]"),
                    ) if defined $$ts[2];
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

Image::ExifTool::Garmin - Read Garmin FIT files

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Garmin FIT (Flexible and Interoperable data Transfer) files.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://developer.garmin.com/fit/overview/>

=item L<https://developer.garmin.com/fit/protocol/>

=item L<https://github.com/garmin/fit-sdk-tools/blob/main/Profile.xlsx>

=item L<https://docs.google.com/spreadsheets/d/1x34eRAZ45nbi3U3GyANotgmoQfj0fR49wBxmL-oLogc/>

=item L<https://forums.garmin.com/developer/fit-sdk/f/discussion/254469/list-of-undocumented-mesg_num/1223595>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Garmin Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
