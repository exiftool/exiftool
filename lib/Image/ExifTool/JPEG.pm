#------------------------------------------------------------------------------
# File:         JPEG.pm
#
# Description:  Definitions for uncommon JPEG segments
#
# Revisions:    10/06/2006 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::JPEG;
use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.39';

sub ProcessOcad($$$);
sub ProcessJPEG_HDR($$$);

# (most of the tags in this table are for documentation purposes only)
%Image::ExifTool::JPEG::Main = (
    NOTES => q{
        This table lists information extracted by ExifTool from JPEG images. See
        L<https://www.w3.org/Graphics/JPEG/jfif3.pdf> for the JPEG specification.
    },
    APP0 => [{
        Name => 'JFIF',
        Condition => '$$valPt =~ /^JFIF\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::JFIF::Main' },
      }, {
        Name => 'JFXX',
        Condition => '$$valPt =~ /^JFXX\0\x10/',
        SubDirectory => { TagTable => 'Image::ExifTool::JFIF::Extension' },
      }, {
        Name => 'CIFF',
        Condition => '$$valPt =~ /^(II|MM).{4}HEAPJPGM/s',
        SubDirectory => { TagTable => 'Image::ExifTool::CanonRaw::Main' },
      }, {
        Name => 'AVI1',
        Condition => '$$valPt =~ /^AVI1/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::AVI1' },
      }, {
        Name => 'Ocad',
        Condition => '$$valPt =~ /^Ocad/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::Ocad' },
    }],
    APP1 => [{
        Name => 'EXIF',
        Condition => '$$valPt =~ /^Exif\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Exif::Main' },
      }, {
        Name => 'ExtendedXMP',
        Condition => '$$valPt =~ m{^http://ns.adobe.com/xmp/extension/\0}',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
      }, {
        Name => 'XMP',
        Condition => '$$valPt =~ /^http/ or $$valPt =~ /<exif:/',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
      }, {
        Name => 'QVCI',
        Condition => '$$valPt =~ /^QVCI\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Casio::QVCI' },
      }, {
        Name => 'FLIR',
        Condition => '$$valPt =~ /^FLIR\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::FFF' },
      }, {
        Name => 'RawThermalImage', # (from Parrot Bebop-Pro Thermal drone)
        Condition => '$$valPt =~ /^PARROT\0(II\x2a\0|MM\0\x2a)/',
        Groups => { 0 => 'APP1', 1 => 'Parrot', 2 => 'Preview' },
        Notes => 'thermal image from Parrot Bebop-Pro Thermal drone',
        RawConv => 'substr($val, 7)',
        Binary => 1,
    }],
    APP2 => [{
        Name => 'ICC_Profile',
        Condition => '$$valPt =~ /^ICC_PROFILE\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
      }, {
        Name => 'FPXR',
        Condition => '$$valPt =~ /^FPXR\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::FlashPix::Main' },
      }, {
        Name => 'MPF',
        Condition => '$$valPt =~ /^MPF\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::MPF::Main' },
      }, {
        Name => 'InfiRayVersion',
        Condition => '$$valPt =~ /^....IJPEG\0/s',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::Version' },
      }, {
        Name => 'UniformResourceName',
        Groups => { 1 => 'APP2' },
        Condition => '$$valPt =~ /^urn:/',
        Notes => 'used in Apple HDR images',
      }, {
        Name => 'PreviewImage',
        Condition => '$$valPt =~ /^(|QVGA\0|BGTH)\xff\xd8\xff\xdb/',
        Notes => 'Samsung APP2 preview image', # (Samsung/GoPro="", BenQ="QVGA\0", Digilife="BGTH")
    }],
    APP3 => [{
        Name => 'Meta',
        Condition => '$$valPt =~ /^(Meta|META|Exif)\0\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Kodak::Meta' },
      }, {
        Name => 'Stim',
        Condition => '$$valPt =~ /^Stim\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Stim::Main' },
      }, {
        Name => 'JPS',
        Condition => '$$valPt =~ /^_JPSJPS_/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::JPS' },
      }, {
        Name => 'ThermalData', # (written by DJI FLIR models)
        Condition => '$$self{Make} eq "DJI"',
        Notes => 'DJI raw thermal data',
        Groups => { 0 => 'APP3', 1 => 'DJI', 2 => 'Image' },
        Binary => 1,
      }, {
        Name => 'ImagingData', # (written by InfiRay models)
        Condition => '$$self{HasIJPEG}',
        Notes => 'InfiRay IR+thermal+visible data',
        Groups => { 0 => 'APP3', 1 => 'InfiRay', 2 => 'Image' },
        Binary => 1,
      }, {
        Name => 'PreviewImage', # (written by HP R837 and Samsung S1060)
        Condition => '$$valPt =~ /^\xff\xd8\xff\xdb/',
        Notes => 'Samsung/HP preview image', # (Samsung, HP, BenQ)
    }],
    APP4 => [{
        Name => 'Scalado',
        Condition => '$$valPt =~ /^SCALADO\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Scalado::Main' },
      }, {
        Name => 'FPXR', # (non-standard location written by some HP models)
        Condition => '$$valPt =~ /^FPXR\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::FlashPix::Main' },
      }, {
        Name => 'QualcommDualCamera',
        Condition => '$$valPt =~ /^Qualcomm Dual Camera Attributes/',
        SubDirectory => { TagTable => 'Image::ExifTool::Qualcomm::DualCamera' },
      }, {
        Name => 'InfiRayFactory',
        Condition => '$$self{HasIJPEG}"',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::Factory' },
      }, {
        Name => 'ThermalParams', # (written by some DJI FLIR models)
        Condition => '$$self{Make} eq "DJI" and $$valPt =~ /^\xaa\x55\x12\x06/',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::ThermalParams' },
      }, {
        Name => 'ThermalParams2', # (written by M3T)
        Condition => '$$self{Make} eq "DJI" and $$valPt =~ /^(.{32})?.{32}\x2c\x01\x20\0/s',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::ThermalParams2' },
      }, {
        Name => 'ThermalParams3', # (written by M30T)
        Condition => '$$self{Make} eq "DJI" and $$valPt =~ /^.{32}\xaa\x55\x38\0/s',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::ThermalParams3' },
      }, {
        Name => 'PreviewImage', # (eg. Samsung S1060)
        Notes => 'continued from APP3',
    }],
    APP5 => [{
        Name => 'RMETA',
        Condition => '$$valPt =~ /^RMETA\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::RMETA' },
      }, {
        Name => 'SamsungUniqueID',
        Condition => '$$valPt =~ /ssuniqueid\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::APP5' },
      }, {
        Name => 'InfiRayPicture',
        Condition => '$$self{HasIJPEG}',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::Picture' },
      }, {
        Name => 'ThermalCalibration', # (written by DJI FLIR models)
        Condition => '$$self{Make} eq "DJI"',
        Notes => 'DJI thermal calibration data',
        Groups => { 0 => 'APP5', 1 => 'DJI', 2 => 'Image' },
        Binary => 1,
      }, {
        Name => 'PreviewImage', # (eg. BenQ DC E1050)
        Notes => 'continued from APP4',
    }],
    APP6 => [{
        Name => 'EPPIM',
        Condition => '$$valPt =~ /^EPPIM\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::EPPIM' },
      }, {
        Name => 'NITF',
        Condition => '$$valPt =~ /^NTIF\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::NITF' },
      }, {
        Name => 'HP_TDHD', # (written by R837)
        Condition => '$$valPt =~ /^TDHD\x01\0\0\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::HP::TDHD' },
      }, {
        Name => 'GoPro',
        Condition => '$$valPt =~ /^GoPro\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
      }, {
        Name => 'InfiRayMixMode',
        Condition => '$$self{HasIJPEG}',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::MixMode' },
      }, {
        Name => 'DJI_DTAT', # (written by ZH20T)
        Condition => '$$valPt =~ /^DTAT\0\0.\{/s',
        Groups => { 0 => 'APP6', 1 => 'DJI' },
        Notes => 'DJI Thermal Analysis Tool record',
        ValueConv => 'substr($val,7)',
      # also seen Motorola APP6 "MMIMETA\0", with sub-types: AL3A,ALED,MMI0,MOTD,QC3A,LMB1
    }],
    APP7 => [{
        Name => 'Pentax',
        Condition => '$$valPt =~ /^PENTAX \0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::Main' },
      }, {
        Name => 'Huawei',
        Condition => '$$valPt =~ /^HUAWEI\0\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::Unknown::Main' },
      }, {
        Name => 'Qualcomm',
        Condition => '$$valPt =~ /^\x1aQualcomm Camera Attributes/',
        SubDirectory => { TagTable => 'Image::ExifTool::Qualcomm::Main' },
      }, {
        Name => 'InfiRayOpMode',
        Condition => '$$self{HasIJPEG}',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::OpMode' },
      }, {
        Name => 'DJI-DBG',
        Condition => '$$valPt =~ /^DJI-DBG\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::Info' },
    }],
    APP8 => [{
        Name => 'SPIFF',
        Condition => '$$valPt =~ /^SPIFF\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::SPIFF' },
      }, {
        Name => 'InfiRayIsothermal',
        Condition => '$$self{HasIJPEG}',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::Isothermal' },
      }, {
        Name => 'SEAL',
        Condition => '$$valPt =~ /^SEAL\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::SEAL' },
    }],
    APP9 => [{
        Name => 'MediaJukebox',
        Condition => '$$valPt =~ /^Media Jukebox\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::MediaJukebox' },
      }, {
        Name => 'InfiRaySensor',
        Condition => '$$self{HasIJPEG}',
        SubDirectory => { TagTable => 'Image::ExifTool::InfiRay::Sensor' },
      }, {
        Name => 'SEAL',
        Condition => '$$valPt =~ /^SEAL\0/',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::SEAL' },
    }],
    APP10 => [{
        Name => 'Comment',
        Condition => '$$valPt =~ /^UNICODE\0/',
        Notes => 'PhotoStudio Unicode comment',
      }, {
        Name => 'HDRGainInfo', #PH (NC)
        Condition => '$$valPt =~ /^AROT\0\0.{4}/s',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::HDRGainInfo' },
    }],
    APP11 => [{
        Name => 'JPEG-HDR',
        Condition => '$$valPt =~ /^HDR_RI /',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::HDR' },
      }, {
        Name => 'JUMBF',
        Condition => '$$valPt =~ /^JP/',
        SubDirectory => { TagTable => 'Image::ExifTool::Jpeg2000::Main' },
        # Note: The suggested options for reading C2PA CAI JUMBF metadata are "-G3 -b -j -u"
    }],
    APP12 => [{
        Name => 'PictureInfo',
        Condition => '$$valPt =~ /(\[picture info\]|Type=)/',
        SubDirectory => { TagTable => 'Image::ExifTool::APP12::PictureInfo' },
      }, {
        Name => 'Ducky',
        Condition => '$$valPt =~ /^Ducky/',
        SubDirectory => { TagTable => 'Image::ExifTool::APP12::Ducky' },
    }],
    APP13 => [{
        Name => 'Photoshop',
        Condition => '$$valPt =~ /^(Photoshop 3.0\0|Adobe_Photoshop2.5)/',
        SubDirectory => { TagTable => 'Image::ExifTool::Photoshop::Main' },
    }, {
        Name => 'Adobe_CM',
        Condition => '$$valPt =~ /^Adobe_CM/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::AdobeCM' },
    }],
    APP14 => {
        Name => 'Adobe',
        Condition => '$$valPt =~ /^Adobe/',
        Writable => 2,  # (for docs only)
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::Adobe' },
    },
    APP15 => {
        Name => 'GraphicConverter',
        Condition => '$$valPt =~ /^Q\s*(\d+)/',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::GraphConv' },
    },
    # APP15 - Also unknown "TEXT\0" segment stored by Casio/FujiFilm
    COM => {
        Name => 'Comment',
        # note: flag as writable for documentation, but it won't show up
        # in the TagLookup as writable because there is no WRITE_PROC
        Writable => 2,
    },
    SOF => {
        Name => 'StartOfFrame',
        SubDirectory => { TagTable => 'Image::ExifTool::JPEG::SOF' },
    },
    DQT => {
        Name => 'DefineQuantizationTable',
        Notes => 'used to calculate the Extra JPEGDigest tag value',
    },
    Trailer => [{
        Name => 'AFCP',
        Condition => '$$valPt =~ /AXS(!|\*).{8}$/s',
        SubDirectory => { TagTable => 'Image::ExifTool::AFCP::Main' },
      }, {
        Name => 'CanonVRD',
        Condition => '$$valPt =~ /CANON OPTIONAL DATA\0.{44}$/s',
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::Main' },
      }, {
        Name => 'FotoStation',
        Condition => '$$valPt =~ /\xa1\xb2\xc3\xd4$/',
        SubDirectory => { TagTable => 'Image::ExifTool::FotoStation::Main' },
      }, {
        Name => 'PhotoMechanic',
        Condition => '$$valPt =~ /cbipcbbl$/',
        SubDirectory => { TagTable => 'Image::ExifTool::PhotoMechanic::Main' },
      }, {
        Name => 'MIE',
        Condition => q{
            $$valPt =~ /~\0\x04\0zmie~\0\0\x06.{4}[\x10\x18]\x04$/s or
            $$valPt =~ /~\0\x04\0zmie~\0\0\x0a.{8}[\x10\x18]\x08$/s
        },
        SubDirectory => { TagTable => 'Image::ExifTool::MIE::Main' },
      }, {
        Name => 'MPF',
        SubDirectory => { TagTable => 'Image::ExifTool::MPF::Main' },
      }, {
        Name => 'Samsung',
        Condition => '$$valPt =~ /QDIOBS$/',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::Trailer' },
      }, {
        Name => 'Vivo',
        Condition => '$$valPt =~ /^(streamdata|vivo\{")/',
        SubDirectory => { TagTable => 'Image::ExifTool::Trailer::Vivo' },
      }, {
        Name => 'OnePlus',
        SubDirectory => { TagTable => 'Image::ExifTool::Trailer::OnePlus' },
      }, {
        Name => 'Google',
        SubDirectory => { TagTable => 'Image::ExifTool::Trailer::Google' },
      }, {
        Name => 'EmbeddedVideo',
        Notes => 'extracted only when ExtractEmbedded option is used',
        Condition => '$$valPt =~ /^.{4}ftyp/s',
      }, {
        Name => 'Insta360',
        Condition => '$$valPt =~ /8db42d694ccc418790edff439fe026bf$/',
      }, {
        Name => 'NikonApp',
        Condition => '$$valPt =~ m(\0{6}/NIKON APP$)',
        Notes => 'contains editing information in XMP format',
      }, {
        Name => 'SonyHiddenData',
        Condition => '$$valPt =~ /^\x55\x26\x11\x05\0/',
      }, {
        Name => 'PreviewImage',
        Condition => '$$valPt =~ /^\xff\xd8\xff/',
        Writable => 2,  # (for docs only)
    }],
);

