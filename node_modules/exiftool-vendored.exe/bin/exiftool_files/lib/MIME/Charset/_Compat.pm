
package MIME::Charset::_Compat;
use 5.004;

use strict;
use Carp qw(croak);

use vars qw($VERSION);

$VERSION = "1.003.1";

sub FB_CROAK { 0x1; }
sub FB_PERLQQ { 0x100; }
sub FB_HTMLCREF { 0x200; }
sub FB_XMLCREF { 0x400; }
sub encode { $_[1]; }
sub decode { $_[1]; }
sub from_to {
    if ((lc($_[2]) eq "us-ascii" or lc($_[1]) eq "us-ascii") and
	$_[0] =~ s/[^\x01-\x7e]/?/g and $_[3] == 1) {
	croak "Non-ASCII characters";
    }
    $_[0];
}
sub is_utf8 { 0; }
sub resolve_alias {
    my $cset = lc(shift);
    if ($cset eq "8bit" or $cset !~ /\S/) {
	return undef;
    } elsif ($cset eq '_unicode_') {
	return $cset;
    } else {
	# Taken from Encode-2.24.
	my %Winlatin2cp = (
	   'latin1'     => 1252,
	   'latin2'     => 1250,
	   'cyrillic'   => 1251,
	   'greek'      => 1253,
	   'turkish'    => 1254,
	   'hebrew'     => 1255,
	   'arabic'     => 1256,
	   'baltic'     => 1257,
	   'vietnamese' => 1258,
	);
	my @Latin2iso = ( 0, 1, 2, 3, 4, 9, 10, 13, 14, 15, 16 );
	$cset =~ s/^(\S+)[\s_]+(.*)$/$1-$2/i;
	$cset =~ s/^UTF-8$/utf8/i;
	$cset =~ s/^.*\bhk(?:scs)?[-_]?big5$/big5-hkscs/i;
	$cset =~ s/^.*\bbig5-?hk(?:scs)?$/big5-hkscs/i;
	$cset =~ s/^.*\btca[-_]?big5$/big5-eten/i;
	$cset =~ s/^.*\bbig5-?et(?:en)?$/big5-eten/i;
	$cset =~ s/^.*\bbig-?5$/big5-eten/i;
	$cset =~ s/^.*\bks_c_5601-1987$/cp949/i;
	$cset =~ s/^.*(?:x-)?windows-949$/cp949/i;
	$cset =~ s/^.*(?:x-)?uhc$/cp949/i;
	$cset =~ s/^.*\bkr.*euc$/euc-kr/i;
	$cset =~ s/^.*\beuc.*kr$/euc-kr/i;
	$cset =~ s/^.*\bsjis$/shiftjis/i;
	$cset =~ s/^.*\bshift.*jis$/shiftjis/i;
	$cset =~ s/^.*\bujis$/euc-jp/i;
	$cset =~ s/^.*\bjp.*euc$/euc-jp/i;
	$cset =~ s/^.*\beuc.*jp$/euc-jp/i;
	$cset =~ s/^.*\bjis$/7bit-jis/i;
	$cset =~ s/^.*\bGB[-_ ]?2312(?!-?raw).*$/euc-cn/i;
	$cset =~ s/^gbk$/cp936/i;
	$cset =~ s/^.*\bcn.*euc$/euc-cn/i;
	$cset =~ s/^.*\beuc.*cn$/euc-cn/i;
	$cset =~ s/^.*\bkoi8[-\s_]*([ru])$/koi8-$1/i;
	$cset =~ s/^mac_(.*)$/mac$1/i;
	$cset =~ s/^.*\b(?:cp|ibm|ms|windows)[-_ ]?(\d{2,4})$/cp$1/i;
	$cset =~ s/^tis620$/iso-8859-11/i;
	$cset =~ s/^thai$/iso-8859-11/i;
	$cset =~ s/^hebrew$/iso-8859-8/i;
	$cset =~ s/^greek$/iso-8859-7/i;
	$cset =~ s/^arabic$/iso-8859-6/i;
	$cset =~ s/^cyrillic$/iso-8859-5/i;
	$cset =~ s/^ascii$/US-ascii/i;
	if ($cset =~ /^.*\bwin(latin[12]|cyrillic|baltic|greek|turkish|
			    hebrew|arabic|baltic|vietnamese)$/ix) {
	    $cset = "cp" . $Winlatin2cp{lc($1)};
	}
	if ($cset =~ /^.*\b(?:iso[-_]?)?latin[-_]?(\d+)$/i) {
	    $cset = defined $Latin2iso[$1] ? "iso-8859-$Latin2iso[$1]" : undef;
	}
	$cset =~ s/^(.+)\@euro$/$1/i;
	$cset =~ s/^.*\bANSI[-_]?X3\.4[-_]?1968$/ascii/i;
	$cset =~ s/^.*\b(?:hp-)?(arabic|greek|hebrew|kana|roman|thai|turkish)8$/${1}8/i;
	$cset =~ s/^.*\biso8859(\d+)$/iso-8859-$1/i;
	$cset =~ s/^.*\biso[-_]?(\d+)[-_](\d+)$/iso-$1-$2/i;
	$cset =~ s/^.*\bISO[-_]?646[-_]?US$/ascii/i;
	$cset =~ s/^C$/ascii/i;
	$cset =~ s/^(?:US-?)ascii$/ascii/i;
	$cset =~ s/^UTF(16|32)$/UTF-$1/i;
	$cset =~ s/^UTF(16|32)-?LE$/UTF-$1LE/i;
	$cset =~ s/^UTF(16|32)-?BE$/UTF-$1BE/i;
	$cset =~ s/^iso-10646-1$/UCS-2BE/i;
	$cset =~ s/^UCS-?4-?(BE|LE)?$/uc("UTF-32$1")/ie;
	$cset =~ s/^UCS-?2-?(BE)?$/UCS-2BE/i;
	$cset =~ s/^UCS-?2-?LE$/UCS-2LE/i;
	$cset =~ s/^UTF-?7$/UTF-7/i;
	$cset =~ s/^(.*)$/\L$1/;
	return $cset;
    }
}

1;
