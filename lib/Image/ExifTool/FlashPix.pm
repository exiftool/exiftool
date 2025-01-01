#------------------------------------------------------------------------------
# File:         FlashPix.pm
#
# Description:  Read FlashPix meta information
#
# Revisions:    05/29/2006 - P. Harvey Created
#
# References:   1) http://www.exif.org/Exif2-2.PDF
#               2) http://www.graphcomp.com/info/specs/livepicture/fpx.pdf
#               3) http://search.cpan.org/~jdb/libwin32/
#               4) http://msdn.microsoft.com/en-us/library/aa380374.aspx
#               5) http://www.cpan.org/modules/by-authors/id/H/HC/HCARVEY/File-MSWord-0.1.zip
#               6) https://msdn.microsoft.com/en-us/library/cc313153(v=office.12).aspx
#               7) https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-oshared/3ef02e83-afef-4b6c-9585-c109edd24e07
#------------------------------------------------------------------------------

package Image::ExifTool::FlashPix;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::ASF;   # for GetGUID()

$VERSION = '1.49';

sub ProcessFPX($$);
sub ProcessFPXR($$$);
sub ProcessProperties($$$);
sub ReadFPXValue($$$$$;$$);
sub ProcessHyperlinks($$);
sub ProcessContents($$$);
sub ProcessWordDocument($$$);
sub ProcessDocumentTable($);
sub ProcessCommentBy($$$);
sub ProcessLastSavedBy($$$);
sub SetDocNum($$;$$$);
sub ConvertDTTM($);

# sector type constants
sub HDR_SIZE           () { 512; }
sub DIF_SECT           () { 0xfffffffc; }
sub FAT_SECT           () { 0xfffffffd; }
sub END_OF_CHAIN       () { 0xfffffffe; }
sub FREE_SECT          () { 0xffffffff; }

# format flags
sub VT_VECTOR          () { 0x1000; }
sub VT_ARRAY           () { 0x2000; }
sub VT_BYREF           () { 0x4000; }
sub VT_RESERVED        () { 0x8000; }

# other constants
sub VT_VARIANT         () { 12; }
sub VT_LPSTR           () { 30; }

# list of OLE format codes (unsupported codes commented out)
my %oleFormat = (
    0  => undef,        # VT_EMPTY
    1  => undef,        # VT_NULL
    2  => 'int16s',     # VT_I2
    3  => 'int32s',     # VT_I4
    4  => 'float',      # VT_R4
    5  => 'double',     # VT_R8
    6  => undef,        # VT_CY
    7  => 'VT_DATE',    # VT_DATE (double, number of days since Dec 30, 1899)
    8  => 'VT_BSTR',    # VT_BSTR (int32u count, followed by binary string)
#   9  => 'VT_DISPATCH',
    10 => 'int32s',     # VT_ERROR
    11 => 'int16s',     # VT_BOOL
    12 => 'VT_VARIANT', # VT_VARIANT
#   13 => 'VT_UNKNOWN',
#   14 => 'VT_DECIMAL',
    16 => 'int8s',      # VT_I1
    17 => 'int8u',      # VT_UI1
    18 => 'int16u',     # VT_UI2
    19 => 'int32u',     # VT_UI4
    20 => 'int64s',     # VT_I8
    21 => 'int64u',     # VT_UI8
#   22 => 'VT_INT',
#   23 => 'VT_UINT',
#   24 => 'VT_VOID',
#   25 => 'VT_HRESULT',
#   26 => 'VT_PTR',
#   27 => 'VT_SAFEARRAY',
#   28 => 'VT_CARRAY',
#   29 => 'VT_USERDEFINED',
    30 => 'VT_LPSTR',   # VT_LPSTR (int32u count, followed by string)
    31 => 'VT_LPWSTR',  # VT_LPWSTR (int32u word count, followed by Unicode string)
    64 => 'VT_FILETIME',# VT_FILETIME (int64u, 100 ns increments since Jan 1, 1601)
    65 => 'VT_BLOB',    # VT_BLOB
#   66 => 'VT_STREAM',
#   67 => 'VT_STORAGE',
#   68 => 'VT_STREAMED_OBJECT',
#   69 => 'VT_STORED_OBJECT',
#   70 => 'VT_BLOB_OBJECT',
    71 => 'VT_CF',      # VT_CF
    72 => 'VT_CLSID',   # VT_CLSID
);

# OLE flag codes (high nibble of property type)
my %oleFlags = (
    0x1000 => 'VT_VECTOR',
    0x2000 => 'VT_ARRAY',   # not yet supported
    0x4000 => 'VT_BYREF',   # ditto
    0x8000 => 'VT_RESERVED',
);

# byte sizes for supported VT_* format and flag types
my %oleFormatSize = (
    VT_DATE     => 8,
    VT_BSTR     => 4,   # (+ string length)
    VT_VARIANT  => 4,   # (+ data length)
    VT_LPSTR    => 4,   # (+ string length)
    VT_LPWSTR   => 4,   # (+ string character length)
    VT_FILETIME => 8,
    VT_BLOB     => 4,   # (+ data length)
    VT_CF       => 4,   # (+ data length)
    VT_CLSID    => 16,
    VT_VECTOR   => 4,   # (+ vector elements)
);

# names for each type of directory entry
my @dirEntryType = qw(INVALID STORAGE STREAM LOCKBYTES PROPERTY ROOT);

# list of code pages used by Microsoft
# (ref http://msdn.microsoft.com/en-us/library/dd317756(VS.85).aspx)
my %codePage = (
     37 => 'IBM EBCDIC US-Canada',
    437 => 'DOS United States',
    500 => 'IBM EBCDIC International',
    708 => 'Arabic (ASMO 708)',
    709 => 'Arabic (ASMO-449+, BCON V4)',
    710 => 'Arabic - Transparent Arabic',
    720 => 'DOS Arabic (Transparent ASMO)',
    737 => 'DOS Greek (formerly 437G)',
    775 => 'DOS Baltic',
    850 => 'DOS Latin 1 (Western European)',
    852 => 'DOS Latin 2 (Central European)',
    855 => 'DOS Cyrillic (primarily Russian)',
    857 => 'DOS Turkish',
    858 => 'DOS Multilingual Latin 1 with Euro',
    860 => 'DOS Portuguese',
    861 => 'DOS Icelandic',
    862 => 'DOS Hebrew',
    863 => 'DOS French Canadian',
    864 => 'DOS Arabic',
    865 => 'DOS Nordic',
    866 => 'DOS Russian (Cyrillic)',
    869 => 'DOS Modern Greek',
    870 => 'IBM EBCDIC Multilingual/ROECE (Latin 2)',
    874 => 'Windows Thai (same as 28605, ISO 8859-15)',
    875 => 'IBM EBCDIC Greek Modern',
    932 => 'Windows Japanese (Shift-JIS)',
    936 => 'Windows Simplified Chinese (PRC, Singapore)',
    949 => 'Windows Korean (Unified Hangul Code)',
    950 => 'Windows Traditional Chinese (Taiwan)',
    1026 => 'IBM EBCDIC Turkish (Latin 5)',
    1047 => 'IBM EBCDIC Latin 1/Open System',
    1140 => 'IBM EBCDIC US-Canada with Euro',
    1141 => 'IBM EBCDIC Germany with Euro',
    1142 => 'IBM EBCDIC Denmark-Norway with Euro',
    1143 => 'IBM EBCDIC Finland-Sweden with Euro',
    1144 => 'IBM EBCDIC Italy with Euro',
    1145 => 'IBM EBCDIC Latin America-Spain with Euro',
    1146 => 'IBM EBCDIC United Kingdom with Euro',
    1147 => 'IBM EBCDIC France with Euro',
    1148 => 'IBM EBCDIC International with Euro',
    1149 => 'IBM EBCDIC Icelandic with Euro',
    1200 => 'Unicode UTF-16, little endian',
    1201 => 'Unicode UTF-16, big endian',
    1250 => 'Windows Latin 2 (Central European)',
    1251 => 'Windows Cyrillic',
    1252 => 'Windows Latin 1 (Western European)',
    1253 => 'Windows Greek',
    1254 => 'Windows Turkish',
    1255 => 'Windows Hebrew',
    1256 => 'Windows Arabic',
    1257 => 'Windows Baltic',
    1258 => 'Windows Vietnamese',
    1361 => 'Korean (Johab)',
    10000 => 'Mac Roman (Western European)',
    10001 => 'Mac Japanese',
    10002 => 'Mac Traditional Chinese',
    10003 => 'Mac Korean',
    10004 => 'Mac Arabic',
    10005 => 'Mac Hebrew',
    10006 => 'Mac Greek',
    10007 => 'Mac Cyrillic',
    10008 => 'Mac Simplified Chinese',
    10010 => 'Mac Romanian',
    10017 => 'Mac Ukrainian',
    10021 => 'Mac Thai',
    10029 => 'Mac Latin 2 (Central European)',
    10079 => 'Mac Icelandic',
    10081 => 'Mac Turkish',
    10082 => 'Mac Croatian',
    12000 => 'Unicode UTF-32, little endian',
    12001 => 'Unicode UTF-32, big endian',
    20000 => 'CNS Taiwan',
    20001 => 'TCA Taiwan',
    20002 => 'Eten Taiwan',
    20003 => 'IBM5550 Taiwan',
    20004 => 'TeleText Taiwan',
    20005 => 'Wang Taiwan',
    20105 => 'IA5 (IRV International Alphabet No. 5, 7-bit)',
    20106 => 'IA5 German (7-bit)',
    20107 => 'IA5 Swedish (7-bit)',
    20108 => 'IA5 Norwegian (7-bit)',
    20127 => 'US-ASCII (7-bit)',
    20261 => 'T.61',
    20269 => 'ISO 6937 Non-Spacing Accent',
    20273 => 'IBM EBCDIC Germany',
    20277 => 'IBM EBCDIC Denmark-Norway',
    20278 => 'IBM EBCDIC Finland-Sweden',
    20280 => 'IBM EBCDIC Italy',
    20284 => 'IBM EBCDIC Latin America-Spain',
    20285 => 'IBM EBCDIC United Kingdom',
    20290 => 'IBM EBCDIC Japanese Katakana Extended',
    20297 => 'IBM EBCDIC France',
    20420 => 'IBM EBCDIC Arabic',
    20423 => 'IBM EBCDIC Greek',
    20424 => 'IBM EBCDIC Hebrew',
    20833 => 'IBM EBCDIC Korean Extended',
    20838 => 'IBM EBCDIC Thai',
    20866 => 'Russian/Cyrillic (KOI8-R)',
    20871 => 'IBM EBCDIC Icelandic',
    20880 => 'IBM EBCDIC Cyrillic Russian',
    20905 => 'IBM EBCDIC Turkish',
    20924 => 'IBM EBCDIC Latin 1/Open System with Euro',
    20932 => 'Japanese (JIS 0208-1990 and 0121-1990)',
    20936 => 'Simplified Chinese (GB2312)',
    20949 => 'Korean Wansung',
    21025 => 'IBM EBCDIC Cyrillic Serbian-Bulgarian',
    21027 => 'Extended Alpha Lowercase (deprecated)',
    21866 => 'Ukrainian/Cyrillic (KOI8-U)',
    28591 => 'ISO 8859-1 Latin 1 (Western European)',
    28592 => 'ISO 8859-2 (Central European)',
    28593 => 'ISO 8859-3 Latin 3',
    28594 => 'ISO 8859-4 Baltic',
    28595 => 'ISO 8859-5 Cyrillic',
    28596 => 'ISO 8859-6 Arabic',
    28597 => 'ISO 8859-7 Greek',
    28598 => 'ISO 8859-8 Hebrew (Visual)',
    28599 => 'ISO 8859-9 Turkish',
    28603 => 'ISO 8859-13 Estonian',
    28605 => 'ISO 8859-15 Latin 9',
    29001 => 'Europa 3',
    38598 => 'ISO 8859-8 Hebrew (Logical)',
    50220 => 'ISO 2022 Japanese with no halfwidth Katakana (JIS)',
    50221 => 'ISO 2022 Japanese with halfwidth Katakana (JIS-Allow 1 byte Kana)',
    50222 => 'ISO 2022 Japanese JIS X 0201-1989 (JIS-Allow 1 byte Kana - SO/SI)',
    50225 => 'ISO 2022 Korean',
    50227 => 'ISO 2022 Simplified Chinese',
    50229 => 'ISO 2022 Traditional Chinese',
    50930 => 'EBCDIC Japanese (Katakana) Extended',
    50931 => 'EBCDIC US-Canada and Japanese',
    50933 => 'EBCDIC Korean Extended and Korean',
    50935 => 'EBCDIC Simplified Chinese Extended and Simplified Chinese',
    50936 => 'EBCDIC Simplified Chinese',
    50937 => 'EBCDIC US-Canada and Traditional Chinese',
    50939 => 'EBCDIC Japanese (Latin) Extended and Japanese',
    51932 => 'EUC Japanese',
    51936 => 'EUC Simplified Chinese',
    51949 => 'EUC Korean',
    51950 => 'EUC Traditional Chinese',
    52936 => 'HZ-GB2312 Simplified Chinese',
    54936 => 'Windows XP and later: GB18030 Simplified Chinese (4 byte)',
    57002 => 'ISCII Devanagari',
    57003 => 'ISCII Bengali',
    57004 => 'ISCII Tamil',
    57005 => 'ISCII Telugu',
    57006 => 'ISCII Assamese',
    57007 => 'ISCII Oriya',
    57008 => 'ISCII Kannada',
    57009 => 'ISCII Malayalam',
    57010 => 'ISCII Gujarati',
    57011 => 'ISCII Punjabi',
    65000 => 'Unicode (UTF-7)',
    65001 => 'Unicode (UTF-8)',
);

