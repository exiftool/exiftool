#------------------------------------------------------------------------------
# File:         FujiFilm.pm
#
# Description:  Read/write FujiFilm maker notes and RAF images
#
# Revisions:    11/25/2003 - P. Harvey Created
#               11/14/2007 - PH Added ability to write RAF images
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) http://homepage3.nifty.com/kamisaka/makernote/makernote_fuji.htm (2007/09/11)
#               3) Michael Meissner private communication
#               4) Paul Samuelson private communication (S5)
#               5) http://www.cybercom.net/~dcoffin/dcraw/
#               6) http://forums.dpreview.com/forums/readflat.asp?forum=1012&thread=31350384
#                  and http://forum.photome.de/viewtopic.php?f=2&t=353&p=742#p740
#               7) Kai Lappalainen private communication
#               8) https://exiftool.org/forum/index.php/topic,5223.0.html
#               9) Zilvinas Brobliauskas private communication
#               10) Albert Shan private communication
#               11) https://exiftool.org/forum/index.php/topic,8377.0.html
#               12) https://exiftool.org/forum/index.php/topic,9607.0.html
#               13) https://exiftool.org/forum/index.php/topic=10481.0.html
#               IB) Iliah Borg private communication (LibRaw)
#               JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::FujiFilm;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '2.00';

sub ProcessFujiDir($$$);
sub ProcessFaceRec($$$);
sub ProcessMRAW($$$);

# the following RAF version numbers have been tested for writing:
# (as of ExifTool 11.70, this lookup is no longer used if the version number is numerical)
my %testedRAF = (
    '0100' => 'E550, E900, F770, S5600, S6000fd, S6500fd, HS10/HS11, HS30, S200EXR, X100, XF1, X-Pro1, X-S1, XQ2 Ver1.00, X-T100, GFX 50R, XF10',
    '0101' => 'X-E1, X20 Ver1.01, X-T3',
    '0102' => 'S100FS, X10 Ver1.02',
    '0103' => 'IS Pro and X-T5 Ver1.03',
    '0104' => 'S5Pro Ver1.04',
    '0106' => 'S5Pro Ver1.06',
    '0111' => 'S5Pro Ver1.11',
    '0114' => 'S9600 Ver1.00',
    '0120' => 'X-T4 Ver1.20',
    '0132' => 'X-T2 Ver1.32',
    '0144' => 'X100T Ver1.44',
    '0159' => 'S2Pro Ver1.00',
    '0200' => 'X10 Ver2.00',
    '0201' => 'X-H1 Ver2.01',
    '0212' => 'S3Pro Ver2.12',
    '0216' => 'S3Pro Ver2.16', # (NC)
    '0218' => 'S3Pro Ver2.18',
    '0240' => 'X-E1 Ver2.40',
    '0264' => 'F700 Ver2.00',
    '0266' => 'S9500 Ver1.01',
    '0261' => 'X-E1 Ver2.61',
    '0269' => 'S9500 Ver1.02',
    '0271' => 'S3Pro Ver2.71', # UV/IR model?
    '0300' => 'X-E2',
   # 0400  - expect to see this for X-T1
    '0540' => 'X-T1 Ver5.40',
    '0712' => 'S5000 Ver3.00',
    '0716' => 'S5000 Ver3.00', # (yes, 2 RAF versions with the same Software version)
    '0Dgi' => 'X-A10 Ver1.01 and X-A3 Ver1.02', # (yes, non-digits in the firmware number)
);

my %faceCategories = (
    Format => 'int8u',
    PrintConv => { BITMASK => {
        1 => 'Partner',
        2 => 'Family',
        3 => 'Friend',
    }},
);

