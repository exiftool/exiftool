#------------------------------------------------------------------------------
# File:         MIE.pm
#
# Description:  Read/write MIE meta information
#
# Revisions:    11/18/2005 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MIE;

use strict;
use vars qw($VERSION %tableDefaults);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '1.55';

sub ProcessMIE($$);
sub ProcessMIEGroup($$$);
sub WriteMIEGroup($$$);
sub CheckMIE($$$);
sub GetLangInfo($$);

# local variables
my $hasZlib;        # 1=Zlib available, 0=no Zlib
my %mieCode;        # reverse lookup for MIE format names
my $doneMieMap;     # flag indicating we added user-defined groups to %mieMap

# MIE format codes
my %mieFormat = (
    0x00 => 'undef',
    0x10 => 'MIE',
    0x18 => 'MIE',
    0x20 => 'string', # ASCII (ISO 8859-1)
    0x28 => 'utf8',
    0x29 => 'utf16',
    0x2a => 'utf32',
    0x30 => 'string_list',
    0x38 => 'utf8_list',
    0x39 => 'utf16_list',
    0x3a => 'utf32_list',
    0x40 => 'int8u',
    0x41 => 'int16u',
    0x42 => 'int32u',
    0x43 => 'int64u',
    0x48 => 'int8s',
    0x49 => 'int16s',
    0x4a => 'int32s',
    0x4b => 'int64s',
    0x52 => 'rational32u',
    0x53 => 'rational64u',
    0x5a => 'rational32s',
    0x5b => 'rational64s',
    0x61 => 'fixed16u',
    0x62 => 'fixed32u',
    0x69 => 'fixed16s',
    0x6a => 'fixed32s',
    0x72 => 'float',
    0x73 => 'double',
    0x80 => 'free',
);

# map of MIE directory locations
my %mieMap = (
   'MIE-Meta'       => 'MIE',
   'MIE-Audio'      => 'MIE-Meta',
   'MIE-Camera'     => 'MIE-Meta',
   'MIE-Doc'        => 'MIE-Meta',
   'MIE-Geo'        => 'MIE-Meta',
   'MIE-Image'      => 'MIE-Meta',
   'MIE-MakerNotes' => 'MIE-Meta',
   'MIE-Preview'    => 'MIE-Meta',
   'MIE-Thumbnail'  => 'MIE-Meta',
   'MIE-Video'      => 'MIE-Meta',
   'MIE-Flash'      => 'MIE-Camera',
   'MIE-Lens'       => 'MIE-Camera',
   'MIE-Orient'     => 'MIE-Camera',
   'MIE-Extender'   => 'MIE-Lens',
   'MIE-GPS'        => 'MIE-Geo',
   'MIE-UTM'        => 'MIE-Geo',
   'MIE-Canon'      => 'MIE-MakerNotes',
    EXIF            => 'MIE-Meta',
    XMP             => 'MIE-Meta',
    IPTC            => 'MIE-Meta',
    ICC_Profile     => 'MIE-Meta',
    ID3             => 'MIE-Meta',
    CanonVRD        => 'MIE-Canon',
    IFD0            => 'EXIF',
    IFD1            => 'IFD0',
    ExifIFD         => 'IFD0',
    GPS             => 'IFD0',
    SubIFD          => 'IFD0',
    GlobParamIFD    => 'IFD0',
    PrintIM         => 'IFD0',
    InteropIFD      => 'ExifIFD',
    MakerNotes      => 'ExifIFD',
);

# convenience variables for common tagInfo entries
my %binaryConv = (
    Writable => 'undef',
    Binary => 1,
);
my %dateInfo = (
    Shift => 'Time',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val)',
);
my %noYes = ( 0 => 'No', 1 => 'Yes' );
my %offOn = ( 0 => 'Off', 1 => 'On' );

# default entries for MIE tag tables
%tableDefaults = (
    PROCESS_PROC => \&ProcessMIE,
    WRITE_PROC   => \&ProcessMIE,
    CHECK_PROC   => \&CheckMIE,
    LANG_INFO    => \&GetLangInfo,
    WRITABLE     => 'string',
    PREFERRED    => 1,
);

# MIE info
%Image::ExifTool::MIE::Main = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Main' },
    WRITE_GROUP => 'MIE-Main',
    NOTES => q{
        MIE is a flexible format which may be used as a stand-alone meta information
        format, for encapsulation of other files and information, or as a trailer
        appended to other file formats.  The tables below represent currently
        defined MIE tags, however ExifTool will also extract any other information
        present in a MIE file.

        When writing MIE information, some special features are supported:

        1) String values may be written as ASCII (ISO 8859-1) or UTF-8.  ExifTool
        automatically detects the presence of wide characters and treats the string
        appropriately. Internally, UTF-8 text may be converted to UTF-16 or UTF-32
        and stored in this format in the file if it is more compact.

        2) All MIE string-value tags support localized text.  Localized values are
        written by adding a language/country code to the tag name in the form
        C<TAG-xx_YY>, where C<TAG> is the tag name, C<xx> is a 2-character lower
        case ISO 639-1 language code, and C<YY> is a 2-character upper case ISO
        3166-1 alpha 2 country code (eg. C<Title-en_US>).  But as usual, the user
        interface is case-insensitive, and ExifTool will write the correct case to
        the file.

        3) Some numerical MIE tags allow units of measurement to be specified.  For
        these tags, units may be added in brackets immediately following the value
        (eg. C<55(mi/h)>).  If no units are specified, the default units are
        written.

        4) ExifTool writes compressed metadata to MIE files if the L<Compress|../ExifTool.html#Compress> (-z)
        option is used and Compress::Zlib is available.

        See L<https://exiftool.org/MIE1.1-20070121.pdf> for the official MIE
        specification.
    },
   '0Type' => {
        Name => 'SubfileType',
        Notes => q{
            the capitalized common extension for this type of file.  If the extension
            has a dot-3 abbreviation, then the longer version is used here. For
            instance, JPEG and TIFF are used, not JPG and TIF
        },
    },
   '0Vers' => {
        Name => 'MIEVersion',
        Notes => 'version 1.1 is assumed if not specified',
    },
   '1Directory' => {
        Name => 'SubfileDirectory',
        Notes => 'original directory for the file',
    },
   '1Name'      => {
        Name => 'SubfileName',
        Notes => 'the file name, including extension if it exists',
    },
   '2MIME'      => { Name => 'SubfileMIMEType' },
    Meta => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Meta',
            DirName => 'MIE-Meta',
        },
    },
    data => {
        Name => 'SubfileData',
        Notes => 'the subfile data',
        %binaryConv,
    },
    rsrc => {
        Name => 'SubfileResource',
        Notes => 'subfile resource fork if it exists',
        %binaryConv,
    },
    zmd5 => {
        Name => 'MD5Digest',
        Notes => q{
            16-byte MD5 digest written in binary form or as a 32-character hex-encoded
            ASCII string. Value is an MD5 digest of the entire 0MIE group as it would be
            with the digest value itself set to all null bytes
        },
    },
    zmie => {
        Name => 'TrailerSignature',
        Writable => 'undef',
        Notes => q{
            used as the last element in the main "0MIE" group to identify a MIE trailer
            when appended to another type of file.  ExifTool will create this tag if set
            to any value, but always with an empty data block
        },
        ValueConvInv => '""',   # data block must be empty
    },
);

# MIE meta information group
%Image::ExifTool::MIE::Meta = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Meta', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Meta',
    Audio => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Audio',
            DirName => 'MIE-Audio',
        },
    },
    Camera => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Camera',
            DirName => 'MIE-Camera',
        },
    },
    Document => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Doc',
            DirName => 'MIE-Doc',
        },
    },
    EXIF => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    Geo => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Geo',
            DirName => 'MIE-Geo',
        },
    },
    ICCProfile  => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
    ID3  => { SubDirectory => { TagTable => 'Image::ExifTool::ID3::Main' } },
    IPTC => { SubDirectory => { TagTable => 'Image::ExifTool::IPTC::Main' } },
    Image => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Image',
            DirName => 'MIE-Image',
        },
    },
    MakerNotes => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::MakerNotes',
            DirName => 'MIE-MakerNotes',
        },
    },
    Preview => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Preview',
            DirName => 'MIE-Preview',
        },
    },
    Thumbnail => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Thumbnail',
            DirName => 'MIE-Thumbnail',
        },
    },
    Video => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Video',
            DirName => 'MIE-Video',
        },
    },
    XMP => { SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' } },
);

# MIE document information
%Image::ExifTool::MIE::Doc = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Doc', 2 => 'Document' },
    WRITE_GROUP => 'MIE-Doc',
    NOTES => 'Information describing the main document, image or file.',
    Author      => { Groups => { 2 => 'Author' } },
    Comment     => { },
    Contributors=> { Groups => { 2 => 'Author' }, List => 1 },
    Copyright   => { Groups => { 2 => 'Author' } },
    CreateDate  => { Groups => { 2 => 'Time' }, %dateInfo },
    EMail       => { Name => 'Email', Groups => { 2 => 'Author' } },
    Keywords    => { List => 1 },
    ModifyDate  => { Groups => { 2 => 'Time' }, %dateInfo },
    OriginalDate=> {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        %dateInfo,
    },
    Phone       => { Name => 'PhoneNumber', Groups => { 2 => 'Author' } },
    References  => { List => 1 },
    Software    => { },
    Title       => { },
    URL         => { },
);

# MIE geographic information
%Image::ExifTool::MIE::Geo = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Geo', 2 => 'Location' },
    WRITE_GROUP => 'MIE-Geo',
    NOTES => 'Information related to geographic location.',
    Address     => { },
    City        => { },
    Country     => { },
    GPS => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::GPS',
            DirName => 'MIE-GPS',
        },
    },
    PostalCode  => { },
    State       => { Notes => 'state or province' },
    UTM => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::UTM',
            DirName => 'MIE-UTM',
        },
    },
);

# MIE GPS information
%Image::ExifTool::MIE::GPS = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-GPS', 2 => 'Location' },
    WRITE_GROUP => 'MIE-GPS',
    Altitude   => {
        Name => 'GPSAltitude',
        Writable => 'rational64s',
        Units => [ qw(m ft) ],
        Notes => q{'m' above sea level unless 'ft' specified},
    },
    Bearing => {
        Name => 'GPSDestBearing',
        Writable => 'rational64s',
        Units => [ qw(deg deg{mag}) ],
        Notes => q{'deg' CW from true north unless 'deg{mag}' specified},
    },
    Datum   => { Name => 'GPSMapDatum', Notes => 'WGS-84 assumed if not specified' },
    Differential => {
        Name => 'GPSDifferential',
        Writable => 'int8u',
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
    Distance => {
        Name => 'GPSDestDistance',
        Writable => 'rational64s',
        Units => [ qw(km mi nmi) ],
        Notes => q{'km' unless 'mi' or 'nmi' specified},
    },
    Heading  => {
        Name => 'GPSTrack',
        Writable => 'rational64s',
        Units => [ qw(deg deg{mag}) ],
        Notes => q{'deg' CW from true north unless 'deg{mag}' specified},
    },
    Latitude => {
        Name => 'GPSLatitude',
        Writable => 'rational64s',
        Count => -1,
        Notes => q{
            1 to 3 numbers: degrees, minutes then seconds.  South latitudes are stored
            as all negative numbers, but may be entered as positive numbers with a
            trailing 'S' for convenience.  For example, these are all equivalent: "-40
            -30", "-40.5", "40 30 0.00 S"
        },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val, 3)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lat")',
    },
    Longitude => {
        Name => 'GPSLongitude',
        Writable => 'rational64s',
        Count => -1,
        Notes => q{
            1 to 3 numbers: degrees, minutes then seconds.  West longitudes are
            negative, but may be entered as positive numbers with a trailing 'W'
        },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val, 3)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
        PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lon")',
    },
    MeasureMode => {
        Name => 'GPSMeasureMode',
        Writable => 'int8u',
        PrintConv => { 2 => '2-D', 3 => '3-D' },
    },
    Satellites => 'GPSSatellites',
    Speed => {
        Name => 'GPSSpeed',
        Writable => 'rational64s',
        Units => [ qw(km/h mi/h m/s kn) ],
        Notes => q{'km/h' unless 'mi/h', 'm/s' or 'kn' specified},
    },
    DateTime => { Name => 'GPSDateTime', Groups => { 2 => 'Time' }, %dateInfo },
);

