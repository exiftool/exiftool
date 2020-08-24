#------------------------------------------------------------------------------
# File:         Shift.pl
#
# Description:  ExifTool time shifting routines
#
# Revisions:    10/28/2005 - P. Harvey Created
#               03/13/2019 - PH Added single-argument form of ShiftTime()
#------------------------------------------------------------------------------

package Image::ExifTool;

use strict;

sub ShiftTime($;$$$);

#------------------------------------------------------------------------------
# apply shift to value in new value hash
# Inputs: 0) ExifTool ref, 1) shift type, 2) shift string, 3) raw date/time value,
#         4) new value hash ref
# Returns: error string or undef on success and updates value in new value hash
sub ApplyShift($$$$;$)
{
    my ($self, $func, $shift, $val, $nvHash) = @_;

    # get shift direction from first character in shift string
    my $pre = ($shift =~ s/^(\+|-)//) ? $1 : '+';
    my $dir = ($pre eq '+') ? 1 : -1;
    my $tagInfo = $$nvHash{TagInfo};
    my $tag = $$tagInfo{Name};
    my $shiftOffset;
    if ($$nvHash{ShiftOffset}) {
        $shiftOffset = $$nvHash{ShiftOffset};
    } else {
        $shiftOffset = $$nvHash{ShiftOffset} = { };
    }

    # initialize handler for eval warnings
    local $SIG{'__WARN__'} = \&SetWarning;
    SetWarning(undef);

    # shift is applied to ValueConv value, so we must ValueConv-Shift-ValueConvInv
    my ($type, $err);
    foreach $type ('ValueConv','Shift','ValueConvInv') {
        if ($type eq 'Shift') {
            #### eval ShiftXxx function
            $err = eval "Shift$func(\$val, \$shift, \$dir, \$shiftOffset)";
        } elsif ($$tagInfo{$type}) {
            my $conv = $$tagInfo{$type};
            if (ref $conv eq 'CODE') {
                $val = &$conv($val, $self);
            } else {
                return "Can't handle $type for $tag in ApplyShift()" if ref $$tagInfo{$type};
                #### eval ValueConv/ValueConvInv ($val, $self)
                $val = eval $$tagInfo{$type};
            }
        } else {
            next;
        }
        # handle errors
        $err and return $err;
        $@ and SetWarning($@);
        GetWarning() and return CleanWarning();
    }
    # update value in new value hash
    $nvHash->{Value} = [ $val ];
    return undef;   # success
}

#------------------------------------------------------------------------------
# Check date/time shift
# Inputs: 0) shift type, 1) shift string (without sign)
# Returns: updated shift string, or undef on error (and may update shift)
sub CheckShift($$)
{
    my ($type, $shift) = @_;
    my $err;
    if ($type eq 'Time') {
        return "No shift direction" unless $shift =~ s/^(\+|-)//;
        # do a test shift to validate the shift string
        my $testTime = '2005:11:02 09:00:13.25-04:00';
        $err = ShiftTime($testTime, $shift, $1 eq '+' ? 1 : -1);
    } else {
        $err = "Unknown shift type ($type)";
    }
    return $err;
}

#------------------------------------------------------------------------------
# return the number of days in a month
# Inputs: 0) month number (Jan=1, may be outside range), 1) year
# Returns: number of days in month
sub DaysInMonth($$)
{
    my ($mon, $year) = @_;
    my @days = (31,28,31,30,31,30,31,31,30,31,30,31);
    # adjust to the range [0,11]
    while ($mon < 1)  { $mon += 12; --$year; }
    while ($mon > 12) { $mon -= 12; ++$year; }
    # return standard number of days unless february on a leap year
    return $days[$mon-1] unless $mon == 2 and not $year % 4;
    # leap years don't occur on even centuries except every 400 years
    return 29 if $year % 100 or not $year % 400;
    return 28;
}

#------------------------------------------------------------------------------
# split times into corresponding components: YYYY mm dd HH MM SS tzh tzm
# Inputs: 0) date/time or shift string 1) reference to list for returned components
#         2) optional reference to list of time components (if shift string)
# Returns: true on success
# Returned components are 0-Y, 1-M, 2-D, 3-hr, 4-min, 5-sec, 6-tzhr, 7-tzmin
sub SplitTime($$;$)
{
    my ($val, $vals, $time) = @_;
    # insert zeros if missing in shift string
    if ($time) {
        $val =~ s/(^|[-+:\s]):/${1}0:/g;
        $val =~ s/:([:\s]|$)/:0$1/g;
    }
    # change dashes to colons in date (for XMP dates)
    if ($val =~ s/^(\d{4})-(\d{2})-(\d{2})/$1:$2:$3/) {
        $val =~ tr/T/ /;    # change 'T' separator to ' '
    }
    # add space before timezone to split it into a separate word
    $val =~ s/(\+|-)/ $1/;
    my @words = split ' ', $val;
    my $err = 1;
    my @v;
    for (;;) {
        my $word = shift @words;
        last unless defined $word;
        # split word into separate numbers (allow decimal points but no signs)
        my @vals = $word =~ /(?=\d|\.\d)\d*(?:\.\d*)?/g or last;
        if ($word =~ /^(\+|-)/) {
            # this is the timezone
            (defined $v[6] or @vals > 2) and $err = 1, last;
            my $sign = ($1 ne '-') ? 1 : -1;
            # apply sign to both minutes and seconds
            $v[6] = $sign * shift(@vals);
            $v[7] = $sign * (shift(@vals) || 0);
        } elsif ((@words and $words[0] =~ /^\d+/) or # there is a time word to follow
            (not $time and $vals[0] =~ /^\d{3}/) or # first value is year (3 or more digits)
            ($time and not defined $$time[3] and not defined $v[0])) # we don't have a time
        {
            # this is a date (must come first)
            (@v or @vals > 3) and $err = 1, last;
            not $time and @vals != 3 and $err = 1, last;
            $v[2] = pop(@vals);     # take day first if only one specified
            $v[1] = pop(@vals) || 0;
            $v[0] = pop(@vals) || 0;
        } else {
            # this is a time (can't come after timezone)
            (defined $v[3] or defined $v[6] or @vals > 3) and $err = 1, last;
            not $time and @vals != 3 and @vals != 2 and $err = 1, last;
            $v[3] = shift(@vals);   # take hour first if only one specified
            $v[4] = shift(@vals) || 0;
            $v[5] = shift(@vals) || 0;
        }
        $err = 0;
    }
    return 0 if $err or not @v;
    if ($time) {
        # zero any required shift entries which aren't yet defined
        $v[0] = $v[1] = $v[2] = 0 if defined $$time[0] and not defined $v[0];
        $v[3] = $v[4] = $v[5] = 0 if defined $$time[3] and not defined $v[3];
        $v[6] = $v[7] = 0 if defined $$time[6] and not defined $v[6];
    }
    @$vals = @v;    # return split time components
    return 1;
}

#------------------------------------------------------------------------------
# shift date/time by components
# Inputs: 0) split date/time list ref, 1) split shift list ref,
#         2) shift direction, 3) reference to output list of shifted components
#         4) number of decimal points in seconds
#         5) reference to return time difference due to rounding
# Returns: error string or undef on success
sub ShiftComponents($$$$$;$)
{
    my ($time, $shift, $dir, $toTime, $dec, $rndPt) = @_;
    # min/max for Y, M, D, h, m, s
    my @min = (    0, 1, 1, 0, 0, 0);
    my @max = (10000,12,28,24,60,60);
    my $i;
#
# apply the shift
#
    my $c = 0;
    for ($i=0; $i<@$time; ++$i) {
        my $v = ($$time[$i] || 0) + $dir * ($$shift[$i] || 0) + $c;
        # handle fractional values by propagating remainders downwards
        if ($v != int($v) and $i < 5) {
            my $iv = int($v);
            $c = ($v - $iv) * $max[$i+1];
            $v = $iv;
        } else {
            $c = 0;
        }
        $$toTime[$i] = $v;
    }
    # round off seconds to the required number of decimal points
    my $sec = $$toTime[5];
    if (defined $sec and $sec != int($sec)) {
        my $mult = 10 ** $dec;
        my $rndSec = int($sec * $mult + 0.5 * ($sec <=> 0)) / $mult;
        $rndPt and $$rndPt = $sec - $rndSec;
        $$toTime[5] = $rndSec;
    }
#
# handle overflows, starting with least significant number first (seconds)
#
    $c = 0;
    for ($i=5; $i>=0; $i--) {
        defined $$time[$i] or $c = 0, next;
        # apply shift and adjust for previous overflow
        my $v = $$toTime[$i] + $c;
        $c = 0; # set carry to zero
        # adjust for over/underflow
        my ($min, $max) = ($min[$i], $max[$i]);
        if ($v < $min) {
            if ($i == 2) {  # 2 = day of month
                do {
                    # add number of days in previous month
                    --$c;
                    my $mon = $$toTime[$i-1] + $c;
                    $v += DaysInMonth($mon, $$toTime[$i-2]);
                } while ($v < 1);
            } else {
                my $fc = ($v - $min) / $max;
                # carry ($c) must be largest integer equal to or less than $fc
                $c = int($fc);
                --$c if $c > $fc;
                $v -= $c * $max;
            }
        } elsif ($v >= $max + $min) {
            if ($i == 2) {
                for (;;) {
                    # test against number of days in current month
                    my $mon = $$toTime[$i-1] + $c;
                    my $days = DaysInMonth($mon, $$toTime[$i-2]);
                    last if $v <= $days;
                    $v -= $days;
                    ++$c;
                    last if $v <= 28;
                }
            } else {
                my $fc = ($v - $max - $min) / $max;
                # carry ($c) must be smallest integer greater than $fc
                $c = int($fc);
                ++$c if $c <= $fc;
                $v -= $c * $max;
            }
        }
        $$toTime[$i] = $v;  # save the new value
    }
    # handle overflows in timezone
    if (defined $$toTime[6]) {
        my $m = $$toTime[6] * 60 + $$toTime[7];
        $m += 0.5 * ($m <=> 0);     # avoid round-off errors
        $$toTime[6] = int($m / 60);
        $$toTime[7] = int($m - $$toTime[6] * 60);
    }
    return undef;   # success
}

#------------------------------------------------------------------------------
# Shift an integer or floating-point number
# Inputs: 0) date/time string, 1) shift string, 2) shift direction (+1 or -1)
#         3) (unused)
# Returns: undef and updates input value
sub ShiftNumber($$$;$)
{
    my ($val, $shift, $dir) = @_;
    $_[0] = $val + $shift * $dir;   # return shifted value
    return undef;                   # success!
}

#------------------------------------------------------------------------------
# Shift date/time string
# Inputs: 0) date/time string, 1) shift string, 2) shift direction (+1 or -1),
#            or 0 or undef to take shift direction from sign of shift,
#         3) reference to ShiftOffset hash (with Date, DateTime, Time, Timezone keys)
#   or    0) shift string (and operates on $_)
# Returns: error string or undef on success and date/time string is updated
sub ShiftTime($;$$$)
{
    my ($val, $shift, $dir, $shiftOffset);
    my (@time, @shift, @toTime, $mode, $needShiftOffset, $dec);

    if (@_ == 1) {      # single argument form of ShiftTime()?
        $val = $_;
        $shift = $_[0];
    } else {
        ($val, $shift, $dir, $shiftOffset) = @_;
    }
    $dir or $dir = ($shift =~ s/^(\+|-)// and $1 eq '-') ? -1 : 1;
#
# figure out what we are dealing with (time, date or date/time)
#
    SplitTime($val, \@time) or return "Invalid time string ($val)";
    if (defined $time[0]) {
        return "Can't shift from year 0000" if $time[0] eq '0000';
        $mode = defined $time[3] ? 'DateTime' : 'Date';
    } elsif (defined $time[3]) {
        $mode = 'Time';
    }
    # get number of digits after the seconds decimal point
    if (defined $time[5] and $time[5] =~ /\.(\d+)/) {
        $dec = length($1);
    } else {
        $dec = 0;
    }
    if ($shiftOffset) {
        $needShiftOffset = 1 unless defined $$shiftOffset{$mode};
        $needShiftOffset = 1 if defined $time[6] and not defined $$shiftOffset{Timezone};
    } else {
        $needShiftOffset = 1;
    }
    if ($needShiftOffset) {
#
# apply date/time shift the hard way
#
        SplitTime($shift, \@shift, \@time) or return "Invalid shift string ($shift)";

        # change 'Z' timezone to '+00:00' only if necessary
        if (@shift > 6 and @time <= 6) {
            $time[6] = $time[7] = 0 if $val =~ s/Z$/\+00:00/;
        }
        my $rndDiff;
        my $err = ShiftComponents(\@time, \@shift, $dir, \@toTime, $dec, \$rndDiff);
        $err and return $err;
#
# calculate and save the shift offsets for next time
#
        if ($shiftOffset) {
            if (defined $time[0] or defined $time[3]) {
                my @tm1 = (0, 0, 0, 1, 0, 2000);
                my @tm2 = (0, 0, 0, 1, 0, 2000);
                if (defined $time[0]) {
                    @tm1[3..5] = reverse @time[0..2];
                    @tm2[3..5] = reverse @toTime[0..2];
                    --$tm1[4]; # month should start from 0
                    --$tm2[4];
                }
                my $diff = 0;
                if (defined $time[3]) {
                    @tm1[0..2] = reverse @time[3..5];
                    @tm2[0..2] = reverse @toTime[3..5];
                    # handle fractional seconds separately
                    $diff = $tm2[0] - int($tm2[0]) - ($tm1[0] - int($tm1[0]));
                    $diff += $rndDiff if defined $rndDiff;  # un-do rounding
                    $tm1[0] = int($tm1[0]);
                    $tm2[0] = int($tm2[0]);
                }
                eval q{
                    require Time::Local;
                    $diff += Time::Local::timegm(@tm2) - Time::Local::timegm(@tm1);
                };
                # not a problem if we failed here since we'll just try again next time,
                # so don't return error message
                unless (@$) {
                    my $mode;
                    if (defined $time[0]) {
                        $mode = defined $time[3] ? 'DateTime' : 'Date';
                    } else {
                        $mode = 'Time';
                    }
                    $$shiftOffset{$mode} = $diff;
                }
            }
            if (defined $time[6]) {
                $$shiftOffset{Timezone} = ($toTime[6] - $time[6]) * 60 +
                                           $toTime[7] - $time[7];
            }
        }

    } else {
#
# apply shift from previously calculated offsets
#
        if ($$shiftOffset{Timezone} and @time <= 6) {
            # change 'Z' timezone to '+00:00' only if necessary
            $time[6] = $time[7] = 0 if $val =~ s/Z$/\+00:00/;
        }
        # apply the previous date/time shift if necessary
        if ($mode) {
            my @tm = (0, 0, 0, 1, 0, 2000);
            if (defined $time[0]) {
                @tm[3..5] = reverse @time[0..2];
                --$tm[4]; # month should start from 0
            }
            @tm[0..2] = reverse @time[3..5] if defined $time[3];
            # save fractional seconds
            my $frac = $tm[0] - int($tm[0]);
            $tm[0] = int($tm[0]);
            my $tm;
            eval q{
                require Time::Local;
                $tm = Time::Local::timegm(@tm) + $frac;
            };
            $@ and return CleanWarning($@);
            $tm += $$shiftOffset{$mode};    # apply the shift
            $tm < 0 and return 'Shift results in negative time';
            # save fractional seconds in shifted time
            $frac = $tm - int($tm);
            if ($frac) {
                $tm = int($tm);
                # must account for any rounding that could occur
                $frac + 0.5 * 10 ** (-$dec) >= 1 and ++$tm, $frac = 0;
            }
            @tm = gmtime($tm);
            @toTime = reverse @tm[0..5];
            $toTime[0] += 1900;
            ++$toTime[1];
            $toTime[5] += $frac;    # add the fractional seconds back in
        }
        # apply the previous timezone shift if necessary
        if (defined $time[6]) {
            my $m = $time[6] * 60 + $time[7];
            $m += $$shiftOffset{Timezone};
            $m += 0.5 * ($m <=> 0);     # avoid round-off errors
            $toTime[6] = int($m / 60);
            $toTime[7] = int($m - $toTime[6] * 60);
        }
    }
#
# insert shifted time components back into original string
#
    my $i;
    for ($i=0; $i<@toTime; ++$i) {
        next unless defined $time[$i] and defined $toTime[$i];
        my ($v, $d, $s);
        if ($i != 6) {  # not timezone hours
            last unless $val =~ /((?=\d|\.\d)\d*(\.\d*)?)/g;
            next if $toTime[$i] == $time[$i];
            $v = $1;    # value
            $d = $2;    # decimal part of value
            $s = '';    # no sign
        } else {
            last if $time[$i] == $toTime[$i] and $time[$i+1] == $toTime[$i+1];
            last unless $val =~ /((?:\+|-)(?=\d|\.\d)\d*(\.\d*)?)/g;
            $v = $1;
            $d = $2;
            if ($toTime[6] >= 0 and $toTime[7] >= 0) {
                $s = '+';
            } else {
                $s = '-';
                $toTime[6] = -$toTime[6];
                $toTime[7] = -$toTime[7];
            }
        }
        my $nv = $toTime[$i];
        my $pos = pos $val;
        my $len = length $v;
        my $sig = $len - length $s;
        my $dec = $d ? length($d) - 1 : 0;
        my $newNum = sprintf($dec ? "$s%0$sig.${dec}f" : "$s%0${sig}d", $nv);
        substr($val, $pos - $len, $len) = $newNum;
        pos($val) = $pos + length($newNum) - $len;
    }
    if (@_ == 1) {
        $_ = $val;      # set $_ to the returned value
    } else {
        $_[0] = $val;   # return shifted value
    }
    return undef;       # success!
}


1; # end

__END__

=head1 NAME

Image::ExifTool::Shift.pl - ExifTool time shifting routines

=head1 DESCRIPTION

This module contains routines used by ExifTool to shift date and time
values.

=head1 METHODS

=head2 ShiftTime

Shift date/time value

    use Image::ExifTool;
    $err = Image::ExifTool::ShiftTime($dateTime, $shift);

=over 4

=item Inputs:

0) Date/time string in EXIF format (eg. C<2016:01:30 11:45:00>).

1) Shift string (see below) with optional leading sign for shift direction.

