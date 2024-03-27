#------------------------------------------------------------------------------
# File:         NikonCustom.pm
#
# Description:  Read and write Nikon Custom settings
#
# Revisions:    2009/11/25 - P. Harvey Created
#
# References:   1) Warren Hatch private communication (D3 and Z9 with SB-800 and SB-900)
#               2) Anonymous contribution 2011/05/25 (D700, D7000)
#              JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::NikonCustom;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK %buttonsZ9);

$VERSION = '1.25';

@ISA = qw(Exporter);
@EXPORT_OK = qw(%buttonsZ9);

%buttonsZ9= (
    SeparateTable => 'ButtonsZ9',
    PrintConv => {
        0 => 'None',
        1 => 'Preview',
        3 => 'FV Lock',
        4 => 'AE/AF Lock',
        5 => 'AE Lock Only',
        6 => 'AE Lock (reset on release)',
        7 => 'AE Lock (hold)',
        8 => 'AF Lock Only',
        9 => 'AF-On',
        10 => 'Flash Disable/Enable',
        11 => 'Bracketing Burst',
        12 => '+NEF(RAW)',
        18 => 'Virtual Horizon',
        19 => 'Synchronized Release',
        20 => 'My Menu',
        21 => 'My Menu Top Item',
        22 => 'Playback',
        23 => 'Rating',
        24 => 'Protect',
        25 => 'Zoom',
        26 => 'Focus Peaking',
        27 => 'Flash Mode/Compensation',
        28 => 'Image Area',
        30 => 'Non-CPU Lens',
        31 => 'Active-D Lighting',
        32 => 'Exposure Delay Mode',
        33 => '1 Stop Speed/Aperture',
        34 => 'White Balance',
        35 => 'Metering',
        36 => 'Auto Bracketing',
        37 => 'Multiple Exposure',
        38 => 'HDR Overlay',
        39 => 'Picture Control',
        40 => 'Quality',
        41 => 'Focus Mode/AF AreaMode',
        42 => 'Select Center Focus Point',
        44 => 'Record Movie',
        45 => 'Thumbnail On/Off',
        46 => 'View Histograms',
        47 => 'Choose Folder',
        48 => 'Power Aperture (Open)',
        49 => 'Power Aperture (Close)',
        52 => 'Microphone Sensitivity',
        53 => 'Release Mode',
        57 => 'Preset Focus Point',
        58 => 'AE/AWB Lock (hold)',
        59 => 'AF-AreaMode',
        60 => 'AF-AreaMode + AF-On',
        61 => 'Recall Shooting Functions',
        64 => 'Filtered Playback',
        65 => 'Same as AF-On',
        66 => 'Voice Memo',
        70 => 'Photo Shooting Bank',
        71 => 'ISO',
        72 => 'Shooting Mode',
        73 => 'Exposure Compensation',
        76 => 'Silent Mode',
        78 => 'LiveView Information',
        79 => 'AWB Lock (hold)',
        80 => 'Grid Display',
        81 => 'Starlight View',
        82 => 'Select To Send (PC)',
        83 => 'Select To Send (FTP)',
        84 => 'Pattern Tone Range',
        85 => 'Control Lock',
        86 => 'Save Focus Position',
        87 => 'Recall Focus Position',
        88 => 'Recall Shooting Functions (Hold)',
        89 => 'Set Picture Control (HLG)',
        90 => 'Skin Softening',
        91 => 'Portrait Impression Balance',
        97 => 'High Frequency Flicker Reduction',
        98 => 'Switch FX/DX',
        99 => 'View Mode (Photo LV)',
        100 => 'Photo Flicker Reduction',
        101 => 'Filtered Playback (Select Criteria)',
        103 => 'Start Series Playback',
        104 => 'View Assist',
        105 => 'Hi-Res Zoom+',
        106 => 'Hi-Res Zoom-',
        108 => 'Override Other Cameras',
        109 => 'DISP - Cycle Information Display (shooting)', # Shooting Mode
        110 => 'DISP - Cycle Information Display (playback)', # Playback mode
        111 => 'Resume Shooting',
        112 => 'Switch Eyes',
        113 => 'Power Zoom +',
        114 => 'Power Zoom -',
        115 => 'Delete',
        116 => 'Pixel Shift Shooting',
        117 => 'Cycle AF-area Mode',
        118 => 'Raw Processing (Current)',  #118-131 are Retouch options
        119 => 'Raw Processing (Multiple)',
        120 => 'Trim',
        121 => 'Resize (Current)',
        122 => 'Resize (Multiple)',
        123 => 'D-Lighting',
        124 => 'Straighten',
        125 => 'Distortion Control',
        126 => 'Perspective Control',
        127 => 'Monochrome',
        128 => 'Overlay (Add)',
        129 => 'Lighten',
        130 => 'Darken',
        131 => 'Motion Blend',
    },
);
my %dialsZ9 = (
    0 => '1 Frame',
    1 => '10 Frames',
    2 => '50 Frames',
    3 => 'Folder',
    4 => 'Protect',
    5 => 'Photos Only',
    6 => 'Videos Only',
    7 => 'Rating',
    8 => 'Page',
    9 => 'Skip To First Shot In Series',
    10 => 'Uploaded to FTP',
    11 => 'Uploaded to Computer',
);
my %dialsVideoZ9 = (
    0 => '2 s',
    1 => '5 s',
    2 => '10 s',
    3 => '1 Frame',
    4 => '5 Frames',
    5 => '10 Frames',
    6 => 'First/Last Frame',
    7 => 'Playback Speed',
);
my %evfGridsZ9 = (
    0 => '3x3',
    1 => '4x4',
    2 => '2.35:1',
    3 => '1.85:1',
    4 => '5:4',
    5 => '4:3',
    6 => '1:1',
    7 => '16:9',
    8 => '90%',
);
my %flicksZ9 = (
     0 => 'Rating',
    1 => 'Select To Send (PC)',
    2 => 'Select To Send (FTP)',
    3 => 'Protect',
    4 => 'Voice Memo',
    5 => 'None',
);
my %focusModeRestrictionsZ9 = (
    0 => 'AF-S',
    1 => 'AF-C',
    2 => 'Full-time AF',
    3 => 'Manual',
    4 => 'No Restrictions',
);
my %powerOffDelayTimesZ9 = (
    SeparateTable => 'DelaysZ9',
    PrintConv => {
        0 => '2 s',
        1 => '4 s',
        3 => '10 s',
        4 => '20 s',
        5 => '30 s',
        6 => '1 min',
        7 => '5 min',
        8 => '10 min',
        11 => '30 min',
        12 => 'No Limit',
    },
);
my %thirdHalfFull = (
    0 => '1/3 EV',
    1 => '1/2 EV',
    2 => '1 EV',
);

my %limitNolimit = ( 0 => 'Limit', 1 => 'No Limit' );
my %offOn = ( 0 => 'Off', 1 => 'On' );
my %onOff = ( 0 => 'On', 1 => 'Off' );
my %noYes = ( 0 => 'No', 1 => 'Yes' );

