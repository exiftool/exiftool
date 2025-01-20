#------------------------------------------------------------------------------
# File:         Samsung.pm
#
# Description:  Samsung EXIF maker notes tags
#
# Revisions:    2010/03/01 - P. Harvey Created
#
# References:   1) Tae-Sun Park private communication
#               2) http://www.cybercom.net/~dcoffin/dcraw/
#               3) Pascal de Bruijn private communication (NX100)
#               4) Jaroslav Stepanek via rt.cpan.org
#               5) Nick Livchits private communication
#               6) Sreerag Raghavan private communication (SM-C200)
#               IB) Iliah Borg private communication (LibRaw)
#               NJ) Niels Kristian Bech Jensen private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Samsung;

use strict;
use vars qw($VERSION %samsungLensTypes);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.58';

sub WriteSTMN($$$);
sub ProcessINFO($$$);
sub ProcessSamsungMeta($$$);
sub ProcessSamsungIFD($$$);
sub ProcessSamsung($$;$);

# Samsung LensType lookup
%samsungLensTypes = (
    # (added "Samsung NX" in all of these lens names - ref 4)
    0 => 'Built-in or Manual Lens', #PH (EX1, WB2000)
    1 => 'Samsung NX 30mm F2 Pancake',
    2 => 'Samsung NX 18-55mm F3.5-5.6 OIS', # (also version II, ref 1)
    3 => 'Samsung NX 50-200mm F4-5.6 ED OIS',
    # what about the non-OIS version of the 18-55,
    # which was supposed to be available before the 20-50? - PH
    4 => 'Samsung NX 20-50mm F3.5-5.6 ED', #PH/4
    5 => 'Samsung NX 20mm F2.8 Pancake', #PH
    6 => 'Samsung NX 18-200mm F3.5-6.3 ED OIS', #4
    7 => 'Samsung NX 60mm F2.8 Macro ED OIS SSA', #1
    8 => 'Samsung NX 16mm F2.4 Pancake', #1/4
    9 => 'Samsung NX 85mm F1.4 ED SSA', #4
    10 => 'Samsung NX 45mm F1.8', #3
    11 => 'Samsung NX 45mm F1.8 2D/3D', #3
    12 => 'Samsung NX 12-24mm F4-5.6 ED', #4
    13 => 'Samsung NX 16-50mm F2-2.8 S ED OIS', #forum3833
    14 => 'Samsung NX 10mm F3.5 Fisheye', #NJ
    15 => 'Samsung NX 16-50mm F3.5-5.6 Power Zoom ED OIS', #5
    20 => 'Samsung NX 50-150mm F2.8 S ED OIS', #PH
    21 => 'Samsung NX 300mm F2.8 ED OIS', #IB
);

# range of values for Formats used in encrypted information
my %formatMinMax = (
    int16u => [ 0, 65535 ],
    int32u => [ 0, 4294967295 ],
    int16s => [ -32768, 32767 ],
    int32s => [ -2147483648, 2147483647 ],
);

# Samsung "STMN" maker notes (ref PH)
%Image::ExifTool::Samsung::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&WriteSTMN,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    IS_OFFSET => [ 2 ],   # tag 2 is 'IsOffset'
    IS_SUBDIR => [ 11 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        Tags found in the binary "STMN" format maker notes written by a number of
        Samsung models.
    },
    0 => {
        Name => 'MakerNoteVersion',
        Format => 'undef[8]',
    },
    2 => {
        Name => 'PreviewImageStart',
        OffsetPair => 3,  # associated byte count tagID
        DataTag => 'PreviewImage',
        IsOffset => 3,
        Protected => 2,
        WriteGroup => 'MakerNotes',
    },
    3 => {
        Name => 'PreviewImageLength',
        OffsetPair => 2,   # point to associated offset
        DataTag => 'PreviewImage',
        Protected => 2,
        WriteGroup => 'MakerNotes',
    },
    11 => {
        Name => 'SamsungIFD',
        # Note: this is not always an IFD.  In many models the string
        # "Park Byeongchan" is found at this location
        Condition => '$$valPt =~ /^[^\0]\0\0\0/',
        Format => 'undef[$size - 44]',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::IFD' },
    },
);

%Image::ExifTool::Samsung::IFD = (
    PROCESS_PROC => \&ProcessSamsungIFD,
    NOTES => q{
        This is a standard-format IFD found in the maker notes of some Samsung
        models, except that the entry count is a 4-byte integer and the offsets are
        relative to the end of the IFD.  Currently, no tags in this IFD are known,
        so the L<Unknown|../ExifTool.html#Unknown> (-u) or L<Verbose|../ExifTool.html#Verbose> (-v) option must be used to see this
        information.
    },
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # 0x0001 - undef[4000|4100]: starts with "MN_PRV" (or all zeros)
    # 0x0002 - undef[7000]     : starts with "Kim Miae"
    # 0x0003 - undef[5000]     : starts with "Lee BK"
    # 0x0004 - undef[500|2000] : starts with "IPCD"   (or all zeros)
    # 0x0006 - undef[100|200]  : starts with "MN_ADS" (or all zeros)
);

