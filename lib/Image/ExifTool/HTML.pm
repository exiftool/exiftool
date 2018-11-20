#------------------------------------------------------------------------------
# File:         HTML.pm
#
# Description:  Read HTML meta information
#
# Revisions:    01/30/2007 - P. Harvey Created
#
# References:   1) http://www.w3.org/TR/html4/
#               2) http://www.daisy.org/publications/specifications/daisy_202.html
#               3) http://vancouver-webpages.com/META/metatags.detail.html
#               4) http://www.html-reference.com/META.htm
#------------------------------------------------------------------------------

package Image::ExifTool::HTML;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::PostScript;
use Image::ExifTool::XMP qw(EscapeXML UnescapeXML);
require Exporter;

$VERSION = '1.16';
@ISA = qw(Exporter);
@EXPORT_OK = qw(EscapeHTML UnescapeHTML);

sub SetHTMLCharset($$);

# convert HTML charset (lower case) to ExifTool Charset name
my %htmlCharset = (
    macintosh     => 'MacRoman',
   'iso-8859-1'   => 'Latin',
   'utf-8'        => 'UTF8',
   'windows-1252' => 'Latin',
);

# HTML 4 character entity references
my %entityNum = (
    'quot'   => 34,   'eth'    => 240,  'lsquo'  => 8216,
    'amp'    => 38,   'ntilde' => 241,  'rsquo'  => 8217,
    'apos'   => 39,   'ograve' => 242,  'sbquo'  => 8218,
    'lt'     => 60,   'oacute' => 243,  'ldquo'  => 8220,
    'gt'     => 62,   'ocirc'  => 244,  'rdquo'  => 8221,
    'nbsp'   => 160,  'otilde' => 245,  'bdquo'  => 8222,
    'iexcl'  => 161,  'ouml'   => 246,  'dagger' => 8224,
    'cent'   => 162,  'divide' => 247,  'Dagger' => 8225,
    'pound'  => 163,  'oslash' => 248,  'bull'   => 8226,
    'curren' => 164,  'ugrave' => 249,  'hellip' => 8230,
    'yen'    => 165,  'uacute' => 250,  'permil' => 8240,
    'brvbar' => 166,  'ucirc'  => 251,  'prime'  => 8242,
    'sect'   => 167,  'uuml'   => 252,  'Prime'  => 8243,
    'uml'    => 168,  'yacute' => 253,  'lsaquo' => 8249,
    'copy'   => 169,  'thorn'  => 254,  'rsaquo' => 8250,
    'ordf'   => 170,  'yuml'   => 255,  'oline'  => 8254,
    'laquo'  => 171,  'OElig'  => 338,  'frasl'  => 8260,
    'not'    => 172,  'oelig'  => 339,  'euro'   => 8364,
    'shy'    => 173,  'Scaron' => 352,  'image'  => 8465,
    'reg'    => 174,  'scaron' => 353,  'weierp' => 8472,
    'macr'   => 175,  'Yuml'   => 376,  'real'   => 8476,
    'deg'    => 176,  'fnof'   => 402,  'trade'  => 8482,
    'plusmn' => 177,  'circ'   => 710,  'alefsym'=> 8501,
    'sup2'   => 178,  'tilde'  => 732,  'larr'   => 8592,
    'sup3'   => 179,  'Alpha'  => 913,  'uarr'   => 8593,
    'acute'  => 180,  'Beta'   => 914,  'rarr'   => 8594,
    'micro'  => 181,  'Gamma'  => 915,  'darr'   => 8595,
    'para'   => 182,  'Delta'  => 916,  'harr'   => 8596,
    'middot' => 183,  'Epsilon'=> 917,  'crarr'  => 8629,
    'cedil'  => 184,  'Zeta'   => 918,  'lArr'   => 8656,
    'sup1'   => 185,  'Eta'    => 919,  'uArr'   => 8657,
    'ordm'   => 186,  'Theta'  => 920,  'rArr'   => 8658,
    'raquo'  => 187,  'Iota'   => 921,  'dArr'   => 8659,
    'frac14' => 188,  'Kappa'  => 922,  'hArr'   => 8660,
    'frac12' => 189,  'Lambda' => 923,  'forall' => 8704,
    'frac34' => 190,  'Mu'     => 924,  'part'   => 8706,
    'iquest' => 191,  'Nu'     => 925,  'exist'  => 8707,
    'Agrave' => 192,  'Xi'     => 926,  'empty'  => 8709,
    'Aacute' => 193,  'Omicron'=> 927,  'nabla'  => 8711,
    'Acirc'  => 194,  'Pi'     => 928,  'isin'   => 8712,
    'Atilde' => 195,  'Rho'    => 929,  'notin'  => 8713,
    'Auml'   => 196,  'Sigma'  => 931,  'ni'     => 8715,
    'Aring'  => 197,  'Tau'    => 932,  'prod'   => 8719,
    'AElig'  => 198,  'Upsilon'=> 933,  'sum'    => 8721,
    'Ccedil' => 199,  'Phi'    => 934,  'minus'  => 8722,
    'Egrave' => 200,  'Chi'    => 935,  'lowast' => 8727,
    'Eacute' => 201,  'Psi'    => 936,  'radic'  => 8730,
    'Ecirc'  => 202,  'Omega'  => 937,  'prop'   => 8733,
    'Euml'   => 203,  'alpha'  => 945,  'infin'  => 8734,
    'Igrave' => 204,  'beta'   => 946,  'ang'    => 8736,
    'Iacute' => 205,  'gamma'  => 947,  'and'    => 8743,
    'Icirc'  => 206,  'delta'  => 948,  'or'     => 8744,
    'Iuml'   => 207,  'epsilon'=> 949,  'cap'    => 8745,
    'ETH'    => 208,  'zeta'   => 950,  'cup'    => 8746,
    'Ntilde' => 209,  'eta'    => 951,  'int'    => 8747,
    'Ograve' => 210,  'theta'  => 952,  'there4' => 8756,
    'Oacute' => 211,  'iota'   => 953,  'sim'    => 8764,
    'Ocirc'  => 212,  'kappa'  => 954,  'cong'   => 8773,
    'Otilde' => 213,  'lambda' => 955,  'asymp'  => 8776,
    'Ouml'   => 214,  'mu'     => 956,  'ne'     => 8800,
    'times'  => 215,  'nu'     => 957,  'equiv'  => 8801,
    'Oslash' => 216,  'xi'     => 958,  'le'     => 8804,
    'Ugrave' => 217,  'omicron'=> 959,  'ge'     => 8805,
    'Uacute' => 218,  'pi'     => 960,  'sub'    => 8834,
    'Ucirc'  => 219,  'rho'    => 961,  'sup'    => 8835,
    'Uuml'   => 220,  'sigmaf' => 962,  'nsub'   => 8836,
    'Yacute' => 221,  'sigma'  => 963,  'sube'   => 8838,
    'THORN'  => 222,  'tau'    => 964,  'supe'   => 8839,
    'szlig'  => 223,  'upsilon'=> 965,  'oplus'  => 8853,
    'agrave' => 224,  'phi'    => 966,  'otimes' => 8855,
    'aacute' => 225,  'chi'    => 967,  'perp'   => 8869,
    'acirc'  => 226,  'psi'    => 968,  'sdot'   => 8901,
    'atilde' => 227,  'omega'  => 969,  'lceil'  => 8968,
    'auml'   => 228,  'thetasym'=>977,  'rceil'  => 8969,
    'aring'  => 229,  'upsih'  => 978,  'lfloor' => 8970,
    'aelig'  => 230,  'piv'    => 982,  'rfloor' => 8971,
    'ccedil' => 231,  'ensp'   => 8194, 'lang'   => 9001,
    'egrave' => 232,  'emsp'   => 8195, 'rang'   => 9002,
    'eacute' => 233,  'thinsp' => 8201, 'loz'    => 9674,
    'ecirc'  => 234,  'zwnj'   => 8204, 'spades' => 9824,
    'euml'   => 235,  'zwj'    => 8205, 'clubs'  => 9827,
    'igrave' => 236,  'lrm'    => 8206, 'hearts' => 9829,
    'iacute' => 237,  'rlm'    => 8207, 'diams'  => 9830,
    'icirc'  => 238,  'ndash'  => 8211,
    'iuml'   => 239,  'mdash'  => 8212,
);
my %entityName; # look up entity names by number (built as necessary)

