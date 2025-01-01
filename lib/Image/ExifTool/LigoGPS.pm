#------------------------------------------------------------------------------
# File:         LigoGPS.pm
#
# Description:  Read LIGOGPSINFO timed GPS records
#
# Revisions:    2024-12-30 - P. Harvey Created
#------------------------------------------------------------------------------
package Image::ExifTool::LigoGPS;

use strict;
use vars qw($VERSION);
use Image::ExifTool;

$VERSION = '1.00';

sub ProcessLigoGPS($$$;$);
sub ProcessLigoJSON($$$);
sub OrderCipherDigits($$$;$);

my $knotsToKph = 1.852;     # knots --> km/h

#------------------------------------------------------------------------------
# Clean up cipher variables and print warning if deciphering was unsuccessful
# Inputs: 0) ExifTool ref
sub CleanupCipher($)
{
    my $et = shift;
    if ($$et{LigoCipher} and $$et{LigoCipher}{'next'}) {
        $et->Warn('Not enough GPS points to determine cipher for decoding LIGOGPSINFO');
    }
    delete $$et{LigoCipher};
}

#------------------------------------------------------------------------------
# Un-do LIGOGPS fuzzing
# Inputs: 0) fuzzed latitude, 1) fuzzed longitude, 2) scale factor
# Returns: 0) latitude, 1) longitude
sub UnfuzzLigoGPS($$$)
{
    my ($lat, $lon, $scl) = @_;
    my $lat2 = int($lat / 10) * 10;
    my $lon2 = int($lon / 10) * 10;
    return($lat2 + ($lon - $lon2) * $scl, $lon2 + ($lat - $lat2) * $scl);
}

#------------------------------------------------------------------------------
# Decrypt LIGOGPSINFO record (starting with "####")
# Inputs: 0) encrypted GPS record incuding 8-byte header
# Returns: decrypted record including 4-byte uint32 header, or undef on error
sub DecryptLigoGPS($)
{
    my $str = shift;
    my $num = unpack('x4V',$str);
    return undef if $num < 4;
    $num = 0x84 if $num > 0x84; # (be safe)
    my @in = unpack("x8C$num",$str);
    my @out;
    while (@in) {
        my $b = shift @in;  # get next byte in data
        # upper 3 bits steer the decryption for this round
        my $steeringBits = $b & 0xe0;
        if ($steeringBits >= 0xc0) {
            return undef if @in < 4;    # next 4 bytes are encrypted data
            push @out, (shift(@in) | $b & 0x01) ^ 0x20,
                       (shift(@in) | $b & 0x02) ^ 0x20,
                       (shift(@in) | $b & 0x0c) ^ 0x20,
                        shift(@in) ^ 0x20 | $b & 0x30;
        } elsif ($steeringBits >= 0x40) {
            return undef if @in < 3;    # next 3 bytes are encrypted data
            if ($steeringBits == 0x40) {
                push @out, 0x20,
                           (shift(@in) | $b & 0x01) ^ 0x20,
                           (shift(@in) | $b & 0x06) ^ 0x20,
                           (shift(@in) | $b & 0x18) ^ 0x20;
            } elsif ($steeringBits == 0x60) {
                push @out, (shift(@in) | $b & 0x03) ^ 0x20,
                           0x20,
                           (shift(@in) | $b & 0x04) ^ 0x20,
                           (shift(@in) | $b & 0x18) ^ 0x20;
            } elsif ($steeringBits == 0x80) {
                push @out, (shift(@in) | $b & 0x03) ^ 0x20,
                           (shift(@in) | $b & 0x0c) ^ 0x20,
                           0x20,
                           (shift(@in) | $b & 0x10) ^ 0x20;
            } else {
                push @out, (shift(@in) | $b & 0x01) ^ 0x20,
                           (shift(@in) | $b & 0x06) ^ 0x20,
                           (shift(@in) | $b & 0x18) ^ 0x20,
                           0x20;
            }
        } elsif ($steeringBits == 0x00) {
            return undef if @in < 1;    # next byte is encrypted data
            push @out, shift(@in) | $b & 0x13;
        } else {
            return undef;   # (shouldn't happen)
        }
    }
    return pack 'C*', @out;
}

