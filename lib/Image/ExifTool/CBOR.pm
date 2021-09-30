#------------------------------------------------------------------------------
# File:         CBOR.pm
#
# Description:  Read CBOR format metadata
#
# Revisions:    2021-09-30 - P. Harvey Created
#
# References:   1) https://c2pa.org/public-draft/
#               2) https://datatracker.ietf.org/doc/html/rfc7049
#------------------------------------------------------------------------------

package Image::ExifTool::CBOR;
use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::JSON;

$VERSION = '1.00';

sub ProcessCBOR($$$);
sub ReadCBORValue($$$$);

# optional CBOR type codes
my %cborType6 = (
    0 => 'date/time string',
    1 => 'epoch-based date/time',
    2 => 'positive bignum',
    3 => 'negative bignum',
    4 => 'decimal fraction',
    5 => 'bigfloat',
    21 => 'expected base64url encoding',
    22 => 'expected base64 encoding',
    23 => 'expected base16 encoding',
    24 => 'encoded CBOR data',
    32 => 'URI',
    33 => 'base64url',
    34 => 'base64',
    35 => 'regular expression',
    36 => 'MIME message',
    55799 => 'CBOR magic number',
);

my %cborType7 = (
    20 => 'False',
    21 => 'True',
    22 => 'null',
    23 => 'undef',
);

%Image::ExifTool::CBOR::Main = (
    GROUPS => { 0 => 'JUMBF', 1 => 'CBOR', 2 => 'Other' },
    VARS => { NO_ID => 1 },
    PROCESS_PROC => \&ProcessCBOR,
    NOTES => q{
        The tags below are extracted from CBOR (Concise Binary Object
        Representation) metadata.  The C2PA specification uses this format for some
        metadata.  As well as these tags, ExifTool will read any existing tags.
    },
    'dc:title'      => 'Title',
    'dc:format'     => 'Format',
    # my sample file has the following 2 tags in CBOR, but they should be JSON
    authorName      => { Name => 'AuthorName', Groups => { 2 => 'Author' } },
    authorIdentifier=> { Name => 'AuthorIdentifier', Groups => { 2 => 'Author' } },
    documentID      => { },
    instanceID      => { },
    thumbnailHash   => { List => 1 },
    thumbnailUrl    => { Name => 'ThumbnailURL' },
    relationship    => { }
);

