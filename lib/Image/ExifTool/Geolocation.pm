#------------------------------------------------------------------------------
# File:         Geolocation.pm
#
# Description:  Look up geolocation information based on a GPS position
#
# Revisions:    2024-03-03 - P. Harvey Created
#
# References:   https://download.geonames.org/export/
#
# Notes:        Set $Image::ExifTool::Geolocation::databaseFile to override
#               default database file (lib/Image/ExifTool/Geolocation.dat)
#
#               Based on data from geonames.org Creative Commons databases,
#               reformatted as follows in the Geolocation.dat file:
#
#   Header: GeolocationV.VV\tNNNN\n - V.VV=version, NNNN=num city entries
#
#   NNNN City entries:
#       1. int16u[2] - longitude.latitude (converted to 0-64k range)
#       2. int8u - low byte of time zone number
#       3. int8u - 100's=time zone high bit, population: 10's=num zeros, 1's=sig digit
#       4. UTF8 City name, terminated by tab
#       5. 2-character country code
#       6. Region code, terminated by newline
#   End of section marker - "\0\0\0\0\x01"
#   Country entries:
#       1. 2-character country code
#       2. Country name, terminated by newline
#   End of section marker - "\0\0\0\0\x02"
#   Region entries:
#       1. 2-character country code
#       2. Region code, terminated by tab
#       3. Region name, terminated by newline
#   End of section marker - "\0\0\0\0\x03"
#   Time zone entries:
#       1. Time zone name, terminated by newline
#   End of file marker - "\0\0\0\0\0"
#------------------------------------------------------------------------------

package Image::ExifTool::Geolocation;

use strict;
use vars qw($VERSION $databaseFile);

$VERSION = '1.00';

my (@cityLookup, %countryLookup, %adminLookup, @timezoneLookup);

# get path name for database file from lib/Image/ExifTool/Geolocation.dat by default,
# or according to $Image::ExifTool::Geolocation::databaseFile if specified
my $datfile = $databaseFile;
unless ($datfile) {
    $datfile = $INC{'Image/ExifTool/Geolocation.pm'};
    $datfile or $datfile = 'Geolocation.pm', warn("Error getting Geolocation directory\n");
    $datfile =~ s/\.pm$/\.dat/;
}

# open geolocation database and verify header
open DATFILE, "<$datfile" or warn("Error reading $datfile\n"), return 0;
binmode DATFILE;
my $line = <DATFILE>;
unless ($line =~ /^Geolocation(\d+\.\d+)\t(\d+)/) {
    warn("Bad format Geolocation database\n");
    close(DATFILE);
    return 0;
}
my $ncity = $2;

# read city database
for (;;) {
    $line = <DATFILE>;
    last if length($line) == 6 and $line =~ /\0\0\0\0/;
    $line .= <DATFILE> while length($line) < 7;
    chomp $line;
    push @cityLookup, $line;
}
@cityLookup == $ncity or warn("Bad number of entries in Geolocation database\n"), return 0;
# read countries
for (;;) {
    $line = <DATFILE>;
    last if length($line) == 6 and $line =~ /\0\0\0\0/;
    chomp $line;
    $countryLookup{substr($line,0,2)} = substr($line,2);
}
# read regions
for (;;) {
    $line = <DATFILE>;
    last if length($line) == 6 and $line =~ /\0\0\0\0/;
    chomp $line;
    my ($code, $region) = split /\t/, $line;
    $adminLookup{$code} = $region;
}
# read time zones
for (;;) {
    $line = <DATFILE>;
    last if length($line) == 6 and $line =~ /\0\0\0\0/;
    chomp $line;
    push @timezoneLookup, $line;
}
close DATFILE;

