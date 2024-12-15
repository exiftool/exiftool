#------------------------------------------------------------------------------
# File:         Ricoh.pm
#
# Description:  Ricoh EXIF maker notes tags
#
# Revisions:    03/28/2005 - P. Harvey Created
#
# References:   1) http://www.ozhiker.com/electronics/pjmt/jpeg_info/ricoh_mn.html
#               2) http://homepage3.nifty.com/kamisaka/makernote/makernote_ricoh.htm
#               3) Tim Gray private communication (GR)
#               4) https://github.com/atotto/ricoh-theta-tools/
#               5) https://github.com/ricohapi/theta-api-specs/blob/main/theta-metadata/README.md
#               IB) Iliah Borg private communication (LibRaw)
#------------------------------------------------------------------------------

package Image::ExifTool::Ricoh;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '1.38';

sub ProcessRicohText($$$);
sub ProcessRicohRMETA($$$);
sub ProcessRicohRDT($$$);

# lens types for Ricoh GXR
my %ricohLensIDs = (
    Notes => q{
        Lens units available for the GXR, used by the Ricoh Composite LensID tag.  Note
        that unlike lenses for all other makes of cameras, the focal lengths in these
        model names have already been scaled to include the 35mm crop factor.
    },
    # (the exact lens model names used by Ricoh, except for a change in case)
    'RL1' => 'GR Lens A12 50mm F2.5 Macro',
    'RL2' => 'Ricoh Lens S10 24-70mm F2.5-4.4 VC',
    'RL3' => 'Ricoh Lens P10 28-300mm F3.5-5.6 VC',
    'RL5' => 'GR Lens A12 28mm F2.5',
    'RL8' => 'Mount A12',
    'RL6' => 'Ricoh Lens A16 24-85mm F3.5-5.5',
);

