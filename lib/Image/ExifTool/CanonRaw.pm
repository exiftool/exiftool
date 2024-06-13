#------------------------------------------------------------------------------
# File:         CanonRaw.pm
#
# Description:  Read Canon RAW (CRW) meta information
#
# Revisions:    11/25/2003 - P. Harvey Created
#               12/02/2003 - P. Harvey Completely reworked and figured out many
#                            more tags
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               2) http://www.wonderland.org/crw/
#               3) http://xyrion.org/ciff/CIFFspecV1R04.pdf
#               4) Dave Nicholson private communication (PowerShot S30)
#------------------------------------------------------------------------------

package Image::ExifTool::CanonRaw;

use strict;
use vars qw($VERSION $AUTOLOAD %crwTagFormat);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::Canon;

$VERSION = '1.61';

sub WriteCRW($$);
sub ProcessCanonRaw($$$);
sub WriteCanonRaw($$$);
sub CheckCanonRaw($$$);
sub InitMakerNotes($);
sub SaveMakerNotes($);
sub BuildMakerNotes($$$$$$);

# formats for CRW tag types (($tag >> 8) & 0x38)
# Note: don't define format for undefined types
%crwTagFormat = (
    0x00 => 'int8u',
    0x08 => 'string',
    0x10 => 'int16u',
    0x18 => 'int32u',
  # 0x20 => 'undef',
  # 0x28 => 'undef',
  # 0x30 => 'undef',
);