# HTML info
# (tag ID's are case insensitive and must be all lower case in tables)
%Image::ExifTool::HTML::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        Meta information extracted from the header of HTML and XHTML files.  This is
        a mix of information found in the C<META> elements, C<XML> element, and the
        C<TITLE> element.
    },
    dc => {
        Name => 'DC',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::dc' },
    },
    ncc => {
        Name => 'NCC',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::ncc' },
    },
    prod => {
        Name => 'Prod',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::prod' },
    },
    vw96 => {
        Name => 'VW96',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::vw96' },
    },
   'http-equiv' => {
        Name => 'HTTP-equiv',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::equiv' },
    },
    o => {
        Name => 'Office',
        SubDirectory => { TagTable => 'Image::ExifTool::HTML::Office' },
    },
    abstract        => { },
    author          => { },
    classification  => { },
   'content-language'=>{ Name => 'ContentLanguage' },
    copyright       => { },
    description     => { },
    distribution    => { },
   'doc-class'      => { Name => 'DocClass' },
   'doc-rights'     => { Name => 'DocRights' },
   'doc-type'       => { Name => 'DocType' },
    formatter       => { },
    generator       => { },
    generatorversion=> { Name => 'GeneratorVersion' },
    googlebot       => { Name => 'GoogleBot' },
    keywords        => { List => 1 },
    mssmarttagspreventparsing => { Name => 'NoMSSmartTags' },
    originator      => { },
    owner           => { },
    progid          => { Name => 'ProgID' },
    rating          => { },
    refresh         => { },
   'resource-type'  => { Name => 'ResourceType' },
   'revisit-after'  => { Name => 'RevisitAfter' },
    robots          => { List => 1 },
    title           => { Notes => "the only extracted tag which isn't from an HTML META element" },
);