#------------------------------------------------------------------------------
# Read CBOR value
# Inputs: 0) ExifTool ref, 1) data ref, 2) position in data, 3) data end
# Returns: 0) value, 1) error string, 2) new data position
sub ReadCBORValue($$$$)
{
    my ($et, $dataPt, $pos, $end) = @_;
    return(undef, 'Truncated CBOR data', $pos) if $pos >= $end;
    my $verbose = $$et{OPTIONS}{Verbose};
    my $indent = $$et{INDENT};
    my $fmt = Get8u($dataPt, $pos++);
    my $dat = $fmt & 0x1f;
    my ($num, $val, $err, $size);
    $fmt >>= 5;
    if ($dat < 24) {
        $num = $dat;
    } elsif ($dat == 31) {  # indefinite count (not used in C2PA)
        $num = -1;  # (flag for indefinite count)
        $et->VPrint(1, "$$et{INDENT} (indefinite count):\n");
    } else {
        my $format = { 24 => 'int8u', 25 => 'int16u', 26 => 'int32u', 27 => 'int64u' }->{$dat};
        return(undef, "Invalid CBOR integer type $dat", $pos) unless $format;
        $size = Image::ExifTool::FormatSize($format);
        return(undef, 'Truncated CBOR integer value', $pos) if $pos + $size > $end;
        $num = ReadValue($dataPt, $pos, $format, 1, $size);
        $pos += $size;
    }
    my ($pre, $opt) = ('', ':');
    if ($verbose and $fmt != 6) {
        if (defined $$et{cbor_pre}) {
            $pre = "$$et{cbor_pre}";
            delete $$et{cbor_pre};
        }
        if (defined $$et{cbor_opt}) {
            $opt = ", $$et{cbor_opt}:";
            delete $$et{cbor_opt};
        }
    }
    if ($fmt == 0) {            # positive integer
        $val = $num;
        $et->VPrint(1, "$$et{INDENT} ${pre}int+$opt $val\n");
    } elsif ($fmt == 1) {       # negative integer
        $val = -1 * $num;
        $et->VPrint(1, "$$et{INDENT} ${pre}int-$opt $val\n");
    } elsif ($fmt == 2 or $fmt == 3) {  # byte/UTF8 string
        return(undef, 'Truncated CBOR string value', $pos) if $pos + $num > $end;
        if ($num < 0) { # (should not happen in C2PA)
            my $string = '';
            $$et{INDENT} .= '   ';
            for (;;) {
                ($val, $err, $pos) = ReadCBORValue($et, $dataPt, $pos, $end);
                return(undef, $err, $pos) if $err;
                last if not defined $val;   # hit the break?
                # (note: strictly we should be checking that this was a string we read)
                $string .= $val;
            }
            $$et{INDENT} = $indent;
            return($string, undef, $pos);   # return concatenated strings
        } else {
            $val = substr($$dataPt, $pos, $num);
        }
        $pos += $num;
        if ($fmt == 2) {
            $et->VPrint(1, "$$et{INDENT} ${pre}byte$opt <binary data ".length($val)." bytes>\n");
            return(\$val, undef, $pos);    # (byte string)
        }
        $et->VPrint(1, "$$et{INDENT} ${pre}text$opt '${val}'\n");
    } elsif ($fmt == 4 or $fmt == 5) {  # list/hash
        if ($fmt == 4) {
            $et->VPrint(1, "$$et{INDENT} ${pre}list$opt <$num elements>\n");
        } else {
            $et->VPrint(1, "$$et{INDENT} ${pre}hash$opt <$num pairs>\n");
            $num *= 2;
        }
        $$et{INDENT} .= '   ';
        my $i = 0;
        my @list;
        while ($num) {
            $$et{cbor_pre} = "$i) ";
            if ($fmt == 4) {
                ++$i;
            } elsif ($num & 0x01) {
                $$et{cbor_pre} = ' ' x length($$et{cbor_pre});
                ++$i;
            }
            ($val, $err, $pos) = ReadCBORValue($et, $dataPt, $pos, $end);
            return(undef, $err, $pos) if $err;
            if (not defined $val) {
                return(undef, 'Unexpected list terminator', $pos) unless $num < 0;
                last;
            }
            push @list, $val;
            --$num;
        }
        $$et{INDENT} = $indent;
        if ($fmt == 5) {
            my ($i, @keys);
            my %hash = ( _ordered_keys_ => \@keys );
            for ($i=0; $i<@list-1; $i+=2) {
                $hash{$list[$i]} = $list[$i+1];
                push @keys, $list[$i];  # save ordered list of keys
            }
            $val = \%hash;
        } else {
            $val = \@list;
        }
    } elsif ($fmt == 6) {       # optional type
        $$et{cbor_opt} = $cborType6{$num} || "<unknown type $num>";
        ($val, $err, $pos) = ReadCBORValue($et, $dataPt, $pos, $end);
    } elsif ($fmt == 7) {       
        if ($dat == 31) {
            undef $val; # "break" = end of indefinite array/hash (not used in C2PA)
        } elsif ($dat < 24) {
            $val = $cborType7{$num};
            $val = "Unknown ($val)" unless defined $val;
        } elsif ($dat == 25) {  # half-precision float
            my $exp = ($num >> 10) & 0x1f;
            my $mant = $num & 0x3ff;
            if ($exp == 0) {
                $val = $mant ** -24;
                $val *= -1 if $num & 0x8000;
            } elsif (exp != 31) {
                $val = ($mant + 1024) ** ($exp - 25);
                $val *= -1 if $num & 0x8000;
            } else {
                $val = $mant == 0 ? '<inf>' : '<nan>';
            }
        } elsif ($dat == 26) {  # float
            $val = GetFloat($dataPt, $pos - $size);
        } elsif ($dat == 27) {  # double
            $val = GetDouble($dataPt, $pos - $size);
        } else {
            return(undef, "Invalid CBOR type 7 variant $num", $pos);
        }
        $et->VPrint(1, "$$et{INDENT} ${pre}typ7$opt ".(defined $val ? $val : '<break>')."\n");
    } else {
        return(undef, "Unknown CBOR format $fmt", $pos);
    }
    return($val, $err, $pos);
}

#------------------------------------------------------------------------------
# Read CBOR box
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessCBOR($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $end = $pos + $$dirInfo{DirLen};
    $et->VerboseDir('CBOR', undef, $$dirInfo{DirLen});
    my ($val, $err, $tag);
    require Image::ExifTool::CBOR;
    while ($pos < $end) {
        ($val, $err, $pos) = ReadCBORValue($et, $dataPt, $pos, $end);
        $err and $et->Warn($err), last;
        ref $val eq 'HASH' or $et->VPrint(1, "$$et{INDENT} CBOR end: Non-hash encountered\n"), last;
        foreach $tag (@{$$val{_ordered_keys_}}) {
            Image::ExifTool::JSON::ProcessTag($et, $tagTablePtr, $tag, $$val{$tag});
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::CBOR - Read CBOR format metadata

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool read Concise
Binary Object Representation (CBOR) formatted metadata, used by the C2PA
specification.

=head1 AUTHOR

Copyright 2003-2021, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://c2pa.org/public-draft/>

=item L<https://datatracker.ietf.org/doc/html/rfc7049>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/CBOR Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

