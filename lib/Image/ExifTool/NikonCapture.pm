#------------------------------------------------------------------------------
# File:         NikonCapture.pm
#
# Description:  Read/write Nikon Capture information
#
# Revisions:    11/08/2005 - P. Harvey Created
#               10/10/2008 - P. Harvey Updated for Capture NX 2
#               16/04/2011 - P. Harvey Decode NikonCaptureEditVersions
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               IB) Iliah Borg private communication (LibRaw)
#------------------------------------------------------------------------------

package Image::ExifTool::NikonCapture;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.14';

sub ProcessNikonCapture($$$);

# common print conversions
my %offOn = ( 0 => 'Off', 1 => 'On' );
my %noYes = ( 0 => 'No', 1 => 'Yes' );
my %unsharpColor = (
    0 => 'RGB',
    1 => 'Red',
    2 => 'Green',
    3 => 'Blue',
    4 => 'Yellow',
    5 => 'Magenta',
    6 => 'Cyan',
);

# Nikon Capture data (ref PH)
%Image::ExifTool::NikonCapture::Main = (
    PROCESS_PROC => \&ProcessNikonCapture,
    WRITE_PROC => \&WriteNikonCapture,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        This information is written by the Nikon Capture software in tag 0x0e01 of
        the maker notes of NEF images.
    },
    # 0x007ddc9d contains contrast information
    0x008ae85e => {
        Name => 'LCHEditor',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x0c89224b => {
        Name => 'ColorAberrationControl',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x116fea21 => {
        Name => 'HighlightData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::HighlightData',
        },
    },
    0x2175eb78 => {
        Name => 'D-LightingHQ',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x2fc08431 => {
        Name => 'StraightenAngle',
        Writable => 'double',
    },
    0x374233e0 => {
        Name => 'CropData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::CropData',
        },
    },
    0x39c456ac => {
        Name => 'PictureCtrl',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::PictureCtrl',
        },
    },
    0x3cfc73c6 => {
        Name => 'RedEyeData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::RedEyeData',
        },
    },
    0x3d136244 => {
        Name => 'EditVersionName',
        Writable => 'string', # (null terminated)
    },
    # 0x3e726567 added when I rotated by 90 degrees
    0x416391c6 => {
        Name => 'QuickFix',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x56a54260 => {
        Name => 'Exposure',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::Exposure',
        },
    },
    0x5f0e7d23 => {
        Name => 'ColorBooster',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x6a6e36b6 => {
        Name => 'D-LightingHQSelected',
        Writable => 'int8u',
        PrintConv => \%noYes,
    },
    0x753dcbc0 => {
        Name => 'NoiseReduction',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43200 => {
        Name => 'UnsharpMask',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43201 => {
        Name => 'Curves',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43202 => {
        Name => 'ColorBalanceAdj',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43203 => {
        Name => 'AdvancedRaw',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43204 => {
        Name => 'WhiteBalanceAdj',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43205 => {
        Name => 'VignetteControl',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x76a43206 => {
        Name => 'FlipHorizontal',
        Writable => 'int8u',
        PrintConv => \%noYes,
    },
    0x76a43207 => { # rotation angle in degrees
        Name => 'Rotation',
        Writable => 'int16u',
    },
    0x083a1a25 => {
        Name => 'HistogramXML',
        Writable => 'undef',
        Binary => 1,
        AdjustSize => 4,    # patch Nikon bug
    },
    0x84589434 => {
        Name => 'BrightnessData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::Brightness',
        },
    },
  # 0x88f55e48 - related to QuickFix
    0x890ff591 => {
        Name => 'D-LightingHQData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::DLightingHQ',
        },
    },
    0x926f13e0 => {
        Name => 'NoiseReductionData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::NoiseReduction',
        },
    },
    0x9ef5f6e0 => {
        Name => 'IPTCData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
  # 0xa7264a72 - related to QuickFix
    0xab5eca5e => {
        Name => 'PhotoEffects',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0xac6bd5c0 => {
        Name => 'VignetteControlIntensity',
        Writable => 'int16s',
    },
    0xb0384e1e => {
        Name => 'PhotoEffectsData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::PhotoEffects',
        },
    },
    0xb999a36f => {
        Name => 'ColorBoostData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::ColorBoost',
        },
    },
    0xbf3c6c20 => {
        Name => 'WBAdjData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::WBAdjData',
        },
    },
    0xce5554aa => {
        Name => 'D-LightingHS',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0xe2173c47 => {
        Name => 'PictureControl',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0xe37b4337 => {
        Name => 'D-LightingHSData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::DLightingHS',
        },
    },
    0xe42b5161 => {
        Name => 'UnsharpData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCapture::UnsharpData',
        },
    },
    0xe9651831 => {
        Name => 'PhotoEffectHistoryXML',
        Binary => 1,
        Writable => 'undef',
    },
    0xfe28a44f => {
        Name => 'AutoRedEye',
        Writable => 'int8u',
        PrintConv => \%offOn, # (have seen a value of 28 here for older software?)
    },
    0xfe443a45 => {
        Name => 'ImageDustOff',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
);

%Image::ExifTool::NikonCapture::UnsharpData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'UnsharpCount',
    19 => { Name => 'Unsharp1Color', Format => 'int16u', PrintConv => \%unsharpColor },
    23 => { Name => 'Unsharp1Intensity', Format => 'int16u' },
    25 => { Name => 'Unsharp1HaloWidth', Format => 'int16u' },
    27 => 'Unsharp1Threshold',
    46 => { Name => 'Unsharp2Color', Format => 'int16u', PrintConv => \%unsharpColor },
    50 => { Name => 'Unsharp2Intensity', Format => 'int16u' },
    52 => { Name => 'Unsharp2HaloWidth', Format => 'int16u' },
    54 => 'Unsharp2Threshold',
    73 => { Name => 'Unsharp3Color', Format => 'int16u', PrintConv => \%unsharpColor },
    77 => { Name => 'Unsharp3Intensity', Format => 'int16u' },
    79 => { Name => 'Unsharp3HaloWidth', Format => 'int16u' },
    81 => 'Unsharp3Threshold',
    100 => { Name => 'Unsharp4Color', Format => 'int16u', PrintConv => \%unsharpColor },
    104 => { Name => 'Unsharp4Intensity', Format => 'int16u' },
    106 => { Name => 'Unsharp4HaloWidth', Format => 'int16u' },
    108 => 'Unsharp4Threshold',
    # there could be more, but I grow bored of this... :P
);

%Image::ExifTool::NikonCapture::DLightingHS = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'D-LightingHSAdjustment',
    1 => 'D-LightingHSColorBoost',
);

%Image::ExifTool::NikonCapture::DLightingHQ = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'D-LightingHQShadow',
    1 => 'D-LightingHQHighlight',
    2 => 'D-LightingHQColorBoost',
);

%Image::ExifTool::NikonCapture::ColorBoost = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'ColorBoostType',
        PrintConv => {
            0 => 'Nature',
            1 => 'People',
        },
    },
    1 => {
        Name => 'ColorBoostLevel',
        Format => 'int32u',
    },
);

