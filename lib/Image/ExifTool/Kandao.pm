#------------------------------------------------------------------------------
# File:         Kandao.pm
#
# Description:  Read Kandao MP4 metadata
#
# Revisions:    2025-12-10 - P. Harvey Created
#
# Notes:        Tested with videos from the Kandao QooCam 3 Ultra
#------------------------------------------------------------------------------

package Image::ExifTool::Kandao;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessKandao($$$);
sub ProcessKVAR($$);

# Kandao format codes
my %format = (
    CHAR => 'string',
    BOOL => 'int8u',
    U8   => 'int8u',
    U16  => 'int16u',
    U32  => 'int32u',
    U64  => 'int64u',
    S8   => 'int8s',
    S16  => 'int16s',
    S32  => 'int32s',
    S64  => 'int64s',
    FLOAT => 'float',
    DOUBLE => 'double',
);

# Kandao 'kvar' and 'kfix' information
%Image::ExifTool::Kandao::Main = (
    GROUPS => { 0 => 'Kandao', 1 => 'KVAR', 2 => 'Camera' },
    VARS => { NO_LOOKUP => 1 },
    NOTES => q{
        Tags extracted from Kandao KVAR files and the 'kvar', 'kfix' and 'kstb'
        atoms in Kandao MP4 videos, and have a family 1 group name of KVAR, KFIX or
        KSTB depending on their location.
    },
    PROCESS_PROC => \&ProcessKandao,
#
# 'kvar' tags
#
    CPU_TEMP => { Name => 'CPUTemperature', ValueConv => '$val / 10' }, # U32[1]
    BAT_TEMP => 'BatteryTemperature', # U32[1]
    PTS_UNIT => { # U32[1]
        Name => 'TimeStampUnit',
        PrintConv => { 0 => 'ms', 1 => 'Subtle', 2 => 'ns' },
    },
    TOTAL_FRAME => 'TotalFrames', # U32[1]
    TOTAL_TIME_MS => { # U32[1]
        Name => 'TotalTime',
        ValueConv => '$val / 1000',
    },
    LENS => 'LensData', # CHAR[534]
    DASHBOARD => 'Dashboard', # U8[1]
    PROJECTION   => 'Projection', # CHAR[16]
    CENTER_SHIFT => 'CenterShift', # DOUBLE[1]
    DISTORTION   => 'Distortion', # DOUBLE[1]
    INFO => 'Info', # CHAR[239]
    PTS => {
        Name => 'PresentationTimeStamp',
        Notes => 'TimeStamp for each frame',
        Format => 'undef', # U64[x]
        Binary => 1,
    },
    LENS_SN0 => 'Lens0SerialNumber', # CHAR[15]
    LENS_SN1 => 'Lens1SerialNumber', # CHAR[15]
    LENS_OTP_ID0 => 'Lens0OTP_ID', # U8[1]
    LENS_OTP_ID1 => 'Lens1OTP_ID', # U8[1]
    IMU => {
        RecordSize => 20,
        SubDirectory => { TagTable => 'Image::ExifTool::Kandao::IMU' },
    },
    GPS => [{
        Condition => '$$valPt =~ /^\xff{4}/',
        RecordSize => 28,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kandao::GPS',
            Start => 4,
        },
    },{
        RecordSize => 20,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kandao::GPS',
        },
    }],
    GPSX => {
        RecordSize => 36,
        SubDirectory => { TagTable => 'Image::ExifTool::Kandao::GPSX' },
    },
    EXP => { # U8[x]
        # actually int64u - monotonically increasing
        Name => 'Exp',
    },
    # (ISP = Image Signal Processor)
    ISP => 'ISP', # U8 - 46-byte records (not very interesting looking)
    FRAME_ISP => {
        # U8 - 12-byte records: int32u-ts, float, float
        RecordSize => 12,
        SubDirectory => { TagTable => 'Image::ExifTool::Kandao::FrameISP' },
    },
    GAINMAP0 => 'GainMap0',
    GAINMAP1 => 'GainMap1',
