#------------------------------------------------------------------------------
# File:         PICT.pm
#
# Description:  Read PICT meta information
#
# Revisions:    10/10/2005 - P. Harvey Created
#
# Notes:        Extraction of PICT opcodes is still experimental
#
# - size difference in PixPat color table?? (imagemagick reads only 1 long per entry)
# - other differences in the way imagemagick reads 16-bit images
#
# References:   1) http://developer.apple.com/documentation/mac/QuickDraw/QuickDraw-2.html
#               2) http://developer.apple.com/documentation/QuickTime/INMAC/QT/iqImageCompMgr.a.htm
#------------------------------------------------------------------------------

package Image::ExifTool::PICT;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.05';

sub ReadPictValue($$$;$);

my ($vers, $extended);  # PICT version number, and extended flag
my ($verbose, $out, $indent); # used in verbose mode

# ranges of reserved opcodes.
# opcodes at the start of each range must be defined in the tag table
my @reserved = (
    0x0017 => 0x0019, 0x0024 => 0x0027, 0x0035 => 0x0037, 0x003d => 0x003f,
    0x0045 => 0x0047, 0x004d => 0x004f, 0x0055 => 0x0057, 0x005d => 0x005f,
    0x0065 => 0x0067, 0x006d => 0x006f, 0x0075 => 0x0077, 0x007d => 0x007f,
    0x0085 => 0x0087, 0x008d => 0x008f, 0x0092 => 0x0097, 0x00a2 => 0x00af,
    0x00b0 => 0x00cf, 0x00d0 => 0x00fe, 0x0100 => 0x01ff, 0x0300 => 0x0bfe,
    0x0c01 => 0x7eff, 0x7f00 => 0x7fff, 0x8000 => 0x80ff, 0x8100 => 0x81ff,
    0x8201 => 0xffff,
);

