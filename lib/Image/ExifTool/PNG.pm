#------------------------------------------------------------------------------
# File:         PNG.pm
#
# Description:  Read and write PNG meta information
#
# Revisions:    06/10/2005 - P. Harvey Created
#               06/23/2005 - P. Harvey Added MNG and JNG support
#               09/16/2005 - P. Harvey Added write support
#
# References:   1) http://www.libpng.org/pub/png/spec/1.2/
#               2) http://www.faqs.org/docs/png/
#               3) http://www.libpng.org/pub/mng/
#               4) http://www.libpng.org/pub/png/spec/register/
#               5) ftp://ftp.simplesystems.org/pub/png/documents/pngext-1.4.0-pdg.html
#               6) ftp://ftp.simplesystems.org/pub/png/documents/pngext-1.5.0.html
#
# Notes:        Writing meta information in PNG images is a pain in the butt
#               for a number of reasons:  One biggie is that you have to
#               decompress then decode the ASCII/hex profile information before
#               you can edit it, then you have to ASCII/hex-encode, recompress
#               and calculate a CRC before you can write it out again.  gaaaak.
#
#               Although XMP is allowed after the IDAT chunk according to the
#               PNG specifiction, some apps (Apple Spotlight and Preview for
#               OS X 10.8.5 and Adobe Photoshop CC 14.0) ignore it unless it
#               comes before IDAT.  As of version 11.58, ExifTool uses a 2-pass
#               writing algorithm to allow it to be compatible with XMP after
#               IDAT while writing it before IDAT.  (PNG and EXIF are still
#               written after IDAT.)  As of version 11.63, this strategy is
#               applied to all text chunks (tEXt, zTXt and iTXt).
#------------------------------------------------------------------------------

package Image::ExifTool::PNG;

use strict;
use vars qw($VERSION $AUTOLOAD %stdCase);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.67';

sub ProcessPNG_tEXt($$$);
sub ProcessPNG_iTXt($$$);
sub ProcessPNG_eXIf($$$);
sub ProcessPNG_Compressed($$$);
sub CalculateCRC($;$$$);
sub HexEncode($);
sub AddChunks($$;@);
sub Add_iCCP($$);
sub DoneDir($$$;$);
sub GetLangInfo($$);
sub BuildTextChunk($$$$$);
sub ConvertPNGDate($$);
sub InversePNGDate($$);

# translate lower-case to actual case used for eXIf/zXIf chunks
%stdCase = ( 'zxif' => 'zxIf', exif => 'eXIf' );

my $noCompressLib;

# look up for file type, header chunk and end chunk, based on file signature
my %pngLookup = (
    "\x89PNG\r\n\x1a\n" => ['PNG', 'IHDR', 'IEND' ],
    "\x8aMNG\r\n\x1a\n" => ['MNG', 'MHDR', 'MEND' ],
    "\x8bJNG\r\n\x1a\n" => ['JNG', 'JHDR', 'IEND' ],
);

# map for directories in PNG images
my %pngMap = (
    IFD1         => 'IFD0',
    EXIF         => 'IFD0', # to write EXIF as a block
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
    IFD0         => 'PNG',
    XMP          => 'PNG',
    ICC_Profile  => 'PNG',
    Photoshop    => 'PNG',
   'PNG-pHYs'    => 'PNG',
    JUMBF        => 'PNG',
    IPTC         => 'Photoshop',
    MakerNotes   => 'ExifIFD',
);

# color type of current image
$Image::ExifTool::PNG::colorType = -1;

# data and text chunk types
my %isDatChunk = ( IDAT => 1, JDAT => 1, JDAA => 1 );
my %isTxtChunk = ( tEXt => 1, zTXt => 1, iTXt => 1, eXIf => 1 );

# chunks that we shouldn't move other chunks across (ref 3)
my %noLeapFrog = ( SAVE => 1, SEEK => 1, IHDR => 1, JHDR => 1, IEND => 1, MEND => 1,
                   DHDR => 1, BASI => 1, CLON => 1, PAST => 1, SHOW => 1, MAGN => 1 );

