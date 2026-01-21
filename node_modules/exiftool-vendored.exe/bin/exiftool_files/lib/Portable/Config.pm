package Portable::Config;

use 5.008;
use strict;
use warnings;
use Portable::FileSpec;

our $VERSION = '1.23';

#####################################################################
# Constructor

sub new {
	my $class  = shift;
	my $parent = shift;
	unless ( Portable::_HASH($parent->portable_config) ) {
		die('Missing or invalid config key in portable.perl');
	}

	# Create the object
	my $self = bless { }, $class;
	my $conf = $parent->portable_config;
	my $root = $parent->dist_root;
	foreach my $key ( sort keys %$conf ) {
		unless (
			defined $conf->{$key}
			and
			length $conf->{$key}
			and not
			$key =~ /^ld|^libpth$/
		) {
			$self->{$key} = $conf->{$key};
			next;
		}
		#join path to directory of portable perl with value from config file
		if ($key eq 'perlpath') {
		  $self->{$key} = Portable::FileSpec::catfile($root, split /\//, $conf->{$key});
		}
		else {
		  $self->{$key} = Portable::FileSpec::catdir($root, split /\//, $conf->{$key});
		}
	}
	foreach my $key ( grep { /^ld|^libpth$/ } keys %$self ) { 
		#special handling of linker config variables and libpth
		next unless defined $self->{$key};
		$self->{$key} =~ s/\$(\w+)/$self->{$1}/g;
	}

	return $self;
}

sub apply {
	my $self   = shift;
	my $parent = shift;

	# Force all Config entries to load, so that
	# all Config_heavy.pl code has run, and none
	# of our values will be overwritten later.
	require Config;
	my $preload = { %Config::Config };

	# Shift the tie STORE method out the way
	SCOPE: {
		no warnings;
		*Config::_TEMP = *Config::STORE;
		*Config::STORE = sub {
			$_[0]->{$_[1]} = $_[2];
		};
	}

	# Write the values to the Config hash
	foreach my $key ( sort keys %$self ) {
		$Config::Config{$key} = $self->{$key};
	}

	# Restore the STORE method
	SCOPE: {
		no warnings;
		*Config::STORE = delete $Config::{_TEMP};
	}
	
	# Confirm we got all the paths
	my $volume = quotemeta $parent->dist_volume;
	foreach my $key ( sort keys %Config::Config ) {
		next unless defined $Config::Config{$key};
		next if     $Config::Config{$key} =~ /$volume/i;
		next unless $Config::Config{$key} =~ /\b[a-z]\:/i;
		die "Failed to localize \$Config::Config{$key} ($Config::Config{$key})";
	}

	return 1;
}

1;
