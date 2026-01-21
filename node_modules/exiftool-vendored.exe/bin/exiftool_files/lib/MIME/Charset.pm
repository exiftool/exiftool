#-*- perl -*-

package MIME::Charset;
use 5.005;

=head1 NAME

MIME::Charset - Charset Information for MIME

=head1 SYNOPSIS

    use MIME::Charset:

    $charset = MIME::Charset->new("euc-jp");

Getting charset information:

    $benc = $charset->body_encoding; # e.g. "Q"
    $cset = $charset->as_string; # e.g. "US-ASCII"
    $henc = $charset->header_encoding; # e.g. "S"
    $cset = $charset->output_charset; # e.g. "ISO-2022-JP"

Translating text data:

    ($text, $charset, $encoding) =
        $charset->header_encode(
           "\xc9\xc2\xc5\xaa\xc0\xde\xc3\xef\xc5\xaa".
           "\xc7\xd1\xca\xaa\xbd\xd0\xce\xcf\xb4\xef",
           Charset => 'euc-jp');
    # ...returns e.g. (<converted>, "ISO-2022-JP", "B").

    ($text, $charset, $encoding) =
        $charset->body_encode(
            "Collectioneur path\xe9tiquement ".
            "\xe9clectique de d\xe9chets",
            Charset => 'latin1');
    # ...returns e.g. (<original>, "ISO-8859-1", "QUOTED-PRINTABLE").

    $len = $charset->encoded_header_len(
        "Perl\xe8\xa8\x80\xe8\xaa\x9e",
        Charset => 'utf-8',
        Encoding => "b");
    # ...returns e.g. 28.

Manipulating module defaults:

    MIME::Charset::alias("csEUCKR", "euc-kr");
    MIME::Charset::default("iso-8859-1");
    MIME::Charset::fallback("us-ascii");

Non-OO functions (may be deprecated in near future):

    use MIME::Charset qw(:info);

    $benc = body_encoding("iso-8859-2"); # "Q"
    $cset = canonical_charset("ANSI X3.4-1968"); # "US-ASCII"
    $henc = header_encoding("utf-8"); # "S"
    $cset = output_charset("shift_jis"); # "ISO-2022-JP"

    use MIME::Charset qw(:trans);

    ($text, $charset, $encoding) =
        header_encode(
           "\xc9\xc2\xc5\xaa\xc0\xde\xc3\xef\xc5\xaa".
           "\xc7\xd1\xca\xaa\xbd\xd0\xce\xcf\xb4\xef",
           "euc-jp");
    # ...returns (<converted>, "ISO-2022-JP", "B");

    ($text, $charset, $encoding) =
        body_encode(
            "Collectioneur path\xe9tiquement ".
            "\xe9clectique de d\xe9chets",
            "latin1");
    # ...returns (<original>, "ISO-8859-1", "QUOTED-PRINTABLE");

    $len = encoded_header_len(
        "Perl\xe8\xa8\x80\xe8\xaa\x9e", "b", "utf-8"); # 28

=head1 DESCRIPTION

MIME::Charset provides information about character sets used for
MIME messages on Internet.

=head2 Definitions

The B<charset> is ``character set'' used in MIME to refer to a
method of converting a sequence of octets into a sequence of characters.
It includes both concepts of ``coded character set'' (CCS) and
``character encoding scheme'' (CES) of ISO/IEC.

The B<encoding> is that used in MIME to refer to a method of representing
a body part or a header body as sequence(s) of printable US-ASCII
characters.

=cut

use strict;
use vars qw(@ISA $VERSION @EXPORT @EXPORT_OK %EXPORT_TAGS $Config);
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(body_encoding canonical_charset header_encoding output_charset
	     body_encode encoded_header_len header_encode);
@EXPORT_OK = qw(alias default fallback recommended);
%EXPORT_TAGS = (
		"info" => [qw(body_encoding header_encoding
			      canonical_charset output_charset)],
		"trans" =>[ qw(body_encode encoded_header_len
			       header_encode)],
		);
use Carp qw(croak);

use constant USE_ENCODE => ($] >= 5.007003)? 'Encode': '';

my @ENCODE_SUBS = qw(FB_CROAK FB_PERLQQ FB_HTMLCREF FB_XMLCREF
		     is_utf8 resolve_alias);
if (USE_ENCODE) {
    eval "use ".USE_ENCODE." \@ENCODE_SUBS;";
    if ($@) { # Perl 5.7.3 + Encode 0.40
	eval "use ".USE_ENCODE." qw(is_utf8);";
	require MIME::Charset::_Compat;
	for my $sub (@ENCODE_SUBS) {
	    no strict "refs";
	    *{$sub} = \&{"MIME::Charset::_Compat::$sub"}
		unless $sub eq 'is_utf8';
	}
    }
} else {
    require MIME::Charset::_Compat;
    for my $sub (@ENCODE_SUBS) {
	no strict "refs";
	*{$sub} = \&{"MIME::Charset::_Compat::$sub"};
    }
}

$VERSION = '1.012.2';

######## Private Attributes ########

my $DEFAULT_CHARSET = 'US-ASCII';
my $FALLBACK_CHARSET = 'UTF-8';

# This table was initially borrowed from Python email package.

