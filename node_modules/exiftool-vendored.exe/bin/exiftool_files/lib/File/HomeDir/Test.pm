package File::HomeDir::Test;

use 5.008003;
use strict;
use warnings;
use Carp                  ();
use File::Spec            ();
use File::Temp            ();
use File::HomeDir::Driver ();

use vars qw{$VERSION %DIR $ENABLED};
use base "File::HomeDir::Driver";

BEGIN
{
    $VERSION = '1.006';
    %DIR     = ();
    $ENABLED = 0;
}

# Special magic use in test scripts
sub import
{
    my $class = shift;
    Carp::croak "Attempted to initialise File::HomeDir::Test trice" if %DIR;

    # Fill the test directories
    my $BASE = File::Temp::tempdir(CLEANUP => 1);
    %DIR = map { $_ => File::Spec->catdir($BASE, $_) } qw{
      my_home
      my_desktop
      my_documents
      my_data
      my_music
      my_pictures
      my_videos
    };

    # Hijack HOME to the home directory
    $ENV{HOME} = $DIR{my_home};    ## no critic qw(LocalizedPunctuationVars)

    # Make File::HomeDir load us instead of the native driver
    $File::HomeDir::IMPLEMENTED_BY =    # Prevent a warning
      $File::HomeDir::IMPLEMENTED_BY = 'File::HomeDir::Test';

    # Ready to go
    $ENABLED = 1;
}

#####################################################################
# Current User Methods

sub my_home
{
    mkdir($DIR{my_home}, oct(755)) unless -d $DIR{my_home};
    return $DIR{my_home};
}

sub my_desktop
{
    mkdir($DIR{my_desktop}, oct(755)) unless -d $DIR{my_desktop};
    return $DIR{my_desktop};
}

sub my_documents
{
    mkdir($DIR{my_documents}, oct(755)) unless -f $DIR{my_documents};
    return $DIR{my_documents};
}

sub my_data
{
    mkdir($DIR{my_data}, oct(755)) unless -d $DIR{my_data};
    return $DIR{my_data};
}

sub my_music
{
    mkdir($DIR{my_music}, oct(755)) unless -d $DIR{my_music};
    return $DIR{my_music};
}

sub my_pictures
{
    mkdir($DIR{my_pictures}, oct(755)) unless -d $DIR{my_pictures};
    return $DIR{my_pictures};
}

sub my_videos
{
    mkdir($DIR{my_videos}, oct(755)) unless -d $DIR{my_videos};
    return $DIR{my_videos};
}

sub users_home
{
    return undef;
}

1;

__END__

#line 148
