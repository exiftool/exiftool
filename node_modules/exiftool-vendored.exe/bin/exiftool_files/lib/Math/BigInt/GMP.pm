package Math::BigInt::GMP;

use 5.006002;
use strict;
use warnings;

use Math::BigInt::Lib 1.999801;

our @ISA = qw< Math::BigInt::Lib >;

our $VERSION = '1.6007';

use XSLoader;
XSLoader::load "Math::BigInt::GMP", $VERSION;

sub import { }                  # catch and throw away
sub api_version() { 2; }

###############################################################################
# Routines not present here are in GMP.xs or inherited from the parent class.

###############################################################################
# routine to test internal state for corruptions

sub _check {
    my ($class, $x) = @_;
    return "Undefined" unless defined $x;
    return "$x is not a reference to Math::BigInt::GMP"
      unless ref($x) eq 'Math::BigInt::GMP';
    return 0;
}

sub STORABLE_freeze {
    my ($self, $cloning) = @_;
    return Math::BigInt::GMP->_str($self);
}

sub STORABLE_thaw {
    my ($self, $cloning, $serialized) = @_;
    Math::BigInt::GMP->_new_attach($self, $serialized);
    return $self;
}

1;

__END__

#line 162
