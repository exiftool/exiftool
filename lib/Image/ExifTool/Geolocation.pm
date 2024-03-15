#------------------------------------------------------------------------------
# File:         Geolocation.pm
#
# Description:  Look up geolocation information based on a GPS position
#
# Revisions:    2024-03-03 - P. Harvey Created
#
# References:   https://download.geonames.org/export/
#
# Notes:        Set $Image::ExifTool::Geolocation::geoDir to override
#               default directory for the database file Geolocation.dat
#               and language directory GeoLang.
#
#               Based on data from geonames.org Creative Commons databases,
#               reformatted as follows in the Geolocation.dat file:
#
#   Header: 
#       "GeolocationV.VV\tNNNN\n"  (V.VV=version, NNNN=num city entries)
#       "# <comment>\n"
#   NNNN City entries:
#     Offset Format   Description
#        0   int16u - longitude high 16 bits (converted to 0-0x100000 range)
#        2   int8u  - longitude low 4 bits, latitude low 4 bits
#        3   int16u - latitude high 16 bits
#        5   int8u  - index of country in country list
#        6   int8u  - 0xf0 = population E exponent (in format "N.Fe+0E"), 0x0f = population N digit
#        7   int16u - 0xf000 = population F digit, 0x0fff = index in region list (admin1)
#        9   int16u - 0x7fff = index in subregion (admin2), 0x8000 = high bit of time zone
#       11   int8u  - low byte of time zone index
#       12   string - UTF8 City name, terminated by newline
#   "\0\0\0\0\x01"
#   Country entries:
#       1. 2-character country code
#       2. Country name, terminated by newline
#   "\0\0\0\0\x02"
#   Region entries:
#       1. Region name, terminated by newline
#   "\0\0\0\0\x03"
#   Subregion entries:
#       1. Subregion name, terminated by newline
#   "\0\0\0\0\x04"
#   Time zone entries:
#       1. Time zone name, terminated by newline
#   "\0\0\0\0\0"
#------------------------------------------------------------------------------

package Image::ExifTool::Geolocation;

use strict;
use vars qw($VERSION $geoDir $dbInfo);

$VERSION = '1.01';

my $databaseVersion = '1.01';

sub ReadDatabase($);
sub SortDatabase($);
sub AddEntry(@);
sub GetEntry($;$);
sub Geolocate($;$$$$);

my (@cityList, @countryList, @regionList, @subregionList, @timezoneList);
my (%countryNum, %regionNum, %subregionNum, %timezoneNum, %langLookup);
my $sortedBy = 'Longitude';

# get path name for database file from lib/Image/ExifTool/Geolocation.dat by default,
# or according to $Image::ExifTool::Geolocation::directory if specified
my $defaultDir = $INC{'Image/ExifTool/Geolocation.pm'};
if ($defaultDir) {
    $defaultDir =~ s(/Geolocation\.pm$)();
} else {
    $defaultDir = '.';
    warn("Error getting Geolocation.pm directory\n");
}

# read the Geolocation database unless $geoDir set to empty string
unless (defined $geoDir and not $geoDir) {
    unless ($geoDir and ReadDatabase("$geoDir/Geolocation.dat")) {
        ReadDatabase("$defaultDir/Geolocation.dat");
    }
}

# set directory for language files
my $geoLang;
if ($geoDir and -d "$geoDir/GeoLang") {
    $geoLang = "$geoDir/GeoLang";
} elsif ($geoDir or not defined $geoDir) {
    $geoLang = "$defaultDir/GeoLang";
}

# add user-defined entries to the database
if (@Image::ExifTool::UserDefined::Geolocation) {
    AddEntry(@$_) foreach @Image::ExifTool::UserDefined::Geolocation;
}