2) [optional] Direction of shift (-1 or +1), or 0 or undef to use the sign
from the shift string.

3) [optional] Reference to time-shift hash -- filled in by first call to
B<ShiftTime>, and used in subsequent calls to shift date/time values by the
same relative amount (see L</TRICKY> section below).

or

0) Shift string (and $_ contains the input date/time string).

=item Return value:

Error string, or undef on success and the input date/time string is shifted
by the specified amount.

=back

=head1 SHIFT STRING

Time shifts are applied to standard EXIF-formatted date/time values (eg.
C<2005:03:14 18:55:00>).  Date-only and time-only values may also be
shifted, and an optional timezone (eg. C<-05:00>) is also supported.  Here
are some general rules and examples to explain how shift strings are
interpreted:

Date-only values are shifted using the following formats:

    'Y:M:D'     - shift date by 'Y' years, 'M' months and 'D' days
    'M:D'       - shift months and days only
    'D'         - shift specified number of days

Time-only values are shifted using the following formats:

    'h:m:s'     - shift time by 'h' hours, 'm' minutes and 's' seconds
    'h:m'       - shift hours and minutes only
    'h'         - shift specified number of hours

Timezone shifts are specified in the following formats:

    '+h:m'      - shift timezone by 'h' hours and 'm' minutes
    '-h:m'      - negative shift of timezone hours and minutes
    '+h'        - shift timezone hours only
    '-h'        - negative shift of timezone hours only

