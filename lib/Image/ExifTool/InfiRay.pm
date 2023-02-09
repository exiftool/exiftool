#------------------------------------------------------------------------------
# File:         InfiRay.pm
#
# Description:  InfiRay IJPEG thermal image metadata
#
# Revisions:    2023-02-08 - M. Del Sol Created
#
# Notes:        Information in this document has been mostly gathered by
#               disassembling the P2 Pro Android app, version 1.0.8.230111.
#------------------------------------------------------------------------------

package Image::ExifTool::InfiRay;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

my %convFloat2 = (
    PrintConv => 'sprintf("%.2f", $val)',
);

my %convPercentage = (
    PrintConv => 'sprintf("%.1f %%", $val * 100)',
);

my %convMeters = (
    PrintConv => 'sprintf("%.2f m", $val / 128)',
);

my %convCelsius = (
    PrintConv => 'sprintf("%.2f C", $val)',
);

my %bool = (
	Format => 'int8u',
	PrintConv => { 0 => 'No', 1 => 'Yes' }
);

# InfiRay IJPEG version header, found in JPEGs APP2
%Image::ExifTool::InfiRay::Version = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG version header, found
        in JPEGs taken with the P2 Pro camera app.
    },
    0x00 => { Name => 'IJPEGVersion',         Format => 'int8u[4]' },
    #0x04 => { Name => 'IJPEGSignature',       Format => 'string' },
    0x0c => { Name => 'IJPEGOrgType',         Format => 'int8u' },
    0x0d => { Name => 'IJPEGDispType',        Format => 'int8u' },
    0x0e => { Name => 'IJPEGRotate',          Format => 'int8u' },
    0x0f => { Name => 'IJPEGMirrorFlip',      Format => 'int8u' },
    0x10 => { Name => 'ImageColorSwitchable', %bool },
    0x11 => { Name => 'ThermalColorPalette',  Format => 'int16u' },
    0x20 => { Name => 'IRDataSize',           Format => 'int64u' },
    0x28 => { Name => 'IRDataFormat',         Format => 'int16u' },
    0x2a => { Name => 'IRImageWidth',         Format => 'int16u' },
    0x2c => { Name => 'IRImageHeight',        Format => 'int16u' },
    0x2e => { Name => 'IRImageBpp',           Format => 'int8u' },
    0x30 => { Name => 'TempDataSize',         Format => 'int64u' },
    0x38 => { Name => 'TempDataFormat',       Format => 'int16u' },
    0x3a => { Name => 'TempImageWidth',       Format => 'int16u' },
    0x3c => { Name => 'TempImageHeight',      Format => 'int16u' },
    0x3e => { Name => 'TempImageBpp',         Format => 'int8u' },
    0x40 => { Name => 'VisibleDataSize',      Format => 'int64u' },
    0x48 => { Name => 'VisibleDataFormat',    Format => 'int16u' },
    0x4a => { Name => 'VisibleImageWidth',    Format => 'int16u' },
    0x4c => { Name => 'VisibleImageHeight',   Format => 'int16u' },
    0x4e => { Name => 'VisibleImageBpp',      Format => 'int8u' },
);

# InfiRay IJPEG factory temperature, found in IJPEG's APP4 section
%Image::ExifTool::InfiRay::FactoryTemp = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG camera factory
        defaults and calibration data.
    },
    0x00 => { Name => 'IJPEGTempVersion',   Format => 'int8u[4]' },
    0x04 => { Name => 'FactDefEmissivity',  Format => 'int8s' },
    0x05 => { Name => 'FactDefTau',         Format => 'int8s' },
    0x06 => { Name => 'FactDefTa',          Format => 'int16s' },
    0x08 => { Name => 'FactDefTu',          Format => 'int16s' },
    0x0a => { Name => 'FactDefDist',        Format => 'int16s' },
    0x0c => { Name => 'FactDefA0',          Format => 'int32s' },
    0x10 => { Name => 'FactDefB0',          Format => 'int32s' },
    0x14 => { Name => 'FactDefA1',          Format => 'int32s' },
    0x18 => { Name => 'FactDefB1',          Format => 'int32s' },
    0x1c => { Name => 'FactDefP0',          Format => 'int32s' },
    0x20 => { Name => 'FactDefP1',          Format => 'int32s' },
    0x24 => { Name => 'FactDefP2',          Format => 'int32s' },
    0x44 => { Name => 'FactRelSensorTemp',  Format => 'int16s' },
    0x46 => { Name => 'FactRelShutterTemp', Format => 'int16s' },
    0x48 => { Name => 'FactRelLensTemp',    Format => 'int16s' },
    0x64 => { Name => 'FactStatusGainOK',   %bool },
    0x65 => { Name => 'FactStatusEnvOK',    %bool },
    0x66 => { Name => 'FactStatusDistOK',   %bool },
    0x67 => { Name => 'FactStatusTempMap',  Format => 'int8s' },
    # Missing: ndist_table_len, ndist_table, nuc_t_table_len, nuc_t_table
);

