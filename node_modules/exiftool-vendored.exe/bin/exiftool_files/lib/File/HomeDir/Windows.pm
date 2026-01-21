package File::HomeDir::Windows;

# See POD at the end of the file for documentation

use 5.008003;
use strict;
use warnings;
use Carp                  ();
use File::Spec            ();
use File::HomeDir::Driver ();

use vars qw{$VERSION};
use base "File::HomeDir::Driver";

BEGIN
{
    $VERSION = '1.006';
}

sub CREATE () { 1 }

#####################################################################
# Current User Methods

sub my_home
{
    my $class = shift;

    # A lot of unix people and unix-derived tools rely on
    # the ability to overload HOME. We will support it too
    # so that they can replace raw HOME calls with File::HomeDir.
    if (exists $ENV{HOME} and defined $ENV{HOME} and length $ENV{HOME})
    {
        return $ENV{HOME};
    }

    # Do we have a user profile?
    if (exists $ENV{USERPROFILE} and $ENV{USERPROFILE})
    {
        return $ENV{USERPROFILE};
    }

    # Some Windows use something like $ENV{HOME}
    if (exists $ENV{HOMEDRIVE} and exists $ENV{HOMEPATH} and $ENV{HOMEDRIVE} and $ENV{HOMEPATH})
    {
        return File::Spec->catpath($ENV{HOMEDRIVE}, $ENV{HOMEPATH}, '',);
    }

    return undef;
}

sub my_desktop
{
    my $class = shift;

    # The most correct way to find the desktop
  SCOPE:
    {
        require Win32;
        my $dir = Win32::GetFolderPath(Win32::CSIDL_DESKTOP(), CREATE);
        return $dir if $dir and $class->_d($dir);
    }

    # MSWindows sets WINDIR, MS WinNT sets USERPROFILE.
    foreach my $e ('USERPROFILE', 'WINDIR')
    {
        next unless $ENV{$e};
        my $desktop = File::Spec->catdir($ENV{$e}, 'Desktop');
        return $desktop if $desktop and $class->_d($desktop);
    }

    # As a last resort, try some hard-wired values
    foreach my $fixed (
        # The reason there are both types of slash here is because
        # this set of paths has been kept from the original version
        # of File::HomeDir::Win32 (before it was rewritten).
        # I can only assume this is Cygwin-related stuff.
        "C:\\windows\\desktop",
        "C:\\win95\\desktop",
        "C:/win95/desktop",
        "C:/windows/desktop",
      )
    {
        return $fixed if $class->_d($fixed);
    }

    return undef;
}

sub my_documents
{
    my $class = shift;

    # The most correct way to find my documents
  SCOPE:
    {
        require Win32;
        my $dir = Win32::GetFolderPath(Win32::CSIDL_PERSONAL(), CREATE);
        return $dir if $dir and $class->_d($dir);
    }

    return undef;
}

sub my_data
{
    my $class = shift;

    # The most correct way to find my documents
  SCOPE:
    {
        require Win32;
        my $dir = Win32::GetFolderPath(Win32::CSIDL_LOCAL_APPDATA(), CREATE);
        return $dir if $dir and $class->_d($dir);
    }

    return undef;
}

sub my_music
{
    my $class = shift;

    # The most correct way to find my music
  SCOPE:
    {
        require Win32;
        my $dir = Win32::GetFolderPath(Win32::CSIDL_MYMUSIC(), CREATE);
        return $dir if $dir and $class->_d($dir);
    }

    return undef;
}

sub my_pictures
{
    my $class = shift;

    # The most correct way to find my pictures
  SCOPE:
    {
        require Win32;
        my $dir = Win32::GetFolderPath(Win32::CSIDL_MYPICTURES(), CREATE);
        return $dir if $dir and $class->_d($dir);
    }

    return undef;
}

sub my_videos
{
    my $class = shift;

    # The most correct way to find my videos
  SCOPE:
    {
        require Win32;
        my $dir = Win32::GetFolderPath(Win32::CSIDL_MYVIDEO(), CREATE);
        return $dir if $dir and $class->_d($dir);
    }

    return undef;
}

# Special case version of -d
sub _d
{
    my $self = shift;
    my $path = shift;

    # Window can legally return a UNC path from GetFolderPath.
    # Not only is the meaning of -d complicated in this situation,
    # but even on a local network calling -d "\\\\cifs\\path" can
    # take several seconds. UNC can also do even weirder things,
    # like launching processes and such.
    # To avoid various crazy bugs caused by this, we do NOT attempt
    # to validate UNC paths at all so that the code that is calling
    # us has an opportunity to take special actions without our
    # blundering getting in the way.
    if ($path =~ /\\\\/)
    {
        return 1;
    }

    # Otherwise do a stat as normal
    return -d $path;
}

1;

#line 261
