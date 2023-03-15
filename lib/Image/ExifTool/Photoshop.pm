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
use vars qw($VERSION $AUTOLOAD $iptcDigestInfo %printFlags);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.69';

sub ProcessPhotoshop($$$);
sub WritePhotoshop($$$);
sub ProcessLayers($$$);

# PrintFlags bit definitions (ref forum13785)
%printFlags = (
    0 => 'Labels',
    1 => 'Corner crop marks',
    2 => 'Color bars', # (deprecated)
    3 => 'Registration marks',
    4 => 'Negative',
    5 => 'Emulsion down',
    6 => 'Interpolate', # (deprecated)
    7 => 'Description',
    8 => 'Print flags',
);

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
        $w and $h and $type and $type eq 'JPEG' or warn("Not a valid JPEG image\n"), return undef;
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
    0x03f3 => {
        Unknown => 1,
        Name => 'PrintFlags',
        Format => 'int8u',
        PrintConv => q{
            my $byte = 0;
            my @bits = $val =~ /\d+/g;
            $byte = ($byte << 1) | ($_ ? 1 : 0) foreach reverse @bits;
            return DecodeBits($byte, \%Image::ExifTool::Photoshop::printFlags);
        },
    },
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
    0x0416 => { Unknown => 1, Name => 'IndexedColorTableCount', Format => 'int16u' },
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
            that the XMP is synchronized with the IPTC.  The MWG recommendation is to
            ignore the XMP if IPTCDigest exists and doesn't match the CurrentIPTCDigest.
            When writing, special values of "new" and "old" represent the digests of the
            IPTC from the edited and original files respectively, and are undefined if
            the IPTC does not exist in the respective file.  Set this to "new" as an
            indication that the XMP is synchronized with the IPTC
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
    DATAMEMBER => [ 1 ],
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
        RawConv => '$$self{PhotoshopFormat} = $val',
        PrintConv => {
            0x0000 => 'Standard',
            0x0001 => 'Optimized',
            0x0101 => 'Progressive',
        },
    },
    2 => {
        Name => 'ProgressiveScans',
        Condition => '$$self{PhotoshopFormat} == 0x0101',
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
    _xcnt => { Name => 'LayerCount', Format => 'int16u' },
    _xrct => {
        Name => 'LayerRectangles',
        Format => 'int32u',
        Count => 4,
        List => 1,
        Notes => 'top left bottom right',
    },
    _xnam => { Name => 'LayerNames',
        Format => 'string',
        List => 1,
        ValueConv => q{
            my $charset = $self->Options('CharsetPhotoshop') || 'Latin';
            return $self->Decode($val, $charset);
        },
    },
    _xbnd => {
        Name => 'LayerBlendModes',
        Format => 'undef',
        List => 1,
        RawConv => 'GetByteOrder() eq "II" ? pack "N*", unpack "V*", $val : $val',
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
        Format => 'int8u',
        List => 1,
        ValueConv => '100 * $val / 255',
        PrintConv => 'sprintf("%d%%",$val)',
    },
    _xvis  => {
        Name => 'LayerVisible',
        Format => 'int8u',
        List => 1,
        ValueConv => '$val & 0x02',
        PrintConv => { 0x02 => 'No', 0x00 => 'Yes' },
    },
    # tags extracted from additional layer information (tag ID's are real)
    # - must be able to accommodate a blank entry to preserve the list ordering
    luni => {
        Name => 'LayerUnicodeNames',
        List => 1,
        RawConv => q{
            return '' if length($val) < 4;
            my $len = Get32u(\$val, 0);
            return $self->Decode(substr($val, 4, $len * 2), 'UCS2');
        },
    },
    lyid => {
        Name => 'LayerIDs',
        Description => 'Layer IDs',
        Format => 'int32u',
        List => 1,
        Unknown => 1,
    },
    lclr => {
        Name => 'LayerColors',
        Format => 'int16u',
        Count => 1,
        List => 1,
        PrintConv => {
            0=>'None',  1=>'Red',  2=>'Orange', 3=>'Yellow',
            4=>'Green', 5=>'Blue', 6=>'Violet', 7=>'Gray',
        },
    },
    shmd => { # layer metadata (undocumented structure)
        # (for now, only extract layerTime.  May also contain "layerXMP" --
        #  it would be nice to decode this but I need a sample)
        Name => 'LayerModifyDates',
        Groups => { 2 => 'Time' },
        List => 1,
        RawConv => q{
            return '' unless $val =~ /layerTime(doub|buod)(.{8})/s;
            my $tmp = $2;
            return GetDouble(\$tmp, 0);
        },
        ValueConv => 'length $val ? ConvertUnixTime($val,1) : ""',
        PrintConv => 'length $val ? $self->ConvertDateTime($val) : ""',
    },
    lsct => {
        Name => 'LayerSections',
        Format => 'int32u',
        Count => 1,
        List => 1,
        PrintConv => { 0 => 'Layer', 1 => 'Folder (open)', 2 => 'Folder (closed)', 3 => 'Divider' },
    },
);

