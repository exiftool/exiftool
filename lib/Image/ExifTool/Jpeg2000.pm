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

$VERSION = '1.26';

sub ProcessJpeg2000Box($$$);

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

# map of where information is written in JPEG2000 image
my %jp2Map = (
    IPTC         => 'UUID-IPTC',
    IFD0         => 'UUID-EXIF',
    XMP          => 'UUID-XMP',
   'UUID-IPTC'   => 'JP2',
   'UUID-EXIF'   => 'JP2',
   'UUID-XMP'    => 'JP2',
  # jp2h         => 'JP2',  (not yet functional)
  # ICC_Profile  => 'jp2h', (not yet functional)
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
    0x51 => 'SIZ', # image and tile size
    0x52 => 'COD', # coding style default
    0x53 => 'COC', # coding style component
    0x55 => 'TLM', # tile-part lengths
    0x57 => 'PLM', # packet length, main header
    0x58 => 'PLT', # packet length, tile-part header
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
        The tags below are extracted from JPEG 2000 images, however ExifTool
        currently writes only EXIF, IPTC and XMP tags in these images.
    },
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
    asoc => 'Association',
    nlst => 'NumberList',
    bfil => 'BinaryFilter',
    drep => 'DesiredReproductions',
        # DesiredReproductions sub boxes...
        gtso => 'GraphicsTechnologyStandardOutput',
    chck => 'DigitalSignature',
    mp7b => 'MPEG7Binary',
    free => 'Free',
    jp2c => 'ContiguousCodestream',
    jp2i => {
        Name => 'IntellectualProperty',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
   'xml '=> {
        Name => 'XML',
        Writable => 'undef',
        Flags => [ 'Binary', 'Protected', 'BlockExtract' ],
        List => 1,
        Notes => q{
            by default, the XML data in this tag is parsed using the ExifTool XMP module
            to to allow individual tags to be accessed when reading, but it may also be
            extracted as a block via the "XML" tag, which is also how this tag is
            written and copied.  This is a List-type tag because multiple XML blocks may
            exist
        },
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
    uuid => [
        {
            Name => 'UUID-EXIF',
            # (this is the EXIF that we create)
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
            # (this is the IPTC that we create)
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
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int8s',
    0 => {
        Name => 'ColorSpecMethod',
        RawConv => '$$self{ColorSpecMethod} = $val',
        PrintConv => {
            1 => 'Enumerated',
            2 => 'Restricted ICC',
            3 => 'Any ICC',
            4 => 'Vendor Color',
        },
    },
    1 => 'ColorSpecPrecedence',
    2 => {
        Name => 'ColorSpecApproximation',
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
            Binary => 1,
        },
    ],
);

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
    # add UUID boxes
    foreach $dirName (sort keys %$addDirs) {
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
# Process JPEG 2000 box
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) Pointer to tag table
# Returns: 1 on success when reading, or -1 on write error
#          (or JP2 box or undef when writing from buffer)
sub ProcessJpeg2000Box($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = $$dirInfo{DataLen};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen = $$dirInfo{DirLen} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $base = $$dirInfo{Base} || 0;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my $dirEnd = $dirStart + $dirLen;
    my ($err, $outBuff, $verbose);

    if ($outfile) {
        unless ($raf) {
            # buffer output to be used for return value
            $outBuff = '';
            $outfile = \$outBuff;
        }
    } else {
        # (must not set verbose flag when writing!)
        $verbose = $$et{OPTIONS}{Verbose};
        $et->VerboseDir($$dirInfo{DirName}) if $verbose;
    }
    # loop through all contained boxes
    my ($pos, $boxLen);
    for ($pos=$dirStart; ; $pos+=$boxLen) {
        my ($boxID, $buff, $valuePtr);
        my $hdrLen = 8;     # the box header length
        if ($raf) {
            $dataPos = $raf->Tell() - $base;
            my $n = $raf->Read($buff,$hdrLen);
            unless ($n == $hdrLen) {
                $n and $err = '', last;
                if ($outfile) {
                    CreateNewBoxes($et, $outfile) or $err = 1;
                }
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
                } elsif ($verbose) {
                    my $msg = sprintf("offset 0x%.4x to end of file", $dataPos + $base + $pos);
                    $et->VPrint(0, "$$et{INDENT}- Tag '${boxID}' ($msg)\n");
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
            if (defined $$subdir{Start}) {
                #### eval Start ($valuePtr)
                $subdirStart = eval($$subdir{Start});
            }
            my $subdirLen = $boxLen - ($subdirStart - $valuePtr);
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
                # remove this directory from our create list
                delete $$et{AddJp2Dirs}{$$tagInfo{Name}};
                my $newdir;
                # only edit writable UUID boxes
                if ($uuid) {
                    $newdir = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
                    next if defined $newdir and not length $newdir; # next if deleting the box
                } elsif (defined $uuid) {
                    $et->Warn("Not editing $$tagInfo{Name} box", 1);
                }
                # use old box data if not changed
                defined $newdir or $newdir = substr($$dataPt, $subdirStart, $subdirLen);
                my $prefixLen = $subdirStart - $valuePtr;
                my $boxhdr = pack('N', length($newdir) + 8 + $prefixLen) . $boxID;
                $boxhdr .= substr($$dataPt, $valuePtr, $prefixLen) if $prefixLen;
                Write($outfile, $boxhdr, $newdir) or $err = 1;
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
    unless ($hdr eq "\x00\x00\x00\x0cjP  \x0d\x0a\x87\x0a" or     # (ref 1)
            $hdr eq "\x00\x00\x00\x0cjP\x1a\x1a\x0d\x0a\x87\x0a") # (ref 2)
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
        $et->InitWriteDirs(\%jp2Map);
        # save list of directories to create
        my %addDirs = %{$$et{ADD_DIRS}};
        $$et{AddJp2Dirs} = \%addDirs;
        $$et{AddJp2Tags} = $et->GetNewTagInfoHash(\%Image::ExifTool::Jpeg2000::Main);
    } else {
        my ($buff, $fileType);
        # recognize JPX and JPM as unique types of JP2
        if ($raf->Read($buff, 12) == 12 and $buff =~ /^.{4}ftyp(.{4})/s) {
            $fileType = 'JPX' if $1 eq 'jpx ';
            $fileType = 'JPM' if $1 eq 'jpm ';
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

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

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