#------------------------------------------------------------------------------
# Read Geolocation database
# Inputs: 0) database file name
# Returns: true on success
sub ReadDatabase($)
{
    my $datfile = shift;
    # open geolocation database and verify header
    open DATFILE, "<$datfile" or warn("Error reading $datfile\n"), return 0;
    binmode DATFILE;
    my $line = <DATFILE>;
    unless ($line =~ /^Geolocation(\d+\.\d+)\t(\d+)/) {
        warn("Bad format Geolocation database\n");
        close(DATFILE);
        return 0;
    }
    if ($1 != $databaseVersion) {
        warn("Wrong Geolocation database version\n");
        close(DATFILE);
        return 0;
    }
    my $ncity = $2;
    my $comment = <DATFILE>;
    defined $comment and $comment =~ /(\d+)/ or close(DATFILE), return 0;
    $dbInfo = "$datfile v$databaseVersion: $ncity cities with population > $1";
    my $isUserDefined = @Image::ExifTool::UserDefined::Geolocation;
    
    # read city database
    undef @cityList;
    for (;;) {
        $line = <DATFILE>;
        last if length($line) == 6 and $line =~ /\0\0\0\0/;
        $line .= <DATFILE> while length($line) < 13;
        chomp $line;
        push @cityList, $line;
    }
    @cityList == $ncity or warn("Bad number of entries in Geolocation database\n"), return 0;
    # read countries
    for (;;) {
        $line = <DATFILE>;
        last if length($line) == 6 and $line =~ /\0\0\0\0/;
        chomp $line;
        push @countryList, $line;
        $countryNum{lc substr($line,0,2)} = $#countryList if $isUserDefined;
    }
    # read regions
    for (;;) {
        $line = <DATFILE>;
        last if length($line) == 6 and $line =~ /\0\0\0\0/;
        chomp $line;
        push @regionList, $line;
        $regionNum{lc $line} = $#regionList if $isUserDefined;
    }
    # read subregions
    for (;;) {
        $line = <DATFILE>;
        last if length($line) == 6 and $line =~ /\0\0\0\0/;
        chomp $line;
        push @subregionList, $line;
        $subregionNum{lc $line} = $#subregionList if $isUserDefined;
    }
    # read time zones
    for (;;) {
        $line = <DATFILE>;
        last if length($line) == 6 and $line =~ /\0\0\0\0/;
        chomp $line;
        push @timezoneList, $line;
        $timezoneNum{lc $line} = $#timezoneList if $isUserDefined;
    }
    close DATFILE;
    return 1;
}

#------------------------------------------------------------------------------
# Sort database by specified field
# Inputs: 0) Field name to sort (Longitude,City,Country)
# Returns: 1 on success
sub SortDatabase($)
{
    my $field = shift;
    if ($field eq $sortedBy) {
        # (already sorted)
    } elsif ($field eq 'Longitude') {
        @cityList = sort { $a cmp $b } @cityList;
    } elsif ($field eq 'City') {
        @cityList = sort { substr($a,12) cmp substr($b,12) } @cityList;
    } elsif ($field eq 'Country') {
        my %lkup;
        foreach (@cityList) {
            my $city = substr($_,12);
            my $ctry = substr($countryList[ord substr($_,5,1)], 2);
            $lkup{$_} = "$ctry $city";
        }
        @cityList = sort { $lkup{$a} cmp $lkup{$b} } @cityList;
    } else {
        return 0;
    }
    $sortedBy = $field;
    return 1;
}

#------------------------------------------------------------------------------
# Add cities to the Geolocation database
# Inputs: 0-8) city,region,subregion,country code,country,timezone,population,lat,lon
# eg. AddEntry('Sinemorets','Burgas','Obshtina Tsarevo','BG','Bulgaria','Europe/Sofia',400,42.06115,27.97833)
sub AddEntry(@)
{
    my ($city, $region, $subregion, $cc, $country, $timezone, $pop, $lat, $lon) = @_;
    if (length($cc) != 2) {
        warn "Country code '${cc}' in UserDefined::Geolocation is not 2 characters\n";
        return;
    }
    @_ < 9 and warn("Too few arguments in $city definition\n"), return;
    chomp $lon; # (just in case it was read from file)
    # create reverse lookups for country/region/subregion/timezone if not done already
    # (eg. if the entries are being added manually instead of via UserDefined::Geolocation)
    unless (%countryNum) {
        my $i;
        $i = 0; $countryNum{lc substr($_,0,2)} = $i++ foreach @countryList;
        $i = 0; $regionNum{lc $_} = $i++ foreach @regionList;
        $i = 0; $subregionNum{lc $_} = $i++ foreach @subregionList;
        $i = 0; $timezoneNum{lc $_} = $i++ foreach @timezoneList;
    }
    my $cn = $countryNum{lc $cc};
    unless (defined $cn) {
        push @countryList, "$cc$country";
        $cn = $countryNum{lc $cc} = $#countryList;
    } elsif ($country) {
        $countryList[$cn] = "$cc$country";  # (override existing country name)
    }
    my $tn = $timezoneNum{lc $timezone};
    unless (defined $tn) {
        push @timezoneList, $timezone;
        $tn = $timezoneNum{lc $timezone} = $#timezoneList;
    }
    my $rn = $regionNum{lc $region};
    unless (defined $rn) {
        push @regionList, $region;
        $rn = $regionNum{lc $region} = $#regionList;
    }
    my $sn = $subregionNum{lc $subregion};
    unless (defined $sn) {
        push @subregionList, $subregion;
        $sn = $subregionNum{lc $subregion} = $#subregionList;
    }
    $pop = sprintf('%.1e',$pop); # format: "3.1e+04" or "3.1e+004"
    # pack CC index, population and region index into a 32-bit integer
    my $code = ($cn << 24) | (substr($pop,-1,1)<<20) | (substr($pop,0,1)<<16) | (substr($pop,2,1)<<12) | $rn;
    # store high bit of timezone index
    $tn > 255 and $sn |= 0x8000, $tn -= 256;
    $lat = int(($lat + 90)  / 180 * 0x100000 + 0.5) & 0xfffff;
    $lon = int(($lon + 180) / 360 * 0x100000 + 0.5) & 0xfffff;
    my $hdr = pack('nCnNnC', $lon>>4, (($lon&0x0f)<<4)|($lat&0x0f), $lat>>4,$code, $sn, $tn);
    push @cityList, "$hdr$city";
    $sortedBy = '';
}

