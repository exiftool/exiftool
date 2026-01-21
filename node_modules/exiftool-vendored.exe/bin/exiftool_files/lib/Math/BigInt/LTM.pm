package Math::BigInt::LTM;

use strict;
use warnings;
our $VERSION = '0.069';

use CryptX;
use Carp;

sub CLONE_SKIP { 1 } # prevent cloning

sub api_version() { 2 } # compatible with Math::BigInt v1.83+

sub import { }

### the following functions are implemented in XS
# _1ex()
# _acmp()
# _add()
# _alen()
# _alen()
# _and()
# _as_bytes()
# _copy()
# _dec()
# _div()
# _from_base()
# _from_bin()
# _from_bytes()
# _from_hex()
# _from_oct()
# _gcd()
# _inc()
# _is_even()
# _is_odd()
# _is_one()
# _is_ten()
# _is_two()
# _is_zero()
# _lcm()
# _len()
# _lsft()
# _mod()
# _modinv()
# _modpow()
# _mul()
# _new()
# _one()
# _or()
# _pow()
# _root()
# _rsft()
# _set()
# _sqrt()
# _str()
# _sub()
# _ten()
# _to_base()
# _to_bin()
# _to_bytes()
# _to_hex()
# _to_oct()
# _two()
# _xor()
# _zero()
# _zeros()


### same as overloading in Math::BigInt::Lib
use overload

  # overload key: with_assign

  '+'    => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _add($x, $y);
            },

  '-'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _sub($x, $y);
            },

  '*'    => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _mul($x, $y);
            },

  '/'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _div($x, $y);
            },

  '%'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _mod($x, $y);
            },

  '**'   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _pow($x, $y);
            },

  '<<'   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $class -> _num($_[0]);
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $_[0];
                    $y = ref($_[1]) ? $class -> _num($_[1]) : $_[1];
                }
                return $class -> _blsft($x, $y);
            },

  '>>'   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _brsft($x, $y);
            },

  # overload key: num_comparison

  '<'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) < 0;
            },

  '<='   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) <= 0;
            },

  '>'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) > 0;
            },

  '>='   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) >= 0;
          },

  '=='   => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _acmp($x, $y) == 0;
            },

  '!='   => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _acmp($x, $y) != 0;
            },

  # overload key: 3way_comparison

  '<=>'  => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y);
            },

  # overload key: binary

  '&'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _and($x, $y);
            },

  '|'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _or($x, $y);
            },

  '^'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _xor($x, $y);
            },

  # overload key: func

  'abs'  => sub { $_[0] },

  'sqrt' => sub {
                my $class = ref $_[0];
                return $class -> _sqrt($class -> _copy($_[0]));
            },

  'int'  => sub { $_[0] },

  # overload key: conversion

  'bool' => sub { ref($_[0]) -> _is_zero($_[0]) ? '' : 1; },

  '""'   => sub { ref($_[0]) -> _str($_[0]); },

  '0+'   => sub { ref($_[0]) -> _num($_[0]); },

  '='    => sub { ref($_[0]) -> _copy($_[0]); },

  ;

### same as _check() in Math::BigInt::Lib
sub _check {
    # used by the test suite
    my ($class, $x) = @_;
    return "Input is undefined" unless defined $x;
    return "$x is not a reference" unless ref($x);
    return 0;
}

### same as _digit() in Math::BigInt::Lib
sub _digit {
    my ($class, $x, $n) = @_;
    substr($class ->_str($x), -($n+1), 1);
}

### same as _num() in Math::BigInt::Lib
sub _num {
    my ($class, $x) = @_;
    0 + $class -> _str($x);
}

### PATCHED _fac() from Math::BigInt::Lib
sub _fac {
    # factorial
    my ($class, $x) = @_;

    my $two = $class -> _two();

    if ($class -> _acmp($x, $two) < 0) {
        ###HACK: needed for MBI 1.999715 compatibility
        ###return $class -> _one();
        $class->_set($x, 1); return $x
    }

    my $i = $class -> _copy($x);
    while ($class -> _acmp($i, $two) > 0) {
        $i = $class -> _dec($i);
        $x = $class -> _mul($x, $i);
    }

    return $x;
}

