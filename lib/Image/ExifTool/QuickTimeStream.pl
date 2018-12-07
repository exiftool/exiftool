#------------------------------------------------------------------------------
# File:         QuickTimeStream.pl
#
# Description:  Extract embedded information from QuickTime movie data
#
# Revisions:    2018-01-03 - P. Harvey Created
#
# References:   1) https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW130
#               2) http://sergei.nz/files/nvtk_mp42gpx.py
#               3) https://forum.flitsservice.nl/dashcam-info/dod-ls460w-gps-data-uit-mov-bestand-lezen-t87926.html
#               4) https://developers.google.com/streetview/publish/camm-spec
#               5) https://sergei.nz/extracting-gps-data-from-viofo-a119-and-other-novatek-powered-cameras/
#------------------------------------------------------------------------------
package Image::ExifTool::QuickTime;

use strict;

sub Process_tx3g($$$);
sub ProcessFreeGPS($$$);
sub ProcessFreeGPS2($$$);

# QuickTime data types that have ExifTool equivalents
# (ref https://developer.apple.com/library/content/documentation/QuickTime/QTFF/Metadata/Metadata.html#//apple_ref/doc/uid/TP40000939-CH1-SW35)
my %qtFmt = (
    0 => 'undef',
    1 => 'string', # (UTF-8)
    # 2 - UTF-16
    # 3 - shift-JIS
    # 4 - UTF-8 sort
    # 5 - UTF-16 sort
    # 13 - JPEG image
    # 14 - PNG image
    # 21 - signed integer (1,2,3 or 4 bytes)
    # 22 - unsigned integer (1,2,3 or 4 bytes)
    23 => 'float',
    24 => 'double',
    # 27 - BMP image
    # 28 - QuickTime atom
    65 => 'int8s',
    66 => 'int16s',
    67 => 'int32s',
    70 => 'float', # float[2] x,y
    71 => 'float', # float[2] width,height
    72 => 'float', # float[4] x,y,width,height
    74 => 'int64s',
    75 => 'int8u',
    76 => 'int16u',
    77 => 'int32u',
    78 => 'int64u',
    79 => 'float', # float[9] transform matrix
    80 => 'float', # float[8] face coordinates
);

# maximums for validating H,M,S,d,m,Y from "freeGPS " metadata
my @dateMax = ( 24, 59, 59, 2200, 12, 31 );

# typical (minimum?) size of freeGPS block
my $gpsBlockSize = 0x8000;

# conversion factors
my $knotsToKph = 1.852; # knots --> km/h
my $mpsToKph   = 3.6;   # m/s   --> km/h

# handler types to process based on MetaFormat/OtherFormat
my %processByMetaFormat = (
    meta => 1,  # ('CTMD' in CR3 images, 'priv' unknown in DJI video)
    data => 1,  # ('RVMI')
    sbtl => 1,  # (subtitle; 'tx3g' in Yuneec drone videos)
);

# tags extracted from various QuickTime data streams
%Image::ExifTool::QuickTime::Stream = (
    GROUPS => { 2 => 'Location' },
    NOTES => q{
        Timed metadata extracted from QuickTime movie data and some AVI videos when
        the ExtractEmbedded option is used.
    },
    VARS => { NO_ID => 1 },
    GPSLatitude  => { PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")' },
    GPSLongitude => { PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")' },
    GPSAltitude  => { PrintConv => '(sprintf("%.4f", $val) + 0) . " m"' }, # round to 4 decimals
    GPSSpeed     => { PrintConv => 'sprintf("%.4f", $val) + 0' },   # round to 4 decimals
    GPSSpeedRef  => { PrintConv => { K => 'km/h', M => 'mph', N => 'knots' } },
    GPSTrack     => { PrintConv => 'sprintf("%.4f", $val) + 0' },    # round to 4 decimals
    GPSTrackRef  => { PrintConv => { M => 'Magnetic North', T => 'True North' } },
    GPSDateTime  => { PrintConv => '$self->ConvertDateTime($val)', Groups => { 2 => 'Time' } },
    GPSTimeStamp => { PrintConv => 'Image::ExifTool::GPS::PrintTimeStamp($val)', Groups => { 2 => 'Time' } },
    GPSSatellites=> { },
    GPSDOP       => { Description => 'GPS Dilution Of Precision' },
    CameraDateTime=>{ PrintConv => '$self->ConvertDateTime($val)', Groups => { 2 => 'Time' } },
    Accelerometer=> { Notes => 'right/up/backward acceleration in units of g' },
    RawGSensor    => {
        # (same as GSensor, but offset by some unknown value)
        ValueConv => 'my @a=split " ",$val; $_/=1000 foreach @a; "@a"',
    },
    Text         => { Groups => { 2 => 'Other' } },
    TimeCode     => { Groups => { 2 => 'Video' } },
    FrameNumber  => { Groups => { 2 => 'Video' } },
    SampleTime   => { Groups => { 2 => 'Video' }, PrintConv => 'ConvertDuration($val)', Notes => 'sample decoding time' },
    SampleDuration=>{ Groups => { 2 => 'Video' }, PrintConv => 'ConvertDuration($val)' },
    UserLabel    => { Groups => { 2 => 'Other' } },
#
# timed metadata decoded based on MetaFormat (format of 'meta' or 'data' sample description)
# [or HandlerType, or specific 'vide' type if specified]
#
    mebx => {
        Name => 'mebx',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Keys',
            ProcessProc => \&Process_mebx,
        },
    },
    gpmd => {
        Name => 'gpmd',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
    },
    fdsc => {
        Name => 'fdsc',
        Condition => '$$valPt =~ /^GPRO/',
        # (other types of "fdsc" samples aren't yet parsed: /^GP\x00/ and /^GP\x04/)
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::fdsc' },
    },
    rtmd => {
        Name => 'rtmd',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::rtmd' },
    },
    CTMD => { # (Canon Timed MetaData)
        Name => 'CTMD',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CTMD' },
    },
    tx3g => {
        Name => 'tx3g',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::tx3g' },
    },
    RVMI => [{ # data "OtherFormat" written by unknown software
        Name => 'RVMI_gReV',
        Condition => '$$valPt =~ /^gReV/',  # GPS data
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::RVMI_gReV',
            ByteOrder => 'Little-endian',
        },
    },{
        Name => 'RVMI_sReV',
        Condition => '$$valPt =~ /^sReV/',  # sensor data
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::RVMI_sReV',
            ByteOrder => 'Little-endian',
        },
    # (there is also "tReV" data that hasn't been decoded yet)
    }],
    camm => [{
        Name => 'camm0',
        Condition => '$$valPt =~ /^\0\0\0\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm0',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm1',
        Condition => '$$valPt =~ /^\0\0\x01\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm1',
            ByteOrder => 'Little-Endian',
        },
    },{ # (written by Insta360) - [HandlerType, not MetaFormat]
        Name => 'camm2',
        Condition => '$$valPt =~ /^\0\0\x02\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm2',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm3',
        Condition => '$$valPt =~ /^\0\0\x03\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm3',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm4',
        Condition => '$$valPt =~ /^\0\0\x04\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm4',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm5',
        Condition => '$$valPt =~ /^\0\0\x05\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm5',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm6',
        Condition => '$$valPt =~ /^\0\0\x06\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm6',
            ByteOrder => 'Little-Endian',
        },
    },{
        Name => 'camm7',
        Condition => '$$valPt =~ /^\0\0\x07\0/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::camm7',
            ByteOrder => 'Little-Endian',
        },
    },],
    JPEG => { # (in CR3 images) - [vide HandlerType with JPEG in SampleDescription, not MetaFormat]
        Name => 'JpgFromRaw',
        Groups => { 2 => 'Preview' },
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# tags found in 'camm' type 0 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm0 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => q{
        The camm0 through camm7 tables define tags extracted from the Google Street
        View Camera Motion Metadata of MP4 videos.  See
        L<https://developers.google.com/streetview/publish/camm-spec> for the
        specification.
    },
    4 => {
        Name => 'AngleAxis',
        Notes => 'angle axis orientation in radians in local coordinate system',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 1 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Camera' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'PixelExposureTime',
        Format => 'int32s',
        ValueConv => '$val * 1e-9',
        PrintConv => 'sprintf("%.4g ms", $val * 1000)',
    },
    8 => {
        Name => 'RollingShutterSkewTime',
        Format => 'int32s',
        ValueConv => '$val * 1e-9',
        PrintConv => 'sprintf("%.4g ms", $val * 1000)',
    },
);