# Apple data structures in PICT images
my %structs = (
    Arc => [
        rect => 'Rect',
        startAng => 'int16s',
        arcAng => 'int16s',
    ],
    BitMap => [
        # (no baseAddr)
        rowBytes => 'int16u',
        bounds => 'Rect',
    ],
    # BitsRect data for PICT version 1
    BitsRect1 => [
        bitMap => 'BitMap',
        srcRect => 'Rect',
        dstRect => 'Rect',
        mode => 'int16u',
        dataSize => 'int16u',
        bitData => 'binary[$val{dataSize}]',
    ],
    # BitsRect data for PICT version 2
    BitsRect2 => [
        pixMap => 'PixMap',
        colorTable => 'ColorTable',
        srcRect => 'Rect',
        dstRect => 'Rect',
        mode => 'int16u',
        pixData => \ 'GetPixData($val{pixMap}, $raf)',
    ],
    # BitsRgn data for PICT version 1
    BitsRgn1 => [
        bitMap => 'BitMap',
        srcRect => 'Rect',
        dstRect => 'Rect',
        mode => 'int16u',
        maskRgn => 'Rgn',
        dataSize => 'int16u',
        bitData => 'binary[$val{dataSize}]',
    ],
    # BitsRgn data for PICT version 2
    BitsRgn2 => [
        pixMap => 'PixMap',
        colorTable => 'ColorTable',
        srcRect => 'Rect',
        dstRect => 'Rect',
        mode => 'int16u',
        maskRgn => 'Rgn',
        pixData => \ 'GetPixData($val{pixMap}, $raf)',
    ],
    ColorSpec => [
        value => 'int16u',
        rgb => 'RGBColor',
    ],
    ColorTable => [
        ctSeed => 'int32u',
        ctFlags => 'int16u',
        ctSize => 'int16u',
        ctTable => 'ColorSpec[$val{ctSize}+1]',
    ],
    # http://developer.apple.com/documentation/QuickTime/INMAC/QT/iqImageCompMgr.a.htm
    CompressedQuickTime => [
        size => 'int32u',   # size NOT including size word
        version => 'int16u',
        matrix => 'int32u[9]',
        matteSize => 'int32u',
        matteRect => 'Rect',
        mode => 'int16u',
        srcRect => 'Rect',
        accuracy => 'int32u',
        maskSize => 'int32u',
        matteDescr => 'Int32uData[$val{matteSize} ? 1 : 0]',
        matteData => 'int8u[$val{matteSize}]',
        maskRgn => 'int8u[$val{maskSize}]',
        imageDescr => 'ImageDescription',
        # size should be $val{imageDescr}->{dataSize}, but this is unreliable
        imageData => q{binary[$val{size} - 68 - $val{maskSize} - $val{imageDescr}->{size} -
                    ($val{matteSize} ? $val{mattSize} + $val{matteDescr}->{size} : 0)]
        },
    ],
    DirectBitsRect => [
        baseAddr => 'int32u',
        pixMap => 'PixMap',
        srcRect => 'Rect',
        dstRect => 'Rect',
        mode => 'int16u',
        pixData => \ 'GetPixData($val{pixMap}, $raf)',
    ],
    DirectBitsRgn => [
        baseAddr => 'int32u',
        pixMap => 'PixMap',
        srcRect => 'Rect',
        dstRect => 'Rect',
        mode => 'int16u',
        maskRgn => 'Rgn',
        pixData => \ 'GetPixData($val{pixMap}, $raf)',
    ],
    # http://developer.apple.com/technotes/qd/qd_01.html
    FontName => [
        size => 'int16u',   # size NOT including size word
        oldFontID => 'int16u',
        nameLen => 'int8u',
        fontName => 'string[$val{nameLen}]',
        padding => 'binary[$val{size} - $val{nameLen} - 3]',
    ],
    # http://developer.apple.com/documentation/QuickTime/APIREF/imagedescription.htm
    ImageDescription => [
        size => 'int32u',   # size INCLUDING size word
        cType => 'string[4]',
        res1 => 'int32u',
        res2 => 'int16u',
        dataRefIndex => 'int16u',
        version => 'int16u',
        revision => 'int16u',
        vendor => 'string[4]',
        temporalQuality => 'int32u',
        quality => 'int32u',
        width => 'int16u',
        height => 'int16u',
        hRes => 'fixed32u',
        vRes => 'fixed32u',
        dataSize => 'int32u',
        frameCount => 'int16u',
        nameLen => 'int8u',
        compressor => 'string[31]',
        depth => 'int16u',
        clutID => 'int16u',
        clutData => 'binary[$val{size}-86]',
    ],
    Int8uText => [
        val => 'int8u',
        count => 'int8u',
        text => 'string[$val{count}]',
    ],
    Int8u2Text => [
        val => 'int8u[2]',
        count => 'int8u',
        text => 'string[$val{count}]',
    ],
    Int16Data => [
        size => 'int16u',   # size NOT including size word
        data => 'int8u[$val{size}]',
    ],
    Int32uData => [
        size => 'int32u',   # size NOT including size word
        data => 'int8u[$val{size}]',
    ],
    LongComment => [
        kind => 'int16u',
        size => 'int16u',   # size of data only
        data => 'binary[$val{size}]',
    ],
    PixMap => [
        # Note: does not contain baseAddr
        # (except for DirectBits opcodes in which it is loaded separately)
        rowBytes => 'int16u',
        bounds => 'Rect',
        pmVersion => 'int16u',
        packType => 'int16u',
        packSize => 'int32u',
        hRes => 'fixed32s',
        vRes => 'fixed32s',
        pixelType => 'int16u',
        pixelSize => 'int16u',
        cmpCount => 'int16u',
        cmpSize => 'int16u',
        planeBytes => 'int32u',
        pmTable => 'int32u',
        pmReserved => 'int32u',
    ],
    PixPat => [
        patType => 'int16u',    # 1 = non-dithered, 2 = dithered
        pat1Data => 'int8u[8]',
        # dithered PixPat has RGB entry
        RGB => 'RGBColor[$val{patType} == 2 ? 1 : 0]',
        # non-dithered PixPat has other stuff instead
        nonDithered=> 'PixPatNonDithered[$val{patType} == 2 ? 0 : 1]',
    ],
    PixPatNonDithered => [
        pixMap => 'PixMap',
        colorTable => 'ColorTable',
        pixData => \ 'GetPixData($val{pixMap}, $raf)',
    ],
    Point => [
        v => 'int16s',
        h => 'int16s',
    ],
    PointText => [
        txLoc => 'Point',
        count => 'int8u',
        text => 'string[$val{count}]',
    ],
    Polygon => [
        polySize => 'int16u',
        polyBBox => 'Rect',
        polyPoints => 'int16u[($val{polySize}-10)/2]',
    ],
    Rect => [
        topLeft => 'Point',
        botRight => 'Point',
    ],
    RGBColor => [
        red => 'int16u',
        green => 'int16u',
        blue => 'int16u',
    ],
    Rgn => [
        rgnSize => 'int16u',
        rgnBBox => 'Rect',
        data => 'int8u[$val{rgnSize}-10]',
    ],
    ShortLine => [
        pnLoc => 'Point',
        dh => 'int8s',
        dv => 'int8s',
    ],
    # http://developer.apple.com/documentation/QuickTime/INMAC/QT/iqImageCompMgr.a.htm
    UncompressedQuickTime => [
        size => 'int32u',   # size NOT including size word
        version => 'int16u',
        matrix => 'int32u[9]',
        matteSize => 'int32u',
        matteRect => 'Rect',
        matteDescr => 'Int32uData[$val{matteSize} ? 1 : 0]',
        matteData => 'binary[$val{matteSize}]',
        subOpcodeData => q{
            binary[ $val{size} - 50 -
                    ($val{matteSize} ? $val{mattSize} + $val{matteDescr}->{size} : 0)]
        },
    ],
);

