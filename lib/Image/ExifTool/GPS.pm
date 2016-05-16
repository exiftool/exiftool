#------------------------------------------------------------------------------
# File:         GPS.pm
#
# Description:  EXIF GPS meta information tags
#
# Revisions:    12/09/2003  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::GPS;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.45';

my %coordConv = (
    ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val)',
    ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val)',
    PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val)',
);

%Image::ExifTool::GPS::Main = (
    GROUPS => { 0 => 'EXIF', 1 => 'GPS', 2 => 'Location' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    WRITE_GROUP => 'GPS',
    0x0000 => {
        Name => 'GPSVersionID',
        Writable => 'int8u',
        Mandatory => 1,
        Count => 4,
        PrintConv => '$val =~ tr/ /./; $val',
        PrintConvInv => '$val =~ tr/./ /; $val',
    },
    0x0001 => {
        Name => 'GPSLatitudeRef',
        Writable => 'string',
        Notes => q{
            tags 0x0001-0x0006 used for camera location according to MWG 2.0. ExifTool
            will also accept a number when writing GPSLatitude -- positive for north
            latitudes, or negative for south
        },
        Count => 2,
        PrintConv => {
            # extract N/S if written from Composite:GPSLatitude
            # (also allow writing from a signed number)
            OTHER => sub {
                my ($val, $inv) = @_;
                return undef unless $inv;
                return uc $1 if $val =~ /\b([NS])$/i;
                return $1 eq '-' ? 'S' : 'N' if $val =~ /^([-+]?)\d+(\.\d*)?$/;
                return undef;
            },
            N => 'North',
            S => 'South',
        },
    },
    0x0002 => {
        Name => 'GPSLatitude',
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
    },
    0x0003 => {
        Name => 'GPSLongitudeRef',
        Writable => 'string',
        Count => 2,
        Notes => q{
            ExifTool will also accept a number when writing this tag -- positive for
            east longitudes or negative for west
        },
        PrintConv => {
            # extract E/W if written from Composite:GPSLongitude
            # (also allow writing from a signed number)
            OTHER => sub {
                my ($val, $inv) = @_;
                return undef unless $inv;
                return uc $1 if $val =~ /\b([EW])$/i;
                return $1 eq '-' ? 'W' : 'E' if $val =~ /^([-+]?)\d+(\.\d*)?$/;
                return undef;
            },
            E => 'East',
            W => 'West',
        },
    },
    0x0004 => {
        Name => 'GPSLongitude',
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
    },
    0x0005 => {
        Name => 'GPSAltitudeRef',
        Writable => 'int8u',
        Notes => q{
            ExifTool will also accept a signed number when writing this tag, beginning
            with "+" for above sea level, or "-" for below
        },
        PrintConv => {
            OTHER => sub {
                my ($val, $inv) = @_;
                return undef unless $inv and $val =~ /^([-+])/;
                return($1 eq '-' ? 1 : 0);
            },
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    0x0006 => {
        Name => 'GPSAltitude',
        Writable => 'rational64u',
        # extricate unsigned decimal number from string
        ValueConvInv => '$val=~/((?=\d|\.\d)\d*(?:\.\d*)?)/ ? $1 : undef',
        PrintConv => '$val =~ /^(inf|undef)$/ ? $val : "$val m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    0x0007 => {
        Name => 'GPSTimeStamp',
        Groups => { 2 => 'Time' },
        Writable => 'rational64u',
        Count => 3,
        Shift => 'Time',
        Notes => q{
            UTC time of GPS fix.  When writing, date is stripped off if present, and
            time is adjusted to UTC if it includes a timezone
        },
        ValueConv => 'Image::ExifTool::GPS::ConvertTimeStamp($val)',
        ValueConvInv => '$val=~tr/:/ /;$val',
        PrintConv => 'Image::ExifTool::GPS::PrintTimeStamp($val)',
        # pull time out of any format date/time string
        # (converting to UTC if a timezone is given)
        PrintConvInv => sub {
            my $v = shift;
            my @tz;
            if ($v =~ s/([-+])(.*)//s) {    # remove timezone
                my $s = $1 eq '-' ? 1 : -1; # opposite sign to convert back to UTC
                my $t = $2;
                @tz = ($s*$1, $s*$2) if $t =~ /^(\d{2}):?(\d{2})\s*$/;
            }
            my @a = ($v =~ /((?=\d|\.\d)\d*(?:\.\d*)?)/g);
            push @a, '00' while @a < 3;
            if (@tz) {
                # adjust to UTC
                $a[-2] += $tz[1];
                $a[-3] += $tz[0];
                while ($a[-2] >= 60) { $a[-2] -= 60; ++$a[-3] }
                while ($a[-2] < 0)   { $a[-2] += 60; --$a[-3] }
                $a[-3] = ($a[-3] + 24) % 24;
            }
            return "$a[-3]:$a[-2]:$a[-1]";
        },
    },
    0x0008 => {
        Name => 'GPSSatellites',
        Writable => 'string',
    },
    0x0009 => {
        Name => 'GPSStatus',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            A => 'Measurement Active', # Exif2.2 "Measurement in progress"
            V => 'Measurement Void',   # Exif2.2 "Measurement Interoperability" (WTF?)
            # (meaning for 'V' taken from status code in NMEA GLL and RMC sentences)
        },
    },
    0x000a => {
        Name => 'GPSMeasureMode',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0x000b => {
        Name => 'GPSDOP',
        Description => 'GPS Dilution Of Precision',
        Writable => 'rational64u',
    },
    0x000c => {
        Name => 'GPSSpeedRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    0x000d => {
        Name => 'GPSSpeed',
        Writable => 'rational64u',
    },
    0x000e => {
        Name => 'GPSTrackRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x000f => {
        Name => 'GPSTrack',
        Writable => 'rational64u',
    },
    0x0010 => {
        Name => 'GPSImgDirectionRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x0011 => {
        Name => 'GPSImgDirection',
        Writable => 'rational64u',
    },
    0x0012 => {
        Name => 'GPSMapDatum',
        Writable => 'string',
    },
    0x0013 => {
        Name => 'GPSDestLatitudeRef',
        Writable => 'string',
        Notes => 'tags 0x0013-0x001a used for subject location according to MWG 2.0',
        Count => 2,
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x0014 => {
        Name => 'GPSDestLatitude',
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
    },
    0x0015 => {
        Name => 'GPSDestLongitudeRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0x0016 => {
        Name => 'GPSDestLongitude',
        Writable => 'rational64u',
        Count => 3,
        %coordConv,
    },
    0x0017 => {
        Name => 'GPSDestBearingRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x0018 => {
        Name => 'GPSDestBearing',
        Writable => 'rational64u',
    },
    0x0019 => {
        Name => 'GPSDestDistanceRef',
        Writable => 'string',
        Count => 2,
        PrintConv => {
            K => 'Kilometers',
            M => 'Miles',
            N => 'Nautical Miles',
        },
    },
    0x001a => {
        Name => 'GPSDestDistance',
        Writable => 'rational64u',
    },
    0x001b => {
        Name => 'GPSProcessingMethod',
        Writable => 'undef',
        Notes => 'values of "GPS", "CELLID", "WLAN" or "MANUAL" by the EXIF spec.',
        RawConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,1,$tag)',
        RawConvInv => 'Image::ExifTool::Exif::EncodeExifText($self,$val)',
    },
    0x001c => {
        Name => 'GPSAreaInformation',
        Writable => 'undef',
        RawConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,1,$tag)',
        RawConvInv => 'Image::ExifTool::Exif::EncodeExifText($self,$val)',
    },
    0x001d => {
        Name => 'GPSDateStamp',
        Groups => { 2 => 'Time' },
        Writable => 'string',
        Format => 'undef', # (Casio EX-H20G uses "\0" instead of ":" as a separator)
        Count => 11,
        Shift => 'Time',
        Notes => q{
            when writing, time is stripped off if present, after adjusting date/time to
            UTC if time includes a timezone.  Format is YYYY:mm:dd
        },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
        ValueConvInv => '$val',
        # pull date out of any format date/time string
        # (and adjust to UTC if this is a full date/time/timezone value)
        PrintConvInv => q{
            my $secs;
            if ($val =~ /[-+]/ and ($secs = Image::ExifTool::GetUnixTime($val, 1))) {
                $val = Image::ExifTool::ConvertUnixTime($secs);
            }
            return $val =~ /(\d{4}).*?(\d{2}).*?(\d{2})/ ? "$1:$2:$3" : undef;
        },
    },
    0x001e => {
        Name => 'GPSDifferential',
        Writable => 'int16u',
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
    0x001f => {
        Name => 'GPSHPositioningError',
        Description => 'GPS Horizontal Positioning Error',
        PrintConv => '"$val m"',
        PrintConvInv => '$val=~s/\s*m$//; $val',
        Writable => 'rational64u',
    },
    # 0xea1c - Nokia Lumina 1020, Samsung GT-I8750, and other Windows 8
    #          phones write this (padding) in GPS IFD - PH
);

# Composite GPS tags
%Image::ExifTool::GPS::Composite = (
    GROUPS => { 2 => 'Location' },
    GPSDateTime => {
        Description => 'GPS Date/Time',
        Groups => { 2 => 'Time' },
        SubDoc => 1,    # generate for all sub-documents
        Require => {
            0 => 'GPS:GPSDateStamp',
            1 => 'GPS:GPSTimeStamp',
        },
        ValueConv => '"$val[0] $val[1]Z"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # Note: The following tags are used by other modules
    # which must therefore require this module as necessary
    GPSLatitude => {
        SubDoc => 1,    # generate for all sub-documents
        Require => {
            0 => 'GPS:GPSLatitude',
            1 => 'GPS:GPSLatitudeRef',
        },
        ValueConv => '$val[1] =~ /^S/i ? -$val[0] : $val[0]',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    GPSLongitude => {
        SubDoc => 1,    # generate for all sub-documents
        Require => {
            0 => 'GPS:GPSLongitude',
            1 => 'GPS:GPSLongitudeRef',
        },
        ValueConv => '$val[1] =~ /^W/i ? -$val[0] : $val[0]',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    GPSAltitude => {
        SubDoc => 1,    # generate for all sub-documents
        Desire => {
            0 => 'GPS:GPSAltitude',
            1 => 'GPS:GPSAltitudeRef',
            2 => 'XMP:GPSAltitude',
            3 => 'XMP:GPSAltitudeRef',
        },
        # Require either GPS:GPSAltitudeRef or XMP:GPSAltitudeRef
        RawConv => '(defined $val[1] or defined $val[3]) ? $val : undef',
        ValueConv => q{
            my $alt = $val[0];
            $alt = $val[2] unless defined $alt;
            return undef unless defined $alt;
            return ($val[1] || $val[3]) ? -$alt : $alt;
        },
        PrintConv => q{
            $val = int($val * 10) / 10;
            return ($val =~ s/^-// ? "$val m Below" : "$val m Above") . " Sea Level";
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::GPS');

#------------------------------------------------------------------------------
# Convert GPS timestamp value
# Inputs: 0) raw timestamp value string
# Returns: EXIF-formatted time string
sub ConvertTimeStamp($)
{
    my $val = shift;
    my ($h,$m,$s) = split ' ', $val;
    my $f = (($h || 0) * 60 + ($m || 0)) * 60 + ($s || 0);
    $h = int($f / 3600); $f -= $h * 3600;
    $m = int($f / 60);   $f -= $m * 60;
    $s = int($f);        $f -= $s;
    $f = int($f * 1000000000 + 0.5);
    if ($f) {
        ($f = sprintf(".%.9d", $f)) =~ s/0+$//;
    } else {
        $f = ''
    }
    return sprintf("%.2d:%.2d:%.2d%s",$h,$m,$s,$f);
}

#------------------------------------------------------------------------------
# Print GPS timestamp
# Inputs: 0) EXIF-formatted time string
# Returns: time rounded to the nearest microsecond
sub PrintTimeStamp($)
{
    my $val = shift;
    return $val unless $val =~ s/:(\d{2}\.\d+)$//;
    my $s = int($1 * 1000000 + 0.5) / 1000000;
    $s = "0$s" if $s < 10;
    return "${val}:$s";
}

#------------------------------------------------------------------------------
# Convert degrees to DMS, or whatever the current settings are
# Inputs: 0) ExifTool reference, 1) Value in degrees,
#         2) format code (0=no format, 1=CoordFormat, 2=XMP format)
#         3) 'N' or 'E' if sign is significant and N/S/E/W should be added
# Returns: DMS string
sub ToDMS($$;$$)
{
    my ($et, $val, $doPrintConv, $ref) = @_;
    my ($fmt, @fmt, $num, $sign);

    if ($ref) {
        if ($val < 0) {
            $val = -$val;
            $ref = {N => 'S', E => 'W'}->{$ref};
            $sign = '-';
        } else {
            $sign = '+';
        }
        $ref = " $ref" unless $doPrintConv and $doPrintConv eq '2';
    } else {
        $val = abs($val);
        $ref = '';
    }
    if ($doPrintConv) {
        if ($doPrintConv eq '1') {
            $fmt = $et->Options('CoordFormat');
            if (not $fmt) {
                $fmt = q{%d deg %d' %.2f"} . $ref;
            } elsif ($ref) {
                # use signed value instead of reference direction if specified
                $fmt =~ s/%\+/$sign%/g or $fmt .= $ref;
            } else {
                $fmt =~ s/%\+/%/g;  # don't know sign, so don't print it
            }
        } else {
            $fmt = "%d,%.6f$ref";   # use XMP standard format
        }
        # count (and capture) the format specifiers (max 3)
        while ($fmt =~ /(%(%|[^%]*?[diouxXDOUeEfFgGcs]))/g) {
            next if $1 eq '%%';
            push @fmt, $1;
            last if @fmt >= 3;
        }
        $num = scalar @fmt;
    } else {
        $num = 3;
    }
    my @c;  # coordinates (D) or (D,M) or (D,M,S)
    $c[0] = $val;
    if ($num > 1) {
        $c[0] = int($c[0]);
        $c[1] = ($val - $c[0]) * 60;
        if ($num > 2) {
            $c[1] = int($c[1]);
            $c[2] = ($val - $c[0] - $c[1] / 60) * 3600;
        }
        # handle round-off errors to ensure minutes and seconds are
        # less than 60 (eg. convert "72 59 60.00" to "73 0 0.00")
        $c[-1] = $doPrintConv ? sprintf($fmt[-1], $c[-1]) : ($c[-1] . '');
        if ($c[-1] >= 60) {
            $c[-1] -= 60;
            ($c[-2] += 1) >= 60 and $num > 2 and $c[-2] -= 60, $c[-3] += 1;
        }
    }
    return $doPrintConv ? sprintf($fmt, @c) : "@c$ref";
}

#------------------------------------------------------------------------------
# Convert to decimal degrees
# Inputs: 0) a string containing 1-3 decimal numbers and any amount of other garbage
#         1) true if value should be negative if coordinate ends in 'S' or 'W'
# Returns: Coordinate in degrees
sub ToDegrees($;$)
{
    my ($val, $doSign) = @_;
    # extract decimal or floating point values out of any other garbage
    my ($d, $m, $s) = ($val =~ /((?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee][+-]\d+)?)/g);
    my $deg = ($d || 0) + (($m || 0) + ($s || 0)/60) / 60;
    # make negative if S or W coordinate
    $deg = -$deg if $doSign ? $val =~ /[^A-Z](S|W)$/i : $deg < 0;
    return $deg;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::GPS - EXIF GPS meta information tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
GPS (Global Positioning System) meta information in EXIF data.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<Image::Info|Image::Info>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/GPS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::Info(3pm)|Image::Info>

=cut