# InfiRay IJPEG picture temperature information, found in IJPEG's APP5 section
%Image::ExifTool::InfiRay::PictureTemp = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG picture temperature
        information.
    },
    0x00 => { Name => 'EnvironmentTemp',  Format => 'float', %convCelsius },
    0x04 => { Name => 'Distance',         Format => 'float', %convMeters },
    0x08 => { Name => 'Emissivity',       Format => 'float', %convFloat2 },
    0x0c => { Name => 'Humidity',         Format => 'float', %convPercentage },
    0x10 => { Name => 'ReferenceTemp',    Format => 'float', %convCelsius },
    0x20 => { Name => 'TempUnit',         Format => 'int8u' },
    0x21 => { Name => 'ShowCenterTemp',   %bool },
    0x22 => { Name => 'ShowMaxTemp',      %bool },
    0x23 => { Name => 'ShowMinTemp',      %bool },
    0x24 => { Name => 'TempMeasureCount', Format => 'int16u' },
    # TODO: process extra measurements list
);

# InfiRay IJPEG visual-infrared mixing mode, found in IJPEG's APP6 section
%Image::ExifTool::InfiRay::MixMode = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG visual-infrared
        mixing mode section.
    },
    0x00 => { Name => 'MixMode',          Format => 'int8u' },
    0x01 => { Name => 'FusionIntensity',  Format => 'float', %convPercentage },
    0x05 => { Name => 'OffsetAdjustment', Format => 'float' },
    0x09 => { Name => 'CorrectionAsix',   Format => 'float[30]' },
);

# InfiRay IJPEG camera operation mode, found in IJPEG's APP7 section
#
# I do not know in what units these times are, or what do they represent.
%Image::ExifTool::InfiRay::OperationMode = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG camera operation
        mode section.
    },
    0x00 => { Name => 'WorkingMode',       Format => 'int8u' },
    0x01 => { Name => 'IntegralTime',      Format => 'int32u' },
    0x05 => { Name => 'IntegratTimeHdr',   Format => 'int32u' },
    0x09 => { Name => 'GainStable',        %bool },
    0x0a => { Name => 'TempControlEnable', %bool },
    0x0b => { Name => 'DeviceTemp',        Format => 'float', %convCelsius },
);

# InfiRay IJPEG isothermal information, found in IJPEG's APP8 section
#
# I have genuinely no clue what is the meaning of any of this information, or
# what is it used for.
%Image::ExifTool::InfiRay::Isothermal = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG picture isothermal
        information.
    },
    0x00 => { Name => 'IsothermalMax', Format => 'float' },
    0x04 => { Name => 'IsothermalMin', Format => 'float' },
    0x08 => { Name => 'ChromaBarMax',  Format => 'float' },
    0x0c => { Name => 'ChromaBarMin',  Format => 'float' },
);

# InfiRay IJPEG sensor information, found in IJPEG's APP9 section
%Image::ExifTool::InfiRay::SensorInfo = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG sensor information
        chunk.
    },
    0x000 => { Name => 'IRSensorManufacturer',      Format => 'string' },
    0x040 => { Name => 'IRSensorName',              Format => 'string' },
    0x080 => { Name => 'IRSensorPartNumber',        Format => 'string' },
    0x0c0 => { Name => 'IRSensorSerialNumber',      Format => 'string' },
    0x100 => { Name => 'IRSensorFirmware',          Format => 'string' },
    0x140 => { Name => 'IRSensorAperture',          Format => 'float', %convFloat2 },
    0x144 => { Name => 'IRFocalLength',             Format => 'float', %convFloat2 },
    0x180 => { Name => 'VisibleSensorManufacturer', Format => 'string' },
    0x1c0 => { Name => 'VisibleSensorName',         Format => 'string' },
    0x200 => { Name => 'VisibleSensorPartNumber',   Format => 'string' },
    0x240 => { Name => 'VisibleSensorSerialNumber', Format => 'string' },
    0x280 => { Name => 'VisibleSensorFirmware',     Format => 'string' },
    0x2c0 => { Name => 'VisibleSensorAperture',     Format => 'float' },
    0x2c4 => { Name => 'VisibleFocalLength',        Format => 'float' },
);

__END__

=head1 NAME

Image::ExifTool::InfiRay - InfiRay IJPEG thermal image metadata

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
metadata and thermal-related information of pictures saved by the InfiRay
IJPEG SDK, used in cameras such as the P2 Pro.

=head1 AUTHOR

Copyright 2003-2023, Marcos Del Sol Vives (marcos at orca.pet)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/InfiRay Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
