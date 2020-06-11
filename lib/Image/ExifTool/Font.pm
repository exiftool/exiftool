#------------------------------------------------------------------------------
# File:         Font.pm
#
# Description:  Read meta information from font files
#
# Revisions:    2010/01/15 - P. Harvey Created
#
# References:   1) http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6.html
#               2) http://www.microsoft.com/typography/otspec/otff.htm
#               3) http://partners.adobe.com/public/developer/opentype/index_font_file.html
#               4) http://partners.adobe.com/public/developer/en/font/5178.PFM.pdf
#               5) http://opensource.adobe.com/svn/opensource/flex/sdk/trunk/modules/compiler/src/java/flex2/compiler/util/MimeMappings.java
#               6) http://www.adobe.com/devnet/font/pdfs/5004.AFM_Spec.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Font;

use strict;
use vars qw($VERSION %ttLang);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.10';

sub ProcessOTF($$);

# TrueType 'name' platform codes
my %ttPlatform = (
    0 => 'Unicode',
    1 => 'Macintosh',
    2 => 'ISO',
    3 => 'Windows',
    4 => 'Custom',
);

# convert TrueType 'name' character encoding to ExifTool Charset (ref 1/2)
my %ttCharset = (
  Macintosh => {
    0 => 'MacRoman',      17 => 'MacMalayalam',
    1 => 'MacJapanese',   18 => 'MacSinhalese',
    2 => 'MacChineseTW',  19 => 'MacBurmese',
    3 => 'MacKorean',     20 => 'MacKhmer',
    4 => 'MacArabic',     21 => 'MacThai',
    5 => 'MacHebrew',     22 => 'MacLaotian',
    6 => 'MacGreek',      23 => 'MacGeorgian',
    7 => 'MacCyrillic',   24 => 'MacArmenian', # 7=Russian
    8 => 'MacRSymbol',    25 => 'MacChineseCN',
    9 => 'MacDevanagari', 26 => 'MacTibetan',
   10 => 'MacGurmukhi',   27 => 'MacMongolian',
   11 => 'MacGujarati',   28 => 'MacGeez',
   12 => 'MacOriya',      29 => 'MacCyrillic', # 29=Slavic
   13 => 'MacBengali',    30 => 'MacVietnam',
   14 => 'MacTamil',      31 => 'MacSindhi',
   15 => 'MacTelugu',     32 => '', # 32=uninterpreted
   16 => 'MacKannada',
  },
  Windows => {
    0 => 'Symbol',         4 => 'Big5',
    1 => 'UCS2',           5 => 'Wansung',
    2 => 'ShiftJIS',       6 => 'Johab',
    3 => 'PRC',           10 => 'UCS4',
  },
  Unicode => {
    # (we don't currently handle the various Unicode flavours)
    0 => 'UCS2', # Unicode 1.0 semantics
    1 => 'UCS2', # Unicode 1.1 semantics
    2 => 'UCS2', # ISO 10646 semantics
    3 => 'UCS2', # Unicode 2.0 and onwards semantics, Unicode BMP only.
    4 => 'UCS2', # Unicode 2.0 and onwards semantics, Unicode full repertoire.
    # 5 => Unicode Variation Sequences (not used in Naming table)
  },
  ISO => { # (deprecated)
    0 => 'UTF8',  # (7-bit ASCII)
    1 => 'UCS2',  # ISO 10646
    2 => 'Latin', # ISO 8859-1
  },
  Custom => { },
);

