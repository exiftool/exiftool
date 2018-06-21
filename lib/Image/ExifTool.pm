#------------------------------------------------------------------------------
# File:         ExifTool.pm
#
# Description:  Read and write meta information
#
# URL:          http://owl.phy.queensu.ca/~phil/exiftool/
#
# Revisions:    Nov. 12/2003 - P. Harvey Created
#               (See html/history.html for revision history)
#
# Legal:        Copyright (c) 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)
#               This library is free software; you can redistribute it and/or
#               modify it under the same terms as Perl itself.
#------------------------------------------------------------------------------

package Image::ExifTool;

use strict;
require 5.004;  # require 5.004 for UNIVERSAL::isa (otherwise 5.002 would do)
require Exporter;
use File::RandomAccess;

use vars qw($VERSION $RELEASE @ISA @EXPORT_OK %EXPORT_TAGS $AUTOLOAD @fileTypes
            %allTables @tableOrder $exifAPP1hdr $xmpAPP1hdr $xmpExtAPP1hdr
            $psAPP13hdr $psAPP13old @loadAllTables %UserDefined $evalWarning
            %noWriteFile %magicNumber @langs $defaultLang %langName %charsetName
            %mimeType $swapBytes $swapWords $currentByteOrder %unpackStd
            %jpegMarker %specialTags %fileTypeLookup);

$VERSION = '11.03';
$RELEASE = '';
@ISA = qw(Exporter);
%EXPORT_TAGS = (
    # all public non-object-oriented functions:
    Public => [qw(
        ImageInfo GetTagName GetShortcuts GetAllTags GetWritableTags
        GetAllGroups GetDeleteGroups GetFileType CanWrite CanCreate
        AddUserDefinedTags
    )],
    # exports not part of the public API, but used by ExifTool modules:
    DataAccess => [qw(
        ReadValue GetByteOrder SetByteOrder ToggleByteOrder Get8u Get8s Get16u
        Get16s Get32u Get32s Get64u GetFloat GetDouble GetFixed32s Write
        WriteValue Tell Set8u Set8s Set16u Set32u
    )],
    Utils => [qw(GetTagTable TagTableKeys GetTagInfoList AddTagToTable HexDump)],
    Vars  => [qw(%allTables @tableOrder @fileTypes)],
);

# set all of our EXPORT_TAGS in EXPORT_OK
Exporter::export_ok_tags(keys %EXPORT_TAGS);

# test for problems that can arise if encoding.pm is used
{ my $t = "\xff"; die "Incompatible encoding!\n" if ord($t) != 0xff; }

# The following functions defined in Image::ExifTool::Writer are declared
# here so their prototypes will be available.  These Writer routines will be
# autoloaded when any of them is called.
sub SetNewValue($;$$%);
sub SetNewValuesFromFile($$;@);
sub GetNewValue($$;$);
sub GetNewValues($$;$);
sub CountNewValues($);
sub SaveNewValues($);
sub RestoreNewValues($);
sub WriteInfo($$;$$);
sub SetFileModifyDate($$;$$$);
sub SetFileName($$;$$);
sub SetSystemTags($$);
sub GetAllTags(;$);
sub GetWritableTags(;$);
sub GetAllGroups($);
sub GetNewGroups($);
sub GetDeleteGroups();
sub AddUserDefinedTags($%);
# non-public routines below
sub InsertTagValues($$$;$$$);
sub IsWritable($);
sub GetNewFileName($$);
sub LoadAllTables();
sub GetNewTagInfoList($;$);
sub GetNewTagInfoHash($@);
sub GetLangInfo($$);
sub Get64s($$);
sub Get64u($$);
sub GetFixed64s($$);
sub GetExtended($$);
sub DecodeBits($$;$);
sub EncodeBits($$;$$);
sub HexDump($;$%);
sub DumpTrailer($$);
sub DumpUnknownTrailer($$);
sub VerboseInfo($$$%);
sub VerboseValue($$$;$);
sub VPrint($$@);
sub Rationalize($;$);
sub Write($@);
sub WriteTrailerBuffer($$$);
sub AddNewTrailers($;@);
sub Tell($);
sub WriteValue($$;$$$$);
sub WriteDirectory($$$;$);
sub WriteBinaryData($$$);
sub CheckBinaryData($$$);
sub WriteTIFF($$$);
sub PackUTF8(@);
sub UnpackUTF8($);
sub SetPreferredByteOrder($);
sub CopyBlock($$$);
sub CopyFileAttrs($$$);
sub TimeNow(;$$);
sub NewGUID();
sub MakeTiffHeader($$$$;$$);

# other subroutine definitions
sub EncodeFileName($$;$);
sub Open($*$;$);
sub Exists($$);
sub IsDirectory($$);
sub Rename($$$);
sub Unlink($@);
sub SetFileTime($$;$$$$);
sub DoEscape($$);
sub ConvertFileSize($);
sub ParseArguments($;@); #(defined in attempt to avoid mod_perl problem)
sub ReadValue($$$$$;$);

# list of main tag tables to load in LoadAllTables() (sub-tables are recursed
# automatically).  Note: They will appear in this order in the documentation
# unless tweaked in BuildTagLookup::GetTableOrder().
@loadAllTables = qw(
    PhotoMechanic Exif GeoTiff CanonRaw KyoceraRaw Lytro MinoltaRaw PanasonicRaw
    SigmaRaw JPEG GIMP Jpeg2000 GIF BMP BMP::OS2 BMP::Extra BPG BPG::Extensions
    PICT PNG MNG FLIF DjVu DPX OpenEXR MIFF PGF PSP PhotoCD Radiance PDF
    PostScript Photoshop::Header Photoshop::Layers Photoshop::ImageData
    FujiFilm::RAF FujiFilm::IFD Samsung::Trailer Sony::SRF2 Sony::SR2SubIFD
    Sony::PMP ITC ID3 FLAC Ogg Vorbis APE APE::NewHeader APE::OldHeader Audible
    MPC MPEG::Audio MPEG::Video MPEG::Xing M2TS QuickTime QuickTime::ImageFile
    QuickTime::Stream Matroska MOI MXF DV Flash Flash::FLV Real::Media
    Real::Audio Real::Metafile Red RIFF AIFF ASF WTV DICOM MIE JSON HTML
    XMP::SVG Palm Palm::MOBI Palm::EXTH Torrent EXE EXE::PEVersion EXE::PEString
    EXE::MachO EXE::PEF EXE::ELF EXE::AR EXE::CHM LNK Font VCard
    VCard::VCalendar RSRC Rawzor ZIP ZIP::GZIP ZIP::RAR RTF OOXML iWork ISO
    FLIR::AFF FLIR::FPF MacOS::MDItem MacOS::XAttr
);

# alphabetical list of current Lang modules
@langs = qw(cs de en en_ca en_gb es fi fr it ja ko nl pl ru sv tr zh_cn zh_tw);

$defaultLang = 'en';    # default language

# language names
%langName = (
    cs => 'Czech (Čeština)',
    de => 'German (Deutsch)',
    en => 'English',
    en_ca => 'Canadian English',
    en_gb => 'British English',
    es => 'Spanish (Español)',
    fi => 'Finnish (Suomi)',
    fr => 'French (Français)',
    it => 'Italian (Italiano)',
    ja => 'Japanese (日本語)',
    ko => 'Korean (한국어)',
    nl => 'Dutch (Nederlands)',
    pl => 'Polish (Polski)',
    ru => 'Russian (Русский)',
    sv => 'Swedish (Svenska)',
   'tr'=> 'Turkish (Türkçe)',
    zh_cn => 'Simplified Chinese (简体中文)',
    zh_tw => 'Traditional Chinese (繁體中文)',
);

# recognized file types, in the order we test unknown files
# Notes: 1) There is no need to test for like types separately here
# 2) Put types with weak file signatures at end of list to avoid false matches
# 3) PLIST must be in this list for the binary PLIST format, although it may
#    cause a file to be checked twice for XML
@fileTypes = qw(JPEG EXV CRW DR4 TIFF GIF MRW RAF X3F JP2 PNG MIE MIFF PS PDF
                PSD XMP BMP BPG PPM RIFF AIFF ASF MOV MPEG Real SWF PSP FLV OGG
                FLAC APE MPC MKV MXF DV PMP IND PGF ICC ITC FLIR FLIF FPF LFP
                HTML VRD RTF XCF DSS QTIF FPX PICT ZIP GZIP PLIST RAR BZ2 TAR
                RWZ EXE EXR HDR CHM LNK WMF AVC DEX DPX RAW Font RSRC M2TS PHP
                WTV Torrent VCard LRI R3D AA PDB MOI ISO JSON MP3 DICOM PCD);

# file types that we can write (edit)
my @writeTypes = qw(JPEG TIFF GIF CRW MRW ORF RAF RAW PNG MIE PSD XMP PPM EPS
                    X3F PS PDF ICC VRD DR4 JP2 EXIF AI AIT IND MOV EXV FLIF);
my %writeTypes; # lookup for writable file types (hash filled if required)

# file extensions that we can't write for various base types
%noWriteFile = (
    TIFF => [ qw(3FR DCR K25 KDC SRF) ],
    XMP  => [ 'SVG', 'INX' ],
    JP2  => [ 'J2C', 'JPC' ],
    MOV  => [ 'HEIC', 'HEIF' ],
);

# file types that we can create from scratch
# - must update CanCreate() documentation if this list is changed!
my %createTypes = map { $_ => 1 } qw(XMP ICC MIE VRD DR4 EXIF EXV);

# file type lookup for all recognized file extensions
# (if extension may be more than one type, the type is a list where
#  the writable type should come first if it exists)
%fileTypeLookup = (
   '3FR' => ['TIFF', 'Hasselblad RAW format'],
   '3G2' => ['MOV',  '3rd Gen. Partnership Project 2 audio/video'],
   '3GP' => ['MOV',  '3rd Gen. Partnership Project audio/video'],
   '3GP2'=>  '3G2',
   '3GPP'=>  '3GP',
    A    => ['EXE',  'Static library'],
    AA   => ['AA',   'Audible Audiobook'],
    AAX  => ['MOV',  'Audible Enhanced Audiobook'],
    ACR  => ['DICOM','American College of Radiology ACR-NEMA'],
    ACFM => ['Font', 'Adobe Composite Font Metrics'],
    AFM  => ['Font', 'Adobe Font Metrics'],
    AMFM => ['Font', 'Adobe Multiple Master Font Metrics'],
    AI   => [['PDF','PS'], 'Adobe Illustrator'],
    AIF  =>  'AIFF',
    AIFC => ['AIFF', 'Audio Interchange File Format Compressed'],
    AIFF => ['AIFF', 'Audio Interchange File Format'],
    AIT  =>  'AI',
    APE  => ['APE',  "Monkey's Audio format"],
    APNG => ['PNG',  'Animated Portable Network Graphics'],
    ARW  => ['TIFF', 'Sony Alpha RAW format'],
    ASF  => ['ASF',  'Microsoft Advanced Systems Format'],
    AVC  => ['AVC',  'Advanced Video Connection'], # (extensions are actually _AU,_AD,_IM,_ID)
    AVI  => ['RIFF', 'Audio Video Interleaved'],
    AZW  =>  'MOBI', # (see http://wiki.mobileread.com/wiki/AZW)
    AZW3 =>  'MOBI',
    BMP  => ['BMP',  'Windows Bitmap'],
    BPG  => ['BPG',  'Better Portable Graphics'],
    BTF  => ['BTF',  'Big Tagged Image File Format'], #(unofficial)
    BZ2  => ['BZ2',  'BZIP2 archive'],
    CHM  => ['CHM',  'Microsoft Compiled HTML format'],
    CIFF => ['CRW',  'Camera Image File Format'],
    COS  => ['COS',  'Capture One Settings'],
    CR2  => ['TIFF', 'Canon RAW 2 format'],
    CR3  => ['MOV',  'Canon RAW 3 format'],
    CRM  => ['MOV',  'Canon RAW Movie'],
    CRW  => ['CRW',  'Canon RAW format'],
    CS1  => ['PSD',  'Sinar CaptureShop 1-Shot RAW'],
    DC3  =>  'DICM',
    DCM  =>  'DICM',
    DCP  => ['TIFF', 'DNG Camera Profile'],
    DCR  => ['TIFF', 'Kodak Digital Camera RAW'],
    DEX  => ['DEX',  'Dalvik Executable format'],
    DFONT=> ['Font', 'Macintosh Data fork Font'],
    DIB  => ['BMP',  'Device Independent Bitmap'],
    DIC  =>  'DICM',
    DICM => ['DICOM','Digital Imaging and Communications in Medicine'],
    DIVX => ['ASF',  'DivX media format'],
    DJV  =>  'DJVU',
    DJVU => ['AIFF', 'DjVu image'],
    DLL  => ['EXE',  'Windows Dynamic Link Library'],
    DNG  => ['TIFF', 'Digital Negative'],
    DOC  => ['FPX',  'Microsoft Word Document'],
    DOCM => [['ZIP','FPX'], 'Office Open XML Document Macro-enabled'],
    # Note: I have seen a password-protected DOCX file which was FPX-like, so I assume
    # that any other MS Office file could be like this too.  The only difference is
    # that the ZIP and FPX formats are checked first, so if this is wrong, no biggie.
    DOCX => [['ZIP','FPX'], 'Office Open XML Document'],
    DOT  => ['FPX',  'Microsoft Word Template'],
    DOTM => [['ZIP','FPX'], 'Office Open XML Document Template Macro-enabled'],
    DOTX => [['ZIP','FPX'], 'Office Open XML Document Template'],
    DPX  => ['DPX',  'Digital Picture Exchange' ],
    DR4  => ['DR4',  'Canon VRD version 4 Recipe'],
    DS2  => ['DSS',  'Digital Speech Standard 2'],
    DSS  => ['DSS',  'Digital Speech Standard'],
    DV   => ['DV',   'Digital Video'],
    DVB  => ['MOV',  'Digital Video Broadcasting'],
   'DVR-MS'=>['ASF', 'Microsoft Digital Video recording'],
    DYLIB=> ['EXE',  'Mach-O Dynamic Link Library'],
    EIP  => ['ZIP',  'Capture One Enhanced Image Package'],
    EPS  => ['EPS',  'Encapsulated PostScript Format'],
    EPS2 =>  'EPS',
    EPS3 =>  'EPS',
    EPSF =>  'EPS',
    EPUB => ['ZIP',  'Electronic Publication'],
    ERF  => ['TIFF', 'Epson Raw Format'],
    EXE  => ['EXE',  'Windows executable file'],
    EXR  => ['EXR', 'Open EXR'],
    EXIF => ['EXIF', 'Exchangable Image File Metadata'],
    EXV  => ['EXV',  'Exiv2 metadata'],
    F4A  => ['MOV',  'Adobe Flash Player 9+ Audio'],
    F4B  => ['MOV',  'Adobe Flash Player 9+ audio Book'],
    F4P  => ['MOV',  'Adobe Flash Player 9+ Protected'],
    F4V  => ['MOV',  'Adobe Flash Player 9+ Video'],
    FFF  => [['TIFF','FLIR'], 'Hasselblad Flexible File Format'],
    FLAC => ['FLAC', 'Free Lossless Audio Codec'],
    FLA  => ['FPX',  'Macromedia/Adobe Flash project'],
    FLIF => ['FLIF', 'Free Lossless Image Format'],
    FLIR => ['FLIR', 'FLIR File Format'], # (not an actual extension)
    FLV  => ['FLV',  'Flash Video'],
    FPF  => ['FPF',  'FLIR Public image Format'],
    FPX  => ['FPX',  'FlashPix'],
    GIF  => ['GIF',  'Compuserve Graphics Interchange Format'],
    GPR  => ['TIFF', 'GoPro RAW'],
    GZ   =>  'GZIP',
    GZIP => ['GZIP', 'GNU ZIP compressed archive'],
    HDP  => ['TIFF', 'Windows HD Photo'],
    HDR  => ['HDR',  'Radiance RGBE High Dynamic Range'],
    HEIC => ['MOV',  'High Efficiency Image Format still image'],
    HEIF => ['MOV',  'High Efficiency Image Format'],
    HTM  =>  'HTML',
    HTML => ['HTML', 'HyperText Markup Language'],
    ICAL =>  'ICS',
    ICC  => ['ICC',  'International Color Consortium'],
    ICM  =>  'ICC',
    ICS  => ['VCard','iCalendar Schedule'],
    IDML => ['ZIP',  'Adobe InDesign Markup Language'],
    IIQ  => ['TIFF', 'Phase One Intelligent Image Quality RAW'],
    IND  => ['IND',  'Adobe InDesign'],
    INDD => ['IND',  'Adobe InDesign Document'],
    INDT => ['IND',  'Adobe InDesign Template'],
    INX  => ['XMP',  'Adobe InDesign Interchange'],
    ISO  => ['ISO',  'ISO 9660 disk image'],
    ITC  => ['ITC',  'iTunes Cover Flow'],
    J2C  => ['JP2',  'JPEG 2000 codestream'],
    J2K  =>  'JP2',
    JNG  => ['PNG',  'JPG Network Graphics'],
    JP2  => ['JP2',  'JPEG 2000 file'],
    # JP4? - looks like a JPEG but the image data is different
    JPC  =>  'J2C',
    JPE  =>  'JPEG',
    JPEG => ['JPEG', 'Joint Photographic Experts Group'],
    JPF  =>  'JP2',
    JPG =>   'JPEG',
    JPM  => ['JP2',  'JPEG 2000 compound image'],
    JPX  => ['JP2',  'JPEG 2000 with extensions'],
    JSON => ['JSON', 'JavaScript Object Notation'],
    JXR  => ['TIFF', 'JPEG XR'],
    K25  => ['TIFF', 'Kodak DC25 RAW'],
    KDC  => ['TIFF', 'Kodak Digital Camera RAW'],
    KEY  => ['ZIP',  'Apple Keynote presentation'],
    KTH  => ['ZIP',  'Apple Keynote Theme'],
    LA   => ['RIFF', 'Lossless Audio'],
    LFP  => ['LFP',  'Lytro Light Field Picture'],
    LFR  =>  'LFP', # (Light Field RAW)
    LNK  => ['LNK',  'Windows shortcut'],
    LRI  => ['LRI',  'Light RAW'],
    M2T  =>  'M2TS',
    M2TS => ['M2TS', 'MPEG-2 Transport Stream'],
    M2V  => ['MPEG', 'MPEG-2 Video'],
    M4A  => ['MOV',  'MPEG-4 Audio'],
    M4B  => ['MOV',  'MPEG-4 audio Book'],
    M4P  => ['MOV',  'MPEG-4 Protected'],
    M4V  => ['MOV',  'MPEG-4 Video'],
    MAX  => ['FPX',  '3D Studio MAX'],
    MEF  => ['TIFF', 'Mamiya (RAW) Electronic Format'],
    MIE  => ['MIE',  'Meta Information Encapsulation format'],
    MIF  =>  'MIFF',
    MIFF => ['MIFF', 'Magick Image File Format'],
    MKA  => ['MKV',  'Matroska Audio'],
    MKS  => ['MKV',  'Matroska Subtitle'],
    MKV  => ['MKV',  'Matroska Video'],
    MNG  => ['PNG',  'Multiple-image Network Graphics'],
    MOBI => ['PDB',  'Mobipocket electronic book'],
    MODD => ['PLIST','Sony Picture Motion metadata'],
    MOI  => ['MOI',  'MOD Information file'],
    MOS  => ['TIFF', 'Creo Leaf Mosaic'],
    MOV  => ['MOV',  'Apple QuickTime movie'],
    MP3  => ['MP3',  'MPEG-1 Layer 3 audio'],
    MP4  => ['MOV',  'MPEG-4 video'],
    MPC  => ['MPC',  'Musepack Audio'],
    MPEG => ['MPEG', 'MPEG-1 or MPEG-2 audio/video'],
    MPG  =>  'MPEG',
    MPO  => ['JPEG', 'Extended Multi-Picture format'],
    MQV  => ['MOV',  'Sony Mobile Quicktime Video'],
    MRW  => ['MRW',  'Minolta RAW format'],
    MTS  =>  'M2TS',
    MXF  => ['MXF',  'Material Exchange Format'],
  # NDPI => ['TIFF', 'Hamamatsu NanoZoomer Digital Pathology Image'],
    NEF  => ['TIFF', 'Nikon (RAW) Electronic Format'],
    NEWER => 'COS',
    NMBTEMPLATE => ['ZIP','Apple Numbers Template'],
    NRW  => ['TIFF', 'Nikon RAW (2)'],
    NUMBERS => ['ZIP','Apple Numbers spreadsheet'],
    O    => ['EXE',  'Relocatable Object'],
    ODB  => ['ZIP',  'Open Document Database'],
    ODC  => ['ZIP',  'Open Document Chart'],
    ODF  => ['ZIP',  'Open Document Formula'],
    ODG  => ['ZIP',  'Open Document Graphics'],
    ODI  => ['ZIP',  'Open Document Image'],
    ODP  => ['ZIP',  'Open Document Presentation'],
    ODS  => ['ZIP',  'Open Document Spreadsheet'],
    ODT  => ['ZIP',  'Open Document Text file'],
    OFR  => ['RIFF', 'OptimFROG audio'],
    OGG  => ['OGG',  'Ogg Vorbis audio file'],
    OGV  => ['OGG',  'Ogg Video file'],
    OPUS => ['OGG',  'Ogg Opus audio file'],
    ORF  => ['ORF',  'Olympus RAW format'],
    OTF  => ['Font', 'Open Type Font'],
    PAC  => ['RIFF', 'Lossless Predictive Audio Compression'],
    PAGES => ['ZIP', 'Apple Pages document'],
    PBM  => ['PPM',  'Portable BitMap'],
    PCD  => ['PCD',  'Kodak Photo CD Image Pac'],
    PCT  =>  'PICT',
    PDB  => ['PDB',  'Palm Database'],
    PDF  => ['PDF',  'Adobe Portable Document Format'],
    PEF  => ['TIFF', 'Pentax (RAW) Electronic Format'],
    PFA  => ['Font', 'PostScript Font ASCII'],
    PFB  => ['Font', 'PostScript Font Binary'],
    PFM  => ['Font', 'Printer Font Metrics'],
    PGF  => ['PGF',  'Progressive Graphics File'],
    PGM  => ['PPM',  'Portable Gray Map'],
    PHP  => ['PHP',  'PHP Hypertext Preprocessor'],
    PHP3 =>  'PHP',
    PHP4 =>  'PHP',
    PHP5 =>  'PHP',
    PHPS =>  'PHP',
    PHTML=>  'PHP',
    PICT => ['PICT', 'Apple PICTure'],
    PLIST=> ['PLIST','Apple Property List'],
    PMP  => ['PMP',  'Sony DSC-F1 Cyber-Shot PMP'], # should stand for Proprietery Metadata Package ;)
    PNG  => ['PNG',  'Portable Network Graphics'],
    POT  => ['FPX',  'Microsoft PowerPoint Template'],
    POTM => [['ZIP','FPX'], 'Office Open XML Presentation Template Macro-enabled'],
    POTX => [['ZIP','FPX'], 'Office Open XML Presentation Template'],
    PPM  => ['PPM',  'Portable Pixel Map'],
    PPS  => ['FPX',  'Microsoft PowerPoint Slideshow'],
    PPSM => [['ZIP','FPX'], 'Office Open XML Presentation Slideshow Macro-enabled'],
    PPSX => [['ZIP','FPX'], 'Office Open XML Presentation Slideshow'],
    PPT  => ['FPX',  'Microsoft PowerPoint Presentation'],
    PPTM => [['ZIP','FPX'], 'Office Open XML Presentation Macro-enabled'],
    PPTX => [['ZIP','FPX'], 'Office Open XML Presentation'],
    PRC  => ['PDB',  'Palm Database'],
    PS   => ['PS',   'PostScript'],
    PS2  =>  'PS',
    PS3  =>  'PS',
    PSB  => ['PSD',  'Photoshop Large Document'],
    PSD  => ['PSD',  'Photoshop Document'],
    PSDT => ['PSD',  'Photoshop Document Template'],
    PSP  => ['PSP',  'Paint Shop Pro'],
    PSPFRAME => 'PSP',
    PSPIMAGE => 'PSP',
    PSPSHAPE => 'PSP',
    PSPTUBE  => 'PSP',
    QIF  =>  'QTIF',
    QT   =>  'MOV',
    QTI  =>  'QTIF',
    QTIF => ['QTIF', 'QuickTime Image File'],
    R3D  => ['R3D',  'Redcode RAW Video'],
    RA   => ['Real', 'Real Audio'],
    RAF  => ['RAF',  'FujiFilm RAW Format'],
    RAM  => ['Real', 'Real Audio Metafile'],
    RAR  => ['RAR',  'RAR Archive'],
    RAW  => [['RAW','TIFF'], 'Kyocera Contax N Digital RAW or Panasonic RAW'],
    RIF  =>  'RIFF',
    RIFF => ['RIFF', 'Resource Interchange File Format'],
    RM   => ['Real', 'Real Media'],
    RMVB => ['Real', 'Real Media Variable Bitrate'],
    RPM  => ['Real', 'Real Media Plug-in Metafile'],
    RSRC => ['RSRC', 'Mac OS Resource'],
    RTF  => ['RTF',  'Rich Text Format'],
    RV   => ['Real', 'Real Video'],
    RW2  => ['TIFF', 'Panasonic RAW 2'],
    RWL  => ['TIFF', 'Leica RAW'],
    RWZ  => ['RWZ',  'Rawzor compressed image'],
    SEQ  => ['FLIR', 'FLIR image Sequence'],
    SKETCH => ['ZIP', 'Sketch design file'],
    SO   => ['EXE',  'Shared Object file'],
    SR2  => ['TIFF', 'Sony RAW Format 2'],
    SRF  => ['TIFF', 'Sony RAW Format'],
    SRW  => ['TIFF', 'Samsung RAW format'],
    SVG  => ['XMP',  'Scalable Vector Graphics'],
    SWF  => ['SWF',  'Shockwave Flash'],
    TAR  => ['TAR',  'TAR archive'],
    THM  => ['JPEG', 'Canon Thumbnail'],
    THMX => [['ZIP','FPX'], 'Office Open XML Theme'],
    TIF  =>  'TIFF',
    TIFF => ['TIFF', 'Tagged Image File Format'],
    TORRENT => ['Torrent', 'BitTorrent description file'],
    TS   =>  'M2TS',
    TTC  => ['Font', 'True Type Font Collection'],
    TTF  => ['Font', 'True Type Font'],
    TUB  => 'PSP',
    VCARD=> ['VCard','Virtual Card'],
    VCF  => 'VCARD',
    VOB  => ['MPEG', 'Video Object'],
    VRD  => ['VRD',  'Canon VRD Recipe Data'],
    VSD  => ['FPX',  'Microsoft Visio Drawing'],
    WAV  => ['RIFF', 'WAVeform (Windows digital audio)'],
    WDP  => ['TIFF', 'Windows Media Photo'],
    WEBM => ['MKV',  'Google Web Movie'],
    WEBP => ['RIFF', 'Google Web Picture'],
    WMA  => ['ASF',  'Windows Media Audio'],
    WMF  => ['WMF',  'Windows Metafile Format'],
    WMV  => ['ASF',  'Windows Media Video'],
    WV   => ['RIFF', 'WavePack lossless audio'],
    X3F  => ['X3F',  'Sigma RAW format'],
    XCF  => ['XCF',  'GIMP native image format'],
    XHTML=> ['HTML', 'Extensible HyperText Markup Language'],
    XLA  => ['FPX',  'Microsoft Excel Add-in'],
    XLAM => [['ZIP','FPX'], 'Office Open XML Spreadsheet Add-in Macro-enabled'],
    XLS  => ['FPX',  'Microsoft Excel Spreadsheet'],
    XLSB => [['ZIP','FPX'], 'Office Open XML Spreadsheet Binary'],
    XLSM => [['ZIP','FPX'], 'Office Open XML Spreadsheet Macro-enabled'],
    XLSX => [['ZIP','FPX'], 'Office Open XML Spreadsheet'],
    XLT  => ['FPX',  'Microsoft Excel Template'],
    XLTM => [['ZIP','FPX'], 'Office Open XML Spreadsheet Template Macro-enabled'],
    XLTX => [['ZIP','FPX'], 'Office Open XML Spreadsheet Template'],
    XMP  => ['XMP',  'Extensible Metadata Platform'],
    WTV  => ['WTV',  'Windows recorded TV show'],
    ZIP  => ['ZIP',  'ZIP archive'],
);

# typical extension for each file type (if different than FileType)
# - case is not significant
my %fileTypeExt = (
    'Canon 1D RAW' => 'tif',
    DICOM   => 'dcm',
    FLIR    => 'fff',
    GZIP    => 'gz',
    JPEG    => 'jpg',
    M2TS    => 'mts',
    MPEG    => 'mpg',
    TIFF    => 'tif',
    VCard   => 'vcf',
);

# descriptions for file types not found in above file extension lookup
my %fileDescription = (
    DICOM => 'Digital Imaging and Communications in Medicine',
    XML   => 'Extensible Markup Language',
    'Win32 EXE' => 'Windows 32-bit Executable',
    'Win32 DLL' => 'Windows 32-bit Dynamic Link Library',
    'Win64 EXE' => 'Windows 64-bit Executable',
    'Win64 DLL' => 'Windows 64-bit Dynamic Link Library',
);

# MIME types for applicable file types above
# (missing entries default to 'application/unknown', but note that other MIME
#  types may be specified by some modules, eg. QuickTime.pm and RIFF.pm)
%mimeType = (
   '3FR' => 'image/x-hasselblad-3fr',
    AA   => 'audio/audible',
    AI   => 'application/vnd.adobe.illustrator',
    AIFF => 'audio/x-aiff',
    APE  => 'audio/x-monkeys-audio',
    APNG => 'image/apng',
    ASF  => 'video/x-ms-asf',
    ARW  => 'image/x-sony-arw',
    BMP  => 'image/bmp',
    BPG  => 'image/bpg',
    BTF  => 'image/x-tiff-big', #(NC) (ref http://www.asmail.be/msg0055371937.html)
    BZ2  => 'application/bzip2',
   'Canon 1D RAW' => 'image/x-raw', # (uses .TIF file extension)
    CHM  => 'application/x-chm',
    CR2  => 'image/x-canon-cr2',
    CR3  => 'image/x-canon-cr3',
    CRM  => 'video/x-canon-crm',
    CRW  => 'image/x-canon-crw',
    DCR  => 'image/x-kodak-dcr',
    DEX  => 'application/octet-stream',
    DFONT=> 'application/x-dfont',
    DICOM=> 'application/dicom',
    DIVX => 'video/divx',
    DJVU => 'image/vnd.djvu',
    DNG  => 'image/x-adobe-dng',
    DOC  => 'application/msword',
    DOCM => 'application/vnd.ms-word.document.macroEnabled',
    DOCX => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    DOT  => 'application/msword',
    DOTM => 'application/vnd.ms-word.template.macroEnabledTemplate',
    DOTX => 'application/vnd.openxmlformats-officedocument.wordprocessingml.template',
    DPX  => 'image/x-dpx',
    DS2  => 'audio/x-ds2',
    DSS  => 'audio/x-dss',
    DV   => 'video/x-dv',
   'DVR-MS' => 'video/x-ms-dvr',
    EIP  => 'application/x-captureone', #(NC)
    EPS  => 'application/postscript',
    ERF  => 'image/x-epson-erf',
    EXE  => 'application/octet-stream',
    EXV  => 'image/x-exv',
    FFF  => 'image/x-hasselblad-fff',
    FLA  => 'application/vnd.adobe.fla',
    FLAC => 'audio/flac',
    FLIF => 'image/flif',
    FLV  => 'video/x-flv',
    Font => 'application/x-font-type1', # covers PFA, PFB and PFM (not sure about PFM)
    FPX  => 'image/vnd.fpx',
    GIF  => 'image/gif',
    GPR  => 'image/x-gopro-gpr',
    GZIP => 'application/x-gzip',
    HDP  => 'image/vnd.ms-photo',
    HDR  => 'image/vnd.radiance',
    HTML => 'text/html',
    ICC  => 'application/vnd.iccprofile',
    ICS  => 'text/calendar',
    IDML => 'application/vnd.adobe.indesign-idml-package',
    IIQ  => 'image/x-raw',
    IND  => 'application/x-indesign',
    INX  => 'application/x-indesign-interchange', #PH (NC)
    ISO  => 'application/x-iso9660-image',
    ITC  => 'application/itunes',
    JNG  => 'image/jng',
    J2C  => 'image/x-j2c', #PH (NC)
    JP2  => 'image/jp2',
    JPEG => 'image/jpeg',
    JPM  => 'image/jpm',
    JPX  => 'image/jpx',
    JSON => 'application/json',
    K25  => 'image/x-kodak-k25',
    KDC  => 'image/x-kodak-kdc',
    KEY  => 'application/x-iwork-keynote-sffkey',
    LFP  => 'image/x-lytro-lfp', #PH (NC)
    LNK  => 'application/octet-stream',
    LRI  => 'image/x-light-lri',
    MAX  => 'application/x-3ds',
    M2T  => 'video/mpeg',
    M2TS => 'video/m2ts',
    MEF  => 'image/x-mamiya-mef',
    MIE  => 'application/x-mie',
    MIFF => 'application/x-magick-image',
    MKA  => 'audio/x-matroska',
    MKS  => 'application/x-matroska',
    MKV  => 'video/x-matroska',
    MNG  => 'video/mng',
    MOBI => 'application/x-mobipocket-ebook',
    MOS  => 'image/x-raw',
    MOV  => 'video/quicktime',
    MP3  => 'audio/mpeg',
    MP4  => 'video/mp4',
    MPC  => 'audio/x-musepack',
    MPEG => 'video/mpeg',
    MRW  => 'image/x-minolta-mrw',
    MXF  => 'application/mxf',
    NEF  => 'image/x-nikon-nef',
    NRW  => 'image/x-nikon-nrw',
    NUMBERS => 'application/x-iwork-numbers-sffnumbers',
    ODB  => 'application/vnd.oasis.opendocument.database',
    ODC  => 'application/vnd.oasis.opendocument.chart',
    ODF  => 'application/vnd.oasis.opendocument.formula',
    ODG  => 'application/vnd.oasis.opendocument.graphics',
    ODI  => 'application/vnd.oasis.opendocument.image',
    ODP  => 'application/vnd.oasis.opendocument.presentation',
    ODS  => 'application/vnd.oasis.opendocument.spreadsheet',
    ODT  => 'application/vnd.oasis.opendocument.text',
    OGG  => 'audio/ogg',
    OGV  => 'video/ogg',
    EXR  => 'image/x-exr',
    ORF  => 'image/x-olympus-orf',
    OTF  => 'application/x-font-otf',
    PAGES=> 'application/x-iwork-pages-sffpages',
    PBM  => 'image/x-portable-bitmap',
    PCD  => 'image/x-photo-cd',
    PDB  => 'application/vnd.palm',
    PDF  => 'application/pdf',
    PEF  => 'image/x-pentax-pef',
    PFA  => 'application/x-font-type1', # (needed if handled by PostScript module)
    PGF  => 'image/pgf',
    PGM  => 'image/x-portable-graymap',
    PHP  => 'application/x-httpd-php',
    PICT => 'image/pict',
    PLIST=> 'application/xml', # (binary PLIST format is 'application/x-plist', recognized at run time)
    PNG  => 'image/png',
    POT  => 'application/vnd.ms-powerpoint',
    POTM => 'application/vnd.ms-powerpoint.template.macroEnabled',
    POTX => 'application/vnd.openxmlformats-officedocument.presentationml.template',
    PPM  => 'image/x-portable-pixmap',
    PPS  => 'application/vnd.ms-powerpoint',
    PPSM => 'application/vnd.ms-powerpoint.slideshow.macroEnabled',
    PPSX => 'application/vnd.openxmlformats-officedocument.presentationml.slideshow',
    PPT  => 'application/vnd.ms-powerpoint',
    PPTM => 'application/vnd.ms-powerpoint.presentation.macroEnabled',
    PPTX => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    PS   => 'application/postscript',
    PSD  => 'application/vnd.adobe.photoshop',
    PSP  => 'image/x-paintshoppro', #(NC)
    QTIF => 'image/x-quicktime',
    R3D  => 'video/x-red-r3d', #PH (invented)
    RA   => 'audio/x-pn-realaudio',
    RAF  => 'image/x-fujifilm-raf',
    RAM  => 'audio/x-pn-realaudio',
    RAR  => 'application/x-rar-compressed',
    RAW  => 'image/x-raw',
    RM   => 'application/vnd.rn-realmedia',
    RMVB => 'application/vnd.rn-realmedia-vbr',
    RPM  => 'audio/x-pn-realaudio-plugin',
    RSRC => 'application/ResEdit',
    RTF  => 'text/rtf',
    RV   => 'video/vnd.rn-realvideo',
    RW2  => 'image/x-panasonic-rw2',
    RWL  => 'image/x-leica-rwl',
    RWZ  => 'image/x-rawzor', #(duplicated in Rawzor.pm)
    SKETCH => 'application/sketch',
    SR2  => 'image/x-sony-sr2',
    SRF  => 'image/x-sony-srf',
    SRW  => 'image/x-samsung-srw',
    SVG  => 'image/svg+xml',
    SWF  => 'application/x-shockwave-flash',
    TAR  => 'application/x-tar',
    THMX => 'application/vnd.ms-officetheme',
    TIFF => 'image/tiff',
    Torrent => 'application/x-bittorrent',
    TTC  => 'application/x-font-ttf',
    TTF  => 'application/x-font-ttf',
    VCard=> 'text/vcard',
    VSD  => 'application/x-visio',
    WDP  => 'image/vnd.ms-photo',
    WEBM => 'video/webm',
    WMA  => 'audio/x-ms-wma',
    WMF  => 'application/x-wmf',
    WMV  => 'video/x-ms-wmv',
    WTV  => 'video/x-ms-wtv',
    X3F  => 'image/x-sigma-x3f',
    XCF  => 'image/x-xcf',
    XLA  => 'application/vnd.ms-excel',
    XLAM => 'application/vnd.ms-excel.addin.macroEnabled',
    XLS  => 'application/vnd.ms-excel',
    XLSB => 'application/vnd.ms-excel.sheet.binary.macroEnabled',
    XLSM => 'application/vnd.ms-excel.sheet.macroEnabled',
    XLSX => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    XLT  => 'application/vnd.ms-excel',
    XLTM => 'application/vnd.ms-excel.template.macroEnabled',
    XLTX => 'application/vnd.openxmlformats-officedocument.spreadsheetml.template',
    XML  => 'application/xml',
    XMP  => 'application/rdf+xml',
    ZIP  => 'application/zip',
);

# module names for processing routines of each file type
# - undefined entries default to same module name as file type
# - module name '' defaults to Image::ExifTool
# - module name '0' indicates a recognized but unsupported file
my %moduleName = (
    AA   => 'Audible',
    AVC  => 0,
    BTF  => 'BigTIFF',
    BZ2  => 0,
    CRW  => 'CanonRaw',
    CHM  => 'EXE',
    COS  => 'CaptureOne',
    DEX  => 0,
    DOCX => 'OOXML',
    DR4  => 'CanonVRD',
    DSS  => 'Olympus',
    EPS  => 'PostScript',
    EXIF => '',
    EXR  => 'OpenEXR',
    EXV  => '',
    ICC  => 'ICC_Profile',
    IND  => 'InDesign',
    FLV  => 'Flash',
    FPF  => 'FLIR',
    FPX  => 'FlashPix',
    GZIP => 'ZIP',
    HDR  => 'Radiance',
    JP2  => 'Jpeg2000',
    JPEG => '',
    LFP  => 'Lytro',
    LRI  => 0,
    MOV  => 'QuickTime',
    MKV  => 'Matroska',
    MP3  => 'ID3',
    MRW  => 'MinoltaRaw',
    OGG  => 'Ogg',
    ORF  => 'Olympus',
    PDB  => 'Palm',
    PCD  => 'PhotoCD',
    PHP  => 0,
    PMP  => 'Sony',
    PS   => 'PostScript',
    PSD  => 'Photoshop',
    QTIF => 'QuickTime',
    R3D  => 'Red',
    RAF  => 'FujiFilm',
    RAR  => 'ZIP',
    RAW  => 'KyoceraRaw',
    RWZ  => 'Rawzor',
    SWF  => 'Flash',
    TAR  => 0,
    TIFF => '',
    VRD  => 'CanonVRD',
    WMF  => 0,
    X3F  => 'SigmaRaw',
    XCF  => 'GIMP',
);

# quick "magic number" file test used to avoid loading module unnecessarily:
# - regular expression evaluated on first 1024 bytes of file
# - must match beginning at first byte in file
# - this test must not be more stringent than module logic
%magicNumber = (
    AA   => '.{4}\x57\x90\x75\x36',
    AIFF => '(FORM....AIF[FC]|AT&TFORM)',
    APE  => '(MAC |APETAGEX|ID3)',
    ASF  => '\x30\x26\xb2\x75\x8e\x66\xcf\x11\xa6\xd9\x00\xaa\x00\x62\xce\x6c',
    AVC  => '\+A\+V\+C\+',
    Torrent => 'd\d+:\w+',
    BMP  => 'BM',
    BPG  => "BPG\xfb",
    BTF  => '(II\x2b\0|MM\0\x2b)',
    BZ2  => 'BZh[1-9]\x31\x41\x59\x26\x53\x59',
    CHM  => 'ITSF.{20}\x10\xfd\x01\x7c\xaa\x7b\xd0\x11\x9e\x0c\0\xa0\xc9\x22\xe6\xec',
    CRW  => '(II|MM).{4}HEAP(CCDR|JPGM)',
    DEX  => "dex\n035\0",
    DICOM=> '(.{128}DICM|\0[\x02\x04\x06\x08]\0[\0-\x20]|[\x02\x04\x06\x08]\0[\0-\x20]\0)',
    DOCX => 'PK\x03\x04',
    DPX  => '(SDPX|XPDS)',
    DR4  => 'IIII\x04\0\x04\0',
    DSS  => '(\x02dss|\x03ds2)',
    DV   => '\x1f\x07\0[\x3f\xbf]', # (not tested if extension recognized)
    EPS  => '(%!PS|%!Ad|\xc5\xd0\xd3\xc6)',
    EXE  => '(MZ|\xca\xfe\xba\xbe|\xfe\xed\xfa[\xce\xcf]|[\xce\xcf]\xfa\xed\xfe|Joy!peff|\x7fELF|#!\s*/\S*bin/|!<arch>\x0a)',
    EXIF => '(II\x2a\0|MM\0\x2a)',
    EXR  => '\x76\x2f\x31\x01',
    EXV  => '\xff\x01Exiv2',
    FLAC => '(fLaC|ID3)',
    FLIF => 'FLIF[0-\x6f][0-2]',
    FLIR => '[AF]FF\0',
    FLV  => 'FLV\x01',
    Font => '((\0\x01\0\0|OTTO|true|typ1)[\0\x01]|ttcf\0[\x01\x02]\0\0|\0[\x01\x02]|' .
            '(.{6})?%!(PS-(AdobeFont-|Bitstream )|FontType1-)|Start(Comp|Master)?FontMetrics)',
    FPF  => 'FPF Public Image Format\0',
    FPX  => '\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1',
    GIF  => 'GIF8[79]a',
    GZIP => '\x1f\x8b\x08',
    HDR  => '#\?(RADIANCE|RGBE)\x0a',
    HTML => '(\xef\xbb\xbf)?\s*(?i)<(!DOCTYPE\s+HTML|HTML|\?xml)', # (case insensitive)
    ICC  => '.{12}(scnr|mntr|prtr|link|spac|abst|nmcl|nkpf)(XYZ |Lab |Luv |YCbr|Yxy |RGB |GRAY|HSV |HLS |CMYK|CMY |[2-9A-F]CLR){2}',
    IND  => '\x06\x06\xed\xf5\xd8\x1d\x46\xe5\xbd\x31\xef\xe7\xfe\x74\xb7\x1d',
  # ISO  =>  signature is at byte 32768
    ITC  => '.{4}itch',
    JP2  => '(\0\0\0\x0cjP(  |\x1a\x1a)\x0d\x0a\x87\x0a|\xff\x4f\xff\x51\0)',
    JPEG => '\xff\xd8\xff',
    JSON => '\s*(\[\s*)?\{\s*"[^"]+"\s*:',
    LFP  => '\x89LFP\x0d\x0a\x1a\x0a',
    LNK  => '.{4}\x01\x14\x02\0{5}\xc0\0{6}\x46',
    LRI  => 'LELR \0',
    M2TS => '(....)?\x47',
    MIE  => '~[\x10\x18]\x04.0MIE',
    MIFF => 'id=ImageMagick',
    MKV  => '\x1a\x45\xdf\xa3',
    MOV  => '.{4}(free|skip|wide|ftyp|pnot|PICT|pict|moov|mdat|junk|uuid)', # (duplicated in WriteQuickTime.pl !!)
  # MP3  =>  difficult to rule out
    MPC  => '(MP\+|ID3)',
    MOI  => 'V6',
    MPEG => '\0\0\x01[\xb0-\xbf]',
    MRW  => '\0MR[MI]',
    MXF  => '\x06\x0e\x2b\x34\x02\x05\x01\x01\x0d\x01\x02', # (not tested if extension recognized)
    OGG  => '(OggS|ID3)',
    ORF  => '(II|MM)',
    PDB  => '.{60}(\.pdfADBE|TEXtREAd|BVokBDIC|DB99DBOS|PNRdPPrs|DataPPrs|vIMGView|PmDBPmDB|InfoINDB|ToGoToGo|SDocSilX|JbDbJBas|JfDbJFil|DATALSdb|Mdb1Mdb1|BOOKMOBI|DataPlkr|DataSprd|SM01SMem|TEXtTlDc|InfoTlIf|DataTlMl|DataTlPt|dataTDBP|TdatTide|ToRaTRPW|zTXTGPlm|BDOCWrdS)',
  # PCD  =>  signature is at byte 2048
    PDF  => '\s*%PDF-\d+\.\d+',
    PGF  => 'PGF',
    PHP  => '<\?php\s',
    PICT => '(.{10}|.{522})(\x11\x01|\x00\x11)',
    PLIST=> '(bplist0|\s*<|\xfe\xff\x00)',
    PMP  => '.{8}\0{3}\x7c.{112}\xff\xd8\xff\xdb',
    PNG  => '(\x89P|\x8aM|\x8bJ)NG\r\n\x1a\n',
    PPM  => 'P[1-6]\s+',
    PS   => '(%!PS|%!Ad|\xc5\xd0\xd3\xc6)',
    PSD  => '8BPS\0[\x01\x02]',
    PSP  => 'Paint Shop Pro Image File\x0a\x1a\0{5}',
    QTIF => '.{4}(idsc|idat|iicc)',
    R3D  => '\0\0..RED(1|2)',
    RAF  => 'FUJIFILM',
    RAR  => 'Rar!\x1a\x07\0',
    RAW  => '(.{25}ARECOYK|II|MM)',
    Real => '(\.RMF|\.ra\xfd|pnm://|rtsp://|http://)',
    RIFF => '(RIFF|LA0[234]|OFR |LPAC|wvpk|RF64)', # RIFF plus other variants
    RSRC => '(....)?\0\0\x01\0',
    RTF  => '[\n\r]*\\{[\n\r]*\\\\rtf',
    RWZ  => 'rawzor',
    SWF  => '[FC]WS[^\0]',
    TAR  => '.{257}ustar(  )?\0', # (this doesn't catch old-style tar files)
    TIFF => '(II|MM)', # don't test magic number (some raw formats are different)
    VCard=> '(?i)BEGIN:(VCARD|VCALENDAR)\r\n',
    VRD  => 'CANON OPTIONAL DATA\0',
    WMF  => '(\xd7\xcd\xc6\x9a\0\0|\x01\0\x09\0\0\x03)',
    WTV  => '\xb7\xd8\x00\x20\x37\x49\xda\x11\xa6\x4e\x00\x07\xe9\x5e\xad\x8d',
    X3F  => 'FOVb',
    XCF  => 'gimp xcf ',
    XMP  => '\0{0,3}(\xfe\xff|\xff\xfe|\xef\xbb\xbf)?\0{0,3}\s*<',
    ZIP  => 'PK\x03\x04',
);

# file types with weak magic number recognition
my %weakMagic = ( MP3 => 1 );

# file types that are determined by the process proc when FastScan == 3
# (when done, the process proc must exit after SetFileType if FastScan is 3)
my %processType = map { $_ => 1 } qw(JPEG TIFF XMP AIFF EXE Font PS Real VCard);

# lookup for valid character set names (keys are all lower case)
%charsetName = (
    #   Charset setting                       alias(es)
    # -------------------------   --------------------------------------------
    utf8        => 'UTF8',        cp65001 => 'UTF8', 'utf-8' => 'UTF8',
    latin       => 'Latin',       cp1252  => 'Latin', latin1 => 'Latin',
    latin2      => 'Latin2',      cp1250  => 'Latin2',
    cyrillic    => 'Cyrillic',    cp1251  => 'Cyrillic', russian => 'Cyrillic',
    greek       => 'Greek',       cp1253  => 'Greek',
    turkish     => 'Turkish',     cp1254  => 'Turkish',
    hebrew      => 'Hebrew',      cp1255  => 'Hebrew',
    arabic      => 'Arabic',      cp1256  => 'Arabic',
    baltic      => 'Baltic',      cp1257  => 'Baltic',
    vietnam     => 'Vietnam',     cp1258  => 'Vietnam',
    thai        => 'Thai',        cp874   => 'Thai',
    doslatinus  => 'DOSLatinUS',  cp437   => 'DOSLatinUS',
    doslatin1   => 'DOSLatin1',   cp850   => 'DOSLatin1',
    macroman    => 'MacRoman',    cp10000 => 'MacRoman', mac => 'MacRoman', roman => 'MacRoman',
    maclatin2   => 'MacLatin2',   cp10029 => 'MacLatin2',
    maccyrillic => 'MacCyrillic', cp10007 => 'MacCyrillic',
    macgreek    => 'MacGreek',    cp10006 => 'MacGreek',
    macturkish  => 'MacTurkish',  cp10081 => 'MacTurkish',
    macromanian => 'MacRomanian', cp10010 => 'MacRomanian',
    maciceland  => 'MacIceland',  cp10079 => 'MacIceland',
    maccroatian => 'MacCroatian', cp10082 => 'MacCroatian',
);

# default group priority for writing
# (NOTE: tags in groups not specified here will not be written unless
#  overridden by the module or specified when writing)
my @defaultWriteGroups = qw(EXIF IPTC XMP MakerNotes Photoshop ICC_Profile CanonVRD Adobe);

# group hash for ExifTool-generated tags
my %allGroupsExifTool = ( 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'ExifTool' );

# special tag names (not used for tag info)
%specialTags = map { $_ => 1 } qw(
    TABLE_NAME       SHORT_NAME  PROCESS_PROC  WRITE_PROC  CHECK_PROC
    GROUPS           FORMAT      FIRST_ENTRY   TAG_PREFIX  PRINT_CONV
    WRITABLE         TABLE_DESC  NOTES         IS_OFFSET   IS_SUBDIR
    EXTRACT_UNKNOWN  NAMESPACE   PREFERRED     SRC_TABLE   PRIORITY
    AVOID            WRITE_GROUP LANG_INFO     VARS        DATAMEMBER
    SET_GROUP1
);

# headers for various segment types
$exifAPP1hdr = "Exif\0\0";
$xmpAPP1hdr = "http://ns.adobe.com/xap/1.0/\0";
$xmpExtAPP1hdr = "http://ns.adobe.com/xmp/extension/\0";
$psAPP13hdr = "Photoshop 3.0\0";
$psAPP13old = 'Adobe_Photoshop2.5:';

sub DummyWriteProc { return 1; }

# lookup for user lenses defined in @Image::ExifTool::UserDefined::Lenses
%Image::ExifTool::userLens = ( );

# queued plug-in tags to add to lookup
@Image::ExifTool::pluginTags = ( );
%Image::ExifTool::pluginTags = ( );

my %systemTagsNotes = (
    Notes => q{
        extracted only if specifically requested or the SystemTags or RequestAll API
        option is set
    },
);

# tag information for preview image -- this should be used for all
# PreviewImage tags so they are handled properly when reading/writing
%Image::ExifTool::previewImageTagInfo = (
    Name => 'PreviewImage',
    Writable => 'undef',
    # a value of 'none' is ok...
    WriteCheck => '$val eq "none" ? undef : $self->CheckImage(\$val)',
    DataTag => 'PreviewImage',
    # accept either scalar or scalar reference
    RawConv => '$self->ValidateImage(ref $val ? $val : \$val, $tag)',
    # we allow preview image to be set to '', but we don't want a zero-length value
    # in the IFD, so set it temorarily to 'none'.  Note that the length is <= 4,
    # so this value will fit in the IFD so the preview fixup won't be generated.
    ValueConvInv => '$val eq "" and $val="none"; $val',
);

# extra tags that aren't truly EXIF tags, but are generated by the script
# Note: any tag in this list with a name corresponding to a Group0 name is
#       used to write the entire corresponding directory as a block.
%Image::ExifTool::Extra = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { NO_ID => 1 }, # tag ID's aren't meaningful for these tags
    WRITE_PROC => \&DummyWriteProc,
    Error   => {
        Priority => 0,
        Groups => \%allGroupsExifTool,
        Notes => q{
            returns errors that may have occurred while reading or writing a file.  Any
            Error will prevent the file from being processed.  Minor errors may be
            downgraded to warnings with the -m or IgnoreMinorErrors option
        },
    },
    Warning => {
        Priority => 0,
        Groups => \%allGroupsExifTool,
        Notes => q{
            returns warnings that may have occurred while reading or writing a file.
            Use the -a or Duplicates option to see all warnings if more than one
            occurred. Minor warnings may be ignored with the -m or IgnoreMinorErrors
            option.  Minor warnings with a capital "M" in the "[Minor]" designation
            indicate that the processing is affected by ignoring the warning
        },
    },
    Comment => {
        Notes => 'comment embedded in JPEG, GIF89a or PPM/PGM/PBM image',
        Writable => 1,
        WriteGroup => 'Comment',
        Priority => 0,  # to preserve order of JPEG COM segments
    },
    Directory => {
        Groups => { 1 => 'System' },
        Notes => q{
            the directory of the file as specified in the call to ExifTool, or "." if no
            directory was specified.  May be written to move the file to another
            directory that will be created if doesn't already exist
        },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1,
        RawConv => '$self->ConvertFileName($val)',
        # translate backslashes in directory names and add trailing '/'
        ValueConvInv => '$_ = $self->InverseFileName($val); m{[^/]$} and $_ .= "/"; $_',
    },
    FileName => {
        Groups => { 1 => 'System' },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1,
        Notes => q{
            may be written with a full path name to set FileName and Directory in one
            operation.  This is such a powerful feature that a TestName tag is provided
            to allow dry-run tests before actually writing the file name.  See
            L<filename.html|../filename.html> for more information on writing the
            FileName, Directory and TestName tags
        },
        RawConv => '$self->ConvertFileName($val)',
        ValueConvInv => '$self->InverseFileName($val)',
    },
    FilePath => {
        Groups => { 1 => 'System' },
        Notes => q{
            absolute path of source file. Not generated unless specifically requested or
            the RequestAll API option is set.  Does not support Windows Unicode file
            names
        },
    },
    TestName => {
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1,
        WriteOnly => 1,
        Notes => q{
            this write-only tag may be used instead of FileName for dry-run tests of the
            file renaming feature.  Writing this tag prints the old and new file names
            to the console, but does not affect the file itself
        },
        ValueConvInv => '$self->InverseFileName($val)',
    },
    FileSequence => {
        Groups => { 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'Other' },
        Notes => q{
            sequence number for each source file when extracting or copying information,
            including files that fail the -if condition of the command-line application,
            beginning at 0 for the first file.  Not generated unless specifically
            requested or the RequestAll API option is set
        },
    },
    FileSize => {
        Groups => { 1 => 'System' },
        Notes => q{
            note that the print conversion for this tag uses historic prefixes: 1 kB =
            1024 bytes, etc.
        },
        PrintConv => \&ConvertFileSize,
    },
    ResourceForkSize => {
        Groups => { 1 => 'System' },
        Notes => q{
            size of the file's resource fork if it contains data.  Mac OS only.  If this
            tag is generated the ExtractEmbedded option may be used to extract
            resource-fork information as a sub-document.  When writing, the resource
            fork is preserved by default, but it may be deleted with C<-rsrc:all=> on
            the command line
        },
        PrintConv => \&ConvertFileSize,
    },
    FileType => {
        Notes => q{
            a short description of the file type.  For many file types this is the just
            the uppercase file extension
        },
    },
    FileTypeExtension => {
        Notes => q{
            a common lowercase extension for this file type, or uppercase with the -n
            option
        },
        PrintConv => 'lc $val',
    },
    FileModifyDate => {
        Description => 'File Modification Date/Time',
        Notes => q{
            the filesystem modification date/time.  Note that ExifTool may not be able
            to handle filesystem dates before 1970 depending on the limitations of the
            system's standard libraries
        },
        Groups => { 1 => 'System', 2 => 'Time' },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        # all writable pseudo-tags must be protected so -tagsfromfile fails with
        # unrecognized files unless a pseudo tag is specified explicitly
        Protected => 1,
        Shift => 'Time',
        ValueConv => 'ConvertUnixTime($val,1)',
        ValueConvInv => 'GetUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    FileAccessDate => {
        Description => 'File Access Date/Time',
        Notes => q{
            the date/time of last access of the file.  Note that this access time is
            updated whenever any software, including ExifTool, reads the file
        },
        Groups => { 1 => 'System', 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    FileCreateDate => {
        Description => 'File Creation Date/Time',
        Notes => q{
            the filesystem creation date/time.  Windows/Mac only.  In Windows, the file
            creation date/time is preserved by default when writing if Win32API::File
            and Win32::API are available.  On Mac, this tag is extracted only if it or
            the MacOS group is specifically requested or the RequestAll API option is
            set to 2 or higher.  Requires "setfile" for writing on Mac
        },
        Groups => { 1 => 'System', 2 => 'Time' },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1, # all writable pseudo-tags must be protected!
        Shift => 'Time',
        ValueConv => '$^O eq "darwin" ? $val : ConvertUnixTime($val,1)',
        ValueConvInv => q{
            return GetUnixTime($val,1) if $^O eq 'MSWin32';
            return $val if $^O eq 'darwin';
            warn "This tag is Windows/Mac only\n";
            return undef;
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    FileInodeChangeDate => {
        Description => 'File Inode Change Date/Time',
        Notes => q{
            the date/time when the file's directory information was last changed.
            Non-Windows systems only
        },
        Groups => { 1 => 'System', 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    FilePermissions => {
        Groups => { 1 => 'System' },
        Notes => q{
            r=read, w=write and x=execute permissions for the file owner, group and
            others.  The ValueConv value is an octal number so bit test operations on
            this value should be done in octal, eg. 'oct($filePermissions#) & 0200'
        },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1, # all writable pseudo-tags must be protected!
        ValueConv => 'sprintf("%.3o", $val & 0777)',
        ValueConvInv => 'oct($val)',
        PrintConv => sub {
            my ($mask, $str, $val) = (0400, '', oct(shift));
            while ($mask) {
                foreach (qw(r w x)) {
                    $str .= $val & $mask ? $_ : '-';
                    $mask >>= 1;
                }
            }
            return $str;
        },
        PrintConvInv => sub {
            my ($bit, $val, $str) = (8, 0, shift);
            return undef if length($str) != 9;
            while ($bit >= 0) {
                foreach (qw(r w x)) {
                    $val |= (1 << $bit) if substr($str, 8-$bit, 1) eq $_;
                    --$bit;
                }
            }
            return sprintf('%.3o', $val);
        },
    },
    FileAttributes => {
        Groups => { 1 => 'System' },
        Notes => q{
            extracted only if specifically requested or the SystemTags or RequestAll API
            option is set.  2 or 3 values: 0. File type, 1. Attribute bits, 2. Windows
            attribute bits if Win32API::File is available
        },
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => [{ # stat device types (bitmask 0xf000)
            0x0000 => 'Unknown',
            0x1000 => 'FIFO',
            0x2000 => 'Character',
            0x3000 => 'Mux Character',
            0x4000 => 'Directory',
            0x5000 => 'XENIX Named',
            0x6000 => 'Block',
            0x7000 => 'Mux Block',
            0x8000 => 'Regular',
            0x9000 => 'VxFS Compressed',
            0xa000 => 'Symbolic Link',
            0xb000 => 'Solaris Shadow Inode',
            0xc000 => 'Socket',
            0xd000 => 'Solaris Door',
            0xe000 => 'BSD Whiteout',
        },{ BITMASK => { # stat attribute bits (bitmask 0x0e00)
            9 => 'Sticky',
            10 => 'Set Group ID',
            11 => 'Set User ID',
        }},{ BITMASK => { # Windows attribute bits
            0 => 'Read Only',
            1 => 'Hidden',
            2 => 'System',
            3 => 'Volume Label',
            4 => 'Directory',
            5 => 'Archive',
            6 => 'Device',
            7 => 'Normal',
            8 => 'Temporary',
            9 => 'Sparse File',
            10 => 'Reparse Point',
            11 => 'Compressed',
            12 => 'Offline',
            13 => 'Not Content Indexed',
            14 => 'Encrypted',
        }}],
    },
    FileDeviceID => {
        Groups => { 1 => 'System' },
        %systemTagsNotes,
        PrintConv => '(($val >> 24) & 0xff) . "." . ($val & 0xffffff)', # (major.minor)
    },
    FileDeviceNumber => { Groups => { 1 => 'System' }, %systemTagsNotes },
    FileInodeNumber  => { Groups => { 1 => 'System' }, %systemTagsNotes },
    FileHardLinks    => { Groups => { 1 => 'System' }, %systemTagsNotes },
    FileUserID => {
        Groups => { 1 => 'System' },
        Notes => q{
            extracted only if specifically requested or the SystemTags or RequestAll API
            option is set.  Returns user ID number with the -n option, or name
            otherwise.  May be written with either user name or number
        },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1, # all writable pseudo-tags must be protected!
        PrintConv => 'eval { getpwuid($val) } || $val',
        PrintConvInv => 'eval { getpwnam($val) } || ($val=~/[^0-9]/ ? undef : $val)',
    },
    FileGroupID => {
        Groups => { 1 => 'System' },
        Notes => q{
            extracted only if specifically requested or the SystemTags or RequestAll API
            option is set.  Returns group ID number with the -n option, or name
            otherwise.  May be written with either group name or number
        },
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1, # all writable pseudo-tags must be protected!
        PrintConv => 'eval { getgrgid($val) } || $val',
        PrintConvInv => 'eval { getgrnam($val) } || ($val=~/[^0-9]/ ? undef : $val)',
    },
    FileBlockSize    => { Groups => { 1 => 'System' }, %systemTagsNotes },
    FileBlockCount   => { Groups => { 1 => 'System' }, %systemTagsNotes },
    HardLink => {
        Writable => 1,
        DelCheck => q{"Can't delete"},
        WriteOnly => 1,
        WritePseudo => 1,
        Protected => 1,
        Notes => q{
            this write-only tag is used to create a hard link to the file.  If the file
            is edited, copied, renamed or moved in the same operation as writing
            HardLink, then the link is made to the updated file.  Note that subsequent
            editing of either the linked file or the original by the exiftool
            application will break the link unless the -overwrite_original_in_place
            option is used
        },
        ValueConvInv => '$val=~tr/\\\\/\//; $val',
    },
    MIMEType    => { Notes => 'the MIME type of the source file' },
    ImageWidth  => { Notes => 'the width of the image in number of pixels' },
    ImageHeight => { Notes => 'the height of the image in number of pixels' },
    XResolution => { Notes => 'the horizontal pixel resolution' },
    YResolution => { Notes => 'the vertical pixel resolution' },
    MaxVal      => { Notes => 'maximum pixel value in PPM or PGM image' },
    EXIF => {
        Notes => q{
            the full EXIF data block from JPEG, PNG, JP2, MIE and MIFF images. This tag
            is generated only if specifically requested
        },
        Groups => { 0 => 'EXIF', 1 => 'EXIF' },
        Flags => ['Writable' ,'Protected', 'Binary'],
        WriteCheck => q{
            return undef if $val =~ /^(II\x2a\0|MM\0\x2a)/;
            return 'Invalid EXIF data';
        },
    },
    IPTC => {
        Notes => q{
            the full IPTC data block.  This tag is generated only if specifically
            requested
        },
        Groups => { 0 => 'IPTC', 1 => 'IPTC' },
        Flags => ['Writable', 'Protected', 'Binary'],
        Priority => 0,  # so main IPTC (which hopefully comes first) takes priority
        WriteCheck => q{
            return undef if $val =~ /^(\x1c|\0+$)/;
            return 'Invalid IPTC data';
        },
    },
    XMP => {
        Notes => q{
            the XMP data block, but note that extended XMP in JPEG images may be split
            into multiple blocks.  This tag is generated only if specifically requested
        },
        Groups => { 0 => 'XMP', 1 => 'XMP' },
        Flags => ['Writable', 'Protected', 'Binary'],
        Priority => 0,  # so main xmp (which usually comes first) takes priority
        WriteCheck => q{
            require Image::ExifTool::XMP;
            return Image::ExifTool::XMP::CheckXMP($self, $tagInfo, \$val);
        },
    },
    ICC_Profile => {
        Notes => q{
            the full ICC_Profile data block.  This tag is generated only if specifically
            requested
        },
        Groups => { 0 => 'ICC_Profile', 1 => 'ICC_Profile' },
        Flags => ['Writable' ,'Protected', 'Binary'],
        WriteCheck => q{
            require Image::ExifTool::ICC_Profile;
            return Image::ExifTool::ICC_Profile::ValidateICC(\$val);
        },
    },
    CanonVRD => {
        Notes => q{
            the full Canon DPP VRD trailer block.  This tag is generated only if
            specifically requested
        },
        Groups => { 0 => 'CanonVRD', 1 => 'CanonVRD' },
        Flags => ['Writable' ,'Protected', 'Binary'],
        Permanent => 0, # (this is 1 by default for MakerNotes tags)
        WriteCheck => q{
            return undef if $val =~ /^CANON OPTIONAL DATA\0/;
            return 'Invalid CanonVRD data';
        },
    },
    CanonDR4 => {
        Notes => q{
            the full Canon DPP version 4 DR4 block.  This tag is generated only if
            specifically requested
        },
        Groups => { 0 => 'CanonVRD', 1 => 'CanonVRD' },
        Flags => ['Writable' ,'Protected', 'Binary'],
        Permanent => 0, # (this is 1 by default for MakerNotes tags)
        WriteCheck => q{
            return undef if $val =~ /^IIII\x04\0\x04\0/;
            return 'Invalid CanonDR4 data';
        },
    },
    Adobe => {
        Notes => q{
            the JPEG APP14 Adobe segment.  Extracted only if specified. See the
            L<JPEG Adobe Tags|JPEG.html#Adobe> for more information
        },
        Groups => { 0 => 'APP14', 1 => 'Adobe' },
        WriteGroup => 'Adobe',
        Flags => ['Writable' ,'Protected', 'Binary'],
    },
    CurrentIPTCDigest => {
        Notes => q{
            MD5 digest of existing IPTC data.  All zeros if IPTC exists but Digest::MD5
            is not installed.  Only calculated for IPTC in the standard location as
            specified by the L<MWG|http://www.metadataworkinggroup.org/>.  ExifTool
            automates the handling of this tag in the MWG module -- see the
            L<MWG Composite Tags|MWG.html> for details
        },
        ValueConv => 'unpack("H*", $val)',
    },
    PreviewImage => {
        Notes => 'JPEG-format embedded preview image',
        Groups => { 2 => 'Preview' },
        Writable => 1,
        WriteCheck => '$self->CheckImage(\$val)',
        WriteGroup => 'All',
        # can't delete, so set to empty string and return no error
        DelCheck => '$val = ""; return undef',
        # accept either scalar or scalar reference
        RawConv => '$self->ValidateImage(ref $val ? $val : \$val, $tag)',
    },
    ThumbnailImage => {
        Groups => { 2 => 'Preview' },
        Notes => 'JPEG-format embedded thumbnail image',
        RawConv => '$self->ValidateImage(ref $val ? $val : \$val, $tag)',
    },
    OtherImage => {
        Groups => { 2 => 'Preview' },
        Notes => 'other JPEG-format embedded image',
        RawConv => '$self->ValidateImage(ref $val ? $val : \$val, $tag)',
    },
    PreviewPNG => {
        Groups => { 2 => 'Preview' },
        Notes => 'PNG-format embedded preview image',
        Binary => 1,
    },
    PreviewWMF => {
        Groups => { 2 => 'Preview' },
        Notes => 'WMF-format embedded preview image',
        Binary => 1,
    },
    PreviewTIFF => {
        Groups => { 2 => 'Preview' },
        Notes => 'TIFF-format embedded preview image',
        Binary => 1,
    },
    PreviewPDF => {
        Groups => { 2 => 'Preview' },
        Notes => 'PDF-format embedded preview image',
        Binary => 1,
    },
    ExifByteOrder => {
        Writable => 1,
        DelCheck => q{"Can't delete"},
        Notes => q{
            represents the byte order of EXIF information.  May be written to set the
            byte order only for newly created EXIF segments
        },
        PrintConv => {
            II => 'Little-endian (Intel, II)',
            MM => 'Big-endian (Motorola, MM)',
        },
    },
    ExifUnicodeByteOrder => {
        Writable => 1,
        WriteOnly => 1,
        DelCheck => q{"Can't delete"},
        Notes => q{
            specifies the byte order to use when writing EXIF Unicode text.  The EXIF
            specification is particularly vague about this byte ordering, and different
            applications use different conventions.  By default ExifTool writes Unicode
            text in EXIF byte order, but this write-only tag may be used to force a
            specific order.  Applies to the EXIF UserComment tag when writing special
            characters
        },
        PrintConv => {
            II => 'Little-endian (Intel, II)',
            MM => 'Big-endian (Motorola, MM)',
        },
    },
    ExifToolVersion => {
        Description => 'ExifTool Version Number',
        Groups => \%allGroupsExifTool,
        Notes => 'the version of ExifTool currently running',
    },
    ProcessingTime => {
        Groups => { 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'Other' },
        Notes => q{
            the clock time in seconds taken by ExifTool to extract information from this
            file.  Not generated unless specifically requested or the RequestAll API
            option is set.  Requires Time::HiRes
        },
        PrintConv => 'sprintf("%.3g s", $val)',
    },
    RAFVersion => { Notes => 'RAF file version number' },
    JPEGDigest => {
        Notes => q{
            an MD5 digest of the JPEG quantization tables is combined with the component
            sub-sampling values to generate the value of this tag.  The result is
            compared to known values in an attempt to deduce the originating software
            based only on the JPEG image data.  For performance reasons, this tag is
            generated only if specifically requested or the RequestAll API option is set
            to 3 or higher
        },
    },
    JPEGQualityEstimate => {
        Notes => q{
            an estimate of the IJG JPEG quality setting for the image, calculated from
            the quantization tables.  For performance reasons, this tag is generated
            only if specifically requested or the RequestAll API option is set to 3 or
            higher
        },
    },
    # Validate (added from Validate.pm)
    Now => {
        Groups => { 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'Time' },
        Notes => q{
            the current date/time.  Useful when setting the tag values, eg.
            C<"-modifydate<now">.  Not generated unless specifically requested or the
            RequestAll API option is set
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    NewGUID => {
        Groups => { 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'Other' },
        Notes => q{
            generates a new, random GUID with format
            YYYYmmdd-HHMM-SSNN-PPPP-RRRRRRRRRRRR, where Y=year, m=month, d=day, H=hour,
            M=minute, S=second, N=file sequence number in hex, P=process ID in hex, and
            R=random hex number; without dashes with the -n option.  Not generated
            unless specifically requested or the RequestAll API option is set
        },
        PrintConv => '$val =~ s/(.{8})(.{4})(.{4})(.{4})/$1-$2-$3-$4-/; $val',
    },
    ID3Size     => { Notes => 'size of the ID3 data block' },
    Geotag => {
        Writable => 1,
        WriteOnly => 1,
        WriteNothing => 1,
        AllowGroup => '(exif|gps|xmp|xmp-exif)',
        Notes => q{
            this write-only tag is used to define the GPS track log data or track log
            file name.  Currently supported track log formats are GPX, NMEA RMC/GGA/GLL,
            KML, IGC, Garmin XML and TCX, Magellan PMGNTRK, Honeywell PTNTHPR, Winplus
            Beacon text, and Bramor gEO log files.  May be set to the special value of
            "DATETIMEONLY" (all caps) to set GPS date/time tags if no input track points
            are available.  See L<geotag.html|../geotag.html> for details
        },
        DelCheck => q{
            require Image::ExifTool::Geotag;
            # delete associated tags
            Image::ExifTool::Geotag::SetGeoValues($self, undef, $wantGroup);
        },
        ValueConvInv => q{
            require Image::ExifTool::Geotag;
            # always warn because this tag is never set (warning is "\n" on success)
            my $result = Image::ExifTool::Geotag::LoadTrackLog($self, $val);
            return '' if not defined $result;   # deleting geo tags
            return $result if ref $result;      # geotag data hash reference
            warn "$result\n";                   # error string
        },
    },
    Geotime => {
        Writable => 1,
        WriteOnly => 1,
        AllowGroup => '(exif|gps|xmp|xmp-exif)',
        Notes => q{
            this write-only tag is used to define a date/time for interpolating a
            position in the GPS track specified by the Geotag tag.  Writing this tag
            causes GPS information to be written into the EXIF or XMP of the target
            files.  The local system timezone is assumed if the date/time value does not
            contain a timezone.  May be deleted to delete associated GPS tags.  A group
            name of 'EXIF' or 'XMP' may be specified to write or delete only EXIF or XMP
            GPS tags
        },
        DelCheck => q{
            require Image::ExifTool::Geotag;
            # delete associated tags
            Image::ExifTool::Geotag::SetGeoValues($self, undef, $wantGroup);
        },
        ValueConvInv => q{
            require Image::ExifTool::Geotag;
            warn Image::ExifTool::Geotag::SetGeoValues($self, $val, $wantGroup) . "\n";
            return undef;
        },
    },
    Geosync => {
        Writable => 1,
        WriteOnly => 1,
        WriteNothing => 1,
        AllowGroup => '(exif|gps|xmp|xmp-exif)',
        Shift => 'Time', # enables "+=" syntax as well as "=+"
        Notes => q{
            this write-only tag specifies a time difference to add to Geotime for
            synchronization with the GPS clock.  For example, set this to "-12" if the
            camera clock is 12 seconds faster than GPS time.  Input format is
            "[+-][[[DD ]HH:]MM:]SS[.ss]".  Additional features allow calculation of time
            differences and time drifts, and extraction of synchronization times from
            image files.  See the L<geotagging documentation|../geotag.html> for details
        },
        ValueConvInv => q{
            require Image::ExifTool::Geotag;
            return Image::ExifTool::Geotag::ConvertGeosync($self, $val);
        },
    },
    ForceWrite => {
        Groups => { 0 => '*', 1 => '*', 2 => '*' },
        Writable => 1,
        WriteOnly => 1,
        Notes => q{
            write-only tag used to force EXIF, IPTC and/or XMP in a file to be
            rewritten.  May be set to "EXIF", "IPTC" or "XMP" to force the corresponding
            metadata type to be rewritten, "FixBase" to cause EXIF to be rewritten only if
            the MakerNotes offset base was fixed, or "All" to rewrite all of these metadata
            types.  Values are case insensitive, and multiple values may be separated with
            commas, eg. C<-ForceWrite=exif,xmp>
        },
    },
);

# YCbCrSubSampling values (used by JPEG SOF, EXIF and XMP)
%Image::ExifTool::JPEG::yCbCrSubSampling = (
    '1 1' => 'YCbCr4:4:4 (1 1)', #PH
    '2 1' => 'YCbCr4:2:2 (2 1)', #14 in Exif.pm
    '2 2' => 'YCbCr4:2:0 (2 2)', #14 in Exif.pm
    '4 1' => 'YCbCr4:1:1 (4 1)', #14 in Exif.pm
    '4 2' => 'YCbCr4:1:0 (4 2)', #PH
    '1 2' => 'YCbCr4:4:0 (1 2)', #PH
    '1 4' => 'YCbCr4:4:1 (1 4)', #JD
    '2 4' => 'YCbCr4:2:1 (2 4)', #JD
);

# define common JPEG segments here to avoid overhead of loading JPEG module

# JPEG SOF (start of frame) tags
# (ref http://www.w3.org/Graphics/JPEG/itu-t81.pdf)
%Image::ExifTool::JPEG::SOF = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'This information is extracted from the JPEG Start Of Frame segment.',
    VARS => { NO_ID => 1 }, # tag ID's aren't meaningful for these tags
    EncodingProcess => {
        PrintHex => 1,
        PrintConv => {
            0x0 => 'Baseline DCT, Huffman coding',
            0x1 => 'Extended sequential DCT, Huffman coding',
            0x2 => 'Progressive DCT, Huffman coding',
            0x3 => 'Lossless, Huffman coding',
            0x5 => 'Sequential DCT, differential Huffman coding',
            0x6 => 'Progressive DCT, differential Huffman coding',
            0x7 => 'Lossless, Differential Huffman coding',
            0x9 => 'Extended sequential DCT, arithmetic coding',
            0xa => 'Progressive DCT, arithmetic coding',
            0xb => 'Lossless, arithmetic coding',
            0xd => 'Sequential DCT, differential arithmetic coding',
            0xe => 'Progressive DCT, differential arithmetic coding',
            0xf => 'Lossless, differential arithmetic coding',
        }
    },
    BitsPerSample    => { },
    ImageHeight      => { },
    ImageWidth       => { },
    ColorComponents  => { },
    YCbCrSubSampling => {
        Notes => 'calculated from components table',
        PrintConv => \%Image::ExifTool::JPEG::yCbCrSubSampling,
    },
);

# JPEG JFIF APP0 definitions
%Image::ExifTool::JFIF::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'JFIF', 1 => 'JFIF', 2 => 'Image' },
    DATAMEMBER => [ 2, 3, 5 ],
    0 => {
        Name => 'JFIFVersion',
        Format => 'int8u[2]',
        PrintConv => 'sprintf("%d.%.2d", split(" ",$val))',
        Mandatory => 1,
    },
    2 => {
        Name => 'ResolutionUnit',
        Writable => 1,
        RawConv => '$$self{JFIFResolutionUnit} = $val',
        PrintConv => {
            0 => 'None',
            1 => 'inches',
            2 => 'cm',
        },
        Priority => -1,
        Mandatory => 1,
    },
    3 => {
        Name => 'XResolution',
        Format => 'int16u',
        Writable => 1,
        Priority => -1,
        RawConv => '$$self{JFIFXResolution} = $val',
        Mandatory => 1,
    },
    5 => {
        Name => 'YResolution',
        Format => 'int16u',
        Writable => 1,
        Priority => -1,
        RawConv => '$$self{JFIFYResolution} = $val',
        Mandatory => 1,
    },
    7 => {
        Name => 'ThumbnailWidth',
        RawConv => '$val ? $$self{JFIFThumbnailWidth} = $val : undef',
    },
    8 => {
        Name => 'ThumbnailHeight',
        RawConv => '$val ? $$self{JFIFThumbnailHeight} = $val : undef',
    },
    9 => {
        Name => 'ThumbnailTIFF',
        Groups => { 2 => 'Preview' },
        Format => 'undef[3*($val{7}||0)*($val{8}||0)]',
        Notes => 'raw RGB thumbnail data, extracted as a TIFF image',
        RawConv => 'length($val) ? $val : undef',
        ValueConv => sub {
            my ($val, $et) = @_;
            my $len = length $val;
            return \ "Binary data $len bytes" unless $et->Options('Binary');
            my $img = MakeTiffHeader($$et{JFIFThumbnailWidth},$$et{JFIFThumbnailHeight},3,8) . $val;
            return \$img;
        },
    },
);
%Image::ExifTool::JFIF::Extension = (
    GROUPS => { 0 => 'JFIF', 1 => 'JFXX', 2 => 'Image' },
    NOTES => 'Thumbnail images extracted from the JFXX segment.',
    0x10 => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Notes => 'JPEG-format thumbnail image',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
    0x11 => { # (untested)
        Name => 'ThumbnailTIFF',
        Groups => { 2 => 'Preview' },
        Notes => 'raw palette-color thumbnail data, extracted as a TIFF image',
        RawConv => '(length $val > 770 and $val !~ /^\0\0/) ? $val : undef',
        ValueConv => sub {
            my ($val, $et) = @_;
            my $len = length $val;
            return \ "Binary data $len bytes" unless $et->Options('Binary');
            my ($w, $h) = unpack('CC', $val);
            my $img = MakeTiffHeader($w,$h,1,8,undef,substr($val,2,768)) . substr($val,770);
            return \$img;
        },
    },
    0x13 => {
        Name => 'ThumbnailTIFF',
        Groups => { 2 => 'Preview' },
        Notes => 'raw RGB thumbnail data, extracted as a TIFF image',
        RawConv => '(length $val > 2 and $val !~ /^\0\0/) ? $val : undef',
        ValueConv => sub {
            my ($val, $et) = @_;
            my $len = length $val;
            return \ "Binary data $len bytes" unless $et->Options('Binary');
            my ($w, $h) = unpack('CC', $val);
            my $img = MakeTiffHeader($w,$h,3,8) . substr($val,2);
            return \$img;
        },
    },
);

# Composite tags (accumulation of all Composite tag tables)
%Image::ExifTool::Composite = (
    GROUPS => { 0 => 'Composite', 1 => 'Composite' },
    TABLE_NAME => 'Image::ExifTool::Composite',
    SHORT_NAME => 'Composite',
    VARS => { NO_ID => 1 }, # want empty tagID's for Composite tags
    WRITE_PROC => \&DummyWriteProc,
);

# static private ExifTool variables

%allTables = ( );   # list of all tables loaded (except Composite tags)
@tableOrder = ( );  # order the tables were loaded

#------------------------------------------------------------------------------
# Warning handler routines (warning string stored in $evalWarning)
#
# Set warning message
# Inputs: 0) warning string (undef to reset warning)
sub SetWarning($) { $evalWarning = $_[0]; }

# Get warning message
sub GetWarning()  { return $evalWarning; }

# Clean unnecessary information (line number, LF) from warning
# Inputs: 0) warning string or undef to use $evalWarning
# Returns: cleaned warning
sub CleanWarning(;$)
{
    my $str = shift;
    unless (defined $str) {
        return undef unless defined $evalWarning;
        $str = $evalWarning;
    }
    $str = $1 if $str =~ /(.*) at /s;
    $str =~ s/\s+$//s;
    return $str;
}

#==============================================================================
# New - create new ExifTool object
# Inputs: 0) reference to exiftool object or ExifTool class name
# Returns: blessed ExifTool object ref
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool';
    my $self = bless {}, $class;

    # make sure our main Exif tag table has been loaded
    GetTagTable("Image::ExifTool::Exif::Main");

    $self->ClearOptions();      # create default options hash
    $$self{VALUE} = { };        # must initialize this for warning messages
    $$self{PATH} = [ ];         # (this too)
    $$self{DEL_GROUP} = { };    # lookup for groups to delete when writing
    $$self{SAVE_COUNT} = 0;     # count calls to SaveNewValues()
    $$self{FILE_SEQUENCE} = 0;  # sequence number for files when reading

    # initialize our new groups for writing
    $self->SetNewGroups(@defaultWriteGroups);

    return $self;
}

#------------------------------------------------------------------------------
# ImageInfo - return specified information from image file
# Inputs: 0) [optional] ExifTool object reference
#         1) filename, file reference, or scalar data reference
#         2-N) list of tag names to find (or tag list reference or options reference)
# Returns: reference to hash of tag/value pairs (with "Error" entry on error)
# Notes:
#   - if no tags names are specified, the values of all tags are returned
#   - tags may be specified with leading '-' to exclude, or trailing '#' for ValueConv
#   - can pass a reference to list of tags to find, in which case the list will
#     be updated with the tags found in the proper case and in the specified order.
#   - can pass reference to hash specifying options
#   - returned tag values may be scalar references indicating binary data
#   - see ClearOptions() below for a list of options and their default values
# Examples:
#   use Image::ExifTool 'ImageInfo';
#   my $info = ImageInfo($file, 'DateTimeOriginal', 'ImageSize');
#    - or -
#   my $et = new Image::ExifTool;
#   my $info = $et->ImageInfo($file, \@tagList, {Sort=>'Group0'} );
sub ImageInfo($;@)
{
    local $_;
    # get our ExifTool object ($self) or create one if necessary
    my $self;
    if (ref $_[0] and UNIVERSAL::isa($_[0],'Image::ExifTool')) {
        $self = shift;
    } else {
        $self = new Image::ExifTool;
    }
    my %saveOptions = %{$$self{OPTIONS}};   # save original options

    # initialize file information
    $$self{FILENAME} = $$self{RAF} = undef;

    $self->ParseArguments(@_);              # parse our function arguments
    $self->ExtractInfo(undef);              # extract meta information from image
    my $info = $self->GetInfo(undef);       # get requested information

    $$self{OPTIONS} = \%saveOptions;        # restore original options

    return $info;   # return requested information
}

#------------------------------------------------------------------------------
# Get/set ExifTool options
# Inputs: 0) ExifTool object reference,
#         1) Parameter name (case insensitive), 2) Value to set the option
#         3-N) More parameter/value pairs
# Returns: original value of last option specified
sub Options($$;@)
{
    local $_;
    my $self = shift;
    my $options = $$self{OPTIONS};
    my $oldVal;

    while (@_) {
        my $param = shift;
        # fix parameter case if necessary
        unless (exists $$options{$param}) {
            my ($fixed) = grep /^$param$/i, keys %$options;
            if ($fixed) {
                $param = $fixed;
            } else {
                $param =~ s/^Group(\d*)$/Group$1/i;
            }
        }
        $oldVal = $$options{$param};
        last unless @_;
        my $newVal = shift;
        if ($param eq 'Lang') {
            # allow this to be set to undef to select the default language
            $newVal = $defaultLang unless defined $newVal;
            if ($newVal eq $defaultLang) {
                $$options{$param} = $newVal;
                delete $$self{CUR_LANG};
            # make sure the language is available
            } elsif (eval "require Image::ExifTool::Lang::$newVal") {
                my $xlat = "Image::ExifTool::Lang::${newVal}::Translate";
                no strict 'refs';
                if (%$xlat) {
                    $$self{CUR_LANG} = \%$xlat;
                    $$options{$param} = $newVal;
                }
            } # else don't change Lang
        } elsif ($param eq 'Exclude' and defined $newVal) {
            # clone Exclude list and expand shortcuts
            my @exclude;
            if (ref $newVal eq 'ARRAY') {
                @exclude = @$newVal;
            } else {
                @exclude = ($newVal);
            }
            ExpandShortcuts(\@exclude, 1);  # (also remove '#' suffix)
            $$options{$param} = \@exclude;
        } elsif ($param =~ /^Charset/ or $param eq 'IPTCCharset') {
            # only allow valid character sets to be set
            if ($newVal) {
                my $charset = $charsetName{lc $newVal};
                if ($charset) {
                    $$options{$param} = $charset;
                    # maintain backward-compatibility with old IPTCCharset option
                    $$options{CharsetIPTC} = $charset if $param eq 'IPTCCharset';
                } else {
                    warn "Invalid Charset $newVal\n";
                }
            } elsif ($param eq 'CharsetEXIF' or $param eq 'CharsetFileName' or $param eq 'CharsetRIFF') {
                $$options{$param} = $newVal;    # only these may be set to a false value
            } elsif ($param eq 'CharsetQuickTime') {
                $$options{$param} = 'MacRoman'; # QuickTime defaults to MacRoman
            } else {
                $$options{$param} = 'Latin';    # all others default to Latin
            }
        } elsif ($param eq 'UserParam') {
            # clear options if $newVal is undef
            defined $newVal or $$options{$param} = {}, next;
            # allow initialization of entire UserParam hash
            if (ref $newVal eq 'HASH') {
                my %newParams;
                $newParams{lc $_} = $$newVal{$_} foreach sort keys %$newVal;
                $$options{$param} = \%newParams;
                next;
            }
            my $force;
            # set/reset single UserParam parameter
            if ($newVal =~ /(.*?)=(.*)/s) {
                $param = lc $1;
                $newVal = $2;
                $force = 1 if $param =~ s/\^$//;
            } else {
                $param = lc $newVal;
                undef $newVal;
            }
            $oldVal = $$options{UserParam}{$param};
            if (defined $newVal) {
                if (length $newVal or $force) {
                    $$options{UserParam}{$param} = $newVal;
                } else {
                    delete $$options{UserParam}{$param};
                }
            }
        } elsif ($param eq 'RequestTags') {
            if (defined $newVal) {
                # parse list from delimited string if necessary
                my @reqList = (ref $newVal eq 'ARRAY') ? @$newVal : ($newVal =~ /[-\w?*:]+/g);
                ExpandShortcuts(\@reqList);
                # add to existing list
                $$options{$param} or $$options{$param} = [ ];
                foreach (@reqList) {
                    /^(.*:)?([-\w?*]*)#?$/ or next;
                    push @{$$options{$param}}, lc($2) if $2;
                    next unless $1;
                    push @{$$options{$param}}, lc($_).':' foreach split /:/, $1;
                }
            } else {
                $$options{$param} = undef;  # clear the list
            }
        } elsif ($param eq 'ListJoin') {
            $$options{$param} = $newVal;
            # ListJoin just sets the List and ListSep options for backward compatibility
            if (defined $newVal) {
                $$options{List} = 0;
                $$options{ListSep} = $newVal;
            } else {
                $$options{List} = 1;
                # (ListSep must be defined)
            }
        } else {
            if ($param eq 'Escape') {
                # set ESCAPE_PROC
                if (defined $newVal and $newVal eq 'XML') {
                    require Image::ExifTool::XMP;
                    $$self{ESCAPE_PROC} = \&Image::ExifTool::XMP::EscapeXML;
                } elsif (defined $newVal and $newVal eq 'HTML') {
                    require Image::ExifTool::HTML;
                    $$self{ESCAPE_PROC} = \&Image::ExifTool::HTML::EscapeHTML;
                } else {
                    delete $$self{ESCAPE_PROC};
                }
                # must forget saved values since they depend on Escape method
                $$self{BOTH} = { };
            } elsif ($param eq 'GlobalTimeShift') {
                delete $$self{GLOBAL_TIME_OFFSET};  # reset our calculated offset
            } elsif ($param eq 'TimeZone' and defined $newVal and length $newVal) {
                $ENV{TZ} = $newVal;
                eval { require POSIX; POSIX::tzset() };
            } elsif ($param eq 'Validate') {
                # load Validate module if Validate option enabled
                $newVal and require Image::ExifTool::Validate;
            }
            $$options{$param} = $newVal;
        }
    }
    return $oldVal;
}

#------------------------------------------------------------------------------
# ClearOptions - set options to default values
# Inputs: 0) ExifTool object reference
sub ClearOptions($)
{
    local $_;
    my $self = shift;

    # create options hash with default values
    # +-----------------------------------------------------+
    # ! DON'T FORGET!!  When adding any new option, must    !
    # ! decide how it is handled in SetNewValuesFromFile()  !
    # +-----------------------------------------------------+
    # (Note: All options must exist in this lookup, even if undefined,
    # to facilitate case-insensitive options. 'Group#' is handled specially)
    $$self{OPTIONS} = {
        Binary      => undef,   # flag to extract binary values even if tag not specified
        ByteOrder   => undef,   # default byte order when creating EXIF information
        Charset     => 'UTF8',  # character set for converting Unicode characters
        CharsetEXIF => undef,   # internal EXIF "ASCII" string encoding
        CharsetFileName => undef,   # external encoding for file names
        CharsetID3  => 'Latin', # internal ID3v1 character set
        CharsetIPTC => 'Latin', # fallback IPTC character set if no CodedCharacterSet
        CharsetPhotoshop => 'Latin', # internal encoding for Photoshop resource names
        CharsetQuickTime => 'MacRoman', # internal QuickTime string encoding
        CharsetRIFF => 0,       # internal RIFF string encoding (0=default to Latin)
        Compact     => undef,   # compact XMP and IPTC data
        Composite   => 1,       # flag to calculate Composite tags
        Compress    => undef,   # flag to write new values as compressed if possible
        CoordFormat => undef,   # GPS lat/long coordinate format
        DateFormat  => undef,   # format for date/time
        Duplicates  => 1,       # flag to save duplicate tag values
        Escape      => undef,   # escape special characters
        Exclude     => undef,   # tags to exclude
        ExtendedXMP => 1,       # strategy for reading extended XMP
        ExtractEmbedded =>undef,# flag to extract information from embedded documents
        FastScan    => undef,   # flag to avoid scanning for trailer
        Filter      => undef,   # output filter for all tag values
        FixBase     => undef,   # fix maker notes base offsets
        GeoMaxIntSecs => 1800,  # geotag maximum interpolation time (secs)
        GeoMaxExtSecs => 1800,  # geotag maximum extrapolation time (secs)
        GeoMaxHDOP  => undef,   # geotag maximum HDOP
        GeoMaxPDOP  => undef,   # geotag maximum PDOP
        GeoMinSats  => undef,   # geotag minimum satellites
        GlobalTimeShift => undef,   # apply time shift to all extracted date/time values
    #   Group#      => undef,   # return tags for specified groups in family #
        HtmlDump    => 0,       # HTML dump (0-3, higher # = bigger limit)
        HtmlDumpBase => undef,  # base address for HTML dump
        IgnoreMinorErrors => undef, # ignore minor errors when reading/writing
        Lang        => $defaultLang,# localized language for descriptions etc
        LargeFileSupport => undef,  # flag indicating support of 64-bit file offsets
        List        => undef,   # extract lists of PrintConv values into arrays [no longer documented]
        ListItem    => undef,   # used to return a specific item from lists
        ListJoin    => ', ',    # join lists together with this separator
        ListSep     => ', ',    # list item separator [no longer documented]
        ListSplit   => undef,   # regex for splitting list-type tag values when writing
        MakerNotes  => undef,   # extract maker notes as a block
        MDItemTags  => undef,   # extract MacOS metadata item tags
        MissingTagValue =>undef,# value for missing tags when expanded in expressions
        NoPDFList   => undef,   # flag to avoid splitting PDF List-type tag values
        Password    => undef,   # password for password-protected PDF documents
        PNGEarlyXMP => undef,   # write XMP in PNG images before IDAT chunk
        PrintConv   => 1,       # flag to enable print conversion
        QuickTimeUTC=> undef,   # assume that QuickTime date/time tags are stored as UTC
        RequestAll  => undef,   # extract all tags that must be specifically requested
        RequestTags => undef,   # extra tags to request (on top of those in the tag list)
        SavePath    => undef,   # (undocumented) save family 5 location path
        ScanForXMP  => undef,   # flag to scan for XMP information in all files
        Sort        => 'Input', # order to sort found tags (Input, File, Tag, Descr, Group#)
        Sort2       => 'File',  # secondary sort order for tags in a group (File, Tag, Descr)
        StrictDate  => undef,   # flag to return undef for invalid date conversions
        Struct      => undef,   # return structures as hash references
        SystemTags  => undef,   # extract additional File System tags
        TextOut     => \*STDOUT,# file for Verbose/HtmlDump output
        TimeZone    => undef,   # local time zone
        Unknown     => 0,       # flag to get values of unknown tags (0-2)
        UserParam   => { },     # user parameters for InsertTagValues()
        Validate    => undef,   # perform additional validation
        Verbose     => 0,       # print verbose messages (0-5, higher # = more verbose)
        WriteMode   => 'wcg',   # enable all write modes by default
        XAttrTags   => undef,   # extract MacOS extended attribute tags
        XMPAutoConv => 1,       # automatic conversion of unknown XMP tag values
    };
    # keep necessary member variables in sync with options
    delete $$self{CUR_LANG};
    delete $$self{ESCAPE_PROC};

    # load user-defined default options
    if (%Image::ExifTool::UserDefined::Options) {
        foreach (keys %Image::ExifTool::UserDefined::Options) {
            $self->Options($_, $Image::ExifTool::UserDefined::Options{$_});
        }
    }
}

#------------------------------------------------------------------------------
# Extract meta information from image
# Inputs: 0) ExifTool object reference
#         1-N) Same as ImageInfo()
# Returns: 1 if this was a valid image, 0 otherwise
# Notes: pass an undefined value to avoid parsing arguments
# Internal 'ReEntry' option allows this routine to be called recursively
sub ExtractInfo($;@)
{
    local $_;
    my $self = shift;
    my $options = $$self{OPTIONS};      # pointer to current options
    my $fast = $$options{FastScan};
    my $req = $$self{REQ_TAG_LOOKUP};
    my $reqAll = $$options{RequestAll} || 0;
    my (%saveOptions, $reEntry, $rsize, $type, @startTime);

    # check for internal ReEntry option to allow recursive calls to ExtractInfo
    if (ref $_[1] eq 'HASH' and $_[1]{ReEntry} and
       (ref $_[0] eq 'SCALAR' or ref $_[0] eq 'GLOB'))
    {
        # save necessary members for restoring later
        $reEntry = {
            RAF       => $$self{RAF},
            PROCESSED => $$self{PROCESSED},
            EXIF_DATA => $$self{EXIF_DATA},
            EXIF_POS  => $$self{EXIF_POS},
            FILE_TYPE => $$self{FILE_TYPE},
        };
        $$self{RAF} = new File::RandomAccess($_[0]);
        $$self{PROCESSED} = { };
        delete $$self{EXIF_DATA};
        delete $$self{EXIF_POS};
    } else {
        if (defined $_[0] or $$options{HtmlDump} or $$req{validate}) {
            %saveOptions = %$options;       # save original options

            # require duplicates for html dump
            $self->Options(Duplicates => 1) if $$options{HtmlDump};
            # enable Validate option if Validate tag is requested
            $self->Options(Validate => 1) if $$req{validate};

            if (defined $_[0]) {
                # only initialize filename if called with arguments
                $$self{FILENAME} = undef;   # name of file (or '' if we didn't open it)
                $$self{RAF} = undef;        # RandomAccess object reference

                $self->ParseArguments(@_);  # initialize from our arguments
            }
        }
        # initialize ExifTool object members
        $self->Init();

        delete $$self{MAKER_NOTE_FIXUP};    # fixup information for extracted maker notes
        delete $$self{MAKER_NOTE_BYTE_ORDER};

        # return our version number
        $self->FoundTag('ExifToolVersion', "$VERSION$RELEASE");
        $self->FoundTag('Now', $self->TimeNow()) if $$req{now} or $reqAll;
        $self->FoundTag('NewGUID', NewGUID()) if $$req{newguid} or $reqAll;
        # generate sequence number if necessary
        $self->FoundTag('FileSequence', $$self{FILE_SEQUENCE}) if $$req{filesequence} or $reqAll;

        if ($$req{processingtime} or $reqAll) {
            eval { require Time::HiRes; @startTime = Time::HiRes::gettimeofday() };
            if (not @startTime and $$req{processingtime}) {
                $self->WarnOnce('Install Time::HiRes to generate ProcessingTime');
            }
        }

        ++$$self{FILE_SEQUENCE};        # count files read
    }

    my $filename = $$self{FILENAME};    # image file name ('' if already open)
    my $raf = $$self{RAF};              # RandomAccess object

    local *EXIFTOOL_FILE;   # avoid clashes with global namespace

    my $realname = $filename;
    unless ($raf) {
        # save file name
        if (defined $filename and $filename ne '') {
            unless ($filename eq '-') {
                # extract file name from pipe if necessary
                $realname =~ /\|$/ and $realname =~ s/^.*?"(.*?)".*/$1/s;
                my ($dir, $name);
                if (eval { require File::Basename }) {
                    $dir = File::Basename::dirname($realname);
                    $name = File::Basename::basename($realname);
                } else {
                    ($name = $realname) =~ tr/\\/\//;
                    # remove path
                    $dir = length($1) ? $1 : '/' if $name =~ s/(.*)\///;
                }
                $self->FoundTag('FileName', $name);
                $self->FoundTag('Directory', $dir) if defined $dir and length $dir;
                if ($$req{filepath} or
                   ($reqAll and not $$self{EXCL_TAG_LOOKUP}{filepath}))
                {
                    local $SIG{'__WARN__'} = \&SetWarning;
                    if (eval { require Cwd }) {
                        my $path = eval { Cwd::abs_path($filename) };
                        $self->FoundTag('FilePath', $path) if defined $path;
                    } elsif ($$req{filepath}) {
                        $self->WarnOnce('The Perl Cwd module must be installed to use FilePath');
                    }
                }
                # get size of resource fork on Mac OS
                $rsize = -s "$filename/..namedfork/rsrc" if $^O eq 'darwin' and not $$self{IN_RESOURCE};
            }
            # open the file
            if ($self->Open(\*EXIFTOOL_FILE, $filename)) {
                # create random access file object
                $raf = new File::RandomAccess(\*EXIFTOOL_FILE);
                # patch to force pipe to be buffered because seek returns success
                # in Windows cmd shell pipe even though it really failed
                $$raf{TESTED} = -1 if $filename eq '-' or $filename =~ /\|$/;
                $$self{RAF} = $raf;
            } else {
                $self->Error('Error opening file');
            }
        } else {
            $self->Error('No file specified');
        }
    }

    if ($raf) {
        my (@stat, $fileSize);
        if ($reEntry) {
            # we already set these tags
        } elsif (not $$raf{FILE_PT}) {
            # get file size from image in memory
            $self->FoundTag('FileSize', length ${$$raf{BUFF_PT}});
        } elsif (-f $$raf{FILE_PT}) {
            # get file tags if this is a plain file
            $fileSize = -s _;
            @stat = stat _;
            my ($aTime, $mTime, $cTime) = $self->GetFileTime($$raf{FILE_PT});
            $self->FoundTag('FileSize', $fileSize) if defined $fileSize;
            $self->FoundTag('ResourceForkSize', $rsize) if $rsize;
            $self->FoundTag('FileModifyDate', $mTime) if defined $mTime;
            $self->FoundTag('FileAccessDate', $aTime) if defined $aTime;
            my $cTag = $^O eq 'MSWin32' ? 'FileCreateDate' : 'FileInodeChangeDate';
            $self->FoundTag($cTag, $cTime) if defined $cTime;
            $self->FoundTag('FilePermissions', $stat[2]) if defined $stat[2];
        } else {
            @stat = stat $$raf{FILE_PT};
        }
        # extract more system info if SystemTags option is set
        if (@stat) {
            my $sys = $$options{SystemTags} || ($reqAll and not defined $$options{SystemTags});
            if ($sys or $$req{fileattributes}) {
                my @attr = ($stat[2] & 0xf000, $stat[2] & 0x0e00);
                # add Windows file attributes if available
                if ($^O eq 'MSWin32' and defined $filename and $filename ne '' and $filename ne '-') {
                    local $SIG{'__WARN__'} = \&SetWarning;
                    if (eval { require Win32API::File }) {
                        my $wattr;
                        my $file = $filename;
                        if ($self->EncodeFileName($file)) {
                            $wattr = eval { Win32API::File::GetFileAttributesW($file) };
                        } else {
                            $wattr = eval { Win32API::File::GetFileAttributes($file) };
                        }
                        push @attr, $wattr if defined $wattr and $wattr != 0xffffffff;
                    }
                }
                $self->FoundTag('FileAttributes', "@attr");
            }
            $self->FoundTag('FileDeviceNumber', $stat[0]) if $sys or $$req{filedevicenumber};
            $self->FoundTag('FileInodeNumber', $stat[1])  if $sys or $$req{fileinodenumber};
            $self->FoundTag('FileHardLinks', $stat[3])    if $sys or $$req{filehardlinks};
            $self->FoundTag('FileUserID', $stat[4])       if $sys or $$req{fileuserid};
            $self->FoundTag('FileGroupID', $stat[5])      if $sys or $$req{filegroupid};
            $self->FoundTag('FileDeviceID', $stat[6])     if $sys or $$req{filedeviceid};
            $self->FoundTag('FileBlockSize', $stat[11])   if $sys or $$req{fileblocksize};
            $self->FoundTag('FileBlockCount', $stat[12])  if $sys or $$req{fileblockcount};
        }
        # extract MDItem tags if requested (only on plain files)
        if ($^O eq 'darwin' and defined $filename and $filename ne '' and defined $fileSize) {
            my $reqMacOS = ($reqAll > 1 or $$req{'macos:'});
            my $crDate = ($reqMacOS || $$req{filecreatedate});
            my $mdItem = ($reqMacOS || $$options{MDItemTags} || grep /^mditem/, keys %$req);
            my $xattr  = ($reqMacOS || $$options{XAttrTags}  || grep /^xattr/,  keys %$req);
            if ($crDate or $mdItem or $xattr) {
                require Image::ExifTool::MacOS;
                Image::ExifTool::MacOS::GetFileCreateDate($self, $filename) if $crDate;
                Image::ExifTool::MacOS::ExtractMDItemTags($self, $filename) if $mdItem;
                Image::ExifTool::MacOS::ExtractXAttrTags($self, $filename) if $xattr;
            }
        }

        # get list of file types to check
        my ($tiffType, %noMagic, $recognizedExt);
        my $ext = $$self{FILE_EXT} = GetFileExtension($realname);
        # set $recognizedExt if this file type is recognized by extension only
        $recognizedExt = $ext if defined $ext and not defined $magicNumber{$ext} and
                                 defined $moduleName{$ext} and not $moduleName{$ext};
        my @fileTypeList = GetFileType($realname);
        if (@fileTypeList) {
            # add remaining types to end of list so we test them all
            my $pat = join '|', @fileTypeList;
            push @fileTypeList, grep(!/^($pat)$/, @fileTypes);
            $tiffType = $$self{FILE_EXT};
            unless ($fast and $fast == 3) {
                $noMagic{MXF} = 1;  # don't do magic number test on MXF or DV files
                $noMagic{DV} = 1;
            }
        } else {
            # scan through all recognized file types
            @fileTypeList = @fileTypes;
            $tiffType = 'TIFF';
        }
        push @fileTypeList, ''; # end of list marker
        # initialize the input file for seeking in binary data
        $raf->BinMode();    # set binary mode before we start reading
        my $pos = $raf->Tell(); # get file position so we can rewind
        my %dirInfo = ( RAF => $raf, Base => $pos );
        # loop through list of file types to test
        my ($buff, $seekErr);
        # read start of file for testing
        my $testLen = 1024;
        $raf->Read($buff, $testLen) or $buff = '';
        $raf->Seek($pos, 0) or $seekErr = 1;
        until ($seekErr) {
            my $unkHeader;
            $type = shift @fileTypeList;
            if ($type) {
                # do quick test for this file type to avoid loading module unnecessarily
                next if $magicNumber{$type} and $buff !~ /^$magicNumber{$type}/s and
                        not $noMagic{$type};
                next if $weakMagic{$type} and defined $recognizedExt;
            } elsif (not defined $type) {
                last;
            } elsif ($recognizedExt) {
                $type = $recognizedExt; # set type from recognized file extension only
            } else {
                # last ditch effort to scan past unknown header for JPEG/TIFF
                next unless $buff =~ /(\xff\xd8\xff|MM\0\x2a|II\x2a\0)/g;
                $type = ($1 eq "\xff\xd8\xff") ? 'JPEG' : 'TIFF';
                my $skip = pos($buff) - length($1);
                $dirInfo{Base} = $pos + $skip;
                $raf->Seek($pos + $skip, 0) or $seekErr = 1, last;
                $self->Warn("Processing $type-like data after unknown $skip-byte header");
                $unkHeader = 1 unless $$self{DOC_NUM};
            }
            # save file type in member variable
            $$self{FILE_TYPE} = $type;
            $dirInfo{Parent} = ($type eq 'TIFF') ? $tiffType : $type;
            # don't process the file when FastScan == 3
            if ($fast and $fast == 3 and not $processType{$type}) {
                unless ($weakMagic{$type} and (not $ext or $ext ne $type)) {
                    $self->SetFileType($dirInfo{Parent});
                }
                last;
            }
            my $module = $moduleName{$type};
            $module = $type unless defined $module;
            my $func = "Process$type";

            # load module if necessary
            if ($module) {
                require "Image/ExifTool/$module.pm";
                $func = "Image::ExifTool::${module}::$func";
            } elsif ($module eq '0') {
                $self->SetFileType();
                $self->Warn('Unsupported file type');
                last;
            }
            push @{$$self{PATH}}, $type;    # save file type in metadata PATH

            # process the file
            no strict 'refs';
            my $result = &$func($self, \%dirInfo);
            use strict 'refs';

            pop @{$$self{PATH}};

            if ($result) {  # all done if successful
                if ($unkHeader) {
                    $self->DeleteTag('FileType');
                    $self->DeleteTag('FileTypeExtension');
                    $self->DeleteTag('MIMEType');
                    $self->VPrint(0,"Reset file type due to unknown header\n");
                }
                last;
            }
            # seek back to try again from the same position in the file
            $raf->Seek($pos, 0) or $seekErr = 1, last;
        }
        if (not defined $type and not $$self{DOC_NUM}) {
            # if we were given a single image with a known type there
            # must be a format error since we couldn't read it, otherwise
            # it is likely we don't support images of this type
            my $fileType = GetFileType($realname) || '';
            my $err;
            if (not length $buff) {
                $err = 'File is empty';
            } else {
                my $ch = substr($buff, 0, 1);
                if (length $buff < 16 or $buff =~ /[^\Q$ch\E]/) {
                    if ($fileType eq 'RAW') {
                        $err = 'Unsupported RAW file type';
                    } elsif ($fileType) {
                        $err = 'File format error';
                    } else {
                        $err = 'Unknown file type';
                    }
                } else {
                    # provide some insight into the content of some corrupted files
                    if ($$self{OPTIONS}{FastScan}) {
                        $err = 'File header is all';
                    } else {
                        my $num = length $buff;
                        for (;;) {
                            $raf->Read($buff, 65536) or undef($num), last;
                            $buff =~ /[^\Q$ch\E]/g and $num += pos($buff) - 1, last;
                            $num += length($buff);
                        }
                        if ($num) {
                            $err = 'First ' . ConvertFileSize($num) . ' of file is';
                        } else {
                            $err = 'Entire file is';
                        }
                    }
                    if ($ch eq "\0") {
                        $err .= ' binary zeros';
                    } elsif ($ch eq ' ') {
                        $err .= ' ASCII spaces';
                    } elsif ($ch =~ /[a-zA-Z0-9]/) {
                        $err .= " ASCII '${ch}' characters";
                    } else {
                        $err .= sprintf(" binary 0x%.2x's", ord $ch);
                    }
                }
            }
            $self->Error($err);
        }
        if ($seekErr) {
            $self->Error('Error seeking in file');
        } elsif ($self->Options('ScanForXMP') and (not defined $type or
            (not $fast and not $$self{FoundXMP})))
        {
            # scan for XMP
            $raf->Seek($pos, 0);
            require Image::ExifTool::XMP;
            Image::ExifTool::XMP::ScanForXMP($self, $raf) and $type = '';
        }
        # extract binary EXIF data block only if requested
        if (defined $$self{EXIF_DATA} and length $$self{EXIF_DATA} > 16 and
            ($$req{exif} or
            # (not extracted normally, so check TAGS_FROM_FILE)
            ($$self{TAGS_FROM_FILE} and not $$self{EXCL_TAG_LOOKUP}{exif})))
        {
            $self->FoundTag('EXIF', $$self{EXIF_DATA});
        }
        unless ($reEntry) {
            $$self{PATH} = [ ];     # reset PATH
            # calculate Composite tags
            $self->BuildCompositeTags() if $$options{Composite};
            # do our HTML dump if requested
            if ($$self{HTML_DUMP}) {
                $raf->Seek(0, 2);   # seek to end of file
                $$self{HTML_DUMP}->FinishTiffDump($self, $raf->Tell());
                my $pos = $$options{HtmlDumpBase};
                $pos = ($$self{FIRST_EXIF_POS} || 0) unless defined $pos;
                my $dataPt = defined $$self{EXIF_DATA} ? \$$self{EXIF_DATA} : undef;
                undef $dataPt if defined $$self{EXIF_POS} and $pos != $$self{EXIF_POS};
                undef $dataPt if $$self{ExtendedEXIF}; # can't use EXIF block if not contiguous
                my $success = $$self{HTML_DUMP}->Print($raf, $dataPt, $pos,
                    $$options{TextOut}, $$options{HtmlDump},
                    $$self{FILENAME} ? "HTML Dump ($$self{FILENAME})" : 'HTML Dump');
                $self->Warn("Error reading $$self{HTML_DUMP}{ERROR}") if $success < 0;
            }
        }
        if ($filename) {
            $raf->Close();  # close the file if we opened it
            # process the resource fork as an embedded file on Mac filesystems
            if ($rsize and $$options{ExtractEmbedded}) {
                local *RESOURCE_FILE;
                if ($self->Open(\*RESOURCE_FILE, "$filename/..namedfork/rsrc")) {
                    $$self{DOC_NUM} = $$self{DOC_COUNT} + 1;
                    $$self{IN_RESOURCE} = 1;
                    $self->ExtractInfo(\*RESOURCE_FILE, { ReEntry => 1 });
                    close RESOURCE_FILE;
                    delete $$self{IN_RESOURCE};
                } else {
                    $self->Warn('Error opening resource fork');
                }
            }
        }
    }

    # generate Validate tag if requested
    if ($$options{Validate} and not $reEntry) {
        Image::ExifTool::Validate::FinishValidate($self, $$req{validate});
    }

    @startTime and $self->FoundTag('ProcessingTime', Time::HiRes::tv_interval(\@startTime));

    # restore original options
    %saveOptions and $$self{OPTIONS} = \%saveOptions;

    if ($reEntry) {
        # restore necessary members when exiting re-entrant code
        $$self{$_} = $$reEntry{$_} foreach keys %$reEntry;
    }

    # ($type may be undef without an Error when processing sub-documents)
    return 0 if not defined $type or exists $$self{VALUE}{Error};
    return 1;
}

#------------------------------------------------------------------------------
# Get hash of extracted meta information
# Inputs: 0) ExifTool object reference
#         1-N) options hash reference, tag list reference or tag names
# Returns: Reference to information hash
# Notes: - pass an undefined value to avoid parsing arguments
#        - If groups are specified, first groups take precedence if duplicate
#          tags found but Duplicates option not set.
#        - tag names may end in '#' to extract ValueConv value
sub GetInfo($;@)
{
    local $_;
    my $self = shift;
    my %saveOptions;

    unless (@_ and not defined $_[0]) {
        %saveOptions = %{$$self{OPTIONS}}; # save original options
        # must set FILENAME so it isn't parsed from the arguments
        $$self{FILENAME} = '' unless defined $$self{FILENAME};
        $self->ParseArguments(@_);
    }

    # get reference to list of tags for which we will return info
    my ($rtnTags, $byValue, $wildTags) = $self->SetFoundTags();

    # build hash of tag information
    my (%info, %ignored);
    my $conv = $$self{OPTIONS}{PrintConv} ? 'PrintConv' : 'ValueConv';
    foreach (@$rtnTags) {
        my $val = $self->GetValue($_, $conv);
        defined $val or $ignored{$_} = 1, next;
        $info{$_} = $val;
    }

    # override specified tags with ValueConv value if necessary
    if (@$byValue) {
        # first determine the number of times each non-ValueConv value is used
        my %nonVal;
        $nonVal{$_} = ($nonVal{$_} || 0) + 1 foreach @$rtnTags;
        --$nonVal{$$rtnTags[$_]} foreach @$byValue;
        # loop through ValueConv tags, updating tag keys and returned values
        foreach (@$byValue) {
            my $tag = $$rtnTags[$_];
            my $val = $self->GetValue($tag, 'ValueConv');
            next unless defined $val;
            my $vtag = $tag;
            # generate a new tag key like "Tag #" or "Tag #(1)"
            $vtag =~ s/( |$)/ #/;
            unless (defined $$self{VALUE}{$vtag}) {
                $$self{VALUE}{$vtag} = $$self{VALUE}{$tag};
                $$self{TAG_INFO}{$vtag} = $$self{TAG_INFO}{$tag};
                $$self{TAG_EXTRA}{$vtag} = $$self{TAG_EXTRA}{$tag};
                $$self{FILE_ORDER}{$vtag} = $$self{FILE_ORDER}{$tag};
                # remove existing PrintConv entry unless we are using it too
                delete $info{$tag} unless $nonVal{$tag};
            }
            $$rtnTags[$_] = $vtag;  # store ValueConv value with new tag key
            $info{$vtag} = $val;    # return ValueConv value
        }
    }

    # remove ignored tags from the list
    my $reqTags = $$self{REQUESTED_TAGS} || [ ];
    if (%ignored) {
        if (not @$reqTags) {
            my @goodTags;
            foreach (@$rtnTags) {
                push @goodTags, $_ unless $ignored{$_};
            }
            $rtnTags = $$self{FOUND_TAGS} = \@goodTags;
        } elsif (@$wildTags) {
            # only remove tags specified by wildcard
            my @goodTags;
            my $i = 0;
            foreach (@$rtnTags) {
                if (@$wildTags and $i == $$wildTags[0]) {
                    shift @$wildTags;
                    push @goodTags, $_ unless $ignored{$_};
                } else {
                    push @goodTags, $_;
                }
                ++$i;
            }
            $rtnTags = $$self{FOUND_TAGS} = \@goodTags;
        }
    }

    # return sorted tag list if provided with a list reference
    if ($$self{IO_TAG_LIST}) {
        # use file order by default if no tags specified
        # (no such thing as 'Input' order in this case)
        my $sort = $$self{OPTIONS}{Sort};
        $sort = 'File' unless @$reqTags or ($sort and $sort ne 'Input');
        # return tags in specified sort order
        @{$$self{IO_TAG_LIST}} = $self->GetTagList($rtnTags, $sort, $$self{OPTIONS}{Sort2});
    }

    # restore original options
    %saveOptions and $$self{OPTIONS} = \%saveOptions;

    return \%info;
}

#------------------------------------------------------------------------------
# Inputs: 0) ExifTool object reference
#         1) [optional] reference to info hash or tag list ref (default is found tags)
#         2) [optional] sort order ('File', 'Input', ...)
#         3) [optional] secondary sort order
# Returns: List of tags in specified order
sub GetTagList($;$$$)
{
    local $_;
    my ($self, $info, $sort, $sort2) = @_;

    my $foundTags;
    if (ref $info eq 'HASH') {
        my @tags = keys %$info;
        $foundTags = \@tags;
    } elsif (ref $info eq 'ARRAY') {
        $foundTags = $info;
    }
    my $fileOrder = $$self{FILE_ORDER};

    if ($foundTags) {
        # make sure a FILE_ORDER entry exists for all tags
        # (note: already generated bogus entries for FOUND_TAGS case below)
        foreach (@$foundTags) {
            next if defined $$fileOrder{$_};
            $$fileOrder{$_} = 999;
        }
    } else {
        $sort = $info if $info and not $sort;
        $foundTags = $$self{FOUND_TAGS} || $self->SetFoundTags() or return undef;
    }
    $sort or $sort = $$self{OPTIONS}{Sort};

    # return original list if no sort order specified
    return @$foundTags unless $sort and $sort ne 'Input';

    if ($sort eq 'Tag' or $sort eq 'Alpha') {
        return sort @$foundTags;
    } elsif ($sort =~ /^Group(\d*(:\d+)*)/) {
        my $family = $1 || 0;
        # want to maintain a basic file order with the groups
        # ordered in the way they appear in the file
        my (%groupCount, %groupOrder);
        my $numGroups = 0;
        my $tag;
        foreach $tag (sort { $$fileOrder{$a} <=> $$fileOrder{$b} } @$foundTags) {
            my $group = $self->GetGroup($tag, $family);
            my $num = $groupCount{$group};
            $num or $num = $groupCount{$group} = ++$numGroups;
            $groupOrder{$tag} = $num;
        }
        $sort2 or $sort2 = $$self{OPTIONS}{Sort2};
        if ($sort2) {
            if ($sort2 eq 'Tag' or $sort2 eq 'Alpha') {
                return sort { $groupOrder{$a} <=> $groupOrder{$b} or $a cmp $b } @$foundTags;
            } elsif ($sort2 eq 'Descr') {
                my $desc = $self->GetDescriptions($foundTags);
                return sort { $groupOrder{$a} <=> $groupOrder{$b} or
                              $$desc{$a} cmp $$desc{$b} } @$foundTags;
            }
        }
        return sort { $groupOrder{$a} <=> $groupOrder{$b} or
                      $$fileOrder{$a} <=> $$fileOrder{$b} } @$foundTags;
    } elsif ($sort eq 'Descr') {
        my $desc = $self->GetDescriptions($foundTags);
        return sort { $$desc{$a} cmp $$desc{$b} } @$foundTags;
    } else {
        return sort { $$fileOrder{$a} <=> $$fileOrder{$b} } @$foundTags;
    }
}

#------------------------------------------------------------------------------
# Get list of found tags in specified sort order
# Inputs: 0) ExifTool object reference, 1) sort order ('File', 'Input', ...)
#         2) secondary sort order
# Returns: List of tag keys in specified order
# Notes: If not specified, sort order is taken from OPTIONS
sub GetFoundTags($;$$)
{
    local $_;
    my ($self, $sort, $sort2) = @_;
    my $foundTags = $$self{FOUND_TAGS} || $self->SetFoundTags() or return undef;
    return $self->GetTagList($foundTags, $sort, $sort2);
}

#------------------------------------------------------------------------------
# Get list of requested tags
# Inputs: 0) ExifTool object reference
# Returns: List of requested tag keys
sub GetRequestedTags($)
{
    local $_;
    return @{$_[0]{REQUESTED_TAGS}};
}

#------------------------------------------------------------------------------
# Get tag value
# Inputs: 0) ExifTool object reference
#         1) tag key or tag name with optional group names (case sensitive)
#            (or flattened tagInfo for getting field values, not part of public API)
#         2) [optional] Value type: PrintConv, ValueConv, Both, Raw or Rational, the default
#            is PrintConv or ValueConv, depending on the PrintConv option setting
#         3) raw field value (not part of public API)
# Returns: Scalar context: tag value or undefined
#          List context: list of values or empty list
sub GetValue($$;$)
{
    local $_;
    my ($self, $tag, $type) = @_; # plus: ($fieldValue)
    my (@convTypes, $tagInfo, $valueConv, $both);
    my $rawValue = $$self{VALUE};

    # get specific tag key if tag has a group name
    if ($tag =~ /^(.*):(.+)/) {
        my ($gp, $tg) = ($1, $2);
        my ($i, $key, @keys);
        # build list of tag keys in the order of priority (no index
        # is top priority, otherwise higher index is higher priority)
        for ($key=$tg, $i=$$self{DUPL_TAG}{$tg} || 0; ; --$i) {
            push @keys, $key if defined $$rawValue{$key};
            last if $i <= 0;
            $key = "$tg ($i)";
        }
        if (@keys) {
            $key = $self->GroupMatches($gp, \@keys);
            $tag = $key if $key;
        }
    }
    # figure out what conversions to do
    if ($type) {
        return $$self{RATIONAL}{$tag} if $type eq 'Rational';
    } else {
        $type = $$self{OPTIONS}{PrintConv} ? 'PrintConv' : 'ValueConv';
    }

    # start with the raw value
    my $value = $$rawValue{$tag};
    if (not defined $value) {
        return () unless ref $tag;
        # get the value of a structure field
        $tagInfo = $tag;
        $tag = $$tagInfo{Name};
        $value = $_[3];
        # (note: type "Both" is not allowed for structure fields)
        if ($type ne 'Raw') {
            push @convTypes, 'ValueConv';
            push @convTypes, 'PrintConv' unless $type eq 'ValueConv';
        }
    } else {
        $tagInfo = $$self{TAG_INFO}{$tag};
        if ($$tagInfo{Struct} and ref $value) {
            # must load XMPStruct.pl just in case (should already be loaded if
            # a structure was extracted, but we could also arrive here if a simple
            # list of values was stored incorrectly in a Struct tag)
            require 'Image/ExifTool/XMPStruct.pl';
            # convert strucure field values
            unless ($type eq 'Both') {
                # (note: ConvertStruct handles the filtering and escaping too if necessary)
                return Image::ExifTool::XMP::ConvertStruct($self,$tagInfo,$value,$type);
            }
            $valueConv = Image::ExifTool::XMP::ConvertStruct($self,$tagInfo,$value,'ValueConv');
            $value = Image::ExifTool::XMP::ConvertStruct($self,$tagInfo,$value,'PrintConv');
            # (must not save these in $$self{BOTH} because the values may have been escaped)
            return ($valueConv, $value);
        }
        if ($type ne 'Raw') {
            # use values we calculated already if we stored them
            $both = $$self{BOTH}{$tag};
            if ($both) {
                if ($type eq 'PrintConv') {
                    $value = $$both[1];
                } elsif ($type eq 'ValueConv') {
                    $value = $$both[0];
                    $value = $$both[1] unless defined $value;
                } else {
                    ($valueConv, $value) = @$both;
                }
            } else {
                push @convTypes, 'ValueConv';
                push @convTypes, 'PrintConv' unless $type eq 'ValueConv';
            }
        }
    }

    # do the conversions
    my (@val, @prt, @raw, $convType);
    foreach $convType (@convTypes) {
        # don't convert a scalar reference or structure
        last if ref $value eq 'SCALAR' and not $$tagInfo{ConvertBinary};
        my $conv = $$tagInfo{$convType};
        unless (defined $conv) {
            if ($convType eq 'ValueConv') {
                next unless $$tagInfo{Binary};
                $conv = '\$val';  # return scalar reference for binary values
            } else {
                # use PRINT_CONV from tag table if PrintConv doesn't exist
                next unless defined($conv = $$tagInfo{Table}{PRINT_CONV});
                next if exists $$tagInfo{$convType};
            }
        }
        # save old ValueConv value if we want Both
        $valueConv = $value if $type eq 'Both' and $convType eq 'PrintConv';
        my ($i, $val, $vals, @values, $convList);
        # split into list if conversion is an array
        if (ref $conv eq 'ARRAY') {
            $convList = $conv;
            $conv = $$convList[0];
            my @valList = (ref $value eq 'ARRAY') ? @$value : split ' ', $value;
            # reorganize list if specified (Note: The writer currently doesn't
            # relist values, so they may be grouped but the order must not change)
            my $relist = $$tagInfo{Relist};
            if ($relist) {
                my (@newList, $oldIndex);
                foreach $oldIndex (@$relist) {
                    my ($newVal, @join);
                    if (ref $oldIndex) {
                        foreach (@$oldIndex) {
                            push @join, $valList[$_] if defined $valList[$_];
                        }
                        $newVal = join(' ', @join) if @join;
                    } else {
                        $newVal = $valList[$oldIndex];
                    }
                    push @newList, $newVal if defined $newVal;
                }
                $value = \@newList;
            } else {
                $value = \@valList;
            }
            return () unless @$value;
        }
        # initialize array so we can iterate over values in list
        if (ref $value eq 'ARRAY') {
            if (defined $$tagInfo{RawJoin}) {
                $val = join ' ', @$value;
            } else {
                $i = 0;
                $vals = $value;
                $val = $$vals[0];
            }
        } else {
            $val = $value;
        }
        # loop through all values in list
        for (;;) {
            if (defined $conv) {
                # get values of required tags if this is a Composite tag
                if (ref $val eq 'HASH' and not @val) {
                    # disable escape of source values so we don't double escape them
                    my $oldEscape = $$self{ESCAPE_PROC};
                    delete $$self{ESCAPE_PROC};
                    # temporarily delete filter so it isn't applied to the Require'd values
                    my $oldFilter = $$self{OPTIONS}{Filter};
                    delete $$self{OPTIONS}{Filter};
                    foreach (keys %$val) {
                        $raw[$_] = $$rawValue{$$val{$_}};
                        ($val[$_], $prt[$_]) = $self->GetValue($$val{$_}, 'Both');
                        next if defined $val[$_] or not $$tagInfo{Require}{$_};
                        $$self{OPTIONS}{Filter} = $oldFilter if defined $oldFilter;
                        $$self{ESCAPE_PROC} = $oldEscape;
                        return ();
                    }
                    $$self{OPTIONS}{Filter} = $oldFilter if defined $oldFilter;
                    $$self{ESCAPE_PROC} = $oldEscape;
                    # set $val to $val[0], or \@val for a CODE ref conversion
                    $val = ref $conv eq 'CODE' ? \@val : $val[0];
                }
                if (ref $conv eq 'HASH') {
                    # look up converted value in hash
                    my $lc;
                    if (defined($value = $$conv{$val})) {
                        # override with our localized language PrintConv if available
                        if ($$self{CUR_LANG} and $convType eq 'PrintConv' and
                            # (no need to check for lang-alt tag names -- they won't have a PrintConv)
                            ref($lc = $$self{CUR_LANG}{$$tagInfo{Name}}) eq 'HASH' and
                            ($lc = $$lc{PrintConv}) and ($lc = $$lc{$value}))
                        {
                            $value = $self->Decode($lc, 'UTF8');
                        }
                    } else {
                        if ($$conv{BITMASK}) {
                            $value = DecodeBits($val, $$conv{BITMASK}, $$tagInfo{BitsPerWord});
                            # override with localized language strings
                            if (defined $value and $$self{CUR_LANG} and $convType eq 'PrintConv' and
                                ref($lc = $$self{CUR_LANG}{$$tagInfo{Name}}) eq 'HASH' and
                                ($lc = $$lc{PrintConv}))
                            {
                                my @vals = split ', ', $value;
                                foreach (@vals) {
                                    $_ = $$lc{$_} if defined $$lc{$_};
                                }
                                $value = join ', ', @vals;
                            }
                        } else {
                             # use alternate conversion routine if available
                            if ($$conv{OTHER}) {
                                local $SIG{'__WARN__'} = \&SetWarning;
                                undef $evalWarning;
                                $value = &{$$conv{OTHER}}($val, undef, $conv);
                                $self->Warn("$convType $tag: " . CleanWarning()) if $evalWarning;
                            }
                            if (not defined $value) {
                                if (($$tagInfo{PrintHex} or
                                    ($$tagInfo{Mask} and not defined $$tagInfo{PrintHex}))
                                    and $val and IsInt($val) and $convType eq 'PrintConv')
                                {
                                    $val = sprintf('0x%x',$val);
                                }
                                $value = "Unknown ($val)";
                            }
                        }
                    }
                } else {
                    # call subroutine or do eval to convert value
                    local $SIG{'__WARN__'} = \&SetWarning;
                    undef $evalWarning;
                    if (ref $conv eq 'CODE') {
                        $value = &$conv($val, $self);
                    } else {
                        #### eval ValueConv/PrintConv ($val, $self, @val, @prt, @raw)
                        $value = eval $conv;
                        $@ and $evalWarning = $@;
                    }
                    $self->Warn("$convType $tag: " . CleanWarning()) if $evalWarning;
                }
            } else {
                $value = $val;
            }
            last unless $vals;
            # must store a separate copy of each binary data value in the list
            if (ref $value eq 'SCALAR') {
                my $tval = $$value;
                $value = \$tval;
            }
            # save this converted value and step to next value in list
            push @values, $value if defined $value;
            if (++$i >= scalar(@$vals)) {
                $value = \@values if @values;
                last;
            }
            $val = $$vals[$i];
            if ($convList) {
                my $nextConv = $$convList[$i];
                if ($nextConv and $nextConv eq 'REPEAT') {
                    undef $convList;
                } else {
                    $conv = $nextConv;
                }
            }
        }
        # return undefined now if no value
        return () unless defined $value;
        # join back into single value if split for conversion list
        if ($convList and ref $value eq 'ARRAY') {
            $value = join($convType eq 'PrintConv' ? '; ' : ' ', @$value);
        }
    }
    if ($type eq 'Both') {
        # save both (unescaped) values because we often need them again
        # (Composite tags need "Both" and often Require one tag for various Composite tags)
        $$self{BOTH}{$tag} = [ $valueConv, $value ] unless $both;
        # escape values if necessary
        if ($$self{ESCAPE_PROC}) {
            DoEscape($value, $$self{ESCAPE_PROC});
            if (defined $valueConv) {
                DoEscape($valueConv, $$self{ESCAPE_PROC});
            } else {
                $valueConv = $value;
            }
        } elsif (not defined $valueConv) {
            # $valueConv is undefined if there was no print conversion done
            $valueConv = $value;
        }
        $self->Filter(\$value) if defined $$self{OPTIONS}{Filter};
        # return Both values as a list (ValueConv, PrintConv)
        return ($valueConv, $value);
    }
    # escape value if necessary
    DoEscape($value, $$self{ESCAPE_PROC}) if $$self{ESCAPE_PROC};

    # filter if necessary
    $self->Filter(\$value) if defined $$self{OPTIONS}{Filter} and $type eq 'PrintConv';

    if (ref $value eq 'ARRAY') {
        if (defined $$self{OPTIONS}{ListItem}) {
            $value = $$value[$$self{OPTIONS}{ListItem}];
        } elsif (wantarray) {
            # return array if requested
            return @$value;
        } elsif ($type eq 'PrintConv' and not $$self{OPTIONS}{List} and not ref $$value[0]) {
            # join PrintConv values in comma-separated string if List option not used
            # and list contains simple scalars (otherwise return ARRAY ref)
            $value = join $$self{OPTIONS}{ListSep}, @$value;
        }
    }
    return $value;
}

#------------------------------------------------------------------------------
# Get tag identification number
# Inputs: 0) ExifTool object reference, 1) tag key
# Returns: Scalar context: tag ID if available, otherwise ''
#          List context: 0) tag ID (or ''), 1) language code (or undef)
sub GetTagID($$)
{
    my ($self, $tag) = @_;
    my $tagInfo = $$self{TAG_INFO}{$tag};
    return '' unless $tagInfo and defined $$tagInfo{TagID};
    return ($$tagInfo{TagID}, $$tagInfo{LangCode}) if wantarray;
    return $$tagInfo{TagID};
}

#------------------------------------------------------------------------------
# Get description for specified tag
# Inputs: 0) ExifTool object reference, 1) tag key
# Returns: Tag description
# Notes: Will always return a defined value, even if description isn't available
sub GetDescription($$)
{
    local $_;
    my ($self, $tag) = @_;
    my ($desc, $name);
    my $tagInfo = $$self{TAG_INFO}{$tag};
    # ($tagInfo won't be defined for missing tags extracted with -f)
    if ($tagInfo) {
        # use alternate language description if available
        while ($$self{CUR_LANG}) {
            $desc = $$self{CUR_LANG}{$$tagInfo{Name}};
            if ($desc) {
                # must look up Description if this tag also has a PrintConv
                $desc = $$desc{Description} or last if ref $desc;
            } else {
                # look up default language of lang-alt tag
                last unless $$tagInfo{LangCode} and
                    ($name = $$tagInfo{Name}) =~ s/-$$tagInfo{LangCode}$// and
                    $desc = $$self{CUR_LANG}{$name};
                $desc = $$desc{Description} or last if ref $desc;
                $desc .= " ($$tagInfo{LangCode})";
            }
            # escape description if necessary
            DoEscape($desc, $$self{ESCAPE_PROC}) if $$self{ESCAPE_PROC};
            # return description in proper Charset
            return $self->Decode($desc, 'UTF8');
        }
        $desc = $$tagInfo{Description};
    }
    # just make the tag more readable if description doesn't exist
    unless ($desc) {
        $desc = MakeDescription(GetTagName($tag));
        # save description in tag information
        $$tagInfo{Description} = $desc if $tagInfo;
    }
    return $desc;
}

#------------------------------------------------------------------------------
# Get group name for specified tag
# Inputs: 0) ExifTool object reference
#         1) tag key (or reference to tagInfo hash, not part of the public API)
#         2) [optional] group family (-1 to get extended group list, or multiple
#            families separated by colons to return multiple groups as a string)
# Returns: Scalar context: group name (for family 0 if not otherwise specified)
#          List context: group name if family specified, otherwise list of
#          group names for each family.  Returns '' for undefined tag.
# Notes: Mutiple families may be specified with ':' in family argument (eg. '1:2')
sub GetGroup($$;$)
{
    local $_;
    my ($self, $tag, $family) = @_;
    my ($tagInfo, @groups, @families, $simplify, $byTagInfo, $ex);
    if (ref $tag eq 'HASH') {
        $tagInfo = $tag;
        $tag = $$tagInfo{Name};
        # set flag so we don't get extra information for an extracted tag
        $byTagInfo = 1;
    } else {
        $tagInfo = $$self{TAG_INFO}{$tag} || { };
        $ex = $$self{TAG_EXTRA}{$tag};
    }
    my $groups = $$tagInfo{Groups};
    # fill in default groups unless already done
    # (after this, Groups 0-2 in tagInfo are guaranteed to be defined)
    unless ($$tagInfo{GotGroups}) {
        my $tagTablePtr = $$tagInfo{Table} || { GROUPS => { } };
        # construct our group list
        $groups or $groups = $$tagInfo{Groups} = { };
        # fill in default groups
        foreach (0..2) {
            $$groups{$_} = $$tagTablePtr{GROUPS}{$_} || '' unless $$groups{$_};
        }
        # set flag indicating group list was built
        $$tagInfo{GotGroups} = 1;
    }
    if (defined $family and $family ne '-1') {
        if ($family =~ /[^\d]/) {
            @families = ($family =~ /\d+/g);
            return(($ex && $$ex{G0}) || $$groups{0}) unless @families;
            $simplify = 1 unless $family =~ /^:/;
            undef $family;
            foreach (0..2) { $groups[$_] = $$groups{$_}; }
        } else {
            return(($ex && $$ex{"G$family"}) || $$groups{$family}) if $family == 0 or $family == 2;
            $groups[1] = $$groups{1};
        }
    } else {
        return(($ex && $$ex{G0}) || $$groups{0}) unless wantarray;
        foreach (0..2) { $groups[$_] = $$groups{$_}; }
    }
    $groups[3] = 'Main';
    $groups[4] = ($tag =~ /\((\d+)\)$/) ? "Copy$1" : '';
    # handle dynamic group names if necessary
    if ($ex and not $byTagInfo) {
        $groups[0] = $$ex{G0} if $$ex{G0};
        $groups[1] = $$ex{G1} =~ /^\+(.*)/ ? "$groups[1]$1" : $$ex{G1} if $$ex{G1};
        $groups[3] = 'Doc' . $$ex{G3} if $$ex{G3};
        $groups[5] = $$ex{G5} || $groups[1] if defined $$ex{G5};
    }
    if ($family) {
        return $groups[$family] || '' if $family > 0;
        # add additional matching group names to list
        # eg) for MIE-Doc, also add MIE1, MIE1-Doc, MIE-Doc1 and MIE1-Doc1
        # and for MIE2-Doc3, also add MIE2, MIE-Doc3, MIE2-Doc and MIE-Doc
        if ($groups[1] =~ /^MIE(\d*)-(.+?)(\d*)$/) {
            push @groups, 'MIE' . ($1 || '1');
            push @groups, 'MIE' . ($1 ? '' : '1') . "-$2$3";
            push @groups, "MIE$1-$2" . ($3 ? '' : '1');
            push @groups, 'MIE' . ($1 ? '' : '1') . "-$2" . ($3 ? '' : '1');
        }
    }
    if (@families) {
        my @grps;
        # create list of group names (without identical adjacent groups if simplifying)
        foreach (@families) {
            my $grp = $groups[$_] or next;
            push @grps, $grp unless $simplify and @grps and $grp eq $grps[-1];
        }
        # remove leading "Main:" if simplifying
        shift @grps if $simplify and @grps > 1 and $grps[0] eq 'Main';
        # return colon-separated string of group names
        return join ':', @grps;
    }
    return @groups;
}

#------------------------------------------------------------------------------
# Get group names for specified tags
# Inputs: 0) ExifTool object reference
#         1) [optional] information hash reference (default all extracted info)
#         2) [optional] group family (default 0)
# Returns: List of group names in alphabetical order
sub GetGroups($;$$)
{
    local $_;
    my $self = shift;
    my $info = shift;
    my $family;

    # figure out our arguments
    if (ref $info ne 'HASH') {
        $family = $info;
        $info = $$self{VALUE};
    } else {
        $family = shift;
    }
    $family = 0 unless defined $family;

    # get a list of all groups in specified information
    my ($tag, %groups);
    foreach $tag (keys %$info) {
        $groups{ $self->GetGroup($tag, $family) } = 1;
    }
    return sort keys %groups;
}

#------------------------------------------------------------------------------
# Set priority for group where new values are written
# Inputs: 0) ExifTool object reference,
#         1-N) group names (reset to default if no groups specified)
sub SetNewGroups($;@)
{
    local $_;
    my ($self, @groups) = @_;
    @groups or @groups = @defaultWriteGroups;
    my $count = @groups;
    my %priority;
    foreach (@groups) {
        $priority{lc($_)} = $count--;
    }
    $priority{file} = 10;       # 'File' group is always written (Comment)
    $priority{composite} = 10;  # 'Composite' group is always written
    # set write priority (higher # is higher priority)
    $$self{WRITE_PRIORITY} = \%priority;
    $$self{WRITE_GROUPS} = \@groups;
}

#------------------------------------------------------------------------------
# Build Composite tags from Require'd/Desire'd tags
# Inputs: 0) ExifTool object reference
# Note: Tag values are calculated in alphabetical order unless a tag Require's
#       or Desire's another Composite tag, in which case the calculation is
#       deferred until after the other tag is calculated.
sub BuildCompositeTags($)
{
    local $_;
    my $self = shift;

    $$self{BuildingComposite} = 1;
    
    my $compTable = GetTagTable('Image::ExifTool::Composite');
    my @tagList = sort keys %$compTable;
    my $rawValue = $$self{VALUE};
    my (%tagsUsed, %cache);

    for (;;) {
        my (%notBuilt, $tag, @deferredTags);
        $notBuilt{$_} = 1 foreach @tagList;
COMPOSITE_TAG:
        foreach $tag (@tagList) {
            next if $specialTags{$tag};
            my $tagInfo = $self->GetTagInfo($compTable, $tag);
            next unless $tagInfo;
            # put required tags into array and make sure they all exist
            my $subDoc = ($$tagInfo{SubDoc} and $$self{DOC_COUNT});
            my $require = $$tagInfo{Require} || { };
            my $desire  = $$tagInfo{Desire}  || { };
            my $inhibit = $$tagInfo{Inhibit} || { };
            # loop through sub-documents if necessary
            my $docNum = 0;
            for (;;) {
                my (%tagKey, $found, $index);
                # save Require'd and Desire'd tag values in list
                for ($index=0; ; ++$index) {
                    my $reqTag = $$require{$index} || $$desire{$index} || $$inhibit{$index};
                    unless ($reqTag) {
                        # allow Composite with no Require'd or Desire'd tags
                        $found = 1 if $index == 0;
                        last;
                    }
                    if ($subDoc) {
                        # handle SubDoc tags specially to cache tag keys for faster
                        # processing when there are a large number of sub-documents
                        # - get document number from the tag groups if specified,
                        #   otherwise we are looping through all documents for this tag
                        my $doc = $reqTag =~ s/\b(Main|Doc(\d+)):// ? ($2 || 0) : $docNum;
                        # make fast lookup for keys of this tag with specified groups other than doc group
                        # (similar to code in InsertTagValues(), but this is case-sensitive)
                        my $cacheTag = $cache{$reqTag};
                        unless ($cacheTag) {
                            $cacheTag = $cache{$reqTag} = [ ];
                            my $reqGroup;
                            $reqTag =~ s/^(.*):// and $reqGroup = $1;
                            my ($i, $key, @keys);
                            # build list of tag keys in order of precedence
                            for ($key=$reqTag, $i=$$self{DUPL_TAG}{$reqTag} || 0; ; --$i) {
                                push @keys, $key if defined $$rawValue{$key};
                                last if $i <= 0;
                                $key = "$reqTag ($i)";
                            }
                            @keys = $self->GroupMatches($reqGroup, \@keys) if defined $reqGroup;
                            if (@keys) {
                                my $ex = $$self{TAG_EXTRA};
                                # loop through tags in reverse order of precedence so the higher
                                # priority tag will win in the case of duplicates within a doc
                                $$cacheTag[$$ex{$_} ? $$ex{$_}{G3} || 0 : 0] = $_ foreach reverse @keys;
                            }
                        }
                        # (set $reqTag to a bogus key if not found)
                        $reqTag = $$cacheTag[$doc] || "$reqTag (0)";
                    } elsif ($reqTag =~ /^(.*):(.+)/) {
                        my ($reqGroup, $name) = ($1, $2);
                        if ($reqGroup eq 'Composite' and $notBuilt{$name}) {
                            push @deferredTags, $tag;
                            next COMPOSITE_TAG;
                        }
                        # (CAREFUL! keys may not be sequential if one was deleted)
                        my ($i, $key, @keys);
                        for ($key=$name, $i=$$self{DUPL_TAG}{$name} || 0; ; --$i) {
                            push @keys, $key if defined $$rawValue{$key};
                            last if $i <= 0;
                            $key = "$name ($i)";
                        }
                        # find first matching tag
                        $key = $self->GroupMatches($reqGroup, \@keys);
                        $reqTag = $key || "$name (0)";
                    } elsif ($notBuilt{$reqTag}) {
                        # calculate this tag later if it relies on another
                        # Composite tag which hasn't been calculated yet
                        push @deferredTags, $tag;
                        next COMPOSITE_TAG;
                    }
                    if (defined $$rawValue{$reqTag}) {
                        if ($$inhibit{$index}) {
                            $found = 0;
                            last;
                        } else {
                            $found = 1;
                        }
                    } elsif ($$require{$index}) {
                        $found = 0;
                        last;   # don't continue since we require this tag
                    }
                    $tagKey{$index} = $reqTag;
                }
                if ($docNum) {
                    if ($found) {
                        $$self{DOC_NUM} = $docNum;
                        $self->FoundTag($tagInfo, \%tagKey);
                        delete $$self{DOC_NUM};
                    }
                    next if ++$docNum <= $$self{DOC_COUNT};
                    last;
                } elsif ($found) {
                    delete $notBuilt{$tag}; # this tag is OK to build now
                    # keep track of all Require'd tag keys
                    foreach (keys %tagKey) {
                        # only tag keys with same name as a Composite tag
                        # can be replaced (also eliminates keys with
                        # instance numbers which can't be replaced either)
                        next unless $$compTable{$tagKey{$_}};
                        my $keyRef = \$tagKey{$_};
                        $tagsUsed{$$keyRef} or $tagsUsed{$$keyRef} = [ ];
                        push @{$tagsUsed{$$keyRef}}, $keyRef;
                    }
                    # save reference to tag key lookup as value for Composite tag
                    my $key = $self->FoundTag($tagInfo, \%tagKey);
                    # check to see if we just replaced one of the tag keys we Require'd
                    if (defined $key and $tagsUsed{$key}) {
                        foreach (@{$tagsUsed{$key}}) {
                            $$_ = $$self{MOVED_KEY};    # replace with new tag key
                        }
                        delete $tagsUsed{$key};         # can't be replaced again
                    }
                } elsif (not defined $found) {
                    delete $notBuilt{$tag}; # tag can't be built anyway
                }
                last unless $subDoc;
                # don't process sub-documents if there is no chance to build this tag
                # (can be very time-consuming if there are many docs)
                if (%$require) {
                    foreach (keys %$require) {
                        my $reqTag = $$require{$_};
                        $reqTag =~ s/.*://;
                        next COMPOSITE_TAG unless defined $$rawValue{$reqTag};
                    }
                    $docNum = 1;   # go ahead and process the 1st sub-document
                } else {
                    my @try = ref $$tagInfo{SubDoc} ? @{$$tagInfo{SubDoc}} : keys %$desire;
                    # at least one of the specified desire tags must exist
                    foreach (@try) {
                        my $desTag = $$desire{$_} or next;
                        $desTag =~ s/.*://;
                        defined $$rawValue{$desTag} and $docNum = 1, last;
                    }
                    last unless $docNum;
                }
            }
        }
        last unless @deferredTags;
        if (@deferredTags == @tagList) {
            # everything was deferred in the last pass,
            # must be a circular dependency
            warn "Circular dependency in Composite tags\n";
            last;
        }
        @tagList = @deferredTags; # calculate deferred tags now
    }
    delete $$self{BuildingComposite};
}

#------------------------------------------------------------------------------
# Get tag name (removes copy index)
# Inputs: 0) Tag key
# Returns: Tag name
sub GetTagName($)
{
    local $_;
    $_[0] =~ /^(\S+)/;
    return $1;
}

#------------------------------------------------------------------------------
# Get list of shortcuts
# Returns: Shortcut list (sorted alphabetically)
sub GetShortcuts()
{
    local $_;
    require Image::ExifTool::Shortcuts;
    return sort keys %Image::ExifTool::Shortcuts::Main;
}

#------------------------------------------------------------------------------
# Get file type for specified extension
# Inputs: 0) file name or extension (case is not significant),
#            or FileType value if a description is requested
#         1) flag to return long description instead of type ('0' to return any recognized type)
# Returns: File type (or desc) or undef if extension not supported or if
#          description is the same as the input FileType.  In list context,
#          may return more than one file type if the file may be different formats.
#          Returns list of all supported extensions if no file specified
sub GetFileType(;$$)
{
    local $_;
    my ($file, $desc) = @_;
    unless (defined $file) {
        my @types;
        if (defined $desc and $desc eq '0') {
            # return all recognized types
            @types = sort keys %fileTypeLookup;
        } else {
            # return all supported types
            foreach (sort keys %fileTypeLookup) {
                my $module = $moduleName{$_};
                $module = $moduleName{$fileTypeLookup{$_}} unless defined $module;
                push @types, $_ unless defined $module and $module eq '0';
            }
        }
        return @types;
    }
    my ($fileType, $subType);
    my $fileExt = GetFileExtension($file);
    unless ($fileExt) {
        if ($file =~ s/ \((.*)\)$//) {
            $subType = $1;
            $fileExt = GetFileExtension($file);
        }
        $fileExt = uc($file) unless $fileExt;
    }
    $fileExt and $fileType = $fileTypeLookup{$fileExt}; # look up the file type
    $fileType = $fileTypeLookup{$fileType} while $fileType and not ref $fileType;
    # return description if specified
    # (allow input $file to be a FileType for this purpose)
    if ($desc) {
        $desc = $fileType ? $$fileType[1] : $fileDescription{$file};
        $desc .= ", $subType" if $subType;
        return $desc;
    } elsif ($fileType and (not defined $desc or $desc ne '0')) {
        # return only supported file types
        my $mod = $moduleName{$$fileType[0]};
        undef $fileType if defined $mod and $mod eq '0';
    }
    $fileType or return ();
    $fileType = $$fileType[0];      # get file type (or list of types)
    if (wantarray) {
        return @$fileType if ref $fileType eq 'ARRAY';
    } elsif ($fileType) {
        $fileType = $fileExt if ref $fileType eq 'ARRAY';
    }
    return $fileType;
}

#------------------------------------------------------------------------------
# Return true if we can write the specified file type
# Inputs: 0) file name or ext
# Returns: true if writable, 0 if not writable, undef if unrecognized
sub CanWrite($)
{
    local $_;
    my $file = shift or return undef;
    my ($type) = GetFileType($file) or return undef;
    if ($noWriteFile{$type}) {
        # can't write TIFF files with certain extensions (various RAW formats)
        my $ext = GetFileExtension($file) || uc($file);
        return grep(/^$ext$/, @{$noWriteFile{$type}}) ? 0 : 1 if $ext;
    }
    unless (%writeTypes) {
        $writeTypes{$_} = 1 foreach @writeTypes;
    }
    return $writeTypes{$type};
}

#------------------------------------------------------------------------------
# Return true if we can create the specified file type
# Inputs: 0) file name or ext
# Returns: true if creatable, 0 if not writable, undef if unrecognized
sub CanCreate($)
{
    local $_;
    my $file = shift or return undef;
    my $ext = GetFileExtension($file) || uc($file);
    my $type = GetFileType($file) or return undef;
    return 1 if $createTypes{$ext} or $createTypes{$type};
    return 0;
}

#==============================================================================
# Functions below this are not part of the public API

# Initialize member variables for reading or writing a new file
# Inputs: 0) ExifTool object reference
sub Init($)
{
    local $_;
    my $self = shift;
    # delete all DataMember variables (lower-case names)
    foreach (keys %$self) {
        /[a-z]/ and delete $$self{$_};
    }
    delete $$self{FOUND_TAGS};      # list of found tags
    delete $$self{EXIF_DATA};       # the EXIF data block
    delete $$self{EXIF_POS};        # EXIF position in file
    delete $$self{FIRST_EXIF_POS};  # position of first EXIF in file
    delete $$self{HTML_DUMP};       # html dump information
    delete $$self{SET_GROUP0};      # group0 name override
    delete $$self{SET_GROUP1};      # group1 name override
    delete $$self{DOC_NUM};         # current embedded document number
    $$self{DOC_COUNT}  = 0;         # count of embedded documents processed
    $$self{BASE}       = 0;         # base for offsets from start of file
    $$self{FILE_ORDER} = { };       # * hash of tag order in file ('*' = based on tag key)
    $$self{VALUE}      = { };       # * hash of raw tag values
    $$self{BOTH}       = { };       # * hash for Value/PrintConv values of Require'd tags
    $$self{RATIONAL}   = { };       # * hash of original rational components
    $$self{TAG_INFO}   = { };       # * hash of tag information
    $$self{TAG_EXTRA}  = { };       # * hash of extra tag information (dynamic group names)
    $$self{PRIORITY}   = { };       # * priority of current tags
    $$self{LIST_TAGS}  = { };       # hash of tagInfo refs for active List-type tags
    $$self{PROCESSED}  = { };       # hash of processed directory start positions
    $$self{DIR_COUNT}  = { };       # count various types of directories
    $$self{DUPL_TAG}   = { };       # last-used index for duplicate-tag keys
    $$self{WARNED_ONCE}= { };       # WarnOnce() warnings already issued
    $$self{WRITTEN}    = { };       # list of tags written (selected tags only)
    $$self{FORCE_WRITE}= { };       # ForceWrite lookup (set from ForceWrite tag)
    $$self{FOUND_DIR}  = { };       # hash of directory names found in file
    $$self{PATH}       = [ ];       # current subdirectory path in file when reading
    $$self{NUM_FOUND}  = 0;         # total number of tags found (incl. duplicates)
    $$self{CHANGED}    = 0;         # number of tags changed (writer only)
    $$self{INDENT}     = '  ';      # initial indent for verbose messages
    $$self{PRIORITY_DIR} = '';      # the priority directory name
    $$self{LOW_PRIORITY_DIR} = { PreviewIFD => 1 }; # names of priority 0 directories
    $$self{TIFF_TYPE}  = '';        # type of TIFF data (APP1, TIFF, NEF, etc...)
    $$self{FMT_EXPR}   = undef;     # current advanced formatting expression
    $$self{Make}       = '';        # camera make
    $$self{Model}      = '';        # camera model
    $$self{CameraType} = '';        # Olympus camera type
    if ($self->Options('HtmlDump')) {
        require Image::ExifTool::HtmlDump;
        $$self{HTML_DUMP} = new Image::ExifTool::HtmlDump;
    }
    # make sure our TextOut is a file reference
    $$self{OPTIONS}{TextOut} = \*STDOUT unless ref $$self{OPTIONS}{TextOut};
}

#------------------------------------------------------------------------------
# Combine information from a list of info hashes
# Unless Duplicates is enabled, first entry found takes priority
# Inputs: 0) ExifTool object reference, 1-N) list of info hash references
# Returns: Combined information hash reference
sub CombineInfo($;@)
{
    local $_;
    my $self = shift;
    my (%combinedInfo, $info, $tag, %haveInfo);

    if ($$self{OPTIONS}{Duplicates}) {
        while ($info = shift) {
            foreach $tag (keys %$info) {
                $combinedInfo{$tag} = $$info{$tag};
            }
        }
    } else {
        while ($info = shift) {
            foreach $tag (keys %$info) {
                my $tagName = GetTagName($tag);
                next if $haveInfo{$tagName};
                $haveInfo{$tagName} = 1;
                $combinedInfo{$tag} = $$info{$tag};
            }
        }
    }
    return \%combinedInfo;
}

#------------------------------------------------------------------------------
# Get tag table name
# Inputs: 0) ExifTool object reference, 1) tag key
# Returns: Table name if available, otherwise ''
sub GetTableName($$)
{
    my ($self, $tag) = @_;
    my $tagInfo = $$self{TAG_INFO}{$tag} or return '';
    return $$tagInfo{Table}{SHORT_NAME};
}

#------------------------------------------------------------------------------
# Get tag index number
# Inputs: 0) ExifTool object reference, 1) tag key
# Returns: Table index number, or undefined if this tag isn't indexed
sub GetTagIndex($$)
{
    my ($self, $tag) = @_;
    my $tagInfo = $$self{TAG_INFO}{$tag} or return undef;
    return $$tagInfo{Index};
}

#------------------------------------------------------------------------------
# Find value for specified tag
# Inputs: 0) ExifTool ref, 1) tag name, 2) tag group (family 1)
# Returns: value or undef
sub FindValue($$$)
{
    my ($et, $tag, $grp) = @_;
    my ($i, $val);
    my $value = $$et{VALUE};
    for ($i=0; ; ++$i) {
        my $key = $tag . ($i ? " ($i)" : '');
        last unless defined $$value{$key};
        if ($et->GetGroup($key, 1) eq $grp) {
            $val = $$value{$key};
            last;
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Get tag key for next existing tag
# Inputs: 0) ExifTool ref, 1) tag key or case-sensitive tag name
# Returns: Key of next existing tag, or undef if no more
# Notes: This routine is provided for iterating through duplicate tags in the
#        ValueConv of Composite tags.
sub NextTagKey($$)
{
    my ($self, $tag) = @_;
    my $i = ($tag =~ s/ \((\d+)\)$//) ? $1 + 1 : 1;
    $tag = "$tag ($i)";
    return $tag if defined $$self{VALUE}{$tag};
    return undef;
}

#------------------------------------------------------------------------------
# Encode file name for calls to system i/o routines
# Inputs: 0) ExifTool ref, 1) file name in CharSetFileName, 2) flag to force conversion
# Returns: true if Windows Unicode routines should be used (in which case
#          the file name will be encoded as a null-terminated UTF-16LE string)
sub EncodeFileName($$;$)
{
    my ($self, $file, $force) = @_;
    my $enc = $$self{OPTIONS}{CharsetFileName};
    if ($enc) {
        if ($file =~ /[\x80-\xff]/ or $force) {
            # encode for use in Windows Unicode functions if necessary
            if ($^O eq 'MSWin32') {
                local $SIG{'__WARN__'} = \&SetWarning;
                if (eval { require Win32API::File }) {
                    # recode as UTF-16LE and add null terminator
                    $_[1] = $self->Decode($file, $enc, undef, 'UTF16', 'II') . "\0\0";
                    return 1;
                }
                $self->WarnOnce('Install Win32API::File for Windows Unicode file support');
            } else {
                # recode as UTF-8 for other platforms if necessary
                $_[1] = $self->Decode($file, $enc, undef, 'UTF8') unless $enc eq 'UTF8';
            }
        }
    } elsif ($^O eq 'MSWin32' and $file =~ /[\x80-\xff]/ and not defined $enc) {
        require Image::ExifTool::XMP;
        if (Image::ExifTool::XMP::IsUTF8(\$file) < 0) {
            $self->WarnOnce('FileName encoding not specified');
        }
    }
    return 0;
}

#------------------------------------------------------------------------------
# Modified perl open() routine to properly handle special characters in file names
# Inputs: 0) ExifTool ref, 1) filehandle, 2) filename,
#         3) mode: '<' or undef = read, '>' = write, '+<' = update
# Returns: true on success
# Note: Must call like "$et->Open(\*FH,$file)", not "$et->Open(FH,$file)" to avoid
#       "unopened filehandle" errors due to a change in scope of the filehandle
sub Open($*$;$)
{
    my ($self, $fh, $file, $mode) = @_;

    $file =~ s/^([\s&])/.\/$1/; # protect leading whitespace or ampersand
    # default to read mode ('<') unless input is a pipe
    $mode = ($file =~ /\|$/ ? '' : '<') unless $mode;
    if ($mode) {
        if ($self->EncodeFileName($file)) {
            # handle Windows Unicode file name
            local $SIG{'__WARN__'} = \&SetWarning;
            my ($access, $create);
            if ($mode eq '>') {
                eval {
                    $access  = Win32API::File::GENERIC_WRITE();
                    $create  = Win32API::File::CREATE_ALWAYS();
                }
            } else {
                eval {
                    $access  = Win32API::File::GENERIC_READ();
                    $access |= Win32API::File::GENERIC_WRITE() if $mode eq '+<'; # update
                    $create  = Win32API::File::OPEN_EXISTING();
                }
            }
            my $wh = eval { Win32API::File::CreateFileW($file, $access, 0, [], $create, 0, []) };
            return undef unless $wh;
            my $fd = eval { Win32API::File::OsFHandleOpenFd($wh, 0) };
            if (not defined $fd or $fd < 0) {
                eval { Win32API::File::CloseHandle($wh) };
                return undef;
            }
            $file = "&=$fd";    # specify file by descriptor
        } else {
            # add leading space to protect against leading characters like '>'
            # in file name, and trailing "\0" to protect trailing spaces
            $file = " $file\0";
        }
    }
    return open $fh, "$mode$file";
}

#------------------------------------------------------------------------------
# Check to see if a file exists (with Windows Unicode support)
# Inputs: 0) ExifTool ref, 1) file name
# Returns: true if file exists
sub Exists($$)
{
    my ($self, $file) = @_;

    if ($self->EncodeFileName($file)) {
        local $SIG{'__WARN__'} = \&SetWarning;
        my $wh = eval { Win32API::File::CreateFileW($file,
                        Win32API::File::GENERIC_READ(), 0, [],
                        Win32API::File::OPEN_EXISTING(), 0, []) };
        return 0 unless $wh;
        eval { Win32API::File::CloseHandle($wh) };
    } else {
        return -e $file;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Return true if file is a directory (with Windows Unicode support)
# Inputs: 0) ExifTool ref, 1) file name
# Returns: true if file is a directory (false if file isn't, or doesn't exist)
sub IsDirectory($$)
{
    my ($et, $file) = @_;
    if ($et->EncodeFileName($file)) {
        local $SIG{'__WARN__'} = \&SetWarning;
        my $attrs = eval { Win32API::File::GetFileAttributesW($file) };
        my $dirBit = eval { Win32API::File::FILE_ATTRIBUTE_DIRECTORY() } || 0;
        return 1 if $attrs and $attrs != 0xffffffff and $attrs & $dirBit;
    } else {
        return -d $file;
    }
    return 0;
}

#------------------------------------------------------------------------------
# Get file times (Unix seconds since the epoch)
# Inputs: 0) ExifTool ref, 1) file name or ref
# Returns: 0) access time, 1) modification time, 2) creation time (or undefs on error)
my $k32GetFileTime;
sub GetFileTime($$)
{
    my ($self, $file) = @_;

    # open file by name if necessary
    unless (ref $file) {
        local *FH;
        $self->Open(\*FH, $file) or $self->Warn("GetFileTime error for '${file}'"), return ();
        $file = *FH;  # (not \*FH, so *FH will be kept open until $file goes out of scope)
    }
    # on Windows, try to work around incorrect file times when daylight saving time is in effect
    if ($^O eq 'MSWin32') {
        if (not eval { require Win32::API }) {
            $self->WarnOnce('Install Win32::API for proper handling of Windows file times');
        } elsif (not eval { require Win32API::File }) {
            $self->WarnOnce('Install Win32API::File for proper handling of Windows file times');
        } else {
            # get Win32 handle, needed for GetFileTime
            my $win32Handle = eval { Win32API::File::GetOsFHandle($file) };
            unless ($win32Handle) {
                $self->Warn("Win32API::File::GetOsFHandle returned invalid handle");
                return ();
            }
            # get FILETIME structs
            my ($atime, $mtime, $ctime, $time);
            $atime = $mtime = $ctime = pack 'LL', 0, 0;
            unless ($k32GetFileTime) {
                return () if defined $k32GetFileTime;
                $k32GetFileTime = new Win32::API('KERNEL32', 'GetFileTime', 'NPPP', 'I');
                unless ($k32GetFileTime) {
                    $self->Warn('Error calling Win32::API::GetFileTime');
                    $k32GetFileTime = 0;
                    return ();
                }
            }
            unless ($k32GetFileTime->Call($win32Handle, $ctime, $atime, $mtime)) {
                $self->Warn("Win32::API::GetFileTime returned " . Win32::GetLastError());
                return ();
            }
            # convert FILETIME structs to Unix seconds
            foreach $time ($atime, $mtime, $ctime) {
                my ($lo, $hi) = unpack 'LL', $time; # unpack FILETIME struct
                # FILETIME is in 100 ns intervals since 0:00 UTC Jan 1, 1601
                # (89 leap years between 1601 and 1970)
                $time = ($hi * 4294967296 + $lo) * 1e-7 - (((1970-1601)*365+89)*24*3600);
            }
            return ($atime, $mtime, $ctime);
        }
    }
    # other os (or Windows fallback)
    return (stat $file)[8, 9, 10];
}

#------------------------------------------------------------------------------
# Parse function arguments and set member variables accordingly
# Inputs: Same as ImageInfo()
# - sets REQUESTED_TAGS, REQ_TAG_LOOKUP, IO_TAG_LIST, FILENAME, RAF, OPTIONS
sub ParseArguments($;@)
{
    my $self = shift;
    my $options = $$self{OPTIONS};
    my @oldGroupOpts = grep /^Group/, keys %{$$self{OPTIONS}};
    my (@exclude, $wasExcludeOpt);

    $$self{REQUESTED_TAGS}  = [ ];
    $$self{REQ_TAG_LOOKUP}  = { };
    $$self{EXCL_TAG_LOOKUP} = { };
    $$self{IO_TAG_LIST} = undef;

    # handle our input arguments
    while (@_) {
        my $arg = shift;
        if (ref $arg) {
            if (ref $arg eq 'ARRAY') {
                $$self{IO_TAG_LIST} = $arg;
                foreach (@$arg) {
                    if (/^-(.*)/) {
                        push @exclude, $1;
                    } else {
                        push @{$$self{REQUESTED_TAGS}}, $_;
                    }
                }
            } elsif (ref $arg eq 'HASH') {
                my $opt;
                foreach $opt (keys %$arg) {
                    # a single new group option overrides all old group options
                    if (@oldGroupOpts and $opt =~ /^Group/) {
                        foreach (@oldGroupOpts) {
                            delete $$options{$_};
                        }
                        undef @oldGroupOpts;
                    }
                    $self->Options($opt, $$arg{$opt});
                    $opt eq 'Exclude' and $wasExcludeOpt = 1;
                }
            } elsif (ref $arg eq 'SCALAR' or UNIVERSAL::isa($arg,'GLOB')) {
                next if defined $$self{RAF};
                # convert image data from UTF-8 to character stream if necessary
                # (patches RHEL 3 UTF8 LANG problem)
                if (ref $arg eq 'SCALAR' and $] >= 5.006 and
                    (eval { require Encode; Encode::is_utf8($$arg) } or $@))
                {
                    # repack by hand if Encode isn't available
                    my $buff = $@ ? pack('C*',unpack($] < 5.010000 ? 'U0C*' : 'C0C*',$$arg)) : Encode::encode('utf8',$$arg);
                    $arg = \$buff;
                }
                $$self{RAF} = new File::RandomAccess($arg);
                # set filename to empty string to indicate that
                # we have a file but we didn't open it
                $$self{FILENAME} = '';
            } elsif (UNIVERSAL::isa($arg, 'File::RandomAccess')) {
                $$self{RAF} = $arg;
                $$self{FILENAME} = '';
            } else {
                warn "Don't understand ImageInfo argument $arg\n";
            }
        } elsif (defined $$self{FILENAME}) {
            if ($arg =~ /^-(.*)/) {
                push @exclude, $1;
            } else {
                push @{$$self{REQUESTED_TAGS}}, $arg;
            }
        } else {
            $$self{FILENAME} = $arg;
        }
    }
    # add additional requested tags to lookup
    if ($$options{RequestTags}) {
        $$self{REQ_TAG_LOOKUP}{$_} = 1 foreach @{$$options{RequestTags}};
    }
    # expand shortcuts in tag arguments if provided
    if (@{$$self{REQUESTED_TAGS}}) {
        ExpandShortcuts($$self{REQUESTED_TAGS});
        # initialize lookup for requested tags
        foreach (@{$$self{REQUESTED_TAGS}}) {
            /^(.*:)?([-\w?*]*)#?$/ or next;
            $$self{REQ_TAG_LOOKUP}{lc($2)} = 1 if $2;
            next unless $1;
            $$self{REQ_TAG_LOOKUP}{lc($_).':'} = 1 foreach split /:/, $1;
        }
    }
    if (@exclude or $wasExcludeOpt) {
        # must add existing excluded tags
        push @exclude, @{$$options{Exclude}} if $$options{Exclude};
        $$options{Exclude} = \@exclude;
        # expand shortcuts in new exclude list
        ExpandShortcuts($$options{Exclude}, 1); # (also remove '#' suffix)
    }
    # generate lookup for excluded tags
    if ($$options{Exclude}) {
        foreach (@{$$options{Exclude}}) {
            /([-\w]+)#?$/ and $$self{EXCL_TAG_LOOKUP}{lc($1)} = 1;
        }
        # exclude list is used only for EXCL_TAG_LOOKUP when TAGS_FROM_FILE is set
        undef $$options{Exclude} if $$self{TAGS_FROM_FILE};
    }
}

#------------------------------------------------------------------------------
# Get list of tags in specified group
# Inputs: 0) ExifTool ref, 1) group spec, 2) tag key or reference to list of tag keys
# Returns: list of matching tags in list context, or first match in scalar context
# Notes: Group spec may contain multiple groups separated by colons, each
#        possibly with a leading family number
sub GroupMatches($$$)
{
    my ($self, $group, $tagList) = @_;
    $tagList = [ $tagList ] unless ref $tagList;
    my ($tag, @matches);
    if ($group =~ /:/) {
        # check each group name individually (eg. "Author:1IPTC")
        my @grps = split ':', lc $group;
        my (@fmys, $g);
        for ($g=0; $g<@grps; ++$g) {
            $fmys[$g] = $1 if $grps[$g] =~ s/^(\d+)//;
        }
        foreach $tag (@$tagList) {
            my @groups = $self->GetGroup($tag, -1);
            for ($g=0; $g<@grps; ++$g) {
                my $grp = $grps[$g];
                next if $grp eq '*' or $grp eq 'all';
                if (defined $fmys[$g]) {
                    my $f = $fmys[$g];
                    last unless $groups[$f] and $grps[$g] eq lc $groups[$f];
                } else {
                    last unless grep /^$grps[$g]$/i, @groups;
                }
            }
            if ($g == @grps) {
                return $tag unless wantarray;
                push @matches, $tag;
            }
        }
    } else {
        my $family = ($group =~ s/^(\d+)//) ? $1 : -1;
        foreach $tag (@$tagList) {
            my @groups = $self->GetGroup($tag, $family);
            if (grep(/^$group$/i, @groups)) {
                return $tag unless wantarray;
                push @matches, $tag;
            }
        }
    }
    return wantarray ? @matches : $matches[0];
}

#------------------------------------------------------------------------------
# Remove specified tags from returned tag list, updating indices in other lists
# Inputs: 0) tag list ref, 1) index list ref, 2) index list ref, 3) hash ref,
#         4) true to include tags from hash instead of excluding
# Returns: nothing, but updates input lists
sub RemoveTagsFromList($$$$;$)
{
    local $_;
    my ($tags, $list1, $list2, $exclude, $inv) = @_;
    my @filteredTags;

    if (@$list1 or @$list2) {
        while (@$tags) {
            my $tag = pop @$tags;
            my $i = @$tags;
            if ($$exclude{$tag} xor $inv) {
                # remove index of excluded tag from each list
                @$list1 = map { $_ < $i ? $_ : $_ == $i ? () : $_ - 1 } @$list1;
                @$list2 = map { $_ < $i ? $_ : $_ == $i ? () : $_ - 1 } @$list2;
            } else {
                unshift @filteredTags, $tag;
            }
        }
    } else {
        foreach (@$tags) {
            push @filteredTags, $_ unless $$exclude{$_} xor $inv;
        }
    }
    $_[0] = \@filteredTags;     # update tag list
}

#------------------------------------------------------------------------------
# Set list of found tags from previously requested tags
# Inputs: 0) ExifTool object reference
# Returns: 0) Reference to list of found tag keys (in order of requested tags)
#          1) Reference to list of indices for tags requested by value
#          2) Reference to list of indices for tags specified by wildcard or "all"
# Notes: index lists are returned in increasing order
sub SetFoundTags($)
{
    my $self = shift;
    my $options = $$self{OPTIONS};
    my $reqTags = $$self{REQUESTED_TAGS} || [ ];
    my $duplicates = $$options{Duplicates};
    my $exclude = $$options{Exclude};
    my $fileOrder = $$self{FILE_ORDER};
    my @groupOptions = sort grep /^Group/, keys %$options;
    my $doDups = $duplicates || $exclude || @groupOptions;
    my ($tag, $rtnTags, @byValue, @wildTags);

    # only return requested tags if specified
    if (@$reqTags) {
        $rtnTags or $rtnTags = [ ];
        # scan through the requested tags and generate a list of tags we found
        my $tagHash = $$self{VALUE};
        my $reqTag;
        foreach $reqTag (@$reqTags) {
            my (@matches, $group, $allGrp, $allTag, $byValue);
            if ($reqTag =~ /^(.*):(.+)/) {
                ($group, $tag) = ($1, $2);
                if ($group =~ /^(\*|all)$/i) {
                    $allGrp = 1;
                } elsif ($group !~ /^[-\w:]*$/) {
                    $self->Warn("Invalid group name '${group}'");
                    $group = 'invalid';
                }
            } else {
                $tag = $reqTag;
            }
            $byValue = 1 if $tag =~ s/#$// and $$options{PrintConv};
            if (defined $$tagHash{$reqTag} and not $doDups) {
                $matches[0] = $tag;
            } elsif ($tag =~ /^(\*|all)$/i) {
                # tag name of '*' or 'all' matches all tags
                if ($doDups or $allGrp) {
                    @matches = grep(!/#/, keys %$tagHash);
                } else {
                    @matches = grep(!/ /, keys %$tagHash);
                }
                next unless @matches;   # don't want entry in list for '*' tag
                $allTag = 1;
            } elsif ($tag =~ /[*?]/) {
                # allow wildcards in tag names
                $tag =~ s/\*/[-\\w]*/g;
                $tag =~ s/\?/[-\\w]/g;
                $tag .= '( \\(.*)?' if $doDups or $allGrp;
                @matches = grep(/^$tag$/i, keys %$tagHash);
                next unless @matches;   # don't want entry in list for wildcard tags
                $allTag = 1;
            } elsif ($doDups or defined $group) {
                # must also look for tags like "Tag (1)"
                # (but be sure not to match temporary ValueConv entries like "Tag #")
                @matches = grep(/^$tag( \(|$)/i, keys %$tagHash);
            } elsif ($tag =~ /^[-\w]+$/) {
                # find first matching value
                # (use in list context to return value instead of count)
                ($matches[0]) = grep /^$tag$/i, keys %$tagHash;
                defined $matches[0] or undef @matches;
            } else {
                $self->Warn("Invalid tag name '${tag}'");
            }
            if (defined $group and not $allGrp) {
                # keep only specified group
                @matches = $self->GroupMatches($group, \@matches);
                next unless @matches or not $allTag;
            }
            if (@matches > 1) {
                # maintain original file order for multiple tags
                @matches = sort { $$fileOrder{$a} <=> $$fileOrder{$b} } @matches;
                # return only the highest priority tag unless duplicates wanted
                unless ($doDups or $allTag or $allGrp) {
                    $tag = shift @matches;
                    my $oldPriority = $$self{PRIORITY}{$tag} || 1;
                    foreach (@matches) {
                        my $priority = $$self{PRIORITY}{$_};
                        $priority = 1 unless defined $priority;
                        next unless $priority >= $oldPriority;
                        $tag = $_;
                        $oldPriority = $priority || 1;
                    }
                    @matches = ( $tag );
                }
            } elsif (not @matches) {
                # put entry in return list even without value (value is undef)
                $matches[0] = $byValue ? "$tag #(0)" : "$tag (0)";
                # bogus file order entry to avoid warning if sorting in file order
                $$self{FILE_ORDER}{$matches[0]} = 9999;
            }
            # save indices of tags extracted by value
            push @byValue, scalar(@$rtnTags) .. (scalar(@$rtnTags)+scalar(@matches)-1) if $byValue;
            # save indices of wildcard tags
            push @wildTags, scalar(@$rtnTags) .. (scalar(@$rtnTags)+scalar(@matches)-1) if $allTag;
            push @$rtnTags, @matches;
        }
    } else {
        # no requested tags, so we want all tags
        my @allTags;
        if ($doDups) {
            @allTags = keys %{$$self{VALUE}};
        } else {
            # only include tag if it doesn't end in a copy number
            @allTags = grep(!/ /, keys %{$$self{VALUE}});
        }
        $rtnTags = \@allTags;
    }

    # filter excluded tags and group options
    while (($exclude or @groupOptions) and @$rtnTags) {
        if ($exclude) {
            my ($pat, %exclude);
            foreach $pat (@$exclude) {
                my $group;
                if ($pat =~ /^(.*):(.+)/) {
                    ($group, $tag) = ($1, $2);
                    if ($group =~ /^(\*|all)$/i) {
                        undef $group;
                    } elsif ($group !~ /^[-\w:]*$/) {
                        $self->Warn("Invalid group name '${group}'");
                        $group = 'invalid';
                    }
                } else {
                    $tag = $pat;
                }
                my @matches;
                if ($tag =~ /^(\*|all)$/i) {
                    @matches = @$rtnTags;
                } else {
                    # allow wildcards in tag names
                    $tag =~ s/\*/[-\\w]*/g;
                    $tag =~ s/\?/[-\\w]/g;
                    @matches = grep(/^$tag( |$)/i, @$rtnTags);
                }
                @matches = $self->GroupMatches($group, \@matches) if $group and @matches;
                $exclude{$_} = 1 foreach @matches;
            }
            if (%exclude) {
                # remove excluded tags from return list(s)
                RemoveTagsFromList($rtnTags, \@byValue, \@wildTags, \%exclude);
                last unless @$rtnTags;      # all done if nothing left
            }
            last if $duplicates and not @groupOptions;
        }
        # filter groups if requested, or to remove duplicates
        my (%keepTags, %wantGroup, $family, $groupOpt);
        my $allGroups = 1;
        # build hash of requested/excluded group names for each group family
        my $wantOrder = 0;
        foreach $groupOpt (@groupOptions) {
            $groupOpt =~ /^Group(\d*(:\d+)*)/ or next;
            $family = $1 || 0;
            $wantGroup{$family} or $wantGroup{$family} = { };
            my $groupList;
            if (ref $$options{$groupOpt} eq 'ARRAY') {
                $groupList = $$options{$groupOpt};
            } else {
                $groupList = [ $$options{$groupOpt} ];
            }
            foreach (@$groupList) {
                # groups have priority in order they were specified
                ++$wantOrder;
                my ($groupName, $want);
                if (/^-(.*)/) {
                    # excluded group begins with '-'
                    $groupName = $1;
                    $want = 0;          # we don't want tags in this group
                } else {
                    $groupName = $_;
                    $want = $wantOrder; # we want tags in this group
                    $allGroups = 0;     # don't want all groups if we requested one
                }
                $wantGroup{$family}{$groupName} = $want;
            }
        }
        # loop through all tags and decide which ones we want
        my (@tags, %bestTag);
GR_TAG: foreach $tag (@$rtnTags) {
            my $wantTag = $allGroups;   # want tag by default if want all groups
            foreach $family (keys %wantGroup) {
                my $group = $self->GetGroup($tag, $family);
                my $wanted = $wantGroup{$family}{$group};
                next unless defined $wanted;
                next GR_TAG unless $wanted;     # skip tag if group excluded
                # take lowest non-zero want flag
                next if $wantTag and $wantTag < $wanted;
                $wantTag = $wanted;
            }
            next unless $wantTag;
            $duplicates and $keepTags{$tag} = 1, next;
            # determine which tag we want to keep
            my $tagName = GetTagName($tag);
            my $bestTag = $bestTag{$tagName};
            if (defined $bestTag) {
                next if $wantTag > $keepTags{$bestTag};
                if ($wantTag == $keepTags{$bestTag}) {
                    # want two tags with the same name -- keep the latest one
                    if ($tag =~ / \((\d+)\)$/) {
                        my $tagNum = $1;
                        next if $bestTag !~ / \((\d+)\)$/ or $1 > $tagNum;
                    }
                }
                # this tag is better, so delete old best tag
                delete $keepTags{$bestTag};
            }
            $keepTags{$tag} = $wantTag;     # keep this tag (for now...)
            $bestTag{$tagName} = $tag;      # this is our current best tag
        }
        # include only tags we want to keep in return lists
        RemoveTagsFromList($rtnTags, \@byValue, \@wildTags, \%keepTags, 1);
        last;
    }
    $$self{FOUND_TAGS} = $rtnTags;      # save found tags

    # return reference to found tag keys (and list of indices of tags to extract by value)
    return wantarray ? ($rtnTags, \@byValue, \@wildTags) : $rtnTags;
}

#------------------------------------------------------------------------------
# Utility to load our write routines if required (called via AUTOLOAD)
# Inputs: 0) autoload function, 1-N) function arguments
# Returns: result of function or dies if function not available
sub DoAutoLoad(@)
{
    my $autoload = shift;
    my @callInfo = split(/::/, $autoload);
    my $file = 'Image/ExifTool/Write';

    return if $callInfo[$#callInfo] eq 'DESTROY';
    if (@callInfo == 4) {
        # load Image/ExifTool/WriteMODULE.pl
        $file .= "$callInfo[2].pl";
    } elsif ($callInfo[-1] eq 'ShiftTime') {
        $file = 'Image/ExifTool/Shift.pl';  # load Shift.pl
    } else {
        # load Image/ExifTool/Writer.pl
        $file .= 'r.pl';
    }
    # attempt to load the package
    eval { require $file } or die "Error while attempting to call $autoload\n$@\n";
    unless (defined &$autoload) {
        my @caller = caller(0);
        # reproduce Perl's standard 'undefined subroutine' message:
        die "Undefined subroutine $autoload called at $caller[1] line $caller[2]\n";
    }
    no strict 'refs';
    return &$autoload(@_);     # call the function
}

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Add warning tag
# Inputs: 0) ExifTool object reference, 1) warning message
#         2) true if minor (2 if behaviour changes when warning is ignored,
#            or 3 if warning shouldn't be issued when Validate option is used)
# Returns: true if warning tag was added
sub Warn($$;$)
{
    my ($self, $str, $ignorable) = @_;
    if ($ignorable) {
        return 0 if $$self{OPTIONS}{IgnoreMinorErrors};
        return 0 if $ignorable eq '3' and $$self{OPTIONS}{Validate};
        $str = $ignorable eq '2' ? "[Minor] $str" : "[minor] $str";
    }
    $self->FoundTag('Warning', $str);
    return 1;
}

#------------------------------------------------------------------------------
# Add warning tag only once per processed file
# Inputs: 0) ExifTool object reference, 1) warning message, 2) true if minor
# Returns: true if warning tag was added
sub WarnOnce($$;$)
{
    my ($self, $str, $ignorable) = @_;
    return 0 if $ignorable and $$self{OPTIONS}{IgnoreMinorErrors};
    unless ($$self{WARNED_ONCE}{$str}) {
        $self->Warn($str, $ignorable);
        $$self{WARNED_ONCE}{$str} = 1;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Add error tag
# Inputs: 0) ExifTool object reference, 1) error message, 2) true if minor
# Returns: true if error tag was added, otherwise warning was added
sub Error($$;$)
{
    my ($self, $str, $ignorable) = @_;
    if ($$self{DemoteErrors}) {
        $self->Warn($str) and ++$$self{DemoteErrors};
        return 1;
    } elsif ($ignorable) {
        $$self{OPTIONS}{IgnoreMinorErrors} and $self->Warn($str), return 0;
        $str = "[minor] $str";
    }
    $self->FoundTag('Error', $str);
    return 1;
}

#------------------------------------------------------------------------------
# Expand shortcuts
# Inputs: 0) reference to list of tags, 1) set to remove trailing '#'
# Notes: Handles leading '-' for excluded tags, trailing '#' for ValueConv,
#        multiple group names, and redirected tags
sub ExpandShortcuts($;$)
{
    my ($tagList, $removeSuffix) = @_;
    return unless $tagList and @$tagList;

    require Image::ExifTool::Shortcuts;

    # expand shortcuts
    my $suffix = $removeSuffix ? '' : '#';
    my @expandedTags;
    my ($entry, $tag, $excl);
    foreach $entry (@$tagList) {
        # skip things like options hash references in list
        if (ref $entry) {
            push @expandedTags, $entry;
            next;
        }
        # remove leading '-'
        ($excl, $tag) = $entry =~ /^(-?)(.*)/s;
        my ($post, @post, $pre, $v);
        # handle redirection
        if (not $excl and $tag =~ /(.+?)([-+]?[<>].+)/s) {
            ($tag, $post) = ($1, $2);
            if ($post =~ /^[-+]?>/ or $post !~ /\$/) {
                # expand shortcuts in postfix (rhs of redirection)
                my ($op, $p2, $t2) = ($post =~ /([-+]?[<>])(.+:)?(.+)/);
                $p2 = '' unless defined $p2;
                $v = ($t2 =~ s/#$//) ? $suffix : ''; # ValueConv suffix
                my ($match) = grep /^\Q$t2\E$/i, keys %Image::ExifTool::Shortcuts::Main;
                if ($match) {
                    foreach (@{$Image::ExifTool::Shortcuts::Main{$match}}) {
                        /^-/ and next;  # ignore excluded tags
                        if ($p2 and /(.+:)(.+)/) {
                            push @post, "$op$_$v";
                        } else {
                            push @post, "$op$p2$_$v";
                        }
                    }
                    next unless @post;
                    $post = shift @post;
                }
            }
        } else {
            $post = '';
        }
        # handle group names
        if ($tag =~ /(.+:)(.+)/) {
            ($pre, $tag) = ($1, $2);
        } else {
            $pre = '';
        }
        $v = ($tag =~ s/#$//) ? $suffix : '';   # ValueConv suffix
        # loop over all postfixes
        for (;;) {
            # expand the tag name
            my ($match) = grep /^\Q$tag\E$/i, keys %Image::ExifTool::Shortcuts::Main;
            if ($match) {
                if ($excl) {
                    # entry starts with '-', so exclude all tags in this shortcut
                    foreach (@{$Image::ExifTool::Shortcuts::Main{$match}}) {
                        /^-/ and next;  # ignore excluded exclude tags
                        # group of expanded tag takes precedence
                        if ($pre and /(.+:)(.+)/) {
                            push @expandedTags, "$excl$_";
                        } else {
                            push @expandedTags, "$excl$pre$_";
                        }
                    }
                } elsif (length $pre or length $post or $v) {
                    foreach (@{$Image::ExifTool::Shortcuts::Main{$match}}) {
                        /(-?)(.+:)?(.+)/;
                        if ($2) {
                            # group from expanded tag takes precedence
                            push @expandedTags, "$_$v$post";
                        } else {
                            push @expandedTags, "$1$pre$3$v$post";
                        }
                    }
                } else {
                    push @expandedTags, @{$Image::ExifTool::Shortcuts::Main{$match}};
                }
            } else {
                push @expandedTags, "$excl$pre$tag$v$post";
            }
            last unless @post;
            $post = shift @post;
        }
    }
    @$tagList = @expandedTags;
}

#------------------------------------------------------------------------------
# Add hash of Composite tags to our composites
# Inputs: 0) hash reference to table of Composite tags to add or module name,
#         1) override existing tag definition
sub AddCompositeTags($;$)
{
    local $_;
    my ($add, $override) = @_;
    my $module;
    unless (ref $add) {
        $module = $add;
        $add .= '::Composite';
        no strict 'refs';
        $add = \%$add;
    }
    my $defaultGroups = $$add{GROUPS};
    my $compTable = GetTagTable('Image::ExifTool::Composite');

    # make sure default groups are defined in families 0 and 1
    if ($defaultGroups) {
        $$defaultGroups{0} or $$defaultGroups{0} = 'Composite';
        $$defaultGroups{1} or $$defaultGroups{1} = 'Composite';
        $$defaultGroups{2} or $$defaultGroups{2} = 'Other';
    } else {
        $defaultGroups = $$add{GROUPS} = { 0 => 'Composite', 1 => 'Composite', 2 => 'Other' };
    }
    SetupTagTable($add);    # generate Name, TagID, etc
    my $tagID;
    foreach $tagID (sort keys %$add) {
        next if $specialTags{$tagID};   # must skip special tags
        my $tagInfo = $$add{$tagID};
        # tagID's MUST be the exact tag name for logic in BuildCompositeTags()
        my $tag = $$tagInfo{Name};
        $$tagInfo{Module} = $module if $$tagInfo{Writable};
        $$tagInfo{Override} = 1 if $override and not defined $$tagInfo{Override};
        $$tagInfo{IsComposite} = 1;
        # allow Composite tags with the same name
        if ($$compTable{$tag}) {
            # determine if we want to override this tag
            # (=0 keep both, >0 override, <0 keep existing)
            my $over = ($$tagInfo{Override} || 0) - ($$compTable{$tag}{Override} || 0);
            next if $over < 0;
            my $n;
            my $new = $tag;
            while ($$compTable{$new}) {
                delete $$compTable{$new} if $over;  # delete existing entries
                $n = ($n || 1) + 1;
                $new = "${tag}-$n";
            }
            # use new ID and save it so we can use it in TagLookup
            $$tagInfo{NewTagID} = $tag = $new unless $over;
        }
        # convert scalar Require/Desire entries
        my $type;
        foreach $type ('Require','Desire') {
            my $req = $$tagInfo{$type} or next;
            $$tagInfo{$type} = { 0 => $req } if ref($req) ne 'HASH';
        }
        # add this Composite tag to our main Composite table
        $$tagInfo{Table} = $compTable;
        # (use the original TagID, even if we changed it, so don't do this:)
        # $$tagInfo{TagID} = $tag;
        # save tag under NewTagID in Composite table
        $$compTable{$tag} = $tagInfo;
        # set all default groups in tag
        my $groups = $$tagInfo{Groups};
        $groups or $groups = $$tagInfo{Groups} = { };
        # fill in default groups
        foreach (keys %$defaultGroups) {
            $$groups{$_} or $$groups{$_} = $$defaultGroups{$_};
        }
        # set flag indicating group list was built
        $$tagInfo{GotGroups} = 1;
    }
}

#------------------------------------------------------------------------------
# Add tags to TagLookup (used for writing)
# Inputs: 0) source hash of tag definitions, 1) name of destination tag table
sub AddTagsToLookup($$)
{
    my ($tagHash, $table) = @_;
    if (defined &Image::ExifTool::TagLookup::AddTags) {
        Image::ExifTool::TagLookup::AddTags($tagHash, $table);
    } elsif (not $Image::ExifTool::pluginTags{$tagHash}) {
        # queue these tags until TagLookup is loaded
        push @Image::ExifTool::pluginTags, [ $tagHash, $table ];
        # set flag so we don't load same tags twice
        $Image::ExifTool::pluginTags{$tagHash} = 1;
    }
}

#------------------------------------------------------------------------------
# Expand tagInfo Flags
# Inputs: 0) tagInfo hash ref
# Notes: $$tagInfo{Flags} must be defined to call this routine
sub ExpandFlags($)
{
    my $tagInfo = shift;
    my $flags = $$tagInfo{Flags};
    if (ref $flags eq 'ARRAY') {
        foreach (@$flags) {
            $$tagInfo{$_} = 1;
        }
    } elsif (ref $flags eq 'HASH') {
        my $key;
        foreach $key (keys %$flags) {
            $$tagInfo{$key} = $$flags{$key};
        }
    } else {
        $$tagInfo{$flags} = 1;
    }
}

#------------------------------------------------------------------------------
# Set up tag table (must be done once for each tag table used)
# Inputs: 0) Reference to tag table
# Notes: - generates 'Name' field from key if it doesn't exist
#        - stores 'Table' pointer and 'TagID' value
#        - expands 'Flags' for quick lookup
sub SetupTagTable($)
{
    my $tagTablePtr = shift;
    my $avoid = $$tagTablePtr{AVOID};
    my ($tagID, $tagInfo);
    foreach $tagID (TagTableKeys($tagTablePtr)) {
        my @infoArray = GetTagInfoList($tagTablePtr,$tagID);
        # process conditional tagInfo arrays
        foreach $tagInfo (@infoArray) {
            $$tagInfo{Table} = $tagTablePtr;
            $$tagInfo{TagID} = $tagID;
            $$tagInfo{Name} or $$tagInfo{Name} = MakeTagName($tagID);
            $$tagInfo{Flags} and ExpandFlags($tagInfo);
            $$tagInfo{Avoid} = $avoid if defined $avoid;
        }
        next unless @infoArray > 1;
        # add an "Index" member to each tagInfo in a list
        my $index = 0;
        foreach $tagInfo (@infoArray) {
            $$tagInfo{Index} = $index++;
        }
    }
}

#------------------------------------------------------------------------------
# Utilities to check for numerical types
# Inputs: 0) value;  Returns: true if value is a numerical type
# Notes: May change commas to decimals in floats for use in other locales
sub IsFloat($) {
    return 1 if $_[0] =~ /^[+-]?(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;
    # allow comma separators (for other locales)
    return 0 unless $_[0] =~ /^[+-]?(?=\d|,\d)\d*(,\d*)?([Ee]([+-]?\d+))?$/;
    $_[0] =~ tr/,/./;   # but translate ',' to '.'
    return 1;
}
sub IsInt($)      { return scalar($_[0] =~ /^[+-]?\d+$/); }
sub IsHex($)      { return scalar($_[0] =~ /^(0x)?[0-9a-f]{1,8}$/i); }
sub IsRational($) { return scalar($_[0] =~ m{^[-+]?\d+/\d+$}); }

# round floating point value to specified number of significant digits
# Inputs: 0) value, 1) number of sig digits;  Returns: rounded number
sub RoundFloat($$)
{
    my ($val, $sig) = @_;
    return sprintf("%.${sig}g", $val);
}

# Convert strings to floating point numbers (or undef)
# Inputs: 0-N) list of strings (may be undef)
# Returns: last value converted
sub ToFloat(@)
{
    local $_;
    foreach (@_) {
        next unless defined $_;
        # (add 0 to convert "0.0" to "0" for tests)
        $_ = /((?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee](?:[+-]?\d+))?)/ ? $1 + 0 : undef;
    }
    return $_[-1];
}

#------------------------------------------------------------------------------
# Utility routines to for reading binary data values from file

my %unpackMotorola = ( S => 'n', L => 'N', C => 'C', c => 'c' );
my %unpackIntel    = ( S => 'v', L => 'V', C => 'C', c => 'c' );
my %unpackRev = ( N => 'V', V => 'N', C => 'C', n => 'v', v => 'n', c => 'c' );

# the following 4 variables are defined in 'use vars' instead of using 'my'
# because mod_perl 5.6.1 apparently has a problem with setting file-scope 'my'
# variables from within subroutines (ref communication with Pavel Merdin):
# $swapBytes - set if EXIF header is not native byte ordering
# $swapWords - swap 32-bit words in doubles (ARM quirk)
$currentByteOrder = 'MM'; # current byte ordering ('II' or 'MM')
%unpackStd = %unpackMotorola;

# Swap bytes in data if necessary
# Inputs: 0) data, 1) number of bytes
# Returns: swapped data
sub SwapBytes($$)
{
    return $_[0] unless $swapBytes;
    my ($val, $bytes) = @_;
    my $newVal = '';
    $newVal .= substr($val, $bytes, 1) while $bytes--;
    return $newVal;
}
# Swap words.  Inputs: 8 bytes of data, Returns: swapped data
sub SwapWords($)
{
    return $_[0] unless $swapWords and length($_[0]) == 8;
    return substr($_[0],4,4) . substr($_[0],0,4)
}

# Unpack value, letting unpack() handle byte swapping
# Inputs: 0) unpack template, 1) data reference, 2) offset
# Returns: unpacked number
# - uses value of %unpackStd to determine the unpack template
# - can only be called for 'S' or 'L' templates since these are the only
#   templates for which you can specify the byte ordering.
sub DoUnpackStd(@)
{
    $_[2] and return unpack("x$_[2] $unpackStd{$_[0]}", ${$_[1]});
    return unpack($unpackStd{$_[0]}, ${$_[1]});
}
# same, but with reversed byte order
sub DoUnpackRev(@)
{
    my $fmt = $unpackRev{$unpackStd{$_[0]}};
    $_[2] and return unpack("x$_[2] $fmt", ${$_[1]});
    return unpack($fmt, ${$_[1]});
}
# Pack value
# Inputs: 0) template, 1) value, 2) data ref (or undef), 3) offset (if data ref)
# Returns: packed value
sub DoPackStd(@)
{
    my $val = pack($unpackStd{$_[0]}, $_[1]);
    $_[2] and substr(${$_[2]}, $_[3], length($val)) = $val;
    return $val;
}
# same, but with reversed byte order
sub DoPackRev(@)
{
    my $val = pack($unpackRev{$unpackStd{$_[0]}}, $_[1]);
    $_[2] and substr(${$_[2]}, $_[3], length($val)) = $val;
    return $val;
}

# Unpack value, handling the byte swapping manually
# Inputs: 0) # bytes, 1) unpack template, 2) data reference, 3) offset
# Returns: unpacked number
# - uses value of $swapBytes to determine byte ordering
sub DoUnpack(@)
{
    my ($bytes, $template, $dataPt, $pos) = @_;
    my $val;
    if ($swapBytes) {
        $val = '';
        $val .= substr($$dataPt,$pos+$bytes,1) while $bytes--;
    } else {
        $val = substr($$dataPt,$pos,$bytes);
    }
    defined($val) or return undef;
    return unpack($template,$val);
}

# Unpack double value
# Inputs: 0) unpack template, 1) data reference, 2) offset
# Returns: unpacked number
sub DoUnpackDbl(@)
{
    my ($template, $dataPt, $pos) = @_;
    my $val = substr($$dataPt,$pos,8);
    defined($val) or return undef;
    # swap bytes and 32-bit words (ARM quirk) if necessary, then unpack value
    return unpack($template, SwapWords(SwapBytes($val, 8)));
}

# Inputs: 0) data reference, 1) offset into data
sub Get8s($$)     { return DoUnpackStd('c', @_); }
sub Get8u($$)     { return DoUnpackStd('C', @_); }
sub Get16s($$)    { return DoUnpack(2, 's', @_); }
sub Get16u($$)    { return DoUnpackStd('S', @_); }
sub Get32s($$)    { return DoUnpack(4, 'l', @_); }
sub Get32u($$)    { return DoUnpackStd('L', @_); }
sub GetFloat($$)  { return DoUnpack(4, 'f', @_); }
sub GetDouble($$) { return DoUnpackDbl('d', @_); }
sub Get16uRev($$) { return DoUnpackRev('S', @_); }
sub Get32uRev($$) { return DoUnpackRev('L', @_); }

# rationals may be a floating point number, 'inf' or 'undef'
my ($ratNumer, $ratDenom);
sub GetRational32s($$)
{
    my ($dataPt, $pos) = @_;
    $ratNumer = Get16s($dataPt,$pos);
    $ratDenom = Get16s($dataPt, $pos + 2) or return $ratNumer ? 'inf' : 'undef';
    # round off to a reasonable number of significant figures
    return RoundFloat($ratNumer / $ratDenom, 7);
}
sub GetRational32u($$)
{
    my ($dataPt, $pos) = @_;
    $ratNumer = Get16u($dataPt,$pos);
    $ratDenom = Get16u($dataPt, $pos + 2) or return $ratNumer ? 'inf' : 'undef';
    return RoundFloat($ratNumer / $ratDenom, 7);
}
sub GetRational64s($$)
{
    my ($dataPt, $pos) = @_;
    $ratNumer = Get32s($dataPt,$pos);
    $ratDenom = Get32s($dataPt, $pos + 4) or return $ratNumer ? 'inf' : 'undef';
    return RoundFloat($ratNumer / $ratDenom, 10);
}
sub GetRational64u($$)
{
    my ($dataPt, $pos) = @_;
    $ratNumer = Get32u($dataPt,$pos);
    $ratDenom = Get32u($dataPt, $pos + 4) or return $ratNumer ? 'inf' : 'undef';
    return RoundFloat($ratNumer / $ratDenom, 10);
}
sub GetFixed16s($$)
{
    my ($dataPt, $pos) = @_;
    my $val = Get16s($dataPt, $pos) / 0x100;
    return int($val * 1000 + ($val<0 ? -0.5 : 0.5)) / 1000;
}
sub GetFixed16u($$)
{
    my ($dataPt, $pos) = @_;
    return int((Get16u($dataPt, $pos) / 0x100) * 1000 + 0.5) / 1000;
}
sub GetFixed32s($$)
{
    my ($dataPt, $pos) = @_;
    my $val = Get32s($dataPt, $pos) / 0x10000;
    # remove insignificant digits
    return int($val * 1e5 + ($val>0 ? 0.5 : -0.5)) / 1e5;
}
sub GetFixed32u($$)
{
    my ($dataPt, $pos) = @_;
    # remove insignificant digits
    return int((Get32u($dataPt, $pos) / 0x10000) * 1e5 + 0.5) / 1e5;
}
# Inputs: 0) value, 1) data ref, 2) offset
sub Set8s(@)  { return DoPackStd('c', @_); }
sub Set8u(@)  { return DoPackStd('C', @_); }
sub Set16u(@) { return DoPackStd('S', @_); }
sub Set32u(@) { return DoPackStd('L', @_); }
sub Set16uRev(@) { return DoPackRev('S', @_); }

#------------------------------------------------------------------------------
# Get current byte order ('II' or 'MM')
sub GetByteOrder() { return $currentByteOrder; }

#------------------------------------------------------------------------------
# Set byte ordering
# Inputs: 0) 'MM'=motorola, 'II'=intel (will translate 'BigEndian', 'LittleEndian')
# Returns: 1 on success
sub SetByteOrder($)
{
    my $order = shift;

    if ($order eq 'MM') {       # big endian (Motorola)
        %unpackStd = %unpackMotorola;
    } elsif ($order eq 'II') {  # little endian (Intel)
        %unpackStd = %unpackIntel;
    } elsif ($order =~ /^Big/i) {
        $order = 'MM';
        %unpackStd = %unpackMotorola;
    } elsif ($order =~ /^Little/i) {
        $order = 'II';
        %unpackStd = %unpackIntel;
    } else {
        return 0;
    }
    my $val = unpack('S','A ');
    my $nativeOrder;
    if ($val == 0x4120) {       # big endian
        $nativeOrder = 'MM';
    } elsif ($val == 0x2041) {  # little endian
        $nativeOrder = 'II';
    } else {
        warn sprintf("Unknown native byte order! (pattern %x)\n",$val);
        return 0;
    }
    $currentByteOrder = $order;  # save current byte order

    # swap bytes if our native CPU byte ordering is not the same as the EXIF
    $swapBytes = ($order ne $nativeOrder);

    # little-endian ARM has big-endian words for doubles (thanks Riku Voipio)
    # (Note: Riku's patch checked for '0ff3', but I think it should be 'f03f' since
    # 1 is '000000000000f03f' on an x86 -- so check for both, but which is correct?)
    my $pack1d = pack('d', 1);
    $swapWords = ($pack1d eq "\0\0\x0f\xf3\0\0\0\0" or
                  $pack1d eq "\0\0\xf0\x3f\0\0\0\0");
    return 1;
}

#------------------------------------------------------------------------------
# Change byte order
sub ToggleByteOrder()
{
    SetByteOrder(GetByteOrder() eq 'II' ? 'MM' : 'II');
}

#------------------------------------------------------------------------------
# hash lookups for reading values from data
my %formatSize = (
    int8s => 1,
    int8u => 1,
    int16s => 2,
    int16u => 2,
    int16uRev => 2,
    int32s => 4,
    int32u => 4,
    int32uRev => 4,
    int64s => 8,
    int64u => 8,
    rational32s => 4,
    rational32u => 4,
    rational64s => 8,
    rational64u => 8,
    fixed16s => 2,
    fixed16u => 2,
    fixed32s => 4,
    fixed32u => 4,
    fixed64s => 8,
    float => 4,
    double => 8,
    extended => 10,
    unicode => 2,
    complex => 8,
    string => 1,
    binary => 1,
   'undef' => 1,
    ifd => 4,
    ifd64 => 8,
    ue7 => 1,
);
my %readValueProc = (
    int8s => \&Get8s,
    int8u => \&Get8u,
    int16s => \&Get16s,
    int16u => \&Get16u,
    int16uRev => \&Get16uRev,
    int32s => \&Get32s,
    int32u => \&Get32u,
    int32uRev => \&Get32uRev,
    int64s => \&Get64s,
    int64u => \&Get64u,
    rational32s => \&GetRational32s,
    rational32u => \&GetRational32u,
    rational64s => \&GetRational64s,
    rational64u => \&GetRational64u,
    fixed16s => \&GetFixed16s,
    fixed16u => \&GetFixed16u,
    fixed32s => \&GetFixed32s,
    fixed32u => \&GetFixed32u,
    fixed64s => \&GetFixed64s,
    float => \&GetFloat,
    double => \&GetDouble,
    extended => \&GetExtended,
    ifd => \&Get32u,
    ifd64 => \&Get64u,
);
# lookup for all rational types
my %isRational = (
    rational32u => 1,
    rational32s => 1,
    rational64u => 1,
    rational64s => 1,
);
sub FormatSize($) { return $formatSize{$_[0]}; }

#------------------------------------------------------------------------------
# Read value from binary data (with current byte ordering)
# Inputs: 0) data reference, 1) value offset, 2) format string,
#         3) number of values (or undef to use all data)
#         4) valid data length relative to offset, 5) optional pointer to returned rational
# Returns: converted value, or undefined if data isn't there
#          or list of values in list context
sub ReadValue($$$$$;$)
{
    my ($dataPt, $offset, $format, $count, $size, $ratPt) = @_;

    my $len = $formatSize{$format};
    unless ($len) {
        warn "Unknown format $format";
        $len = 1;
    }
    unless ($count) {
        return '' if defined $count or $size < $len;
        $count = int($size / $len);
    }
    # make sure entry is inside data
    if ($len * $count > $size) {
        $count = int($size / $len);     # shorten count if necessary
        $count < 1 and return undef;    # return undefined if no data
    }
    my @vals;
    my $proc = $readValueProc{$format};
    if (not $proc) {
        # handle undef/binary/string (also unsupported unicode/complex)
        $vals[0] = substr($$dataPt, $offset, $count * $len);
        # truncate string at null terminator if necessary
        $vals[0] =~ s/\0.*//s if $format eq 'string';
    } elsif ($isRational{$format} and $ratPt) {
        # store rationals separately as string fractions
        my @rat;
        for (;;) {
            push @vals, &$proc($dataPt, $offset);
            push @rat, "$ratNumer/$ratDenom";
            last if --$count <= 0;
            $offset += $len;
        }
        $$ratPt = join(' ',@rat);
    } else {
        for (;;) {
            push @vals, &$proc($dataPt, $offset);
            last if --$count <= 0;
            $offset += $len;
        }
    }
    return @vals if wantarray;
    return join(' ', @vals) if @vals > 1;
    return $vals[0];
}

#------------------------------------------------------------------------------
# Decode string with specified encoding
# Inputs: 0) ExifTool object ref, 1) string to decode
#         2) source character set name (undef for current Charset)
#         3) optional source byte order (2-byte and 4-byte fixed-width sets only)
#         4) optional destination character set (defaults to Charset setting)
#         5) optional destination byte order (2-byte and 4-byte fixed-width only)
# Returns: string in destination encoding
# Note: ExifTool ref may be undef if character both character sets are provided
#       (but in this case no warnings will be issued)
sub Decode($$$;$$$)
{
    my ($self, $val, $from, $fromOrder, $to, $toOrder) = @_;
    $from or $from = $$self{OPTIONS}{Charset};
    $to or $to = $$self{OPTIONS}{Charset};
    if ($from ne $to and length $val) {
        require Image::ExifTool::Charset;
        my $cs1 = $Image::ExifTool::Charset::csType{$from};
        my $cs2 = $Image::ExifTool::Charset::csType{$to};
        if ($cs1 and $cs2 and not $cs2 & 0x002) {
            # treat as straight ASCII if no character will need remapping
            if (($cs1 | $cs2) & 0x680 or $val =~ /[\x80-\xff]/) {
                my $uni = Image::ExifTool::Charset::Decompose($self, $val, $from, $fromOrder);
                $val = Image::ExifTool::Charset::Recompose($self, $uni, $to, $toOrder);
            }
        } elsif ($self) {
            my $set = $cs1 ? $to : $from;
            unless ($$self{"DecodeWarn$set"}) {
                $self->Warn("Unsupported character set ($set)");
                $$self{"DecodeWarn$set"} = 1;
            }
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Encode string with specified encoding
# Inputs: 0) ExifTool object ref, 1) string, 2) destination character set name,
#         3) optional destination byte order (2-byte and 4-byte fixed-width sets only)
# Returns: string in specified encoding
sub Encode($$$;$)
{
    my ($self, $val, $to, $toOrder) = @_;
    return $self->Decode($val, undef, undef, $to, $toOrder);
}

#------------------------------------------------------------------------------
# Decode bit mask
# Inputs: 0) value to decode, 1) Reference to hash for decoding (or undef)
#         2) optional bits per word (defaults to 32)
sub DecodeBits($$;$)
{
    my ($vals, $lookup, $bits) = @_;
    $bits or $bits = 32;
    my ($val, $i, @bitList);
    my $num = 0;
    foreach $val (split ' ', $vals) {
        for ($i=0; $i<$bits; ++$i) {
            next unless $val & (1 << $i);
            my $n = $i + $num;
            if (not $lookup) {
                push @bitList, $n;
            } elsif ($$lookup{$n}) {
                push @bitList, $$lookup{$n};
            } else {
                push @bitList, "[$n]";
            }
        }
        $num += $bits;
    }
    return '(none)' unless @bitList;
    return join($lookup ? ', ' : ',', @bitList);
}

#------------------------------------------------------------------------------
# Validate an extracted image and repair if necessary
# Inputs: 0) ExifTool object reference, 1) image reference, 2) tag name or key
# Returns: image reference or undef if it wasn't valid
# Note: should be called from RawConv, not ValueConv
sub ValidateImage($$$)
{
    my ($self, $imagePt, $tag) = @_;
    return undef if $$imagePt eq 'none';
    unless ($$imagePt =~ /^(Binary data|\xff\xd8\xff)/ or
            # the first byte of the preview of some Minolta cameras is wrong,
            # so check for this and set it back to 0xff if necessary
            $$imagePt =~ s/^.(\xd8\xff\xdb)/\xff$1/s or
            $self->Options('IgnoreMinorErrors'))
    {
        # issue warning only if the tag was specifically requested
        if ($$self{REQ_TAG_LOOKUP}{lc GetTagName($tag)}) {
            $self->Warn("$tag is not a valid JPEG image",1);
            return undef;
        }
    }
    return $imagePt;
}

#------------------------------------------------------------------------------
# Validate a tag name argument (including group name and wildcards, etc)
# Inputs: 0) tag name
# Returns: true if tag name is valid
# - a tag name may contain [-_A-Za-z0-9], but may not start with [-0-9]
# - tag names may contain wildcards [?*], and end with a hash [#]
# - may have group name prefixes (which may have family number prefix), separated by colons
# - a group name may be zero or more characters
sub ValidTagName($)
{
    my $tag = shift;
    return $tag =~ /^(([-\w]*|\d*\*):)*[_a-zA-Z?*][-\w?*]*#?$/;
}

#------------------------------------------------------------------------------
# Generate a valid tag name based on the tag ID or name
# Inputs: 0) tag ID or name
# Returns: valid tag name
sub MakeTagName($)
{
    my $name = shift;
    $name =~ tr/-_a-zA-Z0-9//dc;    # remove illegal characters
    $name = ucfirst $name;          # capitalize first letter
    $name = "Tag$name" if length($name) < 2; # must at least 2 characters long
    return $name;
}

#------------------------------------------------------------------------------
# Make description from a tag name
# Inputs: 0) tag name 1) optional tagID to add at end of description
# Returns: description
sub MakeDescription($;$)
{
    my ($tag, $tagID) = @_;
    # start with the tag name and force first letter to be upper case
    my $desc = ucfirst($tag);
    # translate underlines to spaces
    $desc =~ tr/_/ /;
    # remove hex TagID from name (to avoid inserting spaces in the number)
    $desc =~ s/ (0x[\da-f]+)$//i and $tagID = $1 unless defined $tagID;
    # put a space between lower/UPPER case and lower/number combinations
    $desc =~ s/([a-z])([A-Z\d])/$1 $2/g;
    # put a space between acronyms and words
    $desc =~ s/([A-Z])([A-Z][a-z])/$1 $2/g;
    # put spaces after numbers (if more than one character follows the number)
    $desc =~ s/(\d)([A-Z]\S)/$1 $2/g;
    # add TagID to description
    $desc .= ' ' . $tagID if defined $tagID;
    return $desc;
}

#------------------------------------------------------------------------------
# Get descriptions for all tags in an array
# Inputs: 0) ExifTool ref, 1) reference to list of tag keys
# Returns: reference to hash lookup for descriptions
# Note: Returned descriptions are NOT escaped by ESCAPE_PROC
sub GetDescriptions($$)
{
    local $_;
    my ($self, $tags) = @_;
    my %desc;
    my $oldEscape = $$self{ESCAPE_PROC};
    delete $$self{ESCAPE_PROC};
    $desc{$_} = $self->GetDescription($_) foreach @$tags;
    $$self{ESCAPE_PROC} = $oldEscape;
    return \%desc;
}

#------------------------------------------------------------------------------
# Apply filter to value(s) if necessary
# Inputs: 0) ExifTool ref, 1-N) references to values(s) to filter
# Returns: nothing, but changes values if necessary
sub Filter($@)
{
    local $_;
    my $self = shift;
    return unless defined $$self{OPTIONS}{Filter};
    while (@_) {
        my $valPt = shift;
        next unless defined $$valPt;
        if (not ref $$valPt) {
            $_ = $$valPt;
            #### eval Filter ($_)
            eval $$self{OPTIONS}{Filter};
            $$valPt = $_ if defined $_;
        } elsif (ref $$valPt eq 'SCALAR') {
            my $val = $$$valPt; # make a copy to avoid filtering twice
            $self->Filter(\$val);
            $$valPt = \$val;
        } elsif (ref $$valPt eq 'ARRAY') {
            my @val = @{$$valPt}; # make a copy to avoid filtering twice
            $self->Filter(\$_) foreach @val;
            $$valPt = \@val;
        } elsif (ref $$valPt eq 'HASH') {
            my %val = %{$$valPt}; # make a copy to avoid filtering twice
            $self->Filter(\$val{$_}) foreach keys %val;
            $$valPt = \%val;
        }
    }
}

#------------------------------------------------------------------------------
# Return printable value
# Inputs: 0) ExifTool object reference
#         1) value to print, 2) line length limit (undef defaults to 60, 0=unlimited)
sub Printable($;$)
{
    my ($self, $outStr, $maxLen) = @_;
    return '(undef)' unless defined $outStr;
    $outStr =~ tr/\x01-\x1f\x7f-\xff/./;
    $outStr =~ s/\x00//g;
    my $verbose = $$self{OPTIONS}{Verbose};
    if ($verbose < 4) {
        if ($maxLen) {
            $maxLen = 20 if $maxLen < 20;   # minimum length is 20
        } elsif (defined $maxLen) {
            $maxLen = length $outStr;       # 0 is unlimited
        } else {
            $maxLen = 60;                   # default maximum is 60
        }
    } else {
        $maxLen = length $outStr;
        # limit to 2048 characters if verbose < 5
        $maxLen = 2048 if $maxLen > 2048 and $verbose < 5;
    }

    # limit length if necessary
    $outStr = substr($outStr,0,$maxLen-6) . '[snip]' if length($outStr) > $maxLen;
    return $outStr;
}

#------------------------------------------------------------------------------
# Convert date/time from Exif format
# Inputs: 0) ExifTool object reference, 1) Date/time in EXIF format
# Returns: Formatted date/time string
sub ConvertDateTime($$)
{
    my ($self, $date) = @_;
    my $fmt = $$self{OPTIONS}{DateFormat};
    my $shift = $$self{OPTIONS}{GlobalTimeShift};
    if ($shift) {
        my $dir = ($shift =~ s/^([-+])// and $1 eq '-') ? -1 : 1;
        my $offset = $$self{GLOBAL_TIME_OFFSET};
        $offset or $offset = $$self{GLOBAL_TIME_OFFSET} = { };
        ShiftTime($date, $shift, $dir, $offset);
    }
    # only convert date if a format was specified and the date is recognizable
    if ($fmt) {
        # separate time zone if it exists
        my $tz;
        $date =~ s/([-+]\d{2}:\d{2}|Z)$// and $tz = $1;
        # a few cameras use incorrect date/time formatting:
        # - slashes instead of colons in date (RolleiD330, ImpressCam)
        # - date/time values separated by colon instead of space (Polariod, Sanyo, Sharp, Vivitar)
        # - single-digit seconds with leading space (HP scanners)
        my @a = reverse ($date =~ /\d+/g);  # be very flexible about date/time format
        if (@a and $a[-1] >= 1000 and $a[-1] < 3000 and eval { require POSIX }) {
            shift @a while @a > 6;      # remove superfluous entries
            unshift @a, 1 while @a < 3; # add month and day if necessary
            unshift @a, 0 while @a < 6; # add h,m,s if necessary
            $a[5] -= 1900;              # base year is 1900
            $a[4] -= 1;                 # base month is 1
            # parse %z and %s ourself (to handle time zones properly)
            if ($fmt =~ /%[sz]/) {
                # use system time zone unless otherwise specified
                $tz = TimeZoneString(\@a, TimeLocal(@a)) if not $tz and eval { require Time::Local };
                # remove colon, setting to UTC if time zone is not numeric
                $tz = ($tz and $tz=~/^([-+]\d{2}):(\d{2})$/) ? "$1$2" : '+0000';
                $fmt =~ s/(^|[^%])((%%)*)%z/$1$2$tz/g;      # convert '%z' format codes
                if ($fmt =~ /%s/ and eval { require Time::Local }) {
                    # calculate seconds since the Epoch, UTC
                    my $s = Time::Local::timegm(@a) - 60 * ($tz - int($tz/100) * 40);
                    $fmt =~ s/(^|[^%])((%%)*)%s/$1$2$s/g;   # convert '%s' format codes
                }
            }
            $date = POSIX::strftime($fmt, @a);  # generate the formatted date/time
        } elsif ($$self{OPTIONS}{StrictDate}) {
            undef $date;
        }
    }
    return $date;
}

#------------------------------------------------------------------------------
# Print conversion for time span value
# Inputs: 0) time ticks, 1) number of seconds per tick (default 1)
# Returns: readable time
sub ConvertTimeSpan($;$)
{
    my ($val, $mult) = @_;
    if (Image::ExifTool::IsFloat($val) and $val != 0) {
        $val *= $mult if $mult;
        if ($val < 60) {
            $val = "$val seconds";
        } elsif ($val < 3600) {
            my $fmt = ($mult and $mult >= 60) ? '%d' : '%.1f';
            my $s = ($val == 60 and $mult) ? '' : 's';
            $val = sprintf("$fmt minute$s", $val / 60);
        } elsif ($val < 24 * 3600) {
            $val = sprintf("%.1f hours", $val / 3600);
        } else {
            $val = sprintf("%.1f days", $val / (24 * 3600));
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Patched timelocal() that fixes ActivePerl timezone bug
# Inputs/Returns: same as timelocal()
# Notes: must 'require Time::Local' before calling this routine
sub TimeLocal(@)
{
    my $tm = Time::Local::timelocal(@_);
    if ($^O eq 'MSWin32') {
        # patch for ActivePerl timezone bug
        my @t2 = localtime($tm);
        my $t2 = Time::Local::timelocal(@t2);
        # adjust timelocal() return value to be consistent with localtime()
        $tm += $tm - $t2;
    }
    return $tm;
}

#------------------------------------------------------------------------------
# Get time zone in minutes
# Inputs: 0) localtime array ref, 1) gmtime array ref
# Returns: time zone offset in minutes
sub GetTimeZone($$)
{
    my ($tm, $gm) = @_;
    # compute the number of minutes between localtime and gmtime
    my $min = $$tm[2] * 60 + $$tm[1] - ($$gm[2] * 60 + $$gm[1]);
    if ($$tm[3] != $$gm[3]) {
        # account for case where one date wraps to the first of the next month
        $$gm[3] = $$tm[3] - ($$tm[3]==1 ? 1 : -1) if abs($$tm[3]-$$gm[3]) != 1;
        # adjust for the +/- one day difference
        $min += ($$tm[3] - $$gm[3]) * 24 * 60;
    }
    # MirBSD patch to round to the nearest 30 minutes because
    # it includes leap seconds in localtime but not gmtime
    $min = int($min / 30 + ($min > 0 ? 0.5 : -0.5)) * 30 if $^O eq 'mirbsd';
    return $min;
}

#------------------------------------------------------------------------------
# Get time zone string
# Inputs: 0) time zone offset in minutes
#     or  0) localtime array ref, 1) corresponding time value
# Returns: time zone string ("+/-HH:MM")
sub TimeZoneString($;$)
{
    my $min = shift;
    if (ref $min) {
        my @gm = gmtime(shift);
        $min = GetTimeZone($min, \@gm);
    }
    my $sign = '+';
    $min < 0 and $sign = '-', $min = -$min;
    my $h = int($min / 60);
    return sprintf('%s%.2d:%.2d', $sign, $h, $min - $h * 60);
}

#------------------------------------------------------------------------------
# Convert Unix time to EXIF date/time string
# Inputs: 0) Unix time value, 1) non-zero to convert to local time
# Returns: EXIF date/time string (with timezone for local times)
# Notes: fractional seconds are ignored
sub ConvertUnixTime($;$)
{
    my ($time, $toLocal) = @_;
    return '0000:00:00 00:00:00' if $time == 0;
    $time = int($time + 1e-6) if $time != int($time);  # avoid round-off errors
    my (@tm, $tz);
    if ($toLocal) {
        @tm = localtime($time);
        $tz = TimeZoneString(\@tm, $time);
    } else {
        @tm = gmtime($time);
        $tz = '';
    }
    my $str = sprintf("%4d:%.2d:%.2d %.2d:%.2d:%.2d%s",
                      $tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0], $tz);
    return $str;
}

#------------------------------------------------------------------------------
# Get Unix time from EXIF-formatted date/time string with optional timezone
# Inputs: 0) EXIF date/time string, 1) non-zero if time is local
# Returns: Unix time (seconds since 0:00 GMT Jan 1, 1970) or undefined on error
sub GetUnixTime($;$)
{
    my ($timeStr, $isLocal) = @_;
    return 0 if $timeStr eq '0000:00:00 00:00:00';
    my @tm = ($timeStr =~ /^(\d+):(\d+):(\d+)\s+(\d+):(\d+):(\d+)/);
    return undef unless @tm == 6 and eval { require Time::Local };
    my $tzsec = 0;
    # use specified timezone offset (if given) instead of local system time
    # if we are converting a local time value
    if ($isLocal and $timeStr =~ /(?:Z|([-+])(\d+):(\d+))$/i) {
        # use specified timezone if one exists
        $tzsec = ($2 * 60 + $3) * ($1 eq '-' ? -60 : 60) if $1;
        undef $isLocal; # convert using GMT corrected for specified timezone
    }
    $tm[0] -= 1900;     # convert year
    $tm[1] -= 1;        # convert month
    @tm = reverse @tm;  # change to order required by timelocal()
    return $isLocal ? TimeLocal(@tm) : Time::Local::timegm(@tm) - $tzsec;
}

#------------------------------------------------------------------------------
# Print conversion for file size
# Inputs: 0) file size in bytes
# Returns: converted file size
sub ConvertFileSize($)
{
    my $val = shift;
    $val < 2048 and return "$val bytes";
    $val < 10240 and return sprintf('%.1f kB', $val / 1024);
    $val < 2097152 and return sprintf('%.0f kB', $val / 1024);
    $val < 10485760 and return sprintf('%.1f MB', $val / 1048576);
    $val < 2147483648 and return sprintf('%.0f MB', $val / 1048576);
    $val < 10737418240 and return sprintf('%.1f GB', $val / 1073741824);
    return sprintf('%.0f GB', $val / 1073741824);
}

#------------------------------------------------------------------------------
# Convert seconds to duration string (handles negative durations)
# Inputs: 0) floating point seconds
# Returns: duration string in form "S.SS s", "MM:SS" or "H:MM:SS"
sub ConvertDuration($)
{
    my $time = shift;
    return $time unless IsFloat($time);
    return '0 s' if $time == 0;
    my $sign = ($time > 0 ? '' : (($time = -$time), '-'));
    return sprintf("$sign%.2f s", $time) if $time < 30;
    my $h = int($time / 3600);
    $time -= $h * 3600;
    my $m = int($time / 60);
    $time -= $m * 60;
    if ($h > 24) {
        my $d = int($h / 24);
        $h -= $d * 24;
        $sign = "$sign$d days ";
    }
    return sprintf("$sign%d:%.2d:%.2d", $h, $m, int($time));
}

#------------------------------------------------------------------------------
# Print conversion for bitrate values
# Inputs: 0) bitrate in bits per second
# Returns: human-readable bitrate string
# Notes: returns input value without formatting if it isn't numerical
sub ConvertBitrate($)
{
    my $bitrate = shift;
    IsFloat($bitrate) or return $bitrate;
    my @units = ('bps', 'kbps', 'Mbps', 'Gbps');
    for (;;) {
        my $units = shift @units;
        $bitrate >= 1000 and @units and $bitrate /= 1000, next;
        my $fmt = $bitrate < 100 ? '%.3g' : '%.0f';
        return sprintf("$fmt $units", $bitrate);
    }
}

#------------------------------------------------------------------------------
# Convert file name for printing
# Inputs: 0) ExifTool ref, 1) file name in CharsetFileName character set
# Returns: converted file name in external character set
sub ConvertFileName($$)
{
    my ($self, $val) = @_;
    my $enc = $$self{OPTIONS}{CharsetFileName};
    $val = $self->Decode($val, $enc) if $enc;
    return $val;
}

#------------------------------------------------------------------------------
# Inverse conversion for file name (encode in CharsetFileName)
# Inputs: 0) ExifTool ref, 1) file name in external character set
# Returns: file name in CharsetFileName character set
sub InverseFileName($$)
{
    my ($self, $val) = @_;
    my $enc = $$self{OPTIONS}{CharsetFileName};
    $val = $self->Encode($val, $enc) if $enc;
    $val =~ tr/\\/\//;  # make sure we are using forward slashes
    return $val;
}

#------------------------------------------------------------------------------
# Save information for HTML dump
# Inputs: 0) ExifTool hash ref, 1) start offset, 2) data size
#         3) comment string, 4) tool tip (or SAME), 5) flags
sub HDump($$$$;$$)
{
    my $self = shift;
    $$self{HTML_DUMP} or return;
    my ($pos, $len, $com, $tip, $flg) = @_;
    $pos += $$self{BASE} if $$self{BASE};
    # skip structural data blocks which have been removed from the middle of this dump
    # (SkipData list contains ordered [start,end+1] offsets to skip)
    if ($$self{SkipData}) {
        my $end = $pos + $len;
        my $skip;
        foreach $skip (@{$$self{SkipData}}) {
            $end <= $$skip[0] and last;
            $pos >= $$skip[1] and $pos += $$skip[1] - $$skip[0], next;
            if ($pos != $$skip[0]) {
                $$self{HTML_DUMP}->Add($pos, $$skip[0]-$pos, $com, $tip, $flg);
                $len -= $$skip[0] - $pos;
                $tip = 'SAME';
            }
            $pos = $$skip[1];
        }
    }
    $$self{HTML_DUMP}->Add($pos, $len, $com, $tip, $flg);
}

#------------------------------------------------------------------------------
# Identify trailer ending at specified offset from end of file
# Inputs: 0) RAF reference, 1) offset from end of file (0 by default)
# Returns: Trailer info hash (with RAF and DirName set),
#          or undef if no recognized trailer was found
# Notes: leaves file position unchanged
sub IdentifyTrailer($;$)
{
    my $raf = shift;
    my $offset = shift || 0;
    my $pos = $raf->Tell();
    my ($buff, $type, $len);
    while ($raf->Seek(-$offset, 2) and ($len = $raf->Tell()) > 0) {
        # read up to 64 bytes before specified offset from end of file
        $len = 64 if $len > 64;
        $raf->Seek(-$len, 1) and $raf->Read($buff, $len) == $len or last;
        if ($buff =~ /AXS(!|\*).{8}$/s) {
            $type = 'AFCP';
        } elsif ($buff =~ /\xa1\xb2\xc3\xd4$/) {
            $type = 'FotoStation';
        } elsif ($buff =~ /cbipcbbl$/) {
            $type = 'PhotoMechanic';
        } elsif ($buff =~ /^CANON OPTIONAL DATA\0/) {
            $type = 'CanonVRD';
        } elsif ($buff =~ /~\0\x04\0zmie~\0\0\x06.{4}[\x10\x18]\x04$/s or
                 $buff =~ /~\0\x04\0zmie~\0\0\x0a.{8}[\x10\x18]\x08$/s)
        {
            $type = 'MIE';
        } elsif ($buff =~ /\0\0(QDIOBS|SEFT)$/) {
            $type = 'Samsung';
        }
        last;
    }
    $raf->Seek($pos, 0);    # restore original file position
    return $type ? { RAF => $raf, DirName => $type } : undef;
}

#------------------------------------------------------------------------------
# Read/rewrite trailer information (including multiple trailers)
# Inputs: 0) ExifTool object ref, 1) DirInfo ref:
# - requires RAF and DirName
# - OutFile is a scalar reference for writing
# - scans from current file position if ScanForAFCP is set
# Returns: 1 if trailer was processed or couldn't be processed (or written OK)
#          0 if trailer was recognized but offsets need fixing (or write error)
# - DirName, DirLen, DataPos, Offset, Fixup and OutFile are updated
# - preserves current file position and byte order
sub ProcessTrailers($$)
{
    my ($self, $dirInfo) = @_;
    my $dirName = $$dirInfo{DirName};
    my $outfile = $$dirInfo{OutFile};
    my $offset = $$dirInfo{Offset} || 0;
    my $fixup = $$dirInfo{Fixup};
    my $raf = $$dirInfo{RAF};
    my $pos = $raf->Tell();
    my $byteOrder = GetByteOrder();
    my $success = 1;
    my $path = $$self{PATH};

    for (;;) { # loop through all trailers
        require "Image/ExifTool/$dirName.pm";
        my $proc = "Image::ExifTool::${dirName}::Process$dirName";
        my $outBuff;
        if ($outfile) {
            # write to local buffer so we can add trailer in proper order later
            $$outfile and $$dirInfo{OutFile} = \$outBuff, $outBuff = '';
            # must generate new fixup if necessary so we can shift
            # the old fixup separately after we prepend this trailer
            delete $$dirInfo{Fixup};
        }
        delete $$dirInfo{DirLen};       # reset trailer length
        $$dirInfo{Offset} = $offset;    # set offset from end of file
        $$dirInfo{Trailer} = 1;         # set Trailer flag in case proc cares
        # add trailer and DirName to SubDirectory PATH
        push @$path, 'Trailer', $dirName;

        # read or write this trailer
        # (proc takes Offset as offset from end of trailer to end of file,
        #  and returns DataPos and DirLen, and Fixup if applicable)
        no strict 'refs';
        my $result = &$proc($self, $dirInfo);
        use strict 'refs';

        # restore PATH (pop last 2 items)
        splice @$path, -2;

        # check result
        if ($outfile) {
            if ($result > 0) {
                if ($outBuff) {
                    # write trailers to OutFile in original order
                    $$outfile = $outBuff . $$outfile;
                    # must adjust old fixup start if it exists
                    $$fixup{Start} += length($outBuff) if $fixup;
                    $outBuff = '';      # free memory
                }
                if ($$dirInfo{Fixup}) {
                    if ($fixup) {
                        # add fixup for subsequent trailers to the fixup for this trailer
                        # (but first we must adjust for the new start position)
                        $$fixup{Shift} += $$dirInfo{Fixup}{Start};
                        $$fixup{Start} -= $$dirInfo{Fixup}{Start};
                        $$dirInfo{Fixup}->AddFixup($fixup);
                    }
                    $fixup = $$dirInfo{Fixup};  # save fixup
                }
            } else {
                $success = 0 if $self->Error("Error rewriting $dirName trailer", 2);
                last;
            }
        } elsif ($result < 0) {
            # can't continue if we must scan for this trailer
            $success = 0;
            last;
        }
        last unless $result > 0 and $$dirInfo{DirLen};
        # look for next trailer
        $offset += $$dirInfo{DirLen};
        my $nextTrail = IdentifyTrailer($raf, $offset) or last;
        $dirName = $$dirInfo{DirName} = $$nextTrail{DirName};
        $raf->Seek($pos, 0);
    }
    SetByteOrder($byteOrder);       # restore original byte order
    $raf->Seek($pos, 0);            # restore original file position
    $$dirInfo{OutFile} = $outfile;  # restore original outfile
    $$dirInfo{Offset} = $offset;    # return offset from EOF to start of first trailer
    $$dirInfo{Fixup} = $fixup;      # return fixup information
    return $success;
}

#------------------------------------------------------------------------------
# JPEG constants

# JPEG marker names
%jpegMarker = (
    0x00 => 'NULL',
    0x01 => 'TEM',
    0xc0 => 'SOF0', # to SOF15, with a few exceptions below
    0xc4 => 'DHT',
    0xc8 => 'JPGA',
    0xcc => 'DAC',
    0xd0 => 'RST0',
    0xd8 => 'SOI',
    0xd9 => 'EOI',
    0xda => 'SOS',
    0xdb => 'DQT',
    0xdc => 'DNL',
    0xdd => 'DRI',
    0xde => 'DHP',
    0xdf => 'EXP',
    0xe0 => 'APP0', # to APP15
    0xf0 => 'JPG0',
    0xfe => 'COM',
);

# lookup for size of JPEG marker length word
# (2 bytes assumed unless specified here)
my %markerLenBytes = (
    0x00 => 0,  0x01 => 0,
    0xd0 => 0,  0xd1 => 0,  0xd2 => 0,  0xd3 => 0,  0xd4 => 0,  0xd5 => 0,  0xd6 => 0,  0xd7 => 0,
    0xd8 => 0,  0xd9 => 0,  0xda => 0,
    # J2C
    0x30 => 0,  0x31 => 0,  0x32 => 0,  0x33 => 0,  0x34 => 0,  0x35 => 0,  0x36 => 0,  0x37 => 0,
    0x38 => 0,  0x39 => 0,  0x3a => 0,  0x3b => 0,  0x3c => 0,  0x3d => 0,  0x3e => 0,  0x3f => 0,
    0x4f => 0,
    0x92 => 0,  0x93 => 0,
    # J2C extensions
    0x74 => 4, 0x75 => 4, 0x77 => 4,
);

#------------------------------------------------------------------------------
# Get JPEG marker name
# Inputs: 0) Jpeg number
# Returns: marker name
sub JpegMarkerName($)
{
    my $marker = shift;
    my $markerName = $jpegMarker{$marker};
    unless ($markerName) {
        $markerName = $jpegMarker{$marker & 0xf0};
        if ($markerName and $markerName =~ /^([A-Z]+)\d+$/) {
            $markerName = $1 . ($marker & 0x0f);
        } else {
            $markerName = sprintf("marker 0x%.2x", $marker);
        }
    }
    return $markerName;
}

#------------------------------------------------------------------------------
# Adjust directory start position
# Inputs: 0) dirInfo ref, 1) start offset
#         2) Base for offsets (relative to DataPos, defaults to absolute Base of 0)
sub DirStart($$;$)
{
    my ($dirInfo, $start, $base) = @_;
    $$dirInfo{DirStart} = $start;
    $$dirInfo{DirLen} -= $start;
    if (defined $base) {
        $$dirInfo{Base} = $$dirInfo{DataPos} + $base;
        $$dirInfo{DataPos} = -$base;    # (relative to Base!)
    }
}

#------------------------------------------------------------------------------
# Extract metadata from a jpg image
# Inputs: 0) ExifTool object reference, 1) dirInfo ref with RAF set
# Returns: 1 on success, 0 if this wasn't a valid JPEG file
sub ProcessJPEG($$)
{
    local $_;
    my ($self, $dirInfo) = @_;
    my ($ch, $s, $length);
    my $verbose = $$self{OPTIONS}{Verbose};
    my $out = $$self{OPTIONS}{TextOut};
    my $fast = $$self{OPTIONS}{FastScan};
    my $raf = $$dirInfo{RAF};
    my $htmlDump = $$self{HTML_DUMP};
    my %dumpParms = ( Out => $out );
    my ($success, $wantTrailer, $trailInfo, $foundSOS);
    my (@iccChunk, $iccChunkCount, $iccChunksTotal, @flirChunk, $flirCount, $flirTotal);
    my ($preview, $scalado, @dqt, $subSampling, $dumpEnd, %extendedXMP);

    # check to be sure this is a valid JPG (or J2C, or EXV) file
    return 0 unless $raf->Read($s, 2) == 2 and $s =~ /^\xff[\xd8\x4f\x01]/;
    if ($s eq "\xff\x01") {
        return 0 unless $raf->Read($s, 5) == 5 and $s eq 'Exiv2';
        $$self{FILE_TYPE} = 'EXV';
    }
    if (not $$self{VALUE}{FileType} or ($$self{DOC_NUM} and $$self{OPTIONS}{ExtractEmbedded})) {
        $self->SetFileType();               # set FileType tag
        return 1 if $fast and $fast == 3;   # don't process file when FastScan == 3
        $$self{LOW_PRIORITY_DIR}{IFD1} = 1; # lower priority of IFD1 tags
    }
    $dumpParms{MaxLen} = 128 if $verbose < 4;
    if ($htmlDump) {
        $dumpEnd = $raf->Tell();
        my ($n, $t, $m) = $s eq 'Exiv2' ? (7,'EXV','TEM') : (2,'JPEG','SOI');
        my $pos = $dumpEnd - $n;
        $self->HDump(0, $pos, '[unknown header]') if $pos;
        $self->HDump($pos, $n, "$t header", "$m Marker");
    }
    my $path = $$self{PATH};
    my $pn = scalar @$path;

    # set input record separator to 0xff (the JPEG marker) to make reading quicker
    local $/ = "\xff";

    my ($nextMarker, $nextSegDataPt, $nextSegPos, $combinedSegData, $firstSegPos, @skipData);

    # read file until we reach an end of image (EOI) or start of scan (SOS)
    Marker: for (;;) {
        # set marker and data pointer for current segment
        my $marker = $nextMarker;
        my $segDataPt = $nextSegDataPt;
        my $segPos = $nextSegPos;
        undef $nextMarker;
        undef $nextSegDataPt;
#
# read ahead to the next segment unless we have reached EOI, SOS or SOD
#
        unless ($marker and ($marker==0xd9 or ($marker==0xda and not $wantTrailer) or $marker==0x93)) {
            # read up to next marker (JPEG markers begin with 0xff)
            my $buff;
            $raf->ReadLine($buff) or last;
            # JPEG markers can be padded with unlimited 0xff's
            for (;;) {
                $raf->Read($ch, 1) or last Marker;
                $nextMarker = ord($ch);
                last unless $nextMarker == 0xff;
            }
            # read segment data if it exists
            if (not defined $markerLenBytes{$nextMarker}) {
                # read record length word
                last unless $raf->Read($s, 2) == 2;
                my $len = unpack('n',$s);   # get data length
                last unless defined($len) and $len >= 2;
                $nextSegPos = $raf->Tell();
                $len -= 2;  # subtract size of length word
                last unless $raf->Read($buff, $len) == $len;
                $nextSegDataPt = \$buff;    # set pointer to our next data
            } elsif ($markerLenBytes{$nextMarker} == 4) {
                # handle J2C extensions with 4-byte length word
                last unless $raf->Read($s, 4) == 4;
                my $len = unpack('N',$s);   # get data length
                last unless defined($len) and $len >= 4;
                $nextSegPos = $raf->Tell();
                $len -= 4;  # subtract size of length word
                last unless $raf->Seek($len, 1);
            }
            # read second segment too if this was the first
            next unless defined $marker;
        }
        # set some useful variables for the current segment
        my $markerName = JpegMarkerName($marker);
        $$path[$pn] = $markerName;
#
# parse the current segment
#
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            $length = length $$segDataPt;
            if ($verbose) {
                print $out "JPEG $markerName ($length bytes):\n";
                HexDump($segDataPt, undef, %dumpParms, Addr=>$segPos) if $verbose>2;
            } elsif ($htmlDump) {
                $self->HDump($segPos-4, $length+4, "[JPEG $markerName]", undef, 0x08);
                $dumpEnd = $segPos + $length;
            }
            next unless $length >= 6;
            # extract some useful information
            my ($p, $h, $w, $n) = unpack('Cn2C', $$segDataPt);
            my $sof = GetTagTable('Image::ExifTool::JPEG::SOF');
            $self->HandleTag($sof, 'ImageWidth', $w);
            $self->HandleTag($sof, 'ImageHeight', $h);
            $self->HandleTag($sof, 'EncodingProcess', $marker - 0xc0);
            $self->HandleTag($sof, 'BitsPerSample', $p);
            $self->HandleTag($sof, 'ColorComponents', $n);
            next unless $n == 3 and $length >= 15;
            my ($i, $hmin, $hmax, $vmin, $vmax);
            # loop through all components to determine sampling frequency
            $subSampling = '';
            for ($i=0; $i<$n; ++$i) {
                my $sf = Get8u($segDataPt, 7 + 3 * $i);
                $subSampling .= sprintf('%.2x', $sf);
                # isolate horizontal and vertical components
                my ($hf, $vf) = ($sf >> 4, $sf & 0x0f);
                unless ($i) {
                    $hmin = $hmax = $hf;
                    $vmin = $vmax = $vf;
                    next;
                }
                # determine min/max frequencies
                $hmin = $hf if $hf < $hmin;
                $hmax = $hf if $hf > $hmax;
                $vmin = $vf if $vf < $vmin;
                $vmax = $vf if $vf > $vmax;
            }
            if ($hmin and $vmin) {
                my ($hs, $vs) = ($hmax / $hmin, $vmax / $vmin);
                $self->FoundTag($$sof{YCbCrSubSampling}, "$hs $vs");
            }
            next;
        } elsif ($marker == 0xd9) {         # EOI
            pop @$path;
            $verbose and print $out "JPEG EOI\n";
            my $pos = $raf->Tell();
            if ($htmlDump and $dumpEnd) {
                $self->HDump($dumpEnd, $pos-2-$dumpEnd, '[JPEG Image Data]', undef, 0x08);
                $self->HDump($pos-2, 2, 'JPEG EOI', undef);
                $dumpEnd = 0;
            }
            if ($foundSOS or $$self{FILE_TYPE} eq 'EXV') {
                $success = 1;
            } else {
                $self->Warn('Missing JPEG SOS');
            }
            # we are here because we are looking for trailer information
            if ($wantTrailer) {
                my $start = $$self{PreviewImageStart};
                if ($start) {
                    my $buff;
                    # most previews start right after the JPEG EOI, but the Olympus E-20
                    # preview is 508 bytes into the trailer, the K-M Maxxum 7D preview is
                    # 979 bytes in, and Sony previews can start up to 32 kB into the trailer.
                    # (and Minolta and Sony previews can have a random first byte...)
                    my $scanLen = $$self{Make} =~ /Sony/i ? 65536 : 1024;
                    if ($raf->Read($buff, $scanLen) and ($buff =~ /\xff\xd8\xff./g or
                        ($$self{Make} =~ /(Minolta|Sony)/i and $buff =~ /.\xd8\xff\xdb/g)))
                    {
                        # adjust PreviewImageStart to this location
                        my $actual = $pos + pos($buff) - 4;
                        if ($start ne $actual and $verbose > 1) {
                            print $out "(Fixed PreviewImage location: $start -> $actual)\n";
                        }
                        # update preview image offsets
                        $$self{VALUE}{PreviewImageStart} = $actual if $$self{VALUE}{PreviewImageStart};
                        $$self{PreviewImageStart} = $actual;
                        # load preview now if we tried and failed earlier
                        if ($$self{PreviewError} and $$self{PreviewImageLength}) {
                            if ($raf->Seek($actual, 0) and $raf->Read($buff, $$self{PreviewImageLength})) {
                                $self->FoundTag('PreviewImage', $buff);
                                delete $$self{PreviewError};
                            }
                        }
                    }
                    $raf->Seek($pos, 0);
                }
            }
            # process trailer now or finish processing trailers
            # and scan for AFCP if necessary
            my $fromEnd = 0;
            if ($trailInfo) {
                $$trailInfo{ScanForAFCP} = 1;   # scan now if necessary
                $self->ProcessTrailers($trailInfo);
                # save offset from end of file to start of first trailer
                $fromEnd = $$trailInfo{Offset};
                undef $trailInfo;
            }
            if ($$self{LeicaTrailer}) {
                $raf->Seek(0, 2);
                $$self{LeicaTrailer}{TrailPos} = $pos;
                $$self{LeicaTrailer}{TrailLen} = $raf->Tell() - $pos - $fromEnd;
                Image::ExifTool::Panasonic::ProcessLeicaTrailer($self);
            }
            # finally, dump remaining information in JPEG trailer
            if ($verbose or $htmlDump) {
                my $endPos = $$self{LeicaTrailerPos};
                unless ($endPos) {
                    $raf->Seek(0, 2);
                    $endPos = $raf->Tell() - $fromEnd;
                }
                $self->DumpUnknownTrailer({
                    RAF => $raf,
                    DataPos => $pos,
                    DirLen => $endPos - $pos
                }) if $endPos > $pos;
            }
            last;       # all done parsing file
        } elsif ($marker == 0xda) {         # SOS
            pop @$path;
            $foundSOS = 1;
            # all done with meta information unless we have a trailer
            $verbose and print $out "JPEG SOS\n";
            unless ($fast) {
                $trailInfo = IdentifyTrailer($raf);
                # process trailer now unless we are doing verbose dump
                if ($trailInfo and $verbose < 3 and not $htmlDump) {
                    # process trailers (keep trailInfo to finish processing later
                    # only if we can't finish without scanning from end of file)
                    $self->ProcessTrailers($trailInfo) and undef $trailInfo;
                }
                if ($wantTrailer) {
                    # seek ahead and validate preview image
                    my $buff;
                    my $curPos = $raf->Tell();
                    if ($raf->Seek($$self{PreviewImageStart}, 0) and
                        $raf->Read($buff, 4) == 4 and
                        $buff =~ /^.\xd8\xff[\xc4\xdb\xe0-\xef]/)
                    {
                        undef $wantTrailer;
                    }
                    $raf->Seek($curPos, 0) or last;
                }
                # seek ahead and process Leica trailer
                if ($$self{LeicaTrailer}) {
                    require Image::ExifTool::Panasonic;
                    Image::ExifTool::Panasonic::ProcessLeicaTrailer($self);
                    $wantTrailer = 1 if $$self{LeicaTrailer};
                }
                next if $trailInfo or $wantTrailer or $verbose > 2 or $htmlDump;
            }
            next if $$self{OPTIONS}{Validate};  # (validate to EOI)
            # nothing interesting to parse after start of scan (SOS)
            $success = 1;
            last;   # all done parsing file
        } elsif ($marker == 0x93) {
            pop @$path;
            $verbose and print $out "JPEG SOD\n";
            $success = 1;
            next if $verbose > 2 or $htmlDump;
            last;   # all done parsing file
        } elsif (defined $markerLenBytes{$marker}) {
            # handle other stand-alone markers and segments we skipped over
            $verbose and $marker and print $out "JPEG $markerName\n";
            next;
        } elsif ($marker == 0xdb and length($$segDataPt) and    # DQT
            # save the DQT data only if JPEGDigest has been requested
            # (Note: since we aren't checking the RequestAll API option here, the application
            #  must use the RequestTags option to generate these tags if they have not been
            #  specifically requested.  The reason is that there is too much overhead involved
            #  in the calculation of this tag to make this worth the CPU time.)
            ($$self{REQ_TAG_LOOKUP}{jpegdigest} or $$self{REQ_TAG_LOOKUP}{jpegqualityestimate}
            or ($$self{OPTIONS}{RequestAll} and $$self{OPTIONS}{RequestAll} > 2)))
        {
            my $num = unpack('C',$$segDataPt) & 0x0f;   # get table index
            $dqt[$num] = $$segDataPt if $num < 4;       # save for MD5 calculation
        }
        # handle all other markers
        my $dumpType = '';
        my ($desc, $tip);
        $length = length $$segDataPt;
        if ($verbose) {
            print $out "JPEG $markerName ($length bytes):\n";
            if ($verbose > 2) {
                my %extraParms = ( Addr => $segPos );
                $extraParms{MaxLen} = 128 if $verbose == 4;
                HexDump($segDataPt, undef, %dumpParms, %extraParms);
            }
        }
        # prepare dirInfo hash for processing this information
        my %dirInfo = (
            Parent   => $markerName,
            DataPt   => $segDataPt,
            DataPos  => $segPos,
            DataLen  => $length,
            DirStart => 0,
            DirLen   => $length,
            Base     => 0,
        );
        if ($marker == 0xe0) {              # APP0 (JFIF, JFXX, CIFF, AVI1, Ocad)
            if ($$segDataPt =~ /^JFIF\0/) {
                $dumpType = 'JFIF';
                DirStart(\%dirInfo, 5); # start at byte 5
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Main');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^JFXX\0(\x10|\x11|\x13)/) {
                my $tag = ord $1;
                $dumpType = 'JFXX';
                my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Extension');
                my $tagInfo = $self->GetTagInfo($tagTablePtr, $tag);
                $self->FoundTag($tagInfo, substr($$segDataPt, 6));
            } elsif ($$segDataPt =~ /^(II|MM).{4}HEAPJPGM/s) {
                next if $fast and $fast > 1;    # skip processing for very fast
                $dumpType = 'CIFF';
                my %dirInfo = ( RAF => new File::RandomAccess($segDataPt) );
                $$self{SET_GROUP1} = 'CIFF';
                push @{$$self{PATH}}, 'CIFF';
                require Image::ExifTool::CanonRaw;
                Image::ExifTool::CanonRaw::ProcessCRW($self, \%dirInfo);
                pop @{$$self{PATH}};
                delete $$self{SET_GROUP1};
            } elsif ($$segDataPt =~ /^(AVI1|Ocad)/) {
                $dumpType = $1;
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable("Image::ExifTool::JPEG::$dumpType");
                DirStart(\%dirInfo, 4);
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xe1) {         # APP1 (EXIF, XMP, QVCI)
            # (some Kodak cameras don't put a second "\0", and I have seen an
            #  example where there was a second 4-byte APP1 segment header)
            if ($$segDataPt =~ /^(.{0,4})Exif\0/is) {
                undef $dumpType;    # (will be dumped here)
                # this is EXIF data --
                # get the data block (into a common variable)
                my $hdrLen = length($exifAPP1hdr);
                if (length $1) {
                    $hdrLen += length $1;
                    $self->Warn('Unknown garbage at start of EXIF segment',1);
                } elsif ($$segDataPt !~ /^Exif\0/) {
                    $self->Warn('Incorrect EXIF segment identifier',1);
                }
                if ($htmlDump) {
                    $self->HDump($segPos-4, 4, 'APP1 header', "Data size: $length bytes");
                    $self->HDump($segPos, $hdrLen, 'Exif header', 'APP1 data type: Exif');
                    $dumpEnd = $segPos + $length;
                }
                my $dataPt = $segDataPt;
                if (defined $combinedSegData) {
                    push @skipData, [ $segPos-4, $segPos+$hdrLen ];
                    $combinedSegData .= substr($$segDataPt,$hdrLen);
                    undef $$segDataPt;
                    $dataPt = \$combinedSegData;
                    $segPos = $firstSegPos;
                }
                # peek ahead to see if the next segment is extended EXIF
                if ($nextMarker == $marker and
                    $$nextSegDataPt =~ /^$exifAPP1hdr(?!(MM\0\x2a|II\x2a\0))/)
                {
                    # initialize combined data if necessary
                    unless (defined $combinedSegData) {
                        $combinedSegData = $$segDataPt;
                        undef $$segDataPt;
                        $firstSegPos = $segPos;
                        $self->Warn('File contains multi-segment EXIF',1);
                        $$self{ExtendedEXIF} = 1;
                    }
                    next;
                }
                $dirInfo{DataPt} = $dataPt;
                $dirInfo{DataPos} = $segPos;
                $dirInfo{DataLen} = $dirInfo{DirLen} = length $$dataPt;
                DirStart(\%dirInfo, $hdrLen, $hdrLen);
                $$self{SkipData} = \@skipData if @skipData;
                # extract the EXIF information (it is in standard TIFF format)
                $self->ProcessTIFF(\%dirInfo);
                # avoid looking for preview unless necessary because it really slows
                # us down -- only look for it if we found pointer, and preview is
                # outside EXIF, and PreviewImage is specifically requested
                my $start = $self->GetValue('PreviewImageStart', 'ValueConv');
                my $plen = $self->GetValue('PreviewImageLength', 'ValueConv');
                if (not $start or not $plen and $$self{PreviewError}) {
                    $start = $$self{PreviewImageStart};
                    $plen = $$self{PreviewImageLength};
                }
                if ($start and $plen and IsInt($start) and IsInt($plen) and
                    $start + $plen > $$self{EXIF_POS} + length($$self{EXIF_DATA}) and
                    ($$self{REQ_TAG_LOOKUP}{previewimage} or
                    # (extracted normally, so check Binary option)
                    ($$self{OPTIONS}{Binary} and not $$self{EXCL_TAG_LOOKUP}{previewimage})))
                {
                    $$self{PreviewImageStart} = $start;
                    $$self{PreviewImageLength} = $plen;
                    $wantTrailer = 1;
                }
                if (@skipData) {
                    undef @skipData;
                    delete $$self{SkipData};
                }
                undef $$dataPt;
                next;
            } elsif ($$segDataPt =~ /^$xmpExtAPP1hdr/) {
                # off len -- extended XMP header (75 bytes total):
                #   0  35 bytes - signature
                #  35  32 bytes - GUID (MD5 hash of full extended XMP data in ASCII)
                #  67   4 bytes - total size of extended XMP data
                #  71   4 bytes - offset for this XMP data portion
                $dumpType = 'Extended XMP';
                if ($length > 75) {
                    my ($size, $off) = unpack('x67N2', $$segDataPt);
                    my $guid = substr($$segDataPt, 35, 32);
                    if ($guid =~ /[^A-Za-z0-9]/) { # (technically, should be uppercase)
                        $self->WarnOnce($tip = 'Invalid extended XMP GUID');
                    } else {
                        my $extXMP = $extendedXMP{$guid};
                        if (not $extXMP) {
                            $extXMP = $extendedXMP{$guid} = { };
                        } elsif ($size != $$extXMP{Size}) {
                            $self->WarnOnce('Inconsistent extended XMP size');
                        }
                        $$extXMP{Size} = $size;
                        $$extXMP{$off} = substr($$segDataPt, 75);
                        $tip = "Full length: $size\nChunk offset: $off\nChunk length: " .
                            ($length - 75) . "\nGUID: $guid";
                        # (delay processing extended XMP until after reading all segments)
                    }
                } else {
                    $self->WarnOnce($tip = 'Invalid extended XMP segment');
                }
            } elsif ($$segDataPt =~ /^QVCI\0/) {
                $dumpType = 'QVCI';
                my $tagTablePtr = GetTagTable('Image::ExifTool::Casio::QVCI');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^FLIR\0/ and $length >= 8) {
                $dumpType = 'FLIR';
                # must concatenate FLIR chunks (note: handle the case where
                # some software erroneously writes zeros for the chunk counts)
                my $chunkNum = Get8u($segDataPt, 6);
                my $chunksTot = Get8u($segDataPt, 7) + 1; # (note the "+ 1"!)
                $verbose and printf $out "$$self{INDENT}FLIR chunk %d of %d\n",
                                    $chunkNum + 1, $chunksTot;
                if (defined $flirTotal) {
                    # abort parsing FLIR if the total chunk count is inconsistent
                    undef $flirCount if $chunksTot != $flirTotal;
                } else {
                    $flirCount = 0;
                    $flirTotal = $chunksTot;
                }
                if (defined $flirCount) {
                    if (defined $flirChunk[$chunkNum]) {
                        $self->WarnOnce('Duplicate FLIR chunk number(s)');
                        $flirChunk[$chunkNum] .= substr($$segDataPt, 8);
                    } else {
                        $flirChunk[$chunkNum] = substr($$segDataPt, 8);
                    }
                    # process the FLIR information if we have all of the chunks
                    if (++$flirCount >= $flirTotal) {
                        my $flir = '';
                        defined $_ and $flir .= $_ foreach @flirChunk;
                        undef @flirChunk;   # free memory
                        my $tagTablePtr = GetTagTable('Image::ExifTool::FLIR::FFF');
                        my %dirInfo = (
                            DataPt   => \$flir,
                            Parent   => $markerName,
                            DirName  => 'FLIR',
                        );
                        $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                        undef $flirCount;   # prevent reprocessing
                    }
                } else {
                    $self->WarnOnce('Invalid or extraneous FLIR chunk(s)');
                }
            } else {
                # Hmmm.  Could be XMP, let's see
                my $processed;
                if ($$segDataPt =~ /^(http|XMP\0)/ or $$segDataPt =~ /<(exif:|\?xpacket)/) {
                    $dumpType = 'XMP';
                    # also try to parse XMP with a non-standard header
                    # (note: this non-standard XMP is ignored when writing)
                    my $start = ($$segDataPt =~ /^$xmpAPP1hdr/) ? length($xmpAPP1hdr) : 0;
                    my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                    DirStart(\%dirInfo, $start);
                    $dirInfo{DirName} = $start ? 'XMP' : 'XML',
                    $processed = $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                    if ($processed and not $start) {
                        $self->Warn('Non-standard header for APP1 XMP segment');
                    }
                }
                if ($verbose and not $processed) {
                    $self->Warn("Ignored APP1 segment length $length (unknown header)");
                }
            }
        } elsif ($marker == 0xe2) {         # APP2 (ICC Profile, FPXR, MPF, PreviewImage)
            if ($$segDataPt =~ /^ICC_PROFILE\0/ and $length >= 14) {
                $dumpType = 'ICC_Profile';
                # must concatenate profile chunks (note: handle the case where
                # some software erroneously writes zeros for the chunk counts)
                my $chunkNum = Get8u($segDataPt, 12);
                my $chunksTot = Get8u($segDataPt, 13);
                $verbose and print $out "$$self{INDENT}ICC_Profile chunk $chunkNum of $chunksTot\n";
                if (defined $iccChunksTotal) {
                    # abort parsing ICC_Profile if the total chunk count is inconsistent
                    undef $iccChunkCount if $chunksTot != $iccChunksTotal;
                } else {
                    $iccChunkCount = 0;
                    $iccChunksTotal = $chunksTot;
                    $self->Warn('ICC_Profile chunk count is zero') if !$chunksTot;
                }
                if (defined $iccChunkCount) {
                    if (defined $iccChunk[$chunkNum]) {
                        $self->WarnOnce('Duplicate ICC_Profile chunk number(s)');
                        $iccChunk[$chunkNum] .= substr($$segDataPt, 14);
                    } else {
                        $iccChunk[$chunkNum] = substr($$segDataPt, 14);
                    }
                    # process profile if we have all of the chunks
                    if (++$iccChunkCount >= $iccChunksTotal) {
                        my $icc_profile = '';
                        defined $_ and $icc_profile .= $_ foreach @iccChunk;
                        undef @iccChunk;   # free memory
                        my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                        my %dirInfo = (
                            DataPt   => \$icc_profile,
                            DataPos  => $segPos + 14,
                            DataLen  => length($icc_profile),
                            DirStart => 0,
                            DirLen   => length($icc_profile),
                            Parent   => $markerName,
                        );
                        $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                        undef $iccChunkCount;     # prevent reprocessing
                    }
                } else {
                    $self->WarnOnce('Invalid or extraneous ICC_Profile chunk(s)');
                }
            } elsif ($$segDataPt =~ /^FPXR\0/) {
                next if $fast and $fast > 1;    # skip processing for very fast
                $dumpType = 'FPXR';
                my $tagTablePtr = GetTagTable('Image::ExifTool::FlashPix::Main');
                # set flag if this is the last FPXR segment
                $dirInfo{LastFPXR} = not ($nextMarker==$marker and $$nextSegDataPt=~/^FPXR\0/),
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^MPF\0/) {
                undef $dumpType;    # (will be dumped here)
                DirStart(\%dirInfo, 4, 4);
                $dirInfo{Multi} = 1;    # the MP Attribute IFD will be MPF1
                if ($htmlDump) {
                    $self->HDump($segPos-4, 4, 'APP2 header', "Data size: $length bytes");
                    $self->HDump($segPos, 4, 'MPF header', 'APP2 data type: MPF');
                    $dumpEnd = $segPos + $length;
                }
                # extract the MPF information (it is in standard TIFF format)
                my $tagTablePtr = GetTagTable('Image::ExifTool::MPF::Main');
                $self->ProcessTIFF(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^(|QVGA\0|BGTH)\xff\xd8\xff[\xdb\xe0\xe1]/) {
                # Samsung/GE/GoPro="", BenQ DC C1220/Pentacon/Polaroid="QVGA\0",
                # Digilife DDC-690/Rollei="BGTH"
                $dumpType = 'Preview Image';
                $preview = substr($$segDataPt, length($1));
            } elsif ($preview) {
                $dumpType = 'Preview Image';
                $preview .= $$segDataPt;
            }
            if ($preview and $nextMarker ne $marker) {
                $self->FoundTag('PreviewImage', $preview);
                undef $preview;
            }
        } elsif ($marker == 0xe3) {         # APP3 (Kodak "Meta", Stim)
            if ($$segDataPt =~ /^(Meta|META|Exif)\0\0/) {
                undef $dumpType;    # (will be dumped here)
                DirStart(\%dirInfo, 6, 6);
                if ($htmlDump) {
                    $self->HDump($segPos-4, 10, 'APP3 Meta header');
                    $dumpEnd = $segPos + $length;
                }
                my $tagTablePtr = GetTagTable('Image::ExifTool::Kodak::Meta');
                $self->ProcessTIFF(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^Stim\0/) {
                undef $dumpType;    # (will be dumped here)
                DirStart(\%dirInfo, 6, 6);
                if ($htmlDump) {
                    $self->HDump($segPos-4, 4, 'APP3 header', "Data size: $length bytes");
                    $self->HDump($segPos, 5, 'Stim header', 'APP3 data type: Stim');
                    $dumpEnd = $segPos + $length;
                }
                # extract the Stim information (it is in standard TIFF format)
                my $tagTablePtr = GetTagTable('Image::ExifTool::Stim::Main');
                $self->ProcessTIFF(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^\xff\xd8\xff\xdb/) {
                $dumpType = 'PreviewImage'; # (Samsung, HP, BenQ)
                $preview = $$segDataPt;
            }
            if ($preview and $nextMarker ne 0xe4) { # this preview continues in APP4
                $self->FoundTag('PreviewImage', $preview);
                undef $preview;
            }
        } elsif ($marker == 0xe4) {         # APP4 ("SCALADO", FPXR, PreviewImage)
            if ($$segDataPt =~ /^SCALADO\0/ and $length >= 16) {
                $dumpType = 'SCALADO';
                my ($num, $idx, $len) = unpack('x8n2N', $$segDataPt);
                # assume that the segments are in order and just concatinate them
                $scalado = '' unless defined $scalado;
                $scalado .= substr($$segDataPt, 16);
                if ($idx == $num - 1) {
                    if ($len != length $scalado) {
                        $self->Warn('Possibly corrupted APP4 SCALADO data', 1);
                    }
                    my %dirInfo = (
                        Parent => $markerName,
                        DataPt => \$scalado,
                    );
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Scalado::Main');
                    $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                    undef $scalado;
                }
            } elsif ($$segDataPt =~ /^FPXR\0/) {
                next if $fast and $fast > 1;    # skip processing for very fast
                $dumpType = 'FPXR';
                my $tagTablePtr = GetTagTable('Image::ExifTool::FlashPix::Main');
                # set flag if this is the last FPXR segment
                $dirInfo{LastFPXR} = not ($nextMarker==$marker and $$nextSegDataPt=~/^FPXR\0/),
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($preview) {
                # continued Samsung S1060 preview from APP3
                $dumpType = 'PreviewImage';
                $preview .= $$segDataPt;
            }
            # BenQ DC E1050 continues preview in APP5
            if ($preview and $nextMarker ne 0xe5) {
                $self->FoundTag('PreviewImage', $preview);
                undef $preview;
            }
        } elsif ($marker == 0xe5) {         # APP5 (Ricoh "RMETA")
            if ($$segDataPt =~ /^RMETA\0/) {
                # (NOTE: apparently these may span multiple segments, but I haven't seen
                # a sample like this, so multi-segment support hasn't yet been implemented)
                $dumpType = 'Ricoh RMETA';
                DirStart(\%dirInfo, 6, 6);
                my $tagTablePtr = GetTagTable('Image::ExifTool::Ricoh::RMETA');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($preview) {
                $dumpType = 'PreviewImage';
                $preview .= $$segDataPt;
                $self->FoundTag('PreviewImage', $preview);
                undef $preview;
            }
        } elsif ($marker == 0xe6) {         # APP6 (Toshiba EPPIM, NITF, HP_TDHD)
            if ($$segDataPt =~ /^EPPIM\0/) {
                undef $dumpType;    # (will be dumped here)
                DirStart(\%dirInfo, 6, 6);
                if ($htmlDump) {
                    $self->HDump($segPos-4, 10, 'APP6 EPPIM header');
                    $dumpEnd = $segPos + $length;
                }
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::EPPIM');
                $self->ProcessTIFF(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^NITF\0/) {
                $dumpType = 'NITF';
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::NITF');
                DirStart(\%dirInfo, 5);
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^TDHD\x01\0\0\0/ and $length > 12) {
                # HP Photosmart R837 APP6 "TDHD" segment
                $dumpType = 'TDHD';
                my $tagTablePtr = GetTagTable('Image::ExifTool::HP::TDHD');
                # (ignore first TDHD element because size includes 12-byte tag header)
                DirStart(\%dirInfo, 12);
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^GoPro\0/) {
                # GoPro segment
                $dumpType = 'GoPro';
                my $tagTablePtr = GetTagTable('Image::ExifTool::GoPro::GPMF');
                DirStart(\%dirInfo, 6);
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xe7) {         # APP7 (Pentax, Qualcomm)
            if ($$segDataPt =~ /^PENTAX \0(II|MM)/) {
                # found in K-3 images (is this multi-segment??)
                SetByteOrder($1);
                undef $dumpType; # (dump this ourself)
                my $hdrLen = 10;
                my $tagTablePtr = GetTagTable('Image::ExifTool::Pentax::Main');
                DirStart(\%dirInfo, $hdrLen, 0);
                $dirInfo{DirName} = 'Pentax APP7';
                if ($htmlDump) {
                    $self->HDump($segPos-4, 4, 'APP7 header', "Data size: $length bytes");
                    $self->HDump($segPos, $hdrLen, 'Pentax header', 'APP7 data type: Pentax');
                    $dumpEnd = $segPos + $length;
                }
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } elsif ($$segDataPt =~ /^\x1aQualcomm Camera Attributes/) {
                # found in HP iPAQ_VoiceMessenger
                $dumpType = 'Qualcomm';
                my $tagTablePtr = GetTagTable('Image::ExifTool::Qualcomm::Main');
                DirStart(\%dirInfo, 27);
                $dirInfo{DirName} = 'Qualcomm';
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xe8) {         # APP8 (SPIFF)
            # my sample SPIFF has 32 bytes of data, but spec states 30
            if ($$segDataPt =~ /^SPIFF\0/ and $length == 32) {
                $dumpType = 'SPIFF';
                DirStart(\%dirInfo, 6);
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::SPIFF');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xe9) {         # APP9 (Media Jukebox)
            if ($$segDataPt =~ /^Media Jukebox\0/ and $length > 22) {
                $dumpType = 'MediaJukebox';
                # (start parsing after the "<MJMD>")
                DirStart(\%dirInfo, 22);
                $dirInfo{DirName} = 'MediaJukebox';
                require Image::ExifTool::XMP;
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::MediaJukebox');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr, \&Image::ExifTool::XMP::ProcessXMP);
            }
        } elsif ($marker == 0xea) {         # APP10 (PhotoStudio Unicode comments)
            if ($$segDataPt =~ /^UNICODE\0/) {
                $dumpType = 'PhotoStudio';
                my $comment = $self->Decode(substr($$segDataPt,8), 'UCS2', 'MM');
                $self->FoundTag('Comment', $comment);
            }
        } elsif ($marker == 0xeb) {         # APP11 (JPEG-HDR)
            if ($$segDataPt =~ /^HDR_RI /) {
                $dumpType = 'JPEG-HDR';
                my $dataPt = $segDataPt;
                if (defined $combinedSegData) {
                    if ($$segDataPt =~ /~\0/g) {
                        $combinedSegData .= substr($$segDataPt,pos($$segDataPt));
                    } else {
                        $self->Warn('Invalid format for JPEG-HDR extended segment');
                    }
                    $dataPt = \$combinedSegData;
                }
                if ($nextMarker == $marker and $$nextSegDataPt =~ /^HDR_RI /) {
                    $combinedSegData = $$segDataPt unless defined $combinedSegData;
                } else {
                    my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::HDR');
                    my %dirInfo = ( DataPt => $dataPt );
                    $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                    undef $combinedSegData;
                }
            }
        } elsif ($marker == 0xec) {         # APP12 (Ducky, Picture Info)
            if ($$segDataPt =~ /^Ducky/) {
                $dumpType = 'Ducky';
                DirStart(\%dirInfo, 5);
                my $tagTablePtr = GetTagTable('Image::ExifTool::APP12::Ducky');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            } else {
                my $tagTablePtr = GetTagTable('Image::ExifTool::APP12::PictureInfo');
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr) and $dumpType = 'Picture Info';
            }
        } elsif ($marker == 0xed) {         # APP13 (Photoshop, Adobe_CM)
            my $isOld;
            if ($$segDataPt =~ /^$psAPP13hdr/ or ($$segDataPt =~ /^$psAPP13old/ and $isOld=1)) {
                $dumpType = 'Photoshop';
                # add this data to the combined data if it exists
                my $dataPt = $segDataPt;
                if (defined $combinedSegData) {
                    $combinedSegData .= substr($$segDataPt,length($psAPP13hdr));
                    $dataPt = \$combinedSegData;
                }
                # peek ahead to see if the next segment is photoshop data too
                if ($nextMarker == $marker and $$nextSegDataPt =~ /^$psAPP13hdr/) {
                    # initialize combined data if necessary
                    $combinedSegData = $$segDataPt unless defined $combinedSegData;
                    # (will handle the Photoshop data the next time around)
                } else {
                    my $hdrLen = $isOld ? 27 : 14;
                    # process APP13 Photoshop record
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                    my %dirInfo = (
                        DataPt   => $dataPt,
                        DataPos  => $segPos,
                        DataLen  => length $$dataPt,
                        DirStart => $hdrLen,    # directory starts after identifier
                        DirLen   => length($$dataPt) - $hdrLen,
                        Parent   => $markerName,
                    );
                    $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                    undef $combinedSegData;
                }
            } elsif ($$segDataPt =~ /^Adobe_CM/) {
                $dumpType = 'Adobe_CM';
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::AdobeCM');
                DirStart(\%dirInfo, 8);
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xee) {         # APP14 (Adobe)
            if ($$segDataPt =~ /^Adobe/) {
                # extract as a block if requested, or if copying tags from file
                if ($$self{REQ_TAG_LOOKUP}{adobe} or
                    # (not extracted normally, so check TAGS_FROM_FILE)
                    ($$self{TAGS_FROM_FILE} and not $$self{EXCL_TAG_LOOKUP}{adobe}))
                {
                    $self->FoundTag('Adobe', $$segDataPt);
                }
                $dumpType = 'Adobe';
                SetByteOrder('MM');
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::Adobe');
                DirStart(\%dirInfo, 5);
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        } elsif ($marker == 0xef) {         # APP15 (GraphicConverter)
            if ($$segDataPt =~ /^Q\s*(\d+)/ and $length == 4) {
                $dumpType = 'GraphicConverter';
                my $tagTablePtr = GetTagTable('Image::ExifTool::JPEG::GraphConv');
                $self->HandleTag($tagTablePtr, 'Q', $1);
            }
        } elsif ($marker == 0xfe) {         # COM (JPEG comment)
            $dumpType = 'Comment';
            $$segDataPt =~ s/\0+$//;    # some dumb softwares add null terminators
            $self->FoundTag('Comment', $$segDataPt);
        } elsif ($marker == 0x64) {         # CME (J2C comment and extension)
            $dumpType = 'Comment';
            if ($length > 2) {
                my $reg = unpack('n', $$segDataPt); # get registration value
                my $val = substr($$segDataPt, 2);
                $val = $self->Decode($val, 'Latin') if $reg == 1;
                # (actually an extension for $reg==65535, but store as binary comment)
                $self->FoundTag('Comment', ($reg==0 or $reg==65535) ? \$val : $val);
            }
        } elsif ($marker == 0x51) {         # SIZ (J2C)
            my ($w, $h) = unpack('x2N2', $$segDataPt);
            $self->FoundTag('ImageWidth', $w);
            $self->FoundTag('ImageHeight', $h);
        } elsif (($marker & 0xf0) != 0xe0) {
            $dumpType = "$markerName segment";
            $desc = "[JPEG $markerName]";   # (other known JPEG segments)
        }
        if (defined $dumpType) {
            if (not $dumpType and $$self{OPTIONS}{Unknown}) {
                $self->Warn("Unknown $markerName segment", 1);
            }
            if ($htmlDump) {
                $desc or $desc = $markerName . ($dumpType ? " $dumpType" : '') . ' segment';
                $self->HDump($segPos-4, $length+4, $desc, $tip, 0x08);
                $dumpEnd = $segPos + $length;
            }
        }
        undef $$segDataPt;
    }
    # process extended XMP now if it existed
    if (%extendedXMP) {
        my $guid;
        # GUID indicated by the last main XMP segment
        my $goodGuid = $$self{VALUE}{HasExtendedXMP} || '';
        # GUID of the extended XMP that we will process ('2' for all)
        my $readGuid = $$self{OPTIONS}{ExtendedXMP} || 0;
        $readGuid = $goodGuid if $readGuid eq '1';
        foreach $guid (sort keys %extendedXMP) {
            next unless length $guid == 32;     # ignore other (internal) keys
            my $extXMP = $extendedXMP{$guid};
            my ($off, @offsets, $warn);
            # make sure we have all chunks, and create a list of sorted offsets
            for ($off=0; $off<$$extXMP{Size}; ) {
                last unless defined $$extXMP{$off};
                push @offsets, $off;
                $off += length $$extXMP{$off};
            }
            unless ($off == $$extXMP{Size}) {
                $self->Warn("Incomplete extended XMP (GUID $guid)");
                next;
            }
            if ($guid eq $readGuid or $readGuid eq '2') {
                $warn = 'Reading non-' if $guid ne $goodGuid;
                my $buff = '';
                # assemble XMP all together
                $buff .= $$extXMP{$_} foreach @offsets;
                my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                my %dirInfo = (
                    DataPt   => \$buff,
                    Parent   => 'APP1',
                );
                $$path[$pn] = 'APP1';
                $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
                pop @$path;
            } else {
                $warn = 'Ignored ';
                $warn .= 'non-' if $guid ne $goodGuid;
            }
            $self->Warn("${warn}standard extended XMP (GUID $guid)") if $warn;
            delete $extendedXMP{$guid};
        }
    }
    # calculate JPEGDigest if requested
    if (@dqt) {
        require Image::ExifTool::JPEGDigest;
        Image::ExifTool::JPEGDigest::Calculate($self, \@dqt, $subSampling);
    }
    # issue necessary warnings
    $self->Warn('Incomplete ICC_Profile record', 1) if defined $iccChunkCount;
    $self->Warn('Incomplete FLIR record', 1) if defined $flirCount;
    $self->Warn('Error reading PreviewImage', 1) if $$self{PreviewError};
    $success or $self->Warn('JPEG format error');
    pop @$path if @$path > $pn;
    return 1;
}

#------------------------------------------------------------------------------
# Extract metadata from an Exiv2 EXV file
# Inputs: 0) ExifTool object reference, 1) dirInfo ref with RAF set
# Returns: 1 on success, 0 if this wasn't a valid JPEG file
sub ProcessEXV($$)
{
    my ($self, $dirInfo) = @_;
    return $self->ProcessJPEG($dirInfo);
}

#------------------------------------------------------------------------------
# Process EXIF file
# Inputs/Returns: same as ProcessTIFF
sub ProcessEXIF($$;$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    return $self->ProcessTIFF($dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Process TIFF data (wrapper for DoProcessTIFF to allow re-entry)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) optional tag table ref
# Returns: 1 if this looked like a valid EXIF block, 0 otherwise, or -1 on write error
sub ProcessTIFF($$;$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $exifData = $$self{EXIF_DATA};
    my $exifPos = $$self{EXIF_POS};
    my $rtnVal = $self->DoProcessTIFF($dirInfo, $tagTablePtr);
    # restore original EXIF information (in case ProcessTIFF is nested)
    if (defined $exifData) {
        $$self{EXIF_DATA} = $exifData;
        $$self{EXIF_POS} = $exifPos;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Process TIFF data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) optional tag table ref
# Returns: 1 if this looked like a valid EXIF block, 0 otherwise, or -1 on write error
sub DoProcessTIFF($$;$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $fileType = $$dirInfo{Parent} || '';
    my $raf = $$dirInfo{RAF};
    my $base = $$dirInfo{Base} || 0;
    my $outfile = $$dirInfo{OutFile};
    my ($err, $sig, $canonSig, $otherSig);

    # attempt to read TIFF header
    $$self{EXIF_DATA} = '';
    if ($raf) {
        if ($outfile) {
            $raf->Seek(0, 0) or return 0;
            if ($base) {
                $raf->Read($$dataPt, $base) == $base or return 0;
                Write($outfile, $$dataPt) or $err = 1;
            }
        } else {
            $raf->Seek($base, 0) or return 0;
        }
        # extract full EXIF block (for block copy) from EXIF file
        my $amount = $fileType eq 'EXIF' ? 65536 * 8 : 8;
        my $n = $raf->Read($$self{EXIF_DATA}, $amount);
        if ($n < 8) {
            return 0 if $n or not $outfile or $fileType ne 'EXIF';
            # create EXIF file from scratch
            delete $$self{EXIF_DATA};
            undef $raf;
        }
        if ($n > 8) {
            $raf->Seek(8, 0);
            if ($n == $amount) {
                $$self{EXIF_DATA} = substr($$self{EXIF_DATA}, 0, 8);
                $self->Warn('EXIF too large to extract as a block'); #(shouldn't happen)
            }
        }
    } elsif ($dataPt and length $$dataPt) {
        # save a copy of the EXIF data
        my $dirStart = $$dirInfo{DirStart} || 0;
        my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
        $$self{EXIF_DATA} = substr($$dataPt, $dirStart, $dirLen);
        $self->VerboseDir('TIFF') if $$self{OPTIONS}{Verbose} and length($$self{INDENT}) > 2;
    } elsif ($outfile) {
        delete $$self{EXIF_DATA};  # create from scratch
    } else {
        $$self{EXIF_DATA} = '';
    }
    unless (defined $$self{EXIF_DATA}) {
        # create TIFF information from scratch
        if ($self->SetPreferredByteOrder() eq 'MM') {
            $$self{EXIF_DATA} = "MM\0\x2a\0\0\0\x08";
        } else {
            $$self{EXIF_DATA} = "II\x2a\0\x08\0\0\0";
        }
    }
    $$self{FIRST_EXIF_POS} = $base + $$self{BASE} unless defined $$self{FIRST_EXIF_POS};
    $$self{EXIF_POS} = $base + $$self{BASE};
    $dataPt = \$$self{EXIF_DATA};

    # set byte ordering
    my $byteOrder = substr($$dataPt,0,2);
    SetByteOrder($byteOrder) or return 0;

    # verify the byte ordering
    my $identifier = Get16u($dataPt, 2);
    # identifier is 0x2a for TIFF (but 0x4f52, 0x5352 or ?? for ORF)
  # no longer do this because various files use different values
  # (TIFF=0x2a, RW2/RWL=0x55, HDP=0xbc, BTF=0x2b, ORF=0x4f52/0x5352/0x????)
  #  return 0 unless $identifier == 0x2a;

    # get offset to IFD0
    my $offset = Get32u($dataPt, 4);
    $offset >= 8 or return 0;

    if ($raf) {
        # check for canon or EXIF signature
        # (Canon CR2 images should have an offset of 16, but it may be
        #  greater if edited by PhotoMechanic)
        if ($identifier == 0x2a and $offset >= 16) {
            $raf->Read($sig, 8) == 8 or return 0;
            $$dataPt .= $sig;
            if ($sig =~ /^(CR\x02\0|\xba\xb0\xac\xbb|ExifMeta)/) {
                if ($sig eq 'ExifMeta') {
                    $self->SetFileType($fileType = 'EXIF');
                    $otherSig = $sig;
                } else {
                    $fileType = $sig =~ /^CR/ ? 'CR2' : 'Canon 1D RAW';
                    $canonSig = $sig;
                }
                $self->HDump($base+8, 8, "[$fileType header]") if $$self{HTML_DUMP};
            }
        } elsif ($identifier == 0x55 and $fileType =~ /^(RAW|RW2|RWL|TIFF)$/) {
            # panasonic RAW, RW2 or RWL file
            my $magic;
            # test for RW2/RWL magic number
            if ($offset >= 0x18 and $raf->Read($magic, 16) and
                $magic eq "\x88\xe7\x74\xd8\xf8\x25\x1d\x4d\x94\x7a\x6e\x77\x82\x2b\x5d\x6a")
            {
                $fileType = 'RW2' unless $fileType eq 'RWL';
                $self->HDump($base + 8, 16, '[RW2/RWL header]') if $$self{HTML_DUMP};
                $otherSig = $magic; # save signature for writing
            } else {
                $fileType = 'RAW';
            }
            $tagTablePtr = GetTagTable('Image::ExifTool::PanasonicRaw::Main');
        } elsif ($fileType eq 'TIFF') {
            if ($identifier == 0x2b) {
                # this looks like a BigTIFF image
                $raf->Seek(0);
                require Image::ExifTool::BigTIFF;
                return 1 if Image::ExifTool::BigTIFF::ProcessBTF($self, $dirInfo);
            } elsif ($identifier == 0x4f52 or $identifier == 0x5352) {
                # Olympus ORF image (set FileType now because base type is 'ORF')
                $self->SetFileType($fileType = 'ORF');
            } elsif ($identifier == 0x4352) {
                $fileType = 'DCP';
            } elsif ($byteOrder eq 'II' and ($identifier & 0xff) == 0xbc) {
                $fileType = 'HDP';  # Windows HD Photo file
                # check version number
                my $ver = Get8u($dataPt, 3);
                if ($ver > 1) {
                    $self->Error("Windows HD Photo version $ver files not yet supported");
                    return 1;
                }
            }
        }
        # we have a valid TIFF (or whatever) file
        if ($fileType and not $$self{VALUE}{FileType}) {
            my $lookup = $fileTypeLookup{$fileType};
            $lookup = $fileTypeLookup{$lookup} unless ref $lookup or not $lookup;
            # use file extension to pre-determine type if extension is TIFF-based or type is RAW
            my $baseType = $lookup ? (ref $$lookup[0] ? $$lookup[0][0] : $$lookup[0]) : '';
            my $t = ($baseType eq 'TIFF' or $fileType =~ /RAW/) ? $fileType : undef;
            $self->SetFileType($t);
        }
        # don't process file if FastScan == 3
        return 1 if not $outfile and $$self{OPTIONS}{FastScan} and $$self{OPTIONS}{FastScan} == 3;
    }
    # (accomodate CR3 images which have a TIFF directory with ExifIFD at the top level)
    my $ifdName = ($$dirInfo{DirName} and $$dirInfo{DirName} =~ /^(ExifIFD|GPS)$/) ? $1 : 'IFD0';
    if (not $tagTablePtr or $$tagTablePtr{GROUPS}{0} eq 'EXIF') {
        $self->FoundTag('ExifByteOrder', $byteOrder) unless $outfile;
    } else {
        $ifdName = $$tagTablePtr{GROUPS}{1};
    }
    if ($$self{HTML_DUMP}) {
        my $tip = sprintf("Byte order: %s endian\nIdentifier: 0x%.4x\n$ifdName offset: 0x%.4x",
                          ($byteOrder eq 'II') ? 'Little' : 'Big', $identifier, $offset);
        $self->HDump($base, 8, 'TIFF header', $tip, 0);
    }
    # remember where we found the TIFF data (APP1, APP3, TIFF, NEF, etc...)
    $$self{TIFF_TYPE} = $fileType;

    # get reference to the main EXIF table
    $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');

    # build directory information hash
    my %dirInfo = (
        Base     => $base,
        DataPt   => $dataPt,
        DataLen  => length $$dataPt,
        DataPos  => 0,
        DirStart => $offset,
        DirLen   => length($$dataPt) - $offset,
        RAF      => $raf,
        DirName  => $ifdName,
        Parent   => $fileType,
        ImageData=> 'Main', # set flag to get information to copy main image data later
        Multi    => $$dirInfo{Multi},
    );

    # extract information from the image
    unless ($outfile) {
        # process the directory
        $self->ProcessDirectory(\%dirInfo, $tagTablePtr);
        # process GeoTiff information if available
        if ($$self{VALUE}{GeoTiffDirectory}) {
            require Image::ExifTool::GeoTiff;
            Image::ExifTool::GeoTiff::ProcessGeoTiff($self);
        }
        # process information in recognized trailers
        if ($raf) {
            my $trailInfo = IdentifyTrailer($raf);
            if ($trailInfo) {
                $$trailInfo{ScanForAFCP} = 1;   # scan to find AFCP if necessary
                $self->ProcessTrailers($trailInfo);
            }
            # dump any other known trailer (eg. A100 RAW Data)
            if ($$self{HTML_DUMP} and $$self{KnownTrailer}) {
                my $known = $$self{KnownTrailer};
                $raf->Seek(0, 2);
                my $len = $raf->Tell() - $$known{Start};
                $len -= $$trailInfo{Offset} if $trailInfo;  # account for other trailers
                $self->HDump($$known{Start}, $len, "[$$known{Name}]") if $len > 0;
           }
        }
        # update FileType if necessary now that we know more about the file
        if ($$self{DNGVersion} and $$self{VALUE}{FileType} !~ /^(DNG|GPR)$/) {
            # override whatever FileType we set since we now know it is DNG
            $self->OverrideFileType($$self{TIFF_TYPE} = 'DNG');
        }
        return 1;
    }
#
# rewrite the image
#
    if ($$dirInfo{NoTiffEnd}) {
        delete $$self{TIFF_END};
    } else {
        # initialize TIFF_END so it will be updated by WriteExif()
        $$self{TIFF_END} = 0;
    }
    if ($canonSig) {
        # write Canon CR2 specially because it has a header we want to preserve,
        # and possibly trailers added by the Canon utilities and/or PhotoMechanic
        $dirInfo{OutFile} = $outfile;
        require Image::ExifTool::CanonRaw;
        Image::ExifTool::CanonRaw::WriteCR2($self, \%dirInfo, $tagTablePtr) or $err = 1;
    } else {
        # write TIFF header (8 bytes [plus optional signature] followed by IFD)
        if ($fileType eq 'EXIF') {
            $otherSig = 'ExifMeta'; # force this signature for all EXIF files
        } elsif (not defined $otherSig) {
            $otherSig = '';
        }
        my $offset = 8 + length($otherSig);
        # construct tiff header
        my $header = substr($$dataPt, 0, 4) . Set32u($offset) . $otherSig;
        $dirInfo{NewDataPos} = $offset;
        $dirInfo{HeaderPtr} = \$header;
        # preserve padding between image data blocks in ORF images
        # (otherwise dcraw has problems because it assumes fixed block spacing)
        $dirInfo{PreserveImagePadding} = 1 if $fileType eq 'ORF' or $identifier != 0x2a;
        my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
        if (not defined $newData) {
            $err = 1;
        } elsif (length($newData)) {
            # update header length in case more was added
            my $hdrLen = length $header;
            if ($hdrLen != 8) {
                Set32u($hdrLen, \$header, 4);
                # also update preview fixup if necessary
                my $pi = $$self{PREVIEW_INFO};
                $$pi{Fixup}{Start} += $hdrLen - 8 if $pi and $$pi{Fixup};
            }
            if ($$self{TIFF_TYPE} eq 'ARW' and not $err) {
                # write any required ARW trailer and patch other ARW quirks
                require Image::ExifTool::Sony;
                my $errStr = Image::ExifTool::Sony::FinishARW($self, $dirInfo, \$newData,
                                                              $dirInfo{ImageData});
                $errStr and $self->Error($errStr);
                delete $dirInfo{ImageData}; # (was copied by FinishARW)
            } else {
                Write($outfile, $header, $newData) or $err = 1;
            }
            undef $newData; # free memory
        }
        # copy over image data now if necessary
        if (ref $dirInfo{ImageData} and not $err) {
            $self->CopyImageData($dirInfo{ImageData}, $outfile) or $err = 1;
            delete $dirInfo{ImageData};
        }
    }
    # make local copy of TIFF_END now (it may be reset when processing trailers)
    my $tiffEnd = $$self{TIFF_END};
    delete $$self{TIFF_END};

    # rewrite trailers if they exist
    if ($raf and $tiffEnd and not $err) {
        my ($buf, $trailInfo);
        $raf->Seek(0, 2) or $err = 1;
        my $extra = $raf->Tell() - $tiffEnd;
        # check for trailer and process if possible
        for (;;) {
            last unless $extra > 12;
            $raf->Seek($tiffEnd);  # seek back to end of image
            $trailInfo = IdentifyTrailer($raf);
            last unless $trailInfo;
            my $tbuf = '';
            $$trailInfo{OutFile} = \$tbuf;  # rewrite trailer(s)
            $$trailInfo{ScanForAFCP} = 1;   # scan for AFCP if necessary
            # rewrite all trailers to buffer
            unless ($self->ProcessTrailers($trailInfo)) {
                undef $trailInfo;
                $err = 1;
                last;
            }
            # calculate unused bytes before trailer
            $extra = $$trailInfo{DataPos} - $tiffEnd;
            last; # yes, the 'for' loop was just a cheap 'goto'
        }
        # ignore a single zero byte if used for padding
        if ($extra > 0 and $tiffEnd & 0x01) {
            $raf->Seek($tiffEnd, 0) or $err = 1;
            $raf->Read($buf, 1) or $err = 1;
            defined $buf and $buf eq "\0" and --$extra, ++$tiffEnd;
        }
        if ($extra > 0) {
            my $known = $$self{KnownTrailer};
            if ($$self{DEL_GROUP}{Trailer} and not $known) {
                $self->VPrint(0, "  Deleting unknown trailer ($extra bytes)\n");
                ++$$self{CHANGED};
            } elsif ($known) {
                $self->VPrint(0, "  Copying $$known{Name} ($extra bytes)\n");
                $raf->Seek($tiffEnd, 0) or $err = 1;
                CopyBlock($raf, $outfile, $extra) or $err = 1;
            } else {
                $raf->Seek($tiffEnd, 0) or $err = 1;
                # preserve unknown trailer only if it contains non-null data
                # (Photoshop CS adds a trailer with 2 null bytes)
                my $size = $extra;
                for (;;) {
                    my $n = $size > 65536 ? 65536 : $size;
                    $raf->Read($buf, $n) == $n or $err = 1, last;
                    if ($buf =~ /[^\0]/) {
                        $self->VPrint(0, "  Preserving unknown trailer ($extra bytes)\n");
                        # copy the trailer since it contains non-null data
                        Write($outfile, "\0"x($extra-$size)) or $err = 1, last if $size != $extra;
                        Write($outfile, $buf) or $err = 1, last;
                        CopyBlock($raf, $outfile, $size-$n) or $err = 1 if $size > $n;
                        last;
                    }
                    $size -= $n;
                    next if $size > 0;
                    $self->VPrint(0, "  Deleting blank trailer ($extra bytes)\n");
                    last;
                }
            }
        }
        # write trailer buffer if necessary
        $self->WriteTrailerBuffer($trailInfo, $outfile) or $err = 1 if $trailInfo;
        # add any new trailers we are creating
        my $trailPt = $self->AddNewTrailers();
        Write($outfile, $$trailPt) or $err = 1 if $trailPt;
    }
    # check DNG version
    if ($$self{DNGVersion}) {
        my $ver = $$self{DNGVersion};
        # currently support up to DNG version 1.4
        unless ($ver =~ /^(\d+) (\d+)/ and "$1.$2" <= 1.4) {
            $ver =~ tr/ /./;
            $self->Error("DNG Version $ver not yet tested", 1);
        }
    }
    return $err ? -1 : 1;
}

#------------------------------------------------------------------------------
# Return list of tag table keys (ignoring special keys)
# Inputs: 0) reference to tag table
# Returns: List of table keys (unsorted)
sub TagTableKeys($)
{
    local $_;
    my $tagTablePtr = shift;
    my @keyList;
    foreach (keys %$tagTablePtr) {
        push(@keyList, $_) unless $specialTags{$_};
    }
    return @keyList;
}

#------------------------------------------------------------------------------
# GetTagTable
# Inputs: 0) table name
# Returns: tag table reference, or undefined if not found
# Notes: Always use this function instead of requiring module and using table
# directly since this function also does the following the first time the table
# is loaded:
# - requires new module if necessary
# - generates default GROUPS hash and Group 0 name from module name
# - registers Composite tags if Composite table found
# - saves descriptions for tags in specified table
# - generates default TAG_PREFIX to be used for unknown tags
sub GetTagTable($)
{
    my $tableName = shift or return undef;
    my $table = $allTables{$tableName};

    unless ($table) {
        no strict 'refs';
        unless (%$tableName) {
            # try to load module for this table
            if ($tableName =~ /(.*)::/) {
                my $module = $1;
                if (eval "require $module") {
                    # load additional modules if required
                    if (not %$tableName) {
                        if ($module eq 'Image::ExifTool::XMP') {
                            require 'Image/ExifTool/XMP2.pl';
                        } elsif ($tableName eq 'Image::ExifTool::QuickTime::Stream') {
                            require 'Image/ExifTool/QuickTimeStream.pl';
                        }
                    }
                } else {
                    $@ and warn $@;
                }
            }
            unless (%$tableName) {
                warn "Can't find table $tableName\n";
                return undef;
            }
        }
        no strict 'refs';
        $table = \%$tableName;
        use strict 'refs';
        $$table{TABLE_NAME} = $tableName;   # set table name
        ($$table{SHORT_NAME} = $tableName) =~ s/^Image::ExifTool:://;
        # set default group 0 and 1 from module name unless already specified
        my $defaultGroups = $$table{GROUPS};
        $defaultGroups or $defaultGroups = $$table{GROUPS} = { };
        unless ($$defaultGroups{0} and $$defaultGroups{1}) {
            if ($tableName =~ /Image::.*?::([^:]*)/) {
                $$defaultGroups{0} = $1 unless $$defaultGroups{0};
                $$defaultGroups{1} = $1 unless $$defaultGroups{1};
            } else {
                $$defaultGroups{0} = $tableName unless $$defaultGroups{0};
                $$defaultGroups{1} = $tableName unless $$defaultGroups{1};
            }
        }
        $$defaultGroups{2} = 'Other' unless $$defaultGroups{2};
        if ($$defaultGroups{0} eq 'XMP' or $$table{NAMESPACE}) {
            # initialize some XMP table defaults
            require Image::ExifTool::XMP;
            Image::ExifTool::XMP::RegisterNamespace($table); # register all table namespaces
            # set default write/check procs
            $$table{WRITE_PROC} = \&Image::ExifTool::XMP::WriteXMP unless $$table{WRITE_PROC};
            $$table{CHECK_PROC} = \&Image::ExifTool::XMP::CheckXMP unless $$table{CHECK_PROC};
            $$table{LANG_INFO} = \&Image::ExifTool::XMP::GetLangInfo unless $$table{LANG_INFO};
        }
        # generate a tag prefix for unknown tags if necessary
        unless (defined $$table{TAG_PREFIX}) {
            my $tagPrefix;
            if ($tableName =~ /Image::.*?::(.*)::Main/ || $tableName =~ /Image::.*?::(.*)/) {
                ($tagPrefix = $1) =~ s/::/_/g;
            } else {
                $tagPrefix = $tableName;
            }
            $$table{TAG_PREFIX} = $tagPrefix;
        }
        # set up the new table
        SetupTagTable($table);
        # add any user-defined tags (except Composite tags, which are handled specially)
        if (%UserDefined and $UserDefined{$tableName} and $table ne \%Image::ExifTool::Composite) {
            my $tagID;
            foreach $tagID (TagTableKeys($UserDefined{$tableName})) {
                next if $specialTags{$tagID};
                delete $$table{$tagID}; # replace any existing entry
                AddTagToTable($table, $tagID, $UserDefined{$tableName}{$tagID}, 1);
            }
        }
        # remember order we loaded the tables in
        push @tableOrder, $tableName;
        # insert newly loaded table into list
        $allTables{$tableName} = $table;
    }
    # must check each time to add UserDefined Composite tags because the Composite table
    # may be loaded before the UserDefined tags are available
    if ($table eq \%Image::ExifTool::Composite and not $$table{VARS}{LOADED_USERDEFINED} and
        %UserDefined and $UserDefined{$tableName})
    {
        my $userComp = $UserDefined{$tableName};
        delete $UserDefined{$tableName};        # (must delete first to avoid infinite recursion)
        AddCompositeTags($userComp, 1);
        $UserDefined{$tableName} = $userComp;   # (add back again for adding writable tags later)
        $$table{VARS}{LOADED_USERDEFINED} = 1;  # set flag to avoid doing this again
    }
    return $table;
}

#------------------------------------------------------------------------------
# Process an image directory
# Inputs: 0) ExifTool object reference, 1) directory information reference
#         2) tag table reference, 3) optional reference to processing procedure
# Returns: Result from processing (1=success)
sub ProcessDirectory($$$;$)
{
    my ($self, $dirInfo, $tagTablePtr, $proc) = @_;

    return 0 unless $tagTablePtr and $dirInfo;
    # use default proc from tag table or EXIF proc as fallback if no proc specified
    $proc or $proc = $$tagTablePtr{PROCESS_PROC} || \&Image::ExifTool::Exif::ProcessExif;
    # set directory name from default group0 name if not done already
    my $dirName = $$dirInfo{DirName};
    unless ($dirName) {
        $dirName = $$tagTablePtr{GROUPS}{0};
        $dirName = $$tagTablePtr{GROUPS}{1} if $dirName =~ /^APP\d+$/; # (use specific APP name)
        $$dirInfo{DirName} = $dirName;
    }
    
    # guard against cyclical recursion into the same directory
    if (defined $$dirInfo{DirStart} and defined $$dirInfo{DataPos} and
        # directories don't overlap if the length is zero
        ($$dirInfo{DirLen} or not defined $$dirInfo{DirLen}))
    {
        my $addr = $$dirInfo{DirStart} + $$dirInfo{DataPos} + ($$dirInfo{Base}||0) + $$self{BASE};
        if ($$self{PROCESSED}{$addr}) {
            $self->Warn("$dirName pointer references previous $$self{PROCESSED}{$addr} directory");
            # patch for bug in Windows phone 7.5 O/S that writes incorrect InteropIFD pointer
            return 0 unless $dirName eq 'GPS' and $$self{PROCESSED}{$addr} eq 'InteropIFD';
        }
        $$self{PROCESSED}{$addr} = $dirName;
    }
    my $oldOrder = GetByteOrder();
    my @save = @$self{'INDENT','DIR_NAME','Compression','SubfileType'};
    $$self{LIST_TAGS} = { };    # don't build lists across different directories
    $$self{INDENT} .= '| ';
    $$self{DIR_NAME} = $dirName;
    push @{$$self{PATH}}, $dirName;
    $$self{FOUND_DIR}{$dirName} = 1;

    # process the directory
    my $rtnVal = &$proc($self, $dirInfo, $tagTablePtr);

    pop @{$$self{PATH}};
    @$self{'INDENT','DIR_NAME','Compression','SubfileType'} = @save;
    SetByteOrder($oldOrder);
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Get Metadata path
# Inputs: 0) Exiftool object ref
# Return: Metadata path string
sub MetadataPath($)
{
    my $self = shift;
    return join '-', @{$$self{PATH}}
}

#------------------------------------------------------------------------------
# Get standardized file extension
# Inputs: 0) file name
# Returns: standardized extension (all uppercase), or undefined if no extension
sub GetFileExtension($)
{
    my $filename = shift;
    my $fileExt;
    if ($filename and $filename =~ /^.*\.([^.]+)$/s) {
        $fileExt = uc($1);   # change extension to upper case
        # convert TIF extension to TIFF because we use the
        # extension for the file type tag of TIFF images
        $fileExt eq 'TIF' and $fileExt = 'TIFF';
    }
    return $fileExt;
}

#------------------------------------------------------------------------------
# Get list of tag information hashes for given tag ID
# Inputs: 0) Tag table reference, 1) tag ID
# Returns: Array of tag information references
# Notes: Generates tagInfo hash if necessary
sub GetTagInfoList($$)
{
    my ($tagTablePtr, $tagID) = @_;
    my $tagInfo = $$tagTablePtr{$tagID};

    if ($specialTags{$tagID}) {
        # (hopefully this won't happen)
        warn "Tag $tagID conflicts with internal ExifTool variable in $$tagTablePtr{TABLE_NAME}\n";
    } elsif (ref $tagInfo eq 'HASH') {
        return ($tagInfo);
    } elsif (ref $tagInfo eq 'ARRAY') {
        return @$tagInfo;
    } elsif ($tagInfo) {
        # create hash with name
        $tagInfo = $$tagTablePtr{$tagID} = { Name => $tagInfo };
        return ($tagInfo);
    }
    return ();
}

#------------------------------------------------------------------------------
# Find tag information, processing conditional tags
# Inputs: 0) ExifTool object reference, 1) tagTable pointer, 2) tag ID
#         3) optional value reference, 4) optional format type, 5) optional value count
# Returns: pointer to tagInfo hash, undefined if none found, or '' if $valPt needed
# Notes: You should always call this routine to find a tag in a table because
# this routine will evaluate conditional tags.
# Arguments 3-5 are only required if the information type allows $valPt, $format and/or
# $count in a Condition, and if not given when needed this routine returns ''.
sub GetTagInfo($$$;$$$)
{
    my ($self, $tagTablePtr, $tagID) = @_;
    my ($valPt, $format, $count);

    my @infoArray = GetTagInfoList($tagTablePtr, $tagID);
    # evaluate condition
    my $tagInfo;
    foreach $tagInfo (@infoArray) {
        my $condition = $$tagInfo{Condition};
        if ($condition) {
            ($valPt, $format, $count) = splice(@_, 3) if @_ > 3;
            return '' if $condition =~ /\$(valPt|format|count)\b/ and not defined $valPt;
            # set old value for use in condition if needed
            local $SIG{'__WARN__'} = \&SetWarning;
            undef $evalWarning;
            #### eval Condition ($self, [$valPt, $format, $count])
            unless (eval $condition) {
                $@ and $evalWarning = $@;
                $self->Warn("Condition $$tagInfo{Name}: " . CleanWarning()) if $evalWarning;
                next;
            }
        }
        if ($$tagInfo{Unknown} and not $$self{OPTIONS}{Unknown} and not $$self{OPTIONS}{Verbose}) {
            # don't return Unknown tags unless that option is set
            return undef;
        }
        # return the tag information we found
        return $tagInfo;
    }
    # generate information for unknown tags (numerical only) if required
    if (not $tagInfo and ($$self{OPTIONS}{Unknown} or $$self{OPTIONS}{Verbose}) and
        $tagID =~ /^\d+$/ and not $$self{NO_UNKNOWN})
    {
        my $printConv;
        if (defined $$tagTablePtr{PRINT_CONV}) {
            $printConv = $$tagTablePtr{PRINT_CONV};
        } else {
            # limit length of printout (can be very long)
            $printConv = 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val';
        }
        my $hex = sprintf("0x%.4x", $tagID);
        my $prefix = $$tagTablePtr{TAG_PREFIX};
        $tagInfo = {
            Name => "${prefix}_$hex",
            Description => MakeDescription($prefix, $hex),
            Unknown => 1,
            Writable => 0,  # can't write unknown tags
            PrintConv => $printConv,
        };
        # add tag information to table
        AddTagToTable($tagTablePtr, $tagID, $tagInfo);
    } else {
        undef $tagInfo;
    }
    return $tagInfo;
}

#------------------------------------------------------------------------------
# Add new tag to table (must use this routine to add new tags to a table)
# Inputs: 0) reference to tag table, 1) tag ID
#         2) [optional] tag name or reference to tag information hash
#         3) [optional] flag to avoid adding prefix when generating tag name
# Notes: - will not override existing entry in table
# - info need contain no entries when this routine is called
# - tag name is made valid if necessary
sub AddTagToTable($$;$$)
{
    my ($tagTablePtr, $tagID, $tagInfo, $noPrefix) = @_;

    # generate tag info hash if necessary
    $tagInfo = $tagInfo ? { Name => $tagInfo } : { } unless ref $tagInfo eq 'HASH';

    # define necessary entries in information hash
    if ($$tagInfo{Groups}) {
        # fill in default groups from table GROUPS
        foreach (keys %{$$tagTablePtr{GROUPS}}) {
            next if $$tagInfo{Groups}{$_};
            $$tagInfo{Groups}{$_} = $$tagTablePtr{GROUPS}{$_};
        }
    } else {
        $$tagInfo{Groups} = { %{$$tagTablePtr{GROUPS}} };
    }
    $$tagInfo{Flags} and ExpandFlags($tagInfo);
    $$tagInfo{GotGroups} = 1,
    $$tagInfo{Table} = $tagTablePtr;
    $$tagInfo{TagID} = $tagID;

    my $name = $$tagInfo{Name};
    $name = $tagID unless defined $name;
    $name =~ tr/-_a-zA-Z0-9//dc;    # remove illegal characters
    $name = ucfirst $name;          # capitalize first letter
    # add tag-name prefix if specified and tag name not provided
    unless (defined $$tagInfo{Name} or $noPrefix or not $$tagTablePtr{TAG_PREFIX}) {
        # make description to prevent tagID from getting mangled by MakeDescription()
        $$tagInfo{Description} = MakeDescription($$tagTablePtr{TAG_PREFIX}, $name);
        $name = "$$tagTablePtr{TAG_PREFIX}_$name";
    }
    # tag names must be at least 2 characters long and prefer them to start with a letter
    $name = "Tag$name" if length($name) < 2 or $name !~ /^[A-Z]/i;
    $$tagInfo{Name} = $name;
    # add tag to table, but never override existing entries (could potentially happen
    # if someone thinks there isn't any tagInfo because a condition wasn't satisfied)
    unless (defined $$tagTablePtr{$tagID} or $specialTags{$tagID}) {
        $$tagTablePtr{$tagID} = $tagInfo;
    }
}

#------------------------------------------------------------------------------
# Handle simple extraction of new tag information
# Inputs: 0) ExifTool object ref, 1) tag table reference, 2) tagID, 3) value,
#         4-N) parameters hash: Index, DataPt, DataPos, Base, Start, Size, Parent,
#              TagInfo, ProcessProc, RAF, Format
# Returns: tag key or undef if tag not found
# Notes: if value is not defined, it is extracted from DataPt using TagInfo
#        Format and Count if provided
sub HandleTag($$$$;%)
{
    my ($self, $tagTablePtr, $tag, $val, %parms) = @_;
    my $verbose = $$self{OPTIONS}{Verbose};
    my $pfmt = $parms{Format};
    my $tagInfo = $parms{TagInfo} || $self->GetTagInfo($tagTablePtr, $tag, \$val, $pfmt, $parms{Count});
    my $dataPt = $parms{DataPt};
    my ($subdir, $format, $noTagInfo, $rational);

    if ($tagInfo) {
        $subdir = $$tagInfo{SubDirectory}
    } else {
        return undef unless $verbose;
        $tagInfo = { Name => "tag $tag" };  # create temporary tagInfo hash
        $noTagInfo = 1;
    }
    # read value if not done already (not necessary for subdir)
    unless (defined $val or ($subdir and not $$tagInfo{Writable} and not $$tagInfo{RawConv})) {
        my $start = $parms{Start} || 0;
        my $dLen = $dataPt ? length($$dataPt) : -1;
        my $size = $parms{Size};
        $size = $dLen unless defined $size;
        # read from data in memory if possible
        if ($start >= 0 and $start + $size <= $dLen) {
            $format = $$tagInfo{Format} || $$tagTablePtr{FORMAT};
            $format = $pfmt if not $format and $pfmt and $formatSize{$pfmt};
            if ($format) {
                $val = ReadValue($dataPt, $start, $format, $$tagInfo{Count}, $size, \$rational);
            } else {
                $val = substr($$dataPt, $start, $size);
            }
        } else {
            $self->Warn("Error extracting value for $$tagInfo{Name}");
            return undef;
        }
    }
    # do verbose print if necessary
    if ($verbose) {
        undef $tagInfo if $noTagInfo;
        $parms{Value} = $val;
        $parms{Value} .= " ($rational)" if defined $rational;
        $parms{Table} = $tagTablePtr;
        if ($format) {
            my $count = int(($parms{Size} || 0) / ($formatSize{$format} || 1));
            $parms{Format} = $format . "[$count]";
        }
        $self->VerboseInfo($tag, $tagInfo, %parms);
    }
    if ($tagInfo) {
        if ($subdir) {
            my $subdirStart = $parms{Start};
            my $subdirLen = $parms{Size};
            if ($$tagInfo{RawConv} and not $$tagInfo{Writable}) {
                my $conv = $$tagInfo{RawConv};
                local $SIG{'__WARN__'} = \&SetWarning;
                undef $evalWarning;
                if (ref $conv eq 'CODE') {
                    $val = &$conv($val, $self);
                } else {
                    my ($priority, @grps);
                    # NOTE: RawConv is evaluated in Writer.pl and twice in ExifTool.pm
                    #### eval RawConv ($self, $val, $tag, $tagInfo, $priority, @grps)
                    $val = eval $conv;
                    $@ and $evalWarning = $@;
                }
                $self->Warn("RawConv $tag: " . CleanWarning()) if $evalWarning;
                return undef unless defined $val;
                $val = $$val if ref $val eq 'SCALAR';
                $dataPt = \$val;
                $subdirStart = 0;
                $subdirLen = length $val;
            }
            if ($$subdir{Start}) {
                my $valuePtr = 0;
                #### eval Start ($valuePtr)
                my $off = eval $$subdir{Start};
                $subdirStart += $off;
                $subdirLen -= $off;
            }
            $dataPt or $dataPt = \$val;
            # process subdirectory information
            my %dirInfo = (
                DirName  => $$subdir{DirName} || $$tagInfo{Name},
                DataPt   => $dataPt,
                DataLen  => length $$dataPt,
                DataPos  => $parms{DataPos},
                DirStart => $subdirStart,
                DirLen   => $subdirLen,
                Parent   => $parms{Parent},
                Base     => $parms{Base},
                Multi    => $$subdir{Multi},
                TagInfo  => $tagInfo,
                RAF      => $parms{RAF},
            );
            my $oldOrder = GetByteOrder();
            if ($$subdir{ByteOrder}) {
                if ($$subdir{ByteOrder} eq 'Unknown') {
                    if ($subdirStart + 2 <= $subdirLen) {
                        # attempt to determine the byte ordering of an IFD-style subdirectory
                        my $num = Get16u($dataPt, $subdirStart);
                        ToggleByteOrder if $num & 0xff00 and ($num>>8) > ($num&0xff);
                    }
                } else {
                    SetByteOrder($$subdir{ByteOrder});
                }
            }
            my $subTablePtr = GetTagTable($$subdir{TagTable}) || $tagTablePtr;
            $self->ProcessDirectory(\%dirInfo, $subTablePtr, $$subdir{ProcessProc} || $parms{ProcessProc});
            SetByteOrder($oldOrder);
            # return now unless directory is writable as a block
            return undef unless $$tagInfo{Writable};
        }
        my $key = $self->FoundTag($tagInfo, $val);
        # save original components of rational numbers
        $$self{RATIONAL}{$key} = $rational if defined $rational and defined $key;
        return $key;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Add tag to hash of extracted information
# Inputs: 0) ExifTool object reference
#         1) reference to tagInfo hash or tag name
#         2) data value (or reference to require hash if Composite)
#         3) optional family 0 group, 4) optional family 1 group
# Returns: tag key or undef if no value
sub FoundTag($$$;@)
{
    local $_;
    my ($self, $tagInfo, $value, @grps) = @_;
    my ($tag, $noListDel);
    my $options = $$self{OPTIONS};

    if (ref $tagInfo eq 'HASH') {
        $tag = $$tagInfo{Name} or warn("No tag name\n"), return undef;
    } else {
        $tag = $tagInfo;
        # look for tag in Extra
        $tagInfo = $self->GetTagInfo(GetTagTable('Image::ExifTool::Extra'), $tag);
        # make temporary hash if tag doesn't exist in Extra
        # (not advised to do this since the tag won't show in list)
        $tagInfo or $tagInfo = { Name => $tag, Groups => \%allGroupsExifTool };
        $$options{Verbose} and $self->VerboseInfo(undef, $tagInfo, Value => $value);
    }
    # get tag priority
    my $priority = $$tagInfo{Priority};
    unless (defined $priority) {
        $priority = $$tagInfo{Table}{PRIORITY};
        $priority = 0 if not defined $priority and $$tagInfo{Avoid};
    }
    $grps[0] or $grps[0] = $$self{SET_GROUP0};
    $grps[1] or $grps[1] = $$self{SET_GROUP1};
    my $valueHash = $$self{VALUE};

    if ($$tagInfo{RawConv}) {
        # initialize @val for use in Composite RawConv expressions
        my @val;
        if (ref $value eq 'HASH' and $$tagInfo{IsComposite}) {
            foreach (keys %$value) { $val[$_] = $$valueHash{$$value{$_}}; }
        }
        my $conv = $$tagInfo{RawConv};
        local $SIG{'__WARN__'} = \&SetWarning;
        undef $evalWarning;
        if (ref $conv eq 'CODE') {
            $value = &$conv($value, $self);
            $$self{grps} and @grps = @{$$self{grps}}, delete $$self{grps};
        } else {
            my $val = $value;   # do this so eval can use $val
            # NOTE: RawConv is also evaluated in Writer.pl
            #### eval RawConv ($self, $val, $tag, $tagInfo, $priority, @grps)
            $value = eval $conv;
            $@ and $evalWarning = $@;
        }
        $self->Warn("RawConv $tag: " . CleanWarning()) if $evalWarning;
        return undef unless defined $value;
    }
    # handle duplicate tag names
    if (defined $$valueHash{$tag}) {
        # add to list if there is an active list for this tag
        if ($$self{LIST_TAGS}{$tagInfo}) {
            $tag = $$self{LIST_TAGS}{$tagInfo}; # use key from previous list tag
            if (defined $$self{NO_LIST}) {
                # accumulate list in TAG_EXTRA "NoList" element
                if (defined $$self{TAG_EXTRA}{$tag}{NoList}) {
                    push @{$$self{TAG_EXTRA}{$tag}{NoList}}, $value;
                } else {
                    $$self{TAG_EXTRA}{$tag}{NoList} = [ $$valueHash{$tag}, $value ];
                }
                $noListDel = 1; # set flag to delete this tag if re-listed
            } else {
                if (ref $$valueHash{$tag} ne 'ARRAY') {
                    $$valueHash{$tag} = [ $$valueHash{$tag} ];
                }
                push @{$$valueHash{$tag}}, $value;
                return $tag;    # return without creating a new entry
            }
        }
        # get next available tag key
        my $nextInd = $$self{DUPL_TAG}{$tag} = ($$self{DUPL_TAG}{$tag} || 0) + 1;
        my $nextTag = "$tag ($nextInd)";
#
# take tag with highest priority
#
        # promote existing 0-priority tag so it takes precedence over a new 0-tag
        # (unless old tag was a sub-document and new tag isn't.  Also, never override
        #  a Warning tag because they may be added by ValueConv, which could be confusing)
        my $oldPriority = $$self{PRIORITY}{$tag};
        unless ($oldPriority) {
            if ($$self{DOC_NUM} or not $$self{TAG_EXTRA}{$tag} or $tag eq 'Warning' or
                                   not $$self{TAG_EXTRA}{$tag}{G3})
            {
                $oldPriority = 1;
            } else {
                $oldPriority = 0; # don't promote sub-document tag over main document
            }
        }
        # set priority for this tag
        if (defined $priority) {
            # increase 0-priority tags if this is the priority directory
            $priority = 1 if not $priority and $$self{DIR_NAME} and
                             $$self{DIR_NAME} eq $$self{PRIORITY_DIR};
        } elsif ($$self{DIR_NAME} and $$self{LOW_PRIORITY_DIR}{$$self{DIR_NAME}}) {
            $priority = 0;  # default is 0 for a LOW_PRIORITY_DIR
        } else {
            $priority = 1;  # the normal default
        }
        if ($priority >= $oldPriority and not $$self{DOC_NUM} and not $noListDel) {
            # move existing tag out of the way since this tag is higher priority
            # (NOTE: any new members added here must also be added to DeleteTag())
            $$self{MOVED_KEY} = $nextTag;  # used in BuildCompositeTags()
            $$self{PRIORITY}{$nextTag} = $$self{PRIORITY}{$tag};
            $$valueHash{$nextTag} = $$valueHash{$tag};
            $$self{FILE_ORDER}{$nextTag} = $$self{FILE_ORDER}{$tag};
            my $oldInfo = $$self{TAG_INFO}{$nextTag} = $$self{TAG_INFO}{$tag};
            foreach ('TAG_EXTRA','RATIONAL') {
                if ($$self{$_}{$tag}) {
                    $$self{$_}{$nextTag} = $$self{$_}{$tag};
                    delete $$self{$_}{$tag};
                }
            }
            delete $$self{BOTH}{$tag};
            # update tag key for list if necessary
            $$self{LIST_TAGS}{$oldInfo} = $nextTag if $$self{LIST_TAGS}{$oldInfo};
        } else {
            $tag = $nextTag;        # don't override the existing tag
        }
        $$self{PRIORITY}{$tag} = $priority;
        $$self{TAG_EXTRA}{$tag}{NoListDel} = 1 if $noListDel;
    } elsif ($priority) {
        # set tag priority (only if exists and is non-zero)
        $$self{PRIORITY}{$tag} = $priority;
    }

    # save the raw value, file order, tagInfo ref, group1 name,
    # and tag key for lists if necessary
    $$valueHash{$tag} = $value;
    $$self{FILE_ORDER}{$tag} = ++$$self{NUM_FOUND};
    $$self{TAG_INFO}{$tag} = $tagInfo;
    # set dynamic groups 0, 1 and 3 if necessary
    $$self{TAG_EXTRA}{$tag}{G0} = $grps[0] if $grps[0];
    $$self{TAG_EXTRA}{$tag}{G1} = $grps[1] if $grps[1];
    if ($$self{DOC_NUM}) {
        $$self{TAG_EXTRA}{$tag}{G3} = $$self{DOC_NUM};
        if ($$self{DOC_NUM} =~ /^(\d+)/) {
            # keep track of maximum 1st-level sub-document number
            $$self{DOC_COUNT} = $1 unless $$self{DOC_COUNT} >= $1;
        }
    }
    # save path if requested
    $$self{TAG_EXTRA}{$tag}{G5} = $self->MetadataPath() if $$options{SavePath};

    # remember this tagInfo if we will be accumulating values in a list
    # (but don't override earlier list if this may be deleted by NoListDel flag)
    if ($$tagInfo{List} and not $$self{NO_LIST} and not $noListDel) {
        $$self{LIST_TAGS}{$tagInfo} = $tag;
    }

    # validate tag if requested (but only for simple values -- could result
    # in infinite recursion if called for a Composite tag (HASH ref value)
    # because FoundTag is called in the middle of building Composite tags
    if ($$options{Validate} and not ref $value) {
        Image::ExifTool::Validate::ValidateRaw($self, $tag, $value);
    }

    return $tag;
}

#------------------------------------------------------------------------------
# Make current directory the priority directory if not set already
# Inputs: 0) ExifTool object reference
sub SetPriorityDir($)
{
    my $self = shift;
    $$self{PRIORITY_DIR} = $$self{DIR_NAME} unless $$self{PRIORITY_DIR};
}

#------------------------------------------------------------------------------
# Set family 0 or 1 group name specific to this tag instance
# Inputs: 0) ExifTool ref, 1) tag key, 2) group name, 3) family (default 1)
sub SetGroup($$$;$)
{
    my ($self, $tagKey, $extra, $fam) = @_;
    $$self{TAG_EXTRA}{$tagKey}{defined $fam ? "G$fam" : 'G1'} = $extra;
}

#------------------------------------------------------------------------------
# Delete specified tag
# Inputs: 0) ExifTool object ref, 1) tag key
sub DeleteTag($$)
{
    my ($self, $tag) = @_;
    delete $$self{VALUE}{$tag};
    delete $$self{FILE_ORDER}{$tag};
    delete $$self{TAG_INFO}{$tag};
    delete $$self{TAG_EXTRA}{$tag};
    delete $$self{PRIORITY}{$tag};
    delete $$self{RATIONAL}{$tag};
    delete $$self{BOTH}{$tag};
}

#------------------------------------------------------------------------------
# Escape all elements of a value
# Inputs: 0) value, 1) escape proc
sub DoEscape($$)
{
    my ($val, $key);
    if (not ref $_[0]) {
        $_[0] = &{$_[1]}($_[0]);
    } elsif (ref $_[0] eq 'ARRAY') {
        foreach $val (@{$_[0]}) {
            DoEscape($val, $_[1]);
        }
    } elsif (ref $_[0] eq 'HASH') {
        foreach $key (keys %{$_[0]}) {
            DoEscape($_[0]{$key}, $_[1]);
        }
    }
}

#------------------------------------------------------------------------------
# Set the FileType and MIMEType tags
# Inputs: 0) ExifTool object reference
#         1) Optional file type (uses FILE_TYPE if not specified)
#         2) Optional MIME type (uses our lookup if not specified)
#         3) Optional recommended extension (converted to lower case; uses FileType if undef)
# Notes:  Will NOT set file type twice (subsequent calls ignored)
sub SetFileType($;$$$)
{
    my ($self, $fileType, $mimeType, $normExt) = @_;
    unless ($$self{VALUE}{FileType} and not $$self{DOC_NUM}) {
        my $baseType = $$self{FILE_TYPE};
        my $ext = $$self{FILE_EXT};
        $fileType or $fileType = $baseType;
        # handle sub-types which are identified by extension
        if (defined $ext and $ext ne $fileType and not $$self{DOC_NUM}) {
            my ($f,$e) = @fileTypeLookup{$fileType,$ext};
            if (ref $f eq 'ARRAY' and ref $e eq 'ARRAY' and $$f[0] eq $$e[0]) {
                # make sure $fileType was a root type and not another sub-type
                $fileType = $ext if $$f[0] eq $fileType or not $fileTypeLookup{$$f[0]};
            }
        }
        $mimeType or $mimeType = $mimeType{$fileType};
        # use base file type if necessary (except if 'TIFF', which is a special case)
        $mimeType = $mimeType{$baseType} unless $mimeType or $baseType eq 'TIFF';
        unless (defined $normExt) {
            $normExt = $fileTypeExt{$fileType};
            $normExt = $fileType unless defined $normExt;
        }
        $self->FoundTag('FileType', $fileType);
        $self->FoundTag('FileTypeExtension', uc $normExt);
        $self->FoundTag('MIMEType', $mimeType || 'application/unknown');
    }
}

#------------------------------------------------------------------------------
# Override the FileType and MIMEType tags
# Inputs: 0) ExifTool object ref, 1) file type, 2) MIME type, 3) normal extension
# Notes:  does nothing if FileType was not previously defined (ie. when writing)
sub OverrideFileType($$;$$)
{
    my ($self, $fileType, $mimeType, $normExt) = @_;
    if (defined $$self{VALUE}{FileType} and $fileType ne $$self{VALUE}{FileType}) {
        $$self{VALUE}{FileType} = $fileType;
        unless (defined $normExt) {
            $normExt = $fileTypeExt{$fileType};
            $normExt = $fileType unless defined $normExt;
        }
        $$self{VALUE}{FileTypeExtension} = uc $normExt;
        $mimeType or $mimeType = $mimeType{$fileType};
        $$self{VALUE}{MIMEType} = $mimeType if $mimeType;
        if ($$self{OPTIONS}{Verbose}) {
            $self->VPrint(0,"$$self{INDENT}FileType [override] = $fileType\n");
            $self->VPrint(0,"$$self{INDENT}FileTypeExtension [override] = $$self{VALUE}{FileTypeExtension}\n");
            $self->VPrint(0,"$$self{INDENT}MIMEType [override] = $mimeType\n") if $mimeType;
        }
    }
}

#------------------------------------------------------------------------------
# Modify the value of the MIMEType tag
# Inputs: 0) ExifTool object reference, 1) file or MIME type
# Notes: combines existing type with new type: ie) a/b + c/d => c/b-d
sub ModifyMimeType($;$)
{
    my ($self, $mime) = @_;
    $mime =~ m{/} or $mime = $mimeType{$mime} or return;
    my $old = $$self{VALUE}{MIMEType};
    if (defined $old) {
        my ($a, $b) = split '/', $old;
        my ($c, $d) = split '/', $mime;
        $d =~ s/^x-//;
        $$self{VALUE}{MIMEType} = "$c/$b-$d";
        $self->VPrint(0, "  Modified MIMEType = $c/$b-$d\n");
    } else {
        $self->FoundTag('MIMEType', $mime);
    }
}

#------------------------------------------------------------------------------
# Print verbose output
# Inputs: 0) ExifTool ref, 1) verbose level (prints if level > this), 2-N) print args
sub VPrint($$@)
{
    my $self = shift;
    my $level = shift;
    if ($$self{OPTIONS}{Verbose} and $$self{OPTIONS}{Verbose} > $level) {
        my $out = $$self{OPTIONS}{TextOut};
        print $out @_;
        print $out "\n" unless $_[-1] =~ /\n$/;
    }
}

#------------------------------------------------------------------------------
# Print verbose directory information
# Inputs: 0) ExifTool object reference, 1) directory name or dirInfo ref
#         2) number of entries in directory (or 0 if unknown)
#         3) optional size of directory in bytes
sub VerboseDir($$;$$)
{
    my ($self, $name, $entries, $size) = @_;
    return unless $$self{OPTIONS}{Verbose};
    if (ref $name eq 'HASH') {
        $size = $$name{DirLen} unless $size;
        $name = $$name{Name} || $$name{DirName};
    }
    my $indent = substr($$self{INDENT}, 0, -2);
    my $out = $$self{OPTIONS}{TextOut};
    my $str = $entries ? " with $entries entries" : '';
    $str .= ", $size bytes" if $size;
    print $out "$indent+ [$name directory$str]\n";
}

#------------------------------------------------------------------------------
# Verbose dump
# Inputs: 0) ExifTool ref, 1) data ref, 2-N) HexDump options
sub VerboseDump($$;%)
{
    my $self = shift;
    my $dataPt = shift;
    my $verbose = $$self{OPTIONS}{Verbose};
    if ($verbose and $verbose > 2) {
        my %parms = (
            Prefix => $$self{INDENT},
            Out    => $$self{OPTIONS}{TextOut},
            MaxLen => $verbose < 4 ? 96 : $verbose < 5 ? 2048 : undef,
        );
        HexDump($dataPt, undef, %parms, @_);
    }
}

#------------------------------------------------------------------------------
# Print data in hex
# Inputs: 0) data
# Returns: hex string
# (this is a convenience function for use in debugging PrintConv statements)
sub PrintHex($)
{
    my $val = shift;
    return join(' ', unpack('H2' x length($val), $val));
}

#------------------------------------------------------------------------------
# Extract binary data from file
# 0) ExifTool object reference, 1) offset, 2) length, 3) tag name if conditional
# Returns: binary data, or undef on error
# Notes: Returns "Binary data #### bytes" instead of data unless tag is
#        specifically requested or the Binary option is set
sub ExtractBinary($$$;$)
{
    my ($self, $offset, $length, $tag) = @_;
    my ($isPreview, $buff);

    if ($tag) {
        if ($tag eq 'PreviewImage') {
            # save PreviewImage start/length in case we want to dump trailer
            $$self{PreviewImageStart} = $offset;
            $$self{PreviewImageLength} = $length;
            $isPreview = 1;
        }
        my $lcTag = lc $tag;
        if ((not $$self{OPTIONS}{Binary} or $$self{EXCL_TAG_LOOKUP}{$lcTag}) and
             not $$self{OPTIONS}{Verbose} and not $$self{REQ_TAG_LOOKUP}{$lcTag})
        {
            return "Binary data $length bytes";
        }
    }
    unless ($$self{RAF}->Seek($offset,0)
        and $$self{RAF}->Read($buff, $length) == $length)
    {
        $tag or $tag = 'binary data';
        if ($isPreview and not $$self{BuildingComposite}) {
            $$self{PreviewError} = 1;
        } else {
            $self->Warn("Error reading $tag from file", $isPreview);
        }
        return undef;
    }
    return $buff;
}

#------------------------------------------------------------------------------
# Process binary data
# Inputs: 0) ExifTool object ref, 1) directory information ref, 2) tag table ref
# Returns: 1 on success
# Notes: dirInfo may contain VarFormatData (reference to empty list) to return
#        details about any variable-length-format tags in the table (used when writing)
sub ProcessBinaryData($$$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart} || 0;
    my $size = $$dirInfo{DirLen} || (length($$dataPt) - $offset);
    my $base = $$dirInfo{Base} || 0;
    my $verbose = $$self{OPTIONS}{Verbose};
    my $unknown = $$self{OPTIONS}{Unknown};
    my $dataPos = $$dirInfo{DataPos} || 0;

    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';
    my $increment = $formatSize{$defaultFormat};
    unless ($increment) {
        warn "Unknown format $defaultFormat\n";
        $defaultFormat = 'int8u';
        $increment = $formatSize{$defaultFormat};
    }
    # prepare list of tag numbers to extract
    my (@tags, $topIndex);
    if ($unknown > 1 and defined $$tagTablePtr{FIRST_ENTRY}) {
        # don't create a stupid number of tags if data is huge
        my $sizeLimit = $size < 65536 ? $size : 65536;
        # scan through entire binary table
        $topIndex = int($sizeLimit/$increment);
        @tags = ($$tagTablePtr{FIRST_ENTRY}..($topIndex - 1));
        # add in floating point tag ID's if they exist
        my @ftags = grep /\./, TagTableKeys($tagTablePtr);
        @tags = sort { $a <=> $b } @tags, @ftags if @ftags;
    } elsif ($$dirInfo{DataMember}) {
        @tags = @{$$dirInfo{DataMember}};
        $verbose = 0;   # no verbose output of extracted values when writing
    } elsif ($$dirInfo{MixedTags}) {
        # process sorted integer-ID tags only
        @tags = sort { $a <=> $b } grep /^\d+$/, TagTableKeys($tagTablePtr);
    } else {
        # extract known tags in numerical order
        @tags = sort { ($a < 0 ? $a + 1e9 : $a) <=> ($b < 0 ? $b + 1e9 : $b) } TagTableKeys($tagTablePtr);
    }
    $self->VerboseDir('BinaryData', undef, $size) if $verbose;
    # avoid creating unknown tags for tags that fail condition if Unknown is 1
    $$self{NO_UNKNOWN} = 1 if $unknown < 2;
    my ($index, %val);
    my $nextIndex = 0;
    my $varSize = 0;
    foreach $index (@tags) {
        my ($tagInfo, $val, $saveNextIndex, $len, $mask, $wasVar, $rational);
        if ($$tagTablePtr{$index}) {
            $tagInfo = $self->GetTagInfo($tagTablePtr, $index);
            unless ($tagInfo) {
                next unless defined $tagInfo;
                my $entry = int($index) * $increment + $varSize;
                if ($entry < 0) {
                    $entry += $size;
                    next if $entry < 0;
                }
                next if $entry >= $size;
                my $more = $size - $entry;
                $more = 128 if $more > 128;
                my $v = substr($$dataPt, $entry+$offset, $more);
                $tagInfo = $self->GetTagInfo($tagTablePtr, $index, \$v);
                next unless $tagInfo;
            }
            next if $$tagInfo{Unknown} and
                   ($$tagInfo{Unknown} > $unknown or $index < $nextIndex);
        } elsif ($topIndex and $$tagTablePtr{$index - $topIndex}) {
            $tagInfo = $self->GetTagInfo($tagTablePtr, $index - $topIndex) or next;
        } else {
            # don't generate unknown tags in binary tables unless Unknown > 1
            next unless $unknown > 1;
            next if $index < $nextIndex;    # skip if data already used
            $tagInfo = $self->GetTagInfo($tagTablePtr, $index) or next;
            $$tagInfo{Unknown} = 2;    # set unknown to 2 for binary unknowns
        }
        # get relative offset of this entry
        my $entry = int($index) * $increment + $varSize;
        # allow negative indices to represent bytes from end
        if ($entry < 0) {
            $entry += $size;
            next if $entry < 0;
        }
        my $more = $size - $entry;
        last if $more <= 0;     # all done if we have reached the end of data
        my $count = 1;
        my $format = $$tagInfo{Format};
        if (not $format) {
            $format = $defaultFormat;
        } elsif ($format eq 'string') {
            # string with no specified count runs to end of block
            $count = $more;
        } elsif ($format eq 'pstring') {
            $format = 'string';
            $count = Get8u($dataPt, ($entry++)+$offset);
            --$more;
        } elsif (not $formatSize{$format}) {
            if ($format =~ /(.*)\[(.*)\]/) {
                # handle format count field
                $format = $1;
                $count = $2;
                # evaluate count to allow count to be based on previous values
                #### eval Format size (%val, $size, $self)
                $count = eval $count;
                $@ and warn("Format $$tagInfo{Name}: $@"), next;
                next if $count < 0;
                # allow a variable-length value of any format
                # (note: the next incremental index points to data immediately after
                #  this value, regardless of the size of this value, even if it is zero)
                if ($format =~ s/^var_//) {
                    $varSize += $count * ($formatSize{$format} || 1) - $increment;
                    $wasVar = 1;
                    # save variable size data if required for writing
                    if ($$dirInfo{VarFormatData}) {
                        push @{$$dirInfo{VarFormatData}}, [ $index, $varSize, $format ];
                    }
                    # don't extract value if large and we wanted it just to get
                    # the variable-format information when writing
                    next if $$tagInfo{LargeTag} and $$dirInfo{VarFormatData};
                }
            } elsif ($format =~ /^var_/) {
                # handle variable-length string formats
                $format = substr($format, 4);
                pos($$dataPt) = $entry + $offset;
                undef $count;
                if ($format eq 'ustring') {
                    $count = pos($$dataPt) - ($entry+$offset) if $$dataPt =~ /\G(..)*?\0\0/sg;
                    $varSize -= 2;  # ($count includes base size of 2 bytes)
                } elsif ($format eq 'pstring') {
                    $count = Get8u($dataPt, ($entry++)+$offset);
                    --$more;
                } elsif ($format eq 'pstr32' or $format eq 'ustr32') {
                    last if $more < 4;
                    $count = Get32u($dataPt, $entry + $offset);
                    $count *= 2 if $format eq 'ustr32';
                    $entry += 4;
                    $more -= 4;
                    $nextIndex += 4 / $increment;   # (increment next index for int32u)
                } elsif ($format eq 'int16u') {
                    # int16u size of binary data to follow
                    last if $more < 2;
                    $count = Get16u($dataPt, $entry + $offset) + 2;
                    $varSize -= 2;  # ($count includes size word)
                    $format = 'undef';
                } elsif ($format eq 'ue7') {
                    require Image::ExifTool::BPG;
                    ($val, $count) = Image::ExifTool::BPG::Get_ue7($dataPt, $entry + $offset);
                    last unless defined $val;
                    --$varSize;     # ($count includes base size of 1 byte)
                } elsif ($$dataPt =~ /\0/g) {
                    $count = pos($$dataPt) - ($entry+$offset);
                    --$varSize;     # ($count includes base size of 1 byte)
                }
                $count = $more if not defined $count or $count > $more;
                $varSize += $count; # shift subsequent indices
                unless (defined $val) {
                    $val = substr($$dataPt, $entry+$offset, $count);
                    $val = $self->Decode($val, 'UCS2') if $format eq 'ustring' or $format eq 'ustr32';
                    $val =~ s/\0.*//s unless $format eq 'undef';  # truncate at null
                }
                $wasVar = 1;
                # save variable size data if required for writing
                if ($$dirInfo{VarFormatData}) {
                    push @{$$dirInfo{VarFormatData}}, [ $index, $varSize, $format ];
                }
            }
        }
        # hook to allow format, etc to be set dynamically
        if (defined $$tagInfo{Hook}) {
            my $oldVarSize = $varSize;
            #### eval Hook ($format, $varSize, $size)
            eval $$tagInfo{Hook};
            # save variable size data if required for writing (in case changed by Hook)
            if ($$dirInfo{VarFormatData}) {
                $#{$$dirInfo{VarFormatData}} -= 1 if $wasVar; # remove previous entry for this tag
                push @{$$dirInfo{VarFormatData}}, [ $index, $varSize, $format ];
            } elsif ($varSize != $oldVarSize and $verbose > 2) {
                my ($tmp, $sign) = ($varSize, '+');
                $tmp < 0 and $tmp = -$tmp, $sign = '-';
                $self->VPrint(2, sprintf("$$self{INDENT}\[offsets adjusted by ${sign}0x%.4x after 0x%.4x $$tagInfo{Name}]\n", $tmp, $index));
            }
        }
        if ($unknown > 1) {
            # calculate next valid index for unknown tag
            my $ni = int $index;
            $ni += (($formatSize{$format} || 1) * $count) / $increment unless $wasVar;
            $saveNextIndex = $nextIndex;
            $nextIndex = $ni unless $nextIndex > $ni;
        }
        # allow large tags to be excluded from extraction
        # (provides a work-around for some tight memory situations)
        next if $$tagInfo{LargeTag} and $$self{EXCL_TAG_LOOKUP}{lc $$tagInfo{Name}};
        # read value now if necessary
        unless (defined $val and not $$tagInfo{SubDirectory}) {
            $val = ReadValue($dataPt, $entry+$offset, $format, $count, $more, \$rational);
            $mask = $$tagInfo{Mask};
            $val &= $mask if $mask;
        }
        if ($verbose and not $$tagInfo{Hidden}) {
            if (not $$tagInfo{SubDirectory} or $$tagInfo{Format}) {
                $len = $count * ($formatSize{$format} || 1);
                $len = $more if $len > $more;
            } else {
                $len = $more;
            }
            $self->VerboseInfo($index, $tagInfo,
                Table  => $tagTablePtr,
                Value  => $val,
                DataPt => $dataPt,
                Size   => $len,
                Start  => $entry+$offset,
                Addr   => $entry+$offset+$base+$dataPos,
                Format => $format,
                Count  => $count,
                Extra  => $mask ? sprintf(', mask 0x%.2x',$mask) : undef,
            );
        }
        # parse nested BinaryData directories
        if ($$tagInfo{SubDirectory}) {
            my $subdir = $$tagInfo{SubDirectory};
            my $subTablePtr = GetTagTable($$subdir{TagTable});
            # use specified subdirectory length if given
            if ($$tagInfo{Format} and $formatSize{$format}) {
                $len = $count * $formatSize{$format};
                $len = $more if $len > $more;
            } else {
                $len = $more;   # directory size is all of remaining data
                if ($$subTablePtr{PROCESS_PROC} and
                    $$subTablePtr{PROCESS_PROC} eq \&ProcessBinaryData)
                {
                    # the rest of the data will be printed in the subdirectory
                    $nextIndex = $size / $increment;
                }
            }
            my $subdirBase = $base;
            if (defined $$subdir{Base}) {
                #### eval Base ($start,$base)
                my $start = $entry + $offset + $dataPos;
                $subdirBase = eval($$subdir{Base}) + $base;
            }
            my $start = $$subdir{Start} || 0;
            my %subdirInfo = (
                DataPt   => $dataPt,
                DataPos  => $dataPos,
                DataLen  => length $$dataPt,
                DirStart => $entry + $offset + $start,
                DirLen   => $len - $start,
                Base     => $subdirBase,
            );
            delete $$self{NO_UNKNOWN};
            $self->ProcessDirectory(\%subdirInfo, $subTablePtr, $$subdir{ProcessProc});
            $$self{NO_UNKNOWN} = 1 if $unknown < 2;
            next;
        }
        if ($$tagInfo{IsOffset} and $$tagInfo{IsOffset} ne '3') {
            my $et = $self;
            #### eval IsOffset ($val, $et)
            $val += $base + $$self{BASE} if eval $$tagInfo{IsOffset};
        }
        $val{$index} = $val;
        my $oldBase;
        if ($$tagInfo{SetBase}) {
            $oldBase = $$self{BASE};
            $$self{BASE} += $base;
        }
        my $key = $self->FoundTag($tagInfo,$val);
        $$self{BASE} = $oldBase if defined $oldBase;
        if ($key) {
            $$self{RATIONAL}{$key} = $rational if defined $rational;
        } else {
            # don't increment nextIndex if we didn't extract a tag
            $nextIndex = $saveNextIndex if defined $saveNextIndex;
        }
    }
    delete $$self{NO_UNKNOWN};
    return 1;
}

#..............................................................................
# Load .ExifTool_config file from user's home directory
# (use of noConfig is now deprecated, use configFile = '' instead)
until ($Image::ExifTool::noConfig) {
    my $config = $Image::ExifTool::configFile;
    my $file;
    if (not defined $config) {
        $config = '.ExifTool_config';
        # get our home directory (HOMEDRIVE and HOMEPATH are used in Windows cmd shell)
        my $home = $ENV{EXIFTOOL_HOME} || $ENV{HOME} ||
                   ($ENV{HOMEDRIVE} || '') . ($ENV{HOMEPATH} || '') || '.';
        # look for the config file in 1) the home directory, 2) the program dir
        $file = "$home/$config";
    } else {
        length $config or last; # filename of "" disables configuration
        $file = $config;
    }
    # also check executable directory unless path is absolute
    -r $file or $config =~ /^\// or $file = ($0 =~ /(.*[\\\/])/ ? $1 : './') . $config;
    unless (-r $file) {
        warn("Config file not found\n") if defined $Image::ExifTool::configFile;
        last;
    }
    unshift @INC, '.';      # look in current directory first
    eval { require $file }; # load the config file
    shift @INC;
    # print warning (minus "Compilation failed" part)
    $@ and $_=$@, s/Compilation failed.*//s, warn $_;
    last;
}
# read user-defined lenses (may have been defined by script instead of config file)
if (@Image::ExifTool::UserDefined::Lenses) {
    foreach (@Image::ExifTool::UserDefined::Lenses) {
        $Image::ExifTool::userLens{$_} = 1;
    }
}
# add user-defined file types
if (%Image::ExifTool::UserDefined::FileTypes) {
    foreach (sort keys %Image::ExifTool::UserDefined::FileTypes) {
        my $fileInfo = $Image::ExifTool::UserDefined::FileTypes{$_};
        my $type = uc $_;
        ref $fileInfo eq 'HASH' or $fileTypeLookup{$type} = $fileInfo, next;
        my $baseType = $$fileInfo{BaseType};
        if ($baseType) {
            if ($$fileInfo{Description}) {
                $fileTypeLookup{$type} = [ $baseType, $$fileInfo{Description} ];
            } else {
                $fileTypeLookup{$type} = $baseType;
            }
            if (defined $$fileInfo{Writable} and not $$fileInfo{Writable}) {
                # first make sure we are using an actual base type and not a derived type
                $baseType = $fileTypeLookup{$baseType} while $baseType and not ref $fileTypeLookup{$baseType};
                # mark this type as not writable
                $noWriteFile{$baseType} or $noWriteFile{$baseType} = [ ];
                push @{$noWriteFile{$baseType}}, $type;
            }
        } else {
            $fileTypeLookup{$type} = [ $type, $$fileInfo{Description} || $type ];
            $moduleName{$type} = 0; # not supported
            if ($$fileInfo{Magic}) {
                $magicNumber{$type} = $$fileInfo{Magic};
                push @fileTypes, $type unless grep /^$type$/, @fileTypes;
            }
        }
        $mimeType{$type} = $$fileInfo{MIMEType} if defined $$fileInfo{MIMEType};
    }
}

#------------------------------------------------------------------------------
1;  # end