# FujiFilm MakerNotes tags
%Image::ExifTool::FujiFilm::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0 => {
        Name => 'Version',
        Writable => 'undef',
    },
    0x0010 => { #PH/IB
        Name => 'InternalSerialNumber',
        Writable => 'string',
        Notes => q{
            this number is unique for most models, and contains the camera model ID and
            the date of manufacture
        },
        # eg)  "FPX20017035 592D31313034060427796060110384"
        # "FPX 20495643     592D313335310701318AD010110047" (F40fd)
        #                   HHHHHHHHHHHHyymmdd
        #   HHHHHHHHHHHH = camera body number in hex
        #   yymmdd       = date of manufacture
        PrintConv => q{
            if ($val =~ /^(.*?\s*)([0-9a-fA-F]*)(\d{2})(\d{2})(\d{2})(.{12})\s*\0*$/s
                and $4 >= 1 and $4 <= 12 and $5 >= 1 and $5 <= 31)
            {
                my $yr = $3 + ($3 < 70 ? 2000 : 1900);
                my $sn = pack 'H*', $2;
                return "$1$sn $yr:$4:$5 $6";
            } else {
                # handle a couple of models which use a slightly different format
                $val =~ s/\b(592D(3[0-9])+)/pack("H*",$1).' '/e;
            }
            return $val;
        },
        # (this inverse conversion doesn't work in all cases, so it is best to write
        #  the ValueConv value if an authentic internal serial number is required)
        PrintConvInv => '$_=$val; s/(\S+) (19|20)(\d{2}):(\d{2}):(\d{2}) /unpack("H*",$1)."$3$4$5"/e; $_',
    },
    0x1000 => {
        Name => 'Quality',
        Writable => 'string',
    },
    0x1001 => {
        Name => 'Sharpness',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x00 => '-4 (softest)', #10
            0x01 => '-3 (very soft)',
            0x02 => '-2 (soft)',
            0x03 => '0 (normal)',
            0x04 => '+2 (hard)',
            0x05 => '+3 (very hard)',
            0x06 => '+4 (hardest)',
            0x82 => '-1 (medium soft)', #2
            0x84 => '+1 (medium hard)', #2
            0x8000 => 'Film Simulation', #2
            0xffff => 'n/a', #2
        },
    },
    0x1002 => {
        Name => 'WhiteBalance',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => 'Auto',
            0x1   => 'Auto (white priority)', #forum10890
            0x2   => 'Auto (ambiance priority)', #forum10890
            0x100 => 'Daylight',
            0x200 => 'Cloudy',
            0x300 => 'Daylight Fluorescent',
            0x301 => 'Day White Fluorescent',
            0x302 => 'White Fluorescent',
            0x303 => 'Warm White Fluorescent', #2/PH (S5)
            0x304 => 'Living Room Warm White Fluorescent', #2/PH (S5)
            0x400 => 'Incandescent',
            0x500 => 'Flash', #4
            0x600 => 'Underwater', #forum6109
            0xf00 => 'Custom',
            0xf01 => 'Custom2', #2
            0xf02 => 'Custom3', #2
            0xf03 => 'Custom4', #2
            0xf04 => 'Custom5', #2
            # 0xfe0 => 'Gray Point?', #2
            0xff0 => 'Kelvin', #4
        },
    },
    0x1003 => {
        Name => 'Saturation',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => '0 (normal)', # # ("Color 0", ref 8)
            0x080 => '+1 (medium high)', #2 ("Color +1", ref 8)
            0x100 => '+2 (high)', # ("Color +2", ref 8)
            0x0c0 => '+3 (very high)',
            0x0e0 => '+4 (highest)',
            0x180 => '-1 (medium low)', #2 ("Color -1", ref 8)
            0x200 => 'Low',
            0x300 => 'None (B&W)', #2
            0x301 => 'B&W Red Filter', #PH/8
            0x302 => 'B&W Yellow Filter', #PH (X100)
            0x303 => 'B&W Green Filter', #PH/8
            0x310 => 'B&W Sepia', #PH (X100)
            0x400 => '-2 (low)', #8 ("Color -2")
            0x4c0 => '-3 (very low)',
            0x4e0 => '-4 (lowest)',
            0x500 => 'Acros', #PH (X-Pro2)
            0x501 => 'Acros Red Filter', #PH (X-Pro2)
            0x502 => 'Acros Yellow Filter', #PH (X-Pro2)
            0x503 => 'Acros Green Filter', #PH (X-Pro2)
            0x8000 => 'Film Simulation', #2
        },
    },
    0x1004 => {
        Name => 'Contrast',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => 'Normal',
            0x080 => 'Medium High', #2
            0x100 => 'High',
            0x180 => 'Medium Low', #2
            0x200 => 'Low',
            0x8000 => 'Film Simulation', #2
        },
    },
    0x1005 => { #4
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0x1006 => { #JD
        Name => 'Contrast',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0   => 'Normal',
            0x100 => 'High',
            0x300 => 'Low',
        },
    },
    0x100a => { #2
        Name => 'WhiteBalanceFineTune',
        Notes => 'newer cameras should divide these values by 20', #forum10800
        Writable => 'int32s',
        Count => 2,
        PrintConv => 'sprintf("Red %+d, Blue %+d", split(" ", $val))',
        PrintConvInv => 'my @v=($val=~/-?\d+/g);"@v"',
    },
    0x100b => { #2
        Name => 'NoiseReduction',
        Flags => 'PrintHex',
        Writable => 'int16u',
        RawConv => '$val == 0x100 ? undef : $val',
        PrintConv => {
            0x40 => 'Low',
            0x80 => 'Normal',
            0x100 => 'n/a', #PH (NC) (all X100 samples)
        },
    },
    0x100e => { #PH (X100)
        Name => 'NoiseReduction',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x000 => '0 (normal)', # ("NR 0, ref 8)
            0x100 => '+2 (strong)', # ("NR+2, ref 8)
            0x180 => '+1 (medium strong)', #8 ("NR+1")
            0x1c0 => '+3 (very strong)',
            0x1e0 => '+4 (strongest)',
            0x200 => '-2 (weak)', # ("NR-2, ref 8)
            0x280 => '-1 (medium weak)', #8 ("NR-1")
            0x2c0 => '-3 (very weak)', #10 (-3)
            0x2e0 => '-4 (weakest)', #10 (-4)
        },
    },
    0x100f => { #PR158
        Name => 'Clarity',
        Writable => 'int32s', #PH
        PrintConv => {
            -5000 => '-5',
            -4000 => '-4',
            -3000 => '-3',
            -2000 => '-2',
            -1000 => '-1',
            0 => '0',
            1000 => '1',
            2000 => '2',
            3000 => '3',
            4000 => '4',
            5000 => '5',
        },
    },
    0x1010 => {
        Name => 'FujiFlashMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
            3 => 'Red-eye reduction',
            4 => 'External', #JD
            16 => 'Commander',
            0x8000 => 'Not Attached', #10 (X-T2) (or external flash off)
            0x8120 => 'TTL', #10 (X-T2)
            0x8320 => 'TTL Auto - Did not fire',
            0x9840 => 'Manual', #10 (X-T2)
            0x9860 => 'Flash Commander', #13
            0x9880 => 'Multi-flash', #10 (X-T2)
            0xa920 => '1st Curtain (front)', #10 (EF-X500 flash)
            0xaa20 => 'TTL Slow - 1st Curtain (front)', #13
            0xab20 => 'TTL Auto - 1st Curtain (front)', #13
            0xad20 => 'TTL - Red-eye Flash - 1st Curtain (front)', #13
            0xae20 => 'TTL Slow - Red-eye Flash - 1st Curtain (front)', #13
            0xaf20 => 'TTL Auto - Red-eye Flash - 1st Curtain (front)', #13
            0xc920 => '2nd Curtain (rear)', #10
            0xca20 => 'TTL Slow - 2nd Curtain (rear)', #13
            0xcb20 => 'TTL Auto - 2nd Curtain (rear)', #13
            0xcd20 => 'TTL - Red-eye Flash - 2nd Curtain (rear)', #13
            0xce20 => 'TTL Slow - Red-eye Flash - 2nd Curtain (rear)', #13
            0xcf20 => 'TTL Auto - Red-eye Flash - 2nd Curtain (rear)', #13
            0xe920 => 'High Speed Sync (HSS)', #10
        },
    },
    0x1011 => {
        Name => 'FlashExposureComp', #JD
        Writable => 'rational64s',
    },
    0x1020 => {
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x1021 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
            65535 => 'Movie', #forum10766
        },
    },
    0x1022 => { #8/forum6579
        Name => 'AFMode',
        Writable => 'int16u',
        Notes => '"No" for manual and some AF-multi focus modes',
        PrintConv => {
            0 => 'No',
            1 => 'Single Point',
            256 => 'Zone',
            512 => 'Wide/Tracking',
        },
    },
    0x102b => {
        Name => 'PrioritySettings',
        SubDirectory => { TagTable => 'Image::ExifTool::FujiFilm::PrioritySettings' },
    },
    0x102d => {
        Name => 'FocusSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::FujiFilm::FocusSettings' },
    },
    0x102e => {
        Name => 'AFCSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::FujiFilm::AFCSettings' },
    },
    0x1023 => { #2
        Name => 'FocusPixel',
        Writable => 'int16u',
        Count => 2,
    },
    0x1030 => {
        Name => 'SlowSync',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x1031 => {
        Name => 'PictureMode',
        Flags => 'PrintHex',
        Writable => 'int16u',
        PrintConv => {
            0x0 => 'Auto', # (or 'SR+' if SceneRecognition present, ref 11)
            0x1 => 'Portrait',
            0x2 => 'Landscape',
            0x3 => 'Macro', #JD
            0x4 => 'Sports',
            0x5 => 'Night Scene',
            0x6 => 'Program AE',
            0x7 => 'Natural Light', #3
            0x8 => 'Anti-blur', #3
            0x9 => 'Beach & Snow', #JD
            0xa => 'Sunset', #3
            0xb => 'Museum', #3
            0xc => 'Party', #3
            0xd => 'Flower', #3
            0xe => 'Text', #3
            0xf => 'Natural Light & Flash', #3
            0x10 => 'Beach', #3
            0x11 => 'Snow', #3
            0x12 => 'Fireworks', #3
            0x13 => 'Underwater', #3
            0x14 => 'Portrait with Skin Correction', #7
            0x16 => 'Panorama', #PH (X100)
            0x17 => 'Night (tripod)', #7
            0x18 => 'Pro Low-light', #7
            0x19 => 'Pro Focus', #7
            0x1a => 'Portrait 2', #PH (NC, T500, maybe "Smile & Shoot"?)
            0x1b => 'Dog Face Detection', #7
            0x1c => 'Cat Face Detection', #7
            0x30 => 'HDR', #forum10799
            0x40 => 'Advanced Filter',
            0x100 => 'Aperture-priority AE',
            0x200 => 'Shutter speed priority AE',
            0x300 => 'Manual',
        },
    },
    0x1032 => { #8
        Name => 'ExposureCount',
        Writable => 'int16u',
        Notes => 'number of exposures used for this image',
    },
    0x1033 => { #6
        Name => 'EXRAuto',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0x1034 => { #6
        Name => 'EXRMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x100 => 'HR (High Resolution)',
            0x200 => 'SN (Signal to Noise priority)',
            0x300 => 'DR (Dynamic Range priority)',
        },
    },
    0x1037 => { #forum17591
        Name => 'MultipleExposure',
        Writable => 'int16u', # (NC)
        PrintConv => {
            1 => 'Additive',
            2 => 'Average',
            3 => 'Light',
            4 => 'Dark',
        },
    },
    0x1040 => { #8
        Name => 'ShadowTone',
        Writable => 'int32s',
        PrintConv => {
            OTHER => sub {
                my ($val, $inv) = @_;
                if ($inv) {
                    return int(-$val * 16);
                } else {
                    return -$val / 16;
                }
            },
            -64 => '+4 (hardest)',
            -48 => '+3 (very hard)',
            -32 => '+2 (hard)',
            -16 => '+1 (medium hard)',
            0 => '0 (normal)',
            16 => '-1 (medium soft)',
            32 => '-2 (soft)',
        },
    },
    0x1041 => { #8
        Name => 'HighlightTone',
        Writable => 'int32s',
        PrintConv => {
            OTHER => sub {
                my ($val, $inv) = @_;
                if ($inv) {
                    return int(-$val * 16);
                } else {
                    return -$val / 16;
                }
            },
            -64 => '+4 (hardest)',
            -48 => '+3 (very hard)',
            -32 => '+2 (hard)',
            -16 => '+1 (medium hard)',
            0 => '0 (normal)',
            16 => '-1 (medium soft)',
            32 => '-2 (soft)',
        },
    },
    0x1044 => { #forum7668
        Name => 'DigitalZoom',
        Writable => 'int32u',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
    },
    0x1045 => { #12
        Name => 'LensModulationOptimizer',
        Writable => 'int32u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x1047 => { #12
        Name => 'GrainEffectRoughness',
        Writable => 'int32s',
        PrintConv => {
            0 => 'Off',
            32 => 'Weak',
            64 => 'Strong',
        },
    },
    0x1048 => { #12
        Name => 'ColorChromeEffect',
        Writable => 'int32s',
        PrintConv => {
            0 => 'Off',
            32 => 'Weak',
            64 => 'Strong',
        },
    },
    0x1049 => { #12,forum14319
        Name => 'BWAdjustment',
        Notes => 'positive values are warm, negative values are cool',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val + 0',
    },
    0x104b => { #forum10800,forum14319
        Name => 'BWMagentaGreen',
        Notes => 'positive values are green, negative values are magenta',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val + 0',
    },
    0x104c => { #PR158
        Name => "GrainEffectSize",
        Writable => 'int16u', #PH
        PrintConv => {
            0 => 'Off',
            16 => 'Small',
            32 => 'Large',
        },
    },
    0x104d => { #forum9634
        Name => 'CropMode',
        Writable => 'int16u',
        PrintConv => { # (perhaps this is a bit mask?)
            0 => 'n/a',
            1 => 'Full-frame on GFX', #IB
            2 => 'Sports Finder Mode', # (mechanical shutter)
            4 => 'Electronic Shutter 1.25x Crop', # (continuous high)
            8 => 'Digital Tele-Conv', #forum15784
        },
    },
    0x104e => { #forum10800 (X-Pro3)
        Name => 'ColorChromeFXBlue',
        Writable => 'int32s',
        PrintConv => {
            0 => 'Off',
            32 => 'Weak', # (NC)
            64 => 'Strong',
        },
    },
    0x1050 => { #forum6109
        Name => 'ShutterType',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Mechanical',
            1 => 'Electronic',
            2 => 'Electronic (long shutter speed)', #12
            3 => 'Electronic Front Curtain', #10
        },
    },
    0x1051 => { #forum15784
        Name => 'CropFlag',
        Writable => 'int8u',
        Notes => q(
            this tag exists only if the image was cropped, and is 0 for cropped JPG
            image or 1 for a cropped RAF
        ),
    },
    0x1052 => { Name => 'CropTopLeft', Writable => 'int32u' }, #forum15784
    0x1053 => { Name => 'CropSize',    Writable => 'int32u' }, #forum15784
    # 0x1100 - This may not work well for newer cameras (ref forum12682)
    0x1100 => [{
        Name => 'AutoBracketing',
        Condition => '$$self{Model} eq "X-T3"',
        Notes => 'X-T3 only',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Pre-shot', #12 (Electronic Shutter and Continuous High drive mode only)
        },
    },{
        Name => 'AutoBracketing',
        Notes => 'other models',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'No flash & flash', #3
            6 => 'Pixel Shift', #IB (GFX100S)
        },
    }],
    0x1101 => {
        Name => 'SequenceNumber',
        Writable => 'int16u',
    },
    0x1102 => { #forum17602
        Name => 'WhiteBalanceBracketing',
        Writable => 'int16u', # (NC)
        PrintHex => 1,
        PrintConv => {
            0x01ff => '+/- 1',
            0x02ff => '+/- 2',
            0x03ff => '+/- 3',
        },
    },
    0x1103 => {
        Name => 'DriveSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::FujiFilm::DriveSettings' },
    },
    0x1105 => { Name => 'PixelShiftShots',  Writable => 'int16u' }, #IB
    0x1106 => { Name => 'PixelShiftOffset', Writable => 'rational64s', Count => 2 }, #IB
    0x1150 => {
        Name => 'CompositeImageMode',
        Writable => 'int32u',
        PrintConv => {
            0 => 'n/a', #PH
            1 => 'Pro Low-light', #7
            2 => 'Pro Focus', #7
            32 => 'Panorama', #PH
            128 => 'HDR', #forum10799
            1024 => 'Multi-exposure', #forum17591
        },
    },
    0x1151 => {
        Name => 'CompositeImageCount1',
        Writable => 'int16u',
        # Pro Low-light - val=4 (number of pictures taken?); Pro Focus - val=2,3 (ref 7); HDR - val=3 (forum10799)
    },
    0x1152 => {
        Name => 'CompositeImageCount2',
        Writable => 'int16u',
        # Pro Low-light - val=1,3,4 (stacked pictures used?); Pro Focus - val=1,2 (ref 7); HDR - val=3 (forum10799)
    },
    0x1153 => { #forum7668
        Name => 'PanoramaAngle',
        Writable => 'int16u',
    },
    0x1154 => { #forum7668
        Name => 'PanoramaDirection',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Right',
            2 => 'Left', #forum17591
            3 => 'Up', #forum17591
            4 => 'Down',
        },
    },
    0x1201 => { #forum6109
        Name => 'AdvancedFilter',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x10000 => 'Pop Color',
            0x20000 => 'Hi Key',
            0x30000 => 'Toy Camera',
            0x40000 => 'Miniature',
            0x50000 => 'Dynamic Tone',
            0x60001 => 'Partial Color Red',
            0x60002 => 'Partial Color Yellow',
            0x60003 => 'Partial Color Green',
            0x60004 => 'Partial Color Blue',
            0x60005 => 'Partial Color Orange',
            0x60006 => 'Partial Color Purple',
            0x70000 => 'Soft Focus',
            0x90000 => 'Low Key',
            0x100000 => 'Light Leak', #forum17392
            0x130000 => 'Expired Film Green', #forum17392
            0x130001 => 'Expired Film Red', #forum17392 (NC)
            0x130002 => 'Expired Film Neutral', #forum17392
        },
    },
    0x1210 => { #2
        Name => 'ColorMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Standard',
            0x10 => 'Chrome',
            0x30 => 'B & W',
        },
    },
    0x1300 => {
        Name => 'BlurWarning',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'Blur Warning',
        },
    },
    0x1301 => {
        Name => 'FocusWarning',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Good',
            1 => 'Out of focus',
        },
    },
    0x1302 => {
        Name => 'ExposureWarning',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Good',
            1 => 'Bad exposure',
        },
    },
    0x1304 => { #PH
        Name => 'GEImageSize',
        Condition => '$$self{Make} =~ /^GENERAL IMAGING/',
        Writable => 'string',
        Notes => 'GE models only',
    },
    0x1400 => { #2
        Name => 'DynamicRange',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Standard',
            3 => 'Wide',
            # the S5Pro has 100%(STD),130%,170%,230%(W1),300%,400%(W2) - PH
        },
    },
    0x1401 => { #2 (this doesn't seem to work for the X100 - PH)
        Name => 'FilmMode',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'F0/Standard (Provia)', # X-Pro2 "Provia/Standard"
            0x100 => 'F1/Studio Portrait',
            0x110 => 'F1a/Studio Portrait Enhanced Saturation',
            0x120 => 'F1b/Studio Portrait Smooth Skin Tone (Astia)', # X-Pro2 "Astia/Soft"
            0x130 => 'F1c/Studio Portrait Increased Sharpness',
            0x200 => 'F2/Fujichrome (Velvia)', # X-Pro2 "Velvia/Vivid"
            0x300 => 'F3/Studio Portrait Ex',
            0x400 => 'F4/Velvia',
            0x500 => 'Pro Neg. Std', #PH (X-Pro1)
            0x501 => 'Pro Neg. Hi', #PH (X-Pro1)
            0x600 => 'Classic Chrome', #forum6109
            0x700 => 'Eterna', #12
            0x800 => 'Classic Negative', #forum10536
            0x900 => 'Bleach Bypass', #forum10890
            0xa00 => 'Nostalgic Neg', #forum12085
            0xb00 => 'Reala ACE', #forum15190
        },
    },
    0x1402 => { #2
        Name => 'DynamicRangeSetting',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'Auto',
            0x001 => 'Manual', #(ref http://forum.photome.de/viewtopic.php?f=2&t=353)
            0x100 => 'Standard (100%)',
            0x200 => 'Wide1 (230%)',
            0x201 => 'Wide2 (400%)',
            0x8000 => 'Film Simulation',
        },
    },
    0x1403 => { #2 (only valid for manual DR, ref 6)
        Name => 'DevelopmentDynamicRange',
        Writable => 'int16u',
        # (shows 200, 400 or 800 for HDR200,HDR400,HDR800, ref forum10799)
    },
    0x1404 => { #2
        Name => 'MinFocalLength',
        Writable => 'rational64s',
    },
    0x1405 => { #2
        Name => 'MaxFocalLength',
        Writable => 'rational64s',
    },
    0x1406 => { #2
        Name => 'MaxApertureAtMinFocal',
        Writable => 'rational64s',
    },
    0x1407 => { #2
        Name => 'MaxApertureAtMaxFocal',
        Writable => 'rational64s',
    },
    # 0x1408 - values: '0100', 'S100', 'VQ10'
    # 0x1409 - values: same as 0x1408
    # 0x140a - values: 0, 1, 3, 5, 7 (bit 2=red-eye detection, ref 11/13)
    0x140b => { #6
        Name => 'AutoDynamicRange',
        Writable => 'int16u',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%$//; $val',
    },
    0x1422 => { #8
        Name => 'ImageStabilization',
        Writable => 'int16u',
        Count => 3,
        PrintConv => [{
            0 => 'None',
            1 => 'Optical', #PH
            2 => 'Sensor-shift', #PH (now IBIS/OIS, ref forum13708)
            3 => 'OIS Lens', #forum9815 (optical+sensor?)
            258 => 'IBIS/OIS + DIS', #forum13708 (digital on top of IBIS/OIS)
            512 => 'Digital', #PH
        },{
            0 => 'Off',
            1 => 'On (mode 1, continuous)',
            2 => 'On (mode 2, shooting only)',
        }],
    },
    0x1425 => { # if present and 0x1031 PictureMode is zero, then PictureMode is SR+, not Auto (ref 11)
        Name => 'SceneRecognition',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0 => 'Unrecognized',
            0x100 => 'Portrait Image',
            0x103 => 'Night Portrait', #forum10651
            0x105 => 'Backlit Portrait', #forum10651
            0x200 => 'Landscape Image',
            0x300 => 'Night Scene',
            0x400 => 'Macro',
        },
    },
    0x1431 => { #forum6109
        Name => 'Rating',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
        Priority => 0,
    },
    0x1436 => { #8
        Name => 'ImageGeneration',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Original Image',
            1 => 'Re-developed from RAW',
        },
    },
    0x1438 => { #forum6579 (X-T1 firmware version 3)
        Name => 'ImageCount',
        Notes => 'may reset to 0 when new firmware is installed',
        Writable => 'int16u',
        ValueConv => '$val & 0x7fff',
        ValueConvInv => '$val | 0x8000',
    },
    0x1443 => { #12 (X-T3)
        Name => 'DRangePriority',
        Writable => 'int16u',
        PrintConv => { 0 => 'Auto', 1 => 'Fixed' },
    },
    0x1444 => { #12 (X-T3, only exists if DRangePriority is 'Auto')
        Name => 'DRangePriorityAuto',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Weak',
            2 => 'Strong',
            3 => 'Plus',    #forum10799
        },
    },
    0x1445 => { #12 (X-T3, only exists if DRangePriority is 'Fixed')
        Name => 'DRangePriorityFixed',
        Writable => 'int16u',
        PrintConv => { 1 => 'Weak', 2 => 'Strong' },
    },
    0x1446 => { #12
        Name => 'FlickerReduction',
        Writable => 'int32u',
        # seen values: Off=0x0000, On=0x2100,0x3100
        PrintConv => q{
            my $on = ((($val >> 8) & 0x0f) == 1) ? 'On' : 'Off';
            return sprintf('%s (0x%.4x)', $on, $val);
        },
        PrintConvInv => '$val=~/(0x[0-9a-f]+)/i; hex $1',
    },
    0x1447 => { Name => 'FujiModel',  Writable => 'string' },
    0x1448 => { Name => 'FujiModel2', Writable => 'string' },

    # Found in X-M5, X-E5
    # White balance as shot. Same valus as 0xf00e.
    0x144a => { Name => 'WBRed',      Writable => 'int16u' },
    0x144b => { Name => 'WBGreen',    Writable => 'int16u' },
    0x144c => { Name => 'WBBlue',     Writable => 'int16u' },
    
    0x144d => { Name => 'RollAngle',  Writable => 'rational64s' }, #forum14319
    0x3803 => { #forum10037
        Name => 'VideoRecordingMode',
        Groups => { 2 => 'Video' },
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Normal',
            0x10 => 'F-log',
            0x20 => 'HLG',
            0x30 => 'F-log2', #forum14384
        },
    },
    0x3804 => { #forum10037
        Name => 'PeripheralLighting',
        Groups => { 2 => 'Video' },
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    # 0x3805 - int16u: seen 1
    0x3806 => { #forum10037
        Name => 'VideoCompression',
        Groups => { 2 => 'Video' },
        Writable => 'int16u',
        PrintConv => {
            1 => 'Log GOP',
            2 => 'All Intra',
        },
    },
    # 0x3810 - int32u: related to video codec (ref forum10037)
    0x3820 => { #PH (HS20EXR MOV)
        Name => 'FrameRate',
        Writable => 'int16u',
        Groups => { 2 => 'Video' },
    },
    0x3821 => { #PH (HS20EXR MOV)
        Name => 'FrameWidth',
        Writable => 'int16u',
        Groups => { 2 => 'Video' },
    },
    0x3822 => { #PH (HS20EXR MOV)
        Name => 'FrameHeight',
        Writable => 'int16u',
        Groups => { 2 => 'Video' },
    },
    0x3824 => { #forum10480 (X series)
        Name => 'FullHDHighSpeedRec',
        Writable => 'int32u',
        Groups => { 2 => 'Video' },
        PrintConv => { 1 => 'Off', 2 => 'On' },
    },
    0x4005 => { #forum9634
        Name => 'FaceElementSelected', # (could be face or eye)
        Writable => 'int16u',
        Count => 4,
    },
    0x4100 => { #PH
        Name => 'FacesDetected',
        Writable => 'int16u',
    },
    0x4103 => { #PH
        Name => 'FacePositions',
        Writable => 'int16u',
        Count => -1,
        Notes => q{
            left, top, right and bottom coordinates in full-sized image for each face
            detected
        },
    },
    0x4200 => { #11
        Name => 'NumFaceElements',
        Writable => 'int16u',
    },
    0x4201 => { #11
        Name => 'FaceElementTypes',
        Writable => 'int8u',
        Count => -1,
        PrintConv => [{
            1 => 'Face',
            2 => 'Left Eye',
            3 => 'Right Eye',
            7 => 'Body',
            8 => 'Head',
            9 => 'Both Eyes', #forum17635
            11 => 'Bike',
            12 => 'Body of Car',
            13 => 'Front of Car',
            14 => 'Animal Body',
            15 => 'Animal Head',
            16 => 'Animal Face',
            17 => 'Animal Left Eye',
            18 => 'Animal Right Eye',
            19 => 'Bird Body',
            20 => 'Bird Head',
            21 => 'Bird Left Eye',
            22 => 'Bird Right Eye',
            23 => 'Aircraft Body',
            25 => 'Aircraft Cockpit',
            26 => 'Train Front',
            27 => 'Train Cockpit',
            28 => 'Animal Head (28)', #forum15192
            29 => 'Animal Body (29)', #forum15192
        },'REPEAT'],
    },
    # 0x4202 int8u[-1] - number of cooredinates in each rectangle? (ref 11)
    0x4203 => { #11
        Name => 'FaceElementPositions',
        Writable => 'int16u',
        Count => -1,
        Notes => q{
            left, top, right and bottom coordinates in full-sized image for each face
            element
        },
    },
    # 0x4101-0x4105 - exist only if face detection active
    # 0x4104 - also related to face detection (same number of entries as FacePositions)
    # 0x4200 - same as 0x4100?
    # 0x4203 - same as 0x4103
    # 0x4204 - same as 0x4104
    0x4282 => { #PH
        Name => 'FaceRecInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::FujiFilm::FaceRecInfo' },
    },
    0x8000 => { #2
        Name => 'FileSource',
        Writable => 'string',
    },
    0x8002 => { #2
        Name => 'OrderNumber',
        Writable => 'int32u',
    },
    0x8003 => { #2
        Name => 'FrameNumber',
        Writable => 'int16u',
    },
    0xb211 => { #PH
        Name => 'Parallax',
        # (value set in camera is -0.5 times this value in MPImage2... why?)
        Writable => 'rational64s',
        Notes => 'only found in MPImage2 of .MPO images',
    },
    # 0xb212 - also found in MPIMage2 images - PH
);