%Image::ExifTool::NikonCapture::WBAdjData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'WBAdjRedBalance',
        Format => 'double',
    },
    0x08 => {
        Name => 'WBAdjBlueBalance',
        Format => 'double',
    },
    0x10 => {
        Name => 'WBAdjMode',
        PrintConv => {
            1 => 'Use Gray Point',
            2 => 'Recorded Value',
            3 => 'Use Temperature',
            4 => 'Calculate Automatically',
            5 => 'Auto2', #IB
            6 => 'Underwater', #IB
            7 => 'Auto1',
        },
    },
    0x14 => { #IB
        Name => 'WBAdjLighting',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'None',
            0x100 => 'Incandescent',
            0x200 => 'Daylight (direct sunlight)',
            0x201 => 'Daylight (shade)',
            0x202 => 'Daylight (cloudy)',
            0x300 => 'Standard Fluorescent (warm white)',
            0x301 => 'Standard Fluorescent (3700K)',
            0x302 => 'Standard Fluorescent (cool white)',
            0x303 => 'Standard Fluorescent (5000K)',
            0x304 => 'Standard Fluorescent (daylight)',
            0x305 => 'Standard Fluorescent (high temperature mercury vapor)',
            0x400 => 'High Color Rendering Fluorescent (warm white)',
            0x401 => 'High Color Rendering Fluorescent (3700K)',
            0x402 => 'High Color Rendering Fluorescent (cool white)',
            0x403 => 'High Color Rendering Fluorescent (5000K)',
            0x404 => 'High Color Rendering Fluorescent (daylight)',
            0x500 => 'Flash',
            0x501 => 'Flash (FL-G1 filter)',
            0x502 => 'Flash (FL-G2 filter)',
            0x503 => 'Flash (TN-A1 filter)',
            0x504 => 'Flash (TN-A2 filter)',
            0x600 => 'Sodium Vapor Lamps',
            # 0x1002 => seen for WBAdjMode modes of Underwater and Calculate Automatically
        },
    },
    0x18 => {
        Name => 'WBAdjTemperature',
        Format => 'int16u',
    },
    0x25 => {
        Name => 'WBAdjTint',
        Format => 'int32s',
    },
);