### PATCHED _dfac() from Math::BigInt::Lib
sub _dfac {
    # double factorial
    my ($class, $x) = @_;

    my $two = $class -> _two();

    if ($class -> _acmp($x, $two) < 0) {
        ###HACK: needed for MBI 1.999715 compatibility
        ###return $class -> _one();
        $class->_set($x, 1); return $x
    }

    my $i = $class -> _copy($x);
    while ($class -> _acmp($i, $two) > 0) {
        $i = $class -> _sub($i, $two);
        $x = $class -> _mul($x, $i);
    }

    return $x;
}

### same as _nok() in Math::BigInt::Lib
sub _nok {
    # Return binomial coefficient (n over k).
    my ($class, $n, $k) = @_;

    # If k > n/2, or, equivalently, 2*k > n, compute nok(n, k) as
    # nok(n, n-k), to minimize the number if iterations in the loop.

    {
        my $twok = $class -> _mul($class -> _two(), $class -> _copy($k));
        if ($class -> _acmp($twok, $n) > 0) {
            $k = $class -> _sub($class -> _copy($n), $k);
        }
    }

    # Example:
    #
    # / 7 \       7!       1*2*3*4 * 5*6*7   5 * 6 * 7
    # |   | = --------- =  --------------- = --------- = ((5 * 6) / 2 * 7) / 3
    # \ 3 /   (7-3)! 3!    1*2*3*4 * 1*2*3   1 * 2 * 3
    #
    # Equivalently, _nok(11, 5) is computed as
    #
    # (((((((7 * 8) / 2) * 9) / 3) * 10) / 4) * 11) / 5

    if ($class -> _is_zero($k)) {
        return $class -> _one();
    }

    # Make a copy of the original n, in case the subclass modifies n in-place.

    my $n_orig = $class -> _copy($n);

    # n = 5, f = 6, d = 2 (cf. example above)

    $n = $class -> _sub($n, $k);
    $n = $class -> _inc($n);

    my $f = $class -> _copy($n);
    $f = $class -> _inc($f);

    my $d = $class -> _two();

    # while f <= n (the original n, that is) ...

    while ($class -> _acmp($f, $n_orig) <= 0) {
        $n = $class -> _mul($n, $f);
        $n = $class -> _div($n, $d);
        $f = $class -> _inc($f);
        $d = $class -> _inc($d);
    }

    return $n;
}

### same as _log_int() in Math::BigInt::Lib
sub _log_int {
    # calculate integer log of $x to base $base
    # ref to array, ref to array - return ref to array
    my ($class, $x, $base) = @_;

    # X == 0 => NaN
    return if $class -> _is_zero($x);

    $base = $class -> _new(2)     unless defined($base);
    $base = $class -> _new($base) unless ref($base);

    # BASE 0 or 1 => NaN
    return if $class -> _is_zero($base) || $class -> _is_one($base);

    # X == 1 => 0 (is exact)
    if ($class -> _is_one($x)) {
        return $class -> _zero(), 1;
    }

    my $cmp = $class -> _acmp($x, $base);

    # X == BASE => 1 (is exact)
    if ($cmp == 0) {
        return $class -> _one(), 1;
    }

    # 1 < X < BASE => 0 (is truncated)
    if ($cmp < 0) {
        return $class -> _zero(), 0;
    }

    my $y;

    # log(x) / log(b) = log(xm * 10^xe) / log(bm * 10^be)
    #                 = (log(xm) + xe*(log(10))) / (log(bm) + be*log(10))

    {
        my $x_str = $class -> _str($x);
        my $b_str = $class -> _str($base);
        my $xm    = "." . $x_str;
        my $bm    = "." . $b_str;
        my $xe    = length($x_str);
        my $be    = length($b_str);
        my $log10 = log(10);
        my $guess = int((log($xm) + $xe * $log10) / (log($bm) + $be * $log10));
        $y = $class -> _new($guess);
    }

    my $trial = $class -> _pow($class -> _copy($base), $y);
    my $acmp  = $class -> _acmp($trial, $x);

    # Did we get the exact result?

    return $y, 1 if $acmp == 0;

    # Too small?

    while ($acmp < 0) {
        $trial = $class -> _mul($trial, $base);
        $y     = $class -> _inc($y);
        $acmp  = $class -> _acmp($trial, $x);
    }

    # Too big?

    while ($acmp > 0) {
        $trial = $class -> _div($trial, $base);
        $y     = $class -> _dec($y);
        $acmp  = $class -> _acmp($trial, $x);
    }

    return $y, 1 if $acmp == 0;         # result is exact
    return $y, 0;                       # result is too small
}