# MIE UTM information
%Image::ExifTool::MIE::UTM = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-UTM', 2 => 'Location' },
    WRITE_GROUP => 'MIE-UTM',
    Datum    => { Name => 'UTMMapDatum', Notes => 'WGS-84 assumed if not specified' },
    Easting  => { Name => 'UTMEasting' },
    Northing => { Name => 'UTMNorthing' },
    Zone     => { Name => 'UTMZone', Writable => 'int8s' },
);

# MIE image information
%Image::ExifTool::MIE::Image = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Image', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Image',
   '0Type'          => { Name => 'FullSizeImageType', Notes => 'JPEG if not specified' },
   '1Name'          => { Name => 'FullSizeImageName' },
    BitDepth        => { Name => 'BitDepth', Writable => 'int16u' },
    ColorSpace      => { Notes => 'standard ColorSpace values are "sRGB" and "Adobe RGB"' },
    Components      => {
        Name => 'ComponentsConfiguration',
        Notes => 'string composed of R, G, B, Y, Cb and Cr',
    },
    Compression     => { Name => 'CompressionRatio', Writable => 'rational32u' },
    OriginalImageSize => { # PH added 2022-09-28
        Writable => 'int16u',
        Count => -1,
        Notes => 'size of original image before cropping',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    ImageSize       => {
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    Resolution      => {
        Writable => 'rational64u',
        Units => [ qw(/in /cm /deg /arcmin /arcsec), '' ],
        Count => -1,
        Notes => q{
            1 to 3 values.  A single value for equal resolution in all directions, or
            separate X, Y and Z values if necessary.  Units are '/in' unless '/cm',
            '/deg', '/arcmin', '/arcsec' or '' specified
        },
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'FullSizeImage',
        Groups => { 2 => 'Preview' },
        %binaryConv,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE preview image
%Image::ExifTool::MIE::Preview = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Preview', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Preview',
   '0Type'  => { Name => 'PreviewImageType', Notes => 'JPEG if not specified' },
   '1Name'  => { Name => 'PreviewImageName' },
    ImageSize => {
        Name => 'PreviewImageSize',
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        %binaryConv,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE thumbnail image
%Image::ExifTool::MIE::Thumbnail = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Thumbnail', 2 => 'Image' },
    WRITE_GROUP => 'MIE-Thumbnail',
   '0Type'  => { Name => 'ThumbnailImageType', Notes => 'JPEG if not specified' },
   '1Name'  => { Name => 'ThumbnailImageName' },
    ImageSize => {
        Name => 'ThumbnailImageSize',
        Writable => 'int16u',
        Count => -1,
        Notes => '2 or 3 values, for number of XY or XYZ pixels',
        PrintConv => '$val=~tr/ /x/;$val',
        PrintConvInv => '$val=~tr/x/ /;$val',
    },
    data => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        %binaryConv,
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# MIE audio information
%Image::ExifTool::MIE::Audio = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Audio', 2 => 'Audio' },
    WRITE_GROUP => 'MIE-Audio',
    NOTES => q{
        For the Audio group (and any other group containing a 'data' element), tags
        refer to the contained data if present, otherwise they refer to the main
        SubfileData.  The C<0Type> and C<1Name> elements should exist only if C<data>
        is present.
    },
   '0Type'      => { Name => 'RelatedAudioFileType', Notes => 'MP3 if not specified' },
   '1Name'      => { Name => 'RelatedAudioFileName' },
    SampleBits  => { Writable => 'int16u' },
    Channels    => { Writable => 'int8u' },
    Compression => { Name => 'AudioCompression' },
    Duration    => { Writable => 'rational64u', PrintConv => 'ConvertDuration($val)' },
    SampleRate  => { Writable => 'int32u' },
    data        => { Name => 'RelatedAudioFile', %binaryConv },
);

# MIE video information
%Image::ExifTool::MIE::Video = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Video', 2 => 'Video' },
    WRITE_GROUP => 'MIE-Video',
   '0Type'      => { Name => 'RelatedVideoFileType', Notes => 'MOV if not specified' },
   '1Name'      => { Name => 'RelatedVideoFileName' },
    Codec       => { },
    Duration    => { Writable => 'rational64u', PrintConv => 'ConvertDuration($val)' },
    data        => { Name => 'RelatedVideoFile', %binaryConv },
);

# MIE camera information
%Image::ExifTool::MIE::Camera = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Camera', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Camera',
    Brightness      => { Writable => 'int8s' },
    ColorTemperature=> { Writable => 'int32u' },
    ColorBalance    => {
        Writable => 'rational64u',
        Count => 3,
        Notes => 'RGB scaling factors',
    },
    Contrast        => { Writable => 'int8s' },
    DigitalZoom     => { Writable => 'rational64u' },
    ExposureComp    => { Name => 'ExposureCompensation', Writable => 'rational64s' },
    ExposureMode    => { },
    ExposureTime    => {
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
    },
    Flash => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Flash',
            DirName => 'MIE-Flash',
        },
    },
    FirmwareVersion => { },
    FocusMode       => { },
    ISO             => { Writable => 'int16u' },
    ISOSetting      => {
        Writable => 'int16u',
        Notes => '0 = Auto, otherwise manual ISO speed setting',
    },
    ImageNumber     => { Writable => 'int32u' },
    ImageQuality    => { Notes => 'Economy, Normal, Fine, Super Fine or Raw' },
    ImageStabilization => { Writable => 'int8u', %offOn },
    Lens => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Lens',
            DirName => 'MIE-Lens',
        },
    },
    Make            => { },
    MeasuredEV      => { Writable => 'rational64s' },
    Model           => { },
    OwnerName       => { },
    Orientation     => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Orient',
            DirName => 'MIE-Orient',
        },
    },
    Saturation      => { Writable => 'int8s' },
    SensorSize      => {
        Writable => 'rational64u',
        Count => 2,
        Notes => 'width and height of active sensor area in mm',
    },
    SerialNumber    => { },
    Sharpness       => { Writable => 'int8s' },
    ShootingMode    => { },
);

# Camera orientation information
%Image::ExifTool::MIE::Orient = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Orient', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Orient',
    NOTES => 'These tags describe the camera orientation.',
    Azimuth     => {
        Writable => 'rational64s',
        Units => [ qw(deg deg{mag}) ],
        Notes => q{'deg' CW from true north unless 'deg{mag}' specified},
    },
    Declination => { Writable => 'rational64s' },
    Elevation   => { Writable => 'rational64s' },
    RightAscension => { Writable => 'rational64s' },
    Rotation => {
        Writable => 'rational64s',
        Notes => 'CW rotation angle of camera about lens axis',
    },
);

# MIE camera lens information
%Image::ExifTool::MIE::Lens = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Lens', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Lens',
    NOTES => q{
        All recorded lens parameters (focal length, aperture, etc) include the
        effects of the extender if present.
    },
    Extender => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Extender',
            DirName => 'MIE-Extender',
        },
    },
    FNumber         => { Writable => 'rational64u' },
    FocalLength     => { Writable => 'rational64u', Notes => 'all focal lengths in mm' },
    FocusDistance   => {
        Writable => 'rational64u',
        Units => [ qw(m ft) ],
        Notes => q{'m' unless 'ft' specified},
    },
    Make            => { Name => 'LensMake' },
    MaxAperture     => { Writable => 'rational64u' },
    MaxApertureAtMaxFocal => { Writable => 'rational64u' },
    MaxFocalLength  => { Writable => 'rational64u' },
    MinAperture     => { Writable => 'rational64u' },
    MinFocalLength  => { Writable => 'rational64u' },
    Model           => { Name => 'LensModel' },
    OpticalZoom     => { Writable => 'rational64u' },
    SerialNumber    => { Name => 'LensSerialNumber' },
);

# MIE lens extender information
%Image::ExifTool::MIE::Extender = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Extender', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Extender',
    Magnification   => { Name => 'ExtenderMagnification', Writable => 'rational64s' },
    Make            => { Name => 'ExtenderMake' },
    Model           => { Name => 'ExtenderModel' },
    SerialNumber    => { Name => 'ExtenderSerialNumber' },
);

# MIE camera flash information
%Image::ExifTool::MIE::Flash = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Flash', 2 => 'Camera' },
    WRITE_GROUP => 'MIE-Flash',
    ExposureComp    => { Name => 'FlashExposureComp', Writable => 'rational64s' },
    Fired           => { Name => 'FlashFired', Writable => 'int8u', PrintConv => \%noYes },
    GuideNumber     => { Name => 'FlashGuideNumber' },
    Make            => { Name => 'FlashMake' },
    Mode            => { Name => 'FlashMode' },
    Model           => { Name => 'FlashModel' },
    SerialNumber    => { Name => 'FlashSerialNumber' },
    Type            => { Name => 'FlashType', Notes => '"Internal" or "External"' },
);

# MIE maker notes information
%Image::ExifTool::MIE::MakerNotes = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-MakerNotes' },
    WRITE_GROUP => 'MIE-MakerNotes',
    NOTES => q{
        MIE maker notes are contained within separate groups for each manufacturer
        to avoid name conflicts.
    },
    Canon => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::MIE::Canon',
            DirName => 'MIE-Canon',
        },
    },
    Casio       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    FujiFilm    => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Kodak       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    KonicaMinolta=>{ SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Nikon       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Olympus     => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Panasonic   => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Pentax      => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Ricoh       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Sigma       => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
    Sony        => { SubDirectory => { TagTable => 'Image::ExifTool::MIE::Unknown' } },
);

# MIE Canon-specific information
%Image::ExifTool::MIE::Canon = (
    %tableDefaults,
    GROUPS => { 1 => 'MIE-Canon' },
    WRITE_GROUP => 'MIE-Canon',
    VRD => {
        Name => 'CanonVRD',
        SubDirectory => { TagTable => 'Image::ExifTool::CanonVRD::Main' },
    },
);

%Image::ExifTool::MIE::Unknown = (
    PROCESS_PROC => \&ProcessMIE,
    GROUPS => { 1 => 'MIE-Unknown' },
);

