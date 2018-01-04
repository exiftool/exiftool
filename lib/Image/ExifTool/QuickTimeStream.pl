#------------------------------------------------------------------------------
# File:         QuickTimeStream.pl
#
# Description:  Extract embedded information from QuickTime video data
#
# Revisions:    2018-01-03 - P. Harvey Created
#
# References:   1) https://github.com/stilldavid/gopro-utils
#               2) http://sergei.nz/files/nvtk_mp42gpx.py
#------------------------------------------------------------------------------
package Image::ExifTool::QuickTime;

use strict;

%Image::ExifTool::QuickTime::Stream = (
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        Tags extracted from QuickTime movie data when the ExtractEmbedded option is
        used.
    },
    GPSLatitude => {
        Groups    => { 2 => 'Location' },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    GPSLongitude => {
        Groups    => { 2 => 'Location' },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    GPSAltitude => {
        Groups    => { 2 => 'Location' },
        PrintConv => '"$val m"',
    },
    GPSAltitudeRef => {
        Groups    => { 2 => 'Location' },
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    GPSSpeed => {
        Groups    => { 2 => 'Location' },
    },
    GPSSpeedRef => {
        Groups    => { 2 => 'Location' },
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    GPSTrack => {
        Groups    => { 2 => 'Location' },
    },
    GPSTrackRef => {
        Groups    => { 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSDateTime => { Groups => { 2 => 'Time' } },
    TimeCode    => { Groups => { 2 => 'Time' } },
    Accelerometer => {
        Notes => 'right/up/backward acceleration in units of g',
        Groups => { 2 => 'Location' },
    },
    Text => {
        Notes => 'text captions extracted from some videos when -ee is used',
        Binary => 1,
    },
);

# GoPro META tags (ref 1)
%Image::ExifTool::QuickTime::GoPro = (
    GROUPS => { 1 => 'GoPro', 2 => 'Video' },
    NOTES => q{
        Tags extracted from compatible GoPro MP4 videos when the ExtractEmbedded
        option is used.
    },
    ACCL => { # accelerometer reading x/y/z
        Name => 'Accelerometer',
        ValueConv => q{
            my @a = split ' ', $val;
            my $scl = $$self{ScaleFactor} ? $$self{ScaleFactor}[0] : 1;
            $_ /= $scl foreach @a;
            return \ join ' ', @a;
        },
    },
    DEVC => 'Device',
    DVID => { Name => 'DeviceID', Unknown => 1 }, # possibly hard-coded to 0x1
    DVNM => { # device name, string "Camera"
        Name => 'Model',
        Description => 'Camera Model Name',
    },
    EMPT => { Name => 'Empty', Unknown => 1 }, # empty packet
    GPS5 => { # GPS data (lat, lon, alt, speed, 3d speed)
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::GoProGPS' },
    },
    GPSF => { # GPS fix (none, 2d, 3d)
        Name => 'GPSMeasureMode',
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    GPSP => { # GPS positional accuracy in cm
        Name => 'GPSHPositioningError',
        Description => 'GPS Horizontal Positioning Error',
        ValueConv => '$val / 100', # convert to m
    },
    GPSU => { # GPS acquired timestamp; potentially different than "camera time"
        Name => 'GPSDateTime',
        Groups => { 2 => 'Time' },
    },
    GYRO => { # gryroscope reading x/y/z
        Name => 'Gyroscope',
        ValueConv => q{
            my @a = split ' ', $val;
            my $scl = $$self{ScaleFactor} ? $$self{ScaleFactor}[0] : 1;
            $_ /= $scl foreach @a;
            return \ join ' ', @a;
        },
    },
    SCAL => { # scale factor, a multiplier for subsequent data
        Name => 'ScaleFactor',
        Unknown => 1,   # (not very useful to user)
    },
    SIUN => { # SI units; strings (m/s2, rad/s)
        Name => 'SIUnits',
    },
    STRM => 'NestedSignalStream',
    STNM => { Name => 'StreamName', Unknown => 1 },
    TMPC => { # temperature
        Name => 'CameraTemperature',
        PrintConv => '"$val C"',
    },
    TSMP => { Name => 'TotalSamples', Unknown => 1 },
    UNIT => { # alternative units; strings (deg, m, m/s));  
        Name => 'Units',
    },
    SHUT => {
        Name => 'ExposureTimes',
        PrintConv => q{
            my @a = split ' ', $val;
            $_ = Image::ExifTool::Exif::PrintExposureTime($_) foreach @a;
            return join ' ', @a;
        },
    },
    ISOG => 'ImageSensorGain',
    TYPE => { Name => 'StructureType', Unknown => 1 },
    RMRK => 'Comments',
    WRGB => { #PH
        Name => 'WhiteBalanceRGB',
        Binary => 1,
    },
    WBAL => 'ColorTemperatures', #PH
    FCNM => 'FaceNumbers', #PH
    ISOE => 'ISOSpeeds', #PH
  # ALLD => 'AutoLowLightDuration', #PH
  # TICK => ?
  # FACE => 'FaceDetected', #PH (need sample for testing)
);

# GoPro GPS tags (ref 1)
%Image::ExifTool::QuickTime::GoProGPS = (
    GROUPS => { 1 => 'GoPro', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32s',
    0 => {
        Name => 'GPSLatitude',
        ValueConv => '$val / ($$self{ScaleFactor} ? $$self{ScaleFactor}[0] : 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    1 => {
        Name => 'GPSLongitude',
        ValueConv => '$val / ($$self{ScaleFactor} ? $$self{ScaleFactor}[1] : 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    2 => {
        Name => 'GPSAltitude',
        ValueConv => '$val / ($$self{ScaleFactor} ? $$self{ScaleFactor}[2] : 1)',
        PrintConv => '"$val m"',
    },
    3 => {
        Name => 'GPSSpeed',
        ValueConv => '$val / ($$self{ScaleFactor} ? $$self{ScaleFactor}[3] : 1)',
    },
    4 => {
        Name => 'GPSSpeed3D',
        ValueConv => '$val / ($$self{ScaleFactor} ? $$self{ScaleFactor}[4] : 1)',
    },
);

#------------------------------------------------------------------------------
# Process GoPro metadata
# Inputs: 0) ExifTool ref, 1) data ref
my %goProFmt = ( # format codes
    0x62 => 'int8s',    # 'b'
    0x42 => 'int8u',    # 'B'
    0x63 => 'undef',    # 'c' (character)
    0x73 => 'int16s',   # 's'
    0x53 => 'int16u',   # 'S'
    0x6c => 'int32s',   # 'l'
    0x4c => 'int32u',   # 'L'
    0x66 => 'float',    # 'f'
    0x64 => 'double',   # 'd'
  # 0x46 => 'undef[4]', # 'F' (4-char ID)
  # 0x47 => 'undef[16]',# 'G' (uuid)
    0x6a => 'int64s',   # 'j'
    0x4a => 'int64u',   # 'J'
    0x71 => 'fixed32s', # 'q'
  # 0x51 => 'fixed64s', # 'Q'
  # 0x55 => 'date',     # 'U' 16-byte
    0x3f => 'undef',    # '?' (complex structure)
);
sub ProcessGoProMET($$)
{
    my ($et, $dataPt) = @_;
    my $dataLen = length $$dataPt;
    my $unk = ($et->Options('Unknown') || $et->Options('Verbose'));
    my $pos = 0;

    my $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::GoPro');

    while ($pos + 8 <= $dataLen) {
        my $tag = substr($$dataPt, $pos, 4);
        my ($fmt,$size,$count) = unpack("x${pos}x4CCn", $$dataPt);
        $pos += 8;
        next if $fmt == 0;
        my $len = $size * $count;
        last if $pos + $len > $dataLen;
        next if $len == 0;  # skip empty tags (for now)
        my $format = $goProFmt{$fmt} || 'undef';
        $format = 'undef' if $tag eq 'GPS5';   # don't reformat GPSInfo
        my $val = ReadValue($dataPt, $pos, $format, undef, $len);
        # save scaling factor
        if ($tag eq 'SCAL') {
            $$et{ScaleFactor} = [ split ' ', $val ] if $tag eq 'SCAL';
        } elsif ($fmt == 0x55) { # date
            $val =~ s/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1:$2:$3 $4:$5:/;
        }
        $pos += (($len + 3) & 0xfffffffc);  # round up to even 4-byte boundary
        if (not $$tagTablePtr{$tag} and $unk) {
            AddTagToTable($tagTablePtr, $tag, { Name => Image::ExifTool::MakeTagName("Unknown_$tag") });
        }
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
}

#------------------------------------------------------------------------------
# Exract embedded metadata from media samples
# Inputs: 0) ExifTool ref, 1) tag table ptr, 2) RAF ref, 3) embedded info
sub ProcessSamples($$$$)
{
    my ($et, $tagTablePtr, $raf, $eeInfo) = @_;
    my ($start, $size, $type, $desc) = @$eeInfo{qw(start size type desc)};
    my ($i, $pos, $buff, %parms, $hdrLen, $hdrFmt);
    my $verbose = $et->Options('Verbose');

    $parms{MaxLen} = $verbose == 3 ? 96 : 2048 if $verbose < 5;

    # get required information from avcC box if parsing video data
    if ($type eq 'vide' and $$eeInfo{avcC}) {
        $hdrLen = (Get8u(\$$eeInfo{avcC}, 4) & 0x03) + 1;
        $hdrFmt = ($hdrLen == 4 ? 'N' : $hdrLen == 2 ? 'n' : 'C');
        require Image::ExifTool::H264;
    }
    # loop through all samples
    for ($i=0; $i<@$start and $i<@$size; ++$i) {
        next unless $raf->Seek($$start[$i], 0) and $raf->Read($buff, $$size[$i]) == $$size[$i];
        if ($type eq 'vide' and defined $hdrLen) {
            next if length($buff) <= $hdrLen;
            # scan through all NAL units and send them to ParseH264Video()
            for ($pos=0; ; ) {
                my $len = unpack("x$pos$hdrFmt", $buff);
                last if $pos + $hdrLen + $len > length($buff);
                my $tmp = "\0\0\0\x01" . substr($buff, $pos+$hdrLen, $len);
                Image::ExifTool::H264::ParseH264Video($et, \$tmp);
                $pos += $hdrLen + $len;
                last if $pos + $hdrLen >= length($buff);
            }
            next;
        }
        if ($verbose > 2) {
            $et->VPrint(2, "Type='$type' Desc='$desc', Sample ".($i+1).' of '.scalar(@$start)."\n");
            $parms{Addr} = $$start[$i];
            HexDump(\$buff, undef, %parms);
        }
        if ($type eq 'text') {
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            unless ($buff =~ /^\$BEGIN/) {
                $et->HandleTag($tagTablePtr, Text => $buff);
                next;
            }
            while ($buff =~ /\$(\w+)([^\$]*)/g) {
                my ($tag, $dat) = ($1, $2);
                if ($tag eq 'GPRMC' and $dat =~ /^,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/) {
                    $et->HandleTag($tagTablePtr, GPSLatitude  => (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1));
                    $et->HandleTag($tagTablePtr, GPSLongitude => (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1));
                    if (length $11) {
                        $et->HandleTag($tagTablePtr, GPSSpeed => $11);
                        $et->HandleTag($tagTablePtr, GPSSpeedRef => 'N');
                    }
                    if (length $12) {
                        $et->HandleTag($tagTablePtr, GPSTrack => $11);
                        $et->HandleTag($tagTablePtr, GPSTrackRef => 'T');
                    }
                    my $year = $15 + ($15 >= 70 ? 1900 : 2000);
                    my $str = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', $year, $14, $13, $1, $2, $3);
                    $et->HandleTag($tagTablePtr, GPSDateTime => $str);
                } elsif ($tag eq 'BEGINGSENSOR' and $dat =~ /^:([-+]\d+\.\d+):([-+]\d+\.\d+):([-+]\d+\.\d+)/) {
                    $et->HandleTag($tagTablePtr, Accelerometer => "$1 $2 $3");
                } elsif ($tag eq 'TIME' and $dat =~ /^:(\d+)/) {
                    $et->HandleTag($tagTablePtr, TimeCode => $1 / 100000);
                } elsif ($tag ne 'BEGIN' and $tag ne 'END') {
                    $et->HandleTag($tagTablePtr, Text => "\$$tag$dat");
                }
            }
        } elsif ($type eq 'meta' and $desc eq 'GoPro MET') {
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            ProcessGoProMET($et, \$buff);
        } elsif ($type eq 'gps ') {
            # decode Novatek GPS data (ref 2)
            next unless $buff =~ /^....freeGPS /s and length $buff >= 92;
            my ($hr,$min,$sec,$yr,$mon,$day,$active,$latRef,$lonRef) = unpack('x48V6a1a1a1', $buff);
            my ($lat,$lon,$spd) = unpack('f3', pack('L3', unpack('x76V3', $buff)));
            next unless $active eq 'A'; # ignore bad GPS fixes
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            # lat/long are in DDDmm.mmmm format
            my $deg = int($lat / 100);
            $lat = $deg + (($lat - $deg * 100) / 60) * ($latRef eq 'S' ? -1 : 1);
            $deg = int($lon / 100);
            $lon = $deg + (($lon - $deg * 100) / 60) * ($lonRef eq 'W' ? -1 : 1);
            $et->HandleTag($tagTablePtr, GPSLatitude => $lat);
            $et->HandleTag($tagTablePtr, GPSLongitude => $lon);
            $et->HandleTag($tagTablePtr, GPSSpeed => $spd);
            $et->HandleTag($tagTablePtr, GPSSpeedRef => 'N');
            $yr += $yr >= 70 ? 1900 : 2000;
            $et->HandleTag($tagTablePtr, GPSDateTime =>
                sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d',$yr,$mon,$day,$hr,$min,$sec));
        }
    }
    $$et{DOC_NUM} = 0;
}

#------------------------------------------------------------------------------
# Extract embedded information from movie data
# Inputs: 0) ExifTool ref, 1) RAF ref
sub ExtractEmbedded($$)
{
    local $_;
    my ($et, $raf) = @_;
    if ($$et{eeInfo}) {
        $et->VPrint(0,"Extract Embedded:\n");
        my $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::Stream');
        ProcessSamples($et, $tagTablePtr, $raf, $_) foreach @{$$et{eeInfo}};
        delete $$et{eeInfo};
    }
}

#------------------------------------------------------------------------------
# Save details about embedded information
# Inputs: 0) ExifTool ref, 1) tag name, 2) data ref, 3) handler type,
#         4) handler description
sub ParseTag($$$$$)
{
    local $_;
    my ($et, $tag, $dataPt, $type, $desc) = @_;
    my ($i, $start, $size);
    my $dataLen = length $$dataPt;

    if ($tag eq 'stco' or $tag eq 'co64' and $dataLen > 8) {
        my $num = unpack('x4N', $$dataPt);
        $start = $$et{eeStart} = [ ];
        $size = $$et{eeSize};
        @$start = ReadValue($dataPt, 8, $tag eq 'stco' ? 'int32u' : 'int64u', $num, $dataLen-8);
    } elsif ($tag eq 'stsz' or $tag eq 'sts2' and $dataLen > 12) {
        my ($sz, $num) = unpack('x4N2', $$dataPt);
        $start = $$et{eeStart};
        $size = $$et{eeSize} = [ ];
        if ($tag eq 'stsz') {
            if ($sz == 0) {
                @$size = ReadValue($dataPt, 12, 'int32u', $num, $dataLen-12);
            } else {
                @$size = ($sz) x $num;
            }
        } else {
            $sz &= 0xff;
            if ($sz == 4) {
                my @tmp = ReadValue($dataPt, 12, "int8u", int(($num+1)/2), $dataLen-12);
                foreach (@tmp) {
                    push @$size, $_ >> 4;
                    push @$size, $_ & 0xff;
                }
            } elsif ($sz == 8 || $sz == 16) {
                @$size = ReadValue($dataPt, 12, "int${sz}u", $num, $dataLen-12);
            }
        }
    } elsif ($tag eq 'avcC') {
        $$et{avcC} = $$dataPt if $dataLen >= 7;  # (minimum length is 7)
    } elsif ($tag eq 'gps ' and $dataLen > 8) {
        # decode Novatek 'gps ' box (ref 2)
        my $num = Get32u($dataPt, 4);
        $num = int(($dataLen - 8) / 8) if $num * 8 + 8 > $dataLen;
        $start = $$et{eeStart} = [ ];
        $size = $$et{eeSize} = [ ];
        for ($i=0; $i<$num; $i+=2) {
            push @$start, Get32u($dataPt, 8 + $i * 8);
            push @$size, Get32u($dataPt, 12 + $i * 8);
        }
        $type = $tag;  # fake type
    }
    if ($start and $size) {
        # save details now that we have both sample sizes and offsets
        my $eeInfo = $$et{eeInfo};
        $eeInfo or $eeInfo = $$et{eeInfo} = [ ];
        push @$eeInfo, {
            type  => $type,
            desc  => $desc,
            start => $start,
            size  => $size,
            avcC  => $$et{avcC},
        };
        delete $$et{eeStart};
        delete $$et{eeSize};
        delete $$et{avcC};
    }
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Extract embedded information from video data

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::QuickTime.

=head1 DESCRIPTION

This file contains routines used by Image::ExifTool to extract embedded
information like GPS tracks from QuickTime and MP4 videos.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://github.com/stilldavid/gopro-utils>

=item L<http://sergei.nz/files/nvtk_mp42gpx.py>

=back

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool::TagNames/QuickTime Stream Tags>,
L<Image::ExifTool::TagNames/QuickTime GoPro Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

