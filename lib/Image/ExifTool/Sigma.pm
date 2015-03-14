#------------------------------------------------------------------------------
# File:         Sigma.pm
#
# Description:  Sigma/Foveon EXIF maker notes tags
#
# Revisions:    04/06/2004 - P. Harvey Created
#               02/20/2007 - PH added SD14 tags
#               24/06/2010 - PH decode some SD15 tags
#
# References:   1) http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html
#               2) Niels Kristian Bech Jensen
#               3) Iliah Borg private communication (LibRaw)
#------------------------------------------------------------------------------

package Image::ExifTool::Sigma;

use strict;
use vars qw($VERSION %sigmaLensTypes);
use Image::ExifTool::Exif;

$VERSION = '1.16';

# sigma LensType lookup (ref 3)
%sigmaLensTypes = (
    Notes => q{
        Decimal values have been added to differentiate lenses which would otherwise
        have the same LensType, and are used by the Composite LensID tag when
        attempting to identify the specific lens model.
    },
    # 0 => 'Sigma 50mm F2.8 EX Macro', (0 used for other lenses too)
    # 8 - 18-125mm LENSARANGE@18mm=22-4
    16 => 'Sigma 18-50mm F3.5-5.6 DC', #PH
    103 => 'Sigma 180mm F3.5 EX IF HSM APO Macro',
    104 => 'Sigma 150mm F2.8 EX DG HSM APO Macro',
    105 => 'Sigma 180mm F3.5 EX DG HSM APO Macro',
    106 => 'Sigma 150mm F2.8 EX DG OS HSM APO Macro',
    107 => 'Sigma 180mm F2.8 EX DG OS HSM APO Macro',
    129 => 'Sigma 14mm F2.8 EX Aspherical', #PH
    131 => 'Sigma 17-70mm F2.8-4.5 DC Macro', #PH
    134 => 'Sigma 100-300mm F4 EX DG HSM APO',
    135 => 'Sigma 120-300mm F2.8 EX DG HSM APO',
    136 => 'Sigma 120-300mm F2.8 EX DG OS HSM APO',
    137 => 'Sigma 120-300mm F2.8 DG OS HSM | S',
    143 => 'Sigma 600mm F8 Mirror',
    145 => 'Sigma Lens (145)', #PH
    145.1 => 'Sigma 15-30mm F3.5-4.5 EX DG Aspherical', #PH
    145.2 => 'Sigma 18-50mm F2.8 EX DG', #PH (NC)
    145.3 => 'Sigma 20-40mm F2.8 EX DG', #PH
    152 => 'Sigma APO 800mm F5.6 EX DG HSM',
    165 => 'Sigma 70-200mm F2.8 EX', # ...but what specific model?:
    # 70-200mm F2.8 EX APO - Original version, minimum focus distance 1.8m (1999)
    # 70-200mm F2.8 EX DG - Adds 'digitally optimized' lens coatings to reduce flare (2005)
    # 70-200mm F2.8 EX DG Macro (HSM) - Minimum focus distance reduced to 1m (2006)
    # 70-200mm F2.8 EX DG Macro HSM II - Improved optical performance (2007)
    169 => 'Sigma 18-50mm F2.8 EX DC', #PH (NC)
    183 => 'Sigma 500mm F4.5 EX HSM APO',
    184 => 'Sigma 500mm F4.5 EX DG HSM APO',
    194 => 'Sigma 300mm F2.8 EX HSM APO',
    195 => 'Sigma 300mm F2.8 EX DG HSM APO',
    200 => 'Sigma 12-24mm F4.5-5.6 EX DG ASP HSM',
    201 => 'Sigma 10-20mm F4-5.6 EX DC HSM',
    202 => 'Sigma 10-20mm F3.5 EX DC HSM',
    203 => 'Sigma 8-16mm F4.5-5.6 DC HSM',
    204 => 'Sigma 12-24mm F4.5-5.6 DG HSM II',
    210 => 'Sigma 18-35mm F1.8 DC HSM | A',
    256 => 'Sigma 105mm F2.8 EX Macro',
    257 => 'Sigma 105mm F2.8 EX DG Macro',
    258 => 'Sigma 105mm F2.8 EX DG OS HSM Macro',
    270 => 'Sigma 70mm F2.8 EX DG Macro', #2 (SD1)
    300 => 'Sigma 30mm F1.4 EX DC HSM',
    301 => 'Sigma 30mm F1.4 DC HSM | A',
    310 => 'Sigma 50mm F1.4 EX DG HSM',
    311 => 'Sigma 50mm F1.4 DG HSM | A',
    320 => 'Sigma 85mm F1.4 EX DG HSM',
    330 => 'Sigma 30mm F2.8 EX DN',
    340 => 'Sigma 35mm F1.4 DG HSM',
    345 => 'Sigma 50mm F2.8 EX Macro',
    346 => 'Sigma 50mm F2.8 EX DG Macro',
    400 => 'Sigma 9mm F2.8 EX DN',
    401 => 'Sigma 24mm F1.4 DG HSM | A',
    411 => 'Sigma 20mm F1.8 EX DG ASP RF',
    432 => 'Sigma 24mm F1.8 EX DG ASP Macro',
    440 => 'Sigma 28mm F1.8 EX DG ASP Macro',
    461 => 'Sigma 14mm F2.8 EX ASP HSM',
    475 => 'Sigma 15mm F2.8 EX Diagonal FishEye',
    476 => 'Sigma 15mm F2.8 EX DG Diagonal Fisheye',
    477 => 'Sigma 10mm F2.8 EX DC HSM Fisheye',
    483 => 'Sigma 8mm F4 EX Circular Fisheye',
    484 => 'Sigma 8mm F4 EX DG Circular Fisheye',
    485 => 'Sigma 8mm F3.5 EX DG Circular Fisheye',
    486 => 'Sigma 4.5mm F2.8 EX DC HSM Circular Fisheye',
    506 => 'Sigma 70-300mm F4-5.6 APO Macro Super II',
    507 => 'Sigma 70-300mm F4-5.6 DL Macro Super II',
    508 => 'Sigma 70-300mm F4-5.6 DG APO Macro',
    509 => 'Sigma 70-300mm F4-5.6 DG Macro',
    510 => 'Sigma 17-35 F2.8-4 EX DG ASP',
    512 => 'Sigma 15-30mm F3.5-4.5 EX DG ASP DF',
    513 => 'Sigma 20-40mm F2.8 EX DG',
    519 => 'Sigma 17-35 F2.8-4 EX ASP HSM',
    520 => 'Sigma 100-300mm F4.5-6.7 DL',
    521 => 'Sigma 18-50mm F3.5-5.6 DC Macro',
    527 => 'Sigma 100-300mm F4 EX IF HSM',
    529 => 'Sigma 120-300mm F2.8 EX HSM IF APO',
    547 => 'Sigma 24-60mm F2.8 EX DG',
    548 => 'Sigma 24-70mm F2.8 EX DG Macro',
    549 => 'Sigma 28-70mm F2.8 EX DG',
    566 => 'Sigma 70-200mm F2.8 EX IF APO',
    567 => 'Sigma 70-200mm F2.8 EX IF HSM APO',
    568 => 'Sigma 70-200mm F2.8 EX DG IF HSM APO',
    569 => 'Sigma 70-200 F2.8 EX DG HSM APO Macro',
    571 => 'Sigma 24-70mm F2.8 IF EX DG HSM',
    572 => 'Sigma 70-300mm F4-5.6 DG OS',
    579 => 'Sigma 70-200mm F2.8 EX DG HSM APO Macro', # (also II version)
    580 => 'Sigma 18-50mm F2.8 EX DC',
    581 => 'Sigma 18-50mm F2.8 EX DC Macro', #PH (SD1)
    582 => 'Sigma 18-50mm F2.8 EX DC HSM Macro',
    583 => 'Sigma 17-50mm F2.8 EX DC OS HSM', #PH (also SD1 Kit, is this HSM? - PH)
    589 => 'Sigma APO 70-200mm F2.8 EX DG OS HSM',
    595 => 'Sigma 300-800mm F5.6 EX DG APO HSM',
    597 => 'Sigma 200-500mm F2.8 APO EX DG',
   '5A8'=> 'Sigma 70-300mm F4-5.6 APO DG Macro (Motorized)',
   '5A9'=> 'Sigma 70-300mm F4-5.6 DG Macro (Motorized)',
    668 => 'Sigma 17-70mm F2.8-4 DC Macro OS HSM',
    686 => 'Sigma 50-200mm F4-5.6 DC OS HSM',
    691 => 'Sigma 50-150mm F2.8 EX DC APO HSM II',
    692 => 'Sigma APO 50-150mm F2.8 EX DC OS HSM',
    728 => 'Sigma 120-400mm F4.5-5.6 DG APO OS HSM',
    737 => 'Sigma 150-500mm F5-6.3 APO DG OS HSM',
    738 => 'Sigma 50-500mm F4.5-6.3 APO DG OS HSM',
    824 => 'Sigma 1.4X Teleconverter EX APO DG',
    853 => 'Sigma 18-125mm F3.8-5.6 DC OS HSM',
    861 => 'Sigma 18-50mm F2.8-4.5 DC OS HSM', #2 (SD1)
    876 => 'Sigma 2.0X Teleconverter EX APO DG',
    880 => 'Sigma 18-250mm F3.5-6.3 DC OS HSM',
    882 => 'Sigma 18-200mm F3.5-6.3 II DC OS HSM',
    883 => 'Sigma 18-250mm F3.5-6.3 DC Macro OS HSM',
    1003 => 'Sigma 19mm F2.8', #PH (DP1 Merrill kit)
    1004 => 'Sigma 30mm F2.8', #PH (DP2 Merrill kit)
    1005 => 'Sigma 50mm F2.8 Macro', #PH (DP3 Merrill kit)
    1006 => 'Sigma 19mm F2.8', #2 (DP1 Quattro kit)
    1007 => 'Sigma 30mm F2.8', #PH (DP2 Quattro kit)
    1008 => 'Sigma 50mm F2.8 Macro', #2 (DP3 Quattro kit)
    8900 => 'Sigma 70-300mm F4-5.6 DG OS', #PH (SD15)
   'A100'=> 'Sigma 24-70mm F2.8 DG Macro', #PH (SD15)
    # 'FFFF' - seen this for a 28-70mm F2.8 lens - PH
);