# HDR gain information (ref PH)
%Image::ExifTool::JPEG::HDRGainInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP10', 1 => 'AROT', 2 => 'Image' },
    6 => {
        Name => 'HDRGainCurveSize',
        Format => 'int32u',
    },
    10 => {
        Name => 'HDRGainCurve', # (NC)
        Format => 'int32uRev[$val{6}]',
        Binary => 1,
    },
);

# JPS APP3 segment (ref http://paulbourke.net/stereographics/stereoimage/)
%Image::ExifTool::JPEG::JPS = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP3', 1 => 'JPS', 2 => 'Image' },
    NOTES => 'Tags found in JPEG Stereo (JPS) images.',
    0x0a => {
        Name => 'JPSSeparation',
        Format => 'int32u', # (just so we can look ahead to MediaType);
        Notes => 'stereo only',
        RawConv => q{
            $$self{MediaType} = $val & 0xff;
            return undef unless $$self{MediaType} == 1;
            return(($val >> 24) & 0xff);
        },
    },
    0x08 => {
        Name => 'HdrLength',
        Format => 'int16u',
        Hidden => 1,
        RawConv => '$$self{HdrLength} = $val; undef',
    },
    0x0b => {
        Name => 'JPSFlags',
        PrintConv => { BITMASK => {
            0 => 'Half height',
            1 => 'Half width',
            2 => 'Left field first',
        }},
    },
    0x0c => [{
        Name => 'JPSLayout',
        Condition => '$$self{MediaType} == 0',
        Notes => 'mono',
        PrintConv => {
            0 => 'Both Eyes',
            1 => 'Left Eye',
            2 => 'Right Eye',
        },
    },{
        Name => 'JPSLayout',
        Condition => '$$self{MediaType} == 1',
        Notes => 'stereo',
        PrintConv => {
            1 => 'Interleaved',
            2 => 'Side By Side',
            3 => 'Over Under',
            4 => 'Anaglyph',
        },
    }],
    0x0d => {
        Name => 'JPSType',
        Hook => '$varSize += $$self{HdrLength} - 4', # comment starts after header block
        PrintConv => { 0 => 'Mono', 1 => 'Stereo' },
    },
    # 0x0e - in16u comment length (ignored -- assume the remainder is all comment)
    #        (this is offset if we had a 4-byte JPS header block)
    0x10 => {
        Name => 'JPSComment',
        Format => 'string',
    },
);