%Image::ExifTool::Ricoh::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    0x0001 => { Name => 'MakerNoteType',   Writable => 'string' },
    0x0002 => { #PH
        Name => 'FirmwareVersion',
        Writable => 'string',
        # eg. "Rev0113" is firmware version 1.13
        PrintConv => '$val=~/^Rev(\d+)$/ ? sprintf("%.2f",$1/100) : $val',
        PrintConvInv => '$val=~/^(\d+)\.(\d+)$/ ? sprintf("Rev%.2d%.2d",$1,$2) : $val',
    },
    0x0005 => [ #PH
        {
            Condition => '$$valPt =~ /^[-\w ]+$/',
            Name => 'SerialNumber', # (verified for GXR)
            Writable => 'undef',
            Count => 16,
            Notes => q{
                the serial number stamped on the camera begins with 2 model-specific letters
                followed by the last 8 digits of this value.  For the GXR, this is the
                serial number of the lens unit
            },
            PrintConv => '$val=~s/^(.*)(.{8})$/($1)$2/; $val',
            PrintConvInv => '$val=~tr/()//d; $val',
        },{
            Name => 'InternalSerialNumber',
            Writable => 'undef',
            Count => 16,
            ValueConv => 'unpack("H*", $val)',
            ValueConvInv => 'pack("H*", $val)',
        },
    ],
    0x0e00 => {
        Name => 'PrintIM',
        Writable => 0,
        Description => 'Print Image Matching',
        SubDirectory => { TagTable => 'Image::ExifTool::PrintIM::Main' },
    },
    0x1000 => { #3
        Name => 'RecordingFormat',
        Writable => 'int16u',
        PrintConv => {
            2 => 'JPEG',
            3 => 'DNG',
        },
    },
    0x1001 => [{
        Name => 'ImageInfo',
        Condition => '$format ne "int16u"',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::ImageInfo' },
    },{ #3
        Name => 'ExposureProgram',
        Writable => 'int16u',
        Notes => 'GR',
        PrintConv => {
            1 => 'Auto',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Shutter/aperture priority AE', # TAv
            6 => 'Manual',
            7 => 'Movie', #PH
        },
    }],
    0x1002 => { #3
        Name => 'DriveMode',
        Condition => '$format eq "int16u"',
        Notes => 'valid only for some models',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Single-frame',
            1 => 'Continuous',
            8 => 'AF-priority Continuous',
        },
    },
    0x1003 => [{
        Name => 'Sharpness',
        Condition => '$format ne "int16u"',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Sharp',
            1 => 'Normal',
            2 => 'Soft',
        },
    },{ #3
        Name => 'WhiteBalance',
        Writable => 'int16u',
        Notes => 'GR',
        PrintConv => {
            0 => 'Auto',
            1 => 'Multi-P Auto',
            2 => 'Daylight',
            3 => 'Cloudy',
            4 => 'Incandescent 1',
            5 => 'Incandescent 2',
            6 => 'Daylight Fluorescent',
            7 => 'Neutral White Fluorescent',
            8 => 'Cool White Fluorescent',
            9 => 'Warm White Fluorescent',
            10 => 'Manual',
            11 => 'Kelvin',
            12 => 'Shade', #IB
        },
    }],
    0x1004 => { #3
        Name => 'WhiteBalanceFineTune',
        Condition => '$format eq "int16u"',
        Format => 'int16s',
        Writable => 'int16u',
        Notes => q{
            2 numbers: amount of adjustment towards Amber and Green.  Not valid for all
            models
        },
    },
    # 0x1005 int16u - 5
    0x1006 => { #3
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Manual',
            2 => 'Multi AF',
            3 => 'Spot AF',
            4 => 'Snap',
            5 => 'Infinity',
            7 => 'Face Detect', #PH
            8 => 'Subject Tracking',
            9 => 'Pinpoint AF',
            10 => 'Movie', #PH
        },
    },
    0x1007 => { #3
        Name => 'AutoBracketing',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            9 => 'AE',
            11 => 'WB',
            16 => 'DR', # (dynamic range)
            17 => 'Contrast',
            18 => 'WB2', # (selects two different WB presets besides normal)
            19 => 'Effect',
        },
    },
    0x1009 => { #3
        Name => 'MacroMode',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x100a => { #3
        Name => 'FlashMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto, Fired',
            2 => 'On',
            3 => 'Auto, Fired, Red-eye reduction',
            4 => 'Slow Sync',
            5 => 'Manual',
            6 => 'On, Red-eye reduction',
            7 => 'Synchro, Red-eye reduction',
            8 => 'Auto, Did not fire',
        },
    },
    0x100b => { #3
        Name => 'FlashExposureComp',
        Writable => 'rational64s',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    0x100c => { #3
        Name => 'ManualFlashOutput',
        Writable => 'rational64s',
        PrintConv => {
               0 => 'Full',
             -24 => '1/1.4',
             -48 => '1/2',
             -72 => '1/2.8',
             -96 => '1/4',
            -120 => '1/5.6',
            -144 => '1/8',
            -168 => '1/11',
            -192 => '1/16',
            -216 => '1/22',
            -240 => '1/32',
            -288 => '1/64',
        },
    },
    0x100d => { #3
        Name => 'FullPressSnap',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x100e => { #3
        Name => 'DynamicRangeExpansion',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            3 => 'Weak',
            4 => 'Medium',
            5 => 'Strong',
        },
    },
    0x100f => { #3
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Weak',
            2 => 'Medium',
            3 => 'Strong',
        },
    },
    0x1010 => { #3
        Name => 'ImageEffects',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Standard',
            1 => 'Vivid',
            3 => 'Black & White',
            5 => 'B&W Toning Effect',
            6 => 'Setting 1',
            7 => 'Setting 2',
            9 => 'High-contrast B&W',
            10 => 'Cross Process',
            11 => 'Positive Film',
            12 => 'Bleach Bypass',
            13 => 'Retro',
            15 => 'Miniature',
            17 => 'High Key',
        },
    },
    0x1011 => { #3
        Name => 'Vignetting',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Medium',
            3 => 'High',
        },
    },
    0x1012 => { #PH
        Name => 'Contrast',
        Writable => 'int32u',
        Format => 'int32s', #3 (high-contrast B&W also has -1 and -2 settings)
        PrintConv => {
            OTHER => sub { shift },
            2147483647 => 'MAX', #3 (high-contrast B&W effect MAX setting)
        },
    },
    0x1013 => { Name => 'Saturation', Writable => 'int32u' }, #PH
    0x1014 => { Name => 'Sharpness',  Writable => 'int32u' }, #3
    0x1015 => { #3
        Name => 'ToningEffect',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Sepia',
            2 => 'Red',
            3 => 'Green',
            4 => 'Blue',
            5 => 'Purple',
            6 => 'B&W',
            7 => 'Color',
        },
    },
    0x1016 => { #3
        Name => 'HueAdjust',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Basic',
            2 => 'Magenta',
            3 => 'Yellow',
            4 => 'Normal',
            5 => 'Warm',
            6 => 'Cool',
        },
    },
    0x1017 => { #3
        Name => 'WideAdapter',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Not Attached',
            2 => 'Attached', # (21mm)
        },
    },
    0x1018 => { #3
        Name => 'CropMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On (35mm)',
            2 => 'On (47mm)', #IB
        },
    },
    0x1019 => { #3
        Name => 'NDFilter',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x101a => { Name => 'WBBracketShotNumber', Writable => 'int16u' }, #3
    # 0x1100 - related to DR correction (ref 3)
    0x1307 => { Name => 'ColorTempKelvin',     Writable => 'int32u' }, #3
    0x1308 => { Name => 'ColorTemperature',    Writable => 'int32u' }, #3
    0x1500 => { #3
        Name => 'FocalLength',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0x1200 => { #3
        Name => 'AFStatus',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Out of Focus',
            1 => 'In Focus',
        },
    },
    # 0x1201-0x1204 - related to focus points (ref 3)
    0x1201 => { #PH (NC)
        Name => 'AFAreaXPosition1',
        Writable => 'int32u',
        Notes => 'manual AF area position in a 1280x864 image',
    },
    0x1202 => { Name => 'AFAreaYPosition1', Writable => 'int32u' }, #PH (NC)
    0x1203 => { #PH (NC)
        Name => 'AFAreaXPosition',
        Writable => 'int32u',
        Notes => 'manual AF area position in the full image',
        # (coordinates change to correspond with smaller image
        #  when recording reduced-size JPEG)
    },
    0x1204 => { Name => 'AFAreaYPosition', Writable => 'int32u' }, #PH (NC)
    0x1205 => { #3
        Name => 'AFAreaMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            2 => 'Manual',
        },
    },
    0x1601 => { Name => 'SensorWidth',  Writable => 'int32u' }, #3
    0x1602 => { Name => 'SensorHeight', Writable => 'int32u' }, #3
    0x1603 => { Name => 'CroppedImageWidth',  Writable => 'int32u' }, #3
    0x1604 => { Name => 'CroppedImageHeight', Writable => 'int32u' }, #3
    # 0x1700 - Composite? (0=normal image, 1=interval composite, 2=multi-exposure composite) (ref 3)
    # 0x1703 - 0=normal, 1=final composite (ref 3)
    # 0x1704 - 0=normal, 2=final composite (ref 3)
    0x2001 => [
        {
            Name => 'RicohSubdir',
            Condition => q{
                $self->{Model} !~ /^Caplio RR1\b/ and
                ($format ne 'int32u' or $count != 1)
            },
            SubDirectory => {
                Validate => '$val =~ /^\[Ricoh Camera Info\]/',
                TagTable => 'Image::ExifTool::Ricoh::Subdir',
                Start => '$valuePtr + 20',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'RicohSubdirIFD',
            # the CX6 and GR Digital 4 write an int32u pointer in AVI videos -- doh!
            Condition => '$self->{Model} !~ /^Caplio RR1\b/',
            Flags => 'SubIFD',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Ricoh::Subdir',
                Start => '$val + 20', # (skip over "[Ricoh Camera Info]\0" header)
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'RicohRR1Subdir',
            SubDirectory => {
                Validate => '$val =~ /^\[Ricoh Camera Info\]/',
                TagTable => 'Image::ExifTool::Ricoh::Subdir',
                Start => '$valuePtr + 20',
                ByteOrder => 'BigEndian',
                # the Caplio RR1 uses a different base address -- doh!
                Base => '$start-20',
            },
        },
    ],
    0x4001 => {
        Name => 'ThetaSubdir',
        Groups => { 1 => 'MakerNotes' },    # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Ricoh::ThetaSubdir',
            Start => '$val',
        },
    },
);