# Samsung maker notes (ref PH)
%Image::ExifTool::Samsung::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Tags found in the EXIF-format maker notes of newer Samsung models.',
    0x0001 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x0002 => {
        Name => 'DeviceType',
        Groups => { 2 => 'Camera' },
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x1000 => 'Compact Digital Camera',
            0x2000 => 'High-end NX Camera',
            0x3000 => 'HXM Video Camera',
            0x12000 => 'Cell Phone',
            0x300000 => 'SMX Video Camera',
        },
    },
    0x0003 => {
        Name => 'SamsungModelID',
        Groups => { 2 => 'Camera' },
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x100101c => 'NX10',
            0x1001226 => 'HMX-S10BP',
            0x1001226 => 'HMX-S15BP',
            0x1001233 => 'HMX-Q10',
            0x1001234 => 'HMX-H300',
            0x1001234 => 'HMX-H304',
            0x100130c => 'NX100',
            0x1001327 => 'NX11',
            0x170104b => 'ES65, ES67 / VLUU ES65, ES67 / SL50',
            0x170104e => 'ES70, ES71 / VLUU ES70, ES71 / SL600',
            0x1701052 => 'ES73 / VLUU ES73 / SL605',
            0x1701055 => 'ES25, ES27 / VLUU ES25, ES27 / SL45',
            0x1701300 => 'ES28 / VLUU ES28',
            0x1701303 => 'ES74,ES75,ES78 / VLUU ES75,ES78',
            0x2001046 => 'PL150 / VLUU PL150 / TL210 / PL151',
            0x2001048 => 'PL100 / TL205 / VLUU PL100 / PL101',
            0x2001311 => 'PL120,PL121 / VLUU PL120,PL121',
            0x2001315 => 'PL170,PL171 / VLUUPL170,PL171',
            0x200131e => 'PL210, PL211 / VLUU PL210, PL211',
            0x2701317 => 'PL20,PL21 / VLUU PL20,PL21',
            0x2a0001b => 'WP10 / VLUU WP10 / AQ100',
            0x3000000 => 'Various Models (0x3000000)',
           #0x3000000 => 'DV150F / DV151F / DV155F',
           #0x3000000 => 'NX mini',
           #0x3000000 => 'NX3000',
           #0x3000000 => 'NX3300',
           #0x3000000 => 'ST150F / ST151F / ST152F',
           #0x3000000 => 'WB200F / WB201F / WB202F',
           #0x3000000 => 'WB250F / WB251F / WB252F',
           #0x3000000 => 'WB30F / WB31F / WB32F',
           #0x3000000 => 'WB350F / WB351F / WB352F',
           #0x3000000 => 'WB800F',
            0x3a00018 => 'Various Models (0x3a00018)',
           #0x3a00018 => 'ES30 / VLUU ES30',
           #0x3a00018 => 'ES80 / ES81',
           #0x3a00018 => 'ES9 / ES8',
           #0x3a00018 => 'PL200 / VLUU PL200',
           #0x3a00018 => 'PL80 / VLUU PL80 / SL630 / PL81',
           #0x3a00018 => 'PL90 / VLUU PL90',
           #0x3a00018 => 'WB1100F / WB1101F / WB1102F',
           #0x3a00018 => 'WB2200F',
            0x400101f => 'ST1000 / ST1100 / VLUU ST1000 / CL65',
            0x4001022 => 'ST550 / VLUU ST550 / TL225',
            0x4001025 => 'Various Models (0x4001025)',
           #0x4001025 => 'DV300 / DV300F / DV305F',
           #0x4001025 => 'ST500 / VLUU ST500 / TL220',
           #0x4001025 => 'ST200 / ST200F / ST201 / ST201F / ST205F',
            0x400103e => 'VLUU ST5500, ST5500, CL80',
            0x4001041 => 'VLUU ST5000, ST5000, TL240',
            0x4001043 => 'ST70 / VLUU ST70 / ST71',
            0x400130a => 'Various Models (0x400130a)',
           #0x400130a => 'VLUU ST100, ST100',
           #0x400130a => 'VLUU ST600, ST600',
           #0x400130a => 'VLUU ST80, ST80',
            0x400130e => 'ST90,ST91 / VLUU ST90,ST91',
            0x4001313 => 'VLUU ST95, ST95',
            0x4a00015 => 'VLUU ST60',
            0x4a0135b => 'ST30, ST65 / VLUU ST65 / ST67',
            0x5000000 => 'Various Models (0x5000000)',
           #0x5000000 => 'EX2F',
           #0x5000000 => 'NX1000',
           #0x5000000 => 'NX20',
           #0x5000000 => 'NX200',
           #0x5000000 => 'NX210',
           #0x5000000 => 'ST96',
           #0x5000000 => 'WB750',
           #0x5000000 => 'ST700',
            0x5001038 => 'Various Models (0x5001038)',
           #0x5001038 => 'EK-GN120',
           #0x5001038 => 'HMX-E10',
           #0x5001038 => 'NX1',
           #0x5001038 => 'NX2000',
           #0x5001038 => 'NX30',
           #0x5001038 => 'NX300',
           #0x5001038 => 'NX500',
           #0x5001038 => 'SM-C200',
           #0x5001038 => 'WB2000',
            0x500103a => 'WB650 / VLUU WB650 / WB660',
            0x500103c => 'WB600 / VLUU WB600 / WB610',
            0x500133e => 'WB150 / WB150F / WB152 / WB152F / WB151',
            0x5a0000f => 'WB5000 / HZ25W',
            0x5a0001e => 'WB5500 / VLUU WB5500 / HZ50W',
            0x6001036 => 'EX1',
            0x700131c => 'VLUU SH100, SH100',
            0x27127002 => 'SMX-C20N',
        },
    },
    # 0x0004 - undef[x] (SamsungContentsID?)
    # 0x000a - int32u (ContinuousShotMode?)
    # 0x000b - int16u (BestPhotoMode?)
    # 0x000c - int32u ? values: 0,1
    # 0x000e - int32u[2] (SoundMultiPicture?)
    # 0x0010 - rational64u ? values: undef,inf
    0x0011 => { #6
        Name => 'OrientationInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::OrientationInfo' },
    },
    0x0020 => [{ #forum7685
        Name => 'SmartAlbumColor',
        Condition => '$$valPt =~ /^\0{4}/',
        Writable => 'int16u',
        Count => 2,
        PrintConv => {
            '0 0' => 'n/a',
        },
    },{
        Name => 'SmartAlbumColor',
        Writable => 'int16u',
        Count => 2,
        PrintConv => [{
            0 => 'Red',
            1 => 'Yellow',
            2 => 'Green',
            3 => 'Blue',
            4 => 'Magenta',
            5 => 'Black',
            6 => 'White',
            7 => 'Various',
        }],
    }],
    0x0021 => { #1
        Name => 'PictureWizard',
        Writable => 'int16u',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::PictureWizard' },
    },
    # 0x0022 - int32u (CaptureMode?) (Gamma? eg. 65538 = 1.2, ref forum7720)
    # 0x0023 - string: "0123456789" (PH) (placeholder for SerialNumber?)
    # 0x0025 - int32u (ImageCount?)
    # 0x002a - undef[4] (SNSDirectShare?)
    # 0x002f - string (GPSInfo01?)
    0x0030 => { #1 (NX100 with GPS)
        Name => 'LocalLocationName',
        Groups => { 2 => 'Location' },
        Writable => 'string',
        Format => 'undef',
        # this contains 2 place names (in Korean if in Korea), separated by a null+space
        # - terminate at double-null and replace nulls with newlines
        ValueConv => '$val=~s/\0\0.*//; $val=~s/\0 */\n/g; $val',
        ValueConvInv => '$val=~s/(\x0d\x0a|\x0d|\x0a)/\0 /g; $val . "\0\0"'
    },
    0x0031 => { #1 (NX100 with GPS)
        Name => 'LocationName',
        Groups => { 2 => 'Location' },
        Writable => 'string',
    },
    # 0x0032 - string (GPSInfo03)
    # 0x0033 - string (GPSInfo04)
    # 0x0034 - string (GPSInfo05)
    0x0035 => [{
        Name => 'PreviewIFD',
        Condition => '$$self{TIFF_TYPE} eq "SRW" and $$self{Model} ne "EK-GN120"', # (not an IFD in JPEG images)
        Groups => { 1 => 'PreviewIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewIFD',
            ByteOrder => 'Unknown',
            Start => '$val',
        },
    },{
        Name => 'PreviewIFD',
        Condition => '$$self{TIFF_TYPE} eq "SRW"', # (not an IFD in JPEG images)
        Groups => { 1 => 'PreviewIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewIFD',
            ByteOrder => 'Unknown',
            Start => '$val - 36',
        },
    }],
    # 0x003a - int16u[2] (SmartLensInfo?)
    # 0x003b - int16u[2] (PhotoStyleSelectInfo?)
    # 0x003c - int16u (SmartRange?)
    # 0x003d - int16u[5] (SmartCropInfo?)
    # 0x003e - int32u (DualCapture?)
    # 0x003f - int16u[2] (SGIFInfo?)
    0x0040 => { #forum7432
        Name => 'RawDataByteOrder',
        PrintConv => {
            0 => 'Little-endian (Intel, II)',
            1 => 'Big-endian (Motorola, MM)', #(NC)
        },
    },
    0x0041 => { #forum7684
        Name => 'WhiteBalanceSetup',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0x0043 => { #1 (NC)
        Name => 'CameraTemperature',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        # (DPreview samples all 0.2 C --> pre-production model)
        PrintConv => '$val =~ /\d/ ? "$val C" : $val',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    # 0x0045 => { Name => 'RawCompressionMode', Writable => 'int32u' }, # (related to ExposureMode, not raw compresison? ref forum7432)
    # 0x004a - int32u[7] (ImageVerification?)
    # 0x004b - int32u[2] (RewindInfo?)
    # 0x0050 - int32u (ColorSpace? - inconsistent) values: 1 (related to compression mode, ref forum7432)
    0x0050 => { #forum7432
        Name => 'RawDataCFAPattern',
        PrintConv => {
            0 => 'Unchanged',
            1 => 'Swap',
            65535 => 'Roll',
        },
    },
    # 0x0054 - int16u[2] (WeatherInfo?)
    # 0x0060 - undef (AEInfo?)
    # 0x0080 - undef (AFInfo?)
    # 0x00a0 - undef[8192] (AWBInfo1): white balance information (ref 1):
    #   At byte 5788, the WBAdjust: "Adjust\0\X\0\Y\0\Z\xee\xea\xce\xab", where
    #   Y = BA adjust (0=Blue7, 7=0, 14=Amber7), Z = MG (0=Magenta7, 7=0, 14=Green7)
    # 0x00a1 - undef (AWBInfo2?)
    # 0x00c0 - undef (IPCInfo?)
    # 0x00c7 - undef (SmartFunctionInfo?)
    # 0x00e0 - int16u (SceneResult?)
    # 0x00e1 - int16u[8] (SADebugInfo01?)
    # 0x00e1 - int16u[x] (SADebugInfo02?)
    0x0100 => {
        Name => 'FaceDetect',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' }, #(NC)
    },
    # 0x0101 - int16u[6] (FaceDetectInfo?)
    # 0x0102 - int16u[x] (FaceDetectInfo?)
    0x0120 => {
        Name => 'FaceRecognition',
        Writable => 'int32u',
        PrintConv => { 0 => 'Off', 1 => 'On' }, #(NC)
    },
    0x0123 => { Name => 'FaceName', Writable => 'string' },
    # 0x140 - undef (LensInfo?)
#
# the following tags found only in SRW images
#
    # 0xa000 - rational64u: 1 or 1.1 (ref PH) (MakerNoteVersion?)
    0xa001 => { #1
        Name => 'FirmwareName',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    0xa002 => { #PH/IB
        Name => 'SerialNumber',
        Condition => '$$valPt =~ /^\w{5}/', # should be at least 5 characters long
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    0xa003 => { #1 (SRW images only)
        Name => 'LensType',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        Count => -1,
        PrintConv => [ \%samsungLensTypes ],
    },
    0xa004 => { #1
        Name => 'LensFirmware',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    0xa005 => {
        Name => 'InternalLensSerialNumber', # Not the printed serial number (ref 1)
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    0xa010 => { #1
        Name => 'SensorAreas',
        Groups => { 2 => 'Camera' },
        Notes => 'full and valid sensor areas',
        Writable => 'int32u',
        Count => 8,
    },
    0xa011 => { #1
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
        },
    },
    0xa012 => { #1
        Name => 'SmartRange',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0xa013 => { #1
        Name => 'ExposureCompensation',
        Writable => 'rational64s',
    },
    0xa014 => { #1
        Name => 'ISO',
        Writable => 'int32u',
    },
    0xa018 => { #1
        Name => 'ExposureTime',
        Writable => 'rational64u',
        ValueConv => '$val=~s/ .*//; $val', # some models write 2 values here
        ValueConvInv => '$val',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
    },
    0xa019 => { #1
        Name => 'FNumber',
        Priority => 0,
        Writable => 'rational64u',
        ValueConv => '$val=~s/ .*//; $val', # some models write 2 values here
        ValueConvInv => '$val',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0xa01a => { #1
        Name => 'FocalLengthIn35mmFormat',
        Groups => { 2 => 'Camera' },
        Priority => 0,
        Format => 'int32u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    # 0xa01b - int32u (ImageCount?)
    # 0xa01b - int16u (LDCLens?)
    0xa020 => { #1
        Name => 'EncryptionKey',
        Writable => 'int32u',
        Count => 11,
        Protected => 1,
        DataMember => 'EncryptionKey',
        RawConv => '$$self{EncryptionKey} = [ split(" ",$val) ]; $val',
        Notes => 'key used to decrypt the tags below',
        # value is "305 72 737 456 282 307 519 724 13 505 193"
    },
    0xa021 => { #1
        Name => 'WB_RGGBLevelsUncorrected',
        Writable => 'int32u',
        Count => 4,
        Notes => 'these tags not corrected for WB_RGGBLevelsBlack',
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
    },
    0xa022 => { #1
        Name => 'WB_RGGBLevelsAuto',
        Writable => 'int32u',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-4)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,4)',
    },
    0xa023 => { #1
        Name => 'WB_RGGBLevelsIlluminator1',
        Writable => 'int32u',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-8)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,8)',
    },
    0xa024 => { #1
        Name => 'WB_RGGBLevelsIlluminator2',
        Writable => 'int32u',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-1)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,1)',
    },
    0xa025 => { # (PostAEGain?)
        Name => 'DigitalGain', #IB
        Writable => 'int32u',
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,6)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-6)',
    },
    0xa025 => { #IB
        Name => 'HighlightLinearityLimit',
        Writable => 'int32u',
    },
    0xa028 => { #2/PH
        Name => 'WB_RGGBLevelsBlack',
        Writable => 'int32s',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
    },
    0xa030 => { #1
        Name => 'ColorMatrix',
        Writable =>  'int32s',
        Count => 9,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa031 => { #1
        Name => 'ColorMatrixSRGB',
        Writable =>  'int32s',
        Count => 9,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa032 => { #1
        Name => 'ColorMatrixAdobeRGB',
        Writable =>  'int32s',
        Count => 9,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa033 => { #1
        Name => 'CbCrMatrixDefault',
        Writable => 'int32s',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa034 => { #1
        Name => 'CbCrMatrix',
        Writable => 'int32s',
        Count => 4,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,4)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-4)',
    },
    0xa035 => { #1
        Name => 'CbCrGainDefault',
        Writable => 'int32u',
        Count => 2,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
    },
    0xa036 => { #1
        Name => 'CbCrGain',
        Writable => 'int32u',
        Count => 2,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-2)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,2)',
    },
    0xa040 => { #1
        Name => 'ToneCurveSRGBDefault',
        Writable =>  'int32u',
        Count => 23,
        Notes => q{
            first value gives the number of tone curve entries.  This is followed by an
            array of X coordinates then an array of Y coordinates
        },
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa041 => { #1
        Name => 'ToneCurveAdobeRGBDefault',
        Writable =>  'int32u',
        Count => 23,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa042 => { #1
        Name => 'ToneCurveSRGB',
        Writable =>  'int32u',
        Count => 23,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa043 => { #1
        Name => 'ToneCurveAdobeRGB',
        Writable =>  'int32u',
        Count => 23,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa048 => { #1
        Name => 'RawData',
        Unknown => 1,
        Writable => 'int32s',
        Count => 12,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa050 => { #1
        Name => 'Distortion',
        Unknown => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0")',
    },
    0xa051 => { #1
        Name => 'ChromaticAberration',
        Unknown => 1,
        Writable => 'int16u',
        Count => 22,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",-7,-3)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,7,3)',
    },
    0xa052 => { #1
        Name => 'Vignetting',
        Unknown => 1,
        Writable => 'int16u',
        Count => 15,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa053 => { #1
        Name => 'VignettingCorrection',
        Unknown => 1,
        Writable => 'int16u',
        Count => 15,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa054 => { #1
        Name => 'VignettingSetting',
        Unknown => 1,
        Writable => 'int16u',
        Count => 15,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,0,"-0")',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,"-0",0)',
    },
    0xa055 => { #1
        Name => 'Samsung_Type2_0xa055', # (DistortionCamera1st?)
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,8)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-8)',
    },
    0xa056 => { #1
        Name => 'Samsung_Type2_0xa056', # (DistortionCamera2nd?)
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,5)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-5)',
    },
    0xa057 => { #1
        Name => 'Samsung_Type2_0xa057', # (DistortionCameraSetting?)
        Unknown => 1,
        Hidden => 1,
        Writable => 'int32s',
        Count => 8,
        RawConv    => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,2)',
        RawConvInv => 'Image::ExifTool::Samsung::Crypt($self,$val,$tagInfo,-2)',
    },
    # 0xa060 - rational64u (CISTemperature?)
    # 0xa061 - int16u (Compression?)
);

