#------------------------------------------------------------------------------
# File:         NikonSettings.pm
#
# Description:  Read Nikon user settings
#
# Revisions:    2021/01/08 - Warren Hatch Created
#               2021/01/12 - PH Created ProcessNikonSettings() to extract tags
#                            by ID instead of using fixed offsets
#
# References:   1) Warren Hatch private communication (D6 and Z7_2)
#
#------------------------------------------------------------------------------

package Image::ExifTool::NikonSettings;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

sub ProcessNikonSettings($$$);

my %enableDisable = ( 1 => 'Enable', 2 => 'Disable' );

my %funcButtonZ7m2 = (
    1 => 'AF-On',
    2 => 'AF Lock Only',
    3 => 'AE Lock (hold)',
    4 => 'AE Lock (reset on release)',
    5 => 'AE Lock Only',
    6 => 'AE/AF Lock',
    7 => 'FV Lock',
    8 => 'Flash Disable/Enable',
    9 => 'Preview',
    10 => 'Matrix Metering',
    11 => 'Center-weighted Metering',
    12 => 'Spot Metering',
    13 => 'Highlight-weighted Metering',
    14 => 'Bracketing Burst',
    15 => 'Synchronized Release (Master)',
    16 => 'Synchronized Release (Remote)',    # no settings map to 17 or 18
    19 => '+NEF(RAW)',
    20 => 'Subject Tracking',
    21 => 'Silent Photography',
    22 => 'LiveView Info Display On/Off',
    23 => 'Grid Display',
    24 => 'Zoom (Low)',
    25 => 'Zoom (1:1)',
    26 => 'Zoom (High)',
    27 => 'My Menu',
    28 => 'My Menu Top Item',
    29 => 'Playback',
    30 => 'Protect',
    31 => 'Image Area',
    32 => 'Image Quality',
    33 => 'White Balance',
    34 => 'Picture Control',
    35 => 'Active-D Lighting',
    36 => 'Metering',
    37 => 'Flash Mode',
    38 => 'Focus Mode',
    39 => 'Auto Bracketing',
    40 => 'Multiple Exposure',
    41 => 'HDR',
    42 => 'Exposure Delay Mode',
    43 => 'Shutter/Aperture Lock',
    44 => 'Focus Peaking',
    45 => 'Rating 0',
    46 => 'Rating 5',
    47 => 'Rating 4',
    48 => 'Rating 3',
    49 => 'Rating 2',
    50 => 'Rating 1',    # no settings map to x'51 (possibly intended for 'Candidate for Delection'
    52 => 'Non-CPU Lens',
    52 => 'None',
);

my %flickUpDownD6 = (
    1 => 'Rating',
    2 => 'Select To Send',
    3 => 'Protect',
    4 => 'Voice Memo',
    5 => 'None',
);

my %flickUpDownRatingD6 = (
    1 => 'Rating 5',
    2 => 'Rating 4',
    3 => 'Rating 3',
    4 => 'Rating 2',
    5 => 'Rating 1',
    6 => 'Candidate for Deletion',
);

my %groupAreaCustom = (
    1 => '1x7',
    2 => '1x5',
    3 => '3x7',
    4 => '3x5',
    5 => '3x3',
    6 => '5x7',
    7 => '5x5',
    8 => '5x3',
    9 => '5x1',
    10 => '7x7',
    11 => '7x5',
    12 => '7x3',
    13 => '7x1',
    14 => '11x3',
    15 => '11x1',
    16 => '15x3',
    17 => '15x1',
);

my %iSOAutoHiLimitD6 = (
    1 => 'ISO 200',
    2 => 'ISO 250',
    3 => 'ISO 280',
    4 => 'ISO 320',
    5 => 'ISO 400',
    6 => 'ISO 500',
    7 => 'ISO 560',
    8 => 'ISO 640',
    9 => 'ISO 800',
    10 => 'ISO 1000',
    11 => 'ISO 1100',
    12 => 'ISO 1250',
    13 => 'ISO 1600',
    14 => 'ISO 2000',
    15 => 'ISO 2200',
    16 => 'ISO 2500',
    17 => 'ISO 3200',
    18 => 'ISO 4000',
    19 => 'ISO 4500',
    20 => 'ISO 5000',
    21 => 'ISO 6400',
    22 => 'ISO 8000',
    23 => 'ISO 9000',
    24 => 'ISO 10000',
    25 => 'ISO 12800',
    26 => 'ISO 16000',
    27 => 'ISO 18000',
    28 => 'ISO 20000',
    29 => 'ISO 25600',
    30 => 'ISO 32000',
    31 => 'ISO 36000',
    32 => 'ISO 40000',
    33 => 'ISO 51200',
    34 => 'ISO 64000',
    35 => 'ISO 72000',
    36 => 'ISO 81200',
    37 => 'ISO 102400',
    38 => 'ISO Hi 0.3',
    39 => 'ISO Hi 0.5',
    40 => 'ISO Hi 0.7',
    41 => 'ISO Hi 1.0',
    42 => 'ISO Hi 2.0',
    43 => 'ISO Hi 3.0',
    44 => 'ISO Hi 4.0',
    45 => 'ISO Hi 5.0',
);

my %iSOAutoHiLimitZ7 = (
    1 => 'ISO 100',
    2 => 'ISO 125',
    4 => 'ISO 160',
    5 => 'ISO 200',
    6 => 'ISO 250',
    8 => 'ISO 320',
    9 => 'ISO 400',
    10 => 'ISO 500',
    12 => 'ISO 640',
    13 => 'ISO 800',
    14 => 'ISO 1000',
    16 => 'ISO 1250',
    17 => 'ISO 1600',
    18 => 'ISO 2000',
    20 => 'ISO 2500',
    21 => 'ISO 3200',
    22 => 'ISO 4000',
    24 => 'ISO 5000',
    25 => 'ISO 6400',
    26 => 'ISO 8000',
    28 => 'ISO 10000',
    29 => 'ISO 12800',
    30 => 'ISO 16000',
    32 => 'ISO 20000',
    33 => 'ISO 25600',
    38 => 'ISO Hi 0.3',
    39 => 'ISO Hi 0.5',
    40 => 'ISO Hi 0.7',
    41 => 'ISO Hi 1.0',
    42 => 'ISO Hi 2.0',
);

my %lensFuncButtonZ7m2 = (
    1 => 'AF-On',
    2 => 'AF Lock Only',
    3 => 'AE Lock (hold)',
    4 => 'AE Lock (reset on release)',
    5 => 'AE Lock Only',
    6 => 'AE/AF Lock',
    7 => 'FV Lock',
    8 => 'Flash Disable/Enable',
    9 => 'Preview',
    10 => 'Matrix Metering',
    11 => 'Center-weighted Metering',
    12 => 'Spot Metering',
    13 => 'Highlight-weighted Metering',
    14 => 'Bracketing Burst',
    15 => 'Synchronized Release (Master)',
    16 => 'Synchronized Release (Remote)',    # no settings map to 17 or 18 (Z7II fw 1.01)
    19 => '+NEF(RAW)',
    20 => 'Subject Tracking',
    21 => 'Grid Display',
    22 => 'Zoom (Low)',
    23 => 'Zoom (1:1)',
    24 => 'Zoom (High)',
    25 => 'My Menu',
    26 => 'My Menu Top Item',
    27 => 'Playback',
    28 => 'None',
);

my %limitNolimit = ( 1 => 'Limit', 2 => 'No Limit' );

my %limtReleaseModeSel = (
    0 => 'No Limit',    # not sure why 0 and 2 both map to 'No Limit', but they do
    1 => 'Limit',
    2 => 'No Limit',
);

my %menuBank = (
    1 => 'A',
    2 => 'B',
    3 => 'C',
    4 => 'D',
);

my %noYes = ( 1 => 'No', 2 => 'Yes' );
my %offOn = ( 1 => 'Off', 2 => 'On' );
my %onOff = ( 1 => 'On', 2 => 'Off' );

my %previewButtonD6 = (
    1 => 'Preset Focus Point - Press To Recall',
    2 => 'Preset Focus Point - Hold To Recall',
    3 => 'AF-AreaMode S',
    4 => 'AF-AreaMode D9',
    5 => 'AF-AreaMode D25',
    6 => 'AF-AreaMode D49',
    7 => 'AF-AreaMode D105',
    8 => 'AF-AreaMode 3D',
    9 => 'AF-AreaMode Group',
    10 => 'AF-AreaMode Group C1',
    11 => 'AF-AreaMode Group C2',
    12 => 'AF-AreaMode Auto Area',
    13 => 'AF-AreaMode + AF-On S',
    14 => 'AF-AreaMode + AF-On D9',
    15 => 'AF-AreaMode + AF-On D25',
    16 => 'AF-AreaMode + AF-On D49',
    17 => 'AF-AreaMode + AF-On D105',
    18 => 'AF-AreaMode + AF-On 3D',
    19 => 'AF-AreaMode + AF-On Group',
    20 => 'AF-AreaMode + AF-On Group C1',
    21 => 'AF-AreaMode + AF-On Group C2',
    22 => 'AF-AreaMode + AF-On Auto Area',
    23 => 'AF-On',
    24 => 'AF Lock Only',
    25 => 'AE Lock (hold)',
    26 => 'AE/WB Lock (hold)',
    27 => 'AE Lock (reset on release)',
    28 => 'AE Lock Only',
    29 => 'AE/AF Lock',
    30 => 'FV Lock',
    31 => 'Flash Disable/Enable',
    32 => 'Preview',
    33 => 'Recall Shooting Functions',
    34 => 'Bracketing Burst',
    35 => 'Synchronized Release (Master)',
    36 => 'Synchronized Release (Remote)', # no settings map to 37 or 38
    39 => '+NEF(RAW)',
    40 => 'Grid Display',
    41 => 'Virtual Horizon',
    42 => 'Voice Memo',
    43 => 'Wired LAN',
    44 => 'My Menu',
    45 => 'My Menu Top Item',
    46 => 'Playback',
    47 => 'Filtered Playback',
    48 => 'Photo Shooting Bank',
    49 => 'AF Mode/AF Area Mode',
    50 => 'Image Area',
    51 => 'Active-D Lighting',
    52 => 'Exposure Delay Mode',
    53 => 'Shutter/Aperture Lock',
    54 => '1 Stop Speed/Aperture',
    55 => 'Non-CPU Lens',
    56 => 'None',
);

my %releaseFocus = (
    1 => 'Release',
    2 => 'Focus',
);

my %tagMultiSelector = (
    1 => 'Restart Standby Timer',
    2 => 'Do Nothing',
);