# custom settings for the D80 (encrypted) - ref JD
%Image::ExifTool::NikonCustom::SettingsD80 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the Nikon D80.',
    0.1 => { # CS1
        Name => 'Beep',
        Mask => 0x80,
        PrintConv => \%onOff,
    },
    0.2 => { # CS4
        Name => 'AFAssist',
        Mask => 0x40,
        PrintConv => \%onOff,
    },
    0.3 => { # CS5
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    0.4 => { # CS6
        Name => 'ImageReview',
        Mask => 0x10,
        PrintConv => \%onOff,
    },
    0.5 => { # CS17
        Name => 'Illumination',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    0.6 => { # CS11
        Name => 'MainDialExposureComp',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    0.7 => { # CS10
        Name => 'EVStepSize',
        Mask => 0x01,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    1.1 => { # CS7
        Name => 'AutoISO',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    1.2 => { # CS7-a
        Name => 'AutoISOMax',
        Mask => 0x30,
        PrintConv => {
            0 => 200,
            1 => 400,
            2 => 800,
            3 => 1600,
        },
    },
    1.3 => { # CS7-b
        Name => 'AutoISOMinShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/125 s',
            1 => '1/100 s',
            2 => '1/80 s',
            3 => '1/60 s',
            4 => '1/40 s',
            5 => '1/30 s',
            6 => '1/15 s',
            7 => '1/8 s',
            8 => '1/4 s',
            9 => '1/2 s',
            10 => '1 s',
        },
    },
    2.1 => { # CS13
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0 => 'AE & Flash',
            1 => 'AE Only',
            2 => 'Flash Only',
            3 => 'WB Bracketing',
        },
    },
    2.2 => { # CS14
        Name => 'AutoBracketOrder',
        Mask => 0x20,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    3.1 => { # CS27
        Name => 'MonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '5 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    3.2 => { # CS28
        Name => 'MeteringTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            2 => '8 s',
            3 => '16 s',
            4 => '30 s',
            5 => '30 min',
        },
    },
    3.3 => { # CS29
        Name => 'SelfTimerTime',
        Mask => 0x03,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    4.1 => { # CS18
        Name => 'AELockButton',
        Mask => 0x1e,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AF-ON',
            5 => 'FV Lock',
            6 => 'Focus Area Selection',
            7 => 'AE-L/AF-L/AF Area',
            8 => 'AE-L/AF Area',
            9 => 'AF-L/AF Area',
            10 => 'AF-ON/AF Area',
        },
    },
    4.2 => { # CS19
        Name => 'AELock',
        Mask => 0x01,
        PrintConv => \%offOn,
    },
    4.3 => { # CS30
        Name => 'RemoteOnDuration',
        Mask => 0xc0,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
        },
    },
    5.1 => { # CS15
        Name => 'CommandDials',
        Mask => 0x80,
        PrintConv => {
            0 => 'Standard (Main Shutter, Sub Aperture)',
            1 => 'Reversed (Main Aperture, Sub Shutter)',
        },
    },
    5.2 => { # CS16
        Name => 'FunctionButton',
        Mask => 0x78,
        PrintConv => {
            0 => 'ISO Display',
            1 => 'Framing Grid',
            2 => 'AF-area Mode',
            3 => 'Center AF Area',
            4 => 'FV Lock',
            5 => 'Flash Off',
            6 => 'Matrix Metering',
            7 => 'Center-weighted',
            8 => 'Spot Metering',
        },
    },
    6.1 => { # CS8
        Name => 'GridDisplay',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    6.2 => { # CS9
        Name => 'ViewfinderWarning',
        Mask => 0x40,
        PrintConv => \%onOff,
    },
    6.3 => { # CS12
        Name => 'CenterWeightedAreaSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '6 mm',
            1 => '8 mm',
            2 => '10 mm',
        },
    },
    6.4 => { # CS31
        Name => 'ExposureDelayMode',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    6.5 => { # CS32
        Name => 'MB-D80Batteries',
        Mask => 0x03,
        PrintConv => {
            0 => 'LR6 (AA Alkaline)',
            1 => 'HR6 (AA Ni-MH)',
            2 => 'FR6 (AA Lithium)',
            3 => 'ZR6 (AA Ni-Mg)',
        },
    },
    7.1 => { # CS23
        Name => 'FlashWarning',
        Mask => 0x80,
        PrintConv => \%onOff,
    },
    7.2 => { # CS24
        Name => 'FlashShutterSpeed',
        Mask => 0x78,
        ValueConv => '2 ** ($val - 6)',
        ValueConvInv => '$val>0 ? int(log($val)/log(2)+6+0.5) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    7.3 => { # CS25
        Name => 'AutoFP',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    7.4 => { # CS26
        Name => 'ModelingFlash',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    8.1 => { # CS22
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    8.2 => { # CS22-a
        Name => 'ManualFlashOutput',
        Mask => 0x07,
        ValueConv => '2 ** (-$val)',
        ValueConvInv => '$val > 0 ? -log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CS22-b
        Name => 'RepeatingFlashOutput',
        Mask => 0x70,
        ValueConv => '2 ** (-$val-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CS22-c
        Name => 'RepeatingFlashCount',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    10.1 => { # CS22-d
        Name => 'RepeatingFlashRate',
        Mask => 0xf0,
        ValueConv => '$val < 10 ? $val + 1 : 10 * ($val - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5)',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    10.2 => { # CS22-n
        Name => 'CommanderChannel',
        Mask => 0x03,
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    11.1 => { # CS22-e
        Name => 'CommanderInternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Off',
        },
    },
    11.2 => { # CS22-h
        Name => 'CommanderGroupAMode',
        Mask => 0x30,
        PrintConv => {
            0 => 'TTL',
            1 => 'Auto Aperture',
            2 => 'Manual',
            3 => 'Off',
        },
    },
    11.3 => { # CS22-k
        Name => 'CommanderGroupBMode',
        Mask => 0x0c,
        PrintConv => {
            0 => 'TTL',
            1 => 'Auto Aperture',
            2 => 'Manual',
            3 => 'Off',
        },
    },
    12.1 => { # CS22-f
        Name => 'CommanderInternalTTLComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    12.2 => { # CS22-g
        Name => 'CommanderInternalManualOutput',
        Mask => 0xe0,
        ValueConv => '2 ** (-$val)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)+0.5) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    13.1 => { # CS22-i
        Name => 'CommanderGroupA_TTL-AAComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    13.2 => { # CS22-j
        Name => 'CommanderGroupAManualOutput',
        Mask => 0xe0,
        ValueConv => '2 ** (-$val)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)+0.5) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    14.1 => { # CS22-l
        Name => 'CommanderGroupB_TTL-AAComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    14.2 => { # CS22-m
        Name => 'CommanderGroupBManualOutput',
        Mask => 0xe0,
        ValueConv => '2 ** (-$val)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)+0.5) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    15.1 => { # CS3
        Name => 'CenterAFArea',
        Mask => 0x80,
        PrintConv => {
            0 => 'Normal Zone',
            1 => 'Wide Zone',
        },
    },
    15.2 => { # CS20
        Name => 'FocusAreaSelection',
        Mask => 0x04,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    15.3 => { # CS21
        Name => 'AFAreaIllumination',
        Mask => 0x03,
        PrintConv => {
            0 => 'Auto',
            1 => 'Off',
            2 => 'On',
        },
    },
    16.1 => { # CS2
        Name => 'AFAreaModeSetting',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Single Area',
            1 => 'Dynamic Area',
            2 => 'Auto-area',
        },
    },
);

# custom settings for the D40 (encrypted) - ref JD
%Image::ExifTool::NikonCustom::SettingsD40 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the Nikon D40.',
    0.1 => { # CS1
        Name => 'Beep',
        Mask => 0x80,
        PrintConv => \%onOff,
    },
    0.2 => { # CS9
        Name => 'AFAssist',
        Mask => 0x40,
        PrintConv => \%onOff,
    },
    0.3 => { # CS6
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    0.4 => { # CS7
        Name => 'ImageReview',
        Mask => 0x10,
        PrintConv => \%onOff,
    },
    1.1 => { # CS10-a
        Name => 'AutoISO',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    1.2 => { # CS10-b
        Name => 'AutoISOMax',
        Mask => 0x30,
        PrintConv => {
            1 => 400,
            2 => 800,
            3 => 1600,
        },
    },
    1.3 => { # CS10-c
        Name => 'AutoISOMinShutterSpeed',
        Mask => 0x07,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/125 s',
            1 => '1/60 s',
            2 => '1/30 s',
            3 => '1/15 s',
            4 => '1/8 s',
            5 => '1/4 s',
            6 => '1/2 s',
            7 => '1 s',
        },
    },
    2.1 => { # CS15-b
        Name => 'ImageReviewTime',
        Mask => 0x07,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s',
            3 => '1 min',
            4 => '10 min',
        },
    },
    3.1 => { # CS15-a
        Name => 'MonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s',
            3 => '1 min',
            4 => '10 min',
        },
    },
    3.2 => { # CS15-c
        Name => 'MeteringTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s',
            3 => '1 min',
            4 => '30 min',
        },
    },
    3.3 => { # CS16
        Name => 'SelfTimerTime',
        Mask => 0x03,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    3.4 => { # CS17
        Name => 'RemoteOnDuration',
        Mask => 0xc0,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
        },
    },
    4.1 => { # CS12
        Name => 'AELockButton',
        Mask => 0x0e,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AF-ON',
        },
    },
    4.2 => { # CS13
        Name => 'AELock',
        Mask => 0x01,
        PrintConv => \%offOn,
    },
    5.1 => { # CS4
        Name => 'ShootingModeSetting',
        Mask => 0x70,
        PrintConv => {
            0 => 'Single Frame',
            1 => 'Continuous',
            2 => 'Self-timer',
            3 => 'Delayed Remote',
            4 => 'Quick-response Remote',
        },
    },
    5.2 => { # CS11
        Name => 'TimerFunctionButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Shooting Mode',
            1 => 'Image Quality/Size',
            2 => 'ISO',
            3 => 'White Balance',
            4 => 'Self-timer',
        },
    },
    6.1 => { # CS5
        Name => 'Metering',
        Mask => 0x03,
        PrintConv => {
            0 => 'Matrix',
            1 => 'Center-weighted',
            2 => 'Spot',
        },
    },
    8.1 => { # CS14-a
        Name => 'InternalFlash',
        Mask => 0x10,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
        },
    },
    8.2 => { # CS14-b
        Name => 'ManualFlashOutput',
        Mask => 0x07,
        ValueConv => '2 ** (-$val)',
        ValueConvInv => '$val > 0 ? -log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9 => { # CS8
        Name => 'FlashLevel',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => '$val * 6',
        PrintConv => 'sprintf("%+.1f",$val)',
        PrintConvInv => '$val',
    },
    10.1 => { # CS2
        Name => 'FocusModeSetting',
        # (may differ from FocusMode if lens switch is set to Manual)
        Mask => 0xc0,
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    11.1 => { # CS3
        Name => 'AFAreaModeSetting',
        # (may differ from AFAreaMode for Manual focus)
        Mask => 0x30,
        PrintConv => {
            0 => 'Single Area',
            1 => 'Dynamic Area',
            2 => 'Closest Subject',
        },
    }
);

# D90 custom settings (ref PH)
%Image::ExifTool::NikonCustom::SettingsD90 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D90.',
    # Missing:
    # CSe2 RepeatingFlashRate (needs verification)
    #      CommanderInternalFlash, CommanderGroupAMode, CommanderGroupBMode,
    #      CommanderChannel, CommanderInternalManualOutput,
    #      CommanderGroupAManualOutput, CommanderGroupBManualOutput
    #      CommanderGroupA_TTL-AAComp, CommanderGroupB_TTL-AAComp,
    # CSe4 AutoBracketSet (some values need verification)
    # CSf2 OKButton ("Not Used" value needs verification)
    # CSf5-b CommandDialsChangeMainSub
    # CSf5-c CommandDialsMenuAndPlayback
    0.1 => { # CSf1
        Name => 'LightSwitch',
        Mask => 0x08,
        PrintConv => {
            0 => 'LCD Backlight',
            1 => 'LCD Backlight and Shooting Information',
        },
    },
    2.1 => { # CSa1
        Name => 'AFAreaModeSetting',
        Mask => 0x60,
        PrintConv => {
            0 => 'Single Area',
            1 => 'Dynamic Area',
            2 => 'Auto-area',
            3 => '3D-tracking (11 points)',
        },
    },
    2.2 => { # CSa2
        Name => 'CenterFocusPoint',
        Mask => 0x10,
        PrintConv => {
            0 => 'Normal Zone',
            1 => 'Wide Zone',
        },
    },
    2.3 => { # CSa3
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    2.4 => { # CSa4
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    2.5 => { # CSa5
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    3.1 => { # CSa6
        Name => 'AELockForMB-D80',
        Mask => 0x1c,
        PrintConv => {
            0 => 'AE Lock Only',
            1 => 'AF Lock Only',
            2 => 'AE Lock (hold)',
            3 => 'AF-On',
            4 => 'FV Lock',
            5 => 'Focus Point Selection',
            7 => 'AE/AF Lock',
        },
    },
    3.2 => { # CSd12
        Name => 'MB-D80BatteryType',
        Mask => 0x03,
        PrintConv => {
            0 => 'LR6 (AA alkaline)',
            1 => 'HR6 (AA Ni-MH)',
            2 => 'FR6 (AA lithium)',
            3 => 'ZR6 (AA Ni-Mn)',
        },
    },
    4.1 => { # CSd1
        Name => 'Beep',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    4.2 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    4.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Show ISO/Easy ISO',
            1 => 'Show ISO Sensitivity',
            3 => 'Show Frame Count',
        },
    },
    4.4 => { # CSd4
        Name => 'ViewfinderWarning',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    4.5 => { # CSf6
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    5.1 => { # CSd5
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    5.2 => { # CSd7
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    5.3 => { # CSd8
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Auto',
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
    },
    5.4 => { # CSd9
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    6.1 => { # CSb2
        Name => 'EasyExposureComp',
        Mask => 0x01,
        PrintConv => \%offOn,
    },
    6.2 => { # CSf7
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    7.1 => { # CSb1
        Name => 'ExposureControlStepSize',
        Mask => 0x40,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    8.1 => { # CSb3
        Name => 'CenterWeightedAreaSize',
        Mask => 0x60,
        PrintConv => {
            0 => '6 mm',
            1 => '8 mm',
            2 => '10 mm',
        },
    },
    8.2 => { # CSb4-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb4-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb4-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    11.1 => { # CSd6
        Name => 'CLModeShootingSpeed',
        Mask => 0x07,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    11.2 => { # CSd10
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    13.1 => { # CSe4
        Name => 'AutoBracketSet',
        Mask => 0xe0, #(NC)
        PrintConv => {
            0 => 'AE & Flash', # default
            1 => 'AE Only',
            2 => 'Flash Only', #(NC)
            3 => 'WB Bracketing', #(NC)
            4 => 'Active D-Lighting', #(NC)
        },
    },
    13.2 => { # CSe6
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    14.1 => { # CSf3
        Name => 'FuncButton',
        Mask => 0x78,
        PrintConv => {
            1 => 'Framing Grid',
            2 => 'AF-area Mode',
            3 => 'Center Focus Point',
            4 => 'FV Lock', # default
            5 => 'Flash Off',
            6 => 'Matrix Metering',
            7 => 'Center-weighted Metering',
            8 => 'Spot Metering',
            9 => 'My Menu Top',
            10 => '+ NEF (RAW)',
        },
    },
    16.1 => { # CSf2
        Name => 'OKButton',
        Mask => 0x18,
        PrintConv => {
            1 => 'Select Center Focus Point',
            2 => 'Highlight Active Focus Point',
            3 => 'Not Used', #(NC)
            0 => 'Not Used', #(NC)
        },
    },
    17.1 => { # CSf4
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only', #(NC)
            3 => 'AE Lock (hold)', #(NC)
            4 => 'AF-ON', #(NC)
            5 => 'FV Lock', #(NC)
        },
    },
    18.1 => { # CSf5-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => \%noYes,
    },
    18.2 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    19.1 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0xf0,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '4 s',
            1 => '6 s', # default
            2 => '8 s',
            3 => '16 s',
            4 => '30 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
            8 => '30 min',
        },
    },
    19.2 => { # CSc5
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s', # default
            3 => '20 s',
        },
    },
    20.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x1e,
    },
    21.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    21.2 => { # CSc4-d
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s', # default
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s', # default
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s', # default
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    24.1 => { # CSe2-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    24.2 => { # CSe2-b
        Name => 'ManualFlashOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    25.1 => { # CSe2-ca
        Name => 'RepeatingFlashOutput',
        Mask => 0x70,
        ValueConv => '2 ** (-$val-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    25.2 => { # CSe2-cb
        Name => 'RepeatingFlashCount',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    26.1 => { # CSe2-cc (NC)
        Name => 'RepeatingFlashRate',
        Mask => 0xf0,
        ValueConv => '$val < 10 ? $val + 1 : 10 * ($val - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5)',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    31.1 => { # CSd11
        Name => 'FlashWarning',
        Mask => 0x80,
        PrintConv => \%onOff,
    },
    31.2 => { # CSe2-ea
        Name => 'CommanderInternalTTLComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    31.3 => { # CSe3
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    31.4 => { # CSe5
        Name => 'AutoFP',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    32.1 => { # CSe2-eb
        Name => 'CommanderGroupA_TTLComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    33.1 => { # CSe2-ec
        Name => 'CommanderGroupB_TTLComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    34.1 => { # CSa7
        Name => 'LiveViewAF',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Face Priority', #(NC)
            1 => 'Wide Area',
            2 => 'Normal Area',
        },
    },
);

# D300 (ref JD) and D3 (ref 1/PH) custom settings
%Image::ExifTool::NikonCustom::SettingsD3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D3, D3S, D3X, D300 and D300S.',
    # these settings have been decoded using the D3 and D300, and
    # extrapolated to the other models, but these haven't yet been
    # verified, and the following custom settings are missing:
    #   CSf1-d (D3X,D3S) MultiSelectorLiveView
    #   CSf1 (D300S) LightSwitch
    0.1 => { #1
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    0.2 => { #1
        Name => 'CustomSettingsAllDefault',
        Notes => '"No" if any custom setting for this bank was changed from the default',
        Mask => 0x80,
        PrintConv => { 0 => 'Yes', 1 => 'No' },
    },
    1.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa8
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0 => '51 Points',
            1 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'DynamicAFArea',
        Mask => 0x0c,
        PrintConv => {
            0 => '9 Points',
            1 => '21 Points',
            2 => '51 Points',
            3 => '51 Points (3D-tracking)',
        },
    },
    1.5 => { # CSa4
        Name => 'FocusTrackingLockOn',
        Condition => '$$self{Model} !~ /D3S\b/',
        Notes => 'not D3S',
        Mask => 0x03,
        PrintConv => {
            0 => 'Long',
            1 => 'Normal',
            2 => 'Short',
            3 => 'Off',
        },
    },
    2.1 => { # CSa5
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    2.2 => { # CSa7
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    2.3 => [ # CSa6
        {
            Name => 'AFPointIllumination',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x60,
            PrintConv => {
                0 => 'On in Continuous Shooting and Manual Focusing',
                1 => 'On During Manual Focusing',
                2 => 'On in Continuous Shooting Modes',
                3 => 'Off',
            },
        },
        {
            Name => 'AFPointIllumination',
            Notes => 'D300',
            Mask => 0x06,
            PrintConv => {
                0 => 'Auto',
                1 => 'Off',
                2 => 'On',
            },
        },
    ],
    2.4 => { # CSa6-b (D3, added by firmware update)
        Name => 'AFPointBrightness',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x06,
        PrintConv => {
            0 => 'Low',
            1 => 'Normal',
            2 => 'High',
            3 => 'Extra High',
        },
    },
    2.5 => { # CSa9 (D300)
        Name => 'AFAssist',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    3.1 => { # CSa9 (D3)
        Name => 'AFOnButton',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x07,
        PrintConv => {
            0 => 'AF On',
            1 => 'AE/AF Lock',
            2 => 'AE Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock (hold)',
            5 => 'AF Lock Only',
        },
    },
    3.2 => { # CSa10 (D3)
        Name => 'VerticalAFOnButton',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x70,
        PrintConv => {
            0 => 'AF On',
            1 => 'AE/AF Lock',
            2 => 'AE Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock (hold)',
            5 => 'AF Lock Only',
            7 => 'Same as AF On',
        },
    },
    3.3 => { # CSa10 (D300)
        Name => 'AF-OnForMB-D10',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x70,
        PrintConv => {
            0 => 'AF-On',
            1 => 'AE/AF Lock',
            2 => 'AE Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock (hold)',
            5 => 'AF Lock Only',
            6 => 'Same as FUNC Button',
        },
    },
    4.1 => { # CSa4 (D3S)
        Name => 'FocusTrackingLockOn',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x07,
        PrintConv => {
            0 => '5 (Long)',
            1 => '4',
            2 => '3 (Normal)',
            3 => '2',
            4 => '1 (Short)',
            5 => 'Off',
        },
    },
    4.2 => { # CSf7 (D3S)
        Name => 'AssignBktButton',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x08,
        PrintConv => {
            0 => 'Auto Bracketing',
            1 => 'Multiple Exposure',
        },
    },
    4.3 => { # CSf1-c (D3S) (ref 1)
        Name => 'MultiSelectorLiveView',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Reset',
            1 => 'Zoom On/Off',
            2 => 'Start Movie Recording',
            3 => 'Not Used',
        },
    },
    4.4 => { # CSf1-c2 (D3S) (ref 1)
        Name => 'InitialZoomLiveView',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x30,
        PrintConv => {
            0 => 'Low Magnification',
            1 => 'Medium Magnification',
            2 => 'High Magnification',
        },
    },
    6.1 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    6.2 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    6.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    6.4 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    7.1 => [ # CSb5
        {
            Name => 'CenterWeightedAreaSize',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xe0,
            PrintConv => {
                0 => '8 mm',
                1 => '12 mm',
                2 => '15 mm',
                3 => '20 mm',
                4 => 'Average',
            },
        },
        {
            Name => 'CenterWeightedAreaSize',
            Notes => 'D300',
            Mask => 0xe0,
            PrintConv => {
                0 => '6 mm',
                1 => '8 mm',
                2 => '10 mm',
                3 => '13 mm',
                4 => 'Average',
            },
        },
    ],
    7.2 => { # CSb6-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    8.1 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    8.2 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSf1-a, CSf2-a (D300S)
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Select Center Focus Point',
            1 => 'Highlight Active Focus Point',
            2 => 'Not Used',
        },
    },
    9.2 => { # CSf1-b, CSf2-b (D300S)
        Name => 'MultiSelectorPlaybackMode',
        Condition => '$$self{Model} !~ /D3S\b/',
        Notes => 'all models except D3S', # (not confirmed for D3X)
        Mask => 0x30,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
            3 => 'Choose Folder',
        },
    },
    9.3 => [ # CSf1-b2, CSf2-b2 (D300S)
        {
            Name => 'InitialZoomSetting',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x0c,
            PrintConv => { #1
                0 => 'High Magnification',
                1 => 'Medium Magnification',
                2 => 'Low Magnification',
            },
        },
        {
            Name => 'InitialZoomSetting',
            Notes => 'D300',
            Mask => 0x0c,
            PrintConv => { #JD
                0 => 'Low Magnification',
                1 => 'Medium Magnification',
                2 => 'High Magnification',
            },
        },
    ],
    9.4 => { # CSf2 (D300,D3), CSf3 (D300S)
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    10.1 => { # CSd9 (D300,D3S), CSd10 (D300S), CSd8 (D3)
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    10.2 => { # CSd4 (D300), CDs5 (D300S), CSd2-a (D3)
        Name => 'CLModeShootingSpeed',
        Mask => 0x07,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    10.3 => { # (D3 CSd2-b)
        Name => 'CHModeShootingSpeed',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x30,
        PrintConv => {
            0 => '9 fps',
            1 => '10 fps',
            2 => '11 fps',
        },
    },
    11 => { # CSd5 (D300), CSd6 (D300S), CSd3 (D3)
        Name => 'MaxContinuousRelease',
        # values: 1-100 (D300), 1-130 (D3)
    },
    12.1 => { # CSf10, CSf11 (D3S,D300S)
        Name => 'ReverseIndicators',
        Mask => 0x20,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    12.2 => [ # CSd6 (D300), CSd7 (D300S), CSd4 (D3)
        {
            Name => 'FileNumberSequence',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x02,
            PrintConv => \%onOff,
        },
        {
            Name => 'FileNumberSequence',
            Notes => 'D300',
            Mask => 0x08,
            PrintConv => \%onOff,
        },
    ],
    12.3 => { # CSd5-a (D3)
        Name => 'RearDisplay',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x80,
        PrintConv => {
            0 => 'ISO',
            1 => 'Exposures Remaining',
        },
    },
    12.4 => { # CSd5-b (D3)
        Name => 'ViewfinderDisplay',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x40,
        PrintConv => {
            0 => 'Frame Count',
            1 => 'Exposures Remaining',
        },
    },
    12.5 => { # CSd11 (D300), CSd12 (D300S)
        Name => 'BatteryOrder',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x04,
        PrintConv => {
            0 => 'MB-D10 First',
            1 => 'Camera Battery First',
        },
    },
    12.6 => { # CSd10 (D300), CSd11 (D300S)
        Name => 'MB-D10Batteries',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x03,
        PrintConv => {
            0 => 'LR6 (AA alkaline)',
            1 => 'HR6 (AA Ni-MH)',
            2 => 'FR6 (AA lithium)',
            3 => 'ZR6 (AA Ni-Mn)',
        },
    },
    12.7 => { # CSd7 (D3S), CSd4, (D300S)
        Name => 'ScreenTips',
        Condition => '$$self{Model} =~ /(D3S|D300S)\b/',
        Mask => 0x10,
        PrintConv => \%onOff,
    },
    13.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0 => 'High',
            1 => 'Low',
            2 => 'Off',
        },
    },
    13.2 => { # CSd7 (D300), CSd8 (D300S), CSd6 (D3)
        Name => 'ShootingInfoDisplay',
        Mask => 0x30,
        PrintConv => {
            0 => 'Auto', #JD (D300)
            1 => 'Auto', #1 (D3)
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
    },
    13.3 => { # CSd2 (D300)
        Name => 'GridDisplay',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    13.4 => { # CSd3 (D300)
        Name => 'ViewfinderWarning',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    13.5 => { # CSf1-b (D3S) (ref 1)
        Name => 'MultiSelectorPlaybackMode',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x03,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
        },
    },
    14.1 => [ # CSf5-a (ref 1), CSf6-a (D300S)
        {
            Name => 'PreviewButton',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xf8,
            PrintConv => {
                0 => 'None',
                1 => 'Preview',
                2 => 'FV Lock',
                3 => 'AE/AF Lock',
                4 => 'AE Lock Only',
                5 => 'AE Lock (reset on release)',
                6 => 'AE Lock (hold)',
                7 => 'AF Lock Only',
                8 => 'Flash Off',
                9 => 'Bracketing Burst',
                10 => 'Matrix Metering',
                11 => 'Center-weighted Metering',
                12 => 'Spot Metering',
                13 => 'Virtual Horizon',
                # 14 not used
                15 => 'Playback',
                16 => 'My Menu Top',
            },
        },
        { #PH
            Name => 'FuncButton',
            Notes => 'D300',
            Mask => 0xf8,
            PrintConv => {
                0 => 'None',
                1 => 'Preview',
                2 => 'FV Lock',
                3 => 'AE/AF Lock',
                4 => 'AE Lock Only',
                5 => 'AE Lock (reset on release)',
                6 => 'AE Lock (hold)',
                7 => 'AF Lock Only',
                # 8 not used
                9 => 'Flash Off',
                10 => 'Bracketing Burst',
                11 => 'Matrix Metering',
                12 => 'Center-weighted Metering',
                13 => 'Spot Metering',
                14 => 'Playback', #PH (guess)
                15 => 'My Menu Top', #PH (guess)
                16 => '+ NEF (RAW)', #PH (guess)
            },
        },
    ],
    14.2 => [ # CSf5-b (PH,NC), CSf6-b (D300S)
        {
            Name => 'PreviewButtonPlusDials',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x07,
            PrintConv => {
                0 => 'None',
                1 => 'Choose Image Area (FX/DX/5:4)',
                2 => 'One Step Speed/Aperture',
                3 => 'Choose Non-CPU Lens Number',
                # n/a  4 => 'Focus Point Selection',
                5 => 'Choose Image Area (FX/DX)',
                6 => 'Shooting Bank Menu',
                7 => 'Dynamic AF Area', #PH (D3S,D3X,NC)
            },
        },
        { #PH
            Name => 'FuncButtonPlusDials',
            Notes => 'D300',
            Mask => 0x07,
            PrintConv => {
                0 => 'None',
                2 => 'One Step Speed/Aperture',
                3 => 'Choose Non-CPU Lens Number',
                5 => 'Auto Bracketing',
                6 => 'Dynamic AF Area',
            },
        },
    ],
    15.1 => [ # CSf4-a (ref 1), CSf5-a (D300S)
        {
            Name => 'FuncButton',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xf8,
            PrintConv => {
                0 => 'None',
                1 => 'Preview',
                2 => 'FV Lock',
                3 => 'AE/AF Lock',
                4 => 'AE Lock Only',
                5 => 'AE Lock (reset on release)',
                6 => 'AE Lock (hold)',
                7 => 'AF Lock Only',
                8 => 'Flash Off',
                9 => 'Bracketing Burst',
                10 => 'Matrix Metering',
                11 => 'Center-weighted Metering',
                12 => 'Spot Metering',
                13 => 'Virtual Horizon',
                # 14 not used
                15 => 'Playback',
                16 => 'My Menu Top',
            },
        },
        { #PH
            Name => 'PreviewButton',
            Notes => 'D300',
            Mask => 0xf8,
            PrintConv => {
                0 => 'None',
                1 => 'Preview',
                2 => 'FV Lock',
                3 => 'AE/AF Lock',
                4 => 'AE Lock Only',
                5 => 'AE Lock (reset on release)',
                6 => 'AE Lock (hold)',
                7 => 'AF Lock Only',
                # 8 not used
                9 => 'Flash Off',
                10 => 'Bracketing Burst',
                11 => 'Matrix Metering',
                12 => 'Center-weighted Metering',
                13 => 'Spot Metering',
                14 => 'Playback', #PH (guess)
                15 => 'My Menu Top', #PH (guess)
                16 => '+ NEF (RAW)', #PH (guess)
            },
        },
    ],
    15.2 => [ # CSf4-b (ref 1), CSf5-b (D300S)
        {
            Name => 'FuncButtonPlusDials',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x07,
            PrintConv => {
                0 => 'None',
                1 => 'Choose Image Area (FX/DX/5:4)',
                2 => 'One Step Speed/Aperture',
                3 => 'Choose Non-CPU Lens Number',
                4 => 'Focus Point Selection', #(NC)
                5 => 'Choose Image Area (FX/DX)',
                6 => 'Shooting Bank Menu',
                7 => 'Dynamic AF Area', #PH (D3S,D3X,NC)
            },
        },
        { #PH
            Name => 'PreviewButtonPlusDials',
            Notes => 'D300',
            Mask => 0x07,
            PrintConv => {
                0 => 'None',
                2 => 'One Step Speed/Aperture',
                3 => 'Choose Non-CPU Lens Number',
                5 => 'Auto Bracketing',
                6 => 'Dynamic AF Area',
            },
        },
    ],
    16.1 => [ # CSf6-a (ref 1), CSf7-a (D300S)
        {
            Name => 'AELockButton',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xf8,
            PrintConv => {
                0 => 'None',
                1 => 'Preview',
                2 => 'FV Lock',
                3 => 'AE/AF Lock',
                4 => 'AE Lock Only',
                5 => 'AE Lock (reset on release)',
                6 => 'AE Lock (hold)',
                7 => 'AF Lock Only',
                8 => 'Flash Off',
                9 => 'Bracketing Burst',
                10 => 'Matrix Metering',
                11 => 'Center-weighted Metering',
                12 => 'Spot Metering',
                13 => 'Virtual Horizon',
                14 => 'AF On', # (AE-L/AF-L button only)
                15 => 'Playback',
                16 => 'My Menu Top',
            },
        },
        { #PH
            Name => 'AELockButton',
            Notes => 'D300',
            Mask => 0xf8,
            PrintConv => {
                0 => 'None',
                1 => 'Preview',
                2 => 'FV Lock',
                3 => 'AE/AF Lock',
                4 => 'AE Lock Only',
                5 => 'AE Lock (reset on release)',
                6 => 'AE Lock (hold)',
                7 => 'AF Lock Only',
                8 => 'AF On', # (AE-L/AF-L button only)
                9 => 'Flash Off',
                10 => 'Bracketing Burst',
                11 => 'Matrix Metering',
                12 => 'Center-weighted Metering',
                13 => 'Spot Metering',
                14 => 'Playback', #PH (guess)
                15 => 'My Menu Top', #PH (guess)
                16 => '+ NEF (RAW)', #PH (guess)
            },
        },
    ],
    16.2 => [ # CSf6-b (ref 1), CSf7-b (D300S)
        {
            Name => 'AELockButtonPlusDials',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x07,
            PrintConv => {
                0 => 'None',
                1 => 'Choose Image Area (FX/DX/5:4)',
                2 => 'One Step Speed/Aperture',
                3 => 'Choose Non-CPU Lens Number',
                # n/c 4 => 'Focus Point Selection', #(NC)
                5 => 'Choose Image Area (FX/DX)',
                6 => 'Shooting Bank Menu',
                7 => 'Dynamic AF Area', #PH (D3S,D3X,NC)
            },
        },
        { #PH
            Name => 'AELockButtonPlusDials',
            Notes => 'D300',
            Mask => 0x07,
            PrintConv => {
                0 => 'None',
                # n/a  2 => 'One Step Speed/Aperture',
                3 => 'Choose Non-CPU Lens Number',
                5 => 'Auto Bracketing', #(NC)
                6 => 'Dynamic AF Area',
            },
        },
    ],
    17.1 => { # CSf7-a, CSf8-a (D3S,D300S)
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => \%noYes,
    },
    17.2 => { # CSf7-b, CSf8-b (D3S,D300S)
        Name => 'CommandDialsChangeMainSub',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    17.3 => { # CSf7-c, CSf8-c (D3S,D300S)
        Name => 'CommandDialsApertureSetting',
        Mask => 0x20,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    17.4 => { # CSf7-d, CSf8-d (D3S,D300S)
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x10,
        PrintConv => \%offOn,
    },
    17.5 => { # CSd8 (D300,D3S), CSd9 (D300S), CSd7 (D3)
        Name => 'LCDIllumination',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    17.6 => { # CSf3, CSf4 (D300S)
        Name => 'PhotoInfoPlayback',
        Mask => 0x04,
        PrintConv => {
            0 => 'Info Up-down, Playback Left-right',
            1 => 'Info Left-right, Playback Up-down',
        },
    },
    17.7 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    17.8 => { # CSf8, CSf9 (D3S,D300S)
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    18.1 => { # CSc3
        Name => 'SelfTimerTime',
        Mask => 0x18,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    18.2 => { # CSc4
        Name => 'MonitorOffTime',
        # NOTE: The D3S and D300S have separate settings for Playback,
        # Image Review, Menus, and Information Display times
        Mask => 0x07,
        PrintConv => {
            0 => '10 s',
            1 => '20 s',
            2 => '1 min',
            3 => '5 min',
            4 => '10 min',
        },
    },
    20.1 => [ # CSe1
        {
            Name => 'FlashSyncSpeed',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xe0,
            PrintConv => {
                0 => '1/250 s (auto FP)',
                1 => '1/250 s',
                2 => '1/200 s',
                3 => '1/160 s',
                4 => '1/125 s',
                5 => '1/100 s',
                6 => '1/80 s',
                7 => '1/60 s',
            },
        },
        {
            Name => 'FlashSyncSpeed',
            Notes => 'D300',
            Mask => 0xf0,
            PrintConv => {
                0 => '1/320 s (auto FP)',
                1 => '1/250 s (auto FP)',
                2 => '1/250 s',
                3 => '1/200 s',
                4 => '1/160 s',
                5 => '1/125 s',
                6 => '1/100 s',
                7 => '1/80 s',
                8 => '1/60 s',
            },
        },
    ],
    20.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    21.1 => [{ # CSe5 (D300), CSe4 (D3)
        Name => 'AutoBracketSet',
        Condition => '$$self{Model} !~ /(D3S|D300S)\b/',
        Notes => 'D3 and D300',
        Mask => 0xc0,
        PrintConv => {
            0 => 'AE & Flash',
            1 => 'AE Only',
            2 => 'Flash Only',
            3 => 'WB Bracketing',
        },
    },{ # CSe4 (D3S) (NC for D300S)
        Name => 'AutoBracketSet',
        Notes => 'D3S and D300S',
        Mask => 0xe0,
        PrintConv => {
            0 => 'AE & Flash',
            1 => 'AE Only',
            2 => 'Flash Only',
            3 => 'WB Bracketing',
            # D3S/D300S have an "ADL Bracketing" setting - PH
            4 => 'ADL Bracketing',
        },
    }],
    21.2 => [{ # CSe6 (D300), CSe5 (D3)
        Name => 'AutoBracketModeM',
        Condition => '$$self{Model} !~ /(D3S|D300S)\b/',
        Notes => 'D3 and D300',
        Mask => 0x30,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },{ # CSe5 (D3S)
        Name => 'AutoBracketModeM',
        Notes => 'D3S and D300S',
        Mask => 0x18,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    }],
    21.3 => [{ # CSe7 (D300), CSe6 (D3)
        Name => 'AutoBracketOrder',
        Condition => '$$self{Model} !~ /(D3S|D300S)\b/',
        Notes => 'D3 and D300',
        Mask => 0x08,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },{ # CSe6 (D3S)
        Name => 'AutoBracketOrder',
        Notes => 'D3S and D300S',
        Mask => 0x04,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    }],
    21.4 => { # CSe4 (D300), CSe3 (D3)
        Name => 'ModelingFlash',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    22.1 => { # CSf9, CSf10 (D3S,D300S)
        Name => 'NoMemoryCard',
        Mask => 0x80,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    22.2 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            2 => '8 s',
            3 => '16 s',
            4 => '30 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
            8 => '30 min',
            9 => 'No Limit',
        },
    },
    23.1 => { # CSe3
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    25.1 => { #1 CSc4-d (D3S)
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    25.2 => { #1 CSc4-a (D3S)
        Name => 'PlaybackMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    26.1 => { #1 CSc4-b (D3S)
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    26.2 => { #1 CSc4-c (D3S)
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
);

# D700 custom settings (ref 2)
%Image::ExifTool::NikonCustom::SettingsD700 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 16.1 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D700.',
    0.1 => { #1
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    0.2 => { #1
        Name => 'CustomSettingsAllDefault',
        Notes => '"No" if any custom setting for this bank was changed from the default',
        Mask => 0x80,
        PrintConv => { 0 => 'Yes', 1 => 'No' },
    },
    1.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa8
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0 => '51 Points',
            1 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'DynamicAFArea',
        Mask => 0x0c,
        PrintConv => {
            0 => '9 Points',
            1 => '21 Points',
            2 => '51 Points',
            3 => '51 Points (3D-tracking)',
        },
    },
    2.1 => { # CSa5
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    2.2 => { # CSa7
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    2.3 => { # CSa6
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'Off',
            2 => 'On',
        },
    },
    2.4 => { # CSa9
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    3.1 => { # CSa4
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0 => '3 Normal',
            1 => '4',
            2 => '5 Long',
            3 => '2',
            4 => '1 Short',
            5 => 'Off',
        },
    },
    3.2 => { # CSa10
        Name => 'AF-OnForMB-D10',
        Mask => 0x70,
        PrintConv => {
            0 => 'AF-On',
            1 => 'AE/AF Lock',
            2 => 'AE Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock (hold)',
            5 => 'AF Lock Only',
            6 => 'Same as FUNC Button',
        },
    },
    4.1 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    4.2 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    4.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    4.4 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    5.1 => { # CSb5
        Name => 'CenterWeightedAreaSize',
        Mask => 0x70,
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            2 => '15 mm',
            3 => '20 mm',
            4 => 'Average',
        },
    },
    6.1 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    6.2 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    7.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    7.2 => { # CSc3
        Name => 'SelfTimerTime',
        Mask => 0x30,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    7.3 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            2 => '8 s',
            3 => '16 s',
            4 => '30 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
            8 => '30 min',
            9 => 'No Limit',
        },
    },
    8.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0x38,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    8.2 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0x07,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    9.1 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x38,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    9.2 => { # CSc4-d
        Name => 'ImageReviewTime',
        Mask => 0x07,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    10.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0 => 'High',
            1 => 'Low',
            2 => 'Off',
        },
    },
    10.2 => { # CSd7
        Name => 'ShootingInfoDisplay',
        Mask => 0x30,
        PrintConv => {
            0 => 'Auto', #JD (D300)
            1 => 'Auto', #1 (D3)
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
    },
    10.3 => { # CSd8
        Name => 'LCDIllumination',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    10.4 => { # CSd9
        Name => 'ExposureDelayMode',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    10.5 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    11.1 => { # CSd6
        Name => 'FileNumberSequence',
        Mask => 0x40,
        PrintConv => \%onOff,
    },
    11.2 => { # CSd4
        Name => 'CLModeShootingSpeed',
        Mask => 0x07,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    12 => { # CSd5
        Name => 'MaxContinuousRelease',
        # values: 1-100
    },
    13.1 => { # CSd3
        Name => 'ScreenTips',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    13.2 => { # CSd11
        Name => 'BatteryOrder',
        Mask => 0x04,
        PrintConv => {
            0 => 'MB-D10 First',
            1 => 'Camera Battery First',
        },
    },
    13.3 => { # CSd10
        Name => 'MB-D10BatteryType',
        Mask => 0x03,
        PrintConv => {
            0 => 'LR6 (AA alkaline)',
            1 => 'HR6 (AA Ni-MH)',
            2 => 'FR6 (AA lithium)',
            3 => 'ZR6 (AA Ni-Mn)',
        },
    },
    15.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0 => '1/320 s (auto FP)',
            1 => '1/250 s (auto FP)',
            2 => '1/250 s',
            3 => '1/200 s',
            4 => '1/160 s',
            5 => '1/125 s',
            6 => '1/100 s',
            7 => '1/80 s',
            8 => '1/60 s',
       },
    },
    15.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    16.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        # Note If set the Manual, Repeating Flash, Commander Mode
        #      does not decode the detail settings.
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    16.2 => { # CSe3-b
        Name => 'ManualFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 1',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    17.1 => { # CSe3-ca
        Name => 'RepeatingFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0x70,
        ValueConv => '2 ** (-$val-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    17.2 => { # CSe3-cb
        Name => 'RepeatingFlashCount',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    18.1 => { # CSe3-cc (NC)
        Name => 'RepeatingFlashRate',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0xf0,
        ValueConv => '$val < 10 ? $val + 1 : 10 * ($val - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5)',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    18.2 => { # CSe3-dd
        Name => 'CommanderInternalTTLChannel',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x03,
        PrintConv => {
            0 => '1 ch',
            1 => '2 ch',
            2 => '3 ch',
            3 => '4 ch',
        },
    },
    20.1 => { # CSe3-da
        Name => 'CommanderInternalTTLCompBuiltin',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    21.1 => { # CSe3-db
        Name => 'CommanderInternalTTLCompGroupA',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    22.1 => { # CSe3-dc
        Name => 'CommanderInternalTTLCompGroupB',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    26.1 => { # CSe5
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0 => 'AE & Flash',
            1 => 'AE Only',
            2 => 'Flash Only',
            3 => 'WB Bracketing',
        },
    },
    26.2 => { # CSe6
        Name => 'AutoBracketModeM',
        Mask => 0x30,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    26.3 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x08,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    26.4 => { # CSe4
        Name => 'ModelingFlash',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    27.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Select Center Focus Point',
            1 => 'Highlight Active Focus Point',
            2 => 'Not Used',
        },
    },
    27.2 => { # CSf2-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x30,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
            3 => 'Choose Folder',
        },
    },
    27.3 => { # CSf2-b2
        Name => 'InitialZoomSetting',
        Mask => 0x0c,
        PrintConv => { #1
            0 => 'Low Magnification',
            1 => 'Medium Magnification',
            2 => 'High Magnification',
        },
    },
    27.4 => { # CSf3
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    28.1 => { # CSf5-a
        Name => 'FuncButton',
        Mask => 0xf8,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            # 8 not used
            9 => 'Flash Off',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'My Menu Top',
            15 => 'Live View',
            16 => '+ NEF (RAW)',
            17 => 'Virtual Horizon',
        },
    },
    29.1 => { # CSf6-a
        Name => 'PreviewButton',
        Mask => 0xf8,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-ON',
            9 => 'Flash Off',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'My Menu Top',
            15 => 'Live View',
            16 => '+ NEF (RAW)',
            17 => 'Virtual Horizon',
        },
    },
    30.1 => { # CSf7-a
        Name => 'AELockButton',
        Notes => 'D300',
        Mask => 0xf8,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-ON',
            9 => 'Flash Off',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'My Menu Top',
            15 => 'Live View',
            16 => '+ NEF (RAW)',
            17 => 'Virtual Horizon',
        },
    },
    31.1 => { # CSf5-b
        Name => 'FuncButtonPlusDials',
        Mask => 0x70,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'One Step Speed/Aperture',
            3 => 'Choose Non-CPU Lens Number',
            # n/a  4 => 'Focus Point Selection',
            5 => 'Auto bracketing',
            6 => 'Dynamic AF Area',
            7 => 'Shutter speed & Aperture lock',
        },
    },
    31.2 => { # CSf6-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'One Step Speed/Aperture',
            3 => 'Choose Non-CPU Lens Number',
            # n/a  4 => 'Focus Point Selection',
            5 => 'Auto bracketing',
            6 => 'Dynamic AF Area',
            7 => 'Shutter speed & Aperture lock',
        },
    },
    32.1 => { # CSf7-b
        Name => 'AELockButtonPlusDials',
        Mask => 0x70,
        Prinonv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'One Step Speed/Aperture',
            3 => 'Choose Non-CPU Lens Number',
            # n/a  4 => 'Focus Point Selection',
            5 => 'Auto bracketing',
            6 => 'Dynamic AF Area',
            7 => 'Shutter speed & Aperture lock',
        },
    },
    33.1 => { # CSf9-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => \%noYes,
    },
    33.2 => { # CSf9-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    33.3 => { # CSf9-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x20,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    33.4 => { # CSf9-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x10,
        PrintConv => \%offOn,
    },
    33.5 => { # CSf12
        Name => 'ReverseIndicators',
        Mask => 0x08,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    33.6 => { # CSf4
        Name => 'PhotoInfoPlayback',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    33.7 => { # CSf11
        Name => 'NoMemoryCard',
        Mask => 0x02,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    33.8 => { # CSf10
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
);

# D800 custom settings (ref PH)
%Image::ExifTool::NikonCustom::SettingsD800 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 23.1 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D800 and D800E.',
    12.1 => { # CSe5
        Name => 'AutoBracketingSet',
        Mask => 0xe0, #(NC)
        PrintConv => {
            0 => 'AE & Flash', # default
            1 => 'AE Only', #(NC)
            2 => 'Flash Only',
            3 => 'WB Bracketing', #(NC)
            4 => 'Active D-Lighting', #(NC)
        },
    },
    12.2 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    12.3 => { # CSe6
        Name => 'AutoBracketingMode',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    # 21 - 100 (MaxContinuousRelease?)
    22.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0 => '1/320 s (auto FP)',
            1 => '1/250 s (auto FP)',
            2 => '1/250 s',
            3 => '1/200 s',
            4 => '1/160 s',
            5 => '1/125 s',
            6 => '1/100 s',
            7 => '1/80 s',
            8 => '1/60 s',
       },
    },
    22.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    23.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    23.2 => { # CSe3-b
        Name => 'ManualFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 1',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    24.1 => { # CSe3-ca
        Name => 'RepeatingFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0x70,
        ValueConv => '2 ** (-$val-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    24.2 => { # CSe3-cb
        Name => 'RepeatingFlashCount',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    25.1 => { # CSe3-cc
        Name => 'RepeatingFlashRate',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0xf0,
        ValueConv => '$val < 10 ? $val + 1 : 10 * ($val - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5)',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    25.2 => { # CSe3
        Name => 'CommanderChannel',
        Mask => 0x03,
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    27.1 => { # CSe3
        Name => 'CommanderInternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Off',
        },
    },
    27.2 => { # CSe3
        Name => 'CommanderInternalManualOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2) * 3 + 0.5): 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    28.1 => { # CSe3
        Name => 'CommanderGroupAMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Auto Aperture',
            2 => 'Manual',
            3 => 'Off',
        },
    },
    28.2 => { # CSe3
        Name => 'CommanderGroupAManualOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2) * 3 + 0.5): 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    29.1 => { # CSe3
        Name => 'CommanderGroupBMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Auto Aperture',
            2 => 'Manual',
            3 => 'Off',
        },
    },
    29.2 => { # CSe3
        Name => 'CommanderGroupBManualOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2) * 3 + 0.5): 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    30.1 => { # CSe4
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    30.2 => { # CSe3
        Name => 'CommanderInternalTTLComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    31.1 => { # CSe3
        Name => 'CommanderGroupA_TTL-AAComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    32.1 => { # CSe3
        Name => 'CommanderGroupB_TTL-AAComp',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    # 47 - related to flash
);

# D5 custom settings (ref 1)
%Image::ExifTool::NikonCustom::SettingsD5 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D5.',
    0.1 => {
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    1.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
            3 => 'Focus + Release',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa6
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0 => '55 Points',
            1 => '15 Points',
        },
    },
    1.4 => { # CSa4
        Name => 'Three-DTrackingFaceDetection',
        Mask => 0x08,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    1.5 => { # CSa3-a
        Name => 'BlockShotAFResponse',
        Mask => 0x07,
        #values 1-5
    },
    2.1 => { # CSa11
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    2.2 => { # CSa12-d
        Name => 'AFPointBrightness',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    4.1 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0 => 'Show ISO Sensitivity',
            1 => 'Show Frame Count',
        },
    },
    4.2 => { # CSd8
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    5.1 => { # CSd9
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    5.2 => { # CSd6
        Name => 'ElectronicFront-CurtainShutter',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    6.1 => { # CSf7
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.2 => { # CSf4-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
            2 => 'Exposure Compensation',
            3 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.3 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    8.1 => { # CSb6
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            2 => '15 mm',
            3 => '20 mm',
            4 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Select Center Focus Point (Reset)',
            1 => 'Zoom On/Off',  # this is the documented (and actual) default value, but the choice does not appear on the camera menu
            2 => 'Preset Focus Point (Pre)',
            4 => 'Not Used (None)',
        },
    },
#    10.2 => { # CSf2-b             # moved from the D500 position to Nikon_ShotInfoD5_0x0ab1 with the Mask and PrintConv as specified below.  Further research required.
#        Name => 'MultiSelectorPlaybackMode',
#        Mask => 0x70,
#        PrintConv => {
#            0 => 'Zoom On/Off',
#            1 => 'Choose Folder',
#            6 => 'Thumbnail On/Off',
#            7 => 'View Histograms',
#        },
#    },
    10.3 => { # CSf5
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    11.2 => { # CSd1
        Name => 'CLModeShootingSpeed',
        Mask => 0x0f,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    12.1 => { # CSd2
        Name => 'MaxContinuousRelease',
        # values: 1-100
    },
    13.1 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    13.2 => { # CSe6
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    14.1 => { # CSf1-c
        Name => 'Func1Button',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            58 => 'AF-Area Mode + AF-On (Group Area AF - HL)',
            59 => 'AF-Area Mode + AF-On (Group Area AF - VL)',
        },
    },
    15.1 => { # CSf1-a
        Name => 'PreviewButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            58 => 'AF-Area Mode + AF-On (Group Area AF - HL)',
            59 => 'AF-Area Mode + AF-On (Group Area AF - VL)',
        },
    },
    16.1 => { # CSf1-p
        Name => 'AssignBktButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Auto Bracketing',
            1 => 'Multiple Exposure',
            2 => 'HDR (high dynamic range)',
            3 => 'None',
        },
    },
    18.1 => { # CSf4-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Autofocus Off, Exposure Off',
            1 => 'Autofocus Off, Exposure On',
            2 => 'Autofocus Off, Exposure On (Mode A)',
            4 => 'Autofocus On, Exposure Off',
            5 => 'Autofocus On, Exposure On',
            6 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf4-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf4-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    18.4 => { # CSf6
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            3 => '10 s',
            5 => '30 s',
            6 => '1 min',
            7 => '5 min',
            8 => '10 min',
            9 => '30 min',
            10 => 'No Limit',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    20.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    20.3 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    21.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '2 s',
            1 => '4 s',
            3 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    21.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
            4 => '20 min',
            5 => '30 min',
            6 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            2 => '1/250 s (auto FP)',
            3 => '1/250 s',
            5 => '1/200 s',
            6 => '1/160 s',
            7 => '1/125 s',
            8 => '1/100 s',
            9 => '1/80 s',
            10 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    37.1 => { # CSf2-c
        Name => 'MultiSelectorLiveView',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Reset',
            1 => 'Zoom',
            3 => 'Not Used',
        },
    },
    38.1 => { # CSf3-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    38.2 => { # CSf3-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    38.3 => { # CSg1-h
        Name => 'MovieShutterButton',
        Mask => 0x10,
        PrintConv => {
            0 => 'Take Photo',
            1 => 'Record Movies',
        },
    },
    38.4 => { # CSe3
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0 => 'Entire Frame',
            1 => 'Background Only',
        },
    },
    38.5 => { # CSe4
        Name => 'AutoFlashISOSensitivity',
        Mask => 0x02,
        PrintConv => {
            0 => 'Subject and Background',
            1 => 'Subject Only',
        },
    },
    41.1 => { # CSg1-c
        Name => 'MovieFunc1Button',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            2 => 'Power Aperture (close)',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            11 => 'Exposure Compensation -',
        },
    },
    41.2 => { # CSg1-a
        Name => 'MoviePreviewButton',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Power Aperture (open)',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            10 => 'Exposure Compensation +',
        },
    },
    42.1 => { # CSf1-d
        Name => 'Func1ButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
        },
    },
    43.1 => { # CSf1-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',    # new with D500
            8 => 'Exposure Delay Mode',
        },
    },
    45.1 => { # CSf1-q
        Name => 'AssignMovieRecordButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            7 => 'Photo Shooting Menu Bank',
            11 => 'Exposure Mode',
        },
    },
    46.1 => { # CSb7-d
        Name => 'FineTuneOptHighlightWeighted',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    47.1 => { # CSa12-b
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    47.2 => { # CSa12-a
        Name => 'AFPointIllumination',
        Mask => 0x40,
        PrintConv => {
            0 => 'Off',
            1 => 'On During Manual Focusing',
        },
    },
    47.3 => { # CSa7
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area Mode',
        },
    },
    48.1 => { # CSb5
        Name => 'MatrixMetering',
        Mask => 0x80,
        PrintConv => {
            0 => 'Face Detection On',
            1 => 'Face Detection Off',
        },
    },
    48.2 => { # CSf8
        Name => 'LiveViewButtonOptions',
        Mask => 0x30,
        PrintConv => {
            0 => 'Enable',
            1 => 'Enable (Standby Timer Active)',    # new with D500
            2 => 'Disable',
        },
    },
    48.3 => { # CSa10
        Name => 'AFModeRestrictions',
        Mask => 0x03,
        PrintConv => {
            0 => 'No Restrictions',
            1 => 'AF-C',
            2 => 'AF-S',
        },
    },
    49.1 => { # CSa9
        Name => 'LimitAFAreaModeSelection',
        Mask => 0x7e,
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                0 => 'Auto-area',
                1 => 'Group-area',
                2 => '3D-tracking',
                3 => 'Dynamic area (153 points)',
                4 => 'Dynamic area (72 points)',
                5 => 'Dynamic area (25 points)',
            },
        },
    },
    52.1 => { # CSf1-r
        Name => 'LensFocusFunctionButtons',
        Mask => 0x3f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            24 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
        },
    },
    66.1 => { # CSf1-o
        Name => 'VerticalMultiSelector',
        Mask => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Same as Multi-Selector with Info(U/D) & Playback(R/L)',
            0x08 => 'Same as Multi-Selector with Info(R/L) & Playback(U/D)',
            0x80 => 'Focus Point Selection',
        },
    },
    67.1 => { # CSf1-g
        Name => 'VerticalFuncButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'Reset Focus Point',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            23 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            54 => 'Highlight Active Focus Point',
        },
    },
    68.1 => { # CSf1-h
        Name => 'VerticalFuncPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
            10 => 'ISO Sensitivity',
            11 => 'Exposure Mode',
            12 => 'Exposure Compensation',
            13 => 'Metering',
        },
    },
    70.1 => { # CSf1-j
        Name => 'AF-OnButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
        },
    },
    71.1 => { # CSf1-k
        Name => 'SubSelector',
        Mask => 0x80,
        PrintConv => {
            0 => 'Focus Point Selection',
            1 => 'Same as MultiSelector',
        },
    },
    72.1 => { # CSf1-l
        Name => 'SubSelectorCenter',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'Reset Focus Point',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            23 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            54 => 'Highlight Active Focus Point',
        },
    },
    73.1 => { # CSf1-m
        Name => 'SubSelectorPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            4 => 'Choose Non-CPU Lens Number',
            7 => 'Photo Shooting Menu Bank',
        },
    },
    74.1 => { # CSg1-f
        Name => 'AssignMovieSubselector',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            5 => 'AE/AF Lock',
            6 => 'AE Lock (Only)',
            7 => 'AE Lock (Hold)',
            8 => 'AF Lock (Only)',
        },
    },
    75.1 => { # CSg1-d
        Name => 'AssignMovieFunc1ButtonPlusDials',
        Mask => 0x10,
        PrintConv => {
            0  => 'None',
            1  => 'Choose Image Area',
        },
    },
    75.2 => { # CSg1-b
        Name => 'AssignMoviePreviewButtonPlusDials',
        Mask => 0x01,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
        },
    },
    76.1 => { # CSg1-g
        Name => 'AssignMovieSubselectorPlusDials',
        Mask => 0x10,
        PrintConv => {
            0  => 'None',
            1  => 'Choose Image Area',
        },
    },
    77.1 => { # CSd4
        Name => 'SyncReleaseMode',              # new with D500
        Mask => 0x80,
        PrintConv => {
            0 => 'No Sync',
            1 => 'Sync',
        },
    },
    78.1 => { # CSa5
        Name => 'Three-DTrackingWatchArea',     # new with D500
        Mask => 0x80,
        PrintConv => {
            0 => 'Wide',
            1 => 'Normal',
        },
    },
    78.2 => { # CSa3-b
        Name => 'SubjectMotion',
        Mask => 0x60,
        PrintConv => {
            0 => 'Steady',
            1 => 'Middle',
            2 => 'Erratic',
        },
    },
    78.3 => { # CSa8
        Name => 'AFActivation',
        Mask => 0x08,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    78.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)'
        },
    },
    79.1 => { # CSf1-n
        Name => 'VerticalAFOnButton',
        Mask => 0x7f,
        PrintConv => {
            0 => 'None',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            100 => 'Same as AF-On',
        },
    },
    80.1 => { # CSf1-e
        Name => 'Func2Button',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
        },
    },
    81.1 => { # CSf1-f
        Name => 'Func2ButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
        },
    },
    82.1 => { # CSg1-e
        Name => 'AssignMovieFunc2Button',
        Mask => 0x70,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
    83.1 => { # CSf1-i
        Name => 'Func3Button',
        Mask => 0x03,
        PrintConv => {
            0 => 'None',
            1 => 'Voice Memo',
            2 => 'Rating',
            3 => 'Connect To Network',
        },
    },
);

# D500 custom settings (ref 1)
%Image::ExifTool::NikonCustom::SettingsD500 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D500.',
    0.1 => {
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    1.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
            3 => 'Focus + Release',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa6
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0 => '55 Points',
            1 => '15 Points',
        },
    },
    1.4 => { # CSa4
        Name => 'Three-DTrackingFaceDetection',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    1.5 => { # CSa3-a
        Name => 'BlockShotAFResponse',
        Mask => 0x07,
        #values 1-5
    },
    2.1 => { # CSa11
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    2.2 => { # CSa12-c
        Name => 'AFPointBrightness',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    4.1 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0 => 'Show ISO Sensitivity',
            1 => 'Show Frame Count',
        },
    },
    4.2 => { # CSd8
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    5.1 => { # CSd9
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    5.2 => { # CSd6
        Name => 'ElectronicFront-CurtainShutter',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    6.1 => { # CSf7
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.2 => { # CSf4-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
            2 => 'Exposure Compensation',
            3 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.3 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    8.1 => { # CSb6
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '6 mm',
            1 => '8 mm',
            2 => '10 mm',
            3 => '13 mm',
            4 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xe0,                       #same offset and settings as D810 but with a different decoding
        PrintConv => {
            0 => 'Select Center Focus Point (Reset)',
            2 => 'Preset Focus Point (Pre)',
            3 => 'Highlight Active Focus Point',
            4 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf2-b                      #same offset and settings as D810 but with a different decoding
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
            3 => 'Choose Folder',
        },
    },
    10.3 => { # CSf5
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    11.2 => { # CSd1
        Name => 'CLModeShootingSpeed',
        Mask => 0x0f,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    12.1 => { # CSd2
        Name => 'MaxContinuousRelease',
        # values: 1-100
    },
    13.1 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    13.2 => { # CSe6
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    14.1 => { # CSf1-c
        Name => 'Func1Button',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
        },
    },
    15.1 => { # CSf1-a
        Name => 'PreviewButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
#           21 => 'Disable Synchronized Release',   # removed with D500
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',                         # new with D500
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',         # new with D500
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',         # new with D500
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',        # new with D500
            40 => 'AF-Area Mode (Group Area AF)',                  # new with D500
            41 => 'AF-Area Mode (Auto Area AF)',                   # new with D500
            42 => 'AF-Area Mode + AF-On (Single)',                 # new with D500
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)', # new with D500
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)', # new with D500
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',# new with D500
            46 => 'AF-Area Mode + AF-On (Group Area AF)',          # new with D500
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',           # new with D500
            49 => 'Sync Release (Master Only)',                    # new with D500
            50 => 'Sync Release (Remote Only)',                    # new with D500
        },
    },
    16.1 => { # CSf1-j
        Name => 'AssignBktButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Auto Bracketing',
            1 => 'Multiple Exposure',
            2 => 'HDR (high dynamic range)',
            3 => 'None',
        },
    },
    18.1 => { # CSf4-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Autofocus Off, Exposure Off',
            1 => 'Autofocus Off, Exposure On',
            2 => 'Autofocus Off, Exposure On (Mode A)',
            4 => 'Autofocus On, Exposure Off',
            5 => 'Autofocus On, Exposure On',
            6 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf4-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf4-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    18.4 => { # CSf6
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            3 => '10 s',
            5 => '30 s',
            6 => '1 min',
            7 => '5 min',
            8 => '10 min',
            9 => '30 min',
            10 => 'No Limit',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    20.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    20.3 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    21.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '2 s',
            1 => '4 s',
            3 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    21.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
            4 => '20 min',
            5 => '30 min',
            6 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            2 => '1/250 s (auto FP)',
            3 => '1/250 s',
            5 => '1/200 s',
            6 => '1/160 s',
            7 => '1/125 s',
            8 => '1/100 s',
            9 => '1/80 s',
            10 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    37.1 => { # CSf2-c
        Name => 'MultiSelectorLiveView',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Reset',
            1 => 'Zoom',
            3 => 'Not Used',
        },
    },
    38.1 => { # CSf3-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    38.2 => { # CSf3-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    38.3 => { # CSg1-h
        Name => 'MovieShutterButton',
        Mask => 0x10,
        PrintConv => {
            0 => 'Take Photo',
            1 => 'Record Movies',
        },
    },
    38.4 => { # CSe3
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0 => 'Entire Frame',
            1 => 'Background Only',
        },
    },
    38.5 => { # CSe4
        Name => 'AutoFlashISOSensitivity',
        Mask => 0x02,
        PrintConv => {
            0 => 'Subject and Background',
            1 => 'Subject Only',
        },
    },
    41.1 => { # CSg1-c
        Name => 'MovieFunc1Button',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            2 => 'Power Aperture (close)',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            11 => 'Exposure Compensation -',
        },
    },
    41.2 => { # CSg1-a
        Name => 'MoviePreviewButton',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Power Aperture (open)',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            10 => 'Exposure Compensation +',
        },
    },
    42.1 => { # CSf1-d
        Name => 'Func1ButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
        },
    },
    43.1 => { # CSf1-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',    # new with D500
            8 => 'Exposure Delay Mode',
        },
    },
    45.1 => { # CSf1-k
        Name => 'AssignMovieRecordButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
            2 => 'Shutter Speed & Aperture Lock',
            7 => 'Photo Shooting Menu Bank',
            11 => 'Exposure Mode',
        },
    },
    46.1 => { # CSb7-d
        Name => 'FineTuneOptHighlightWeighted',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    47.1 => { # CSa12-b
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    47.2 => { # CSa12-a
        Name => 'AFPointIllumination',
        Mask => 0x40,
        PrintConv => {
            0 => 'Off',
            1 => 'On During Manual Focusing',
        },
    },
    47.3 => { # CSa7
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area Mode',
        },
    },
    47.4 => { # CSa12-c
        Name => 'GroupAreaAFIllumination',
        Mask => 0x04,
        PrintConv => {
            0 => 'Squares',
            1 => 'Dots',
        },
    },
    48.1 => { # CSb5
        Name => 'MatrixMetering',
        Mask => 0x80,
        PrintConv => {
            0 => 'Face Detection On',
            1 => 'Face Detection Off',
        },
    },
    48.2 => { # CSf8
        Name => 'LiveViewButtonOptions',
        Mask => 0x30,
        PrintConv => {
            0 => 'Enable',
            1 => 'Enable (Standby Timer Active)',    # new with D500
            2 => 'Disable',
        },
    },
    48.3 => { # CSa10
        Name => 'AFModeRestrictions',
        Mask => 0x03,
        PrintConv => {
            0 => 'No Restrictions',
            1 => 'AF-C',
            2 => 'AF-S',
        },
    },
    49.1 => { # CSa9
        Name => 'LimitAFAreaModeSelection',
        Mask => 0x7e,
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                0 => 'Auto-area',
                1 => 'Group-area',
                2 => '3D-tracking',
                3 => 'Dynamic area (153 points)',
                4 => 'Dynamic area (72 points)',
                5 => 'Dynamic area (25 points)',
            },
        },
    },
    52.1 => { # CSf1-l
        Name => 'LensFocusFunctionButtons',
        Mask => 0x3f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            24 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
        },
    },
    66.1 => { # CSf10-d
        Name => 'VerticalMultiSelector',
        Mask => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Same as Multi-Selector with Info(U/D) & Playback(R/L)',
            0x08 => 'Same as Multi-Selector with Info(R/L) & Playback(U/D)',
            0x80 => 'Focus Point Selection',
        },
    },
    67.1 => { # CSf10-a
        Name => 'AssignMB-D17FuncButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'Reset Focus Point',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            23 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            54 => 'Highlight Active Focus Point',
        },
    },
    68.1 => { # CSf10-b
        Name => 'AssignMB-D17FuncButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
            10 => 'ISO Sensitivity',
            11 => 'Exposure Mode',
            12 => 'Exposure Compensation',
            13 => 'Metering Mode',
        },
    },
    70.1 => { # CSf1-f
        Name => 'AF-OnButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
        },
    },
    71.1 => { # CSf1-g
        Name => 'SubSelector',
        Mask => 0x80,
        PrintConv => {
            0 => 'Focus Point Selection',
            1 => 'Same as MultiSelector',
        },
    },
    72.1 => { # CSf1-h
        Name => 'SubSelectorCenter',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'Reset Focus Point',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            23 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            54 => 'Highlight Active Focus Point',
        },
    },
    73.1 => { # CSf1-i
        Name => 'SubSelectorPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
            2 => 'Shutter Speed & Aperture Lock',
            4 => 'Choose Non-CPU Lens Number',
            7 => 'Photo Shooting Menu Bank',
        },
    },
    74.1 => { # CSg1-f
        Name => 'AssignMovieSubselector',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            5 => 'AE/AF Lock',
            6 => 'AE Lock (Only)',
            7 => 'AE Lock (Hold)',
            8 => 'AF Lock (Only)',
        },
    },
    75.1 => { # CSg1-d
        Name => 'AssignMovieFunc1ButtonPlusDials',
        Mask => 0x10,
        PrintConv => {
            0  => 'None',
            1  => 'Choose Image Area (DX/1.3x)',
        },
    },
    75.2 => { # CSg1-b
        Name => 'AssignMoviePreviewButtonPlusDials',
        Mask => 0x01,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (DX/1.3x)',
        },
    },
    76.1 => { # CSg1-g
        Name => 'AssignMovieSubselectorPlusDials',
        Mask => 0x10,
        PrintConv => {
            0  => 'None',
            1  => 'Choose Image Area (DX/1.3x)',
        },
    },
    77.1 => { # CSd4
        Name => 'SyncReleaseMode',          # new with D500
        Mask => 0x80,
        PrintConv => {
            0 => 'No Sync',
            1 => 'Sync',
        },
    },
    78.1 => { # CSa5
        Name => 'Three-DTrackingWatchArea', # new with D500
        Mask => 0x80,
        PrintConv => {
            0 => 'Wide',
            1 => 'Normal',
        },
    },
    78.2 => { # CSa3-b
        Name => 'SubjectMotion',
        Mask => 0x60,
        PrintConv => {
            0 => 'Steady',
            1 => 'Middle',
            2 => 'Erratic',
        },
    },
    78.3 => { # CSa8
        Name => 'AFActivation',
        Mask => 0x08,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    78.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)'
        },
    },
    79.1 => { # CSf10-c
        Name => 'AssignMB-D17AF-OnButton',
        Mask => 0x7f,
        PrintConv => {
            0 => 'None',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            100 => 'Same as Camera AF-On Button',
        },
    },
    80.1 => { # CSf1-e
        Name => 'Func2Button',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            15 => 'My Menu Top Item',
            20 => 'My Menu',
            55 => 'Rating',
        },
    },
    82.1 => { # CSg1-e
        Name => 'AssignMovieFunc2Button',
        Mask => 0x70,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
);