# test for file extensions which may be variants of the FPX format
# (have seen one password-protected DOCX file that is FPX-like, so assume
#  that all the rest could be as well)
my %fpxFileType = (
    DOC => 1,  DOCX => 1,  DOCM => 1,
    DOT => 1,  DOTX => 1,  DOTM => 1,
    POT => 1,  POTX => 1,  POTM => 1,
    PPS => 1,  PPSX => 1,  PPSM => 1,
    PPT => 1,  PPTX => 1,  PPTM => 1,  THMX => 1,
    XLA => 1,  XLAM => 1,
    XLS => 1,  XLSX => 1,  XLSM => 1,  XLSB => 1,
    XLT => 1,  XLTX => 1,  XLTM => 1,
    # non MSOffice types
    FLA => 1,  VSD  => 1,
);

%Image::ExifTool::FlashPix::Main = (
    PROCESS_PROC => \&ProcessFPXR,
    GROUPS => { 2 => 'Image' },
    VARS => { LONG_TAGS => 0 },
    NOTES => q{
        The FlashPix file format, introduced in 1996, was developed by Kodak,
        Hewlett-Packard and Microsoft.  Internally the FPX file structure mimics
        that of an old DOS disk with fixed-sized "sectors" (usually 512 bytes) and a
        "file allocation table" (FAT).  No wonder this image format never became
        popular.  However, some of the structures used in FlashPix streams are part
        of the EXIF specification, and are still being used in the APP2 FPXR segment
        of JPEG images by some digital cameras from manufacturers such as FujiFilm,
        Hewlett-Packard, Kodak and Sanyo.

        ExifTool extracts FlashPix information from both FPX images and the APP2
        FPXR segment of JPEG images.  As well, FlashPix information is extracted
        from DOC, PPT, XLS (Microsoft Word, PowerPoint and Excel) documents, VSD
        (Microsoft Visio) drawings, and FLA (Macromedia/Adobe Flash project) files
        since these are based on the same file format as FlashPix (the Windows
        Compound Binary File format).  Note that ExifTool identifies any
        unrecognized Windows Compound Binary file as a FlashPix (FPX) file.  See
        L<http://graphcomp.com/info/specs/livepicture/fpx.pdf> for the FlashPix
        specification.

        Note that Microsoft is not consistent with the time zone used for some
        date/time tags, and it may be either UTC or local time depending on the
        software used to create the file.
    },
    "\x05SummaryInformation" => {
        Name => 'SummaryInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::SummaryInfo',
        },
    },
    "\x05DocumentSummaryInformation" => {
        Name => 'DocumentInfo',
        Multi => 1, # flag to process UserDefined information after this
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::DocumentInfo',
        },
    },
    "\x01CompObj" => {
        Name => 'CompObj',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::CompObj',
            DirStart => 0x1c,   # skip stream header
        },
    },
    "\x05Image Info" => {
        Name => 'ImageInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::ImageInfo',
        },
    },
    "\x05Image Contents" => {
        Name => 'Image',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::Image',
        },
    },
    "Contents" => {
        Name => 'Contents',
        Notes => 'found in FLA files; may contain XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            ProcessProc => \&ProcessContents,
        },
    },
    "ICC Profile 0001" => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            DirStart => 0x1c,   # skip stream header
        },
    },
    "\x05Extension List" => {
        Name => 'Extensions',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::Extensions',
        },
    },
    'Subimage 0000 Header' => {
        Name => 'SubimageHdr',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::SubimageHdr',
            DirStart => 0x1c,   # skip stream header
        },
    },
#   'Subimage 0000 Data'
    "\x05Data Object" => {  # plus instance number (eg. " 000000")
        Name => 'DataObject',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::DataObject',
        },
    },
#   "\x05Data Object Store" => { # plus instance number (eg. " 000000")
    "\x05Transform" => {    # plus instance number (eg. " 000000")
        Name => 'Transform',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::Transform',
        },
    },
    "\x05Operation" => {    # plus instance number (eg. " 000000")
        Name => 'Operation',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::Operation',
        },
    },
    "\x05Global Info" => {
        Name => 'GlobalInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::GlobalInfo',
        },
    },
    "\x05Screen Nail" => { # plus class ID (eg. "_bd0100609719a180")
        Name => 'ScreenNail',
        Groups => { 2 => 'Other' },
        # strip off stream header
        ValueConv => 'length($val) > 0x1c and $val = substr($val, 0x1c); \$val',
    },
    "\x05Audio Info" => {
        Name => 'AudioInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::AudioInfo',
        },
    },
    'Audio Stream' => { # plus instance number (eg. " 000000")
        Name => 'AudioStream',
        Groups => { 2 => 'Audio' },
        # strip off stream header
        ValueConv => 'length($val) > 0x1c and $val = substr($val, 0x1c); \$val',
    },
    'Current User' => { #PH
        Name => 'CurrentUser',
        # not sure what the rest of this data is, but extract ASCII name from it - PH
        ValueConv => q{
            return undef if length $val < 12;
            my ($size,$pos) = unpack('x4VV', $val);
            my $len = $size - $pos - 4;
            return undef if $len < 0 or length $val < $size + 8;
            return substr($val, 8 + $pos, $len);
        },
    },
    'WordDocument' => {
        Name => 'WordDocument',
        SubDirectory => { TagTable => 'Image::ExifTool::FlashPix::WordDocument' },
    },
    # save these tables until after the WordDocument was processed
    '0Table' => {
        Name => 'Table0',
        Hidden => 1, # (used only as temporary storage until table is processed)
        Binary => 1,
    },
    '1Table' => {
        Name => 'Table1',
        Hidden => 1, # (used only as temporary storage until table is processed)
        Binary => 1,
    },
    Preview => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
        Notes => 'written by some FujiFilm models',
        # skip 47-byte Fuji header
        RawConv => q{
            return undef unless length $val > 47;
            $val = substr($val, 47);
            return $val =~ /^\xff\xd8\xff/ ? $val : undef;
        },
    },
    Property => {
        Name => 'PreviewInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::PreviewInfo',
            ByteOrder => 'BigEndian',
        },
    },
    # recognize Autodesk Revit files by looking at BasicFileInfo
    # (but don't yet support reading their metatdata)
    BasicFileInfo => {
        Name => 'BasicFileInfo',
        Binary => 1,
        RawConv => q{
            $val =~ tr/\0//d;   # brute force conversion to ASCII
            if ($val =~ /\.(rfa|rft|rte|rvt)/) {
                $self->OverrideFileType(uc($1), "application/$1", $1);
            }
            return $val;
        },
    },
    IeImg => {
        Name => 'EmbeddedImage',
        Notes => q{
            embedded images in Scene7 vignette VNT files.  The EmbeddedImage Class and
            Rectangle are also extracted for applicable images, and may be associated
            with the corresponding EmbeddedImage via the family 3 group name
        },
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    IeImg_class => {
        Name => 'EmbeddedImageClass',
        Notes => q{
            not a real tag.  This information is extracted if available for the
            corresponding EmbeddedImage from the Contents of a VNT file
        },
        # eg. "Cache", "Mask"
    },
    IeImg_rect => { #
        Name => 'EmbeddedImageRectangle',
        Notes => q{
            not a real tag.  This information is extracted if available for the
            corresponding EmbeddedImage from the Contents of a VNT file
        },
    },
    _eeJPG => {
        Name => 'EmbeddedImage',
        Notes => q{
            Not a real tag. Extracted from stream content when the ExtractEmbedded
            option is used
        },
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    _eePNG => {
        Name => 'EmbeddedPNG',
        Notes => q{
            Not a real tag. Extracted from stream content when the ExtractEmbedded
            option is used
        },
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    _eeLink => {
        Name => 'LinkedFileName',
        Notes => q{
            Not a real tag. Extracted from stream content when the ExtractEmbedded
            option is used
        },
    },
);

# Summary Information properties
%Image::ExifTool::FlashPix::SummaryInfo = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        The Dictionary, CodePage and LocalIndicator tags are common to all FlashPix
        property tables, even though they are only listed in the SummaryInfo table.
    },
    0x00 => { Name => 'Dictionary',     Groups => { 2 => 'Other' }, Binary => 1 },
    0x01 => {
        Name => 'CodePage',
        Groups => { 2 => 'Other' },
        PrintConv => \%codePage,
    },
    0x02 => 'Title',
    0x03 => 'Subject',
    0x04 => { Name => 'Author',         Groups => { 2 => 'Author' } },
    0x05 => 'Keywords',
    0x06 => 'Comments',
    0x07 => 'Template',
    0x08 => { Name => 'LastModifiedBy', Groups => { 2 => 'Author' } },
    0x09 => 'RevisionNumber',
    0x0a => { Name => 'TotalEditTime',  PrintConv => 'ConvertTimeSpan($val)' }, # (in sec)
    0x0b => { Name => 'LastPrinted',    Groups => { 2 => 'Time' } },
    0x0c => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x0d => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x0e => 'Pages',
    0x0f => 'Words',
    0x10 => 'Characters',
    0x11 => {
        Name => 'ThumbnailClip',
        # (not a displayable format, so not in the "Preview" group)
        Binary => 1,
    },
    0x12 => {
        Name => 'Software',
        RawConv => '$$self{Software} = $val', # (use to determine file type)
    },
    0x13 => {
        Name => 'Security',
        # see http://msdn.microsoft.com/en-us/library/aa379255(VS.85).aspx
        PrintConv => {
            0 => 'None',
            BITMASK => {
                0 => 'Password protected',
                1 => 'Read-only recommended',
                2 => 'Read-only enforced',
                3 => 'Locked for annotations',
            },
        },
    },
    0x22 => { Name => 'CreatedBy', Groups => { 2 => 'Author' } }, #PH (guess) (MAX files)
    0x23 => 'DocumentID', # PH (guess) (MAX files)
  # 0x25 ? seen values 1.0-1.97 (MAX files)
    0x80000000 => { Name => 'LocaleIndicator', Groups => { 2 => 'Other' } },
);

