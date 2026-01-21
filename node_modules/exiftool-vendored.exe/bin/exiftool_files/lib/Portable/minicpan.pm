package Portable::minicpan;

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
	unless ( Portable::_HASH($parent->portable_minicpan) ) {
		die('Missing or invalid minicpan key in portable.perl');
	}

	# Create the object
	my $self = bless { }, $class;

	# Map paths to absolute paths
	my $minicpan = $parent->portable_minicpan;
	my $root     = $parent->dist_root;
	foreach my $key ( qw{ local } ) {
		unless (
			defined $minicpan->{$key}
			and
			length $minicpan->{$key}
		) {
			$self->{$key} = $minicpan->{$key};
			next;
		}
		$self->{$key} = Portable::FileSpec::catdir(
			$root, split /\//, $minicpan->{$key}
		);
	}

	# Add the literal params
	$self->{remote}         = $minicpan->{remote};
	$self->{quiet}          = $minicpan->{quiet};
	$self->{force}          = $minicpan->{force};
	$self->{offline}        = $minicpan->{offline};
	$self->{also_mirror}    = $minicpan->{also_mirror};
	$self->{module_filters} = $minicpan->{module_filters};
	$self->{path_filters}   = $minicpan->{path_filters};
	$self->{skip_cleanup}   = $minicpan->{skip_cleanup};
	$self->{skip_perl}      = $minicpan->{skip_perl};
	$self->{no_conn_cache}  = $minicpan->{no_conn_cache};

	return $self;
}

1;
