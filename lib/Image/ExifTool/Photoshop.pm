#------------------------------------------------------------------------------
# File:         Photoshop.pm
#
# Description:  Read/write Photoshop IRB meta information
#
# Revisions:    02/06/2004 - P. Harvey Created
#               02/25/2004 - P. Harvey Added hack for problem with old photoshops
#               10/04/2004 - P. Harvey Added a bunch of tags (ref Image::MetaData::JPEG)
#                            but left most of them commented out until I have enough
#                            information to write PrintConv routines for them to
#                            display something useful
#               07/08/2005 - P. Harvey Added support for reading PSD files
#               01/07/2006 - P. Harvey Added PSD write support
#               11/04/2006 - P. Harvey Added handling of resource name
#
# References:   1) http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf
#               2) http://www.ozhiker.com/electronics/pjmt/jpeg_info/irb_jpeg_qual.html
#               3) Matt Mueller private communication (tests with PS CS2)
#               4) http://www.fileformat.info/format/psd/egff.htm
#               5) http://www.telegraphics.com.au/svn/psdparse/trunk/resources.c
#               6) http://libpsd.graphest.com/files/Photoshop%20File%20Formats.pdf
#               7) http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
#------------------------------------------------------------------------------

package Image::ExifTool::Photoshop;

use strict;
use vars qw($VERSION $AUTOLOAD $iptcDigestInfo);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.49';

sub ProcessPhotoshop($$$);
sub WritePhotoshop($$$);
sub ProcessLayers($$$);

# map of where information is stored in PSD image
my %psdMap = (
    IPTC         => 'Photoshop',
    XMP          => 'Photoshop',
    EXIFInfo     => 'Photoshop',
    IFD0         => 'EXIFInfo',
    IFD1         => 'IFD0',
    ICC_Profile  => 'Photoshop',
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);

# tag information for PhotoshopThumbnail and PhotoshopBGRThumbnail
my %thumbnailInfo = (
    Writable => 'undef',
    Protected => 1,
    RawConv => 'my $img=substr($val,0x1c); $self->ValidateImage(\$img,$tag)',
    ValueConvInv => q{
        my $et = new Image::ExifTool;
        my @tags = qw{ImageWidth ImageHeight FileType};
        my $info = $et->ImageInfo(\$val, @tags);
        my ($w, $h, $type) = @$info{@tags};
        $w and $h and $type eq 'JPEG' or warn("Not a valid JPEG image\n"), return undef;
        my $wbytes = int(($w * 24 + 31) / 32) * 4;
        return pack('N6n2', 1, $w, $h, $wbytes, $wbytes * $h, length($val), 24, 1) . $val;
    },
);

# tag info to decode Photoshop Unicode string
my %unicodeString = (
    ValueConv => sub {
        my ($val, $et) = @_;
        return '<err>' if length($val) < 4;
        my $len = unpack('N', $val) * 2;
        return '<err>' if length($val) < 4 + $len;
        return $et->Decode(substr($val, 4, $len), 'UCS2', 'MM');
    },
    ValueConvInv => sub {
        my ($val, $et) = @_;
        return pack('N', length $val) . $et->Encode($val, 'UCS2', 'MM');
    },
);

