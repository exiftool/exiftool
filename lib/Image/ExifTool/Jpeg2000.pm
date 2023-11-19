#------------------------------------------------------------------------------
# File:         Jpeg2000.pm
#
# Description:  Read JPEG 2000 meta information
#
# Revisions:    02/11/2005 - P. Harvey Created
#               06/22/2007 - PH Added write support (EXIF, IPTC and XMP only)
#
# References:   1) http://www.jpeg.org/public/fcd15444-2.pdf
#               2) ftp://ftp.remotesensing.org/jpeg2000/fcd15444-1.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Jpeg2000;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.36';

sub ProcessJpeg2000Box($$$);
sub ProcessJUMD($$$);

my %resolutionUnit = (
    -3 => 'km',
    -2 => '100 m',
    -1 => '10 m',
     0 => 'm',
     1 => '10 cm',
     2 => 'cm',
     3 => 'mm',
     4 => '0.1 mm',
     5 => '0.01 mm',
     6 => 'um',
);

# top-level boxes containing image data
my %isImageData = ( jp2c=>1, jbrd=>1, jxlp=>1, jxlc=>1 );

# map of where information is written in JPEG2000 image
my %jp2Map = (
    IPTC         => 'UUID-IPTC',
    IFD0         => 'UUID-EXIF',
    XMP          => 'UUID-XMP',
   'UUID-IPTC'   => 'JP2',
   'UUID-EXIF'   => 'JP2',
   'UUID-XMP'    => 'JP2',
    jp2h         => 'JP2',
    colr         => 'jp2h',
    ICC_Profile  => 'colr',
    IFD1         => 'IFD0',
    EXIF         => 'IFD0', # to write EXIF as a block
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);

# map of where information is written in a JXL image
my %jxlMap = (
    IFD0         => 'Exif',
    XMP          => 'xml ',
   'Exif'        => 'JP2',
    IFD1         => 'IFD0',
    EXIF         => 'IFD0', # to write EXIF as a block
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);

# UUID's for writable UUID directories (by tag name)
my %uuid = (
    'UUID-EXIF'   => 'JpgTiffExif->JP2',
    'UUID-EXIF2'  => '',    # (flags a warning when writing)
    'UUID-EXIF_bad' => '0', # (flags a warning when reading and writing)
    'UUID-IPTC'   => "\x33\xc7\xa4\xd2\xb8\x1d\x47\x23\xa0\xba\xf1\xa3\xe0\x97\xad\x38",
    'UUID-XMP'    => "\xbe\x7a\xcf\xcb\x97\xa9\x42\xe8\x9c\x71\x99\x94\x91\xe3\xaf\xac",
  # (can't yet write GeoJP2 information)
  # 'UUID-GeoJP2' => "\xb1\x4b\xf8\xbd\x08\x3d\x4b\x43\xa5\xae\x8c\xd7\xd5\xa6\xce\x03",
);

# JPEG2000 codestream markers (ref ISO/IEC FCD15444-1/2)
my %j2cMarker = (
    0x4f => 'SOC', # start of codestream
  # 0x50 - seen in JPH codestream
    0x51 => 'SIZ', # image and tile size
    0x52 => 'COD', # coding style default
    0x53 => 'COC', # coding style component
    0x55 => 'TLM', # tile-part lengths
    0x57 => 'PLM', # packet length, main header
    0x58 => 'PLT', # packet length, tile-part header
  # 0x59 - seen in JPH codestream
    0x5c => 'QCD', # quantization default
    0x5d => 'QCC', # quantization component
    0x5e => 'RGN', # region of interest
    0x5f => 'POD', # progression order default
    0x60 => 'PPM', # packed packet headers, main
    0x61 => 'PPT', # packed packet headers, tile-part
    0x63 => 'CRG', # component registration
    0x64 => 'CME', # comment and extension
    0x90 => 'SOT', # start of tile-part
    0x91 => 'SOP', # start of packet
    0x92 => 'EPH', # end of packet header
    0x93 => 'SOD', # start of data
    # extensions (ref ISO/IEC FCD15444-2)
    0x70 => 'DCO', # variable DC offset
    0x71 => 'VMS', # visual masking
    0x72 => 'DFS', # downsampling factor style
    0x73 => 'ADS', # arbitrary decomposition style
  # 0x72 => 'ATK', # arbitrary transformation kernels ?
    0x78 => 'CBD', # component bit depth
    0x74 => 'MCT', # multiple component transformation definition
    0x75 => 'MCC', # multiple component collection
    0x77 => 'MIC', # multiple component intermediate collection
    0x76 => 'NLT', # non-linearity point transformation
);

# JPEG 2000 "box" (ie. atom) names
# Note: only tags with a defined "Format" are extracted
%Image::ExifTool::Jpeg2000::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessJpeg2000Box,
    WRITE_PROC => \&ProcessJpeg2000Box,
    PREFERRED => 1, # always add these tags when writing
    NOTES => q{
        The tags below are found in JPEG 2000 images and the C2PA CAI JUMBF metadata
        in various file types (see below).  Note that ExifTool currently writes only
        EXIF, IPTC and XMP tags in Jpeg2000 images, and EXIF and XMP in JXL images. 
        ExifTool will read/write Brotli-compressed EXIF and XMP in JXL images, but
        the API L<Compress|../ExifTool.html#Compress> option must be set to create new EXIF and XMP in compressed
        format.

        C2PA (Coalition for Content Provenance and Authenticity) CAI (Content
        Authenticity Initiative) JUMBF (JPEG Universal Metadata Box Format) metdata
        is currently extracted from JPEG, PNG, TIFF-based (eg. TIFF, DNG),
        QuickTime-based (eg. MP4, MOV, HEIF, AVIF), RIFF-based (eg. WAV, AVI, WebP),
        GIF files and ID3v2 metadata.  The suggested ExifTool command-line arguments
        for reading C2PA metadata are C<-jumbf:all -G3 -b -j -u -struct>.  This
        metadata may be deleted from writable JPEG, PNG, WebP, TIFF-based, and
        QuickTime-based files by deleting the JUMBF group with C<-jumbf:all=>.
    },