# Focus Priority settings, tag 0x102b (X-T3, ref forum 9607)
%Image::ExifTool::FujiFilm::PrioritySettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    WRITABLE => 1,
    0.1 => {
        Name => 'AF-SPriority',
        Mask => 0x000f,
        PrintConv => {
            1 => 'Release',
            2 => 'Focus',
        },
    },
    0.2 => {
        Name => 'AF-CPriority',
        Mask => 0x00f0,
        PrintConv => {
            1 => 'Release',
            2 => 'Focus',
        },
    },
);

# Focus settings, tag 0x102d (X-T3, ref forum 9607)
%Image::ExifTool::FujiFilm::FocusSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    WRITABLE => 1,
    0.1 => {
        Name => 'FocusMode2',
        Mask => 0x0000000f,
        PrintConv => {
            0x0 => 'AF-M',
            0x1 => 'AF-S',
            0x2 => 'AF-C',
        },
    },
    0.2 => {
        Name => 'PreAF',
        Mask => 0x00f0,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0.3 => {
        Name => 'AFAreaMode',
        Mask => 0x0f00,
        PrintConv => {
            0 => 'Single Point',
            1 => 'Zone',
            2 => 'Wide/Tracking',
        },
    },
    0.4 => {
        Name => 'AFAreaPointSize',
        Mask => 0xf000,
        PrintConv => {
            0 => 'n/a',
            OTHER => sub { return $_[0] },
        },
    },
    0.5 => {
        Name => 'AFAreaZoneSize',
        Mask => 0xff0000,
        PrintConv => {
            0 => 'n/a',
            OTHER => sub {
                my ($val, $inv) = @_;
                my ($w, $h);
                if ($inv) {
                    my ($w, $h) = $val =~ /(\d+)/g;
                    return 0 unless $w and $h;
                    return((($h << 5) & 0xf0) | ($w & 0x0f));
                }
                ($w, $h) = ($val & 0x0f, $val >> 5);
                return "$w x $h";
            },
        },
    },
);