# Canon raw file tag table
# Note: Tag ID's have upper 2 bits set to zero, since these 2 bits
# just specify the location of the information
%Image::ExifTool::CanonRaw::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessCanonRaw,
    WRITE_PROC => \&WriteCanonRaw,
    CHECK_PROC => \&CheckCanonRaw,
    WRITABLE => 1,
    0x0000 => { Name => 'NullRecord', Writable => 'undef' }, #3
    0x0001 => { #3
        Name => 'FreeBytes',
        Format => 'undef',
        Binary => 1,
    },
    0x0032 => { Name => 'CanonColorInfo1', Writable => 0 },
    0x0805 => [
        # this tag is found in more than one directory...
        {
            Condition => '$self->{DIR_NAME} eq "ImageDescription"',
            Name => 'CanonFileDescription',
            Writable => 'string[32]',
        },
        {
            Name => 'UserComment',
            Writable => 'string[256]',
        },
    ],
    0x080a => {
        Name => 'CanonRawMakeModel',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::CanonRaw::MakeModel' },
    },
    0x080b => { Name => 'CanonFirmwareVersion', Writable => 'string[32]' },
    0x080c => { Name => 'ComponentVersion',     Writable => 'string'     }, #3
    0x080d => { Name => 'ROMOperationMode',     Writable => 'string[8]'  }, #3
    0x0810 => { Name => 'OwnerName',            Writable => 'string[32]' },
    0x0815 => { Name => 'CanonImageType',       Writable => 'string[32]' },
    0x0816 => { Name => 'OriginalFileName',     Writable => 'string[32]' },
    0x0817 => { Name => 'ThumbnailFileName',    Writable => 'string[32]' },
    0x100a => { #3
        Name => 'TargetImageType',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Real-world Subject',
            1 => 'Written Document',
        },
    },
    0x1010 => { #3
        Name => 'ShutterReleaseMethod',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Single Shot',
            2 => 'Continuous Shooting',
        },
    },
    0x1011 => { #3
        Name => 'ShutterReleaseTiming',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Priority on shutter',
            1 => 'Priority on focus',
        },
    },
    0x1016 => { Name => 'ReleaseSetting',       Writable => 'int16u' }, #3
    0x101c => { Name => 'BaseISO',              Writable => 'int16u' }, #3
    0x1028=> { #PH
        Name => 'CanonFlashInfo',
        Writable => 'int16u',
        Count => 4,
        Unknown => 1,
    },
    0x1029 => {
        Name => 'CanonFocalLength',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::FocalLength' },
    },
    0x102a => {
        Name => 'CanonShotInfo',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ShotInfo' },
    },
    0x102c => {
        Name => 'CanonColorInfo2',
        Writable => 0,
        # for the S30, the following information has been decoded: (ref 4)
        # offset 66: int32u - shutter half press time in ms
        # offset 70: int32u - image capture time in ms
        # offset 74: int16u - custom white balance flag (0=Off, 512=On)
    },
    0x102d => {
        Name => 'CanonCameraSettings',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraSettings' },
    },
    0x1030 => { #4
        Name => 'WhiteSample',
        Writable => 0,
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonRaw::WhiteSample',
        },
    },
    0x1031 => {
        Name => 'SensorInfo',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::SensorInfo' },
    },
    # this tag has only be verified for the 10D in CRW files, but the D30 and D60
    # also produce CRW images and have CustomFunction information in their JPEG's
    0x1033 => [
        {
            Name => 'CustomFunctions10D',
            Condition => '$self->{Model} =~ /EOS 10D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions10D',
            },
        },
        {
            Name => 'CustomFunctionsD30',
            Condition => '$self->{Model} =~ /EOS D30\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsD60',
            Condition => '$self->{Model} =~ /EOS D60\b/',
            SubDirectory => {
                # the stored size in the D60 apparently doesn't include the size word:
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size-2,$size)',
                # (D60 custom functions are basically the same as D30)
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsUnknown',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FuncsUnknown',
            },
        },
    ],
    0x1038 => {
        Name => 'CanonAFInfo',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::AFInfo' },
    },
    0x1093 => {
        Name => 'CanonFileInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FileInfo',
        },
    },
    0x10a9 => {
        Name => 'ColorBalance',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorBalance' },
    },
    0x10b5 => { #PH
        Name => 'RawJpgInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonRaw::RawJpgInfo',
        },
    },
    0x10ae => {
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0x10b4 => {
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
        },
    },
    0x1803 => { #3
        Name => 'ImageFormat',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::CanonRaw::ImageFormat' },
    },
    0x1804 => { Name => 'RecordID', Writable => 'int32u' }, #3
    0x1806 => { #3
        Name => 'SelfTimerTime',
        Writable => 'int32u',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '"$val s"',
        PrintConvInv => '$val=~s/\s*s.*//;$val',
    },
    0x1807 => {
        Name => 'TargetDistanceSetting',
        Format => 'float',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0x180b => [
        {
            # D30
            Name => 'SerialNumber',
            Condition => '$$self{Model} =~ /EOS D30\b/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%x-%.5d",$val>>16,$val&0xffff)',
            PrintConvInv => '$val=~/(.*)-(\d+)/ ? (hex($1)<<16)+$2 : undef',
        },
        {
            # all EOS models (D30, 10D, 300D)
            Name => 'SerialNumber',
            Condition => '$$self{Model} =~ /EOS/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.10d",$val)',
            PrintConvInv => '$val',
        },
        {
            # this is not SerialNumber for PowerShot models (but what is it?) - PH
            Name => 'UnknownNumber',
            Unknown => 1,
        },
    ],
    0x180e => {
        Name => 'TimeStamp',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::TimeStamp',
        },
    },
    0x1810 => {
        Name => 'ImageInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::ImageInfo',
        },
    },
    0x1813 => { #3
        Name => 'FlashInfo',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonRaw::FlashInfo',
        },
    },
    0x1814 => { #3
        Name => 'MeasuredEV',
        Notes => q{
            this is the Canon name for what could better be called MeasuredLV, and
            should be close to the calculated LightValue for a proper exposure with most
            models
        },
        Format => 'float',
        ValueConv => '$val + 5',
        ValueConvInv => '$val - 5',
    },
    0x1817 => {
        Name => 'FileNumber',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val;s/(\d+)(\d{4})/$1-$2/;$_',
        PrintConvInv => '$_=$val;s/-//;$_',
    },
    0x1818 => { #3
        Name => 'ExposureInfo',
        Groups => { 1 => 'CIFF' }, # (only so CIFF shows up in group lists)
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::CanonRaw::ExposureInfo' },
    },
    0x1834 => { #PH
        Name => 'CanonModelID',
        Writable => 'int32u',
        PrintHex => 1,
        Notes => q{
            this is the complete list of model ID numbers, but note that many of these
            models do not produce CRW images
        },
        SeparateTable => 'Canon CanonModelID',
        PrintConv => \%Image::ExifTool::Canon::canonModelID,
    },
    0x1835 => {
        Name => 'DecoderTable',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::CanonRaw::DecoderTable' },
    },
    0x183b => { #PH
        # display format for serial number
        Name => 'SerialNumberFormat',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x90000000 => 'Format 1',
            0xa0000000 => 'Format 2',
        },
    },
    0x2005 => {
        Name => 'RawData',
        Writable => 0,
        Binary => 1,
    },
    0x2007 => {
        Name => 'JpgFromRaw',
        Groups => { 2 => 'Preview' },
        Writable => 'resize',  # 'resize' allows this value to change size
        Permanent => 0,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
    0x2008 => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Writable => 'resize',  # 'resize' allows this value to change size
        WriteCheck => '$self->CheckImage(\$val)',
        Permanent => 0,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
    # the following entries are subdirectories
    # (any 0x28 and 0x30 tag types are handled automatically by the decoding logic)
    0x2804 => {
        Name => 'ImageDescription',
        SubDirectory => { },
        Writable => 0,
    },
    0x2807 => { #3
        Name => 'CameraObject',
        SubDirectory => { },
        Writable => 0,
    },
    0x3002 => { #3
        Name => 'ShootingRecord',
        SubDirectory => { },
        Writable => 0,
    },
    0x3003 => { #3
        Name => 'MeasuredInfo',
        SubDirectory => { },
        Writable => 0,
    },
    0x3004 => { #3
        Name => 'CameraSpecification',
        SubDirectory => { },
        Writable => 0,
    },
    0x300a => { #3
        Name => 'ImageProps',
        SubDirectory => { },
        Writable => 0,
    },
    0x300b => {
        Name => 'ExifInformation',
        SubDirectory => { },
        Writable => 0,
    },
);

