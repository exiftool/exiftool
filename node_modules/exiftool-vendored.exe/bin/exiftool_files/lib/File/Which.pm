package File::Which;

use strict;
use warnings;
use Exporter   ();
use File::Spec ();

# ABSTRACT: Perl implementation of the which utility as an API
our $VERSION = '1.23'; # VERSION


our @ISA       = 'Exporter';
our @EXPORT    = 'which';
our @EXPORT_OK = 'where';

use constant IS_VMS => ($^O eq 'VMS');
use constant IS_MAC => ($^O eq 'MacOS');
use constant IS_WIN => ($^O eq 'MSWin32' or $^O eq 'dos' or $^O eq 'os2');
use constant IS_DOS => IS_WIN();
use constant IS_CYG => ($^O eq 'cygwin' || $^O eq 'msys');

our $IMPLICIT_CURRENT_DIR = IS_WIN || IS_VMS || IS_MAC;

# For Win32 systems, stores the extensions used for
# executable files
# For others, the empty string is used
# because 'perl' . '' eq 'perl' => easier
my @PATHEXT = ('');
if ( IS_WIN ) {
  # WinNT. PATHEXT might be set on Cygwin, but not used.
  if ( $ENV{PATHEXT} ) {
    push @PATHEXT, split ';', $ENV{PATHEXT};
  } else {
    # Win9X or other: doesn't have PATHEXT, so needs hardcoded.
    push @PATHEXT, qw{.com .exe .bat};
  }
} elsif ( IS_VMS ) {
  push @PATHEXT, qw{.exe .com};
} elsif ( IS_CYG ) {
  # See this for more info
  # http://cygwin.com/cygwin-ug-net/using-specialnames.html#pathnames-exe
  push @PATHEXT, qw{.exe .com};
}


sub which {
  my ($exec) = @_;

  return undef unless defined $exec;
  return undef if $exec eq '';

  my $all = wantarray;
  my @results = ();

  # check for aliases first
  if ( IS_VMS ) {
    my $symbol = `SHOW SYMBOL $exec`;
    chomp($symbol);
    unless ( $? ) {
      return $symbol unless $all;
      push @results, $symbol;
    }
  }
  if ( IS_MAC ) {
    my @aliases = split /\,/, $ENV{Aliases};
    foreach my $alias ( @aliases ) {
      # This has not been tested!!
      # PPT which says MPW-Perl cannot resolve `Alias $alias`,
      # let's just hope it's fixed
      if ( lc($alias) eq lc($exec) ) {
        chomp(my $file = `Alias $alias`);
        last unless $file;  # if it failed, just go on the normal way
        return $file unless $all;
        push @results, $file;
        # we can stop this loop as if it finds more aliases matching,
        # it'll just be the same result anyway
        last;
      }
    }
  }

  return $exec
          if !IS_VMS and !IS_MAC and !IS_WIN and $exec =~ /\// and -f $exec and -x $exec;

  my @path;
  if($^O eq 'MSWin32') {
    # File::Spec (at least recent versions)
    # add the implicit . for you on MSWin32,
    # but we may or may not want to include
    # that.
    @path = split(';', $ENV{PATH});
    s/"//g for @path;
    @path = grep length, @path;
  } else {
    @path = File::Spec->path;
  }
  if ( $IMPLICIT_CURRENT_DIR ) {
    unshift @path, File::Spec->curdir;
  }

  foreach my $base ( map { File::Spec->catfile($_, $exec) } @path ) {
    for my $ext ( @PATHEXT ) {
      my $file = $base.$ext;

      # We don't want dirs (as they are -x)
      next if -d $file;

      if (
        # Executable, normal case
        -x _
        or (
          # MacOS doesn't mark as executable so we check -e
          IS_MAC
          ||
          (
            ( IS_WIN or IS_CYG )
            and
            grep {
              $file =~ /$_\z/i
            } @PATHEXT[1..$#PATHEXT]
          )
          # DOSish systems don't pass -x on
          # non-exe/bat/com files. so we check -e.
          # However, we don't want to pass -e on files
          # that aren't in PATHEXT, like README.
          and -e _
        )
      ) {
        return $file unless $all;
        push @results, $file;
      }
    }
  }

  if ( $all ) {
    return @results;
  } else {
    return undef;
  }
}


sub where {
  # force wantarray
  my @res = which($_[0]);
  return @res;
}

1;

__END__

#line 393