#------------------------------------------------------------------------------
# Add user-defined MIE groups to %mieMap
# Inputs: none;  Returns: nothing, but sets $doneMieMap flag
sub UpdateMieMap()
{
    $doneMieMap = 1;    # set flag so we only do this once
    return unless %Image::ExifTool::UserDefined;
    my ($tableName, @tables, %doneTable, $tagID);
    # get list of top-level MIE tables with user-defined tags
    foreach $tableName (keys %Image::ExifTool::UserDefined) {
        next unless $tableName =~ /^Image::ExifTool::MIE::/;
        my $userTable = $Image::ExifTool::UserDefined{$tableName};
        my $tagTablePtr = GetTagTable($tableName) or next;
        # copy the WRITE_GROUP from the actual table
        $$userTable{WRITE_GROUP} = $$tagTablePtr{WRITE_GROUP};
        # add to list of tables to process
        $doneTable{$tableName} = 1;
        push @tables, [$tableName, $userTable];
    }
    # recursively add all user-defined groups to MIE map
    while (@tables) {
        my ($tableName, $tagTablePtr) = @{shift @tables};
        my $parent = $$tagTablePtr{WRITE_GROUP};
        $parent or warn("No WRITE_GROUP for $tableName\n"), next;
        $mieMap{$parent} or warn("$parent is not in MIE map\n"), next;
        foreach $tagID (TagTableKeys($tagTablePtr)) {
            my $tagInfo = $$tagTablePtr{$tagID};
            next unless ref $tagInfo eq 'HASH' and $$tagInfo{SubDirectory};
            my $subTableName = $tagInfo->{SubDirectory}->{TagTable};
            my $subTablePtr = GetTagTable($subTableName) or next;
            # only care about MIE tables
            next unless $$subTablePtr{PROCESS_PROC} and
                        $$subTablePtr{PROCESS_PROC} eq \&ProcessMIE;
            my $group = $$subTablePtr{WRITE_GROUP};
            $group or warn("No WRITE_GROUP for $subTableName\n"), next;
            if ($mieMap{$group} and $mieMap{$group} ne $parent) {
                warn("$group already has different parent ($mieMap{$group})\n"), next;
            }
            $mieMap{$group} = $parent;  # add to map
            # process tables within this one too
            $doneTable{$subTableName} and next;
            $doneTable{$subTableName} = 1;
            push @tables, [$subTableName, $subTablePtr];
        }
    }
}

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash
# Inputs: 0) tagInfo hash ref, 1) locale code (eg. "en_CA")
# Returns: new tagInfo hash ref, or undef if invalid
sub GetLangInfo($$)
{
    my ($tagInfo, $langCode) = @_;
    # check for properly formatted language code
    return undef unless $langCode =~ /^[a-z]{2}([-_])[A-Z]{2}$/;
    # use '_' as a separator, but recognize '_' or '-'
    $langCode =~ tr/-/_/ if $1 eq '-';
    # can only set locale on string types
    return undef if $$tagInfo{Writable} and $$tagInfo{Writable} ne 'string';
    return Image::ExifTool::GetLangInfo($tagInfo, $langCode);
}

#------------------------------------------------------------------------------
# return true if we have Zlib::Compress
# Inputs: 0) ExifTool object ref, 1) verb for what you want to do with the info
# Returns: 1 if Zlib available, 0 otherwise
sub HasZlib($$)
{
    unless (defined $hasZlib) {
        $hasZlib = eval { require Compress::Zlib };
        unless ($hasZlib) {
            $hasZlib = 0;
            $_[0]->Warn("Install Compress::Zlib to $_[1] compressed information");
        }
    }
    return $hasZlib;
}

#------------------------------------------------------------------------------
# Get format code for MIE group element with current byte order
# Inputs: 0) [optional] true to convert result to chr()
# Returns: format code
sub MIEGroupFormat(;$)
{
    my $chr = shift;
    my $format = GetByteOrder() eq 'MM' ? 0x10 : 0x18;
    return $chr ? chr($format) : $format;
}

#------------------------------------------------------------------------------
# ReadValue() with added support for UTF formats (utf8, utf16 and utf32)
# Inputs: 0) data reference, 1) value offset, 2) format string,
#         3) number of values (or undef to use all data)
#         4) valid data length relative to offset, 5) returned rational ref
# Returns: converted value, or undefined if data isn't there
#          or list of values in list context
# Notes: all string formats are converted to UTF8
sub ReadMIEValue($$$$$;$)
{
    my ($dataPt, $offset, $format, $count, $size, $ratPt) = @_;
    my $val;
    if ($format =~ /^(utf(8|16|32)|string)/) {
        if ($1 eq 'utf8' or $1 eq 'string') {
            # read the 8-bit string
            $val = substr($$dataPt, $offset, $size);
            # (as of ExifTool 7.62, leave string values unconverted)
        } else {
            # convert to UTF8
            my $fmt;
            if (GetByteOrder() eq 'MM') {
                $fmt = ($1 eq 'utf16') ? 'n' : 'N';
            } else {
                $fmt = ($1 eq 'utf16') ? 'v' : 'V';
            }
            my @unpk = unpack("x$offset$fmt$size",$$dataPt);
            if ($] >= 5.006001) {
                $val = pack('C0U*', @unpk);
            } else {
                $val = Image::ExifTool::PackUTF8(@unpk);
            }
        }
        # truncate at null unless this is a list
        # (strings shouldn't have a null, but just in case)
        $val =~ s/\0.*//s unless $format =~ /_list$/;
    } else {
        $format = 'undef' if $format eq 'free'; # read 'free' as 'undef'
        return ReadValue($dataPt, $offset, $format, $count, $size, $ratPt);
    }
    return $val;
}

#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool object ref, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string or undef (and possibly changes value) on success
sub CheckMIE($$$)
{
    my ($et, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Writable} || $tagInfo->{Table}->{WRITABLE};
    my $err;

    return 'No writable format' if not $format or $format eq '1';
    # handle units if supported by this tag
    my $ulist = $$tagInfo{Units};
    if ($ulist and $$valPtr =~ /(.*)\((.*)\)$/) {
        my ($val, $units) = ($1, $2);
        ($units) = grep /^$units$/i, @$ulist;
        defined $units or return 'Allowed units: (' . join('|', @$ulist) . ')';
        $err = Image::ExifTool::CheckValue(\$val, $format, $$tagInfo{Count});
        # add units back onto value
        $$valPtr = "$val($units)" unless $err;
    } elsif ($format !~ /^(utf|string|undef)/ and $$valPtr =~ /\)$/) {
        return 'Units not supported';
    } else {
        if ($format eq 'string' and $$et{OPTIONS}{Charset} ne 'UTF8' and
            $$valPtr =~ /[\x80-\xff]/)
        {
            # convert from Charset to UTF-8
            $$valPtr = $et->Encode($$valPtr,'UTF8');
        }
        $err = Image::ExifTool::CheckValue($valPtr, $format, $$tagInfo{Count});
    }
    return $err;
}