# convert TrueType 'name' language code to ExifTool language code
%ttLang = (
  # Macintosh language codes (also used by QuickTime.pm)
  # oddities:
  #   49 - Cyrillic version    83 - Roman
  #   50 - Arabic version     84 - Arabic
  #  146 - with dot above
  Macintosh => {
    0 => 'en',     24 => 'lt',    48 => 'kk',    72 => 'ml',    129 => 'eu',
    1 => 'fr',     25 => 'pl',    49 => 'az',    73 => 'kn',    130 => 'ca',
    2 => 'de',     26 => 'hu',    50 => 'az',    74 => 'ta',    131 => 'la',
    3 => 'it',     27 => 'et',    51 => 'hy',    75 => 'te',    132 => 'qu',
    4 => 'nl-NL',  28 => 'lv',    52 => 'ka',    76 => 'si',    133 => 'gn',
    5 => 'sv',     29 => 'smi',   53 => 'ro',    77 => 'my',    134 => 'ay',
    6 => 'es',     30 => 'fo',    54 => 'ky',    78 => 'km',    135 => 'tt',
    7 => 'da',     31 => 'fa',    55 => 'tg',    79 => 'lo',    136 => 'ug',
    8 => 'pt',     32 => 'ru',    56 => 'tk',    80 => 'vi',    137 => 'dz',
    9 => 'no',     33 => 'zh-CN', 57 => 'mn-MN', 81 => 'id',    138 => 'jv',
    10 => 'he',    34 => 'nl-BE', 58 => 'mn-CN', 82 => 'tl',    139 => 'su',
    11 => 'ja',    35 => 'ga',    59 => 'ps',    83 => 'ms-MY', 140 => 'gl',
    12 => 'ar',    36 => 'sq',    60 => 'ku',    84 => 'ms-BN', 141 => 'af',
    13 => 'fi',    37 => 'ro',    61 => 'ks',    85 => 'am',    142 => 'br',
    14 => 'el',    38 => 'cs',    62 => 'sd',    86 => 'ti',    144 => 'gd',
    15 => 'is',    39 => 'sk',    63 => 'bo',    87 => 'om',    145 => 'gv',
    16 => 'mt',    40 => 'sl',    64 => 'ne',    88 => 'so',    146 => 'ga',
    17 => 'tr',    41 => 'yi',    65 => 'sa',    89 => 'sw',    147 => 'to',
    18 => 'hr',    42 => 'sr',    66 => 'mr',    90 => 'rw',    148 => 'el',
    19 => 'zh-TW', 43 => 'mk',    67 => 'bn',    91 => 'rn',    149 => 'kl',
    20 => 'ur',    44 => 'bg',    68 => 'as',    92 => 'ny',    150 => 'az',
    21 => 'hi',    45 => 'uk',    69 => 'gu',    93 => 'mg',
    22 => 'th',    46 => 'be',    70 => 'pa',    94 => 'eo',
    23 => 'ko',    47 => 'uz',    71 => 'or',   128 => 'cy',
  },
  # Windows language codes (http://msdn.microsoft.com/en-us/library/0h88fahh(VS.85).aspx)
  # Notes: This isn't an exact science.  The reference above gives language codes
  # which are different from some ISO 639-1 numbers.  Also, some Windows language
  # codes don't appear to have ISO 639-1 equivalents.
  #  0x0428 - fa by ref above
  #  0x048c - no ISO equivalent
  #  0x081a/0x83c - sr-SP
  #  0x0c0a - modern?
  #  0x2409 - Caribbean country code not found in ISO 3166-1
  Windows => {
    0x0401 => 'ar-SA', 0x0438 => 'fo',    0x0481 => 'mi',    0x1409 => 'en-NZ',
    0x0402 => 'bg',    0x0439 => 'hi',    0x0482 => 'oc',    0x140a => 'es-CR',
    0x0403 => 'ca',    0x043a => 'mt',    0x0483 => 'co',    0x140c => 'fr-LU',
    0x0404 => 'zh-TW', 0x043b => 'se-NO', 0x0484 => 'gsw',   0x141a => 'bs-BA',
    0x0405 => 'cs',    0x043c => 'gd',    0x0485 => 'sah',   0x143b => 'smj-SE',
    0x0406 => 'da',    0x043d => 'yi',    0x0486 => 'ny',    0x1801 => 'ar-MA',
    0x0407 => 'de-DE', 0x043e => 'ms-MY', 0x0487 => 'rw',    0x1809 => 'en-IE',
    0x0408 => 'el',    0x043f => 'kk',    0x048c => 'Dari',  0x180a => 'es-PA',
    0x0409 => 'en-US', 0x0440 => 'ky',    0x0801 => 'ar-IQ', 0x180c => 'fr-MC',
    0x040a => 'es-ES', 0x0441 => 'sw',    0x0804 => 'zh-CN', 0x181a => 'sr-BA',
    0x040b => 'fi',    0x0442 => 'tk',    0x0807 => 'de-CH', 0x183b => 'sma-NO',
    0x040c => 'fr-FR', 0x0443 => 'uz-UZ', 0x0809 => 'en-GB', 0x1c01 => 'ar-TN',
    0x040d => 'he',    0x0444 => 'tt',    0x080a => 'es-MX', 0x1c09 => 'en-ZA',
    0x040e => 'hu',    0x0445 => 'bn-IN', 0x080c => 'fr-BE', 0x1c0a => 'es-DO',
    0x040f => 'is',    0x0446 => 'pa',    0x0810 => 'it-CH', 0x1c1a => 'sr-BA',
    0x0410 => 'it-IT', 0x0447 => 'gu',    0x0813 => 'nl-BE', 0x1c3b => 'sma-SE',
    0x0411 => 'ja',    0x0448 => 'wo',    0x0814 => 'nn',    0x2001 => 'ar-OM',
    0x0412 => 'ko',    0x0449 => 'ta',    0x0816 => 'pt-PT', 0x2009 => 'en-JM',
    0x0413 => 'nl-NL', 0x044a => 'te',    0x0818 => 'ro-MO', 0x200a => 'es-VE',
    0x0414 => 'no-NO', 0x044b => 'kn',    0x0819 => 'ru-MO', 0x201a => 'bs-BA',
    0x0415 => 'pl',    0x044c => 'ml',    0x081a => 'sr-RS', 0x203b => 'sms',
    0x0416 => 'pt-BR', 0x044d => 'as',    0x081d => 'sv-FI', 0x2401 => 'ar-YE',
    0x0417 => 'rm',    0x044e => 'mr',    0x082c => 'az-AZ', 0x2409 => 'en-CB',
    0x0418 => 'ro',    0x044f => 'sa',    0x082e => 'dsb',   0x240a => 'es-CO',
    0x0419 => 'ru',    0x0450 => 'mn-MN', 0x083b => 'se-SE', 0x243b => 'smn',
    0x041a => 'hr',    0x0451 => 'bo',    0x083c => 'ga',    0x2801 => 'ar-SY',
    0x041b => 'sk',    0x0452 => 'cy',    0x083e => 'ms-BN', 0x2809 => 'en-BZ',
    0x041c => 'sq',    0x0453 => 'km',    0x0843 => 'uz-UZ', 0x280a => 'es-PE',
    0x041d => 'sv-SE', 0x0454 => 'lo',    0x0845 => 'bn-BD', 0x2c01 => 'ar-JO',
    0x041e => 'th',    0x0456 => 'gl',    0x0850 => 'mn-CN', 0x2c09 => 'en-TT',
    0x041f => 'tr',    0x0457 => 'kok',   0x085d => 'iu-CA', 0x2c0a => 'es-AR',
    0x0420 => 'ur',    0x045a => 'syr',   0x085f => 'tmh',   0x3001 => 'ar-LB',
    0x0421 => 'id',    0x045b => 'si',    0x086b => 'qu-EC', 0x3009 => 'en-ZW',
    0x0422 => 'uk',    0x045d => 'iu-CA', 0x0c01 => 'ar-EG', 0x300a => 'es-EC',
    0x0423 => 'be',    0x045e => 'am',    0x0c04 => 'zh-HK', 0x3401 => 'ar-KW',
    0x0424 => 'sl',    0x0461 => 'ne',    0x0c07 => 'de-AT', 0x3409 => 'en-PH',
    0x0425 => 'et',    0x0462 => 'fy',    0x0c09 => 'en-AU', 0x340a => 'es-CL',
    0x0426 => 'lv',    0x0463 => 'ps',    0x0c0a => 'es-ES', 0x3801 => 'ar-AE',
    0x0427 => 'lt',    0x0464 => 'fil',   0x0c0c => 'fr-CA', 0x380a => 'es-UY',
    0x0428 => 'tg',    0x0465 => 'dv',    0x0c1a => 'sr-RS', 0x3c01 => 'ar-BH',
    0x042a => 'vi',    0x0468 => 'ha',    0x0c3b => 'se-FI', 0x3c0a => 'es-PY',
    0x042b => 'hy',    0x046a => 'yo',    0x0c6b => 'qu-PE', 0x4001 => 'ar-QA',
    0x042c => 'az-AZ', 0x046b => 'qu-BO', 0x1001 => 'ar-LY', 0x4009 => 'en-IN',
    0x042d => 'eu',    0x046c => 'st',    0x1004 => 'zh-SG', 0x400a => 'es-BO',
    0x042e => 'hsb',   0x046d => 'ba',    0x1007 => 'de-LU', 0x4409 => 'en-MY',
    0x042f => 'mk',    0x046e => 'lb',    0x1009 => 'en-CA', 0x440a => 'es-SV',
    0x0430 => 'st',    0x046f => 'kl',    0x100a => 'es-GT', 0x4809 => 'en-SG',
    0x0431 => 'ts',    0x0470 => 'ig',    0x100c => 'fr-CH', 0x480a => 'es-HN',
    0x0432 => 'tn',    0x0478 => 'yi',    0x101a => 'hr-BA', 0x4c0a => 'es-NI',
    0x0434 => 'xh',    0x047a => 'arn',   0x103b => 'smj-NO',0x500a => 'es-PR',
    0x0435 => 'zu',    0x047c => 'moh',   0x1401 => 'ar-DZ', 0x540a => 'es-US',
    0x0436 => 'af',    0x047e => 'br',    0x1404 => 'zh-MO',
    0x0437 => 'ka',    0x0480 => 'ug',    0x1407 => 'de-LI',
  },
  Unicode => { },
  ISO     => { },
  Custom  => { },
);