#
# NOTE: ONLY TAGS WITH "Format" DEFINED ARE EXTRACTED!
#
   'jP  ' => 'JP2Signature', # (ref 1)
   "jP\x1a\x1a" => 'JP2Signature', # (ref 2)
    prfl => 'Profile',
    ftyp => {
        Name => 'FileType',
        SubDirectory => { TagTable => 'Image::ExifTool::Jpeg2000::FileType' },
    },
    rreq => 'ReaderRequirements',
    jp2h => {
        Name => 'JP2Header',
        SubDirectory => { },
    },
        # JP2Header sub boxes...
        ihdr => {
            Name => 'ImageHeader',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Jpeg2000::ImageHeader',
            },
        },
        bpcc => 'BitsPerComponent',
        colr => {
            Name => 'ColorSpecification',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Jpeg2000::ColorSpec',
            },
        },
        pclr => 'Palette',
        cdef => 'ComponentDefinition',
       'res '=> {
            Name => 'Resolution',
            SubDirectory => { },
        },
            # Resolution sub boxes...
            resc => {
                Name => 'CaptureResolution',
                SubDirectory => {
                    TagTable => 'Image::ExifTool::Jpeg2000::CaptureResolution',
                },
            },
            resd => {
                Name => 'DisplayResolution',
                SubDirectory => {
                    TagTable => 'Image::ExifTool::Jpeg2000::DisplayResolution',
                },
            },
    jpch => {
        Name => 'CodestreamHeader',
        SubDirectory => { },
    },
        # CodestreamHeader sub boxes...
       'lbl '=> {
            Name => 'Label',
            Format => 'string',
        },
        cmap => 'ComponentMapping',
        roid => 'ROIDescription',
    jplh => {
        Name => 'CompositingLayerHeader',
        SubDirectory => { },
    },
        # CompositingLayerHeader sub boxes...
        cgrp => 'ColorGroup',
        opct => 'Opacity',
        creg => 'CodestreamRegistration',
    dtbl => 'DataReference',
    ftbl => {
        Name => 'FragmentTable',
        Subdirectory => { },
    },
        # FragmentTable sub boxes...
        flst => 'FragmentList',
    cref => 'Cross-Reference',
    mdat => 'MediaData',
    comp => 'Composition',
    copt => 'CompositionOptions',
    inst => 'InstructionSet',
    asoc => {
        Name => 'Association',
        SubDirectory => { },
    },
        # (Association box may contain any other sub-box)
    nlst => 'NumberList',
    bfil => 'BinaryFilter',
    drep => 'DesiredReproductions',
        # DesiredReproductions sub boxes...
        gtso => 'GraphicsTechnologyStandardOutput',
    chck => 'DigitalSignature',
    mp7b => 'MPEG7Binary',
    free => 'Free',
    jp2c => [{
        Name => 'ContiguousCodestream',
        Condition => 'not $$self{jumd_level}',
    },{
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
    }],
    jp2i => {
        Name => 'IntellectualProperty',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
   'xml '=> [{
        Name => 'XML',
        Condition => 'not $$self{IsJXL}',
        Writable => 'undef',
        Flags => [ 'Binary', 'Protected', 'BlockExtract' ],
        List => 1,
        Notes => q{
            by default, the XML data in this tag is parsed using the ExifTool XMP module
            to to allow individual tags to be accessed when reading, but it may also be
            extracted as a block via the "XML" tag, which is also how this tag is
            written and copied.  It may also be extracted as a block by setting the API
            BlockExtract option.  This is a List-type tag because multiple XML blocks
            may exist
        },
        # (note: extracting as a block was broken in 11.04, and finally fixed in 12.14)
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::XML' },
    },{
        Name => 'XMP',
        Notes => 'used for XMP in JPEG XL files',
        # NOTE: the hacked code relies on this being at index 1 of the tagInfo list!
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    }],
    uuid => [
        {
            Name => 'UUID-EXIF',
            # (this is the EXIF that we create in JP2)
            Condition => '$$valPt=~/^JpgTiffExif->JP2(?!Exif\0\0)/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&Image::ExifTool::ProcessTIFF,
                WriteProc => \&Image::ExifTool::WriteTIFF,
                DirName => 'EXIF',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-EXIF2',
            # written by Photoshop 7.01+Adobe JPEG2000-plugin v1.5
            Condition => '$$valPt=~/^\x05\x37\xcd\xab\x9d\x0c\x44\x31\xa7\x2a\xfa\x56\x1f\x2a\x11\x3e/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&Image::ExifTool::ProcessTIFF,
                WriteProc => \&Image::ExifTool::WriteTIFF,
                DirName => 'EXIF',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-EXIF_bad',
            # written by Digikam
            Condition => '$$valPt=~/^JpgTiffExif->JP2/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&Image::ExifTool::ProcessTIFF,
                WriteProc => \&Image::ExifTool::WriteTIFF,
                DirName => 'EXIF',
                Start => '$valuePtr + 22',
            },
        },
        {
            Name => 'UUID-IPTC',
            # (this is the IPTC that we create in JP2)
            Condition => '$$valPt=~/^\x33\xc7\xa4\xd2\xb8\x1d\x47\x23\xa0\xba\xf1\xa3\xe0\x97\xad\x38/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::IPTC::Main',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-IPTC2',
            # written by Photoshop 7.01+Adobe JPEG2000-plugin v1.5
            Condition => '$$valPt=~/^\x09\xa1\x4e\x97\xc0\xb4\x42\xe0\xbe\xbf\x36\xdf\x6f\x0c\xe3\x6f/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::IPTC::Main',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-XMP',
            # ref http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf
            Condition => '$$valPt=~/^\xbe\x7a\xcf\xcb\x97\xa9\x42\xe8\x9c\x71\x99\x94\x91\xe3\xaf\xac/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::XMP::Main',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-GeoJP2',
            # ref http://www.remotesensing.org/jpeg2000/
            Condition => '$$valPt=~/^\xb1\x4b\xf8\xbd\x08\x3d\x4b\x43\xa5\xae\x8c\xd7\xd5\xa6\xce\x03/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
                ProcessProc => \&Image::ExifTool::ProcessTIFF,
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-Photoshop',
            # written by Photoshop 7.01+Adobe JPEG2000-plugin v1.5
            Condition => '$$valPt=~/^\x2c\x4c\x01\x00\x85\x04\x40\xb9\xa0\x3e\x56\x21\x48\xd6\xdf\xeb/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Photoshop::Main',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-C2PAClaimSignature',  # (seen in incorrectly-formatted JUMB data of JPEG images)
            # (may be able to remove this when JUMBF specification is finalized)
            Condition => '$$valPt=~/^c2cs\x00\x11\x00\x10\x80\x00\x00\xaa\x00\x38\x9b\x71/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::CBOR::Main',
                Start => '$valuePtr + 16',
            },
        },
        {
            Name => 'UUID-Signature',  # (seen in JUMB data of JPEG images)
            # (may be able to remove this when JUMBF specification is finalized)
            Condition => '$$valPt=~/^casg\x00\x11\x00\x10\x80\x00\x00\xaa\x00\x38\x9b\x71/',
            Format => 'undef',
            ValueConv => 'substr($val,16)',
        },
        {
            Name => 'UUID-Unknown',
        },
        # also written by Adobe JPEG2000 plugin v1.5:
        # 3a 0d 02 18 0a e9 41 15 b3 76 4b ca 41 ce 0e 71 - 1 byte (01)
        # 47 c9 2c cc d1 a1 45 81 b9 04 38 bb 54 67 71 3b - 1 byte (01)
        # bc 45 a7 74 dd 50 4e c6 a9 f6 f3 a1 37 f4 7e 90 - 4 bytes (00 00 00 32)
        # d7 c8 c5 ef 95 1f 43 b2 87 57 04 25 00 f5 38 e8 - 4 bytes (00 00 00 32)
    ],
    uinf => {
        Name => 'UUIDInfo',
        SubDirectory => { },
    },
        # UUIDInfo sub boxes...
        ulst => 'UUIDList',
       'url '=> {
            Name => 'URL',
            Format => 'string',
        },
    # JUMBF boxes (ref https://github.com/thorfdbg/codestream-parser)
    jumd => {
        Name => 'JUMBFDescr',
        SubDirectory => { TagTable => 'Image::ExifTool::Jpeg2000::JUMD' },
    },
    jumb => {
        Name => 'JUMBFBox',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Jpeg2000::Main',
            ProcessProc => \&ProcessJUMB,
        },
    },
    json => {
        Name => 'JSONData',
        Flags => [ 'Binary', 'Protected', 'BlockExtract' ],
        Notes => q{
            by default, data in this tag is parsed using the ExifTool JSON module to to
            allow individual tags to be accessed when reading, but it may also be
            extracted as a block via the "JSONData" tag or by setting the API
            BlockExtract option
        },
        SubDirectory => { TagTable => 'Image::ExifTool::JSON::Main' },
    },
    cbor => {
        Name => 'CBORData',
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => { TagTable => 'Image::ExifTool::CBOR::Main' },
    },
    bfdb => { # used in JUMBF (see  # (used when tag is renamed according to JUMDLabel)
        Name => 'BinaryDataType',
        Notes => 'JUMBF, MIME type and optional file name',
        Format => 'undef',
        # (ignore "toggles" byte and just extract MIME type and file name)
        ValueConv => '$_=substr($val,1); s/\0+$//; s/\0/, /; $_',
        JUMBF_Suffix => 'Type', # (used when tag is renamed according to JUMDLabel)
    },
    bidb => { # used in JUMBF
        Name => 'BinaryData',
        Notes => 'JUMBF',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
        JUMBF_Suffix => 'Data', # (used when tag is renamed according to JUMDLabel)
    },
    c2sh => { # used in JUMBF
        Name => 'C2PASaltHash',
        Format => 'undef',
        ValueConv => 'unpack("H*",$val)',
        JUMBF_Suffix => 'Salt', # (used when tag is renamed according to JUMDLabel)
    },