# AF-C settings, tag 0x102e (ref forum 9607)
%Image::ExifTool::FujiFilm::AFCSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    WRITABLE => 1,
    0 => {
        Name => 'AF-CSetting',
        PrintHex => 3,
        PrintSort => 1, # sort PrintConv by value
        # decode in-camera preset values (X-T3)
        PrintConv => {
            0x102 => 'Set 1 (multi-purpose)',              # (2,0,Auto)
            0x203 => 'Set 2 (ignore obstacles)',           # (3,0,Center)
            0x122 => 'Set 3 (accelerating subject)',       # (2,2,Auto)
            0x010 => 'Set 4 (suddenly appearing subject)', # (0,1,Front)
            0x123 => 'Set 5 (erratic motion)',             # (3,2,Auto)
            OTHER => sub {
                my ($val, $inv) = @_;
                return $val =~ /(0x\w+)/ ? hex $1 : undef if $inv;
                return sprintf 'Set 6 (custom 0x%.3x)', $val;
            },
        },
    },
    0.1 => {
        Name => 'AF-CTrackingSensitivity',
        Mask => 0x000f, # (values 0-4)
    },
    0.2 => {
        Name => 'AF-CSpeedTrackingSensitivity',
        Mask => 0x00f0,
        # (values 0-2)
    },
    0.3 => {
        Name => 'AF-CZoneAreaSwitching',
        Mask => 0x0f00,
        PrintConv => {
            0 => 'Front',
            1 => 'Auto',
            2 => 'Center',
        },
    },
);

