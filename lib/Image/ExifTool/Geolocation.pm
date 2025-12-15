#------------------------------------------------------------------------------
# File:         Geolocation.pm
#
# Description:  Determine geolocation from GPS and visa-versa
#
# Revisions:    2024-03-03 - P. Harvey Created
#               2024-03-21 - PH Significant restructuring and addition of
#                            several new features.
#
# References:   https://download.geonames.org/export/
#
# Notes:        Set $Image::ExifTool::Geolocation::geoDir to override the
#               default directory containing the database file Geolocation.dat
#               and the GeoLang directory with the alternate language files.
#               If set, this directory is
#
#               AltNames.dat may be loaded from a different directory by
#               specifying $Image::ExifTool::Geolocation::altDir.  This
#               database and has entries in the same order as Geolocation.dat,
#               and each entry is a newline-separated list of alternate names
#               terminated by a null byte.  These alternate names are used
#               only when searching for a city by name (eg. "Big Apple").
#
#               Databases are based on data from geonames.org with a
#               Creative Commons license, reformatted as follows in the
#               Geolocation.dat file:
#
#   Header:
#       "GeolocationV.VV\tNNNN\n"  (V.VV=version, NNNN=num city entries)
#       "# <comment>\n"
#   NNNN City entries:
#     Offset Format   Description
#        0   int16u - latitude high 16 bits (converted to 0-0x100000 range)
#        2   int8u  - latitude low 4 bits, longitude low 4 bits
#        3   int16u - longitude high 16 bits
#        5   int8u  - index of country in country list
#        6   int8u  - 0xf0 = population E exponent (in format "N.Fe+0E"), 0x0f = population N digit
#        7   int16u - 0xf000 = population F digit, 0x0fff = index in region list (admin1)
#        9   int16u - v1.02: 0x7fff = index in subregion (admin2), 0x8000 = high bit of time zone
#        9   int16u - v1.03: index in subregion (admin2)
#       11   int8u  - low byte of time zone index
#       12   int8u  - 0x3f = feature code index (see below), v1.03: 0x80 = high bit of time zone
#       13   string - UTF8 City name, terminated by newline
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
#   "\0\0\0\0\x05" (feature codes added in v1.03)
#   Feature codes:
#       1. Feature code, optional space-followed-by-feature-name, then newline
#   "\0\0\0\0\0"
#
# Feature Codes v1.02: (see http://www.geonames.org/export/codes.html#P for descriptions)
#
#       0. Other    3. PPLA2    6. PPLA5    9. PPLF    12. PPLR   15. PPLX
#       1. PPL      4. PPLA3    7. PPLC    10. PPLG    13. PPLS
#       2. PPLA     5. PPLA4    8. PPLCH   11. PPLL    14. STLMT
#------------------------------------------------------------------------------

package Image::ExifTool::Geolocation;

use strict;
use vars qw($VERSION $geoDir $altDir $dbInfo);

$VERSION = '1.10';  # (this is the module version number, not the database version)

my $debug; # set to output processing time for testing

sub ReadDatabase($);
sub SortDatabase($);
sub AddEntry(@);
sub GetEntry($;$$);
sub Geolocate($;$);

my (@cityList, @countryList, @regionList, @subregionList, @timezoneList);
my (%countryNum, %regionNum, %subregionNum, %timezoneNum); # reverse lookups
my (@sortOrder, @altNames, %langLookup, $nCity, %featureCodes, %featureTypes);
my ($lastArgs, %lastFound, @lastByPop, @lastByLat); # cached city matches
my $dbVer = '1.03';         # database version number
my $sortedBy = 'Latitude';
my $pi = 3.1415926536;
my $earthRadius = 6371;     # earth radius in km
# hard-coded feature codes for v1.02 database
my @featureCodes = qw(Other PPL PPLA PPLA2 PPLA3 PPLA4 PPLA5 PPLC
                      PPLCH PPLF PPLG PPLL PPLR PPLS STLMT PPLX);

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