# orientation information (ref 6)
%Image::ExifTool::Samsung::OrientationInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'rational64s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Camera orientation information written by the Gear 360 (SM-C200).',
    0 => {
        Name => 'YawAngle', #(NC)
        Unknown => 1,
        Notes => 'always zero',
    },
    1 => {
        Name => 'PitchAngle',
        Notes => 'upward tilt of rear camera in degrees',
    },
    2 => {
        Name => 'RollAngle',
        Notes => 'clockwise rotation of rear camera in degrees',
    },
);

# Picture Wizard information (ref 1)
%Image::ExifTool::Samsung::PictureWizard = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'PictureWizardMode',
        PrintConvColumns => 3,
        PrintConv => { #3
             0 => 'Standard',
             1 => 'Vivid',
             2 => 'Portrait',
             3 => 'Landscape',
             4 => 'Forest',
             5 => 'Retro',
             6 => 'Cool',
             7 => 'Calm',
             8 => 'Classic',
             9 => 'Custom1',
            10 => 'Custom2',
            11 => 'Custom3',
           255 => 'n/a', #PH
        },
    },
    1 => 'PictureWizardColor',
    2 => {
        Name => 'PictureWizardSaturation',
        ValueConv => '$val - 4',
        ValueConvInv => '$val + 4',
    },
    3 => {
        Name => 'PictureWizardSharpness',
        ValueConv => '$val - 4',
        ValueConvInv => '$val + 4',
    },
    4 => {
        Name => 'PictureWizardContrast',
        ValueConv => '$val - 4',
        ValueConvInv => '$val + 4',
    },
);