### same as _lucas() in Math::BigInt::Lib
sub _lucas {
    my ($class, $n) = @_;

    $n = $class -> _num($n) if ref $n;

    # In list context, use lucas(n) = lucas(n-1) + lucas(n-2)

    if (wantarray) {
        my @y;

        push @y, $class -> _two();
        return @y if $n == 0;

        push @y, $class -> _one();
        return @y if $n == 1;

        for (my $i = 2 ; $i <= $n ; ++ $i) {
            $y[$i] = $class -> _add($class -> _copy($y[$i - 1]), $y[$i - 2]);
        }

        return @y;
    }

    require Scalar::Util;

    # In scalar context use that lucas(n) = fib(n-1) + fib(n+1).
    #
    # Remember that _fib() behaves differently in scalar context and list
    # context, so we must add scalar() to get the desired behaviour.

    return $class -> _two() if $n == 0;

    return $class -> _add(scalar $class -> _fib($n - 1),
                          scalar $class -> _fib($n + 1));
}

### same as _fib() in Math::BigInt::Lib
sub _fib {
    my ($class, $n) = @_;

    $n = $class -> _num($n) if ref $n;

    # In list context, use fib(n) = fib(n-1) + fib(n-2)

    if (wantarray) {
        my @y;

        push @y, $class -> _zero();
        return @y if $n == 0;

        push @y, $class -> _one();
        return @y if $n == 1;

        for (my $i = 2 ; $i <= $n ; ++ $i) {
            $y[$i] = $class -> _add($class -> _copy($y[$i - 1]), $y[$i - 2]);
        }

        return @y;
    }

    # In scalar context use a fast algorithm that is much faster than the
    # recursive algorith used in list context.

    my $cache = {};
    my $two = $class -> _two();
    my $fib;

    $fib = sub {
        my $n = shift;
        return $class -> _zero() if $n <= 0;
        return $class -> _one()  if $n <= 2;
        return $cache -> {$n}    if exists $cache -> {$n};

        my $k = int($n / 2);
        my $a = $fib -> ($k + 1);
        my $b = $fib -> ($k);
        my $y;

        if ($n % 2 == 1) {
            # a*a + b*b
            $y = $class -> _add($class -> _mul($class -> _copy($a), $a),
                                $class -> _mul($class -> _copy($b), $b));
        } else {
            # (2*a - b)*b
            $y = $class -> _mul($class -> _sub($class -> _mul(
                   $class -> _copy($two), $a), $b), $b);
        }

        $cache -> {$n} = $y;
        return $y;
    };

    return $fib -> ($n);
}

