#------------------------------------------------------------------------------
# File:         ASF.pm
#
# Description:  Read ASF/WMA/WMV meta information
#
# Revisions:    12/23/2005 - P. Harvey Created
#
# References:   1) http://www.microsoft.com/windows/windowsmedia/format/asfspec.aspx
#               2) http://www.adobe.com/devnet/xmp/pdfs/XMPSpecificationPart3.pdf (Oct 2008)
#------------------------------------------------------------------------------

package Image::ExifTool::ASF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::RIFF;

$VERSION = '1.25';

sub ProcessASF($$;$);
sub ProcessContentDescription($$$);
sub ProcessExtendedContentDescription($$$);
sub ProcessMetadata($$$);
sub ProcessPicture($$$);
sub ProcessCodecList($$$);

# GUID definitions
my %errorCorrection = (
    '20FB5700-5B55-11CF-A8FD-00805F5C442B' => 'No Error Correction',
    'BFC3CD50-618F-11CF-8BB2-00AA00B4E220' => 'Audio Spread',
);

my %streamType = (
    'F8699E40-5B4D-11CF-A8FD-00805F5C442B' => 'Audio',
    'BC19EFC0-5B4D-11CF-A8FD-00805F5C442B' => 'Video',
    '59DACFC0-59E6-11D0-A3AC-00A0C90348F6' => 'Command',
    'B61BE100-5B4E-11CF-A8FD-00805F5C442B' => 'JFIF',
    '35907DE0-E415-11CF-A917-00805F5C442B' => 'Degradable JPEG',
    '91BD222C-F21C-497A-8B6D-5AA86BFC0185' => 'File Transfer',
    '3AFB65E2-47EF-40F2-AC2C-70A90D71D343' => 'Binary',
);

my %mutex = (
    'D6E22A00-35DA-11D1-9034-00A0C90349BE' => 'MutexLanguage',
    'D6E22A01-35DA-11D1-9034-00A0C90349BE' => 'MutexBitrate',
    'D6E22A02-35DA-11D1-9034-00A0C90349BE' => 'MutexUnknown',
);

my %bandwidthSharing = (
    'AF6060AA-5197-11D2-B6AF-00C04FD908E9' => 'SharingExclusive',
    'AF6060AB-5197-11D2-B6AF-00C04FD908E9' => 'SharingPartial',
);

my %typeSpecific = (
    '776257D4-C627-41CB-8F81-7AC7FF1C40CC' => 'WebStreamMediaSubtype',
    'DA1E6B13-8359-4050-B398-388E965BF00C' => 'WebStreamFormat',
);

my %advancedContentEncryption = (
    '7A079BB6-DAA4-4e12-A5CA-91D38DC11A8D' => 'DRMNetworkDevices',
);

