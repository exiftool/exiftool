#------------------------------------------------------------------------------
# File:         GM.pm
#
# Description:  Read GM PDR metadata from automobile videos
#
# Revisions:    2024-04-01 - P. Harvey Created
#
# References:   1) https://exiftool.org/forum/index.php?topic=11335
#------------------------------------------------------------------------------

package Image::ExifTool::GM;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::GPS;

$VERSION = '1.01';

sub Process_marl($$$);
sub Process_mrld($$$);
sub Process_mrlv($$$);
sub PrintCSV($;$);

# rename some units strings
my %convertUnits = (
    "\xc2\xb0" => 'deg',
    "\xc2\xb0C" => 'C',
    "\xc2\xb0/sec" => 'deg/sec',
    ltr => 'L',
);

my $pi = 3.141592653589793;

# offsets and scaling factors to convert to reasonable units
my %changeOffset = (
    C => -273.15,           # K to C
);
my %changeScale = (
    G => 1 / 9.80665,       # m/s2 to G
    kph => 3.6,             # m/s to km/h
    deg => 180 / $pi,       # radians to degrees
    'deg/sec' => 180 / $pi, # rad/s to deg/s
    '%' => 100,             # decimal to %
    kPa => 1/1000,          # Pa to kPa
    rpm => 10,              # ? (arbitrary factor of 10)
    km => 1/1000,           # m to km
    L => 1000,              # m3 to L
    mm => 1000,             # m to mm
);

# default print conversions for various types of units
my %printConv = (
    rpm => 'sprintf("%.2f rpm", $val)',
    '%' => 'sprintf("%.2f %%", $val)',
    kPa => 'sprintf("%.2f kPa", $val)',
    G   => 'sprintf("%.3f G", $val)',
    km  => 'sprintf("%.3f km", $val)',
    kph => 'sprintf("%.2f km/h", $val)',
    deg => 'sprintf("%.2f deg", $val)',
    'deg/sec' => 'sprintf("%.2f deg/sec", $val)',
);

# channel parameters extracted from marl dictionary
my @channel = qw(
    ID Type Num Units Flags Interval Min Max DispMin DispMax Multiplier Offset
    Name Description
);
my %channelStruct = (
    STRUCT_NAME => 'GM Channel',
    NOTES => 'Information stored for each channel in the Marlin dictionary.',
    SORT_ORDER => \@channel,
    ID      => { Writable => 0, Notes => 'channel ID number' },
    Type    => { Writable => 0, Notes => 'measurement type' },
    Num     => { Writable => 0, Notes => 'units ID number' },
    Units   => { Writable => 0, Notes => 'units string' },
    Flags   => { Writable => 0, Notes => 'channel flags' },
    Interval=> { Writable => 0, Notes => 'measurement interval', ValueConv => '$val / 1e7', PrintConv => '"$val s"' },
    Min     => { Writable => 0, Notes => 'raw value minimum' },
    Max     => { Writable => 0, Notes => 'raw value maximum' },
    DispMin => { Writable => 0, Notes => 'displayed value minimum' },
    DispMax => { Writable => 0, Notes => 'displayed value maximum' },
    Multiplier=>{Writable => 0, Notes => 'multiplier for raw value' },
    Offset  => { Writable => 0, Notes => 'offset for scaled value' },
    Name    => { Writable => 0, Notes => 'channel name' },
    Description=>{Writable=> 0, Notes => 'channel description' },
);

# tags found in the 'mrlh' (marl header) atom
%Image::ExifTool::GM::mrlh = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'The Marlin PDR header.',
    0 => { Name => 'MarlinDataVersion', Format => 'int16u[2]', PrintConv => '$val =~ tr/ /./; $val' },
);

# tags found in the 'mrlv' (Marlin values) atom
%Image::ExifTool::GM::mrlv = (
    PROCESS_PROC => \&Process_mrlv,
    FORMAT => 'string',
    NOTES => q{Tags found in the 'mrlv' (Marlin values) box.},
   'time'=> { Name => 'Time1', Groups => { 2 => 'Time' }, ValueConv => '$val =~ tr/-/:/; $val' },
    date => { Name => 'Date1', Groups => { 2 => 'Time' }, ValueConv => '$val =~ tr/-/:/; $val' },
    ltim => { Name => 'Time2', Groups => { 2 => 'Time' }, ValueConv => '$val =~ tr/-/:/; $val' },
    ldat => { Name => 'Date2', Groups => { 2 => 'Time' }, ValueConv => '$val =~ tr/-/:/; $val' },
    tstm => {
        Name => 'StartTime',
        Groups => { 2 => 'Time' },
        Format => 'int64u',
        RawConv => '$$self{GMStartTime} = $val / 1e7',
        ValueConv => 'ConvertUnixTime($val, undef, 6)', # (likely UTC, but not sure so don't add time zone)
        PrintConv => '$self->ConvertDateTime($val)',
    },
    zone => { Name => 'TimeZone', Groups => { 2 => 'Time' } },
    lang => 'Language',
    unit => { Name => 'Units', PrintConv => { usim => 'U.S. Imperial' } },
    swvs => 'SoftwareVersion',
    # id   ? ""
    # cntr ? ""
    # flap ? ""
);

