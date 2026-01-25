#------------------------------------------------------------------------------
# File:         Matroska.pm
#
# Description:  Read meta information from Matroska multimedia files
#
# Revisions:    05/26/2010 - P. Harvey Created
#
# References:   1) http://www.matroska.org/technical/specs/index.html
#               2) https://www.matroska.org/technical/tagging.html
#------------------------------------------------------------------------------

package Image::ExifTool::Matroska;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.19';

sub HandleStruct($$;$$$$);

my %noYes = ( 0 => 'No', 1 => 'Yes' );

my %dateInfo = (
    Groups => { 2 => 'Time' },
    # the spec says to use "-" as a date separator, but my only sample uses ":", so
    # convert to ":" if necessary, and avoid translating all "-" in case someone wants
    # to include a negative time zone (although the spec doesn't mention time zones)
    ValueConv => '$val =~ s/^(\d{4})-(\d{2})-/$1:$2:/; $val',
    PrintConv => '$self->ConvertDateTime($val)',
);

my %uidInfo = (
    Format => 'string',
    ValueConv => 'unpack("H*",$val)'
);

# Matroska tags
# Note: The tag ID's in the Matroska documentation include the length designation
#       (the upper bits), which is not included in the tag ID's below
%Image::ExifTool::Matroska::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => q{
        The following tags are extracted from Matroska multimedia container files.
        This container format is used by file types such as MKA, MKV, MKS and WEBM.
        For speed, by default ExifTool extracts tags only up to the first Cluster
        unless a Seek element specifies the position of a Tags element after this.
        However, the L<Verbose|../ExifTool.html#Verbose> (-v) and L<Unknown|../ExifTool.html#Unknown> = 2 (-U) options force processing of
        Cluster data, and the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> (-ee) option skips over Clusters to
        read subsequent tags.  See
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
    0x3f  => { Name => 'CRC-32',            Format => 'unsigned', Unknown => 1 },
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
    0x13ab => {
        Name => 'SeekID',
        Unknown => 1,
        SeekInfo => 'ID',       # save seek ID's
        # (note: converted from VInt internally)
        PrintConv => q{
            my $tagInfo = $Image::ExifTool::Matroska::Main{$val};
            $val = sprintf('0x%x', $val);
            $val .= " ($$tagInfo{Name})" if ref $tagInfo eq 'HASH' and $$tagInfo{Name};
            return $val;
        },
    },
    0x13ac => {
        Name => 'SeekPosition',
        Format => 'unsigned',
        Unknown => 1,
        SeekInfo => 'Position', # save seek positions
        RawConv => '$val + $$self{SeekHeadOffset}',
    },
#
# Segment Info
#
    0x549a966 => {
        Name => 'Info',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x33a4 => { Name => 'SegmentUID',       %uidInfo, Unknown => 1 },
    0x3384 => { Name => 'SegmentFileName',  Format => 'utf8' },
    0x1cb923 => { Name => 'PrevUID',        %uidInfo, Unknown => 1 },
    0x1c83ab => { Name => 'PrevFileName',   Format => 'utf8' },
    0x1eb923 => { Name => 'NextUID',        %uidInfo, Unknown => 1 },
    0x1e83bb => { Name => 'NextFileName',   Format => 'utf8' },
    0x0444 => { Name => 'SegmentFamily',    Binary => 1, Unknown => 1 },
    0x2924 => {
        Name => 'ChapterTranslate',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x29fc => { Name => 'ChapterTranslateEditionUID', %uidInfo, Unknown => 1 },
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
        ValueConv => '$$self{TimecodeScale} ? $val * $$self{TimecodeScale} / 1e9 : $val / 1000',
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
        # reset TrackType member at the start of each track
        Condition => 'delete $$self{TrackType}; 1',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x57   => { Name => 'TrackNumber',      Format => 'unsigned' },
    0x33c5 => { Name => 'TrackUID',         %uidInfo },
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
    0x137f  => { Name => 'TrackOffset',       Format => 'signed', Unknown => 1 },
    0x15ee  => { Name => 'MaxBlockAdditionID',Format => 'unsigned', Unknown => 1 },
    0x136e  => { Name => 'TrackName',         Format => 'utf8' },
    0x2b59c => { Name => 'TrackLanguage',     Format => 'string' },
    0x2b59d => { Name => 'TrackLanguageIETF', Format => 'string' },
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
    0x3446 => { Name => 'TrackAttachmentUID',%uidInfo },
    0x1a9697=>{ Name => 'CodecSettings',    Format => 'utf8' },
    0x1b4040=>{ Name => 'CodecInfoURL',     Format => 'string' },
    0x6b240 =>{ Name => 'CodecDownloadURL', Format => 'string' },
    0x2a   => { Name => 'CodecDecodeAll',   Format => 'unsigned', PrintConv => \%noYes },
    0x2fab => { Name => 'TrackOverlay',     Format => 'unsigned', Unknown => 1 },
    0x2624 => {
        Name => 'TrackTranslate',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x26fc => { Name => 'TrackTranslateEditionUID', %uidInfo, Unknown => 1 },
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
            0 => 'Undetermined',
            1 => 'Interlaced',
            2 => 'Progressive',
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
            3 => 'Display Aspect Ratio',
            4 => 'Unknown',
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
    0x6ae => { Name => 'AttachedFileUID',       %uidInfo },
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
    0x5bc => { Name => 'EditionUID',        %uidInfo, Unknown => 1 },
    0x5bd => { Name => 'EditionFlagHidden', Format => 'unsigned', Unknown => 1 },
    0x5db => { Name => 'EditionFlagDefault',Format => 'unsigned', Unknown => 1 },
    0x5dd => { Name => 'EditionFlagOrdered',Format => 'unsigned', Unknown => 1 },
    0x36 => {
        Name => 'ChapterAtom',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
    0x33c4 => { Name => 'ChapterUID', %uidInfo, Unknown => 1 },
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
    0x2e67=> { Name => 'ChapterSegmentUID', %uidInfo,  Unknown => 1 },
    0x2ebc=> { Name => 'ChapterSegmentEditionUID', %uidInfo, Unknown => 1 },
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
        # Targets elements
        0x28ca => {
            Name => 'TargetTypeValue',
            Format => 'unsigned',
            PrintConv => {
                10 => 'Shot',
                20 => 'Scene/Subtrack',
                30 => 'Chapter/Track',
                40 => 'Session',
                50 => 'Movie/Album',
                60 => 'Season/Edition',
                70 => 'Collection',
            },
        },
        0x23ca => { Name => 'TargetType',       Format => 'string' },
        0x23c5 => { Name => 'TagTrackUID',      %uidInfo },
        0x23c9 => { Name => 'TagEditionUID',    %uidInfo },
        0x23c4 => { Name => 'TagChapterUID',    %uidInfo },
        0x23c6 => { Name => 'TagAttachmentUID', %uidInfo },
    0x27c8 => {
        Name => 'SimpleTag',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Main' },
    },
        # SimpleTag elements
        0x5a3 => { Name => 'TagName',           Format => 'utf8' },
        0x47a => { Name => 'TagLanguage',       Format => 'string' },
        0x47a => { Name => 'TagLanguageBCP47',  Format => 'string' },
        0x484 => { Name => 'TagDefault',        Format => 'unsigned', PrintConv => \%noYes },
        0x487 => { Name => 'TagString',         Format => 'utf8' },
        0x485 => { Name => 'TagBinary',         Binary => 1 },
#
# Spherical Video V2 (untested)
#
    0x7670 => {
        Name => 'Projection',
        SubDirectory => { TagTable => 'Image::ExifTool::Matroska::Projection' },
    },
#
# other
#
    0x5345414c => { # ('SEAL' in hex)
        Name => 'SEAL',
        NotEBML => 1,   # don't process SubDirectory as EBML elements
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::SEAL' },
    },
);

# Spherical video v2 projection tags (ref https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)
%Image::ExifTool::Matroska::Projection = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => q{
        Projection tags defined by the Spherical Video V2 specification.  See
        L<https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md>
        for the specification.
    },
    0x7671 => {
        Name => 'ProjectionType',
        Format => 'unsigned',
        DataMember => 'ProjectionType',
        RawConv => '$$self{ProjectionType} = $val',
        PrintConv => {
            0 => 'Rectangular',
            1 => 'Equirectangular',
            2 => 'Cubemap',
            3 => 'Mesh',
        },
    },
    # ProjectionPrivate in the spec
    0x7672 => [{
        Name => 'EquirectangularProj',
        Condition => '$$self{ProjectionType} == 1',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::equi' },
    },{
        Name => 'CubemapProj',
        Condition => '$$self{ProjectionType} == 2',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::cbmp' },
    },{ # (don't decode 3 because it is a PITA)
        Name => 'ProjectionPrivate',
        Binary => 1,
    }],
    0x7673 => { Name => 'ProjectionPoseYaw',   Format => 'float' },
    0x7674 => { Name => 'ProjectionPosePitch', Format => 'float' },
    0x7675 => { Name => 'ProjectionPoseRoll',  Format => 'float' },
);

# standardized tag names (ref 2)
%Image::ExifTool::Matroska::StdTag = (
    GROUPS => { 2 => 'Video' },
    PRIORITY => 0, # (don't want named tags to override numbered tags, eg. "DURATION")
    VARS => { LONG_TAGS => 3 },
    NOTES => q{
        Standardized Matroska tags, stored in a SimpleTag structure (see
        L<https://www.matroska.org/technical/tagging.html>).
    },
    ORIGINAL    => 'Original',  # struct
    SAMPLE      => 'Sample',    # struct
    COUNTRY     => 'Country',   # struct (should deal with this properly!)
    TOTAL_PARTS => 'TotalParts',
    PART_NUMBER => 'PartNumber',
    PART_OFFSET => 'PartOffset',
    TITLE       => 'Title',
    SUBTITLE    => 'Subtitle',
    URL         => 'URL',       # nested
    SORT_WITH   => 'SortWith',  # nested
    INSTRUMENTS => {            # nested
        Name => 'Instruments',
        IsList => 1,
        ValueConv => 'my @a = split /,\s?/, $val; \@a',
    },
    EMAIL       => 'Email',     # nested
    ADDRESS     => 'Address',   # nested
    FAX         => 'FAX',       # nested
    PHONE       => 'Phone',     # nested
    ARTIST      => 'Artist',
    LEAD_PERFORMER => 'LeadPerformer',
    ACCOMPANIMENT => 'Accompaniment',
    COMPOSER    => 'Composer',
    ARRANGER    => 'Arranger',
    LYRICS      => 'Lyrics',
    LYRICIST    => 'Lyricist',
    CONDUCTOR   => 'Conductor',
    DIRECTOR    => 'Director',
    ASSISTANT_DIRECTOR      => 'AssistantDirector',
    DIRECTOR_OF_PHOTOGRAPHY => 'DirectorOfPhotography',
    SOUND_ENGINEER          => 'SoundEngineer',
    ART_DIRECTOR            => 'ArtDirector',
    PRODUCTION_DESIGNER     => 'ProductionDesigner',
    CHOREGRAPHER            => 'Choregrapher',
    COSTUME_DESIGNER        => 'CostumeDesigner',
    ACTOR       => 'Actor',
    CHARACTER   => 'Character',
    WRITTEN_BY  => 'WrittenBy',
    SCREENPLAY_BY => 'ScreenplayBy',
    EDITED_BY   => 'EditedBy',
    PRODUCER    => 'Producer',
    COPRODUCER  => 'Coproducer',
    EXECUTIVE_PRODUCER  => 'ExecutiveProducer',
    DISTRIBUTED_BY      => 'DistributedBy',
    MASTERED_BY         => 'MasteredBy',
    ENCODED_BY  => 'EncodedBy',
    MIXED_BY    => 'MixedBy',
    REMIXED_BY  => 'RemixedBy',
    PRODUCTION_STUDIO => 'ProductionStudio',
    THANKS_TO   => 'ThanksTo',
    PUBLISHER   => 'Publisher',
    LABEL       => 'Label',
    GENRE       => 'Genre',
    MOOD        => 'Mood',
    ORIGINAL_MEDIA_TYPE => 'OriginalMediaType',
    CONTENT_TYPE => 'ContentType',
    SUBJECT     => 'Subject',
    DESCRIPTION => 'Description',
    KEYWORDS    => {
        Name => 'Keywords',
        IsList => 1,
        ValueConv => 'my @a = split /,\s?/, $val; \@a',
    },
    SUMMARY     => 'Summary',
    SYNOPSIS    => 'Synopsis',
    INITIAL_KEY => 'InitialKey',
    PERIOD      => 'Period',
    LAW_RATING  => 'LawRating',
    DATE_RELEASED   => { Name => 'DateReleased',     %dateInfo },
    DATE_RECORDED   => { Name => 'DateTimeOriginal', %dateInfo, Description => 'Date/Time Original' },
    DATE_ENCODED    => { Name => 'DateEncoded',      %dateInfo },
    DATE_TAGGED     => { Name => 'DateTagged',       %dateInfo },
    DATE_DIGITIZED  => { Name => 'CreateDate',       %dateInfo },
    DATE_WRITTEN    => { Name => 'DateWritten',      %dateInfo },
    DATE_PURCHASED  => { Name => 'DatePurchased',    %dateInfo },
    RECORDING_LOCATION   => 'RecordingLocation',
    COMPOSITION_LOCATION => 'CompositionLocation',
    COMPOSER_NATIONALITY => 'ComposerNationality',
    COMMENT     => 'Comment',
    PLAY_COUNTER => 'PlayCounter',
    RATING      => 'Rating',
    ENCODER     => 'Encoder',
    ENCODER_SETTINGS => 'EncoderSettings',
    BPS         => 'BPS',
    FPS         => 'FPS',
    BPM         => 'BPM',
    MEASURE     => 'Measure',
    TUNING      => 'Tuning',
    REPLAYGAIN_GAIN => 'ReplaygainGain',
    REPLAYGAIN_PEAK => 'ReplaygainPeak',
    ISRC        => 'ISRC',
    MCDI        => 'MCDI',
    ISBN        => 'ISBN',
    BARCODE     => 'Barcode',
    CATALOG_NUMBER => 'CatalogNumber',
    LABEL_CODE  => 'LabelCode',
    LCCN        => 'Lccn',
    IMDB        => 'IMDB',
    TMDB        => 'TMDB',
    TVDB        => 'TVDB',
    PURCHASE_ITEM   => 'PurchaseItem',
    PURCHASE_INFO   => 'PurchaseInfo',
    PURCHASE_OWNER  => 'PurchaseOwner',
    PURCHASE_PRICE  => 'PurchasePrice',
    PURCHASE_CURRENCY => 'PurchaseCurrency',
    COPYRIGHT   => 'Copyright',
    PRODUCTION_COPYRIGHT => 'ProductionCopyright',
    LICENSE     => 'License',
    TERMS_OF_USE => 'TermsOfUse',
    # (the following are untested)
    'spherical-video' => { #https://github.com/google/spatial-media/blob/master/docs/spherical-video-rfc.md
        Name => 'SphericalVideoXML',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            ProcessProc => 'Image::ExifTool::XMP::ProcessGSpherical',
        },
    },
    'SPHERICAL-VIDEO' => { #https://github.com/google/spatial-media/blob/master/docs/spherical-video-rfc.md
        Name => 'SphericalVideoXML',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            ProcessProc => 'Image::ExifTool::XMP::ProcessGSpherical',
        },
    },
#
# other tags seen
#
    _STATISTICS_WRITING_DATE_UTC => { Name => 'StatisticsWritingDateUTC', %dateInfo },
    _STATISTICS_WRITING_APP => 'StatisticsWritingApp',
    _STATISTICS_TAGS => 'StatisticsTags',
    DURATION => 'Duration',
    NUMBER_OF_FRAMES => 'NumberOfFrames',
    NUMBER_OF_BYTES => 'NumberOfBytes',
);

#------------------------------------------------------------------------------
# Handle MKV SimpleTag structure
# Inputs: 0) ExifTool ref, 1) structure ref, 2) parent tag ID, 3) parent tag Name,
#         4) language code, 5) country code
sub HandleStruct($$;$$$$)
{
    local $_;
    my ($et, $struct, $pid, $pname, $lang, $ctry) = @_;
    my $tagTbl = GetTagTable('Image::ExifTool::Matroska::StdTag');
    my $tag = $$struct{TagName};
    my $tagInfo = $$tagTbl{$tag};
    # create tag if necessary
    unless (ref $tagInfo eq 'HASH') {
        my $name = ucfirst lc $tag;
        $name =~ tr/0-9a-zA-Z_//dc;
        $name =~ s/_([a-z])/\U$1/g;
        $name = "Tag_$name" if length $name < 2;
        $et->VPrint(0, "  [adding $tag = $name]\n");
        $tagInfo = AddTagToTable($tagTbl, $tag, { Name => $name });
    }
    my ($id, $nm);
    if ($pid) {
        $id = "$pid/$tag";
        $nm = "$pname/$$tagInfo{Name}";
        unless ($$tagTbl{$id}) {
            my %copy = %$tagInfo;
            $copy{Name} = $nm;
            $et->VPrint(0, "  [adding $id = $nm]\n");
            $tagInfo = AddTagToTable($tagTbl, $id, \%copy);
        }
    } else {
        ($id, $nm) = ($tag, $$tagInfo{Name});
    }
    if (defined $$struct{TagString} or defined $$struct{TagBinary}) {
        my $val = defined $$struct{TagString} ? $$struct{TagString} : \$$struct{TagBinary};
        $lang = $$struct{TagLanguageBCP47} || $$struct{TagLanguage} || $lang;
        # (Note: not currently handling TagDefault attribute)
        my $code = $lang;
        $code = $lang ? "${lang}-${ctry}" : "eng-${ctry}" if $ctry; # ('eng' is default lang)
        if ($code) {
            $tagInfo = Image::ExifTool::GetLangInfo($tagInfo, $code);
            $et->HandleTag($tagTbl, $$tagInfo{TagID}, $val);
        } else {
            $et->HandleTag($tagTbl, $id, $val);
        }
        # COUNTRY is handled as an attribute for contained tags
        if ($tag eq 'COUNTRY') {
            $ctry = $val;
            ($id, $nm) = ($pid, $pname);
        }
    }
    if ($$struct{struct}) {
        # step into each contained structure
        HandleStruct($et, $_, $id, $nm, $lang, $ctry) foreach @{$$struct{struct}};
    }
}

#------------------------------------------------------------------------------
# Get variable-length Matroska integer
# Inputs: 0) data buffer, 1) position in data
# Returns: integer value and updates position, -1 for unknown/reserved value,
#          or undef if no data left
# Notes: Increments position pointer
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
    my ($buff, $buf2, @dirEnd, $trackIndent, %trackTypes, %trackNum,
        $struct, %seekInfo, %seek);

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
    my $processAll = ($verbose or $et->Options('Unknown') > 1) ? 2 : 0;
    ++$processAll if $et->Options('ExtractEmbedded');
    $$et{TrackTypes} = \%trackTypes;  # store Track types reference
    $$et{SeekHeadOffset} = 0;
    my $oldIndent = $$et{INDENT};
    my $chapterNum = 0;
    my $dirName = 'MKV';

    # loop over all Matroska elements
    for (;;) {
        while (@dirEnd) {
            if ($pos + $dataPos >= $dirEnd[-1][0]) {
                if ($dirEnd[-1][1] eq 'Seek') {
                    # save seek info
                    if (defined $seekInfo{ID} and defined $seekInfo{Position}) {
                        my $seekTag = $$tagTablePtr{$seekInfo{ID}};
                        if (ref $seekTag eq 'HASH' and $$seekTag{Name}) {
                            $seek{$$seekTag{Name}} = $seekInfo{Position} + $$et{SeekHeadOffset};
                        }
                    }
                    undef %seekInfo;
                }
                pop @dirEnd;
                if ($struct) {
                    if (@dirEnd and $dirEnd[-1][2]) {
                        # save this nested structure
                        $dirEnd[-1][2]{struct} or $dirEnd[-1][2]{struct} = [ ];
                        push @{$dirEnd[-1][2]{struct}}, $struct;
                        $struct = $dirEnd[-1][2];
                    } else {
                        # handle completed structures now
                        HandleStruct($et, $struct);
                        undef $struct;
                    }
                }
                $dirName = @dirEnd ? $dirEnd[-1][1] : 'MKV';
                # use INDENT to decide whether or not we are done this Track element
                delete $$et{SET_GROUP1} if $trackIndent and $trackIndent eq $$et{INDENT};
                $$et{INDENT} = substr($$et{INDENT}, 0, -2);
                pop @{$$et{PATH}};
            } else {
                $dirName = $dirEnd[-1][1];
                last;
            }
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
        $$et{SeekHeadOffset} = $pos if $tag == 0x14d9b74;   # save offset of seek head
        my $size = GetVInt($buff, $pos);
        last unless defined $size;
        my ($unknownSize, $seekInfoOnly, $tagName);
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
        if (not $tagInfo and ref $$tagTablePtr{$tag} eq 'HASH' and $$tagTablePtr{$tag}{SeekInfo}) {
            $tagInfo = $$tagTablePtr{$tag};
            $seekInfoOnly = 1;
        }
        if ($tagInfo) {
            $tagName = $$tagInfo{Name};
            if ($$tagInfo{SubDirectory} and not $$tagInfo{NotEBML}) {
                # stop processing at first cluster unless we are using -v -U or -ee
                # or there are Tags after this
                if ($tagName eq 'Cluster' and $processAll < 2) {
                    # jump to Tags if possible
                    unless ($processAll) {
                        if ($seek{Tags} and $seek{Tags} > $pos + $dataPos and $raf->Seek($seek{Tags},0)) {
                            $buff = '';
                            $dataPos = $seek{Tags};
                            $pos = $dataLen = 0;
                            next;
                        }
                        last;
                    }
                    undef $tagInfo; # just skip the Cluster when -ee is used
                } else {
                    # just fall through into the contained EBML elements
                    $$et{INDENT} .= '| ';
                    $dirName = $tagName;
                    $et->VerboseDir($dirName, undef, $size);
                    push @{$$et{PATH}}, $dirName;
                    push @dirEnd, [ $pos + $dataPos + $size, $dirName, $struct ];
                    $struct = { } if $dirName eq 'SimpleTag';   # keep track of SimpleTag elements
                    # set Chapter# and Info family 1 group names
                    if ($tagName eq 'ChapterAtom') {
                        $$et{SET_GROUP1} = 'Chapter' . (++$chapterNum);
                        $trackIndent = $$et{INDENT};
                    } elsif ($tagName eq 'Info' and not $$et{SET_GROUP1}) {
                        $$et{SET_GROUP1} = 'Info';
                        $trackIndent = $$et{INDENT};
                    }
                    next;
                }
            }
        } elsif ($verbose) {
            $et->VPrint(0,sprintf("$$et{INDENT}- Tag 0x%x (Unknown, %d bytes)\n", $tag, $size));
        }
        last if $unknownSize;
        if ($pos + $size > $dataLen) {
            # how much more do we need to read?
            my $more = $pos + $size - $dataLen;
            # just skip unknown and large data blocks
            if (not $tagInfo or $more > 10000000) {
                # don't try to skip very large blocks unless LargeFileSupport is enabled
                if ($more >= 0x80000000) {
                    last unless $et->Options('LargeFileSupport');
                    if ($et->Options('LargeFileSupport') eq '2') {
                        $et->Warn('Processing large block (LargeFileSupport is 2)');
                    }
                }
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
            if ($tagName eq 'TrackNumber') {
                # set Track# family 1 group name for tags directly in the track
                $$et{SET_GROUP1} = 'Track' . $val;
                $trackIndent = $$et{INDENT};
            } elsif ($tagName eq 'TrackUID' and $$et{SET_GROUP1}) {
                # save the Track# group associated with this TrackUID
                $trackNum{$val} = $$et{SET_GROUP1};
            } elsif ($tagName eq 'TagTrackUID' and $trackNum{$val}) {
                # set Track# group for associated SimpleTags tags
                $$et{SET_GROUP1} = $trackNum{$val};
                # we're already one deeper than the level where we want to
                # reset the group name, so trigger at one indent level higher
                $trackIndent = substr($$et{INDENT}, 0, -2);
            }
        }
        my %parms = (
            DataPt  => \$buff,
            DataPos => $dataPos,
            Start   => $pos,
            Size    => $size,
        );
        if ($$tagInfo{NoSave} or $struct) {
            $et->VerboseInfo($tag, $tagInfo, Value => $val, %parms) if $verbose;
            $$struct{$tagName} = $val if $struct;
        } elsif ($$tagInfo{SeekInfo}) {
            my $p = $pos;
            $val = GetVInt($buff, $p) unless defined $val;
            $seekInfo{$$tagInfo{SeekInfo}} = $val;
            $et->HandleTag($tagTablePtr, $tag, $val, %parms) unless $seekInfoOnly;
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

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.matroska.org/technical/specs/index.html>

=item L<https://www.matroska.org/technical/tagging.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Matroska Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
