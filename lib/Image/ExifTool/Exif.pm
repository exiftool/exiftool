#------------------------------------------------------------------------------
# File:         Exif.pm
#
# Description:  Read EXIF/TIFF meta information
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/06/2004 - P. Harvey Moved processing functions from ExifTool
#               03/19/2004 - P. Harvey Check PreviewImage for validity
#               11/11/2004 - P. Harvey Split off maker notes into MakerNotes.pm
#               12/13/2004 - P. Harvey Added AUTOLOAD to load write routines
#
# References:   0) http://www.exif.org/Exif2-2.PDF
#               1) http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf
#               2) http://www.adobe.com/products/dng/pdfs/dng_spec_1_3_0_0.pdf
#               3) http://www.awaresystems.be/imaging/tiff/tifftags.html
#               4) http://www.remotesensing.org/libtiff/TIFFTechNote2.html
#               5) http://www.exif.org/dcf.PDF
#               6) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               7) http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf
#               8) http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html
#               9) http://hul.harvard.edu/jhove/tiff-tags.html
#              10) http://partners.adobe.com/public/developer/en/tiff/TIFFPM6.pdf
#              11) Robert Mucke private communication
#              12) http://www.broomscloset.com/closet/photo/exif/TAG2000-22_DIS12234-2.PDF
#              13) http://www.microsoft.com/whdc/xps/wmphoto.mspx
#              14) http://www.asmail.be/msg0054681802.html
#              15) http://crousseau.free.fr/imgfmt_raw.htm
#              16) http://www.cybercom.net/~dcoffin/dcraw/
#              17) http://www.digitalpreservation.gov/formats/content/tiff_tags.shtml
#              18) http://www.asmail.be/msg0055568584.html
#              19) http://libpsd.graphest.com/files/Photoshop%20File%20Formats.pdf
#              20) http://tiki-lounge.com/~raf/tiff/fields.html
#              21) http://community.roxen.com/developers/idocs/rfc/rfc3949.html
#              22) http://tools.ietf.org/html/draft-ietf-fax-tiff-fx-extension1-01
#              23) MetaMorph Stack (STK) Image File Format:
#                  --> ftp://ftp.meta.moleculardevices.com/support/stack/STK.doc
#              24) http://www.cipa.jp/std/documents/e/DC-008-2012_E.pdf (Exif 2.3)
#              25) Vesa Kivisto private communication (7D)
#              26) Jeremy Brown private communication
#              27) Gregg Lee private communication
#              28) http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/cinemadng/pdfs/CinemaDNG_Format_Specification_v1_1.pdf
#              29) http://www.libtiff.org
#              30) http://geotiff.maptools.org/spec/geotiffhome.html
#              31) https://android.googlesource.com/platform/external/dng_sdk/+/refs/heads/master/source/dng_tag_codes.h
#              32) Jeffry Friedl private communication
#              33) https://www.cipa.jp/std/documents/download_e.html?DC-008-Translation-2023-E (Exif 3.0)
#              IB) Iliah Borg private communication (LibRaw)
#              JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;
use vars qw($VERSION $AUTOLOAD @formatSize @formatName %formatNumber %intFormat
            %lightSource %flash %compression %photometricInterpretation %orientation
            %subfileType %saveForValidate);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::MakerNotes;

$VERSION = '4.46';

sub ProcessExif($$$);
sub WriteExif($$$);
sub CheckExif($$$);
sub RebuildMakerNotes($$$);
sub EncodeExifText($$);
sub ValidateIFD($;$);
sub ValidateImageData($$$;$);
sub AddImageDataHash($$$);
sub ProcessTiffIFD($$$);
sub PrintParameter($$$);
sub GetOffList($$$$$);
sub PrintOpcode($$$);
sub PrintLensInfo($);
sub InverseOffsetTime($$);
sub ConvertLensInfo($);

# size limit for loading binary data block into memory
sub BINARY_DATA_LIMIT { return 10 * 1024 * 1024; }

# byte sizes for the various EXIF format types below
@formatSize = (undef,1,1,2,4,8,1,1,2,4,8,4,8,4,2,8,8,8,8);
$formatSize[129] = 1; # (Exif 3.0)

@formatName = (
     undef,    'int8u',      'string',     'int16u',
    'int32u',  'rational64u','int8s',      'undef',
    'int16s',  'int32s',     'rational64s','float',
    'double',  'ifd',        'unicode',    'complex',
    'int64u',  'int64s',     'ifd64', # (new BigTIFF formats)
);
$formatName[129] = 'utf8';  # (Exif 3.0)

# hash to look up EXIF format numbers by name
# (format types are all lower case)
%formatNumber = (
    'int8u'       => 1,  # BYTE
    'string'      => 2,  # ASCII
    'int16u'      => 3,  # SHORT
    'int32u'      => 4,  # LONG
    'rational64u' => 5,  # RATIONAL
    'int8s'       => 6,  # SBYTE
    'undef'       => 7,  # UNDEFINED
    'binary'      => 7,  # (same as undef)
    'int16s'      => 8,  # SSHORT
    'int32s'      => 9,  # SLONG
    'rational64s' => 10, # SRATIONAL
    'float'       => 11, # FLOAT
    'double'      => 12, # DOUBLE
    'ifd'         => 13, # IFD (with int32u format)
    'unicode'     => 14, # UNICODE [see Note below]
    'complex'     => 15, # COMPLEX [see Note below]
    'int64u'      => 16, # LONG8 [BigTIFF]
    'int64s'      => 17, # SLONG8 [BigTIFF]
    'ifd64'       => 18, # IFD8 (with int64u format) [BigTIFF]
    'utf8'        => 129,# UTF-8 (Exif 3.0)
    # Note: unicode and complex types are not yet properly supported by ExifTool.
    # These are types which have been observed in the Adobe DNG SDK code, but
    # aren't fully supported there either.  We know the sizes, but that's about it.
    # We don't know if the unicode is null terminated, or the format for complex
    # (although I suspect it would be two 4-byte floats, real and imaginary).
);

# lookup for integer format strings
%intFormat = (
    'int8u'  => 1,
    'int16u' => 3,
    'int32u' => 4,
    'int8s'  => 6,
    'int16s' => 8,
    'int32s' => 9,
    'ifd'    => 13,
    'int64u' => 16,
    'int64s' => 17,
    'ifd64'  => 18,
);

# EXIF LightSource PrintConv values
%lightSource = (
    0 => 'Unknown',
    1 => 'Daylight',
    2 => 'Fluorescent',
    3 => 'Tungsten (Incandescent)',
    4 => 'Flash',
    9 => 'Fine Weather',
    10 => 'Cloudy',
    11 => 'Shade',
    12 => 'Daylight Fluorescent',   # (D 5700 - 7100K)
    13 => 'Day White Fluorescent',  # (N 4600 - 5500K)
    14 => 'Cool White Fluorescent', # (W 3800 - 4500K)
    15 => 'White Fluorescent',      # (WW 3250 - 3800K)
    16 => 'Warm White Fluorescent', # (L 2600 - 3250K)
    17 => 'Standard Light A',
    18 => 'Standard Light B',
    19 => 'Standard Light C',
    20 => 'D55',
    21 => 'D65',
    22 => 'D75',
    23 => 'D50',
    24 => 'ISO Studio Tungsten',
    255 => 'Other',
);

# EXIF Flash values
%flash = (
    OTHER => sub {
        # translate "Off" and "On" when writing
        my ($val, $inv) = @_;
        return undef unless $inv and $val =~ /^(off|on)$/i;
        return lc $val eq 'off' ? 0x00 : 0x01;
    },
    0x00 => 'No Flash',
    0x01 => 'Fired',
    0x05 => 'Fired, Return not detected',
    0x07 => 'Fired, Return detected',
    0x08 => 'On, Did not fire', # not charged up?
    0x09 => 'On, Fired',
    0x0d => 'On, Return not detected',
    0x0f => 'On, Return detected',
    0x10 => 'Off, Did not fire',
    0x14 => 'Off, Did not fire, Return not detected',
    0x18 => 'Auto, Did not fire',
    0x19 => 'Auto, Fired',
    0x1d => 'Auto, Fired, Return not detected',
    0x1f => 'Auto, Fired, Return detected',
    0x20 => 'No flash function',
    0x30 => 'Off, No flash function',
    0x41 => 'Fired, Red-eye reduction',
    0x45 => 'Fired, Red-eye reduction, Return not detected',
    0x47 => 'Fired, Red-eye reduction, Return detected',
    0x49 => 'On, Red-eye reduction',
    0x4d => 'On, Red-eye reduction, Return not detected',
    0x4f => 'On, Red-eye reduction, Return detected',
    0x50 => 'Off, Red-eye reduction',
    0x58 => 'Auto, Did not fire, Red-eye reduction',
    0x59 => 'Auto, Fired, Red-eye reduction',
    0x5d => 'Auto, Fired, Red-eye reduction, Return not detected',
    0x5f => 'Auto, Fired, Red-eye reduction, Return detected',
);

# TIFF Compression values
# (values with format "Xxxxx XXX Compressed" are used to identify RAW file types)
%compression = (
    1 => 'Uncompressed',
    2 => 'CCITT 1D',
    3 => 'T4/Group 3 Fax',
    4 => 'T6/Group 4 Fax',
    5 => 'LZW',
    6 => 'JPEG (old-style)', #3
    7 => 'JPEG', #4
    8 => 'Adobe Deflate', #3
    9 => 'JBIG B&W', #3
    10 => 'JBIG Color', #3
    99 => 'JPEG', #16
    262 => 'Kodak 262', #16
    32766 => 'Next', #3
    32767 => 'Sony ARW Compressed', #16
    32769 => 'Packed RAW', #PH (used by Epson, Nikon, Samsung)
    32770 => 'Samsung SRW Compressed', #PH
    32771 => 'CCIRLEW', #3
    32772 => 'Samsung SRW Compressed 2', #PH (NX3000,NXmini)
    32773 => 'PackBits',
    32809 => 'Thunderscan', #3
    32867 => 'Kodak KDC Compressed', #PH
    32895 => 'IT8CTPAD', #3
    32896 => 'IT8LW', #3
    32897 => 'IT8MP', #3
    32898 => 'IT8BL', #3
    32908 => 'PixarFilm', #3
    32909 => 'PixarLog', #3
  # 32910,32911 - Pixar reserved
    32946 => 'Deflate', #3
    32947 => 'DCS', #3
    33003 => 'Aperio JPEG 2000 YCbCr', #https://openslide.org/formats/aperio/
    33005 => 'Aperio JPEG 2000 RGB', #https://openslide.org/formats/aperio/
    34661 => 'JBIG', #3
    34676 => 'SGILog', #3
    34677 => 'SGILog24', #3
    34712 => 'JPEG 2000', #3
    34713 => 'Nikon NEF Compressed', #PH
    34715 => 'JBIG2 TIFF FX', #20
    34718 => 'Microsoft Document Imaging (MDI) Binary Level Codec', #18
    34719 => 'Microsoft Document Imaging (MDI) Progressive Transform Codec', #18
    34720 => 'Microsoft Document Imaging (MDI) Vector', #18
    34887 => 'ESRI Lerc', #LibTiff
  # 34888,34889 - ESRI reserved
    34892 => 'Lossy JPEG', # (DNG 1.4)
    34925 => 'LZMA2', #LibTiff
    34926 => 'Zstd', #LibTiff
    34927 => 'WebP', #LibTiff
    34933 => 'PNG', # (TIFF mail list)
    34934 => 'JPEG XR', # (TIFF mail list)
    52546 => 'JPEG XL', # (DNG 1.7)
    65000 => 'Kodak DCR Compressed', #PH
    65535 => 'Pentax PEF Compressed', #Jens
);

%photometricInterpretation = (
    0 => 'WhiteIsZero',
    1 => 'BlackIsZero',
    2 => 'RGB',
    3 => 'RGB Palette',
    4 => 'Transparency Mask',
    5 => 'CMYK',
    6 => 'YCbCr',
    8 => 'CIELab',
    9 => 'ICCLab', #3
    10 => 'ITULab', #3
    32803 => 'Color Filter Array', #2
    32844 => 'Pixar LogL', #3
    32845 => 'Pixar LogLuv', #3
    32892 => 'Sequential Color Filter', #JR (Sony ARQ)
    34892 => 'Linear Raw', #2
    51177 => 'Depth Map', # (DNG 1.5)
    52527 => 'Semantic Mask', # (DNG 1.6)
);

%orientation = (
    1 => 'Horizontal (normal)',
    2 => 'Mirror horizontal',
    3 => 'Rotate 180',
    4 => 'Mirror vertical',
    5 => 'Mirror horizontal and rotate 270 CW',
    6 => 'Rotate 90 CW',
    7 => 'Mirror horizontal and rotate 90 CW',
    8 => 'Rotate 270 CW',
);

%subfileType = (
    0 => 'Full-resolution image',
    1 => 'Reduced-resolution image',
    2 => 'Single page of multi-page image',
    3 => 'Single page of multi-page reduced-resolution image',
    4 => 'Transparency mask',
    5 => 'Transparency mask of reduced-resolution image',
    6 => 'Transparency mask of multi-page image',
    7 => 'Transparency mask of reduced-resolution multi-page image',
    8 => 'Depth map', # (DNG 1.5)
    9 => 'Depth map of reduced-resolution image', # (DNG 1.5)
    16 => 'Enhanced image data', # (DNG 1.5)
    0x10001 => 'Alternate reduced-resolution image', # (DNG 1.2)
    0x10004 => 'Semantic Mask', # (DNG 1.6)
    0xffffffff => 'invalid', #(found in E5700 NEF's)
    BITMASK => {
        0 => 'Reduced resolution',
        1 => 'Single page',
        2 => 'Transparency mask',
        3 => 'TIFF/IT final page', #20 (repurposed as DepthMap repurposes by DNG 1.5)
        4 => 'TIFF-FX mixed raster content', #20 (repurposed as EnhancedImageData by DNG 1.5)
    },
);

# PrintConv for parameter tags
%Image::ExifTool::Exif::printParameter = (
    PrintConv => {
        0 => 'Normal',
        OTHER => \&Image::ExifTool::Exif::PrintParameter,
    },
);

# convert DNG UTF-8 string values (may be string or int8u format)
my %utf8StringConv = (
    Writable => 'string',
    Format => 'string',
    ValueConv => '$self->Decode($val, "UTF8")',
    ValueConvInv => '$self->Encode($val,"UTF8")',
);

# ValueConv that makes long values binary type
my %longBin = (
    ValueConv => 'length($val) > 64 ? \$val : $val',
    ValueConvInv => '$val',
    LongBinary => 1,        # flag to avoid decoding values of a large array
);

# PrintConv for SampleFormat (0x153)
my %sampleFormat = (
    1 => 'Unsigned',        # unsigned integer
    2 => 'Signed',          # two's complement signed integer
    3 => 'Float',           # IEEE floating point
    4 => 'Undefined',
    5 => 'Complex int',     # complex integer (ref 3)
    6 => 'Complex float',   # complex IEEE floating point (ref 3)
);

# save the values of these tags for additional validation checks
%saveForValidate = (
    0x100 => 1, # ImageWidth
    0x101 => 1, # ImageHeight
    0x102 => 1, # BitsPerSample
    0x103 => 1, # Compression
    0x115 => 1, # SamplesPerPixel
);

# conversions for DNG OpcodeList tags
my %opcodeInfo = (
    Writable => 'undef',
    WriteGroup => 'SubIFD',
    Protected => 1,
    Binary => 1,
    ConvertBinary => 1, # needed because the ValueConv value is binary
    PrintConvColumns => 2,
    PrintConv => {
        OTHER => \&PrintOpcode,
        1 => 'WarpRectilinear',
        2 => 'WarpFisheye',
        3 => 'FixVignetteRadial',
        4 => 'FixBadPixelsConstant',
        5 => 'FixBadPixelsList',
        6 => 'TrimBounds',
        7 => 'MapTable',
        8 => 'MapPolynomial',
        9 => 'GainMap',
        10 => 'DeltaPerRow',
        11 => 'DeltaPerColumn',
        12 => 'ScalePerRow',
        13 => 'ScalePerColumn',
        14 => 'WarpRectilinear2', # (DNG 1.6)
    },
    PrintConvInv => undef,  # (so the inverse conversion is not performed)
);

