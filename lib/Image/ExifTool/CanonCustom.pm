#------------------------------------------------------------------------------
# File:         CanonCustom.pm
#
# Description:  Read and write Canon Custom functions
#
# Revisions:    11/25/2003  - P. Harvey Created
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Christian Koller private communication (20D)
#               3) Rainer Honle private communication (5D)
#               4) David Pitcher private communication (1DmkIII firmware upgrade)
#------------------------------------------------------------------------------

package Image::ExifTool::CanonCustom;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);
use Image::ExifTool::Canon;
use Image::ExifTool::Exif;

$VERSION = '1.55';

sub ProcessCanonCustom($$$);
sub ProcessCanonCustom2($$$);
sub WriteCanonCustom($$$);
sub WriteCanonCustom2($$$);
sub CheckCanonCustom($$$);
sub ConvertPFn($);
sub ConvertPFnInv($);

my %onOff = ( 0 => 'On', 1 => 'Off' );
my %offOn = ( 0 => 'Off', 1 => 'On' );
my %disableEnable = ( 0 => 'Disable', 1 => 'Enable' );
my %enableDisable = ( 0 => 'Enable', 1 => 'Disable' );
my %convPFn = ( PrintConv => \&ConvertPfn, PrintConvInv => \&ConvertPfnInv );

#------------------------------------------------------------------------------
# Custom functions for the 1D
# CanonCustom (keys are custom function number)
%Image::ExifTool::CanonCustom::Functions1D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    NOTES => q{
        These custom functions are used by all 1D models up to but not including the
        Mark III.
    },
    0 => {
        Name => 'FocusingScreen',
        PrintConv => {
            0 => 'Ec-N, R',
            1 => 'Ec-A,B,C,CII,CIII,D,H,I,L',
        },
    },
    1 => {
        Name => 'FinderDisplayDuringExposure',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'ShutterReleaseNoCFCard',
        Description => 'Shutter Release W/O CF Card',
        PrintConv => {
            0 => 'Yes',
            1 => 'No',
        },
    },
    3 => {
        Name => 'ISOSpeedExpansion',
        Description => 'ISO Speed Expansion',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    4 => {
        Name => 'ShutterAELButton',
        Description => 'Shutter Button/AEL Button',
        PrintConv => {
            0 => 'AF/AE lock stop',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'ManualTv',
        Description => 'Manual Tv/Av For M',
        PrintConv => {
            0 => 'Tv=Main/Av=Control',
            1 => 'Tv=Control/Av=Main',
            2 => 'Tv=Main/Av=Main w/o lens',
            3 => 'Tv=Control/Av=Main w/o lens',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3-stop set, 1/3-stop comp.',
            1 => '1-stop set, 1/3-stop comp.',
            2 => '1/2-stop set, 1/2-stop comp.',
        },
    },
    7 => {
        Name => 'USMLensElectronicMF',
        PrintConv => {
            0 => 'Turns on after one-shot AF',
            1 => 'Turns off after one-shot AF',
            2 => 'Always turned off',
        },
    },
    8 => {
        Name => 'LCDPanels',
        Description => 'Top/Back LCD Panels',
        PrintConv => {
            0 => 'Remain. shots/File no.',
            1 => 'ISO/Remain. shots',
            2 => 'ISO/File no.',
            3 => 'Shots in folder/Remain. shots',
        },
    },
    9 => {
        Name => 'AEBSequenceAutoCancel',
        Description => 'AEB Sequence/Auto Cancel',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'AFPointIllumination',
        PrintConv => {
            0 => 'On',
            1 => 'Off',
            2 => 'On without dimming',
            3 => 'Brighter',
        },
    },
    11 => {
        Name => 'AFPointSelection',
        PrintConv => {
            0 => 'H=AF+Main/V=AF+Command',
            1 => 'H=Comp+Main/V=Comp+Command',
            2 => 'H=Command only/V=Assist+Main',
            3 => 'H=FEL+Main/V=FEL+Command',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AFPointSpotMetering',
        Description => 'No. AF Points/Spot Metering',
        PrintConv => {
            0 => '45/Center AF point',
            1 => '11/Active AF point',
            2 => '11/Center AF point',
            3 => '9/Active AF point',
        },
    },
    14 => {
        Name => 'FillFlashAutoReduction',
        PrintConv => \%enableDisable,
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'AFPointActivationArea',
        PrintConv => {
            0 => 'Single AF point',
            1 => 'Expanded (TTL. of 7 AF points)',
            2 => 'Automatic expanded (max. 13)',
        },
    },
    18 => {
        Name => 'SwitchToRegisteredAFPoint',
        PrintConv => {
            0 => 'Assist + AF',
            1 => 'Assist',
            2 => 'Only while pressing assist',
        },
    },
    19 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'AF mode: ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    20 => {
        Name => 'AIServoTrackingSensitivity',
        PrintConv => {
            0 => 'Standard',
            1 => 'Slow',
            2 => 'Moderately slow',
            3 => 'Moderately fast',
            4 => 'Fast',
        },
    },
    21 => {
        Name => 'AIServoContinuousShooting',
        PrintConv => {
            0 => 'Shooting not possible without focus',
            1 => 'Shooting possible without focus',
        },
    },
);

# Custom functions for the 5D (ref 3)
%Image::ExifTool::CanonCustom::Functions5D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'FocusingScreen',
        PrintConv => {
            0 => 'Ee-A',
            1 => 'Ee-D',
            2 => 'Ee-S',
        },
    },
    1 => {
        Name => 'SetFunctionWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Change quality',
            2 => 'Change Parameters',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    2 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    3 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    4 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    7 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    8 => {
        Name => 'ISOExpansion',
        PrintConv => \%offOn,
    },
    9 => {
        Name => 'AEBSequenceAutoCancel',
        Description => 'AEB Sequence/Auto Cancel',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    11 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AFPointSelectionMethod',
        PrintConv => {
            0 => 'Normal',
            1 => 'Multi-controller direct',
            2 => 'Quick Control Dial direct',
        },
    },
    14 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'AFPointActivationArea',
        PrintConv => {
            0 => 'Standard',
            1 => 'Expanded',
        },
    },
    18 => {
        Name => 'LCDDisplayReturnToShoot',
        PrintConv => {
            0 => 'With Shutter Button only',
            1 => 'Also with * etc.',
        },
    },
    19 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    20 => {
        Name => 'AddOriginalDecisionData',
        PrintConv => \%offOn,
    },
);

# Custom functions for 10D
%Image::ExifTool::CanonCustom::Functions10D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    1 => {
        Name => 'SetButtonWhenShooting',
        PrintConv => {
            0 => 'Normal (disabled)',
            1 => 'Image quality',
            2 => 'Change parameters',
            3 => 'Menu display',
            4 => 'Image playback',
        },
    },
    2 => {
        Name => 'ShutterReleaseNoCFCard',
        Description => 'Shutter Release W/O CF Card',
        PrintConv => {
            0 => 'Yes',
            1 => 'No',
        },
    },
    3 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    4 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'AFAssist',
        Description => 'AF Assist/Flash Firing',
        PrintConv => {
            0 => 'Emits/Fires',
            1 => 'Does not emit/Fires',
            2 => 'Only ext. flash emits/Fires',
            3 => 'Emits/Does not fire',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/2 Stop',
            1 => '1/3 Stop',
        },
    },
    7 => {
        Name => 'AFPointRegistration',
        PrintConv => {
            0 => 'Center',
            1 => 'Bottom',
            2 => 'Right',
            3 => 'Extreme Right',
            4 => 'Automatic',
            5 => 'Extreme Left',
            6 => 'Left',
            7 => 'Top',
        },
    },
    8 => {
        Name => 'RawAndJpgRecording',
        PrintConv => {
            0 => 'RAW+Small/Normal',
            1 => 'RAW+Small/Fine',
            2 => 'RAW+Medium/Normal',
            3 => 'RAW+Medium/Fine',
            4 => 'RAW+Large/Normal',
            5 => 'RAW+Large/Fine',
        },
    },
    9 => {
        Name => 'AEBSequenceAutoCancel',
        Description => 'AEB Sequence/Auto Cancel',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    11 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AssistButtonFunction',
        PrintConv => {
            0 => 'Normal',
            1 => 'Select Home Position',
            2 => 'Select HP (while pressing)',
            3 => 'Av+/- (AF point by QCD)',
            4 => 'FE lock',
        },
    },
    14 => {
        Name => 'FillFlashAutoReduction',
        PrintConv => \%enableDisable,
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M->Auto/Auto->ctr',
            4 => 'One Shot <-> AI servo',
            5 => 'IS start',
        },
    },
);