# EPPIM APP6 (Toshiba PrintIM) segment (ref PH, from PDR-M700 samples)
%Image::ExifTool::JPEG::EPPIM = (
    GROUPS => { 0 => 'APP6', 1 => 'EPPIM', 2 => 'Image' },
    NOTES => q{
        APP6 is used in by the Toshiba PDR-M700 to store a TIFF structure containing
        PrintIM information.
    },
    0xc4a5 => {
        Name => 'PrintIM',
        # must set Writable here so this tag will be saved with MakerNotes option
        # (but it isn't actually writable because there is no WRITE_PROC)
        Writable => 'undef',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);

# APP8 SPIFF segment.  Refs:
# 1) http://www.fileformat.info/format/spiff/
# 2) http://www.jpeg.org/public/spiff.pdf
%Image::ExifTool::JPEG::SPIFF = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP8', 1 => 'SPIFF', 2 => 'Image' },
    NOTES => q{
        This information is found in APP8 of SPIFF-style JPEG images (the "official"
        yet rarely used JPEG file format standard: Still Picture Interchange File
        Format).  See L<http://www.jpeg.org/public/spiff.pdf> for the official
        specification.
    },
    0 => {
        Name => 'SPIFFVersion',
        Format => 'int8u[2]',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    2 => {
        Name => 'ProfileID',
        PrintConv => {
            0 => 'Not Specified',
            1 => 'Continuous-tone Base',
            2 => 'Continuous-tone Progressive',
            3 => 'Bi-level Facsimile',
            4 => 'Continuous-tone Facsimile',
        },
    },
    3 => 'ColorComponents',
    6 => {
        Name => 'ImageHeight',
        Notes => q{
            at index 4 in specification, but there are 2 extra bytes here in my only
            SPIFF sample, version 1.2
        },
        Format => 'int32u',
    },
    10 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    14 => {
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'Bi-level',
            1 => 'YCbCr, ITU-R BT 709, video',
            2 => 'No color space specified',
            3 => 'YCbCr, ITU-R BT 601-1, RGB',
            4 => 'YCbCr, ITU-R BT 601-1, video',
            8 => 'Gray-scale',
            9 => 'PhotoYCC',
            10 => 'RGB',
            11 => 'CMY',
            12 => 'CMYK',
            13 => 'YCCK',
            14 => 'CIELab',
        },
    },
    15 => 'BitsPerSample',
    16 => {
        Name => 'Compression',
        PrintConv => {
            0 => 'Uncompressed, interleaved, 8 bits per sample',
            1 => 'Modified Huffman',
            2 => 'Modified READ',
            3 => 'Modified Modified READ',
            4 => 'JBIG',
            5 => 'JPEG',
        },
    },
    17 => {
        Name => 'ResolutionUnit',
        PrintConv => {
            0 => 'None',
            1 => 'inches',
            2 => 'cm',
        },
    },
    18 => {
        Name => 'YResolution',
        Format => 'int32u',
    },
    22 => {
        Name => 'XResolution',
        Format => 'int32u',
    },
);