my %CHARSETS = (# input		    header enc body enc output conv
		'ISO-8859-1' =>		['Q',	'Q',	undef],
		'ISO-8859-2' =>		['Q',	'Q',	undef],
		'ISO-8859-3' =>		['Q',	'Q',	undef],
		'ISO-8859-4' =>		['Q',	'Q',	undef],
		# ISO-8859-5 is Cyrillic, and not especially used
		# ISO-8859-6 is Arabic, also not particularly used
		# ISO-8859-7 is Greek, 'Q' will not make it readable
		# ISO-8859-8 is Hebrew, 'Q' will not make it readable
		'ISO-8859-9' =>		['Q',	'Q',	undef],
		'ISO-8859-10' =>	['Q',	'Q',	undef],
		# ISO-8859-11 is Thai, 'Q' will not make it readable
		'ISO-8859-13' =>	['Q',	'Q',	undef],
		'ISO-8859-14' =>	['Q',	'Q',	undef],
		'ISO-8859-15' =>	['Q',	'Q',	undef],
		'ISO-8859-16' =>	['Q',	'Q',	undef],
		'WINDOWS-1252' =>	['Q',	'Q',	undef],
		'VISCII' =>		['Q',	'Q',	undef],
		'US-ASCII' =>		[undef,	undef,	undef],
		'BIG5' =>		['B',	'B',	undef],
		'GB2312' =>		['B',	'B',	undef],
		'HZ-GB-2312' =>		['B',	undef,	undef],
		'EUC-JP' =>		['B',	undef,	'ISO-2022-JP'],
		'SHIFT_JIS' =>		['B',	undef,	'ISO-2022-JP'],
		'ISO-2022-JP' =>	['B',	undef,	undef],
		'ISO-2022-JP-1' =>	['B',	undef,	undef],
		'ISO-2022-JP-2' =>	['B',	undef,	undef],
		'EUC-JISX0213' =>	['B',	undef,	'ISO-2022-JP-3'],
		'SHIFT_JISX0213' =>	['B',	undef,	'ISO-2022-JP-3'],
		'ISO-2022-JP-3' =>	['B',	undef,	undef],
		'EUC-JIS-2004' =>	['B',	undef,	'ISO-2022-JP-2004'],
		'SHIFT_JIS-2004' =>	['B',	undef,	'ISO-2022-JP-2004'],
		'ISO-2022-JP-2004' =>	['B',	undef,	undef],
		'KOI8-R' =>		['B',	'B',	undef],
		'TIS-620' =>		['B',	'B',	undef], # cf. Mew
		'UTF-16' =>		['B',	'B',	undef],
		'UTF-16BE' => 		['B',	'B',	undef],
		'UTF-16LE' =>		['B',	'B',	undef],
		'UTF-32' =>		['B',	'B',	undef],
		'UTF-32BE' => 		['B',	'B',	undef],
		'UTF-32LE' =>		['B',	'B',	undef],
		'UTF-7' =>		['Q',	undef,	undef],
		'UTF-8' =>		['S',	'S',	undef],
		'GSM03.38' =>		[undef,	undef,	undef], # not for MIME
		# We're making this one up to represent raw unencoded 8bit
		'8BIT' =>		[undef,	'B',	'ISO-8859-1'],
		);

# Fix some unexpected or unpreferred names returned by
# Encode::resolve_alias() or used by somebodies else.
my %CHARSET_ALIASES = (# unpreferred		preferred
		       "ASCII" =>		"US-ASCII",
		       "BIG5-ETEN" =>		"BIG5",
		       "CP1250" =>		"WINDOWS-1250",
		       "CP1251" =>		"WINDOWS-1251",
		       "CP1252" =>		"WINDOWS-1252",
		       "CP1253" =>		"WINDOWS-1253",
		       "CP1254" =>		"WINDOWS-1254",
		       "CP1255" =>		"WINDOWS-1255",
		       "CP1256" =>		"WINDOWS-1256",
		       "CP1257" =>		"WINDOWS-1257",
		       "CP1258" =>		"WINDOWS-1258",
		       "CP874" =>		"WINDOWS-874",
		       "CP936" =>		"GBK",
		       "CP949" =>		"KS_C_5601-1987",
		       "EUC-CN" =>		"GB2312",
		       "HZ" =>			"HZ-GB-2312", # RFC 1842
		       "KS_C_5601" =>		"KS_C_5601-1987",
		       "SHIFTJIS" =>		"SHIFT_JIS",
		       "SHIFTJISX0213" =>	"SHIFT_JISX0213",
		       "TIS620" =>		"TIS-620", # IANA MIBenum 2259
		       "UNICODE-1-1-UTF-7" =>	"UTF-7", # RFC 1642 (obs.)
		       "UTF8" =>		"UTF-8",
		       "UTF-8-STRICT" =>	"UTF-8", # Perl internal use
		       "GSM0338" =>		"GSM03.38", # not for MIME
		       );