A valid shift value consists of one or two arguments, separated by a space.
If only one is provided, it is assumed to be a time shift when applied to a
time-only or a date/time value, or a date shift when applied to a date-only
value.  For example:

    '1'         - shift by 1 hour if applied to a time or date/time
                  value, or by one day if applied to a date value
    '2:0'       - shift 2 hours (time, date/time), or 2 months (date)
    '5:0:0'     - shift 5 hours (time, date/time), or 5 years (date)
    '0:0:1'     - shift 1 s (time, date/time), or 1 day (date)

If two arguments are given, the date shift is first, followed by the time
shift:

    '3:0:0 0'         - shift date by 3 years
    '0 15:30'         - shift time by 15 hours and 30 minutes
    '1:0:0 0:0:0+5:0' - shift date by 1 year and timezone by 5 hours

A date shift is simply ignored if applied to a time value or visa versa.

Numbers specified in shift fields may contain a decimal point:

    '1.5'       - 1 hour 30 minutes (time, date/time), or 1 day (date)
    '2.5 0'     - 2 days 12 hours (date/time), 12 hours (time) or
                  2 days (date)

And to save typing, a zero is assumed for any missing numbers:

    '1::'       - shift by 1 hour (time, date/time) or 1 year (date)
    '26:: 0'    - shift date by 26 years
    '+:30'      - shift timezone by 30 minutes