# Document Summary Information properties (ref 4)
%Image::ExifTool::FlashPix::DocumentInfo = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        The DocumentSummaryInformation property set includes a UserDefined property
        set for which only the Hyperlinks and HyperlinkBase tags are pre-defined.
        However, ExifTool will also extract any other information found in the
        UserDefined properties.
    },
  # 0x01 => 'CodePage', #7
    0x02 => 'Category',
    0x03 => 'PresentationTarget',
    0x04 => 'Bytes',
    0x05 => 'Lines',
    0x06 => 'Paragraphs',
    0x07 => 'Slides',
    0x08 => 'Notes',
    0x09 => 'HiddenSlides',
    0x0a => 'MMClips',
    0x0b => {
        Name => 'ScaleCrop',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x0c => 'HeadingPairs',
    0x0d => {
        Name => 'TitleOfParts',
        # look for "3ds Max" software name at beginning of TitleOfParts
        RawConv => q{
            (ref $val eq 'ARRAY' ? $$val[0] : $val) =~ /^(3ds Max)/ and $$self{Software} = $1;
            return $val;
        }
    },
    0x0e => 'Manager',
    0x0f => 'Company',
    0x10 => {
        Name => 'LinksUpToDate',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x11 => 'CharCountWithSpaces',
  # 0x12 ? seen -32.1850395202637,-386.220672607422,-9.8100004196167,-9810,...
    0x13 => { #PH (unconfirmed)
        Name => 'SharedDoc',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
  # 0x14 ? seen -1
  # 0x15 ? seen 1
    0x16 => {
        Name => 'HyperlinksChanged',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x17 => { #PH (unconfirmed handling of lower 16 bits, not valid for MAX files)
        Name => 'AppVersion',
        ValueConv => 'sprintf("%d.%.4d",$val >> 16, $val & 0xffff)',
    },
  # 0x18 ? seen -1 (DigitalSignature, VtDigSig format, ref 7)
  # 0x19 ? seen 0
  # 0x1a ? seen 0
  # 0x1b ? seen 0
  # 0x1c ? seen 0,1
  # 0x1d ? seen 1
    0x1a => 'ContentType', #7, github#217
    0x1b => 'ContentStatus', #7, github#217
    0x1c => 'Language', #7, github#217
    0x1d => 'DocVersion', #7, github#217
  # 0x1e ? seen 1
  # 0x1f ? seen 1,5
  # 0x20 ? seen 0,5
  # 0x21 ? seen -1
  # 0x22 ? seen 0
   '_PID_LINKBASE' => {
        Name => 'HyperlinkBase',
        ValueConv => '$self->Decode($val, "UCS2","II")',
    },
   '_PID_HLINKS' => {
        Name => 'Hyperlinks',
        RawConv => \&ProcessHyperlinks,
    },
);

# Image Information properties
%Image::ExifTool::FlashPix::ImageInfo = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Image' },
    0x21000000 => {
        Name => 'FileSource',
        PrintConv => {
            1 => 'Film Scanner',
            2 => 'Reflection Print Scanner',
            3 => 'Digital Camera',
            4 => 'Video Capture',
            5 => 'Computer Graphics',
        },
    },
    0x21000001 => {
        Name => 'SceneType',
        PrintConv => {
            1 => 'Original Scene',
            2 => 'Second Generation Scene',
            3 => 'Digital Scene Generation',
        },
    },
    0x21000002 => 'CreationPathVector',
    0x21000003 => 'SoftwareRelease',
    0x21000004 => 'UserDefinedID',
    0x21000005 => 'SharpnessApproximation',
    0x22000000 => { Name => 'Copyright',                 Groups => { 2 => 'Author' } },
    0x22000001 => { Name => 'OriginalImageBroker',       Groups => { 2 => 'Author' } },
    0x22000002 => { Name => 'DigitalImageBroker',        Groups => { 2 => 'Author' } },
    0x22000003 => { Name => 'Authorship',                Groups => { 2 => 'Author' } },
    0x22000004 => { Name => 'IntellectualPropertyNotes', Groups => { 2 => 'Author' } },
    0x23000000 => {
        Name => 'TestTarget',
        PrintConv => {
            1 => 'Color Chart',
            2 => 'Gray Card',
            3 => 'Grayscale',
            4 => 'Resolution Chart',
            5 => 'Inch Scale',
            6 => 'Centimeter Scale',
            7 => 'Millimeter Scale',
            8 => 'Micrometer Scale',
        },
    },
    0x23000002 => 'GroupCaption',
    0x23000003 => 'CaptionText',
    0x23000004 => 'People',
    0x23000007 => 'Things',
    0x2300000A => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x2300000B => 'Events',
    0x2300000C => 'Places',
    0x2300000F => 'ContentDescriptionNotes',
    0x24000000 => { Name => 'Make',             Groups => { 2 => 'Camera' } },
    0x24000001 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Groups => { 2 => 'Camera' },
    },
    0x24000002 => { Name => 'SerialNumber',     Groups => { 2 => 'Camera' } },
    0x25000000 => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x25000001 => {
        Name => 'ExposureTime',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x25000002 => {
        Name => 'FNumber',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x25000003 => {
        Name => 'ExposureProgram',
        Groups => { 2 => 'Camera' },
        # use PrintConv of corresponding EXIF tag
        PrintConv => $Image::ExifTool::Exif::Main{0x8822}->{PrintConv},
    },
    0x25000004 => 'BrightnessValue',
    0x25000005 => 'ExposureCompensation',
    0x25000006 => {
        Name => 'SubjectDistance',
        Groups => { 2 => 'Camera' },
        PrintConv => 'sprintf("%.3f m", $val)',
    },
    0x25000007 => {
        Name => 'MeteringMode',
        Groups => { 2 => 'Camera' },
        PrintConv => $Image::ExifTool::Exif::Main{0x9207}->{PrintConv},
    },
    0x25000008 => {
        Name => 'LightSource',
        Groups => { 2 => 'Camera' },
        PrintConv => $Image::ExifTool::Exif::Main{0x9208}->{PrintConv},
    },
    0x25000009 => {
        Name => 'FocalLength',
        Groups => { 2 => 'Camera' },
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    0x2500000A => {
        Name => 'MaxApertureValue',
        Groups => { 2 => 'Camera' },
        ValueConv => '2 ** ($val / 2)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x2500000B => {
        Name => 'Flash',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'No Flash',
            2 => 'Flash Fired',
        },
    },
    0x2500000C => {
        Name => 'FlashEnergy',
        Groups => { 2 => 'Camera' },
    },
    0x2500000D => {
        Name => 'FlashReturn',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            1 => 'Subject Outside Flash Range',
            2 => 'Subject Inside Flash Range',
        },
    },
    0x2500000E => {
        Name => 'BackLight',
        PrintConv => {
            1 => 'Front Lit',
            2 => 'Back Lit 1',
            3 => 'Back Lit 2',
        },
    },
    0x2500000F => { Name => 'SubjectLocation', Groups => { 2 => 'Camera' } },
    0x25000010 => 'ExposureIndex',
    0x25000011 => {
        Name => 'SpecialEffectsOpticalFilter',
        PrintConv => {
            1 => 'None',
            2 => 'Colored',
            3 => 'Diffusion',
            4 => 'Multi-image',
            5 => 'Polarizing',
            6 => 'Split-field',
            7 => 'Star',
        },
    },
    0x25000012 => 'PerPictureNotes',
    0x26000000 => {
        Name => 'SensingMethod',
        Groups => { 2 => 'Camera' },
        PrintConv => $Image::ExifTool::Exif::Main{0x9217}->{PrintConv},
    },
    0x26000001 => { Name => 'FocalPlaneXResolution', Groups => { 2 => 'Camera' } },
    0x26000002 => { Name => 'FocalPlaneYResolution', Groups => { 2 => 'Camera' } },
    0x26000003 => {
        Name => 'FocalPlaneResolutionUnit',
        Groups => { 2 => 'Camera' },
        PrintConv => $Image::ExifTool::Exif::Main{0xa210}->{PrintConv},
    },
    0x26000004 => 'SpatialFrequencyResponse',
    0x26000005 => 'CFAPattern',
    0x27000001 => {
        Name => 'FilmCategory',
        PrintConv => {
            1 => 'Negative B&W',
            2 => 'Negative Color',
            3 => 'Reversal B&W',
            4 => 'Reversal Color',
            5 => 'Chromagenic',
            6 => 'Internegative B&W',
            7 => 'Internegative Color',
        },
    },
    0x26000007 => 'ISO',
    0x26000008 => 'Opto-ElectricConvFactor',
    0x27000000 => 'FilmBrand',
    0x27000001 => 'FilmCategory',
    0x27000002 => 'FilmSize',
    0x27000003 => 'FilmRollNumber',
    0x27000004 => 'FilmFrameNumber',
    0x29000000 => 'OriginalScannedImageSize',
    0x29000001 => 'OriginalDocumentSize',
    0x29000002 => {
        Name => 'OriginalMedium',
        PrintConv => {
            1 => 'Continuous Tone Image',
            2 => 'Halftone Image',
            3 => 'Line Art',
        },
    },
    0x29000003 => {
        Name => 'TypeOfOriginal',
        PrintConv => {
            1 => 'B&W Print',
            2 => 'Color Print',
            3 => 'B&W Document',
            4 => 'Color Document',
        },
    },
    0x28000000 => 'ScannerMake',
    0x28000001 => 'ScannerModel',
    0x28000002 => 'ScannerSerialNumber',
    0x28000003 => 'ScanSoftware',
    0x28000004 => { Name => 'ScanSoftwareRevisionDate', Groups => { 2 => 'Time' } },
    0x28000005 => 'ServiceOrganizationName',
    0x28000006 => 'ScanOperatorID',
    0x28000008 => {
        Name => 'ScanDate',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x28000009 => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x2800000A => 'ScannerPixelSize',
);

# Image Contents properties
%Image::ExifTool::FlashPix::Image = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Image' },
    # VARS storage is used as a hash lookup for tagID's which aren't constant.
    # The key is a mask for significant bits of the tagID, and the value
    # is a lookup for tagID's for which this mask is valid.
    VARS => {
        # ID's are different for each subimage
        0xff00ffff => {
            0x02000000=>1, 0x02000001=>1, 0x02000002=>1, 0x02000003=>1,
            0x02000004=>1, 0x02000005=>1, 0x02000006=>1, 0x02000007=>1,
            0x03000001=>1,
        },
    },
    0x01000000 => 'NumberOfResolutions',
    0x01000002 => 'ImageWidth',     # width of highest resolution image
    0x01000003 => 'ImageHeight',
    0x01000004 => 'DefaultDisplayHeight',
    0x01000005 => 'DefaultDisplayWidth',
    0x01000006 => {
        Name => 'DisplayUnits',
        PrintConv => {
            0 => 'inches',
            1 => 'meters',
            2 => 'cm',
            3 => 'mm',
        },
    },
    0x02000000 => 'SubimageWidth',
    0x02000001 => 'SubimageHeight',
    0x02000002 => {
        Name => 'SubimageColor',
        # decode only component count and color space of first component
        ValueConv => 'sprintf("%.2x %.4x", unpack("x4vx4v",$val))',
        PrintConv => {
            '01 0000' => 'Opacity Only',
            '01 8000' => 'Opacity Only (uncalibrated)',
            '01 0001' => 'Monochrome',
            '01 8001' => 'Monochrome (uncalibrated)',
            '03 0002' => 'YCbCr',
            '03 8002' => 'YCbCr (uncalibrated)',
            '03 0003' => 'RGB',
            '03 8003' => 'RGB (uncalibrated)',
            '04 0002' => 'YCbCr with Opacity',
            '04 8002' => 'YCbCr with Opacity (uncalibrated)',
            '04 0003' => 'RGB with Opacity',
            '04 8003' => 'RGB with Opacity (uncalibrated)',
        },
    },
    0x02000003 => {
        Name => 'SubimageNumericalFormat',
        PrintConv => {
            17 => '8-bit, Unsigned',
            18 => '16-bit, Unsigned',
            19 => '32-bit, Unsigned',
        },
    },
    0x02000004 => {
        Name => 'DecimationMethod',
        PrintConv => {
            0 => 'None (Full-sized Image)',
            8 => '8-point Prefilter',
        },
    },
    0x02000005 => 'DecimationPrefilterWidth',
    0x02000007 => 'SubimageICC_Profile',
    0x03000001 => { Name => 'JPEGTables', Binary => 1 },
    0x03000002 => 'MaxJPEGTableIndex',
);

# Extension List properties
%Image::ExifTool::FlashPix::Extensions = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Other' },
    VARS => {
        # ID's are different for each extension type
        0x0000ffff => {
            0x0001=>1, 0x0002=>1, 0x0003=>1, 0x0004=>1,
            0x0005=>1, 0x0006=>1, 0x0007=>1, 0x1000=>1,
            0x2000=>1, 0x2001=>1, 0x3000=>1, 0x4000=>1,
        },
        0x0000f00f => { 0x3001=>1, 0x3002=>1 },
    },
    0x10000000 => 'UsedExtensionNumbers',
    0x0001 => 'ExtensionName',
    0x0002 => 'ExtensionClassID',
    0x0003 => {
        Name => 'ExtensionPersistence',
        PrintConv => {
            0 => 'Always Valid',
            1 => 'Invalidated By Modification',
            2 => 'Potentially Invalidated By Modification',
        },
    },
    0x0004 => { Name => 'ExtensionCreateDate', Groups => { 2 => 'Time' } },
    0x0005 => { Name => 'ExtensionModifyDate', Groups => { 2 => 'Time' } },
    0x0006 => 'CreatingApplication',
    0x0007 => 'ExtensionDescription',
    0x1000 => 'Storage-StreamPathname',
    0x2000 => 'FlashPixStreamPathname',
    0x2001 => 'FlashPixStreamFieldOffset',
    0x3000 => 'PropertySetPathname',
    0x3001 => 'PropertySetIDCodes',
    0x3002 => 'PropertyVectorElements',
    0x4000 => 'SubimageResolutions',
);

# Subimage Header tags
%Image::ExifTool::FlashPix::SubimageHdr = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32u',
#   0 => 'HeaderLength',
    1 => 'SubimageWidth',
    2 => 'SubimageHeight',
    3 => 'SubimageTileCount',
    4 => 'SubimageTileWidth',
    5 => 'SubimageTileHeight',
    6 => 'NumChannels',
#   7 => 'TileHeaderOffset',
#   8 => 'TileHeaderLength',
    # ... followed by tile header table
);