# Ricoh type 2 maker notes (ref PH)
# (similar to Kodak::Type11 and GE::Main)
%Image::ExifTool::Ricoh::Type2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Tags written by models such as the Ricoh HZ15 and the Pentax XG-1.  These
        are not writable due to numerous formatting errors as written by these
        cameras.
    },
    # 0x104 - int32u: 1
    # 0x200 - int32u[3]: 0 0 0
    # 0x202 - int16u: 0 (GE Macro?)
    # 0x203 - int16u: 0,3 (Kodak PictureEffect?)
    # 0x204 - rational64u: 0/10
    # 0x205 - rational64u: 150/1
    # 0x206 - float[6]: (not really float because size should be 2 bytes)
    0x207 => {
        Name => 'RicohModel',
        Writable => 'string',
    },
    0x300 => {
        # brutal.  There are lots of errors in the XG-1 maker notes.  For the XG-1,
        # 0x300 has a value of "XG-1Pentax".  The "XG-1" part is likely an improperly
        # stored 0x207 RicohModel, resulting in an erroneous 4-byte offset for this tag
        Name => 'RicohMake',
        Writable => 'undef',
        ValueConv => '$val =~ s/ *$//; $val',
    },
    # 0x306 - int16u: 1
    # 0x500 - int16u: 0,1
    # 0x501 - int16u: 0
    # 0x502 - int16u: 0
    # 0x9c9c - int8u[6]: ?
    # 0xadad - int8u[20480]: ?
);