#------------------------------------------------------------------------------
# Unpack entry in database
# Inputs: 0) entry number, 1) optional language code
# Returns: 0-8) city,region,subregion,country code,country,timezone,population,lat,lon
sub GetEntry($;$)
{
    my ($entryNum, $lang) = @_;
    return() if $entryNum > $#cityList;
    my ($ln,$f,$lt,$code,$sb,$tn) = unpack('nCnNnC', $cityList[$entryNum]);
    my $city = substr($cityList[$entryNum],12);
    my $ctry = $countryList[$code >> 24];
    my $rgn = $regionList[$code & 0x0fff];
    my $sub = $subregionList[$sb & 0x7fff];
    # convert population digits back into exponent format
    my $pop = (($code>>16 & 0x0f) . '.' . ($code>>12 & 0x0f) . 'e+' . ($code>>20 & 0x0f)) + 0;
    $tn += 256 if $sb & 0x8000;
    $lt = sprintf('%.4f', (($lt<<4)|($f & 0x0f)) * 180 / 0x100000 - 90);
    $ln = sprintf('%.4f', (($ln<<4)|($f >> 4))   * 360 / 0x100000 - 180);
    my $cc = substr($ctry, 0, 2);
    my $country = substr($ctry, 2);
    if ($lang) {
        my $xlat = $langLookup{$lang};
        # load language lookups if  not done already
        if (not defined $xlat) {
            if (eval "require '$geoLang/$lang.pm'") {
                my $trans = "Image::ExifTool::GeoLang::${lang}::Translate";
                no strict 'refs';
                $xlat = \%$trans if %$trans;
            }
            # read user-defined language translations
            if (%Image::ExifTool::Geolocation::geoLang) {
                my $userLang = $Image::ExifTool::Geolocation::geoLang{$lang};
                if ($userLang and ref($userLang) eq 'HASH') {
                    if ($xlat) {
                        # add user-defined entries to main lookup
                        $$xlat{$_} = $$userLang{$_} foreach keys %$userLang;
                    } else {
                        $xlat = $userLang;
                    }
                }
            }
            $langLookup{$lang} = $xlat || 0;
        }
        if ($xlat) {
            my $r2 = $rgn;
            # City-specific: "CCRgn,Sub,City", "CCRgn,,City", "CC,,City", ",City"
            # Subregion-specific: "CCRgn,Sub,"
            # Region-specific: "CCRgn,"
            # Country-specific: "CC,"
            $city = $$xlat{"$cc$r2,$sub,$city"} || $$xlat{"$cc,,$city"} ||
                    $$xlat{",$city"} || $$xlat{$city} || $city;
            $sub = $$xlat{"$cc$rgn,$sub,"} || $$xlat{$sub} || $sub;
            $rgn = $$xlat{"$cc$rgn,"} || $$xlat{$rgn} || $rgn;
            $country = $$xlat{"$cc,"} || $$xlat{$country} || $country;
        }
    }
    return($city,$rgn,$sub,$cc,$country,$timezoneList[$tn],$pop,$lt,$ln);
}