# set directory for language files and alternate names
$geoDir = $defaultDir unless defined $geoDir;
if (not defined $altDir and $geoDir and -e "$geoDir/AltNames.dat") {
    $altDir = $geoDir;
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
    open DATFILE, "< $datfile" or warn("Error reading $datfile\n"), return 0;
    binmode DATFILE;
    my $line = <DATFILE>;
    unless ($line =~ /^Geolocation(\d+\.\d+)\t(\d+)/) {
        warn("Bad format Geolocation database\n");
        close(DATFILE);
        return 0;
    }
    ($dbVer, $nCity) = ($1, $2);
    if ($dbVer !~ /^1\.0[23]$/) {
        my $which = $dbVer < 1.03 ? 'database' : 'ExifTool';
        warn("Incompatible Geolocation database (update your $which)\n");
        close(DATFILE);
        return 0;
    }
    my $comment = <DATFILE>;
    defined $comment and $comment =~ / (\d+) / or close(DATFILE), return 0;
    $dbInfo = "$datfile v$dbVer: $nCity cities with population > $1";
    my $isUserDefined = @Image::ExifTool::UserDefined::Geolocation;

    undef @altNames;    # reset altNames

    # read city database
    undef @cityList;
    my $i = 0;
    for (;;) {
        $line = <DATFILE>;
        last if length($line) == 6 and $line =~ /\0\0\0\0/;
        $line .= <DATFILE> while length($line) < 14;
        chomp $line;
        push @cityList, $line;
    }
    @cityList == $nCity or warn("Bad number of entries in Geolocation database\n"), return 0;
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
    # read feature codes if available
    if ($line eq "\0\0\0\0\x05\n") {
        undef @featureCodes;
        for (;;) {
            $line = <DATFILE>;
            last if length($line) == 6 and $line =~ /\0\0\0\0/;
            chomp $line;
            $featureTypes{$line} = $1 if $line =~ s/ (.*)//;
            push @featureCodes, $line;
        }
    }
    close DATFILE;
    # initialize featureCodes lookup
    $i = 0;
    %featureCodes = map { lc($_) => $i++ } @featureCodes;
    return 1;
}

#------------------------------------------------------------------------------
# Read alternate-names database
# Returns: True on success
# Notes: Must be called after ReadDatabase(). Resets $altDir on exit.
sub ReadAltNames()
{
    my $success;
    if ($altDir and $nCity) {
        if (open ALTFILE, "< $altDir/AltNames.dat") {
            binmode ALTFILE;
            local $/ = "\0";
            my $i = 0;
            while (<ALTFILE>) { chop; $altNames[$i++] = $_; }
            close ALTFILE;
            if ($i == $nCity) {
                $success = 1;
            } else {
                warn("Bad number of entries in AltNames database\n");
                undef @altNames;
            }
        } else {
            warn "Error reading $altDir/AltNames.dat\n";
        }
        undef $altDir;
    }
    return $success;
}

#------------------------------------------------------------------------------
# Clear last city matches cache
sub ClearLastMatches()
{
    undef $lastArgs;    # arguments in last call to Geolocate
    undef %lastFound;   # keys are last matching city numbers, values are population codes
    undef @lastByPop;   # last matching city numbers ordered by population
    undef @lastByLat;   # last matching city numbers ordered by latitude
}

#------------------------------------------------------------------------------
# Sort database by specified field
# Inputs: 0) Field name to sort (Latitude,City,Country)
# Returns: 1 on success
sub SortDatabase($)
{
    my $field = shift;
    return 1 if $field eq $sortedBy;    # already sorted?
    undef @sortOrder;
    if ($field eq 'Latitude') {
        @sortOrder = sort { $cityList[$a] cmp $cityList[$b] } 0..$#cityList;
    } elsif ($field eq 'City') {
        @sortOrder = sort { substr($cityList[$a],13) cmp substr($cityList[$b],13) } 0..$#cityList;
    } elsif ($field eq 'Country') {
        my %lkup;
        foreach (0..$#cityList) {
            my $city = substr($cityList[$_],13);
            my $ctry = substr($countryList[ord substr($cityList[$_],5,1)], 2);
            $lkup{$_} = "$ctry $city";
        }
        @sortOrder = sort { $lkup{$a} cmp $lkup{$b} } 0..$#cityList;
    } else {
        return 0;
    }
    $sortedBy = $field;
    ClearLastMatches();
    return 1;
}