# D610 custom settings (ref forum6942)
%Image::ExifTool::NikonCustom::SettingsD610 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D610.',
    0.1 => { #CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0x80,
        PrintConv => {
            0 => 'Release',
            1 => 'Focus',
        },
    },
    0.2 => { #CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release',
            1 => 'Focus',
        },
    },
    0.3 => { # CSa6
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0 => '39 Points',
            1 => '11 Points',
        },
    },
    0.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0 => 'Off',
            1 => '1 Short',
            2 => '2',
            3 => '3 Normal',
            4 => '4',
            5 => '5 Long',
        },
    },
    1.1 => { # CSa5
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    1.2 => { # CSa4
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    1.3 => { # CSa7
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    5.1 => { # CSb3
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On Auto Reset',
        },
    },
    6.1 => { # CSb2
        Name => 'ExposureControlStep',
        Mask => 0x40,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    6.2 => { # CSb1
        Name => 'ISOSensitivityStep',
        Mask => 0x10,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    7.1 => { # CSb4
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            2 => '15 mm',
            3 => '20 mm',
            4 => 'Average',
        },
    },
    7.2 => { # CSb5-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    8.1 => { # CSb5-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    8.2 => { # CSb5-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    17.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    18.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            2 => '10 s',
            3 => '30 s',
            4 => '1 min',
            5 => '5 min',
            6 => '10 min',
            7 => '30 min',
            8 => 'No Limit',
        },
    },
    18.2 => { # CSc5
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '20 min',
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    19.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    19.3 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    20.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '2 s',
            1 => '4 s',
            2 => '10 s',
            3 => '20 s',
            4 => '1 min',
            5 => '5 min',
            6 => '10 min',
        },
    },
    20.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '5 min',
            1 => '10 min',
            2 => '15 min',
            3 => '20 min',
            4 => '30 min',
            5 => 'No Limit',
        },
    },
    21.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s', # default
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    21.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    35.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
);