Below are some specific examples applied to real date and/or time values
('Dir' is the applied shift direction: '+' is positive, '-' is negative):

     Original Value         Shift   Dir    Shifted Value
    ---------------------  -------  ---  ---------------------
    '20:30:00'             '5'       +   '01:30:00'
    '2005:01:27'           '5'       +   '2005:02:01'
    '2005:01:27 20:30:00'  '5'       +   '2005:01:28 01:30:00'
    '11:54:00'             '2.5 0'   -   '23:54:00'
    '2005:11:02'           '2.5 0'   -   '2005:10:31'
    '2005:11:02 11:54:00'  '2.5 0'   -   '2005:10:30 23:54:00'
    '2004:02:28 08:00:00'  '1 1.3'   +   '2004:02:29 09:18:00'
    '07:00:00'             '-5'      +   '07:00:00'
    '07:00:00+01:00'       '-5'      +   '07:00:00-04:00'
    '07:00:00Z'            '+2:30'   -   '07:00:00-02:30'
    '1970:01:01'           '35::'    +   '2005:01:01'
    '2005:01:01'           '400'     +   '2006:02:05'
    '10:00:00.00'          '::1.33'  -   '09:59:58.67'

=head1 NOTES

The format of the original date/time value is not changed when the time
shift is applied.  This means that the length of the date/time string will
not change, and only the numbers in the string will be modified.  The only
exception to this rule is that a 'Z' timezone is changed to '+00:00'
notation if a timezone shift is applied.  A timezone will not be added to
the date/time string.

=head1 TRICKY

This module is perhaps more complicated than it needs to be because it is
designed to be very flexible in the way time shifts are specified and
applied...

The ability to shift dates by Y years, M months, etc, conflicts with the
design goal of maintaining a constant shift for all time values when
applying a batch shift.  This is because shifting by 1 month can be
equivalent to anything from 28 to 31 days, and 1 year can be 365 or 366
days, depending on the starting date.

The inconsistency is handled by shifting the first tag found with the actual
specified shift, then calculating the equivalent time difference in seconds
for this shift and applying this difference to subsequent tags in a batch
conversion.  So if it works as designed, the behaviour should be both
intuitive and mathematically correct, and the user shouldn't have to worry
about details such as this (in keeping with Perl's "do the right thing"
philosophy).

=head1 BUGS

Due to the use of the standard time library functions, dates are typically
limited to the range 1970 to 2038 on 32-bit systems.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