%Image::ExifTool::NikonCapture::PhotoEffects = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'PhotoEffectsType',
        PrintConv => {
            0 => 'None',
            1 => 'B&W',
            2 => 'Sepia',
            3 => 'Tinted',
        },
    },
    4 => {
        Name => 'PhotoEffectsRed',
        Format => 'int16s',
    },
    6 => {
        Name => 'PhotoEffectsGreen',
        Format => 'int16s',
    },
    8 => {
        Name => 'PhotoEffectsBlue',
        Format => 'int16s',
    },
);

%Image::ExifTool::NikonCapture::Brightness = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'BrightnessAdj',
        Format => 'double',
        ValueConv => '$val * 50',
        ValueConvInv => '$val / 50',
    },
    8 => {
        Name => 'EnhanceDarkTones',
        PrintConv => \%offOn,
    },
);

%Image::ExifTool::NikonCapture::NoiseReduction = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x04 => {
        Name => 'EdgeNoiseReduction',
        PrintConv => \%offOn,
    },
    0x05 => {
        Name => 'ColorMoireReductionMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Medium',
            3 => 'High',
        },
    },
    0x09 => {
        Name => 'NoiseReductionIntensity',
        Format => 'int32u',
    },
    0x0d => {
        Name => 'NoiseReductionSharpness',
        Format => 'int32u',
    },
    0x11 => {
        Name => 'NoiseReductionMethod',
        Format => 'int16u',
        PrintConv => {
            0 => 'Faster',
            1 => 'Better Quality',
            2 => 'Better Quality 2013',
        },
    },
    0x15 => {
        Name => 'ColorMoireReduction',
        PrintConv => \%offOn,
    },
    0x17 => {
        Name => 'NoiseReduction',
        PrintConv => \%offOn,
    },
    0x18 => {
        Name => 'ColorNoiseReductionIntensity',
        Format => 'int32u',
    },
    0x1c => {
        Name => 'ColorNoiseReductionSharpness',
        Format => 'int32u',
    },
);

%Image::ExifTool::NikonCapture::CropData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x1e => {
        Name => 'CropLeft',
        Format => 'double',
        ValueConv => '$val / 2',
        ValueConvInv => '$val * 2',
    },
    0x26 => {
        Name => 'CropTop',
        Format => 'double',
        ValueConv => '$val / 2',
        ValueConvInv => '$val * 2',
    },
    0x2e => {
        Name => 'CropRight',
        Format => 'double',
        ValueConv => '$val / 2',
        ValueConvInv => '$val * 2',
    },
    0x36 => {
        Name => 'CropBottom',
        Format => 'double',
        ValueConv => '$val / 2',
        ValueConvInv => '$val * 2',
    },
    0x8e => {
        Name => 'CropOutputWidthInches',
        Format => 'double',
    },
    0x96 => {
        Name => 'CropOutputHeightInches',
        Format => 'double',
    },
    0x9e => {
        Name => 'CropScaledResolution',
        Format => 'double',
    },
    0xae => {
        Name => 'CropSourceResolution',
        Format => 'double',
        ValueConv => '$val / 2',
        ValueConvInv => '$val * 2',
    },
    0xb6 => {
        Name => 'CropOutputResolution',
        Format => 'double',
    },
    0xbe => {
        Name => 'CropOutputScale',
        Format => 'double',
    },
    0xc6 => {
        Name => 'CropOutputWidth',
        Format => 'double',
    },
    0xce => {
        Name => 'CropOutputHeight',
        Format => 'double',
    },
    0xd6 => {
        Name => 'CropOutputPixels',
        Format => 'double',
    },
);