# Data Object properties
%Image::ExifTool::FlashPix::DataObject = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Other' },
    0x00010000 => 'DataObjectID',
    0x00010002 => 'LockedPropertyList',
    0x00010003 => 'DataObjectTitle',
    0x00010004 => 'LastModifier',
    0x00010005 => 'RevisionNumber',
    0x00010006 => { Name => 'DataCreateDate', Groups => { 2 => 'Time' } },
    0x00010007 => { Name => 'DataModifyDate', Groups => { 2 => 'Time' } },
    0x00010008 => 'CreatingApplication',
    0x00010100 => {
        Name => 'DataObjectStatus',
        PrintConv => q{
            ($val & 0x0000ffff ? 'Exists' : 'Does Not Exist') .
            ', ' . ($val & 0xffff0000 ? 'Not ' : '') . 'Purgeable'
        },
    },
    0x00010101 => {
        Name => 'CreatingTransform',
        PrintConv => '$val ? $val :  "Source Image"',
    },
    0x00010102 => 'UsingTransforms',
    0x10000000 => 'CachedImageHeight',
    0x10000001 => 'CachedImageWidth',
);

# Transform properties
%Image::ExifTool::FlashPix::Transform = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Other' },
    0x00010000 => 'TransformNodeID',
    0x00010001 => 'OperationClassID',
    0x00010002 => 'LockedPropertyList',
    0x00010003 => 'TransformTitle',
    0x00010004 => 'LastModifier',
    0x00010005 => 'RevisionNumber',
    0x00010006 => { Name => 'TransformCreateDate', Groups => { 2 => 'Time' } },
    0x00010007 => { Name => 'TransformModifyDate', Groups => { 2 => 'Time' } },
    0x00010008 => 'CreatingApplication',
    0x00010100 => 'InputDataObjectList',
    0x00010101 => 'OutputDataObjectList',
    0x00010102 => 'OperationNumber',
    0x10000000 => 'ResultAspectRatio',
    0x10000001 => 'RectangleOfInterest',
    0x10000002 => 'Filtering',
    0x10000003 => 'SpatialOrientation',
    0x10000004 => 'ColorTwistMatrix',
    0x10000005 => 'ContrastAdjustment',
);

# Operation properties
%Image::ExifTool::FlashPix::Operation = (
    PROCESS_PROC => \&ProcessProperties,
    0x00010000 => 'OperationID',
);

# Global Info properties
%Image::ExifTool::FlashPix::GlobalInfo = (
    PROCESS_PROC => \&ProcessProperties,
    0x00010002 => 'LockedPropertyList',
    0x00010003 => 'TransformedImageTitle',
    0x00010004 => 'LastModifier',
    0x00010100 => 'VisibleOutputs',
    0x00010101 => 'MaximumImageIndex',
    0x00010102 => 'MaximumTransformIndex',
    0x00010103 => 'MaximumOperationIndex',
);

# Audio Info properties
%Image::ExifTool::FlashPix::AudioInfo = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Audio' },
);

# MacroMedia flash contents
%Image::ExifTool::FlashPix::Contents = (
    PROCESS_PROC => \&ProcessProperties,
    GROUPS => { 2 => 'Image' },
    OriginalFileName => { Name => 'OriginalFileName', Hidden => 1 }, # (not a real tag -- extracted from Contents of VNT file)
);

# CompObj tags
%Image::ExifTool::FlashPix::CompObj = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    FORMAT => 'int32u',
    0 => { Name => 'CompObjUserTypeLen' },
    1 => {
        Name => 'CompObjUserType',
        Format => 'string[$val{0}]',
        RawConv => '$$self{CompObjUserType} = $val', # (use to determine file type)
    },
);

# decode Word document FIB header (ref [MS-DOC].pdf)
%Image::ExifTool::FlashPix::WordDocument = (
    PROCESS_PROC => \&ProcessWordDocument,
    GROUPS => { 2 => 'Other' },
    FORMAT => 'int16u',
    NOTES => 'Tags extracted from the Microsoft Word document stream.',
    0 => {
        Name => 'Identification',
        PrintHex => 1,
        PrintConv => {
            0x6a62 => 'MS Word 97',
            0x626a => 'Word 98 Mac',
            0xa5dc => 'Word 6.0/7.0',
            0xa5ec => 'Word 8.0',
        },
    },
    3 => {
        Name => 'LanguageCode',
        PrintHex => 1,
        PrintConv => {
            0x0400 => 'None',
            0x0401 => 'Arabic',
            0x0402 => 'Bulgarian',
            0x0403 => 'Catalan',
            0x0404 => 'Traditional Chinese',
            0x0804 => 'Simplified Chinese',
            0x0405 => 'Czech',
            0x0406 => 'Danish',
            0x0407 => 'German',
            0x0807 => 'German (Swiss)',
            0x0408 => 'Greek',
            0x0409 => 'English (US)',
            0x0809 => 'English (British)',
            0x0c09 => 'English (Australian)',
            0x040a => 'Spanish (Castilian)',
            0x080a => 'Spanish (Mexican)',
            0x040b => 'Finnish',
            0x040c => 'French',
            0x080c => 'French (Belgian)',
            0x0c0c => 'French (Canadian)',
            0x100c => 'French (Swiss)',
            0x040d => 'Hebrew',
            0x040e => 'Hungarian',
            0x040f => 'Icelandic',
            0x0410 => 'Italian',
            0x0810 => 'Italian (Swiss)',
            0x0411 => 'Japanese',
            0x0412 => 'Korean',
            0x0413 => 'Dutch',
            0x0813 => 'Dutch (Belgian)',
            0x0414 => 'Norwegian (Bokmal)',
            0x0814 => 'Norwegian (Nynorsk)',
            0x0415 => 'Polish',
            0x0416 => 'Portuguese (Brazilian)',
            0x0816 => 'Portuguese',
            0x0417 => 'Rhaeto-Romanic',
            0x0418 => 'Romanian',
            0x0419 => 'Russian',
            0x041a => 'Croato-Serbian (Latin)',
            0x081a => 'Serbo-Croatian (Cyrillic)',
            0x041b => 'Slovak',
            0x041c => 'Albanian',
            0x041d => 'Swedish',
            0x041e => 'Thai',
            0x041f => 'Turkish',
            0x0420 => 'Urdu',
            0x0421 => 'Bahasa',
            0x0422 => 'Ukrainian',
            0x0423 => 'Byelorussian',
            0x0424 => 'Slovenian',
            0x0425 => 'Estonian',
            0x0426 => 'Latvian',
            0x0427 => 'Lithuanian',
            0x0429 => 'Farsi',
            0x042d => 'Basque',
            0x042f => 'Macedonian',
            0x0436 => 'Afrikaans',
            0x043e => 'Malaysian',
        },
    },
    5 => {
        Name => 'DocFlags',
        Mask => 0xff0f, # ignore save count
        RawConv => '$$self{DocFlags} = $val',
        PrintConv => { BITMASK => {
            0 => 'Template',
            1 => 'AutoText only',
            2 => 'Complex',
            3 => 'Has picture',
            # 4-7 = number of incremental saves
            8 => 'Encrypted',
            9 => '1Table',
            10 => 'Read only',
            11 => 'Passworded',
            12 => 'ExtChar',
            13 => 'Load override',
            14 => 'Far east',
            15 => 'Obfuscated',
        }},
    },
    9.1 => {
        Name => 'System',
        Mask => 0x0001,
        PrintConv => {
            0x0000 => 'Windows',
            0x0001 => 'Macintosh',
        },
    },
    9.2 => {
        Name => 'Word97',
        Mask => 0x0010,
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
);

# tags decoded from Word document table
%Image::ExifTool::FlashPix::DocTable = (
    GROUPS => { 1 => 'MS-DOC', 2 => 'Document' },
    NOTES => 'Tags extracted from the Microsoft Word document table.',
    VARS => { NO_ID => 1 },
    CommentBy => {
        Groups => { 2 => 'Author' },
        Notes => 'enable L<Duplicates|../ExifTool.html#Duplicates> option to extract all entries',
    },
    LastSavedBy => {
        Groups => { 2 => 'Author' },
        Notes => 'enable L<Duplicates|../ExifTool.html#Duplicates> option to extract history of up to 10 entries',
    },
    DOP => { SubDirectory => { TagTable => 'Image::ExifTool::FlashPix::DOP' } },
    ModifyDate => {
        Groups => { 2 => 'Time' },
        Format => 'int64u',
        Priority => 0,
        RawConv => q{
            $val = $val * 1e-7 - 11644473600;   # convert to seconds since 1970
            return $val > 0 ? $val : undef;
        },
        ValueConv => 'ConvertUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
#
# tags below are used internally in intermediate steps to extract the tags above
#
    TableOffsets => { Hidden => 1 }, # stores offsets to extract data from document table
    CommentByBlock => {   # entire block of CommentBy entries
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::DocTable',
            ProcessProc => \&ProcessCommentBy,
        },
        Hidden => 1,
    },
    LastSavedByBlock => {   # entire block of LastSavedBy entries
        SubDirectory => {
            TagTable => 'Image::ExifTool::FlashPix::DocTable',
            ProcessProc => \&ProcessLastSavedBy,
        },
        Hidden => 1,
    },
);

# Microsoft Office Document Properties (ref [MS-DOC].pdf)
%Image::ExifTool::FlashPix::DOP = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 1 => 'MS-DOC', 2 => 'Document' },
    NOTES => 'Microsoft office document properties.',
    20 => {
        Name => 'CreateDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Priority => 0,
        RawConv => \&ConvertDTTM,
        PrintConv => '$self->ConvertDateTime($val)',
    },
    24 => {
        Name => 'ModifyDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Priority => 0,
        RawConv => \&ConvertDTTM,
        PrintConv => '$self->ConvertDateTime($val)',
    },
    28 => {
        Name => 'LastPrinted',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        RawConv => \&ConvertDTTM,
        PrintConv => '$self->ConvertDateTime($val)',
    },
    32 => { Name => 'RevisionNumber', Format => 'int16u' },
    34 => {
        Name => 'TotalEditTime',
        Format => 'int32u',
        PrintConv => 'ConvertTimeSpan($val,60)',
    },
    # (according to the MS-DOC specification, the following are accurate only if
    # flag 'X' is set, and flag 'u' specifies whether the main or subdoc tags are
    # used, but in my tests it seems that both are filled in with reasonable values,
    # so just extract the main counts and ignore the subdoc counts for now - PH)
    38 => { Name => 'Words',      Format => 'int32u' },
    42 => { Name => 'Characters', Format => 'int32u' },
    46 => { Name => 'Pages',      Format => 'int16u' },
    48 => { Name => 'Paragraphs', Format => 'int32u' },
    56 => { Name => 'Lines',      Format => 'int32u' },
    #60 => { Name => 'WordsWithSubdocs',      Format => 'int32u' },
    #64 => { Name => 'CharactersWithSubdocs', Format => 'int32u' },
    #68 => { Name => 'PagesWithSubdocs',      Format => 'int16u' },
    #70 => { Name => 'ParagraphsWithSubdocs', Format => 'int32u' },
    #74 => { Name => 'LinesWithSubdocs',      Format => 'int32u' },
);

