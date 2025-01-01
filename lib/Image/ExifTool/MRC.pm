#------------------------------------------------------------------------------
# File:         MRC.pm
#
# Description:  Read MRC (Medical Research Council) image files
#
# Revisions:    2021-04-21 - P. Harvey Created
#
# References:   1) https://www.ccpem.ac.uk/mrc_format/mrc2014.php
#               2) http://legacy.ccp4.ac.uk/html/library.html
#               3) https://github.com/ccpem/mrcfile/blob/master/mrcfile/dtypes.py
#
# Notes:        The header is basically identical to the older CCP4 file format
#------------------------------------------------------------------------------

package Image::ExifTool::MRC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

my %bool = (
    Format => 'int8u',
    PrintConv => { 0 => 'No', 1 => 'Yes' } 
);

%Image::ExifTool::MRC::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    FORMAT => 'int32u',
    NOTES => q{
        Tags extracted from Medical Research Council (MRC) format imaging files. 
        See L<https://www.ccpem.ac.uk/mrc_format/mrc2014.php> for the specification.
    },
    0 => 'ImageWidth',
    1 => 'ImageHeight',
    2 => {
        Name => 'ImageDepth',
        Notes => q{
            number of sections. Use ExtractEmbedded option to extract metadata for all
            sections
        },
        RawConv => '$$self{ImageDepth} = $val',
    },
    3 => {
        Name => 'ImageMode',
        PrintConv => {
            0 => '8-bit signed integer',
            1 => '16-bit signed integer',
            2 => '32-bit signed real',
            3 => 'complex 16-bit integer',
            4 => 'complex 32-bit real',
            6 => '16-bit unsigned integer',
        },
    },
    4 => { Name => 'StartPoint', Format => 'int32u[3]' },
    7 => { Name => 'GridSize',   Format => 'int32u[3]' },
    10 => { Name => 'CellWidth', Format => 'float', Notes => 'cell size in angstroms' },
    11 => { Name => 'CellHeight',Format => 'float' },
    12 => { Name => 'CellDepth', Format => 'float' },
    13 => { Name => 'CellAlpha', Format => 'float' },
    14 => { Name => 'CellBeta',  Format => 'float' },
    15 => { Name => 'CellGamma', Format => 'float' },
    16 => { Name => 'ImageWidthAxis',  PrintConv => { 1 => 'X', 2 => 'Y', 3 => 'Z' } },
    17 => { Name => 'ImageHeightAxis', PrintConv => { 1 => 'X', 2 => 'Y', 3 => 'Z' } },
    18 => { Name => 'ImageDepthAxis',  PrintConv => { 1 => 'X', 2 => 'Y', 3 => 'Z' } },
    19 => { Name => 'DensityMin', Format => 'float' },
    20 => { Name => 'DensityMax', Format => 'float' },
    21 => { Name => 'DensityMean',Format => 'float' },
    22 => 'SpaceGroupNumber',
    23 => { Name => 'ExtendedHeaderSize', RawConv => '$$self{ExtendedHeaderSize} = $val' },
    26 => { Name => 'ExtendedHeaderType', Format => 'string[4]', RawConv => '$$self{ExtendedHeaderType} = $val' },
    27 => 'MRCVersion',
    49 => { Name => 'Origin',     Format => 'float[3]' },
    53 => { Name => 'MachineStamp', Format => 'int8u[4]', PrintConv => 'sprintf("0x%.2x 0x%.2x 0x%.2x 0x%.2x",split " ", $val)' },
    54 => { Name => 'RMSDeviation', Format => 'float' },
    55 => { Name => 'NumberOfLabels', RawConv => '$$self{NLab} = $val' },
    56 => { Name => 'Label0', Format => 'string[80]', Condition => '$$self{NLab} > 0' },
    76 => { Name => 'Label1', Format => 'string[80]', Condition => '$$self{NLab} > 1' },
    96 => { Name => 'Label2', Format => 'string[80]', Condition => '$$self{NLab} > 2' },
   116 => { Name => 'Label3', Format => 'string[80]', Condition => '$$self{NLab} > 3' },
   136 => { Name => 'Label4', Format => 'string[80]', Condition => '$$self{NLab} > 4' },
   156 => { Name => 'Label5', Format => 'string[80]', Condition => '$$self{NLab} > 5' },
   176 => { Name => 'Label6', Format => 'string[80]', Condition => '$$self{NLab} > 6' },
   196 => { Name => 'Label7', Format => 'string[80]', Condition => '$$self{NLab} > 7' },
   216 => { Name => 'Label8', Format => 'string[80]', Condition => '$$self{NLab} > 8' },
   236 => { Name => 'Label9', Format => 'string[80]', Condition => '$$self{NLab} > 9' },
);