#------------------------------------------------------------------------------
# Look up lat/lon in geolocation database
# Inputs: 0) Latitude, 1) longitude, 2) optional min population,
#         3) optional max distance (km)
# Returns: 0) UTF8 city name (or undef if geolocation is unsuccessful),
#          1) UTF8 state, province or region (or undef),
#          2) country code, 3) country name (undef is possible),
#          4) time zone name (empty string possible), 5) approx population,
#          6) approx distance (km), 7) approximate compass bearing (or undef),
#          8/9) approx lat/lon
sub Geolocate($$;$$)
{
    my ($lat, $lon, $pop, $km) = @_;
    my ($minPop, $maxDist2);
    my $earthCirc = 40000;  # earth circumference in km

    if ($pop) {
        # convert population minimum to a 2-digit code
        my $dig = substr($pop, 0, 1);
        my $zer = length($pop) - 1;
        # round up if necessary
        if (length($pop) > 1 and substr($pop, 1, 1) >= 5) {
            ++$dig > 9 and $dig = 1, ++$zer;
        }
        $minPop = $zer.$dig;
    }
    if ($km) {
        # convert max distance to reduced coordinate units
        my $tmp = $km * 2 * 65536 / $earthCirc;
        $maxDist2 = $tmp * $tmp;
    }
    my $cos = cos($lat * 3.14159 / 180); # cosine factor for longitude distances
    # reduce lat/lon to the range 0-65536
    $lat = int(($lat + 90)  / 180 * 65536 + 0.5) & 0xffff;
    $lon = int(($lon + 180) / 360 * 65536 + 0.5) & 0xffff;
    my $coord = pack('n2',$lon,$lat);   # pack for comparison with binary database values
    # binary search to find closest longitude
    my ($n0, $n1) = (0, scalar(@cityLookup)-1);
    while ($n1 - $n0 > 1) {
        my $n = int(($n0 + $n1) / 2);
        if ($coord lt $cityLookup[$n]) {
            $n1 = $n;
        } else {
            $n0 = $n;
        }
    }
    # step backward then forward through database to find nearest city
    my ($minDist2, $minN, @dxy);
    my ($inc, $end, $n) = (-1, -1, $n0+1);
    for (;;) {
        if (($n += $inc) == $end) {
            last if $inc == 1;
            ($inc, $end, $n) = (1, scalar(@cityLookup), $n1);
        }
        my ($x,$y) = unpack('n2', $cityLookup[$n]);
        my ($dy,$dx) = ($y-$lat, $x-$lon);
        $dx += 65536 if $dx < -32768;       # measure the short way around the world
        $dx -= 65536 if $dx > 32768;
        $dx = 2 * $cos * $dx;               # adjust for longitude spacing
        my $dx2 = $dx * $dx;
        my $dist2 = $dy * $dy + $dx2;
        if (defined $minDist2) {
            # searched far enough if longitude alone is further than best distance
            $dx2 > $minDist2 and $n = $end - $inc, next;
        } elsif (defined $maxDist2) {
            $dx2 > $maxDist2 and $n = $end - $inc, next;
            next if $dist2 > $maxDist2;   # ignore if distance is too great
        }
        # ignore if population is below threshold
        next if $minPop and $minPop > unpack('x5C', $cityLookup[$n]) % 100;
        if (not defined $minDist2 or $minDist2 > $dist2) {
            $minDist2 = $dist2;
            @dxy = ($dx, $dy);
            $minN = $n;
        }
    }
    return () unless defined $minN;

    my ($ln,$lt,$tn,$pc) = unpack('n2C2', $cityLookup[$minN]);
    my ($city, $code) = split /\t/, substr($cityLookup[$minN],6);
    my $ctry = substr($code,0,2);
    my $rgn = $adminLookup{$code};
    my $po2 = substr($pc, -1) . (length($pc) > 1 ? '0' x substr($pc, -2, 1) : '');
    $tn += 256 if $pc > 99;
    my $be; # calculate bearing to geolocated city
    if ($dxy[0] or $dxy[1]) {
        $be = atan2($dxy[0],$dxy[1]) * 180 / 3.14159;
        $be += 360 if $be < 0;
        $be = int($be + 0.5);
    }
    $lt = sprintf('%.3f', $lt * 180 / 65536 - 90);
    $ln = sprintf('%.3f', $ln * 360 / 65536 - 180);
    $km = sprintf('%.1f', sqrt($minDist2) * $earthCirc / (2 * 65536));

    return($city,$rgn,$ctry,$countryLookup{$ctry},$timezoneLookup[$tn],$po2,$km,$be,$lt,$ln);
}

__END__

=head1 NAME

Image::ExifTool::Geolocation - Look up geolocation based on GPS position

=head1 SYNOPSIS

This module is used by the Image::ExifTool Geolocation feature.

=head1 DESCRIPTION

This module contains the code to convert GPS coordinates to city, region,
country, time zone, etc.  It uses a database derived from geonames.org,
modified to reduce the size as much as possible.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  Geolocation.dat is based on data
from geonames.org with a Creative Commons license.

=head1 REFERENCES

=over 4

=item L<https://download.geonames.org/export/>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

1; #end