# Custom functions for the 20D (ref 2)
%Image::ExifTool::CanonCustom::Functions20D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'SetFunctionWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Change quality',
            2 => 'Change Parameters',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/250 Fixed',
        },
    },
    3 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    4 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only ext. flash emits',
        },
    },
    5 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    6 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    7 => {
        Name => 'ISOExpansion',
        PrintConv => \%offOn,
    },
    8 => {
        Name => 'AEBSequenceAutoCancel',
        Description => 'AEB Sequence/Auto Cancel',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    9 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    10 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    11 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    12 => {
        Name => 'AFPointSelectionMethod',
        PrintConv => {
            0 => 'Normal',
            1 => 'Multi-controller direct',
            2 => 'Quick Control Dial direct',
        },
    },
    13 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    14 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    15 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    16 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    17 => {
        Name => 'AddOriginalDecisionData',
        PrintConv => \%offOn,
    },
);

# Custom functions for the 30D (PH)
%Image::ExifTool::CanonCustom::Functions30D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    1 => {
        Name => 'SetFunctionWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Change quality',
            2 => 'Change Picture Style',
            3 => 'Menu display',
            4 => 'Image replay',
        },
    },
    2 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    3 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/250 Fixed',
        },
    },
    4 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    5 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only ext. flash emits',
        },
    },
    6 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    7 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    8 => {
        Name => 'ISOExpansion',
        PrintConv => \%offOn,
    },
    9 => {
        Name => 'AEBSequenceAutoCancel',
        Description => 'AEB Sequence/Auto Cancel',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    10 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    11 => {
        Name => 'MenuButtonDisplayPosition',
        PrintConv => {
            0 => 'Previous (top if power off)',
            1 => 'Previous',
            2 => 'Top',
        },
    },
    12 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    13 => {
        Name => 'AFPointSelectionMethod',
        PrintConv => {
            0 => 'Normal',
            1 => 'Multi-controller direct',
            2 => 'Quick Control Dial direct',
        },
    },
    14 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    15 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    16 => {
        Name => 'SafetyShiftInAvOrTv',
        PrintConv => \%disableEnable,
    },
    17 => {
        Name => 'MagnifiedView',
        PrintConv => {
            0 => 'Image playback only',
            1 => 'Image review and playback',
        },
    },
    18 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock while metering',
            3 => 'AF point: M -> Auto / Auto -> Ctr.',
            4 => 'ONE SHOT <-> AI SERVO',
            5 => 'IS start',
        },
    },
    19 => {
        Name => 'AddOriginalDecisionData',
        PrintConv => \%offOn,
    },
);

# Custom functions for the 350D (PH)
%Image::ExifTool::CanonCustom::Functions350D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'SetButtonCrossKeysFunc',
        PrintConv => {
            0 => 'Normal',
            1 => 'Set: Quality',
            2 => 'Set: Parameter',
            3 => 'Set: Playback',
            4 => 'Cross keys: AF point select',
        },
    },
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    3 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    4 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only ext. flash emits',
        },
    },
    5 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    6 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    7 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    8 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
);

# Custom functions for the 400D (PH)
%Image::ExifTool::CanonCustom::Functions400D = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    WRITABLE => 'int8u',
    0 => {
        Name => 'SetButtonCrossKeysFunc',
        PrintConv => {
            0 => 'Set: Picture Style',
            1 => 'Set: Quality',
            2 => 'Set: Flash Exposure Comp',
            3 => 'Set: Playback',
            4 => 'Cross keys: AF point select',
        },
    },
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    2 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    3 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock, No AE lock',
            3 => 'AE/AF, No AE lock',
        },
    },
    4 => {
        Name => 'AFAssistBeam',
        PrintConv => {
            0 => 'Emits',
            1 => 'Does not emit',
            2 => 'Only ext. flash emits',
        },
    },
    5 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1/2 Stop',
        },
    },
    6 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    7 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    8 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    9 => {
        Name => 'MagnifiedView',
        PrintConv => {
            0 => 'Image playback only',
            1 => 'Image review and playback',
        },
    },
    10 => {
        Name => 'LCDDisplayAtPowerOn',
        PrintConv => {
            0 => 'Display',
            1 => 'Retain power off status',
        },
    },
);

# Custom functions for the D30/D60
%Image::ExifTool::CanonCustom::FunctionsD30 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
    WRITE_PROC => \&WriteCanonCustom,
    CHECK_PROC => \&CheckCanonCustom,
    NOTES => 'Custom functions for the EOS D30 and D60.',
    WRITABLE => 'int8u',
    1 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'Shutter-AELock',
        PrintConv => {
            0 => 'AF/AE lock',
            1 => 'AE lock/AF',
            2 => 'AF/AF lock',
            3 => 'AE+release/AE+AF',
        },
    },
    3 => {
        Name => 'MirrorLockup',
        PrintConv => \%disableEnable,
    },
    4 => {
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            0 => '1/2 Stop',
            1 => '1/3 Stop',
        },
    },
    5 => {
        Name => 'AFAssist',
        PrintConv => {
            0 => 'Emits/Fires',
            1 => 'Does not emit/Fires',
            2 => 'Only ext. flash emits/Fires',
            3 => 'Emits/Does not fire',
        },
    },
    6 => {
        Name => 'FlashSyncSpeedAv',
        PrintConv => {
            0 => 'Auto',
            1 => '1/200 Fixed',
        },
    },
    7 => {
        Name => 'AEBSequenceAutoCancel',
        Description => 'AEB Sequence/Auto Cancel',
        PrintConv => {
            0 => '0,-,+/Enabled',
            1 => '0,-,+/Disabled',
            2 => '-,0,+/Enabled',
            3 => '-,0,+/Disabled',
        },
    },
    8 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    9 => {
        Name => 'LensAFStopButton',
        PrintConv => {
            0 => 'AF Stop',
            1 => 'Operate AF',
            2 => 'Lock AE and start timer',
        },
    },
    10 => {
        Name => 'FillFlashAutoReduction',
        PrintConv => \%enableDisable,
    },
    11 => {
        Name => 'MenuButtonReturn',
        PrintConv => {
            0 => 'Top',
            1 => 'Previous (volatile)',
            2 => 'Previous',
        },
    },
    12 => {
        Name => 'SetButtonWhenShooting',
        PrintConv => {
            0 => 'Default (no function)',
            1 => 'Image quality',
            2 => 'Change ISO speed',
            3 => 'Change parameters',
        },
    },
    13 => {
        Name => 'SensorCleaning',
        PrintConv => \%disableEnable,
    },
    14 => {
        Name => 'SuperimposedDisplay',
        PrintConv => \%onOff,
    },
    15 => {
        Name => 'ShutterReleaseNoCFCard',
        Description => 'Shutter Release W/O CF Card',
        PrintConv => {
            0 => 'Yes',
            1 => 'No',
        },
    },
);

# Custom functions for unknown cameras
%Image::ExifTool::CanonCustom::FuncsUnknown = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom,
);

# 1D personal function settings (ref PH)
%Image::ExifTool::CanonCustom::PersonalFuncs = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    NOTES => 'Personal function settings for the EOS-1D.',
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    1 => { Name => 'PF0CustomFuncRegistration', %convPFn },
    2 => { Name => 'PF1DisableShootingModes',   %convPFn },
    3 => { Name => 'PF2DisableMeteringModes',   %convPFn },
    4 => { Name => 'PF3ManualExposureMetering', %convPFn },
    5 => { Name => 'PF4ExposureTimeLimits',     %convPFn },
    6 => { Name => 'PF5ApertureLimits',         %convPFn },
    7 => { Name => 'PF6PresetShootingModes',    %convPFn },
    8 => { Name => 'PF7BracketContinuousShoot', %convPFn },
    9 => { Name => 'PF8SetBracketShots',        %convPFn },
    10 => { Name => 'PF9ChangeBracketSequence', %convPFn },
    11 => { Name => 'PF10RetainProgramShift',   %convPFn },
    #12 => { Name => 'PF11Unused',               %convPFn },
    #13 => { Name => 'PF12Unused',               %convPFn },
    14 => { Name => 'PF13DrivePriority',        %convPFn },
    15 => { Name => 'PF14DisableFocusSearch',   %convPFn },
    16 => { Name => 'PF15DisableAFAssistBeam',  %convPFn },
    17 => { Name => 'PF16AutoFocusPointShoot',  %convPFn },
    18 => { Name => 'PF17DisableAFPointSel',    %convPFn },
    19 => { Name => 'PF18EnableAutoAFPointSel', %convPFn },
    20 => { Name => 'PF19ContinuousShootSpeed', %convPFn },
    21 => { Name => 'PF20LimitContinousShots',  %convPFn },
    22 => { Name => 'PF21EnableQuietOperation', %convPFn },
    #23 => { Name => 'PF22Unused',               %convPFn },
    24 => { Name => 'PF23SetTimerLengths',      %convPFn },
    25 => { Name => 'PF24LightLCDDuringBulb',   %convPFn },
    26 => { Name => 'PF25DefaultClearSettings', %convPFn },
    27 => { Name => 'PF26ShortenReleaseLag',    %convPFn },
    28 => { Name => 'PF27ReverseDialRotation',  %convPFn },
    29 => { Name => 'PF28NoQuickDialExpComp',   %convPFn },
    30 => { Name => 'PF29QuickDialSwitchOff',   %convPFn },
    31 => { Name => 'PF30EnlargementMode',      %convPFn },
    32 => { Name => 'PF31OriginalDecisionData', %convPFn },
);