#------------------------------------------------------------------------------
# Add cities to the Geolocation database
# Inputs: 0-8) city,region,subregion,country_code,country,timezone,feature_code,population,lat,lon,altNames
# eg. AddEntry('Sinemorets','Burgas','Obshtina Tsarevo','BG','Bulgaria','Europe/Sofia','',400,42.06115,27.97833)
# Returns: true on success, otherwise issues warning
sub AddEntry(@)
{
    my ($city, $region, $subregion, $cc, $country, $timezone, $fc, $pop, $lat, $lon, $altNames) = @_;
    @_ < 10 and warn("Too few arguments in $city definition (check for updated format)\n"), return 0;
    length($cc) != 2 and warn("Country code '${cc}' is not 2 characters\n"), return 0;
    $featureTypes{$fc} = $1 if $fc =~ s/ (.*)//;
    my $fn = $featureCodes{lc $fc};
    unless (defined $fn) {
        if ($dbVer eq '1.02' or @featureCodes > 0x3f or not length $fc) {
            $fn = 0;
        } else {
            push @featureCodes, uc($fc);
            $featureCodes{lc $fc} = $fn = $#featureCodes;
        }
    }
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
        $#countryList >= 0xff and warn("AddEntry: Too many countries\n"), return 0;
        push @countryList, "$cc$country";
        $cn = $countryNum{lc $cc} = $#countryList;
    } elsif ($country) {
        $countryList[$cn] = "$cc$country";  # (override existing country name)
    }
    my $tn = $timezoneNum{lc $timezone};
    unless (defined $tn) {
        $#timezoneList >= 0x1ff and warn("AddEntry: Too many time zones\n"), return 0;
        push @timezoneList, $timezone;
        $tn = $timezoneNum{lc $timezone} = $#timezoneList;
    }
    my $rn = $regionNum{lc $region};
    unless (defined $rn) {
        $#regionList >= 0xfff and warn("AddEntry: Too many regions\n"), return 0;
        push @regionList, $region;
        $rn = $regionNum{lc $region} = $#regionList;
    }
    my $sn = $subregionNum{lc $subregion};
    unless (defined $sn) {
        my $max = $dbVer eq '1.02' ? 0x7fff : 0xffff;
        $#subregionList >= $max and warn("AddEntry: Too many subregions\n"), return 0;
        push @subregionList, $subregion;
        $sn = $subregionNum{lc $subregion} = $#subregionList;
    }
    $pop = sprintf('%.1e',$pop); # format: "3.1e+04" or "3.1e+004"
    # pack CC index, population and region index into a 32-bit integer
    my $code = ($cn << 24) | (substr($pop,-1,1)<<20) | (substr($pop,0,1)<<16) | (substr($pop,2,1)<<12) | $rn;
    # store high bit of timezone index
    if ($tn > 255) {
        if ($dbVer eq '1.02') {
            $sn |= 0x8000;
        } else {
            $fn |= 0x80;
        }
        $tn -= 256;
    }
    $lat = int(($lat + 90)  / 180 * 0x100000 + 0.5) & 0xfffff;
    $lon = int(($lon + 180) / 360 * 0x100000 + 0.5) & 0xfffff;
    my $hdr = pack('nCnNnCC', $lat>>4, (($lat&0x0f)<<4)|($lon&0x0f), $lon>>4, $code, $sn, $tn, $fn);
    push @cityList, "$hdr$city";
    # add altNames entry if provided
    if ($altNames) {
        chomp $altNames; # (just in case)
        $altNames =~ tr/,/\n/;
        # add any more arguments in case altNames were passed separately (undocumented)
        foreach (11..$#_) {
            chomp $_[$_];
            $altNames .= "\n$_[$_]";
        }
        $altNames[$#cityList] = $altNames;
    }
    $sortedBy = '';
    undef $lastArgs;    # (faster than ClearLastArgs)
    return 1;
}

