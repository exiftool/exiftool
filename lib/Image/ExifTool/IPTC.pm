#------------------------------------------------------------------------------
# File:         IPTC.pm
#
# Description:  Read IPTC meta information
#
# Revisions:    Jan. 08/2003 - P. Harvey Created
#               Feb. 05/2004 - P. Harvey Added support for records other than 2
#
# References:   1) http://www.iptc.org/IIM/
#------------------------------------------------------------------------------

package Image::ExifTool::IPTC;

use strict;
use vars qw($VERSION $AUTOLOAD %iptcCharset);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.58';

%iptcCharset = (
    "\x1b%G"  => 'UTF8',
   # don't translate these (at least until we handle ISO 2022 shift codes)
   # because the sets are only designated and not invoked
   # "\x1b,A"  => 'Latin',  # G0 = ISO 8859-1 (similar to Latin1, but codes 0x80-0x9f are missing)
   # "\x1b-A"  => 'Latin',  # G1     "
   # "\x1b.A"  => 'Latin',  # G2
   # "\x1b/A"  => 'Latin',  # G3
);

sub ProcessIPTC($$$);
sub WriteIPTC($$$);
sub CheckIPTC($$$);
sub PrintCodedCharset($);
sub PrintInvCodedCharset($);

# standard IPTC locations
# (MWG specifies locations only for JPEG, TIFF and PSD -- the rest are ExifTool-defined)
my %isStandardIPTC = (
    'JPEG-APP13-Photoshop-IPTC' => 1,
    'TIFF-IFD0-IPTC'            => 1,
    'PSD-IPTC'                  => 1,
    'MIE-IPTC'                  => 1,
    'EPS-Photoshop-IPTC'        => 1,
    'PS-Photoshop-IPTC'         => 1,
    'EXV-APP13-Photoshop-IPTC'  => 1,
    # set file types to 0 if they have a standard location
    JPEG => 0,
    TIFF => 0,
    PSD  => 0,
    MIE  => 0,
    EPS  => 0,
    PS   => 0,
    EXV  => 0,
);

my %fileFormat = (
    0 => 'No ObjectData',
    1 => 'IPTC-NAA Digital Newsphoto Parameter Record',
    2 => 'IPTC7901 Recommended Message Format',
    3 => 'Tagged Image File Format (Adobe/Aldus Image data)',
    4 => 'Illustrator (Adobe Graphics data)',
    5 => 'AppleSingle (Apple Computer Inc)',
    6 => 'NAA 89-3 (ANPA 1312)',
    7 => 'MacBinary II',
    8 => 'IPTC Unstructured Character Oriented File Format (UCOFF)',
    9 => 'United Press International ANPA 1312 variant',
    10 => 'United Press International Down-Load Message',
    11 => 'JPEG File Interchange (JFIF)',
    12 => 'Photo-CD Image-Pac (Eastman Kodak)',
    13 => 'Bit Mapped Graphics File [.BMP] (Microsoft)',
    14 => 'Digital Audio File [.WAV] (Microsoft & Creative Labs)',
    15 => 'Audio plus Moving Video [.AVI] (Microsoft)',
    16 => 'PC DOS/Windows Executable Files [.COM][.EXE]',
    17 => 'Compressed Binary File [.ZIP] (PKWare Inc)',
    18 => 'Audio Interchange File Format AIFF (Apple Computer Inc)',
    19 => 'RIFF Wave (Microsoft Corporation)',
    20 => 'Freehand (Macromedia/Aldus)',
    21 => 'Hypertext Markup Language [.HTML] (The Internet Society)',
    22 => 'MPEG 2 Audio Layer 2 (Musicom), ISO/IEC',
    23 => 'MPEG 2 Audio Layer 3, ISO/IEC',
    24 => 'Portable Document File [.PDF] Adobe',
    25 => 'News Industry Text Format (NITF)',
    26 => 'Tape Archive [.TAR]',
    27 => 'Tidningarnas Telegrambyra NITF version (TTNITF DTD)',
    28 => 'Ritzaus Bureau NITF version (RBNITF DTD)',
    29 => 'Corel Draw [.CDR]',
);

# main IPTC tag table
# Note: ALL entries in main IPTC table (except PROCESS_PROC) must be SubDirectory
# entries, each specifying a TagTable.
%Image::ExifTool::IPTC::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessIPTC,
    WRITE_PROC => \&WriteIPTC,
    1 => {
        Name => 'IPTCEnvelope',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::EnvelopeRecord',
        },
    },
    2 => {
        Name => 'IPTCApplication',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::ApplicationRecord',
        },
    },
    3 => {
        Name => 'IPTCNewsPhoto',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::NewsPhoto',
        },
    },
    7 => {
        Name => 'IPTCPreObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::PreObjectData',
        },
    },
    8 => {
        Name => 'IPTCObjectData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::ObjectData',
        },
    },
    9 => {
        Name => 'IPTCPostObjectData',
        Groups => { 1 => 'IPTC#' }, #(just so this shows up in group list)
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::PostObjectData',
        },
    },
    240 => {
        Name => 'IPTCFotoStation',
        SubDirectory => {
            TagTable => 'Image::ExifTool::IPTC::FotoStation',
        },
    },
);

