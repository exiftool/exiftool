#------------------------------------------------------------------------------
# File:         PanasonicRaw.pm
#
# Description:  Read/write Panasonic/Leica RAW/RW2/RWL meta information
#
# Revisions:    2009/03/24 - P. Harvey Created
#               2009/05/12 - PH Added RWL file type (same format as RW2)
#
# References:   1) https://exiftool.org/forum/index.php/topic,1542.0.html
#               2) http://www.cybercom.net/~dcoffin/dcraw/
#               3) http://syscall.eu/#pana
#               4) Klaus Homeister private communication
#              IB) Iliah Borg private communication (LibRaw)
#              JD) Jens Duttke private communication (TZ3,FZ30,FZ50)
#------------------------------------------------------------------------------

package Image::ExifTool::PanasonicRaw;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.29';

sub ProcessJpgFromRaw($$$);
sub WriteJpgFromRaw($$$);
sub WriteDistortionInfo($$$);
sub ProcessDistortionInfo($$$);

my %jpgFromRawMap = (
    IFD1         => 'IFD0',
    EXIF         => 'IFD0', # to write EXIF as a block
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
    IFD0         => 'APP1',
    MakerNotes   => 'ExifIFD',
    Comment      => 'COM',
);

my %wbTypeInfo = (
    PrintConv => \%Image::ExifTool::Exif::lightSource,
    SeparateTable => 'EXIF LightSource',
);

my %panasonicWhiteBalance = ( #forum9396
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    4 => 'n/a',
    5 => 'Flash',
    6 => 'n/a',
    7 => 'n/a',
    8 => 'Custom#1',
    9 => 'Custom#2',
    10 => 'Custom#3',
    11 => 'Custom#4',
    12 => 'Shade',
    13 => 'Kelvin',
    16 => 'AWBc', # GH5 and G9 (Makernotes WB==19)
);