# APP9 Media Jukebox segment (ref PH)
%Image::ExifTool::JPEG::MediaJukebox = (
    GROUPS => { 0 => 'XML', 1 => 'MediaJukebox', 2 => 'Image' },
    VARS => { ID_FMT => 'none' },
    NOTES => 'Tags found in the XML metadata of the APP9 "Media Jukebox" segment.',
    Date => {
        Groups => { 2 => 'Time' },
        # convert from days since Dec 30, 1899 to seconds since Jan 1, 1970
        ValueConv => 'ConvertUnixTime(($val - (70 * 365 + 17 + 2)) * 24 * 3600)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Album        => { },
    Caption      => { },
    Keywords     => { },
    Name         => { },
    People       => { },
    Places       => { },
    Tool_Name    => { },
    Tool_Version => { },
);

# JPEG-HDR APP11 information (ref PH, guessed from http://anyhere.com/gward/papers/cic05.pdf)
%Image::ExifTool::JPEG::HDR = (
    GROUPS => { 0 => 'APP11', 1 => 'JPEG-HDR', 2 => 'Image' },
    PROCESS_PROC => \&ProcessJPEG_HDR,
    TAG_PREFIX => '', # (no prefix for unknown tags)
    NOTES => 'Information extracted from APP11 of a JPEG-HDR image.',
    ver => 'JPEG-HDRVersion',
    # (need names for the next 3 tags)
    ln0 => { Description => 'Ln0' },
    ln1 => { Description => 'Ln1' },
    s2n => { Description => 'S2n' },
    alp => { Name => 'Alpha' }, # (Alpha/Beta are saturation parameters)
    bet => { Name => 'Beta' },
    cor => { Name => 'CorrectionMethod' },
    RatioImage => {
        Groups => { 2 => 'Preview' },
        Notes => 'the embedded JPEG-compressed ratio image',
        Binary => 1,
    },
);

# AdobeCM APP13 (no references)
%Image::ExifTool::JPEG::AdobeCM = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP13', 1 => 'AdobeCM', 2 => 'Image' },
    NOTES => q{
        The APP13 "Adobe_CM" segment presumably contains color management
        information, but the meaning of the data is currently unknown.  If anyone
        has an idea about what this means, please let me know.
    },
    FORMAT => 'int16u',
    0 => 'AdobeCMType',
);