# eclectic table of tags for various format font files
%Image::ExifTool::Font::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        This table contains a collection of tags found in font files of various
        formats.  ExifTool current recognizes OTF, TTF, TTC, DFONT, PFA, PFB, PFM,
        AFM, ACFM and AMFM font files.
    },
    name => {
        SubDirectory => { TagTable => 'Image::ExifTool::Font::Name' },
    },
    PFM  => {
        Name => 'PFMHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::Font::PFM' },
    },
    PSInfo => {
        Name => 'PSFontInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Font::PSInfo' },
    },
    AFM => {
        Name => 'AFM',
        SubDirectory => { TagTable => 'Image::ExifTool::Font::AFM' },
    },
    numfonts => 'NumFonts',
    fontname => 'FontName',
    postfont => {
        Name => 'PostScriptFontName',
        Description => 'PostScript Font Name',
    },
);

# TrueType name tags (ref 1/2)
%Image::ExifTool::Font::Name = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        The following tags are extracted from the TrueType font "name" table found
        in OTF, TTF, TTC and DFONT files.  These tags support localized languages by
        adding a hyphen followed by a language code to the end of the tag name (eg.
        "Copyright-fr" or "License-en-US").  Tags with no language code use the
        default language of "en".
    },
    0 => { Name => 'Copyright', Groups => { 2 => 'Author' } },
    1 => 'FontFamily',
    2 => 'FontSubfamily',
    3 => 'FontSubfamilyID',
    4 => 'FontName', # full name
    5 => 'NameTableVersion',
    6 => { Name => 'PostScriptFontName', Description => 'PostScript Font Name' },
    7 => 'Trademark',
    8 => 'Manufacturer',
    9 => 'Designer',
    10 => 'Description',
    11 => 'VendorURL',
    12 => 'DesignerURL',
    13 => 'License',
    14 => 'LicenseInfoURL',
    16 => 'PreferredFamily',
    17 => 'PreferredSubfamily',
    18 => 'CompatibleFontName',
    19 => 'SampleText',
    20 => {
        Name => 'PostScriptFontName',
        Description => 'PostScript Font Name',
    },
    21 => 'WWSFamilyName',
    22 => 'WWSSubfamilyName',
);