#------------------------------------------------------------------------------
# Determine correct ordering of enciphered digits (unit digits of seconds)
# Inputs: 0) starting character code, 1) lookup for next character(s) in sequence
#         2) i/o list of ordered characters, 3) hash of used characters
# Returns: true if a consistent ordering was found
# - loops through all possible orders based on $next sequence until a complete
#   cycle is established
# - this complexity is necessary because GPS may skip some seconds
sub OrderCipherDigits($$$;$)
{
    my ($ch, $next, $order, $did) = @_;
    $did or $did = { };
    while ($$next{$ch}) {
        if (@$order < 10) {
            last if $$did{$ch};
        } else {
            # success if we have cycled through all 10 digits and back to the first
            return 1 if @$order == 10 and $ch eq $$order[0];
            last;
        }
        push @$order, $ch;
        $$did{$ch} = 1;
        # continue with next character if there is only one possibility
        @{$$next{$ch}} == 1 and $ch = $$next{$ch}[0], next;
        # otherwise, test all possibilities
        my $n = $#$order;
        foreach (@{$$next{$ch}}) {
            my %did = %$did;  # make a copy of the used-character lookup
            return 1 if OrderCipherDigits($_, $next, $order, \%did);
            $#$order = $n;    # restore order and try next possibility
        }
        last;
    }
    return 0; # failure
}