### same as _sand() in Math::BigInt::Lib
sub _sand {
    my ($class, $x, $sx, $y, $sy) = @_;

    return ($class -> _zero(), '+')
      if $class -> _is_zero($x) || $class -> _is_zero($y);

    my $sign = $sx eq '-' && $sy eq '-' ? '-' : '+';

    my ($bx, $by);

    if ($sx eq '-') {                   # if x is negative
        # two's complement: inc (dec unsigned value) and flip all "bits" in $bx
        $bx = $class -> _copy($x);
        $bx = $class -> _dec($bx);
        $bx = $class -> _as_hex($bx);
        $bx =~ s/^-?0x//;
        $bx =~ tr<0123456789abcdef>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    } else {                            # if x is positive
        $bx = $class -> _as_hex($x);    # get binary representation
        $bx =~ s/^-?0x//;
        $bx =~ tr<fedcba9876543210>
                 <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    }

    if ($sy eq '-') {                   # if y is negative
        # two's complement: inc (dec unsigned value) and flip all "bits" in $by
        $by = $class -> _copy($y);
        $by = $class -> _dec($by);
        $by = $class -> _as_hex($by);
        $by =~ s/^-?0x//;
        $by =~ tr<0123456789abcdef>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    } else {
        $by = $class -> _as_hex($y);    # get binary representation
        $by =~ s/^-?0x//;
        $by =~ tr<fedcba9876543210>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    }

    # now we have bit-strings from X and Y, reverse them for padding
    $bx = reverse $bx;
    $by = reverse $by;

    # padd the shorter string
    my $xx = "\x00"; $xx = "\x0f" if $sx eq '-';
    my $yy = "\x00"; $yy = "\x0f" if $sy eq '-';
    my $diff = CORE::length($bx) - CORE::length($by);
    if ($diff > 0) {
        # if $yy eq "\x00", we can cut $bx, otherwise we need to padd $by
        $by .= $yy x $diff;
    } elsif ($diff < 0) {
        # if $xx eq "\x00", we can cut $by, otherwise we need to padd $bx
        $bx .= $xx x abs($diff);
    }

    # and the strings together
    my $r = $bx & $by;

    # and reverse the result again
    $bx = reverse $r;

    # One of $bx or $by was negative, so need to flip bits in the result. In both
    # cases (one or two of them negative, or both positive) we need to get the
    # characters back.
    if ($sign eq '-') {
        $bx =~ tr<\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>
                 <0123456789abcdef>;
    } else {
        $bx =~ tr<\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>
                 <fedcba9876543210>;
    }

    # leading zeros will be stripped by _from_hex()
    $bx = '0x' . $bx;
    $bx = $class -> _from_hex($bx);

    $bx = $class -> _inc($bx) if $sign eq '-';

    # avoid negative zero
    $sign = '+' if $class -> _is_zero($bx);

    return $bx, $sign;
}

### same as _sxor() in Math::BigInt::Lib
sub _sxor {
    my ($class, $x, $sx, $y, $sy) = @_;

    return ($class -> _zero(), '+')
      if $class -> _is_zero($x) && $class -> _is_zero($y);

    my $sign = $sx ne $sy ? '-' : '+';

    my ($bx, $by);

    if ($sx eq '-') {                   # if x is negative
        # two's complement: inc (dec unsigned value) and flip all "bits" in $bx
        $bx = $class -> _copy($x);
        $bx = $class -> _dec($bx);
        $bx = $class -> _as_hex($bx);
        $bx =~ s/^-?0x//;
        $bx =~ tr<0123456789abcdef>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    } else {                            # if x is positive
        $bx = $class -> _as_hex($x);    # get binary representation
        $bx =~ s/^-?0x//;
        $bx =~ tr<fedcba9876543210>
                 <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    }

    if ($sy eq '-') {                   # if y is negative
        # two's complement: inc (dec unsigned value) and flip all "bits" in $by
        $by = $class -> _copy($y);
        $by = $class -> _dec($by);
        $by = $class -> _as_hex($by);
        $by =~ s/^-?0x//;
        $by =~ tr<0123456789abcdef>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    } else {
        $by = $class -> _as_hex($y);    # get binary representation
        $by =~ s/^-?0x//;
        $by =~ tr<fedcba9876543210>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    }

    # now we have bit-strings from X and Y, reverse them for padding
    $bx = reverse $bx;
    $by = reverse $by;

    # padd the shorter string
    my $xx = "\x00"; $xx = "\x0f" if $sx eq '-';
    my $yy = "\x00"; $yy = "\x0f" if $sy eq '-';
    my $diff = CORE::length($bx) - CORE::length($by);
    if ($diff > 0) {
        # if $yy eq "\x00", we can cut $bx, otherwise we need to padd $by
        $by .= $yy x $diff;
    } elsif ($diff < 0) {
        # if $xx eq "\x00", we can cut $by, otherwise we need to padd $bx
        $bx .= $xx x abs($diff);
    }

    # xor the strings together
    my $r = $bx ^ $by;

    # and reverse the result again
    $bx = reverse $r;

    # One of $bx or $by was negative, so need to flip bits in the result. In both
    # cases (one or two of them negative, or both positive) we need to get the
    # characters back.
    if ($sign eq '-') {
        $bx =~ tr<\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>
                 <0123456789abcdef>;
    } else {
        $bx =~ tr<\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>
                 <fedcba9876543210>;
    }

    # leading zeros will be stripped by _from_hex()
    $bx = '0x' . $bx;
    $bx = $class -> _from_hex($bx);

    $bx = $class -> _inc($bx) if $sign eq '-';

    # avoid negative zero
    $sign = '+' if $class -> _is_zero($bx);

    return $bx, $sign;
}

