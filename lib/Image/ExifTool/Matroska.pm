#------------------------------------------------------------------------------
# File:         Matroska.pm
#
# Description:  Read meta information from Matroska multimedia files
#
# Revisions:    05/26/2010 - P. Harvey Created
#
# References:   1) http://www.matroska.org/technical/specs/index.html
#------------------------------------------------------------------------------

package Image::ExifTool::Matroska;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

my %noYes = ( 0 => 'No', 1 => 'Yes' );

# Matroska tags
# Note: The tag ID's in the Matroska documentation include the length designation
#       (the upper bits), which is not included in the tag ID's below
%Image::ExifTool::Matroska::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => q{
        The following tags are extracted from Matroska multimedia container files. 
        This container format is used by file types such as MKA, MKV, MKS and WEBM. 
        For speed, ExifTool extracts tags only up to the first Cluster unless the
        Verbose (-v) or Unknown = 2 (-U) option is used.  See
        L<http://www.matroska.org/technical/specs/index.html> for the official
        Matroska specification.
    },
    # supported Format's: signed, unsigned, float, date, string, utf8
    # (or undef by default)
#
# EBML Header
#
    0xa45dfa3 => {
        Name => 'EBMLHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x286 => { Name => 'EBMLVersion',       Format => 'unsigned' },
    0x2f7 => { Name => 'EBMLReadVersion',   Format => 'unsigned' },
    0x2f2 => { Name => 'EBMLMaxIDLength',   Format => 'unsigned', Unknown => 1 },
    0x2f3 => { Name => 'EBMLMaxSizeLength', Format => 'unsigned', Unknown => 1 },
    0x282 => {
        Name => 'DocType',
        Format => 'string',
        # override FileType for "webm" files
        RawConv => '$self->OverrideFileType("WEBM") if $val eq "webm"; $val',
    },
    0x287 => { Name => 'DocTypeVersion',    Format => 'unsigned' },
    0x285 => { Name => 'DocTypeReadVersion',Format => 'unsigned' },
#
# General
#
    0x3f  => { Name => 'CRC-32',            Binary => 1, Unknown => 1 },
    0x6c  => { Name => 'Void',              NoSave => 1, Unknown => 1 },
#
# Signature
#
    0xb538667 => {
        Name => 'SignatureSlot',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x3e8a => { Name => 'SignatureAlgo',    Format => 'unsigned' },
    0x3e9a => { Name => 'SignatureHash',    Format => 'unsigned' },
    0x3ea5 => { Name =>'SignaturePublicKey',Binary => 1, Unknown => 1 },
    0x3eb5 => { Name => 'Signature',        Binary => 1, Unknown => 1 },
    0x3e5b => {
        Name => 'SignatureElements',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x3e7b => {
        Name => 'SignatureElementList',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x2532 => { Name => 'SignedElement',    Binary => 1, Unknown => 1 },
#
# Segment
#
    0x8538067 => {
        Name => 'SegmentHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x14d9b74 => {
        Name => 'SeekHead',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0xdbb => {
        Name => 'Seek',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x13ab => { Name => 'SeekID',           Binary => 1, Unknown => 1 },
    0x13ac => { Name => 'SeekPosition',     Format => 'unsigned', Unknown => 1 },
#
# Segment Info
#
    0x549a966 => {
        Name => 'Info',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x33a4 => { Name => 'SegmentUID',       Binary => 1, Unknown => 1 },
    0x3384 => { Name => 'SegmentFileName',  Format => 'utf8' },
    0x1cb923 => { Name => 'PrevUID',        Binary => 1, Unknown => 1 },
    0x1c83ab => { Name => 'PrevFileName',   Format => 'utf8' },
    0x1eb923 => { Name => 'NextUID',        Binary => 1, Unknown => 1 },
    0x1e83bb => { Name => 'NextFileName',   Format => 'utf8' },
    0x0444 => { Name => 'SegmentFamily',    Binary => 1, Unknown => 1 },
    0x2924 => {
        Name => 'ChapterTranslate',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x29fc => { Name => 'ChapterTranslateEditionUID',Format => 'unsigned', Unknown => 1 },
    0x29bf => {
        Name => 'ChapterTranslateCodec',
        Format => 'unsigned',
        PrintConv => { 0 => 'Matroska Script', 1 => 'DVD Menu' },
    },
    0x29a5 => { Name => 'ChapterTranslateID',Binary => 1, Unknown => 1 },
    0xad7b1 => {
        Name => 'TimecodeScale',
        Format => 'unsigned',
        RawConv => '$$self{TimecodeScale} = $val',
        ValueConv => '$val / 1e9',
        PrintConv => '($val * 1000) . " ms"',
    },
    0x489 => {
        Name => 'Duration',
        Format => 'float',
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val',
        PrintConv => '$$self{TimecodeScale} ? ConvertDuration($val) : $val',
    },
    0x461 => {
        Name => 'DateTimeOriginal', # called "DateUTC" by the spec
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x3ba9 => { Name => 'Title',            Format => 'utf8' },
    0xd80  => { Name => 'MuxingApp',        Format => 'utf8' },
    0x1741 => { Name => 'WritingApp',       Format => 'utf8' },
#
# Cluster
#
    0xf43b675 => {
        Name => 'Cluster',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x67 => {
        Name => 'TimeCode',
        Format => 'unsigned',
        Unknown => 1,
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val',
        PrintConv => '$$self{TimecodeScale} ? ConvertDuration($val) : $val',
    },
    0x1854 => {
        Name => 'SilentTracks',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x18d7 => { Name => 'SilentTrackNumber',Format => 'unsigned' },
    0x27   => { Name => 'Position',         Format => 'unsigned' },
    0x2b   => { Name => 'PrevSize',         Format => 'unsigned' },
    0x23   => { Name => 'SimpleBlock',      NoSave => 1, Unknown => 1 },
    0x20 => {
        Name => 'BlockGroup',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x21   => { Name => 'Block',            NoSave => 1, Unknown => 1 },
    0x22   => { Name => 'BlockVirtual',     NoSave => 1, Unknown => 1 },
    0x35a1 => {
        Name => 'BlockAdditions',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x26 => {
        Name => 'BlockMore',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x6e   => { Name => 'BlockAddID',       Format => 'unsigned', Unknown => 1 },
    0x25   => { Name => 'BlockAdditional',  NoSave => 1, Unknown => 1 },
    0x1b   => {
        Name => 'BlockDuration',
        Format => 'unsigned',
        Unknown => 1,
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val',
        PrintConv => '$$self{TimecodeScale} ? "$val s" : $val',
    },
    0x7a   => { Name => 'ReferencePriority',Format => 'unsigned', Unknown => 1 },
    0x7b   => {
        Name => 'ReferenceBlock',
        Format => 'signed',
        Unknown => 1,
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val',
        PrintConv => '$$self{TimecodeScale} ? "$val s" : $val',
    },
    0x7d   => { Name => 'ReferenceVirtual', Format => 'signed', Unknown => 1 },
    0x24   => { Name => 'CodecState',       Binary => 1, Unknown => 1 },
    0x0e => {
        Name => 'Slices',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x68 => {
        Name => 'TimeSlice',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x4c   => { Name => 'LaceNumber',       Format => 'unsigned', Unknown => 1 },
    0x4d   => { Name => 'FrameNumber',      Format => 'unsigned', Unknown => 1 },
    0x4b   => { Name => 'BlockAdditionalID',Format => 'unsigned', Unknown => 1 },
    0x4e   => { Name => 'Delay',            Format => 'unsigned', Unknown => 1 },
    0x4f   => { Name => 'ClusterDuration',  Format => 'unsigned', Unknown => 1 },
    0x2f   => { Name => 'EncryptedBlock',   NoSave => 1, Unknown => 1 },
#
# Tracks
#
    0x654ae6b => {
        Name => 'Tracks',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x2e => {
        Name => 'TrackEntry',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x57   => { Name => 'TrackNumber',      Format => 'unsigned' },
    0x33c5 => { Name => 'TrackUID',         Format => 'unsigned', Unknown => 1 },
    0x03 => {
        Name => 'TrackType',
        Format => 'unsigned',
        PrintHex => 1,
        # remember types of all tracks encountered, as well as the current track type
        RawConv => '$$self{TrackTypes}{$val} = 1; $$self{TrackType} = $val',
        PrintConv => {
            0x01 => 'Video',
            0x02 => 'Audio',
            0x03 => 'Complex', # (audio+video)
            0x10 => 'Logo',
            0x11 => 'Subtitle',
            0x12 => 'Buttons',
            0x20 => 'Control',
        },
    },
    0x39   => { Name => 'TrackUsed',        Format => 'unsigned', PrintConv => \%noYes },
    0x08   => { Name => 'TrackDefault',     Format => 'unsigned', PrintConv => \%noYes },
    0x15aa => { Name => 'TrackForced',      Format => 'unsigned', PrintConv => \%noYes },
    0x1c => {
        Name => 'TrackLacing',
        Format => 'unsigned',
        Unknown => 1,
        PrintConv => \%noYes,
    },
    0x2de7 => { Name => 'MinCache',         Format => 'unsigned', Unknown => 1 },
    0x2df8 => { Name => 'MaxCache',         Format => 'unsigned', Unknown => 1 },
    0x3e383 => [
        {
            Name => 'VideoFrameRate',
            Condition => '$$self{TrackType} and $$self{TrackType} == 0x01',
            Format => 'unsigned',
            ValueConv => '$val ? 1e9 / $val : 0',
            PrintConv => 'int($val * 1000 + 0.5) / 1000',
        },{
            Name => 'DefaultDuration',
            Format => 'unsigned',
            ValueConv => '$val / 1e9',
            PrintConv => '($val * 1000) . " ms"',
        }
    ],
    0x3314f => { Name => 'TrackTimecodeScale',Format => 'float' },
    0x137f  => { Name => 'TrackOffset',     Format => 'signed', Unknown => 1 },
    0x15ee  => { Name => 'MaxBlockAdditionID',Format => 'unsigned', Unknown => 1 },
    0x136e  => { Name => 'TrackName',       Format => 'utf8' },
    0x2b59c => { Name => 'TrackLanguage',   Format => 'string' },
    0x06 => [
        {
            Name => 'VideoCodecID',
            Condition => '$$self{TrackType} and $$self{TrackType} == 0x01',
            Format => 'string',
        },{
            Name => 'AudioCodecID',
            Condition => '$$self{TrackType} and $$self{TrackType} == 0x02',
            Format => 'string',
        },{
            Name => 'CodecID',
            Format => 'string',
        }
    ],
    0x23a2 => { Name => 'CodecPrivate',     Binary => 1, Unknown => 1 },
    0x58688 => [
        {
            Name => 'VideoCodecName',
            Condition => '$$self{TrackType} and $$self{TrackType} == 0x01',
            Format => 'utf8',
        },{
            Name => 'AudioCodecName',
            Condition => '$$self{TrackType} and $$self{TrackType} == 0x02',
            Format => 'utf8',
        },{
            Name => 'CodecName',
            Format => 'utf8',
        }
    ],
    0x3446 => { Name => 'TrackAttachmentUID',Format => 'unsigned' },
    0x1a9697=>{ Name => 'CodecSettings',    Format => 'utf8' },
    0x1b4040=>{ Name => 'CodecInfoURL',     Format => 'string' },
    0x6b240 =>{ Name => 'CodecDownloadURL', Format => 'string' },
    0x2a   => { Name => 'CodecDecodeAll',   Format => 'unsigned', PrintConv => \%noYes },
    0x2fab => { Name => 'TrackOverlay',     Format => 'unsigned', Unknown => 1 },
    0x2624 => {
        Name => 'TrackTranslate',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x26fc => { Name => 'TrackTranslateEditionUID',Format => 'unsigned', Unknown => 1 },
    0x26bf => {
        Name => 'TrackTranslateCodec',
        Format => 'unsigned',
        PrintConv => { 0 => 'Matroska Script', 1 => 'DVD Menu' },
    },
    0x26a5 => { Name => 'TrackTranslateTrackID', Binary => 1, Unknown => 1 },
#
# Video
#
    0x60 => {
        Name => 'Video',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x1a => {
        Name => 'VideoScanType',
        Format => 'unsigned',
        PrintConv => {
            0 => 'Progressive',
            1 => 'Interlaced',
        },
    },
    0x13b8 => {
        Name => 'Stereo3DMode',
        Format => 'unsigned',
        Printconv => {
            0 => 'Mono',
            1 => 'Right Eye',
            2 => 'Left Eye',
            3 => 'Both Eyes',
        },
    },
    0x30   => { Name => 'ImageWidth',       Format => 'unsigned' },
    0x3a   => { Name => 'ImageHeight',      Format => 'unsigned' },
    0x14aa => { Name => 'CropBottom',       Format => 'unsigned' },
    0x14bb => { Name => 'CropTop',          Format => 'unsigned' },
    0x14cc => { Name => 'CropLeft',         Format => 'unsigned' },
    0x14dd => { Name => 'CropRight',        Format => 'unsigned' },
    0x14b0 => { Name => 'DisplayWidth',     Format => 'unsigned' },
    0x14ba => { Name => 'DisplayHeight',    Format => 'unsigned' },
    0x14b2 => {
        Name => 'DisplayUnit',
        Format => 'unsigned',
        PrintConv => {
            0 => 'Pixels',
            1 => 'cm',
            2 => 'inches',
        },
    },
    0x14b3 => {
        Name => 'AspectRatioType',
        Format => 'unsigned',
        PrintConv => {
            0 => 'Free Resizing',
            1 => 'Keep Aspect Ratio',
            2 => 'Fixed',
        },
    },
    0xeb524 => { Name => 'ColorSpace',      Binary => 1, Unknown => 1 },
    0xfb523 => { Name => 'Gamma',           Format => 'float' },
    0x383e3 => { Name => 'FrameRate',       Format => 'float' },
#
# Audio
#
    0x61 => {
        Name => 'Audio',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x35   => { Name => 'AudioSampleRate',  Format => 'float',     Groups => { 2 => 'Audio' } },
    0x38b5 => { Name => 'OutputAudioSampleRate',Format => 'float', Groups => { 2 => 'Audio' } },
    0x1f   => { Name => 'AudioChannels',    Format => 'unsigned',  Groups => { 2 => 'Audio' } },
    0x3d7b => {
        Name => 'ChannelPositions',
        Binary => 1,
        Unknown => 1,
        Groups => { 2 => 'Audio' },
    },
    0x2264 => { Name => 'AudioBitsPerSample',   Format => 'unsigned', Groups => { 2 => 'Audio' } },
#
# Content Encoding
#
    0x2d80 => {
        Name => 'ContentEncodings',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x2240 => {
        Name => 'ContentEncoding',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x1031 => { Name => 'ContentEncodingOrder', Format => 'unsigned', Unknown => 1 },
    0x1032 => { Name => 'ContentEncodingScope', Format => 'unsigned', Unknown => 1 },
    0x1033 => {
        Name => 'ContentEncodingType',
        Format => 'unsigned',
        PrintConv => { 0 => 'Compression', 1 => 'Encryption' },
    },
    0x1034 => {
        Name => 'ContentCompression',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x254 => {
        Name => 'ContentCompressionAlgorithm',
        Format => 'unsigned',
        PrintConv => {
            0 => 'zlib',
            1 => 'bzlib',
            2 => 'lzo1x',
            3 => 'Header Stripping',
        },
    },
    0x255 => { Name => 'ContentCompressionSettings',Binary => 1, Unknown => 1 },
    0x1035 => {
        Name => 'ContentEncryption',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x7e1 => {
        Name => 'ContentEncryptionAlgorithm',
        Format => 'unsigned',
        PrintConv => {
            0 => 'Not Encrypted',
            1 => 'DES',
            2 => '3DES',
            3 => 'Twofish',
            4 => 'Blowfish',
            5 => 'AES',
        },
    },
    0x7e2 => { Name => 'ContentEncryptionKeyID',Binary => 1, Unknown => 1 },
    0x7e3 => { Name => 'ContentSignature',      Binary => 1, Unknown => 1 },
    0x7e4 => { Name => 'ContentSignatureKeyID', Binary => 1, Unknown => 1 },
    0x7e5 => {
        Name => 'ContentSignatureAlgorithm',
        Format => 'unsigned',
        PrintConv => {
            0 => 'Not Signed',
            1 => 'RSA',
        },
    },
    0x7e6 => {
        Name => 'ContentSignatureHashAlgorithm',
        Format => 'unsigned',
        PrintConv => {
            0 => 'Not Signed',
            1 => 'SHA1-160',
            2 => 'MD5',
        },
    },
#
# Cues
#
    0xc53bb6b => {
        Name => 'Cues',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x3b => {
        Name => 'CuePoint',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x33 => {
        Name => 'CueTime',
        Format => 'unsigned',
        Unknown => 1,
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val',
        PrintConv => '$$self{TimecodeScale} ? ConvertDuration($val) : $val',
    },
    0x37 => {
        Name => 'CueTrackPositions',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x77   => { Name => 'CueTrack',         Format => 'unsigned', Unknown => 1 },
    0x71   => { Name => 'CueClusterPosition',Format => 'unsigned', Unknown => 1 },
    0x1378 => { Name => 'CueBlockNumber',   Format => 'unsigned', Unknown => 1 },
    0x6a   => { Name => 'CueCodecState',    Format => 'unsigned', Unknown => 1 },
    0x5b => {
        Name => 'CueReference',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x16 => {
        Name => 'CueRefTime',
        Format => 'unsigned',
        Unknown => 1,
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val',
        PrintConv => '$$self{TimecodeScale} ? ConvertDuration($val) : $val',
    },
    0x17  => { Name => 'CueRefCluster',     Format => 'unsigned', Unknown => 1 },
    0x135f=> { Name => 'CueRefNumber',      Format => 'unsigned', Unknown => 1 },
    0x6b  => { Name => 'CueRefCodecState',  Format => 'unsigned', Unknown => 1 },
#
# Attachments
#
    0x941a469 => {
        Name => 'Attachments',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x21a7 => {
        Name => 'AttachedFile',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x67e => { Name => 'AttachedFileDescription',Format => 'utf8' },
    0x66e => { Name => 'AttachedFileName',      Format => 'utf8' },
    0x660 => { Name => 'AttachedFileMIMEType',  Format => 'string' },
    0x65c => { Name => 'AttachedFileData',      Binary => 1 },
    0x6ae => { Name => 'AttachedFileUID',       Format => 'unsigned' },
    0x675 => { Name => 'AttachedFileReferral',  Binary => 1, Unknown => 1 },
#
# Chapters
#
    0x43a770 => {
        Name => 'Chapters',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x5b9 => {
        Name => 'EditionEntry',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x5bc => { Name => 'EditionUID',        Format => 'unsigned', Unknown => 1 },
    0x5bd => { Name => 'EditionFlagHidden', Format => 'unsigned', Unknown => 1 },
    0x5db => { Name => 'EditionFlagDefault',Format => 'unsigned', Unknown => 1 },
    0x5dd => { Name => 'EditionFlagOrdered',Format => 'unsigned', Unknown => 1 },
    0x36 => {
        Name => 'ChapterAtom',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x33c4 => { Name => 'ChapterUID',       Format => 'unsigned', Unknown => 1 },
    0x11 => {
        Name => 'ChapterTimeStart',
        Groups => { 1 => 'Chapter#' },
        Format => 'unsigned',
        ValueConv => '$val / 1e9',
        PrintConv => 'ConvertDuration($val)',
    },
    0x12 => {
        Name => 'ChapterTimeEnd',
        Format => 'unsigned',
        ValueConv => '$val / 1e9',
        PrintConv => 'ConvertDuration($val)',
    },
    0x18  => { Name => 'ChapterFlagHidden', Format => 'unsigned', Unknown => 1 },
    0x598 => { Name => 'ChapterFlagEnabled',Format => 'unsigned', Unknown => 1 },
    0x2e67=> { Name => 'ChapterSegmentUID', Binary => 1, Unknown => 1 },
    0x2ebc=> { Name => 'ChapterSegmentEditionUID', Binary => 1, Unknown => 1 },
    0x23c3 => {
        Name => 'ChapterPhysicalEquivalent',
        Format => 'unsigned',
        PrintConv => {
            10 => 'Index',
            20 => 'Track',
            30 => 'Session',
            40 => 'Layer',
            50 => 'Side',
            60 => 'CD / DVD',
            70 => 'Set / Package',
        },
    },
    0x0f => {
        Name => 'ChapterTrack',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x09 => { Name => 'ChapterTrackNumber', Format => 'unsigned', Unknown => 1 },
    0x00 => {
        Name => 'ChapterDisplay',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x05  => { Name => 'ChapterString',     Format => 'utf8' },
    0x37c => { Name => 'ChapterLanguage',   Format => 'string' },
    0x37e => { Name => 'ChapterCountry',    Format => 'string' },
    0x2944 => {
        Name => 'ChapterProcess',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x2955 => {
        Name => 'ChapterProcessCodecID',
        Format => 'unsigned',
        Unknown => 1,
        PrintConv => { 0 => 'Matroska', 1 => 'DVD' },
    },
    0x50d => { Name => 'ChapterProcessPrivate', Binary => 1, Unknown => 1 },
    0x2911 => {
        Name => 'ChapterProcessCommand',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x2922 => {
        Name => 'ChapterProcessTime',
        Format => 'unsigned',
        Unknown => 1,
        PrintConv => {
            0 => 'For Duration of Chapter',
            1 => 'Before Chapter',
            2 => 'After Chapter',
        },
    },
    0x2933 => { Name => 'ChapterProcessData',   Binary => 1, Unknown => 1 },
#
# Tags
#
    0x254c367 => {
        Name => 'Tags',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x3373 => {
        Name => 'Tag',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x23c0 => {
        Name => 'Targets',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x28ca => { Name => 'TargetTypeValue',  Format => 'unsigned' },
    0x23ca => { Name => 'TargetType',       Format => 'string' },
    0x23c5 => { Name => 'TagTrackUID',      Format => 'unsigned', Unknown => 1 },
    0x23c9 => { Name => 'TagEditionUID',    Format => 'unsigned', Unknown => 1 },
    0x23c4 => { Name => 'TagChapterUID',    Format => 'unsigned', Unknown => 1 },
    0x23c6 => { Name => 'TagAttachmentUID', Format => 'unsigned', Unknown => 1 },
    0x27c8 => {
        Name => 'SimpleTag',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x5a3 => { Name => 'TagName',           Format => 'utf8' },
    0x47a => { Name => 'TagLanguage',       Format => 'string' },
    0x484 => { Name => 'TagDefault',        Format => 'unsigned', PrintConv => \%noYes },
    0x487 => { Name => 'TagString',         Format => 'utf8' },
    0x485 => { Name => 'TagBinary',         Binary => 1 },
);

#------------------------------------------------------------------------------
# Get variable-length Matroska integer
# Inputs: 0) data buffer, 1) position in data
# Returns: integer value and updates position, -1 for unknown/reserved value,
#          or undef if no data left
sub GetVInt($$)
{
    return undef if $_[1] >= length $_[0];
    my $val = ord(substr($_[0], $_[1]++));
    my $num = 0;
    unless ($val) {
        return undef if $_[1] >= length $_[0];
        $val = ord(substr($_[0], $_[1]++));
        return undef unless $val;   # can't be this large!
        $num += 7;  # 7 more bytes to read (we just read one)
    }
    my $mask = 0x7f;
    while ($val == ($val & $mask)) {
        $mask >>= 1;
        ++$num;
    }
    $val = ($val & $mask);
    my $unknown = ($val == $mask);
    return undef if $_[1] + $num > length $_[0];
    while ($num) {
        my $b = ord(substr($_[0], $_[1]++));
        $unknown = 0 if $b != 0xff;
        $val = $val * 256 + $b;
        --$num;
    }
    return $unknown ? -1 : $val;
}

#------------------------------------------------------------------------------
# Read information from a Matroska multimedia file (MKV, MKA, MKS)
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid Matroska file
sub ProcessMKV($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, @dirEnd, $trackIndent, %trackTypes);

    $raf->Read($buff, 4) == 4 or return 0;
    return 0 unless $buff =~ /^\x1a\x45\xdf\xa3/;

    # read in 64kB blocks (already read 4 bytes)
    $raf->Read($buff, 65532) or return 0;
    my $dataLen = length $buff;
    my ($pos, $dataPos) = (0, 4);

    # verify header length
    my $hlen = GetVInt($buff, $pos);
    return 0 unless $hlen and $hlen > 0;
    $pos + $hlen > $dataLen and $et->Warn('Truncated Matroska header'), return 1;
    $et->SetFileType();
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::Matroska::Main');

    # set flag to process entire file (otherwise we stop at the first Cluster)
    my $verbose = $et->Options('Verbose');
    my $processAll = ($verbose or $et->Options('Unknown') > 1);
    $$et{TrackTypes} = \%trackTypes;  # store Track types reference
    my $oldIndent = $$et{INDENT};
    my $chapterNum = 0;

    # loop over all Matroska elements
    for (;;) {
        while (@dirEnd and $pos + $dataPos >= $dirEnd[-1][0]) {
            pop @dirEnd;
            # use INDENT to decide whether or not we are done this Track element
            delete $$et{SET_GROUP1} if $trackIndent and $trackIndent eq $$et{INDENT};
            $$et{INDENT} = substr($$et{INDENT}, 0, -2);
        }
        # read more if we are getting close to the end of our buffer
        # (24 more bytes should be enough to read this element header)
        if ($pos + 24 > $dataLen and $raf->Read($buf2, 65536)) {
            $buff = substr($buff, $pos) . $buf2;
            undef $buf2;
            $dataPos += $pos;
            $dataLen = length $buff;
            $pos = 0;
        }
        my $tag = GetVInt($buff, $pos);
        last unless defined $tag and $tag >= 0;
        my $size = GetVInt($buff, $pos);
        last unless defined $size;
        my $unknownSize;
        $size < 0 and $unknownSize = 1, $size = 1e20;
        if (@dirEnd and $pos + $dataPos + $size > $dirEnd[-1][0]) {
            $et->Warn("Invalid or corrupted $dirEnd[-1][1] master element");
            $pos = $dirEnd[-1][0] - $dataPos;
            if ($pos < 0 or $pos > $dataLen) {
                $buff = '';
                $dataPos += $pos;
                $dataLen = 0;
                $pos = 0;
                $raf->Seek($dataPos, 0) or last;
            }
            next;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        # just fall through into the contained EBML elements
        if ($tagInfo and $$tagInfo{SubDirectory}) {
            # stop processing at first cluster unless we are in verbose mode
            last if $$tagInfo{Name} eq 'Cluster' and not $processAll;
            $$et{INDENT} .= '| ';
            $et->VerboseDir($$tagTablePtr{$tag}{Name}, undef, $size);
            push @dirEnd, [ $pos + $dataPos + $size, $$tagInfo{Name} ];
            if ($$tagInfo{Name} eq 'ChapterAtom') {
                $$et{SET_GROUP1} = 'Chapter' . (++$chapterNum);
                $trackIndent = $$et{INDENT};
            }
            next;
        }
        last if $unknownSize;
        if ($pos + $size > $dataLen) {
            # how much more do we need to read?
            my $more = $pos + $size - $dataLen;
            # just skip unknown and large data blocks
            if (not $tagInfo or $more > 10000000) {
                # don't try to skip very large blocks unless LargeFileSupport is enabled
                last if $more > 0x80000000 and not $et->Options('LargeFileSupport');
                $raf->Seek($more, 1) or last;
                $buff = '';
                $dataPos += $dataLen + $more;
                $dataLen = 0;
                $pos = 0;
                next;
            } else {
                # read data in multiples of 64kB
                $more = (int($more / 65536) + 1) * 65536;
                if ($raf->Read($buf2, $more)) {
                    $buff = substr($buff, $pos) . $buf2;
                    undef $buf2;
                    $dataPos += $pos;
                    $dataLen = length $buff;
                    $pos = 0;
                }
                last if $pos + $size > $dataLen;
            }
        }
        unless ($tagInfo) {
            # ignore the element
            $pos += $size;
            next;
        }
        my $val;
        if ($$tagInfo{Format}) {
            my $fmt = $$tagInfo{Format};
            if ($fmt eq 'string' or $fmt eq 'utf8') {
                ($val = substr($buff, $pos, $size)) =~ s/\0.*//s;
                $val = $et->Decode($val, 'UTF8') if $fmt eq 'utf8';
            } elsif ($fmt eq 'float') {
                if ($size == 4) {
                    $val = GetFloat(\$buff, $pos);
                } elsif ($size == 8) {
                    $val = GetDouble(\$buff, $pos);
                } else {
                    $et->Warn("Illegal float size ($size)");
                }
            } else {
                my @vals = unpack("x${pos}C$size", $buff);
                $val = 0;
                if ($fmt eq 'signed' or $fmt eq 'date') {
                    my $over = 1;
                    foreach (@vals) {
                        $val = $val * 256 + $_;
                        $over *= 256;
                    }
                    # interpret negative numbers
                    $val -= $over if $vals[0] & 0x80;
                    # convert dates (nanoseconds since 2001:01:01)
                    if ($fmt eq 'date') {
                        my $t = $val / 1e9;
                        my $f = $t - int($t);   # fractional seconds
                        $f =~ s/^\d+//;         # remove leading zero
                        # (8 leap days between 1970 and 2001)
                        $t += (((2001-1970)*365+8)*24*3600);
                        $val = Image::ExifTool::ConvertUnixTime($t) . $f . 'Z';
                    }
                } else { # must be unsigned
                    $val = $val * 256 + $_ foreach @vals;
                }
            }
            # set group1 to Track/Chapter number
            if ($$tagInfo{Name} eq 'TrackNumber') {
                $$et{SET_GROUP1} = 'Track' . $val;
                $trackIndent = $$et{INDENT};
            }
        }
        my %parms = (
            DataPt  => \$buff,
            DataPos => $dataPos,
            Start   => $pos,
            Size    => $size,
        );
        if ($$tagInfo{NoSave}) {
            $et->VerboseInfo($tag, $tagInfo, Value => $val, %parms) if $verbose;
        } else {
            $et->HandleTag($tagTablePtr, $tag, $val, %parms);
        }
        $pos += $size;  # step to next element
    }
    $$et{INDENT} = $oldIndent;
    delete $$et{SET_GROUP1};
    # override file type if necessary based on existing track types
    unless ($trackTypes{0x01} or $trackTypes{0x03}) {   # video or complex?
        if ($trackTypes{0x02}) {                        # audio?
            $et->OverrideFileType('MKA');
        } elsif ($trackTypes{0x11}) {                   # subtitle?
            $et->OverrideFileType('MKS');
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Matroska - Read meta information from Matroska files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from Matroska multimedia files (MKA, MKV, MKS and WEBM).

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.matroska.org/technical/specs/index.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Matroska Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