# D810 custom settings (ref 1)
%Image::ExifTool::NikonCustom::SettingsD810 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 24.1 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D810.',
    0.1 => { # CSf1
        Name => 'LightSwitch',
        Mask => 0x08,
        PrintConv => {
            0 => 'LCD Backlight',
            1 => 'LCD Backlight and Shooting Information',
        },
    },
    0.2 => {
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    1.1 => { #CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa7
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0 => '51 Points',
            1 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0 => 'Off',
            1 => '1 (Short)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Long)',
        },
    },
    2.1 => { # CSa4
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    2.2 => { # CSa7
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    2.3 => { # CSa6
        Name => 'AFPointBrightness',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    2.4 => { # CSa10
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    3.1 => { # CSd13
        Name => 'BatteryOrder',
        Mask => 0x40,
        PrintConv => {
            0 => 'MB-D12 First',
            1 => 'Camera Battery First',
        },
    },
    3.2 => { # CSd12
        Name => 'MB-D12BatteryType',
        Mask => 0x03,
        PrintConv => {
            0 => 'LR6 (AA alkaline)',
            1 => 'HR6 (AA Ni-MH)',
            2 => 'FR6 (AA lithium)',
        },
    },
    4.1 => { # CSd1-b
        Name => 'Pitch',
        Mask => 0x40,
        PrintConv => { 0 => 'High', 1 => 'Low' },
    },
    4.2 => { # CSf11
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    4.3 => { # CSd8
        Name => 'ISODisplay',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Show ISO/Easy ISO',
            1 => 'Show ISO Sensitivity',
            3 => 'Show Frame Count',
        },
    },
    4.4 => { # CSd7
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    5.1 => { # CSd10
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Not Set', # observed on a new camera prior to applying a setting for the first time
            1 => 'Auto',
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
    },
    5.2 => { # CSd11
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    5.3 => { # CSd5
        Name => 'ElectronicFront-CurtainShutter',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    5.4 => { # CSd9
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    5.5 => { # CSd1-a
        Name => 'Beep',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Medium',
            3 => 'High',
        },
    },
    6.1 => { # CSf12
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.2 => { # CSf9-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
            2 => 'Exposure Compensation',
            3 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.3 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    8.1 => { # CSb6
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            2 => '15 mm',
            3 => '20 mm',
            4 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Select Center Focus Point (Reset)',
            1 => 'Highlight Active Focus Point',
            2 => 'Preset Focus Point (Pre)',
            3 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf2-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x30,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
            3 => 'Choose Folder',
        },
    },
    10.3 => { # CSf3
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd4
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    11.2 => { # CSd2
        Name => 'CLModeShootingSpeed',
        Mask => 0x0f,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    12.1 => { # CSd3
        Name => 'MaxContinuousRelease',
        # values: 1-100
    },
    13.1 => { # CSe6
        Name => 'AutoBracketSet',
        Mask => 0xe0,
        PrintConv => {
            0 => 'AE & Flash',
            1 => 'AE Only',
            2 => 'Flash Only',
            3 => 'WB Bracketing',
            4 => 'Active D-Lighting',
        },
    },
    13.2 => { # CSe8
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    13.3 => { # CSe7
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    14.1 => { # CSf4-a
        Name => 'FuncButton',
        Mask => 0x1f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display', # values 19 and 20 are swapped from the D4s encodings
            20 => 'My Menu',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',    # new value with D810
        },
    },
    15.1 => { # CSf5-a
        Name => 'PreviewButton',
        Mask => 0x1f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display', # values 19 and 20 are swapped from the D4s encodings
            20 => 'My Menu',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',        # new value with D810
        },
    },
    16.1 => { # CSf8
        Name => 'AssignBktButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Auto Bracketing',
            1 => 'Multiple Exposure',
            2 => 'HDR (high dynamic range)',
            3 => 'None',
        },
    },
    17.1 => { # CSf6-a
        Name => 'AELockButton',
        Mask => 0x1f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display', # values 19 and 20 are swapped from the D4s encodings
            20 => 'My Menu',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',        # new value with D810
        },
    },
    18.1 => { # CSf9-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Autofocus Off, Exposure Off',
            1 => 'Autofocus Off, Exposure On',
            2 => 'Autofocus Off, Exposure On (Mode A)',
            4 => 'Autofocus On, Exposure Off',
            5 => 'Autofocus On, Exposure On',
            6 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf9-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf9-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    18.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    18.5 => { # CSf10
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            3 => '10 s',
            5 => '30 s',
            6 => '1 min',
            7 => '5 min',
            8 => '10 min',
            9 => '30 min',
            10 => 'No Limit', #1
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    20.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    20.3 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    21.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',  # note: decode changed from D4s
        Mask => 0xe0,
        PrintConv => {
            0 => '2 s',
            1 => '4 s',
            3 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    21.2 => { # CSc4-e                        # note: decode changed from D4s
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
            4 => '20 min',
            5 => '30 min',
            6 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b                        # note: decode changed from D4s
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    22.2 => { # CSc4-c                        # note: decode changed from D4s
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0 => '1/320 s (auto FP)',
            2 => '1/250 s (auto FP)',
            3 => '1/250 s',
            5 => '1/200 s',
            6 => '1/160 s',
            7 => '1/125 s',
            8 => '1/100 s',
            9 => '1/80 s',
            10 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    24.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    37.1 => { # CSf2-c
        Name => 'MultiSelectorLiveView',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Reset',
            1 => 'Zoom',
            3 => 'Not Used',
        },
    },
    38.1 => { # CSf7-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    38.2 => { # CSf7-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    38.3 => { # CSg4
        Name => 'MovieShutterButton',
        Mask => 0x20,
        PrintConv => {
            0 => 'Take Photo',
            1 => 'Record Movies',
        },
    },
    38.4 => { # CSe4
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0 => 'Entire frame',
            1 => 'Background only',
        },
    },
    40.1 => { # CSg3
        Name => 'MovieAELockButtonAssignment',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            5 => 'AE/AF Lock',
            6 => 'AE Lock Only',
            7 => 'AE Lock (hold)',
            8 => 'AF Lock Only',
        },
    },
    41.1 => { # CSg1
        Name => 'MovieFunctionButton',
        Mask => 0x70,
        PrintConv => {
            0 => 'None',
            1 => 'Power Aperture (open)', # bit '02' is also toggled on for this setting
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
    41.2 => { # CSg2
        Name => 'MoviePreviewButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            2 => 'Power Aperture (open)', # bit '10' is also toggled on for this setting
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
    42.1 => { # CSf4-b
        Name => 'FuncButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            8 => 'Exposure Delay Mode',
        },
    },
    43.1 => { # CSf5-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            8 => 'Exposure Delay Mode',
        },
    },
    44.1 => { # CSf6-b
        Name => 'AELockButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            4 => 'Choose Non-CPU Lens Number',
            8 => 'Exposure Delay Mode',
        },
    },
    45.1 => { # CSf13
        Name => 'AssignMovieRecordButton',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            9 => 'White Balance',
            10 => 'ISO Sensitivity',
        },
    },
    46.1 => { # CSb7-d
        Name => 'FineTuneOptHighlightWeighted',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    47.1 => { # CSa5-b
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    47.2 => { # CSa5-a              # moved with D810
        Name => 'AFPointIllumination',
        Mask => 0x40,
        PrintConv => {
            0 => 'Off',
            1 => 'On During Manual Focusing',
        },
    },
    47.3 => { # CSa9
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area mode',
        },
    },
    47.4 => { # CSa5-c
        Name => 'GroupAreaAFIllumination',
        Mask => 0x04,
        PrintConv => {
            0 => 'Squares',      # moved with D810
            1 => 'Dots',
        },
    },
    48.1 => { # CSb5
        Name => 'MatrixMetering',
        Mask => 0x80,
        PrintConv => {
            0 => 'Face Detection On',
            1 => 'Face Detection Off',
        },
    },
    48.2 => { # CSf14
        Name => 'LiveViewButtonOptions',
        Mask => 0x30,
        PrintConv => {
            0 => 'Enable',
            2 => 'Disable',
        },
    },
    48.3 => { # CSa12
        Name => 'AFModeRestrictions',
        Mask => 0x03,
        PrintConv => {
            0 => 'No Restrictions',
            1 => 'AF-C',
            2 => 'AF-S',
        },
    },
    49.1 => { # CSa11
        Name => 'LimitAFAreaModeSelection',
        Mask => 0x7e,
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                0 => 'Auto-area',
                1 => 'Group-area',
                2 => '3D-tracking',
                3 => 'Dynamic area (51 points)',
                4 => 'Dynamic area (21 points)',
                5 => 'Dynamic area (9 points)',
            },
        },
    },
    50.1 => { # CSf15
        Name => 'AF-OnForMB-D12',
        Mask => 0x07,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AE Lock (reset)',
            5 => 'AF-On',
            6 => 'FV Lock',
            7 => 'Same As Fn Button',
        },
    },
    51.1 => { # CSf16
        Name => 'AssignRemoteFnButton',
        Mask => 0x1f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            16 => '+NEF(RAW)',
            25 => 'Live View',
            26 => 'Flash Disable/Enable',
        },
    },
    52.1 => { # CSf17
        Name => 'LensFocusFunctionButtons',
        Mask => 0x3f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            7 => 'AF Lock Only',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            24 => 'Preset focus Point',
            26 => 'Flash Disable/Enable',
            32 => 'AF-Area Mode:  Single-point AF',
            33 => 'AF-Area Mode: Dynamic-area AF (9 points)',
            34 => 'AF-Area Mode: Dynamic-area AF (21 points)',
            35 => 'AF-Area Mode: Dynamic-area AF (51 points)',
            36 => 'AF-Area Mode: Group-area AF',
            37 => 'AF-Area Mode: Auto area AF',
        },
    },
);

# D850 custom settings (ref 1)
%Image::ExifTool::NikonCustom::SettingsD850 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D850.',
    0.2 => {
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    1.1 => { #CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
            3 => 'Focus + Release',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa6
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0 => '55 Points',
            1 => '15 Points',
        },
    },
    1.4 => { # CSa4
        Name => 'Three-DTrackingFaceDetection',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    1.5 => { # CSa3-a
        Name => 'BlockShotAFResponse',
        Mask => 0x07,
        PrintConv => {
            1 => '1 (Quick)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Delay)',
        },
    },
    2.1 => { # CSa11
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    2.2 => { # CSa12-a
        Name => 'AFPointBrightness',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    4.1 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0 => 'Show ISO Sensitivity',
            1 => 'Show Frame Count',
        },
    },
    4.2 => { # CSd9
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    5.1 => { # CSd10
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    5.2 => { # CSd6
        Name => 'ElectronicFront-CurtainShutter',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    6.1 => { # CSf7
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.2 => { # CSf4-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
            2 => 'Exposure Compensation',
            3 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.3 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (Auto Reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    8.1 => { # CSb6
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            2 => '15 mm',
            3 => '20 mm',
            4 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Select Center Focus Point (Reset)',
            2 => 'Preset Focus Point (Pre)',
            3 => 'Highlight Active Focus Point',
            4 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf2-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
            3 => 'Choose Folder',
        },
    },
    10.3 => { # CSf5
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Off',
            1 => '0.2 s',          #new with the D850
            2 => '0.5 s',          #new with the D850
            3 => '1 s',
            4 => '2 s',
            5 => '3 s',
        },
    },
    11.2 => { # CSd1
        Name => 'CLModeShootingSpeed',
        Mask => 0x0f,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    12.1 => { # CSd2
        Name => 'MaxContinuousRelease',
        # values: 1-100
    },
    13.1 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    13.2 => { # CSe6
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    14.1 => { # CSf1-c
        Name => 'Func1Button',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
        },
    },
    15.1 => { # CSf1-a
        Name => 'PreviewButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
        },
    },
    16.1 => { # CSf1-j
        Name => 'AssignBktButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Auto Bracketing',
            1 => 'Multiple Exposure',
            2 => 'HDR (high dynamic range)',
            3 => 'None',
        },
    },
    18.1 => { # CSf4-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Autofocus Off, Exposure Off',
            1 => 'Autofocus Off, Exposure On',
            2 => 'Autofocus Off, Exposure On (Mode A)',
            4 => 'Autofocus On, Exposure Off',
            5 => 'Autofocus On, Exposure On',
            6 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf4-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf4-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    18.4 => { # CSf6
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            3 => '10 s',
            5 => '30 s',
            6 => '1 min',
            7 => '5 min',
            8 => '10 min',
            9 => '30 min',
            10 => 'No Limit',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    20.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    20.3 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    21.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '2 s',
            1 => '4 s',
            3 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    21.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
            4 => '20 min',
            5 => '30 min',
            6 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            2 => '10 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            2 => '1/250 s (auto FP)',
            3 => '1/250 s',
            5 => '1/200 s',
            6 => '1/160 s',
            7 => '1/125 s',
            8 => '1/100 s',
            9 => '1/80 s',
            10 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    37.1 => { # CSf2-c
        Name => 'MultiSelectorLiveView',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Reset',
            1 => 'Zoom',
            3 => 'Not Used',
        },
    },
    38.1 => { # CSf3-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    38.2 => { # CSf3-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    38.3 => { # CSg1-h
        Name => 'MovieShutterButton',
        Mask => 0x10,
        PrintConv => {
            0 => 'Take Photo',
            1 => 'Record Movies',
        },
    },
    38.4 => { # CSe3
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0 => 'Entire Frame',
            1 => 'Background Only',
        },
    },
    38.5 => { # CSe4
        Name => 'AutoFlashISOSensitivity',
        Mask => 0x02,
        PrintConv => {
            0 => 'Subject and Background',
            1 => 'Subject Only',
        },
    },
    41.1 => { # CSg1-c
        Name => 'MovieFunc1Button',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            2 => 'Power Aperture (close)',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            11 => 'Exposure Compensation -',
        },
    },
    41.2 => { # CSg1-a
        Name => 'MoviePreviewButton',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Power Aperture (open)',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            10 => 'Exposure Compensation +',
        },
    },
    42.1 => { # CSf1-d
        Name => 'Func1ButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
        },
    },
    43.1 => { # CSf1-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
        },
    },
    45.1 => { # CSf1-k
        Name => 'AssignMovieRecordButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            7 => 'Photo Shooting Menu Bank',
            11 => 'Exposure Mode',
        },
    },
    46.1 => { # CSb7-d
        Name => 'FineTuneOptHighlightWeighted',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    47.1 => { # CSa12-c
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    47.2 => { # CSa12-b
        Name => 'AFPointIllumination',
        Mask => 0x40,
        PrintConv => {
            0 => 'Off',
            1 => 'On During Manual Focusing',
        },
    },
    47.3 => { # CSa7
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area Mode',
        },
    },
    48.1 => { # CSb5
        Name => 'MatrixMetering',
        Mask => 0x80,
        PrintConv => {
            0 => 'Face Detection On',
            1 => 'Face Detection Off',
        },
    },
    48.2 => { # CSf8
        Name => 'LiveViewButtonOptions',
        Mask => 0x30,
        PrintConv => {
            0 => 'Enable',
            1 => 'Enable (Standby Timer Active)',
            2 => 'Disable',
        },
    },
    48.3 => { # CSa10
        Name => 'AFModeRestrictions',
        Mask => 0x03,
        PrintConv => {
            0 => 'No Restrictions',
            1 => 'AF-C',
            2 => 'AF-S',
        },
    },
    49.1 => { # CSa9
        Name => 'LimitAFAreaModeSelection',  #note that 'Dynamic area (9 points)' can be selected from the camera menu but the setting is not written to the EXIF data.
        Mask => 0x7e,                        #...This AF Mode was added to the D5 firmware several months after the camera's initial release which may help explain the inconsistency.
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                0 => 'Auto-area',
                1 => 'Group-area',
                2 => '3D-tracking',
                3 => 'Dynamic area (153 points)',
                4 => 'Dynamic area (72 points)',
                5 => 'Dynamic area (25 points)',
          },
        },
    },
    52.1 => { # CSf1-l
        Name => 'LensFocusFunctionButtons',
        Mask => 0x3f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            24 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
        },
    },
    66.1 => { # CSf10-d
        Name => 'VerticalMultiSelector',
        Mask => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Same as Multi-Selector with Info(U/D) & Playback(R/L)',
            0x08 => 'Same as Multi-Selector with Info(R/L) & Playback(U/D)',
            0x80 => 'Focus Point Selection',
        },
    },
    67.1 => { # CSf10-a
        Name => 'AssignMB-D18FuncButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'Reset Focus Point',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            23 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            54 => 'Highlight Active Focus Point',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
        },
    },
    68.1 => { # CSf10-b
        Name => 'AssignMB-D18FuncButtonPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            7 => 'Photo Shooting Menu Bank',
            8 => 'Exposure Delay Mode',
            10 => 'ISO Sensitivity',
            11 => 'Exposure Mode',
            12 => 'Exposure Compensation',
            13 => 'Metering Mode',
        },
    },
    70.1 => { # CSf1-f
        Name => 'AF-OnButton',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
        },
    },
    71.1 => { # CSf1-g
        Name => 'SubSelector',
        Mask => 0x80,
        PrintConv => {
            0 => 'Focus Point Selection',
            1 => 'Same as MultiSelector',
        },
    },
    72.1 => { # CSf1-h
        Name => 'SubSelectorCenter',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'Reset Focus Point',
            19 => 'Grid Display',
            20 => 'My Menu',
            22 => 'Remote Release Only',
            23 => 'Preset Focus Point',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            49 => 'Sync Release (Master Only)',
            50 => 'Sync Release (Remote Only)',
            54 => 'Highlight Active Focus Point',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
        },
    },
    73.1 => { # CSf1-i
        Name => 'SubSelectorPlusDials',
        Mask => 0x0f,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
            2 => 'Shutter Speed & Aperture Lock',
            4 => 'Choose Non-CPU Lens Number',
            7 => 'Photo Shooting Menu Bank',
        },
    },
    74.1 => { # CSg1-f
        Name => 'AssignMovieSubselector',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
            5 => 'AE/AF Lock',
            6 => 'AE Lock (Only)',
            7 => 'AE Lock (Hold)',
            8 => 'AF Lock (Only)',
        },
    },
    75.1 => { # CSg1-d
        Name => 'AssignMovieFunc1ButtonPlusDials',
        Mask => 0x10,
        PrintConv => {
            0  => 'None',
            1  => 'Choose Image Area',
        },
    },
    75.2 => { # CSg1-b
        Name => 'AssignMoviePreviewButtonPlusDials',
        Mask => 0x01,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
        },
    },
    76.1 => { # CSg1-g
        Name => 'AssignMovieSubselectorPlusDials',
        Mask => 0x10,
        PrintConv => {
            0  => 'None',
            1  => 'Choose Image Area',
        },
    },
    77.1 => { # CSd4
        Name => 'SyncReleaseMode',
        Mask => 0x80,
        PrintConv => {
            0 => 'No Sync',
            1 => 'Sync',
        },
    },
    77.2 => { # CSd11 (new with D850)
        Name => 'ContinuousModeLiveView',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    78.1 => { # CSa5
        Name => 'Three-DTrackingWatchArea',
        Mask => 0x80,
        PrintConv => {
            0 => 'Wide',
            1 => 'Normal',
        },
    },
    78.2 => { # CSa3-b
        Name => 'SubjectMotion',
        Mask => 0x60,
        PrintConv => {
            0 => 'Steady',
            1 => 'Middle',
            2 => 'Erratic',
        },
    },
    78.3 => { # CSa8
        Name => 'AFActivation',
        Mask => 0x08,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    78.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)'
        },
    },
    79.1 => { # CSf10-c
        Name => 'AssignMB-D18AF-OnButton',
        Mask => 0x7f,
        PrintConv => {
            0 => 'None',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            36 => 'AF-Area Mode (Single)',
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',
            39 => 'AF-Area Mode (Dynamic Area 153 Points)',
            40 => 'AF-Area Mode (Group Area AF)',
            41 => 'AF-Area Mode (Auto Area AF)',
            42 => 'AF-Area Mode + AF-On (Single)',
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',
            45 => 'AF-Area Mode + AF-On (Dynamic Area 153 Points)',
            46 => 'AF-Area Mode + AF-On (Group Area AF)',
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',
            56 => 'AF-Area Mode (Dynamic Area 9 Points)',
            57 => 'AF-Area Mode + AF-On (Dynamic Area 9 Points)',
            100 => 'Same as Camera AF-On Button',
        },
    },
    80.1 => { # CSf1-e
        Name => 'Func2Button',
        Mask => 0x3f,
        PrintConv => {
            0 => 'None',
            15 => 'My Menu Top Item',
            20 => 'My Menu',
            55 => 'Rating',
        },
    },
    82.1 => { # CSg1-e
        Name => 'AssignMovieFunc2Button',
        Mask => 0x70,
        PrintConv => {
            0 => 'None',
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
);

# D5000 custom settings (ref PH)
%Image::ExifTool::NikonCustom::SettingsD5000 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D5000.',
    # Missing/Incomplete settings:
    # CSd7 - LiveViewDisplayOptions [couldn't find in data - try again with live view shots]
    0.1 => { # CSa1
        Name => 'AFAreaModeSetting',
        Mask => 0x60,
        PrintConv => {
            0 => 'Single Area',
            1 => 'Dynamic Area',
            2 => 'Auto-area',
            3 => '3D-tracking (11 points)',
        },
    },
    0.2 => { # CSa2
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    2.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    2.2 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    2.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    2.4 => { # CSf4
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    3.1 => { # CSd4
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    4.1 => { # CSa4
        Name => 'RangeFinder',
        Mask => 0x10,
        PrintConv => \%offOn,
    },
    4.2 => { # CSd6
        Name => 'DateImprint',
        Mask => 0x08,
        PrintConv => \%offOn,
    },
    4.3 => { # CSf5
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    5.1 => { # CSb1
        Name => 'EVStepSize',
        Mask => 0x40,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    9.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    11.1 => { # CSe2
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Exposure',
            # (NOTE: the following are reversed in the D5100 -- is this correct?)
            1 => 'Active D-Lighting', #(NC)
            2 => 'WB Bracketing',
        },
    },
    12.1 => { # CSf1
        Name => 'TimerFunctionButton',
        Mask => 0x38,
        PrintConv => {
            0 => 'Self-timer',
            1 => 'Release Mode',
            2 => 'Image Quality/Size', #(NC)
            3 => 'ISO', #(NC)
            4 => 'White Balance', #(NC)
            5 => 'Active D-Lighting', #(NC)
            6 => '+ NEF (RAW)',
            7 => 'Auto Bracketing',
        },
    },
    15.1 => { # CSf2
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only', #(NC)
            2 => 'AF Lock Only', #(NC)
            3 => 'AE Lock (hold)',
            4 => 'AF-ON',
        },
    },
    16.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    16.2 => { # CSf3
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => \%noYes,
    },
    17.1 => { # CSc2-c
        Name => 'MeteringTime',
        Mask => 0x70,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s',
            3 => '1 min',
            4 => '30 min',
        },
    },
    17.2 => { # CSc4
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
        },
    },
    18.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    18.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x1e,
    },
    19.1 => { # CSc2-b
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s',
            3 => '1 min',
            4 => '10 min',
        },
    },
    20.1 => { # CSc2-a
        Name => 'PlaybackMenusTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 s',
            1 => '12 s',
            2 => '20 s',
            3 => '1 min',
            4 => '10 min',
        },
    },
    22.1 => { # CSe1-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
        },
    },
    22.2 => { # CSe1-b
        Name => 'ManualFlashOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    32.1 => { # CSa3
        Name => 'LiveViewAF',
        Mask => 0x60,
        PrintConv => {
            0 => 'Face Priority',
            1 => 'Wide Area',
            2 => 'Normal Area',
            3 => 'Subject Tracking',
        },
    },
);