# tags found in the 'mrld' (Marlin dictionary) atom
%Image::ExifTool::GM::mrld = (
    PROCESS_PROC => \&Process_mrld,
    VARS => { ADD_FLATTENED => 1 },
    WRITABLE => 0,
    NOTES => q{
        The Marlin dictionary.  Only one channel is listed but all available
        channels are extracted.  Use the -struct (L<API Struct|../ExifTool.html#Struct>) option to extract the
        channel information as structures.
    },
    Channel01 => { Struct => \%channelStruct },
);

# tags found in 'marl' ctbx timed metadata
%Image::ExifTool::GM::marl = (
    PROCESS_PROC => \&Process_marl,
    GROUPS => { 2 => 'Other' },
    VARS => { ID_FMT => 'none', NO_LOOKUP => 1 },
    NOTES => q{
        Tags extracted from the 'ctbx' 'marl' (Marlin) box of timed PDR metadata
        from GM cars.  Use the -ee (L<API ExtractEmbedded|../ExifTool.html#ExtractEmbedded>) option to extract this
        information, or the L<API PrintCSV|../ExifTool.html#PrintCSV> option to output in CSV format.
    },
    TimeStamp => { # (the marl timestamp)
        Groups => { 2 => 'Time' },
        Notes => q{
            the numerical value is seconds since start of video, but the print
            conversion adds StartTime to provide a date/time value.  Extracted as
            GPSDateTime if requested
        },
        ValueConv => '$val / 1e7',
        PrintConv => q{
            return "$val s" unless $$self{GMStartTime};
            return $self->ConvertDateTime(ConvertUnixTime($val+$$self{GMStartTime},undef,6));
        },
    },
    GPSDateTime => { # (alternative for TimeStamp)
        Groups => { 2 => 'Time' },
        Notes => 'generated from the TimeStamp only if specifically requested',
        RawConv => '$$self{GMStartTime} ? $val : undef',
        ValueConv => 'ConvertUnixTime($val / 1e7 + $$self{GMStartTime}) . "Z"',
        PrintConv => '$self->ConvertDateTime($val,undef,6)',
    },
    Latitude => {
        Name => 'GPSLatitude',
        Description => 'GPS Latitude', # (need description so we don't set it from the mrld)
        Groups => { 2 => 'Location' },
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    Longitude => {
        Name => 'GPSLongitude',
        Description => 'GPS Longitude',
        Groups => { 2 => 'Location' },
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    Altitude => {
        Name => 'GPSAltitude',
        Description => 'GPS Altitude',
        Groups => { 2 => 'Location' },
    },
    Heading => {
        Name => 'GPSTrack',
        Description => 'GPS Track',
        Groups => { 2 => 'Location' },
        PrintConv => '$val > 360 ? "n/a" : sprintf("%.2f",$val)', # (seen 655.35)
    },
    ABSActive => { },
    AccelPos => { },
    BatteryVoltage => { },
    Beacon => { },
    BoostPressureInd => { },
    BrakePos => { },
    ClutchPos => { },
    CoolantTemp => { },
    CornerExitSetting => { },
    CPUFree => { },
    CPUIO => { },
    CPUIRQ => { },
    CPUSystem => { },
    CPUUser => { },
    DiskReadOperations => { },
    DiskReadRate => { },
    DiskReadTime => { },
    DiskWriteOperations => { },
    DiskWriteRate => { },
    DiskWriteTime => { },
    Distance => { },
    DriverPerformanceMode => { },
    EngineSpeedRequest => { },
    EngineTorqureReq => { },
    FuelCapacity => { },
    FuelLevel => { },
    Gear => {
        Notes => q{
            in the PrintCSV output, the value for Neutral is set to -1, and Reverse to
            -100 for compatibility with RaceRender
        },
        CSVConv => { 13 => -1, 14 => -100 },
        PrintConv => { 1=>1, 2=>2, 3=>3, 4=>4, 5=>5, 6=>6, 13=>'N', 14=>'R' }
    },
    GPSFix => { },
    InfotainOpMode => { },
    IntakeAirTemperature => { },
    IntakeBoostPressure => { },
    LateralAcceleration => { },
    LFTyrePressure => { },
    LFTyreTemp => { },
    LongitudinalAcceleration => { },
    LRTyrePressure => { },
    LRTyreTemp => { },
    OilPressure => { },
    OilTemp => { },
    OutsideAirTemperature => { },
    RecordingEventOdometer => { },
    RFTyrePressure => { },
    RFTyreTemp => { },
    RPM => { },
    RRTyrePressure => { },
    RRTyreTemp => { },
    Speed => { Groups => { 2 => 'Location' } },
    SpeedControlResponse => { },
    SpeedRequestIntervention => { },
    Steering1Switch => { },
    Steering2Switch => { },
    SteeringAngle => { },
    SuspensionDisplacementLeftFront => { },
    SuspensionDisplacementLeftRear => { },
    SuspensionDisplacementRightFront => { },
    SuspensionDisplacementRightRear => { },
    SystemBackupPowerEnabled => { },
    SystemBackupPowerMode => { },
    SystemPowerMode => { },
    TractionControlActive => { },
    TransOilTemp => { },
    TransportStorageMode => { },
    ValetMode => { },
    VehicleStabilityActive => { },
    VerticalAcceleration => { },
    WheelspeedLeftDriven => { },
   'WheelspeedLeftNon-Driven' => { },
    WheelspeedRightDriven => { },
   'WheelspeedRightNon-Driven' => { },
    YawRate => { },
);

#------------------------------------------------------------------------------
# Print a CSV row
# Inputs: 0) ExifTool ref, 1) time stamp
sub PrintCSV($;$)
{
    my ($et, $ts) = @_;
    my $csv = $$et{GMCsv} or return; # get the list of channels with measurements
    @$csv or return;
    my $vals = $$et{GMVals};
    my $gmDict = $$et{GMDictionary};
    my @items = ('') x scalar(@$gmDict);
    $items[0] = ($ts || $$et{GMMaxTS}) / 1e7;
    # fill in scaled measurements for this TimeStamp
    foreach (@$csv) {
        my $gmChan = $$gmDict[$_];
        $items[$_] = $$vals[$_] * $$gmChan{Mult} + $$gmChan{Off};
        # apply CSV conversion if applicable (ie. Gear)
        next unless $$gmChan{Conv} and defined $$gmChan{Conv}{$items[$_]};
        $items[$_] = $$gmChan{Conv}{$items[$_]};
    }
    my $out = $$et{OPTIONS}{TextOut};
    print $out join(',',@items),"\n";
    @$csv = (); # clear the channel list
}

#------------------------------------------------------------------------------
# Process GM Marlin values ('mrlv' box)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_mrlv($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen = length $$dataPt;
    my $pos = 0;
    # data lengths for known formats
    my %fmtLen = (
        strs => 64, lang => 64, strl => 256, 'time' => 32, date => 32,
        tmzn => 32, tstm => 8, focc => 4, "kvp\0" => 64+256,
    );
    $et->VerboseDir('mrlv', undef, $dirLen);
    while ($pos + 8 <= $dirLen) {
        my $tag = substr($$dataPt, $pos, 4);
        my $fmt = substr($$dataPt, $pos + 4, 4);
        my $len = $fmtLen{$fmt};
        unless ($len) {
            ($tag, $fmt) = (PrintableTagID($tag), PrintableTagID($fmt));
            $et->Warn("Unknown format ($fmt) for tag $tag");
            last;
        }
        $pos + 8 + $len > $dirLen and $et->Warn('Truncated mrlv data'), last;
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $pos + 8,
            Size    => $len,
        );
        $pos += 8 + $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process GM Marlin dictionary ('mrld' box)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_mrld($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen = length $$dataPt;
    my $struct = $et->Options('Struct') || 0;
    my $gmDict = $$et{GMDictionary} = [ ];
    my $marl = GetTagTable('Image::ExifTool::GM::marl');
    my ($pos, $item, $csv);

    $et->VerboseDir('mrld', undef, $dirLen);
    require 'Image/ExifTool/XMPStruct.pl';
    Image::ExifTool::XMP::AddFlattenedTags($tagTablePtr);
    $csv = [ ] if $et->Options('PrintCSV');

    for ($pos=0; $pos+448<=$dirLen; $pos+=448) {
        # unpack 448-byte records:
        # 0. int32u - channel number
        # 1. int32u - measurement type
        # 2. int32u - units number
        # 3. string[64] - units string
        # 4. int32u - flags (0.visible, 1.linear conversion, 2.interpolation OK)
        # 5. int64u - interval
        # 6. int32s - min reading
        # 7. int32s - max reading
        # 8. double - disp min
        # 9. double - disp max
        # 10. double - multiplier
        # 11. double - offset
        # 12. string[64] - channel name
        # 13. string[64] - channel description
        my @a = unpack("x${pos}NNNZ64Na8N2a8a8a8a8Z64Z64", $$dataPt);
        my $units = $convertUnits{$a[3]} || $a[3];
        $a[3] = $et->Decode($a[3], 'UTF8');                  # convert from UTF8
        $_ & 0x8000000 and $_ -= 4294967296 foreach @a[6,7]; # convert signed ints
        map { $_ = GetDouble(\$_,0) } @a[8,9,10,11];         # convert doubles
        $a[5] = Get64u(\$a[5],0);                            # convert 64-bit int
        my $chan = $a[0];
        my $tag = sprintf('Channel%.2d', $chan);
        my $tagInfo = $$tagTablePtr{$tag};
        my $hash = { map { $channel[$_] => $a[$_] } 1..$#a };
        unless ($tagInfo) {
            $tagInfo = AddTagToTable($tagTablePtr, $tag, { Name => $tag, Struct => \%channelStruct });
            Image::ExifTool::XMP::AddFlattenedTags($tagTablePtr, $tag);
        }
        # extract channel structure if specified
        if ($struct) {
            $$hash{_ordered_keys_} = [ @channel[1..$#channel] ];
            $et->FoundTag($tagInfo, $hash);
        }
        # extract flattened channel elements
        if ($struct == 0 or $struct == 2) {
            $et->HandleTag($tagTablePtr, "$tag$channel[$_]", $a[$_]) foreach 1..$#a;
        }
        # add corresponding tag to marl table
        my $name = Image::ExifTool::MakeTagName($a[12]);
        $tagInfo = $$marl{$name};
        unless ($tagInfo) {
            $et->VPrint(0, $$et{INDENT}, "[adding $name]\n");
            $tagInfo = AddTagToTable($marl, $name, { });
        }
        $$tagInfo{Description} = $a[13] unless $$tagInfo{Description};
        unless ($$tagInfo{PrintConv}) {
            # add a default print conversion
            $units =~ tr/"\\//d; # (just to be safe, probably never happen)
            $$tagInfo{PrintConv} = $printConv{$units} || qq("\$val $units");
        }
        # adjust multiplier/offset as necessary to scale to more appropriate units
        # (ie. to the units actually specified in this dictionary -- d'oh)
        my $mult = $a[10] * ($changeScale{$units} || 1);
        my $off =  $a[11] * ($changeScale{$units} || 1) + ($changeOffset{$units} || 0);
        my $init = int(($a[6] + $a[7]) / 2); # initial value for difference readings
        # save information about this channel necessary for processing the marl data
        $$gmDict[$chan] = { Name => $name, Mult => $mult, Off => $off, Init => $init };
        $$gmDict[$chan]{Conv} = $$tagInfo{CSVConv};
        $csv and $$csv[$chan] = $a[12] . ($a[3] ? " ($a[3])" : '');
    }
    # channel 0 must not be defined because we use it for the TimeStamp
    if (defined $$gmDict[0]) {
        $et->Warn('Internal error: PDR channel 0 is used');
        delete $$et{GMDictionary};
    } elsif ($csv) {
        $$csv[0] = 'Time (s)';
        defined $_ or $_ = '' foreach @$csv;
        my $out = $$et{OPTIONS}{TextOut};
        print $out join(',',@$csv),"\n";
        $$et{GMCsv} = [ ];
    }
    $et->AddCleanup(\&PrintCSV); # print last CSV line when we are done
    # initialize variables for processing marl box
    $$et{GMVals} = [ ];
    $$et{GMMaxTS} = 0;
    $$et{GMBadChan} = 0;
    return 1;
}

#------------------------------------------------------------------------------
# Process GM 'marl' ctbx data (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (see https://exiftool.org/forum/index.php?topic=11335.msg61393#msg61393)
sub Process_marl($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = ($$dirInfo{DataPos} || 0) + ($$dirInfo{Base} || 0);
    my $dataLen = length $$dataPt;
    my $vals = $$et{GMVals}; # running values for each channel (0=TimeStamp)
    my $chan = $$et{GMChan}; # running channel number
    my $gmDict = $$et{GMDictionary};
    my $csv = $$et{GMCsv};
    my $maxTS = $$et{GMMaxTS};
    my $reqGPSDateTime = $$et{REQ_TAG_LOOKUP}{gpsdatetime};
    my $reqTimeStamp = $reqGPSDateTime ? $$et{REQ_TAG_LOOKUP}{timestamp} : 1;
    my ($pos, $verbose2);

    $et->VerboseDir('marl', undef, $dataLen);
    $gmDict or $et->Warn('Missing marl dictionary'), return 0;
    my $maxChan = $#$gmDict;
    $verbose2 = 1 if $et->Options('Verbose') > 1;
    $$vals[0] = -1 unless defined $$vals[0];    # (we use the 0th channel for the TimeStamp)
    my $ts = $$vals[0];

    for ($pos=0; $pos + 8 <= $dataLen; $pos += 8) {
        my @a = unpack("x${pos}NN", $$dataPt);
        my $ah = $a[0] >> 24;
        my $a2 = $ah & 0xc0;
        my ($val, $chanDiff, $valDiff, @ts, $gmChan);
        if ($a2 == 0xc0) {          # 16-byte full record?
            last if $ah == 0xff;    # exit at first empty record
            $chan = $a[0] & 0x0fffffff;
            $gmChan = $$gmDict[$chan] or next;  # (shouldn't happen)
            $val = $a[1] - ($a[1] & 0x80000000 ? 4294967296 : 0);
            $$vals[$chan] = $val;
            last if $pos + 16 > $dataLen;       # (shouldn't happen)
            $pos += 8;                          # point at time stamp
            @ts = unpack("x${pos}NN", $$dataPt);
            $ts = $ts[0] * 4294967296 + $ts[1];
        } elsif ($a2 == 0x40) {     # 8-byte difference record?
            next unless defined $chan;          # (shouldn't happen)
            $ts += $a[1];                       # increment time stamp
            $chanDiff = ($ah & 0x3f) - ($ah & 0x20 ? 0x40 : 0);
            $chan += $chanDiff;                 # increment the running channel number
            $gmChan = $$gmDict[$chan] or next;  # (shouldn't happen)
            defined $$vals[$chan] or $$vals[$chan] = $$gmChan{Init}; # init if necessary
            $valDiff = ($a[0] & 0x00ffffff) - ($a[0] & 0x00800000 ? 0x01000000 : 0);
            $val = ($$vals[$chan] += $valDiff); # increment the running value for this channel
        } else {
            next;   # (shouldn't happen)
        }
        # ensure that the timestamps are monotonically increasing
        # (have seen backward steps up to 0.033 sec, so fudge these)
        if ($ts > $maxTS) {
            if ($csv) {
                PrintCSV($et, $maxTS);
            } else {
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                $et->HandleTag($tagTablePtr, TimeStamp => $ts) if $reqTimeStamp;
                $et->HandleTag($tagTablePtr, GPSDateTime => $ts) if $reqGPSDateTime;
            }
            $maxTS = $ts;
        }
        $csv and push(@$csv, $chan), next;
        my $scaled = $val * $$gmChan{Mult} + $$gmChan{Off};
        $et->HandleTag($tagTablePtr, $$gmChan{Name}, $scaled);
        if ($verbose2) {
            my $str = " * $$gmChan{Mult} + $$gmChan{Off} = $scaled";
            my $p0 = $dataPos + $pos - ($a2 == 0xc0 ? 8 : 0);
            my ($cd,$vd) = @ts ? ('','') : (sprintf('%+d',$chanDiff),sprintf('%+d',$valDiff));
            printf "| %8.4x: %.8x %.8x chan$cd=%.2d $$gmChan{Name}$vd = $val$str\n", $p0, @a, $chan;
            printf("| %8.4x: %.8x %.8x         TimeStamp = %.6f sec\n", $dataPos + $pos, @ts, $ts / 1e7) if @ts;
        }
    }
    $$vals[0] = $ts;        # save last timestamp
    $$et{GMChan} = $chan;   # save last channel number
    $$et{GMMaxTS} = $ts;
    delete $$et{DOC_NUM};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::GM - Read GM PDR Data from automobile videos

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read PDR
metadata from videos written by some GM models such as Corvette and Camero.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://exiftool.org/forum/index.php?topic=11335>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/GM Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