# Canon binary data blocks
%Image::ExifTool::CanonRaw::MakeModel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    DATAMEMBER => [ 0, 6 ], # indices of data members to extract when writing
    WRITABLE => 1,
    FORMAT => 'string',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # (can't specify a first entry because this isn't
    # a simple binary table with fixed offsets)
    0 => {
        Name => 'Make',
        Format => 'string[6]',  # "Canon\0"
        DataMember => 'Make',
        RawConv => '$self->{Make} = $val',
    },
    6 => {
        Name => 'Model',
        Format => 'string', # no size = to the end of the data
        Description => 'Camera Model Name',
        DataMember => 'Model',
        RawConv => '$self->{Model} = $val',
    },
);

%Image::ExifTool::CanonRaw::TimeStamp = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Time' },
    0 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Shift => 'Time',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    1 => { #3
        Name => 'TimeZoneCode',
        Format => 'int32s',
        ValueConv => '$val / 3600',
        ValueConvInv => '$val * 3600',
    },
    2 => { #3
        Name => 'TimeZoneInfo',
        Notes => 'set to 0x80000000 if TimeZoneCode is valid',
    },
);

%Image::ExifTool::CanonRaw::ImageFormat = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'FileFormat',
        Flags => 'PrintHex',
        PrintConv => {
            0x00010000 => 'JPEG (lossy)',
            0x00010002 => 'JPEG (non-quantization)',
            0x00010003 => 'JPEG (lossy/non-quantization toggled)',
            0x00020001 => 'CRW',
        },
    },
    1 => {
        Name => 'TargetCompressionRatio',
        Format => 'float',
    },
);

%Image::ExifTool::CanonRaw::RawJpgInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
#    0 => 'RawJpgInfoSize',
    1 => { #PH
        Name => 'RawJpgQuality',
        PrintConv => {
            1 => 'Economy',
            2 => 'Normal',
            3 => 'Fine',
            5 => 'Superfine',
        },
    },
    2 => { #PH
        Name => 'RawJpgSize',
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    3 => 'RawJpgWidth', #PH
    4 => 'RawJpgHeight', #PH
);