# Photoshop APP13 tag table
# (set Unknown flag for information we don't want to display normally)
%Image::ExifTool::Photoshop::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessPhotoshop,
    WRITE_PROC => \&WritePhotoshop,
    0x03e8 => { Unknown => 1, Name => 'Photoshop2Info' },
    0x03e9 => { Unknown => 1, Name => 'MacintoshPrintInfo' },
    0x03ea => { Unknown => 1, Name => 'XMLData', Binary => 1 }, #PH
    0x03eb => { Unknown => 1, Name => 'Photoshop2ColorTable' },
    0x03ed => {
        Name => 'ResolutionInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Resolution',
        },
    },
    0x03ee => {
        Name => 'AlphaChannelsNames',
        ValueConv => 'Image::ExifTool::Photoshop::ConvertPascalString($self,$val)',
    },
    0x03ef => { Unknown => 1, Name => 'DisplayInfo' },
    0x03f0 => { Unknown => 1, Name => 'PStringCaption' },
    0x03f1 => { Unknown => 1, Name => 'BorderInformation' },
    0x03f2 => { Unknown => 1, Name => 'BackgroundColor' },
    0x03f3 => { Unknown => 1, Name => 'PrintFlags', Format => 'int8u' },
    0x03f4 => { Unknown => 1, Name => 'BW_HalftoningInfo' },
    0x03f5 => { Unknown => 1, Name => 'ColorHalftoningInfo' },
    0x03f6 => { Unknown => 1, Name => 'DuotoneHalftoningInfo' },
    0x03f7 => { Unknown => 1, Name => 'BW_TransferFunc' },
    0x03f8 => { Unknown => 1, Name => 'ColorTransferFuncs' },
    0x03f9 => { Unknown => 1, Name => 'DuotoneTransferFuncs' },
    0x03fa => { Unknown => 1, Name => 'DuotoneImageInfo' },
    0x03fb => { Unknown => 1, Name => 'EffectiveBW', Format => 'int8u' },
    0x03fc => { Unknown => 1, Name => 'ObsoletePhotoshopTag1' },
    0x03fd => { Unknown => 1, Name => 'EPSOptions' },
    0x03fe => { Unknown => 1, Name => 'QuickMaskInfo' },
    0x03ff => { Unknown => 1, Name => 'ObsoletePhotoshopTag2' },
    0x0400 => { Unknown => 1, Name => 'TargetLayerID', Format => 'int16u' }, # (LayerStateInfo)
    0x0401 => { Unknown => 1, Name => 'WorkingPath' },
    0x0402 => { Unknown => 1, Name => 'LayersGroupInfo', Format => 'int16u' },
    0x0403 => { Unknown => 1, Name => 'ObsoletePhotoshopTag3' },
    0x0404 => {
        Name => 'IPTCData',
        SubDirectory => {
            DirName => 'IPTC',
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x0405 => { Unknown => 1, Name => 'RawImageMode' },
    0x0406 => { #2
        Name => 'JPEG_Quality',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::JPEG_Quality',
        },
    },
    0x0408 => { Unknown => 1, Name => 'GridGuidesInfo' },
    0x0409 => {
        Name => 'PhotoshopBGRThumbnail',
        Notes => 'this is a JPEG image, but in BGR format instead of RGB',
        %thumbnailInfo,
        Groups => { 2 => 'Preview' },
    },
    0x040a => {
        Name => 'CopyrightFlag',
        Writable => 'int8u',
        Groups => { 2 => 'Author' },
        ValueConv => 'join(" ",unpack("C*", $val))',
        ValueConvInv => 'pack("C*",split(" ",$val))',
        PrintConv => { #3
            0 => 'False',
            1 => 'True',
        },
    },
    0x040b => {
        Name => 'URL',
        Writable => 'string',
        Groups => { 2 => 'Author' },
    },
    0x040c => {
        Name => 'PhotoshopThumbnail',
        %thumbnailInfo,
        Groups => { 2 => 'Preview' },
    },
    0x040d => {
        Name => 'GlobalAngle',
        Writable => 'int32u',
        ValueConv => 'unpack("N",$val)',
        ValueConvInv => 'pack("N",$val)',
    },
    0x040e => { Unknown => 1, Name => 'ColorSamplersResource' },
    0x040f => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0x0410 => { Unknown => 1, Name => 'Watermark', Format => 'int8u' },
    0x0411 => { Unknown => 1, Name => 'ICC_Untagged', Format => 'int8u' },
    0x0412 => { Unknown => 1, Name => 'EffectsVisible', Format => 'int8u' },
    0x0413 => { Unknown => 1, Name => 'SpotHalftone' },
    0x0414 => { Unknown => 1, Name => 'IDsBaseValue', Description => 'IDs Base Value', Format => 'int32u' },
    0x0415 => { Unknown => 1, Name => 'UnicodeAlphaNames' },
    0x0416 => { Unknown => 1, Name => 'IndexedColourTableCount', Format => 'int16u' },
    0x0417 => { Unknown => 1, Name => 'TransparentIndex', Format => 'int16u' },
    0x0419 => {
        Name => 'GlobalAltitude',
        Writable => 'int32u',
        ValueConv => 'unpack("N",$val)',
        ValueConvInv => 'pack("N",$val)',
    },
    0x041a => {
        Name => 'SliceInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::SliceInfo' },
    },
    0x041b => { Name => 'WorkflowURL', %unicodeString },
    0x041c => { Unknown => 1, Name => 'JumpToXPEP' },
    0x041d => { Unknown => 1, Name => 'AlphaIdentifiers' },
    0x041e => {
        Name => 'URL_List',
        List => 1,
        Writable => 1,
        ValueConv => sub {
            my ($val, $et) = @_;
            return '<err>' if length($val) < 4;
            my $num = unpack('N', $val);
            my ($i, @vals);
            my $pos = 4;
            for ($i=0; $i<$num; ++$i) {
                $pos += 8;  # (skip word and ID)
                last if length($val) < $pos + 4;
                my $len = unpack("x${pos}N", $val) * 2;
                last if length($val) < $pos + 4 + $len;
                push @vals, $et->Decode(substr($val,$pos+4,$len), 'UCS2', 'MM');
                $pos += 4 + $len;
            }
            return \@vals;
        },
        # (this is tricky to make writable)
    },
    0x0421 => {
        Name => 'VersionInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::VersionInfo',
        },
    },
    0x0422 => {
        Name => 'EXIFInfo', #PH (Found in EPS and PSD files)
        SubDirectory => {
            TagTable=> 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    0x0423 => { Unknown => 1, Name => 'ExifInfo2', Binary => 1 }, #5
    0x0424 => {
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    0x0425 => {
        Name => 'IPTCDigest',
        Writable => 'string',
        Protected => 1,
        Notes => q{
            this tag indicates provides a way for XMP-aware applications to indicate
            that the XMP is synchronized with the IPTC.  When writing, special values of
            "new" and "old" represent the digests of the IPTC from the edited and
            original files respectively, and are undefined if the IPTC does not exist in
            the respective file.  Set this to "new" as an indication that the XMP is
            synchronized with the IPTC
        },
        # also note the 'new' feature requires that the IPTC comes before this tag is written
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => q{
            if (lc($val) eq 'new' or lc($val) eq 'old') {
                {
                    local $SIG{'__WARN__'} = sub { };
                    return lc($val) if eval { require Digest::MD5 };
                }
                warn "Digest::MD5 must be installed\n";
                return undef;
            }
            return pack('H*', $val) if $val =~ /^[0-9a-f]{32}$/i;
            warn "Value must be 'new', 'old' or 32 hexadecimal digits\n";
            return undef;
        }
    },
    0x0426 => {
        Name => 'PrintScaleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::PrintScaleInfo' },
    },
    0x0428 => {
        Name => 'PixelInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::PixelInfo' },
    },
    0x0429 => { Unknown => 1, Name => 'LayerComps' }, #5
    0x042a => { Unknown => 1, Name => 'AlternateDuotoneColors' }, #5
    0x042b => { Unknown => 1, Name => 'AlternateSpotColors' }, #5
    0x042d => { #7
        Name => 'LayerSelectionIDs',
        Description => 'Layer Selection IDs',
        Unknown => 1,
        ValueConv => q{
            my ($n, @a) = unpack("nN*",$val);
            $#a = $n - 1 if $n > @a;
            return join(' ', @a);
        },
    },
    0x042e => { Unknown => 1, Name => 'HDRToningInfo' }, #7
    0x042f => { Unknown => 1, Name => 'PrintInfo' }, #7
    0x0430 => { Unknown => 1, Name => 'LayerGroupsEnabledID', Format => 'int8u' }, #7
    0x0431 => { Unknown => 1, Name => 'ColorSamplersResource2' }, #7
    0x0432 => { Unknown => 1, Name => 'MeasurementScale' }, #7
    0x0433 => { Unknown => 1, Name => 'TimelineInfo' }, #7
    0x0434 => { Unknown => 1, Name => 'SheetDisclosure' }, #7
    0x0435 => { Unknown => 1, Name => 'DisplayInfo' }, #7
    0x0436 => { Unknown => 1, Name => 'OnionSkins' }, #7
    0x0438 => { Unknown => 1, Name => 'CountInfo' }, #7
    0x043a => { Unknown => 1, Name => 'PrintInfo2' }, #7
    0x043b => { Unknown => 1, Name => 'PrintStyle' }, #7
    0x043c => { Unknown => 1, Name => 'MacintoshNSPrintInfo' }, #7
    0x043d => { Unknown => 1, Name => 'WindowsDEVMODE' }, #7
    0x043e => { Unknown => 1, Name => 'AutoSaveFilePath' }, #7
    0x043f => { Unknown => 1, Name => 'AutoSaveFormat' }, #7
    0x0440 => { Unknown => 1, Name => 'PathSelectionState' }, #7
    # 0x07d0-0x0bb6 Path information
    0x0bb7 => {
        Name => 'ClippingPathName',
        # convert from a Pascal string (ignoring 6 bytes of unknown data after string)
        ValueConv => q{
            my $len = ord($val);
            $val = substr($val, 0, $len+1) if $len < length($val);
            return Image::ExifTool::Photoshop::ConvertPascalString($self,$val);
        },
    },
    0x0bb8 => { Unknown => 1, Name => 'OriginPathInfo' }, #7
    # 0x0fa0-0x1387 - plug-in resources (ref 7)
    0x1b58 => { Unknown => 1, Name => 'ImageReadyVariables' }, #7
    0x1b59 => { Unknown => 1, Name => 'ImageReadyDataSets' }, #7
    0x1f40 => { Unknown => 1, Name => 'LightroomWorkflow' }, #7
    0x2710 => { Unknown => 1, Name => 'PrintFlagsInfo' },
);