# INFO tags in Samsung MP4 videos (ref PH)
%Image::ExifTool::Samsung::INFO = (
    PROCESS_PROC => \&ProcessINFO,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => q{
        This information is found in MP4 videos from Samsung models such as the
        SMX-C20N.
    },
    EFCT => 'Effect', # (guess)
    QLTY => 'Quality',
    # MDEL - value: 0
    # ASPT - value: 1, 2
);

# Samsung MP4 TAGS information (PH - from WP10 sample)
# --> very similar to Sanyo MP4 information
%Image::ExifTool::Samsung::MP4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This information is found in Samsung MP4 videos from models such as the
        WP10.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
        PrintConv => 'ucfirst(lc($val))',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[16]',
    },
    0x2e => { #(NC)
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x32 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x3a => { #(NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
    },
    0x6a => {
        Name => 'ISO',
        Format => 'int32u',
    },
    0x7d => {
        Name => 'Software',
        Format => 'string[32]',
        # (these tags are not at a constant offset for Olympus/Sanyo videos,
        #  so just to be safe use this to validate subsequent tags)
        RawConv => q{
            $val =~ /^SAMSUNG/ or return undef;
            $$self{SamsungMP4} = 1;
            return $val;
        },
    },
    0xf4 => {
        Name => 'Thumbnail',
        Condition => '$$self{SamsungMP4}',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Samsung::Thumbnail',
            Base => '$start',
        },
    },
);

# thumbnail image information found in MP4 videos (similar in Olympus,Samsung,Sanyo)
%Image::ExifTool::Samsung::Thumbnail = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    FORMAT => 'int32u',
    1 => 'ThumbnailWidth',
    2 => 'ThumbnailHeight',
    3 => 'ThumbnailLength',
    4 => { Name => 'ThumbnailOffset', IsOffset => 1 },
);

# Samsung MP4 @sec information (PH - from WB30F sample)
%Image::ExifTool::Samsung::sec = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This information is found in the @sec atom of Samsung MP4 videos from models
        such as the WB30F.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[32]',
        PrintConv => 'ucfirst(lc($val))',
    },
    0x20 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[32]',
    },
    0x200 => { Name => 'ThumbnailWidth',  Format => 'int32u' },
    0x204 => { Name => 'ThumbnailHeight', Format => 'int32u' },
    0x208 => { Name => 'ThumbnailLength', Format => 'int32u' }, # (2 bytes too long in my sample)
    0x20c => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{0x208}]',
        Notes => 'the THM image, embedded metadata is extracted as the first sub-document',
        SetBase => 1,
        RawConv => q{
            my $pt = $self->ValidateImage(\$val, $tag);
            if ($pt) {
                $$self{BASE} += 0x20c;
                $$self{DOC_NUM} = ++$$self{DOC_COUNT};
                $self->ExtractInfo($pt, { ReEntry => 1 });
                $$self{DOC_NUM} = 0;
            }
            return $pt;
        },
    },
);

# Samsung MP4 smta information (PH - from SM-C101 sample)
%Image::ExifTool::Samsung::smta = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => q{
        This information is found in the smta atom of Samsung MP4 videos from models
        such as the Galaxy S4.
    },
    svss => {
        Name => 'SamsungSvss',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::svss' },
    },
    mdln => 'SamsungModel', #PH (Samsung SM-A136U, etc)
    # swtr - 4 bytes, all zero
    # scid - 8 bytes, all zero
    # saut - 4 or 6 bytes, all zero
);

# Samsung MP4 svss information (PH - from SM-C101 sample)
%Image::ExifTool::Samsung::svss = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => q{
        This information is found in the svss atom of Samsung MP4 videos from models
        such as the Galaxy S4.
    },
    # junk - 10240 bytes, all zero
);

# thumbnail image information found in some MP4 videos
%Image::ExifTool::Samsung::Thumbnail2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    FORMAT => 'int32u',
    1 => 'ThumbnailWidth',
    2 => 'ThumbnailHeight',
    3 => 'ThumbnailLength',
    4 => { Name => 'ThumbnailOffset', IsOffset => 1 },
);

# information extracted from "ssuniqueid\0" APP5 (ref PH)
%Image::ExifTool::Samsung::APP5 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    ssuniqueid => {
        Name => 'UniqueID',
        # 32 bytes - some sort of serial number?
        ValueConv => 'unpack("H*",$val)',
    },
);

