#------------------------------------------------------------------------------
# File:         FLIR.pm
#
# Description:  Read FLIR meta information
#
# Revisions:    2013/03/28 - P. Harvey Created
#
# References:   1) https://exiftool.org/forum/index.php/topic,4898.0.html
#               2) http://www.nuage.ch/site/flir-i7-some-analysis/
#               3) http://www.workswell.cz/manuals/flir/hardware/A3xx_and_A6xx_models/Streaming_format_ThermoVision.pdf
#               4) http://support.flir.com/DocDownload/Assets/62/English/1557488%24A.pdf
#               5) http://code.google.com/p/dvelib/source/browse/trunk/flirPublicFormat/fpfConverter/Fpfimg.h?spec=svn3&r=3
#               6) https://exiftool.org/forum/index.php/topic,5538.0.html
#               JD) Jens Duttke private communication
#
# Glossary:     FLIR = Forward Looking Infra Red
#------------------------------------------------------------------------------

package Image::ExifTool::FLIR;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '1.23';

sub ProcessFLIR($$;$);
sub ProcessFLIRText($$$);
sub ProcessMeasInfo($$$);
sub GetImageType($$$);

my %temperatureInfo = (
    Writable => 'rational64u',
    Format => 'rational64s', # (have seen negative values)
);

# tag information for floating point Kelvin tag
my %floatKelvin = (
    Format => 'float',
    ValueConv => '$val - 273.15',
    PrintConv => 'sprintf("%.1f C",$val)',
);

# commonly used tag information elements
my %float1f = ( Format => 'float', PrintConv => 'sprintf("%.1f",$val)' );
my %float2f = ( Format => 'float', PrintConv => 'sprintf("%.2f",$val)' );
my %float6f = ( Format => 'float', PrintConv => 'sprintf("%.6f",$val)' );
my %float8g = ( Format => 'float', PrintConv => 'sprintf("%.8g",$val)' );

# FLIR makernotes tags (ref PH)
%Image::ExifTool::FLIR::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    PRIORITY => 0, # (unreliable)
    NOTES => q{
        Information extracted from the maker notes of JPEG images from thermal
        imaging cameras by FLIR Systems Inc.
    },
    0x01 => { #2
        Name => 'ImageTemperatureMax',
        %temperatureInfo,
        Notes => q{
            these temperatures may be in Celsius, Kelvin or Fahrenheit, but there is no
            way to tell which
        },
    },
    0x02 => { Name => 'ImageTemperatureMin', %temperatureInfo }, #2
    0x03 => { #1
        Name => 'Emissivity',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    # 0x04 does not change with temperature units; often 238, 250 or 457
    0x04 => { Name => 'UnknownTemperature', %temperatureInfo, Unknown => 1 },
    # 0x05,0x06 are unreliable.  As written by FLIR tools, these are the
    # CameraTemperatureRangeMax/Min, but the units vary depending on the
    # options settings.  But as written by some cameras, the values are different.
    0x05 => { Name => 'CameraTemperatureRangeMax', %temperatureInfo, Unknown => 1 },
    0x06 => { Name => 'CameraTemperatureRangeMin', %temperatureInfo, Unknown => 1 },
    # 0x07 - string[33] (some sort of image ID?)
    # 0x08 - string[33]
    # 0x09 - undef (tool info)
    # 0x0a - int32u: 1
    # 0x0f - rational64u: 0/1000
    # 0x10,0x11,0x12 - int32u: 0
    # 0x13 - rational64u: 0/1000
);

# FLIR FFF tag table (ref PH)
%Image::ExifTool::FLIR::FFF = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&ProcessFLIR,
    VARS => { ALPHA_FIRST => 1 },
    NOTES => q{
        Information extracted from FLIR FFF images and the APP1 FLIR segment of JPEG
        images.  These tags may also be extracted from the first frame of an FLIR
        SEQ file, or all frames if the ExtractEmbedded option is used.  Setting
        ExtractEmbedded to 2 also the raw thermal data from all frames.
    },
    "_header" => {
        Name => 'FFFHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::Header' },
    },
    # 0 = free (ref 3)
    0x01 => {
        Name => 'RawData',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::RawData' },
    },
    # 2 = GainMap (ref 3)
    # 3 = OffsMap (ref 3)
    # 4 = DeadMap (ref 3)
    0x05 => { #6
        Name => 'GainDeadData',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::GainDeadData' },
    },
    0x06 => { #6
        Name => 'CoarseData',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::CoarseData' },
    },
    # 7 = ImageMap (ref 3)
    0x0e => {
        Name => 'EmbeddedImage',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::EmbeddedImage' },
    },
    0x20 => {
        Name => 'CameraInfo', # (BasicData - ref 3)
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::CameraInfo' },
    },
    0x21 => { #6
        Name => 'MeasurementInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::MeasInfo' },
    },
    0x22 => {
        Name => 'PaletteInfo', # (ColorPal - ref 3)
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::PaletteInfo' },
    },
    0x23 => {
        Name => 'TextInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::TextInfo' },
    },
    0x24 => {
        Name => 'EmbeddedAudioFile',
        # (sometimes has an unknown 8-byte header)
        RawConv => q{
            return \$val if $val =~ s/^.{0,16}?RIFF/RIFF/s;
            $self->Warn('Unknown EmbeddedAudioFile format');
            return undef;
        },
    },
    # 0x27: 01 00 08 00 10 00 00 00
    0x28 => {
        Name => 'PaintData',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::PaintData' },
    },
    0x2a => {
        Name => 'PiP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FLIR::PiP',
            ByteOrder => 'LittleEndian',
        },
    },
    0x2b => {
        Name => 'GPSInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FLIR::GPSInfo',
            ByteOrder => 'LittleEndian',
        },
    },
    0x2c => {
        Name => 'MeterLink',
        SubDirectory => {
            TagTable => 'Image::ExifTool::FLIR::MeterLink' ,
            ByteOrder => 'LittleEndian'
        },
    },
    0x2e => {
        Name => 'ParameterInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::ParamInfo' },
    },
);

# FFF file header (ref PH)
%Image::ExifTool::FLIR::Header = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => 'Tags extracted from the FLIR FFF/AFF header.',
    4 => { Name => 'CreatorSoftware', Format => 'string[16]' },
);

# FLIR raw data record (ref PH)
%Image::ExifTool::FLIR::RawData = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    NOTES => q{
        The thermal image data may be stored either as raw data, or in PNG format.
        If stored as raw data, ExifTool adds a TIFF header to allow the data to be
        viewed as a TIFF image.  If stored in PNG format, the PNG image is extracted
        as-is.  Note that most FLIR cameras using the PNG format seem to write the
        16-bit raw image data in the wrong byte order.
    },
    0x00 => {
        # use this tag only to determine the byte order of the raw data
        # (the value should be 0x0002 if the byte order is correct)
        # - always "II" when RawThermalImageType is "TIFF"
        # - seen both "II" and "MM" when RawThermalImageType is "PNG"
        Name => 'RawDataByteOrder',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    0x01 => {
        Name => 'RawThermalImageWidth',
        RawConv => '$$self{RawThermalImageWidth} = $val',
    },
    0x02 => {
        Name => 'RawThermalImageHeight',
        RawConv => '$$self{RawThermalImageHeight} = $val',
    },
    # 0x03-0x05: 0
    # 0x06: raw image width - 1
    # 0x07: 0
    # 0x08: raw image height - 1
    # 0x09: 0,15,16
    # 0x0a: 0,2,3,11,12,13,30
    # 0x0b: 0,2
    # 0x0c: 0 or a large number
    # 0x0d: 0,3,4,6
    # 0x0e-0x0f: 0
    16 => {
        Name => 'RawThermalImageType',
        Format => 'undef[$size-0x20]',
        RawConv => 'Image::ExifTool::FLIR::GetImageType($self, $val, "RawThermalImage")',
    },
    16.1 => {
        Name => 'RawThermalImage',
        Groups => { 2 => 'Preview' },
        # make a copy in case we want to extract more of them with -ee2
        RawConv => 'my $copy = $$self{RawThermalImage}; \$copy',
    },
);