# PNG chunks
%Image::ExifTool::PNG::Main = (
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    GROUPS => { 2 => 'Image' },
    PREFERRED => 1, # always add these tags when writing
    NOTES => q{
        Tags extracted from PNG images.  See
        L<http://www.libpng.org/pub/png/spec/1.2/> for the official PNG 1.2
        specification.

        According to the specification, a PNG file should end at the IEND chunk,
        however ExifTool will preserve any data found after this when writing unless
        it is specifically deleted with C<-Trailer:All=>.  When reading, a minor
        warning is issued if this trailer exists, and ExifTool will attempt to parse
        this data as additional PNG chunks.

        Also according to the PNG specification, there is no restriction on the
        location of text-type chunks (tEXt, zTXt and iTXt).  However, certain
        utilities (including some Apple and Adobe utilities) won't read the XMP iTXt
        chunk if it comes after the IDAT chunk, and at least one utility won't read
        other text chunks here.  For this reason, when writing, ExifTool 11.63 and
        later create new text chunks (including XMP) before IDAT, and move existing
        text chunks to before IDAT.

        The PNG format contains CRC checksums that are validated when reading with
        either the L<Verbose|../ExifTool.html#Verbose> or L<Validate|../ExifTool.html#Validate> option.  When writing, these checksums are
        validated by default, but the L<FastScan|../ExifTool.html#FastScan> option may be used to bypass this
        check if speed is more of a concern.
    },
    bKGD => {
        Name => 'BackgroundColor',
        ValueConv => 'join(" ",unpack(length($val) < 2 ? "C" : "n*", $val))',
    },
    cHRM => {
        Name => 'PrimaryChromaticities',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::PrimaryChromaticities' },
    },
    dSIG => {
        Name => 'DigitalSignature',
        Binary => 1,
    },
    fRAc => {
        Name => 'FractalParameters',
        Binary => 1,
    },
    gAMA => {
        Name => 'Gamma',
        Writable => 1,
        Protected => 1,
        Notes => q{
            ExifTool reports the gamma for decoding the image, which is consistent with
            the EXIF convention, but is the inverse of the stored encoding gamma
        },
        ValueConv => 'my $a=unpack("N",$val);$a ? int(1e9/$a+0.5)/1e4 : $val',
        ValueConvInv => 'pack("N", int(1e5/$val+0.5))',
    },
    gIFg => {
        Name => 'GIFGraphicControlExtension',
        Binary => 1,
    },
    gIFt => {
        Name => 'GIFPlainTextExtension',
        Binary => 1,
    },
    gIFx => {
        Name => 'GIFApplicationExtension',
        Binary => 1,
    },
    hIST => {
        Name => 'PaletteHistogram',
        Binary => 1,
    },
    iCCP => {
        Name => 'ICC_Profile',
        Notes => q{
            this is where ExifTool will write a new ICC_Profile.  When creating a new
            ICC_Profile, the SRGBRendering tag should be deleted if it exists
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessPNG_Compressed,
        },
    },
   'iCCP-name' => {
        Name => 'ProfileName',
        Writable => 1,
        FakeTag => 1, # (not a real PNG tag, so don't try to write it)
        Notes => q{
            not a real tag ID, this tag represents the iCCP profile name, and may only
            be written when the ICC_Profile is written
        },
    },
#   IDAT
#   IEND
    IHDR => {
        Name => 'ImageHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::ImageHeader' },
    },
    iTXt => {
        Name => 'InternationalText',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::TextualData',
            ProcessProc => \&ProcessPNG_iTXt,
        },
    },
    oFFs => {
        Name => 'ImageOffset',
        ValueConv => q{
            my @a = unpack("NNC",$val);
            $a[2] = ($a[2] ? "microns" : "pixels");
            return "$a[0], $a[1] ($a[2])";
        },
    },
    pCAL => {
        Name => 'PixelCalibration',
        Binary => 1,
    },
    pHYs => {
        Name => 'PhysicalPixel',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::PhysicalPixel',
            DirName => 'PNG-pHYs', # (needed for writing)
        },
    },
    PLTE => {
        Name => 'Palette',
        ValueConv => 'length($val) <= 3 ? join(" ",unpack("C*",$val)) : \$val',
    },
    sBIT => {
        Name => 'SignificantBits',
        ValueConv => 'join(" ",unpack("C*",$val))',
    },
    sCAL => { # png 1.4.0
        Name => 'SubjectScale',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::SubjectScale' },
    },
    sPLT => {
        Name => 'SuggestedPalette',
        Binary => 1,
        PrintConv => 'split("\0",$$val,1)', # extract palette name
    },
    sRGB => {
        Name => 'SRGBRendering',
        Writable => 1,
        Protected => 1,
        Notes => 'this chunk should not be present if an iCCP chunk exists',
        ValueConv => 'unpack("C",$val)',
        ValueConvInv => 'pack("C",$val)',
        PrintConv => {
            0 => 'Perceptual',
            1 => 'Relative Colorimetric',
            2 => 'Saturation',
            3 => 'Absolute Colorimetric',
        },
    },
    sTER => { # png 1.4.0
        Name => 'StereoImage',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::StereoImage' },
    },
    tEXt => {
        Name => 'TextualData',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::TextualData' },
    },
    tIME => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        Writable => 1,
        Shift => 'Time',
        ValueConv => 'sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d", unpack("nC5", $val))',
        ValueConvInv => q{
            my @a = ($val=~/^(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)/);
            @a == 6 or warn('Invalid date'), return undef;
            return pack('nC5', @a);
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    tRNS => {
        Name => 'Transparency',
        # may have as many entries as the PLTE table, but who wants to see all that?
        ValueConv => q{
            return \$val if length($val) > 6;
            join(" ",unpack($Image::ExifTool::PNG::colorType == 3 ? "C*" : "n*", $val));
        },
    },
    tXMP => {
        Name => 'XMP',
        Notes => 'obsolete location specified by a September 2001 XMP draft',
        NonStandard => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
    vpAg => { # private imagemagick chunk
        Name => 'VirtualPage',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::VirtualPage' },
    },
    zTXt => {
        Name => 'CompressedText',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::TextualData',
            ProcessProc => \&ProcessPNG_Compressed,
        },
    },
    # animated PNG (ref https://wiki.mozilla.org/APNG_Specification)
    acTL => {
        Name => 'AnimationControl',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::AnimationControl',
        },
    },
    # eXIf (ref 6)
    $stdCase{exif} => {
        Name => $stdCase{exif},
        Notes => 'this is where ExifTool will create new EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            DirName => 'EXIF', # (to write as a block)
            ProcessProc => \&ProcessPNG_eXIf,
        },
    },
    # zXIf
    $stdCase{zxif} => {
        Name => $stdCase{zxif},
        Notes => 'a once-proposed chunk for compressed EXIF',
        NonStandard => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            DirName => 'EXIF', # (to write as a block)
            ProcessProc => \&ProcessPNG_eXIf,
        },
    },
    # fcTL - animation frame control for each frame
    # fdAT - animation data for each frame
    iDOT => { # (ref NealKrawetz)
        Name => 'AppleDataOffsets',
        Binary => 1,
        # Apple offsets into data relative to start of iDOT chunk:
        #    int32u Divisor  [only ever seen 2]
        #    int32u Unknown  [always 0]
        #    int32u TotalDividedHeight  [image height from IDHR/Divisor]
        #    int32u Size  [always 40 / 0x28; size of this chunk]
        #    int32u DividedHeight1
        #    int32u DividedHeight2
        #    int32u IDAT_Offset2 [location of IDAT with start of DividedHeight2 segment]
    },
    caBX => { # C2PA metadata
        Name => 'JUMBF',
        Deletable => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Jpeg2000::Main' },
    },
    cICP => {
        Name => 'CICodePoints',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PNG::CICodePoints',
        },
    },
    cpIp => { # OLE information found in PNG Plus images written by Picture It!
        Name => 'OLEInfo',
        Condition => q{
            # set FileType to "PNG Plus"
            if ($$self{VALUE}{FileType} and $$self{VALUE}{FileType} eq "PNG") {
                $$self{VALUE}{FileType} = 'PNG Plus';
            }
            return 1;
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::Main',
            ProcessProc => 'Image::ExifTool::FlashPix::ProcessFPX',
        },
    },
    meTa => { # XML in UTF-16 BOM format written by Picture It!
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::XML',
            IgnoreProp => { meta => 1 }, # ignore 'meta' container
        },
    },
    # mkBF,mkTS,mkBS,mkBT ? - written by Adobe FireWorks
);

# PNG IHDR chunk
%Image::ExifTool::PNG::ImageHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    4 => {
        Name => 'ImageHeight',
        Format => 'int32u',
    },
    8 => 'BitDepth',
    9 => {
        Name => 'ColorType',
        RawConv => '$Image::ExifTool::PNG::colorType = $val',
        PrintConv => {
            0 => 'Grayscale',
            2 => 'RGB',
            3 => 'Palette',
            4 => 'Grayscale with Alpha',
            6 => 'RGB with Alpha',
        },
    },
    10 => {
        Name => 'Compression',
        PrintConv => { 0 => 'Deflate/Inflate' },
    },
    11 => {
        Name => 'Filter',
        PrintConv => { 0 => 'Adaptive' },
    },
    12 => {
        Name => 'Interlace',
        PrintConv => { 0 => 'Noninterlaced', 1 => 'Adam7 Interlace' },
    },
);

# PNG cHRM chunk
%Image::ExifTool::PNG::PrimaryChromaticities = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    0 => { Name => 'WhitePointX', ValueConv => '$val / 100000' },
    1 => { Name => 'WhitePointY', ValueConv => '$val / 100000' },
    2 => { Name => 'RedX',        ValueConv => '$val / 100000' },
    3 => { Name => 'RedY',        ValueConv => '$val / 100000' },
    4 => { Name => 'GreenX',      ValueConv => '$val / 100000' },
    5 => { Name => 'GreenY',      ValueConv => '$val / 100000' },
    6 => { Name => 'BlueX',       ValueConv => '$val / 100000' },
    7 => { Name => 'BlueY',       ValueConv => '$val / 100000' },
);

# PNG pHYs chunk
%Image::ExifTool::PNG::PhysicalPixel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    WRITABLE => 1,
    GROUPS => { 1 => 'PNG-pHYs', 2 => 'Image' },
    WRITE_GROUP => 'PNG-pHYs',
    NOTES => q{
        These tags are found in the PNG pHYs chunk and belong to the PNG-pHYs family
        1 group.  They are all created together with default values if necessary
        when any of these tags is written, and may only be deleted as a group.
    },
    0 => {
        Name => 'PixelsPerUnitX',
        Format => 'int32u',
        Notes => 'default 2834',
    },
    4 => {
        Name => 'PixelsPerUnitY',
        Format => 'int32u',
        Notes => 'default 2834',
    },
    8 => {
        Name => 'PixelUnits',
        PrintConv => { 0 => 'Unknown', 1 => 'meters' },
        Notes => 'default meters',
    },
);

