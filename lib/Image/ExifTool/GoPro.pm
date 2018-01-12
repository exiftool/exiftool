#------------------------------------------------------------------------------
# File:         GoPro.pm
#
# Description:  Read information from GoPro videos
#
# Revisions:    2018/01/12 - P. Harvey Created
#
# References:   1) https://github.com/stilldavid/gopro-utils
#------------------------------------------------------------------------------

package Image::ExifTool::GoPro;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessGPMF($$$);
sub ProcessMET($$$);

# GoPro data types that have ExifTool equivalents (ref 1)
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

# Tags found in the GPMF box of Hero6 mp4 videos (ref PH)
%Image::ExifTool::GoPro::GPMF = (
    PROCESS_PROC => \&ProcessGPMF,
    GROUPS => { 2 => 'Camera' },
    NOTES => q{
        Tags extracted from the GPMF box of GoPro MP4 videos.  Many more tags exist,
        but are currently unknown and extracted only with the -u option.  Please let
        me know if you discover the meaning of any of these unknown tags.
    },
  # APTO - seen: 'RAW' (fmt c)
  # AUDO - seen: 'WIND' (fmt c)
    AUDO => 'AudioSetting',
  # AUPT - seen: 'N' (fmt c)
  # BRID - seen: 0 (fmt B)
  # BROD - seen: 'ASK' (fmt c)
  # CASN - seen: 'C3221324545448' (fmt c)
    CASN => 'CameraSerialNumber',
  # CINF - seen: 0x67376be7709bc8876a8baf3940908618 (fmt B)
  # CMOD - seen: 12 (fmt B)
  # DEVC - DeviceContainer (fmt \0)
  # DVID - DeviceID; seen: 1 (fmt L), HLMT (fmt F)
  # DVNM - DeviceName; seen: 'Video Global Settings' (fmt c), 'Highlights' (fmt c)
  # DZOM - seen: 'Y' (fmt c)
  # DZST - seen: 0 (fmt L)
  # EISA - seen: 'Y' (fmt c)
  # EISE - seen: 'Y' (fmt c)
  # EXPT - seen: '' (fmt c)
  # FMWR - seen: HD6.01.01.51.00 (fmt c)
    FMWR => { Name => 'FirmwareVersion', Groups => { 2 => 'Camera' } },
  # LINF - seen: LAJ7061916601668 (fmt c)
  # MINF - seen: HERO6 Black (fmt c)
    MINF => {
        Name => 'Model',
        Groups => { 2 => 'Camera' },
        Description => 'Camera Model Name',
    },
  # MTYP - seen: 0 (fmt B)
  # MUID - seen: 3882563431 2278071152 967805802 411471936 0 0 0 0 (fmt L)
  # OREN - seen: 'U' (fmt c)
  # PIMN - seen: 100 (fmt L)
    PIMN => { Name => 'AutoISOMin' },
  # PIMX - seen: 1600 (fmt L)
    PIMX => { Name => 'AutoISOMax' },
  # PRTN - seen: 'N' (fmt c)
  # PTCL - seen: 'GOPRO' (fmt c)
  # PTEV - seen: '0.0' (fmt c)
  # PTSH - seen: 'HIGH' (fmt c)
  # PTWB - seen: 'AUTO' (fmt c)
  # RATE - seen: '0_5SEC' (fmt c)
  # RMRK - seen: 'struct: Time (ms), in (ms), out (ms), Location XYZ (deg,deg,m), Type, Confidence (%) Score' (fmt c)
  # SCAL - seen: 1 1 1 10000000 10000000 1 1 1 1 (fmt l)
  # SMTR - seen: 'N' (fmt c)
  # STRM - NestedSignalStream (fmt \0)
  # TYPE - seen: 'LLLllfFff' (fmt c)
  # VFOV - seen: 'W' (fmt c)
  # VLTA - seen: 78 ('N') (fmt B)
  # VLTE - seen: 'Y' (fmt c)
);