%Image::ExifTool::NikonCapture::PictureCtrl = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'PictureControlActive',
        PrintConv => \%offOn,
    },
    0x13 => {
        Name => 'PictureControlMode',
        Format => 'string[16]',
    },
    # 0x29 changes with Hue and Sharpening
    0x2a => {
        Name => 'QuickAdjust',
        ValueConv => '$val - 128',
        ValueConvInv => '$val + 128',
    },
    0x2b => {
        Name => 'SharpeningAdj',
        ValueConv => '$val ? $val - 128 : "Auto"',
        ValueConvInv => '$val=~/\d/ ? $val + 128 : 0',
    },
    0x2c => {
        Name => 'ContrastAdj',
        ValueConv => '$val ? $val - 128 : "Auto"',
        ValueConvInv => '$val=~/\d/ ? $val + 128 : 0',
    },
    0x2d => {
        Name => 'BrightnessAdj',
        ValueConv => '$val ? $val - 128 : "Auto"', # no "Auto" mode (yet) for this setting
        ValueConvInv => '$val=~/\d/ ? $val + 128 : 0',
    },
    0x2e => {
        Name => 'SaturationAdj',
        ValueConv => '$val ? $val - 128 : "Auto"',
        ValueConvInv => '$val=~/\d/ ? $val + 128 : 0',
    },
    0x2f => {
        Name => 'HueAdj',
        ValueConv => '$val - 128',
        ValueConvInv => '$val + 128',
    },
    # 0x37 changed from 0 to 2 when Picture Control is enabled (and no active DLighting)
);

%Image::ExifTool::NikonCapture::RedEyeData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'RedEyeCorrection',
        PrintConv => {
            0 => 'Off',
            1 => 'Automatic',
            2 => 'Click on Eyes',
        },
    },
);

%Image::ExifTool::NikonCapture::Exposure = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'ExposureAdj',
        Format => 'int16s',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x12 => {
        Name => 'ExposureAdj2',
        Format => 'double',
        PrintConv => 'sprintf("%.4f", $val)',
        PrintConvInv => '$val',
    },
    0x24 => {
        Name => 'ActiveD-Lighting',
        PrintConv => \%offOn,
    },
    0x25 => {
        Name => 'ActiveD-LightingMode',
        PrintConv => {
            0 => 'Unchanged',
            1 => 'Off',
            2 => 'Low',
            3 => 'Normal',
            4 => 'High',
            6 => 'Extra High',
            7 => 'Extra High 1',
            8 => 'Extra High 2',
        },
    },
);

%Image::ExifTool::NikonCapture::HighlightData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'ShadowProtection',
    1 => 'SaturationAdj',
    6 => 'HighlightProtection',
);

#------------------------------------------------------------------------------
# write Nikon Capture data (ref 1)
# Inputs: 0) ExifTool object reference, 1) reference to directory information
#         2) pointer to tag table
# Returns: 1 on success
sub WriteNikonCapture($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package

    # no need to edit this information unless necessary
    unless ($$et{EDIT_DIRS}{MakerNotes} or $$et{EDIT_DIRS}{IPTC}) {
        return undef;
    }
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    if ($dirLen < 22) {
        $et->Warn('Short Nikon Capture Data',1);
        return undef;
    }
    # make sure the capture data is properly contained
    SetByteOrder('II');
    my $tagID = Get32u($dataPt, $dirStart);
    # sometimes size includes 18 header bytes, and other times it doesn't (eg. ViewNX 2.1.1)
    my $size = Get32u($dataPt, $dirStart + 18);
    my $pad = $dirLen - $size - 18;
    unless ($tagID == 0x7a86a940 and ($pad >= 0 or $pad == -18)) {
        $et->Warn('Unrecognized Nikon Capture Data header');
        return undef;
    }
    # determine if there is any data after this block
    if ($pad > 0) {
        $pad = substr($$dataPt, $dirStart + 18 + $size, $pad);
        $dirLen = $size + 18;
    } else {
        $pad = '';
    }
    my $outBuff = '';
    my $pos;
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    my $dirEnd = $dirStart + $dirLen;

    # loop through all entries in the Nikon Capture data
    for ($pos=$dirStart+22; $pos+22<$dirEnd; $pos+=22+$size) {
        $tagID = Get32u($dataPt, $pos);
        $size = Get32u($dataPt, $pos + 18) - 4;
        last if $size < 0 or $pos + 22 + $size > $dirEnd;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        if ($tagInfo) {
            my $newVal;
            if ($$tagInfo{SubDirectory}) {
                # rewrite the subdirectory
                my %subdirInfo = (
                    DataPt => $dataPt,
                    DirStart => $pos + 22,
                    DirLen => $size,
                );
                my $subTable = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                # ignore minor errors in IPTC since there is typically trailing garbage
                my $oldSetting = $et->Options('IgnoreMinorErrors');
                $$tagInfo{Name} =~ /IPTC/ and $et->Options(IgnoreMinorErrors => 1);
                # rewrite the directory
                $newVal = $et->WriteDirectory(\%subdirInfo, $subTable);
                # restore our original options
                $et->Options(IgnoreMinorErrors => $oldSetting);
            } elsif ($$newTags{$tagID}) {
                # get new value for this tag if we are writing it
                my $format = $$tagInfo{Format} || $$tagInfo{Writable};
                my $oldVal = ReadValue($dataPt,$pos+22,$format,1,$size);
                my $nvHash = $et->GetNewValueHash($tagInfo);
                if ($et->IsOverwriting($nvHash, $oldVal)) {
                    my $val = $et->GetNewValue($tagInfo);
                    $newVal = WriteValue($val, $$tagInfo{Writable}) if defined $val;
                    if (defined $newVal and length $newVal) {
                        ++$$et{CHANGED};
                    } else {
                        undef $newVal;
                        $et->Warn("Can't delete $$tagInfo{Name}");
                    }
                }
            }
            if (defined $newVal) {
                next unless length $newVal; # don't write zero length information
                # write the new value
                $outBuff .= substr($$dataPt, $pos, 18);
                $outBuff .= Set32u(length($newVal) + 4);
                $outBuff .= $newVal;
                next;
            }
        }
        # rewrite the existing information
        $outBuff .= substr($$dataPt, $pos, 22 + $size);
    }
    unless ($pos == $dirEnd) {
        if ($pos == $dirEnd - 4) {
            # it seems that sometimes (NX2) the main block size is wrong by 4 bytes
            # (did they forget to include the size word?)
            $outBuff .= substr($$dataPt, $pos, 4);
        } else {
            $et->Warn('Nikon Capture Data improperly terminated',1);
            return undef;
        }
    }
    # add the header and return the new directory
    return substr($$dataPt, $dirStart, 18) .
           Set32u(length($outBuff) + 4) .
           $outBuff . $pad;
}

