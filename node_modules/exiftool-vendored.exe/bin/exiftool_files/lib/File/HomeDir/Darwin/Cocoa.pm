package File::HomeDir::Darwin::Cocoa;

use 5.008003;
use strict;
use warnings;
use Cwd                   ();
use Carp                  ();
use File::HomeDir::Darwin ();

use vars qw{$VERSION};
use base "File::HomeDir::Darwin";

BEGIN
{
    $VERSION = '1.006';

    # Load early if in a forking environment and we have
    # prefork, or at run-time if not.
    local $@;                                     ## no critic (Variables::RequireInitializationForLocalVars)
    eval "use prefork 'Mac::SystemDirectory'";    ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
}

#####################################################################
# Current User Methods

## no critic qw(UnusedPrivateSubroutines)
sub _guess_determined_home
{
    my $class = shift;

    require Mac::SystemDirectory;
    my $home = Mac::SystemDirectory::HomeDirectory();
    $home ||= $class->SUPER::_guess_determined_home($@);
    return $home;
}

# from 10.4
sub my_desktop
{
    my $class = shift;

    require Mac::SystemDirectory;
    eval { $class->_find_folder(Mac::SystemDirectory::NSDesktopDirectory()) }
      || $class->SUPER::my_desktop;
}

# from 10.2
sub my_documents
{
    my $class = shift;

    require Mac::SystemDirectory;
    eval { $class->_find_folder(Mac::SystemDirectory::NSDocumentDirectory()) }
      || $class->SUPER::my_documents;
}

# from 10.4
sub my_data
{
    my $class = shift;

    require Mac::SystemDirectory;
    eval { $class->_find_folder(Mac::SystemDirectory::NSApplicationSupportDirectory()) }
      || $class->SUPER::my_data;
}

# from 10.6
sub my_music
{
    my $class = shift;

    require Mac::SystemDirectory;
    eval { $class->_find_folder(Mac::SystemDirectory::NSMusicDirectory()) }
      || $class->SUPER::my_music;
}

# from 10.6
sub my_pictures
{
    my $class = shift;

    require Mac::SystemDirectory;
    eval { $class->_find_folder(Mac::SystemDirectory::NSPicturesDirectory()) }
      || $class->SUPER::my_pictures;
}

# from 10.6
sub my_videos
{
    my $class = shift;

    require Mac::SystemDirectory;
    eval { $class->_find_folder(Mac::SystemDirectory::NSMoviesDirectory()) }
      || $class->SUPER::my_videos;
}

sub _find_folder
{
    my $class = shift;
    my $name  = shift;

    require Mac::SystemDirectory;
    my $folder = Mac::SystemDirectory::FindDirectory($name);
    return undef unless defined $folder;

    unless (-d $folder)
    {
        # Make sure that symlinks resolve to directories.
        return undef unless -l $folder;
        my $dir = readlink $folder or return;
        return undef unless -d $dir;
    }

    return Cwd::abs_path($folder);
}

1;

#line 158
