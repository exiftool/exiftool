package File::HomeDir;

# See POD at end for documentation

use 5.008003;
use strict;
use warnings;
use Carp        ();
use Config      ();
use File::Spec  ();
use File::Which ();

# Globals
use vars qw{$VERSION @EXPORT @EXPORT_OK $IMPLEMENTED_BY};    ## no critic qw(AutomaticExportation)
use base qw(Exporter);

BEGIN
{
    $VERSION = '1.006';

    # Inherit manually
    require Exporter;
    @EXPORT    = qw{home};
    @EXPORT_OK = qw{
      home
      my_home
      my_desktop
      my_documents
      my_music
      my_pictures
      my_videos
      my_data
      my_dist_config
      my_dist_data
      users_home
      users_desktop
      users_documents
      users_music
      users_pictures
      users_videos
      users_data
    };
}

# Inlined Params::Util functions
sub _CLASS ($)    ## no critic qw(SubroutinePrototypes)
{
    (defined $_[0] and not ref $_[0] and $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*\z/s) ? $_[0] : undef;
}

sub _DRIVER ($$)    ## no critic qw(SubroutinePrototypes)
{
    (defined _CLASS($_[0]) and eval "require $_[0]; 1" and $_[0]->isa($_[1]) and $_[0] ne $_[1]) ? $_[0] : undef;
}

# Platform detection
if ($IMPLEMENTED_BY)
{
    # Allow for custom HomeDir classes
    # Leave it as the existing value
}
elsif ($^O eq 'MSWin32')
{
    # All versions of Windows
    $IMPLEMENTED_BY = 'File::HomeDir::Windows';
}
elsif ($^O eq 'darwin')
{
    # 1st: try Mac::SystemDirectory by chansen
    if (eval "require Mac::SystemDirectory; 1")
    {
        $IMPLEMENTED_BY = 'File::HomeDir::Darwin::Cocoa';
    }
    elsif (eval "require Mac::Files; 1")
    {
        # 2nd try Mac::Files: Carbon - unmaintained since 2006 except some 64bit fixes
        $IMPLEMENTED_BY = 'File::HomeDir::Darwin::Carbon';
    }
    else
    {
        # 3rd: fallback: pure perl
        $IMPLEMENTED_BY = 'File::HomeDir::Darwin';
    }
}
elsif ($^O eq 'MacOS')
{
    # Legacy Mac OS
    $IMPLEMENTED_BY = 'File::HomeDir::MacOS9';
}
elsif (File::Which::which('xdg-user-dir'))
{
    # freedesktop unixes
    $IMPLEMENTED_BY = 'File::HomeDir::FreeDesktop';
}
else
{
    # Default to Unix semantics
    $IMPLEMENTED_BY = 'File::HomeDir::Unix';
}

unless (_DRIVER($IMPLEMENTED_BY, 'File::HomeDir::Driver'))
{
    Carp::croak("Missing or invalid File::HomeDir driver $IMPLEMENTED_BY");
}

#####################################################################
# Current User Methods

sub my_home
{
    $IMPLEMENTED_BY->my_home;
}

sub my_desktop
{
    $IMPLEMENTED_BY->can('my_desktop')
      ? $IMPLEMENTED_BY->my_desktop
      : Carp::croak("The my_desktop method is not implemented on this platform");
}

sub my_documents
{
    $IMPLEMENTED_BY->can('my_documents')
      ? $IMPLEMENTED_BY->my_documents
      : Carp::croak("The my_documents method is not implemented on this platform");
}

sub my_music
{
    $IMPLEMENTED_BY->can('my_music')
      ? $IMPLEMENTED_BY->my_music
      : Carp::croak("The my_music method is not implemented on this platform");
}

sub my_pictures
{
    $IMPLEMENTED_BY->can('my_pictures')
      ? $IMPLEMENTED_BY->my_pictures
      : Carp::croak("The my_pictures method is not implemented on this platform");
}

sub my_videos
{
    $IMPLEMENTED_BY->can('my_videos')
      ? $IMPLEMENTED_BY->my_videos
      : Carp::croak("The my_videos method is not implemented on this platform");
}

sub my_data
{
    $IMPLEMENTED_BY->can('my_data')
      ? $IMPLEMENTED_BY->my_data
      : Carp::croak("The my_data method is not implemented on this platform");
}