# Adobe APP14 refs:
# http://partners.adobe.com/public/developer/en/ps/sdk/5116.DCT_Filter.pdf
# http://java.sun.com/j2se/1.5.0/docs/api/javax/imageio/metadata/doc-files/jpeg_metadata.html#color
%Image::ExifTool::JPEG::Adobe = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP14', 1 => 'Adobe', 2 => 'Image' },
    NOTES => q{
        The APP14 "Adobe" segment stores image encoding information for DCT filters.
        This segment may be copied or deleted as a block using the Extra "Adobe"
        tag, but note that it is not deleted by default when deleting all metadata
        because it may affect the appearance of the image.
    },
    FORMAT => 'int16u',
    0 => 'DCTEncodeVersion',
    1 => {
        Name => 'APP14Flags0',
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                15 => 'Encoded with Blend=1 downsampling'
            },
        },
    },
    2 => {
        Name => 'APP14Flags1',
        PrintConv => {
            0 => '(none)',
            BITMASK => { },
        },
    },
    3 => {
        Name => 'ColorTransform',
        Format => 'int8u',
        PrintConv => {
            0 => 'Unknown (RGB or CMYK)',
            1 => 'YCbCr',
            2 => 'YCCK',
        },
    },
);

# GraphicConverter APP15 (ref PH)
%Image::ExifTool::JPEG::GraphConv = (
    GROUPS => { 0 => 'APP15', 1 => 'GraphConv', 2 => 'Image' },
    NOTES => 'APP15 is used by GraphicConverter to store JPEG quality.',
    'Q' => 'Quality',
);