### same as _sor() in Math::BigInt::Lib
sub _sor {
    my ($class, $x, $sx, $y, $sy) = @_;

    return ($class -> _zero(), '+')
      if $class -> _is_zero($x) && $class -> _is_zero($y);

    my $sign = $sx eq '-' || $sy eq '-' ? '-' : '+';

    my ($bx, $by);

    if ($sx eq '-') {                   # if x is negative
        # two's complement: inc (dec unsigned value) and flip all "bits" in $bx
        $bx = $class -> _copy($x);
        $bx = $class -> _dec($bx);
        $bx = $class -> _as_hex($bx);
        $bx =~ s/^-?0x//;
        $bx =~ tr<0123456789abcdef>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    } else {                            # if x is positive
        $bx = $class -> _as_hex($x);     # get binary representation
        $bx =~ s/^-?0x//;
        $bx =~ tr<fedcba9876543210>
                 <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    }

    if ($sy eq '-') {                   # if y is negative
        # two's complement: inc (dec unsigned value) and flip all "bits" in $by
        $by = $class -> _copy($y);
        $by = $class -> _dec($by);
        $by = $class -> _as_hex($by);
        $by =~ s/^-?0x//;
        $by =~ tr<0123456789abcdef>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    } else {
        $by = $class -> _as_hex($y);     # get binary representation
        $by =~ s/^-?0x//;
        $by =~ tr<fedcba9876543210>
                <\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>;
    }

    # now we have bit-strings from X and Y, reverse them for padding
    $bx = reverse $bx;
    $by = reverse $by;

    # padd the shorter string
    my $xx = "\x00"; $xx = "\x0f" if $sx eq '-';
    my $yy = "\x00"; $yy = "\x0f" if $sy eq '-';
    my $diff = CORE::length($bx) - CORE::length($by);
    if ($diff > 0) {
        # if $yy eq "\x00", we can cut $bx, otherwise we need to padd $by
        $by .= $yy x $diff;
    } elsif ($diff < 0) {
        # if $xx eq "\x00", we can cut $by, otherwise we need to padd $bx
        $bx .= $xx x abs($diff);
    }

    # or the strings together
    my $r = $bx | $by;

    # and reverse the result again
    $bx = reverse $r;

    # One of $bx or $by was negative, so need to flip bits in the result. In both
    # cases (one or two of them negative, or both positive) we need to get the
    # characters back.
    if ($sign eq '-') {
        $bx =~ tr<\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>
                 <0123456789abcdef>;
    } else {
        $bx =~ tr<\x0f\x0e\x0d\x0c\x0b\x0a\x09\x08\x07\x06\x05\x04\x03\x02\x01\x00>
                 <fedcba9876543210>;
    }

    # leading zeros will be stripped by _from_hex()
    $bx = '0x' . $bx;
    $bx = $class -> _from_hex($bx);

    $bx = $class -> _inc($bx) if $sign eq '-';

    # avoid negative zero
    $sign = '+' if $class -> _is_zero($bx);

    return $bx, $sign;
}

### same as _as_bin() in Math::BigInt::Lib
sub _as_bin {
    # convert the number to a string of binary digits with prefix
    my ($class, $x) = @_;
    return '0b' . $class -> _to_bin($x);
}

### same as _as_oct() in Math::BigInt::Lib
sub _as_oct {
    # convert the number to a string of octal digits with prefix
    my ($class, $x) = @_;
    return '0' . $class -> _to_oct($x);         # yes, 0 becomes "00"
}

### same as _as_hex() in Math::BigInt::Lib
sub _as_hex {
    # convert the number to a string of hexadecimal digits with prefix
    my ($class, $x) = @_;
    return '0x' . $class -> _to_hex($x);
}

1;

#line 909