# Photoshop JPEG quality record (ref 2)
%Image::ExifTool::Photoshop::JPEG_Quality = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int16s',
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'PhotoshopQuality',
        Writable => 1,
        PrintConv => '$val + 4',
        PrintConvInv => '$val - 4',
    },
    1 => {
        Name => 'PhotoshopFormat',
        PrintConv => {
            0x0000 => 'Standard',
            0x0001 => 'Optimized',
            0x0101 => 'Progressive',
        },
    },
    2 => {
        Name => 'ProgressiveScans',
        PrintConv => {
            1 => '3 Scans',
            2 => '4 Scans',
            3 => '5 Scans',
        },
    },
);

# Photoshop Slices
%Image::ExifTool::Photoshop::SliceInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    20 => { Name => 'SlicesGroupName', Format => 'var_ustr32' },
    24 => { Name => 'NumSlices',       Format => 'int32u' },
);

# Photoshop resolution information #PH
%Image::ExifTool::Photoshop::Resolution = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    WRITABLE => 1,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'XResolution',
        Format => 'int32u',
        Priority => 0,
        ValueConv => '$val / 0x10000',
        ValueConvInv => 'int($val * 0x10000 + 0.5)',
        PrintConv => 'int($val * 100 + 0.5) / 100',
        PrintConvInv => '$val',
    },
    2 => {
        Name => 'DisplayedUnitsX',
        PrintConv => {
            1 => 'inches',
            2 => 'cm',
        },
    },
    4 => {
        Name => 'YResolution',
        Format => 'int32u',
        Priority => 0,
        ValueConv => '$val / 0x10000',
        ValueConvInv => 'int($val * 0x10000 + 0.5)',
        PrintConv => 'int($val * 100 + 0.5) / 100',
        PrintConvInv => '$val',
    },
    6 => {
        Name => 'DisplayedUnitsY',
        PrintConv => {
            1 => 'inches',
            2 => 'cm',
        },
    },
);