#
# 'kfix' tags
#
    PRODUCT => 'Model',
    PROJECT => 'Project',
    SN => 'SerialNumber',
    PR_VER => 'ProductVersion',
    SW_VER => 'SoftwareVersion',
    HW_VER => 'HardwareVersion',
    VIDEO_CAPTIME => {
        Name => 'VideoCaptureTime',
        Notes => 'local camera time',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/^(\d{4})-(\d{2})-/$1:$2:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    GPS_CAPTIME => {
        Name => 'GPSCaptureTime',
        Groups => { 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val/1000, 0, 3) . "Z"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    LENS_INDEX => { Name => 'LensIndex', Format => 'int16u' },
    NEED_LSC => 'NeedLDSC',
    # (also in 'kvar') CPU_TEMP => { Name => 'CPUTemperature', ValueConv => '$val / 10' },
    # (also in 'kvar') BAT_TEMP => 'BatteryTemperature',
    INPUT_INSERT => 'InputInsert',
    VIDEO_RESOLUTION => 'VideoResolution',
    VIDEO_CODECTYPE => 'VideoCodec',
    VIDEO_BITRATE => { Name => 'VideoBitrate', PrintConv => '($val / 1e6) . " Mbps"' },
    VIDEO_FORMAT => 'VideoFormat',
    OUTPUT_INSERT => 'OutputInsert',
    DYNAMIC_RANGE => 'DynamicRange',
    AWB_CCT => 'AWB_CCT',
    EV => 'EV',
    ISO => 'ISO',
    SHUTTER => 'Shutter',
    IMAGE_STYLE => 'ImageStyle',
    AE_METERING => 'AEMetering',
    CAPTURE_MODE => 'CaptureMode',
    HDR => 'HDR',
    STITCHED => 'Stitched',
    COVER_MODE => 'CoverMode',
    STEREO => 'Stereo',
    FOV => 'FOV',
    AE_MODE => 'AEMode',
    AF_FN => 'AF_FN',
    AWB_MODE => 'AWBMode',
    AUDIO_GAIN => 'AudioGain',
    INTERVAL => 'Interval',
    ISP_VER => 'ISPVersion',
    YAW => 'Yaw',
    FAN_LEVEL => 'FanLevel',
    FAN_MODE => 'FanMode',
    CUSTOMIZED => 'Customized',
);

%Image::ExifTool::Kandao::GPS = (
    GROUPS => { 0 => 'Kandao', 1 => 'KVAR', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        These tags are in the family 1 KVAR group instead of a GPS group to allow
        them to be distinguished from the duplicate GPS tags in the GPSX table.
    },
    0 => { Name => 'TimeStamp', Format => 'int32u' },
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
    20 => { # (optional)
        Name => 'GPSAltitude',
        Format => 'double',
        PrintConv => '$_ = sprintf("%.6f", $val); s/\.?0+$//; "$_ m"',
    },
);

%Image::ExifTool::Kandao::GPSX = (
    GROUPS => { 0 => 'Kandao', 1 => 'GPS', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q(
        These tags are in the family 1 GPS group.  They are duplicates of the tags
        in the Kandao GPS table with the addition of GPSDateTime.
    ),
    0 => { Name => 'TimeStamp', Format => 'int32u' },
    4 => {
        Name => 'GPSDateTime',
        Description => 'GPS Date/Time',
        Groups => { 2 => 'Time' },
        Format => 'int64u',
        ValueConv => 'ConvertUnixTime($val/1000, 0, 3) . "Z"',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    12 => {
        Name => 'GPSLatitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    20 => {
        Name => 'GPSLongitude',
        Format => 'double',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    28 => {
        Name => 'GPSAltitude',
        Format => 'double',
        PrintConv => '$_ = sprintf("%.6f", $val); s/\.?0+$//; "$_ m"',
    },
);

# IMU gyroscope data
%Image::ExifTool::Kandao::IMU = (
    GROUPS => { 0 => 'Kandao', 1 => 'KVAR', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    0 => { Name => 'TimeStamp',     Format => 'int64u' },
    8 => { Name => 'Gyroscope',     Format => 'int16s[3]' }, # 2G max range
    14=> { Name => 'Accelerometer', Format => 'int16s[3]' }, # 2000 deg/sec max range
    # (Kandao docs mention optional 6-byte Magnetometer data here, but
    #  with no way to determine if it exists, and it isn't in my samples)
);

# (ISP = Image Signal Processor?)
%Image::ExifTool::Kandao::FrameISP = (
    GROUPS => { 0 => 'Kandao', 1 => 'KVAR', 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    0 => { Name => 'TimeStamp',  Format => 'int32u',   Unknown => 1 },
    4 => { Name => 'FrameISP_4', Format => 'float[2]', Unknown => 1 },
);

#------------------------------------------------------------------------------
# Extract information from a Kandao 'kfix' and 'kvar' atoms
# Inputs: 0) ExifTool ref, 1) dirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessKandao($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $raf = $$dirInfo{RAF};
    $raf or $raf = File::RandomAccess->new($$dirInfo{DataPt});
    my $dirName = $$dirInfo{DirName};
    my $dataPos = ($$dirInfo{DataPos} || 0) + ($$dirInfo{Base} || 0);
    my $verbose = $et->Options('Verbose');
    my $ee = $et->Options('ExtractEmbedded');
    # extract as a block from MP4 if specified
    if ($$dirInfo{BlockInfo}) {
        my $blockName = $$dirInfo{BlockInfo}{Name};
        my $blockExtract = $et->Options('BlockExtract');
        if (($blockExtract or $$et{REQ_TAG_LOOKUP}{lc $blockName} or
            ($$et{TAGS_FROM_FILE} and not $$et{EXCL_TAG_LOOKUP}{lc $blockName})))
        {
            $et->FoundTag($$dirInfo{BlockInfo}, $$dirInfo{DataPt});
            return 1 if $blockExtract and $blockExtract > 1;
        }
    }
    my ($buff, $err, $i, $tag, $fmt);
    SetByteOrder('II');
    $raf->Read($buff, 4) == 4 or return 0;
    my $n = Get32u(\$buff, 0);
    $et->VerboseDir($dirName, $n);
    for ($i=0; $i<$n; ++$i) {
        $raf->Read($buff, 0x2c) == 0x2c or $err = '', last;
        ($tag = substr($buff, 0, 0x20)) =~ s/\0+$//;
        ($fmt = substr($buff, 0x20, 8)) =~ s/\0+$//;
        my $format = $format{$fmt};
        $format or $err = "Unknown Kandao format '${fmt}'", last;
        my $num = Get32u(\$buff, 0x28);
        my $size = $num * Image::ExifTool::FormatSize($format);
        my %parms = (
            DataPt  => \$buff,
            DataPos => $dataPos + $raf->Tell(),
            Index   => $i,
            Format  => $format,
        );
        $raf->Read($buff, $size) == $size or $err = '', last;
        my $tagInfo = $et->GetTagInfo($tagTbl, $tag, \$buff);
        unless ($tagInfo) {
            my $name = ucfirst lc $tag;
            $name =~ s/_([a-z])/_\u$1/g;
            $name = Image::ExifTool::MakeTagName($name);
            $et->VPrint(0, "$$et{INDENT}\[adding $dirName '${tag}']\n");
            $tagInfo = AddTagToTable($tagTbl, $tag, { Name => $name });
        }
        my $recLen = $$tagInfo{RecordSize};
        if ($recLen) {
            $verbose and $et->VerboseInfo($tag, $tagInfo, %parms);
            my $tbl = GetTagTable($$tagInfo{SubDirectory}{TagTable});
            my $pt = $$tagInfo{SubDirectory}{Start} || 0;
            my %dirInfo = (
                DataPt  => \$buff,,
                DataPos => $parms{DataPos},
                DirLen  => $recLen,
                DirName => $tag,
            );
            my $nLimit = 10000;
            my $sizeLimit = $size;
            if ($ee and int(($size - $pt) / $recLen) > $nLimit and
                $et->Warn("Extracting only the first $nLimit $$tagInfo{Name} records", 2))
            {
                $sizeLimit = $pt + $recLen * $nLimit;
            }
            while ($pt+$recLen <= $sizeLimit) {
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                $dirInfo{DirStart} = $pt;
                $et->ProcessDirectory(\%dirInfo, $tbl);
                $ee or $et->Warn('Use the ExtractEmbedded option to extract all timed metadata',7), last;
                $pt += $recLen;
            }
            delete $$et{DOC_NUM};
        } else {
            my $val;
            if ($fmt eq 'U8' and $num > 1 and not $$tagInfo{Format}) {
                $val = \$buff;
            } else {
                # override format if necessary
                if ($$tagInfo{Format}) {
                    $format = $$tagInfo{Format};
                    $parms{Format} .= " read as $format";
                    $num = int($size / Image::ExifTool::FormatSize($format));
                }
                $val = ReadValue(\$buff, 0, $format, $num, $size);
            }
            my $key = $et->HandleTag($tagTbl, $tag, $val, %parms);
            $et->SetGroup($key, $dirName) if $dirName ne 'KVAR';
        }
    }
    $et->Warn($err || "Truncated $dirName record") if defined $err;
    return 1;
}

#------------------------------------------------------------------------------
# Process Kandao KVAR file
# Inputs: 0) ExifTool ref, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid KVAR file
sub ProcessKVAR($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tagTablePtr);

    # verify this is a valid KVAR file
    return 0 unless $raf->Read($buff, 44) == 44;
    return 0 unless $buff =~ /^.{2}\0\0[A-Z].{31}(CHAR|BOOL|[US](8|16|32|64)|FLOAT|DOUBLE)\0/s;
    $et->SetFileType('KVAR', 'application/x-kandaostudio');
    $raf->Seek(0,0) or $et->Warn('Seek error'), return 1;
    $$dirInfo{DirName} = 'KVAR';
    $tagTablePtr = GetTagTable('Image::ExifTool::Kandao::Main');
    return $et->ProcessDirectory($dirInfo, $tagTablePtr);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Kandao - Read Kandao MP4 metadata

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains code to extract metadata from Kandao 'kfix' and 'kvar'
atoms in MP4 videos as shot by the Kandao QOOCAM 3 ULTRA.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Kandao Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

