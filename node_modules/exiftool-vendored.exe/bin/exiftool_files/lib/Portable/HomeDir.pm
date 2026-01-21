package Portable::HomeDir;

# In the trivial case, only my_home is implemented

use 5.008;
use strict;
use warnings;
use Portable::FileSpec;

our $VERSION = '1.23';

#####################################################################
# Portable Driver API

sub new {
	my $class  = shift;
	my $parent = shift;
	unless ( Portable::_HASH($parent->portable_homedir) ) {
		die('Missing or invalid HomeDir key in portable.perl');
	}

	# Create the object
	my $self = bless { }, $class;

	# Map the 
	my $homedir = $parent->portable_homedir;
	my $root    = $parent->dist_root;
	foreach my $key ( sort keys %$homedir ) {
		unless (
			defined $homedir->{$key}
			and
			length $homedir->{$key}
		) {
			$self->{$key} = $homedir->{$key};
			next;
		}
		$self->{$key} = Portable::FileSpec::catdir(
			$root, split /\//, $homedir->{$key}
		);
	}

	return $self;
}

sub apply {
	my $self = shift;

	# Shortcut if we've already applied
	if ( $File::HomeDir::IMPLEMENTED_BY eq __PACKAGE__ ) {
		return 1;
	}

	# Load File::HomeDir and the regular platform driver
	require File::HomeDir;

	# Remember the platform we're on so we can default
	# to it properly if there's no portable equivalent.
	$self->{platform} = $File::HomeDir::IMPLEMENTED_BY;

	# Hijack the implementation class to us
	$File::HomeDir::IMPLEMENTED_BY = __PACKAGE__;

	return 1;
}

sub platform {
	$_[0]->{platform};
}





#####################################################################
# File::HomeDir::Driver API

sub _SELF {
	ref($_[0]) ? $_[0] : Portable->default->homedir;
}

sub my_home {
	_SELF(@_)->{my_home};
}

# The concept of "my_desktop" is incompatible with the idea of
# a Portable Perl distribution (because Windows won't overwrite
# the desktop with anything on the flash drive)
# sub my_desktop

sub my_documents {
	_SELF(@_)->{my_documents};
}

sub my_music {
	_SELF(@_)->{my_music};
}

sub my_pictures {
	_SELF(@_)->{my_pictures};
}

sub my_videos {
	_SELF(@_)->{my_videos};
}

sub my_data {
	_SELF(@_)->{my_data};
}

1;
