#------------------------------------------------------------------------------
# File:         NikonCustom.pm
#
# Description:  Read and write Nikon Custom settings
#
# Revisions:    2009/11/25 - P. Harvey Created
#
# References:   1) Warren Hatch private communication (D3 with SB-800 and SB-900)
#               2) Anonymous contribution 2011/05/25 (D700, D7000)
#              JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::NikonCustom;

use strict;
use vars qw($VERSION);

$VERSION = '1.13';

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
        PrintConv => {
            0x00 => 'On',
            0x80 => 'Off',
        },
    },
    0.2 => { # CS4
        Name => 'AFAssist',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'On',
            0x40 => 'Off',
        },
    },
    0.3 => { # CS5
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    0.4 => { # CS6
        Name => 'ImageReview',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'On',
            0x10 => 'Off',
        },
    },
    0.5 => { # CS17
        Name => 'Illumination',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'On',
        },
    },
    0.6 => { # CS11
        Name => 'MainDialExposureComp',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Off',
            0x04 => 'On',
        },
    },
    0.7 => { # CS10
        Name => 'EVStepSize',
        Mask => 0x01,
        PrintConv => {
            0x00 => '1/3 EV',
            0x01 => '1/2 EV',
        },
    },
    1.1 => { # CS7
        Name => 'AutoISO',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    1.2 => { # CS7-a
        Name => 'AutoISOMax',
        Mask => 0x30,
        PrintConv => {
            0x00 => 200,
            0x10 => 400,
            0x20 => 800,
            0x30 => 1600,
        },
    },
    1.3 => { # CS7-b
        Name => 'AutoISOMinShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/125 s',
            0x01 => '1/100 s',
            0x02 => '1/80 s',
            0x03 => '1/60 s',
            0x04 => '1/40 s',
            0x05 => '1/30 s',
            0x06 => '1/15 s',
            0x07 => '1/8 s',
            0x08 => '1/4 s',
            0x09 => '1/2 s',
            0x0a => '1 s',
        },
    },
    2.1 => { # CS13
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'AE & Flash',
            0x40 => 'AE Only',
            0x80 => 'Flash Only',
            0xc0 => 'WB Bracketing',
        },
    },
    2.2 => { # CS14
        Name => 'AutoBracketOrder',
        Mask => 0x20,
        PrintConv => {
            0x00 => '0,-,+',
            0x20 => '-,0,+',
        },
    },
    3.1 => { # CS27
        Name => 'MonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '5 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    3.2 => { # CS28
        Name => 'MeteringTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '6 s',
            0x08 => '8 s',
            0x0c => '16 s',
            0x10 => '30 s',
            0x14 => '30 min',
        },
    },
    3.3 => { # CS29
        Name => 'SelfTimerTime',
        Mask => 0x03,
        PrintConv => {
            0x00 => '2 s',
            0x01 => '5 s',
            0x02 => '10 s',
            0x03 => '20 s',
        },
    },
    4.1 => { # CS18
        Name => 'AELockButton',
        Mask => 0x1e,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x02 => 'AE Lock Only',
            0x04 => 'AF Lock Only',
            0x06 => 'AE Lock (hold)',
            0x08 => 'AF-ON',
            0x0a => 'FV Lock',
            0x0c => 'Focus Area Selection',
            0x0e => 'AE-L/AF-L/AF Area',
            0x10 => 'AE-L/AF Area',
            0x12 => 'AF-L/AF Area',
            0x14 => 'AF-ON/AF Area',
        },
    },
    4.2 => { # CS19
        Name => 'AELock',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
        },
    },
    4.3 => { # CS30
        Name => 'RemoteOnDuration',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1 min',
            0x40 => '5 min',
            0x80 => '10 min',
            0xc0 => '15 min',
        },
    },
    5.1 => { # CS15
        Name => 'CommandDials',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Standard (Main Shutter, Sub Aperture)',
            0x80 => 'Reversed (Main Aperture, Sub Shutter)',
        },
    },
    5.2 => { # CS16
        Name => 'FunctionButton',
        Mask => 0x78,
        PrintConv => {
            0x00 => 'ISO Display',
            0x08 => 'Framing Grid',
            0x10 => 'AF-area Mode',
            0x18 => 'Center AF Area',
            0x20 => 'FV Lock',
            0x28 => 'Flash Off',
            0x30 => 'Matrix Metering',
            0x38 => 'Center-weighted',
            0x40 => 'Spot Metering',
        },
    },
    6.1 => { # CS8
        Name => 'GridDisplay',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    6.2 => { # CS9
        Name => 'ViewfinderWarning',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'On',
            0x40 => 'Off',
        },
    },
    6.3 => { # CS12
        Name => 'CenterWeightedAreaSize',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '6 mm',
            0x04 => '8 mm',
            0x08 => '10 mm',
        },
    },
    6.4 => { # CS31
        Name => 'ExposureDelayMode',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Off',
            0x20 => 'On',
        },
    },
    6.5 => { # CS32
        Name => 'MB-D80Batteries',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'LR6 (AA Alkaline)',
            0x01 => 'HR6 (AA Ni-MH)',
            0x02 => 'FR6 (AA Lithium)',
            0x03 => 'ZR6 (AA Ni-Mg)',
        },
    },
    7.1 => { # CS23
        Name => 'FlashWarning',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'On',
            0x80 => 'Off',
        },
    },
    7.2 => { # CS24
        Name => 'FlashShutterSpeed',
        Mask => 0x78,
        ValueConv => '2 ** (($val >> 3) - 6)',
        ValueConvInv => '$val>0 ? int(log($val)/log(2)+6+0.5) << 3 : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    7.3 => { # CS25
        Name => 'AutoFP',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Off',
            0x04 => 'On',
        },
    },
    7.4 => { # CS26
        Name => 'ModelingFlash',
        Mask => 0x02,
        PrintConv => {
            0x00 => 'Off',
            0x02 => 'On',
        },
    },
    8.1 => { # CS22
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
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
        ValueConv => '2 ** (-($val>>4)-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5)<<4 : 0',
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
        ValueConv => 'my $v=($val>>4); $v < 10 ? $v + 1 : 10 * ($v - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5) << 4',
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
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Off',
        },
    },
    11.2 => { # CS22-h
        Name => 'CommanderGroupAMode',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'TTL',
            0x10 => 'Auto Aperture',
            0x20 => 'Manual',
            0x30 => 'Off',
        },
    },
    11.3 => { # CS22-k
        Name => 'CommanderGroupBMode',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'TTL',
            0x04 => 'Auto Aperture',
            0x08 => 'Manual',
            0x0c => 'Off',
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
        ValueConv => '2 ** (-($val>>5))',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)+0.5) << 5 : 0',
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
        ValueConv => '2 ** (-($val>>5))',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)+0.5) << 5 : 0',
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
        ValueConv => '2 ** (-($val>>5))',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)+0.5) << 5 : 0',
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
            0x00 => 'Normal Zone',
            0x80 => 'Wide Zone',
        },
    },
    15.2 => { # CS20
        Name => 'FocusAreaSelection',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'No Wrap',
            0x04 => 'Wrap',
        },
    },
    15.3 => { # CS21
        Name => 'AFAreaIllumination',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Auto',
            0x01 => 'Off',
            0x02 => 'On',
        },
    },
    16.1 => { # CS2
        Name => 'AFAreaModeSetting',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Single Area',
            0x40 => 'Dynamic Area',
            0x80 => 'Auto-area',
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
        PrintConv => {
            0x00 => 'On',
            0x80 => 'Off',
        },
    },
    0.2 => { # CS9
        Name => 'AFAssist',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'On',
            0x40 => 'Off',
        },
    },
    0.3 => { # CS6
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    0.4 => { # CS7
        Name => 'ImageReview',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'On',
            0x10 => 'Off',
        },
    },
    1.1 => { # CS10-a
        Name => 'AutoISO',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    1.2 => { # CS10-b
        Name => 'AutoISOMax',
        Mask => 0x30,
        PrintConv => {
            0x10 => 400,
            0x20 => 800,
            0x30 => 1600,
        },
    },
    1.3 => { # CS10-c
        Name => 'AutoISOMinShutterSpeed',
        Mask => 0x07,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/125 s',
            0x01 => '1/60 s',
            0x02 => '1/30 s',
            0x03 => '1/15 s',
            0x04 => '1/8 s',
            0x05 => '1/4 s',
            0x06 => '1/2 s',
            0x07 => '1 s',
        },
    },
    2.1 => { # CS15-b
        Name => 'ImageReviewTime',
        Mask => 0x07,
        PrintConv => {
            0x00 => '4 s',
            0x01 => '8 s',
            0x02 => '20 s',
            0x03 => '1 min',
            0x04 => '10 min',
        },
    },
    3.1 => { # CS15-a
        Name => 'MonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '8 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '10 min',
        },
    },
    3.2 => { # CS15-c
        Name => 'MeteringTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '8 s',
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '30 min',
        },
    },
    3.3 => { # CS16
        Name => 'SelfTimerTime',
        Mask => 0x03,
        PrintConv => {
            0x00 => '2 s',
            0x01 => '5 s',
            0x02 => '10 s',
            0x03 => '20 s',
        },
    },
    3.4 => { # CS17
        Name => 'RemoteOnDuration',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1 min',
            0x40 => '5 min',
            0x80 => '10 min',
            0xc0 => '15 min',
        },
    },
    4.1 => { # CS12
        Name => 'AELockButton',
        Mask => 0x0e,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x02 => 'AE Lock Only',
            0x04 => 'AF Lock Only',
            0x06 => 'AE Lock (hold)',
            0x08 => 'AF-ON',
        },
    },
    4.2 => { # CS13
        Name => 'AELock',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
        },
    },
    5.1 => { # CS4
        Name => 'ShootingModeSetting',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'Single Frame',
            0x10 => 'Continuous',
            0x20 => 'Self-timer',
            0x30 => 'Delayed Remote',
            0x40 => 'Quick-response Remote',
        },
    },
    5.2 => { # CS11
        Name => 'TimerFunctionButton',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'Shooting Mode',
            0x01 => 'Image Quality/Size',
            0x02 => 'ISO',
            0x03 => 'White Balance',
            0x04 => 'Self-timer',
        },
    },
    6.1 => { # CS5
        Name => 'Metering',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Matrix',
            0x01 => 'Center-weighted',
            0x02 => 'Spot',
        },
    },
    8.1 => { # CS14-a
        Name => 'InternalFlash',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'TTL',
            0x10 => 'Manual',
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
            0x00 => 'Manual',
            0x40 => 'AF-S',
            0x80 => 'AF-C',
            0xc0 => 'AF-A',
        },
    },
    11.1 => { # CS3
        Name => 'AFAreaModeSetting',
        # (may differ from AFAreaMode for Manual focus)
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Single Area',
            0x10 => 'Dynamic Area',
            0x20 => 'Closest Subject',
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
            0x00 => 'LCD Backlight',
            0x08 => 'LCD Backlight and Shooting Information',
        },
    },
    2.1 => { # CSa1
        Name => 'AFAreaModeSetting',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Single Area',
            0x20 => 'Dynamic Area',
            0x40 => 'Auto-area',
            0x60 => '3D-tracking (11 points)',
        },
    },
    2.2 => { # CSa2
        Name => 'CenterFocusPoint',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'Normal Zone',
            0x10 => 'Wide Zone',
        },
    },
    2.3 => { # CSa3
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    2.4 => { # CSa4
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0x00 => 'Auto',
            0x02 => 'On',
            0x04 => 'Off',
        },
    },
    2.5 => { # CSa5
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    3.1 => { # CSa6
        Name => 'AELockForMB-D80',
        Mask => 0x1c,
        PrintConv => {
            0x00 => 'AE Lock Only',
            0x04 => 'AF Lock Only',
            0x08 => 'AE Lock (hold)',
            0x0c => 'AF-On',
            0x10 => 'FV Lock',
            0x14 => 'Focus Point Selection',
            0x1c => 'AE/AF Lock',
        },
    },
    3.2 => { # CSd12
        Name => 'MB-D80BatteryType',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'LR6 (AA alkaline)',
            0x01 => 'HR6 (AA Ni-MH)',
            0x02 => 'FR6 (AA lithium)',
            0x03 => 'ZR6 (AA Ni-Mn)',
        },
    },
    4.1 => { # CSd1
        Name => 'Beep',
        Mask => 0x40,
        PrintConv => {
            0x40 => 'On',
            0x00 => 'Off',
        },
    },
    4.2 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    4.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Show ISO/Easy ISO',
            0x04 => 'Show ISO Sensitivity',
            0x0c => 'Show Frame Count',
        },
    },
    4.4 => { # CSd4
        Name => 'ViewfinderWarning',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    4.5 => { # CSf6
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    5.1 => { # CSd5
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    5.2 => { # CSd7
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => { 0x00 => 'On', 0x08 => 'Off' },
    },
    5.3 => { # CSd8
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Auto',
            0x80 => 'Manual (dark on light)',
            0xc0 => 'Manual (light on dark)',
        },
    },
    5.4 => { # CSd9
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => { 0x00 => 'Off', 0x20 => 'On' },
    },
    6.1 => { # CSb2
        Name => 'EasyExposureComp',
        Mask => 0x01,
        PrintConv => { 0x00 => 'Off', 0x01 => 'On' },
    },
    6.2 => { # CSf7
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    7.1 => { # CSb1
        Name => 'ExposureControlStepSize',
        Mask => 0x40,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
        },
    },
    8.1 => { # CSb3
        Name => 'CenterWeightedAreaSize',
        Mask => 0x60,
        PrintConv => {
            0x00 => '6 mm',
            0x20 => '8 mm',
            0x40 => '10 mm',
        },
    },
    8.2 => { # CSb4-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb4-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x70 ? $val - 0x100 : $val) / 0x60',
        ValueConvInv => '(int($val*6+($val>0?0.5:-0.5))<<4) & 0xf0',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb4-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
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
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    13.1 => { # CSe4
        Name => 'AutoBracketSet',
        Mask => 0xe0, #(NC)
        PrintConv => {
            0x00 => 'AE & Flash', # default
            0x20 => 'AE Only',
            0x40 => 'Flash Only', #(NC)
            0x60 => 'WB Bracketing', #(NC)
            0x80 => 'Active D-Lighting', #(NC)
        },
    },
    13.2 => { # CSe6
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0x00 => '0,-,+',
            0x10 => '-,0,+',
        },
    },
    14.1 => { # CSf3
        Name => 'FuncButton',
        Mask => 0x78,
        PrintConv => {
            0x08 => 'Framing Grid',
            0x10 => 'AF-area Mode',
            0x18 => 'Center Focus Point',
            0x20 => 'FV Lock', # default
            0x28 => 'Flash Off',
            0x30 => 'Matrix Metering',
            0x38 => 'Center-weighted Metering',
            0x40 => 'Spot Metering',
            0x48 => 'My Menu Top',
            0x50 => '+ NEF (RAW)',
        },
    },
    16.1 => { # CSf2
        Name => 'OKButton',
        Mask => 0x18,
        PrintConv => {
            0x08 => 'Select Center Focus Point',
            0x10 => 'Highlight Active Focus Point',
            0x18 => 'Not Used', #(NC)
            0x00 => 'Not Used', #(NC)
        },
    },
    17.1 => { # CSf4
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x08 => 'AE Lock Only',
            0x10 => 'AF Lock Only', #(NC)
            0x18 => 'AE Lock (hold)', #(NC)
            0x20 => 'AF-ON', #(NC)
            0x28 => 'FV Lock', #(NC)
        },
    },
    18.1 => { # CSf5-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => { 0x00 => 'No', 0x80 => 'Yes' },
    },
    18.2 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    19.1 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0xf0,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '6 s', # default
            0x20 => '8 s',
            0x30 => '16 s',
            0x40 => '30 s',
            0x50 => '1 min',
            0x60 => '5 min',
            0x70 => '10 min',
            0x80 => '30 min',
        },
    },
    19.2 => { # CSc5
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0x00 => '1 min',
            0x01 => '5 min',
            0x02 => '10 min',
            0x03 => '15 min',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s', # default
            0xc0 => '20 s',
        },
    },
    20.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x1e,
        ValueConv => '$val >> 1',
        ValueConvInv => '$val << 1',
    },
    21.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '10 s', # default
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
        },
    },
    21.2 => { # CSc4-d
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s', # default
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s', # default
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '10 s', # default
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s', # default
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    24.1 => { # CSe2-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
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
        ValueConv => '2 ** (-($val>>4)-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5)<<4 : 0',
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
        ValueConv => 'my $v=($val>>4); $v < 10 ? $v + 1 : 10 * ($v - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5) << 4',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    31.1 => { # CSd11
        Name => 'FlashWarning',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'On',
            0x80 => 'Off',
        },
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
        PrintConv => { 0x00 => 'On', 0x20 => 'Off' },
    },
    31.4 => { # CSe5
        Name => 'AutoFP',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
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
            0x00 => 'Face Priority', #(NC)
            0x40 => 'Wide Area',
            0x80 => 'Normal Area',
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
        PrintConv => { 0x00 => 'Yes', 0x80 => 'No' },
    },
    1.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Release',
            0x40 => 'Release + Focus',
            0x80 => 'Focus',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Focus',
            0x20 => 'Release',
        },
    },
    1.3 => { # CSa8
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0x00 => '51 Points',
            0x10 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'DynamicAFArea',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '9 Points',
            0x04 => '21 Points',
            0x08 => '51 Points',
            0x0c => '51 Points (3D-tracking)',
        },
    },
    1.5 => { # CSa4
        Name => 'FocusTrackingLockOn',
        Condition => '$$self{Model} !~ /D3S\b/',
        Notes => 'not D3S',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Long',
            0x01 => 'Normal',
            0x02 => 'Short',
            0x03 => 'Off',
        },
    },
    2.1 => { # CSa5
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Shutter/AF-On',
            0x80 => 'AF-On Only',
        },
    },
    2.2 => { # CSa7
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    2.3 => [ # CSa6
        {
            Name => 'AFPointIllumination',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x60,
            PrintConv => {
                0x00 => 'On in Continuous Shooting and Manual Focusing',
                0x20 => 'On During Manual Focusing',
                0x40 => 'On in Continuous Shooting Modes',
                0x60 => 'Off',
            },
        },
        {
            Name => 'AFPointIllumination',
            Notes => 'D300',
            Mask => 0x06,
            PrintConv => {
                0x00 => 'Auto',
                0x02 => 'Off',
                0x04 => 'On',
            },
        },
    ],
    2.4 => { # CSa6-b (D3, added by firmware update)
        Name => 'AFPointBrightness',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x06,
        PrintConv => {
            0x00 => 'Low',
            0x02 => 'Normal',
            0x04 => 'High',
            0x06 => 'Extra High',
        },
    },
    2.5 => { # CSa9 (D300)
        Name => 'AFAssist',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
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
            0x00 => 'AF On',
            0x10 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x30 => 'AE Lock (reset on release)',
            0x40 => 'AE Lock (hold)',
            0x50 => 'AF Lock Only',
            0x70 => 'Same as AF On',
        },
    },
    3.3 => { # CSa10 (D300)
        Name => 'AF-OnForMB-D10',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'AF-On',
            0x10 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x30 => 'AE Lock (reset on release)',
            0x40 => 'AE Lock (hold)',
            0x50 => 'AF Lock Only',
            0x60 => 'Same as FUNC Button',
        },
    },
    4.1 => { # CSa4 (D3S)
        Name => 'FocusTrackingLockOn',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x07,
        PrintConv => {
            0x00 => '5 (Long)',
            0x01 => '4',
            0x02 => '3 (Normal)',
            0x03 => '2',
            0x04 => '1 (Short)',
            0x05 => 'Off',
        },
    },
    4.2 => { # CSf7 (D3S)
        Name => 'AssignBktButton',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'Auto Bracketing',
            0x08 => 'Multiple Exposure',
        },
    },
    4.3 => { # CSf1-c (D3S) (ref 1)
        Name => 'MultiSelectorLiveView',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Reset',
            0x40 => 'Zoom On/Off',
            0x80 => 'Start Movie Recording',
            0xc0 => 'Not Used',
        },
    },
    4.4 => { # CSf1-c2 (D3S) (ref 1)
        Name => 'InitialZoomLiveView',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Low Magnification',
            0x10 => 'Medium Magnification',
            0x20 => 'High Magnification',
        },
    },
    6.1 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
            0x80 => '1 EV',
        },
    },
    6.2 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0x30,
        PrintConv => {
            0x00 => '1/3 EV',
            0x10 => '1/2 EV',
            0x20 => '1 EV',
        },
    },
    6.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '1/3 EV',
            0x04 => '1/2 EV',
            0x08 => '1 EV',
        },
    },
    6.4 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
            0x02 => 'On (auto reset)',
        },
    },
    7.1 => [ # CSb5
        {
            Name => 'CenterWeightedAreaSize',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xe0,
            PrintConv => {
                0x00 => '8 mm',
                0x20 => '12 mm',
                0x40 => '15 mm',
                0x60 => '20 mm',
                0x80 => 'Average',
            },
        },
        {
            Name => 'CenterWeightedAreaSize',
            Notes => 'D300',
            Mask => 0xe0,
            PrintConv => {
                0x00 => '6 mm',
                0x20 => '8 mm',
                0x40 => '10 mm',
                0x60 => '13 mm',
                0x80 => 'Average',
            },
        },
    ],
    7.2 => { # CSb6-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    8.1 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0xf0,
        ValueConv => '($val > 0x70 ? $val - 0x100 : $val) / 0x60',
        ValueConvInv => '(int($val*6+($val>0?0.5:-0.5))<<4) & 0xf0',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    8.2 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSf1-a, CSf2-a (D300S)
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Select Center Focus Point',
            0x40 => 'Highlight Active Focus Point',
            0x80 => 'Not Used',
        },
    },
    9.2 => { # CSf1-b, CSf2-b (D300S)
        Name => 'MultiSelectorPlaybackMode',
        Condition => '$$self{Model} !~ /D3S\b/',
        Notes => 'all models except D3S', # (not confirmed for D3X)
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Thumbnail On/Off',
            0x10 => 'View Histograms',
            0x20 => 'Zoom On/Off',
            0x30 => 'Choose Folder',
        },
    },
    9.3 => [ # CSf1-b2, CSf2-b2 (D300S)
        {
            Name => 'InitialZoomSetting',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x0c,
            PrintConv => { #1
                0x00 => 'High Magnification',
                0x04 => 'Medium Magnification',
                0x08 => 'Low Magnification',
            },
        },
        {
            Name => 'InitialZoomSetting',
            Notes => 'D300',
            Mask => 0x0c,
            PrintConv => { #JD
                0x00 => 'Low Magnification',
                0x04 => 'Medium Magnification',
                0x08 => 'High Magnification',
            },
        },
    ],
    9.4 => { # CSf2 (D300,D3), CSf3 (D300S)
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Do Nothing',
            0x01 => 'Reset Meter-off Delay',
        },
    },
    10.1 => { # CSd9 (D300,D3S), CSd10 (D300S), CSd8 (D3)
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => { 0x00 => 'Off', 0x40 => 'On' },
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
            0x00 => '9 fps',
            0x10 => '10 fps',
            0x20 => '11 fps',
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
            0x00 => '+ 0 -',
            0x20 => '- 0 +',
        },
    },
    12.2 => [ # CSd6 (D300), CSd7 (D300S), CSd4 (D3)
        {
            Name => 'FileNumberSequence',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0x02,
            PrintConv => { 0x00 => 'On', 0x02 => 'Off' },
        },
        {
            Name => 'FileNumberSequence',
            Notes => 'D300',
            Mask => 0x08,
            PrintConv => { 0x00 => 'On', 0x08 => 'Off' },
        },
    ],
    12.3 => { # CSd5-a (D3)
        Name => 'RearDisplay',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'ISO',
            0x80 => 'Exposures Remaining',
        },
    },
    12.4 => { # CSd5-b (D3)
        Name => 'ViewfinderDisplay',
        Condition => '$$self{Model} =~ /D3[SX]?\b/',
        Notes => 'D3 only',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Frame Count',
            0x40 => 'Exposures Remaining',
        },
    },
    12.5 => { # CSd11 (D300), CSd12 (D300S)
        Name => 'BatteryOrder',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'MB-D10 First',
            0x04 => 'Camera Battery First',
        },
    },
    12.6 => { # CSd10 (D300), CSd11 (D300S)
        Name => 'MB-D10Batteries',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'LR6 (AA alkaline)',
            0x01 => 'HR6 (AA Ni-MH)',
            0x02 => 'FR6 (AA lithium)',
            0x03 => 'ZR6 (AA Ni-Mn)',
        },
    },
    12.7 => { # CSd7 (D3S), CSd4, (D300S)
        Name => 'ScreenTips',
        Condition => '$$self{Model} =~ /(D3S|D300S)\b/',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'On',
            0x10 => 'Off',
        },
    },
    13.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'High',
            0x40 => 'Low',
            0x80 => 'Off',
        },
    },
    13.2 => { # CSd7 (D300), CSd8 (D300S), CSd6 (D3)
        Name => 'ShootingInfoDisplay',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Auto', #JD (D300)
            0x10 => 'Auto', #1 (D3)
            0x20 => 'Manual (dark on light)',
            0x30 => 'Manual (light on dark)',
        },
    },
    13.3 => { # CSd2 (D300)
        Name => 'GridDisplay',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    13.4 => { # CSd3 (D300)
        Name => 'ViewfinderWarning',
        Condition => '$$self{Model} =~ /D300S?\b/',
        Notes => 'D300 only',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    13.5 => { # CSf1-b (D3S) (ref 1)
        Name => 'MultiSelectorPlaybackMode',
        Condition => '$$self{Model} =~ /D3S\b/',
        Notes => 'D3S only',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Thumbnail On/Off',
            0x01 => 'View Histograms',
            0x02 => 'Zoom On/Off',
        },
    },
    14.1 => [ # CSf5-a (ref 1), CSf6-a (D300S)
        {
            Name => 'PreviewButton',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xf8,
            PrintConv => {
                0x00 => 'None',
                0x08 => 'Preview',
                0x10 => 'FV Lock',
                0x18 => 'AE/AF Lock',
                0x20 => 'AE Lock Only',
                0x28 => 'AE Lock (reset on release)',
                0x30 => 'AE Lock (hold)',
                0x38 => 'AF Lock Only',
                0x40 => 'Flash Off',
                0x48 => 'Bracketing Burst',
                0x50 => 'Matrix Metering',
                0x58 => 'Center-weighted Metering',
                0x60 => 'Spot Metering',
                0x68 => 'Virtual Horizon',
                # 0x70 not used
                0x78 => 'Playback',
                0x80 => 'My Menu Top',
            },
        },
        { #PH
            Name => 'FuncButton',
            Notes => 'D300',
            Mask => 0xf8,
            PrintConv => {
                0x00 => 'None',
                0x08 => 'Preview',
                0x10 => 'FV Lock',
                0x18 => 'AE/AF Lock',
                0x20 => 'AE Lock Only',
                0x28 => 'AE Lock (reset on release)',
                0x30 => 'AE Lock (hold)',
                0x38 => 'AF Lock Only',
                # 0x40 not used
                0x48 => 'Flash Off',
                0x50 => 'Bracketing Burst',
                0x58 => 'Matrix Metering',
                0x60 => 'Center-weighted Metering',
                0x68 => 'Spot Metering',
                0x70 => 'Playback', #PH (guess)
                0x78 => 'My Menu Top', #PH (guess)
                0x80 => '+ NEF (RAW)', #PH (guess)
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
                0x00 => 'None',
                0x08 => 'Preview',
                0x10 => 'FV Lock',
                0x18 => 'AE/AF Lock',
                0x20 => 'AE Lock Only',
                0x28 => 'AE Lock (reset on release)',
                0x30 => 'AE Lock (hold)',
                0x38 => 'AF Lock Only',
                0x40 => 'Flash Off',
                0x48 => 'Bracketing Burst',
                0x50 => 'Matrix Metering',
                0x58 => 'Center-weighted Metering',
                0x60 => 'Spot Metering',
                0x68 => 'Virtual Horizon',
                # 0x70 not used
                0x78 => 'Playback',
                0x80 => 'My Menu Top',
            },
        },
        { #PH
            Name => 'PreviewButton',
            Notes => 'D300',
            Mask => 0xf8,
            PrintConv => {
                0x00 => 'None',
                0x08 => 'Preview',
                0x10 => 'FV Lock',
                0x18 => 'AE/AF Lock',
                0x20 => 'AE Lock Only',
                0x28 => 'AE Lock (reset on release)',
                0x30 => 'AE Lock (hold)',
                0x38 => 'AF Lock Only',
                # 0x40 not used
                0x48 => 'Flash Off',
                0x50 => 'Bracketing Burst',
                0x58 => 'Matrix Metering',
                0x60 => 'Center-weighted Metering',
                0x68 => 'Spot Metering',
                0x70 => 'Playback', #PH (guess)
                0x78 => 'My Menu Top', #PH (guess)
                0x80 => '+ NEF (RAW)', #PH (guess)
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
                0x00 => 'None',
                0x08 => 'Preview',
                0x10 => 'FV Lock',
                0x18 => 'AE/AF Lock',
                0x20 => 'AE Lock Only',
                0x28 => 'AE Lock (reset on release)',
                0x30 => 'AE Lock (hold)',
                0x38 => 'AF Lock Only',
                0x40 => 'Flash Off',
                0x48 => 'Bracketing Burst',
                0x50 => 'Matrix Metering',
                0x58 => 'Center-weighted Metering',
                0x60 => 'Spot Metering',
                0x68 => 'Virtual Horizon',
                0x70 => 'AF On', # (AE-L/AF-L button only)
                0x78 => 'Playback',
                0x80 => 'My Menu Top',
            },
        },
        { #PH
            Name => 'AELockButton',
            Notes => 'D300',
            Mask => 0xf8,
            PrintConv => {
                0x00 => 'None',
                0x08 => 'Preview',
                0x10 => 'FV Lock',
                0x18 => 'AE/AF Lock',
                0x20 => 'AE Lock Only',
                0x28 => 'AE Lock (reset on release)',
                0x30 => 'AE Lock (hold)',
                0x38 => 'AF Lock Only',
                0x40 => 'AF On', # (AE-L/AF-L button only)
                0x48 => 'Flash Off',
                0x50 => 'Bracketing Burst',
                0x58 => 'Matrix Metering',
                0x60 => 'Center-weighted Metering',
                0x68 => 'Spot Metering',
                0x70 => 'Playback', #PH (guess)
                0x78 => 'My Menu Top', #PH (guess)
                0x80 => '+ NEF (RAW)', #PH (guess)
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
        PrintConv => { 0x00 => 'No', 0x80 => 'Yes' },
    },
    17.2 => { # CSf7-b, CSf8-b (D3S,D300S)
        Name => 'CommandDialsChangeMainSub',
        Mask => 0x40,
        PrintConv => { 0x00 => 'Off', 0x40 => 'On' },
    },
    17.3 => { # CSf7-c, CSf8-c (D3S,D300S)
        Name => 'CommandDialsApertureSetting',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Sub-command Dial',
            0x20 => 'Aperture Ring',
        },
    },
    17.4 => { # CSf7-d, CSf8-d (D3S,D300S)
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x10,
        PrintConv => { 0x00 => 'Off', 0x10 => 'On' },
    },
    17.5 => { # CSd8 (D300,D3S), CSd9 (D300S), CSd7 (D3)
        Name => 'LCDIllumination',
        Mask => 0x08,
        PrintConv => { 0x00 => 'Off', 0x08 => 'On' },
    },
    17.6 => { # CSf3, CSf4 (D300S)
        Name => 'PhotoInfoPlayback',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Info Up-down, Playback Left-right',
            0x04 => 'Info Left-right, Playback Up-down',
        },
    },
    17.7 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    17.8 => { # CSf8, CSf9 (D3S,D300S)
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => { 0x00 => 'No', 0x01 => 'Yes' },
    },
    18.1 => { # CSc3
        Name => 'SelfTimerTime',
        Mask => 0x18,
        PrintConv => {
            0x00 => '2 s',
            0x08 => '5 s',
            0x10 => '10 s',
            0x18 => '20 s',
        },
    },
    18.2 => { # CSc4
        Name => 'MonitorOffTime',
        # NOTE: The D3S and D300S have separate settings for Playback,
        # Image Review, Menus, and Information Display times
        Mask => 0x07,
        PrintConv => {
            0x00 => '10 s',
            0x01 => '20 s',
            0x02 => '1 min',
            0x03 => '5 min',
            0x04 => '10 min',
        },
    },
    20.1 => [ # CSe1
        {
            Name => 'FlashSyncSpeed',
            Condition => '$$self{Model} =~ /D3[SX]?\b/',
            Notes => 'D3',
            Mask => 0xe0,
            PrintConv => {
                0x00 => '1/250 s (auto FP)',
                0x20 => '1/250 s',
                0x40 => '1/200 s',
                0x60 => '1/160 s',
                0x80 => '1/125 s',
                0xa0 => '1/100 s',
                0xc0 => '1/80 s',
                0xe0 => '1/60 s',
            },
        },
        {
            Name => 'FlashSyncSpeed',
            Notes => 'D300',
            Mask => 0xf0,
            PrintConv => {
                0x00 => '1/320 s (auto FP)',
                0x10 => '1/250 s (auto FP)',
                0x20 => '1/250 s',
                0x30 => '1/200 s',
                0x40 => '1/160 s',
                0x50 => '1/125 s',
                0x60 => '1/100 s',
                0x70 => '1/80 s',
                0x80 => '1/60 s',
            },
        },
    ],
    20.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    21.1 => [{ # CSe5 (D300), CSe4 (D3)
        Name => 'AutoBracketSet',
        Condition => '$$self{Model} !~ /(D3S|D300S)\b/',
        Notes => 'D3 and D300',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'AE & Flash',
            0x40 => 'AE Only',
            0x80 => 'Flash Only',
            0xc0 => 'WB Bracketing',
        },
    },{ # CSe4 (D3S) (NC for D300S)
        Name => 'AutoBracketSet',
        Notes => 'D3S and D300S',
        Mask => 0xe0,
        PrintConv => {
            0x00 => 'AE & Flash',
            0x20 => 'AE Only',
            0x40 => 'Flash Only',
            0x60 => 'WB Bracketing',
            # D3S/D300S have an "ADL Bracketing" setting - PH
            0x80 => 'ADL Bracketing',
        },
    }],
    21.2 => [{ # CSe6 (D300), CSe5 (D3)
        Name => 'AutoBracketModeM',
        Condition => '$$self{Model} !~ /(D3S|D300S)\b/',
        Notes => 'D3 and D300',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x10 => 'Flash/Speed/Aperture',
            0x20 => 'Flash/Aperture',
            0x30 => 'Flash Only',
        },
    },{ # CSe5 (D3S)
        Name => 'AutoBracketModeM',
        Notes => 'D3S and D300S',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x08 => 'Flash/Speed/Aperture',
            0x10 => 'Flash/Aperture',
            0x18 => 'Flash Only',
        },
    }],
    21.3 => [{ # CSe7 (D300), CSe6 (D3)
        Name => 'AutoBracketOrder',
        Condition => '$$self{Model} !~ /(D3S|D300S)\b/',
        Notes => 'D3 and D300',
        Mask => 0x08,
        PrintConv => {
            0x00 => '0,-,+',
            0x08 => '-,0,+',
        },
    },{ # CSe6 (D3S)
        Name => 'AutoBracketOrder',
        Notes => 'D3S and D300S',
        Mask => 0x04,
        PrintConv => {
            0x00 => '0,-,+',
            0x04 => '-,0,+',
        },
    }],
    21.4 => { # CSe4 (D300), CSe3 (D3)
        Name => 'ModelingFlash',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    22.1 => { # CSf9, CSf10 (D3S,D300S)
        Name => 'NoMemoryCard',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Release Locked',
            0x80 => 'Enable Release',
        },
    },
    22.2 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '4 s',
            0x01 => '6 s',
            0x02 => '8 s',
            0x03 => '16 s',
            0x04 => '30 s',
            0x05 => '1 min',
            0x06 => '5 min',
            0x07 => '10 min',
            0x08 => '30 min',
            0x09 => 'No Limit',
        },
    },
    23.1 => { # CSe3
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
        },
    },
    25.1 => { #1 CSc4-d (D3S)
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    25.2 => { #1 CSc4-a (D3S)
        Name => 'PlaybackMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '10 s',
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
        },
    },
    26.1 => { #1 CSc4-b (D3S)
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    26.2 => { #1 CSc4-c (D3S)
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '10 s',
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
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
        PrintConv => { 0x00 => 'Yes', 0x80 => 'No' },
    },
    1.1 => { # CSa1
        Name => 'AF-CPrioritySelection',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Release',
            0x40 => 'Release + Focus',
            0x80 => 'Focus',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Focus',
            0x20 => 'Release',
        },
    },
    1.3 => { # CSa8
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0x00 => '51 Points',
            0x10 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'DynamicAFArea',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '9 Points',
            0x04 => '21 Points',
            0x08 => '51 Points',
            0x0c => '51 Points (3D-tracking)',
        },
    },
    2.1 => { # CSa5
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Shutter/AF-On',
            0x80 => 'AF-On Only',
        },
    },
    2.2 => { # CSa7
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    2.3 => { # CSa6
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0x00 => 'Auto',
            0x02 => 'Off',
            0x04 => 'On',
        },
    },
    2.4 => { # CSa9
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    3.1 => { # CSa4
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0x00 => '3 Normal',
            0x01 => '4',
            0x02 => '5 Long',
            0x03 => '2',
            0x04 => '1 Short',
            0x05 => 'Off',
        },
    },
    3.2 => { # CSa10
        Name => 'AF-OnForMB-D10',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'AF-On',
            0x10 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x30 => 'AE Lock (reset on release)',
            0x40 => 'AE Lock (hold)',
            0x50 => 'AF Lock Only',
            0x60 => 'Same as FUNC Button',
        },
    },
    4.1 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
            0x80 => '1 EV',
        },
    },
    4.2 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0x30,
        PrintConv => {
            0x00 => '1/3 EV',
            0x10 => '1/2 EV',
            0x20 => '1 EV',
        },
    },
    4.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '1/3 EV',
            0x04 => '1/2 EV',
            0x08 => '1 EV',
        },
    },
    4.4 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
            0x02 => 'On (auto reset)',
        },
    },
    5.1 => { # CSb5
        Name => 'CenterWeightedAreaSize',
        Mask => 0x70,
        PrintConv => {
            0x00 => '8 mm',
            0x10 => '12 mm',
            0x20 => '15 mm',
            0x30 => '20 mm',
            0x40 => 'Average',
        },
    },
    6.1 => { # CSb6-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0xf0,
        ValueConv => '($val > 0x70 ? $val - 0x100 : $val) / 0x60',
        ValueConvInv => '(int($val*6+($val>0?0.5:-0.5))<<4) & 0xf0',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    6.2 => { # CSb6-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    7.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x80,
        PrintConv => { 0x00 => 'Off', 0x80 => 'On' },
    },
    7.2 => { # CSc3
        Name => 'SelfTimerTime',
        Mask => 0x30,
        PrintConv => {
            0x00 => '2 s',
            0x10 => '5 s',
            0x20 => '10 s',
            0x30 => '20 s',
        },
    },
    7.3 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '4 s',
            0x01 => '6 s',
            0x02 => '8 s',
            0x03 => '16 s',
            0x04 => '30 s',
            0x05 => '1 min',
            0x06 => '5 min',
            0x07 => '10 min',
            0x08 => '30 min',
            0x09 => 'No Limit',
        },
    },
    8.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0x38,
        PrintConv => {
            0x00 => '4 s',
            0x08 => '10 s',
            0x10 => '20 s',
            0x18 => '1 min',
            0x20 => '5 min',
            0x28 => '10 min',
        },
    },
    8.2 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0x07,
        PrintConv => {
            0x00 => '4 s',
            0x01 => '10 s',
            0x02 => '20 s',
            0x03 => '1 min',
            0x04 => '5 min',
            0x05 => '10 min',
        },
    },
    9.1 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x38,
        PrintConv => {
            0x00 => '4 s',
            0x08 => '10 s',
            0x10 => '20 s',
            0x18 => '1 min',
            0x20 => '5 min',
            0x28 => '10 min',
        },
    },
    9.2 => { # CSc4-d
        Name => 'ImageReviewTime',
        Mask => 0x07,
        PrintConv => {
            0x00 => '4 s',
            0x01 => '10 s',
            0x02 => '20 s',
            0x03 => '1 min',
            0x04 => '5 min',
            0x05 => '10 min',
        },
    },
    10.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'High',
            0x40 => 'Low',
            0x80 => 'Off',
        },
    },
    10.2 => { # CSd7
        Name => 'ShootingInfoDisplay',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Auto', #JD (D300)
            0x10 => 'Auto', #1 (D3)
            0x20 => 'Manual (dark on light)',
            0x30 => 'Manual (light on dark)',
        },
    },
    10.3 => { # CSd8
        Name => 'LCDIllumination',
        Mask => 0x08,
        PrintConv => { 0x00 => 'Off', 0x08 => 'On' },
    },
    10.4 => { # CSd9
        Name => 'ExposureDelayMode',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    10.5 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    11.1 => { # CSd6
        Name => 'FileNumberSequence',
        Mask => 0x40,
        PrintConv => { 0x00 => 'On', 0x40 => 'Off' },
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
        PrintConv => { 0x08 => 'On', 0x00 => 'Off' },
    },
    13.2 => { # CSd11
        Name => 'BatteryOrder',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'MB-D10 First',
            0x04 => 'Camera Battery First',
        },
    },
    13.3 => { # CSd10
        Name => 'MB-D10BatteryType',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'LR6 (AA alkaline)',
            0x01 => 'HR6 (AA Ni-MH)',
            0x02 => 'FR6 (AA lithium)',
            0x03 => 'ZR6 (AA Ni-Mn)',
        },
    },
    15.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '1/320 s (auto FP)',
            0x10 => '1/250 s (auto FP)',
            0x20 => '1/250 s',
            0x30 => '1/200 s',
            0x40 => '1/160 s',
            0x50 => '1/125 s',
            0x60 => '1/100 s',
            0x70 => '1/80 s',
            0x80 => '1/60 s',
       },
    },
    15.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    16.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        # Note If set the Manual, Repeating Flash, Commander Mode
        #      does not decode the detail settings.
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
        },
    },
    16.2 => { # CSe3-b
        Name => 'ManualFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 0x40',
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
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0x70,
        ValueConv => '2 ** (-($val>>4)-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5)<<4 : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    17.2 => { # CSe3-cb
        Name => 'RepeatingFlashCount',
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    18.1 => { # CSe3-cc (NC)
        Name => 'RepeatingFlashRate',
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0xf0,
        ValueConv => 'my $v=($val>>4); $v < 10 ? $v + 1 : 10 * ($v - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5) << 4',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    18.2 => { # CSe3-dd
        Name => 'CommanderInternalTTLChannel',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
        Mask => 0x03,
        PrintConv => {
            0x00 => '1 ch',
            0x01 => '2 ch',
            0x02 => '3 ch',
            0x03 => '4 ch',
        },
    },
    20.1 => { # CSe3-da
        Name => 'CommanderInternalTTLCompBuiltin',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    21.1 => { # CSe3-db
        Name => 'CommanderInternalTTLCompGroupA',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    22.1 => { # CSe3-dc
        Name => 'CommanderInternalTTLCompGroupB',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
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
            0x00 => 'AE & Flash',
            0x40 => 'AE Only',
            0x80 => 'Flash Only',
            0xc0 => 'WB Bracketing',
        },
    },
    26.2 => { # CSe6
        Name => 'AutoBracketModeM',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x10 => 'Flash/Speed/Aperture',
            0x20 => 'Flash/Aperture',
            0x30 => 'Flash Only',
        },
    },
    26.3 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x08,
        PrintConv => {
            0x00 => '0,-,+',
            0x08 => '-,0,+',
        },
    },
    26.4 => { # CSe4
        Name => 'ModelingFlash',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    27.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Select Center Focus Point',
            0x40 => 'Highlight Active Focus Point',
            0x80 => 'Not Used',
        },
    },
    27.2 => { # CSf2-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Thumbnail On/Off',
            0x10 => 'View Histograms',
            0x20 => 'Zoom On/Off',
            0x30 => 'Choose Folder',
        },
    },
    27.3 => { # CSf2-b2
        Name => 'InitialZoomSetting',
        Mask => 0x0c,
        PrintConv => { #1
            0x00 => 'Low Magnification',
            0x04 => 'Medium Magnification',
            0x08 => 'High Magnification',
        },
    },
    27.4 => { # CSf3
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Do Nothing',
            0x01 => 'Reset Meter-off Delay',
        },
    },
    28.1 => { # CSf5-a
        Name => 'FuncButton',
        Mask => 0xf8,
        PrintConv => {
            0x00 => 'None',
            0x08 => 'Preview',
            0x10 => 'FV Lock',
            0x18 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x28 => 'AE Lock (reset on release)',
            0x30 => 'AE Lock (hold)',
            0x38 => 'AF Lock Only',
            # 0x40 not used
            0x48 => 'Flash Off',
            0x50 => 'Bracketing Burst',
            0x58 => 'Matrix Metering',
            0x60 => 'Center-weighted Metering',
            0x68 => 'Spot Metering',
            0x70 => 'My Menu Top',
            0x78 => 'Live View',
            0x80 => '+ NEF (RAW)',
            0x88 => 'Virtual Horizon',
        },
    },
    29.1 => { # CSf6-a
        Name => 'PreviewButton',
        Mask => 0xf8,
        PrintConv => {
            0x00 => 'None',
            0x08 => 'Preview',
            0x10 => 'FV Lock',
            0x18 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x28 => 'AE Lock (reset on release)',
            0x30 => 'AE Lock (hold)',
            0x38 => 'AF Lock Only',
            0x40 => 'AF-ON',
            0x48 => 'Flash Off',
            0x50 => 'Bracketing Burst',
            0x58 => 'Matrix Metering',
            0x60 => 'Center-weighted Metering',
            0x68 => 'Spot Metering',
            0x70 => 'My Menu Top',
            0x78 => 'Live View',
            0x80 => '+ NEF (RAW)',
            0x88 => 'Virtual Horizon',
        },
    },
    30.1 => { # CSf7-a
        Name => 'AELockButton',
        Notes => 'D300',
        Mask => 0xf8,
        PrintConv => {
            0x00 => 'None',
            0x08 => 'Preview',
            0x10 => 'FV Lock',
            0x18 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x28 => 'AE Lock (reset on release)',
            0x30 => 'AE Lock (hold)',
            0x38 => 'AF Lock Only',
            0x40 => 'AF-ON',
            0x48 => 'Flash Off',
            0x50 => 'Bracketing Burst',
            0x58 => 'Matrix Metering',
            0x60 => 'Center-weighted Metering',
            0x68 => 'Spot Metering',
            0x70 => 'My Menu Top',
            0x78 => 'Live View',
            0x80 => '+ NEF (RAW)',
            0x88 => 'Virtual Horizon',
        },
    },
    31.1 => { # CSf5-b
        Name => 'FuncButtonPlusDials',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'None',
            0x10 => 'Choose Image Area',
            0x20 => 'One Step Speed/Aperture',
            0x30 => 'Choose Non-CPU Lens Number',
            # n/a  0x40 => 'Focus Point Selection',
            0x50 => 'Auto bracketing',
            0x60 => 'Dynamic AF Area',
            0x70 => 'Shutter speed & Aperture lock',
        },
    },
    31.2 => { # CSf6-b
        Name => 'PreviewButtonPlusDials',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'None',
            0x01 => 'Choose Image Area',
            0x02 => 'One Step Speed/Aperture',
            0x03 => 'Choose Non-CPU Lens Number',
            # n/a  0x04 => 'Focus Point Selection',
            0x05 => 'Auto bracketing',
            0x06 => 'Dynamic AF Area',
            0x07 => 'Shutter speed & Aperture lock',
        },
    },
    32.1 => { # CSf7-b
        Name => 'AELockButtonPlusDials',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'None',
            0x10 => 'Choose Image Area',
            0x20 => 'One Step Speed/Aperture',
            0x30 => 'Choose Non-CPU Lens Number',
            # n/a  0x40 => 'Focus Point Selection',
            0x50 => 'Auto bracketing',
            0x60 => 'Dynamic AF Area',
            0x70 => 'Shutter speed & Aperture lock',
        },
    },
    33.1 => { # CSf9-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => { 0x00 => 'No', 0x80 => 'Yes' },
    },
    33.2 => { # CSf9-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0x40,
        PrintConv => { 0x00 => 'Off', 0x40 => 'On' },
    },
    33.3 => { # CSf9-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Sub-command Dial',
            0x20 => 'Aperture Ring',
        },
    },
    33.4 => { # CSf9-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x10,
        PrintConv => { 0x00 => 'Off', 0x10 => 'On' },
    },
    33.5 => { # CSf12
        Name => 'ReverseIndicators',
        Mask => 0x08,
        PrintConv => {
            0x00 => '+ 0 -',
            0x08 => '- 0 +',
        },
    },
    33.6 => { # CSf4
        Name => 'PhotoInfoPlayback',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    33.7 => { # CSf11
        Name => 'NoMemoryCard',
        Mask => 0x02,
        PrintConv => {
            0x00 => 'Release Locked',
            0x02 => 'Enable Release',
        },
    },
    33.8 => { # CSf10
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => { 0x00 => 'No', 0x01 => 'Yes' },
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
            0x00 => 'AE & Flash', # default
            0x20 => 'AE Only', #(NC)
            0x40 => 'Flash Only',
            0x60 => 'WB Bracketing', #(NC)
            0x80 => 'Active D-Lighting', #(NC)
        },
    },
    12.2 => { # CSe7
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0x00 => '0,-,+',
            0x10 => '-,0,+',
        },
    },
    12.3 => { # CSe6
        Name => 'AutoBracketingMode',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x04 => 'Flash/Speed/Aperture',
            0x08 => 'Flash/Aperture',
            0x0c => 'Flash Only',
        },
    },
    # 21 - 100 (MaxContinuousRelease?)
    22.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '1/320 s (auto FP)',
            0x10 => '1/250 s (auto FP)',
            0x20 => '1/250 s',
            0x30 => '1/200 s',
            0x40 => '1/160 s',
            0x50 => '1/125 s',
            0x60 => '1/100 s',
            0x70 => '1/80 s',
            0x80 => '1/60 s',
       },
    },
    22.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    23.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
        },
    },
    23.2 => { # CSe3-b
        Name => 'ManualFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 0x40',
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
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0x70,
        ValueConv => '2 ** (-($val>>4)-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5)<<4 : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    24.2 => { # CSe3-cb
        Name => 'RepeatingFlashCount',
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    25.1 => { # CSe3-cc
        Name => 'RepeatingFlashRate',
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0xf0,
        ValueConv => 'my $v=($val>>4); $v < 10 ? $v + 1 : 10 * ($v - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5) << 4',
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
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Off',
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
            0x00 => 'TTL',
            0x40 => 'Auto Aperture',
            0x80 => 'Manual',
            0xc0 => 'Off',
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
            0x00 => 'TTL',
            0x40 => 'Auto Aperture',
            0x80 => 'Manual',
            0xc0 => 'Off',
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
        PrintConv => { 0x00 => 'On', 0x20 => 'Off' },
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

# D500 custom settings (ref 1)
%Image::ExifTool::NikonCustom::SettingsD500 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom settings for the D500',
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
            0x00 => 'Release',
            0x40 => 'Release + Focus',
            0x80 => 'Focus',
            0xc0 => 'Focus + Release',
        },
    },
    1.2 => { # CSa6
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0x00 => '55 Points',
            0x10 => '15 Points',
        },
    },
    1.3 => { # CSa4
        Name => 'Three-DTrackingFaceDetection',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'On',
        },
    },
    1.4 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Focus',
            0x20 => 'Release',
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
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    2.2 => { # CSa12-d
        Name => 'AFPointBrightness',
        Mask => 0x06,
        PrintConv => {
            0x00 => 'Auto',
            0x02 => 'On',
            0x04 => 'Off',
        },
    },
    4.1 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'Show ISO Sensitivity',
            0x08 => 'Show Frame Count',
        },
    },
    4.2 => { # CSd8
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => { 0x00 => 'On', 0x02 => 'Off' },
    },
    5.1 => { # CSd9
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => { 0x00 => 'Off', 0x20 => 'On' },
    },
    5.2 => { # CSd6
        Name => 'ElectronicFront-CurtainShutter',
        Mask => 0x08,
        PrintConv => { 0x00 => 'Off', 0x08 => 'On' },
    },
    6.1 => { # CSf7
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    6.2 => { # CSf4-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'No',
            0x08 => 'Shutter Speed & Aperture',
            0x10 => 'Exposure Compensation',
            0x18 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.3 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
            0x02 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
            0x80 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0x00 => '1/3 EV',
            0x10 => '1/2 EV',
            0x20 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '1/3 EV',
            0x04 => '1/2 EV',
            0x08 => '1 EV',
        },
    },
    8.1 => { # CSb6
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '6 mm',
            0x20 => '8 mm',
            0x40 => '10 mm',
            0x60 => '13 mm',
            0x80 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x70 ? $val - 0x100 : $val) / 0x60',
        ValueConvInv => '(int($val*6+($val>0?0.5:-0.5))<<4) & 0xf0',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xe0,                       #same offset and settings as D810 but with a different decoding
        PrintConv => {
            0x00 => 'Select Center Focus Point (Reset)',
            0x40 => 'Preset Focus Point (Pre)',
            0x60 => 'Highlight Active Focus Point',
            0x80 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf2-b                      #same offset and settings as D810 but with a different decoding
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Thumbnail On/Off',
            0x04 => 'View Histograms',
            0x08 => 'Zoom On/Off',
            0x0c => 'Choose Folder',
        },
    },
    10.3 => { # CSf5
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Do Nothing',
            0x01 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => '1 s',
            0x80 => '2 s',
            0xc0 => '3 s',
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
            0x00 => '0,-,+',
            0x10 => '-,0,+',
        },
    },
    13.2 => { # CSe6
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x04 => 'Flash/Speed/Aperture',
            0x08 => 'Flash/Aperture',
            0x0c => 'Flash Only',
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
#           21 => 'Disable Synchronized Release',   #removed with D500
            22 => 'Remote Release Only',
            26 => 'Flash Disable/Enable',
            27 => 'Highlight-weighted Metering',
            36 => 'AF-Area Mode (Single)',                              #new with D500
            37 => 'AF-Area Mode (Dynamic Area 25 Points)',              #new with D500
            38 => 'AF-Area Mode (Dynamic Area 72 Points)',              #new with D500
            39 => 'AF-Area Mode (Dynamic Area 152 Points)',             #new with D500
            40 => 'AF-Area Mode (Group Area AF)',                       #new with D500
            41 => 'AF-Area Mode (Auto Area AF)',                        #new with D500
            42 => 'AF-Area Mode + AF-On (Single)',                      #new with D500
            43 => 'AF-Area Mode + AF-On (Dynamic Area 25 Points)',      #new with D500
            44 => 'AF-Area Mode + AF-On (Dynamic Area 72 Points)',      #new with D500
            45 => 'AF-Area Mode + AF-On (Dynamic Area 152 Points)',     #new with D500
            46 => 'AF-Area Mode + AF-On (Group Area AF)',               #new with D500
            47 => 'AF-Area Mode + AF-On (Auto Area AF)',                #new with D500
            49 => 'Sync Release (Master Only)',                         #new with D500
            50 => 'Sync Release (Remote Only)',                         #new with D500
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
            0x00 => 'Autofocus Off, Exposure Off',
            0x20 => 'Autofocus Off, Exposure On',
            0x40 => 'Autofocus Off, Exposure On (Mode A)',
            0x80 => 'Autofocus On, Exposure Off',
            0xa0 => 'Autofocus On, Exposure On',
            0xc0 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf4-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'On',
            0x08 => 'Off',
            0x10 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf4-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Sub-command Dial',
            0x04 => 'Aperture Ring',
        },
    },
    18.4 => { # CSf6
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => { 0x00 => 'No', 0x01 => 'Yes' },
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '6 s',
            0x30 => '10 s',
            0x50 => '30 s',
            0x60 => '1 min',
            0x70 => '5 min',
            0x80 => '10 min',
            0x90 => '30 min',
            0xa0 => 'No Limit',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s',
            0xc0 => '20 s',
        },
    },
    20.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0x00 => '0.5 s',
            0x10 => '1 s',
            0x20 => '2 s',
            0x30 => '3 s',
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
            0x00 => '2 s',
            0x20 => '4 s',
            0x60 => '10 s',
            0x80 => '20 s',
            0xa0 => '1 min',
            0xc0 => '5 min',
            0xe0 => '10 min',
        },
    },
    21.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x04 => '5 min',
            0x08 => '10 min',
            0x0c => '15 min',
            0x10 => '20 min',
            0x14 => '30 min',
            0x18 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x40 => '10 s',
            0x80 => '20 s',
            0xa0 => '1 min',
            0xc0 => '5 min',
            0xe0 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x08 => '10 s',
            0x10 => '20 s',
            0x14 => '1 min',
            0x18 => '5 min',
            0x1c => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0x20 => '1/250 s (auto FP)',
            0x30 => '1/250 s',
            0x50 => '1/200 s',
            0x60 => '1/160 s',
            0x70 => '1/125 s',
            0x80 => '1/100 s',
            0x90 => '1/80 s',
            0xa0 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'On',
            0x20 => 'Off',
        },
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    37.1 => { # CSf2-c
        Name => 'MultiSelectorLiveView',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Reset',
            0x40 => 'Zoom',
            0xc0 => 'Not Used',
        },
    },
    38.1 => { # CSf3-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    38.2 => { # CSf3-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    38.3 => { # CSg1-h
        Name => 'MovieShutterButton',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'Take Photo',
            0x10 => 'Record Movies',
        },
    },
    38.4 => { # CSe3
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Entire Frame',
            0x04 => 'Background Only',
        },
    },
    38.5 => { # CSe4
        Name => 'AutoFlashISOSensitivity',
        Mask => 0x02,
        PrintConv => {
            0x00 => 'Subject and Background',
            0x02 => 'Subject Only',
        },
    },
    41.1 => { # CSg1-c
        Name => 'MoviePreviewButton',
        Mask => 0xf0,
        PrintConv => {
            0x00 => 'None',
            0x20 => 'Power Aperture (close)',
            0x30 => 'Index Marking',
            0x40 => 'View Photo Shooting Info',
            0xb0 => 'Exposure Compensation -',
        },
    },
    41.2 => { # CSg1-a
        Name => 'MoviePreviewButton',
        Mask => 0x0f,
        PrintConv => {
            0x00 => 'None',
            0x01 => 'Power Aperture (open)',
            0x03 => 'Index Marking',
            0x04 => 'View Photo Shooting Info',
            0x0a => 'Exposure Compensation +',
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
            7 => 'Photo Shooting Menu Bank',                                #new with D500
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
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    47.1 => { # CSa12-b
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    47.2 => { # CSa12-a
        Name => 'AFPointIllumination',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On During Manual Focusing',
        },
    },
    47.3 => { # CSa7
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'Focus Point',
            0x10 => 'Focus Point and AF-area Mode',
        },
    },
    47.4 => { # CSa12-c
        Name => 'GroupAreaAFIllumination',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Squares',
            0x04 => 'Dots',
        },
    },
    48.1 => { # CSb5
        Name => 'MatrixMetering',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Face Detection On',
            0x80 => 'Face Detection Off',
        },
    },
    48.2 => { # CSf8
        Name => 'LiveViewButtonOptions',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Enable',
            0x10 => 'Enable (Standby Timer Active)',            #new with D500
            0x20 => 'Disable',
        },
    },
    48.3 => { # CSa10
        Name => 'AFModeRestrictions',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'No Restrictions',
            0x01 => 'AF-C',
            0x02 => 'AF-S',
        },
    },
    49.1 => { # CSa9
        Name => 'LimitAFAreaModeSelection',
        Mask => 0x7e,
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                1 => 'Auto-area',
                2 => 'Group-area',
                3 => '3D-tracking',
                4 => 'Dynamic area (153 points)',
                5 => 'Dynamic area (72 points)',
                6 => 'Dynamic area (25 points)',
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
            0x00 => 'Focus Point Selection',
            0x80 => 'Same as MultiSelector',
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
            0x00 => 'None',
            0x30 => 'Index Marking',
            0x40 => 'View Photo Shooting Info',
            0x50 => 'AE/AF Lock',
            0x60 => 'AE Lock (Only)',
            0x70 => 'AE Lock (Hold)',
            0x80 => 'AF Lock (Only)',
        },
    },
    75.1 => { # CSg1-d
        Name => 'AssignMovieFunc1ButtonPlusDials',
        Mask => 0x10,
        PrintConv => {
            0x00  => 'None',
            0x10  => 'Choose Image Area (DX/1.3x)',
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
            0x00  => 'None',
            0x10  => 'Choose Image Area (DX/1.3x)',
        },
    },
    77.1 => { # CSd4
        Name => 'SyncReleaseMode',          #new with D500
        Mask => 0x80,
        PrintConv => {
            0x00 => 'No Sync',
            0x80 => 'Sync',
        },
    },
    78.1 => { # CSa5
        Name => 'Three-DTrackingWatchArea',      #new with D500
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Wide',
            0x80 => 'Normal',
        },
    },
    78.2 => { # CSa3-b
        Name => 'SubjectMotion',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Steady',
            0x20 => 'Middle',
            0x40 => 'Erratic',
        },
    },
    78.3 => { # CSa8
        Name => 'AFActivation',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'Shutter/AF-On',
            0x08 => 'AF-On Only',
        },
    },
    78.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On (Half Press)',
            0x02 => 'On (Burst Mode)'
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
            0x00 => 'None',
            0x30 => 'Index Marking',
            0x40 => 'View Photo Shooting Info',
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
    NOTES => 'Custom settings for the D810',
    0.1 => { # CSf1
        Name => 'LightSwitch',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'LCD Backlight',
            0x08 => 'LCD Backlight and Shooting Information',
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
            0x00 => 'Release',
            0x40 => 'Release + Focus',
            0x80 => 'Focus',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Focus',
            0x20 => 'Release',
        },
    },
    1.3 => { # CSa7
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0x00 => '51 Points',
            0x10 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'Off',
            0x01 => '1 (Short)',
            0x02 => '2',
            0x03 => '3 (Normal)',
            0x04 => '4',
            0x05 => '5 (Long)',
        },
    },
    2.1 => { # CSa4
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Shutter/AF-On',
            0x80 => 'AF-On Only',
        },
    },
    2.2 => { # CSa7
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    2.3 => { # CSa6
        Name => 'AFPointBrightness',
        Mask => 0x06,
        PrintConv => {
            0x00 => 'Auto',
            0x02 => 'On',
            0x04 => 'Off',
        },
    },
    2.4 => { # CSa10
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'On',
            0x01 => 'Off',
        },
    },
    3.1 => { # CSd13
        Name => 'BatteryOrder',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'MB-D12 First',
            0x40 => 'Camera Battery First',
        },
    },
    3.2 => { # CSd12
        Name => 'MB-D12BatteryType',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'LR6 (AA alkaline)',
            0x01 => 'HR6 (AA Ni-MH)',
            0x02 => 'FR6 (AA lithium)',
        },
    },
    4.1 => { # CSd1-b
        Name => 'Pitch',
        Mask => 0x40,
        PrintConv => { 0x00 => 'High', 0x40 => 'Low' },
    },
    4.2 => { # CSf11
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    4.3 => { # CSd8
        Name => 'ISODisplay',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Show ISO/Easy ISO',
            0x04 => 'Show ISO Sensitivity',
            0x0c => 'Show Frame Count',
        },
    },
    4.4 => { # CSd7
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => { 0x00 => 'On', 0x02 => 'Off' },
    },
    5.1 => { # CSd10
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Not Set', # observed on a new camera prior to applying a setting for the first time
            0x40 => 'Auto',
            0x80 => 'Manual (dark on light)',
            0xc0 => 'Manual (light on dark)',
        },
    },
    5.2 => { # CSd11
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => { 0x00 => 'Off', 0x20 => 'On' },
    },
    5.3 => { # CSd5
        Name => 'ElectronicFront-CurtainShutter',
        Mask => 0x08,
        PrintConv => { 0x00 => 'Off', 0x08 => 'On' },
    },
    5.4 => { # CSd9
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    5.5 => { # CSd1-a
        Name => 'Beep',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'Low',
            0x02 => 'Medium',
            0x03 => 'High',
        },
    },
    6.1 => { # CSf12
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    6.2 => { # CSf9-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'No',
            0x08 => 'Shutter Speed & Aperture',
            0x10 => 'Exposure Compensation',
            0x18 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.3 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
            0x02 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
            0x80 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0x00 => '1/3 EV',
            0x10 => '1/2 EV',
            0x20 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '1/3 EV',
            0x04 => '1/2 EV',
            0x08 => '1 EV',
        },
    },
    8.1 => { # CSb6
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '8 mm',
            0x20 => '12 mm',
            0x40 => '15 mm',
            0x60 => '20 mm',
            0x80 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x70 ? $val - 0x100 : $val) / 0x60',
        ValueConvInv => '(int($val*6+($val>0?0.5:-0.5))<<4) & 0xf0',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf2-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Select Center Focus Point (Reset)',
            0x40 => 'Highlight Active Focus Point',
            0x80 => 'Preset Focus Point (Pre)',
            0xc0 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf2-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Thumbnail On/Off',
            0x10 => 'View Histograms',
            0x20 => 'Zoom On/Off',
            0x30 => 'Choose Folder',
        },
    },
    10.3 => { # CSf3
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Do Nothing',
            0x01 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd4
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => '1 s',
            0x80 => '2 s',
            0xc0 => '3 s',
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
            0x00 => 'AE & Flash',
            0x20 => 'AE Only',
            0x40 => 'Flash Only',
            0x60 => 'WB Bracketing',
            0x80 => 'Active D-Lighting',
        },
    },
    13.2 => { # CSe8
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0x00 => '0,-,+',
            0x10 => '-,0,+',
        },
    },
    13.3 => { # CSe7
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x04 => 'Flash/Speed/Aperture',
            0x08 => 'Flash/Aperture',
            0x0c => 'Flash Only',
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
            0x00 => 'Autofocus Off, Exposure Off',
            0x20 => 'Autofocus Off, Exposure On',
            0x40 => 'Autofocus Off, Exposure On (Mode A)',
            0x80 => 'Autofocus On, Exposure Off',
            0xa0 => 'Autofocus On, Exposure On',
            0xc0 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf9-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'On',
            0x08 => 'Off',
            0x10 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf9-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Sub-command Dial',
            0x04 => 'Aperture Ring',
        },
    },
    18.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    18.5 => { # CSf10
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => { 0x00 => 'No', 0x01 => 'Yes' },
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '6 s',
            0x30 => '10 s',
            0x50 => '30 s',
            0x60 => '1 min',
            0x70 => '5 min',
            0x80 => '10 min',
            0x90 => '30 min',
            0xa0 => 'No Limit', #1
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s',
            0xc0 => '20 s',
        },
    },
    20.2 => { # CSc3-c
        Name => 'SelfTimerShotInterval',
        Mask => 0x30,
        PrintConv => {
            0x00 => '0.5 s',
            0x10 => '1 s',
            0x20 => '2 s',
            0x30 => '3 s',
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
            0x00 => '2 s',
            0x20 => '4 s',
            0x60 => '10 s',
            0x80 => '20 s',
            0xa0 => '1 min',
            0xc0 => '5 min',
            0xe0 => '10 min',
        },
    },
    21.2 => { # CSc4-e                        # note: decode changed from D4s
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x04 => '5 min',
            0x08 => '10 min',
            0x0c => '15 min',
            0x10 => '20 min',
            0x14 => '30 min',
            0x18 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b                        # note: decode changed from D4s
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x40 => '10 s',
            0x80 => '20 s',
            0xa0 => '1 min',
            0xc0 => '5 min',
            0xe0 => '10 min',
        },
    },
    22.2 => { # CSc4-c                        # note: decode changed from D4s
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x08 => '10 s',
            0x10 => '20 s',
            0x14 => '1 min',
            0x18 => '5 min',
            0x1c => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '1/320 s (auto FP)',
            0x20 => '1/250 s (auto FP)',
            0x30 => '1/250 s',
            0x50 => '1/200 s',
            0x60 => '1/160 s',
            0x70 => '1/125 s',
            0x80 => '1/100 s',
            0x90 => '1/80 s',
            0xa0 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    24.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'On',
            0x20 => 'Off',
        },
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    37.1 => { # CSf2-c
        Name => 'MultiSelectorLiveView',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Reset',
            0x40 => 'Zoom',
            0xc0 => 'Not Used',
        },
    },
    38.1 => { # CSf7-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    38.2 => { # CSf7-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    38.3 => { # CSg4
        Name => 'MovieShutterButton',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Take Photo',
            0x20 => 'Record Movies',
        },
    },
    38.4 => { # CSe4
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Entire frame',
            0x04 => 'Background only',
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
            0x00 => 'None',
            0x10 => 'Power Aperture (open)', # bit '02' is also toggled on for this setting
            0x30 => 'Index Marking',
            0x40 => 'View Photo Shooting Info',
        },
    },
    41.2 => { # CSg2
        Name => 'MoviePreviewButton',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'None',
            0x02 => 'Power Aperture (open)', # bit '10' is also toggled on for this setting
            0x03 => 'Index Marking',
            0x04 => 'View Photo Shooting Info',
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
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    47.1 => { # CSa5-b
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    47.2 => { # CSa5-a              # moved with D810
        Name => 'AFPointIllumination',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On During Manual Focusing',
        },
    },
    47.3 => { # CSa9
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'Focus Point',
            0x10 => 'Focus Point and AF-area mode',
        },
    },
    47.4 => { # CSa5-c
        Name => 'GroupAreaAFIllumination',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Squares',      # moved with D810
            0x04 => 'Dots',
        },
    },
    48.1 => { # CSb5
        Name => 'MatrixMetering',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Face Detection On',
            0x80 => 'Face Detection Off',
        },
    },
    48.2 => { # CSf14
        Name => 'LiveViewButtonOptions',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Enable',
            0x20 => 'Disable',
        },
    },
    48.3 => { # CSa12
        Name => 'AFModeRestrictions',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'No Restrictions',
            0x01 => 'AF-C',
            0x02 => 'AF-S',
        },
    },
    49.1 => { # CSa11
        Name => 'LimitAFAreaModeSelection',
        Mask => 0x7e,
        PrintConv => {
            0 => 'No Restrictions',
            BITMASK => {
                1 => 'Auto-area',
                2 => 'Group-area',
                3 => '3D-tracking',
                4 => 'Dynamic area (51 points)',
                5 => 'Dynamic area (21 points)',
                6 => 'Dynamic area (9 points)',
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
            0x00 => 'Single Area',
            0x20 => 'Dynamic Area',
            0x40 => 'Auto-area',
            0x60 => '3D-tracking (11 points)',
        },
    },
    0.2 => { # CSa2
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
        },
    },
    2.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'Low',
            0x80 => 'High',
        },
    },
    2.2 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => {
            0x00 => 'On',
            0x02 => 'Off',
        },
    },
    2.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0x08 => 'Off',
            0x00 => 'On',
        },
    },
    2.4 => { # CSf4
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    3.1 => { # CSd4
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => { 0x00 => 'On', 0x08 => 'Off' },
    },
    4.1 => { # CSa4
        Name => 'RangeFinder',
        Mask => 0x10,
        PrintConv => { 0x00 => 'Off', 0x10 => 'On' },
    },
    4.2 => { # CSd6
        Name => 'DateImprint',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'On',
        },
    },
    4.3 => { # CSf5
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    5.1 => { # CSb1
        Name => 'EVStepSize',
        Mask => 0x40,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
        },
    },
    9.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    11.1 => { # CSe2
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Exposure',
            # (NOTE: the following are reversed in the D5100 -- is this correct?)
            0x40 => 'Active D-Lighting', #(NC)
            0x80 => 'WB Bracketing',
        },
    },
    12.1 => { # CSf1
        Name => 'TimerFunctionButton',
        Mask => 0x38,
        PrintConv => {
            0x00 => 'Self-timer',
            0x08 => 'Release Mode',
            0x10 => 'Image Quality/Size', #(NC)
            0x18 => 'ISO', #(NC)
            0x20 => 'White Balance', #(NC)
            0x28 => 'Active D-Lighting', #(NC)
            0x30 => '+ NEF (RAW)',
            0x38 => 'Auto Bracketing',
        },
    },
    15.1 => { # CSf2
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x08 => 'AE Lock Only', #(NC)
            0x10 => 'AF Lock Only', #(NC)
            0x18 => 'AE Lock (hold)',
            0x20 => 'AF-ON',
        },
    },
    16.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    16.2 => { # CSf3
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => { 0x00 => 'No', 0x80 => 'Yes' },
    },
    17.1 => { # CSc2-c
        Name => 'MeteringTime',
        Mask => 0x70,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '8 s',
            0x20 => '20 s',
            0x30 => '1 min',
            0x40 => '30 min',
        },
    },
    17.2 => { # CSc4
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0x00 => '1 min',
            0x01 => '5 min',
            0x02 => '10 min',
            0x03 => '15 min',
        },
    },
    18.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s',
            0xc0 => '20 s',
        },
    },
    18.2 => { # CSc3-b
        Name => 'SelfTimerShotCount',
        Mask => 0x1e,
        ValueConv => '$val >> 1',
        ValueConvInv => '$val << 1',
    },
    19.1 => { # CSc2-b
        Name => 'ImageReviewTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '8 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '10 min',
        },
    },
    20.1 => { # CSc2-a
        Name => 'PlaybackMenusTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '8 s',
            0x20 => '12 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '10 min',
        },
    },
    22.1 => { # CSe1-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
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
            0x00 => 'Face Priority',
            0x20 => 'Wide Area',
            0x40 => 'Normal Area',
            0x60 => 'Subject Tracking',
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
            0x00 => 'Release',
            0x80 => 'Focus',
        },
    },
    1.1 => { # CSa2
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
        },
    },
    3.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'Low',
            0x80 => 'High',
        },
    },
    3.2 => { # CSf4
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    3.3 => { # CSd2
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'On',
            0x08 => 'Off',
        },
    },
    4.1 => { # CSd3
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => { 0x00 => 'On', 0x08 => 'Off' },
    },
    5.1 => { # CSa3
        Name => 'RangeFinder',
        Mask => 0x10,
        PrintConv => { 0x00 => 'Off', 0x10 => 'On' },
    },
    # (it looks like CSd5 DateImprint is not stored)
    5.2 => { # CSf5
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    6.1 => { # CSb1
        Name => 'EVStepSize',
        Mask => 0x40,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
        },
    },
    10.1 => { # CSd4
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    12.1 => { # CSe2
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Exposure',
            # (NOTE: the following are reversed from the D5000 -- is D5000 correct?)
            0x40 => 'WB Bracketing',
            0x80 => 'Active D-Lighting',
        },
    },
    13.1 => { # CSf1
        Name => 'TimerFunctionButton',
        Mask => 0x38,
        PrintConv => {
            0x00 => 'Self-timer',
            0x08 => 'Release Mode',
            0x10 => 'Image Quality/Size',
            0x18 => 'ISO',
            0x20 => 'White Balance',
            0x28 => 'Active D-Lighting',
            0x30 => '+ NEF (RAW)',
            0x38 => 'Auto Bracketing',
        },
    },
    16.1 => { # CSf2
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x08 => 'AE Lock Only',
            0x10 => 'AF Lock Only',
            0x18 => 'AE Lock (hold)',
            0x20 => 'AF-ON',
        },
    },
    17.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    17.2 => { # CSf3
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => { 0x00 => 'No', 0x80 => 'Yes' },
    },
    18.1 => { # CSc2-d
        Name => 'MeteringTime',
        Mask => 0x70,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '8 s',
            0x20 => '20 s', #(NC)
            0x30 => '1 min',
            0x40 => '30 min', #(NC)
        },
    },
    18.2 => { # CSc4
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0x00 => '1 min',
            0x01 => '5 min',
            0x02 => '10 min', #(NC)
            0x03 => '20 min', # (but picture in manual shows 15 min)
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s',
            0xc0 => '20 s',
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
            0x00 => '4 s',
            0x20 => '8 s', #(NC)
            0x40 => '20 s',
            0x60 => '1 min', #(NC)
            0x80 => '10 min', #(NC)
        },
    },
    20.2 => { # CSc2-c
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '3 min',
            0x04 => '5 min', #(NC)
            0x08 => '10 min',
            0x0c => '15 min', #(NC)
            0x10 => '20 min', #(NC)
            0x14 => '30 min', #(NC)
        },
    },
    21.1 => { # CSc2-a
        Name => 'PlaybackMenusTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '8 s', #(NC)
            0x20 => '12 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '10 min', #(NC)
        },
    },
    23.1 => { # CSe1-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
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
            0x00 => 'Release',
            0x80 => 'Focus',
        },
    },
    0.2 => { # CSa2
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0x00 => '39 Points',
            0x10 => '11 Points',
        },
    },
    1.1 => { # CSa3
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
        },
    },
    3.1 => { # CSd1
        Name => 'Beep',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'Low',
            0x80 => 'High',
        },
    },
    3.2 => { # CSf4
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    3.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'On',
            0x08 => 'Off',
        },
    },
    4.1 => { # CSd3
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => { 0x00 => 'On', 0x08 => 'Off' },
    },
    5.1 => { # CSa4
        Name => 'RangeFinder',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    5.2 => { # CSf3-a
        Name => 'ReverseExposureCompDial',
        Mask => 0x10,
        PrintConv => { 0x00 => 'No', 0x10 => 'Yes' },
    },
    5.3 => { # CSf3-b
        Name => 'ReverseShutterSpeedAperture',
        Mask => 0x08,
        PrintConv => { 0x00 => 'No', 0x08 => 'Yes' },
    },
    5.4 => { # CSf5
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    6.1 => { # CSb1
        Name => 'EVStepSize',
        Mask => 0x40, # (bit 0x04 also changes)
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
        },
    },
    10.1 => { # CSd5
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    12.1 => { # CSe2
        Name => 'AutoBracketSet',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Exposure',
            # (NOTE: the following are reversed from the D5000 -- is D5000 correct?)
            0x40 => 'WB Bracketing',
            0x80 => 'Active D-Lighting',
        },
    },
    13.1 => { # CSf1
        Name => 'FunctionButton',
        Mask => 0x1f,
        PrintConv => {
            0x03 => 'AE/AF Lock',
            0x04 => 'AE Lock Only',
            0x06 => 'AE Lock (hold)',
            0x07 => 'AF Lock Only',
            0x08 => 'AF-ON',
            0x10 => '+ NEF (RAW)',
            0x12 => 'Active D-Lighting',
            0x19 => 'Live View',
            0x1a => 'Image Quality',
            0x1b => 'ISO',
            0x1c => 'White Balance',
            0x1d => 'HDR',
            0x1e => 'Auto Bracketing',
            0x1f => 'AF-area Mode',
        },
    },
    16.1 => { # CSf2
        Name => 'AELockButton',
        Mask => 0x0f,
        PrintConv => {
            0x03 => 'AE/AF Lock',
            0x04 => 'AE Lock Only',
            0x06 => 'AE Lock (hold)',
            0x07 => 'AF Lock Only',
            0x08 => 'AF-ON',
        },
    },
    17.1 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    18.1 => { # CSc2-d
        Name => 'StandbyTimer',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '8 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '30 min',
        },
    },
    18.2 => { # CSc4
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0x00 => '1 min',
            0x01 => '5 min',
            0x02 => '10 min',
            0x03 => '15 min',
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s',
            0xc0 => '20 s',
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
            0x20 => '4 s',
            0x40 => '8 s',
            0x80 => '20 s',
            0xa0 => '1 min',
            0xe0 => '10 min',
        },
    },
    20.2 => { # CSc2-c
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x04 => '5 min',
            0x08 => '10 min',
            0x0c => '15 min',
            0x10 => '20 min',
            0x14 => '30 min',
        },
    },
    21.1 => { # CSc2-a
        Name => 'PlaybackMenusTime',
        Mask => 0xe0,
        PrintConv => {
            0x20 => '8 s',
            0x80 => '20 s',
            0xa0 => '1 min',
            0xc0 => '5 min',
            0xe0 => '10 min',
        },
    },
    23.1 => { # CSe1-a
        Name => 'InternalFlash',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
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
            0x00 => 'Release',
            0x80 => 'Focus',
        },
    },
    0.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Focus',
            0x20 => 'Release',
        },
    },
    0.3 => { # CSa6
        Name => 'NumberOfFocusPoints',
        Mask => 0x10,
        PrintConv => {
            0x00 => '39 Points',
            0x10 => '11 Points',
        },
    },
    0.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0x05 => '5 Long',
            0x04 => '4',
            0x03 => '3 Normal',
            0x02 => '2',
            0x01 => '1 Short',
            0x00 => 'Off',
        },
    },
    1.2 => { # CSa5
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    1.3 => { # CSa4
        Name => 'AFPointIllumination',
        Mask => 0x06,
        PrintConv => {
            0x00 => 'Auto',
            0x02 => 'On',
            0x04 => 'Off',
        },
    },
    1.4 => { # CSa7
        Name => 'AFAssist',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    2.1 => { # CSd14
        Name => 'BatteryOrder',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'MB-D11 First',
            0x40 => 'Camera Battery First',
        },
    },
    2.2 => { # CSa10
        Name => 'AF-OnForMB-D11',
        Mask => 0x1c,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x04 => 'AE Lock Only',
            0x08 => 'AF Lock Only',
            0x0c => 'AE Lock (hold)',
            0x10 => 'AF-ON',
            0x14 => 'FV Lock',
            0x18 => 'Same as FUNC Button',
        },
    },
    2.3 => { # CSd13
        Name => 'MB-D11BatteryType',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'LR6 (AA alkaline)',
            0x01 => 'Ni-MH (AA Ni-MH)',
            0x02 => 'FR6 (AA lithium)',
        },
    },
    3.1 => { # CSd1-b
        Name => 'BeepPitch',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'Low',
            0x80 => 'High',
        },
    },
    3.2 => { # CSf8
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    3.3 => { # CSd3
        Name => 'ISODisplay',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Show ISO/Easy ISO',
            0x04 => 'Show ISO Sensitivity',
            0x0c => 'Show Frame Count',
        },
    },
    3.4 => { # CSd2
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => { 0x00 => 'On', 0x02 => 'Off' },
    },
    3.5 => { # CSd4
        Name => 'ViewfinderWarning',
        Mask => 0x01,
        PrintConv => { 0x00 => 'On', 0x01 => 'Off' },
    },
    4.1 => { # CSd9
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Auto',
            0x80 => 'Manual (dark on light)',
            0xc0 => 'Manual (light on dark)',
        },
    },
    4.2 => { # CSd10
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => { 0x00 => 'Off', 0x20 => 'On' },
    },
    4.3 => { # CSd8
        Name => 'FileNumberSequence',
        Mask => 0x08,
        PrintConv => { 0x00 => 'On', 0x08 => 'Off' },
    },
    4.4 => { # CSd5
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    4.5 => { # CSd1-a
        Name => 'BeepVolume',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => '1',
            0x02 => '2',
            0x03 => '3',
        },
    },
    5.1 => { # CSf9
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    5.2 => { # CSb3
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
            0x02 => 'On Auto Reset',
        },
    },
    6.1 => { # CSb2
        Name => 'ExposureControlStep',
        Mask => 0x40,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
        },
    },
    6.2 => { # CSb1
        Name => 'ISOSensitivityStep',
        Mask => 0x10,
        PrintConv => {
            0x00 => '1/3 EV',
            0x10 => '1/2 EV',
        },
    },
    7.1 => { # CSb4
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '6 mm',
            0x20 => '8 mm',
            0x40 => '10 mm',
            0x60 => '13 mm',
            0x80 => 'Average',
        },
    },
    10.1 => { # CSd11
        Name => 'ExposureDelayMode',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
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
            0x00 => 'AE & Flash', # default
            0x20 => 'AE Only',
            0x40 => 'Flash Only', #(NC)
            0x60 => 'WB Bracketing', #(NC)
            0x80 => 'Active D-Lighting', #(NC)
        },
    },
    12.2 => { # CSe6
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0x00 => '0,-,+',
            0x10 => '-,0,+',
        },
    },
    13.1 => { # CSf3
        Name => 'FuncButton',
        Mask => 0xf8,
        PrintConv => {
            0x00 => 'Grid Display',
            0x08 => 'FV Lock',
            0x10 => 'Flash Off',
            0x18 => 'Matrix Metering',
            0x20 => 'Center-weighted Metering',
            0x28 => 'Spot Metering',
            0x30 => 'My Menu Top',
            0x38 => '+ NEF (RAW)',
            0x40 => 'Active D-Lighting',
            0x48 => 'Preview',
            0x50 => 'AE/AF Lock',
            0x58 => 'AE Lock Only',
            0x60 => 'AF Lock Only',
            0x68 => 'AE Lock (hold)',
            0x70 => 'Bracketing Burst',
            0x78 => 'Playback',
            0x80 => '1EV Step Speed/Aperture',
            0x88 => 'Choose Non-CPU Lens',
            0x90 => 'Virtual Horizon',
            0x98 => 'Start Movie Recording',
        },
    },
    14.1 => { # CSf4
        Name => 'PreviewButton',
        Mask => 0xf8,
        PrintConv => {
            0x00 => 'Grid Display',
            0x08 => 'FV Lock',
            0x10 => 'Flash Off',
            0x18 => 'Matrix Metering',
            0x20 => 'Center-weighted Metering',
            0x28 => 'Spot Metering',
            0x30 => 'My Menu Top',
            0x38 => '+ NEF (RAW)',
            0x40 => 'Active D-Lighting',
            0x48 => 'Preview',
            0x50 => 'AE/AF Lock',
            0x58 => 'AE Lock Only',
            0x60 => 'AF Lock Only',
            0x68 => 'AE Lock (hold)',
            0x70 => 'Bracketing Burst',
            0x78 => 'Playback',
            0x80 => '1EV Step Speed/Aperture',
            0x88 => 'Choose Non-CPU Lens',
            0x90 => 'Virtual Horizon',
            0x98 => 'Start Movie Recording',
        },
    },
    16.1 => { # CSf5
        Name => 'AELockButton',
        Mask => 0x38,
        PrintConv => {
            0x00 => 'AE/AF Lock',
            0x08 => 'AE Lock Only',
            0x10 => 'AF Lock Only',
            0x18 => 'AE Lock (hold)',
            0x20 => 'AF-ON',
            0x28 => 'FV Lock',
        },
    },
    15.1 => { # CSf2
        Name => 'OKButton',
        Mask => 0x18,
        PrintConv => {
            0x08 => 'Select Center Focus Point',
            0x10 => 'Highlight Active Focus Point',
            0x18 => 'Not Used', #(NC)
            0x00 => 'Off', #(NC)
        },
    },
    17.1 => { # CSf6-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x80,
        PrintConv => { 0x00 => 'No', 0x80 => 'Yes' },
    },
    17.2 => { # CSf6-b
        Name => 'CommandDialsChangeMainSub',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Off',
            0x20 => 'On',
            0x40 => 'On (A mode only)',
        },
    },
    17.3 => { # CSf6-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Sub-command Dial',
            0x04 => 'Aperture Ring',
        },
    },
    17.4 => { # CSf6-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'On',
            0x10 => 'On (Image Review Exclude)',
            0x08 => 'Off',
        },
    },
    17.5 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    17.6 => { # CSf7
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => { 0x00 => 'No', 0x01 => 'Yes' },
    },
    18.1 => { # CSc2
        Name => 'MeteringTime',
        Mask => 0xf0,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '6 s', # default
            0x20 => '8 s',
            0x30 => '16 s',
            0x40 => '30 s',
            0x50 => '1 min',
            0x60 => '5 min',
            0x70 => '10 min',
            0x80 => '30 min',
            0x90 => 'No Limit',
        },
    },
    18.2 => { # CSc5
        Name => 'RemoteOnDuration',
        Mask => 0x03,
        PrintConv => {
            0x00 => '1 min',
            0x01 => '5 min',
            0x02 => '10 min',
            0x03 => '15 min',
        },
    },
    19.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s', # default
            0xc0 => '20 s',
        },
    },
    19.2 => { # CSc3-c
        Name => 'SelfTimerInterval',
        Mask => 0x30,
        PrintConv => {
            0x00 => '0.5 s',
            0x10 => '1 s',
            0x20 => '2 s', # default
            0x30 => '3 s',
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
            0x00 => '4 s',
            0x20 => '10 s', # default
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    20.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => { #(NC)
            0x00 => '4 s',
            0x04 => '10 s', # default
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
        },
    },
    21.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s', # default
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    21.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => { #(NC)
            0x00 => '4 s',
            0x04 => '10 s', # default
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
        },
    },
    22.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '1/320 s (auto FP)',
            0x10 => '1/250 s (auto FP)',
            0x20 => '1/250 s',
            0x30 => '1/200 s',
            0x40 => '1/160 s',
            0x50 => '1/125 s',
            0x60 => '1/100 s',
            0x70 => '1/80 s',
            0x80 => '1/60 s',
       },
    },
    22.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    23.1 => { # CSe3
        Name => 'FlashControlBuilt-in',
        Mask => 0xc0,
        RawConv => '$$self{FlashControlBuiltin} = $val',
        PrintConv => {
            0x00 => 'TTL',
            0x40 => 'Manual',
            0x80 => 'Repeating Flash',
            0xc0 => 'Commander Mode',
        },
    },
    23.2 => { # CSe3-b
        Name => 'ManualFlashOutput',
        Condition => '$$self{FlashControlBuiltin} == 0x40',
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
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0x70,
        ValueConv => '2 ** (-($val>>4)-2)',
        ValueConvInv => '$val > 0 ? int(-log($val)/log(2)-2+0.5)<<4 : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    24.2 => { # CSe3-cb
        Name => 'RepeatingFlashCount',
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0x0f,
        ValueConv => '$val < 10 ? $val + 1 : 5 * ($val - 7)',
        ValueConvInv => '$val <= 10 ? $val - 1 : $val / 5 + 7',
    },
    25.1 => { # CSe3-cc (NC)
        Name => 'RepeatingFlashRate',
        Condition => '$$self{FlashControlBuiltin} == 0x80',
        Mask => 0xf0,
        ValueConv => 'my $v=($val>>4); $v < 10 ? $v + 1 : 10 * ($v - 8)',
        ValueConvInv => 'int(($val <= 10 ? $val - 1 : $val / 10 + 8) + 0.5) << 4',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    26.1 => { # CSe3-da
        Name => 'CommanderInternalTTLCompBuiltin',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    27.1 => { # CSe3-db
        Name => 'CommanderInternalTTLCompGroupA',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    28.1 => { # CSe3-dc
        Name => 'CommanderInternalTTLCompGroupB',
        Condition => '$$self{FlashControlBuiltin} == 0xc0',
        Mask => 0x1f,
        ValueConv => '($val - 9) / 3',
        ValueConvInv => '$val * 3 + 9',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    30.1 => { # CSd11
        Name => 'FlashWarning',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'On',
            0x80 => 'Off',
        },
    },
    30.2 => { # CSe4
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => { 0x00 => 'On', 0x20 => 'Off' },
    },
    34.1 => { # CSa8-b
        Name => 'LiveViewAFAreaMode',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Face-Priority',
            0x20 => 'NormalArea',
            0x40 => 'WideArea',
            0x60 => 'SubjectTracking',
        },
    },
    34.2 => { # CSa8-a
        Name => 'LiveViewAFMode',
        Mask => 0x02,
        PrintConv => {
            0x00 => 'AF-C',
            0x02 => 'AF-F',
        },
    },
    35.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s', # default
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
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
            0x00 => 'Release',
            0x40 => 'Release + Focus',
            0x80 => 'Focus',
            0xc0 => 'Focus + Release',
        },
    },
    1.2 => { # CSa2
        Name => 'AF-SPrioritySelection',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Focus',
            0x20 => 'Release',
        },
    },
    1.3 => { # CSa7
        Name => 'AFPointSelection',
        Mask => 0x10,
        PrintConv => {
            0x00 => '51 Points',
            0x10 => '11 Points',
        },
    },
    1.4 => { # CSa3
        Name => 'FocusTrackingLockOn',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'Off',
            0x01 => '1 (Short)',
            0x02 => '2',
            0x03 => '3 (Normal)',
            0x04 => '4',
            0x05 => '5 (Long)',
        },
    },
    2.1 => { # CSa4
        Name => 'AFActivation',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Shutter/AF-On',
            0x80 => 'AF-On Only',
        },
    },
    2.2 => { # CSa6
        Name => 'FocusPointWrap',
        Mask => 0x08,
        PrintConv => {
            0x00 => 'No Wrap',
            0x08 => 'Wrap',
        },
    },
    4.1 => { # CSd1-b
        Name => 'Pitch',
        Mask => 0x40,
        PrintConv => { 0x00 => 'High', 0x40 => 'Low' },
    },
    4.2 => { # CSf12
        Name => 'NoMemoryCard',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Release Locked',
            0x20 => 'Enable Release',
        },
    },
    4.3 => { # CSd6
        Name => 'GridDisplay',
        Mask => 0x02,
        PrintConv => { 0x00 => 'On', 0x02 => 'Off' },
    },
    5.1 => { # CSd9
        Name => 'ShootingInfoDisplay',
        Mask => 0xc0,
        PrintConv => {
            # 0x00 - seen for D4 (PH)
            0x40 => 'Auto',
            0x80 => 'Manual (dark on light)',
            0xc0 => 'Manual (light on dark)',
        },
    },
    5.2 => { # CSd10
        Name => 'LCDIllumination',
        Mask => 0x20,
        PrintConv => { 0x00 => 'Off', 0x20 => 'On' },
    },
    5.3 => { # CSd8
        Name => 'ScreenTips',
        Mask => 0x04,
        PrintConv => { 0x00 => 'Off', 0x04 => 'On' },
    },
    5.4 => { # CSd1-a
        Name => 'Beep',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'Low',
            0x02 => 'Medium',
            0x03 => 'High',
        },
    },
    6.1 => { # CSf13
        Name => 'ReverseIndicators',
        Mask => 0x80,
        PrintConv => {
            0x00 => '+ 0 -',
            0x80 => '- 0 +',
        },
    },
    6.2 => { # CSd7-a
        Name => 'RearDisplay',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'ISO',
            0x40 => 'Exposures Remaining',
        },
    },
    6.3 => { # CSd7-b
        Name => 'ViewfinderDisplay',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'Frame Count',
            0x20 => 'Exposures Remaining',
        },
    },
    6.4 => { # CSd10-a
        Name => 'CommandDialsReverseRotation',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'No',
            0x08 => 'Shutter Speed & Aperture',
            0x10 => 'Exposure Compensation',
            0x18 => 'Exposure Compensation, Shutter Speed & Aperture',
        },
    },
    6.5 => { # CSb4
        Name => 'EasyExposureCompensation',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
            0x02 => 'On (auto reset)',
        },
    },
    7.1 => { # CSb2
        Name => 'ExposureControlStepSize',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '1/3 EV',
            0x40 => '1/2 EV',
            0x80 => '1 EV',
        },
    },
    7.2 => { # CSb1
        Name => 'ISOStepSize',
        Mask => 0x30,
        PrintConv => {
            0x00 => '1/3 EV',
            0x10 => '1/2 EV',
            0x20 => '1 EV',
        },
    },
    7.3 => { # CSb3
        Name => 'ExposureCompStepSize',
        Mask => 0x0c,
        PrintConv => {
            0x00 => '1/3 EV',
            0x04 => '1/2 EV',
            0x08 => '1 EV',
        },
    },
    8.1 => { # CSb6 (CSb5 for D4)
        Name => 'CenterWeightedAreaSize',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '8 mm',
            0x20 => '12 mm',
            0x40 => '15 mm',
            0x60 => '20 mm',
            0x80 => 'Average',
        },
    },
    8.2 => { # CSb7-a
        Name => 'FineTuneOptMatrixMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.1 => { # CSb7-b
        Name => 'FineTuneOptCenterWeighted',
        Mask => 0xf0,
        ValueConv => '($val > 0x70 ? $val - 0x100 : $val) / 0x60',
        ValueConvInv => '(int($val*6+($val>0?0.5:-0.5))<<4) & 0xf0',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    9.2 => { # CSb7-c
        Name => 'FineTuneOptSpotMetering',
        Mask => 0x0f,
        ValueConv => '($val > 0x7 ? $val - 0x10 : $val) / 6',
        ValueConvInv => 'int($val*6+($val>0?0.5:-0.5)) & 0x0f',
        PrintConv => '$val ? sprintf("%+.2f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10.1 => { # CSf1-a
        Name => 'MultiSelectorShootMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Select Center Focus Point (Reset)',
            0x80 => 'Preset Focus Point (Pre)',
            0xc0 => 'Not Used (None)',
        },
    },
    10.2 => { # CSf1-b
        Name => 'MultiSelectorPlaybackMode',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Thumbnail On/Off',
            0x10 => 'View Histograms',
            0x20 => 'Zoom On/Off',
            0x30 => 'Choose Folder',
        },
    },
    10.3 => { # CSf2
        Name => 'MultiSelector',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Do Nothing',
            0x01 => 'Reset Meter-off Delay',
        },
    },
    11.1 => { # CSd4
        Name => 'ExposureDelayMode',
        Mask => 0xc0,
        PrintConv => {
            0x00 => 'Off',
            0x40 => '1 s',
            0x80 => '2 s',
            0xc0 => '3 s',
        },
    },
    11.2 => { # CSd2-a
        Name => 'CHModeShootingSpeed',
        Mask => 0x10,
        PrintConv => {
            0x00 => '10 fps',
            0x10 => '11 fps',
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
            0x00 => 'AE & Flash',
            0x20 => 'AE Only',
            0x40 => 'Flash Only',
            0x60 => 'WB Bracketing',
            0x80 => 'Active D-Lighting',
        },
    },
    13.2 => { # CSe8
        Name => 'AutoBracketOrder',
        Mask => 0x10,
        PrintConv => {
            0x00 => '0,-,+',
            0x10 => '-,0,+',
        },
    },
    13.3 => { # CSe7
        Name => 'AutoBracketModeM',
        Mask => 0x0c,
        PrintConv => {
            0x00 => 'Flash/Speed',
            0x04 => 'Flash/Speed/Aperture',
            0x08 => 'Flash/Aperture',
            0x0c => 'Flash Only',
        },
    },
    14.1 => { # CSf3-a
        Name => 'FuncButton',
        Mask => 0xf8,
        PrintConv => {
            0x00 => 'None',
            0x08 => 'Preview',
            0x10 => 'FV Lock',
            0x18 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x28 => 'AE Lock (reset on release)',
            0x30 => 'AE Lock (hold)',
            0x38 => 'AF Lock Only',
            0x40 => 'AF-On',
            0x50 => 'Bracketing Burst',
            0x58 => 'Matrix Metering',
            0x60 => 'Center-weighted Metering',
            0x68 => 'Spot Metering',
            0x70 => 'Playback',
            0x78 => 'My Menu Top Item',
            0x80 => '+NEF(RAW)',
            0x88 => 'Virtual Horizon',
            0x90 => 'My Menu',
            0xa0 => 'Grid Display',
            0xa8 => 'Disable Synchronized Release',
            0xb0 => 'Remote Release Only',
            0xd0 => 'Flash Disable/Enable',
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
            0x00 => 'None',
            0x08 => 'Preview',
            0x10 => 'FV Lock',
            0x18 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x28 => 'AE Lock (reset on release)',
            0x30 => 'AE Lock (hold)',
            0x38 => 'AF Lock Only',
            0x40 => 'AF-On',
            0x50 => 'Bracketing Burst',
            0x58 => 'Matrix Metering',
            0x60 => 'Center-weighted Metering',
            0x68 => 'Spot Metering',
            0x70 => 'Playback',
            0x78 => 'My Menu Top Item',
            0x80 => '+NEF(RAW)',
            0x88 => 'Virtual Horizon',
            0x90 => 'My Menu',
            0xa0 => 'Grid Display',
            0xa8 => 'Disable Synchronized Release',
            0xb0 => 'Remote Release Only',
            0xd0 => 'Flash Disable/Enable',
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
            0x00 => 'Autofocus Off, Exposure Off',
            0x20 => 'Autofocus Off, Exposure On',
            0x40 => 'Autofocus Off, Exposure On (Mode A)',
            0x80 => 'Autofocus On, Exposure Off',
            0xa0 => 'Autofocus On, Exposure On',
            0xc0 => 'Autofocus On, Exposure On (Mode A)',
        },
    },
    18.2 => { # CSf10-d
        Name => 'CommandDialsMenuAndPlayback',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'On',
            0x08 => 'Off',
            0x10 => 'On (Image Review Excluded)',
        },
    },
    18.3 => { # CSf10-c
        Name => 'CommandDialsApertureSetting',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Sub-command Dial',
            0x04 => 'Aperture Ring',
        },
    },
    18.4 => { # CSc1
        Name => 'ShutterReleaseButtonAE-L',
        Mask => 0x02,
        PrintConv => { 0x00 => 'Off', 0x02 => 'On' },
    },
    18.5 => { # CSf11
        Name => 'ReleaseButtonToUseDial',
        Mask => 0x01,
        PrintConv => { 0x00 => 'No', 0x01 => 'Yes' },
    },
    19.1 => { # CSc2
        Name => 'StandbyTimer',
        Mask => 0xf0,
        PrintConv => {
            0x00 => '4 s',
            0x10 => '6 s',
            0x30 => '10 s',
            0x50 => '30 s',
            0x60 => '1 min',
            0x70 => '5 min',
            0x80 => '10 min',
            0x90 => '30 min',
        },
    },
    20.1 => { # CSc3-a
        Name => 'SelfTimerTime',
        Mask => 0xc0,
        PrintConv => {
            0x00 => '2 s',
            0x40 => '5 s',
            0x80 => '10 s',
            0xc0 => '20 s',
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
            0x00 => '0.5 s',
            0x10 => '1 s',
            0x20 => '2 s',
            0x30 => '3 s',
        },
    },
    21.1 => { # CSc4-d
        Name => 'ImageReviewMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '2 s',
            0x20 => '4 s',
            0x40 => '10 s',
            0x60 => '20 s',
            0x80 => '1 min',
            0xa0 => '5 min',
            0xc0 => '10 min',

        },
    },
    21.2 => { # CSc4-e
        Name => 'LiveViewMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '5 min',
            0x04 => '10 min',
            0x08 => '15 min',
            0x0c => '20 min',
            0x10 => '30 min',
            0x14 => 'No Limit',
        },
    },
    22.1 => { # CSc4-b
        Name => 'MenuMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    22.2 => { # CSc4-c
        Name => 'ShootingInfoMonitorOffTime',
        Mask => 0x1c,
        PrintConv => {
            0x00 => '4 s',
            0x04 => '10 s',
            0x08 => '20 s',
            0x0c => '1 min',
            0x10 => '5 min',
            0x14 => '10 min',
        },
    },
    23.1 => { # CSe1
        Name => 'FlashSyncSpeed',
        Mask => 0xf0,
        PrintConv => {
            # 0x00 - seen for D4 (PH)
            0x10 => '1/250 s (auto FP)',
            0x20 => '1/250 s',
            0x30 => '1/200 s',
            0x40 => '1/160 s',
            0x50 => '1/125 s',
            0x60 => '1/100 s',
            0x70 => '1/80 s',
            0x80 => '1/60 s',
        },
    },
    23.2 => { # CSe2
        Name => 'FlashShutterSpeed',
        Mask => 0x0f,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => '1/60 s',
            0x01 => '1/30 s',
            0x02 => '1/15 s',
            0x03 => '1/8 s',
            0x04 => '1/4 s',
            0x05 => '1/2 s',
            0x06 => '1 s',
            0x07 => '2 s',
            0x08 => '4 s',
            0x09 => '8 s',
            0x0a => '15 s',
            0x0b => '30 s',
        },
    },
    31.1 => { # CSe5
        Name => 'ModelingFlash',
        Mask => 0x20,
        PrintConv => {
            0x00 => 'On',
            0x20 => 'Off',
        },
    },
    36.1 => { # CSc4-a
        Name => 'PlaybackMonitorOffTime',
        Mask => 0xe0,
        PrintConv => {
            0x00 => '4 s',
            0x20 => '10 s',
            0x40 => '20 s',
            0x60 => '1 min',
            0x80 => '5 min',
            0xa0 => '10 min',
        },
    },
    37.1 => { # CSf15
        Name => 'PlaybackZoom',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Use Separate Zoom Buttons',
            0x01 => 'Use Either Zoom Button with Command Dial',
        },
    },
    38.1 => { # CSf8-a
        Name => 'ShutterSpeedLock',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    38.2 => { # CSf8-b
        Name => 'ApertureLock',
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Off',
            0x40 => 'On',
        },
    },
    38.3 => { # CSg4
        Name => 'MovieShutterButton',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Take Photo',
            0x10 => 'Record Movies',
            0x20 => 'Live Frame Grab',
        },
    },
    38.4 => { # CSe4
        Name => 'FlashExposureCompArea',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Entire frame',
            0x04 => 'Background only',
        },
    },
    41.1 => { # CSg1-a
        Name => 'MovieFunctionButton',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'None',
            0x10 => 'Power Aperture (open)', # bit '02' is also toggled on for this setting
            0x30 => 'Index Marking',
            0x40 => 'View Photo Shooting Info',
        },
    },
    41.2 => { # CSg2-a
        Name => 'MoviePreviewButton',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'None',
            0x02 => 'Power Aperture (open)', # bit '10' is also toggled on for this setting
            0x03 => 'Index Marking',
            0x04 => 'View Photo Shooting Info',
        },
    },
    42.1 => { # CSf14
        Name => 'VerticalMultiSelector',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Same as Multi-Selector with Info(U/D) & Playback(R/L)',
            0x20 => 'Same as Multi-Selector with Info(R/L) & Playback(U/D)',
            0x40 => 'Focus Point Selection',
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
            0x00 => 'None',
            0x10 => 'Choose Image Area (FX/DX/5:4)',
            0x20 => 'Shutter Speed & Aperture Lock',
            0x30 => 'One Step Speed / Aperture',
            0x40 => 'Choose Non-CPU Lens Number',
            0x50 => 'Active D-Lighting',
            0x60 => 'Shooting Bank Menu',
            0x70 => 'ISO Sensitivity',
            0x80 => 'Exposure Mode',
            0x90 => 'Exposure Compensation',
            0xa0 => 'Metering',
            },
    },
    43.2 => { # CSf16
        Name => 'AssignMovieRecordButton',
        Mask => 0x07,
        PrintConv => {
            0x00 => 'None',
            0x01 => 'Choose Image Area (FX/DX/5:4)',
            0x02 => 'Shutter Speed & Aperture Lock',
            0x03 => 'ISO Sensitivity',
            0x04 => 'Shooting Bank Menu',
        },
    },
    46.1 => { # CSa5-c
        Name => 'DynamicAreaAFDisplay',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    46.2 => { # CSa5-a
        Name => 'AFPointIllumination',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Off',
            0x20 => 'On in Continuous Shooting Modes',
            0x40 => 'On During Manual Focusing',
            0x60 => 'On in Continuous Shooting and Manual Focusing',
        },
    },
    46.3 => { # CSa10 (D4 is slightly different -- needs checking)
        Name => 'StoreByOrientation',
        Mask => 0x18,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'Focus Point',
            0x10 => 'Focus Point and AF-area mode',
        },
    },
    46.4 => { # CSa5-d
        Name => 'GroupAreaAFIllumination',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Squares',
            0x04 => 'Dots',
        },
    },
    46.5 => { # CSa5-b
        Name => 'AFPointBrightness',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Low',
            0x01 => 'Normal',
            0x02 => 'High',
            0x03 => 'Extra High',
        },
    },
    47.1 => { # CSa8
        Name => 'AFOnButton',
        Mask => 0x70,
        PrintConv => {
            0x00 => 'AF On',
            0x10 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x30 => 'AE Lock (reset on release)',
            0x40 => 'AE Lock (hold)',
            0x50 => 'AF Lock Only',
            0x60 => 'None',
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
            0x00 => 'Focus Point Selection',
            0x80 => 'Same As Multi-selector',
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
            0x00 => 'None',
            0x08 => 'Preview',
            0x10 => 'FV Lock',
            0x18 => 'AE/AF Lock',
            0x20 => 'AE Lock Only',
            0x28 => 'AE Lock (reset on release)',
            0x30 => 'AE Lock (hold)',
            0x38 => 'AF Lock Only',
            0x40 => 'AF-On',
            # 0x48 - seen for D4 (PH)
            0x50 => 'Bracketing Burst',
            0x58 => 'Matrix Metering',
            0x60 => 'Center-weighted Metering',
            0x68 => 'Spot Metering',
            0x70 => 'Playback',
            0x78 => 'My Menu Top Item',
            0x80 => '+NEF(RAW)',
            0x88 => 'Virtual Horizon',
            0x90 => 'My Menu',
            0x98 => 'Reset',    # value appears to be specific to this control at this time
            0xa0 => 'Grid Display',
            0xa8 => 'Disable Synchronized Release',
            0xb0 => 'Remote Release Only',
            0xb8 => 'Preview',  # value appears to be specific to this control at this time
            0xd0 => 'Flash Disable/Enable',
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
            0x00 => 'Face Detection On',
            0x80 => 'Face Detection Off',
        },
    },
    50.2 => { # CSf17
        Name => 'LiveViewButtonOptions',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x30,
        PrintConv => {
            0x00 => 'Enable',
            0x10 => 'Enable (standby time active)',
            0x20 => 'Disable',
        },
    },
    50.3 => { # CSa12
        Name => 'AFModeRestrictions',
        Condition => '$$self{Model} =~ /\bD4S/',
        Notes => 'D4S only',
        Mask => 0x03,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'AF-C',
            0x02 => 'AF-S',
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
                1 => 'Auto-area',
                2 => 'Group-area',
                3 => '3D-tracking',
                4 => 'Dynamic area (51 points)',
                5 => 'Dynamic area (21 points)',
                6 => 'Dynamic area (9 points)',
            },
        },
    },
    52.1 => { # CSg1-b
        Name => 'MovieFunctionButtonPlusDials',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'None',
            0x10 => 'Choose Image Area',
        },
    },
    52.2 => { # CSg2-b
        Name => 'MoviePreviewButtonPlusDials',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'None',
            0x01 => 'Choose Image Area',
        },
    },
    53.1 => { # CSg3-b
        Name => 'MovieSubSelectorAssignmentPlusDials',
        Mask => 0x10,
        PrintConv => {
            0x00 => 'None',
            0x10 => 'Choose Image Area',
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

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Jens Duttke and Warren Hatch for their help decoding the D300 and
D3 custom settings.  And thanks to the customer service personnel at Best
Buy for not bugging me while I spent lots of time playing with their
cameras.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
