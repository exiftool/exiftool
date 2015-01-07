#------------------------------------------------------------------------------
# File:         CanonVRD.pm
#
# Description:  Read/write Canon VRD information
#
# Revisions:    2006/10/30 - P. Harvey Created
#               2007/10/23 - PH Added new VRD 3.0 tags
#               2008/08/29 - PH Added new VRD 3.4 tags
#               2008/12/02 - PH Added new VRD 3.5 tags
#               2010/06/18 - PH Support variable-length CustomPictureStyle data
#               2010/09/14 - PH Added r/w support for XMP in VRD
#
# References:   1) Bogdan private communication (Canon DPP v3.4.1.1)
#               2) Gert Kello private communiation (DPP 3.8)
#------------------------------------------------------------------------------

package Image::ExifTool::CanonVRD;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.23';

sub ProcessCanonVRD($$;$);
sub WriteCanonVRD($$;$);
sub ProcessEditData($$$);
sub ProcessIHL($$$);
sub ProcessIHLExif($$$);

# map for adding directories to VRD
my %vrdMap = (
    XMP      => 'CanonVRD',
    CanonVRD => 'VRD',
);

my %noYes = ( 0 => 'No', 1 => 'Yes' );

# main tag table blocks in CanonVRD trailer (ref PH)
%Image::ExifTool::CanonVRD::Main = (
    WRITE_PROC => \&WriteCanonVRD,
    PROCESS_PROC => \&ProcessCanonVRD,
    NOTES => q{
        Canon Digital Photo Professional writes VRD (Recipe Data) information as a
        trailer record to JPEG, TIFF, CRW and CR2 images, or as a stand-alone VRD
        file.  The tags listed below represent information found in this record. 
        The complete VRD data record may be accessed as a block using the Extra
        'CanonVRD' tag, but this tag is not extracted or copied unless specified
        explicitly.
    },
    0xffff00f4 => {
        Name => 'EditData',
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::Edit' },
    },
    0xffff00f5 => {
        Name => 'IHLData',
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::IHL' },
    },
    0xffff00f6 => {
        Name => 'XMP',
        Flags => [ 'Binary', 'Protected' ],
        Writable => 'undef',    # allow writing/deleting as a block
        SubDirectory => {
            DirName => 'XMP',
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
);

# the VRD edit information is divided into sections
%Image::ExifTool::CanonVRD::Edit = (
    WRITE_PROC => \&ProcessEditData,
    PROCESS_PROC => \&ProcessEditData,
    VARS => { ID_LABEL => 'Index' }, # change TagID label in documentation
    NOTES => 'Canon VRD edit information.',
    0 => {
        Name => 'VRD1',
        Size => 0x272,  # size of version 1.0 edit information in bytes
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::Ver1' },
    },
    1 => {
        Name => 'VRDStampTool',
        # (size is variable, and obtained from int32u at end of last directory)
        Size => 0,      # size is variable, and obtained from int32u at directory start
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::StampTool' },
    },
    2 => {
        Name => 'VRD2',
        Size => undef,  # size is the remaining edit data
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::Ver2' },
    },
);

# "IHL Created Optional Item Data" tags (not yet writable)
%Image::ExifTool::CanonVRD::IHL = (
    PROCESS_PROC => \&ProcessIHL,
    TAG_PREFIX => 'VRD_IHL',
    GROUPS => { 2 => 'Image' },
    1 => [
        # this contains edited TIFF-format data, with an original IFD at 0x0008
        # and an edited IFD with offset given in the TIFF header.
        {
            Name => 'IHL_EXIF',
            Condition => '$self->Options("ExtractEmbedded")',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&ProcessIHLExif,
            },
        },{
            Name => 'IHL_EXIF',
            Notes => q{
                extracted as a block if the Unknown option is used, or processed as the
                first sub-document with the ExtractEmbedded option
            },
            Binary => 1,
            Unknown => 1,
        },
    ],
    # 2 - written by DPP 3.0.2.6, and it looks something like edit data,
    #     but I haven't decoded it yet - PH
    3 => {
        # (same size as the PreviewImage with DPP 3.0.2.6)
        Name => 'ThumbnailImage',
        Binary => 1,
    },
    4 => {
        Name => 'PreviewImage',
        Binary => 1,
    },
    5 => {
        Name => 'RawCodecVersion',
        ValueConv => '$val =~ s/\0.*//s; $val',  # truncate string at null
    },
    6 => {
        Name => 'CRCDevelParams',
        Binary => 1,
        Unknown => 1,
    },
);

# VRD version 1 tags (ref PH)
%Image::ExifTool::CanonVRD::Ver1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 2 => 'Image' },
    DATAMEMBER => [ 0x002 ],   # necessary for writing