# Photoshop version information
%Image::ExifTool::Photoshop::VersionInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FIRST_ENTRY => 0,
    GROUPS => { 2 => 'Image' },
    # (always 1) 0 => { Name => 'PhotoshopVersion', Format => 'int32u' },
    4 => { Name => 'HasRealMergedData', Format => 'int8u', PrintConv => { 0 => 'No', 1 => 'Yes' } },
    5 => { Name => 'WriterName', Format => 'var_ustr32' },
    9 => { Name => 'ReaderName', Format => 'var_ustr32' },
    # (always 1) 13 => { Name => 'FileVersion', Format => 'int32u' },
);

# Print Scale
%Image::ExifTool::Photoshop::PrintScaleInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FIRST_ENTRY => 0,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'PrintStyle',
        Format => 'int16u',
        PrintConv => {
            0 => 'Centered',
            1 => 'Size to Fit',
            2 => 'User Defined',
        },
    },
    2  => { Name => 'PrintPosition', Format => 'float[2]' },
    10 => { Name => 'PrintScale',    Format => 'float' },
);

# Pixel Aspect Ratio
%Image::ExifTool::Photoshop::PixelInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FIRST_ENTRY => 0,
    GROUPS => { 2 => 'Image' },
    # 0 - version
    4 => { Name => 'PixelAspectRatio', Format => 'double' },
);