# tags extracted from ImageSourceData found in TIFF images (ref PH)
%Image::ExifTool::Photoshop::DocumentData = (
    PROCESS_PROC => \&ProcessDocumentData,
    GROUPS => { 2 => 'Image' },
    Layr => {
        Name => 'Layers',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::Layers' },
    },
    Lr16 => { # (NC)
        Name => 'Layers',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::Layers' },
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
# Process Photoshop layers and mask information section of PSD/PSB file
# Inputs: 0) ExifTool ref, 1) DirInfo ref, 2) tag table ref
# Returns: 1 on success (and seeks to the end of this section)
sub ProcessLayersAndMask($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $fileType = $$et{FileType};
    my $data;

    return 0 unless $fileType eq 'PSD' or $fileType eq 'PSB';   # (no layer section in CS1 files)

    # (some words are 4 bytes in PSD files and 8 bytes in PSB)
    my ($psb, $psiz) = $fileType eq 'PSB' ? (1, 8) : (undef, 4);

    # read the layer information header
    my $n = $psiz * 2 + 2;
    $raf->Read($data, $n) == $n or return 0;
    my $tot = $psb ? Get64u(\$data, 0) : Get32u(\$data, 0); # length of layer and mask info
    return 1 if $tot == 0;
    my $end = $raf->Tell() - $psiz - 2 + $tot;
    $data = substr $data, $psiz;
    my $len = $psb ? Get64u(\$data, 0) : Get32u(\$data, 0); # length of layer info section
    my $num = Get16s(\$data, $psiz);
    # check for Lr16 block if layers length is 0 (ref https://forums.adobe.com/thread/1540914)
    if ($len == 0 and $num == 0) {
        $raf->Read($data,10) == 10 or return 0;
        if ($data =~ /^..8BIMLr16/s) {
            $raf->Read($data, $psiz+2) == $psiz+2 or return 0;
            $len = $psb ? Get64u(\$data, 0) : Get32u(\$data, 0);
        } elsif ($data =~ /^..8BIMMt16/s) { # (have seen Mt16 before Lr16, ref PH)
            $raf->Read($data, $psiz) == $psiz or return 0;
            $raf->Read($data, 8) == 8 or return 0;
            if ($data eq '8BIMLr16') {
                $raf->Read($data, $psiz+2) == $psiz+2 or return 0;
                $len = $psb ? Get64u(\$data, 0) : Get32u(\$data, 0);
            } else {
                $raf->Seek(-18-$psiz, 1) or return 0;
            }
        } else {
            $raf->Seek(-10, 1) or return 0;
        }
    }
    $len += 2;  # include layer count with layer info section
    $raf->Seek(-2, 1) or return 0;
    my %dinfo = (
        RAF => $raf,
        DirLen => $len,
    );
    $$et{IsPSB} = $psb; # set PSB flag
    ProcessLayers($et, \%dinfo, $tagTablePtr);

    # seek to the end of this section and return success flag
    return $raf->Seek($end, 0) ? 1 : 0;
}

#------------------------------------------------------------------------------
# Process Photoshop layers (beginning with layer count)
# Inputs: 0) ExifTool ref, 1) DirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: Uses ExifTool IsPSB member to determine whether file is PSB format
sub ProcessLayers($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my ($i, $n, %count, $buff, $buf2);
    my $raf = $$dirInfo{RAF};
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $$et{OPTIONS}{Verbose};
    my %dinfo = ( DataPt => \$buff, Base => $raf->Tell() );
    my $pos = 0;
    return 0 if $dirLen < 2;
    $raf->Read($buff, 2) == 2 or return 0;
    my $num = Get16s(\$buff, 0);    # number of layers
    $num = -$num if $num < 0;       # (first channel is transparency data if negative)
    $et->VerboseDir('Layers', $num, $dirLen);
    $et->HandleTag($tagTablePtr, '_xcnt', $num, Start => $pos, Size => 2, %dinfo); # LayerCount
    my $oldIndent = $$et{INDENT};
    $$et{INDENT} .= '| ';
    $pos += 2;
    my $psb = $$et{IsPSB};  # is PSB format?
    my $psiz = $psb ? 8 : 4;
    for ($i=0; $i<$num; ++$i) { # process each layer
        $et->VPrint(0, $oldIndent.'+ [Layer '.($i+1)." of $num]\n");
        last if $pos + 18 > $dirLen;
        $raf->Read($buff, 18) == 18 or last;
        $dinfo{DataPos} = $pos;
        # save the layer rectangle
        $et->HandleTag($tagTablePtr, '_xrct', undef, Start => 0, Size => 16, %dinfo);
        my $numChannels = Get16u(\$buff, 16);
        $n = (2 + $psiz) * $numChannels;    # size of channel information
        $raf->Seek($n, 1) or last;
        $pos += 18 + $n;
        last if $pos + 20 > $dirLen;
        $raf->Read($buff, 20) == 20 or last;
        $dinfo{DataPos} = $pos;
        my $sig = substr($buff, 0, 4);
        $sig =~ /^(8BIM|MIB8)$/ or last;    # verify signature
        $et->HandleTag($tagTablePtr, '_xbnd', undef, Start => 4, Size => 4, %dinfo);
        $et->HandleTag($tagTablePtr, '_xopc', undef, Start => 8, Size => 1, %dinfo);
        $et->HandleTag($tagTablePtr, '_xvis', undef, Start =>10, Size => 1, %dinfo);
        my $nxt = $pos + 16 + Get32u(\$buff, 12);
        $n = Get32u(\$buff, 16);        # get size of layer mask data
        $pos += 20 + $n;                # skip layer mask data
        last if $pos + 4 > $dirLen;
        $raf->Seek($n, 1) and $raf->Read($buff, 4) == 4 or last;
        $n = Get32u(\$buff, 0);         # get size of layer blending ranges
        $pos += 4 + $n;                 # skip layer blending ranges data
        last if $pos + 1 > $dirLen;
        $raf->Seek($n, 1) and $raf->Read($buff, 1) == 1 or last;
        $n = Get8u(\$buff, 0);          # get length of layer name
        last if $pos + 1 + $n > $dirLen;
        $raf->Read($buff, $n) == $n or last;
        $dinfo{DataPos} = $pos + 1;
        $et->HandleTag($tagTablePtr, '_xnam', undef, Start => 0, Size => $n, %dinfo);
        my $frag = ($n + 1) & 0x3;
        $raf->Seek(4 - $frag, 1) or last if $frag;
        $n = ($n + 4) & 0xfffffffc;     # +1 for length byte then pad to multiple of 4 bytes
        $pos += $n;
        # process additional layer info
        while ($pos + 12 <= $nxt) {
            $raf->Read($buff, 12) == 12 or last;
            my $dat = substr($buff, 0, 8);
            $dat = pack 'N*', unpack 'V*', $dat if GetByteOrder() eq 'II';
            my $sig = substr($dat, 0, 4);
            last unless $sig eq '8BIM' or $sig eq '8B64';   # verify signature
            my $tag = substr($dat, 4, 4);
            # (some structures have an 8-byte size word [augh!]
            # --> it would be great if '8B64' indicated a 64-bit version, and this may well
            # be the case, but it is not mentioned in the Photoshop file format specification)
            if ($psb and $tag =~ /^(LMsk|Lr16|Lr32|Layr|Mt16|Mt32|Mtrn|Alph|FMsk|lnk2|FEid|FXid|PxSD)$/) {
                last if $pos + 16 > $nxt;
                $raf->Read($buf2, 4) == 4 or last;
                $buff .= $buf2;
                $n = Get64u(\$buff, 8);
                $pos += 4;
            } else {
                $n = Get32u(\$buff, 8);
            }
            $pos += 12;
            last if $pos + $n > $nxt;
            $frag = $n & 0x3;
            if ($$tagTablePtr{$tag} or $verbose) {
                # pad with empty entries if necessary to keep the same index for each item in the layer
                $count{$tag} = 0 unless defined $count{$tag};
                $raf->Read($buff, $n) == $n or last;
                $dinfo{DataPos} = $pos;
                while ($count{$tag} < $i) {
                    $et->HandleTag($tagTablePtr, $tag, $tag eq 'lsct' ? 0 : '');
                    ++$count{$tag};
                }
                $et->HandleTag($tagTablePtr, $tag, undef, Start => 0, Size => $n, %dinfo);
                ++$count{$tag};
                if ($frag) {
                    $raf->Seek(4 - $frag, 1) or last;
                    $n += 4 - $frag;    # pad to multiple of 4 bytes (PH NC)
                }
            } else {
                $n += 4 - $frag if $frag;
                $raf->Seek($n, 1) or last;
            }
            $pos += $n; # step to start of next structure
        }
        $pos = $nxt;
    }
    # pad lists if necessary to have an entry for each layer
    foreach (sort keys %count) {
        while ($count{$_} < $num) {
            $et->HandleTag($tagTablePtr, $_, $_ eq 'lsct' ? 0 : '');
            ++$count{$_};
        }
    }
    $$et{INDENT} = $oldIndent;
    return 1;
}

#------------------------------------------------------------------------------
# Process Photoshop ImageSourceData
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessDocumentData($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $verbose = $$et{OPTIONS}{Verbose};
    my $raf = $$dirInfo{RAF};
    my $dirLen = $$dirInfo{DirLen};
    my $pos = 36;   # length of header
    my ($buff, $n, $err);

    $et->VerboseDir('Photoshop Document Data', undef, $dirLen);
    unless ($raf) {
        my $dataPt = $$dirInfo{DataPt};
        my $start = $$dirInfo{DirStart} || 0;
        $raf = new File::RandomAccess($dataPt);
        $raf->Seek($start, 0) if $start;
        $dirLen = length $$dataPt - $start unless defined $dirLen;
        $et->VerboseDump($dataPt, Start => $start, Len => $dirLen, Base => $$dirInfo{Base});
    }
    unless ($raf->Read($buff, $pos) == $pos and
            $buff =~ /^Adobe Photoshop Document Data (Block|V0002)\0/)
    {
        $et->Warn('Invalid Photoshop Document Data');
        return 0;
    }
    my $psb = ($1 eq 'V0002');
    my %dinfo = ( DataPt => \$buff );
    $$et{IsPSB} = $psb; # set PSB flag (needed when handling Layers directory)
    while ($pos + 12 <= $dirLen) {
        $raf->Read($buff, 8) == 8 or $err = 'Error reading document data', last;
        # set byte order according to byte order of first signature
        SetByteOrder($buff =~ /^(8BIM|8B64)/ ? 'MM' : 'II') if $pos == 36;
        $buff = pack 'N*', unpack 'V*', $buff if GetByteOrder() eq 'II';
        my $sig = substr($buff, 0, 4);
        $sig eq '8BIM' or $sig eq '8B64' or $err = 'Bad photoshop resource', last; # verify signature
        my $tag = substr($buff, 4, 4);
        if ($psb and $tag =~ /^(LMsk|Lr16|Lr32|Layr|Mt16|Mt32|Mtrn|Alph|FMsk|lnk2|FEid|FXid|PxSD)$/) {
            $pos + 16 > $dirLen and $err = 'Short PSB resource', last;
            $raf->Read($buff, 8) == 8 or $err = 'Error reading PSB resource', last;
            $n = Get64u(\$buff, 0);
            $pos += 4;
        } else {
            $raf->Read($buff, 4) == 4 or $err = 'Error reading PSD resource', last;
            $n = Get32u(\$buff, 0);
        }
        $pos += 12;
        $pos + $n > $dirLen and $err = 'Truncated photoshop resource', last;
        my $pad = (4 - ($n & 3)) & 3;   # number of padding bytes
        my $tagInfo = $$tagTablePtr{$tag};
        if ($tagInfo or $verbose) {
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                my $fpos = $raf->Tell() + $n + $pad;
                my $subTable = GetTagTable($$tagInfo{SubDirectory}{TagTable});
                $et->ProcessDirectory({ RAF => $raf, DirLen => $n }, $subTable);
                $raf->Seek($fpos, 0) or $err = 'Seek error', last;
            } else {
                $dinfo{DataPos} = $raf->Tell();
                $dinfo{Start} = 0;
                $dinfo{Size} = $n;
                $raf->Read($buff, $n) == $n or $err = 'Error reading photoshop resource', last;
                $et->HandleTag($tagTablePtr, $tag, undef, %dinfo);
                $raf->Seek($pad, 1) or $err = 'Seek error', last;
            }
        } else {
            $raf->Seek($n + $pad, 1) or $err = 'Seek error', last;
        }
        $pos += $n + $pad;              # step to start of next structure
    }
    $err and $et->Warn($err);
    return 1;
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

    # ignore non-standard XMP while in strict MWG compatibility mode
    if (($Image::ExifTool::MWG::strict or $et->Options('Validate')) and
        $$et{FILE_TYPE} =~ /^(JPEG|TIFF|PSD)$/)
    {
        my $path = $et->MetadataPath();
        unless ($path =~ /^(JPEG-APP13-Photoshop|TIFF-IFD0-Photoshop|PSD)$/) {
            if ($Image::ExifTool::MWG::strict) {
                $et->Warn("Ignored non-standard Photoshop at $path");
                return 1;
            } else {
                $et->Warn("Non-standard Photoshop at $path", 1);
            }
        }
    }
    if ($$et{FILE_TYPE} eq 'JPEG' and $$dirInfo{Parent} ne 'APP13') {
        $$et{LOW_PRIORITY_DIR}{'*'} = 1;    # lower priority of all these tags
    }
    SetByteOrder('MM');     # Photoshop is always big-endian
    $verbose and $et->VerboseDir('Photoshop', 0, $$dirInfo{DirLen});

    # scan through resource blocks:
    # Format: 0) Type, 4 bytes - '8BIM' (or the rare 'PHUT', 'DCSR', 'AgHg' or 'MeSa')
    #         1) TagID,2 bytes
    #         2) Name, pascal string padded to even no. bytes
    #         3) Size, 4 bytes - N
    #         4) Data, N bytes
    while ($pos + 8 < $dirEnd) {
        my $type = substr($$dataPt, $pos, 4);
        my ($ttPtr, $extra, $val, $name);
        if ($type eq '8BIM') {
            $ttPtr = $tagTablePtr;
        } elsif ($type =~ /^(PHUT|DCSR|AgHg|MeSa)$/) { # (PHUT~ImageReady, MeSa~PhotoDeluxe)
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
            Base    => $$dirInfo{Base},
            Parent  => $$dirInfo{DirName},
        );
        $size += 1 if $size & 0x01; # size is padded to an even # bytes
        $pos += $size;
    }
    # warn about incorrect IPTCDigest
    if ($$et{VALUE}{IPTCDigest} and $$et{VALUE}{CurrentIPTCDigest} and
        $$et{VALUE}{IPTCDigest} ne $$et{VALUE}{CurrentIPTCDigest})
    {
        $et->WarnOnce('IPTCDigest is not current. XMP may be out of sync');
    }
    delete $$et{LOW_PRIORITY_DIR}{'*'};
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
        my $oldIndent = $$et{INDENT};
        $$et{INDENT} .= '| ';
        if (ProcessLayersAndMask($et, \%dirInfo, $tagTablePtr) and
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
        $$et{INDENT} = $oldIndent;
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

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

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