# information extracted from Samsung trailer (ie. Samsung SM-T805 "Sound & Shot" JPEG) (ref PH)
# NOTE: These tags may use $$self{SamsungTagName} in a Condition statement
#       if necessary to differentiate tags with the same ID but different names
%Image::ExifTool::Samsung::Trailer = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Other' },
    VARS => { NO_ID => 1, HEX_ID => 0 },
    PROCESS_PROC => \&ProcessSamsung,
    TAG_PREFIX => 'SamsungTrailer',
    PRIORITY => 0, # (first one takes priority so DepthMapWidth/Height match first DepthMapData)
    NOTES => q{
        Tags extracted from the SEFT trailer of JPEG and PNG images written when
        using certain features (such as "Sound & Shot" or "Shot & More") from
        Samsung models such as the Galaxy S4 and Tab S, and from the 'sefd' atom in
        HEIC images from models such as the S10+.
    },
    '0x0001-name' => 'EmbeddedImageName', # ("DualShot_1","DualShot_2","SingleShot")
    '0x0001' => [
        {
            Name => 'EmbeddedImage',
            Condition => '$$self{SamsungTagName} ne "DualShot_2"',
            Groups => { 2 => 'Preview' },
            Binary => 1,
        },
        {
            Name => 'EmbeddedImage2',
            Groups => { 2 => 'Preview' },
            Binary => 1,
        },
        # (have also seen the string "BOKEH" here (SM-A226B)
    ],
    '0x0100-name' => 'EmbeddedAudioFileName', # ("SoundShot_000")
    '0x0100' => { Name => 'EmbeddedAudioFile', Groups => { 2 => 'Audio' }, Binary => 1 },
    '0x0201-name' => 'SurroundShotVideoName', # ("Interactive_Panorama_000")
    '0x0201' => { Name => 'SurroundShotVideo', Groups => { 2 => 'Video' }, Binary => 1 },
   # 0x0800-name - seen 'SoundShot_Meta_Info'
   # 0x0800 - unknown (29 bytes) (contains already-extracted EmbeddedAudioFileName)
   # 0x0830-name - seen '1165724808.pre'
   # 0x0830 - unknown (164004 bytes)
   # 0x08c0-name - seen 'Auto_Enhance_Info' #forum16086
   # 0x08d0-name - seen 'Interactive_Panorama_Info'
   # 0x08d0 - unknown (7984 bytes)
   # 0x08e0-name - seen 'Panorama_Shot_Info'
   # 0x08e0 - string, seen 'PanoramaShot'
   # 0x08e1-name - seen 'Motion_Panorama_Info'
   # 0x0910-name - seen 'Front_Cam_Selfie_Info'
   # 0x0910 - string, seen 'Front_Cam_Selfie_Info'
   # 0x09e0-name - seen 'Burst_Shot_Info'
   # 0x09e0 - string, seen '489489125'
   # 0x09e1-name - seen 'BurstShot_Best_Photo_Info' #forum16086
   # 0x09f0-name - seen 'Pro_Mode_Info' #forum16086
   # 0x0a01-name - seen 'Image_UTC_Data'
    '0x0a01' => { #forum7161
        Name => 'TimeStamp',
        Groups => { 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val / 1e3, 1, 3)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '0x0a20-name' => 'DualCameraImageName', # ("FlipPhoto_002")
    '0x0a20' => { Name => 'DualCameraImage', Groups => { 2 => 'Preview' }, Binary => 1 },
    '0x0a30-name' => 'EmbeddedVideoType', # ("MotionPhoto_Data")
    '0x0a30' => { Name => 'EmbeddedVideoFile', Groups => { 2 => 'Video' }, Binary => 1 }, #forum7161
   # 0x0a41-name - seen 'BackupRestore_Data' #forum16086
   # 0x0aa1-name - seen 'MCC_Data'
   # 0x0aa1 - seen '204','222','234','302','429'
    '0x0aa1' => {
        Name => 'MCCData',
        Groups => { 2 => 'Location' },
        PrintConv => {
            202 => 'Greece (202)',
            204 => 'Netherlands (204)',
            206 => 'Belgium (206)',
            208 => 'France (208)',
            212 => 'Monaco (212)',
            213 => 'Andorra (213)',
            214 => 'Spain (214)',
            216 => 'Hungary (216)',
            218 => 'Bosnia & Herzegov. (218)',
            219 => 'Croatia (219)',
            220 => 'Serbia (220)',
            221 => 'Kosovo (221)',
            222 => 'Italy (222)',
            226 => 'Romania (226)',
            228 => 'Switzerland (228)',
            230 => 'Czech Rep. (230)',
            231 => 'Slovakia (231)',
            232 => 'Austria (232)',
            234 => 'United Kingdom (234)',
            235 => 'United Kingdom (235)',
            238 => 'Denmark (238)',
            240 => 'Sweden (240)',
            242 => 'Norway (242)',
            244 => 'Finland (244)',
            246 => 'Lithuania (246)',
            247 => 'Latvia (247)',
            248 => 'Estonia (248)',
            250 => 'Russian Federation (250)',
            255 => 'Ukraine (255)',
            257 => 'Belarus (257)',
            259 => 'Moldova (259)',
            260 => 'Poland (260)',
            262 => 'Germany (262)',
            266 => 'Gibraltar (266)',
            268 => 'Portugal (268)',
            270 => 'Luxembourg (270)',
            272 => 'Ireland (272)',
            274 => 'Iceland (274)',
            276 => 'Albania (276)',
            278 => 'Malta (278)',
            280 => 'Cyprus (280)',
            282 => 'Georgia (282)',
            283 => 'Armenia (283)',
            284 => 'Bulgaria (284)',
            286 => 'Turkey (286)',
            288 => 'Faroe Islands (288)',
            289 => 'Abkhazia (289)',
            290 => 'Greenland (290)',
            292 => 'San Marino (292)',
            293 => 'Slovenia (293)',
            294 => 'Macedonia (294)',
            295 => 'Liechtenstein (295)',
            297 => 'Montenegro (297)',
            302 => 'Canada (302)',
            308 => 'St. Pierre & Miquelon (308)',
            310 => 'United States / Guam (310)',
            311 => 'United States / Guam (311)',
            312 => 'United States (312)',
            316 => 'United States (316)',
            330 => 'Puerto Rico (330)',
            334 => 'Mexico (334)',
            338 => 'Jamaica (338)',
            340 => 'French Guiana / Guadeloupe / Martinique (340)',
            342 => 'Barbados (342)',
            344 => 'Antigua and Barbuda (344)',
            346 => 'Cayman Islands (346)',
            348 => 'British Virgin Islands (348)',
            350 => 'Bermuda (350)',
            352 => 'Grenada (352)',
            354 => 'Montserrat (354)',
            356 => 'Saint Kitts and Nevis (356)',
            358 => 'Saint Lucia (358)',
            360 => 'St. Vincent & Gren. (360)',
            362 => 'Bonaire, Sint Eustatius and Saba / Curacao / Netherlands Antilles (362)',
            363 => 'Aruba (363)',
            364 => 'Bahamas (364)',
            365 => 'Anguilla (365)',
            366 => 'Dominica (366)',
            368 => 'Cuba (368)',
            370 => 'Dominican Republic (370)',
            372 => 'Haiti (372)',
            374 => 'Trinidad and Tobago (374)',
            376 => 'Turks and Caicos Islands / US Virgin Islands (376)',
            400 => 'Azerbaijan (400)',
            401 => 'Kazakhstan (401)',
            402 => 'Bhutan (402)',
            404 => 'India (404)',
            405 => 'India (405)',
            410 => 'Pakistan (410)',
            412 => 'Afghanistan (412)',
            413 => 'Sri Lanka (413)',
            414 => 'Myanmar (Burma) (414)',
            415 => 'Lebanon (415)',
            416 => 'Jordan (416)',
            417 => 'Syrian Arab Republic (417)',
            418 => 'Iraq (418)',
            419 => 'Kuwait (419)',
            420 => 'Saudi Arabia (420)',
            421 => 'Yemen (421)',
            422 => 'Oman (422)',
            424 => 'United Arab Emirates (424)',
            425 => 'Israel / Palestinian Territory (425)',
            426 => 'Bahrain (426)',
            427 => 'Qatar (427)',
            428 => 'Mongolia (428)',
            429 => 'Nepal (429)',
            430 => 'United Arab Emirates (430)',
            431 => 'United Arab Emirates (431)',
            432 => 'Iran (432)',
            434 => 'Uzbekistan (434)',
            436 => 'Tajikistan (436)',
            437 => 'Kyrgyzstan (437)',
            438 => 'Turkmenistan (438)',
            440 => 'Japan (440)',
            441 => 'Japan (441)',
            450 => 'South Korea (450)',
            452 => 'Viet Nam (452)',
            454 => 'Hongkong, China (454)',
            455 => 'Macao, China (455)',
            456 => 'Cambodia (456)',
            457 => 'Laos P.D.R. (457)',
            460 => 'China (460)',
            466 => 'Taiwan (466)',
            467 => 'North Korea (467)',
            470 => 'Bangladesh (470)',
            472 => 'Maldives (472)',
            502 => 'Malaysia (502)',
            505 => 'Australia (505)',
            510 => 'Indonesia (510)',
            514 => 'Timor-Leste (514)',
            515 => 'Philippines (515)',
            520 => 'Thailand (520)',
            525 => 'Singapore (525)',
            528 => 'Brunei Darussalam (528)',
            530 => 'New Zealand (530)',
            537 => 'Papua New Guinea (537)',
            539 => 'Tonga (539)',
            540 => 'Solomon Islands (540)',
            541 => 'Vanuatu (541)',
            542 => 'Fiji (542)',
            544 => 'American Samoa (544)',
            545 => 'Kiribati (545)',
            546 => 'New Caledonia (546)',
            547 => 'French Polynesia (547)',
            548 => 'Cook Islands (548)',
            549 => 'Samoa (549)',
            550 => 'Micronesia (550)',
            552 => 'Palau (552)',
            553 => 'Tuvalu (553)',
            555 => 'Niue (555)',
            602 => 'Egypt (602)',
            603 => 'Algeria (603)',
            604 => 'Morocco (604)',
            605 => 'Tunisia (605)',
            606 => 'Libya (606)',
            607 => 'Gambia (607)',
            608 => 'Senegal (608)',
            609 => 'Mauritania (609)',
            610 => 'Mali (610)',
            611 => 'Guinea (611)',
            612 => 'Ivory Coast (612)',
            613 => 'Burkina Faso (613)',
            614 => 'Niger (614)',
            615 => 'Togo (615)',
            616 => 'Benin (616)',
            617 => 'Mauritius (617)',
            618 => 'Liberia (618)',
            619 => 'Sierra Leone (619)',
            620 => 'Ghana (620)',
            621 => 'Nigeria (621)',
            622 => 'Chad (622)',
            623 => 'Central African Rep. (623)',
            624 => 'Cameroon (624)',
            625 => 'Cape Verde (625)',
            626 => 'Sao Tome & Principe (626)',
            627 => 'Equatorial Guinea (627)',
            628 => 'Gabon (628)',
            629 => 'Congo, Republic (629)',
            630 => 'Congo, Dem. Rep. (630)',
            631 => 'Angola (631)',
            632 => 'Guinea-Bissau (632)',
            633 => 'Seychelles (633)',
            634 => 'Sudan (634)',
            635 => 'Rwanda (635)',
            636 => 'Ethiopia (636)',
            637 => 'Somalia (637)',
            638 => 'Djibouti (638)',
            639 => 'Kenya (639)',
            640 => 'Tanzania (640)',
            641 => 'Uganda (641)',
            642 => 'Burundi (642)',
            643 => 'Mozambique (643)',
            645 => 'Zambia (645)',
            646 => 'Madagascar (646)',
            647 => 'Reunion (647)',
            648 => 'Zimbabwe (648)',
            649 => 'Namibia (649)',
            650 => 'Malawi (650)',
            651 => 'Lesotho (651)',
            652 => 'Botswana (652)',
            653 => 'Swaziland (653)',
            654 => 'Comoros (654)',
            655 => 'South Africa (655)',
            657 => 'Eritrea (657)',
            659 => 'South Sudan (659)',
            702 => 'Belize (702)',
            704 => 'Guatemala (704)',
            706 => 'El Salvador (706)',
            708 => 'Honduras (708)',
            710 => 'Nicaragua (710)',
            712 => 'Costa Rica (712)',
            714 => 'Panama (714)',
            716 => 'Peru (716)',
            722 => 'Argentina Republic (722)',
            724 => 'Brazil (724)',
            730 => 'Chile (730)',
            732 => 'Colombia (732)',
            734 => 'Venezuela (734)',
            736 => 'Bolivia (736)',
            738 => 'Guyana (738)',
            740 => 'Ecuador (740)',
            744 => 'Paraguay (744)',
            746 => 'Suriname (746)',
            748 => 'Uruguay (748)',
            750 => 'Falkland Islands (Malvinas) (750)',
            901 => 'International Networks / Satellite Networks (901)',
        },
    },
   # 0x0ab0-name - seen 'DualShot_Meta_Info'
    '0x0ab1-name' => {
        Name => 'DepthMapName',
        # seen 'DualShot_DepthMap_1' (SM-N950U), DualShot_DepthMap_5 (SM-G998W)
        RawConv => '$$self{DepthMapName} = $val',
    },
    '0x0ab1' => [
        {
            Name => 'DepthMapData',
            Condition => '$$self{DepthMapName} eq "DualShot_DepthMap_1"',
            Binary => 1,
        },{
            Name => 'DepthMapData2',
            Binary => 1,
        },
    ],
   # 0x0ab3-name - seen 'DualShot_Extra_Info' (SM-N950U)
    '0x0ab3' => { # (SM-N950U)
        Name => 'DualShotExtra',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::DualShotExtra' },
     },
   # 0x0ab4-name - seen 'DualShot_Core_Info' #forum16086
   # 0x0ac0-name - seen 'ZoomInOut_Info' (SM-N950U)
   # 0x0ac0 - 2048 bytes of interesting stuff including firmware version? (SM-N950U)
   # 0x0b30-name - seen 'Camera_Sticker_Info' #forum16086
    '0x0b40' => { # (SM-N975X front camera)
        Name => 'SingleShotMeta',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::SingleShotMeta' },
        # (have also see the string "BOKEH_INFO" here (SM-A226B)
     },
   # 0x0b41-name - seen 'SingeShot_DepthMap_1' (Yes, "Singe") (SM-N975X front camera)
    '0x0b41' => { Name => 'SingleShotDepthMap', Binary => 1 },
   # 0x0b51-name - seen 'Intelligent_PhotoEditor_Data' #forum16086
   # 0x0b60-name - seen 'UltraWide_PhotoEditor_Data' #forum16086
   # 0x0b90-name - seen 'Document_Scan_Info' #forum16086
   # 0x0ba1-name - seen 'Original_Path_Hash_Key', 'PhotoEditor_Re_Edit_Data', 'deco_doodle_bitmap', 'deco_sticker_bitmap', 'deco_text_bitmap'
   # 0x0ba2-name - seen 'Copy_Available_Edit_Info' #forum16086
   # 0x0bc0-name - seen 'Single_Relighting_Bokeh_Info' #forum16086
   # 0x0bd0-name - seen 'Dual_Relighting_Bokeh_Info' #forum16086
   # 0x0be0-name - seen 'Livefocus_JDM_Info' #forum16086
   # 0x0bf0-name - seen 'Remaster_Info' #forum16086
   '0x0bf0' => 'RemasterInfo', #forum16086/16242
   # 0x0c21-name - seen 'Portrait_Effect_Info' #forum16086
   # 0x0c51-name - seen 'Samsung_Capture_Info' #forum16086
   '0x0c51' => 'SamsungCaptureInfo', #forum16086/16242
   # 0x0c61-name - seen 'Camera_Capture_Mode_Info' #forum16086
   # 0x0c71-name - seen 'Pro_White_Balance_Info' #forum16086
   # 0x0c81-name - seen 'Watermark_Info' #forum16086
   # 0x0cc1-name - seen 'Color_Display_P3' #forum16086
   # 0x0cd2-name - seen 'Photo_HDR_Info' #forum16086
   # 0x0ce1-name - seen 'Gallery_DC_Data' #forum16086
   # 0x0d01-name - seen 'Camera_Scene_Info', 'Camera_Scene_Info2', 'Camera_Scene_Info3' #forum16086
   # 0x0d11-name - seen 'Video_Snapshot_Info' #forum16086
   # 0x0d21-name - seen 'Camera_Scene_Info' #forum16086
   # 0x0d31-name - seen 'Food_Blur_Effect_Info' #forum16086
    '0x0d91' => { #forum16086/16242
        Name => 'PEg_Info',
        Description => 'PEg Info',
        SubDirectory => { TagTable => 'Image::ExifTool::JSON::Main' },
    },
   # 0x0da1-name - seen 'Captured_App_Info' #forum16086
   # 0xa050-name - seen 'Jpeg360_2D_Info' (Samsung Gear 360)
   # 0xa050 - seen 'Jpeg3602D' (Samsung Gear 360)
   # 0x0c81-name - seen 'Watermark_Info'
);