# Ricoh image info (ref 2)
%Image::ExifTool::Ricoh::ImageInfo = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    IS_OFFSET => [ 28 ],   # tag 28 is 'IsOffset'
    0 => {
        Name => 'RicohImageWidth',
        Format => 'int16u',
    },
    2 => {
        Name => 'RicohImageHeight',
        Format => 'int16u',
    },
    6 => {
        Name => 'RicohDate',
        Groups => { 2 => 'Time' },
        Format => 'int8u[7]',
        # (what an insane way to encode the date)
        ValueConv => q{
            sprintf("%.2x%.2x:%.2x:%.2x %.2x:%.2x:%.2x",
                    split(' ', $val));
        },
        ValueConvInv => q{
            my @vals = ($val =~ /(\d{1,2})/g);
            push @vals, 0 if @vals < 7;
            join(' ', map(hex, @vals));
        },
    },
    28 => {
        Name => 'PreviewImageStart',
        Format => 'int16u', # ha!  (only the lower 16 bits, even if > 0xffff)
        Flags => 'IsOffset',
        OffsetPair => 30,   # associated byte count tagID
        DataTag => 'PreviewImage',
        Protected => 2,
        WriteGroup => 'MakerNotes',
        # prevent preview from being written to MakerNotes of DNG images
        RawConvInv => q{
            return $val if $$self{FILE_TYPE} eq "JPEG";
            warn "\n"; # suppress warning
            return undef;
        },
    },
    30 => {
        Name => 'PreviewImageLength',
        Format => 'int16u',
        OffsetPair => 28,   # point to associated offset
        DataTag => 'PreviewImage',
        Protected => 2,
        WriteGroup => 'MakerNotes',
        RawConvInv => q{
            return $val if $$self{FILE_TYPE} eq "JPEG";
            warn "\n"; # suppress warning
            return undef;
        },
    },
    32 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto', #PH
            2 => 'On',
        },
    },
    33 => {
        Name => 'Macro',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    34 => {
        Name => 'Sharpness',
        PrintConv => {
            0 => 'Sharp',
            1 => 'Normal',
            2 => 'Soft',
        },
    },
    38 => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Tungsten',
            4 => 'Fluorescent',
            5 => 'Manual', #PH (GXR)
            7 => 'Detail',
            9 => 'Multi-pattern Auto', #PH (GXR)
        },
    },
    39 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => 'Auto',
            1 => 64,
            2 => 100,
            4 => 200,
            6 => 400,
            7 => 800,
            8 => 1600,
            9 => 'Auto', #PH (? CX3)
            10 => 3200, #PH (A16)
            11 => '100 (Low)', #PH (A16)
        },
    },
    40 => {
        Name => 'Saturation',
        PrintConv => {
            0 => 'High',
            1 => 'Normal',
            2 => 'Low',
            3 => 'B&W',
            6 => 'Toning Effect', #PH (GXR Sepia,Red,Green,Blue,Purple)
            9 => 'Vivid', #PH (GXR)
            10 => 'Natural', #PH (GXR)
        },
    },
);

# Ricoh subdirectory tags (ref PH)
# NOTE: this subdir is currently not writable because the offsets would require
# special code to handle the funny start location and base offset
%Image::ExifTool::Ricoh::Subdir = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    # the significance of the following 2 dates is not known.  They are usually
    # within a month of each other, but I have seen differences of nearly a year.
    # Sometimes the first is more recent, and sometimes the second.
    # 0x0003 - int32u[1]
    0x0004 => { # (NC)
        Name => 'ManufactureDate1',
        Groups => { 2 => 'Time' },
        Writable => 'string',
        Count => 20,
    },
    0x0005 => { # (NC)
        Name => 'ManufactureDate2',
        Groups => { 2 => 'Time' },
        Writable => 'string',
        Count => 20,
    },
    # 0x0006 - undef[16] ?
    # 0x0007 - int32u[1] ?
    # 0x000c - int32u[2] 1st number is a counter (file number? shutter count?) - PH
    # 0x0014 - int8u[338] could contain some data related to face detection? - PH
    # 0x0015 - int8u[2]: related to noise reduction?
    0x001a => { #PH
        Name => 'FaceInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::FaceInfo' },
    },
    0x0029 => {
        Name => 'FirmwareInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::FirmwareInfo' },
    },
    0x002a => {
        Name => 'NoiseReduction',
        # this is the applied value if NR is set to "Auto"
        Writable => 'int32u',
        PrintConv => {
            0 => 'Off',
            1 => 'Weak',
            2 => 'Strong',
            3 => 'Max',
        },
    },
    0x002c => { # (GXR)
        Name => 'SerialInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::SerialInfo' },
    }
    # 0x000E ProductionNumber? (ref 2) [no. zero for most models - PH]
);

# Ricoh Theta subdirectory tags - Contains orientation information (ref 4)
%Image::ExifTool::Ricoh::ThetaSubdir = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    # 0x0001 - int16u[1] ?
    # 0x0002 - int16u[1] ?
    0x0003 => {
        Name => 'Accelerometer',
        Writable => 'rational64s',
        Count => 2,
    },
    0x0004 => {
        Name => 'Compass',
        Writable => 'rational64u',
    },
    # 0x0005 - int16u[1] ?
    # 0x0006 - int16u[1] ?
    # 0x0007 - int16u[1] ?
    # 0x0008 - int16u[1] ?
    # 0x0009 - int16u[1] ?
    0x000a => {
        Name => 'TimeZone',
        Writable => 'string',
    },
    # 0x0101 - int16u[4] ISO (why 4 values?)
    # 0x0102 - rational64s[2] FNumber (why 2 values?)
    # 0x0103 - rational64u[2] ExposureTime (why 2 values?)
    # 0x0104 - string[9] SerialNumber?
    # 0x0105 - string[9] SerialNumber?
);