# Tags found in Panasonic RAW/RW2/RWL images (ref PH)
%Image::ExifTool::PanasonicRaw::Main = (
    GROUPS => { 0 => 'EXIF', 1 => 'IFD0', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITE_GROUP => 'IFD0',   # default write group
    NOTES => 'These tags are found in IFD0 of Panasonic/Leica RAW, RW2 and RWL images.',
    0x01 => {
        Name => 'PanasonicRawVersion',
        Writable => 'undef',
    },
    0x02 => 'SensorWidth', #1/PH
    0x03 => 'SensorHeight', #1/PH
    0x04 => 'SensorTopBorder', #JD
    0x05 => 'SensorLeftBorder', #JD
    0x06 => 'SensorBottomBorder', #PH
    0x07 => 'SensorRightBorder', #PH
    # observed values for unknown tags - PH
    # 0x08: 1
    # 0x09: 1,3,4
    # 0x0a: 12
    # (IB gave 0x08-0x0a as BlackLevel tags, but Klaus' decoding makes more sense)
    0x08 => { Name => 'SamplesPerPixel', Writable => 'int16u', Protected => 1 }, #4
    0x09 => { #4
        Name => 'CFAPattern',
        Writable => 'int16u',
        Protected => 1,
        PrintConv => {
            0 => 'n/a',
            1 => '[Red,Green][Green,Blue]', # (CM-1, FZ70)
            2 => '[Green,Red][Blue,Green]', # (LX-7)
            3 => '[Green,Blue][Red,Green]', # (ZS100, FZ2500, FZ1000, ...)
            4 => '[Blue,Green][Green,Red]', # (LC-100, G-7, V-LUX1, ...)
        },
    },
    0x0a => { Name => 'BitsPerSample', Writable => 'int16u', Protected => 1 }, #4
    0x0b => { #4
        Name => 'Compression',
        Writable => 'int16u',
        Protected => 1,
        PrintConv => {
            34316 => 'Panasonic RAW 1', # (most models - RAW/RW2/RWL)
            34826 => 'Panasonic RAW 2', # (DIGILUX 2 - RAW)
            34828 => 'Panasonic RAW 3', # (D-LUX2,D-LUX3,FZ30,LX1 - RAW)
            34830 => 'Panasonic RAW 4', #IB (Leica DIGILUX 3, Panasonic DMC-L1)
        },
    },
    # 0x0c: 2 (only Leica Digilux 2)
    # 0x0d: 0,1
    # 0x0e,0x0f,0x10: 4095
    0x0e => { Name => 'LinearityLimitRed',   Writable => 'int16u' }, #IB
    0x0f => { Name => 'LinearityLimitGreen', Writable => 'int16u' }, #IB
    0x10 => { Name => 'LinearityLimitBlue',  Writable => 'int16u' }, #IB
    0x11 => { #JD
        Name => 'RedBalance',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
        Notes => 'found in Digilux 2 RAW images',
    },
    0x12 => { #JD
        Name => 'BlueBalance',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x13 => { #IB
        Name => 'WBInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::PanasonicRaw::WBInfo' },
    },
    0x17 => { #1
        Name => 'ISO',
        Writable => 'int16u',
    },
    # 0x18,0x19,0x1a: 0
    0x18 => { #IB
        Name => 'HighISOMultiplierRed',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x19 => { #IB
        Name => 'HighISOMultiplierGreen',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x1a => { #IB
        Name => 'HighISOMultiplierBlue',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    # 0x1b: [binary data] (something to do with the camera ISO cababilities: int16u count N,
    #                      followed by table of  N entries: int16u ISO, int16u[3] RGB gains - ref IB)
    0x1c => { Name => 'BlackLevelRed',   Writable => 'int16u' }, #IB
    0x1d => { Name => 'BlackLevelGreen', Writable => 'int16u' }, #IB
    0x1e => { Name => 'BlackLevelBlue',  Writable => 'int16u' }, #IB
    0x24 => { #2
        Name => 'WBRedLevel',
        Writable => 'int16u',
    },
    0x25 => { #2
        Name => 'WBGreenLevel',
        Writable => 'int16u',
    },
    0x26 => { #2
        Name => 'WBBlueLevel',
        Writable => 'int16u',
    },
    0x27 => { #IB
        Name => 'WBInfo2',
        SubDirectory => { TagTable => 'Image::ExifTool::PanasonicRaw::WBInfo2' },
    },
    # 0x27,0x29,0x2a,0x2b,0x2c: [binary data]
    0x2d => { #IB
        Name => 'RawFormat',
        Writable => 'int16u',
        Protected => 1,
        # 2 - RAW DMC-FZ8/FZ18
        # 3 - RAW DMC-L10
        # 4 - RW2 for most other models, including G9 in "pixel shift off" mode and YUNEEC CGO4
        #     (must add 15 to black levels for RawFormat == 4)
        # 5 - RW2 DC-GH5s; G9 in "pixel shift on" mode
        # 6 - RW2 DC-S1, DC-S1r in "pixel shift off" mode
        # 7 - RW2 DC-S1r (and probably DC-S1, have no raw samples) in "pixel shift on" mode
        # not used - DMC-LX1/FZ30/FZ50/L1/LX1/LX2
        # (modes 5 and 7 are lossless)
    },
    0x2e => { #JD
        Name => 'JpgFromRaw', # (writable directory!)
        Groups => { 2 => 'Preview' },
        Writable => 'undef',
        # protect this tag because it contains all the metadata
        Flags => [ 'Binary', 'Protected', 'NestedHtmlDump', 'BlockExtract' ],
        Notes => 'processed as an embedded document because it contains full EXIF',
        WriteCheck => '$val eq "none" ? undef : $self->CheckImage(\$val)',
        DataTag => 'JpgFromRaw',
        RawConv => '$self->ValidateImage(\$val,$tag)',
        SubDirectory => {
            # extract information from embedded image since it is metadata-rich,
            # unless HtmlDump option set (note that the offsets will be relative,
            # not absolute like they should be in verbose mode)
            TagTable => 'Image::ExifTool::JPEG::Main',
            WriteProc => \&WriteJpgFromRaw,
            ProcessProc => \&ProcessJpgFromRaw,
        },
    },
    0x2f => { Name => 'CropTop',    Writable => 'int16u' },
    0x30 => { Name => 'CropLeft',   Writable => 'int16u' },
    0x31 => { Name => 'CropBottom', Writable => 'int16u' },
    0x32 => { Name => 'CropRight',  Writable => 'int16u' },
    0x37 => { Name => 'ISO',        Writable => 'int32u' },
    # 0x44 - may contain another pointer to the raw data starting at byte 2 in this data (DC-GH6)
    0x10f => {
        Name => 'Make',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
        DataMember => 'Make',
        # save this value as an ExifTool member variable
        RawConv => '$self->{Make} = $val',
    },
    0x110 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
        DataMember => 'Model',
        # save this value as an ExifTool member variable
        RawConv => '$self->{Model} = $val',
    },
    0x111 => {
        Name => 'StripOffsets',
        # (this value is 0xffffffff for some models, and RawDataOffset must be used)
        Flags => [ 'IsOffset', 'PanasonicHack' ],
        OffsetPair => 0x117,  # point to associated byte counts
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x112 => {
        Name => 'Orientation',
        Writable => 'int16u',
        PrintConv => \%Image::ExifTool::Exif::orientation,
        Priority => 0,  # so IFD1 doesn't take precedence
    },
    0x116 => {
        Name => 'RowsPerStrip',
        Priority => 0,
    },
    0x117 => {
        Name => 'StripByteCounts',
        # (note that this value may represent something like uncompressed byte count
        # for RAW/RW2/RWL images from some models, and is zero for some other models)
        OffsetPair => 0x111,   # point to associated offset
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x118 => {
        Name => 'RawDataOffset', #PH (RW2/RWL)
        IsOffset => '$$et{TIFF_TYPE} =~ /^(RW2|RWL)$/', # (invalid in DNG-converted files)
        PanasonicHack => 1,
        OffsetPair => 0x117, # (use StripByteCounts as the offset pair)
        NotRealPair => 1,    # (to avoid Validate warning)
        IsImageData => 1,
    },
    0x119 => {
        Name => 'DistortionInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::PanasonicRaw::DistortionInfo' },
    },
    # 0x11b - chromatic aberration correction (ref 3) (also see forum9366)
    0x11c => { #forum9373
        Name => 'Gamma',
        Writable => 'int16u',
        # unfortunately it seems that the scaling factor varies with model...
        ValueConv => '$val / ($val >= 1024 ? 1024 : ($val >= 256 ? 256 : 100))',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x120 => {
        Name => 'CameraIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PanasonicRaw::CameraIFD',
            Base => '$start',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
        },
    },
    0x121 => { #forum9295
        Name => 'Multishot',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            65536 => 'Pixel Shift',
        },
    },
    # 0x122 - int32u: RAWDataOffset for the GH5s/GX9, or pointer to end of raw data for G9 (forum9295)
    0x127 => { #github193 (newer models)
        Name => 'JpgFromRaw2',
        Groups => { 2 => 'Preview' },
        DataTag => 'JpgFromRaw2',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
    0x13b => {
        Name => 'Artist',
        Groups => { 2 => 'Author' },
        Permanent => 1, # (so we don't add it if the model doesn't write it)
        Writable => 'string',
        WriteGroup => 'IFD0',
        RawConv => '$val =~ s/\s+$//; $val', # trim trailing blanks
    },
    0x2bc => { # PH Extension!!
        Name => 'ApplicationNotes', # (writable directory!)
        Writable => 'int8u',
        Format => 'undef',
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => {
            DirName => 'XMP',
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    0x001b => { #forum9250
        Name => 'NoiseReductionParams',
        Writable => 'undef',
        Format => 'int16u',
        Count => -1,
        Flags => 'Protected',
        Notes => q{
            the camera's default noise reduction setup.  The first number is the number
            of entries, then for each entry there are 4 numbers: an ISO speed, and
            noise-reduction strengths the R, G and B channels
        },
    },
    0x8298 => { #github193
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
        Permanent => 1, # (so we don't add it if the model doesn't write it)
        Format => 'undef',
        Writable => 'string',
        WriteGroup => 'IFD0',
        RawConv => $Image::ExifTool::Exif::Main{0x8298}{RawConv},
        RawConvInv => $Image::ExifTool::Exif::Main{0x8298}{RawConvInv},
        PrintConvInv => $Image::ExifTool::Exif::Main{0x8298}{PrintConvInv},
    },
    0x83bb => { # PH Extension!!
        Name => 'IPTC-NAA', # (writable directory!)
        Format => 'undef',      # convert binary values as undef
        Writable => 'int32u',   # but write int32u format code in IFD
        WriteGroup => 'IFD0',
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => {
            DirName => 'IPTC',
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x8769 => {
        Name => 'ExifOffset',
        Groups => { 1 => 'ExifIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            DirName => 'ExifIFD',
            Start => '$val',
        },
    },
    0x8825 => {
        Name => 'GPSInfo',
        Groups => { 1 => 'GPS' },
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'GPS',
            TagTable => 'Image::ExifTool::GPS::Main',
            Start => '$val',
        },
    },
    # 0xffff => 'DCSHueShiftValues', #exifprobe (NC)
);

# white balance information (ref IB)
# (PanasonicRawVersion<200: Digilux 2)
%Image::ExifTool::PanasonicRaw::WBInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0 => 'NumWBEntries',
    1 => { Name => 'WBType1', %wbTypeInfo },
    2 => { Name => 'WB_RBLevels1', Format => 'int16u[2]' },
    4 => { Name => 'WBType2', %wbTypeInfo },
    5 => { Name => 'WB_RBLevels2', Format => 'int16u[2]' },
    7 => { Name => 'WBType3', %wbTypeInfo },
    8 => { Name => 'WB_RBLevels3', Format => 'int16u[2]' },
    10 => { Name => 'WBType4', %wbTypeInfo },
    11 => { Name => 'WB_RBLevels4', Format => 'int16u[2]' },
    13 => { Name => 'WBType5', %wbTypeInfo },
    14 => { Name => 'WB_RBLevels5', Format => 'int16u[2]' },
    16 => { Name => 'WBType6', %wbTypeInfo },
    17 => { Name => 'WB_RBLevels6', Format => 'int16u[2]' },
    19 => { Name => 'WBType7', %wbTypeInfo },
    20 => { Name => 'WB_RBLevels7', Format => 'int16u[2]' },
);

# white balance information (ref IB)
# (PanasonicRawVersion>=200: D-Lux2, D-Lux3, DMC-FZ18/FZ30/LX1/L10)
%Image::ExifTool::PanasonicRaw::WBInfo2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0 => 'NumWBEntries',
    1 => { Name => 'WBType1', %wbTypeInfo },
    2 => { Name => 'WB_RGBLevels1', Format => 'int16u[3]' },
    5 => { Name => 'WBType2', %wbTypeInfo },
    6 => { Name => 'WB_RGBLevels2', Format => 'int16u[3]' },
    9 => { Name => 'WBType3', %wbTypeInfo },
    10 => { Name => 'WB_RGBLevels3', Format => 'int16u[3]' },
    13 => { Name => 'WBType4', %wbTypeInfo },
    14 => { Name => 'WB_RGBLevels4', Format => 'int16u[3]' },
    17 => { Name => 'WBType5', %wbTypeInfo },
    18 => { Name => 'WB_RGBLevels5', Format => 'int16u[3]' },
    21 => { Name => 'WBType6', %wbTypeInfo },
    22 => { Name => 'WB_RGBLevels6', Format => 'int16u[3]' },
    25 => { Name => 'WBType7', %wbTypeInfo },
    26 => { Name => 'WB_RGBLevels7', Format => 'int16u[3]' },
);

# lens distortion information (ref 3)
# (distortion correction equation: Ru = scale*(Rd + a*Rd^3 + b*Rd^5 + c*Rd^7), ref 3)
%Image::ExifTool::PanasonicRaw::DistortionInfo = (
    PROCESS_PROC => \&ProcessDistortionInfo,
    WRITE_PROC => \&WriteDistortionInfo,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    # (don't make this family 0 MakerNotes because we don't want it to be a deletable group)
    GROUPS => { 0 => 'PanasonicRaw', 1 => 'PanasonicRaw', 2 => 'Image'},
    WRITABLE => 1,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    NOTES => 'Lens distortion correction information.',
    # 0,1 - checksums
    2 => {
        Name => 'DistortionParam02',
        ValueConv => '$val / 32768',
        ValueConvInv => '$val * 32768',
    },
    # 3 - usually 0, but seen 0x026b when value 5 is non-zero
    4 => {
        Name => 'DistortionParam04',
        ValueConv => '$val / 32768',
        ValueConvInv => '$val * 32768',
    },
    5 => {
        Name => 'DistortionScale',
        ValueConv => '1 / (1 + $val/32768)',
        ValueConvInv => '(1/$val - 1) * 32768',
    },
    # 6 - seen 0x0000-0x027f
    7.1 => {
        Name => 'DistortionCorrection',
        Mask => 0x0f,
        # (have seen the upper 4 bits set for GF5 and GX1, giving a value of -4095 - PH)
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    8 => {
        Name => 'DistortionParam08',
        ValueConv => '$val / 32768',
        ValueConvInv => '$val * 32768',
    },
    9 => {
        Name => 'DistortionParam09',
        ValueConv => '$val / 32768',
        ValueConvInv => '$val * 32768',
    },
    # 10 - seen 0xfc,0x0101,0x01f4,0x021d,0x0256
    11 => {
        Name => 'DistortionParam11',
        ValueConv => '$val / 32768',
        ValueConvInv => '$val * 32768',
    },
    12 => {
        Name => 'DistortionN',
        Unknown => 1,
    },
    # 13 - seen 0x0000,0x01f9-0x02b2
    # 14,15 - checksums
);

# Panasonic RW2 camera IFD written by GH5 (ref PH)
# (doesn't seem to be valid for the GF7 or GM5 -- encrypted?)
%Image::ExifTool::PanasonicRaw::CameraIFD = (
    GROUPS => { 0 => 'PanasonicRaw', 1 => 'CameraIFD', 2 => 'Camera'},
    # (don't know what format codes 0x101 and 0x102 are for, so just
    #  map them into 4 = int32u for now)
    VARS => { MAP_FORMAT => { 0x101 => 4, 0x102 => 4 } },
    0x1001 => { #forum9388
        Name => 'MultishotOn',
        Writable => 'int32u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x1100 => { #forum9274
        Name => 'FocusStepNear',
        Writable => 'int16s',
    },
    0x1101 => { #forum9274 (was forum8484)
        Name => 'FocusStepCount',
        Writable => 'int16s',
    },
    0x1102 => { #forum9417
        Name => 'FlashFired',
        Writable => 'int32u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    # 0x1104 - set when camera shoots on lowest possible Extended-ISO (forum9290)
    0x1105 => { #forum9392
        Name => 'ZoomPosition',
        Notes => 'in the range 0-255 for most cameras',
        Writable => 'int32u',
    },
    0x1200 => { #forum9278
        Name => 'LensAttached',
        Notes => 'many CameraIFD tags are invalid if there is no lens attached',
        Writable => 'int32u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    # Note: LensTypeMake and LensTypeModel are combined into a Composite LensType tag
    # defined in Olympus.pm which has the same values as Olympus:LensType
    0x1201 => { #IB
        Name => 'LensTypeMake',
        Condition => '$format eq "int16u"',
        Writable => 'int16u',
        # when format is int16u, these values have been observed:
        #  0 - Olympus or unknown lens
        #  2 - Leica or Lumix lens
        # when format is int32u (S models), these values have been observed (ref IB):
        #  256 - Leica lens
        #  257 - Lumix lens
        #  258 - ? (seen once)
    },
    0x1202 => { #IB
        Name => 'LensTypeModel',
        Condition => '$format eq "int16u"',
        Writable => 'int16u',
        RawConv => q{
            return undef unless $val;
            require Image::ExifTool::Olympus; # (to load Composite LensID)
            return $val;
        },
        ValueConv => '$_=sprintf("%.4x",$val); s/(..)(..)/$2 $1/; $_',
        ValueConvInv => '$val =~ s/(..) (..)/$2$1/; hex($val)',
    },
    0x1203 => { #4
        Name => 'FocalLengthIn35mmFormat',
        Writable => 'int16u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    # 0x1300 - incident light value? (ref forum11395)
    0x1301 => { #forum11395
        Name => 'ApertureValue',
        Writable => 'int16s',
        Priority => 0,
        ValueConv => '2 ** ($val / 512)',
        ValueConvInv => '$val>0 ? 512*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x1302 => { #forum11395
        Name => 'ShutterSpeedValue',
        Writable => 'int16s',
        Priority => 0,
        ValueConv => 'abs($val/256)<100 ? 2**(-$val/256) : 0',
        ValueConvInv => '$val>0 ? -256*log($val)/log(2) : -25600',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x1303 => { #forum11395
        Name => 'SensitivityValue',
        Writable => 'int16s',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256)',
    },
    0x1305 => { #forum9384
        Name => 'HighISOMode',
        Writable => 'int16u',
        RawConv => '$val || undef',
        PrintConv => { 1 => 'On', 2 => 'Off' },
    },
    # 0x1306 EV for some models like the GX8 (forum11395)
    # 0x140b - scaled overall black level? (ref forum9281)
    # 0x1411 - scaled black level per channel difference (ref forum9281)
    0x1412 => { #forum11397
        Name => 'FacesDetected',
        Writable => 'int8u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    # 0x2000 - WB tungsten=3, daylight=4 (ref forum9467)
    # 0x2009 - scaled black level per channel (ref forum9281)
    # 0x3000-0x310b - red/blue balances * 1024 (ref forum9467)
    #  0x3000 modifiedTungsten-Red (-2?)
    #  0x3001 modifiedTungsten-Blue (-2?)
    #  0x3002 modifiedDaylight-Red (-2?)
    #  0x3003 modifiedDaylight-Blue (-2?)
    #  0x3004 modifiedTungsten-Red (-1?)
    #  0x3005 modifiedTungsten-Blue (-1?)
    #  0x3006 modifiedDaylight-Red (-1?)
    #  0x3007 modifiedDaylight-Blue (-1?)
    #  0x3100 DefaultTungsten-Red
    #  0x3101 DefaultTungsten-Blue
    #  0x3102 DefaultDaylight-Red
    #  0x3103 DefaultDaylight-Blue
    #  0x3104 modifiedTungsten-Red (+1?)
    #  0x3105 modifiedTungsten-Blue (+1?)
    #  0x3106 modifiedDaylight-Red (+1?)
    #  0x3107 modifiedDaylight-Blue (+1?)
    #  0x3108 modifiedTungsten-Red (+2?)
    #  0x3109 modifiedTungsten-Blue (+2?)
    #  0x310a modifiedDaylight-Red (+2?)
    #  0x310b modifiedDaylight-Blue (+2?)
    0x3200 => { #forum9275
        Name => 'WB_CFA0_LevelDaylight',
        Writable => 'int16u',
    },
    0x3201 => { #forum9275
        Name => 'WB_CFA1_LevelDaylight',
        Writable => 'int16u',
    },
    0x3202 => { #forum9275
        Name => 'WB_CFA2_LevelDaylight',
        Writable => 'int16u',
    },
    0x3203 => { #forum9275
        Name => 'WB_CFA3_LevelDaylight',
        Writable => 'int16u',
    },
    # 0x3204-0x3207 - user multipliers * 1024 ? (ref forum9275)
    # 0x320a - scaled maximum value of raw data (scaling = 4x) (ref forum9281)
    # 0x3209 - gamma (x256) (ref forum9281)
    0x3300 => { #forum9296/9396
        Name => 'WhiteBalanceSet',
        Writable => 'int8u',
        PrintConv => \%panasonicWhiteBalance,
        SeparateTable => 'WhiteBalance',
    },
    0x3420 => { #forum9276
        Name => 'WB_RedLevelAuto',
        Writable => 'int16u',
    },
    0x3421 => { #forum9276
        Name => 'WB_BlueLevelAuto',
        Writable => 'int16u',
    },
    0x3501 => { #4
        Name => 'Orientation',
        Writable => 'int8u',
        PrintConv => \%Image::ExifTool::Exif::orientation,
    },
    # 0x3504 = Tag 0x1301+0x1302-0x1303 (Bv = Av+Tv-Sv) (forum11395)
    # 0x3505 - same as 0x1300 (forum11395)
    0x3600 => { #forum9396
        Name => 'WhiteBalanceDetected',
        Writable => 'int8u',
        PrintConv => \%panasonicWhiteBalance,
        SeparateTable => 'WhiteBalance',
    },
);

# PanasonicRaw composite tags
%Image::ExifTool::PanasonicRaw::Composite = (
    ImageWidth => {
        Require => {
            0 => 'IFD0:SensorLeftBorder',
            1 => 'IFD0:SensorRightBorder',
        },
        ValueConv => '$val[1] - $val[0]',
    },
    ImageHeight => {
        Require => {
            0 => 'IFD0:SensorTopBorder',
            1 => 'IFD0:SensorBottomBorder',
        },
        ValueConv => '$val[1] - $val[0]',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::PanasonicRaw');


#------------------------------------------------------------------------------
# checksum algorithm for lens distortion correction information (ref 3)
# Inputs: 0) data ref, 1) start position, 2) number of bytes, 3) incement
# Returns: checksum value
sub Checksum($$$$)
{
    my ($dataPt, $start, $num, $inc) = @_;
    my $csum = 0;
    my $i;
    for ($i=0; $i<$num; ++$i) {
        $csum = (73 * $csum + Get8u($dataPt, $start + $i * $inc)) % 0xffef;
    }
    return $csum;
}

#------------------------------------------------------------------------------
# Read lens distortion information
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessDistortionInfo($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart} || 0;
    my $size = $$dirInfo{DirLen} || (length($$dataPt) - $start);
    if ($size == 32) {
        # verify the checksums (ref 3)
        my $csum1 = Checksum($dataPt, $start +  4, 12, 1);
        my $csum2 = Checksum($dataPt, $start + 16, 12, 1);
        my $csum3 = Checksum($dataPt, $start +  2, 14, 2);
        my $csum4 = Checksum($dataPt, $start +  3, 14, 2);
        my $res = $csum1 ^ Get16u($dataPt, $start + 2) ^
                  $csum2 ^ Get16u($dataPt, $start + 28) ^
                  $csum3 ^ Get16u($dataPt, $start + 0) ^
                  $csum4 ^ Get16u($dataPt, $start + 30);
        $et->Warn('Invalid DistortionInfo checksum',1) if $res;
    } else {
        $et->Warn('Invalid DistortionInfo',1);
    }
    return $et->ProcessBinaryData($dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Write lens distortion information
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: updated distortion information or undef on error
sub WriteDistortionInfo($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;  # (allow dummy access)
    my $dat = $et->WriteBinaryData($dirInfo, $tagTablePtr);
    if (defined $dat and length($dat) == 32) {
        # fix checksums (ref 3)
        Set16u(Checksum(\$dat,  4, 12, 1), \$dat,  2);
        Set16u(Checksum(\$dat, 16, 12, 1), \$dat, 28);
        Set16u(Checksum(\$dat,  2, 14, 2), \$dat,  0);
        Set16u(Checksum(\$dat,  3, 14, 2), \$dat, 30);
    } else {
        $et->Warn('Error wriing DistortionInfo',1);
    }
    return $dat;
}

#------------------------------------------------------------------------------
# Patch for writing non-standard Panasonic RAW/RW2/RWL raw data
# Inputs: 0) offset info ref, 1) raf ref, 2) IFD number
# Returns: error string, or undef on success
# OffsetInfo is a hash by tag ID of lists with the following elements:
#  0 - tag info ref
#  1 - pointer to int32u offset in IFD or value data
#  2 - value count
#  3 - reference to list of original offset values
#  4 - IFD format number
#  5 - (pointer to StripOffsets value added by this PatchRawDataOffset routine)
#  6 - flag set if this is a fixed offset (Panasonic GH6 fixed-offset hack)
sub PatchRawDataOffset($$$)
{
    my ($offsetInfo, $raf, $ifd) = @_;
    my $stripOffsets = $$offsetInfo{0x111};
    my $stripByteCounts = $$offsetInfo{0x117};
    my $rawDataOffset = $$offsetInfo{0x118};
    my $err;
    $err = 1 unless $ifd == 0;
    if ($stripOffsets or $stripByteCounts) {
        $err = 1 unless $stripOffsets and $stripByteCounts and $$stripOffsets[2] == 1;
    } else {
        # the DC-GH6 and DC-GH5M2 write RawDataOffset with no Strip tags, so we need
        # to create fake StripByteCounts information for copying the data
        if ($$offsetInfo{0x118}) { # (just to be safe)
            $stripByteCounts = $$offsetInfo{0x117} = [ $PanasonicRaw::Main{0x117}, 0, 1, [ 0 ], 4 ];
            # set flag so the offset will be fixed (GH6 hack, see https://exiftool.org/forum/index.php?topic=13861.0)
            # (of course, fixing up the offset is now unnecessary, but continue to do this even
            # though the fixup adjustment will be 0 because this allows us to delete the following
            # line to remove the fix-offset restriction if Panasonic ever sees the light, but note
            # that in this case we should investigate the purpose of the seemily-duplicate raw
            # data offset contained within PanasonicRaw_0x0044)
            $$offsetInfo{0x118}[6] = 1;
        }
    }
    if ($rawDataOffset and not $err) {
        $err = 1 unless $$rawDataOffset[2] == 1;
        if ($stripOffsets) {
            $err = 1 unless $$stripOffsets[3][0] == 0xffffffff or $$stripByteCounts[3][0] == 0;
        }
    }
    $err and return 'Unsupported Panasonic/Leica RAW variant';
    if ($rawDataOffset) {
        # update StripOffsets along with this tag if it contains a reasonable value
        if ($stripOffsets and $$stripOffsets[3][0] != 0xffffffff) {
            # save pointer to StripOffsets value for updating later
            push @$rawDataOffset, $$stripOffsets[1];
        }
        # handle via RawDataOffset instead of StripOffsets
        $stripOffsets = $$offsetInfo{0x111} = $rawDataOffset;
        delete $$offsetInfo{0x118};
    }
    # determine the length of the raw data
    my $pos = $raf->Tell();
    $raf->Seek(0, 2) or $err = 1; # seek to end of file
    my $len = $raf->Tell() - $$stripOffsets[3][0];
    $raf->Seek($pos, 0);
    # quick check to be sure the raw data length isn't unreasonable
    # (the 22-byte length is for '<Dummy raw image data>' in our tests)
    $err = 1 if ($len < 1000 and $len != 22) or $len & 0x80000000;
    $err and return 'Error reading Panasonic raw data';
    # update StripByteCounts info with raw data length
    # (note that the original value is maintained in the file)
    $$stripByteCounts[3][0] = $len;

    return undef;
}

#------------------------------------------------------------------------------
# Write meta information to Panasonic JpgFromRaw in RAW/RW2/RWL image
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: updated image data, or undef if nothing changed
sub WriteJpgFromRaw($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $byteOrder = GetByteOrder();
    my $fileType = $$et{TIFF_TYPE};   # RAW, RW2 or RWL
    my $dirStart = $$dirInfo{DirStart};
    if ($dirStart) { # DirStart is non-zero in DNG-converted RW2/RWL
        my $dirLen = $$dirInfo{DirLen} | length($$dataPt) - $dirStart;
        my $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
    }
    my $raf = File::RandomAccess->new($dataPt);
    my $outbuff;
    my %dirInfo = (
        RAF => $raf,
        OutFile => \$outbuff,
    );
    $$et{BASE} = $$dirInfo{DataPos};
    $$et{FILE_TYPE} = $$et{TIFF_TYPE} = 'JPEG';
    # use a specialized map so we don't write XMP or IPTC (or other junk) into the JPEG
    my $editDirs = $$et{EDIT_DIRS};
    my $addDirs = $$et{ADD_DIRS};
    $et->InitWriteDirs(\%jpgFromRawMap);
    # don't add XMP segment (IPTC won't get added because it is in Photoshop record)
    delete $$et{ADD_DIRS}{XMP};
    my $result = $et->WriteJPEG(\%dirInfo);
    # restore variables we changed
    $$et{BASE} = 0;
    $$et{FILE_TYPE} = 'TIFF';
    $$et{TIFF_TYPE} = $fileType;
    $$et{EDIT_DIRS} = $editDirs;
    $$et{ADD_DIRS} = $addDirs;
    SetByteOrder($byteOrder);
    return $result > 0 ? $outbuff : $$dataPt;
}

#------------------------------------------------------------------------------
# Extract meta information from an Panasonic JpgFromRaw
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid JpgFromRaw image
sub ProcessJpgFromRaw($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $byteOrder = GetByteOrder();
    my $fileType = $$et{TIFF_TYPE};   # RAW, RW2 or RWL
    my $tagInfo = $$dirInfo{TagInfo};
    my $verbose = $et->Options('Verbose');
    my ($indent, $out);
    $tagInfo or $et->Warn('No tag info for Panasonic JpgFromRaw'), return 0;
    my $dirStart = $$dirInfo{DirStart};
    if ($dirStart) { # DirStart is non-zero in DNG-converted RW2/RWL
        my $dirLen = $$dirInfo{DirLen} | length($$dataPt) - $dirStart;
        my $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
    }
    $$et{BASE} = $$dirInfo{DataPos} + ($dirStart || 0);
    $$et{FILE_TYPE} = $$et{TIFF_TYPE} = 'JPEG';
    $$et{DOC_NUM} = 1;
    # extract information from embedded JPEG
    my %dirInfo = (
        Parent => 'RAF',
        RAF    => File::RandomAccess->new($dataPt),
    );
    if ($verbose) {
        my $indent = $$et{INDENT};
        $$et{INDENT} = '  ';
        $out = $et->Options('TextOut');
        print $out '--- DOC1:JpgFromRaw ',('-'x56),"\n";
    }
    # fudge HtmlDump base offsets to show as a stand-alone JPEG
    $$et{BASE_FUDGE} = $$et{BASE};
    my $rtnVal = $et->ProcessJPEG(\%dirInfo);
    $$et{BASE_FUDGE} = 0;
    # restore necessary variables for continued RW2/RWL processing
    $$et{BASE} = 0;
    $$et{FILE_TYPE} = 'TIFF';
    $$et{TIFF_TYPE} = $fileType;
    delete $$et{DOC_NUM};
    SetByteOrder($byteOrder);
    if ($verbose) {
        $$et{INDENT} = $indent;
        print $out ('-'x76),"\n";
    }
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PanasonicRaw - Read/write Panasonic/Leica RAW/RW2/RWL meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write meta information in Panasonic/Leica RAW, RW2 and RWL images.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PanasonicRaw Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