# 1D personal function values (ref PH)
%Image::ExifTool::CanonCustom::PersonalFuncValues = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    1 => 'PF1Value',
    2 => 'PF2Value',
    3 => 'PF3Value',
    4 => {
        Name => 'PF4ExposureTimeMin',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val*4)*log(2))*1000/8',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*8/1000)/log(2))/4',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    5 => {
        Name => 'PF4ExposureTimeMax',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val*4)*log(2))*1000/8',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*8/1000)/log(2))/4',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    6 => {
        Name => 'PF5ApertureMin',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val*4-32)*log(2)/2)',
        ValueConvInv => '(Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))+32)/4',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    7 => {
        Name => 'PF5ApertureMax',
        RawConv => '$val > 0 ? $val : 0',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val*4-32)*log(2)/2)',
        ValueConvInv => '(Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))+32)/4',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    8 => 'PF8BracketShots',
    9 => 'PF19ShootingSpeedLow',
    10 => 'PF19ShootingSpeedHigh',
    11 => 'PF20MaxContinousShots',
    12 => 'PF23ShutterButtonTime',
    13 => 'PF23FELockTime',
    14 => 'PF23PostReleaseTime',
    15 => 'PF25AEMode',
    16 => 'PF25MeteringMode',
    17 => 'PF25DriveMode',
    18 => 'PF25AFMode',
    19 => 'PF25AFPointSel',
    20 => 'PF25ImageSize',
    21 => 'PF25WBMode',
    22 => 'PF25Parameters',
    23 => 'PF25ColorMatrix',
    24 => 'PF27Value',
);

