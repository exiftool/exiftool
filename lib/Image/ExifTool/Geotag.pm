#------------------------------------------------------------------------------
# File:         Geotag.pm
#
# Description:  Geotagging utility routines
#
# Revisions:    2009/04/01 - P. Harvey Created
#               2009/09/27 - PH Added Geosync feature
#               2009/06/25 - PH Read Garmin TCX track logs
#               2009/09/11 - PH Read ITC GPS track logs
#               2012/01/08 - PH Extract orientation information from PTNTHPR
#               2012/05/08 - PH Read Winplus Beacon .TXT files
#               2015/05/30 - PH Read Bramor gEO log files
#               2016/07/13 - PH Added ability to geotag date/time only
#               2019/07/02 - PH Added ability to read IMU CSV files
#               2019/11/10 - PH Also write pitch to CameraElevationAngle
#               2020/12/01 - PH Added ability to read DJI CSV log files
#               2022/06/21 - PH Added ability to read Google Takeout JSON files
#               2024/04/23 - PH Added ability to read more OpenTracks GPS tags
#
# References:   1) http://www.topografix.com/GPX/1/1/
#               2) http://www.gpsinformation.org/dale/nmea.htm#GSA
#               3) http://code.google.com/apis/kml/documentation/kmlreference.html
#               4) http://www.fai.org/gliding/system/files/tech_spec_gnss.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Geotag;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:Public);
use Image::ExifTool::GPS;

$VERSION = '1.76';

sub JITTER() { return 2 }       # maximum time jitter

sub GetTime($);
sub SetGeoValues($$;$);
sub PrintFixTime($);
sub PrintFix($@);

# XML tags that we recognize (keys are forced to lower case)
my %xmlTag = (
    lat         => 'lat',       # GPX
    latitude    => 'lat',       # Garmin
    latitudedegrees => 'lat',   # Garmin TCX
    lon         => 'lon',       # GPX
    longitude   => 'lon',       # Garmin
    longitudedegrees => 'lon',  # Garmin TCX
    ele         => 'alt',       # GPX
    elevation   => 'alt',       # PH
    alt         => 'alt',       # PH
    altitude    => 'alt',       # Garmin
    altitudemeters => 'alt',    # Garmin TCX
   'time'       => 'time',      # GPX/Garmin
    fix         => 'fixtype',   # GPX
    hdop        => 'hdop',      # GPX
    vdop        => 'vdop',      # GPX
    pdop        => 'pdop',      # GPX
    sat         => 'nsats',     # GPX
    atemp       => 'atemp',     # GPX (Garmin 550t)
    when        => 'time',      # KML
    coordinates => 'coords',    # KML
    coord       => 'coords',    # KML, as written by Google Location History
    begin       => 'begin',     # KML TimeSpan
    end         => 'time',      # KML TimeSpan
    course      => 'dir',       # (written by Arduino)
    pitch       => 'pitch',     # (written by Arduino)
    roll        => 'roll',      # (written by Arduino)
    speed       => 'speed',     # (OpenTrack gpx)
    accuracy_horizontal => 'err',#(OpenTrack gpx)
    # XML containers (fix is reset at the opening tag of these properties)
    wpt         => '',          # GPX
    trkpt       => '',          # GPX
    rtept       => '',          # GPX
    trackpoint  => '',          # Garmin
    placemark   => '',          # KML
);

# fix information keys which must be interpolated around a circle
my %cyclical = (lon => 1, track => 1, dir => 1, pitch => 1, roll => 1);
my %cyc180 = (lon => 1, pitch => 1, roll => 1); # wraps from 180 to -180

# fix information keys for each of our general categories
my %fixInfoKeys = (
   'pos'   => [ 'lat', 'lon' ],
    track  => [ 'track', 'speed' ],
    alt    => [ 'alt' ],
    orient => [ 'dir', 'pitch', 'roll' ],
    atemp  => [ 'atemp' ],
    err    => [ 'err' ],
);

my %isOrient = ( dir => 1, pitch => 1, roll => 1 ); # test for orientation key

# tags which may exist separately in some formats (eg. CSV)
my %sepTags = ( dir => 1, pitch => 1, roll => 1, track => 1, speed => 1 );

# conversion factors for GPSSpeed (standard EXIF units only)
my %speedConv = (
    'K' => 1.852,       # km/h per knot
    'M' => 1.150779448, # mph per knot
    'k' => 'K',         # (allow lower case)
    'm' => 'M',
    'km/h' => 'K',      # (allow other formats)
    'mph' => 'M',
);

# all recognized speed conversion factors (non-EXIF included)
my %otherConv = (
    'km/h' => 1.852,
    'mph'  => 1.150779448,
    'm/s'  => 0.514444,
);

my $secPerDay = 24 * 3600;  # a useful constant

