#------------------------------------------------------------------------------
# File:         Charset.pm
#
# Description:  ExifTool character encoding routines
#
# Revisions:    2009/08/28 - P. Harvey created
#               2010/01/20 - P. Harvey complete re-write
#               2010/07/16 - P. Harvey added UTF-16 support
#------------------------------------------------------------------------------

package Image::ExifTool::Charset;

use strict;
use vars qw($VERSION %csType);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.09';

my %charsetTable;   # character set tables we've loaded

# lookup for converting Unicode to 1-byte character sets
my %unicode2byte = (
  Latin => {    # pre-load Latin (cp1252) for speed
    0x20ac => 0x80,  0x0160 => 0x8a,  0x2013 => 0x96,
    0x201a => 0x82,  0x2039 => 0x8b,  0x2014 => 0x97,
    0x0192 => 0x83,  0x0152 => 0x8c,  0x02dc => 0x98,
    0x201e => 0x84,  0x017d => 0x8e,  0x2122 => 0x99,
    0x2026 => 0x85,  0x2018 => 0x91,  0x0161 => 0x9a,
    0x2020 => 0x86,  0x2019 => 0x92,  0x203a => 0x9b,
    0x2021 => 0x87,  0x201c => 0x93,  0x0153 => 0x9c,
    0x02c6 => 0x88,  0x201d => 0x94,  0x017e => 0x9e,
    0x2030 => 0x89,  0x2022 => 0x95,  0x0178 => 0x9f,
  },
);

# bit flags for all supported character sets
# (this number must be correct because it dictates the decoding algorithm!)
#   0x001 = character set requires a translation module
#   0x002 = inverse conversion not yet supported by Recompose()
#   0x080 = some characters with codepoints in the range 0x00-0x7f are remapped
#   0x100 = 1-byte fixed-width characters
#   0x200 = 2-byte fixed-width characters
#   0x400 = 4-byte fixed-width characters
#   0x800 = 1- and 2-byte variable-width characters, or 1-byte
#           fixed-width characters that map into multiple codepoints
# Note: In its public interface, ExifTool can currently only support type 0x101
#       and lower character sets because strings are only converted if they
#       contain characters above 0x7f and there is no provision for specifying
#       the byte order for input/output values
%csType = (
    UTF8         => 0x100,
    ASCII        => 0x100, # (treated like UTF8)
    Arabic       => 0x101,
    Baltic       => 0x101,
    Cyrillic     => 0x101,
    Greek        => 0x101,
    Hebrew       => 0x101,
    Latin        => 0x101,
    Latin2       => 0x101,
    MacCroatian  => 0x101,
    MacCyrillic  => 0x101,
    MacGreek     => 0x101,
    MacIceland   => 0x101,
    MacLatin2    => 0x101,
    MacRoman     => 0x101,
    MacRomanian  => 0x101,
    MacTurkish   => 0x101,
    Thai         => 0x101,
    Turkish      => 0x101,
    Vietnam      => 0x101,
    MacArabic    => 0x103, # (directional characters not supported)
    PDFDoc       => 0x181,
    Unicode      => 0x200, # (UCS2)
    UCS2         => 0x200,
    UTF16        => 0x200,
    Symbol       => 0x201,
    JIS          => 0x201,
    UCS4         => 0x400,
    MacChineseCN => 0x803,
    MacChineseTW => 0x803,
    MacHebrew    => 0x803, # (directional characters not supported)
    MacKorean    => 0x803,
    MacRSymbol   => 0x803,
    MacThai      => 0x803,
    MacJapanese  => 0x883,
    ShiftJIS     => 0x883,
);

#------------------------------------------------------------------------------
# Load character set module
# Inputs: 0) Module name
# Returns: Reference to lookup hash, or undef on error
sub LoadCharset($)
{
    my $charset = shift;
    my $conv = $charsetTable{$charset};
    unless ($conv) {
        # load translation module
        my $module = "Image::ExifTool::Charset::$charset";
        no strict 'refs';
        if (%$module or eval "require $module") {
            $conv = $charsetTable{$charset} = \%$module;
        }
    }
    return $conv;
}