# Custom functions used by the 1D Mark III and later models (ref PH)
%Image::ExifTool::CanonCustom::Functions2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonCustom2,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITE_PROC => \&WriteCanonCustom2,
    WRITABLE => 'int32s',
    NOTES => q{
        Beginning with the EOS 1D Mark III, Canon finally created a set of custom
        function tags which are (reasonably) consistent across models.  The EOS 1D
        Mark III has 57 custom function tags divided into four main groups: 1.
        Exposure (0x0101-0x010f), 2. Image (0x0201-0x0203), Flash Exposure
        (0x0304-0x0306) and Display (0x0407-0x0409), 3. Auto Focus (0x0501-0x050e)
        and Drive (0x060f-0x0611), and 4. Operation (0x0701-0x070a) and Others
        (0x080b-0x0810).  The table below lists tags used by the EOS 1D Mark III, as
        well as newer tags and values added by later models.
    },
    # grouped in 4 groups:
    # 1) Exposure
    0x0101 => [
        {
            Name => 'ExposureLevelIncrements',
            Condition => '$$self{Model} =~ /\b1Ds?\b/',
            Notes => '1DmkIII and 1DmkIV',
            PrintConv => {
                0 => '1/3-stop set, 1/3-stop comp.',
                1 => '1-stop set, 1/3-stop comp.',
                2 => '1/2-stop set, 1/2-stop comp.',
            },
        },
        {
            Name => 'ExposureLevelIncrements',
            Notes => 'other models',
            PrintConv => {
                0 => '1/3 Stop',
                1 => '1/2 Stop',
            },
        },
    ],
    0x0102 => {
        Name => 'ISOSpeedIncrements',
        PrintConv => {
            0 => '1/3 Stop',
            1 => '1 Stop',
        },
    },
    0x0103 => [
        {
            Name => 'ISOSpeedRange',
            Condition => '$$self{Model} =~ /\b1D/',
            Notes => '1DmkIII and 1DmkIV',
            Count => 3,
            # (this decoding may not be valid for CR2 images?)
            ValueConv => [
                undef,
                # this may also be set to "H" (Hi6400) -- is this the -1 value I see? - PH
                '$val < 2 ? $val : ($val < 1000 ? exp(($val/8-9)*log(2))*100 : 0)', # (educated guess)
                # this may also be set to "L" (Lo50) -- is this the 1 value I see? - PH
                '$val < 2 ? $val : ($val < 1000 ? exp(($val/8-9)*log(2))*100 : 0)', # (educated guess)
            ],
            ValueConvInv => [
                undef,
                '$val < 2 ? $val : int(8*(log($val/100)/log(2)+9) + 0.5)',
                '$val < 2 ? $val : int(8*(log($val/100)/log(2)+9) + 0.5)',
            ],
            PrintConv => [
                \%disableEnable,
                'sprintf("Max %.0f",$val)',
                'sprintf("Min %.0f",$val)',
            ],
            PrintConvInv => [
                undef,
                '$val=~/(-?[\d.]+)/ ? $1 : 0',
                '$val=~/(-?[\d.]+)/ ? $1 : 0',
            ],
        },
        {
            Name => 'ISOExpansion',
            Notes => 'other models',
            PrintConv => \%offOn,
        },
    ],
    0x0104 => {
        Name => 'AEBAutoCancel',
        PrintConv => \%onOff,
    },
    0x0105 => {
        Name => 'AEBSequence',
        Notes => 'value of 2 not used by 40D, 50D, 60D, 5DmkII and 7D',
        PrintConv => {
            0 => '0,-,+',
            1 => '-,0,+',
            2 => '+,0,-',
        },
    },
    0x0106 => [{
        Name => 'AEBShotCount',
        Condition => '$count == 1',
        Notes => 'one value for some models...',
        PrintConv => {
            0 => '3 shots',
            1 => '2 shots',
            2 => '5 shots',
            3 => '7 shots',
        },
    },{
        Name => 'AEBShotCount',
        Count => 2,
        Notes => 'two values for others',
        PrintConv => {
            '3 0' => '3 shots',
            '2 1' => '2 shots',
            '5 2' => '5 shots',
            '7 3' => '7 shots',
        },
    }],
    0x0107 => {
        Name => 'SpotMeterLinkToAFPoint',
        PrintConv => {
            0 => 'Disable (use center AF point)',
            1 => 'Enable (use active AF point)',
        },
    },
    0x0108 => {
        Name => 'SafetyShift',
        Notes => 'value of 2 not used by 40D, 50D, 60D, 5DmkII and 7D',
        PrintConv => {
            0 => 'Disable',
            1 => 'Enable (Tv/Av)',
            2 => 'Enable (ISO speed)',
        },
    },
    0x0109 => {
        Name => 'UsableShootingModes',
        Count => 2,
        PrintConv => [
            \%disableEnable,
            'sprintf("Flags 0x%x",$val)', # (M, Tv, Av, P, Bulb)
        ],
        PrintConvInv => [
            undef,
            '$val=~/0x([\dA-F]+)/i ? hex($1) : undef',
        ],
    },
    0x010a => {
        Name => 'UsableMeteringModes',
        Count => 2,
        PrintConv => [
            \%disableEnable,
            'sprintf("Flags 0x%x",$val)', # (evaluative,partial,spot,center-weighted average)
        ],
        PrintConvInv => [
            undef,
            '$val=~/0x([\dA-F]+)/i ? hex($1) : undef',
        ],
    },
    0x010b => {
        Name => 'ExposureModeInManual',
        PrintConv => {
            0 => 'Specified metering mode',
            1 => 'Evaluative metering',
            2 => 'Partial metering',
            3 => 'Spot metering',
            4 => 'Center-weighted average',
        },
    },
    0x010c => [{
        Name => 'ShutterSpeedRange',
        Condition => '$count == 3',
        Count => 3,
        ValueConv => [
            undef,
            'exp(-($val/8-7)*log(2))',
            'exp(-($val/8-7)*log(2))',
        ],
        ValueConvInv => [
            undef,
            'int(-8*(log($val)/log(2)-7) + 0.5)',
            'int(-8*(log($val)/log(2)-7) + 0.5)',
        ],
        PrintConv => [
            \%disableEnable,
            '"Hi " . Image::ExifTool::Exif::PrintExposureTime($val)',
            '"Lo " . Image::ExifTool::Exif::PrintExposureTime($val)',
        ],
        PrintConvInv => [
            undef,
            '$val=~m{([\d./]+)} ? eval $1 : 0',
            '$val=~m{([\d./]+)} ? eval $1 : 0',
        ],
    },{ # (EOS R)
        Name => 'ShutterSpeedRange',
        Condition => '$count == 4',
        Count => 4,
        ValueConv => [ # (NC)
            'exp(-$val/(1600*log(2)))',
            'exp(-$val/(1600*log(2)))',
            'exp(-$val/(1600*log(2)))',
            'exp(-$val/(1600*log(2)))',
        ],
        ValueConvInv => [
            'int(-log($val)*1600*log(2) + 0.5)',
            'int(-log($val)*1600*log(2) + 0.5)',
            'int(-log($val)*1600*log(2) + 0.5)',
            'int(-log($val)*1600*log(2) + 0.5)',
        ],
        PrintConv => [ # (NC)
            '"Manual: Hi " . Image::ExifTool::Exif::PrintExposureTime($val)',
            '"Lo " . Image::ExifTool::Exif::PrintExposureTime($val)',
            '"Auto: Hi " . Image::ExifTool::Exif::PrintExposureTime($val)',
            '"Lo " . Image::ExifTool::Exif::PrintExposureTime($val)',
        ],
        PrintConvInv => [
            '$val=~m{([\d./]+)} ? eval $1 : 0',
            '$val=~m{([\d./]+)} ? eval $1 : 0',
            '$val=~m{([\d./]+)} ? eval $1 : 0',
            '$val=~m{([\d./]+)} ? eval $1 : 0',
        ],
    }],
    0x010d => [{
        Name => 'ApertureRange',
        Condition => '$count == 3',
        Count => 3,
        ValueConv => [
            undef,
            'exp(($val/8-1)*log(2)/2)',
            'exp(($val/8-1)*log(2)/2)',
        ],
        ValueConvInv => [
            undef,
            'int(8*(log($val)*2/log(2)+1) + 0.5)',
            'int(8*(log($val)*2/log(2)+1) + 0.5)',
        ],
        PrintConv => [
            \%disableEnable,
            'sprintf("Closed %.2g",$val)',
            'sprintf("Open %.2g",$val)',
        ],
        PrintConvInv => [
            undef,
            '$val=~/([\d.]+)/ ? $1 : 0',
            '$val=~/([\d.]+)/ ? $1 : 0',
        ],
    },{ # (EOS R)
        Name => 'ApertureRange',
        Condition => '$count == 4',
        Count => 4,
        ValueConv => [ # (NC)
            'exp($val/2400)',
            'exp($val/2400)',
            'exp($val/2400)',
            'exp($val/2400)',
        ],
        ValueConvInv => [
            'int(log($val)*2400) + 0.5)',
            'int(log($val)*2400) + 0.5)',
            'int(log($val)*2400) + 0.5)',
            'int(log($val)*2400) + 0.5)',
        ],
        PrintConv => [ # (NC)
            'sprintf("Manual: Closed %.2g",$val)',
            'sprintf("Open %.2g",$val)',
            'sprintf("Auto: Closed %.2g",$val)',
            'sprintf("Open %.2g",$val)',
        ],
        PrintConvInv => [
            '$val=~/([\d.]+)/ ? $1 : 0',
            '$val=~/([\d.]+)/ ? $1 : 0',
            '$val=~/([\d.]+)/ ? $1 : 0',
            '$val=~/([\d.]+)/ ? $1 : 0',
        ],
    }],
    0x010e => {
        Name => 'ApplyShootingMeteringMode',
        Count => 8,
        PrintConv => [ \%disableEnable ],
    },
    0x010f => [
        {
            Name => 'FlashSyncSpeedAv',
            Condition => '$$self{Model} =~ /\b(40D|1Ds Mark III)\b/',
            Notes => '40D and 1Ds Mark III',
            PrintConv => {
                0 => 'Auto',
                1 => '1/250 Fixed',
            },
        },
        {
            Name => 'FlashSyncSpeedAv',
            Condition => '$$self{Model} =~ /\b(50D|60D|7D)\b/',
            Notes => '50D, 60D and 7D',
            PrintConv => {
                0 => 'Auto',
                1 => '1/250-1/60 Auto',
                2 => '1/250 Fixed',
            },
        },
        {
            Name => 'FlashSyncSpeedAv',
            Condition => '$$self{Model} =~ /\b(450D|XSi|Kiss X2|1000D|XS|Kiss F)\b/',
            Notes => '450D and 1000D',
            PrintConv => {
                0 => 'Auto',
                1 => '1/200 Fixed',
            },
        },
        {
            Name => 'FlashSyncSpeedAv',
            Condition => '$$self{Model} =~ /\bEOS-1Ds? Mark III\b/',
            Notes => '1D Mark III and 1Ds Mark III',
            PrintConv => {
                0 => 'Auto',
                1 => '1/300 Fixed',
            },
        },
        {
            Name => 'FlashSyncSpeedAv',
            Condition => '$$self{Model} =~ /\bEOS-1D Mark IV\b/',
            Notes => '1D Mark IV',
            PrintConv => {
                0 => 'Auto',
                1 => '1/300-1/60 Auto',
                2 => '1/300 Fixed',
            },
        },
        {
            Name => 'FlashSyncSpeedAv',
            Notes => '5D Mark II, 5D Mark III, 500D, 550D, 600D and 1100D',
            PrintConv => {
                0 => 'Auto',
                1 => '1/200-1/60 Auto',
                2 => '1/200 Fixed',
            },
        },
    ],
    0x0110 => { # new for 1DmkIV
        Name => 'AEMicroadjustment',
        Count => 3,
        PrintConv => [ \%disableEnable ],
    },
    0x0111 => { # new for 1DmkIV
        Name => 'FEMicroadjustment',
        Count => 3,
        PrintConv => [ \%disableEnable ],
    },
    0x0112 => [{ # (5DS)
        Name => 'SameExposureForNewAperture',
        PrintConv => {
            0 => 'Disable',
            1 => 'ISO Speed',
            2 => 'Shutter Speed',
        },
    },{ # (EOS R)
        Name => 'SameExposureForNewAperture',
        Notes => 'EOS R',
        PrintConv => {
            0 => 'Disable',
            1 => 'ISO Speed',
            2 => 'ISO Speed/Shutter Speed',
            3 => 'Shutter Speed',
        },
    }],
    0x0113 => { # (200D)
        Name => 'ExposureCompAutoCancel',
        PrintConv => \%enableDisable,
    },
    0x0114 => { # (R)
        Name => 'AELockMeterModeAfterFocus',
        # metering modes where AE lock after focus applies:
        PrintConv => { BITMASK => { # (NC)
            0 => 'Evaluative',
            1 => 'Partial',
            2 => 'Spot',
            3 => 'Center-weighted',
        }},
    },
    #### 2a) Image
    0x0201 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    0x0202 => [
        {
            Name => 'HighISONoiseReduction',
            Condition => q{
                $$self{Model} =~ /\b(50D|60D|5D Mark II|7D|500D|T1i|Kiss X3|550D|T2i|Kiss X4)\b/ or
                $$self{Model} =~ /\b(600D|T3i|Kiss X5|1100D|T3|Kiss X50)\b/
            },
            Notes => '50D, 60D, 500D, 550D, 600D, 1100D, 5DmkII and 7D',
            PrintConv => {
                0 => 'Standard',
                1 => 'Low',
                2 => 'Strong',
                3 => 'Off',
            },
        },
        {
            Name => 'HighISONoiseReduction',
            Notes => 'other models',
            PrintConv => \%offOn,
        },
    ],
    0x0203 => {
        Name => 'HighlightTonePriority',
        PrintConv => \%disableEnable
    },
    0x0204 => [
        {
            Name => 'AutoLightingOptimizer',
            Condition => '$$self{Model} =~ /\b(50D|5D Mark II|500D|T1i|Kiss X3|1D Mark IV)\b/',
            Notes => '50D, 500D, 5DmkII and 1DmkIV',
            PrintConv => {
                0 => 'Standard',
                1 => 'Low',
                2 => 'Strong',
                3 => 'Disable',
            },
        },
        {
            Name => 'AutoLightingOptimizer',
            Notes => 'other models',
            PrintConv => \%enableDisable,
        },
    ],
    # 0x0205 - Added in 5DmkII firmware update
    #### 2b) Flash exposure
    0x0304 => {
        Name => 'ETTLII',
        Description => 'E-TTL II',
        PrintConv => {
            0 => 'Evaluative',
            1 => 'Average',
        },
    },
    0x0305 => {
        Name => 'ShutterCurtainSync',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    0x0306 => {
        Name => 'FlashFiring',
        PrintConv => {
            0 => 'Fires',
            1 => 'Does not fire',
        },
    },
    #### 2c) Display
    0x0407 => {
        Name => 'ViewInfoDuringExposure',
        PrintConv => \%disableEnable,
    },
    0x0408 => {
        Name => 'LCDIlluminationDuringBulb',
        PrintConv => \%offOn,
    },
    0x0409 => [
        {
            Name => 'InfoButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b1Ds? Mark III\b/',
            Notes => '1D Mark III',
            PrintConv => {
                0 => 'Displays camera settings',
                1 => 'Displays shooting functions',
            },
        },
        {
            Name => 'InfoButtonWhenShooting',
            Notes => '1D Mark IV',
            PrintConv => {
                # reversed from earlier models. grr...
                0 => 'Displays shooting functions',
                1 => 'Displays camera settings',
            },
        },
    ],
    0x040a => { # new for 5DmkIII
        Name => 'ViewfinderWarnings',
        PrintConv => { BITMASK => { #(NC)
            0 => 'Monochrome',              # (have seen for: 5DmkII, 6D)
            1 => 'WB corrected',            # (have seen for: 5DmkII, 6D)
            2 => 'One-touch image quality', # (have seen for: 5DmkII; doesn't exist for 6D)
            3 => 'ISO expansion',           # (have seen for: 5DmkII)
            4 => 'Spot metering',           # (have seen for: 5DmkII, 6D)
        }},
    },
    0x040b => { # new for 5DmkIII
        Name => 'LVShootingAreaDisplay',
        PrintConv => {
            0 => 'Masked',
            1 => 'Outlined',
        },
    },
    0x040c => { # (7DmkII)
        Name => 'LVShootingAreaDisplay',
        PrintConv => {
            0 => 'Masked',
            1 => 'Outlined',
        },
    },
    #### 3a) Auto focus
    0x0501 => {
        Name => 'USMLensElectronicMF',
        PrintConv => {
            0 => 'Enable after one-shot AF',
            1 => 'Disable after one-shot AF',
            2 => 'Disable in AF mode',
        },
    },
    0x0502 => {
        Name => 'AIServoTrackingSensitivity',
        PrintConv => {
           -2 => 'Slow',        # (Locked on -2 for 6D)
           -1 => 'Medium Slow', # (Locked on -1 for 6D)
            0 => 'Standard',
            1 => 'Medium Fast', # (Responsive +1 for 6D)
            2 => 'Fast',        # (Responsive +2 for 6D)
        },
    },
    0x0503 => {
        Name => 'AIServoImagePriority',
        PrintConv => {
            0 => '1: AF, 2: Tracking',
            1 => '1: AF, 2: Drive speed',
            2 => '1: Release, 2: Drive speed',
            3 => '1: Release, 2: Tracking', # 7D/1DmkIV
        },
    },
    0x0504 => {
        Name => 'AIServoTrackingMethod',
        PrintConv => {
            0 => 'Main focus point priority',
            1 => 'Continuous AF track priority',
        },
    },
    0x0505 => {
        Name => 'LensDriveNoAF',
        PrintConv => {
            0 => 'Focus search on',
            1 => 'Focus search off',
        },
    },
    0x0506 => {
        Name => 'LensAFStopButton',
        Notes => 'value of 6 not used by 40D, 50D and 5DmkII',
        PrintConv => {
            0 => 'AF stop',
            1 => 'AF start',
            2 => 'AE lock',
            3 => 'AF point: M->Auto/Auto->ctr',
            4 => 'One Shot <-> AI servo',
            5 => 'IS start',
            6 => 'Switch to registered AF point',
            7 => 'Spot AF', # 1DmkIV
        },
    },
    0x0507 => {
        Name => 'AFMicroadjustment',
        Count => 5,
        PrintConv => [
            {
                0 => 'Disable',
                1 => 'Adjust all by same amount',
                2 => 'Adjust by lens',
            },
            # DECODE OTHER VALUES
        ],
    },
    0x0508 => [
        {
            Name => 'AFPointAreaExpansion',
            Condition => '$$self{Model} =~ /\b5D Mark II\b/',
            Notes => '5D Mark II',
            PrintConv => {
                0 => 'Disable',
                1 => 'Enable',
            },
        },
        {
            Name => 'AFPointAreaExpansion',
            Condition => '$$self{Model} =~ /\b1Ds Mark III\b/',
            Notes => '1Ds Mark III',
            PrintConv => {
                0 => 'Disable',
                1 => 'Enable (left/right Assist AF points)',
                2 => 'Enable (surrounding Assist AF points)',
            },
        },
        {
            Name => 'AFPointAreaExpansion',
            Notes => 'other models',
            PrintConv => {
                0 => 'Disable',
                1 => 'Left/right AF points',
                2 => 'Surrounding AF points',
                3 => 'All 45 points area', # 1DmkIV
            },
        },
    ],
    0x0509 => [
        {
            Name => 'SelectableAFPoint',
            Condition => '$$self{Model} =~ /\b1D Mark IV\b/',
            Notes => '1D Mark IV',
            PrintConv => {
                 0 => '45 points',
                 1 => '19 points',
                 2 => '11 points',
                 3 => 'Inner 9 points',
                 4 => 'Outer 9 points',
            },
        },
        {
            Name => 'SelectableAFPoint',
            Notes => 'other models',
            PrintConv => {
                0 => '19 points',
                1 => 'Inner 9 points',
                2 => 'Outer 9 points',
                3 => '19 Points, Multi-controller selectable', #4
                4 => 'Inner 9 Points, Multi-controller selectable', #4
                5 => 'Outer 9 Points, Multi-controller selectable', #4
            },
        },
    ],
    0x050a => [
        {
            Name => 'SwitchToRegisteredAFPoint',
            Condition => '$$self{Model} =~ /\b1D Mark IV\b/',
            Notes => '1D Mark IV',
            PrintConv => {
                0 => 'Disable',
                1 => 'Switch with multi-controller',
                2 => 'Only while AEL is pressed',
            },
        },
        {
            Name => 'SwitchToRegisteredAFPoint',
            Notes => 'other models',
            PrintConv => \%disableEnable,
        },
    ],
    0x050b => {
        Name => 'AFPointAutoSelection',
        PrintConv => {
            0 => 'Control-direct:disable/Main:enable',
            1 => 'Control-direct:disable/Main:disable',
            2 => 'Control-direct:enable/Main:enable',
        },
    },
    0x050c => [
        {
            Name => 'AFPointDisplayDuringFocus',
            Condition => '$$self{Model} =~ /\b1D\b/',
            Notes => '1D models',
            PrintConv => {
                0 => 'On',
                1 => 'Off',
                2 => 'On (when focus achieved)',
            },
        },
        {
            Name => 'AFPointDisplayDuringFocus',
            Notes => 'other models', # (7D, 70D, 750D, 760D)
            PrintConv => {
                0 => 'Selected (constant)',
                1 => 'All (constant)',
                2 => 'Selected (pre-AF, focused)',
                3 => 'Selected (focused)',
                4 => 'Disable display',
            },
        },
    ],
    0x050d => {
        Name => 'AFPointBrightness',
        PrintConv => {
            0 => 'Normal',
            1 => 'Brighter',
        },
    },
    0x050e => [
        {
            Name => 'AFAssistBeam',
            Condition => '$$self{Model} =~ /\b(1D Mark IV|6D)\b/',
            Notes => '1D Mark IV and 6D',
            PrintConv => {
                0 => 'Emits',
                1 => 'Does not emit',
                2 => 'IR AF assist beam only',
            },
        },
        {
            Name => 'AFAssistBeam',
            Notes => 'other models; values 2-3 not used by 1DmkIII or 5DmkII, value 3 new for 7D',
            PrintConv => {
                0 => 'Emits',
                1 => 'Does not emit',
                2 => 'Only ext. flash emits',
                3 => 'IR AF assist beam only', # new for 7D
            },
        },
    ],
    0x050f => [ # new for 40D
        {
            Name => 'AFPointSelectionMethod',
            Condition => '$$self{Model} !~ /\b60D\b/',
            Notes => '40D, 50D and 5DmkII',
            PrintConv => {
                0 => 'Normal',
                1 => 'Multi-controller direct',
                2 => 'Quick Control Dial direct',
            },
        },
        {
            Name => 'AFPointSelectionMethod',
            Notes => '60D',
            PrintConv => {
                0 => 'AF point button: Activate AF Sel; Rear dial: Select AF points',
                1 => 'AF point button: Auto selection; Rear dial: Manual selection',
            },
        },
    ],
    0x0510 => [ # new for 40D
        {
            Name => 'VFDisplayIllumination', # (7D quirk, or decoded incorrectly?)
            Condition => '$$self{Model} =~ /\b7D\b/',
            Notes => '7D',
            PrintConv => {
                0 => 'Auto',
                1 => 'Enable',
                2 => 'Disable',
            },
        },
        {
            Name => 'SuperimposedDisplay',
            Notes => 'other models',
            PrintConv => \%onOff,
        },
    ],
    0x0511 => [ # new for 40D
        {
            Name => 'AFDuringLiveView',
            Condition => '$$self{Model} =~ /\b40D\b/',
            Notes => '40D',
            PrintConv => \%disableEnable,
        },
        {
            Name => 'AFDuringLiveView',
            Notes => '450D and 1000D',
            PrintConv => {
                0 => 'Disable',
                1 => 'Quick mode',
                2 => 'Live mode',
            },
        },
    ],
    0x0512 => { # new for 7D
        Name => 'SelectAFAreaSelectMode',
        PrintConv => [
            {
                0 => 'Disable',
                1 => 'Enable',
                2 => 'Register',
                3 => 'Select AF-modes',
            },
            'sprintf("Flags 0x%x",$val)', # (70D=Manual 1pt,Manual zone,Auto 19pt)
        ],
        PrintConvInv => [
            undef,
            '$val=~/0x([\dA-F]+)/i ? hex($1) : undef',
        ],
    },
    0x0513 => { # new for 7D
        Name => 'ManualAFPointSelectPattern',
        PrintConv => {
            0 => 'Stops at AF area edges',
            1 => 'Continuous',
        },
    },
    0x0514 => { # new for 7D
        Name => 'DisplayAllAFPoints',
        PrintConv => \%enableDisable,
    },
    0x0515 => { # new for 7D
        Name => 'FocusDisplayAIServoAndMF',
        PrintConv => \%enableDisable,
    },
    0x0516 => { # new for 7D and 1DmkIV
        Name => 'OrientationLinkedAFPoint',
        PrintConv => {
            0 => 'Same for vertical and horizontal',
            1 => 'Select different AF points',
        },
    },
    0x0517 => { # new for 1DmkIV
        Name => 'MultiControllerWhileMetering',
        PrintConv => {
            0 => 'Off',
            1 => 'AF point selection',
        },
    },
    0x0518 => { # new for 6D
        Name => 'AccelerationTracking',
    },
    0x0519 => { # new for 6D
        Name => 'AIServoFirstImagePriority',
        PrintConv => { #(NC)
            -1 => 'Release priority',
            0 => 'Equal priority',
            1 => 'Focus priority',
        },
    },
    0x051a => { # new for 6D
        Name => 'AIServoSecondImagePriority',
        PrintConv => { #(NC)
            -1 => 'Shooting speed priority',
            0 => 'Equal priority',
            1 => 'Focus priority',
        },
    },
    0x051b => { # (70D)
        Name => 'AFAreaSelectMethod',
        PrintConv => {
            0 => 'AF area selection button',
            1 => 'Main dial',
        },
    },
    0x051c => { # (750D)
        Name => 'AutoAFPointColorTracking',
        PrintConv => {
            0 => 'On-Shot AF only',
            1 => 'Disable',
        },
    },
    0x051d => { # (750D/760D)
        Name => 'VFDisplayIllumination',
        PrintConv => [{
            0 => 'Auto',
            1 => 'Enable',
            2 => 'Disable',
        },{
            0 => 'Non-illuminated', #(NC)
            1 => 'Illuminated', #(NC)
        }],
    },
    0x051e => { # (80D)
        Name => 'InitialAFPointAIServoAF',
        PrintConv => {
            0 => 'Auto',
            1 => 'Initial AF point selected',
            2 => 'Manual AF point',
        },
    },
    #### 3b) Drive
    0x060f => {
        Name => 'MirrorLockup',
        Notes => 'value of 2 not used by some models',
        PrintConv => {
            0 => 'Disable',
            1 => 'Enable',
            2 => 'Enable: Down with Set',
        },
    },
    0x0610 => {
        Name => 'ContinuousShootingSpeed',
        Count => 3,
        PrintConv => [
            \%disableEnable,
            '"Hi $val"',
            '"Lo $val"',
        ],
        PrintConvInv => [
            undef,
            '$val=~/(\d+)/ ? $1 : 0',
            '$val=~/(\d+)/ ? $1 : 0',
        ],
    },
    0x0611 => {
        Name => 'ContinuousShotLimit',
        Count => 2,
        PrintConv => [
            \%disableEnable,
            '"$val shots"',
        ],
        PrintConvInv => [
            undef,
            '$val=~/(\d+)/ ? $1 : 0',
        ],
    },
    0x0612 => { # (1DX)
        Name => 'RestrictDriveModes',
        Count => 2,
        PrintConv => [
            \%disableEnable,
            'sprintf("Flags 0x%x",$val)', # (Single,Cont Hi,Cont Lo,Timer 10,Timer 2,Silent,Super Hi)
        ],
        PrintConvInv => [
            undef,
            '$val=~/0x([\dA-F]+)/i ? hex($1) : undef',
        ],
    },
    #### 4a) Operation
    0x0701 => [
        {
            Name => 'Shutter-AELock',
            Condition => q{
                $$self{Model} =~ /\b(1000D|XS|Kiss F|500D|T1i|Kiss X3|550D|T2i|Kiss X4)\b/ or
                $$self{Model} =~ /\b(600D|T3i|Kiss X5|1100D|T3|Kiss X50)\b/
            },
            Notes => '500D, 550D, 600D, 1000D and 1100D',
            PrintConv => {
                0 => 'AF/AE lock',
                1 => 'AE lock/AF',
                2 => 'AF/AF lock, No AE lock',
                3 => 'AE/AF, No AE lock',
            },
        },
        {
            Name => 'AFAndMeteringButtons',
            Condition => '$$self{Model} =~ /\b60D\b/',
            Notes => '60D',
            PrintConv => {
                0 => 'Metering start',
                1 => 'Metering + AF start',
                2 => 'AE lock',
                3 => 'AF stop',
                4 => 'No function',
            },
        },
        {
            Name => 'ShutterButtonAFOnButton',
            Notes => 'other models',
            PrintConv => {
                0 => 'Metering + AF start',
                1 => 'Metering + AF start/AF stop',
                2 => 'Metering start/Meter + AF start',
                3 => 'AE lock/Metering + AF start',
                4 => 'Metering + AF start/disable',
            },
        },
    ],
    0x0702 => {
        Name => 'AFOnAELockButtonSwitch',
        PrintConv => \%disableEnable,
    },
    0x0703 => {
        Name => 'QuickControlDialInMeter',
        PrintConv => {
            0 => 'Exposure comp/Aperture',
            1 => 'AF point selection',
            2 => 'ISO speed',
            3 => 'AF point selection swapped with Exposure comp', #4
            4 => 'ISO speed swapped with Exposure comp', #4
        },
    },
    0x0704 => [
        {
            Name => 'SetButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b(40D|50D|5D Mark II)\b/',
            Notes => '40D, 50D and 5DmkII; value of 5 is new for 50D, and 6 is new for 5DmkII',
            PrintConv => {
                0 => 'Normal (disabled)',
                1 => 'Image quality',
                2 => 'Picture style',
                3 => 'Menu display',
                4 => 'Image playback',
                5 => 'Quick control screen', #50D
                6 => 'Record movie (Live View)', #5DmkII
            },
        },
        {
            Name => 'SetButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b60D\b/',
            Notes => '60D',
            PrintConv => {
                0 => 'Normal (disabled)',
                1 => 'Image quality',
                2 => 'Picture style',
                3 => 'White balance',
                4 => 'Flash exposure compensation',
                5 => 'Viewfinder leveling gauge',
            },
        },
        {
            Name => 'SetButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b(450D|XSi|Kiss X2|550D|T2i|Kiss X4|600D|T3i|Kiss X5)\b/',
            Notes => '450D, 550D and 600D; value of 5 is new for 550D',
            PrintConv => {
                0 => 'Normal (disabled)',
                1 => 'Image quality',
                2 => 'Flash exposure compensation',
                3 => 'LCD monitor On/Off',
                4 => 'Menu display',
                5 => 'ISO speed',
            },
        },
        {
            Name => 'SetButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b(1100D|T3|Kiss X50)\b/',
            Notes => '1100D',
            PrintConv => {
                0 => 'Normal (disabled)',
                1 => 'Image quality',
                2 => 'Flash exposure compensation',
                3 => 'LCD monitor On/Off',
                4 => 'Menu display',
                5 => 'Depth-of-field preview',
            },
        },
        {
            Name => 'SetButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b(1000D|XS|Kiss F)\b/',
            Notes => '1000D',
            PrintConv => {
                0 => 'LCD monitor On/Off',
                1 => 'Image quality',
                2 => 'Flash exposure compensation',
                3 => 'Menu display',
                4 => 'Disabled',
            },
        },
        {
            Name => 'SetButtonWhenShooting',
            Condition => '$$self{Model} =~ /\b(500D|T1i|Kiss X3)\b/',
            Notes => '500D',
            PrintConv => {
                0 => 'Quick control screen',
                1 => 'Image quality',
                2 => 'Flash exposure compensation',
                3 => 'LCD monitor On/Off',
                4 => 'Menu display',
                5 => 'Disabled',
            },
        },
        {
            Name => 'SetButtonWhenShooting',
            Notes => '1DmkIII and 1DmkIV',
            PrintConv => {
                0 => 'Normal (disabled)',
                1 => 'White balance',
                2 => 'Image size',
                3 => 'ISO speed',
                4 => 'Picture style',
                5 => 'Record func. + media/folder',
                6 => 'Menu display',
                7 => 'Image playback',
            },
        },
    ],
    0x0705 => {
        Name => 'ManualTv',
        Description => 'Manual Tv/Av For M',
        PrintConv => {
            0 => 'Tv=Main/Av=Control',
            1 => 'Tv=Control/Av=Main',
        },
    },
    0x0706 => {
        Name => 'DialDirectionTvAv',
        PrintConv => {
            0 => 'Normal',
            1 => 'Reversed',
        },
    },
    0x0707 => {
        Name => 'AvSettingWithoutLens',
        PrintConv => \%disableEnable,
    },
    0x0708 => {
        Name => 'WBMediaImageSizeSetting',
        PrintConv => {
            0 => 'Rear LCD panel',
            1 => 'LCD monitor',
            2 => 'Off (disable button)', # (1DX)
        },
    },
    0x0709 => {
        Name => 'LockMicrophoneButton',
        PrintConv => [{
            # called "sound" in 1DmkIII manual, and "memo" in 1DmkIV manual
            0 => 'Protect (hold:record memo)',
            1 => 'Record memo (protect:disable)',
            2 => 'Play memo (hold:record memo)', # new with 1DmkIV
            3 => 'Rating (protect/memo:disable)', # new with 1DX
        }],
        # (not sure what the 2nd number is -- new for 1DX.  Seen a value of 31.
        # Memo quality may be set to 48kHz or 8kHz through another option that
        # doesn't seem to be stored separately -- is this it?)
    },
    0x070a => {
        Name => 'ButtonFunctionControlOff',
        PrintConv => {
            0 => 'Normal (enable)',
            1 => 'Disable main, Control, Multi-control',
        },
    },
    0x070b => { # 50D (also, 5DmkII writes this but it isn't in user guide)
        Name => 'AssignFuncButton',
        PrintConv => {
            0 => 'LCD brightness',
            1 => 'Image quality',
            2 => 'Exposure comp./AEB setting',
            3 => 'Image jump with main dial',
            4 => 'Live view function settings',
        },
    },
    0x070c => { # new for 7D
        Name => 'CustomControls',
        # (too much stuff to decode)
    },
    0x070d => { # new for 1DmkIV
        Name => 'StartMovieShooting',
        PrintConv => {
            0 => 'Default (from LV)',
            1 => 'Quick start (FEL button)',
        },
    },
    0x070e => { # new for 1100D
        Name => 'FlashButtonFunction',
        PrintConv => {
            0 => 'Raise built-in flash',
            1 => 'ISO speed',
        },
    },
    0x070f => { # new for 5DmkIII
        Name => 'MultiFunctionLock',
        PrintConv => [
            { #(NC)
                0 => 'Off',
                1 => 'On', # "On (main dial)" for 750D/760D?
                2 => 'On (quick control dial)', #(NC)
                3 => 'On (main dial and quick control dial)', #(NC)
            },
            { BITMASK => { #(NC)
                0 => 'Main dial',
                1 => 'Quick control dial',
                2 => 'Multi-controller',
            }},
        ],
    },
    0x0710 => { # (M)
        Name => 'TrashButtonFunction',
        PrintConv => {
            0 => 'Normal (set center AF point)',
            1 => 'Depth-of-field preview',
        },
    },
    0x0711 => { # (M)
        Name => 'ShutterReleaseWithoutLens',
        PrintConv => \%disableEnable,
    },
    0x0712 => { # (R)
        Name => 'ControlRingRotation',
        PrintConv => {
            0 => 'Normal',
            1 => 'Reversed',
        },
    },
    0x0713 => { # (R)
        Name => 'FocusRingRotation',
        PrintConv => {
            0 => 'Normal',
            1 => 'Reversed',
        },
    },
    0x0714 => { # (R)
        Name => 'RFLensMFFocusRingSensitivity',
        PrintConv => {
            0 => 'Varies With Rotation Speed',
            1 => 'Linked To Rotation Angle',
        },
    },
    0x0715 => { # (R)
        Name => 'CustomizeDials', # (NC, may be CustomizeM-FnBar)
        # (too much stuff to decode)
    },
    #### 4b) Others
    0x080b => [
        {
            Name => 'FocusingScreen',
            Condition => '$$self{Model} =~ /\b(40D|50D|60D)\b/',
            Notes => '40D, 50D and 60D',
            PrintConv => {
                0 => 'Ef-A',
                1 => 'Ef-D',
                2 => 'Ef-S',
            },
        },
        {
            Name => 'FocusingScreen',
            Condition => '$$self{Model} =~ /\b5D Mark II\b/',
            Notes => '5D Mark II',
            PrintConv => {
                0 => 'Eg-A',
                1 => 'Eg-D',
                2 => 'Eg-S',
            },
        },
        {
            Name => 'FocusingScreen',
            Condition => '$$self{Model} =~ /\b6D\b/',
            Notes => '6D',
            PrintConv => {
                0 => 'Eg-A II',
                1 => 'Eg-D',
                2 => 'Eg-S',
            },
        },
        {
            Name => 'FocusingScreen',
            Condition => '$$self{Model} =~ /\b7D Mark II\b/',
            Notes => '7D Mark II',
            PrintConv => {
                0 => 'Eh-A',
                1 => 'Eh-S',
            },
        },
        {
            Name => 'FocusingScreen',
            Condition => '$$self{Model} =~ /\b1D X\b/',
            Notes => '1DX',
            PrintConv => {
                0 => 'Ec-CV',
                1 => 'Ec-A,B,D,H,I,L',
            },
        },
        {
            Name => 'FocusingScreen',
            Notes => '1DmkIII, 1DSmkIII and 1DmkIV',
            PrintConv => {
                0 => 'Ec-CIV',
                1 => 'Ec-A,B,C,CII,CIII,D,H,I,L',
                2 => 'Ec-S',
                3 => 'Ec-N,R',
            },
        },
    ],
    0x080c => {
        Name => 'TimerLength',
        Count => 4,
        PrintConv => [
            \%disableEnable,
            '"6 s: $val"',
            '"16 s: $val"',
            '"After release: $val"',
        ],
        PrintConvInv => [
            undef,
            '$val=~/(\d+)$/ ? $1 : 0',
            '$val=~/(\d+)$/ ? $1 : 0',
            '$val=~/(\d+)$/ ? $1 : 0',
        ],
    },
    0x080d => {
        Name => 'ShortReleaseTimeLag',
        PrintConv => \%disableEnable,
    },
    0x080e => {
        Name => 'AddAspectRatioInfo',
        PrintConv => {
            0 => 'Off',
            1 => '6:6',
            2 => '3:4',
            3 => '4:5',
            4 => '6:7',
            5 => '10:12',
            6 => '5:7',
        },
    },
    0x080f => {
        Name => 'AddOriginalDecisionData', # called ("image verification" in 1DmkIV manual)
        PrintConv => \%offOn,
    },
    0x0810 => {
        Name => 'LiveViewExposureSimulation',
        PrintConv => {
            0 => 'Disable (LCD auto adjust)',
            1 => 'Enable (simulates exposure)',
        },
    },
    0x0811 => {
        Name => 'LCDDisplayAtPowerOn',
        PrintConv => {
            0 => 'Display',
            1 => 'Retain power off status',
        },
    },
    0x0812 => { # (1DX)
        Name => 'MemoAudioQuality',
        PrintConv => {
            0 => 'High (48 kHz)',
            1 => 'Low (8 kHz)',
        },
    },
    0x0813 => { # (5DmkIII)
        Name => 'DefaultEraseOption',
        PrintConv => {
            0 => 'Cancel selected',
            1 => 'Erase selected',
        },
    },
    0x0814 => { # (5DS)
        Name => 'RetractLensOnPowerOff',
        PrintConv => \%enableDisable,
    },
    0x0815 => { # (R)
        Name => 'AddIPTCInformation',
        PrintConv => \%disableEnable,
    },
);