# face detection information (ref PH, CX4)
%Image::ExifTool::Ricoh::FaceInfo = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 181 ],
    0xb5 => { # (should be int16u at 0xb4?)
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0xb6 => {
        Name => 'FaceDetectFrameSize',
        Format => 'int16u[2]',
    },
    0xbc => {
        Name => 'Face1Position',
        Condition => '$$self{FacesDetected} >= 1',
        Format => 'int16u[4]',
        Notes => q{
            left, top, width and height of detected face in coordinates of
            FaceDetectFrameSize with increasing Y downwards
        },
    },
    0xc8 => {
        Name => 'Face2Position',
        Condition => '$$self{FacesDetected} >= 2',
        Format => 'int16u[4]',
    },
    0xd4 => {
        Name => 'Face3Position',
        Condition => '$$self{FacesDetected} >= 3',
        Format => 'int16u[4]',
    },
    0xe0 => {
        Name => 'Face4Position',
        Condition => '$$self{FacesDetected} >= 4',
        Format => 'int16u[4]',
    },
    0xec => {
        Name => 'Face5Position',
        Condition => '$$self{FacesDetected} >= 5',
        Format => 'int16u[4]',
    },
    0xf8 => {
        Name => 'Face6Position',
        Condition => '$$self{FacesDetected} >= 6',
        Format => 'int16u[4]',
    },
    0x104 => {
        Name => 'Face7Position',
        Condition => '$$self{FacesDetected} >= 7',
        Format => 'int16u[4]',
    },
    0x110 => {
        Name => 'Face8Position',
        Condition => '$$self{FacesDetected} >= 8',
        Format => 'int16u[4]',
    },
);

# firmware version information (ref PH)
%Image::ExifTool::Ricoh::FirmwareInfo = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    0x00 => {
        Name => 'FirmwareRevision',
        Format => 'string[12]',
    },
    0x0c => {
        Name => 'FirmwareRevision2',
        Format => 'string[12]',
    },
);

# serial/version number information written by GXR (ref PH)
%Image::ExifTool::Ricoh::SerialInfo = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    NOTES => 'This information is found in images from the GXR.',
    0 => {
        Name => 'BodyFirmware', #(NC)
        Format => 'string[16]',
        # observed: "RS1 :V00560000" --> FirmwareVersion "Rev0056"
        #           "RS1 :V01020200" --> FirmwareVersion "Rev0102"
    },
    16 => {
        Name => 'BodySerialNumber',
        Format => 'string[16]',
        # observed: "SID:00100056" --> "WD00100056" on plate
    },
    32 => {
        Name => 'LensFirmware', #(NC)
        Format => 'string[16]',
        # observed: "RL1 :V00560000", "RL1 :V01020200" - A12 50mm F2.5 Macro
        #           "RL2 :V00560000", "RL2 :V01020300" - S10 24-70mm F2.5-4.4 VC
        # --> used in a Composite tag to determine LensType
    },
    48 => {
        Name => 'LensSerialNumber',
        Format => 'string[16]',
        # observed: (S10) "LID:00010024" --> "WF00010024" on plate
        #           (A12) "LID:00010054" --> "WE00010029" on plate??
    },
);

# Ricoh text-type maker notes (PH)
%Image::ExifTool::Ricoh::Text = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessRicohText,
    NOTES => q{
        Some Ricoh DC and RDC models use a text-based format for their maker notes
        instead of the IFD format used by the Caplio models.  Below is a list of known
        tags in this information.
    },
    Rev => {
        Name => 'FirmwareVersion',
        PrintConv => '$val=~/^\d+$/ ? sprintf("%.2f",$val/100) : $val',
        PrintConvInv => '$val=~/^(\d+)\.(\d+)$/ ? sprintf("%.2d%.2d",$1,$2) : $val',
    },
    Rv => {
        Name => 'FirmwareVersion',
        PrintConv => '$val=~/^\d+$/ ? sprintf("%.2f",$val/100) : $val',
        PrintConvInv => '$val=~/^(\d+)\.(\d+)$/ ? sprintf("%.2d%.2d",$1,$2) : $val',
    },
    Rg => 'RedGain',
    Gg => 'GreenGain',
    Bg => 'BlueGain',
);