#------------------------------------------------------------------------------
# Load GPS track log file
# Inputs: 0) ExifTool ref, 1) track log data or file name
# Returns: geotag hash data reference or error string
# - the geotag hash has the following members:
#       Points - hash of GPS fix information hashes keyed by Unix time
#       Times  - list of sorted Unix times (keys of Points hash)
#       NoDate - flag if some points have no date (ie. referenced to 1970:01:01)
#       IsDate - flag if some points have date
#       Has    - hash of flags for available information (track, orient, alt)
# - the fix information hash may contain:
#       lat    - signed latitude (required)
#       lon    - signed longitude (required)
#       alt    - signed altitude
#       time   - fix time in UTC as XML string
#       fixtype- type of fix ('none'|'2d'|'3d'|'dgps'|'pps')
#       pdop   - dilution of precision
#       hdop   - horizontal DOP
#       vdop   - vertical DOP
#       sats   - comma-separated list of active satellites
#       nsats  - number of active satellites
#       track  - track heading (deg true)
#       dir    - image direction (deg true)
#       pitch  - pitch angle (deg)
#       roll   - roll angle (deg)
#       speed  - speed (knots)
#       first  - flag set for first fix of track
# - concatenates new data with existing track data stored in ExifTool NEW_VALUE
#   for the Geotag tag
sub LoadTrackLog($$;$)
{
    local ($_, $/, *EXIFTOOL_TRKFILE);
    my ($et, $val) = @_;
    my ($raf, $from, $time, $isDate, $noDate, $noDateChanged, $lastDate, $dateFlarm);
    my ($nmeaStart, $fixSecs, @fixTimes, $lastFix, %nmea, @csvHeadings, $sortFixes);
    my ($canCut, $cutPDOP, $cutHDOP, $cutSats, $e0, $e1, @tmp, $trackFile, $trackTime);
    my $scaleSpeed;

    unless (eval { require Time::Local }) {
        return 'Geotag feature requires Time::Local installed';
    }
    # add data to existing track
    my $geotag = $et->GetNewValue('Geotag') || { };

    # initialize track points lookup
    my $points = $$geotag{Points};
    $points or $points = $$geotag{Points} = { };

    # get lookup for available information types
    my $has = $$geotag{Has};
    $has or $has = $$geotag{Has} = { 'pos' => 1 };

    my $format = '';
    # is $val track log data?
    if ($val =~ /^(\xef\xbb\xbf)?<(\?xml|gpx)[\s>]/) {
        $format = 'XML';
        $/ = '>';   # set input record separator to '>' for XML/GPX data
    } elsif ($val =~ /(\x0d\x0a|\x0d|\x0a)/) {
        $/ = $1;
    } else {
        # $val is track file name
        if ($et->Open(\*EXIFTOOL_TRKFILE, $val)) {
            $trackFile = $val;
            $raf = File::RandomAccess->new(\*EXIFTOOL_TRKFILE);
            unless ($raf->Read($_, 256)) {
                close EXIFTOOL_TRKFILE;
                return "Empty track file '${val}'";
            }
            # look for XML or GPX header (might as well allow UTF-8 BOM)
            if (/^(\xef\xbb\xbf)?<(\?xml|gpx)[\s>]/) {
                $format = 'XML';
                $/ = '>';   # set input record separator to '>' for XML/GPX data
            } elsif (/(\x0d\x0a|\x0d|\x0a)/) {
                $/ = $1;
            } else {
                close EXIFTOOL_TRKFILE;
                return "Invalid track file '${val}'";
            }
            $raf->Seek(0,0);
            $from = "file '${val}'";
        } elsif ($val eq 'DATETIMEONLY') {
            $$geotag{DateTimeOnly} = 1;
            $$geotag{IsDate} = 1;
            $et->VPrint(0, 'Geotagging date/time only');
            return $geotag;
        } else {
            return "Error opening GPS file '${val}'";
        }
    }
    unless ($from) {
        # set up RAF for reading log file in memory
        $raf = File::RandomAccess->new(\$val);
        $from = 'data';
    }

    # initialize cuts
    my $maxHDOP = $et->Options('GeoMaxHDOP');
    my $maxPDOP = $et->Options('GeoMaxPDOP');
    my $minSats = $et->Options('GeoMinSats');
    my $isCut = $maxHDOP || $maxPDOP || $minSats;

    my $numPoints = 0;
    my $skipped = 0;
    my $lastSecs = 0;
    my $fix = { };
    my $csvDelim = $et->Options('CSVDelim');
    $csvDelim = ',' unless defined $csvDelim;
    my (@saveFix, @saveTime, $timeSpan);
    for (;;) {
        $raf->ReadLine($_) or last;
        # determine file format
        if (not $format) {
            s/^\xef\xbb\xbf//;          # remove leading BOM if it exists
            if (/^\xff\xfe|\xfe\xff/) {
                return "ExifTool doesn't yet read UTF16-format track logs";
            }
            if (/^<(\?xml|gpx)[\s>]/) { # look for XML or GPX header
                $format = 'XML';
            # check for NMEA sentence
            # (must ONLY start with ones that have timestamps! eg. not GSA or PTNTHPR!)
            } elsif (/^.*\$([A-Z]{2}(RMC|GGA|GLL|ZDA)|PMGNTRK),/) {
                $format = 'NMEA';
                $nmeaStart = $2 || $1;  # save type of first sentence
            } elsif (/^A(FLA|XSY|FIL)/) {
                # (don't set format yet because we want to read HFDTE first)
                $nmeaStart = 'B' ;
                next;
            } elsif (/^HFDTE(?:DATE:)?(\d{2})(\d{2})(\d{2})/) {
                my $year = $3 + ($3 >= 70 ? 1900 : 2000);
                $dateFlarm = Time::Local::timegm(0,0,0,$1,$2-1,$year);
                $nmeaStart = 'B' ;
                $format = 'IGC';
                next;
            } elsif ($nmeaStart and /^B/) {
                # parse IGC fixes without a date
                $format = 'IGC';
            } elsif (/^TP,D,/) {
                $format = 'Winplus';
            } elsif (/^\s*\d+\s+.*\sypr\s*$/ and (@tmp=split) == 12) {
                $format = 'Bramor';
            } elsif (((/\b(GPS)?Date/i and /\b(GPS)?(Date)?Time/i) or /\bTime\(seconds\)/i) and /\Q$csvDelim/) {
                chomp;
                @csvHeadings = split /\Q$csvDelim/;
                $format = 'CSV';
                # convert recognized headings to our parameter names
                foreach (@csvHeadings) {
                    my $head = $_;
                    my $param;
                    my $xtra = '';
                    s/^GPS ?//; # remove leading "GPS" to simplify regex patterns
                    if (/^Time ?\(seconds\)$/i) { # DJI
                        # DJI CSV log files have a column "Time(seconds)" which is seconds since
                        # the start of the flight.  The date/time is obtained from the file name.
                        $param = 'runtime';
                        if ($trackFile and $trackFile =~ /(\d{4})-(\d{2})-(\d{2})[^\/]+(\d{2})-(\d{2})-(\d{2})[^\/]*$/) {
                            $trackTime = Image::ExifTool::TimeLocal($6,$5,$4,$3,$2-1,$1);
                            my $utc = PrintFixTime($trackTime);
                            my $tzs = Image::ExifTool::TimeZoneString([$6,$5,$4,$3,$2-1,$1-1900],$trackTime);
                            $et->VPrint(2, "  DJI start time:  $utc (local timezone is $tzs)\n");
                        } else {
                            return 'Error getting start time from file name for DJI CSV track file';
                        }
                    } elsif (/^Date ?Time/i) {  # ExifTool addition
                        $param = 'datetime';
                    } elsif (/^Date/i) {
                        $param = 'date';
                    } elsif (/^Time(?! ?\(text\))/i) { # (ignore DJI "Time(text)" column)
                        $param = 'time';
                    } elsif (/^(Pos)?Lat/i) {
                        $param = 'lat';
                        /ref$/i and $param .= 'ref';
                    } elsif (/^(Pos)?Lon/i) {
                        $param = 'lon';
                        /ref$/i and $param .= 'ref';
                    } elsif (/^(Pos)?Alt/i) {
                        $param = 'alt';
                    } elsif (/^Speed/i) {
                        $param = 'speed';
                        # (recognize units in brackets)
                        if (m{\((mph|km/h|m/s)\)}) {
                            $scaleSpeed = $otherConv{$1};
                            $xtra = " in $1";
                        } else {
                            $xtra = ' in knots';
                        }
                    } elsif (/^(Angle)?(Heading|Track|Bearing)/i) {
                        $param = 'track';
                    } elsif (/^(Angle)?Pitch/i or /^Camera ?Elevation ?Angle/i) {
                        $param = 'pitch';
                    } elsif (/^(Angle)?Roll/i) {
                        $param = 'roll';
                    } elsif (/^Img ?Dir/i) {
                        $param = 'dir';
                    }
                    if ($param) {
                        $et->VPrint(2, "CSV column '${head}' is $param$xtra\n");
                        $_ = $param;
                    } else {
                        $et->VPrint(2, "CSV column '${head}' ignored\n");
                        $_ = '';    # ignore this column
                    }
                }
                next;
            } elsif (/"(timelineObjects|placeVisit|activitySegment|latitudeE7)":/) {
                # Google Takeout JSON format
                $format = 'JSON';
                $sortFixes = 1; # (fixes are not all in order for this format)
            } else {
                # search only first 50 lines of file for a valid fix
                last if ++$skipped > 50;
                next;
            }
        }
#
# XML format (GPX, KML, Garmin XML/TCX etc)
#
        if ($format eq 'XML') {
            my ($arg, $tok, $td);
            s/\s*=\s*(['"])\s*/=$1/g;  # remove unnecessary white space in attributes
            # Workaround for KML generated by Google Location History:
            # lat/lon/alt are space-separated; we want commas.
            s{(\S+)\s+(\S+)\s+(\S+)(</gx:coord>)}{$1,$2,$3$4};
            foreach $arg (split) {
                # parse attributes (eg. GPX 'lat' and 'lon')
                # (note: ignore namespace prefixes if they exist)
                if ($arg =~ /^(\w+:)?(\w+)=(['"])(.*?)\3/g) {
                    my $tag = $xmlTag{lc $2};
                    if ($tag) {
                        $$fix{$tag} = $4;
                        if ($isOrient{$tag}) {
                            $$has{orient} = 1;
                        } elsif ($tag eq 'alt') {
                            # validate altitude
                            undef $$fix{alt} if defined $$fix{alt} and $$fix{alt} !~ /^[+-]?\d+\.?\d*/;
                            $$has{alt} = 1 if $$fix{alt};   # set "has altitude" flag if appropriate
                        } elsif ($tag eq 'atemp' or $tag eq 'speed' or $tag eq 'err') {
                            $$has{$tag} = 1;
                        }
                    }
                }
                # loop through XML elements
                while ($arg =~ m{([^<>]*)<(/)?(\w+:)?(\w+)(>|$)}g) {
                    my $tag = $xmlTag{$tok = lc $4};
                    # parse as a simple property if this element has a value
                    if (defined $tag and not $tag) {
                        # a containing property was opened or closed
                        if (not $2) {
                            # opened: start a new fix
                            $lastFix = $fix = { };
                            undef @saveFix;
                            next;
                        } elsif ($fix and $lastFix and %$fix) {
                            # closed: transfer additional tags from current fix
                            foreach (keys %$fix) {
                                $$lastFix{$_} = $$fix{$_} unless defined $$lastFix{$_};
                            }
                            undef $lastFix;
                        }
                    }
                    if (length $1) {
                        if ($tag) {
                            if ($tag eq 'coords') {
                                # save other fixes if there are more than one
                                if (defined $$fix{lon} and defined $$fix{lat} and defined $$fix{alt}) {
                                    push @saveFix, [ @$fix{'lon','lat','alt'} ];
                                }
                                # read KML "Point" coordinates
                                @$fix{'lon','lat','alt'} = split ',', $1;
                                $$has{alt} = 1 if $$fix{alt};
                            } else {
                                if ($tok eq 'when' and $$fix{'time'}) {
                                    push @saveTime, $1; # flightaware KML stores times in array
                                } else {
                                    $$fix{$tag} = $1;
                                }
                                if ($isOrient{$tag}) {
                                    $$has{orient} = 1;
                                } elsif ($tag eq 'alt') {
                                    # validate altitude
                                    undef $$fix{alt} if defined $$fix{alt} and $$fix{alt} !~ /^[+-]?\d+\.?\d*/;
                                    $$has{alt} = 1 if $$fix{alt};   # set "has altitude" flag if appropriate
                                } elsif ($tag eq 'atemp' or $tag eq 'speed' or $tag eq 'err') {
                                    $$has{$tag} = 1;
                                }
                            }
                        }
                        next;
                    } elsif ($tok eq 'td') {
                        $td = 1;
                    }
                    # validate and store GPS fix
                    next unless defined $$fix{lat} and defined $$fix{lon};
                    unless (defined $$fix{'time'}) {
                        next unless @saveTime;
                        $$fix{'time'} = shift @saveTime; # get next time in flightaware KML list
                    }
                    unless ($$fix{lat} =~ /^[+-]?\d+\.?\d*/ and $$fix{lon} =~ /^[+-]?\d+\.?\d*/) {
                        $e0 or $et->VPrint(0, "Coordinate format error in $from\n"), $e0 = 1;
                        next;
                    }
                    unless (defined($time = GetTime($$fix{'time'}))) {
                        $e1 or $et->VPrint(0, "Timestamp format error in $from\n"), $e1 = 1;
                        next;
                    }
                    $isDate = 1;
                    $canCut= 1 if defined $$fix{pdop} or defined $$fix{hdop} or defined $$fix{nsats};
                    # generate extra fixes assuming an equally spaced track
                    if ($$fix{begin}) {
                        my $begin = GetTime($$fix{begin});
                        undef $$fix{begin};
                        if (defined $begin and $begin < $time) {
                            $$fix{span} = $timeSpan = ($timeSpan || 0) + 1;
                            my $i;
                            # duplicate the fix if there is only one so we will have
                            # a fix and the start and end of the TimeSpan
                            @saveFix or push @saveFix, [ @$fix{'lon','lat','alt'} ];
                            for ($i=0; $i<@saveFix; ++$i) {
                                my $t = $begin + ($time - $begin) * ($i / scalar(@saveFix));
                                my %f;
                                @f{'lon','lat','alt'} = @{$saveFix[$i]};
                                $t += 0.001 if not $i and $$points{$t}; # (avoid dupicates)
                                $f{span} = $timeSpan;
                                $$points{$t} = \%f;
                                push @fixTimes, $t;
                            }
                        }
                    }
                    $$points{$time} = $fix;
                    push @fixTimes, $time;  # save times of all fixes in order
                    $fix = { };
                    undef @saveFix;
                    ++$numPoints;
                }
            }
            # last ditch check KML description for timestamp (assume it is UTC)
            $$fix{'time'} = "$1T$2Z" if $td and not $$fix{'time'} and
                /[\s>](\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2}(\.\d+)?)/;
            next;
#
# Winplus Beacon text file
#
        } elsif ($format eq 'Winplus') {
            # TP,D, 44.933666667, -93.186555556, 10/26/2011, 19:07:28, 0
            #       latitude      longitude      date        time
            /^TP,D,\s*([-+]?\d+\.\d*),\s*([-+]?\d+\.\d*),\s*(\d+)\/(\d+)\/(\d{4}),\s*(\d+):(\d+):(\d+)/ or next;
            $$fix{lat} = $1;
            $$fix{lon} = $2;
            $time = Time::Local::timegm($8,$7,$6,$4,$3-1,$5);
DoneFix:    $isDate = 1;
            $$points{$time} = $fix;
            push @fixTimes, $time;
            $fix = { };
            ++$numPoints;
            next;
#
# Bramor gEO log file
#
        } elsif ($format eq 'Bramor') {
            #   1 0015   18.723675   50.672752  149 169.31 22/04/2015 07:06:55 169.31    8.88   28.07 ypr
            #   ? index  latitude    longitude  alt track  date       time     dir       pitch  roll
            my @parts = split ' ', $_;
            next unless @parts == 12 and $parts[11] eq 'ypr';
            my @d = split m{/}, $parts[6];  # date (dd/mm/YYYY)
            my @t = split m{:}, $parts[7];  # time (HH:MM:SS)
            next unless @d == 3 and @t == 3;
            @$fix{qw(lat lon alt track dir pitch roll)} = @parts[2,3,4,5,8,9,10];
            # (add the seconds afterwards in case some models have decimal seconds)
            $time = Time::Local::timegm(0,$t[1],$t[0],$d[0],$d[1]-1,$d[2]) + $t[2];
            # set necessary flags for extra available information
            @$has{qw(alt track orient)} = (1,1,1);
            goto DoneFix;   # save this fix
        } elsif ($format eq 'CSV') {
            chomp;
            my @vals = split /\Q$csvDelim/;
#
# CSV format output of GPS/IMU POS system
#   Date*           - date in DD/MM/YYYY format
#   Time*           - time in HH:MM:SS.SSS format
#   [Pos]Lat*       - latitude in decimal degrees
#   [Pos]Lon*       - longitude in decimal degrees
#   [Pos]Alt*       - altitude in m relative to sea level
#   [Angle]Heading* - GPSTrack in degrees true
#   [Angle]Pitch*   - pitch angle in degrees
#   [Angle]Roll*    - roll angle in degrees
# (ExifTool enhancements allow for standard tag names or descriptions as the column headings,
#  add support for time zones and flexible coordinates, and allow new DateTime and Shift columns)
#
            my ($param, $date, $secs, %neg);
            foreach $param (@csvHeadings) {
                my $val = shift @vals;
                last unless defined $val and length($val);
                next unless $param;
                if ($param eq 'datetime') {
                    # (fix formats like "24.07.2016 13:47:30")
                    $val =~ s/^(\d{2})[^\d](\d{2})[^\d](\d{4}) /$3:$2:$1 /;
                    local $SIG{'__WARN__'} = sub { };
                    my $dateTime = $et->InverseDateTime($val);
                    if ($dateTime) {
                        $date = Image::ExifTool::GetUnixTime($val, 2);
                        $secs = 0;
                    }
                } elsif ($param eq 'date') {
                    if ($val =~ m{^(\d{2})/(\d{2})/(\d{4})$}) {
                        $date = Time::Local::timegm(0,0,0,$1,$2-1,$3);
                    } elsif ($val =~ /(\d{4}).*?(\d{2}).*?(\d{2})/) {
                        $date = Time::Local::timegm(0,0,0,$3,$2-1,$1);
                    }
                } elsif ($param eq 'time') {
                    if ($val =~ /^(\d{1,2}):(\d{2}):(\d{2}(\.\d+)?).*?(([-+])(\d{1,2}):?(\d{2}))?/) {
                        $secs = (($1 * 60) + $2) * 60 + $3;
                        # adjust for time zone if specified
                        $secs += ($7 * 60 + $8) * ($6 eq '-' ? 60 : -60) if $5;
                    }
                } elsif ($param eq 'lat' or $param eq 'lon') {
                    $$fix{$param} = Image::ExifTool::GPS::ToDegrees($val, 1);
                } elsif ($param eq 'latref') {
                    $neg{lat} = 1 if $val =~ /^S/i;
                } elsif ($param eq 'lonref') {
                    $neg{lon} = 1 if $val =~ /^W/i;
                } elsif ($param eq 'runtime') {
                    $date = $trackTime;
                    $secs = $val;
                } else {
                    $val /= $scaleSpeed if $scaleSpeed and $param eq 'speed';
                    $$fix{$param} = $val;
                    $$has{$param} = 1 if $sepTags{$param};
                }
            }
            # make coordinate negative according to reference direction if necessary
            foreach $param (keys %neg) {
                next unless defined $$fix{$param};
                $$fix{$param} = -abs($$fix{$param});
            }
            if ($date and defined $secs and defined $$fix{lat} and defined $$fix{lon}) {
                $time = $date + $secs;
                $$has{alt} = 1 if defined $$fix{alt};
                $$has{track} = 1 if defined $$fix{track};
                $$has{orient} = 1 if defined $$fix{pitch};
                goto DoneFix;
            }
            next;
        } elsif ($format eq 'JSON') {
            # Google Takeout JSON format
            if (/"(latitudeE7|longitudeE7|latE7|lngE7|timestamp)":\s*"?(.*?)"?,?\s*[\x0d\x0a]/) {
                if ($1 eq 'timestamp') {
                    $time = GetTime($2);
                    goto DoneFix if $time and $$fix{lat} and $$fix{lon};
                } elsif ($1 eq 'latitudeE7' or $1 eq 'latE7') {
                    $$fix{lat} = $2 * 1e-7;
                } else {
                    $$fix{lon} = $2 * 1e-7;
                }
            }
            next;
        }
        my (%fix, $secs, $date, $nmea);
        if ($format eq 'NMEA') {
            # ignore unrecognized NMEA sentences
            # (first 2 characters: GP=GPS, GL=GLONASS, GA=Gallileo, GN=combined, BD=Beidou)
            next unless /^(.*)\$([A-Z]{2}(RMC|GGA|GLL|GSA|ZDA)|PMGNTRK|PTNTHPR),/;
            $nmea = $3 || $2;
            $_ = substr($_, length($1)) if length($1);
        }
#
# IGC (flarm) (ref 4)
#
        if ($format eq 'IGC') {
            # B0939564531208N00557021EA007670089100207
            # BHHMMSSDDMMmmmNDDDMMmmmEAaaaaaAAAAAxxyy
            #    HH     MM     SS     DD     MM     mmm          DDD    MM     mmm                aaaaa AAAAA
            #    1      2      3      4      5      6      7     8      9      10     11    12    13    14
            /^B(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{3})([NS])(\d{3})(\d{2})(\d{3})([EW])([AV])(\d{5})(\d{5})/ or next;
            $fix{lat} = ($4 + ($5 + $6/1000)/60) * ($7  eq 'N' ? 1 : -1);
            $fix{lon} = ($8 + ($9 +$10/1000)/60) * ($11 eq 'E' ? 1 : -1);
            $fix{alt} = $12 eq 'A' ? $14 : undef;
            $secs = (($1 * 60) + $2) * 60 + $3;
            # wrap to next day if necessary
            if ($dateFlarm) {
                $dateFlarm += $secPerDay if $secs < $lastSecs - JITTER();
                $date = $dateFlarm;
            }
            $nmea = 'B';
#
# NMEA RMC sentence (contains date)
#
        } elsif ($nmea eq 'RMC') {
            #  $GPRMC,092204.999,A,4250.5589,S,14718.5084,E,0.00,89.68,211200,,*25
            #  $GPRMC,093657.007,,3652.835020,N,01053.104094,E,1.642,,290913,,,A*0F
            #  $GPRMC,hhmmss.sss,A/V,ddmm.mmmm,N/S,dddmm.mmmm,E/W,spd(knots),dir(deg),DDMMYY,,*cs
            /^\$[A-Z]{2}RMC,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/ or next;
            next if $13 > 31 or $14 > 12 or $15 > 99;   # validate day/month/year
            $fix{lat} = (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1);
            $fix{lon} = (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1);
            $fix{speed} = $11 if length $11;
            $fix{track} = $12 if length $12;
            my $year = $15 + ($15 >= 70 ? 1900 : 2000);
            $secs = (($1 * 60) + $2) * 60 + $3;
            $date = Time::Local::timegm(0,0,0,$13,$14-1,$year);
#
# NMEA GGA sentence (no date)
#
        } elsif ($nmea eq 'GGA') {
            #  $GPGGA,092204.999,4250.5589,S,14718.5084,E,1,04,24.4,19.7,M,,,,0000*1F
            #  $GPGGA,093657.000,3652.835020,N,01053.104094,E,,8,,166.924,M,40.9,M,,*77
            #  $GPGGA,hhmmss.sss,ddmm.mmmm,N/S,dddmm.mmmm,E/W,0=invalid,sats,hdop,alt,M,...
            /^\$[A-Z]{2}GGA,(\d{2})(\d{2})(\d+(\.\d*)?),(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),[1-6]?,(\d+)?,(\.\d+|\d+\.?\d*)?,(-?\d+\.?\d*)?,M?/ or next;
            $fix{lat} = (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1);
            $fix{lon} = (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1);
            @fix{qw(nsats hdop alt)} = ($11,$12,$13);
            $secs = (($1 * 60) + $2) * 60 + $3;
            $canCut = 1;
#
# NMEA GLL sentence (no date)
#
        } elsif ($nmea eq 'GLL') {
            #  $GPGLL,4250.5589,S,14718.5084,E,092204.999,A*2D
            #  $GPGLL,ddmm.mmmm,N/S,dddmm.mmmm,E/W,hhmmss.sss,A/V*cs
            /^\$[A-Z]{2}GLL,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d{2})(\d{2})(\d+(\.\d*)?),A/ or next;
            $fix{lat} = (($1 || 0) + $2/60) * ($3 eq 'N' ? 1 : -1);
            $fix{lon} = (($4 || 0) + $5/60) * ($6 eq 'E' ? 1 : -1);
            $secs = (($7 * 60) + $8) * 60 + $9;
#
# NMEA GSA sentence (satellite status, no date)
#
        } elsif ($nmea eq 'GSA') {
            # $GPGSA,A,3,04,05,,,,,,,,,,,pdop,hdop,vdop*HH
            /^\$[A-Z]{2}GSA,[AM],([23]),((?:\d*,){11}(?:\d*)),(\d+\.?\d*|\.\d+)?,(\d+\.?\d*|\.\d+)?,(\d+\.?\d*|\.\d+)?\*/ or next;
            @fix{qw(fixtype sats pdop hdop vdop)} = ($1.'d',$2,$3,$4,$5);
            # count the number of acquired satellites
            my @a = ($fix{sats} =~ /\d+/g);
            $fix{nsats} = scalar @a;
            $canCut = 1;
#
# NMEA ZDA sentence (date/time, contains date)
#
        } elsif ($nmea eq 'ZDA') {
            #  $GPZDA,093655.000,29,09,2013,,*58
            #  $GPZDA,hhmmss.ss,DD,MM,YYYY,tzh,tzm (hhmmss in UTC)
            /^\$[A-Z]{2}ZDA,(\d{2})(\d{2})(\d{2}(\.\d*)?),(\d+),(\d+),(\d+)/ or next;
            $secs = (($1 * 60) + $2) * 60 + $3;
            $date = Time::Local::timegm(0,0,0,$5,$6-1,$7);
#
# Magellan eXplorist PMGNTRK (Proprietary MaGellaN TRacK) sentence (optional date)
#
        } elsif ($nmea eq 'PMGNTRK') {
            # $PMGNTRK,4415.026,N,07631.091,W,00092,M,185031.06,A,,020409*65
            # $PMGNTRK,ddmm.mmm,N/S,dddmm.mmm,E/W,alt,F/M,hhmmss.ss,A/V,trkname,DDMMYY*cs
            /^\$PMGNTRK,(\d+)(\d{2}\.\d+),([NS]),(\d+)(\d{2}\.\d+),([EW]),(-?\d+\.?\d*),([MF]),(\d{2})(\d{2})(\d+(\.\d*)?),A,(?:[^,]*,(\d{2})(\d{2})(\d+))?/ or next;
            $fix{lat} = ($1 + $2/60) * ($3 eq 'N' ? 1 : -1);
            $fix{lon} = ($4 + $5/60) * ($6 eq 'E' ? 1 : -1);
            $fix{alt} = $8 eq 'M' ? $7 : $7 * 12 * 0.0254;
            $secs = (($9 * 60) + $10) * 60 + $11;
            if (defined $15) {
                next if $13 > 31 or $14 > 12 or $15 > 99;   # validate day/month/year
                # optional date is available in PMGNTRK sentence
                my $year = $15 + ($15 >= 70 ? 1900 : 2000);
                $date = Time::Local::timegm(0,0,0,$13,$14-1,$year);
            }
#
# Honeywell HMR3000 PTNTHPR (Heading Pitch Roll) sentence (no date)
# (ref http://www.gpsarea.com/uploadfile/download/introduce/hmr3000_manual.pdf)
#
        } elsif ($nmea eq 'PTNTHPR') {
            # $PTNTHPR,85.9,N,-0.9,N,0.8,N*HH
            # $PTNTHPR,heading,heading status,pitch,pitch status,roll,roll status,*cs
            # status: L=low alarm, M=low warning, N=normal, O=high warning
            #         P=high alarm, C=tuning analog circuit
            # (ignore this information on any alarm status)
            /^\$PTNTHPR,(-?[\d.]+),[MNO],(-?[\d.]+),[MNO],(-?[\d.]+),[MNO]/ or next;
            @fix{qw(dir pitch roll)} = ($1,$2,$3);

        } else {
            next;   # this shouldn't happen
        }
        # remember the NMEA formats we successfully read
        $nmea{$nmea} = 1;
        # use last date if necessary (and appropriate)
        if (defined $secs and not defined $date and defined $lastDate) {
            # wrap to next day if necessary
            if ($secs < $lastSecs - JITTER()) {
                $lastSecs -= $secPerDay;
                $lastDate += $secPerDay;
            }
            # use earlier date only if we are within 10 seconds
            if ($secs - $lastSecs < 10) {
                # last date is close, use it for this fix
                $date = $lastDate;
            } else {
                # last date is old, discard it
                undef $lastDate;
                undef $lastSecs;
            }
        }
        # save our last date/time
        if (defined $date) {
            $lastDate = $date;
            $lastSecs = $secs;
        }
#
# Add NMEA/IGC fix to our lookup
# (this is much more complicated than it needs to be because
#  the stupid NMEA format provides no end-of-fix indication)
#
        # assumptions for each NMEA sentence:
        # - we only parse a time if we get a lat/lon
        # - we always get a time if we have a date
        if ($nmea eq $nmeaStart or (defined $secs and (not defined $fixSecs or
            # don't combine sentences that are outside 10 seconds apart
            ($secs >= $fixSecs and $secs - $fixSecs >= 10) or
            ($secs <  $fixSecs and $secs + $secPerDay - $fixSecs >= 10))))
        {
            # start a new fix
            $fix = \%fix;
            $fixSecs = $secs;
            undef $noDateChanged;
            # does this fix have a date/time or time stamp?
            if (defined $date) {
                $fix{isDate} = $isDate = 1;
                $time = $date + $secs;
            } elsif (defined $secs) {
                $time = $secs;
                $noDate = $noDateChanged = 1;
            } else {
                next;   # wait until we have a time before adding to lookup
            }
        } else {
            # add new data to existing fix (but don't overwrite earlier values to
            # keep the coordinates in sync with the fix time)
            foreach (keys %fix) {
                $$fix{$_} = $fix{$_} unless defined $$fix{$_};
            }
            if (defined $date) {
                next if $$fix{isDate};
                # move this fix to the proper date
                if (defined $fixSecs) {
                    delete $$points{$fixSecs};
                    pop @fixTimes if @fixTimes and $fixTimes[-1] == $fixSecs;
                    --$numPoints;
                    # if we wrapped to the next day since the start of this fix,
                    # we must shift the date back to the day of $fixSecs
                    $date -= $secPerDay if $secs < $fixSecs;
                } else {
                    $fixSecs = $secs;
                }
                $time = $date + $fixSecs;
                $$fix{isDate} = $isDate = 1;
                # revert noDate flag if it was set for this fix
                $noDate = 0 if $noDateChanged;
            } elsif (defined $secs and not defined $fixSecs) {
                $time = $fixSecs = $secs;
                $noDate = $noDateChanged = 1;
            } else {
                next;   # wait until we have a time
            }
        }
        # add fix to our lookup
        $$points{$time} = $fix;
        push @fixTimes, $time;  # save time of all fixes in order
        ++$numPoints;
    }
    $raf->Close();

    # set date flags
    if ($noDate and not $$geotag{NoDate}) {
        if ($isDate) {
            $et->Warn('Fixes are date-less -- will use time-only interpolation');
        } else {
            $et->Warn('Some fixes are date-less -- may use time-only interpolation');
        }
        $$geotag{NoDate} = 1;
    }
    $$geotag{IsDate} = 1 if $isDate;

    # cut bad fixes if necessary
    if ($isCut and $canCut) {
        $cutPDOP = $cutHDOP = $cutSats = 0;
        my @goodTimes;
        foreach (@fixTimes) {
            $fix = $$points{$_} or next;
            if ($maxPDOP and $$fix{pdop} and $$fix{pdop} > $maxPDOP) {
                delete $$points{$_};
                ++$cutPDOP;
            } elsif ($maxHDOP and $$fix{hdop} and $$fix{hdop} > $maxHDOP) {
                delete $$points{$_};
                ++$cutHDOP;
            } elsif ($minSats and defined $$fix{nsats} and $$fix{nsats} ne '' and
                $$fix{nsats} < $minSats)
            {
                delete $$points{$_};
                ++$cutSats;
            } else {
                push @goodTimes, $_;
            }
        }
        @fixTimes = @goodTimes; # update fix times
        $numPoints -= $cutPDOP;
        $numPoints -= $cutHDOP;
        $numPoints -= $cutSats;
    }
    # sort fixes if necessary
    @fixTimes = sort { $a <=> $b } @fixTimes if $sortFixes;
    # mark first fix of the track
    while (@fixTimes) {
        $fix = $$points{$fixTimes[0]} or shift(@fixTimes), next;
        $$fix{first} = 1;
        last;
    }
    my $verbose = $et->Options('Verbose');
    if ($verbose) {
        my $out = $et->Options('TextOut');
        $format or $format = 'unknown';
        print $out "Loaded $numPoints points from $format-format GPS track log $from\n";
        print $out "Ignored $cutPDOP points due to GeoMaxPDOP cut\n" if $cutPDOP;
        print $out "Ignored $cutHDOP points due to GeoMaxHDOP cut\n" if $cutHDOP;
        print $out "Ignored $cutSats points due to GeoMinSats cut\n" if $cutSats;
        if ($numPoints and $verbose > 1) {
            my @lbl = ('start:', 'end:  ');
            # (fixes may be in reverse order in GPX files)
            @lbl = reverse @lbl if $fixTimes[0] > $fixTimes[-1];
            print $out "  GPS track $lbl[0] " . PrintFixTime($fixTimes[0]) . "\n";
            if ($verbose > 3) {
                print $out PrintFix($points, $_) foreach @fixTimes;
            }
            print $out "  GPS track $lbl[1] " . PrintFixTime($fixTimes[-1]) . "\n";
        }
    }
    if ($numPoints) {
        # reset timestamp list to force it to be regenerated
        delete $$geotag{Times};
        # set flags for available information
        $$has{alt} = 1 if $nmea{GGA} or $nmea{PMGNTRK} or $nmea{B}; # alt
        $$has{track} = 1 if $nmea{RMC};                             # track, speed
        $$has{orient} = 1 if $nmea{PTNTHPR};                        # dir, pitch, roll
        return $geotag;     # success!
    }
    return "No track points found in GPS $from";
}


#------------------------------------------------------------------------------
# Get floating point UTC time
# Inputs: 0) XML time string
# Returns: floating point time or undef on error
sub GetTime($)
{
    my $timeStr = shift;
    $timeStr =~ /^(\d{4})-(\d+)-(\d+)T(\d+):(\d+):(\d+)(\.\d+)?(.*)/ or return undef;
    my $time = Time::Local::timegm($6,$5,$4,$3,$2-1,$1);
    $time += $7 if $7;  # add fractional seconds
    my $tz = $8;
    # adjust for time zone (otherwise assume UTC)
    # - allow timezone of +-HH:MM, +-H:MM, +-HHMM or +-HH since
    #   the spec is unclear about timezone format
    if ($tz =~ /^([-+])(\d+):(\d{2})\b/ or $tz =~ /^([-+])(\d{2})(\d{2})?\b/) {
        $tz = ($2 * 60 + ($3 || 0)) * 60;
        $tz *= -1 if $1 eq '+'; # opposite sign to change back to UTC
        $time += $tz;
    }
    return $time;
}

#------------------------------------------------------------------------------
# Apply Geosync time correction
# Inputs: 0) ExifTool ref, 1) Unix UTC time value
# Returns: sync time difference (and updates input time), or undef if no sync
sub ApplySyncCorr($$)
{
    my ($et, $time) = @_;
    my $sync = $et->GetNewValue('Geosync');
    if (ref $sync eq 'HASH') {
        my $syncTimes = $$sync{Times};
        if ($syncTimes) {
            # find the nearest 2 sync points
            my ($i0, $i1) = (0, scalar(@$syncTimes) - 1);
            while ($i1 > $i0 + 1) {
                my $pt = int(($i0 + $i1) / 2);
                ($time < $$syncTimes[$pt] ? $i1 : $i0) = $pt;
            }
            my ($t0, $t1) = ($$syncTimes[$i0], $$syncTimes[$i1]);
            # interpolate/extrapolate to account for linear camera clock drift
            my $syncPoints = $$sync{Points};
            my $f = $t1 == $t0 ? 0 : ($time - $t0) / ($t1 - $t0);
            $sync = $$syncPoints{$t1} * $f + $$syncPoints{$t0} * (1 - $f);
        } else {
            $sync = $$sync{Offset}; # use fixed time offset
        }
        $_[1] += $sync;
    } else {
        undef $sync;
    }
    return $sync;
}

#------------------------------------------------------------------------------
# Scan outwards for a fix containing the requested parameter
# Inputs: 0) name of fix parameter, 1) reference to list of fix times,
#         2) reference to fix points hash, 3) index of starting time,
#         4) direction to scan (-1 or +1), 5) maximum time difference
# Returns: 0) time for fix containing requested information (or undef)
#          1) the corresponding fix, 2) the value of the requested fix parameter
sub ScanOutwards($$$$$$)
{
    my ($key, $times, $points, $i, $dir, $maxSecs) = @_;
    my $t0 = $$times[$i];
    for (;;) {
        $i += $dir;
        last if $i < 0 or $i >= scalar @$times;
        my $t = $$times[$i];
        last if abs($t - $t0) > $maxSecs;   # don't look too far
        my $p = $$points{$t};
        my $v = $$p{$key};
        return($t,$p,$v) if defined $v;
    }
    return();
}

#------------------------------------------------------------------------------
# Find nearest fix containing the specified parameter
# Inputs: 0) ExifTool ref, 1) name of fix parameter, 2) reference to list of fix times,
#         3) reference to fix points hash, 4) index of starting time,
#         5) direction to scan (-1, +1 or undef), 6) maximum time difference
# Returns: reference to fix hash or undef
sub FindFix($$$$$$$)
{
    my ($et, $key, $times, $points, $i, $dir, $maxSecs) = @_;
    my ($t,$p);
    if ($dir) {
        ($t,$p) = ScanOutwards($key, $times, $points, $i, $dir, $maxSecs);
    } else {
        my ($t1, $p1) = ScanOutwards($key, $times, $points, $i, -1, $maxSecs);
        my ($t2, $p2) = ScanOutwards($key, $times, $points, $i, 1, $maxSecs);
        if (defined $t1) {
            if (defined $t2) {
                # both surrounding points are valid, so take the closest one
                ($t, $p) = ($t - $t1 < $t2 - $t) ? ($t1, $p1) : ($t2, $p2);
            } else {
                ($t, $p) = ($t1, $p1);
            }
        } elsif (defined $t2) {
            ($t, $p) = ($t2, $p2);
        }
    }
    if (defined $p and $$et{OPTIONS}{Verbose} > 2) {
        $et->VPrint(2, "  Taking $key from fix:\n", PrintFix($points, $t))
    }
    return $p;
}

#------------------------------------------------------------------------------
# Set new geotagging values according to date/time
# Inputs: 0) ExifTool object ref, 1) date/time value (or undef to delete tags)
#         2) optional write group
# Returns: error string, or '' on success
# Notes: Uses track data stored in ExifTool NEW_VALUE for Geotag tag
sub SetGeoValues($$;$)
{
    local $_;
    my ($et, $val, $writeGroup) = @_;
    my $geotag = $et->GetNewValue('Geotag');
    my $verbose = $et->Options('Verbose');
    my ($fix, $time, $fsec, $noDate, $secondTry, $iExt, $iDir);

    # remove date if none of our fixes had date information
    $val =~ s/^\S+\s+// if $val and $geotag and not $$geotag{IsDate};

    # maximum time (sec) from nearest GPS fix when position is still considered valid
    my $geoMaxIntSecs = $et->Options('GeoMaxIntSecs');
    my $geoMaxExtSecs = $et->Options('GeoMaxExtSecs');

    # use 30 minutes for a default
    defined $geoMaxIntSecs or $geoMaxIntSecs = 1800;
    defined $geoMaxExtSecs or $geoMaxExtSecs = 1800;

    my $times = $$geotag{Times};
    my $points = $$geotag{Points};
    my $has = $$geotag{Has};
    my $err = '';
    # loop to try date/time value first, then time-only value
    while (defined $val) {
        unless (defined $geotag) {
            $err = 'No GPS track loaded';
            last;
        }
        unless ($times) {
            # generate sorted timestamp list for binary search
            my @times = sort { $a <=> $b } keys %$points;
            $times = $$geotag{Times} = \@times;
        }
        unless ($times and @$times or $$geotag{DateTimeOnly}) {
            $err = 'GPS track is empty';
            last;
        }
        unless (eval { require Time::Local }) {
            $err = 'Geotag feature requires Time::Local installed';
            last;
        }
        # convert date/time to UTC
        my ($year,$mon,$day,$hr,$min,$sec,$fs,$tz,$t0,$t1,$t2);
        if ($val =~ /^(\d{4}):(\d+):(\d+)\s+(\d+):(\d+):(\d+)(\.\d*)?(Z|([-+])(\d+):(\d+))?/) {
            # valid date/time value
            ($year,$mon,$day,$hr,$min,$sec,$fs,$tz,$t0,$t1,$t2) = ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11);
        } elsif ($val =~ /^(\d{2}):(\d+):(\d+)(\.\d*)?(Z|([-+])(\d+):(\d+))?/) {
            # valid time-only value
            ($hr,$min,$sec,$fs,$tz,$t0,$t1,$t2) = ($1,$2,$3,$4,$5,$6,$7,$8);
            # use Jan. 2 to avoid going negative after tz adjustment
            ($year,$mon,$day) = (1970,1,2);
            $noDate = 1;
        } else {
            $err = 'Invalid date/time (use YYYY:mm:dd HH:MM:SS[.ss][+/-HH:MM|Z])';
            last;
        }
        if ($tz) {
            $time = Time::Local::timegm($sec,$min,$hr,$day,$mon-1,$year);
            # use timezone from date/time value
            if ($tz ne 'Z') {
                my $tzmin = $t1 * 60 + $t2;
                $time -= ($t0 eq '-' ? -$tzmin : $tzmin) * 60;
            }
        } else {
            # assume local timezone
            $time = Image::ExifTool::TimeLocal($sec,$min,$hr,$day,$mon-1,$year);
        }
        # add fractional seconds
        $time += $fs if $fs and $fs ne '.';

        # bring UTC time back to Jan. 1 if no date is given
        # (don't use '%' operator here because it drops fractional seconds)
        $time -= int($time / $secPerDay) * $secPerDay if $noDate;

        # apply time synchronization if available
        my $sync = ApplySyncCorr($et, $time);

        # save fractional seconds string
        $fsec = ($time =~ /(\.\d+)$/) ? $1 : '';

        if ($et->Options('Verbose') > 1 and not $secondTry) {
            my $out = $et->Options('TextOut');
            my $str = '';
            $str .= sprintf(" (incl. Geosync offset of %+.3f sec)", $sync) if defined $sync;
            unless ($tz) {
                my $tzs = Image::ExifTool::TimeZoneString([$sec,$min,$hr,$day,$mon-1,$year-1900],$time);
                $str .= " (local timezone is $tzs)";
            }
            print $out '  Geotime value:   ' . PrintFixTime($time) . "$str\n";
        }
        if (not $times or not @$times) {
            $fix = { }; # dummy fix to geotag date/time only
        # interpolate GPS track at $time
        } elsif ($time < $$times[0]) {
            if ($time < $$times[0] - $geoMaxExtSecs) {
                $err or $err = 'Time is too far before track';
                $et->VPrint(2, '  Track start:     ', PrintFixTime($$times[0]), "\n") if $verbose > 2;
                $fix = { } if $$geotag{DateTimeOnly};
            } else {
                $fix = $$points{$$times[0]};
                $iExt = 0;  $iDir = 1;
                $et->VPrint(2, "  Taking pos from fix:\n",
                    PrintFix($points, $$times[0])) if $verbose > 2;
            }
        } elsif ($time > $$times[-1]) {
            if ($time > $$times[-1] + $geoMaxExtSecs) {
                $err or $err = 'Time is too far beyond track';
                $et->VPrint(2, '  Track end:       ', PrintFixTime($$times[-1]), "\n") if $verbose > 2;
                $fix = { } if $$geotag{DateTimeOnly};
            } else {
                $fix = $$points{$$times[-1]};
                $iExt = $#$times;  $iDir = -1;
                $et->VPrint(2, "  Taking pos from fix:\n",
                    PrintFix($points, $$times[-1])) if $verbose > 2;
            }
        } else {
            # find nearest 2 points in time
            my ($i0, $i1) = (0, scalar(@$times) - 1);
            while ($i1 > $i0 + 1) {
                my $pt = int(($i0 + $i1) / 2);
                ($time < $$times[$pt] ? $i1 : $i0) = $pt;
            }
            # do linear interpolation for position
            my $t0 = $$times[$i0];
            my $t1 = $$times[$i1];
            my $p1 = $$points{$t1};
            # check to see if we are extrapolating before the first entry in a track
            my $maxSecs = ($$p1{first} and $geoMaxIntSecs) ? $geoMaxExtSecs : $geoMaxIntSecs;
            # don't interpolate if fixes are too far apart
            # (but always interpolate fixes inside the same TimeSpan)
            if ($t1 - $t0 > $maxSecs and (not $$p1{span} or not $$points{$t0}{span} or
                $$p1{span} != $$points{$t0}{span}))
            {
                # treat as an extrapolation -- use nearest fix if close enough
                my $tn;
                if ($time - $t0 < $t1 - $time) {
                    $tn = $t0;
                    $iExt = $i0;
                } else {
                    $tn = $t1;
                    $iExt = $i1;
                }
                if (abs($time - $tn) > $geoMaxExtSecs) {
                    $err or $err = 'Time is too far from nearest GPS fix'.' '.abs($time-$tn).' > '.$geoMaxExtSecs;
                    $et->VPrint(2, '  Nearest fix:     ', PrintFixTime($tn), "\n") if $verbose > 2;
                    $fix = { } if $$geotag{DateTimeOnly};
                } else {
                    $fix = $$points{$tn};
                    $et->VPrint(2, "  Taking pos from fix:\n",
                        PrintFix($points, $tn)) if $verbose > 2;
                }
            } else {
                my $f0 = $t1 == $t0 ? 0 : ($time - $t0) / ($t1 - $t0);
                my $p0 = $$points{$t0};
                $et->VPrint(2, "  Interpolating between fixes (f=$f0):\n",
                    PrintFix($points, $t0, $t1)) if $verbose > 2;
                $fix = { };
                # loop through available fix information categories
                # (pos, track, alt, orient)
                my ($category, $key);
Category:       foreach $category (qw{pos track alt orient atemp err}) {
                    next unless $$has{$category};
                    my ($f, $p0b, $p1b, $f0b);
                    # loop through specific fix information keys
                    # (lat, lon, alt, track, speed, dir, pitch, roll)
                    foreach $key (@{$fixInfoKeys{$category}}) {
                        my $v0 = $$p0{$key};
                        my $v1 = $$p1{$key};
                        if (defined $v0 and defined $v1) {
                            $f = $f0;
                        } elsif (defined $f0b) {
                            $v0 = $$p0b{$key};
                            $v1 = $$p1b{$key};
                            next unless defined $v0 and defined $v1;
                            $f = $f0b;
                        } else {
                            next if $sepTags{$key}; # (don't scan outwards for some formats, eg. CSV)
                            # scan outwards looking for fixes with the required information
                            # (NOTE: SHOULD EVENTUALLY DO THIS FOR EXTRAPOLATION TOO!)
                            my ($t0b, $t1b);
                            if (defined $v0) {
                                $t0b = $t0;  $p0b = $p0;
                            } else {
                                ($t0b,$p0b,$v0) = ScanOutwards($key,$times,$points,$i0,-1,$maxSecs);
                                next Category unless defined $t0b;
                            }
                            if (defined $v1) {
                                $t1b = $t1;  $p1b = $p1;
                            } else {
                                ($t1b,$p1b,$v1) = ScanOutwards($key,$times,$points,$i1,1,$maxSecs);
                                next Category unless defined $t1b;
                            }
                            # re-calculate the interpolation factor
                            $f = $f0b = $t1b == $t0b ? 0 : ($time - $t0b) / ($t1b - $t0b);
                            $et->VPrint(2, "  Interpolating $category between fixes (f=$f):\n",
                                PrintFix($points, $t0b, $t1b)) if $verbose > 2;
                        }
                        # must interpolate cyclical values differently
                        if ($cyclical{$key} and abs($v1 - $v0) > 180) {
                            # the acute angle spans the discontinuity, so add
                            # 360 degrees to the smaller angle before interpolating
                            $v0 < $v1 ? $v0 += 360 : $v1 += 360;
                            $$fix{$key} = $v1 * $f + $v0 * (1 - $f);
                            # some ranges are -180 to 180, others are 0 to 360
                            my $max = $cyc180{$key} ? 180 : 360;
                            $$fix{$key} -= 360 if $$fix{$key} >= $max;
                        } else {
                            # simple linear interpolation
                            $$fix{$key} = $v1 * $f + $v0 * (1 - $f);
                        }
                    }
                }
            }
        }
        if ($fix) {
            $err = '';  # success!
        } elsif ($$geotag{NoDate} and not $noDate and $val =~ s/^\S+\s+//) {
            # try again with no date since some of our track points are date-less
            $secondTry = 1;
            next;
        }
        last;
    }
    if ($fix) {
        my ($gpsDate, $gpsAlt, $gpsAltRef);
        my @t = gmtime(int $time);
        my $gpsTime = sprintf('%.2d:%.2d:%.2d', $t[2], $t[1], $t[0]) . $fsec;
        # write GPSDateStamp if date included in track log, otherwise delete it
        $gpsDate = sprintf('%.2d:%.2d:%.2d', $t[5]+1900, $t[4]+1, $t[3]) unless $noDate;
        # write GPSAltitude tags if altitude included in track log, otherwise delete them
        my $alt = $$fix{alt};
        if (not defined $alt and $$has{alt} and defined $iExt) {
            my $tFix = FindFix($et,'alt',$times,$points,$iExt,$iDir,$geoMaxExtSecs);
            $alt = $$tFix{alt} if $tFix;
        }
        # set new GPS tag values (EXIF, or XMP if write group is 'xmp')
        my ($xmp, $exif, $qt, @r);
        my %opts = ( Type => 'ValueConv' ); # write ValueConv values
        if ($writeGroup) {
            $opts{Group} = $writeGroup;
            $xmp = ($writeGroup =~ /xmp/i);
            $exif = ($writeGroup =~ /^(exif|gps)$/i);
            $qt = $writeGroup =~ /^(quicktime|keys|itemlist|userdata)$/i;
        }
        # set QuickTime GPSCoordinates
        my $coords = "$$fix{lat} $$fix{lon}";
        if (defined $alt) {
            $gpsAlt = abs $alt;
            $gpsAltRef = ($alt < 0 ? 1 : 0);
            $coords .= " $alt";
        }
        @r = $et->SetNewValue(GPSCoordinates => $coords, %opts);
        # also Geolocate if specified
        my $nvHash;
        my $geoloc = $et->GetNewValue('Geolocate', \$nvHash);
        if ($geoloc and $geoloc =~ /\bgeotag\b/i) {
            my $tag = ($$nvHash{WantGroup} ? "$$nvHash{WantGroup}:" : '') . 'Geolocate';
            # pass along any regular expressions to qualify geolocation search
            my $parms = join ',', grep m(/), split /\s*,\s*/, $geoloc;
            $parms and $parms = ",$parms,both"; 
            $et->SetNewValue($tag => "$$fix{lat},$$fix{lon}$parms");
            # (the Geolocate tag will be restored to its original value
            # by RestoreNewValues before the next file in batch processing)
        }
        return $err if $qt; # all done if writing to QuickTime only
        # (capture error messages by calling SetNewValue in list context)
        @r = $et->SetNewValue(GPSLatitude => $$fix{lat}, %opts);
        @r = $et->SetNewValue(GPSLongitude => $$fix{lon}, %opts);
        @r = $et->SetNewValue(GPSAltitude => $gpsAlt, %opts);
        @r = $et->SetNewValue(GPSAltitudeRef => $gpsAltRef, %opts);
        if ($$has{track} or $$has{speed}) {
            my $type = $$has{track} ? 'track' : 'speed';
            my $tFix = $fix;
            if (not defined $$fix{$type} and defined $iExt) {
                my $p = FindFix($et,$type,$times,$points,$iExt,$iDir,$geoMaxExtSecs);
                $tFix = $p if $p;
            }
            @r = $et->SetNewValue(GPSTrack => $$tFix{track}, %opts);
            @r = $et->SetNewValue(GPSTrackRef => (defined $$tFix{track} ? 'T' : undef), %opts);
            my ($spd, $ref);
            if (defined($spd = $$tFix{speed})) {
                # convert to specified units if necessary
                $ref = $$et{OPTIONS}{GeoSpeedRef};
                if ($ref and defined $speedConv{$ref}) {
                    $ref = $speedConv{$ref} if $speedConv{$speedConv{$ref}};
                    $spd *= $speedConv{$ref};
                } else {
                    $ref = 'N';     # knots by default
                }
            }
            @r = $et->SetNewValue(GPSSpeed => $spd, %opts);
            @r = $et->SetNewValue(GPSSpeedRef => $ref, %opts);
        }
        if ($$has{orient}) {
            my $tFix = $fix;
            if (not defined $$fix{dir} and defined $iExt) {
                my $p = FindFix($et,'dir',$times,$points,$iExt,$iDir,$geoMaxExtSecs);
                $tFix = $p if $p;
            }
            @r = $et->SetNewValue(GPSImgDirection => $$tFix{dir}, %opts);
            @r = $et->SetNewValue(GPSImgDirectionRef => (defined $$tFix{dir} ? 'T' : undef), %opts);
            @r = $et->SetNewValue(CameraElevationAngle => $$tFix{pitch}, %opts);
            # Note: GPSPitch and GPSRoll are non-standard, and must be user-defined
            @r = $et->SetNewValue(GPSPitch => $$tFix{pitch}, %opts);
            @r = $et->SetNewValue(GPSRoll => $$tFix{roll}, %opts);
        }
        if ($$has{atemp}) {
            my $tFix = $fix;
            if (not defined $$fix{atemp} and defined $iExt) {
                # (not all fixes have atemp, so try interpolating specifically for this)
                my $p = FindFix($et,'atemp',$times,$points,$iExt,$iDir,$geoMaxExtSecs);
                $tFix = $p if $p;
            }
            @r = $et->SetNewValue(AmbientTemperature => $$tFix{atemp}, %opts);
        }
        if ($$has{err}) {
            @r = $et->SetNewValue(GPSHPositioningError => $$fix{err}, %opts);
        }
        unless ($xmp) {
            my ($latRef, $lonRef);
            $latRef = ($$fix{lat} > 0 ? 'N' : 'S') if defined $$fix{lat};
            $lonRef = ($$fix{lon} > 0 ? 'E' : 'W') if defined $$fix{lon};
            @r = $et->SetNewValue(GPSLatitudeRef => $latRef, %opts);
            @r = $et->SetNewValue(GPSLongitudeRef => $lonRef, %opts);
            @r = $et->SetNewValue(GPSDateStamp => $gpsDate, %opts);
            @r = $et->SetNewValue(GPSTimeStamp => $gpsTime, %opts);
            # set options to edit XMP:GPSDateTime only if it already exists
            $opts{EditOnly} = 1;
            $opts{Group} = 'XMP';
        }
        unless ($exif) {
            @r = $et->SetNewValue(GPSDateTime => "$gpsDate $gpsTime", %opts);
        }
    } else {
        my %opts = ( IgnorePermanent => 1 );
        $opts{Replace} = 2 if defined $val; # remove existing new values
        $opts{Group} = $writeGroup if $writeGroup;

        # reset any GPS values we might have already set
        foreach (qw(GPSLatitude GPSLatitudeRef GPSLongitude GPSLongitudeRef
                    GPSAltitude GPSAltitudeRef GPSDateStamp GPSTimeStamp GPSDateTime
                    GPSTrack GPSTrackRef GPSSpeed GPSSpeedRef GPSImgDirection
                    GPSImgDirectionRef GPSPitch GPSRoll CameraElevationAngle
                    AmbientTemperature GPSHPositioningError GPSCoordinates))
        {
            my @r = $et->SetNewValue($_, undef, %opts);
        }
    }
    return $err;
}

#------------------------------------------------------------------------------
# Convert Geotagging time synchronization value
# Inputs: 0) exiftool object ref,
#         1) time difference string ("[+-]DD MM:HH:SS.ss"), geosync'd file name,
#            "GPSTIME@IMAGETIME", or "GPSTIME@FILENAME"
# Returns: geosync hash:
#           Offset = Offset in seconds for latest synchronization (GPS - image time)
#           Points = hash of all sync offsets keyed by image times in seconds
#           Times = sorted list of image synchronization times (keys in Points hash)
# Notes: calling this routine with more than one geosync'd file causes time drift
#        correction to be implemented
sub ConvertGeosync($$)
{
    my ($et, $val) = @_;
    my $sync = $et->GetNewValue('Geosync') || { };
    my ($syncFile, $gpsTime, $imgTime);

    if ($val =~ /(.*?)\@(.*)/) {
        $gpsTime = $1;
        (-f $2 ? $syncFile : $imgTime) = $2;
    # (take care because "-f '1:30'" crashes ActivePerl 5.10)
    } elsif ($val !~ /^\d/ or $val !~ /:/) {
        $syncFile = $val if -f $val;
    }
    if ($gpsTime or defined $syncFile) {
        # (this is a time synchronization vector)
        if (defined $syncFile) {
            # check the following tags in order to obtain the image timestamp
            my @timeTags = qw(SubSecDateTimeOriginal SubSecCreateDate SubSecModifyDate
                              DateTimeOriginal CreateDate ModifyDate FileModifyDate);
            my $info = ImageInfo($syncFile, { PrintConv => 0 }, @timeTags,
                                 'GPSDateTime', 'GPSTimeStamp');
            $$info{Error} and warn("$$info{Err}\n"), return undef;
            unless ($gpsTime) {
                $gpsTime = $$info{GPSDateTime} || $$info{GPSTimeStamp};
                $gpsTime .= 'Z' if $gpsTime and not $$info{GPSDateTime};
            }
            $gpsTime or warn("No GPSTimeStamp in '$syncFile\n"), return undef;
            my $tag;
            foreach $tag (@timeTags) {
                if ($$info{$tag}) {
                    $imgTime = $$info{$tag};
                    $et->VPrint(2, "Geosyncing with $tag from '${syncFile}'\n");
                    last;
                }
            }
            $imgTime or warn("No image timestamp in '${syncFile}'\n"), return undef;
        }
        # add date to date-less timestamps
        my ($imgDateTime, $gpsDateTime, $noDate);
        if ($imgTime =~ /^(\d+:\d+:\d+)\s+\d+/) {
            $imgDateTime = $imgTime;
            my $date = $1;
            if ($gpsTime =~ /^\d+:\d+:\d+\s+\d+/) {
                $gpsDateTime = $gpsTime;
            } else {
                $gpsDateTime = "$date $gpsTime";
            }
        } elsif ($gpsTime =~ /^(\d+:\d+:\d+)\s+\d+/) {
            $imgDateTime = "$1 $imgTime";
            $gpsDateTime = $gpsTime;
        } else {
            # use a today's date (so hopefully the DST setting will be intuitive)
            my @tm = localtime;
            my $date = sprintf('%.4d:%.2d:%.2d', $tm[5]+1900, $tm[4]+1, $tm[3]);
            $gpsDateTime = "$date $gpsTime";
            $imgDateTime = "$date $imgTime";
            $noDate = 1;
        }
        # calculate Unix seconds since the epoch
        my $imgSecs = Image::ExifTool::GetUnixTime($imgDateTime, 1);
        defined $imgSecs or warn("Invalid image time '${imgTime}'\n"), return undef;
        my $gpsSecs = Image::ExifTool::GetUnixTime($gpsDateTime, 1);
        defined $gpsSecs or warn("Invalid GPS time '${gpsTime}'\n"), return undef;
        # add fractional seconds
        $gpsSecs += $1 if $gpsTime =~ /(\.\d+)/;
        $imgSecs += $1 if $imgTime =~ /(\.\d+)/;
        # shift dates within 12 hours of each other if either timestamp was date-less
        if ($gpsDateTime ne $gpsTime or $imgDateTime ne $imgTime) {
            my $diff = ($imgSecs - $gpsSecs) % (24 * 3600);
            $diff -= 24 * 3600 if $diff > 12 * 3600;
            $diff += 24 * 3600 if $diff < -12 * 3600;
            if ($gpsDateTime ne $gpsTime) {
                $gpsSecs = $imgSecs - $diff;
            } else {
                $imgSecs = $gpsSecs + $diff;
            }
        }
        # save the synchronization offset
        $$sync{Offset} = $gpsSecs - $imgSecs;
        # save this synchronization point if either timestamp had a date
        unless ($noDate) {
            $$sync{Points} or $$sync{Points} = { };
            $$sync{Points}{$imgSecs} = $$sync{Offset};
            # print verbose output
            if ($et->Options('Verbose') > 1) {
                # print GPS and image timestamps in UTC
                $et->VPrint(1, "Added Geosync point:\n",
                               '  GPS time stamp:  ', PrintFixTime($gpsSecs), "\n",
                               '  Image date/time: ', PrintFixTime($imgSecs), "\n");
            }
            # save sorted list of image sync times if we have more than one
            my @times = keys %{$$sync{Points}};
            if (@times > 1) {
                @times = sort { $a <=> $b } @times;
                $$sync{Times} = \@times;
            }
        }
    } else {
        # (this is a simple time difference)
        my @vals = $val =~ /(?=\d|\.\d)\d*(?:\.\d*)?/g; # (allow decimal values too)
        @vals or warn("Invalid value (please refer to geotag documentation)\n"), return undef;
        my $secs = 0;
        my $mult;
        foreach $mult (1, 60, 3600, $secPerDay) {
            $secs += $mult * pop(@vals);
            last unless @vals;
        }
        # set constant sync offset
        $$sync{Offset} = $val =~ /^\s*-/ ? -$secs : $secs;
    }
    return $sync;
}

#------------------------------------------------------------------------------
# Print fix time
# Inputs: 0) time since the epoch
# Returns: UTC time string with fractional seconds
sub PrintFixTime($)
{
    my $time = $_[0] + 0.0005;  # round off to nearest ms
    my $fsec = int(($time - int($time)) * 1000);
    return sprintf('%s.%.3d UTC', Image::ExifTool::ConvertUnixTime($time), $fsec);
}

#------------------------------------------------------------------------------
# Print fix information
# Inputs: 0) lookup for all fix points, 1-n) list of fix times
# Returns: fix string (including leading indent and trailing newline)
sub PrintFix($@)
{
    local $_;
    my $points = shift;
    my $str = '';
    while (@_) {
        my $time = shift;
        $str .= '    ' . PrintFixTime($time) . ' -';
        my $fix = $$points{$time};
        if ($fix) {
            foreach (sort keys %$fix) {
                $str .= " $_=$$fix{$_}" unless $_ eq 'time' or not defined $$fix{$_};
            }
        }
        $str .= "\n";
    }
    return $str;
}

#------------------------------------------------------------------------------
1;  # end

__END__

=head1 NAME

Image::ExifTool::Geotag - Geotagging utility routines

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module loads GPS track logs, interpolates to determine position based
on time, and sets new GPS values for geotagging images.  Currently supported
formats are GPX, NMEA RMC/GGA/GLL, KML, IGC, Garmin XML and TCX, Magellan
PMGNTRK, Honeywell PTNTHPR, Bramor gEO, Winplus Beacon text, Google Takeout
JSON, GPS/IMU CSV, DJI CSV, ExifTool CSV log files.

Methods in this module should not be called directly.  Instead, the Geotag
feature is accessed by writing the values of the ExifTool Geotag, Geosync
and Geotime tags (see the L<Extra Tags|Image::ExifTool::TagNames/Extra Tags>
in the tag name documentation).

=head1 NOTES

To take advantage of attitude information in the PTNTHPR NMEA sentence, the
user-defined tag GPSRoll, must be active.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.topografix.com/GPX/1/1/>

=item L<http://www.gpsinformation.org/dale/nmea.htm#GSA>

=item L<http://code.google.com/apis/kml/documentation/kmlreference.html>

=item L<http://www.fai.org/gliding/system/files/tech_spec_gnss.pdf>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Lionel Genet for the ability to read IGC format track logs.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Extra Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