# Photoshop PSD file header
%Image::ExifTool::Photoshop::Header = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    GROUPS => { 2 => 'Image' },
    NOTES => 'This information is found in the PSD file header.',
    6 => 'NumChannels',
    7 => { Name => 'ImageHeight', Format => 'int32u' },
    9 => { Name => 'ImageWidth', Format => 'int32u' },
    11 => 'BitDepth',
    12 => {
        Name => 'ColorMode',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Bitmap',
            1 => 'Grayscale',
            2 => 'Indexed',
            3 => 'RGB',
            4 => 'CMYK',
            7 => 'Multichannel',
            8 => 'Duotone',
            9 => 'Lab',
        },
    },
);

# Layer information
%Image::ExifTool::Photoshop::Layers = (
    PROCESS_PROC => \&ProcessLayers,
    GROUPS => { 2 => 'Image' },
    NOTES => 'Tags extracted from Photoshop layer information.',
    # tags extracted from layer information
    # (tag ID's are for convenience only)
    _xcnt => { Name => 'LayerCount' },
    _xrct => { Name => 'LayerRectangles', List => 1 },
    _xnam => { Name => 'LayerNames',      List => 1 },
    _xbnd => {
        Name => 'LayerBlendModes',
        List => 1,
        PrintConv => {
            pass => 'Pass Through',
            norm => 'Normal',
            diss => 'Dissolve',
            dark => 'Darken',
           'mul '=> 'Multiply',
            idiv => 'Color Burn',
            lbrn => 'Linear Burn',
            dkCl => 'Darker Color',
            lite => 'Lighten',
            scrn => 'Screen',
           'div '=> 'Color Dodge',
            lddg => 'Linear Dodge',
            lgCl => 'Lighter Color',
            over => 'Overlay',
            sLit => 'Soft Light',
            hLit => 'Hard Light',
            vLit => 'Vivid Light',
            lLit => 'Linear Light',
            pLit => 'Pin Light',
            hMix => 'Hard Mix',
            diff => 'Difference',
            smud => 'Exclusion',
            fsub => 'Subtract',
            fdiv => 'Divide',
           'hue '=> 'Hue',
           'sat '=> 'Saturation',
            colr => 'Color',
           'lum '=> 'Luminosity',
        },
    },
    _xopc  => { 
        Name => 'LayerOpacities',
        List => 1,
        ValueConv => '100 * $val / 255',
        PrintConv => 'sprintf("%d%%",$val)',
    },
    # tags extracted from additional layer information (tag ID's are real)
    # - must be able to accomodate a blank entry to preserve the list ordering
    luni => {
        Name => 'LayerUnicodeNames',
        List => 1,
        RawConv => q{
            return "" if length($val) < 4;
            my $len = Get32u(\$val, 0);
            return $self->Decode(substr($val, 4, $len * 2), 'UCS2');
        },
    },
);

# image data
%Image::ExifTool::Photoshop::ImageData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'Compression',
        Format => 'int16u',
        PrintConv => {
            0 => 'Uncompressed',
            1 => 'RLE',
            2 => 'ZIP without prediction',
            3 => 'ZIP with prediction',
        },
    },
);

# tags for unknown resource types
%Image::ExifTool::Photoshop::Unknown = (
    GROUPS => { 2 => 'Unknown' },
);

# define reference to IPTCDigest tagInfo hash for convenience
$iptcDigestInfo = $Image::ExifTool::Photoshop::Main{0x0425};


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Convert pascal string(s) to something we can use
# Inputs: 1) Pascal string data
# Returns: Strings, concatenated with ', '
sub ConvertPascalString($$)
{
    my ($et, $inStr) = @_;
    my $outStr = '';
    my $len = length($inStr);
    my $i=0;
    while ($i < $len) {
        my $n = ord(substr($inStr, $i, 1));
        last if $i + $n >= $len;
        $i and $outStr .= ', ';
        $outStr .= substr($inStr, $i+1, $n);
        $i += $n + 1;
    }
    my $charset = $et->Options('CharsetPhotoshop') || 'Latin';
    return $et->Decode($outStr, $charset);
}