# Some vendors encode characters beyond standardized mappings using extended
# encoders.  Some other standard encoders need additional encode modules.
my %ENCODERS = (
		'EXTENDED' => {
		    'ISO-8859-1' => [['cp1252'], ],     # Encode::Byte
		    'ISO-8859-2' => [['cp1250'], ],     # Encode::Byte
		    'ISO-8859-5' => [['cp1251'], ],     # Encode::Byte
		    'ISO-8859-6' => [
				     ['cp1256'],        # Encode::Byte
				     # ['cp1006'],      # ditto, for Farsi
				    ],
		    'ISO-8859-6-I'=>[['cp1256'], ],     # ditto
		    'ISO-8859-7' => [['cp1253'], ],     # Encode::Byte
		    'ISO-8859-8' => [['cp1255'], ],     # Encode::Byte
		    'ISO-8859-8-I'=>[['cp1255'], ],     # ditto
		    'ISO-8859-9' => [['cp1254'], ],     # Encode::Byte
		    'ISO-8859-13'=> [['cp1257'], ],     # Encode::Byte
		    'GB2312'     => [
				     ['gb18030',	'Encode::HanExtra'],
				     ['cp936'],		# Encode::CN
				    ],
		    'EUC-JP'     => [
				     ['eucJP-ascii',	'Encode::EUCJPASCII'],
				     # ['cp51932',	'Encode::EUCJPMS'],
				    ],
		    'ISO-2022-JP'=> [
				     ['x-iso2022jp-ascii',
				      			'Encode::EUCJPASCII'],
				     # ['iso-2022-jp-ms','Encode::ISO2022JPMS'],
				     # ['cp50220',      'Encode::EUCJPMS'],
				     # ['cp50221',      'Encode::EUCJPMS'],
				     ['iso-2022-jp-1'], # Encode::JP (note*)
				    ],
		    'SHIFT_JIS'  => [
				     ['cp932'],		# Encode::JP
				    ],
		    'EUC-JISX0213'  => [['euc-jis-2004', 'Encode::JISX0213'], ],
		    'ISO-2022-JP-3' => [['iso-2022-jp-2004', 'Encode::JISX0213'], ],
		    'SHIFT_JISX0213'=> [['shift_jis-2004', 'Encode::ShiftJIS2004'], ],
		    'EUC-KR'     => [['cp949'], ],      # Encode::KR
		    'BIG5'       => [
				     # ['big5plus',     'Encode::HanExtra'],
				     # ['big5-2003',    'Encode::HanExtra'], 
				     ['cp950'],         # Encode::TW
				     # ['big5-1984',    'Encode::HanExtra'], 
				    ],
		    'TIS-620'    => [['cp874'], ],      # Encode::Byte
		    'UTF-8'      => [['utf8'], ],       # Special name on Perl
		},
		'STANDARD' => {
		    'ISO-8859-6-E'  => [['iso-8859-6'],],# Encode::Byte
		    'ISO-8859-6-I'  => [['iso-8859-6'],],# ditto
		    'ISO-8859-8-E'  => [['iso-8859-8'],],# Encode::Byte
		    'ISO-8859-8-I'  => [['iso-8859-8'],],# ditto
		    'GB18030'       => [['gb18030',     'Encode::HanExtra'], ],
		    'ISO-2022-JP-2' => [['iso-2022-jp-2','Encode::ISO2022JP2'], ],
		    'EUC-JISX0213'  => [['euc-jisx0213', 'Encode::JISX0213'], ],
		    'ISO-2022-JP-3' => [['iso-2022-jp-3', 'Encode::JISX0213'], ],
		    'EUC-JIS-2004'  => [['euc-jis-2004', 'Encode::JISX0213'], ],
		    'ISO-2022-JP-2004' => [['iso-2022-jp-2004', 'Encode::JISX0213'], ],
		    'SHIFT_JIS-2004'=> [['shift_jis-2004', 'Encode::ShiftJIS2004'], ],
		    'EUC-TW'        => [['euc-tw',      'Encode::HanExtra'], ],
		    'HZ-GB-2312'    => [['hz'], ],	# Encode::CN
		    'TIS-620'       => [['tis620'], ],  # (note*)
		    'UTF-16'        => [['x-utf16auto', 'MIME::Charset::UTF'],],
		    'UTF-32'        => [['x-utf32auto', 'MIME::Charset::UTF'],],
		    'GSM03.38'      => [['gsm0338'], ],	# Encode::GSM0338

		    # (note*) ISO-8859-11 was not registered by IANA.
		    # L<Encode> treats it as canonical name of ``tis-?620''.
		},
);

# ISO-2022-* escape sequences etc. to detect charset from unencoded data.
my @ESCAPE_SEQS = ( 
		# ISO-2022-* sequences
		   # escape seq, possible charset
		   # Following sequences are commonly used.
		   ["\033\$\@",	"ISO-2022-JP"],	# RFC 1468
		   ["\033\$B",	"ISO-2022-JP"],	# ditto
		   ["\033(J",	"ISO-2022-JP"],	# ditto
		   ["\033(I",	"ISO-2022-JP"],	# ditto (nonstandard)
		   ["\033\$(D",	"ISO-2022-JP"],	# RFC 2237 (note*)
		   # Following sequences are less commonly used.
		   ["\033.A",   "ISO-2022-JP-2"], # RFC 1554
		   ["\033.F",   "ISO-2022-JP-2"], # ditto
		   ["\033\$(C", "ISO-2022-JP-2"], # ditto
		   ["\033\$(O",	"ISO-2022-JP-3"], # JIS X 0213:2000
		   ["\033\$(P",	"ISO-2022-JP-2004"], # JIS X 0213:2000/2004
		   ["\033\$(Q",	"ISO-2022-JP-2004"], # JIS X 0213:2004
		   ["\033\$)C",	"ISO-2022-KR"],	# RFC 1557
		   ["\033\$)A",	"ISO-2022-CN"], # RFC 1922
		   ["\033\$A",	"ISO-2022-CN"], # ditto (nonstandard)
		   ["\033\$)G",	"ISO-2022-CN"], # ditto
		   ["\033\$*H",	"ISO-2022-CN"], # ditto
		   # Other sequences will be used with appropriate charset
		   # parameters, or hardly used.

		   # note*: This RFC defines ISO-2022-JP-1, superset of 
		   # ISO-2022-JP.  But that charset name is rarely used.
		   # OTOH many of encoders for ISO-2022-JP recognize this
		   # sequence so that comatibility with EUC-JP will be
		   # guaranteed.

		# Singlebyte 7-bit sequences
		   # escape seq, possible charset
		   ["\033e",	"GSM03.38"],	# ESTI GSM 03.38 (note*)
		   ["\033\012",	"GSM03.38"],	# ditto
		   ["\033<",	"GSM03.38"],	# ditto
		   ["\033/",	"GSM03.38"],	# ditto
		   ["\033>",	"GSM03.38"],	# ditto
		   ["\033\024",	"GSM03.38"],	# ditto
		   ["\033(",	"GSM03.38"],	# ditto
		   ["\033\@",	"GSM03.38"],	# ditto
		   ["\033)",	"GSM03.38"],	# ditto
		   ["\033=",	"GSM03.38"],	# ditto

		   # note*: This is not used for MIME message.
		  );