# Record 1 -- EnvelopeRecord
%Image::ExifTool::IPTC::EnvelopeRecord = (
    GROUPS => { 2 => 'Other' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
    0 => {
        Name => 'EnvelopeRecordVersion',
        Format => 'int16u',
        Mandatory => 1,
    },
    5 => {
        Name => 'Destination',
        Flags => 'List',
        Groups => { 2 => 'Location' },
        Format => 'string[0,1024]',
    },
    20 => {
        Name => 'FileFormat',
        Groups => { 2 => 'Image' },
        Format => 'int16u',
        PrintConv => \%fileFormat,
    },
    22 => {
        Name => 'FileVersion',
        Groups => { 2 => 'Image' },
        Format => 'int16u',
    },
    30 => {
        Name => 'ServiceIdentifier',
        Format => 'string[0,10]',
    },
    40 => {
        Name => 'EnvelopeNumber',
        Format => 'digits[8]',
    },
    50 => {
        Name => 'ProductID',
        Flags => 'List',
        Format => 'string[0,32]',
    },
    60 => {
        Name => 'EnvelopePriority',
        Format => 'digits[1]',
        PrintConv => {
            0 => '0 (reserved)',
            1 => '1 (most urgent)',
            2 => 2,
            3 => 3,
            4 => 4,
            5 => '5 (normal urgency)',
            6 => 6,
            7 => 7,
            8 => '8 (least urgent)',
            9 => '9 (user-defined priority)',
        },
    },
    70 => {
        Name => 'DateSent',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    80 => {
        Name => 'TimeSent',
        Groups => { 2 => 'Time' },
        Format => 'string[11]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    90 => {
        Name => 'CodedCharacterSet',
        Notes => q{
            values are entered in the form "ESC X Y[, ...]".  The escape sequence for
            UTF-8 character coding is "ESC % G", but this is displayed as "UTF8" for
            convenience.  Either string may be used when writing.  The value of this tag
            affects the decoding of string values in the Application and NewsPhoto
            records.  This tag is marked as "unsafe" to prevent it from being copied by
            default in a group operation because existing tags in the destination image
            may use a different encoding.  When creating a new IPTC record from scratch,
            it is suggested that this be set to "UTF8" if special characters are a
            possibility
        },
        Protected => 1,
        Format => 'string[0,32]',
        ValueConvInv => '$val =~ /^UTF-?8$/i ? "\x1b%G" : $val',
        # convert ISO 2022 escape sequences to a more readable format
        PrintConv => \&PrintCodedCharset,
        PrintConvInv => \&PrintInvCodedCharset,
    },
    100 => {
        Name => 'UniqueObjectName',
        Format => 'string[14,80]',
    },
    120 => {
        Name => 'ARMIdentifier',
        Format => 'int16u',
    },
    122 => {
        Name => 'ARMVersion',
        Format => 'int16u',
    },
);

# Record 2 -- ApplicationRecord
%Image::ExifTool::IPTC::ApplicationRecord = (
    GROUPS => { 2 => 'Other' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
    0 => {
        Name => 'ApplicationRecordVersion',
        Format => 'int16u',
        Mandatory => 1,
    },
    3 => {
        Name => 'ObjectTypeReference',
        Format => 'string[3,67]',
    },
    4 => {
        Name => 'ObjectAttributeReference',
        Flags => 'List',
        Format => 'string[4,68]',
    },
    5 => {
        Name => 'ObjectName',
        Format => 'string[0,64]',
    },
    7 => {
        Name => 'EditStatus',
        Format => 'string[0,64]',
    },
    8 => {
        Name => 'EditorialUpdate',
        Format => 'digits[2]',
        PrintConv => {
            '01' => 'Additional language',
        },
    },
    10 => {
        Name => 'Urgency',
        Format => 'digits[1]',
        PrintConv => {
            0 => '0 (reserved)',
            1 => '1 (most urgent)',
            2 => 2,
            3 => 3,
            4 => 4,
            5 => '5 (normal urgency)',
            6 => 6,
            7 => 7,
            8 => '8 (least urgent)',
            9 => '9 (user-defined priority)',
        },
    },
    12 => {
        Name => 'SubjectReference',
        Flags => 'List',
        Format => 'string[13,236]',
    },
    15 => {
        Name => 'Category',
        Format => 'string[0,3]',
    },
    20 => {
        Name => 'SupplementalCategories',
        Flags => 'List',
        Format => 'string[0,32]',
    },
    22 => {
        Name => 'FixtureIdentifier',
        Format => 'string[0,32]',
    },
    25 => {
        Name => 'Keywords',
        Flags => 'List',
        Format => 'string[0,64]',
    },
    26 => {
        Name => 'ContentLocationCode',
        Flags => 'List',
        Groups => { 2 => 'Location' },
        Format => 'string[3]',
    },
    27 => {
        Name => 'ContentLocationName',
        Flags => 'List',
        Groups => { 2 => 'Location' },
        Format => 'string[0,64]',
    },
    30 => {
        Name => 'ReleaseDate',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    35 => {
        Name => 'ReleaseTime',
        Groups => { 2 => 'Time' },
        Format => 'string[11]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    37 => {
        Name => 'ExpirationDate',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    38 => {
        Name => 'ExpirationTime',
        Groups => { 2 => 'Time' },
        Format => 'string[11]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    40 => {
        Name => 'SpecialInstructions',
        Format => 'string[0,256]',
    },
    42 => {
        Name => 'ActionAdvised',
        Format => 'digits[2]',
        PrintConv => {
            '' => '',
            '01' => 'Object Kill',
            '02' => 'Object Replace',
            '03' => 'Object Append',
            '04' => 'Object Reference',
        },
    },
    45 => {
        Name => 'ReferenceService',
        Flags => 'List',
        Format => 'string[0,10]',
    },
    47 => {
        Name => 'ReferenceDate',
        Groups => { 2 => 'Time' },
        Flags => 'List',
        Format => 'digits[8]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    50 => {
        Name => 'ReferenceNumber',
        Flags => 'List',
        Format => 'digits[8]',
    },
    55 => {
        Name => 'DateCreated',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
        PrintConv => '$self->Options("DateFormat") ? $self->ConvertDateTime("$val 00:00:00") : $val',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    60 => {
        Name => 'TimeCreated',
        Groups => { 2 => 'Time' },
        Format => 'string[11]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
        PrintConv => '$self->Options("DateFormat") ? $self->ConvertDateTime("1970:01:01 $val") : $val',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    62 => {
        Name => 'DigitalCreationDate',
        Groups => { 2 => 'Time' },
        Format => 'digits[8]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcDate($val)',
        PrintConv => '$self->Options("DateFormat") ? $self->ConvertDateTime("$val 00:00:00") : $val',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    63 => {
        Name => 'DigitalCreationTime',
        Groups => { 2 => 'Time' },
        Format => 'string[11]',
        Shift => 'Time',
        ValueConv => 'Image::ExifTool::Exif::ExifTime($val)',
        ValueConvInv => 'Image::ExifTool::IPTC::IptcTime($val)',
        PrintConv => '$self->Options("DateFormat") ? $self->ConvertDateTime("1970:01:01 $val") : $val',
        PrintConvInv => 'Image::ExifTool::IPTC::InverseDateOrTime($self,$val)',
    },
    65 => {
        Name => 'OriginatingProgram',
        Format => 'string[0,32]',
    },
    70 => {
        Name => 'ProgramVersion',
        Format => 'string[0,10]',
    },
    75 => {
        Name => 'ObjectCycle',
        Format => 'string[1]',
        PrintConv => {
            'a' => 'Morning',
            'p' => 'Evening',
            'b' => 'Both Morning and Evening',
        },
    },
    80 => {
        Name => 'By-line',
        Flags => 'List',
        Format => 'string[0,32]',
        Groups => { 2 => 'Author' },
    },
    85 => {
        Name => 'By-lineTitle',
        Flags => 'List',
        Format => 'string[0,32]',
        Groups => { 2 => 'Author' },
    },
    90 => {
        Name => 'City',
        Format => 'string[0,32]',
        Groups => { 2 => 'Location' },
    },
    92 => {
        Name => 'Sub-location',
        Format => 'string[0,32]',
        Groups => { 2 => 'Location' },
    },
    95 => {
        Name => 'Province-State',
        Format => 'string[0,32]',
        Groups => { 2 => 'Location' },
    },
    100 => {
        Name => 'Country-PrimaryLocationCode',
        Format => 'string[3]',
        Groups => { 2 => 'Location' },
    },
    101 => {
        Name => 'Country-PrimaryLocationName',
        Format => 'string[0,64]',
        Groups => { 2 => 'Location' },
    },
    103 => {
        Name => 'OriginalTransmissionReference',
        Format => 'string[0,32]',
        Notes => 'now used as a job identifier',
    },
    105 => {
        Name => 'Headline',
        Format => 'string[0,256]',
    },
    110 => {
        Name => 'Credit',
        Groups => { 2 => 'Author' },
        Format => 'string[0,32]',
    },
    115 => {
        Name => 'Source',
        Groups => { 2 => 'Author' },
        Format => 'string[0,32]',
    },
    116 => {
        Name => 'CopyrightNotice',
        Groups => { 2 => 'Author' },
        Format => 'string[0,128]',
    },
    118 => {
        Name => 'Contact',
        Flags => 'List',
        Groups => { 2 => 'Author' },
        Format => 'string[0,128]',
    },
    120 => {
        Name => 'Caption-Abstract',
        Format => 'string[0,2000]',
    },
    121 => {
        Name => 'LocalCaption',
        Format => 'string[0,256]', # (guess)
        Notes => q{
            I haven't found a reference for the format of tags 121, 184-188 and
            225-232, so I have just make them writable as strings with
            reasonable length.  Beware that if this is wrong, other utilities
            may not be able to read these tags as written by ExifTool
        },
    },
    122 => {
        Name => 'Writer-Editor',
        Flags => 'List',
        Groups => { 2 => 'Author' },
        Format => 'string[0,32]',
    },
    125 => {
        Name => 'RasterizedCaption',
        Format => 'undef[7360]',
        Binary => 1,
    },
    130 => {
        Name => 'ImageType',
        Groups => { 2 => 'Image' },
        Format => 'string[2]',
    },
    131 => {
        Name => 'ImageOrientation',
        Groups => { 2 => 'Image' },
        Format => 'string[1]',
        PrintConv => {
            P => 'Portrait',
            L => 'Landscape',
            S => 'Square',
        },
    },
    135 => {
        Name => 'LanguageIdentifier',
        Format => 'string[2,3]',
    },
    150 => {
        Name => 'AudioType',
        Format => 'string[2]',
        PrintConv => {
            '1A' => 'Mono Actuality',
            '2A' => 'Stereo Actuality',
            '1C' => 'Mono Question and Answer Session',
            '2C' => 'Stereo Question and Answer Session',
            '1M' => 'Mono Music',
            '2M' => 'Stereo Music',
            '1Q' => 'Mono Response to a Question',
            '2Q' => 'Stereo Response to a Question',
            '1R' => 'Mono Raw Sound',
            '2R' => 'Stereo Raw Sound',
            '1S' => 'Mono Scener',
            '2S' => 'Stereo Scener',
            '0T' => 'Text Only',
            '1V' => 'Mono Voicer',
            '2V' => 'Stereo Voicer',
            '1W' => 'Mono Wrap',
            '2W' => 'Stereo Wrap',
        },
    },
    151 => {
        Name => 'AudioSamplingRate',
        Format => 'digits[6]',
    },
    152 => {
        Name => 'AudioSamplingResolution',
        Format => 'digits[2]',
    },
    153 => {
        Name => 'AudioDuration',
        Format => 'digits[6]',
    },
    154 => {
        Name => 'AudioOutcue',
        Format => 'string[0,64]',
    },
    184 => {
        Name => 'JobID',
        Format => 'string[0,64]', # (guess)
    },
    185 => {
        Name => 'MasterDocumentID',
        Format => 'string[0,256]', # (guess)
    },
    186 => {
        Name => 'ShortDocumentID',
        Format => 'string[0,64]', # (guess)
    },
    187 => {
        Name => 'UniqueDocumentID',
        Format => 'string[0,128]', # (guess)
    },
    188 => {
        Name => 'OwnerID',
        Format => 'string[0,128]', # (guess)
    },
    200 => {
        Name => 'ObjectPreviewFileFormat',
        Groups => { 2 => 'Image' },
        Format => 'int16u',
        PrintConv => \%fileFormat,
    },
    201 => {
        Name => 'ObjectPreviewFileVersion',
        Groups => { 2 => 'Image' },
        Format => 'int16u',
    },
    202 => {
        Name => 'ObjectPreviewData',
        Groups => { 2 => 'Preview' },
        Format => 'undef[0,256000]',
        Binary => 1,
    },
    221 => {
        Name => 'Prefs',
        Groups => { 2 => 'Image' },
        Format => 'string[0,64]',
        Notes => 'PhotoMechanic preferences',
        PrintConv => q{
            $val =~ s[\s*(\d+):\s*(\d+):\s*(\d+):\s*(\S*)]
                     [Tagged:$1, ColorClass:$2, Rating:$3, FrameNum:$4];
            return $val;
        },
        PrintConvInv => q{
            $val =~ s[Tagged:\s*(\d+).*ColorClass:\s*(\d+).*Rating:\s*(\d+).*FrameNum:\s*(\S*)]
                     [$1:$2:$3:$4]is;
            return $val;
        },
    },
    225 => {
        Name => 'ClassifyState',
        Format => 'string[0,64]', # (guess)
    },
    228 => {
        Name => 'SimilarityIndex',
        Format => 'string[0,32]', # (guess)
    },
    230 => {
        Name => 'DocumentNotes',
        Format => 'string[0,1024]', # (guess)
    },
    231 => {
        Name => 'DocumentHistory',
        Format => 'string[0,256]', # (guess)
        ValueConv => '$val =~ s/\0+/\n/g; $val', # (have seen embedded nulls)
        ValueConvInv => '$val',
    },
    232 => {
        Name => 'ExifCameraInfo',
        Format => 'string[0,4096]', # (guess)
    },
    255 => { #PH
        Name => 'CatalogSets',
        List => 1,
        Format => 'string[0,256]', # (guess)
        Notes => 'written by iView MediaPro',
    },
);

# Record 3 -- News photo
%Image::ExifTool::IPTC::NewsPhoto = (
    GROUPS => { 2 => 'Image' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
    0 => {
        Name => 'NewsPhotoVersion',
        Format => 'int16u',
        Mandatory => 1,
    },
    10 => {
        Name => 'IPTCPictureNumber',
        Format => 'string[16]',
        Notes => '4 numbers: 1-Manufacturer ID, 2-Equipment ID, 3-Date, 4-Sequence',
        PrintConv => 'Image::ExifTool::IPTC::ConvertPictureNumber($val)',
        PrintConvInv => 'Image::ExifTool::IPTC::InvConvertPictureNumber($val)',
    },
    20 => {
        Name => 'IPTCImageWidth',
        Format => 'int16u',
    },
    30 => {
        Name => 'IPTCImageHeight',
        Format => 'int16u',
    },
    40 => {
        Name => 'IPTCPixelWidth',
        Format => 'int16u',
    },
    50 => {
        Name => 'IPTCPixelHeight',
        Format => 'int16u',
    },
    55 => {
        Name => 'SupplementalType',
        Format => 'int8u',
        PrintConv => {
            0 => 'Main Image',
            1 => 'Reduced Resolution Image',
            2 => 'Logo',
            3 => 'Rasterized Caption',
        },
    },
    60 => {
        Name => 'ColorRepresentation',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x000 => 'No Image, Single Frame',
            0x100 => 'Monochrome, Single Frame',
            0x300 => '3 Components, Single Frame',
            0x301 => '3 Components, Frame Sequential in Multiple Objects',
            0x302 => '3 Components, Frame Sequential in One Object',
            0x303 => '3 Components, Line Sequential',
            0x304 => '3 Components, Pixel Sequential',
            0x305 => '3 Components, Special Interleaving',
            0x400 => '4 Components, Single Frame',
            0x401 => '4 Components, Frame Sequential in Multiple Objects',
            0x402 => '4 Components, Frame Sequential in One Object',
            0x403 => '4 Components, Line Sequential',
            0x404 => '4 Components, Pixel Sequential',
            0x405 => '4 Components, Special Interleaving',
        },
    },
    64 => {
        Name => 'InterchangeColorSpace',
        Format => 'int8u',
        PrintConv => {
            1 => 'X,Y,Z CIE',
            2 => 'RGB SMPTE',
            3 => 'Y,U,V (K) (D65)',
            4 => 'RGB Device Dependent',
            5 => 'CMY (K) Device Dependent',
            6 => 'Lab (K) CIE',
            7 => 'YCbCr',
            8 => 'sRGB',
        },
    },
    65 => {
        Name => 'ColorSequence',
        Format => 'int8u',
    },
    66 => {
        Name => 'ICC_Profile',
        # ...could add SubDirectory support to read into this (if anybody cares)
        Writable => 0,
        Binary => 1,
    },
    70 => {
        Name => 'ColorCalibrationMatrix',
        Writable => 0,
        Binary => 1,
    },
    80 => {
        Name => 'LookupTable',
        Writable => 0,
        Binary => 1,
    },
    84 => {
        Name => 'NumIndexEntries',
        Format => 'int16u',
    },
    85 => {
        Name => 'ColorPalette',
        Writable => 0,
        Binary => 1,
    },
    86 => {
        Name => 'IPTCBitsPerSample',
        Format => 'int8u',
    },
    90 => {
        Name => 'SampleStructure',
        Format => 'int8u',
        PrintConv => {
            0 => 'OrthogonalConstangSampling',
            1 => 'Orthogonal4-2-2Sampling',
            2 => 'CompressionDependent',
        },
    },
    100 => {
        Name => 'ScanningDirection',
        Format => 'int8u',
        PrintConv => {
            0 => 'L-R, Top-Bottom',
            1 => 'R-L, Top-Bottom',
            2 => 'L-R, Bottom-Top',
            3 => 'R-L, Bottom-Top',
            4 => 'Top-Bottom, L-R',
            5 => 'Bottom-Top, L-R',
            6 => 'Top-Bottom, R-L',
            7 => 'Bottom-Top, R-L',
        },
    },
    102 => {
        Name => 'IPTCImageRotation',
        Format => 'int8u',
        PrintConv => {
            0 => 0,
            1 => 90,
            2 => 180,
            3 => 270,
        },
    },
    110 => {
        Name => 'DataCompressionMethod',
        Format => 'int32u',
    },
    120 => {
        Name => 'QuantizationMethod',
        Format => 'int8u',
        PrintConv => {
            0 => 'Linear Reflectance/Transmittance',
            1 => 'Linear Density',
            2 => 'IPTC Ref B',
            3 => 'Linear Dot Percent',
            4 => 'AP Domestic Analogue',
            5 => 'Compression Method Specific',
            6 => 'Color Space Specific',
            7 => 'Gamma Compensated',
        },
    },
    125 => {
        Name => 'EndPoints',
        Writable => 0,
        Binary => 1,
    },
    130 => {
        Name => 'ExcursionTolerance',
        Format => 'int8u',
        PrintConv => {
            0 => 'Not Allowed',
            1 => 'Allowed',
        },
    },
    135 => {
        Name => 'BitsPerComponent',
        Format => 'int8u',
    },
    140 => {
        Name => 'MaximumDensityRange',
        Format => 'int16u',
    },
    145 => {
        Name => 'GammaCompensatedValue',
        Format => 'int16u',
    },
);

# Record 7 -- Pre-object Data
%Image::ExifTool::IPTC::PreObjectData = (
    # (not actually writable, but used in BuildTagLookup to recognize IPTC tables)
    WRITE_PROC => \&WriteIPTC,
    10 => {
        Name => 'SizeMode',
        Format => 'int8u',
        PrintConv => {
            0 => 'Size Not Known',
            1 => 'Size Known',
        },
    },
    20 => {
        Name => 'MaxSubfileSize',
        Format => 'int32u',
    },
    90 => {
        Name => 'ObjectSizeAnnounced',
        Format => 'int32u',
    },
    95 => {
        Name => 'MaximumObjectSize',
        Format => 'int32u',
    },
);

# Record 8 -- ObjectData
%Image::ExifTool::IPTC::ObjectData = (
    WRITE_PROC => \&WriteIPTC,
    10 => {
        Name => 'SubFile',
        Flags => 'List',
        Binary => 1,
    },
);

# Record 9 -- PostObjectData
%Image::ExifTool::IPTC::PostObjectData = (
    WRITE_PROC => \&WriteIPTC,
    10 => {
        Name => 'ConfirmedObjectSize',
        Format => 'int32u',
    },
);

# Record 240 -- FotoStation proprietary data (ref PH)
%Image::ExifTool::IPTC::FotoStation = (
    GROUPS => { 2 => 'Other' },
    WRITE_PROC => \&WriteIPTC,
    CHECK_PROC => \&CheckIPTC,
    WRITABLE => 1,
);

# IPTC Composite tags
%Image::ExifTool::IPTC::Composite = (
    GROUPS => { 2 => 'Image' },
    DateTimeCreated => {
        Description => 'Date/Time Created',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'IPTC:DateCreated',
            1 => 'IPTC:TimeCreated',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    DigitalCreationDateTime => {
        Description => 'Digital Creation Date/Time',
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'IPTC:DigitalCreationDate',
            1 => 'IPTC:DigitalCreationTime',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::IPTC');


#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Print conversion for CodedCharacterSet
# Inputs: 0) value
sub PrintCodedCharset($)
{
    my $val = shift;
    return $iptcCharset{$val} if $iptcCharset{$val};
    $val =~ s/(.)/ $1/g;
    $val =~ s/ \x1b/, ESC/g;
    $val =~ s/^,? //;
    return $val;
}

#------------------------------------------------------------------------------
# Handle CodedCharacterSet
# Inputs: 0) ExifTool ref, 1) CodedCharacterSet value
# Returns: IPTC character set if translation required (or 'bad' if unknown)
sub HandleCodedCharset($$)
{
    my ($et, $val) = @_;
    my $xlat = $iptcCharset{$val};
    unless ($xlat) {
        if ($val =~ /^\x1b\x25/) {
            # some unknown character set invoked
            $xlat = 'bad';  # flag unsupported coding
        } else {
            $xlat = $et->Options('CharsetIPTC');
        }
    }
    # no need to translate if Charset is the same
    undef $xlat if $xlat eq $et->Options('Charset');
    return $xlat;
}

#------------------------------------------------------------------------------
# Encode or decode coded string
# Inputs: 0) ExifTool ref, 1) value ptr, 2) IPTC charset (or 'bad') ref
#         3) flag set to decode (read) value from IPTC
# Updates value on return
sub TranslateCodedString($$$$)
{
    my ($et, $valPtr, $xlatPtr, $read) = @_;
    if ($$xlatPtr eq 'bad') {
        $et->Warn('Some IPTC characters not converted (unsupported CodedCharacterSet)');
        undef $$xlatPtr;
    } elsif (not $read) {
        $$valPtr = $et->Decode($$valPtr, undef, undef, $$xlatPtr);
    } elsif ($$valPtr !~ /[\x14\x15\x1b]/) {
        $$valPtr = $et->Decode($$valPtr, $$xlatPtr);
    } else {
        # don't yet support reading ISO 2022 shifted character sets
        $et->Warn('Some IPTC characters not converted (ISO 2022 shifting not supported)');
    }
}

#------------------------------------------------------------------------------
# Is this IPTC in a standard location?
# Inputs: 0) Current metadata path string
# Returns: true if path is standard, 0 if file type doesn't have standard IPTC,
#          or undef if IPTC is non-standard
sub IsStandardIPTC($)
{
    my $path = shift;
    return 1 if $isStandardIPTC{$path};
    return 0 unless $path =~ /^(\w+)/ and defined $isStandardIPTC{$1};
    return undef;   # non-standard
}

#------------------------------------------------------------------------------
# get IPTC info
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
#         2) reference to tag table
# Returns: 1 on success, 0 otherwise
sub ProcessIPTC($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || 0;
    my $dirEnd = $pos + $dirLen;
    my $verbose = $et->Options('Verbose');
    my $validate = $et->Options('Validate');
    my $success = 0;
    my ($lastRec, $recordPtr, $recordName);

    $verbose and $dirInfo and $et->VerboseDir('IPTC', 0, $$dirInfo{DirLen});

    if ($tagTablePtr eq \%Image::ExifTool::IPTC::Main) {
        my $path = $et->MetadataPath();
        my $isStd = IsStandardIPTC($path);
        if (defined $isStd and not $$et{DIR_COUNT}{STD_IPTC}) {
            # set flag to ensure we only have one family 1 "IPTC" group
            $$et{DIR_COUNT}{STD_IPTC} = 1;
            # calculate MD5 if Digest::MD5 is available (truly standard IPTC only)
            if ($isStd) {
                my $md5;
                if (eval { require Digest::MD5 }) {
                    if ($pos or $dirLen != length($$dataPt)) {
                        $md5 = Digest::MD5::md5(substr $$dataPt, $pos, $dirLen);
                    } else {
                        $md5 = Digest::MD5::md5($$dataPt);
                    }
                } else {
                    # a zero digest indicates IPTC exists but we don't have Digest::MD5
                    $md5 = "\0" x 16;
                }
                $et->FoundTag('CurrentIPTCDigest', $md5);
            }
        } else {
            if (($Image::ExifTool::MWG::strict or $et->Options('Validate')) and
                $$et{FILE_TYPE} =~ /^(JPEG|TIFF|PSD)$/)
            {
                if ($Image::ExifTool::MWG::strict) {
                    # ignore non-standard IPTC while in strict MWG compatibility mode
                    $et->Warn("Ignored non-standard IPTC at $path");
                    return 1;
                } else {
                    $et->Warn("Non-standard IPTC at $path", 1);
                }
            }
            # extract non-standard IPTC
            my $count = ($$et{DIR_COUNT}{IPTC} || 0) + 1;  # count non-standard IPTC
            $$et{DIR_COUNT}{IPTC} = $count;
            $$et{LOW_PRIORITY_DIR}{IPTC} = 1;       # lower priority of non-standard IPTC
            $$et{SET_GROUP1} = '+' . ($count + 1);  # add number to family 1 group name
        }
    }
    # begin by assuming default IPTC encoding
    my $xlat = $et->Options('CharsetIPTC');
    undef $xlat if $xlat eq $et->Options('Charset');

    # quick check for improperly byte-swapped IPTC
    if ($dirLen >= 4 and substr($$dataPt, $pos, 1) ne "\x1c" and
                         substr($$dataPt, $pos + 3, 1) eq "\x1c")
    {
        $et->Warn('IPTC data was improperly byte-swapped');
        my $newData = pack('N*', unpack('V*', substr($$dataPt, $pos, $dirLen) . "\0\0\0"));
        $dataPt = \$newData;
        $pos = 0;
        $dirEnd = $pos + $dirLen;
        # NOTE: MUST NOT access $dirInfo DataPt, DirStart or DataLen after this!
    }
    # extract IPTC as a block if specified
    if ($$et{REQ_TAG_LOOKUP}{iptc} or ($$et{TAGS_FROM_FILE} and
        not $$et{EXCL_TAG_LOOKUP}{iptc}))
    {
        if ($pos or $dirLen != length($$dataPt)) {
            $et->FoundTag('IPTC', substr($$dataPt, $pos, $dirLen));
        } else {
            $et->FoundTag('IPTC', $$dataPt);
        }
    }
    while ($pos + 5 <= $dirEnd) {
        my $buff = substr($$dataPt, $pos, 5);
        my ($id, $rec, $tag, $len) = unpack("CCCn", $buff);
        unless ($id == 0x1c) {
            unless ($id) {
                # scan the rest of the data an give warning unless all zeros
                # (iMatch pads the IPTC block with nulls for some reason)
                my $remaining = substr($$dataPt, $pos, $dirEnd - $pos);
                last unless $remaining =~ /[^\0]/;
            }
            $et->Warn(sprintf('Bad IPTC data tag (marker 0x%x)',$id));
            last;
        }
        $pos += 5;      # step to after field header
        # handle extended IPTC entry if necessary
        if ($len & 0x8000) {
            my $n = $len & 0x7fff; # get num bytes in length field
            if ($pos + $n > $dirEnd or $n > 8) {
                $et->VPrint(0, "Invalid extended IPTC entry (dataset $rec:$tag, len $len)\n");
                $success = 0;
                last;
            }
            # determine length (a big-endian, variable sized int)
            for ($len = 0; $n; ++$pos, --$n) {
                $len = $len * 256 + ord(substr($$dataPt, $pos, 1));
            }
        }
        if ($pos + $len > $dirEnd) {
            $et->VPrint(0, "Invalid IPTC entry (dataset $rec:$tag, len $len)\n");
            $success = 0;
            last;
        }
        if (not defined $lastRec or $lastRec != $rec) {
            if ($validate and defined $lastRec and $rec < $lastRec) {
                $et->Warn("IPTC doesn't conform to spec: Records out of sequence",1)
            }
            my $tableInfo = $tagTablePtr->{$rec};
            unless ($tableInfo) {
                $et->Warn("Unrecognized IPTC record $rec (ignored)");
                $pos += $len;
                next;   # ignore this entry
            }
            my $tableName = $tableInfo->{SubDirectory}->{TagTable};
            unless ($tableName) {
                $et->Warn("No table for IPTC record $rec!");
                last;   # this shouldn't happen
            }
            $recordName = $$tableInfo{Name};
            $recordPtr = Image::ExifTool::GetTagTable($tableName);
            $et->VPrint(0,$$et{INDENT},"-- $recordName record --\n");
            $lastRec = $rec;
        }
        my $val = substr($$dataPt, $pos, $len);

        # add tagInfo for all unknown tags:
        unless ($$recordPtr{$tag}) {
            # - no Format so format is auto-detected
            # - no Name so name is generated automatically with decimal tag number
            AddTagToTable($recordPtr, $tag, { Unknown => 1 });
        }

        my $tagInfo = $et->GetTagInfo($recordPtr, $tag);
        my $format;
        # (could use $$recordPtr{FORMAT} if no Format below, but don't do this to
        #  be backward compatible with improperly written PhotoMechanic tags)
        $format = $$tagInfo{Format} if $tagInfo;
        if (not $format) {
            # guess at "int" format if not specified
            $format = 'int' if $len <= 4 and $len != 3 and $val =~ /[\0-\x08]/;
        } elsif ($validate) {
            my ($fmt,$min,$max);
            if ($format =~ /(.*)\[(\d+)(,(\d+))?\]/) {
                $fmt = $1;
                $min = $2;
                $max = $4 || $2;
            } else {
                $fmt = $format;
                $min = $max = 1;
            }
            my $siz = Image::ExifTool::FormatSize($fmt) || 1;
            $min *= $siz; $max *= $siz;
            if ($len < $min or $len > $max) {
                my $should = ($min == $max) ? $min : ($len < $min ? "$min min" : "$max max");
                my $what = ($len < $siz * $min) ? 'short' : 'long';
                $et->Warn("IPTC $$tagInfo{Name} too $what ($len bytes; should be $should)", 1);
            }
        }
        if ($format) {
            if ($format =~ /^int/) {
                if ($len <= 8) {    # limit integer conversion to 8 bytes long
                    $val = 0;
                    my $i;
                    for ($i=0; $i<$len; ++$i) {
                        $val = $val * 256 + ord(substr($$dataPt, $pos+$i, 1));
                    }
                }
            } elsif ($format =~ /^string/) {
                # some braindead softwares add null terminators
                if ($val =~ s/\0+$// and $validate) {
                    $et->Warn("IPTC $$tagInfo{Name} improperly terminated", 1);
                }
                if ($rec == 1) {
                    # handle CodedCharacterSet tag
                    $xlat = HandleCodedCharset($et, $val) if $tag == 90;
                # translate characters if necessary and special characters exist
                } elsif ($xlat and $rec < 7 and $val =~ /[\x80-\xff]/) {
                    # translate to specified character set
                    TranslateCodedString($et, \$val, \$xlat, 1);
                }
            } elsif ($format =~ /^digits/) {
                if ($val =~ s/\0+$// and $validate) {
                    $et->Warn("IPTC $$tagInfo{Name} improperly terminated", 1);
                }
            } elsif ($format !~ /^undef/) {
                warn("Invalid IPTC format: $format");   # (this would be a programming error)
            }
        }
        $verbose and $et->VerboseInfo($tag, $tagInfo,
            Table   => $tagTablePtr,
            Value   => $val,
            DataPt  => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Size    => $len,
            Start   => $pos,
            Extra   => ", $recordName record",
            Format  => $format,
        );
        $et->FoundTag($tagInfo, $val) if $tagInfo;
        $success = 1;

        $pos += $len;   # increment to next field
    }
    delete $$et{SET_GROUP1};
    delete $$et{LOW_PRIORITY_DIR}{IPTC};
    return $success;
}

1; # end


__END__

=head1 NAME

Image::ExifTool::IPTC - Read IPTC meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
IPTC (International Press Telecommunications Council) meta information in
image files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.iptc.org/IIM/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/IPTC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