# APP0 AVI1 segment (ref http://www.schnarff.com/file-formats/bmp/BMPDIB.TXT)
%Image::ExifTool::JPEG::AVI1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP0', 1 => 'AVI1', 2 => 'Image' },
    NOTES => 'This information may be found in APP0 of JPEG image data from AVI videos.',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'InterleavedField',
        PrintConv => {
            0 => 'Not Interleaved',
            1 => 'Odd',
            2 => 'Even',
        },
    },
);

# APP0 Ocad segment (ref PH)
%Image::ExifTool::JPEG::Ocad = (
    PROCESS_PROC => \&ProcessOcad,
    GROUPS => { 0 => 'APP0', 1 => 'Ocad', 2 => 'Image' },
    TAG_PREFIX => 'Ocad',
    FIRST_ENTRY => 0,
    NOTES => q{
        Tags extracted from the JPEG APP0 "Ocad" segment (found in Photobucket
        images).
    },
    Rev => {
        Name => 'OcadRevision',
        Format => 'string[6]',
    }
);

# APP6 NITF segment (National Imagery Transmission Format)
# ref http://www.gwg.nga.mil/ntb/baseline/docs/n010697/bwcguide25aug98.pdf
%Image::ExifTool::JPEG::NITF = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'APP6', 1 => 'NITF', 2 => 'Image' },
    NOTES => q{
        Information in APP6 used by the National Imagery Transmission Format.  See
        L<http://www.gwg.nga.mil/ntb/baseline/docs/n010697/bwcguide25aug98.pdf> for
        the official specification.
    },
    0 => {
        Name => 'NITFVersion',
        Format => 'int8u[2]',
        ValueConv => 'sprintf("%d.%.2d", split(" ",$val))',
    },
    2 => {
        Name => 'ImageFormat',
        ValueConv => 'chr($val & 0xff)',
        PrintConv => { B => 'IMode B' },
    },
    3 => {
        Name => 'BlocksPerRow',
        Format => 'int16u',
    },
    5 => {
        Name => 'BlocksPerColumn',
        Format => 'int16u',
    },
    7 => {
        Name => 'ImageColor',
        PrintConv => { 0 => 'Monochrome' },
    },
    8 => 'BitDepth',
    9 => {
        Name => 'ImageClass',
        PrintConv => {
            0 => 'General Purpose',
            4 => 'Tactical Imagery',
        },
    },
    10 => {
        Name => 'JPEGProcess',
        PrintConv => {
            1 => 'Baseline sequential DCT, Huffman coding, 8-bit samples',
            4 => 'Extended sequential DCT, Huffman coding, 12-bit samples',
        },
    },
    11 => 'Quality',
    12 => {
        Name => 'StreamColor',
        PrintConv => { 0 => 'Monochrome' },
    },
    13 => 'StreamBitDepth',
    14 => {
        Name => 'Flags',
        Format => 'int32u',
        PrintConv => 'sprintf("0x%x", $val)',
    },
);