#------------------------------------------------------------------------------
# Rewrite a MIE directory
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ptr
# Returns: undef on success, otherwise error message (empty message if nothing to write)
sub WriteMIEGroup($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $dirName = $$dirInfo{DirName};
    my $toWrite = $$dirInfo{ToWrite} || '';
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $optCompress = $et->Options('Compress');
    my $out = $et->Options('TextOut');
    my ($msg, $err, $ok, $sync, $delGroup);
    my $tag = '';
    my $deletedTag = '';

    # count each MIE directory found and make name for this specific instance
    my ($grp1, %isWriting);
    my $cnt = $$et{MIE_COUNT};
    my $grp = $tagTablePtr->{GROUPS}->{1};
    my $n = $$cnt{'MIE-Main'} || 0;
    if ($grp eq 'MIE-Main') {
        $$cnt{$grp} = ++$n;
        ($grp1 = $grp) =~ s/MIE-/MIE$n-/;
    } else {
        ($grp1 = $grp) =~ s/MIE-/MIE$n-/;
        my $m = $$cnt{$grp1} = ($$cnt{$grp1} || 0) + 1;
        $isWriting{"$grp$m"} = 1;   # eg. 'MIE-Doc2'
        $isWriting{$grp1} = 1;      # eg. 'MIE1-Doc'
        $grp1 .= $m;
    }
    # build lookup for all valid group names for this MIE group
    $isWriting{$grp} = 1;           # eg. 'MIE-Doc'
    $isWriting{$grp1} = 1;          # eg. 'MIE1-Doc2'
    $isWriting{"MIE$n"} = 1;        # eg. 'MIE1'

    # determine if we are deleting this group
    if (%{$$et{DEL_GROUP}}) {
        $delGroup = 1 if $$et{DEL_GROUP}{MIE} or
                         $$et{DEL_GROUP}{$grp} or
                         $$et{DEL_GROUP}{$grp1} or
                         $$et{DEL_GROUP}{"MIE$n"};
    }

    # prepare lookups and lists for writing
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    my ($addDirs, $editDirs) = $et->GetAddDirHash($tagTablePtr, $dirName);
    my @editTags = sort keys %$newTags, keys %$editDirs;
    $verbose and print $out $raf ? 'Writing' : 'Creating', " $grp1:\n";

    # loop through elements in MIE group
    MieElement: for (;;) {
        my ($format, $tagLen, $valLen, $units, $oldHdr, $buff);
        my $lastTag = $tag;
        if ($raf) {
            # read first 4 bytes of element header
            my $n = $raf->Read($oldHdr, 4);
            if ($n != 4) {
                last if $n or defined $sync;
                undef $raf; # all done reading
                $ok = 1;
            }
        }
        if ($raf) {
            ($sync, $format, $tagLen, $valLen) = unpack('aC3', $oldHdr);
            $sync eq '~' or $msg = 'Invalid sync byte', last;

            # read tag name
            if ($tagLen) {
                $raf->Read($tag, $tagLen) == $tagLen or last;
                $oldHdr .= $tag;    # add tag to element header
                $et->Warn("MIE tag '${tag}' out of sequence") if $tag lt $lastTag;
                # separate units from tag name if they exist
                $units = $1 if $tag =~ s/\((.*)\)$//;
            } else {
                $tag = '';
            }

            # get multi-byte value length if necessary
            if ($valLen > 252) {
                # calculate number of bytes in extended DataLength
                my $n = 1 << (256 - $valLen);
                $raf->Read($buff, $n) == $n or last;
                $oldHdr .= $buff;   # add to old header
                my $fmt = 'int' . ($n * 8) . 'u';
                $valLen = ReadValue(\$buff, 0, $fmt, 1, $n);
                if ($valLen > 0x7fffffff) {
                    $msg = "Can't write $tag (DataLength > 2GB not yet supported)";
                    last;
                }
            }
            # don't rewrite free bytes or information in deleted groups
            if ($format == 0x80 or ($delGroup and $tagLen and ($format & 0xf0) != 0x10)) {
                $raf->Seek($valLen, 1) or $msg = 'Seek error', last;
                if ($verbose > 1) {
                    my $free = ($format == 0x80) ? ' free' : '';
                    print $out "    - $grp1:$tag ($valLen$free bytes)\n";
                }
                ++$$et{CHANGED} if $delGroup;
                next;
            }
        } else {
            # no more elements to read
            $tagLen = $valLen = 0;
            $tag = '';
        }
#
# write necessary new tags and process directories
#
        while (@editTags) {
            last if $tagLen and $editTags[0] gt $tag;
            # we are writing the new tag now
            my ($newVal, $writable, $oldVal, $newFormat, $compress);
            my $newTag = shift @editTags;
            length($newTag) > 255 and $et->Warn('Tag name too long'), next; # (just to be safe)
            my $newInfo = $$editDirs{$newTag};
            if ($newInfo) {
                # create the new subdirectory or rewrite existing non-MIE directory
                my $subTablePtr = GetTagTable($newInfo->{SubDirectory}->{TagTable});
                unless ($subTablePtr) {
                    $et->Warn("No tag table for $newTag $$newInfo{Name}");
                    next;
                }
                my %subdirInfo;
                my $isMieGroup = ($$subTablePtr{WRITE_PROC} and
                                  $$subTablePtr{WRITE_PROC} eq \&ProcessMIE);

                if ($newTag eq $tag) {
                    # make sure that either both or neither old and new tags are MIE groups
                    if ($isMieGroup xor ($format & 0xf3) == 0x10) {
                        $et->Warn("Tag '${tag}' not expected type");
                        next;   # don't write our new tag
                    }
                    # uncompress existing directory into $oldVal since we are editing it
                    if ($format & 0x04) {
                        last unless HasZlib($et, 'edit');
                        $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        my $stat;
                        my $inflate = Compress::Zlib::inflateInit();
                        $inflate and ($oldVal, $stat) = $inflate->inflate($oldVal);
                        unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                            $msg = "Error inflating $tag";
                            last MieElement;
                        }
                        $compress = 1;
                        $valLen = length $oldVal;    # uncompressed value length
                    }
                } else {
                    # don't create this directory unless necessary
                    next unless $$addDirs{$newTag};
                }

                if ($isMieGroup) {
                    my $hdr;
                    if ($newTag eq $tag) {
                        # rewrite existing directory later unless it was compressed
                        last unless $compress;
                        # rewrite directory to '$newVal'
                        $newVal = '';
                        %subdirInfo = (
                            OutFile => \$newVal,
                            RAF => File::RandomAccess->new(\$oldVal),
                        );
                    } elsif ($optCompress and not $$dirInfo{IsCompressed}) {
                        # write to memory so we can compress the new MIE group
                        $compress = 1;
                        %subdirInfo = (
                            OutFile => \$newVal,
                        );
                    } else {
                        $hdr = '~' . MIEGroupFormat(1) . chr(length($newTag)) .
                               "\0" . $newTag;
                        %subdirInfo = (
                            OutFile => $outfile,
                            ToWrite => $toWrite . $hdr,
                        );
                    }
                    $subdirInfo{DirName} = $newInfo->{SubDirectory}->{DirName} || $newTag;
                    $subdirInfo{Parent} = $dirName;
                    # don't compress elements of an already compressed group
                    $subdirInfo{IsCompressed} = $$dirInfo{IsCompressed} || $compress;
                    $msg = WriteMIEGroup($et, \%subdirInfo, $subTablePtr);
                    last MieElement if $msg;
                    # message is defined but empty if nothing was written
                    if (defined $msg) {
                        undef $msg; # not a problem if nothing was written
                        next;
                    } elsif (not $compress) {
                        # group was written already
                        $toWrite = '';
                        next;
                    } elsif (length($newVal) <= 4) {    # terminator only?
                        $verbose and print $out "Deleted compressed $grp1 (empty)\n";
                        next MieElement if $newTag eq $tag; # deleting the directory
                        next;       # not creating the new directory
                    }
                    $writable = 'undef';
                    $newFormat = MIEGroupFormat();
                } else {
                    if ($newTag eq $tag) {
                        unless ($compress) {
                            # read and edit existing directory
                            $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        }
                        %subdirInfo = (
                            DataPt  => \$oldVal,
                            DataLen => $valLen,
                            DirName => $$newInfo{Name},
                            DataPos => $$dirInfo{IsCompressed} ? undef : $raf->Tell() - $valLen,
                            DirStart=> 0,
                            DirLen  => $valLen,
                        );
                        # write Compact subdirectories if we will compress the data
                        if (($compress or $optCompress or $$dirInfo{IsCompressed}) and
                            eval { require Compress::Zlib })
                        {
                            $subdirInfo{Compact} = 1;
                            $subdirInfo{ReadOnly} = 1;  # because XMP is not writable in place
                        }
                    }
                    $subdirInfo{Parent} = $dirName;
                    my $writeProc = $newInfo->{SubDirectory}->{WriteProc};
                    # reset processed lookup to avoid errors in case of multiple EXIF blocks
                    $$et{PROCESSED} = { };
                    $newVal = $et->WriteDirectory(\%subdirInfo, $subTablePtr, $writeProc);
                    if (defined $newVal) {
                        if ($newVal eq '') {
                            next MieElement if $newTag eq $tag; # deleting the directory
                            next;       # not creating the new directory
                        }
                    } else {
                        next unless defined $oldVal;
                        $newVal = $oldVal;  # just copy over the old directory
                    }
                    $writable = 'undef';
                    $newFormat = 0x00;  # all other directories are 'undef' format
                }
            } else {

                # get the new tag information
                $newInfo = $$newTags{$newTag};
                my $nvHash = $et->GetNewValueHash($newInfo);
                my @newVals;

                # write information only to specified group
                my $writeGroup = $$nvHash{WriteGroup};
                last unless $isWriting{$writeGroup};

                # if tag existed, must decide if we want to overwrite the value
                if ($newTag eq $tag) {
                    my $isOverwriting;
                    my $isList = $$newInfo{List};
                    if ($isList) {
                        last if $$nvHash{CreateOnly};
                        $isOverwriting = -1;    # force processing list elements individually
                    } else {
                        $isOverwriting = $et->IsOverwriting($nvHash);
                        last unless $isOverwriting;
                    }
                    my ($val, $cmpVal);
                    if ($isOverwriting < 0 or $verbose > 1) {
                        # check to be sure we can uncompress the value if necessary
                        HasZlib($et, 'edit') or last if $format & 0x04;
                        # read the old value
                        $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        # uncompress if necessary
                        if ($format & 0x04) {
                            my $stat;
                            my $inflate = Compress::Zlib::inflateInit();
                            # must save original compressed value in case we decide
                            # not to overwrite it later
                            $cmpVal = $oldVal;
                            $inflate and ($oldVal, $stat) = $inflate->inflate($oldVal);
                            unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                                $msg = "Error inflating $tag";
                                last MieElement;
                            }
                            $valLen = length $oldVal;    # update value length
                        }
                        # convert according to specified format
                        my $formatStr = $mieFormat{$format & 0xfb} || 'undef';
                        $val = ReadMIEValue(\$oldVal, 0, $formatStr, undef, $valLen);
                        if ($isOverwriting < 0 and defined $val) {
                            # handle list values individually
                            if ($isList) {
                                my (@vals, $v);
                                if ($formatStr =~ /_list$/) {
                                    @vals = split "\0", $val;
                                } else {
                                    @vals = $val;
                                }
                                # keep any list items that we aren't overwriting
                                foreach $v (@vals) {
                                    next if $et->IsOverwriting($nvHash, $v);
                                    push @newVals, $v;
                                }
                            } else {
                                # test to see if we really want to overwrite the value
                                $isOverwriting = $et->IsOverwriting($nvHash, $val);
                            }
                        }
                    }
                    if ($isOverwriting) {
                        # skip the old value if we didn't read it already
                        unless (defined $oldVal) {
                            $raf->Seek($valLen, 1) or $msg = 'Seek error';
                        }
                        if ($verbose > 1) {
                            $val .= "($units)" if defined $units;
                            $et->VerboseValue("- $grp1:$$newInfo{Name}", $val);
                        }
                        $deletedTag = $tag;     # remember that we deleted this tag
                        ++$$et{CHANGED}; # we deleted the old value
                    } else {
                        if (defined $oldVal) {
                            # write original compressed value
                            $oldVal = $cmpVal if defined $cmpVal;
                        } else {
                            $raf->Read($oldVal, $valLen) == $valLen or last MieElement;
                        }
                        # write the old value now
                        Write($outfile, $toWrite, $oldHdr, $oldVal) or $err = 1;
                        $toWrite = '';
                        next MieElement;
                    }
                    unless (@newVals) {
                        # unshift the new tag info to write it later
                        unshift @editTags, $newTag;
                        next MieElement;    # get next element from file
                    }
                } else {
                    # write new value if creating, or if List and list existed, or
                    # if tag was previously deleted
                    next unless $$nvHash{IsCreating} or
                        ($newTag eq $lastTag and ($$newInfo{List} or $deletedTag eq $lastTag));
                }
                # get the new value to write (undef to delete)
                push @newVals, $et->GetNewValue($nvHash);
                next unless @newVals;
                $writable = $$newInfo{Writable} || $$tagTablePtr{WRITABLE};
                if ($writable eq 'string') {
                    # join multiple values into a single string
                    $newVal = join "\0", @newVals;
                    # write string as UTF-8,16 or 32 if value contains valid UTF-8 codes
                    my $isUTF8 = Image::ExifTool::IsUTF8(\$newVal);
                    if ($isUTF8 > 0) {
                        $writable = 'utf8';
                        # write UTF-16 or UTF-32 if it is more compact
                        my $to = $isUTF8 > 1 ? 'UCS4' : 'UCS2';
                        my $tmp = Image::ExifTool::Decode(undef,$newVal,'UTF8',undef,$to);
                        if (length $tmp < length $newVal) {
                            $newVal = $tmp;
                            $writable = ($isUTF8 > 1) ? 'utf32' : 'utf16';
                        }
                    }
                    # write as a list if we have multiple values
                    $writable .= '_list' if @newVals > 1;
                } else {
                    # should only be one element in the list
                    $newVal = shift @newVals;
                }
                $newFormat = $mieCode{$writable};
                unless (defined $newFormat) {
                    $msg = "Bad format '${writable}' for $$newInfo{Name}";
                    next MieElement;
                }
            }

            # write the new or edited element
            while (defined $newFormat) {
                my $valPt = \$newVal;
                # remove units from value and add to tag name if supported by this tag
                if ($$newInfo{Units}) {
                    my $val2;
                    if ($$valPt =~ /(.*)\((.*)\)$/) {
                        $val2 = $1;
                        $newTag .= "($2)";
                    } else {
                        $val2 = $$valPt;
                        # add default units
                        my $ustr = '(' . $newInfo->{Units}->[0] . ')';
                        $newTag .= $ustr;
                        $$valPt .= $ustr;
                    }
                    $valPt = \$val2;
                }
                # convert value if necessary
                if ($writable !~ /^(utf|string|undef)/) {
                    my $val3 = WriteValue($$valPt, $writable, $$newInfo{Count});
                    defined $val3 or $et->Warn("Error writing $newTag"), last;
                    $valPt = \$val3;
                }
                my $len = length $$valPt;
                # compress value before writing if required
                if (($compress or $optCompress) and not $$dirInfo{IsCompressed} and
                    HasZlib($et, 'write'))
                {
                    my $deflate = Compress::Zlib::deflateInit();
                    my $val4;
                    if ($deflate) {
                        $val4 = $deflate->deflate($$valPt);
                        $val4 .= $deflate->flush() if defined $val4;
                    }
                    if (defined $val4) {
                        my $len4 = length $val4;
                        my $saved = $len - $len4;
                        # only use compressed data if it is smaller
                        if ($saved > 0) {
                            $verbose and print $out "  [$newTag compression saved $saved bytes]\n";
                            $newFormat |= 0x04; # set compressed bit
                            $len = $len4;       # set length
                            $valPt = \$val4;    # set value pointer
                        } elsif ($verbose) {
                            print $out "  [$newTag compression saved $saved bytes -- written uncompressed]\n";
                        }
                    } else {
                        $et->Warn("Error deflating $newTag (written uncompressed)");
                    }
                }
                # calculate the DataLength code
                my $extLen;
                if ($len < 253) {
                    $extLen = '';
                } elsif ($len < 65536) {
                    $extLen = Set16u($len);
                    $len = 255;
                } elsif ($len <= 0x7fffffff) {
                    $extLen = Set32u($len);
                    $len = 254;
                } else {
                    $et->Warn("Can't write $newTag (DataLength > 2GB not yet supported)");
                    last; # don't write this tag
                }
                # write this element (with leading MIE group element if not done already)
                my $hdr = $toWrite . '~' . chr($newFormat) . chr(length $newTag);
                Write($outfile, $hdr, chr($len), $newTag, $extLen, $$valPt) or $err = 1;
                $toWrite = '';
                # we changed a tag unless just editing a subdirectory
                unless ($$editDirs{$newTag}) {
                    $et->VerboseValue("+ $grp1:$$newInfo{Name}", $newVal);
                    ++$$et{CHANGED};
                }
                last;   # didn't want to loop anyway
            }
            next MieElement if defined $oldVal;
        }