# D5100 custom settings (ref PH)
%Image::ExifTool::NikonCustom::SettingsD5100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D5100.',
    0.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0x80,
        PrintConv => {
            0 => 'Release',
            1 => 'Focus',
        },
    },
    1.1 => { # CSa2
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    3.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    3.2 => { # CSf4
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    3.3 => { # CSd2
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    4.1 => { # CSd3
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    5.1 => { # CSa3
        Name => 'RangeFinder',
        Mask => 0x10,
        PrintConv => \%offOn,
    },
    # (it looks like CSd5 DateImprint is not stored)
    5.2 => { # CSf5
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.1 => { # CSb1
        Name => 'EVStepSize',
        Mask => 0x40,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    10.1 => { # CSd4
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    12.1 => { # CSe2
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Exposure',
            # (NOTE: the following are reversed from the D5000 -- is D5000 correct?)
            1 => 'WB Bracketing',
            2 => 'Active D-Lighting',
        },
    },
    13.1 => { # CSf1
        Name => 'TimerFunctionButton',
        Mask => 0x38,
        PrintConv => {
            0 => 'Self-timer',
            1 => 'Release Mode',
            2 => 'Image Quality/Size',
            3 => 'ISO',
            4 => 'White Balance',
            5 => 'Active D-Lighting',
            6 => '+ NEF (RAW)',
            7 => 'Auto Bracketing',
        },
    },
    16.1 => { # CSf2
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AF-ON',
        },
    },
    17.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    17.2 => { # CSf3
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => \%noYes,
    },
    18.1 => { # CSc2-d
        Name => 'MeteringTime',
        Mask => 0x70,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s', #(NC)
            3 => '1 min',
            4 => '30 min', #(NC)
        },
    },
    18.2 => { # CSc4
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min', #(NC)
            3 => '20 min', # (but picture in manual shows 15 min)
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    19.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    20.1 => { # CSc2-b
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '8 s', #(NC)
            2 => '20 s',
            3 => '1 min', #(NC)
            4 => '10 min', #(NC)
        },
    },
    20.2 => { # CSc2-c
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '3 min',
            1 => '5 min', #(NC)
            2 => '10 min',
            3 => '15 min', #(NC)
            4 => '20 min', #(NC)
            5 => '30 min', #(NC)
        },
    },
    21.1 => { # CSc2-a
        Name => 'PlaybackMenusTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 s', #(NC)
            1 => '12 s',
            2 => '20 s',
            3 => '1 min',
            4 => '10 min', #(NC)
        },
    },
    23.1 => { # CSe1-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
        },
    },
    23.1 => { # CSe1-b
        Name => 'ManualFlashOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
);

# D5200 custom settings (ref PH)
%Image::ExifTool::NikonCustom::SettingsD5200 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D5200.',
    0.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0x80,
        PrintConv => {
            0 => 'Release',
            1 => 'Focus',
        },
    },
    0.2 => { # CSa2
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0 => '39 Points',
            1 => '11 Points',
        },
    },
    1.1 => { # CSa3
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    3.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    3.2 => { # CSf4
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    3.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    4.1 => { # CSd3
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    5.1 => { # CSa4
        Name => 'RangeFinder',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    5.2 => { # CSf3-a
        Name => 'ReverseExposureCompDial',
        Mask => 0x10,
        PrintConv => \%noYes,
    },
    5.3 => { # CSf3-b
        Name => 'ReverseShutterSpeedAperture',
        Mask => 0x08,
        PrintConv => \%noYes,
    },
    5.4 => { # CSf5
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.1 => { # CSb1
        Name => 'EVStepSize',
        Mask => 0x40, # (bit 0x04 also changes)
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    10.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    12.1 => { # CSe2
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Exposure',
            # (NOTE: the following are reversed from the D5000 -- is D5000 correct?)
            1 => 'WB Bracketing',
            2 => 'Active D-Lighting',
        },
    },
    13.1 => { # CSf1
        Name => 'FunctionButton',
        Mask => 0x1f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-ON',
            16 => '+ NEF (RAW)',
            18 => 'Active D-Lighting',
            25 => 'Live View',
            26 => 'Image Quality',
            27 => 'ISO',
            28 => 'White Balance',
            29 => 'HDR',
            30 => 'Auto Bracketing',
            31 => 'AF-area Mode',
        },
    },
    16.1 => { # CSf2
        Name => 'AELockButton',
        Mask => 0x0f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-ON',
        },
    },
    17.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    18.1 => { # CSc2-d
        Name => 'StandbyTimer',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '8 s',
            2 => '20 s',
            3 => '1 min',
            4 => '30 min',
        },
    },
    18.2 => { # CSc4
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    19.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    20.1 => { # CSc2-b
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            1 => '4 s',
            2 => '8 s',
            4 => '20 s',
            5 => '1 min',
            7 => '10 min',
        },
    },
    20.2 => { # CSc2-c
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
            4 => '20 min',
            5 => '30 min',
        },
    },
    21.1 => { # CSc2-a
        Name => 'PlaybackMenusTime',
        Mask => 0xe0,
        PrintConv => {
            1 => '8 s',
            4 => '20 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
        },
    },
    23.1 => { # CSe1-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
        },
    },
    23.2 => { # CSe1-b
        Name => 'ManualFlashOutput',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
);

# D7000 custom settings (ref 2)
%Image::ExifTool::NikonCustom::SettingsD7000 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 23.1 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D7000.',
    0.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0x80,
        PrintConv => {
            0 => 'Release',
            1 => 'Focus',
        },
    },
    0.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    0.3 => { # CSa6
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0 => '39 Points',
            1 => '11 Points',
        },
    },
    0.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0 => 'Off',
            1 => '1 Short',
            2 => '2',
            3 => '3 Normal',
            4 => '4',
            5 => '5 Long',
        },
    },
    1.1 => { # CSa5
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    1.2 => { # CSa4
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
        },
    },
    1.3 => { # CSa7
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    2.1 => { # CSd14
        Name => 'BatteryOrder',
        Mask => 0x40,
        PrintConv => {
            0 => 'MB-D11 First',
            1 => 'Camera Battery First',
        },
    },
    2.2 => { # CSa10
        Name => 'AF-OnForMB-D11',
        Mask => 0x1c,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AF-ON',
            5 => 'FV Lock',
            6 => 'Same as FUNC Button',
        },
    },
    2.3 => { # CSd13
        Name => 'MB-D11BatteryType',
        Mask => 0x03,
        PrintConv => {
            0 => 'LR6 (AA alkaline)',
            1 => 'Ni-MH (AA Ni-MH)',
            2 => 'FR6 (AA lithium)',
        },
    },
    3.1 => { # CSd1-b
        Name => 'BeepPitch',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    3.2 => { # CSf8
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    3.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Show ISO/Easy ISO',
            1 => 'Show ISO Sensitivity',
            3 => 'Show Frame Count',
        },
    },
    3.4 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    3.5 => { # CSd4
        Name => 'ViewfinderWarning',
        Mask => 0x01,
        PrintConv => \%onOff,
    },
    4.1 => { # CSd9
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Auto',
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
    },
    4.2 => { # CSd10
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    4.3 => { # CSd8
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => \%onOff,
    },
    4.4 => { # CSd5
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    4.5 => { # CSd1-a
        Name => 'BeepVolume',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => '1',
            2 => '2',
            3 => '3',
        },
    },
    5.1 => { # CSf9
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    5.2 => { # CSb3
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On Auto Reset',
        },
    },
    6.1 => { # CSb2
        Name => 'ExposureControlStep',
        Mask => 0x40,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    6.2 => { # CSb1
        Name => 'ISOSensitivityStep',
        Mask => 0x10,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
        },
    },
    7.1 => { # CSb4
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '6 mm',
            1 => '8 mm',
            2 => '10 mm',
            3 => '13 mm',
            4 => 'Average',
        },
    },
    10.1 => { # CSd11
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    10.2 => { # CSd6
        Name => 'CLModeShootingSpeed',
        Mask => 0x07,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    11 => { # CSd7
        Name => 'MaxContinuousRelease',
        # values: 1-100
    },
    12.1 => { # CSe5
        Name => 'AutoBracketSet',
        Mask => 0xe0, #(NC)
        PrintConv => {
            0 => 'AE & Flash', # default
            1 => 'AE Only',
            2 => 'Flash Only', #(NC)
            3 => 'WB Bracketing', #(NC)
            4 => 'Active D-Lighting', #(NC)
        },
    },
    12.2 => { # CSe6
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    13.1 => { # CSf3
        Name => 'FuncButton',
        Mask => 0xf8,
        PrintConv => {
            0 => 'Grid Display',
            1 => 'FV Lock',
            2 => 'Flash Off',
            3 => 'Matrix Metering',
            4 => 'Center-weighted Metering',
            5 => 'Spot Metering',
            6 => 'My Menu Top',
            7 => '+ NEF (RAW)',
            8 => 'Active D-Lighting',
            9 => 'Preview',
            10 => 'AE/AF Lock',
            11 => 'AE Lock Only',
            12 => 'AF Lock Only',
            13 => 'AE Lock (hold)',
            14 => 'Bracketing Burst',
            15 => 'Playback',
            16 => '1EV Step Speed/Aperture',
            17 => 'Choose Non-CPU Lens',
            18 => 'Virtual Horizon',
            19 => 'Start Movie Recording',
        },
    },
    14.1 => { # CSf4
        Name => 'PreviewButton',
        Mask => 0xf8,
        PrintConv => {
            0 => 'Grid Display',
            1 => 'FV Lock',
            2 => 'Flash Off',
            3 => 'Matrix Metering',
            4 => 'Center-weighted Metering',
            5 => 'Spot Metering',
            6 => 'My Menu Top',
            7 => '+ NEF (RAW)',
            8 => 'Active D-Lighting',
            9 => 'Preview',
            10 => 'AE/AF Lock',
            11 => 'AE Lock Only',
            12 => 'AF Lock Only',
            13 => 'AE Lock (hold)',
            14 => 'Bracketing Burst',
            15 => 'Playback',
            16 => '1EV Step Speed/Aperture',
            17 => 'Choose Non-CPU Lens',
            18 => 'Virtual Horizon',
            19 => 'Start Movie Recording',
        },
    },
    16.1 => { # CSf5
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0 => 'AE/AF Lock',
            1 => 'AE Lock Only',
            2 => 'AF Lock Only',
            3 => 'AE Lock (hold)',
            4 => 'AF-ON',
            5 => 'FV Lock',
        },
    },
    15.1 => { # CSf2
        Name => 'OKButton',
        Mask => 0x18,
        PrintConv => {
            1 => 'Select Center Focus Point',
            2 => 'Highlight Active Focus Point',
            3 => 'Not Used', #(NC)
            0 => 'Off', #(NC)
        },
    },
    17.1 => { # CSf6-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => \%noYes,
    },
    17.2 => { # CSf6-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0x60,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (A mode only)',
        },
    },
    17.3 => { # CSf6-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    17.4 => { # CSf6-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0 => 'On',
            2 => 'On (Image Review Exclude)',
            1 => 'Off',
        },
    },
    17.5 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    17.6 => { # CSf7
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    18.1 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0xf0,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '4 s',
            1 => '6 s', # default
            2 => '8 s',
            3 => '16 s',
            4 => '30 s',
            5 => '1 min',
            6 => '5 min',
            7 => '10 min',
            8 => '30 min',
            9 => 'No Limit',
        },
    },
    18.2 => { # CSc5
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0 => '1 min',
            1 => '5 min',
            2 => '10 min',
            3 => '15 min',
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s', # default
            3 => '20 s',
        },
    },
    19.2 => { # CSc3-c
        Name => 'SelfTimerInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s', # default
            3 => '3 s',
        },
    },
    19.3 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    20.1 => { # CSc4-d
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => { #(NC)
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    20.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => { #(NC)
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    21.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    21.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => { #(NC)
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    22.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0 => '1/320 s (auto FP)',
            1 => '1/250 s (auto FP)',
            2 => '1/250 s',
            3 => '1/200 s',
            4 => '1/160 s',
            5 => '1/125 s',
            6 => '1/100 s',
            7 => '1/80 s',
            8 => '1/60 s',
       },
    },
    22.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    23.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0 => 'TTL',
            1 => 'Manual',
            2 => 'Repeating Flash',
            3 => 'Commander Mode',
        },
    },
    23.2 => { # CSe3-b
        Name => 'ManualFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 1',
        Mask => 0x1f,
        ValueConv => '2 ** (-$val/3)',
        ValueConvInv => '$val > 0 ? -3*log($val)/log(2) : 0',
        PrintConv => q{
            return 'Full' if $val > 0.99;
            Image::ExifTool::Exif::PrintExposureTime($val);
        },
        PrintConvInv => '$val=~/F/i ? 1 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    24.1 => { # CSe3-ca
        Name => 'RepeatingFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0x70,
        ValueConv => '2 ** (-$val-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    24.2 => { # CSe3-cb
        Name => 'RepeatingFlashCount',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    25.1 => { # CSe3-cc (NC)
        Name => 'RepeatingFlashRate',
        Condition => '$$self{FlashControlBuiltin} == 2',
        Mask => 0xf0,
        ValueConv => '$val < 10 ? $val + 1 : 10 * ($val - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5)',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    26.1 => { # CSe3-da
        Name => 'CommanderInternalTTLCompBuiltin',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    27.1 => { # CSe3-db
        Name => 'CommanderInternalTTLCompGroupA',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    28.1 => { # CSe3-dc
        Name => 'CommanderInternalTTLCompGroupB',
        Condition => '$$self{FlashControlBuiltin} == 3',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    30.1 => { # CSd11
        Name => 'FlashWarning',
        Mask => 0x80,
        PrintConv => \%onOff,
    },
    30.2 => { # CSe4
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    34.1 => { # CSa8-b
        Name => 'LiveViewAFAreaMode',
        Mask => 0x60,
        PrintConv => {
            0 => 'Face-Priority',
            1 => 'NormalArea',
            2 => 'WideArea',
            3 => 'SubjectTracking',
        },
    },
    34.2 => { # CSa8-a
        Name => 'LiveViewAFMode',
        Mask => 0x02,
        PrintConv => {
            0 => 'AF-C',
            1 => 'AF-F',
        },
    },
    35.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s', # default
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
);

# D4/D4S custom settings (ref 1, decoded from D4S)
%Image::ExifTool::NikonCustom::SettingsD4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D4 and D4S.',
    0.1 => {
        Name => 'CustomSettingsBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    1.1 => { #CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            2 => 'Focus',
            3 => 'Focus + Release',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0 => 'Focus',
            1 => 'Release',
        },
    },
    1.3 => { # CSa7
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0 => '51 Points',
            1 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0 => 'Off',
            1 => '1 (Short)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Long)',
        },
    },
    2.1 => { # CSa4
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0 => 'Shutter/AF-On',
            1 => 'AF-On Only',
        },
    },
    2.2 => { # CSa6
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0 => 'No Wrap',
            1 => 'Wrap',
        },
    },
    4.1 => { # CSd1-b
        Name => 'Pitch',
        Mask => 0x40,
        PrintConv => { 0 => 'High', 1 => 'Low' },
    },
    4.2 => { # CSf12
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0 => 'Release Locked',
            1 => 'Enable Release',
        },
    },
    4.3 => { # CSd6
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => \%onOff,
    },
    5.1 => { # CSd9
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            # 0 - seen for D4 (PH)
            1 => 'Auto',
            2 => 'Manual (dark on light)',
            3 => 'Manual (light on dark)',
        },
    },
    5.2 => { # CSd10
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => \%offOn,
    },
    5.3 => { # CSd8
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => \%offOn,
    },
    5.4 => { # CSd1-a
        Name => 'Beep',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Medium',
            3 => 'High',
        },
    },
    6.1 => { # CSf13
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0 => '+ 0 -',
            1 => '- 0 +',
        },
    },
    6.2 => { # CSd7-a
        Name => 'RearDisplay',
        Mask => 0x40,
        PrintConv => {
            0 => 'ISO',
            1 => 'Exposures Remaining',
        },
    },
    6.3 => { # CSd7-b
        Name => 'ViewfinderDisplay',
        Mask => 0x20,
        PrintConv => {
            0 => 'Frame Count',
            1 => 'Exposures Remaining',
        },
    },
    6.4 => { # CSd10-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
            2 => 'Exposure Compensation',
            3 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.5 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0 => '1/3 EV',
            1 => '1/2 EV',
            2 => '1 EV',
        },
    },
    8.1 => { # CSb6 (CSb5 for D4)
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            2 => '15 mm',
            3 => '20 mm',
            4 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5))',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf1-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Select Center Focus Point (Reset)',
            2 => 'Preset Focus Point (Pre)',
            3 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf1-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x30,
        PrintConv => {
            0 => 'Thumbnail On/Off',
            1 => 'View Histograms',
            2 => 'Zoom On/Off',
            3 => 'Choose Folder',
        },
    },
    10.3 => { # CSf2
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0 => 'Do Nothing',
            1 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd4
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Off',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    11.2 => { # CSd2-a
        Name => 'CHModeShootingSpeed',
        Mask => 0x10,
        PrintConv => {
            0 => '10 fps',
            1 => '11 fps',
        },
    },
    11.3 => { # CSd2-b
        Name => 'CLModeShootingSpeed',
        Mask => 0x0f,
        PrintConv => '"$val fps"',
        PrintConvInv => '$val=~s/\s*fps//i; $val',
    },
    12 => { # CSd3
        Name => 'MaxContinuousRelease',
        # values: 1-200
    },
    13.1 => { # CSe6
        Name => 'AutoBracketSet',
        Mask => 0xe0,
        PrintConv => {
            0 => 'AE & Flash',
            1 => 'AE Only',
            2 => 'Flash Only',
            3 => 'WB Bracketing',
            4 => 'Active D-Lighting',
        },
    },
    13.2 => { # CSe8
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
        },
    },
    13.3 => { # CSe7
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
        },
    },
    14.1 => { # CSf3-a
        Name => 'FuncButton',
        Mask => 0xf8,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'My Menu',
            20 => 'Grid Display',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
        },
    },
    14.2 => { # CSf3-b
        Name => 'FuncButtonPlusDials',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            6 => 'Shooting Bank Menu',
        },
    },
    15.1 => { # CSf4-a
        Name => 'PreviewButton',
        Mask => 0xf8,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'My Menu',
            20 => 'Grid Display',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
        },
    },
    15.2 => { # CSf4-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            6 => 'Shooting Bank Menu',
        },
    },
    16.1 => { # CSf9
        Name => 'AssignBktButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Auto Bracketing',
            1 => 'Multiple Exposure',
            2 => 'HDR (high dynamic range)',
            3 => 'None',
        },
    },
    18.1 => { # CSf10-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0xe0,
        PrintConv => {
            0 => 'Autofocus Off, Exposure Off',
            1 => 'Autofocus Off, Exposure On',
            2 => 'Autofocus Off, Exposure On (Mode A)',
            4 => 'Autofocus On, Exposure Off',
            5 => 'Autofocus On, Exposure On',
            6 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf10-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf10-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0 => 'Sub-command Dial',
            1 => 'Aperture Ring',
        },
    },
    18.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => \%offOn,
    },
    18.5 => { # CSf11
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => \%noYes,
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0 => '4 s',
            1 => '6 s',
            3 => '10 s',
            5 => '30 s',
            6 => '1 min',
            7 => '5 min',
            8 => '10 min',
            9 => '30 min',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    20.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x0f,
    },
    20.3 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    21.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '2 s',
            1 => '4 s',
            2 => '10 s',
            3 => '20 s',
            4 => '1 min',
            5 => '5 min',
            6 => '10 min',

        },
    },
    21.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '5 min',
            1 => '10 min',
            2 => '15 min',
            3 => '20 min',
            4 => '30 min',
            5 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            # 0x00 - seen for D4 (PH)
            1 => '1/250 s (auto FP)',
            2 => '1/250 s',
            3 => '1/200 s',
            4 => '1/160 s',
            5 => '1/125 s',
            6 => '1/100 s',
            7 => '1/80 s',
            8 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1/60 s',
            1 => '1/30 s',
            2 => '1/15 s',
            3 => '1/8 s',
            4 => '1/4 s',
            5 => '1/2 s',
            6 => '1 s',
            7 => '2 s',
            8 => '4 s',
            9 => '8 s',
            10 => '15 s',
            11 => '30 s',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => \%onOff,
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0 => '4 s',
            1 => '10 s',
            2 => '20 s',
            3 => '1 min',
            4 => '5 min',
            5 => '10 min',
        },
    },
    37.1 => { # CSf15
        Name => 'PlaybackZoom',
        Mask => 0x01,
        PrintConv => {
            0 => 'Use Separate Zoom Buttons',
            1 => 'Use Either Zoom Button with Command Dial',
        },
    },
    38.1 => { # CSf8-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    38.2 => { # CSf8-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => \%offOn,
    },
    38.3 => { # CSg4
        Name => 'MovieShutterButton',
        Mask => 0x30,
        PrintConv => {
            0 => 'Take Photo',
            1 => 'Record Movies',
            2 => 'Live Frame Grab',
        },
    },
    38.4 => { # CSe4
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0 => 'Entire frame',
            1 => 'Background only',
        },
    },
    41.1 => { # CSg1-a
        Name => 'MovieFunctionButton',
        Mask => 0x70,
        PrintConv => {
            0 => 'None',
            1 => 'Power Aperture (open)', # bit '02' is also toggled on for this setting
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
    41.2 => { # CSg2-a
        Name => 'MoviePreviewButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            2 => 'Power Aperture (open)', # bit '10' is also toggled on for this setting
            3 => 'Index Marking',
            4 => 'View Photo Shooting Info',
        },
    },
    42.1 => { # CSf14
        Name => 'VerticalMultiSelector',
        Mask => 0x60,
        PrintConv => {
            0 => 'Same as Multi-Selector with Info(U/D) & Playback(R/L)',
            1 => 'Same as Multi-Selector with Info(R/L) & Playback(U/D)',
            2 => 'Focus Point Selection',
        },
    },
    42.2 => { # CSf7-a
        Name => 'VerticalFuncButton',
        Mask => 0x1f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'My Menu',
            20 => 'Grid Display',
            26 => 'Flash Disable/Enable',
        },
    },
    43.1 => { # CSf7-b
        Name => 'VerticalFuncButtonPlusDials',
        Mask => 0xf0,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'One Step Speed / Aperture',
            4 => 'Choose Non-CPU Lens Number',
            5 => 'Active D-Lighting',
            6 => 'Shooting Bank Menu',
            7 => 'ISO Sensitivity',
            8 => 'Exposure Mode',
            9 => 'Exposure Compensation',
            10 => 'Metering',
        },
    },
    43.2 => { # CSf16
        Name => 'AssignMovieRecordButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            3 => 'ISO Sensitivity',
            4 => 'Shooting Bank Menu',
        },
    },
    46.1 => { # CSa5-c
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => \%offOn,
    },
    46.2 => { # CSa5-a
        Name => 'AFPointIllumination',
        Mask => 0x60,
        PrintConv => {
            0 => 'Off',
            1 => 'On in Continuous Shooting Modes',
            2 => 'On During Manual Focusing',
            3 => 'On in Continuous Shooting and Manual Focusing',
        },
    },
    46.3 => { # CSa10 (D4 is slightly different -- needs checking)
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area mode',
        },
    },
    46.4 => { # CSa5-d
        Name => 'GroupAreaAFIllumination',
        Mask => 0x04,
        PrintConv => {
            0 => 'Squares',
            1 => 'Dots',
        },
    },
    46.5 => { # CSa5-b
        Name => 'AFPointBrightness',
        Mask => 0x03,
        PrintConv => {
            0 => 'Low',
            1 => 'Normal',
            2 => 'High',
            3 => 'Extra High',
        },
    },
    47.1 => { # CSa8
        Name => 'AFOnButton',
        Mask => 0x70,
        PrintConv => {
            0 => 'AF On',
            1 => 'AE/AF Lock',
            2 => 'AE Lock Only',
            3 => 'AE Lock (reset on release)',
            4 => 'AE Lock (hold)',
            5 => 'AF Lock Only',
            6 => 'None',
        },
    },
    47.2 => { # CSa9
        Name => 'VerticalAFOnButton',
        Mask => 0x07,
        PrintConv => {
            0 => 'Same as AF On',
            1 => 'AF On',
            2 => 'AE/AF Lock',
            3 => 'AE Lock Only',
            4 => 'AE Lock (reset on release)',
            5 => 'AE Lock (hold)',
            6 => 'AF Lock Only',
            7 => 'None',
        },
    },
    48.1 => { # CSf5
        Name => 'SubSelectorAssignment',
        Mask => 0x80,
        PrintConv => {
            0 => 'Focus Point Selection',
            1 => 'Same As Multi-selector',
        },
    },
    48.2 => { # CSg3-a
        Name => 'MovieSubSelectorAssignment',
        Mask => 0x07,
        PrintConv => {
            0 => 'None',
            1 => 'Index Marking',
            2 => 'AE/AF Lock',
            3 => 'AE Lock Only',
            4 => 'AE Lock (hold)',
            5 => 'AF Lock Only',
            6 => 'View Photo Shooting Info',
        },
    },
    49.1 => { # CSf6-a
        Name => 'SubSelector',
        Mask => 0xf8,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            6 => 'AE Lock (hold)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            # 9 - seen for D4 (PH)
            10 => 'Bracketing Burst',
            11 => 'Matrix Metering',
            12 => 'Center-weighted Metering',
            13 => 'Spot Metering',
            14 => 'Playback',
            15 => 'My Menu Top Item',
            16 => '+NEF(RAW)',
            17 => 'Virtual Horizon',
            18 => 'My Menu',
            19 => 'Reset',    # value appears to be specific to this control at this time
            20 => 'Grid Display',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            23 => 'Preview',  # value appears to be specific to this control at this time
            26 => 'Flash Disable/Enable',
        },
    },
    49.2 => { # CSf6-b
        Name => 'SubSelectorPlusDials',
        Mask => 0x07,
        PrintConv => {
            # (not all values from CSf3-b/CSf4-b are available for CSf6-b)
            0 => 'None',
            1 => 'Choose Image Area (FX/DX/5:4)',
            2 => 'Shutter Speed & Aperture Lock',
            # 3 => 'One Step Speed / Aperture', # (not available)
            4 => 'Choose Non-CPU Lens Number',
            # 5 => 'Active D-Lighting',         # (not available)
            6 => 'Shooting Bank Menu',
        },
    },
    50.1 => { # CSb5
        Name => 'MatrixMetering',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x80,
        PrintConv => {
            0 => 'Face Detection On',
            1 => 'Face Detection Off',
        },
    },
    50.2 => { # CSf17
        Name => 'LiveViewButtonOptions',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x30,
        PrintConv => {
            0 => 'Enable',
            1 => 'Enable (standby time active)',
            2 => 'Disable',
        },
    },
    50.3 => { # CSa12
        Name => 'AFModeRestrictions',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x03,
        PrintConv => {
            0 => 'Off',
            1 => 'AF-C',
            2 => 'AF-S',
        },
    },
    51.1 => { # CSa11
        Name => 'LimitAFAreaModeSelection',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x7e,
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                0 => 'Auto-area',
                1 => 'Group-area',
                2 => '3D-tracking',
                3 => 'Dynamic area (51 points)',
                4 => 'Dynamic area (21 points)',
                5 => 'Dynamic area (9 points)',
            },
        },
    },
    52.1 => { # CSg1-b
        Name => 'MovieFunctionButtonPlusDials',
        Mask => 0x10,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
        },
    },
    52.2 => { # CSg2-b
        Name => 'MoviePreviewButtonPlusDials',
        Mask => 0x01,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
        },
    },
    53.1 => { # CSg3-b
        Name => 'MovieSubSelectorAssignmentPlusDials',
        Mask => 0x10,
        PrintConv => {
            0 => 'None',
            1 => 'Choose Image Area',
        },
    },
    54.1 => { # CSf18
        Name => 'AssignRemoteFnButton',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x1f,
        PrintConv => {
            0 => 'None',
            1 => 'Preview',
            2 => 'FV Lock',
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            5 => 'AE Lock (reset on release)',
            7 => 'AF Lock Only',
            8 => 'AF-On',
            16 => '+NEF(RAW)',
            25 => 'Live View',
            26 => 'Flash Disable/Enable',
        },
    },
    55.1 => { # CSf19
        Name => 'LensFocusFunctionButtons',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x3f,
        PrintConv => {
            3 => 'AE/AF Lock',
            4 => 'AE Lock Only',
            7 => 'AF Lock Only',
            21 => 'Disable Synchronized Release',
            22 => 'Remote Release Only',
            24 => 'Preset focus Point',
            26 => 'Flash Disable/Enable',
            32 => 'AF-Area Mode:  Single-point AF',
            33 => 'AF-Area Mode: Dynamic-area AF (9 points)',
            34 => 'AF-Area Mode: Dynamic-area AF (21 points)',
            35 => 'AF-Area Mode: Dynamic-area AF (51 points)',
            36 => 'AF-Area Mode: Group-area AF',
            37 => 'AF-Area Mode: Auto area AF',
        },
    },
);