# GainDeadMap record (ref 6) (see RawData above)
%Image::ExifTool::FLIR::GainDeadData = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    NOTES => 'Information found in FFF-format .GAN calibration image files.',
    0x00 => {
        Name => 'GainDeadMapByteOrder',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    0x01 => {
        Name => 'GainDeadMapImageWidth',
        RawConv => '$$self{GainDeadMapImageWidth} = $val',
    },
    0x02 => {
        Name => 'GainDeadMapImageHeight',
        RawConv => '$$self{GainDeadMapImageHeight} = $val',
    },
    16 => {
        Name => 'GainDeadMapImageType',
        Format => 'undef[$size-0x20]',
        RawConv => 'Image::ExifTool::FLIR::GetImageType($self, $val, "GainDeadMapImage")',
    },
    16.1 => {
        Name => 'GainDeadMapImage',
        RawConv => 'my $copy = \$$self{GainDeadMapImage}; \$copy',
    },
);

# CoarseMap record (ref 6) (see RawData above)
%Image::ExifTool::FLIR::CoarseData = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    NOTES => 'Information found in FFF-format .CRS correction image files.',
    0x00 => {
        Name => 'CoarseMapByteOrder',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    0x01 => {
        Name => 'CoarseMapImageWidth',
        RawConv => '$$self{CoarseMapImageWidth} = $val',
    },
    0x02 => {
        Name => 'CoarseMapImageHeight',
        RawConv => '$$self{CoarseMapImageHeight} = $val',
    },
    16 => {
        Name => 'CoarseMapImageType',
        Format => 'undef[$size-0x20]',
        RawConv => 'Image::ExifTool::FLIR::GetImageType($self, $val, "CoarseMapImage")',
    },
    16.1 => {
        Name => 'CoarseMapImage',
        RawConv => 'my $copy = \$$self{CoarseMapImage}; \$copy',
    },
);

# "Paint colors" record (ref PH)
%Image::ExifTool::FLIR::PaintData = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    NOTES => 'Information generated by FLIR Tools "Paint colors" tool.',
    0x01 => {
        Name => 'PaintByteOrder',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    0x05 => {
        Name => 'PaintImageWidth',
        RawConv => '$$self{PaintImageWidth} = $val',
    },
    0x06 => {
        Name => 'PaintImageHeight',
        RawConv => '$$self{PaintImageHeight} = $val',
    },
    20 => {
        Name => 'PaintImageType',
        Format => 'undef[$size-0x28]',
        RawConv => 'Image::ExifTool::FLIR::GetImageType($self, $val, "PaintImage")',
    },
    20.1 => {
        Name => 'PaintImage',
        RawConv => 'my $copy = \$$self{PaintImage}; \$copy',
    },
);

# FLIR embedded image (ref 1)
%Image::ExifTool::FLIR::EmbeddedImage = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0 => {
        # use this tag only to determine the byte order
        # (the value should be 0x0003 if the byte order is correct)
        Name => 'EmbeddedImageByteOrder',
        Format => 'int16u',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    1 => 'EmbeddedImageWidth',
    2 => 'EmbeddedImageHeight',
    16 => {
        Name => 'EmbeddedImageType',
        Format => 'undef[4]',
        RawConv => '$val =~ /^\x89PNG/s ? "PNG" : ($val =~ /^\xff\xd8\xff/ ? "JPG" : "DAT")',
        Notes => q{
            "PNG" for PNG image in Y Cb Cr colors, "JPG" for a JPEG image, or "DAT" for
            other image data
        },
    },
    16.1 => {
        Name => 'EmbeddedImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$size-0x20]',
        Binary => 1,
    },
);