#
# stuff seen in JPEG XL images:
#
  # jbrd - JPEG Bitstream Reconstruction Data (allows lossless conversion back to original JPG)
    jxlc => {
        Name => 'JXLCodestream',
        Format => 'undef',
        Notes => q{
            Codestream in JPEG XL image.  Currently processed only to determine
            ImageSize
        },
        RawConv => 'Image::ExifTool::Jpeg2000::ProcessJXLCodestream($self,\$val); undef',
    },
    jxlp => {
        Name => 'PartialJXLCodestream',
        Format => 'undef',
        Notes => q{
            Partial codestreams in JPEG XL image.  Currently processed only to determine
            ImageSize
        },
        RawConv => 'Image::ExifTool::Jpeg2000::ProcessJXLCodestream($self,\$val); undef',
    },
    Exif => {
        Name => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
            DirName => 'EXIF',
            Start => '$valuePtr + 4 + (length($$dataPt)-$valuePtr > 4 ? unpack("N", $$dataPt) : 0)',
        },
    },
    hrgm => {
        Name => 'GainMapImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
    },
    brob => [{ # Brotli-encoded metadata (see https://libjxl.readthedocs.io/en/latest/api_decoder.html)
        Name => 'BrotliXMP',
        Condition => '$$valPt =~ /^xml /i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            ProcessProc => \&ProcessBrotli,
            WriteProc => \&ProcessBrotli,
            # (don't set DirName to 'XMP' because this would enable a block write of raw XMP)
        },
    },{
        Name => 'BrotliEXIF',
        Condition => '$$valPt =~ /^exif/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&ProcessBrotli,
            WriteProc => \&ProcessBrotli,
            # (don't set DirName to 'EXIF' because this would enable a block write of raw EXIF)
        },
    },{
        Name => 'BrotliJUMB',
        Condition => '$$valPt =~ /^jumb/i',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Jpeg2000::Main',
            ProcessProc => \&ProcessBrotli,
        },
    }],
);

%Image::ExifTool::Jpeg2000::ImageHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ImageHeight',
        Format => 'int32u',
    },
    4 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    8 => {
        Name => 'NumberOfComponents',
        Format => 'int16u',
    },
    10 => {
        Name => 'BitsPerComponent',
        PrintConv => q{
            $val == 0xff and return 'Variable';
            my $sign = ($val & 0x80) ? 'Signed' : 'Unsigned';
            return (($val & 0x7f) + 1) . " Bits, $sign";
        },
    },
    11 => {
        Name => 'Compression',
        PrintConv => {
            0 => 'Uncompressed',
            1 => 'Modified Huffman',
            2 => 'Modified READ',
            3 => 'Modified Modified READ',
            4 => 'JBIG',
            5 => 'JPEG',
            6 => 'JPEG-LS',
            7 => 'JPEG 2000',
            8 => 'JBIG2',
        },
    },
);

# (ref fcd15444-1/2/6.pdf)
# (also see http://developer.apple.com/mac/library/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html)
%Image::ExifTool::Jpeg2000::FileType = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    0 => {
        Name => 'MajorBrand',
        Format => 'undef[4]',
        PrintConv => {
            'jp2 ' => 'JPEG 2000 Image (.JP2)',           # image/jp2
            'jpm ' => 'JPEG 2000 Compound Image (.JPM)',  # image/jpm
            'jpx ' => 'JPEG 2000 with extensions (.JPX)', # image/jpx
            'jxl ' => 'JPEG XL Image (.JXL)',             # image/jxl
            'jph ' => 'High-throughput JPEG 2000 (.JPH)', # image/jph
        },
    },
    1 => {
        Name => 'MinorVersion',
        Format => 'undef[4]',
        ValueConv => 'sprintf("%x.%x.%x", unpack("nCC", $val))',
    },
    2 => {
        Name => 'CompatibleBrands',
        Format => 'undef[$size-8]',
        # ignore any entry with a null, and return others as a list
        ValueConv => 'my @a=($val=~/.{4}/sg); @a=grep(!/\0/,@a); \@a',
    },
);

%Image::ExifTool::Jpeg2000::CaptureResolution = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int8s',
    0 => {
        Name => 'CaptureYResolution',
        Format => 'rational32u',
    },
    4 => {
        Name => 'CaptureXResolution',
        Format => 'rational32u',
    },
    8 => {
        Name => 'CaptureYResolutionUnit',
        SeparateTable => 'ResolutionUnit',
        PrintConv => \%resolutionUnit,
    },
    9 => {
        Name => 'CaptureXResolutionUnit',
        SeparateTable => 'ResolutionUnit',
        PrintConv => \%resolutionUnit,
    },
);

%Image::ExifTool::Jpeg2000::DisplayResolution = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int8s',
    0 => {
        Name => 'DisplayYResolution',
        Format => 'rational32u',
    },
    4 => {
        Name => 'DisplayXResolution',
        Format => 'rational32u',
    },
    8 => {
        Name => 'DisplayYResolutionUnit',
        SeparateTable => 'ResolutionUnit',
        PrintConv => \%resolutionUnit,
    },
    9 => {
        Name => 'DisplayXResolutionUnit',
        SeparateTable => 'ResolutionUnit',
        PrintConv => \%resolutionUnit,
    },
);

%Image::ExifTool::Jpeg2000::ColorSpec = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData, # (we don't actually call this)
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int8s',
    WRITABLE => 1,
    # (Note: 'colr' is not a real group, but is used as a hack to write the
    #  necessary colr box.  This hack necessitated another hack in TagInfoXML.pm
    #  to avoid reporting this fake group in the XML output)
    WRITE_GROUP => 'colr',
    DATAMEMBER => [ 0 ],
    IS_SUBDIR => [ 3 ],
    NOTES => q{
        The table below contains tags in the color specification (colr) box.  This
        box may be rewritten by writing either ICC_Profile, ColorSpace or
        ColorSpecData.  When writing, any existing colr boxes are replaced with the
        newly created colr box.

        B<NOTE>: Care must be taken when writing this color specification because
        writing a specification that is incompatible with the image data may make
        the image undisplayable.
    },
    0 => {
        Name => 'ColorSpecMethod',
        RawConv => '$$self{ColorSpecMethod} = $val',
        Protected => 1,
        Notes => q{
            default for writing is 2 when writing ICC_Profile, 1 when writing
            ColorSpace, or 4 when writing ColorSpecData
        },
        PrintConv => {
            1 => 'Enumerated',
            2 => 'Restricted ICC',
            3 => 'Any ICC',
            4 => 'Vendor Color',
        },
    },
    1 => {
        Name => 'ColorSpecPrecedence',
        Notes => 'default for writing is 0',
        Protected => 1,
    },
    2 => {
        Name => 'ColorSpecApproximation',
        Notes => 'default for writing is 0',
        Protected => 1,
        PrintConv => {
            0 => 'Not Specified',
            1 => 'Accurate',
            2 => 'Exceptional Quality',
            3 => 'Reasonable Quality',
            4 => 'Poor Quality',
        },
    },
    3 => [
        {
            Name => 'ICC_Profile',
            Condition => q{
                $$self{ColorSpecMethod} == 2 or
                $$self{ColorSpecMethod} == 3
            },
            Format => 'undef[$size-3]',
            SubDirectory => {
                TagTable => 'Image::ExifTool::ICC_Profile::Main',
            },
        },
        {
            Name => 'ColorSpace',
            Condition => '$$self{ColorSpecMethod} == 1',
            Format => 'int32u',
            Protected => 1,
            PrintConv => { # ref 15444-2 2002-05-15
                0 => 'Bi-level',
                1 => 'YCbCr(1)',
                3 => 'YCbCr(2)',
                4 => 'YCbCr(3)',
                9 => 'PhotoYCC',
                11 => 'CMY',
                12 => 'CMYK',
                13 => 'YCCK',
                14 => 'CIELab',
                15 => 'Bi-level(2)', # (incorrectly listed as 18 in 15444-2 2000-12-07)
                16 => 'sRGB',
                17 => 'Grayscale',
                18 => 'sYCC',
                19 => 'CIEJab',
                20 => 'e-sRGB',
                21 => 'ROMM-RGB',
                # incorrect in 15444-2 2000-12-07
                #22 => 'sRGB based YCbCr',
                #23 => 'YPbPr(1125/60)',
                #24 => 'YPbPr(1250/50)',
                22 => 'YPbPr(1125/60)',
                23 => 'YPbPr(1250/50)',
                24 => 'e-sYCC',
            },
        },
        {
            Name => 'ColorSpecData',
            Format => 'undef[$size-3]',
            Writable => 'undef',
            Protected => 1,
            Binary => 1,
        },
    ],
);