# main EXIF tag table
%Image::ExifTool::Exif::Main = (
    GROUPS => { 0 => 'EXIF', 1 => 'IFD0', 2 => 'Image'},
    WRITE_PROC => \&WriteExif,
    CHECK_PROC => \&CheckExif,
    WRITE_GROUP => 'ExifIFD',   # default write group
    SET_GROUP1 => 1, # set group1 name to directory name for all tags in table
    0x1 => {
        Name => 'InteropIndex',
        Description => 'Interoperability Index',
        Protected => 1,
        Writable => 'string',
        WriteGroup => 'InteropIFD',
        PrintConv => {
            R98 => 'R98 - DCF basic file (sRGB)',
            R03 => 'R03 - DCF option file (Adobe RGB)',
            THM => 'THM - DCF thumbnail file',
        },
    },
    0x2 => { #5
        Name => 'InteropVersion',
        Description => 'Interoperability Version',
        Protected => 1,
        Writable => 'undef',
        Mandatory => 1,
        WriteGroup => 'InteropIFD',
        RawConv => '$val=~s/\0+$//; $val',  # (some idiots add null terminators)
    },
    0x0b => { #PH
        Name => 'ProcessingSoftware',
        Writable => 'string',
        WriteGroup => 'IFD0',
        Notes => 'used by ACD Systems Digital Imaging',
    },
    0xfe => {
        Name => 'SubfileType',
        Notes => 'called NewSubfileType by the TIFF specification',
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        # set priority directory if this is the full resolution image
        DataMember => 'SubfileType',
        RawConv => q{
            if ($val == ($val & 0x02)) {
                $self->SetPriorityDir() if $val == 0;
                $$self{PageCount} = ($$self{PageCount} || 0) + 1;
                $$self{MultiPage} = 1 if $val == 2 or $$self{PageCount} > 1;
            }
            $$self{SubfileType} = $val;
        },
        PrintConv => \%subfileType,
    },
    0xff => {
        Name => 'OldSubfileType',
        Notes => 'called SubfileType by the TIFF specification',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        # set priority directory if this is the full resolution image
        RawConv => q{
            if ($val == 1 or $val == 3) {
                $self->SetPriorityDir() if $val == 1;
                $$self{PageCount} = ($$self{PageCount} || 0) + 1;
                $$self{MultiPage} = 1 if $val == 3 or $$self{PageCount} > 1;
            }
            $val;
        },
        PrintConv => {
            1 => 'Full-resolution image',
            2 => 'Reduced-resolution image',
            3 => 'Single page of multi-page image',
        },
    },
    0x100 => {
        Name => 'ImageWidth',
        # even though Group 1 is set dynamically we need to register IFD1 once
        # so it will show up in the group lists
        Groups => { 1 => 'IFD1' },
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        # Note: priority 0 tags automatically have their priority increased for the
        # priority directory (the directory with a SubfileType of "Full-resolution image")
        Priority => 0,
    },
    0x101 => {
        Name => 'ImageHeight',
        Notes => 'called ImageLength by the EXIF spec.',
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Priority => 0,
    },
    0x102 => {
        Name => 'BitsPerSample',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => -1, # can be 1 or 3: -1 means 'variable'
        Priority => 0,
    },
    0x103 => {
        Name => 'Compression',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Mandatory => 1,
        DataMember => 'Compression',
        SeparateTable => 'Compression',
        RawConv => q{
            Image::ExifTool::Exif::IdentifyRawFile($self, $val);
            return $$self{Compression} = $val;
        },
        PrintConv => \%compression,
        Priority => 0,
    },
    0x106 => {
        Name => 'PhotometricInterpretation',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => \%photometricInterpretation,
        Priority => 0,
    },
    0x107 => {
        Name => 'Thresholding',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => {
            1 => 'No dithering or halftoning',
            2 => 'Ordered dither or halftone',
            3 => 'Randomized dither',
        },
    },
    0x108 => {
        Name => 'CellWidth',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x109 => {
        Name => 'CellLength',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x10a => {
        Name => 'FillOrder',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => {
            1 => 'Normal',
            2 => 'Reversed',
        },
    },
    0x10d => {
        Name => 'DocumentName',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x10e => {
        Name => 'ImageDescription',
        Writable => 'string',
        WriteGroup => 'IFD0',
        Priority => 0,
    },
    0x10f => {
        Name => 'Make',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
        WriteGroup => 'IFD0',
        DataMember => 'Make',
        # remove trailing blanks and save as an ExifTool member variable
        RawConv => '$val =~ s/\s+$//; $$self{Make} = $val',
        # NOTE: trailing "blanks" (spaces) are removed from all EXIF tags which
        # may be "unknown" (filled with spaces) according to the EXIF spec.
        # This allows conditional replacement with "exiftool -TAG-= -TAG=VALUE".
        # - also removed are any other trailing whitespace characters
    },
    0x110 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
        WriteGroup => 'IFD0',
        DataMember => 'Model',
        # remove trailing blanks and save as an ExifTool member variable
        RawConv => '$val =~ s/\s+$//; $$self{Model} = $val',
    },
    0x111 => [
        {
            Condition => q[
                $$self{TIFF_TYPE} eq 'MRW' and $$self{DIR_NAME} eq 'IFD0' and
                $$self{Model} =~ /^DiMAGE A200/
            ],
            Name => 'StripOffsets',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x117,  # point to associated byte counts
            # A200 stores this information in the wrong byte order!!
            ValueConv => '$val=join(" ",unpack("N*",pack("V*",split(" ",$val))));\$val',
            ByteOrder => 'LittleEndian',
        },
        {
            Condition => '$$self{Compression} and $$self{Compression} eq "34892"', # DNG Lossy JPEG
            Name => 'OtherImageStart',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x117,  # point to associated byte counts
            DataTag => 'OtherImage',
        },
        {
            # (APP1 IFD2 is for Leica JPEG preview)
            Condition => q[
                not ($$self{TIFF_TYPE} eq 'CR2' and $$self{DIR_NAME} eq 'IFD0') and
                not ($$self{TIFF_TYPE} =~ /^(DNG|TIFF)$/ and $$self{Compression} eq '7' and $$self{SubfileType} ne '0') and
                not ($$self{TIFF_TYPE} eq 'APP1' and $$self{DIR_NAME} eq 'IFD2')
            ],
            Name => 'StripOffsets',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x117,  # point to associated byte counts
            ValueConv => 'length($val) > 32 ? \$val : $val',
        },
        {
            # PreviewImageStart in IFD0 of CR2 images
            Condition => '$$self{TIFF_TYPE} eq "CR2"',
            Name => 'PreviewImageStart',
            IsOffset => 1,
            OffsetPair => 0x117,
            Notes => q{
                called StripOffsets in most locations, but it is PreviewImageStart in IFD0
                of CR2 images and various IFD's of DNG images except for SubIFD2 where it is
                JpgFromRawStart
            },
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
            Permanent => 1,
        },
        {
            # PreviewImageStart in various IFD's of DNG images except SubIFD2
            Condition => '$$self{DIR_NAME} ne "SubIFD2"',
            Name => 'PreviewImageStart',
            IsOffset => 1,
            OffsetPair => 0x117,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'All',    # (writes to specific group of associated Composite tag)
            Protected => 2,
            Permanent => 1,
        },
        {
            # JpgFromRawStart in various IFD's of DNG images except SubIFD2
            Name => 'JpgFromRawStart',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x117,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD2',
            Protected => 2,
            Permanent => 1,
        },
    ],
    0x112 => {
        Name => 'Orientation',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => \%orientation,
        Priority => 0,  # so PRIORITY_DIR takes precedence
    },
    0x115 => {
        Name => 'SamplesPerPixel',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Priority => 0,
    },
    0x116 => {
        Name => 'RowsPerStrip',
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Priority => 0,
    },
    0x117 => [
        {
            Condition => q[
                $$self{TIFF_TYPE} eq 'MRW' and $$self{DIR_NAME} eq 'IFD0' and
                $$self{Model} =~ /^DiMAGE A200/
            ],
            Name => 'StripByteCounts',
            OffsetPair => 0x111,   # point to associated offset
            # A200 stores this information in the wrong byte order!!
            ValueConv => '$val=join(" ",unpack("N*",pack("V*",split(" ",$val))));\$val',
            ByteOrder => 'LittleEndian',
        },
        {
            Condition => '$$self{Compression} and $$self{Compression} eq "34892"', # DNG Lossy JPEG
            Name => 'OtherImageLength',
            OffsetPair => 0x111,   # point to associated offset
            DataTag => 'OtherImage',
        },
        {
            # (APP1 IFD2 is for Leica JPEG preview)
            Condition => q[
                not ($$self{TIFF_TYPE} eq 'CR2' and $$self{DIR_NAME} eq 'IFD0') and
                not ($$self{TIFF_TYPE} =~ /^(DNG|TIFF)$/ and $$self{Compression} eq '7' and $$self{SubfileType} ne '0') and
                not ($$self{TIFF_TYPE} eq 'APP1' and $$self{DIR_NAME} eq 'IFD2')
            ],
            Name => 'StripByteCounts',
            OffsetPair => 0x111,   # point to associated offset
            ValueConv => 'length($val) > 32 ? \$val : $val',
        },
        {
            # PreviewImageLength in IFD0 of CR2 images
            Condition => '$$self{TIFF_TYPE} eq "CR2"',
            Name => 'PreviewImageLength',
            OffsetPair => 0x111,
            Notes => q{
                called StripByteCounts in most locations, but it is PreviewImageLength in
                IFD0 of CR2 images and various IFD's of DNG images except for SubIFD2 where
                it is JpgFromRawLength
            },
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
            Permanent => 1,
        },
        {
            # PreviewImageLength in various IFD's of DNG images except SubIFD2
            Condition => '$$self{DIR_NAME} ne "SubIFD2"',
            Name => 'PreviewImageLength',
            OffsetPair => 0x111,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'All',    # (writes to specific group of associated Composite tag)
            Protected => 2,
            Permanent => 1,
        },
        {
            # JpgFromRawLength in SubIFD2 of DNG images
            Name => 'JpgFromRawLength',
            OffsetPair => 0x111,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD2',
            Protected => 2,
            Permanent => 1,
        },
    ],
    0x118 => {
        Name => 'MinSampleValue',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x119 => {
        Name => 'MaxSampleValue',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
    },
    0x11a => {
        Name => 'XResolution',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Mandatory => 1,
        Priority => 0,  # so PRIORITY_DIR takes precedence
    },
    0x11b => {
        Name => 'YResolution',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Mandatory => 1,
        Priority => 0,
    },
    0x11c => {
        Name => 'PlanarConfiguration',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => {
            1 => 'Chunky',
            2 => 'Planar',
        },
        Priority => 0,
    },
    0x11d => {
        Name => 'PageName',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x11e => {
        Name => 'XPosition',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    0x11f => {
        Name => 'YPosition',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
    },
    # FreeOffsets/FreeByteCounts are used by Ricoh for RMETA information
    # in TIFF images (not yet supported)
    0x120 => {
        Name => 'FreeOffsets',
        IsOffset => 1,
        OffsetPair => 0x121,
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x121 => {
        Name => 'FreeByteCounts',
        OffsetPair => 0x120,
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x122 => {
        Name => 'GrayResponseUnit',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => { #3
            1 => 0.1,
            2 => 0.001,
            3 => 0.0001,
            4 => 0.00001,
            5 => 0.000001,
        },
    },
    0x123 => {
        Name => 'GrayResponseCurve',
        Binary => 1,
    },
    0x124 => {
        Name => 'T4Options',
        PrintConv => { BITMASK => {
            0 => '2-Dimensional encoding',
            1 => 'Uncompressed',
            2 => 'Fill bits added',
        } }, #3
    },
    0x125 => {
        Name => 'T6Options',
        PrintConv => { BITMASK => {
            1 => 'Uncompressed',
        } }, #3
    },
    0x128 => {
        Name => 'ResolutionUnit',
        Notes => 'the value 1 is not standard EXIF',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Mandatory => 1,
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
        Priority => 0,
    },
    0x129 => {
        Name => 'PageNumber',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x12c => 'ColorResponseUnit', #9
    0x12d => {
        Name => 'TransferFunction',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 768,
        Binary => 1,
    },
    0x131 => {
        Name => 'Software',
        Writable => 'string',
        WriteGroup => 'IFD0',
        DataMember => 'Software',
        RawConv => '$val =~ s/\s+$//; $$self{Software} = $val', # trim trailing blanks
    },
    0x132 => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        Notes => 'called DateTime by the EXIF spec.',
        Writable => 'string',
        Shift => 'Time',
        WriteGroup => 'IFD0',
        Validate => 'ValidateExifDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x13b => {
        Name => 'Artist',
        Groups => { 2 => 'Author' },
        Notes => 'becomes a list-type tag when the MWG module is loaded',
        Writable => 'string',
        WriteGroup => 'IFD0',
        RawConv => '$val =~ s/\s+$//; $val', # trim trailing blanks
    },
    0x13c => {
        Name => 'HostComputer',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x13d => {
        Name => 'Predictor',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => {
            1 => 'None',
            2 => 'Horizontal differencing',
            3 => 'Floating point', # (DNG 1.5)
            34892 => 'Horizontal difference X2', # (DNG 1.5)
            34893 => 'Horizontal difference X4', # (DNG 1.5)
            34894 => 'Floating point X2', # (DNG 1.5)
            34895 => 'Floating point X4', # (DNG 1.5)
        },
    },
    0x13e => {
        Name => 'WhitePoint',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x13f => {
        Name => 'PrimaryChromaticities',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 6,
        Priority => 0,
    },
    0x140 => {
        Name => 'ColorMap',
        Format => 'binary',
        Binary => 1,
    },
    0x141 => {
        Name => 'HalftoneHints',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 2,
    },
    0x142 => {
        Name => 'TileWidth',
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x143 => {
        Name => 'TileLength',
        Protected => 1,
        Writable => 'int32u',
        WriteGroup => 'IFD0',
    },
    0x144 => {
        Name => 'TileOffsets',
        IsOffset => 1,
        IsImageData => 1,
        OffsetPair => 0x145,
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x145 => {
        Name => 'TileByteCounts',
        OffsetPair => 0x144,
        ValueConv => 'length($val) > 32 ? \$val : $val',
    },
    0x146 => 'BadFaxLines', #3
    0x147 => { #3
        Name => 'CleanFaxData',
        PrintConv => {
            0 => 'Clean',
            1 => 'Regenerated',
            2 => 'Unclean',
        },
    },
    0x148 => 'ConsecutiveBadFaxLines', #3
    0x14a => [
        {
            Name => 'SubIFD',
            # use this opportunity to identify an ARW image, and if so we
            # must decide if this is a SubIFD or the A100 raw data
            # (use SubfileType, Compression and FILE_TYPE to identify ARW/SR2,
            # then call SetARW to finish the job)
            Condition => q{
                $$self{DIR_NAME} ne 'IFD0' or $$self{FILE_TYPE} ne 'TIFF' or
                $$self{Make} !~ /^SONY/ or
                not $$self{SubfileType} or $$self{SubfileType} != 1 or
                not $$self{Compression} or $$self{Compression} != 6 or
                not require Image::ExifTool::Sony or
                Image::ExifTool::Sony::SetARW($self, $valPt)
            },
            Groups => { 1 => 'SubIFD' },
            Flags => 'SubIFD',
            SubDirectory => {
                Start => '$val',
                MaxSubdirs => 10, # (have seen 5 in a DNG 1.4 image)
            },
        },
        { #16
            Name => 'A100DataOffset',
            Notes => 'the data offset in original Sony DSLR-A100 ARW images',
            DataMember => 'A100DataOffset',
            RawConv => '$$self{A100DataOffset} = $val',
            WriteGroup => 'IFD0', # (only for Validate)
            IsOffset => 1,
            Protected => 2,
        },
    ],
    0x14c => {
        Name => 'InkSet',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => { #3
            1 => 'CMYK',
            2 => 'Not CMYK',
        },
    },
    0x14d => 'InkNames', #3
    0x14e => 'NumberofInks', #3
    0x150 => 'DotRange', # (int8u or int16u)
    0x151 => {
        Name => 'TargetPrinter',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x152 => {
        Name => 'ExtraSamples',
        PrintConv => { #20
            0 => 'Unspecified',
            1 => 'Associated Alpha',
            2 => 'Unassociated Alpha',
        },
    },
    0x153 => {
        Name => 'SampleFormat',
        Notes => 'SamplesPerPixel values',
        WriteGroup => 'SubIFD', # (only for Validate)
        PrintConvColumns => 2,
        PrintConv => [ \%sampleFormat, \%sampleFormat, \%sampleFormat, \%sampleFormat ],
    },
    0x154 => 'SMinSampleValue',
    0x155 => 'SMaxSampleValue',
    0x156 => 'TransferRange',
    0x157 => 'ClipPath', #3
    0x158 => 'XClipPathUnits', #3
    0x159 => 'YClipPathUnits', #3
    0x15a => { #3
        Name => 'Indexed',
        PrintConv => { 0 => 'Not indexed', 1 => 'Indexed' },
    },
    0x15b => {
        Name => 'JPEGTables',
        Binary => 1,
    },
    0x15f => { #10
        Name => 'OPIProxy',
        PrintConv => {
            0 => 'Higher resolution image does not exist',
            1 => 'Higher resolution image exists',
        },
    },
    # 0x181 => 'Decode', #20 (typo! - should be 0x1b1, ref 21)
    # 0x182 => 'DefaultImageColor', #20 (typo! - should be 0x1b2, ref 21)
    0x190 => { #3
        Name => 'GlobalParametersIFD',
        Groups => { 1 => 'GlobParamIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'GlobParamIFD',
            Start => '$val',
            MaxSubdirs => 1,
        },
    },
    0x191 => { #3
        Name => 'ProfileType',
        PrintConv => { 0 => 'Unspecified', 1 => 'Group 3 FAX' },
    },
    0x192 => { #3
        Name => 'FaxProfile',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Minimal B&W lossless, S',
            2 => 'Extended B&W lossless, F',
            3 => 'Lossless JBIG B&W, J',
            4 => 'Lossy color and grayscale, C',
            5 => 'Lossless color and grayscale, L',
            6 => 'Mixed raster content, M',
            7 => 'Profile T', #20
            255 => 'Multi Profiles', #20
        },
    },
    0x193 => { #3
        Name => 'CodingMethods',
        PrintConv => { BITMASK => {
            0 => 'Unspecified compression',
            1 => 'Modified Huffman',
            2 => 'Modified Read',
            3 => 'Modified MR',
            4 => 'JBIG',
            5 => 'Baseline JPEG',
            6 => 'JBIG color',
        } },
    },
    0x194 => 'VersionYear', #3
    0x195 => 'ModeNumber', #3
    0x1b1 => 'Decode', #3
    0x1b2 => 'DefaultImageColor', #3 (changed to ImageBaseColor, ref 21)
    0x1b3 => 'T82Options', #20
    0x1b5 => { #19
        Name => 'JPEGTables',
        Binary => 1,
    },
    0x200 => {
        Name => 'JPEGProc',
        PrintConv => {
            1 => 'Baseline',
            14 => 'Lossless',
        },
    },
    0x201 => [
        {
            Name => 'ThumbnailOffset',
            Notes => q{
                called JPEGInterchangeFormat in the specification, this is ThumbnailOffset
                in IFD1 of JPEG and some TIFF-based images, IFD0 of MRW images and AVI and
                MOV videos, and the SubIFD in IFD1 of SRW images; PreviewImageStart in
                MakerNotes and IFD0 of ARW and SR2 images; JpgFromRawStart in SubIFD of NEF
                images and IFD2 of PEF images; and OtherImageStart in everything else
            },
            # thumbnail is found in IFD1 of JPEG and TIFF images, and
            # IFD0 of EXIF information in FujiFilm AVI (RIFF) and MOV videos
            Condition => q{
                # recognize NRW file from a JPEG-compressed thumbnail in IFD0
                if ($$self{TIFF_TYPE} eq 'NEF' and $$self{DIR_NAME} eq 'IFD0' and $$self{Compression} == 6) {
                    $self->OverrideFileType($$self{TIFF_TYPE} = 'NRW');
                }
                $$self{DIR_NAME} eq 'IFD1' or
                ($$self{DIR_NAME} eq 'IFD0' and $$self{FILE_TYPE} =~ /^(RIFF|MOV)$/)
            },
            IsOffset => 1,
            OffsetPair => 0x202,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD1',
            # according to the EXIF spec. a JPEG-compressed thumbnail image may not
            # be stored in a TIFF file, but these TIFF-based RAW image formats
            # use IFD1 for a JPEG-compressed thumbnail:  CR2, ARW, SR2 and PEF.
            # (SRF also stores a JPEG image in IFD1, but it is actually a preview
            # and we don't yet write SRF anyway)
            WriteCondition => q{
                $$self{FILE_TYPE} ne "TIFF" or
                $$self{TIFF_TYPE} =~ /^(CR2|ARW|SR2|PEF)$/
            },
            Protected => 2,
        },
        {
            Name => 'ThumbnailOffset',
            # thumbnail in IFD0 of MRW images (Minolta A200)
            # and IFD0 of NRW images (Nikon Coolpix P6000,P7000,P7100)
            Condition => '$$self{DIR_NAME} eq "IFD0" and $$self{TIFF_TYPE} =~ /^(MRW|NRW)$/',
            IsOffset => 1,
            OffsetPair => 0x202,
            # A200 uses the wrong base offset for this pointer!!
            WrongBase => '$$self{Model} =~ /^DiMAGE A200/ ? $$self{MRW_WrongBase} : undef',
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'ThumbnailOffset',
            # in SubIFD of IFD1 in Samsung SRW images
            Condition => q{
                $$self{TIFF_TYPE} eq 'SRW' and $$self{DIR_NAME} eq 'SubIFD' and
                $$self{PATH}[-2] eq 'IFD1'
            },
            IsOffset => 1,
            OffsetPair => 0x202,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'PreviewImageStart',
            Condition => '$$self{DIR_NAME} eq "MakerNotes"',
            IsOffset => 1,
            OffsetPair => 0x202,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'PreviewImageStart',
            # PreviewImage in IFD0 of ARW and SR2 files for all models
            Condition => '$$self{DIR_NAME} eq "IFD0" and $$self{TIFF_TYPE} =~ /^(ARW|SR2)$/',
            IsOffset => 1,
            OffsetPair => 0x202,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'JpgFromRawStart',
            Condition => '$$self{DIR_NAME} eq "SubIFD"',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x202,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            # JpgFromRaw is in SubIFD of NEF, NRW and SRW files
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'JpgFromRawStart',
            Condition => '$$self{DIR_NAME} eq "IFD2"',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x202,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'IFD2',
            # JpgFromRaw is in IFD2 of PEF files
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'OtherImageStart',
            Condition => '$$self{DIR_NAME} eq "SubIFD1"',
            IsImageData => 1,
            IsOffset => 1,
            OffsetPair => 0x202,
            DataTag => 'OtherImage',
            Writable => 'int32u',
            WriteGroup => 'SubIFD1',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'OtherImageStart',
            Condition => '$$self{DIR_NAME} eq "SubIFD2"',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x202,
            DataTag => 'OtherImage',
            Writable => 'int32u',
            WriteGroup => 'SubIFD2',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'OtherImageStart',
            IsOffset => 1,
            IsImageData => 1,
            OffsetPair => 0x202,
        },
    ],
    0x202 => [
        {
            Name => 'ThumbnailLength',
            Notes => q{
                called JPEGInterchangeFormatLength in the specification, this is
                ThumbnailLength in IFD1 of JPEG and some TIFF-based images, IFD0 of MRW
                images and AVI and MOV videos, and the SubIFD in IFD1 of SRW images;
                PreviewImageLength in MakerNotes and IFD0 of ARW and SR2 images;
                JpgFromRawLength in SubIFD of NEF images, and IFD2 of PEF images; and
                OtherImageLength in everything else
            },
            Condition => q{
                $$self{DIR_NAME} eq 'IFD1' or
                ($$self{DIR_NAME} eq 'IFD0' and $$self{FILE_TYPE} =~ /^(RIFF|MOV)$/)
            },
            OffsetPair => 0x201,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD1',
            WriteCondition => q{
                $$self{FILE_TYPE} ne "TIFF" or
                $$self{TIFF_TYPE} =~ /^(CR2|ARW|SR2|PEF)$/
            },
            Protected => 2,
        },
        {
            Name => 'ThumbnailLength',
            # thumbnail in IFD0 of MRW images (Minolta A200)
            # and IFD0 of NRW images (Nikon Coolpix P6000,P7000,P7100)
            Condition => '$$self{DIR_NAME} eq "IFD0" and $$self{TIFF_TYPE} =~ /^(MRW|NRW)$/',
            OffsetPair => 0x201,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'ThumbnailLength',
            # in SubIFD of IFD1 in Samsung SRW images
            Condition => q{
                $$self{TIFF_TYPE} eq 'SRW' and $$self{DIR_NAME} eq 'SubIFD' and
                $$self{PATH}[-2] eq 'IFD1'
            },
            OffsetPair => 0x201,
            DataTag => 'ThumbnailImage',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'PreviewImageLength',
            Condition => '$$self{DIR_NAME} eq "MakerNotes"',
            OffsetPair => 0x201,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'PreviewImageLength',
            # PreviewImage in IFD0 of ARW and SR2 files for all models
            Condition => '$$self{DIR_NAME} eq "IFD0" and $$self{TIFF_TYPE} =~ /^(ARW|SR2)$/',
            OffsetPair => 0x201,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'IFD0',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'JpgFromRawLength',
            Condition => '$$self{DIR_NAME} eq "SubIFD"',
            OffsetPair => 0x201,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'SubIFD',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'JpgFromRawLength',
            Condition => '$$self{DIR_NAME} eq "IFD2"',
            OffsetPair => 0x201,
            DataTag => 'JpgFromRaw',
            Writable => 'int32u',
            WriteGroup => 'IFD2',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'OtherImageLength',
            Condition => '$$self{DIR_NAME} eq "SubIFD1"',
            OffsetPair => 0x201,
            DataTag => 'OtherImage',
            Writable => 'int32u',
            WriteGroup => 'SubIFD1',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'OtherImageLength',
            Condition => '$$self{DIR_NAME} eq "SubIFD2"',
            OffsetPair => 0x201,
            DataTag => 'OtherImage',
            Writable => 'int32u',
            WriteGroup => 'SubIFD2',
            Protected => 2,
            Permanent => 1,
        },
        {
            Name => 'OtherImageLength',
            OffsetPair => 0x201,
        },
    ],
    0x203 => 'JPEGRestartInterval',
    0x205 => 'JPEGLosslessPredictors',
    0x206 => 'JPEGPointTransforms',
    0x207 => {
        Name => 'JPEGQTables',
        IsOffset => 1,
        # this tag is not supported for writing, so define an
        # invalid offset pair to cause a "No size tag" error to be
        # generated if we try to write a file containing this tag
        OffsetPair => -1,
    },
    0x208 => {
        Name => 'JPEGDCTables',
        IsOffset => 1,
        OffsetPair => -1, # (see comment for JPEGQTables)
    },
    0x209 => {
        Name => 'JPEGACTables',
        IsOffset => 1,
        OffsetPair => -1, # (see comment for JPEGQTables)
    },
    0x211 => {
        Name => 'YCbCrCoefficients',
        Protected => 1,
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 3,
        Priority => 0,
    },
    0x212 => {
        Name => 'YCbCrSubSampling',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Count => 2,
        PrintConvColumns => 2,
        PrintConv => \%Image::ExifTool::JPEG::yCbCrSubSampling,
        Priority => 0,
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Mandatory => 1,
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
        Priority => 0,
    },
    0x214 => {
        Name => 'ReferenceBlackWhite',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 6,
        Priority => 0,
    },
  # 0x220 - int32u: 0 (IFD0, Xaiomi Redmi models)
  # 0x221 - int32u: 0 (IFD0, Xaiomi Redmi models)
  # 0x222 - int32u: 0 (IFD0, Xaiomi Redmi models)
  # 0x223 - int32u: 0 (IFD0, Xaiomi Redmi models)
  # 0x224 - int32u: 0,1 (IFD0, Xaiomi Redmi models)
  # 0x225 - string: "" (IFD0, Xaiomi Redmi models)
    0x22f => 'StripRowCounts',
    0x2bc => {
        Name => 'ApplicationNotes', # (writable directory!)
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0', # (only for Validate)
        Flags => [ 'Binary', 'Protected' ],
        # this could be an XMP block
        SubDirectory => {
            DirName => 'XMP',
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    0x3e7 => 'USPTOMiscellaneous', #20
    0x1000 => { #5
        Name => 'RelatedImageFileFormat',
        Protected => 1,
        Writable => 'string',
        WriteGroup => 'InteropIFD',
    },
    0x1001 => { #5
        Name => 'RelatedImageWidth',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'InteropIFD',
    },
    0x1002 => { #5
        Name => 'RelatedImageHeight',
        Notes => 'called RelatedImageLength by the DCF spec.',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'InteropIFD',
    },
    # (0x474x tags written by MicrosoftPhoto)
    0x4746 => { #PH
        Name => 'Rating',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Avoid => 1,
    },
    0x4747 => { # (written by Digital Image Pro)
        Name => 'XP_DIP_XML',
        Format => 'undef',
        # the following reference indicates this is Unicode:
        # http://social.msdn.microsoft.com/Forums/en-US/isvvba/thread/ce6edcbb-8fc2-40c6-ad98-85f5d835ddfb
        ValueConv => '$self->Decode($val,"UCS2","II")',
    },
    0x4748 => {
        Name => 'StitchInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Microsoft::Stitch',
            ByteOrder => 'LittleEndian', #PH (NC)
        },
    },
    0x4749 => { #PH
        Name => 'RatingPercent',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Avoid => 1,
    },
    # tags 0x5XXX are obscure tags defined by Microsoft:
    # ref https://learn.microsoft.com/en-us/previous-versions/windows/embedded/ms932271(v=msdn.10)
    # ref https://learn.microsoft.com/en-us/windows/win32/gdiplus/-gdiplus-constant-property-item-descriptions
    0x5001 => { Name => 'ResolutionXUnit', Notes => "ID's from 0x5001 to 0x5113 are obscure tags defined by Microsoft" }, # (int16u)
    0x5002 => 'ResolutionYUnit', # (int16u)
    0x5003 => 'ResolutionXLengthUnit', # (int16u)
    0x5004 => 'ResolutionYLengthUnit', # (int16u)
    0x5005 => 'PrintFlags', # (string)
    0x5006 => 'PrintFlagsVersion', # (int16u)
    0x5007 => 'PrintFlagsCrop', # (int8u)
    0x5008 => 'PrintFlagsBleedWidth', # (int32u)
    0x5009 => 'PrintFlagsBleedWidthScale', # (int16u)
    0x500a => 'HalftoneLPI', # (rational64u)
    0x500b => 'HalftoneLPIUnit', # (int16u, 1=inch, 2=cm)
    0x500c => 'HalftoneDegree', # (rational64u)
    0x500d => 'HalftoneShape', # (int16u,0=round,1=Ellipse,2=Line,3=Square,4=Cross,5=Diamond)
    0x500e => 'HalftoneMisc', # (int32u)
    0x500f => 'HalftoneScreen', # (int8u)
    0x5010 => 'JPEGQuality', # (int32u[N])
    0x5011 => { Name => 'GridSize', Binary => 1 }, # (undef)
    0x5012 => 'ThumbnailFormat', # (int32u,1=raw RGB,2=JPEG)
    0x5013 => 'ThumbnailWidth', # (int32u)
    0x5014 => 'ThumbnailHeight', # (int32u)
    0x5015 => 'ThumbnailColorDepth', # (int16u)
    0x5016 => 'ThumbnailPlanes', # (int16u)
    0x5017 => 'ThumbnailRawBytes', # (int32u)
    0x5018 => 'ThumbnailLength', # (int32u)
    0x5019 => 'ThumbnailCompressedSize', # (int32u)
    0x501a => { Name => 'ColorTransferFunction', Binary => 1 }, # (undef)
    0x501b => { Name => 'ThumbnailData', Binary => 1, Format => 'undef' }, # (int8u)
    0x5020 => 'ThumbnailImageWidth', # (int16u or int32u)
    0x5021 => 'ThumbnailImageHeight', # (int16u or int32u)
    0x5022 => 'ThumbnailBitsPerSample', # (int16u[N])
    0x5023 => 'ThumbnailCompression', # (int16u)
    0x5024 => 'ThumbnailPhotometricInterp', # (int16u)
    0x5025 => 'ThumbnailDescription', # (string)
    0x5026 => 'ThumbnailEquipMake', # (string)
    0x5027 => 'ThumbnailEquipModel', # (string)
    0x5028 => 'ThumbnailStripOffsets', # (int16u or int32u)
    0x5029 => 'ThumbnailOrientation', # (int16u)
    0x502a => 'ThumbnailSamplesPerPixel', # (int16u)
    0x502b => 'ThumbnailRowsPerStrip', # (int16u or int32u)
    0x502c => 'ThumbnailStripByteCounts', # (int16u or int32u)
    0x502d => 'ThumbnailResolutionX',
    0x502e => 'ThumbnailResolutionY',
    0x502f => 'ThumbnailPlanarConfig', # (int16u)
    0x5030 => 'ThumbnailResolutionUnit', # (int16u)
    0x5031 => 'ThumbnailTransferFunction', # (int16u[N])
    0x5032 => 'ThumbnailSoftware', # (string)
    0x5033 => { Name => 'ThumbnailDateTime', Groups => { 2 => 'Time' } }, # (string)
    0x5034 => 'ThumbnailArtist', # (string)
    0x5035 => 'ThumbnailWhitePoint', # (rational64u[2])
    0x5036 => 'ThumbnailPrimaryChromaticities', # (rational64u[6])
    0x5037 => 'ThumbnailYCbCrCoefficients', # (rational64u[3])
    0x5038 => 'ThumbnailYCbCrSubsampling', # (int16u)
    0x5039 => 'ThumbnailYCbCrPositioning', # (int16u)
    0x503a => 'ThumbnailRefBlackWhite', # (rational64u[6])
    0x503b => 'ThumbnailCopyright', # (string)
    0x5090 => 'LuminanceTable', # (int16u[64])
    0x5091 => 'ChrominanceTable', # (int16u[64])
    0x5100 => 'FrameDelay', # (int32u[N])
    0x5101 => 'LoopCount', # (int16u)
    0x5102 => 'GlobalPalette', # (int8u[N])
    0x5103 => 'IndexBackground', # (int8u)
    0x5104 => 'IndexTransparent', # (int8u)
    0x5110 => 'PixelUnits', # (int8u)
    0x5111 => 'PixelsPerUnitX', # (int32u)
    0x5112 => 'PixelsPerUnitY', # (int32u)
    0x5113 => 'PaletteHistogram', # (int8u[N])
    0x7000 => { #JR
        Name => 'SonyRawFileType',
        # (only valid if Sony:FileFormat >= ARW 2.0, ref IB)
        # Writable => 'int16u', (don't allow writes for now)
        PrintConv => {
            0 => 'Sony Uncompressed 14-bit RAW',
            1 => 'Sony Uncompressed 12-bit RAW', #IB
            2 => 'Sony Compressed RAW', # (lossy, ref IB)
            3 => 'Sony Lossless Compressed RAW', #IB
            4 => 'Sony Lossless Compressed RAW 2', #JR (ILCE-1)
        },
    },
    # 0x7001 - int16u[1] (in SubIFD of Sony ARW images) - values: 0,1
    0x7010 => { #IB
        Name => 'SonyToneCurve',
        # int16u[4] (in SubIFD of Sony ARW images -- don't allow writes for now)
        # - only the middle 4 points are stored (lower comes from black level,
        #   and upper from data maximum)
    },
    # 0x7011 - int16u[4] (in SubIFD of Sony ARW images) - values: "0 4912 8212 12287","4000 7200 10050 12075"
    # 0x7020 - int32u[1] (in SubIFD of Sony ARW images) - values: 0,3
    0x7031 => {
        Name => 'VignettingCorrection',
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Permanent => 1,
        Protected => 1,
        PrintConv => {
            256 => 'Off',
            257 => 'Auto',
            272 => 'Auto (ILCE-1)', #JR
            511 => 'No correction params available',
        },
    },
    0x7032 => {
        Name => 'VignettingCorrParams', #forum7640
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Count => 17,
        Permanent => 1,
        Protected => 1,
    },
    0x7034 => {
        Name => 'ChromaticAberrationCorrection',
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Permanent => 1,
        Protected => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            255 => 'No correction params available',
        },
    },
    0x7035 => {
        Name => 'ChromaticAberrationCorrParams', #forum6509
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Count => 33,
        Permanent => 1,
        Protected => 1,
    },
    0x7036 => {
        Name => 'DistortionCorrection',
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Permanent => 1,
        Protected => 1,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            17 => 'Auto fixed by lens',
            255 => 'No correction params available',
        },
    },
    0x7037 => {
        Name => 'DistortionCorrParams', #forum6509
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Count => 17,
        Permanent => 1,
        Protected => 1,
    },
    0x7038 => { #github#195 (Sony ARW)
        Name => 'SonyRawImageSize',
        Notes => 'size of actual image in Sony ARW files',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Permanent => 1,
        Protected => 1,
    },
    0x7310 => { #github#195 (Sony ARW)
        Name => 'BlackLevel',
        Notes => 'found in Sony ARW images',
        Writable => 'int16u',
        WriteGroup => 'SubIFD',
        Count => 4,
        Permanent => 1,
        Protected => 1,
    },
    0x7313 => { #github#195 (Sony ARW)
        Name => 'WB_RGGBLevels',
        Notes => 'found in Sony ARW images',
        Writable => 'int16s',
        WriteGroup => 'SubIFD',
        Count => 4,
        Permanent => 1,
        Protected => 1,
    },
    0x74c7 => { #IB (in ARW images from some Sony cameras)
        Name => 'SonyCropTopLeft',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Permanent => 1,
        Protected => 1,
    },
    0x74c8 => { #IB (in ARW images from some Sony cameras)
        Name => 'SonyCropSize',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Permanent => 1,
        Protected => 1,
    },
    0x800d => 'ImageID', #10
    0x80a3 => { Name => 'WangTag1', Binary => 1 }, #20
    0x80a4 => { Name => 'WangAnnotation', Binary => 1 },
    0x80a5 => { Name => 'WangTag3', Binary => 1 }, #20
    0x80a6 => { #20
        Name => 'WangTag4',
        PrintConv => 'length($val) <= 64 ? $val : \$val',
    },
    # tags 0x80b8-0x80bc are registered to Island Graphics
    0x80b9 => 'ImageReferencePoints', #29
    0x80ba => 'RegionXformTackPoint', #29
    0x80bb => 'WarpQuadrilateral', #29
    0x80bc => 'AffineTransformMat', #29
    0x80e3 => 'Matteing', #9
    0x80e4 => 'DataType', #9
    0x80e5 => 'ImageDepth', #9
    0x80e6 => 'TileDepth', #9
    # tags 0x8214-0x8219 are registered to Pixar
    0x8214 => 'ImageFullWidth', #29
    0x8215 => 'ImageFullHeight', #29
    0x8216 => 'TextureFormat', #29
    0x8217 => 'WrapModes', #29
    0x8218 => 'FovCot', #29
    0x8219 => 'MatrixWorldToScreen', #29
    0x821a => 'MatrixWorldToCamera', #29
    0x827d => 'Model2', #29 (Eastman Kodak)
    0x828d => { #12
        Name => 'CFARepeatPatternDim',
        Protected => 1,
        Writable => 'int16u',
        WriteGroup => 'SubIFD',
        Count => 2,
    },
    0x828e => {
        Name => 'CFAPattern2', #12
        Format => 'int8u',  # (written incorrectly as 'undef' in Nikon NRW images)
        Protected => 1,
        Writable => 'int8u',
        WriteGroup => 'SubIFD',
        Count => -1,
    },
    0x828f => { #12
        Name => 'BatteryLevel',
        Groups => { 2 => 'Camera' },
    },
    0x8290 => {
        Name => 'KodakIFD',
        Groups => { 1 => 'KodakIFD' },
        Flags => 'SubIFD',
        Notes => 'used in various types of Kodak images',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::IFD',
            DirName => 'KodakIFD',
            Start => '$val',
            MaxSubdirs => 1,
        },
    },
    0x8298 => {
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
        Format => 'undef',
        Writable => 'string',
        WriteGroup => 'IFD0',
        Notes => q{
            may contain copyright notices for photographer and editor, separated by a
            newline.  As per the EXIF specification, the newline is replaced by a null
            byte when writing to file, but this may be avoided by disabling the print
            conversion
        },
        # internally the strings are separated by a null character in this format:
        # Photographer only: photographer + NULL
        # Both:              photographer + NULL + editor + NULL
        # Editor only:       SPACE + NULL + editor + NULL
        # (this is done as a RawConv so conditional replaces will work properly)
        RawConv => sub {
            my ($val, $self) = @_;
            $val =~ s/ *\0/\n/;  # translate first NULL to a newline, removing trailing blanks
            $val =~ s/ *\0.*//s; # truncate at second NULL and remove trailing blanks
            $val =~ s/\n$//;     # remove trailing newline if it exists
            # decode if necessary (note: this is the only non-'string' EXIF value like this)
            my $enc = $self->Options('CharsetEXIF');
            $val = $self->Decode($val,$enc) if $enc;
            return $val;
        },
        RawConvInv => '$val . "\0"',
        PrintConvInv => sub {
            my ($val, $self) = @_;
            # encode if necessary (not automatic because Format is 'undef')
            my $enc = $self->Options('CharsetEXIF');
            $val = $self->Encode($val,$enc) if $enc and $val !~ /\0/;
            if ($val =~ /(.*?)\s*[\n\r]+\s*(.*)/s) {
                return $1 unless length $2;
                # photographer copyright set to ' ' if it doesn't exist, according to spec.
                return((length($1) ? $1 : ' ') . "\0" . $2);
            }
            return $val;
        },
    },
    0x829a => {
        Name => 'ExposureTime',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
    },
    0x829d => {
        Name => 'FNumber',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x82a5 => { #3
        Name => 'MDFileTag',
        Notes => 'tags 0x82a5-0x82ac are used in Molecular Dynamics GEL files',
    },
    0x82a6 => 'MDScalePixel', #3
    0x82a7 => 'MDColorTable', #3
    0x82a8 => 'MDLabName', #3
    0x82a9 => 'MDSampleInfo', #3
    0x82aa => 'MDPrepDate', #3
    0x82ab => 'MDPrepTime', #3
    0x82ac => 'MDFileUnits', #3
    0x830e => { #30 (GeoTiff)
        Name => 'PixelScale',
        Writable => 'double',
        WriteGroup => 'IFD0',
        Count => 3,
    },
    0x8335 => 'AdventScale', #20
    0x8336 => 'AdventRevision', #20
    0x835c => 'UIC1Tag', #23
    0x835d => 'UIC2Tag', #23
    0x835e => 'UIC3Tag', #23
    0x835f => 'UIC4Tag', #23
    0x83bb => { #12
        Name => 'IPTC-NAA', # (writable directory! -- but see note below)
        # this should actually be written as 'undef' (see
        # http://www.awaresystems.be/imaging/tiff/tifftags/iptc.html),
        # but Photoshop writes it as int32u and Nikon Capture won't read
        # anything else, so we do the same thing here...  Doh!
        Format => 'undef',      # convert binary values as undef
        Writable => 'int32u',   # but write int32u format code in IFD
        WriteGroup => 'IFD0',
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => {
            DirName => 'IPTC',
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
        # Note: This directory may be written as a block via the IPTC-NAA tag,
        # but this technique is not recommended.  Instead, it is better to
        # write the Extra IPTC tag and let ExifTool decide where it should go.
    },
    0x847e => 'IntergraphPacketData', #3
    0x847f => 'IntergraphFlagRegisters', #3
    0x8480 => { #30 (GeoTiff, obsolete)
        Name => 'IntergraphMatrix',
        Writable => 'double',
        WriteGroup => 'IFD0',
        Count => -1,
    },
    0x8481 => 'INGRReserved', #20
    0x8482 => { #30 (GeoTiff)
        Name => 'ModelTiePoint',
        Groups => { 2 => 'Location' },
        Writable => 'double',
        WriteGroup => 'IFD0',
        Count => -1,
    },
    0x84e0 => 'Site', #9
    0x84e1 => 'ColorSequence', #9
    0x84e2 => 'IT8Header', #9
    0x84e3 => { #9
        Name => 'RasterPadding',
        PrintConv => { #20
            0 => 'Byte',
            1 => 'Word',
            2 => 'Long Word',
            9 => 'Sector',
            10 => 'Long Sector',
        },
    },
    0x84e4 => 'BitsPerRunLength', #9
    0x84e5 => 'BitsPerExtendedRunLength', #9
    0x84e6 => 'ColorTable', #9
    0x84e7 => { #9
        Name => 'ImageColorIndicator',
        PrintConv => { #20
            0 => 'Unspecified Image Color',
            1 => 'Specified Image Color',
        },
    },
    0x84e8 => { #9
        Name => 'BackgroundColorIndicator',
        PrintConv => { #20
            0 => 'Unspecified Background Color',
            1 => 'Specified Background Color',
        },
    },
    0x84e9 => 'ImageColorValue', #9
    0x84ea => 'BackgroundColorValue', #9
    0x84eb => 'PixelIntensityRange', #9
    0x84ec => 'TransparencyIndicator', #9
    0x84ed => 'ColorCharacterization', #9
    0x84ee => { #9
        Name => 'HCUsage',
        PrintConv => { #20
            0 => 'CT',
            1 => 'Line Art',
            2 => 'Trap',
        },
    },
    0x84ef => 'TrapIndicator', #17
    0x84f0 => 'CMYKEquivalent', #17
    0x8546 => { #11
        Name => 'SEMInfo',
        Notes => 'found in some scanning electron microscope images',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0x8568 => {
        Name => 'AFCP_IPTC',
        SubDirectory => {
            # must change directory name so we don't create this directory
            DirName => 'AFCP_IPTC',
            TagTable => 'Image::ExifTool::IPTC::Main',
        },
    },
    0x85b8 => 'PixelMagicJBIGOptions', #20
    0x85d7 => 'JPLCartoIFD', #exifprobe (NC)
    0x85d8 => { #30 (GeoTiff)
        Name => 'ModelTransform',
        Groups => { 2 => 'Location' },
        Writable => 'double',
        WriteGroup => 'IFD0',
        Count => 16,
    },
    0x8602 => { #16
        Name => 'WB_GRGBLevels',
        Notes => 'found in IFD0 of Leaf MOS images',
    },
    # 0x8603 - Leaf CatchLight color matrix (ref 16)
    0x8606 => {
        Name => 'LeafData',
        Format => 'undef',    # avoid converting huge block to string of int8u's!
        SubDirectory => {
            DirName => 'LeafIFD',
            TagTable => 'Image::ExifTool::Leaf::Main',
        },
    },
    0x8649 => { #19
        Name => 'PhotoshopSettings',
        Format => 'binary',
        WriteGroup => 'IFD0', # (only for Validate)
        SubDirectory => {
            DirName => 'Photoshop',
            TagTable => 'Image::ExifTool::Photoshop::Main',
        },
    },
    0x8769 => {
        Name => 'ExifOffset',
        Groups => { 1 => 'ExifIFD' },
        WriteGroup => 'IFD0', # (only for Validate)
        SubIFD => 2,
        SubDirectory => {
            DirName => 'ExifIFD',
            Start => '$val',
        },
    },
    0x8773 => {
        Name => 'ICC_Profile',
        WriteGroup => 'IFD0', # (only for Validate)
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0x877f => { #20
        Name => 'TIFF_FXExtensions',
        PrintConv => { BITMASK => {
            0 => 'Resolution/Image Width',
            1 => 'N Layer Profile M',
            2 => 'Shared Data',
            3 => 'B&W JBIG2',
            4 => 'JBIG2 Profile M',
        }},
    },
    0x8780 => { #20
        Name => 'MultiProfiles',
        PrintConv => { BITMASK => {
            0 => 'Profile S',
            1 => 'Profile F',
            2 => 'Profile J',
            3 => 'Profile C',
            4 => 'Profile L',
            5 => 'Profile M',
            6 => 'Profile T',
            7 => 'Resolution/Image Width',
            8 => 'N Layer Profile M',
            9 => 'Shared Data',
            10 => 'JBIG2 Profile M',
        }},
    },
    0x8781 => { #22
        Name => 'SharedData',
        IsOffset => 1,
        # this tag is not supported for writing, so define an
        # invalid offset pair to cause a "No size tag" error to be
        # generated if we try to write a file containing this tag
        OffsetPair => -1,
    },
    0x8782 => 'T88Options', #20
    0x87ac => 'ImageLayer',
    0x87af => { #30
        Name => 'GeoTiffDirectory',
        Format => 'undef',
        Writable => 'int16u',
        Notes => q{
            these "GeoTiff" tags may read and written as a block, but they aren't
            extracted unless specifically requested.  Byte order changes are handled
            automatically when copying between TIFF images with different byte order
        },
        WriteGroup => 'IFD0',
        Binary => 1,
        RawConv => '$val . GetByteOrder()', # save byte order
        # swap byte order if necessary
        RawConvInv => q{
            return $val if length $val < 2;
            my $order = substr($val, -2);
            return $val unless $order eq 'II' or $order eq 'MM';
            $val = substr($val, 0, -2);
            return $val if $order eq GetByteOrder();
            return pack('v*',unpack('n*',$val));
        },
    },
    0x87b0 => { #30
        Name => 'GeoTiffDoubleParams',
        Format => 'undef',
        Writable => 'double',
        WriteGroup => 'IFD0',
        Binary => 1,
        RawConv => '$val . GetByteOrder()', # save byte order
        # swap byte order if necessary
        RawConvInv => q{
            return $val if length $val < 2;
            my $order = substr($val, -2);
            return $val unless $order eq 'II' or $order eq 'MM';
            $val = substr($val, 0, -2);
            return $val if $order eq GetByteOrder();
            $val =~ s/(.{4})(.{4})/$2$1/sg; # swap words
            return pack('V*',unpack('N*',$val));
        },
    },
    0x87b1 => { #30
        Name => 'GeoTiffAsciiParams',
        Format => 'undef',
        Writable => 'string',
        WriteGroup => 'IFD0',
        Binary => 1,
    },
    0x87be => 'JBIGOptions', #29
    0x8822 => {
        Name => 'ExposureProgram',
        Groups => { 2 => 'Camera' },
        Notes => 'the value of 9 is not standard EXIF, but is used by the Canon EOS 7D',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Not Defined',
            1 => 'Manual',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Creative (Slow speed)',
            6 => 'Action (High speed)',
            7 => 'Portrait',
            8 => 'Landscape',
            9 => 'Bulb', #25
        },
    },
    0x8824 => {
        Name => 'SpectralSensitivity',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
    },
    0x8825 => {
        Name => 'GPSInfo',
        Groups => { 1 => 'GPS' },
        WriteGroup => 'IFD0', # (only for Validate)
        Flags => 'SubIFD',
        SubDirectory => {
            DirName => 'GPS',
            TagTable => 'Image::ExifTool::GPS::Main',
            Start => '$val',
            MaxSubdirs => 1,
        },
    },
    0x8827 => {
        Name => 'ISO',
        Notes => q{
            called ISOSpeedRatings by EXIF 2.2, then PhotographicSensitivity by the EXIF
            2.3 spec.
        },
        Writable => 'int16u',
        Count => -1,
        PrintConv => '$val=~s/\s+/, /g; $val',
        PrintConvInv => '$val=~tr/,//d; $val',
    },
    0x8828 => {
        Name => 'Opto-ElectricConvFactor',
        Notes => 'called OECF by the EXIF spec.',
        Binary => 1,
    },
    0x8829 => 'Interlace', #12
    0x882a => { #12
        Name => 'TimeZoneOffset',
        Writable => 'int16s',
        Count => -1, # can be 1 or 2
        Notes => q{
            1 or 2 values: 1. The time zone offset of DateTimeOriginal from GMT in
            hours, 2. If present, the time zone offset of ModifyDate
        },
    },
    0x882b => { #12
        Name => 'SelfTimerMode',
        Writable => 'int16u',
    },
    0x8830 => { #24
        Name => 'SensitivityType',
        Notes => 'applies to EXIF:ISO tag',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Standard Output Sensitivity',
            2 => 'Recommended Exposure Index',
            3 => 'ISO Speed',
            4 => 'Standard Output Sensitivity and Recommended Exposure Index',
            5 => 'Standard Output Sensitivity and ISO Speed',
            6 => 'Recommended Exposure Index and ISO Speed',
            7 => 'Standard Output Sensitivity, Recommended Exposure Index and ISO Speed',
        },
    },
    0x8831 => { #24
        Name => 'StandardOutputSensitivity',
        Writable => 'int32u',
    },
    0x8832 => { #24
        Name => 'RecommendedExposureIndex',
        Writable => 'int32u',
    },
    0x8833 => { #24
        Name => 'ISOSpeed',
        Writable => 'int32u',
    },
    0x8834 => { #24
        Name => 'ISOSpeedLatitudeyyy',
        Description => 'ISO Speed Latitude yyy',
        Writable => 'int32u',
    },
    0x8835 => { #24
        Name => 'ISOSpeedLatitudezzz',
        Description => 'ISO Speed Latitude zzz',
        Writable => 'int32u',
    },
    0x885c => 'FaxRecvParams', #9
    0x885d => 'FaxSubAddress', #9
    0x885e => 'FaxRecvTime', #9
    0x8871 => 'FedexEDR', #exifprobe (NC)
  # 0x8889 - string: "portrait" (ExifIFD, Xiaomi POCO F1)
    0x888a => { #PH
        Name => 'LeafSubIFD',
        Format => 'int32u',     # Leaf incorrectly uses 'undef' format!
        Groups => { 1 => 'LeafSubIFD' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::SubIFD',
            Start => '$val',
        },
    },
  # 0x8891 - int16u: 35 (ExifIFD, Xiaomi POCO F1)
  # 0x8894 - int16u: 0 (ExifIFD, Xiaomi POCO F1)
  # 0x8895 - int16u: 0 (ExifIFD, Xiaomi POCO F1)
  # 0x889a - int16u: 0 (ExifIFD, Xiaomi POCO F1)
  # 0x89ab - seen "11 100 130 16 0 0 0 0" in IFD0 of TIFF image from IR scanner (forum8470)
    0x9000 => {
        Name => 'ExifVersion',
        Writable => 'undef',
        Mandatory => 1,
        RawConv => '$val=~s/\0+$//; $val',  # (some idiots add null terminators)
        # (allow strings like "2.31" when writing)
        PrintConvInv => '$val=~tr/.//d; $val=~/^\d{4}$/ ? $val : $val =~ /^\d{3}$/ ? "0$val" : undef',
    },
    0x9003 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Notes => 'date/time when original image was taken',
        Writable => 'string',
        Shift => 'Time',
        Validate => 'ValidateExifDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x9004 => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        Notes => 'called DateTimeDigitized by the EXIF spec.',
        Writable => 'string',
        Shift => 'Time',
        Validate => 'ValidateExifDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x9009 => { # undef[44] (or undef[11]) written by Google Plus uploader - PH
        Name => 'GooglePlusUploadCode',
        Format => 'int8u',
        Writable => 'undef',
        Count => -1,
    },
    0x9010 => {
        Name => 'OffsetTime',
        Groups => { 2 => 'Time' },
        Notes => 'time zone for ModifyDate',
        Writable => 'string',
        Shift => 'Time',
        PrintConvInv => \&InverseOffsetTime,
    },
    0x9011 => {
        Name => 'OffsetTimeOriginal',
        Groups => { 2 => 'Time' },
        Notes => 'time zone for DateTimeOriginal',
        Writable => 'string',
        Shift => 'Time',
        PrintConvInv => \&InverseOffsetTime,
    },
    0x9012 => {
        Name => 'OffsetTimeDigitized',
        Groups => { 2 => 'Time' },
        Notes => 'time zone for CreateDate',
        Writable => 'string',
        Shift => 'Time',
        PrintConvInv => \&InverseOffsetTime,
    },
    0x9101 => {
        Name => 'ComponentsConfiguration',
        Format => 'int8u',
        Protected => 1,
        Writable => 'undef',
        Count => 4,
        Mandatory => 1,
        ValueConvInv => '$val=~tr/,//d; $val',  # (so we can copy from XMP with -n)
        PrintConvColumns => 2,
        PrintConv => {
            0 => '-',
            1 => 'Y',
            2 => 'Cb',
            3 => 'Cr',
            4 => 'R',
            5 => 'G',
            6 => 'B',
            OTHER => sub {
                my ($val, $inv, $conv) = @_;
                my @a = split /,?\s+/, $val;
                if ($inv) {
                    my %invConv;
                    $invConv{lc $$conv{$_}} = $_ foreach keys %$conv;
                    # strings like "YCbCr" and "RGB" still work for writing
                    @a = $a[0] =~ /(Y|Cb|Cr|R|G|B)/g if @a == 1;
                    foreach (@a) {
                        $_ = $invConv{lc $_};
                        return undef unless defined $_;
                    }
                    push @a, 0 while @a < 4;
                } else {
                    foreach (@a) {
                        $_ = $$conv{$_} || "Err ($_)";
                    }
                }
                return join ', ', @a;
            },
        },
    },
    0x9102 => {
        Name => 'CompressedBitsPerPixel',
        Protected => 1,
        Writable => 'rational64u',
    },
    # 0x9103 - int16u: 1 (found in Pentax XG-1 samples)
    0x9201 => {
        Name => 'ShutterSpeedValue',
        Notes => 'displayed in seconds, but stored as an APEX value',
        Format => 'rational64s', # Leica M8 patch (incorrectly written as rational64u)
        Writable => 'rational64s',
        ValueConv => 'IsFloat($val) && abs($val)<100 ? 2**(-$val) : 0',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : -100',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x9202 => {
        Name => 'ApertureValue',
        Notes => 'displayed as an F number, but stored as an APEX value',
        Writable => 'rational64u',
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    # Wikipedia: BrightnessValue = Bv = Av + Tv - Sv
    # ExifTool:  LightValue = LV = Av + Tv - Sv + 5 (5 is the Sv for ISO 100 in Exif usage)
    0x9203 => {
        Name => 'BrightnessValue',
        Writable => 'rational64s',
    },
    0x9204 => {
        Name => 'ExposureCompensation',
        Format => 'rational64s', # Leica M8 patch (incorrectly written as rational64u)
        Notes => 'called ExposureBiasValue by the EXIF spec.',
        Writable => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => '$val',
    },
    0x9205 => {
        Name => 'MaxApertureValue',
        Notes => 'displayed as an F number, but stored as an APEX value',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x9206 => {
        Name => 'SubjectDistance',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
        PrintConv => '$val =~ /^(inf|undef)$/ ? $val : "${val} m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    0x9207 => {
        Name => 'MeteringMode',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Average',
            2 => 'Center-weighted average',
            3 => 'Spot',
            4 => 'Multi-spot',
            5 => 'Multi-segment',
            6 => 'Partial',
            255 => 'Other',
        },
    },
    0x9208 => {
        Name => 'LightSource',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        SeparateTable => 'LightSource',
        PrintConv => \%lightSource,
    },
    0x9209 => {
        Name => 'Flash',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        Flags => 'PrintHex',
        SeparateTable => 'Flash',
        PrintConv => \%flash,
    },
    0x920a => {
        Name => 'FocalLength',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    # Note: tags 0x920b-0x9217 are duplicates of 0xa20b-0xa217
    # (The EXIF standard uses 0xa2xx, but you'll find both in images)
    0x920b => { #12
        Name => 'FlashEnergy',
        Groups => { 2 => 'Camera' },
    },
    0x920c => 'SpatialFrequencyResponse', #12 (not in Fuji images - PH)
    0x920d => 'Noise', #12
    0x920e => 'FocalPlaneXResolution', #12
    0x920f => 'FocalPlaneYResolution', #12
    0x9210 => { #12
        Name => 'FocalPlaneResolutionUnit',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
            4 => 'mm',
            5 => 'um',
        },
    },
    0x9211 => { #12
        Name => 'ImageNumber',
        Writable => 'int32u',
    },
    0x9212 => { #12
        Name => 'SecurityClassification',
        Writable => 'string',
        PrintConv => {
            T => 'Top Secret',
            S => 'Secret',
            C => 'Confidential',
            R => 'Restricted',
            U => 'Unclassified',
        },
    },
    0x9213 => { #12
        Name => 'ImageHistory',
        Writable => 'string',
    },
    0x9214 => {
        Name => 'SubjectArea',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        Count => -1, # 2, 3 or 4 values
    },
    0x9215 => 'ExposureIndex', #12
    0x9216 => 'TIFF-EPStandardID', #12
    0x9217 => { #12
        Name => 'SensingMethod',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            # (values 1 and 6 are not used by corresponding EXIF tag 0xa217)
            1 => 'Monochrome area',
            2 => 'One-chip color area',
            3 => 'Two-chip color area',
            4 => 'Three-chip color area',
            5 => 'Color sequential area',
            6 => 'Monochrome linear',
            7 => 'Trilinear',
            8 => 'Color sequential linear',
        },
    },
    0x923a => 'CIP3DataFile', #20
    0x923b => 'CIP3Sheet', #20
    0x923c => 'CIP3Side', #20
    0x923f => 'StoNits', #9
    # handle maker notes as a conditional list
    0x927c => \@Image::ExifTool::MakerNotes::Main,
    0x9286 => {
        Name => 'UserComment',
        # I have seen other applications write it incorrectly as 'string' or 'int8u'
        Format => 'undef',
        Writable => 'undef',
        RawConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,1,$tag)',
        #  (starts with "ASCII\0\0\0", "UNICODE\0", "JIS\0\0\0\0\0" or "\0\0\0\0\0\0\0\0")
        RawConvInv => 'Image::ExifTool::Exif::EncodeExifText($self,$val)',
        # SHOULD ADD SPECIAL LOGIC TO ALLOW CONDITIONAL OVERWRITE OF
        # "UNKNOWN" VALUES FILLED WITH SPACES
    },
    0x9290 => {
        Name => 'SubSecTime',
        Groups => { 2 => 'Time' },
        Notes => 'fractional seconds for ModifyDate',
        Writable => 'string',
        ValueConv => '$val=~s/ +$//; $val', # trim trailing blanks
        # extract fractional seconds from a full date/time value
        ValueConvInv => '$val=~/^(\d+)\s*$/ ? $1 : ($val=~/\.(\d+)/ ? $1 : undef)',
    },
    0x9291 => {
        Name => 'SubSecTimeOriginal',
        Groups => { 2 => 'Time' },
        Notes => 'fractional seconds for DateTimeOriginal',
        Writable => 'string',
        ValueConv => '$val=~s/ +$//; $val', # trim trailing blanks
        ValueConvInv => '$val=~/^(\d+)\s*$/ ? $1 : ($val=~/\.(\d+)/ ? $1 : undef)',
    },
    0x9292 => {
        Name => 'SubSecTimeDigitized',
        Groups => { 2 => 'Time' },
        Notes => 'fractional seconds for CreateDate',
        Writable => 'string',
        ValueConv => '$val=~s/ +$//; $val', # trim trailing blanks
        ValueConvInv => '$val=~/^(\d+)\s*$/ ? $1 : ($val=~/\.(\d+)/ ? $1 : undef)',
    },
    # The following 3 tags are found in MSOffice TIFF images
    # References:
    # http://social.msdn.microsoft.com/Forums/en-US/os_standocs/thread/03086d55-294a-49d5-967a-5303d34c40f8/
    # http://blogs.msdn.com/openspecification/archive/2009/12/08/details-of-three-tiff-tag-extensions-that-microsoft-office-document-imaging-modi-software-may-write-into-the-tiff-files-it-generates.aspx
    # http://www.microsoft.com/downloads/details.aspx?FamilyID=0dbc435d-3544-4f4b-9092-2f2643d64a39&displaylang=en#filelist
    0x932f => 'MSDocumentText',
    0x9330 => {
        Name => 'MSPropertySetStorage',
        Binary => 1,
    },
    0x9331 => {
        Name => 'MSDocumentTextPosition',
        Binary => 1, # (just in case -- don't know what format this is)
    },
    0x935c => { #3/19
        Name => 'ImageSourceData', # (writable directory!)
        Writable => 'undef',
        WriteGroup => 'IFD0',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::DocumentData' },
        Binary => 1,
        Protected => 1,     # (because this can be hundreds of megabytes)
        ReadFromRAF => 1,   # don't load into memory when reading
    },
    0x9400 => {
        Name => 'AmbientTemperature',
        Notes => 'ambient temperature in degrees C, called Temperature by the EXIF spec.',
        Writable => 'rational64s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    0x9401 => {
        Name => 'Humidity',
        Notes => 'ambient relative humidity in percent',
        Writable => 'rational64u',
    },
    0x9402 => {
        Name => 'Pressure',
        Notes => 'air pressure in hPa or mbar',
        Writable => 'rational64u',
    },
    0x9403 => {
        Name => 'WaterDepth',
        Notes => 'depth under water in metres, negative for above water',
        Writable => 'rational64s',
    },
    0x9404 => {
        Name => 'Acceleration',
        Notes => 'directionless camera acceleration in units of mGal, or 10-5 m/s2',
        Writable => 'rational64u',
    },
    0x9405 => {
        Name => 'CameraElevationAngle',
        Writable => 'rational64s',
    },
  # 0x9999 - string: camera settings (ExifIFD, Xiaomi POCO F1)
  # 0x9aaa - int8u[2176]: ? (ExifIFD, Xiaomi POCO F1)
    0x9c9b => {
        Name => 'XPTitle',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Notes => q{
            tags 0x9c9b-0x9c9f are used by Windows Explorer; special characters
            in these values are converted to UTF-8 by default, or Windows Latin1
            with the -L option.  XPTitle is ignored by Windows Explorer if
            ImageDescription exists
        },
        ValueConv => '$self->Decode($val,"UCS2","II")',
        ValueConvInv => '$self->Encode($val,"UCS2","II") . "\0\0"',
    },
    0x9c9c => {
        Name => 'XPComment',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        ValueConv => '$self->Decode($val,"UCS2","II")',
        ValueConvInv => '$self->Encode($val,"UCS2","II") . "\0\0"',
    },
    0x9c9d => {
        Name => 'XPAuthor',
        Groups => { 2 => 'Author' },
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Notes => 'ignored by Windows Explorer if Artist exists',
        ValueConv => '$self->Decode($val,"UCS2","II")',
        ValueConvInv => '$self->Encode($val,"UCS2","II") . "\0\0"',
    },
    0x9c9e => {
        Name => 'XPKeywords',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        ValueConv => '$self->Decode($val,"UCS2","II")',
        ValueConvInv => '$self->Encode($val,"UCS2","II") . "\0\0"',
    },
    0x9c9f => {
        Name => 'XPSubject',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        ValueConv => '$self->Decode($val,"UCS2","II")',
        ValueConvInv => '$self->Encode($val,"UCS2","II") . "\0\0"',
    },
    0xa000 => {
        Name => 'FlashpixVersion',
        Writable => 'undef',
        Mandatory => 1,
        RawConv => '$val=~s/\0+$//; $val',  # (some idiots add null terminators)
        PrintConvInv => '$val=~tr/.//d; $val=~/^\d{4}$/ ? $val : undef',
    },
    0xa001 => {
        Name => 'ColorSpace',
        Notes => q{
            the value of 0x2 is not standard EXIF.  Instead, an Adobe RGB image is
            indicated by "Uncalibrated" with an InteropIndex of "R03".  The values
            0xfffd and 0xfffe are also non-standard, and are used by some Sony cameras
        },
        Writable => 'int16u',
        Mandatory => 1,
        PrintHex => 1,
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
            # Sony uses these definitions: (ref JD)
            # 0xffff => 'Adobe RGB', (conflicts with Uncalibrated)
            0xfffe => 'ICC Profile',
            0xfffd => 'Wide Gamut RGB',
        },
    },
    0xa002 => {
        Name => 'ExifImageWidth',
        Notes => 'called PixelXDimension by the EXIF spec.',
        Writable => 'int16u',
        Mandatory => 1,
    },
    0xa003 => {
        Name => 'ExifImageHeight',
        Notes => 'called PixelYDimension by the EXIF spec.',
        Writable => 'int16u',
        Mandatory => 1,
    },
    0xa004 => {
        Name => 'RelatedSoundFile',
        Writable => 'string',
    },
    0xa005 => {
        Name => 'InteropOffset',
        Groups => { 1 => 'InteropIFD' },
        Flags => 'SubIFD',
        Description => 'Interoperability Offset',
        SubDirectory => {
            DirName => 'InteropIFD',
            Start => '$val',
            MaxSubdirs => 1,
        },
    },
    # the following 4 tags found in SubIFD1 of some Samsung SRW images
    0xa010 => {
        Name => 'SamsungRawPointersOffset',
        IsOffset => 1,
        OffsetPair => 0xa011,  # point to associated byte count
    },
    0xa011 => {
        Name => 'SamsungRawPointersLength',
        OffsetPair => 0xa010,  # point to associated offset
    },
    0xa101 => {
        Name => 'SamsungRawByteOrder',
        Format => 'undef',
        # this is written incorrectly as string[1], but is "\0\0MM" or "II\0\0"
        FixedSize => 4,
        Count => 1,
    },
    0xa102 => {
        Name => 'SamsungRawUnknown',
        Unknown => 1,
    },
    0xa20b => {
        Name => 'FlashEnergy',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0xa20c => {
        Name => 'SpatialFrequencyResponse',
        PrintConv => 'Image::ExifTool::Exif::PrintSFR($val)',
    },
    0xa20d => 'Noise',
    0xa20e => {
        Name => 'FocalPlaneXResolution',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0xa20f => {
        Name => 'FocalPlaneYResolution',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0xa210 => {
        Name => 'FocalPlaneResolutionUnit',
        Groups => { 2 => 'Camera' },
        Notes => 'values 1, 4 and 5 are not standard EXIF',
        Writable => 'int16u',
        PrintConv => {
            1 => 'None', # (not standard EXIF)
            2 => 'inches',
            3 => 'cm',
            4 => 'mm',   # (not standard EXIF)
            5 => 'um',   # (not standard EXIF)
        },
    },
    0xa211 => 'ImageNumber',
    0xa212 => 'SecurityClassification',
    0xa213 => 'ImageHistory',
    0xa214 => {
        Name => 'SubjectLocation',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        Count => 2,
    },
    0xa215 => { Name => 'ExposureIndex', Writable => 'rational64u' },
    0xa216 => 'TIFF-EPStandardID',
    0xa217 => {
        Name => 'SensingMethod',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            1 => 'Not defined',
            2 => 'One-chip color area',
            3 => 'Two-chip color area',
            4 => 'Three-chip color area',
            5 => 'Color sequential area',
            7 => 'Trilinear',
            8 => 'Color sequential linear',
            # 15 - used by DJI XT2
        },
    },
    0xa300 => {
        Name => 'FileSource',
        Writable => 'undef',
        ValueConvInv => '($val=~/^\d+$/ and $val < 256) ? chr($val) : $val',
        PrintConv => {
            1 => 'Film Scanner',
            2 => 'Reflection Print Scanner',
            3 => 'Digital Camera',
            # handle the case where Sigma incorrectly gives this tag a count of 4
            "\3\0\0\0" => 'Sigma Digital Camera',
        },
    },
    0xa301 => {
        Name => 'SceneType',
        Writable => 'undef',
        ValueConvInv => 'chr($val & 0xff)',
        PrintConv => {
            1 => 'Directly photographed',
        },
    },
    0xa302 => {
        Name => 'CFAPattern',
        Writable => 'undef',
        RawConv => 'Image::ExifTool::Exif::DecodeCFAPattern($self, $val)',
        RawConvInv => q{
            my @a = split ' ', $val;
            return $val if @a <= 2; # also accept binary data for backward compatibility
            return pack(GetByteOrder() eq 'II' ? 'v2C*' : 'n2C*', @a);
        },
        PrintConv => 'Image::ExifTool::Exif::PrintCFAPattern($val)',
        PrintConvInv => 'Image::ExifTool::Exif::GetCFAPattern($val)',
    },
    0xa401 => {
        Name => 'CustomRendered',
        Writable => 'int16u',
        Notes => q{
            only 0 and 1 are standard EXIF, but other values are used by Apple iOS
            devices
        },
        PrintConv => {
            0 => 'Normal',
            1 => 'Custom',
            2 => 'HDR (no original saved)', #32 non-standard (Apple iOS)
            3 => 'HDR (original saved)',    #32 non-standard (Apple iOS)
            4 => 'Original (for HDR)',      #32 non-standard (Apple iOS)
            6 => 'Panorama', # non-standard (Apple iOS, horizontal or vertical)
            7 => 'Portrait HDR',            #32 non-standard (Apple iOS)
            8 => 'Portrait', # non-standard (Apple iOS, blurred background)
            # 9 - also seen (Apple iOS) (HDR Portrait?)
        },
    },
    0xa402 => {
        Name => 'ExposureMode',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
            2 => 'Auto bracket',
            # have seen 3 from Samsung EX1, NX30, NX200 - PH
        },
    },
    0xa403 => {
        Name => 'WhiteBalance',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        # set Priority to zero to keep this WhiteBalance from overriding the
        # MakerNotes WhiteBalance, since the MakerNotes WhiteBalance and is more
        # accurate and contains more information (if it exists)
        Priority => 0,
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0xa404 => {
        Name => 'DigitalZoomRatio',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0xa405 => {
        Name => 'FocalLengthIn35mmFormat',
        Notes => 'called FocalLengthIn35mmFilm by the EXIF spec.',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0xa406 => {
        Name => 'SceneCaptureType',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        Notes => 'the value of 4 is non-standard, and used by some Samsung models',
        PrintConv => {
            0 => 'Standard',
            1 => 'Landscape',
            2 => 'Portrait',
            3 => 'Night',
            4 => 'Other', # (non-standard Samsung, ref forum 5724)
        },
    },
    0xa407 => {
        Name => 'GainControl',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'Low gain up',
            2 => 'High gain up',
            3 => 'Low gain down',
            4 => 'High gain down',
        },
    },
    0xa408 => {
        Name => 'Contrast',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    0xa409 => {
        Name => 'Saturation',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    0xa40a => {
        Name => 'Sharpness',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    0xa40b => {
        Name => 'DeviceSettingDescription',
        Groups => { 2 => 'Camera' },
        Binary => 1,
    },
    0xa40c => {
        Name => 'SubjectDistanceRange',
        Groups => { 2 => 'Camera' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Macro',
            2 => 'Close',
            3 => 'Distant',
        },
    },
    # 0xa40d - int16u: 0 (GE E1486 TW)
    # 0xa40e - int16u: 1 (GE E1486 TW)
    0xa420 => { Name => 'ImageUniqueID', Writable => 'string' },
    0xa430 => { #24
        Name => 'OwnerName',
        Notes => 'called CameraOwnerName by the EXIF spec.',
        Writable => 'string',
    },
    0xa431 => { #24
        Name => 'SerialNumber',
        Notes => 'called BodySerialNumber by the EXIF spec.',
        Writable => 'string',
    },
    0xa432 => { #24
        Name => 'LensInfo',
        Notes => q{
            4 rational values giving focal and aperture ranges, called LensSpecification
            by the EXIF spec.
        },
        Writable => 'rational64u',
        Count => 4,
        # convert to the form "12-20mm f/3.8-4.5" or "50mm f/1.4"
        PrintConv => \&PrintLensInfo,
        PrintConvInv => \&ConvertLensInfo,
    },
    0xa433 => { Name => 'LensMake',         Writable => 'string' }, #24
    0xa434 => { Name => 'LensModel',        Writable => 'string' }, #24
    0xa435 => { Name => 'LensSerialNumber', Writable => 'string' }, #24
    0xa436 => { Name => 'Title',            Writable => 'string', Avoid => 1 }, #33
    0xa437 => { Name => 'Photographer',     Writable => 'string' }, #33
    0xa438 => { Name => 'ImageEditor',      Writable => 'string' }, #33
    0xa439 => { Name => 'CameraFirmware',          Writable => 'string' }, #33
    0xa43a => { Name => 'RAWDevelopingSoftware',   Writable => 'string' }, #33
    0xa43b => { Name => 'ImageEditingSoftware',    Writable => 'string' }, #33
    0xa43c => { Name => 'MetadataEditingSoftware', Writable => 'string' }, #33
    0xa460 => { #Exif2.32
        Name => 'CompositeImage',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Not a Composite Image',
            2 => 'General Composite Image',
            3 => 'Composite Image Captured While Shooting',
        },
    },
    0xa461 => { #Exif2.32
        Name => 'CompositeImageCount',
        Notes => q{
            2 values: 1. Number of source images, 2. Number of images used.  Called
            SourceImageNumberOfCompositeImage by the EXIF spec.
        },
        Writable => 'int16u',
        Count => 2,
    },
    0xa462 => { #Exif2.32
        Name => 'CompositeImageExposureTimes',
        Notes => q{
            11 or more values: 1. Total exposure time period, 2. Total exposure of all
            source images, 3. Total exposure of all used images, 4. Max exposure time of
            source images, 5. Max exposure time of used images, 6. Min exposure time of
            source images, 7. Min exposure of used images, 8. Number of sequences, 9.
            Number of source images in sequence. 10-N. Exposure times of each source
            image. Called SourceExposureTimesOfCompositeImage by the EXIF spec.
        },
        Writable => 'undef',
        RawConv => sub {
            my $val = shift;
            my @v;
            my $i = 0;
            for (;;) {
                if ($i == 56 or $i == 58) {
                    last if $i + 2 > length $val;
                    push @v, Get16u(\$val, $i);
                    $i += 2;
                } else {
                    last if $i + 8 > length $val;
                    push @v, Image::ExifTool::GetRational64u(\$val, $i);
                    $i += 8;
                }
            }
            return join ' ', @v;
        },
        RawConvInv => sub {
            my $val = shift;
            my @v = split ' ', $val;
            my $i;
            for ($i=0; ; ++$i) {
                last unless defined $v[$i];
                $v[$i] = ($i == 7 or $i == 8) ? Set16u($v[$i]) : Image::ExifTool::SetRational64u($v[$i]);
            }
            return join '', @v;
        },
        PrintConv => sub {
            my $val = shift;
            my @v = split ' ', $val;
            my $i;
            for ($i=0; ; ++$i) {
                last unless defined $v[$i];
                $v[$i] = PrintExposureTime($v[$i]) unless $i == 7 or $i == 8;
            }
            return join ' ', @v;
        },
        PrintConvInv => '$val',
    },
    0xa480 => { Name => 'GDALMetadata',     Writable => 'string', WriteGroup => 'IFD0' }, #3
    0xa481 => { Name => 'GDALNoData',       Writable => 'string', WriteGroup => 'IFD0' }, #3
    0xa500 => { Name => 'Gamma',            Writable => 'rational64u' },
    0xafc0 => 'ExpandSoftware', #JD (Opanda)
    0xafc1 => 'ExpandLens', #JD (Opanda)
    0xafc2 => 'ExpandFilm', #JD (Opanda)
    0xafc3 => 'ExpandFilterLens', #JD (Opanda)
    0xafc4 => 'ExpandScanner', #JD (Opanda)
    0xafc5 => 'ExpandFlashLamp', #JD (Opanda)
    0xb4c3 => { Name => 'HasselbladRawImage', Format => 'undef', Binary => 1 }, #IB
#
# Windows Media Photo / HD Photo (WDP/HDP) tags
#
    0xbc01 => { #13
        Name => 'PixelFormat',
        PrintHex => 1,
        Format => 'undef',
        Notes => q{
            tags 0xbc** are used in Windows HD Photo (HDP and WDP) images. The actual
            PixelFormat values are 16-byte GUID's but the leading 15 bytes,
            '6fddc324-4e03-4bfe-b1853-d77768dc9', have been removed below to avoid
            unnecessary clutter
        },
        ValueConv => q{
            require Image::ExifTool::ASF;
            $val = Image::ExifTool::ASF::GetGUID($val);
            # GUID's are too long, so remove redundant information
            $val =~ s/^6fddc324-4e03-4bfe-b185-3d77768dc9//i and $val = hex($val);
            return $val;
        },
        PrintConv => {
            0x0d => '24-bit RGB',
            0x0c => '24-bit BGR',
            0x0e => '32-bit BGR',
            0x15 => '48-bit RGB',
            0x12 => '48-bit RGB Fixed Point',
            0x3b => '48-bit RGB Half',
            0x18 => '96-bit RGB Fixed Point',
            0x1b => '128-bit RGB Float',
            0x0f => '32-bit BGRA',
            0x16 => '64-bit RGBA',
            0x1d => '64-bit RGBA Fixed Point',
            0x3a => '64-bit RGBA Half',
            0x1e => '128-bit RGBA Fixed Point',
            0x19 => '128-bit RGBA Float',
            0x10 => '32-bit PBGRA',
            0x17 => '64-bit PRGBA',
            0x1a => '128-bit PRGBA Float',
            0x1c => '32-bit CMYK',
            0x2c => '40-bit CMYK Alpha',
            0x1f => '64-bit CMYK',
            0x2d => '80-bit CMYK Alpha',
            0x20 => '24-bit 3 Channels',
            0x21 => '32-bit 4 Channels',
            0x22 => '40-bit 5 Channels',
            0x23 => '48-bit 6 Channels',
            0x24 => '56-bit 7 Channels',
            0x25 => '64-bit 8 Channels',
            0x2e => '32-bit 3 Channels Alpha',
            0x2f => '40-bit 4 Channels Alpha',
            0x30 => '48-bit 5 Channels Alpha',
            0x31 => '56-bit 6 Channels Alpha',
            0x32 => '64-bit 7 Channels Alpha',
            0x33 => '72-bit 8 Channels Alpha',
            0x26 => '48-bit 3 Channels',
            0x27 => '64-bit 4 Channels',
            0x28 => '80-bit 5 Channels',
            0x29 => '96-bit 6 Channels',
            0x2a => '112-bit 7 Channels',
            0x2b => '128-bit 8 Channels',
            0x34 => '64-bit 3 Channels Alpha',
            0x35 => '80-bit 4 Channels Alpha',
            0x36 => '96-bit 5 Channels Alpha',
            0x37 => '112-bit 6 Channels Alpha',
            0x38 => '128-bit 7 Channels Alpha',
            0x39 => '144-bit 8 Channels Alpha',
            0x08 => '8-bit Gray',
            0x0b => '16-bit Gray',
            0x13 => '16-bit Gray Fixed Point',
            0x3e => '16-bit Gray Half',
            0x3f => '32-bit Gray Fixed Point',
            0x11 => '32-bit Gray Float',
            0x05 => 'Black & White',
            0x09 => '16-bit BGR555',
            0x0a => '16-bit BGR565',
            0x13 => '32-bit BGR101010',
            0x3d => '32-bit RGBE',
        },
    },
    0xbc02 => { #13
        Name => 'Transformation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Mirror vertical',
            2 => 'Mirror horizontal',
            3 => 'Rotate 180',
            4 => 'Rotate 90 CW',
            5 => 'Mirror horizontal and rotate 90 CW',
            6 => 'Mirror horizontal and rotate 270 CW',
            7 => 'Rotate 270 CW',
        },
    },
    0xbc03 => { #13
        Name => 'Uncompressed',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0xbc04 => { #13
        Name => 'ImageType',
        PrintConv => { BITMASK => {
            0 => 'Preview',
            1 => 'Page',
        } },
    },
    0xbc80 => 'ImageWidth', #13
    0xbc81 => 'ImageHeight', #13
    0xbc82 => 'WidthResolution', #13
    0xbc83 => 'HeightResolution', #13
    0xbcc0 => { #13
        Name => 'ImageOffset',
        IsOffset => 1,
        IsImageData => 1,
        OffsetPair => 0xbcc1,  # point to associated byte count
    },
    0xbcc1 => { #13
        Name => 'ImageByteCount',
        OffsetPair => 0xbcc0,  # point to associated offset
    },
    0xbcc2 => { #13
        Name => 'AlphaOffset',
        IsOffset => 1,
        IsImageData => 1,
        OffsetPair => 0xbcc3,  # point to associated byte count
    },
    0xbcc3 => { #13
        Name => 'AlphaByteCount',
        OffsetPair => 0xbcc2,  # point to associated offset
    },
    0xbcc4 => { #13
        Name => 'ImageDataDiscard',
        PrintConv => {
            0 => 'Full Resolution',
            1 => 'Flexbits Discarded',
            2 => 'HighPass Frequency Data Discarded',
            3 => 'Highpass and LowPass Frequency Data Discarded',
        },
    },
    0xbcc5 => { #13
        Name => 'AlphaDataDiscard',
        PrintConv => {
            0 => 'Full Resolution',
            1 => 'Flexbits Discarded',
            2 => 'HighPass Frequency Data Discarded',
            3 => 'Highpass and LowPass Frequency Data Discarded',
        },
    },
#
    0xc427 => 'OceScanjobDesc', #3
    0xc428 => 'OceApplicationSelector', #3
    0xc429 => 'OceIDNumber', #3
    0xc42a => 'OceImageLogic', #3
    0xc44f => { Name => 'Annotations', Binary => 1 }, #7/19
    0xc4a5 => {
        Name => 'PrintIM', # (writable directory!)
        # must set Writable here so this tag will be saved with MakerNotes option
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Binary => 1,
        # (don't make Binary/Protected because we can't copy individual PrintIM tags anyway)
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
        PrintConvInv => '$val =~ /^PrintIM/ ? $val : undef',    # quick validation
    },
    0xc519 => { # (Hasselblad X2D)
        Name => 'HasselbladXML',
        Format => 'undef',
        TruncateOK => 1,    # (incorrect size written by X2D)
        SubDirectory => {
            DirName => 'XML',
            TagTable => 'Image::ExifTool::PLIST::Main',
            Start => '$valuePtr + 4',
        },
    },
    0xc51b => { # (Hasselblad H3D)
        Name => 'HasselbladExif',
        Format => 'undef',
        SubDirectory => {
            Start => '$valuePtr',
            Base => '$start',
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessSubTIFF,
            # Writing this is problematic due to the braindead Hasselblad programmers.
            # One problem is that some values run outside the HasselbladExif data so they
            # will be lost if we do a simple copy (which is what we are currently doing
            # by returning undef from the WriteProc), but we can't rebuild this directory
            # by writing it properly because there is an erroneous StripByteCounts value
            # written by the X2D 100C that renders the data unreadable
            WriteProc => sub { return undef },
        },
    },
    0xc573 => { #PH
        Name => 'OriginalFileName',
        Notes => 'used by some obscure software', # (possibly Swizzy Photosmacker?)
        # (it is a 'string', but obscure, so don't make it writable)
    },
    0xc580 => { #20
        Name => 'USPTOOriginalContentType',
        PrintConv => {
            0 => 'Text or Drawing',
            1 => 'Grayscale',
            2 => 'Color',
        },
    },
    # 0xc5d8 - found in CR2 images
    # 0xc5d9 - found in CR2 images
    0xc5e0 => { #forum8153 (CR2 images)
        Name => 'CR2CFAPattern',
        ValueConv => {
            1 => '0 1 1 2',
            2 => '2 1 1 0',
            3 => '1 2 0 1',
            4 => '1 0 2 1',
        },
        PrintConv => {
            '0 1 1 2' => '[Red,Green][Green,Blue]',
            '2 1 1 0' => '[Blue,Green][Green,Red]',
            '1 2 0 1' => '[Green,Blue][Red,Green]',
            '1 0 2 1' => '[Green,Red][Blue,Green]',
        },
    },
#
# DNG tags 0xc6XX, 0xc7XX and 0xcdXX (ref 2 unless otherwise stated)
#
    0xc612 => {
        Name => 'DNGVersion',
        Notes => q{
            tags 0xc612-0xcd48 are defined by the DNG specification unless otherwise
            noted.  See L<https://helpx.adobe.com/photoshop/digital-negative.html> for
            the specification
        },
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 4,
        Protected => 1, # (confuses Apple Preview if written to a TIFF image)
        DataMember => 'DNGVersion',
        RawConv => '$$self{DNGVersion} = $val',
        PrintConv => '$val =~ tr/ /./; $val',
        PrintConvInv => '$val =~ tr/./ /; $val',
    },
    0xc613 => {
        Name => 'DNGBackwardVersion',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 4,
        Protected => 1,
        PrintConv => '$val =~ tr/ /./; $val',
        PrintConvInv => '$val =~ tr/./ /; $val',
    },
    0xc614 => {
        Name => 'UniqueCameraModel',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc615 => {
        Name => 'LocalizedCameraModel',
        WriteGroup => 'IFD0',
        %utf8StringConv,
        PrintConv => '$self->Printable($val, 0)',
        PrintConvInv => '$val',
    },
    0xc616 => {
        Name => 'CFAPlaneColor',
        WriteGroup => 'SubIFD', # (only for Validate)
        PrintConv => q{
            my @cols = qw(Red Green Blue Cyan Magenta Yellow White);
            my @vals = map { $cols[$_] || "Unknown($_)" } split(' ', $val);
            return join(',', @vals);
        },
    },
    0xc617 => {
        Name => 'CFALayout',
        WriteGroup => 'SubIFD', # (only for Validate)
        PrintConv => {
            1 => 'Rectangular',
            2 => 'Even columns offset down 1/2 row',
            3 => 'Even columns offset up 1/2 row',
            4 => 'Even rows offset right 1/2 column',
            5 => 'Even rows offset left 1/2 column',
            # the following are new for DNG 1.3:
            6 => 'Even rows offset up by 1/2 row, even columns offset left by 1/2 column',
            7 => 'Even rows offset up by 1/2 row, even columns offset right by 1/2 column',
            8 => 'Even rows offset down by 1/2 row, even columns offset left by 1/2 column',
            9 => 'Even rows offset down by 1/2 row, even columns offset right by 1/2 column',
        },
    },
    0xc618 => {
        Name => 'LinearizationTable',
        Writable => 'int16u',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
        Binary => 1,
    },
    0xc619 => {
        Name => 'BlackLevelRepeatDim',
        Writable => 'int16u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Protected => 1,
    },
    0xc61a => {
        Name => 'BlackLevel',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
    },
    0xc61b => {
        Name => 'BlackLevelDeltaH',
        %longBin,
        Writable => 'rational64s',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
    },
    0xc61c => {
        Name => 'BlackLevelDeltaV',
        %longBin,
        Writable => 'rational64s',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
    },
    0xc61d => {
        Name => 'WhiteLevel',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
    },
    0xc61e => {
        Name => 'DefaultScale',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Protected => 1,
    },
    0xc61f => {
        Name => 'DefaultCropOrigin',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Protected => 1,
    },
    0xc620 => {
        Name => 'DefaultCropSize',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 2,
        Protected => 1,
    },
    0xc621 => {
        Name => 'ColorMatrix1',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc622 => {
        Name => 'ColorMatrix2',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc623 => {
        Name => 'CameraCalibration1',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc624 => {
        Name => 'CameraCalibration2',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc625 => {
        Name => 'ReductionMatrix1',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc626 => {
        Name => 'ReductionMatrix2',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc627 => {
        Name => 'AnalogBalance',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc628 => {
        Name => 'AsShotNeutral',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc629 => {
        Name => 'AsShotWhiteXY',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 2,
        Protected => 1,
    },
    0xc62a => {
        Name => 'BaselineExposure',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xc62b => {
        Name => 'BaselineNoise',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xc62c => {
        Name => 'BaselineSharpness',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xc62d => {
        Name => 'BayerGreenSplit',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Protected => 1,
    },
    0xc62e => {
        Name => 'LinearResponseLimit',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xc62f => {
        Name => 'CameraSerialNumber',
        Groups => { 2 => 'Camera' },
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc630 => {
        Name => 'DNGLensInfo',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 4,
        PrintConv =>\&PrintLensInfo,
        PrintConvInv => \&ConvertLensInfo,
    },
    0xc631 => {
        Name => 'ChromaBlurRadius',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Protected => 1,
    },
    0xc632 => {
        Name => 'AntiAliasStrength',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Protected => 1,
    },
    0xc633 => {
        Name => 'ShadowScale',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xc634 => [
        {
            Condition => '$$self{TIFF_TYPE} =~ /^(ARW|SR2)$/',
            Name => 'SR2Private',
            Groups => { 1 => 'SR2' },
            Flags => 'SubIFD',
            Format => 'int32u',
            # some utilities have problems unless this is int8u format:
            # - Adobe Camera Raw 5.3 gives an error
            # - Apple Preview 10.5.8 gets the wrong white balance
            FixFormat => 'int8u', # (stupid Sony)
            WriteGroup => 'IFD0', # (for Validate)
            SubDirectory => {
                DirName => 'SR2Private',
                TagTable => 'Image::ExifTool::Sony::SR2Private',
                Start => '$val',
            },
        },
        {
            Condition => '$$valPt =~ /^Adobe\0/',
            Name => 'DNGAdobeData',
            Flags => [ 'Binary', 'Protected' ],
            Writable => 'undef', # (writable directory!) (to make it possible to delete this mess)
            WriteGroup => 'IFD0',
            NestedHtmlDump => 1,
            SubDirectory => { TagTable => 'Image::ExifTool::DNG::AdobeData' },
            Format => 'undef',  # but written as int8u (change to undef for speed)
        },
        {
            # Pentax/Samsung models that write AOC maker notes in JPG images:
            # K-5,K-7,K-m,K-x,K-r,K10D,K20D,K100D,K110D,K200D,K2000,GX10,GX20
            # (Note: the following expression also appears in WriteExif.pl)
            Condition => q{
                $$valPt =~ /^(PENTAX |SAMSUNG)\0/ and
                $$self{Model} =~ /\b(K(-[57mrx]|(10|20|100|110|200)D|2000)|GX(10|20))\b/
            },
            Name => 'MakerNotePentax',
            MakerNotes => 1,    # (causes "MakerNotes header" to be identified in HtmlDump output)
            Binary => 1,
            WriteGroup => 'IFD0', # (for Validate)
            # Note: Don't make this block-writable for a few reasons:
            # 1) It would be dangerous (possibly confusing Pentax software)
            # 2) It is a different format from the JPEG version of MakerNotePentax
            # 3) It is converted to JPEG format by RebuildMakerNotes() when copying
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::Main',
                Start => '$valuePtr + 10',
                Base => '$start - 10',
                ByteOrder => 'Unknown', # easier to do this than read byteorder word
            },
            Format => 'undef',  # but written as int8u (change to undef for speed)
        },
        {
            # must duplicate the above tag with a different name for more recent
            # Pentax models which use the "PENTAX" instead of the "AOC" maker notes
            # in JPG images (needed when copying maker notes from DNG to JPG)
            Condition => '$$valPt =~ /^(PENTAX |SAMSUNG)\0/',
            Name => 'MakerNotePentax5',
            MakerNotes => 1,
            Binary => 1,
            WriteGroup => 'IFD0', # (for Validate)
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::Main',
                Start => '$valuePtr + 10',
                Base => '$start - 10',
                ByteOrder => 'Unknown',
            },
            Format => 'undef',
        },
        {
            # Ricoh models such as the GR III
            Condition => '$$valPt =~ /^RICOH\0(II|MM)/',
            Name => 'MakerNoteRicohPentax',
            MakerNotes => 1,
            Binary => 1,
            WriteGroup => 'IFD0', # (for Validate)
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::Main',
                Start => '$valuePtr + 8',
                Base => '$start - 8',
                ByteOrder => 'Unknown',
            },
            Format => 'undef',
        },
        # the DJI FC2103 writes some interesting stuff here (with sections labelled
        # awb_dbg_info, ae_dbg_info, ae_histogram_info, af_dbg_info, hiso, xidiri) - PH
        {
            Name => 'MakerNoteDJIInfo',
            Condition => '$$valPt =~ /^\[ae_dbg_info:/',
            MakerNotes => 1,
            Binary => 1,
            WriteGroup => 'IFD0', # (for Validate)
            SubDirectory => { TagTable => 'Image::ExifTool::DJI::Info' },
            Format => 'undef',
        },
        {
            Name => 'DNGPrivateData',
            Flags => [ 'Binary', 'Protected' ],
            Format => 'undef',
            Writable => 'int8u',
            WriteGroup => 'IFD0',
        },
    ],
    0xc635 => {
        Name => 'MakerNoteSafety',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        PrintConv => {
            0 => 'Unsafe',
            1 => 'Safe',
        },
    },
    0xc640 => { #15
        Name => 'RawImageSegmentation',
        # (int16u[3], not writable)
        Notes => q{
            used in segmented Canon CR2 images.  3 numbers: 1. Number of segments minus
            one; 2. Pixel width of segments except last; 3. Pixel width of last segment
        },
    },
    0xc65a => {
        Name => 'CalibrationIlluminant1',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Protected => 1,
        SeparateTable => 'LightSource',
        PrintConv => \%lightSource,
    },
    0xc65b => {
        Name => 'CalibrationIlluminant2',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Protected => 1,
        SeparateTable => 'LightSource',
        PrintConv => \%lightSource,
    },
    0xc65c => {
        Name => 'BestQualityScale',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Protected => 1,
    },
    0xc65d => {
        Name => 'RawDataUniqueID',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 16,
        Protected => 1,
        ValueConv => 'uc(unpack("H*",$val))',
        ValueConvInv => 'pack("H*", $val)',
    },
    0xc660 => { #3
        Name => 'AliasLayerMetadata',
        Notes => 'used by Alias Sketchbook Pro',
    },
    0xc68b => {
        Name => 'OriginalRawFileName',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc68c => {
        Name => 'OriginalRawFileData', # (writable directory!)
        Writable => 'undef', # must be defined here so tag will be extracted if specified
        WriteGroup => 'IFD0',
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => {
            TagTable => 'Image::ExifTool::DNG::OriginalRaw',
        },
    },
    0xc68d => {
        Name => 'ActiveArea',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => 4,
        Protected => 1,
    },
    0xc68e => {
        Name => 'MaskedAreas',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
    },
    0xc68f => {
        Name => 'AsShotICCProfile', # (writable directory)
        Binary => 1,
        Writable => 'undef', # must be defined here so tag will be extracted if specified
        WriteGroup => 'IFD0',
        Protected => 1,
        WriteCheck => q{
            require Image::ExifTool::ICC_Profile;
            return Image::ExifTool::ICC_Profile::ValidateICC(\$val);
        },
        SubDirectory => {
            DirName => 'AsShotICCProfile',
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0xc690 => {
        Name => 'AsShotPreProfileMatrix',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc691 => {
        Name => 'CurrentICCProfile', # (writable directory)
        Binary => 1,
        Writable => 'undef', # must be defined here so tag will be extracted if specified
        SubDirectory => {
            DirName => 'CurrentICCProfile',
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Protected => 1,
        WriteCheck => q{
            require Image::ExifTool::ICC_Profile;
            return Image::ExifTool::ICC_Profile::ValidateICC(\$val);
        },
    },
    0xc692 => {
        Name => 'CurrentPreProfileMatrix',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc6bf => {
        Name => 'ColorimetricReference',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Protected => 1,
        PrintConv => {
            0 => 'Scene-referred',
            1 => 'Output-referred (ICC Profile Dynamic Range)',
            2 => 'Output-referred (High Dyanmic Range)', # DNG 1.7
        },
    },
    0xc6c5 => { Name => 'SRawType', Description => 'SRaw Type', WriteGroup => 'IFD0' }, #exifprobe (CR2 proprietary)
    0xc6d2 => { #JD (Panasonic DMC-TZ5)
        # this text is UTF-8 encoded (hooray!) - PH (TZ5)
        Name => 'PanasonicTitle',
        Format => 'string', # written incorrectly as 'undef'
        Notes => 'proprietary Panasonic tag used for baby/pet name, etc',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        # panasonic always records this tag (64 zero bytes),
        # so ignore it unless it contains valid information
        RawConv => 'length($val) ? $val : undef',
        ValueConv => '$self->Decode($val, "UTF8")',
        ValueConvInv => '$self->Encode($val,"UTF8")',
    },
    0xc6d3 => { #PH (Panasonic DMC-FS7)
        Name => 'PanasonicTitle2',
        Format => 'string', # written incorrectly as 'undef'
        Notes => 'proprietary Panasonic tag used for baby/pet name with age',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        # panasonic always records this tag (128 zero bytes),
        # so ignore it unless it contains valid information
        RawConv => 'length($val) ? $val : undef',
        ValueConv => '$self->Decode($val, "UTF8")',
        ValueConvInv => '$self->Encode($val,"UTF8")',
    },
    # 0xc6dc - int32u[4]: found in CR2 images (PH, 7DmkIII)
    # 0xc6dd - int16u[256]: found in CR2 images (PH, 5DmkIV)
    0xc6f3 => {
        Name => 'CameraCalibrationSig',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc6f4 => {
        Name => 'ProfileCalibrationSig',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc6f5 => {
        Name => 'ProfileIFD', # (ExtraCameraProfiles)
        Groups => { 1 => 'ProfileIFD' },
        Flags => 'SubIFD',
        WriteGroup => 'IFD0', # (only for Validate)
        SubDirectory => {
            ProcessProc => \&ProcessTiffIFD,
            WriteProc => \&ProcessTiffIFD,
            DirName => 'ProfileIFD',
            Start => '$val',
            Base => '$start',   # offsets relative to start of TIFF-like header
            MaxSubdirs => 10,
            Magic => 0x4352,    # magic number for TIFF-like header
        },
    },
    0xc6f6 => {
        Name => 'AsShotProfileName',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc6f7 => {
        Name => 'NoiseReductionApplied',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Protected => 1,
    },
    0xc6f8 => {
        Name => 'ProfileName',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc6f9 => {
        Name => 'ProfileHueSatMapDims',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Count => 3,
        Protected => 1,
    },
    0xc6fa => {
        Name => 'ProfileHueSatMapData1',
        %longBin,
        Writable => 'float',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc6fb => {
        Name => 'ProfileHueSatMapData2',
        %longBin,
        Writable => 'float',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc6fc => {
        Name => 'ProfileToneCurve',
        %longBin,
        Writable => 'float',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc6fd => {
        Name => 'ProfileEmbedPolicy',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Protected => 1,
        PrintConv => {
            0 => 'Allow Copying',
            1 => 'Embed if Used',
            2 => 'Never Embed',
            3 => 'No Restrictions',
        },
    },
    0xc6fe => {
        Name => 'ProfileCopyright',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc714 => {
        Name => 'ForwardMatrix1',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc715 => {
        Name => 'ForwardMatrix2',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc716 => {
        Name => 'PreviewApplicationName',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc717 => {
        Name => 'PreviewApplicationVersion',
        Writable => 'string',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc718 => {
        Name => 'PreviewSettingsName',
        Writable => 'string',
        WriteGroup => 'IFD0',
        Protected => 1,
        %utf8StringConv,
    },
    0xc719 => {
        Name => 'PreviewSettingsDigest',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Protected => 1,
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
    0xc71a => {
        Name => 'PreviewColorSpace',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Protected => 1,
        PrintConv => {
            0 => 'Unknown',
            1 => 'Gray Gamma 2.2',
            2 => 'sRGB',
            3 => 'Adobe RGB',
            4 => 'ProPhoto RGB',
        },
    },
    0xc71b => {
        Name => 'PreviewDateTime',
        Groups => { 2 => 'Time' },
        Writable => 'string',
        Shift => 'Time',
        WriteGroup => 'IFD0',
        Protected => 1,
        ValueConv => q{
            require Image::ExifTool::XMP;
            return Image::ExifTool::XMP::ConvertXMPDate($val);
        },
        ValueConvInv => q{
            require Image::ExifTool::XMP;
            return Image::ExifTool::XMP::FormatXMPDate($val);
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,1,1)',
    },
    0xc71c => {
        Name => 'RawImageDigest',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 16,
        Protected => 1,
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
    0xc71d => {
        Name => 'OriginalRawFileDigest',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 16,
        Protected => 1,
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
    0xc71e => 'SubTileBlockSize',
    0xc71f => 'RowInterleaveFactor',
    0xc725 => {
        Name => 'ProfileLookTableDims',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Count => 3,
        Protected => 1,
    },
    0xc726 => {
        Name => 'ProfileLookTableData',
        %longBin,
        Writable => 'float',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xc740 => { Name => 'OpcodeList1', %opcodeInfo }, # DNG 1.3
    0xc741 => { Name => 'OpcodeList2', %opcodeInfo }, # DNG 1.3
    0xc74e => { Name => 'OpcodeList3', %opcodeInfo }, # DNG 1.3
    0xc761 => { # DNG 1.3
        Name => 'NoiseProfile',
        Writable => 'double',
        WriteGroup => 'SubIFD',
        Count => -1,
        Protected => 1,
    },
    0xc763 => { #28
        Name => 'TimeCodes',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => -1, # (8 * number of time codes, max 10)
        ValueConv => q{
            my @a = split ' ', $val;
            my @v;
            push @v, join('.', map { sprintf('%.2x',$_) } splice(@a,0,8)) while @a >= 8;
            join ' ', @v;
        },
        ValueConvInv => q{
            my @a = map hex, split /[. ]+/, $val;
            join ' ', @a;
        },
        # Note: Currently ignore the flags:
        #   byte 0 0x80 - color frame
        #   byte 0 0x40 - drop frame
        #   byte 1 0x80 - field phase
        PrintConv => q{
            my @a = map hex, split /[. ]+/, $val;
            my @v;
            while (@a >= 8) {
                my $str = sprintf("%.2x:%.2x:%.2x.%.2x", $a[3]&0x3f,
                                 $a[2]&0x7f, $a[1]&0x7f, $a[0]&0x3f);
                if ($a[3] & 0x80) { # date+timezone exist if BGF2 is set
                    my $tz = $a[7] & 0x3f;
                    my $bz = sprintf('%.2x', $tz);
                    $bz = 100 if $bz =~ /[a-f]/i; # not BCD
                    if ($bz < 26) {
                        $tz = ($bz < 13 ? 0 : 26) - $bz;
                    } elsif ($bz == 32) {
                        $tz = 12.75;
                    } elsif ($bz >= 28 and $bz <= 31) {
                        $tz = 0;    # UTC
                    } elsif ($bz < 100) {
                        undef $tz;  # undefined or user-defined
                    } elsif ($tz < 0x20) {
                        $tz = (($tz < 0x10 ? 10 : 20) - $tz) - 0.5;
                    } else {
                        $tz = (($tz < 0x30 ? 53 : 63) - $tz) + 0.5;
                    }
                    if ($a[7] & 0x80) { # MJD format (/w UTC time)
                        my ($h,$m,$s,$f) = split /[:.]/, $str;
                        my $jday = sprintf('%x%.2x%.2x', reverse @a[4..6]);
                        $str = ConvertUnixTime(($jday - 40587) * 24 * 3600
                                 + ((($h+$tz) * 60) + $m) * 60 + $s) . ".$f";
                        $str =~ s/^(\d+):(\d+):(\d+) /$1-$2-${3}T/;
                    } else { # YYMMDD (Note: CinemaDNG 1.1 example seems wrong)
                        my $yr = sprintf('%.2x',$a[6]) + 1900;
                        $yr += 100 if $yr < 1970;
                        $str = sprintf('%d-%.2x-%.2xT%s',$yr,$a[5],$a[4],$str);
                    }
                    $str .= TimeZoneString($tz*60) if defined $tz;
                }
                push @v, $str;
                splice @a, 0, 8;
            }
            join ' ', @v;
        },
        PrintConvInv => q{
            my @a = split ' ', $val;
            my @v;
            foreach (@a) {
                my @td = reverse split /T/;
                my $tz = 0x39; # default to unknown timezone
                if ($td[0] =~ s/([-+])(\d+):(\d+)$//) {
                    if ($3 == 0) {
                        $tz = hex(($1 eq '-') ? $2 : 0x26 - $2);
                    } elsif ($3 == 30) {
                        if ($1 eq '-') {
                            $tz = $2 + 0x0a;
                            $tz += 0x0a if $tz > 0x0f;
                        } else {
                            $tz = 0x3f - $2;
                            $tz -= 0x0a if $tz < 0x3a;
                        }
                    } elsif ($3 == 45) {
                        $tz = 0x32 if $1 eq '+' and $2 == 12;
                    }
                }
                my @t = split /[:.]/, $td[0];
                push @t, '00' while @t < 4;
                my $bg;
                if ($td[1]) {
                    # date was specified: fill in date & timezone
                    my @d = split /[-]/, $td[1];
                    next if @d < 3;
                    $bg = sprintf('.%.2d.%.2d.%.2d.%.2x', $d[2], $d[1], $d[0]%100, $tz);
                    $t[0] = sprintf('%.2x', hex($t[0]) + 0xc0); # set BGF1+BGF2
                } else { # time only
                    $bg = '.00.00.00.00';
                }
                push @v, join('.', reverse(@t[0..3])) . $bg;
            }
            join ' ', @v;
        },
    },
    0xc764 => { #28
        Name => 'FrameRate',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
        PrintConvInv => '$val',
    },
    0xc772 => { #28
        Name => 'TStop',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => -1, # (1 or 2)
        PrintConv => 'join("-", map { sprintf("%.2f",$_) } split " ", $val)',
        PrintConvInv => '$val=~tr/-/ /; $val',
    },
    0xc789 => { #28
        Name => 'ReelName',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc791 => { # DNG 1.4
        Name => 'OriginalDefaultFinalSize',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Count => 2,
        Protected => 1,
    },
    0xc792 => { # DNG 1.4
        Name => 'OriginalBestQualitySize',
        Notes => 'called OriginalBestQualityFinalSize by the DNG spec',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Count => 2,
        Protected => 1,
    },
    0xc793 => { # DNG 1.4
        Name => 'OriginalDefaultCropSize',
        Writable => 'rational64u',
        WriteGroup => 'IFD0',
        Count => 2,
        Protected => 1,
    },
    0xc7a1 => {  #28
        Name => 'CameraLabel',
        Writable => 'string',
        WriteGroup => 'IFD0',
    },
    0xc7a3 => { # DNG 1.4
        Name => 'ProfileHueSatMapEncoding',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Protected => 1,
        PrintConv => {
            0 => 'Linear',
            1 => 'sRGB',
        },
    },
    0xc7a4 => { # DNG 1.4
        Name => 'ProfileLookTableEncoding',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Protected => 1,
        PrintConv => {
            0 => 'Linear',
            1 => 'sRGB',
        },
    },
    0xc7a5 => { # DNG 1.4
        Name => 'BaselineExposureOffset',
        Writable => 'rational64s', # (incorrectly "RATIONAL" in DNG 1.4 spec)
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xc7a6 => { # DNG 1.4
        Name => 'DefaultBlackRender',
        Writable => 'int32u',
        WriteGroup => 'IFD0',
        Protected => 1,
        PrintConv => {
            0 => 'Auto',
            1 => 'None',
        },
    },
    0xc7a7 => { # DNG 1.4
        Name => 'NewRawImageDigest',
        Format => 'undef',
        Writable => 'int8u',
        WriteGroup => 'IFD0',
        Count => 16,
        Protected => 1,
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
    0xc7a8 => { # DNG 1.4
        Name => 'RawToPreviewGain',
        Writable => 'double',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    # 0xc7a9 - CacheBlob (ref 31)
    0xc7aa => { #31 undocumented DNG tag written by LR4 (val=256, related to fast load data?)
        Name => 'CacheVersion',
        Writable => 'int32u',
        WriteGroup => 'SubIFD2',
        Format => 'int8u',
        Count => 4,
        Protected => 1,
        PrintConv => '$val =~ tr/ /./; $val',
        PrintConvInv => '$val =~ tr/./ /; $val',
    },
    0xc7b5 => { # DNG 1.4
        Name => 'DefaultUserCrop',
        Writable => 'rational64u',
        WriteGroup => 'SubIFD',
        Count => 4,
        Protected => 1,
    },
    0xc7d5 => { #PH (in SubIFD1 of Nikon Z6/Z7 NEF images)
        Name => 'NikonNEFInfo',
        Condition => '$$valPt =~ /^Nikon\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::NEFInfo',
            Start => '$valuePtr + 18',
            Base => '$start - 8',
            ByteOrder => 'Unknown',
        },
    },
    # 0xc7d6 - int8u: 1 (SubIFD1 of Nikon Z6/Z7 NEF)
    0xc7e9 => { # DNG 1.5
        Name => 'DepthFormat',
        Writable => 'int16u',
        Notes => 'tags 0xc7e9-0xc7ee added by DNG 1.5.0.0',
        Protected => 1,
        WriteGroup => 'IFD0',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Linear',
            2 => 'Inverse',
        },
    },
    0xc7ea => { # DNG 1.5
        Name => 'DepthNear',
        Writable => 'rational64u',
        Protected => 1,
        WriteGroup => 'IFD0',
    },
    0xc7eb => { # DNG 1.5
        Name => 'DepthFar',
        Writable => 'rational64u',
        Protected => 1,
        WriteGroup => 'IFD0',
    },
    0xc7ec => { # DNG 1.5
        Name => 'DepthUnits',
        Writable => 'int16u',
        Protected => 1,
        WriteGroup => 'IFD0',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Meters',
        },
    },
    0xc7ed => { # DNG 1.5
        Name => 'DepthMeasureType',
        Writable => 'int16u',
        Protected => 1,
        WriteGroup => 'IFD0',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Optical Axis',
            2 => 'Optical Ray',
        },
    },
    0xc7ee => { # DNG 1.5
        Name => 'EnhanceParams',
        Writable => 'string',
        Protected => 1,
        WriteGroup => 'IFD0',
    },
    0xcd2d => { # DNG 1.6
        Name => 'ProfileGainTableMap',
        Writable => 'undef',
        WriteGroup => 'SubIFD', # (according to DNG 1.7 docs, this was an error and it should have been IFD0)
        Protected => 1,
        Binary => 1,
    },
    0xcd2e => { # DNG 1.6
        Name => 'SemanticName',
      # Writable => 'string',
        WriteGroup => 'SubIFD' #? (NC) Semantic Mask IFD (only for Validate)
    },
    0xcd30 => { # DNG 1.6
        Name => 'SemanticInstanceID',
      # Writable => 'string',
        WriteGroup => 'SubIFD' #? (NC) Semantic Mask IFD (only for Validate)
    },
    0xcd31 => { # DNG 1.6
        Name => 'CalibrationIlluminant3',
        Writable => 'int16u',
        WriteGroup => 'IFD0',
        Protected => 1,
        SeparateTable => 'LightSource',
        PrintConv => \%lightSource,
    },
    0xcd32 => { # DNG 1.6
        Name => 'CameraCalibration3',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xcd33 => { # DNG 1.6
        Name => 'ColorMatrix3',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xcd34 => { # DNG 1.6
        Name => 'ForwardMatrix3',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xcd35 => { # DNG 1.6
        Name => 'IlluminantData1',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xcd36 => { # DNG 1.6
        Name => 'IlluminantData2',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xcd37 => { # DNG 1.6
        Name => 'IlluminantData3',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xcd38 => { # DNG 1.6
        Name => 'MaskSubArea',
      # Writable => 'int32u',
        WriteGroup => 'SubIFD', #? (NC) Semantic Mask IFD (only for Validate)
        Count => 4,
    },
    0xcd39 => { # DNG 1.6
        Name => 'ProfileHueSatMapData3',
        %longBin,
        Writable => 'float',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xcd3a => { # DNG 1.6
        Name => 'ReductionMatrix3',
        Writable => 'rational64s',
        WriteGroup => 'IFD0',
        Count => -1,
        Protected => 1,
    },
    0xcd3b => { # DNG 1.6
        Name => 'RGBTables',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xcd40 => { # DNG 1.7
        Name => 'ProfileGainTableMap2',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Protected => 1,
        Binary => 1,
    },
    0xcd41 => {
        Name => 'JUMBF',
        # (set Deletable flag so we can delete this because
        #  Jpeg2000 directories are otherwise permanent)
        Deletable => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Jpeg2000::Main',
            ByteOrder => 'BigEndian',
        },
    },
    0xcd43 => { # DNG 1.7
        Name => 'ColumnInterleaveFactor',
        Writable => 'int32u',
        WriteGroup => 'SubIFD',
        Protected => 1,
    },
    0xcd44 => { # DNG 1.7
        Name => 'ImageSequenceInfo',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        SubDirectory => {
            TagTable => 'Image::ExifTool::DNG::ImageSeq',
            ByteOrder => 'BigEndian',
        },
    },
    0xcd46 => { # DNG 1.7
        Name => 'ImageStats',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        Binary => 1,
        Protected => 1,
    },
    0xcd47 => { # DNG 1.7
        Name => 'ProfileDynamicRange',
        Writable => 'undef',
        WriteGroup => 'IFD0',
        SubDirectory => {
            TagTable => 'Image::ExifTool::DNG::ProfileDynamicRange',
            ByteOrder => 'BigEndian', # (not indicated in spec)
        },
    },
    0xcd48 => { # DNG 1.7
        Name => 'ProfileGroupName',
        Writable => 'string',
        Format => 'string',
        WriteGroup => 'IFD0',
        Protected => 1,
    },
    0xea1c => { #13
        Name => 'Padding',
        Binary => 1,
        Protected => 1,
        Writable => 'undef',
        # must start with 0x1c 0xea by the WM Photo specification
        # (not sure what should happen if padding is only 1 byte)
        # (why does MicrosoftPhoto write "1c ea 00 00 00 08"?)
        RawConvInv => '$val=~s/^../\x1c\xea/s; $val',
    },
    0xea1d => {
        Name => 'OffsetSchema',
        Notes => "Microsoft's ill-conceived maker note offset difference",
        Protected => 1,
        Writable => 'int32s',
        # From the Microsoft documentation:
        #
        #     Any time the "Maker Note" is relocated by Windows, the Exif MakerNote
        #     tag (37500) is updated automatically to reference the new location. In
        #     addition, Windows records the offset (or difference) between the old and
        #     new locations in the Exif OffsetSchema tag (59933). If the "Maker Note"
        #     contains relative references, the developer can add the value in
        #     OffsetSchema to the original references to find the correct information.
        #
        # My recommendation is for other developers to ignore this tag because the
        # information it contains is unreliable. It will be wrong if the image has
        # been subsequently edited by another application that doesn't recognize the
        # new Microsoft tag.
        #
        # The new tag unfortunately only gives the difference between the new maker
        # note offset and the original offset. Instead, it should have been designed
        # to store the original offset. The new offset may change if the image is
        # edited, which will invalidate the tag as currently written. If instead the
        # original offset had been stored, the new difference could be easily
        # calculated because the new maker note offset is known.
        #
        # I exchanged emails with a Microsoft technical representative, pointing out
        # this problem shortly after they released the update (Feb 2007), but so far
        # they have taken no steps to address this.
    },
    # 0xefee - int16u: 0 - seen this from a WIC-scanned image

    # tags in the range 0xfde8-0xfe58 have been observed in PS7 files
    # generated from RAW images.  They are all strings with the
    # tag name at the start of the string.  To accommodate these types
    # of tags, all tags with values above 0xf000 are handled specially
    # by ProcessExif().
    0xfde8 => {
        Name => 'OwnerName',
        Condition => '$$self{TIFF_TYPE} ne "DCR"', # (used for another purpose in Kodak DCR images)
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Owner's Name: $val"},
        Notes => q{
            tags 0xfde8-0xfdea and 0xfe4c-0xfe58 are generated by Photoshop Camera RAW.
            Some names are the same as other EXIF tags, but ExifTool will avoid writing
            these unless they already exist in the file
        },
    },
    0xfde9 => {
        Name => 'SerialNumber',
        Condition => '$$self{TIFF_TYPE} ne "DCR"', # (used for another purpose in Kodak DCR SubIFD)
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Serial Number: $val"},
    },
    0xfdea => {
        Name => 'Lens',
        Condition => '$$self{TIFF_TYPE} ne "DCR"', # (used for another purpose in Kodak DCR SubIFD)
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Lens: $val"},
    },
    0xfe4c => {
        Name => 'RawFile',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Raw File: $val"},
    },
    0xfe4d => {
        Name => 'Converter',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Converter: $val"},
    },
    0xfe4e => {
        Name => 'WhiteBalance',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"White Balance: $val"},
    },
    0xfe51 => {
        Name => 'Exposure',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Exposure: $val"},
    },
    0xfe52 => {
        Name => 'Shadows',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Shadows: $val"},
    },
    0xfe53 => {
        Name => 'Brightness',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Brightness: $val"},
    },
    0xfe54 => {
        Name => 'Contrast',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Contrast: $val"},
    },
    0xfe55 => {
        Name => 'Saturation',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Saturation: $val"},
    },
    0xfe56 => {
        Name => 'Sharpness',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Sharpness: $val"},
    },
    0xfe57 => {
        Name => 'Smoothness',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Smoothness: $val"},
    },
    0xfe58 => {
        Name => 'MoireFilter',
        Avoid => 1,
        PSRaw => 1,
        Writable => 'string',
        ValueConv => '$val=~s/^.*: //;$val',
        ValueConvInv => q{"Moire Filter: $val"},
    },

    #-------------
    0xfe00 => {
        Name => 'KDC_IFD',
        Groups => { 1 => 'KDC_IFD' },
        Flags => 'SubIFD',
        Notes => 'used in some Kodak KDC images',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::KDC_IFD',
            DirName => 'KDC_IFD',
            Start => '$val',
        },
    },
);

# conversions for Composite SubSec date/time tags
my %subSecConv = (
    # @val array: 0) date/time, 1) sub-seconds, 2) time zone offset
    RawConv => q{
        my $v;
        if (defined $val[1] and $val[1]=~/^(\d+)/) {
            my $subSec = $1;
            # be careful here just in case the time already contains sub-seconds or a timezone (contrary to spec)
            undef $v unless ($v = $val[0]) =~ s/( \d{2}:\d{2}:\d{2})(?!\.\d+)/$1\.$subSec/;
        }
        if (defined $val[2] and $val[0]!~/[-+]/ and $val[2]=~/^([-+])(\d{1,2}):(\d{2})/) {
            $v = ($v || $val[0]) . sprintf('%s%.2d:%.2d', $1, $2, $3);
        }
        return $v;
    },
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val)',
);

# EXIF Composite tags (plus other more general Composite tags)
%Image::ExifTool::Exif::Composite = (
    GROUPS => { 2 => 'Image' },
    ImageSize => {
        Require => {
            0 => 'ImageWidth',
            1 => 'ImageHeight',
        },
        Desire => {
            2 => 'ExifImageWidth',
            3 => 'ExifImageHeight',
            4 => 'RawImageCroppedSize', # (FujiFilm RAF images)
        },
        # use ExifImageWidth/Height only for Canon and Phase One TIFF-base RAW images
        ValueConv => q{
            return $val[4] if $val[4];
            return "$val[2] $val[3]" if $val[2] and $val[3] and
                    $$self{TIFF_TYPE} =~ /^(CR2|Canon 1D RAW|IIQ|EIP)$/;
            return "$val[0] $val[1]" if IsFloat($val[0]) and IsFloat($val[1]);
            return undef;
        },
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    Megapixels => {
        Require => 'ImageSize',
        ValueConv => 'my @d = ($val =~ /\d+/g); $d[0] * $d[1] / 1000000',
        PrintConv => 'sprintf("%.*f", ($val >= 1 ? 1 : ($val >= 0.001 ? 3 : 6)), $val)',
    },
    # pick the best shutter speed value
    ShutterSpeed => {
        Desire => {
            0 => 'ExposureTime',
            1 => 'ShutterSpeedValue',
            2 => 'BulbDuration',
        },
        ValueConv => '($val[2] and $val[2]>0) ? $val[2] : (defined($val[0]) ? $val[0] : $val[1])',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    Aperture => {
        Desire => {
            0 => 'FNumber',
            1 => 'ApertureValue',
        },
        RawConv => '($val[0] || $val[1]) ? $val : undef',
        ValueConv => '$val[0] || $val[1]',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    LightValue => {
        Notes => q{
            calculated LV = 2 * log2(Aperture) - log2(ShutterSpeed) - log2(ISO/100);
            similar to exposure value but normalized to ISO 100
        },
        Require => {
            0 => 'Aperture',
            1 => 'ShutterSpeed',
            2 => 'ISO',
        },
        ValueConv => 'Image::ExifTool::Exif::CalculateLV($val[0],$val[1],$prt[2])',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    FocalLength35efl => { #26/PH
        Description => 'Focal Length',
        Notes => 'this value may be incorrect if the image has been resized',
        Groups => { 2 => 'Camera' },
        Require => {
            0 => 'FocalLength',
        },
        Desire => {
            1 => 'ScaleFactor35efl',
        },
        ValueConv => 'ToFloat(@val); ($val[0] || 0) * ($val[1] || 1)',
        PrintConv => '$val[1] ? sprintf("%.1f mm (35 mm equivalent: %.1f mm)", $val[0], $val) : sprintf("%.1f mm", $val)',
    },
    ScaleFactor35efl => { #26/PH
        Description => 'Scale Factor To 35 mm Equivalent',
        Notes => q{
            this value and any derived values may be incorrect if the image has been
            resized
        },
        Groups => { 2 => 'Camera' },
        Desire => {
            0 => 'FocalLength',
            1 => 'FocalLengthIn35mmFormat',
            2 => 'Composite:DigitalZoom',
            3 => 'FocalPlaneDiagonal',
            4 => 'SensorSize',
            5 => 'FocalPlaneXSize',
            6 => 'FocalPlaneYSize',
            7 => 'FocalPlaneResolutionUnit',
            8 => 'FocalPlaneXResolution',
            9 => 'FocalPlaneYResolution',
           10 => 'ExifImageWidth',
           11 => 'ExifImageHeight',
           12 => 'CanonImageWidth',
           13 => 'CanonImageHeight',
           14 => 'ImageWidth',
           15 => 'ImageHeight',
        },
        ValueConv => 'Image::ExifTool::Exif::CalcScaleFactor35efl($self, @val)',
        PrintConv => 'sprintf("%.1f", $val)',
    },
    CircleOfConfusion => {
        Notes => q{
            calculated as D/1440, where D is the focal plane diagonal in mm.  This value
            may be incorrect if the image has been resized
        },
        Groups => { 2 => 'Camera' },
        Require => 'ScaleFactor35efl',
        ValueConv => 'sqrt(24*24+36*36) / ($val * 1440)',
        PrintConv => 'sprintf("%.3f mm",$val)',
    },
    HyperfocalDistance => {
        Notes => 'this value may be incorrect if the image has been resized',
        Groups => { 2 => 'Camera' },
        Require => {
            0 => 'FocalLength',
            1 => 'Aperture',
            2 => 'CircleOfConfusion',
        },
        ValueConv => q{
            ToFloat(@val);
            return 'inf' unless $val[1] and $val[2];
            return $val[0] * $val[0] / ($val[1] * $val[2] * 1000);
        },
        PrintConv => 'sprintf("%.2f m", $val)',
    },
    DOF => {
        Description => 'Depth Of Field',
        Notes => 'this value may be incorrect if the image has been resized',
        Require => {
            0 => 'FocalLength',
            1 => 'Aperture',
            2 => 'CircleOfConfusion',
        },
        Desire => {
            3 => 'FocusDistance',   # focus distance in metres (0 is infinity)
            4 => 'SubjectDistance',
            5 => 'ObjectDistance',
            6 => 'ApproximateFocusDistance',
            7 => 'FocusDistanceLower',
            8 => 'FocusDistanceUpper',
        },
        ValueConv => q{
            ToFloat(@val);
            my ($d, $f) = ($val[3], $val[0]);
            if (defined $d) {
                $d or $d = 1e10;    # (use large number for infinity)
            } else {
                $d = $val[4] || $val[5] || $val[6];
                unless (defined $d) {
                    return undef unless defined $val[7] and defined $val[8];
                    $d = ($val[7] + $val[8]) / 2;
                }
            }
            return 0 unless $f and $val[2];
            my $t = $val[1] * $val[2] * ($d * 1000 - $f) / ($f * $f);
            my @v = ($d / (1 + $t), $d / (1 - $t));
            $v[1] < 0 and $v[1] = 0; # 0 means 'inf'
            return join(' ',@v);
        },
        PrintConv => q{
            $val =~ tr/,/./;    # in case locale is whacky
            my @v = split ' ', $val;
            $v[1] or return sprintf("inf (%.2f m - inf)", $v[0]);
            my $dof = $v[1] - $v[0];
            my $fmt = ($dof>0 and $dof<0.02) ? "%.3f" : "%.2f";
            return sprintf("$fmt m ($fmt - $fmt m)",$dof,$v[0],$v[1]);
        },
    },
    FOV => {
        Description => 'Field Of View',
        Notes => q{
            calculated for the long image dimension.  This value may be incorrect for
            fisheye lenses, or if the image has been resized
        },
        Require => {
            0 => 'FocalLength',
            1 => 'ScaleFactor35efl',
        },
        Desire => {
            2 => 'FocusDistance', # (multiply by 1000 to convert to mm)
        },
        # ref http://www.bobatkins.com/photography/technical/field_of_view.html
        # (calculations below apply to rectilinear lenses only, not fisheye)
        ValueConv => q{
            ToFloat(@val);
            return undef unless $val[0] and $val[1];
            my $corr = 1;
            if ($val[2]) {
                my $d = 1000 * $val[2] - $val[0];
                $corr += $val[0]/$d if $d > 0;
            }
            my $fd2 = atan2(36, 2*$val[0]*$val[1]*$corr);
            my @fov = ( $fd2 * 360 / 3.14159 );
            if ($val[2] and $val[2] > 0 and $val[2] < 10000) {
                push @fov, 2 * $val[2] * sin($fd2) / cos($fd2);
            }
            return join(' ', @fov);
        },
        PrintConv => q{
            my @v = split(' ',$val);
            my $str = sprintf("%.1f deg", $v[0]);
            $str .= sprintf(" (%.2f m)", $v[1]) if $v[1];
            return $str;
        },
    },
    # generate DateTimeOriginal from Date and Time Created if not extracted already
    DateTimeOriginal => {
        Condition => 'not defined $$self{VALUE}{DateTimeOriginal}',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Desire => {
            0 => 'DateTimeCreated',
            1 => 'DateCreated',
            2 => 'TimeCreated',
        },
        RawConv => '($val[1] and $val[2]) ? $val : undef',
        ValueConv => q{
            return $val[0] if $val[0] and $val[0]=~/ /;
            return "$val[1] $val[2]";
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ThumbnailImage => {
        Groups => { 0 => 'EXIF', 1 => 'IFD1', 2 => 'Preview' },
        Writable => 1,
        WriteGroup => 'All',
        WriteCheck => '$self->CheckImage(\$val)',
        WriteAlso => {
            # (the 0xfeedfeed values are translated in the Exif write routine)
            ThumbnailOffset => 'defined $val ? 0xfeedfeed : undef',
            ThumbnailLength => 'defined $val ? 0xfeedfeed : undef',
        },
        Require => {
            0 => 'ThumbnailOffset',
            1 => 'ThumbnailLength',
        },
        Notes => q{
            this tag is writable, and may be used to update existing thumbnails, but may
            only create a thumbnail in IFD1 of certain types of files.  Note that for
            this and other Composite embedded-image tags the family 0 and 1 groups match
            those of the originating tags
        },
        # retrieve the thumbnail from our EXIF data
        RawConv => q{
            @grps = $self->GetGroup($$val{0});  # set groups from ThumbnailOffsets
            Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"ThumbnailImage");
        },
    },
    ThumbnailTIFF => {
        Groups => { 2 => 'Preview' },
        Require => {
            0 => 'SubfileType',
            1 => 'Compression',
            2 => 'ImageWidth',
            3 => 'ImageHeight',
            4 => 'BitsPerSample',
            5 => 'PhotometricInterpretation',
            6 => 'StripOffsets',
            7 => 'SamplesPerPixel',
            8 => 'RowsPerStrip',
            9 => 'StripByteCounts',
        },
        Desire => {
            10 => 'PlanarConfiguration',
            11 => 'Orientation',
        },
        # rebuild the TIFF thumbnail from our EXIF data
        RawConv => q{
            my $tiff;
            ($tiff, @grps) = Image::ExifTool::Exif::RebuildTIFF($self, @val);
            return $tiff;
        },
    },
    PreviewImage => {
        Groups => { 0 => 'EXIF', 1 => 'SubIFD', 2 => 'Preview' },
        Writable => 1,
        WriteGroup => 'All',
        WriteCheck => '$self->CheckImage(\$val)',
        DelCheck => '$val = ""; return undef', # can't delete, so set to empty string
        WriteAlso => {
            PreviewImageStart  => 'defined $val ? 0xfeedfeed : undef',
            PreviewImageLength => 'defined $val ? 0xfeedfeed : undef',
            PreviewImageValid  => 'defined $val and length $val ? 1 : 0', # (for Olympus)
        },
        Require => {
            0 => 'PreviewImageStart',
            1 => 'PreviewImageLength',
        },
        Desire => {
            2 => 'PreviewImageValid',
            # (DNG and A100 ARW may be have 2 preview images)
            3 => 'PreviewImageStart (1)',
            4 => 'PreviewImageLength (1)',
        },
        Notes => q{
            this tag is writable, and may be used to update existing embedded images,
            but not create or delete them
        },
        # note: extract 2nd preview, but ignore double-referenced preview
        # (in A100 ARW images, the 2nd PreviewImageLength from IFD0 may be wrong anyway)
        RawConv => q{
            if ($val[3] and $val[4] and $val[0] ne $val[3]) {
                my %val = (
                    0 => 'PreviewImageStart (1)',
                    1 => 'PreviewImageLength (1)',
                    2 => 'PreviewImageValid',
                );
                $self->FoundTag($tagInfo, \%val);
            }
            return undef if defined $val[2] and not $val[2];
            @grps = $self->GetGroup($$val{0});
            return Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],'PreviewImage');
        },
    },
    JpgFromRaw => {
        Groups => { 0 => 'EXIF', 1 => 'SubIFD', 2 => 'Preview' },
        Writable => 1,
        WriteGroup => 'All',
        WriteCheck => '$self->CheckImage(\$val)',
        # Note: ExifTool 10.38 had disabled the ability to delete this -- why?
        # --> added the DelCheck in 10.61 to re-enable this
        DelCheck => '$val = ""; return undef', # can't delete, so set to empty string
        WriteAlso => {
            JpgFromRawStart  => 'defined $val ? 0xfeedfeed : undef',
            JpgFromRawLength => 'defined $val ? 0xfeedfeed : undef',
        },
        Require => {
            0 => 'JpgFromRawStart',
            1 => 'JpgFromRawLength',
        },
        Notes => q{
            this tag is writable, and may be used to update existing embedded images,
            but not create or delete them
        },
        RawConv => q{
            @grps = $self->GetGroup($$val{0});
            return Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"JpgFromRaw");
        },
    },
    OtherImage => {
        Groups => { 0 => 'EXIF', 1 => 'SubIFD', 2 => 'Preview' },
        Writable => 1,
        WriteGroup => 'All',
        WriteCheck => '$self->CheckImage(\$val)',
        DelCheck => '$val = ""; return undef', # can't delete, so set to empty string
        WriteAlso => {
            OtherImageStart  => 'defined $val ? 0xfeedfeed : undef',
            OtherImageLength => 'defined $val ? 0xfeedfeed : undef',
        },
        Require => {
            0 => 'OtherImageStart',
            1 => 'OtherImageLength',
        },
        Desire => {
            2 => 'OtherImageStart (1)',
            3 => 'OtherImageLength (1)',
        },
        Notes => q{
            this tag is writable, and may be used to update existing embedded images,
            but not create or delete them
        },
        # retrieve all other images
        RawConv => q{
            if ($val[2] and $val[3]) {
                my $i = 1;
                for (;;) {
                    my %val = ( 0 => $$val{2}, 1 => $$val{3} );
                    $self->FoundTag($tagInfo, \%val);
                    ++$i;
                    $$val{2} = "$$val{0} ($i)";
                    last unless defined $$self{VALUE}{$$val{2}};
                    $$val{3} = "$$val{1} ($i)";
                    last unless defined $$self{VALUE}{$$val{3}};
                }
            }
            @grps = $self->GetGroup($$val{0});
            Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"OtherImage");
        },
    },
    PreviewImageSize => {
        Require => {
            0 => 'PreviewImageWidth',
            1 => 'PreviewImageHeight',
        },
        ValueConv => '"$val[0]x$val[1]"',
    },
    SubSecDateTimeOriginal => {
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Writable => 1,
        Shift => 0, # don't shift this tag
        Require => {
            0 => 'EXIF:DateTimeOriginal',
        },
        Desire => {
            1 => 'SubSecTimeOriginal',
            2 => 'OffsetTimeOriginal',
        },
        WriteAlso => {
            'EXIF:DateTimeOriginal' => '($val and $val=~/^(\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2})/) ? $1 : undef',
            'EXIF:SubSecTimeOriginal' => '($val and $val=~/\.(\d+)/) ? $1 : undef',
            'EXIF:OffsetTimeOriginal' => '($val and $val=~/([-+]\d{2}:\d{2}|Z)$/) ? ($1 eq "Z" ? "+00:00" : $1) : undef',
        },
        %subSecConv,
    },
    SubSecCreateDate => {
        Description => 'Create Date',
        Groups => { 2 => 'Time' },
        Writable => 1,
        Shift => 0, # don't shift this tag
        Require => {
            0 => 'EXIF:CreateDate',
        },
        Desire => {
            1 => 'SubSecTimeDigitized',
            2 => 'OffsetTimeDigitized',
        },
        WriteAlso => {
            'EXIF:CreateDate' => '($val and $val=~/^(\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2})/) ? $1 : undef',
            'EXIF:SubSecTimeDigitized' => '($val and $val=~/\.(\d+)/) ? $1 : undef',
            'EXIF:OffsetTimeDigitized' => '($val and $val=~/([-+]\d{2}:\d{2}|Z)$/) ? ($1 eq "Z" ? "+00:00" : $1) : undef',
        },
        %subSecConv,
    },
    SubSecModifyDate => {
        Description => 'Modify Date',
        Groups => { 2 => 'Time' },
        Writable => 1,
        Shift => 0, # don't shift this tag
        Require => {
            0 => 'EXIF:ModifyDate',
        },
        Desire => {
            1 => 'SubSecTime',
            2 => 'OffsetTime',
        },
        WriteAlso => {
            'EXIF:ModifyDate' => '($val and $val=~/^(\d{4}:\d{2}:\d{2} \d{2}:\d{2}:\d{2})/) ? $1 : undef',
            'EXIF:SubSecTime' => '($val and $val=~/\.(\d+)/) ? $1 : undef',
            'EXIF:OffsetTime' => '($val and $val=~/([-+]\d{2}:\d{2}|Z)$/) ? ($1 eq "Z" ? "+00:00" : $1) : undef',
        },
        %subSecConv,
    },
    CFAPattern => {
        Require => {
            0 => 'CFARepeatPatternDim',
            1 => 'CFAPattern2',
        },
        # generate CFAPattern
        ValueConv => q{
            my @a = split / /, $val[0];
            my @b = split / /, $val[1];
            return '?' unless @a==2 and @b==$a[0]*$a[1];
            return "$a[0] $a[1] @b";
        },
        PrintConv => 'Image::ExifTool::Exif::PrintCFAPattern($val)',
    },
    RedBalance => {
        Groups => { 2 => 'Camera' },
        Desire => {
            0 => 'WB_RGGBLevels',
            1 => 'WB_RGBGLevels',
            2 => 'WB_RBGGLevels',
            3 => 'WB_GRBGLevels',
            4 => 'WB_GRGBLevels',
            5 => 'WB_GBRGLevels',
            6 => 'WB_RGBLevels',
            7 => 'WB_GRBLevels',
            8 => 'WB_RBLevels',
            9 => 'WBRedLevel', # red
           10 => 'WBGreenLevel',
        },
        ValueConv => 'Image::ExifTool::Exif::RedBlueBalance(0,@val)',
        PrintConv => 'int($val * 1e6 + 0.5) * 1e-6',
    },
    BlueBalance => {
        Groups => { 2 => 'Camera' },
        Desire => {
            0 => 'WB_RGGBLevels',
            1 => 'WB_RGBGLevels',
            2 => 'WB_RBGGLevels',
            3 => 'WB_GRBGLevels',
            4 => 'WB_GRGBLevels',
            5 => 'WB_GBRGLevels',
            6 => 'WB_RGBLevels',
            7 => 'WB_GRBLevels',
            8 => 'WB_RBLevels',
            9 => 'WBBlueLevel', # blue
           10 => 'WBGreenLevel',
        },
        ValueConv => 'Image::ExifTool::Exif::RedBlueBalance(1,@val)',
        PrintConv => 'int($val * 1e6 + 0.5) * 1e-6',
    },
    GPSPosition => {
        Groups => { 2 => 'Location' },
        Writable => 1,
        Protected => 1,
        WriteAlso => {
            GPSLatitude => '(defined $val and $val =~ /(.*) /) ? $1 : undef',
            GPSLatitudeRef => '(defined $val and $val =~ /(-?)(.*?) /) ? ($1 ? "S" : "N") : undef',
            GPSLongitude => '(defined $val and $val =~ / (.*)$/) ? $1 : undef',
            GPSLongitudeRef => '(defined $val and $val =~ / (-?)/) ? ($1 ? "W" : "E") : undef',
        },
        PrintConvInv => q{
            return undef unless $val =~ /(.*? ?[NS]?), ?(.*? ?[EW]?)$/;
            my ($lat, $lon) = ($1, $2);
            require Image::ExifTool::GPS;
            $lat = Image::ExifTool::GPS::ToDegrees($lat, 1, "lat");
            $lon = Image::ExifTool::GPS::ToDegrees($lon, 1, "lon");
            return "$lat $lon";
        },
        Require => {
            0 => 'GPSLatitude',
            1 => 'GPSLongitude',
        },
        Priority => 0,
        Notes => q{
            when written, writes GPSLatitude, GPSLatitudeRef, GPSLongitude and
            GPSLongitudeRef.  This tag may be written using the same coordinate
            format as provided by Google Maps when right-clicking on a location
        },
        ValueConv => '(length($val[0]) or length($val[1])) ? "$val[0] $val[1]" : undef',
        PrintConv => '"$prt[0], $prt[1]"',
    },
    LensID => {
        Groups => { 2 => 'Camera' },
        Require => 'LensType',
        Desire => {
            1 => 'FocalLength',
            2 => 'MaxAperture',
            3 => 'MaxApertureValue',
            4 => 'MinFocalLength',
            5 => 'MaxFocalLength',
            6 => 'LensModel',
            7 => 'LensFocalRange',
            8 => 'LensSpec',
            9 => 'LensType2',
            10 => 'LensType3',
            11 => 'LensFocalLength', # (for Pentax to check for converter)
            12 => 'RFLensType',
        },
        Notes => q{
            attempt to identify the actual lens from all lenses with a given LensType.
            Applies only to LensType values with a lookup table.  May be configured
            by adding user-defined lenses
        },
        # this LensID is only valid if the LensType has a PrintConv or is a model name
        RawConv => q{
            my $printConv = $$self{TAG_INFO}{LensType}{PrintConv};
            return $val if ref $printConv eq 'HASH' or (ref $printConv eq 'ARRAY' and
                ref $$printConv[0] eq 'HASH') or $val[0] =~ /(mm|\d\/F)/;
            return undef;
        },
        ValueConv => '$val',
        PrintConv => q{
            my $pcv;
            # use LensType2 instead of LensType if available and valid (Sony E-mount lenses)
            # (0x8000 or greater; 0 for several older/3rd-party E-mount lenses)
            if (defined $val[9] and ($val[9] & 0x8000 or $val[9] == 0)) {
                $val[0] = $val[9];
                $prt[0] = $prt[9];
                # Particularly GM lenses: often LensType2=0 but LensType3 is available and valid: use LensType3.
                if ($val[9] == 0 and $val[10] & 0x8000) {
                   $val[0] = $val[10];
                   $prt[0] = $prt[10];
                }
                $pcv = $$self{TAG_INFO}{LensType2}{PrintConv};
            }
            # use Canon RFLensType if available
            if ($val[12]) {
                $val[0] = $val[12];
                $prt[0] = $prt[12];
                $pcv = $$self{TAG_INFO}{RFLensType}{PrintConv};
            }
            my $lens = Image::ExifTool::Exif::PrintLensID($self, $prt[0], $pcv, $prt[8], @val);
            # check for use of lens converter (Pentax K-3)
            if ($val[11] and $val[1] and $lens) {
                my $conv = $val[1] / $val[11];
                $lens .= sprintf(' + %.1fx converter', $conv) if $conv > 1.1;
            }
            return $lens;
        },
    },
    'LensID-2' => {
        Name => 'LensID',
        Groups => { 2 => 'Camera' },
        Desire => {
            0 => 'LensModel',
            1 => 'Lens',
            2 => 'XMP-aux:LensID',
            3 => 'Make',
        },
        Inhibit => {
            4 => 'Composite:LensID',
        },
        RawConv => q{
            return undef if defined $val[2] and defined $val[3];
            return $val if defined $val[0] and $val[0] =~ /(mm|\d\/F)/;
            return $val if defined $val[1] and $val[1] =~ /(mm|\d\/F)/;
            return undef;
        },
        ValueConv => q{
            return $val[0] if defined $val[0] and $val[0] =~ /(mm|\d\/F)/;
            return $val[1];
        },
        PrintConv => '$_=$val; s/(\d)\/F/$1mm F/; s/mmF/mm F/; s/(\d) mm/${1}mm/; s/ - /-/; $_',
    },
);

# table for unknown IFD entries
%Image::ExifTool::Exif::Unknown = (
    GROUPS => { 0 => 'EXIF', 1 => 'UnknownIFD', 2 => 'Image'},
    WRITE_PROC => \&WriteExif,
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Exif');


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Identify RAW file type for some TIFF-based formats using Compression value
# Inputs: 0) ExifTool object reference, 1) Compression value
# - sets TIFF_TYPE and FileType if identified
sub IdentifyRawFile($$)
{
    my ($et, $comp) = @_;
    if ($$et{FILE_TYPE} eq 'TIFF' and not $$et{IdentifiedRawFile}) {
        if ($compression{$comp} and $compression{$comp} =~ /^\w+ ([A-Z]{3}) Compressed$/) {
            $et->OverrideFileType($$et{TIFF_TYPE} = $1);
            $$et{IdentifiedRawFile} = 1;
        }
    }
}

#------------------------------------------------------------------------------
# Calculate LV (Light Value)
# Inputs: 0) Aperture, 1) ShutterSpeed, 2) ISO
# Returns: LV value (and converts input values to floating point if necessary)
sub CalculateLV($$$)
{
    local $_;
    # do validity checks on arguments
    return undef unless @_ >= 3;
    foreach (@_) {
        return undef unless $_ and /([+-]?(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?)/ and $1 > 0;
        $_ = $1;    # extract float from any other garbage
    }
    # (A light value of 0 is defined as f/1.0 at 1 second with ISO 100)
    return log($_[0] * $_[0] * 100 / ($_[1] * $_[2])) / log(2);
}

#------------------------------------------------------------------------------
# Calculate scale factor for 35mm effective focal length (ref 26/PH)
# Inputs: 0) ExifTool object ref
#         1) Focal length
#         2) Focal length in 35mm format
#         3) Canon digital zoom factor
#         4) Focal plane diagonal size (in mm)
#         5) Sensor size (X and Y in mm)
#         6/7) Focal plane X/Y size (in mm)
#         8) focal plane resolution units (1=None,2=inches,3=cm,4=mm,5=um)
#         9/10) Focal plane X/Y resolution
#         11/12,13/14...) Image width/height in order of precedence (first valid pair is used)
# Returns: 35mm conversion factor (or undefined if it can't be calculated)
sub CalcScaleFactor35efl
{
    my $et = shift;
    my $res = $_[7];    # save resolution units (in case they have been converted to string)
    my $sensXY = $_[4];
    Image::ExifTool::ToFloat(@_);
    my $focal = shift;
    my $foc35 = shift;

    return $foc35 / $focal if $focal and $foc35;

    my $digz = shift || 1;
    my $diag = shift;
    my $sens = shift;
    # calculate Canon sensor size using a dedicated algorithm
    if ($$et{Make} eq 'Canon') {
        require Image::ExifTool::Canon;
        my $canonDiag = Image::ExifTool::Canon::CalcSensorDiag(
            $$et{RATIONAL}{FocalPlaneXResolution},
            $$et{RATIONAL}{FocalPlaneYResolution},
        );
        $diag = $canonDiag if $canonDiag;
    }
    unless ($diag and Image::ExifTool::IsFloat($diag)) {
        if ($sens and $sensXY =~ / (\d+(\.?\d*)?)$/) {
            $diag = sqrt($sens * $sens + $1 * $1);
        } else {
            undef $diag;
            my $xsize = shift;
            my $ysize = shift;
            if ($xsize and $ysize) {
                # validate by checking aspect ratio because FocalPlaneX/YSize is not reliable
                my $a = $xsize / $ysize;
                if (abs($a-1.3333) < .1 or abs($a-1.5) < .1) {
                    $diag = sqrt($xsize * $xsize + $ysize * $ysize);
                }
            }
        }
        unless ($diag) {
            # get number of mm in units (assume inches unless otherwise specified)
            my %lkup = ( 3=>10, 4=>1, 5=>0.001 , cm=>10, mm=>1, um=>0.001 );
            my $units = $lkup{ shift() || $res || '' } || 25.4;
            my $x_res = shift || return undef;
            my $y_res = shift || $x_res;
            Image::ExifTool::IsFloat($x_res) and $x_res != 0 or return undef;
            Image::ExifTool::IsFloat($y_res) and $y_res != 0 or return undef;
            my ($w, $h);
            for (;;) {
                @_ < 2 and return undef;
                $w = shift;
                $h = shift;
                next unless $w and $h;
                my $a = $w / $h;
                last if $a > 0.5 and $a < 2; # stop if we get a reasonable value
            }
            # calculate focal plane size in mm
            $w *= $units / $x_res;
            $h *= $units / $y_res;
            $diag = sqrt($w*$w+$h*$h);
            # make sure size is reasonable
            return undef unless $diag > 1 and $diag < 100;
        }
    }
    return sqrt(36*36+24*24) * $digz / $diag;
}

#------------------------------------------------------------------------------
# Print exposure compensation fraction
sub PrintFraction($)
{
    my $val = shift;
    my $str;
    if (defined $val) {
        $val *= 1.00001;    # avoid round-off errors
        if (not $val) {
            $str = '0';
        } elsif (int($val)/$val > 0.999) {
            $str = sprintf("%+d", int($val));
        } elsif ((int($val*2))/($val*2) > 0.999) {
            $str = sprintf("%+d/2", int($val * 2));
        } elsif ((int($val*3))/($val*3) > 0.999) {
            $str = sprintf("%+d/3", int($val * 3));
        } else {
            $str = sprintf("%+.3g", $val);
        }
    }
    return $str;
}

#------------------------------------------------------------------------------
# Convert fraction or number to floating point value (or 'undef' or 'inf')
sub ConvertFraction($)
{
    my $val = shift;
    if ($val =~ m{([-+]?\d+)/(\d+)}) {
        $val = $2 ? $1 / $2 : ($1 ? 'inf' : 'undef');
    }
    return $val;
}

#------------------------------------------------------------------------------
# Convert EXIF text to something readable
# Inputs: 0) ExifTool object reference, 1) EXIF text,
#         2) [optional] 1 to apply CharsetEXIF to ASCII text,
#         3) tag name for warning message (may be argument 2)
# Returns: text encoded according to Charset option (with trailing spaces removed)
sub ConvertExifText($$;$$)
{
    my ($et, $val, $asciiFlex, $tag) = @_;
    return $val if length($val) < 8;
    my $id = substr($val, 0, 8);
    my $str = substr($val, 8);
    my $type;

    delete $$et{WrongByteOrder};
    if ($$et{OPTIONS}{Validate} and $id =~ /^(ASCII|UNICODE|JIS)?\0* \0*$/) {
        $et->Warn(($1 || 'Undefined') . ' text header' . ($tag ? " for $tag" : '') . ' has spaces instead of nulls');
    }
    # Note: allow spaces instead of nulls in the ID codes because
    # it is fairly common for camera manufacturers to get this wrong
    # (also handle Canon ZoomBrowser EX 4.5 null followed by 7 bytes of garbage)
    if ($id =~ /^(ASCII)?(\0|[\0 ]+$)/) {
        # truncate at null terminator (shouldn't have a null based on the
        # EXIF spec, but it seems that few people actually read the spec)
        $str =~ s/\0.*//s;
        # allow ASCII text to contain any other specified encoding
        if ($asciiFlex and $asciiFlex eq '1') {
            my $enc = $et->Options('CharsetEXIF');
            $str = $et->Decode($str, $enc) if $enc;
        }
    # by the EXIF spec, the following string should be "UNICODE\0", but
    # apparently Kodak sometimes uses "Unicode\0" in the APP3 "Meta" information.
    # However, unfortunately Ricoh uses "Unicode\0" in the RR30 EXIF UserComment
    # when the text is actually ASCII, so only recognize uppercase "UNICODE\0".
    } elsif ($id =~ /^(UNICODE)[\0 ]$/) {
        $type = $1;
        # MicrosoftPhoto writes as little-endian even in big-endian EXIF,
        # so we must guess at the true byte ordering
        $str = $et->Decode($str, 'UTF16', 'Unknown');
    } elsif ($id =~ /^(JIS)[\0 ]{5}$/) {
        $type = $1;
        $str = $et->Decode($str, 'JIS', 'Unknown');
    } else {
        $tag = $asciiFlex if $asciiFlex and $asciiFlex ne '1';
        $et->Warn('Invalid EXIF text encoding' . ($tag ? " for $tag" : ''));
        $str = $id . $str;
    }
    if ($$et{WrongByteOrder} and $$et{OPTIONS}{Validate}) {
        $et->Warn('Wrong byte order for EXIF' . ($tag ? " $tag" : '') .
                  ($type ? " $type" : '') . ' text');
    }
    $str =~ s/ +$//;    # trim trailing blanks
    return $str;
}

#------------------------------------------------------------------------------
# Print conversion for SpatialFrequencyResponse
sub PrintSFR($)
{
    my $val = shift;
    return $val unless length $val > 4;
    my ($n, $m) = (Get16u(\$val, 0), Get16u(\$val, 2));
    my @cols = split /\0/, substr($val, 4), $n+1;
    my $pos = length($val) - 8 * $n * $m;
    return $val unless @cols == $n+1 and $pos >= 4;
    pop @cols;
    my ($i, $j);
    for ($i=0; $i<$n; ++$i) {
        my @rows;
        for ($j=0; $j<$m; ++$j) {
            push @rows, Image::ExifTool::GetRational64u(\$val, $pos + 8*($i+$j*$n));
        }
        $cols[$i] .= '=' . join(',',@rows) . '';
    }
    return join '; ', @cols;
}

#------------------------------------------------------------------------------
# Print numerical parameter value (with sign, or 'Normal' for zero)
# Inputs: 0) value, 1) flag for inverse conversion, 2) conversion hash reference
sub PrintParameter($$$)
{
    my ($val, $inv, $conv) = @_;
    return $val if $inv;
    if ($val > 0) {
        if ($val > 0xfff0) {    # a negative value in disguise?
            $val = $val - 0x10000;
        } else {
            $val = "+$val";
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Convert parameter back to standard EXIF value
#   0,0.00,etc or "Normal" => 0
#   -1,-2,etc or "Soft" or "Low" => 1
#   +1,+2,1,2,etc or "Hard" or "High" => 2
sub ConvertParameter($)
{
    my $val = shift;
    my $isFloat = Image::ExifTool::IsFloat($val);
    # normal is a value of zero
    return 0 if $val =~ /\bn/i or ($isFloat and $val == 0);
    # "soft", "low" or any negative number is a value of 1
    return 1 if $val =~ /\b(s|l)/i or ($isFloat and $val < 0);
    # "hard", "high" or any positive number is a value of 2
    return 2 if $val =~ /\bh/i or $isFloat;
    return undef;
}

#------------------------------------------------------------------------------
# Calculate Red/BlueBalance
# Inputs: 0) 0=red, 1=blue, 1-8) WB_RGGB/RGBG/RBGG/GRBG/GRGB/RGB/GRB/RBLevels,
#         8) red or blue level, 9) green level
my @rggbLookup = (
    # indices for R, G, G and B components in input value
    [ 0, 1, 2, 3 ], # 0 RGGB
    [ 0, 1, 3, 2 ], # 1 RGBG
    [ 0, 2, 3, 1 ], # 2 RBGG
    [ 1, 0, 3, 2 ], # 3 GRBG
    [ 1, 0, 2, 3 ], # 4 GRGB
    [ 2, 3, 0, 1 ], # 5 GBRG
    [ 0, 1, 1, 2 ], # 6 RGB
    [ 1, 0, 0, 2 ], # 7 GRB
    [ 0, 256, 256, 1 ], # 8 RB (green level is 256)
);
sub RedBlueBalance($@)
{
    my $blue = shift;
    my ($i, $val, $levels);
    for ($i=0; $i<@rggbLookup; ++$i) {
        $levels = shift or next;
        my @levels = split ' ', $levels;
        next if @levels < 2;
        my $lookup = $rggbLookup[$i];
        my $g = $$lookup[1];    # get green level or index
        if ($g < 4) {
            next if @levels < 3;
            $g = ($levels[$g] + $levels[$$lookup[2]]) / 2 or next;
        } elsif ($levels[$$lookup[$blue * 3]] < 4) {
            $g = 1; # Some Nikon cameras use a scaling factor of 1 (E5700)
        }
        $val = $levels[$$lookup[$blue * 3]] / $g;
        last;
    }
    $val = $_[0] / $_[1] if not defined $val and ($_[0] and $_[1]);
    return $val;
}

#------------------------------------------------------------------------------
# Print exposure time as a fraction
sub PrintExposureTime($)
{
    my $secs = shift;
    return $secs unless Image::ExifTool::IsFloat($secs);
    if ($secs < 0.25001 and $secs > 0) {
        return sprintf("1/%d",int(0.5 + 1/$secs));
    }
    $_ = sprintf("%.1f",$secs);
    s/\.0$//;
    return $_;
}

#------------------------------------------------------------------------------
# Print FNumber
sub PrintFNumber($)
{
    my $val = shift;
    if (Image::ExifTool::IsFloat($val) and $val > 0) {
        # round to 1 decimal place, or 2 for values < 1.0
        $val = sprintf(($val<1 ? "%.2f" : "%.1f"), $val);
    }
    return $val;
}

#------------------------------------------------------------------------------
# Decode raw CFAPattern value
# Inputs: 0) ExifTool ref, 1) binary value
# Returns: string of numbers
sub DecodeCFAPattern($$)
{
    my ($self, $val) = @_;
    # some panasonic cameras (SV-AS3, SV-AS30) write this in ascii (very odd)
    if ($val =~ /^[0-6]+$/) {
        $self->Warn('Incorrectly formatted CFAPattern', 1);
        $val =~ tr/0-6/\x00-\x06/;
    }
    return $val unless length($val) >= 4;
    my @a = unpack(GetByteOrder() eq 'II' ? 'v2C*' : 'n2C*', $val);
    my $end = 2 + $a[0] * $a[1];
    if ($end > @a) {
        # try swapping byte order (I have seen this order different than in EXIF)
        my ($x, $y) = unpack('n2',pack('v2',$a[0],$a[1]));
        if (@a < 2 + $x * $y) {
            $self->Warn('Invalid CFAPattern', 1);
        } else {
            ($a[0], $a[1]) = ($x, $y);
            # (can't technically be wrong because the order isn't well defined by the EXIF spec)
            # $self->Warn('Wrong byte order for CFAPattern');
        }
    }
    return "@a";
}

#------------------------------------------------------------------------------
# Print CFA Pattern
sub PrintCFAPattern($)
{
    my $val = shift;
    my @a = split ' ', $val;
    return '<truncated data>' unless @a >= 2;
    return '<zero pattern size>' unless $a[0] and $a[1];
    my $end = 2 + $a[0] * $a[1];
    return '<invalid pattern size>' if $end > @a;
    my @cfaColor = qw(Red Green Blue Cyan Magenta Yellow White);
    my ($pos, $rtnVal) = (2, '[');
    for (;;) {
        $rtnVal .= $cfaColor[$a[$pos]] || 'Unknown';
        last if ++$pos >= $end;
        ($pos - 2) % $a[1] and $rtnVal .= ',', next;
        $rtnVal .= '][';
    }
    return $rtnVal . ']';
}

#------------------------------------------------------------------------------
# Print Opcode List
# Inputs: 0) value, 1) flag for inverse conversion, 2) conversion hash reference
# Returns: converted value
sub PrintOpcode($$$)
{
    my ($val, $inv, $conv) = @_;
    return undef if $inv;   # (can't do inverse conversion)
    return '' unless length $$val > 4;
    my $num = unpack('N', $$val);
    my $pos = 4;
    my ($i, @ops);
    for ($i=0; $i<$num; ++$i) {
        $pos + 16 <= length $$val or push(@ops, '<err>'), last;
        my ($op, $ver, $flags, $len) = unpack("x${pos}N4", $$val);
        push @ops, $$conv{$op} || "[opcode $op]";
        $pos += 16 + $len;
    }
    return join ', ', @ops;
}

#------------------------------------------------------------------------------
# Print conversion for lens info
# Inputs: 0) string of values (min focal, max focal, min F, max F)
# Returns: string in the form "12-20mm f/3.8-4.5" or "50mm f/1.4"
sub PrintLensInfo($)
{
    my $val = shift;
    my @vals = split ' ', $val;
    return $val unless @vals == 4;
    my $c = 0;
    foreach (@vals) {
        Image::ExifTool::IsFloat($_) and ++$c, next;
        $_ eq 'inf' and $_ = '?', ++$c, next;
        $_ eq 'undef' and $_ = '?', ++$c, next;
    }
    return $val unless $c == 4;
    $val = $vals[0];
    # (the Pentax Q writes zero for upper value of fixed-focal-length lenses)
    $val .= "-$vals[1]" if $vals[1] and $vals[1] ne $vals[0];
    $val .= "mm f/$vals[2]";
    $val .= "-$vals[3]" if $vals[3] and $vals[3] ne $vals[2];
    return $val;
}

#------------------------------------------------------------------------------
# Get lens info from lens model string
# Inputs: 0) lens string, 1) flag to allow unknown "?" values
# Returns: 0) min focal, 1) max focal, 2) min aperture, 3) max aperture
# Notes: returns empty list if lens string could not be parsed
sub GetLensInfo($;$)
{
    my ($lens, $unk) = @_;
    # extract focal length and aperture ranges for this lens
    my $pat = '\\d+(?:\\.\\d+)?';
    $pat .= '|\\?' if $unk;
    return () unless $lens =~ /($pat)(?:-($pat))?\s*mm.*?(?:[fF]\/?\s*)($pat)(?:-($pat))?/;
    # ($1=short focal, $2=long focal, $3=max aperture wide, $4=max aperture tele)
    my @a = ($1, $2, $3, $4);
    $a[1] or $a[1] = $a[0];
    $a[3] or $a[3] = $a[2];
    if ($unk) {
        local $_;
        $_ eq '?' and $_ = 'undef' foreach @a;
    }
    return @a;
}

#------------------------------------------------------------------------------
# Match lens in list of possbilities based on value of LensModel
# Inputs: 0) reference to list of possible models, 1) LensModel string
# - updates list on return; guaranteed not to remove all list entries
sub MatchLensModel($$)
{
    my ($try, $lensModel) = @_;
    if (@$try > 1 and $lensModel) {
        my (@filt, $pat);
        # filter by focal length
        if ($lensModel =~ /((\d+-)?\d+mm)/) {
            my $focal = $1;
            @filt = grep /$focal/, @$try;
            @$try = @filt if @filt and @filt < @$try;
        }
        # filter by aperture
        if (@$try > 1 and $lensModel =~ m{(?:F/?|1:)(\d+(\.\d+)?)}i) {
            my $fnum = $1;
            @filt = grep m{(F/?|1:)$fnum(\b|[A-Z])}i, @$try;
            @$try = @filt if @filt and @filt < @$try;
        }
        # filter by model version, and other lens parameters
        foreach $pat ('I+', 'USM') {
            next unless @$try > 1 and $lensModel =~ /\b($pat)\b/;
            my $val = $1;
            @filt = grep /\b$val\b/, @$try;
            @$try = @filt if @filt and @filt < @$try;
        }
    }
}

#------------------------------------------------------------------------------
# Attempt to identify the specific lens if multiple lenses have the same LensType
# Inputs: 0) ExifTool object ref, 1) LensType print value, 2) PrintConv hash ref,
#         3) LensSpec print value, 4) LensType numerical value, 5) FocalLength,
#         6) MaxAperture, 7) MaxApertureValue, 8) MinFocalLength, 9) MaxFocalLength,
#         10) LensModel, 11) LensFocalRange, 12) LensSpec
my %sonyEtype;
sub PrintLensID($$@)
{
    my ($et, $lensTypePrt, $printConv, $lensSpecPrt, $lensType, $focalLength,
        $maxAperture, $maxApertureValue, $shortFocal, $longFocal, $lensModel,
        $lensFocalRange, $lensSpec) = @_;
    # this logic relies on the LensType lookup:
    return undef unless defined $lensType;
    # get print conversion hash if necessary
    $printConv or $printConv = $$et{TAG_INFO}{LensType}{PrintConv};
    # just copy LensType PrintConv value if it was a lens name
    # (Olympus or Panasonic -- just exclude things like Nikon and Leaf LensType)
    unless (ref $printConv eq 'HASH') {
        if (ref $printConv eq 'ARRAY' and ref $$printConv[0] eq 'HASH') {
            $printConv = $$printConv[0];
            $lensTypePrt =~ s/;.*//;
            $lensType =~ s/ .*//;
        } else {
            return $lensTypePrt if $lensTypePrt =~ /mm/;
            return $lensTypePrt if $lensTypePrt =~ s/(\d)\/F/$1mm F/;
            return undef;
        }
    }
    # get LensSpec information if available (Sony)
    my ($sf0, $lf0, $sa0, $la0);
    if ($lensSpecPrt) {
        ($sf0, $lf0, $sa0, $la0) = GetLensInfo($lensSpecPrt);
        undef $sf0 unless $sa0; # (make sure aperture isn't zero)
    }
    # use MaxApertureValue if MaxAperture is not available
    $maxAperture = $maxApertureValue unless $maxAperture;
    if ($lensFocalRange and $lensFocalRange =~ /^(\d+)(?: (?:to )?(\d+))?$/) {
        ($shortFocal, $longFocal) = ($1, $2 || $1);
    }
    if ($$et{Make} eq 'SONY') {
        if ($lensType eq 65535) {
            # handle Sony E-type lenses when LensType2 isn't valid (NEX/ILCE models only)
            if ($$et{Model} =~ /NEX|ILCE/) {
                unless (%sonyEtype) {
                    my ($index, $i, %did, $lens);
                    require Image::ExifTool::Sony;
                    foreach (sort keys %Image::ExifTool::Sony::sonyLensTypes2) {
                        ($lens = $Image::ExifTool::Sony::sonyLensTypes2{$_}) =~ s/ or .*//;
                        next if $did{$lens};
                        ($i, $index) = $index ? ("65535.$index", $index + 1) : (65535, 1);
                        $did{$sonyEtype{$i} = $lens} = 1;
                    }
                }
                $printConv = \%sonyEtype;
            }
        } elsif ($lensType != 0xff00) {
            # Patch for Metabones or other adapters on Sony E-mount cameras (ref Jos Roost)
            # Metabones Canon EF to E-mount adapters add 0xef00, 0xbc00 or 0x7700 to the
            # high byte for 2-byte Canon LensType values, so we need to adjust for these.
            # Offset 0xef00 is also used by Sigma MC-11, Fotodiox and Viltrox EF-E adapters.
            # Have to exclude A-mount Sigma Filtermatic with 'odd' LensType=0xff00.
            require Image::ExifTool::Minolta;
            if ($Image::ExifTool::Minolta::metabonesID{$lensType & 0xff00}) {
                $lensType -= ($lensType >= 0xef00 ? 0xef00 : $lensType >= 0xbc00 ? 0xbc00 : 0x7700);
                require Image::ExifTool::Canon;
                $printConv = \%Image::ExifTool::Canon::canonLensTypes;
                $lensTypePrt = $$printConv{$lensType} if $$printConv{$lensType};
            # Test for Sigma MC-11 SA-E adapter with Sigma SA lens using 0x4900 offset.
            # (upper limit of test cuts off two highest Sigma lenses, but prevents
            # conflict with old Minolta 25xxx and higher ID's)
            } elsif ($lensType >= 0x4900 and $lensType <= 0x590a) {
                require Image::ExifTool::Sigma;
                $lensType -= 0x4900;
                $printConv = \%Image::ExifTool::Sigma::sigmaLensTypes;
                $lensTypePrt = $$printConv{$lensType} if $$printConv{$lensType};
            }
        }
    # (Min/MaxFocalLength may report the current focal length for Tamron zoom lenses)
    } elsif ($shortFocal and $longFocal and (not $lensModel or $lensModel !~ /^TAMRON.*-\d+mm/)) {
        # Canon (and some other makes) include makernote information
        # which allows better lens identification
        require Image::ExifTool::Canon;
        return Image::ExifTool::Canon::PrintLensID($printConv, $lensType,
                    $shortFocal, $longFocal, $maxAperture, $lensModel);
    }
    my $lens = $$printConv{$lensType};
    return ($lensModel || $lensTypePrt) unless $lens;
    return $lens unless $$printConv{"$lensType.1"};
    $lens =~ s/ or .*//s;    # remove everything after "or"
    # make list of all possible matching lenses
    my @lenses = ( $lens );
    my $i;
    for ($i=1; $$printConv{"$lensType.$i"}; ++$i) {
        push @lenses, $$printConv{"$lensType.$i"};
    }
    # attempt to determine actual lens
    my (@matches, @best, @user, $diff);
    foreach $lens (@lenses) {
        push @user, $lens if $Image::ExifTool::userLens{$lens};
        # sf = short focal
        # lf = long focal
        # sa = max aperture at short focal
        # la = max aperture at long focal
        my ($sf, $lf, $sa, $la) = GetLensInfo($lens);
        next unless $sf;
        # check against LensSpec parameters if available
        if ($sf0) {
            next if abs($sf - $sf0) > 0.5 or abs($sa - $sa0) > 0.15 or
                    abs($lf - $lf0) > 0.5 or abs($la - $la0) > 0.15;
            # the basic parameters match, but also check against additional lens features:
            # for Sony A and E lenses, the full LensSpec string should match with end of LensType,
            # excluding any part between () at the end, and preceded by a space (the space
            # ensures that e.g. Zeiss Loxia 21mm having LensSpec "E 21mm F2.8" will not be
            # identified as "Sony FE 21mm F2.8 (SEL28F20 + SEL075UWC)")
            $lensSpecPrt and $lens =~ / \Q$lensSpecPrt\E( \(| GM$|$)/ and @best = ( $lens ), last;
            # exactly-matching Sony lens should have been found above, so only add non-Sony lenses
            push @best, $lens unless $lens =~ /^Sony /;
            next;
        }
        # adjust focal length and aperture if teleconverter is attached (Minolta)
        if ($lens =~ / \+ .*? (\d+(\.\d+)?)x( |$)/) {
            $sf *= $1;  $lf *= $1;
            $sa *= $1;  $la *= $1;
        }
        # see if we can rule out this lens using FocalLength and MaxAperture
        if ($focalLength) {
            next if $focalLength < $sf - 0.5;
            next if $focalLength > $lf + 0.5;
        }
        if ($maxAperture) {
            # it seems that most manufacturers set MaxAperture and MaxApertureValue
            # to the maximum aperture (smallest F number) for the current focal length
            # of the lens, so assume that MaxAperture varies with focal length and find
            # the closest match (this is somewhat contrary to the EXIF specification which
            # states "The smallest F number of the lens", without mention of focal length)
            next if $maxAperture < $sa - 0.15;  # (0.15 is arbitrary)
            next if $maxAperture > $la + 0.15;
            # now determine the best match for this aperture
            my $aa; # approximate maximum aperture at this focal length
            if ($sf == $lf or $sa == $la or $focalLength <= $sf) {
                # either 1) prime lens, 2) fixed-aperture zoom, or 3) zoom at min focal
                $aa = $sa;
            } elsif ($focalLength >= $lf) {
                $aa = $la;
            } else {
                # assume a log-log variation of max aperture with focal length
                # (see http://regex.info/blog/2006-10-05/263)
                $aa = exp(log($sa) + (log($la)-log($sa)) / (log($lf)-log($sf)) *
                                     (log($focalLength)-log($sf)));
                # a linear relationship between 1/FocalLength and 1/MaxAperture fits Sony better (ref 27)
                #$aa = 1 / (1/$sa + (1/$focalLength - 1/$sf) * (1/$la - 1/$sa) / (1/$lf - 1/$sf));
            }
            my $d = abs($maxAperture - $aa);
            if (defined $diff) {
                $d > $diff + 0.15 and next;     # (0.15 is arbitrary)
                $d < $diff - 0.15 and undef @best;
            }
            $diff = $d;
            push @best, $lens;
        }
        push @matches, $lens;
    }
    # return the user-defined lens if it exists
    if (@user) {
        # choose the best match if we have more than one
        if (@user > 1) {
            my ($try, @good);
            foreach $try (\@best, \@matches) {
                $Image::ExifTool::userLens{$_} and push @good, $_ foreach @$try;
                return join(' or ', @good) if @good;
            }
        }
        return join(' or ', @user);
    }
    # return the best match(es) from the possible lenses, after checking against LensModel
    @best = @matches unless @best;
    if (@best) {
        MatchLensModel(\@best, $lensModel);
        return join(' or ', @best);
    }
    $lens = $$printConv{$lensType};
    return $lensModel if $lensModel and $lens =~ / or /; # (eg. Sony NEX-5N)
    return $lens;
}

#------------------------------------------------------------------------------
# Translate date into standard EXIF format
# Inputs: 0) date
# Returns: date in format '2003:10:22'
# - bad formats recognized: '2003-10-22','2003/10/22','2003 10 22','20031022'
# - removes null terminator if it exists
sub ExifDate($)
{
    my $date = shift;
    $date =~ s/\0$//;       # remove any null terminator
    # separate year:month:day with colons
    # (have seen many other characters, including nulls, used erroneously)
    $date =~ s/(\d{4})[^\d]*(\d{2})[^\d]*(\d{2})$/$1:$2:$3/;
    return $date;
}

#------------------------------------------------------------------------------
# Translate time into standard EXIF format
# Inputs: 0) time
# Returns: time in format '10:30:55'
# - bad formats recognized: '10 30 55', '103055', '103055+0500'
# - removes null terminator if it exists
# - leaves time zone intact if specified (eg. '10:30:55+05:00')
sub ExifTime($)
{
    my $time = shift;
    $time =~ tr/ /:/;   # use ':' (not ' ') as a separator
    $time =~ s/\0$//;   # remove any null terminator
    # add separators if they don't exist
    $time =~ s/^(\d{2})(\d{2})(\d{2})/$1:$2:$3/;
    $time =~ s/([+-]\d{2})(\d{2})\s*$/$1:$2/;   # to timezone too
    return $time;
}

#------------------------------------------------------------------------------
# Generate TIFF file from scratch (in current byte order)
# Inputs: 0) hash of IFD entries (TagID => Value; multiple values space-delimited)
#         1) raw image data reference
# Returns: TIFF image data, or undef on error
sub GenerateTIFF($$)
{
    my ($entries, $dataPt) = @_;
    my ($rtnVal, $tag, $offsetPos);

    my $num = scalar keys %$entries;
    my $ifdBuff = GetByteOrder() . Set16u(42) .  Set32u(8) .  Set16u($num);
    my $valBuff = '';
    my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
    foreach $tag (sort { $a <=> $b } keys %$entries) {
        my $tagInfo = $$tagTablePtr{$tag};
        my $fmt = ref $tagInfo eq 'HASH' ? $$tagInfo{Writable} : 'int32u';
        return undef unless defined $fmt;
        my $val = Image::ExifTool::WriteValue($$entries{$tag}, $fmt, -1);
        return undef unless defined $val;
        my $format = $formatNumber{$fmt};
        $ifdBuff .= Set16u($tag) . Set16u($format) . Set32u(length($val)/$formatSize[$format]);
        $offsetPos = length($ifdBuff) if $tag == 0x111; # (remember StripOffsets position)
        if (length $val > 4) {
            $ifdBuff .= Set32u(10 + 12 * $num + 4 + length($valBuff));
            $valBuff .= $val;
        } else {
            $val .= "\0" x (4 - length($val)) if length $val < 4;
            $ifdBuff .= $val;
        }
    }
    $ifdBuff .= "\0\0\0\0"; # (no IFD1)
    return undef unless $offsetPos;
    Set32u(length($ifdBuff) + length($valBuff), \$ifdBuff, $offsetPos);
    return $ifdBuff . $valBuff . $$dataPt;
}

#------------------------------------------------------------------------------
# Rebuild TIFF thumbnail(s)/preview(s) into stand-alone files with current byte order
# Inputs: 0) ExifTool ref, 1) SubfileType, 2) Compression, 3) ImageWidth, 4) ImageHeight,
#         5) BitsPerSample, 6) PhotometricInterpretation, 7) StripOffsets, 8) SamplesPerPixel,
#         9) RowsPerStrip, 10) StripByteCounts, 10) PlanarConfiguration, 11) Orientation
# Returns: 0) TIFF image or undef, 1/2) Family 0/1 groups for TIFF preview IFD
sub RebuildTIFF($;@)
{
    local $_;
    my $et = $_[0];
    my $value = $$et{VALUE};
    my ($i, $j, $rtn, $grp0, $grp1);
    return undef if $$et{FILE_TYPE} eq 'RWZ';
SubFile:
    for ($i=0; ; ++$i) {
        my $key = 'SubfileType' . ($i ? " ($i)" : '');
        last unless defined $$value{$key};
        next unless $$value{$key} == 1; # (reduced-resolution image)
        my $grp = $et->GetGroup($key, 1);
        my $cmp = $et->FindValue('Compression', $grp);
        next unless $cmp == 1; # (no compression)
        my %vals = (Compression=>$cmp, PlanarConfiguration=>1, Orientation=>1);
        foreach (qw(ImageWidth ImageHeight BitsPerSample PhotometricInterpretation
                    StripOffsets SamplesPerPixel RowsPerStrip StripByteCounts
                    PlanarConfiguration Orientation))
        {
            my $val = $et->FindValue($_, $grp);
            defined $val and $vals{$_} = $val, next;
            next SubFile unless defined $vals{$_};
        }
        my ($w, $h) = @vals{'ImageWidth', 'ImageHeight'};
        my @bits = split ' ', $vals{BitsPerSample};
        my $rowBytes = 0;
        $rowBytes += $w * int(($_+7)/8) foreach @bits;
        my $dat = '';
        my @off = split ' ', $vals{StripOffsets};
        my @len = split ' ', $vals{StripByteCounts};
        # read the image data
        for ($j=0; $j<@off; ++$j) {
            next SubFile unless $len[$j] == $rowBytes * $vals{RowsPerStrip};
            my $tmp = $et->ExtractBinary($off[$j], $len[$j]);
            next SubFile unless defined $tmp;
            $dat .= $tmp;
        }
        # generate the TIFF image
        my %entries = (
            0x0fe => 0,                 # SubfileType = 0
            0x100 => $w,                # ImageWidth
            0x101 => $h,                # ImageHeight
            0x102 => $vals{BitsPerSample},# BitsPerSample
            0x103 => $vals{Compression},# Compression
            0x106 => $vals{PhotometricInterpretation}, # PhotometricInterpretation
            0x111 => 0,                 # StripOffsets (will be adjusted later)
            0x112 => $vals{Orientation},# Orientation
            0x115 => $vals{SamplesPerPixel}, # SamplesPerPixel
            0x116 => $h,                # RowsPerStrip
            0x117 => $h * $rowBytes,    # StripByteCounts
            0x11a => 72,                # XResolution = 72
            0x11b => 72,                # YResolution = 72
            0x11c => $vals{PlanarConfiguration}, # PlanarConfiguration
            0x128 => 2,                 # ResolutionUnit = 2
        );
        my $img = GenerateTIFF(\%entries, \$dat);

        if (not defined $img) {
            $et->Warn('Invalid ' . ($w > 256 ? 'Preview' : 'Thumbnail') . 'TIFF data');
        } elsif ($rtn or $w > 256) { # (call it a preview if larger than 256 pixels)
            $et->FoundTag('PreviewTIFF', \$img, $et->GetGroup($key));
        } else {
            $rtn = \$img;
            ($grp0, $grp1) = $et->GetGroup($key);
        }
    }
    return $rtn unless wantarray;
    return ($rtn, $grp0, $grp1);
}

#------------------------------------------------------------------------------
# Extract image from file
# Inputs: 0) ExifTool object reference, 1) data offset (in file), 2) data length
#         3) [optional] tag name
# Returns: Reference to Image if specifically requested or "Binary data" message
#          Returns undef if there was an error loading the image
sub ExtractImage($$$$)
{
    my ($et, $offset, $len, $tag) = @_;
    my $dataPt = \$$et{EXIF_DATA};
    my $dataPos = $$et{EXIF_POS};
    my $image;

    # no image if length is zero, and don't try to extract binary from XMP file
    return undef if not $len or $$et{FILE_TYPE} eq 'XMP';

    # take data from EXIF block if possible
    if (defined $dataPos and $offset>=$dataPos and $offset+$len<=$dataPos+length($$dataPt)) {
        $image = substr($$dataPt, $offset-$dataPos, $len);
    } else {
        $image = $et->ExtractBinary($offset, $len, $tag);
        return undef unless defined $image;
        # patch for incorrect ThumbnailOffset in some Sony DSLR-A100 ARW images
        if ($tag and $tag eq 'ThumbnailImage' and $$et{TIFF_TYPE} eq 'ARW' and
            $$et{Model} eq 'DSLR-A100' and $offset < 0x10000 and
            $image !~ /^(Binary data|\xff\xd8\xff)/)
        {
            my $try = $et->ExtractBinary($offset + 0x10000, $len, $tag);
            if (defined $try and $try =~ /^\xff\xd8\xff/) {
                $image = $try;
                $$et{VALUE}{ThumbnailOffset} += 0x10000;
                $et->Warn('Adjusted incorrect A100 ThumbnailOffset', 1);
            }
        }
    }
    return $et->ValidateImage(\$image, $tag);
}

#------------------------------------------------------------------------------
# Utility routine to return tag ID string for warnings
# Inputs: 0) Tag ID, 1) [optional] TagInfo ref
# Returns: "tag 0xXXXX NAME"
sub TagName($;$)
{
    my ($tagID, $tagInfo) = @_;
    my $tagName = $tagInfo ? ' '.$$tagInfo{Name} : '';
    return sprintf('tag 0x%.4x%s', $tagID, $tagName);
}

#------------------------------------------------------------------------------
# Get class name of next IFD offset for HtmlDump output
# Inputs: 0) ExifTool ref, 1) current class ID
# Returns: 0) new IFD offset name, 1) new class ID including "Offset_" for new offset
#          2) new "Offset_" ID
sub NextOffsetName($;$)
{
    my ($et, $id) = @_;
    $$et{OffsetNum} = defined $$et{OffsetNum} ? $$et{OffsetNum} + 1 : 0;
    my $offName = 'o' . $$et{OffsetNum};
    my $sid = "Offset_$offName";
    $id = (defined $id ? "$id " : '') . $sid;
    return ($offName, $id, $sid);
}

#------------------------------------------------------------------------------
# Process EXIF directory
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessExif($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dataLen = $$dirInfo{DataLen};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $dataLen - $dirStart;
    my $dirName = $$dirInfo{DirName};
    my $base = $$dirInfo{Base} || 0;
    my $firstBase = $base;
    my $raf = $$dirInfo{RAF};
    my ($verbose,$validate,$saveFormat) = @{$$et{OPTIONS}}{qw(Verbose Validate SaveFormat)};
    my $htmlDump = $$et{HTML_DUMP};
    my $success = 1;
    my ($tagKey, $dirSize, $makerAddr, $strEnc, %offsetInfo, $offName, $nextOffName, $doHash);
    my $inMakerNotes = $$tagTablePtr{GROUPS}{0} eq 'MakerNotes';
    my $isExif = ($tagTablePtr eq \%Image::ExifTool::Exif::Main);

    # warn for incorrect maker notes in CR3 files
    if ($$dirInfo{DirName} eq 'MakerNotes' and $$et{FileType} eq 'CR3' and
        $$dirInfo{Parent} and $$dirInfo{Parent} eq 'ExifIFD')
    {
        $et->WarnOnce("MakerNotes shouldn't exist ExifIFD of CR3 image", 1);
    }
    # set flag to calculate image data hash if requested
    $doHash = 1 if $$et{ImageDataHash} and (($$et{FILE_TYPE} eq 'TIFF' and not $base and not $inMakerNotes) or
        ($$et{FILE_TYPE} eq 'RAF' and $dirName eq 'FujiIFD'));

    # set encoding to assume for strings
    $strEnc = $et->Options('CharsetEXIF') if $$tagTablePtr{GROUPS}{0} eq 'EXIF';

    # ignore non-standard EXIF while in strict MWG compatibility mode
    if (($validate or $Image::ExifTool::MWG::strict) and $dirName eq 'IFD0' and
        $isExif and $$et{FILE_TYPE} =~ /^(JPEG|TIFF|PSD)$/)
    {
        my $path = $et->MetadataPath();
        if ($path =~ /^(JPEG-APP1-IFD0|TIFF-IFD0|PSD-EXIFInfo-IFD0)$/) {
            unless ($$et{DOC_NUM}) {
                $et->Warn("Duplicate EXIF at $path") if $$et{HasExif};
                $$et{HasExif} = 1;
            }
        } else {
            if ($Image::ExifTool::MWG::strict) {
                $et->Warn("Ignored non-standard EXIF at $path");
                return 0;
            } else {
                $et->Warn("Non-standard EXIF at $path", 1);
            }
        }
    }
    # mix htmlDump and Validate into verbose so we can test for all at once
    $verbose = -1 if $htmlDump;
    $verbose = -2 if $validate and not $verbose;
    $dirName eq 'EXIF' and $dirName = $$dirInfo{DirName} = 'IFD0';
    $$dirInfo{Multi} = 1 if $dirName =~ /^(IFD0|SubIFD)$/ and not defined $$dirInfo{Multi};
    # get a more descriptive name for MakerNote sub-directories
    my $dir = $$dirInfo{Name};
    $dir = $dirName unless $dir and $inMakerNotes and $dir !~ /^MakerNote/;

    my ($numEntries, $dirEnd);
    if ($dirStart >= 0 and $dirStart <= $dataLen-2) {
        # make sure data is large enough (patches bug in Olympus subdirectory lengths)
        $numEntries = Get16u($dataPt, $dirStart);
        $dirSize = 2 + 12 * $numEntries;
        $dirEnd = $dirStart + $dirSize;
        if ($dirSize > $dirLen) {
            if (($verbose > 0 or $validate) and not $$dirInfo{SubIFD}) {
                my $short = $dirSize - $dirLen;
                $$et{INDENT} =~ s/..$//; # keep indent the same
                $et->Warn("Short directory size for $dir (missing $short bytes)");
                $$et{INDENT} .= '| ';
            }
            undef $dirSize if $dirEnd > $dataLen; # read from file if necessary
        }
    }
    # read IFD from file if necessary
    unless ($dirSize) {
        $success = 0;
        if ($raf) {
            # read the count of entries in this IFD
            my $offset = $dirStart + $dataPos;
            my ($buff, $buf2);
            if ($raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2) {
                my $len = 12 * Get16u(\$buff,0);
                # also read next IFD pointer if available
                if ($raf->Read($buf2, $len+4) >= $len) {
                    $buff .= $buf2;
                    $dataPt = $$dirInfo{DataPt} = \$buff;
                    $dataPos = $$dirInfo{DataPos} = $offset;
                    $dataLen = $$dirInfo{DataLen} = length $buff;
                    $dirStart = $$dirInfo{DirStart} = 0;
                    $dirLen = $$dirInfo{DirLen} = length $buff;
                    $success = 1;
                }
            }
        }
        if ($success) {
            $numEntries = Get16u($dataPt, $dirStart);
        } else {
            $et->Warn("Bad $dir directory", $inMakerNotes);
            return 0 unless $inMakerNotes and $dirLen >= 14 and $dirStart >= 0 and
                            $dirStart + $dirLen <= length($$dataPt);
            $dirSize = $dirLen;
            $numEntries = int(($dirSize - 2) / 12); # read what we can
            Set16u($numEntries, $dataPt, $dirStart);
        }
        $dirSize = 2 + 12 * $numEntries;
        $dirEnd = $dirStart + $dirSize;
    }
    $verbose > 0 and $et->VerboseDir($dirName, $numEntries);
    my $bytesFromEnd = $dataLen - $dirEnd;
    if ($bytesFromEnd < 4) {
        unless ($bytesFromEnd==2 or $bytesFromEnd==0) {
            $et->Warn("Illegal $dir directory size ($numEntries entries)");
            return 0;
        }
    }
    # fix base offset for maker notes if necessary
    if (defined $$dirInfo{MakerNoteAddr}) {
        $makerAddr = $$dirInfo{MakerNoteAddr};
        delete $$dirInfo{MakerNoteAddr};
        if (Image::ExifTool::MakerNotes::FixBase($et, $dirInfo)) {
            $base = $$dirInfo{Base};
            $dataPos = $$dirInfo{DataPos};
        }
    }
    if ($htmlDump) {
        $offName = $$dirInfo{OffsetName};
        my $longName = $dir eq 'MakerNotes' ? ($$dirInfo{Name} || $dir) : $dir;
        if (defined $makerAddr) {
            my $hdrLen = $dirStart + $dataPos + $base - $makerAddr;
            $et->HDump($makerAddr, $hdrLen, "MakerNotes header", $longName) if $hdrLen > 0;
        }
        unless ($$dirInfo{NoDumpEntryCount}) {
            $et->HDump($dirStart + $dataPos + $base, 2, "$longName entries",
                       "Entry count: $numEntries", undef, $offName);
        }
        my $tip;
        my $id = $offName;
        if ($bytesFromEnd >= 4) {
            my $nxt = ($dir =~ /^(.*?)(\d+)$/) ? $1 . ($2 + 1) : 'Next IFD';
            my $off = Get32u($dataPt, $dirEnd);
            $tip = sprintf("$nxt offset: 0x%.4x", $off);
            ($nextOffName, $id) = NextOffsetName($et, $offName) if $off;
        }
        $et->HDump($dirEnd + $dataPos + $base, 4, "Next IFD", $tip, 0, $id);
    }

    # patch for Canon EOS 40D firmware 1.0.4 bug (incorrect directory counts)
    # (must do this before parsing directory or CameraSettings offset will be suspicious)
    if ($inMakerNotes and $$et{Model} eq 'Canon EOS 40D' and $numEntries) {
        my $entry = $dirStart + 2 + 12 * ($numEntries - 1);
        my $fmt = Get16u($dataPt, $entry + 2);
        if ($fmt < 1 or $fmt > 13) {
            $et->HDump($entry+$dataPos+$base,12,"[invalid IFD entry]",
                       "Bad format type: $fmt", 1, $offName);
            # adjust the number of directory entries
            --$numEntries;
            $dirEnd -= 12;
        }
    }

    # make sure that Compression and SubfileType are defined for this IFD (for Condition's)
    $$et{Compression} = $$et{SubfileType} = '';

    # loop through all entries in an EXIF directory (IFD)
    my ($index, $valEnd, $offList, $offHash, $mapFmt, @valPos);
    $mapFmt = $$tagTablePtr{VARS}{MAP_FORMAT} if $$tagTablePtr{VARS};

    my ($warnCount, $lastID) = (0, -1);
    for ($index=0; $index<$numEntries; ++$index) {
        if ($warnCount > 10) {
            $et->Warn("Too many warnings -- $dir parsing aborted", 2) and return 0;
        }
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        my $format = Get16u($dataPt, $entry+2);
        my $count = Get32u($dataPt, $entry+4);
        # (Apple uses the BigTIFF format code 16 in the maker notes of their ProRaw DNG files)
        if (($format < 1 or $format > 13) and $format != 129 and not ($format == 16 and $$et{Make} eq 'Apple' and $inMakerNotes)) {
            if ($mapFmt and $$mapFmt{$format}) {
                $format = $$mapFmt{$format};
            } else {
                $et->HDump($entry+$dataPos+$base,12,"[invalid IFD entry]",
                           "Bad format type: $format", 1, $offName);
                # warn unless the IFD was just padded with zeros
                if ($format or $validate) {
                    $et->Warn("Bad format ($format) for $dir entry $index", $inMakerNotes);
                    ++$warnCount;
                }
                # assume corrupted IFD if this is our first entry (except Sony ILCE-7M2 firmware 1.21)
                return 0 unless $index or $$et{Model} eq 'ILCE-7M2';
                next;
            }
        }
        my $formatStr = $formatName[$format];   # get name of this format
        my $valueDataPt = $dataPt;
        my $valueDataPos = $dataPos;
        my $valueDataLen = $dataLen;
        my $valuePtr = $entry + 8;      # pointer to value within $$dataPt
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        my ($origFormStr, $bad, $rational, $subOffName);
        # save the EXIF format codes if requested
        $$et{SaveFormat}{$saveFormat = $formatStr} = 1 if $saveFormat;
        # hack to patch incorrect count in Kodak SubIFD3 tags
        if ($count < 2 and ref $$tagTablePtr{$tagID} eq 'HASH' and $$tagTablePtr{$tagID}{FixCount}) {
            $offList or ($offList, $offHash) = GetOffList($dataPt, $dirStart, $dataPos,
                                                          $numEntries, $tagTablePtr);
            my $i = $$offHash{Get32u($dataPt, $valuePtr)};
            if (defined $i and $i < $#$offList) {
                my $oldCount = $count;
                $count = int(($$offList[$i+1] - $$offList[$i]) / $formatSize[$format]);
                $origFormStr = $formatName[$format] . '[' . $oldCount . ']' if $oldCount != $count;
            }
        }
        $validate and not $inMakerNotes and Image::ExifTool::Validate::ValidateExif(
            $et, $tagTablePtr, $tagID, $tagInfo, $lastID, $dir, $count, $formatStr);
        my $size = $count * $formatSize[$format];
        my $readSize = $size;
        if ($size > 4) {
            if ($size > 0x7fffffff and (not $tagInfo or not $$tagInfo{ReadFromRAF})) {
                $et->Warn(sprintf("Invalid size (%u) for %s %s",$size,$dir,TagName($tagID,$tagInfo)), $inMakerNotes);
                ++$warnCount;
                next;
            }
            $valuePtr = Get32u($dataPt, $valuePtr);
            if ($validate and not $inMakerNotes) {
                my $tagName = TagName($tagID, $tagInfo);
                $et->Warn("Odd offset for $dir $tagName", 1) if $valuePtr & 0x01;
                if ($valuePtr < 8 || ($valuePtr + $size > length($$dataPt) and
                                      $valuePtr + $size > $$et{VALUE}{FileSize}))
                {
                    $et->Warn("Invalid offset for $dir $tagName");
                    ++$warnCount;
                    next;
                }
                if ($valuePtr + $size > $dirStart + $dataPos and $valuePtr < $dirEnd + $dataPos + 4) {
                    $et->Warn("Value for $dir $tagName overlaps IFD");
                }
                foreach (@valPos) {
                    next if $$_[0] >= $valuePtr + $size or $$_[0] + $$_[1] <= $valuePtr;
                    $et->Warn("Value for $dir $tagName overlaps $$_[2]");
                }
                push @valPos, [ $valuePtr, $size, $tagName ];
            }
            # fix valuePtr if necessary
            if ($$dirInfo{FixOffsets}) {
                my $wFlag;
                $valEnd or $valEnd = $dataPos + $dirEnd + 4;
                #### eval FixOffsets ($valuePtr, $valEnd, $size, $tagID, $wFlag)
                eval $$dirInfo{FixOffsets};
            }
            my $suspect;
            # offset shouldn't point into TIFF header
            $valuePtr < 8 and not $$dirInfo{ZeroOffsetOK} and $suspect = $warnCount;
            # convert offset to pointer in $$dataPt
            if ($$dirInfo{EntryBased} or (ref $$tagTablePtr{$tagID} eq 'HASH' and
                $$tagTablePtr{$tagID}{EntryBased}))
            {
                $valuePtr += $entry;
            } else {
                $valuePtr -= $dataPos;
            }
            # value shouldn't overlap our directory
            $suspect = $warnCount if $valuePtr < $dirEnd and $valuePtr+$size > $dirStart;
            # load value from file if necessary
            if ($valuePtr < 0 or $valuePtr+$size > $dataLen) {
                # get value by seeking in file if we are allowed
                my $buff;
                if ($raf) {
                    # avoid loading large binary data unless necessary
                    while ($size > BINARY_DATA_LIMIT) {
                        if ($tagInfo) {
                            # make large unknown blocks binary data
                            $$tagInfo{Binary} = 1 if $$tagInfo{Unknown};
                            last unless $$tagInfo{Binary};      # must read non-binary data
                            last if $$tagInfo{SubDirectory};
                            my $lcTag = lc($$tagInfo{Name});
                            if ($$et{OPTIONS}{Binary} and
                                not $$et{EXCL_TAG_LOOKUP}{$lcTag})
                            {
                                # read binary data if specified unless tagsFromFile won't use it
                                last unless $$et{TAGS_FROM_FILE} and $$tagInfo{Protected};
                            }
                            # must read if tag is specified by name
                            last if $$et{REQ_TAG_LOOKUP}{$lcTag};
                        } else {
                            # must read value if needed for a condition
                            last if defined $tagInfo;
                        }
                        # (note: changing the value without changing $size will cause
                        # a warning in the verbose output, but we need to maintain the
                        # proper size for the htmlDump, so we can't change this)
                        $buff = "Binary data $size bytes";
                        $readSize = length $buff;
                        last;
                    }
                    # read from file if necessary
                    unless (defined $buff) {
                        my ($wrn, $truncOK);
                        my $readFromRAF = ($tagInfo and $$tagInfo{ReadFromRAF});
                        if (not $raf->Seek($base + $valuePtr + $dataPos, 0)) {
                            $wrn = "Invalid offset for $dir entry $index";
                        } elsif ($readFromRAF and $size > BINARY_DATA_LIMIT and
                            not $$et{REQ_TAG_LOOKUP}{lc $$tagInfo{Name}})
                        {
                            $buff = "$$tagInfo{Name} data $size bytes";
                            $readSize = length $buff;
                        } elsif ($raf->Read($buff,$size) != $size) {
                            $wrn = sprintf("Error reading value for $dir entry $index, ID 0x%.4x", $tagID);
                            if ($tagInfo and not $$tagInfo{Unknown}) {
                                $wrn .= " $$tagInfo{Name}";
                                $truncOK = $$tagInfo{TruncateOK};
                            }
                        } elsif ($readFromRAF) {
                            # seek back to the start of the value
                            $raf->Seek($base + $valuePtr + $dataPos, 0);
                        }
                        if ($wrn) {
                            $et->Warn($wrn, $inMakerNotes || $truncOK);
                            return 0 unless $inMakerNotes or $htmlDump or $truncOK;
                            ++$warnCount;
                            $buff = '' unless defined $buff;
                            $readSize = length $buff;
                            $bad = 1 unless $truncOK;
                        }
                    }
                    $valueDataLen = length $buff;
                    $valueDataPt = \$buff;
                    $valueDataPos = $valuePtr + $dataPos;
                    $valuePtr = 0;
                } else {
                    my ($tagStr, $tmpInfo, $leicaTrailer);
                    if ($tagInfo) {
                        $tagStr = $$tagInfo{Name};
                        $leicaTrailer = $$tagInfo{LeicaTrailer};
                    } elsif (defined $tagInfo) {
                        $tmpInfo = $et->GetTagInfo($tagTablePtr, $tagID, \ '', $formatStr, $count);
                        if ($tmpInfo) {
                            $tagStr = $$tmpInfo{Name};
                            $leicaTrailer = $$tmpInfo{LeicaTrailer};
                        }
                    }
                    if ($tagInfo and $$tagInfo{ChangeBase}) {
                        # adjust base offset for this tag only
                        #### eval ChangeBase ($dirStart,$dataPos)
                        my $newBase = eval $$tagInfo{ChangeBase};
                        $valuePtr += $newBase;
                    }
                    $tagStr or $tagStr = sprintf("tag 0x%.4x",$tagID);
                    # allow PreviewImage to run outside EXIF data
                    if ($tagStr eq 'PreviewImage' and $$et{RAF}) {
                        my $pos = $$et{RAF}->Tell();
                        $buff = $et->ExtractBinary($base + $valuePtr + $dataPos, $size, 'PreviewImage');
                        $$et{RAF}->Seek($pos, 0);
                        $valueDataPt = \$buff;
                        $valueDataPos = $valuePtr + $dataPos;
                        $valueDataLen = $size;
                        $valuePtr = 0;
                    } elsif ($leicaTrailer and $$et{RAF}) {
                        if ($verbose > 0) {
                            $et->VPrint(0, "$$et{INDENT}$index) $tagStr --> (outside APP1 segment)\n");
                        }
                        if ($et->Options('FastScan')) {
                            $et->Warn('Ignored Leica MakerNote trailer');
                        } else {
                            require Image::ExifTool::Fixup;
                            $$et{LeicaTrailer} = {
                                TagInfo => $tagInfo || $tmpInfo,
                                Offset  => $base + $valuePtr + $dataPos,
                                Size    => $size,
                                Fixup   => new Image::ExifTool::Fixup,
                            };
                        }
                    } else {
                        $et->Warn("Bad offset for $dir $tagStr", $inMakerNotes);
                        ++$warnCount;
                    }
                    unless (defined $buff) {
                        $valueDataPt = '';
                        $valueDataPos = $valuePtr + $dataPos;
                        $valueDataLen = 0;
                        $valuePtr = 0;
                        $bad = 1;
                    }
                }
            }
            # warn about suspect offsets if they didn't already cause another warning
            if (defined $suspect and $suspect == $warnCount) {
                my $tagStr = $tagInfo ? $$tagInfo{Name} : sprintf('tag 0x%.4x', $tagID);
                if ($et->Warn("Suspicious $dir offset for $tagStr", $inMakerNotes)) {
                    ++$warnCount;
                    next unless $verbose;
                }
            }
        }
        # treat single unknown byte as int8u
        $formatStr = 'int8u' if $format == 7 and $count == 1;

        my ($val, $subdir, $wrongFormat);
        if ($tagID > 0xf000 and $isExif) {
            my $oldInfo = $$tagTablePtr{$tagID};
            if ((not $oldInfo or (ref $oldInfo eq 'HASH' and $$oldInfo{Condition} and
                not $$oldInfo{PSRaw})) and not $bad)
            {
                # handle special case of Photoshop RAW tags (0xfde8-0xfe58)
                # --> generate tags from the value if possible
                $val = ReadValue($valueDataPt,$valuePtr,$formatStr,$count,$readSize);
                if (defined $val and $val =~ /(.*): (.*)/) {
                    my $tag = $1;
                    $val = $2;
                    $tag =~ s/'s//; # remove 's (so "Owner's Name" becomes "OwnerName")
                    $tag =~ tr/a-zA-Z0-9_//cd; # remove unknown characters
                    if ($tag) {
                        $tagInfo = {
                            Name => $tag,
                            Condition => '$$self{TIFF_TYPE} ne "DCR"',
                            ValueConv => '$_=$val;s/^.*: //;$_', # remove descr
                            PSRaw => 1, # (just as flag to avoid adding this again)
                        };
                        AddTagToTable($tagTablePtr, $tagID, $tagInfo);
                        # generate conditional list if a conditional tag already existed
                        $$tagTablePtr{$tagID} = [ $oldInfo, $tagInfo ] if $oldInfo;
                    }
                }
            }
        }
        if (defined $tagInfo and not $tagInfo) {
            if ($bad) {
                undef $tagInfo;
            } else {
                # GetTagInfo() required the value for a Condition
                my $tmpVal = substr($$valueDataPt, $valuePtr, $readSize < 128 ? $readSize : 128);
                # (use original format name in this call -- $formatStr may have been changed to int8u)
                $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID, \$tmpVal,
                                           $formatName[$format], $count);
            }
        }
        # make sure we are handling the 'ifd' format properly
        if (($format == 13 or $format == 18) and (not $tagInfo or not $$tagInfo{SubIFD})) {
            my $str = sprintf('%s tag 0x%.4x IFD format not handled', $dirName, $tagID);
            $et->Warn($str, $inMakerNotes);
        }
        if (defined $tagInfo) {
            my $readFormat = $$tagInfo{Format};
            $subdir = $$tagInfo{SubDirectory};
            # unless otherwise specified, all SubDirectory data except
            # EXIF SubIFD offsets should be unformatted
            $readFormat = 'undef' if $subdir and not $$tagInfo{SubIFD} and not $readFormat;
            # override EXIF format if specified
            if ($readFormat) {
                $formatStr = $readFormat;
                my $newNum = $formatNumber{$formatStr};
                if ($newNum and $newNum != $format) {
                    $origFormStr = $formatName[$format] . '[' . $count . ']';
                    $format = $newNum;
                    $size = $readSize = $$tagInfo{FixedSize} if $$tagInfo{FixedSize};
                    # adjust number of items for new format size
                    $count = int($size / $formatSize[$format]);
                }
            }
            # verify that offset-type values are integral
            if (($$tagInfo{IsOffset} or $$tagInfo{SubIFD}) and not $intFormat{$formatStr}) {
                $et->Warn(sprintf('Wrong format (%s) for %s 0x%.4x %s',$formatStr,$dir,$tagID,$$tagInfo{Name}));
                if ($validate) {
                    $$et{WrongFormat}{"$dir:$$tagInfo{Name}"} = 1;
                    $offsetInfo{$tagID} = [ $tagInfo, '' ];
                }
                next unless $verbose;
                $wrongFormat = 1;
            }
        } else {
            next unless $verbose;
        }
        unless ($bad) {
            # limit maximum length of data to reformat
            # (avoids long delays when processing some corrupted files)
            my $warned;
            if ($count > 100000 and $formatStr !~ /^(undef|string|binary)$/) {
                my $tagName = $tagInfo ? $$tagInfo{Name} : sprintf('tag 0x%.4x', $tagID);
                # (count of 196608 is typical for ColorMap)
                if ($tagName ne 'TransferFunction' or $count != 196608) {
                    my $minor = $count > 2000000 ? 0 : 2;
                    if ($et->Warn("Ignoring $dirName $tagName with excessive count", $minor)) {
                        next unless $$et{OPTIONS}{HtmlDump};
                        $warned = 1;
                    }
                }
            }
            if ($count > 500 and $formatStr !~ /^(undef|string|binary)$/ and
                (not $tagInfo or $$tagInfo{LongBinary} or $warned) and not $$et{OPTIONS}{IgnoreMinorErrors})
            {
                $et->WarnOnce('Not decoding some large array(s). Ignore minor errors to decode', 2) unless $warned;
                next if $$et{TAGS_FROM_FILE};   # don't generate bogus value when copying tags
                $val = "(large array of $count $formatStr values)";
            } else {
                # convert according to specified format
                $val = ReadValue($valueDataPt,$valuePtr,$formatStr,$count,$readSize,\$rational);
                # re-code if necessary
                if (defined $val) {
                    if ($formatStr eq 'utf8') {
                        $val = $et->Decode($val, 'UTF8');
                    } elsif ($strEnc and $formatStr eq 'string') {
                        $val = $et->Decode($val, $strEnc);
                    }
                }
            }
        }

        if ($verbose) {
            my $tval = $val;
            # also show as a rational
            $tval .= " ($rational)" if defined $rational;
            if ($htmlDump) {
                my ($tagName, $colName);
                if ($tagInfo) {
                    $tagName = $$tagInfo{Name};
                } elsif ($tagID == 0x927c and $dirName eq 'ExifIFD') {
                    $tagName = 'MakerNotes';
                } else {
                    $tagName = sprintf("Tag 0x%.4x",$tagID);
                }
                my $dname = sprintf("${dir}-%.2d", $index);
                # build our tool tip
                $size < 0 and $size = $count * $formatSize[$format];
                my $fstr = "$formatName[$format]\[$count]";
                $fstr = "$origFormStr read as $fstr" if $origFormStr and $origFormStr ne $fstr;
                $fstr .= ' <-- WRONG' if $wrongFormat;
                my $tip = sprintf("Tag ID: 0x%.4x\n", $tagID) .
                          "Format: $fstr\nSize: $size bytes\n";
                if ($size > 4) {
                    my $offPt = Get32u($dataPt,$entry+8);
                    # (test this with ../pics/{CanonEOS-1D_XMarkIII.hif,PanasonicDC-G9.rw2})
                    my $actPt = $valuePtr + $valueDataPos + $base - ($$et{EXIF_POS} || 0) + ($$et{BASE_FUDGE} || 0);
                    $tip .= sprintf("Value offset: 0x%.4x\n", $offPt);
                    # highlight tag name (red for bad size)
                    my $style = ($bad or not defined $tval) ? 'V' : 'H';
                    if ($actPt != $offPt) {
                        $tip .= sprintf("Actual offset: 0x%.4x\n", $actPt);
                        my $sign = $actPt < $offPt ? '-' : '';
                        $tip .= sprintf("Offset base: ${sign}0x%.4x\n", abs($actPt - $offPt));
                        $style = 'F' if $style eq 'H';  # purple for different offsets
                    }
                    if ($$et{EXIF_POS} and not $$et{BASE_FUDGE}) {
                        $tip .= sprintf("File offset:   0x%.4x\n", $actPt + $$et{EXIF_POS})
                    }
                    $colName = "<span class=$style>$tagName</span>";
                    $colName .= ' <span class=V>(odd)</span>' if $offPt & 0x01;
                } else {
                    $colName = $tagName;
                }
                $colName .= ' <span class=V>(err)</span>' if $wrongFormat;
                $colName .= ' <span class=V>(seq)</span>' if $tagID <= $lastID and not $inMakerNotes;
                $lastID = $tagID;
                if (not defined $tval) {
                    $tval = '<bad size/offset>';
                } else {
                    $tval = substr($tval,0,28) . '[...]' if length($tval) > 32;
                    if ($formatStr =~ /^(string|undef|binary)/) {
                        # translate non-printable characters
                        $tval =~ tr/\x00-\x1f\x7f-\xff/./;
                    } elsif ($tagInfo and Image::ExifTool::IsInt($tval)) {
                        if ($$tagInfo{IsOffset} or $$tagInfo{SubIFD}) {
                            $tval = sprintf('0x%.4x', $tval);
                            my $actPt = $val + $base - ($$et{EXIF_POS} || 0) + ($$et{BASE_FUDGE} || 0);
                            if ($actPt != $val) {
                                $tval .= sprintf("\nActual offset: 0x%.4x", $actPt);
                                my $sign = $actPt < $val ? '-' : '';
                                $tval .= sprintf("\nOffset base: ${sign}0x%.4x", abs($actPt - $val));
                            }
                        } elsif ($$tagInfo{PrintHex}) {
                            $tval = sprintf('0x%x', $tval);
                        }
                    }
                }
                $tip .= "Value: $tval";
                my $id = $offName;
                my $sid;
                ($subOffName, $id, $sid) = NextOffsetName($et, $offName) if $tagInfo and $$tagInfo{SubIFD};
                $et->HDump($entry+$dataPos+$base, 12, "$dname $colName", $tip, 1, $id);
                next if $valueDataLen < 0;  # don't process bad pointer entry
                if ($size > 4) {
                    my $exifDumpPos = $valuePtr + $valueDataPos + $base;
                    my $flag = 0;
                    if ($subdir) {
                        if ($$tagInfo{MakerNotes}) {
                            $flag = 0x04;
                        } elsif ($$tagInfo{NestedHtmlDump}) {
                            $flag = $$tagInfo{NestedHtmlDump} == 2 ? 0x10 : 0x04;
                        }
                    }
                    # add value data block (underlining maker notes data)
                    $et->HDump($exifDumpPos,$size,"$tagName value",'SAME', $flag, $sid);
                    if ($subdir and $$tagInfo{MakerNotes} and $$tagInfo{NotIFD}) {
                        $et->HDump($exifDumpPos,$size,"$tagName value",undef,undef,$$dirInfo{OffsetName});
                    }
                }
            } else {
                if ($tagID <= $lastID and not $inMakerNotes) {
                    my $str = $tagInfo ? ' '.$$tagInfo{Name} : '';
                    if ($tagID == $lastID) {
                        $et->Warn(sprintf('Duplicate tag 0x%.4x%s in %s', $tagID, $str, $dirName));
                    } else {
                        $et->Warn(sprintf('Tag ID 0x%.4x%s out of sequence in %s', $tagID, $str, $dirName));
                    }
                }
                $lastID = $tagID;
                if ($verbose > 0) {
                    my $fstr = $formatName[$format];
                    $fstr = "$origFormStr read as $fstr" if $origFormStr;
                    $et->VerboseInfo($tagID, $tagInfo,
                        Table   => $tagTablePtr,
                        Index   => $index,
                        Value   => $tval,
                        DataPt  => $valueDataPt,
                        DataPos => $valueDataPos + $base,
                        Size    => $size,
                        Start   => $valuePtr,
                        Format  => $fstr,
                        Count   => $count,
                    );
                }
            }
            next if not $tagInfo or $wrongFormat;
        }
        next unless defined $val;
#..............................................................................
# Handle SubDirectory tag types
#
        if ($subdir) {
            # don't process empty subdirectories
            unless ($size) {
                unless ($$tagInfo{MakerNotes} or $inMakerNotes) {
                    $et->Warn("Empty $$tagInfo{Name} data", 1);
                }
                next;
            }
            my (@values, $newTagTable, $dirNum, $newByteOrder, $invalid);
            my $tagStr = $$tagInfo{Name};
            if ($$subdir{MaxSubdirs}) {
                @values = split ' ', $val;
                # limit the number of subdirectories we parse
                my $over = @values - $$subdir{MaxSubdirs};
                if ($over > 0) {
                    $et->Warn("Ignoring $over $tagStr directories");
                    splice @values, $$subdir{MaxSubdirs};
                }
                $val = shift @values;
            }
            if ($$subdir{TagTable}) {
                $newTagTable = GetTagTable($$subdir{TagTable});
                $newTagTable or warn("Unknown tag table $$subdir{TagTable}"), next;
            } else {
                $newTagTable = $tagTablePtr;    # use existing table
            }
            # loop through all sub-directories specified by this tag
            for ($dirNum=0; ; ++$dirNum) {
                my $subdirBase = $base;
                my $subdirDataPt = $valueDataPt;
                my $subdirDataPos = $valueDataPos;
                my $subdirDataLen = $valueDataLen;
                my $subdirStart = $valuePtr;
                if (defined $$subdir{Start}) {
                    # set local $valuePtr relative to file $base for eval
                    my $valuePtr = $subdirStart + $subdirDataPos;
                    #### eval Start ($valuePtr, $val)
                    my $newStart = eval($$subdir{Start});
                    unless (Image::ExifTool::IsInt($newStart)) {
                        $et->Warn("Bad value for $tagStr");
                        last;
                    }
                    # convert back to relative to $subdirDataPt
                    $newStart -= $subdirDataPos;
                    # adjust directory size if necessary
                    unless ($$tagInfo{SubIFD} or $$subdir{BadOffset}) {
                        $size -= $newStart - $subdirStart;
                    }
                    $subdirStart = $newStart;
                }
                # this is a pain, but some maker notes are always a specific
                # byte order, regardless of the byte order of the file
                my $oldByteOrder = GetByteOrder();
                $newByteOrder = $$subdir{ByteOrder};
                if ($newByteOrder) {
                    if ($newByteOrder =~ /^Little/i) {
                        $newByteOrder = 'II';
                    } elsif ($newByteOrder =~ /^Big/i) {
                        $newByteOrder = 'MM';
                    } elsif ($$subdir{OffsetPt}) {
                        undef $newByteOrder;
                        warn "Can't have variable byte ordering for SubDirectories using OffsetPt";
                        last;
                    } elsif ($subdirStart + 2 <= $subdirDataLen) {
                        # attempt to determine the byte ordering by checking
                        # the number of directory entries.  This is an int16u
                        # that should be a reasonable value.
                        my $num = Get16u($subdirDataPt, $subdirStart);
                        if ($num & 0xff00 and ($num>>8) > ($num&0xff)) {
                            # This looks wrong, we shouldn't have this many entries
                            my %otherOrder = ( II=>'MM', MM=>'II' );
                            $newByteOrder = $otherOrder{$oldByteOrder};
                        } else {
                            $newByteOrder = $oldByteOrder;
                        }
                    }
                } else {
                    $newByteOrder = $oldByteOrder;
                }
                # set base offset if necessary
                if ($$subdir{Base}) {
                    # calculate subdirectory start relative to $base for eval
                    my $start = $subdirStart + $subdirDataPos;
                    #### eval Base ($start,$base)
                    $subdirBase = eval($$subdir{Base}) + $base;
                }
                # add offset to the start of the directory if necessary
                if ($$subdir{OffsetPt}) {
                    #### eval OffsetPt ($valuePtr)
                    my $pos = eval $$subdir{OffsetPt};
                    if ($pos + 4 > $subdirDataLen) {
                        $et->Warn("Bad $tagStr OffsetPt");
                        last;
                    }
                    SetByteOrder($newByteOrder);
                    $subdirStart += Get32u($subdirDataPt, $pos);
                    SetByteOrder($oldByteOrder);
                }
                if ($subdirStart < 0 or $subdirStart + 2 > $subdirDataLen) {
                    # convert $subdirStart back to a file offset
                    if ($raf) {
                        # reset SubDirectory buffer (we will load it later)
                        my $buff = '';
                        $subdirDataPt = \$buff;
                        $subdirDataLen = $size = length $buff;
                    } else {
                        my $msg = "Bad $tagStr SubDirectory start";
                        if ($verbose > 0) {
                            if ($subdirStart < 0) {
                                $msg .= " (directory start $subdirStart is before EXIF start)";
                            } else {
                                my $end = $subdirStart + $size;
                                $msg .= " (directory end is $end but EXIF size is only $subdirDataLen)";
                            }
                        }
                        $et->Warn($msg, $inMakerNotes);
                        last;
                    }
                }

                # must update subdirDataPos if $base changes for this subdirectory
                $subdirDataPos += $base - $subdirBase;

                # build information hash for new directory
                my %subdirInfo = (
                    Name       => $tagStr,
                    Base       => $subdirBase,
                    DataPt     => $subdirDataPt,
                    DataPos    => $subdirDataPos,
                    DataLen    => $subdirDataLen,
                    DirStart   => $subdirStart,
                    DirLen     => $size,
                    RAF        => $raf,
                    Parent     => $dirName,
                    DirName    => $$subdir{DirName},
                    FixBase    => $$subdir{FixBase},
                    FixOffsets => $$subdir{FixOffsets},
                    EntryBased => $$subdir{EntryBased},
                    TagInfo    => $tagInfo,
                    SubIFD     => $$tagInfo{SubIFD},
                    Subdir     => $subdir,
                    OffsetName => $subOffName,
                );
                # (remember: some cameras incorrectly write maker notes in IFD0)
                if ($$tagInfo{MakerNotes}) {
                    # don't parse makernotes if FastScan > 1
                    my $fast = $et->Options('FastScan');
                    last if $fast and $fast > 1;
                    $subdirInfo{MakerNoteAddr} = $valuePtr + $valueDataPos + $base;
                    $subdirInfo{NoFixBase} = 1 if defined $$subdir{Base};
                }
                # set directory IFD name from group name of family 1 if it exists,
                # unless the tag is writable as a block in which case group 1 may
                # have been set automatically
                if ($$tagInfo{Groups} and not $$tagInfo{Writable}) {
                    $subdirInfo{DirName} = $$tagInfo{Groups}{1};
                    # number multiple subdirectories
                    $subdirInfo{DirName} =~ s/\d*$/$dirNum/ if $dirNum;
                }
                SetByteOrder($newByteOrder);    # set byte order for this subdir
                # validate the subdirectory if necessary
                my $dirData = $subdirDataPt;    # set data pointer to be used in eval
                #### eval Validate ($val, $dirData, $subdirStart, $size)
                my $ok = 0;
                if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                    $et->Warn("Invalid $tagStr data", $inMakerNotes);
                    $invalid = 1;
                } else {
                    if (not $subdirInfo{DirName} and $inMakerNotes) {
                        $subdirInfo{DirName} = $$tagInfo{Name};
                    }
                    # process the subdirectory
                    $ok = $et->ProcessDirectory(\%subdirInfo, $newTagTable, $$subdir{ProcessProc});
                }
                # print debugging information if there were errors
                if (not $ok and $verbose > 1 and $subdirStart != $valuePtr) {
                    my $out = $et->Options('TextOut');
                    printf $out "%s    (SubDirectory start = 0x%x)\n", $$et{INDENT}, $subdirStart;
                }
                SetByteOrder($oldByteOrder);    # restore original byte swapping

                @values or last;
                $val = shift @values;           # continue with next subdir
            }
            my $doMaker = $et->Options('MakerNotes');
            next unless $doMaker or $$et{REQ_TAG_LOOKUP}{lc($tagStr)} or $$tagInfo{BlockExtract};
            # extract as a block if specified
            if ($$tagInfo{MakerNotes}) {
                # save maker note byte order (if it was significant and valid)
                if ($$subdir{ByteOrder} and not $invalid) {
                    $$et{MAKER_NOTE_BYTE_ORDER} =
                        defined ($$et{UnknownByteOrder}) ?
                                 $$et{UnknownByteOrder} : $newByteOrder;
                }
                if ($doMaker and $doMaker eq '2') {
                    # extract maker notes without rebuilding (no fixup information)
                    delete $$et{MAKER_NOTE_FIXUP};
                } elsif (not $$tagInfo{NotIFD} or $$tagInfo{IsPhaseOne}) {
                    # this is a pain, but we must rebuild EXIF-type maker notes to
                    # include all the value data if data was outside the maker notes
                    my %makerDirInfo = (
                        Name       => $tagStr,
                        Base       => $base,
                        DataPt     => $valueDataPt,
                        DataPos    => $valueDataPos,
                        DataLen    => $valueDataLen,
                        DirStart   => $valuePtr,
                        DirLen     => $size,
                        RAF        => $raf,
                        Parent     => $dirName,
                        DirName    => 'MakerNotes',
                        FixOffsets => $$subdir{FixOffsets},
                        TagInfo    => $tagInfo,
                    );
                    my $val2;
                    if ($$tagInfo{IsPhaseOne}) {
                        $$et{DropTags} = 1;
                        $val2 = Image::ExifTool::PhaseOne::WritePhaseOne($et, \%makerDirInfo, $newTagTable);
                        delete $$et{DropTags};
                    } else {
                        $makerDirInfo{FixBase} = 1 if $$subdir{FixBase};
                        # rebuild maker notes (creates $$et{MAKER_NOTE_FIXUP})
                        $val2 = RebuildMakerNotes($et, \%makerDirInfo, $newTagTable);
                    }
                    if (defined $val2) {
                        $val = $val2;
                    } elsif ($size > 4) {
                        $et->Warn('Error rebuilding maker notes (may be corrupt)');
                    }
                }
            } else {
                # extract this directory as a block if specified
                next unless $$tagInfo{Writable};
            }
        }
 #..............................................................................
        # convert to absolute offsets if this tag is an offset
        #### eval IsOffset ($val, $et)
        if ($$tagInfo{IsOffset} and eval $$tagInfo{IsOffset}) {
            my $offsetBase = $$tagInfo{IsOffset} eq '2' ? $firstBase : $base;
            $offsetBase += $$et{BASE};
            # handle offsets which use a wrong base (Minolta A200)
            if ($$tagInfo{WrongBase}) {
                my $self = $et;
                #### eval WrongBase ($self)
                $offsetBase += eval $$tagInfo{WrongBase} || 0;
            }
            my @vals = split(' ',$val);
            foreach $val (@vals) {
                $val += $offsetBase;
            }
            $val = join(' ', @vals);
        }
        if ($validate or $doHash) {
            if ($$tagInfo{OffsetPair}) {
                $offsetInfo{$tagID} = [ $tagInfo, $val ];
            } elsif ($saveForValidate{$tagID} and $isExif) {
                $offsetInfo{$tagID} = $val;
            }
        }
        # save the value of this tag
        $tagKey = $et->FoundTag($tagInfo, $val);
        if (defined $tagKey) {
            # set the group 1 name for tags in specified tables
            $et->SetGroup($tagKey, $dirName) if $$tagTablePtr{SET_GROUP1};
            # save original components of rational numbers (used when copying)
            $$et{RATIONAL}{$tagKey} = $rational if defined $rational;
            $$et{TAG_EXTRA}{$tagKey}{G6} = $saveFormat if $saveFormat;
            if ($$et{MAKER_NOTE_FIXUP}) {
                $$et{TAG_EXTRA}{$tagKey}{Fixup} = $$et{MAKER_NOTE_FIXUP};
                delete $$et{MAKER_NOTE_FIXUP};
            }
        }
    }

    if (%offsetInfo) {
        # calculate image data hash if requested
        AddImageDataHash($et, $dirInfo, \%offsetInfo) if $doHash;
        # validate image data offsets for this IFD (note: modifies %offsetInfo)
        Image::ExifTool::Validate::ValidateOffsetInfo($et, \%offsetInfo, $dirName, $inMakerNotes) if $validate;
    }

    # scan for subsequent IFD's if specified
    if ($$dirInfo{Multi} and $bytesFromEnd >= 4) {
        # use same directory information for trailing directory,
        # but change the start location (ProcessDirectory will
        # test to make sure we don't reprocess the same dir twice)
        my %newDirInfo = %$dirInfo;
        $newDirInfo{Multi} = 0;  # prevent recursion
        $newDirInfo{OffsetName} = $nextOffName;
        $$et{INDENT} =~ s/..$//; # keep indent the same
        for (;;) {
            my $offset = Get32u($dataPt, $dirEnd) or last;
            $newDirInfo{DirStart} = $offset - $dataPos;
            # increment IFD number
            my $ifdNum = $newDirInfo{DirName} =~ s/(\d+)$// ? $1 : 0;
            $newDirInfo{DirName} .= $ifdNum + 1;
            # must validate SubIFD1 because the nextIFD pointer is invalid for some RAW formats
            if ($newDirInfo{DirName} ne 'SubIFD1' or ValidateIFD(\%newDirInfo)) {
                my $cur = pop @{$$et{PATH}};
                $et->ProcessDirectory(\%newDirInfo, $tagTablePtr) or $success = 0;
                push @{$$et{PATH}}, $cur;
                if ($success and $newDirInfo{BytesFromEnd} >= 4) {
                    $dataPt = $newDirInfo{DataPt};
                    $dataPos = $newDirInfo{DataPos};
                    $dirEnd = $newDirInfo{DirEnd};
                    next;
                }
            } elsif ($verbose or $$et{TIFF_TYPE} eq 'TIFF') {
                $et->Warn('Ignored bad IFD linked from SubIFD');
            }
            last;
        }
    } elsif (defined $$dirInfo{Multi}) {
        # return necessary parameters for parsing next IFD
        $$dirInfo{DirEnd} = $dirEnd;
        $$dirInfo{OffsetName} = $nextOffName;
        $$dirInfo{BytesFromEnd} = $bytesFromEnd;
    }
    return $success;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Exif - Read EXIF/TIFF meta information

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool for processing
EXIF and TIFF meta information.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.exif.org/Exif2-2.PDF>

=item L<http://www.cipa.jp/std/documents/e/DC-008-2012_E.pdf>

=item L<http://partners.adobe.com/asn/developer/pdfs/tn/TIFF6.pdf>

=item L<http://partners.adobe.com/public/developer/en/tiff/TIFFPM6.pdf>

=item L<http://www.adobe.com/products/dng/pdfs/dng_spec.pdf>

=item L<http://www.awaresystems.be/imaging/tiff/tifftags.html>

=item L<http://www.remotesensing.org/libtiff/TIFFTechNote2.html>

=item L<http://www.exif.org/dcf.PDF>

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.fine-view.com/jp/lab/doc/ps6ffspecsv2.pdf>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html>

=item L<http://hul.harvard.edu/jhove/tiff-tags.html>

=item L<http://www.microsoft.com/whdc/xps/wmphoto.mspx>

=item L<http://www.asmail.be/msg0054681802.html>

=item L<http://crousseau.free.fr/imgfmt_raw.htm>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://www.digitalpreservation.gov/formats/content/tiff_tags.shtml>

=item L<http://community.roxen.com/developers/idocs/rfc/rfc3949.html>

=item L<http://tools.ietf.org/html/draft-ietf-fax-tiff-fx-extension1-01>

=item L<http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/cinemadng/pdfs/CinemaDNG_Format_Specification_v1_1.pdf>

=item L<http://geotiff.maptools.org/spec/geotiffhome.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Jeremy Brown for the 35efl tags, and Matt Madrid for his help with
the XP character code conversions.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/EXIF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