#------------------------------------------------------------------------------
# Does an array contain valid UTF-16 characters?
# Inputs: 0) array reference to list of UCS-2 values
# Returns: 0=invalid UTF-16, 1=valid UTF-16 with no surrogates, 2=valid UTF-16 with surrogates
sub IsUTF16($)
{
    local $_;
    my $uni = shift;
    my $surrogate;
    foreach (@$uni) {
        my $hiBits = ($_ & 0xfc00);
        if ($hiBits == 0xfc00) {
            # check for invalid values in UTF-16
            return 0 if $_ == 0xffff or $_ == 0xfffe or ($_ >= 0xfdd0 and $_ <= 0xfdef);
        } elsif ($surrogate) {
            return 0 if $hiBits != 0xdc00;
            $surrogate = 0;
        } else {
            return 0 if $hiBits == 0xdc00;
            $surrogate = 1 if $hiBits == 0xd800;
        }
    }
    return 1 if not defined $surrogate;
    return 2 unless $surrogate;
    return 0;
}

#------------------------------------------------------------------------------
# Decompose string with specified encoding into an array of integer code points
# Inputs: 0) ExifTool object ref (or undef), 1) string, 2) character set name,
#         3) optional byte order ('II','MM','Unknown' or undef to use ExifTool ordering)
# Returns: Reference to array of Unicode values
# Notes: Accepts any type of character set
# - byte order only used for fixed-width 2-byte and 4-byte character sets
# - byte order mark observed and then removed with UCS2 and UCS4
# - no warnings are issued if ExifTool object is not provided
sub Decompose($$$;$)
{
    local $_;
    my ($et, $val, $charset) = @_; # ($byteOrder assigned later if required)
    my $type = $csType{$charset};
    my (@uni, $conv);

    if ($type & 0x001) {
        $conv = LoadCharset($charset);
        unless ($conv) {
            # (shouldn't happen)
            $et->Warn("Invalid character set $charset") if $et;
            return \@uni;   # error!
        }
    } elsif ($type == 0x100) {
        # convert ASCII and UTF8 (treat ASCII as UTF8)
        if ($] < 5.006001) {
            # do it ourself
            @uni = Image::ExifTool::UnpackUTF8($val);
        } else {
            # handle warnings from malformed UTF-8
            undef $Image::ExifTool::evalWarning;
            local $SIG{'__WARN__'} = \&Image::ExifTool::SetWarning;
            # (somehow the meaning of "U0" was reversed in Perl 5.10.0!)
            @uni = unpack($] < 5.010000 ? 'U0U*' : 'C0U*', $val);
            # issue warning if we had errors
            if ($Image::ExifTool::evalWarning and $et and not $$et{WarnBadUTF8}) {
                $et->Warn('Malformed UTF-8 character(s)');
                $$et{WarnBadUTF8} = 1;
            }
        }
        return \@uni;       # all done!
    }
    if ($type & 0x100) {        # 1-byte fixed-width characters
        @uni = unpack('C*', $val);
        foreach (@uni) {
            $_ = $$conv{$_} if defined $$conv{$_};
        }
    } elsif ($type & 0x600) {   # 2-byte or 4-byte fixed-width characters
        my $unknown;
        my $byteOrder = $_[3];
        if (not $byteOrder) {
            $byteOrder = GetByteOrder();
        } elsif ($byteOrder eq 'Unknown') {
            $byteOrder = GetByteOrder();
            $unknown = 1;
        }
        my $fmt = $byteOrder eq 'MM' ? 'n*' : 'v*';
        if ($type & 0x400) {    # 4-byte
            $fmt = uc $fmt; # unpack as 'N*' or 'V*'
            # honour BOM if it exists
            $val =~ s/^(\0\0\xfe\xff|\xff\xfe\0\0)// and $fmt = $1 eq "\0\0\xfe\xff" ? 'N*' : 'V*';
            undef $unknown; # (byte order logic applies to 2-byte only)
        } elsif ($val =~ s/^(\xfe\xff|\xff\xfe)//) {
            $fmt = $1 eq "\xfe\xff" ? 'n*' : 'v*';
            undef $unknown;
        }
        # convert from UCS2 or UCS4
        @uni = unpack($fmt, $val);

        if (not $conv) {
            # no translation necessary
            if ($unknown) {
                # check the byte order
                my (%bh, %bl);
                my ($zh, $zl) = (0, 0);
                foreach (@uni) {
                    $bh{$_ >> 8} = 1;
                    $bl{$_ & 0xff} = 1;
                    ++$zh unless $_ & 0xff00;
                    ++$zl unless $_ & 0x00ff;
                }
                # count the number of unique values in the hi and lo bytes
                my ($bh, $bl) = (scalar(keys %bh), scalar(keys %bl));
                # the byte with the greater number of unique values should be
                # the low-order byte, otherwise the byte which is zero more
                # often is likely the high-order byte
                if ($bh > $bl or ($bh == $bl and $zl > $zh)) {
                    # we guessed wrong, so decode using the other byte order
                    $fmt =~ tr/nvNV/vnVN/;
                    @uni = unpack($fmt, $val);
                }
            }
            # handle surrogate pairs of UTF-16
            if ($charset eq 'UTF16') {
                my $i;
                for ($i=0; $i<$#uni; ++$i) {
                    next unless ($uni[$i]   & 0xfc00) == 0xd800 and
                                ($uni[$i+1] & 0xfc00) == 0xdc00;
                    my $cp = 0x10000 + (($uni[$i] & 0x3ff) << 10) + ($uni[$i+1] & 0x3ff);
                    splice(@uni, $i, 2, $cp);
                }
            }
        } elsif ($unknown) {
            # count encoding errors as we do the translation
            my $e1 = 0;
            foreach (@uni) {
                defined $$conv{$_} and $_ = $$conv{$_}, next;
                ++$e1;
            }
            # try the other byte order if we had any errors
            if ($e1) {
                $fmt = $byteOrder eq 'MM' ? 'v*' : 'n*'; #(reversed)
                my @try = unpack($fmt, $val);
                my $e2 = 0;
                foreach (@try) {
                    defined $$conv{$_} and $_ = $$conv{$_}, next;
                    ++$e2;
                }
                # use this byte order if there are fewer errors
                return \@try if $e2 < $e1;
            }
        } else {
            # translate any characters found in the lookup
            foreach (@uni) {
                $_ = $$conv{$_} if defined $$conv{$_};
            }
        }
    } else {                    # variable-width characters
        # unpack into bytes
        my @bytes = unpack('C*', $val);
        while (@bytes) {
            my $ch = shift @bytes;
            my $cv = $$conv{$ch};
            # pass straight through if no translation
            $cv or push(@uni, $ch), next;
            # byte translates into single Unicode character
            ref $cv or push(@uni, $cv), next;
            # byte maps into multiple Unicode characters
            ref $cv eq 'ARRAY' and push(@uni, @$cv), next;
            # handle 2-byte character codes
            $ch = shift @bytes;
            if (defined $ch) {
                if ($$cv{$ch}) {
                    $cv = $$cv{$ch};
                    ref $cv or push(@uni, $cv), next;
                    push @uni, @$cv;        # multiple Unicode characters
                } else {
                    push @uni, ord('?');    # encoding error
                    unshift @bytes, $ch;
                }
            } else {
                push @uni, ord('?');        # encoding error
            }
        }
    }
    return \@uni;
}