# DriveMode settings, tag 0x1103 (X-T3, ref forum 9607)
%Image::ExifTool::FujiFilm::DriveSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    WRITABLE => 1,
    0.1 => {
        Name => 'DriveMode',
        Mask => 0x000000ff,
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous Low', # not used by X-H2S? (see forum13777)
            2 => 'Continuous High',
        },
    },
    0.2 => {
        Name => 'DriveSpeed',
        Mask => 0xff000000,
        PrintConv => {
            0 => 'n/a',
            OTHER => sub {
                my ($val, $inv) = @_;
                return "$val fps" unless $inv;
                $val =~ s/ ?fps$//;
                return $val;
            },
        },
    },
);

# Face recognition information from FinePix F550EXR (ref PH)
%Image::ExifTool::FujiFilm::FaceRecInfo = (
    PROCESS_PROC => \&ProcessFaceRec,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    VARS => { ID_FMT => 'none' },
    NOTES => 'Face recognition information.',
    Face1Name => { },
    Face2Name => { },
    Face3Name => { },
    Face4Name => { },
    Face5Name => { },
    Face6Name => { },
    Face7Name => { },
    Face8Name => { },
    Face1Category => { %faceCategories },
    Face2Category => { %faceCategories },
    Face3Category => { %faceCategories },
    Face4Category => { %faceCategories },
    Face5Category => { %faceCategories },
    Face6Category => { %faceCategories },
    Face7Category => { %faceCategories },
    Face8Category => { %faceCategories },
    Face1Birthday => { },
    Face2Birthday => { },
    Face3Birthday => { },
    Face4Birthday => { },
    Face5Birthday => { },
    Face6Birthday => { },
    Face7Birthday => { },
    Face8Birthday => { },
);

# tags extracted from RAF header
%Image::ExifTool::FujiFilm::RAFHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'RAF', 1 => 'RAF', 2 => 'Image' },
    NOTES => 'Tags extracted from the header of RAF images.',
  # 0x00 - eg. "FUJIFILMCCD-RAW 0201FA392001FinePix S3Pro"
    0x3c => { #PH
        Name => 'RAFVersion',
        Format => 'undef[4]',
    },
    # (all int32u values)
  # 0x40 - 1 for M-RAW, 0 otherwise?
  # 0x44 - high word of M-RAW offset? (only seen zero)
  # 0x48 - M-RAW header offset
  # 0x4c - M-RAW header length
  # 0x50 - ? (only seen zero)
  # 0x54 - JPEG offset
  # 0x58 - JPEG length
  # 0x5c - RAF directory offset
  # 0x60 - RAF directory length
  # 0x64 - FujiIFD dir offset
  # 0x68 - FujiIFD dir length
  # 0x6c - RAFCompression or JPEG start
    0x6c => { #10
        Name => 'RAFCompression',
        Condition => '$$valPt =~ /^\0\0\0/', # (JPEG header is in this location for some RAF versions)
        Format => 'int32u',
        PrintConv => { 0 => 'Uncompressed', 2 => 'Lossless', 3 => 'Lossy'  },
    },
  # 0x70 - ? same as 0x68?
  # 0x74 - ? usually 0, but have seen 0x1700
  # 0x78 - RAF1 dir offset
  # 0x7c - RAF1 dir length
  # 0x80 - FujiIFD1 dir offset
  # 0x84 - FujiIFD1 dir length
  # 0x88-0x8c - always zero?
  # 0x90 - ? same as 0x74?
  # 0x94 - JPEG or M-RAW start
);

