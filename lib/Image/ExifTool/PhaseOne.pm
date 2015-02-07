#------------------------------------------------------------------------------
# File:         PhaseOne.pm
#
# Description:  Phase One maker notes tags
#
# Revisions:    2013-02-17 - P. Harvey Created
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#------------------------------------------------------------------------------

package Image::ExifTool::PhaseOne;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

sub ProcessPhaseOne($$$);
sub ProcessSensorCalibration($$$);

# observed PhaseOne format types
my @formatName = ( undef, 'string', 'undef', undef, 'int32u' );
my @formatSize = ( undef,        1,       1, undef,        4 );

# Phase One maker notes (ref PH)
%Image::ExifTool::PhaseOne::Main = (
    PROCESS_PROC => \&ProcessPhaseOne,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from the maker notes of Phase One images.',
    0x0100 => { #1
        Name => 'CameraOrientation',
        ValueConv => '$val & 0x03',     # ignore other bits for now
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
            3 => 'Rotate 180',
        },
    },
    # 0x0101 - int32u: 96,160,192,256,544 (same as 0x0213)
    0x0102 => 'SerialNumber',
    # 0x0103 - int32u: 19,20,59769034
    # 0x0104 - int32u: 50,200
    0x0105 => 'ISO',
    0x0106 => {
        Name => 'ColorMatrix1',
        Format => 'float',
        PrintConv => q{
            my @a = map { sprintf('%.3f', $_) } split ' ', $val;
            return "@a";
        },
    },
    0x0107 => 'WB_RGBLevels',
    0x0108 => 'SensorWidth',
    0x0109 => 'SensorHeight',
    0x010a => 'SensorLeftMargin', #1
    0x010b => 'SensorTopMargin', #1
    0x010c => 'ImageWidth',
    0x010d => 'ImageHeight',
    0x010e => { #1
        Name => 'RawFormat',
        # 1 = raw bit mask 0x5555 (>1 mask 0x1354)
        # >2 = compressed
        # 5 = non-linear
        PrintConv => { #PH
            1 => 'RAW 1', #?
            2 => 'RAW 2', #?
            3 => 'IIQ L',
            # 4?
            5 => 'IIQ S',
            6 => 'IIQ Sv2',
        },
    },
    0x010f => { Name => 'RawData', Binary => 1 },
    0x0110 => { #1
        Name => 'SensorCalibration',
        SubDirectory => { TagTable => 'Image::ExifTool::PhaseOne::SensorCalibration' },
    },
    0x0112 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Notes => 'also used as a key to encrypt the raw data', #1
        ValueConv => 'ConvertUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x0113 => 'ImageNumber', # (NC)
    0x0203 => 'Software',
    0x0204 => 'System',
    # 0x020b - int32u: 0,1
    # 0x020c - int32u: 1,2
    # 0x020e - int32u: 1,3
    0x0210 => { # (NC) (used in linearization formula - ref 1)
        Name => 'SensorTemperature',
        PrintConv => 'sprintf("%.2f C",$val)',
    },
    0x0211 => { # (NC)
        Name => 'SensorTemperature2',
        PrintConv => 'sprintf("%.2f C",$val)',
    },
    0x0212 => {
        Name => 'UnknownDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        # (this time is within about 10 minutes before or after 0x0112)
        Unknown => 1,
        ValueConv => 'ConvertUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # 0x0213 - int32u: 96,160,192,256,544 (same as 0x0101)
    # 0x0215 - int32u: 4,5
    # 0x021a - used by dcraw
    0x021c => { Name => 'StripOffsets', Binary => 1 },
    0x021d => 'BlackLevel', #1
    # 0x021e - int32u: 1
    # 0x0220 - int32u: 32
    # 0x0221 - float: 0-271
    0x0222 => 'SplitColumn', #1
    0x0223 => { Name => 'BlackLevelData', Binary => 1 }, #1
    # 0x0224 - int32u: 1688,2748,3372
    0x0225 => {
        Name => 'PhaseOne_0x0225',
        Format => 'int16s',
        Flags => ['Unknown','Hidden'],
        PrintConv => 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val',
    },
    0x0226 => {
        Name => 'ColorMatrix2',
        PrintConv => q{
            my @a = map { sprintf('%.3f', $_) } split ' ', $val;
            return "@a";
        },
    },
    # 0x0227 - int32u: 0,1
    # 0x0228 - int32u: 1,2
    # 0x0229 - int32s: -2,0
    # 0x0242 - int32u: 55
    # 0x0244 - int32u: 102
    # 0x0300 - int32u: 100,101,102
    0x0301 => 'FirmwareVersions',
    # 0x0304 - int32u: 8,3073,3076
    0x0400 => {
        Name => 'ShutterSpeedValue',
        ValueConv => 'abs($val)<100 ? 2**(-$val) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x0401 => {
        Name => 'ApertureValue',
        ValueConv => '2 ** ($val / 2)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x0402 => {
        Name => 'ExposureCompensation',
        Format => 'float',
        PrintConv => 'sprintf("%.3f",$val)',
    },
    0x0403 => {
        Name => 'FocalLength',
        Format => 'int32u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    # 0x0404 - int32u: 0,3
    # 0x0405 - int32u? (big numbers)
    # 0x0406 - int32u: 1
    # 0x0407 - float: -0.333 (exposure compensation again?)
    # 0x0408-0x0409 - int32u: 1
    0x0410 => 'CameraModel',
    # 0x0411 - int32u: 33556736
    0x0412 => 'LensModel',
    0x0414 => {
        Name => 'MaxApertureValue',
        ValueConv => '2 ** ($val / 2)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x0415 => {
        Name => 'MinApertureValue',
        ValueConv => '2 ** ($val / 2)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    # 0x0416 - float: (min focal length? ref LibRaw, Credo50) (but looks more like an int32u date for the 645DF - PH)
    # 0x0417 - float: 80 (max focal length? ref LibRaw)
);

# Phase One metadata (ref 1)
%Image::ExifTool::PhaseOne::SensorCalibration = (
    PROCESS_PROC => \&ProcessSensorCalibration,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    TAG_PREFIX => 'SensorCalibration',
    0x0400 => {
        Name => 'SensorDefects',
        # list of defects. each defect is 4 x int16u values:
        # 0=column, 1=row, 2=type (129=bad pixel, 131=bad column), 3=?
        # (but it isn't really worth the time decoding this -- it can be a few hundred kB)
        Format => 'undef',
        Binary => 1,
    },
    0x0401 => {
        Name => 'AllColorFlatField1',
        Format => 'undef',
        Flags => ['Unknown','Binary'],
    },
    0x0404 => { #PH
        Name => 'SensorCalibration_0x0404',
        Format => 'string',
        Flags => ['Unknown','Hidden'],
    },
    0x0405 => { #PH
        Name => 'SensorCalibration_0x0405',
        Format => 'string',
        Flags => ['Unknown','Hidden'],
    },
    0x0406 => { #PH
        Name => 'SensorCalibration_0x0406',
        Format => 'string',
        Flags => ['Unknown','Hidden'],
    },
    0x0407 => { #PH
        Name => 'SerialNumber',
        Format => 'string',
    },
    0x0408 => { #PH
        Name => 'SensorCalibration_0x0408',
        Format => 'float',
        Flags => ['Unknown','Hidden'],
    },
    0x040b => {
        Name => 'RedBlueFlatField',
        Format => 'undef',
        Flags => ['Unknown','Binary'],
    },
    0x0410 => {
        Name => 'AllColorFlatField2',
        Format => 'undef',
        Flags => ['Unknown','Binary'],
    },
    # 0x0412 - used by dcraw
    0x0413 => { #PH
        Name => 'SensorCalibration_0x0413',
        Format => 'double',
        Flags => ['Unknown','Hidden'],
    },
    0x0416 => {
        Name => 'AllColorFlatField3',
        Format => 'undef',
        Flags => ['Unknown','Binary'],
    },
    0x0419 => {
        Name => 'LinearizationCoefficients1',
        Format => 'float',
        PrintConv => 'my @a=split " ",$val;join " ", map { sprintf("%.5g",$_) } @a',
    },
    0x041a => {
        Name => 'LinearizationCoefficients2',
        Format => 'float',
        PrintConv => 'my @a=split " ",$val;join " ", map { sprintf("%.5g",$_) } @a',
    },
    0x041c => { #PH
        Name => 'SensorCalibration_0x041c',
        Format => 'float',
        Flags => ['Unknown','Hidden'],
    },
    0x041e => { #PH
        Name => 'SensorCalibration_0x041e',
        Format => 'undef',
        Flags => ['Unknown','Hidden'],
        ValueConv => q{
            my $order = GetByteOrder();
            if (length $val >= 8 and SetByteOrder(substr($val,0,2))) {
                $val = ReadValue(\$val, 4, 'float', undef, length($val)-4);
                SetByteOrder($order);
            }
            return $val;
        },
    },
);

#------------------------------------------------------------------------------
# Do HTML dump of an IFD entry
# Inputs: 0) ExifTool ref, 1) tag table ref, 3) tag ID, 4) tag value,
#         5) IFD entry offset, 6) IFD entry size, 7) parameter hash
sub HtmlDump($$$$$$%)
{
    my ($et, $tagTablePtr, $tagID, $value, $entry, $entryLen, %parms) = @_;
    my ($dirName, $index, $formatStr, $base, $size, $valuePtr) =
        @parms{qw(DirName Index Format DataPos Size Start)};
    my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
    my ($tagName, $colName, $subdir);
    my $count = $parms{Count} || $size;
    if ($tagInfo) {
        $tagName = $$tagInfo{Name};
        $subdir = $$tagInfo{SubDirectory};
        if ($$tagInfo{Format}) {
            $formatStr = $$tagInfo{Format};
            $count = $size / Image::ExifTool::FormatSize($formatStr);
        }
    } else {
        $tagName = sprintf("Tag 0x%.4x", $tagID);
    }
    my $dname = sprintf("${dirName}-%.2d", $index);
    # build our tool tip
    my $fstr = "$formatStr\[$count]";
    my $tip = sprintf("Tag ID: 0x%.4x\n", $tagID) .
              "Format: $fstr\nSize: $size bytes\n";
    if ($size > 4) {
        $tip .= sprintf("Value offset: 0x%.4x\n", $valuePtr);
        $tip .= sprintf("Actual offset: 0x%.4x\n", $valuePtr + $base);
        $tip .= sprintf("Offset base: 0x%.4x\n", $base);
        $colName = "<span class=F>$tagName</span>";
    } else {
        $colName = $tagName;
    }
    unless (ref $value) {
        my $tval = length($value) > 32 ? substr($value,0,28) . '[...]' : $value;
        $tval =~ tr/\x00-\x1f\x7f-\xff/./;
        $tip .= "Value: $tval";
    }
    $et->HDump($entry+$base, $entryLen, "$dname $colName", $tip, 1);
    if ($size > 4) {
        my $dumpPos = $valuePtr + $base;
        # add value data block
        $et->HDump($dumpPos,$size,"$tagName value",'SAME', $subdir ? 0x04 : 0);
    }
}

#------------------------------------------------------------------------------
# Process Phase One sensor calibration directory (ref 1)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessSensorCalibration($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $$dirInfo{DataLen} - $dirStart;
    my $verbose = $et->Options('Verbose');
    my $htmlDump = $$et{HTML_DUMP};

    return 0 unless $dirLen >= 12 and SetByteOrder(substr($$dataPt, $dirStart, 2));
    # get offset to start of SensorCalibration directory
    my $ifdStart = Get32u($dataPt, $dirStart + 8);
    return 0 if $ifdStart > $dirLen - 4;
    my $numEntries = Get32u($dataPt, $dirStart + $ifdStart);
    my $ifdEnd = $ifdStart + 8 + 12 * $numEntries;
    return 0 if $numEntries < 2 or $numEntries > 300 or $ifdEnd > $dirLen;
    $et->VerboseDir('SensorCalibration', $numEntries);
    if ($htmlDump) {
        $et->HDump($dirStart + $dataPos, 8, 'SensorCalibration header');
        $et->HDump($dirStart + $dataPos + 8, 4, 'SensorCalibration IFD offset');
        $et->HDump($dirStart + $dataPos + $ifdStart, 4, 'SensorCalibration entries',
                   "Entry count: $numEntries");
        $et->HDump($dirStart + $dataPos + $ifdStart + 4, 4, '[unused]');
    }
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + $ifdStart + 8 + 12 * $index;
        my $tagID = Get32u($dataPt, $entry);
        my $size = Get32u($dataPt, $entry+4);
        my $valuePtr = $entry + 8;
        if ($size > 4) {
            if ($size > 0x7fffffff) {
                $et->Warn("Invalid size for SensorCalibration IFD entry $index");
                return 0;
            }
            $valuePtr = Get32u($dataPt, $valuePtr);
            if ($valuePtr + $size > $dirLen) {
                $et->Warn(sprintf("Invalid offset 0x%.4x for SensorCalibration IFD entry $index",$valuePtr));
                return 0;
            }
            $valuePtr += $dirStart;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        my $formatStr;
        if ($tagInfo) {
            $formatStr = $$tagInfo{Format};
        } else {
            next unless $verbose or $htmlDump;
        }
        unless ($formatStr) {
            my $value = substr($$dataPt, $valuePtr, $size);
            if ($value =~ /^[\w]+\0$/) {
                $formatStr = 'string';
            } else {
                $formatStr = ($size % 4) ? 'undef' : 'int32s';
            }
        }
        my $value = ReadValue($dataPt,$valuePtr,$formatStr,undef,$size);
        my %parms = (
            DirName => 'SensorCalibration',
            Index   => $index,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Size    => $size,
            Start   => $valuePtr,
            Format  => $formatStr,
        );
        $htmlDump and HtmlDump($et, $tagTablePtr, $tagID, $value, $entry, 12, %parms);
        $et->HandleTag($tagTablePtr, $tagID, $value, %parms);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Phase One maker notes
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessPhaseOne($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $$dirInfo{DataLen} - $dirStart;
    my $binary = $et->Options('Binary');
    my $verbose = $et->Options('Verbose');
    my $htmlDump = $$et{HTML_DUMP};

    return 0 if $dirLen < 12;
    my $hdr = substr($$dataPt, $dirStart, 12);
    return 0 unless $hdr =~ /^(IIII.waR|MMMMRaw.)/s;
    SetByteOrder(substr($hdr, 0, 2));
    # get offset to start of PhaseOne directory
    my $ifdStart = Get32u(\$hdr, 8);
    return 0 if $ifdStart > $dirLen - 4;
    # get number of entries in PhaseOne directory
    my $numEntries = Get32u($dataPt, $dirStart + $ifdStart);
    my $ifdEnd = $ifdStart + 8 + 16 * $numEntries;
    return 0 if $numEntries < 2 or $numEntries > 300 or $ifdEnd > $dirLen;
    $et->VerboseDir('PhaseOne', $numEntries);
    if ($htmlDump) {
        $et->HDump($dirStart + $dataPos, 8, 'PhaseOne header');
        $et->HDump($dirStart + $dataPos + 8, 4, 'PhaseOne IFD offset');
        $et->HDump($dirStart + $dataPos + $ifdStart, 4, "PhaseOne entries",
                   "Entry count: $numEntries");
        $et->HDump($dirStart + $dataPos + $ifdStart + 4, 4, '[unused]');
    }
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + $ifdStart + 8 + 16 * $index;
        my $tagID = Get32u($dataPt, $entry);
        my $format = Get32u($dataPt, $entry+4);
        my $size = Get32u($dataPt, $entry+8);
        if ($format < 1 or $format > 13) {
            $et->Warn("Invalid PhaseOne IFD entry $index",1);
            return 0;
        }
        unless (defined $formatSize[$format]) {
            $et->WarnOnce("Unrecognized PhaseOne format type $format",1);
            $formatSize[$format] = 1;
            $formatName[$format] = 'undef';
        }
        my $count = int($size / $formatSize[$format]);
        my $valuePtr = $entry + 12;
        if ($size > 4) {
            if ($size > 0x7fffffff) {
                $et->Warn("Invalid size for PhaseOne IFD entry $index");
                return 0;
            }
            $valuePtr = Get32u($dataPt, $valuePtr);
            if ($valuePtr + $size > $dirLen) {
                $et->Warn(sprintf("Invalid offset 0x%.4x for PhaseOne IFD entry $index",$valuePtr));
                return 0;
            }
            $valuePtr += $dirStart;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        my $formatStr = $formatName[$format];
        if ($tagInfo) {
            $formatStr = $$tagInfo{Format} if $$tagInfo{Format};
        } else {
            next unless $verbose or $htmlDump;
        }
        my $value;
        if ($count > 100000 and not $binary) {
            $value = \ "Binary data $size bytes";
        } else {
            $value = ReadValue($dataPt,$valuePtr,$formatStr,$count,$size);
            # PhaseOne uses the same format code for 'int32u' and 'float',
            # so assume that they may also use this for 'int32s'. grrr...
            if ($formatStr eq 'int32u') {
                my ($val) = split ' ', $value;
                # assume signed if it looks like a negative integer
                if (($val & 0xff800000) == 0xff800000) {
                    $formatStr = 'int32s';
                    $value = ReadValue($dataPt,$valuePtr,$formatStr,$count,$size);
                } else {
                    # get floating point exponent (has bias of 127)
                    my $exp = ($val & 0x7f800000) >> 23;
                    if ($exp > 120 and $exp < 140) {
                        $formatStr = 'float';
                        $value = ReadValue($dataPt,$valuePtr,$formatStr,$count,$size);
                    }
                }                    
            }
        }
        my %parms = (
            DirName => 'PhaseOne',
            Index   => $index,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Size    => $size,
            Start   => $valuePtr,
            Format  => $formatStr,
            Count   => $count
        );
        $htmlDump and HtmlDump($et, $tagTablePtr, $tagID, $value, $entry, 16, %parms);
        $et->HandleTag($tagTablePtr, $tagID, $value, %parms);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PhaseOne - Phase One maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to decode Phase
One maker notes.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PhaseOne Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