#------------------------------------------------------------------------------
# Unpack entry in database
# Inputs: 0) entry number or index into sorted database,
#         1) optional language code, 2) flag to use index into sorted database
# Returns: 0-10) city,region,subregion,country_code,country,timezone,
#                feature_code,pop,lat,lon,feature_type
sub GetEntry($;$$)
{
    my ($entryNum, $lang, $sort) = @_;
    return() if $entryNum > $#cityList;
    $entryNum = $sortOrder[$entryNum] if $sort and @sortOrder > $entryNum;
    my ($lt,$f,$ln,$code,$sn,$tn,$fn) = unpack('nCnNnCC', $cityList[$entryNum]);
    my $city = substr($cityList[$entryNum],13);
    my $ctry = $countryList[$code >> 24];
    my $rgn = $regionList[$code & 0x0fff];
    if ($dbVer eq '1.02') {
        $sn & 0x8000 and $tn += 256, $sn &= 0x7fff;
    } else {
        $fn & 0x80 and $tn += 256;
    }
    my $sub = $subregionList[$sn];
    # convert population digits back into exponent format
    my $pop = (($code>>16 & 0x0f) . '.' . ($code>>12 & 0x0f) . 'e+' . ($code>>20 & 0x0f)) + 0;
    $lt = sprintf('%.4f', (($lt<<4)|($f >> 4))  * 180 / 0x100000 - 90);
    $ln = sprintf('%.4f', (($ln<<4)|($f & 0x0f))* 360 / 0x100000 - 180);
    my $fc = $featureCodes[$fn & 0x3f] || 'Other';
    my $cc = substr($ctry, 0, 2);
    my $country = substr($ctry, 2);
    my $ft = $featureTypes{$fc};
    if ($lang and $lang ne 'en') {
        my $xlat = $langLookup{$lang};
        # load language lookups if  not done already
        if (not defined $xlat) {
            unshift @INC, $geoDir;  # make sure $geoDir is first in path
            if (eval "require 'GeoLang/$lang.pm'") {
                my $trans = "Image::ExifTool::GeoLang::${lang}::Translate";
                no strict 'refs';
                $xlat = \%$trans if %$trans;
            }
            shift @INC;
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
            # City-specific: "CCRgn,Sub,City", "CCRgn,City", "CC,City", ",City"
            # Subregion-specific: "CCRgn,Sub,"
            # Region-specific: "CCRgn,"
            # Country-specific: "CC,"
            $city = $$xlat{"$cc$r2,$sub,$city"} || $$xlat{"$cc$r2,$city"} ||
                    $$xlat{"$cc,$city"} || $$xlat{",$city"} || $$xlat{$city} || $city;
            $sub = $$xlat{"$cc$rgn,$sub,"} || $$xlat{$sub} || $sub;
            $rgn = $$xlat{"$cc$rgn,"} || $$xlat{$rgn} || $rgn;
            $country = $$xlat{"$cc,"} || $$xlat{$country} || $country;
            $ft = $$xlat{$fc} if $$xlat{$fc};
        }
    }
    return($city,$rgn,$sub,$cc,$country,$timezoneList[$tn],$fc,$pop,$lt,$ln,$ft);
}

#------------------------------------------------------------------------------
# Get alternate names for specified database entry
# Inputs: 0) entry number or index into sorted database, 1) sort flag
# Returns: comma-separated list of alternate names, or empty string if no names
# Notes: ReadAltNames() must be called before this
sub GetAltNames($;$)
{
    my ($entryNum, $sort) = @_;
    $entryNum = $sortOrder[$entryNum] if $sort and @sortOrder > $entryNum;
    my $alt = $altNames[$entryNum] or return '';
    $alt =~ tr/\n/,/;
    return $alt;
}