# FujiFilm "Property" information (ref PH)
%Image::ExifTool::FlashPix::PreviewInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    NOTES => 'Preview information written by some FujiFilm models.',
    FIRST_ENTRY => 0,
    # values are all constant for for my samples except the two decoded tags
    # 0x0000: 01 01 00 00 02 01 00 00 00 00 00 00 00 xx xx 01
    # 0x0010: 01 00 00 00 00 00 00 xx xx 00 00 00 00 00 00 00
    # 0x0020: 00 00 00 00 00
    0x0d => {
        Name => 'PreviewImageWidth',
        Format => 'int16u',
    },
    0x17 => {
        Name => 'PreviewImageHeight',
        Format => 'int16u',
    },
);

# composite FlashPix tags
%Image::ExifTool::FlashPix::Composite = (
    GROUPS => { 2 => 'Image' },
    PreviewImage => {
        Groups => { 2 => 'Preview' },
        # extract JPEG preview from ScreenNail if possible
        Require => {
            0 => 'ScreenNail',
        },
        Binary => 1,
        RawConv => q{
            return undef unless $val[0] =~ /\xff\xd8\xff/g;
            @grps = $self->GetGroup($$val{0});  # set groups from ScreenNail
            return substr($val[0], pos($val[0])-3);
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::FlashPix');

#------------------------------------------------------------------------------
# Convert Microsoft DTTM structure to date/time
# Inputs: 0) DTTM value
# Returns: EXIF-format date/time string ("0000:00:00 00:00:00" for zero date/time)
sub ConvertDTTM($)
{
    my $val = shift;
    my $yr  = ($val >> 20) & 0x1ff;
    my $mon = ($val >> 16) & 0x0f;
    my $day = ($val >> 11) & 0x1f;
    my $hr  = ($val >> 6)  & 0x1f;
    my $min = ($val & 0x3f);
    $yr += 1900 if $val;
    # ExifTool 12.48 dropped the "Z" on the time here because a test .doc
    # file written by Word 2011 on Mac certainly used local time here
    return sprintf("%.4d:%.2d:%.2d %.2d:%.2d:00",$yr,$mon,$day,$hr,$min);
}

#------------------------------------------------------------------------------
# Process hyperlinks from PID_HYPERLINKS array
# (ref http://msdn.microsoft.com/archive/default.asp?url=/archive/en-us/dnaro97ta/html/msdn_hyper97.asp)
# Inputs: 0) value, 1) ExifTool ref
# Returns: list of hyperlinks
sub ProcessHyperlinks($$)
{
    my ($val, $et) = @_;

    # process as an array of VT_VARIANT's
    my $dirEnd = length $val;
    return undef if $dirEnd < 4;
    my $num = Get32u(\$val, 0);
    my $valPos = 4;
    my ($i, @vals);
    for ($i=0; $i<$num; ++$i) {
        # read VT_BLOB entries as an array of VT_VARIANT's
        my $value = ReadFPXValue($et, \$val, $valPos, VT_VARIANT, $dirEnd);
        last unless defined $value;
        push @vals, $value;
    }
    # filter values to extract only the links
    my @links;
    for ($i=0; $i<@vals; $i+=6) {
        push @links, $vals[$i+4];    # get address
        $links[-1] .= '#' . $vals[$i+5] if length $vals[$i+5]; # add subaddress
    }
    return \@links;
}

#------------------------------------------------------------------------------
# Read FlashPix value
# Inputs: 0) ExifTool ref, 1) data ref, 2) value offset, 3) FPX format number,
#         4) end offset, 5) flag for no padding, 6) code page
# Returns: converted value (or list of values in list context) and updates
#          value offset to end of value if successful, or returns undef on error
sub ReadFPXValue($$$$$;$$)
{
    my ($et, $dataPt, $valPos, $type, $dirEnd, $noPad, $codePage) = @_;
    my @vals;

    my $format = $oleFormat{$type & 0x0fff};
    while ($format) {
        my $count = 1;
        # handle VT_VECTOR types
        my $flags = $type & 0xf000;
        if ($flags) {
            if ($flags == VT_VECTOR) {
                $noPad = 1;     # values sometimes aren't padded inside vectors!!
                my $size = $oleFormatSize{VT_VECTOR};
                if ($valPos + $size > $dirEnd) {
                    $et->Warn('Incorrect FPX VT_VECTOR size');
                    last;
                }
                $count = Get32u($dataPt, $valPos);
                push @vals, '' if $count == 0;  # allow zero-element vector
                $valPos += 4;
            } else {
                # can't yet handle this property flag
                $et->Warn('Unknown FPX property');
                last;
            }
        }
        unless ($format =~ /^VT_/) {
            my $size = Image::ExifTool::FormatSize($format) * $count;
            if ($valPos + $size > $dirEnd) {
                $et->Warn("Incorrect FPX $format size");
                last;
            }
            @vals = ReadValue($dataPt, $valPos, $format, $count, $size);
            # update position to end of value plus padding
            $valPos += ($count * $size + 3) & 0xfffffffc;
            last;
        }
        my $size = $oleFormatSize{$format};
        my ($item, $val, $len);
        for ($item=0; $item<$count; ++$item) {
            if ($valPos + $size > $dirEnd) {
                $et->Warn("Truncated FPX $format value");
                last;
            }
            # sometimes VT_VECTOR items are padded to even 4-byte boundaries, and sometimes they aren't
            if ($noPad and defined $len and $len & 0x03) {
                my $pad = 4 - ($len & 0x03);
                if ($valPos + $pad + $size <= $dirEnd) {
                    # skip padding if all zeros
                    $valPos += $pad if substr($$dataPt, $valPos, $pad) eq "\0" x $pad;
                }
            }
            undef $len;
            if ($format eq 'VT_VARIANT') {
                my $subType = Get32u($dataPt, $valPos);
                $valPos += $size;
                $val = ReadFPXValue($et, $dataPt, $valPos, $subType, $dirEnd, $noPad, $codePage);
                last unless defined $val;
                push @vals, $val;
                next;   # avoid adding $size to $valPos again
            } elsif ($format eq 'VT_FILETIME') {
                # convert from time in 100 ns increments to time in seconds
                $val = 1e-7 * Image::ExifTool::Get64u($dataPt, $valPos);
                # print as date/time if value is greater than one year (PH hack)
                my $secDay = 24 * 3600;
                if ($val > 365 * $secDay) {
                    # shift from Jan 1, 1601 to Jan 1, 1970
                    my $unixTimeZero = 134774 * $secDay;
                    $val -= $unixTimeZero;
                    # there are a lot of bad programmers out there...
                    my $sec100yr = 100 * 365 * $secDay;
                    if ($val < 0 || $val > $sec100yr) {
                        # some software writes the wrong byte order (but the proper word order)
                        my @w = unpack("x${valPos}NN", $$dataPt);
                        my $v2 = ($w[0] + $w[1] * 4294967296) * 1e-7 - $unixTimeZero;
                        if ($v2 > 0 && $v2 < $sec100yr) {
                            $val = $v2;
                        # also check for wrong time base
                        } elsif ($val < 0 && $val + $unixTimeZero > 0) {
                            $val += $unixTimeZero;
                        }
                    }
                    $val = Image::ExifTool::ConvertUnixTime($val);
                }
            } elsif ($format eq 'VT_DATE') {
                $val = Image::ExifTool::GetDouble($dataPt, $valPos);
                # shift zero from Dec 30, 1899 to Jan 1, 1970 and convert to secs
                $val = ($val - 25569) * 24 * 3600 if $val != 0;
                $val = Image::ExifTool::ConvertUnixTime($val);
            } elsif ($format =~ /STR$/) {
                $len = Get32u($dataPt, $valPos);
                $len *= 2 if $format eq 'VT_LPWSTR';    # convert to byte count
                if ($valPos + $len + 4 > $dirEnd) {
                    $et->Warn("Truncated $format value");
                    last;
                }
                $val = substr($$dataPt, $valPos + 4, $len);
                if ($format eq 'VT_LPWSTR') {
                    # convert wide string from Unicode
                    $val = $et->Decode($val, 'UCS2');
                } elsif ($codePage) {
                    my $charset = $Image::ExifTool::charsetName{"cp$codePage"};
                    if ($charset) {
                        $val = $et->Decode($val, $charset);
                    } elsif ($codePage == 1200) {   # UTF-16, little endian
                        $val = $et->Decode($val, 'UCS2', 'II');
                    }
                }
                $val =~ s/\0.*//s;  # truncate at null terminator
                # update position for string length
                # (the spec states that strings should be padded to align
                #  on even 32-bit boundaries, but this isn't always the case)
                $valPos += $noPad ? $len : ($len + 3) & 0xfffffffc;
            } elsif ($format eq 'VT_BLOB' or $format eq 'VT_CF') {
                my $len = Get32u($dataPt, $valPos); # (use local $len because we always expect padding)
                if ($valPos + $len + 4 > $dirEnd) {
                    $et->Warn("Truncated $format value");
                    last;
                }
                $val = substr($$dataPt, $valPos + 4, $len);
                # update position for data length plus padding
                # (does this padding disappear in arrays too?)
                $valPos += ($len + 3) & 0xfffffffc;
            } elsif ($format eq 'VT_CLSID') {
                $val = Image::ExifTool::ASF::GetGUID(substr($$dataPt, $valPos, $size));
            }
            $valPos += $size;   # update value pointer to end of value
            push @vals, $val;
        }
        # join VT_ values with commas unless we want an array
        @vals = ( join $et->Options('ListSep'), @vals ) if @vals > 1 and not wantarray;
        last;   # didn't really want to loop
    }
    $_[2] = $valPos;    # return updated value position

    push @vals, '' if $type eq 0; # (VT_EMPTY)
    if (wantarray) {
        return @vals;
    } elsif (@vals > 1) {
        return join(' ', @vals);
    } else {
        return $vals[0];
    }
}

#------------------------------------------------------------------------------
# Scan for XMP in FLA Contents (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: FLA format is proprietary and I couldn't find any documentation,
#        so this routine is entirely based on observations from sample files
sub ProcessContents($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $isFLA;

    # all of my FLA samples contain "Contents" data, and no other FPX-like samples have
    # this (except Scene7 VNT viles), but check the data for a familiar pattern to be
    # sure this is FLA: the Contents of all of my FLA samples start with two bytes
    # (0x29,0x38,0x3f,0x43 or 0x47, then 0x01) followed by a number of zero bytes
    # (from 0x18 to 0x26 of them, related somehow to the value of the first byte),
    # followed by the string "DocumentPage"
    if ($$dataPt =~ /^..\0+\xff\xff\x01\0\x0d\0CDocumentPage/s) {
        $isFLA = 1;
    } elsif ($$dataPt =~ /^\0{4}.(.{1,255})\x60\xa1\x3f\x22\0{5}(.{8})/sg) {
        # this looks like a VNT file
        $et->OverrideFileType('VNT', 'image/x-vignette');
        # hack to set proper file description (extension is the same for V-Note files)
        $Image::ExifTool::static_vars{OverrideFileDescription}{VNT} = 'Scene7 Vignette',
        my $name = $1;
        my ($w, $h) = unpack('V2',$2);
        $et->FoundTag(ImageWidth => $w);
        $et->FoundTag(ImageHeight => $h);
        $et->HandleTag($tagTablePtr, OriginalFileName => $name);        
        if ($$dataPt =~ /\G\x01\0{4}(.{12})/sg) {
            # (first 4 bytes seem to be number of objects, next 4 bytes are zero, then ICC size)
            my $size = unpack('x8V', $1);
            # (not useful?) $et->FoundTag(NumObjects => $num);
            if ($size and pos($$dataPt) + $size < length($$dataPt)) {
                my $dat = substr($$dataPt, pos($$dataPt), $size);
                $et->FoundTag(ICC_Profile => $dat);
                pos($$dataPt) += $size;
            }
            $$et{IeImg_lkup} = { };
            $$et{IeImg_class} = { };
            # - the byte before \x80 is 0x0d, 0x11 or 0x1f for separate images in my samples,
            #   and 0x1c or 0x23 for inline masks
            # - the byte after \xff\xff is 0x3b in my samples for $1 containing 'VnMask' or 'VnCache'
            while ($$dataPt =~ /\x0bTargetRole1(?:.\x80|\xff\xff.\0.\0Vn(\w+))\0\0\x01.{4}(.{24})/sg) {
                my ($index, @coords) = unpack('Vx4V4', $2);
                next if $index == 0xffffffff;
                $$et{IeImg_lkup}{$index} and $et->Warn('Duplicate image index');
                $$et{IeImg_lkup}{$index} = "@coords";
                $$et{IeImg_class}{$index} = $1 if $1;
            }
        }
    }

    # do a brute-force scan of the "Contents" for UTF-16 XMP
    # (this may always be little-endian, but allow for either endianness)
    if ($$dataPt =~ /<\0\?\0x\0p\0a\0c\0k\0e\0t\0 \0b\0e\0g\0i\0n\0=\0['"](\0\xff\xfe|\xfe\xff)/g) {
        $$dirInfo{DirStart} = pos($$dataPt) - 36;
        if ($$dataPt =~ /<\0\?\0x\0p\0a\0c\0k\0e\0t\0 \0e\0n\0d\0=\0['"]\0[wr]\0['"]\0\?\0>\0?/g) {
            $$dirInfo{DirLen} = pos($$dataPt) - $$dirInfo{DirStart};
            Image::ExifTool::XMP::ProcessXMP($et, $dirInfo, $tagTablePtr);
            # override format if not already FLA but XMP-dc:Format indicates it is
            $isFLA = 1 if $$et{FILE_TYPE} ne 'FLA' and $$et{VALUE}{Format} and
                          $$et{VALUE}{Format} eq 'application/vnd.adobe.fla';
        }
    }
    $et->OverrideFileType('FLA') if $isFLA;
    return 1;
}

#------------------------------------------------------------------------------
# Process WordDocument stream of MSWord doc file (ref 6)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessWordDocument($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt} or return 0;
    my $dirLen = length $$dataPt;
    # validate the FIB signature
    unless ($dirLen > 2 and Get16u($dataPt,0) == 0xa5ec) {
        $et->Warn('Invalid FIB signature', 1);
        return 0;
    }
    $et->ProcessBinaryData($dirInfo, $tagTablePtr); # process FIB
    # continue parsing the WordDocument stream until we find the FibRgFcLcb
    my $pos = 32;
    return 0 if $pos + 2 > $dirLen;
    my $n = Get16u($dataPt, $pos);  # read csw
    $pos += 2 + $n * 2;             # skip fibRgW
    return 0 if $pos + 2 > $dirLen;
    $n = Get16u($dataPt, $pos);     # read cslw
    $pos += 2 + $n * 4;             # skip fibRgLw
    return 0 if $pos + 2 > $dirLen;
    $n = Get16u($dataPt, $pos);     # read cbRgFcLcb
    $pos += 2;  # point to start of fibRgFcLcbBlob
    return 0 if $pos + $n * 8 > $dirLen;
    my ($off, @tableOffsets);
    # save necessary entries for later processing of document table
    # (DOP, CommentBy, LastSavedBy)
    foreach $off (0xf8, 0x120, 0x238) {
        last if $off + 8 > $n * 8;
        push @tableOffsets, Get32u($dataPt, $pos + $off);
        push @tableOffsets, Get32u($dataPt, $pos + $off + 4);
    }
    my $tbl = GetTagTable('Image::ExifTool::FlashPix::DocTable');
    # extract ModifyDate if it exists
    $et->HandleTag($tbl, 'ModifyDate', undef,
        DataPt => $dataPt,
        Start  => $pos + 0x2b8,
        Size   => 8,
    );
    $et->HandleTag($tbl, TableOffsets => \@tableOffsets);   # save for later
    # $pos += $n * 8;                 # skip fibRgFcLcbBlob
    # return 0 if $pos + 2 > $dirLen;
    # $n = Get16u($dataPt, $pos);     # read cswNew
    # return 0 if $pos + 2 + $n * 2 > $dirLen;
    # my $nFib = Get16u($dataPt, 2 + ($n ? $pos : 0));
    # $pos += 2 + $n * 2;             # skip fibRgCswNew
    return 1;
}

#------------------------------------------------------------------------------
# Process Microsoft Word Document Table
# Inputs: 0) ExifTool object ref
sub ProcessDocumentTable($)
{
    my $et = shift;
    my $value = $$et{VALUE};
    my $extra = $$et{TAG_EXTRA};
    my ($i, $j, $tag);
    # loop through TableOffsets for each sub-document
    for ($i=0; ; ++$i) {
        my $key = 'TableOffsets' . ($i ? " ($i)" : '');
        my $offsets = $$value{$key};
        last unless defined $offsets;
        my $doc;
        $doc = $$extra{$key}{G3} || '';
        # get DocFlags for this sub-document
        my ($docFlags, $docTable);
        for ($j=0; ; ++$j) {
            my $key = 'DocFlags' . ($j ? " ($j)" : '');
            last unless defined $$value{$key};
            my $tmp;
            $tmp = $$extra{$key}{G3} || '';
            if ($tmp eq $doc) {
                $docFlags = $$value{$key};
                last;
            }
        }
        next unless defined $docFlags;
        $tag = $docFlags & 0x200 ? 'Table1' : 'Table0';
        # get table for this sub-document
        for ($j=0; ; ++$j) {
            my $key = $tag . ($j ? " ($j)" : '');
            last unless defined $$value{$key};
            my $tmp;
            $tmp = $$extra{$key}{G3} || '';
            if ($tmp eq $doc) {
                $docTable = \$$value{$key};
                last;
            }
        }
        next unless defined $docTable;
        # extract DOP and LastSavedBy information from document table
        $$et{DOC_NUM} = $doc;   # use same document number
        my $tagTablePtr = GetTagTable('Image::ExifTool::FlashPix::DocTable');
        foreach $tag (qw(DOP CommentByBlock LastSavedByBlock)) {
            last unless @$offsets;
            my $off = shift @$offsets;
            my $len = shift @$offsets;
            next unless $len and $off + $len <= length $$docTable;
            $et->HandleTag($tagTablePtr, $tag, undef,
                DataPt => $docTable,
                Start  => $off,
                Size   => $len,
            );
        }
        delete $$et{DOC_NUM};
    }
    # delete intermediate tags
    foreach $tag (qw(TableOffsets Table0 Table1)) {
        for ($i=0; ; ++$i) {
            my $key = $tag . ($i ? " ($i)" : '');
            last unless defined $$value{$key};
            $et->DeleteTag($key);
        }
    }
}

#------------------------------------------------------------------------------
# Extract names of comment authors (ref 6)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessCommentBy($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $end = $$dirInfo{DirLen} + $pos;
    $et->VerboseDir($$dirInfo{DirName});
    while ($pos + 2 < $end) {
        my $len = Get16u($dataPt, $pos);
        $pos += 2;
        last if $pos + $len * 2 > $end;
        my $author = $et->Decode(substr($$dataPt, $pos, $len*2), 'UCS2');
        $pos += $len * 2;
        $et->HandleTag($tagTablePtr, CommentBy => $author);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract last-saved-by names (ref 5)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessLastSavedBy($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $end = $$dirInfo{DirLen} + $pos;
    return 0 if $pos + 6 > $end;
    $et->VerboseDir($$dirInfo{DirName});
    my $num = Get16u($dataPt, $pos+2);
    $pos += 6;
    while ($num >= 2) {
        last if $pos + 2 > $end;
        my $len = Get16u($dataPt, $pos);
        $pos += 2;
        last if $pos + $len * 2 > $end;
        my $author = $et->Decode(substr($$dataPt, $pos, $len*2), 'UCS2');
        $pos += $len * 2;
        last if $pos + 2 > $end;
        $len = Get16u($dataPt, $pos);
        $pos += 2;
        last if $pos + $len * 2 > $end;
        my $path = $et->Decode(substr($$dataPt, $pos, $len*2), 'UCS2');
        $pos += $len * 2;
        $et->HandleTag($tagTablePtr, LastSavedBy => "$author ($path)");
        $num -= 2;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Check FPX byte order mark (BOM) and set byte order appropriately
# Inputs: 0) data ref, 1) offset to BOM
# Returns: true on success
sub CheckBOM($$)
{
    my ($dataPt, $pos) = @_;
    my $bom = Get16u($dataPt, $pos);
    return 1 if $bom == 0xfffe;
    return 0 unless $bom == 0xfeff;
    ToggleByteOrder();
    return 1;
}

#------------------------------------------------------------------------------
# Process FlashPix properties
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessProperties($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $pos;
    my $dirEnd = $pos + $dirLen;
    my $verbose = $et->Options('Verbose');
    my $n;

    if ($dirLen < 48) {
        $et->Warn('Truncated FPX properties');
        return 0;
    }
    # check and set our byte order if necessary
    unless (CheckBOM($dataPt, $pos)) {
        $et->Warn('Bad FPX property byte order mark');
        return 0;
    }
    # get position of start of section
    $pos = Get32u($dataPt, $pos + 44);
    if ($pos < 48) {
        $et->Warn('Bad FPX property section offset');
        return 0;
    }
    for ($n=0; $n<2; ++$n) {
        my %dictionary;     # dictionary to translate user-defined properties
        my $codePage;
        last if $pos + 8 > $dirEnd;
        # read property section header
        my $size = Get32u($dataPt, $pos);
        last unless $size;
        my $numEntries = Get32u($dataPt, $pos + 4);
        $verbose and $et->VerboseDir('Property Info', $numEntries, $size);
        if ($pos + 8 + 8 * $numEntries > $dirEnd) {
            $et->Warn('Truncated property list');
            last;
        }
        my $index;
        for ($index=0; $index<$numEntries; ++$index) {
            my $entry = $pos + 8 + 8 * $index;
            my $tag = Get32u($dataPt, $entry);
            my $offset = Get32u($dataPt, $entry + 4);
            my $valStart = $pos + 4 + $offset;
            last if $valStart >= $dirEnd;
            my $valPos = $valStart;
            my $type = Get32u($dataPt, $pos + $offset);
            if ($tag == 0) {
                # read dictionary to get tag name lookup for this property set
                my $i;
                for ($i=0; $i<$type; ++$i) {
                    last if $valPos + 8 > $dirEnd;
                    $tag = Get32u($dataPt, $valPos);
                    my $len = Get32u($dataPt, $valPos + 4);
                    $valPos += 8 + $len;
                    last if $valPos > $dirEnd;
                    my $name = substr($$dataPt, $valPos - $len, $len);
                    $name =~ s/\0.*//s;
                    next unless length $name;
                    $dictionary{$tag} = $name;
                    next if $$tagTablePtr{$name};
                    $tag = $name;
                    $name =~ s/(^| )([a-z])/\U$2/g; # start with uppercase
                    $name =~ tr/-_a-zA-Z0-9//dc;    # remove illegal characters
                    next unless length $name;
                    $et->VPrint(0, "$$et{INDENT}\[adding $name]\n") if $verbose;
                    AddTagToTable($tagTablePtr, $tag, { Name => $name });
                }
                next;
            }
            # use tag name from dictionary if available
            my ($custom, $val);
            if (defined $dictionary{$tag}) {
                $tag = $dictionary{$tag};
                $custom = 1;
            }
            my @vals = ReadFPXValue($et, $dataPt, $valPos, $type, $dirEnd, undef, $codePage);
            @vals or $et->Warn('Error reading property value');
            $val = @vals > 1 ? \@vals : $vals[0];
            my $format = $type & 0x0fff;
            my $flags = $type & 0xf000;
            my $formStr = $oleFormat{$format} || "Type $format";
            $formStr .= '|' . ($oleFlags{$flags} || sprintf("0x%x",$flags)) if $flags;
            my $tagInfo;
            # check for common tag ID's: Dictionary, CodePage and LocaleIndicator
            # (must be done before masking because masked tags may overlap these ID's)
            if (not $custom and ($tag == 1 or $tag == 0x80000000)) {
                # get tagInfo from SummaryInfo table
                my $summaryTable = GetTagTable('Image::ExifTool::FlashPix::SummaryInfo');
                $tagInfo = $et->GetTagInfo($summaryTable, $tag);
                if ($tag == 1) {
                    $val += 0x10000 if $val < 0; # (may be incorrectly stored as int16s)
                    $codePage = $val;            # save code page for translating values
                }
            } elsif ($$tagTablePtr{$tag}) {
                $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            } elsif ($$tagTablePtr{VARS} and not $custom) {
                # mask off insignificant bits of tag ID if necessary
                my $masked = $$tagTablePtr{VARS};
                my $mask;
                foreach $mask (keys %$masked) {
                    if ($masked->{$mask}->{$tag & $mask}) {
                        $tagInfo = $et->GetTagInfo($tagTablePtr, $tag & $mask);
                        last;
                    }
                }
            }
            $et->HandleTag($tagTablePtr, $tag, $val,
                DataPt  => $dataPt,
                Start   => $valStart,
                Size    => $valPos - $valStart,
                Format  => $formStr,
                Index   => $index,
                TagInfo => $tagInfo,
                Extra   => ", type=$type",
            );
        }
        # issue warning if we hit end of property section prematurely
        $et->Warn('Truncated property data') if $index < $numEntries;
        last unless $$dirInfo{Multi};
        $pos += $size;
    }

    return 1;
}

#------------------------------------------------------------------------------
# Load chain of sectors from file
# Inputs: 0) RAF ref, 1) first sector number, 2) FAT ref, 3) sector size, 4) header size
sub LoadChain($$$$$)
{
    my ($raf, $sect, $fatPt, $sectSize, $hdrSize) = @_;
    return undef unless $raf;
    my $chain = '';
    my ($buff, %loadedSect);
    for (;;) {
        last if $sect >= END_OF_CHAIN;
        return undef if $loadedSect{$sect}; # avoid infinite loop
        $loadedSect{$sect} = 1;
        my $offset = $sect * $sectSize + $hdrSize;
        return undef unless ($offset <= 0x7fffffff or $$raf{LargeFileSupport}) and
                            $raf->Seek($offset, 0) and
                            $raf->Read($buff, $sectSize) == $sectSize;
        $chain .= $buff;
        # step to next sector in chain
        return undef if $sect * 4 > length($$fatPt) - 4;
        $sect = Get32u($fatPt, $sect * 4);
    }
    return $chain;
}

#------------------------------------------------------------------------------
# Extract information from a JPEG APP2 FPXR segment
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessFPXR($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');

    if ($dirLen < 13) {
        $et->Warn('FPXR segment too small');
        return 0;
    }

    # get version and segment type (version is 0 in all my samples)
    my ($vers, $type) = unpack('x5C2', $$dataPt);

    if ($type == 1) {   # a "Contents List" segment

        $vers != 0 and $et->Warn("Untested FPXR version $vers");
        if ($$et{FPXR}) {
            $et->Warn('Multiple FPXR contents lists');
            delete $$et{FPXR};
        }
        my $numEntries = unpack('x7n', $$dataPt);
        my @contents;
        $verbose and $et->VerboseDir('Contents List', $numEntries);
        my $pos = 9;
        my $entry;
        for ($entry = 0; $entry < $numEntries; ++$entry) {
            if ($pos + 4 > $dirLen) {
                $et->Warn('Truncated FPXR contents');
                return 0;
            }
            my ($size, $default) = unpack("x${pos}Na", $$dataPt);
            pos($$dataPt) = $pos + 5;
            # according to the spec, this string is little-endian
            # (very odd, since the size word is big-endian),
            # and the first char must be '/'
            unless ($$dataPt =~ m{\G(/\0(..)*?)\0\0}sg) {
                $et->Warn('Invalid FPXR stream name');
                return 0;
            }
            # convert stream pathname to ascii
            my $name = Image::ExifTool::Decode(undef, $1, 'UCS2', 'II', 'Latin');
            if ($verbose) {
                my $psize = ($size == 0xffffffff) ? 'storage' : "$size bytes";
                $et->VPrint(0,"  |  $entry) Name: '${name}' [$psize]\n");
            }
            # remove directory specification
            $name =~ s{.*/}{}s;
            # read storage class ID if necessary
            my $classID;
            if ($size == 0xffffffff) {
                unless ($$dataPt =~ m{(.{16})}sg) {
                    $et->Warn('Truncated FPXR storage class ID');
                    return 0;
                }
                # unpack class ID in case we want to use it sometime
                $classID = Image::ExifTool::ASF::GetGUID($1);
            }
            # find the tagInfo if available
            my $tagInfo;
            unless ($$tagTablePtr{$name}) {
                # remove instance number or class ID from tag if necessary
                $tagInfo = $et->GetTagInfo($tagTablePtr, $1) if
                    ($name =~ /(.*) \d{6}$/s and $$tagTablePtr{$1}) or
                    ($name =~ /(.*)_[0-9a-f]{16}$/s and $$tagTablePtr{$1});
            }
            # update position in list
            $pos = pos($$dataPt);
            # add to our contents list
            push @contents, {
                Name => $name,
                Size => $size,
                Default => $default,
                ClassID => $classID,
                TagInfo => $tagInfo,
            };
        }
        # save contents list as $et member variable
        # (must do this last so we don't save list on error)
        $$et{FPXR} = \@contents;

    } elsif ($type == 2) {  # a "Stream Data" segment

        # get the contents list index and stream data offset
        my ($index, $offset) = unpack('x7nN', $$dataPt);
        my $fpxr = $$et{FPXR};
        if ($fpxr and $$fpxr[$index]) {
            my $obj = $$fpxr[$index];
            # extract stream data (after 13-byte header)
            if (not defined $$obj{Stream}) {
                # ignore offset for first segment of this type
                # (in my sample images, this isn't always zero as one would expect)
                $$obj{Stream} = substr($$dataPt, $dirStart+13);
            } else {
                # add data at the proper offset to the stream
                my $overlap = length($$obj{Stream}) - $offset;
                my $start = $dirStart + 13;
                if ($overlap < 0 or $dirLen - $overlap < 13) {
                    $et->Warn("Bad FPXR stream $index offset",1);
                } else {
                    # ignore any overlapping data in this segment
                    # (this seems to be the convention)
                    $start += $overlap;
                }
                # concatenate data with this stream
                $$obj{Stream} .= substr($$dataPt, $start);
            }
            # save value for this tag if stream is complete
            my $len = length $$obj{Stream};
            if ($len >= $$obj{Size}) {
                $et->VPrint(0, "  + [FPXR stream $index, $len bytes]\n") if $verbose;
                if ($len > $$obj{Size}) {
                    $et->Warn('Extra data in FPXR segment (truncated)');
                    $$obj{Stream} = substr($$obj{Stream}, 0, $$obj{Size});
                }
                # handle this tag
                $et->HandleTag($tagTablePtr, $$obj{Name}, $$obj{Stream},
                    DataPt => \$$obj{Stream},
                    TagInfo => $$obj{TagInfo},
                );
                delete $$obj{Stream}; # done with this stream
            }
        # hack for improperly stored FujiFilm PreviewImage (stored with no contents list)
        } elsif ($index == 512 and $dirLen > 60 and ($$et{FujiPreview} or
            ($dirLen > 64 and substr($$dataPt, $dirStart+60, 4) eq "\xff\xd8\xff\xdb")))
        {
            $$et{FujiPreview} = '' unless defined $$et{FujiPreview};
            # recombine PreviewImage, skipping 13-byte FPXR header + 47-byte Fuji header
            $$et{FujiPreview} .= substr($$dataPt, $dirStart+60);
        } else {
            # (Kodak uses index 255 for a free segment in images from some cameras)
            $et->Warn("Unlisted FPXR segment (index $index)") if $index != 255;
        }

    } elsif ($type != 3) {  # not a "Reserved" segment

        $et->Warn("Unknown FPXR segment (type $type)");

    }

    # clean up if this was the last FPXR segment
    if ($$dirInfo{LastFPXR}) {
        if ($$et{FPXR}) {
            my $obj;
            foreach $obj (@{$$et{FPXR}}) {
                next unless defined $$obj{Stream} and length $$obj{Stream};
                # parse it even though it isn't the proper length
                $et->HandleTag($tagTablePtr, $$obj{Name}, $$obj{Stream},
                    DataPt => \$$obj{Stream},
                    TagInfo => $$obj{TagInfo},
                );
            }
            delete $$et{FPXR};    # delete our temporary variables
        }
        if ($$et{FujiPreview}) {
            $et->FoundTag('PreviewImage', $$et{FujiPreview});
            delete $$et{FujiPreview};
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Set document number for objects
# Inputs: 0) object hierarchy hash ref, 1) object index, 2) doc number list ref,
#         3) doc numbers used at each level, 4) flag set for metadata levels
sub SetDocNum($$;$$$)
{
    my ($hier, $index, $doc, $used, $meta) = @_;
    my $obj = $$hier{$index} or return;
    return if exists $$obj{DocNum};
    $$obj{DocNum} = $doc;
    SetDocNum($hier, $$obj{Left}, $doc, $used, $meta) if $$obj{Left};
    SetDocNum($hier, $$obj{Right}, $doc, $used, $meta) if $$obj{Right};
    if (defined $$obj{Child}) {
        $used or $used = [ ];
        my @subDoc;
        push @subDoc, @$doc if $doc;
        # we must dive down 2 levels for each sub-document, so use the
        # $meta flag to add a sub-document level only for every 2nd generation
        if ($meta) {
            my $subNum = ($$used[scalar @subDoc] || 0);
            $$used[scalar @subDoc] = $subNum;
            push @subDoc, $subNum;
        } elsif (@subDoc) {
            $subDoc[-1] = ++$$used[$#subDoc];
        }
        SetDocNum($hier, $$obj{Child}, \@subDoc, $used, not $meta);
    }
}

#------------------------------------------------------------------------------
# Extract information from a FlashPix (FPX) file
# Inputs: 0) ExifTool object ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid FPX-format file
sub ProcessFPX($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $out, $oldIndent, $miniStreamBuff);
    my ($tag, %hier, %objIndex, %loadedDifSect);

    # handle FPX format in memory from PNG cpIp chunk
    $raf or $raf = File::RandomAccess->new($$dirInfo{DataPt});

    # read header
    return 0 unless $raf->Read($buff,HDR_SIZE) == HDR_SIZE;
    # check signature
    return 0 unless $buff =~ /^\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1/;

    # set FileType initially based on file extension (we may override this later)
    my $fileType = $$et{FILE_EXT};
    $fileType = 'FPX' unless $fileType and $fpxFileType{$fileType};
    $et->SetFileType($fileType);
    SetByteOrder(substr($buff, 0x1c, 2) eq "\xff\xfe" ? 'MM' : 'II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::FlashPix::Main');
    my $verbose = $et->Options('Verbose');
    # copy LargeFileSupport option to RAF for use in LoadChain
    $$raf{LargeFileSupport} = $et->Options('LargeFileSupport');

    my $sectSize = 1 << Get16u(\$buff, 0x1e);
    my $miniSize = 1 << Get16u(\$buff, 0x20);
    my $fatCount   = Get32u(\$buff, 0x2c);  # number of FAT sectors
    my $dirStart   = Get32u(\$buff, 0x30);  # first directory sector
    my $miniCutoff = Get32u(\$buff, 0x38);  # minimum size for big-FAT streams
    my $miniStart  = Get32u(\$buff, 0x3c);  # first sector of mini-FAT
    my $miniCount  = Get32u(\$buff, 0x40);  # number of mini-FAT sectors
    my $difStart   = Get32u(\$buff, 0x44);  # first sector of DIF chain
    my $difCount   = Get32u(\$buff, 0x48);  # number of DIF sectors

    if ($verbose) {
        $out = $et->Options('TextOut');
        print $out "  Sector size=$sectSize\n  FAT: Count=$fatCount\n";
        print $out "  DIR: Start=$dirStart\n";
        print $out "  MiniFAT: Mini-sector size=$miniSize Start=$miniStart Count=$miniCount Cutoff=$miniCutoff\n";
        print $out "  DIF FAT: Start=$difStart Count=$difCount\n";
    }
#
# load the FAT
#
    my $pos = 0x4c;
    my $endPos = length($buff);
    my $fat = '';
    my $fatCountCheck = 0;
    my $difCountCheck = 0;
    my $hdrSize = $sectSize > HDR_SIZE ? $sectSize : HDR_SIZE;

    for (;;) {
        while ($pos <= $endPos - 4) {
            my $sect = Get32u(\$buff, $pos);
            $pos += 4;
            next if $sect == FREE_SECT;
            my $offset = $sect * $sectSize + $hdrSize;
            my $fatSect;
            unless ($raf->Seek($offset, 0) and
                    $raf->Read($fatSect, $sectSize) == $sectSize)
            {
                $et->Error("Error reading FAT from sector $sect");
                return 1;
            }
            $fat .= $fatSect;
            ++$fatCountCheck;
        }
        last if $difStart >= END_OF_CHAIN;
        # read next DIF (Dual Indirect FAT) sector
        if (++$difCountCheck > $difCount) {
            $et->Warn('Unterminated DIF FAT');
            last;
        }
        if ($loadedDifSect{$difStart}) {
            $et->Warn('Cyclical reference in DIF FAT');
            last;
        }
        my $offset = $difStart * $sectSize + $hdrSize;
        unless ($raf->Seek($offset, 0) and $raf->Read($buff, $sectSize) == $sectSize) {
            $et->Error("Error reading DIF sector $difStart");
            return 1;
        }
        $loadedDifSect{$difStart} = 1;
        # set end of sector information in this DIF
        $pos = 0;
        $endPos = $sectSize - 4;
        # next time around we want to read next DIF in chain
        $difStart = Get32u(\$buff, $endPos);
    }
    if ($fatCountCheck != $fatCount) {
        $et->Warn("Bad number of FAT sectors (expected $fatCount but found $fatCountCheck)");
    }
#
# load the mini-FAT and the directory
#
    my $miniFat = LoadChain($raf, $miniStart, \$fat, $sectSize, $hdrSize);
    my $dir = LoadChain($raf, $dirStart, \$fat, $sectSize, $hdrSize);
    unless (defined $miniFat and defined $dir) {
        $et->Error('Error reading mini-FAT or directory stream');
        return 1;
    }
    if ($verbose) {
        print $out "  FAT [",length($fat)," bytes]:\n";
        $et->VerboseDump(\$fat);
        print $out "  Mini-FAT [",length($miniFat)," bytes]:\n";
        $et->VerboseDump(\$miniFat);
        print $out "  Directory [",length($dir)," bytes]:\n";
        $et->VerboseDump(\$dir);
    }
#
# process the directory
#
    if ($verbose) {
        $oldIndent = $$et{INDENT};
        $$et{INDENT} .= '| ';
        $et->VerboseDir('FPX', undef, length $dir);
    }
    my $miniStream;
    $endPos = length($dir);
    my $index = 0;
    my $ee; # name of next tag to extract if unknown
    $ee = 0 if $et->Options('ExtractEmbedded');

    for ($pos=0; $pos<=$endPos-128; $pos+=128, ++$index) {

        # get directory entry type
        # (0=invalid, 1=storage, 2=stream, 3=lockbytes, 4=property, 5=root)
        my $type = Get8u(\$dir, $pos + 0x42);
        next if $type == 0; # skip invalid entries
        if ($type > 5) {
            $et->Warn("Invalid directory entry type $type");
            last;   # rest of directory is probably garbage
        }
        # get entry name (note: this is supposed to be length in 2-byte
        # characters but this isn't what is done in my sample FPX file, so
        # be very tolerant of this count -- it's null terminated anyway)
        my $len = Get16u(\$dir, $pos + 0x40);
        $len > 32 and $len = 32;
        $tag = Image::ExifTool::Decode(undef, substr($dir,$pos,$len*2), 'UCS2', 'II', 'Latin');
        $tag =~ s/\0.*//s;  # truncate at null (in case length was wrong)

        if ($tag eq '0' and not defined $ee) {
            $et->Warn('Use the ExtractEmbedded option to extract embedded information', 3);
        }
        my $sect = Get32u(\$dir, $pos + 0x74);  # start sector number
        my $size = Get32u(\$dir, $pos + 0x78);  # stream length

        # load Ministream (referenced from first directory entry)
        unless ($miniStream) {
            $miniStreamBuff = LoadChain($raf, $sect, \$fat, $sectSize, $hdrSize);
            unless (defined $miniStreamBuff) {
                $et->Warn('Error loading Mini-FAT stream');
                last;
            }
            $miniStream = File::RandomAccess->new(\$miniStreamBuff);
        }

        my $tagInfo;
        if ($$tagTablePtr{$tag}) {
            $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        } elsif (defined $ee and $tag eq $ee) {
            $tagInfo = '';  # won't know the actual tagID untile we read the stream
            $ee = sprintf('%x', hex($ee)+1); # tag to look for next
        } else {
            # remove instance number or class ID from tag if necessary
            $tagInfo = $et->GetTagInfo($tagTablePtr, $1) if
                ($tag =~ /(.*) \d{6}$/s and $$tagTablePtr{$1}) or
                ($tag =~ /(.*)_[0-9a-f]{16}$/s and $$tagTablePtr{$1}) or
                ($tag =~ /(.*)_[0-9]{4}$/s and $$tagTablePtr{$1});  # IeImg instances
        }

        my $lSib = Get32u(\$dir, $pos + 0x44);  # left sibling
        my $rSib = Get32u(\$dir, $pos + 0x48);  # right sibling
        my $chld = Get32u(\$dir, $pos + 0x4c);  # child directory

        # save information about object hierarchy
        my ($obj, $sub);
        $obj = $hier{$index} or $obj = $hier{$index} = { };
        $$obj{Left} = $lSib unless $lSib == FREE_SECT;
        $$obj{Right} = $rSib unless $rSib == FREE_SECT;
        unless ($chld == FREE_SECT) {
            $$obj{Child} = $chld;
            $sub = $hier{$chld} or $sub = $hier{$chld} = { };
            $$sub{Parent} = $index;
        }

        next unless defined $tagInfo or $verbose;

        # load the data for stream types
        my $extra = '';
        my $typeStr = $dirEntryType[$type] || $type;
        if ($typeStr eq 'STREAM') {
            if ($size >= $miniCutoff) {
                # stream is in the main FAT
                $buff = LoadChain($raf, $sect, \$fat, $sectSize, $hdrSize);
            } elsif ($size) {
                # stream is in the mini-FAT
                $buff = LoadChain($miniStream, $sect, \$miniFat, $miniSize, 0);
            } else {
                $buff = ''; # an empty stream
            }
            unless (defined $buff) {
                my $name = $tagInfo ? $$tagInfo{Name} : 'unknown';
                $et->Warn("Error reading $name stream");
                $buff = '';
            }
        } elsif ($typeStr eq 'ROOT') {
            $buff = $miniStreamBuff;
            $extra .= ' (Ministream)';
        } else {
            $buff = '';
            undef $size;
        }
        if ($verbose) {
            my $flags = Get8u(\$dir, $pos + 0x43);  # 0=red, 1=black
            my $col = { 0 => 'Red', 1 => 'Black' }->{$flags} || $flags;
            $extra .= " Type=$typeStr Flags=$col";
            $extra .= " Left=$lSib" unless $lSib == FREE_SECT;
            $extra .= " Right=$rSib" unless $rSib == FREE_SECT;
            $extra .= " Child=$chld" unless $chld == FREE_SECT;
            $extra .= " Size=$size" if defined $size;
            my $name;
            $name = "Unknown_0x$tag" if not $tagInfo and $tag =~ /^[0-9a-f]{1,3}$/;
            $et->VerboseInfo($tag, $tagInfo,
                Index  => $index,
                Value  => $buff,
                DataPt => \$buff,
                Extra  => $extra,
              # Size   => $size, (moved to $extra so we can see the rest of the stream if larger)
                Name   => $name,
            );
        }
        if (defined $tagInfo and $buff) {
            my $num = $$et{NUM_FOUND};
            if ($tagInfo and $$tagInfo{SubDirectory}) {
                my $subdir = $$tagInfo{SubDirectory};
                my %dirInfo = (
                    DataPt   => \$buff,
                    DirStart => $$subdir{DirStart},
                    DirLen   => length $buff,
                    Multi    => $$tagInfo{Multi},
                );
                my $subTablePtr = GetTagTable($$subdir{TagTable});
                $et->ProcessDirectory(\%dirInfo, $subTablePtr,  $$subdir{ProcessProc});
            } elsif (defined $size and $size > length($buff)) {
                $et->Warn('Truncated object');
            } else {
                $buff = substr($buff, 0, $size) if defined $size and $size < length($buff);
                if ($tag =~ /^IeImg_0*(\d+)$/) {
                    # set document number for embedded images and their positions (if available, VNT files)
                    my $num = $1;
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                    $et->FoundTag($tagInfo, $buff);
                    if ($$et{IeImg_lkup} and $$et{IeImg_lkup}{$num}) {
                        # save position of this image
                        $et->HandleTag($tagTablePtr, IeImg_rect => $$et{IeImg_lkup}{$num});
                        delete $$et{IeImg_lkup}{$num};
                        if ($$et{IeImg_class} and $$et{IeImg_class}{$num}) {
                            $et->HandleTag($tagTablePtr, IeImg_class => $$et{IeImg_class}{$num});
                            delete $$et{IeImg_class}{$num};
                        }
                    }
                    delete $$et{DOC_NUM};
                } elsif (not $tagInfo) {
                    # extract some embedded information from PNG Plus images
                    if ($buff =~ /^(.{19,40})(\xff\xd8\xff\xe0|\x89PNG\r\n\x1a\n)/sg) {
                        my $id = $2 eq "\xff\xd8\xff\xe0" ? '_eeJPG' : '_eePNG';
                        $et->HandleTag($tagTablePtr, $id, substr($buff, length($1)));
                    } elsif ($buff =~ /^\0\x80\0\0\x01\0\0\0\x0e\0/ and length($buff) > 18) {
                        my $len = unpack('x17C', $buff);
                        next if $len + 18 > length($buff);
                        my $filename = $et->Decode(substr($buff,18,$len), 'UTF16', 'II');
                        $et->HandleTag($tagTablePtr, '_eeLink', $filename);
                    } else {
                        next;
                    }
                } else {
                    $et->FoundTag($tagInfo, $buff);
                }
            }
            # save object index number for all found tags
            my $num2 = $$et{NUM_FOUND};
            $objIndex{++$num} = $index while $num < $num2;
        }
    }
    # set document numbers for tags extracted from embedded documents
    unless ($$et{DOC_NUM}) {
        # initialize document number for all objects, beginning at root (index 0)
        SetDocNum(\%hier, 0);
        # set family 3 group name for all tags in embedded documents
        my $order = $$et{FILE_ORDER};
        my (@pri, $copy, $member);
        foreach $tag (keys %$order) {
            my $num = $$order{$tag};
            next unless defined $num and $objIndex{$num};
            my $obj = $hier{$objIndex{$num}} or next;
            my $docNums = $$obj{DocNum};
            next unless $docNums and @$docNums;
            $$et{TAG_EXTRA}{$tag}{G3} = join '-', @$docNums;
            push @pri, $tag unless $tag =~ / /; # save keys for priority sub-doc tags
        }
        # swap priority sub-document tags with main document tags if they exist
        foreach $tag (@pri) {
            for ($copy=1; ;++$copy) {
                my $key = "$tag ($copy)";
                last unless defined $$et{VALUE}{$key};
                next if $$et{TAG_EXTRA}{$key}{G3}; # not Main if family 3 group is set
                foreach $member ('PRIORITY','VALUE','FILE_ORDER','TAG_INFO','TAG_EXTRA') {
                    my $pHash = $$et{$member};
                    my $t = $$pHash{$tag};
                    $$pHash{$tag} = $$pHash{$key};
                    $$pHash{$key} = $t;
                }
                last;
            }
        }
    }
    $$et{INDENT} = $oldIndent if $verbose;
    # try to better identify the file type
    if ($$et{FileType} eq 'FPX') {
        my $val = $$et{CompObjUserType} || $$et{Software};
        if ($val) {
            my %type = ( '^3ds Max' => 'MAX', Word => 'DOC', PowerPoint => 'PPT', Excel => 'XLS' );
            my $pat;
            foreach $pat (sort keys %type) {
                next unless $val =~ /$pat/;
                $et->OverrideFileType($type{$pat});
                last;
            }
        }
    }
    # process Word document table
    ProcessDocumentTable($et);

    if ($$et{IeImg_lkup} and %{$$et{IeImg_lkup}}) {
        $et->Warn('Image positions exist without corresponding images');
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::FlashPix - Read FlashPix meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
FlashPix meta information from FPX images, and from the APP2 FPXR segment of
JPEG images.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.exif.org/Exif2-2.PDF>

=item L<http://www.graphcomp.com/info/specs/livepicture/fpx.pdf>

=item L<http://search.cpan.org/~jdb/libwin32/>

=item L<http://msdn.microsoft.com/en-us/library/aa380374.aspx>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FlashPix Tags>,
L<Image::ExifTool::TagNames/OOXML Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