# FLIR camera record (ref PH)
%Image::ExifTool::FLIR::CameraInfo = (
    GROUPS => { 0 => 'APP1', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => q{
        FLIR camera information.  The Planck tags are variables used in the
        temperature calculation.  See
        L<https://exiftool.org/forum/index.php?topic=4898.msg23972#msg23972>
        for details.
    },
    0x00 => {
        # use this tag only to determine the byte order
        # (the value should be 0x0002 if the byte order is correct)
        Name => 'CameraInfoByteOrder',
        Format => 'int16u',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    # 0x02 - int16u: image width
    # 0x04 - int16u: image height
    # 0x0c - int32u: image width - 1
    # 0x10 - int32u: image height - 1
    0x20 => { Name => 'Emissivity',                   %float2f },
    0x24 => { Name => 'ObjectDistance', Format => 'float', PrintConv => 'sprintf("%.2f m",$val)' },
    0x28 => { Name => 'ReflectedApparentTemperature', %floatKelvin },
    0x2c => { Name => 'AtmosphericTemperature',       %floatKelvin },
    0x30 => { Name => 'IRWindowTemperature',          %floatKelvin },
    0x34 => { Name => 'IRWindowTransmission',         %float2f },
    # 0x38: 0
    0x3c => {
        Name => 'RelativeHumidity',
        Format => 'float',
        ValueConv => '$val > 2 ? $val / 100 : $val', # have seen value expressed as percent in FFF file
        PrintConv => 'sprintf("%.1f %%",$val*100)',
    },
    # 0x40 - float: 0,6
    # 0x44,0x48,0x4c: 0
    # 0x50 - int32u: 1
    # 0x54: 0
    0x58 => { Name => 'PlanckR1', %float8g }, #1
    0x5c => { Name => 'PlanckB',  %float8g }, #1
    0x60 => { Name => 'PlanckF',  %float8g }, #1
    # 0x64,0x68,0x6c: 0
    0x070 => { Name => 'AtmosphericTransAlpha1', %float6f }, #1 (value: 0.006569)
    0x074 => { Name => 'AtmosphericTransAlpha2', %float6f }, #1 (value: 0.012620)
    0x078 => { Name => 'AtmosphericTransBeta1',  %float6f }, #1 (value: -0.002276)
    0x07c => { Name => 'AtmosphericTransBeta2',  %float6f }, #1 (value: -0.006670)
    0x080 => { Name => 'AtmosphericTransX',      %float6f }, #1 (value: 1.900000)
    # 0x84,0x88: 0
    # 0x8c - float: 0,4,6
    0x90 => { Name => 'CameraTemperatureRangeMax', %floatKelvin },
    0x94 => { Name => 'CameraTemperatureRangeMin', %floatKelvin },
    0x98 => { Name => 'CameraTemperatureMaxClip', %floatKelvin }, # 50 degrees over camera max
    0x9c => { Name => 'CameraTemperatureMinClip', %floatKelvin }, # usually 10 or 20 degrees below camera min
    0xa0 => { Name => 'CameraTemperatureMaxWarn', %floatKelvin }, # same as camera max
    0xa4 => { Name => 'CameraTemperatureMinWarn', %floatKelvin }, # same as camera min
    0xa8 => { Name => 'CameraTemperatureMaxSaturated', %floatKelvin }, # usually 50 or 88 degrees over camera max
    0xac => { Name => 'CameraTemperatureMinSaturated', %floatKelvin }, # usually 10, 20 or 40 degrees below camera min
    0xd4 => { Name => 'CameraModel',        Format => 'string[32]' },
    0xf4 => { Name => 'CameraPartNumber',   Format => 'string[16]' }, #1
    0x104 => { Name => 'CameraSerialNumber',Format => 'string[16]' }, #1
    0x114 => { Name => 'CameraSoftware',    Format => 'string[16]' }, #1/PH (NC)
    0x170 => { Name => 'LensModel',         Format => 'string[32]' },
    # note: it seems that FLIR updated their lenses at some point, so lenses with the same
    # name may have different part numbers (eg. the FOL38 is either 1196456 or T197089)
    0x190 => { Name => 'LensPartNumber',    Format => 'string[16]' },
    0x1a0 => { Name => 'LensSerialNumber',  Format => 'string[16]' },
    0x1b4 => { Name => 'FieldOfView',       Format => 'float', PrintConv => 'sprintf("%.1f deg", $val)' }, #1
    # 0x1d0 - int16u: 0,12,24,25,46
    # 0x1d2 - int16u: 170,180,190,380,760,52320
    0x1ec => { Name => 'FilterModel',       Format => 'string[16]' },
    0x1fc => { Name => 'FilterPartNumber',  Format => 'string[32]' },
    0x21c => { Name => 'FilterSerialNumber',Format => 'string[32]' },
    0x308 => { Name => 'PlanckO',           Format => 'int32s' }, #1
    0x30c => { Name => 'PlanckR2',          %float8g }, #1
    0x310 => { Name => 'RawValueRangeMin',  Format => 'int16u', Groups => { 2 => 'Image' } }, #forum10060
    0x312 => { Name => 'RawValueRangeMax',  Format => 'int16u', Groups => { 2 => 'Image' } }, #forum10060
    0x338 => { Name => 'RawValueMedian',    Format => 'int16u', Groups => { 2 => 'Image' } },
    0x33c => { Name => 'RawValueRange',     Format => 'int16u', Groups => { 2 => 'Image' } },
    0x384 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'undef[10]',
        Groups => { 2 => 'Time' },
        RawConv => q{
            my $tm = Get32u(\$val, 0);
            my $ss = Get32u(\$val, 4) & 0xffff;
            my $tz = Get16s(\$val, 8);
            ConvertUnixTime($tm - $tz * 60) . sprintf('.%.3d', $ss) . TimeZoneString(-$tz);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x390 => { Name => 'FocusStepCount', Format => 'int16u' },
    0x45c => { Name => 'FocusDistance',  Format => 'float', PrintConv => 'sprintf("%.1f m",$val)' },
    # 0x43c - string: either "Live" or the file name
    0x464 => { Name => 'FrameRate',  Format => 'int16u' }, #SebastianHani
);

# FLIR measurement tools record (ref 6)
%Image::ExifTool::FLIR::MeasInfo = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&ProcessMeasInfo,
    FORMAT => 'int16u',
    VARS => { NO_ID => 1 },
    NOTES => q{
        Tags listed below are only for the first measurement tool, however multiple
        measurements may be added, and information is extracted for all of them. 
        Tags for subsequent measurements are generated as required with the prefixes
        "Meas2", "Meas3", etc.
    },
    Meas1Type => {
        PrintConv => {
            1 => 'Spot',
            2 => 'Area',
            3 => 'Ellipse',
            4 => 'Line',
            5 => 'Endpoint', #PH (NC, FLIR Tools v2.0 for Mac generates an empty one of these after each Line)
            6 => 'Alarm', #PH seen params: "0 1 0 1 9142 0 9142 0" (called "Isotherm" by Mac version)
            7 => 'Unused', #PH (NC) (or maybe "Free"?)
            8 => 'Difference',
        },
    },
    Meas1Params => {
        Notes => 'Spot=X,Y; Area=X1,Y1,W,H; Ellipse=XC,YC,X1,Y1,X2,Y2; Line=X1,Y1,X2,Y2',
    },
    Meas1Label => { },
);

# FLIR palette record (ref PH/JD)
%Image::ExifTool::FLIR::PaletteInfo = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    0x00 => { #JD
        Name => 'PaletteColors',
        RawConv => '$$self{PaletteColors} = $val',
    },
    0x06 => { Name => 'AboveColor',     Format => 'int8u[3]', Notes => 'Y Cr Cb color components' }, #JD
    0x09 => { Name => 'BelowColor',     Format => 'int8u[3]' }, #JD
    0x0c => { Name => 'OverflowColor',  Format => 'int8u[3]' }, #JD
    0x0f => { Name => 'UnderflowColor', Format => 'int8u[3]' }, #JD
    0x12 => { Name => 'Isotherm1Color', Format => 'int8u[3]' }, #JD
    0x15 => { Name => 'Isotherm2Color', Format => 'int8u[3]' }, #JD
    0x1a => { Name => 'PaletteMethod' }, #JD
    0x1b => { Name => 'PaletteStretch' }, #JD
    0x30 => {
        Name => 'PaletteFileName',
        Format => 'string[32]',
        # (not valid for all images)
        RawConv => q{
            $val =~ s/\0.*//;
            $val =~ /^[\x20-\x7e]{3,31}$/ ? $val : undef;
        },
    },
    0x50 => {
        Name => 'PaletteName',
        Format => 'string[32]',
        # (not valid for all images)
        RawConv => q{
            $val =~ s/\0.*//;
            $val =~ /^[\x20-\x7e]{3,31}$/ ? $val : undef;
        },
    },
    0x70 => {
        Name => 'Palette',
        Format => 'undef[3*$$self{PaletteColors}]',
        Notes => 'Y Cr Cb byte values for each palette color',
        Binary => 1,
    },
);

# FLIR text information record (ref PH)
%Image::ExifTool::FLIR::TextInfo = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&ProcessFLIRText,
    VARS => { NO_ID => 1 },
    Label0 => { },
    Value0 => { },
    Label1 => { },
    Value1 => { },
    Label2 => { },
    Value2 => { },
    Label3 => { },
    Value3 => { },
    # (there could be more, and we will generate these on the fly if necessary)
);

# FLIR parameter information record (ref PH)
%Image::ExifTool::FLIR::ParamInfo = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&ProcessFLIRText,
    VARS => { NO_ID => 1 },
    Generated => {
        Name => 'DateTimeGenerated',
        Description => 'Date/Time Generated',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ tr/-/:/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Param0 => { },
    Param1 => { },
    Param2 => { },
    Param3 => { },
    # (there could be more, and we will generate these on the fly if necessary)
);

# FLIR Picture in Picture record (ref 1)
%Image::ExifTool::FLIR::PiP = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => 'FLIR Picture in Picture tags.',
    FORMAT => 'int16s',
    0x00 => {
        Name => 'Real2IR',
        Format => 'float',
    },
    2 => {
        Name => 'OffsetX',
        Notes => 'offset from of insertion point from center',
        PrintConv => 'sprintf("%+d",$val)', # (add sign for direct use with IM convert)
    },
    3 => {
        Name => 'OffsetY',
        PrintConv => 'sprintf("%+d",$val)',
    },
    4 => {
        Name => 'PiPX1',
        Description => 'PiP X1',
        Notes => 'crop size for radiometric image',
    },
    5 => { Name => 'PiPX2', Description => 'PiP X2' },
    6 => { Name => 'PiPY1', Description => 'PiP Y1' },
    7 => { Name => 'PiPY2', Description => 'PiP Y2' },
);