#
# rewrite existing element or descend into uncompressed MIE group
#
        # all done this MIE group if we reached the terminator element
        unless ($tagLen) {
            # skip over existing terminator data (if any)
            last if $valLen and not $raf->Seek($valLen, 1);
            $ok = 1;
            # write group terminator if necessary
            unless ($toWrite) {
                # write end-of-group terminator element
                my $term = "~\0\0\0";
                unless ($$dirInfo{Parent}) {
                    # write extended terminator for file-level group
                    my $len = ref $outfile eq 'SCALAR' ? length($$outfile) : tell $outfile;
                    $len += 10; # include length of terminator itself
                    if ($len and $len <= 0x7fffffff) {
                        $term = "~\0\0\x06" . Set32u($len) . MIEGroupFormat(1) . "\x04";
                    }
                }
                Write($outfile, $term) or $err = 1;
            }
            last;
        }

        # descend into existing uncompressed MIE group
        if ($format == 0x10 or $format == 0x18) {
            my ($subTablePtr, $dirName);
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $dirName = $tagInfo->{SubDirectory}->{DirName};
                my $subTable = $tagInfo->{SubDirectory}->{TagTable};
                $subTablePtr = $subTable ? GetTagTable($subTable) : $tagTablePtr;
            } else {
                $subTablePtr = GetTagTable('Image::ExifTool::MIE::Unknown');
            }
            my $hdr = '~' . chr($format) . chr(length $tag) . "\0" . $tag;
            my %subdirInfo = (
                DirName => $dirName || $tag,
                RAF     => $raf,
                ToWrite => $toWrite . $hdr,
                OutFile => $outfile,
                Parent  => $dirName,
                IsCompressed => $$dirInfo{IsCompressed},
            );
            my $oldOrder = GetByteOrder();
            SetByteOrder($format & 0x08 ? 'II' : 'MM');
            $msg = WriteMIEGroup($et, \%subdirInfo, $subTablePtr);
            SetByteOrder($oldOrder);
            last if $msg;
            if (defined $msg) {
                undef $msg; # no problem if nothing written
            } else {
                $toWrite = '';
            }
            next;
        }
        # just copy existing element
        my $oldVal;
        $raf->Read($oldVal, $valLen) == $valLen or last;
        if ($toWrite) {
            Write($outfile, $toWrite) or $err = 1;
            $toWrite = '';
        }
        Write($outfile, $oldHdr, $oldVal) or $err = 1;
    }
    # return error message
    if ($err) {
        $msg = 'Error writing file';
    } elsif (not $ok and not $msg) {
        $msg = 'Unexpected end of file';
    } elsif (not $msg and $toWrite) {
        $msg = '';  # flag for nothing written
        $verbose and print $out "Deleted $grp1 (empty)\n";
    }
    return $msg;
}

#------------------------------------------------------------------------------
# Process MIE directory
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: undef on success, or error message if there was a problem
# Notes: file pointer is positioned at the MIE end on entry
sub ProcessMIEGroup($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my $notUTF8 = ($$et{OPTIONS}{Charset} ne 'UTF8');
    my ($msg, $buff, $ok, $oldIndent, $mime);
    my $lastTag = '';

    # get group 1 names: $grp doesn't have numbers (eg. 'MIE-Doc'),
    # and $grp1 does (eg. 'MIE1-Doc1')
    my $cnt = $$et{MIE_COUNT};
    my $grp1 = $tagTablePtr->{GROUPS}->{1};
    my $n = $$cnt{'MIE-Main'} || 0;
    if ($grp1 eq 'MIE-Main') {
        $$cnt{$grp1} = ++$n;
        $grp1 =~ s/MIE-/MIE$n-/ if $n > 1;
    } else {
        $grp1 =~ s/MIE-/MIE$n-/ if $n > 1;
        $$cnt{$grp1} = ($$cnt{$grp1} || 0) + 1;
        $grp1 .= $$cnt{$grp1} if $$cnt{$grp1} > 1;
    }
    # set group1 name for all tags extracted from this group
    $$et{SET_GROUP1} = $grp1;

    if ($verbose) {
        $oldIndent = $$et{INDENT};
        $$et{INDENT} .= '| ';
        $et->VerboseDir($grp1);
    }
    my $wasCompressed = $$dirInfo{WasCompressed};

    # process all MIE elements
    for (;;) {
        $raf->Read($buff, 4) == 4 or last;
        my ($sync, $format, $tagLen, $valLen) = unpack('aC3', $buff);
        $sync eq '~' or $msg = 'Invalid sync byte', last;

        # read tag name
        my ($tag, $units);
        if ($tagLen) {
            $raf->Read($tag, $tagLen) == $tagLen or last;
            $et->Warn("MIE tag '${tag}' out of sequence") if $tag lt $lastTag;
            $lastTag = $tag;
            # separate units from tag name if they exist
            $units = $1 if $tag =~ s/\((.*)\)$//;
        } else {
            $tag = '';
        }

        # get multi-byte value length if necessary
        if ($valLen > 252) {
            my $n = 1 << (256 - $valLen);
            $raf->Read($buff, $n) == $n or last;
            my $fmt = 'int' . ($n * 8) . 'u';
            $valLen = ReadValue(\$buff, 0, $fmt, 1, $n);
            if ($valLen > 0x7fffffff) {
                $msg = "Can't read $tag (DataLength > 2GB not yet supported)";
                last;
            }
        }

        # all done if we reached the group terminator
        unless ($tagLen) {
            # skip over terminator data block
            $ok = 1 unless $valLen and not $raf->Seek($valLen, 1);
            last;
        }

        # get tag information hash unless this is free space
        my ($tagInfo, $value);
        while ($format != 0x80) {
            $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            last if $tagInfo;
            # extract tags with locale code
            if ($tag =~ /\W/) {
                if ($tag =~ /^(\w+)-([a-z]{2}_[A-Z]{2})$/) {
                    my ($baseTag, $langCode) = ($1, $2);
                    $tagInfo = $et->GetTagInfo($tagTablePtr, $baseTag);
                    $tagInfo = GetLangInfo($tagInfo, $langCode) if $tagInfo;
                    last if $tagInfo;
                } else {
                    $et->Warn('Invalid MIE tag name');
                    last;
                }
            }
            # extract unknown tags if specified
            $tagInfo = {
                Name => $tag,
                Writable => 0,
                PrintConv => \&Image::ExifTool::LimitLongValues,
            };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
            last;
        }

        # read value and uncompress if necessary
        my $formatStr = $mieFormat{$format & 0xfb} || 'undef';
        if ($tagInfo or ($formatStr eq 'MIE' and $format & 0x04)) {
            $raf->Read($value, $valLen) == $valLen or last;
            if ($format & 0x04) {
                if ($verbose) {
                    print $out "$$et{INDENT}\[Tag '${tag}' $valLen bytes compressed]\n";
                }
                next unless HasZlib($et, 'decode');
                my $stat;
                my $inflate = Compress::Zlib::inflateInit();
                $inflate and ($value, $stat) = $inflate->inflate($value);
                unless ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                    $et->Warn("Error inflating $tag");
                    next;
                }
                $valLen = length $value;
                $wasCompressed = 1;
            }
        }

        # process this tag
        if ($formatStr eq 'MIE') {
            # process MIE directory
            my ($subTablePtr, $dirName);
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                $dirName = $tagInfo->{SubDirectory}->{DirName};
                my $subTable = $tagInfo->{SubDirectory}->{TagTable};
                $subTablePtr = $subTable ? GetTagTable($subTable) : $tagTablePtr;
            } else {
                $subTablePtr = GetTagTable('Image::ExifTool::MIE::Unknown');
            }
            if ($verbose) {
                my $order = ', byte order ' . GetByteOrder();
                $et->VerboseInfo($tag, $tagInfo, Size => $valLen, Extra => $order);
            }
            my %subdirInfo = (
                DirName => $dirName || $tag,
                RAF     => $raf,
                Parent  => $$dirInfo{DirName},
                WasCompressed => $wasCompressed,
            );
            # read from uncompressed data instead if necessary
            $subdirInfo{RAF} = File::RandomAccess->new(\$value) if $valLen;

            my $oldOrder = GetByteOrder();
            SetByteOrder($format & 0x08 ? 'II' : 'MM');
            $msg = ProcessMIEGroup($et, \%subdirInfo, $subTablePtr);
            SetByteOrder($oldOrder);
            $$et{SET_GROUP1} = $grp1;    # restore this group1 name
            last if $msg;
        } else {
            # process MIE data format types
            if ($tagInfo) {
                my ($rational, $binVal);
                # extract tag value
                my $val = ReadMIEValue(\$value, 0, $formatStr, undef, $valLen, \$rational);
                $binVal = substr($value, 0, $valLen) if $$et{OPTIONS}{SaveBin};
                unless (defined $val) {
                    $et->Warn("Error reading $tag value");
                    $val = '<err>';
                }
                # save type or mime type
                $mime = $val if $tag eq '0Type' or $tag eq '2MIME';
                if ($verbose) {
                    my $count;
                    my $s = Image::ExifTool::FormatSize($formatStr);
                    if ($s and $formatStr !~ /^(utf|string|undef)/) {
                        $count = $valLen / $s;
                    }
                    $et->VerboseInfo($lastTag, $tagInfo,
                        DataPt  => \$value,
                        DataPos => $wasCompressed ? undef : $raf->Tell() - $valLen,
                        Size    => $valLen,
                        Format  => $formatStr,
                        Value   => $val,
                        Count   => $count,
                    );
                }
                if ($$tagInfo{SubDirectory}) {
                    my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                    my %subdirInfo = (
                        DirName => $$tagInfo{Name},
                        DataPt  => \$value,
                        DataLen => $valLen,
                        DirStart=> 0,
                        DirLen  => $valLen,
                        Parent  => $$dirInfo{DirName},
                        WasCompressed => $wasCompressed,
                    );
                    # set DataPos and Base for uncompressed information only
                    unless ($wasCompressed) {
                        $subdirInfo{DataPos} = 0; # (relative to Base)
                        $subdirInfo{Base}    = $raf->Tell() - $valLen;
                    }
                    # reset PROCESSED lookup for each MIE directory
                    # (there is no possibility of double-processing a MIE directory)
                    $$et{PROCESSED} = { };
                    my $processProc = $tagInfo->{SubDirectory}->{ProcessProc};
                    delete $$et{SET_GROUP1};
                    delete $$et{NO_LIST};
                    $et->ProcessDirectory(\%subdirInfo, $subTablePtr, $processProc);
                    $$et{SET_GROUP1} = $grp1;
                    $$et{NO_LIST} = 1;
                } else {
                    # convert to specified character set if necessary
                    if ($notUTF8 and $formatStr =~ /^(utf|string)/) {
                        $val = $et->Decode($val, 'UTF8');
                    }
                    if ($formatStr =~ /_list$/) {
                        # split list value into separate strings
                        my @vals = split "\0", $val;
                        $val = \@vals;
                    }
                    if (defined $units) {
                        $val = "@$val" if ref $val; # convert string list to number list
                        # add units to value if specified
                        $val .= "($units)" if defined $units;
                    }
                    my $key = $et->FoundTag($tagInfo, $val);
                    if (defined $key) {
                        my $ex = $$et{TAG_EXTRA}{$key};
                        $$ex{Rational} = $rational if defined $rational;
                        $$ex{BinVal} = $binVal if defined $binVal;
                        $$ex{G6} = $formatStr if $$et{OPTIONS}{SaveFormat};
                    }
                }
            } else {
                # skip over unknown information or free bytes
                $raf->Seek($valLen, 1) or $msg = 'Seek error', last;
                $verbose and $et->VerboseInfo($tag, undef, Size => $valLen);
            }
        }
    }
    # modify MIME type if necessary
    $mime and not $$dirInfo{Parent} and $et->ModifyMimeType($mime);

    $ok or $msg or $msg = 'Unexpected end of file';
    $verbose and $$et{INDENT} = $oldIndent;
    return $msg;
}