#------------------------------------------------------------------------------
# Process Photoshop layers and mask information
# Inputs: 0) ExifTool ref, 1) DirInfo ref, 2) tag table ref
# Returns: 1 on success (and seeks to the end of this section)
sub ProcessLayers($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $fileType = $$et{VALUE}{FileType};
    my ($i, $data, %count);

    return 0 unless $fileType eq 'PSD' or $fileType eq 'PSB';   # (no layer section in CS1 files)

    # (some words are 4 bytes in PSD files and 8 bytes in PSB)
    my ($psb, $psiz) = $fileType eq 'PSB' ? (1, 8) : (undef, 4);

    # read the layer information header
    my $n = $psiz * 2 + 2;
    $raf->Read($data, $n) == $n or return 0;
    my $tot = $psb ? Get64u(\$data, 0) : Get32u(\$data, 0); # length of layer and mask info
    my $len = $psb ? Get64u(\$data, $psiz) : Get32u(\$data, $psiz); # length of layer info section
    $et->VerboseDir('Layers', 0, $len);
    my $num = Get16u(\$data, $psiz * 2);
    $num = -$num if $num < 0;       # (first channel is transparency data if negative)
    $et->HandleTag($tagTablePtr, _xcnt => $num); # LayerCount
    return 0 if $len > 100000000;   # set a reasonable limit on maximum size
    my $dataPos = $raf->Tell();
    # read the layer information data
    $raf->Read($data, $len) == $len or return 0;

    my $pos = 0;
    for ($i=0; $i<$num; ++$i) {
        last if $pos + 18 > $len;
        # save the layer rectangle
        $et->HandleTag($tagTablePtr, _xrct => join(' ',ReadValue(\$data, $pos, 'int32u', 4, 16)));
        my $numChannels = Get16u(\$data, $pos + 16);
        $pos += 18 + (2 + $psiz) * $numChannels;    # skip the channel information
        last if $pos + 20 > $len or substr($data, $pos, 4) ne '8BIM'; # verify signature
        $et->HandleTag($tagTablePtr, _xbnd => substr($data, $pos+4, 4)); # blend mode
        $et->HandleTag($tagTablePtr, _xopc => Get8u(\$data, $pos+8));    # opacity
        my $nxt = $pos + 16 + Get32u(\$data, $pos + 12);
        $n = Get32u(\$data, $pos+16);   # get size of layer mask data
        $pos += 20 + $n;                # skip layer mask data
        last if $pos + 4 > $len;
        $n = Get32u(\$data, $pos);      # get size of layer blending ranges
        $pos += 4 + $n;                 # skip layer blanding ranges data
        last if $pos + 1 > $len;
        $n = Get8u(\$data, $pos);       # get length of layer name
        last if $pos + 1 + $n > $len;
        $et->HandleTag($tagTablePtr, _xnam => substr($data, $pos+1, $n)); # layer name
        $n = ($n + 3) & 0xfffffffc;
        $pos += $n;
        # process additional layer info
        while ($pos + 12 <= $nxt) {
            my $sig = substr($data, $pos, 4);
            last unless $sig eq '8BIM' or $sig eq '8B64';   # verify signature
            my $tag = substr($data, $pos+4, 4);
            # (some structures have an 8-byte size word [augh!]
            # --> it would be great if '8B64' indicated a 64-bit version, and this may well
            # be the case, but it is not mentioned in the Photoshop file format specification)
            if ($psb and $tag =~ /^(LMsk|Lr16|Lr32|Layr|Mt16|Mt32|Mtrn|Alph|FMsk|lnk2|FEid|FXid|PxSD)$/) {
                last if $pos + 16 > $nxt;
                $n = Get64u(\$data, $pos+8);
                $pos += 4;
            } else {
                $n = Get32u(\$data, $pos+8);
            }
            $pos += 12;
            last if $pos + $n > $nxt;
            my $val = substr($data, $pos, $n);
            # pad with empty entries if necessary to keep the same index for each item in the layer
            $count{$tag} = 0 unless defined $count{$tag};
            while ($count{$tag} < $i) {
                $et->HandleTag($tagTablePtr, $tag, '');
                ++$count{$tag};
            }
            $et->HandleTag($tagTablePtr, $tag, $val,
                DataPt => \$val,
                DataPos => $dataPos + $pos,
            );
            ++$count{$tag};
            $pos += $n; # step to start of next structure
        }
        $pos = $nxt;
    }
    # seek to the end of this section
    return 0 unless $raf->Seek($dataPos - 2 - $psiz + $tot, 0);
    return 1;   # success!
}