#------------------------------------------------------------------------------
# Look up lat,lon or city in geolocation database
# Inputs: 0) "lat,lon", "city,region,country", etc, (city must be first)
#         1) optional min population, 2) optional max distance (km)
#         3) optional language code, 4) flag to return multiple cities
# Returns: Reference to list of city information, or list of city information
#          lists if returning multiple cities.
# City information list elements:
#         0) UTF8 city name (or undef if geolocation is unsuccessful),
#         1) UTF8 state, province or region (or empty),
#         2) UTF8 subregion (or empty)
#         3) country code, 4) country name,
#         5) time zone name (empty string possible), 6) approx population,
#         7/8) approx lat/lon (or undef if geolocation is unsuccessful,
#         9) approx distance (km), 10) compass bearing to city,
#         11) non-zero if multiple matches were possible (and city with
#             the largest population is returned)
sub Geolocate($;$$$$)
{
    my ($arg, $pop, $maxDist, $lang, $multi) = @_;
    my ($minPop, $minDist2, $km, $minN, @dxy);
    my $earthCirc = 40000;  # earth circumference in km

    @cityList or warn('No Geolocation database'), return();
    # make population code for comparing with 2 bytes at offset 6 in database
    if ($pop) {
        $pop = sprintf('%.1e', $pop);
        $minPop = chr((substr($pop,-1,1)<<4) | (substr($pop,0,1))) . chr(substr($pop,2,1)<<4);
    }
    $arg =~ s/^\s+//; $arg =~ s/\s+$//; # remove leading/trailing spaces
    unless ($arg =~ /^([-+]?\d+(?:\.\d+)?)\s*,\s*([-+]?\d+(?:\.\d+)?)$/) {
#
# perform reverse Geolocation lookup to determine GPS based on city, country, etc.
#
        my @args = split /\s*,\s*/, $arg;
        my ($city, $i, %found, @exact, %regex, @multiCity, @ciReg, @anyReg, %otherReg, $type );
        my %ri = ( ci => -1, cc => 0, co => 1, re => 2, sr => 3 );
        foreach (@args) {
            # allow regular expressions optionally prefixed by "ci", "cc", "co", "re" or "sr"
            if (m{^(\w{2})?/(.*)/(i?)$}) {
                my $re = $3 ? qr/$2/im : qr/$2/m;
                next if $1 and not defined $ri{$1};
                $1 or push(@anyReg, $re), next;
                $1 eq 'ci' and push(@ciReg, $re), next;
                $otherReg{$ri{$1}} or $otherReg{$ri{$1}} = [ ];
                push @{$otherReg{$1}}, $re;
            } elsif ($city) {
                push @exact, lc $_;
            } else {
                $city = lc $_;
            }
        }
Entry:  for ($i=0; $i<@cityList; ++$i) {
            my $cty = substr($cityList[$i],12);
            next if $city and $city ne lc $cty; # test exact city name first
            $cty =~ $_ or next Entry foreach @ciReg;
            # test other arguments
            my ($cd,$sb) = unpack('x5Nn', $cityList[$i]);
            my $ct = $countryList[$cd >> 24];
            my @geo = (substr($ct,0,2), substr($ct,2), $regionList[$cd & 0x0fff], $subregionList[$sb & 0x7fff]);
            if (@exact) {
                # make quick lookup for all names at this location
                my %geoLkup;
                $_ and $geoLkup{lc $_} = 1 foreach @geo;
                $geoLkup{$_} or next Entry foreach @exact;
            }
            if (%otherReg) {
                foreach $type (keys %otherReg) {
                    $geo[$ri{$type}] =~ /$_/ or next Entry foreach @{$otherReg{$type}};
                }
            }
            if (@anyReg) {
                my $str = join "\n", $cty, @geo;
                $str =~ /$_/ or next Entry foreach @anyReg;
            }
            scalar(keys %found) > 200 and warn("Too many matching cities\n"), return();
            my $pc = substr($cityList[$i],6,2);
            $found{$i} = $pc if not defined $minPop or $pc ge $minPop;
        }
        if (%found) {
            my @f = keys %found;
            @f = sort { $found{$b} cmp $found{$a} or $cityList[$a] cmp $cityList[$b] } @f if @f > 1;
            foreach (@f) {
                my @cityInfo = GetEntry($_, $lang);
                $cityInfo[11] = @f if @f > 1;
                return \@cityInfo unless @f > 1 and $multi;
                push @multiCity, \@cityInfo;
            }
            return \@multiCity;
        }
        warn "No such city in Geolocation database\n";
        return();
    }
#
# determine Geolocation based on GPS coordinates
#
    my ($lat, $lon) = ($1, $2);
    # re-sort if necessary
    SortDatabase('Longitude') unless $sortedBy eq 'Longitude';
    if ($maxDist) {
        # convert max distance to reduced coordinate units
        my $tmp = $maxDist * 2 * 0x100000 / $earthCirc;
        $minDist2 = $tmp * $tmp;
    } else {
        $minDist2 = 0x100000 * 0x100000;
    }
    my $cos = cos($lat * 3.14159 / 180); # cosine factor for longitude distances
    # reduce lat/lon to the range 0-0x100000
    $lat = int(($lat + 90)  / 180 * 0x100000 + 0.5) & 0xfffff;
    $lon = int(($lon + 180) / 360 * 0x100000 + 0.5) & 0xfffff;
    my $coord = pack('nCn',$lon>>4,(($lon&0x0f)<<4)|($lat&0x0f),$lat>>4);;
    # binary search to find closest longitude
    my ($n0, $n1) = (0, scalar(@cityList)-1);
    while ($n1 - $n0 > 1) {
        my $n = int(($n0 + $n1) / 2);
        if ($coord lt $cityList[$n]) {
            $n1 = $n;
        } else {
            $n0 = $n;
        }
    }
    # step backward then forward through database to find nearest city
    my ($inc, $end, $n) = (-1, -1, $n0+1);
    for (;;) {
        if (($n += $inc) == $end) {
            last if $inc == 1;
            ($inc, $end, $n) = (1, scalar(@cityList), $n1);
        }
        my ($x,$f,$y) = unpack('nCn', $cityList[$n]);
        $x = ($x << 4) | ($f >> 4);
        $y = ($y << 4) | ($f & 0x0f);
        my ($dy,$dx) = ($y-$lat, $x-$lon);
        $dx += 0x100000 if $dx < -524288;   # measure the short way around the world
        $dx -= 0x100000 if $dx > 0x80000;
        $dx = 2 * $cos * $dx;           # adjust for longitude spacing
        my $dx2 = $dx * $dx;
        # searched far enough if longitude alone is further than best distance
        $dx2 > $minDist2 and $n = $end - $inc, next;
        my $dist2 = $dx2 + $dy * $dy;
        next if $dist2 > $minDist2;     # skip if distance is too great
        # ignore if population is below threshold
        next if defined $minPop and $minPop ge substr($cityList[$n],6,2);
        $minDist2 = $dist2;
        @dxy = ($dx, $dy);
        $minN = $n;
    }
    defined $minN or warn("No suitable location in Geolocation database\n"), return();

    my $be; # calculate bearing to geolocated city
    if ($dxy[0] or $dxy[1]) {
        $be = atan2($dxy[0],$dxy[1]) * 180 / 3.14159;
        $be += 360 if $be < 0;
        $be = int($be + 0.5);
    }
    $km = sprintf('%.2f', sqrt($minDist2) * $earthCirc / (2 * 0x100000));

    # unpack return values from database entry
    my @cityInfo = GetEntry($minN, $lang);
    @cityInfo[9,10] = ($km, $be);   # add distance and heading
    return \@cityInfo;
}