%Image::ExifTool::Sigma::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 'string',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are written by Sigma/Foveon cameras.  In the early days Sigma was
        a class leader by releasing their maker note specification to the public,
        but since then they have deviated from this standard and newer camera models
        are less than consistent about their metadata formats.
    },
    0x0002 => 'SerialNumber',
    0x0003 => 'DriveMode',
    0x0004 => 'ResolutionMode',
    0x0005 => 'AFMode',
    0x0006 => 'FocusSetting',
    0x0007 => 'WhiteBalance',
    0x0008 => {
        Name => 'ExposureMode',
        PrintConv => { #PH
            A => 'Aperture-priority AE',
            M => 'Manual',
            P => 'Program AE',
            S => 'Shutter speed priority AE',
        },
    },
    0x0009 => {
        Name => 'MeteringMode',
        PrintConv => { #PH
            A => 'Average',
            C => 'Center-weighted average',
            8 => 'Multi-segment',
        },
    },
    0x000a => 'LensFocalRange',
    0x000b => 'ColorSpace',
    # SIGMA PhotoPro writes these tags as strings, but some cameras (at least) write them as rational
    0x000c => [
        {
            Name => 'ExposureCompensation',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Expo:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Expo:%+.1f",$val) : undef',
        },
        { #PH
            Name => 'ExposureAdjust',
            Writable => 'rational64s',
            Unknown => 1,
        },
    ],
    0x000d => [
        {
            Name => 'Contrast',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Cont:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Cont:%+.1f",$val) : undef',
        },
        { #PH
            Name => 'Contrast',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x000e => [
        {
            Name => 'Shadow',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Shad:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Shad:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Shadow',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x000f => [
        {
            Name => 'Highlight',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/High:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("High:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Highlight',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x0010 => [
        {
            Name => 'Saturation',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Satu:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Satu:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Saturation',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x0011 => [
        {
            Name => 'Sharpness',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Shar:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Shar:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Sharpness',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x0012 => [
        {
            Name => 'X3FillLight',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Fill:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Fill:%+.1f",$val) : undef',
        },
        { #PH
            Name => 'X3FillLight',
            Writable => 'rational64s',
        },
    ],
    0x0014 => [
        {
            Name => 'ColorAdjustment',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/CC:\s*//, $val',
            ValueConvInv => 'IsInt($val) ? "CC:$val" : undef',
        },
        { #PH
            Name => 'ColorAdjustment',
            Writable => 'rational64s',
            Count => 3,
        },
    ],
    0x0015 => 'AdjustmentMode',
    0x0016 => {
        Name => 'Quality',
        ValueConv => '$val =~ s/Qual:\s*//, $val',
        ValueConvInv => 'IsInt($val) ? "Qual:$val" : undef',
    },
    0x0017 => 'Firmware',
    0x0018 => {
        Name => 'Software',
        Priority => 0,
    },
    0x0019 => 'AutoBracket',
    0x001a => [ #PH
        {
            Name => 'PreviewImageStart',
            Condition => '$format eq "int32u"',
            Notes => q{
                Sigma Photo Pro writes ChrominanceNoiseReduction here, but various
                models use this for PreviewImageStart
            },
            IsOffset => 1,
            OffsetPair => 0x001b,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            Protected => 2,
        },{ # (written by Sigma Photo Pro)
            Name => 'ChrominanceNoiseReduction',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Chro:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Chro:%+.1f",$val) : undef',
        },
        # the SD1 writes something else here (rational64s, value 0/10)
        # (but we can't test by model becaues Sigma Photo Pro writes this too)
    ],
    0x001b => [ #PH
        {
            Name => 'PreviewImageLength',
            Condition => '$format eq "int32u"',
            Notes => q{
                Sigma Photo Pro writes LuminanceNoiseReduction here, but various models use
                this for PreviewImageLength
            },
            OffsetPair => 0x001a,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            Protected => 2,
        },{ # (written by Sigma Photo Pro)
            Name => 'LuminanceNoiseReduction',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Luma:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Luma:%+.1f",$val) : undef',
        },
        # the SD1 writes something else here (rational64s, value 0/10)
    ],
    0x001c => [ #PH
        {
            Name => 'PreviewImageSize',
            Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
            Notes => q{
                PreviewImageStart for the SD1 and Merrill/Quattro models, and
                PreviewImageSize for others
            },
            Writable => 'int16u',
            Count => 2,
        },{
            Name => 'PreviewImageStart',
            Condition => '$format eq "int32u"',
            IsOffset => 1,
            OffsetPair => 0x001d,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            Protected => 2,
        },
    ],
    0x001d => [ #PH
        {
            Name => 'MakerNoteVersion',
            Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
            Notes => q{
                PreviewImageLength for the SD1 and Merrill/Quattro models, and
                MakerNoteVersion for others
            },
            Writable => 'undef',
        },{
            Name => 'PreviewImageLength',
            Condition => '$format eq "int32u"',
            OffsetPair => 0x001c,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            Protected => 2,
        },
    ],
    # 0x001e - int16u: 0, 4, 13 - flash mode for other models?
    0x001e => { #PH
        Name => 'PreviewImageSize',
        Condition => '$$self{Model} =~ /^SIGMA (DP\d (Merrill|Quattro))$/i',
        Notes => 'only valid for some models',
        Writable => 'int16u',
        Count => 2,
    },
    0x001f => [ #PH
        {
            Name => 'AFPoint', # (NC -- invalid for SD9,SD14?)
            Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
            Notes => q{
                MakerNoteVersion for the SD1 and Merrill/Quattro models, and AFPoint for
                others
            },
            # values: "", "Center", "Center,Center", "Right,Right"
        },{
            Name => 'MakerNoteVersion',
            Writable => 'undef',
        },
    ],
    # 0x0020 - string: " " for most models, or int16u: 4 for the DP3 Merrill
    # 0x0021 - string: " " for most models, or int8u[2]: '3 3' for the DP3 Merrill
    0x0022 => { #PH (NC)
        Name => 'FileFormat',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        # values: "JPG", "JPG-S", "JPG-P", "X3F", "X3F-S"
    },
    # 0x0023 - string: "", 10, 83, 131, 145, 150, 152, 169
    0x0024 => { # (invalid for SD9,SD14?)
        Name => 'Calibration',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
    },
    # 0x0025 - string: "", "0.70", "0.90"
    # 0x0026-2b - int32u: 0
    0x0026 => { #PH (NC)
        Name => 'FileFormat',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
    },
    0x0027 => { #PH
        Name => 'LensType',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        SeparateTable => 'LensType',
        ValueConvInv => '$val=~s/\.\d+$//; $val', # (truncate decimal part)
        PrintConv => \%sigmaLensTypes,
    },
    0x002a => { #PH
        Name => 'LensFocalRange',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'rational64u',
        Count => 2,
        PrintConv => '$val=~s/ / to /; $val',
        PrintConvInv => '$val=~s/to /; $val',
    },
    0x002b => { #PH
        Name => 'LensMaxApertureRange',
        # for most models this gives the max aperture at the long/short focal lengths,
        # but for some models this gives the min/max aperture
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'rational64u',
        Count => 2,
        PrintConv => '$val=~s/ / to /; $val',
        PrintConvInv => '$val=~s/to /; $val',
    },
    0x002c => { #PH
        Name => 'ColorMode',
        Condition => '$format eq "int32u"',
        Notes => 'not valid for some models',
        Writable => 'int32u',
        # this tag written by Sigma Photo Pro even for cameras that write 'n/a' here
        PrintConv => {
            0 => 'n/a',
            1 => 'Sepia',
            2 => 'B&W',
            3 => 'Standard',
            4 => 'Vivid',
            5 => 'Neutral',
            6 => 'Portrait',
            7 => 'Landscape',
            8 => 'FOV Classic Blue',
        },
    },
    # 0x002d - int32u: 0
    # 0x002e - rational64s: (the negative of FlashExposureComp, but why?)
    # 0x002f - int32u: 0, 1
    0x0030 => [ #PH
        {
            Name => 'LensApertureRange',
            Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
            Notes => q{
                Calibration for the SD1 and Merrill/Quattro models, and LensApertureRange
                for others. Note that LensApertureRange changes with focal length, and some
                models report the maximum aperture here
            },
        },{
            Name => 'Calibration',
        },
    ],
    0x0031 => { #PH
        Name => 'FNumber',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
        Priority => 0,
    },
    0x0032 => { #PH
        Name => 'ExposureTime',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        Priority => 0,
    },
    0x0033 => { #PH
        Name => 'ExposureTime2',
        Condition => '$$self{Model} !~ / (SD1|SD9|SD15|Merrill|Quattro)$/',
        Notes => 'models other than the SD1, SD9, SD15 and Merrill/Quattro models',
        Writable => 'string',
        ValueConv => '$val * 1e-6',
        ValueConvInv => 'int($val * 1e6 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0034 => { #PH
        Name => 'BurstShot',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'int32u',
    },
    # 0x0034 - int32u: 0,1,2,3 or 4
    0x0035 => { #PH
        Name => 'ExposureCompensation',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64s',
        # add a '+' sign to positive values
        PrintConv => '$val and $val =~ s/^(\d)/\+$1/; $val',
        PrintConvInv => '$val',
    },
    # 0x0036 - string: "                    "
    # 0x0037-38 - string: ""
    0x0039 => { #PH (invalid for SD9, SD14?)
        Name => 'SensorTemperature',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        # (string format)
        PrintConv => 'IsInt($val) ? "$val C" : $val',
        PrintConvInv => '$val=~s/ ?C$//; $val',
    },
    0x003a => { #PH
        Name => 'FlashExposureComp',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64s',
    },
    0x003b => { #PH (how is this different from other Firmware?)
        Name => 'Firmware',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Priority => 0,
    },
    0x003c => { #PH
        Name => 'WhiteBalance',
        Condition => '$$self{Model} !~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Priority => 0,
    },
    0x003d => { #PH (new for SD15 and SD1)
        Name => 'PictureMode',
        Notes => 'same as ColorMode, but "Standard" when ColorMode is Sepia or B&W',
    },
    0x0048 => { #PH
        Name => 'LensApertureRange',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
    },
    0x0049 => { #PH
        Name => 'FNumber',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
        Priority => 0,
    },
    0x004a => { #PH
        Name => 'ExposureTime',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        Priority => 0,
    },
    0x004b => [{ #PH
        Name => 'ExposureTime2',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d Merrill)$/',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'string',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },{
        Name => 'ExposureTime2',
        Condition => '$$self{Model} =~ /^SIGMA dp\d Quattro$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'string',
        ValueConv => '$val / 1000000',
        ValueConvInv => '$val * 1000000',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    }],
    0x004d => { #PH
        Name => 'ExposureCompensation',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'rational64s',
        # add a '+' sign to positive values
        PrintConv => '$val and $val =~ s/^(\d)/\+$1/; $val',
        PrintConvInv => '$val',
    },
    # 0x0054 - string: "F20","F23"
    0x0055 => { #PH
        Name => 'SensorTemperature',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        # (string format)
        PrintConv => 'IsInt($val) ? "$val C" : $val',
        PrintConvInv => '$val=~s/ ?C$//; $val',
    },
    0x0056 => { #PH (NC)
        Name => 'FlashExposureComp',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Writable => 'rational64s',
    },
    0x0057 => { #PH (how is this different from other Firmware?)
        Name => 'Firmware',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Priority => 0,
    },
    0x0058 => { #PH
        Name => 'WhiteBalance',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        Priority => 0,
    },
    0x0059 => { #PH
        Name => 'DigitalFilter',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d (Merrill|Quattro))$/i',
        Notes => 'SD1 and Merrill/Quattro models only',
        # seen: Standard, Landscape,Monochrome,Neutral,Portrait,Sepia,Vivid
    },
    # 0x005a/b/c - rational64s: 0/10 for the SD1
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Sigma - Sigma/Foveon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sigma and Foveon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sigma Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