# PICT image opcodes
%Image::ExifTool::PICT::Main = (
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => q{
The PICT format contains no true meta information, except for the possible
exception of the LongComment opcode.  By default, only ImageWidth,
ImageHeight and X/YResolution are extracted from a PICT image.  Tags in the
following table represent image opcodes.  Extraction of these tags is
experimental, and is only enabled with the Verbose or Unknown options.
    },
    0x0000 => {
        Name => 'Nop',
        Description => 'No Operation',
        Format => 'null',
    },
    0x0001 => {
        Name => 'ClipRgn',
        Description => 'Clipping Region',
        Format => 'Rgn',
    },
    0x0002 => {
        Name => 'BkPat',
        Description => 'Background Pattern',
        Format => 'int8u[8]',
    },
    0x0003 => {
        Name => 'TxFont',
        Description => 'Font Number',
        Format => 'int16u',
    },
    0x0004 => {
        Name => 'TxFace',
        Description => 'Text Font Style',
        Format => 'int8u',
    },
    0x0005 => {
        Name => 'TxMode',
        Description => 'Text Source Mode',
        Format => 'int16u',
    },
    0x0006 => {
        Name => 'SpExtra',
        Description => 'Extra Space',
        Format => 'fixed32s',
    },
    0x0007 => {
        Name => 'PnSize',
        Description => 'Pen Size',
        Format => 'Point',
    },
    0x0008 => {
        Name => 'PnMode',
        Description => 'Pen Mode',
        Format => 'int16u',
    },
    0x0009 => {
        Name => 'PnPat',
        Description => 'Pen Pattern',
        Format => 'int8u[8]',
    },
    0x000a => {
        Name => 'FillPat',
        Description => 'Fill Pattern',
        Format => 'int8u[8]',
    },
    0x000b => {
        Name => 'OvSize',
        Description => 'Oval Size',
        Format => 'Point',
    },
    0x000c => {
        Name => 'Origin',
        Format => 'Point',
    },
    0x000d => {
        Name => 'TxSize',
        Description => 'Text Size',
        Format => 'int16u',
    },
    0x000e => {
        Name => 'FgColor',
        Description => 'Foreground Color',
        Format => 'int32u',
    },
    0x000f => {
        Name => 'BkColor',
        Description => 'Background Color',
        Format => 'int32u',
    },
    0x0010 => {
        Name => 'TxRatio',
        Description => 'Text Ratio',
        Format => 'Rect',
    },
    0x0011 => {
        Name => 'VersionOp',
        Description => 'Version',
        Format => 'int8u',
    },
    0x0012 => {
        Name => 'BkPixPat',
        Description => 'Background Pixel Pattern',
        Format => 'PixPat',
    },
    0x0013 => {
        Name => 'PnPixPat',
        Description => 'Pen Pixel Pattern',
        Format => 'PixPat',
    },
    0x0014 => {
        Name => 'FillPixPat',
        Description => 'Fill Pixel Pattern',
        Format => 'PixPat',
    },
    0x0015 => {
        Name => 'PnLocHFrac',
        Description => 'Fractional Pen Position',
        Format => 'int16u',
    },
    0x0016 => {
        Name => 'ChExtra',
        Description => 'Added Width for NonSpace Characters',
        Format => 'int16u',
    },
    0x0017 => {
        Name => 'Reserved',
        Format => 'Unknown',
    },
    0x001a => {
        Name => 'RGBFgCol',
        Description => 'Foreground Color',
        Format => 'RGBColor',
    },
    0x001b => {
        Name => 'RGBBkCol',
        Description => 'Background Color',
        Format => 'RGBColor',
    },
    0x001c => {
        Name => 'HiliteMode',
        Description => 'Highlight Mode Flag',
        Format => 'null',
    },
    0x001d => {
        Name => 'HiliteColor',
        Description => 'Highlight Color',
        Format => 'RGBColor',
    },
    0x001e => {
        Name => 'DefHilite',
        Description => 'Use Default Highlight Color',
        Format => 'null',
    },
    0x001f => {
        Name => 'OpColor',
        Format => 'RGBColor',
    },
    0x0020 => {
        Name => 'Line',
        Format => 'Rect',
    },
    0x0021 => {
        Name => 'LineFrom',
        Format => 'Point',
    },
    0x0022 => {
        Name => 'ShortLine',
        Format => 'ShortLine',
    },
    0x0023 => {
        Name => 'ShortLineFrom',
        Format => 'int8u[2]',
    },
    0x0024 => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x0028 => {
        Name => 'LongText',
        Format => 'PointText',
    },
    0x0029 => {
        Name => 'DHText',
        Format => 'Int8uText',
    },
    0x002a => {
        Name => 'DVText',
        Format => 'Int8uText',
    },
    0x002b => {
        Name => 'DHDVText',
        Format => 'Int8u2Text',
    },
    0x002c => {
        Name => 'FontName',
        Format => 'FontName',
    },
    0x002d => {
        Name => 'LineJustify',
        Format => 'int8u[10]',
    },
    0x002e => {
        Name => 'GlyphState',
        Format => 'int8u[8]',
    },
    0x002f => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x0030 => {
        Name => 'FrameRect',
        Format => 'Rect',
    },
    0x0031 => {
        Name => 'PaintRect',
        Format => 'Rect',
    },
    0x0032 => {
        Name => 'EraseRect',
        Format => 'Rect',
    },
    0x0033 => {
        Name => 'InvertRect',
        Format => 'Rect',
    },
    0x0034 => {
        Name => 'FillRect',
        Format => 'Rect',
    },
    0x0035 => {
        Name => 'Reserved',
        Format => 'Rect',
    },
    0x0038 => {
        Name => 'FrameSameRect',
        Format => 'null',
    },
    0x0039 => {
        Name => 'PaintSameRect',
        Format => 'null',
    },
    0x003a => {
        Name => 'EraseSameRect',
        Format => 'null',
    },
    0x003b => {
        Name => 'InvertSameRect',
        Format => 'null',
    },
    0x003c => {
        Name => 'FillSameRect',
        Format => 'null',
    },
    0x003d => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x0040 => {
        Name => 'FrameRRect',
        Format => 'Rect',
    },
    0x0041 => {
        Name => 'PaintRRect',
        Format => 'Rect',
    },
    0x0042 => {
        Name => 'EraseRRect',
        Format => 'Rect',
    },
    0x0043 => {
        Name => 'InvertRRect',
        Format => 'Rect',
    },
    0x0044 => {
        Name => 'FillRRect',
        Format => 'Rect',
    },
    0x0045 => {
        Name => 'Reserved',
        Format => 'Rect',
    },
    0x0048 => {
        Name => 'FrameSameRRect',
        Format => 'null',
    },
    0x0049 => {
        Name => 'PaintSameRRect',
        Format => 'null',
    },
    0x004a => {
        Name => 'EraseSameRRect',
        Format => 'null',
    },
    0x004b => {
        Name => 'InvertSameRRect',
        Format => 'null',
    },
    0x004c => {
        Name => 'FillSameRRect',
        Format => 'null',
    },
    0x004d => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x0050 => {
        Name => 'FrameOval',
        Format => 'Rect',
    },
    0x0051 => {
        Name => 'PaintOval',
        Format => 'Rect',
    },
    0x0052 => {
        Name => 'EraseOval',
        Format => 'Rect',
    },
    0x0053 => {
        Name => 'InvertOval',
        Format => 'Rect',
    },
    0x0054 => {
        Name => 'FillOval',
        Format => 'Rect',
    },
    0x0055 => {
        Name => 'Reserved',
        Format => 'Rect',
    },
    0x0058 => {
        Name => 'FrameSameOval',
        Format => 'null',
    },
    0x0059 => {
        Name => 'PaintSameOval',
        Format => 'null',
    },
    0x005a => {
        Name => 'EraseSameOval',
        Format => 'null',
    },
    0x005b => {
        Name => 'InvertSameOval',
        Format => 'null',
    },
    0x005c => {
        Name => 'FillSameOval',
        Format => 'null',
    },
    0x005d => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x0060 => {
        Name => 'FrameArc',
        Format => 'Arc',
    },
    0x0061 => {
        Name => 'PaintArc',
        Format => 'Arc',
    },
    0x0062 => {
        Name => 'EraseArc',
        Format => 'Arc',
    },
    0x0063 => {
        Name => 'InvertArc',
        Format => 'Arc',
    },
    0x0064 => {
        Name => 'FillArc',
        Format => 'Arc',
    },
    0x0065 => {
        Name => 'Reserved',
        Format => 'Arc',
    },
    0x0068 => {
        Name => 'FrameSameArc',
        Format => 'Point',
    },
    0x0069 => {
        Name => 'PaintSameArc',
        Format => 'Point',
    },
    0x006a => {
        Name => 'EraseSameArc',
        Format => 'Point',
    },
    0x006b => {
        Name => 'InvertSameArc',
        Format => 'Point',
    },
    0x006c => {
        Name => 'FillSameArc',
        Format => 'Point',
    },
    0x006d => {
        Name => 'Reserved',
        Format => 'int32u',
    },
    0x0070 => {
        Name => 'FramePoly',
        Format => 'Polygon',
    },
    0x0071 => {
        Name => 'PaintPoly',
        Format => 'Polygon',
    },
    0x0072 => {
        Name => 'ErasePoly',
        Format => 'Polygon',
    },
    0x0073 => {
        Name => 'InvertPoly',
        Format => 'Polygon',
    },
    0x0074 => {
        Name => 'FillPoly',
        Format => 'Polygon',
    },
    0x0075 => {
        Name => 'Reserved',
        Format => 'Polygon',
    },
    0x0078 => {
        Name => 'FrameSamePoly',
        Format => 'null',
    },
    0x0079 => {
        Name => 'PaintSamePoly',
        Format => 'null',
    },
    0x007a => {
        Name => 'EraseSamePoly',
        Format => 'null',
    },
    0x007b => {
        Name => 'InvertSamePoly',
        Format => 'null',
    },
    0x007c => {
        Name => 'FillSamePoly',
        Format => 'null',
    },
    0x007d => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x0080 => {
        Name => 'FrameRgn',
        Format => 'Rgn',
    },
    0x0081 => {
        Name => 'PaintRgn',
        Format => 'Rgn',
    },
    0x0082 => {
        Name => 'EraseRgn',
        Format => 'Rgn',
    },
    0x0083 => {
        Name => 'InvertRgn',
        Format => 'Rgn',
    },
    0x0084 => {
        Name => 'FillRgn',
        Format => 'Rgn',
    },
    0x0085 => {
        Name => 'Reserved',
        Format => 'Rgn',
    },
    0x0088 => {
        Name => 'FrameSameRgn',
        Format => 'null',
    },
    0x0089 => {
        Name => 'PaintSameRgn',
        Format => 'null',
    },
    0x008a => {
        Name => 'EraseSameRgn',
        Format => 'null',
    },
    0x008b => {
        Name => 'InvertSameRgn',
        Format => 'null',
    },
    0x008c => {
        Name => 'FillSameRgn',
        Format => 'null',
    },
    0x008d => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x0090 => {
        Name => 'BitsRect',
        Description => 'CopyBits with Clipped Rectangle',
        Format => 'BitsRect#',  # (version-dependent format)
    },
    0x0091 => {
        Name => 'BitsRgn',
        Description => 'CopyBits with Clipped Region',
        Format => 'BitsRgn#',   # (version-dependent format)
    },
    0x0092 => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x0098 => {
        Name => 'PackBitsRect',
        Description => 'Packed CopyBits with Clipped Rectangle',
        Format => 'BitsRect#',  # (version-dependent format)
    },
    0x0099 => {
        Name => 'PackBitsRgn',
        Description => 'Packed CopyBits with Clipped Region',
        Format => 'BitsRgn#',   # (version-dependent format)
    },
    0x009a => {
        Name => 'DirectBitsRect',
        Format => 'DirectBitsRect',
    },
    0x009b => {
        Name => 'DirectBitsRgn',
        Format => 'DirectBitsRgn',
    },
    0x009c => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x009d => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x009e => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x009f => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x00a0 => {
        Name => 'ShortComment',
        Format => 'int16u',
    },
    0x00a1 => [
        # this list for documentation only [currently not extracted]
        {
            # (not actually a full Photohop IRB record it appears, but it does start
            #  with '8BIM', and does contain resolution information at offset 0x0a)
            Name => 'LongComment',  # kind = 498
            Format => 'LongComment',
            SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::Main' },
        },
        {
            Name => 'LongComment',  # kind = 224
            Format => 'LongComment',
            SubDirectory => {
                TagTable => 'Image::ExifTool::ICC_Profile::Main',
                Start => '$valuePtr + 4',
            },
        },
    ],
    0x00a2 => {
        Name => 'Reserved',
        Format => 'Int16Data',
    },
    0x00b0 => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x00d0 => {
        Name => 'Reserved',
        Format => 'Int32uData',
    },
    0x00ff => {
        Name => 'OpEndPic',
        Description => 'End of picture',
        Format => 'null', # 2 for version 2!?
    },
    0x0100 => {
        Name => 'Reserved',
        Format => 'int16u',
    },
    0x0200 => {
        Name => 'Reserved',
        Format => 'int32u',
    },
    0x02ff => {
        Name => 'Version',
        Description => 'Version number of picture',
        Format => 'int16u',
    },
    0x0300 => {
        Name => 'Reserved',
        Format => 'int16u',
    },
    0x0bff => {
        Name => 'Reserved',
        Format => 'int8u[22]',
    },
    0x0c00 => {
        Name => 'HeaderOp',
        Format => 'int16u[12]',
    },
    0x0c01 => {
        Name => 'Reserved',
        Format => 'int8u[24]',
    },
    0x7f00 => {
        Name => 'Reserved',
        Format => 'int8u[254]',
    },
    0x8000 => {
        Name => 'Reserved',
        Format => 'null',
    },
    0x8100 => {
        Name => 'Reserved',
        Format => 'Int32uData',
    },
    0x8200 => {
        Name => 'CompressedQuickTime',
        Format => 'CompressedQuickTime',
    },
    0x8201 => {
        Name => 'UncompressedQuickTime',
        Format => 'Int32uData',
    },
    0xffff => {
        Name => 'Reserved',
        Format => 'Int32uData',
    },
);