#------------------------------------------------------------------------------
# Read/write a MIE file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MIE file, or -1 on write error
# - process as a trailer if "Trailer" flag set in dirInfo
sub ProcessMIE($$)
{
    my ($et, $dirInfo) = @_;
    return 1 unless defined $et;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my ($buff, $err, $msg, $pos, $end, $isCreating);
    my $numDocs = 0;
#
# process as a trailer (from end of file) if specified
#
    if ($$dirInfo{Trailer}) {
        my $offset = $$dirInfo{Offset} || 0;    # offset from end of file
        $raf->Seek(-10 - $offset, 2) or return 0;
        for (;;) {
            # read and validate last 10 bytes
            $raf->Read($buff, 10) == 10 or last;
            last unless $buff =~ /~\0\0\x06.{4}(\x10|\x18)(\x04)$/s or
                        $buff =~ /(\x10|\x18)(\x08)$/s;
            SetByteOrder($1 eq "\x10" ? 'MM' : 'II');
            my $len = ($2 eq "\x04") ? Get32u(\$buff, 4) : Get64u(\$buff, 0);
            my $curPos = $raf->Tell() or last;
            last if $len < 12 or $len > $curPos;
            # validate element header if 8-byte offset was used
            if ($2 eq "\x08") {
                last if $len < 14;
                $raf->Seek($curPos - 14, 0) and $raf->Read($buff, 4) or last;
                last unless $buff eq "~\0\0\x0a";
            }
            # looks like a good group, so remember start position
            $pos = $curPos - $len;
            $end = $curPos unless $end;
            # seek to 10 bytes from end of previous group
            $raf->Seek($pos - 10, 0) or last;
        }
        # seek to start of first MIE group
        return 0 unless defined $pos and $raf->Seek($pos, 0);
        # update DataPos and DirLen for ProcessTrailers()
        $$dirInfo{DataPos} = $pos;
        $$dirInfo{DirLen} = $end - $pos;
        if ($outfile and $$et{DEL_GROUP}{MIE}) {
            # delete the trailer
            $et->VPrint(0,"  Deleting MIE trailer\n");
            ++$$et{CHANGED};
            return 1;
        } elsif ($et->Options('Verbose') or $$et{HTML_DUMP}) {
            $et->DumpTrailer($dirInfo);
        }
    }
#
# loop through all documents in MIE file
#
    for (;;) {
        # look for "0MIE" group element
        my $num = $raf->Read($buff, 8);
        if ($num == 8) {
            # verify file identifier
            if ($buff =~ /^~(\x10|\x18)\x04(.)0MIE/s) {
                SetByteOrder($1 eq "\x10" ? 'MM' : 'II');
                my $len = ord($2);
                # skip extended DataLength if it exists
                if ($len > 252 and not $raf->Seek(1 << (256 - $len), 1)) {
                    $msg = 'Seek error';
                    last;
                }
            } else {
                return 0 unless $numDocs;   # not a MIE file
                if ($buff =~ /^~/) {
                    $msg = 'Non-standard file-level MIE element';
                } else {
                    $msg = 'Invalid MIE file-level data';
                }
            }
        } elsif ($numDocs) {
            last unless $num;   # OK, all done with file
            $msg = 'Truncated MIE element header';
        } else {
            return 0 if $num or not $outfile;
            # we have the ability to create a MIE file from scratch
            $buff = ''; # start from nothing
            # set byte order according to preferences
            $et->SetPreferredByteOrder();
            $isCreating = 1;
        }
        if ($msg) {
            last if $$dirInfo{Trailer}; # allow other trailers after MIE
            if ($outfile) {
                $et->Error($msg);
            } else {
                $et->Warn($msg);
            }
            last;
        }
        # this is a new MIE document -- increment document count
        unless ($numDocs) {
            # this is a valid MIE file (unless a trailer on another file)
            $et->SetFileType();
            $$et{NO_LIST} = 1;   # handle lists ourself
            $$et{MIE_COUNT} = { };
            undef $hasZlib;
        }
        ++$numDocs;

        # process the MIE groups recursively, beginning with the main MIE group
        my $tagTablePtr = GetTagTable('Image::ExifTool::MIE::Main');

        my %subdirInfo = (
            DirName => 'MIE',
            RAF => $raf,
            OutFile => $outfile,
            # don't define Parent so WriteMIEGroup() writes extended terminator
        );
        if ($outfile) {
            # generate lookup for MIE format codes if not done already
            unless (%mieCode) {
                foreach (keys %mieFormat) {
                    $mieCode{$mieFormat{$_}} = $_;
                }
            }
            # update %mieMap with user-defined MIE groups
            UpdateMieMap() unless $doneMieMap;
            # initialize write directories, with MIE tags taking priority
            # (note that this may re-initialize directories when writing trailer
            #  to another type of image, but this is OK because we are done writing
            #  the other format by the time we start writing the trailer)
            $et->InitWriteDirs(\%mieMap, 'MIE');
            $subdirInfo{ToWrite} = '~' . MIEGroupFormat(1) . "\x04\xfe0MIE\0\0\0\0";
            $msg = WriteMIEGroup($et, \%subdirInfo, $tagTablePtr);
            if ($msg) {
                $et->Error($msg);
                $err = 1;
                last;
            } elsif (defined $msg and $isCreating) {
                last;
            }
        } else {
            $msg = ProcessMIEGroup($et, \%subdirInfo, $tagTablePtr);
            if ($msg) {
                $et->Warn($msg);
                last;
            }
        }
    }
    delete $$et{NO_LIST};
    delete $$et{MIE_COUNT};
    delete $$et{SET_GROUP1};
    return $err ? -1 : 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MIE - Read/write MIE meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read and write
information in MIE files.

=head1 WHAT IS MIE?

MIE stands for "Meta Information Encapsulation".  The MIE format is an
extensible, dedicated meta information format which supports storage of
binary as well as textual meta information.  MIE can be used to encapsulate
meta information from many sources and bundle it together with any type of
file.

=head2 Features

Below is very subjective score card comparing the features of a number of
common file and meta information formats, and comparing them to MIE.  The
following features are rated for each format with a score of 0 to 10:

  1) Extensible (can incorporate user-defined information).
  2) Meaningful tag ID's (hint to meaning of unknown information).
  3) Sequential read/write ability (streamable).
  4) Hierarchical information structure.
  5) Easy to implement reader/writer/editor.
  6) Order of information well defined.
  7) Large data lengths supported: >64kB (+5) and >4GB (+5).
  8) Localized text strings.
  9) Multiple documents in a single file.
 10) Compact format doesn't squander disk space or bandwidth.
 11) Compressed meta information supported.
 12) Relocatable data elements (ie. no fixed offsets).
 13) Binary meta information (+7) with variable byte order (+3).
 14) Mandatory tags not required (an unnecessary complication).
 15) Append information to end of file without editing.

                          Feature number                   Total
     Format  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15   Score
     ------ ---------------------------------------------  -----
     MIE    10 10 10 10 10 10 10 10 10 10 10 10 10 10 10    150
     PDF    10 10  0 10  0  0 10  0 10 10 10  0  7 10 10     97
     PNG    10 10 10  0  8  0  5 10  0 10 10 10  0 10  0     93
     XMP    10 10 10 10  2  0 10 10 10  0  0 10  0 10  0     92
     AIFF    0  5 10 10 10  0  5  0  0 10  0 10  7 10  0     77
     RIFF    0  5 10 10 10  0  5  0  0 10  0 10  7 10  0     77
     JPEG   10  0 10  0 10  0  0  0  0 10  0 10  7 10  0     67
     EPS    10 10 10  0  0  0 10  0 10  0  0  5  0 10  0     65
     CIFF    0  0  0 10 10  0  5  0  0 10  0 10 10 10  0     65
     TIFF    0  0  0 10  5 10  5  0 10 10  0  0 10  0  0     60
     EXIF    0  0  0 10  5 10  0  0  0 10  0  0 10  0  0     45
     IPTC    0  0 10  0  8  0  0  0  0 10  0 10  7  0  0     45

By design, MIE ranks highest by a significant margin.  Other formats with
reasonable scores are PDF, PNG and XMP, but each has significant weak
points.  What may be surprising is that TIFF, EXIF and IPTC rank so low.

As well as scoring high in all these features, the MIE format has the unique
ability to encapsulate any other type of file, and provides a non-invasive
method of adding meta information to a file.  The meta information is
logically separated from the original file data, which is extremely
important because meta information is routinely lost when files are edited.

Also, the MIE format supports multiple files by simple concatenation,
enabling all kinds of wonderful features such as linear databases, edit
histories or non-intrusive file updates.  This ability can also be leveraged
to allow MIE-format trailers to be added to some other file types.

=head1 MIE 1.1 FORMAT SPECIFICATION (2007-01-21)

=head2 File Structure

A MIE file consists of a series of MIE elements.  A MIE element may contain
either data or a group of MIE elements, providing a hierarchical format for
storing data.  Each MIE element is identified by a human-readable tag name,
and may store data from zero to 2^64-1 bytes in length.

=head2 File Signature

The first element in the MIE file must be an uncompressed MIE group element
with a tag name of "0MIE".  This restriction allows the first 8 bytes of a
MIE file to be used to identify a MIE format file.  The following table
lists the two possible initial byte sequences for a MIE-format file (the
first for big-endian, and the second for little-endian byte ordering):

    Byte Number:      0    1    2    3    4    5    6    7

    C Characters:     ~ \x10 \x04    ?    0    M    I    E
        or            ~ \x18 \x04    ?    0    M    I    E

    Hexadecimal:     7e   10   04    ?   30   4d   49   45
        or           7e   18   04    ?   30   4d   49   45

    Decimal:        126   16    4    ?   48   77   73   69
        or          126   24    4    ?   48   77   73   69

Note that byte 1 may have one of the two possible values (0x10 or 0x18), and
byte 3 may have any value (0x00 to 0xff).

=head2 Element Structure

    1 byte  SyncByte = 0x7e (decimal 126, character '~')
    1 byte  FormatCode (see below)
    1 byte  TagLength (T)
    1 byte  DataLength (gives D if DataLength < 253)
    T bytes TagName (T given by TagLength)
    2 bytes DataLength2 [exists only if DataLength == 255 (0xff)]
    4 bytes DataLength4 [exists only if DataLength == 254 (0xfe)]
    8 bytes DataLength8 [exists only if DataLength == 253 (0xfd)]
    D bytes DataBlock (D given by DataLength)

The minimum element length is 4 bytes (for a group terminator).  The maximum
DataBlock size is 2^64-1 bytes.  TagLength and DataLength are unsigned
integers, and the byte ordering for multi-byte DataLength fields is
specified by the containing MIE group element.  The SyncByte is byte
aligned, so no padding is added to align on an N-byte boundary.

=head3 FormatCode

The format code is a bitmask that defines the format of the data:

    7654 3210
    ++++ ----  FormatType
    ---- +---  TypeModifier
    ---- -+--  Compressed
    ---- --++  FormatSize

=over 4

