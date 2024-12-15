#------------------------------------------------------------------------------
# File:         Microsoft.pm
#
# Description:  Definitions for custom Microsoft tags
#
# Revisions:    2010/10/01 - P. Harvey Created
#               2011/10/05 - PH Added ProcessXtra()
#               2021/02/23 - PH Added abiltity to write Xtra tags
#
# References:   1) http://research.microsoft.com/en-us/um/redmond/groups/ivm/hdview/hdmetadataspec.htm
#------------------------------------------------------------------------------

package Image::ExifTool::Microsoft;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.23';

sub ProcessXtra($$$);
sub WriteXtra($$$);
sub CheckXtra($$$);

# tags written by Microsoft HDView (ref 1)
%Image::ExifTool::Microsoft::Stitch = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        Information found in the Microsoft custom EXIF tag 0x4748, as written by
        Windows Live Photo Gallery.
    },
    0 => {
        Name => 'PanoramicStitchVersion',
        Format => 'int32u',
    },
    1 => {
        Name => 'PanoramicStitchCameraMotion',
        Format => 'int32u',
        PrintConv => {
            2 => 'Rigid Scale',
            3 => 'Affine',
            4 => '3D Rotation',
            5 => 'Homography',
        },
    },
    2 => {
        Name => 'PanoramicStitchMapType',
        Format => 'int32u',
        PrintConv => {
            0 => 'Perspective',
            1 => 'Horizontal Cylindrical',
            2 => 'Horizontal Spherical',
            257 => 'Vertical Cylindrical',
            258 => 'Vertical Spherical',
        },
    },
    3 => 'PanoramicStitchTheta0',
    4 => 'PanoramicStitchTheta1',
    5 => 'PanoramicStitchPhi0',
    6 => 'PanoramicStitchPhi1',
);

# Microsoft Photo schema properties (MicrosoftPhoto) (ref PH)
%Image::ExifTool::Microsoft::XMP = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-microsoft', 2 => 'Image' },
    NAMESPACE => 'MicrosoftPhoto',
    TABLE_DESC => 'XMP Microsoft',
    VARS => { NO_ID => 1 },
    NOTES => q{
        Microsoft Photo 1.0 schema XMP tags.  This is likely not a complete list,
        but represents tags which have been observed in sample images.  The actual
        namespace prefix is "MicrosoftPhoto", but ExifTool shortens this in the
        family 1 group name.
    },
    CameraSerialNumber => { },
    DateAcquired       => { Groups => { 2 => 'Time' }, %Image::ExifTool::XMP::dateTimeInfo },
    FlashManufacturer  => { },
    FlashModel         => { },
    LastKeywordIPTC    => { List => 'Bag' },
    LastKeywordXMP     => { List => 'Bag' },
    LensManufacturer   => { },
    LensModel          => { Avoid => 1 },
    Rating => {
        Name => 'RatingPercent',
        Notes => q{
            XMP-xmp:Rating values of 1,2,3,4 and 5 stars correspond to RatingPercent
            values of 1,25,50,75 and 99 respectively
        },
    },
    CreatorAppId             => { Name => 'CreatorAppID' },
    CreatorOpenWithUIOptions => { },
    ItemSubType              => { },
);

# Microsoft Photo 1.1 schema properties (MP1 - written as 'prefix0' by MSPhoto) (ref PH)
%Image::ExifTool::Microsoft::MP1 = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-MP1', 2 => 'Image' },
    NAMESPACE => 'MP1',
    TABLE_DESC => 'XMP Microsoft Photo',
    VARS => { NO_ID => 1 },
    NOTES => q{
        Microsoft Photo 1.1 schema XMP tags which have been observed.
    },
    PanoramicStitchCameraMotion => {
        PrintConv => {
            'RigidScale' => 'Rigid Scale',
            'Affine'     => 'Affine',
            '3DRotation' => '3D Rotation',
            'Homography' => 'Homography',
        },
    },
    PanoramicStitchMapType => {
        PrintConv => {
            'Perspective'            => 'Perspective',
            'Horizontal-Cylindrical' => 'Horizontal Cylindrical',
            'Horizontal-Spherical'   => 'Horizontal Spherical',
            'Vertical-Cylindrical'   => 'Vertical Cylindrical',
            'Vertical-Spherical'     => 'Vertical Spherical',
        },
    },
    PanoramicStitchPhi0   => { Writable => 'real' },
    PanoramicStitchPhi1   => { Writable => 'real' },
    PanoramicStitchTheta0 => { Writable => 'real' },
    PanoramicStitchTheta1 => { Writable => 'real' },
    WhiteBalance0         => { Writable => 'real' },
    WhiteBalance1         => { Writable => 'real' },
    WhiteBalance2         => { Writable => 'real' },
    Brightness            => { Avoid => 1 },
    Contrast              => { Avoid => 1 },
    CameraModelID         => { Avoid => 1 },
    ExposureCompensation  => { Avoid => 1 },
    PipelineVersion       => { },
    StreamType            => { },
);

# Microsoft Photo 1.2 schema properties (MP) (ref PH)
# (also ref http://msdn.microsoft.com/en-us/library/windows/desktop/ee719905(v=vs.85).aspx)
my %sRegions = (
    STRUCT_NAME => 'Microsoft Regions',
    NAMESPACE   => 'MPReg',
    NOTES => q{
        Note that PersonLiveIdCID element is called PersonLiveCID according to the
        Microsoft specification, but in practice their software actually writes
        PersonLiveIdCID, so ExifTool uses this too.
    },
    Rectangle         => { },
    PersonDisplayName => { },
    PersonEmailDigest => { },
    PersonLiveIdCID   => { },  # (see https://exiftool.org/forum/index.php?topic=4274.msg20368#msg20368)
    PersonSourceID    => { },
);
%Image::ExifTool::Microsoft::MP = (
    %Image::ExifTool::XMP::xmpTableDefaults,
    GROUPS => { 0 => 'XMP', 1 => 'XMP-MP', 2 => 'Image' },
    NAMESPACE => 'MP',
    TABLE_DESC => 'XMP Microsoft Photo',
    VARS => { NO_ID => 1 },
    NOTES => q{
        Microsoft Photo 1.2 schema XMP tags which have been observed.
    },
    RegionInfo => {
        Name => 'RegionInfoMP',
        Struct => {
            STRUCT_NAME => 'Microsoft RegionInfo',
            NAMESPACE   => 'MPRI',
            Regions   => { Struct => \%sRegions, List => 'Bag' },
            DateRegionsValid => {
                Writable => 'date',
                Shift => 'Time',
                Groups => { 2 => 'Time'},
                PrintConv => '$self->ConvertDateTime($val)',
                PrintConvInv => '$self->InverseDateTime($val,undef,1)',
            },
        },
    },
    # remove "MP" from tag name (was added only to avoid conflict with XMP-mwg-rs:RegionInfo)
    RegionInfoRegions                  => { Flat => 1, Name => 'RegionInfoRegions' },
    RegionInfoDateRegionsValid         => { Flat => 1, Name => 'RegionInfoDateRegionsValid' },
    # shorten flattened Regions tag names to make them easier to use
    RegionInfoRegionsRectangle         => { Flat => 1, Name => 'RegionRectangle' },
    RegionInfoRegionsPersonDisplayName => { Flat => 1, Name => 'RegionPersonDisplayName' },
    RegionInfoRegionsPersonEmailDigest => { Flat => 1, Name => 'RegionPersonEmailDigest' },
    RegionInfoRegionsPersonLiveIdCID   => { Flat => 1, Name => 'RegionPersonLiveIdCID' },
    RegionInfoRegionsPersonSourceID    => { Flat => 1, Name => 'RegionPersonSourceID' },
);