# ASF top level objects
%Image::ExifTool::ASF::Main = (
    PROCESS_PROC => \&ProcessASF,
    NOTES => q{
        The ASF format is used by Windows WMA and WMV files, and DIVX videos.  Tag
        ID's aren't listed because they are huge 128-bit GUID's that would ruin the
        formatting of this table.
    },
    '75B22630-668E-11CF-A6D9-00AA0062CE6C' => {
        Name => 'Header',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::Header', Size => 6 },
    },
    '75B22636-668E-11CF-A6D9-00AA0062CE6C' => 'Data',
    '33000890-E5B1-11CF-89F4-00A0C90349CB' => 'SimpleIndex',
    'D6E229D3-35DA-11D1-9034-00A0C90349BE' => 'Index',
    'FEB103F8-12AD-4C64-840F-2A1D2F7AD48C' => 'MediaIndex',
    '3CB73FD0-0C4A-4803-953D-EDF7B6228F0C' => 'TimecodeIndex',
    'BE7ACFCB-97A9-42E8-9C71-999491E3AFAC' => { #2
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
);

# ASF header objects
%Image::ExifTool::ASF::Header = (
    PROCESS_PROC => \&ProcessASF,
    '8CABDCA1-A947-11CF-8EE4-00C00C205365' => {
        Name => 'FileProperties',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::FileProperties' },
    },
    'B7DC0791-A9B7-11CF-8EE6-00C00C205365' => {
        Name => 'StreamProperties',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::StreamProperties' },
    },
    '5FBF03B5-A92E-11CF-8EE3-00C00C205365' => {
        Name => 'HeaderExtension',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::HeaderExtension', Size => 22 },
    },
    '86D15240-311D-11D0-A3A4-00A0C90348F6' => {
        Name => 'CodecList',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::CodecList' },
    },
    '1EFB1A30-0B62-11D0-A39B-00A0C90348F6' => 'ScriptCommand',
    'F487CD01-A951-11CF-8EE6-00C00C205365' => 'Marker',
    'D6E229DC-35DA-11D1-9034-00A0C90349BE' => 'BitrateMutualExclusion',
    '75B22635-668E-11CF-A6D9-00AA0062CE6C' => 'ErrorCorrection',
    '75B22633-668E-11CF-A6D9-00AA0062CE6C' => {
        Name => 'ContentDescription',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::ContentDescr' },
    },
    '2211B3FA-BD23-11D2-B4B7-00A0C955FC6E' => {
        Name => 'ContentBranding',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::ContentBranding' },
    },
    'D2D0A440-E307-11D2-97F0-00A0C95EA850' => {
        Name => 'ExtendedContentDescr',
        SubDirectory => { TagTable => 'Image::ExifTool::ASF::ExtendedDescr' },
    },
    '7BF875CE-468D-11D1-8D82-006097C9A2B2' => 'StreamBitrateProps',
    '2211B3FB-BD23-11D2-B4B7-00A0C955FC6E' => 'ContentEncryption',
    '298AE614-2622-4C17-B935-DAE07EE9289C' => 'ExtendedContentEncryption',
    '2211B3FC-BD23-11D2-B4B7-00A0C955FC6E' => 'DigitalSignature',
    '1806D474-CADF-4509-A4BA-9AABCB96AAE8' => 'Padding',
);

%Image::ExifTool::ASF::ContentDescr = (
    PROCESS_PROC => \&ProcessContentDescription,
    GROUPS => { 2 => 'Video' },
    0 => 'Title',
    1 => { Name => 'Author',    Groups => { 2 => 'Author' } },
    2 => { Name => 'Copyright', Groups => { 2 => 'Author' } },
    3 => 'Description',
    4 => 'Rating',
);

%Image::ExifTool::ASF::ContentBranding = (
    PROCESS_PROC => \&ProcessContentBranding,
    GROUPS => { 2 => 'Author' },
    0 => {
        Name => 'BannerImageType',
        PrintConv => {
            0 => 'None',
            1 => 'Bitmap',
            2 => 'JPEG',
            3 => 'GIF',
        },
    },
    1 => { Name => 'BannerImage', Groups => { 2 => 'Preview' }, Binary => 1 },
    2 => 'BannerImageURL',
    3 => 'CopyrightURL',
);

# Note: Many of these tags are similar to those in Image::ExifTool::Microsoft::Xtra
#       and Image::ExifTool::WTV::Metadata
# (tags in this table may have a leading "WM/" removed)
%Image::ExifTool::ASF::ExtendedDescr = (
    PROCESS_PROC => \&ProcessExtendedContentDescription,
    GROUPS => { 2 => 'Video' },
    ASFLeakyBucketPairs => { Binary => 1 },
    AspectRatioX => {},
    AspectRatioY => {},
    Author => { Groups => { 2 => 'Author' } },
    AverageLevel => {},
    BannerImageData => {},
    BannerImageType => {},
    BannerImageURL => {},
    Bitrate => { PrintConv => 'ConvertBitrate($val)' },
    Broadcast => {},
    BufferAverage => {},
    Can_Skip_Backward => {},
    Can_Skip_Forward => {},
    Copyright => { Groups => { 2 => 'Author' } },
    CopyrightURL => { Groups => { 2 => 'Author' } },
    CurrentBitrate => { PrintConv => 'ConvertBitrate($val)' },
    Description => {},
    DRM_ContentID => {},
    DRM_DRMHeader_ContentDistributor => {},
    DRM_DRMHeader_ContentID => {},
    DRM_DRMHeader_IndividualizedVersion => {},
    DRM_DRMHeader_KeyID => {},
    DRM_DRMHeader_LicenseAcqURL => {},
    DRM_DRMHeader_SubscriptionContentID => {},
    DRM_DRMHeader => {},
    DRM_IndividualizedVersion => {},
    DRM_KeyID => {},
    DRM_LASignatureCert => {},
    DRM_LASignatureLicSrvCert => {},
    DRM_LASignaturePrivKey => {},
    DRM_LASignatureRootCert => {},
    DRM_LicenseAcqURL => {},
    DRM_V1LicenseAcqURL => {},
    Duration => { PrintConv => 'ConvertDuration($val)' },
    FileSize => {},
    HasArbitraryDataStream => {},
    HasAttachedImages => {},
    HasAudio => {},
    HasFileTransferStream => {},
    HasImage => {},
    HasScript => {},
    HasVideo => {},
    Is_Protected => {},
    Is_Trusted => {},
    IsVBR => {},
    NSC_Address => {},
    NSC_Description => {},
    NSC_Email => {},
    NSC_Name => {},
    NSC_Phone => {},
    NumberOfFrames => {},
    OptimalBitrate => { PrintConv => 'ConvertBitrate($val)' },
    PeakValue => {},
    Rating => {},
    Seekable => {},
    Signature_Name => {},
    Stridable => {},
    Title => {},
    VBRPeak => {},
    # "WM/" tags...
    AlbumArtist => {},
    AlbumCoverURL => {},
    AlbumTitle => {},
    ASFPacketCount => {},
    ASFSecurityObjectsSize => {},
    AudioFileURL => {},
    AudioSourceURL => {},
    AuthorURL => { Groups => { 2 => 'Author' } },
    BeatsPerMinute => {},
    Category => {},
    Codec => {},
    Composer => {},
    Conductor => {},
    ContainerFormat => {},
    ContentDistributor => {},
    ContentGroupDescription => {},
    Director => {},
    DRM => {},
    DVDID => {},
    EncodedBy => {},
    EncodingSettings => {},
    EncodingTime => { Groups => { 2 => 'Time' }, PrintConv => '$self->ConvertDateTime($val)' },
    Genre => {},
    GenreID => {},
    InitialKey => {},
    ISRC => {},
    Language => {},
    Lyrics => {},
    Lyrics_Synchronised => {},
    MCDI => {},
    MediaClassPrimaryID => { ValueConv => 'Image::ExifTool::ASF::GetGUID($val)' },
    MediaClassSecondaryID => { ValueConv => 'Image::ExifTool::ASF::GetGUID($val)' },
    MediaCredits => {},
    MediaIsDelay => {},
    MediaIsFinale => {},
    MediaIsLive => {},
    MediaIsPremiere => {},
    MediaIsRepeat => {},
    MediaIsSAP => {},
    MediaIsStereo => {},
    MediaIsSubtitled => {},
    MediaIsTape => {},
    MediaNetworkAffiliation => {},
    MediaOriginalBroadcastDateTime => {
        Groups => { 2 => 'Time' },
        ValueConv => '$val=~tr/-T/: /; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    MediaOriginalChannel => {},
    MediaStationCallSign => {},
    MediaStationName => {},
    ModifiedBy => {},
    Mood => {},
    OriginalAlbumTitle => {},
    OriginalArtist => {},
    OriginalFilename => 'OriginalFileName',
    OriginalLyricist => {},
    OriginalReleaseTime => {
        Groups => { 2 => 'Time' },
        ValueConv => '$val=~tr/-T/: /; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    OriginalReleaseYear => { Groups => { 2 => 'Time' } },
    ParentalRating => {},
    ParentalRatingReason => {},
    PartOfSet => {},
    PeakBitrate => { PrintConv => 'ConvertBitrate($val)' },
    Period => {},
    Picture => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::ASF::Picture',
        },
    },
    PlaylistDelay => {},
    Producer => {},
    PromotionURL => {},
    ProtectionType => {},
    Provider => {},
    ProviderCopyright => {},
    ProviderRating => {},
    ProviderStyle => {},
    Publisher => {},
    RadioStationName => {},
    RadioStationOwner => {},
    SharedUserRating => {},
    StreamTypeInfo => {},
    SubscriptionContentID => {},
    SubTitle            => 'Subtitle',
    SubTitleDescription => 'SubtitleDescription',
    Text => {},
    ToolName => {},
    ToolVersion => {},
    Track => {},
    TrackNumber => {},
    UniqueFileIdentifier => {},
    UserWebURL => {},
    VideoClosedCaptioning => {},
    VideoFrameRate => {},
    VideoHeight => {},
    VideoWidth => {},
    WMADRCAverageReference => {},
    WMADRCAverageTarget => {},
    WMADRCPeakReference => {},
    WMADRCPeakTarget => {},
    WMCollectionGroupID => {},
    WMCollectionID => {},
    WMContentID => {},
    Writer => { Groups => { 2 => 'Author' } },
    Year   => { Groups => { 2 => 'Time' } },
);

%Image::ExifTool::ASF::Picture = (
    PROCESS_PROC => \&ProcessPicture,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'PictureType',
        PrintConv => { # (Note: Duplicated in ID3, ASF and FLAC modules!)
            0 => 'Other',
            1 => '32x32 PNG Icon',
            2 => 'Other Icon',
            3 => 'Front Cover',
            4 => 'Back Cover',
            5 => 'Leaflet',
            6 => 'Media',
            7 => 'Lead Artist',
            8 => 'Artist',
            9 => 'Conductor',
            10 => 'Band',
            11 => 'Composer',
            12 => 'Lyricist',
            13 => 'Recording Studio or Location',
            14 => 'Recording Session',
            15 => 'Performance',
            16 => 'Capture from Movie or Video',
            17 => 'Bright(ly) Colored Fish',
            18 => 'Illustration',
            19 => 'Band Logo',
            20 => 'Publisher Logo',
        },
    },
    1 => 'PictureMIMEType',
    2 => 'PictureDescription',
    3 => {
        Name => 'Picture',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
);

%Image::ExifTool::ASF::FileProperties = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    0  => {
        Name => 'FileID',
        Format => 'binary[16]',
        ValueConv => 'Image::ExifTool::ASF::GetGUID($val)',
    },
    16 => { Name => 'FileLength',   Format => 'int64u' },
    24 => {
        Name => 'CreationDate',
        Format => 'int64u',
        Groups => { 2 => 'Time' },
        # time is in 100 ns intervals since 0:00 UTC Jan 1, 1601
        ValueConv => q{ # (89 leap years between 1601 and 1970)
            my $t = $val / 1e7 - (((1970-1601)*365+89)*24*3600);
            return Image::ExifTool::ConvertUnixTime($t) . 'Z';
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    32 => { Name => 'DataPackets',  Format => 'int64u' },
    40 => {
        Name => 'Duration',
        Format => 'int64u',
        Notes => 'called PlayDuration by the ASF spec',
        Priority => 0,
        ValueConv => '$val / 1e7',
        PrintConv => 'ConvertDuration($val)',
    },
    48 => {
        Name => 'SendDuration',
        Format => 'int64u',
        ValueConv => '$val / 1e7',
        PrintConv => 'ConvertDuration($val)',
    },
    56 => { Name => 'Preroll',      Format => 'int64u' },
    64 => { Name => 'Flags',        Format => 'int32u' },
    68 => { Name => 'MinPacketSize',Format => 'int32u' },
    72 => { Name => 'MaxPacketSize',Format => 'int32u' },
    76 => { Name => 'MaxBitrate',   Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
);

%Image::ExifTool::ASF::StreamProperties = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    NOTES => 'Tags with index 54 and greater are conditional based on the StreamType.',
    0  => {
        Name => 'StreamType',
        Format => 'binary[16]',
        RawConv => sub { # set ASF_STREAM_TYPE for use in conditional tags
            my ($val, $et) = @_;
            $$et{ASF_STREAM_TYPE} = $streamType{GetGUID($val)} || '';
            return $val;
        },
        ValueConv => 'Image::ExifTool::ASF::GetGUID($val)',
        PrintConv => \%streamType,
    },
    16 => {
        Name => 'ErrorCorrectionType',
        Format => 'binary[16]',
        ValueConv => 'Image::ExifTool::ASF::GetGUID($val)',
        PrintConv => \%errorCorrection,
    },
    32 => {
        Name => 'TimeOffset',
        Format => 'int64u',
        ValueConv => '$val / 1e7',
        PrintConv => '"$val s"',
    },
    48 => {
        Name => 'StreamNumber',
        Format => 'int16u',
        PrintConv => '($val & 0x7f) . ($val & 0x8000 ? " (encrypted)" : "")',
    },
    54 => [
        {
            Condition => '$self->{ASF_STREAM_TYPE} eq "Audio"',
            Name => 'AudioCodecID',
            Format => 'int16u',
            PrintHex => 1,
            SeparateTable => 'RIFF AudioEncoding',
            PrintConv => \%Image::ExifTool::RIFF::audioEncoding,
        },
        {
            Condition => '$self->{ASF_STREAM_TYPE} =~ /^(Video|JFIF|Degradable JPEG)$/',
            Name => 'ImageWidth',
            Format => 'int32u',
        },
    ],
    56 => {
        Condition => '$self->{ASF_STREAM_TYPE} eq "Audio"',
        Name => 'AudioChannels',
        Format => 'int16u',
    },
    58 => [
        {
            Condition => '$self->{ASF_STREAM_TYPE} eq "Audio"',
            Name => 'AudioSampleRate',
            Format => 'int32u',
        },
        {
            Condition => '$self->{ASF_STREAM_TYPE} =~ /^(Video|JFIF|Degradable JPEG)$/',
            Name => 'ImageHeight',
            Format => 'int32u',
        },
    ],
);

%Image::ExifTool::ASF::HeaderExtension = (
    PROCESS_PROC => \&ProcessASF,
    '14E6A5CB-C672-4332-8399-A96952065B5A' => 'ExtendedStreamProps',
    'A08649CF-4775-4670-8A16-6E35357566CD' => 'AdvancedMutualExcl',
    'D1465A40-5A79-4338-B71B-E36B8FD6C249' => 'GroupMutualExclusion',
    'D4FED15B-88D3-454F-81F0-ED5C45999E24' => 'StreamPrioritization',
    'A69609E6-517B-11D2-B6AF-00C04FD908E9' => 'BandwidthSharing',
    '7C4346A9-EFE0-4BFC-B229-393EDE415C85' => 'LanguageList',
    'C5F8CBEA-5BAF-4877-8467-AA8C44FA4CCA' => {
        Name => 'Metadata',
        SubDirectory => {
            # have seen some tags same as ExtendedDescr, so use this table - PH
            TagTable => 'Image::ExifTool::ASF::ExtendedDescr',
            ProcessProc => \&ProcessMetadata,
        },
    },
    '44231C94-9498-49D1-A141-1D134E457054' => {
        Name => 'MetadataLibrary',
        SubDirectory => {
            # have seen some tags same as ExtendedDescr, so use this table - PH
            TagTable => 'Image::ExifTool::ASF::ExtendedDescr',
            ProcessProc => \&ProcessMetadata,
        },
    },
    'D6E229DF-35DA-11D1-9034-00A0C90349BE' => 'IndexParameters',
    '6B203BAD-3F11-48E4-ACA8-D7613DE2CFA7' => 'TimecodeIndexParms',
    '75B22630-668E-11CF-A6D9-00AA0062CE6C' => 'Compatibility',
    '43058533-6981-49E6-9B74-AD12CB86D58C' => 'AdvancedContentEncryption',
    'ABD3D211-A9BA-11cf-8EE6-00C00C205365' => 'Reserved1',
);

%Image::ExifTool::ASF::CodecList = (
    PROCESS_PROC => \&ProcessCodecList,
    VideoCodecName => {},
    VideoCodecDescription => {},
    AudioCodecName => {},
    AudioCodecDescription => {},
    OtherCodecName => {},
    OtherCodecDescription => {},
);

#------------------------------------------------------------------------------
# Generate GUID from 16 bytes of binary data
# Inputs: 0) data
# Returns: GUID
sub GetGUID($)
{
    # must do some byte swapping
    my $val = shift;
    return $val unless length($val) == 16;
    my $buff = unpack('H*',pack('NnnNN',unpack('VvvNN',$val)));
    $buff =~ s/(.{8})(.{4})(.{4})(.{4})/$1-$2-$3-$4-/;
    return uc($buff);
}

#------------------------------------------------------------------------------
# Process ASF content description
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table reference
# Returns: 1 on success
sub ProcessContentDescription($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    return 0 if $dirLen < 10;
    my @len = unpack('v5', $$dataPt);
    my $pos = 10;
    my $tag;
    foreach $tag (0..4) {
        my $len = shift @len;
        next unless $len;
        return 0 if $pos + $len > $dirLen;
        my $val = $et->Decode(substr($$dataPt,$pos,$len),'UCS2','II');
        $et->HandleTag($tagTablePtr, $tag, $val);
        $pos += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process ASF content branding
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table reference
# Returns: 1 on success
sub ProcessContentBranding($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    return 0 if $dirLen < 40;
    # decode banner image type
    $et->HandleTag($tagTablePtr, 0, unpack('V', $$dataPt));
    # decode banner image, banner URL and copyright URL
    my $pos = 4;
    my $tag;
    foreach $tag (1..3) {
        return 0 if $pos + 4 > $dirLen;
        my $size = unpack("x${pos}V", $$dataPt);
        $pos += 4;
        next unless $size;
        return 0 if $pos + $size > $dirLen;
        my $val = substr($$dataPt, $pos, $size);
        $et->HandleTag($tagTablePtr, $tag, $val);
        $pos += $size;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read ASF value
# Inputs: 0) ExifTool object ref, 1) data reference, 2) value offset,
#         3) format number, 4) size
# Returns: converted value
sub ReadASF($$$$$)
{
    my ($et, $dataPt, $pos, $format, $size) = @_;
    my @vals;
    if ($format == 0) { # unicode string
        $vals[0] = $et->Decode(substr($$dataPt,$pos,$size),'UCS2','II');
    } elsif ($format == 2) { # 4-byte boolean
        @vals = ReadValue($dataPt, $pos, 'int32u', undef, $size);
        foreach (@vals) {
            $_ = $_ ? 'True' : 'False';
        }
    } elsif ($format == 3) { # int32u
        @vals = ReadValue($dataPt, $pos, 'int32u', undef, $size);
    } elsif ($format == 4) { # int64u
        @vals = ReadValue($dataPt, $pos, 'int64u', undef, $size);
    } elsif ($format == 5) { # int16u
        @vals = ReadValue($dataPt, $pos, 'int16u', undef, $size);
    } else { # any other format (including 1, byte array): return raw data
        $vals[0] = substr($$dataPt,$pos,$size);
    }
    return join ' ', @vals;
}

#------------------------------------------------------------------------------
# Process extended content description
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table reference
# Returns: 1 on success
sub ProcessExtendedContentDescription($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    return 0 if $dirLen < 2;
    my $count = Get16u($dataPt, 0);
    $et->VerboseDir($dirInfo, $count);
    my $pos = 2;
    my $i;
    for ($i=0; $i<$count; ++$i) {
        return 0 if $pos + 6 > $dirLen;
        my $nameLen = unpack("x${pos}v", $$dataPt);
        $pos += 2;
        return 0 if $pos + $nameLen + 4 > $dirLen;
        my $tag = Image::ExifTool::Decode(undef,substr($$dataPt,$pos,$nameLen),'UCS2','II','Latin');
        $tag =~ s/^WM\///; # remove leading "WM/"
        $pos += $nameLen;
        my ($dType, $dLen) = unpack("x${pos}v2", $$dataPt);
        $pos += 4;
        return 0 if $pos + $dLen > $dirLen;
        my $val = ReadASF($et,$dataPt,$pos,$dType,$dLen);
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => $dLen,
        );
        $pos += $dLen;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process ASF metadata library (similar to ProcessExtendedContentDescription above)
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table reference
# Returns: 1 on success
sub ProcessMetadata($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    return 0 if $dirLen < 2;
    my $count = Get16u($dataPt, 0);
    $et->VerboseDir($dirInfo, $count);
    my $pos = 2;
    my $i;
    for ($i=0; $i<$count; ++$i) {
        return 0 if $pos + 12 > $dirLen;
        my ($index, $stream, $nameLen, $dType, $dLen) = unpack("x${pos}v4V", $$dataPt);
        $pos += 12;
        return 0 if $pos + $nameLen + $dLen > $dirLen;
        my $tag = Image::ExifTool::Decode(undef,substr($$dataPt,$pos,$nameLen),'UCS2','II','Latin');
        $tag =~ s/^WM\///; # remove leading "WM/"
        $pos += $nameLen;
        my $val = ReadASF($et,$dataPt,$pos,$dType,$dLen);
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => $dLen,
        );
        $pos += $dLen;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process WM/Picture preview
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table reference
# Returns: 1 on success
sub ProcessPicture($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    return 0 unless $dirLen > 9;
    # extract picture type and length
    my ($type, $picLen) = unpack("x${dirStart}CV", $$dataPt);
    $et->VerboseDir('Picture');
    $et->HandleTag($tagTablePtr, 0, $type);
    # extract mime type and description strings (null-terminated unicode strings)
    my $n = $dirLen - 5 - $picLen;
    return 0 if $n & 0x01 or $n < 4;
    my $str = substr($$dataPt, $dirStart+5, $n);
    if ($str =~ /^((?:..)*?)\0\0((?:..)*?)\0\0/s) {
        my ($mime, $desc) = ($1, $2);
        $et->HandleTag($tagTablePtr, 1, $et->Decode($mime,'UCS2','II'));
        $et->HandleTag($tagTablePtr, 2, $et->Decode($desc,'UCS2','II')) if length $desc;
    }
    $et->HandleTag($tagTablePtr, 3, substr($$dataPt, $dirStart+5+$n, $picLen));
    return 1;
}

#------------------------------------------------------------------------------
# Process codec list
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table reference
# Returns: 1 on success
sub ProcessCodecList($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    return 0 if $dirLen < 20;
    my $count = Get32u($dataPt, 16);
    $et->VerboseDir($dirInfo, $count);
    my $pos = 20;
    my $i;
    my %codecType = ( 1 => 'Video', 2 => 'Audio' );
    for ($i=0; $i<$count; ++$i) {
        return 0 if $pos + 8 > $dirLen;
        my $type = ($codecType{Get16u($dataPt, $pos)} || 'Other') . 'Codec';
        # stupid Windows programmers: these lengths are in characters (others are in bytes)
        my $nameLen = Get16u($dataPt, $pos + 2) * 2;
        $pos += 4;
        return 0 if $pos + $nameLen + 2 > $dirLen;
        my $name = $et->Decode(substr($$dataPt,$pos,$nameLen),'UCS2','II');
        $et->HandleTag($tagTablePtr, "${type}Name", $name);
        my $descLen = Get16u($dataPt, $pos + $nameLen) * 2;
        $pos += $nameLen + 2;
        return 0 if $pos + $descLen + 2 > $dirLen;
        my $desc = $et->Decode(substr($$dataPt,$pos,$descLen),'UCS2','II');
        $et->HandleTag($tagTablePtr, "${type}Description", $desc);
        my $infoLen = Get16u($dataPt, $pos + $descLen);
        $pos += $descLen + 2 + $infoLen;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a ASF file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) tag table ref
# Returns: 1 on success, 0 if this wasn't a valid ASF file
sub ProcessASF($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $rtnVal = 0;
    my $pos = 0;
    my ($buff, $err, @parentTable, @childEnd);

    for (;;) {
        last unless $raf->Read($buff, 24) == 24;
        $pos += 24;
        my $tag = GetGUID(substr($buff,0,16));
        unless ($tagTablePtr) {
            # verify this is a valid ASF file
            last unless $tag eq '75B22630-668E-11CF-A6D9-00AA0062CE6C';
            my $fileType = $$et{FILE_EXT};
            $fileType = 'ASF' unless $fileType and $fileType =~ /^(ASF|WMV|WMA|DIVX)$/;
            $et->SetFileType($fileType);
            SetByteOrder('II');
            $tagTablePtr = GetTagTable('Image::ExifTool::ASF::Main');
            $rtnVal = 1;
        }
        my $size = Image::ExifTool::Get64u(\$buff, 16) - 24;
        if ($size < 0) {
            $err = 'Invalid ASF object size';
            last;
        }
        if ($size > 0x7fffffff) {
            if ($size > 0x7fffffff * 4294967296) {
                $err = 'Invalid ASF object size';
            } elsif ($et->Options('LargeFileSupport')) {
                if ($raf->Seek($size, 1)) {
                    $et->VPrint(0, "  Skipped large ASF object ($size bytes)\n");
                    $pos += $size;
                    next;
                }
                $err = 'Error seeking past large ASF object';
            } else {
                $err = 'Large ASF objects not supported (LargeFileSupport not set)';
            }
            last;
        }
        # go back to parent tag table if done with previous children
        if (@childEnd and $pos >= $childEnd[-1]) {
            pop @childEnd;
            $tagTablePtr = pop @parentTable;
            $$et{INDENT} = substr($$et{INDENT},0,-2);
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        $verbose and $et->VerboseInfo($tag, $tagInfo);
        if ($tagInfo) {
            my $subdir = $$tagInfo{SubDirectory};
            if ($subdir) {
                my $subTable = GetTagTable($$subdir{TagTable});
                if ($$subTable{PROCESS_PROC} eq \&ProcessASF) {
                    if (defined $$subdir{Size}) {
                        my $s = $$subdir{Size};
                        if ($verbose > 2) {
                            $raf->Read($buff, $s) == $s or $err = 'Truncated file', last;
                            $et->VerboseDump(\$buff);
                        } elsif (not $raf->Seek($s, 1)) {
                            $err = 'Seek error';
                            last;
                        }
                        # continue processing linearly using subTable
                        push @parentTable, $tagTablePtr;
                        push @childEnd, $pos + $size;
                        $tagTablePtr = $subTable;
                        $pos += $$subdir{Size};
                        if ($verbose) {
                            $$et{INDENT} .= '| ';
                            $et->VerboseDir($$tagInfo{Name});
                        }
                        next;
                    }
                } elsif ($raf->Read($buff, $size) == $size) {
                    my %subdirInfo = (
                        DataPt => \$buff,
                        DirStart => 0,
                        DirLen => $size,
                        DirName => $$tagInfo{Name},
                    );
                    $et->VerboseDump(\$buff) if $verbose > 2;
                    unless ($et->ProcessDirectory(\%subdirInfo, $subTable, $$subdir{ProcessProc})) {
                        $et->Warn("Error processing $$tagInfo{Name} directory");
                    }
                    $pos += $size;
                    next;
                } else {
                    $err = 'Unexpected end of file';
                    last;
                }
            }
        }
        if ($verbose > 2) {
            $raf->Read($buff, $size) == $size or $err = 'Truncated file', last;
            $et->VerboseDump(\$buff);
        } elsif (not $raf->Seek($size, 1)) { # skip the block
            $err = 'Seek error';
            last;
        }
        $pos += $size;
    }
    $err and $et->Warn($err);
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ASF - Read ASF/WMA/WMV meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from Microsoft Advanced Systems Format (ASF) files, including
Windows Media Audio (WMA) and Windows Media Video (WMV) files.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.microsoft.com/windows/windowsmedia/format/asfspec.aspx>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ASF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