=item FormatType (bitmask 0xf0):

    0x00 - other (or unknown) data
    0x10 - MIE group
    0x20 - text string
    0x30 - list of null-separated text strings
    0x40 - integer
    0x50 - rational
    0x60 - fixed point
    0x70 - floating point
    0x80 - free space

=item TypeModifier (bitmask 0x08):

Modifies the meaning of certain FormatTypes (0x00-0x60):

    0x08 - other data sensitive to MIE group byte order
    0x18 - MIE group with little-endian byte ordering
    0x28 - UTF encoded text string
    0x38 - UTF encoded text string list
    0x48 - signed integer
    0x58 - signed rational (denominator is always unsigned)
    0x68 - signed fixed-point

=item Compressed (bitmask 0x04):

If this bit is set, the data block is compressed using Zlib deflate.  An
entire MIE group may be compressed, with the exception of file-level groups.

=item FormatSize (bitmask 0x03):

Gives the byte size of each data element:

    0x00 - 8 bits  (1 byte)
    0x01 - 16 bits (2 bytes)
    0x02 - 32 bits (4 bytes)
    0x03 - 64 bits (8 bytes)

The number of bytes in a single value for this format is given by
2**FormatSize (or 1 << FormatSize).  The number of values is the data length
divided by this number of bytes.  It is an error if the data length is not
an even multiple of the format size in bytes.

=back

The following is a list of all currently defined MIE FormatCode values for
uncompressed data (add 0x04 to each value for compressed data):

    0x00 - other data (insensitive to MIE group byte order) (1)
    0x01 - other 16-bit data (may be byte swapped)
    0x02 - other 32-bit data (may be byte swapped)
    0x03 - other 64-bit data (may be byte swapped)
    0x08 - other data (sensitive to MIE group byte order) (1)
    0x10 - MIE group with big-endian values (1)
    0x18 - MIE group with little-endian values (1)
    0x20 - ASCII (ISO 8859-1) string (2,3)
    0x28 - UTF-8 string (2,3,4)
    0x29 - UTF-16 string (2,3,4)
    0x2a - UTF-32 string (2,3,4)
    0x30 - ASCII (ISO 8859-1) string list (3,5)
    0x38 - UTF-8 string list (3,4,5)
    0x39 - UTF-16 string list (3,4,5)
    0x3a - UTF-32 string list (3,4,5)
    0x40 - unsigned 8-bit integer
    0x41 - unsigned 16-bit integer
    0x42 - unsigned 32-bit integer
    0x43 - unsigned 64-bit integer (6)
    0x48 - signed 8-bit integer
    0x49 - signed 16-bit integer
    0x4a - signed 32-bit integer
    0x4b - signed 64-bit integer (6)
    0x52 - unsigned 32-bit rational (16-bit numerator then denominator) (7)
    0x53 - unsigned 64-bit rational (32-bit numerator then denominator) (7)
    0x5a - signed 32-bit rational (denominator is unsigned) (7)
    0x5b - signed 64-bit rational (denominator is unsigned) (7)
    0x61 - unsigned 16-bit fixed-point (high 8 bits is integer part) (8)
    0x62 - unsigned 32-bit fixed-point (high 16 bits is integer part) (8)
    0x69 - signed 16-bit fixed-point (high 8 bits is signed integer) (8)
    0x6a - signed 32-bit fixed-point (high 16 bits is signed integer) (8)
    0x72 - 32-bit IEEE float (not recommended for portability reasons)
    0x73 - 64-bit IEEE double (not recommended for portability reasons) (6)
    0x80 - free space (value data does not contain useful information)

Notes:

=over 4

=item 1.

The byte ordering specified by the MIE group TypeModifier applies to the MIE
group element as well as all elements within the group.  Data for all
FormatCodes except 0x08 (other data, sensitive to byte order) may be
transferred between MIE groups with different byte order by byte swapping
the uncompressed data according to the specified data format.  The following
list illustrates the byte-swapping pattern, based on FormatSize, for all
format types except rational (FormatType 0x50).

      FormatSize              Change in Byte Sequence
    --------------      -----------------------------------
    0x00 (8 bits)       0 1 2 3 4 5 6 7 --> 0 1 2 3 4 5 6 7 (no change)
    0x01 (16 bits)      0 1 2 3 4 5 6 7 --> 1 0 3 2 5 4 7 6
    0x02 (32 bits)      0 1 2 3 4 5 6 7 --> 3 2 1 0 7 6 5 4
    0x03 (64 bits)      0 1 2 3 4 5 6 7 --> 7 6 5 4 3 2 1 0

Rational values consist of two integers, so they are swapped as the next
lower FormatSize.  For example, a 32-bit rational (FormatSize 0x02, and
FormatCode 0x52 or 0x5a) is swapped as two 16-bit values (ie. as if it had
FormatSize 0x01).

=item 2.

The TagName of a string element may have an 6-character suffix to indicate a
specific locale. (eg. "Title-en_US", or "Keywords-de_DE").

=item 3.

Text strings are not normally null terminated, however they may be padded
with one or more null characters to the end of the data block to allow
strings to be edited within fixed-length data blocks.  Newlines in the text
are indicated by a single LF (0x0a) character.

=item 4.

UTF strings must not begin with a byte order mark (BOM) since the byte order
and byte size are specified by the MIE format.  If a BOM is found, it should
be treated as a zero-width non-breaking space.

=item 5.

A list of text strings separated by null characters.  These lists must not
be null padded or null terminated, since this would be interpreted as
additional zero-length strings.  For ASCII and UTF-8 strings, the null
character is a single zero (0x00) byte.  For UTF-16 or UTF-32 strings, the
null character is 2 or 4 zero bytes respectively.

=item 6.

64-bit integers and doubles are subject to the specified byte ordering for
both 32-bit words and bytes within these words.  For instance, the high
order byte is always the first byte if big-endian, and the eighth byte if
little-endian.  This means that some swapping is always necessary for these
values on systems where the byte order differs from the word order (eg. some
ARM systems), regardless of the endian-ness of the stored values.

=item 7.

Rational values are treated as two separate integers.  The numerator always
comes first regardless of the byte ordering.  In a signed rational value,
only the numerator is signed.  The denominator of all rational values is
unsigned (eg. a signed 64-bit rational of 0x80000000/0x80000000 evaluates to
-1, not +1).

=item 8.

32-bit fixed point values are converted to floating point by treating them
as an integer and dividing by an appropriate value.  eg)

    16-bit fixed value = 16-bit integer value / 256.0
    32-bit fixed value = 32-bit integer value / 65536.0

=back

=head3 TagLength

Gives the length of the TagName string.  Any value between 0 and 255 is
valid, but the TagLength of 0 is valid only for the MIE group terminator.

=head3 DataLength

DataLength is an unsigned byte that gives the number of bytes in the data
block.  A value between 0 and 252 gives the data length directly, and
numbers from 253 to 255 are reserved for extended DataLength codes.  Codes
of 255, 254 and 253 indicate that the element contains an additional 2, 4 or
8 byte unsigned integer representing the data length.

    0-252      - length of data block
    255 (0xff) - use DataLength2
    254 (0xfe) - use DataLength4
    253 (0xfd) - use DataLength8

A DataLength of zero is valid for any element except a compressed MIE group.
A zero DataLength for an uncompressed MIE group indicates that the group
length is unknown.  For other elements, a zero length indicates there is no
associated data.  A terminator element must have a DataLength of 0, 6 or 10,
and may not use an extended DataLength.

=head3 TagName

The TagName string is 0 to 255 bytes long, and is composed of the ASCII
characters A-Z, a-z, 0-9 and underline ('_').  Also, a dash ('-') is used to
separate the language/country code in the TagName of a localized text
string, and a units string (possibly containing other ASCII characters) may
be appear in brackets at the end of the TagName.  The TagName string is NOT
null terminated.  A MIE element with a tag string of zero length is reserved
for the group terminator.

MIE elements are sorted alphabetically by TagName within each group.
Multiple elements with the same TagName are allowed, even within the same
group.

TagNames should be meaningful.  Case is significant.  Words should be
lowercase with an uppercase first character, and acronyms should be all
upper case.  The underline ("_") is provided to allow separation of two
acronyms or two numbers, but it shouldn't be used unless necessary.  No
separation is necessary between an acronym and a word (eg. "ISOSetting").

All TagNames should start with an uppercase letter.  An exception to this
rule allows tags to begin with a digit (0-9) if they must come before other
tags in the sort order, or a lowercase letter (a-z) if they must come after.
For instance, the '0Type' element begins with a digit so it comes before,
and the 'data' element begins with a lowercase letter so that it comes after
meta information tags in the main "0MIE" group.

Tag names for localized text strings have an 6-character suffix with the
following format:  The first character is a dash ('-'), followed by a
2-character lower case ISO 639-1 language code, then an underline ('_'), and
ending with a 2-character upper case ISO 3166-1 alpha 2 country code.  (eg.
"-en_US", "-en_GB", "-de_DE" or "-fr_FR".  Note that "GB", and not "UK" is
the code for Great Britain, although "UK" should be recognized for
compatibility reasons.)  The suffix is included when sorting the tags
alphabetically, so the default locale (with no tag-name suffix) always comes
first.  If the country is unknown or not applicable, a country code of "XX"
should be used.

Tags with numerical values may allow units of measurement to be specified.
The units string is stored in brackets at the end of the tag name, and is
composed of zero or more ASCII characters in the range 0x21 to 0x7d,
excluding the bracket characters 0x28 and 0x29.  (eg. "Resolution(/cm)" or
"SpecificHeat(J/kg.K)".)  See L<Image::ExifTool::MIEUnits> for details. Unit
strings are not localized, and may not be used in combination with localized
text strings.

Sets of tags which would require a common prefix should be added in a
separate MIE group instead of adding the prefix to all tag names.  For
example, instead of these TagName's:

    ExternalFlashType
    ExternalFlashSerialNumber
    ExternalFlashFired

one would instead designate a separate "ExternalFlash" MIE group to contain
the following elements:

    Type
    SerialNumber
    Fired

=head3 DataLength2/4/8

These extended DataLength fields exist only if DataLength is 255, 254 or
253, and are respectively 2, 4 or 8 byte unsigned integers giving the data
block length.  One of these values must be used if the data block is larger
than 252 bytes, but they may be used if desired for smaller blocks too
(although this may add a few unnecessary bytes to the MIE element).

=head3 DataBlock

The data value for the MIE element.  The format of the data is given by the
FormatCode.  For MIE group elements, the data includes all contained
elements and the group terminator.

=head2 MIE groups

All MIE data elements must be contained within a group.  A group begins with
a MIE group element, and ends with a group terminator.  Groups may be nested
in a hierarchy to arbitrary depth.

A MIE group element is identified by a format code of 0x10 (big endian byte
ordering) or 0x18 (little endian).  The group terminator is distinguished by
a zero TagLength (it is the only element allowed to have a zero TagLength),
and has a FormatCode of 0x00.

The MIE group element is permitted to have a zero DataLength only if the
data is uncompressed.  This special value indicates that the group length is
unknown (otherwise the minimum value for DataLength is 4, corresponding the
the minimum group size which includes a terminator of at least 4 bytes). If
DataLength is zero, all elements in the group must be parsed until the group
terminator is found.  If non-zero, DataLength includes the length of all
elements contained within the group, including the group terminator.  Use of
a non-zero DataLength is encouraged because it allows readers quickly skip
over entire MIE groups.  For compressed groups DataLength must be non-zero,
and is the length of the compressed group data (which includes the
compressed group terminator).

=head3 Group Terminator