#------------------------------------------------------------------------------
# Decipher and parse LIGOGPSINFO record (starting with "####")
# Inputs: 0) ExifTool ref, 1) enciphered string, 2) tag table ref
#         3) true if GPS coordinates don't need de-fuzzing
# Returns: true if this looked like an enciphered string
# Notes: handles contained tags, but may defer handling until full cipher is known
sub DecipherLigoGPS($$$;$)
{
    my ($et, $str, $tagTbl, $noFuzz) = @_;

    # (enciphered characters must be in the range 0x30-0x5f ('0' - '_'))
    $str =~ m[^####.{4}([0-_])[0-_]{3}/[0-_]{2}/[0-_]{2} ..([0-_])..([0-_]).([0-_]) ]s or return undef;
    return undef unless $2 eq $3;   # (colons in time string must be the same)

    my $cipherInfo = $$et{LigoCipher};
    unless ($cipherInfo) {
        $cipherInfo = $$et{LigoCipher} = { cache => [ ], 'next' => { } };
        $et->AddCleanup(\&CleanupCipher);
    };
    my $decipher = $$cipherInfo{decipher};
    my $cache = $$cipherInfo{cache};

    # determine the cipher code table based on the advancing 1's digit of seconds
    unless ($decipher) {
        push @$cache, $str;     # cache records until we can decipher them
        my $next = $$cipherInfo{next};
        my ($millennium, $colon, $ch2) = ($1, $2, $4);
        # determine the cipher lookup table
        # (only characters in range 0x30-0x5f are encrypted)
        my $ch1 = $$cipherInfo{ch1};
        $$cipherInfo{ch1} = $ch2;
        return 1 if not defined $ch1 or $ch1 eq $ch2; # ignore duplicate sequential digits
        if ($$next{$ch1}) {
            return 1 if grep /\Q$ch2\E/, @{$$next{$ch1}};   # don't add twice
            push @{$$next{$ch1}}, $ch2;
        } else {
            $$next{$ch1} = [ $ch2 ];
        }
        # must wait until the lookup contains all 10 digits
        return 1 if scalar(keys %$next) < 10;
        my (@order, $two);
        return 1 unless OrderCipherDigits($ch1, $next, \@order);
        # get index of enciphered "2" in ordered array
        $order[$_] eq $millennium and $two = $_, last foreach 0..9;
        defined $two or $et->Warn('Problem deciphering LIGOGPSINFO'), return 1;
        delete $$cipherInfo{'next'};        # all done with 'next' lookup
        my %decipher = ( $colon => ':' );   # (':' is the time separator)
        foreach (0..9) {
            my $ch = $order[($_ + $two - 2 + 10) % 10];
            $decipher{$ch} = chr($_ + 0x30);
        }
        # may also know the lat/lon quadrant from the signs of the coordinates
        if ($str =~ / ([0-_])$colon(-?).*? ([0-_])$colon(-?)/) {
            @decipher{$1,$3} = ($2 ? 'S' : 'N', $4 ? 'W' : 'E');
            unless ($2 or $4) {
                my ($ns, $ew) = ($1, $3);
                if ($$et{OPTIONS}{GPSQuadrant} and $$et{OPTIONS}{GPSQuadrant} =~ /^([NS])([EW])$/i) {
                    @decipher{$ns,$ew} = (uc($1), uc($2));
                } else {
                    $et->Warn('May need to set API GPSQuadrant option (eg. "NW")');
                }
            }
        }
        # fill in unknown entries with '?' (only chars 0x30-0x5f are enciphered)
        defined $decipher{$_} or $decipher{$_} = '?' foreach map(chr, 0x30..0x5f);
        $decipher = $$cipherInfo{decipher} = \%decipher;
        $str = shift @$cache;   # start deciphering at oldest cache entry
    }

    # apply reverse cipher and extract GPS information
    do {
        my $pre = substr($str, 4, 4);        # save second 4 bytes of header
        ($str = substr($str,8)) =~ s/\0+$//; # remove 8-byte header and null padding
        $str =~ s/([0-_])/$$decipher{$1}/g;  # decipher
        if ($$et{OPTIONS}{Verbose} > 1) {
            $et->VPrint(1, "$$et{INDENT}\(Deciphered: ".unpack('H8',$pre)." $str)\n");
        }
        # add back leading 4 bytes (int16u counter plus 2 unknown bytes), and parse
        ParseLigoGPS($et, "$pre$str", $tagTbl, $noFuzz);
    } while $str = shift @$cache;

    return 1;
}

#------------------------------------------------------------------------------
# Parse decrypted/deciphered (but not defuzzed) LIGOGPSINFO record
# (record starts with 4-byte int32u counter followed by date/time, etc)
# Inputs: 0) ExifTool ref, 1) GPS string, 2) tag table ref, 3) not fuzzed
# Returns: nothing
sub ParseLigoGPS($$$;$)
{
    my ($et, $str, $tagTbl, $noFuzz) = @_;

    # example string input
    # "....2022/09/19 12:45:24 N:31.285065 W:124.759483 46.93 km/h x:-0.000 y:-0.000 z:-0.000"
    unless ($str=~ /^.{4}(\S+ \S+)\s+([NS?]):(-?)([.\d]+)\s+([EW?]):(-?)([\.\d]+)\s+([.\d]+)/s) {
        $et->Warn('LIGOGPSINFO format error');
        return;
    }
    my ($time,$latRef,$latNeg,$lat,$lonRef,$lonNeg,$lon,$spd) = ($1,$2,$3,$4,$5,$6,$7,$8);
    my %gpsScl = ( 1 => 1.524855137, 2 => 1.456027985, 3 => 1.15368 );
    my $spdScl = $noFuzz ? $knotsToKph : 1.85407333;
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $time =~ tr(/)(:);
    # convert from DDMM.MMMMMM to DD.DDDDDD if necessary
    # (speed wasn't scaled in my 1 sample with this format)
    $lat =~ /^\d{3}/ and Image::ExifTool::QuickTime::ConvertLatLon($lat,$lon), $spdScl = 1;
    unless ($noFuzz) { # unfuzz the coordinates if necessary
        my $scl = $$et{OPTIONS}{LigoGPSScale} || $$et{LigoGPSScale} || 1;
        $scl = $gpsScl{$scl} if $gpsScl{$scl};
        ($lat, $lon) = UnfuzzLigoGPS($lat, $lon, $scl);
    }
    # a final sanity check
    ($lat > 90 or $lon > 180) and $et->Warn('LIGOGPSINFO coordinates out of range'), return;
    $$et{SET_GROUP1} = 'LIGO';
    $et->HandleTag($tagTbl, 'GPSDateTime',  $time);
    # (ignore N/S/E/W if coordinate is signed)
    $et->HandleTag($tagTbl, 'GPSLatitude',  $lat * (($latNeg or $latRef eq 'S') ? -1 : 1));
    $et->HandleTag($tagTbl, 'GPSLongitude', $lon * (($lonNeg or $lonRef eq 'W') ? -1 : 1));
    $et->HandleTag($tagTbl, 'GPSSpeed',     $spd * $spdScl);
    $et->HandleTag($tagTbl, 'GPSTrack', $1) if $str =~ /\bA:(\S+)/;
    # (have a sample where tab is used to separate acc components)
    $et->HandleTag($tagTbl, 'Accelerometer',"$1 $2 $3") if $str =~ /x:(\S+)\sy:(\S+)\sz:(\S+)/;
    $et->HandleTag($tagTbl, 'M', $1) if $str =~ /\bM:(\S+)/;
    $et->HandleTag($tagTbl, 'H', $1) if $str =~ /\bH:(\S+)/;
    delete $$et{SET_GROUP1};
}

#------------------------------------------------------------------------------
# Process LIGOGPSINFO data (non-JSON format)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
#         3) 1=LIGOGPS lat/lon/spd weren't fuzzed
# Returns: 1 on success
sub ProcessLigoGPS($$$;$)
{
    my ($et, $dirInfo, $tagTbl, $noFuzz) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = ($$dirInfo{DirStart} || 0) + 0x14;
    return undef if $pos > length $$dataPt;
    my $cipherInfo = $$et{LigoCipher};
    my $dirName = $$dirInfo{DirName} || 'LigoGPS';
    push @{$$et{PATH}}, $dirName unless $$dirInfo{DirID};
    # not fuzzed if header =~ /LIGOGPSINFO\0\0\0\0[\x01\x14]/ (\x01=BlueSkySeaDV688)
    $noFuzz = 1 if substr($$dataPt, $pos-8, 4) =~ /^\0\0\0[\x01\x14]/;
    $et->VerboseDir($dirName);
    for (; $pos + 0x84 <= length($$dataPt); $pos+=0x84) {
        my $dat = substr($$dataPt, $pos, 0x84);
        $dat =~ /^####/ or next; # (have seen blank records filled with zeros, so keep trying)
        # decipher if we already know the encryption
        $cipherInfo and $$cipherInfo{decipher} and DecipherLigoGPS($et, $dat, $tagTbl, $noFuzz) and next;
        my $str = DecryptLigoGPS($dat);
        defined $str or DecipherLigoGPS($et, $dat, $tagTbl, $noFuzz), next;   # try to decipher
        $et->VPrint(1, "$$et{INDENT}\(Decrypted: ",unpack('V',$str),' ',substr($str,4),")\n") if $$et{OPTIONS}{Verbose} > 1;
        ParseLigoGPS($et, $str, $tagTbl, $noFuzz);
    }
    pop @{$$et{PATH}} unless $$dirInfo{DirID};
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Process LIGOGPSINFO JSON-format GPS (Yada RoadCam Pro 4K BT58189)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Sample data (chained 512-byte records starting like this):
# 0000: 4c 49 47 4f 47 50 53 49 4e 46 4f 20 7b 22 48 6f [LIGOGPSINFO {"Ho]
# 0010: 75 72 22 3a 20 22 32 33 22 2c 20 22 4d 69 6e 75 [ur": "23", "Minu]
# 0020: 74 65 22 3a 20 22 31 30 22 2c 20 22 53 65 63 6f [te": "10", "Seco]
# 0030: 6e 64 22 3a 20 22 32 32 22 2c 20 22 59 65 61 72 [nd": "22", "Year]
# 0040: 22 3a 20 22 32 30 32 33 22 2c 20 22 4d 6f 6e 74 [": "2023", "Mont]
# 0050: 68 22 3a 20 22 31 32 22 2c 20 22 44 61 79 22 3a [h": "12", "Day":]
# 0060: 20 22 32 38 22 2c 20 22 73 74 61 74 75 73 22 3a [ "28", "status":]
sub ProcessLigoJSON($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    require Image::ExifTool::Import;
    $et->VerboseDir('LIGO_JSON', undef, length($$dataPt));
    $$et{SET_GROUP1} = 'LIGO';
    while ($$dataPt =~ /LIGOGPSINFO (\{.*?\})/g) {
        my $json = $1;
        my %dbase;
        Image::ExifTool::Import::ReadJSON(\$json, \%dbase);
        my $info = $dbase{'*'} or next;
        # my sample contains the following JSON fields (in this order):
        # Hour Minute Second Year Month Day (GPS UTC time)
        # status NS EW Latitude Longitude Speed (speed in knots)
        # GsensorX GsensorY GsensorZ (units? - only seen "000" for all)
        # MHour MMinute MSecond MYear MMonth MDay (local dashcam clock time)
        # OLatitude OLongitude (? same values as Latitude/Longitude)
        next unless defined $$info{status} and $$info{status} eq 'A'; # only read if GPS is active
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        my $num = 0;
        defined $$info{$_} and ++$num foreach qw(Year Month Day Hour Minute Second);
        if ($num == 6) {
            # this is the GPS time in UTC
            my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ',@$info{qw{Year Month Day Hour Minute Second}});
            $et->HandleTag($tagTbl, GPSDateTime => $time);
        }
        if ($$info{Latitude} and $$info{Longitude}) {
            my $lat = $$info{Latitude};
            $lat = -$lat if $$info{NS} and $$info{NS} eq 'S';
            my $lon = $$info{Longitude};
            $lon = -$lon if $$info{EW} and $$info{EW} eq 'W';
            $et->HandleTag($tagTbl, GPSLatitude => $lat);
            $et->HandleTag($tagTbl, GPSLongitude => $lon);
        }
        $et->HandleTag($tagTbl, GPSSpeed => $$info{Speed} * $knotsToKph) if defined $$info{Speed};
        if (defined $$info{GsensorX} and defined $$info{GsensorY} and defined $$info{GsensorZ}) {
            # (don't know conversion factor for accel data, so leave it raw for now)
            $et->HandleTag($tagTbl, Accelerometer => "$$info{GsensorX} $$info{GsensorY} $$info{GsensorZ}");
        }
        $num = 0;
        defined $$info{$_} and ++$num foreach qw(MYear MMonth MDay MHour MMinute MSecond);
        if ($num == 6) {
            # this is the dashcam clock time (local time zone)
            my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d',@$info{qw{MYear MMonth MDay MHour MMinute MSecond}});
            $et->HandleTag($tagTbl, DateTimeOriginal => $time);
        }
        if (defined $$info{OLatitude} and defined $$info{OLongitude}) {
            my $lat = $$info{OLatitude};
            $lat = -$lat if $$info{NS} and $$info{NS} eq 'S';
            my $lon = $$info{OLongitude};
            $lon = -$lon if $$info{EW} and $$info{EW} eq 'W';
            $et->HandleTag($tagTbl, GPSLatitude2 => $lat);
            $et->HandleTag($tagTbl, GPSLongitude2 => $lon);
        }
        unless ($et->Options('ExtractEmbedded')) {
            $et->Warn('Use the ExtractEmbedded option to extract all timed GPS',3);
            last;
        }
    }
    delete $$et{DOC_NUM};
    delete $$et{SET_GROUP1};
    return 1;
}

1; #end


__END__

=head1 NAME

Image::ExifTool::LigoGPS - Read LIGOGPSINFO timed GPS records

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module decrypts, deciphers and decodes timed GPS metadata from
LIGOGPSINFO records found in various locations of MP4 and M2TS videos from a
variety of dashcam makes and models.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/QuickTime Stream Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