# PostScript Font Metric file header (ref 4)
%Image::ExifTool::Font::PFM = (
    GROUPS => { 2 => 'Document' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'Tags extracted from the PFM file header.',
    0 => {
        Name => 'PFMVersion',
        Format => 'int16u',
        PrintConv => 'sprintf("%x.%.2x",$val>>8,$val&0xff)',
    },
    6  => { Name => 'Copyright',       Format => 'string[60]', Groups => { 2 => 'Author' } },
    66 => { Name => 'FontType',        Format => 'int16u' },
    68 => { Name => 'PointSize',       Format => 'int16u' },
    70 => { Name => 'YResolution',     Format => 'int16u' },
    72 => { Name => 'XResolution',     Format => 'int16u' },
    74 => { Name => 'Ascent',          Format => 'int16u' },
    76 => { Name => 'InternalLeading', Format => 'int16u' },
    78 => { Name => 'ExternalLeading', Format => 'int16u' },
    80 => { Name => 'Italic' },
    81 => { Name => 'Underline' },
    82 => { Name => 'Strikeout' },
    83 => { Name => 'Weight',          Format => 'int16u' },
    85 => { Name => 'CharacterSet' },
    86 => { Name => 'PixWidth',        Format => 'int16u' },
    88 => { Name => 'PixHeight',       Format => 'int16u' },
    90 => { Name => 'PitchAndFamily' },
    91 => { Name => 'AvgWidth',        Format => 'int16u' },
    93 => { Name => 'MaxWidth',        Format => 'int16u' },
    95 => { Name => 'FirstChar' },
    96 => { Name => 'LastChar' },
    97 => { Name => 'DefaultChar' },
    98 => { Name => 'BreakChar' },
    99 => { Name => 'WidthBytes',      Format => 'int16u' },
   # 101 => { Name => 'DeviceTypeOffset', Format => 'int32u' },
   # 105 => { Name => 'FontNameOffset',   Format => 'int32u' },
   # 109 => { Name => 'BitsPointer',      Format => 'int32u' },
   # 113 => { Name => 'BitsOffset',       Format => 'int32u' },
);

# PostScript FontInfo attributes (PFA, PFB) (ref PH)
%Image::ExifTool::Font::PSInfo = (
    GROUPS => { 2 => 'Document' },
    NOTES => 'Tags extracted from PostScript font files (PFA and PFB).',
    FullName    => { },
    FamilyName  => { Name => 'FontFamily' },
    Weight      => { },
    ItalicAngle => { },
    isFixedPitch=> { },
    UnderlinePosition  => { },
    UnderlineThickness => { },
    Copyright   => { Groups => { 2 => 'Author' } },
    Notice      => { Groups => { 2 => 'Author' } },
    version     => { },
    FontName    => { },
    FontType    => { },
    FSType      => { },
);

# Adobe Font Metrics tags (AFM) (ref 6)
%Image::ExifTool::Font::AFM = (
    GROUPS => { 2 => 'Document' },
    NOTES => 'Tags extracted from Adobe Font Metrics files (AFM, ACFM and AMFM).',
   'Creation Date' => { Name => 'CreateDate', Groups => { 2 => 'Time' } },
    FontName    => { },
    FullName    => { },
    FamilyName => { Name => 'FontFamily' },
    Weight      => { },
    Version     => { },
    Notice      => { Groups => { 2 => 'Author' } },
    EncodingScheme => { },
    MappingScheme  => { },
    EscChar     => { },
    CharacterSet=> { },
    Characters  => { },
    IsBaseFont  => { },
   # VVector     => { },
    IsFixedV    => { },
    CapHeight   => { },
    XHeight     => { },
    Ascender    => { },
    Descender   => { },
);

#------------------------------------------------------------------------------
# Read information from a TrueType font collection (TTC) (refs 2,3)
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid TrueType font collection
sub ProcessTTC($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $i);

    return 0 unless $raf->Read($buff, 12) == 12;
    return 0 unless $buff =~ /^ttcf\0[\x01\x02]\0\0/;
    SetByteOrder('MM');
    my $num = Get32u(\$buff, 8);
    # might as well put a limit on the number of fonts we will parse (< 256)
    return 0 unless $num < 0x100 and $raf->Read($buff, $num * 4) == $num * 4;
    $et->SetFileType('TTC');
    return 1 if $$et{OPTIONS}{FastScan} and $$et{OPTIONS}{FastScan} == 3;
    my $tagTablePtr = GetTagTable('Image::ExifTool::Font::Main');
    $et->HandleTag($tagTablePtr, 'numfonts', $num);
    # loop through all fonts in the collection
    for ($i=0; $i<$num; ++$i) {
        my $n = $i + 1;
        $et->VPrint(0, "Font $n:\n");
        $$et{SET_GROUP1} = "+$n";
        my $offset = Get32u(\$buff, $i * 4);
        $raf->Seek($offset, 0) or last;
        ProcessOTF($et, $dirInfo) or last;
    }
    delete $$et{SET_GROUP1};
    return 1;
}