######## Public Configuration Attributes ########

$Config = {
    Detect7bit =>      'YES',
    Mapping =>         'EXTENDED',
    Replacement =>     'DEFAULT',
};
local @INC = @INC;
pop @INC if $INC[-1] eq '.';
eval { require MIME::Charset::Defaults; };

######## Private Constants ########

my $NON7BITRE = qr{
    [^\x01-\x7e]
}x;

my $NONASCIIRE = qr{
    [^\x09\x0a\x0d\x20\x21-\x7e]
}x;

my $ISO2022RE = qr{
    ISO-2022-.+
}ix;

my $ASCIITRANSRE = qr{
    HZ-GB-2312 | UTF-7
}ix;


######## Public Functions ########

=head2 Constructor

=over

=item $charset = MIME::Charset->new([CHARSET [, OPTS]])

Create charset object.

OPTS may accept following key-value pair.
B<NOTE>:
When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
conversion will not be performed.  So this option do not have any effects.

=over 4

=item Mapping => MAPTYPE

Whether to extend mappings actually used for charset names or not.
C<"EXTENDED"> uses extended mappings.
C<"STANDARD"> uses standardized strict mappings.
Default is C<"EXTENDED">.

=back

=cut

sub new {
    my $class = shift;
    my $charset = shift;
    return bless {}, $class unless $charset;
    return bless {}, $class if 75 < length $charset; # w/a for CPAN RT #65796.
    my %params = @_;
    my $mapping = uc($params{'Mapping'} || $Config->{Mapping});

    if ($charset =~ /\bhz.?gb.?2312$/i) {
	# workaround: "HZ-GB-2312" mistakenly treated as "EUC-CN" by Encode
	# (2.12).
	$charset = "HZ-GB-2312";
    } elsif ($charset =~ /\btis-?620$/i) {
	# workaround: "TIS620" treated as ISO-8859-11 by Encode.
	# And "TIS-620" not known by some versions of Encode (cf.
	# CPAN RT #20781).
	$charset = "TIS-620";
    } else {
	$charset = resolve_alias($charset) || $charset
    }
    $charset = $CHARSET_ALIASES{uc($charset)} || uc($charset);
    my ($henc, $benc, $outcset);
    my $spec = $CHARSETS{$charset};
    if ($spec) {
	($henc, $benc, $outcset) =
	    ($$spec[0], $$spec[1], USE_ENCODE? $$spec[2]: undef);
    } else {
	($henc, $benc, $outcset) = ('S', 'B', undef);
    }
    my ($decoder, $encoder);
    if (USE_ENCODE) {
	$decoder = _find_encoder($charset, $mapping);
	$encoder = _find_encoder($outcset, $mapping);
    } else {
	$decoder = $encoder = undef;
    }

    bless {
	InputCharset => $charset,
	Decoder => $decoder,
	HeaderEncoding => $henc,
	BodyEncoding => $benc,
	OutputCharset => ($outcset || $charset),
	Encoder => ($encoder || $decoder),
    }, $class;
}

my %encoder_cache = ();

sub _find_encoder($$) {
    my $charset = uc(shift || "");
    return undef unless $charset;
    my $mapping = uc(shift);
    my ($spec, $name, $module, $encoder);

    local($@);
    $encoder = $encoder_cache{$charset, $mapping};
    return $encoder if ref $encoder;

    foreach my $m (('EXTENDED', 'STANDARD')) {
	next if $m eq 'EXTENDED' and $mapping ne 'EXTENDED';
	$spec = $ENCODERS{$m}->{$charset};
	next unless $spec;
	foreach my $s (@{$spec}) {
	    ($name, $module) = @{$s};
	    if ($module) {
		next unless eval "require $module;";
	    }
	    $encoder = Encode::find_encoding($name);
	    last if ref $encoder;
	}
	last if ref $encoder;
    }
    $encoder ||= Encode::find_encoding($charset);
    $encoder_cache{$charset, $mapping} = $encoder if $encoder;
    return $encoder;
}

=back

=head2 Getting Information of Charsets

=over

=item $charset->body_encoding

=item body_encoding CHARSET

Get recommended transfer-encoding of CHARSET for message body.

Returned value will be one of C<"B"> (BASE64), C<"Q"> (QUOTED-PRINTABLE),
C<"S"> (shorter one of either) or
C<undef> (might not be transfer-encoded; either 7BIT or 8BIT).  This may
not be same as encoding for message header.

=cut

sub body_encoding($) {
    my $self = shift;
    return undef unless $self;
    $self = __PACKAGE__->new($self) unless ref $self;
    $self->{BodyEncoding};
}

=item $charset->as_string

=item canonical_charset CHARSET

Get canonical name for charset.

=cut

sub canonical_charset($) {
    my $self = shift;
    return undef unless $self;
    $self = __PACKAGE__->new($self) unless ref $self;
    $self->{InputCharset};
}

sub as_string($) {
    my $self = shift;
    $self->{InputCharset};
}

=item $charset->decoder

Get L<"Encode::Encoding"> object to decode strings to Unicode by charset.
If charset is not specified or not known by this module,
undef will be returned.