# DualShot Extra Info (ref PH)
%Image::ExifTool::Samsung::DualShotExtra = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FIRST_ENTRY => 0,
    FORMAT => 'int32u',
    # This is a pain, but the DepthMapWidth/Height move around in this record.
    # In all of my samples so far, the bytes "01 00 ff ff" precede these tags.
    # I have seen this byte sequence at offsets 32, 60, 64 and 68, so look for
    # it in bytes 32-95, and use its location to adjust the tag positions
    8 => {
        Name => 'DualShotDummy',
        Format => 'undef[64]',
        Hidden => 1,
        Hook => q{
            if ($size >= 96) {
                my $tmp = substr($$dataPt, $pos, 64);
                # (have seen 0x01,0x03 and 0x07)
                if ($tmp =~ /[\x01-\x09]\0\xff\xff/g and not pos($tmp) % 4) {
                    $$self{DepthMapTagPos} = pos($tmp);
                    $varSize += $$self{DepthMapTagPos} - 32;
                }
            }
        },
        RawConv => 'undef', # not a real tag
    },
    16 => {
        Name => 'DepthMapWidth',
        Condition => '$$self{DepthMapTagPos}',
        Notes => 'index varies depending on model',
    },
    17 => {
        Name => 'DepthMapHeight',
        Condition => '$$self{DepthMapTagPos}',
        Notes => 'index varies depending on model',
    },
);