# PNG cICP chunk
%Image::ExifTool::PNG::CICodePoints = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 1 => 'PNG-cICP', 2 => 'Image' },
    NOTES => q{
        These tags are found in the PNG cICP chunk and belong to the PNG-cICP family
        1 group.
    },
    # (same as tags in QuickTime::ColorRep)
    0 => {
        Name => 'ColorPrimaries',
        PrintConv => {
            1 => 'BT.709',
            2 => 'Unspecified',
            4 => 'BT.470 System M (historical)',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240',
            8 => 'Generic film (color filters using illuminant C)',
            9 => 'BT.2020, BT.2100',
            10 => 'SMPTE 428 (CIE 1921 XYZ)',
            11 => 'SMPTE RP 431-2',
            12 => 'SMPTE EG 432-1',
            22 => 'EBU Tech. 3213-E',
        },
    },
    1 => {
        Name => 'TransferCharacteristics',
        PrintConv => {
            0 => 'For future use (0)',
            1 => 'BT.709',
            2 => 'Unspecified',
            3 => 'For future use (3)',
            4 => 'BT.470 System M (historical)',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240 M',
            8 => 'Linear',
            9 => 'Logarithmic (100 : 1 range)',
            10 => 'Logarithmic (100 * Sqrt(10) : 1 range)',
            11 => 'IEC 61966-2-4',
            12 => 'BT.1361',
            13 => 'sRGB or sYCC',
            14 => 'BT.2020 10-bit systems',
            15 => 'BT.2020 12-bit systems',
            16 => 'SMPTE ST 2084, ITU BT.2100 PQ',
            17 => 'SMPTE ST 428',
            18 => 'BT.2100 HLG, ARIB STD-B67',
        },
    },
    2 => {
        Name => 'MatrixCoefficients',
        PrintConv => {
            0 => 'Identity matrix',
            1 => 'BT.709',
            2 => 'Unspecified',
            3 => 'For future use (3)',
            4 => 'US FCC 73.628',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240 M',
            8 => 'YCgCo',
            9 => 'BT.2020 non-constant luminance, BT.2100 YCbCr',
            10 => 'BT.2020 constant luminance',
            11 => 'SMPTE ST 2085 YDzDx',
            12 => 'Chromaticity-derived non-constant luminance',
            13 => 'Chromaticity-derived constant luminance',
            14 => 'BT.2100 ICtCp',
        },
    },
    3 => 'VideoFullRangeFlag',
);

# PNG sCAL chunk
%Image::ExifTool::PNG::SubjectScale = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'SubjectUnits',
        PrintConv => { 1 => 'meters', 2 => 'radians' },
    },
    1 => {
        Name => 'SubjectPixelWidth',
        Format => 'var_string',
    },
    2 => {
        Name => 'SubjectPixelHeight',
        Format => 'var_string',
    },
);

# PNG vpAg chunk
%Image::ExifTool::PNG::VirtualPage = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    0 => 'VirtualImageWidth',
    1 => 'VirtualImageHeight',
    2 => {
        Name => 'VirtualPageUnits',
        Format => 'int8u',
        # what is the conversion for this?
    },
);

# PNG sTER chunk
%Image::ExifTool::PNG::StereoImage = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'StereoMode',
        PrintConv => {
            0 => 'Cross-fuse Layout',
            1 => 'Diverging-fuse Layout',
        },
    },
);

my %unreg = ( Notes => 'unregistered' );