# FLIR GPS record (ref PH/JD/forum9615)
%Image::ExifTool::FLIR::GPSInfo = (
    GROUPS => { 0 => 'APP1', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    0x00 => {
        Name => 'GPSValid',
        Format => 'int32u',
        RawConv => '$$self{GPSValid} = $val',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x04 => {
        Name => 'GPSVersionID',
        Format => 'undef[4]',
        RawConv => '$val eq "\0\0\0\0" ? undef : $val',
        PrintConv => 'join ".", split //, $val',
    },
    0x08 => {
        Name => 'GPSLatitudeRef',
        Format => 'string[2]',
        RawConv => 'length($val) ? $val : undef',
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x0a => {
        Name => 'GPSLongitudeRef',
        Format => 'string[2]',
        RawConv => 'length($val) ? $val : undef',
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
  # 0x0c - 4 unknown bytes
    0x10 => {
        Name => 'GPSLatitude',
        Condition => '$$self{GPSValid}',    # valid only if GPSValid is 1
        Format => 'double', # (signed)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    0x18 => {
        Name => 'GPSLongitude',
        Condition => '$$self{GPSValid}',    # valid only if GPSValid is 1
        Format => 'double', # (signed)
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    0x20 => {
        Name => 'GPSAltitude',
        Condition => '$$self{GPSValid}',    # valid only if GPSValid is 1
        Format => 'float',
        # (have seen likely invalid value of -1 when GPSValid is 1)
        PrintConv => 'sprintf("%.2f m", $val)',
    },
  # 0x24 - 28 unknown bytes:
  # 0x28 - int8u: seen 0,49,51,55,57 (ASCII "1","3","7","9")
  # 0x29 - int8u: seen 0,48 (ASCII "0")
    0x40 => {
        Name => 'GPSDOP',
        Description => 'GPS Dilution Of Precision',
        Format => 'float',
        RawConv => '$val > 0 ? $val : undef', # (have also seen likely invalid value of 1)
        PrintConv => 'sprintf("%.2f", $val)',
    },
    0x44 => {
        Name => 'GPSSpeedRef',
        Format => 'string[2]',
        RawConv => 'length($val) ? $val : undef',
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    0x46 => {
        Name => 'GPSTrackRef',
        Format => 'string[2]',
        RawConv => 'length($val) ? $val : undef',
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x48 => { #PH (NC)
        Name => 'GPSImgDirectionRef',
        Format => 'string[2]',
        RawConv => 'length($val) ? $val : undef',
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x4c => {
        Name => 'GPSSpeed',
        %float2f,
        RawConv => '$val < 0 ? undef : $val',
    },
    0x50 => {
        Name => 'GPSTrack',
        %float2f,
        RawConv => '$val < 0 ? undef : $val',
    },
    0x54 => {
        Name => 'GPSImgDirection',
        %float2f,
        RawConv => '$val < 0 ? undef : $val',
    },
    0x58 => {
        Name => 'GPSMapDatum',
        Format => 'string[16]',
        RawConv => 'length($val) ? $val : undef',
    },
  # 0xa4 - string[6]: seen 000208,081210,020409,000608,010408,020808,091011
  # 0x78 - double[2]: seen "-1 -1","0 0"
  # 0x78 - float[2]: seen "-1 -1","0 0"
  # 0xb2 - string[2]?: seen "5\0"
);

# humidity meter information
# (ref https://exiftool.org/forum/index.php/topic,5325.0.html)
# The %Image::ExifTool::UserDefined hash defines new tags to be added to existing tables.
%Image::ExifTool::FLIR::MeterLink = (
    GROUPS => { 0 => 'APP1', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => 'Tags containing Meterlink humidity meter information.',
    26 => {
        Name => 'Reading1Units',
        DataMember => 'Reading1Units',
        RawConv => '$$self{Reading1Units} = $val',
        PrintHex => 1,
        PrintConv => {
            0x0d => 'C',
            0x1b => '%',
            0x1d => 'Relative',
            0x24 => 'g/kg',
        },
    },
    28 => {
        Name => 'Reading1Description',
        DataMember => 'Reading1Description',
        RawConv => '$$self{Reading1Description} = $val',
        PrintConv => {
            0 => 'Humidity',
            3 => 'Moisture', # Pinless Moisture Readings with INTernal sensor
            7 => 'Dew Point',
            8 => 'Air Temperature',
            9 => 'IR Temperature',
            11 => 'Difference Temperature', # Difference Temp: IR-Temp and DewPoint
        },
    },
    32 => {
        Name => 'Reading1Device',
        Format => 'string[16]',
    },
    96 => {
        Name => 'Reading1Value',
        Format => 'double',
        # convert Kelvin -> Celsius and kg/kg -> g/kg
        ValueConv => q{
            return $val - 273.15 if $$self{Reading1Units} == 0x0d and $$self{Reading1Description} != 11;
            return $val *= 1000 if $$self{Reading1Units} == 0x24;
            return $val;
        },
    },
    # add 100 for subsequent readings
    126 => {
        Name => 'Reading2Units',
        DataMember => 'Reading2Units',
        RawConv => '$$self{Reading2Units} = $val',
        PrintHex => 1,
        PrintConv => {
            0x0d => 'C',
            0x1b => '%',
            0x1d => 'rel',
            0x24 => 'g/kg',
        },
    },
    128 => {
        Name => 'Reading2Description',
        DataMember => 'Reading2Description',
        RawConv => '$$self{Reading2Description} = $val',
        PrintConv => {
            0 => 'Humidity',
            3 => 'Moisture',
            7 => 'Dew Point',
            8 => 'Air Temperature',
            9 => 'IR Temperature',
            11 => 'Difference Temperature', # Difference Temp: IR-Temp and DewPoint
        },
    },
    132 => {
        Name => 'Reading2Device',
        Format => 'string[16]',
    },
    196 => {
        Name => 'Reading2Value',
        Format => 'double',
        # convert Kelvin -> Celsius and kg/kg -> g/kg
        ValueConv => q{
            return $val - 273.15 if $$self{Reading2Units} == 0x0d and $$self{Reading2Description} != 11;
            return $val *= 1000 if $$self{Reading2Units} == 0x24;
            return $val;
        },
    },
    226 => {
        Name => 'Reading3Units',
        DataMember => 'Reading3Units',
        RawConv => '$$self{Reading3Units} = $val',
        PrintHex => 1,
        PrintConv => {
            0x0d => 'C',
            0x1b => '%',
            0x1d => 'rel',
            0x24 => 'g/kg',
        },
    },
    228 => {
        Name => 'Reading3Description',
        DataMember => 'Reading3Description',
        RawConv => '$$self{Reading3Description} = $val',
        PrintConv => {
            0 => 'Humidity',
            3 => 'Moisture',
            7 => 'Dew Point',
            8 => 'Air Temperature',
            9 => 'IR Temperature',
            11 => 'Difference Temperature', # Difference Temp: IR-Temp and DewPoint
        },
    },
    232 => {
        Name => 'Reading3Device',
        Format => 'string[16]',
    },
    296 => {
        Name => 'Reading3Value',
        Format => 'double',
        # convert Kelvin -> Celsius and kg/kg -> g/kg
        ValueConv => q{
            return $val - 273.15 if $$self{Reading3Units} == 0x0d and $$self{Reading3Description} != 11;
            return $val *= 1000 if $$self{Reading3Units} == 0x24;
            return $val;
        },
    },

    326 => {
        Name => 'Reading4Units',
        DataMember => 'Reading4Units',
        RawConv => '$$self{Reading4Units} = $val',
        PrintHex => 1,
        PrintConv => {
            0x0d => 'C',
            0x1b => '%',
            0x1d => 'rel',
            0x24 => 'g/kg',
        },
    },
    328 => {
        Name => 'Reading4Description',
        DataMember => 'Reading4Description',
        RawConv => '$$self{Reading4Description} = $val',
        PrintConv => {
            0 => 'Humidity',
            3 => 'Moisture',
            7 => 'Dew Point',
            8 => 'Air Temperature',
            9 => 'IR Temperature',
            11 => 'Difference Temperature', # Difference Temp: IR-Temp and DewPoint
        },
    },
    332 => {
        Name => 'Reading4Device',
        Format => 'string[16]',
    },
    396 => {
        Name => 'Reading4Value',
        Format => 'double',
        # convert Kelvin -> Celsius and kg/kg -> g/kg
        ValueConv => q{
            return $val - 273.15 if $$self{Reading4Units} == 0x0d and $$self{Reading4Description} != 11;
            return $val *= 1000 if $$self{Reading4Units} == 0x24;
            return $val;
        },
    },
);

# FLIR public image format (ref 4/5)
%Image::ExifTool::FLIR::FPF = (
    GROUPS => { 0 => 'FLIR', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'Tags extracted from FLIR Public image Format (FPF) files.',
    0x20 => { Name => 'FPFVersion',         Format => 'int32u' },
    0x24 => { Name => 'ImageDataOffset',    Format => 'int32u' },
    0x28 => {
        Name => 'ImageType',
        Format => 'int16u',
        PrintConv => {
            0 => 'Temperature',
            1 => 'Temperature Difference',
            2 => 'Object Signal',
            3 => 'Object Signal Difference',
        },
    },
    0x2a => {
        Name => 'ImagePixelFormat',
        Format => 'int16u',
        PrintConv => {
            0 => '2-byte short integer',
            1 => '4-byte long integer',
            2 => '4-byte float',
            3 => '8-byte double',
        },
    },
    0x2c => { Name => 'ImageWidth',         Format => 'int16u' },
    0x2e => { Name => 'ImageHeight',        Format => 'int16u' },
    0x30 => { Name => 'ExternalTriggerCount',Format => 'int32u' },
    0x34 => { Name => 'SequenceFrameNumber',Format => 'int32u' },
    0x78 => { Name => 'CameraModel',        Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x98 => { Name => 'CameraPartNumber',   Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0xb8 => { Name => 'CameraSerialNumber', Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0xd8 => { Name => 'CameraTemperatureRangeMin', %floatKelvin,    Groups => { 2 => 'Camera' } },
    0xdc => { Name => 'CameraTemperatureRangeMax', %floatKelvin,    Groups => { 2 => 'Camera' } },
    0xe0 => { Name => 'LensModel',          Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x100 => { Name => 'LensPartNumber',    Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x120 => { Name => 'LensSerialNumber',  Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x140 => { Name => 'FilterModel',       Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x150 => { Name => 'FilterPartNumber',  Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x180 => { Name => 'FilterSerialNumber',Format => 'string[32]', Groups => { 2 => 'Camera' } },
    0x1e0 => { Name => 'Emissivity',        %float2f },
    0x1e4 => { Name => 'ObjectDistance',    Format => 'float', PrintConv => 'sprintf("%.2f m",$val)' },
    0x1e8 => { Name => 'ReflectedApparentTemperature', %floatKelvin },
    0x1ec => { Name => 'AtmosphericTemperature',       %floatKelvin },
    0x1f0 => { Name => 'RelativeHumidity',  Format => 'float', PrintConv => 'sprintf("%.1f %%",$val*100)' },
    0x1f4 => { Name => 'ComputedAtmosphericTrans', %float2f },
    0x1f8 => { Name => 'EstimatedAtmosphericTrans',%float2f },
    0x1fc => { Name => 'ReferenceTemperature', %floatKelvin },
    0x200 => { Name => 'IRWindowTemperature',  %floatKelvin, Groups => { 2 => 'Camera' } },
    0x204 => { Name => 'IRWindowTransmission', %float2f,     Groups => { 2 => 'Camera' } },
    0x248 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Format => 'int32u[7]',
        ValueConv => 'sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d.%.3d",split(" ",$val))',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # Notes (based on ref 4):
    # 1) The above date/time structure is documented to be 32 bytes for FPFVersion 1, but in
    #    fact it is only 28.  Maybe this is why the full header length of my FPFVersion 2
    #    sample is 892 bytes instead of 896.  If this was a documentation error, we are OK,
    #    but if the alignment was really different in version 1, then the temperatures below
    #    will be mis-aligned.  I don't have any version 1 samples to check this.
    # 2) The following temperatures may not always be in Kelvin
    0x2a4 => { Name => 'CameraScaleMin',    %float1f },
    0x2a8 => { Name => 'CameraScaleMax',    %float1f },
    0x2ac => { Name => 'CalculatedScaleMin',%float1f },
    0x2b0 => { Name => 'CalculatedScaleMax',%float1f },
    0x2b4 => { Name => 'ActualScaleMin',    %float1f },
    0x2b8 => { Name => 'ActualScaleMax',    %float1f },
);

# top-level user data written by FLIR cameras in MP4 videos
%Image::ExifTool::FLIR::UserData = (
    GROUPS => { 1 => 'FLIR', 2 => 'Camera' },
    NOTES => q{
        Tags written by some FLIR cameras in a top-level (!) "udta" atom of MP4
        videos.
    },
    uuid => [
        {
            Name => 'FLIR_Parts',
            Condition => '$$valPt=~/^\x43\xc3\x99\x3b\x0f\x94\x42\x4b\x82\x05\x6b\x66\x51\x3f\x48\x5d/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FLIR::Parts',
                Start => 16,
            },
        },
        {
            Name => 'FLIR_Serial',
            Condition => '$$valPt=~/^\x57\xf5\xb9\x3e\x51\xe4\x48\xaf\xa0\xd9\xc3\xef\x1b\x37\xf7\x12/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FLIR::SerialNums',
                Start => 16,
            },
        },
        {
            Name => 'FLIR_Params',
            Condition => '$$valPt=~/^\x41\xe5\xdc\xf9\xe8\x0a\x41\xce\xad\xfe\x7f\x0c\x58\x08\x2c\x19/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FLIR::Params',
                Start => 16,
            },
        },
        {
            Name => 'FLIR_UnknownUUID',
            Condition => '$$valPt=~/^\x57\x45\x20\x50\x2c\xbb\x44\xad\xae\x54\x15\xe9\xb8\x39\xd9\x03/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FLIR::UnknownUUID',
                Start => 16,
            },
        },
        {
            Name => 'FLIR_GPS',
            Condition => '$$valPt=~/^\x7f\x2e\x21\x00\x8b\x46\x49\x18\xaf\xb1\xde\x70\x9a\x74\xf6\xf5/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FLIR::GPS_UUID',
                Start => 16,
            },
        },
        {
            Name => 'FLIR_MoreInfo',
            Condition => '$$valPt=~/^\x2b\x45\x2f\xdc\x74\x35\x40\x94\xba\xee\x22\xa6\xb2\x3a\x7c\xf8/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FLIR::MoreInfo',
                Start => 16,
            },
        },
        {
            Name => 'SoftwareComponents',
            Condition => '$$valPt=~/^\x78\x3f\xc7\x83\x0c\x95\x4b\x00\x8c\xc7\xac\xf1\xec\xb4\xd3\x9a/s',
            Unknown => 1,
            ValueConv => 'join " ", unpack "x20N4xZ*", $val',
        },
        {
            Name => 'FLIR_Unknown',
            Condition => '$$valPt=~/^\x52\xae\xda\x45\x17\x1e\x48\xb1\x92\x47\x93\xa4\x21\x4e\x43\xf5/s',
            Unknown => 1,
            ValueConv => 'unpack "x20C*", $val',
        },
        {
            Name => 'Units',
            Condition => '$$valPt=~/^\xf8\xab\x72\x1e\x84\x73\x44\xa0\xb8\xc8\x1b\x04\x82\x6e\x07\x24/s',
            List => 1,
            RawConv => 'my @a = split "\0", substr($val, 20); \@a',
        },
        {
            Name => 'ThumbnailImage',
            Groups => { 2 => 'Preview' },
            Condition => '$$valPt=~/^\x91\xaf\x9b\x93\x45\x9b\x44\x56\x98\xd1\x5e\x76\xea\x01\x04\xac....\xff\xd8\xff/s',
            RawConv => 'substr($val, 20)',
            Binary => 1,
        },
    ],
);

# uuid 43c3993b0f94424b82056b66513f485d box of MP4 videos (ref PH)
%Image::ExifTool::FLIR::Parts = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'undef',
    NOTES => q{
        Tags extracted from the "uuid" box with ID 43c3993b0f94424b82056b66513f485d
        in FLIR MP4 videos.
    },
    4 => [
        {
            Name => 'BAHPVer',
            Condition => '$$valPt =~ /^bahpver\0/',
            Format => 'undef[$size]',
            RawConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'BALPVer',
            Condition => '$$valPt =~ /^balpver\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'Battery',
            Condition => '$$valPt =~ /^battery\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'BAVPVer',
            Condition => '$$valPt =~ /^bavpver\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
            # (the first string corresponds with a lens part number)
        },
        {
            Name => 'CamCore',
            Condition => '$$valPt =~ /^camcore\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'DetectorBoard',
            Condition => '$$valPt =~ /^det_board\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 10)',
        },
        {
            Name => 'Detector',
            Condition => '$$valPt =~ /^detector\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 9)',
        },
        {
            Name => 'GIDCVer',
            Condition => '$$valPt =~ /^gidcver\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'GIDPVer',
            Condition => '$$valPt =~ /^gidpver\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'GIPC_CPLD',
            Condition => '$$valPt =~ /^gipccpld\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 9)',
        },
        {
            Name => 'GIPCVer',
            Condition => '$$valPt =~ /^gipcver\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'GIXIVer',
            Condition => '$$valPt =~ /^gixiver\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 8)',
        },
        {
            Name => 'MainBoard',
            Condition => '$$valPt =~ /^mainboard\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 10)',
        },
        {
            Name => 'Optics',
            Condition => '$$valPt =~ /^optics\0/',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", substr($val, 7)',
        },
        {
            Name => 'PartNumber',
            Format => 'undef[$size]',
            ValueConv => 'join " ", split "\0", $val',
        },
    ],
);

# uuid 57f5b93e51e448afa0d9c3ef1b37f712 box of MP4 videos (ref PH)
%Image::ExifTool::FLIR::SerialNums = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => q{
        Tags extracted from the "uuid" box with ID 57f5b93e51e448afa0d9c3ef1b37f712
        in FLIR MP4 videos.
    },
    # (not sure if these offsets are constant)
    0x0c => { Name => 'UnknownSerial1',     Format => 'string[33]', Unknown => 1 },
    0x2d => { Name => 'UnknownSerial2',     Format => 'string[33]', Unknown => 1 },
    0x4e => { Name => 'UnknownSerial3',     Format => 'string[33]', Unknown => 1 },
    0x6f => { Name => 'UnknownSerial4',     Format => 'string[11]', Unknown => 1 },
    0x7b => { Name => 'UnknownNumber',      Format => 'string[3]',  Unknown => 1 },
    0x7e => { Name => 'CameraSerialNumber', Format => 'string[9]' },
);

# uuid 41e5dcf9e80a41ceadfe7f0c58082c19 box of MP4 videos (ref PH)
%Image::ExifTool::FLIR::Params = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    NOTES => q{
        Tags extracted from the "uuid" box with ID 41e5dcf9e80a41ceadfe7f0c58082c19
        in FLIR MP4 videos.
    },
    1 => { Name => 'ReflectedApparentTemperature', %floatKelvin },
    2 => { Name => 'AtmosphericTemperature',       %floatKelvin },
    3 => { Name => 'Emissivity',                   %float2f },
    4 => { Name => 'ObjectDistance',   PrintConv => 'sprintf("%.2f m",$val)' },
    5 => { Name => 'RelativeHumidity', PrintConv => 'sprintf("%.1f %%",$val*100)' },
    6 => { Name => 'EstimatedAtmosphericTrans',    %float2f },
    7 => { Name => 'IRWindowTemperature',          %floatKelvin },
    8 => { Name => 'IRWindowTransmission',         %float2f },
);

# uuid 574520502cbb44adae5415e9b839d903 box of MP4 videos (ref PH)
%Image::ExifTool::FLIR::UnknownUUID = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    NOTES => q{
        Tags extracted from the "uuid" box with ID 574520502cbb44adae5415e9b839d903
        in FLIR MP4 videos.
    },
    # 1 - 1
    # 2 - 0
    # 3 - 0
);

# uuid 7f2e21008b464918afb1de709a74f6f5 box of MP4 videos (ref PH)
%Image::ExifTool::FLIR::GPS_UUID = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'FLIR', 2 => 'Location' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'float',
    FIRST_ENTRY => 0,
    NOTES => q{
        Tags extracted from the "uuid" box with ID 7f2e21008b464918afb1de709a74f6f5
        in FLIR MP4 videos.
    },
    1 => {
        Name => 'GPSLatitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    2 => {
        Name => 'GPSLongitude',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    3 => {
        Name => 'GPSAltitude',
        PrintConv => '$val=int($val*100+0.5)/100;"$val m"',
    },
    # 4 - int32u: 0x0001bf74
    # 5 - int32u: 0
    # 6 - int32u: 1
);

# uuid 2b452fdc74354094baee22a6b23a7cf8 box of MP4 videos (ref PH)
%Image::ExifTool::FLIR::MoreInfo = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    NOTES => q{
        Tags extracted from the "uuid" box with ID 2b452fdc74354094baee22a6b23a7cf8
        in FLIR MP4 videos.
    },
    5 => { Name => 'LensModel', Format => 'string[6]' },
    11 => { Name => 'UnknownTemperature1', %floatKelvin, Unknown => 1 }, # (-14.9 C)
    15 => { Name => 'UnknownTemperature2', %floatKelvin, Unknown => 1 }, # (60.0 C)
);

# FLIR AFF tag table (ref PH)
%Image::ExifTool::FLIR::AFF = (
    GROUPS => { 0 => 'FLIR', 1 => 'FLIR', 2 => 'Image' },
    NOTES => 'Tags extracted from FLIR "AFF" SEQ images.',
    VARS => { ALPHA_FIRST => 1 },
    "_header" => {
        Name => 'AFFHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::Header' },
    },
    0x01 => {
        Name => 'AFF1',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::AFF1' },
    },
    0x05 => {
        Name => 'AFF5',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::AFF5' },
    },
);

# AFF record type 1 (ref forum?topic=4898.msg27627)
%Image::ExifTool::FLIR::AFF1 = (
    GROUPS => { 0 => 'FLIR', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x00 => {
        # use this tag only to determine the byte order of the raw data
        # (the value should be 0x0002 if the byte order is correct)
        Name => 'RawDataByteOrder',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    0x01 => { Name => 'SensorWidth',  Format => 'int16u' },
    0x02 => { Name => 'SensorHeight', Format => 'int16u' },
);

# AFF record type 5 (ref forum?topic=4898.msg27628)
%Image::ExifTool::FLIR::AFF5 = (
    GROUPS => { 0 => 'FLIR', 1 => 'FLIR', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x12 => {
        # use this tag only to determine the byte order of the raw data
        # (the value should be 0x0002 if the byte order is correct)
        Name => 'RawDataByteOrder',
        Hidden => 1,
        RawConv => 'ToggleByteOrder() if $val >= 0x0100; undef',
    },
    0x13 => { Name => 'SensorWidth',  Format => 'int16u' },
    0x14 => { Name => 'SensorHeight', Format => 'int16u' },
);

# FLIR composite tags (ref 1)
%Image::ExifTool::FLIR::Composite = (
    GROUPS => { 1 => 'FLIR', 2 => 'Camera' },
    PeakSpectralSensitivity => {
        Require => 'FLIR:PlanckB',
        ValueConv => '14387.6515/$val',
        PrintConv => 'sprintf("%.1f um", $val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::FLIR');

#------------------------------------------------------------------------------
# Get image type from raw image data
# Inputs: 0) ExifTool ref, 1) image data, 2) tag name
# Returns: image type (PNG, JPG, TIFF or undef)
# - image itself is stored in $$et{$tag}
sub GetImageType($$$)
{
    my ($et, $val, $tag) = @_;
    my ($w, $h) = @$et{"${tag}Width","${tag}Height"};
    my $type = 'DAT';
    # add TIFF header only if this looks like 16-bit raw data
    # (note: MakeTiffHeader currently works only for little-endian,
    #  and I haven't seen any big-endian samples, but check anwyay)
    if ($val =~ /^\x89PNG\r\n\x1a\n/) {
        $type = 'PNG';
    } elsif ($val =~ /^\xff\xd8\xff/) { # (haven't seen this, but just in case - PH)
        $type = 'JPG';
    } elsif (length $val != $w * $h * 2) {
        $et->Warn("Unrecognized FLIR $tag data format");
    } elsif (GetByteOrder() eq 'II') {
        $val = Image::ExifTool::MakeTiffHeader($w,$h,1,16) . $val;
        $type = 'TIFF';
    } else {
        $et->Warn("Don't yet support big-endian TIFF $tag");
    }
    # save image data
    $$et{$tag} = $val;
    return $type;
}

#------------------------------------------------------------------------------
# Unescape FLIR Unicode character
# Inputs: 0) escaped character code
# Returns: UTF8 character
sub UnescapeFLIR($)
{
    my $char = shift;
    return $char unless length $char == 4; # escaped ASCII char (eg. '\\')
    my $val = hex $char;
    return chr($val) if $val < 0x80;   # simple ASCII
    return pack('C0U', $val) if $] >= 5.006001;
    return Image::ExifTool::PackUTF8($val);
}

#------------------------------------------------------------------------------
# Process FLIR text info record (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessFLIRText($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen};

    return 0 if $dirLen < 12;

    $et->VerboseDir('FLIR Text');

    my $dat = substr($$dataPt, $dirStart+12, $dirLen-12);
    $dat =~ s/\0.*//s; # truncate at null

    # the parameter text contains an additional header entry...
    if ($tagTablePtr eq \%Image::ExifTool::FLIR::ParamInfo and
        $dat =~ /# (Generated) at (.*?)[\n\r]/)
    {
        $et->HandleTag($tagTablePtr, $1, $2);
    }

    for (;;) {
        $dat =~ /.(\d+).(label|value|param) (unicode|text) "(.*)"/g or last;
        my ($tag, $val) = (ucfirst($2) . $1, $4);
        if ($3 eq 'unicode' and $val =~ /\\/) {
            # convert escaped Unicode characters (backslash followed by 4 hex digits)
            $val =~ s/\\([0-9a-fA-F]{4}|.)/UnescapeFLIR($1)/sge;
            $et->Decode($val, 'UTF8');
        }
        $$tagTablePtr{$tag} or AddTagToTable($tagTablePtr, $tag, { Name => $tag });
        $et->HandleTag($tagTablePtr, $tag, $val);
    }

    return 1;
}

#------------------------------------------------------------------------------
# Process FLIR measurement tool record (ref 6)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (code-driven decoding isn't pretty, but sometimes it is necessary)
sub ProcessMeasInfo($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dataPos = $$dirInfo{DataPos};
    my $dirEnd = $dirStart + $$dirInfo{DirLen};

    my $pos = $dirStart + 12;
    return 0 if $pos > $dirEnd;
    ToggleByteOrder() if Get16u($dataPt, $dirStart) >= 0x100;
    my ($i, $t, $p);
    for ($i=1; ; ++$i) {
        last if $pos + 2 > $dirEnd;
        my $recLen = Get16u($dataPt, $pos);
        last if $recLen < 0x28 or $pos + $recLen > $dirEnd;
        my $pre = 'Meas' . $i;
        $et->VerboseDir("MeasInfo $i", undef, $recLen);
        $et->VerboseDump($dataPt, Len => $recLen, Start=>$pos, DataPos=>$dataPos);
        my $coordLen = Get16u($dataPt, $pos+4);
        # generate tag table entries for this tool if necessary
        foreach $t ('Type', 'Params', 'Label') {
            my $tag = $pre . $t;
            last if $$tagTablePtr{$tag};
            my $tagInfo = { Name => $tag };
            $$tagInfo{PrintConv} = $$tagTablePtr{"Meas1$t"}{PrintConv};
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        # extract measurement tool type
        $et->HandleTag($tagTablePtr, "${pre}Type", undef,
            DataPt=>$dataPt, DataPos=>$dataPos, Start=>$pos+0x0a, Size=>2);
        last if $pos + 0x24 + $coordLen > $dirEnd;
        # extract measurement parameters
        $et->HandleTag($tagTablePtr, "${pre}Params", undef,
            DataPt=>$dataPt, DataPos=>$dataPos, Start=>$pos+0x24, Size=>$coordLen);
        my @uni;
        # extract label (sometimes-null-terminated Unicode)
        for ($p=0x24+$coordLen; $p<$recLen-1; $p+=2) {
            my $ch = Get16u($dataPt, $p+$pos);
            # FLIR Tools v2.0 for Mac doesn't properly null-terminate these strings,
            # so end the string at any funny character
            last if $ch < 0x20 or $ch > 0x7f;
            push @uni, $ch;
        }
        # convert to the ExifTool character set
        require Image::ExifTool::Charset;
        my $val = Image::ExifTool::Charset::Recompose($et, \@uni);
        $et->HandleTag($tagTablePtr, "${pre}Label", $val,
            DataPt=>$dataPt, DataPos=>$dataPos, Start=>$pos+0x24+$coordLen, Size=>2*scalar(@uni));
        $pos += $recLen;    # step to next record
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process FLIR FFF record (ref PH/1/3)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 if this was a valid FFF record
sub ProcessFLIR($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF} || File::RandomAccess->new($$dirInfo{DataPt});
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my $base = $raf->Tell();
    my ($i, $hdr, $buff, $rec);

    # read and verify FFF header
    $raf->Read($hdr, 0x40) == 0x40 and $hdr =~ /^([AF]FF)\0/ or return 0;

    my $type = $1;

    # set file type if reading from FFF or SEQ file ($tagTablePtr will not be defined)
    $et->SetFileType($type eq 'FFF' ? 'FLIR' : 'SEQ') unless $tagTablePtr;

    # FLIR file header (ref 3)
    # 0x00 - string[4] file format ID = "FFF\0"
    # 0x04 - string[16] file creator: seen "\0","MTX IR\0","CAMCTRL\0"
    # 0x14 - int32u file format version = 100
    # 0x18 - int32u offset to record directory
    # 0x1c - int32u number of entries in record directory
    # 0x20 - int32u next free index ID = 2
    # 0x24 - int16u swap pattern = 0 (?)
    # 0x28 - int16u[7] spares
    # 0x34 - int32u[2] reserved
    # 0x3c - int32u checksum

    # determine byte ordering by validating version number
    # (in my samples FLIR APP1 is big-endian, FFF files are little-endian)
    for ($i=0; ; ++$i) {
        my $ver = Get32u(\$hdr, 0x14);
        last if $ver >= 100 and $ver < 200; # (have seen 100 and 101 - PH)
        ToggleByteOrder();
        next unless $i;
        return 0 if $$et{DOC_NUM};
        $et->Warn("Unsupported FLIR $type version");
        return 1;
    }

    # read the FLIR record directory
    my $pos = Get32u(\$hdr, 0x18);
    my $num = Get32u(\$hdr, 0x1c);
    unless ($raf->Seek($base+$pos) and $raf->Read($buff, $num * 0x20) == $num * 0x20) {
        $et->Warn('Truncated FLIR FFF directory');
        return $$et{DOC_NUM} ? 0 : 1;
    }

    unless ($tagTablePtr) {
        $tagTablePtr = GetTagTable("Image::ExifTool::FLIR::$type");
        $$et{SET_GROUP0} = 'FLIR'; # (set group 0 to 'FLIR' for FFF files)
    }

    # process the header data
    $et->HandleTag($tagTablePtr, '_header', $hdr);

    my $success = 1;
    my $oldIndent = $$et{INDENT};
    $$et{INDENT} .= '| ';
    $et->VerboseDir($type, $num);

    for ($i=0; $i<$num; ++$i) {

        # FLIR record entry (ref 3):
        # 0x00 - int16u record type
        # 0x02 - int16u record subtype: RawData 1=BE, 2=LE, 3=PNG; 1 for other record types
        # 0x04 - int32u record version: seen 0x64,0x66,0x67,0x68,0x6f,0x104
        # 0x08 - int32u index id = 1
        # 0x0c - int32u record offset from start of FLIR data
        # 0x10 - int32u record length
        # 0x14 - int32u parent = 0 (?)
        # 0x18 - int32u object number = 0 (?)
        # 0x1c - int32u checksum: 0 for no checksum

        my $entry = $i * 0x20;
        my $recType = Get16u(\$buff, $entry);
        if ($recType == 0) {
            $verbose and print $out "$$et{INDENT}$i) FLIR Record 0x00 (empty)\n";
            next;
        }
        my $recPos = Get32u(\$buff, $entry + 0x0c);
        my $recLen = Get32u(\$buff, $entry + 0x10);

        $verbose and printf $out "%s%d) FLIR Record 0x%.2x, offset 0x%.4x, length 0x%.4x\n",
                                 $$et{INDENT}, $i, $recType, $recPos, $recLen;

        # skip RawData records for embedded documents
        if ($recType == 1 and $$et{DOC_NUM} and $et->Options('ExtractEmbedded') < 2) {
            $raf->Seek($base+$recPos+$recLen) or $success = 0, last;
            next;
        }
        unless ($raf->Seek($base+$recPos) and $raf->Read($rec, $recLen) == $recLen) {
            if ($$et{DOC_NUM}) {
                $success = 0;   # abort processing more documents
            } else {
                $et->Warn('Invalid FLIR record');
            }
            last;
        }
        if ($$tagTablePtr{$recType}) {
            $et->HandleTag($tagTablePtr, $recType, undef,
                Base    => $base,
                DataPt  => \$rec,
                DataPos => $recPos,
                Start   => 0,
                Size    => $recLen,
            );
        } elsif ($verbose > 2) {
            $et->VerboseDump(\$rec, Len => $recLen, DataPos => $recPos);
        }
    }
    delete $$et{SET_GROUP0};
    $$et{INDENT} = $oldIndent;

    # extract information from subsequent frames in SEQ file if ExtractEmbedded is used
    if ($$dirInfo{RAF} and $et->Options('ExtractEmbedded') and not $$et{DOC_NUM}) {
        for (;;) {
            $$et{DOC_NUM} = $$et{DOC_COUNT} + 1;
            last unless ProcessFLIR($et, $dirInfo, $tagTablePtr);
            # (DOC_COUNT will be incremented automatically if we extracted any tags)
        }
        delete $$et{DOC_NUM};
    }
    return $success;
}

#------------------------------------------------------------------------------
# Process FLIR public image format (FPF) file (ref PH/4)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 if this was a valid FFF file
sub ProcessFPF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    $raf->Read($buff, 892) == 892 and $buff =~ /^FPF Public Image Format\0/ or return 0;

    # I think these are always little-endian, but check FPFVersion just in case
    SetByteOrder('II');
    ToggleByteOrder() unless Get32u(\$buff, 0x20) & 0xffff;

    my $tagTablePtr = GetTagTable('Image::ExifTool::FLIR::FPF');
    $et->SetFileType();
    $et->ProcessDirectory( { DataPt => \$buff, Parent => 'FPF' }, $tagTablePtr);
    return 1;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::FLIR - Read FLIR meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains the definitions to read meta information from FLIR
Systems Inc. thermal image files (FFF, FPF and JPEG format).

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://exiftool.org/forum/index.php/topic,4898.0.html>

=item L<http://www.nuage.ch/site/flir-i7-some-analysis/>

=item L<http://www.workswell.cz/manuals/flir/hardware/A3xx_and_A6xx_models/Streaming_format_ThermoVision.pdf>

=item L<http://support.flir.com/DocDownload/Assets/62/English/1557488%24A.pdf>

=item L<http://code.google.com/p/dvelib/source/browse/trunk/flirPublicFormat/fpfConverter/Fpfimg.h?spec=svn3&r=3>

=item L<https://exiftool.org/forum/index.php/topic,5538.0.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Tomas for his hard work in decoding much of this information, and
to Jens Duttke for getting me started on this format.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FLIR Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