# ref 2
%Image::ExifTool::HTML::dc = (
    GROUPS => { 1 => 'HTML-dc', 2 => 'Document' },
    NOTES => 'Dublin Core schema tags (also used in XMP).',
    contributor => { Groups => { 2 => 'Author' }, List => 'Bag' },
    coverage    => { },
    creator     => { Groups => { 2 => 'Author' }, List => 'Seq' },
    date        => {
        Groups => { 2 => 'Time'   },
        List => 'Seq',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    description => { },
   'format'     => { },
    identifier  => { },
    language    => { List => 'Bag' },
    publisher   => { Groups => { 2 => 'Author' }, List => 'Bag' },
    relation    => { List => 'Bag' },
    rights      => { Groups => { 2 => 'Author' } },
    source      => { Groups => { 2 => 'Author' } },
    subject     => { List => 'Bag' },
    title       => { },
    type        => { List => 'Bag' },
);

# ref 2
%Image::ExifTool::HTML::ncc = (
    GROUPS => { 1 => 'HTML-ncc', 2 => 'Document' },
    charset         => { Name => 'CharacterSet' }, # name changed to avoid conflict with -charset option
    depth           => { },
    files           => { },
    footnotes       => { },
    generator       => { },
    kbytesize       => { Name => 'KByteSize' },
    maxpagenormal   => { Name => 'MaxPageNormal' },
    multimediatype  => { Name => 'MultimediaType' },
    narrator        => { },
    pagefront       => { Name => 'PageFront' },
    pagenormal      => { Name => 'PageNormal' },
    pagespecial     => { Name => 'PageSpecial' },
    prodnotes       => { Name => 'ProdNotes' },
    producer        => { },
    produceddate    => { Name => 'ProducedDate', Groups => { 2 => 'Time' } }, # YYYY-mm-dd
    revision        => { },
    revisiondate    => { Name => 'RevisionDate', Groups => { 2 => 'Time' } },
    setinfo         => { Name => 'SetInfo' },
    sidebars        => { },
    sourcedate      => { Name => 'SourceDate', Groups => { 2 => 'Time' } },
    sourceedition   => { Name => 'SourceEdition' },
    sourcepublisher => { Name => 'SourcePublisher' },
    sourcerights    => { Name => 'SourceRights' },
    sourcetitle     => { Name => 'SourceTitle' },
    tocitems        => { Name => 'TOCItems' },
    totaltime       => { Name => 'Duration' }, # HH:MM:SS
);

# ref 3
%Image::ExifTool::HTML::vw96 = (
    GROUPS => { 1 => 'HTML-vw96', 2 => 'Document' },
    objecttype      => { Name => 'ObjectType' },
);

# ref 2
%Image::ExifTool::HTML::prod = (
    GROUPS => { 1 => 'HTML-prod', 2 => 'Document' },
    reclocation     => { Name => 'RecLocation' },
    recengineer     => { Name => 'RecEngineer' },
);

# ref 3/4
%Image::ExifTool::HTML::equiv = (
    GROUPS => { 1 => 'HTTP-equiv', 2 => 'Document' },
    NOTES => 'These tags have a family 1 group name of "HTTP-equiv".',
   'cache-control'       => { Name => 'CacheControl' },
   'content-disposition' => { Name => 'ContentDisposition' },
   'content-language'    => { Name => 'ContentLanguage' },
   'content-script-type' => { Name => 'ContentScriptType' },
   'content-style-type'  => { Name => 'ContentStyleType' },
    # note: setting the HTMLCharset like this will miss any tags which come earlier
   'content-type'        => { Name => 'ContentType', RawConv => \&SetHTMLCharset },
   'default-style'       => { Name => 'DefaultStyle' },
    expires              => { },
   'ext-cache'           => { Name => 'ExtCache' },
    imagetoolbar         => { Name => 'ImageToolbar' },
    lotus                => { },
   'page-enter'          => { Name => 'PageEnter' },
   'page-exit'           => { Name => 'PageExit' },
   'pics-label'          => { Name => 'PicsLabel' },
    pragma               => { },
    refresh              => { },
   'reply-to'            => { Name => 'ReplyTo' },
   'set-cookie'          => { Name => 'SetCookie' },
   'site-enter'          => { Name => 'SiteEnter' },
   'site-exit'           => { Name => 'SiteExit' },
    vary                 => { },
   'window-target'       => { Name => 'WindowTarget' },
);

# MS Office namespace (ref PH)
%Image::ExifTool::HTML::Office = (
    GROUPS => { 1 => 'HTML-office', 2 => 'Document' },
    NOTES => 'Tags written by Microsoft Office applications.',
    Subject     => { },
    Author      => { Groups => { 2 => 'Author' } },
    Keywords    => { },
    Description => { },
    Template    => { },
    LastAuthor  => { Groups => { 2 => 'Author' } },
    Revision    => { Name => 'RevisionNumber' },
    TotalTime   => { Name => 'TotalEditTime',   PrintConv => 'ConvertTimeSpan($val, 60)' },
    Created     => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    LastSaved   => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    LastSaved   => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    LastPrinted => {
        Name => 'LastPrinted',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Pages       => { },
    Words       => { },
    Characters  => { },
    Category    => { },
    Manager     => { },
    Company     => { },
    Lines       => { },
    Paragraphs  => { },
    CharactersWithSpaces => { },
    Version     => { Name => 'RevisionNumber' },
);

#------------------------------------------------------------------------------
# Set HTMLCharset member based on content type
# Inputs: 0) content type string, 1) ExifTool ref
# Returns: original string
sub SetHTMLCharset($$)
{
    my ($val, $et) = @_;
    $$et{HTMLCharset} = $htmlCharset{lc $1} if $val =~ /charset=['"]?([-\w]+)/;
    return $val;
}

#------------------------------------------------------------------------------
# Convert single UTF-8 character to HTML character reference
# Inputs: 0) UTF-8 character sequence
# Returns: HTML character reference (eg. "&quot;");
# Note: Must be called via EscapeHTML to load name lookup
sub EscapeChar($)
{
    my $ch = shift;
    my $val;
    if ($] < 5.006001) {
        ($val) = Image::ExifTool::UnpackUTF8($ch);
    } else {
        # the meaning of "U0" is reversed as of Perl 5.10.0!
        ($val) = unpack($] < 5.010000 ? 'U0U' : 'C0U', $ch);
    }
    return '?' unless defined $val;
    return "&$entityName{$val};" if $entityName{$val};
    return sprintf('&#x%x;',$val);
}

#------------------------------------------------------------------------------
# Escape any special characters for HTML
# Inputs: 0) string to be escaped, 1) optional string encoding (default 'UTF8')
# Returns: escaped string
sub EscapeHTML($;$)
{
    my ($str, $enc) = @_;
    # escape XML characters
    $str = EscapeXML($str);
    # escape other special characters if they exist
    if ($str =~ /[\x80-\xff]/) {
        # generate entity name lookup if necessary
        unless (%entityName) {
            local $_;
            foreach (keys %entityNum) {
                $entityName{$entityNum{$_}} = $_;
            }
            delete $entityName{39};  # 'apos' is not valid HTML
        }
        # suppress warnings
        local $SIG{'__WARN__'} = sub { 1 };
        if ($enc and $enc ne 'UTF8') {
            $str = Image::ExifTool::Decode(undef, $str, $enc, undef, 'UTF8');
            $str =~ s/([\xc2-\xf7][\x80-\xbf]+)/EscapeChar($1)/sge;
            $str = Image::ExifTool::Decode(undef, $str, 'UTF8', undef, $enc);
        } else {
            # escape any non-ascii characters for HTML
            $str =~ s/([\xc2-\xf7][\x80-\xbf]+)/EscapeChar($1)/sge;
        }
    }
    return $str;
}

#------------------------------------------------------------------------------
# Unescape all HTML character references
# Inputs: 0) string to be unescaped, 1) optional string encoding (default 'UTF8')
# Returns: unescaped string
sub UnescapeHTML($;$)
{
    my ($str, $enc) = @_;
    return UnescapeXML($str, \%entityNum, $enc);
}

#------------------------------------------------------------------------------
# Extract information from a HTML file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid HTML file
sub ProcessHTML($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    # validate HTML or XHTML file
    $raf->Read($buff, 256) or return 0;
    $buff =~ /^(\xef\xbb\xbf)?\s*<(!DOCTYPE\s+HTML|HTML|\?xml)/i or return 0;
    $buff =~ /<(!DOCTYPE\s+)?HTML/i or return 0 if $2 eq '?xml';
    $et->SetFileType();

    $raf->Seek(0,0) or $et->Warn('Seek error'), return 1;

    local $/ = Image::ExifTool::PostScript::GetInputRecordSeparator($raf);
    $/ or $et->Warn('Invalid HTML data'), return 1;

    # extract header information
    my $doc;
    while ($raf->ReadLine($buff)) {
        if (not defined $doc) {
            # look for 'head' element
            next unless $buff =~ /<head\b/ig;
            $doc = substr($buff, pos($buff));
            next;
        }
        $doc .= $buff;
        last if $buff =~ m{</head>}i;
    }
    return 1 unless defined $doc;

    # process all elements in header
    my $tagTablePtr = GetTagTable('Image::ExifTool::HTML::Main');
    for (;;) {
        last unless $doc =~ m{<([\w:.-]+)(.*?)>}sg;
        my ($tagName, $attrs) = ($1, $2);
        my $tag = lc($tagName);
        my ($val, $grp);
        if ($attrs =~ m{/$}) {  # self-contained XHTML tags end in '/>'
            $val = '';
        } else {
            # look for element close
            my $pos = pos($doc);
            my $close = "</$tagName>";
            # the following doesn't work on Solaris Perl 5.6.1 due to Perl bug:
            # if ($doc =~ m{(.*?)</$tagName>}sg) {
            #     $val = $1;
            if ($doc =~ m{$close}sg) {
                $val = substr($doc, $pos, pos($doc)-$pos-length($close));
            } else {
                pos($doc) = $pos;
                next unless $tag eq 'meta'; # META tags don't need to be closed
                $val = '';
            }
        }
        my $table = $tagTablePtr;
        if ($tag eq 'meta') {
            # parse HTML META element
            undef $tag;
            # tag name is in NAME or HTTP-EQUIV attribute
            if ($attrs =~ /\bname\s*=\s*['"]?([\w:.-]+)/si) {
                $tagName = $1;
            } elsif ($attrs =~ /\bhttp-equiv\s*=\s*['"]?([\w:.-]+)/si) {
                $tagName = "HTTP-equiv.$1";
            } else {
                next;   # no name
            }
            $tag = lc($tagName) or next;
            # tag value is in CONTENT attribute
            if ($attrs =~ /\bcontent\s*=\s*(['"])(.*?)\1/si or
                $attrs =~ /\bcontent\s*=\s*(['"]?)([\w:.-]+)/si)
            {
                $val = $2;
            } else {
                next unless length $val;
            }
            # isolate group name (separator is '.' in HTML, but ':' in ref 2)
            if ($tag =~ /^([\w-]+)[:.]([\w-]+)/) {
                ($grp, $tag) = ($1, $2);
                my $tagInfo = $et->GetTagInfo($tagTablePtr, $grp);
                if ($tagInfo and $$tagInfo{SubDirectory}) {
                    $table = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                } else {
                    $tag = "$grp.$tag";
                }
            }
        } elsif ($tag eq 'xml') {
            $et->VPrint(0, "Parsing XML\n");
            # parse XML tags (quick-and-dirty)
            my $xml = $val;
            while ($xml =~ /<([\w-]+):([\w-]+)(\s.*?)?>([^<]*?)<\/\1:\2>/g) {
                ($grp, $tag, $val) = ($1, $2, $4);
                my $tagInfo = $et->GetTagInfo($tagTablePtr, $grp);
                next unless $tagInfo and $$tagInfo{SubDirectory};
                $table = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                unless ($$table{$tag}) {
                    my $name = ucfirst $tag;
                    $name =~ s/_x([0-9a-f]{4})_/chr(hex($1))/gie; # convert hex codes
                    $name =~ s/\s(.)/\U$1/g;     # capitalize all words in tag name
                    $name =~ tr/-_a-zA-Z0-9//dc; # remove illegal characters (also hex code wide chars)
                    AddTagToTable($table, $tag, { Name => $name });
                    $et->VPrint(0, "  [adding $tag '${name}']\n");
                }
                $val = $et->Decode($val, $$et{HTMLCharset}) if $$et{HTMLCharset};
                $et->HandleTag($table, $tag, UnescapeXML($val));
            }
            next;
        } else {
            # the only other element we process is TITLE
            next unless $tag eq 'title';
        }
        unless ($$table{$tag}) {
            my $name = $tagName;
            $name =~ s/\W+(\w)/\u$1/sg;
            my $info = { Name => $name, Groups => { 0 => 'HTML' } };
            $info->{Groups}->{1} = ($grp eq 'http-equiv' ? 'HTTP-equiv' : "HTML-$grp") if $grp;
            AddTagToTable($table, $tag, $info);
            $et->VPrint(0, "  [adding $tag '${tagName}']\n");
        }
        # recode if necessary
        $val = $et->Decode($val, $$et{HTMLCharset}) if $$et{HTMLCharset};
        $val =~ s{\s*$/\s*}{ }sg;   # replace linefeeds and indenting spaces
        $val = UnescapeHTML($val);  # unescape HTML character references
        $et->HandleTag($table, $tag, $val);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::HTML - Read HTML meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
meta information from HTML documents.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.w3.org/TR/html4/>

=item L<http://www.daisy.org/publications/specifications/daisy_202.html>

=item L<http://vancouver-webpages.com/META/metatags.detail.html>

=item L<http://www.html-reference.com/META.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/HTML Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