# Tags for PNG tEXt zTXt and iTXt chunks
# (NOTE: ValueConv is set dynamically, so don't set it here!)
%Image::ExifTool::PNG::TextualData = (
    PROCESS_PROC => \&ProcessPNG_tEXt,
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    WRITABLE => 'string',
    PREFERRED => 1, # always add these tags when writing
    GROUPS => { 2 => 'Image' },
    LANG_INFO => \&GetLangInfo,
    NOTES => q{
        The PNG TextualData format allows arbitrary tag names to be used.  The tags
        listed below are the only ones that can be written (unless new user-defined
        tags are added via the configuration file), however ExifTool will extract
        any other TextualData tags that are found.  All TextualData tags (including
        tags not listed below) are removed when deleting all PNG tags.

        These tags may be stored as tEXt, zTXt or iTXt chunks in the PNG image.  By
        default ExifTool writes new string-value tags as as uncompressed tEXt, or
        compressed zTXt if the L<Compress|../ExifTool.html#Compress> (-z) option is used and Compress::Zlib is
        available.  Alternate language tags and values containing special characters
        (unless the Latin character set is used) are written as iTXt, and compressed
        if the L<Compress|../ExifTool.html#Compress> option is used and Compress::Zlib is available.  Raw profile
        information is always created as compressed zTXt if Compress::Zlib is
        available, or tEXt otherwise.  Standard XMP is written as uncompressed iTXt.
        User-defined tags may set an 'iTXt' flag in the tag definition to be written
        only as iTXt.

        Alternate languages are accessed by suffixing the tag name with a '-',
        followed by an RFC 3066 language code (eg. "PNG:Comment-fr", or
        "Title-en-US").  See L<http://www.ietf.org/rfc/rfc3066.txt> for the RFC 3066
        specification.

        Some of the tags below are not registered as part of the PNG specification,
        but are included here because they are generated by other software such as
        ImageMagick.
    },
    Title       => { },
    Author      => { Groups => { 2 => 'Author' } },
    Description => { },
    Copyright   => { Groups => { 2 => 'Author' } },
   'Creation Time' => {
        Name => 'CreationTime',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Notes => 'stored in RFC-1123 format and converted to/from EXIF format by ExifTool',
        RawConv => \&ConvertPNGDate,
        ValueConvInv => \&InversePNGDate,
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
    },
    Software    => { },
    Disclaimer  => { },
    # change name to differentiate from ExifTool Warning
    Warning     => { Name => 'PNGWarning', },
    Source      => { },
    Comment     => { },
    Collection  => { }, # (PNG extensions, 2004)
#
# The following tags are not part of the original PNG specification,
# but are written by ImageMagick and other software
#
    Artist      => { %unreg, Groups => { 2 => 'Author' } },
    Document    => { %unreg },
    Label       => { %unreg },
    Make        => { %unreg, Groups => { 2 => 'Camera' } },
    Model       => { %unreg, Groups => { 2 => 'Camera' } },
    parameters  => { %unreg }, # (written by Stable Diffusion)
    aesthetic_score => { Name => 'AestheticScore', %unreg }, # (written by Stable Diffusion)
   'create-date'=> {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        %unreg,
        ValueConv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::ConvertXMPDate($val)',
        ValueConvInv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::FormatXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
    },
   'modify-date'=> {
        Name => 'ModDate', # (to distinguish from tIME chunk "ModifyDate")
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        %unreg,
        ValueConv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::ConvertXMPDate($val)',
        ValueConvInv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::FormatXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
    },
    TimeStamp   => { %unreg, Groups => { 2 => 'Time' }, Shift => 'Time' },
    URL         => { %unreg },
   'XML:com.adobe.xmp' => {
        Name => 'XMP',
        Notes => q{
            unregistered, but this is the location according to the June 2002 or later
            XMP specification, and is where ExifTool will add a new XMP chunk if the
            image didn't already contain XMP
        },
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
   'Raw profile type APP1' => [
        {
            # EXIF table must come first because we key on this in ProcessProfile()
            # (No condition because this is just for BuildTagLookup)
            Name => 'APP1_Profile',
            %unreg,
            NonStandard => 'EXIF',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&ProcessProfile,
            },
        },
        {
            Name => 'APP1_Profile',
            NonStandard => 'XMP',
            SubDirectory => {
                TagTable => 'Image::ExifTool::XMP::Main',
                ProcessProc => \&ProcessProfile,
            },
        },
    ],
   'Raw profile type exif' => {
        Name => 'EXIF_Profile',
        %unreg,
        NonStandard => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type icc' => {
        Name => 'ICC_Profile',
        %unreg,
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type icm' => {
        Name => 'ICC_Profile',
        %unreg,
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type iptc' => {
        Name => 'IPTC_Profile',
        Notes => q{
            unregistered.  May be either IPTC IIM or Photoshop IRB format.  This is
            where ExifTool will add new IPTC, inside a Photoshop IRB container
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
   'Raw profile type xmp' => {
        Name => 'XMP_Profile',
        %unreg,
        NonStandard => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
    'Raw profile type 8bim' => {
        Name => 'Photoshop_Profile',
        %unreg,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
            ProcessProc => \&ProcessProfile,
        },
    },
);

# Animation control
%Image::ExifTool::PNG::AnimationControl = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    NOTES => q{
        Tags found in the Animation Control chunk.  See
        L<https://wiki.mozilla.org/APNG_Specification> for details.
    },
    0 => {
        Name => 'AnimationFrames',
        RawConv => '$self->OverrideFileType("APNG", undef, "PNG"); $val',
    },
    1 => {
        Name => 'AnimationPlays',
        PrintConv => '$val || "inf"',
    },
);

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Get standard case for language code (this routine copied from XMP.pm)
# Inputs: 0) Language code
# Returns: Language code in standard case
sub StandardLangCase($)
{
    my $lang = shift;
    # make 2nd subtag uppercase only if it is 2 letters
    return lc($1) . uc($2) . lc($3) if $lang =~ /^([a-z]{2,3}|[xi])(-[a-z]{2})\b(.*)/i;
    return lc($lang);
}

#------------------------------------------------------------------------------
# Convert date from PNG to EXIF format
# Inputs: 0) Date/time in PNG format, 1) ExifTool ref
# Returns: EXIF formatted date/time string
my %monthNum = (
    Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6,
    Jul=>7, Aug=>8, Sep=>9, Oct=>10,Nov=>11,Dec=>12
);
my %tzConv = (
    UT  => '+00:00',  GMT => '+00:00',  UTC => '+00:00', # (UTC not in spec -- PH addition)
    EST => '-05:00',  EDT => '-04:00',
    CST => '-06:00',  CDT => '-05:00',
    MST => '-07:00',  MDT => '-06:00',
    PST => '-08:00',  PDT => '-07:00',
    A => '-01:00',    N => '+01:00',
    B => '-02:00',    O => '+02:00',
    C => '-03:00',    P => '+03:00',
    D => '-04:00',    Q => '+04:00',
    E => '-05:00',    R => '+05:00',
    F => '-06:00',    S => '+06:00',
    G => '-07:00',    T => '+07:00',
    H => '-08:00',    U => '+08:00',
    I => '-09:00',    V => '+09:00',
    K => '-10:00',    W => '+10:00',
    L => '-11:00',    X => '+11:00',
    M => '-12:00',    Y => '+12:00',
    Z => '+00:00',
);
sub ConvertPNGDate($$)
{
    my ($val, $et) = @_;
    # standard format is like "Mon, 1 Jan 2018 12:10:22 EST" (RFC-1123 section 5.2.14)
    while ($val =~ /(\d+)\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s*(\d+)\s+(\d+):(\d{2})(:\d{2})?\s*(\S*)/i) {
        my ($day,$mon,$yr,$hr,$min,$sec,$tz) = ($1,$2,$3,$4,$5,$6,$7);
        $yr += $yr > 70 ? 1900 : 2000 if $yr < 100;     # boost year to 4 digits if necessary
        $mon = $monthNum{ucfirst lc $mon} or return $val;
        if (not $tz) {
            $tz = '';
        } elsif ($tzConv{uc $tz}) {
            $tz = $tzConv{uc $tz};
        } elsif ($tz =~ /^([-+]\d+):?(\d{2})/) {
            $tz = $1 . ':' . $2;
        } else {
            last;       # (non-standard date)
        }
        return sprintf("%.4d:%.2d:%.2d %.2d:%.2d%s%s",$yr,$mon,$day,$hr,$min,$sec||':00',$tz);
    }
    if (($et->Options('StrictDate') and not $$et{TAGS_FROM_FILE}) or $et->Options('Validate')) {
        $et->Warn('Non standard PNG date/time format', 1);
    }
    return $val;
}

#------------------------------------------------------------------------------
# Convert EXIF date/time to PNG format
# Inputs: 0) Date/time in EXIF format, 1) ExifTool ref
# Returns: PNG formatted date/time string
sub InversePNGDate($$)
{
    my ($val, $et) = @_;
    if ($et->Options('StrictDate')) {
        my $err;
        if ($val =~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2})(:\d{2})(:\d{2})?(?:\.\d*)?\s*(\S*)/) {
            my ($yr,$mon,$day,$hr,$min,$sec,$tz) = ($1,$2,$3,$4,$5,$6,$7);
            $sec or $sec = '';
            my %monName = map { $monthNum{$_} => $_ } keys %monthNum;
            $mon = $monName{$mon + 0} or $err = 1;
            if (length $tz) {
                $tz =~ /^(Z|[-+]\d{2}:?\d{2})/ or $err = 1;
                $tz =~ tr/://d;
                $tz = ' ' . $tz;
            }
            $val = "$day $mon $yr $hr$min$sec$tz" unless $err;
        }
        if ($err) {
            warn "Invalid date/time (use YYYY:mm:dd HH:MM:SS[.ss][+/-HH:MM|Z])\n";
            undef $val;
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash
# Inputs: 0) tagInfo hash ref, 1) language code (eg. "x-default")
# Returns: new tagInfo hash ref, or undef if invalid
sub GetLangInfo($$)
{
    my ($tagInfo, $lang) = @_;
    $lang =~ tr/_/-/;   # RFC 3066 specifies '-' as a separator
    # no alternate languages for XMP or raw profile directories
    return undef if $$tagInfo{SubDirectory};
    # language code must normalized for use in tag ID
    return Image::ExifTool::GetLangInfo($tagInfo, StandardLangCase($lang));
}

#------------------------------------------------------------------------------
# Found a PNG tag -- extract info from subdirectory or decompress data if necessary
# Inputs: 0) ExifTool object reference, 1) Pointer to tag table,
#         2) Tag ID, 3) Tag value, 4) [optional] compressed data flag:
#            0=not compressed, 1=unknown compression, 2-N=compression with type N-2
#         5) optional output buffer ref, 6) character encoding (tEXt/zTXt/iTXt only)
#         6) optional language code
# Returns: 1 on success
sub FoundPNG($$$$;$$$$)
{
    my ($et, $tagTablePtr, $tag, $val, $compressed, $outBuff, $enc, $lang) = @_;
    return 0 unless defined $val;
    my $verbose = $et->Options('Verbose');
    my $id = $tag;  # generate tag ID which includes language code
    if ($lang) {
        # case of language code must be normalized since they are case insensitive
        $lang = StandardLangCase($lang);
        $id .= '-' . $lang;
    }
    my $tagInfo = $et->GetTagInfo($tagTablePtr, $id) ||
                  # (some software forgets to capitalize first letter)
                  $et->GetTagInfo($tagTablePtr, ucfirst($id));
    # create alternate language tag if necessary
    if (not $tagInfo and $lang) {
        $tagInfo = $et->GetTagInfo($tagTablePtr, $tag) ||
                   $et->GetTagInfo($tagTablePtr, ucfirst($tag));
        $tagInfo = GetLangInfo($tagInfo, $lang) if $tagInfo;
    }
#
# uncompress data if necessary
#
    my ($wasCompressed, $deflateErr);
    if ($compressed and $compressed > 1) {
        if ($compressed == 2) { # Inflate/Deflate compression
            if (eval { require Compress::Zlib }) {
                my ($v2, $stat);
                my $inflate = Compress::Zlib::inflateInit();
                $inflate and ($v2, $stat) = $inflate->inflate($val);
                if ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                    $val = $v2;
                    $compressed = 0;
                    $wasCompressed = 1;
                } else {
                    $deflateErr = "Error inflating $tag";
                }
            } elsif (not $noCompressLib) {
                $deflateErr = "Install Compress::Zlib to read compressed information";
            } else {
                $deflateErr = '';   # flag deflate error but no warning
            }
        } else {
            $compressed -= 2;
            $deflateErr = "Unknown compression method $compressed for $tag";
        }
        if ($compressed and $verbose and $tagInfo and $$tagInfo{SubDirectory}) {
            $et->VerboseDir("Unable to decompress $$tagInfo{Name}", 0, length($val));
        }
        # issue warning if relevant
        if ($deflateErr and not $outBuff) {
            $et->Warn($deflateErr);
            $noCompressLib = 1 if $deflateErr =~ /^Install/;
        }
    }
    # translate character encoding if necessary (tEXt/zTXt/iTXt string values only)
    if ($enc and not $compressed and not ($tagInfo and $$tagInfo{SubDirectory})) {
        $val = $et->Decode($val, $enc);
    }
#
# extract information from subdirectory if available
#
    if ($tagInfo) {
        my $tagName = $$tagInfo{Name};
        my $processed;
        if ($$tagInfo{SubDirectory}) {
            if ($$et{OPTIONS}{Validate} and $$tagInfo{NonStandard}) {
                $et->WarnOnce("Non-standard $$tagInfo{NonStandard} in PNG $tag chunk", 1);
            }
            my $subdir = $$tagInfo{SubDirectory};
            my $dirName = $$subdir{DirName} || $tagName;
            if (not $compressed) {
                my $len = length $val;
                if ($verbose and $$et{INDENT} ne '  ') {
                    if ($wasCompressed and $verbose > 2) {
                        my $name = $tagName;
                        $wasCompressed and $name = "Decompressed $name";
                        $et->VerboseDir($name, 0, $len);
                        $et->VerboseDump(\$val);
                    }
                    # don't indent next directory (since it is really the same data)
                    $$et{INDENT} =~ s/..$//;
                }
                my $processProc = $$subdir{ProcessProc};
                # nothing more to do if writing and subdirectory is not writable
                my $subTable = GetTagTable($$subdir{TagTable});
                return 1 if $outBuff and not $$subTable{WRITE_PROC};
                my $dirName = $$subdir{DirName} || $tagName;
                my %subdirInfo = (
                    DataPt   => \$val,
                    DirStart => 0,
                    DataLen  => $len,
                    DirLen   => $len,
                    DirName  => $dirName,
                    TagInfo  => $tagInfo,
                    ReadOnly => 1, # (used only by WriteXMP)
                    OutBuff  => $outBuff,
                    IgnoreProp => $$subdir{IgnoreProp}, # (XML hack for meTa chunk)
                );
                # no need to re-decompress if already done
                undef $processProc if $wasCompressed and $processProc and $processProc eq \&ProcessPNG_Compressed;
                # rewrite this directory if necessary (but always process TextualData normally)
                if ($outBuff and not $processProc and $subTable ne \%Image::ExifTool::PNG::TextualData) {
                    return 1 unless $$et{EDIT_DIRS}{$dirName};
                    $$outBuff = $et->WriteDirectory(\%subdirInfo, $subTable);
                    if ($tagName eq 'XMP' and $$outBuff) {
                        # make sure the XMP is marked as read-only
                        Image::ExifTool::XMP::ValidateXMP($outBuff,'r');
                    }
                    DoneDir($et, $dirName, $outBuff, $$tagInfo{NonStandard});
                } else {
                    $processed = $et->ProcessDirectory(\%subdirInfo, $subTable, $processProc);
                }
                $compressed = 1;    # pretend this is compressed since it is binary data
            } elsif ($outBuff) {
                if ($$et{DEL_GROUP}{$dirName} or ($dirName eq 'EXIF' and $$et{DEL_GROUP}{IFD0})) {
                    $$outBuff = '';
                    ++$$et{CHANGED};
                    $et->VPrint(0, "  Deleting $tag chunk");
                } else {
                    if ($$et{EDIT_DIRS}{$dirName} or ($dirName eq 'EXIF' and $$et{EDIT_DIRS}{IFD0})) {
                        $et->Warn("Can't write $dirName. Requires Compress::Zlib");
                    }
                    # pretend we did this directory so we don't try to recreate it
                    DoneDir($et, $dirName, $outBuff, $$tagInfo{NonStandard});
                }
            }
        }
        if ($outBuff) {
            my $writable = $$tagInfo{Writable};
            my $isOverwriting;
            if ($writable or ($$tagTablePtr{WRITABLE} and
                not defined $writable and not $$tagInfo{SubDirectory}))
            {
                # write new value for this tag if necessary
                my $newVal;
                if ($$et{DEL_GROUP}{PNG}){
                    # remove this tag now, but keep in ADD_PNG list to add back later
                    $isOverwriting = 1;
                } else {
                    # remove this from the list of PNG tags to add
                    delete $$et{ADD_PNG}{$id};
                    # (also handle case of tEXt tags written with lowercase first letter)
                    delete $$et{ADD_PNG}{ucfirst($id)};
                    my $nvHash = $et->GetNewValueHash($tagInfo);
                    $isOverwriting = $et->IsOverwriting($nvHash);
                    if (defined $deflateErr) {
                        $newVal = $et->GetNewValue($nvHash);
                        # can only write tag now if always overwriting
                        if ($isOverwriting > 0) {
                            $val = '<deflate error>';
                        } elsif ($isOverwriting) {
                            $isOverwriting = 0; # can't overwrite
                            $et->Warn($deflateErr) if $deflateErr;
                        }
                    } else {
                        if ($isOverwriting < 0) {
                            $isOverwriting = $et->IsOverwriting($nvHash, $val);
                        }
                        # (must get new value after IsOverwriting() in case it was shifted)
                        $newVal = $et->GetNewValue($nvHash);
                    }
                }
                if ($isOverwriting) {
                    $$outBuff = (defined $newVal) ? $newVal : '';
                    ++$$et{CHANGED};
                    $et->VerboseValue("- PNG:$tagName", $val);
                    $et->VerboseValue("+ PNG:$tagName", $newVal) if defined $newVal;
                }
            }
            if (defined $$outBuff and length $$outBuff) {
                if ($enc) { # must be tEXt/zTXt/iTXt if $enc is set
                    $$outBuff = BuildTextChunk($et, $tag, $tagInfo, $$outBuff, $lang);
                } elsif ($wasCompressed) {
                    # re-compress the output data
                    my $len = length $$outBuff;
                    my $deflate = Compress::Zlib::deflateInit();
                    if ($deflate) {
                        $$outBuff = $deflate->deflate($$outBuff);
                        $$outBuff .= $deflate->flush() if defined $$outBuff;
                    } else {
                        undef $$outBuff;
                    }
                    if (not $$outBuff) {
                        $et->Warn("PNG:$tagName not written (compress error)");
                    } elsif (lc $tag eq 'zxif') {
                        $$outBuff = "\0" . pack('N',$len) . $$outBuff;  # add zXIf header
                    }
                }
            }
            return 1;
        }
        return 1 if $processed;
    } elsif ($outBuff) {
        if ($$et{DEL_GROUP}{PNG} and $tagTablePtr eq \%Image::ExifTool::PNG::TextualData) {
            # delete all TextualData tags if deleting the PNG group
            $$outBuff = '';
            ++$$et{CHANGED};
            $et->VerboseValue("- PNG:$tag", $val);
        }
        return 1;
    } else {
        my $name;
        ($name = $tag) =~ s/\s+(.)/\u$1/g;   # remove white space from tag name
        $tagInfo = { Name => $name };
        $$tagInfo{LangCode} = $lang if $lang;
        # make unknown profiles binary data type
        $$tagInfo{Binary} = 1 if $tag =~ /^Raw profile type /;
        $verbose and $et->VPrint(0, "  [adding $tag]\n");
        AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
#
# store this tag information
#
    if ($verbose) {
        # temporarily remove subdirectory so it isn't printed in verbose information
        # since we aren't decoding it anyway;
        my $subdir = $$tagInfo{SubDirectory};
        delete $$tagInfo{SubDirectory};
        $et->VerboseInfo($tag, $tagInfo,
            Table  => $tagTablePtr,
            DataPt => \$val,
        );
        $$tagInfo{SubDirectory} = $subdir if $subdir;
    }
    # set the RawConv dynamically depending on whether this is binary or not
    my $delRawConv;
    if ($compressed and not defined $$tagInfo{ValueConv}) {
        $$tagInfo{RawConv} = '\$val';
        $delRawConv = 1;
    }
    $et->FoundTag($tagInfo, $val);
    delete $$tagInfo{RawConv} if $delRawConv;
    return 1;
}

#------------------------------------------------------------------------------
# Process encoded PNG profile information
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
sub ProcessProfile($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $tagInfo = $$dirInfo{TagInfo};
    my $outBuff = $$dirInfo{OutBuff};
    my $tagName = $$tagInfo{Name};

    # ImageMagick 5.3.6 writes profiles with the following headers:
    # "\nICC Profile\n", "\nIPTC profile\n", "\n\xaa\x01{generic prof\n"
    # and "\ngeneric profile\n"
    return 0 unless $$dataPt =~ /^\n(.*?)\n\s*(\d+)\n(.*)/s;
    my ($profileType, $len) = ($1, $2);
    # data is encoded in hex, so change back to binary
    my $buff = pack('H*', join('',split(' ',$3)));
    my $actualLen = length $buff;
    if ($len ne $actualLen) {
        $et->Warn("$tagName is wrong size (should be $len bytes but is $actualLen)");
        $len = $actualLen;
    }
    my $verbose = $et->Options('Verbose');
    if ($verbose) {
        if ($verbose > 2) {
            $et->VerboseDir("Decoded $tagName", 0, $len);
            $et->VerboseDump(\$buff);
        }
        # don't indent next directory (since it is really the same data)
        $$et{INDENT} =~ s/..$//;
    }
    my %dirInfo = (
        Parent   => 'PNG',
        DataPt   => \$buff,
        DataLen  => $len,
        DirStart => 0,
        DirLen   => $len,
        Base     => 0,
        OutFile  => $outBuff,
    );
    $$et{PROCESSED} = { };    # reset processed directory offsets
    my $processed = 0;
    my $oldChanged = $$et{CHANGED};
    my $exifTable = GetTagTable('Image::ExifTool::Exif::Main');
    my $editDirs = $$et{EDIT_DIRS};

    if ($tagTablePtr ne $exifTable) {
        # this is unfortunate, but the "IPTC" profile may be stored as either
        # IPTC IIM or a Photoshop IRB resource, so we must test for this
        if ($tagName eq 'IPTC_Profile' and $buff =~ /^\x1c/) {
            $tagTablePtr = GetTagTable('Image::ExifTool::IPTC::Main');
        }
        # process non-EXIF and non-APP1 profile as-is
        if ($outBuff) {
            # no need to rewrite this if not editing tags in this directory
            my $dir = $tagName;
            $dir =~ s/_Profile// unless $dir =~ /^ICC/;
            return 1 unless $$editDirs{$dir};
            $$outBuff = $et->WriteDirectory(\%dirInfo, $tagTablePtr);
            DoneDir($et, $dir, $outBuff, $$tagInfo{NonStandard});
        } else {
            $processed = $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
    } elsif ($buff =~ /^$Image::ExifTool::exifAPP1hdr/) {
        # APP1 EXIF information
        return 1 if $outBuff and not $$editDirs{IFD0};
        my $hdrLen = length($Image::ExifTool::exifAPP1hdr);
        $dirInfo{DirStart} += $hdrLen;
        $dirInfo{DirLen} -= $hdrLen;
        if ($outBuff) {
            # delete non-standard EXIF if recreating from scratch
            if ($$et{DEL_GROUP}{EXIF} or $$et{DEL_GROUP}{IFD0}) {
                $$outBuff = '';
                $et->VPrint(0, '  Deleting non-standard APP1 EXIF information');
                return 1;
            }
            $$outBuff = $et->WriteDirectory(\%dirInfo, $tagTablePtr,
                                            \&Image::ExifTool::WriteTIFF);
            $$outBuff = $Image::ExifTool::exifAPP1hdr . $$outBuff if $$outBuff;
            DoneDir($et, 'IFD0', $outBuff, $$tagInfo{NonStandard});
        } else {
            $processed = $et->ProcessTIFF(\%dirInfo);
        }
    } elsif ($buff =~ /^$Image::ExifTool::xmpAPP1hdr/) {
        # APP1 XMP information
        my $hdrLen = length($Image::ExifTool::xmpAPP1hdr);
        my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
        $dirInfo{DirStart} += $hdrLen;
        $dirInfo{DirLen} -= $hdrLen;
        if ($outBuff) {
            return 1 unless $$editDirs{XMP};
            $$outBuff = $et->WriteDirectory(\%dirInfo, $tagTablePtr);
            $$outBuff and $$outBuff = $Image::ExifTool::xmpAPP1hdr . $$outBuff;
            DoneDir($et, 'XMP', $outBuff, $$tagInfo{NonStandard});
        } else {
            $processed = $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
    } elsif ($buff =~ /^(MM\0\x2a|II\x2a\0)/) {
        # TIFF information
        return 1 if $outBuff and not $$editDirs{IFD0};
        if ($outBuff) {
            # delete non-standard EXIF if recreating from scratch
            if ($$et{DEL_GROUP}{EXIF} or $$et{DEL_GROUP}{IFD0}) {
                $$outBuff = '';
                $et->VPrint(0, '  Deleting non-standard EXIF/TIFF information');
                return 1;
            }
            $$outBuff = $et->WriteDirectory(\%dirInfo, $tagTablePtr,
                                            \&Image::ExifTool::WriteTIFF);
            DoneDir($et, 'IFD0', $outBuff, $$tagInfo{NonStandard});
        } else {
            $processed = $et->ProcessTIFF(\%dirInfo);
        }
    } else {
        my $profName = $profileType;
        $profName =~ tr/\x00-\x1f\x7f-\xff/./;
        $et->Warn("Unknown raw profile '${profName}'");
    }
    if ($outBuff and defined $$outBuff and length $$outBuff) {
        if ($$et{CHANGED} != $oldChanged) {
            my $hdr = sprintf("\n%s\n%8d\n", $profileType, length($$outBuff));
            # hex encode the data
            $$outBuff = $hdr . HexEncode($outBuff);
        } else {
            undef $$outBuff;
        }
    }
    return $processed;
}

#------------------------------------------------------------------------------
# Process PNG compressed zTXt or iCCP chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
# Notes: writes new chunk data to ${$$dirInfo{OutBuff}} if writing tag
sub ProcessPNG_Compressed($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my ($tag, $val) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return 0 unless defined $val;
    # set compressed to 2 + compression method to decompress the data
    my $compressed = 2 + unpack('C', $val);
    my $hdr = $tag . "\0" . substr($val, 0, 1);
    $val = substr($val, 1); # remove compression method byte
    my $success;
    my $outBuff = $$dirInfo{OutBuff};
    my $tagInfo = $$dirInfo{TagInfo};
    # use the PNG chunk tag instead of the embedded tag name for iCCP chunks
    if ($tagInfo and $$tagInfo{Name} eq 'ICC_Profile') {
        $et->VerboseDir('iCCP');
        $tagTablePtr = \%Image::ExifTool::PNG::Main;
        FoundPNG($et, $tagTablePtr, 'iCCP-name', $tag) if length($tag) and not $outBuff;
        $success = FoundPNG($et, $tagTablePtr, 'iCCP', $val, $compressed, $outBuff);
        if ($outBuff and $$outBuff) {
            my $profileName = $et->GetNewValue($Image::ExifTool::PNG::Main{'iCCP-name'});
            if (defined $profileName) {
                $hdr = $profileName . substr($hdr, length $tag);
                $et->VerboseValue("+ PNG:ProfileName", $profileName);
            }
            $$outBuff = $hdr . $$outBuff;
        }
    } else {
        $success = FoundPNG($et, $tagTablePtr, $tag, $val, $compressed, $outBuff, 'Latin');
    }
    return $success;
}

#------------------------------------------------------------------------------
# Process PNG tEXt chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
# Notes: writes new chunk data to ${$$dirInfo{OutBuff}} if writing tag
sub ProcessPNG_tEXt($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my ($tag, $val) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    my $outBuff = $$dirInfo{OutBuff};
    $$et{INDENT} = substr($$et{INDENT}, 0, -2) if $$et{OPTIONS}{Verbose};
    return FoundPNG($et, $tagTablePtr, $tag, $val, undef, $outBuff, 'Latin');
}

#------------------------------------------------------------------------------
# Process PNG iTXt chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
# Notes: writes new chunk data to ${$$dirInfo{OutBuff}} if writing tag
sub ProcessPNG_iTXt($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my ($tag, $dat) = split /\0/, ${$$dirInfo{DataPt}}, 2;
    return 0 unless defined $dat and length($dat) >= 4;
    my ($compressed, $meth) = unpack('CC', $dat);
    my ($lang, $trans, $val) = split /\0/, substr($dat, 2), 3;
    # set compressed flag so we will decompress it in FoundPNG()
    $compressed and $compressed = 2 + $meth;
    my $outBuff = $$dirInfo{OutBuff};
    $$et{INDENT} = substr($$et{INDENT}, 0, -2) if $$et{OPTIONS}{Verbose};
    return FoundPNG($et, $tagTablePtr, $tag, $val, $compressed, $outBuff, 'UTF8', $lang);
}

#------------------------------------------------------------------------------
# Process PNG eXIf/zXIf chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) Pointer to tag table
# Returns: 1 on success
# Notes: writes new chunk data to ${$$dirInfo{OutBuff}} if writing tag
sub ProcessPNG_eXIf($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $outBuff = $$dirInfo{OutBuff};
    my $dataPt = $$dirInfo{DataPt};
    my $tagInfo = $$dirInfo{TagInfo};
    my $tag = $$tagInfo{TagID};
    my $del = $outBuff && ($$et{DEL_GROUP}{EXIF} or $$et{DEL_GROUP}{IFD0});
    my $type;

    if ($$dataPt =~ /^Exif\0\0/) {
        $et->Warn('Improper "Exif00" header in EXIF chunk');
        $$dataPt = substr($$dataPt, 6);
        $$dirInfo{DataLen} = length $$dataPt;
        $$dirInfo{DirLen} -= 6 if $$dirInfo{DirLen};
    }
    if ($$dataPt =~ /^(\0|II|MM)/) {
        $type = $1;
    } elsif ($del) {
        $et->VPrint(0, "  Deleting invalid $tag chunk");
        $$outBuff = '';
        ++$$et{CHANGED};
        return 1;
    } else {
        $et->Warn("Invalid $tag chunk");
        return 0;
    }
    if ($type eq "\0") {    # is this compressed EXIF?
        my $buf = substr($$dataPt, 5);
        # go around again to uncompress the data
        $tagTablePtr = GetTagTable('Image::ExifTool::PNG::Main');
        return FoundPNG($et, $tagTablePtr, $$tagInfo{TagID}, \$buf, 2, $outBuff);
    } elsif (not $outBuff) {
        return $et->ProcessTIFF($dirInfo);
    # (zxIf was not adopted)
    #} elsif ($del and ($et->Options('Compress') xor lc($tag) eq 'zxif')) {
    } elsif ($del and lc($tag) eq 'zxif') {
        $et->VPrint(0, "  Deleting $tag chunk");
        $$outBuff = '';
        ++$$et{CHANGED};
    } elsif ($$et{EDIT_DIRS}{IFD0}) {
        $$outBuff = $et->WriteDirectory($dirInfo, $tagTablePtr,
                                        \&Image::ExifTool::WriteTIFF);
        DoneDir($et, 'IFD0', $outBuff, $$tagInfo{NonStandard});
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract meta information from a PNG image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PNG image, or -1 on write error
sub ProcessPNG($$)
{
    my ($et, $dirInfo) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $raf = $$dirInfo{RAF};
    my $datChunk = '';
    my $datCount = 0;
    my $datBytes = 0;
    my $fastScan = $et->Options('FastScan');
    my $hash = $$et{ImageDataHash};
    my ($n, $sig, $err, $hbuf, $dbuf, $cbuf);
    my ($wasHdr, $wasEnd, $wasDat, $doTxt, @txtOffset);

    # check to be sure this is a valid PNG/MNG/JNG image
    return 0 unless $raf->Read($sig,8) == 8 and $pngLookup{$sig};

    if ($outfile) {
        delete $$et{TextChunkType};
        Write($outfile, $sig) or $err = 1 if $outfile;
        # can only add tags in Main and TextualData tables
        $$et{ADD_PNG} = $et->GetNewTagInfoHash(
            \%Image::ExifTool::PNG::Main,
            \%Image::ExifTool::PNG::TextualData);
        # initialize with same directories, with PNG tags taking priority
        $et->InitWriteDirs(\%pngMap,'PNG');
    } else {
        # disable buffering in FastScan mode
        $$raf{NoBuffer} = 1 if $fastScan;
    }
    my ($fileType, $hdrChunk, $endChunk) = @{$pngLookup{$sig}};
    $et->SetFileType($fileType);  # set the FileType tag
    SetByteOrder('MM'); # PNG files are big-endian
    my $tagTablePtr = GetTagTable('Image::ExifTool::PNG::Main');
    my $mngTablePtr;
    if ($fileType ne 'PNG') {
        $mngTablePtr = GetTagTable('Image::ExifTool::MNG::Main');
    }
    my $verbose = $et->Options('Verbose');
    my $validate = $et->Options('Validate');
    my $out = $et->Options('TextOut');

    # scan ahead to find offsets of all text chunks after IDAT
    if ($outfile) {
        while ($raf->Read($hbuf,8) == 8) {
            my ($len, $chunk) = unpack('Na4',$hbuf);
            last if $len > 0x7fffffff;
            if ($wasDat) {
                last if $noLeapFrog{$chunk}; # (don't move text across these chunks)
                push @txtOffset, $raf->Tell() - 8 if $isTxtChunk{$chunk};
            } elsif ($isDatChunk{$chunk}) {
                $wasDat = $chunk;
            }
            $raf->Seek($len + 4, 1) or last;    # skip chunk data
        }
        $raf->Seek(8,0) or $et->Error('Error seeking in file'), return -1;
        undef $wasDat;
    }

    # process the PNG/MNG/JNG chunks
    undef $noCompressLib;
    for (;;) {
        if ($doTxt) {
            # read text chunks that were found after IDAT so we can write them before
            $raf->Seek(shift(@txtOffset), 0) or $et->Error('Seek error'), last;
            # (this is the IDAT offset if @txtOffset is now empty)
            undef $doTxt unless @txtOffset;
        }
        $n = $raf->Read($hbuf,8);   # read chunk header

        if ($wasEnd) {
            last unless $n; # stop now if normal end of PNG
            $et->WarnOnce("Trailer data after $fileType $endChunk chunk", 1);
            last if $n < 8;
            $$et{SET_GROUP1} = 'Trailer';
        } elsif ($n != 8) {
            $et->Warn("Truncated $fileType image") unless $wasEnd;
            last;
        }
        my ($len, $chunk) = unpack('Na4',$hbuf);
        if ($len > 0x7fffffff) {
            $et->Warn("Invalid $fileType chunk size") unless $wasEnd;
            last;
        }
        if ($verbose) {
            print $out "  Moving $chunk from after IDAT ($len bytes)\n" if $doTxt;
            # don't dump image data chunks in verbose mode (only give count instead)
            if ($datCount and $chunk ne $datChunk) {
                my $s = $datCount > 1 ? 's' : '';
                print $out "$fileType $datChunk ($datCount chunk$s, total $datBytes bytes)\n";
                print $out "$$et{INDENT}(ImageDataHash: $datBytes bytes of $datChunk data)\n" if $hash;
                $datCount = $datBytes = 0;
            }
        }
        unless ($wasHdr) {
            if ($chunk eq $hdrChunk) {
                $wasHdr = 1;
            } elsif ($hdrChunk eq 'IHDR' and $chunk eq 'CgBI') {
                $et->Warn('Non-standard PNG image (Apple iPhone format)');
            } else {
                $et->WarnOnce("$fileType image did not start with $hdrChunk");
            }
        }
        if ($outfile and ($isDatChunk{$chunk} or $chunk eq $endChunk) and @txtOffset) {
            # continue processing here after we move the text chunks from after IDAT
            push @txtOffset, $raf->Tell() - 8;
            $doTxt = 1;     # process text chunks now
            next;
        }
        if ($isDatChunk{$chunk}) {
            if ($fastScan and $fastScan >= 2) {
                $et->VPrint(0,"End processing at $chunk chunk due to FastScan=$fastScan setting");
                last;
            }
            $datChunk = $chunk;
            $datCount++;
            $datBytes += $len;
            $wasDat = $chunk;
        } else {
            $datChunk = '';
        }
        if ($outfile) {
            # add text chunks (including XMP) before any data chunk end chunk
            if ($datChunk or $chunk eq $endChunk) {
                # write iCCP chunk now if requested because AddChunks will try
                # to add it as a text profile chunk if this isn't successful
                # (ie. if Compress::Zlib wasn't available)
                Add_iCCP($et, $outfile);
                AddChunks($et, $outfile) or $err = 1;           # add all text chunks
                AddChunks($et, $outfile, 'IFD0') or $err = 1;   # and eXIf chunk
            } elsif ($chunk eq 'PLTE') {
                # iCCP chunk must come before PLTE (and IDAT, handled above)
                # (ignore errors -- will add later as text profile if this fails)
                Add_iCCP($et, $outfile);
            }
        }
        if ($chunk eq $endChunk) {
            # read CRC
            unless ($raf->Read($cbuf,4) == 4) {
                $et->Warn("Truncated $fileType $endChunk chunk") unless $wasEnd;
                last;
            }
            $verbose and print $out "$fileType $chunk (end of image)\n";
            $wasEnd = 1;
            if ($outfile) {
                # write the IEND/MEND chunk with CRC
                Write($outfile, $hbuf, $cbuf) or $err = 1;
                if ($$et{DEL_GROUP}{Trailer}) {
                    if ($raf->Read($hbuf, 1)) {
                        $verbose and printf $out "  Deleting PNG trailer\n";
                        ++$$et{CHANGED};
                    }
                } else {
                    # copy over any existing trailer data
                    my $tot = 0;
                    for (;;) {
                        $n = $raf->Read($hbuf, 65536) or last;
                        $tot += $n;
                        Write($outfile, $hbuf) or $err = 1;
                    }
                    $tot and $verbose and printf $out "  Copying PNG trailer ($tot bytes)\n";
                }
                last;
            }
            next;
        }
        if ($datChunk) {
            my $chunkSizeLimit = 10000000;  # largest chunk to read into memory
            if ($outfile) {
                # avoid loading very large data chunks into memory
                if ($len > $chunkSizeLimit) {
                    Write($outfile, $hbuf) or $err = 1;
                    Image::ExifTool::CopyBlock($raf, $outfile, $len+4) or $et->Error("Error copying $datChunk");
                    next;
                }
            # skip over data chunks if possible/necessary
            } elsif (not $validate or $len > $chunkSizeLimit) {
                if ($hash) {
                    $et->ImageDataHash($raf, $len);
                    $raf->Read($cbuf, 4) == 4 or $et->Warn('Truncated data'), last;
                } else {
                    $raf->Seek($len + 4, 1) or $et->Warn('Seek error'), last;
                }
                next;
            }
        } elsif ($wasDat and $isTxtChunk{$chunk}) {
            my $msg;
            if (not $outfile) {
                $msg = 'may be ignored by some readers';
            } elsif (defined $doTxt) {  # $doTxt == 0 if we crossed a noLeapFrog chunk
                $msg = "can't be moved"; # (but could be deleted then added back again)
            } else {
                $msg = 'fixed';
            }
            $et->WarnOnce("Text/EXIF chunk(s) found after $$et{FileType} $wasDat ($msg)", 1);
        }
        # read chunk data and CRC
        unless ($raf->Read($dbuf,$len)==$len and $raf->Read($cbuf, 4)==4) {
            $et->Warn("Corrupted $fileType image") unless $wasEnd;
            last;
        }
        $hash->add($dbuf) if $hash and $datChunk;   # add to hash if necessary
        if ($verbose or $validate or ($outfile and not $fastScan)) {
            # check CRC when in verbose mode (since we don't care about speed)
            my $crc = CalculateCRC(\$hbuf, undef, 4);
            $crc = CalculateCRC(\$dbuf, $crc);
            unless ($crc == unpack('N',$cbuf)) {
                my $msg = "Bad CRC for $chunk chunk";
                $outfile ? $et->Error($msg, 1) : $et->Warn($msg);
            }
            if ($datChunk) {
                Write($outfile, $hbuf, $dbuf, $cbuf) or $err = 1 if $outfile;
                next;
            }
            # just skip over any text chunk found after IDAT
            if ($outfile and $wasDat) {
                if ($isTxtChunk{$chunk} and not defined $doTxt) {
                    ++$$et{CHANGED} if $$et{FORCE_WRITE}{PNG};
                    print $out "  Deleting $chunk that was moved ($len bytes)\n" if $verbose;
                    next;
                }
                # done moving text if we hit one of these chunks
                $doTxt = 0 if $noLeapFrog{$chunk};
            }
            if ($verbose) {
                print $out "$fileType $chunk ($len bytes):\n";
                $et->VerboseDump(\$dbuf, Addr => $raf->Tell() - $len - 4) if $verbose > 2;
            }
        }
        # translate case of chunk names that have changed since the first implementation
        if (not $$tagTablePtr{$chunk} and $stdCase{lc $chunk}) {
            my $stdChunk = $stdCase{lc $chunk};
            if ($outfile and ($$et{EDIT_DIRS}{IFD0} or $stdChunk !~ /^[ez]xif$/i)) {
                $et->Warn("Changed $chunk chunk to $stdChunk", 1);
                ++$$et{CHANGED};
            } else {
                $et->Warn("$chunk chunk should be $stdChunk", 1);
            }
            $chunk = $stdCase{lc $chunk};
        }
        # only extract information from chunks in our tables
        my ($theBuff, $outBuff);
        $outBuff = \$theBuff if $outfile;
        if ($$tagTablePtr{$chunk}) {
            FoundPNG($et, $tagTablePtr, $chunk, $dbuf, undef, $outBuff);
        } elsif ($mngTablePtr and $$mngTablePtr{$chunk}) {
            FoundPNG($et, $mngTablePtr, $chunk, $dbuf, undef, $outBuff);
        }
        if ($outfile) {
            if (defined $theBuff) {
                next unless length $theBuff; # empty if we deleted the information
                # change chunk type if necessary
                if ($$et{TextChunkType}) {
                    $chunk = $$et{TextChunkType};
                    delete $$et{TextChunkType};
                }
                $hbuf = pack('Na4', length($theBuff), $chunk);
                $dbuf = $theBuff;
                my $crc = CalculateCRC(\$hbuf, undef, 4);
                $crc = CalculateCRC(\$dbuf, $crc);
                $cbuf = pack('N', $crc);
            }
            Write($outfile, $hbuf, $dbuf, $cbuf) or $err = 1;
        }
    }
    delete $$et{SET_GROUP1};
    return -1 if $outfile and ($err or not $wasEnd);
    return 1;   # this was a valid PNG/MNG/JNG image
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PNG - Read and write PNG meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read and
write PNG (Portable Network Graphics), MNG (Multi-image Network Graphics)
and JNG (JPEG Network Graphics) images.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.libpng.org/pub/png/spec/1.2/>

=item L<http://www.faqs.org/docs/png/>

=item L<http://www.libpng.org/pub/mng/>

=item L<http://www.libpng.org/pub/png/spec/register/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PNG Tags>,
L<Image::ExifTool::TagNames/MNG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