# Z8 custom settings (ref 1)   #base at offset26 + 1195 (firmware 1.0.0)
%Image::ExifTool::NikonCustom::SettingsZ8 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    DATAMEMBER => [ 185, 529 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the Z8.',
    1 => {
        Name => 'CustomSettingsBank',
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    3 => { # CSa1
        Name => 'AF-CPrioritySelection',
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            3 => 'Focus',
        },
    },
    5 => { Name => 'AF-SPrioritySelection', PrintConv => {0 => 'Release',1 => 'Focus'}},  #CSa2
    7 => { # CSa3-a                      #when AFAreaMode is 3D-tracking, blocked shot response will be 3, regardless of this setting
        Name => 'BlockShotAFResponse',
        PrintConv => {
            1 => '1 (Quick)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Delayed)',
        },
    },
    11 => {Name => 'AFPointSel',PrintConv => { 0 => 'Use All',1 => 'Use Half' }},    # CSa4
    13 => { # CSa5
        Name => 'StoreByOrientation',
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area mode',
        },
    },
    15 => { Name => 'AFActivation',                 PrintConv => {0 => 'AF-On Only', 1 => 'Shutter/AF-On'}},     # CSa6-a
    16 => { Name => 'AF-OnOutOfFocusRelease',       PrintConv => {0 => 'Disable', 1 => 'Enable'}, Unknown => 1},  # CSa6-b
    17 => { Name => 'LimitAF-AreaModeSelPinpoint',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    19 => { Name => 'LimitAF-AreaModeSelWideAF_S',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    20 => { Name => 'LimitAF-AreaModeSelWideAF_L',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    21 => { Name => 'LimitAFAreaModeSelAuto',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8     #left out hypen to retain compatibility with tag name in NikonSettings
    22 => { Name => 'FocusPointWrap',               PrintConv => { 0 => 'No Wrap', 1 => 'Wrap' }, Unknown => 1 }, # CSa10
    23 => { Name => 'ManualFocusPointIllumination', PrintConv => {0 => 'On During Focus Point Selection Only', 1 => 'On', }, Unknown => 1 },  # CSa11a
    24 => { Name => 'DynamicAreaAFAssist',     PrintConv => { 0 => 'Focus Point Only',1 => 'Focus and Surrounding Points',}, Unknown => 1 },  # CSa11b
    25 => { Name => 'AF-AssistIlluminator',    PrintConv => \%offOn }, # CSa12
    26 => { Name => 'ManualFocusRingInAFMode', PrintConv => \%offOn }, # CSa15
    27 => { Name => 'ExposureControlStepSize', PrintConv => \%thirdHalfFull },     # CSb2
    29 => { # CSb3
        Name => 'EasyExposureCompensation',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    31 => { # CSb5
        Name => 'CenterWeightedAreaSize',
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            4 => 'Average',
        },
    },
    33 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    35 => { # CSb6-b
        Name => 'FineTuneOptCenterWeighted',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    37 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    39 => { # CSb6-d
        Name => 'FineTuneOptHighlightWeighted',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    41 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        PrintConv => {
            0 => 'Off',
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)',
        },
    },
    43 => { # CSc2-a
        Name => 'SelfTimerTime',
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    45 => { Name => 'SelfTimerShotCount',  }, # CSc2-b   1-9
    49 => { # CSc2-c
        Name => 'SelfTimerShotInterval',
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    51 => { Name => 'PlaybackMonitorOffTime',    %powerOffDelayTimesZ9 }, # CSc3-a
    53 => { Name => 'MenuMonitorOffTime',        %powerOffDelayTimesZ9 }, # CSc3-b
    55 => { Name => 'ShootingInfoMonitorOffTime',%powerOffDelayTimesZ9 }, # CSc3-c
    57 => { Name => 'ImageReviewMonitorOffTime', %powerOffDelayTimesZ9 }, # CSc3-d
    59 => { Name => 'CLModeShootingSpeed',       ValueConv => '$val + 1', ValueConvInv => '$val - 1', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1b
    61 => {  # CSd2       # values: 1-200 &  'No Limit'
        Name => 'MaxContinuousRelease',
        Format => 'int16s',
        ValueConv => '($val eq -1 ?  \'No Limit\' : $val ) ',
    },
    65 => { Name => 'SyncReleaseMode',                PrintConv => { 0 => 'No Sync', 1 => 'Sync' }, Unknown => 1 }, # CSd4
    69 => { Name => 'LimitSelectableImageAreaDX',     PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-1
    70 => { Name => 'LimitSelectableImageArea1To1',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-2
    71 => { Name => 'LimitSelectableImageArea16To9',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-3
    72 => { Name => 'FileNumberSequence',             PrintConv => \%offOn }, # CSd7
    73 => { #CSa13b
        Name => 'FocusPeakingLevel',
        Unknown => 1,
        PrintConv => {
            0 => 'High Sensitivity',
            1 => 'Standard Sensitivity',
            2 => 'Low Sensitivity',
        },
    },
    75 => { #CSa13c
        Name => 'FocusPeakingHighlightColor',
        Unknown => 1,
        PrintConv => {
            0 => 'Red',
            1 => 'Yellow',
            2 => 'Blue',
            3 => 'White',
        },
    },

    81 => { Name => 'ContinuousModeDisplay',  PrintConv => \%offOn }, # CSd12
    83 => { # CSe1-a            Previous cameras reported this with HighSpeedSync indicator appended as '(Auto FP)'.  Z9 separated the 2 fields.
        Name => 'FlashSyncSpeed',
        ValueConv => '($val-144)/8',
        PrintConv => {
            0 => '1/60 s',
            1 => '1/80 s',
            2 => '1/100 s',
            3 => '1/125 s',
            4 => '1/160 s',
            5 => '1/200 s',
            6 => '1/250 s',
        },
    },
    85 => { Name => 'HighSpeedSync',          PrintConv => \%offOn }, # CSe1-b
    87 => { # CSe2
        Name => 'FlashShutterSpeed',
        ValueConv => 'my $t = ($val - 16) % 24; $t ? $val / 24  : 2 + ($val - 16) / 24',     #unusual decode perhaps due to need to accommodate 4 new values?
        PrintConv => {
            0 => '1 s',
            1 => '1/2 s',
            2 => '1/4 s',
            3 => '1/8 s',
            4 => '1/15 s',
            5 => '1/30 s',
            6 => '1/60 s',
            7 => '30 s',
            8 => '15 s',
            9 => '8 s',
            10 => '4 s',
            11 => '2 s',
        },
    },
    89 => { Name => 'FlashExposureCompArea',   PrintConv => { 0 => 'Entire Frame', 1 => 'Background Only' } }, # CSe3
    91 => { Name => 'AutoFlashISOSensitivity', PrintConv => { 0 => 'Subject and Background',1 => 'Subject Only'} }, # CSe4
    93 => { Name => 'ModelingFlash',           PrintConv => \%offOn }, # CSe5
    95 => { # CSe6
        Name => 'AutoBracketModeM',
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
            4 => 'Flash/ISO',
        },
    },
    97 => { Name => 'AutoBracketOrder',   PrintConv => { 0 => '0,-,+',1 => '-,0,+' } }, # CSe7
    99 => { Name => 'Func1Button',        %buttonsZ9}, # CSf2-a
    115 => { Name => 'Func2Button',       %buttonsZ9}, # CSf2-b
    131 => { Name => 'AFOnButton',                %buttonsZ9}, # CSf2-c
    143 => { Name => 'SubSelector',               %buttonsZ9, Unknown => 1}, # CSf2-g
    155 => { Name => 'AssignMovieRecordButton',   %buttonsZ9, Unknown => 1}, # CSf2-m
    159 => { Name => 'LensFunc1Button',           %buttonsZ9}, # CSf2-o
    167 => { Name => 'LensFunc2Button',           %buttonsZ9}, # CSf2-p
    173 => { # CSf2-q
        Name => 'LensControlRing',
        PrintConv => {
            0 => 'None (Disabled)',
            1 => 'Focus (M/A)',
            2 => 'ISO Sensitivity',
            3 => 'Exposure Compensation',
            4 => 'Aperture',
        },
    },
    175 => { Name => 'MultiSelectorShootMode',     %buttonsZ9}, # CSf2-h    called the OK button in camera, tag name retained for compatibility
    179 => { Name => 'MultiSelectorPlaybackMode',  %buttonsZ9}, # CSf3f
    183 => { Name => 'ShutterSpeedLock',           PrintConv => \%offOn }, # CSf4-a
    184 => { Name => 'ApertureLock',               PrintConv => \%offOn }, # CSf4-b
    185 => { # CSf5-a Previous cameras reported this tag as part of CmdDialsReverseRotation.  Blend with CSf5-b separate settings together to match extant tag name and values
        Name => 'CmdDialsReverseRotExposureComp',
        RawConv => '$$self{CmdDialsReverseRotExposureComp} = $val',
        Hidden => 1,
    },
    186 => [{ # CSf5-a  (continued from above)
        Name => 'CmdDialsReverseRotation',
        Condition => '$$self{CmdDialsReverseRotExposureComp} == 0',
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
        },
    },{
        Name => 'CmdDialsReverseRotation',
        PrintConv => {
            0 => 'Exposure Compensation',
            1 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    }],
    191 => { Name => 'UseDialWithoutHold',  PrintConv => \%offOn, Unknown => 1 }, # CSf6
    193 => { Name => 'ReverseIndicators',   PrintConv => { 0 => '+ 0 -', 1 => '- 0 +' }, Unknown => 1 }, # CSf7
    195 => { Name => 'MovieFunc1Button',    %buttonsZ9}, # CSg2-a
    199 => { Name => 'MovieFunc2Button',    %buttonsZ9}, # CSg2-b

    203 => { Name => 'MovieAF-OnButton',    %buttonsZ9}, # CSg2-f
    215 => { # CSg2-z
        Name => 'MovieLensControlRing',
        PrintConv => {
            0 => 'None (Disabled)',
            2 => 'ISO Sensitivity',
            3 => 'Exposure Compensation',
            4 => 'Power Aperture',
            5 => 'Hi-Res Zoom',
        },
    },
    217 => { Name => 'MovieMultiSelector',  %buttonsZ9, Unknown => 1}, # CSg2-h
    221 => { Name => 'MovieAFSpeed',        ValueConv => '$val - 5', ValueConvInv => '$val + 5' }, # CSg6-a
    223 => { Name => 'MovieAFSpeedApply',   PrintConv => {0 => 'Always', 1 => 'Only During Recording'},}, # CSg6-b
    225 => { # CSg7
        Name => 'MovieAFTrackingSensitivity',
        PrintConv => {
            0 => '1 (High)',
            1 => '2',
            2 => '3',
            3 => '4 (Normal)',
            4 => '5',
            5 => '6',
            6 => '7 (Low)',
        },
    },
    257 => { Name => 'LCDIllumination',           PrintConv => \%offOn, Unknown => 1 }, # CSd11
    258 => { Name => 'ExtendedShutterSpeeds',     PrintConv => \%offOn }, # CSd5
    259 => { Name => 'SubjectMotion',             PrintConv => {0 => 'Erratic', 1 => 'Steady'} },  # CSa3-b
    261 => { Name => 'FocusPointPersistence',     PrintConv => {0 => 'Auto', 1 => 'Off'} }, # CSa7
    263 => { Name => 'AutoFocusModeRestrictions', PrintConv => \%focusModeRestrictionsZ9, Unknown => 1},  # CSa9
    267 => { Name => 'CHModeShootingSpeed',       ValueConv => '$val + 1', ValueConvInv => '$val - 1', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1a
    273 => { Name => 'FlashBurstPriority',            PrintConv => { 0 => 'Frame Rate',1 => 'Exposure'}, Unknown => 1 },  # CSe8
    335 => { Name => 'LimitAF-AreaModeSelDynamic_S',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    336 => { Name => 'LimitAF-AreaModeSelDynamic_M',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    337 => { Name => 'LimitAF-AreaModeSelDynamic_L',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    339 => { Name => 'LimitAF-AreaModeSel3DTracking',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    341 => { Name => 'PlaybackFlickUp',     PrintConv => \%flicksZ9, Unknown => 1}, # CSf12-a
    345 => { Name => 'PlaybackFlickDown',   PrintConv => \%flicksZ9, Unknown => 1}, # CSf12-b
    349 => { Name => 'ISOStepSize',         PrintConv => \%thirdHalfFull },     # CSb1
    355 => { Name => 'ReverseFocusRing',    PrintConv => { 0 => 'Not Reversed', 1 => 'Reversed' } }, # CSf8
    356 => { Name => 'EVFImageFrame',       PrintConv => \%offOn, Unknown => 1 }, # CSd14
    357 => { Name => 'EVFGrid',             PrintConv => \%evfGridsZ9, Unknown => 1 }, # CSd15
    359 => { Name => 'VirtualHorizonStyle', PrintConv => {0 => 'Type A (Cockpit)', 1 => 'Type B (Sides)' }, Unknown => 1}, #CSd16
    421 => { Name => 'Func1ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-a
    423 => { Name => 'Func2ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-b
    437 => { Name => 'MovieRecordButtonPlaybackMode',  %buttonsZ9, Unknown => 1}, # CSf3-m
    453 => { Name => 'WBButtonPlaybackMode',   %buttonsZ9},     #CSf2
    461 => { Name => 'CommandDialVideoPlaybackMode',        PrintConv => \%dialsVideoZ9,   Unknown => 1}, # CSf3-b
    465 => { Name => 'SubCommandDialVideoPlaybackMode',     PrintConv => \%dialsVideoZ9,   Unknown => 1}, # CSf3-b
    467 => { Name => 'FocusPointLock',                 PrintConv => \%offOn,     Unknown => 1}, # CSf4-c
    459 => { Name => 'CommandDialPlaybackMode',        PrintConv => \%dialsZ9,   Unknown => 1}, # CSf3-k
    463 => { Name => 'SubCommandDialPlaybackMode',     PrintConv => \%dialsZ9,   Unknown => 1}, # CSf3-l
    469 => { Name => 'ControlRingResponse',            PrintConv => { 0 => 'High', 1 => 'Low' } }, # CSf10

    515 => { Name => 'MovieAFAreaMode',       %buttonsZ9, Unknown => 1}, # CSg2-e
    529 => { # CSg9-a
        Name => 'ZebraPatternToneRange',
        Unknown => 1,
        RawConv => '$$self{ZebraPatternToneRange} = $val',
        PrintConv => {
            0 => 'Off',
            1 => 'Highlights',
            2 => 'Midtones',
        },
    },
    531 => { Name => 'MovieZebraPattern',              Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} != 0', PrintConv => {0 => 'Pattern 1', 1 => 'Pattern 2'}, Unknown => 1}, # CSg12-b
    533 => { Name => 'MovieHighlightDisplayThreshold', Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 1', Unknown => 1 }, # CSg12-c   120-25  when highlights are the selected tone range
    535 => { Name => 'MovieMidtoneDisplayValue',       Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 2', Unknown => 1 }, # CSg12-d1     when midtones are the selected tone range
    537 => { Name => 'MovieMidtoneDisplayRange',       Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 2', PrintConv => '"+/-$val"', Unknown => 1 }, # CSg12-d1     when midtones are the selected tone range
    541 => { Name => 'MovieEVFGrid',          PrintConv => \%evfGridsZ9, Unknown => 1 }, # CSg11
    549 => { Name => 'MovieShutterSpeedLock', PrintConv => \%offOn,     Unknown => 1}, # CSg4-a
    550 => { Name => 'MovieFocusPointLock',   PrintConv => \%offOn,     Unknown => 1}, # CSf4-c
    563 => { Name => 'MatrixMetering',        PrintConv => { 0 => 'Face Detection Off', 1 => 'Face Detection On' }, Unknown => 1 }, # CSb4
    564 => { Name => 'AF-CFocusDisplay',      PrintConv => \%offOn }, # CSa11c
    565 => { Name => 'FocusPeakingDisplay',   PrintConv => \%offOn, Unknown => 1}, # CSa13a
    567 => { # CSb7
        Name => 'KeepExposure',
        PrintConv => {
            0 => 'Off',
            1 => 'Shutter Speed',
            2 => 'ISO',
        },
    },
    585 => { Name => 'StarlightView',   PrintConv => \%offOn, Unknown => 1 }, # CSd9
    587 => { # CSd10-a
        Name => 'EVFWarmDisplayMode',
        Unknown => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Mode 1',
            2 => 'Mode 2',
        },
    },
    589 => {  # CSd10-b      values in range -3 to +3
        Name => 'EVFWarmDisplayBrightness',
        Format => 'int8s',
        Unknown => 1,
    },
    591 => { #CSd13
        Name => 'EVFReleaseIndicator',
        Unknown => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Type A (Dark)',
            2 => 'Type B (Border)',
            3 => 'Type C (Sides)',
        },
    },
    601 => { Name => 'MovieApertureLock',     PrintConv => \%offOn,  Unknown => 1 }, # CSg4-b
    607 => { Name => 'FlickAdvanceDirection', PrintConv => {  0 => 'Left to Right', 1 => 'Right to Left' },  Unknown => 1 }, # CSf11-c
    647 => { #CSd4-a
        Name => 'PreReleaseBurstLength',
        PrintConv => {
            0 => 'None',
            1 => '0.3 Sec',
            2 => '0.5 Sec',
            3 => '1 Sec',
        },
    },
    649 => { #CSd4-b
        Name => 'PostReleaseBurstLength',
        PrintConv => {
            0 => '1 Sec',
            1 => '2 Sec',
            2 => '3 Sec',
            3 => 'Max',
        },
    },
    681 => { Name => 'ViewModeShowEffectsOfSettings', PrintConv => { 0=>'Always', 1=> 'Only When Flash Not Used'}, Unknown => 1 },     #CS8-a
    683 => { Name => 'DispButton',                  %buttonsZ9},    #CSf2
    753 => {  #CSd5
        Name => 'ExposureDelay',
        Format => 'int16u',
        PrintConv => '$val ? sprintf("%.1f sec",$val/1000) : "Off"',
    },
);

# Z9 custom settings (ref 1)   #base at offset26 + 1035 (firmware 1.0.0)
%Image::ExifTool::NikonCustom::SettingsZ9 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    DATAMEMBER => [ 185, 529 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the Z9.',
    1 => {
        Name => 'CustomSettingsBank',
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    3 => { # CSa1
        Name => 'AF-CPrioritySelection',
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            3 => 'Focus',
        },
    },
    5 => { Name => 'AF-SPrioritySelection', PrintConv => {0 => 'Release',1 => 'Focus'}},  #CSa2
    7 => { # CSa3-a                      #when AFAreaMode is 3D-tracking, blocked shot response will be 3, regardless of this setting
        Name => 'BlockShotAFResponse',
        PrintConv => {
            1 => '1 (Quick)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Delayed)',
        },
    },
    11 => {Name => 'AFPointSel',PrintConv => { 0 => 'Use All',1 => 'Use Half' }},    # CSa4
    13 => { # CSa5
        Name => 'StoreByOrientation',
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area mode',
        },
    },
    15 => { Name => 'AFActivation',                 PrintConv => {0 => 'AF-On Only', 1 => 'Shutter/AF-On'}},     # CSa6-a
    16 => { Name => 'AF-OnOutOfFocusRelease',       PrintConv => {0 => 'Disable', 1 => 'Enable'}, Unknown => 1},  # CSa6-b
    17 => { Name => 'LimitAF-AreaModeSelPinpoint',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    19 => { Name => 'LimitAF-AreaModeSelWideAF_S',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    20 => { Name => 'LimitAF-AreaModeSelWideAF_L',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    21 => { Name => 'LimitAFAreaModeSelAuto',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8     #left out hypen to retain compatibility with tag name in NikonSettings
    22 => { Name => 'FocusPointWrap',               PrintConv => { 0 => 'No Wrap', 1 => 'Wrap' }, Unknown => 1 }, # CSa10
    23 => { Name => 'ManualFocusPointIllumination', PrintConv => {0 => 'On During Focus Point Selection Only', 1 => 'On', }, Unknown => 1 },  # CSa11a
    24 => { Name => 'DynamicAreaAFAssist',     PrintConv => { 0 => 'Focus Point Only',1 => 'Focus and Surrounding Points',}, Unknown => 1 },  # CSa11b
    25 => { Name => 'AF-AssistIlluminator',    PrintConv => \%offOn }, # CSa12
    26 => { Name => 'ManualFocusRingInAFMode', PrintConv => \%offOn }, # CSa14
    27 => { Name => 'ExposureControlStepSize', PrintConv => \%thirdHalfFull },     # CSb2
    29 => { # CSb3
        Name => 'EasyExposureCompensation',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    31 => { # CSb5
        Name => 'CenterWeightedAreaSize',
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            4 => 'Average',
        },
    },
    33 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    35 => { # CSb6-b
        Name => 'FineTuneOptCenterWeighted',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    37 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    39 => { # CSb6-d
        Name => 'FineTuneOptHighlightWeighted',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    41 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        PrintConv => {
            0 => 'Off',
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)',
        },
    },
    43 => { # CSc3-a
        Name => 'SelfTimerTime',
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    45 => { Name => 'SelfTimerShotCount',  }, # CSc3-b   1-9
    49 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    51 => { Name => 'PlaybackMonitorOffTime',    %powerOffDelayTimesZ9 }, # CSc4-a
    53 => { Name => 'MenuMonitorOffTime',        %powerOffDelayTimesZ9 }, # CSc4-b
    55 => { Name => 'ShootingInfoMonitorOffTime',%powerOffDelayTimesZ9 }, # CSc4-c
    57 => { Name => 'ImageReviewMonitorOffTime', %powerOffDelayTimesZ9 }, # CSc4-d
    59 => { Name => 'CLModeShootingSpeed',       ValueConv => '$val + 1', ValueConvInv => '$val - 1', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1b
    61 => {  # CSd2       # values: 1-200 &  'No Limit'
        Name => 'MaxContinuousRelease',
        Format => 'int16s',
        ValueConv => '($val eq -1 ?  \'No Limit\' : $val ) ',
    },
    65 => { Name => 'SyncReleaseMode',                PrintConv => { 0 => 'No Sync', 1 => 'Sync' }, Unknown => 1 }, # CSd4
    69 => { Name => 'LimitSelectableImageAreaDX',     PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-1
    70 => { Name => 'LimitSelectableImageArea1To1',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-2
    71 => { Name => 'LimitSelectableImageArea16To9',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-3
    72 => { Name => 'FileNumberSequence',             PrintConv => \%offOn }, # CSd7
    73 => { #CSa13b
        Name => 'FocusPeakingLevel',
        Unknown => 1,
        PrintConv => {
            0 => 'High Sensitivity',
            1 => 'Standard Sensitivity',
            2 => 'Low Sensitivity',
        },
    },
    75 => { #CSa13c
        Name => 'FocusPeakingHighlightColor',
        Unknown => 1,
        PrintConv => {
            0 => 'Red',
            1 => 'Yellow',
            2 => 'Blue',
            3 => 'White',
        },
    },
    81 => { Name => 'ContinuousModeDisplay',  PrintConv => \%offOn }, # CSd12
    83 => { # CSe1-a            Previous cameras reported this with HighSpeedSync indicator appended as '(Auto FP)'.  Z9 separated the 2 fields.
        Name => 'FlashSyncSpeed',
        ValueConv => '($val-144)/8',
        PrintConv => {
            0 => '1/60 s',
            1 => '1/80 s',
            2 => '1/100 s',
            3 => '1/125 s',
            4 => '1/160 s',
            5 => '1/200 s',
            6 => '1/250 s',
        },
    },
    85 => { Name => 'HighSpeedSync',          PrintConv => \%offOn }, # CSe1-b
    87 => { # CSe2
        Name => 'FlashShutterSpeed',
        ValueConv => 'my $t = ($val - 16) % 24; $t ? $val / 24  : 2 + ($val - 16) / 24',     #unusual decode perhaps due to need to accommodate 4 new values?
        PrintConv => {
            0 => '1 s',
            1 => '1/2 s',
            2 => '1/4 s',
            3 => '1/8 s',
            4 => '1/15 s',
            5 => '1/30 s',
            6 => '1/60 s',
            7 => '30 s',
            8 => '15 s',
            9 => '8 s',
            10 => '4 s',
            11 => '2 s',
        },
    },
    89 => { Name => 'FlashExposureCompArea',   PrintConv => { 0 => 'Entire Frame', 1 => 'Background Only' } }, # CSe3
    91 => { Name => 'AutoFlashISOSensitivity', PrintConv => { 0 => 'Subject and Background',1 => 'Subject Only'} }, # CSe4
    93 => { Name => 'ModelingFlash',           PrintConv => \%offOn }, # CSe5
    95 => { # CSe6
        Name => 'AutoBracketModeM',
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
            4 => 'Flash/ISO',
        },
    },
    97 => { Name => 'AutoBracketOrder',   PrintConv => { 0 => '0,-,+',1 => '-,0,+' } }, # CSe7
    99 => { Name => 'Func1Button',        %buttonsZ9}, # CSf2-a
    #101 Func1Button submenu: Preview               0 => 'Press To Recall', 1=> 'Hold To Recall'  # CSf2-a
    #103 Func1Button submenu: AreaMode              0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-a
    #105 Func1Button submenu: AreaMode+AF-On        0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-a
    #109 Func1Button submenu: SynchronizedRelease   1=>'Master', 2=>'Remote'  # CSf2-a
    #111 Func1Button submenu: Zoom                  0=>'Zoom (Low)', 2=>'Zoom (1:1)', 2=>'Zoom (High)'  # CSf2-a
    #113 Func1Button & Func1ButtonPlayback submenu: Rating                # CSf2-a & CSf3a   0=>'Candidate For Deletion'  6=>''None'
    115 => { Name => 'Func2Button',       %buttonsZ9}, # CSf2-b
    #117 Func2Button submenu: Preview               0 => 'Press To Recall', 1=> 'Hold To Recall' # CSf2-b
    #119 Func2Button submenu: AreaMode              0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-b
    #121 Func2Button submenu: AreaMode+AF-On        0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-b
    #125 Func2Button submenu: SynchronizedRelease   1=>'Master', 2=>'Remote'  # CSf2-b
    #127 Func2Button submenu: Zoom                  0=>'Zoom (Low)', 2=>'Zoom (1:1)', 2=>'Zoom (High)'  # CSf2-b
    #129 Func2Button & Func2ButtonPlayback submenu: Rating                # CSf2-b & CSf3b   0=>'Candidate For Deletion'  6=>''None'
    131 => { Name => 'AFOnButton',                %buttonsZ9}, # CSf2-c
    143 => { Name => 'SubSelector',               %buttonsZ9, Unknown => 1}, # CSf2-g
    155 => { Name => 'AssignMovieRecordButton',   %buttonsZ9, Unknown => 1}, # CSf2-m
    159 => { Name => 'LensFunc1Button',           %buttonsZ9}, # CSf2-o
    167 => { Name => 'LensFunc2Button',           %buttonsZ9}, # CSf2-p
    173 => { # CSf2-q
        Name => 'LensControlRing',
        PrintConv => {
            0 => 'None (Disabled)',
            1 => 'Focus (M/A)',
            2 => 'ISO Sensitivity',
            3 => 'Exposure Compensation',
            4 => 'Aperture',
        },
    },
    175 => { Name => 'MultiSelectorShootMode',     %buttonsZ9}, # CSf2-h    called the OK button in camera, tag name retained for compatibility
    179 => { Name => 'MultiSelectorPlaybackMode',  %buttonsZ9}, # CSf3f
    183 => { Name => 'ShutterSpeedLock',           PrintConv => \%offOn }, # CSf4-a
    184 => { Name => 'ApertureLock',               PrintConv => \%offOn }, # CSf4-b
    185 => { # CSf5-a Previous cameras reported this tag as part of CmdDialsReverseRotation.  Blend with CSf5-b separate settings together to match extant tag name and values
        Name => 'CmdDialsReverseRotExposureComp',
        RawConv => '$$self{CmdDialsReverseRotExposureComp} = $val',
        Hidden => 1,
    },
    186 => [{ # CSf5-a  (continued from above)
        Name => 'CmdDialsReverseRotation',
        Condition => '$$self{CmdDialsReverseRotExposureComp} == 0',
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
        },
    },{
        Name => 'CmdDialsReverseRotation',
        PrintConv => {
            0 => 'Exposure Compensation',
            1 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    }],
    191 => { Name => 'UseDialWithoutHold',  PrintConv => \%offOn, Unknown => 1 }, # CSf6
    193 => { Name => 'ReverseIndicators',   PrintConv => { 0 => '+ 0 -', 1 => '- 0 +' }, Unknown => 1 }, # CSf7
    195 => { Name => 'MovieFunc1Button',    %buttonsZ9}, # CSg2-a
    199 => { Name => 'MovieFunc2Button',    %buttonsZ9}, # CSg2-b
    203 => { Name => 'MovieAF-OnButton',    %buttonsZ9}, # CSg2-f
    207 => { Name => 'MovieMultiSelector',  %buttonsZ9, Unknown => 1}, # CSg2-h
    215 => { # CSg2-z
        Name => 'MovieLensControlRing',
        PrintConv => {
            0 => 'None (Disabled)',
            2 => 'ISO Sensitivity',
            3 => 'Exposure Compensation',
            4 => 'Power Aperture',
            5 => 'Hi-Res Zoom',
        },
    },
    221 => { Name => 'MovieAFSpeed',        ValueConv => '$val - 5', ValueConvInv => '$val + 5' }, # CSg6-a
    223 => { Name => 'MovieAFSpeedApply',   PrintConv => {0 => 'Always', 1 => 'Only During Recording'},}, # CSg6-b
    225 => { # CSg7
        Name => 'MovieAFTrackingSensitivity',
        PrintConv => {
            0 => '1 (High)',
            1 => '2',
            2 => '3',
            3 => '4 (Normal)',
            4 => '5',
            5 => '6',
            6 => '7 (Low)',
        },
    },
    257 => { Name => 'LCDIllumination',           PrintConv => \%offOn, Unknown => 1 }, # CSd11
    258 => { Name => 'ExtendedShutterSpeeds',     PrintConv => \%offOn }, # CSd5
    259 => { Name => 'SubjectMotion',             PrintConv => {0 => 'Erratic', 1 => 'Steady'} },  # CSa3-b
    261 => { Name => 'FocusPointPersistence',     PrintConv => {0 => 'Auto', 1 => 'Off'} }, # CSa7
    263 => { Name => 'AutoFocusModeRestrictions', PrintConv => \%focusModeRestrictionsZ9, Unknown => 1},  # CSa9
    267 => { Name => 'CHModeShootingSpeed',       ValueConv => '$val + 1', ValueConvInv => '$val - 1', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1a
    269.1 => { Name => 'LimitReleaseModeSelCL',   Mask => 0x02, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-a
    269.2 => { Name => 'LimitReleaseModeSelCH',   Mask => 0x04, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-b
    269.3 => { Name => 'LimitReleaseModeSelC30',  Mask => 0x10, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-e
    269.4 => { Name => 'LimitReleaseModeSelC120', Mask => 0x40, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-c
    269.5 => { Name => 'LimitReleaseModeSelSelf', Mask => 0x80, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-d
    273 => { Name => 'FlashBurstPriority',            PrintConv => { 0 => 'Frame Rate',1 => 'Exposure'}, Unknown => 1 },  # CSe8
    277 => { Name => 'VerticalFuncButton',            %buttonsZ9}, # CSf2-c
    281 => { Name => 'Func3Button',                   %buttonsZ9}, # CSf2-c
    285 => { Name => 'VerticalAFOnButton',            %buttonsZ9}, # CSf2-l
    293 => { Name => 'VerticalMultiSelectorPlaybackMode',  PrintConv => { 0 => 'Image Scroll L/R', 1 => 'Image Scroll Up/Down' }, Unknown => 1}, # CSf3-j
    295 => { Name => 'MovieFunc3Button',                   %buttonsZ9}, # CSg2-c
    335 => { Name => 'LimitAF-AreaModeSelDynamic_S',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    336 => { Name => 'LimitAF-AreaModeSelDynamic_M',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    337 => { Name => 'LimitAF-AreaModeSelDynamic_L',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    339 => { Name => 'LimitAF-AreaModeSel3DTracking',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    341 => { Name => 'PlaybackFlickUp',     PrintConv => \%flicksZ9, Unknown => 1}, # CSf11-a
    345 => { Name => 'PlaybackFlickDown',   PrintConv => \%flicksZ9, Unknown => 1}, # CSf11-b
    349 => { Name => 'ISOStepSize',         PrintConv => \%thirdHalfFull },     # CSb1
    355 => { Name => 'ReverseFocusRing',    PrintConv => { 0 => 'Not Reversed', 1 => 'Reversed' } }, # CSf8
    356 => { Name => 'EVFImageFrame',       PrintConv => \%offOn, Unknown => 1 }, # CSd14
    357 => { Name => 'EVFGrid',             PrintConv => \%evfGridsZ9, Unknown => 1 }, # CSd15
    359 => { Name => 'VirtualHorizonStyle', PrintConv => {0 => 'Type A (Cockpit)', 1 => 'Type B (Sides)' }, Unknown => 1}, #CSd16
    373 => { Name => 'Func4Button',         %buttonsZ9, Unknown => 1}, # CSf2-e
    379 => { Name => 'AudioButton',         %buttonsZ9, Unknown => 1}, # CSf2-i
    381 => { Name => 'QualityButton',       %buttonsZ9, Unknown => 1}, # CSf2-j
    399 => { Name => 'VerticalMultiSelector',          %buttonsZ9, Unknown => 1}, # CSf2-k
    421 => { Name => 'Func1ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-a
    423 => { Name => 'Func2ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-b
    425 => { Name => 'Func3ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-c
    431 => { Name => 'Func4ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-e
    437 => { Name => 'MovieRecordButtonPlaybackMode',  %buttonsZ9, Unknown => 1}, # CSf3-m
    439 => { Name => 'VerticalFuncButtonPlaybackMode', %buttonsZ9, Unknown => 1}, # CSf3-d
    441 => { Name => 'AudioButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-g
    447 => { Name => 'QualityButtonPlaybackMode',      %buttonsZ9, Unknown => 1}, # CSf3-h
    467 => { Name => 'FocusPointLock',                 PrintConv => \%offOn,     Unknown => 1}, # CSf4-c
    453 => { Name => 'WhiteBalanceButtonPlaybackMode', %buttonsZ9, Unknown => 1}, # CSf3-i
    459 => { Name => 'CommandDialPlaybackMode',        PrintConv => \%dialsZ9,   Unknown => 1}, # CSf3-k
    463 => { Name => 'SubCommandDialPlaybackMode',     PrintConv => \%dialsZ9,   Unknown => 1}, # CSf3-l
    469 => { Name => 'ControlRingResponse',            PrintConv => { 0 => 'High', 1 => 'Low' } }, # CSf10
    481 => { Name => 'VerticalMovieFuncButton',        %buttonsZ9, Unknown => 1}, # CSg2-d
    505 => { Name => 'VerticalMovieAFOnButton',        %buttonsZ9, Unknown => 1}, # CSg2-l
    515 => { Name => 'MovieAFAreaMode',       %buttonsZ9, Unknown => 1}, # CSg2-e
    #521 => { Name => 'MovieLimitAF-AreaModeSelWideAF_S',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-a
    #522 => { Name => 'MovieLimitAF-AreaModeSelWideAF_W',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-b
    #523 => { Name => 'MovieLimitAF-AreaModeSelSubjectTrack',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-c
    #524 => { Name => 'MovieLimitAFAreaModeSelAuto',           PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-d
    #525 => { Name => 'MovieAutoFocusModeRestrictions', PrintConv => \%focusModeRestrictionsZ9, Unknown => 1},  # CSa9
    527 => { Name => 'HDMIViewAssist', PrintConv => \%offOn, Unknown => 1 }, # CSg8
    529 => { # CSg9-a
        Name => 'ZebraPatternToneRange',
        Unknown => 1,
        RawConv => '$$self{ZebraPatternToneRange} = $val',
        PrintConv => {
            0 => 'Off',
            1 => 'Highlights',
            2 => 'Midtones',
        },
    },
    531 => { Name => 'MovieZebraPattern',              Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} != 0', PrintConv => {0 => 'Pattern 1', 1 => 'Pattern 2'}, Unknown => 1}, # CSg9-b
    533 => { Name => 'MovieHighlightDisplayThreshold', Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 1', Unknown => 1 }, # CSg9-c   120-25  when highlights are the selected tone range
    535 => { Name => 'MovieMidtoneDisplayValue',       Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 2', Unknown => 1 }, # CSg9-d1     when midtones are the selected tone range
    537 => { Name => 'MovieMidtoneDisplayRange',       Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 2', PrintConv => '"+/-$val"', Unknown => 1 }, # CSg9-d1     when midtones are the selected tone range
    #539 CS g-10 LimitZebraPatternToneRange  0=>'No Restrictions', 1=> 'Highlights', 2=> 'Midtones'
    541 => { Name => 'MovieEVFGrid',          PrintConv => \%evfGridsZ9, Unknown => 1 }, # CSg11
    549 => { Name => 'MovieShutterSpeedLock', PrintConv => \%offOn,     Unknown => 1}, # CSg4-a
    550 => { Name => 'MovieFocusPointLock',   PrintConv => \%offOn,     Unknown => 1}, # CSf4-c
    563 => { Name => 'MatrixMetering',        PrintConv => { 0 => 'Face Detection Off', 1 => 'Face Detection On' }, Unknown => 1 }, # CSb4
    564 => { Name => 'AF-CFocusDisplay',      PrintConv => \%offOn }, # CSa11c
    565 => { Name => 'FocusPeakingDisplay',   PrintConv => \%offOn, Unknown => 1}, # CSa13a
    567 => { # CSb7
        Name => 'KeepExposure',
        PrintConv => {
            0 => 'Off',
            1 => 'Shutter Speed',
            2 => 'ISO',
        },
    },
    #569  CDd8 (adjust viewfinder/monitor hue, brightness and/or white balance settings)   0=>'No adjustment',  1=>'Adjust'.  Related ontrols & adjustments stored in following dozen bytes or so.
    585 => { Name => 'StarlightView',   PrintConv => \%offOn, Unknown => 1 }, # CSd9
    587 => { # CSd10-a
        Name => 'EVFWarmDisplayMode',
        Unknown => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Mode 1',
            2 => 'Mode 2',
        },
    },
    589 => {  # CSd10-b      values in range -3 to +3
        Name => 'EVFWarmDisplayBrightness',
        Format => 'int8s',
        Unknown => 1,
    },
    591 => { #CSd13
        Name => 'EVFReleaseIndicator',
        Unknown => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Type A (Dark)',
            2 => 'Type B (Border)',
            3 => 'Type C (Sides)',
        },
    },
    601 => { Name => 'MovieApertureLock',     PrintConv => \%offOn,  Unknown => 1 }, # CSg4-b
    607 => { Name => 'FlickAdvanceDirection', PrintConv => {  0 => 'Left to Right', 1 => 'Right to Left' },  Unknown => 1 }, # CSf11-c
);

# Z9 custom settings (ref 1)   #base at offset26 + 1095 (firmware 4.0)
%Image::ExifTool::NikonCustom::SettingsZ9v4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    DATAMEMBER => [ 185, 553 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the Z9.',
    1 => {
        Name => 'CustomSettingsBank',
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    3 => { # CSa1
        Name => 'AF-CPrioritySelection',
        PrintConv => {
            0 => 'Release',
            1 => 'Release + Focus',
            3 => 'Focus',
        },
    },
    5 => { Name => 'AF-SPrioritySelection', PrintConv => {0 => 'Release',1 => 'Focus'}},  #CSa2
    7 => { # CSa3-a                      #when AFAreaMode is 3D-tracking, blocked shot response will be 3, regardless of this setting
        Name => 'BlockShotAFResponse',
        PrintConv => {
            1 => '1 (Quick)',
            2 => '2',
            3 => '3 (Normal)',
            4 => '4',
            5 => '5 (Delayed)',
        },
    },
    11 => {Name => 'AFPointSel',PrintConv => { 0 => 'Use All',1 => 'Use Half' }},    # CSa4
    13 => { # CSa5
        Name => 'StoreByOrientation',
        PrintConv => {
            0 => 'Off',
            1 => 'Focus Point',
            2 => 'Focus Point and AF-area mode',
        },
    },
    15 => { Name => 'AFActivation',                 PrintConv => {0 => 'AF-On Only', 1 => 'Shutter/AF-On'}},     # CSa6-a
    16 => { Name => 'AF-OnOutOfFocusRelease',       PrintConv => {0 => 'Disable', 1 => 'Enable'}, Unknown => 1},  # CSa6-b
    17 => { Name => 'LimitAF-AreaModeSelPinpoint',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    19 => { Name => 'LimitAF-AreaModeSelWideAF_S',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    20 => { Name => 'LimitAF-AreaModeSelWideAF_L',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    21 => { Name => 'LimitAFAreaModeSelAuto',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8     #left out hypen to retain compatibility with tag name in NikonSettings
    22 => { Name => 'FocusPointWrap',               PrintConv => { 0 => 'No Wrap', 1 => 'Wrap' }, Unknown => 1 }, # CSa10
    23 => { Name => 'ManualFocusPointIllumination', PrintConv => {0 => 'On During Focus Point Selection Only', 1 => 'On', }, Unknown => 1 },  # CSa11a
    24 => { Name => 'DynamicAreaAFAssist',     PrintConv => { 0 => 'Focus Point Only',1 => 'Focus and Surrounding Points',}, Unknown => 1 },  # CSa11b
    25 => { Name => 'AF-AssistIlluminator',    PrintConv => \%offOn }, # CSa12
    26 => { Name => 'ManualFocusRingInAFMode', PrintConv => \%offOn }, # CSa14
    27 => { Name => 'ExposureControlStepSize', PrintConv => \%thirdHalfFull },     # CSb2
    29 => { # CSb3
        Name => 'EasyExposureCompensation',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (auto reset)',
        },
    },
    31 => { # CSb5
        Name => 'CenterWeightedAreaSize',
        PrintConv => {
            0 => '8 mm',
            1 => '12 mm',
            4 => 'Average',
        },
    },
    33 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    35 => { # CSb6-b
        Name => 'FineTuneOptCenterWeighted',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    37 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    39 => { # CSb6-d
        Name => 'FineTuneOptHighlightWeighted',
        Format => 'int8s',
        ValueConv => '$val / 6',
        ValueConvInv => 'int($val*6)',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    41 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        PrintConv => {
            0 => 'Off',
            1 => 'On (Half Press)',
            2 => 'On (Burst Mode)',
        },
    },
    43 => { # CSc3-a
        Name => 'SelfTimerTime',
        PrintConv => {
            0 => '2 s',
            1 => '5 s',
            2 => '10 s',
            3 => '20 s',
        },
    },
    45 => { Name => 'SelfTimerShotCount',  }, # CSc3-b   1-9
    49 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        PrintConv => {
            0 => '0.5 s',
            1 => '1 s',
            2 => '2 s',
            3 => '3 s',
        },
    },
    51 => { Name => 'PlaybackMonitorOffTime',    %powerOffDelayTimesZ9 }, # CSc4-a
    53 => { Name => 'MenuMonitorOffTime',        %powerOffDelayTimesZ9 }, # CSc4-b
    55 => { Name => 'ShootingInfoMonitorOffTime',%powerOffDelayTimesZ9 }, # CSc4-c
    57 => { Name => 'ImageReviewMonitorOffTime', %powerOffDelayTimesZ9 }, # CSc4-d
    59 => { Name => 'CLModeShootingSpeed',       ValueConv => '$val + 1', ValueConvInv => '$val - 1', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1b
    61 => {  # CSd2       # values: 1-200 &  'No Limit'
        Name => 'MaxContinuousRelease',
        Format => 'int16s',
        ValueConv => '($val eq -1 ?  \'No Limit\' : $val ) ',
    },
    65 => { Name => 'SyncReleaseMode',                PrintConv => { 0 => 'No Sync', 1 => 'Sync' }, Unknown => 1 }, # CSd4
    69 => { Name => 'LimitSelectableImageAreaDX',     PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-1
    70 => { Name => 'LimitSelectableImageArea1To1',   PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-2
    71 => { Name => 'LimitSelectableImageArea16To9',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSd6-3
    72 => { Name => 'FileNumberSequence',             PrintConv => \%offOn }, # CSd7
    73 => { #CSa13b
        Name => 'FocusPeakingLevel',
        Unknown => 1,
        PrintConv => {
            0 => 'High Sensitivity',
            1 => 'Standard Sensitivity',
            2 => 'Low Sensitivity',
        },
    },
    75 => { #CSa13c
        Name => 'FocusPeakingHighlightColor',
        Unknown => 1,
        PrintConv => {
            0 => 'Red',
            1 => 'Yellow',
            2 => 'Blue',
            3 => 'White',
        },
    },
    81 => { Name => 'ContinuousModeDisplay',  PrintConv => \%offOn }, # CSd12
    83 => { # CSe1-a            Previous cameras reported this with HighSpeedSync indicator appended as '(Auto FP)'.  Z9 separated the 2 fields.
        Name => 'FlashSyncSpeed',
        ValueConv => '($val-144)/8',
        PrintConv => {
            0 => '1/60 s',
            1 => '1/80 s',
            2 => '1/100 s',
            3 => '1/125 s',
            4 => '1/160 s',
            5 => '1/200 s',
            6 => '1/250 s',
        },
    },
    85 => { Name => 'HighSpeedSync',          PrintConv => \%offOn }, # CSe1-b
    87 => { # CSe2
        Name => 'FlashShutterSpeed',
        ValueConv => 'my $t = ($val - 16) % 24; $t ? $val / 24  : 2 + ($val - 16) / 24',     #unusual decode perhaps due to need to accommodate 4 new values?
        PrintConv => {
            0 => '1 s',
            1 => '1/2 s',
            2 => '1/4 s',
            3 => '1/8 s',
            4 => '1/15 s',
            5 => '1/30 s',
            6 => '1/60 s',
            7 => '30 s',
            8 => '15 s',
            9 => '8 s',
            10 => '4 s',
            11 => '2 s',
        },
    },
    89 => { Name => 'FlashExposureCompArea',   PrintConv => { 0 => 'Entire Frame', 1 => 'Background Only' } }, # CSe3
    91 => { Name => 'AutoFlashISOSensitivity', PrintConv => { 0 => 'Subject and Background',1 => 'Subject Only'} }, # CSe4
    93 => { Name => 'ModelingFlash',           PrintConv => \%offOn }, # CSe5
    95 => { # CSe6
        Name => 'AutoBracketModeM',
        PrintConv => {
            0 => 'Flash/Speed',
            1 => 'Flash/Speed/Aperture',
            2 => 'Flash/Aperture',
            3 => 'Flash Only',
            4 => 'Flash/ISO',
        },
    },
    97 => { Name => 'AutoBracketOrder',   PrintConv => { 0 => '0,-,+',1 => '-,0,+' } }, # CSe7
    99 => { Name => 'Func1Button',        %buttonsZ9}, # CSf2-a
    #101 Func1Button submenu: Preview               0 => 'Press To Recall', 1=> 'Hold To Recall'  # CSf2-a
    #103 Func1Button submenu: AreaMode              0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-a
    #105 Func1Button submenu: AreaMode+AF-On        0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-a
    #109 Func1Button submenu: SynchronizedRelease   1=>'Master', 2=>'Remote'  # CSf2-a
    #111 Func1Button submenu: Zoom                  0=>'Zoom (Low)', 2=>'Zoom (1:1)', 2=>'Zoom (High)'  # CSf2-a
    #113 Func1Button & Func1ButtonPlayback submenu: Rating                # CSf2-a & CSf3a   0=>'Candidate For Deletion'  6=>''None'
    115 => { Name => 'Func2Button',       %buttonsZ9}, # CSf2-b
    #117 Func2Button submenu: Preview               0 => 'Press To Recall', 1=> 'Hold To Recall' # CSf2-b
    #119 Func2Button submenu: AreaMode              0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-b
    #121 Func2Button submenu: AreaMode+AF-On        0-7 => S, Dyn-S, Dyn-M, Dyn-L, Wide-S, Wide-L, 3D, Auto; 11=>n/a  # CSf2-b
    #125 Func2Button submenu: SynchronizedRelease   1=>'Master', 2=>'Remote'  # CSf2-b
    #127 Func2Button submenu: Zoom                  0=>'Zoom (Low)', 2=>'Zoom (1:1)', 2=>'Zoom (High)'  # CSf2-b
    #129 Func2Button & Func2ButtonPlayback submenu: Rating                # CSf2-b & CSf3b   0=>'Candidate For Deletion'  6=>''None'
    131 => { Name => 'AFOnButton',                %buttonsZ9}, # CSf2-c
    143 => { Name => 'SubSelector',               %buttonsZ9, Unknown => 1}, # CSf2-g
    155 => { Name => 'AssignMovieRecordButton',   %buttonsZ9, Unknown => 1}, # CSf2-m
    159 => { Name => 'LensFunc1Button',           %buttonsZ9}, # CSf2-o
    167 => { Name => 'LensFunc2Button',           %buttonsZ9}, # CSf2-p
    173 => { # CSf2-q
        Name => 'LensControlRing',
        PrintConv => {
            0 => 'None (Disabled)',
            1 => 'Focus (M/A)',
            2 => 'ISO Sensitivity',
            3 => 'Exposure Compensation',
            4 => 'Aperture',
        },
    },
    175 => { Name => 'MultiSelectorShootMode',     %buttonsZ9}, # CSf2-h    called the OK button in camera, tag name retained for compatibility
    179 => { Name => 'MultiSelectorPlaybackMode',  %buttonsZ9}, # CSf3f
    183 => { Name => 'ShutterSpeedLock',           PrintConv => \%offOn }, # CSf4-a
    184 => { Name => 'ApertureLock',               PrintConv => \%offOn }, # CSf4-b
    185 => { # CSf5-a Previous cameras reported this tag as part of CmdDialsReverseRotation.  Blend with CSf5-b separate settings together to match extant tag name and values
        Name => 'CmdDialsReverseRotExposureComp',
        RawConv => '$$self{CmdDialsReverseRotExposureComp} = $val',
        Hidden => 1,
    },
    186 => [{ # CSf5-a  (continued from above)
        Name => 'CmdDialsReverseRotation',
        Condition => '$$self{CmdDialsReverseRotExposureComp} == 0',
        PrintConv => {
            0 => 'No',
            1 => 'Shutter Speed & Aperture',
        },
    },{
        Name => 'CmdDialsReverseRotation',
        PrintConv => {
            0 => 'Exposure Compensation',
            1 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    }],
    191 => { Name => 'UseDialWithoutHold',  PrintConv => \%offOn, Unknown => 1 }, # CSf6
    193 => { Name => 'ReverseIndicators',   PrintConv => { 0 => '+ 0 -', 1 => '- 0 +' }, Unknown => 1 }, # CSf7
    195 => { Name => 'MovieFunc1Button',    %buttonsZ9}, # CSg2-a
    199 => { Name => 'MovieFunc2Button',    %buttonsZ9}, # CSg2-b
    203 => { Name => 'MovieAF-OnButton',    %buttonsZ9}, # CSg2-f
    207 => { Name => 'MovieMultiSelector',  %buttonsZ9, Unknown => 1}, # CSg2-h
    215 => { # CSg2-z
        Name => 'MovieLensControlRing',
        PrintConv => {
            0 => 'None (Disabled)',
            2 => 'ISO Sensitivity',
            3 => 'Exposure Compensation',
            4 => 'Power Aperture',
            5 => 'Hi-Res Zoom',
        },
    },
    221 => { Name => 'MovieAFSpeed',        ValueConv => '$val - 5', ValueConvInv => '$val + 5' }, # CSg6-a
    223 => { Name => 'MovieAFSpeedApply',   PrintConv => {0 => 'Always', 1 => 'Only During Recording'},}, # CSg6-b
    225 => { # CSg7
        Name => 'MovieAFTrackingSensitivity',
        PrintConv => {
            0 => '1 (High)',
            1 => '2',
            2 => '3',
            3 => '4 (Normal)',
            4 => '5',
            5 => '6',
            6 => '7 (Low)',
        },
    },
    279 => { Name => 'LCDIllumination',           PrintConv => \%offOn, Unknown => 1 }, # CSd11
    280 => { Name => 'ExtendedShutterSpeeds',     PrintConv => \%offOn }, # CSd5
    281 => { Name => 'SubjectMotion',             PrintConv => {0 => 'Erratic', 1 => 'Steady'} },  # CSa3-b
    283 => { Name => 'FocusPointPersistence',     PrintConv => {0 => 'Auto', 1 => 'Off'} }, # CSa7
    285 => { Name => 'AutoFocusModeRestrictions', PrintConv => \%focusModeRestrictionsZ9, Unknown => 1},  # CSa9
    289 => { Name => 'CHModeShootingSpeed',       ValueConv => '$val + 1', ValueConvInv => '$val - 1', PrintConv => '"$val fps"', PrintConvInv => '$val=~s/\s*fps//i; $val' }, # CSd1a
    293.1 => { Name => 'LimitReleaseModeSelCL',   Mask => 0x02, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-a
    293.2 => { Name => 'LimitReleaseModeSelCH',   Mask => 0x04, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-b
    293.3 => { Name => 'LimitReleaseModeSelC30',  Mask => 0x10, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-e
    293.4 => { Name => 'LimitReleaseModeSelC120', Mask => 0x40, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-c
    293.5 => { Name => 'LimitReleaseModeSelSelf', Mask => 0x80, PrintConv => \%limitNolimit, Unknown => 1 }, # CSd3-d
    297 => { Name => 'FlashBurstPriority',            PrintConv => { 0 => 'Frame Rate',1 => 'Exposure'}, Unknown => 1 },  # CSe8
    301 => { Name => 'VerticalFuncButton',            %buttonsZ9}, # CSf2-c
    305 => { Name => 'Func3Button',                   %buttonsZ9}, # CSf2-c
    309 => { Name => 'VerticalAFOnButton',            %buttonsZ9}, # CSf2-l
    317 => { Name => 'VerticalMultiSelectorPlaybackMode',  PrintConv => { 0 => 'Image Scroll L/R', 1 => 'Image Scroll Up/Down' }, Unknown => 1}, # CSf3-j
    319 => { Name => 'MovieFunc3Button',                   %buttonsZ9}, # CSg2-c
    359 => { Name => 'LimitAF-AreaModeSelDynamic_S',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    360 => { Name => 'LimitAF-AreaModeSelDynamic_M',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    361 => { Name => 'LimitAF-AreaModeSelDynamic_L',       PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    363 => { Name => 'LimitAF-AreaModeSel3DTracking',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSa8
    365 => { Name => 'PlaybackFlickUp',     PrintConv => \%flicksZ9, Unknown => 1}, # CSf11-a
    369 => { Name => 'PlaybackFlickDown',   PrintConv => \%flicksZ9, Unknown => 1}, # CSf11-b
    373 => { Name => 'ISOStepSize',         PrintConv => \%thirdHalfFull },     # CSb1
    379 => { Name => 'ReverseFocusRing',    PrintConv => { 0 => 'Not Reversed', 1 => 'Reversed' } }, # CSf8
    380 => { Name => 'EVFImageFrame',       PrintConv => \%offOn, Unknown => 1 }, # CSd14
    381 => { Name => 'EVFGrid',             PrintConv => \%evfGridsZ9, Unknown => 1 }, # CSd15
    383 => { Name => 'VirtualHorizonStyle', PrintConv => {0 => 'Type A (Cockpit)', 1 => 'Type B (Sides)' }, Unknown => 1}, #CSd16
    397 => { Name => 'Func4Button',         %buttonsZ9, Unknown => 1}, # CSf2-e
    403 => { Name => 'AudioButton',         %buttonsZ9, Unknown => 1}, # CSf2-i
    405 => { Name => 'QualityButton',       %buttonsZ9, Unknown => 1}, # CSf2-j
    423 => { Name => 'VerticalMultiSelector',          %buttonsZ9, Unknown => 1}, # CSf2-k
    445 => { Name => 'Func1ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-a
    447 => { Name => 'Func2ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-b
    449 => { Name => 'Func3ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-c
    455 => { Name => 'Func4ButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-e
    461 => { Name => 'MovieRecordButtonPlaybackMode',  %buttonsZ9, Unknown => 1}, # CSf3-m
    463 => { Name => 'VerticalFuncButtonPlaybackMode', %buttonsZ9, Unknown => 1}, # CSf3-d
    465 => { Name => 'AudioButtonPlaybackMode',        %buttonsZ9, Unknown => 1}, # CSf3-g
    471 => { Name => 'QualityButtonPlaybackMode',      %buttonsZ9, Unknown => 1}, # CSf3-h
    477 => { Name => 'WhiteBalanceButtonPlaybackMode', %buttonsZ9, Unknown => 1}, # CSf3-i
    483 => { Name => 'CommandDialPlaybackMode',        PrintConv => \%dialsZ9,   Unknown => 1}, # CSf3-k
    485 => { # CSf3-m2
        Name => 'CommandDialVideoPlaybackMode',
        Condition => '$$self{FirmwareVersion} and $$self{FirmwareVersion} ge "05.00"',
        PrintConv => \%dialsVideoZ9,
        Unknown => 1
    },
    487 => { Name => 'SubCommandDialPlaybackMode',     PrintConv => \%dialsZ9,   Unknown => 1}, # CSf3-l
    489 => { # CSf3-n2
        Name => 'SubCommandDialVideoPlaybackMode',
        Condition => '$$self{FirmwareVersion} and $$self{FirmwareVersion} ge "05.00"',
        PrintConv => \%dialsVideoZ9,
        Unknown => 1
    },
    491 => { Name => 'FocusPointLock',                 PrintConv => \%offOn,     Unknown => 1}, # CSf4-c
    493 => { Name => 'ControlRingResponse',            PrintConv => { 0 => 'High', 1 => 'Low' } }, # CSf10
    505 => { Name => 'VerticalMovieFuncButton',        %buttonsZ9, Unknown => 1}, # CSg2-d
    529 => { Name => 'VerticalMovieAFOnButton',        %buttonsZ9, Unknown => 1}, # CSg2-l
    539 => { Name => 'MovieAFAreaMode',       %buttonsZ9, Unknown => 1}, # CSg2-e
    #545 => { Name => 'MovieLimitAF-AreaModeSelWideAF_S',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-a
    #546 => { Name => 'MovieLimitAF-AreaModeSelWideAF_W',      PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-b
    #547 => { Name => 'MovieLimitAF-AreaModeSelSubjectTrack',  PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-c
    #548 => { Name => 'MovieLimitAFAreaModeSelAuto',           PrintConv => \%limitNolimit, Unknown => 1 }, # CSg4-d
    #549 => { Name => 'MovieAutoFocusModeRestrictions', PrintConv => \%focusModeRestrictionsZ9, Unknown => 1},  # CSa9
    551 => { Name => 'HDMIViewAssist', PrintConv => \%offOn, Unknown => 1 }, # CSg12
    553 => { # CSg13-a
        Name => 'ZebraPatternToneRange',
        Unknown => 1,
        RawConv => '$$self{ZebraPatternToneRange} = $val',
        PrintConv => {
            0 => 'Off',
            1 => 'Highlights',
            2 => 'Midtones',
        },
    },
    555 => { Name => 'MovieZebraPattern',              Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} != 0', PrintConv => {0 => 'Pattern 1', 1 => 'Pattern 2'}, Unknown => 1}, # CSg13-b
    557 => { Name => 'MovieHighlightDisplayThreshold', Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 1', Unknown => 1 }, # CSg13-c   120-25  when highlights are the selected tone range
    559 => { Name => 'MovieMidtoneDisplayValue',       Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 2', Unknown => 1 }, # CSg13-d1     when midtones are the selected tone range
    561 => { Name => 'MovieMidtoneDisplayRange',       Condition => '$$self{ZebraPatternToneRange} and $$self{ZebraPatternToneRange} == 2', PrintConv => '"+/-$val"', Unknown => 1 }, # CSg13-d2     when midtones are the selected tone range
    #563 CS g-14 LimitZebraPatternToneRange  0=>'No Restrictions', 1=> 'Highlights', 2=> 'Midtones'
    565 => { Name => 'MovieEVFGrid',          PrintConv => \%evfGridsZ9, Unknown => 1 }, # CSg15
    573 => { Name => 'MovieShutterSpeedLock', PrintConv => \%offOn,     Unknown => 1}, # CSg3-a
    574 => { Name => 'MovieFocusPointLock',   PrintConv => \%offOn,     Unknown => 1}, # CSg3-c
    587 => { Name => 'MatrixMetering',        PrintConv => { 0 => 'Face Detection Off', 1 => 'Face Detection On' }, Unknown => 1 }, # CSb4
    588 => { Name => 'AF-CFocusDisplay',      PrintConv => \%offOn }, # CSa11c
    589 => { Name => 'FocusPeakingDisplay',   PrintConv => \%offOn, Unknown => 1}, # CSa13a
    591 => { # CSb7
        Name => 'KeepExposure',
        PrintConv => {
            0 => 'Off',
            1 => 'Shutter Speed',
            2 => 'ISO',
        },
    },
    #593  CSd (adjust viewfinder/monitor hue, brightness and/or white balance settings)   0=>'No adjustment',  1=>'Adjust'.  Related ontrols & adjustments stored in following dozen bytes or so.
    609 => { Name => 'StarlightView',   PrintConv => \%offOn, Unknown => 1 }, # CSd11
    611 => { # CSd12-a
        Name => 'EVFWarmDisplayMode',
        Unknown => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Mode 1',
            2 => 'Mode 2',
        },
    },
    613 => {  # CSd12-b      values in range -3 to +3
        Name => 'EVFWarmDisplayBrightness',
        Format => 'int8s',
        Unknown => 1,
    },
    615 => { #CSd15
        Name => 'EVFReleaseIndicator',
        Unknown => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Type A (Dark)',
            2 => 'Type B (Border)',
            3 => 'Type C (Sides)',
        },
    },
    625 => { Name => 'MovieApertureLock',     PrintConv => \%offOn,  Unknown => 1 }, # CSg3-b
    631 => { Name => 'FlickAdvanceDirection', PrintConv => {  0 => 'Left to Right', 1 => 'Right to Left' },  Unknown => 1 }, # CSf13-c
);
1;  # end

__END__

=head1 NAME

Image::ExifTool::NikonCustom - Read and Write Nikon custom settings

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

The Nikon custom functions are very specific to the camera model (and
sometimes even change with firmware version).  The information is stored as
unformatted binary data in the ShotInfo record of the Nikon MakerNotes.
This module contains the definitions necessary for Image::ExifTool to decode
this information.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Jens Duttke and Warren Hatch for their help decoding the D300, D3
and Z9 custom settings.  And thanks to the customer service personnel at
Best Buy for not bugging me while I spent lots of time playing with their
cameras.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