my %tagSecondarySlotFunction = (
    1 => 'Overflow',
    2 => 'Backup',
    3 => 'NEF Primary + JPG Secondary',
    4 => 'JPG Primary + JPG Secondary',
);

my %tagSubSelector = (
    1 => 'Same as MultiSelector',
    2 => 'Focus Point Selection',
);

my %thirdHalfFull = (
    1 => '1/3 EV',
    2 => '1/2 EV',
    3 => '1 EV',
);

my %times4s10s20s1m5m20m = (
    1 => '4 s',
    2 => '10 s',
    3 => '20 s',
    4 => '1 min',
    5 => '5 min',
    6 => '10 min',
);

my %yesNo = ( 1 => 'Yes', 2 => 'No' );

my %infoD6 = (
    Condition => '$$self{Model} =~ /^NIKON D6\b/i',
    Notes => 'D6',
);

my %infoZ7 = (
    Condition => '$$self{Model} =~ /^NIKON Z (7|7_2)\b/i',
    Notes => 'Z7 and Z7_2',
);

my %infoZSeries = (
    Condition => '$$self{Model} =~ /^NIKON Z (5|50|6|6_2|7|7_2|fc)\b/i',
    Notes => 'Z Series cameras thru November 2021',
);

# Nikon Settings tags (ref 1, tag ID's ref PH)
%Image::ExifTool::NikonSettings::Main = (
    PROCESS_PROC => \&ProcessNikonSettings,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        User settings for newer Nikon models.  A number of the tags are marked as
        Unknown only to reduce the volume of the normal output.
    },
    0x001 => [{
        Name => 'ISOAutoHiLimit',
        PrintConv => \%iSOAutoHiLimitD6,
        %infoD6,
    },{
        Name => 'ISOAutoHiLimit',
        PrintConv => \%iSOAutoHiLimitZ7,
        %infoZ7,
    }],
    0x002 => [{
        Name => 'ISOAutoFlashLimit',
        PrintConv => {
            1 => 'Same As Without Flash',
            2 => 'ISO 200',
            3 => 'ISO 250',
            5 => 'ISO 320',
            6 => 'ISO 400',
            7 => 'ISO 500',
            9 => 'ISO 640',
            10 => 'ISO 800',
            11 => 'ISO 1000',
            13 => 'ISO 1250',
            14 => 'ISO 1600',
            15 => 'ISO 2000',
            17 => 'ISO 2500',
            18 => 'ISO 3200',
            19 => 'ISO 4000',
            21 => 'ISO 5000',
            22 => 'ISO 6400',
            23 => 'ISO 8000',
            25 => 'ISO 10000',
            26 => 'ISO 12800',
            27 => 'ISO 16000',
            29 => 'ISO 20000',
            30 => 'ISO 25600',
            31 => 'ISO 32000',
            33 => 'ISO 40000',
            34 => 'ISO 51200',
            35 => 'ISO 64000',
            36 => 'ISO 72000',
            37 => 'ISO 81200',
            38 => 'ISO 102400',
            39 => 'ISO Hi 0.3',
            40 => 'ISO Hi 0.5',
            41 => 'ISO Hi 0.7',
            42 => 'ISO Hi 1.0',
            43 => 'ISO Hi 2.0',
            44 => 'ISO Hi 3.0',
            45 => 'ISO Hi 4.0',
            46 => 'ISO Hi 5.0',
        },
        %infoD6,
    },{
        Name => 'ISOAutoFlashLimit',
        PrintConv => {
            1 => 'Same As Without Flash',
            2 => 'ISO 100',
            3 => 'ISO 125',
            5 => 'ISO 160',
            6 => 'ISO 200',
            7 => 'ISO 250',
            9 => 'ISO 320',
            10 => 'ISO 400',
            11 => 'ISO 500',
            13 => 'ISO 640',
            14 => 'ISO 800',
            15 => 'ISO 1000',
            17 => 'ISO 1250',
            18 => 'ISO 1600',
            19 => 'ISO 2000',
            21 => 'ISO 2500',
            22 => 'ISO 3200',
            23 => 'ISO 4000',
            25 => 'ISO 5000',
            26 => 'ISO 6400',
            27 => 'ISO 8000',
            29 => 'ISO 10000',
            30 => 'ISO 12800',
            31 => 'ISO 16000',
            33 => 'ISO 20000',
            34 => 'ISO 25600',
            39 => 'ISO Hi 0.3',
            40 => 'ISO Hi 0.5',
            41 => 'ISO Hi 0.7',
            42 => 'ISO Hi 1.0',
            43 => 'ISO Hi 2.0',
        },
        %infoZ7,
    }],
    0x003 => { # (D6/Z7_2)
        Name => 'ISOAutoShutterTime',
        PrintConv => {
            1 => 'Auto (Slowest)',
            2 => 'Auto (Slower)',
            3 => 'Auto',
            4 => 'Auto (Faster)',
            5 => 'Auto (Fastest)',
            6 => '1/4000 s',
            7 => '1/3200 s',
            8 => '1/2500 s',
            9 => '1/2000 s',
            10 => '1/1600 s',
            11 => '1/1250 s',
            12 => '1/1000 s',
            13 => '1/800 s',
            14 => '1/640 s',
            15 => '1/500 s',
            16 => '1/400 s',
            17 => '1/320 s',
            18 => '1/250 s',
            19 => '1/200 s',
            20 => '1/160 s',
            21 => '1/125 s',
            22 => '1/100 s',
            23 => '1/80 s',
            24 => '1/60 s',
            25 => '1/50 s',
            26 => '1/40 s',
            27 => '1/30 s',
            28 => '1/25 s',
            29 => '1/20 s',
            30 => '1/15 s',
            31 => '1/13 s',
            32 => '1/10 s',
            33 => '1/8 s',
            34 => '1/6 s',
            35 => '1/5 s',
            36 => '1/4 s',
            37 => '1/3 s',
            38 => '1/2.5 s',
            39 => '1/2 s',
            40 => '1/1.6 s',
            41 => '1/1.3 s',
            42 => '1 s',
            43 => '1.3 s',
            44 => '1.6 s',
            45 => '2 s',
            46 => '2.5 s',
            47 => '3 s',
            48 => '4 s',
            49 => '5 s',
            50 => '6 s',
            51 => '8 s',
            52 => '10 s',
            53 => '13 s',
            54 => '15 s',
            55 => '20 s',
            56 => '25 s',
            57 => '30 s',
        },
    },
    0x00b => { Name => 'FlickerReductionShooting', PrintConv => \%enableDisable }, # (D6/Z7_2)
    0x00c => { Name => 'FlickerReductionIndicator',PrintConv => \%enableDisable }, # (D6)
    0x00d => [{
        Name => 'MovieISOAutoHiLimit',
        PrintConv => \%iSOAutoHiLimitD6,
        %infoD6,
    },{
        Name => 'MovieISOAutoHiLimit',
        PrintConv => {
            1 => 'ISO 200',
            2 => 'ISO 250',
            4 => 'ISO 320',
            5 => 'ISO 400',
            6 => 'ISO 500',
            8 => 'ISO 640',
            9 => 'ISO 800',
            10 => 'ISO 1000',
            12 => 'ISO 1250',
            13 => 'ISO 1600',
            14 => 'ISO 2000',
            16 => 'ISO 2500',
            17 => 'ISO 3200',
            18 => 'ISO 4000',
            20 => 'ISO 5000',
            21 => 'ISO 6400',
            22 => 'ISO 8000',
            24 => 'ISO 10000',
            25 => 'ISO 12800',
            26 => 'ISO 16000',
            28 => 'ISO 20000',
            29 => 'ISO 25600',
            34 => 'ISO Hi 0.3',
            35 => 'ISO Hi 0.5',
            36 => 'ISO Hi 0.7',
            37 => 'ISO Hi 1.0',
            38 => 'ISO Hi 2.0',
        },
        %infoZ7,
    }],
    0x00e => { Name => 'MovieISOAutoControlManualMode',PrintConv => \%onOff }, # (D6/Z7_2)
    0x00f => { Name => 'MovieWhiteBalanceSameAsPhoto', PrintConv => \%yesNo }, # (D6/Z7_2)
    0x01d => [{ # CSa1 (D6)
        Name => 'AF-CPrioritySel',
        PrintConv => { # valid for cameras with 4 options for CS1, otherwise 1=Release, 2=Focus
            1 => 'Release',
            2 => 'Release + Focus',
            3 => 'Focus + Release',
            4 => 'Focus',
        },
        %infoD6,
    },{ # CSa1 (Z7_2)
        Name => 'AF-CPrioritySel',
        PrintConv => \%releaseFocus,
        %infoZSeries,
    }],
    0x01e => { Name => 'AF-SPrioritySel',       PrintConv => \%releaseFocus }, # CSa2 (D6), CSa2 (Z7_2)
    0x020 => [{ # CSa4 (D6)
        Name => 'AFPointSel',
        PrintConv => {
            1 => '105 Points',
            2 => '27 Points',
            3 => '15 Points',
        },
        %infoD6,
    },{ # CSa4 (Z7_2)
        Name => 'AFPointSel',
        PrintConv => { 1 => 'Use All', 2 => 'Use Half' },
        %infoZSeries,
    }],
    0x022 => { Name => 'AFActivation',          PrintConv => { 1 => 'Shutter/AF-On', 2 => 'AF-On Only' } }, # CSa6-a (D6/Z7_2) (missing enable/disable out of focus release) # (D6)
    0x023 => { Name => 'FocusPointWrap',        PrintConv => { 1 => 'Wrap', 2 => 'No Wrap' } }, # CSa16 (D6), CSa8 (Z7_2)
    0x025 => { # CSa17-a (D6), CSa9-a (Z7_2)
        Name => 'ManualFocusPointIllumination',
        PrintConv => {
            1 => 'On',
            2 => 'On During Focus Point Selection Only',
        },
    },
    0x026 => { Name => 'AF-AssistIlluminator',      PrintConv => \%onOff }, # CSa11 (Z7_2)
    0x027 => { Name => 'ManualFocusRingInAFMode',   PrintConv => \%onOff }, # CSa12 (D6,Z7_2) capability documented in manual, but visibility (& ability to test) requires a compatible lens
    0x029 => { Name => 'ISOStepSize',               PrintConv => \%thirdHalfFull },     # CSb1 (D6)
    0x02a => { Name => 'ExposureControlStepSize',   PrintConv => \%thirdHalfFull }, # CSb2 (D6), CSb1 (Z7_2)
    0x02b => { # CSb4 (D6), CSb2 (Z7_2)
        Name => 'EasyExposureCompensation',
        PrintConv => {
            1 => 'On (auto reset)',
            2 => 'On',
            3 => 'Off',
        },
    },
    0x02c => { Name => 'MatrixMetering', PrintConv => { 1 => 'Face Detection On', 2 => 'Face Detection Off' } }, # CSb5 (D6)
    0x02d => [{ # CSb6 (D6)
        Name => 'CenterWeightedAreaSize',
        PrintConv => {
            1 => '8 mm',
            2 => '12 mm',
            3 => '15 mm',
            4 => '20 mm',
            5 => 'Average',
        },
        %infoD6
    },{ # CSb3 (Z7_2)
        Name => 'CenterWeightedAreaSize',
        PrintConv => { 1 => '12 mm', 2 => 'Average' },
        %infoZSeries,
    }],
    0x02f => { # CSb7-a (D6), CSb4-a (Z7_2)
        Name => 'FineTuneOptMatrixMetering',
        ValueConv => '($val - 7) / 6',
        ValueConvInv => 'int($val*6+7)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x030 => { # CSb7-b (D6), CSb4-b (Z7_2)
        Name => 'FineTuneOptCenterWeighted',
        ValueConv => '($val - 7) / 6',
        ValueConvInv => 'int($val*6+7)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x031 => { # CSb7-c (D6), CSb4-c (Z7_2)
        Name => 'FineTuneOptSpotMetering',
        ValueConv => '($val - 7) / 6',
        ValueConvInv => 'int($val*6+7)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x032 => { # CSb7-d (D6), CSb4-d (Z7_2)
        Name => 'FineTuneOptHighlightWeighted',
        ValueConv => '($val - 7) / 6',
        ValueConvInv => 'int($val*6+7)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x033 => { # CSc1 (D6), CSc1 (Z7_2)
        Name => 'ShutterReleaseButtonAE-L',
        PrintConv => {
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)',
            3 => 'Off',
        },
    },
    0x034 => [{ # CSc2 (D6)
        Name => 'StandbyMonitorOffTime',
        PrintConv => {
            1 => '4 s',
            2 => '6 s',
            3 => '10 s',
            4 => '30 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
            8 => '30 min',
            9 => 'No Limit',
        },
        %infoD6,
    },{ # CSc4-d (Z7_2)
        Name => 'StandbyMonitorOffTime',
        PrintConv => {
            1 => '10 s',
            2 => '20 s',
            3 => '30 s',
            4 => '1 min',
            5 => '5 min',
            6 => '10 min',
            7 => '30 min',
            8 => 'No Limit',
        },
        %infoZSeries,
    }],
    0x035 => { # CSc3-a (D6), CSc2-a (Z7_2)
        Name => 'SelfTimerTime',
        PrintConv => {
            1 => '2 s',
            2 => '5 s',
            3 => '10 s',
            4 => '20 s',
        },
    },
    0x036 => { Name => 'SelfTimerShotCount', ValueConv => '10 - $val', ValueConvInv => '10 + $val' }, # CSc3-b (D6), CSc2-b (Z7_2)
    0x037 => { # CSc3-c (D6), CSc2-c (Z7_2)
        Name => 'SelfTimerShotInterval',
        PrintConv => {
            1 => '0.5 s',
            2 => '1 s',
            3 => '2 s',
            4 => '3 s',
        },
    },
    0x038 => { Name => 'PlaybackMonitorOffTime',    PrintConv => \%times4s10s20s1m5m20m }, # CSc4-a (D6), CSc3-a (Z7_2)
    0x039 => { Name => 'MenuMonitorOffTime',        PrintConv => \%times4s10s20s1m5m20m }, # CSc4-b (D6), CSc3-b (Z7_2)
    0x03a => { Name => 'ShootingInfoMonitorOffTime',PrintConv => \%times4s10s20s1m5m20m }, # CSc4-c (D6)
    0x03b => { # CSc4-d (D6), CSc3-c (Z7_2)
        Name => 'ImageReviewMonitorOffTime',
        PrintConv => {
            1 => '2 s',
            2 => '4 s',
            3 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    0x03c => { # CSc4-e (D6)
        Name => 'LiveViewMonitorOffTime',
        PrintConv => {
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
            4 => '20 min',
            5 => '30 min',
            6 => 'No Limit',
        },
    },
    0x03e => { Name => 'CLModeShootingSpeed',       ValueConv => '6 - $val', ValueConvInv => '6 + $val', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1 (Z7_2)
    0x03f => { Name => 'MaxContinuousRelease' }, # CSd2       # values: 1-200 # (D6/Z7_2)
    0x040 => { # CSd5 (D6), CSd4 (Z7_2)
        Name => 'ExposureDelayMode',
        PrintConv => {
            1 => '3 s',
            2 => '2 s',
            3 => '1 s',
            4 => '0.5 s',
            5 => '0.2 s',
            6 => 'Off',
        },
    },
    0x041 => { Name => 'ElectronicFront-CurtainShutter',PrintConv => \%onOff }, # CSd6 (D6)
    0x042 => { Name => 'FileNumberSequence',        PrintConv => \%onOff }, # CSd9 (D6), CSd8 (Z7_2)
    0x043 => { Name => 'FramingGridDisplay',        PrintConv => \%onOff }, # CSd11 (D6), CSd10 (Z7_2), new tag with implementation of NikonSettings # (Z7_2)
    0x045 => { Name => 'LCDIllumination',           PrintConv => \%onOff }, # CSd13 (D6)
    0x046 => { Name => 'OpticalVR',                 PrintConv => \%onOff }, # CSd15 (D6)
    0x047 => [{ # CSe1 (D6)
        Name => 'FlashSyncSpeed',
        PrintConv => {
            1 => '1/250 s (auto FP)',
            2 => '1/250 s',
            3 => '1/200 s',
            4 => '1/160 s',
            5 => '1/125 s',
            6 => '1/100 s',
            7 => '1/80 s',
            8 => '1/60 s',
        },
        %infoD6,
    },{ # CSe1 (Z7_2)
        Name => 'FlashSyncSpeed',
        PrintConv => {
            1 => '1/200 s (auto FP)',
            2 => '1/200 s',
            3 => '1/160 s',
            4 => '1/125 s',
            5 => '1/100 s',
            6 => '1/80 s',
            7 => '1/60 s',
        },
        %infoZSeries,
    }],
    0x048 => { # CSe2 (D6/Z7_2)
        Name => 'FlashShutterSpeed',
        PrintConv => {
            1 => '1/60 s',
            2 => '1/30 s',
            3 => '1/15 s',
            4 => '1/8 s',
            5 => '1/4 s',
            6 => '1/2 s',
            7 => '1 s',
            8 => '2 s',
        },
    },
    0x049 => { Name => 'FlashExposureCompArea', PrintConv => { 1 => 'Entire Frame', 2 => 'Background Only' } }, # CSe3 (D6/Z7_2)
    0x04a => { # CSe4 (D6/Z7_2)
        Name => 'AutoFlashISOSensitivity',
        PrintConv => {
            1 => 'Subject and Background',
            2 => 'Subject Only',
        },
    },
    0x051 => { # CSf3-l (D6)
        Name => 'AssignBktButton',
        PrintConv => {
            1 => 'Auto Bracketing',
            2 => 'Multiple Exposure',
            3 => 'HDR (high dynamic range)',
            4 => 'None',
        },
    },
    0x052 => [{ # CSf3-m (D6)
        Name => 'AssignMovieRecordButton',
        PrintConv => {
            1 => 'Voice Memo',
            2 => 'Photo Shooting Bank',
            3 => 'Exposure Mode',
            4 => 'AF Mode/AF Area Mode',
            5 => 'Image Area',
            6 => 'Shutter/Aperture Lock',
            7 => 'None',
        },
        %infoD6,
    },{ # CSf2-f (Z7_2)
        Name => 'AssignMovieRecordButton',
        PrintConv => {
            1 => 'AE Lock (hold)',
            2 => 'AE Lock (reset on release)',
            3 => 'Preview',
            4 => '+NEF(RAW)',
            5 => 'LiveView Info Display On/Off',
            6 => 'Grid Display',
            7 => 'Zoom (Low)',
            8 => 'Zoom (1:1)',
            9 => 'Zoom (High)',
            10 => 'My Menu',
            11 => 'My Menu Top Item',
            12 => 'Image Area',
            13 => 'Image Quality',
            14 => 'White Balance',
            15 => 'Picture Control',
            16 => 'Active-D Lighting',
            17 => 'Metering',
            18 => 'Flash Mode',
            19 => 'Focus Mode',
            20 => 'Auto Bracketing',
            21 => 'Multiple Exposure',
            22 => 'HDR',
            23 => 'Exposure Delay Mode',
            24 => 'Shutter/Aperture Lock',
            25 => 'Non-CPU Lens',
            26 => 'None',
        },
        %infoZSeries,
    }],
    0x053 => [{ # CSf4-a (D6)
        Name => 'MultiSelectorShootMode',
        PrintConv => {
            1 => 'Select Center Focus Point',
            2 => 'Preset Focus Point - Press To Recall',
            3 => 'Preset Focus Point - Hold To Recall',
            4 => 'None',
        },
        %infoD6,
    },{ # CSf3-a (Z7_2) also called the OK button on this camera
        Name => 'MultiSelectorShootMode',
        PrintConv => {
            1 => 'Select Center Focus Point',
            2 => 'Zoom (Low)',
            3 => 'Zoom (1:1)',
            4 => 'Zoom (High)',
            5 => 'None',
        },
        %infoZSeries,
    }],
    0x054 => [{ # CSf4-c (D6)
        Name => 'MultiSelectorPlaybackMode',
        PrintConv => {
            1 => 'Filtered Playback',
            2 => 'View Histograms',
            3 => 'Zoom (Low)',
            4 => 'Zoom (1:1)',
            5 => 'Zoom (High)',
            6 => 'Choose Folder',
        },
        %infoD6,
    },{ # CSf3-b (Z7_2) # these decodes are correct.  However, a new camera (or one following a 'reset all settings') will report Zoom (Low), despite the camera exhibiting the expected behavior (Zoom 1:1).  Any change to CSf3-b corrects the reporting.
        Name => 'MultiSelectorPlaybackMode',
        PrintConv => {
            1 => 'Thumbnail On/Off',
            2 => 'View Histograms',
            3 => 'Zoom (Low)',
            4 => 'Zoom (1:1)',
            5 => 'Zoom (High)',
            6 => 'Choose Folder',
        },
        %infoZSeries,
    }],
    0x056 => { # CSf4-b (D6)
        Name => 'MultiSelectorLiveView',
        PrintConv => {
            1 => 'Select Center Focus Point',
            2 => 'Zoom (Low)',
            3 => 'Zoom (1:1)',
            4 => 'Zoom (High)',
            5 => 'None',
        },
    },
    0x058 => { # CSf6-a-1 and CSf6-a-2 (D6), CSf5-a-1 and CSf5-a-2 (Z7_2), Previous cameras reported these 2 in a single tag (CmdDialsReverseRotation).  Blend the separate settings together to match extant tag name and values
        Name => 'CmdDialsReverseRotExposureComp',
        RawConv => '$$self{CmdDialsReverseRotExposureComp} = $val',
        Unknown => 1,
    },
    0x059 => { # CSf6-b-1 and  CSf6-b-2 (D6), CSf5-b-1 and  CSf5-b-2 (Z7_2), Previous cameras reported these 2 in a single tag (CmdDialsChangeMainSub).  Blend the separate settings together to match extant tag name and values
        Name => 'CmdDialsChangeMainSubExposure',
        RawConv => '$$self{CmdDialsChangeMainSubExposure} = $val',
        Unknown => 1,
    },
    0x05a => [{ # CSf6-b-1 and CSf6-b-2 (D6), CSf5-b-1 and CSf5-b-2 (Z7_2), (continued from above)
        Name => 'CmdDialsChangeMainSub',
        Condition => '$$self{CmdDialsChangeMainSubExposure} and $$self{CmdDialsChangeMainSubExposure} == 1',
        PrintConv => {
            1 => 'Autofocus On, Exposure On',
            2 => 'Autofocus Off, Exposure On',
        },
    },{
        Name => 'CmdDialsChangeMainSub',
        Condition => '$$self{CmdDialsChangeMainSubExposure} and $$self{CmdDialsChangeMainSubExposure} == 2',
        PrintConv => {
            1 => 'Autofocus On, Exposure On (Mode A)',
            2 => 'Autofocus Off, Exposure On (Mode A)',
        },
    },{
        Name => 'CmdDialsChangeMainSub',
        PrintConv => {
            1 => 'Autofocus On, Exposure Off',
            2 => 'Autofocus Off, Exposure Off',
        },
    }],
    0x05b => { Name => 'CmdDialsMenuAndPlayback', PrintConv => { 1 => 'On', 2 => 'On (Image Review Excluded)', 3 => 'Off' } }, # CSf5-c (D6), CSf5-c (Z7_2)
    0x05c => { # CSf6-d (D6), CSf5-d (Z7_2)
        Name => 'SubDialFrameAdvance',
        PrintConv => {
            1 => '10 Frames',
            2 => '50 Frames',
            3 => 'Rating',
            4 => 'Protect',
            5 => 'Stills Only',
            6 => 'Movies Only',
            7 => 'Folder',
        },
    },
    0x05d => { Name => 'ReleaseButtonToUseDial',    PrintConv => \%yesNo }, # CSf8 (D6), CSf6 (Z7_2)
    0x05e => { Name => 'ReverseIndicators',         PrintConv => { 1 => '+ 0 -', 2 => '- 0 +' } }, # CSf9 (D6), CSf7 (Z7_2)
    0x062 => { # CSg2-f (D6), CSg2-e (Z7_2)
        Name => 'MovieShutterButton',
        PrintConv => {
            1 => 'Take Photo',
            2 => 'Record Movie',
        },
    },
    0x063 => { # Settings menu # (D6,Z7_2)
        Name => 'Language',
        PrintConv => {
            5 => 'English',
            6 => 'Spanish',
            8 => 'French',
            15 => 'Portuguese (Br)',
        },
    },
    0x06c => [{
        Name => 'ShootingInfoDisplay',
        PrintConv => {
            1 => 'Auto',
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
        %infoD6,
    },{
        Name => 'ShootingInfoDisplay',
        PrintConv => {
            1 => 'Manual (dark on light)',
            2 => 'Manual (light on dark)',
        },
        %infoZSeries,
    }],
    0x074 => { Name => 'FlickAdvanceDirection', PrintConv => { 1 => 'Right to Left', 2 => 'Left to Right' } }, # CSf12-3 (D6)
    0x075 => { # Settings menu # (D6,Z7_2)
        Name => 'HDMIOutputResolution',
        PrintConv => {
            1 => 'Auto',
            2 => '2160p',
            3 => '1080p',
            4 => '1080i',
            5 => '720p',
            6 => '576p',
            7 => '480p',
        },
    },
    0x077 => { # Settings menu # (D6,Z7_2)
        Name => 'HDMIOutputRange',
        PrintConv => {
            1 => 'Auto',
            2 => 'Limit',
            3 => 'Full',
        },
    },
    0x080 => [{
        Name => 'RemoteFuncButton',
        PrintConv => {
            1 => 'AF-On',
            2 => 'AF Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock Only',
            5 => 'AE/AF Lock',
            6 => 'FV Lock',
            7 => 'Flash Disable/Enable',
            8 => 'Preview',
            9 => '+NEF(RAW)',
            10 => 'LiveView Info Display On/Off',
            11 => 'Recall Shooting Functions',
            12 => 'None',
        },
        %infoD6,
    },{
        Name => 'RemoteFuncButton',
        PrintConv => {
            1 => 'AF-On',
            2 => 'AF Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock Only',
            5 => 'AE/AF Lock',
            6 => 'FV Lock',
            7 => 'Flash Disable/Enable',
            8 => 'Preview',
            9 => '+NEF(RAW)',
            10 => 'None',
            11 => 'LiveView Info Display On/Off',
        },
        %infoZSeries,
    }],
    0x08b => [{ # CSf6-a-1 and CSf6-a-2 (D6), CSf5-a-1 and CSf5-a-2 (Z7_2), (continued from above)
        Name => 'CmdDialsReverseRotation',
        Condition => '$$self{CmdDialsReverseRotExposureComp} and $$self{CmdDialsReverseRotExposureComp} == 1',
        PrintConv => {
            1 => 'No',
            2 => 'Shutter Speed & Aperture',
        },
    },{
        Name => 'CmdDialsReverseRotation',
        PrintConv => {
            1 => 'Exposure Compensation',
            2 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    }],
    0x08d => { # CSd10-b (D6), CSd11-b (Z7_2)
        Name => 'FocusPeakingHighlightColor',
        PrintConv => {
            1 => 'Red',
            2 => 'Yellow',
            3 => 'Blue',
            4 => 'White',
        },
    },
    0x08e => { Name => 'ContinuousModeDisplay',     PrintConv => \%onOff }, # CSd14 (D6), CSd12 (Z7_2)
    0x08f => { Name => 'ShutterSpeedLock',          PrintConv => \%onOff }, # CSf54-a (D6), CSf4-a (Z7_2)
    0x090 => { Name => 'ApertureLock',              PrintConv => \%onOff }, # CSf5-b (D6), CSf4-b (Z7_2 could not select)
    0x091 => { # CSg4-b (D6), CSg6-b (Z7_2)
        Name => 'MovieHighlightDisplayThreshold',
        PrintConv => {
            1 => '255',
            2 => '248',
            3 => '235',
            4 => '224',
            5 => '213',
            6 => '202',
            7 => '191',
            8 => '180',
        },
    },
    0x092 => { Name => 'HDMIExternalRecorder',     PrintConv => \%onOff }, # Settings Menu/HDMI/Advanced entry (D6 & Z7_2)
    0x093 => { # CSa3-a (D6), CSa3 (Z7_2)
        Name => 'BlockShotAFResponse',
        PrintConv => {
            1 => '1 (Quick)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Delay)',
        },
    },
    0x094 => { Name => 'SubjectMotion', PrintConv => { 1 => 'Erratic', 2 => 'Steady' } }, # CSa3-b (D6)
    0x095 => { Name => 'Three-DTrackingFaceDetection', PrintConv => \%onOff }, # CSa8 (D6)
    0x097 => [{ # CSa5 (D6)
        Name => 'StoreByOrientation',
        PrintConv => {
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area mode',
            3 => 'Off',
        },
        %infoD6,
    },{ # CSa5 (Z7_2)
        Name => 'StoreByOrientation',
        PrintConv => {
            1 => 'Focus Point',
            2 => 'Off',
        },
        %infoZSeries,
    }],
    0x099 => { Name => 'DynamicAreaAFAssist',PrintConv => \%onOff }, # CSa17-c (D6), CSa9-b (Z7_2)
    0x09a => { Name => 'ExposureCompStepSize',      PrintConv => \%thirdHalfFull }, # CSb3 (D6)
    0x09b => { Name => 'SyncReleaseMode',           PrintConv => { 1 => 'Sync', 2 => 'No Sync' } }, # CSd4 (D6), CSd3 (Z7_2)
    0x09c => { Name => 'ModelingFlash',             PrintConv => \%onOff }, # CSe6 (D6), CSe5 (Z7_2)
    0x09d => { # CSe7 (D6), CSe6 (Z7_2)
        Name => 'AutoBracketModeM',
        PrintConv => {
            1 => 'Flash/Speed',
            2 => 'Flash/Speed/Aperture',
            3 => 'Flash/Aperture',
            4 => 'Flash Only',
        },
    },
    0x09e => { Name => 'PreviewButton',             PrintConv => \%previewButtonD6 }, # CSf3-a (D6)
    0x0a0 => [{ # CSf3-b (D6)
        Name => 'Func1Button',
        PrintConv => \%previewButtonD6,
        %infoD6,
    },{ # CSf2-a (Z7_2)
        Name => 'Func1Button',
        PrintConv => \%funcButtonZ7m2,
        %infoZSeries,
    }],
    0x0a2 => [{ # CSf3-c (D6)
        Name => 'Func2Button',
        PrintConv => \%previewButtonD6,
        %infoD6,
    },{ # CSf2-b (Z7_2)
        Name => 'Func2Button',
        PrintConv => \%funcButtonZ7m2,
        %infoZSeries,
    }],
    0x0a3 => [{ # CSf3-f (D6)
        Name => 'AF-OnButton',
        PrintConv => {
            1 => 'AF-AreaMode S',
            2 => 'AF-AreaMode D9',
            3 => 'AF-AreaMode D25',
            4 => 'AF-AreaMode D49',
            5 => 'AF-AreaMode D105',
            6 => 'AF-AreaMode 3D',
            7 => 'AF-AreaMode Group',
            8 => 'AF-AreaMode Group C1',
            9 => 'AF-AreaMode Group C2',
            10 => 'AF-AreaMode Auto Area',
            11 => 'AF-AreaMode + AF-On S',
            12 => 'AF-AreaMode + AF-On D9',
            13 => 'AF-AreaMode + AF-On D25',
            14 => 'AF-AreaMode + AF-On D49',
            15 => 'AF-AreaMode + AF-On D105',
            16 => 'AF-AreaMode + AF-On 3D',
            17 => 'AF-AreaMode + AF-On Group',
            18 => 'AF-AreaMode + AF-On Group C1',
            19 => 'AF-AreaMode + AF-On Group C2',
            20 => 'AF-AreaMode + AF-On Auto Area',
            21 => 'AF-On',
            22 => 'AF Lock Only',
            23 => 'AE Lock (hold)',
            24 => 'AE/WB Lock (hold)',
            25 => 'AE Lock (reset on release)',
            26 => 'AE Lock Only',
            27 => 'AE/AF Lock',
            28 => 'Recall Shooting Functions',
            29 => 'None',
        },
        %infoD6,
    },{ # CSf2-c (Z7_2)
        Name => 'AF-OnButton',
        PrintConv => {
            1 => 'Center Focus Point',
            2 => 'AF-On',
            3 => 'AF Lock Only',
            4 => 'AE Lock (hold)',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock Only',
            7 => 'AE/AF Lock',
            8 => 'LiveView Info Display On/Off',
            9 => 'Zoom (Low)',
            10 => 'Zoom (1:1)',
            11 => 'Zoom (High)',
            12 => 'None'
        },
        %infoZSeries,
    }],
    0x0a4 => { Name => 'SubSelector', PrintConv => \%tagSubSelector }, # CSf3-g-1 # (D6), CSf2-d-1 # (Z7_2)
    0x0a5 => [{ # CSf3-h (D6)
        Name => 'SubSelectorCenter',
        PrintConv => {
            1 => 'Preset Focus Point - Press To Recall',
            2 => 'Preset Focus Point - Hold To Recall',
            3 => 'Center Focus Point',
            4 => 'AF-AreaMode S',
            5 => 'AF-AreaMode D9',
            6 => 'AF-AreaMode D25',
            7 => 'AF-AreaMode D49',
            8 => 'AF-AreaMode D105',
            9 => 'AF-AreaMode 3D',
            10 => 'AF-AreaMode Group',
            11 => 'AF-AreaMode Group C1',
            12 => 'AF-AreaMode Group C2',
            13 => 'AF-AreaMode Auto Area',
            14 => 'AF-AreaMode + AF-On S',
            15 => 'AF-AreaMode + AF-On D9',
            16 => 'AF-AreaMode + AF-On D25',
            17 => 'AF-AreaMode + AF-On D49',
            18 => 'AF-AreaMode + AF-On D105',
            19 => 'AF-AreaMode + AF-On 3D',
            20 => 'AF-AreaMode + AF-On Group',
            21 => 'AF-AreaMode + AF-On Group C1',
            22 => 'AF-AreaMode + AF-On Group C2',
            23 => 'AF-AreaMode + AF-On Auto Area',
            24 => 'AF-On',
            25 => 'AF Lock Only',
            26 => 'AE Lock (hold)',
            27 => 'AE/WB Lock (hold)',
            28 => 'AE Lock (reset on release)',
            29 => 'AE Lock Only',
            30 => 'AE/AF Lock',
            31 => 'FV Lock',
            32 => 'Flash Disable/Enable',
            33 => 'Preview',
            34 => 'Recall Shooting Functions',
            35 => 'Bracketing Burst',
            36 => 'Synchronized Release (Master)',
            37 => 'Synchronized Release (Remote)',
            38 => 'None',
        },
        %infoD6,
    },{ # CSf2-e (Z7_2)
        Name => 'SubSelectorCenter',
        PrintConv => {
            1 => 'Center Focus Point',
            2 => 'AF-On',
            3 => 'AF Lock Only',
            4 => 'AE Lock (hold)',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock Only',
            7 => 'AE/AF Lock',
            8 => 'FV Lock',
            9 => 'Flash Disable/Enable',
            10 => 'Preview',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Highlight-weighted Metering',
            15 => 'Bracketing Burst',
            16 => 'Synchronized Release (Master)',
            17 => 'Synchronized Release (Remote)',
            20 => '+NEF(RAW)',
            21 => 'LiveView Info Display On/Off',
            22 => 'Grid Display',
            23 => 'Image Area',
            24 => 'Non-CPU Lens',
            25 => 'None',
        },
        %infoZSeries,
    }],
    0x0a7 => [{ # CSf3-n (D6)
        Name => 'LensFunc1Button',
        PrintConv => {
            1 => 'Preset Focus Point - Press To Recall',
            2 => 'Preset Focus Point - Hold To Recall',
            3 => 'AF-AreaMode S',
            4 => 'AF-AreaMode D9',
            5 => 'AF-AreaMode D25',
            6 => 'AF-AreaMode D49',
            7 => 'AF-AreaMode D105',
            8 => 'AF-AreaMode 3D',
            9 => 'AF-AreaMode Group',
            10 => 'AF-AreaMode Group C1',
            11 => 'AF-AreaMode Group C2',
            12 => 'AF-AreaMode Auto Area',
            13 => 'AF-AreaMode + AF-On S',
            14 => 'AF-AreaMode + AF-On D9',
            15 => 'AF-AreaMode + AF-On D25',
            16 => 'AF-AreaMode + AF-On D49',
            17 => 'AF-AreaMode + AF-On D105',
            18 => 'AF-AreaMode + AF-On 3D',
            19 => 'AF-AreaMode + AF-On Group',
            20 => 'AF-AreaMode + AF-On Group C1',
            21 => 'AF-AreaMode + AF-On Group C2',
            22 => 'AF-AreaMode + AF-On Auto Area',
            23 => 'AF-On',
            24 => 'AF Lock Only',
            25 => 'AE Lock Only',
            26 => 'AE/AF Lock',
            27 => 'Flash Disable/Enable',
            28 => 'Recall Shooting Functions',
            29 => 'Synchronized Release (Master)',
            30 => 'Synchronized Release (Remote)',
        },
        %infoD6,
    },{ # CSf2-g (Z7_2)
        Name => 'LensFunc1Button',
        PrintConv => \%lensFuncButtonZ7m2,
        %infoZSeries,
    }],
    0x0a8 => { Name => 'CmdDialsApertureSetting',   PrintConv => { 1 => 'Sub-command Dial', 2 => 'Aperture Ring' } }, # CSf6-c (D6)
    0x0a9 => { Name => 'MultiSelector',             PrintConv => \%tagMultiSelector }, # CSf7 (D6)
    0x0aa => { # CSf10 (D6)
        Name => 'LiveViewButtonOptions',
        PrintConv => {
            1 => 'Enable',
            2 => 'Enable (Standby Timer Active)',
            3 => 'Disable',
        },
    },
    0x0ab => { # CSf11 (D6)
        Name => 'LightSwitch',
        PrintConv => {
            1 => 'LCD Backlight',
            2 => 'LCD Backlight and Shooting Information',
        },
    },
    0x0b1 => [{ # CSg2-a (D6)
        Name => 'MoviePreviewButton',
        PrintConv => {
            1 => 'Power Aperture (Open)',
            2 => 'Exposure Compensation',
            3 => 'Grid Display',
            4 => 'Zoom (Low)',
            5 => 'Zoom (1:1)',
            6 => 'Zoom (High)',
            7 => 'Image Area',
            8 => 'Microphone Sensitivity',
            9 => 'None',
        },
        %infoD6,
    },{ # CSg2-a (Z7_2)
        Name => 'MovieFunc1Button',
        PrintConv => {
            1 => 'Power Aperture (Open)',
            2 => 'Exposure Compensation',
            3 => 'Subject Tracking',
            4 => 'LiveView Info Display On/Off',
            5 => 'Grid Display',
            6 => 'Zoom (Low)',
            7 => 'Zoom (1:1)',
            8 => 'Zoom (High)',
            9 => 'Protect',
            10 => 'Image Area',
            11 => 'White Balance',
            12 => 'Picture Control',
            13 => 'Active-D Lighting',
            14 => 'Metering',
            15 => 'Focus Mode',
            16 => 'Microphone Sensitivity',
            17 => 'Focus Peaking',
            18 => 'Rating (None)',
            19 => 'Rating (5)',
            20 => 'Rating (4)',
            21 => 'Rating (3)',
            22 => 'Rating (2)',
            23 => 'Rating (1)',    # no mapping for 24 on the Z7_2.  Possibly intended for Rating = 'Candidate for Deletion'?
            25 => 'None',
        },
        %infoZSeries,
    }],
    0x0b3 => [{ # CSg2-b (D6)
        Name => 'MovieFunc1Button',
        PrintConv => {
            1 => 'Power Aperture (Close)',
            2 => 'Exposure Compensation',
            3 => 'Grid Display',
            4 => 'Zoom (Low)',
            5 => 'Zoom (1:1)',
            6 => 'Zoom (High)',
            7 => 'Image Area',
            8 => 'Microphone Sensitivity',
            9 => 'None',
        },
        %infoD6,
    },{ # CSg2-b (Z7_2)
        Name => 'MovieFunc2Button',
        PrintConv => { # TODO:  simplify Func1 and Func2 movies buttons - identical except for the 1st entry
            1 => 'Power Aperture (Close)',
            2 => 'Exposure Compensation',
            3 => 'Subject Tracking',
            4 => 'LiveView Info Display On/Off',
            5 => 'Grid Display',
            6 => 'Zoom (Low)',
            7 => 'Zoom (1:1)',
            8 => 'Zoom (High)',
            9 => 'Protect',
            10 => 'Image Area',
            11 => 'White Balance',
            12 => 'Picture Control',
            13 => 'Active-D Lighting',
            14 => 'Metering',
            15 => 'Focus Mode',
            16 => 'Microphone Sensitivity',
            17 => 'Focus Peaking',
            18 => 'Rating (None)',
            19 => 'Rating (5)',
            20 => 'Rating (4)',
            21 => 'Rating (3)',
            22 => 'Rating (2)',
            23 => 'Rating (1)',    # no mapping for 24 on the Z7_2.  Possibly intended for Rating = 'Candidate for Deletion'?
            25 => 'None',
        },
        %infoZSeries,
    }],
    0x0b5 => { # CSg2-c (D6)
        Name => 'MovieFunc2Button',
        PrintConv => {
            1 => 'Grid Display',
            2 => 'Zoom (Low)',
            3 => 'Zoom (1:1)',
            4 => 'Zoom (High)',
            5 => 'Image Area',
            6 => 'Microphone Sensitivity',
            7 => 'None',
        },
    },
    0x0b6 => [{ # CSg2-e (D6)
        Name => 'AssignMovieSubselector',
        PrintConv => {
            1 => 'Center Focus Point',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AE/WB Lock (hold)',
            5 => 'AE Lock Only',
            6 => 'AE/AF Lock',
            7 => 'Zoom (Low)',
            8 => 'Zoom (1:1)',
            9 => 'Zoom (High)',
            10 => 'Record Movie',
            11 => 'None',
        },
        %infoD6,
    },{ # CSg2-d (Z7_2)
        Name => 'AssignMovieSubselector',
        PrintConv => {
            1 => 'Center Focus Point',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AE Lock Only',
            5 => 'AE/AF Lock',
            6 => 'LiveView Info Display On/Off',
            7 => 'Grid Display',
            8 => 'Zoom (Low)',
            9 => 'Zoom (1:1)',
            10 => 'Zoom (High)',
            11 => 'Record Movie',
            12 => 'Image Area',
            13 => 'None',
        },
        %infoZSeries,
    }],
    0x0b8 => { Name => 'LimitAFAreaModeSelD9',          PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-a (D6)
    0x0b9 => { Name => 'LimitAFAreaModeSelD25',         PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-b (D6)
    0x0bc => { Name => 'LimitAFAreaModeSel3D',          PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-e (D6)
    0x0bd => { Name => 'LimitAFAreaModeSelGroup',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-f (D6)
    0x0be => { Name => 'LimitAFAreaModeSelAuto',        PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-i (D6), CSa7-g (Z7_2)
  # 0x0bf => { Name => 'LimitSelectableImageArea30x20', PrintConv => \%limitNolimit }, # CSd8-1 (D6) further investigation & testing of CSd8-1 and CSd8-2 required.  The other CSd8 tags are fine.
  # 0x0c0 => { Name => 'LimitSelectableImageAreaDX',    PrintConv => \%limitNolimit }, # CSd8-2 (D6) further investigation & testing of CSd8-1 and CSd8-2 required.  The other CSd8 tags are fine.
    0x0c1 => { Name => 'LimitSelectableImageArea5To4',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd8-3 (D6)
    0x0c2 => { Name => 'LimitSelectableImageArea1To1',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd8-4 (D6)
  # 0x0d3 => CSf3-g-2 (D6), CSf2-d-2 (Z7_2) SelectorPlaybackRole 'Scroll' and  'Display Next/Previous' (skipped to reduce volume of output)
    0x0d4 => { Name => 'PhotoShootingMenuBank',         PrintConv => \%menuBank }, # (D6)
    0x0d5 => { Name => 'CustomSettingsBank',            PrintConv => \%menuBank }, # (D6)
    0x0d6 => { Name => 'LimitAF-AreaModeSelPinpoint',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-a (Z7_2)
    0x0d7 => { Name => 'LimitAF-AreaModeSelDynamic',    PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-b (Z7_2)
    0x0d8 => { Name => 'LimitAF-AreaModeSelWideAF_S',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-c (Z7_2)
    0x0d9 => { Name => 'LimitAF-AreaModeSelWideAF_L',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-d (Z7_2)
    0x0da => { Name => 'LowLightAF',                    PrintConv => \%onOff }, # CSa10 (Z7_2)
    0x0db => { Name => 'LimitSelectableImageAreaDX',    PrintConv => \%limitNolimit, Unknown => 1 }, # CSd7-a (Z7_2)
    0x0dc => { Name => 'LimitSelectableImageArea5To4',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd7-b (Z7_2)
    0x0dd => { Name => 'LimitSelectableImageArea1To1',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd7-c (Z7_2)
    0x0de => { Name => 'LimitSelectableImageArea16To9', PrintConv => \%limitNolimit, Unknown => 1 }, # CSd7-d (Z7_2)
    0x0df => { Name => 'ApplySettingsToLiveView',       PrintConv => \%onOff }, # CSd9  # new tag with Z7_2 # (Z7_2)
    0x0e0 => { # CSd10-a (D6), CSd11-a (Z7_2)
        Name => 'FocusPeakingLevel',
        PrintConv => {
            1 => 'High Sensitivity',
            2 => 'Standard Sensitivity',
            3 => 'Low Sensitivity',
            4 => 'Off',
        },
    },
    0x0ea => { # CSf2-i         #option for 'Focus (M/A)' is documented, but not available from camera menu
        Name => 'LensControlRing',
        PrintConv => {
            1 => 'Aperture',
            2 => 'Exposure Compensation',
            3 => 'ISO Sensitivity',
            4 => 'None (Disabled)',
        },
    },
  # 0x0eb  MovieLensControlRing ? # (Z7_2)
  # 0x0ec # (Z7_2)
    0x0ed => [{ # CSg3 (D6)
        Name => 'MovieMultiSelector',
        PrintConv => {
            1 => 'Center Focus Point',
            2 => 'Zoom (Low)',
            3 => 'Zoom (1:1)',
            4 => 'Zoom (High)',
            5 => 'Record Movie',
            6 => 'None',
        },
        %infoD6,
    },{ # labels Ok button on camera # (Z7_2)
        Name => 'MovieMultiSelector',
        PrintConv => { # Z7 has codes for both OK and MultiSelector - although only the OK value can be changed.  [The multiselector served as the OK button on these cameras].
            1 => 'Center Focus Point',
            2 => 'Zoom (Low)',
            3 => 'Zoom (1:1)',
            4 => 'Zoom (High)',
            5 => 'Record Movie',
            6 => 'None',
        },
    }],
    0x0ee => { Name => 'MovieAFSpeed', ValueConv => '$val - 6', ValueConvInv => '$val + 6' }, # CSg4-a (Z7_2)
    0x0ef => { # CSg4-b (Z7_2)
        Name => 'MovieAFSpeedApply',
        PrintConv => {
            1 => 'Always',
            2 => 'Only During Recording',
        },
    },
    0x0f0 => { # CSg5 (Z7_2)
        Name => 'MovieAFTrackingSensitivity',
        PrintConv => {
            1 => '1 (High)',
            2 => '2',
            3 => '3',
            4 => '4 (Normal)',
            5 => '5',
            6 => '6',
            7 => '7 (Low)',
        },
    },
    0x0f1 => { # CSg4-a (D6), CSg6-a (Z7_2)
        Name => 'MovieHighlightDisplayPattern',
        PrintConv => {
            1 => 'Pattern 1',
            2 => 'Pattern 2',
            3 => 'Off',
        },
    },
    0x0f2 => { Name => 'SubDialFrameAdvanceRating5',    PrintConv => \%noYes, Unknown => 1 }, # (D6,Z7_2)
    0x0f3 => { Name => 'SubDialFrameAdvanceRating4',    PrintConv => \%noYes, Unknown => 1 }, # (D6,Z7_2)
    0x0f4 => { Name => 'SubDialFrameAdvanceRating3',    PrintConv => \%noYes, Unknown => 1 }, # (D6,Z7_2)
    0x0f5 => { Name => 'SubDialFrameAdvanceRating2',    PrintConv => \%noYes, Unknown => 1 }, # (D6,Z7_2)
    0x0f6 => { Name => 'SubDialFrameAdvanceRating1',    PrintConv => \%noYes, Unknown => 1 }, # (D6,Z7_2)
    0x0f7 => { Name => 'SubDialFrameAdvanceRating0',    PrintConv => \%noYes, Unknown => 1 }, # (D6,Z7_2)
  # 0x0f8 ??  looks like it should be part of the above, but nothing seems to cause the value to change.  Possibly intended for Rating='Candidate for Deletion' # (D6)
    0x0f9 => { # CSg2-c (Z7_2)
        Name => 'MovieAF-OnButton',
        PrintConv => {
            1 => 'Center Focus Point',
            2 => 'AF-On',
            3 => 'AF Lock Only',
            4 => 'AE Lock (hold)',
            5 => 'AE Lock Only',
            6 => 'AE/AF Lock',
            7 => 'LiveView Info Display On/Off',
            8 => 'Zoom (Low)',
            9 => 'Zoom (1:1)',
            10 => 'Zoom (High)',
            11 => 'Record Movie',
            12 => 'None',
        },
    },
    0x0fb => { Name => 'SecondarySlotFunction', PrintConv => \%tagSecondarySlotFunction },    # tag name selected to maintain compatibility with older cameras # (Z7_2)
    0x0fb => { Name => 'SecondarySlotFunction', PrintConv => \%tagSecondarySlotFunction }, # (D6)
    0x0fc => { Name => 'SilentPhotography',     PrintConv => \%onOff }, # (D6,Z7_2)   # tag is associated with Silent LiveView Photography (as distinguisehed from Silent Interval or Silent Focus Shift)
    0x0fd => { Name => 'ExtendedShutterSpeeds', PrintConv => \%onOff }, # CSd7 (D6), CSd6 (Z7_2)
    0x102 => { # (Z7_2)
        Name => 'HDMIBitDepth',
        RawConv => '$$self{HDMIBitDepth} = $val',
        PrintConv => {
            1 => '8 Bit',
            2 => '10 Bit',
            #5 => 'Auto',     #observed on the Z50 - needs confirmation
        },
    },
    0x103 => { # (Z7_2)
        Name => 'HDMIOutputHDR',
        Condition => '$$self{HDMIBitDepth}  == 2',   # HDR(HLC) output option only available only for 10 bit
        RawConv => '$$self{HDMIOutputHDR} = $val',
        PrintConv => {
            2 => 'On',  # unusual decode perhaps due to sharing sub-menu with tag HDMIOutputN-Log?
            3 => 'Off',
        },
    },
    0x104 => {  # valid for 10 bit with either N-Log or HDR/HLG selected    CSg5 (Z7_2)
        Name => 'HDMIViewAssist',
        Condition => '$$self{HDMIBitDepth}  == 2',
        PrintConv => \%onOff
    },
    0x109 => { # (D6,Z7_2)
        Name => 'BracketSet',
        RawConv => '$$self{BracketSet} = $val',
        PrintConv => {
            1 => 'AE/Flash',
            2 => 'AE',
            3 => 'Flash',
            4 => 'White Balance',
            5 => 'Active-D Lighting',
        },
    },
    0x10a => [{ # (D6/Z7_2)
        Name => 'BracketProgram',
        Condition => '$$self{BracketSet} < 4',
        Notes => 'AE and/or Flash Bracketing',
        RawConv => '$$self{BracketProgram} = $val',
        PrintConv =>  {
            15 => '+3F',
            16 => '-3F',
            17 => '+2F',
            18 => '-2F',
            19 => 'Disabled',
            20 => '3F',
            21 => '5F',
            22 => '7F',
            23 => '9F',
        },
    },{
        Name => 'BracketProgram',
        Condition => '$$self{BracketSet} and $$self{BracketSet} == 4',
        Notes => 'White Balance Bracketing',
        RawConv => '$$self{BracketProgram} = $val',
        PrintConv =>  {
            1 => 'B3F',
            2 => 'A3F',
            3 => 'B2F',
            4 => 'A2F',
            5 => 'Disabled',
            6 => '3F',
            7 => '5F',
            8 => '7F',
            9 => '9F',
            19 => 'N/A'    # observed when shooting other than JPG
        },
    },{
        Name => 'BracketProgram',
        Condition => '$$self{BracketSet} and $$self{BracketSet} == 5',
        Notes => 'Active-D Bracketing',
        RawConv => '$$self{BracketProgram} = $val',
        Mask => 0x0f,
        PrintConv =>  {
            10 => 'Disabled',
            11 => '2 Exposures',
            12 => '3 Exposures',
            13 => '4 Exposures',
            14 => '5 Exposures',
        },
    }],
    0x10b => [{ # (D6/Z7_2)
        Name => 'BracketIncrement',
        Condition => '$$self{BracketSet} < 4 and $$self{BracketProgram} ne 19',
        Notes => 'AE and/or Flash Bracketing enabled',
        PrintConv =>  {
            0x01 => '0.3',
            0x03 => '0.5',
            0x04 => '1.0',
            0x05 => '2.0',
            0x06 => '3.0',
        },
    },{
        Name => 'BracketIncrement',
        Condition => '$$self{BracketSet} == 4 and $$self{BracketProgram} ne 5',
        Notes => 'White Balance Bracketing enabled',
        PrintConv => '$val-6',   # TODO:  qualify amber/blue direction of increment (eg, '1A' vs.'1B' vs '1A,1B')
    }],
    0x10c => { # (D6/Z7_2)
        Name => 'BracketIncrement',
        Condition => '$$self{BracketSet} == 5 and $$self{BracketProgram} ne 10',
        Notes => 'Active-D Bracketing enabled',
        PrintConv =>  {
            0 => 'Off',
            1 => 'Off, Low',
            2 => 'Off, Normal',
            3 => 'Off, High',
            4 => 'Off, Extra High',
            5 => 'Off, Auto',
            6 => 'Off, Low, Normal',
            7 => 'Off, Low, Normal, High',
            8 => 'Off, Low, Normal, High, Extra High',
        },
    },
    0x10e  => { # (D6/Z7_2)
        Name => 'MonitorBrightness',
        # settings: -5 to +5
        ValueConv => '$val - 6',
    },
    0x116 => { Name => 'GroupAreaC1',               PrintConv =>\%groupAreaCustom },    # CSa10-a (new with D6) # (D6)
    0x117 => { Name => 'AutoAreaAFStartingPoint',   PrintConv => \%enableDisable },     # CSa12 (D6)
    0x118 => { Name => 'FocusPointPersistence',     PrintConv => { 1 => 'Auto', 2 => 'Off' } }, # CSa13 (new with D6) # (D6)
    0x119 => { Name => 'LimitAFAreaModeSelD49',     PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-c (D6)
    0x11a => { Name => 'LimitAFAreaModeSelD105',    PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-d (D6)
    0x11b => { Name => 'LimitAFAreaModeSelGroupC1', PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-g (D6)
    0x11c => { Name => 'LimitAFAreaModeSelGroupC2', PrintConv => \%limitNolimit, Unknown => 1 }, # CSa14-h (D6)
    0x11d => { # CSa15 (D6)
        Name => 'AutoFocusModeRestrictions',
        PrintConv => {
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'No Limit',
        },
    },
    0x11e => { # CSa17-b (D6)
        Name => 'FocusPointBrightness',
        PrintConv => {
            1 => 'Extra High',
            2 => 'High',
            3 => 'Normal',
            4 => 'Low',
        },
    },
    0x11f => { Name => 'CHModeShootingSpeed',       ValueConv => '15 - $val', ValueConvInv => '15 + $val', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1-a (D6)
    0x120 => { Name => 'CLModeShootingSpeed',       ValueConv => '11 - $val', ValueConvInv => '11 + $val', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1-b (D6)
    0x121 => { # CSd1-c (new with D6)
        Name => 'QuietShutterShootingSpeed',
        PrintConv => {
            1 => 'Single',
            2 => '5 fps',
            3 => '4 fps',
            4 => '3 fps',
            5 => '2 fps',
            6 => '1 fps',
        },
    },
    0x122 => { Name => 'LimitReleaseModeSelCL',         PrintConv => \%limtReleaseModeSel, Unknown => 1 }, # CSd3-a (D6)
    0x123 => { Name => 'LimitReleaseModeSelCH',         PrintConv => \%limtReleaseModeSel, Unknown => 1 }, # CSd3-b (D6)
    0x124 => { Name => 'LimitReleaseModeSelQ',          PrintConv => \%limtReleaseModeSel, Unknown => 1 }, # CSd3-c (D6)
    0x125 => { Name => 'LimitReleaseModeSelTimer',      PrintConv => \%limtReleaseModeSel, Unknown => 1 }, # CSd3-d (D6)
    0x126 => { Name => 'LimitReleaseModeSelMirror-Up',  PrintConv => \%limtReleaseModeSel, Unknown => 1 }, # CSd3-e (D6)
    0x127 => { Name => 'LimitSelectableImageArea16To9', PrintConv => \%limitNolimit, Unknown => 1 }, # CSd8-5 (D6)
    0x128 => { Name => 'RearControPanelDisplay',        PrintConv => { 1 => 'Release Mode', 2 => 'Frame Count' } }, # CSd12  # new tag with D6 # (D6)
    0x129 => { Name => 'FlashBurstPriority',            PrintConv => { 1 => 'Frame Rate', 2 => 'Exposure' } }, # CSE5   # new tag with D6 # (D6)
    0x12a => { Name => 'RecallShootFuncExposureMode',   PrintConv => \%offOn }, # (D6)
    0x12b => { Name => 'RecallShootFuncShutterSpeed',   PrintConv => \%offOn }, # (D6)
    0x12c => { Name => 'RecallShootFuncAperture',       PrintConv => \%offOn }, # (D6)
    0x12d => { Name => 'RecallShootFuncExposureComp',   PrintConv => \%offOn }, # (D6)
    0x12e => { Name => 'RecallShootFuncISO',            PrintConv => \%offOn }, # (D6)
    0x12f => { Name => 'RecallShootFuncMeteringMode',   PrintConv => \%offOn }, # (D6)
    0x130 => { Name => 'RecallShootFuncWhiteBalance',   PrintConv => \%offOn }, # (D6)
    0x131 => { Name => 'RecallShootFuncAFAreaMode',     PrintConv => \%offOn }, # (D6)
    0x132 => { Name => 'RecallShootFuncFocusTracking',  PrintConv => \%offOn }, # (D6)
    0x133 => { Name => 'RecallShootFuncAF-On',          PrintConv => \%offOn }, # (D6)
    0x134 => { # CSf3-d (D6)
        Name => 'VerticalFuncButton',
        PrintConv => {
            1 => 'Preset Focus Point',
            2 => 'AE Lock (hold)',
            3 => 'AE/WB Lock (hold)',
            4 => 'AE Lock (reset on release)',
            5 => 'FV Lock',
            6 => 'Preview',
            7 => '+NEF(RAW)',
            8 => 'Grid Display',
            9 => 'Virtual Horizon',
            10 => 'Voice Memo',
            11 => 'Playback',
            12 => 'Filtered Playback',
            13 => 'Photo Shooting Bank',
            14 => 'Exposure Mode',
            15 => 'Exposure Comp',
            16 => 'AF Mode/AF Area Mode',
            17 => 'Image Area',
            18 => 'ISO',
            19 => 'Active-D Lighting',
            20 => 'Metering',
            21 => 'Exposure Delay Mode',
            22 => 'Shutter/Aperture Lock',
            23 => '1 Stop Speed/Aperture',
            24 => 'Rating 0',
            25 => 'Rating 5',
            26 => 'Rating 4',
            27 => 'Rating 3',
            28 => 'Rating 2',
            29 => 'Rating 1',
            30 => 'Candidate For Deletion',
            31 => 'Non-CPU Lens',
            32 => 'None',
        },
    },
    0x135 => { # CSf3-e (D6)
        Name => 'Func3Button',
        PrintConv => {
            1 => 'Voice Memo',
            2 => 'Select To Send',
            3 => 'Wired LAN',
            4 => 'My Menu',
            5 => 'My Menu Top Item',
            6 => 'Filtered Playback',
            7 => 'Rating 0',
            8 => 'Rating 5',
            9 => 'Rating 4',
            10 => 'Rating 3',
            11 => 'Rating 2',
            12 => 'Rating 1',
            13 => 'Candidate For Deletion',
            14 => 'None',
        },
    },
    0x136 => { # CSf3-i (D6)
        Name => 'VerticalAF-OnButton',
        PrintConv => {
            1 => 'AF-AreaMode S',
            2 => 'AF-AreaMode D9',
            3 => 'AF-AreaMode D25',
            4 => 'AF-AreaMode D49',
            5 => 'AF-AreaMode D105',
            6 => 'AF-AreaMode 3D',
            7 => 'AF-AreaMode Group',
            8 => 'AF-AreaMode Group C1',
            9 => 'AF-AreaMode Group C2',
            10 => 'AF-AreaMode Auto Area',
            11 => 'AF-AreaMode + AF-On S',
            12 => 'AF-AreaMode + AF-On D9',
            13 => 'AF-AreaMode + AF-On D25',
            14 => 'AF-AreaMode + AF-On D49',
            15 => 'AF-AreaMode + AF-On D105',
            16 => 'AF-AreaMode + AF-On 3D',
            17 => 'AF-AreaMode + AF-On Group',
            18 => 'AF-AreaMode + AF-On Group C1',
            19 => 'AF-AreaMode + AF-On Group C2',
            20 => 'AF-AreaMode + AF-On Auto Area',
            21 => 'Same as AF-On',
            22 => 'AF-On',
            23 => 'AF Lock Only',
            24 => 'AE Lock (hold)',
            25 => 'AE/WB Lock (hold)',
            26 => 'AE Lock (reset on release)',
            27 => 'AE Lock Only',
            28 => 'AE/AF Lock',
            29 => 'Recall Shooting Functions',
            30 => 'None',
        },
    },
    0x137 => { Name => 'VerticalMultiSelector', PrintConv => \%tagSubSelector }, # CSf3-j-1 # (D6)
    0x138 => { # CSf3-k (D6)
        Name => 'MeteringButton',
        PrintConv => {
            1 => 'Photo Shooting Bank',
            2 => 'Image Area',
            3 => 'Active-D Lighting',
            4 => 'Metering',
            5 => 'Exposure Delay Mode',
            6 => 'Shutter/Aperture Lock',
            7 => '1 Stop Speed/Aperture',
            8 => 'Non-CPU Lens',
            9 => 'None',
        },
    },
    0x139 => { Name => 'PlaybackFlickUp', RawConv => '$$self{PlaybackFlickUp} = $val', PrintConv => \%flickUpDownD6 }, # CSf12-1-a # (D6)
    0x13a => { Name => 'PlaybackFlickUpRating', Condition => '$$self{PlaybackFlickUp} and $$self{PlaybackFlickUp} == 1', Notes => 'Meaningful only when PlaybackFlickUp is Rating', PrintConv => \%flickUpDownRatingD6 }, # CSf12-1-b # (D6)
    0x13b => { Name => 'PlaybackFlickDown', RawConv => '$$self{PlaybackFlickDown} = $val', PrintConv => \%flickUpDownD6 }, # CSf12-2-a # (D6)
    0x13c => { Name => 'PlaybackFlickDownRating', Condition => '$$self{PlaybackFlickDown} and $$self{PlaybackFlickDown} == 1', Notes => 'Meaningful only when PlaybackFlickDown is Rating', PrintConv => \%flickUpDownRatingD6 }, # CSf12-2-b # (D6)
    0x13d => {  # CSg2-d (D6)
        Name => 'MovieFunc3Button',
        PrintConv => {
            1 => 'Record Movie',
            2 => 'My Menu',
            3 => 'My Menu Top Item',
            4 => 'None',
        },
    },
    0x150 => { # CSd5 (Z7_2) new with Z series
        Name => 'ShutterType',
        PrintConv => {
            1 => 'Auto',
            2 => 'Mechanical',
            3 => 'Electronic',
        },
    },
    0x151 => { Name => 'LensFunc2Button',       PrintConv => \%lensFuncButtonZ7m2 }, # CSf2-h (Z7_2)
    #0x153 => { Name => 'ViewfinderBrightness', }      #(Z7_2)   # commented out to reduce output volume.  Range [-5,+5]. PrintConv matches MonitorBrightness.
    0x158 => { Name => 'USBPowerDelivery',      PrintConv => \%enableDisable }, # (Z7_2)
    0x159 => { Name => 'EnergySavingMode',      PrintConv =>\%onOff },    # (Z7_2)
    0x15c => { Name => 'BracketingBurstOptions',PrintConv => \%enableDisable }, # CSe9 (D6)
  # 0x15d => CSf3-j-2 (D6) 'Same as Multi-Selector with Info(U/D) & Playback(R/L)'  and  'Same as Multi-Selector with Info(R/L) & Playback(U/D)'  (skipped to reduce volume of output)
    0x15e => { Name => 'PrimarySlot',           PrintConv => { 1 => 'CFexpress/XQD Card', 2 => 'SD Card' } }, # (Z7_2)
    0x15f => { Name => 'ReverseFocusRing',      PrintConv => { 1 => 'Not Reversed', 2 => 'Reversed' } }, # CSf8 (Z7_2)
    0x160 => { # CSf9-a (Z7_2)
        Name => 'VerticalFuncButton',
        PrintConv => {
            1 => 'AE Lock (hold)',
            2 => 'AE Lock (reset on release)',
            3 => 'FV Lock',
            4 => 'Preview',
            5 => '+NEF(RAW)',
            6 => 'Subject Tracking',
            7 => 'Silent Photography',
            8 => 'LiveView Info Display On/Off',
            9 => 'Playback',
            10 => 'Image Area',
            11 => 'Metering',
            12 => 'Flash Mode',
            13 => 'Focus Mode',
            14 => 'Exposure Delay Mode',
            15 => 'Shutter/Aperture Lock',
            16 => 'Exposure Compensation',
            17 => 'ISO Sensitivity',
            18 => 'None',
        },
    },
    0x161 => { # CSf9-b (Z7_2)
        Name => 'VerticalAFOnButton',
        PrintConv => {
            1 => 'Same as AF-On Button',
            2 => 'Select Center Focus Point',
            3 => 'AF-On',
            4 => 'AF Lock Only',
            5 => 'AE Lock (hold)',
            6 => 'AE Lock (reset on release)',
            7 => 'AE Lock Only',
            8 => 'AE/AF Lock',
            9 => 'LiveView Info Display On/Off',
            10 => 'Zoom (Low)',
            11 => 'Zoom (1:1)',
            12 => 'Zoom (High)',
            13 => 'None',
        },
    },
    0x162 => { Name => 'VerticalMultiSelector', PrintConv => \%tagSubSelector }, # CSf9-c (Z7_2)
  # 0x163 => CSf9-c-2 (Z7_2) 'Same as Multi-Selector with Info(U/D) & Playback(R/L)' and 'Same as Multi-Selector with Info(R/L) & Playback(U/D)' (skipped to reduce volume of output)
    0x164 => { # CSg7-a (Z7_2)
        Name => 'VerticalMovieFuncButton',
        PrintConv => {
            1 => 'LiveView Info Display On/Off',
            2 => 'Record Movie',
            3 => 'Exposure Compensation',
            4 => 'ISO',
            5 => 'None',
        },
    },
    0x165 => { # CSg7-b (Z7_2)
        Name => 'VerticalMovieAFOnButton',
        PrintConv => {
            1 => 'Same as AF-On',
            2 => 'Center Focus Point',
            3 => 'AF-On',
            4 => 'AF Lock Only',
            5 => 'AE Lock (hold)',
            6 => 'AE Lock Only',
            7 => 'AE/AF Lock',
            8 => 'LiveView Info Display On/Off',
            9 => 'Zoom (Low)',
            10 => 'Zoom (1:1)',
            11 => 'Zoom (High)',
            12 => 'Record Movie',
            13 => 'None',
        },
    },
    #0x168 => { Name => 'ControlPanelBrightness',   # (Z7_2)   #commented to reduce output volume
    0x169 => { Name => 'LimitAF-AreaModeSelAutoPeople',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-h (Z7_2)
    0x16a => { Name => 'LimitAF-AreaModeSelAutoAnimals',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-h (Z7_2)
    0x16b => { Name => 'LimitAF-AreaModeSelWideLPeople',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-e (Z7_2)
    0x16c => { Name => 'LimitAF-AreaModeSelWideLAnimals', PrintConv => \%limitNolimit, Unknown => 1 }, # CSa7-f (Z7_2)
    0x16d => { Name => 'SaveFocus', PrintConv => \%onOff }, # (Z7_2)
    0x16e => { # (Z7_2)
        Name => 'AFAreaMode',
        RawConv => '$$self{AFAreaMode} = $val',
        PrintConv => {
            2 => 'Single-point',
            3 => 'Dynamic-area',
            4 => 'Wide (S)',
            5 => 'Wide (L)',
            6 => 'Wide (L-people)',
            7 => 'Wide (L-animals)',
            8 => 'Auto',
            9 => 'Auto (People)',
            10 => 'Auto (Animals)',
        },
    },
    0x16f => { # (Z7_2)
        Name => 'MovieAFAreaMode',
        PrintConv => {
            1 => 'Single-point',
            2 => 'Wide (S)',
            3 => 'Wide (L)',
            4 => 'Wide (L-people)',
            5 => 'Wide (L-animals)',
            6 => 'Auto',
            7 => 'Auto (People)',
            8 => 'Auto (Animals)',
        },
    },
    0x170 => { Name => 'PreferSubSelectorCenter', PrintConv => \%offOn }, # CSf13 (D6 firmware v1.2.0)
    0x171 => { # CSb8 (D6 firmware v1.3.0)
        Name => 'KeepExposureWithTeleconverter',
        PrintConv => {
            1 => 'Off',
            2 => 'Shutter Speed',
            3 => 'ISO',
        },
    },
    0x174 => { # CSa17-d (D6 firmware v1.2.0)
        Name => 'FocusPointSelectionSpeed',
        PrintConv => {
            1 => 'Normal',
            2 => 'High',
            3 => 'Very High',
        },
    },
);

#------------------------------------------------------------------------------
# Process NikonSettings directory (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNikonSettings($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;

    # NikonSettings directory has a 24-byte header:
    #  0x00 - undef[4]: '0100'
    #  0x04 - int32u:   1 (D-models), 2 (Z-models)
    #  0x08 - undef[4]: '0100'
    #  0x0c - int32u:   1 (Z7), 2 (D850), 3 (D780,Z50), 4 (D6,Z5), 5(Z7m2)
    #  0x10 - undef[4]: firmware version (eg. '0110' for firmware 1.10)
    #  0x14 - int32u:   number of entries in directory

    return 0 if $$dirInfo{DirLen} < 24; # sanity check

    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $num = Get32u($dataPt, $start + 0x14);

    $et->VerboseDir('NikonSettings', $num);

    my $n = int(($$dirInfo{DirLen} - 0x18) / 8);
    if ($n < $num) {
        $et->Warn('Missing '.($num-$n).' NikonSettings entries', 1);
        $num = $n;
    } elsif ($n > $num) {
        $et->Warn('Unused space in NikonSettings directory', 1);
    }
    my $i;
    for ($i=0; $i<$num; ++$i) {
        my $entry = $start + 0x18 + $i * 8;
        my $tag = Get16u($dataPt, $entry);
        # this is odd, but either the format is 16-bit and always big-endian,
        # or it is 8-bit and we have an unknown byte in the entry...
        my $fmt = Get8u($dataPt,  $entry + 3);
        my $val = Get32u($dataPt, $entry + 4);
        # abort if the tag has a format that we haven't yet seen
        # (assuming this is a size/format code.  So far we have only seen a code of 4)
        $fmt == 4 or $et->Warn(sprintf('Unknown format $fmt for NikonSettings tag 0x%.4x',$tag)), last;
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Base    => $$dirInfo{Base},
            Start   => $entry + 4,
            Size    => 4,
            Format  => 'int32u',
            Index   => $i,
        );
    }
    return 1;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::NikonSettings - Read Nikon user settings

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains the definitions necessary to read the user settings for
Nikon cameras such as the D6 and Z7mk2.


=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Warren Hatch for his work decoding settings for the D6 and Z7mkII,
and for providing the original source code for this module.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
