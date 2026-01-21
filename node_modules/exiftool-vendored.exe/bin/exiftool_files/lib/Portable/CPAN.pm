package Portable::CPAN;

use 5.008;
use strict;
use warnings;
use Portable::FileSpec;

our $VERSION = '1.23';

# Create the enumerations
our %bin  = map { $_ => 1 } qw{
	bzip2 curl ftp gpg gzip lynx
	ncftp ncftpget pager patch
	shell tar unzip wget
};
our %post = map { $_ => 1 } qw{
	make_arg make_install_arg makepl_arg
	mbuild_arg mbuild_install_arg mbuildpl_arg
};
our %file = ( %bin, histfile => 1 );





#####################################################################
# Constructor

sub new {
	my $class  = shift;
	my $parent = shift;
	unless ( Portable::_HASH($parent->portable_cpan) ) {
		die('Missing or invalid cpan key in portable.perl');
	}

	# Create the object
	my $self = bless { }, $class;

	# Map the 
	my $cpan = $parent->portable_cpan;
	my $root = $parent->dist_root;
	foreach my $key ( sort keys %$cpan ) {
		unless (
			defined $cpan->{$key}
			and
			length $cpan->{$key}
			and not
			$post{$key}
		) {
			$self->{$key} = $cpan->{$key};
			next;
		}
                if ($file{$key}) {
                  $self->{$key} = Portable::FileSpec::catfile($root, split /\//, $cpan->{$key});
                }
                else {
                  $self->{$key} = Portable::FileSpec::catdir($root, split /\//, $cpan->{$key});
                }
	}
	my $config = $parent->config;
	foreach my $key ( sort keys %post ) {
		next unless defined $self->{$key};
		$self->{$key} =~ s/\$(\w+)/$config->{$1}/g;
	}

	return $self;
}

sub apply {
	my $self   = shift;
	my $parent = shift;

	# Load the CPAN configuration
	require CPAN::Config;

	# Overwrite the CPAN config entries
	foreach my $key ( sort keys %$self ) {
		$CPAN::Config->{$key} = $self->{$key};
	}

	# Confirm we got all the paths
	my $volume = quotemeta $parent->dist_volume;
	foreach my $key ( sort keys %$CPAN::Config ) {
		next unless defined $CPAN::Config->{$key};
		next if     $CPAN::Config->{$key} =~ /$volume/;
		next unless $CPAN::Config->{$key} =~ /\b[a-z]\:/i;
		next if -e  $CPAN::Config->{$key};
		die "Failed to localize \$CPAN::Config->{$key} ($CPAN::Config->{$key})";
	}

	return 1;
}

1;
