package CryptX;

use strict;
use warnings ;
our $VERSION = '0.069';

require XSLoader;
XSLoader::load('CryptX', $VERSION);

use Carp;
my $has_json;

BEGIN {
  if (eval { require Cpanel::JSON::XS }) {
    Cpanel::JSON::XS->import(qw(encode_json decode_json));
    $has_json = 1;
  }
  elsif (eval { require JSON::XS }) {
    JSON::XS->import(qw(encode_json decode_json));
    $has_json = 2;
  }
  elsif (eval { require JSON::PP }) {
    JSON::PP->import(qw(encode_json decode_json));
    $has_json = 3;
  }
  else {
    $has_json = 0;
  }
}

sub _croak {
  die @_ if ref $_[0] || !$_[-1];
  if ($_[-1] =~ /^(.*)( at .+ line .+\n$)/s) {
    pop @_;
    push @_, $1;
  }
  die Carp::shortmess @_;
}

sub _decode_json {
  croak "FATAL: cannot find JSON::PP or JSON::XS or Cpanel::JSON::XS" if !$has_json;
  decode_json(shift);
}

sub _encode_json {
  croak "FATAL: cannot find JSON::PP or JSON::XS or Cpanel::JSON::XS" if !$has_json;
  my $data = shift;
  my $rv = encode_json($data); # non-canonical fallback
  return(eval { Cpanel::JSON::XS->new->canonical->encode($data) } || $rv) if $has_json == 1;
  return(eval { JSON::XS->new->canonical->encode($data)         } || $rv) if $has_json == 2;
  return(eval { JSON::PP->new->canonical->encode($data)         } || $rv) if $has_json == 3;
  return($rv);
}

1;

#line 136