=cut

sub decoder($) {
    my $self = shift;
    $self->{Decoder};
}

=item $charset->dup

Get a copy of charset object.

=cut

sub dup($) {
    my $self = shift;
    my $obj = __PACKAGE__->new(undef);
    %{$obj} = %{$self};
    $obj;
}

=item $charset->encoder([CHARSET])

Get L<"Encode::Encoding"> object to encode Unicode string using compatible
charset recommended to be used for messages on Internet.

If optional CHARSET is specified, replace encoder (and output charset
name) of $charset object with those of CHARSET, therefore,
$charset object will be a converter between original charset and
new CHARSET.

=cut

sub encoder($$;) {
    my $self = shift;
    my $charset = shift;
    if ($charset) {
	$charset = __PACKAGE__->new($charset) unless ref $charset;
	$self->{OutputCharset} = $charset->{InputCharset};
	$self->{Encoder} = $charset->{Decoder};
	$self->{BodyEncoding} = $charset->{BodyEncoding};
	$self->{HeaderEncoding} = $charset->{HeaderEncoding};
    }
    $self->{Encoder};
}

=item $charset->header_encoding

=item header_encoding CHARSET

Get recommended encoding scheme of CHARSET for message header.

Returned value will be one of C<"B">, C<"Q">, C<"S"> (shorter one of either)
or C<undef> (might not be encoded).  This may not be same as encoding
for message body.

=cut

sub header_encoding($) {
    my $self = shift;
    return undef unless $self;
    $self = __PACKAGE__->new($self) unless ref $self;
    $self->{HeaderEncoding};
}

=item $charset->output_charset

=item output_charset CHARSET

Get a charset which is compatible with given CHARSET and is recommended
to be used for MIME messages on Internet (if it is known by this module).

When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
this function will simply
return the result of L<"canonical_charset">.

=cut

sub output_charset($) {
    my $self = shift;
    return undef unless $self;
    $self = __PACKAGE__->new($self) unless ref $self;
    $self->{OutputCharset};
}

=back

=head2 Translating Text Data

=over

=item $charset->body_encode(STRING [, OPTS])

=item body_encode STRING, CHARSET [, OPTS]

Get converted (if needed) data of STRING and recommended transfer-encoding
of that data for message body.  CHARSET is the charset by which STRING
is encoded.

OPTS may accept following key-value pairs.
B<NOTE>:
When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
conversion will not be performed.  So these options do not have any effects.

=over 4

=item Detect7bit => YESNO

Try auto-detecting 7-bit charset when CHARSET is not given.
Default is C<"YES">.

=item Replacement => REPLACEMENT

Specifies error handling scheme.  See L<"Error Handling">.

=back

3-item list of (I<converted string>, I<charset for output>,
I<transfer-encoding>) will be returned.
I<Transfer-encoding> will be either C<"BASE64">, C<"QUOTED-PRINTABLE">,
C<"7BIT"> or C<"8BIT">.  If I<charset for output> could not be determined
and I<converted string> contains non-ASCII byte(s), I<charset for output> will
be C<undef> and I<transfer-encoding> will be C<"BASE64">.
I<Charset for output> will be C<"US-ASCII"> if and only if string does not
contain any non-ASCII bytes.

=cut

sub body_encode {
    my $self = shift;
    my $text;
    if (ref $self) {
	$text = shift;
    } else {
	$text = $self;
	$self = __PACKAGE__->new(shift);
    }
    my ($encoded, $charset) = $self->_text_encode($text, @_);
    return ($encoded, undef, 'BASE64')
	unless $charset and $charset->{InputCharset};
    my $cset = $charset->{OutputCharset};

    # Determine transfer-encoding.
    my $enc = $charset->{BodyEncoding};

    if (!$enc and $encoded !~ /\x00/) {	# Eliminate hostile NUL character.
        if ($encoded =~ $NON7BITRE) {	# String contains 8bit char(s).
            $enc = '8BIT';
	} elsif ($cset =~ /^($ISO2022RE|$ASCIITRANSRE)$/) {	# 7BIT.
            $enc = '7BIT';
        } else {			# Pure ASCII.
            $enc = '7BIT';
            $cset = 'US-ASCII';
        }
    } elsif ($enc eq 'S') {
	$enc = _resolve_S($encoded, 1);
    } elsif ($enc eq 'B') {
        $enc = 'BASE64';
    } elsif ($enc eq 'Q') {
        $enc = 'QUOTED-PRINTABLE';
    } else {
        $enc = 'BASE64';
    }
    return ($encoded, $cset, $enc);
}

=item $charset->decode(STRING [,CHECK])

Decode STRING to Unicode.

B<Note>:
When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
this function will die.

=cut

sub decode($$$;) {
    my $self = shift;
    my $s = shift;
    my $check = shift || 0;
    $self->{Decoder}->decode($s, $check);
}

=item detect_7bit_charset STRING

Guess 7-bit charset that may encode a string STRING.
If STRING contains any 8-bit bytes, C<undef> will be returned.
Otherwise, Default Charset will be returned for unknown charset.

=cut

sub detect_7bit_charset($) {
    return $DEFAULT_CHARSET unless &USE_ENCODE;
    my $s = shift;
    return $DEFAULT_CHARSET unless $s;

    # Non-7bit string
    return undef if $s =~ $NON7BITRE;

    # Try to detect 7-bit escape sequences.
    foreach (@ESCAPE_SEQS) {
	my ($seq, $cset) = @$_;
	if (index($s, $seq) >= 0) {
            my $decoder = __PACKAGE__->new($cset);
            next unless $decoder->{Decoder};
            eval {
		my $dummy = $s;
		$decoder->decode($dummy, FB_CROAK());
	    };
	    if ($@) {
		next;
	    }
	    return $decoder->{InputCharset};
	}
    }

    # How about HZ, VIQR, UTF-7, ...?

    return $DEFAULT_CHARSET;
}