sub my_dist_data
{
    my $params = ref $_[-1] eq 'HASH' ? pop : {};
    my $dist   = pop or Carp::croak("The my_dist_data method requires an argument");
    my $data   = my_data();

    # If datadir is not defined, there's nothing we can do: bail out
    # and return nothing...
    return undef unless defined $data;

    # On traditional unixes, hide the top-level directory
    my $var =
      $data eq home()
      ? File::Spec->catdir($data, '.perl', 'dist', $dist)
      : File::Spec->catdir($data, 'Perl',  'dist', $dist);

    # directory exists: return it
    return $var if -d $var;

    # directory doesn't exist: check if we need to create it...
    return undef unless $params->{create};

    # user requested directory creation
    require File::Path;
    File::Path::mkpath($var);
    return $var;
}

sub my_dist_config
{
    my $params = ref $_[-1] eq 'HASH' ? pop : {};
    my $dist   = pop or Carp::croak("The my_dist_config method requires an argument");

    # not all platforms support a specific my_config() method
    my $config =
        $IMPLEMENTED_BY->can('my_config')
      ? $IMPLEMENTED_BY->my_config
      : $IMPLEMENTED_BY->my_documents;

    # If neither configdir nor my_documents is defined, there's
    # nothing we can do: bail out and return nothing...
    return undef unless defined $config;

    # On traditional unixes, hide the top-level dir
    my $etc =
      $config eq home()
      ? File::Spec->catdir($config, '.perl', $dist)
      : File::Spec->catdir($config, 'Perl',  $dist);

    # directory exists: return it
    return $etc if -d $etc;

    # directory doesn't exist: check if we need to create it...
    return undef unless $params->{create};

    # user requested directory creation
    require File::Path;
    File::Path::mkpath($etc);
    return $etc;
}

#####################################################################
# General User Methods

sub users_home
{
    $IMPLEMENTED_BY->can('users_home')
      ? $IMPLEMENTED_BY->users_home($_[-1])
      : Carp::croak("The users_home method is not implemented on this platform");
}

sub users_desktop
{
    $IMPLEMENTED_BY->can('users_desktop')
      ? $IMPLEMENTED_BY->users_desktop($_[-1])
      : Carp::croak("The users_desktop method is not implemented on this platform");
}

sub users_documents
{
    $IMPLEMENTED_BY->can('users_documents')
      ? $IMPLEMENTED_BY->users_documents($_[-1])
      : Carp::croak("The users_documents method is not implemented on this platform");
}

sub users_music
{
    $IMPLEMENTED_BY->can('users_music')
      ? $IMPLEMENTED_BY->users_music($_[-1])
      : Carp::croak("The users_music method is not implemented on this platform");
}

sub users_pictures
{
    $IMPLEMENTED_BY->can('users_pictures')
      ? $IMPLEMENTED_BY->users_pictures($_[-1])
      : Carp::croak("The users_pictures method is not implemented on this platform");
}

sub users_videos
{
    $IMPLEMENTED_BY->can('users_videos')
      ? $IMPLEMENTED_BY->users_videos($_[-1])
      : Carp::croak("The users_videos method is not implemented on this platform");
}

sub users_data
{
    $IMPLEMENTED_BY->can('users_data')
      ? $IMPLEMENTED_BY->users_data($_[-1])
      : Carp::croak("The users_data method is not implemented on this platform");
}

#####################################################################
# Legacy Methods

# Find the home directory of an arbitrary user
sub home (;$)    ## no critic qw(SubroutinePrototypes)
{
    # Allow to be called as a method
    if ($_[0] and $_[0] eq 'File::HomeDir')
    {
        shift();
    }

    # No params means my home
    return my_home() unless @_;

    # Check the param
    my $name = shift;
    if (!defined $name)
    {
        Carp::croak("Can't use undef as a username");
    }
    if (!length $name)
    {
        Carp::croak("Can't use empty-string (\"\") as a username");
    }

    # A dot also means my home
    ### Is this meant to mean File::Spec->curdir?
    if ($name eq '.')
    {
        return my_home();
    }

    # Now hand off to the implementor
    $IMPLEMENTED_BY->users_home($name);
}
eval {
	require Portable;
	Portable->import('HomeDir');
};


1;

__END__

#line 729