# tags in RAF images (ref 5)
%Image::ExifTool::FujiFilm::RAF = (
    PROCESS_PROC => \&ProcessFujiDir,
    GROUPS => { 0 => 'RAF', 1 => 'RAF', 2 => 'Image' },
    PRIORITY => 0, # so the first RAF directory takes precedence
    NOTES => q{
        FujiFilm RAF images contain meta information stored in a proprietary
        FujiFilm RAF format, as well as EXIF information stored inside an embedded
        JPEG preview image.  The table below lists tags currently decoded from the
        RAF-format information.
    },
    0x100 => {
        Name => 'RawImageFullSize',
        Format => 'int16u',
        Groups => { 1 => 'RAF2' }, # (so RAF2 shows up in family 1 list)
        Count => 2,
        Notes => 'including borders',
        ValueConv => 'my @v=reverse split(" ",$val);"@v"', # reverse to show width first
        PrintConv => '$val=~tr/ /x/; $val',
    },
    0x110 => {
        Name => 'RawImageCropTopLeft',
        Format => 'int16u',
        Count => 2,
        Notes => 'top margin first, then left margin',
    },
    0x111 => {
        Name => 'RawImageCroppedSize',
        Format => 'int16u',
        Count => 2,
        Notes => 'including borders',
        ValueConv => 'my @v=reverse split(" ",$val);"@v"', # reverse to show width first
        PrintConv => '$val=~tr/ /x/; $val',
    },
    # 0x112 - int16u[2] same as 0x111 but with width/height swapped?
    # 0x113 - int16u[2] same as 0x111?
    0x115 => {
        Name => 'RawImageAspectRatio',
        Format => 'int16u',
        Count => 2,
        ValueConv => 'my @v=reverse split(" ",$val);"@v"', # reverse to show width first
        PrintConv => '$val=~tr/ /:/; $val',
    },
    0x117 => {
        Name => 'RawZoomActive',
        Format => 'int32u',
        Count => 1,
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x118 => {
        Name => 'RawZoomTopLeft',
        Format => 'int16u',
        Count => 2,
        Notes => 'relative to RawCroppedImageSize',
        ValueConv => 'my @v=reverse split(" ",$val);"@v"', # reverse to show width first
        PrintConv => '$val=~tr/ /x/; $val',
    },
    0x119 => {
        Name => 'RawZoomSize',
        Format => 'int16u',
        Count => 2,
        Notes => 'relative to RawCroppedImageSize',
        ValueConv => 'my @v=reverse split(" ",$val);"@v"', # reverse to show width first
        PrintConv => '$val=~tr/ /x/; $val',
    },
    0x121 => [
        {
            Name => 'RawImageSize',
            Condition => '$$self{Model} eq "FinePixS2Pro"',
            Format => 'int16u',
            Count => 2,
            ValueConv => q{
                my @v=split(" ",$val);
                $v[0]*=2, $v[1]/=2;
                return "@v";
            },
            PrintConv => '$val=~tr/ /x/; $val',
        },
        {
            Name => 'RawImageSize',
            Format => 'int16u',
            Count => 2,
            # values are height then width, adjusted for the layout
            ValueConv => q{
                my @v=reverse split(" ",$val);
                $$self{FujiLayout} and $v[0]/=2, $v[1]*=2;
                return "@v";
            },
            PrintConv => '$val=~tr/ /x/; $val',
        },
    ],
    0x130 => {
        Name => 'FujiLayout',
        Format => 'int8u',
        RawConv => q{
            my ($v) = split ' ', $val;
            $$self{FujiLayout} = $v & 0x80 ? 1 : 0;
            return $val;
        },
    },
    0x131 => { #5
        Name => 'XTransLayout',
        Description => 'X-Trans Layout',
        Format => 'int8u',
        Count => 36,
        PrintConv => '$val =~ tr/012 /RGB/d; join " ", $val =~ /....../g',
    },
    # 0x141 - int16u[2] Bit depth? "14 42" for 14-bit RAF and "16 48" for 16-bit RAF
    0x2000 => { #IB
        Name => 'WB_GRGBLevelsAuto',
        Format => 'int16u',
        Count => 4, # (ignore the duplicate values)
    },
    0x2100 => { #IB
        Name => 'WB_GRGBLevelsDaylight',
        Format => 'int16u',
        Count => 4,
    },
    0x2200 => { #IB
        Name => 'WB_GRGBLevelsCloudy',
        Format => 'int16u',
        Count => 4,
    },
    0x2300 => { #IB
        Name => 'WB_GRGBLevelsDaylightFluor',
        Format => 'int16u',
        Count => 4,
    },
    0x2301 => { #IB
        Name => 'WB_GRGBLevelsDayWhiteFluor',
        Format => 'int16u',
        Count => 4,
    },
    0x2302 => { #IB
        Name => 'WB_GRGBLevelsWhiteFluorescent',
        Format => 'int16u',
        Count => 4,
    },
    0x2310 => { #IB
        Name => 'WB_GRGBLevelsWarmWhiteFluor',
        Format => 'int16u',
        Count => 4,
    },
    0x2311 => { #IB
        Name => 'WB_GRGBLevelsLivingRoomWarmWhiteFluor',
        Format => 'int16u',
        Count => 4,
    },
    0x2400 => { #IB
        Name => 'WB_GRGBLevelsTungsten',
        Format => 'int16u',
        Count => 4,
    },
    # 0x2f00 => WB_GRGBLevelsCustom: int32u count, then count * (int16u GRGBGRGB), ref IB
    0x2ff0 => {
        Name => 'WB_GRGBLevels',
        Format => 'int16u',
        Count => 4,
    },
    0x9200 => { #Frank Markesteijn
        Name => 'RelativeExposure',
        Format => 'rational32s',
        ValueConv => 'log($val) / log(2)',
        ValueConvInv => 'exp($val * log(2))',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    # 0x9200 - relative exposure? (ref Frank Markesteijn)
    0x9650 => { #Frank Markesteijn
        Name => 'RawExposureBias',
        Format => 'rational32s',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    0xc000 => {
        Name => 'RAFData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FujiFilm::RAFData',
            ByteOrder => 'Little-endian',
        }
    },
);

%Image::ExifTool::FujiFilm::RAFData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0, 4, 8 ],
    FIRST_ENTRY => 0,
    # (FujiFilm image dimensions are REALLY confusing)
    # --> this needs some cleaning up
    # [Note to self: See email from Iliah Borg for more information about WB settings in this data]
    0 => {
        Name => 'RawImageWidth',
        Format => 'int32u',
        DataMember => 'FujiWidth',
        RawConv => '$val < 10000 ? $$self{FujiWidth} = $val : undef', #5
        ValueConv => '$$self{FujiLayout} ? ($val / 2) : $val',
    },
    4 => [
        {
            Name => 'RawImageWidth',
            Condition => 'not $$self{FujiWidth}',
            Format => 'int32u',
            DataMember => 'FujiWidth',
            RawConv => '$val < 10000 ? $$self{FujiWidth} = $val : undef', #PH
            ValueConv => '$$self{FujiLayout} ? ($val / 2) : $val',
        },
        {
            Name => 'RawImageHeight',
            Format => 'int32u',
            DataMember => 'FujiHeight',
            RawConv => '$$self{FujiHeight} = $val',
            ValueConv => '$$self{FujiLayout} ? ($val * 2) : $val',
        },
    ],
    8 => [
        {
            Name => 'RawImageWidth',
            Condition => 'not $$self{FujiWidth}',
            Format => 'int32u',
            DataMember => 'FujiWidth',
            RawConv => '$val < 10000 ? $$self{FujiWidth} = $val : undef', #PH
            ValueConv => '$$self{FujiLayout} ? ($val / 2) : $val',
        },
        {
            Name => 'RawImageHeight',
            Condition => 'not $$self{FujiHeight}',
            Format => 'int32u',
            DataMember => 'FujiHeight',
            RawConv => '$$self{FujiHeight} = $val',
            ValueConv => '$$self{FujiLayout} ? ($val * 2) : $val',
        },
    ],
    12 => {
        Name => 'RawImageHeight',
        Condition => 'not $$self{FujiHeight}',
        Format => 'int32u',
        ValueConv => '$$self{FujiLayout} ? ($val * 2) : $val',
    },
);

# TIFF IFD-format information stored in FujiFilm RAF images (ref 5)
%Image::ExifTool::FujiFilm::IFD = (
    PROCESS_PROC => \&Image::ExifTool::Exif::ProcessExif,
    GROUPS => { 0 => 'RAF', 1 => 'FujiIFD', 2 => 'Image' },
    NOTES => 'Tags found in the FujiIFD information of RAF images from some models.',
    0xf000 => {
        Name => 'FujiIFD',
        Groups => { 1 => 'FujiIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FujiFilm::IFD',
            DirName => 'FujiSubIFD',
            Start => '$val',
        },
    },
    0xf001 => 'RawImageFullWidth',
    0xf002 => 'RawImageFullHeight',
    0xf003 => 'BitsPerSample',
    # 0xf004 - values: 4
    # 0xf005 - values: 1374, 1668
    # 0xf006 - some sort of flag indicating packed format?
    0xf007 => {
        Name => 'StripOffsets',
        IsOffset => 1,
        IsImageData => 1,
        OffsetPair => 0xf008,  # point to associated byte counts
    },
    0xf008 => {
        Name => 'StripByteCounts',
        OffsetPair => 0xf007,  # point to associated offsets
    },
    # 0xf009 - values: 0, 3
    0xf00a => 'BlackLevel', #IB
    0xf00b => 'GeometricDistortionParams', #9 (rational64s[23, 35 or 43])
    0xf00c => 'WB_GRBLevelsStandard', #IB (GRBXGRBX; X=17 is standard illuminant A, X=21 is D65)
    0xf00d => 'WB_GRBLevelsAuto', #IB
    0xf00e => 'WB_GRBLevels',
    0xf00f => 'ChromaticAberrationParams', # (rational64s[23])
    0xf010 => 'VignettingParams', #9 (rational64s[31 or 64])
    # 0xf013 - int32u[3] same as 0xf00d
    # 0xf014 - int32u[3] - also related to WhiteBalance
);

# information found in FFMV atom of MOV videos
%Image::ExifTool::FujiFilm::FFMV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => 'Information found in the FFMV atom of MOV videos.',
    0 => {
        Name => 'MovieStreamName',
        Format => 'string[34]',
    },
);

# tags in FujiFilm QuickTime videos (ref PH)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::FujiFilm::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => 'This information is found in MOV videos from some FujiFilm cameras.',
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[16]',
    },
    0x2e => { # (NC)
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 1 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x32 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x3a => { # (NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
    },
);