#------------------------------------------------------------------------------
# process Nikon Capture data (ref 1)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNikonCaptureEditVersions($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dirEnd = $dirStart + $dirLen;
    my $verbose = $et->Options('Verbose');
    SetByteOrder('II');
    return 0 unless $dirLen > 4;
    my $num = Get32u($dataPt, $dirStart);
    my $pos = $dirStart + 4;
    $verbose and $et->VerboseDir('NikonCaptureEditVersions', $num);
    while ($num) {
        last if $pos + 4 > $dirEnd;
        my $len = Get32u($dataPt, $pos);
        last if $pos + $len + 4 > $dirEnd;
        my %dirInfo = (
            DirName  => 'NikonCapture',
            Parent   => 'NikonCaptureEditVersions',
            DataPt   => $dataPt,
            DirStart => $pos + 4,
            DirLen   => $len,
        );
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        --$num;
        $pos += $len + 4;
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# process Nikon Capture data (ref 1)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNikonCapture($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dirEnd = $dirStart + $dirLen;
    my $verbose = $et->Options('Verbose');
    my $success = 0;
    SetByteOrder('II');
    $verbose and $et->VerboseDir('NikonCapture', 0, $dirLen);
    my $pos;
    for ($pos=$dirStart+22; $pos+22<$dirEnd; ) {
        my $tagID = Get32u($dataPt, $pos);
        my $size = Get32u($dataPt, $pos + 18) - 4;
        $pos += 22;
        last if $size < 0 or $pos + $size > $dirEnd;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        if ($tagInfo or $verbose) {
            my ($format, $value);
            # (note that Writable will be 0 for Unknown tags)
            $tagInfo and $format = ($$tagInfo{Format} || $$tagInfo{Writable});
            # generate a reasonable default format type for short values
            if (not $format and ($size == 1 or $size == 2 or $size == 4)) {
                $format = 'int' . ($size * 8) . 'u';
            }
            if ($format) {
                my $count = 1;
                if ($format eq 'string' or $format eq 'undef') {
                    # patch Nikon bug in size of some values (HistogramXML)
                    $size += $$tagInfo{AdjustSize} if $tagInfo and $$tagInfo{AdjustSize};
                    $count = $size;
                }
                $value = ReadValue($dataPt,$pos,$format,$count,$size);
            } elsif ($size == 1) {
                $value = substr($$dataPt, $pos, $size);
            }
            $et->HandleTag($tagTablePtr, $tagID, $value,
                DataPt  => $dataPt,
                DataPos => $$dirInfo{DataPos},
                Base    => $$dirInfo{Base},
                Start   => $pos,
                Size    => $size,
            ) and $success = 1;
        }
        $pos += $size;
    }
    return $success;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::NikonCapture - Read/write Nikon Capture information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains routines to read and write Nikon Capture information in
the maker notes of NEF images.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/NikonCapture Tags>,
L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