# JUMBF description box
%Image::ExifTool::Jpeg2000::JUMD = (
    PROCESS_PROC => \&ProcessJUMD,
    GROUPS => { 0 => 'JUMBF', 1 => 'JUMBF', 2 => 'Image' },
    NOTES => 'Information extracted from the JUMBF description box.',
    'type' => {
        Name => 'JUMDType',
        ValueConv => 'unpack "H*", $val',
        PrintConv => q{
            my @a = $val =~ /^(\w{8})(\w{4})(\w{4})(\w{16})$/;
            return $val unless @a;
            my $ascii = pack 'H*', $a[0];
            $a[0] = "($ascii)" if $ascii =~ /^[a-zA-Z0-9]{4}$/;
            return join '-', @a;
        },
        # seen:
        # cacb/cast/caas/cacl/casg/json-00110010800000aa00389b71
        # 6579d6fbdba2446bb2ac1b82feeb89d1 - JPEG image
    },
    'label' => { Name => 'JUMDLabel' },
    'toggles' => {
        Name => 'JUMDToggles',
        Unknown => 1,
        PrintConv => { BITMASK => {
            0 => 'Requestable',
            1 => 'Label',
            2 => 'ID',
            3 => 'Signature',
        }},
    },
    'id'    => { Name => 'JUMDID', Description => 'JUMD ID' },
    'sig'   => { Name => 'JUMDSignature', PrintConv => 'unpack "H*", $val' },
);