sub _detect_7bit_charset {
    detect_7bit_charset(@_);
}

=item $charset->encode(STRING [, CHECK])

Encode STRING (Unicode or non-Unicode) using compatible charset recommended
to be used for messages on Internet (if this module knows it).
Note that string will be decoded to Unicode then encoded even if compatible charset
was equal to original charset.

B<Note>:
When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
this function will die.

=cut

sub encode($$$;) {
    my $self = shift;
    my $s = shift;
    my $check = shift || 0;

    unless (is_utf8($s) or $s =~ /[^\x00-\xFF]/) {
	$s = $self->{Decoder}->decode($s, ($check & 0x1)? FB_CROAK(): 0);
    }
    my $enc = $self->{Encoder}->encode($s, $check);
    Encode::_utf8_off($enc) if is_utf8($enc); # workaround for RT #35120
    $enc;
}

=item $charset->encoded_header_len(STRING [, ENCODING])

=item encoded_header_len STRING, ENCODING, CHARSET

Get length of encoded STRING for message header
(without folding).

ENCODING may be one of C<"B">, C<"Q"> or C<"S"> (shorter
one of either C<"B"> or C<"Q">).

=cut

sub encoded_header_len($$$;) {
    my $self = shift;
    my ($encoding, $s);
    if (ref $self) {
	$s = shift;
	$encoding = uc(shift || $self->{HeaderEncoding});
    } else {
	$s = $self;
	$encoding = uc(shift);
	$self  = shift;
	$self = __PACKAGE__->new($self) unless ref $self;
    }

    #FIXME:$encoding === undef

    my $enclen;
    if ($encoding eq 'Q') {
        $enclen = _enclen_Q($s);
    } elsif ($encoding eq 'S' and _resolve_S($s) eq 'Q') {
	$enclen = _enclen_Q($s);
    } else { # "B"
        $enclen = _enclen_B($s);
    }

    length($self->{OutputCharset})+$enclen+7;
}

sub _enclen_B($) {
    int((length(shift) + 2) / 3) * 4;
}

sub _enclen_Q($;$) {
    my $s = shift;
    my $in_body = shift;
    my @o;
    if ($in_body) {
	@o = ($s =~ m{([^-\t\r\n !*+/0-9A-Za-z])}go);
    } else {
	@o = ($s =~ m{([^- !*+/0-9A-Za-z])}gos);
    }
    length($s) + scalar(@o) * 2;
}

sub _resolve_S($;$) {
    my $s = shift;
    my $in_body = shift;
    my $e;
    if ($in_body) {
	$e = scalar(() = $s =~ m{[^-\t\r\n !*+/0-9A-Za-z]}g);
	return (length($s) + 8 < $e * 6) ? 'BASE64' : 'QUOTED-PRINTABLE';
    } else {
	$e = scalar(() = $s =~ m{[^- !*+/0-9A-Za-z]}g);
	return (length($s) + 8 < $e * 6) ? 'B' : 'Q';
    }
}

=item $charset->header_encode(STRING [, OPTS])

=item header_encode STRING, CHARSET [, OPTS]

Get converted (if needed) data of STRING and recommended encoding scheme of
that data for message headers.  CHARSET is the charset by which STRING
is encoded.

OPTS may accept following key-value pairs.
B<NOTE>:
When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
conversion will not be performed.  So these options do not have any effects.

=over 4

=item Detect7bit => YESNO

Try auto-detecting 7-bit charset when CHARSET is not given.
Default is C<"YES">.

=item Replacement => REPLACEMENT

Specifies error handling scheme.  See L<"Error Handling">.

=back

3-item list of (I<converted string>, I<charset for output>,
I<encoding scheme>) will be returned.  I<Encoding scheme> will be
either C<"B">, C<"Q"> or C<undef> (might not be encoded).
If I<charset for output> could not be determined and I<converted string>
contains non-ASCII byte(s), I<charset for output> will be C<"8BIT">
(this is I<not> charset name but a special value to represent unencodable
data) and I<encoding scheme> will be C<undef> (should not be encoded).
I<Charset for output> will be C<"US-ASCII"> if and only if string does not
contain any non-ASCII bytes.

=cut

sub header_encode {
    my $self = shift;
    my $text;
    if (ref $self) {
	$text = shift;
    } else {
	$text = $self;
	$self = __PACKAGE__->new(shift);
    }
    my ($encoded, $charset) = $self->_text_encode($text, @_);
    return ($encoded, '8BIT', undef)
	unless $charset and $charset->{InputCharset};
    my $cset = $charset->{OutputCharset};

    # Determine encoding scheme.
    my $enc = $charset->{HeaderEncoding};

    if (!$enc and $encoded !~ $NON7BITRE) {
	unless ($cset =~ /^($ISO2022RE|$ASCIITRANSRE)$/) {	# 7BIT.
            $cset = 'US-ASCII';
        }
    } elsif ($enc eq 'S') {
	$enc = _resolve_S($encoded);
    } elsif ($enc !~ /^[BQ]$/) {
        $enc = 'B';
    }
    return ($encoded, $cset, $enc);
}