#------------------------------------------------------------------------------
# Read information from a TrueType font file (OTF or TTF) (refs 1,2)
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid TrueType font file
sub ProcessOTF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($tbl, $buff, $pos, $i);
    my $base = $$dirInfo{Base} || 0;

    return 0 unless $raf->Read($buff, 12) == 12;
    return 0 unless $buff =~ /^(\0\x01\0\0|OTTO|true|typ1|\xa5(kbd|lst))[\0\x01]/;

    $et->SetFileType($1 eq 'OTTO' ? 'OTF' : 'TTF');
    return 1 if $$et{OPTIONS}{FastScan} and $$et{OPTIONS}{FastScan} == 3;
    SetByteOrder('MM');
    my $numTables = Get16u(\$buff, 4);
    return 0 unless $numTables > 0 and $numTables < 0x200;
    my $len = $numTables * 16;
    return 0 unless $raf->Read($tbl, $len) == $len;

    my $verbose = $et->Options('Verbose');
    my $oldIndent = $$et{INDENT};
    $$et{INDENT} .= '| ';
    $et->VerboseDir('TrueType', $numTables) if $verbose;

    for ($pos=0; $pos<$len; $pos+=16) {
        # look for 'name' table
        my $tag = substr($tbl, $pos, 4);
        next unless $tag eq 'name' or $verbose;
        my $offset = Get32u(\$tbl, $pos + 8);
        my $size   = Get32u(\$tbl, $pos + 12);
        unless ($raf->Seek($offset+$base, 0) and $raf->Read($buff, $size) == $size) {
            $et->Warn("Error reading '${tag}' data");
            next;
        }
        if ($verbose) {
            $tag =~ s/([\0-\x1f\x80-\xff])/sprintf('\x%.2x',ord $1)/ge;
            my $str = sprintf("%s%d) Tag '%s' (offset 0x%.4x, %d bytes)\n",
                              $$et{INDENT}, $pos/16, $tag, $offset, $size);
            $et->VPrint(0, $str);
            $et->VerboseDump(\$buff, Addr => $offset) if $verbose > 2;
            next unless $tag eq 'name';
        }
        next unless $size >= 8;
        my $entries = Get16u(\$buff, 2);
        my $recEnd = 6 + $entries * 12;
        if ($recEnd > $size) {
            $et->Warn('Truncated name record');
            last;
        }
        my $strStart = Get16u(\$buff, 4);
        if ($strStart < $recEnd or $strStart > $size) {
            $et->Warn('Invalid string offset');
            last;
        }
        # parse language-tag record (in format 1 Naming table only) (ref 2)
        my %langTag;
        if (Get16u(\$buff, 0) == 1 and $recEnd + 2 <= $size) {
            my $langTags = Get16u(\$buff, $recEnd);
            if ($langTags and $recEnd + 2 + $langTags * 4 < $size) {
                for ($i=0; $i<$langTags; ++$i) {
                    my $pt = $recEnd + 2 + $i * 4;
                    my $langLen = Get16u(\$buff, $pt);
                    # make sure the language string length is reasonable (UTF-16BE)
                    last if $langLen == 0 or $langLen & 0x01 or $langLen > 40;
                    my $langPt = Get16u(\$buff, $pt + 2) + $strStart;
                    last if $langPt + $langLen > $size;
                    my $lang = substr($buff, $langPt, $langLen);
                    $lang = $et->Decode($lang,'UCS2','MM','UTF8');
                    $lang =~ tr/-_a-zA-Z0-9//dc;    # remove naughty characters
                    $langTag{$i + 0x8000} = $lang;
                }
            }
        }
        my $tagTablePtr = GetTagTable('Image::ExifTool::Font::Name');
        $$et{INDENT} .= '| ';
        $et->VerboseDir('Name', $entries) if $verbose;
        for ($i=0; $i<$entries; ++$i) {
            my $pt = 6 + $i * 12;
            my $platform = Get16u(\$buff, $pt);
            my $encoding = Get16u(\$buff, $pt + 2);
            my $langID   = Get16u(\$buff, $pt + 4);
            my $nameID   = Get16u(\$buff, $pt + 6);
            my $strLen   = Get16u(\$buff, $pt + 8);
            my $strPt    = Get16u(\$buff, $pt + 10) + $strStart;
            if ($strPt + $strLen <= $size) {
                my $val = substr($buff, $strPt, $strLen);
                my ($lang, $charset, $extra);
                my $sys = $ttPlatform{$platform};
                # translate from specified encoding
                if ($sys) {
                    $lang = $ttLang{$sys}{$langID} || $langTag{$langID};
                    $charset = $ttCharset{$sys}{$encoding};
                    if (not $charset) {
                        if (not defined $charset and not $$et{FontWarn}) {
                            $et->Warn("Unknown $sys character set ($encoding)");
                            $$et{FontWarn} = 1;
                        }
                    } else {
                        # translate to ExifTool character set
                        $val = $et->Decode($val, $charset);
                    }
                } else {
                    $et->Warn("Unknown platform ($platform) for name $nameID");
                }
                # get the tagInfo for our specific language (use 'en' for default)
                my $tagInfo = $et->GetTagInfo($tagTablePtr, $nameID);
                if ($tagInfo and $lang and $lang ne 'en') {
                    my $langInfo = Image::ExifTool::GetLangInfo($tagInfo, $lang);
                    $tagInfo = $langInfo if $langInfo;
                }
                if ($verbose) {
                    $langID > 0x400 and $langID = sprintf('0x%x', $langID);
                    $extra = ", Plat=$platform/" . ($sys || 'Unknown') . ', ' .
                               "Enc=$encoding/" . ($charset || 'Unknown') . ', ' .
                               "Lang=$langID/" . ($lang || 'Unknown');
                }
                $et->HandleTag($tagTablePtr, $nameID, $val,
                    TagInfo => $tagInfo,
                    DataPt  => \$buff,
                    DataPos => $offset,
                    Start   => $strPt,
                    Size    => $strLen,
                    Index   => $i,
                    Extra   => $extra,
                );
            }
        }
        $$et{INDENT} = $oldIndent . '| ';
        last unless $verbose;
    }
    $$et{INDENT} = $oldIndent;
    return 1;
}