#------------------------------------------------------------------------------
# Conversion routines
# Inputs: 0) value to convert
sub ConvertPfn($)
{
    my $val = shift;
    return $val ? ($val==1 ? 'On' : "On ($val)") : "Off";
}
sub ConvertPfnInv($)
{
    my $val = shift;
    return $1 if $val =~ /(\d+)/;
    return  1 if $val =~ /on/i;
    return  0 if $val =~ /off/i;
    return undef;
}

#------------------------------------------------------------------------------
# Read/Write Canon custom 2 directory (new for 1D Mark III)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessCanonCustom2($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $write = $$dirInfo{Write};
    my $verbose = $et->Options('Verbose');
    my $newTags;

    return 0 if $size < 2;
    # first entry in array must be the size
    my $len = Get16u($dataPt, $offset);
    unless ($len == $size and $len >= 8) {
        $et->Warn('Invalid CanonCustom2 data');
        return 0;
    }
    # get group count
    my $count = Get32u($dataPt, $offset + 4);
    if ($write) {
        $newTags = $et->GetNewTagInfoHash($tagTablePtr);
        $et->VPrint(0, "  Rewriting CanonCustom2\n");
    } elsif ($verbose) {
        $et->VerboseDir('CanonCustom2', $count, $len);
    }
    my $pos = $offset + 8;
    my $end = $offset + $size;
    # loop through group records
    for (; $pos<$end; ) {
        last if $pos + 12 > $end;
        my $recNum = Get32u($dataPt, $pos);
        my $recLen = Get32u($dataPt, $pos + 4);
        my $recCount = Get32u($dataPt, $pos + 8);
        last if $recLen < 8;    # must be at least 8 bytes for recNum and recLen
        $pos += 12;
        my $recPos = $pos;
        my $recEnd = $pos + $recLen - 8;
        if ($recEnd > $end) {
            $et->Warn('Corrupted CanonCustom2 group');
            return 0;
        }
        if ($verbose and not $write) {
            $et->VerboseDir("CanonCustom2 group $recNum", $recCount, $recLen);
        }
        my ($i, $num, $tag);
        for ($i=0; $recPos + 8 < $recEnd; ++$i, $recPos+=4*$num) {
            $tag = Get32u($dataPt, $recPos);
            $num = Get32u($dataPt, $recPos + 4);
            $recPos += 8;
            last if $recPos + $num * 4 > $recEnd;
            my $val = ReadValue($dataPt, $recPos, 'int32s', $num, $num * 4);
            if ($write) {
                # write new value
                my $tagInfo = $$newTags{$tag};
                next unless $$newTags{$tag};
                $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$val, undef, $num) or next;
                my $nvHash = $et->GetNewValueHash($tagInfo) or next;
                next unless $et->IsOverwriting($nvHash, $val);
                my $newVal = $et->GetNewValue($nvHash);
                next unless defined $newVal;    # can't delete from a custom table
                WriteValue($newVal, 'int32s', $num, $dataPt, $recPos);
                $et->VerboseValue("- CanonCustom:$$tagInfo{Name}", $val);
                $et->VerboseValue("+ CanonCustom:$$tagInfo{Name}", $newVal);
                ++$$et{CHANGED};
            } else {
                # save extracted tag
                my $oldInfo = $$tagTablePtr{$tag};
                $et->HandleTag($tagTablePtr, $tag, $val,
                    Index  => $i,
                    Format => 'int32u',
                    Count  => $num,
                    Size   => $num * 4,
                );
                my $tagInfo = $$tagTablePtr{$tag};
                # generate properly formatted description if we just added the tag
                if ($tagInfo and not $oldInfo) {
                    ($$tagInfo{Description} = $$tagInfo{Name}) =~ tr/_/ /;
                    $$tagInfo{Description} =~ s/CanonCustom Functions/Canon Custom Functions /;
                }
            }
        }
        $pos = $recEnd;
    }
    if ($pos != $end) {
        # Note: a firmware bug in the EOS M5 and M6 stores an incorrect
        # size for the 2nd CanonCustom2 record, so this message is expected
        # for these models...
        $et->Warn('Possibly corrupted CanonCustom2 data');
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Write Canon custom 2 data
# Inputs: 0) ExifTool object reference, 1) dirInfo hash ref, 2) tag table ref
# Returns: New custom data block or undefined on error
sub WriteCanonCustom2($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    # edit a copy of the custom function 2 data
    my $buff = substr($$dataPt, $$dirInfo{DirStart}, $$dirInfo{DirLen});
    my %dirInfo = (
        DataPt   => \$buff,
        DirStart => 0,
        DirLen   => $$dirInfo{DirLen},
        Write    => 1,
    );
    ProcessCanonCustom2($et, \%dirInfo, $tagTablePtr) or return undef;
    return $buff;
}

#------------------------------------------------------------------------------
# Process Canon custom directory
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessCanonCustom($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');

    # first entry in array must be the size
    my $len = Get16u($dataPt,$offset);
    unless ($len == $size or ($$et{Model}=~/\bD60\b/ and $len+2 == $size)) {
        $et->Warn("Invalid CanonCustom data");
        return 0;
    }
    $verbose and $et->VerboseDir('CanonCustom', $size/2-1);
    my $pos;
    for ($pos=2; $pos<$size; $pos+=2) {
        # ($pos is position within custom directory)
        my $val = Get16u($dataPt,$offset+$pos);
        my $tag = ($val >> 8);
        $val = ($val & 0xff);
        $et->HandleTag($tagTablePtr, $tag, $val,
            Index  => $pos/2-1,
            Format => 'int8u',
            Count  => 1,
            Size   => 1,
        );
    }
    return 1;
}

#------------------------------------------------------------------------------
# Check new value for Canon custom data block
# Inputs: 0) ExifTool object reference, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string or undef (and may modify value) on success
sub CheckCanonCustom($$$)
{
    my ($et, $tagInfo, $valPtr) = @_;
    return Image::ExifTool::CheckValue($valPtr, 'int8u');
}

#------------------------------------------------------------------------------
# Write Canon custom data
# Inputs: 0) ExifTool object reference, 1) dirInfo hash ref, 2) tag table ref
# Returns: New custom data block or undefined on error
sub WriteCanonCustom($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $dirStart;
    my $dirName = $$dirInfo{DirName};
    my $newData = substr($$dataPt, $dirStart, $dirLen) or return undef;
    $dataPt = \$newData;

    # first entry in array must be the size
    my $len = Get16u($dataPt, 0);
    unless ($len == $dirLen or ($$et{Model}=~/\bD60\b/ and $len+2 == $dirLen)) {
        $et->Warn("Invalid CanonCustom data");
        return undef;
    }
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    my $pos;
    for ($pos=2; $pos<$dirLen; $pos+=2) {
        my $val = Get16u($dataPt, $pos);
        my $tag = ($val >> 8);
        my $tagInfo = $$newTags{$tag};
        next unless $tagInfo;
        my $nvHash = $et->GetNewValueHash($tagInfo);
        $val = ($val & 0xff);
        next unless $et->IsOverwriting($nvHash, $val);
        my $newVal = $et->GetNewValue($nvHash);
        next unless defined $newVal;    # can't delete from a custom table
        Set16u(($newVal & 0xff) + ($tag << 8), $dataPt, $pos);
        $et->VerboseValue("- $dirName:$$tagInfo{Name}", $val);
        $et->VerboseValue("+ $dirName:$$tagInfo{Name}", $newVal);
        ++$$et{CHANGED};
    }
    return $newData;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::CanonCustom - Read and Write Canon custom functions

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

The Canon custom functions meta information is very specific to the
camera model, and is found in both the EXIF maker notes and in the
Canon RAW files.  This module contains the definitions necessary for
Image::ExifTool to read this information.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Christian Koller for his work in decoding the 20D custom
functions, Rainer Honle for decoding the 5D custom functions and David
Pitcher for adding a few undocumented 1DmkIII settings.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Canon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