#------------------------------------------------------------------------------
# Look up lat,lon or city in geolocation database
# Inputs: 0) "lat,lon", "city,region,country", etc, (city must be first)
#         1) options hash reference (or undef for no options)
# Options: GeolocMinPop, GeolocMaxDist, GeolocMulti, GeolocFeature, GeolocAltNames,
#          GeolocNearby
# Returns: 0) Reference to list of indices for matching cities, or undef for no matches
#          1) Reference to list of distance/bearing pairs, or undef if no GPS
#          In scalar context returns list of indices only
sub Geolocate($;$)
{
    my ($arg, $opts) = @_;
    my ($city, @exact, %regex, @multiCity, $other, $idx, @cargs);
    my ($minPop, $minDistU, $minDistC, @matchParms, @coords, %fcOK, $both);
    my ($pop, $maxDist, $multi, $fcodes, $altNames, @startTime);

    $opts and ($pop, $maxDist, $multi, $fcodes, $altNames) =
        @$opts{qw(GeolocMinPop GeolocMaxDist GeolocMulti GeolocFeature GeolocAltNames)};

    if ($debug) {
        require Time::HiRes;
        @startTime = Time::HiRes::gettimeofday();
    }
    @cityList or warn('No Geolocation database'), return();
    # make population code for comparing with 2 bytes at offset 6 in database
    if ($pop) {
        $pop = sprintf('%.1e', $pop);
        $minPop = chr((substr($pop,-1,1)<<4) | (substr($pop,0,1))) . chr(substr($pop,2,1)<<4);
    }
    if ($fcodes) {
        my $neg = $fcodes =~ s/^-//;
        my @fcodes = split /\s*,-?\s*/, lc $fcodes;     # (allow leading dash on subsequent codes)
        if ($neg) {
            $fcOK{$_} = 1 foreach 0..$#featureCodes;
            defined $featureCodes{$_} and delete $fcOK{$featureCodes{$_}} foreach @fcodes;
        } else {
            defined $featureCodes{$_} and $fcOK{$featureCodes{$_}} = 1 foreach @fcodes;
        }
    }
#
# process input argument
#
    my $num = 1;
    $arg =~ s/^\s+//; $arg =~ s/\s+$//; # remove leading/trailing spaces
    my @args = split /\s*,\s*/, $arg;
    my %ri = ( cc => 0, co => 1, re => 2, sr => 3, ci => 8, '' => 9 );
    foreach (@args) {
        # allow regular expressions optionally prefixed by "ci", "cc", "co", "re" or "sr"
        if (m{^(-)?(\w{2})?/(.*)/(i?)$}) {
            my $re = $4 ? qr/$3/im : qr/$3/m;
            next if not defined($idx = $ri{$2});
            push @cargs, $_;
            $other = 1 if $idx < 5;
            $idx += 10 if $1;   # add 10 for negative matches
            $regex{$idx} or $regex{$idx} = [ ];
            push @{$regex{$idx}}, $re;
            $city = '' unless defined $city;
        } elsif (/^[-+]?\d+(\.\d+)?$/) {    # coordinate format
            push @coords, $_ if @coords < 2;
        } elsif (/^([-+]?\d+(?:\.\d+)?) *(([NS])[A-Z]*)? +([-+]?\d+(?:\.\d+)?) *(([EW])[A-Z]*)?/i) { # "lat lon" format
            next if @coords;
            my ($lat, $lon) = ($1, $4);
            $lat = -abs($lat) if $3 and uc($3) eq 'S';
            $lon = -abs($lon) if $6 and uc($6) eq 'W';
            push @coords, $lat, $lon;
        } elsif (lc $_ eq 'both') {
            $both = 1;
        } elsif ($_ =~ /^num=(\d+)$/i) {
            $num = $1;
        } elsif ($_) {
            push @cargs, $_;
            if ($city) {
                push @exact, lc $_;
            } else {
                $city = lc $_;
            }
        }
    }
    unless (defined $city or @coords == 2) {
        warn("Insufficient information to determine geolocation\n");
        return();
    }
    # sort database by logitude if finding entry based on coordinates
    SortDatabase('Latitude') if @coords == 2 and ($both or not defined $city);
#
# perform reverse Geolocation lookup to determine GPS based on city, country, etc.
#
    while (defined $city and (@coords != 2 or $both)) {
        my $cargs = join(',', @cargs, $pop||'', $maxDist||'', $fcodes||'');
        my $i = 0;
        if ($lastArgs and $lastArgs eq $cargs) {
            $i = @cityList; # bypass search
        } else {
            ClearLastMatches();
            $lastArgs = $cargs;
        }
        # read alternate names database if an exact city match is specified
        if ($altNames) {
            ReadAltNames() if $city and $altDir;
            $altNames = \@altNames;
        } else {
            $altNames = [ ];    # (don't search alt names)
        }
Entry:  for (; $i<@cityList; ++$i) {
            my $cty = substr($cityList[$i],13);
            if ($city and $city ne lc $cty) { # test exact city name first
                next unless $$altNames[$i] and $$altNames[$i] =~ /^$city$/im;
            }
            # test with city-specific regexes
            if ($regex{8})  { $cty =~ $_ or next Entry foreach @{$regex{8}} }
            if ($regex{18}) { $cty !~ $_ or next Entry foreach @{$regex{18}} }
            # test other arguments
            my ($cd,$sn) = unpack('x5Nn', $cityList[$i]);
            my $ct = $countryList[$cd >> 24];
            $sn &= 0x7fff if $dbVer eq '1.02';
            my @geo = (substr($ct,0,2), substr($ct,2), $regionList[$cd & 0x0fff], $subregionList[$sn]);
            if (@exact) {
                # make quick lookup for all names at this location
                my %geoLkup;
                $_ and $geoLkup{lc $_} = 1 foreach @geo;
                $geoLkup{$_} or next Entry foreach @exact;
            }
            # test with cc, co, re and sr regexes
            if ($other) { foreach $idx (0..3) {
                if ($regex{$idx})    { $geo[$idx] =~ $_ or next Entry foreach @{$regex{$idx}} }
                if ($regex{$idx+10}) { $geo[$idx] !~ $_ or next Entry foreach @{$regex{$idx+10}} }
            } }
            # test regexes for any place name
            if ($regex{9} or $regex{19}) {
                my $str = join "\n", $cty, @geo;
                $str =~ $_ or next Entry foreach @{$regex{9}};
                $str !~ $_ or next Entry foreach @{$regex{19}};
            }
            # test feature code and population
            next if $fcodes and not $fcOK{ord(substr($cityList[$i],12,1)) & 0x3f};
            my $pc = substr($cityList[$i],6,2);
            if (not defined $minPop or $pc ge $minPop) {
                $lastFound{$i} = $pc;
                push @lastByLat, $i if @coords == 2;
            }
        }
        @startTime and printf("= Processing time: %.3f sec\n", Time::HiRes::tv_interval(\@startTime));
        if (%lastFound) {
            last if @coords == 2;   # continue to use coords with last city matches
            scalar(keys %lastFound) > 200 and warn("Too many matching cities\n"), return();
            # return nearby cities if "num=" is used and only one match found
            if ($num > 1 and scalar(keys %lastFound) == 1) {
                my ($i) = keys %lastFound;
                my @entry = GetEntry($i);
                @coords = @entry[8,9];
                SortDatabase('Latitude');   # (make sure we are sorted by latitude)
                last;
            }
            unless (@lastByPop) {
                @lastByPop = sort { $lastFound{$b} cmp $lastFound{$a} or $cityList[$a] cmp $cityList[$b] } keys %lastFound;
            }
            return(\@lastByPop);
        }
        warn "No such city in Geolocation database\n";
        return();
    }
#
# determine Geolocation based on GPS coordinates
#
    my ($lat, $lon) = @coords;
    if ($maxDist) {
        $minDistU = $maxDist / (2 * $earthRadius);              # min distance on unit sphere
        $minDistC = $maxDist * 0x100000 / ($pi * $earthRadius); # min distance in coordinate units
    } else {
        $minDistU = $pi;
        $minDistC = 0x200000;
    }
    my $cos = cos($lat * $pi / 180); # cosine factor for longitude distances
    # reduce lat/lon to the range 0-0x100000
    $lat = int(($lat + 90)  / 180 * 0x100000 + 0.5) & 0xfffff;
    $lon = int(($lon + 180) / 360 * 0x100000 + 0.5) & 0xfffff;
    $lat or $lat = $coords[0] < 0 ? 1 : 0xfffff;    # (zero latitude is a problem for our calculations)
    my $coord = pack('nCn',$lat>>4,(($lat&0x0f)<<4)|($lon&0x0f),$lon>>4);;
    # start from cached city matches if also using city information
    my $numEntries = @lastByLat || @cityList;
    # binary search to find closest longitude
    my ($n0, $n1) = (0, $numEntries - 1);
    my $sorted = @lastByLat ? \@lastByLat : (@sortOrder ? \@sortOrder : undef);
    while ($n1 - $n0 > 1) {
        my $n = int(($n0 + $n1) / 2);
        if ($coord lt $cityList[$sorted ? $$sorted[$n] : $n]) {
            $n1 = $n;
        } else {
            $n0 = $n;
        }
    }
    # step backward then forward through database to find nearest city
    my ($inc, $end, $n) = (-1, -1, $n0+1);
    my ($p0, $t0) = ($lat*$pi/0x100000 - $pi/2, $lon*$pi/0x080000 - $pi);
    my $cp0 = cos($p0);
    my (@matches, @rtnList, @dist);

    for (;;) {
        if (($n += $inc) == $end) {
            last if $inc == 1 or $n0 == $n1;
            ($inc, $end, $n) = (1, $numEntries, $n1);
        }
        my $i = $sorted ? $$sorted[$n] : $n;
        # get city latitude/longitude
        my ($lt,$f,$ln) = unpack('nCn', $cityList[$i]);
        $lt = ($lt << 4) | ($f >> 4);
        # searched far enough if latitude alone is further than best distance
        abs($lt - $lat) > $minDistC and $n = $end - $inc, next;
        # ignore if population is below threshold
        next if defined $minPop and $minPop ge substr($cityList[$i],6,2);
        next if $fcodes and not $fcOK{ord(substr($cityList[$i],12,1)) & 0x3f};
        $ln = ($ln << 4) | ($f & 0x0f);
        # calculate great circle distance to this city on unit sphere
        my ($p1, $t1) = ($lt*$pi/0x100000 - $pi/2, $ln*$pi/0x080000 - $pi);
        my ($sp, $st) = (sin(($p1-$p0)/2), sin(($t1-$t0)/2));
        my $a = $sp * $sp + $cp0 * cos($p1) * $st * $st;
        my $distU = atan2(sqrt($a), sqrt(1-$a)); # distance on unit sphere
        next if $distU > $minDistU;
        @matchParms = ($i, $p1, $t1, $distU);
        if ($num <= 1) {
            $minDistU = $distU;
        } else {
            my $j;
            # add this entry into list of matching cities ordered by closest first
            for ($j=0; $j<@matches; ++$j) {
                last if $distU < $matches[$j][3];
            }
            if ($j < $#matches) {
                splice @matches, $j, 0, [ @matchParms ];
            } else {
                $matches[$j] = [ @matchParms ];
            }
            # restrict list to the specified number of nearest cities
            pop @matches if @matches > $num;
            # update minimum distance with furthest match if we satisfied our quota
            $minDistU = $matches[-1][3] if @matches >= $num;
        }
        $minDistC = $minDistU * 0x200000 / $pi;  # distance in scaled coordinate units
    }
    @matchParms or warn("No suitable location in Geolocation database\n"), return();
    $num = @matches;

    @startTime and printf("- Processing time: %.3f sec\n", Time::HiRes::tv_interval(\@startTime));

    for (;;) {
        if ($num > 1) {
            last unless @matches;
            @matchParms = @{$matches[0]};
            shift @matches;
        }
        # calculate distance in km and bearing to matching city
        my ($ii, $p1, $t1, $distU) = @matchParms;
        my $km = sprintf('%.2f', 2 * $earthRadius * $distU);
        my $be = atan2(sin($t1-$t0)*cos($p1-$p0), $cp0*sin($p1)-sin($p0)*cos($p1)*cos($t1-$t0));
        $be = int($be * 180 / $pi + 360.5) % 360; # convert from radians to integer degrees
        push @rtnList, $ii;
        push @dist, [ $km, $be ];
        last if $num <= 1;
    }
    return wantarray ? (\@rtnList, \@dist) : \@rtnList;
}