sub _text_encode {
    my $charset = shift;
    my $s = shift;
    my %params = @_;
    my $replacement = uc($params{'Replacement'} || $Config->{Replacement});
    my $detect7bit = uc($params{'Detect7bit'} || $Config->{Detect7bit});
    my $encoding = $params{'Encoding'} ||
	(exists $params{'Encoding'}? undef: 'A'); # undocumented

    if (!$encoding or $encoding ne 'A') { # no 7-bit auto-detection
	$detect7bit = 'NO';
    }
    unless ($charset->{InputCharset}) {
	if ($s =~ $NON7BITRE) {
	    return ($s, undef);
	} elsif ($detect7bit ne "NO") {
	    $charset = __PACKAGE__->new(&detect_7bit_charset($s));
	} else {
	    $charset = __PACKAGE__->new($DEFAULT_CHARSET,
					Mapping => 'STANDARD');
	} 
    }
    if (!$encoding or $encoding ne 'A') { # no conversion
	$charset = $charset->dup;
	$charset->encoder($charset);
	$charset->{HeaderEncoding} = $encoding;
	$charset->{BodyEncoding} = $encoding;
    }
    my $check = ($replacement and $replacement =~ /^\d+$/)?
	$replacement:
    {
	'CROAK' => FB_CROAK(),
	'STRICT' => FB_CROAK(),
	'FALLBACK' => FB_CROAK(), # special
	'PERLQQ' => FB_PERLQQ(),
	'HTMLCREF' => FB_HTMLCREF(),
	'XMLCREF' => FB_XMLCREF(),
    }->{$replacement || ""} || 0;

    # Encode data by output charset if required.  If failed, fallback to
    # fallback charset.
    my $encoded;
    if (is_utf8($s) or $s =~ /[^\x00-\xFF]/ or
	($charset->{InputCharset} || "") ne ($charset->{OutputCharset} || "")) {
	if ($check & 0x1) { # CROAK or FALLBACK
	    eval {
		$encoded = $s;
		$encoded = $charset->encode($encoded, FB_CROAK());
	    };
	    if ($@) {
		if ($replacement eq "FALLBACK" and $FALLBACK_CHARSET) {
		    my $cset = __PACKAGE__->new($FALLBACK_CHARSET,
						Mapping => 'STANDARD');
		    # croak unknown charset
		    croak "unknown charset ``$FALLBACK_CHARSET''"
			unless $cset->{Decoder};
		    # charset translation
		    $charset = $charset->dup;
		    $charset->encoder($cset);
		    $encoded = $s;
		    $encoded = $charset->encode($encoded, 0);
		    # replace input & output charsets with fallback charset
		    $cset->encoder($cset);
		    $charset = $cset;
		} else {
		    $@ =~ s/ at .+$//;
		    croak $@;
		}
	    }
	} else {
	    $encoded = $s;
	    $encoded = $charset->encode($encoded, $check);
	}
    } else {
        $encoded = $s;
    }

    if ($encoded !~ /$NONASCIIRE/) { # maybe ASCII
	# check ``ASCII transformation'' charsets
	if ($charset->{OutputCharset} =~ /^($ASCIITRANSRE)$/) {
	    my $u = $encoded;
	    if (USE_ENCODE) {
		$u = $charset->encoder->decode($encoded); # dec. by output
	    } elsif ($encoded =~ /[+~]/) { # workaround for pre-Encode env.
		$u = "x$u";
	    }
	    if ($u eq $encoded) {
		$charset = $charset->dup;
		$charset->encoder($DEFAULT_CHARSET);
	    }
	} elsif ($charset->{OutputCharset} ne "US-ASCII") {
	    $charset = $charset->dup;
	    $charset->encoder($DEFAULT_CHARSET);
	}
    }

    return ($encoded, $charset);
}

=item $charset->undecode(STRING [,CHECK])

Encode Unicode string STRING to byte string by input charset of $charset.
This is equivalent to C<$charset-E<gt>decoder-E<gt>encode()>.

B<Note>:
When Unicode/multibyte support is disabled (see L<"USE_ENCODE">),
this function will die.

=cut

sub undecode($$$;) {
    my $self = shift;
    my $s = shift;
    my $check = shift || 0;
    my $enc = $self->{Decoder}->encode($s, $check);
    Encode::_utf8_off($enc); # workaround for RT #35120
    $enc;
}

=back

=head2 Manipulating Module Defaults

=over

=item alias ALIAS [, CHARSET]

Get/set charset alias for canonical names determined by
L<"canonical_charset">.

If CHARSET is given and isn't false, ALIAS will be assigned as an alias of
CHARSET.  Otherwise, alias won't be changed.  In both cases,
current charset name that ALIAS is assigned will be returned.

=cut

sub alias ($;$) {
    my $alias = uc(shift);
    my $charset = uc(shift);

    return $CHARSET_ALIASES{$alias} unless $charset;

    $CHARSET_ALIASES{$alias} = $charset;
    return $charset;
}

=item default [CHARSET]

Get/set default charset.

B<Default charset> is used by this module when charset context is
unknown.  Modules using this module are recommended to use this
charset when charset context is unknown or implicit default is
expected.  By default, it is C<"US-ASCII">.

If CHARSET is given and isn't false, it will be set to default charset.
Otherwise, default charset won't be changed.  In both cases,
current default charset will be returned.

B<NOTE>: Default charset I<should not> be changed.

=cut

sub default(;$) {
    my $charset = &canonical_charset(shift);

    if ($charset) {
	croak "Unknown charset '$charset'"
	    unless resolve_alias($charset);
	$DEFAULT_CHARSET = $charset;
    }
    return $DEFAULT_CHARSET;
}

=item fallback [CHARSET]

Get/set fallback charset.