%Image::ExifTool::CanonRaw::FlashInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'FlashGuideNumber',
    1 => 'FlashThreshold',
);

%Image::ExifTool::CanonRaw::ExposureInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => 'ExposureCompensation',
    1 => {
        Name => 'ShutterSpeedValue',
        ValueConv => 'abs($val)<100 ? 1/(2**$val) : 0',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : -100',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    2 => {
        Name => 'ApertureValue',
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
);

%Image::ExifTool::CanonRaw::ImageInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # Note: Don't make these writable (except rotation) because it confuses
    # Canon decoding software if the are changed
    0 => 'ImageWidth', #3
    1 => 'ImageHeight', #3
    2 => { #3
        Name => 'PixelAspectRatio',
        Format => 'float',
    },
    3 => {
        Name => 'Rotation',
        Format => 'int32s',
        Writable => 1,
    },
    4 => 'ComponentBitDepth', #3
    5 => 'ColorBitDepth', #3
    6 => 'ColorBW', #3
);

# ref 4
%Image::ExifTool::CanonRaw::DecoderTable = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => 'DecoderTableNumber',
    2 => 'CompressedDataOffset',
    3 => 'CompressedDataLength',
);

# ref 1/4
%Image::ExifTool::CanonRaw::WhiteSample = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    1 => 'WhiteSampleWidth',
    2 => 'WhiteSampleHeight',
    3 => 'WhiteSampleLeftBorder',
    4 => 'WhiteSampleTopBorder',
    5 => 'WhiteSampleBits',
    # this is followed by the encrypted white sample values (ref 1)
);

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Process Raw file directory
# Inputs: 0) ExifTool object reference
#         1) directory information reference, 2) tag table reference
# Returns: 1 on success
sub ProcessCanonRaw($$$)
{
    my ($et, $dirInfo, $rawTagTable) = @_;
    my $blockStart = $$dirInfo{DirStart};
    my $blockSize = $$dirInfo{DirLen};
    my $raf = $$dirInfo{RAF} or return 0;
    my $buff;
    my $verbose = $et->Options('Verbose');
    my $buildMakerNotes = $et->Options('MakerNotes');

    # 4 bytes at end of block give directory position within block
    $raf->Seek($blockStart+$blockSize-4, 0) or return 0;
    $raf->Read($buff, 4) == 4 or return 0;
    my $dirOffset = Get32u(\$buff,0) + $blockStart;
    # avoid infinite recursion
    $$et{ProcessedCanonRaw} or $$et{ProcessedCanonRaw} = { };
    if ($$et{ProcessedCanonRaw}{$dirOffset}) {
        $et->Warn("Not processing double-referenced $$dirInfo{DirName} directory");
        return 0;
    }
    $$et{ProcessedCanonRaw}{$dirOffset} = 1;
    $raf->Seek($dirOffset, 0) or return 0;
    $raf->Read($buff, 2) == 2 or return 0;
    my $entries = Get16u(\$buff,0);         # get number of entries in directory
    # read the directory (10 bytes per entry)
    $raf->Read($buff, 10 * $entries) == 10 * $entries or return 0;

    $verbose and $et->VerboseDir('CIFF', $entries);
    my $index;
    for ($index=0; $index<$entries; ++$index) {
        my $pt = 10 * $index;
        my $tag = Get16u(\$buff, $pt);
        my $size = Get32u(\$buff, $pt+2);
        my $valuePtr = Get32u(\$buff, $pt+6);
        my $ptr = $valuePtr + $blockStart;  # all pointers relative to block start
        if ($tag & 0x8000) {
            $et->Warn('Bad CRW directory entry');
            return 1;
        }
        my $tagID = $tag & 0x3fff;          # get tag ID
        my $tagType = ($tag >> 8) & 0x38;   # get tag type
        my $valueInDir = ($tag & 0x4000);   # flag for value in directory
        my $tagInfo = $et->GetTagInfo($rawTagTable, $tagID);
        if (($tagType==0x28 or $tagType==0x30) and not $valueInDir) {
            # this type of tag specifies a raw subdirectory
            my $name;
            $tagInfo and $name = $$tagInfo{Name};
            $name or $name = sprintf("CanonRaw_0x%.4x", $tag);
            my %subdirInfo = (
                DirName  => $name,
                DataLen  => 0,
                DirStart => $ptr,
                DirLen   => $size,
                Nesting  => $$dirInfo{Nesting} + 1,
                RAF      => $raf,
                Parent   => $$dirInfo{DirName},
            );
            if ($verbose) {
                my $fakeInfo = { Name => $name, SubDirectory => { } };
                $et->VerboseInfo($tagID, $fakeInfo,
                    'Index'  => $index,
                    'Size'   => $size,
                    'Start'  => $ptr,
                );
            }
            $et->ProcessDirectory(\%subdirInfo, $rawTagTable);
            next;
        }
        my ($valueDataPos, $count, $subdir);
        my $format = $crwTagFormat{$tagType};
        if ($tagInfo) {
            $subdir = $$tagInfo{SubDirectory};
            $format = $$tagInfo{Format} if $$tagInfo{Format};
            $count = $$tagInfo{Count};
        }
        # get value data
        my ($value, $delRawConv);
        if ($valueInDir) {  # is the value data in the directory?
            # this type of tag stores the value in the 'size' and 'ptr' fields
            $valueDataPos = $dirOffset + $pt + 4; # (remember, +2 for the entry count)
            $size = 8;
            $value = substr($buff, $pt+2, $size);
            # set count to 1 by default for normal values in directory
            $count = 1 if not defined $count and $format and
                          $format ne 'string' and not $subdir;
        } else {
            $valueDataPos = $ptr;
            # do hash of image data if requested
            if ($$et{ImageDataHash} and $tagID == 0x2005) {
                $raf->Seek($ptr, 0) and $et->ImageDataHash($raf, $size, 'raw');
            }
            if ($size <= 512 or ($verbose > 2 and $size <= 65536)
                or ($tagInfo and ($$tagInfo{SubDirectory}
                or grep(/^$$tagInfo{Name}$/i, $et->GetRequestedTags()) )))
            {
                # read value if size is small or specifically requested
                # or if this is a SubDirectory
                unless ($raf->Seek($ptr, 0) and $raf->Read($value, $size) == $size) {
                    $et->Warn(sprintf("Error reading %d bytes from 0x%x",$size,$ptr));
                    next;
                }
            } else {
                $value = "Binary data $size bytes";
                if ($tagInfo) {
                    if ($et->Options('Binary') or $verbose) {
                        # read the value anyway
                        unless ($raf->Seek($ptr, 0) and $raf->Read($value, $size) == $size) {
                            $et->Warn(sprintf("Error reading %d bytes from 0x%x",$size,$ptr));
                            next;
                        }
                    }
                    # force this to be a binary (scalar reference)
                    $$tagInfo{RawConv} = '\$val';
                    $delRawConv = 1;
                }
                $size = length $value;
                undef $format;
            }
        }
        # set count from tagInfo count if necessary
        if ($format and not $count) {
            # set count according to format and size
            my $fnum = $Image::ExifTool::Exif::formatNumber{$format};
            my $fsiz = $Image::ExifTool::Exif::formatSize[$fnum];
            $count = int($size / $fsiz);
        }
        if ($verbose) {
            my $val = $value;
            $format and $val = ReadValue(\$val, 0, $format, $count, $size);
            $et->VerboseInfo($tagID, $tagInfo,
                Table   => $rawTagTable,
                Index   => $index,
                Value   => $val,
                DataPt  => \$value,
                DataPos => $valueDataPos,
                Size    => $size,
                Format  => $format,
                Count   => $count,
            );
        }
        if ($buildMakerNotes) {
            # build maker notes information if requested
            BuildMakerNotes($et, $tagID, $tagInfo, \$value, $format, $count);
        }
        next unless defined $tagInfo;

        if ($subdir) {
            my $name = $$tagInfo{Name};
            my $newTagTable;
            if ($$subdir{TagTable}) {
                $newTagTable = GetTagTable($$subdir{TagTable});
                unless ($newTagTable) {
                    warn "Unknown tag table $$subdir{TagTable}\n";
                    next;
                }
            } else {
                warn "Must specify TagTable for SubDirectory $name\n";
                next;
            }
            my $subdirStart = 0;
            #### eval Start ()
            $subdirStart = eval $$subdir{Start} if $$subdir{Start};
            my $dirData = \$value;
            my %subdirInfo = (
                Name     => $name,
                DataPt   => $dirData,
                DataLen  => $size,
                DataPos  => $valueDataPos,
                DirStart => $subdirStart,
                DirLen   => $size - $subdirStart,
                Nesting  => $$dirInfo{Nesting} + 1,
                RAF      => $raf,
                DirName  => $name,
                Parent   => $$dirInfo{DirName},
            );
            #### eval Validate ($dirData, $subdirStart, $size)
            if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                $et->Warn("Invalid $name data");
            } else {
                $et->ProcessDirectory(\%subdirInfo, $newTagTable, $$subdir{ProcessProc});
            }
        } else {
            # convert to specified format if necessary
            $format and $value = ReadValue(\$value, 0, $format, $count, $size);
            # save the information
            $et->FoundTag($tagInfo, $value);
            delete $$tagInfo{RawConv} if $delRawConv;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# get information from raw file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid Canon RAW file
sub ProcessCRW($$)
{
    my ($et, $dirInfo) = @_;
    my ($buff, $sig);
    my $raf = $$dirInfo{RAF};
    my $buildMakerNotes = $et->Options('MakerNotes');

    $raf->Read($buff,2) == 2      or return 0;
    SetByteOrder($buff)           or return 0;
    $raf->Read($buff,4) == 4      or return 0;
    $raf->Read($sig,8) == 8       or return 0;  # get file signature
    $sig =~ /^HEAP(CCDR|JPGM)/    or return 0;  # validate signature
    my $hlen = Get32u(\$buff, 0);

    $raf->Seek(0, 2)              or return 0;  # seek to end of file
    my $filesize = $raf->Tell()   or return 0;

    # initialize maker note data if building maker notes
    $buildMakerNotes and InitMakerNotes($et);

    # set the FileType tag unless already done (eg. APP0 CIFF record in JPEG image)
    $et->SetFileType();

    # build directory information for main raw directory
    my %dirInfo = (
        DataLen  => 0,
        DirStart => $hlen,
        DirLen   => $filesize - $hlen,
        Nesting  => 0,
        RAF      => $raf,
        Parent   => 'CRW',
    );

    # process the raw directory
    my $rawTagTable = GetTagTable('Image::ExifTool::CanonRaw::Main');
    my $oldIndent = $$et{INDENT};
    $$et{INDENT} .= '| ';
    unless (ProcessCanonRaw($et, \%dirInfo, $rawTagTable)) {
        $et->Warn('CRW file format error');
    }
    $$et{INDENT} = $oldIndent;

    # finish building maker notes if necessary
    $buildMakerNotes and SaveMakerNotes($et);

    # process trailers if they exist in CRW file (not in CIFF information!)
    if ($$et{FILE_TYPE} eq 'CRW') {
        my $trailInfo = Image::ExifTool::IdentifyTrailer($raf);
        $et->ProcessTrailers($trailInfo) if $trailInfo;
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::CanonRaw - Read Canon RAW (CRW) meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
meta information from Canon CRW raw files.  These files are written directly
by some Canon cameras, and contain meta information similar to that found in
the EXIF Canon maker notes.

=head1 NOTES

The CR2 format written by some Canon cameras is very different the CRW
format processed by this module.  (CR2 is TIFF-based and uses standard EXIF
tags.)

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://www.wonderland.org/crw/>

=item L<http://xyrion.org/ciff/>

=item L<https://exiftool.org/canon_raw.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Dave Nicholson for decoding a number of new tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/CanonRaw Tags>,
L<Image::ExifTool::Canon(3pm)|Image::ExifTool::Canon>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