#------------------------------------------------------------------------------
# Process Photoshop APP13 record
# Inputs: 0) ExifTool object reference, 1) Reference to directory information
#         2) Tag table reference
# Returns: 1 on success
sub ProcessPhotoshop($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $dirEnd = $pos + $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');
    my $success = 0;

    SetByteOrder('MM');     # Photoshop is always big-endian
    $verbose and $et->VerboseDir('Photoshop', 0, $$dirInfo{DirLen});

    # scan through resource blocks:
    # Format: 0) Type, 4 bytes - '8BIM' (or the rare 'PHUT', 'DCSR' or 'AgHg')
    #         1) TagID,2 bytes
    #         2) Name, pascal string padded to even no. bytes
    #         3) Size, 4 bytes - N
    #         4) Data, N bytes
    while ($pos + 8 < $dirEnd) {
        my $type = substr($$dataPt, $pos, 4);
        my ($ttPtr, $extra, $val, $name);
        if ($type eq '8BIM') {
            $ttPtr = $tagTablePtr;
        } elsif ($type =~ /^(PHUT|DCSR|AgHg)$/) {
            $ttPtr = GetTagTable('Image::ExifTool::Photoshop::Unknown');
        } else {
            $type =~ s/([^\w])/sprintf("\\x%.2x",ord($1))/ge;
            $et->Warn(qq{Bad Photoshop IRB resource "$type"});
            last;
        }
        my $tag = Get16u($dataPt, $pos + 4);
        $pos += 6;  # point to start of name
        my $nameLen = Get8u($dataPt, $pos);
        my $namePos = ++$pos;
        # skip resource block name (pascal string, padded to an even # of bytes)
        $pos += $nameLen;
        ++$pos unless $nameLen & 0x01;
        if ($pos + 4 > $dirEnd) {
            $et->Warn("Bad Photoshop resource block");
            last;
        }
        my $size = Get32u($dataPt, $pos);
        $pos += 4;
        if ($size + $pos > $dirEnd) {
            $et->Warn("Bad Photoshop resource data size $size");
            last;
        }
        $success = 1;
        if ($nameLen) {
            $name = substr($$dataPt, $namePos, $nameLen);
            $extra = qq{, Name="$name"};
        } else {
            $name = '';
        }
        my $tagInfo = $et->GetTagInfo($ttPtr, $tag);
        # append resource name to value if requested (braced by "/#...#/")
        if ($tagInfo and defined $$tagInfo{SetResourceName} and
            $$tagInfo{SetResourceName} eq '1' and $name !~ m{/#})
        {
            $val = substr($$dataPt, $pos, $size) . '/#' . $name . '#/';
        }
        $et->HandleTag($ttPtr, $tag, $val,
            TagInfo => $tagInfo,
            Extra   => $extra,
            DataPt  => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Size    => $size,
            Start   => $pos,
            Parent  => $$dirInfo{DirName},
        );
        $size += 1 if $size & 0x01; # size is padded to an even # bytes
        $pos += $size;
    }
    return $success;
}

#------------------------------------------------------------------------------
# extract information from Photoshop PSD file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid PSD file, -1 on write error
sub ProcessPSD($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my ($data, $err, $tagTablePtr);

    $raf->Read($data, 30) == 30 or return 0;
    $data =~ /^8BPS\0([\x01\x02])/ or return 0;
    SetByteOrder('MM');
    $et->SetFileType($1 eq "\x01" ? 'PSD' : 'PSB'); # set the FileType tag
    my %dirInfo = (
        DataPt => \$data,
        DirStart => 0,
        DirName => 'Photoshop',
    );
    my $len = Get32u(\$data, 26);
    if ($outfile) {
        Write($outfile, $data) or $err = 1;
        $raf->Read($data, $len) == $len or return -1;
        Write($outfile, $data) or $err = 1; # write color mode data
        # initialize map of where things are written
        $et->InitWriteDirs(\%psdMap);
    } else {
        # process the header
        $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Header');
        $dirInfo{DirLen} = 30;
        $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        $raf->Seek($len, 1) or $err = 1;    # skip over color mode data
    }
    # read image resource section
    $raf->Read($data, 4) == 4 or $err = 1;
    $len = Get32u(\$data, 0);
    $raf->Read($data, $len) == $len or $err = 1;
    $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
    $dirInfo{DirLen} = $len;
    my $rtnVal = 1;
    if ($outfile) {
        # rewrite IRB resources
        $data = WritePhotoshop($et, \%dirInfo, $tagTablePtr);
        if ($data) {
            $len = Set32u(length $data);
            Write($outfile, $len, $data) or $err = 1;
            # look for trailer and edit if necessary
            my $trailInfo = Image::ExifTool::IdentifyTrailer($raf);
            if ($trailInfo) {
                my $tbuf = '';
                $$trailInfo{OutFile} = \$tbuf;  # rewrite trailer(s)
                # rewrite all trailers to buffer
                if ($et->ProcessTrailers($trailInfo)) {
                    my $copyBytes = $$trailInfo{DataPos} - $raf->Tell();
                    if ($copyBytes >= 0) {
                        # copy remaining PSD file up to start of trailer
                        while ($copyBytes) {
                            my $n = ($copyBytes > 65536) ? 65536 : $copyBytes;
                            $raf->Read($data, $n) == $n or $err = 1;
                            Write($outfile, $data) or $err = 1;
                            $copyBytes -= $n;
                        }
                        # write the trailer (or not)
                        $et->WriteTrailerBuffer($trailInfo, $outfile) or $err = 1;
                    } else {
                        $et->Warn('Overlapping trailer');
                        undef $trailInfo;
                    }
                } else {
                    undef $trailInfo;
                }
            }
            unless ($trailInfo) {
                # copy over the rest of the file
                while ($raf->Read($data, 65536)) {
                    Write($outfile, $data) or $err = 1;
                }
            }
        } else {
            $err = 1;
        }
        $rtnVal = -1 if $err;
    } elsif ($err) {
        $et->Warn('File format error');
    } else {
        # read IRB resources
        ProcessPhotoshop($et, \%dirInfo, $tagTablePtr);
        # read layer and mask information section
        $dirInfo{RAF} = $raf;
        $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Layers');
        if (ProcessLayers($et, \%dirInfo, $tagTablePtr) and
            # read compression mode from image data section
            $raf->Read($data,2) == 2)
        {
            my %dirInfo = (
                DataPt  => \$data,
                DataPos => $raf->Tell() - 2,
            );
            $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::ImageData');
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
        # process trailers if they exist
        my $trailInfo = Image::ExifTool::IdentifyTrailer($raf);
        $et->ProcessTrailers($trailInfo) if $trailInfo;
    }
    return $rtnVal;
}

1; # end


__END__

=head1 NAME

Image::ExifTool::Photoshop - Read/write Photoshop IRB meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

Photoshop writes its own format of meta information called a Photoshop IRB
resource which is located in the APP13 record of JPEG files.  This module
contains the definitions to read this information.

=head1 NOTES

Photoshop IRB blocks may have an associated resource name.  These names are
usually just an empty string, but if not empty they are displayed in the
verbose level 2 (or greater) output.  A special C<SetResourceName> flag may
be set to '1' in the tag information hash to cause the resource name to be
appended to the value when extracted.  If this is done, the returned value
has the form "VALUE/#NAME#/".  When writing, the writer routine looks for
this syntax (if C<SetResourceName> is defined), and and uses the embedded
name to set the name of the new resource.  This allows the resource names to
be preserved when copying Photoshop information via user-defined tags.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/irb_jpeg_qual.html>

=item L<http://www.fileformat.info/format/psd/egff.htm>

=item L<http://libpsd.graphest.com/files/Photoshop%20File%20Formats.pdf>

=item L<http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Photoshop Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::MetaData::JPEG(3pm)|Image::MetaData::JPEG>

=cut