1; #end

__END__

=head1 NAME

Image::ExifTool::Geolocation - Determine geolocation from GPS and visa-versa

=head1 SYNOPSIS

Look up geolocation information (city, region, subregion, country, etc)
based on input GPS coordinates, or determine GPS coordinates based on city
name, etc.

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

=head2 ReadAltNames

Load the alternate names database.  Before calling this method the $altDir
package variable may be set, otherwise AltNames.dat is loaded from the same
directory as Geolocation.dat.  This method is called automatically by
L</Geolocate> if the GeolocAltNames option is used and an input city name is
provided.

    Image::ExifTool::Geolocation::ReadAltNames();

=over 4

=item Inputs:

(none)

=item Return Value:

True on success.  May be called repeatedly, but AltNames.dat is loaded only
on the first call.

=back

=head2 SortDatabase

Sort database in specified order.

    Image::ExifTool::Geolocation::SortDatabase('City');

=over 4

=item Inputs:

0) Sort order: 'Latitude', 'City' or 'Country'

=item Return Value:

1 on success, 0 on failure (bad sort order specified).

=back

=head2 AddEntry

Add entry to Geolocation database.

    Image::ExifTool::Geolocation::AddEntry($city, $region,
        $subregion, $countryCode, $country, $timezone,
        $featureCode, $population, $lat, $lon, $altNames);