# SingleShot Meta Info (ref PH) (SM-N975X front camera)
%Image::ExifTool::Samsung::SingleShotMeta = (
    PROCESS_PROC => \&ProcessSamsungMeta,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    inputWidth          => { },
    inputHeight         => { },
    outputWidth         => { },
    outputHeight        => { },
    segWidth            => { },
    segHeight           => { },
    depthSWWidth        => { },
    depthSWHeight       => { },
    depthHWWidth        => { },
    depthHWHeight       => { },
    flipStatus          => { },
    lensFacing          => { },
    deviceOrientation   => { },
    objectOrientation   => { },
    isArtBokeh          => { },
    beautyRetouchLevel  => { },
    beautyColorLevel    => { },
    effectType          => { },
    effectStrength      => { },
    blurStrength        => { },
    spinStrength        => { },
    zoomStrength        => { },
    colorpopStrength    => { },
    monoStrength        => { },
    sidelightStrength   => { },
    vintageStrength     => { },
    bokehShape          => { },
    perfMode            => { },
);

# Samsung composite tags
%Image::ExifTool::Samsung::Composite = (
    GROUPS => { 2 => 'Image' },
    WB_RGGBLevels => {
        Require => {
            0 => 'WB_RGGBLevelsUncorrected',
            1 => 'WB_RGGBLevelsBlack',
        },
        ValueConv => q{
            my @a = split ' ', $val[0];
            my @b = split ' ', $val[1];
            $a[$_] -= $b[$_] foreach 0..$#a;
            return "@a";
        },
    },
    DepthMapTiff => {
        Require => {
            0 => 'DepthMapData',
            1 => 'DepthMapWidth',
            2 => 'DepthMapHeight',
        },
        ValueConv => q{
            return undef unless length ${$val[0]} == $val[1] * $val[2];
            my $tiff = MakeTiffHeader($val[1],$val[2],1,8) . ${$val[0]};
            return \$tiff;
        },
    },
    SingleShotDepthMapTiff => {
        Require => {
            0 => 'SingleShotDepthMap',
            1 => 'SegWidth',
            2 => 'SegHeight',
        },
        ValueConv => q{
            return undef unless length ${$val[0]} == $val[1] * $val[2];
            my $tiff = MakeTiffHeader($val[1],$val[2],1,8) . ${$val[0]};
            return \$tiff;
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Samsung');

#------------------------------------------------------------------------------
# Encrypt/Decrypt NX10 information
# Inputs: 0) ExifTool ref, 1) value as a string of integers,
#         2) tagInfo hash ref, 3-N) encryption salt values
# Returns: encrypted/decrypted value
# Notes:
# 1) The encryption salt starts with '-' to reverse the encryption algorithm
# 2) Additional salt values are provided when tag stores multiple arrays
#    (in which case the first value of the tag gives the array length)
sub Crypt($$$@)
{
    my ($et, $val, $tagInfo, @salt) = @_;
    my $key = $$et{EncryptionKey} or return undef;
    my $format = $$tagInfo{Writable} || $$tagInfo{Format} or return undef;
    return undef unless $formatMinMax{$format};
    my ($min, $max) = @{$formatMinMax{$format}};
    my @a = split ' ', $val;
    my $newSalt = (@salt > 1) ? 1 : 0;  # skip length entry if this is an array
    my ($i, $sign, $salt, $start);
    for ($i=$newSalt; $i<@a; ++$i) {
        if ($i == $newSalt) {
            $start = $i;
            $salt = shift @salt;
            $sign = ($salt =~ s/^-//) ? -1 : 1;
            $newSalt += $a[0] if @salt;
        }
        $a[$i] += $sign * $$key[($salt+$i-$start) % scalar(@$key)];
        # handle integer wrap-around
        if ($sign > 0) {
            $a[$i] -= $max - $min + 1 if $a[$i] > $max;
        } else {
            $a[$i] += $max - $min + 1 if $a[$i] < $min;
        }
    }
    return "@a";
}

#------------------------------------------------------------------------------
# Process Samsung MP4 INFO data
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessINFO($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $len = $$dirInfo{DirLen};
    my $end = $pos + $len;
    $et->VerboseDir('INFO', undef, $len);
    while ($pos + 8 <= $end) {
        my $tag = substr($$dataPt, $pos, 4);
        my $val = Get32u($dataPt, $pos + 4);
        unless ($$tagTablePtr{$tag}) {
            my $name = "Samsung_INFO_$tag";
            $name =~ tr/-_0-9a-zA-Z//dc;
            AddTagToTable($tagTablePtr, $tag, { Name => $name }) if $name;
        }
        $et->HandleTag($tagTablePtr, $tag, $val);
        $pos += 8;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read Samsung Meta Info from trailer
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: true on success
sub ProcessSamsungMeta($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dirName = $$dirInfo{DirName};
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $end = $$dirInfo{DirLen} + $pos;
    unless ($pos + 8 <= $end and substr($$dataPt, $pos, 4) eq 'DOFS') {
        $et->Warn("Unrecognized $dirName data", 1);
        return 0;
    }
    my $ver = Get32u($dataPt, $pos + 4);
    if ($ver == 3) {
        unless ($pos + 18 <= $end and Get32u($dataPt, $pos + 12) == $$dirInfo{DirLen}) {
            $et->Warn("Unrecognized $dirName version $ver data");
            return 0;
        }
        my $num = Get16u($dataPt, $pos + 16);
        $et->VerboseDir("$dirName version $ver", $num);
        $pos += 18;
        my ($i, $val);
        for ($i=0; $i<$num; ++$i) {
            last if $pos + 2 > $end;
            my ($x, $n) = unpack("x${pos}CC", $$dataPt);
            $pos += 2;
            last if $pos + $n + 2 > $end;
            my $tag = substr($$dataPt, $pos, $n);
            my $len = Get16u($dataPt, $pos + $n);
            $pos += $n + 2;
            last if $pos + $len > $end;
            if ($len == 4) {
                $val = Get32u($dataPt, $pos);
            } else {
                my $tmp = substr($$dataPt, $pos, $len);
                $val = \$pos;
            }
            $et->HandleTag($tagTablePtr, $tag, $val);
            $pos += $len;
        }
        $et->Warn("Unexpected end of $dirName version $ver $i $num data") if $i < $num;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: true on success
sub ProcessSamsungIFD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $len = $$dirInfo{DataLen};
    my $pos = $$dirInfo{DirStart};
    return 0 unless $pos + 4 < $len;
    my $dataPt = $$dirInfo{DataPt};
    my $buff = substr($$dataPt, $pos, 4);
    # this is not an IFD for many models
    # (the string "Park Byeongchan" is often found here)
    return 0 unless $buff =~ s/^([^\0])\0\0\0/$1\0$1\0/s;
    my $numEntries = ord $1;
    if ($$et{HTML_DUMP}) {
        my $pt = $$dirInfo{DirStart} + $$dirInfo{DataPos} + $$dirInfo{Base};
        $et->HDump($pt-44, 44, "MakerNotes header", 'Samsung');
        $et->HDump($pt, 4, "MakerNotes entries", "Format: int32u\nEntry count: $numEntries");
        $$dirInfo{NoDumpEntryCount} = 1;
    }
    substr($$dataPt, $pos, 4) = $buff;      # insert bogus 2-byte entry count
    # offset base is at end of IFD
    my $shift = $$dirInfo{DirStart} + 4 + $numEntries * 12 + 4;
    $$dirInfo{Base} += $shift;
    $$dirInfo{DataPos} -= $shift;
    $$dirInfo{DirStart} += 2;       # start at bogus entry count
    $$dirInfo{ZeroOffsetOK} = 1;    # disable check for zero offset
    delete $$et{NO_UNKNOWN};  # (set for BinaryData, but not for EXIF IFD's)
    my $rtn = Image::ExifTool::Exif::ProcessExif($et, $dirInfo, $tagTablePtr);
    substr($$dataPt, $pos + 2, 1) = "\0";   # remove bogus count
    return $rtn;
}

#------------------------------------------------------------------------------
# Read/write Samsung trailer (ie. "Sound & Shot" written by Galaxy Tab S (SM-T805))
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 not valid Samsung trailer, or -1 error writing
# - updates DataPos to point to start of Samsung trailer
# - updates DirLen to existing trailer length
sub ProcessSamsung($$;$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $offset = $$dirInfo{Offset} || 0;
    my $outfile = $$dirInfo{OutFile};
    my $verbose = $et->Options('Verbose');
    my $unknown = $et->Options('Unknown');
    my ($buff, $buf2, $index, $offsetPos, $audioNOff, $audioSize);

    unless ($raf) {
        $raf = File::RandomAccess->new($$dirInfo{DataPt});
        $et->VerboseDir('SamsungTrailer');
    }
    return 0 unless $raf->Seek(-6-$offset, 2) and $raf->Read($buff, 6) == 6 and
                    ($buff eq 'QDIOBS' or $buff eq "\0\0SEFT");
    my $endPos = $raf->Tell();
    $raf->Seek(-2, 1) or return 0 if $buff eq 'QDIOBS'; # rewind to before 'BS'
    my $blockEnd = $raf->Tell();
    SetByteOrder('II');

    # read blocks backward until we find the SEFH/SEFT block
    # (the only other block I have seen is QDIO/QDIO)
SamBlock:
    for (;;) {
        last unless $raf->Seek($blockEnd-8, 0) and $raf->Read($buff, 8) == 8;
        my $type = substr($buff, 4);
        last unless $type =~ /^\w+$/;
        my $len = Get32u(\$buff, 0);
        last unless $len < 0x10000 and $len >= 4 and $len + 8 < $blockEnd;
        last unless $raf->Seek(-8-$len, 1) and $raf->Read($buff, $len) == $len;
        $blockEnd -= $len + 8;
        unless ($type eq 'SEFT') {  # look for directory block (ends with "SEFT")
            next unless $outfile and $type eq 'QDIO';
            # QDIO block format:
            #   0 - 'QDIO'
            #   4 - int32u: 101 (version)
            #   8 - int32u: 1
            #  12 - int32u: absolute offset of audio file start (augh!!)
            #  16 - int32u: absolute offset of audio file end (augh!!)
            #  20 - int32u: 20 (QDIO block length minus 8)
            #  24 - 'QDIO'
            if ($len == 20) {
                # save position of audio file offset in QDIO block
                $offsetPos = $endPos - $raf->Tell() + $len - 12;
            } else {
                $et->Error('Unsupported Samsung trailer QDIO block', 1);
            }
            next;
        }
        last unless $buff =~ /^SEFH/ and $len >= 12;   # validate SEFH header
        my $dirPos = $raf->Tell() - $len;
        # my $ver = Get32u(\$buff, 0x04);  # version (=101)
        my $count = Get32u(\$buff, 0x08);
        last if 12 + 12 * $count > $len;
        my $tagTablePtr = GetTagTable('Image::ExifTool::Samsung::Trailer');

        # scan ahead quickly to look for the block where the data comes first
        # (have only seen this to be the first in the directory, but just in case)
        my $firstBlock = 0;
        for ($index=0; $index<$count; ++$index) {
            my $entry = 12 + 12 * $index;
            my $noff = Get32u(\$buff, $entry + 4);  # negative offset
            $firstBlock = $noff if $firstBlock < $noff;
        }
        # save trailer position and length
        my $dataPos = $$dirInfo{DataPos} = $dirPos - $firstBlock;
        my $dirLen = $$dirInfo{DirLen} = $endPos - $dataPos;
        if (($verbose or $$et{HTML_DUMP}) and not $outfile and $$dirInfo{RAF}) {
            $et->DumpTrailer($dirInfo);
            return 1 if $$et{HTML_DUMP};
        }
        # read through the SEFH/SEFT directory entries
        for ($index=0; $index<$count; ++$index) {
            my $entry = 12 + 12 * $index;
            # first 2 bytes always 0 (may be part of block type)
            my $type = Get16u(\$buff, $entry + 2);  # block type
            my $noff = Get32u(\$buff, $entry + 4);  # negative offset
            my $size = Get32u(\$buff, $entry + 8);  # block size
            last SamBlock if $noff > $dirPos or $size > $noff or $size < 8;
            $firstBlock = $noff if $firstBlock < $noff;
            if ($outfile) {
                next unless $type == 0x0100 and not $audioNOff;
                # save offset and length of first audio file for QDIO block
                last unless $raf->Seek($dirPos-$noff, 0) and $raf->Read($buf2, 8) == 8;
                $len = Get32u(\$buf2, 4);
                $audioNOff = $noff - 8 - $len;   # negative offset to start of audio data
                $audioSize = $size - 8 - $len;
                next;
            }
            last unless $raf->Seek($dirPos-$noff, 0) and $raf->Read($buf2, $size) == $size;
            # (could validate the first 4 bytes of the block because they
            # are the same as the first 4 bytes of the directory entry)
            $len = Get32u(\$buf2, 4);
            last if $len + 8 > $size;
            my $tag = sprintf("0x%.4x", $type);
            # add unknown tags if necessary
            unless ($$tagTablePtr{$tag}) {
                next unless $unknown or $verbose;
                my %tagInfo = (
                    Name        => "SamsungTrailer_$tag",
                    Description => "Samsung Trailer $tag",
                    Unknown     => 1,
                    Binary      => 1,
                );
                AddTagToTable($tagTablePtr, $tag, \%tagInfo);
            }
            unless ($$tagTablePtr{"$tag-name"}) {
                my %tagInfo2 = (
                    Name        => "SamsungTrailer_${tag}Name",
                    Description => "Samsung Trailer $tag Name",
                    Unknown     => 1,
                );
                AddTagToTable($tagTablePtr, "$tag-name", \%tagInfo2);
            }
            # set SamsungTagName ExifTool member for use in tag Condition
            $$et{SamsungTagName} = substr($buf2, 8, $len);
            # extract tag name and value
            $et->HandleTag($tagTablePtr, "$tag-name", undef,
                DataPt  => \$buf2,
                DataPos => $dirPos - $noff,
                Start   => 8,
                Size    => $len,
            );
            $et->HandleTag($tagTablePtr, $tag, undef,
                DataPt  => \$buf2,
                DataPos => $dirPos - $noff,
                Start   => 8 + $len,
                Size    => $size - (8 + $len),
            );
            delete $$et{SamsungTagName};
        }
        if ($outfile) {
            last unless $raf->Seek($dataPos, 0) and $raf->Read($buff, $dirLen) == $dirLen;
            # adjust the absolute offset in the QDIO block if necessary
            if ($offsetPos and $audioNOff) {
                # initialize the audio file start/end position in the QDIO block
                my $newPos = Tell($outfile) + $dirPos - $audioNOff - $dataPos;
                Set32u($newPos, \$buff, length($buff) - $offsetPos);
                Set32u($newPos + $audioSize, \$buff, length($buff) - $offsetPos + 4);
                # add a fixup so the calling routine can apply further shifts if necessary
                require Image::ExifTool::Fixup;
                my $fixup = $$dirInfo{Fixup};
                $fixup or $fixup = $$dirInfo{Fixup} = Image::ExifTool::Fixup->new;
                $fixup->AddFixup(length($buff) - $offsetPos);
                $fixup->AddFixup(length($buff) - $offsetPos + 4);
            }
            $et->VPrint(0, "  Writing Samsung trailer ($dirLen bytes)\n") if $verbose;
            Write($$dirInfo{OutFile}, $buff) or return -1;
            return 1;
        }
        return 1;
    }
    $et->Warn('Error processing Samsung trailer',1);
    return 0;
}

#------------------------------------------------------------------------------
# Write Samsung STMN maker notes
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: Binary data block or undefined on error
sub WriteSTMN($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    # create a Fixup for the PreviewImage
    $$dirInfo{Fixup} = Image::ExifTool::Fixup->new;
    my $val = Image::ExifTool::WriteBinaryData($et, $dirInfo, $tagTablePtr);
    # force PreviewImage into the trailer even if it fits in EXIF segment
    $$et{PREVIEW_INFO}{IsTrailer} = 1 if $$et{PREVIEW_INFO};
    return $val;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Samsung - Samsung EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Samsung maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Tae-Sun Park for decoding a number of tags, Pascal de Bruijn for
the PictureWizard values, and everyone else who helped by discovering new
Samsung information.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Samsung Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
