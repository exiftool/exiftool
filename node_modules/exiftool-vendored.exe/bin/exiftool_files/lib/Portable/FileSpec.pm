package Portable::FileSpec;

### UGLY HACK: these functions where completely copied from File::Spec::Win32

use 5.008;
use strict;
use warnings;

our $VERSION = '1.23';

# Some regexes we use for path splitting
my $DRIVE_RX = '[a-zA-Z]:';
my $UNC_RX = '(?:\\\\\\\\|//)[^\\\\/]+[\\\\/][^\\\\/]+';
my $VOL_RX = "(?:$DRIVE_RX|$UNC_RX)";

sub splitpath {
    my ($path, $nofile) = @_;
    my ($volume,$directory,$file) = ('','','');
    if ( $nofile ) {
        $path =~ 
            m{^ ( $VOL_RX ? ) (.*) }sox;
        $volume    = $1;
        $directory = $2;
    }
    else {
        $path =~ 
            m{^ ( $VOL_RX ? )
                ( (?:.*[\\/](?:\.\.?\Z(?!\n))?)? )
                (.*)
             }sox;
        $volume    = $1;
        $directory = $2;
        $file      = $3;
    }

    return ($volume,$directory,$file);
}

sub splitdir {
    my ($directories) = @_ ;
    #
    # split() likes to forget about trailing null fields, so here we
    # check to be sure that there will not be any before handling the
    # simple case.
    #
    if ( $directories !~ m|[\\/]\Z(?!\n)| ) {
        return split( m|[\\/]|, $directories );
    }
    else {
        #
        # since there was a trailing separator, add a file name to the end, 
        # then do the split, then replace it with ''.
        #
        my( @directories )= split( m|[\\/]|, "${directories}dummy" ) ;
        $directories[ $#directories ]= '' ;
        return @directories ;
    }
}

sub catpath {
    my ($volume,$directory,$file) = @_;

    # If it's UNC, make sure the glue separator is there, reusing
    # whatever separator is first in the $volume
    my $v;
    $volume .= $v
        if ( (($v) = $volume =~ m@^([\\/])[\\/][^\\/]+[\\/][^\\/]+\Z(?!\n)@s) &&
             $directory =~ m@^[^\\/]@s
           ) ;

    $volume .= $directory ;

    # If the volume is not just A:, make sure the glue separator is 
    # there, reusing whatever separator is first in the $volume if possible.
    if ( $volume !~ m@^[a-zA-Z]:\Z(?!\n)@s &&
         $volume =~ m@[^\\/]\Z(?!\n)@      &&
         $file   =~ m@[^\\/]@
       ) {
        $volume =~ m@([\\/])@ ;
        my $sep = $1 ? $1 : '\\' ;
        $volume .= $sep ;
    }

    $volume .= $file ;

    return $volume ;
}

sub catdir {
    # Legacy / compatibility support
    return "" unless @_;
    shift, return _canon_cat( "/", @_ ) if $_[0] eq "";

    # Compatibility with File::Spec <= 3.26:
    #     catdir('A:', 'foo') should return 'A:\foo'.
    return _canon_cat( ($_[0].'\\'), @_[1..$#_] ) if $_[0] =~ m{^$DRIVE_RX\z}o;

    return _canon_cat( @_ );
}

sub catfile {
    # Legacy / compatibility support
    #
    shift, return _canon_cat( "/", @_ )
	if $_[0] eq "";

    # Compatibility with File::Spec <= 3.26:
    #     catfile('A:', 'foo') should return 'A:\foo'.
    return _canon_cat( ($_[0].'\\'), @_[1..$#_] )
        if $_[0] =~ m{^$DRIVE_RX\z}o;

    return _canon_cat( @_ );
}

sub _canon_cat {
    my ($first, @rest) = @_;

    my $volume = $first =~ s{ \A ([A-Za-z]:) ([\\/]?) }{}x	# drive letter
    	       ? ucfirst( $1 ).( $2 ? "\\" : "" )
	       : $first =~ s{ \A (?:\\\\|//) ([^\\/]+)
				 (?: [\\/] ([^\\/]+) )?
	       			 [\\/]? }{}xs			# UNC volume
	       ? "\\\\$1".( defined $2 ? "\\$2" : "" )."\\"
	       : $first =~ s{ \A [\\/] }{}x			# root dir
	       ? "\\"
	       : "";
    my $path   = join "\\", $first, @rest;

    $path =~ tr#\\/#\\\\#s;		# xx/yy --> xx\yy & xx\\yy --> xx\yy

    					# xx/././yy --> xx/yy
    $path =~ s{(?:
		(?:\A|\\)		# at begin or after a slash
		\.
		(?:\\\.)*		# and more
		(?:\\|\z) 		# at end or followed by slash
	       )+			# performance boost -- I do not know why
	     }{\\}gx;

    # XXX I do not know whether more dots are supported by the OS supporting
    #     this ... annotation (NetWare or symbian but not MSWin32).
    #     Then .... could easily become ../../.. etc:
    # Replace \.\.\. by (\.\.\.+)  and substitute with
    # { $1 . ".." . "\\.." x (length($2)-2) }gex
	     				# ... --> ../..
    $path =~ s{ (\A|\\)			# at begin or after a slash
    		\.\.\.
		(?=\\|\z) 		# at end or followed by slash
	     }{$1..\\..}gx;
    					# xx\yy\..\zz --> xx\zz
    while ( $path =~ s{(?:
		(?:\A|\\)		# at begin or after a slash
		[^\\]+			# rip this 'yy' off
		\\\.\.
		(?<!\A\.\.\\\.\.)	# do *not* replace ^..\..
		(?<!\\\.\.\\\.\.)	# do *not* replace \..\..
		(?:\\|\z) 		# at end or followed by slash
	       )+			# performance boost -- I do not know why
	     }{\\}sx ) {}

    $path =~ s#\A\\##;			# \xx --> xx  NOTE: this is *not* root
    $path =~ s#\\\z##;			# xx\ --> xx

    if ( $volume =~ m#\\\z# )
    {					# <vol>\.. --> <vol>\
	$path =~ s{ \A			# at begin
		    \.\.
		    (?:\\\.\.)*		# and more
		    (?:\\|\z) 		# at end or followed by slash
		 }{}x;

	return $1			# \\HOST\SHARE\ --> \\HOST\SHARE
	    if    $path eq ""
	      and $volume =~ m#\A(\\\\.*)\\\z#s;
    }
    return $path ne "" || $volume ? $volume.$path : ".";
}


1;