# Xtra tags written in MP4 files written by Microsoft Windows Media Player
# (ref http://msdn.microsoft.com/en-us/library/windows/desktop/dd562330(v=VS.85).aspx)
# Note: These tags are closely related to tags in Image::ExifTool::ASF::ExtendedDescr
#       and Image::ExifTool::WTV::Metadata
%Image::ExifTool::Microsoft::Xtra = (
    PROCESS_PROC => \&ProcessXtra,
    WRITE_PROC => \&WriteXtra,
    CHECK_PROC => \&CheckXtra,
    WRITE_GROUP => 'Microsoft',
    AVOID => 1,
    GROUPS => { 0 => 'QuickTime', 2 => 'Video' },
    VARS => { NO_ID => 1 },
    NOTES => q{
        Tags found in the Microsoft "Xtra" atom of QuickTime videos.  Tag ID's are
        not shown because some are unruly GUID's.  Currently most of these tags are
        not writable because the Microsoft documentation is poor and samples were
        not available, but more tags may be made writable in the future if samples
        are provided.  Note that writable tags in this table are are flagged to
        "Avoid", which means that other more common tags will be written instead if
        possible unless the Microsoft group is specified explicitly.
    },
    Abstract                    => { },
    AcquisitionTime             => { Groups => { 2 => 'Time' } },
    AcquisitionTimeDay          => { Groups => { 2 => 'Time' } },
    AcquisitionTimeMonth        => { Groups => { 2 => 'Time' } },
    AcquisitionTimeYear         => { Groups => { 2 => 'Time' } },
    AcquisitionTimeYearMonth    => { Groups => { 2 => 'Time' } },
    AcquisitionTimeYearMonthDay => { Groups => { 2 => 'Time' } },
    AlbumArtistSortOrder        => { },
    AlbumID                     => { },
    AlbumIDAlbumArtist          => { },
    AlbumTitleSortOrder         => { },
    AlternateSourceURL          => { },
    AudioBitrate                => { },
    AudioFormat                 => { },
    Author                      => { Groups => { 2 => 'Author' } },
    AuthorSortOrder             => { },
    AverageLevel                => { },
    Bitrate                     => { },
    BuyNow                      => { },
    BuyTickets                  => { },
    CallLetters                 => { },
    CameraManufacturer          => { },
    CameraModel                 => { },
    CDTrackEnabled              => { },
    Channels                    => { },
    chapterNum                  => { },
    Comment                     => { },
    ContentDistributorDuration  => { },
    Copyright                   => { Groups => { 2 => 'Author' } },
    Count                       => { },
    CurrentBitrate              => { },
    Description                 => { Writable => 'Unicode', Avoid => 1 },
    DisplayArtist               => { },
    DLNAServerUDN               => { },
    DLNASourceURI               => { },
    DRMKeyID                    => { },
    DRMIndividualizedVersion    => { },
    DTCPIPHost                  => { },
    DTCPIPPort                  => { },
    Duration                    => { },
    DVDID                       => { },
    Event                       => { },
    FileSize                    => { },
    FileType                    => { },
    FourCC                      => { },
    FormatTag                   => { },
    FrameRate                   => { },
    Frequency                   => { },
    IsNetworkFeed               => { },
    Is_Protected                => 'IsProtected',
    IsVBR                       => { },
    LeadPerformer               => { },
    LibraryID                   => { },
    LibraryName                 => { },
    Location                    => { },
    MediaContentTypes           => { },
    MediaType                   => { },
    ModifiedBy                  => { },
    MoreInfo                    => { },
    PartOfSet                   => { },
    PeakValue                   => { },
    PixelAspectRatioX           => { },
    PixelAspectRatioY           => { },
    PlaylistIndex               => { },
    Provider                    => { },
    ProviderLogoURL             => { },
    ProviderURL                 => { },
    RadioBand                   => { },
    RadioFormat                 => { },
    RatingOrg                   => { },
    RecordingTime               => { Groups => { 2 => 'Time' } },
    RecordingTimeDay            => { Groups => { 2 => 'Time' } },
    RecordingTimeMonth          => { Groups => { 2 => 'Time' } },
    RecordingTimeYear           => { Groups => { 2 => 'Time' } },
    RecordingTimeYearMonth      => { Groups => { 2 => 'Time' } },
    RecordingTimeYearMonthDay   => { Groups => { 2 => 'Time' } },
    ReleaseDate                 => { Groups => { 2 => 'Time' } },
    ReleaseDateDay              => { Groups => { 2 => 'Time' } },
    ReleaseDateMonth            => { Groups => { 2 => 'Time' } },
    ReleaseDateYear             => { Groups => { 2 => 'Time' } },
    ReleaseDateYearMonth        => { Groups => { 2 => 'Time' } },
    ReleaseDateYearMonthDay     => { Groups => { 2 => 'Time' } },
    RequestState                => { },
    ShadowFilePath              => { },
    SourceURL                   => { },
    Subject                     => { },
    SyncState                   => { },
    Sync01                      => { },
    Sync02                      => { },
    Sync03                      => { },
    Sync04                      => { },
    Sync05                      => { },
    Sync06                      => { },
    Sync07                      => { },
    Sync08                      => { },
    Sync09                      => { },
    Sync10                      => { },
    Sync11                      => { },
    Sync12                      => { },
    Sync13                      => { },
    Sync14                      => { },
    Sync15                      => { },
    Sync16                      => { },
    SyncOnly                    => { },
    Temporary                   => { },
    Title                       => { },
    titleNum                    => { },
    TitleSortOrder              => { },
    TotalDuration               => { },
    TrackingID                  => { },
    UserCustom1                 => { },
    UserCustom2                 => { },
    UserEffectiveRating         => { },
    UserLastPlayedTime          => { },
    UserPlayCount               => { },
    UserPlaycountAfternoon      => { },
    UserPlaycountEvening        => { },
    UserPlaycountMorning        => { },
    UserPlaycountNight          => { },
    UserPlaycountWeekday        => { },
    UserPlaycountWeekend        => { },
    UserRating                  => { },
    UserServiceRating           => { },
    VideoBitrate                => { },
    VideoFormat                 => { },
    'WM/AlbumArtist'            => { Name => 'AlbumArtist', Writable => 'Unicode' }, # (NC)
    'WM/AlbumCoverURL'          => { Name => 'AlbumCoverURL', Writable => 'Unicode' }, # (NC)
    'WM/AlbumTitle'             => { Name => 'AlbumTitle',  Writable => 'Unicode' }, # (NC)
    'WM/BeatsPerMinute'         => 'BeatsPerMinute',
    'WM/Category'               => { Name => 'Category',    Writable => 'Unicode', List => 1 },
    'WM/Composer'               => { Name => 'Composer',    Writable => 'Unicode' }, # (NC)
    'WM/Conductor'              => { Name => 'Conductor',   Writable => 'Unicode', List => 1 },
    'WM/ContentDistributor'     => { Name => 'ContentDistributor', Writable => 'Unicode' },
    'WM/ContentDistributorType' => 'ContentDistributorType',
    'WM/ContentGroupDescription'=> 'ContentGroupDescription',
    'WM/Director'               => { Name => 'Director',    Writable => 'Unicode', List => 1 },
    'WM/EncodingTime'           => {
        Name => 'EncodingTime',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Writable => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    'WM/Genre'                  => 'Genre',
    'WM/GenreID'                => 'GenreID',
    'WM/InitialKey'             => { Name => 'InitialKey',  Writable => 'Unicode' },
    'WM/Language'               => 'Language',
    'WM/Lyrics'                 => 'Lyrics',
    'WM/MCDI'                   => 'MCDI',
    'WM/MediaClassPrimaryID'    => {
        Name => 'MediaClassPrimaryID',
        Writable => 'GUID',
        PrintConv => { #http://msdn.microsoft.com/en-us/library/windows/desktop/dd757960(v=vs.85).aspx
            'D1607DBC-E323-4BE2-86A1-48A42A28441E' => 'Music',
            'DB9830BD-3AB3-4FAB-8A37-1A995F7FF74B' => 'Video',
            '01CD0F29-DA4E-4157-897B-6275D50C4F11' => 'Audio (not music)',
            'FCF24A76-9A57-4036-990D-E35DD8B244E1' => 'Other (not audio or video)',
        },
    },
    'WM/MediaClassSecondaryID' => {
        Name => 'MediaClassSecondaryID',
        Writable => 'GUID',
        PrintConv => { #http://msdn.microsoft.com/en-us/library/windows/desktop/dd757960(v=vs.85).aspx
            'E0236BEB-C281-4EDE-A36D-7AF76A3D45B5' => 'Audio Book',
            '3A172A13-2BD9-4831-835B-114F6A95943F' => 'Spoken Word',
            '6677DB9B-E5A0-4063-A1AD-ACEB52840CF1' => 'Audio News',
            '1B824A67-3F80-4E3E-9CDE-F7361B0F5F1B' => 'Talk Show',
            '1FE2E091-4E1E-40CE-B22D-348C732E0B10' => 'Video News',
            'D6DE1D88-C77C-4593-BFBC-9C61E8C373E3' => 'Web-based Video',
            '00033368-5009-4AC3-A820-5D2D09A4E7C1' => 'Sound Clip from Game',
            'F24FF731-96FC-4D0F-A2F5-5A3483682B1A' => 'Song from Game',
            'E3E689E2-BA8C-4330-96DF-A0EEEFFA6876' => 'Music Video',
            'B76628F4-300D-443D-9CB5-01C285109DAF' => 'Home Movie',
            'A9B87FC9-BD47-4BF0-AC4F-655B89F7D868' => 'Feature Film',
            'BA7F258A-62F7-47A9-B21F-4651C42A000E' => 'TV Show',
            '44051B5B-B103-4B5C-92AB-93060A9463F0' => 'Corporate Video',
            '0B710218-8C0C-475E-AF73-4C41C0C8F8CE' => 'Home Video from Pictures',
            '00000000-0000-0000-0000-000000000000' => 'Unknown Content', #PH
        },
    },
    'WM/MediaOriginalBroadcastDateTime' => {
        Name => 'MediaOriginalBroadcastDateTime',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    'WM/MediaOriginalChannel'   => 'MediaOriginalChannel',
    'WM/MediaStationName'       => 'MediaStationName',
    'WM/Mood'                   => { Name => 'Mood',        Writable => 'Unicode' },
    'WM/OriginalAlbumTitle'     => { Name => 'OriginalAlbumTitle',  Writable => 'Unicode' }, # (NC)
    'WM/OriginalArtist'         => { Name => 'OriginalArtist',      Writable => 'Unicode' }, # (NC)
    'WM/OriginalLyricist'       => { Name => 'OriginalLyricist',    Writable => 'Unicode' }, # (NC)
    'WM/ParentalRating'         => { Name => 'ParentalRating',      Writable => 'Unicode' },
    'WM/PartOfSet'              => 'PartOfSet',
    'WM/Period'                 => { Name => 'Period',      Writable => 'Unicode' },
    'WM/Producer'               => { Name => 'Producer',    Writable => 'Unicode', List => 1 },
    'WM/ProtectionType'         => 'ProtectionType',
    'WM/Provider'               => { Name => 'Provider',    Writable => 'Unicode' }, # (NC)
    'WM/ProviderRating'         => 'ProviderRating',
    'WM/ProviderStyle'          => 'ProviderStyle',
    'WM/Publisher'              => { Name => 'Publisher',   Writable => 'Unicode' }, # (multiple entries separated by semicolon)
    'WM/SharedUserRating'       => { Name => 'SharedUserRating', Writable => 'int64u' },
    'WM/SubscriptionContentID'  => 'SubscriptionContentID',
    'WM/SubTitle'               => { Name => 'Subtitle',    Writable => 'Unicode' },
    'WM/SubTitleDescription'    => 'SubtitleDescription',
    'WM/TrackNumber'            => 'TrackNumber',
    'WM/UniqueFileIdentifier'   => 'UniqueFileIdentifier',
    'WM/VideoFrameRate'         => 'VideoFrameRate',
    'WM/VideoHeight'            => 'VideoHeight',
    'WM/VideoWidth'             => 'VideoWidth',
    'WM/WMCollectionGroupID'    => 'WMCollectionGroupID',
    'WM/WMCollectionID'         => 'WMCollectionID',
    'WM/WMContentID'            => 'WMContentID',
    'WM/WMShadowFileSourceDRMType' => 'WMShadowFileSourceDRMType',
    'WM/WMShadowFileSourceFileType' => 'WMShadowFileSourceFileType',
    'WM/Writer'                 => { Name => 'Writer',  Groups => { 2 => 'Author' }, Writable => 'Unicode' }, # (NC)
    'WM/Year'                   => { Name => 'Year',    Groups => { 2 => 'Time' } },
    'WM/PromotionURL'           => { Name => 'PromotionURL',Writable => 'Unicode' },
    'WM/AuthorURL'              => { Name => 'AuthorURL', Groups => { 2 => 'Author' }, Writable => 'Unicode' },
    'WM/EncodedBy',             => { Name => 'EncodedBy',   Writable => 'Unicode' },

    # I can't find documentation for the following tags in videos,
    # but the tag ID's correspond to Microsoft property GUID+ID's
    # References:
    #  http://msdn.microsoft.com/en-us/library/cc251929%28v=prot.10%29.aspx
    #  http://multi-rename-script.googlecode.com/svn-history/r4/trunk/plugins/ShellDetails/ShellDetails.ini
    # I have observed only 1 so far:
    '{2CBAA8F5-D81F-47CA-B17A-F8D822300131} 100' => {
        Name => 'DateAcquired', # (seems to be when videos are downloaded from the camera)
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Writable => 'vt_filetime',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef)',
    },
    # the following have not yet been observed...
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 10'    => 'Name',
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 12'    => 'Size',
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 4'     => 'Type',
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 14'    => {
        Name => 'DateModified',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 15'    => {
        Name => 'DateCreated',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 16'    => {
        Name => 'DateAccessed',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 13'    => 'Attributes',
    '{D8C3986F-813B-449C-845D-87B95D674ADE} 2'     => 'Status',
    '{9B174B34-40FF-11D2-A27E-00C04FC30871} 4'     => 'Owner',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 4'     => {
        Name => 'Author',
        Groups => { 2 => 'Author' },
    },
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 2'     => 'Title',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 3'     => 'Subject',
    '{D5CDD502-2E9C-101B-9397-08002B2CF9AE} 2'     => 'Category',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 14'    => 'Pages',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 6'     => 'Comments',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 11'    => {
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
    },
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 2'     => 'Artist',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 4'     => 'AlbumTitle',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 5'     => {
        Name => 'Year',
        Groups => { 2 => 'Time' },
    },
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 7'     => 'TrackNumber',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 11'    => 'Genre',
    '{64440490-4C8B-11D1-8B70-080036B11A03} 3'     => 'Duration',
    '{64440490-4C8B-11D1-8B70-080036B11A03} 4'     => 'Bitrate',
    '{AEAC19E4-89AE-4508-B9B7-BB867ABEE2ED} 2'     => 'Protected',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 272'   => 'CameraModel',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 36867' => {
        Name => 'DatePictureTaken',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{6444048F-4C8B-11D1-8B70-080036B11A03} 13'    => 'Dimensions',
    '{6444048F-4C8B-11D1-8B70-080036B11A03} 3'     => 'Untitled0',
    '{6444048F-4C8B-11D1-8B70-080036B11A03} 4'     => 'Untitled1',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 2'     => 'EpisodeName',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 3'     => 'ProgramDescription',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 12'    => 'Untitled2',
    '{64440490-4C8B-11D1-8B70-080036B11A03} 6'     => 'AudioSampleSize',
    '{64440490-4C8B-11D1-8B70-080036B11A03} 5'     => 'AudioSampleRate',
    '{64440490-4C8B-11D1-8B70-080036B11A03} 7'     => 'Channels',
    '{D5CDD502-2E9C-101B-9397-08002B2CF9AE} 15'    => 'Company',
    '{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 3'     => 'Description',
    '{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 4'     => 'FileVersion',
    '{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 7'     => 'ProductName',
    '{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 8'     => 'ProductVersion',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 5'     => 'Keywords',
    '{28636AA6-953D-11D2-B5D6-00C04FD918D0} 11'    => 'Type',
    '{6D24888F-4718-4BDA-AFED-EA0FB4386CD8} 100'   => 'OfflineStatus',
    '{A94688B6-7D9F-4570-A648-E3DFC0AB2B3F} 100'   => 'OfflineAvailability',
    '{28636AA6-953D-11D2-B5D6-00C04FD918D0} 9'     => 'PerceivedType',
    '{1E3EE840-BC2B-476C-8237-2ACD1A839B22} 3'     => 'Kinds',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 36'    => 'Conductors',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 9'     => 'Rating',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 271'   => 'CameraMaker',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 18'    => 'ProgramName',
    '{293CA35A-09AA-4DD2-B180-1FE245728A52} 100'   => 'Duration',
    '{BFEE9149-E3E2-49A7-A862-C05988145CEC} 100'   => 'IsOnline',
    '{315B9C8D-80A9-4EF9-AE16-8E746DA51D70} 100'   => 'IsRecurring',
    '{F6272D18-CECC-40B1-B26A-3911717AA7BD} 100'   => 'Location',
    '{D55BAE5A-3892-417A-A649-C6AC5AAAEAB3} 100'   => 'OptionalAttendeeAddresses',
    '{09429607-582D-437F-84C3-DE93A2B24C3C} 100'   => 'OptionalAttendees',
    '{744C8242-4DF5-456C-AB9E-014EFB9021E3} 100'   => 'OrganizerAddress',
    '{AAA660F9-9865-458E-B484-01BC7FE3973E} 100'   => 'OrganizerName',
    '{72FC5BA4-24F9-4011-9F3F-ADD27AFAD818} 100'   => 'ReminderTime',
    '{0BA7D6C3-568D-4159-AB91-781A91FB71E5} 100'   => 'RequiredAttendeeAddresses',
    '{B33AF30B-F552-4584-936C-CB93E5CDA29F} 100'   => 'RequiredAttendees',
    '{00F58A38-C54B-4C40-8696-97235980EAE1} 100'   => 'Resources',
    '{5BF396D4-5EB2-466F-BDE9-2FB3F2361D6E} 100'   => 'Free-busyStatus',
    '{9B174B35-40FF-11D2-A27E-00C04FC30871} 3'     => 'TotalSize',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 9'     => 'AccountName',
    '{28636AA6-953D-11D2-B5D6-00C04FD918D0} 5'     => 'Computer',
    '{9AD5BADB-CEA7-4470-A03D-B84E51B9949E} 100'   => 'Anniversary',
    '{CD102C9C-5540-4A88-A6F6-64E4981C8CD1} 100'   => 'AssistantsName',
    '{9A93244D-A7AD-4FF8-9B99-45EE4CC09AF6} 100'   => 'AssistantsPhone',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 47'    => 'Birthday',
    '{730FB6DD-CF7C-426B-A03F-BD166CC9EE24} 100'   => 'BusinessAddress',
    '{402B5934-EC5A-48C3-93E6-85E86A2D934E} 100'   => 'BusinessCity',
    '{B0B87314-FCF6-4FEB-8DFF-A50DA6AF561C} 100'   => 'BusinessCountry-Region',
    '{BC4E71CE-17F9-48D5-BEE9-021DF0EA5409} 100'   => 'BusinessPOBox',
    '{E1D4A09E-D758-4CD1-B6EC-34A8B5A73F80} 100'   => 'BusinessPostalCode',
    '{446F787F-10C4-41CB-A6C4-4D0343551597} 100'   => 'BusinessStateOrProvince',
    '{DDD1460F-C0BF-4553-8CE4-10433C908FB0} 100'   => 'BusinessStreet',
    '{91EFF6F3-2E27-42CA-933E-7C999FBE310B} 100'   => 'BusinessFax',
    '{56310920-2491-4919-99CE-EADB06FAFDB2} 100'   => 'BusinessHomePage',
    '{6A15E5A0-0A1E-4CD7-BB8C-D2F1B0C929BC} 100'   => 'BusinessPhone',
    '{BF53D1C3-49E0-4F7F-8567-5A821D8AC542} 100'   => 'CallbackNumber',
    '{8FDC6DEA-B929-412B-BA90-397A257465FE} 100'   => 'CarPhone',
    '{D4729704-8EF1-43EF-9024-2BD381187FD5} 100'   => 'Children',
    '{8589E481-6040-473D-B171-7FA89C2708ED} 100'   => 'CompanyMainPhone',
    '{FC9F7306-FF8F-4D49-9FB6-3FFE5C0951EC} 100'   => 'Department',
    '{F8FA7FA3-D12B-4785-8A4E-691A94F7A3E7} 100'   => 'E-mailAddress',
    '{38965063-EDC8-4268-8491-B7723172CF29} 100'   => 'E-mail2',
    '{644D37B4-E1B3-4BAD-B099-7E7C04966ACA} 100'   => 'E-mail3',
    '{84D8F337-981D-44B3-9615-C7596DBA17E3} 100'   => 'E-mailList',
    '{CC6F4F24-6083-4BD4-8754-674D0DE87AB8} 100'   => 'E-mailDisplayName',
    '{F1A24AA7-9CA7-40F6-89EC-97DEF9FFE8DB} 100'   => 'FileAs',
    '{14977844-6B49-4AAD-A714-A4513BF60460} 100'   => 'FirstName',
    '{635E9051-50A5-4BA2-B9DB-4ED056C77296} 100'   => 'FullName',
    '{3C8CEE58-D4F0-4CF9-B756-4E5D24447BCD} 100'   => 'Gender',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 70'    => 'GivenName',
    '{5DC2253F-5E11-4ADF-9CFE-910DD01E3E70} 100'   => 'Hobbies',
    '{98F98354-617A-46B8-8560-5B1B64BF1F89} 100'   => 'HomeAddress',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 65'    => 'HomeCity',
    '{08A65AA1-F4C9-43DD-9DDF-A33D8E7EAD85} 100'   => 'HomeCountry-Region',
    '{7B9F6399-0A3F-4B12-89BD-4ADC51C918AF} 100'   => 'HomePOBox',
    '{8AFCC170-8A46-4B53-9EEE-90BAE7151E62} 100'   => 'HomePostalCode',
    '{C89A23D0-7D6D-4EB8-87D4-776A82D493E5} 100'   => 'HomeStateOrProvince',
    '{0ADEF160-DB3F-4308-9A21-06237B16FA2A} 100'   => 'HomeStreet',
    '{660E04D6-81AB-4977-A09F-82313113AB26} 100'   => 'HomeFax',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 20'    => 'HomePhone',
    '{D68DBD8A-3374-4B81-9972-3EC30682DB3D} 100'   => 'IMAddresses',
    '{F3D8F40D-50CB-44A2-9718-40CB9119495D} 100'   => 'Initials',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 6'     => 'JobTitle',
    '{97B0AD89-DF49-49CC-834E-660974FD755B} 100'   => 'Label',
    '{8F367200-C270-457C-B1D4-E07C5BCD90C7} 100'   => 'LastName',
    '{C0AC206A-827E-4650-95AE-77E2BB74FCC9} 100'   => 'MailingAddress',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 71'    => 'MiddleName',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 35'    => 'CellPhone',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 74'    => 'Nickname',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 7'     => 'OfficeLocation',
    '{508161FA-313B-43D5-83A1-C1ACCF68622C} 100'   => 'OtherAddress',
    '{6E682923-7F7B-4F0C-A337-CFCA296687BF} 100'   => 'OtherCity',
    '{8F167568-0AAE-4322-8ED9-6055B7B0E398} 100'   => 'OtherCountry-Region',
    '{8B26EA41-058F-43F6-AECC-4035681CE977} 100'   => 'OtherPOBox',
    '{95C656C1-2ABF-4148-9ED3-9EC602E3B7CD} 100'   => 'OtherPostalCode',
    '{71B377D6-E570-425F-A170-809FAE73E54E} 100'   => 'OtherStateOrProvince',
    '{FF962609-B7D6-4999-862D-95180D529AEA} 100'   => 'OtherStreet',
    '{D6304E01-F8F5-4F45-8B15-D024A6296789} 100'   => 'Pager',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 69'    => 'PersonalTitle',
    '{C8EA94F0-A9E3-4969-A94B-9C62A95324E0} 100'   => 'City',
    '{E53D799D-0F3F-466E-B2FF-74634A3CB7A4} 100'   => 'Country-Region',
    '{DE5EF3C7-46E1-484E-9999-62C5308394C1} 100'   => 'POBox',
    '{18BBD425-ECFD-46EF-B612-7B4A6034EDA0} 100'   => 'PostalCode',
    '{F1176DFE-7138-4640-8B4C-AE375DC70A6D} 100'   => 'StateOrProvince',
    '{63C25B20-96BE-488F-8788-C09C407AD812} 100'   => 'Street',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 48'    => 'PrimaryE-mail',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 25'    => 'PrimaryPhone',
    '{7268AF55-1CE4-4F6E-A41F-B6E4EF10E4A9} 100'   => 'Profession',
    '{9D2408B6-3167-422B-82B0-F583B7A7CFE3} 100'   => 'Spouse',
    '{176DC63C-2688-4E89-8143-A347800F25E9} 73'    => 'Suffix',
    '{AAF16BAC-2B55-45E6-9F6D-415EB94910DF} 100'   => 'TTY-TTDPhone',
    '{C554493C-C1F7-40C1-A76C-EF8C0614003E} 100'   => 'Telex',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 18'    => 'Webpage',
    '{D5CDD502-2E9C-101B-9397-08002B2CF9AE} 27'    => 'Status',
    '{D5CDD502-2E9C-101B-9397-08002B2CF9AE} 26'    => 'ContentType',
    '{43F8D7B7-A444-4F87-9383-52271C9B915C} 100'   => {
        Name => 'DateArchived',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{72FAB781-ACDA-43E5-B155-B2434F85E678} 100'   => {
        Name => 'DateCompleted',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 18258' => {
        Name => 'DateImported',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{276D7BB0-5B34-4FB0-AA4B-158ED12A1809} 100'   => 'ClientID',
    '{F334115E-DA1B-4509-9B3D-119504DC7ABB} 100'   => 'Contributors',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 11'    => 'LastPrinted',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 13'    => {
        Name => 'DateLastSaved',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{1E005EE6-BF27-428B-B01C-79676ACD2870} 100'   => 'Division',
    '{E08805C8-E395-40DF-80D2-54F0D6C43154} 100'   => 'DocumentID',
    '{D5CDD502-2E9C-101B-9397-08002B2CF9AE} 7'     => 'Slides',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 10'    => 'TotalEditingTime',
    '{F29F85E0-4FF9-1068-AB91-08002B27B3D9} 15'    => 'WordCount',
    '{3F8472B5-E0AF-4DB2-8071-C53FE76AE7CE} 100'   => 'DueDate',
    '{C75FAA05-96FD-49E7-9CB4-9F601082D553} 100'   => 'EndDate',
    '{28636AA6-953D-11D2-B5D6-00C04FD918D0} 12'    => 'FileCount',
    '{41CF5AE0-F75A-4806-BD87-59C7D9248EB9} 100'   => 'WindowsFileName',
    '{67DF94DE-0CA7-4D6F-B792-053A3E4F03CF} 100'   => 'FlagColor',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 12'    => 'FlagStatus',
    '{9B174B35-40FF-11D2-A27E-00C04FC30871} 2'     => 'SpaceFree',
    '{6444048F-4C8B-11D1-8B70-080036B11A03} 7'     => 'BitDepth',
    '{6444048F-4C8B-11D1-8B70-080036B11A03} 5'     => 'HorizontalResolution',
    '{6444048F-4C8B-11D1-8B70-080036B11A03} 6'     => 'VerticalResolution',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 11'    => 'Importance',
    '{F23F425C-71A1-4FA8-922F-678EA4A60408} 100'   => 'IsAttachment',
    '{5CDA5FC8-33EE-4FF3-9094-AE7BD8868C4D} 100'   => 'IsDeleted',
    '{5DA84765-E3FF-4278-86B0-A27967FBDD03} 100'   => 'HasFlag',
    '{A6F360D2-55F9-48DE-B909-620E090A647C} 100'   => 'IsCompleted',
    '{346C8BD1-2E6A-4C45-89A4-61B78E8E700F} 100'   => 'Incomplete',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 10'    => 'ReadStatus',
    '{EF884C5B-2BFE-41BB-AAE5-76EEDF4F9902} 100'   => 'Shared',
    '{D0A04F0A-462A-48A4-BB2F-3706E88DBD7D} 100'   => {
        Name => 'Creator',
        Groups => { 2 => 'Author' },
    },
    '{F7DB74B4-4287-4103-AFBA-F1B13DCD75CF} 100'   => {
        Name => 'Date',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{B725F130-47EF-101A-A5F1-02608C9EEBAC} 2'     => 'FolderName',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 6'     => 'FolderPath',
    '{DABD30ED-0043-4789-A7F8-D013A4736622} 100'   => 'Folder',
    '{D4D0AA16-9948-41A4-AA85-D97FF9646993} 100'   => 'Participants',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 7'     => 'Path',
    '{DEA7C82C-1D89-4A66-9427-A4E3DEBABCB1} 100'   => 'ContactNames',
    '{95BEB1FC-326D-4644-B396-CD3ED90E6DDF} 100'   => 'EntryType',
    '{D5CDD502-2E9C-101B-9397-08002B2CF9AE} 28'    => 'Language',
    '{5CBF2787-48CF-4208-B90E-EE5E5D420294} 23'    => {
        Name => 'DateVisited',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{5CBF2787-48CF-4208-B90E-EE5E5D420294} 21'    => 'Description',
    '{B9B4B3FC-2B51-4A42-B5D8-324146AFCF25} 3'     => 'LinkStatus',
    '{B9B4B3FC-2B51-4A42-B5D8-324146AFCF25} 2'     => 'LinkTarget',
    '{5CBF2787-48CF-4208-B90E-EE5E5D420294} 2'     => 'URL',
    '{2E4B640D-5019-46D8-8881-55414CC5CAA0} 100'   => 'MediaCreated',
    '{DE41CC29-6971-4290-B472-F59F2E2F31E2} 100'   => {
        Name => 'DateReleased',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{64440492-4C8B-11D1-8B70-080036B11A03} 36'    => 'EncodedBy',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 22'    => 'Producers',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 30'    => 'Publisher',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 38'    => 'Subtitle',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 34'    => 'UserWebURL',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 23'    => 'Writers',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 21'    => 'Attachments',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 2'     => 'BccAddresses',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 3'     => 'BccNames',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 4'     => 'CcAddresses',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 5'     => 'CcNames',
    '{DC8F80BD-AF1E-4289-85B6-3DFC1B493992} 100'   => 'ConversationID',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 20'    => {
        Name => 'DateReceived',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 19'    => {
        Name => 'DateSent',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 13'    => 'FromAddresses',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 14'    => 'FromNames',
    '{9C1FCF74-2D97-41BA-B4AE-CB2E3661A6E4} 8'     => 'HasAttachments',
    '{0BE1C8E7-1981-4676-AE14-FDD78F05A6E7} 100'   => 'SenderAddress',
    '{0DA41CFA-D224-4A18-AE2F-596158DB4B3A} 100'   => 'SenderName',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 15'    => 'Store',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 16'    => 'ToAddresses',
    '{BCCC8A3C-8CEF-42E5-9B1C-C69079398BC7} 100'   => 'ToDoTitle',
    '{E3E0584C-B788-4A5A-BB20-7F5A44C9ACDD} 17'    => 'ToNames',
    '{FDF84370-031A-4ADD-9E91-0D775F1C6605} 100'   => 'Mileage',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 13'    => 'AlbumArtist',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 35'    => 'Beats-per-minute',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 19'    => 'Composers',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 34'    => 'InitialKey',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 39'    => 'Mood',
    '{56A3372E-CE9C-11D2-9F0E-006097C686F6} 37'    => 'PartOfSet',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 31'    => 'Period',
    '{4776CAFA-BCE4-4CB1-A23E-265E76D8EB11} 100'   => 'Color',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 21'    => 'ParentalRating',
    '{10984E0A-F9F2-4321-B7EF-BAF195AF4319} 100'   => 'ParentalRatingReason',
    '{9B174B35-40FF-11D2-A27E-00C04FC30871} 5'     => 'SpaceUsed',
    '{D35F743A-EB2E-47F2-A286-844132CB1427} 100'   => 'ExifVersion',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 18248' => 'Event',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 37380' => 'ExposureBias',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 34850' => 'ExposureProgram',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 33434' => 'ExposureTime',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 33437' => 'F-stop',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 37385' => 'FlashMode',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 37386' => 'FocalLength',
    '{A0E74609-B84D-4F49-B860-462BD9971F98} 100'   => 'FocalLength35mm',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 34855' => 'ISOSpeed',
    '{E6DDCAF7-29C5-4F0A-9A68-D19412EC7090} 100'   => 'LensMaker',
    '{E1277516-2B5F-4869-89B1-2E585BD38B7A} 100'   => 'LensModel',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 37384' => 'LightSource',
    '{08F6D7C2-E3F2-44FC-AF1E-5AA5C81A2D3E} 100'   => 'MaxAperture',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 37383' => 'MeteringMode',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 274'   => 'Orientation',
    '{6D217F6D-3F6A-4825-B470-5F03CA2FBE9B} 100'   => 'ProgramMode',
    '{49237325-A95A-4F67-B211-816B2D45D2E0} 100'   => 'Saturation',
    '{14B81DA1-0135-4D31-96D9-6CBFC9671A99} 37382' => 'SubjectDistance',
    '{EE3D3D8A-5381-4CFA-B13B-AAF66B5F4EC9} 100'   => 'WhiteBalance',
    '{9C1FCF74-2D97-41BA-B4AE-CB2E3661A6E4} 5'     => 'Priority',
    '{39A7F922-477C-48DE-8BC8-B28441E342E3} 100'   => 'Project',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 7'     => 'ChannelNumber',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 12'    => 'ClosedCaptioning',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 13'    => 'Rerun',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 14'    => 'SAP',
    '{4684FE97-8765-4842-9C13-F006447B178C} 100'   => 'BroadcastDate',
    '{A5477F61-7A82-4ECA-9DDE-98B69B2479B3} 100'   => 'RecordingTime',
    '{6D748DE2-8D38-4CC3-AC60-F009B057C557} 5'     => 'StationCallSign',
    '{1B5439E7-EBA1-4AF8-BDD7-7AF1D4549493} 100'   => 'StationName',
    '{560C36C0-503A-11CF-BAA1-00004C752A9A} 2'     => 'AutoSummary',
    '{560C36C0-503A-11CF-BAA1-00004C752A9A} 3'     => 'Summary',
    '{49691C90-7E17-101A-A91C-08002B2ECDA9} 3'     => 'SearchRanking',
    '{F8D3F6AC-4874-42CB-BE59-AB454B30716A} 100'   => 'Sensitivity',
    '{EF884C5B-2BFE-41BB-AAE5-76EEDF4F9902} 200'   => 'SharedWith',
    '{668CDFA5-7A1B-4323-AE4B-E527393A1D81} 100'   => 'Source',
    '{48FD6EC8-8A12-4CDF-A03E-4EC5A511EDDE} 100'   => 'StartDate',
    '{D37D52C6-261C-4303-82B3-08B926AC6F12} 100'   => 'BillingInformation',
    '{084D8A0A-E6D5-40DE-BF1F-C8820E7C877C} 100'   => 'Complete',
    '{08C7CC5F-60F2-4494-AD75-55E3E0B5ADD0} 100'   => 'TaskOwner',
    '{28636AA6-953D-11D2-B5D6-00C04FD918D0} 14'    => 'TotalFileSize',
    '{0CEF7D53-FA64-11D1-A203-0000F81FEDEE} 9'     => 'LegalTrademarks',
    '{64440491-4C8B-11D1-8B70-080036B11A03} 10'    => 'VideoCompression',
    '{64440492-4C8B-11D1-8B70-080036B11A03} 20'    => 'Directors',
    '{64440491-4C8B-11D1-8B70-080036B11A03} 8'     => 'DataRate',
    '{64440491-4C8B-11D1-8B70-080036B11A03} 4'     => 'FrameHeight',
    '{64440491-4C8B-11D1-8B70-080036B11A03} 6'     => 'FrameRate',
    '{64440491-4C8B-11D1-8B70-080036B11A03} 3'     => 'FrameWidth',
    '{64440491-4C8B-11D1-8B70-080036B11A03} 43'    => 'TotalBitrate',
);

#------------------------------------------------------------------------------
# check new value for Xtra tag
# Inputs: 0) ExifTool object ref, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string, or undef on success
sub CheckXtra($$$)
{
    my ($et, $tagInfo, $valPt) = @_;
    my $format = $$tagInfo{Writable};
    return 'Unknown format' unless $format;
    if ($format =~ /^int/) {
        return 'Not an integer' unless Image::ExifTool::IsInt($$valPt);
    } elsif ($format ne 'Unicode') {
        my @vals = ($$valPt);
        return 'Invalid format' unless WriteXtraValue($et, $tagInfo, \@vals);
    }
    return undef;
}

#------------------------------------------------------------------------------
# Decode value(s) in Microsoft Xtra tag
# Inputs: 0) ExifTool object ref, 1) value data
# Returns: Scalar context: decoded value, List context: 0) decoded value, 1) format string
sub ReadXtraValue($$)
{
    my ($et, $data) = @_;
    my ($format, $i, @vals);
    
    return undef if length($data) < 10;

    # (version flags according to the reference, but looks more like a count - PH)
    my $count = Get32u(\$data, 0);
    # point to start of first value (after 4-byte count, 4-byte length and 2-byte type)
    my $valPos = 10;
    for ($i=0; ;) {
        # (stored value includes size of $valLen and $valType, so subtract 6)
        my $valLen = Get32u(\$data, $valPos - 6) - 6;
        last if $valPos + $valLen > length($data);
        my $valType = Get16u(\$data, $valPos - 2);
        my $val = substr($data, $valPos, $valLen);
        # Note: all dumb Microsoft values are little-endian inside a big-endian-format file
        SetByteOrder('II');
        if ($valType == 8) {
            $format = 'Unicode';
            $val = $et->Decode($val, 'UCS2');
        } elsif ($valType == 19 and $valLen == 8) {
            $format = 'int64u';
            $val = Get64u(\$val, 0);
        } elsif ($valType == 21 and $valLen == 8) {
            $format = 'date';
            $val = Get64u(\$val, 0);
            # convert time from 100 ns intervals since Jan 1, 1601
            $val = $val * 1e-7 - 11644473600 if $val;
            # (the Nikon S100 uses UTC timezone, same as ASF - PH)
            $val = Image::ExifTool::ConvertUnixTime($val, 1);
        } elsif ($valType == 72 and $valLen == 16) {
            $format = 'GUID';
            $val = uc unpack('H*',pack('NnnNN',unpack('VvvNN',$val)));
            $val =~ s/(.{8})(.{4})(.{4})(.{4})/$1-$2-$3-$4-/;
        } elsif ($valType == 65 and $valLen > 4) { #PH (empirical)
            $format = 'variant';
            require Image::ExifTool::FlashPix;
            my $vPos = 0; # (necessary because ReadFPXValue updates this)
            # read entry as a VT_VARIANT (use FlashPix module for this)
            $val = Image::ExifTool::FlashPix::ReadFPXValue($et, \$val, $vPos,
                   Image::ExifTool::FlashPix::VT_VARIANT(), $valLen, 1);
        } else {
            $format = "Unknown($valType)";
        }
        SetByteOrder('MM'); # back to native QuickTime byte ordering
        push @vals, $val;
        last if ++$i >= $count;
        $valPos += $valLen + 6; # step to next value
        last if $valPos > length($data);
    }
    return wantarray ? (\@vals, $format) : \@vals;
}

#------------------------------------------------------------------------------
# Write a Microsoft Xtra value
# Inputs: 0) ExifTool object ref, 1) tagInfo ref, 2) reference to list of values
# Returns: new value binary data (or empty string)
sub WriteXtraValue($$$)
{
    my ($et, $tagInfo, $vals) = @_;
    my $format = $$tagInfo{Writable};
    my $buff = '';
    my $count = 0;
    my $val;
    foreach $val (@$vals) {
        SetByteOrder('II');
        my ($type, $dat);
        if ($format eq 'Unicode') {
            $dat = $et->Encode($val,'UCS2','II') . "\0\0";  # (must be null terminated)
            $type = 8;
        } elsif ($format eq 'int64u') {
            if (Image::ExifTool::IsInt($val)) {
                $dat = Set64u($val);
                $type = 19;
            }
        } elsif ($format eq 'date') {
            $dat = Image::ExifTool::GetUnixTime($val, 1);   # (convert to UTC, NC)
            if ($dat) {
                # 100ns intervals since Jan 1, 1601
                $dat = Set64u(($dat + 11644473600) * 1e7);
                $type = 21;
            }
        } elsif ($format eq 'vt_filetime') { # 'date' value inside a VT_VARIANT
            $dat = Image::ExifTool::GetUnixTime($val);  # (leave as local time, NC)
            if ($dat) {
                # 100ns intervals since Jan 1, 1601
                $dat = Set32u(64) . Set64u(($dat + 11644473600) * 1e7);
                $type = 65;
            }
        } elsif ($format eq 'GUID') {
            ($dat = $val) =~ tr/-//d;
            if (length($dat) == 32) {
                $dat = pack('VvvNN',unpack('NnnNN',pack('H*', $dat)));
                $type = 72;
            }
        } else {
            $et->Warn("Error converting value for Microsoft:$$tagInfo{Name}");
        }
        SetByteOrder('MM');
        if (defined $type) {
            ++$count;
            $buff .= Set32u(length($dat)+6) . Set16u($type) . $dat;
        }
    }
    return $count ? Set32u($count) . $buff : '';
}

#------------------------------------------------------------------------------
# Add new values to list
# Inputs: 0) ExifTool ref, 1) new value list ref, 2) nvHash ref
# Returns: true if something was added
sub AddNewValues($$$)
{
    my ($et, $vals, $nvHash) = @_;
    my @newVals = $et->GetNewValue($nvHash) or return undef;
    if ($$et{OPTIONS}{Verbose} > 1) {
        $et->VPrint(1, "  + Microsoft:$$nvHash{TagInfo}{Name} = $_\n") foreach @newVals;
    }
    push @$vals, @newVals;
    return 1;
}

#------------------------------------------------------------------------------
# Write tags to a Microsoft Xtra MP4 atom
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: Microsoft Xtra data block (may be empty if no Xtra data) or undef on error
sub WriteXtra($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;      # allow dummy access

    my $delGroup = ($$et{DEL_GROUP} and $$et{DEL_GROUP}{Microsoft});
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);

    return undef unless $delGroup or %$newTags;  # don't rewrite if nothing to do

    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = length $$dataPt;
    my $newData = '';
    my $pos = 0;
    my ($err, %done, $changed, $tag);

    if ($delGroup) {
        $changed = 1 if $dataLen;
        my $empty = '';
        $dataPt = $empty;
        $dataLen = 0;
    }
    for (;;) {
        last if $pos + 4 > $dataLen;
        my $size = Get32u($dataPt, $pos); # (includes $size word)
        ($size < 8 or $pos + $size > $dataLen) and $err=1, last;
        my $tagLen = Get32u($dataPt, $pos + 4);
        $tagLen + 18 > $size and $err=1, last;
        $tag = substr($$dataPt, $pos + 8, $tagLen);
        my @newVals;
        while ($$newTags{$tag}) {
            my $nvHash = $et->GetNewValueHash($$newTags{$tag});
            $$nvHash{CreateOnly} and delete($$newTags{$tag}), last; # don't edit this tag
            my $valPos = $pos + 8 + $tagLen;
            my $valLen = $size - 8 - $tagLen;
            my $val = ReadXtraValue($et, substr($$dataPt, $valPos, $valLen));
            foreach $val (@$val) {
                my $overwrite = $et->IsOverwriting($nvHash, $val);
                $overwrite or push(@newVals, $val), next;
                $et->VPrint(1, "  - Microsoft:$$newTags{$tag}{Name} = $val\n");
                next if $done{$tag};
                $done{$tag} = 1;
                AddNewValues($et, \@newVals, $nvHash);
            }
            # add to the end of the list if this was a List-type tag and we didn't delete anything
            if (not $done{$tag} and $$newTags{$tag}{List}) {
                AddNewValues($et, \@newVals, $nvHash) or last;
                $done{$tag} = 1;
            }
            last;   # (it was a cheap goto)
        }
        if ($done{$tag}) {
            $changed = 1;
            # write changed values
            my $buff = WriteXtraValue($et, $$newTags{$tag}, \@newVals);
            if (length $buff) {
                $newData .= Set32u(8+length($tag)+length($buff)) . Set32u(length($tag)) . $tag . $buff;
            }
        } else {
            # nothing changed; just copy over
            $newData .= substr($$dataPt, $pos, $size);
        }
        $pos += $size;  # step to next entry
    }
    if ($err) {
        $et->Warn('Microsoft Xtra format error');
        return undef;
    }
    # add any new tags
    foreach $tag (sort keys %$newTags) {
        next if $done{$tag};
        my $nvHash = $et->GetNewValueHash($$newTags{$tag});
        next unless $$nvHash{IsCreating} and not $$nvHash{EditOnly};
        my @newVals;
        AddNewValues($et, \@newVals, $nvHash) or next;
        my $buff = WriteXtraValue($et, $$newTags{$tag}, \@newVals);
        if (length $buff) {
            $newData .= Set32u(8+length($tag)+length($buff)) . Set32u(length($tag)) . $tag . $buff;
            $changed = 1;
        }
    }
    if ($changed) {
        ++$$et{CHANGED};
    } else {
        undef $newData;
    }
    return $newData;
}

#------------------------------------------------------------------------------
# Extract information from Xtra MP4 atom
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Reference: http://code.google.com/p/mp4v2/ [since removed from trunk]
sub ProcessXtra($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{Base} || 0;
    my $dataLen = $$dirInfo{DataLen};
    my $pos = 0;
    $et->VerboseDir('Xtra', 0, $dataLen);
    for (;;) {
        last if $pos + 4 > $dataLen;
        my $size = Get32u($dataPt, $pos); # (includes $size word)
        last if $size < 8 or $pos + $size > $dataLen;
        my $tagLen = Get32u($dataPt, $pos + 4);
        last if $tagLen + 18 > $size;
        my $valLen = $size - 8 - $tagLen;
        if ($tagLen > 0 and $valLen > 0) {
            my $tag = substr($$dataPt, $pos + 8, $tagLen);
            my $valPos = $pos + 8 + $tagLen;
            my ($val, $format) = ReadXtraValue($et, substr($$dataPt, $valPos, $valLen));
            last unless defined $val;
            $val = $$val[0] if @$val == 1;
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            unless ($tagInfo) {
                # generate tag information for unrecognized tags
                my $name = $tag;
                $name =~ s{^WM/}{};
              # $name =~ tr/-_A-Za-z0-9//dc;
                if ($name =~ /^[-\w]+$/) {
                    $tagInfo = { Name => ucfirst($name) };
                    AddTagToTable($tagTablePtr, $tag, $tagInfo);
                    $et->VPrint(0, $$et{INDENT}, "[adding Microsoft:$tag]\n");
                }
            }
            my $count = ref $val ? scalar @$val : 1;
            $et->HandleTag($tagTablePtr, $tag, $val,
                TagInfo => $tagInfo,
                DataPt  => $dataPt,
                DataPos => $dataPos,
                Start   => $valPos,
                Size    => $valLen,
                Format  => $format,
                Extra   => " count=$count",
            );
        }
        $pos += $size;  # step to next entry
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Microsoft - Definitions for custom Microsoft tags

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Microsoft-specific EXIF and XMP tags, and routines to read/write Microsoft
Xtra tags in videos.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://research.microsoft.com/en-us/um/redmond/groups/ivm/hdview/hdmetadataspec.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Microsoft Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