#------------------------------------------------------------------------------
# Extract information from the JPEG APP0 Ocad segment
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessOcad($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    $et->VerboseDir('APP0 Ocad', undef, length $$dataPt);
    for (;;) {
        last unless $$dataPt =~ /\$(\w+):([^\0\$]+)/g;
        my ($tag, $val) = ($1, $2);
        $val =~ s/^\s+//; $val =~ s/\s+$//;     # remove leading/trailing spaces
        AddTagToTable($tagTablePtr, $tag) unless $$tagTablePtr{$tag};
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from the JPEG APP0 Ocad segment
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessJPEG_HDR($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    $$dataPt =~ /~\0/g or $et->Warn('Unrecognized JPEG-HDR format'), return 0;
    my $pos = pos $$dataPt;
    my $meta = substr($$dataPt, 7, $pos-9);
    $et->VerboseDir('APP11 JPEG-HDR', undef, length $$dataPt);
    while ($meta =~ /(\w+)=([^,\s]*)/g) {
        my ($tag, $val) = ($1, $2);
        AddTagToTable($tagTablePtr, $tag) unless $$tagTablePtr{$tag};
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
    $et->HandleTag($tagTablePtr, 'RatioImage', substr($$dataPt, $pos));
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::JPEG - Definitions for uncommon JPEG segments

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool for some
uncommon JPEG segments.  For speed reasons, definitions for more common JPEG
segments are included in the Image::ExifTool module itself.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/JPEG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