=over 4

=item Inputs:

0) City name (UTF8)

1) Region, state or province name (UTF8), or empty string if unknown

2) Subregion name (UTF8), or empty string if unknown

3) 2-character ISO 3166 country code

4) Country name (UTF8), or empty string to use existing definition. If the
country name is provided for a country code that already exists in the
database, then the database entry is updated with the new country name.

5) Time zone identifier (eg. "America/New_York")

6) Feature code (eg. "PPL"), or empty if not known

7) City population

8) GPS latitude (signed floating point degrees)

9) GPS longitude

10) Optional comma-separated list of alternate names for the city

=item Return Value:

1 on success, otherwise sends a warning message to stderr

=back

=head2 GetEntry

Get entry from Geolocation database.

    my @vals = Image::ExifTool::Geolocation::GetEntry($num,$lang,$sort);

=over 4

=item Inputs:

0) Entry number in database, or index into sorted database

1) Optional language code

2) Optional flag to treat first argument as an index into the sorted
database

item Return Values:

0) City name, or undef if the entry didn't exist

1) Region name, or "" if no region

2) Subregion name, or "" if no subregion

3) Country code

4) Country name

5) Time zone

6) Feature code

7) City population

8) GPS latitude

9) GPS longitude

10) Feature type, or undef

=back