#------------------------------------------------------------------------------
# Read information from an Adobe Font Metrics file (AFM, ACFM, AMFM) (ref 6)
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a recognized AFM-type file
sub ProcessAFM($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $comment);

    require Image::ExifTool::PostScript;
    local $/ = Image::ExifTool::PostScript::GetInputRecordSeparator($raf);
    $raf->ReadLine($buff);
    return 0 unless $buff =~ /^Start(Comp|Master)?FontMetrics\s+\d+/;
    my $ftyp = $1 ? ($1 eq 'Comp' ? 'ACFM' : 'AMFM') : 'AFM';
    $et->SetFileType($ftyp, 'application/x-font-afm');
    return 1 if $$et{OPTIONS}{FastScan} and $$et{OPTIONS}{FastScan} == 3;
    my $tagTablePtr = GetTagTable('Image::ExifTool::Font::AFM');

    for (;;) {
        $raf->ReadLine($buff) or last;
        if (defined $comment and $buff !~ /^Comment\s/) {
            $et->FoundTag('Comment', $comment);
            undef $comment;
        }
        $buff =~ /^(\w+)\s+(.*?)[\x0d\x0a]/ or next;
        my ($tag, $val) = ($1, $2);
        if ($tag eq 'Comment' and $val =~ /^(Creation Date):\s+(.*)/) {
            ($tag, $val) = ($1, $2);
        }
        $val =~ s/^\((.*)\)$/$1/;   # (some values may be in brackets)
        if ($tag eq 'Comment') {
            # concatinate all comments into a single value
            $comment = defined($comment) ? "$comment\n$val" : $val;
            next;
        }
        unless ($et->HandleTag($tagTablePtr, $tag, $val)) {
            # end parsing if we start any subsection
            last if $tag =~ /^Start/ and $tag ne 'StartDirection';
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read information from various format font files
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a recognized Font file
sub ProcessFont($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $rtnVal);
    return 0 unless $raf->Read($buff, 24) and $raf->Seek(0,0);
    if ($buff =~ /^(\0\x01\0\0|OTTO|true|typ1)[\0\x01]/) {        # OTF, TTF
        $rtnVal = ProcessOTF($et, $dirInfo);
    } elsif ($buff =~ /^ttcf\0[\x01\x02]\0\0/) {                  # TTC
        $rtnVal = ProcessTTC($et, $dirInfo);
    } elsif ($buff =~ /^Start(Comp|Master)?FontMetrics\s+\d+/s) { # AFM
        $rtnVal = ProcessAFM($et, $dirInfo);
    } elsif ($buff =~ /^(.{6})?%!(PS-(AdobeFont-|Bitstream )|FontType1-)/s) {# PFA, PFB
        $raf->Seek(6,0) and $et->SetFileType('PFB') if $1;
        require Image::ExifTool::PostScript;
        $rtnVal = Image::ExifTool::PostScript::ProcessPS($et, $dirInfo);
    } elsif ($buff =~ /^\0[\x01\x02]/ and $raf->Seek(0, 2) and    # PFM
             # validate file size
             $raf->Tell() > 117 and $raf->Tell() == unpack('x2V',$buff) and
             # read PFM header
             $raf->Seek(0,0) and $raf->Read($buff,117) == 117 and
             # validate "DeviceType" string (must be "PostScript\0")
             SetByteOrder('II') and $raf->Seek(Get32u(\$buff, 101), 0) and
             # the DeviceType should be "PostScript\0", but FontForge
             # incorrectly writes "Postscript\0", so ignore case
             $raf->Read($buf2, 11) == 11 and lc($buf2) eq "postscript\0")
    {
        $et->SetFileType('PFM');
        return 1 if $$et{OPTIONS}{FastScan} and $$et{OPTIONS}{FastScan} == 3;
        SetByteOrder('II');
        my $tagTablePtr = GetTagTable('Image::ExifTool::Font::Main');
        # process the PFM header
        $et->HandleTag($tagTablePtr, 'PFM', $buff);
        # extract the font names
        my $nameOff = Get32u(\$buff, 105);
        if ($raf->Seek($nameOff, 0) and $raf->Read($buff, 256) and
            $buff =~ /^([\x20-\xff]+)\0([\x20-\xff]+)\0/)
        {
            $et->HandleTag($tagTablePtr, 'fontname', $1);
            $et->HandleTag($tagTablePtr, 'postfont', $2);
        }
        $rtnVal = 1;
    } elsif ($buff =~ /^(wOF[F2])/) {
        my $type = $1 eq 'wOFF' ? 'woff' : 'woff2';
        $et->SetFileType(uc($type), "font/$type");
        # (don't yet extract metadata from these files)
        $rtnVal = 1;
    } else {
        $rtnVal = 0;
    }
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Font - Read meta information from font files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains the routines required by Image::ExifTool to read meta
information from various format font files.  Currently recognized font file
types are OTF, TTF, TTC, DFONT, PFA, PFB, PFM, AFM, ACFM and AMFM.  As well,
WOFF and WOFF2 font files are identified, but metadata is not currently
extracted from these formats.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6.html>

=item L<http://www.microsoft.com/typography/otspec/otff.htm>

=item L<http://partners.adobe.com/public/developer/opentype/index_font_file.html>

=item L<http://partners.adobe.com/public/developer/en/font/5178.PFM.pdf>

=item L<http://opensource.adobe.com/svn/opensource/flex/sdk/trunk/modules/compiler/src/java/flex2/compiler/util/MimeMappings.java>

=item L<http://www.adobe.com/devnet/font/pdfs/5004.AFM_Spec.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Font Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