#
# RAW image adjustment
#
    0x002 => {
        Name => 'VRDVersion',
        Format => 'int16u',
        Writable => 0,
        DataMember => 'VRDVersion',
        RawConv => '$$self{VRDVersion} = $val',
        PrintConv => '$val =~ s/^(\d)(\d*)(\d)$/$1.$2.$3/; $val',
    },
    0x006 => {
        Name => 'WBAdjRGGBLevels',
        Format => 'int16u[4]',
    },
    0x018 => {
        Name => 'WhiteBalanceAdj',
        Format => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Tungsten',
            4 => 'Fluorescent',
            5 => 'Flash',
            8 => 'Shade',
            9 => 'Kelvin',
            30 => 'Manual (Click)',
            31 => 'Shot Settings',
        },
    },
    0x01a => {
        Name => 'WBAdjColorTemp',
        Format => 'int16u',
    },
    # 0x01c similar to 0x006
    0x024 => {
        Name => 'WBFineTuneActive',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x028 => {
        Name => 'WBFineTuneSaturation',
        Format => 'int16u',
    },
    0x02c => {
        Name => 'WBFineTuneTone',
        Format => 'int16u',
    },
    0x02e => {
        Name => 'RawColorAdj',
        Format => 'int16u',
        PrintConv => {
            0 => 'Shot Settings',
            1 => 'Faithful',
            2 => 'Custom',
        },
    },
    0x030 => {
        Name => 'RawCustomSaturation',
        Format => 'int32s',
    },
    0x034 => {
        Name => 'RawCustomTone',
        Format => 'int32s',
    },
    0x038 => {
        Name => 'RawBrightnessAdj',
        Format => 'int32s',
        ValueConv => '$val / 6000',
        ValueConvInv => 'int($val * 6000 + ($val < 0 ? -0.5 : 0.5))',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    0x03c => {
        Name => 'ToneCurveProperty',
        Format => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Shot Settings',
            1 => 'Linear',
            2 => 'Custom 1',
            3 => 'Custom 2',
            4 => 'Custom 3',
            5 => 'Custom 4',
            6 => 'Custom 5',
        },
    },
    # 0x040 usually "10 9 2"
    0x07a => {
        Name => 'DynamicRangeMin',
        Format => 'int16u',
    },
    0x07c => {
        Name => 'DynamicRangeMax',
        Format => 'int16u',
    },
    # 0x0c6 usually "10 9 2"
#
# RGB image adjustment
#
    0x110 => {
        Name => 'ToneCurveActive',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x113 => {
        Name => 'ToneCurveMode',
        PrintConv => { 0 => 'RGB', 1 => 'Luminance' },
    },
    0x114 => {
        Name => 'BrightnessAdj',
        Format => 'int8s',
    },
    0x115 => {
        Name => 'ContrastAdj',
        Format => 'int8s',
    },
    0x116 => {
        Name => 'SaturationAdj',
        Format => 'int16s',
    },
    0x11e => {
        Name => 'ColorToneAdj',
        Notes => 'in degrees, so -1 is the same as 359',
        Format => 'int32s',
    },
    0x126 => {
        Name => 'LuminanceCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x150 => {
        Name => 'LuminanceCurveLimits',
        Notes => '4 numbers: input and output highlight and shadow points',
        Format => 'int16u[4]',
    },
    0x159 => {
        Name => 'ToneCurveInterpolation',
        PrintConv => { 0 => 'Curve', 1 => 'Straight' },
    },
    0x160 => {
        Name => 'RedCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    # 0x193 same as 0x159
    0x19a => {
        Name => 'GreenCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    # 0x1cd same as 0x159
    0x1d4 => {
        Name => 'BlueCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x18a => {
        Name => 'RedCurveLimits',
        Format => 'int16u[4]',
    },
    0x1c4 => {
        Name => 'GreenCurveLimits',
        Format => 'int16u[4]',
    },
    0x1fe => {
        Name => 'BlueCurveLimits',
        Format => 'int16u[4]',
    },
    # 0x207 same as 0x159
    0x20e => {
        Name => 'RGBCurvePoints',
        Format => 'int16u[21]',
        PrintConv => 'Image::ExifTool::CanonVRD::ToneCurvePrint($val)',
        PrintConvInv => 'Image::ExifTool::CanonVRD::ToneCurvePrintInv($val)',
    },
    0x238 => {
        Name => 'RGBCurveLimits',
        Format => 'int16u[4]',
    },
    # 0x241 same as 0x159
    0x244 => {
        Name => 'CropActive',
        Format => 'int16u',
        PrintConv => \%noYes,
    },
    0x246 => {
        Name => 'CropLeft',
        Notes => 'crop coordinates in original unrotated image',
        Format => 'int16u',
    },
    0x248 => {
        Name => 'CropTop',
        Format => 'int16u',
    },
    0x24a => {
        Name => 'CropWidth',
        Format => 'int16u',
    },
    0x24c => {
        Name => 'CropHeight',
        Format => 'int16u',
    },
    0x25a => {
        Name => 'SharpnessAdj',
        Format => 'int16u',
    },
    0x260 => {
        Name => 'CropAspectRatio',
        Format => 'int16u',
        PrintConv => {
            0 => 'Free',
            1 => '3:2',
            2 => '2:3',
            3 => '4:3',
            4 => '3:4',
            5 => 'A-size Landscape',
            6 => 'A-size Portrait',
            7 => 'Letter-size Landscape',
            8 => 'Letter-size Portrait',
            9 => '4:5',
            10 => '5:4',
            11 => '1:1',
            12 => 'Circle',
            65535 => 'Custom',
        },
    },
    0x262 => {
        Name => 'ConstrainedCropWidth',
        Format => 'float',
        PrintConv => 'sprintf("%.7g",$val)',
        PrintConvInv => '$val',
    },
    0x266 => {
        Name => 'ConstrainedCropHeight',
        Format => 'float',
        PrintConv => 'sprintf("%.7g",$val)',
        PrintConvInv => '$val',
    },
    0x26a => {
        Name => 'CheckMark',
        Format => 'int16u',
        PrintConv => {
            0 => 'Clear',
            1 => 1,
            2 => 2,
            3 => 3,
        },
    },
    0x26e => {
        Name => 'Rotation',
        Format => 'int16u',
        PrintConv => {
            0 => 0,
            1 => 90,
            2 => 180,
            3 => 270,
        },
    },
    0x270 => {
        Name => 'WorkColorSpace',
        Format => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
            2 => 'Wide Gamut RGB',
            3 => 'Apple RGB',
            4 => 'ColorMatch RGB',
        },
    },
    # (VRD 1.0.0 edit data ends here -- 0x272 bytes)
);

# VRD Stamp Tool tags (ref PH)
%Image::ExifTool::CanonVRD::StampTool = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0x00 => {
        Name => 'StampToolCount',
        Format => 'int32u',
    },
);

# VRD version 2 and 3 tags (ref PH)
%Image::ExifTool::CanonVRD::Ver2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    FORMAT => 'int16s',
    DATAMEMBER => [ 0x58, 0xdf, 0xea ], # (required for DataMember and var-format tags)
    GROUPS => { 2 => 'Image' },
    NOTES => 'Tags added in DPP version 2.0 and later.',
    0x02 => {
        Name => 'PictureStyle',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Standard',
            1 => 'Portrait',
            2 => 'Landscape',
            3 => 'Neutral',
            4 => 'Faithful',
            5 => 'Monochrome',
            6 => 'Unknown?', # PH (maybe in-camera custom picture style?)
            7 => 'Custom',
        },
    },
    0x03 => {
        Name => 'IsCustomPictureStyle',
        PrintConv => \%noYes,
    },
    # 0x08: 3
    # 0x09: 4095
    # 0x0a: 0
    # 0x0b: 4095
    # 0x0c: 0
    0x0d => 'StandardRawColorTone',
    0x0e => 'StandardRawSaturation',
    0x0f => 'StandardRawContrast',
    0x10 => {
        Name => 'StandardRawLinear',
        PrintConv => \%noYes,
    },
    0x11 => 'StandardRawSharpness',
    0x12 => 'StandardRawHighlightPoint',
    0x13 => 'StandardRawShadowPoint',
    0x14 => 'StandardOutputHighlightPoint', #2
    0x15 => 'StandardOutputShadowPoint', #2
    0x16 => 'PortraitRawColorTone',
    0x17 => 'PortraitRawSaturation',
    0x18 => 'PortraitRawContrast',
    0x19 => {
        Name => 'PortraitRawLinear',
        PrintConv => \%noYes,
    },
    0x1a => 'PortraitRawSharpness',
    0x1b => 'PortraitRawHighlightPoint',
    0x1c => 'PortraitRawShadowPoint',
    0x1d => 'PortraitOutputHighlightPoint',
    0x1e => 'PortraitOutputShadowPoint',
    0x1f => 'LandscapeRawColorTone',
    0x20 => 'LandscapeRawSaturation',
    0x21 => 'LandscapeRawContrast',
    0x22 => {
        Name => 'LandscapeRawLinear',
        PrintConv => \%noYes,
    },
    0x23 => 'LandscapeRawSharpness',
    0x24 => 'LandscapeRawHighlightPoint',
    0x25 => 'LandscapeRawShadowPoint',
    0x26 => 'LandscapeOutputHighlightPoint',
    0x27 => 'LandscapeOutputShadowPoint',
    0x28 => 'NeutralRawColorTone',
    0x29 => 'NeutralRawSaturation',
    0x2a => 'NeutralRawContrast',
    0x2b => {
        Name => 'NeutralRawLinear',
        PrintConv => \%noYes,
    },
    0x2c => 'NeutralRawSharpness',
    0x2d => 'NeutralRawHighlightPoint',
    0x2e => 'NeutralRawShadowPoint',
    0x2f => 'NeutralOutputHighlightPoint',
    0x30 => 'NeutralOutputShadowPoint',
    0x31 => 'FaithfulRawColorTone',
    0x32 => 'FaithfulRawSaturation',
    0x33 => 'FaithfulRawContrast',
    0x34 => {
        Name => 'FaithfulRawLinear',
        PrintConv => \%noYes,
    },
    0x35 => 'FaithfulRawSharpness',
    0x36 => 'FaithfulRawHighlightPoint',
    0x37 => 'FaithfulRawShadowPoint',
    0x38 => 'FaithfulOutputHighlightPoint',
    0x39 => 'FaithfulOutputShadowPoint',
    0x3a => {
        Name => 'MonochromeFilterEffect',
        PrintConv => {
            -2 => 'None',
            -1 => 'Yellow',
            0 => 'Orange',
            1 => 'Red',
            2 => 'Green',
        },
    },
    0x3b => {
        Name => 'MonochromeToningEffect',
        PrintConv => {
            -2 => 'None',
            -1 => 'Sepia',
            0 => 'Blue',
            1 => 'Purple',
            2 => 'Green',
        },
    },
    0x3c => 'MonochromeContrast',
    0x3d => {
        Name => 'MonochromeLinear',
        PrintConv => \%noYes,
    },
    0x3e => 'MonochromeSharpness',
    0x3f => 'MonochromeRawHighlightPoint',
    0x40 => 'MonochromeRawShadowPoint',
    0x41 => 'MonochromeOutputHighlightPoint',
    0x42 => 'MonochromeOutputShadowPoint',
    0x45 => { Name => 'UnknownContrast',            Unknown => 1 },
    0x46 => {
        Name => 'UnknownLinear',
        Unknown => 1,
        PrintConv => \%noYes,
    },
    0x47 => { Name => 'UnknownSharpness',           Unknown => 1 },
    0x48 => { Name => 'UnknownRawHighlightPoint',   Unknown => 1 },
    0x49 => { Name => 'UnknownRawShadowPoint',      Unknown => 1 },
    0x4a => { Name => 'UnknownOutputHighlightPoint',Unknown => 1 },
    0x4b => { Name => 'UnknownOutputShadowPoint',   Unknown => 1 },
    0x4e => 'CustomContrast',
    0x4f => {
        Name => 'CustomLinear',
        PrintConv => \%noYes,
    },
    0x50 => 'CustomSharpness',
    0x51 => 'CustomRawHighlightPoint',
    0x52 => 'CustomRawShadowPoint',
    0x53 => 'CustomOutputHighlightPoint',
    0x54 => 'CustomOutputShadowPoint',
    0x58 => {
        Name => 'CustomPictureStyleData',
        Format => 'var_int16u',
        Binary => 1,
        Notes => 'variable-length data structure',
        Writable => 0,
        RawConv => 'length($val) == 2 ? undef : $val', # ignore if no data
    },
    # (VRD 2.0.0 edit data ends here: 178 bytes, index 0x59)
    0x5e => [{
        Name => 'ChrominanceNoiseReduction',
        Condition => '$$self{VRDVersion} < 330',
        Notes => 'VRDVersion prior to 3.3.0',
        PrintConv => {
            0   => 'Off',
            58  => 'Low',
            100 => 'High',
        },
    },{ #1
        Name => 'ChrominanceNoiseReduction',
        Notes => 'VRDVersion 3.3.0 or later',
        PrintHex => 1,
        PrintConvColumns => 4,
        PrintConv => {
            0x00 => 0,
            0x10 => 1,
            0x21 => 2,
            0x32 => 3,
            0x42 => 4,
            0x53 => 5,
            0x64 => 6,
            0x74 => 7,
            0x85 => 8,
            0x96 => 9,
            0xa6 => 10,
            0xa7 => 11,
            0xa8 => 12,
            0xa9 => 13,
            0xaa => 14,
            0xab => 15,
            0xac => 16,
            0xad => 17,
            0xae => 18,
            0xaf => 19,
            0xb0 => 20,
        },
    }],
    0x5f => [{
        Name => 'LuminanceNoiseReduction',
        Condition => '$$self{VRDVersion} < 330',
        Notes => 'VRDVersion prior to 3.3.0',
        PrintConv => {
            0   => 'Off',
            65  => 'Low',
            100 => 'High',
        },
    },{ #1
        Name => 'LuminanceNoiseReduction',
        Notes => 'VRDVersion 3.3.0 or later',
        PrintHex => 1,
        PrintConvColumns => 4,
        PrintConv => {
            0x00 => 0,
            0x41 => 1,
            0x64 => 2,
            0x6e => 3,
            0x78 => 4,
            0x82 => 5,
            0x8c => 6,
            0x96 => 7,
            0xa0 => 8,
            0xaa => 9,
            0xb4 => 10,
            0xb5 => 11,
            0xb6 => 12,
            0xb7 => 13,
            0xb8 => 14,
            0xb9 => 15,
            0xba => 16,
            0xbb => 17,
            0xbc => 18,
            0xbd => 19,
            0xbe => 20,
        },
    }],
    0x60 => [{
        Name => 'ChrominanceNR_TIFF_JPEG',
        Condition => '$$self{VRDVersion} < 330',
        Notes => 'VRDVersion prior to 3.3.0',
        PrintConv => {
            0   => 'Off',
            33  => 'Low',
            100 => 'High',
        },
    },{ #1
        Name => 'ChrominanceNR_TIFF_JPEG',
        Notes => 'VRDVersion 3.3.0 or later',
        PrintHex => 1,
        PrintConvColumns => 4,
        PrintConv => {
            0x00 => 0,
            0x10 => 1,
            0x21 => 2,
            0x32 => 3,
            0x42 => 4,
            0x53 => 5,
            0x64 => 6,
            0x74 => 7,
            0x85 => 8,
            0x96 => 9,
            0xa6 => 10,
            0xa7 => 11,
            0xa8 => 12,
            0xa9 => 13,
            0xaa => 14,
            0xab => 15,
            0xac => 16,
            0xad => 17,
            0xae => 18,
            0xaf => 19,
            0xb0 => 20,
        },
    }],
    # 0x61: 1
    # (VRD 3.0.0 edit data ends here: 196 bytes, index 0x62)
    0x62 => {
        Name => 'ChromaticAberrationOn',
        ValueConv => \%noYes,
    },
    0x63 => {
        Name => 'DistortionCorrectionOn',
        ValueConv => \%noYes,
    },
    0x64 => {
        Name => 'PeripheralIlluminationOn',
        ValueConv => \%noYes,
    },
    0x65 => {
        Name => 'ColorBlur',
        ValueConv => \%noYes,
    },
    0x66 => {
        Name => 'ChromaticAberration',
        ValueConv => '$val / 0x400',
        ValueConvInv => 'int($val * 0x400 + 0.5)',
        PrintConv => 'sprintf("%.0f%%", $val * 100)',
        PrintConvInv => 'ToFloat($val) / 100',
    },
    0x67 => {
        Name => 'DistortionCorrection',
        ValueConv => '$val / 0x400',
        ValueConvInv => 'int($val * 0x400 + 0.5)',
        PrintConv => 'sprintf("%.0f%%", $val * 100)',
        PrintConvInv => 'ToFloat($val) / 100',
    },
    0x68 => {
        Name => 'PeripheralIllumination',
        ValueConv => '$val / 0x400',
        ValueConvInv => 'int($val * 0x400 + 0.5)',
        PrintConv => 'sprintf("%.0f%%", $val * 100)',
        PrintConvInv => 'ToFloat($val) / 100',
    },
    0x69 => {
        Name => 'AberrationCorrectionDistance',
        Notes => '100% = infinity',
        RawConv => '$val == 0x7fff ? undef : $val',
        ValueConv => '1 - $val / 0x400',
        ValueConvInv => 'int((1 - $val) * 0x400 + 0.5)',
        PrintConv => 'sprintf("%.0f%%", $val * 100)',
        PrintConvInv => 'ToFloat($val) / 100',
    },
    0x6a => 'ChromaticAberrationRed',
    0x6b => 'ChromaticAberrationBlue',
    0x6d => { #1
        Name => 'LuminanceNR_TIFF_JPEG',
        Notes => 'val = raw / 10',
        ValueConv => '$val / 10',
        ValueConvInv => 'int($val * 10 + 0.5)',
    },
    # (VRD 3.4.0 edit data ends here: 220 bytes, index 0x6e)
    0x6e => {
        Name => 'AutoLightingOptimizerOn',
        PrintConv => \%noYes,
    },
    0x6f => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            100 => 'Low',
            200 => 'Standard',
            300 => 'Strong',
            0x7fff => 'n/a', #1
        },
    },
    # 0x71: 200
    # 0x73: 100
    # (VRD 3.5.0 edit data ends here: 232 bytes, index 0x74)
    0x75 => {
        Name => 'StandardRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x76 => {
        Name => 'PortraitRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x77 => {
        Name => 'LandscapeRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x78 => {
        Name => 'NeutralRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x79 => {
        Name => 'FaithfulRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x7a => {
        Name => 'MonochromeRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x7b => {
        Name => 'UnknownRawHighlight',
        Unknown => 1,
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x7c => {
        Name => 'CustomRawHighlight',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x7e => {
        Name => 'StandardRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x7f => {
        Name => 'PortraitRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x80 => {
        Name => 'LandscapeRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x81 => {
        Name => 'NeutralRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x82 => {
        Name => 'FaithfulRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x83 => {
        Name => 'MonochromeRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x84 => {
        Name => 'UnknownRawShadow',
        Unknown => 1,
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x85 => {
        Name => 'CustomRawShadow',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x8b => { #2
        Name => 'AngleAdj',
        Format => 'int32s',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x8e => {
        Name => 'CheckMark2',
        Format => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Clear',
            1 => 1,
            2 => 2,
            3 => 3,
            4 => 4,
            5 => 5,
        },
    },
    # (VRD 3.8.0 edit data ends here: 286 bytes, index 0x8f)
    0x90 => {
        Name => 'UnsharpMask',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x92 => 'StandardUnsharpMaskStrength',
    0x94 => 'StandardUnsharpMaskFineness',
    0x96 => 'StandardUnsharpMaskThreshold',
    0x98 => 'PortraitUnsharpMaskStrength',
    0x9a => 'PortraitUnsharpMaskFineness',
    0x9c => 'PortraitUnsharpMaskThreshold',
    0x9e => 'LandscapeUnsharpMaskStrength',
    0xa0 => 'LandscapeUnsharpMaskFineness',
    0xa2 => 'LandscapeUnsharpMaskThreshold',
    0xa4 => 'NeutraUnsharpMaskStrength',
    0xa6 => 'NeutralUnsharpMaskFineness',
    0xa8 => 'NeutralUnsharpMaskThreshold',
    0xaa => 'FaithfulUnsharpMaskStrength',
    0xac => 'FaithfulUnsharpMaskFineness',
    0xae => 'FaithfulUnsharpMaskThreshold',
    0xb0 => 'MonochromeUnsharpMaskStrength',
    0xb2 => 'MonochromeUnsharpMaskFineness',
    0xb4 => 'MonochromeUnsharpMaskThreshold',
    0xb6 => 'CustomUnsharpMaskStrength',
    0xb8 => 'CustomUnsharpMaskFineness',
    0xba => 'CustomUnsharpMaskThreshold',
    0xbc => 'CustomDefaultUnsharpStrength',
    0xbe => 'CustomDefaultUnsharpFineness',
    0xc0 => 'CustomDefaultUnsharpThreshold',
    # (VRD 3.9.1 edit data ends here: 392 bytes, index 0xc4)
    # 0xc9: 3    - some RawSharpness
    # 0xca: 4095 - some RawHighlightPoint
    # 0xcb: 0    - some RawShadowPoint
    # 0xcc: 4095 - some OutputHighlightPoint
    # 0xcd: 0    - some OutputShadowPoint
    # 0xd1: 3    - some UnsharpMaskStrength
    # 0xd3: 7    - some UnsharpMaskFineness
    # 0xd5: 3,4  - some UnsharpMaskThreshold
    0xd6 => {
        Name => 'CropCircleActive',
        PrintConv => \%noYes,
    },
    0xd7 => 'CropCircleX',
    0xd8 => 'CropCircleY',
    0xd9 => 'CropCircleRadius',
    # 0xda: 0, 1
    # 0xdb: 100
    0xdc => {
        Name => 'DLOOn',
        PrintConv => \%noYes,
    },
    0xdd => 'DLOSetting',
    # (VRD 3.11.0 edit data ends here: 444 bytes, index 0xde)
    0xde => {
        Name => 'DLOShootingDistance',
        Notes => '100% = infinity',
        RawConv => '$val == 0x7fff ? undef : $val',
        ValueConv => '1 - $val / 0x400',
        ValueConvInv => 'int((1 - $val) * 0x400 + 0.5)',
        PrintConv => 'sprintf("%.0f%%", $val * 100)',
        PrintConvInv => 'ToFloat($val) / 100',
    },
    0xdf => {
        Name => 'DLODataLength',
        Format => 'int32u',
        Writable => 0,
        # - have seen 65536 when DLO is Off
        #   --> this is my only sample where 0xda is 1 -- coincidence?
    },
    # 0xe1 - 0 without DLO, seen 3112 with DLO
    # (VRD 3.11.2 edit data ends here: 452 bytes, index 0xe2, unless DLO is on)
    0xe4 => 'DLOSettingApplied',
    0xe5 => {
        Name => 'DLOVersion', #(NC)
        Format => 'string[10]',
    },
    0xea => {
        Name => 'DLOData',
        LargeTag => 1, # large tag, so avoid storing unnecessarily
        Notes => 'variable-length Digital Lens Optimizer data, stored in JPEG-like format',
        Format => 'var_undef[$val{0xdf}]',
        Writable => 0,
        Binary => 1,
        RawConv => 'length($val) ? \$val : undef', # (don't extract if zero length)
    },
);

#------------------------------------------------------------------------------
# Tone curve print conversion
sub ToneCurvePrint($)
{
    my $val = shift;
    my @vals = split ' ', $val;
    return $val unless @vals == 21;
    my $n = shift @vals;
    return $val unless $n >= 2 and $n <= 10;
    $val = '';
    while ($n--) {
        $val and $val .= ' ';
        $val .= '(' . shift(@vals) . ',' . shift(@vals) . ')';
    }
    return $val;
}

#------------------------------------------------------------------------------
# Inverse print conversion for tone curve
sub ToneCurvePrintInv($)
{
    my $val = shift;
    my @vals = ($val =~ /\((\d+),(\d+)\)/g);
    return undef unless @vals >= 4 and @vals <= 20 and not @vals & 0x01;
    unshift @vals, scalar(@vals) / 2;
    while (@vals < 21) { push @vals, 0 }
    return join(' ',@vals);
}

#------------------------------------------------------------------------------
# Read/Write VRD edit data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: Reading: 1 on success; Writing: modified edit data, or undef if nothing changed
sub ProcessEditData($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $dataPos = $$dirInfo{DataPos};
    my $outfile = $$dirInfo{OutFile};
    my $dirLen = $$dirInfo{DirLen};
    my $dirEnd = $pos + $dirLen;
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my $oldChanged = $$et{CHANGED};

    $et->VerboseDir('VRD Edit Data', 0, $dirLen) unless $outfile;

    # loop through all records in the edit data
    my ($recNum, $recLen, $err);
    for ($recNum=0;; ++$recNum, $pos+=$recLen) {
        if ($pos + 4 > $dirEnd) {
            last if $pos == $dirEnd;    # all done if we arrived at end
            $recLen = 0;    # just reset record size (will exit loop on test below)
        } else {
            $recLen = Get32u($dataPt, $pos);
        }
        $pos += 4;          # move to start of record
        if ($pos + $recLen > $dirEnd) {
            $et->Warn('Possibly corrupt CanonVRD Edit record');
            $err = 1;
            last;
        }
        if ($verbose > 1 and not $outfile) {
            printf $out "$$et{INDENT}CanonVRD Edit record ($recLen bytes at offset 0x%x)\n",
                   $pos + $dataPos;
            if ($recNum and $verbose > 2) {
                my %parms = (
                    Start  => $pos,
                    Addr   => $pos + $dataPos,
                    Out    => $out,
                    Prefix => $$et{INDENT},
                );
                $parms{MaxLen} = $verbose == 3 ? 96 : 2048 if $verbose < 5;
                HexDump($dataPt, $recLen, %parms);
            }
        }

        # our edit information is the 0th record, so don't process the others
        next if $recNum;

        # process VRD edit information
        my $subTablePtr = GetTagTable('Image::ExifTool::CanonVRD::Edit');
        my $index;
        my %subdirInfo = (
            DataPt   => $dataPt,
            DataPos  => $dataPos,
            DirStart => $pos,
            DirLen   => $recLen,
        );
        my $subStart = 0;
        # loop through various sections of the VRD edit data
        for ($index=0; ; ++$index) {
            my $tagInfo = $$subTablePtr{$index} or last;
            my $subLen;
            my $maxLen = $recLen - $subStart;
            if ($$tagInfo{Size}) {
                $subLen = $$tagInfo{Size};
            } elsif (defined $$tagInfo{Size}) {
                # get size from int32u at $subStart
                last unless $subStart + 4 <= $recLen;
                $subLen = Get32u($dataPt, $subStart + $pos);
                $subStart += 4; # skip the length word
            } else {
                $subLen = $maxLen;
            }
            $subLen > $maxLen and $subLen = $maxLen;
            if ($subLen) {
                my $subTable = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                my $subName = $$tagInfo{Name};
                $subdirInfo{DirStart} = $subStart + $pos;
                $subdirInfo{DirLen} = $subLen;
                $subdirInfo{DirName} = $subName;
                if ($outfile) {
                    # rewrite this section of the VRD edit information
                    $verbose and print $out "  Rewriting Canon $subName\n";
                    my $newVal = $et->WriteDirectory(\%subdirInfo, $subTable);
                    substr($$dataPt, $pos+$subStart, $subLen) = $newVal if $newVal;
                } else {
                    $et->VPrint(0, "$$et{INDENT}$subName (SubDirectory) -->\n");
                    $et->VerboseDump($dataPt,
                        Start => $pos + $subStart,
                        Addr  => $dataPos + $pos + $subStart,
                        Len   => $subLen,
                    );
                    # extract tags from this section of the VRD edit information
                    $et->ProcessDirectory(\%subdirInfo, $subTable);
                }
            }
            # next section starts at the end of this one
            $subStart += $subLen;
        }
    }
    if ($outfile) {
        return undef if $oldChanged == $$et{CHANGED};
        return substr($$dataPt, $$dirInfo{DirStart}, $dirLen);
    }
    return $err ? 0 : 1;
}

#------------------------------------------------------------------------------
# Process VRD IHL data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessIHL($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $pos = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dirEnd = $pos + $dirLen;

    $et->VerboseDir('VRD IHL', 0, $dirLen);

    SetByteOrder('II'); # (make up your mind, Canon!)
    while ($pos + 48 <= $dirEnd) {
        my $hdr = substr($$dataPt, $pos, 48);
        unless ($hdr =~ /^IHL Created Optional Item Data\0\0/) {
            $et->Warn('Possibly corrupted VRD IHL data');
            last;
        }
        my $tag  = Get32u($dataPt, $pos + 36);
        my $size = Get32u($dataPt, $pos + 40); # size of data in IHL record
        my $next = Get32u($dataPt, $pos + 44); # size of complete IHL record
        if ($size > $next or $pos + 48 + $next > $dirEnd) {
            $et->Warn(sprintf('Bad size for VRD IHL tag 0x%.4x', $tag));
            last;
        }
        $pos += 48;
        $et->HandleTag($tagTablePtr, $tag, substr($$dataPt, $pos, $size),
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $pos,
            Size    => $size
        );
        $pos += $next;
    }
    return 1;
}    
    
#------------------------------------------------------------------------------
# Process VRD IHL EXIF data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessIHLExif($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $$et{DOC_NUM} = 1;
    # the IHL-edited maker notes may look messed up, but the offsets should be OK
    my $oldFix = $et->Options(FixBase => 0);
    my $rtnVal = $et->ProcessTIFF($dirInfo, $tagTablePtr);
    $et->Options(FixBase => $oldFix);
    delete $$et{DOC_NUM};
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Read/write Canon VRD file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a Canon VRD file, 0 otherwise, -1 on write error
sub ProcessVRD($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    my $num = $raf->Read($buff, 0x1c);

    # initialize write directories if necessary
    $et->InitWriteDirs(\%vrdMap, 'XMP') if $$dirInfo{OutFile};

    if (not $num and $$dirInfo{OutFile}) {
        # create new VRD file from scratch
        my $newVal = $et->GetNewValues('CanonVRD');
        if ($newVal) {
            $et->VPrint(0, "  Writing CanonVRD as a block\n");
            Write($$dirInfo{OutFile}, $newVal) or return -1;
            ++$$et{CHANGED};
        } else {
            # allow VRD to be created from individual tags
            if ($$et{ADD_DIRS}{CanonVRD}) {
                my $newVal = '';
                if (ProcessCanonVRD($et, { OutFile => \$newVal }) > 0) {
                    Write($$dirInfo{OutFile}, $newVal) or return -1;
                    ++$$et{CHANGED};
                    return 1;
                }
            }
            $et->Error('No CanonVRD information to write');
        }
    } else {
        $num == 0x1c or return 0;
        $buff =~ /^CANON OPTIONAL DATA\0/ or return 0;
        $et->SetFileType();
        $$dirInfo{DirName} = 'CanonVRD';    # set directory name for verbose output
        my $result = ProcessCanonVRD($et, $dirInfo);
        return $result if $result < 0;
        $result or $et->Warn('Format error in VRD file');
    }
    return 1;
}

#------------------------------------------------------------------------------
# Write VRD data record as a block
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: VRD data block (may be empty if no VRD data)
# Notes: Increments ExifTool CHANGED flag if changed
sub WriteCanonVRD($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access
    my $nvHash = $et->GetNewValueHash($Image::ExifTool::Extra{CanonVRD});
    my $val = $et->GetNewValues($nvHash);
    $val = '' unless defined $val;
    return undef unless $et->IsOverwriting($nvHash, $val);
    ++$$et{CHANGED};
    return $val;
}

#------------------------------------------------------------------------------
# Read/write CanonVRD information
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 not valid VRD, or -1 error writing
# - updates DataPos to point to start of CanonVRD information
# - updates DirLen to existing trailer length
sub ProcessCanonVRD($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $offset = $$dirInfo{Offset} || 0;
    my $outfile = $$dirInfo{OutFile};
    my $dataPt = $$dirInfo{DataPt};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my ($buff, $created, $err, $blockLen, $blockType, %didDir, $fromFile);
#
# The CanonVRD trailer has a 0x1c-byte header and a 0x40-byte footer,
# each beginning with "CANON OPTIONAL DATA\0" and containing an int32u
# giving the size of the contained data (at byte 0x18 and 0x14 respectively)
#
    if ($raf) {
        $fromFile = 1;
    } else {
        unless ($dataPt) {
            return 1 unless $outfile;
            # create blank VRD data from scratch
            my $blank = "CANON OPTIONAL DATA\0\0\x01\0\0\0\0\0\0" .
                        "CANON OPTIONAL DATA\0" . ("\0" x 42) . "\xff\xd9";
            $dataPt = \$blank;
            $verbose and printf $out "  Creating CanonVRD trailer\n";
            $created = 1;
        }
        $raf = new File::RandomAccess($dataPt);
    }
    # read and validate the footer
    $raf->Seek(-0x40-$offset, 2)    or return 0;
    $raf->Read($buff, 0x40) == 0x40 or return 0;
    $buff =~ /^CANON OPTIONAL DATA\0(.{4})/s or return 0;
    my $dirLen = unpack('N', $1) + 0x5c;  # size including header+footer

    # read and validate the header
    unless ($dirLen < 0x80000000 and
            $raf->Seek(-$dirLen, 1) and
            $raf->Read($buff, 0x1c) == 0x1c and
            $buff =~ /^CANON OPTIONAL DATA\0/ and
            $raf->Seek(-0x1c, 1))
    {
        $et->Warn('Bad CanonVRD trailer');
        return 0;
    }
    # set variables returned in dirInfo hash
    $$dirInfo{DataPos} = $raf->Tell();
    $$dirInfo{DirLen} = $dirLen;

    if ($outfile and ref $outfile eq 'SCALAR' and not length $$outfile) {
        # write directly to outfile to avoid duplicating data in memory
        $$outfile = $$dataPt unless $fromFile;
        # TRICKY! -- copy to outfile memory buffer and edit in place
        # (so we must disable all Write() calls for this case)
        $dataPt = $outfile;
    }
    if ($fromFile) {
        $dataPt = \$buff unless $dataPt;
        # read VRD data into memory if necessary
        unless ($raf->Read($$dataPt, $dirLen) == $dirLen) {
            $$dataPt = '' if $outfile eq $dataPt;
            $et->Warn('Error reading CanonVRD data');
            return 0;
        }
    }
    # exit quickly if writing and no CanonVRD tags are being edited
    if ($outfile and not exists $$et{EDIT_DIRS}{CanonVRD}) {
        print $out "$$et{INDENT}  [nothing changed]\n" if $verbose;
        return 1 if $outfile eq $dataPt;
        return Write($outfile, $$dataPt) ? 1 : -1;
    }
    # extract CanonVRD block if copying tags, or if requested
    if (($$et{TAGS_FROM_FILE} and not $$et{EXCL_TAG_LOOKUP}{canonvrd}) or
        $$et{REQ_TAG_LOOKUP}{canonvrd})
    {
        $et->FoundTag('CanonVRD', $buff);
    }

    if ($outfile) {
        $verbose and not $created and printf $out "  Rewriting CanonVRD trailer\n";
        # delete CanonVRD information if specified
        if ($$et{DEL_GROUP}{CanonVRD} or $$et{DEL_GROUP}{Trailer} or
            # also delete if writing as a block (will get added back again later)
            $$et{NEW_VALUE}{$Image::ExifTool::Extra{CanonVRD}})
        {
            if ($$et{FILE_TYPE} eq 'VRD') {
                my $newVal = $et->GetNewValues('CanonVRD');
                if ($newVal) {
                    $verbose and printf $out "  Writing CanonVRD as a block\n";
                    if ($outfile eq $dataPt) {
                        $$outfile = $newVal;
                    } else {
                        Write($outfile, $newVal) or return -1;
                    }
                    ++$$et{CHANGED};
                } else {
                    $et->Error("Can't delete all CanonVRD information from a VRD file");
                }
            } else {
                $verbose and printf $out "  Deleting CanonVRD trailer\n";
                $$outfile = '' if $outfile eq $dataPt;
                ++$$et{CHANGED};
            }
            return 1;
        }
        # write now and return if CanonVRD was set as a block
        my $val = $et->GetNewValues('CanonVRD');
        if ($val) {
            $verbose and print $out "  Writing CanonVRD as a block\n";
            if ($outfile eq $dataPt) {
                $$outfile = $val;
            } else {
                Write($outfile, $val) or return -1;
            }
            ++$$et{CHANGED};
            return 1;
        }
    } elsif ($verbose or $$et{HTML_DUMP}) {
        $et->DumpTrailer($dirInfo) if $$dirInfo{RAF};
    }

    $tagTablePtr = GetTagTable('Image::ExifTool::CanonVRD::Main');

    # validate VRD trailer and get position and length of edit record
    SetByteOrder('MM');
    my $pos = 0x1c; # start at end of header

    # loop through the VRD blocks
    for (;;) {
        my $end = $dirLen - 0x40;   # end of last VRD block (and start of footer)
        if ($pos + 8 > $end) {
            last if $pos == $end;
            $blockLen = $end;       # mark as invalid
        } else {
            $blockType = Get32u($dataPt, $pos);
            $blockLen = Get32u($dataPt, $pos + 4);
        }
        $pos += 8;  # move to start of block
        if ($pos + $blockLen > $end) {
            $et->Warn('Possibly corrupt CanonVRD block');
            last;
        }
        if ($verbose > 1 and not $outfile) {
            printf $out "  CanonVRD block 0x%.8x ($blockLen bytes at offset 0x%x)\n",
                $blockType, $pos + $$dirInfo{DataPos};
            if ($verbose > 2) {
                my %parms = (
                    Start  => $pos,
                    Addr   => $pos + $$dirInfo{DataPos},
                    Out    => $out,
                    Prefix => $$et{INDENT},
                );
                $parms{MaxLen} = $verbose == 3 ? 96 : 2048 if $verbose < 5;
                HexDump($dataPt, $blockLen, %parms);
            }
        }
        my $tagInfo = $$tagTablePtr{$blockType};
        unless ($tagInfo) {
            unless ($et->Options('Unknown')) {
                $pos += $blockLen;  # step to next block
                next;
            }
            my $name = sprintf('CanonVRD_0x%.8x', $blockType);
            my $desc = $name;
            $desc =~ tr/_/ /;
            $tagInfo = {
                Name        => $name,
                Description => $desc,
                Binary      => 1,
            };
            AddTagToTable($tagTablePtr, $blockType, $tagInfo);
        }
        if ($$tagInfo{SubDirectory}) {
            my $subTablePtr = GetTagTable($$tagInfo{SubDirectory}{TagTable});
            my %subdirInfo = (
                DataPt   => $dataPt,
                DataLen  => length $$dataPt,
                DataPos  => $$dirInfo{DataPos},
                DirStart => $pos,
                DirLen   => $blockLen,
                DirName  => $$tagInfo{Name},
                Parent   => 'CanonVRD',
                OutFile  => $outfile,
            );
            if ($outfile) {
                # set flag indicating we did this directory
                $didDir{$$tagInfo{Name}} = 1;
                my ($dat, $diff);
                if ($$et{NEW_VALUE}{$tagInfo}) {
                    # write as a block
                    $et->VPrint(0, "Writing $$tagInfo{Name} as a block\n");
                    $dat = $et->GetNewValues($tagInfo);
                    $dat = '' unless defined $dat;
                    ++$$et{CHANGED};
                } else {
                    $dat = $et->WriteDirectory(\%subdirInfo, $subTablePtr);
                }
                # update data with new directory
                if (defined $dat) {
                    if (length $dat or $$et{FILE_TYPE} !~ /^(CRW|VRD)$/) {
                        # replace with new block (updating the block length word)
                        substr($$dataPt, $pos-4, $blockLen+4) = Set32u(length $dat) . $dat;
                    } else {
                        # remove block totally (CRW/VRD files only)
                        substr($$dataPt, $pos-8, $blockLen+8) = '';
                    }
                    # make necessary adjustments if block changes length
                    if (($diff = length($$dataPt) - $dirLen) != 0) {
                        $pos += $diff;
                        $dirLen += $diff;
                        # update the new VRD length in the header/footer
                        Set32u($dirLen - 0x5c, $dataPt, 0x18);
                        Set32u($dirLen - 0x5c, $dataPt, $dirLen - 0x2c);
                    }
                }
            } else {
                # extract as a block if requested
                $et->ProcessDirectory(\%subdirInfo, $subTablePtr);
            }
        } else {
            $et->HandleTag($tagTablePtr, $blockType, substr($$dataPt, $pos, $blockLen));
        }
        $pos += $blockLen;  # step to next block
    }
    if ($outfile) {
        # create XMP block if necessary (CRW/VRD files only)
        if ($$et{ADD_DIRS}{CanonVRD} and not $didDir{XMP}) {
            my $subTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
            my $dat = $et->WriteDirectory({ Parent => 'CanonVRD' }, $subTablePtr);
            if ($dat) {
                my $blockLen = length $dat;
                substr($$dataPt, -0x40, 0) = Set32u(0xffff00f6) . Set32u(length $dat) . $dat;
                $dirLen = length $$dataPt;
                # update the new VRD length in the header/footer
                Set32u($dirLen - 0x5c, $dataPt, 0x18);
                Set32u($dirLen - 0x5c, $dataPt, $dirLen - 0x2c);
            }
        }
        # write CanonVRD trailer unless it is empty
        if (length $$dataPt) {
            Write($outfile, $$dataPt) or $err = 1 unless $outfile eq $dataPt;
        } else {
            $verbose and printf $out "  Deleting CanonVRD trailer\n";
        }
    }
    undef $buff;
    return $err ? -1 : 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::CanonVRD - Read/write Canon VRD information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write VRD Recipe Data information as written by the Canon Digital Photo
Professional software.  This information is written to VRD files, and as a
trailer in JPEG, CRW, CR2 and TIFF images.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Bogdan and Gert Kello for decoding some tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/CanonVRD Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