=head2 GetAltNames

Get alternate names for specified city.

    my $str = Image::ExifTool::Geolocation::GetAltNames($num,$sort);

=over 4

=item Inputs:

0) Entry number in database or index into the sorted database

1) Optional flag to treat first argument as an index into the sorted
database

=item Return value:

Comma-separated string of alternate names for this city.

=item Notes:

L</ReadAltNames> must be called before calling this routine.

=back

=head2 Geolocate

Return geolocation information for specified GPS coordinates or city name.

    my @rtnInfo = Image::ExifTool::Geolocation::Geolocate($arg,$opts);

=over 4

=item Inputs:

0) Input argument ("lat,lon", "city", "city,country", "city,region,country",
etc).  When specifying a city, the city name must come first, followed by
zero or more of the following in any order, separated by commas: region
name, subregion name, country code, and/or country name.  Regular
expressions in C</expr/> format are also allowed, optionally prefixed by
"ci", "re", "sr", "cc" or "co" to specifically match City, Region,
Subregion, CountryCode or Country name.  Two special controls may be added
to the argument list:

   'both'   - When search input includes both name and GPS coordinates, use
              both to determine the closest city matching the specified
              name(s) instead of using GPS only.

   'num=##' - When the search includes GPS coordinates, or when a single
              city is matched by name, return the nearest ## cities instead
              of just the closest or named one.  Returned cities are in the
              order from nearest to farthest.

See L<https://exiftool.org/geolocation.html#Read> for more details.

1) Optional reference to hash of options:

    GeolocMinPop   - Minimum population of cities to consider in search.
                     Default 0.

    GeolocMaxDist  - Maximum distance (km) to search for cities when an
                     input GPS position is used.  Default infinity.

    GeolocMulti    - Flag to return multiple cities if there is more than
                     one match.  Used in the case where no input GPS
                     coordinates are provided.  Default 0.

    GeolocFeature  - Comma-separated list of feature codes to include in
                     search, or exclude if the list starts with a dash (-).
                     Default undef.

    GeolocAltNames - Flag to search alternate names database if available
                     for matching city name (see ALTERNATE DATABASES below).
                     Default undef.

=item Return Values:

0) Reference to list of database entry numbers for matching cities, or undef
if no matches were found.

1) Reference to list of distance/bearing pairs for each matching city, or
undef if the search didn't provide GPS coordinates.

In scalar context, only the reference to the list of database entry numbers
is returned.

=back

=head1 ALTERNATE DATABASES

A different version of the cities database may be specified setting the
package $geoDir variable before loading this module.  This directory should
contain the Geolocation.dat file, and optionally a GeoLang directory for the
language translations.  The $geoDir variable may be set to an empty string
to disable loading of a database.

When searching for a city by name, AltNames.dat is checked to provide
additional possibilities for matches if the GeolocAltNames option is set and
an AltNames.dat database exists.  The package $altDir variable may be set to
specify a different directory for AltNames.dat, otherwise the
Geolocation.dat directory is assumed.  The entries in AltNames.dat must
match those in the currently loaded version of Geolocation.dat.

=head1 ADDING USER-DEFINED DATABASE ENTRIES

User-defined entries may be created by defining them using the following
technique before the Geolocation module is loaded.

    @Image::ExifTool::UserDefined::Geolocation = (
        # city, region, subregion, country code, country, timezone,
        ['Sinemorets','burgas','Obshtina Tsarevo','BG','','Europe/Sofia',
        # feature code, population, lat, lon
         'PPL',400,42.06115,27.97833],
    );

Similarly, user-defined language translations may be defined, and will
override any existing translations.  Translations for the default 'en'
language may also be specified.  See
L<https://exiftool.org/geolocation.html#Custom> for more information.

=head1 USING A CUSTOM DATABASE

This example shows how to use a custom database.  In this example, the input
database file is a comma-separated text file with columns corresponding to
the input arguments of the AddEntry method.

    $Image::ExifTool::Geolocation::geoDir = '';
    require Image::ExifTool::Geolocation;
    open DFILE, "< $filename";
    Image::ExifTool::Geolocation::AddEntry(split /,/) foreach <DFILE>;
    close DFILE;

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  The associated database files are
based on data from geonames.org with a Creative Commons license.

=head1 REFERENCES

=over 4

=item L<https://download.geonames.org/export/>

=item L<https://exiftool.org/geolocation.html>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

1; #end
