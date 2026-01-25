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
use Image::ExifTool::Exif;

$VERSION = '1.12';

sub WritePhaseOne($$$);
sub ProcessPhaseOne($$$);

# default formats based on PhaseOne format size
my @formatName = ( undef, 'string', 'int16s', undef, 'int32s' );

# Phase One maker notes (ref PH)
%Image::ExifTool::PhaseOne::Main = (
    PROCESS_PROC => \&ProcessPhaseOne,
    WRITE_PROC => \&WritePhaseOne,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => '1',
    FORMAT => 'int32s',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    VARS => { ENTRY_SIZE => 16 }, # (entries contain a format field)
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
    0x0102 => { Name => 'SerialNumber', Format => 'string' },
    # 0x0103 - int32u: 19,20,59769034
    # 0x0104 - int32u: 50,200
    0x0105 => 'ISO',
    0x0106 => {
        Name => 'ColorMatrix1',
        Format => 'float',
        Count => 9,
        PrintConv => q{
            my @a = map { sprintf('%.3f', $_) } split ' ', $val;
            return "@a";
        },
        PrintConvInv => '$val',
    },
    0x0107 => { Name => 'WB_RGBLevels', Format => 'float', Count => 3 },
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
            0 => 'Uncompressed', #https://github.com/darktable-org/darktable/issues/7308
            1 => 'RAW 1', #? (encrypted)
            2 => 'RAW 2', #? (encrypted)
            3 => 'IIQ L', # (now "L14", ref IB)
            # 4?
            5 => 'IIQ S',
            6 => 'IIQ Sv2', # (now "S14" for "IIQ 14 Smart" and "IIQ 14 Sensor+", ref IB)
            8 => 'IIQ L16', #IB ("IIQ 16 Extended" and "IIQ 16 Large")
        },
    },
    0x010f => {
        Name => 'RawData',
        Format => 'undef', # (actually 2-byte integers, but don't convert)
        Binary => 1,
        IsImageData => 1,
        PutFirst => 1,
        Writable => 0,
        Drop => 1, # don't copy to other file types
    },
    0x0110 => { #1
        Name => 'SensorCalibration',
        SubDirectory => { TagTable => 'Image::ExifTool::PhaseOne::SensorCalibration' },
    },
    0x0112 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'int32u',
        Writable => 0, # (don't write because this is an encryption key for RawFormat 1 and 2)
        Priority => 0,
        Shift => 'Time',
        Groups => { 2 => 'Time' },
        Notes => 'may be used as a key to encrypt the raw data', #1
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x0113 => 'ImageNumber', # (NC)
    0x0203 => { Name => 'Software', Format => 'string' },
    0x0204 => { Name => 'System',   Format => 'string' },
    # 0x020b - int32u: 0,1
    # 0x020c - int32u: 1,2
    # 0x020e - int32u: 1,3
    0x0210 => { # (NC) (used in linearization formula - ref 1)
        Name => 'SensorTemperature',
        Format => 'float',
        PrintConv => 'sprintf("%.2f C",$val)',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    0x0211 => { # (NC)
        Name => 'SensorTemperature2',
        Format => 'float',
        PrintConv => 'sprintf("%.2f C",$val)',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    0x0212 => {
        Name => 'UnknownDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        # (this time is within about 10 minutes before or after 0x0112)
        Unknown => 1,
        Shift => 'Time',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    # 0x0213 - int32u: 96,160,192,256,544 (same as 0x0101)
    # 0x0215 - int32u: 4,5
    # 0x021a - used by dcraw
    0x021c => { Name => 'StripOffsets', Binary => 1, Writable => 0 },
    0x021d => 'BlackLevel', #1
    # 0x021e - int32u: 1
    # 0x0220 - int32u: 32
    # 0x0221 - float: 0-271
    0x0222 => 'SplitColumn', #1
    0x0223 => { Name => 'BlackLevelData', Format => 'int16u', Count => -1, Binary => 1 }, #1
    # 0x0224 - int32u: 1688,2748,3372
    0x0225 => {
        Name => 'PhaseOne_0x0225',
        Format => 'int16s',
        Count => -1,
        Flags => ['Unknown','Hidden'],
        PrintConv => \&Image::ExifTool::LimitLongValues,
    },
    0x0226 => {
        Name => 'ColorMatrix2',
        Format => 'float',
        Count => 9,
        PrintConv => q{
            my @a = map { sprintf('%.3f', $_) } split ' ', $val;
            return "@a";
        },
        PrintConvInv => '$val',
    },
    # 0x0227 - int32u: 0,1
    # 0x0228 - int32u: 1,2
    # 0x0229 - int32s: -2,0
    0x0267 => { #PH
        Name => 'AFAdjustment',
        Format => 'float',
    },
    0x022b => { #PH
        Name => 'PhaseOne_0x022b',
        Format => 'float',
        Flags => ['Unknown','Hidden'],
    },
    # 0x0242 - int32u: 55
    # 0x0244 - int32u: 102
    # 0x0245 - float: 1.2
    0x0258 => { #PH
        Name => 'PhaseOne_0x0258',
        Format => 'int16s',
        Flags => ['Unknown','Hidden'],
        PrintConv => \&Image::ExifTool::LimitLongValues,
    },
    0x025a => { #PH
        Name => 'PhaseOne_0x025a',
        Format => 'int16s',
        Flags => ['Unknown','Hidden'],
        PrintConv => \&Image::ExifTool::LimitLongValues,
    },
    0x0262 => { Name => 'SequenceID', Format => 'string' },
    0x0263 => {
        Name => 'SequenceKind',
        PrintConv => {
            0 => 'Bracketing: Shutter Speed',
            1 => 'Bracketing: Aperture',
            2 => 'Bracketing: ISO',
            3 => 'Hyperfocal',
            4 => 'Time Lapse',
            5 => 'HDR',
            6 => 'Focus Stacking',
        },
        PrintConvInv => '$val',
    },
    0x0264 => 'SequenceFrameNumber',
    0x0265 => 'SequenceFrameCount',
    # 0x0300 - int32u: 100,101,102
    0x0301 => { Name => 'FirmwareVersions', Format => 'string' },
    # 0x0304 - int32u: 8,3073,3076
    0x0400 => {
        Name => 'ShutterSpeedValue',
        Format => 'float',
        ValueConv => 'abs($val)<100 ? 2**(-$val) : 0',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : -100',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0401 => {
        Name => 'ApertureValue',
        Format => 'float',
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0402 => {
        Name => 'ExposureCompensation',
        Format => 'float',
        PrintConv => 'sprintf("%.3f",$val)',
        PrintConvInv => '$val',
    },
    0x0403 => {
        Name => 'FocalLength',
        Format => 'float',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    # 0x0404 - int32u: 0,3
    # 0x0405 - int32u? (big numbers)
    # 0x0406 - int32u: 1
    # 0x0407 - float: -0.333 (exposure compensation again?)
    # 0x0408-0x0409 - int32u: 1
    0x0410 => { Name => 'CameraModel',  Format => 'string' },
    # 0x0411 - int32u: 33556736
    0x0412 => { Name => 'LensModel',    Format => 'string' },
    0x0414 => {
        Name => 'MaxApertureValue',
        Format => 'float',
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0415 => {
        Name => 'MinApertureValue',
        Format => 'float',
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    # 0x0416 - float: (min focal length? ref LR, Credo50) (but looks more like an int32u date for the 645DF - PH)
    # 0x0417 - float: 80 (max focal length? ref LR)
    0x0455 => { #PH
        Name => 'Viewfinder',
        Format => 'string',
    },
);

# Phase One metadata (ref 1)
%Image::ExifTool::PhaseOne::SensorCalibration = (
    PROCESS_PROC => \&ProcessPhaseOne,
    WRITE_PROC => \&WritePhaseOne,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    TAG_PREFIX => 'SensorCalibration',
    WRITE_GROUP => 'PhaseOne',
    VARS => { ENTRY_SIZE => 12 }, # (entries do not contain a format field)
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
        Writable => 1,
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
    0x040f => { #PH
        Name => 'SensorCalibration_0x040f',
        Format => 'undef',
        Flags => ['Unknown','Hidden'],
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
    0x0414 => { #PH
        Name => 'SensorCalibration_0x0414',
        Format => 'undef',
        Flags => ['Unknown','Hidden'],
        ValueConv => q{
            my $order = GetByteOrder();
            if (length $val >= 8 and SetByteOrder(substr($val,0,2))) {
                $val = ReadValue(\$val, 2, 'int16u', 1, length($val)-2) . ' ' .
                       ReadValue(\$val, 4, 'float', undef, length($val)-4);
                SetByteOrder($order);
            }
            return $val;
        },
    },
    0x0416 => {
        Name => 'AllColorFlatField3',
        Format => 'undef',
        Flags => ['Unknown','Binary'],
    },
    0x0418 => { #PH
        Name => 'SensorCalibration_0x0418',
        Format => 'undef',
        Flags => ['Unknown','Hidden'],
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
                $val = ReadValue(\$val, 2, 'int16u', 1, length($val)-2) . ' ' .
                       ReadValue(\$val, 4, 'float', undef, length($val)-4);
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
    my ($dirName, $index, $formatStr, $dataPos, $base, $size, $valuePtr) =
        @parms{qw(DirName Index Format DataPos Base Size Start)};
    my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
    my ($tagName, $colName, $subdir);
    my $count = $parms{Count} || $size;
    $base = 0 unless defined $base;
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
        $tip .= sprintf("Value offset: 0x%.4x\n", $valuePtr - $base);
        $tip .= sprintf("Actual offset: 0x%.4x\n", $valuePtr + $dataPos);
        $tip .= sprintf("Offset base: 0x%.4x\n", $dataPos + $base);
        $colName = "<span class=F>$tagName</span>";
    } else {
        $colName = $tagName;
    }
    unless (ref $value) {
        my $tval = length($value) > 32 ? substr($value,0,28) . '[...]' : $value;
        $tval =~ tr/\x00-\x1f\x7f-\xff/./;
        $tip .= "Value: $tval";
    }
    $et->HDump($entry+$dataPos, $entryLen, "$dname $colName", $tip, 1);
    if ($size > 4) {
        my $dumpPos = $valuePtr + $dataPos;
        # add value data block
        $et->HDump($dumpPos,$size,"$tagName value",'SAME', $subdir ? 0x04 : 0);
    }
}

#------------------------------------------------------------------------------
# Write PhaseOne maker notes (both types of PhaseOne IFD)
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: data block or undef on error
sub WritePhaseOne($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;      # allow dummy access to autoload this package

    # nothing to do if we aren't changing any PhaseOne tags
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    return undef unless %$newTags or $$et{DropTags} or $$et{EDIT_DIRS}{PhaseOne};

    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $$dirInfo{DataLen} - $dirStart;
    my $dirName = $$dirInfo{DirName};
    my $verbose = $et->Options('Verbose');

    return undef if $dirLen < 12;
    unless ($$tagTablePtr{VARS} and $$tagTablePtr{VARS}{ENTRY_SIZE}) {
        $et->Warn("No ENTRY_SIZE for $$tagTablePtr{TABLE_NAME}");
        return undef;
    }
    my $entrySize = $$tagTablePtr{VARS}{ENTRY_SIZE};
    my $ifdType = $$tagTablePtr{TAG_PREFIX} || 'PhaseOne';
    my $hdr = substr($$dataPt, $dirStart, 12);
    if ($entrySize == 16) {
        return undef unless $hdr =~ /^(IIII.waR|MMMMRaw.)/s;
    } elsif ($hdr !~ /^(IIII\x01\0\0\0|MMMM\0\0\0\x01)/s) {
        $et->Warn("Unrecognized $ifdType directory version");
        return undef;
    }
    SetByteOrder(substr($hdr, 0, 2));
    # get offset to start of PhaseOne directory
    my $ifdStart = Get32u(\$hdr, 8);
    return undef if $ifdStart + 8 > $dirLen;
    # initialize output directory buffer with (fixed) number of entries plus 4-byte padding
    my $dirBuff = substr($$dataPt, $dirStart + $ifdStart, 8);
    # get number of entries in PhaseOne directory
    my $numEntries = Get32u(\$dirBuff, 0);
    my $ifdEnd = $ifdStart + 8 + $entrySize * $numEntries;
    return undef if $numEntries < 2 or $numEntries > 300 or $ifdEnd > $dirLen;
    my $hdrBuff = $hdr;
    my $valBuff = '';   # buffer for value data
    my $fixup = Image::ExifTool::Fixup->new;
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + $ifdStart + 8 + $entrySize * $index;
        my $tagID = Get32u($dataPt, $entry);
        my $size = Get32u($dataPt, $entry+$entrySize-8);
        my ($formatSize, $formatStr);
        if ($entrySize == 16) {
            $formatSize = Get32u($dataPt, $entry+4);
            $formatStr = $formatName[$formatSize];
            unless ($formatStr) {
                $et->Warn("Possibly invalid $ifdType IFD entry $index",1);
                delete $$newTags{$tagID};   # make sure we don't try to change this one
            }
        } else {
            # (no format code for SensorCalibration IFD entries)
            $formatSize = 1;
            $formatStr = 'undef';
        }
        my $valuePtr = $entry + $entrySize - 4;
        if ($size > 4) {
            if ($size > 0x7fffffff) {
                $et->Error("Invalid size for $ifdType IFD entry $index",1);
                return undef;
            }
            $valuePtr = Get32u($dataPt, $valuePtr);
            if ($valuePtr + $size > $dirLen) {
                $et->Error(sprintf("Invalid offset 0x%.4x for $ifdType IFD entry $index",$valuePtr),1);
                return undef;
            }
            $valuePtr += $dirStart;
        }
        my $value = substr($$dataPt, $valuePtr, $size);
        my $tagInfo = $$newTags{$tagID} || $$tagTablePtr{$tagID};
        $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID) if $tagInfo and ref($tagInfo) ne 'HASH';
        if ($$newTags{$tagID}) {
            $formatStr = $$tagInfo{Format} if $$tagInfo{Format};
            my $count = int($size / Image::ExifTool::FormatSize($formatStr));
            my $val = ReadValue(\$value, 0, $formatStr, $count, $size);
            my $nvHash = $et->GetNewValueHash($tagInfo);
            if ($et->IsOverwriting($nvHash, $val)) {
                my $newVal = $et->GetNewValue($nvHash);
                # allow count to change for string and undef types only
                undef $count if $formatStr eq 'string' or $formatStr eq 'undef';
                my $newValue = WriteValue($newVal, $formatStr, $count);
                if (defined $newValue) {
                    $value = $newValue;
                    $size = length $newValue;
                    $et->VerboseValue("- $dirName:$$tagInfo{Name}", $val);
                    $et->VerboseValue("+ $dirName:$$tagInfo{Name}", $newVal);
                    ++$$et{CHANGED};
                }
            }
        } elsif ($tagInfo and $$tagInfo{SubDirectory}) {
            my $subTable = GetTagTable($$tagInfo{SubDirectory}{TagTable});
            my %subdirInfo = (
                DirName => $$tagInfo{Name},
                DataPt  => \$value,
                DataLen => length $value,
            );
            my $newValue = $et->WriteDirectory(\%subdirInfo, $subTable);
            if (defined $newValue and length($newValue)) {
                $value = $newValue;
                $size = length $newValue;
            }
        } elsif ($$et{DropTags} and (($tagInfo and $$tagInfo{Drop}) or $size > 8192)) {
            # decrease the number of entries in the directory
            Set32u(Get32u(\$dirBuff, 0) - 1, \$dirBuff, 0);
            next;   # drop this tag
        }
        # add the tagID, possibly format size, and size to this directory entry
        $dirBuff .= substr($$dataPt, $entry, $entrySize - 8) . Set32u($size);

        # pad value to an even 4-byte boundary just in case
        $value .= ("\0" x (4 - ($size & 0x03))) if $size & 0x03 or not $size;
        if ($size <= 4) {
            # store value in place of the IFD value pointer (already padded to 4 bytes)
            $dirBuff .= $value;
        } elsif ($tagInfo and $$tagInfo{PutFirst}) {
            # store value immediately after header
            $dirBuff .= Set32u(length $hdrBuff);
            $hdrBuff .= $value;
        } else {
            # store value at end of value buffer
            $fixup->AddFixup(length $dirBuff);
            $dirBuff .= Set32u(length $valBuff);
            $valBuff .= $value;
        }
    }
    # apply necessary fixup to offsets in PhaseOne directory
    $$fixup{Shift} = length $hdrBuff;
    $fixup->ApplyFixup(\$dirBuff);
    # set pointer to PhaseOneIFD in header
    Set32u(length($hdrBuff) + length($valBuff), \$hdrBuff, 8);
    return $hdrBuff . $valBuff . $dirBuff;
}

#------------------------------------------------------------------------------
# Read Phase One maker notes
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: This routine processes both the main PhaseOne IFD type (with 16 bytes
#        per entry), and the SensorCalibration IFD type (12 bytes per entry)
sub ProcessPhaseOne($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = ($$dirInfo{DataPos} || 0) + ($$dirInfo{Base} || 0);
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $$dirInfo{DataLen} - $dirStart;
    my $binary = $et->Options('Binary');
    my $verbose = $et->Options('Verbose');
    my $hash = $$et{ImageDataHash};
    my $htmlDump = $$et{HTML_DUMP};

    return 0 if $dirLen < 12;
    unless ($$tagTablePtr{VARS} and $$tagTablePtr{VARS}{ENTRY_SIZE}) {
        $et->Warn("No ENTRY_SIZE for $$tagTablePtr{TABLE_NAME}");
        return undef;
    }
    my $entrySize = $$tagTablePtr{VARS}{ENTRY_SIZE};
    my $ifdType = $$tagTablePtr{TAG_PREFIX} || 'PhaseOne';

    my $hdr = substr($$dataPt, $dirStart, 12);
    if ($entrySize == 16) {
        return 0 unless $hdr =~ /^(IIII.waR|MMMMRaw.)/s;
    } elsif ($hdr !~ /^(IIII\x01\0\0\0|MMMM\0\0\0\x01)/s) {
        $et->Warn("Unrecognized $ifdType directory version");
        return 0;
    }
    SetByteOrder(substr($hdr, 0, 2));
    # get offset to start of PhaseOne directory
    my $ifdStart = Get32u(\$hdr, 8);
    return 0 if $ifdStart + 8 > $dirLen;
    # get number of entries in PhaseOne directory
    my $numEntries = Get32u($dataPt, $dirStart + $ifdStart);
    my $ifdEnd = $ifdStart + 8 + $entrySize * $numEntries;
    return 0 if $numEntries < 2 or $numEntries > 300 or $ifdEnd > $dirLen;
    $et->VerboseDir($ifdType, $numEntries);
    if ($htmlDump) {
        $et->HDump($dirStart + $dataPos, 8, "$ifdType header");
        $et->HDump($dirStart + $dataPos + 8, 4, "$ifdType IFD offset");
        $et->HDump($dirStart + $dataPos + $ifdStart, 4, "$ifdType entries",
                   "Entry count: $numEntries");
        $et->HDump($dirStart + $dataPos + $ifdStart + 4, 4, '[unused]');
    }
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + $ifdStart + 8 + $entrySize * $index;
        my $tagID = Get32u($dataPt, $entry);
        my $size = Get32u($dataPt, $entry+$entrySize-8);
        my $valuePtr = $entry + $entrySize - 4;
        my ($formatSize, $formatStr, $value);
        if ($entrySize == 16) {
            # (format code only for the 16-byte IFD entry)
            $formatSize = Get32u($dataPt, $entry+4);
            $formatStr = $formatName[$formatSize];
            unless ($formatStr) {
                $et->Warn("Unrecognized $ifdType format size $formatSize",1);
                $formatSize = 1;
                $formatStr = 'undef';
            }
        } elsif ($size %4) {
            $formatSize = 1;
            $formatStr = 'undef';
        } else {
            $formatSize = 4;
            $formatStr = 'int32s';
        }
        if ($size > 4) {
            if ($size > 0x7fffffff) {
                $et->Warn("Invalid size for $ifdType IFD entry $index");
                return 0;
            }
            $valuePtr = Get32u($dataPt, $valuePtr);
            if ($valuePtr + $size > $dirLen) {
                $et->Warn(sprintf("Invalid offset 0x%.4x for $ifdType IFD entry $index",$valuePtr));
                return 0;
            }
            $valuePtr += $dirStart;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        if ($tagInfo) {
            $formatStr = $$tagInfo{Format} if $$tagInfo{Format};
        } else {
            next unless $verbose or $htmlDump;
        }
        my $count = int($size / Image::ExifTool::FormatSize($formatStr));
        if ($count > 100000 and not $binary) {
            $value = \ "Binary data $size bytes";
        } else {
            $value = ReadValue($dataPt,$valuePtr,$formatStr,$count,$size);
            # try to distinguish between the various format types
            if ($formatStr eq 'int32s') {
                my ($val) = split ' ', $value;
                if (defined $val) {
                    # get floating point exponent (has bias of 127)
                    my $exp = ($val & 0x7f800000) >> 23;
                    if ($exp > 120 and $exp < 140) {
                        $formatStr = 'float';
                        $value = ReadValue($dataPt,$valuePtr,$formatStr,$count,$size);
                    }
                }
            }
        }
        if ($hash and $tagInfo and $$tagInfo{IsImageData}) {
            my ($pos, $len) = ($valuePtr, $size);
            while ($len) {
                my $n = $len > 65536 ? 65536 : $len;
                my $tmp = substr($$dataPt, $pos, $n);
                $hash->add($tmp);
                $len -= $n;
                $pos += $n;
            }
            $et->VPrint(0, "$$et{INDENT}(ImageDataHash: $size bytes of PhaseOne:$$tagInfo{Name})\n");
        }
        my %parms = (
            DirName => $ifdType,
            Index   => $index,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Size    => $size,
            Start   => $valuePtr,
            Format  => $formatStr,
            Count   => $count
        );
        $htmlDump and HtmlDump($et, $tagTablePtr, $tagID, $value, $entry, $entrySize,
                               %parms, Base => $dirStart);
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

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

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