#------------------------------------------------------------------------------
# Read JUMBF box to keep track of sub-document numbers
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessJUMB($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    if ($$et{jumd_level}) {
        ++$$et{jumd_level}[-1]; # increment current sub-document number
    } else {
        $$et{jumd_level} = [ ++$$et{DOC_COUNT} ]; # new top-level sub-document
        $$et{SET_GROUP0} = 'JUMBF';
    }
    $$et{DOC_NUM} = join '-', @{$$et{jumd_level}};
    push @{$$et{jumd_level}}, 0;
    ProcessJpeg2000Box($et, $dirInfo, $tagTablePtr);
    delete $$et{DOC_NUM};
    delete $$et{JUMBFLabel};
    pop @{$$et{jumd_level}};
    if (@{$$et{jumd_level}} < 2) {
        delete $$et{jumd_level};
        delete $$et{SET_GROUP0};
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read JUMBF description box (ref https://github.com/thorfdbg/codestream-parser)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessJUMD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos    = $$dirInfo{DirStart};
    my $end    = $pos + $$dirInfo{DirLen};
    $et->VerboseDir('JUMD', 0, $end-$pos);
    delete $$et{JUMBFLabel};
    $$dirInfo{DirLen} < 17 and $et->Warn('Truncated JUMD directory'), return 0;
    my $type = substr($$dataPt, $pos, 4);
    $et->HandleTag($tagTablePtr, 'type', substr($$dataPt, $pos, 16));
    $pos += 16;
    my $flags = Get8u($dataPt, $pos++);
    $et->HandleTag($tagTablePtr, 'toggles', $flags);
    if ($flags & 0x02) {    # label exists?
        pos($$dataPt) = $pos;
        $$dataPt =~ /\0/g or $et->Warn('Missing JUMD label terminator'), return 0;
        my $len = pos($$dataPt) - $pos;
        my $name = substr($$dataPt, $pos, $len);
        $et->HandleTag($tagTablePtr, 'label', $name);
        $pos += $len;
        if ($len) {
            $name =~ s/[^-_a-zA-Z0-9]([a-z])/\U$1/g; # capitalize characters after illegal characters
            $name =~ tr/-_a-zA-Z0-9//dc;    # remove other illegal characters
            $name =~ s/__/_/;               # collapse double underlines
            $name = ucfirst $name;          # capitalize first letter
            $name = "Tag$name" if length($name) < 2; # must at least 2 characters long
            $$et{JUMBFLabel} = $name;
        }
    }
    if ($flags & 0x04) {    # ID exists?
        $pos + 4 > $end and $et->Warn('Missing JUMD ID'), return 0;
        $et->HandleTag($tagTablePtr, 'id', Get32u($dataPt, $pos));
        $pos += 4;
    }
    if ($flags & 0x08) {    # signature exists?
        $pos + 32 > $end and $et->Warn('Missing JUMD signature'), return 0;
        $et->HandleTag($tagTablePtr, 'sig', substr($$dataPt, $pos, 32));
        $pos += 32;
    }
    my $more = $end - $pos;
    if ($more) {
        # (may find c2sh box hiding after JUMD record)
        if ($more >= 8) {
            my %dirInfo = (
                DataPt   => $dataPt,
                DataLen  => $$dirInfo{DataLen},
                DirStart => $pos,
                DirLen   => $more,
                DirName  => 'JUMDPrivate',
            );
            $et->ProcessDirectory(\%dirInfo, GetTagTable('Image::ExifTool::Jpeg2000::Main'));
        } else {
            $et->Warn("Extra data in JUMD box $more bytes)", 1);
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Create new JPEG 2000 boxes when writing
# (Currently only supports adding top-level Writable JPEG2000 tags and certain UUID boxes)
# Inputs: 0) ExifTool object ref, 1) Output file or scalar ref
# Returns: 1 on success
sub CreateNewBoxes($$)
{
    my ($et, $outfile) = @_;
    my $addTags = $$et{AddJp2Tags};
    my $addDirs = $$et{AddJp2Dirs};
    delete $$et{AddJp2Tags};
    delete $$et{AddJp2Dirs};
    my ($tag, $dirName);
    # add JPEG2000 tags
    foreach $tag (sort keys %$addTags) {
        my $tagInfo = $$addTags{$tag};
        my $nvHash = $et->GetNewValueHash($tagInfo);
        # (native JPEG2000 information is always preferred, so don't check IsCreating)
        next unless $$tagInfo{List} or $et->IsOverwriting($nvHash) > 0;
        next if $$nvHash{EditOnly};
        my @vals = $et->GetNewValue($nvHash);
        my $val;
        foreach $val (@vals) {
            my $boxhdr = pack('N', length($val) + 8) . $$tagInfo{TagID};
            Write($outfile, $boxhdr, $val) or return 0;
            ++$$et{CHANGED};
            $et->VerboseValue("+ Jpeg2000:$$tagInfo{Name}", $val);
        }
    }
    # add UUID boxes (and/or JXL Exif/XML boxes)
    foreach $dirName (sort keys %$addDirs) {
        # handle JPEG XL XMP and EXIF
        if ($dirName eq 'xml ' or $dirName eq 'Exif') {
            my ($tag, $dir) = $dirName eq 'xml ' ? ('xml ', 'XMP') : ('Exif', 'EXIF');
            my $tagInfo = $Image::ExifTool::Jpeg2000::Main{$tag};
            $tagInfo = $$tagInfo[1] if ref $tagInfo eq 'ARRAY'; # (hack for stupid JXL XMP)
            my $subdir = $$tagInfo{SubDirectory};
            my $tagTable = GetTagTable($$subdir{TagTable});
            $tagTable = GetTagTable('Image::ExifTool::XMP::Main') if $dir eq 'XMP';
            my %dirInfo = (
                DirName => $dir,
                Parent => $tag,
            );
            my $compress = $et->Options('Compress');
            $dirInfo{Compact} = 1 if $$et{IsJXL} and $compress;
            my $newdir = $et->WriteDirectory(\%dirInfo, $tagTable, $$subdir{WriteProc});
            if (defined $newdir and length $newdir) {
                # not sure why, but EXIF box is padded with leading 0's in my sample
                my $pad = $dirName eq 'Exif' ? "\0\0\0\0" : '';
                if ($$et{IsJXL} and $compress) {
                    # create as Brotli-compressed metadata
                    if (eval { require IO::Compress::Brotli }) {
                        my $compressed;
                        eval { $compressed = IO::Compress::Brotli::bro($pad . $newdir) };
                        if ($@ or not $compressed) {
                            $et->Warn("Error encoding $dirName brob box");
                        } else {
                            $et->VPrint(0, "  Writing Brotli-compressed $dir\n");
                            $newdir = $compressed;
                            $pad = $tag;
                            $tag = 'brob';
                        }
                    } else {
                        $et->WarnOnce('Install IO::Compress::Brotli to create Brotli-compressed metadata');
                    }
                }
                my $boxhdr = pack('N', length($newdir) + length($pad) + 8) . $tag;
                Write($outfile, $boxhdr, $pad, $newdir) or return 0;
                next;
            }
        }
        next unless $uuid{$dirName};
        my $tagInfo;
        foreach $tagInfo (@{$Image::ExifTool::Jpeg2000::Main{uuid}}) {
            next unless $$tagInfo{Name} eq $dirName;
            my $subdir = $$tagInfo{SubDirectory};
            my $tagTable = GetTagTable($$subdir{TagTable});
            my %dirInfo = (
                DirName => $$subdir{DirName} || $dirName,
                Parent => 'JP2',
            );
            # remove "UUID-" from start of directory name to allow appropriate
            # directories to be written as a block
            $dirInfo{DirName} =~ s/^UUID-//;
            my $newdir = $et->WriteDirectory(\%dirInfo, $tagTable, $$subdir{WriteProc});
            if (defined $newdir and length $newdir) {
                my $boxhdr = pack('N', length($newdir) + 24) . 'uuid' . $uuid{$dirName};
                Write($outfile, $boxhdr, $newdir) or return 0;
                last;
            }
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Create Color Specification Box
# Inputs: 0) ExifTool object ref, 1) Output file or scalar ref
# Returns: 1 on success
sub CreateColorSpec($$)
{
    my ($et, $outfile) = @_;
    my $meth   = $et->GetNewValue('Jpeg2000:ColorSpecMethod');
    my $prec   = $et->GetNewValue('Jpeg2000:ColorSpecPrecedence') || 0;
    my $approx = $et->GetNewValue('Jpeg2000:ColorSpecApproximation') || 0;
    my $icc    = $et->GetNewValue('ICC_Profile');
    my $space  = $et->GetNewValue('Jpeg2000:ColorSpace');
    my $cdata  = $et->GetNewValue('Jpeg2000:ColorSpecData');
    unless ($meth) {
        if ($icc) {
            $meth = 2;
        } elsif (defined $space) {
            $meth = 1;
        } elsif (defined $cdata) {
            $meth = 4;
        } else {
            $et->Warn('Color space not defined'), return 0;
        }
    }
    if ($meth eq '1') {
        defined $space or $et->Warn('Must specify ColorSpace'), return 0;
        $cdata = pack('N', $space);
    } elsif ($meth eq '2' or $meth eq '3') {
        defined $icc or $et->Warn('Must specify ICC_Profile'), return 0;
        $cdata = $icc;
    } elsif ($meth eq '4') {
        defined $cdata or $et->Warn('Must specify ColorSpecData'), return 0;
    } else {
        $et->Warn('Unknown ColorSpecMethod'), return 0;
    }
    my $boxhdr = pack('N', length($cdata) + 11) . 'colr';
    Write($outfile, $boxhdr, pack('CCC',$meth,$prec,$approx), $cdata) or return 0;
    ++$$et{CHANGED};
    $et->VPrint(1, "    + Jpeg2000:ColorSpec\n");
    return 1;
}

#------------------------------------------------------------------------------
# Process JPEG 2000 box
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) Pointer to tag table
# Returns: 1 on success when reading, or -1 on write error
#          (or JP2 box or undef when writing from buffer)
sub ProcessJpeg2000Box($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = $$dirInfo{DataLen};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dirLen = $$dirInfo{DirLen} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $base = $$dirInfo{Base} || 0;
    my $outfile = $$dirInfo{OutFile};
    my $dirEnd = $dirStart + $dirLen;
    my ($err, $outBuff, $verbose, $doColour, $hash, $raf);

    # read from RAF unless reading from buffer
    $raf = $$dirInfo{RAF} unless $dataPt;

    if ($outfile) {
        unless ($raf) {
            # buffer output to be used for return value
            $outBuff = '';
            $outfile = \$outBuff;
        }
        # determine if we will be writing colr box
        if ($$dirInfo{DirName} and $$dirInfo{DirName} eq 'JP2Header') {
            $doColour = 2 if defined $et->GetNewValue('ColorSpecMethod') or $et->GetNewValue('ICC_Profile') or
                             defined $et->GetNewValue('ColorSpecPrecedence') or defined $et->GetNewValue('ColorSpace') or
                             defined $et->GetNewValue('ColorSpecApproximation') or defined $et->GetNewValue('ColorSpecData');
        }
    } else {
        # (must not set verbose flag when writing!)
        $verbose = $$et{OPTIONS}{Verbose};
        $et->VerboseDir($$dirInfo{DirName}) if $verbose;
        # do hash if requested, but only for top-level image data
        $hash = $$et{ImageDataHash} if $raf;
    }
    # loop through all contained boxes
    my ($pos, $boxLen, $lastBox);
    for ($pos=$dirStart; ; $pos+=$boxLen) {
        my ($boxID, $buff, $valuePtr);
        my $hdrLen = 8;     # the box header length
        if ($raf) {
            $dataPos = $raf->Tell() - $base;
            my $n = $raf->Read($buff,$hdrLen);
            unless ($n == $hdrLen) {
                $n and $err = '', last;
                CreateNewBoxes($et, $outfile) or $err = 1 if $outfile;
                last;
            }
            $dataPt = \$buff;
            $dirLen = $dirEnd = $hdrLen;
            $pos = 0;
        } elsif ($pos >= $dirEnd - $hdrLen) {
            $err = '' unless $pos == $dirEnd;
            last;
        }
        $boxLen = unpack("x$pos N",$$dataPt);   # (length includes header and data)
        $boxID = substr($$dataPt, $pos+4, 4);
        # (ftbl box contains flst boxes with absolute file offsets, not currently handled)
        if ($outfile and $boxID eq 'ftbl') {
            $et->Error("Can't yet handle fragmented JPX files");
            return -1;
        }
        # remove old colr boxes if necessary
        if ($doColour and $boxID eq 'colr') {
            if ($doColour == 1) { # did we successfully write the new colr box?
                $et->VPrint(1,"    - Jpeg2000:ColorSpec\n");
                ++$$et{CHANGED};
                next;
            }
            $et->Warn('Out-of-order colr box encountered');
            undef $doColour;
        }
        $lastBox = $boxID;
        $pos += $hdrLen;                # move to end of box header
        if ($boxLen == 1) {
            # box header contains an additional 8-byte integer for length
            $hdrLen += 8;
            if ($raf) {
                my $buf2;
                if ($raf->Read($buf2,8) == 8) {
                    $buff .= $buf2;
                    $dirLen = $dirEnd = $hdrLen;
                }
            }
            $pos > $dirEnd - 8 and $err = '', last;
            my ($hi, $lo) = unpack("x$pos N2",$$dataPt);
            $hi and $err = "Can't currently handle JPEG 2000 boxes > 4 GB", last;
            $pos += 8;                  # move to end of extended-length box header
            $boxLen = $lo - $hdrLen;    # length of remaining box data
        } elsif ($boxLen == 0) {
            if ($raf) {
                if ($outfile) {
                    CreateNewBoxes($et, $outfile) or $err = 1;
                    # copy over the rest of the file
                    Write($outfile, $$dataPt) or $err = 1;
                    while ($raf->Read($buff, 65536)) {
                        Write($outfile, $buff) or $err = 1;
                    }
                } else {
                    if ($verbose) {
                        my $msg = sprintf("offset 0x%.4x to end of file", $dataPos + $base + $pos);
                        $et->VPrint(0, "$$et{INDENT}- Tag '${boxID}' ($msg)\n");
                    }
                    if ($hash and $isImageData{$boxID}) {
                        $et->ImageDataHash($raf, undef, $boxID);
                    }
                }
                last;   # (ignore the rest of the file when reading)
            }
            $boxLen = $dirEnd - $pos;   # data runs to end of file
        } else {
            $boxLen -= $hdrLen;         # length of remaining box data
        }
        $boxLen < 0 and $err = 'Invalid JPEG 2000 box length', last;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $boxID);
        unless (defined $tagInfo or $verbose) {
            # no need to process this box
            if ($raf) {
                if ($outfile) {
                    Write($outfile, $$dataPt) or $err = 1;
                    $raf->Read($buff,$boxLen) == $boxLen or $err = '', last;
                    Write($outfile, $buff) or $err = 1;
                } elsif ($hash and $isImageData{$boxID}) {
                    $et->ImageDataHash($raf, $boxLen, $boxID);
                } else {
                    $raf->Seek($boxLen, 1) or $err = 'Seek error', last;
                }
            } elsif ($outfile) {
                Write($outfile, substr($$dataPt, $pos-$hdrLen, $boxLen+$hdrLen)) or $err = '', last;
            }
            next;
        }
        if ($raf) {
            # read the box data
            $dataPos = $raf->Tell() - $base;
            $raf->Read($buff,$boxLen) == $boxLen or $err = '', last;
            if ($hash and $isImageData{$boxID}) {
                $hash->add($buff);
                $et->VPrint(0, "$$et{INDENT}(ImageDataHash: $boxLen bytes of $boxID data)\n");
            }
            $valuePtr = 0;
            $dataLen = $boxLen;
        } elsif ($pos + $boxLen > $dirEnd) {
            $err = '';
            last;
        } else {
            $valuePtr = $pos;
        }
        if (defined $tagInfo and not $tagInfo) {
            # GetTagInfo() required the value for a Condition
            my $tmpVal = substr($$dataPt, $valuePtr, $boxLen < 128 ? $boxLen : 128);
            $tagInfo = $et->GetTagInfo($tagTablePtr, $boxID, \$tmpVal);
        }
        # delete all UUID boxes and any writable box if deleting all information
        if ($outfile and $tagInfo) {
            if ($boxID eq 'uuid' and $$et{DEL_GROUP}{'*'}) {
                $et->VPrint(0, "  Deleting $$tagInfo{Name}\n");
                ++$$et{CHANGED};
                next;
            } elsif ($$tagInfo{Writable}) {
                my $isOverwriting;
                if ($$et{DEL_GROUP}{Jpeg2000}) {
                    $isOverwriting = 1;
                } else {
                    my $nvHash = $et->GetNewValueHash($tagInfo);
                    $isOverwriting = $et->IsOverwriting($nvHash);
                }
                if ($isOverwriting) {
                    my $val = substr($$dataPt, $valuePtr, $boxLen);
                    $et->VerboseValue("- Jpeg2000:$$tagInfo{Name}", $val);
                    ++$$et{CHANGED};
                    next;
                } elsif (not $$tagInfo{List}) {
                    delete $$et{AddJp2Tags}{$boxID};
                }
            }
        }
        # create new tag for JUMBF data values with name corresponding to JUMBFLabel
        if ($tagInfo and $$et{JUMBFLabel} and (not $$tagInfo{SubDirectory} or $$tagInfo{BlockExtract})) {
            $tagInfo = { %$tagInfo, Name => $$et{JUMBFLabel} . ($$tagInfo{JUMBF_Suffix} || '') };
            delete $$tagInfo{Description};
            AddTagToTable($tagTablePtr, '_JUMBF_' . $$et{JUMBFLabel}, $tagInfo);
            delete $$tagInfo{Protected}; # (must do this so -j -b returns JUMBF binary data)
            $$tagInfo{TagID} = $boxID;
        }
        if ($verbose) {
            $et->VerboseInfo($boxID, $tagInfo,
                Table  => $tagTablePtr,
                DataPt => $dataPt,
                Size   => $boxLen,
                Start  => $valuePtr,
                Addr   => $valuePtr + $dataPos + $base,
            );
            next unless $tagInfo;
        }
        if ($$tagInfo{SubDirectory}) {
            my $subdir = $$tagInfo{SubDirectory};
            my $subdirStart = $valuePtr;
            my $subdirLen = $boxLen;
            if (defined $$subdir{Start}) {
                #### eval Start ($valuePtr, $dataPt)
                $subdirStart = eval($$subdir{Start});
                $subdirLen -= $subdirStart - $valuePtr;
                if ($subdirLen < 0) {
                    $subdirStart = $valuePtr;
                    $subdirLen = 0;
                }
            }
            my %subdirInfo = (
                Parent => 'JP2',
                DataPt => $dataPt,
                DataPos => -$subdirStart, # (relative to Base)
                DataLen => $dataLen,
                DirStart => $subdirStart,
                DirLen => $subdirLen,
                DirName => $$subdir{DirName} || $$tagInfo{Name},
                OutFile => $outfile,
                Base => $base + $dataPos + $subdirStart,
            );
            my $uuid = $uuid{$$tagInfo{Name}};
            # remove "UUID-" prefix to allow appropriate directories to be written as a block
            $subdirInfo{DirName} =~ s/^UUID-//;
            my $subTable = GetTagTable($$subdir{TagTable}) || $tagTablePtr;
            if ($outfile) {
                # (special case for brob box, which may be EXIF or XMP)
                my $fakeID = $boxID;
                if ($boxID eq 'brob') {
                    # I have seen 'brob' ID's with funny cases, so standardize these
                    $fakeID = 'xml ' if $$dataPt =~ /^xml /i;
                    $fakeID = 'Exif' if $$dataPt =~ /^Exif/i;
                }
                my $newdir;
                # only edit writable UUID, Exif and jp2h boxes
                if ($uuid or $fakeID eq 'Exif' or ($fakeID eq 'xml ' and $$et{IsJXL}) or
                    ($boxID eq 'jp2h' and $$et{EDIT_DIRS}{jp2h}))
                {
                    my $compress = $et->Options('Compress');
                    $subdirInfo{Parent} = $fakeID;
                    $subdirInfo{Compact} = 1 if $compress and $$et{IsJXL};
                    $newdir = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
                    next if defined $newdir and not length $newdir; # next if deleting the box
                    # compress JXL EXIF or XMP metadata if requested
                    if (defined $newdir and $$et{IsJXL} and defined $compress and
                        ($fakeID eq 'Exif' or $fakeID eq 'xml '))
                    {
                        if ($compress and $boxID ne 'brob') {
                            # rewrite as a Brotli-compressed 'brob' box
                            if (eval { require IO::Compress::Brotli }) {
                                my $pad = $boxID eq 'Exif' ? "\0\0\0\0" : '';
                                my $compressed;
                                eval { $compressed = IO::Compress::Brotli::bro($pad . $newdir) };
                                if ($@ or not $compressed) {
                                    $et->Warn("Error encoding $boxID brob box");
                                } else {
                                    $et->VPrint(0, "  Writing Brotli-compressed $boxID\n");
                                    $newdir = $boxID . $compressed;
                                    $boxID = 'brob';
                                    $subdirStart = $valuePtr = 0;
                                    ++$$et{CHANGED};
                                }
                            } else {
                                $et->WarnOnce('Install IO::Compress::Brotli to write Brotli-compressed metadata');
                            }
                        } elsif (not $compress and $boxID eq 'brob') {
                            # (in this case, ProcessBrotli has returned uncompressed data,
                            #  so change to the uncompressed 'xml ' or 'Exif' box type)
                            $et->VPrint(0, "  Writing uncompressed $fakeID\n");
                            $boxID = $fakeID;
                            $subdirStart = $valuePtr = 0;
                            ++$$et{CHANGED};
                        }
                    }
                } elsif (defined $uuid) {
                    $et->Warn("Not editing $$tagInfo{Name} box", 1);
                }
                # remove this directory from our create list
                delete $$et{AddJp2Dirs}{$fakeID};               # (eg. 'Exif' or 'xml ')
                if ($boxID eq 'brob') {
                    # (can't make tag Name 'XMP' or 'Exif' for Brotli-compressed tags because it
                    #  would break the logic in WriteDirectory(), so we do a lookup here instead)
                    delete $$et{AddJp2Dirs}{{'xml '=>'XMP','Exif'=>'EXIF'}->{$fakeID}};
                } else {
                    delete $$et{AddJp2Dirs}{$$tagInfo{Name}};   # (eg. 'EXIF' or 'XMP')
                }
                # use old box data if not changed
                defined $newdir or $newdir = substr($$dataPt, $subdirStart, $subdirLen);
                my $prefixLen = $subdirStart - $valuePtr;
                my $boxhdr = pack('N', length($newdir) + 8 + $prefixLen) . $boxID;
                $boxhdr .= substr($$dataPt, $valuePtr, $prefixLen) if $prefixLen;
                Write($outfile, $boxhdr, $newdir) or $err = 1;
                # write new colr box immediately after ihdr
                if ($doColour and $boxID eq 'ihdr') {
                    # (shouldn't be multiple ihdr boxes, but just in case, write only 1)
                    $doColour = $doColour==2 ? CreateColorSpec($et, $outfile) : 0;
                }
            } else {
                # extract as a block if specified
                $subdirInfo{BlockInfo} = $tagInfo if $$tagInfo{BlockExtract};
                $et->Warn("Reading non-standard $$tagInfo{Name} box") if defined $uuid and $uuid eq '0';
                unless ($et->ProcessDirectory(\%subdirInfo, $subTable, $$subdir{ProcessProc})) {
                    if ($subTable eq $tagTablePtr) {
                        $err = 'JPEG 2000 format error';
                        last;
                    }
                    $et->Warn("Unrecognized $$tagInfo{Name} box");
                }
            }
        } elsif ($$tagInfo{Format} and not $outfile) {
            # only save tag values if Format was specified
            my $rational;
            my $val = ReadValue($dataPt, $valuePtr, $$tagInfo{Format}, undef, $boxLen, \$rational);
            if (defined $val) {
                my $key = $et->FoundTag($tagInfo, $val);
                # save Rational value
                $$et{RATIONAL}{$key} = $rational if defined $rational and defined $key;
            }
        } elsif ($outfile) {
            my $boxhdr = pack('N', $boxLen + 8) . $boxID;
            Write($outfile, $boxhdr, substr($$dataPt, $valuePtr, $boxLen)) or $err = 1;
        }
    }
    if (defined $err) {
        $err or $err = 'Truncated JPEG 2000 box';
        if ($outfile) {
            $et->Error($err) unless $err eq '1';
            return $raf ? -1 : undef;
        }
        $et->Warn($err);
    }
    return $outBuff if $outfile and not $raf;
    return 1;
}

#------------------------------------------------------------------------------
# Return bits from a bitstream object
# Inputs: 0) array ref, 1) number of bits
# Returns: specified number of bits as an integer, and shifts input bitstream
sub GetBits($$)
{
    my ($a, $n) = @_;
    my $v = 0;
    my $bit = 1;
    my $i;
    while ($n--) {
        for ($i=0; $i<@$a; ++$i) {
            # consume bits LSB first
            my $set = $$a[$i] & 1;
            $$a[$i] >>= 1;
            if ($i) {
                $$a[$i-1] |= 0x80 if $set;
            } else {
                $v |= $bit if $set;
                $bit <<= 1;
            }
        }
    }
    return $v;
}

#------------------------------------------------------------------------------
# Read/write Brotli-encoded metadata
# Inputs: 0) ExifTool ref, 1) dirInfoRef, 2) tag table ref
# Returns: 1 on success when reading, or new data when writing (undef if unchanged)
# (ref https://libjxl.readthedocs.io/en/latest/api_decoder.html)
sub ProcessBrotli($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};

    return 0 unless length($$dataPt) > 4;

    my $isWriting = $$dirInfo{IsWriting};
    my $type = substr($$dataPt, 0, 4);
    $et->VerboseDir("Decrypted Brotli '${type}'") unless $isWriting;
    my %knownType = ( exif => 'Exif', 'xml ' => 'xml ', jumb => 'jumb' );
    my $stdType = $knownType{lc $type};
    unless ($stdType) {
        $et->Warn('Unknown Brotli box type', 1);
        return 1;
    }
    if ($type ne $stdType) {
        $et->Warn("Incorrect case for Brotli '${type}' data (should be '${stdType}')");
        $type = $stdType;
    }
    if (eval { require IO::Uncompress::Brotli }) {
        if ($isWriting and not eval { require IO::Compress::Brotli }) {
            $et->WarnOnce('Install IO::Compress::Brotli to write Brotli-compressed metadata');
            return undef;
        }
        my $compress = $et->Options('Compress');
        my $verbose = $isWriting ? 0 : $et->Options('Verbose');
        my $dat = substr($$dataPt, 4);
        eval { $dat = IO::Uncompress::Brotli::unbro($dat, 100000000) };
        $@ and $et->Warn("Error decoding $type brob box"), return 1;
        $verbose > 2 and $et->VerboseDump(\$dat, Prefix => $$et{INDENT} . '  ');
        my %dirInfo = ( DataPt => \$dat );
        if ($type eq 'xml ') {
            $dirInfo{DirName} = 'XMP'; # (necessary for block read/write)
            require Image::ExifTool::XMP;
            if ($isWriting) {
                $dirInfo{Compact} = 1 if $compress;  # (no need to add padding if writing compressed)
                $dat = $et->WriteDirectory(\%dirInfo, $tagTablePtr);
            } else {
                Image::ExifTool::XMP::ProcessXMP($et, \%dirInfo, $tagTablePtr);
            }
        } elsif ($type eq 'Exif') {
            $dirInfo{DirName} = 'EXIF'; # (necessary for block read/write)
            $dirInfo{DirStart} = 4 + (length($dat) > 4 ? unpack("N", $dat) : 0);
            if ($dirInfo{DirStart} > length $dat) {
                $et->Warn("Corrupted Brotli '${type}' data");
            } elsif ($isWriting) {
                $dat = $et->WriteDirectory(\%dirInfo, $tagTablePtr, \&Image::ExifTool::WriteTIFF);
                # add back header word
                $dat = "\0\0\0\0" . $dat if defined $dat and length $dat;
            } else {
                $et->ProcessTIFF(\%dirInfo, $tagTablePtr);
            }
        } elsif ($type eq 'jumb') {
            return undef if $isWriting; # (can't yet write JUMBF)
            Image::ExifTool::ProcessJUMB($et, \%dirInfo, $tagTablePtr); # (untested)
        }
        if ($isWriting) {
            return undef unless defined $dat;
            # rewrite as uncompressed if Compress option is set to 0 (or '')
            return $dat if defined $compress and not $compress;
            eval { $dat = IO::Compress::Brotli::bro($dat) };
            $@ and $et->Warn("Error encoding $type brob box"), return undef;
            $et->VPrint(0, "  Writing Brotli-compressed $type\n");
            return $type . $dat;
        }
    } else {
        $et->WarnOnce('Install IO::Uncompress::Brotli to decode Brotli-compressed metadata');
        return undef if $isWriting;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract parameters from JPEG XL codestream [unverified!]
# Inputs: 0) ExifTool ref, 1) codestream ref
# Returns: 1 on success
sub ProcessJXLCodestream($$)
{
    my ($et, $dataPt) = @_;

    return 0 unless $$dataPt =~ /^(\0\0\0\0)?\xff\x0a/; # validate codestream
    # ignore if already extracted (ie. subsequent jxlp boxes)
    return 0 if $$et{ProcessedJXLCodestream};
    $$et{ProcessedJXLCodestream} = 1;
    # work with first 64 bytes of codestream data
    # (and add padding if necessary to avoid unpacking past end of data)
    my $dat;
    if (length $$dataPt > 64) {
        $dat = substr($$dataPt, 0, 64);
    } elsif (length $$dataPt < 18) {
        $dat = $$dataPt . ("\0" x 18); # (so we'll have a minimum 14 bytes to work with)
    } else {
        $dat = $$dataPt;
    }
    $dat =~ s/^\0\0\0\0//;  # remove jxlp header word
    my @a = unpack 'x2C12', $dat;
    my ($x, $y);
    my $small = GetBits(\@a, 1);
    if ($small) {
        $y = (GetBits(\@a, 5) + 1) * 8;
    } else {
        $y = GetBits(\@a, [9, 13, 18, 30]->[GetBits(\@a, 2)]) + 1;
    }
    my $ratio = GetBits(\@a, 3);
    if ($ratio == 0) {
        if ($small) {
            $x = (GetBits(\@a, 5) + 1) * 8;;
        } else {
            $x = GetBits(\@a, [9, 13, 18, 30]->[GetBits(\@a, 2)]) + 1;
        }
    } else {
        my $r = [[1,1],[12,10],[4,3],[3,2],[16,9],[5,4],[2,1]]->[$ratio-1];
        $x = int($y * $$r[0] / $$r[1]);
    }
    $et->FoundTag(ImageWidth => $x);
    $et->FoundTag(ImageHeight => $y);
    return 1;
}

#------------------------------------------------------------------------------
# Read/write meta information from a JPEG 2000 image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG 2000 file, or -1 on write error
sub ProcessJP2($$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my $hdr;

    # check to be sure this is a valid JPG2000 file
    return 0 unless $raf->Read($hdr,12) == 12;
    unless ($hdr eq "\0\0\0\x0cjP  \x0d\x0a\x87\x0a" or     # (ref 1)
            $hdr eq "\0\0\0\x0cjP\x1a\x1a\x0d\x0a\x87\x0a" or # (ref 2)
            $$et{IsJXL})
    {
        return 0 unless $hdr =~ /^\xff\x4f\xff\x51\0/;  # check for JP2 codestream format
        if ($outfile) {
            $et->Error('Writing of J2C files is not yet supported');
            return 0
        }
        # add J2C markers if not done already
        unless ($Image::ExifTool::jpegMarker{0x4f}) {
            $Image::ExifTool::jpegMarker{$_} = $j2cMarker{$_} foreach keys %j2cMarker;
        }
        $et->SetFileType('J2C');
        $raf->Seek(0,0);
        return $et->ProcessJPEG($dirInfo);    # decode with JPEG processor
    }
    if ($outfile) {
        Write($outfile, $hdr) or return -1;
        if ($$et{IsJXL}) {
            $et->InitWriteDirs(\%jxlMap);
            $$et{AddJp2Tags} = { }; # (don't add JP2 tags in JXL files)
        } else {
            $et->InitWriteDirs(\%jp2Map);
            $$et{AddJp2Tags} = $et->GetNewTagInfoHash(\%Image::ExifTool::Jpeg2000::Main);
        }
        # save list of directories to create
        my %addDirs = %{$$et{ADD_DIRS}}; # (make a copy)
        $$et{AddJp2Dirs} = \%addDirs;
    } else {
        my ($buff, $fileType);
        # recognize JPX and JPM as unique types of JP2
        if ($raf->Read($buff, 12) == 12 and $buff =~ /^.{4}ftyp(.{4})/s) {
            $fileType = 'JPX' if $1 eq 'jpx ';
            $fileType = 'JPM' if $1 eq 'jpm ';
            $fileType = 'JXL' if $1 eq 'jxl ';
            $fileType = 'JPH' if $1 eq 'jph ';
        }
        $raf->Seek(-length($buff), 1) if defined $buff;
        $et->SetFileType($fileType);
    }
    SetByteOrder('MM'); # JPEG 2000 files are big-endian
    my %dirInfo = (
        RAF => $raf,
        DirName => 'JP2',
        OutFile => $$dirInfo{OutFile},
    );
    my $tagTablePtr = GetTagTable('Image::ExifTool::Jpeg2000::Main');
    return $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Read/write meta information in a JPEG XL image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG XL file, -1 on write error
sub ProcessJXL($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my ($hdr, $buff);

    return 0 unless $raf->Read($hdr,12) == 12;
    if ($hdr eq "\0\0\0\x0cJXL \x0d\x0a\x87\x0a") {
        # JPEG XL in ISO BMFF container
        $$et{IsJXL} = 1;
    } elsif ($hdr =~ /^\xff\x0a/) {
        # JPEG XL codestream
        if ($outfile) {
            if ($$et{OPTIONS}{IgnoreMinorErrors}) {
                $et->Warn('Wrapped JXL codestream in ISO BMFF container');
            } else {
                $et->Error('Will wrap JXL codestream in ISO BMFF container for writing',1);
                return 0;
            }
            $$et{IsJXL} = 2;
            my $buff = "\0\0\0\x0cJXL \x0d\x0a\x87\x0a\0\0\0\x14ftypjxl \0\0\0\0jxl ";
            # add metadata to empty ISO BMFF container
            $$dirInfo{RAF} = new File::RandomAccess(\$buff);
        } else {
            $et->SetFileType('JXL Codestream','image/jxl', 'jxl');
            if ($$et{ImageDataHash} and $raf->Seek(0,0)) {
                $et->ImageDataHash($raf, undef, 'JXL');
            }
            return ProcessJXLCodestream($et, \$hdr);
        }
    } else {
        return 0;
    }
    $raf->Seek(0,0) or $et->Error('Seek error'), return 0;

    my $success = ProcessJP2($et, $dirInfo);

    if ($outfile and $success > 0 and $$et{IsJXL} == 2) {
        # attach the JXL codestream box to the ISO BMFF file
        $raf->Seek(0,2) or return -1;
        my $size = $raf->Tell();
        $raf->Seek(0,0) or return -1;
        SetByteOrder('MM');
        Write($outfile, Set32u($size + 8), 'jxlc') or return -1;
        while ($raf->Read($buff, 65536)) {
            Write($outfile, $buff) or return -1;
        }
    }
    return $success;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Jpeg2000 - Read JPEG 2000 meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read JPEG 2000
files.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.jpeg.org/public/fcd15444-2.pdf>

=item L<ftp://ftp.remotesensing.org/jpeg2000/fcd15444-1.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Jpeg2000 Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