The group terminator has a FormatCode and TagLength of zero.  The terminator
DataLength must be 0, 6 or 10 bytes, and extended DataLength codes may not
be used.  With a zero DataLength, the byte sequence for a terminator is "7e
00 00 00" (hex).  With a DataLength of 6 or 10 bytes, the terminator data
block contains information about the length and byte ordering of the
preceding group.  This additional information is recommended for file-level
groups, and is used in multi-document MIE files and MIE trailers to allow
the file to be scanned backwards from the end.  (This may also allow some
documents to be recovered if part of the file is corrupted.)  The structure
of this optional terminator data block is as follows:

    4 or 8 bytes  GroupLength (unsigned integer)
    1 byte        ByteOrder (0x10 or 0x18, same as MIE group)
    1 byte        GroupLengthSize (0x04 or 0x08)

The ByteOrder and GroupLengthSize values give the byte ordering and size of
the GroupLength integer.  The GroupLength value is the total length of the
entire MIE group ending with this terminator, including the opening MIE
group element and the terminator itself.

=head3 File-level MIE groups

File-level MIE groups may NOT be compressed.

All elements in a MIE file are contained within a special group with a
TagName of "0MIE".  The purpose of the "OMIE" group is to provide a unique
signature at the start of the file, and to encapsulate information allowing
files to be easily combined.  The "0MIE" group must be terminated like any
other group, but it is recommended that the terminator of a file-level group
include the optional data block (defined above) to provide information about
the group length and byte order.

It is valid to have more than one "0MIE" group at the file level, allowing
multiple documents in a single MIE file.  Furthermore, the MIE structure
enables multi-document files to be generated by simply concatenating two or
more MIE files.

=head2 Scanning Backwards through a MIE File

The steps below give an algorithm to quickly locate the last document in a
MIE file:

=over 4

=item 1.

Read the last 10 bytes of the file.  (Note that a valid MIE file may be as
short as 12 bytes long, but a file this length contains only an an empty MIE
group.)

=item 2.

If the last byte of the file is zero, then it is not possible to scan
backward through the file, so the file must be scanned from the beginning.
Otherwise, proceed to the next step.

=item 3.

If the last byte is 4 or 8, the terminator contains information about the
byte ordering and length of the group.  Otherwise, stop here because this
isn't a valid MIE file.

=item 4.

The next-to-last byte must be either 0x10 indicating big-endian byte
ordering or 0x18 for little-endian ordering, otherwise this isn't a valid
MIE file.

=item 5.

The value of the preceding 4 or 8 bytes gives the length of the complete
file-level MIE group (GroupLength).  This length includes both the leading
MIE group element and the terminator element itself.  The value is an
unsigned integer with a byte length given in step 3), and a byte order from
step 4).  From the current file position (at the end of the data read in
step 1), seek backward by this number of bytes to find the start of the MIE
group element for this document.

=back

This algorithm may be repeated again beginning at this point in the file to
locate the next-to-last document, etc.

The table below lists all 5 valid patterns for the last 14 bytes of a
file-level MIE group, with all numbers in hex.  The comments indicate the
length and byte ordering of GroupLength (xx) if available:

  ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 7e 00 00 00  - (no GroupLength)
  ?? ?? ?? ?? 7e 00 00 06 xx xx xx xx 10 04  - 4 bytes, big endian
  ?? ?? ?? ?? 7e 00 00 06 xx xx xx xx 18 04  - 4 bytes, little endian
  7e 00 00 0a xx xx xx xx xx xx xx xx 10 08  - 8 bytes, big endian
  7e 00 00 0a xx xx xx xx xx xx xx xx 18 08  - 8 bytes, little endian

=head2 Trailer Signature

The MIE format may be used for trailer information appended to other types
of files.  When this is done, a signature must appear at the end of the main
MIE group to uniquely identify the MIE format trailer.  To achieve this, a
"zmie" trailer signature is written as the last element in the main "0MIE"
group.  This element has a FormatCode of 0, a TagLength of 4, a DataLength
of 0, and a TagName of "zmie".  With this signature, the hex byte sequence
"7e 00 04 00 7a 6d 69 65" appears immediately before the final group
terminator, and the last 22 bytes of the trailer correspond to one of the
following 4 patterns (where the trailer length is given by "xx", as above):

  ?? ?? ?? ?? 7e 00 04 00 7a 6d 69 65 7e 00 00 06 xx xx xx xx 10 04
  ?? ?? ?? ?? 7e 00 04 00 7a 6d 69 65 7e 00 00 06 xx xx xx xx 18 04
  7e 00 04 00 7a 6d 69 65 7e 00 00 0a xx xx xx xx xx xx xx xx 10 08
  7e 00 04 00 7a 6d 69 65 7e 00 00 0a xx xx xx xx xx xx xx xx 18 08

Note that the zero-DataLength terminator may not be used here because the
trailer length must be known for seeking backwards from the end of the file.

Multiple trailers may be appended to the same file using this technique.

=head2 MIE Data Values

MIE data values for a given tag are usually not restricted to a specific
FormatCode.  Any value may be represented in any appropriate format,
including numbers represented in string (ASCII or UTF) form.

It is preferred that closely related values with the same format are written
to a single tag instead of using multiple tags.  This improves localization
of like values and decreases MIE element overhead.  For instance, instead of
separate ImageWidth and ImageHeight tags, a single ImageSize tag is defined.

Tags which may take on a discrete set of values should have meaningful
values if possible.  This improves the extensibility of the format and
allows a more reasonable interpretation of unrecognized values.

=head3 Numerical Representation

Integer and floating point numbers may be represented in binary or string
form.  In string form, integers are a series of digits with an optional
leading sign (eg. "[+|-]DDDDDD"), and multiple values are separated by a
single space character (eg. "23 128 -32").  Floating point numbers are
similar but may also contain a decimal point and/or a signed exponent with a
leading 'e' character (eg. "[+|-]DD[.DDDDDD][e(+|-)EEE]").  The string "inf"
is used to represent infinity.  One advantage of numerical strings is that
they can have an arbitrarily high precision because the possible number of
significant digits is virtually unlimited.

Note that numerical values may have associated units of measurement which
are specified in the L</TagName> string.

=head3 Date/Time Format

All MIE dates are strings in the form "YYYY:mm:dd HH:MM:SS.ss+HH:MM".  The
fractional seconds (".ss") are optional, and if included may contain any
number of significant digits (unlike all other fields which are a fixed
number of digits and must be padded with leading zeros if necessary).  The
timezone ("+HH:MM" or "-HH:MM") is recommended but not required.  If not
given, the local system timezone is assumed.

=head2 MIME Type

The basic MIME type for a MIE file is "application/x-mie", however the
specific MIME type depends on the type of subfile, and is obtained by adding
"x-mie-" to the MIME type of the subfile.  For example, with a subfile of
type "image/jpeg", the MIE file MIME type is "image/x-mie-jpeg".  But note
that the "x-" is not duplicated if the subfile MIME type already starts with
"x-".  So a subfile with MIME type "image/x-raw" is contained within a MIE
file of type "image/x-mie-raw", not "image/x-mie-x-raw".  In the case of
multiple documents in a MIE file, the MIME type is taken from the first
document.  Regardless of the subfile type, all MIE-format files should have
a filename extension of ".MIE".

=head2 Levels of Support

Basic MIE reader/writer applications may choose not to provide support for
some advanced features of the MIE format.  Features which may not be
supported by all software are:

=over 4

=item Compression

Software not supporting compression must ignore compressed elements and
groups, but should be able to process the remaining information.

=item Large data lengths

Some software may limit the maximum size of a MIE group or element.
Historically, a limit of 2GB may be imposed by some systems.  However,
8-byte data lengths should be supported by all applications provided the
value doesn't exceed the system limit.  (eg. For systems with a 2GB limit,
8-byte data lengths should be supported if the upper 17 bits are all zero.)
If a data length above the system limit is encountered, it may be necessary
for the application to stop processing if it can not seek to the next
element in the file.

=back

=head1 EXAMPLES

This section gives examples for working with MIE information using ExifTool.

=head2 Encapsulating Information with Data in a MIE File

The following command encapsulates any file recognized by ExifTool inside a
MIE file, and initializes MIE tags from information within the file:

    exiftool -o new.mie -tagsfromfile FILE '-mie:all<all' \
        '-subfilename<filename' '-subfiletype<filetype' \
        '-subfilemimetype<mimetype' '-subfiledata<=FILE'

where C<FILE> is the name of the file.

For unrecognized files, this command may be used:

    exiftool -o new.mie -subfilename=FILE -subfiletype=TYPE \
        -subfilemimetype=MIME '-subfiledata<=FILE'

where C<TYPE> and C<MIME> represent the source file type and MIME type
respectively.

=head2 Adding a MIE Trailer to a File

The MIE format may also be used to store information in a trailer appended
to another type of file.  Beware that trailers may not be compatible with
all file formats, but JPEG and TIFF are two formats where additional trailer
information doesn't create any problems for normal parsing of the file.
Also note that this technique has the disadvantage that trailer information
is commonly lost if the file is subsequently edited by other software.

Creating a MIE trailer with ExifTool is a two-step process since ExifTool
can't currently be used to add a MIE trailer directly.  The example below
illustrates the steps for adding a MIE trailer with a small preview image
(C<small.jpg>) to a destination JPEG image (C<dst.jpg>).

Step 1) Create a MIE file with a TrailerSignature containing the desired
information:

    exiftool -o new.mie -trailersignature=1 -tagsfromfile small.jpg \
        '-previewimagetype<filetype' '-previewimagesize<imagesize' \
        '-previewimagename<filename' '-previewimage<=small.jpg'

Step 2) Append the MIE information to another file.  In Unix, this can be
done with the 'cat' command:

    cat new.mie >> dst.jpg

Once added, ExifTool may be used to edit or delete a MIE trailer in a JPEG
or TIFF image.

=head2 Multiple MIE Documents in a Single File

The MIE specification allows multiple MIE documents (or trailers) to exist
in a single file.  A file like this may be created by simply concatenating
MIE documents.  ExifTool may be used to access information in a specific
document by adding a copy number to the MIE group name.  For example:

    # write the Author tag in the second MIE document
    exiftool -mie2:author=phil test.mie

    # delete the first MIE document from a file
    exiftool -mie1:all= test.mie

=head2 Units of Measurement

Some MIE tags allow values to be specified in different units of
measurement.  In the MIE file format these units are combined with the tag
name, but when using ExifTool they are specified in brackets after the
value:

    exiftool -mie:gpsaltitude='7500(ft)' test.mie

If no units are provided, the default units are written.

=head2 Localized Text

Localized text values are accessed by adding a language/country code to the
tag name.  For example:

    exiftool -comment-en_us='this is a comment' test.mie

=head1 REVISIONS

  2010-04-05 - Fixed "Format Size" Note 7 to give the correct number of bits
               in the example rational value
  2007-01-21 - Specified LF character (0x0a) for text newline sequence
  2007-01-19 - Specified ISO 8859-1 character set for extended ASCII codes
  2007-01-01 - Improved wording of Step 5 for scanning backwards in MIE file
  2006-12-30 - Added EXAMPLES section and note about UTF BOM
  2006-12-20 - MIE 1.1:  Changed meaning of TypeModifier bit (0x08) for
               unknown data (FormatType 0x00), and documented byte swapping
  2006-12-14 - MIE 1.0:  Added Data Values and Numerical Representations
               sections, and added ability to specify units in tag names
  2006-11-09 - Added Levels of Support section
  2006-11-03 - Added Trailer Signature
  2005-11-18 - Original specification created

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  The MIE format itself is also
copyright Phil Harvey, and is covered by the same free-use license.

=head1 REFERENCES

=over 4

=item L<https://exiftool.org/MIE1.1-20070121.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MIE Tags>, L<Image::ExifTool::MIEUnits>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