# picture comment 'kind' codes
# http://developer.apple.com/technotes/qd/qd_10.html
my %commentKind = (
    150 => 'TextBegin',
    151 => 'TextEnd',
    152 => 'StringBegin',
    153 => 'StringEnd',
    154 => 'TextCenter',
    155 => 'LineLayoutOff',
    156 => 'LineLayoutOn',
    157 => 'ClientLineLayout',
    160 => 'PolyBegin',
    161 => 'PolyEnd',
    163 => 'PolyIgnore',
    164 => 'PolySmooth',
    165 => 'PolyClose',
    180 => 'DashedLine',
    181 => 'DashedStop',
    182 => 'SetLineWidth',
    190 => 'PostScriptBegin',
    191 => 'PostScriptEnd',
    192 => 'PostScriptHandle',
    193 => 'PostScriptFile',
    194 => 'TextIsPostScript',
    195 => 'ResourcePS',
    196 => 'PSBeginNoSave',
    197 => 'SetGrayLevel',
    200 => 'RotateBegin',
    201 => 'RotateEnd',
    202 => 'RotateCenter',
    210 => 'FormsPrinting',
    211 => 'EndFormsPrinting',
    224 => '<ICC Profile>',
    498 => '<Photoshop Data>',
    1000 => 'BitMapThinningOff',
    1001 => 'BitMapThinningOn',
);