#------------------------------------------------------------------------------
# Convert array of code point integers into a string with specified encoding
# Inputs: 0) ExifTool ref (or undef), 1) unicode character array ref,
#         2) character set (note: not all types are supported)
#         3) byte order ('MM' or 'II', multi-byte sets only, defaults to current byte order)
# Returns: converted string (truncated at null character if it exists), empty on error
# Notes: converts elements of input character array to new code points
# - ExifTool ref may be undef provided $charset is defined
sub Recompose($$;$$)
{
    local $_;
    my ($et, $uni, $charset) = @_; # ($byteOrder assigned later if required)
    my ($outVal, $conv, $inv);
    $charset or $charset = $$et{OPTIONS}{Charset};
    my $csType = $csType{$charset};
    if ($csType == 0x100) {     # UTF8 (also treat ASCII as UTF8)
        if ($] >= 5.006001) {
            # let Perl do it
            $outVal = pack('C0U*', @$uni);
        } else {
            # do it ourself
            $outVal = Image::ExifTool::PackUTF8(@$uni);
        }
        $outVal =~ s/\0.*//s;   # truncate at null terminator
        return $outVal;
    }
    # get references to forward and inverse lookup tables
    if ($csType & 0x801) {
        $conv = LoadCharset($charset);
        unless ($conv) {
            $et->Warn("Missing charset $charset") if $et;
            return '';
        }
        $inv = $unicode2byte{$charset};
        # generate inverse lookup if necessary
        unless ($inv) {
            if (not $csType or $csType & 0x802) {
                $et->Warn("Invalid destination charset $charset") if $et;
                return '';
            }
            # prepare table to convert from Unicode to 1-byte characters
            my ($char, %inv);
            foreach $char (keys %$conv) {
                $inv{$$conv{$char}} = $char;
            }
            $inv = $unicode2byte{$charset} = \%inv;
        }
    }
    if ($csType & 0x100) {      # 1-byte fixed-width
        # convert to specified character set
        foreach (@$uni) {
            next if $_ < 0x80;
            $$inv{$_} and $_ = $$inv{$_}, next;
            # our tables omit 1-byte characters with the same values as Unicode,
            # so pass them straight through after making sure there isn't a
            # different character with this byte value
            next if $_ < 0x100 and not $$conv{$_};
            $_ = ord('?');  # set invalid characters to '?'
            if ($et and not $$et{EncodingError}) {
                $et->Warn("Some character(s) could not be encoded in $charset");
                $$et{EncodingError} = 1;
            }
        }
        # repack as an 8-bit string and truncate at null
        $outVal = pack('C*', @$uni);
        $outVal =~ s/\0.*//s;
    } else {                    # 2-byte and 4-byte fixed-width
        # convert if required
        if ($inv) {
            $$inv{$_} and $_ = $$inv{$_} foreach @$uni;
        }
        # generate surrogate pairs of UTF-16
        if ($charset eq 'UTF16') {
            my $i;
            for ($i=0; $i<@$uni; ++$i) {
                next unless $$uni[$i] >= 0x10000 and $$uni[$i] < 0x10ffff;
                my $t = $$uni[$i] - 0x10000;
                my $w1 = 0xd800 + (($t >> 10) & 0x3ff);
                my $w2 = 0xdc00 + ($t & 0x3ff);
                splice(@$uni, $i, 1, $w1, $w2);
                ++$i;   # skip surrogate pair
            }
        }
        # pack as 2- or 4-byte integer in specified byte order
        my $byteOrder = $_[3] || GetByteOrder();
        my $fmt = $byteOrder eq 'MM' ? 'n*' : 'v*';
        $fmt = uc($fmt) if $csType & 0x400;
        $outVal = pack($fmt, @$uni);
    }
    return $outVal;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Charset - ExifTool character encoding routines

=head1 SYNOPSIS

This module is required by Image::ExifTool.

=head1 DESCRIPTION

This module contains routines used by ExifTool to translate special
character sets.  Currently, the following character sets are supported:

  UTF8, UTF16, UCS2, UCS4, Arabic, Baltic, Cyrillic, Greek, Hebrew, JIS,
  Latin, Latin2, MacArabic, MacChineseCN, MacChineseTW, MacCroatian,
  MacCyrillic, MacGreek, MacHebrew, MacIceland, MacJapanese, MacKorean,
  MacLatin2, MacRSymbol, MacRoman, MacRomanian, MacThai, MacTurkish,
  PDFDoc, RSymbol, ShiftJIS, Symbol, Thai, Turkish, Vietnam

However, only some of these character sets are available to the user via
ExifTool options -- the multi-byte character sets are used only internally
when decoding certain types of information.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