# tags found in 'camm' type 2 timed metadata (ref PH, Insta360Pro)
%Image::ExifTool::QuickTime::camm2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'AngularVelocity',
        Notes => 'gyro angular velocity about X, Y and Z axes in rad/s',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 3 timed metadata (ref PH, Insta360Pro)
%Image::ExifTool::QuickTime::camm3 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'Acceleration',
        Notes => 'acceleration in the X, Y and Z directions in m/s^2',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 4 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'Position',
        Notes => 'X, Y, Z position in local coordinate system',
        Format => 'float[3]',
    },
);

# tags found in 'camm' type 5 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm5 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'GPSLatitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    12 => {
        Name => 'GPSLongitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    20 => {
        Name => 'GPSAltitude',
        Format => 'double',
        PrintConv => '$_ = sprintf("%.6f", $val); s/\.?0+$//; "$_ m"',
    },
);

# tags found in 'camm' type 6 timed metadata (ref PH/4, Insta360)
%Image::ExifTool::QuickTime::camm6 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    0x04 => {
        Name => 'GPSDateTime',
        Groups => { 2 => 'Time' },
        Format => 'double',
        ValueConv => q{
            my $str = ConvertUnixTime($val);
            my $frac = $val - int($val);
            if ($frac != 0) {
                $frac = sprintf('%.6f', $frac);
                $frac =~ s/^0//;
                $frac =~ s/0+$//;
                $str .= $frac;
            }
            return $str . 'Z';
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x0c => {
        Name => 'GPSMeasureMode',
        Format => 'int32u',
        PrintConv => {
            0 => 'No Measurement',
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0x10 => {
        Name => 'GPSLatitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    0x18 => {
        Name => 'GPSLongitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    0x20 => {
        Name => 'GPSAltitude',
        Format => 'float',
        PrintConv => '$_ = sprintf("%.3f", $val); s/\.?0+$//; "$_ m"',
    },
    0x24 => { Name => 'GPSHorizontalAccuracy', Format => 'float', Notes => 'metres' },
    0x28 => { Name => 'GPSVerticalAccuracy',   Format => 'float' },
    0x2c => { Name => 'GPSVelocityEast',       Format => 'float', Notes => 'm/s' },
    0x30 => { Name => 'GPSVelocityNorth',      Format => 'float' },
    0x34 => { Name => 'GPSVelocityUp',         Format => 'float' },
    0x38 => { Name => 'GPSSpeedAccuracy',      Format => 'float' },
);

# tags found in 'camm' type 7 timed metadata (ref 4)
%Image::ExifTool::QuickTime::camm7 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    4 => {
        Name => 'MagneticField',
        Format => 'float[3]',
        Notes => 'microtesla',
    },
);

# tags found in 'RVMI' 'gReV' timed metadata (ref PH)
%Image::ExifTool::QuickTime::RVMI_gReV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => q{
        GPS information extracted from the RVMI box of MOV videos.
    },
    4 => {
        Name => 'GPSLatitude',
        Format => 'int32s',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val/1e6, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    8 => {
        Name => 'GPSLongitude',
        Format => 'int32s',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val/1e6, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    # 12 - int32s: space for altitude? (always zero in my sample)
    16 => {
        Name => 'GPSSpeed', # km/h
        Format => 'int16s',
        ValueConv => '$val / 10',
    },
    18 => {
        Name => 'GPSTrack',
        Format => 'int16u',
        ValueConv => '$val * 2',
    },
);

# tags found in 'RVMI' 'sReV' timed metadata (ref PH)
%Image::ExifTool::QuickTime::RVMI_sReV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => q{
        G-sensor information extracted from the RVMI box of MOV videos.
    },
    4 => {
        Name => 'GSensor',
        Format => 'int16s[3]', # X Y Z
        ValueConv => 'my @a=split " ",$val; $_/=1000 foreach @a; "@a"',
    },
);

# tags found in 'tx3g' sbtl timed metadata (ref PH)
%Image::ExifTool::QuickTime::tx3g = (
    PROCESS_PROC => \&Process_tx3g,
    GROUPS => { 2 => 'Location' },
    FIRST_ENTRY => 0,
    NOTES => 'Tags extracted from the tx3g sbtl timed metadata of Yuneec drones.',
    Lat => {
        Name => 'GPSLatitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    Lon => {
        Name => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    Alt => {
        Name => 'GPSAltitude',
        ValueConv => '$val =~ s/\s*m$//; $val', # remove " m"
        PrintConv => '"$val m"', # add it back again
    },
    Yaw      => 'Yaw',
    Pitch    => 'Pitch',
    Roll     => 'Roll',
    GimYaw   => 'GimbalYaw',
    GimPitch => 'GimbalPitch',
    GimRoll  => 'GimbalRoll',
);

#------------------------------------------------------------------------------
# Save information from keys in OtherSampleDesc directory for processing timed metadata
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (ref "Timed Metadata Media" here:
#  https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html)
sub SaveMetaKeys($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    return 0 unless $dirLen > 8;
    my $pos = 0;
    my $verbose = $$et{OPTIONS}{Verbose};
    my $oldIndent = $$et{INDENT};
    my $ee = $$et{ee};
    $ee or $ee = $$et{ee} = { };

    $verbose and $et->VerboseDir($$dirInfo{DirName}, undef, $dirLen);

    # loop through metadata key table
    while ($pos + 8 < $dirLen) {
        my $size = Get32u($dataPt, $pos);
        my $id = substr($$dataPt, $pos+4, 4);
        my $end = $pos + $size;
        $end = $dirLen if $end > $dirLen;
        $pos += 8;
        my ($tagID, $format, $pid);
        if ($verbose) {
            $pid = PrintableTagID($id,1);
            $et->VPrint(0, "$oldIndent+ [Metdata Key entry, Local ID=$pid, $size bytes]\n");
            $$et{INDENT} .= '| ';
        }

        while ($pos + 4 < $end) {
            my $len = unpack("x${pos}N", $$dataPt);
            last if $len < 8 or $pos + $len > $end;
            my $tag = substr($$dataPt, $pos + 4, 4);
            $pos += 8;  $len -= 8;
            my $val = substr($$dataPt, $pos, $len);
            $pos += $len;
            my $str;
            if ($tag eq 'keyd') {
                ($tagID = $val) =~ s/^(mdta|fiel)com\.apple\.quicktime\.//;
                $tagID = "Tag_$val" unless $tagID;
                ($str = $val) =~ s/(.{4})/$1 / if $verbose;
            } elsif ($tag eq 'dtyp') {
                next if length $val < 4;
                if (length $val >= 4) {
                    my $ns = unpack('N', $val);
                    if ($ns == 0) {
                        length $val >= 8 or $et->Warn('Short dtyp data'), next;
                        $str = unpack('x4N',$val);
                        $format = $qtFmt{$str} || 'undef';
                    } elsif ($ns == 1) {
                        $str = substr($val, 4);
                        $format = 'undef';
                    } else {
                        $format = 'undef';
                    }
                    $str .= " ($format)" if $verbose and defined $str;
                }
            }
            if ($verbose > 1) {
                if (defined $str) {
                    $str =~ tr/\x00-\x1f\x7f-\xff/./;
                    $str = " = $str";
                } else {
                    $str = '';
                }
                $et->VPrint(1, $$et{INDENT}."- Tag '".PrintableTagID($tag)."' ($len bytes)$str\n");
                $et->VerboseDump(\$val);
            }
        }
        if (defined $tagID and defined $format) {
            if ($verbose) {
                my $t2 = PrintableTagID($tagID);
                $et->VPrint(0, "$$et{INDENT}Added Local ID $pid = $t2 ($format)\n");
            }
            $$ee{'keys'}{$id} = { TagID => $tagID, Format => $format };
        }
        $$et{INDENT} = $oldIndent;
    }
    return 1;
}

#------------------------------------------------------------------------------
# We found some tags for this sample, so set document number and save timing information
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) sample time, 3) sample duration
sub FoundSomething($$$$)
{
    my ($et, $tagTbl, $time, $dur) = @_;
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $et->HandleTag($tagTbl, SampleTime => $time) if defined $time;
    $et->HandleTag($tagTbl, SampleDuration => $dur) if defined $dur;
}

#------------------------------------------------------------------------------
# Exract embedded metadata from media samples
# Inputs: 0) ExifTool ref
# Notes: Also accesses ExifTool RAF*, SET_GROUP1, HandlerType, MetaFormat,
#        ee*, and avcC elements (* = must exist)
sub ProcessSamples($)
{
    my $et = shift;
    my ($raf, $ee) = @$et{qw(RAF ee)};
    my ($i, $buff, $pos, $hdrLen, $hdrFmt, @time, @dur, $oldIndent);

    return unless $ee;
    delete $$et{ee};    # use only once

    # only process specific types of video streams
    my $type = $$et{HandlerType} || '';
    if ($type eq 'vide') {
        if    ($$ee{avcC}) { $type = 'avcC' }
        elsif ($$ee{JPEG}) { $type = 'JPEG' }
        else { return }
    }

    my ($start, $size) = @$ee{qw(start size)};
#
# determine sample start offsets from chunk offsets (stco) and sample-to-chunk table (stsc),
# and sample time/duration from time-to-sample (stts)
#
    unless ($start and $size) {
        return unless $size;
        my ($stco, $stsc, $stts) = @$ee{qw(stco stsc stts)};
        return unless $stco and $stsc and @$stsc;
        $start = [ ];
        my ($nextChunk, $iChunk) = (0, 1);
        my ($chunkStart, $startChunk, $samplesPerChunk, $descIdx, $timeCount, $timeDelta, $time);
        if ($stts and @$stts > 1) {
            $time = 0;
            $timeCount = shift @$stts;
            $timeDelta = shift @$stts;
        }
        my $ts = $$et{MediaTS} || 1;
        foreach $chunkStart (@$stco) {
            if ($iChunk >= $nextChunk and @$stsc) {
                ($startChunk, $samplesPerChunk, $descIdx) = @{shift @$stsc};
                $nextChunk = $$stsc[0][0] if @$stsc;
            }
            @$size < @$start + $samplesPerChunk and $et->WarnOnce('Sample size error'), return;
            my $sampleStart = $chunkStart;
            for ($i=0; ; ) {
                push @$start, $sampleStart;
                if (defined $time) {
                    until ($timeCount) {
                        if (@$stts < 2) {
                            undef $time;
                            last;
                        }
                        $timeCount = shift @$stts;
                        $timeDelta = shift @$stts;
                    }
                    push @time, $time / $ts;
                    push @dur, $timeDelta / $ts;
                    $time += $timeDelta;
                    --$timeCount;
                }
                # (eventually should use the description indices: $descIdx)
                last if ++$i >= $samplesPerChunk;
                $sampleStart += $$size[$#$start];
            }
            ++$iChunk;
        }
        @$start == @$size or $et->WarnOnce('Incorrect sample start/size count'), return;
    }
#
# extract and parse the sample data
#
    my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
    my $verbose = $et->Options('Verbose');
    my $metaFormat = $$et{MetaFormat} || '';
    my $tell = $raf->Tell();

    if ($verbose) {
        $et->VPrint(0, "---- Extract Embedded ----\n");
        $oldIndent = $$et{INDENT};
        $$et{INDENT} = '';
    }
    # get required information from avcC box if parsing video data
    if ($type eq 'avcC') {
        $hdrLen = (Get8u(\$$ee{avcC}, 4) & 0x03) + 1;
        $hdrFmt = ($hdrLen == 4 ? 'N' : $hdrLen == 2 ? 'n' : 'C');
        require Image::ExifTool::H264;
    }
    # loop through all samples
    for ($i=0; $i<@$start and $i<@$size; ++$i) {

        # read the sample data
        my $size = $$size[$i];
        next unless $raf->Seek($$start[$i], 0) and $raf->Read($buff, $size) == $size;

        if ($type eq 'avcC') {
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
        if ($verbose > 1) {
            my $hdr = $$et{SET_GROUP1} ? "$$et{SET_GROUP1} Type='${type}' Format='${metaFormat}'" : "Type='${type}'";
            $et->VPrint(1, "${hdr}, Sample ".($i+1).' of '.scalar(@$start)." ($size bytes)\n");
            $et->VerboseDump(\$buff, Addr => $$start[$i]);
        }
        if ($type eq 'text') {

            FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
            unless ($buff =~ /^\$BEGIN/) {
                # remove ending "encd" box if it exists
                $buff =~ s/\0\0\0\x0cencd\0\0\x01\0$// and $size -= 12;
                # cameras such as the CanonPowerShotN100 store ASCII time codes with a
                # leading 2-byte integer giving the length of the string
                # (and chapter names start with a 2-byte integer too)
                if ($size >= 2 and unpack('n',$buff) == $size - 2) {
                    next if $size == 2;
                    $buff = substr($buff,2);
                }
                my $val;
                # check for encrypted GPS text as written by E-PRANCE B47FS camera
                if ($buff =~ /^\0/ and $buff =~ /\x0a$/ and length($buff) > 5) {
                    # decode simple ASCII difference cipher,
                    # based on known value of 4th-last char = '*'
                    my $dif = ord('*') - ord(substr($buff, -4, 1));
                    my $tmp = pack 'C*',map { $_=($_+$dif)&0xff } unpack 'C*',substr $buff,1,-1;
                    if ($verbose > 2) {
                        $et->VPrint(0, "[decrypted text]\n");
                        $et->VerboseDump(\$tmp);
                    }
                    if ($tmp =~ /^(.*?)(\$[A-Z]{2}RMC.*)/s) {
                        ($val, $buff) = ($1, $2);
                        $val =~ tr/\t/ /;
                        $et->HandleTag($tagTbl, RawGSensor => $val) if length $val;
                    }
                } elsif ($buff =~ /^PNDM/ and length $buff >= 20) {
                    # Garmin Dashcam format (actually binary, not text)
                    $et->HandleTag($tagTbl, GPSLatitude  => Get32s(\$buff, 12) * 180/0x80000000);
                    $et->HandleTag($tagTbl, GPSLongitude => Get32s(\$buff, 16) * 180/0x80000000);
                    $et->HandleTag($tagTbl, GPSSpeed => Get16u(\$buff, 8));
                    $et->HandleTag($tagTbl, GPSSpeedRef => 'M');
                    next;
                }
                unless (defined $val) {
                    $et->HandleTag($tagTbl, Text => $buff); # just store any other text
                    next;
                }
            }
            while ($buff =~ /\$(\w+)([^\$]*)/g) {
                my ($tag, $dat) = ($1, $2);
                if ($tag =~ /^[A-Z]{2}RMC$/ and $dat =~ /^,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/) {
                    $et->HandleTag($tagTbl, GPSLatitude  => (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1));
                    $et->HandleTag($tagTbl, GPSLongitude => (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1));
                    if (length $11) {
                        $et->HandleTag($tagTbl, GPSSpeed => $11 * $knotsToKph);
                        $et->HandleTag($tagTbl, GPSSpeedRef => 'K');
                    }
                    if (length $12) {
                        $et->HandleTag($tagTbl, GPSTrack => $11);
                        $et->HandleTag($tagTbl, GPSTrackRef => 'T');
                    }
                    my $year = $15 + ($15 >= 70 ? 1900 : 2000);
                    my $str = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', $year, $14, $13, $1, $2, $3);
                    $et->HandleTag($tagTbl, GPSDateTime => $str);
                } elsif ($tag eq 'BEGINGSENSOR' and $dat =~ /^:([-+]\d+\.\d+):([-+]\d+\.\d+):([-+]\d+\.\d+)/) {
                    $et->HandleTag($tagTbl, Accelerometer => "$1 $2 $3");
                } elsif ($tag eq 'TIME' and $dat =~ /^:(\d+)/) {
                    $et->HandleTag($tagTbl, TimeCode => $1 / ($$et{MediaTS} || 1));
                } elsif ($tag eq 'BEGIN') {
                    $et->HandleTag($tagTbl, Text => $dat) if length $dat;
                } elsif ($tag ne 'END') {
                    $et->HandleTag($tagTbl, Text => "\$$tag$dat");
                }
            }

        } elsif ($processByMetaFormat{$type}) {

            if ($$tagTbl{$metaFormat}) {
                my $tagInfo = $et->GetTagInfo($tagTbl, $metaFormat, \$buff);
                if ($tagInfo) {
                    FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
                    $$et{ee} = $ee; # need ee information for 'keys'
                    $et->HandleTag($tagTbl, $metaFormat, undef,
                        DataPt  => \$buff,
                        Base    => $$start[$i],
                        TagInfo => $tagInfo,
                    );
                    delete $$et{ee};
                }
            } elsif ($verbose) {
                $et->VPrint(0, "Unknown meta format ($metaFormat)");
            }

        } elsif ($type eq 'gps ') { # (ie. GPSDataList tag)

            if ($buff =~ /^....freeGPS /s) {
                # decode "freeGPS " data (Novatek)
                ProcessFreeGPS($et, {
                    DataPt => \$buff,
                    SampleTime => $time[$i],
                    SampleDuration => $dur[$i],
                }, $tagTbl) ;
            }

        } elsif ($$tagTbl{$type}) {

            my $tagInfo = $et->GetTagInfo($tagTbl, $type, \$buff);
            if ($tagInfo) {
                FoundSomething($et, $tagTbl, $time[$i], $dur[$i]);
                $et->HandleTag($tagTbl, $type, undef,
                    DataPt  => \$buff,
                    Base    => $$start[$i],
                    TagInfo => $tagInfo,
                );
            }
        }
    }
    if ($verbose) {
        $$et{INDENT} = $oldIndent;
        $et->VPrint(0, "--------------------------\n");
    }
    # clean up
    $raf->Seek($tell, 0); # restore original file position
    $$et{DOC_NUM} = 0;
    $$et{HandlerType} = $$et{HanderDesc} = '';
}

#------------------------------------------------------------------------------
# Process "freeGPS " data blocks referenced by a 'gps ' (GPSDataList) atom
# Inputs: 0) ExifTool ref, 1) dirInfo ref {DataPt,SampleTime,SampleDuration}, 2) tagTable ref
# Returns: 1 on success (or 0 on unrecognized or "measurement-void" GPS data)
# Notes:
# - also see ProcessFreeGPS2() below for processing of other types of freeGPS blocks
sub ProcessFreeGPS($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my ($yr, $mon, $day, $hr, $min, $sec, $stat, $lbl);
    my ($lat, $latRef, $lon, $lonRef, $spd, $trk, $alt, @acc, @xtra);

    return 0 if $dirLen < 92;

    if (substr($$dataPt,12,1) eq "\x05") {

        # decode encrypted ASCII-based GPS (DashCam Azdome GS63H, ref 5)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 05 01 00 00 [....freeGPS ....]
        #  0010: 01 03 aa aa f2 e1 f0 ee 54 54 98 9a 9b 92 9a 93 [........TT......]
        #  0020: 98 9e 98 98 9e 93 98 92 a6 9f 9f 9c 9d ed fa 8a [................]
        my $n = $dirLen - 18;
        $n = 0x101 if $n > 0x101;
        my $buf2 = pack 'C*', map { $_ ^ 0xaa } unpack 'C*', substr($$dataPt,18,$n);
        if ($et->Options('Verbose') > 1) {
            $et->VPrint(1, '[decrypted freeGPS data]');
            $et->VerboseDump(\$buf2);
        }
        # (extract longitude as 9 digits, not 8, ref PH)
        return 0 unless $buf2 =~ /^.{8}(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}).(.{15})([NS])(\d{8})([EW])(\d{9})(\d{8})/s;
        ($yr,$mon,$day,$hr,$min,$sec,$lbl,$latRef,$lat,$lonRef,$lon,$spd) = ($1,$2,$3,$4,$5,$6,$7,$8,$9/1e4,$10,$11/1e4,$12);
        $spd += 0;  # remove leading 0's
        $lbl =~ s/\0.*//s;  $lbl =~ s/\s+$//;  # truncate at null and remove trailing spaces
        push @xtra, UserLabel => $lbl if length $lbl;
        # extract accelerometer data (ref PH)
        @acc = ($1/100,$2/100,$3/100) if $buf2 =~ /^.{173}([-+]\d{3})([-+]\d{3})([-+]\d{3})/s;

    } elsif ($$dataPt =~ /^.{52}(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/s) {

        # decode NMEA-format GPS data (NextBase 512GW dashcam, ref PH)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 40 01 00 00 [....freeGPS @...]
        #  0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        #  0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        push @xtra, CameraDateTime => "$1:$2:$3 $4:$5:$6";
        if ($$dataPt =~ /\$[A-Z]{2}RMC,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d+\.\d+),([NS]),(\d+\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/s) {
            ($lat,$latRef,$lon,$lonRef) = ($5,$6,$7,$8);
            $yr = $13 + ($13 >= 70 ? 1900 : 2000);
            ($mon,$day,$hr,$min,$sec) = ($12,$11,$1,$2,$3);
            $spd = $9 * $knotsToKph if length $9;
            $trk = $10 if length $10;
        }
        if ($$dataPt =~ /\$[A-Z]{2}GGA,(\d{2})(\d{2})(\d+(\.\d*)?),(\d+\.\d+),([NS]),(\d+\.\d+),([EW]),[1-6]?,(\d+)?,(\.\d+|\d+\.?\d*)?,(-?\d+\.?\d*)?,M?/s) {
            ($hr,$min,$sec,$lat,$latRef,$lon,$lonRef) = ($1,$2,$3,$5,$6,$7,$8) unless defined $yr;
            $alt = $11;
            unshift @xtra, GPSSatellites => $9;
            unshift @xtra, GPSDOP => $10;
        }
        if (defined $lat) {
            # extract accelerometer readings if GPS was valid
            @acc = unpack('x68V3', $$dataPt);
            # change to signed integer and divide by 256
            map { $_ = $_ - 4294967296 if $_ >= 0x80000000; $_ /= 256 } @acc;
        }

    } else {

        # decode binary GPS format (Viofo A119S, ref 2)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 4c 00 00 00 [....freeGPS L...]
        #  0010: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        #  0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
        # (records are same structure as Type 3 Novatek GPS in ProcessFreeGPS2() below)
        ($hr,$min,$sec,$yr,$mon,$day,$stat,$latRef,$lonRef,$lat,$lon,$spd,$trk) =
            unpack('x48V6a1a1a1x1V4', $$dataPt);
        # ignore invalid fixes
        return 0 unless $stat eq 'A' and ($latRef eq 'N' or $latRef eq 'S') and
                                         ($lonRef eq 'E' or $lonRef eq 'W');
        ($lat,$lon,$spd,$trk) = unpack 'f*', pack 'L*', $lat, $lon, $spd, $trk;
        $yr += 2000 if $yr < 2000;
        $spd *= $knotsToKph;    # convert speed to km/h
        # ($trk is not confirmed; may be GPSImageDirection, ref PH)
    }
#
# save tag values extracted by above code
#
    FoundSomething($et, $tagTbl, $$dirInfo{SampleTime}, $$dirInfo{SampleDuration});
    # lat/long are in DDDMM.MMMM format
    my $deg = int($lat / 100);
    $lat = $deg + ($lat - $deg * 100) / 60;
    $deg = int($lon / 100);
    $lon = $deg + ($lon - $deg * 100) / 60;
    $sec = '0' . $sec unless $sec =~ /^\d{2}/;   # pad integer part of seconds to 2 digits
    if (defined $yr) {
        my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%sZ',$yr,$mon,$day,$hr,$min,$sec);
        $et->HandleTag($tagTbl, GPSDateTime => $time);
    } elsif (defined $hr) {
        my $time = sprintf('%.2d:%.2d:%sZ',$hr,$min,$sec);
        $et->HandleTag($tagTbl, GPSTimeStamp => $time);
    }
    $et->HandleTag($tagTbl, GPSLatitude  => $lat * ($latRef eq 'S' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSLongitude => $lon * ($lonRef eq 'W' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSAltitude  => $alt) if defined $alt;
    if (defined $spd) {
        $et->HandleTag($tagTbl, GPSSpeed => $spd);
        $et->HandleTag($tagTbl, GPSSpeedRef => 'K');
    }
    if (defined $trk) {
        $et->HandleTag($tagTbl, GPSTrack => $trk);
        $et->HandleTag($tagTbl, GPSTrackRef => 'T');
    }
    while (@xtra) {
        my $tag = shift @xtra;
        $et->HandleTag($tagTbl, $tag => shift @xtra);
    }
    $et->HandleTag($tagTbl, Accelerometer => \@acc) if @acc;
    return 1;
}

#------------------------------------------------------------------------------
# Process "freeGPS " data blocks _not_ referenced by a 'gps ' atom
# Inputs: 0) ExifTool ref, 1) dirInfo ref {DataPt,DataPos,DirLen}, 2) tagTable ref
# Returns: 1 on success
# Notes:
# - also see ProcessFreeGPS() above
sub ProcessFreeGPS2($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my ($yr, $mon, $day, $hr, $min, $sec, $pos);
    my ($lat, $latRef, $lon, $lonRef, $spd, $trk, $alt, $ddd, $unk);

    return 0 if $dirLen < 82;   # minimum size of block with a single GPS record

    if (substr($$dataPt,0x45,3) eq 'ATC') {

        # header looks like this: (sample 1)
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 38 06 00 00 [....freeGPS 8...]
        #  0010: 49 51 53 32 30 31 33 30 33 30 36 42 00 00 00 00 [IQS20130306B....]
        #  0020: 4d 61 79 20 31 35 20 32 30 31 35 2c 20 31 39 3a [May 15 2015, 19:]
        # (sample 2)
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 4c 06 00 00 [....freeGPS L...]
        #  0010: 32 30 31 33 30 33 31 38 2e 30 31 00 00 00 00 00 [20130318.01.....]
        #  0020: 4d 61 72 20 31 38 20 32 30 31 33 2c 20 31 34 3a [Mar 18 2013, 14:]

        my ($recPos, $lastRecPos, $foundNew);
        my $verbose = $et->Options('Verbose');
        my $dataPos = $$dirInfo{DataPos};
        my $then = $$et{FreeGPS2}{Then};
        $then or $then = $$et{FreeGPS2}{Then} = [ (0) x 6 ];
        # Loop through records in the ATC-type GPS block until we find the most recent.
        # If we have already found one, then we only need to check the first record
        # (in case the buffer wrapped around), and the record after the position of
        # the last record we found, because the others will be old.  Odd, but this
        # is the way it is done...  I have only seen one new 52-byte record in the
        # entire 32 kB block, but the entire device ring buffer (containing 30
        # entries in my samples) is stored every time.  The code below allows for
        # the possibility of missing blocks and multiple new records in a single
        # block, but I have never seen this.  Note that there may be some earlier
        # GPS records at the end of the first block that we will miss decoding, but
        # these should (I believe) be before the start of the video
ATCRec: for ($recPos = 0x30; $recPos + 52 < $dirLen; $recPos += 52) {

            my $a = substr($$dataPt, $recPos, 52); # isolate a single record
            # decrypt record
            my @a = unpack('C*', $a);
            my ($key1, $key2) = @a[0x14, 0x1c];
            $a[$_] ^= $key1 foreach 0x00..0x14, 0x18..0x1b;
            $a[$_] ^= $key2 foreach 0x1c, 0x20..0x32;
            my $b = pack 'C*', @a;
            # unpack and validate date/time
            my @now = unpack 'x13C3x28vC2', $b; # (H-1,M,S,Y,m,d)
            $now[0] = ($now[0] + 1) & 0xff;     # increment hour
            my $i;
            for ($i=0; $i<@dateMax; ++$i) {
                next if $now[$i] <= $dateMax[$i];
                $et->WarnOnce('Invalid GPS date/time');
                next ATCRec;    # ignore this record
            }
            # look for next ATC record in temporal sequence
            foreach $i (3..5, 0..2) {
                if ($now[$i] < $$then[$i]) {
                    last ATCRec if $foundNew;
                    last;
                }
                next if $now[$i] == $$then[$i];
                # we found a more recent record -- extract it and remember its location
                if ($verbose) {
                    $et->VPrint(2, "  + [encrypted GPS record]\n");
                    $et->VerboseDump(\$a, DataPos => $dataPos + $recPos);
                    $et->VPrint(2, "  + [decrypted GPS record]\n");
                    $et->VerboseDump(\$b);
                    #my @v = unpack 'H8VVC4V!CA3V!CA3VvvV!vCCCCH4', $b;
                    #$et->VPrint(2, "  + [unpacked: @v]\n");
                    # values unpacked above (ref PH):
                    #  0) 0x00 4 bytes - byte 0=1, 1=counts to 255, 2=record index, 3=0 (ref 3)
                    #  1) 0x04 4 bytes - int32u: bits 0-4=day, 5-8=mon, 9-19=year (ref 3)
                    #  2) 0x08 4 bytes - int32u: bits 0-5=sec, 6-11=min, 12-16=hour (ref 3)
                    #  3) 0x0c 1 byte  - seen values of 0,1,2 - GPS status maybe?
                    #  4) 0x0d 1 byte  - hour minus 1
                    #  5) 0x0e 1 byte  - minute
                    #  6) 0x0f 1 byte  - second
                    #  7) 0x10 4 bytes - int32s latitude * 1e7
                    #  8) 0x14 1 byte  - always 0 (used for decryption)
                    #  9) 0x15 3 bytes - always "ATC"
                    # 10) 0x18 4 bytes - int32s longitude * 1e7
                    # 11) 0x1c 1 byte  - always 0 (used for decryption)
                    # 12) 0x1d 3 bytes - always "001"
                    # 13) 0x20 4 bytes - int32s speed * 100 (m/s)
                    # 14) 0x24 2 bytes - int16u heading * 100 (-180 to 180 deg)
                    # 15) 0x26 2 bytes - always zero
                    # 16) 0x28 4 bytes - int32s altitude * 1000 (ref 3)
                    # 17) 0x2c 2 bytes - int16u year
                    # 18) 0x2e 1 byte  - month
                    # 19) 0x2f 1 byte  - day
                    # 20) 0x30 1 byte  - unknown
                    # 21) 0x31 1 byte  - always zero
                    # 22) 0x32 2 bytes - checksum ?
                }
                @$then = @now;
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                $trk = Get16s(\$b, 0x24) / 100;
                $trk += 360 if $trk < 0;
                my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', @now[3..5, 0..2]);
                $et->HandleTag($tagTbl, GPSDateTime  => $time);
                $et->HandleTag($tagTbl, GPSLatitude  => Get32s(\$b, 0x10) / 1e7);
                $et->HandleTag($tagTbl, GPSLongitude => Get32s(\$b, 0x18) / 1e7);
                $et->HandleTag($tagTbl, GPSSpeed     => Get32s(\$b, 0x20) / 100 * $mpsToKph);
                $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
                $et->HandleTag($tagTbl, GPSTrack     => $trk);
                $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
                $et->HandleTag($tagTbl, GPSAltitude  => Get32s(\$b, 0x28) / 1000);
                $lastRecPos = $recPos;
                $foundNew = 1;
                # don't skip to location of previous recent record in ring buffer
                # since we found a more recent record here
                delete $$et{FreeGPS2}{RecentRecPos};
                last;
            }
            # skip older records
            my $recentRecPos = $$et{FreeGPS2}{RecentRecPos};
            $recPos = $recentRecPos if $recentRecPos and $recPos < $recentRecPos;
        }
        # save position of most recent record (needed when parsing the next freeGPS block)
        $$et{FreeGPS2}{RecentRecPos} = $lastRecPos;
        return 1;

    } elsif ($$dataPt =~ /^.{60}A\0.{10}([NS])\0.{14}([EW])\0/s) {

        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 08 01 00 00 [....freeGPS ....]
        #  0010: 32 30 31 33 30 38 31 35 2e 30 31 00 00 00 00 00 [20130815.01.....]
        #  0020: 4a 75 6e 20 31 30 20 32 30 31 37 2c 20 31 34 3a [Jun 10 2017, 14:]

        # Type 2 (ref PH):
        # 0x30 - int32u hour
        # 0x34 - int32u minute
        # 0x38 - int32u second
        # 0x3c - int32u GPS status ('A' or 'V')
        # 0x40 - double latitude  (DDMM.MMMMMM)
        # 0x48 - int32u latitude ref  ('N' or 'S')
        # 0x50 - double longitude (DDMM.MMMMMM)
        # 0x58 - int32u longitude ref ('E' or 'W')
        # 0x60 - double speed (knots)
        # 0x68 - double heading (deg)
        # 0x70 - int32u year - 2000
        # 0x74 - int32u month
        # 0x78 - int32u day
        ($latRef, $lonRef) = ($1, $2);
        ($hr,$min,$sec,$yr,$mon,$day) = unpack('x48V3x52V3', $$dataPt);
        $lat = GetDouble($dataPt, 0x40);
        $lon = GetDouble($dataPt, 0x50);
        $spd = GetDouble($dataPt, 0x60) * $knotsToKph;
        $trk = GetDouble($dataPt, 0x68);

    } elsif ($$dataPt =~ /^.{72}A([NS])([EW])/s) {

        # Type 3 (Novatek GPS, ref 2): (in case it wasn't decoded via 'gps ' atom)
        # 0x30 - int32u hour
        # 0x34 - int32u minute
        # 0x38 - int32u second
        # 0x3c - int32u year - 2000
        # 0x40 - int32u month
        # 0x44 - int32u day
        # 0x48 - int8u  GPS status ('A' or 'V')
        # 0x49 - int8u  latitude ref  ('N' or 'S')
        # 0x4a - int8u  longitude ref ('E' or 'W')
        # 0x4b - 0
        # 0x4c - float  latitude  (DDMM.MMMMMM)
        # 0x50 - float  longitude (DDMM.MMMMMM)
        # 0x54 - float  speed (knots)
        # 0x58 - float  heading (deg)
        # Type 3b, same as above for 0x30-0x4a (ref PH)
        # 0x4c - int32s latitude (decimal degrees * 1e7)
        # 0x50 - int32s longitude (decimal degrees * 1e7)
        # 0x54 - int32s speed (m/s * 100)
        # 0x58 - float  altitude (m * 1000, NC)
        ($latRef, $lonRef) = ($1, $2);
        ($hr,$min,$sec,$yr,$mon,$day) = unpack('x48V6', $$dataPt);
        if (substr($$dataPt, 16, 3) eq 'IQS') {
            # Type 3b (ref PH)
            # header looks like this in my sample:
            #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 4c 00 00 00 [....freeGPS L...]
            #  0010: 49 51 53 5f 41 37 5f 32 30 31 35 30 34 31 37 00 [IQS_A7_20150417.]
            #  0020: 4d 61 72 20 32 39 20 32 30 31 37 2c 20 31 36 3a [Mar 29 2017, 16:]
            $ddd = 1;
            $lat = abs Get32s($dataPt, 0x4c) / 1e7;
            $lon = abs Get32s($dataPt, 0x50) / 1e7;
            $spd = Get32s($dataPt, 0x54) / 100 * $mpsToKph;
            $alt = GetFloat($dataPt, 0x58) / 1000; # (NC)
        } else {
            # Type 3 (ref 2)
            # (no sample with this format)
            $lat = GetFloat($dataPt, 0x4c);
            $lon = GetFloat($dataPt, 0x50);
            $spd = GetFloat($dataPt, 0x54) * $knotsToKph;
            $trk = GetFloat($dataPt, 0x58);
        }

    } else {

        # (look for binary GPS as stored by NextBase 512G, ref PH)
        # header looks like this in my sample:
        #  0000: 00 00 80 00 66 72 65 65 47 50 53 20 78 01 00 00 [....freeGPS x...]
        #  0010: 78 2e 78 78 00 00 00 00 00 00 00 00 00 00 00 00 [x.xx............]
        #  0020: 30 30 30 30 30 00 00 00 00 00 00 00 00 00 00 00 [00000...........]

        # followed by a number of 32-byte records in this format (big endian!):
        # 0x30 - int16u unknown (seen: 0x24 0x53 = "$S")
        # 0x32 - int16u speed (m/s * 100)
        # 0x34 - int16s heading (deg * 100) (or GPSImgDirection?)
        # 0x36 - int16u year
        # 0x38 - int8u  month
        # 0x39 - int8u  day
        # 0x3a - int8u  hour
        # 0x3b - int8u  min
        # 0x3c - int16u sec * 10
        # 0x3e - int8u  unknown (seen: 2)
        # 0x3f - int32s latitude (decimal degrees * 1e7)
        # 0x43 - int32s longitude (decimal degrees * 1e7)
        # 0x47 - int8u  unknown (seen: 16)
        # 0x48-0x4f -   all zero
        for ($pos=0x32; ; ) {
            ($spd,$trk,$yr,$mon,$day,$hr,$min,$sec,$unk,$lat,$lon) = unpack "x${pos}nnnCCCCnCNN", $$dataPt;
            # validate record using date/time
            last if $yr < 2000 or $yr > 2200 or
                    $mon < 1 or $mon > 12 or
                    $day < 1 or $day > 31 or
                    $hr > 59 or $min > 59 or $sec > 600;
            # change lat/lon to signed integer and divide by 1e7
            map { $_ = $_ - 4294967296 if $_ >= 0x80000000; $_ /= 1e7 } $lat, $lon;
            $trk -= 0x10000 if $trk >= 0x8000;  # make it signed
            $trk /= 100;
            $trk += 360 if $trk < 0;
            my $time = sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%04.1fZ", $yr, $mon, $day, $hr, $min, $sec/10);
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            $et->HandleTag($tagTbl, GPSDateTime  => $time);
            $et->HandleTag($tagTbl, GPSLatitude  => $lat);
            $et->HandleTag($tagTbl, GPSLongitude => $lon);
            $et->HandleTag($tagTbl, GPSSpeed     => $spd / 100 * $mpsToKph);
            $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
            $et->HandleTag($tagTbl, GPSTrack     => $trk);
            $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
            last if $pos += 0x20 > length($$dataPt) - 0x1e;
        }
        return $$et{DOC_NUM} ? 1 : 0;   # return 0 if nothing extracted
    }
#
# save tag values extracted by above code
#
    return 0 if $mon < 1 or $mon > 12;  # quick sanity check
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $yr += 2000 if $yr < 2000;
    my $time = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', $yr, $mon, $day, $hr, $min, $sec);
    # convert from DDMM.MMMMMM to DD.DDDDDD format if necessary
    unless ($ddd) {
        my $deg = int($lat / 100);
        $lat = $deg + ($lat - $deg * 100) / 60;
        $deg = int($lon / 100);
        $lon = $deg + ($lon - $deg * 100) / 60;
    }
    $et->HandleTag($tagTbl, GPSDateTime  => $time);
    $et->HandleTag($tagTbl, GPSLatitude  => $lat * ($latRef eq 'S' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSLongitude => $lon * ($lonRef eq 'W' ? -1 : 1));
    $et->HandleTag($tagTbl, GPSSpeed     => $spd); # (now in km/h)
    $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
    if (defined $trk) {
        $et->HandleTag($tagTbl, GPSTrack     => $trk);
        $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
    }
    if (defined $alt) {
        $et->HandleTag($tagTbl, GPSAltitude  => $alt);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract embedded information referenced from a track
# Inputs: 0) ExifTool ref, 1) tag name, 2) data ref
sub ParseTag($$$)
{
    local $_;
    my ($et, $tag, $dataPt) = @_;
    my $dataLen = length $$dataPt;

    if ($tag eq 'stsz' or $tag eq 'stz2' and $dataLen > 12) {
        # read the sample sizes
        my ($sz, $num) = unpack('x4N2', $$dataPt);
        my $size = $$et{ee}{size} = [ ];
        if ($tag eq 'stsz') {
            if ($sz == 0) {
                @$size = ReadValue($dataPt, 12, 'int32u', $num, $dataLen-12);
            } else {
                @$size = ($sz) x $num;
            }
        } else {
            $sz &= 0xff;
            if ($sz == 4) {
                my @tmp = ReadValue($dataPt, 12, 'int8u', int(($num+1)/2), $dataLen-12);
                foreach (@tmp) {
                    push @$size, $_ >> 4;
                    push @$size, $_ & 0xff;
                }
            } elsif ($sz == 8 || $sz == 16) {
                @$size = ReadValue($dataPt, 12, "int${sz}u", $num, $dataLen-12);
            }
        }
    } elsif ($tag eq 'stco' or $tag eq 'co64' and $dataLen > 8) {
        # read the chunk offsets
        my $num = unpack('x4N', $$dataPt);
        my $stco = $$et{ee}{stco} = [ ];
        @$stco = ReadValue($dataPt, 8, $tag eq 'stco' ? 'int32u' : 'int64u', $num, $dataLen-8);
    } elsif ($tag eq 'stsc' and $dataLen > 8) {
        # read the sample-to-chunk box
        my $num = unpack('x4N', $$dataPt);
        if ($dataLen >= 8 + $num * 12) {
            my ($i, @stsc);
            for ($i=0; $i<$num; ++$i) {
                # list of (first-chunk, samples-per-chunk, sample-description-index)
                push @stsc, [ unpack('x'.(8+$i*12).'N3', $$dataPt) ];
            }
            $$et{ee}{stsc} = \@stsc;
        }
    } elsif ($tag eq 'stts' and $dataLen > 8) {
        # read the time-to-sample box
        my $num = unpack('x4N', $$dataPt);
        if ($dataLen >= 8 + $num * 8) {
            $$et{ee}{stts} = [ unpack('x8N'.($num*2), $$dataPt) ];
        }
    } elsif ($tag eq 'avcC') {
        # read the AVC compressor configuration
        $$et{ee}{avcC} = $$dataPt if $dataLen >= 7;  # (minimum length is 7)
    } elsif ($tag eq 'JPEG') {
        $$et{ee}{JPEG} = $$dataPt;
    } elsif ($tag eq 'gps ' and $dataLen > 8) {
        # decode Novatek 'gps ' box (ref 2)
        my $num = Get32u($dataPt, 4);
        $num = int(($dataLen - 8) / 8) if $num * 8 + 8 > $dataLen;
        my $start = $$et{ee}{start} = [ ];
        my $size = $$et{ee}{size} = [ ];
        my $i;
        for ($i=0; $i<$num; ++$i) {
            push @$start, Get32u($dataPt, 8 + $i * 8);
            push @$size, Get32u($dataPt, 12 + $i * 8);
        }
        $$et{HandlerType} = $tag;   # fake handler type
        ProcessSamples($et);        # we have all we need to process sample data now
    }
}

#------------------------------------------------------------------------------
# Process Yuneec 'tx3g' sbtl metadata (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Process_tx3g($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    return 0 if length $$dataPt < 2;
    pos($$dataPt) = 2;  # skip 2-byte length word
    $et->HandleTag($tagTablePtr, $1, $2) while $$dataPt =~ /(\w+):([^:]*[^:\s])(\s|$)/sg;
    return 1;
}

#------------------------------------------------------------------------------
# Process QuickTime 'mebx' timed metadata
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# - uses tag ID keys stored in the ExifTool ee data member by a previous call to SaveMetaKeys
sub Process_mebx($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $ee = $$et{ee} or return 0;
    return 0 unless $$ee{'keys'};
    my $dataPt = $$dirInfo{DataPt};

    # parse using information from 'keys' table (eg. Apple iPhone7+ hevc 'Core Media Data Handler')
    $et->VerboseDir('mebx', undef, length $$dataPt);
    my $pos = 0;
    while ($pos + 8 < length $$dataPt) {
        my $len = Get32u($dataPt, $pos);
        last if $len < 8 or $pos + $len > length $$dataPt;
        my $id = substr($$dataPt, $pos+4, 4);
        my $info = $$ee{'keys'}{$id};
        if ($info) {
            my $tag = $$info{TagID};
            unless ($$tagTbl{$tag}) {
                next unless $tag =~ /^[-\w.]+$/;
                # create info for tags with reasonable id's
                my $name = $tag;
                $name =~ s/[-.](.)/\U$1/g;
                AddTagToTable($tagTbl, $tag, { Name => ucfirst($name) });
            }
            my $val = ReadValue($dataPt, $pos+8, $$info{Format}, undef, $len-8);
            $et->HandleTag($tagTbl, $tag, $val,
                DataPt => $dataPt,
                Base   => $$dirInfo{Base},
                Start  => $pos + 8,
                Size   => $len - 8,
            );
        } else {
            $et->WarnOnce('No key information for mebx ID ' . PrintableTagID($id,1));
        }
        $pos += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Scan movie data for "freeGPS" metadata if not found already (ref PH)
# Inputs: 0) ExifTool ref
sub ScanMovieData($)
{
    my $et = shift;
    return if $$et{DOC_COUNT};  # don't scan if we already found embedded metadata
    my $raf = $$et{RAF} or return;
    my $dataPos = $$et{VALUE}{MovieDataOffset} or return;
    my $dataLen = $$et{VALUE}{MovieDataSize} or return;
    $raf->Seek($dataPos, 0) or return;
    my ($pos, $buf2) = (0, '');
    my ($tagTbl, $oldByteOrder, $verbose, $buff);

    $$et{FreeGPS2} = { };   # initialize variable space for FreeGPS2()

    # loop through 'mdat' movie data looking for GPS information
    for (;;) {
        last if $pos + $gpsBlockSize > $dataLen;
        last unless $raf->Read($buff, $gpsBlockSize);
        $buff = $buf2 . $buff if length $buf2;
        last if length $buff < $gpsBlockSize;
        # look for "freeGPS " block
        # (found on an absolute 0x8000-byte boundary in all of my samples,
        #  but allow for any alignment when searching)
        if ($buff !~ /\0..\0freeGPS /sg) { # (seen ".." = "\0\x80","\x01\0")
            $buf2 = substr($buff,-12);
            $pos += length($buff)-12;
            # in all of my samples the first freeGPS block is within 2 MB of the start
            # of the mdat, so limit the scan to the first 20 MB to be fast and safe
            next if $tagTbl or $pos < 20e6;
            last;
        } elsif (not $tagTbl) {
            # initialize variables for extracting metadata from this block
            $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            $verbose = $$et{OPTIONS}{Verbose};
            $oldByteOrder = GetByteOrder();
            SetByteOrder('II');
            $et->VPrint(0, "---- Extract Embedded ----\n");
            $$et{INDENT} .= '| ';
        }
        if (pos($buff) > 12) {
            $pos += pos($buff) - 12;
            $buff = substr($buff, pos($buff) - 12);
        }
        # make sure we have the full freeGPS record
        my $len = unpack('N', $buff);
        if ($len < 12) {
            $len = 12;
        } else {
            my $more = $len - length($buff);
            if ($more > 0) {
                last unless $raf->Read($buf2, $more) == $more;
                $buff .= $buf2;
            }
            if ($verbose) {
                $et->VerboseDir('GPS', undef, $len);
                $et->VerboseDump(\$buff, DataPos => $pos + $dataPos);
            }
            my $dirInfo = { DataPt => \$buff, DataPos => $pos + $dataPos, DirLen => $len };
            ProcessFreeGPS2($et, $dirInfo, $tagTbl);
        }
        $pos += $len;
        $buf2 = substr($buff, $len);
    }
    if ($tagTbl) {
        $$et{DOC_NUM} = 0;
        $et->VPrint(0, "--------------------------\n");
        SetByteOrder($oldByteOrder);
        $$et{INDENT} = substr $$et{INDENT}, 0, -2;
    }
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Extract embedded information from movie data

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::QuickTime.

=head1 DESCRIPTION

This file contains routines used by Image::ExifTool to extract embedded
information like GPS tracks from MOV and MP4 movie data.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item Lhttps://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW130>

=item L<http://sergei.nz/files/nvtk_mp42gpx.py>

=item L<https://forum.flitsservice.nl/dashcam-info/dod-ls460w-gps-data-uit-mov-bestand-lezen-t87926.html>

=item L<https://developers.google.com/streetview/publish/camm-spec>

=item L<https://sergei.nz/extracting-gps-data-from-viofo-a119-and-other-novatek-powered-cameras/>

=back

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool::TagNames/QuickTime Stream Tags>,
L<Image::ExifTool::TagNames/GoPro GPMF Tags>,
L<Image::ExifTool::TagNames/Sony rtmd Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