#------------------------------------------------------------------------------
# Get PixData data
# Inputs: 0) reference to PixMap, 1) RAF reference
# Returns: reference to PixData or undef on error
sub GetPixData($$)
{
    my ($pixMap, $raf) = @_;
    my $packType = $pixMap->{packType};
    my $rowBytes = $pixMap->{rowBytes} & 0x3fff;    # remove flags bits
    my $height = $pixMap->{bounds}->{botRight}->{v} -
                 $pixMap->{bounds}->{topLeft}->{v};
    my ($data, $size, $buff, $i);

    if ($packType == 1 or $rowBytes < 8) {  # unpacked data
        $size = $rowBytes * $height;
        return undef unless $raf->Read($data, $size) == $size;
    } elsif ($packType == 2) {              # pad byte dropped
        $size = int($rowBytes * $height * 3 / 4 + 0.5);
        return undef unless $raf->Read($data, $size) == $size;
    } else {
        $data = '';
        for ($i=0; $i<$height; ++$i) {
            if ($rowBytes > 250) {
                $raf->Read($buff,2) == 2 or return undef;
                $size = unpack('n',$buff);
            } else {
                $raf->Read($buff,1) == 1 or return undef;
                $size = unpack('C',$buff);
            }
            $data .= $buff;
            $raf->Read($buff,$size) == $size or return undef;
            $data .= $buff;
        }
    }
    return \$data;
}