%Image::ExifTool::Ricoh::RMETA = (
    GROUPS => { 0 => 'APP5', 1 => 'RMETA', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::Ricoh::ProcessRicohRMETA,
    NOTES => q{
        The Ricoh Caplio Pro G3 has the ability to add custom fields to the APP5
        "RMETA" segment of JPEG images.  While only a few observed tags have been
        defined below, ExifTool will extract any information found here.
    },
    'Sign type' => { Name => 'SignType', PrintConv => {
        1 => 'Directional',
        2 => 'Warning',
        3 => 'Information',
    } },
    Location => { PrintConv => {
        1 => 'Verge',
        2 => 'Gantry',
        3 => 'Central reservation',
        4 => 'Roundabout',
    } },
    Lit => { PrintConv => {
        1 => 'Yes',
        2 => 'No',
    } },
    Condition => { PrintConv => {
        1 => 'Good',
        2 => 'Fair',
        3 => 'Poor',
        4 => 'Damaged',
    } },
    Azimuth => { PrintConv => {
        1 => 'N',
        2 => 'NNE',
        3 => 'NE',
        4 => 'ENE',
        5 => 'E',
        6 => 'ESE',
        7 => 'SE',
        8 => 'SSE',
        9 => 'S',
        10 => 'SSW',
        11 => 'SW',
        12 => 'WSW',
        13 => 'W',
        14 => 'WNW',
        15 => 'NW',
        16 => 'NNW',
    } },
    _audio => {
        Name => 'SoundFile',
        Notes => 'audio data recorded in JPEG images by the G700SE',
    },
    _barcode => { Name => 'Barcodes', List => 1 },
);

# information stored in Ricoh AVI images (ref PH)
%Image::ExifTool::Ricoh::AVI = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    ucmt => {
        Name => 'Comment',
        # Ricoh writes a "Unicode" header even when text is ASCII (spaces anyway)
        ValueConv => '$_=$val; s/^(Unicode\0|ASCII\0\0\0)//; tr/\0//d; s/\s+$//; $_',
    },
    mnrt => {
        Name => 'MakerNoteRicoh',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Ricoh::Main',
            Start => '$valuePtr + 8',
            ByteOrder => 'BigEndian',
            Base => '8',
        },
    },
    rdc2 => {
        Name => 'RicohRDC2',
        Unknown => 1,
        ValueConv => 'unpack("H*",$val)',
        # have seen values like 0a000444 and 00000000 - PH
    },
    thum => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
);

# real-time metadata in RDTA atom (ref 5)
%Image::ExifTool::Ricoh::RDTA = (
    PROCESS_PROC => \&ProcessRicohRDT,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Location' },
    0 => { Name => 'Accelerometer', Format => 'float[3]' },
    16 => { Name => 'TimeStamp', Format => 'int64u', ValueConv => '$val * 1e-9' },
);

# real-time metadata in RDTB atom (ref 5)
%Image::ExifTool::Ricoh::RDTB = (
    PROCESS_PROC => \&ProcessRicohRDT,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Location' },
    0 => { Name => 'Gyroscope', Format => 'float[3]', Notes => 'rad/s' },
    16 => { Name => 'TimeStamp', Format => 'int64u', ValueConv => '$val * 1e-9' },
);

# real-time metadata in RDTC atom (ref 5)
%Image::ExifTool::Ricoh::RDTC = (
    PROCESS_PROC => \&ProcessRicohRDT,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Location' },
    0 => { Name => 'MagneticField', Format => 'float[3]' },
    16 => { Name => 'TimeStamp', Format => 'int64u', ValueConv => '$val * 1e-9' },
);

# real-time metadata in RDTG atom (ref 5)
%Image::ExifTool::Ricoh::RDTG = (
    PROCESS_PROC => \&ProcessRicohRDT,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    0 => { Name => 'TimeStamp', Format => 'int64u', ValueConv => '$val * 1e-9' },
    100 => { Name => 'FrameNumber', Notes => 'generated internally' },
);

