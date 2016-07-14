#------------------------------------------------------------------------------
# File:         Sony.pm
#
# Description:  Sony EXIF Maker Notes tags
#
# Revisions:    04/06/2004  - P. Harvey Created
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               2) http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm (2006/08/06)
#               3) Thomas Bodenmann private communication
#               4) Philippe Devaux private communication (A700)
#               5) Marcus Holland-Moritz private communication (A700)
#               6) Andrey Tverdokhleb private communication
#               7) Rudiger Lange private communication (A700)
#               8) Igal Milchtaich private communication
#               9) Michael Reitinger private communication (DSC-TX7,RX100)
#               10) http://www.klingebiel.com/tempest/hd/pmp.html
#               11) Mike Battilana private communication
#               13) http://www.mi-fo.de/forum/index.php?showtopic=33239
#                   http://www.dyxum.com/dforum/the-alpha-shutter-count-tool_topic97489_page4.html
#               IB) Iliah Borg private communication (LibRaw)
#               JD) Jens Duttke private communication
#               JR) Jos Roost private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Sony;

use strict;
use vars qw($VERSION %sonyLensTypes);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::Minolta;

$VERSION = '2.40';

sub ProcessSRF($$$);
sub ProcessSR2($$$);
sub ProcessSonyPIC($$$);
sub ProcessMoreInfo($$$);
sub Decipher($;$);
sub ProcessEnciphered($$$);
sub WriteEnciphered($$$);
sub WriteSR2($$$);
sub ConvLensSpec($);
sub ConvInvLensSpec($);
sub PrintLensSpec($);
sub PrintInvLensSpec($;$$);
sub MakeTiffHeader($$$$;$);

# (%sonyLensTypes is filled in based on Minolta LensType's)

# Sony E-mount lenses
# (NOTE: these should be kept in sync with the 65535 entries in %minoltaLensTypes)
my %sonyLensTypes2 = (
    Notes => 'Lens type numbers for Sony E-mount lenses used by NEX models.',
    0 => 'Unknown E-mount lens or other lens',
    1 => 'Sony LA-EA1 Adapter',
    2 => 'Sony LA-EA2 Adapter',
    3 => 'Sony LA-EA3 Adapter', #(NC) ILCE-7 image with A-mount lens, but also has 0x940e 2nd byte=2
    6 => 'Sony LA-EA4 Adapter', #(NC) ILCE-7R image with A-mount lens and having phase-detect info blocks in 0x940e AFInfo
    44 => 'Metabones Canon EF Smart Adapter', #JR
    78 => 'Metabones Canon EF Smart Adapter Mark III or Other Adapter', #PH/JR (also Mark IV, Fotodiox and Viltrox)
    234 => 'Metabones Canon EF Smart Adapter Mark IV', #JR
    239 => 'Metabones Canon EF Speed Booster', #JR
                                                # Sony VX product code: (http://www.mi-fo.de/forum/index.php?s=7df1c8d3b1cd675f2abf4f4442e19cf2&showtopic=35035&view=findpost&p=303746)
    32784 => 'Sony E 16mm F2.8',                # VX9100
    32785 => 'Sony E 18-55mm F3.5-5.6 OSS',     # VX9101
    32786 => 'Sony E 55-210mm F4.5-6.3 OSS',    # VX9102
    32787 => 'Sony E 18-200mm F3.5-6.3 OSS',    # VX9103
    32788 => 'Sony E 30mm F3.5 Macro',          # VX9104
    32789 => 'Sony E 24mm F1.8 ZA',             # VX9105
    32790 => 'Sony E 50mm F1.8 OSS',            # VX9106
    32791 => 'Sony E 16-70mm F4 ZA OSS',        # VX9107
    32792 => 'Sony E 10-18mm F4 OSS',           # VX9108
    32793 => 'Sony E PZ 16-50mm F3.5-5.6 OSS',  # VX9109
    32794 => 'Sony FE 35mm F2.8 ZA',            # VX9110
    32795 => 'Sony FE 24-70mm F4 ZA OSS',       # VX9111

    32797 => 'Sony E 18-200mm F3.5-6.3 OSS LE', # VX9113
    32798 => 'Sony E 20mm F2.8',                # VX9114
    32799 => 'Sony E 35mm F1.8 OSS',            # VX9115
    32800 => 'Sony E PZ 18-105mm F4 G OSS', #JR # VX9116

    32802 => 'Sony FE 90mm F2.8 Macro G OSS',   # VX?
    32803 => 'Sony E 18-50mm F4-5.6',

    32807 => 'Sony E PZ 18-200mm F3.5-6.3 OSS', # VX9123
    32808 => 'Sony FE 55mm F1.8 ZA',            # VX9124

    32810 => 'Sony FE 70-200mm F4 G OSS', #JR   # VX9126
    32811 => 'Sony FE 16-35mm F4 ZA OSS', #JR   # VX9127

    32813 => 'Sony FE 28-70mm F3.5-5.6 OSS',    # VX9129
    32814 => 'Sony FE 35mm F1.4 ZA',            # VX?
    32815 => 'Sony FE 24-240mm F3.5-6.3 OSS',   # VX?
    32816 => 'Sony FE 28mm F2', #JR             # VX?
    32817 => 'Sony FE PZ 28-135mm F4 G OSS',#JR # VX?

    32821 => 'Sony FE 24-70mm F2.8 GM', #JR/IB
    32822 => 'Sony FE 50mm F1.4 ZA', #JR
    32823 => 'Sony FE 85mm F1.4 GM', #JR/IB
    32824 => 'Sony FE 50mm F1.8', #JR (Sony code 'SEL50F18F' with trailing "F" as compared to 'SEL50F18' for 32790)

    32826 => 'Sony FE 21mm F2.8 (SEL28F20 + SEL075UWC)', #JR          # (+ Ultra-wide converter)
    32827 => 'Sony FE 16mm F3.5 Fisheye (SEL28F20 + SEL057FEC)', #JR  # (+ Fisheye converter)
    32828 => 'Sony FE 70-300mm F4.5-5.6 G OSS', #JR
    32830 => 'Sony FE 70-200mm F2.8 GM OSS', #JR

    49201 => 'Zeiss Touit 12mm F2.8', #JR (lens firmware Ver.02)
    49202 => 'Zeiss Touit 32mm F1.8', #JR (lens firmware Ver.02)
    49203 => 'Zeiss Touit 50mm F2.8 Macro', #JR (lens firmware Ver.02)
    49216 => 'Zeiss Batis 25mm F2', #JR
    49217 => 'Zeiss Batis 85mm F1.8', #JR
    49218 => 'Zeiss Batis 18mm F2.8', #IB
    49232 => 'Zeiss Loxia 50mm F2', #JR (lens firmware Ver.02)
    49233 => 'Zeiss Loxia 35mm F2', #JR (lens firmware Ver.02)
    49234 => 'Zeiss Loxia 21mm F2.8', #PH

    50480 => 'Sigma 30mm F1.4 DC DN | C 016', #IB/JR
    50481 => 'Sigma 50mm F1.4 DG HSM | A 014 + MC-11', #JR
    50482 => 'Sigma 18-300mm F3.5-6.3 DC MACRO OS HSM | C 014 + MC-11', #JR
    50483 => 'Sigma 18-35mm F1.8 DC HSM | A 013 + MC-11', #JR
    50484 => 'Sigma 24-35mm F2 DG HSM | A 015 + MC-11', #JR
    50486 => 'Sigma 150-600mm F5-6.3 DG OS HSM | C 015 + MC-11', #JR
    50487 => 'Sigma 20mm F1.4 DG HSM | A 015 + MC-11', #JR
    50488 => 'Sigma 35mm F1.4 DG HSM | A 012 + MC-11', #JR
    50489 => 'Sigma 150-600mm F5-6.3 DG OS HSM | S 014 + MC-11', #JR
    50490 => 'Sigma 120-300mm F2.8 DG OS HSM | S 013 + MC-11', #JR
    50492 => 'Sigma 24-105mm F4 DG OS HSM | A 013 + MC-11', #JR
    50493 => 'Sigma 17-70mm F2.8-4 DC MACRO OS HSM | C 013 + MC-11', #JR
    50495 => 'Sigma 50-100mm F1.8 DC HSM | A 016 + MC-11', #JR

    # lenses listed in the Sigma MC-11 list, but not yet seen:
    # 504xx => 'Sigma 18-200mm F3.5-6.3 DC MACRO OS HSM | C 014 + MC-11',
    # 504xx => 'Sigma 18-300mm F3.5-6.3 DC MACRO OS HSM | C 014 + MC-11',
    # 504xx => 'Sigma 24mm F1.4 DG HSM | A 015 + MC-11',
    # 504xx => 'Sigma 30mm F1.4 DC HSM | A 013 + MC-11',
);

# ExposureProgram values (ref PH, mainly decoded from A200)
my %sonyExposureProgram = (
    0 => 'Auto', # (same as 'Program AE'?)
    1 => 'Manual',
    2 => 'Program AE',
    3 => 'Aperture-priority AE',
    4 => 'Shutter speed priority AE',
    8 => 'Program Shift A', #7
    9 => 'Program Shift S', #7
    16 => 'Portrait', # (A330)
    17 => 'Sports', # (A330)
    18 => 'Sunset', # (A330)
    19 => 'Night Portrait', # (A330)
    20 => 'Landscape', # (A330)
    21 => 'Macro', # (A330)
    35 => 'Auto No Flash', # (A330)
);

# ExposureProgram values in CameraSettings3 (ref JR)
my %sonyExposureProgram2 = (            # A580 Mode Dial setting:
     1 => 'Program AE',                 # P
     2 => 'Aperture-priority AE',       # A
     3 => 'Shutter speed priority AE',  # S
     4 => 'Manual',                     # M
     5 => 'Cont. Priority AE',          # (A35)
    16 => 'Auto',                       # AUTO
    17 => 'Auto (no flash)',            # "flash strike-out" symbol
    18 => 'Auto+',                      #PH (A33)
    49 => 'Portrait',                   # SCN
    50 => 'Landscape',                  # SCN
    51 => 'Macro',                      # SCN
    52 => 'Sports',                     # SCN
    53 => 'Sunset',                     # SCN
    54 => 'Night view',                 # SCN
    55 => 'Night view/portrait',        # SCN
    56 => 'Handheld Night Shot',        # SCN (also called "Hand-held Twilight")
    57 => '3D Sweep Panorama',          # "Panorama" symbol
    64 => 'Auto 2',                     #PH (A33 AUTO)
    65 => 'Auto 2 (no flash)',          #JR (NC, A35)
    80 => 'Sweep Panorama',             # "Panorama" symbol
    96 => 'Anti Motion Blur',           #PH (NEX-5)
    # 128-138 are A35 picture effects (combined SCN/Picture effect mode dial position)
    128 => 'Toy Camera',
    129 => 'Pop Color',
    130 => 'Posterization',
    131 => 'Posterization B/W',
    132 => 'Retro Photo',
    133 => 'High-key',
    134 => 'Partial Color Red',
    135 => 'Partial Color Green',
    136 => 'Partial Color Blue',
    137 => 'Partial Color Yellow',
    138 => 'High Contrast Monochrome',
);

# ExposureProgram values in Tags 2010 and 94xx (ref JR)
my %sonyExposureProgram3 = (
     0 => 'Program AE',
     1 => 'Aperture-priority AE',
     2 => 'Shutter speed priority AE',
     3 => 'Manual',
     4 => 'Auto',
     5 => 'iAuto',
     6 => 'Superior Auto',
     7 => 'iAuto+',
     8 => 'Portrait',
     9 => 'Landscape',
    10 => 'Twilight',
    11 => 'Twilight Portrait',
    12 => 'Sunset',
    14 => 'Action (High speed)', #PH (RX100)
    16 => 'Sports',
    17 => 'Handheld Night Shot',
    18 => 'Anti Motion Blur',
    19 => 'High Sensitivity',
    21 => 'Beach',
    22 => 'Snow',
    23 => 'Fireworks',
    26 => 'Underwater',
    27 => 'Gourmet',
    28 => 'Pet',
    29 => 'Macro',
    30 => 'Backlight Correction HDR',
    # 32 => 'Night ... ???', # seen for HDR-CX360E
    33 => 'Sweep Panorama',
    36 => 'Background Defocus',
    37 => 'Soft Skin',
    42 => '3D Image',
    43 => 'Cont. Priority AE',
);

# WhiteBalanceSetting values (ref JR)
my %whiteBalanceSetting = (
    0x10 => 'Auto (-3)', #(NC)
    0x11 => 'Auto (-2)', #(NC)
    0x12 => 'Auto (-1)', #(NC)
    0x13 => 'Auto (0)',
    0x14 => 'Auto (+1)', #(NC)
    0x15 => 'Auto (+2)', #(NC)
    0x16 => 'Auto (+3)', #(NC)
    0x20 => 'Daylight (-3)',
    0x21 => 'Daylight (-2)', #(NC)
    0x22 => 'Daylight (-1)', #(NC)
    0x23 => 'Daylight (0)',
    0x24 => 'Daylight (+1)',
    0x25 => 'Daylight (+2)',
    0x26 => 'Daylight (+3)',
    0x30 => 'Shade (-3)', #(NC)
    0x31 => 'Shade (-2)', #(NC)
    0x32 => 'Shade (-1)', #(NC)
    0x33 => 'Shade (0)',
    0x34 => 'Shade (+1)', #(NC)
    0x35 => 'Shade (+2)', #(NC)
    0x36 => 'Shade (+3)',
    0x40 => 'Cloudy (-3)', #(NC)
    0x41 => 'Cloudy (-2)', #(NC)
    0x42 => 'Cloudy (-1)', #(NC)
    0x43 => 'Cloudy (0)',
    0x44 => 'Cloudy (+1)', #(NC)
    0x45 => 'Cloudy (+2)', #(NC)
    0x46 => 'Cloudy (+3)', #(NC)
    0x50 => 'Tungsten (-3)', #(NC)
    0x51 => 'Tungsten (-2)', #(NC)
    0x52 => 'Tungsten (-1)', #(NC)
    0x53 => 'Tungsten (0)',
    0x54 => 'Tungsten (+1)', #(NC)
    0x55 => 'Tungsten (+2)', #(NC)
    0x56 => 'Tungsten (+3)', #(NC)
    0x60 => 'Fluorescent (-3)', #(NC)
    0x61 => 'Fluorescent (-2)', #(NC)
    0x62 => 'Fluorescent (-1)', #(NC)
    0x63 => 'Fluorescent (0)',
    0x64 => 'Fluorescent (+1)', #(NC)
    0x65 => 'Fluorescent (+2)', #(NC)
    0x66 => 'Fluorescent (+3)', #(NC)
    0x70 => 'Flash (-3)', #(NC)
    0x71 => 'Flash (-2)', #(NC)
    0x72 => 'Flash (-1)', #(NC)
    0x73 => 'Flash (0)',
    0x74 => 'Flash (+1)', #(NC)
    0x75 => 'Flash (+2)', #(NC)
    0x76 => 'Flash (+3)', #(NC)
    0xa3 => 'Custom',
    0xf3 => 'Color Temperature/Color Filter',
);

# AF points for cameras with 15-point AF (ref JR)
my %afPoint15 = (
    0 => 'Upper-left',
    1 => 'Left',
    2 => 'Lower-left',
    3 => 'Far Left',
    4 => 'Top (horizontal)',
    5 => 'Near Right',
    6 => 'Center (horizontal)',
    7 => 'Near Left',
    8 => 'Bottom (horizontal)',
    9 => 'Top (vertical)',
    10 => 'Center (vertical)',
    11 => 'Bottom (vertical)',
    12 => 'Far Right',
    13 => 'Upper-right',
    14 => 'Right',
    15 => 'Lower-right',
    16 => 'Upper-middle',
    17 => 'Lower-middle',
);

# AF points for cameras with 19-point AF (ref PH)
# (verified for A77 firmware 1.07)
my %afPoint19 = (
    0 => 'Upper Far Left',
    1 => 'Upper-left (horizontal)',
    2 => 'Far Left (horizontal)',
    3 => 'Left (horizontal)',
    4 => 'Lower Far Left',
    5 => 'Lower-left (horizontal)',
    6 => 'Upper-left (vertical)',
    7 => 'Left (vertical)',
    8 => 'Lower-left (vertical)',
    9 => 'Far Left (vertical)',
    10 => 'Top (horizontal)',
    11 => 'Near Right',
    12 => 'Center (horizontal)',
    13 => 'Near Left',
    14 => 'Bottom (horizontal)',
    15 => 'Top (vertical)',
    16 => 'Upper-middle',
    17 => 'Center (vertical)',
    18 => 'Lower-middle',
    19 => 'Bottom (vertical)',
    20 => 'Upper Far Right',
    21 => 'Upper-right (horizontal)',
    22 => 'Far Right (horizontal)',
    23 => 'Right (horizontal)',
    24 => 'Lower Far Right',
    25 => 'Lower-right (horizontal)',
    26 => 'Far Right (vertical)',
    27 => 'Upper-right (vertical)',
    28 => 'Right (vertical)',
    29 => 'Lower-right (vertical)',
);

# 79 AF point layout and indices for ILCA-68/77M2, numbered 0-78 for direct look-up from BITMASK in 0x2020,
# E6 = Center (ref JR)
my %afPoints79 = (
                                             0=>'A5',  1=>'A6',  2=>'A7',
               3=>'B2',  4=>'B3',  5=>'B4',  6=>'B5',  7=>'B6',  8=>'B7',  9=>'B8', 10=>'B9', 11=>'B10',
    12=>'C1', 13=>'C2', 14=>'C3', 15=>'C4', 16=>'C5', 17=>'C6', 18=>'C7', 19=>'C8', 20=>'C9', 21=>'C10', 22=>'C11',
    23=>'D1', 24=>'D2', 25=>'D3', 26=>'D4', 27=>'D5', 28=>'D6', 29=>'D7', 30=>'D8', 31=>'D9', 32=>'D10', 33=>'D11',
    34=>'E1', 35=>'E2', 36=>'E3', 37=>'E4', 38=>'E5', 39=>'E6', 40=>'E7', 41=>'E8', 42=>'E9', 43=>'E10', 44=>'E11',
    45=>'F1', 46=>'F2', 47=>'F3', 48=>'F4', 49=>'F5', 50=>'F6', 51=>'F7', 52=>'F8', 53=>'F9', 54=>'F10', 55=>'F11',
    56=>'G1', 57=>'G2', 58=>'G3', 59=>'G4', 60=>'G5', 61=>'G6', 62=>'G7', 63=>'G8', 64=>'G9', 65=>'G10', 66=>'G11',
              67=>'H2', 68=>'H3', 69=>'H4', 70=>'H5', 71=>'H6', 72=>'H7', 73=>'H8', 74=>'H9', 75=>'H10',
                                            76=>'I5', 77=>'I6', 78=>'I7',
);

# AFPoint and AFStatus tags in AFInfo(Tag940e) use numbers 0 to 94 for the 79 positions + 15 cross + 1 F2.8
my %afPoints79_940e = (
                                            59=>'A5', 50=>'A6', 41=>'A7',
              14=>'B2',  7=>'B3',  0=>'B4', 60=>'B5', 51=>'B6', 42=>'B7', 87=>'B8', 80=>'B9', 73=>'B10',
    21=>'C1', 15=>'C2',  8=>'C3',  1=>'C4', 61=>'C5', 52=>'C6', 43=>'C7', 88=>'C8', 81=>'C9', 74=>'C10', 68=>'C11',
    22=>'D1', 16=>'D2',  9=>'D3',  2=>'D4', 62=>'D5', 53=>'D6', 44=>'D7', 89=>'D8', 82=>'D9', 75=>'D10', 69=>'D11',
    23=>'E1', 17=>'E2', 10=>'E3',  3=>'E4', 63=>'E5', 54=>'E6 Center', 45=>'E7', 90=>'E8', 83=>'E9', 76=>'E10', 70=>'E11',
    24=>'F1', 18=>'F2', 11=>'F3',  4=>'F4', 64=>'F5', 55=>'F6', 46=>'F7', 91=>'F8', 84=>'F9', 77=>'F10', 71=>'F11',
    25=>'G1', 19=>'G2', 12=>'G3',  5=>'G4', 65=>'G5', 56=>'G6', 47=>'G7', 92=>'G8', 85=>'G9', 78=>'G10', 72=>'G11',
              20=>'H2', 13=>'H3',  6=>'H4', 66=>'H5', 57=>'H6', 48=>'H7', 93=>'H8', 86=>'H9', 79=>'H10',
                                            67=>'I5', 58=>'I6', 49=>'I7',

                                   28=>'A5 Vertical', 27=>'A6 Vertical', 26=>'A7 Vertical',
                                   31=>'C5 Vertical', 30=>'C6 Vertical', 29=>'C7 Vertical',
                                   34=>'E5 Vertical', 33=>'E6 Center Vertical', 32=>'E7 Vertical',
                                   37=>'G5 Vertical', 36=>'G6 Vertical', 35=>'G7 Vertical',
                                   40=>'I5 Vertical', 39=>'I6 Vertical', 38=>'I7 Vertical',

                                                      94=>'E6 Center F2.8',
);

my %binaryDataAttrs = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
);

# tagInfo attributes for unknown cipher block tags
my %unknownCipherData = (
    Unknown => 1,   # require Unknown option
    Hidden => 1,    # doesn't appear in Tag Name documentation
    RawConv => sub { Decipher(\$_[0]); return $_[0] },
    ValueConv => 'PrintHex($val)',                      # print as hex
    PrintConv => 'length($val) > 65 ? substr($val,0,60) . "[...]" : $val',  # limit length
);

my %meterInfo1 = (
    Format => 'int32u[27]',
    PrintConv => 'sprintf("%19d %4d %6d" . " %3d %4d %6d" x 8, split(" ",$val))',
    PrintConvInv => '$val',
);
my %meterInfo2 = (
    Format => 'int32u[33]',
    PrintConv => 'sprintf("%3d %4d %6d" . " %3d %4d %6d" x 10, split(" ",$val))',
    PrintConvInv => '$val',
);

# Sony maker notes tags (some elements in common with %Image::ExifTool::Minolta::Main)
%Image::ExifTool::Sony::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        The following information has been decoded from the MakerNotes of Sony
        cameras.  Some of these tags have been inherited from the Minolta
        MakerNotes.
    },
    0x0010 => [ #PH
        # appears to contain mostly AF related information;
        # for SLT-A77V and newer, similar info is found in 0x940e AFInfo" (ref JR)
        {
            Name => 'CameraInfo',
            # count: A700=368, A850/A900=5478
            Condition => '$count == 368 or $count == 5478',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraInfo',
                ByteOrder => 'BigEndian',
            },
        },{
            Name => 'CameraInfo2',
            # count: A200/A300/A350=5506, A230/A290/A330/A380/A390=6118
            Condition => '$count == 5506 or $count == 6118',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraInfo2',
                ByteOrder => 'LittleEndian',
            },
        },{
            Name => 'CameraInfo3',
            # count: A33/A35/A55V/A450/A500/A550/A560/A580/NEX3/5/5C/C3/VG10E=15360
            Condition => '$count == 15360',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraInfo3',
                ByteOrder => 'LittleEndian',
            },
        },{
            Name => 'CameraInfoUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::CameraInfoUnknown' },
        },
    ],
    # 0x0018 - starts with "GYRO" for sweep panorama images (ref JR)
    #        - contains ImageStabilization information for Minolta
    0x0020 => [
        # similar to WBInfoA100 in Minolta.pm.
        # appears to contain various types of information, as in MoreInfo. (ref JR)
        {
            Name => 'FocusInfo', #PH
            # count: A200/A230/A290/A300/A330/A350/A380/A390==19154, A700/A850/A900=19148
            Condition => '$count == 19154 or $count == 19148',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::FocusInfo',
                ByteOrder => 'LittleEndian',
            },
        },{
            Name => 'MoreInfo', #JR
            # count: A450/A500/A550/A560/A580/A33/A35/A55/NEX-3/5/C3/VG10E==20480
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::MoreInfo',
                ByteOrder => 'LittleEndian',
            },
        },
    ],
    0x0102 => { #5/JD
        Name => 'Quality',
        Writable => 'int32u',
        PrintConv => {
            0 => 'RAW',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra Fine',
            6 => 'RAW + JPEG',
            7 => 'Compressed RAW',
            8 => 'Compressed RAW + JPEG',
            0xffffffff => 'n/a', #PH (SLT-A57 panorama)
        },
    },
    0x0104 => { #5/JD
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Writable => 'rational64s',
    },
    0x0105 => { #5/JD (models since mid-2014, ILCA-77M2, ILCE-7M2/7RM2/7SM2, do not report this tag anymore, ref JR)
        Name => 'Teleconverter',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => \%Image::ExifTool::Minolta::minoltaTeleconverters,
    },
    0x0112 => { #JD
        Name => 'WhiteBalanceFineTune',
        Format => 'int32s',
        Writable => 'int32u',
    },
    0x0114 => [ #PH
        {
            Name => 'CameraSettings',
            # count: A200/A300/A350/A700=280, A850/A900=364
            Condition => '$count == 280 or $count == 364',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings',
                ByteOrder => 'BigEndian',
            },
        },{
            Name => 'CameraSettings2',
            # count: A230/A290/A330/A380/A390=332
            Condition => '$count == 332',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings2',
                ByteOrder => 'BigEndian',
            },
        },{
            Name => 'CameraSettings3',
            # count: A560/A580/A33/A35/A55/NEX3/5/5C/C3/VG10E=1536, A450/A500/A550=2048
            Condition => '$count == 1536 || $count == 2048',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettings3',
                ByteOrder => 'LittleEndian',
            },
        },{
            Name => 'CameraSettingsUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::CameraSettingsUnknown',
                ByteOrder => 'BigEndian',
            },
        },
    ],
    0x0115 => { #JD
        Name => 'WhiteBalance',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Auto',
            0x01 => 'Color Temperature/Color Filter',
            0x10 => 'Daylight',
            0x20 => 'Cloudy',
            0x30 => 'Shade',
            0x40 => 'Tungsten',
            0x50 => 'Flash',
            0x60 => 'Fluorescent',
            0x70 => 'Custom',
            0x80 => 'Underwater',
        },
    },
    # Tag 0x0116: extra hardware info (ref JR)
    # (tag not present for A100, A200, A300, A350, A700, nor for A37, A57, A65, A77)
    0x0116 => [ #JR
        {
            Name => 'ExtraInfo',
            Condition => '$$self{Model} =~ /^DSLR-A(850|900)\b/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sony::ExtraInfo',
                ByteOrder => 'BigEndian',
            },
        },{
            Name => 'ExtraInfo2',
            Condition => '$$self{Model} =~ /^DSLR-A(230|290|330|380|390)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::ExtraInfo2' },
        },{
            Name => 'ExtraInfo3',
            # for DSLR-A450/500/550/560/580, SLT-A33/35/55 and NEX-3/5/5C.
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::ExtraInfo3' },
        }
    ],
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => { TagTable => 'Image::ExifTool::PrintIM::Main' },
    },
    # the next 3 tags have a different meaning for some models (with format int32u)
    0x1000 => { #9 (F88, multi burst mode only)
        Name => 'MultiBurstMode',
        Condition => '$format eq "undef"',
        Notes => 'MultiBurst tags valid only for models with this feature, like the F88',
        Writable => 'undef',
        Format => 'int8u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x1001 => { #9 (F88, multi burst mode only)
        Name => 'MultiBurstImageWidth',
        Condition => '$format eq "int16u"',
        Writable => 'int16u',
    },
    0x1002 => { #9 (F88, multi burst mode only)
        Name => 'MultiBurstImageHeight',
        Condition => '$format eq "int16u"',
        Writable => 'int16u',
    },
    0x1003 => { #9 (64 bytes, contains Panorama info for various DSC, NEX, SLT and DSLR models)
        Name => 'Panorama',
        # panorama: first 4 bytes '1 1 0 0' (little-endian) or '0 0 1 1' (big-endian)
        # non-panorama: all bytes are '0' (ref JR)
        Condition => '$$self{Panorama} = ($$valPt =~ /^(\0\0)?\x01\x01/)', # (little- or big-endian int32u = 257)
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Panorama' },
    },
    # 0x2000 - undef[1]
    0x2001 => { #PH (JPEG images from all DSLR's except the A100)
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Writable => 'undef',
        DataTag => 'PreviewImage',
        Notes => 'HD-size preview in JPEG images from almost all DSLR/SLT/ILCA/NEX/ILCE.',
        # Note: the preview data starts with a 32-byte proprietary Sony header
        #       first 8 bytes after 32-byte header:
        #          \x00\xd8\xff\xe1\x00\x27\xff\xff for JPEG files from A33/35/55V/450/500/550/560/580, NEX-3/5/5C/C3/VG10
        #          \x00\xd8\xff\xdb\x00\x84\x00\x01 for JPEG files from all other models
        #        ( \xff\xd8\xff\xdb\x00\x84\x00\x01 corresponding bytes for all ARW files )
        #
        # DSLR-A700/A850/A900 and DSLR-A200/A300/A350:
        # - no MPImage2
        # DSLR-A230/A290/A330/A380/A390:
        # - PreviewImage start-offset is at 110 bytes inside MPImage2
        # DSLR-A450/A500/A550/A560/A580, SLT-A33/A35/A55V, NEX-3/5/5C/C3/VG10/VG10E:
        # - PreviewImage start-offset is at 106 bytes inside MPImage2
        # - different first bytes after 32-byte header
        # SLT-A37/A57/A58/A65V/A77V/A99V, ILCA-77M2, NEX-3N/5N/5R/5T/6/7/F3, ILCE-3000/3500/5000/6000/7/7R/7S:
        # - PreviewImage start-offset is at 130 bytes inside MPImage2
        # NEX-VG20E/VG30E/VG900, ILCE-QX1: 0x2001 not present
        # ILCE-5100/ILCE-7M2/7RM2/7SM2   : 0x2001 present but Size 0 and Offset 0
        #
        WriteCheck => 'return $val=~/^(none|.{32}\xff\xd8\xff)/s ? undef : "Not a valid image"',
        RawConv => q{
            return \$val if $val =~ /^Binary/;
            $val = substr($val,0x20) if length($val) > 0x20;
#            return \$val if $val =~ s/^.(\xd8\xff\xdb)/\xff$1/s;
            return \$val if $val =~ s/^.(\xd8\xff[\xdb\xe1])/\xff$1/s;
            $$self{PreviewError} = 1 unless $val eq 'none';
            return undef;
        },
        # must construct 0x20-byte header which contains length, width and height
        ValueConvInv => q{
            return 'none' unless $val;
            my $e = new Image::ExifTool;
            my $info = $e->ImageInfo(\$val,'ImageWidth','ImageHeight');
            return undef unless $$info{ImageWidth} and $$info{ImageHeight};
            my $size = Set32u($$info{ImageWidth}) . Set32u($$info{ImageHeight});
            return Set32u(length $val) . $size . ("\0" x 8) . $size . ("\0" x 4) . $val;
        },
    },
    0x2002 => { #JR (written by Sony IDC)
        Name => 'Rating',
        Writable => 'int32u', # (0-5 stars) (4294967295 for an HX9V iSweep Panorama, ref JR)
    },
    # 0x2003 - string[256]: all 0 for DSLR, SLT, NEX; data for DSC-HX9V
    0x2004 => { #PH (NEX-5)
        Name => 'Contrast',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2005 => { #PH (NEX-5)
        Name => 'Saturation',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2006 => { #PH
        Name => 'Sharpness',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2007 => { #PH
        Name => 'Brightness',
        Writable => 'int32s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x2008 => { #PH
        Name => 'LongExposureNoiseReduction',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'On (unused)',
            0x10001 => 'On (dark subtracted)', # (NEX-C3)
            0xffff0000 => 'Off (65535)',
            0xffff0001 => 'On (65535)',
            0xffffffff => 'n/a',
        },
    },
    0x2009 => { #PH
        Name => 'HighISONoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Normal',
            3 => 'High',
            256 => 'Auto',
            # it seems that all DSC models except DSC-RX models give n/a here (ref JR)
            65535 => 'n/a',
        },
    },
    0x200a => { #PH (A550)
        Name => 'HDR',
        Writable => 'int32u',
        Format => 'int16u',
        Count => 2,
        Notes => 'stored as a 32-bit integer, but read as two 16-bit integers',
        PrintHex => 1,
        PrintConv => [{
            0x0 => 'Off',
            0x01 => 'Auto',
            0x10 => '1.0 EV',
            0x11 => '1.5 EV',
            0x12 => '2.0 EV',
            0x13 => '2.5 EV',
            0x14 => '3.0 EV',
            0x15 => '3.5 EV',
            0x16 => '4.0 EV',
            0x17 => '4.5 EV',
            0x18 => '5.0 EV',
            0x19 => '5.5 EV',
            0x1a => '6.0 EV',
        },{ #JR (A580)
            0 => 'Uncorrected image',  # A580 stores 2 images: uncorrected and HDR
            1 => 'HDR image (good)',
            2 => 'HDR image (fail 1)', # alignment problem?
            3 => 'HDR image (fail 2)', # contrast problem?
        }],
    },
    0x200b => { #PH
        Name => 'MultiFrameNoiseReduction',
        Writable => 'int32u',
        Notes => 'may not be valid for RS100', # (RS100 sample was 0 when this feature was turned on)
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            255 => 'n/a',
        },
    },
    # 0x200c - int32u[3]: '0 0 0'; seen '2 1 0' for HX9V 3D-Image (in both JPG and MPO image)
    # 0x200d - rational64u: 10/10, seen 2.5 for DSC-TX300V, 8 for DSC-HX100V/RX10
    0x200e => { #PH (HX20V)
        Name => 'PictureEffect',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Toy Camera', #JR (A35)
            2 => 'Pop Color', # (also A35/NEX-C3, ref JR)
            3 => 'Posterization', #JR (A35)
            4 => 'Posterization B/W', #JR (A35)
            5 => 'Retro Photo', #JR (A35, NEX-5)
            6 => 'Soft High Key', # (also A65V, A35/NEX-C3 call this "High-key", ref JR)
            7 => 'Partial Color (red)', #JR (A35)
            8 => 'Partial Color (green)', #JR (A35, NEX-5)
            9 => 'Partial Color (blue)', #JR (A35)
            10 => 'Partial Color (yellow)', #JR (A35, NEX-5)
            13 => 'High Contrast Monochrome', #JR (A35)
            16 => 'Toy Camera (normal)', # (also A65, ref JR)
            17 => 'Toy Camera (cool)', # (RX100)
            18 => 'Toy Camera (warm)', # (RX100)
            19 => 'Toy Camera (green)', # (RX100)
            20 => 'Toy Camera (magenta)', # (RX100)
            32 => 'Soft Focus (low)', #JR (RX100)
            33 => 'Soft Focus', #JR (A65V)
            34 => 'Soft Focus (high)', # (RX100)
            48 => 'Miniature (auto)', #JR (A65V/NEX-7, horizontal)
            49 => 'Miniature (top)', # (RX100)
            50 => 'Miniature (middle horizontal)', # (WX100/HX20V, horizontal)
            51 => 'Miniature (bottom)', # (WX100, rotate 90 CW)
            52 => 'Miniature (left)', # (RX100)
            53 => 'Miniature (middle vertical)', # (RX100)
            54 => 'Miniature (right)', # (RX100)
            64 => 'HDR Painting (low)', # (RX100)
            65 => 'HDR Painting', # (also A65V, ref JR)
            66 => 'HDR Painting (high)', # (RX100)
            80 => 'Rich-tone Monochrome', # (also A65V, ref JR)
            97 => 'Water Color', # (HX200V)
            98 => 'Water Color 2',
            112 => 'Illustration (low)', # (RX100)
            113 => 'Illustration', # (RX100)
            114 => 'Illustration (high)', # (RX100)
        },
    },
    0x200f => { #PH (RX100)
        Name => 'SoftSkinEffect',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Mid',
            3 => 'High',
            # 0x10001 - seen (ref JR)
            # 0x10002 - seen for landscape and portrait flash (ref JR)
            0xffffffff => 'n/a', # (A35)
        },
    },
    0x2010 => [ #JR
        # different camera models have similar content but at different offsets, appears to correlate with:
        # 0x1206 - 0x1207 deciphered (0x1205 changes with firmware version):
        #   ad c3 - NEX-5N
        # 0x0192 - 0x0193 deciphered (0x0191 changes with firmware version):
        #   91 c3 - NEX-VG20E
        #   93 c3 - NEX-7, SLT-A65V/A77V
        #   94 c3 - Hasselblad Lunar
        # 0x0012 - 0x0013 deciphered (0x0011 changes with firmware version):
        #   94 c3 - SLT-A37/A57, NEX-F3
        #   95 d3 - DSC-WX50, WX70
        #   98 c3 - DSC-HX200V, HX20V, HX30V, TX200V, TX300V
        #   98 d3 - DSC-HX10V, TX66, WX100, WX150
        #   9a c3 - DSC-RX1, RX1R
        #   9b c3 - SLT-A99V, Hasselblad HV
        #   9c c3 - NEX-VG30E
        #   9d c3 - DSC-RX100, Hasselblad Stellar
        #   9e c3 - NEX-VG900, SLT-A58
        #   a1 d3 - DSC-TX30
        #   a2 d3 - DSC-WX60, WX80, WX200, WX300
        #   a3 c3 - NEX-6, DSC-HX300, HX50V
        #   a4 c3 - NEX-3N/5R/5T, ILCE-3000/3500
        # unknown offsets or values for DSC-TX20/TX55/WX30
        # unknown offsets or values for DSC-HX60V/HX400V/QX10/QX30/QX100/RX10/RX100M2/RX100M3/WX220/WX350,
        #                               ILCA-68/77M2, ILCE-5000/5100/6000/7/7M2/7R/7S/QX1
        # unknown offsets or values for DSC-HX90V/RX1RM2/RX10M2/RX10M3/RX100M4/WX500, ILCE-6300/7RM2/7SM2
    {
        Name => 'Tag2010a', # ad
        Condition => '$$self{Model} =~ /^NEX-5N$/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010a' },
    },{
        Name => 'Tag2010b', # 91, 93
        Condition => '$$self{Model} =~ /^(SLT-A(65|77)V?|NEX-(7|VG20E)|Lunar)$/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010b' },
    },{
        Name => 'Tag2010c', # 94
        Condition => '$$self{Model} =~ /^(SLT-A(37|57)|NEX-F3)$/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010c' },
    },{
        Name => 'Tag2010d', # 95, 98
        Condition => q{
            $$self{Model} =~ /^(DSC-(HX10V|HX20V|HX30V|HX200V|TX66|TX200V|TX300V|WX50|WX70|WX100|WX150))$/ and
            not $$self{Panorama}
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010d' },
    },{
        Name => 'Tag2010e', # 9a, 9b, 9c, 9d, 9e, a1, a2, a3, a4
        Condition => q{
            $$self{Model} =~ /^(SLT-A99V?|HV|SLT-A58|ILCE-(3000|3500)|NEX-(3N|5R|5T|6|VG900|VG30E)|DSC-(RX100|RX1|RX1R)|Stellar)$/ or
            ($$self{Model} =~ /^(DSC-(HX300|HX50V|TX30|WX60|WX80|WX200|WX300))$/ and not $$self{Panorama})
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010e' },
    },{
        Name => 'Tag2010f', # ?
        Condition => '$$self{Model} =~ /^(DSC-(RX100M2|QX10|QX100))$/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010f' },
    },{
        Name => 'Tag2010g', # ?
        Condition => '$$self{Model} =~ /^(DSC-(QX30|RX10|RX100M3|HX60V|HX400V|WX220|WX350)|ILCE-(7(R|S|M2)?|[56]000|5100|QX1)|ILCA-(68|77M2))\b/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010g' },
    },{
        Name => 'Tag2010h', # ?
        Condition => '$$self{Model} =~ /^(DSC-(RX1RM2|RX10M2|RX10M3|RX100M4|HX90V|WX500)|ILCE-(6300|7RM2|7SM2))\b/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag2010h' },
    },{
        Name => 'Tag_0x2010',
        %unknownCipherData,
    }],
    0x2011 => { #PH (A77, NEX-5N)
        Name => 'VignettingCorrection',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            2 => 'Auto',
            0xffffffff => 'n/a', # (RX100)
        },
    },
    0x2012 => { #PH (A77, NEX-5N)
        Name => 'LateralChromaticAberration',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            2 => 'Auto',
            0xffffffff => 'n/a', # (RX100)
        },
    },
    0x2013 => { #PH (A77, NEX-5N) ("Setting"; application of such correction is indicated in Tag9405 - ref JR)
        Name => 'DistortionCorrectionSetting',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            2 => 'Auto',
            0xffffffff => 'n/a', # (RX100)
        },
    },
    0x2014 => { #JR/9
        Name => 'WBShiftAB_GM',
        Writable => 'int32s',
        Count => 2,
        Notes => q{
            2 numbers: 1. positive is a shift toward amber, 2. positive is a shift
            toward magenta
        },
    },
    # 0x2015 - int16u: 65535, also for 'normal' HDR images; 0 for HDR-paint and high-contrast-BW effect images
    0x2016 => { #PH (RX100)
        Name => 'AutoPortraitFramed',
        Writable => 'int16u',
        Notes => '"Yes" if this image was created by the Auto Portrait Framing feature',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    # 0x2017 - int32u: flash mode. 0=off, 1=fired, 2=red-eye (PH, NEX-6) (also in A99, RX1, NEX-5R)
    0x2017 => { #JR
        Name => 'FlashAction',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Flash Fired',
            2 => 'External Flash Fired',
        },
    },
    # 0x2018 - something with external flash: seen 1 only when 0x2017 = 2
    # 0x2019 - 0 or 1 (seen 1 for ILCA-77M2, ILCE-7M2/7RM2)
    # 0x201a - 0 or 1
    0x201b => { #PH
        # FocusMode for SLT/HV/ILCA and NEX/ILCE; doesn't seem to apply to DSC models (always 0)
        Name => 'FocusMode',
        Condition => '$$self{Model} !~ /^DSC-/',
        Writable => 'int8u',
        Priority => 0,
        PrintConv => {
            0 => 'Manual',
            2 => 'AF-S',
            3 => 'AF-C',
            4 => 'AF-A',
            6 => 'DMF', # "Direct Manual Focus"
            7 => 'AF-D', # "Depth Map Assist Continuous AF"
        },
    },
    0x201c => [ #JR
        # AFAreaModeSetting for SLT/HV/ILCA and NEX/ILCE; doesn't seem to apply to DSC models (always 0)
        # all DSLR/SLT/HV         Wide  Zone Spot   Local
        # all NEX and ILCE-3000   Multi      Center FlexibleSpot
        # ILCE-7 and newer        Wide  Zone Center FlexibleSpot
        # ILCA-77M2 and newer     Wide  Zone Center FlexibleSpot
        # (actual AFAreaMode used may be different as camera can override this under certain conditions)
        {
            Name => 'AFAreaModeSetting',
            Condition => '$$self{Model} =~ /^(SLT-|HV)/',
            Notes => 'SLT models',
            Writable => 'int8u',
            PrintConv => {
                0 => 'Wide',
                4 => 'Local',
                8 => 'Zone', #PH
                9 => 'Spot',
            },
        },{
            Name => 'AFAreaModeSetting',
            Condition => '$$self{Model} =~ /^(NEX-|ILCE-)/',
            Notes => 'NEX and ILCE models',
            Writable => 'int8u',
            PrintConv => {
                0 => 'Multi', # all NEX and ILCE-3000/3500; all other ILCE use the name 'Wide'
                1 => 'Center',
                3 => 'Flexible Spot',
                11 => 'Zone',
                12 => 'Expanded Flexible Spot',
            },
        },{
            Name => 'AFAreaModeSetting',
            Condition => '$$self{Model} =~ /^ILCA-/',
            Notes => 'ILCA models',
            Writable => 'int8u',
            PrintConv => {
                0 => 'Wide',
                4 => 'Flexible Spot',
                8 => 'Zone',
                9 => 'Center',
                12 => 'Expanded Flexible Spot',
            },
        },
    ],
    0x201d => { #JR
        # Flexible Spot position for NEX/ILCE, non-zero only when AFAreaMode='Flexible Spot'
        # observed values in range (0 0) to (640 480), with center (320 240) often seen
        # for NEX-5R/6, positions appear to be in an 11x9 grid
        Name => 'FlexibleSpotPosition',
        Condition => '$$self{Model} =~ /^(NEX-|ILCE-)/',
        Writable => 'int16u',
        Count => 2,
        Notes => q{
            X and Y coordinates of the AF point, valid only when AFAreaMode is Flexible
            Spot
        },
    },
    0x201e => [{ #PH (A99)
        # AFPointSelected for SLT/HV/ILCA, non-zero only when AFAreaMode = 'Local' or 'Zone'
        # AFZoneSelected for NEX/ILCE, non-zero only when AFAreaMode = 'Zone',
        #      but also with Expanded Flexible Spot for ILCE-7RM2/7SM2 ...
        # doesn't seem to apply to DSC models (always 0)
        Name => 'AFPointSelected',
        Condition => '$$self{Model} =~ /^(SLT-|HV)/',
        Notes => 'SLT models',
        Writable => 'int8u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto', # (NC)
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
            10 => 'Far Right',
            11 => 'Far Left',
            12 => 'Upper-middle',
            13 => 'Near Right',
            14 => 'Lower-middle',
            15 => 'Near Left',
            16 => 'Upper Far Right',
            17 => 'Lower Far Right',
            18 => 'Lower Far Left',
            19 => 'Upper Far Left',
        },
    },{
        Name => 'AFPointSelected',
        Condition => '$$self{Model} =~ /^ILCA-/',
        Notes => 'ILCA models',
        Writable => 'int8u',
        ValueConv => '$val - 1', # to get the same numbers as from the BITMASK in 0x2020
        ValueConvInv => '$val + 1',
        PrintConvColumns => 3,
        PrintConv => {
            -1 => 'Auto',
            %afPoints79,
            39 => 'E6 (Center)', # (add " (Center)" to central point)
        },
    },{
        Name => 'AFZoneSelected', # each Zone has 3x3 AF Areas --> 9 positions within 5x5 total Contrast AF Areas
        # non-zero only when AFAreaMode is 'Zone', and 'Expanded-Flexible-Spot' for ILCE-6300/7RM2/7SM2
        Condition => '$$self{Model} =~ /^(NEX-|ILCE-)/',
        Notes => 'NEX and ILCE models',
        Writable => 'int8u',
        PrintConv => {
            0 => 'n/a',
            1 => 'Center',
            2 => 'Top',
            3 => 'Right',
            4 => 'Left',
            5 => 'Bottom',
            6 => 'Bottom Right',
            7 => 'Bottom Left',
            8 => 'Top Left',
            9 => 'Top Right',
        },
    }],
    # 0x201f - 0 0 0 0 for SLT and DSC; 4 values for NEX/ILCE with 4th value always 0:
    # possibly bits relating to the 25 AF-Contrast-areas ???
    # 0x2020 - 10 values; for SLT/ILCA and NEX/ILCE with A-mount lens: relates to (phase-detect) AFPoints
    0x2020 => [{
        Name => 'AFPointsUsed',
        Condition => '$$self{Model} !~ /^(ILCA-|DSC-)/', # (doesn't seem to apply to DSC-models)
        Notes => 'SLT models, or NEX/ILCE with A-mount lenses',
        BitsPerWord => 8,
        BitsTotal => 80,
        Notes => 'SLT models only',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Center',
                1 => 'Top',
                2 => 'Upper-right',
                3 => 'Right',
                4 => 'Lower-right',
                5 => 'Bottom',
                6 => 'Lower-left',
                7 => 'Left',
                8 => 'Upper-left',
                9 => 'Far Right',
                10 => 'Far Left',
                11 => 'Upper-middle',
                12 => 'Near Right',
                13 => 'Lower-middle',
                14 => 'Near Left',
                15 => 'Upper Far Right',
                16 => 'Lower Far Right',
                17 => 'Lower Far Left',
                18 => 'Upper Far Left',
            },
        },
    },{
        Name => 'AFPointsUsed',
        Condition => '$$self{Model} =~ /^ILCA-/',
        Notes => 'ILCA models',
        BitsPerWord => 8,
        BitsTotal => 80,
        PrintConv => {
            0 => '(none)',
            BITMASK => { %afPoints79 },
        },
    }],
    # 0x2021 - 0 for DSC; 0, 1 or 2 for SLT/ILCA and NEX/ILCE: 1=Face, 2=object-tracking ?
    # 0x2022 - 13 bytes (104 bits) for SLT-A58/A99V, NEX-3N/5R/5T/6/VG30E/VG900, ILCE-3000/3500/5000/7/7R
    #          26 bytes (208 bits) for ILCA-77M2, ILCE-5100/6000/7M2/7S/QX1 (7M2 has 117, 5100/6000 have 179 PhaseAFPoints)
    #          52 bytes (416 bits) for ILCE-7RM2 (which has 399 PhaseAFPoints) and ILCE-7SM2
    #          Only seen non-zero values for ILCE-5100/6000/7M2/7RM2 in AF-C mode: maybe FocalPlaneAFPointsUsed ???
    #          (Similar number of bytes for contemporary DSC models, but mostly all non-zero values.)
    #          ILCE-6300 does not write this tag anymore, but writes 0x202a ...
    0x2022 => [{
        Name => 'FocalPlaneAFPointsUsed',
        Condition => '$$self{Model} =~ /^(ILCE-(5100|6000|7M2))/',
        Notes => 'On-sensor/focal-plane phase AF points for ILCE with hybrid AF',
        BitsPerWord => 8,
        BitsTotal => 208, # 26 words
        PrintConv => {
            0 => '(none)',
            BITMASK => { },
        },
    },{
        Name => 'FocalPlaneAFPointsUsed',
        Condition => '$$self{Model} =~ /^ILCE-7RM2/',
        # ILCE-7RM2 has 399 points in 19 rows of 21 points, numbered [0] to [398], [199] is Center
        BitsPerWord => 8,
        BitsTotal => 416, # 52 words
        PrintConv => {
            0 => '(none)',
            BITMASK => { },
        },
    }],
    # 0x2023 - 0
    # 0x2024 - 96 byte data block, very similar to 0x3000 ShotInfo, seen in Xperia Z5
    # 0x2025 - n1 n2 0 0         DSC-RX100M3/RX100M4/RX10M2/HX90V/WX500, ILCA-77M2, ILCE-5100/7M2/7RM2/7S/QX1
    #          seen n1=0,2,4,5,7 and n2=0,1,3, very often: 7 3 0 0

    # 0x2026 - 2 values: more precise WB Shift: AB in steps of 0.50, GM in steps of 0.25 (ILCE-7RM2 onwards)
    0x2026 => { #JR
        Name => 'WBShiftAB_GM_Precise',
        Writable => 'int32s',
        Count => 2,
        Notes => q{
            2 numbers: 1. positive is a shift toward amber, 2. positive is a shift
            toward magenta
        },
        PrintConv => 'my @v=split(" ",$val); $_/=1000 foreach @v; sprintf("%.2f %.2f",$v[0],$v[1])',
    },
    # 0x2027 - W H W/2 H/2  or  W H val1 val2  (0 0 0 0 for Panorama images)
    #          Probably location of focus for Playback Zoom.
    #          Origin appears to be top-left, i.e. 1st coord to the right, 2nd coord. pointing down.
    0x2027 => { #JR
        Name => 'FocusLocation', #(NC)
        Writable => 'int16u',
        Count => 4,
        NOTES => q{
            Location in the image where the camera focused, used for Playback Zoom.
            If the focus location information cannot be obtained, the centre of the
            image will be used.
        },
    },
    # 0x2028 - 0 0 for DSC-RX100M4/RX10M2, ILCE-7RM2/7SM2; seen non-zero values only for DSC-RX1RM2
    0x2028 => { #JR
        Name => 'VariableLowPassFilter',
        Format => 'int32u',
        PrintConv => {
            0x00000 => 'n/a',
            0x00001 => 'Off',
            0x10001 => 'Standard',
            0x20001 => 'High',
        },
    },
    0x2029 => { # uncompressed 14-bit RAW file type setting introduced 2015
        Name => 'RAWFileType',
        Format => 'int16u',
        PrintConv => {
            0 => 'Compressed RAW',
            1 => 'Uncompressed RAW',
        },
    },
    # 0x202a - first seen for ILCE-6300: 66 bytes
    #          possibly a 'replacement' for Tag2022 FocalPlaneAFPointsUsed,
    #          but now indicating locations in a 640x428 grid (3:2 part of LCD ?)
    # first byte value 1 for ILCE-6300
    #            values 110,137, ... for DSC-RX10M3, therefore limit to first byte = 1 for now
    0x202a => {
        Name => 'Tag202a',
        Condition => '$$valPt =~ /^\x01/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag202a' },
    },
    0x3000 => {
        Name => 'ShotInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::ShotInfo' },
    },
    # 0x3000: data block that includes DateTimeOriginal string
    # 0x5001 - 0
    # 0x5002 - 128
#
# at least some data for tags 0x2010, 0x9050 and 0x94xx is encrypted - PH
# (This is certainly true for at least parts of 0x2010, 0x9050, 0x9400, 0x9402 and 0x9403,
# but hasn't been verified for other tags -- just to be thorough, decipher all of them)
# Note: "(e)" in a comment indicates an enciphered value, all other values are deciphered
#
    # 0x900b - 1st byte 0xae: face detection info for A450/500/550/560/580, A33/35/55, NEX-3/5/5C/C3/VG10
    #        - other 1st byte values for some DSC-models
    #        - seen many 1,8,27,64... values: assume encrypted like other 9xxx tags
    0x900b => {
        Name => 'Tag900b',
        Condition => '$$valPt =~ /^\xae/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag900b' },
    },
    0x9050 => {
        Name => 'Tag9050',
        # 944 bytes for A37, A57, A99, NEX-F3, NEX-5R, NEX-6, DSC-RX1, DSC-RX100
        # 3072 bytes for A65, A77, NEX-5N, NEX-7, NEX-VG20 (ref JR)
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::Tag9050',
            ByteOrder => 'LittleEndian',
        },
    },
    0x9400 => [
    # first byte:
    # 0x07 (e) for DSC-HX7V/HX9V/HX100V/TX10/TX100/TX100V/WX7/WX9/WX10, HDR-CX../PJ..
    # 0x09 (e) for DSC-TX20/TX55/WX30
    # 0x0a (e) for SLT-A37/A57/A65V/A77V/A99V, NEX-F3/5N/5R/5T/6/7/VG20E, DSC-RX100/RX1/RX1R/HX10V/HX20V/HX30V/HX200V/TX200V/TX300V/TX66/WX50/WX100/WX150, Lunar/Stellar/HV
    # 0x0c (e) for ILCE-3000/3500, NEX-3N, SLT-A58, DSC-HX50V/HX300/RX100M2/TX30/WX60/WX80/WX200/WX300, DSC-QX10/QX100
    # 0xd0 (e) H90, W650, W690: tag9400 decoding appears not valid/different
    # 0x23 (e) for DSC-RX10/HX60V/HX400V/WX220/WX350, ILCE-7/7R/5000/6000, ILCA-68/77M2
    # 0x24 (e) for ILCE-5100/6300/7M2/7RM2/7S/7SM2/QX1, DSC-HX90V/QX30/RX100M3/RX100M4/RX10M2/RX10M3/RX1RM2/WX500
    # first byte decoded: 40, 204, 202, 27, 58, 62, 48 respectively
    {
        Name => 'Tag9400a',
        Condition => q{
            $$valPt =~ /^[\x07\x09\x0a]/ or
           ($$valPt =~ /^[\x5e\xe7\x04]/ and $$self{DoubleCipher} = 1)
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9400a' },
    },{
        Name => 'Tag9400b',
        Condition => '$$valPt =~ /^\x0c/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9400b' },
    },{
        Name => 'Tag9400c',
        Condition => '$$valPt =~ /^[\x23\x24]/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9400c' },
    },{
        Name => 'Sony_0x9400',
        %unknownCipherData,
    }],
    0x9401 => {
        Name => 'Sony_0x9401',
        %unknownCipherData,
        # notes for data in this block (ref PH/JR):
        #   0x02-0x03 appear to have some relation to start-offset of data...
        #   0x00 - 0x03    Metering
        #                  Mode
        #   f4 00 00 03      -        -   DSC-H90/W650/W690
        #   cf 0b 9f 0f    0x09bc    (a)  DSC-WX9
        #   1c 00 ac 0f    0x09c9    (b)  HDR-CX130E/CX160E/CX360E/CX560E/CX700E/PJ10E/PJ30E
        #   b7 0f f7 0f    0x09dd    (c)  DSC-HX7V/TX10/WX7/WX10
        #   b7 0f fa 0f    0x09e0    (d)  DSC-HX9V/HX100V/TX100/TX100V
        #   27 00 fd 0f    0x09e7    (e)  DSC-TX20/TX55/WX30
        #   69 1f ff 0f    0x09e9    (f)  NEX-5N
        #   21 2b cf 0f    0x09e9    (f)  NEX-7/VG20E, SLT-A65V/A77V, Lunar
        #   2d 00 d5 0d    0x09a2    (g)  DSC-HX10V/HX20V/HX30V/HX200V/TX66/TX200V/TX300V/WX50/WX70/WX100/WX150
        #   2f 00 d6 0d    0x09a3    (h)  NEX-F3, SLT-A37/A57
        #   30 00 d8 0d    0x09a5    (i)  HDR-AS15
        #   32 00 e2 0d    0x09ac    (j)  DSC-RX100, Stellar
        #   33 00 e2 0d    0x09ac    (j)  NEX-5R/5T/6, NEX-VG900/VG30E
        #   33 50 e2 0d    0x09ac    (j)  SLT-A99V, HV
        #   33 40 0d 0e    0x09d7    (k)  DSC-RX1 v0.01
        #   33 41 0d 0e    0x09d7    (k)  DSC-RX1, DSC-RX1R
        #   38 00 32 0e    0x09fc    (l)  SLT-A58, ILCE-3000/3500, NEX-3N, DSC-HX300/HX50V/WX200/WX300/WX60/WX80/TX30
        #   3a 10 3a 0e    0x0a01    (m)  DSC-QX10/QX100
        #   3a 20 47 0e    0x0a01    (m)  DSC-RX100M2
        #   43 00 66 0e    0x0a1b    (n)  ILCE-7/7R v0.xx/v1.00/v1.01, ILCE-5000, DSC-RX10
        #   43 10 66 0e    0x0a1b    (n)  ILCE-7/7R v1.02/v1.10
        #   43 30 6c 0e    0x0a1b    (n)  ILCE-7/7R v1.20/v2.00
        #   44 00 9c 0e    0x0a39    (o)  ILCE-6000 v1.00/v1.10, DSC-HX60V/HX400V/WX220/WX350 (also DSC-QX30 samples from sony.net)
        #   49 00 b0 0e    0x0a3b    (p)  ILCA-68 v1.00, ILCA-77M2 V1.00/v1.01/v2.00 (also DSC-RX100M3 samples from sony.net)
        #   4a 00 b3 0e    0x0a3d    (q)  ILCE-7S v1.00, ILCE-5100 v1.00/v1.10, ILCE-QX1, DSC-QX30/RX100M3
        #   4a 20 b9 0e    0x0a3d    (q)  ILCE-7S v1.20/v2.00
        #   4e 10 d0 0e    0x0a5a    (r)  ILCE-7M2 v1.00/v1.10
        #   4e 30 d6 0e    0x0a5a    (r)  ILCE-7M2 v1.20/v1.21/v2.00
        #   5a 00 14 0f    0x0a85    (s)  DSC-HX90V/WX500
        #   5d 00 56 0f    0x0ac7    (t)  DSC-RX10M2/RX100M4, ILCE-7RM2/7SM2 v1.00/v1.10/v2.00 (also DSC-RX1RM2 samples from Sony)
        #   5d 1d 58 0f    0x0ac7    (t)  ILCE-7RM2 v3.00/v3.05
        #   5d 1e 57 0f    0x0ac7    (t)  DSC-RX1RM2 v1.00
        #   5d 10 56 0f    0x0ac7    (t)  ILCE-6300 v1.00 (samples from Sony)
        #   5d 20 58 0f    0x0ac7    (t)  ILCE-6300 v1.00
        #   5e 00 56 0f    0x0ac7    (t)  DSC-RX10M3 v1.00
        #
        # 0x0004 - (RX100: 0 or 1. subsequent data valid only if 1 - PH)
        # 0x0007 => {
        #     Name => 'DynamicRangeOptimizer_9401',
        #     PrintConv => {
        #         0 => 'Disabled', # seen for Panorama images
        #         1 => 'Auto',
        #         3 => 'Lv1', #NC
        #         4 => 'Lv2', #NC
        #         5 => 'Lv3',
        #         6 => 'Lv4',
        #         7 => 'Lv5',
        #         # 8 - seen for VG20E and some other models - PH
        #         255 => 'Off',
        #     },
        # },
    },
    0x9402 => [{
        Name => 'Tag9402',
        # first 2 bytes deciphered:
        #   0x00      0x00     SLT-A37/A57/A65/A77
        #   0x0e      0x00     DSC-H90/HX7V/HX9V/HX100V/TX10/TX100/TX100V/TX20/TX55/W650/W690/W730/WX10/WX30/WX7/WX9, but also seen:
        #     0x0e      0x01     for a few DSC-W650/W690 samples ...
        #   0x0f      0x01     NEX-5N/7/VG20, Lunar
        #   0x10      0x01     DSC-HX10V/HX200V/HX20V/HX300/HX30V/HX50V/TX200V/TX30/TX300V/TX66/RX100/RX1/RX1R/WX100/WX150/WX200/WX300/WX50/WX60/WX70/WX80, Stellar,
        #                      ILCE-3000/3500, NEX-F3/3N/5R/5T/6/VG30/VG900
        #   0x11      0x01     DSC-RX100M2/QX10/QX100
        #   0x13      0x01     ILCE-5000/7/7R, DSC-RX10, but also seen:
        #     0x12      0x01     for ILCE-7/7R and DSC-RX10 samples from Sony.net ...
        #     0x15      0x01     for a few ILCE-7/7R ...
        #   0x14      0x01     ILCE-6000, DSC-HX60V/HX400V/WX220/WX350
        #   0x17      0x01     ILCE-7S/7M2/5100/QX1, DSC-QX30/RX100M3
        #   0x19      0x01     DSC-HX90V/RX1RM2/RX10M2/RX100M4/WX500, ILCE-6300/7RM2/7SM2
        #   0x1a      0x01     DSC-RX10M3
        #   var       var      SLT-A58/A99V, HV, ILCA-68/77M2
        # only valid when first byte 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x17, 0x19, 0x1a (enciphered 0x8a, 0x70, 0xb6, 0x69, 0x88, 0x20, 0x30, 0xd7, 0xbb, 0x92)
        Condition => '$$self{DoubleCipher} ? $$valPt =~ /^[\x7e\x46\x1d\x18\x3a\x95\x24\x26\xd6]\x01/ : $$valPt =~ /^[\x8a\x70\xb6\x69\x88\x20\x30\xd7\xbb\x92]\x01/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9402' },
    },{
        Name => 'Sony_0x9402',
        %unknownCipherData,
    }],
    0x9403 => {
        Name => 'Tag9403',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9403' },
    },
    # 0x9404 first 5 bytes (deciphered):
    #  4  0  163  1  2     SLT-A65V/A77V, NEX-5N/7, Lunar, DSC-HX7V/HX9V/HX100V/TX10/TX20/TX55/TX100/TX100V/WX9/WX10/WX30...
    #  5  0  172  1  2     DSC-HX10V/HX200V/HX20V/HX30V/TX66/TX200V/TX300V/WX50/WX70/WX100/WX150...
    #  9  0   38  2  2     SLT-A37/A57/A99V, NEX-5R/5T/6/F3/VG30E/VG900, DSC-RX1/RX1R/RX100, Stellar
    # 12  0    8  2  2     SLT-A58, NEX-3N, ILCE-3000/3500, DSC-HX300/HX50V/WX60/WX80/WX300/TX30...
    # 13  0    9  2  2     DSC-QX10/QX100/RX100M2
    # 15  0   35  2  2     ILCA-68/77M2, ILCE-5000/5100/6000/7/7R/7S/7M2/QX1, DSC-HX400V/HX60V/QX30/RX10/RX100M3/WX220/WX350
    # 16  0   85  2  2     DSC-HX90V/WX500
    # 17  0  232  1  2     DSC-RX1RM2/RX10M2/RX10M3/RX100M4, ILCE-6300/7RM2/7SM2
    # other values for Panorama images and several other models
    0x9404 => [{
        Name => 'Tag9404a',
        # first byte must be 4 or 5 and 4th byte must be 1 (deciphered)
        Condition => '$$valPt =~ /^[\x40\x7d]..\x01/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9404a' },
    },{
        Name => 'Tag9404b',
        # first byte must be 9 or 12 or 13 or 15 or 16 and 4th byte must be 2 (deciphered)
        Condition => '$$valPt =~ /^[\xe7\xea\xcd\x8a\x70]..\x08/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9404b' },
    },{
        Name => 'Sony_0x9404',
        %unknownCipherData,
    }],
    # 0x9405 first 2 bytes:
    #   0   0  (0x00 =   0   0 enc.) DSC-H90
    #   2   0  (0x08 =   8   0 enc.) DSC and HDR of HX9V generation
    #   3   0  (0x1b =  27   0 enc.) SLT, NEX, ILCE-3000/3500, DSC-RX100/RX1 + other DSC of same generation, also QX10 and QX100
    #   4   0  (0x40 =  64   0 enc.) DSC-RX1R
    #   5   0  (0x7d = 125   0 enc.) DSC-RX100M2
    # 136 var  (0x3a =  58 var enc.) ILCE-7/7R/5000/6000, DSC-HX400V/HX60V/RX10/WX220/WX350
    # 137 var  (0xb3 = 179 var enc.) ILCA-68/77M2, DSC-RX100M3 - appears to go with 136
    # 138 var  (0x7e = 126 var enc.) ILCE-7S/5100/QX1, DSC-QX30   - appears to go with 136
    # 139 var  (0x9a = 154 var enc.) ILCE-7M2
    # 142 var  (0x25 =  37 var enc.) DSC-HX90V/RX1RM2/RX10M2/RX10M3/RX100M4/WX500, ILCE-6300/7RM2/7SM2
    0x9405 => [{
        Name => 'Tag9405a',
        # first byte must be 0x1b or 0x40 or 0x7d
        Condition => '$$valPt =~ /^[\x1b\x40\x7d]/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9405a' },
    },{
        Name => 'Tag9405b',
        # first byte must be 0x3a, 0xb3, 0x7e, 0x9a or 0x25
        Condition => '$$valPt =~ /^[\x3a\xb3\x7e\x9a\x25]/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9405b' },
    },{
        Name => 'Sony_0x9405',
        %unknownCipherData,
    }],
    0x9406 => [{
        Name => 'Tag9406',
        # - first byte must be 0x01 or 0x02 (enciphered 0x01 or 0x08), or 0x03 (enc. 0x1b) for ILCE-6300/7RM2/7SM2, and
        #   third byte must be 0x02 or 0x03 (enciphered 0x08 or 0x1b) - ref JR
        # (applies to most SLT and NEX models, but no DSC models)
        Condition => '$$valPt =~ /^[\x01\x08\x1b].[\x08\x1b]/s',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag9406' },
    },{
        Name => 'Sony_0x9406',
        %unknownCipherData,
    }],
    0x9407 => {
        Name => 'Sony_0x9407',
        %unknownCipherData,
    },
    0x9408 => {
        Name => 'Sony_0x9408',
        %unknownCipherData,
    },
    0x9409 => {
        Name => 'Sony_0x9409',
        %unknownCipherData,
    },
    0x940a => [{
        Name => 'Tag940a',
        Condition => '$$self{Model} =~ /^(SLT-|HV)/', # but appears not valid for ILCA models ...
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag940a' },
    },{
        Name => 'Sony_0x940a',
        %unknownCipherData,
    }],
    0x940b => {
        Name => 'Sony_0x940b',
        %unknownCipherData,
    },
    0x940c => [{
        Name => 'Tag940c',
        Condition => '$$self{Model} =~ /^(NEX-|ILCE-|Lunar)\b/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag940c' },
    },{
        Name => 'Sony_0x940c',
        %unknownCipherData,
    }],
    0x940d => {
        Name => 'Sony_0x940d',
        %unknownCipherData,
    },
#   0x940e: 2nd byte = 0: no AFInfo, default for NEX/ILCE
#           2nd byte = 1: AFInfo for SLT/ILCA models (but also seen 1 for DSC-HX20W/HX300/WX70 ...)
#           2nd byte = 2: AFInfo for NEX/ILCE with LA-EA2/EA4 Phase-detect AF Adapter
    0x940e => [{
        Name => 'AFInfo',
        Condition => '$$self{Model} =~ /^(SLT-|HV|ILCA-)/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::AFInfo' },
    },{
        Name => 'Tag940e',
        Condition => '$$self{Model} =~ /^(NEX-|ILCE-|Lunar)/',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Tag940e' },
    },{
        Name => 'Sony_0x940e',
        %unknownCipherData,
    }],
    0x940f => {
        Name => 'Sony_0x940f',
        %unknownCipherData,
    },
    0x9411 => {
        Name => 'Sony_0x9411',
        %unknownCipherData,
        # 0x02 - int32u?: 1,3,5,7,9 (A77)
    },
    0xb000 => { #8
        Name => 'FileFormat',
        Writable => 'int8u',
        Count => 4,
        # dynamically set the file type to SR2 because we could have assumed ARW up till now
        RawConv => q{
            $self->OverrideFileType($$self{TIFF_TYPE} = 'SR2') if $val eq '1 0 0 0';
            return $val;
        },
        PrintConvColumns => 2,
        PrintConv => {
            '0 0 0 2' => 'JPEG',
            '1 0 0 0' => 'SR2',
            '2 0 0 0' => 'ARW 1.0',
            '3 0 0 0' => 'ARW 2.0',
            '3 1 0 0' => 'ARW 2.1',
            '3 2 0 0' => 'ARW 2.2', #PH (NEX-5)
            '3 3 0 0' => 'ARW 2.3', #PH (SLT-A65,SLT-A77)
            '3 3 1 0' => 'ARW 2.3.1', #PH/JR (DSC-RX1R/RX100M2)
            '3 3 2 0' => 'ARW 2.3.2', #JR (DSC-RX1RM2,ILCE-7SM2 - support for uncompressed 14-bit RAW)
            # what about cRAW images?
        },
    },
    0xb001 => { # ref http://forums.dpreview.com/forums/read.asp?forum=1037&message=33609644
        # (ARW and SR2 images only until the SLT-A65V started writing them to JPEG too)
        Name => 'SonyModelID',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            2 => 'DSC-R1',
            256 => 'DSLR-A100',
            257 => 'DSLR-A900',
            258 => 'DSLR-A700',
            259 => 'DSLR-A200',
            260 => 'DSLR-A350',
            261 => 'DSLR-A300',
            262 => 'DSLR-A900 (APS-C mode)', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3994.0.html
            263 => 'DSLR-A380/A390', #PH (A390)
            264 => 'DSLR-A330',
            265 => 'DSLR-A230',
            266 => 'DSLR-A290', #PH
            269 => 'DSLR-A850',
            270 => 'DSLR-A850 (APS-C mode)', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3994.0.html
            273 => 'DSLR-A550',
            274 => 'DSLR-A500', #PH
            275 => 'DSLR-A450', #http://dev.exiv2.org/issues/show/0000611
            278 => 'NEX-5', #PH
            279 => 'NEX-3', #PH
            280 => 'SLT-A33', #PH
            281 => 'SLT-A55 / SLT-A55V', #PH (A55 NC)
            282 => 'DSLR-A560', #PH
            283 => 'DSLR-A580', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2881.0.html
            284 => 'NEX-C3', #PH
            285 => 'SLT-A35', #JR
            286 => 'SLT-A65 / SLT-A65V', #PH
            287 => 'SLT-A77 / SLT-A77V', #PH
            288 => 'NEX-5N', #PH
            289 => 'NEX-7', #PH (also Hasselblad Lunar, ref JR)
            290 => 'NEX-VG20E', #JR
            291 => 'SLT-A37', #JR
            292 => 'SLT-A57', #JR
            293 => 'NEX-F3', #PH
            294 => 'SLT-A99 / SLT-A99V', #JR (also Hasselblad HV)
            295 => 'NEX-6', #JR
            296 => 'NEX-5R', #JR
            297 => 'DSC-RX100', #PH (also Hasselblad Stellar, ref JR)
            298 => 'DSC-RX1', #JR
            299 => 'NEX-VG900', #JR
            300 => 'NEX-VG30E', #JR
            302 => 'ILCE-3000 / ILCE-3500', #JR
            303 => 'SLT-A58', #JR
            305 => 'NEX-3N', #PH
            306 => 'ILCE-7', #JR
            307 => 'NEX-5T', #JR
            308 => 'DSC-RX100M2', #JR
            309 => 'DSC-RX10', #JR
            310 => 'DSC-RX1R', #JR
            311 => 'ILCE-7R', #JR
            312 => 'ILCE-6000', #JR
            313 => 'ILCE-5000', #JR
            317 => 'DSC-RX100M3', #JR
            318 => 'ILCE-7S', #JR
            319 => 'ILCA-77M2', #IB
            339 => 'ILCE-5100', #JR
            340 => 'ILCE-7M2', #JR
            341 => 'DSC-RX100M4', #PH
            342 => 'DSC-RX10M2', #JR
            344 => 'DSC-RX1RM2', #JR
            346 => 'ILCE-QX1', #IB
            347 => 'ILCE-7RM2', #JR
            350 => 'ILCE-7SM2', #JR
            353 => 'ILCA-68', #IB
            355 => 'DSC-RX10M3', #PH
            357 => 'ILCE-6300', #IB
        },
    },
    0xb020 => { #2
        Name => 'CreativeStyle',
        Writable => 'string',
        # (all of these values have been observed, ref JR and PH)
        # - this PrintConv is included to make these strings consistent with
        #   other CreativeStyle tags, and to facilitate the language translations
        # - these values are always English, regardless of the camera language settings
        PrintConv => {
            OTHER => sub { shift }, # pass other values straight through
            None        => 'None',
            AdobeRGB    => 'Adobe RGB',
            Real        => 'Real',
            Standard    => 'Standard',
            Vivid       => 'Vivid',
            Portrait    => 'Portrait',
            Landscape   => 'Landscape',
            Sunset      => 'Sunset',
            Nightview   => 'Night View/Portrait',
            BW          => 'B&W',
            Neutral     => 'Neutral',
            Clear       => 'Clear',
            Deep        => 'Deep',
            Light       => 'Light',
            Autumnleaves=> 'Autumn Leaves',
            Sepia       => 'Sepia',
        },
    },
    0xb021 => { #2
        Name => 'ColorTemperature',
        Writable => 'int32u',
        PrintConv => '$val ? ($val==0xffffffff ? "n/a" : $val) : "Auto"',
        PrintConvInv => '$val=~/Auto/i ? 0 : ($val eq "n/a" ? 0xffffffff : $val)',
    },
    0xb022 => { #7
        Name => 'ColorCompensationFilter',
        Format => 'int32s',
        Writable => 'int32u', # (written incorrectly as unsigned by Sony)
        Notes => 'negative is green, positive is magenta',
    },
    0xb023 => { #PH (A100) - (set by mode dial)
        Name => 'SceneMode',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => \%Image::ExifTool::Minolta::minoltaSceneMode,
    },
    0xb024 => { #PH (A100)
        Name => 'ZoneMatching',
        Writable => 'int32u',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    0xb025 => { #PH (A100)
        Name => 'DynamicRangeOptimizer',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Auto', # (A550)
            8 => 'Advanced Lv1', #JD
            9 => 'Advanced Lv2', #JD
            10 => 'Advanced Lv3', #JD
            11 => 'Advanced Lv4', #JD
            12 => 'Advanced Lv5', #JD
            16 => 'Lv1', # (NEX-5)
            17 => 'Lv2',
            18 => 'Lv3',
            19 => 'Lv4',
            20 => 'Lv5',
        },
    },
    0xb026 => { #PH (A100)
        Name => 'ImageStabilization',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            0xffffffff => 'n/a', # (HX9V sweep panorama, ref JR)
        },
    },
    0xb027 => { #2
        Name => 'LensType',
        Writable => 'int32u',
        SeparateTable => 1,
        # set to 65535 for E-mount lenses (values 0x80xx)
        ValueConvInv => '($val & 0xff00) == 0x8000 ? 65535 : int($val)',
        PrintConv => \%sonyLensTypes,
    },
    0xb028 => { #2
        # (used by the DSLR-A100)
        Name => 'MinoltaMakerNote',
        # must check for zero since apparently a value of zero indicates the IFD doesn't exist
        # (dumb Sony -- they shouldn't write this tag if the IFD is missing!)
        Condition => '$$valPt ne "\0\0\0\0"',
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::Main',
            Start => '$val',
        },
    },
    0xb029 => { #2 (set by creative style menu)
        Name => 'ColorMode',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => \%Image::ExifTool::Minolta::sonyColorMode,
    },
    0xb02a => {
        Name => 'LensSpec',
        Format => 'undef',
        Writable => 'int8u',
        Count => 8,
        Notes => q{
            like LensInfo, but also specifies lens features: DT, E, ZA, G, SSM, SAM,
            OSS, STF, Reflex, Macro and Fisheye
        },
        ValueConv => \&ConvLensSpec,
        ValueConvInv => \&ConvInvLensSpec,
        PrintConv => \&PrintLensSpec,
        PrintConvInv => \&PrintInvLensSpec,
    },
    0xb02b => { #PH (A550 JPEG and A200, A230, A300, A350, A380, A700 and A900 ARW)
        Name => 'FullImageSize',
        Writable => 'int32u',
        Count => 2,
        # values stored height first, so swap to get "width height"
        ValueConv => 'join(" ", reverse split(" ", $val))',
        ValueConvInv => 'join(" ", reverse split(" ", $val))',
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0xb02c => { #PH (A550 JPEG and A200, A230, A300, A350, A380, A700 and A900 ARW)
        Name => 'PreviewImageSize',
        Writable => 'int32u',
        Count => 2,
        ValueConv => 'join(" ", reverse split(" ", $val))',
        ValueConvInv => 'join(" ", reverse split(" ", $val))',
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0xb040 => { #2
        Name => 'Macro',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Close Focus', #9
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb041 => { #2
        Name => 'ExposureMode',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Program AE', # (RX100 'Program','Sunset' - PH)
            1 => 'Portrait', #PH (HX1)
            2 => 'Beach', #9
            3 => 'Sports', #9
            4 => 'Snow', #9
            5 => 'Landscape',
            6 => 'Auto', # (RX100 'Intelligent Auto' - PH)
            7 => 'Aperture-priority AE',
            8 => 'Shutter speed priority AE',
            9 => 'Night Scene / Twilight',#2/9
            10 => 'Hi-Speed Shutter', #9
            11 => 'Twilight Portrait', #9 (RX100 'Night Portrait' - PH)
            12 => 'Soft Snap/Portrait', #9 (TX7 'Soft Snap'; RX100/A37 'Portrait' but manuals say "reproduces soft skin tone" - PH)
            13 => 'Fireworks', #9
            14 => 'Smile Shutter', #9 (T200)
            15 => 'Manual',
            18 => 'High Sensitivity', #9
            19 => 'Macro', #JR
            20 => 'Advanced Sports Shooting', #9
            29 => 'Underwater', #9
            # 30 seen for DSC-W110 and W390, maybe something with Face or Portrait ??
            33 => 'Food', #9
            34 => 'Sweep Panorama', #PH (HX1)
            35 => 'Handheld Night Shot', #PH (HX1/TX1, also called "Hand-held Twilight")
            36 => 'Anti Motion Blur', #PH (TX1)
            37 => 'Pet', #9
            38 => 'Backlight Correction HDR', #9
            39 => 'Superior Auto', #9
            40 => 'Background Defocus', #PH (HX20V)
            41 => 'Soft Skin', #JR (HX9V) (HX200V Portrait - PH)
            42 => '3D Image', #JR (HX9V)
            # 50 seen for DSC-W530
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb042 => { #9
        Name => 'FocusMode',
        # Only FocusMode for older DSC models;
        # Newest DSC models give only 0, many models of 'HX9V generation' give only 4 -
        # these models give FocusMode in tag 0xb04e, and are excluded here.
        Condition => q{
            ($$self{TagB042} = Get16u($valPt, 0)) and
            (not $$self{MetaVersion} or $$self{MetaVersion} ne 'DC7303320222000')
        },
        Notes => 'not valid for all models',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            # 0 - seen this for panorama shot
            1 => 'AF-S', # (called Single-AF by Sony)
            2 => 'AF-C', # (called Monitor-AF by Sony)
            4 => 'Permanent-AF', # (TX7,HX9V?)
            65535 => 'n/a', #PH (A100), also for DSC-W690 panorama shots
        },
    },
    0xb043 => [{ #9
        Name => 'AFAreaMode',
        # AFAreaMode only for older models;
        # exclude newest DSC models, which give AFAreaMode in Tag9402 0x0017 (eg. RX100 - PH)
        Writable => 'int16u',
        Condition => 'not $$self{MetaVersion} or $$self{MetaVersion} ne "DC7303320222000"', #JR
        RawConv => '$val == 65535 ? undef : $val',
        Notes => 'older models',
        PrintConv => {
            # 0 - (takes this value after camera reset, but can't be set back once changed)
            0 => 'Default',
            1 => 'Multi',
            2 => 'Center',
            3 => 'Spot',
            4 => 'Flexible Spot', # (T200)
            6 => 'Touch',
            14 => 'Tracking', #JR (HX9V) ("Manual" for the T200?, ref 9)
            15 => 'Face Tracking', # (not set when in face detect mode and no faces detected)
            65535 => 'n/a', #PH (A100)
        },
    },{ #JR
        Name => 'AFAreaMode',
        # AFAreaMode for DSC-HX9V generation, having values that appear to be different from older models.
        Writable => 'int16u',
        Condition => '$$self{TagB042} and $$self{TagB042} != 0',
        Notes => 'DSC-HX9V generation cameras',
        PrintConv => {
            0 => 'Multi',
            1 => 'Center',
            2 => 'Spot', # (NC) seen for DSC-WX9
            3 => 'Flexible Spot',
            10 => 'Selective (for Miniature effect)', # seen for Miniature effect of DSC-WX30
            14 => 'Tracking',
            15 => 'Face Tracking',
            255 => 'Manual',
        },
    }],
    0xb044 => { #9
        Name => 'AFIlluminator',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            65535 => 'n/a', #PH (A100)
        },
    },
    # 0xb045 - int16u: 0
    # 0xb046 - int16u: 0
    0xb047 => { #2
        Name => 'JPEGQuality',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Standard',
            1 => 'Fine',
            2 => 'Extra Fine', #JR
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb048 => { #9
        Name => 'FlashLevel',  #JR other name, but values -9 to 9 match FlashExposureCompensation
        Writable => 'int16s',
        RawConv => '($val == -1 and $$self{Model} =~ /DSLR-A100\b/) ? undef : $val',
        PrintConv => {
            -32768 => 'Low',
            -9 => '-9/3', #JR
            -6 => '-6/3', #JR
            -5 => '-5/3', #JR
            -4 => '-4/3', #JR
            -3 => '-3/3',
            -2 => '-2/3',
            -1 => '-1/3', # (for the A100, -1 is effectively 'n/a' - PH)
            0 => 'Normal',
            1 => '+1/3',
            2 => '+2/3',
            3 => '+3/3',
            4 => '+4/3', #JR (NC)
            5 => '+5/3', #JR (NC)
            6 => '+6/3', #JR
            128 => 'n/a', #JR (HX9V)
            32767 => 'High',
        },
    },
    0xb049 => { #9
        Name => 'ReleaseMode',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Normal', # (ie. shutter button)
            2 => 'Continuous',
            5 => 'Exposure Bracketing',
            6 => 'White Balance Bracketing', # (HX5)
            8 => 'DRO Bracketing', #JR (ILCE-7RM2)
            65535 => 'n/a', #PH (A100)
        },
    },
    0xb04a => { #9
        Name => 'SequenceNumber',
        Notes => 'shot number in continuous burst',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Single',
            65535 => 'n/a', #PH (A100)
            OTHER => sub { shift }, # pass all other numbers straight through
        },
    },
    0xb04b => { #2/PH
        Name => 'Anti-Blur',
        Writable => 'int16u',
        RawConv => '$val == 65535 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On (Continuous)', #PH (NC)
            2 => 'On (Shooting)', #PH (NC)
            65535 => 'n/a',
        },
    },
    # 0xb04c - rational64u: 10/10 (seen 5 for HX9V Manual-exposure images, ref JR)
    # 0xb04d - int16u: 0
    # (the Kamisaka decoding of 0xb04e seems wrong - ref JR)
    # 0xb04e => { #2
    #     Name => 'LongExposureNoiseReduction',
    #     Notes => 'LongExposureNoiseReduction for other models',
    #     Writable => 'int16u',
    #     RawConv => '$val == 65535 ? undef : $val',
    #     PrintConv => {
    #         0 => 'Off',
    #         1 => 'On',
    #         2 => 'On 2', #PH (TX10, TX100, WX9, WX10, etc)
    #         # 4 - seen this (CX360E, CX700E)
    #         65535 => 'n/a', #PH (A100)
    #     },
    # },
    0xb04e => { #PH (RX100) - but not in RX100M3 anymore (ref JR)
        Name => 'FocusMode',
        Condition => '$$self{MetaVersion} and $$self{MetaVersion} eq "DC7303320222000"', #JR
        Notes => 'valid for DSC-HX9V generation and newer',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Manual',
            # 1 - seen for DSC-WX7 burst, HDR-CX130E/CX560E
            2 => 'AF-S',
            3 => 'AF-C',
            # 4 - seen for HDR-CX360E/CX700E
            5 => 'Semi-manual', #JR (HX9V)
            6 => 'DMF', # "Direct Manual Focus"
        },
    },
    0xb04f => { #PH (TX1)
        Name => 'DynamicRangeOptimizer',
        Writable => 'int16u',
        Priority => 0, # (unreliable for the A77)
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Plus',
            # 8 for HDR models - what does this mean?
        },
    },
    0xb050 => { #PH (RX100)
        Name => 'HighISONoiseReduction2',
        Condition => '$$self{Model} =~ /^(DSC-|Stellar)/',
        Notes => 'DSC models only',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'High',
            2 => 'Low',
            3 => 'Off', #JR
            # it seems that all SLT and NEX models give n/a here (ref JR)
            65535 => 'n/a',
        },
    },
    # 0xb051 - int16u: 0
    0xb052 => { #PH (TX1)
        Name => 'IntelligentAuto',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Advanced', #9
        },
    },
    # 0xb053 - int16u: normally 0, but got 1 for a superior auto backlight picture (RX100)
    0xb054 => { #PH/9/JR (TX1,TX7,RX100,HX9V)
        Name => 'WhiteBalance',
        Writable => 'int16u',
        Notes => q{
            decoding of the Fluorescent settings matches the EXIF standard, which is
            different than the names used by Sony for some models
        },
        PrintConv => {
            0 => 'Auto',
            4 => 'Custom', # (manual)
            5 => 'Daylight',
            6 => 'Cloudy',
            # PrintConv names matching Exif Fluorescent LightSource names (ref JR)
            # (Sony uses conflicting names for some models)
            7 => 'Cool White Fluorescent', # (RX100) (TX7/HX9V "Fluorescent 1 (White)", ref 9/JR)
            8 => 'Day White Fluorescent',  # (RX100) (TX7/HX9V "Fluorescent 2 (Natural White)", ref 9/JR)
            9 => 'Daylight Fluorescent',   # (RX100) (TX7/HX9V "Fluorescent 3 (Day White)", ref 9/JR)
            10 => 'Incandescent2', #JR (HX9V)
            11 => 'Warm White Fluorescent',
            14 => 'Incandescent',
            15 => 'Flash',
            17 => 'Underwater 1 (Blue Water)', #9
            18 => 'Underwater 2 (Green Water)', #9
            19 => 'Underwater Auto', #JR
        },
    },
);

# "SEMC MS" maker notes
%Image::ExifTool::Sony::Ericsson = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Maker notes found in images from some Sony Ericsson phones.',
    0x2000 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x201 => {
        Name => 'PreviewImageStart',
        IsOffset => 1,
        MakerPreview => 1, # force preview inside maker notes
        OffsetPair => 0x202,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
        Notes => 'a small 320x200 preview image',
    },
    0x202 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x201,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
);

# camera information for the A700/A850/A900 (ref JR)
%Image::ExifTool::Sony::CameraInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Camera information for the A700, A850 and A900.',
    0x00 => {
        Name => 'LensSpec',
        # the A700/A850/A900 use a different int16 byte ordering! - PH
        Format => 'undef[8]',
        ValueConv => sub {
            my $val = shift;;
            return ConvLensSpec(pack('v*', unpack('n*', $val)));
        },
        ValueConvInv => sub {
            my $val = shift;
            return pack('v*', unpack('n*', ConvInvLensSpec($val)));
        },
        PrintConv => \&PrintLensSpec,
        PrintConvInv => \&PrintInvLensSpec,
    },
    0x0014 => {
        Name => 'FocusModeSetting',
        Notes => 'FocusModeSetting for the A700, A850 and A900',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
            4 => 'DMF',
        },
    },
    0x0015 => { # the AF Point selected in AFAreaMode=Local or Spot; always '0' for AFAreaMode=Wide
        Name => 'AFPointSelected',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto',
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
            10 => 'Far Right', # only given by A700
            11 => 'Far Left',  # only given by A700
        },
    },
    # 0x0019 - AF sensor used for focusing for A700/A850/A900:
    #
    #   A700 AF sensor layout:         A850/A900 AF sensor layout:
    #
    #              -                             *-*                 - = AF sensor
    #        |           |                  |           |            * = assist sensor
    #              -                             *-*                 o = F2.8 sensor
    #   |    |    |o|    |    |        |    *    |o|    *    |       A700 center: double-cross + F2.8
    #              -                             *-*                 A850 center: double-cross + F2.8 + 4 assist
    #        |           |                  |           |
    #              -                             *-*
    #
    # Following values seen for A700/A850 in AFAreaMode=Local or Spot: (other values only seen in "Wide")
    #
    #              16
    #         0           19
    #              13
    #    3    1    22     20    18
    #               8
    #         2           21
    #               5
    #
    # Note 1: A850/A900 AFPoint Selected 'Left'/'Right' (in 0x0015) corresponds in position (see diagram)
    #         to A700 Local AFPoint 'Far Left'/'Far Right', and gives 'Far Left'/'Far Right' in 0x0019.
    # Note 2: A700 in "Wide" also gives all 23 values in 0x0019, although it doesn't have assist-points ...
    0x0019 => { # the AF sensor used for focusing
        Name => 'AFPoint',
        PrintConv => {
            0 => 'Upper-left',
            1 => 'Left',
            2 => 'Lower-left',
            3 => 'Far Left',
            4 => 'Bottom Assist-left', #NC
            5 => 'Bottom',
            6 => 'Bottom Assist-right', #NC
            # values 7-14: 8 center points: 4 from double-cross + 4 assist; 7-10 appear horizontal, 11-14 vertical
            7  => 'Center (7)', #NC
            8  => 'Center (horizontal)',
            9  => 'Center (9)', #NC
            10 => 'Center (10)', #NC
            11 => 'Center (11)', #NC
            12 => 'Center (12)', #NC
            13 => 'Center (vertical)',
            14 => 'Center (14)', #NC
            15 => 'Top Assist-left', #NC
            16 => 'Top',
            17 => 'Top Assist-right', #NC
            18 => 'Far Right',
            19 => 'Upper-right',
            20 => 'Right',
            21 => 'Lower-right',
            22 => 'Center F2.8',
        },
    },
    # AF Status for A700/A850/A900, which have different sensor layout
    # and different int16 byte ordering
    0x001e => { Name => 'AFStatusActiveSensor',       %Image::ExifTool::Minolta::afStatusInfo },
    0x0020 => { Name => 'AFStatusUpper-left',         %Image::ExifTool::Minolta::afStatusInfo },
    0x0022 => { Name => 'AFStatusLeft',               %Image::ExifTool::Minolta::afStatusInfo },
    0x0024 => { Name => 'AFStatusLower-left',         %Image::ExifTool::Minolta::afStatusInfo },
    0x0026 => { Name => 'AFStatusFarLeft',            %Image::ExifTool::Minolta::afStatusInfo },
    0x0028 => { Name => 'AFStatusBottomAssist-left',  %Image::ExifTool::Minolta::afStatusInfo },
    0x002a => { Name => 'AFStatusBottom',             %Image::ExifTool::Minolta::afStatusInfo },
    0x002c => { Name => 'AFStatusBottomAssist-right', %Image::ExifTool::Minolta::afStatusInfo },
    0x002e => { Name => 'AFStatusCenter-7',           %Image::ExifTool::Minolta::afStatusInfo },
    0x0030 => { Name => 'AFStatusCenter-horizontal',  %Image::ExifTool::Minolta::afStatusInfo },
    0x0032 => { Name => 'AFStatusCenter-9',           %Image::ExifTool::Minolta::afStatusInfo },
    0x0034 => { Name => 'AFStatusCenter-10',          %Image::ExifTool::Minolta::afStatusInfo },
    0x0036 => { Name => 'AFStatusCenter-11',          %Image::ExifTool::Minolta::afStatusInfo },
    0x0038 => { Name => 'AFStatusCenter-12',          %Image::ExifTool::Minolta::afStatusInfo },
    0x003a => { Name => 'AFStatusCenter-vertical',    %Image::ExifTool::Minolta::afStatusInfo },
    0x003c => { Name => 'AFStatusCenter-14',          %Image::ExifTool::Minolta::afStatusInfo },
    0x003e => { Name => 'AFStatusTopAssist-left',     %Image::ExifTool::Minolta::afStatusInfo },
    0x0040 => { Name => 'AFStatusTop',                %Image::ExifTool::Minolta::afStatusInfo },
    0x0042 => { Name => 'AFStatusTopAssist-right',    %Image::ExifTool::Minolta::afStatusInfo },
    0x0044 => { Name => 'AFStatusFarRight',           %Image::ExifTool::Minolta::afStatusInfo },
    0x0046 => { Name => 'AFStatusUpper-right',        %Image::ExifTool::Minolta::afStatusInfo },
    0x0048 => { Name => 'AFStatusRight',              %Image::ExifTool::Minolta::afStatusInfo },
    0x004a => { Name => 'AFStatusLower-right',        %Image::ExifTool::Minolta::afStatusInfo },
    0x004c => { Name => 'AFStatusCenterF2-8',         %Image::ExifTool::Minolta::afStatusInfo },
    0x0130 => {
        Name => 'AFMicroAdjValue',
        Condition => '$$self{Model} =~ /^DSLR-A(850|900)\b/',
        ValueConv => '$val - 20',
        ValueConvInv => '$val + 20',
    },
    0x0131 => {
        Name => 'AFMicroAdjMode',
        Condition => '$$self{Model} =~ /^DSLR-A(850|900)\b/',
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Off',
            0x80 => 'On',
        },
    },
    305.1 => { # (0x131)
        Name => 'AFMicroAdjRegisteredLenses',
        Notes => 'number of registered lenses with a non-zero AFMicroAdjValue',
        Condition => '$$self{Model} =~ /^DSLR-A(850|900)\b/',
        Mask => 0x7f,
    },
    # 0x0166 - 40 x 128 int8u values: AF Info Blocks for A850 and A900, not for A700
);

# camera information for other DSLR models (ref JR)
%Image::ExifTool::Sony::CameraInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Camera information for the DSLR-A200, A230, A290, A300, A330, A350, A380 and
        A390.
    },
    0x00 => {
        Name => 'LensSpec',
        Format => 'undef[8]',
        ValueConv => \&ConvLensSpec,
        ValueConvInv => \&ConvInvLensSpec,
        PrintConv => \&PrintLensSpec,
        PrintConvInv => \&PrintInvLensSpec,
    },
    # 0x0010 - maybe to do with AFStatus: 0 na./Manual, 4 Failed, 16 Tracking, 64 Focused
    0x0014 => {
        Name => 'AFPointSelected',
        PrintConvColumns => 2,
        PrintConv => { #JR (NC) same list as A100, A700/A900, as all have 9 point AF
            0 => 'Auto',
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
        },
    },
    0x0015 => {
        Name => 'FocusModeSetting',
        Notes => 'FocusModeSetting for other models',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
            4 => 'DMF',
        },
    },
    # 0x0018 - AF sensor used for focusing for A200/A230/A290/A300/A330/A350/A380/A390; AF sensor layout:
    #
    #               -              - = AF sensor
    #        |              |      + = cross sensor
    #
    #            -  +  -
    #
    #        |              |
    #               -
    #
    0x0018 => { # used A100 list which appears to match
        Name => 'AFPoint',
        PrintConv => {
            0 => 'Top-right',
            1 => 'Bottom-right',
            2 => 'Bottom',
            3 => 'Middle Horizontal',
            4 => 'Center Vertical',
            5 => 'Top',
            6 => 'Top-left',
            7 => 'Bottom-left',
        },
    },
    # AF Status for A200/A230/A290/A300/A330/A350/A380/A390: analogous to A100 in Minolta.pm
    0x001b => { Name => 'AFStatusActiveSensor',     %Image::ExifTool::Minolta::afStatusInfo },
    0x001d => { Name => 'AFStatusTop-right',        %Image::ExifTool::Minolta::afStatusInfo },
    0x001f => { Name => 'AFStatusBottom-right',     %Image::ExifTool::Minolta::afStatusInfo },
    0x0021 => { Name => 'AFStatusBottom',           %Image::ExifTool::Minolta::afStatusInfo },
    # MiddleHorizontal is any of the 3 central horizontal sensors
    0x0023 => { Name => 'AFStatusMiddleHorizontal', %Image::ExifTool::Minolta::afStatusInfo },
    0x0025 => { Name => 'AFStatusCenterVertical',   %Image::ExifTool::Minolta::afStatusInfo },
    0x0027 => { Name => 'AFStatusTop',              %Image::ExifTool::Minolta::afStatusInfo },
    0x0029 => { Name => 'AFStatusTop-left',         %Image::ExifTool::Minolta::afStatusInfo },
    0x002b => { Name => 'AFStatusBottom-left',      %Image::ExifTool::Minolta::afStatusInfo },
    # the 3 MiddleHorizontal sensors
    0x002d => { Name => 'AFStatusLeft',             %Image::ExifTool::Minolta::afStatusInfo },
    0x002f => { Name => 'AFStatusCenterHorizontal', %Image::ExifTool::Minolta::afStatusInfo },
    0x0031 => { Name => 'AFStatusRight',            %Image::ExifTool::Minolta::afStatusInfo },
    # 0x0166 -  59 x 96 int8u values: AF Info Blocks for A230/A290/A330/A380/A390
    # 0x0182 -  58 x 88 int8u values: AF Info Blocks for A200/A300/A350
);

# Camera information for the A55 (ref PH)
# (also valid for A33, A35, A560, A580 - ref JR)
%Image::ExifTool::Sony::CameraInfo3 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x23 ],
    NOTES => q{
        Camera information stored by the A33, A35, A55, A450, A500, A550, A560,
        A580, NEX-3/5/5C/C3 and VG10E.  Some tags are valid only for some of these
        models.
    },
    0x00 => { #JR
        Name => 'LensSpec',
        Condition => '$$self{Model} !~ /^NEX-5C/',
        Format => 'undef[8]',
        ValueConv => \&ConvLensSpec,
        ValueConvInv => \&ConvInvLensSpec,
        PrintConv => \&PrintLensSpec,
        PrintConvInv => \&PrintInvLensSpec,
    },
    0x0e => { #JR
        Name => 'FocalLength',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int16u',
        Priority => 0,
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ mm//; $val',
    },
    0x10 => { #JR
        Name => 'FocalLengthTeleZoom',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int16u',
        ValueConv => '$val * 2 / 3',
        ValueConvInv => 'int($val * 3 / 2 + 0.5)',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ mm//; $val',
    },
#
# Note:
# The below AF decoding covers cameras with 2 different AF systems, with overlapping offsets !
#  1) DSLR-A450/A500/A550 with 9 point AF system: decoding/offsets identical to A200 - A390 in CameraInfo
#  2) SLT-A33/A35/A55 and DSLR-A560/A580 with 15 point AF system: similar/more info but at different offsets
#
    0x14 => { #JR
        Name => 'AFPointSelected',
        Condition => '$$self{Model} =~ /^(DSLR-A(450|500|550))\b/',
        # (these cameras have a 9-point AF system, ref JR)
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto', # (seen in Wide mode and for Manual Focus)
            1 => 'Center', # seen for AFArea=Spot
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
        },
    },
    0x15 => { #JR
        Name => 'FocusMode',
        Condition => '$$self{Model} =~ /^(DSLR-A(450|500|550))\b/',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x18 => { #JR
        Name => 'AFPoint',
        Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/',
        PrintConv => {
            0 => 'Top-right',
            1 => 'Bottom-right',
            2 => 'Bottom',
            3 => 'Middle Horizontal',
            4 => 'Center Vertical',
            5 => 'Top',
            6 => 'Top-left',
            7 => 'Bottom-left',
        },
    },
    0x19 => { #JR
        Name => 'FocusStatus',
        Condition => '$$self{Model} =~ /^(SLT-|DSLR-A(560|580))\b/',
        Notes => 'not valid with Contrast AF or for NEX models',
        # seen the following values:
        #  0 with MF (A35, A55V-HDR, A560, A580), non-AF lens (A35), and A580 Contrast-AF
        #  4 with MF (A33, A55V), and A580 Contrast-AF
        # 16 with AF-C (or AF-A) and focus OK
        # 24 with AF-C (or AF-A) and unsharp or fast moving subject e.g. bird in flight
        # 64 with AF-S (or AF-A) and focus OK
        PrintConv => {
            0 => 'Manual - Not confirmed (0)',
            4 => 'Manual - Not confirmed (4)',
            16 => 'AF-C - Confirmed',
            24 => 'AF-C - Not Confirmed',
            64 => 'AF-S - Confirmed',
        },
    },
    0x1b => { #JR
        Name => 'AFStatusActiveSensor',
        Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/',
        %Image::ExifTool::Minolta::afStatusInfo,
    },
    0x1c => {
        Name => 'AFPointSelected',  # (v8.88: renamed from LocalAFAreaPointSelected)
        Condition => '$$self{Model} =~ /^(SLT-|DSLR-A(560|580))\b/',
        Notes => 'not valid for Contrast AF', #JR
        # (all of these cameras have an 15-point three-cross AF system, ref JR)
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto', # (seen in Wide mode)
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
            10 => 'Far Right',
            11 => 'Far Left',
            12 => 'Upper-middle',
            13 => 'Near Right',
            14 => 'Lower-middle',
            15 => 'Near Left',
        },
    },
    0x1d => [
        {
            Name => 'FocusMode',
            Condition => '$$self{Model} =~ /^(SLT-|DSLR-A(560|580))\b/',
            PrintConv => {
                0 => 'Manual',
                1 => 'AF-S',
                2 => 'AF-C',
                3 => 'AF-A',
            },
        },{ #JR
            Name => 'AFStatusTop-right',
            Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/',
            %Image::ExifTool::Minolta::afStatusInfo,
        },
    ],
    0x1f => { #JR
        Name => 'AFStatusBottom-right',
        Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/',
        %Image::ExifTool::Minolta::afStatusInfo,
    },
    0x20 => { #JR
        Name => 'AFPoint',  # (v8.88: renamed from LocalAFAreaPointUsed)
        Condition => '$$self{Model} =~ /^(SLT-|DSLR-A(560|580))\b/',
        Notes => 'the AF sensor used for focusing. Not valid for Contrast AF',
        PrintConvColumns => 2,
        PrintConv => {
            %afPoint15,
            255 => '(none)', #PH (A55, guess; also A35 with non-AF lens, ref JR)
        },
    },
    0x21 => [ #JR
        {
            Name => 'AFStatusActiveSensor',
            Condition => '$$self{Model} =~ /^(SLT-|DSLR-A(560|580))\b/',
            %Image::ExifTool::Minolta::afStatusInfo,
        },{
            Name => 'AFStatusBottom',
            Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/',
            %Image::ExifTool::Minolta::afStatusInfo,
        },
    ],
    0x23 => [ #JR
        {
            Name => 'AFStatus15',
            Condition => '$$self{Model} =~ /^(SLT-|DSLR-A(560|580))\b/',
            Format => 'int16s[18]',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::AFStatus15' },
        },{
            Name => 'AFStatusMiddleHorizontal', # MiddleHorizontal is any of the 3 central horizontal sensors
            Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/',
            %Image::ExifTool::Minolta::afStatusInfo,
        },
    ],
    0x25 => { Name => 'AFStatusCenterVertical',   Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    0x27 => { Name => 'AFStatusTop',              Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    0x29 => { Name => 'AFStatusTop-left',         Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    0x2b => { Name => 'AFStatusBottom-left',      Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    # the 3 MiddleHorizontal sensors:
    0x2d => { Name => 'AFStatusLeft',             Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    0x2f => { Name => 'AFStatusCenterHorizontal', Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    0x31 => { Name => 'AFStatusRight',            Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)\b/', %Image::ExifTool::Minolta::afStatusInfo },
    # 0x0166 - starting here there are 96 AF Info blocks of 155 bytes each for the SLT-A33/A35/A55 and DSLR-A560/A580,
    #          starting here there are 86 AF Info blocks of 174 bytes each for the DSLR-A450/A500/A550,
    #          but NOT for NEX, and not for the A580 in Contrast-AF mode (ref JR)
    #          The 43rd byte of each block for A580 appears to be the AFPoint as in offset 0x20,
    #          possibly also 73rd and 74th byte
);

# Camera information for other models (ref PH)
%Image::ExifTool::Sony::CameraInfoUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# white balance and other camera information (ref PH)
%Image::ExifTool::Sony::FocusInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRIORITY => 0,
    NOTES => q{
        More camera settings and focus information decoded for models such as the
        A200, A230, A290, A300, A330, A350, A380, A390, A700, A850 and A900.
    },
    0x0e => [{ #7/JR
        Name => 'DriveMode2',
        Condition => '$$self{Model} =~ /^DSLR-A(230|290|330|380|390)$/',
        Notes => 'A230, A290, A330, A380 and A390',
        ValueConvInv => '$val',
        PrintHex => 1,
        PrintConv => { # (values confirmed for specified models - PH)
            0x01 => 'Single Frame', # (A230,A330,A380)
            0x02 => 'Continuous High', #PH (A230,A330)
            0x04 => 'Self-timer 10 sec', # (A230)
            0x05 => 'Self-timer 2 sec, Mirror Lock-up', # (A230,A290,A330,A380,390)
            0x07 => 'Continuous Bracketing', # (A230,A330)
            0x0a => 'Remote Commander', # (A230)
            0x0b => 'Continuous Self-timer', # (A230,A330)
        },
    },{
        Name => 'DriveMode2',
        Notes => 'A200, A300, A350, A700, A850 and A900',
        ValueConvInv => '$val',
        PrintHex => 1,
        PrintConv => {
            0x01 => 'Single Frame',
            0x02 => 'Continuous High', # A700/A900; not on A850
            0x12 => 'Continuous Low', #JR
            0x04 => 'Self-timer 10 sec',
            0x05 => 'Self-timer 2 sec, Mirror Lock-up',
            0x06 => 'Single-frame Bracketing',
            0x07 => 'Continuous Bracketing',
            0x18 => 'White Balance Bracketing Low', #JR
            0x28 => 'White Balance Bracketing High', #JR
            0x19 => 'D-Range Optimizer Bracketing Low', #JR
            0x29 => 'D-Range Optimizer Bracketing High', #JR
            0x0a => 'Remote Commander', #JR
            0x0b => 'Mirror Lock-up', #JR (A850/A900; not on A700)
        },
    }],
    0x10 => { #JR (1 and 2 inverted!)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 90 CW',
        },
    },
    0x14 => {
        Name => 'ImageStabilizationSetting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x15 => { #7
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x2b => { #JR seen 2,1,3 for both WB and DRO bracketing
        Name => 'BracketShotNumber',
        Notes => 'WB and DRO bracketing',
    },
    0x2c => { #JR
        Name => 'WhiteBalanceBracketing',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x2d => { #JR seen 2,1,3 for both WB and DRO bracketing
        Name => 'BracketShotNumber2',
    },
    0x2e => { #JR
        Name => 'DynamicRangeOptimizerBracket',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x2f => { #JR seen 0,1,2 and 0,1,2,3,4 for 3 and 5 image bracketing sequences
        Name => 'ExposureBracketShotNumber',
    },
    0x3f => { #JR
        Name => 'ExposureProgram',
        SeparateTable => 'ExposureProgram',
        PrintConv => \%sonyExposureProgram,
    },
    0x41 => { #JR style actually used (combination of mode dial + creative style menu)
        Name => 'CreativeStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            9 => 'Adobe RGB', # A700
            11 => 'Neutral',
            12 => 'Clear', #7
            13 => 'Deep', #7
            14 => 'Light', #7
            15 => 'Autumn Leaves', #7
            16 => 'Sepia', #7
        },
    },
    0x6d => {
        Name => 'ISOSetting',
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x6f => {
        Name => 'ISO',
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x77 => { #JR
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x79 => 'DynamicRangeOptimizerLevel',
#    0x06f1 - int16u    LensType,  Condition => '$$self{Model} =~ /^DSLR-A(700|850|900)$/',
#    0x4a81 - int16u    LensType,  Condition => '$$self{Model} !~ /^DSLR-A(700|850|900)$/',
#    0x4a84 - int16uRev LensType,  Condition => '$$self{Model} =~ /^DSLR-A(700|850|900)$/',
    0x0846 => { #13
        Name => 'ShutterCount', # (=ImageCount for these models)
        Condition => '$$self{Model} =~ /^DSLR-A(230|290|330|380|390|850|900)$/',
        Format => 'int32u',
        Notes => 'only valid for some DSLR models',
        RawConv => '$val & 0x00ffffff', #PH
    },
    0x09bb => { #PH (validated only for DSLR-A850)
        Name => 'FocusPosition',
        Condition => '$$self{Model} =~ /^DSLR-A(200|230|290|300|330|350|380|390|700|850|900)$/',
        Notes => 'only valid for some DSLR models',
        # 128 = infinity -- see Composite:FocusDistance below
    },
    0x1110 => { # (9600 bytes: 4 sets of 40x30 int16u values in the range 0-8191)
        Name => 'TiffMeteringImage',
        Format => 'undef[9600]',
        Notes => q{
            13-bit RBGG (?) 40x30 pixels, presumably metering info, extracted as a
            16-bit TIFF image;
        },
        ValueConv => sub {
            my ($val, $et) = @_;
            return undef unless length $val >= 9600;
            return \ "Binary data 7404 bytes" unless $et->Options('Binary');
            my @dat = unpack('n*', $val);
            # TIFF header for a 16-bit RGB 10dpi 40x30 image
            $val = MakeTiffHeader(40,30,3,16,10);
            # re-order data to RGB pixels
            my ($i, @val);
            for ($i=0; $i<40*30; ++$i) {
                # data is 13-bit (max 8191), shift left to fill 16 bits
                # (typically, this gives a very dark image since the data should
                # really be anti-logged to convert from EV to perceived brightness)
#                push @val, $dat[$i]<<3, $dat[$i+2400]<<3, $dat[$i+1200]<<3;
                push @val, int(5041.1*log($dat[$i]+1)/log(2)), int(5041.1*log($dat[$i+2400]+1)/log(2)), int(5041.1*log($dat[$i+1200]+1)/log(2));
            }
            $val .= pack('v*', @val);   # add TIFF strip data
            return \$val;
        },
    },
);

# more camera setting information (ref JR)
# - many of these tags are the same as in CameraSettings3
%Image::ExifTool::Sony::MoreInfo = (
    PROCESS_PROC => \&ProcessMoreInfo,
    WRITE_PROC => \&ProcessMoreInfo,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        More camera settings information decoded for the A450, A500, A550, A560,
        A580, A33, A35, A55, NEX-3/5/C3 and VG10E.
    },
    0x0001 => { # (256 bytes)
        Name => 'MoreSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MoreSettings' },
    },
    # (byte sizes for a single A580 image -- not checked for other images)
    0x0002 => [ # (256 bytes)
        {
            Name => 'FaceInfo',
            Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::FaceInfo' },
        },{
            Name => 'FaceInfoA',
            Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::FaceInfoA' },
        },
    ],
    # 0x0101:  512 bytes
    # 0x0102: 1804 bytes
    # 0x0103:  176 bytes
    # 0x0104: 1088 bytes
    # 0x0105:  160 bytes (all zero unless flash is used, ref JR)
    # 0x0106:  256 bytes (faces detected if first byte is non-zero? ref JR)
    0x0107 => { # (7200 bytes: 3 sets of 40x30 int16u values in the range 0-1023)
        Name => 'TiffMeteringImage',
        Notes => q{
            10-bit RGB data from the 1200 AE metering segments, extracted as a 16-bit
            TIFF image
        },
        ValueConv => sub {
            my ($val, $et) = @_;
            return undef unless length $val >= 7200;
            return \ "Binary data 7404 bytes" unless $et->Options('Binary');
            my @dat = unpack('v*', $val);
            # TIFF header for a 16-bit RGB 10dpi 40x30 image
            $val = MakeTiffHeader(40,30,3,16,10);
            # re-order data to RGB pixels
            my ($i, @val);
            for ($i=0; $i<40*30; ++$i) {
                # data is 10-bit (max 1023), shift left to fill 16 bits
                # (typically, this gives a very dark image since the data should
                # really be anti-logged to convert from EV to perceived brightness)
                push @val, $dat[$i]<<6, $dat[$i+1200]<<6, $dat[$i+2400]<<6;
            }
            $val .= pack('v*', @val);   # add TIFF strip data
            return \$val;
        },
    },
    # 0x0108:  140 bytes
    # 0x0109:  256 bytes
    # 0x010a:  256 bytes
    # 0x0306:  276 bytes
    # 0x0307:  256 bytes
    # 0x0308:   96 bytes
    # 0x0309:  112 bytes
    # 0xffff:  788 bytes
    0x0201 => { # (368 bytes)
        Name => 'MoreInfo0201',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MoreInfo0201' },
    },
    # 0x0202:  144 bytes
    # 0x0401: 4608 bytes
    0x0401 => {
        Name => 'MoreInfo0401',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MoreInfo0401' },
    },
);

%Image::ExifTool::Sony::MoreInfo0201 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRIORITY => 0,
#    0x005d - also from 0 - 255, in sync with but lower than 0x005e, depending on FocalLength
#    0x005e => {
#        # FocusPosition for A560/A580/A33/A35/A55V
#        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
#        Name => 'FocusPosition2_0201',
#        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
#    },
#    0x0093 - also from 0 - 255, in sync with but lower than 0x0094, depending on FocalLength
#    0x0094 => {
#        # FocusPosition for A450/A500/A550
#        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
#        Name => 'FocusPosition2_0201',
#        Condition => '$$self{Model} =~ /^(DSLR-(A450|A500|A550)$)/',
#    },
    0x011b => { #13
        Name => 'ImageCount',
        Condition => '$$self{Model} !~ /^DSLR-A(450|500|550)$/', #JR
        Format => 'int32u',
        Notes => 'not valid for the A450, A500 or A550',
        RawConv => '$val & 0x00ffffff',
    },
    0x0125 => { #13
        Name => 'ShutterCount',
        Condition => '$$self{Model} !~ /^DSLR-A(450|500|550)$/', #JR
        Format => 'int32u',
        Notes => 'not valid for the A450, A500 or A550',
        RawConv => '$val & 0x00ffffff',
    },
    0x014a => { #13
        Name => 'ShutterCount', # (=ImageCount for these models)
        Condition => '$$self{Model} =~ /^DSLR-A(450|500|550)$/', #JR
        Format => 'int32u',
        Notes => 'A450, A500 and A550 only',
        RawConv => '$val & 0x00ffffff',
    },
);

%Image::ExifTool::Sony::MoreInfo0401 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRIORITY => 0,
    0x044e => { #JR
        Name => 'ShotNumberSincePowerUp',
        Condition => '$$self{Model} !~ /^NEX-(3|5)$/',
        Format => 'int32u',
        Notes => 'Not valid for the NEX-3 or NEX-5',
        RawConv => '$val & 0x00ffffff',
    },
#    0x101e - int16u LensType  Condition => '$$self{Model} =~ /^SLT-A(33|55V)/',
#    0x1022 - int16u LensType  Condition => '$$self{Model} =~ /^DSLR-A(560|580)/',
#    0x102a - int16u LensType  Condition => '$$self{Model} =~ /^(SLT-A35|NEX-C3)/',

#    0x10a8 - int16u LensType  Condition => '$$self{Model} =~ /^SLT-A(33|55V)/',
#    0x10ac - int16u LensType  Condition => '$$self{Model} =~ /^DSLR-A(560|580)/',
#    0x10b4 - int16u LensType  Condition => '$$self{Model} =~ /^(SLT-A35|NEX-C3)/',
#
#    0x10f7 - int16u LensType  Condition => '$$self{Model} =~ /^SLT-A(33|55V)/',
#    0x10fb - int16u LensType  Condition => '$$self{Model} =~ /^DSLR-A(560|580)/',
#    0x1103 - int16u LensType  Condition => '$$self{Model} =~ /^(SLT-A35|NEX-C3)/',
#
#    0x1181 - int16u LensType  Condition => '$$self{Model} =~ /^SLT-A(33|55V)/',
#    0x1185 - int16u LensType  Condition => '$$self{Model} =~ /^DSLR-A(560|580)/',
#    0x118d - int16u LensType  Condition => '$$self{Model} =~ /^(SLT-A35|NEX-C3)/',
);

# more camera setting information (ref JR)
# - many of these tags are the same as in CameraSettings3
%Image::ExifTool::Sony::MoreSettings = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRIORITY => 0,
    0x01 => { # interesting: somewhere between CameraSettings3 0x04 and 0x34
        Name => 'DriveMode2',
        PrintHex => 1,
        PrintConv => {
            0x10 => 'Single Frame',
            0x21 => 'Continuous High', # also automatically selected for Scene mode Sports-action (0x05=52)
            0x22 => 'Continuous Low',
            0x30 => 'Speed Priority Continuous',
            0x51 => 'Self-timer 10 sec',
            0x52 => 'Self-timer 2 sec, Mirror Lock-up',
            0x71 => 'Continuous Bracketing 0.3 EV',
            0x75 => 'Continuous Bracketing 0.7 EV',
            0x91 => 'White Balance Bracketing Low',
            0x92 => 'White Balance Bracketing High',
            0xc0 => 'Remote Commander',
        },
    },
    0x02 => {
        Name => 'ExposureProgram',
        SeparateTable => 'ExposureProgram2',
        PrintConv => \%sonyExposureProgram2,
    },
    0x03 => {
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted average',
            3 => 'Spot',
        },
    },
    0x04 => {
        Name => 'DynamicRangeOptimizerSetting',
        PrintConv => {
            1 => 'Off',
            16 => 'On (Auto)',
            17 => 'On (Manual)',
        },
    },
    0x05 => 'DynamicRangeOptimizerLevel',
    0x06 => {
        Name => 'ColorSpace',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
    0x07 => {
        Name => 'CreativeStyleSetting',
        PrintConvColumns => 2,
        PrintConv => {
            16 => 'Standard',
            32 => 'Vivid',
            64 => 'Portrait',
            80 => 'Landscape',
            96 => 'B&W',
            160 => 'Sunset',
        },
    },
    0x08 => { #JR
        Name => 'ContrastSetting',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x09 => {
        Name => 'SaturationSetting',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x0a => {
        Name => 'SharpnessSetting',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x0d => {
        Name => 'WhiteBalanceSetting',
        # many guessed, based on "logical system" as observed for Daylight and Shade and steps of 16 between the modes
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => \%whiteBalanceSetting,
        SeparateTable => 1,
    },
    0x0e => {
        Name => 'ColorTemperatureSetting',
        # matches "0xb021 ColorTemperature" when WB set to "Custom" or "Color Temperature/Color Filter"
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '"$val K"',
        PrintConvInv => '$val =~ s/ ?K$//i; $val',
    },
    0x0f => {
        Name => 'ColorCompensationFilterSet',
        # seen 0, 1-9 and 245-255, corresponding to 0, M1-M9 and G9-G1 on camera display
        # matches "0xb022 ColorCompensationFilter" when WB set to "Custom" or "Color Temperature/Color Filter"
        Format => 'int8s',
        Notes => 'negative is green, positive is magenta',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x10 => {
        Name => 'FlashMode',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Flash Off',
            16 => 'Autoflash',
            17 => 'Fill-flash',
            18 => 'Slow Sync',
            19 => 'Rear Sync',
            20 => 'Wireless',
        },
    },
    0x11 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            1 => 'Off',
            16 => 'On',  # (unused or dark subject)
        },
    },
    0x12 => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            16 => 'Low',
            19 => 'Auto',
        },
    },
    0x13 => { # why is this not valid for A450/A500/A550 ?
        Name => 'FocusMode',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            17 => 'AF-S',
            18 => 'AF-C',
            19 => 'AF-A',
            32 => 'Manual',
            48 => 'DMF', # (NC) (seen for NEX-5)
        },
    },
    0x15 => {
        Name => 'MultiFrameNoiseReduction',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a', # seen for A450/A500/A550
            1 => 'Off',
            16 => 'On',
            255 => 'None', # seen for NEX-3/5/C3
        },
    },
    0x16 => {
        Name => 'HDRSetting',
        PrintConv => {
            1 => 'Off',
            16 => 'On (Auto)',
            17 => 'On (Manual)',
        },
    },
    0x17 => {
        Name => 'HDRLevel',
        PrintConvColumns => 3,
        PrintConv => {
            33 => '1 EV',
            34 => '1.5 EV', #JR (NC)
            35 => '2 EV',
            36 => '2.5 EV', #JR (NC)
            37 => '3 EV',
            38 => '3.5 EV', #PH (NC)
            39 => '4 EV',
            40 => '5 EV',
            41 => '6 EV',
        },
    },
    0x18 => {
        Name => 'ViewingMode',
        PrintConv => {
            16 => 'ViewFinder',
            33 => 'Focus Check Live View',
            34 => 'Quick AF Live View',
        },
    },
    0x19 => {
        Name => 'FaceDetection',
        PrintConv => {
            1 => 'Off',
            16 => 'On',
        },
    },
    0x1a => {
        Name => 'CustomWB_RBLevels',
        # matches "0x7313 WB_RGGBLevels" when WB set to "Custom", except factor of 4
        Format => 'int16uRev[2]',
    },
    # From here different and overlapping offsets for 3 groups of cameras:
    # 1) DSLR-A450/A500/A550
    # 2) NEX-3/5/5C
    # 3) DSLR-A560/A580, NEX-C3/VG10/VG10E, SLT-A33/A35/A55V
    0x1e => [{
        Name => 'BrightnessValue',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        ValueConv => '($val-106)/8',
        ValueConvInv => '$val * 8 + 106',
    },{
        Name => 'ExposureCompensationSet',
        Notes => 'other models',
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    }],
    0x1f => [{
        Name => 'ISO',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },{
        Name => 'FlashExposureCompSet',
        Notes => 'other models',
        Description => 'Flash Exposure Comp. Setting',
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    }],
    0x20 => [{
        Name => 'FNumber',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },{
        Name => 'LiveViewAFMethod',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)/',
        Notes => 'other models except the NEX-3/5/5C',
        PrintConv => {
            0 => 'n/a',
            1 => 'Phase-detect AF',
            2 => 'Contrast AF',
            # Contrast AF is only available with SSM/SAM lenses and in Focus Check LV,
            # NOT in Quick AF LV, and is automatically set when mounting SSM/SAM lens
            # - changes into Phase-AF when switching to Quick AF LV.
        },
    }],
    0x21 => [{
        Name => 'ExposureTime',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },{
        Name => 'ISO',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C',
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    }],
    0x22 => {
        Name => 'FNumber',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C only',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x23 => [{
        Name => 'FocalLength2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        ValueConv => '10 * 2 ** (($val-28)/16)',
        ValueConvInv => '$val>0 ? log($val/10)/log(2) * 16 + 28 : 0',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//; $val',
    },{
        Name => 'ExposureTime',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    }],
    0x24 => {
        Name => 'ExposureCompensation2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        Format => 'int16s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    0x25 => [{
        Name => 'FocalLength2',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C',
        ValueConv => '10 * 2 ** (($val-28)/16)',
        ValueConvInv => '$val>0 ? log($val/10)/log(2) * 16 + 28 : 0',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//; $val',
    },{
        Name => 'ISO',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)/',
        Notes => 'other models except the A450, A500 and A550',
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    }],
    0x26 => [{
        Name => 'FlashExposureCompSet2',
        Description => 'Flash Exposure Comp. Setting 2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        Format => 'int16s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },{
        Name => 'ExposureCompensation2',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C',
        Format => 'int16s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },{
        Name => 'FNumber',
        Notes => 'other models',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    }],
    0x27 => {
        Name => 'ExposureTime',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)|DSLR-(A450|A500|A550)/',
        Notes => 'models other than the A450, A500, A550 and NEX-3/5/5C',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x28 => {
        Name => 'Orientation2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        PrintConv => {
            1 => 'Horizontal (normal)',
            2 => 'Rotate 180',
            6 => 'Rotate 90 CW',
            8 => 'Rotate 270 CW',
        },
    },
    0x29 => [{
        # FocusPosition for A450/A500/A550
        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
        Name => 'FocusPosition2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
    },{
        # value increase of 16 corresponds to doubling of FocalLength
        Name => 'FocalLength2',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)/',
        Notes => 'other models except the NEX-3/5/5C',
        ValueConv => '10 * 2 ** (($val-28)/16)',
        ValueConvInv => '$val>0 ? log($val/10)/log(2) * 16 + 28 : 0',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//; $val',
    }],
    0x2a => [{
        Name => 'FlashAction',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
        },
    },{
        Name => 'ExposureCompensation2',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)/',
        Notes => 'other models except the NEX-3/5/5C',
        Format => 'int16s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    }],
    0x2b => {
        # FocusPosition for NEX-3/5/5C
        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
        Name => 'FocusPosition2',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C only',
    },
    0x2c => [{
        Name => 'FocusMode2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        Notes => 'A450, A500 and A550',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },{
        Name => 'FlashAction',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C FlashAction2',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
        },
    },{
        Name => 'FlashExposureCompSet2',
        Description => 'Flash Exposure Comp. Setting 2',
        Notes => 'other models FlashExposureCompSet2',
        Format => 'int16s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    }],
    0x2e => [{
        Name => 'FocusMode2',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        Notes => 'NEX-3/5/5C',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },{
        Name => 'Orientation2', # seen some A55 images where this does not match the other Orientation tags
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)/',
        Notes => 'other models except the A450, A500 and A550',
        PrintConv => {
            1 => 'Horizontal (normal)',
            2 => 'Rotate 180',
            6 => 'Rotate 90 CW',
            8 => 'Rotate 270 CW',
        },
    }],
    0x2f => {
        # FocusPosition for A560/A580/A33/A35/A55V and NEX-C3/VG10/VG10E
        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
        Name => 'FocusPosition2',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)|DSLR-(A450|A500|A550)/',
        Notes => 'models other than the A450, A500, A550 and NEX-3/5/5C',
    },
    0x30 => {
        Name => 'FlashAction',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)|DSLR-(A450|A500|A550)/',
        Notes => 'models other than the A450, A500, A550 and NEX-3/5/5C',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
        },
    },
    0x32 => {
        Name => 'FocusMode2',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)|DSLR-(A450|A500|A550)/',
        Notes => 'models other than the A450, A500, A550 and NEX-3/5/5C',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },
    0x0077 => {
        Name => 'FlashAction2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)/',
        PrintConv => {
            0 => 'Did not fire',
            2 => 'External Flash fired (2)',
            3 => 'Built-in Flash fired',
            4 => 'External Flash fired (4)', # what is difference with 2 ?
        },
    },
    0x0078 => {
        Name => 'FlashActionExternal',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        PrintConv => {
            136 => 'Did not fire',
            121 => 'Fired', # what is difference with 122 ?
            122 => 'Fired',
        },
    },
    0x007c => {
        Name => 'FlashActionExternal',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)|DSLR-(A450|A500|A550)/',
        PrintConv => {
            136 => 'Did not fire',
            167 => 'Fired',
            182 => 'Fired, HSS',
        },
    },
    0x0082 => {
        Name => 'FlashStatus',
        Condition => '$$self{Model} =~ /^NEX-(3|5|5C)/',
        PrintConv => {
            0 => 'None',
            2 => 'External',
        },
    },
    0x0086 => {
        Name => 'FlashStatus',
        Condition => '$$self{Model} !~ /^NEX-(3|5|5C)|DSLR-(A450|A500|A550)/',
        PrintConv => {
            0 => 'None',
            1 => 'Built-in',
            2 => 'External',
        },
    },
);

# Face detection information (ref JR)
my %faceInfo = (
    Format => 'int16u[4]',
    # re-order to top,left,height,width and scale to full-sized image like other Sony models
    ValueConv => 'my @v=split(" ",$val); $_*=15 foreach @v; "$v[1] $v[0] $v[3] $v[2]"',
    ValueConvInv => 'my @v=split(" ",$val); $_=int($_/15+0.5) foreach @v; "$v[1] $v[0] $v[3] $v[2]"',
);
%Image::ExifTool::Sony::FaceInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    DATAMEMBER => [ 0x00 ],
    0x00 => {
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        Format => 'int16s',
        RawConv => '$$self{FacesDetected} = ($val == -1 ? 0 : $val); $val',
        PrintConv => {
            OTHER => sub { shift }, # pass other values straight through
            -1 => 'n/a',
        },
    },
    0x01 => {
        Name => 'Face1Position',
        Condition => '$$self{FacesDetected} >= 1',
        %faceInfo,
        Notes => q{
            re-ordered and scaled to return the top, left, height and width of detected
            face, with coordinates relative to the full-sized unrotated image and
            increasing Y downwards
        },
    },
    0x06 => {
        Name => 'Face2Position',
        Condition => '$$self{FacesDetected} >= 2',
        %faceInfo,
    },
    0x0b => {
        Name => 'Face3Position',
        Condition => '$$self{FacesDetected} >= 3',
        %faceInfo,
    },
    0x10 => {
        Name => 'Face4Position',
        Condition => '$$self{FacesDetected} >= 4',
        %faceInfo,
    },
    0x15 => {
        Name => 'Face5Position',
        Condition => '$$self{FacesDetected} >= 5',
        %faceInfo,
    },
    0x1a => {
        Name => 'Face6Position',
        Condition => '$$self{FacesDetected} >= 6',
        %faceInfo,
    },
    0x1f => {
        Name => 'Face7Position',
        Condition => '$$self{FacesDetected} >= 7',
        %faceInfo,
    },
    0x24 => {
        Name => 'Face8Position',
        Condition => '$$self{FacesDetected} >= 8',
        %faceInfo,
    },
);

%Image::ExifTool::Sony::FaceInfoA = ( # different offsets for A450/A500/A550
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    DATAMEMBER => [ 0x02, 0x03, 0x08 ],
#
# The FacesDetected number at 0x03 below is often 1 lower than the one at Tag900b 0x02.
# The number of Face Positions starting at 0x5b (max. 4) corresponds to the number at 0x03.
# The number of Face Positions starting at 0x0b usually corresponds to the FacesDetected number of Tag900b...
# Therefore created the extra condition at 0x0b (11.1) to output an available FacePosition, even when 0x03=0...
#
    0x02 => {
        Name => 'FaceTest2',
        DataMember => 'FaceTest2',
        Hidden => 1,
        RawConv => '$$self{FaceTest2} = $val; $$self{OPTIONS}{Unknown}<2 ? undef : $val',
    },
    0x03 => {
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = ($val > 8 ? 0 : $val); $val',
        ValueConv => '$val > 8 ? 0 : $val',
    },
    0x08 => {
        Name => 'FaceTest8',
        DataMember => 'FaceTest8',
        Hidden => 1,
        RawConv => '$$self{FaceTest8} = $val; $$self{OPTIONS}{Unknown}<2 ? undef : $val',
    },
# 0x0b - start of 8 Face Positions of 10 int16u values each
    0x0b => {
        Name => 'PotentialFace1Position',
        Condition => q{
            $$self{FacesDetected} >= 1 or
            ($$self{FaceTest8} > 0 and ($$self{FaceTest2} == 1 or $$self{FaceTest2} == 257))
        },
        %faceInfo,
    },
    0x15 => {
        Name => 'PotentialFace2Position',
        Condition => '$$self{FacesDetected} >= 2 or ($$self{FacesDetected} == 1 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
    0x1f => {
        Name => 'PotentialFace3Position',
        Condition => '$$self{FacesDetected} >= 3 or ($$self{FacesDetected} == 2 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
    0x29 => {
        Name => 'PotentialFace4Position',
        Condition => '$$self{FacesDetected} >= 4 or ($$self{FacesDetected} == 3 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
    0x33 => {
        Name => 'PotentialFace5Position',
        Condition => '$$self{FacesDetected} >= 5 or ($$self{FacesDetected} == 4 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
    0x3d => {
        Name => 'PotentialFace6Position',
        Condition => '$$self{FacesDetected} >= 6 or ($$self{FacesDetected} == 5 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
    0x47 => {
        Name => 'PotentialFace7Position',
        Condition => '$$self{FacesDetected} >= 7 or ($$self{FacesDetected} == 6 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
    0x51 => {
        Name => 'PotentialFace8Position',
        Condition => '$$self{FacesDetected} >= 8 or ($$self{FacesDetected} == 7 and $$self{FaceTest8} > 0)',
        %faceInfo,
    },
# 0x5b - start of max. 4 further Face Positions here
    0x5b => {
        Name => 'Face1Position',
        Condition => '$$self{FacesDetected} >= 1',
        %faceInfo,
    },
    0x65 => {
        Name => 'Face2Position',
        Condition => '$$self{FacesDetected} >= 2',
        %faceInfo,
    },
    0x6f => {
        Name => 'Face3Position',
        Condition => '$$self{FacesDetected} >= 3',
        %faceInfo,
    },
    0x79 => {
        Name => 'Face4Position',
        Condition => '$$self{FacesDetected} >= 4',
        %faceInfo,
    },
);

# Camera settings (ref PH) (decoded mainly from A200)
%Image::ExifTool::Sony::CameraSettings = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    PRIORITY => 0,
    NOTES => 'Camera settings for the A200, A300, A350, A700, A850 and A900.',
    0x00 => { #JR
        Name => 'ExposureTime',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x01 => { #JR
        Name => 'FNumber',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x02 => { #JR (requires external flash)
        Name => 'HighSpeedSync',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x03 => { #JR
        Name => 'ExposureCompensationSet',
        ValueConv => '($val - 128) / 24',
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x04 => { #7/JR
        Name => 'DriveMode',
        Mask => 0xff, # (not sure what upper byte is for)
        PrintConv => {
            0x01 => 'Single Frame',
            0x02 => 'Continuous High', # A700/A900; not on A850
            0x12 => 'Continuous Low', #JR
            0x04 => 'Self-timer 10 sec',
            0x05 => 'Self-timer 2 sec, Mirror Lock-up',
            0x06 => 'Single-frame Bracketing',
            0x07 => 'Continuous Bracketing', # (A200 val=0x1107)
            0x18 => 'White Balance Bracketing Low', #JR
            0x28 => 'White Balance Bracketing High', #JR
            0x19 => 'D-Range Optimizer Bracketing Low', #JR
            0x29 => 'D-Range Optimizer Bracketing High', #JR
            0x0a => 'Remote Commander', #JR
            0x0b => 'Mirror Lock-up', #JR (A850/A900; not on A700)
        },
    },
    0x05 => { #JR
        Name => 'WhiteBalanceSetting',
        PrintConv => {
            2 => 'Auto',
            4 => 'Daylight',
            5 => 'Fluorescent',
            6 => 'Tungsten',
            7 => 'Flash',
            16 => 'Cloudy',
            17 => 'Shade',
            18 => 'Color Temperature/Color Filter',
            32 => 'Custom 1',
            33 => 'Custom 2',
            34 => 'Custom 3',
        },
    },
    0x06 => { #7 (A700) (ref JR: at least also valid for A200, ValueConv as for ColorCompensationFilterSet)
        Name => 'WhiteBalanceFineTune',
        ValueConv => '$val > 128 ? $val - 256 : $val',
    },
    0x07 => { #JR as set in WB "Color Temperature/Color Filter" and in White Balance Bracketing
        Name => 'ColorTemperatureSet',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '"$val K"',
        PrintConvInv => '$val =~ s/ ?K$//i; $val',
    },
    0x08 => { #JR as set in WB "Color Temperature/Color Filter"
        Name => 'ColorCompensationFilterSet',
        Notes => 'negative is green, positive is magenta',
        ValueConv => '$val > 128 ? $val - 256 : $val',
        ValueConvInv => '$val < 0 ? $val + 256 : $val',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x0c => { #JR as set in WB "Custom" and in White Balance Bracketing
        Name => 'ColorTemperatureCustom',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '"$val K"',
        PrintConvInv => '$val =~ s/ ?K$//i; $val',
    },
    0x0d => { #JR as set in WB "Custom"
        Name => 'ColorCompensationFilterCustom',
        Notes => 'negative is green, positive is magenta',
        ValueConv => '$val > 128 ? $val - 256 : $val',
        ValueConvInv => '$val < 0 ? $val + 256 : $val',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x0f => { #JR
        Name => 'WhiteBalance',
        PrintConv => {
            2 => 'Auto',
            4 => 'Daylight',
            5 => 'Fluorescent',
            6 => 'Tungsten',
            7 => 'Flash',
            12 => 'Color Temperature',
            13 => 'Color Filter',
            14 => 'Custom',
            16 => 'Cloudy',
            17 => 'Shade',
        },
    },
    0x10 => { #7 (A700)
        Name => 'FocusModeSetting',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
            4 => 'DMF', #JR
        },
    },
    0x11 => { #JD (A700)
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x12 => { #7 (A700)
        Name => 'AFPointSetting',
        Format => 'int16u',
        # The AF point as selected by the user in AFAreaMode=Local or Spot;
        # Reported value remains at the last-set position in AFAreaModes=Wide.
        # A200, A300, A350: 9-point centre-cross (ref JR)
        # A700: 11-point centre-dual-cross (ref JR)
        # A850, A900: 9-point centre-dual-cross with 10 assist-points (ref JR)
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
            10 => 'Far Right', # (presumably A700 only)
            11 => 'Far Left', # (presumably A700 only)
        },
    },
    0x13 => { #JR
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Autoflash',
            2 => 'Rear Sync',
            3 => 'Wireless',
            4 => 'Fill-flash',
            5 => 'Flash Off',
            6 => 'Slow Sync',
        },
    },
    0x14 => { #JR
        Name => 'FlashExposureCompSet',
        Description => 'Flash Exposure Comp. Setting',
        # (as pre-selected by the user, not zero if flash didn't fire)
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x15 => { #7
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted Average',
            4 => 'Spot',
        },
    },
    0x16 => {
        Name => 'ISOSetting',
        # 0 indicates 'Auto' (I think)
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x18 => { #7
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x19 => { #7
        Name => 'DynamicRangeOptimizerLevel',
    },
    0x1a => { # style actually used (combination of mode dial + creative style menu)
        Name => 'CreativeStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            9 => 'Adobe RGB', # A700
            11 => 'Neutral',
            12 => 'Clear', #7
            13 => 'Deep', #7
            14 => 'Light', #7
            15 => 'Autumn Leaves', #7
            16 => 'Sepia', #7
        },
    },
    0x1b => { #JR
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',        # (A850, selected via Colorspace menu item)
            5 => 'Adobe RGB (A700)', # (A700, selected via CreativeStyle menu)
        },
    },
    0x1c => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1d => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1e => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1f => { #7
        Name => 'ZoneMatchingValue',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x22 => { #7
        Name => 'Brightness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x23 => {
        Name => 'FlashControl',
        PrintConv => {
            0 => 'ADI',
            1 => 'Pre-flash TTL',
            2 => 'Manual',
        },
    },
    0x28 => { #7
        Name => 'PrioritySetupShutterRelease',
        PrintConv => {
            0 => 'AF',
            1 => 'Release',
        },
    },
    0x29 => { #7
        Name => 'AFIlluminator',
        PrintConv => {
            0 => 'Auto',
            1 => 'Off',
        },
    },
    0x2a => { #7
        Name => 'AFWithShutter',
        PrintConv => { 0 => 'On', 1 => 'Off' },
    },
    0x2b => { #7
        Name => 'LongExposureNoiseReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x2c => { #7
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
            3 => 'Off',
        },
    },
    0x2d => { #7
        Name => 'ImageStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait', #PH
            4 => 'Landscape', #PH
            5 => 'Sunset', #PH
            7 => 'Night View/Portrait', #PH (A200/A350 when CreativeStyle was 6!)
            8 => 'B&W', #PH (guess)
            9 => 'Adobe RGB',
            11 => 'Neutral',
            129 => 'StyleBox1',
            130 => 'StyleBox2',
            131 => 'StyleBox3',
            132 => 'StyleBox4', #JR (A850)
            133 => 'StyleBox5', #JR (A850)
            134 => 'StyleBox6', #JR (A850)
        },
    },
    0x2e => { #JR (may not apply to A200/A300/A350 -- they don't have the AF/MF button)
        Name => 'FocusModeSwitch',
        PrintConv => {
            0 => 'AF',
            1 => 'Manual',
        },
    },
    0x2f => { #JR
        Name => 'ShutterSpeedSetting',
        Notes => 'used in M, S and Program Shift S modes',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x30 => { #JR
        Name => 'ApertureSetting',
        Notes => 'used in M, A and Program Shift A modes',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x3c => {
        Name => 'ExposureProgram',
        SeparateTable => 'ExposureProgram',
        PrintConv => \%sonyExposureProgram,
    },
    0x3d => {
        Name => 'ImageStabilizationSetting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x3e => { #JR
        Name => 'FlashAction',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
            2 => 'External Flash, Did not fire',
            3 => 'External Flash, Fired',
        },
    },
    0x3f => { # (verified for A330/A380)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW', #(NC)
            2 => 'Rotate 270 CW',
        },
    },
    0x40 => { #JR
        Name => 'AELock',
        PrintConv => {
            1 => 'Off',
            2 => 'On',
        },
    },
    0x4c => { #JR
        Name => 'FlashAction2',
        PrintConv => {
            1 => 'Fired, Autoflash',
            2 => 'Fired, Fill-flash',
            3 => 'Fired, Rear Sync',
            4 => 'Fired, Wireless',
            5 => 'Did not fire',
            6 => 'Fired, Slow Sync',
            17 => 'Fired, Autoflash, Red-eye reduction',
            18 => 'Fired, Fill-flash, Red-eye reduction',
            34 => 'Fired, Fill-flash, HSS',
        },
    },
    0x4d => { #JR
        Name => 'FocusMode', # (focus mode actually used)
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
            4 => 'DMF', #JR
        },
    },
    0x50 => { #JR
        Name => 'BatteryState',
        PrintConv => {
            2 => 'Empty',      # 0%
            3 => 'Very Low',   # 1 - 20%
            4 => 'Low',        # 21 - 50%
            5 => 'Sufficient', # 51 - 80%
            6 => 'Full',       # > 80%
        },
    },
    0x51 => { #JR
        Name => 'BatteryLevel',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
    0x53 => { #JR
        Name => 'FocusStatus',
        PrintConv => {
            0 => 'Not confirmed',
            4 => 'Not confirmed, Tracking',
            BITMASK => {
                0 => 'Confirmed',
                1 => 'Failed',
                2 => 'Tracking',
            },
        },
    },
    0x54 => {
        Name => 'SonyImageSize',
        PrintConv => {
            1 => 'Large',
            2 => 'Medium',
            3 => 'Small',
        },
    },
    0x55 => { #7
        Name => 'AspectRatio',
        PrintConv => {
            1 => '3:2',
            2 => '16:9',
        },
    },
    0x56 => { #PH/7
        Name => 'Quality',
        PrintConv => {
            0 => 'RAW',
            2 => 'CRAW',
            34 => 'RAW + JPEG',
            35 => 'CRAW + JPEG',
            16 => 'Extra Fine',
            32 => 'Fine',
            48 => 'Standard',
        },
    },
    0x58 => { #7
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            33 => '1/3 EV',
            50 => '1/2 EV',
        },
    },
    0x6a => { #JR
        Name => 'RedEyeReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x9a => { #JR
        Name => 'FolderNumber',
        Mask => 0x03ff, # (not sure what the upper 6 bits are for)
        PrintConv => 'sprintf("%.3d",$val)',
        PrintConvInv => '$val',
    },
    0x9b => { #JR
        Name => 'ImageNumber',
        Mask => 0x3fff, # (not sure what the upper 2 bits are for)
        PrintConv => 'sprintf("%.4d",$val)',
        PrintConvInv => '$val',
    },
);

# Camera settings (ref PH) (A230, A290, A330, A380 and A390)
%Image::ExifTool::Sony::CameraSettings2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    PRIORITY => 0,
    NOTES => 'Camera settings for the A230, A290, A330, A380 and A390.',
### 0x00-0x03: same TagID as CameraSettings
    0x00 => { #JR
        Name => 'ExposureTime',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x01 => { #JR
        Name => 'FNumber',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x02 => { #JR (requires external flash)
        Name => 'HighSpeedSync',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x03 => { #JR
        Name => 'ExposureCompensationSet',
        ValueConv => '($val - 128) / 24',
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
### 0x04-0x11: subtract 1 from CameraSettings TagID
    0x04 => { #JR
        Name => 'WhiteBalanceSetting',
        PrintConv => {
            2 => 'Auto',
            4 => 'Daylight',
            5 => 'Fluorescent',
            6 => 'Tungsten',
            7 => 'Flash',
            16 => 'Cloudy',
            17 => 'Shade',
            18 => 'Color Temperature/Color Filter',
            32 => 'Custom 1',
            33 => 'Custom 2',
            34 => 'Custom 3',
        },
    },
    0x05 => { #JR
        Name => 'WhiteBalanceFineTune',
        ValueConv => '$val > 128 ? $val - 256 : $val',
    },
    0x06 => { #JR as set in WB "Color Temperature/Color Filter" and in White Balance Bracketing
        Name => 'ColorTemperatureSet',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '"$val K"',
        PrintConvInv => '$val =~ s/ ?K$//i; $val',
    },
    0x07 => { #JR as set in WB "Color Temperature/Color Filter"
        Name => 'ColorCompensationFilterSet',
        Notes => 'negative is green, positive is magenta',
        ValueConv => '$val > 128 ? $val - 256 : $val',
        ValueConvInv => '$val < 0 ? $val + 256 : $val',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x08 => { #JR
        Name => 'CustomWB_RGBLevels',
        Format => 'int16u[3]',
    },
    0x0b => { #JR as set in WB "Custom" and in White Balance Bracketing
        Name => 'ColorTemperatureCustom',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '"$val K"',
        PrintConvInv => '$val =~ s/ ?K$//i; $val',
    },
    0x0c => { #JR as set in WB "Custom"
        Name => 'ColorCompensationFilterCustom',
        Notes => 'negative is green, positive is magenta',
        ValueConv => '$val > 128 ? $val - 256 : $val',
        ValueConvInv => '$val < 0 ? $val + 256 : $val',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x0e => { #JR
        Name => 'WhiteBalance',
        PrintConv => {
            2 => 'Auto',
            4 => 'Daylight',
            5 => 'Fluorescent',
            6 => 'Tungsten',
            7 => 'Flash',
            12 => 'Color Temperature',
            13 => 'Color Filter',
            14 => 'Custom',
            16 => 'Cloudy',
            17 => 'Shade',
        },
    },
    0x0f => { #JR/PH (educated guess)
        Name => 'FocusModeSetting',
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
            # seen 5 for A380 (FocusMode was Manual and FocusStatus was Confirmed)
        },
    },
    0x10 => { #JR/PH (educated guess)
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x11 => { #JR/PH (educated guess)
        Name => 'AFPointSetting',
        Format => 'int16u',
        # The AF point as selected by the user in AFAreaMode=Local or Spot;
        # Reported value remains at the last-set position in AFAreaModes=Wide.
        # (all of these cameras have a 9-point centre-cross AF system, ref JR)
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Right',
            5 => 'Lower-right',
            6 => 'Bottom',
            7 => 'Lower-left',
            8 => 'Left',
            9 => 'Upper-left',
        },
    },
### 0x12-0x18: subtract 2 from CameraSettings TagID
    0x12 => { #JR
        Name => 'FlashExposureCompSet',
        Description => 'Flash Exposure Comp. Setting',
        # (as pre-selected by the user, not zero if flash didn't fire)
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x13 => {
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted Average',
            4 => 'Spot',
        },
    },
    0x14 => { # A330/A380
        Name => 'ISOSetting',
        # 0 indicates 'Auto' (?)
        ValueConv => '$val ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '$val ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => '$val ? sprintf("%.0f",$val) : "Auto"',
        PrintConvInv => '$val =~ /auto/i ? 0 : $val',
    },
    0x16 => {
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced Auto',
            3 => 'Advanced Level',
        },
    },
    0x17 => 'DynamicRangeOptimizerLevel',
    0x18 => { # A380
        Name => 'CreativeStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'Sunset',
            6 => 'Night View/Portrait',
            8 => 'B&W',
            # (these models don't have Neutral - PH)
        },
    },
### 0x19-0x1b: subtract 3 from CameraSettings TagID
    0x19 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1a => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x1b => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
### 0x1c-0x24: subtract 4 from CameraSettings TagID (not sure about 0x1c)
    0x1f => { #PH (educated guess)
        Name => 'FlashControl',
        PrintConv => {
            0 => 'ADI',
            1 => 'Pre-flash TTL',
            2 => 'Manual',
        },
    },
### 0x25-0x27: subtract 6 from CameraSettings TagID
    0x25 => { #PH
        Name => 'LongExposureNoiseReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x26 => { #PH
        Name => 'HighISONoiseReduction',
        # (Note: the order is different from that in CameraSettings)
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Normal',
            3 => 'High',
        },
    },
    0x27 => { #PH
        Name => 'ImageStyle',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Standard',
            2 => 'Vivid',
            3 => 'Portrait', #PH
            4 => 'Landscape', #PH
            5 => 'Sunset', #PH
            7 => 'Night View/Portrait', #PH (A200 when CreativeStyle was 6!)
            8 => 'B&W', #PH (A380)
            # (these models don't have Neutral - PH)
        },
    },
### 0x28-0x3b: subtract 7 from CameraSettings TagID
    0x28 => { #PH
        Name => 'ShutterSpeedSetting',
        Notes => 'used in M, S and Program Shift S modes',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x29 => { #PH
        Name => 'ApertureSetting',
        Notes => 'used in M, A and Program Shift A modes',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
### 0x3c-0x59: same TagID as CameraSettings
    0x3c => {
        Name => 'ExposureProgram',
        SeparateTable => 'ExposureProgram',
        PrintConv => \%sonyExposureProgram,
    },
    0x3d => { # (copied from CameraSettings, ref JR)
        Name => 'ImageStabilizationSetting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x3e => { #JR
        Name => 'FlashAction',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
            2 => 'External Flash, Did not fire',
            3 => 'External Flash, Fired',
        },
    },
    0x3f => { # (verified for A330/A380)
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW', #(NC)
            2 => 'Rotate 270 CW',
        },
    },
    0x40 => { #JR
        Name => 'AELock',
        PrintConv => {
            1 => 'Off',
            2 => 'On',
        },
    },
    0x4c => { #JR
        Name => 'FlashAction2',
        PrintConv => {
            1 => 'Fired, Autoflash',
            2 => 'Fired, Fill-flash',
            3 => 'Fired, Rear Sync',
            4 => 'Fired, Wireless',
            5 => 'Did not fire',
            6 => 'Fired, Slow Sync',
            17 => 'Fired, Autoflash, Red-eye reduction',
            18 => 'Fired, Fill-flash, Red-eye reduction',
            34 => 'Fired, Fill-flash, HSS',
        },
    },
    0x4d => { #JR
        Name => 'FocusMode', # (focus mode actually used)
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x53 => { #JR (copied from CameraSettings, but all bits may not be applicable for these models)
        Name => 'FocusStatus',
        PrintConv => {
            0 => 'Not confirmed',
            4 => 'Not confirmed, Tracking',
            BITMASK => {
                0 => 'Confirmed',
                1 => 'Failed',
                2 => 'Tracking',
            },
        },
    },
    0x54 => {
        Name => 'SonyImageSize',
        PrintConv => {
            1 => 'Large',
            2 => 'Medium',
            3 => 'Small',
        },
    },
    0x55 => { # (copied from CameraSettings, ref JR)
        Name => 'AspectRatio',
        PrintConv => {
            1 => '3:2',
            2 => '16:9',
        },
    },
    0x56 => { # (copied from CameraSettings, ref JR)
        Name => 'Quality',
        PrintConv => {
            0 => 'RAW',
            2 => 'CRAW',
            34 => 'RAW + JPEG',
            35 => 'CRAW + JPEG',
            16 => 'Extra Fine',
            32 => 'Fine',
            48 => 'Standard',
        },
    },
    0x58 => { # (copied from CameraSettings, ref JR)
        Name => 'ExposureLevelIncrements',
        PrintConv => {
            33 => '1/3 EV',
            50 => '1/2 EV',
        },
    },
### 0x5a onwards: subtract 1 from CameraSettings TagID
    # (0x69 not confirmed)
    #0x69 => { #JR
    #    Name => 'RedEyeReduction',
    #    PrintConv => {
    #        0 => 'Off',
    #        1 => 'On',
    #    },
    #},
    0x7e => { #JR
        Name => 'DriveMode',
        Mask => 0xff, # (not sure what upper byte is for)
        PrintConv => { # (values confirmed for specified models - PH)
            0x01 => 'Single Frame', # (A230,A330,A380)
            0x02 => 'Continuous High', #PH (A230,A330)
            0x04 => 'Self-timer 10 sec', # (A230)
            0x05 => 'Self-timer 2 sec, Mirror Lock-up', # (A230,A290,A330,A380,390)
            0x07 => 'Continuous Bracketing', # (A230 val=0x1107, A330 val=0x1307 [0.7 EV])
            0x0a => 'Remote Commander', # (A230)
            0x0b => 'Continuous Self-timer', # (A230 val=0x800b [5 shots], A330 val=0x400b [3 shots])
        },
    },
    0x7f => { #JR
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Autoflash',
            2 => 'Rear Sync',
            3 => 'Wireless',
            4 => 'Fill-flash',
            5 => 'Flash Off',
            6 => 'Slow Sync',
        },
    },
    0x83 => { #PH
        Name => 'ColorSpace',
        PrintConv => {
            5 => 'Adobe RGB',
            6 => 'sRGB',
        },
    },
);

# more Camera settings (ref PH)
# This was decoded for the A55, but it seems to apply to the following models:
# A33, A35, A55, A450, A500, A550, A560, A580, NEX-3, NEX-5, NEX-C3 and NEX-VG10E
%Image::ExifTool::Sony::CameraSettings3 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int8u',
    PRIORITY => 0,
    DATAMEMBER => [ 0x99 ],
    NOTES => q{
        Camera settings for models such as the A33, A35, A55, A450, A500, A550,
        A560, A580, NEX-3, NEX-5, NEX-C3 and NEX-VG10E.
    },
    0x00 => { #JR
        Name => 'ShutterSpeedSetting',
        Notes => 'used only in M and S exposure modes',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x01 => { #JR
        Name => 'ApertureSetting',
        Notes => 'used only in M and A exposure modes',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x02 => {
        Name => 'ISOSetting',
        ValueConv => '($val and $val < 254) ? exp(($val/8-6)*log(2))*100 : $val',
        ValueConvInv => '($val and $val != 254) ? 8*(log($val/100)/log(2)+6) : $val',
        PrintConv => {
            OTHER => sub {
                my ($val, $inv) = @_;
                return int($val + 0.5) unless $inv;
                return Image::ExifTool::IsFloat($val) ? $val : undef;
            },
            0 => 'Auto',
            254 => 'n/a', # get this for multi-shot noise reduction
        },
    },
    0x03 => { #JR
        Name => 'ExposureCompensationSet',
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x04 => { #JR
        Name => 'DriveModeSetting',
        # Same drivemode info is repeated in 0x0034, but with at least the following exceptions:
        # - 0x0034 not for A550 ? - seen "0"
        # - hand-held night   (0x05=56): 0x0004=0x10 and 0x0034=0xd3
        # - 3D sweep panorama (0x05=57): 0x0004=0x10 and 0x0034=0xd6
        # - sweep panorama    (0x05=80): 0x0004=0x10 and 0x0034=0xd5
        # preliminary conclusion: 0x0004 is Drivemode as pre-set, but may be overruled by Scene/Panorama mode selections
        #                         0x0034 is Divemode as actually used
        PrintHex => 1,
        PrintConv => {
            0x10 => 'Single Frame',
            0x21 => 'Continuous High', # also automatically selected for Scene mode Sports-action (0x05=52)
            0x22 => 'Continuous Low',
            0x30 => 'Speed Priority Continuous',
            0x51 => 'Self-timer 10 sec',
            0x52 => 'Self-timer 2 sec, Mirror Lock-up',
            0x71 => 'Continuous Bracketing 0.3 EV',
            0x75 => 'Continuous Bracketing 0.7 EV',
            0x91 => 'White Balance Bracketing Low',
            0x92 => 'White Balance Bracketing High',
            0xc0 => 'Remote Commander',
        },
    },
    0x05 => { #JR
        Name => 'ExposureProgram',
        # Camera exposure program/mode as selected with the Mode dial.
        # For SCN a further selection is done via the menu
        # Matches OK with 0xb023
        SeparateTable => 'ExposureProgram2',
        PrintConv => \%sonyExposureProgram2,
    },
    0x06 => { #JR
        Name => 'FocusModeSetting',
        PrintConv => {
            17 => 'AF-S',
            18 => 'AF-C',
            19 => 'AF-A',
            32 => 'Manual',
            48 => 'DMF', # (NC) (seen for NEX-5)
        },
    },
    0x07 => { #JR
        Name => 'MeteringMode',
        PrintConv => {
            1 => 'Multi-segment',
            2 => 'Center-weighted average',
            3 => 'Spot',
        },
    },
    0x09 => { #JR
        Name => 'SonyImageSize',
        PrintConv => {  # values confirmed as noted for the A580 and A33
           21 => 'Large (3:2)',    # A580: 16M  (4912x3264), A33: 14M  (4592x3056)
           22 => 'Medium (3:2)',   # A580: 8.4M (3568x2368), A33: 7.4M (3344x2224)
           23 => 'Small (3:2)',    # A580: 4.0M (2448x1624), A33: 3.5M (2288x1520)
           25 => 'Large (16:9)',   # A580: 14M  (4912x2760)
           26 => 'Medium (16:9)',  # A580: 7.1M (3568x2000)
           27 => 'Small (16:9)',   # A580: 3.4M (2448x1376)
        },
    },
    0x0a => { #JR
        Name => 'AspectRatio',
        # normally 4 for A580 3:2 ratio images
        # seen 8 when selecting 16:9 via menu, and when selecting Panorama mode
        PrintConv => {
            4 => '3:2',
            8 => '16:9',
        },
    },
    0x0b => { #JR
        Name => 'Quality',
        PrintConv => {
            2 => 'RAW',
            4 => 'RAW + JPEG',
            6 => 'Fine',
            7 => 'Standard',
        },
    },
    0x0c => {
        Name => 'DynamicRangeOptimizerSetting',
        PrintConv => {
            1 => 'Off',
            16 => 'On (Auto)',
            17 => 'On (Manual)',
        },
    },
    0x0d => 'DynamicRangeOptimizerLevel',
    0x0e => { #JR
        Name => 'ColorSpace',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
    0x0f => { #JR
        Name => 'CreativeStyleSetting',
        PrintConvColumns => 2,
        PrintConv => {
            16 => 'Standard',
            32 => 'Vivid',
            64 => 'Portrait',
            80 => 'Landscape',
            96 => 'B&W',
            160 => 'Sunset',
        },
    },
    0x10 => { #JR (seen values 253, 254, 255, 0, 1, 2, 3)
        Name => 'ContrastSetting',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x11 => { #JR
        Name => 'SaturationSetting',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x12 => { #JR
        Name => 'SharpnessSetting',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x16 => { #JR
        Name => 'WhiteBalanceSetting',
        # many guessed, based on "logical system" as observed for Daylight and Shade and steps of 16 between the modes
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => \%whiteBalanceSetting,
        SeparateTable => 1,
    },
    0x17 => { #JR
        Name => 'ColorTemperatureSetting',
        # matches "0xb021 ColorTemperature" when WB set to "Custom" or "Color Temperature/Color Filter"
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '"$val K"',
        PrintConvInv => '$val =~ s/ ?K$//i; $val',
    },
    0x18 => { #JR
        Name => 'ColorCompensationFilterSet',
        # seen 0, 1-9 and 245-255, corresponding to 0, M1-M9 and G9-G1 on camera display
        # matches "0xb022 ColorCompensationFilter" when WB set to "Custom" or "Color Temperature/Color Filter"
        Format => 'int8s',
        Notes => 'negative is green, positive is magenta',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x19 => { #JR
        Name => 'CustomWB_RGBLevels',
        Format => 'int16uRev[3]',
        # 0x19 - 0x1e are related to Custom WB measurements performed by the camera.
        # The values change only each time when measuring and setting a new Custom WB.
        # (0x19,0x1a) and (0x1d,0x1e) are same as MoreSettings (0x1a,0x1b) and (0x1c,0x1d)
    },
    # 0x1f - always 2 (ref JR)
    0x20 => { #JR
        Name => 'FlashMode',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Flash Off',
            16 => 'Autoflash',
            17 => 'Fill-flash',
            18 => 'Slow Sync',
            19 => 'Rear Sync',
            20 => 'Wireless',
        },
    },
    0x21 => { #JR
        Name => 'FlashControl',
        PrintConv => {
            1 => 'ADI Flash',
            2 => 'Pre-flash TTL',
        },
    },
    0x23 => { #JR
        Name => 'FlashExposureCompSet',
        Description => 'Flash Exposure Comp. Setting',
        # (as pre-selected by the user, not zero if flash didn't fire)
        ValueConv => '($val - 128) / 24', #PH
        ValueConvInv => 'int($val * 24 + 128.5)',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x24 => {
        Name => 'AFAreaMode',
        PrintConv => {
            1 => 'Wide',
            2 => 'Spot',
            3 => 'Local',
            4 => 'Flexible', #JR
            # (Flexible Spot is a grid of 17x11 points for the NEX-5)
        },
    },
    0x25 => { #JR
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            1 => 'Off',
            16 => 'On',  # (unused or dark subject)
        },
    },
    0x26 => { #JR
        Name => 'HighISONoiseReduction',
        PrintConv => {
            16 => 'Low',
            19 => 'Auto',
        },
    },
    0x27 => { #JR
        Name => 'SmileShutterMode',
        PrintConv => {
            17 => 'Slight Smile',
            18 => 'Normal Smile',
            19 => 'Big Smile',
        },
    },
    0x28 => { #JR
        Name => 'RedEyeReduction',
        PrintConv => {
            1 => 'Off',
            16 => 'On',
        },
    },
    0x2d => {
        Name => 'HDRSetting',
        PrintConv => {
            1 => 'Off',
            16 => 'On (Auto)',
            17 => 'On (Manual)',
        },
    },
    0x2e => {
        Name => 'HDRLevel',
        PrintConvColumns => 3,
        PrintConv => {
            33 => '1 EV',
            34 => '1.5 EV', #JR (NC)
            35 => '2 EV',
            36 => '2.5 EV', #JR (NC)
            37 => '3 EV',
            38 => '3.5 EV', #PH (NC)
            39 => '4 EV',
            40 => '5 EV',
            41 => '6 EV',
        },
    },
    0x2f => { #JR (not sure what is difference with 0x85)
        Name => 'ViewingMode',
        PrintConv => {
            16 => 'ViewFinder',
            33 => 'Focus Check Live View',
            34 => 'Quick AF Live View',
        },
    },
    0x30 => { #JR
        Name => 'FaceDetection',
        PrintConv => {
            1 => 'Off',
            16 => 'On',
        },
    },
    0x31 => { #JR
        Name => 'SmileShutter',
        PrintConv => {
            1 => 'Off',
            16 => 'On',
        },
    },
    0x32 => { #JR
        Name => 'SweepPanoramaSize',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            1 => 'Standard',
            2 => 'Wide',
        },
    },
    0x33 => { #JR
        Name => 'SweepPanoramaDirection',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            1 => 'Right',
            2 => 'Left',
            3 => 'Up',
            4 => 'Down',
        },
    },
    0x34 => { #JR
        Name => 'DriveMode', # (drive mode actually used)
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintHex => 1,
        PrintConv => {
            0x10 => 'Single Frame',
            0x21 => 'Continuous High', # also automatically selected for Scene mode Sports-action (0x05=52)
            0x22 => 'Continuous Low',
            0x30 => 'Speed Priority Continuous',
            0x51 => 'Self-timer 10 sec',
            0x52 => 'Self-timer 2 sec, Mirror Lock-up',
            0x71 => 'Continuous Bracketing 0.3 EV',
            0x75 => 'Continuous Bracketing 0.7 EV',
            0x91 => 'White Balance Bracketing Low',
            0x92 => 'White Balance Bracketing High',
            0xc0 => 'Remote Commander',
            0xd1 => 'Continuous - HDR',
            0xd2 => 'Continuous - Multi Frame NR',
            0xd3 => 'Continuous - Handheld Night Shot', # (also called "Hand-held Twilight")
            0xd4 => 'Continuous - Anti Motion Blur', #PH (NEX-5)
            0xd5 => 'Continuous - Sweep Panorama',
            0xd6 => 'Continuous - 3D Sweep Panorama',
        },
    },
    0x35 => {
        Name => 'MultiFrameNoiseReduction',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a', # seen for A450/A500/A550
            1 => 'Off',
            16 => 'On',
            255 => 'None', # seen for NEX-3/5/C3
        },
    },
    0x36 => { #JR (not 100% sure about this one)
        Name => 'LiveViewAFSetting',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
        PrintConv => {
            0 => 'n/a',
            1 => 'Phase-detect AF',
            2 => 'Contrast AF',
            # Contrast AF is only available with SSM/SAM lenses and in Focus Check LV,
            # NOT in Quick AF LV, and is automatically set when mounting SSM/SAM lens
            # - changes into Phase-AF when switching to Quick AF LV.
        },
    },
    0x38 => { #JR
        Name => 'PanoramaSize3D',
        Description => '3D Panorama Size',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            1 => 'Standard',
            2 => 'Wide',
            3 => '16:9',
        },
    },
    0x83 => { #JR
        Name => 'AFButtonPressed',
        # only indicates pressing and holding the "AF" button (centre-controller),
        # not pressing the shutter release button halfway down
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
        PrintConv => {
            1 => 'No',
            16 => 'Yes',
        },
    },
    0x84 => { #JR (not 100% sure about this one)
        Name => 'LiveViewMetering',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
        PrintConv => {
            0 => 'n/a',
            16 => '40 Segment',             # DSLR with LiveView/OVF switch in OVF position
            32 => '1200-zone Evaluative',   # SLT, or DSLR with LiveView/OVF switch in LiveView position
        },
    },
    0x85 => { #JR (not sure what is difference with 0x2f)
        Name => 'ViewingMode2',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
        PrintConv => {
            0 => 'n/a',
            16 => 'Viewfinder',
            33 => 'Focus Check Live View',
            34 => 'Quick AF Live View',
        },
    },
    0x86 => { #JR
        Name => 'AELock',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
        PrintConv => {
            1 => 'On',
            2 => 'Off',
        },
    },
    0x87 => { #JR
        Name => 'FlashStatusBuilt-in',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)/',
        PrintConv => {
            1 => 'Off',
            2 => 'On',
        },
    },
    0x88 => { #JR
        Name => 'FlashStatusExternal',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)/',
        PrintConv => {
            1 => 'None',
            2 => 'Off',
            3 => 'On',
        },
    },
#    0x8a => { #JR
#        Name => 'LensAF',
#        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
#        PrintConv => {
#            1  => 'No',
#            16 => 'AF Lens',
#        },
#    },
    0x8b => { #JR
        Name => 'LiveViewFocusMode',
        Condition => '$$self{Model} !~ /^(NEX-|DSLR-(A450|A500|A550)$)/',
        PrintConv => {
            0 => 'n/a',
            1 => 'AF',
            16 => 'Manual',
        },
    },
#    0x8e => { #JR
#        Name => 'LensSAM',
#        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
#        PrintConv => {
#            1  => 'No',
#            16 => 'SAM Lens',
#        },
#    },
    0x99 => { #JR
        Name => 'LensMount',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val',
        PrintConv => {
            1  => 'Unknown',
            16 => 'A-mount',
            17 => 'E-mount',
        },
    },
#    0x9b => { #JR
#        Name => 'LensOSS',
#        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
#        PrintConv => {
#            1  => 'No',
#            16 => 'OSS Lens',
#            17 => 'OSS Lens (NEX-VG)', # active ?
#        },
#    },
    # 0x9c - 1; 2 for multi-shot modes
    0x10c => { #JR
        Name => 'SequenceNumber',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/', # seen 18 for A550, so better exclude ?
        # normally 0; seen 1,2,3 for bracketing, 6 for Handheld Night Shot, 3 for HDR, 6 for MFNR
        PrintConv => {
            0 => 'Single',
            255 => 'n/a',
            OTHER => sub { shift }, # pass all other numbers straight through
        },
    },
    # when reading 0x0114 - 0x0117 as int32u:
    # - upper 8 bits (0x0117): always value 4, meaning unknown
    # - next 10 bits: FolderNumber (max. 999 according to manual)
    # - last 14 bits: ImageNumber  (max 9999)
    0x0114 => { #JR
        Name => 'FolderNumber',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int32u',
        Mask => 0x00ffc000,
        ValueConv => '$val >> 14',
        ValueConvInv => '$val << 14',
        PrintConv => 'sprintf("%.3d",$val)',
        PrintConvInv => '$val',
    },
    276.1 => { #JR (0x0114.1)
        Name => 'ImageNumber',
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int32u',
        Mask => 0x00003fff,
        PrintConv => 'sprintf("%.4d",$val)',
        PrintConvInv => '$val',
    },
    0x200 => { #JR
        Name => 'ShotNumberSincePowerUp2',
        Notes => q{
            same as ShotNumberSincePowerUp for single-shot images, but includes all
            shots of the current image in multi-shot modes like HDR, panorama, and
            multi-frame noise reduction
        },
        # (includes all shutter actuations of the current shot)
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int32u',
    },
    0x283 => { #JR
        Name => 'AFButtonPressed',
        # only indicates pressing and holding the "AF" button (centre-controller),
        # not pressing the shutter release button halfway down
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            1 => 'No',
            16 => 'Yes',
        },
    },
    0x284 => { #JR (not 100% sure about this one)
        Name => 'LiveViewMetering',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            16 => '40 Segment',             # DSLR with LiveView/OVF switch in OVF position
            32 => '1200-zone Evaluative',   # DSLR with LiveView/OVF switch in LiveView position
        },
    },
    0x285 => { #JR (not sure what is difference with 0x2f)
        Name => 'ViewingMode2',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            16 => 'Viewfinder',
            33 => 'Focus Check Live View',
            34 => 'Quick AF Live View',
        },
    },
    0x286 => { #JR
        Name => 'AELock',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            1 => 'On',
            2 => 'Off',
        },
    },
    0x287 => { #JR
        Name => 'FlashStatusBuilt-in',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Notes => 'A450, A500 and A550',
        PrintConv => {
            1 => 'Off',
            2 => 'On',
        },
    },
    0x288 => { #JR
        Name => 'FlashStatusExternal',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Notes => 'A450, A500 and A550',
        PrintConv => {
            1 => 'None',
            2 => 'Off',
            3 => 'On',
        },
    },
    0x28b => { #JR
        Name => 'LiveViewFocusMode',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        PrintConv => {
            0 => 'n/a',
            1 => 'AF',
            16 => 'Manual',
        },
    },
    0x30c => { #JR
        Name => 'SequenceNumber',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Notes => 'A450, A500 and A550',
        # normally 0; seen 2 for HDR
        PrintConv => {
            0 => 'Single',
            255 => 'n/a',
            OTHER => sub { shift }, # pass all other numbers straight through
        },
    },
    0x314 => { #JR
        Name => 'ImageNumber',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int16u',
        Notes => 'A450, A500 and A550',
        Mask => 0x3fff, #PH (not sure what the upper 2 bits are for)
        PrintConv => 'sprintf("%.4d",$val)',
        PrintConvInv => '$val',
    },
    0x316 => { #JR
        Name => 'FolderNumber',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Notes => 'A450, A500 and A550',
        Format => 'int16u',
        Mask => 0x03ff, # (NC)
        PrintConv => 'sprintf("%.3d",$val)',
        PrintConvInv => '$val',
    },
    0x03f0 => {
        Name => 'LensE-mountVersion',
        Format => 'int16u',
        Condition => '($$self{Model} =~ /^NEX-/)',
        PrintConv => 'sprintf("%x.%.2x",$val>>8,$val&0xff)',
        PrintConvInv => 'my @a=split(/\./,$val);(hex($a[0])<<8)|hex($a[1])',
    },
    # maybe this wasn't right (ref JR)
    #0x03f3 => {
    #    Name => 'CameraE-mountVersion',
    #    Format => 'int16u',
    #    Condition => '($$self{Model} =~ /^NEX-/)',
    #    PrintConv => 'sprintf("%x.%.2x",$val>>8,$val&0xff)',
    #    PrintConvInv => 'my @a=split(/\./,$val);(hex($a[0])<<8)|hex($a[1])',
    #    # seen values 1.00, 1.01, 1.02, 1.03 and 1.04 for NEX-3/5/5C/C3/VG10/VG10E with various Firmware versions.
    #},
    0x03f4 => { #JR (NC)
        Name => 'LensFirmwareVersion',
        Format => 'int8u',
        Condition => '($$self{Model} =~ /^NEX-/)',
        PrintConv => 'sprintf("Ver.%.2x",$val)',
        PrintConvInv => '$val=~s/^Ver\.//; hex($val)',
    },
    0x3f7 => { #JR
        Name => 'LensType2',
        Condition => '($$self{Model} =~ /^NEX-/) and ($$self{LensMount} != 1)',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x400 => { #JR
        Name => 'ImageNumber',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int16u',
        Notes => 'A450, A500 and A550',
        Mask => 0x3fff, #PH (not sure what the upper 2 bits are for)
        PrintConv => 'sprintf("%.4d",$val)',
        PrintConvInv => '$val',
    },
    0x402 => { #JR
        Name => 'FolderNumber',
        Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)$/',
        Format => 'int16u',
        Mask => 0x03ff, # (NC)
        Notes => 'A450, A500 and A550',
        PrintConv => 'sprintf("%.3d",$val)',
        PrintConvInv => '$val',
    },
);

# Camera settings for other models
%Image::ExifTool::Sony::CameraSettingsUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
);

# extra hardware information (ref JR)
%Image::ExifTool::Sony::ExtraInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Extra hardware information for the A850 and A900.',
    # 0x0000: seen values 5 or 6
    0x0001 => {
        Name => 'BatteryTemperature',
        # seen values of appr. 55 - 115: looks like temperature Fahrenheit
        # changing battery in cold weather: new battery starts with value 53
        ValueConv => '($val - 32) / 1.8', # convert to Celsius
        ValueConvInv => '$val * 1.8 + 32',
        PrintConv => 'sprintf("%.1f C",$val)',
        PrintConvInv => '$val=~ s/\s*C//; $val',
        # (may be invalid for non-OEM batteries)
    },
    0x0002 => {
        Name => 'BatteryUnknown',
        # appears to be an int16u value together with 0x0005 (values similar to ExtraInfo3 0x0000)
        # seen values of appr. 800 at 23 deg C to 630 at 40 deg C for A850 with NP-FM500H battery (7.2 V nominal)
        # i.e. inversely proportional to BatteryTemperature: can not be BatteryVoltage, must be something else ?
        Unknown => 1,
        Format => 'undef[4]',
        ValueConv => sub {
            my $val = shift;;
            my @a = unpack("CvC",pack('v*', unpack('n*', $val)));
            return $a[1];
        },
    },
    # 0x0003: seen 0 or 16
    # 0x0004: always 255
    # 0x0006: int16u value together with 0x0009: same behaviour and almost same values as 0x0002
    # 0x0007: always 3
    0x0008 => {
        Name => 'BatteryVoltage',
        # 0x0008: int16u value together with 0x000b:
        # values follow BatteryLevel: from appr.900 when battery full, to appr. 775 when empty.
        # with factor 118 they range from appr. 7.6 to 6.6 - looks like battery voltage (nominal 7.2 V)
        Unknown => 1,
        Format => 'undef[4]',
        ValueConv => sub {
            my $val = shift;;
            my @a = unpack("CvC",pack('v*', unpack('n*', $val)));
            return $a[1]/118;
        },
        PrintConv => 'sprintf("%.2f V",$val)',
    },
    0x000a => {
        # seen mostly 213 and 246, corresponding with other ImageStabilization On/Off tags.
        Name => 'ImageStabilization2',
        Unknown => 1, # (because the decoding is funny and possibly incomplete - PH)
        PrintConv => {
            191 => 'On (191)', # seen a few times with moving subject, continuous drive, bracketing
            207 => 'On (207)', # seen once with RemoteCommander
            210 => 'On (210)', # seen a few times with continous drive
            213 => 'On',
            246 => 'Off',
        },
    },
    # 0x000c: seen always decreasing values, from max. 107 to min. 0,
    #   then jump back to high value: correlates with battery change/recharging
    #   Seen once 255 immediately after inserting new battery, next frame OK at 106.
    #   Validation: matches exactly with batterylevel display on camera (all 100+ values displayed as 100%)
    0x000c => {
        Name => 'BatteryLevel',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
    # 0x000d: always 2
    # 0x000e: always 204
    # 0x000f: always 0
    # 0x0010-0x0019: always 204
    0x001a => {
        Name => 'ExtraInfoVersion',
        Format => 'int8u[4]',
        PrintConv => '$val=~tr/ /./; $val',
        PrintConvInv => '$val=~tr/./ /; $val',
        # always 0 1 0 1 for 0x0131 Software = DSLR-A850 v1.00
        # always 0 2 0 4 for 0x0131 Software = DSLR-A850 v2.00
        # seen   0 2 0 0 for 0x0131 Software = DSLR-A900 v1.00
        # seen   0 4 0 0 for 0x0131 Software = DSLR-A900 v1.00
        # seen   0 5 0 4 for 0x0131 Software = DSLR-A900 v2.00
        # A850: correlates exactly with Firmware versions.
        # A900: have there been different FW 1.0 versions ?
    },
);

# extra hardware information (ref JR)
%Image::ExifTool::Sony::ExtraInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Extra hardware information for the A230/290/330/380/390.',
    0x0004 => {
        Name => 'BatteryLevel',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
    0x0012 => {
        Name => 'ImageStabilization',
        PrintConv => {
            0 => 'Off',
            64 => 'On',
        },
    },
);

# extra hardware information (ref JR)
%Image::ExifTool::Sony::ExtraInfo3 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Extra hardware information for the A33, A35, A55, A450, A500, A550, A560,
        A580 and NEX-3/5/C3/VG10.
    },
    0x0000 => {
        Name => 'BatteryUnknown',
        # seen values of appr. 870 at 10 deg C to 650 at 39 deg C for A580 with NP-FM500H battery (7.2 V nominal)
        # i.e. inversely proportional to BatteryTemperature: can not be BatteryVoltage, must be something else ?
        Unknown => 1,
        Format => 'int16u',
    },
    0x0002 => {
        Name => 'BatteryTemperature',
        ValueConv => '($val - 32) / 1.8', # convert to Celsius
        ValueConvInv => '$val * 1.8 + 32',
        PrintConv => 'sprintf("%.1f C",$val)',
        PrintConvInv => '$val=~ s/\s*C//; $val',
    },
    0x0004 => {
        Name => 'BatteryLevel',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
    # 0x0005:  always 255
    # from here on the differences between DSLR, SLT and NEX
    # 0x0006 and 0x0008:
    #   values follow BatteryLevel: start high (970, 940) when battery full,
    #   and decrease with decreasing battery level to (850, 815)
    #   with factor 128 they range from (7.6, 7.3) to (6.6, 6.4) - looks like battery voltage (nominal 7.2 V)
    0x0006 => {
        Name => 'BatteryVoltage1',
        Format => 'int16u',
        Condition => '$$self{Model} !~ /^(NEX-(3|5|5C|C3|VG10|VG10E))\b/',
        ValueConv => '$val / 128',
        ValueConvInv => '$val * 128',
        PrintConv => 'sprintf("%.2f V",$val)',
        PrintConvInv => '$val=~s/\s*V//; $val',
    },
    0x0008 => {
        Name => 'BatteryVoltage2',
        Format => 'int16u',
        Condition => '$$self{Model} !~ /^(NEX-(3|5|5C|C3|VG10|VG10E))\b/',
        ValueConv => '$val / 128',
        ValueConvInv => '$val * 128',
        PrintConv => 'sprintf("%.2f V",$val)',
        PrintConvInv => '$val=~s/\s*V//; $val',
    },
    # 0x000a - 0x000f: 3 int16u values: probably some mode or status info:
    # seen various 3-number-sequences for SLT and DSLR, but meaning unknown
    # 0x000a => {
    #     Name => 'ExtraInfo_000a',
    #     Format => 'int16u[3]',
    #     Condition => '$$self{Model} !~ /^(NEX-(3|5|5C|C3|VG10|VG10E))\b/',
    # },
    # 0x0010 seen:
    #     176 for SLT
    #     204 for NEX
    #     240 for DSLR
    0x0011 => {
        Name => 'ImageStabilization',
        Condition => '$$self{Model} !~ /^(NEX-(3|5|5C|C3|VG10|VG10E))\b/',
        # usually matches 0xb026 ImageStabilization, except some images with SelfTimer and on tripod
        PrintConv => {
            0 => 'Off',
            64 => 'On',
        },
    },
    0x0014 => [
        {
            Name => 'BatteryState',
            Condition => '$$self{Model} =~ /^SLT-/',
            # possibly relates to "simple" batterylevel indication with battery-icon, but not completely sure
            Notes => 'BatteryState for SLT models',
            PrintConv => {
                1 =>  'Empty',
                2 =>  'Low',
                3 =>  'Half full',
                4 =>  'Almost full',
                5 =>  'Full',
            },
        },{
            Name => 'ExposureProgram',
            Condition => '$$self{Model} =~ /^DSLR-(A450|A500|A550)\b/',
            Notes => 'ExposureProgram for the A450, A500 and A550',
            Priority => 0, # (some unknown values)
            PrintConv => {
                241 => 'Landscape',
                243 => 'Aperture-priority AE',
                245 => 'Portrait',
                246 => 'Auto',
                247 => 'Program AE',
                249 => 'Macro',
                252 => 'Sunset',
                253 => 'Sports', #PH (A550)
                255 => 'Manual',
                # missing: Shutter speed priority AE, No Flash, Night View
            },
        },{
            Name => 'ModeDialPosition',
            Condition => '$$self{Model} =~ /^DSLR-/',
            Notes => 'ModeDialPosition for other DSLR models',
            # (decoded from A560/A580)
            PrintConv => {
                248 => 'No Flash',
                249 => 'Aperture-priority AE',
                250 => 'SCN', # <-- the reason we don't call it ExposureProgram for these models
                251 => 'Shutter speed priority AE',
                252 => 'Auto',
                253 => 'Program AE',
                254 => 'Panorama',
                255 => 'Manual',
            },
        },
    ],
    # 0x0015: DSLR: appears to be a bitmask relating to "switch" positions:
    #   bit 0 (  1) only seen OFF for A580
    #   bit 1 (  2) ON = Flash down, OFF = Flash raised
    #   bit 2 (  4) only seen ON for A580
    #   bit 3 (  8) only seen ON for A580
    #   bit 4 ( 16) ON = AF,         OFF = MF
    #   bit 5 ( 32) ON = OVF,        OFF = LiveView
    #   bit 6 ( 64) seen ON and OFF, meaning unknown
    #   bit 7 (128) seen ON and OFF, meaning unknown
    # 0x0016: DSLR: seen 244,245,252,254, decoded for A580 with 32GB SD and 16GB MS cards
    # 0x0016: NEX:  seen 61,62,  125,126,  190: bits '64' and '128' appear to relate to CameraOrientation
    # 0x0016: SLT:  seen 64 - 78, meaning unknown
    0x0016 => [{
        Name => 'MemoryCardConfiguration',
        Condition => '$$self{Model} =~ /^DSLR-/',
        PrintConv => {
            244 => 'MemoryStick in use, SD card present',
            245 => 'MemoryStick in use, SD slot empty',
            252 => 'SD card in use, MemoryStick present',
            254 => 'SD card in use, MemoryStick slot empty',
        },
    },{
        Name => 'CameraOrientation',
        Condition => '$$self{Model} =~ /^(NEX-(3|5|5C|C3|VG10|VG10E))\b/',
        Mask => 0xc0, # (don't know what other bits mean)
        PrintConv => {
            0x00 =>  'Horizontal (normal)',
            0x40 =>  'Rotate 90 CW',
            0x80 =>  'Rotate 270 CW',
            0xc0 =>  'Rotate 180', # (NC)
        },

    }],
    # 0x0017: seen 0 for SLT, 255 for DSLR, variable for NEX
    0x0018 => {
        Name => 'CameraOrientation',
        Condition => '$$self{Model} !~ /^(NEX-(3|5|5C|C3|VG10|VG10E))\b/',
        Mask => 0x30, # (don't know what other bits mean)
        PrintConv => {
            0x00 =>  'Horizontal (normal)',
            0x10 =>  'Rotate 90 CW',
            0x20 =>  'Rotate 270 CW',
            0x30 =>  'Rotate 180',
        },
    },
    # 0x0019:
    #   A450/500/550:  0 - 12 and 233 - 255
    #   A560/580:  1 or 64, seen a few 0 and 8
    #   A33/35/55: seen 0, 1, 64
    #   NEX:       204
    # 0x001a, 0x001c appear to be 2 int16u values, meaning unknown
);

# shot information (ref PH)
%Image::ExifTool::Sony::ShotInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    DATAMEMBER => [ 0x02, 0x30, 0x32, 0x34 ],
    IS_SUBDIR => [ 0x48, 0x5e ],
    # 0x00 - byte order 'II'
    0x02 => {
        Name => 'FaceInfoOffset',
        Format => 'int16u',
        DataMember => 'FaceInfoOffset',
        Writable => 0,
        RawConv => '$$self{FaceInfoOffset} = $val',
    },
    0x06 => {
        Name => 'SonyDateTime',
        Format => 'string[20]',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x1a => { Name => 'SonyImageHeight', Format => 'int16u' }, #JR
    0x1c => { Name => 'SonyImageWidth',  Format => 'int16u' }, #JR
    0x30 => { #Jeffrey Friedl
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        Format => 'int16u',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x32 => {
        Name => 'FaceInfoLength', # length of a single FaceInfo entry
        DataMember => 'FaceInfoLength',
        Format => 'int16u',
        Writable => 0,
        RawConv => '$$self{FaceInfoLength} = $val',
    },
    0x34 => {
        # oldest/other DSC/other        -
        # older DSC models              "DC5303320222000" or "DC6303320222000"
        # DSC-W650/W690/W730            "THm101000000000" or "THm211000000000"
        # DSC-HX9V generation and newer "DC7303320222000"
        Name => 'MetaVersion', # (tentative)
        Format => 'string[16]',
        DataMember => 'MetaVersion',
        RawConv => '$$self{MetaVersion} = $val',
    },
    0x48 => { # (most models: DC5303320222000 and DC6303320222000)
        Name => 'FaceInfo1',
        Condition => q{
            $$self{FacesDetected} and
            $$self{FaceInfoOffset} == 0x48 and
            $$self{FaceInfoLength} == 0x20
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::FaceInfo1' },
    },
    0x5e => { # (HX7V: DC7303320222000)
        Name => 'FaceInfo2',
        Condition => q{
            $$self{FacesDetected} and
            $$self{FaceInfoOffset} == 0x5e and
            $$self{FaceInfoLength} == 0x25
        },
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::FaceInfo2' },
    },
);

# tags used in Tag2010 and Tag9400 tables
my %sequenceImageNumber = ( #PH
    Name => 'SequenceImageNumber',
    Notes => 'number of images captured in burst sequence',
    # (not shutter count because it increments for auto portrait framing)
    Format => 'int32u',
    ValueConv => '$val + 1',
    ValueConvInv => '$val - 1',
);
my %sequenceFileNumber = ( #PH
    Name => 'SequenceFileNumber',
    Notes => 'file number in burst sequence',
    Format => 'int32u',
    ValueConv => '$val + 1', #JR
    ValueConvInv => '$val - 1',
);
my %releaseMode2 = ( #JR
    Name => 'ReleaseMode2',
    SeparateTable => 'ReleaseMode2',
    PrintConv => {
        0 => 'Normal',
        1 => 'Continuous', # (RX100 "Continuous - Self-timer")
        2 => 'Continuous - Exposure Bracketing', # (RX100)
# 3 - also DRO Bracketing (ILCE-7RM2), not "Continuous" because only single exposure from which camera makes 3 versions
        3 => 'DRO or White Balance Bracketing', # (HX9V) (RX100) (ILCE-7RM2)
        5 => 'Continuous - Burst', # (HX9V)
        6 => 'Single Frame - Capture During Movie', #PH (RX100)
        7 => 'Continuous - Sweep Panorama',
        8 => 'Continuous - Anti-Motion Blur, Hand-held Twilight', # (HX9V)
        9 => 'Continuous - HDR',
        10 => 'Continuous - Background defocus', # (HX9V)
        13 => 'Continuous - 3D Sweep Panorama', #PH/JR
        15 => 'Continuous - High Resolution Sweep Panorama', #JR (HX50V)
        16 => 'Continuous - 3D Image', # (HX9V)
        17 => 'Continuous - Burst 2', # (WX7 - PH) (#JR 9400-SequenceLength=10 shots)
       # 18 - seen for several ILCE-7S v2.00 iAuto+ single-shot images ...
        19 => 'Continuous - Speed/Advance Priority', #PH/JR (RX100)
        20 => 'Continuous - Multi Frame NR',
        23 => 'Single-frame - Exposure Bracketing', # (seen for ILCE-7 series)
        26 => 'Continuous Low', #PH (A77)
        27 => 'Continuous - High Sensitivity',  # seen for DSC-WX60 and WX300
        28 => 'Smile Shutter', #PH (RX100)
        29 => 'Continuous - Tele-zoom Advance Priority',
       # 30 - seen quite often for single-shot images ...
        146 => 'Single Frame - Movie Capture', #PH (seen in Tag2010 ReleaseMode2 values)
    },
);

# tag definitions for Tag2010 tables (ref JR)
my %sonyDateTime2010 = (
    Name => 'SonyDateTime',
    Format => 'undef[7]',
    Shift => 'Time',
    ValueConv => q{
        my @v = unpack('vC*', $val);
        return sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d", @v)
    },
    ValueConvInv => q{
        my @v = ($val =~ /\d+/g);
        return undef unless @v == 6;
        return pack('vC*', @v);
    },
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val,0)',
);
my %releaseMode2010 = (
    Name => 'ReleaseMode3',
    PrintConv => {
        0 => 'Normal',
        1 => 'Continuous',
        2 => 'Bracketing', # (all types: Continuous and Single-Frame Exposure, White Balance and DRO bracketing - PH/JR)
        # 3 => 'Remote Commander', (NC) (seen this when other ReleaseMode and ReleaseMode2 are 'Normal' - PH, A77)
        4 => 'Continuous - Burst', # seen for DSC-WX500 with burst of 10 shots
        5 => 'Continuous - Speed/Advance Priority',
        # 6 => '???', # seen for ILCE-6300
    },
);
my %selfTimer2010 = (
    Name => 'SelfTimer',
    PrintConv => {
        0 => 'Off',
        1 => 'Self-timer 10 s',
        2 => 'Self-timer 2 s',
    },
);
my %selfTimerB2010 = (  # also value 1 for new 5 s mode of DSC-HX90V/RX10M2/RX100M4/WX500, ILCE-7RM2/7SM2
    Name => 'SelfTimer',
    PrintConv => {
        0 => 'Off',
        1 => 'Self-timer 5 or 10 s',
        2 => 'Self-timer 2 s',
    },
);
my %gain2010 = (
    Name => 'StopsAboveBaseISO',
    # BaseISO is 100 for SLT, ILCE-3000, NEX-5N/5R/5T/6/7/VG20/VG30/VG900, DSC-RX1/RX1R
    # BaseISO is 200 for NEX-F3/3N
    # BaseISO is 160 for DSC-RX100M2
    # BaseISO is 125 for DSC-RX100
    # Also several other DSC models have BaseISO different from 100.
    Format => 'int16u',
    ValueConv => '16 - $val/256',
    ValueConvInv => '(16 - $val) * 256',
    PrintConv => '$val ? sprintf("%.1f",$val) : $val',
    PrintConvInv => '$val',
);
my %brightnessValue2010 = (
    Name => 'BrightnessValue',
    Format => 'int16u',
    ValueConv => '$val/256 - 56.6',
    ValueConvInv => '($val + 56.6) * 256',
);
my %dynamicRangeOptimizer2010 = (
    Name => 'DynamicRangeOptimizer',
    PrintConv => {
        0 => 'Off',
        1 => 'Auto',
        3 => 'Lv1',
        4 => 'Lv2',
        5 => 'Lv3',
        6 => 'Lv4',
        7 => 'Lv5',
        8 => 'n/a',
    },
);
my %hdr2010 = (
    Name => 'HDRSetting', # (Off when HDR tag is On for RX100 superior auto backlight - PH)
    PrintConv => {
        0 => 'Off',
        1 => 'HDR Auto',
        3 => 'HDR 1 EV',
        5 => 'HDR 2 EV',
        7 => 'HDR 3 EV',
        9 => 'HDR 4 EV',
        11 => 'HDR 5 EV',
        13 => 'HDR 6 EV',
    },
);
my %exposureComp2010 = ( # only as set manually, remains 0 in exposure-bracketing modes
    Name => 'ExposureCompensation',
    Format=>'int16s',
    ValueConv => '-$val/256',
    ValueConvInv => '-$val*256',
    PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
    PrintConvInv => '$val',
);
my %pictureEffect2010 = (
    Name => 'PictureEffect2',
    SeparateTable => 'PictureEffect2',
    PrintConv => {
        0 => 'Off',
        1 => 'Toy Camera',
        2 => 'Pop Color',
        3 => 'Posterization',
        4 => 'Retro Photo',
        5 => 'Soft High Key',
        6 => 'Partial Color',
        7 => 'High Contrast Monochrome',
        8 => 'Soft Focus',
        9 => 'HDR Painting',
        10 => 'Rich-tone Monochrome',
        11 => 'Miniature',
        12 => 'Water Color',
        13 => 'Illustration',
    },
);
my %quality2010 = (
    Name => 'Quality2',
    PrintConv => {
        0 => 'JPEG',
        1 => 'RAW',
        2 => 'RAW + JPEG',
    },
);
my %meteringMode2010 = (
    Name => 'MeteringMode',
    PrintConv => {
        0 => 'Multi-segment',
        2 => 'Center-weighted average',
        3 => 'Spot',
    },
);
my %flashMode2010 = (
    Name => 'FlashMode',
    PrintConv => {
        0 => 'Autoflash',
        1 => 'Fill-flash',
        2 => 'Flash Off',
        3 => 'Slow Sync',
        4 => 'Rear Sync',
        6 => 'Wireless',
    },
);
my %exposureProgram2010 = (
    Name => 'ExposureProgram',
    SeparateTable => 'ExposureProgram3',
    PrintConv => \%sonyExposureProgram3,
);
my %pictureProfile2010 = (
    Name => 'PictureProfile',
    # values 0-9:    Seen for all cameras writing this tag: matches CreativeStyle and/or SceneMode settings.
    # 10 and higher: Seen for ILCE-7S/7M2 and newer, having a PictureProfile setting, also some DSC/HDR models.
    #                Although intended for video, when set these profiles are also applied to (JPG) still images.
    PrintConv => {
        0 => 'Standard/Neutral - Gamma Still (PP2)', # CreativeStyle = Standard or Neutral
        1 => 'Portrait',
        3 => 'Night View/Portrait',
        4 => 'B&W/Sepia',
        5 => 'Clear',
        6 => 'Deep',
        7 => 'Light',
        8 => 'Vivid', # SceneMode or CreativeStyle =  Vivid, Autumn, Sunset or Landscape
        9 => 'Real',
        10 => 'Gamma Movie (PP1)',
        22 => 'Gamma ITU709 (PP3)',
        23 => 'ColorTone ITU709 (PP4)', # seen for HDR-CX130E
        24 => 'Gamma Cine1 (PP5)',
        25 => 'Gamma Cine2 (PP6)',
        26 => 'Gamma Cine3',
        27 => 'Gamma Cine4',
        28 => 'Gamma S-Log2 (PP7)',
        29 => 'Gamma ITU709(800%)',
    },
);

%Image::ExifTool::Sony::Tag2010a = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => 'Valid for NEX-5N.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x04b0 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x1128 => { %releaseMode2010 },
    0x112c => { %releaseMode2 },
    0x1134 => { %selfTimer2010 },
    0x1138 => { %flashMode2010 },
    0x113e => { %gain2010 },
    0x1140 => { %brightnessValue2010 },
    0x1144 => { %dynamicRangeOptimizer2010 },
    0x1148 => { %hdr2010 },
    0x114c => { %exposureComp2010 },
    0x115e => { %pictureProfile2010 },
    0x115f => { %pictureProfile2010 },
    0x1163 => { %pictureEffect2010 },
    0x1170 => { %quality2010 },
    0x1174 => { %meteringMode2010 },
    0x1175 => { %exposureProgram2010 },
    0x117c => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    #0x1a08 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1a0c => { Name => 'SonyImageHeight', Format => 'int16u' },
);

%Image::ExifTool::Sony::Tag2010b = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => 'Valid for SLT-A65/A77, NEX-7/VG20E.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0000 => { %sequenceImageNumber }, #PH
    0x0004 => { %sequenceFileNumber }, #PH
    0x0008 => { %releaseMode2, Format => 'int32u' },
    #0x0044 => { Name => 'SonyImageWidth3',  Format => 'int16u' },
    #0x0048 => { Name => 'SonyImageHeight3', Format => 'int16u' },
    #0x0054 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x0058 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x0064 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x0068 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x00a8 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00ac => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00b8 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00bc => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00c8 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x00cc => { Name => 'SonyImageHeight',  Format => 'int16u' },
    0x01b6 => { %sonyDateTime2010, Groups => { 2 => 'Time' } },
    #0x0204 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x0206 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    0x0324 => { %dynamicRangeOptimizer2010 },
    0x04b4 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x1128 => { %releaseMode2010 },
    0x112c => { %releaseMode2 },
    0x1134 => { %selfTimer2010 },
    0x1138 => { %flashMode2010 },
    0x113e => { %gain2010 },
    0x1140 => { %brightnessValue2010 },
    0x1144 => { %dynamicRangeOptimizer2010 },
    0x1148 => { %hdr2010 },
    0x114c => { %exposureComp2010 },
    0x1162 => { %pictureProfile2010 },
    0x1163 => { %pictureProfile2010 },
    0x1167 => { %pictureEffect2010 },
    0x1174 => { %quality2010 },
    0x1178 => { %meteringMode2010 },     #1154
    0x1179 => { %exposureProgram2010 },
    0x1180 => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    0x1218 => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    #0x1a08 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1a0c => { Name => 'SonyImageHeight', Format => 'int16u' },
    0x1a23 => { # only for NEX-7 with Firmware v1.02 and higher, but slightly different from Tag9405 ...
        Name => 'LensParameters',
        Format => 'int16s[16]',
        PrintConv => 'sprintf("%5d" . " %5d" x 15, split(" ",$val))',
    },
);

%Image::ExifTool::Sony::Tag2010c = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => 'Valid for SLT-A37/A57 and NEX-F3.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0000 => { %sequenceImageNumber }, #PH
    0x0004 => { %sequenceFileNumber }, #PH
    0x0008 => { %releaseMode2, Format => 'int32u' },
    #0x0048 => { Name => 'SonyImageWidth3',  Format => 'int16u' },
    #0x004c => { Name => 'SonyImageHeight3', Format => 'int16u' },
    #0x0058 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x005c => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x0068 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x006c => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x00c0 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00c4 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00d0 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00d4 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00e0 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x00e4 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x0134 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x0144 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x0154 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    0x0200 => { Name => 'DigitalZoomRatio', ValueConv => '$val/16', ValueConvInv => '$val*16', Priority => 0 },
    0x0210 => { %sonyDateTime2010, Groups => { 2 => 'Time' } },
    0x0300 => { %dynamicRangeOptimizer2010 },
    0x0490 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x1104 => { %releaseMode2010 },
    0x1108 => { %releaseMode2 },
    0x1110 => { %selfTimer2010 },
    0x1114 => { %flashMode2010 },
    0x111a => { %gain2010 },
    0x111c => { %brightnessValue2010 },
    0x1120 => { %dynamicRangeOptimizer2010 },
    0x1124 => { %hdr2010 },
    0x1128 => { %exposureComp2010 },
    0x113e => { %pictureProfile2010 },
    0x113f => { %pictureProfile2010 },
    0x1143 => { %pictureEffect2010 },
    0x1150 => { %quality2010 },
    0x1154 => { %meteringMode2010 },
    0x1155 => { %exposureProgram2010 },
    0x115c => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    0x11f4 => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    #0x1a08 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1a0c => { Name => 'SonyImageHeight', Format => 'int16u' },
);

%Image::ExifTool::Sony::Tag2010d = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => q{
        Valid for DSC-HX10V/HX20V/HX200V/TX66/TX200V/TX300V/WX50/WX100/WX150, but
        not valid for panorama images.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0000 => { %sequenceImageNumber }, #PH
    0x0004 => { %sequenceFileNumber }, #PH
    0x0008 => { %releaseMode2, Format => 'int32u' },
    #0x0048 => { Name => 'SonyImageWidth3',  Format => 'int16u' },
    #0x004c => { Name => 'SonyImageHeight3', Format => 'int16u' },
    #0x0058 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x005c => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x0068 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x006c => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x00c0 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00c4 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00d0 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00d4 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00e0 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x00e4 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    0x01fe => { %sonyDateTime2010, Groups => { 2 => 'Time' } },
    0x037c => { %dynamicRangeOptimizer2010 },
    0x050c => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x1180 => { %releaseMode2010 },
    0x1184 => { %releaseMode2 },
    0x118c => { %selfTimer2010 },
    0x1190 => { %flashMode2010 },
    0x1196 => { %gain2010 },
    0x1198 => { %brightnessValue2010 },
    0x119c => { %dynamicRangeOptimizer2010 },
    0x11a0 => { %hdr2010 },
    0x11ba => { %pictureProfile2010 },
    0x11bb => { %pictureProfile2010 },
    0x11bf => { %pictureEffect2010 },
    0x11d0 => { %meteringMode2010 },
    # 0x11d1 - not valid for HX20V panorama images - PH
    0x11d1 => { %exposureProgram2010 },
    0x11d8 => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    0x1270 => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
);

%Image::ExifTool::Sony::Tag2010e = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => q{
        Valid for SLT-A58/A99, ILCE-3000/3500, NEX-3N/5R/5T/6/VG30E/VG900, DSC-RX100,
        DSC-RX1/RX1R. Also valid for DSC-HX300/HX50V/TX30/WX60/WX200/WX300, but not
        for panorama images.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0000 => { %sequenceImageNumber }, #PH
    0x0004 => { %sequenceFileNumber }, #PH
    0x0008 => { %releaseMode2, Format => 'int32u' },
    #0x0048 => { Name => 'SonyImageWidth3',  Format => 'int16u' },
    #0x004c => { Name => 'SonyImageHeight3', Format => 'int16u' },
    #0x0058 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x005c => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x0068 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x006c => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x00c0 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00c4 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00d0 => { Name => 'SonyImageWidth2',  Format => 'int16u' },
    #0x00d4 => { Name => 'SonyImageHeight2', Format => 'int16u' },
    #0x00e0 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    #0x00e4 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x01fa => { Name => 'SonyImageHeight',  Format => 'int16u' },
    #0x0200 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    0x021c => { Name => 'DigitalZoomRatio', ValueConv => '$val/16', ValueConvInv => '$val*16', Priority => 0 },
    0x022c => { %sonyDateTime2010, Groups => { 2 => 'Time' } },
    0x0328 => { %dynamicRangeOptimizer2010 },
    0x04b8 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x115c => { %releaseMode2010 },
    0x1160 => { %releaseMode2 },
    0x1168 => { %selfTimer2010 },
    0x116c => { %flashMode2010 },
    0x1172 => { %gain2010 },
    0x1174 => { %brightnessValue2010 },
    0x1178 => { %dynamicRangeOptimizer2010 },
    0x117c => { %hdr2010 },
    0x1180 => { %exposureComp2010 },
    0x1196 => { %pictureProfile2010 },
    0x1197 => { %pictureProfile2010 },
    0x119b => { %pictureEffect2010 },
    0x11a8 => { %quality2010 },
    0x11ac => { %meteringMode2010 },
    0x11ad => { %exposureProgram2010 },
    0x11b4 => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    0x1254 => {
        Condition => '$$self{Model} =~ /^(SLT-(A99|A99V)|NEX-(5R|5T|6|VG900|VG30E)|DSC-RX100|Stellar|HV)\b/',
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x1258 => {
        Condition => '$$self{Model} =~ /^(DSC-(RX1|RX1R))\b/',
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x1278 => {
        Condition => '$$self{Model} =~ /^(SLT-A58|ILCE-(3000|3500)|NEX-3N|DSC-(HX300|HX50V|WX60|WX80|WX200|WX300|TX30))\b/',
        Name => 'FocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x127a => {
        Condition => '$$self{Model} =~ /^(SLT-A58|ILCE-(3000|3500)|NEX-3N|DSC-(HX300|HX50V|WX60|WX80|WX200|WX300|TX30))\b/',
        Name => 'MinFocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x127c => { # may give 0 for fixed focal length lenses
        Condition => '$$self{Model} =~ /^(SLT-A58|ILCE-(3000|3500)|NEX-3N|DSC-(HX300|HX50V|WX60|WX80|WX200|WX300|TX30))\b/',
        Name => 'MaxFocalLength',
        Format => 'int16u',
        RawConv => '$val || undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x1280 => {
        Condition => '$$self{Model} =~ /^(SLT-A58|ILCE-(3000|3500)|NEX-3N|DSC-(HX300|HX50V|WX60|WX80|WX200|WX300|TX30))\b/',
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x1870 => {
        Name => 'LensParameters',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
        Format => 'int16s[16]',
        Unknown => 1, # (not sure how these are applied)
        PrintConv => 'sprintf("%5d" . " %5d" x 15, split(" ",$val))',
    },
    # 0x1890 - same as 0x1892, but has value 3 for 50mm F1.4 ZA, DT 18-135mm and for 70-400mm G II: meaning ??
    0x1891 => {
        Name => 'LensFormat',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
        PrintConv => {
            0 => 'Unknown',
            1 => 'APS-C',
            2 => 'Full-frame',
        },
    },
    0x1892 => {
        Name => 'LensMount',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val; $$self{Model} =~ /^(DSC-|Stellar)/ ? undef : $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount',
            2 => 'E-mount',
        },
    },
    0x1893 => { #JR
        Name => 'LensType2',
        Condition => '$$self{LensMount} == 2',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x1896 => {
        Name => 'LensType',
        Condition => '$$self{LensMount} == 1',
        Priority => 0, #PH (just to be safe)
        Format => 'int16u', #PH
        SeparateTable => 1,
        ValueConvInv => '($val & 0xff00) == 0x8000 ? 0 : int($val)',
        PrintConv => \%sonyLensTypes,
    },
    #0x1914 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1918 => { Name => 'SonyImageHeight', Format => 'int16u' },
    #0x192e => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1930 => { Name => 'SonyImageHeight', Format => 'int16u' },
);

%Image::ExifTool::Sony::Tag2010f = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => 'Valid for DSC-RX100M2, DSC-QX10/QX100.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0004 => { %releaseMode2, Format => 'int32u' }, # NOT at offset 0x08 !
    #0x002e => { Name => 'SonyImageWidth3', Format => 'int16u' },
    #0x0042 => { Name => 'SonyImageWidth3', Format => 'int16u' },
    0x0050 => { %dynamicRangeOptimizer2010 },
    0x01e0 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x1014 => { %releaseMode2010 },
    0x1018 => { %releaseMode2 },
    0x1020 => { %selfTimer2010 },
    0x1024 => { %flashMode2010 },
    0x102a => { %gain2010 },
    0x102c => { %brightnessValue2010 },
    0x1030 => { %dynamicRangeOptimizer2010 },
    0x1034 => { %hdr2010 },
    0x1038 => { %exposureComp2010 },
    0x104e => { %pictureProfile2010 },
    0x104f => { %pictureProfile2010 },
    0x1053 => { %pictureEffect2010 },
    0x1060 => { %quality2010 },
    0x1064 => { %meteringMode2010 },
    0x1065 => { %exposureProgram2010 },
    0x106c => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    #0x1096 => { Name => 'SonyImageWidth3', Format => 'int16u' },
    #0x10aa => { Name => 'SonyImageWidth3', Format => 'int16u' },
    0x1134 => {
        Name => 'FocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x1136 => {
        Name => 'MinFocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x1138 => {
        Name => 'MaxFocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x113c => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    #0x1914 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1918 => { Name => 'SonyImageHeight', Format => 'int16u' },
    #0x192e => { Name => 'SonyImageWidth',  Format => 'int16u' },
    #0x1930 => { Name => 'SonyImageHeight', Format => 'int16u' },
);

%Image::ExifTool::Sony::Tag2010g = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => q{
        Valid for DSC-HX400V/HX60V/QX30/RX10/RX100M3/WX220/WX350,
        ILCE-7/7R/7S/7M2/5000/5100/6000/QX1, ILCA-68/77M2.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0004 => { %releaseMode2, Format => 'int32u' }, # NOT at offset 0x08 !
    0x0050 => { %dynamicRangeOptimizer2010 },
    0x020c => { %releaseMode2010 },
    0x0210 => { %releaseMode2 },
    0x0218 => { %selfTimer2010 },
    0x021c => { %flashMode2010 },
    0x0222 => { %gain2010 },
    0x0224 => { %brightnessValue2010 },
    0x0228 => { %dynamicRangeOptimizer2010 },
    0x022c => { %hdr2010 },
    0x0230 => { %exposureComp2010 },
    0x0246 => { %pictureProfile2010 },
    0x0247 => { %pictureProfile2010 },
    0x024b => { %pictureEffect2010 },
    0x0258 => { %quality2010 },
    0x025c => { %meteringMode2010 },
    0x025d => { %exposureProgram2010 },
    0x0264 => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    0x032c => {
        Name => 'FocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x032e => {
        Name => 'MinFocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x0330 => { # may give 0 for fixed focal length lenses
        Name => 'MaxFocalLength',
        Format => 'int16u',
        RawConv => '$val || undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x0344 => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x0388 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x189c => {
        Name => 'LensParameters',
        Condition => '$$self{Model} !~ /^DSC-/',
        Format => 'int16s[16]',
        Unknown => 1,
        PrintConv => 'sprintf("%5d" . " %5d" x 15, split(" ",$val))',
    },
    # 0x18bc - same as 0x18be, but has value 3 for 50mm F1.4 ZA, DT 18-135mm and for 70-400mm G II: meaning ??
    0x18bd => {
        Name => 'LensFormat',
        Condition => '$$self{Model} !~ /^DSC-/',
        PrintConv => {
            0 => 'Unknown',
            1 => 'APS-C',
            2 => 'Full-frame',
        },
    },
    0x18be => {
        Name => 'LensMount',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val; $$self{Model} =~ /^DSC-/ ? undef : $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount',
            2 => 'E-mount',
        },
    },
    0x18bf => { #JR
        Name => 'LensType2',
        Condition => '$$self{LensMount} == 2',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x18c2 => {
        Name => 'LensType',
        Condition => '$$self{LensMount} == 1',
        Priority => 0, #PH (just to be safe)
        Format => 'int16u', #PH
        SeparateTable => 1,
        ValueConvInv => '($val & 0xff00) == 0x8000 ? 0 : int($val)',
        PrintConv => \%sonyLensTypes,
    },
    # 0x1940 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    # 0x1944 => { Name => 'SonyImageHeight', Format => 'int16u' },
    # 0x195a => { Name => 'SonyImageWidth',  Format => 'int16u' },
    # 0x195c => { Name => 'SonyImageHeight', Format => 'int16u' },
);

%Image::ExifTool::Sony::Tag2010h = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => q{
        Valid for DSC-HX90V/RX1RM2/RX10M2/RX10M3/RX100M4/WX500, ILCE-6300/7RM2/7SM2.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0004 => { %releaseMode2, Format => 'int32u' },
    0x0050 => { %dynamicRangeOptimizer2010 },
    0x020c => { %releaseMode2010 },
    0x0210 => { %releaseMode2 },
    0x0218 => { %selfTimerB2010 },
    0x021c => { %flashMode2010 },
    0x0222 => { %gain2010 },
    0x0224 => { %brightnessValue2010 },
    0x0228 => { %dynamicRangeOptimizer2010 },
    0x022c => { %hdr2010 },
    0x0230 => { %exposureComp2010 },
    0x0246 => { %pictureProfile2010 },
    0x0247 => { %pictureProfile2010 },
    0x024b => { %pictureEffect2010 },
    0x0258 => { %quality2010 },
    0x025c => { %meteringMode2010 },
    0x025d => { %exposureProgram2010 },
    0x0264 => { Name => 'WB_RGBLevels', Format => 'int16u[3]' },
    0x032c => {
        Name => 'FocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x032e => {
        Name => 'MinFocalLength',
        Format => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x0330 => { # may give 0 for fixed focal length lenses
        Name => 'MaxFocalLength',
        Format => 'int16u',
        RawConv => '$val || undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val =~ s/ ?mm//; $val',
    },
    0x0346 => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x0388 => {
        Name => 'MeterInfo',
        Format => 'int32u[486]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::MeterInfo' },
    },
    0x18cc => {
        Name => 'LensParameters',
        Condition => '$$self{Model} !~ /^DSC-/',
        Format => 'int16s[16]',
        Unknown => 1,
        PrintConv => 'sprintf("%5d" . " %5d" x 15, split(" ",$val))',
    },
    # 0x18ec - same as 0x18ee, but has value 3 for LensType>=65, except SAL300F28G2
    0x18ed => {
        Name => 'LensFormat',
        Condition => '$$self{Model} !~ /^DSC-/',
        PrintConv => {
            0 => 'Unknown',
            1 => 'APS-C',
            2 => 'Full-frame',
        },
    },
    0x18ee => {
        Name => 'LensMount',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val; $$self{Model} =~ /^DSC-/ ? undef : $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount',
            2 => 'E-mount',
        },
    },
    0x18ef => { #JR
        Name => 'LensType2',
        Condition => '$$self{LensMount} == 2',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x18f2 => {
        Name => 'LensType',
        Condition => '$$self{LensMount} == 1',
        Priority => 0, #PH (just to be safe)
        Format => 'int16u', #PH
        SeparateTable => 1,
        ValueConvInv => '($val & 0xff00) == 0x8000 ? 0 : int($val)',
        PrintConv => \%sonyLensTypes,
    },
    # 0x1970 => { Name => 'SonyImageWidth',  Format => 'int16u' },
    # 0x1974 => { Name => 'SonyImageHeight', Format => 'int16u' },
    # 0x198a => { Name => 'SonyImageWidth',  Format => 'int16u' },
    # 0x198c => { Name => 'SonyImageHeight', Format => 'int16u' },
);

%Image::ExifTool::Sony::Tag202a = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int8u',
    DATAMEMBER => [ 0x01 ],
#
# first seen for ILCE-6300
# Possibly the Locations of the FocalPlaneAFPointsUsed are indicated here.
# 66 bytes, structure appears to be as follows:
# 0x00 - 1 for ILCE-6300
# 0x01 - int8u: 0 to 15 - nr of locations to follow
# 0x02 and 0x03 - (128 2) or 640 - (max.) width (X) of (LCD screen) area of following locations
# 0x04 and 0x05 - (172 1) or 428 - (max.) height (Y) of (LCD screen) area of following locations
#                 origin of X-Y coordinates appears to be top-left, i.e. X to the right, Y pointing down.
# 0x06 0x07 0x08 0x09 - 2x int16u : X and Y coordinates of Location 1
# etc.
#
    0x01 => {
        Name => 'FocalPlaneAFPointsUsed',
        DataMember => 'Locations',
        Format => 'int8u',
        RawConv => '$$self{Locations} = $val',
    },
    0x02 => {
        Name => 'FocalPlaneAFPointArea',
        Condition => '$$self{Locations} >= 1', # only output this if at least 1 Location follows ?
        Format => 'int16u[2]',
    },
    0x06 => { Name => 'FocalPlaneAFPointLocation1',  Condition => '$$self{Locations} >= 1',  Format => 'int16u[2]' },
    0x0a => { Name => 'FocalPlaneAFPointLocation2',  Condition => '$$self{Locations} >= 2',  Format => 'int16u[2]' },
    0x0e => { Name => 'FocalPlaneAFPointLocation3',  Condition => '$$self{Locations} >= 3',  Format => 'int16u[2]' },
    0x12 => { Name => 'FocalPlaneAFPointLocation4',  Condition => '$$self{Locations} >= 4',  Format => 'int16u[2]' },
    0x16 => { Name => 'FocalPlaneAFPointLocation5',  Condition => '$$self{Locations} >= 5',  Format => 'int16u[2]' },
    0x1a => { Name => 'FocalPlaneAFPointLocation6',  Condition => '$$self{Locations} >= 6',  Format => 'int16u[2]' },
    0x1e => { Name => 'FocalPlaneAFPointLocation7',  Condition => '$$self{Locations} >= 7',  Format => 'int16u[2]' },
    0x22 => { Name => 'FocalPlaneAFPointLocation8',  Condition => '$$self{Locations} >= 8',  Format => 'int16u[2]' },
    0x26 => { Name => 'FocalPlaneAFPointLocation9',  Condition => '$$self{Locations} >= 9',  Format => 'int16u[2]' },
    0x2a => { Name => 'FocalPlaneAFPointLocation10', Condition => '$$self{Locations} >= 10', Format => 'int16u[2]' },
    0x2e => { Name => 'FocalPlaneAFPointLocation11', Condition => '$$self{Locations} >= 11', Format => 'int16u[2]' },
    0x32 => { Name => 'FocalPlaneAFPointLocation12', Condition => '$$self{Locations} >= 12', Format => 'int16u[2]' },
    0x36 => { Name => 'FocalPlaneAFPointLocation13', Condition => '$$self{Locations} >= 13', Format => 'int16u[2]' },
    0x3a => { Name => 'FocalPlaneAFPointLocation14', Condition => '$$self{Locations} >= 14', Format => 'int16u[2]' },
    0x3e => { Name => 'FocalPlaneAFPointLocation15', Condition => '$$self{Locations} >= 15', Format => 'int16u[2]' },
);

# possible metering information (ref JR)
%Image::ExifTool::Sony::MeterInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        Information possibly related to metering.  Extracted only if the Unknown
        option is used.
    },
#
# 162 'triplets' of 3 int32u numbers: (k,n1,n2)
# These appear to relate to two sets of brightness distribution over the image area:
# Set 1: 7 rows of 9
# Set 2: 9 rows of 11
#
# Exact meaning presently unknown, however:
# n1 ranges from 0 (black) - appr. 1300 (bright white)
# n2 ranges from 0 (black) - appr. 142000 (bright white), i.e. roughly factor 100 higher
# Many panorama images: all 0
# Flash images: n2 = n1
# k maybe some kind of 'gain' or multiplication factor ?
# k distribution over the image as function of Aspect-Ratio is as follows:
#
#                3:2 image                           16:9 image                          4:3 image
# set 1:
#
#     12 12 12 12 12 12 12 12 12          12 12 12 15 18 15 12 12 12           9 12 12 12 12 12 12 12  9
#     12 12 12 12 12 12 12 12 12          12 12 12 15 18 15 12 12 12           9 12 12 12 12 12 12 12  9
#     16 16 16 16 16 16 16 16 16          12 12 12 15 18 15 12 12 12          12 16 16 16 16 16 16 16 12
#     16 16 16 16 16 16 16 16 16          12 12 12 15 18 15 12 12 12          12 16 16 16 16 16 16 16 12
#     16 16 16 16 16 16 16 16 16          12 12 12 15 18 15 12 12 12          12 16 16 16 16 16 16 16 12
#     12 12 12 12 12 12 12 12 12          12 12 12 15 18 15 12 12 12           9 12 12 12 12 12 12 12  9
#     12 12 12 12 12 12 12 12 12          12 12 12 15 18 15 12 12 12           9 12 12 12 12 12 12 12  9
#
# set 2:
#
#  12 12 12 12 12 12 12 12 12 12 12    12 12 12 12 15 18 15 12 12 12 12     9  9 12 12 12 12 12 12 12  9  9
#  12 12 12 12 12 12 12 12 12 12 12    12 12 12 12 15 18 15 12 12 12 12     9  9 12 12 12 12 12 12 12  9  9
#  12 12 12 12 12 12 12 12 12 12 12    12 12 12 12 15 18 15 12 12 12 12     9  9 12 12 12 12 12 12 12  9  9
#  16 16 16 16 16 16 16 16 16 16 16    12 12 12 12 15 18 15 12 12 12 12    12 12 16 16 16 16 16 16 16 12 12
#  16 16 16 16 16 16 16 16 16 16 16    12 12 12 12 15 18 15 12 12 12 12    12 12 16 16 16 16 16 16 16 12 12
#  16 16 16 16 16 16 16 16 16 16 16    12 12 12 12 15 18 15 12 12 12 12    12 12 16 16 16 16 16 16 16 12 12
#  12 12 12 12 12 12 12 12 12 12 12    12 12 12 12 15 18 15 12 12 12 12     9  9 12 12 12 12 12 12 12  9  9
#  12 12 12 12 12 12 12 12 12 12 12    12 12 12 12 15 18 15 12 12 12 12     9  9 12 12 12 12 12 12 12  9  9
#  12 12 12 12 12 12 12 12 12 12 12     8  8  8  8 10 12 10  8  8  8  8     9  9 12 12 12 12 12 12 12  9  9
#
# Usually, in the center, the numbers of set 1 row 2-6 match with set 2 row 3-7, except for first and last 2 columns.
#
    0x0000 => { Name => 'MeterInfo1Row1', %meterInfo1 },
    0x006c => { Name => 'MeterInfo1Row2', %meterInfo1 },
    0x00d8 => { Name => 'MeterInfo1Row3', %meterInfo1 },
    0x0144 => { Name => 'MeterInfo1Row4', %meterInfo1 },
    0x01b0 => { Name => 'MeterInfo1Row5', %meterInfo1 },
    0x021c => { Name => 'MeterInfo1Row6', %meterInfo1 },
    0x0288 => { Name => 'MeterInfo1Row7', %meterInfo1 },

    0x02f4 => { Name => 'MeterInfo2Row1', %meterInfo2 },
    0x0378 => { Name => 'MeterInfo2Row2', %meterInfo2 },
    0x03fc => { Name => 'MeterInfo2Row3', %meterInfo2 },
    0x0480 => { Name => 'MeterInfo2Row4', %meterInfo2 },
    0x0504 => { Name => 'MeterInfo2Row5', %meterInfo2 },
    0x0588 => { Name => 'MeterInfo2Row6', %meterInfo2 },
    0x060c => { Name => 'MeterInfo2Row7', %meterInfo2 },
    0x0690 => { Name => 'MeterInfo2Row8', %meterInfo2 },
    0x0714 => { Name => 'MeterInfo2Row9', %meterInfo2 },
);

%Image::ExifTool::Sony::Tag900b = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # 0x0000 - always 174 (e)
    0x0002 => {
        Name => 'FacesDetected',
        PrintConv => {
            0   => '0',
            98  => '1',
            57  => '2',
            93  => '3',
            77  => '4',
            33  => '5',
            168 => '6',
            241 => '7',
            115 => '8',
        },
    },
    # 0x00bc - always 98 (221 (e))
    0x00bd => {
        Condition => '$$self{Model} !~ /^DSLR-(A450|A500|A550)$/', # always 98 for A450/A500/A550: exclude
        Name => 'FaceDetection',
        PrintConv => {
            0 => 'Off',
            98 => 'On',
        },
    },
);

%Image::ExifTool::Sony::Tag9050 = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 0x0105 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        Data for tags 0x9050, 0x94xx and 0x2010 is encrypted by a simple
        substitution cipher, but the deciphered values are listed below.
    },
    0x0000 => {
        Condition => '$$self{Model} !~ /^(NEX-|Lunar|ILCE-|DSC-|Stellar)/',
        Name => 'MaxAperture', # (at current focal length)
        # seen values from 17 - 48
        ValueConv => '2 ** (($val/8 - 1.06) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0001 => {
        Condition => '$$self{Model} !~ /^(NEX-|Lunar|ILCE-|DSC-|Stellar)/',
        Name => 'MinAperture', # (at current focal length)
        # seen values from 80 - 95
        ValueConv => '2 ** (($val/8 - 1.06) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
#    0x0002 and 0x0004 (int16u) for SLT:
#           appears to be difference between used FNumber and MaxAperture, 256 being +1 APEX or stop
#           however, not always valid e.g. bracketing, Shutter-prio e.a.
#           difference between 0x0002 and 0x0004 mostly 0.0, 0.1 or 0.2 stops.

#### From July 2015: ILCE-6300/7RM2/7SM2 offsets appear to be different ... exclude from existing tags

    0x0031 => { #JR
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|ILCE-(6300|7RM2|7SM2))/',
        Name => 'FlashStatus',
        RawConv => '$$self{FlashFired} = $val',
        PrintConv => {
            0 => 'No Flash present',
            2 => 'Flash Inhibited',           # seen for ILCE-7/7R continuous, panorama, HDR mode
            64 => 'Built-in Flash present',
            65 => 'Built-in Flash Fired',
            66 => 'Built-in Flash Inhibited', # seen for panorama, HDR, burst mode
            128 => 'External Flash present',  # seen for NEX-5N/5T
            129 => 'External Flash Fired',    # seen for SLT-A99V, ILCE-7R, NEX-5N/5R
        },
    },
    0x0032 => { #13
        Name => 'ImageCount',
        # this seems to be valid for the A37,A57,A65,A77,A99, and possibly the NEX-5N/7
        # but I haven't seen a count over 65536, so the Format is not confirmed - PH
        # - not valid for the DSC-RX100 or RX1, so exclude all DSC models
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|ILCE-(6300|7RM2|7SM2))/', #PH
        Format => 'int32u',
        Notes => 'total number of image exposures made by the camera',
        RawConv => '$val & 0x00ffffff',
    },
    0x003a => { # appr. same value as Exif ExposureTime, but longer in HDR-modes
        Name => 'SonyExposureTime',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|ILCE-(6300|7RM2|7SM2))/',
        Format => 'int16u',
        ValueConv => '$val ? 2 ** (16 - $val/256) : 0',
        ValueConvInv => '$val ? int((16 - log($val) / log(2)) * 256 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x003c => {
        Name => 'SonyFNumber',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|ILCE-(6300|7RM2|7SM2))/',
        Format => 'int16u',
        ValueConv => '2 ** (($val/256 - 16) / 2)',
        ValueConvInv => '(log($val)*2/log(2)+16)*256',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x003f => {
        Name => 'ReleaseMode2',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|ILCE-(6300|7RM2|7SM2))/',
        %releaseMode2,
    },
    0x004c => { # only ILCE-7/7R/7S/7M2/5000/5100/6000/QX1 - but appears not valid when flash is used ...
        Name => 'ImageCount2',
        Condition => '($$self{Model} =~ /^(ILCE-(7(R|S|M2)?|[56]000|5100|QX1))\b/) and (($$self{FlashFired} & 0x01) != 1)',
        Format => 'int32u',
        RawConv => '$val & 0x00ffffff',
    },
    0x0051 => { # only ILCE-7/7R/7S/7M2/5000/5100/6000/QX1, but hours usually different from SonyDateTime - UTC?
                # appears not valid (all '0') when flash is used, panorama, hdr modes ...
        Name => 'SonyDateTime2',
        Condition => '$$self{Model} =~ /^(ILCE-(7(R|S|M2)?|[56]000|5100|QX1))\b/',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Format => 'undef[6]',
        ValueConv => q{
            my @v = unpack('C*', $val);
            return undef unless $v[0] > 0;
            return sprintf("20%.2d:%.2d:%.2d %.2d:%.2d:%.2d", @v)
        },
        ValueConvInv => q{
            my @v = ($val =~ /\d+/g);
            return undef unless @v == 6 and ($v[0]-=2000) >= 0;
            return pack('C*', @v);
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x0067 => {
        Name => 'ReleaseMode2',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|SLT-A(65|77)V?|Lunar|NEX-(5N|7|VG20E)|ILCE-(6300|7RM2|7SM2))/',
        %releaseMode2,
    },
    0x007c => { #JR valid for ILCE and most NEX
        Name => 'InternalSerialNumber', # (NC)
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|Lunar|NEX-(5N|7|VG20E)|SLT-|HV|ILCA-|ILCE-(6300|7RM2|7SM2))/',
        Format => 'int8u[4]',
        PrintConv => 'unpack "H*", pack "C*", split " ", $val',
    },
    0x00f0 => { #JR valid for SLT/ILCA models
        Name => 'InternalSerialNumber', # (NC)
        Condition => '$$self{Model} =~ /^(SLT-|HV|ILCA-)/',
        Format => 'int8u[5]',
        PrintConv => 'unpack "H*", pack "C*", split " ", $val',
        PrintConvInv => 'join " ", unpack "C*", pack "H*", $val',
    },

##### ILCE-6300/7RM2/7SM2: offsets +8

    0x0039 => {
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        Name => 'FlashStatus',
        RawConv => '$$self{FlashFired} = $val',
        PrintConv => {
            0 => 'No Flash present',
            2 => 'Flash Inhibited',           # seen for ILCE-7/7R continuous, panorama, HDR mode
            64 => 'Built-in Flash present',
            65 => 'Built-in Flash Fired',
            66 => 'Built-in Flash Inhibited', # seen for panorama, HDR, burst mode
            128 => 'External Flash present',  # seen for NEX-5N/5T
            129 => 'External Flash Fired',    # seen for SLT-A99V, ILCE-7R, NEX-5N/5R
        },
    },
    0x003a => {
        Name => 'ImageCount',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        Format => 'int32u',
        Notes => 'total number of image exposures made by the camera',
        RawConv => '$val & 0x00ffffff',
    },

##### ILCE-6300/7RM2/7SM2: offsets +12 (x0c):

    0x0046 => { # appr. same value as Exif ExposureTime, but longer in HDR-modes
        Name => 'SonyExposureTime',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        Format => 'int16u',
        ValueConv => '$val ? 2 ** (16 - $val/256) : 0',
        ValueConvInv => '$val ? int((16 - log($val) / log(2)) * 256 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0048 => {
        Name => 'SonyFNumber',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        Format => 'int16u',
        ValueConv => '2 ** (($val/256 - 16) / 2)',
        ValueConvInv => '(log($val)*2/log(2)+16)*256',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x004b => {
        Name => 'ReleaseMode2',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        %releaseMode2,
    },
    0x0058 => { # only ILCE-(7RM2|7SM2) - but appears not valid when flash is used ...
        Name => 'ImageCount2',
        Condition => '($$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))\b/) and (($$self{FlashFired} & 0x01) != 1)',
        Format => 'int32u',
        RawConv => '$val & 0x00ffffff',
    },
    0x005d => { # only ILCE-(7RM2|7SM2), but only minutes-seconds ???
        Name => 'SonyDateTime2',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))\b/',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Format => 'undef[6]',
        ValueConv => q{
            my @v = unpack('C*', $val);
#            return undef unless $v[0] > 0;
            return sprintf("20%.2d:%.2d:%.2d %.2d:%.2d:%.2d", @v)
        },
        ValueConvInv => q{
            my @v = ($val =~ /\d+/g);
            return undef unless @v == 6 and ($v[0]-=2000) >= 0;
            return pack('C*', @v);
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x0073 => {
        Name => 'ReleaseMode2',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        %releaseMode2,
    },
    0x0088 => {
        Name => 'InternalSerialNumber', # (NC)
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))/',
        Format => 'int8u[6]',
        PrintConv => 'unpack "H*", pack "C*", split " ", $val',
    },

##### ILCE-6300/7RM2/7SM2: same offsets for lens info tags

    # 0x0104 - same as 0x0105, but has value 3 for 50mm F1.4 ZA, DT 18-135mm and for 70-400mm G II: meaning ??
    0x0105 => {
        Name => 'LensMount',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val; $$self{Model} =~ /^(DSC-|Stellar)/ ? undef : $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount',
            2 => 'E-mount',
        },
    },
    0x0106 => {
        Name => 'LensFormat',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
        PrintConv => {
            0 => 'Unknown',
            1 => 'APS-C',
            2 => 'Full-frame',
        },
    },
    0x0107 => {
        Name => 'LensType2',
        Condition => '$$self{LensMount} == 2',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    # 0x0108 - 128 for Sony E-mount lenses, 0 for all other
    0x0109 => {
        Name => 'LensType',
        Condition => '$$self{LensMount} == 1',
        Priority => 0, #PH (just to be safe)
        Format => 'int16u', #PH
        Notes => 'SLT models, and NEX with A-mount lenses',
        SeparateTable => 1,
        # has a value of 0 for E-mount lenses (values 0x80xx)
        ValueConvInv => '($val & 0xff00) == 0x8000 ? 0 : int($val)',
        PrintConv => \%sonyLensTypes,
    },
    # 0x0115 and 0x0116, or 0x0116 and 0x0117:
    # give the same info as the first and last bytes of LensSpec,
    # but also for older Sony and Minolta lenses where all LensSpec bytes are 0.
    0x0115 => {
        Name => 'LensSpecFeatures',
        Condition => '$$self{Model} =~ /^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/',
        Format => 'undef[2]',
        ValueConv => 'join " ", unpack "H2H2", $val',
        ValueConvInv => sub {
            my @a = split(" ", shift);
            return @a == 2 ? pack 'CC', hex($a[0]), hex($a[1]) : undef;
        },
        PrintConv => \&PrintLensSpec,
        PrintConvInv => 'Image::ExifTool::Sony::PrintInvLensSpec($val, $self, 1)',
    },
    0x0116 => {
        Name => 'LensSpecFeatures',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar|SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/',
        Format => 'undef[2]',
        ValueConv => 'join " ", unpack "H2H2", $val',
        ValueConvInv => sub {
            my @a = split(" ", shift);
            return @a == 2 ? pack 'CC', hex($a[0]), hex($a[1]) : undef;
        },
        PrintConv => \&PrintLensSpec,
        PrintConvInv => 'Image::ExifTool::Sony::PrintInvLensSpec($val, $self, 1)',
    },

#    0x0122 => {Name=>'9050_LensType',Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/'},
#    0x0123 => {Name=>'9050_LensType',Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(58|99V?)|HV|ILCA-(68|77M2)|NEX-(3N|5R|5T|6|VG30E|VG900)|ILCE-(3000|3500|5000|5100|6000|7|7R|7S|7M2|QX1))/'},
#    0x012d => {Name=>'9050_LensType',Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/'},
#    0x012e => {Name=>'9050_LensType',Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(58|99V?)|HV|ILCA-(68|77M2)|NEX-(3N|5R|5T|6|VG30E|VG900)|ILCE-(3000|3500|5000|5100|6000|7|7R|7S|7M2|QX1))/'},

#    ImageCount3 = ImageCount   for SLT-A58, ILCE, ILCA, NEX-3N
#                  ImageCount-1 for SLT-A37,A57,A65,A77,A99, NEX-F3,5N,5R,5T,6,7, sometimes 0
#                  ImageCount-2 for NEX-VG, and often 0; "ImageCount-2" also seen on a few A99V images
#    The offset for ImageCount3 changes with firmware version for the ILCE-7/7R/7S/7M2, so don't decode it for now:
#                 ILCE-7M2/7S: 0x01a0 (firmware 1.0x, 1.1x), 0x01b6 (firmware 1.20, 1.21, 2.00)
#                 ILCE-7/7R:   0x01aa (firmware 1.0x, 1.1x), 0x01c0 (firmware 1.20, 1.21, 2.00)
#    Similarly for ILCE-6000 v2.00: 0x01aa --> 0x01c0: removed from 0x01aa
    0x01a0 => {
        Name => 'ImageCount3',
        Format => 'int32u',
        RawConv => '$val == 0 ? undef : $val',
        Condition => '$$self{Model} =~ /^(ILCE-(5100|QX1)|ILCA-(68|77M2))/',
    },
    0x01aa => {
        Name => 'ImageCount3',
        Format => 'int32u',
        RawConv => '$val == 0 ? undef : $val',
        Condition => '$$self{Model} =~ /^(SLT-A(58|99V?)|HV|NEX-(3N|5R|5T|6|VG900|VG30E)|ILCE-([35]000|3500))\b/',
    },
    0x01bd => {
        Name => 'ImageCount3',
        Format => 'int32u',
        RawConv => '$val == 0 ? undef : $val',
        Condition => '$$self{Model} =~ /^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/'
    },
    0x01cb => {
        Name => 'ImageCount3',
        Format => 'int32u',
        RawConv => '$val == 0 ? undef : $val',
        Condition => '$$self{Model} =~ /^(ILCE-(7RM2|7SM2))/',
    },

#    0x0222 => {Name=>'9050_LensType2',Format=>'int16u',Condition =>'$$self{Model}=~/^(ILCE-(5100|7S|7M2|QX1))/'},
#    0x0224 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(ILCE-(5100|7S|7M2|QX1)|ILCA-(68|77M2))/'},
#    0x0229 => {Name=>'9050_LensType2',Format=>'int16u',Condition =>'$$self{Model}=~/^(NEX-(5R|5T|6|VG30E|VG900))/'},
#    0x022b => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(NEX-(5R|5T|6|VG30E|VG900))/'},
#    0x022c => {Name=>'9050_LensType2',Format=>'int16u',Condition =>'$$self{Model}=~/^(ILCE-(3000|3500|5000|6000|7|7R)|NEX-3N)\b/'},
#    0x022e => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(ILCE-(3000|3500|5000|6000|7|7R)|NEX-3N|SLT-A(58|99V?)|HV)\b/'},

#    0x0231 => {Name=>'9050_LensSpecFeatures',Format=>'undef[2]',Condition=>'$$self{Model}=~/^(ILCE-(7S|7M2|5100|QX1)|ILCA-(68|77M2))/'},
#    0x0238 => {Name=>'9050_LensSpecFeatures',Format=>'undef[2]',Condition=>'$$self{Model}=~/^(NEX-(5R|5T|6|VG30E|VG900))/'},
#    0x023b => {Name=>'9050_LensSpecFeatures',Format=>'undef[2]',Condition=>'$$self{Model}=~/^(SLT-A(58|99V?)|HV|ILCE-(3000|3500|5000|6000|7|7R)|NEX-3N)\b/'},

#    0x023c => {Name=>'9050_LensType2',Format=>'int16u',Condition =>'$$self{Model}=~/^(Lunar|NEX-(F3|5N|7|VG20E))/'},
#    0x023e => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E)|ILCE-(5100|7S|7M2|QX1)|ILCA-(68|77M2))/'},
#    0x0245 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(NEX-(5R|5T|6|VG30E|VG900))/'},
#    0x0248 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(58|99V?)|HV|ILCE-(3000|3500|5000|6000|7|7R)|NEX-3N)\b/'},
#    0x0249 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(ILCE-(5100|7S|7M2|QX1)|ILCA-(68|77M2))/'},

#    0x024a => {Name=>'9050_LensSpecFeatures',Format=>'undef[2]',Condition=>'$$self{Model}=~/^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/'},

#    0x0250 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(NEX-(5R|5T|6|VG30E|VG900))/'},
#    0x0253 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(58|99V?)|HV|ILCE-(3000|3500|5000|6000|7|7R|7S|7M2)|NEX-3N)\b/'},
#    0x0257 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/'},
#    0x0262 => {Name=>'9050_LensType', Format=>'int16u',Condition =>'$$self{Model}=~/^(SLT-A(37|57|65|77)V?|Lunar|NEX-(F3|5N|7|VG20E))/'},

#    0x031b => {%gain2010,Condition=>'$$self{Model}=~/^(DSC-RX100M3|ILCA-(68|77M2)|ILCE-(5100|7S|7M2|QX1))/'},
#    0x032c => {%gain2010,Condition=>'$$self{Model}=~/^(NEX-(5R|5T|6|VG30E|VG900))/'},
#    0x032f => {%gain2010,Condition=>'$$self{Model}=~/^(DSC-RX10|SLT-A(58|99V?)|HV|ILCE-(3000|3500|5000|6000|7|7R)|NEX-3N)\b/'},
#    0x0350 => {%gain2010,Condition=>'$$self{Model}=~/^(SLT-A(37|57)|NEX-F3)/'},
#    0x037b => {%gain2010,Condition=>'$$self{Model}=~/^(SLT-A(65|77)V?|Lunar|NEX-(7|VG20E))/'},
);

%Image::ExifTool::Sony::Tag9400a = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => 'Valid for many DSC, NEX and SLT models',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0008 => { %sequenceImageNumber }, #PH
    0x000c => { %sequenceFileNumber }, #PH
    0x0010 => { %releaseMode2 },
    0x0012 => {
        Name => 'DigitalZoom',
        Condition => '$$self{Model} !~ /^(SLT-(A65|A77)V?|NEX-(5N|7|VG20E)|Lunar|DSC-(HX10V|HX20V|HX200V|TX20|TX55|TX300V|WX30|WX70))\b/',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
#    0x0013 - Flash fired 0=no, 1=yes
#    0x0014 - related to flash / RedEyeReduction ?
#    0x0015 - CameraType: 1=HDR, 2=DSC, 3=SLT/NEX
    0x001a => { #PH
        Name => 'ShotNumberSincePowerUp',
        Format => 'int32u',
    },
#    0x001e - increments by 4 or 6 or 8 each shutter release press since power up
#    0x001f - 0=most pictures, 1='Self-timer/Self-portrait', 2='Self-portrait (2 people)',
#             3='Continuous Self-timer', 26='Sweep Panorama' (PH, RX100)
#    0x0021 - maybe related to Image Stabilization or Smile Shutter ?
    0x0022 => {
        Name => 'SequenceLength',
        PrintConv => {
            0 => 'Continuous', # (RX100 too)
            1 => '1 shot',
            2 => '2 shots', # (Background defocus, 3D Image)
            3 => '3 shots', # (HDR, WB Bracketing) (RX100, also continuous bracket)
            4 => '4 shots', # seen for DSC-WX300 in Superior-Auto Anti-Motion-Blur
            5 => '5 shots', # (PH, RX100)
            6 => '6 shots', # (Multi Frame NR, Anti Motion blur, Hand-held Twilight)
            10 => '10 shots', # (HX9V Burst)
            100 => 'Continuous - iSweep Panorama', # (HX9V)
            200 => 'Continuous - Sweep Panorama',
        },
    },
#    0x0027 - 1=single exposure, 2=multi-exposure (eg. pano,some superior auto) (PH, RX100)
    0x0028 => {
        Name => 'CameraOrientation', # (also RX100 - PH)
        PrintConv => {
            1 => 'Horizontal (normal)',
            3 => 'Rotate 180',
            6 => 'Rotate 90 CW',
            8 => 'Rotate 270 CW',
        },
    },
    0x0029 => {
        Name => 'Quality2', # (also RX100 - PH)
        PrintConv => {
            0 => 'JPEG',
            1 => 'RAW',
            2 => 'RAW + JPEG',
            3 => 'JPEG + MPO', # 3D images
        },
    },
#    0x002b - FacesDetected_OK  0=no, 1=yes  appears valid for SLT, but not for NEX and DSC-HX9V
#    0x0030 - long exposure noise reduction used 0=no, 1=yes (PH, RX100)
#    0x0031 - smile shutter used 0=no, 1=yes (PH, RX100)
#    0x0033 - 0 for DSC-HX9V, 8 for SLT, NEX
#    0x0034 and 0x0038 - different offset for HX9V and SLT/NEX, but similar numbers, non-zero when flash fired
    0x0044 => {
        Condition => '$$self{Model} =~ /^(SLT-|HV|NEX-|Lunar|DSC-RX|Stellar)/', # not valid for most other DSC and HDR models
        Name => 'SonyImageHeight',
        Format => 'int16u',
        PrintConv => '$val > 0 ? 8*$val : "n.a."',
    },
    0x0052 => {
        Name => 'ModelReleaseYear',
        Condition => '$$self{Model} =~ /^(SLT-|HV|NEX-|Lunar|DSC-RX|Stellar)/', # not valid for most other DSC and HDR models
        Format => 'int8u',
        PrintConv => 'sprintf("20%.2d", $val)',
    },
);

%Image::ExifTool::Sony::Tag9400b = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    NOTES => q{
        Valid for NEX-3N, ILCE-3000/3500, SLT-A58, DSC-WX60, DSC-WX300, DSC-RX100M2,
        DSC-HX50V, DSC-QX10/QX100.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0008 => { %sequenceImageNumber }, #PH
    0x000c => { %sequenceFileNumber }, #PH
    0x0010 => { %releaseMode2 },
    0x0012 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
#    0x0013 - Flash fired 0=no, 1=yes
#    0x0014 - related to flash / RedEyeReduction ?
#    0x0015 - CameraType: 1=HDR, 2=DSC, 3=SLT/NEX
    0x0016 => { #PH
        Name => 'ShotNumberSincePowerUp',
        Format => 'int32u',
    },
    0x001e => {
        Name => 'SequenceLength',
        PrintConv => {
            0 => 'Continuous',
            1 => '1 shot',
            2 => '2 shots',
            3 => '3 shots',
            4 => '4 shots',
            5 => '5 shots',
            6 => '6 shots',
            10 => '10 shots',
            100 => 'Continuous - iSweep Panorama',
            200 => 'Continuous - Sweep Panorama',
        },
    },
    0x0024 => {
        Name => 'CameraOrientation',
        PrintConv => {
            1 => 'Horizontal (normal)',
            3 => 'Rotate 180',
            6 => 'Rotate 90 CW',
            8 => 'Rotate 270 CW',
        },
    },
    0x0025 => {
        Name => 'Quality2',
        PrintConv => {
            0 => 'JPEG',
            1 => 'RAW',
            2 => 'RAW + JPEG',
            3 => 'JPEG + MPO', # 3D images
        },
    },
#    0x0027 - FacesDetected_OK  0=no, 1=yes
#    0x002c - long exposure noise reduction used 0=no, 1=yes (PH, RX100)
    0x003f => {
        Name => 'SonyImageHeight',
        Format => 'int16u',
        PrintConv => '$val > 0 ? 8*$val : "n.a."',
    },
    0x0046 => { # but Panorama images give incorrect result
        Name => 'ModelReleaseYear',
        Format => 'int8u',
        PrintConv => 'sprintf("20%.2d", $val)',
    },
);

%Image::ExifTool::Sony::Tag9400c = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    NOTES => q{
        Valid for DSC-HX400V/HX60V/QX30/RX10/RX100M3/WX220/WX350,
        ILCE-7/7R/7S/7M2/7RM2/7SM2/5000/5100/6000/6300/QX1, ILCA-68/77M2.
    },
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0009 => { %releaseMode2 },
    0x000a => {
        Name => 'ShotNumberSincePowerUp',
        Format => 'int32u',
    },
    0x0012 => { %sequenceImageNumber },
    0x0016 => {
        Name => 'SequenceLength',
        PrintConv => {
            0 => 'Continuous',
            1 => '1 shot',
            2 => '2 shots',
            3 => '3 shots',
            4 => '4 shots',
            5 => '5 shots',
            6 => '6 shots',
            9 => '9 shots', # ILCE-7RM2 9-shot bracketing
            10 => '10 shots',
            100 => 'Continuous - iSweep Panorama',
            200 => 'Continuous - Sweep Panorama',
        },
    },
    0x001a => { %sequenceFileNumber },
    0x001e => {
        Name => 'SequenceLength',
        PrintConv => {
            0 => 'Continuous',
            1 => '1 file',
            2 => '2 files',
            3 => '3 files',
            5 => '5 files',
            9 => '9 files', # ILCE-7RM2 9-shot bracketing
            10 => '10 files', # seen for DSC-WX500 with burst of 10 shots
        },
    },
    0x0029 => {
        Name => 'CameraOrientation',
        PrintConv => {
            1 => 'Horizontal (normal)',
            3 => 'Rotate 180',
            6 => 'Rotate 90 CW',
            8 => 'Rotate 270 CW',
        },
    },
    0x002a => {
        Name => 'Quality2',
        PrintConv => {
            0 => 'JPEG',
            1 => 'RAW',
            2 => 'RAW + JPEG',
            3 => 'JPEG + MPO', # 3D images
        },
    },
    0x0047 => {
        Name => 'SonyImageHeight',
        Format => 'int16u',
        PrintConv => '$val > 0 ? 8*$val : "n.a."',
    },
    0x0053 => {
        Name => 'ModelReleaseYear',
        Format => 'int8u',
        PrintConv => 'sprintf("20%.2d", $val)',
    },
);

# PH (RX100)
%Image::ExifTool::Sony::Tag9402 = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    DATAMEMBER => [ 0x02 ],
    PRIORITY => 0,
    0x02 => {
        Name => 'TempTest1',
        DataMember => 'TempTest1',
        Hidden => 1,
        RawConv => '$$self{TempTest1}=$val; $$self{OPTIONS}{Unknown}<2 ? undef : $val',
    },
    0x04 => {
        Name => 'AmbientTemperature',
        # this (and many other values) are only valid if 0x02 is 255 (why?)
        Condition => '$$self{TempTest1} == 255',
        Format => 'int8s', # (verified for negative temperature)
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    0x16 => { #JR
        Name => 'FocusMode',
        Mask => 0x7f, # (often +128, not sure what upper bit is for)
        PrintConv => {
            0 => 'Manual',
            2 => 'AF-S',
            3 => 'AF-C',
            4 => 'AF-A', # seen in ILCE-6000 images
            6 => 'DMF',
            # 7 => 'AF-D', # not for DSC, NEX, ILCE ...
        },
    },
    0x17 => {
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Multi', # newer DSC/ILC use name 'Wide'
            1 => 'Center',
            2 => 'Spot', # (NC) seen for DSC-WX300
            3 => 'Flexible Spot',
            10 => 'Selective (for Miniature effect)', # seen for DSC-HX30V,TX30,WX60,WX100
            11 => 'Zone', #JR (ILCE-7 series)
            12 => 'Expanded Flexible Spot', #JR (HX90V, ILCE-7 series)
            14 => 'Tracking',
            15 => 'Face Tracking',
            255 => 'Manual',
        },
    },
    # 0x24, 0x26: factor 10 for NEX and ILCE, factor 100 for DSC
    # 0x24, 0x26, 0x28, 0x2a: inconsistent for A-mount lenses on NEX/ILCE: some correct, some 0, some incorrect ...
    # 0x28 - not valid for DSC-[HTW]X models, or DSC-RX100
#    0x24 => { # same values as Exif FocalLength
#        Name => 'FocalLength',
#        Format => 'int16u',
#        RawConv => '$val || undef',
#        ValueConv => '$val / ($$self{Model}=~/DSC/ ? 100 : 10)',
#        ValueConvInv => '$val * ($$self{Model}=~/DSC/ ? 100 : 10)',
#        PrintConv => 'sprintf("%.1f mm",$val)',
#        PrintConvInv => '$val =~ s/ ?mm//; $val',
#    },
#    0x26 => { # usually identical to 0x24 or 0
#        Name => 'FocalLength',
#        Format => 'int16u',
#        ValueConv => '$val / ($$self{Model}=~/DSC/ ? 100 : 10)',
#        ValueConvInv => '$val * ($$self{Model}=~/DSC/ ? 100 : 10)',
#        PrintConv => 'sprintf("%.1f mm",$val)',
#        PrintConvInv => '$val =~ s/ ?mm//; $val',
#    },
#    0x28 => { # values slightly different from Exif FocalLength
#        Name => 'FocalLength2',
#        Format => 'int16u',
#        RawConv => '$val || undef',
#        ValueConv => '$val / 10',
#        ValueConvInv => '$val * 10',
#        PrintConv => 'sprintf("%.1f mm",$val)',
#        PrintConvInv => '$val =~ s/ ?mm//; $val',
#    },
#    0x2a => { # usually identical to 0x28 or 0
#        Name => 'FocalLength2',
#        Format => 'int16u',
#        ValueConv => '$val / 10',
#        ValueConvInv => '$val * 10',
#        PrintConv => 'sprintf("%.1f mm",$val)',
#        PrintConvInv => '$val =~ s/ ?mm//; $val',
#    },
#    0x002c => {
#        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
#        Name => 'FocusPosition2',
#        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
#    },
    0x002d => { # usually same as 0x002c, but some differences
        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
        Name => 'FocusPosition2',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
    },
    # 0x8a - int32u: some sort of accumulated time or something since power up
    #        (doesn't increment during continuous shooting and at some other times)
);

# PH (RX100)
%Image::ExifTool::Sony::Tag9403 = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    DATAMEMBER => [ 0x04 ],
    0x04 => {
        # seen values 0,2,3,18,32,49,50,83,148
        # CameraTemperature is valid for all values except 0,148
        Name => 'TempTest2',
        DataMember => 'TempTest2',
        Hidden => 1,
        RawConv => '$$self{TempTest2}=$val; $$self{OPTIONS}{Unknown}<2 ? undef : $val',
    },
    0x05 => {
        Name => 'CameraTemperature', # (maybe SensorTemperature? - heats up when taking movies)
        Condition => '$$self{TempTest2} and $$self{TempTest2} < 100',
        Format => 'int8s', # have seen as low as -1 for AmbientTemperature of -18
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    # 0x0f - same as 0x05
    # 0x18 - maybe another temperature?
);

# Tag9404 (ref JR)
%Image::ExifTool::Sony::Tag9404a = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x0019 => {
        Name => 'LensZoomPosition',
        Format => 'int16u',
        Condition => '$$self{Model} !~ /^SLT-/',
        PrintConv => 'sprintf("%.0f%%",$val/10.24)',
        PrintConvInv => '$val=~s/ ?%$//; $val * 10.24',
    },
);

%Image::ExifTool::Sony::Tag9404b= (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x001e => {
        Name => 'LensZoomPosition',
        Format => 'int16u',
        Condition => '$$self{Model} !~ /^(SLT-|HV|ILCA-)/',
        PrintConv => 'sprintf("%.0f%%",$val/10.24)',
        PrintConvInv => '$val=~s/ ?%$//; $val * 10.24',
    },
    0x0020 => {
        # seen values from 80 - 255 (= infinity) -- see Composite:FocusDistance2 below
        Name => 'FocusPosition2',
        Condition => '$$self{Model} =~ /^(SLT-|HV|ILCA-)/',
    },
);

# Tag9405 (ref JR)
%Image::ExifTool::Sony::Tag9405a = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x0604 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Valid for SLT, NEX, ILCE-3000/3500 and several DSC models.',
    0x0601 => {
        Name => 'DistortionCorrection',
        PrintConv => {
            0 => 'None',
            1 => 'Applied',
        },
    },
    # 0x0602 - same as 0x0604, but has value 3 for 50mm F1.4 ZA, DT 18-135mm and for 70-400mm G II: meaning ??
    0x0603 => {
        Name => 'LensFormat',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
        PrintConv => {
            0 => 'Unknown',
            1 => 'APS-C',
            2 => 'Full-frame',
        },
    },
    0x0604 => {
        Name => 'LensMount',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val; $$self{Model} =~ /^(DSC-|Stellar)/ ? undef : $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount',
            2 => 'E-mount',
            # 6 - seen for A58 panorama image
        },
    },
    0x0605 => {
        Name => 'LensType2',
        Condition => '$$self{LensMount} == 2',
        Format => 'int16u',
        Notes => 'E-mount lenses',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x0608 => {
        Name => 'LensType',
        Condition => '$$self{LensMount} == 1',
        Format => 'int16u',
        Notes => 'A-mount lenses on SLT and NEX',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes,
    },
    0x06ca => {
        Name => 'LensParameters',
        Condition => '$$self{Model} !~ /^(DSC-|Stellar)/',
        Format => 'int16s[16]',
        Unknown => 1,
        PrintConv => 'sprintf("%5d" . " %5d" x 15, split(" ",$val))',
    },
);

# Tag9405b (ref JR)
%Image::ExifTool::Sony::Tag9405b = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x005e ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        Valid for DSC-HX400V/HX60V/QX30/RX10/RX10M2/RX10M3/RX100M3/RX100M4/WX220/WX350,
        ILCE-7/7M2/7R/7RM2/7S/7SM2/5000/5100/6000/6300/QX1, ILCA-68/77M2.
    },
    0x0004 => {
        Name => 'SonyISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x0006 => {
        Name => 'BaseISO',
        Format => 'int16u',
        ValueConv => '3.125*(2**(21-($val/256)))',
        PrintConv => 'sprintf("%.0f",$val)',
    },
    0x000a => { %gain2010 },
    0x000e => { # appr. same value as Exif ExposureTime, but shorter in HDR-modes
        Name => 'SonyExposureTime2',
        Format => 'int16u',
        ValueConv => '$val ? 2 ** (16 - $val/256) : 0',
        ValueConvInv => '$val ? int((16 - log($val) / log(2)) * 256 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0010 => {
        Name => 'ExposureTime',
        Format => 'rational32u',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"', # (Bulb NC)
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0014 => { # but often odd results for DSC models: exclude
        Name => 'SonyFNumber',
        Format => 'int16u',
        Condition => '$$self{Model} !~ /^DSC-/',
        ValueConv => '2 ** (($val/256 - 16) / 2)',
        ValueConvInv => '(log($val)*2/log(2)+16)*256',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0016 => {
        Name => 'SonyMaxApertureValue', # (at current focal length)
        Format => 'int16u',
        ValueConv => '2 ** (($val/256 - 16) / 2)',
        ValueConvInv => '(log($val)*2/log(2)+16)*256',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0024 => { %sequenceImageNumber },
    0x0034 => { %releaseMode2 },
    0x0042 => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Normal',
            3 => 'High',
        },
    },
    0x0044 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'On',  # (unused or dark subject)
        },
    },
    0x0046 => { %pictureEffect2010 },
    0x0048 => { %exposureProgram2010 },
    0x004a => {
        Name => 'CreativeStyle',
        PrintConv => {
            0 => 'Standard',
            1 => 'Vivid',
            2 => 'Neutral',
            3 => 'Portrait',
            4 => 'Landscape',
            5 => 'B&W',
            6 => 'Clear',
            7 => 'Deep',
            8 => 'Light',
            9 => 'Sunset',
            10 => 'Night View/Portrait',
            11 => 'Autumn Leaves',
            13 => 'Sepia',
        },
    },
    0x0052 => {
        Name => 'Sharpness',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    0x005b => {
        Name => 'DistortionCorrection',
        PrintConv => {
            0 => 'None',
            1 => 'Applied',
        },
    },
    # 0x005c - same as 0x005e, but has value 3 for 50mm F1.4 ZA, DT 18-135mm and for 70-400mm G II: meaning ??
    0x005d => {
        Name => 'LensFormat',
        Condition => '$$self{Model} !~ /^DSC-/',
        PrintConv => {
            0 => 'Unknown',
            1 => 'APS-C',
            2 => 'Full-frame',
        },
    },
    0x005e => {
        Name => 'LensMount',
        DataMember => 'LensMount',
        RawConv => '$$self{LensMount} = $val; $$self{Model} =~ /^DSC-/ ? undef : $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount',
            2 => 'E-mount',
        },
    },
    0x0060 => {
        Name => 'LensType2',
        Condition => '$$self{LensMount} == 2',
        Format => 'int16u',
        Notes => 'E-mount lenses',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x0062 => {
        Name => 'LensType',
        Condition => '$$self{LensMount} == 1',
        Format => 'int16u',
        Notes => 'A-mount lenses on SLT and NEX',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes,
    },
    0x0064 => {
        Name => 'LensParameters',
        Condition => '$$self{Model} !~ /^DSC-/',
        Format => 'int16s[16]',
        Unknown => 1,
        PrintConv => 'sprintf("%5d" . " %5d" x 15, split(" ",$val))',
    },
    0x0342 => {
        Name => 'LensZoomPosition',
        Condition => '$$self{Model} !~ /^(ILCA-|ILCE-(7RM2|7SM2)|DSC-(HX90V|RX10M2|RX10M3|RX100M4|WX500))/',
        Format => 'int16u',
        PrintConv => 'sprintf("%.0f%%",$val/10.24)',
        PrintConvInv => '$val=~s/ ?%$//; $val * 10.24',
    },
    0x035a => {
        Name => 'LensZoomPosition',
        Condition => '$$self{Model} =~ /^(ILCE-(7RM2|7SM2)|DSC-(HX90V|RX10M2|RX10M3|RX100M4|WX500))/',
        Format => 'int16u',
        PrintConv => 'sprintf("%.0f%%",$val/10.24)',
        PrintConvInv => '$val=~s/ ?%$//; $val * 10.24',
    },
);

# Tag9406 (ref JR)
%Image::ExifTool::Sony::Tag9406 = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
#    0x0000: 1 for A37, A57, A65, A77, NEX-5N, 7, F3, VG20
#            2 for A58/99V, NEX-3N/5R/5T/6/VG30/VG900, ILCE-3000/7/7R/5000/6000
#    0x0001+0x0002: Int16u, seen 580 - 770: similar to "BatteryUnknown" ??
#    0x0005: int8u, seen 73 - 117: maybe Fahrenheit? Higher than "AmbientTemperature", but same trend.
    0x0005 => {
        Name => 'BatteryTemperature',
        ValueConv => '($val - 32) / 1.8', # convert to Celsius
        ValueConvInv => '$val * 1.8 + 32',
        PrintConv => 'sprintf("%.1f C",$val)',
        PrintConvInv => '$val=~s/\s*C//; $val',
    },
    # 0x0006: usually 0, seen non-zero values only for A99V and ILCE-7/7R: BatteryLevel Grip ?
    0x0006 => {
        Name => 'BatteryLevelGrip1',
        Condition => '$$valPt !~ /^\x00/', # only valid when not 0
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
    # 0x0007: seen values from 8 - 105, decreasing in sequences of images: BatteryLevel
    0x0007 => {
        Name => 'BatteryLevel',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
    # 0x0008: usually 255 or 0 (ILCE-7/7R), seen other values only for A99V and ILCE-7/7R when 0x0006 not 0.
    #         A99V with grip can have 3 batteries: => Grip 2;
    #         but ILCE-7/7R with grip can have max 2, and as all ILCE-7/7R samples give >100 values, exclude...
    0x0008 => {
        Name => 'BatteryLevelGrip2',
        Condition => '$$valPt !~ /^[\x00\xff]/ and $$self{Model} !~ /^(ILCE-(7|7R))$/', # only when not 0 or 255 and not for ILCE-7/7R
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~s/\s*\%//; $val',
    },
#    0x0009-0x001a: looks like 9 Int16u values
#    0x0022: 0 or 1 for A99, NEX-5R, 6
#    0x0025: 0 or 1 for other SLT and NEX (0x0022, 0x0023, 0x0024 = 255)
);

# Tag940a (ref PH, decoded mainly from A77)
%Image::ExifTool::Sony::Tag940a = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are currently extracted for SLT models only.',
    # 0x00 - 10(A65,A77,NEX-5N,7,VG20E), 11(A37,A57,A99,NEX-5R,6,F3,RX1,RX100),
    #        9(HX9V), 4,68,86,110(panoramas) - ref JR
    0x04 => {
        Name => 'AFPointsSelected',
        Format => 'int32u',
        PrintConvColumns => 2,
        PrintConv => {
            # verified for A77 firmware 1.03 and 1.07 and A99 firmware 1.00,
            # but there were inconsistencies with my A77 firmware 1.04 samples - PH
            0 => '(none)',
            0x00007801 => 'Center Zone',
            0x0001821c => 'Right Zone',
            0x000605c0 => 'Left Zone',
            0x7fffffff => '(all)',
            # 0xffffffff - 'n/a' - RX1 and NEX models always give this
            # (on Wide AFAreaMode, outer focus points are dropped
            #  at progressively higher digital zoom ratios, ref JR)
            BITMASK => {
                0 => 'Center',          # (1.04 gave this for Upper-middle and Near Left)
                1 => 'Top',             # (1.04 didn't give this value)
                2 => 'Upper-right',     # (1.04 OK)
                3 => 'Right',           # (1.04 didn't give this value)
                4 => 'Lower-right',     # (1.04 gave this for Bottom)
                5 => 'Bottom',          # (1.04 gave this for Lower-middle)
                6 => 'Lower-left',      # (1.04 gave this for Left and Lower Far Left)
                7 => 'Left',            # (1.04 gave this for Far Left)
                8 => 'Upper-left',      # (1.04 OK)
                9 => 'Far Right',       # (1.04 gave this for Upper Far Right and Right)
                10 => 'Far Left',       # (1.04 didn't give this value)
                11 => 'Upper-middle',   # (1.04 gave this for Top)
                12 => 'Near Right',     # (1.04 gave this for Center)
                13 => 'Lower-middle',   # (1.04 gave this for Lower-left and Near Right)
                14 => 'Near Left',      # (1.04 didn't give this value)
                15 => 'Upper Far Right',# (1.04 didn't give this value)
                16 => 'Lower Far Right',# (1.04 OK, but gave this for Far Right and Lower-right too)
                17 => 'Lower Far Left', # (1.04 didn't give this value)
                18 => 'Upper Far Left', # (1.04 OK)
                # higher bits may be used in panorama images - ref JR
            },
        },
    },
    # 0x0a - int16u: 0,1,2,3
    # 0xa6 - 8 bytes face detection info ?; starts with 1, otherwise all 0
);

# Tag940c (ref JR)
%Image::ExifTool::Sony::Tag940c = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    DATAMEMBER => [ 0x0008 ],
    NOTES => 'NEX and ILCE models only.',

    # 0x0001 - 0 for all NEX and ILCE-3000/3500, 20 for all other ILCE (17 for ILCE samples from Sony.net)
    # 0x0008 - LensMount, but different values from Tag9405-0x0105 and Tag9050-0x0604.
    # don't know what difference is between values '1' and '5' ...
    0x0008 => {
        Name => 'LensMount2', # ? maybe some other meaning ? (A-mount adapter-only images give 0)
        RawConv => '$$self{LensMount} = $val',
        PrintConv => {
            0 => 'Unknown',
            1 => 'A-mount (1)',
            4 => 'E-mount',
            5 => 'A-mount (5)',
        },
    },
    # 0x0009 - LensType3:
    # This tag appears to also indicate adapter info, similar to CameraSettings3-0x03f7 for the original NEX-3/5.
    # (Tag9405-0x0605 and Tag9050-0x0107 LensType2 always give '0' for adapters/A-mount lenses.)
    # - seen a few instances of 0x0009 indicating an E-mount lens, but 0xb027 LensType indicating an A-mount lens:
    #   possibly due to adapter info not being read/reset correctly ?
    0x0009 => {
        Name => 'LensType3',
        RawConv => '(($$self{LensMount} != 0) or ($val > 0 and $val < 32784)) ? $val : undef',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%sonyLensTypes2,
    },
    0x000b => {
        Name => 'CameraE-mountVersion',
        Format => 'int16u',
        PrintConv => 'sprintf("%x.%.2x",$val>>8,$val&0xff)',
        PrintConvInv => 'my @a=split(/\./,$val);(hex($a[0])<<8)|hex($a[1])',
        # camera Firmware versions:
        # 1.00 - 1.04: seen in CameraSettings3 0x03f3 for NEX-3/5/5C/C3/VG10E
        # 1.14: NEX-5N/5R/6/7/F3/VG20E/VG30E/VG900 v1.00, NEX-5N v1.01, NEX-3N v0.90
        # 1.20: NEX-3N v1.00, NEX-6 v1.01, NEX-7 v1.02, ILCE-3000 v1.00, ILCE-3500 v1.01
        # 1.30: NEX-5T v1.00, NEX-6 v1.02/v1.03, NEX-7 v1.03
        # 1.31: ILCE-7/7R v0.95/v1.00/v1.01, ILCE-5000
        # 1.40: ILCE-7/7R v1.02/v1.10, ILCE-7S v1.00, ILCE-5100/6000/QX1
        # 1.50: ILCE-7/7R/7S v1.20/v2.00, ILCE-7M2/7RM2/7SM2, ILCE-6000 v1.20/v2.00
        # 1.60: ILCE-6300, ILCE-7RM2 v3.05/v3.10
    },
    0x000d => {
        Name => 'LensE-mountVersion',
        Format => 'int16u',
        PrintConv => 'sprintf("%x.%.2x",$val>>8,$val&0xff)',
        PrintConvInv => 'my @a=split(/\./,$val);(hex($a[0])<<8)|hex($a[1])',
        # lens models:
        # 0.00: Unknown lenses/adapters
        # 1.00: SEL18200LE, Sigma DN, Tamron Di III, Zeiss Touit
        # 1.07: (Ver.01) original E-lenses (SEL16F28, SEL18200, SEL1855, SEL24F18Z, SEL30M35, SEL50F18, SEL55210) and LA-EA1
        # 1.08: LA-EA1 (Ver.02), Metabones Smart
        # 1.14: LA-EA2
        # 1.20: (Ver.02) firmware-updated E-lenses (SEL1855, SEL24F18Z, SEL30M35, SEL50F18, SEL55210),
        #       newer E-lenses (SEL1018, SEL1670Z, SEL20F28, SEL35F18, SELP1650, SELP18105G, SELP18200) or LA-EA3
        # 1.30: LA-EA4
        # 1.31: original FE-lenses (SEL2470Z, SEL2870, SEL35F28Z, SEL55F18Z), SEL1850
        # 1.35: SEL70200G, SEL55210 (Black?, seen with ILCE-3500)
        # 1.40: SEL1635Z, SEL24240, SEL35F14Z, SELP28135G, Zeiss Loxia 35mm/50mm Ver.01
        # 1.50: SEL28F20, SEL90M28G, Zeiss Batis 25mm/85mm, Zeiss Loxia 21mm, Zeiss Loxia 50mm Ver.02
        # 1.60: SEL85F14GM, SEL2470GM, SEL70200GM, SEL50F18F, SEL70300G, Sigma 30mm F1.4 DC DN
    },
    0x0015 => {
        Name => 'LensFirmwareVersion',
        Format => 'int8u',
        PrintConv => 'sprintf("Ver.%.2x",$val)',
        PrintConvInv => '$val=~/Ver\.//; hex($val)',
        # 0x00: Sony Ver.00
        # 0x01: Sony Ver.01
        # 0x02: Sony Ver.02
        # 0x16: Metabones V0.16
        # 0x19: Metabones V0.19
        # 0x22: Metabones V0.22
        # 0x24: Metabones V0.24
        # 0x30: Metabones V0.30
        # 0x32: Metabones V0.32
        # 0x41: Metabones V0.41 (ILCE-7RM2 with Metabones Smart IV)
    },
    # 0x0016 - 0x003f: non-0 data present when: 0x0001>0 AND 0x0008=4(E-mount) AND 0x000f<255
);


# AFInfo (SLT models only) (ref PH, decoded mainly from A77)
%Image::ExifTool::Sony::AFInfo = (
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0x02 ],
    IS_SUBDIR => [ 0x11 ],
    NOTES => 'These tags are currently extracted for SLT models only.',
    # first 4 bytes (deciphered) (ref JR):
    #   0 1 1 0  for A37, A57, A58
    #   2 1 1 0  for A65V
    #   2 1 2 0  for A77V
    #   0 1 2 0  for A99V
    #   1 1 3 0  for ILCA-68/77M2
    #   0 0 0 0  for NEX and ILCE-3000/3500
    #   1 0 0 0  for ILCE-5000/5100/6000/7/7M2/7R/7S/QX1
    #   6 0 0 0  for ILCE-7RM2/7SM2
    #   0 2 0 0  for NEX/ILCE with LA-EA2/EA4 Phase-AF adapter
    #   2 0 0 0  seen for a few NEX-5N images
    #   2 2 0 0  seen for a few NEX-5N/7 images with LA-EA2 adapter
    0x02 => {
        Name => 'AFType',
        RawConv => '$$self{AFType} = $val',
        PrintConv => {
            # 0 => '?? n.a.', # seen on some A99V images with non-AF (Samyang) lens
            1 => '15-point',
            2 => '19-point',
            3 => '79-point', # ILCA-68/77M2
        },
    },

### decoding for SLT; ILCA-68/77M2 (AFType == 3) uses different offsets: see below

    0x04 => {
        Name => 'AFStatusActiveSensor',
        Condition => '$$self{Model} !~ /^ILCA-/',
        %Image::ExifTool::Minolta::afStatusInfo,
    },
    0x07 => [ # the active AF sensor
        {
            Name => 'AFPoint',
            Condition => '$$self{AFType} == 1',
            Notes => 'models with 15-point AF',
            PrintConvColumns => 2,
            PrintConv => \%afPoint15,
        },{
            Name => 'AFPoint',
            Condition => '$$self{AFType} == 2',
            Notes => 'models with 19-point AF',
            PrintConvColumns => 2,
            PrintConv => \%afPoint19,
        },
    ],
    0x08 => [ # the AF sensor in focus at focus time (shutter release half press)
        {
            Name => 'AFPointInFocus',
            Condition => '$$self{AFType} == 1',
            Notes => 'models with 15-point AF',
            PrintConvColumns => 2,
            PrintConv => {
                %afPoint15,
                255 => '(none)',
            },
        },{
            Name => 'AFPointInFocus',
            Condition => '$$self{AFType} == 2',
            Notes => 'models with 19-point AF',
            PrintConvColumns => 2,
            PrintConv => {
                %afPoint19,
                255 => '(none)',
            },
        },
    ],
    0x09 => [ # the AF sensor in focus at shutter release (shutter release full press)
        {
            Name => 'AFPointAtShutterRelease',
            Condition => '$$self{AFType} == 1',
            Notes => 'models with 15-point AF',
            PrintConvColumns => 2,
            PrintConv => {
                %afPoint15,
                30 => '(out of focus)',
            },
        },{
            Name => 'AFPointAtShutterRelease',
            Condition => '$$self{AFType} == 2',
            Notes => 'models with 19-point AF',
            PrintConvColumns => 2,
            PrintConv => {
                %afPoint19,
                30 => '(out of focus)',
            },
        },
    ],
    0x0a => {
        Name => 'AFAreaMode',
        Condition => '$$self{Model} !~ /^ILCA-/',
        PrintConv => {
            0 => 'Wide',
            1 => 'Spot',
            2 => 'Local',
            3 => 'Zone',
        },
    },
    0x0b => {
        Name => 'FocusMode',
        Condition => '$$self{Model} !~ /^ILCA-/',
        PrintConvColumns => 2,
        # validated for A77 firmware 1.03, 1.04 and 1.07 and A99
        # - not confirmed for A37,A57 and A65 which also write this tag
        PrintConv => {
            0 => 'Manual',
            2 => 'AF-S',
            3 => 'AF-C',
            4 => 'AF-A',
            6 => 'DMF',
            7 => 'AF-D', # (unique to A99)
        },
    },
    0x11 => [ #JR
        {
            Name => 'AFStatus15',
            Condition => '$$self{AFType} == 1',
            Format => 'int16s[18]',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::AFStatus15' },
        },{
            Name => 'AFStatus19',
            Condition => '$$self{AFType} == 2',
            Format => 'int16s[30]',
            SubDirectory => { TagTable => 'Image::ExifTool::Sony::AFStatus19' },
        },
    ],
    # 0x004d - 18 or 30 int16 values
    # 0x0089 - 18 or 30 int16 values
    # 0x00b1 - 18 or 30 int16 values
    # 0x0121 - 18 or 30 int16s values, similar to 0x11 AFStatus
    # 0x016e - SLT: 4 bytes indicating 'AFPointsUsed', identical to first 4 bytes of 0x2020 for A58/A99V
    0x016e => {
        Name => 'AFPointsUsed',
        Condition => '$$self{Model} !~ /^ILCA-/',
        Notes => 'SLT models only',
        Format => 'int32u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Center',
                1 => 'Top',
                2 => 'Upper-right',
                3 => 'Right',
                4 => 'Lower-right',
                5 => 'Bottom',
                6 => 'Lower-left',
                7 => 'Left',
                8 => 'Upper-left',
                9 => 'Far Right',
                10 => 'Far Left',
                11 => 'Upper-middle',
                12 => 'Near Right',
                13 => 'Lower-middle',
                14 => 'Near Left',
                15 => 'Upper Far Right',
                16 => 'Lower Far Right',
                17 => 'Lower Far Left',
                18 => 'Upper Far Left',
            },
        },
    },
    # 0x017b and 0x017c also have to do with AFMicroAdj (ref JR)
    0x017d => { #PH (verified for the SLT-A77/A99; other SLT models don't have this setting - ref JR)
        # (different from AFMicroAdjValue because it is 0 when the adjustment is off)
        Name => 'AFMicroAdj',
        Condition => '$$self{Model} !~ /^ILCA-/',
        Format => 'int8s',
    },
    0x017e => { #JR
        Name => 'ExposureProgram',
        Condition => '$$self{Model} !~ /^ILCA-/',
        Priority => 0,
        SeparateTable => 'ExposureProgram3',
        PrintConv => \%sonyExposureProgram3,
    },
    # 0x01b8 - 65 AF Info blocks of 180 bytes each for SLT (ref JR)
    # In each block, the 9th, 10th and 11th byte appear to relate to AFPoint as at offsets 0x07, 0x08, 0x09 above..
    # Possibly, these blocks relate to sequential focusing attempts and/or object tracking,
    # the first byte being an Index or Counter.
    # The last block before the block with index 0, appears to relate to the AF data at ShutterRelease.

    # 0xf38,0x1208,0x14d8,0x158c,0x1640,(and more) - 0 if AFMicroAdj is On, 1 if Off
    # 0x1ab6 - 0x80 if AFMicroAdj is On, 0 if Off
    # tags also related to AFPoint (PH, A77):
    #   0x11ec, 0x122a, 0x1408, 0x1446, 0x14bc, 0x1f86,
    #   0x14fa, 0x1570, 0x1572, 0x15ae, 0x1f48

### decoding for ILCA-68/77M2, AFType == 3

    0x0005 => { #JR
        Name => 'FocusMode',
        Condition => '$$self{Model} =~ /^ILCA-/',
        Notes => 'ILCA models only',
        Writable => 'int8u',
        Priority => 0,
        PrintConv => {
            0 => 'Manual',
            2 => 'AF-S',
            3 => 'AF-C',
            4 => 'AF-A',
            # 6 => 'DMF', # not yet seen
            # 7 => 'AF-D', # not yet seen
        },
    },
    # 0x0010 - for ILCA-68/77M2: 10 bytes identical to 0x2020, and probably indicating 'AFPointsUsed' (ref JR)
    0x0010 => {
        Name => 'AFPointsUsed',
        Condition => '$$self{Model} =~ /^ILCA-/',
        Format => 'int8u[10]',
        BitsPerWord => 8,
        BitsTotal => 80,
        PrintConv => {
            0 => '(none)',
            BITMASK => { %afPoints79 },
        },
    },
    # 0x0037, 0x0038, 0x0039 similar to 0x07, 0x08, 0x09, but using numbers from 0-94 for ILCA-68/77M2
    0x0037 => { # the active AF sensor
        Name => 'AFPoint',
        Condition => '$$self{AFType} == 3',
        PrintConv => {
            %afPoints79_940e,
            255 => '(none)',
        },
    },
    0x0038 => { # the AF sensor in focus at focus time (shutter release half press)
        Name => 'AFPointInFocus',
        Condition => '$$self{AFType} == 3',
        PrintConv => {
            %afPoints79_940e,
            255 => '(none)',
        },
    },
    0x0039 => { # the AF sensor in focus at shutter release (shutter release full press)
        Name => 'AFPointAtShutterRelease',
        Condition => '$$self{AFType} == 3',
        PrintConv => {
            %afPoints79_940e,
            95 => '(none)',
        },
    },
    0x003a => { #JR
        Name => 'AFAreaMode',
        Condition => '$$self{Model} =~ /^ILCA-/',
        PrintConv => {
            0 => 'Wide',
            1 => 'Center',
            2 => 'Flexible Spot',
            3 => 'Zone',
            4 => 'Expanded Flexible Spot', # (NC)
        },
    },
    0x003b => {
        Name => 'AFStatusActiveSensor',
        Condition => '$$self{Model} =~ /^ILCA-/',
        %Image::ExifTool::Minolta::afStatusInfo,
    },
    0x0043 => {
        Name => 'ExposureProgram',
        Condition => '$$self{Model} =~ /^ILCA-/',
        Priority => 0,
        SeparateTable => 'ExposureProgram3',
        PrintConv => \%sonyExposureProgram3,
    },
    # 0x004e and 0x004f also have to do with AFMicroAdj (ref JR)
    0x0050 => { #PH (ILCA-A77M2, to be confirmed for other ILCA models)
        Name => 'AFMicroAdj',
        Condition => '$$self{Model} =~ /^ILCA-/',
        Format => 'int8s',
    },
    # 0x007d - AFStatus79 - 95 int16s values for the ILCA-68/77M2 79 AF points + 15 cross + 1 F2.8
    0x007d => {
        Name => 'AFStatus79',
        Condition => '$$self{AFType} == 3',
        Format => 'int16s[95]',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::AFStatus79' },
    },
    # 0x013b - 95 int8u values
    # 0x01ab - 95 int8u values
    # 0x021b - 95 int16s values, similar to 0x007d AFStatus79
    # 0x04c0 - 45 AF Info blocks of 244 bytes each for ILCA
);

%Image::ExifTool::Sony::Tag940e = ( #JR
    PROCESS_PROC => \&ProcessEnciphered,
    WRITE_PROC => \&WriteEnciphered,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'E-mount models.',

    # (see comment in AFInfo for deciphered values of first 4 bytes for various models)

    # 0x0004 - if 0x0001 == 2: LA-EA2/EA4 15-point SLT Phase-detect AF adapter used:
    #          start of 164-byte AF Info Blocks, possibly the 11th byte might be the AFPoint.
    #          ILCE-7M2:       40 Blocks of 164 bytes (probably also for 7RM2: tbc)
    #          other NEX/ILCE: 74 blocks of 164 bytes

    # 0x1a06 onwards - first seen for ILCE-7RM2: appears to be some kind of metering image
    0x1a06 => { Name => 'TiffMeteringImageWidth',  Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))\b/' },
    0x1a07 => { Name => 'TiffMeteringImageHeight', Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))\b/' },
    0x1a08 => { # (2640 bytes: 1 set of 44x30 int16u values)
        Name => 'TiffMeteringImage',
        Condition => '$$self{Model} =~ /^(ILCE-(6300|7RM2|7SM2))\b/',
        Format => 'undef[2640]',
        Notes => q{
            13(?)-bit intensity data from 1320 (1200) metering segments, extracted as a
            16-bit TIFF image
        },
        ValueConv => sub {
            my ($val, $et) = @_;
            return undef unless length $val >= 2640;
            return \ "Binary data 2640 bytes" unless $et->Options('Binary');
            my @dat = unpack('v*', $val);
            # TIFF header for a 16-bit RGB 10dpi 44x30 image
            $val = MakeTiffHeader(44,30,3,16,10);
            # re-order data to RGB pixels - use same value for R, G and B
            my ($i, @val);
            for ($i=0; $i<44*30; ++$i) {
                # data is 13-bit (max 8191), shift left to fill 16 bits
                push @val, int(5041.1*log($dat[$i]+1)/log(2)), int(5041.1*log($dat[$i]+1)/log(2)), int(5041.1*log($dat[$i]+1)/log(2));
            }
            $val .= pack('v*', @val);   # add TIFF strip data
            return \$val;
        },
    },
);

# AF Point Status (ref JR)
%Image::ExifTool::Sony::AFStatus15 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'AF Status information for models with 15-point AF.',
    0x00 => { Name => 'AFStatusUpper-left',           %Image::ExifTool::Minolta::afStatusInfo },
    0x02 => { Name => 'AFStatusLeft',                 %Image::ExifTool::Minolta::afStatusInfo },
    0x04 => { Name => 'AFStatusLower-left',           %Image::ExifTool::Minolta::afStatusInfo },
    0x06 => { Name => 'AFStatusFarLeft',              %Image::ExifTool::Minolta::afStatusInfo },
    0x08 => { Name => 'AFStatusTopHorizontal',        %Image::ExifTool::Minolta::afStatusInfo },
    0x0a => { Name => 'AFStatusNearRight',            %Image::ExifTool::Minolta::afStatusInfo },
    0x0c => { Name => 'AFStatusCenterHorizontal',     %Image::ExifTool::Minolta::afStatusInfo },
    0x0e => { Name => 'AFStatusNearLeft',             %Image::ExifTool::Minolta::afStatusInfo },
    0x10 => { Name => 'AFStatusBottomHorizontal',     %Image::ExifTool::Minolta::afStatusInfo },
    0x12 => { Name => 'AFStatusTopVertical',          %Image::ExifTool::Minolta::afStatusInfo },
    0x14 => { Name => 'AFStatusCenterVertical',       %Image::ExifTool::Minolta::afStatusInfo },
    0x16 => { Name => 'AFStatusBottomVertical',       %Image::ExifTool::Minolta::afStatusInfo },
    0x18 => { Name => 'AFStatusFarRight',             %Image::ExifTool::Minolta::afStatusInfo },
    0x1a => { Name => 'AFStatusUpper-right',          %Image::ExifTool::Minolta::afStatusInfo },
    0x1c => { Name => 'AFStatusRight',                %Image::ExifTool::Minolta::afStatusInfo },
    0x1e => { Name => 'AFStatusLower-right',          %Image::ExifTool::Minolta::afStatusInfo },
    0x20 => { Name => 'AFStatusUpper-middle',         %Image::ExifTool::Minolta::afStatusInfo },
    0x22 => { Name => 'AFStatusLower-middle',         %Image::ExifTool::Minolta::afStatusInfo },
);

# AF Point Status (ref JR)
%Image::ExifTool::Sony::AFStatus19 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'AF Status information for models with 19-point AF.',
    0x00 => { Name => 'AFStatusUpperFarLeft',         %Image::ExifTool::Minolta::afStatusInfo },
    0x02 => { Name => 'AFStatusUpper-leftHorizontal', %Image::ExifTool::Minolta::afStatusInfo },
    0x04 => { Name => 'AFStatusFarLeftHorizontal',    %Image::ExifTool::Minolta::afStatusInfo },
    0x06 => { Name => 'AFStatusLeftHorizontal',       %Image::ExifTool::Minolta::afStatusInfo },
    0x08 => { Name => 'AFStatusLowerFarLeft',         %Image::ExifTool::Minolta::afStatusInfo },
    0x0a => { Name => 'AFStatusLower-leftHorizontal', %Image::ExifTool::Minolta::afStatusInfo },
    0x0c => { Name => 'AFStatusUpper-leftVertical',   %Image::ExifTool::Minolta::afStatusInfo },
    0x0e => { Name => 'AFStatusLeftVertical',         %Image::ExifTool::Minolta::afStatusInfo },
    0x10 => { Name => 'AFStatusLower-leftVertical',   %Image::ExifTool::Minolta::afStatusInfo },
    0x12 => { Name => 'AFStatusFarLeftVertical',      %Image::ExifTool::Minolta::afStatusInfo },
    0x14 => { Name => 'AFStatusTopHorizontal',        %Image::ExifTool::Minolta::afStatusInfo },
    0x16 => { Name => 'AFStatusNearRight',            %Image::ExifTool::Minolta::afStatusInfo },
    0x18 => { Name => 'AFStatusCenterHorizontal',     %Image::ExifTool::Minolta::afStatusInfo },
    0x1a => { Name => 'AFStatusNearLeft',             %Image::ExifTool::Minolta::afStatusInfo },
    0x1c => { Name => 'AFStatusBottomHorizontal',     %Image::ExifTool::Minolta::afStatusInfo },
    0x1e => { Name => 'AFStatusTopVertical',          %Image::ExifTool::Minolta::afStatusInfo },
    0x20 => { Name => 'AFStatusUpper-middle',         %Image::ExifTool::Minolta::afStatusInfo },
    0x22 => { Name => 'AFStatusCenterVertical',       %Image::ExifTool::Minolta::afStatusInfo },
    0x24 => { Name => 'AFStatusLower-middle',         %Image::ExifTool::Minolta::afStatusInfo },
    0x26 => { Name => 'AFStatusBottomVertical',       %Image::ExifTool::Minolta::afStatusInfo },
    0x28 => { Name => 'AFStatusUpperFarRight',        %Image::ExifTool::Minolta::afStatusInfo },
    0x2a => { Name => 'AFStatusUpper-rightHorizontal',%Image::ExifTool::Minolta::afStatusInfo },
    0x2c => { Name => 'AFStatusFarRightHorizontal',   %Image::ExifTool::Minolta::afStatusInfo },
    0x2e => { Name => 'AFStatusRightHorizontal',      %Image::ExifTool::Minolta::afStatusInfo },
    0x30 => { Name => 'AFStatusLowerFarRight',        %Image::ExifTool::Minolta::afStatusInfo },
    0x32 => { Name => 'AFStatusLower-rightHorizontal',%Image::ExifTool::Minolta::afStatusInfo },
    0x34 => { Name => 'AFStatusFarRightVertical',     %Image::ExifTool::Minolta::afStatusInfo },
    0x36 => { Name => 'AFStatusUpper-rightVertical',  %Image::ExifTool::Minolta::afStatusInfo },
    0x38 => { Name => 'AFStatusRightVertical',        %Image::ExifTool::Minolta::afStatusInfo },
    0x3a => { Name => 'AFStatusLower-rightVertical',  %Image::ExifTool::Minolta::afStatusInfo },
);

# AF Point Status (ref JR)
%Image::ExifTool::Sony::AFStatus79 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'AF Status information for models with 79-point AF.',
#
# ILCA-68/77M2 AF sensor layout:
#                           A5*  A6*  A7*
#         B2   B3   B4      B5   B6   B7      B8   B9   B10
#    C1   C2   C3   C4      C5*  C6*  C7*     C8   C9   C10   C11
#    D1   D2   D3   D4      D5   D6   D7      D8   D9   D10   D11
#    E1   E2   E3   E4      E5*  E6*  E7*     E8   E9   E10   E11
#    F1   F2   F3   F4      F5   F6   F7      F8   F9   F10   F11
#    G1   G2   G3   G4      G5*  G6*  G7*     G8   G9   G10   G11
#         H2   H3   H4      H5   H6   H7      H8   H9   H10
#                           I5*  I6*  I7*
# left section, from top to bottom, from right to left
    0x00 => { Name => 'AFStatus_00_B4', %Image::ExifTool::Minolta::afStatusInfo },
    0x02 => { Name => 'AFStatus_01_C4', %Image::ExifTool::Minolta::afStatusInfo },
    0x04 => { Name => 'AFStatus_02_D4', %Image::ExifTool::Minolta::afStatusInfo },
    0x06 => { Name => 'AFStatus_03_E4', %Image::ExifTool::Minolta::afStatusInfo },
    0x08 => { Name => 'AFStatus_04_F4', %Image::ExifTool::Minolta::afStatusInfo },
    0x0a => { Name => 'AFStatus_05_G4', %Image::ExifTool::Minolta::afStatusInfo },
    0x0c => { Name => 'AFStatus_06_H4', %Image::ExifTool::Minolta::afStatusInfo },
    0x0e => { Name => 'AFStatus_07_B3', %Image::ExifTool::Minolta::afStatusInfo },
    0x10 => { Name => 'AFStatus_08_C3', %Image::ExifTool::Minolta::afStatusInfo },
    0x12 => { Name => 'AFStatus_09_D3', %Image::ExifTool::Minolta::afStatusInfo },
    0x14 => { Name => 'AFStatus_10_E3', %Image::ExifTool::Minolta::afStatusInfo },
    0x16 => { Name => 'AFStatus_11_F3', %Image::ExifTool::Minolta::afStatusInfo },
    0x18 => { Name => 'AFStatus_12_G3', %Image::ExifTool::Minolta::afStatusInfo },
    0x1a => { Name => 'AFStatus_13_H3', %Image::ExifTool::Minolta::afStatusInfo },
    0x1c => { Name => 'AFStatus_14_B2', %Image::ExifTool::Minolta::afStatusInfo },
    0x1e => { Name => 'AFStatus_15_C2', %Image::ExifTool::Minolta::afStatusInfo },
    0x20 => { Name => 'AFStatus_16_D2', %Image::ExifTool::Minolta::afStatusInfo },
    0x22 => { Name => 'AFStatus_17_E2', %Image::ExifTool::Minolta::afStatusInfo },
    0x24 => { Name => 'AFStatus_18_F2', %Image::ExifTool::Minolta::afStatusInfo },
    0x26 => { Name => 'AFStatus_19_G2', %Image::ExifTool::Minolta::afStatusInfo },
    0x28 => { Name => 'AFStatus_20_H2', %Image::ExifTool::Minolta::afStatusInfo },
    0x2a => { Name => 'AFStatus_21_C1', %Image::ExifTool::Minolta::afStatusInfo },
    0x2c => { Name => 'AFStatus_22_D1', %Image::ExifTool::Minolta::afStatusInfo },
    0x2e => { Name => 'AFStatus_23_E1', %Image::ExifTool::Minolta::afStatusInfo },
    0x30 => { Name => 'AFStatus_24_F1', %Image::ExifTool::Minolta::afStatusInfo },
    0x32 => { Name => 'AFStatus_25_G1', %Image::ExifTool::Minolta::afStatusInfo },
# center section, cross-sensors *, from right to left, from top to bottom
# These are presumably Vertical, as all others are default Horizontal (ref Sony ILCA-77M2 brochure).
    0x34 => { Name => 'AFStatus_26_A7_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x36 => { Name => 'AFStatus_27_A6_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x38 => { Name => 'AFStatus_28_A5_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x3a => { Name => 'AFStatus_29_C7_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x3c => { Name => 'AFStatus_30_C6_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x3e => { Name => 'AFStatus_31_C5_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x40 => { Name => 'AFStatus_32_E7_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x42 => { Name => 'AFStatus_33_E6_Center_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x44 => { Name => 'AFStatus_34_E5_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x46 => { Name => 'AFStatus_35_G7_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x48 => { Name => 'AFStatus_36_G6_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x4a => { Name => 'AFStatus_37_G5_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x4c => { Name => 'AFStatus_38_I7_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x4e => { Name => 'AFStatus_39_I6_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
    0x50 => { Name => 'AFStatus_40_I5_Vertical', %Image::ExifTool::Minolta::afStatusInfo },
# center section, all sensors, from top to bottom, from right to left
    0x52 => { Name => 'AFStatus_41_A7', %Image::ExifTool::Minolta::afStatusInfo },
    0x54 => { Name => 'AFStatus_42_B7', %Image::ExifTool::Minolta::afStatusInfo },
    0x56 => { Name => 'AFStatus_43_C7', %Image::ExifTool::Minolta::afStatusInfo },
    0x58 => { Name => 'AFStatus_44_D7', %Image::ExifTool::Minolta::afStatusInfo },
    0x5a => { Name => 'AFStatus_45_E7', %Image::ExifTool::Minolta::afStatusInfo },
    0x5c => { Name => 'AFStatus_46_F7', %Image::ExifTool::Minolta::afStatusInfo },
    0x5e => { Name => 'AFStatus_47_G7', %Image::ExifTool::Minolta::afStatusInfo },
    0x60 => { Name => 'AFStatus_48_H7', %Image::ExifTool::Minolta::afStatusInfo },
    0x62 => { Name => 'AFStatus_49_I7', %Image::ExifTool::Minolta::afStatusInfo },
    0x64 => { Name => 'AFStatus_50_A6', %Image::ExifTool::Minolta::afStatusInfo },
    0x66 => { Name => 'AFStatus_51_B6', %Image::ExifTool::Minolta::afStatusInfo },
    0x68 => { Name => 'AFStatus_52_C6', %Image::ExifTool::Minolta::afStatusInfo },
    0x6a => { Name => 'AFStatus_53_D6', %Image::ExifTool::Minolta::afStatusInfo },
    0x6c => { Name => 'AFStatus_54_E6_Center', %Image::ExifTool::Minolta::afStatusInfo },
    0x6e => { Name => 'AFStatus_55_F6', %Image::ExifTool::Minolta::afStatusInfo },
    0x70 => { Name => 'AFStatus_56_G6', %Image::ExifTool::Minolta::afStatusInfo },
    0x72 => { Name => 'AFStatus_57_H6', %Image::ExifTool::Minolta::afStatusInfo },
    0x74 => { Name => 'AFStatus_58_I6', %Image::ExifTool::Minolta::afStatusInfo },
    0x76 => { Name => 'AFStatus_59_A5', %Image::ExifTool::Minolta::afStatusInfo },
    0x78 => { Name => 'AFStatus_60_B5', %Image::ExifTool::Minolta::afStatusInfo },
    0x7a => { Name => 'AFStatus_61_C5', %Image::ExifTool::Minolta::afStatusInfo },
    0x7c => { Name => 'AFStatus_62_D5', %Image::ExifTool::Minolta::afStatusInfo },
    0x7e => { Name => 'AFStatus_63_E5', %Image::ExifTool::Minolta::afStatusInfo },
    0x80 => { Name => 'AFStatus_64_F5', %Image::ExifTool::Minolta::afStatusInfo },
    0x82 => { Name => 'AFStatus_65_G5', %Image::ExifTool::Minolta::afStatusInfo },
    0x84 => { Name => 'AFStatus_66_H5', %Image::ExifTool::Minolta::afStatusInfo },
    0x86 => { Name => 'AFStatus_67_I5', %Image::ExifTool::Minolta::afStatusInfo },
# right section, from top to bottom, from right to left
    0x88 => { Name => 'AFStatus_68_C11', %Image::ExifTool::Minolta::afStatusInfo },
    0x8a => { Name => 'AFStatus_69_D11', %Image::ExifTool::Minolta::afStatusInfo },
    0x8c => { Name => 'AFStatus_70_E11', %Image::ExifTool::Minolta::afStatusInfo },
    0x8e => { Name => 'AFStatus_71_F11', %Image::ExifTool::Minolta::afStatusInfo },
    0x90 => { Name => 'AFStatus_72_G11', %Image::ExifTool::Minolta::afStatusInfo },
    0x92 => { Name => 'AFStatus_73_B10', %Image::ExifTool::Minolta::afStatusInfo },
    0x94 => { Name => 'AFStatus_74_C10', %Image::ExifTool::Minolta::afStatusInfo },
    0x96 => { Name => 'AFStatus_75_D10', %Image::ExifTool::Minolta::afStatusInfo },
    0x98 => { Name => 'AFStatus_76_E10', %Image::ExifTool::Minolta::afStatusInfo },
    0x9a => { Name => 'AFStatus_77_F10', %Image::ExifTool::Minolta::afStatusInfo },
    0x9c => { Name => 'AFStatus_78_G10', %Image::ExifTool::Minolta::afStatusInfo },
    0x9e => { Name => 'AFStatus_79_H10', %Image::ExifTool::Minolta::afStatusInfo },
    0xa0 => { Name => 'AFStatus_80_B9', %Image::ExifTool::Minolta::afStatusInfo },
    0xa2 => { Name => 'AFStatus_81_C9', %Image::ExifTool::Minolta::afStatusInfo },
    0xa4 => { Name => 'AFStatus_82_D9', %Image::ExifTool::Minolta::afStatusInfo },
    0xa6 => { Name => 'AFStatus_83_E9', %Image::ExifTool::Minolta::afStatusInfo },
    0xa8 => { Name => 'AFStatus_84_F9', %Image::ExifTool::Minolta::afStatusInfo },
    0xaa => { Name => 'AFStatus_85_G9', %Image::ExifTool::Minolta::afStatusInfo },
    0xac => { Name => 'AFStatus_86_H9', %Image::ExifTool::Minolta::afStatusInfo },
    0xae => { Name => 'AFStatus_87_B8', %Image::ExifTool::Minolta::afStatusInfo },
    0xb0 => { Name => 'AFStatus_88_C8', %Image::ExifTool::Minolta::afStatusInfo },
    0xb2 => { Name => 'AFStatus_89_D8', %Image::ExifTool::Minolta::afStatusInfo },
    0xb4 => { Name => 'AFStatus_90_E8', %Image::ExifTool::Minolta::afStatusInfo },
    0xb6 => { Name => 'AFStatus_91_F8', %Image::ExifTool::Minolta::afStatusInfo },
    0xb8 => { Name => 'AFStatus_92_G8', %Image::ExifTool::Minolta::afStatusInfo },
    0xba => { Name => 'AFStatus_93_H8', %Image::ExifTool::Minolta::afStatusInfo },
# central F2.8 sensor
    0xbc => { Name => 'AFStatus_94_E6_Center_F2-8', %Image::ExifTool::Minolta::afStatusInfo },
);

%Image::ExifTool::Sony::FaceInfo1 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'Face1Position',
        Format => 'int16u[4]',
        Notes => q{
            top, left, height and width of detected face.  Coordinates are relative to
            the full-sized unrotated image, with increasing Y downwards
        },
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
    },
    0x20 => {
        Name => 'Face2Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x40 => {
        Name => 'Face3Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x60 => {
        Name => 'Face4Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x80 => {
        Name => 'Face5Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0xa0 => {
        Name => 'Face6Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0xc0 => {
        Name => 'Face7Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0xe0 => {
        Name => 'Face8Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
);

%Image::ExifTool::Sony::FaceInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x00 => {
        Name => 'Face1Position',
        Format => 'int16u[4]',
        Notes => q{
            top, left, height and width of detected face.  Coordinates are relative to
            the full-sized unrotated image, with increasing Y downwards
        },
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
    },
    0x25 => {
        Name => 'Face2Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x4a => {
        Name => 'Face3Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x6f => {
        Name => 'Face4Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x94 => {
        Name => 'Face5Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0xb9 => {
        Name => 'Face6Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0xde => {
        Name => 'Face7Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0x103 => {
        Name => 'Face8Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
);

# panorama info for cameras such as the HX1, HX5, TX7 (ref 9/PH)
%Image::ExifTool::Sony::Panorama = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int32u',
    NOTES => q{
        Tags found in panorama images from various Sony DSC, NEX, SLT and DSLR
        cameras.  The width/height values of these tags are not affected by camera
        rotation -- the width is always the longer dimension.
    },
    # 0: 257 for panorama images, 0 for all other images (ref JR)
    1 => 'PanoramaFullWidth', # (including black/grey borders)
    2 => 'PanoramaFullHeight',
    3 => {
        Name => 'PanoramaDirection',
        PrintConv => {
            0 => 'Left or Up',
            1 => 'Right or Down',
        },
    },
    # crop area to remove black/grey borders from full image
    4 => 'PanoramaCropLeft',
    5 => 'PanoramaCropTop', #PH guess (NC)
    6 => 'PanoramaCropRight',
    7 => 'PanoramaCropBottom',
    # 8: 1728 (HX1), 1824 (HX5/TX7) (value8/value9 = 16/9)
    8 => 'PanoramaFrameWidth', #PH guess (NC)
    # 9: 972 (HX1), 1026 (HX5/TX7)
    9 => 'PanoramaFrameHeight', #PH guess (NC)
    # 10: 3200-3800 (HX1), 4000-4900 (HX5/TX7)
    10 => 'PanoramaSourceWidth', #PH guess (NC)
    # 11: 800-1800 (larger for taller panoramas)
    11 => 'PanoramaSourceHeight', #PH guess (NC)
    # 12-15: 0
);

# tag table for SRF0 IFD (ref 1)
%Image::ExifTool::Sony::SRF = (
    PROCESS_PROC => \&ProcessSRF,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SRF#', 2 => 'Camera' },
    NOTES => q{
        The maker notes in SRF (Sony Raw Format) images contain 7 IFD's with family
        1 group names SRF0 through SRF6.  SRF0 and SRF1 use the tags in this table,
        while SRF2 through SRF5 use the tags in the next table, and SRF6 uses
        standard EXIF tags.  All information other than SRF0 is encrypted, but
        thanks to Dave Coffin the decryption algorithm is known.  SRF images are
        written by the Sony DSC-F828 and DSC-V3.
    },
    # tags 0-1 are used in SRF1
    0 => {
        Name => 'SRF2Key',
        Notes => 'key to decrypt maker notes from the start of SRF2',
        RawConv => '$$self{SRF2Key} = $val',
    },
    1 => {
        Name => 'DataKey',
        Notes => 'key to decrypt the rest of the file from the end of the maker notes',
        RawConv => '$$self{SRFDataKey} = $val',
    },
    # SRF0 contains a single unknown tag with TagID 0x0003
);

# tag table for Sony RAW Format (ref 1)
%Image::ExifTool::Sony::SRF2 = (
    PROCESS_PROC => \&ProcessSRF,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SRF#', 2 => 'Camera' },
    NOTES => "These tags are found in the SRF2 through SRF5 IFD's.",
    # the following tags are used in SRF2-5
    2 => 'SRF6Offset', #PH
    # SRFDataOffset references 2220 bytes of unknown data for the DSC-F828 - PH
    3 => { Name => 'SRFDataOffset', Unknown => 1 }, #PH
    4 => { Name => 'RawDataOffset' }, #PH
    5 => { Name => 'RawDataLength' }, #PH
    0x0043 => 'MaxApertureAtMaxFocal', #IB
    0x0044 => 'MaxApertureAtMinFocal', #IB
    0x0045 => { #IB
        Name => 'MinFocalLength',
        PrintConv => '"$val mm"',
    },
    0x0046 => { #IB
        Name => 'MaxFocalLength',
        PrintConv => '"$val mm"',
    },
    0x00c0 => 'WBRedDaylight', #IB
    0x00c1 => 'WBGreenDaylight', #IB
    0x00c2 => 'WBBlueDaylight', #IB
    0x00c3 => 'WBRedCloudy', #IB
    0x00c4 => 'WBGreenCloudy', #IB
    0x00c5 => 'WBBlueCloudy', #IB
    0x00c9 => 'WBRedTungsten', #IB
    0x00ca => 'WBGreenTungsten', #IB
    0x00cb => 'WBBlueTungsten', #IB
    0x00cc => 'WBRedFlash', #IB
    0x00cd => 'WBGreenFlash', #IB
    0x00ce => 'WBBlueFlash', #IB
    0x00d0 => 'WBRedAsShot', #IB
    0x00d1 => 'WBGreenAsShot', #IB
    0x00d2 => 'WBBlueAsShot', #IB
);

# tag table for Sony RAW 2 Format Private IFD (ref 1)
%Image::ExifTool::Sony::SR2Private = (
    PROCESS_PROC => \&ProcessSR2,
    WRITE_PROC => \&WriteSR2,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2', 2 => 'Camera' },
    NOTES => q{
        The SR2 format uses the DNGPrivateData tag to reference a private IFD
        containing these tags.  SR2 images are written by the Sony DSC-R1, but
        this information is also written to ARW images by other models.
    },
    0x7200 => {
        Name => 'SR2SubIFDOffset',
        # (adjusting offset messes up calculations for AdobeSR2 in DNG images)
        # Flags => 'IsOffset',
        # (can't set OffsetPair or else DataMember won't be set when writing)
        # OffsetPair => 0x7201,
        DataMember => 'SR2SubIFDOffset',
        RawConv => '$$self{SR2SubIFDOffset} = $val',
    },
    0x7201 => {
        Name => 'SR2SubIFDLength',
        # (can't set OffsetPair or else DataMember won't be set when writing)
        # OffsetPair => 0x7200,
        DataMember => 'SR2SubIFDLength',
        RawConv => '$$self{SR2SubIFDLength} = $val',
    },
    0x7221 => {
        Name => 'SR2SubIFDKey',
        Format => 'int32u',
        Notes => 'key to decrypt SR2SubIFD',
        DataMember => 'SR2SubIFDKey',
        RawConv => '$$self{SR2SubIFDKey} = $val',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
    0x7240 => { #PH
        Name => 'IDC_IFD',
        Groups => { 1 => 'SonyIDC' },
        Condition => '$$valPt !~ /^\0\0\0\0/',   # (just in case this could be zero)
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'SonyIDC',
            TagTable => 'Image::ExifTool::SonyIDC::Main',
            Start => '$val',
        },
    },
    0x7241 => { #PH
        Name => 'IDC2_IFD',
        Groups => { 1 => 'SonyIDC' },
        Condition => '$$valPt !~ /^\0\0\0\0/',   # may be zero if dir doesn't exist
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'SonyIDC2',
            TagTable => 'Image::ExifTool::SonyIDC::Main',
            Start => '$val',
            Base => '$start',
            MaxSubdirs => 20,   # (A900 has 10 null entries, but IDC writes only 1)
            RelativeBase => 1,  # needed to write SubIFD with relative offsets
        },
    },
    0x7250 => { #1
        Name => 'MRWInfo',
        Condition => '$$valPt !~ /^\0\0\0\0/',   # (just in case this could be zero)
        SubDirectory => {
            TagTable => 'Image::ExifTool::MinoltaRaw::Main',
        },
    },
);

%Image::ExifTool::Sony::SR2SubIFD = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2SubIFD', 2 => 'Camera' },
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    NOTES => 'Tags in the encrypted SR2SubIFD',
    0x7300 => 'BlackLevel', #IB (R1)
    0x7302 => 'WB_GRBGLevelsAuto', #IB (R1)
    0x7303 => 'WB_GRBGLevels', #1 (R1 "as shot", ref IB)
    0x7310 => 'BlackLevel', #IB (divide by 4)
    0x7313 => 'WB_RGGBLevels', #6
    0x7480 => 'WB_RGBLevelsDaylight', #IB (R1)
    0x7481 => 'WB_RGBLevelsCloudy', #IB (R1)
    0x7482 => 'WB_RGBLevelsTungsten', #IB (R1)
    0x7483 => 'WB_RGBLevelsFlash', #IB (R1)
    0x7484 => 'WB_RGBLevels4500K', #IB (R1)
    0x7486 => 'WB_RGBLevelsFluorescent', #IB (R1)
    0x74a0 => 'MaxApertureAtMaxFocal', #PH
    0x74a1 => 'MaxApertureAtMinFocal', #PH
    0x74a2 => { #IB (R1)
        Name => 'MaxFocalLength',
        PrintConv => '"$val mm"',
    },
    0x74a3 => { #IB (R1)
        Name => 'MinFocalLength',
        PrintConv => '"$val mm"',
    },
    0x74c0 => { #PH
        Name => 'SR2DataIFD',
        Groups => { 1 => 'SR2DataIFD' }, # (needed to set SubIFD DirName)
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Sony::SR2DataIFD',
            Start => '$val',
            MaxSubdirs => 20, # an A700 ARW has 14 of these! - PH
        },
    },
    0x7800 => 'ColorMatrix', #IB (divide by 1024)
    0x7820 => 'WB_RGBLevelsDaylight', #6 (or 5300K, ref IB)
    0x7821 => 'WB_RGBLevelsCloudy', #6 (or 6100K, ref IB)
    0x7822 => 'WB_RGBLevelsTungsten', #6
    0x7823 => 'WB_RGBLevelsFlash', #IB
    0x7824 => 'WB_RGBLevels4500K', #IB
    0x7825 => 'WB_RGBLevelsShade', #6 (or 7500K, ref IB)
    0x7826 => 'WB_RGBLevelsFluorescent', #6 (~4000K)
    0x7827 => 'WB_RGBLevelsFluorescentP1', #IB (~5000K)
    0x7828 => 'WB_RGBLevelsFluorescentP2', #IB (~6500K) (was Flash, ref 6)
    0x7829 => 'WB_RGBLevelsFluorescentM1', #IB (~3500K)
    0x782a => 'WB_RGBLevels8500K', #IB
    0x782b => 'WB_RGBLevels6000K', #IB
    0x782c => 'WB_RGBLevels3200K', #IB
    0x782d => 'WB_RGBLevels2500K', #IB
    0x787f => 'WhiteLevel', #IB (divide by 4)
    0x7980 => 'ChromaticAberrationCorrParams', #forum6509 (Sony A7 ARW)
    0x7982 => 'DistortionCorrParams', #forum6509 (Sony A7 ARW)
);

%Image::ExifTool::Sony::SR2DataIFD = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'SR2DataIFD', 2 => 'Camera' },
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    # 0x7313 => 'WB_RGGBLevels', (duplicated in all SR2DataIFD's)
    0x7770 => { #PH
        Name => 'ColorMode',
        Priority => 0,
    },
);

# extract information from "SONY PIC\0" maker notes (ref PH)
%Image::ExifTool::Sony::PIC = (
    PROCESS_PROC => \&ProcessSonyPIC,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        The TextInfo data is extracted as a block to preserve the formatting, and
        some of the more interesting information is extracted as separate tags.
    },
    TextInfo1 => { Binary => 1 },
    TextInfo2 => { Binary => 1 },
    # tags extracted from TextInfo blocks (ID's must end with ':')
    'Temp:' => {
        Name => 'CameraTemperature',
        RawConv => '$val =~ /^-?\d+/ ? $val : undef',
        PrintConv => '"$val C"',
    },
    'Temp:Clbt:' => { Name => 'BoardTemperature', PrintConv => '"$val C"' }, #(NC)
    'Capt:' => { Name => 'SensorTemperature', PrintConv => '"$val C"' }, #(NC)
    'VR Enable C:' => {
        Name => 'VibrationReduction',
        PrintConv => { 0 => 'Off', 1 => 'On' }, #(NC)
    },
    'FWVer:' => 'FirmwareVersion',
    'BC:' => {
        Name => 'Barcode',
        Condition => 'not $$self{VALUE}{Barcode}',
        ValueConv => '$val=~s/IP1.*//; $val',
    },
    'barcode:' => 'Barcode',
    'BarCode:' => {
        Name => 'Barcode',
        ValueConv => 'length($val) > 12 ? substr($val,0,12) : $val',
    },
    # 'EvA:' - exposure compensation * 10 (ref JR)
    # for documentation only -- this IFD is handled manually
    IFD => {
        Name => 'PIC_IFD',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::Main' },
    },
);

# tags found in DSC-F1 PMP header (ref 10)
%Image::ExifTool::Sony::PMP = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FIRST_ENTRY => 0,
    NOTES => q{
        These tags are written in the proprietary-format header of PMP images from
        the DSC-F1.
    },
    8 => { #PH
        Name => 'JpgFromRawStart',
        Format => 'int32u',
        Notes => q{
            OK, not really a RAW file, but this mechanism is used to allow extraction of
            the JPEG image from a PMP file
        },
    },
    12 => { Name => 'JpgFromRawLength', Format => 'int32u' },
    22 => { Name => 'SonyImageWidth',   Format => 'int16u' },
    24 => { Name => 'SonyImageHeight',  Format => 'int16u' },
    27 => {
        Name => 'Orientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 270 CW',#11
            2 => 'Rotate 180',
            3 => 'Rotate 90 CW',#11
        },
    },
    29 => {
        Name => 'ImageQuality',
        PrintConv => {
            8 => 'Snap Shot',
            23 => 'Standard',
            51 => 'Fine',
        },
    },
    # 40 => ImageWidth again (int16u)
    # 42 => ImageHeight again (int16u)
    52 => { Name => 'Comment',         Format => 'string[19]' },
    76 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int8u[6]',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            my @a = split ' ', $val;
            $a[0] += $a[0] < 70 ? 2000 : 1900;
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @a);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    84 => {
        Name => 'ModifyDate',
        Format => 'int8u[6]',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            my @a = split ' ', $val;
            $a[0] += $a[0] < 70 ? 2000 : 1900;
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @a);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    102 => {
        Name => 'ExposureTime',
        Format => 'int16s',
        RawConv => '$val <= 0 ? undef : $val',
        ValueConv => '2 ** (-$val / 100)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    106 => { # (NC -- not written by DSC-F1)
        Name => 'FNumber',
        Format => 'int16s',
        RawConv => '$val <= 0 ? undef : $val',
        ValueConv => '$val / 100', # (likely wrong)
    },
    108 => { # (NC -- not written by DSC-F1)
        Name => 'ExposureCompensation',
        Format => 'int16s',
        RawConv => '($val == -1 or $val == -32768) ? undef : $val',
        ValueConv => '$val / 100', # (probably wrong too)
    },
    112 => { # (NC -- not written by DSC-F1)
        Name => 'FocalLength',
        Format => 'int16s',
        Groups => { 2 => 'Camera' },
        RawConv => '$val <= 0 ? undef : $val',
        ValueConv => '$val / 100',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    118 => {
        Name => 'Flash',
        Groups => { 2 => 'Camera' },
        PrintConv => { 0 => 'No Flash', 1 => 'Fired' },
    },
);

# Composite Sony tags
%Image::ExifTool::Sony::Composite = (
    GROUPS => { 2 => 'Camera' },
    FocusDistance => {
        Require => {
            0 => 'Sony:FocusPosition',
            1 => 'FocalLength',
        },
        Notes => 'distance in metres = FocusPosition * FocalLength / 1000',
        ValueConv => '$val >= 128 ? "inf" : $val * $val[1] / 1000',
        PrintConv => '$val eq "inf" ? $val : "$val m"',
    },
    FocusDistance2 => {
        # For DSLR-A550 and newer, NEX/ILCE/SLT/ILCA (only A65V/A77V are missing ...):
        #     seen FocusPosition2 with values from 80 - 255 (and 21 for Touit 12mm...)
        # Formula from minolta.pm (WBInfoA100 - 0x49bb) gives mostly correct/acceptable distance indications.
            # (http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3688.0.html)
            # if this value is the 35mm equivalent magnification, then the formula could
            # be (1.5 * 2**($val/16-5)+1) * FocalLength, but this tends to underestimate
            # distance by about 18% (ref 20) (255=inf)
            # modified 16-10-2014 based on A99V measurements: use FocalLengthIn35mmFormat and leave out the "1.5*" factor.
        Require => {
            0 => 'Sony:FocusPosition2',
            1 => 'FocalLengthIn35mmFormat',
        },
        ValueConv => q{
            return undef unless $val;
            return 'inf' if $val >= 255;
            return (2**($val/16-5) + 1) * $val[1] / 1000;
        },
        PrintConv => '$val eq "inf" ? $val : sprintf("%.2f m",$val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Sony');

sub SortLensTypes
{
    return $a <=> $b unless $a =~ /\./ and $b =~ /\./;
    my @a = split /\./, $a;
    my @b = split /\./, $b;
    # must compare the decimal part separately to sort in proper order
    return $a[0] <=> $b[0] || $a[1] <=> $b[1];
}

# fill in Sony LensType lookup based on Minolta values
{
    my $minoltaTypes = \%Image::ExifTool::Minolta::minoltaLensTypes;
    %sonyLensTypes = %$minoltaTypes;
    my $other = $$minoltaTypes{OTHER};
    delete $$minoltaTypes{Notes};   # (temporarily)
    delete $$minoltaTypes{OTHER};   # (temporarily)
    my $id;
    # 5-digit lens ID's are missing the last digit (usually "1") in the metadata for
    # some Sony models, so generate corresponding 4-digit entries for these cameras
    foreach $id (sort SortLensTypes keys %$minoltaTypes) {
        next if $id < 10000;
        my $sid = int($id/10);
        my $i;
        my $lens = $$minoltaTypes{$id};
        if ($sonyLensTypes{$sid}) {
            # put lens name with "or" first in list
            if ($lens =~ / or /) {
                my $tmp = $sonyLensTypes{$sid};
                $sonyLensTypes{$sid} = $lens;
                $lens = $tmp;
            }
            for (;;) {
                $i = ($i || 0) + 1;
                $sid = int($id/10) . ".$i";
                last unless $sonyLensTypes{$sid};
            }
        }
        $sonyLensTypes{$sid} = $lens;
    }
    $$minoltaTypes{Notes} = $sonyLensTypes{Notes}; # (restore original Notes)
    $$minoltaTypes{OTHER} = $other;
}

#------------------------------------------------------------------------------
# Process "SONY PIC\0" maker notes (DSC-H200/J10/W370/W510, MHS-TS20, ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1
sub ProcessSonyPIC($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart} || 0;
    my $len = $$dirInfo{DirLen} || (length($$dataPt) - $start);
    my $data = substr($$dataPt, $start, $len);

    # H200 panorama images have an IFD at offset 12 (non-panoramas have 0's here)
    # - assume other images could too, but do a bit of validation to check
    # - MHS-TS20 images have some other data here
    if ($len >= 26) {
        my $count = Get16u($dataPt, $start + 12);
        if ($count > 256) {
            SwapByteOrder();
            $count = Get16u($dataPt, $start + 12);
        }
        if ($count and $count < 256) {
            my $format = Get16u($dataPt, $start + 16);
            if ($format >= 1 and $format <= 10) {
                $$dirInfo{DirStart} = $start + 12;
                $$dirInfo{DirLen} = $len - 12;
                my $sonyTable = GetTagTable('Image::ExifTool::Sony::Main');
                Image::ExifTool::Exif::ProcessExif($et, $dirInfo, $sonyTable);
            }
        }
    }
    # Do a brute force search for text data:
    # For the DSC-J10/W370/W510 the first text block is at offset 0x1ec and
    # starts with "BarCode:".  For the H200 it is at 0x1f0 and starts with "BC:".
    # For the TS20 it is at 0x5b and starts with "V400 AELOG\nbarcode:".
    # The second text block starts with "AFLOG" (Auto-Focus log) and is at
    # 0x600 for all models, except for the TS20 it is at 0x45b.
    my $i = 0;
    while ($data =~ /(\w[\x09\x0a\x0d\x20-\x7e]+)/sg) {
        next unless length $1 > 32;
        my ($tag, $val) = ('TextInfo' . (++$i), $1);
        $$tagTablePtr{$tag} or AddTagToTable($tagTablePtr, $tag, { Name => $tag, Binary => 1 });
        $et->HandleTag($tagTablePtr, $tag, $val);
        # extract interesting tags separately (might want to speed this up)
        foreach $tag (sort { lc $a cmp lc $b } keys %$tagTablePtr) {
            next unless $tag =~ /:$/ and $val =~ /\b$tag\s*([^\s;,:]+)/;
            $et->HandleTag($tagTablePtr, $tag, $1);
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Make TIFF header for raw data
# Inputs: 0) width, 1) height, 2) num colour components, 3) bits, 4) resolution
# Returns: TIFF header
# Notes: Multi-byte data must be little-endian
sub MakeTiffHeader($$$$;$)
{
    my ($w, $h, $cols, $bits, $res) = @_;
    $res or $res = 72;
    my $saveOrder = GetByteOrder();
    SetByteOrder('II');
    my $hdr =
    "\x49\x49\x2a\0\x08\0\0\0\x0e\0" .          # 0x00 14 menu entries:
    "\xfe\x00\x04\0\x01\0\0\0\x00\0\0\0" .      # 0x0a SubfileType = 0
    "\x00\x01\x04\0\x01\0\0\0" . Set32u($w) .   # 0x16 ImageWidth
    "\x01\x01\x04\0\x01\0\0\0" . Set32u($h) .   # 0x22 ImageHeight
    "\x02\x01\x03\0" . Set32u($cols) .          # 0x2e BitsPerSample
    Set32u($cols == 1 ? $bits : 0xb6) .
    "\x03\x01\x03\0\x01\0\0\0\x01\0\0\0" .      # 0x3a Compression = 1
    "\x06\x01\x03\0\x01\0\0\0" .                # 0x46 PhotometricInterpretation
    Set32u($cols == 1 ? 1 : 2) .
    "\x11\x01\x04\0\x01\0\0\0\xcc\0\0\0" .      # 0x52 StripOffsets = 0xcc
    "\x15\x01\x03\0\x01\0\0\0" . Set32u($cols) .# 0x5e SamplesPerPixel
    "\x16\x01\x04\0\x01\0\0\0" . Set32u($h) .   # 0x6a RowsPerStrip
    "\x17\x01\x04\0\x01\0\0\0" .                # 0x76 StripByteCounts
    Set32u($w * $h * $cols * int(($bits+7)/8)) .
    "\x1a\x01\x05\0\x01\0\0\0\xbc\0\0\0" .      # 0x82 XResolution
    "\x1b\x01\x05\0\x01\0\0\0\xc4\0\0\0" .      # 0x8e YResolution
    "\x1c\x01\x03\0\x01\0\0\0\x01\0\0\0" .      # 0x9a PlanarConfiguration = 1
    "\x28\x01\x03\0\x01\0\0\0\x02\0\0\0" .      # 0xa6 ResolutionUnit = 2
    "\0\0\0\0" .                                # 0xb2 (no IFD1)
    (Set16u($bits) x 3) .                       # 0xb6 BitsPerSample value
    Set32u($res) . "\x01\0\0\0" .               # 0xbc XResolution = 72
    Set32u($res) . "\x01\0\0\0";                # 0xc4 YResolution = 72
    SetByteOrder($saveOrder);                   # 0xcc (data goes here)
    return $hdr;
}

#------------------------------------------------------------------------------
# LensSpec value conversions
# Inputs: 0) value
# Returns: converted value
# Notes: unpacks in format compatible with LensInfo, with extra flags bytes at start and end
sub ConvLensSpec($)
{
    my $val = shift;
    return \$val unless length($val) == 8;
    my @a = unpack("H2H4H4H2H2H2",$val);
    $a[1] += 0;  $a[2] += 0;    # remove leading zeros from focal lengths
    $a[3] /= 10; $a[4] /= 10;   # divide f-numbers by 10
    return join ' ', @a;
}
sub ConvInvLensSpec($)
{
    my $val = shift;
    my @a=split(" ", $val);
    return $val unless @a == 6;
    $a[3] *= 10; $a[4] *= 10;   # f-numbers are multiplied by 10
    $_ = hex foreach @a;        # convert from hex
    return pack 'CnnCCC', @a;
}

#------------------------------------------------------------------------------
# Print Sony LensSpec value
# Inputs: 0) LensSpec numerical value
# Returns: converted LensSpec string (eg. "DT 18-55mm F3.5-5.6 SAM")
# Refs: http://equational.org/importphotos/alphalensinfo.html
#       http://www.dyxum.com/dforum/the-lens-information-different-from-lensid_topic37682.html
my @lensFeatures = (
    # lens features in the order they are added to the LensSpec string
    # (high byte of Mask/Bits represents byte 0 of LensSpec, low byte is byte 7)
    #  Mask   {  Bits     Name    Bits     Name  } Prefix flag
    # ------    ------    -----  ------    -----   -----------
    [ 0x4000, { 0x4000 => 'PZ'                   }, 1 ],
    [ 0x0300, { 0x0100 => 'DT',  0x0200 => 'FE', 0x0300 => 'E'   }, 1 ], # (will come before preceding prefix), FE added (ref JR)
    [ 0x00e0, { 0x0020 => 'STF', 0x0040 => 'Reflex', 0x0060 => 'Macro', 0x0080 => 'Fisheye' } ],
    [ 0x000c, { 0x0004 => 'ZA',  0x0008 => 'G'   } ],
    [ 0x0003, { 0x0001 => 'SSM', 0x0002 => 'SAM' } ],
    [ 0x8000, { 0x8000 => 'OSS' } ],
    [ 0x2000, { 0x2000 => 'LE' } ], #JR
    [ 0x0800, { 0x0800 => 'II' } ], #JR
);
sub PrintLensSpec($)
{
    my $val = shift;
    my ($rtnVal, $feature, $f1, $sf, $lf, $sa, $la, $f2);
    # 0=flags1, 1=short focal, 2=long focal, 3=max aperture at short focal,
    # 4=max aperture at long focal, 5=flags2
    my @a = split ' ', $val;
    if (@a == 2) {  # LensSpecFeatures patch
        ($f1, $f2) = @a;
        $rtnVal = '';
    } elsif (@a >= 6) {
        ($f1, $sf, $lf, $sa, $la, $f2) = @a;
        # crude validation of focal length and aperture values
        if ($sf != 0 and $sa != 0 and ($lf == 0 or $lf >= $sf) and ($la == 0 or $la >= $sa)) {
            # use focal and aperture range if this is a zoom lens
            $sf .= '-' . $lf if $lf != $sf and $lf != 0;
            $sa .= '-' . $la if $sa != $la and $la != 0;
            $rtnVal = "${sf}mm F$sa";     # heart of LensSpec is a LensInfo string
        }
    }
    if (defined $rtnVal) {
        # loop through available lens features
        my $flags = hex($f1 . $f2);
        foreach $feature (@lensFeatures) {
            my $bits = $$feature[0] & $flags;
            next unless $bits or $$feature[1]{$bits};
            # add feature name as a prefix or suffix to the LensSpec
            my $str = $$feature[1]{$bits} || sprintf('Unknown(%.4x)',$bits);
            $rtnVal = $rtnVal ? ($$feature[2] ? "$str $rtnVal" : "$rtnVal $str") : $str;
        }
    } else {
        $rtnVal = "Unknown ($val)";
    }
    return $rtnVal;
}
# inverse conversion
sub PrintInvLensSpec($;$$)
{
    my ($val, $self, $features) = @_;
    return $1 if $val =~ /Unknown \((.*)\)/i;
    my ($sf, $lf, $sa, $la) = Image::ExifTool::Exif::GetLensInfo($val);
    my $str;
    if ($features) {
        $str = '';
    } elsif ($sf) {
        # fixed focal length and aperture have zero for 2nd number
        $lf = 0 if $lf == $sf;
        $la = 0 if $la == $sa;
        $str = " $sf $lf $sa $la";
    } else {
        return undef;
    }
    my $flags = 0;
    my ($feature, $bits);
    foreach $feature (@lensFeatures) {
        foreach $bits (keys %{$$feature[1]}) {
            # set corresponding flag bits for each feature name found
            my $name = $$feature[1]{$bits};
            $val =~ /\b$name\b/i and $flags |= $bits;
        }
    }
    return sprintf "%.2x$str %.2x", $flags>>8, $flags&0xff;
}

#------------------------------------------------------------------------------
# Read/Write MoreInfo information (tag 0x0020, count 20480)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success when reading, or new directory when writing (IsWriting set)
sub ProcessMoreInfo($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to write routine
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt);
    my $isWriting = $$dirInfo{IsWriting};
    my $rtnVal = $isWriting ? undef : 0;
    return $rtnVal if $dirLen < 4;

    my $num = Get16u($dataPt, $start);      # number of entries
    my $len = Get16u($dataPt, $start + 2);  # total data length

    if ($dirLen < 4 + $num * 4) {
        $et->Warn('Truncated MoreInfo data', 1);
        return $rtnVal;
    }
    if ($num > 50) {
        $et->Warn('Possibly corrupted MoreInfo data', 1);
        return $rtnVal;
    }

    $et->VerboseDir('MoreInfo', $num, $len) unless $isWriting;

    if ($len > $dirLen) {
        $et->Warn('MoreInfo data length too large', 1);
        $len = $dirLen;
    }
    # loop through the MoreInfo index section to get the block offsets and tag ID's
    # (in case they are out of order, even though this may never happen)
    my ($i, @offset, @tagID, %blockSize);
    for ($i=0; $i<$num; ++$i) {
        my $entry = $start + 4 + $i * 4;
        push @tagID, Get16u($dataPt, $entry);
        push @offset, Get16u($dataPt, $entry + 2);
        if ($offset[-1] > $len and $offset[-1] <= $dirLen) {
            $et->Warn('MoreInfo data length too small', 1);
            $len = $dirLen;
        }
    }
    # generate a lookup table of block sizes
    my @sorted = sort { $a <=> $b } @offset;
    push @sorted, 0xffff;   # (simplifies logic in loop below)
    for ($i=0; $i<$num; ++$i) {
        my $offset = $sorted[$i];
        my $size = $sorted[$i+1] - $offset;
        # note that block size will be negative for blocks with starting
        # offsets greater than $dirLen, but we will ignore these below
        $size = $len - $offset if $size > $len - $offset;
        # (if blockSize is already defined for this offset, then there
        #  are 2 blocks with the same starting offset and the existing
        #  size must be zero.  Since we can't know which block is
        #  actually non-zero size, the reasonable thing to do is
        #  assume that both have a size of zero)
        $blockSize{$offset} = $size unless defined $blockSize{$offset};
    }
    # initialize successful return value
    $rtnVal = $isWriting ? substr($$dataPt, $start, $dirLen) : 1;
    # now process each block
    my $unknown = $$et{OPTIONS}{Unknown};
    for ($i=0; $i<$num; ++$i) {
        next if $offset[$i] > $dirLen;  # ignore bad offsets
        my $tag = $tagID[$i];
        if ($isWriting) {
            # write new tags
            my $tagInfo = $$tagTablePtr{$tag};
            next unless ref $tagInfo eq 'HASH' and $$tagInfo{SubDirectory};
            my $offset = $offset[$i];
            my $size = $blockSize{$offset};
            next unless $size;  # ignore zero-length blocks
            my %dirInfo = (
                DirName  => $$tagInfo{Name},
                Parent   => $$dirInfo{DirName},
                DataPt   => \$rtnVal,
                DirStart => $offset,
                DirLen   => $size,
            );
            my $subTable = GetTagTable($$tagInfo{SubDirectory}{TagTable});
            my $val = $et->WriteDirectory(\%dirInfo, $subTable);
            # update this block in the returned MoreInfo data
            substr($rtnVal, $offset, $size) = $val if defined $val;
            next;
        }
        # generate binary tables for unknown tags if -U option used
        if (not defined $$tagTablePtr{$tag} and $unknown > 1) {
            my $name = sprintf('MoreInfo%.4x', $tag);
            my $table = "Image::ExifTool::Sony::$name";
            no strict 'refs';
            %$table = (
                PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
                FIRST_ENTRY => 0,
                GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
            );
            use strict 'refs';
            my %tagInfo = (
                Name => $name,
                SubDirectory => { TagTable => $table },
            );
            AddTagToTable($tagTablePtr, $tag, \%tagInfo);
        }
        $et->HandleTag($tagTablePtr, $tag, undef,
            Index   => $i,
            DataPt  => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Start   => $start + $offset[$i],
            Size    => $blockSize{$offset[$i]},
        );
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Read Sony DSC-F1 PMP file
# Inputs: 0) ExifTool object ref, 1) dirInfo ref
# Returns: 1 on success when reading, 0 if this isn't a valid PMP file
sub ProcessPMP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    $raf->Read($buff, 128) == 128 or return 0;
    # validate header length (124 bytes)
    $buff =~ /^.{8}\0{3}\x7c.{112}\xff\xd8\xff\xdb$/s or return 0;
    $et->SetFileType();
    SetByteOrder('MM');
    $et->FoundTag(Make => 'Sony');
    $et->FoundTag(Model => 'DSC-F1');
    # extract information from 124-byte header
    my $tagTablePtr = GetTagTable('Image::ExifTool::Sony::PMP');
    my %dirInfo = ( DataPt => \$buff, DirName => 'PMP' );
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
    # process JPEG image
    $raf->Seek(124, 0);
    $$dirInfo{Base} = 124;
    $et->ProcessJPEG($dirInfo);
    return 1;
}

#------------------------------------------------------------------------------
# Set the ARW file type and decide between SubIFD and A100DataOffset
# Inputs: 0) ExifTool object ref, 1) reference to tag 0x14a raw data
# Returns: true if tag 0x14a is a SubIFD, false otherwise
sub SetARW($$)
{
    my ($et, $valPt) = @_;

    # assume ARW for now -- SR2's get identified when FileFormat is parsed
    $et->OverrideFileType($$et{TIFF_TYPE} = 'ARW');

    # this should always be a SubIFD for models other than the A100
    return 1 unless $$et{Model} eq 'DSLR-A100' and length $$valPt == 4;

    # for the A100, IFD0 tag 0x14a is either a pointer to the raw data if this is
    # an original image, or a SubIFD offset if the image was edited by Sony IDC,
    # so assume it points to the raw data if it isn't a valid IFD (this assumption
    # will be checked later when we try to parse the SR2Private directory)
    my %subdir = (
        DirStart => Get32u($valPt, 0),
        Base     => 0,
        RAF      => $$et{RAF},
        AllowOutOfOrderTags => 1, # doh!
    );
    return Image::ExifTool::Exif::ValidateIFD(\%subdir);
}

#------------------------------------------------------------------------------
# Finish writing ARW image, patching necessary Sony quirks, etc
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) EXIF data ref, 3) image data reference
# Returns: undef on success, error string otherwise
# Notes: (it turns that all of this is for the A100 only)
sub FinishARW($$$$)
{
    my ($et, $dirInfo, $dataPt, $imageData) = @_;

    # pre-scan IFD0 to get IFD entry offsets for each tag
    my $dataLen = length $$dataPt;
    return 'Truncated IFD0' if $dataLen < 2;
    my $n = Get16u($dataPt, 0);
    return 'Truncated IFD0' if $dataLen < 2 + 12 * $n;
    my ($i, %entry, $dataBlock, $pad, $dataOffset);
    for ($i=0; $i<$n; ++$i) {
        my $entry = 2 + $i * 12;
        $entry{Get16u($dataPt, $entry)} = $entry;
    }
    # fix up SR2Private offset and A100DataOffset (A100 only)
    if ($entry{0xc634} and $$et{MRWDirData}) {
        return 'Unexpected MRW block' unless $$et{Model} eq 'DSLR-A100';
        return 'Missing A100DataOffset' unless $entry{0x14a} and $$et{A100DataOffset};
        # account for total length of image data
        my $totalLen = 8 + $dataLen;
        if (ref $imageData) {
            foreach $dataBlock (@$imageData) {
                my ($pos, $size, $pad) = @$dataBlock;
                $totalLen += $size + $pad;
            }
        }
        # align MRW block on an even 4-byte boundary
        my $remain = $totalLen & 0x03;
        $pad = 4 - $remain and $totalLen += $pad if $remain;
        # set offset for the MRW directory data
        Set32u($totalLen, $dataPt, $entry{0xc634} + 8);
        # also pad MRWDirData data to an even 4 bytes (just to be safe)
        $remain = length($$et{MRWDirData}) & 0x03;
        $$et{MRWDirData} .= "\0" x (4 - $remain) if $remain;
        $totalLen += length $$et{MRWDirData};
        # fix up A100DataOffset
        $dataOffset = $$et{A100DataOffset};
        Set32u($totalLen, $dataPt, $entry{0x14a} + 8);
    }
    # patch double-referenced and incorrectly-sized A100 PreviewImage
    if ($entry{0x201} and $$et{A100PreviewStart} and
        $entry{0x202} and $$et{A100PreviewLength})
    {
        Set32u($$et{A100PreviewStart}, $dataPt, $entry{0x201} + 8);
        Set32u($$et{A100PreviewLength}, $dataPt, $entry{0x202} + 8);
    }
    # write TIFF IFD structure
    my $outfile = $$dirInfo{OutFile};
    my $header = GetByteOrder() . Set16u(0x2a) . Set32u(8);
    Write($outfile, $header, $$dataPt) or return 'Error writing';
    # copy over image data
    if (ref $imageData) {
        $et->CopyImageData($imageData, $outfile) or return 'Error copying image data';
    }
    # write MRW data if necessary
    if ($$et{MRWDirData}) {
        Write($outfile, "\0" x $pad) if $pad;   # write padding if necessary
        Write($outfile, $$et{MRWDirData});
        delete $$et{MRWDirData};
        # set TIFF_END to copy over the MRW image data
        $$et{TIFF_END} = $dataOffset if $dataOffset;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Decrypt/Encrypt Sony data (ref 1) (reversible encryption)
# Inputs: 0) data reference, 1) start offset, 2) data length, 3) decryption key
# Returns: nothing (original data buffer is updated with decrypted data)
# Notes: data length should be a multiple of 4
sub Decrypt($$$$)
{
    my ($dataPt, $start, $len, $key) = @_;
    my ($i, $j, @pad);
    my $words = int ($len / 4);

    for ($i=0; $i<4; ++$i) {
        my $lo = ($key & 0xffff) * 0x0edd + 1;
        my $hi = ($key >> 16) * 0x0edd + ($key & 0xffff) * 0x02e9 + ($lo >> 16);
        $pad[$i] = $key = (($hi & 0xffff) << 16) + ($lo & 0xffff);
    }
    $pad[3] = ($pad[3] << 1 | ($pad[0]^$pad[2]) >> 31) & 0xffffffff;
    for ($i=4; $i<0x7f; ++$i) {
        $pad[$i] = (($pad[$i-4]^$pad[$i-2]) << 1 |
                    ($pad[$i-3]^$pad[$i-1]) >> 31) & 0xffffffff;
    }
    my @data = unpack("x$start N$words", $$dataPt);
    for ($i=0x7f,$j=0; $j<$words; ++$i,++$j) {
        $data[$j] ^= $pad[$i & 0x7f] = $pad[($i+1) & 0x7f] ^ $pad[($i+65) & 0x7f];
    }
    substr($$dataPt, $start, $words*4) = pack('N*', @data);
}

#------------------------------------------------------------------------------
# Decipher/encipher Sony tag 0x94xx data (ref PH)
# Inputs: 0) data reference, 1) true to encipher the data
sub Decipher($;$)
{
    my ($dataPt, $encipher) = @_;
    # This is a simple substitution cipher, so use a hardcoded translation table for speed.
    # The formula is: $c = ($b*$b*$b) % 249, where $c is the enciphered data byte
    # (note that bytes with values 249-255 are not translated, and 0-1, 82-84,
    #  165-167 and 248 have the same enciphered value)
    if ($encipher) {    # encipher
        $$dataPt =~ tr/\x02-\xf7/\x08\x1b\x40\x7d\xd8\x5e\x0e\xe7\x04V\xea\xcd\x05\x8ap\xb6i\x88\x200\xbe\xd7\x81\xbb\x92\x0c\x28\xecl\xa0\x95Q\xd3\x2f\x5dj\x5c9\x07\xc5\x87L\x1a\xf0\xe2\xef\x24y\x02\xb7\xac\xe0\x60\x2bG\xba\x91\xcbu\x8e\x233\xc4\xe3\x96\xdc\xc2N\x7fb\xf6OeE\xeet\xcf\x138KRST\x5bn\x93\xd02\xb1aAW\xa9D\x27X\xdd\xc3\x10\xbc\xdbs\x83\x181\xd4\x15\xe5_\x7bF\xbf\xf3\xe8\xa4\x2d\x82\xb0\xbd\xaf\x8cZ\x1f\xda\x9fmJ\x3cIw\xccU\x11\x06\x3a\xb3\x7e\x9a\x14\xe4\x25\xc8\xe1v\x86\x1e\x3d\xe96\x1c\xa1\xd2\xb5P\xa2\xb8\x98H\xc7\x29f\x8b\x9e\xa5\xa6\xa7\xae\xc1\xe6\x2a\x85\x0b\xb4\x94\xaa\x03\x97z\xab7\x1dc\x165\xc6\xd6k\x84\x2eh\x3f\xb2\xce\x99\x19MB\xf7\x80\xd5\x0a\x17\x09\xdf\xadr4\xf2\xc0\x9d\x8f\x9c\xca\x26\xa8dY\x8d\x0d\xd1\xedg\x3ex\x22\x3b\xc9\xd9q\x90C\x89o\xf4\x2c\x0f\xa3\xf5\x12\xeb\x9b\x21\x7c\xb9\xde\xf1/;
    } else {            # decipher
        $$dataPt =~ tr/\x08\x1b\x40\x7d\xd8\x5e\x0e\xe7\x04V\xea\xcd\x05\x8ap\xb6i\x88\x200\xbe\xd7\x81\xbb\x92\x0c\x28\xecl\xa0\x95Q\xd3\x2f\x5dj\x5c9\x07\xc5\x87L\x1a\xf0\xe2\xef\x24y\x02\xb7\xac\xe0\x60\x2bG\xba\x91\xcbu\x8e\x233\xc4\xe3\x96\xdc\xc2N\x7fb\xf6OeE\xeet\xcf\x138KRST\x5bn\x93\xd02\xb1aAW\xa9D\x27X\xdd\xc3\x10\xbc\xdbs\x83\x181\xd4\x15\xe5_\x7bF\xbf\xf3\xe8\xa4\x2d\x82\xb0\xbd\xaf\x8cZ\x1f\xda\x9fmJ\x3cIw\xccU\x11\x06\x3a\xb3\x7e\x9a\x14\xe4\x25\xc8\xe1v\x86\x1e\x3d\xe96\x1c\xa1\xd2\xb5P\xa2\xb8\x98H\xc7\x29f\x8b\x9e\xa5\xa6\xa7\xae\xc1\xe6\x2a\x85\x0b\xb4\x94\xaa\x03\x97z\xab7\x1dc\x165\xc6\xd6k\x84\x2eh\x3f\xb2\xce\x99\x19MB\xf7\x80\xd5\x0a\x17\x09\xdf\xadr4\xf2\xc0\x9d\x8f\x9c\xca\x26\xa8dY\x8d\x0d\xd1\xedg\x3ex\x22\x3b\xc9\xd9q\x90C\x89o\xf4\x2c\x0f\xa3\xf5\x12\xeb\x9b\x21\x7c\xb9\xde\xf1/\x02-\xf7/;
    }
}

#------------------------------------------------------------------------------
# Process Sony 0x94xx cipherdata directory
# Inputs: 0) ExifTool object ref, 1) directory information ref, 2) tag table ref
# Returns: 1 on success
# Notes:
# 1) dirInfo may contain VarFormatData (reference to empty list) to return
#    details about any variable-length-format tags in the table (used when writing)
# 2) A bug in ExifTool 9.04-9.10 could have double-enciphered these blocks
sub ProcessEnciphered($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    my $data = substr($$dataPt, $dirStart, $dirLen);
    my %dirInfo = (
        %$dirInfo,
        DataPt => \$data,
        DataPos => $$dirInfo{DataPos} + $dirStart,
        DirStart => 0,
    );
    Decipher(\$data);
    if ($$et{DoubleCipher}) {
        Decipher(\$data);
        $et->WarnOnce('Some Sony metadata is double-enciphered. Write any tag to fix',1);
    }
    if ($et->Options('Verbose') > 2) {
        my $tagInfo = $$dirInfo{TagInfo} || { Name => 'data' };
        my $str = $$et{DoubleCipher} ? 'ouble-d' : '';
        $et->VerboseDir("D${str}eciphered $$tagInfo{Name}");
        $et->VerboseDump(\$data,
            Prefix  => $$et{INDENT} . '  ',
            DataPos => $$dirInfo{DirStart} + $$dirInfo{DataPos} + ($$dirInfo{Base} || 0),
        );
    }
    return $et->ProcessBinaryData(\%dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Write Sony 0x94xx cipherdata directory
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: cipherdata block or undefined on error
sub WriteEnciphered($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    my $data = substr($$dataPt, $dirStart, $dirLen);
    my $changed = $$et{CHANGED};
    Decipher(\$data);
    # fix double-enciphered data (due to bug in ExifTool 9.04-9.10)
    if ($$et{DoubleCipher}) {
        Decipher(\$data);
        ++$$et{CHANGED};
        $et->WarnOnce('Fixed double-enciphered Sony metadata',1);
    }
    my %dirInfo = (
        %$dirInfo,
        DataPt => \$data,
        DataPos => $$dirInfo{DataPos} + $dirStart,
        DirStart => 0,
    );
    $data = $et->WriteBinaryData(\%dirInfo, $tagTablePtr);
    if ($changed == $$et{CHANGED}) {
        # nothing changed, so recover original data
        $data = substr($$dataPt, $dirStart, $dirLen);
    } elsif (defined $data) {
        Decipher(\$data,1);     # re-encipher
    }
    return $data;
}

#------------------------------------------------------------------------------
# Process SRF maker notes
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessSRF($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart};
    my $verbose = $et->Options('Verbose');

    # process IFD chain
    my ($ifd, $success);
    for ($ifd=0; ; ) {
        # switch tag table for SRF2-5 and SRF6
        if ($ifd == 2) {
            $tagTablePtr = GetTagTable('Image::ExifTool::Sony::SRF2');
        } elsif ($ifd == 6) {
            # SRF6 uses standard EXIF tags
            $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
        }
        my $srf = $$dirInfo{DirName} = "SRF$ifd";
        $$et{SET_GROUP1} = $srf;
        $success = Image::ExifTool::Exif::ProcessExif($et, $dirInfo, $tagTablePtr);
        delete $$et{SET_GROUP1};
        last unless $success;
#
# get pointer to next IFD
#
        my $count = Get16u($dataPt, $$dirInfo{DirStart});
        my $dirEnd = $$dirInfo{DirStart} + 2 + $count * 12;
        last if $dirEnd + 4 > length($$dataPt);
        my $nextIFD = Get32u($dataPt, $dirEnd);
        last unless $nextIFD;
        $nextIFD -= $$dirInfo{DataPos}; # adjust for position of makernotes data
        $$dirInfo{DirStart} = $nextIFD;
#
# decrypt next IFD data if necessary
#
        ++$ifd;
        my ($key, $len);
        if ($ifd == 1) {
            # get the key to decrypt IFD1
            my $cp = $start + 0x8ddc;    # why?
            my $ip = $cp + 4 * unpack("x$cp C", $$dataPt);
            $key = unpack("x$ip N", $$dataPt);
            $len = $cp + $nextIFD;  # decrypt up to $cp
        } elsif ($ifd == 2) {
            # get the key to decrypt IFD2
            $key = $$et{SRF2Key};
            $len = length($$dataPt) - $nextIFD; # decrypt rest of maker notes
        } else {
            next;   # no decryption needed
        }
        # decrypt data
        Decrypt($dataPt, $nextIFD, $len, $key) if defined $key;
        next unless $verbose > 2;
        # display decrypted data in verbose mode
        $et->VerboseDir("Decrypted SRF$ifd", 0, $nextIFD + $len);
        $et->VerboseDump($dataPt,
            Prefix => "$$et{INDENT}  ",
            Start => $nextIFD,
            DataPos => $$dirInfo{DataPos},
        );
    }
}

#------------------------------------------------------------------------------
# Write SR2 data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success when reading, or SR2 directory or undef when writing
sub WriteSR2($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;      # allow dummy access
    my $buff = '';
    $$dirInfo{OutFile} = \$buff;
    return ProcessSR2($et, $dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Read/Write SR2 IFD and its encrypted subdirectories
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success when reading, or SR2 directory or undef when writing
sub ProcessSR2($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dataLen = $$dirInfo{DataLen} || length $$dataPt;
    my $base = $$dirInfo{Base} || 0;
    my $outfile = $$dirInfo{OutFile};

    # clear SR2 member variables to be safe
    delete $$et{SR2SubIFDOffset};
    delete $$et{SR2SubIFDLength};
    delete $$et{SR2SubIFDKey};

    # make sure we have the first 4 bytes available to test directory type
    my $buff;
    if ($dataLen < 4 and $raf) {
        my $pos = $dataPos + ($$dirInfo{DirStart}||0) + $base;
        if ($raf->Seek($pos, 0) and $raf->Read($buff, 4) == 4) {
            $dataPt = \$buff;
            undef $$dirInfo{DataPt};    # must load data from file
            $raf->Seek($pos, 0);
        }
    }
    # this may either be a normal IFD, or a MRW data block
    # (only original ARW images from the A100 use the MRW block)
    my $dataOffset;
    if ($dataPt and $$dataPt =~ /^\0MR[IM]/) {
        my ($err, $srfPos, $srfLen, $dataOffset);
        $dataOffset = $$et{A100DataOffset};
        if ($dataOffset) {
            # save information about the RAW data trailer so it will be preserved
            $$et{KnownTrailer} = { Name => 'A100 RAW Data', Start => $dataOffset };
        } else {
            $err = 'A100DataOffset tag is missing from A100 ARW image';
        }
        $raf or $err = 'Unrecognized SR2 structure';
        unless ($err) {
            $srfPos = $raf->Tell();
            $srfLen = $dataOffset - $srfPos;
            unless ($srfLen > 0 and $raf->Read($buff, $srfLen) == $srfLen) {
                $err = 'Error reading MRW directory';
            }
        }
        if ($err) {
            $outfile and $et->Error($err), return undef;
            $et->Warn($err);
            return 0;
        }
        my %dirInfo = ( DataPt => \$buff );
        require Image::ExifTool::MinoltaRaw;
        if ($outfile) {
            # save MRW data to be written last
            $$et{MRWDirData} = Image::ExifTool::MinoltaRaw::WriteMRW($et, \%dirInfo);
            return $$et{MRWDirData} ? "\0\0\0\0\0\0" : undef;
        } else {
            if (not $outfile and $$et{HTML_DUMP}) {
                $et->HDump($srfPos, $srfLen, '[A100 SRF Data]');
            }
            return Image::ExifTool::MinoltaRaw::ProcessMRW($et, \%dirInfo);
        }
    } elsif ($$et{A100DataOffset}) {
        my $err = 'Unexpected A100DataOffset tag';
        $outfile and $et->Error($err), return undef;
        $et->Warn($err);
        return 0;
    }
    my $verbose = $et->Options('Verbose');
    my $result;
    if ($outfile) {
        $result = Image::ExifTool::Exif::WriteExif($et, $dirInfo, $tagTablePtr);
        return undef unless $result;
        $$outfile .= $result;

    } else {
        $result = Image::ExifTool::Exif::ProcessExif($et, $dirInfo, $tagTablePtr);
    }
    return $result unless $result and $$et{SR2SubIFDOffset};
    # only take first offset value if more than one!
    my @offsets = split ' ', $$et{SR2SubIFDOffset};
    my $offset = shift @offsets;
    my $length = $$et{SR2SubIFDLength};
    my $key = $$et{SR2SubIFDKey};
    my @subifdPos;
    if ($offset and $length and defined $key) {
        my $buff;
        # read encrypted SR2SubIFD from file
        if (($raf and $raf->Seek($offset+$base, 0) and
                $raf->Read($buff, $length) == $length) or
            # or read from data (when processing Adobe DNGPrivateData)
            ($offset - $dataPos >= 0 and $offset - $dataPos + $length < $dataLen and
                ($buff = substr($$dataPt, $offset - $dataPos, $length))))
        {
            Decrypt(\$buff, 0, $length, $key);
            # display decrypted data in verbose mode
            if ($verbose > 2 and not $outfile) {
                $et->VerboseDir("Decrypted SR2SubIFD", 0, $length);
                $et->VerboseDump(\$buff, Addr => $offset + $base);
            }
            my $num = '';
            my $dPos = $offset;
            for (;;) {
                my %dirInfo = (
                    Base => $base,
                    DataPt => \$buff,
                    DataLen => length $buff,
                    DirStart => $offset - $dPos,
                    DirName => "SR2SubIFD$num",
                    DataPos => $dPos,
                );
                my $subTable = GetTagTable('Image::ExifTool::Sony::SR2SubIFD');
                if ($outfile) {
                    my $fixup = new Image::ExifTool::Fixup;
                    $dirInfo{Fixup} = $fixup;
                    $result = $et->WriteDirectory(\%dirInfo, $subTable);
                    return undef unless $result;
                    # save position of this SubIFD
                    push @subifdPos, length($$outfile);
                    # add this directory to the returned data
                    $$fixup{Start} += length($$outfile);
                    $$outfile .= $result;
                    $$dirInfo{Fixup}->AddFixup($fixup);
                } else {
                    $result = $et->ProcessDirectory(\%dirInfo, $subTable);
                }
                last unless @offsets;
                $offset = shift @offsets;
                $num = ($num || 1) + 1;
            }

        } else {
            $et->Warn('Error reading SR2 data');
        }
    }
    if ($outfile and @subifdPos) {
        # the SR2SubIFD must be padded to a multiple of 4 bytes for the encryption
        my $sr2Len = length($$outfile) - $subifdPos[0];
        if ($sr2Len & 0x03) {
            my $pad = 4 - ($sr2Len & 0x03);
            $sr2Len += $pad;
            $$outfile .= ' ' x $pad;
        }
        # save the new SR2SubIFD Length and Key to be used later for encryption
        $$et{SR2SubIFDLength} = $sr2Len;
        my $newKey = $$et{VALUE}{SR2SubIFDKey};
        $$et{SR2SubIFDKey} = $newKey if defined $newKey;
        # update SubIFD pointers manually and add to fixup, and set SR2SubIFDLength
        my $n = Get16u($outfile, 0);
        my ($i, %found);
        for ($i=0; $i<$n; ++$i) {
            my $entry = 2 + 12 * $i;
            my $tagID = Get16u($outfile, $entry);
            # only interested in SR2SubIFDOffset (0x7200) and SR2SubIFDLength (0x7201)
            next unless $tagID == 0x7200 or $tagID == 0x7201;
            $found{$tagID} = 1;
            my $fmt = Get16u($outfile, $entry + 2);
            if ($fmt != 0x04) { # must be int32u
                $et->Error("Unexpected format ($fmt) for SR2SubIFD tag");
                return undef;
            }
            if ($tagID == 0x7201) { # SR2SubIFDLength
                Set32u($sr2Len, $outfile, $entry + 8);
                next;
            }
            my $tag = 'SR2SubIFDOffset';
            my $valuePtr = @subifdPos < 2 ? $entry+8 : Get32u($outfile, $entry+8);
            my $pos;
            foreach $pos (@subifdPos) {
                Set32u($pos, $outfile, $valuePtr);
                $$dirInfo{Fixup}->AddFixup($valuePtr, $tag);
                undef $tag;
                $valuePtr += 4;
            }
        }
        unless ($found{0x7200} and $found{0x7201}) {
            $et->Error('Missing SR2SubIFD tag');
            return undef;
        }
    }
    return $outfile ? $$outfile : $result;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Sony - Sony EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sony maker notes EXIF meta information.

=head1 NOTES

Also see Minolta.pm since Sony DSLR models use structures originating from
Minolta.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm>

=item L<http://www.klingebiel.com/tempest/hd/pmp.html>

=item (...plus lots of testing with my RX100!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Thomas Bodenmann, Philippe Devaux, Jens Duttke, Marcus
Holland-Moritz, Andrey Tverdokhleb, Rudiger Lange, Igal Milchtaich, Michael
Reitinger and Jos Roost for help decoding some tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sony Tags>,
L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