%Image::ExifTool::MRC::FEI12 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup (way too many!)
    NOTES => 'Tags extracted from FEI1 and FEI2 extended headers.',
    0 => { Name => 'MetadataSize',    Format => 'int32u', RawConv => '$$self{MetadataSize} = $val' },
    4 => { Name => 'MetadataVersion', Format => 'int32u' },
    8 => {
        Name => 'Bitmask1',
        Format => 'int32u',
        RawConv => '$$self{BitM} = $val',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
    12 => {
        Name => 'TimeStamp',
        Format => 'double', 
        Condition => '$$self{BitM} & 0x01',
        Groups => { 2 => 'Time'},
        # shift from days since Dec 30, 1899 to Unix epoch of Jan 1, 1970
        # (my sample looks like local time, although it should be UTC)
        ValueConv => 'ConvertUnixTime(($val-25569)*24*3600)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    20  => { Name => 'MicroscopeType',  Format => 'string[16]', Condition => '$$self{BitM} & 0x02' },
    36  => { Name => 'MicroscopeID',    Format => 'string[16]', Condition => '$$self{BitM} & 0x04' },
    52  => { Name => 'Application',     Format => 'string[16]', Condition => '$$self{BitM} & 0x08' },
    68  => { Name => 'AppVersion',      Format => 'string[16]', Condition => '$$self{BitM} & 0x10' },
    84  => { Name => 'HighTension',     Format => 'double',     Condition => '$$self{BitM} & 0x20', Notes => 'volts' },
    92  => { Name => 'Dose',            Format => 'double',     Condition => '$$self{BitM} & 0x40', Notes => 'electrons/m2' },
    100 => { Name => 'AlphaTilt',       Format => 'double',     Condition => '$$self{BitM} & 0x80' },
    108 => { Name => 'BetaTilt',        Format => 'double',     Condition => '$$self{BitM} & 0x100' },
    116 => { Name => 'XStage',          Format => 'double',     Condition => '$$self{BitM} & 0x200' },
    124 => { Name => 'YStage',          Format => 'double',     Condition => '$$self{BitM} & 0x400' },
    132 => { Name => 'ZStage',          Format => 'double',     Condition => '$$self{BitM} & 0x800' },
    140 => { Name => 'TiltAxisAngle',   Format => 'double',     Condition => '$$self{BitM} & 0x1000' },
    148 => { Name => 'DualAxisRot',     Format => 'double',     Condition => '$$self{BitM} & 0x2000' },
    156 => { Name => 'PixelSizeX',      Format => 'double',     Condition => '$$self{BitM} & 0x4000' },
    164 => { Name => 'PixelSizeY',      Format => 'double',     Condition => '$$self{BitM} & 0x8000' },
    220 => { Name => 'Defocus',         Format => 'double',     Condition => '$$self{BitM} & 0x400000' },
    228 => { Name => 'STEMDefocus',     Format => 'double',     Condition => '$$self{BitM} & 0x800000' },
    236 => { Name => 'AppliedDefocus',  Format => 'double',     Condition => '$$self{BitM} & 0x1000000' },
    244 => { Name => 'InstrumentMode',  Format => 'int32u',     Condition => '$$self{BitM} & 0x2000000', PrintConv => { 1 => 'TEM', 2 => 'STEM' } },
    248 => { Name => 'ProjectionMode',  Format => 'int32u',     Condition => '$$self{BitM} & 0x4000000', PrintConv => { 1 => 'Diffraction', 2 => 'Imaging' } },
    252 => { Name => 'ObjectiveLens',   Format => 'string[16]', Condition => '$$self{BitM} & 0x8000000' },
    268 => { Name => 'HighMagnificationMode', Format => 'string[16]', Condition => '$$self{BitM} & 0x10000000' },
    284 => { Name => 'ProbeMode',       Format => 'int32u',     Condition => '$$self{BitM} & 0x20000000', PrintConv => { 1 => 'Nano', 2 => 'Micro' } },
    288 => { Name => 'EFTEMOn',         %bool,                  Condition => '$$self{BitM} & 0x40000000' },
    289 => { Name => 'Magnification',   Format => 'double',     Condition => '$$self{BitM} & 0x80000000' },
    297 => {
        Name => 'Bitmask2',
        Format => 'int32u',
        RawConv => '$$self{BitM} = $val',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
    301 => { Name => 'CameraLength',    Format => 'double',     Condition => '$$self{BitM} & 0x01' },
    309 => { Name => 'SpotIndex',       Format => 'int32u',     Condition => '$$self{BitM} & 0x02' },
    313 => { Name => 'IlluminationArea',Format => 'double',     Condition => '$$self{BitM} & 0x04' },
    321 => { Name => 'Intensity',       Format => 'double',     Condition => '$$self{BitM} & 0x08' },
    329 => { Name => 'ConvergenceAngle',Format => 'double',     Condition => '$$self{BitM} & 0x10' },
    337 => { Name => 'IlluminationMode',Format => 'string[16]', Condition => '$$self{BitM} & 0x20' },
    353 => { Name => 'WideConvergenceAngleRange', %bool,        Condition => '$$self{BitM} & 0x40' },
    354 => { Name => 'SlitInserted',    %bool,                  Condition => '$$self{BitM} & 0x80' },
    355 => { Name => 'SlitWidth',       Format => 'double',     Condition => '$$self{BitM} & 0x100' },
    363 => { Name => 'AccelVoltOffset', Format => 'double',     Condition => '$$self{BitM} & 0x200' },
    371 => { Name => 'DriftTubeVolt',   Format => 'double',     Condition => '$$self{BitM} & 0x400' },
    379 => { Name => 'EnergyShift',     Format => 'double',     Condition => '$$self{BitM} & 0x800' },
    387 => { Name => 'ShiftOffsetX',    Format => 'double',     Condition => '$$self{BitM} & 0x1000' },
    395 => { Name => 'ShiftOffsetY',    Format => 'double',     Condition => '$$self{BitM} & 0x2000' },
    403 => { Name => 'ShiftX',          Format => 'double',     Condition => '$$self{BitM} & 0x4000' },
    411 => { Name => 'ShiftY',          Format => 'double',     Condition => '$$self{BitM} & 0x8000' },
    419 => { Name => 'IntegrationTime', Format => 'double',     Condition => '$$self{BitM} & 0x10000' },
    427 => { Name => 'BinningWidth',    Format => 'int32u',     Condition => '$$self{BitM} & 0x20000' },
    431 => { Name => 'BinningHeight',   Format => 'int32u',     Condition => '$$self{BitM} & 0x40000' },
    435 => { Name => 'CameraName',      Format => 'string[16]', Condition => '$$self{BitM} & 0x80000' },
    451 => { Name => 'ReadoutAreaLeft', Format => 'int32u',     Condition => '$$self{BitM} & 0x100000' },
    455 => { Name => 'ReadoutAreaTop',  Format => 'int32u',     Condition => '$$self{BitM} & 0x200000' },
    459 => { Name => 'ReadoutAreaRight',Format => 'int32u',     Condition => '$$self{BitM} & 0x400000' },
    463 => { Name => 'ReadoutAreaBottom',Format=> 'int32u',     Condition => '$$self{BitM} & 0x800000' },
    467 => { Name => 'CetaNoiseReduct', %bool,                  Condition => '$$self{BitM} & 0x1000000' },
    468 => { Name => 'CetaFramesSummed',Format => 'int32u',     Condition => '$$self{BitM} & 0x2000000' },
    472 => { Name => 'DirectDetElectronCounting', %bool,        Condition => '$$self{BitM} & 0x4000000' },
    473 => { Name => 'DirectDetAlignFrames',      %bool,        Condition => '$$self{BitM} & 0x8000000' },
    490 => {
        Name => 'Bitmask3',
        Format => 'int32u',
        RawConv => '$$self{BitM} = $val',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
    518 => { Name => 'PhasePlate',      %bool,                  Condition => '$$self{BitM} & 0x40' },
    519 => { Name => 'STEMDetectorName',Format => 'string[16]', Condition => '$$self{BitM} & 0x80' },
    535 => { Name => 'Gain',            Format => 'double',     Condition => '$$self{BitM} & 0x100' },
    543 => { Name => 'Offset',          Format => 'double',     Condition => '$$self{BitM} & 0x200' },
    571 => { Name => 'DwellTime',       Format => 'double',     Condition => '$$self{BitM} & 0x8000' },
    579 => { Name => 'FrameTime',       Format => 'double',     Condition => '$$self{BitM} & 0x10000' },
    587 => { Name => 'ScanSizeLeft',    Format => 'int32u',     Condition => '$$self{BitM} & 0x20000' },
    591 => { Name => 'ScanSizeTop',     Format => 'int32u',     Condition => '$$self{BitM} & 0x40000' },
    595 => { Name => 'ScanSizeRight',   Format => 'int32u',     Condition => '$$self{BitM} & 0x80000' },
    599 => { Name => 'ScanSizeBottom',  Format => 'int32u',     Condition => '$$self{BitM} & 0x100000' },
    603 => { Name => 'FullScanFOV_X',   Format => 'double',     Condition => '$$self{BitM} & 0x200000' },
    611 => { Name => 'FullScanFOV_Y',   Format => 'double',     Condition => '$$self{BitM} & 0x400000' },
    619 => { Name => 'Element',         Format => 'string[16]', Condition => '$$self{BitM} & 0x800000' },
    635 => { Name => 'EnergyIntervalLower', Format => 'double', Condition => '$$self{BitM} & 0x1000000' },
    643 => { Name => 'EnergyIntervalHigher',Format => 'double', Condition => '$$self{BitM} & 0x2000000' },
    651 => { Name => 'Method',          Format=> 'int32u',      Condition => '$$self{BitM} & 0x4000000' },
    655 => { Name => 'IsDoseFraction',  %bool,                  Condition => '$$self{BitM} & 0x8000000' },
    656 => { Name => 'FractionNumber',  Format => 'int32u',     Condition => '$$self{BitM} & 0x10000000' },
    660 => { Name => 'StartFrame',      Format => 'int32u',     Condition => '$$self{BitM} & 0x20000000' },
    664 => { Name => 'EndFrame',        Format => 'int32u',     Condition => '$$self{BitM} & 0x40000000' },
    668 => { Name =>'InputStackFilename',Format=> 'string[80]', Condition => '$$self{BitM} & 0x80000000' },
    748 => {
        Name => 'Bitmask4',
        Format => 'int32u',
        RawConv => '$$self{BitM} = $val',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
    752 => { Name => 'AlphaTiltMin',   Format => 'double',     Condition => '$$self{BitM} & 0x01' },
    760 => { Name => 'AlphaTiltMax',   Format => 'double',     Condition => '$$self{BitM} & 0x02' },
#
# FEI2 header starts here
#
    768 => { Name => 'ScanRotation',   Format => 'double',     Condition => '$$self{BitM} & 0x04' },
    776 => { Name => 'DiffractionPatternRotation',Format=>'double', Condition => '$$self{BitM} & 0x08' },
    784 => { Name => 'ImageRotation',  Format => 'double',     Condition => '$$self{BitM} & 0x10' },
    792 => { Name => 'ScanModeEnumeration',Format => 'int32u', Condition => '$$self{BitM} & 0x20', PrintConv => { 0 => 'Other', 1 => 'Raster', 2 => 'Serpentine' } },
    796 => {
        Name => 'AcquisitionTimeStamp',
        Format => 'int64u',
        Condition => '$$self{BitM} & 0x40',
        Groups => { 2 => 'Time' },
        # microseconds since 1970 UTC
        ValueConv => 'ConvertUnixTime($val / 1e6, 1, 6)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    804 => { Name => 'DetectorCommercialName', Format => 'string[16]', Condition => '$$self{BitM} & 0x80' },
    820 => { Name => 'StartTiltAngle', Format => 'double',     Condition => '$$self{BitM} & 0x100' },
    828 => { Name => 'EndTiltAngle',   Format => 'double',     Condition => '$$self{BitM} & 0x200' },
    836 => { Name => 'TiltPerImage',   Format => 'double',     Condition => '$$self{BitM} & 0x400' },
    844 => { Name => 'TitlSpeed',      Format => 'double',     Condition => '$$self{BitM} & 0x800' },
    852 => { Name => 'BeamCenterX',    Format => 'int32u',     Condition => '$$self{BitM} & 0x1000' },
    856 => { Name => 'BeamCenterY',    Format => 'int32u',     Condition => '$$self{BitM} & 0x2000' },
    860 => {
        Name => 'CFEGFlashTimeStamp',
        Format => 'int64u',
        Condition => '$$self{BitM} & 0x4000',
        Groups => { 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val / 1e6, 1, 6)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    868 => { Name => 'PhasePlatePosition',Format => 'int32u',  Condition => '$$self{BitM} & 0x8000' },
    872 => { Name => 'ObjectiveAperture', Format=>'string[16]',Condition => '$$self{BitM} & 0x10000' },
);

#------------------------------------------------------------------------------
# Extract metadata from a MRC image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MRC file
sub ProcessMRC($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tagTablePtr, $i);

    # verify this is a valid MRC file
    return 0 unless $raf->Read($buff, 1024) == 1024;
    # validate axes, "MAP" file type and machine stamp
    return 0 unless $buff =~ /^.{64}[\x01\x02\x03]\0\0\0[\x01\x02\x03]\0\0\0[\x01\x02\x03]\0\0\0.{132}MAP[\0 ](\x44\x44|\x44\x41|\x11\x11)\0\0/s;

    $et->SetFileType();
    SetByteOrder('II');
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    $tagTablePtr = GetTagTable('Image::ExifTool::MRC::Main');
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);

    # (I don't have any samples with extended headers for testing, so these are not yet decoded)
    if ($$et{ExtendedHeaderSize} and $$et{ExtendedHeaderType} =~ /^FEI[12]/) {
        unless ($raf->Read($buff,4)==4 and $raf->Seek(-4,1)) { # read metadata size
            $et->Warn('Error reading extended header'); 
            return 1;
        }
        my $size = Get32u(\$buff, 0);
        if ($size * $$et{ImageDepth} > $$et{ExtendedHeaderSize}) {
            $et->Warn('Corrupted extended header');
            return 1;
        }
        $dirInfo{DirLen} = $size;
        $tagTablePtr = GetTagTable('Image::ExifTool::MRC::FEI12');
        for ($i=0; ;) {
            $dirInfo{DataPos} = $raf->Tell();
            $raf->Read($buff, $size) == $size or $et->Warn("Error reading extended header $i"), last;
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
            last if ++$i >= $$et{ImageDepth};
            unless ($$et{OPTIONS}{ExtractEmbedded}) {
                $et->Warn('Use the ExtractEmbedded option to read metadata for all frames',3);
                last;
            }
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        }
        delete $$et{DOC_NUM};
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MRC - Read MRC meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
metadata from Medical Research Council (MRC) images.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://www.ccpem.ac.uk/mrc_format/mrc2014.php>

=item L<http://legacy.ccp4.ac.uk/html/library.html>

=item L<https://github.com/ccpem/mrcfile/blob/master/mrcfile/dtypes.py>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MRC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