# real-time metadata in RDTL atom (ref 5)
%Image::ExifTool::Ricoh::RDTL = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Location' },
    0 => {
        Name => 'GPSDateTime',
        Groups => { 2 => 'Time' },
        Format => 'double',
        ValueConv => 'ConvertUnixTime($val*1e-9, 1, 9)', # (NC -- what is the epoch?)
        PrintConv => '$self->ConvertDateTime($val)',
    },
    8 => {
        Name => 'GPSLatitude',
        Format => 'double',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    16 => {
        Name => 'GPSLongitude',
        Format => 'double',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    24 => {
        Name => 'GPSAltitude',
        Format => 'double',
        PrintConv => '($val =~ s/^-// ? "$val m Below" : "$val m Above") . " Sea Level"',
    },
);

# Ricoh composite tags
%Image::ExifTool::Ricoh::Composite = (
    GROUPS => { 2 => 'Camera' },
    LensID => {
        SeparateTable => 'Ricoh LensID',
        Require => 'Ricoh:LensFirmware',
        RawConv => '$val[0] ? $val[0] : undef',
        ValueConv => '$val=~s/\s*:.*//; $val',
        PrintConv => \%ricohLensIDs,
    },
    RicohPitch => {
        Require => 'Ricoh:Accelerometer',
        ValueConv => 'my @v = split(" ",$val); $v[1]',
    },
    RicohRoll => {
        Require => 'Ricoh:Accelerometer',
        ValueConv => 'my @v = split(" ",$val); $v[0] <= 180 ? $v[0] : $v[0] - 360',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Ricoh');


#------------------------------------------------------------------------------
# Process Ricoh RDT* real-time metadata
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessRicohRDT($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $dirName = $$dirInfo{DirName};
    my ($i, $rdtg);
    return 0 if $dirLen < 16;
    my $ee = $et->Options('ExtractEmbedded');
    unless ($ee) {
        $et->Warn('Use ExtractEmbedded option to read Ricoh real-time metadata',3);
        return 1;
    }
    my $endian = substr($$dataPt, 8, 2);
    SetByteOrder($endian eq "\x23\x01" ? 'II' : 'MM');
    my $count = Get32u($dataPt, 0);
    my $len = Get16u($dataPt, 6);
    if ($dirName eq 'RicohRDTG') {
        if ($ee < 2) {
            $et->Warn('Set ExtractEmbedded option to 2 or higher to extract frame timestamps',3);
            return 1;
        }
        $rdtg = 0;
        $et->Warn('Unexpected RDTG record length') if $len > 8;
    }
    if ($count * $len + 16 > $dirLen) {
        $et->Warn("Truncated $dirName data");
        $count = int(($dirLen - 16) / $len);
    }
    $et->VerboseDir($dirName);
    $$dirInfo{DirStart} = 16;
    $$dirInfo{DirLen} = $len;
    for ($i=0; $i<$count; ++$i) {;
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        $et->HandleTag($tagTablePtr, 100, $rdtg++) if defined $rdtg;
        $et->ProcessBinaryData($dirInfo, $tagTablePtr);
        $$dirInfo{DirStart} += $len;
    }
    delete $$et{DOC_NUM};
    return 1;
}

#------------------------------------------------------------------------------
# Process Ricoh text-based maker notes
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessRicohText($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = $$dirInfo{DataLen};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $dataLen - $dirStart;
    my $verbose = $et->Options('Verbose');

    my $data = substr($$dataPt, $dirStart, $dirLen);
    return 1 if $data =~ /^\0/;     # blank Ricoh maker notes
    $et->VerboseDir('RicohText', undef, $dirLen);
    # validate text maker notes
    unless ($data =~ /^(Rev|Rv)/) {
        $et->Warn('Bad Ricoh maker notes');
        return 0;
    }
    while ($data =~ m/([A-Z][a-z]{1,2})([0-9A-F]+);/sg) {
        my $tag = $1;
        my $val = $2;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($verbose) {
            $et->VerboseInfo($tag, $tagInfo,
                Table  => $tagTablePtr,
                Value  => $val,
            );
        }
        unless ($tagInfo) {
            next unless $$et{OPTIONS}{Unknown};
            $tagInfo = {
                Name => "Ricoh_Text_$tag",
                Unknown => 1,
                PrintConv => \&Image::ExifTool::LimitLongValues,
            };
            # add tag information to table
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $et->FoundTag($tagInfo, $val);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Ricoh APP5 RMETA information
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessRicohRMETA($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dataLen = length($$dataPt);
    my $dirLen = $dataLen - $dirStart;
    my $verbose = $et->Options('Verbose');

    $et->VerboseDir('Ricoh RMETA') if $verbose;
    $dirLen < 20 and $et->Warn('Truncated Ricoh RMETA data', 1), return 0;
    my $byteOrder = substr($$dataPt, $dirStart, 2);
    $byteOrder = GetByteOrder() if $byteOrder eq "\0\0"; # (same order as container)
    SetByteOrder($byteOrder) or $et->Warn('Bad Ricoh RMETA data', 1), return 0;
    # get the RMETA segment number
    my $rmetaNum = Get16u($dataPt, $dirStart+4);
    if ($rmetaNum != 0) {
        # not sure how to recognize audio, so do it by checking for "RIFF" header
        # and assume all subsequent RMETA segments are part of the audio data
        # (but it looks like the int16u at $dirStart+6 is the next block number
        # if the data is continued, or 0 for the last block)
        $dirLen < 14 and $et->Warn('Short Ricoh RMETA block', 1), return 0;
        if ($$dataPt =~ /^.{20}BARCODE/s) {
            my $val = substr($$dataPt, 20);
            $val =~ s/\0.*//s;
            $val =~ s/^BARCODE\w+,\d{2},//;
            my @codes;
            for (;;) {
                $val =~ s/(\d+),// and length $val >= $1 or last;
                push @codes, substr($val, 0, $1);
                last unless length $val > $1;
                $val = substr($val, $1+1);
            }
            $et->HandleTag($tagTablePtr, '_barcode', \@codes) if @codes;
            return 1;
        } elsif ($$dataPt =~ /^.{18}ASCII/s) {
            # (ignore barcode tag names for now)
            return 1;
        }
        my $audioLen = Get16u($dataPt, $dirStart+12);
        $audioLen + 14 > $dirLen and $et->Warn('Truncated Ricoh RMETA audio data', 1), return 0;
        my $buff = substr($$dataPt, $dirStart + 14, $audioLen);
        if ($audioLen >= 4 and substr($buff, 0, 4) eq 'RIFF') {
            $et->HandleTag($tagTablePtr, '_audio', \$buff);
        } elsif ($$et{VALUE}{SoundFile}) {
            ${$$et{VALUE}{SoundFile}} .= $buff;
        } else {
            $et->Warn('Unknown Ricoh RMETA type', 1);
            return 0;
        }
        return 1;
    }
    # decode standard RMETA tag directory
    my (@tags, @vals, @nums, $valPos, $numPos);
    my $pos = $dirStart + Get16u($dataPt, $dirStart+8);
    my $numEntries = Get16u($dataPt, $pos);
    $numEntries > 100 and $et->Warn('Bad RMETA entry count'), return 0;
    $pos += 10; # start of first RMETA section
    # loop through RMETA sections
    while ($pos <= $dataLen - 4) {
        my $type = Get16u($dataPt, $pos);
        my $size = Get16u($dataPt, $pos + 2);
        last unless $size;
        $pos += 4;
        $size -= 2;
        if ($size < 0 or $pos + $size > $dataLen) {
            $et->Warn('Corrupted Ricoh RMETA data', 1);
            last;
        }
        my $dat = substr($$dataPt, $pos, $size);
        if ($verbose) {
            $et->VPrint(2, "$$et{INDENT}RMETA section type=$type size=$size\n");
            $et->VerboseDump(\$dat, Addr => $$dirInfo{DataPos} + $pos);
        }
        if ($type == 1) {                       # section 1: tag names
            # save the tag names
            @tags = split /\0/, $dat, $numEntries+1;
        } elsif ($type == 2 || $type == 18) {   # section 2/18: string values (G800 uses type 18)
            # save the tag values (assume "ASCII\0" encoding since others never seen)
            @vals = split /\0/, $dat, $numEntries+1;
            $valPos = $pos; # save position of first string value
        } elsif ($type == 3) {                  # section 3: numerical values
            if ($size < $numEntries * 2) {
                $et->Warn('Truncated RMETA section 3');
            } else {
                # save the numerical tag values
                # (0=empty, 0xffff=text input, otherwise menu item number)
                @nums = unpack(($byteOrder eq 'MM' ? 'n' : 'v').$numEntries, $dat);
                $numPos = $pos; # save position of numerical values
            }
        } elsif ($type != 16) {
            $et->Warn("Unrecognized RMETA section (type $type, len $size)");
        }
        $pos += $size;
    }
    return 1 unless @tags or @vals;
    $valPos or $valPos = 0; # (just in case there was no value section)
    # find next tag in null-delimited list
    # unpack numerical values from block of int16u values
    my ($i, $name);
    for ($i=0; $i<$numEntries; ++$i) {
        my $tag = $tags[$i];
        my $val = $vals[$i];
        $val = '' unless defined $val;
        unless (defined $tag and length $tag) {
            length $val or ++$valPos, next;     # (skip empty entries)
            $tag = '';
        }
        ($name = $tag) =~ s/\b([a-z])/\U$1/gs;  # capitalize all words
        $name =~ s/ (\w)/\U$1/g;                # remove special characters
        $name = 'RMETA_Unknown' unless length($name);
        my $num = $nums[$i];
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo) {
            # make sure print conversion is defined
            $$tagInfo{PrintConv} = { } unless ref $$tagInfo{PrintConv} eq 'HASH';
        } else {
            # create tagInfo hash
            $tagInfo = { Name => $name, PrintConv => { } };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        # use string value directly if no numerical value
        $num = $val unless defined $num;
        # add conversion for this value (replacing any existing entry)
        $tagInfo->{PrintConv}->{$num} = length $val ? $val : $num;
        if ($verbose) {
            my %datParms;
            if (length $val) {
                %datParms = ( Start => $valPos, Size => length($val), Format => 'string' );
            } elsif ($numPos) {
                %datParms = ( Start => $numPos + $i * 2, Size => 2, Format => 'int16u' );
            }
            %datParms and $datParms{DataPt} = $dataPt, $datParms{DataPos} = $$dirInfo{DataPos};
            $et->VerboseInfo($tag, $tagInfo, Table=>$tagTablePtr, Value=>$num, %datParms);
        }
        $et->FoundTag($tagInfo, $num);
        $valPos += length($val) + 1;
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Ricoh - Ricoh EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Ricoh maker notes EXIF meta information.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/ricoh_mn.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Tim Gray for his help decoding a number of tags for the Ricoh GR.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Ricoh Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