#------------------------------------------------------------------------------
# Read value from PICT file
# Inputs: 0) RAF reference, 1) tag, 2) format, 3) optional count
# Returns: value, reference to structure hash, or undef on error
sub ReadPictValue($$$;$)
{
    my ($raf, $tag, $format, $count) = @_;
    return undef unless $format;
    unless (defined $count) {
        if ($format =~ /(.+)\[(.+)\]/s) {
            $format = $1;
            $count = $2;
        } else {
            $count = 1; # count undefined: assume 1
        }
    }
    my $cntStr = ($count == 1) ? '' : "[$count]";
    # no size if count is 0
    my $size = $count ? Image::ExifTool::FormatSize($format) : 0;
    if (defined $size or $format eq 'null') {
        my $val;
        if ($size) {
            my $buff;
            $size *= $count;
            $raf->Read($buff, $size) == $size or return undef;
            $val = ReadValue(\$buff, 0, $format, $count, $size);
        } else {
            $val = '';
        }
        if ($verbose) {
            print $out "${indent}$tag ($format$cntStr)";
            if ($size) {
                if (not defined $val) {
                    print $out " = <undef>\n";
                } elsif ($format eq 'binary') {
                    print $out " = <binary data>\n";
                    if ($verbose > 2) {
                        my %parms = ( Out => $out );
                        $parms{MaxLen} = 96 if $verbose < 4;
                        HexDump(\$val, undef, %parms);
                    }
                } else {
                    print $out " = $val\n";
                }
            } else {
                print $out "\n";
            }
        }
        return \$val if $format eq 'binary' and defined $val;
        return $val;
    }
    $verbose and print $out "${indent}$tag ($format$cntStr):\n";
    my $struct = $structs{$format} or return undef;
    my ($c, @vals);
    for ($c=0; $c<$count; ++$c) {
        my (%val, $i);
        for ($i=0; ; $i+=2) {
            my $tag = $$struct[$i] or last;
            my $fmt = $$struct[$i+1];
            my ($cnt, $val);
            $indent .= '  ';
            if (ref $fmt) {
                $val = eval $$fmt;
                $@ and warn $@;
                if ($verbose and defined $val) {
                    printf $out "${indent}$tag (binary[%d]) = <binary data>\n",length($$val);
                    if ($verbose > 2) {
                        my %parms = ( Out => $out );
                        $parms{MaxLen} = 96 if $verbose < 4;
                        HexDump($val, undef, %parms);
                    }
                }
            } elsif ($fmt =~ /(.+)\[(.+)\]/s) {
                $fmt = $1;
                $cnt = eval $2;
                $@ and warn $@;
                $val = ReadPictValue($raf, $tag, $fmt, $cnt);
            } else {
                $val = ReadPictValue($raf, $tag, $fmt);
            }
            $indent = substr($indent, 2);
            return undef unless defined $val;
            $val{$tag} = $val;
        }
        return \%val if $count == 1;
        push @vals, \%val;
    }
    return \@vals;
}