1; #end

__END__

=head1 NAME

Image::ExifTool::Geolocation - Look up geolocation based on GPS position

=head1 SYNOPSIS

This module is used by the Image::ExifTool Geolocation feature.

=head1 DESCRIPTION

This module contains the code to convert GPS coordinates to city, region,
subregion, country, time zone, etc.  It uses a database derived from
geonames.org, modified to reduce the size as much as possible.

=head1 METHODS

=head2 ReadDatabase

Load Geolocation database from file.  This method is called automatically
when this module is loaded.  By default, the database is loaded from
"Geolocation.dat" in the same directory as this module, but a different
directory may be used by setting $Image::ExifTool::Geolocation::geoDir
before loading this module.  Setting this to an empty string avoids loading
any database.  A warning is generated if the file can't be read.

    Image::ExifTool::Geolocation::ReadDatabase($filename);

=over 4

=item Inputs:

0) Database file name

=item Return Value:

True on success.

=back

=head2 SortDatabase

Sort database in specified order.

    Image::ExifTool::Geolocation::ReadDatabase('City');

=over 4

=item Inputs:

0) Sort order: 'Longitude', 'City' or 'Country'

=item Return Value:

1 on success, 0 on failure (bad sort order specified).

=back

=head2 AddEntry

Add entry to Geolocation database.

    Image::ExifTool::Geolocation::AddEntry($city, $region,
        $countryCode, $country, $timezone, $population, $lat, $lon);