# tags in RAF M-RAW header (ref PH)
%Image::ExifTool::FujiFilm::MRAW = (
    PROCESS_PROC => \&ProcessMRAW,
    GROUPS => { 0 => 'RAF', 1 => 'M-RAW', 2 => 'Image' },
    FORMAT => 'int32u',
    TAG_PREFIX => 'MRAW',
    NOTES => q{
        Tags extracted from the M-RAW header of multi-image RAF files.  The family 1
        group name for these tags is "M-RAW".  Additional metadata may be extracted
        from the embedded RAW images with the ExtractEmbedded option.
    },
    0x2001 => { Name => 'RawImageNumber', Format => 'int32u' },
    # 0x2003 - seen "0 100", "-300 100" and "300 100" for a sequence of 3 images
    0x2003 => { Name => 'ExposureCompensation', Format => 'rational32s', Unknown => 1, Hidden => 1, PrintConv => 'sprintf("%+.2f",$val)' },
    # 0x2004 - (same value as 3 in all my samples)
    0x2004 => { Name => 'ExposureCompensation2', Format => 'rational32s', Unknown => 1, Hidden => 1, PrintConv => 'sprintf("%+.2f",$val)' },
    # 0x2005 - seen "10 1600", "10 6800", "10 200", "10 35000" etc
    0x2005 => { Name => 'ExposureTime', Format => 'rational64u', PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)' },
    # 0x2006 - seen "450 100", "400 100" (all images in RAF have same value)
    0x2006 => { Name => 'FNumber', Format => 'rational64u', PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)' },
    # 0x2007 - seen 200, 125, 250, 2000
    0x2007 => 'ISO',
    # 0x2008 - seen 0, 65536
);

#------------------------------------------------------------------------------
# decode information from FujiFilm face recognition information
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) tag table ref
# Returns: 1
sub ProcessFaceRec($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} + ($$dirInfo{Base} || 0);
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $pos = $dirStart;
    my $end = $dirStart + $dirLen;
    my ($i, $n, $p, $val);
    $et->VerboseDir('FaceRecInfo');
    for ($i=1; ; ++$i) {
        last if $pos + 8 > $end;
        my $off = Get32u($dataPt, $pos) + $dirStart;
        my $len = Get32u($dataPt, $pos + 4);
        last if $len==0 or $off>$end or $off+$len>$end or $len < 62;
        # values observed for each offset (always zero if not listed):
        # 0=5; 3=1; 4=4; 6=1; 10-13=numbers(constant for a given registered face)
        # 15=16; 16=3; 18=1; 22=nameLen; 26=1; 27=16; 28=7; 30-33=nameLen(int32u)
        # 34-37=nameOffset(int32u); 38=32; 39=16; 40=4; 42=1; 46=0,2,4,8(category)
        # 50=33; 51=16; 52=7; 54-57=dateLen(int32u); 58-61=dateOffset(int32u)
        $n = Get32u($dataPt, $off + 30);
        $p = Get32u($dataPt, $off + 34) + $dirStart;
        last if $p < $dirStart or $p + $n > $end;
        $val = substr($$dataPt, $p, $n);
        $et->HandleTag($tagTablePtr, "Face${i}Name", $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $p,
            Size    => $n,
        );
        $n = Get32u($dataPt, $off + 54);
        $p = Get32u($dataPt, $off + 58) + $dirStart;
        last if $p < $dirStart or $p + $n > $end;
        $val = substr($$dataPt, $p, $n);
        $val =~ s/(\d{4})(\d{2})(\d{2})/$1:$2:$2/;
        $et->HandleTag($tagTablePtr, "Face${i}Birthday", $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $p,
            Size    => $n,
        );
        $et->HandleTag($tagTablePtr, "Face${i}Category", undef,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $off + 46,
            Size    => 1,
        );
        $pos += 8;
    }
    return 1;
}