B<Fallback charset> is used by this module when conversion by given
charset is failed and C<"FALLBACK"> error handling scheme is specified.
Modules using this module may use this charset as last resort of charset
for conversion.  By default, it is C<"UTF-8">.

If CHARSET is given and isn't false, it will be set to fallback charset.
If CHARSET is C<"NONE">, fallback charset will be undefined.
Otherwise, fallback charset won't be changed.  In any cases,
current fallback charset will be returned.

B<NOTE>: It I<is> useful that C<"US-ASCII"> is specified as fallback charset,
since result of conversion will be readable without charset information.

=cut

sub fallback(;$) {
    my $charset = &canonical_charset(shift);

    if ($charset eq "NONE") {
	$FALLBACK_CHARSET = undef;
    } elsif ($charset) {
	croak "Unknown charset '$charset'"
	    unless resolve_alias($charset);
	$FALLBACK_CHARSET = $charset;
    }
    return $FALLBACK_CHARSET;
}

=item recommended CHARSET [, HEADERENC, BODYENC [, ENCCHARSET]]

Get/set charset profiles.

If optional arguments are given and any of them are not false, profiles
for CHARSET will be set by those arguments.  Otherwise, profiles
won't be changed.  In both cases, current profiles for CHARSET will be
returned as 3-item list of (HEADERENC, BODYENC, ENCCHARSET).

HEADERENC is recommended encoding scheme for message header.
It may be one of C<"B">, C<"Q">, C<"S"> (shorter one of either) or
C<undef> (might not be encoded).

BODYENC is recommended transfer-encoding for message body.  It may be
one of C<"B">, C<"Q">, C<"S"> (shorter one of either) or
C<undef> (might not be transfer-encoded).

ENCCHARSET is a charset which is compatible with given CHARSET and
is recommended to be used for MIME messages on Internet.
If conversion is not needed (or this module doesn't know appropriate
charset), ENCCHARSET is C<undef>.

B<NOTE>: This function in the future releases can accept more optional
arguments (for example, properties to handle character widths, line folding
behavior, ...).  So format of returned value may probably be changed.
Use L<"header_encoding">, L<"body_encoding"> or L<"output_charset"> to get
particular profile.

=cut

sub recommended ($;$;$;$) {
    my $charset = &canonical_charset(shift);
    my $henc = uc(shift) || undef;
    my $benc = uc(shift) || undef;
    my $cset = &canonical_charset(shift);

    croak "CHARSET is not specified" unless $charset;
    croak "Unknown header encoding" unless !$henc or $henc =~ /^[BQS]$/;
    croak "Unknown body encoding" unless !$benc or $benc =~ /^[BQ]$/;

    if ($henc or $benc or $cset) {
	$cset = undef if $charset eq $cset;
	my @spec = ($henc, $benc, USE_ENCODE? $cset: undef);
	$CHARSETS{$charset} = \@spec;
	return @spec;
    } else {
	$charset = __PACKAGE__->new($charset) unless ref $charset;
	return map { $charset->{$_} } qw(HeaderEncoding BodyEncoding
					 OutputCharset);
    }
}

=back

=head2 Constants

=over

=item USE_ENCODE

Unicode/multibyte support flag.
Non-empty string will be set when Unicode and multibyte support is enabled.
Currently, this flag will be non-empty on Perl 5.7.3 or later and
empty string on earlier versions of Perl.

=back

=head2 Error Handling

L<"body_encode"> and L<"header_encode"> accept following C<Replacement>
options:

=over

=item C<"DEFAULT">

Put a substitution character in place of a malformed character.
For UCM-based encodings, <subchar> will be used.

=item C<"FALLBACK">

Try C<"DEFAULT"> scheme using I<fallback charset> (see L<"fallback">).
When fallback charset is undefined and conversion causes error,
code will die on error with an error message.

=item C<"CROAK">

Code will die on error immediately with an error message.
Therefore, you should trap the fatal error with eval{} unless you
really want to let it die on error.
Synonym is C<"STRICT">.

=item C<"PERLQQ">

=item C<"HTMLCREF">

=item C<"XMLCREF">

Use C<FB_PERLQQ>, C<FB_HTMLCREF> or C<FB_XMLCREF>
scheme defined by L<Encode> module.

=item numeric values

Numeric values are also allowed.
For more details see L<Encode/Handling Malformed Data>.

=back

If error handling scheme is not specified or unknown scheme is specified,
C<"DEFAULT"> will be assumed.

=head2 Configuration File

Built-in defaults for option parameters can be overridden by configuration
file: F<MIME/Charset/Defaults.pm>.
For more details read F<MIME/Charset/Defaults.pm.sample>.

=head1 VERSION

Consult $VERSION variable.

Development versions of this module may be found at
L<http://hatuka.nezumi.nu/repos/MIME-Charset/>.

=head2 Incompatible Changes

=over 4

=item Release 1.001

=over 4

=item *

new() method returns an object when CHARSET argument is not specified.

=back

=item Release 1.005

=over 4

=item *

Restrict characters in encoded-word according to RFC 2047 section 5 (3).
This also affects return value of encoded_header_len() method.

=back

=item Release 1.008.2

=over 4

=item *

body_encoding() method may also returns C<"S">.

=item *

Return value of body_encode() method for UTF-8 may include
C<"QUOTED-PRINTABLE"> encoding item that in earlier versions was fixed to
C<"BASE64">.

=back

=back

=head1 SEE ALSO

Multipurpose Internet Mail Extensions (MIME).

=head1 AUTHOR

Hatuka*nezumi - IKEDA Soji <hatuka(at)nezumi.nu>

=head1 COPYRIGHT

Copyright (C) 2006-2017 Hatuka*nezumi - IKEDA Soji.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