#------------------------------------------------------------------------------
# Extract meta information from a PICT image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PICT image
sub ProcessPICT($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    $verbose = $et->Options('Verbose');
    $out = $et->Options('TextOut');
    $indent = '';
    my ($buff, $tried, @hdr, $op, $hRes, $vRes);

    # recognize both PICT files and PICT resources (PICT files have a
    # 512-byte header that we ignore, but PICT resources do not)
    for (;;) {
        $raf->Read($buff, 12) == 12 or return 0;
        @hdr = unpack('x2n5', $buff);
        $op = pop @hdr;
        # check for PICT version 1 format
        if ($op == 0x1101) {
            $vers = 1;
            undef $extended;
            last;
        }
        # check for PICT version 2 format
        if ($op == 0x0011) {
            $raf->Read($buff, 28) == 28 or return 0;
            if ($buff =~ /^\x02\xff\x0c\x00\xff\xff/) {
                $vers = 2;
                undef $extended;
                last;
            }
            if ($buff =~ /^\x02\xff\x0c\x00\xff\xfe/) {
                $vers = 2;
                $extended = 1;
                ($hRes, $vRes) = unpack('x8N2', $buff);
                last;
            }
        }
        return 0 if $tried;
        $tried = 1;
        $raf->Seek(512, 0) or return 0;
    }
    # make the bounding rect signed
    foreach (@hdr) {
        $_ >= 0x8000 and $_ -= 0x10000;
    }
    my $w = $hdr[3] - $hdr[1];
    my $h = $hdr[2] - $hdr[0];
    return 0 unless $w > 0 and $h > 0;

    SetByteOrder('MM');

    if ($extended) {
        # extended version 2 pictures contain resolution information
        # and image bounds are in 72-dpi equivalent units
        $hRes = GetFixed32s(\$buff, 8);
        $vRes = GetFixed32s(\$buff, 12);
        return 0 unless $hRes and $vRes;
        $w = int($w * $hRes / 72 + 0.5);
        $h = int($h * $vRes / 72 + 0.5);
    }
    $et->SetFileType();
    $et->FoundTag('ImageWidth', $w);
    $et->FoundTag('ImageHeight', $h);
    $et->FoundTag('XResolution', $hRes) if $hRes;
    $et->FoundTag('YResolution', $vRes) if $vRes;

    # don't extract image opcodes unless verbose
    return 1 unless $verbose or $et->Options('Unknown');

    $verbose and printf $out "PICT version $vers%s\n", $extended ? ' extended' : '';

    my $tagTablePtr = GetTagTable('Image::ExifTool::PICT::Main');

    my $success;
    for (;;) {
        if ($vers == 1) {
            $raf->Read($buff, 1) == 1 or last;
            $op = ord($buff);
        } else {
            # must start version 2 opcode on an even byte
            $raf->Read($buff, 1) if $raf->Tell() & 0x01;
            $raf->Read($buff, 2) == 2 or last;
            $op = unpack('n', $buff);
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $op);
        unless ($tagInfo) {
            my $i;
            # search for reserved tag info
            for ($i=0; $i<scalar(@reserved); $i+=2) {
                next unless $op >= $reserved[$i];
                last if $op > $reserved[$i+1];
                $tagInfo = $et->GetTagInfo($tagTablePtr, $reserved[$i]);
                last;
            }
            last unless $tagInfo;
        }
        if ($op == 0xff) {
            $verbose and print $out "End of picture\n";
            $success = 1;
            last;
        }
        my $format = $$tagInfo{Format};
        unless ($format) {
            $et->Warn("Missing format for $$tagInfo{Name}");
            last;
        }
        # replace version number for version-dependent formats
        $format =~ s/#$/$vers/;
        my $wid = $vers * 2;
        $verbose and printf $out "Tag 0x%.${wid}x, ", $op;
        my $val = ReadPictValue($raf, $$tagInfo{Name}, $format);
        unless (defined $val) {
            $et->Warn("Error reading $$tagInfo{Name} information");
            last;
        }
        if (ref $val eq 'HASH') {
            # extract JPEG image from CompressedQuickTime imageData
            if ($$tagInfo{Name} eq 'CompressedQuickTime' and
                ref $val->{imageDescr} eq 'HASH' and
                $val->{imageDescr}->{compressor} and
                $val->{imageDescr}->{compressor} eq 'Photo - JPEG' and
                ref $val->{imageData} eq 'SCALAR' and
                $et->ValidateImage($val->{imageData}, 'PreviewImage'))
            {
                $et->FoundTag('PreviewImage', $val->{imageData});
            }
        } else {
            # $et->FoundTag($tagInfo, $val);
        }
    }
    $success or $et->Warn('End of picture not found');
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PICT - Read PICT meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read PICT
(Apple Picture) images.

=head1 NOTES

Extraction of PICT opcodes is experimental, and is only enabled with the
Verbose or the Unknown option.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://developer.apple.com/documentation/mac/QuickDraw/QuickDraw-2.html>

=item L<http://developer.apple.com/documentation/QuickTime/INMAC/QT/iqImageCompMgr.a.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PICT Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