#------------------------------------------------------------------------------
# get information from FujiFilm RAF directory
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) tag table ref
# Returns: 1 if this was a valid FujiFilm directory
sub ProcessFujiDir($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $offset = $$dirInfo{DirStart};
    $raf->Seek($offset, 0) or return 0;
    my ($buff, $index);
    $raf->Read($buff, 4) or return 0;
    my $entries = unpack 'N', $buff;
    $entries < 256 or return 0;
    $et->VerboseDir('Fuji', $entries);
    SetByteOrder('MM');
    my $pos = $offset + 4;
    for ($index=0; $index<$entries; ++$index) {
        $raf->Read($buff,4) or return 0;
        $pos += 4;
        my ($tag, $len) = unpack 'nn', $buff;
        my ($val, $vbuf);
        $raf->Read($vbuf, $len) or return 0;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo and $$tagInfo{Format}) {
            $val = ReadValue(\$vbuf, 0, $$tagInfo{Format}, $$tagInfo{Count}, $len);
            next unless defined $val;
        } elsif ($len == 4) {
            # interpret unknown 4-byte values as int32u
            $val = Get32u(\$vbuf, 0);
        } else {
            # treat other unknown values as binary data
            $val = \$vbuf;
        }
        $et->HandleTag($tagTablePtr, $tag, $val,
            Index   => $index,
            DataPt  => \$vbuf,
            DataPos => $pos,
            Size    => $len,
            TagInfo => $tagInfo,
        );
        $pos += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# get information from FujiFilm M-RAW header
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 if this was a valid M-RAW header
sub ProcessMRAW($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    return 1 if $$et{DOC_NUM};
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dataLen = length $$dataPt;
    $dataLen < 44 and $et->Warn('Short M-RAW header'), return 0;
    $$dataPt =~ /^FUJIFILMM-RAW  / or $et->Warn('Bad M-RAW header'), return 0;
    my $ver = substr($$dataPt, 16, 4);
    $et->VerboseDir("M-RAW $ver", undef, $dataLen);
    SetByteOrder('MM');
    my $size = Get16u($dataPt, 40); # (these are just a guess - PH)
    my $num = Get16u($dataPt, 42);
    my $pos = 44;
    my ($i, $n);
    for ($n=0; ; ++$n) {
        my $end = $pos + 16 + $size;
        last if $end > $dataLen;
        my $rafStart = Get64u($dataPt, $pos);
        my $rafLen = Get64u($dataPt, $pos+8);
        $pos += 16;  # skip offset/size fields
        $$et{DOC_NUM} = ++$$et{DOC_COUNT} if $pos > 60;
        $et->VPrint(0, "$$et{INDENT}(Raw image $n parameters: $size bytes, $num entries)\n");
        for ($i=0; $i<$num; ++$i) {
            last if $pos + 4 > $end;
            my $tag = Get16u($dataPt, $pos);
            my $size = Get16u($dataPt, $pos+2);
            $pos += 4;
            last if $pos + $size > $end;
            $et->HandleTag($tagTablePtr, $tag, undef,
                DataPt  => $dataPt,
                DataPos => $dataPos,
                Start   => $pos,
                Size    => $size,
            );
            $pos += $size;
        }
        if ($rafStart and $et->Options('ExtractEmbedded')) {
            if ($et->Options('Verbose')) {
                my $msg = sprintf("$$et{INDENT}(RAW image $n data: Start=0x%x, Length=0x%x)\n",$rafStart,$rafLen);
                $et->VPrint(0, $msg);
            }
            my $raf = $$et{RAF};
            my $tell = $raf->Tell();
            my $order = GetByteOrder();
            my $fujiWidth = $$et{FujiWidth};
            $raf->Seek($rafStart, 0) or next;
            ProcessRAF($et, { RAF => $raf, Base => $rafStart });
            $$et{FujiWidth} = $fujiWidth;
            SetByteOrder($order);
            $raf->Seek($tell, 0);
        }
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# write information to FujiFilm RAW file (RAF)
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid RAF file, or -1 on write error
sub WriteRAF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($hdr, $jpeg, $outJpeg, $offset, $err, $buff);

    $raf->Read($hdr,0x94) == 0x94  or return 0;
    $hdr =~ /^FUJIFILM/            or return 0;
    my $ver = substr($hdr, 0x3c, 4);
    $ver =~ /^\d{4}$/ or $testedRAF{$ver} or return 0;

    # get position and size of M-RAW header
    my ($mpos, $mlen) = unpack('x72NN', $hdr);
    # get the position and size of embedded JPEG
    my ($jpos, $jlen) = unpack('x84NN', $hdr);
    # check to be sure the JPEG starts in the expected location
    if (($mpos > 0x94 or $jpos > 0x94 + $mlen) or $jpos < 0x68 or $jpos & 0x03) {
        $et->Error("Unsupported or corrupted RAF image (version $ver)");
        return 1;
    }
    # check to make sure this version of RAF has been tested
    #(removed in ExifTool 11.70)
    #unless ($testedRAF{$ver}) {
    #    $et->Warn("RAF version $ver not yet tested", 1);
    #}
    # read the embedded JPEG
    unless ($raf->Seek($jpos, 0) and $raf->Read($jpeg, $jlen) == $jlen) {
        $et->Error('Error reading RAF meta information');
        return 1;
    }
    if ($mpos) {
        if ($mlen != 0x11c) {
            $et->Error('Unsupported M-RAW header (please submit sample for testing)');
            return 1;
        }
        # read M-RAW header and add to file header
        my $mraw;
        unless ($raf->Seek($mpos, 0) and $raf->Read($mraw, $mlen) == $mlen) {
            $et->Error('Error reading M-RAW header');
            return 1;
        }
        $hdr .= $mraw;
        # verify that the 1st raw image offset is zero, and that the 1st raw image
        # length is the same as the 2nd raw image offset
        unless (substr($hdr, 0xc0, 8) eq "\0\0\0\0\0\0\0\0" and
                substr($hdr, 0xc8, 8) eq substr($hdr, 0x110, 8))
        {
            $et->Error('Unexpected layout of M-RAW header');
            return 1;
        }
    }
    # use same write directories as JPEG
    $et->InitWriteDirs('JPEG');
    # rewrite the embedded JPEG in memory
    my %jpegInfo = (
        Parent  => 'RAF',
        RAF     => File::RandomAccess->new(\$jpeg),
        OutFile => \$outJpeg,
    );
    $$et{FILE_TYPE} = 'JPEG';
    my $success = $et->WriteJPEG(\%jpegInfo);
    $$et{FILE_TYPE} = 'RAF';
    unless ($success and $outJpeg) {
        $et->Error("Invalid RAF format");
        return 1;
    }
    return -1 if $success < 0;

    # rewrite the RAF image
    SetByteOrder('MM');
    my $jpegLen = length $outJpeg;
    # pad JPEG to an even 4 bytes (ALWAYS use padding as Fuji does)
    my $pad = "\0" x (4 - ($jpegLen % 4));
    # update JPEG size in header (size without padding)
    Set32u(length($outJpeg), \$hdr, 0x58);
    # get pointer to start of the next RAF block
    my $nextPtr = Get32u(\$hdr, 0x5c);
    # determine the length of padding at the end of the original JPEG
    my $oldPadLen = $nextPtr - ($jpos + $jlen);
    if ($oldPadLen) {
        if ($oldPadLen > 1000000 or $oldPadLen < 0 or
            not $raf->Seek($jpos+$jlen, 0) or
            $raf->Read($buff, $oldPadLen) != $oldPadLen)
        {
            $et->Error('Bad RAF pointer at 0x5c');
            return 1;
        }
        # make sure padding is only zero bytes (can be >100k for HS10)
        # (have seen non-null padding in X-Pro1)
        if ($buff =~ /[^\0]/) {
            return 1 if $et->Error('Non-null bytes found in padding', 2);
        }
    }
    # calculate offset difference due to change in JPEG size
    my $ptrDiff = length($outJpeg) + length($pad) - ($jlen + $oldPadLen);
    # update necessary pointers in header (0xcc and higher in M-RAW header)
    foreach $offset (0x5c, 0x64, 0x78, 0x80, 0xcc, 0x114, 0x164) {
        last if $offset >= $jpos;   # some versions have a short header
        my $oldPtr = Get32u(\$hdr, $offset);
        next unless $oldPtr;        # don't update if pointer is zero
        my $newPtr = $oldPtr + $ptrDiff;
        if ($newPtr < 0 or $newPtr > 0xffffffff) {
            $offset < 0xcc and $et->Error('Invalid offset in RAF header'), return 1;
            # assume values at 0xcc and greater are 8-byte integers (NC)
            # and adjust high word if necessary
            my $high = Get32u(\$hdr, $offset-4);
            if ($newPtr < 0) {
                $high -= 1;
                $newPtr += 0xffffffff + 1;
                $high < 0 and $et->Error('RAF header offset error'), return 1;
            } else {
                $high += 1;
                $newPtr -= 0xffffffff + 1;
            }
            Set32u($high, \$hdr, $offset-4);
        }
        Set32u($newPtr, \$hdr, $offset);
    }
    # write the new header
    my $outfile = $$dirInfo{OutFile};
    Write($outfile, substr($hdr, 0, $jpos)) or $err = 1;
    # write the updated JPEG plus padding
    Write($outfile, $outJpeg, $pad) or $err = 1;
    # copy over the rest of the RAF image
    unless ($raf->Seek($nextPtr, 0)) {
        $et->Error('Error reading RAF image');
        return 1;
    }
    while ($raf->Read($buff, 65536)) {
        Write($outfile, $buff) or $err = 1, last;
    }
    return $err ? -1 : 1;
}

#------------------------------------------------------------------------------
# get information from FujiFilm RAW file (RAF)
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid RAF file
sub ProcessRAF($$)
{
    my ($et, $dirInfo) = @_;
    my ($buff, $jpeg, $warn, $offset);

    my $raf = $$dirInfo{RAF};
    my $base = $$dirInfo{Base} || 0;
    $raf->Read($buff,0x70) == 0x70    or return 0;
    $buff =~ /^FUJIFILM/              or return 0;
    # get position and size of M-RAW header and jpeg preview
    my ($mpos, $mlen) = unpack('x72NN', $buff);
    my ($jpos, $jlen) = unpack('x84NN', $buff);
    $jpos & 0x8000                   and return 0;
    if ($jpos) {
        $raf->Seek($jpos+$base, 0)        or return 0;
        $raf->Read($jpeg, $jlen) == $jlen or return 0;
    }
    SetByteOrder('MM');
    $et->SetFileType() unless $$et{DOC_NUM};
    my $tbl = GetTagTable('Image::ExifTool::FujiFilm::RAFHeader');
    $et->ProcessDirectory({ DataPt => \$buff, DirName => 'RAFHeader', Base => $base }, $tbl);
    
    # extract information from embedded JPEG
    my %dirInfo = (
        Parent => 'RAF',
        RAF    => File::RandomAccess->new(\$jpeg),
    );
    if ($jpos) {
        $$et{BASE} += $jpos + $base;
        my $ok = $et->ProcessJPEG(\%dirInfo);
        $$et{BASE} -= $jpos + $base;
        $et->FoundTag('PreviewImage', \$jpeg) if $ok;
    }
    # extract information from Fuji RAF and TIFF directories
    my ($rafNum, $ifdNum) = ('','');
    foreach $offset (0x48, 0x5c, 0x64, 0x78, 0x80) {
        last if $jpos and $offset >= $jpos;
        unless ($raf->Seek($offset+$base, 0) and $raf->Read($buff, 8)) {
            $warn = 1;
            last;
        }
        my ($start, $len) = unpack('N2',$buff);
        next unless $start;
        $start += $base;
        if ($offset == 0x64 or $offset == 0x80) {
            # parse FujiIFD directory
            %dirInfo = (
                RAF  => $raf,
                Base => $start,
            );
            $$et{SET_GROUP1} = "FujiIFD$ifdNum";
            my $tagTablePtr = GetTagTable('Image::ExifTool::FujiFilm::IFD');
            # this is TIFF-format data only for some models, so no warning if it fails
            unless ($et->ProcessTIFF(\%dirInfo, $tagTablePtr, \&Image::ExifTool::ProcessTIFF)) {
                # do hash of image data if necessary
                $et->ImageDataHash($raf, $len, 'raw') if $$et{ImageDataHash} and $raf->Seek($start,0);
            }
            delete $$et{SET_GROUP1};
            $ifdNum = ($ifdNum || 1) + 1;
        } elsif ($offset == 0x48) {
            $$et{VALUE}{FileType} .= ' (M-RAW)';
            if ($raf->Seek($start, 0) and $raf->Read($buff, $mlen) == $mlen) {
                my $tbl = GetTagTable('Image::ExifTool::FujiFilm::MRAW');
                $et->ProcessDirectory({ DataPt => \$buff, DataPos => $start, DirName => 'M-RAW' }, $tbl);
            } else {
                $et->Warn('Error reading M-RAW header');
            }
        } else {
            # parse RAF directory
            %dirInfo = (
                RAF      => $raf,
                DirStart => $start,
            );
            $$et{SET_GROUP1} = "RAF$rafNum";
            my $tagTablePtr = GetTagTable('Image::ExifTool::FujiFilm::RAF');
            if ($et->ProcessDirectory(\%dirInfo, $tagTablePtr)) {
                $rafNum = ($rafNum || 1) + 1;
            } else {
                $warn = 1;
            }
            delete $$et{SET_GROUP1};
        }
    }
    $warn and $et->Warn('Possibly corrupt RAF information');

    return 1;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::FujiFilm - Read/write FujiFilm maker notes and RAF images

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
FujiFilm maker notes in EXIF information, and to read/write FujiFilm RAW
(RAF) images.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_fuji.htm>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item (...plus testing with my own FinePix 2400 Zoom)

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Michael Meissner, Paul Samuelson and Jens Duttke for help decoding
some FujiFilm information.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FujiFilm Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