=over 4

=item Inputs:

0) GPS latitude (signed floating point degrees)

1) GPS longitude

2) City name (UTF8)

3) Region, state or province name (UTF8), or empty string if unknown

4) Subregion name (UTF8), or empty string if unknown

5) 2-character ISO 3166 country code

6) Country name (UTF8), or empty string to use existing definition. If the
country name is provided for a country code that already exists in the
database, then the database entry is updated with the new country name.

7) Time zone identifier (eg. "America/New_York")

8) City population

=back

=head2 GetEntry

Get entry from Geolocation database.

    my @vals = Image::ExifTool::Geolocation::GetEntry($num,$lang);

=over 4

=item Inputs:

0) Entry number in database

1) Optional language code

=item Return Values:

0) City name, or undef if the entry didn't exist

1) Region name, or "" if no region

2) Subregion name, or "" if no subregion

3) Country code

4) Country name

5) Time zone

6) City population

7) GPS latitude

8) GPS longitude

=item Notes:

The alternate-language feature of this method (and of L</Geolocate>)
requires the installation of optional GeoLang modules.  See
L<https://exiftool.org/geolocation.html> for more information.

=back

=head2 Geolocate

Return geolocation information for specified GPS coordinates or city name.

    my @cityInfo =
        Image::ExifTool::Geolocation::Geolocate($arg,$pop,$dist,$lang,$multi);

=over 4

=item Inputs:

0) Input argument ("lat,lon", "city", "city,country", "city,region,country",
etc).  When specifying a city, the city name must come first, followed by
zero or more of the following in any order, separated by commas: region
name, subregion name, country code, and/or country name.  Regular
expressions in C</expr/> format are also allowed, optionally prefixed by
"ci", "re", "sr", "cc" or "co" to specifically match City, Region,
Subregion, CountryCode or Country name.  See
L<https://exiftool.org/geolocation.html#Read> for details.

1) Minimum city population (cities smaller than this are ignored)

2) Maximum distance to city (farther cities are not considered)

3) Language code

4) Flag to return multiple cities if there is more than one match.  In this
case the return value is a list of city information lists.

=item Return Value:

Reference to list of information about the matching city.  If multiple
matches were found, the city with the highest population is returned unless
the flag is set to allow multiple cities to be returned, in which case all
cities are turned as a list of city lists in order of decreasing population.

The city information list contains the following entries:

0) Name of matching city (UTF8), or undef if no match

1) Region, state or province name (UTF8), or "" if no region

2) Subregion name (UTF8), or "" if no region

3) Country code

4) Country name (UTF8)

5) Standard time zone identifier name

6) City population rounded to 2 significant figures

7) Approximate city latitude (signed degrees)

8) Approximate city longitude

9) Distance to city in km if "lat,lon" specified

10) Compass bearing for direction to city if "lat,lon" specified

11) Flag set if multiple matches were found

=back

=head1 USING A CUSTOM DATABASE

This example shows how to use a custom database.  In this example, the input
database file is a comma-separated text file with columns corresponding to
the input arguments of the AddEntry method.

    $Image::ExifTool::Geolocation::geoDir = '';
    require Image::ExifTool::Geolocation;
    open DFILE, "<$filename";
    Image::ExifTool::Geolocation::AddEntry(split /,/) foreach <DFILE>;
    close DFILE;

=head1 CUSTOM LANGUAGE TRANSLATIONS

User-defined language translations may be added by defining
%Image::ExifTool::Geolocation::geoLang before calling GetEntry() or
Geolocate().  See L<http://exiftool.org/geolocation.html#Custom> for
details.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  Geolocation.dat is based on data
from geonames.org with a Creative Commons license.

=head1 REFERENCES

=over 4

=item L<https://download.geonames.org/export/>

=item L<https://exiftool.org/geolocation.html>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

1; #end