# GoPro META tags (ref 1)
%Image::ExifTool::GoPro::MET = (
    GROUPS => { 1 => 'GoPro', 2 => 'Video' },
    PROCESS_PROC => \&ProcessMET,
    NOTES => q{
        Tags extracted from the MP4 "GoPro MET" timed metadata when the ExtractEmbedded
        option is used.
    },
    ACCL => {
        Name => 'Accelerometer',
        ValueConv => q{
            my @a = split ' ', $val;
            my $scl = $$self{ScaleFactor} ? $$self{ScaleFactor}[0] : 1;
            $_ /= $scl foreach @a;
            return \ join ' ', @a;
        },
    },
    DEVC => 'DeviceContainer', #PH
    DVID => { Name => 'DeviceID', Unknown => 1 }, # possibly hard-coded to 0x1
    DVNM => {
        Name => 'DeviceName', #PH
        Description => 'Camera Model Name',
        # seen: "Camera" (Hero5), "Hero6 Black" (Hero6)
    },
    EMPT => { Name => 'Empty', Unknown => 1 },
    GPS5 => {
        Name => 'GPSInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPS5' },
    },
    GPSF => {
        Name => 'GPSMeasureMode',
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    GPSP => {
        Name => 'GPSHPositioningError',
        Description => 'GPS Horizontal Positioning Error',
        ValueConv => '$val / 100', # convert from cm to m
    },
    GPSU => {
        Name => 'GPSDateTime',
        Groups => { 2 => 'Time' },
        # (HERO5 writes this in 'c' format, HERO6 writes 'U')
        ValueConv => '$val =~ s/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1:$2:$3 $4:$5:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    GYRO => {
        Name => 'Gyroscope',
        ValueConv => q{
            my @a = split ' ', $val;
            my $scl = $$self{ScaleFactor} ? $$self{ScaleFactor}[0] : 1;
            $_ /= $scl foreach @a;
            return \ join ' ', @a;
        },
    },
    SCAL => { # scale factor for subsequent data
        Name => 'ScaleFactor',
        Unknown => 1,   # (not very useful to user)
    },
    SIUN => { # SI units (m/s2, rad/s)
        Name => 'SIUnits',
        ValueConv => '$self->Decode($val, "Latin")',
    },
    STRM => { Name => 'NestedSignalStream', Unknown => 1 },
    STNM => {
        Name => 'StreamName',
        Unknown => 1,
        ValueConv => '$self->Decode($val, "Latin")',
    },
    TMPC => {
        Name => 'CameraTemperature',
        PrintConv => '"$val C"',
    },
    TSMP => { Name => 'TotalSamples', Unknown => 1 },
    UNIT => { # alternative units (deg, m, m/s)
        Name => 'Units',
        ValueConv => '$self->Decode($val, "Latin")',
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
    RMRK => {
        Name => 'Comments',
        ValueConv => '$self->Decode($val, "Latin")',
    },
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
%Image::ExifTool::GoPro::GPS5 = (
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

# GoPro SOS tags written by the Hero5 and Hero6 (ref PH)
%Image::ExifTool::GoPro::SOS = (
    GROUPS => { 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        Tags extracted from the MP4 "GoPro SOS" timed metadata when the ExtractEmbedded
        option is used.
    },
    0x08 => { Name => 'FirmwareVersion',    Format => 'string[15]' },
    0x17 => { Name => 'SerialNumber',       Format => 'string[16]' },
    0x57 => { Name => 'OtherSerialNumber',  Format => 'string[15]' }, # (NC)
    0x66 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[16]',
    },
    # ...
    # after this there is lots of interesting stuff also found in the GPMF box,
    # but this block is lacking structure, and the value offsets are therefore
    # presumably firmware dependent :(
);

#------------------------------------------------------------------------------
# Process GoPro MET data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
sub ProcessMET($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = length $$dataPt;
    my $unk = ($et->Options('Unknown') || $et->Options('Verbose'));
    my $pos = 0;

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
        my ($val, @val);
        if ($format eq 'undef' and $count > 1 and $size > 1) {
            my ($i, @val);
            for ($i=0; $i<$count; ++$i) {
                push @val, substr($$dataPt, $pos + $size * $i, $size);
            }
            $val = join ' ', @val;
        } else {
            $val = ReadValue($dataPt, $pos, $format, undef, $len);
        }
        # save scaling factor
        $$et{ScaleFactor} = [ split ' ', $val ] if $tag eq 'SCAL';
        $pos += (($len + 3) & 0xfffffffc);  # round up to even 4-byte boundary
        if (not $$tagTablePtr{$tag} and $unk) {
            AddTagToTable($tagTablePtr, $tag, { Name => Image::ExifTool::MakeTagName("Unknown_$tag") });
        }
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
}

#------------------------------------------------------------------------------
# Process GoPro GPMF atom (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessGPMF($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{Base};
    my $dirLen = length $$dataPt;
    my $unknown = $$et{OPTIONS}{Unknown} || $$et{OPTIONS}{Verbose};
    my ($pos, $size);
    $et->VerboseDir('GPMF', undef, $dirLen);
    for ($pos = 0; $pos + 8 <= $dirLen; $pos += 8 + $size) {
        my $tag = substr($$dataPt, $pos, 4);
        my $fmt = Get8u($dataPt, $pos + 4);
        my $len = Get8u($dataPt, $pos + 5);
        my $count = Get16u($dataPt, $pos + 6);
        $size = $len * $count;
        last if $tag eq "\0\0\0\0" or $dirLen < $pos + 8 + $size;
        $fmt == 0 and $size = 0, next;      # descend into containers (fmt=0)
        $size = ($size + 3) & 0xfffffffc;   # (padded to 4-byte boundary)
        my $val = substr($$dataPt, $pos + 8, $len * $count);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            next unless $unknown;
            my $name = Image::ExifTool::QuickTime::PrintableTagID($tag);
            $tagInfo = {
                Name => "Unknown_$name",
                Description => "Unknown $name",
                Unknown => 1,
            },
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $pos + 8,
            Size    => $len * $count,
            TagInfo => $tagInfo,
            Format  => $goProFmt{$fmt},
        );
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::GoPro - Read information from GoPro videos

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to decode
metadata from GoPro MP4 videos.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://github.com/stilldavid/gopro-utils>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/GoPro Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

