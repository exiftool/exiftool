#------------------------------------------------------------------------------
# File:         Kodak.pm
#
# Description:  Kodak EXIF maker notes and APP3 "Meta" tags
#
# Revisions:    03/28/2005  - P. Harvey Created
#
# References:   1) http://search.cpan.org/dist/Image-MetaData-JPEG/
#               2) http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html
#               3) http://www.cybercom.net/~dcoffin/dcraw/
#               IB) Iliah Borg private communication (LibRaw)
#
# Notes:        There really isn't much public information about Kodak formats.
#               The only source I could find was Image::MetaData::JPEG, which
#               didn't provide information about decoding the tag values.  So
#               this module represents a lot of work downloading sample images
#               (about 100MB worth!), and testing with my daughter's CX4200.
#------------------------------------------------------------------------------

package Image::ExifTool::Kodak;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.43';

sub ProcessKodakIFD($$$);
sub ProcessKodakText($$$);
sub ProcessPose($$$);
sub WriteKodakIFD($$$);

# Kodak type 1 maker notes (ref 1)
%Image::ExifTool::Kodak::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => q{
        The table below contains the most common set of Kodak tags.  The following
        Kodak camera models have been tested and found to use these tags: C360,
        C663, C875, CX6330, CX6445, CX7330, CX7430, CX7525, CX7530, DC4800, DC4900,
        DX3500, DX3600, DX3900, DX4330, DX4530, DX4900, DX6340, DX6440, DX6490,
        DX7440, DX7590, DX7630, EasyShare-One, LS420, LS443, LS633, LS743, LS753,
        V530, V550, V570, V603, V610, V705, Z650, Z700, Z710, Z730, Z740, Z760 and
        Z7590.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 8,
    0x00 => {
        Name => 'KodakModel',
        Format => 'string[8]',
    },
    0x09 => {
        Name => 'Quality',
        PrintConv => { #PH
            1 => 'Fine',
            2 => 'Normal',
        },
    },
    0x0a => {
        Name => 'BurstMode',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x0c => {
        Name => 'KodakImageWidth',
        Format => 'int16u',
    },
    0x0e => {
        Name => 'KodakImageHeight',
        Format => 'int16u',
    },
    0x10 => {
        Name => 'YearCreated',
        Groups => { 2 => 'Time' },
        Format => 'int16u',
    },
    0x12 => {
        Name => 'MonthDayCreated',
        Groups => { 2 => 'Time' },
        Format => 'int8u[2]',
        ValueConv => 'sprintf("%.2d:%.2d",split(" ", $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x14 => {
        Name => 'TimeCreated',
        Groups => { 2 => 'Time' },
        Format => 'int8u[4]',
        Shift => 'Time',
        ValueConv => 'sprintf("%.2d:%.2d:%.2d.%.2d",split(" ", $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x18 => {
        Name => 'BurstMode2',
        Format => 'int16u',
        Unknown => 1, # not sure about this tag (or other 'Unknown' tags)
    },
    0x1b => {
        Name => 'ShutterMode',
        PrintConv => { #PH
            0 => 'Auto',
            8 => 'Aperture Priority',
            32 => 'Manual?',
        },
    },
    0x1c => {
        Name => 'MeteringMode',
        PrintConv => { #PH
            0 => 'Multi-segment',
            1 => 'Center-weighted average',
            2 => 'Spot',
        },
    },
    0x1d => 'SequenceNumber',
    0x1e => {
        Name => 'FNumber',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x20 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x24 => {
        Name => 'ExposureCompensation',
        Format => 'int16s',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x26 => {
        Name => 'VariousModes',
        Format => 'int16u',
        Unknown => 1,
    },
    0x28 => {
        Name => 'Distance1',
        Format => 'int32u',
        Unknown => 1,
    },
    0x2c => {
        Name => 'Distance2',
        Format => 'int32u',
        Unknown => 1,
    },
    0x30 => {
        Name => 'Distance3',
        Format => 'int32u',
        Unknown => 1,
    },
    0x34 => {
        Name => 'Distance4',
        Format => 'int32u',
        Unknown => 1,
    },
    0x38 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'Normal',
            2 => 'Macro',
        },
    },
    0x3a => {
        Name => 'VariousModes2',
        Format => 'int16u',
        Unknown => 1,
    },
    0x3c => {
        Name => 'PanoramaMode',
        Format => 'int16u',
        Unknown => 1,
    },
    0x3e => {
        Name => 'SubjectDistance',
        Format => 'int16u',
        Unknown => 1,
    },
    0x40 => {
        Name => 'WhiteBalance',
        Priority => 0,
        PrintConv => { #PH
            0 => 'Auto',
            1 => 'Flash?',
            2 => 'Tungsten',
            3 => 'Daylight',
            # 5 - seen this for "Auto" with a ProBack 645M
        },
    },
    0x5c => {
        Name => 'FlashMode',
        Flags => 'PrintHex',
        # various models express this number differently
        PrintConv => { #PH
            0x00 => 'Auto',
            0x01 => 'Fill Flash',
            0x02 => 'Off',
            0x03 => 'Red-Eye',
            0x10 => 'Fill Flash',
            0x20 => 'Off',
            0x40 => 'Red-Eye?',
        },
    },
    0x5d => {
        Name => 'FlashFired',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x5e => {
        Name => 'ISOSetting',
        Format => 'int16u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/^\d+$/ ? $val : 0',
    },
    0x60 => {
        Name => 'ISO',
        Format => 'int16u',
    },
    0x62 => {
        Name => 'TotalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x64 => {
        Name => 'DateTimeStamp',
        Format => 'int16u',
        PrintConv => '$val ? "Mode $val" : "Off"',
        PrintConvInv => '$val=~tr/0-9//dc; $val ? $val : 0',
    },
    0x66 => {
        Name => 'ColorMode',
        Format => 'int16u',
        Flags => 'PrintHex',
        # various models express this number differently
        PrintConv => { #PH
            0x01 => 'B&W',
            0x02 => 'Sepia',
            0x03 => 'B&W Yellow Filter',
            0x04 => 'B&W Red Filter',
            0x20 => 'Saturated Color',
            0x40 => 'Neutral Color',
            0x100 => 'Saturated Color',
            0x200 => 'Neutral Color',
            0x2000 => 'B&W',
            0x4000 => 'Sepia',
        },
    },
    0x68 => {
        Name => 'DigitalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x6b => {
        Name => 'Sharpness',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
);

# Kodak type 2 maker notes (ref PH)
%Image::ExifTool::Kodak::Type2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => q{
        These tags are used by the Kodak DC220, DC260, DC265 and DC290,
        Hewlett-Packard PhotoSmart 618, C500 and C912, Pentax EI-200 and EI-2000,
        and Minolta EX1500Z.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x08 => {
        Name => 'KodakMaker',
        Format => 'string[32]',
    },
    0x28 => {
        Name => 'KodakModel',
        Format => 'string[32]',
    },
    0x6c => {
        Name => 'KodakImageWidth',
        Format => 'int32u',
    },
    0x70 => {
        Name => 'KodakImageHeight',
        Format => 'int32u',
    },
);

# Kodak type 3 maker notes (ref PH)
%Image::ExifTool::Kodak::Type3 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'These tags are used by the DC240, DC280, DC3400 and DC5000.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x0c => {
        Name => 'YearCreated',
        Groups => { 2 => 'Time' },
        Format => 'int16u',
    },
    0x0e => {
        Name => 'MonthDayCreated',
        Groups => { 2 => 'Time' },
        Format => 'int8u[2]',
        ValueConv => 'sprintf("%.2d:%.2d",split(" ", $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x10 => {
        Name => 'TimeCreated',
        Groups => { 2 => 'Time' },
        Format => 'int8u[4]',
        Shift => 'Time',
        ValueConv => 'sprintf("%2d:%.2d:%.2d.%.2d",split(" ", $val))',
        ValueConvInv => '$val=~tr/:./ /;$val',
    },
    0x1e => {
        Name => 'OpticalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x37 => {
        Name => 'Sharpness',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x38 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x3c => {
        Name => 'FNumber',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x4e => {
        Name => 'ISO',
        Format => 'int16u',
    },
);

# Kodak type 4 maker notes (ref PH)
%Image::ExifTool::Kodak::Type4 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'These tags are used by the DC200 and DC215.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x20 => {
        Name => 'OriginalFileName',
        Format => 'string[12]',
    },
);

# Kodak type 5 maker notes (ref PH)
%Image::ExifTool::Kodak::Type5 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        These tags are used by the CX4200, CX4210, CX4230, CX4300, CX4310, CX6200
        and CX6230.
    },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x14 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x1a => {
        Name => 'WhiteBalance',
        PrintConv => {
            1 => 'Daylight',
            2 => 'Flash',
            3 => 'Tungsten',
        },
    },
    0x1c => {
        Name => 'FNumber',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x1e => {
        Name => 'ISO',
        Format => 'int16u',
    },
    0x20 => {
        Name => 'OpticalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x22 => {
        Name => 'DigitalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x27 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Auto',
            1 => 'On',
            2 => 'Off',
            3 => 'Red-Eye',
        },
    },
    0x2a => {
        Name => 'ImageRotated',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x2b => {
        Name => 'Macro',
        PrintConv => { 0 => 'On', 1 => 'Off' },
    },
);

# Kodak type 6 maker notes (ref PH)
%Image::ExifTool::Kodak::Type6 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'These tags are used by the DX3215 and DX3700.',
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    0x10 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x14 => {
        Name => 'ISOSetting',
        Format => 'int32u',
        Unknown => 1,
    },
    0x18 => {
        Name => 'FNumber',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => 'int($val * 100 + 0.5)',
    },
    0x1a => {
        Name => 'ISO',
        Format => 'int16u',
    },
    0x1c => {
        Name => 'OpticalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x1e => {
        Name => 'DigitalZoom',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0x22 => {
        Name => 'Flash',
        Format => 'int16u',
        PrintConv => {
            0 => 'No Flash',
            1 => 'Fired',
        },
    },
);

# Kodak type 7 maker notes (ref PH)
%Image::ExifTool::Kodak::Type7 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => q{
        The maker notes of models such as the C340, C433, CC533, LS755, V803 and
        V1003 seem to start with the camera serial number.  The C310, C315, C330,
        C643, C743, CD33, CD43, CX7220 and CX7300 maker notes are also decoded using
        this table, although the strings for these cameras don't conform to the
        usual Kodak serial number format, and instead have the model name followed
        by 8 digits.
    },
    0 => { # (not confirmed)
        Name => 'SerialNumber',
        Format => 'string[16]',
        ValueConv => '$val=~s/\s+$//; $val', # remove trailing whitespace
        ValueConvInv => '$val',
    },
);

# Kodak IFD-format maker notes (ref PH)
%Image::ExifTool::Kodak::Type8 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Kodak models such as the ZD710, P712, P850, P880, V1233, V1253, V1275,
        V1285, Z612, Z712, Z812, Z885 use standard TIFF IFD format for the maker
        notes.  In keeping with Kodak's strategy of inconsistent makernotes, models
        such as the M380, M1033, M1093, V1073, V1273, Z1012, Z1085 and Z8612
        also use these tags, but these makernotes begin with a TIFF header instead
        of an IFD entry count and use relative instead of absolute offsets.  There
        is a large amount of information stored in these maker notes (apparently
        with much duplication), but relatively few tags have so far been decoded.
    },
    0xfc00 => [{
        Name => 'SubIFD0',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2, # (so HtmlDump doesn't show these as double-referenced)
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD0',
            Base => '$start',
            ProcessProc => \&ProcessKodakIFD,
            WriteProc => \&WriteKodakIFD,
        },
    },{
        Name => 'SubIFD0',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD0',
            Start => '$val',
            # (odd but true: the Base for this SubIFD is different than 0xfc01-0xfc06)
        },
    }],
    # SubIFD1 and higher data is preceded by a TIFF byte order mark to indicate
    # the byte ordering used.  Beginning with the M580, these subdirectories are
    # stored as 'undef' data rather than as a standard EXIF SubIFD.
    0xfc01 => [{
        Name => 'SubIFD1',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD1',
            Base => '$start',
        },
    },{
        Name => 'SubIFD1',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD1',
            Start => '$val',
            Base => '$start',
        },
    }],
    0xfc02 => [{
        Name => 'SubIFD2',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD2',
            Base => '$start',
        },
    },{
        Name => 'SubIFD2',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD2',
            Start => '$val',
            Base => '$start',
        },
    }],
    0xfc03 => [{
        Name => 'SubIFD3',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD3',
            Base => '$start',
        },
    },{
        Name => 'SubIFD3',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD3',
            Start => '$val',
            Base => '$start',
        },
    }],
    # (SubIFD4 has the pointer zeroed in my samples, but support it
    # in case it is used by future models -- ignored if pointer is zero)
    0xfc04 => [{
        Name => 'SubIFD4',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD4',
            Base => '$start',
        },
    },{
        Name => 'SubIFD4',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD4',
            Start => '$val',
            Base => '$start',
        },
    }],
    0xfc05 => [{
        Name => 'SubIFD5',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD5',
            Base => '$start',
        },
    },{
        Name => 'SubIFD5',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD5',
            Start => '$val',
            Base => '$start',
        },
    }],
    0xfc06 => [{ # new for the M580
        Name => 'SubIFD6',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD6',
            Base => '$start',
        },
    },{
        Name => 'SubIFD6',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD6',
            Start => '$val',
            Base => '$start',
        },
    }],
    0xfcff => {
        Name => 'SubIFD255',
        Condition => '$format eq "undef"',
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        NestedHtmlDump => 2,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SubIFD0',
            # (uses the same Base as the main MakerNote IFD)
        },
    },
    0xff00 => {
        Name => 'CameraInfo',
        Condition => '$$valPt ne "\0\0\0\0"',   # may be zero if dir doesn't exist
        Groups => { 1 => 'MakerNotes' },        # SubIFD needs group 1 set
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::CameraInfo',
            Start => '$val',
            # (uses the same Base as the main MakerNote IFD)
        },
    },
);

# Kodak type 9 maker notes (ref PH)
%Image::ExifTool::Kodak::Type9 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    NOTES => q{
        These tags are used by the Kodak C140, C180, C913, C1013, M320, M340 and
        M550, as well as various cameras marketed by other manufacturers.
    },
    0x0c => [
        {
            Name => 'FNumber',
            Condition => '$$self{Make} =~ /Kodak/i',
            Format => 'int16u',
            ValueConv => '$val / 100',
            ValueConvInv => 'int($val * 100 + 0.5)',
        },{
            Name => 'FNumber',
            Format => 'int16u',
            ValueConv => '$val / 10',
            ValueConvInv => 'int($val * 10 + 0.5)',
        },
    ],
    0x10 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val / 1e6',
        ValueConvInv => '$val * 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x14 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Format => 'string[20]',
        Shift => 'Time',
        ValueConv => '$val=~s{/}{:}g; $val',
        ValueConvInv => '$val=~s{^(\d{4}):(\d{2}):}{$1/$2/}; $val',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x34 => {
        Name => 'ISO',
        Format => 'int16u',
    },
    0x57 => {
        Name => 'FirmwareVersion',
        Condition => '$$self{Make} =~ /Kodak/i',
        Format => 'string[16]',
        Notes => 'Kodak only',
    },
    0xa8 => {
        Name => 'UnknownNumber', # (was SerialNumber, but not unique for all cameras. eg. C1013)
        Condition => '$$self{Make} =~ /Kodak/i and $$valPt =~ /^([A-Z0-9]{1,11}\0|[A-Z0-9]{12})/i',
        Format => 'string[12]',
        Notes => 'Kodak only',
        Writable => 0,
    },
    0xc4 => {
        Name => 'UnknownNumber', # (confirmed NOT to be serial number for Easyshare Mini - PH)
        Condition => '$$self{Make} =~ /Kodak/i and $$valPt =~ /^([A-Z0-9]{1,11}\0|[A-Z0-9]{12})/i',
        Format => 'string[12]',
        Notes => 'Kodak only',
        Writable => 0,
    },
);

# more Kodak IFD-format maker notes (ref PH)
%Image::ExifTool::Kodak::Type10 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRIORITY => 0,
    NOTES => q{
        Another variation of the IFD-format type, this time with just a byte order
        indicator instead of a full TIFF header.  These tags are used by the Z980.
    },
    # 0x01 int16u - always 0
    0x02 => {
        Name => 'PreviewImageSize',
        Writable => 'int16u',
        Count => 2,
    },
    # 0x03 int32u - ranges from about 33940 to 40680
    # 0x04 int32u - always 18493
    # 0x06 undef[4] - 07 d9 04 11
    # 0x07 undef[3] - varies
    # 0x08 int16u - 1 (mostly), 2
    # 0x09 int16u - 255
    # 0x0b int16u[2] - '0 0' (mostly), '20 0', '21 0', '1 0'
    # 0x0c int16u - 1 (mostly), 3, 259, 260
    # 0x0d int16u - 0
    # 0x0e int16u - 0, 1, 2 (MeteringMode? 0=Partial, 1,2=Multi)
    # 0x0f int16u - 0, 5 (MeteringMode? 0=Multi, 5=Partial)
    # 0x10 int16u - ranges from about 902 to 2308
    0x12 => {
        Name => 'ExposureTime',
        Writable => 'int32u',
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x13 => {
        Name => 'FNumber',
        Writable => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    0x14 => {
        Name => 'ISO',
        Writable => 'int16u',
        ValueConv => 'exp($val/3*log(2))*25',
        ValueConvInv => '3*log($val/25)/log(2)',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    # 0x15 int16u - 18-25 (SceneMode? 21=auto, 24=Aperture Priority, 19=high speed)
    # 0x16 int16u - 50
    # 0x17 int16u - 0, 65535 (MeteringMode? 0=Multi, 65535=Partial)
    # 0x19 int16u - 0, 4 (WhiteBalance? 0=Auto, 4=Manual)
    # 0x1a int16u - 0, 65535
    # 0x1b int16u - 416-696
    # 0x1c int16u - 251-439 (low when 0x1b is high)
    0x1d => {
        Name => 'FocalLength',
        Writable => 'int32u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    # 0x1e int16u - 100
    # 0x1f int16u - 0, 1
    # 0x20,0x21 int16u - 1
    # 0x27 undef[4] - fe ff ff ff
    # 0x32 undef[4] - 00 00 00 00
    # 0x61 int32u[2] - '0 0' or '34050 0'
    # 0x62 int8u - 0, 1
    # 0x63 int8u - 1
    # 0x64,0x65 int8u - 0, 1, 2
    # 0x66 int32u - 0
    # 0x67 int32u - 3
    # 0x68 int32u - 0
    # 0x3fe undef[2540]
);

# Kodak PixPro S-1 maker notes (ref PH)
# (similar to Ricoh::Type2 and GE::Main)
%Image::ExifTool::Kodak::Type11 = (
    # (can't currently write these)
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES =>q{
        These tags are found in models such as the PixPro S-1.  They are not
        writable because the inconsistency of Kodak maker notes is beginning to get
        on my nerves.
    },
    # (these are related to the Kodak QuickTime UserData tags)
    0x0104 => 'FirmwareVersion',
    0x0203 => {
        Name => 'PictureEffect',
        PrintConv => {
            0 => 'None',
            3 => 'Monochrome',
            9 => 'Kodachrome',
        },
    },
    # 0x0204 - ExposureComp or FlashExposureComp maybe?
    0x0207 => 'KodakModel',
    0x0300 => 'KodakMake',
    0x0308 => 'LensSerialNumber',
    0x0309 => 'LensModel',
    0x030d => { Name => 'LevelMeter', Unknown => 1 }, # (guess)
    0x0311 => 'Pitch', # Units??
    0x0312 => 'Yaw',   # Units??
    0x0313 => 'Roll',  # Units??
    0x0314 => { Name => 'CX',   Unknown => 1 },
    0x0315 => { Name => 'CY',   Unknown => 1 },
    0x0316 => { Name => 'Rads', Unknown => 1 },
);

# Kodak SubIFD0 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD0 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'SubIFD0 through SubIFD5 tags are written a number of newer Kodak models.',
    0xfa02 => {
        Name => 'SceneMode',
        Writable => 'int16u',
        Notes => 'may not be valid for some models', # eg. M580?
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Sport',
            3 => 'Portrait',
            4 => 'Landscape',
            6 => 'Beach',
            7 => 'Night Portrait',
            8 => 'Night Landscape',
            9 => 'Snow',
            10 => 'Text',
            11 => 'Fireworks',
            12 => 'Macro',
            13 => 'Museum',
            16 => 'Children',
            17 => 'Program',
            18 => 'Aperture Priority',
            19 => 'Shutter Priority',
            20 => 'Manual',
            25 => 'Back Light',
            28 => 'Candlelight',
            29 => 'Sunset',
            31 => 'Panorama Left-right',
            32 => 'Panorama Right-left',
            33 => 'Smart Scene',
            34 => 'High ISO',
        },
    },
    # 0xfa04 - values: 0 (normally), 2 (panorama shots)
    # 0xfa0f - values: 0 (normally), 1 (macro?)
    # 0xfa11 - some sort of FNumber (x 100)
    0xfa19 => {
        Name => 'SerialNumber', # (verified with Z712 - PH)
        Writable => 'string',
    },
    0xfa1d => {
        Name => 'KodakImageWidth',
        Writable => 'int16u',
    },
    0xfa1e => {
        Name => 'KodakImageHeight',
        Writable => 'int16u',
    },
    0xfa20 => {
        Name => 'SensorWidth',
        Writable => 'int16u',
    },
    0xfa21 => {
        Name => 'SensorHeight',
        Writable => 'int16u',
    },
    0xfa23 => {
        Name => 'FNumber',
        Writable => 'int16u',
        Priority => 0,
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0xfa24 => {
        Name => 'ExposureTime',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val / 1e5',
        ValueConvInv => '$val * 1e5',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0xfa2e => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
    0xfa3d => {
        Name => 'OpticalZoom',
        Writable => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val=~s/ ?x//; $val',
    },
    0xfa46 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
    # 0xfa4c - related to focal length (1=wide, 32=full zoom)
    0xfa51 => {
        Name => 'KodakImageWidth',
        Writable => 'int16u',
    },
    0xfa52 => {
        Name => 'KodakImageHeight',
        Writable => 'int16u',
    },
    0xfa54 => {
        Name => 'ThumbnailWidth',
        Writable => 'int16u',
    },
    0xfa55 => {
        Name => 'ThumbnailHeight',
        Writable => 'int16u',
    },
    0xfa57 => {
        Name => 'PreviewImageWidth',
        Writable => 'int16u',
    },
    0xfa58 => {
        Name => 'PreviewImageHeight',
        Writable => 'int16u',
    },
);

# Kodak SubIFD1 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD1 = (
    PROCESS_PROC => \&ProcessKodakIFD,
    WRITE_PROC => \&WriteKodakIFD,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0027 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
    0x0028 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
);

my %sceneModeUsed = (
    0 => 'Program',
    2 => 'Aperture Priority',
    3 => 'Shutter Priority',
    4 => 'Manual',
    5 => 'Portrait',
    6 => 'Sport',
    7 => 'Children',
    8 => 'Museum',
    10 => 'High ISO',
    11 => 'Text',
    12 => 'Macro',
    13 => 'Back Light',
    16 => 'Landscape',
    17 => 'Night Landscape',
    18 => 'Night Portrait',
    19 => 'Snow',
    20 => 'Beach',
    21 => 'Fireworks',
    22 => 'Sunset',
    23 => 'Candlelight',
    28 => 'Panorama',
);

# Kodak SubIFD2 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD2 = (
    PROCESS_PROC => \&ProcessKodakIFD,
    WRITE_PROC => \&WriteKodakIFD,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x6002 => {
        Name => 'SceneModeUsed',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => \%sceneModeUsed,
    },
    0x6006 => {
        Name => 'OpticalZoom',
        Writable => 'int32u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val=~s/ ?x//; $val',
    },
    # 0x6009 - some sort of FNumber (x 100)
    0x6103 => {
        Name => 'MaxAperture',
        Writable => 'int32u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0xf002 => {
        Name => 'SceneModeUsed',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => \%sceneModeUsed,
    },
    0xf006 => {
        Name => 'OpticalZoom',
        Writable => 'int32u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val=~s/ ?x//; $val',
    },
    # 0xf009 - some sort of FNumber (x 100)
    0xf103 => {
        Name => 'FNumber',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0xf104 => {
        Name => 'ExposureTime',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val / 1e6',
        ValueConvInv => '$val * 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0xf105 => {
        Name => 'ISO',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
);

# Kodak SubIFD3 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD3 = (
    PROCESS_PROC => \&ProcessKodakIFD,
    WRITE_PROC => \&WriteKodakIFD,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x1000 => {
        Name => 'OpticalZoom',
        Writable => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val=~s/ ?x//; $val',
    },
    # 0x1002 - related to focal length (1=wide, 32=full zoom)
    # 0x1006 - pictures remaining? (gradually decreases as pictures are taken)
#
# the following unknown Kodak tags in subIFD3 may store an IFD count of 0 or 1 instead
# of the correct value (which changes from model to model).  This bad count is fixed
# with the "FixCount" patch.  Models known to have this problem include:
# M380, M1033, M1093IS, V1073, V1233, V1253, V1273, V1275, V1285, Z612, Z712,
# Z812, Z885, Z915, Z950, Z1012IS, Z1085IS, ZD710
#
    0x2007 => {
        Name => 'Kodak_SubIFD3_0x2007',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x2008 => {
        Name => 'Kodak_SubIFD3_0x2008',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x2009 => {
        Name => 'Kodak_SubIFD3_0x2009',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x200a => {
        Name => 'Kodak_SubIFD3_0x200a',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x200b => {
        Name => 'Kodak_SubIFD3_0x200b',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x3020 => {
        Name => 'Kodak_SubIFD3_0x3020',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x3030 => {
        Name => 'Kodak_SubIFD3_0x3030',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x3040 => {
        Name => 'Kodak_SubIFD3_0x3040',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x3050 => {
        Name => 'Kodak_SubIFD3_0x3050',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x3060 => {
        Name => 'Kodak_SubIFD3_0x3060',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8001 => {
        Name => 'Kodak_SubIFD3_0x8001',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8002 => {
        Name => 'Kodak_SubIFD3_0x8002',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8003 => {
        Name => 'Kodak_SubIFD3_0x8003',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8004 => {
        Name => 'Kodak_SubIFD3_0x8004',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8005 => {
        Name => 'Kodak_SubIFD3_0x8005',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8006 => {
        Name => 'Kodak_SubIFD3_0x8006',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8007 => {
        Name => 'Kodak_SubIFD3_0x8007',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8008 => {
        Name => 'Kodak_SubIFD3_0x8008',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x8009 => {
        Name => 'Kodak_SubIFD3_0x8009',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x800a => {
        Name => 'Kodak_SubIFD3_0x800a',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x800b => {
        Name => 'Kodak_SubIFD3_0x800b',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
    0x800c => {
        Name => 'Kodak_SubIFD3_0x800c',
        Flags => [ 'FixCount', 'Unknown', 'Hidden' ],
    },
);

# Kodak SubIFD4 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD4 = (
    PROCESS_PROC => \&ProcessKodakIFD,
    WRITE_PROC => \&WriteKodakIFD,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# Kodak SubIFD5 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD5 = (
    PROCESS_PROC => \&ProcessKodakIFD,
    WRITE_PROC => \&WriteKodakIFD,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000f => {
        Name => 'OpticalZoom',
        Writable => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val=~s/ ?x//; $val',
    },
);

# Kodak SubIFD6 tags (ref PH)
%Image::ExifTool::Kodak::SubIFD6 = (
    PROCESS_PROC => \&ProcessKodakIFD,
    WRITE_PROC => \&WriteKodakIFD,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'SubIFD6 is written by the M580.',
);

# Decoded from P712, P850 and P880 samples (ref PH)
%Image::ExifTool::Kodak::CameraInfo = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are used by the  P712, P850 and P880.',
    0xf900 => {
        Name => 'SensorWidth',
        Writable => 'int16u',
        Notes => 'effective sensor size',
    },
    0xf901 => {
        Name => 'SensorHeight',
        Writable => 'int16u',
    },
    0xf902 => {
        Name => 'BayerPattern',
        Writable => 'string',
    },
    0xf903 => {
        Name => 'SensorFullWidth',
        Writable => 'int16u',
        Notes => 'includes black border?',
    },
    0xf904 => {
        Name => 'SensorFullHeight',
        Writable => 'int16u',
    },
    0xf907 => {
        Name => 'KodakImageWidth',
        Writable => 'int16u',
    },
    0xf908 => {
        Name => 'KodakImageHeight',
        Writable => 'int16u',
    },
    0xfa00 => {
        Name => 'KodakInfoType',
        Writable => 'string',
    },
    0xfa04 => {
        Name => 'SerialNumber', # (unverified)
        Writable => 'string',
    },
    0xfd04 => {
        Name => 'FNumber',
        Writable => 'int16u',
        Priority => 0,
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
    },
    0xfd05 => {
        Name => 'ExposureTime',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val / 1e6',
        ValueConvInv => '$val * 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0xfd06 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
);

# treat unknown maker notes as binary data (allows viewing with -U)
%Image::ExifTool::Kodak::Unknown = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
);

# tags found in the KodakIFD (in IFD0 of KDC, DCR, TIFF and JPEG images) (ref PH)
%Image::ExifTool::Kodak::IFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'KodakIFD', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITE_GROUP => 'KodakIFD',
    SET_GROUP1 => 1,
    NOTES => q{
        These tags are found in a separate IFD of JPEG, TIFF, DCR and KDC images
        from some older Kodak models such as the DC50, DC120, DCS760C, DCS Pro 14N,
        14nx, SLR/n, Pro Back and Canon EOS D2000.
    },
    # 0x0000: int8u[4]    - values: "1 0 0 0" (DC50), "1 1 0 0" (DC120)
    0x0001 => {
        # (related to EV but exact meaning unknown)
        Name => 'UnknownEV',
        Writable => 'rational64u',
        Unknown => 1,
    },
    # 0x0002: int8u       - values: 0
    0x0003 => {
        Name => 'ExposureValue',
        Writable => 'rational64u',
    },
    # 0x0004: rational64u - values: 2.875,3.375,3.625,4,4.125,7.25
    # 0x0005: int8u       - values: 0
    # 0x0006: int32u[12]  - ?
    # 0x0007: int32u[3]   - values: "65536 67932 69256"
    0x03e9 => { Name => 'OriginalFileName', Writable => 'string' },
    0x03eb => 'SensorLeftBorder',
    0x03ec => 'SensorTopBorder',
    0x03ed => 'SensorImageWidth',
    0x03ee => 'SensorImageHeight',
    0x03f1 => {
        Name => 'TextualInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::TextualInfo',
        },
    },
    # 0x03f2 - FlashMode (ref IB)
    # 0x03f3 - FlashCompensation (ref IB)
    # 0x03f8 - MinAperture (ref IB)
    # 0x03f9 - MaxAperture (ref IB)
    0x03fc => { #3
        Name => 'WhiteBalance',
        Writable => 'int16u',
        Priority => 0,
        PrintConv => { },   # no values yet known
    },
    0x03fd => { #3
        Name => 'Processing',
        Condition => '$count == 72',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Processing',
        },
    },
    0x0401 => {
        Name => 'Time',
        Groups => { 2 => 'Time' },
        Writable => 'string',
    },
    0x0406 => { #IB
        Name => 'CameraTemperature',
        # (when count is 2, values seem related to temperature, but are not Celius)
        Condition => '$count == 1',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    0x0407 => { #IB
        Name => 'AdapterVoltage',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0x0408 => { #IB
        Name => 'BatteryVoltage',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0x0414 => { Name => 'NCDFileInfo',      Writable => 'string' },
    0x0846 => { #3
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0x0848 => 'WB_RGBLevelsDaylight', #IB
    0x0849 => 'WB_RGBLevelsTungsten', #IB
    0x084a => 'WB_RGBLevelsFluorescent', #IB
    0x084b => 'WB_RGBLevelsFlash', #IB
    0x084c => 'WB_RGBLevelsCustom', #IB
    0x084d => 'WB_RGBLevelsAuto', #IB
    0x0852 => 'WB_RGBMul0', #3
    0x0853 => 'WB_RGBMul1', #3
    0x0854 => 'WB_RGBMul2', #3
    0x0855 => 'WB_RGBMul3', #3
    0x085c => { Name => 'WB_RGBCoeffs0', Binary => 1 }, #3
    0x085d => { Name => 'WB_RGBCoeffs1', Binary => 1 }, #3
    0x085e => { Name => 'WB_RGBCoeffs2', Binary => 1 }, #3
    0x085f => { Name => 'WB_RGBCoeffs3', Binary => 1 }, #3
    # 0x089d => true analogue ISO values possible (ref IB)
    # 0x089e => true analogue ISO used at capture (ref IB)
    # 0x089f => ISO calibration gain (ref IB)
    # 0x08a0 => ISO calibration gain table (ref IB)
    # 0x08a1 => exposure headroom coefficient (ref IB)
    0x0903 => { Name => 'BaseISO', Writable => 'rational64u' }, #IB (ISO before digital gain)
    # 0x090d: linear table (ref 3)
    0x09ce => { Name => 'SensorSerialNumber', Writable => 'string', Groups => { 2 => 'Camera' } }, #IB
    # 0x0c81: some sort of date (manufacture date?) - PH
    0x0ce5 => { Name => 'FirmwareVersion',  Writable => 'string', Groups => { 2 => 'Camera' } },
    0x0e4c => { #IB
        Name => 'KodakLook',
        Format => 'undef',
        Writable => 'string',
        ValueConv => '$val=~tr/\0/\n/; $val',
        ValueConvInv => '$val=~tr/\n/\0/; $val',
    },
    0x1389 => { Name => 'InputProfile',     Writable => 'undef', Binary => 1 }, #IB
    0x138a => { Name => 'KodakLookProfile', Writable => 'undef', Binary => 1 }, #IB
    0x138b => { Name => 'OutputProfile',    Writable => 'undef', Binary => 1 }, #IB
    # 0x1390: value: "DCSProSLRn" (tone curve name?) - PH
    0x1391 => { Name => 'ToneCurveFileName',Writable => 'string' },
    0x1784 => { Name => 'ISO',              Writable => 'int32u' }, #3
);

# contains WB adjust set in software (ref 3)
%Image::ExifTool::Kodak::Processing = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    20 => {
        Name => 'WB_RGBLevels',
        Format => 'int16u[3]',
        ValueConv => q{
            my @a = split ' ',$val;
            foreach (@a) {
                $_ = 2048 / $_ if $_;
            }
            return join ' ', @a;
        }
    },
);

# tags found in the Kodak KDC_IFD (in IFD0 of KDC images) (ref 3)
%Image::ExifTool::Kodak::KDC_IFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'KDC_IFD', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITE_GROUP => 'KDC_IFD',
    SET_GROUP1 => 1,
    NOTES => q{
        These tags are found in a separate IFD of KDC images from some newer Kodak
        models such as the P880 and Z1015IS.
    },
    0xfa00 => {
        Name => 'SerialNumber', #PH (unverified)
        Writable => 'string',
    },
    0xfa0d => {
        Name => 'WhiteBalance',
        Writable => 'int8u',
        PrintConv => { #PH
            0 => 'Auto',
            1 => 'Fluorescent', # (NC)
            2 => 'Tungsten', # (NC)
            3 => 'Daylight', # (NC)
            6 => 'Shade', # (NC, called "Open Shade" by Kodak)
        },
    },
    # the following tags are numbered for use in the Composite tag lookup
    0xfa25 => 'WB_RGBLevelsAuto',
    0xfa27 => 'WB_RGBLevelsTungsten', # (NC)
    0xfa28 => 'WB_RGBLevelsFluorescent', # (NC)
    0xfa29 => 'WB_RGBLevelsDaylight', # (NC)
    0xfa2a => 'WB_RGBLevelsShade', # (NC)
);

# textual-based Kodak TextualInfo tags (not found in KDC images) (ref PH)
%Image::ExifTool::Kodak::TextualInfo = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Kodak', 2 => 'Image'},
    PROCESS_PROC => \&ProcessKodakText,
    NOTES => q{
        Below is a list of tags which have been observed in the Kodak TextualInfo
        data, however ExifTool will extract information from any tags found here.
    },
    'Actual Compensation' => 'ActualCompensation',
    'AF Function'   => 'AFMode', # values: "S" (=Single?, then maybe C for Continuous, M for Manual?) - PH
    'Aperture'      => {
        Name => 'Aperture',
        ValueConv => '$val=~s/^f//i; $val',
    },
    'Auto Bracket'  => 'AutoBracket',
    'Brightness Value' => 'BrightnessValue',
    'Camera'        => 'CameraModel',
    'Camera body'   => 'CameraBody',
    'Compensation'  => 'ExposureCompensation',
    'Date'          => {
        Name => 'Date',
        Groups => { 2 => 'Time' },
    },
    'Exposure Bias' => 'ExposureBias',
    'Exposure Mode' => {
        Name => 'ExposureMode',
        PrintConv => {
            OTHER => sub { shift }, # pass other values straight through
            'M' => 'Manual',
            'A' => 'Aperture Priority', #(NC -- I suppose this could be "Auto" too)
            'S' => 'Shutter Priority', #(NC)
            'P' => 'Program', #(NC)
            'B' => 'Bulb', #(NC)
            # have seen "Manual (M)" written by DCS760C - PH
            # and "Aperture priority AE (Av)" written by a ProBack 645M
        },
    },
    'Firmware Version' => 'FirmwareVersion',
    'Flash Compensation' => 'FlashExposureComp',
    'Flash Fired'   => 'FlashFired',
    'Flash Sync Mode' => 'FlashSyncMode',
    'Focal Length'  => {
        Name => 'FocalLength',
        PrintConv => '"$val mm"',
    },
    'Height'        => 'KodakImageHeight',
    'Image Number'  => 'ImageNumber',
    'ISO'           => 'ISO',
    'ISO Speed'     => 'ISO',
    'Max Aperture'  => {
        Name => 'MaxAperture',
        ValueConv => '$val=~s/^f//i; $val',
    },
    'Meter Mode'    => 'MeterMode',
    'Min Aperture'  => {
        Name => 'MinAperture',
        ValueConv => '$val=~s/^f//i; $val',
    },
    'Popup Flash'   => 'PopupFlash',
    'Serial Number' => 'SerialNumber',
    'Shooting Mode' => 'ShootingMode',
    'Shutter'       => 'ShutterSpeed',
    'Temperature'   => 'Temperature', # with a value of 15653, what could this be? - PH
    'Time'          => {
        Name => 'Time',
        Groups => { 2 => 'Time' },
    },
    'White balance' => 'WhiteBalance',
    'Width'         => 'KodakImageWidth',
    '_other_info'   => {
        Name => 'OtherInfo',
        Notes => 'any other information without a tag name',
    },
);

# Kodak APP3 "Meta" tags (ref 2)
%Image::ExifTool::Kodak::Meta = (
    GROUPS => { 0 => 'Meta', 1 => 'MetaIFD', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITE_GROUP => 'MetaIFD',   # default write group
    NOTES => q{
        These tags are found in the APP3 "Meta" segment of JPEG images from Kodak
        cameras such as the DC280, DC3400, DC5000, MC3, M580, Z950 and Z981.  The
        structure of this segment is similar to the APP1 "Exif" segment, but a
        different set of tags is used.
    },
    0xc350 => 'FilmProductCode',
    0xc351 => 'ImageSourceEK',
    0xc352 => 'CaptureConditionsPAR',
    0xc353 => {
        Name => 'CameraOwner',
        Writable => 'undef',
        RawConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,$tag)',
        RawConvInv => 'Image::ExifTool::Exif::EncodeExifText($self,$val)',
    },
    0xc354 => {
        Name => 'SerialNumber',
        Writable => 'undef',
        Groups => { 2 => 'Camera' },
        RawConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,$tag)', #PH
        RawConvInv => 'Image::ExifTool::Exif::EncodeExifText($self,$val)',
    },
    0xc355 => 'UserSelectGroupTitle',
    0xc356 => 'DealerIDNumber',
    0xc357 => 'CaptureDeviceFID',
    0xc358 => 'EnvelopeNumber',
    0xc359 => 'FrameNumber',
    0xc35a => 'FilmCategory',
    0xc35b => 'FilmGencode',
    0xc35c => 'ModelAndVersion',
    0xc35d => 'FilmSize',
    0xc35e => 'SBA_RGBShifts',
    0xc35f => 'SBAInputImageColorspace',
    0xc360 => 'SBAInputImageBitDepth',
    0xc361 => {
        Name => 'SBAExposureRecord',
        Binary => 1,
    },
    0xc362 => {
        Name => 'UserAdjSBA_RGBShifts',
        Binary => 1,
    },
    0xc363 => 'ImageRotationStatus',
    0xc364 => 'RollGuidElements',
    0xc365 => 'MetadataNumber',
    0xc366 => 'EditTagArray',
    0xc367 => 'Magnification',
    # 0xc36b - string[8]: "1.0"
    0xc36c => 'NativeXResolution',
    0xc36d => 'NativeYResolution',
    0xc36e => {
        Name => 'KodakEffectsIFD',
        Flags => 'SubIFD',
        Groups => { 1 => 'KodakEffectsIFD' },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::SpecialEffects',
            Start => '$val',
        },
    },
    0xc36f => {
        Name => 'KodakBordersIFD',
        Flags => 'SubIFD',
        Groups => { 1 => 'KodakBordersIFD' },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Borders',
            Start => '$val',
        },
    },
    0xc37a => 'NativeResolutionUnit',
    0xc418 => 'SourceImageDirectory',
    0xc419 => 'SourceImageFileName',
    0xc41a => 'SourceImageVolumeName',
    0xc46c => 'PrintQuality',
    0xc46e => 'ImagePrintStatus',
    # 0cx46f - int16u: 1
);

# Kodak APP3 "Meta" Special Effects sub-IFD (ref 2)
%Image::ExifTool::Kodak::SpecialEffects = (
    GROUPS => { 0 => 'Meta', 1 => 'KodakEffectsIFD', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    0 => 'DigitalEffectsVersion',
    1 => {
        Name => 'DigitalEffectsName',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,"DigitalEffectsName")',
    },
    2 => 'DigitalEffectsType',
);

# Kodak APP3 "Meta" Borders sub-IFD (ref 2)
%Image::ExifTool::Kodak::Borders = (
    GROUPS => { 0 => 'Meta', 1 => 'KodakBordersIFD', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    0 => 'BordersVersion',
    1 => {
        Name => 'BorderName',
        PrintConv => 'Image::ExifTool::Exif::ConvertExifText($self,$val,"BorderName")',
    },
    2 => 'BorderID',
    3 => 'BorderLocation',
    4 => 'BorderType',
    8 => 'WatermarkType',
);

# tags in Kodak MOV videos (ref PH)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Kodak::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in the TAGS atom of MOV videos from Kodak models
        such as the P880.
    },
    0 => {
        Name => 'Make',
        Format => 'string[21]',
    },
    0x16 => {
        Name => 'Model',
        Format => 'string[42]',
    },
    0x40 => {
        Name => 'ModelType',
        Format => 'string[8]',
    },
    # (01 00 at offset 0x48)
    0x4e => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x52 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x5a => {
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    # 0x6c => 'WhiteBalance', ?
    0x70 => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
);

# Kodak DcMD atoms (ref PH)
%Image::ExifTool::Kodak::DcMD = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => 'Metadata directory found in MOV and MP4 videos from some Kodak cameras.',
    Cmbo => {
        Name => 'CameraByteOrder',
        PrintConv => {
            II => 'Little-endian (Intel, II)',
            MM => 'Big-endian (Motorola, MM)',
        },
    },
    CMbo => { # (as written by Kodak Playsport video camera)
        Name => 'CameraByteOrder',
        PrintConv => {
            II => 'Little-endian (Intel, II)',
            MM => 'Big-endian (Motorola, MM)',
        },
    },
    DcME => {
        Name => 'DcME',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::DcME',
        },
    },
    DcEM => {
        Name => 'DcEM',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::DcEM',
        },
    },
);

# Kodak DcME atoms (ref PH)
%Image::ExifTool::Kodak::DcME = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    # Mtmd - 24 bytes: ("00 00 00 00 00 00 00 01" x 3)
    # Keyw - keywords? (six bytes all zero)
    # Rate -  2 bytes: 00 00
);

# Kodak DcEM atoms (ref PH)
%Image::ExifTool::Kodak::DcEM = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    # Mtmd - 24 bytes: ("00 00 00 00 00 00 00 01" x 3)
    # Csat - 16 bytes: 00 06 00 00 62 00 61 00 73 00 69 00 63 00 00 00 [....b.a.s.i.c...]
    # Ksre -  8 bytes: 00 01 00 00 00 00
);

# tags in "free" atom of Kodak M5370 MP4 videos (ref PH)
%Image::ExifTool::Kodak::Free = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => q{
        Information stored in the "free" atom of Kodak MP4 videos. (VERY bad form
        for Kodak to store useful information in an atom intended for unused space!)
    },
    # (2012/01/19: Kodak files for bankruptcy -- this is poetic metadata justice)
    Seri => {
        Name => 'SerialNumber',
        # byte 0 is string length;  byte 1 is zero;  string starts at byte 2
        ValueConv => 'substr($val, 2, unpack("C",$val))',
    },
    SVer => {
        Name => 'FirmwareVersion',
        ValueConv => 'substr($val, 2, unpack("C",$val))',
    },
    # Clor - 2 bytes: 0 1  (?)
    # CapM - 2 bytes: 0 1  (capture mode? = exposure mode?)
    # WBMD - 2 bytes: 0 0  (white balance?)
    Expc => { # (NC)
        Name => 'ExposureCompensation',
        Format => 'int16s',
        ValueConv => '$val / 3', # (guess)
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    # Zone - 2 bytes: 0 2  (time zone? focus zone?)
    # FoMD - 2 bytes: 0 0  (focus mode?)
    # Shap - 2 bytes: 0 2  (sharpness?)
    Expo => {
        Name => 'ExposureTime',
        Format => 'rational32u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    FNum => {
        Name => 'FNumber',
        Format => 'int16u',
        ValueConv => '$val / 100',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    ISOS => { Name => 'ISO', Format => 'int16u' },
    StSV => {
        Name => 'ShutterSpeedValue',
        Format => 'int16s',
        ValueConv => 'abs($val)<100 ? 2**(-$val/3) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    AprV => {
        Name => 'ApertureValue',
        Format => 'int16s',
        ValueConv => '2 ** ($val / 2000)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    BrtV => { # (NC)
        Name => 'BrightnessValue',
        Format => 'int32s',
        ValueConv => '$val / 1000', # (guess)
    },
    FoLn => {
        Name => 'FocalLength',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    FL35 => {
        Name => 'FocalLengthIn35mmFormat',
        Groups => { 2 => 'Camera' },
        Format => 'int16u',
        PrintConv => '"$val mm"',
    },
    Scrn => {
        Name => 'PreviewInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Kodak::Scrn' },
    },
);

# tags in "frea" atom of Kodak PixPro SP360 MP4 videos (ref PH)
%Image::ExifTool::Kodak::frea = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Information stored in the "frea" atom of Kodak PixPro SP360 MP4 videos.',
    # tima - 4 bytes: "0 0 0 0x20" or "0 0 0 0x0a"
    thma => { Name => 'ThumbnailImage', Groups => { 2 => 'Preview' }, Binary => 1 },
    scra => { Name => 'PreviewImage',   Groups => { 2 => 'Preview' }, Binary => 1 },
);

# preview information in free/Scrn atom of MP4 videos (ref PH)
%Image::ExifTool::Kodak::Scrn = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16u',
    0 => 'PreviewImageWidth',
    1 => 'PreviewImageHeight',
    2 => { Name => 'PreviewImageLength', Format => 'int32u' },
    4 => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{2}]',
        RawConv => '$self->ValidateImage(\$val, $tag)',
    },
);

# acceleration information extracted from 'pose' atom of MP4 videos (ref PH, PixPro 4KVR360)
%Image::ExifTool::Kodak::pose = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    PROCESS_PROC => \&ProcessPose,
    NOTES => q{
        Streamed orientation information from the PixPro 4KVR360, extracted as
        sub-documents when the Duplicates option is used.
    },
    Accelerometer => { }, # up, back, left?  units of g
    AngularVelocity => { } # left, up, ccw?  units?
);

# Kodak composite tags
%Image::ExifTool::Kodak::Composite = (
    GROUPS => { 2 => 'Camera' },
    DateCreated => {
        Groups => { 2 => 'Time' },
        Require => {
            0 => 'Kodak:YearCreated',
            1 => 'Kodak:MonthDayCreated',
        },
        ValueConv => '"$val[0]:$val[1]"',
    },
    WB_RGBLevels => {
        Require => {
            0 => 'KDC_IFD:WhiteBalance',
        },
        # indices of the following entries are KDC_IFD:WhiteBalance + 1
        Desire => {
            1 => 'WB_RGBLevelsAuto',
            2 => 'WB_RGBLevelsFluorescent',
            3 => 'WB_RGBLevelsTungsten',
            4 => 'WB_RGBLevelsDaylight',
            5 => 'WB_RGBLevels4',
            6 => 'WB_RGBLevels5',
            7 => 'WB_RGBLevelsShade',
        },
        ValueConv => '$val[$val[0] + 1]',
    },
    WB_RGBLevels2 => {
        Name => 'WB_RGBLevels',
        Require => {
            0 => 'KodakIFD:WhiteBalance',
            1 => 'WB_RGBMul0',
            2 => 'WB_RGBMul1',
            3 => 'WB_RGBMul2',
            4 => 'WB_RGBMul3',
            5 => 'WB_RGBCoeffs0',
            6 => 'WB_RGBCoeffs1',
            7 => 'WB_RGBCoeffs2',
            8 => 'WB_RGBCoeffs3',
        },
        # indices of the following entries are KDC_IFD:WhiteBalance + 1
        Desire => {
            9 => 'KodakIFD:ColorTemperature',
            10 => 'Kodak:WB_RGBLevels',
        },
        ValueConv => 'Image::ExifTool::Kodak::CalculateRGBLevels(@val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Kodak');

#------------------------------------------------------------------------------
# Process Kodak accelerometer data (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessPose($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my $ee = $et->Options('ExtractEmbedded');
    my ($i, $pos);

    return 0 if $dirLen < 0x14;
    my $num = Get32u($dataPt, 0x10);
    return 0 if $dirLen < 0x14 + $num * 24;

    $et->VerboseDir('Kodak pose', undef, $dirLen);

    $$et{DOC_NUM} = 0;
    for ($i=0, $pos=0x14; $i<$num; ++$i, $pos+=24) {
        $et->HandleTag($tagTablePtr, AngularVelocity =>
            Image::ExifTool::GetRational64s($dataPt, $pos) . ' ' .
            Image::ExifTool::GetRational64s($dataPt, $pos + 8) . ' ' .
            Image::ExifTool::GetRational64s($dataPt, $pos + 16));
        $ee or $pos += $num * 24, last;
        ++$$et{DOC_NUM};
    }
    $$et{DOC_NUM} = 0;

    return 1 if $dirLen < $pos + 0x10;
    $num = Get32u($dataPt, $pos + 0x0c);
    return 1 if $dirLen < $pos + 0x10 + $num * 24;

    for ($i=0, $pos+=0x10; $i<$num; ++$i, $pos+=24) {
        $et->HandleTag($tagTablePtr, Accelerometer =>
            Image::ExifTool::GetRational64s($dataPt, $pos) . ' ' .
            Image::ExifTool::GetRational64s($dataPt, $pos + 8) . ' ' .
            Image::ExifTool::GetRational64s($dataPt, $pos + 16));
        $ee or $pos += $num * 24, last;
        ++$$et{DOC_NUM};
    }
    $$et{DOC_NUM} = 0;
    $ee or $et->Warn('Use the ExtractEmbedded option to extract all accelerometer data',3);
    return 1;
}

#------------------------------------------------------------------------------
# Calculate RGB levels from associated tags (ref 3)
# Inputs: 0) KodakIFD:WhiteBalance, 1-4) WB_RGBMul0-3, 5-8) WB_RGBCoeffs0-3
#         9) (optional) KodakIFD:ColorTemperature, 10) (optional) Kodak:WB_RGBLevels
# Returns: WB_RGBLevels or undef
sub CalculateRGBLevels(@)
{
    return undef if $_[10]; # use existing software levels if they exist
    my $wbi = $_[0];
    return undef if $wbi < 0 or $wbi > 3;
    my @mul = split ' ', $_[$wbi + 1], 13; # (only use the first 12 coeffs)
    my @coefs = split ' ', ${$_[$wbi + 5]}; # (extra de-reference for Binary data)
    my $wbtemp100 = ($_[9] || 6500) / 100;
    return undef unless @mul >= 3 and @coefs >= 12;
    my ($i, $c, $n, $num, @cam_mul);
    for ($c=$n=0; $c<3; ++$c) {
        for ($num=$i=0; $i<4; ++$i) {
            $num += $coefs[$n++] * ($wbtemp100 ** $i);
        }
        $cam_mul[$c] = 2048 / ($num * $mul[$c]);
    }
    return join(' ', @cam_mul);
}

#------------------------------------------------------------------------------
# Process Kodak textual TextualInfo
# Inputs: 0) ExifTool object ref, 1) dirInfo hash ref, 2) tag table ref
# Returns: 1 on success
sub ProcessKodakText($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $dirStart;
    my $data = substr($$dataPt, $dirStart, $dirLen);
    $data =~ s/\0.*//s;     # truncate at null if it exists
    my @lines = split /[\n\r]+/, $data;
    my ($line, $success, @other, $tagInfo);
    $et->VerboseDir('Kodak Text');
    foreach $line (@lines) {
        if ($line =~ /(.*?):\s*(.*)/) {
            my ($tag, $val) = ($1, $2);
            if ($$tagTablePtr{$tag}) {
                $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            } else {
                my $tagName = $tag;
                $tagName =~ s/([A-Z])\s+([A-Za-z])/${1}_\U$2/g;
                $tagName =~ s/([a-z])\s+([A-Za-z0-9])/${1}\U$2/g;
                $tagName =~ s/\s+//g;
                $tagName =~ s/[^-\w]+//g;   # delete remaining invalid characters
                $tagName = 'NoName' unless $tagName;
                $tagInfo = { Name => $tagName };
                AddTagToTable($tagTablePtr, $tag, $tagInfo);
            }
            $et->HandleTag($tagTablePtr, $tag, $val, TagInfo => $tagInfo);
            $success = 1;
        } else {
            # strip off leading/trailing white space and ignore blank lines
            push @other, $1 if $line =~ /^\s*(\S.*?)\s*$/;
        }
    }
    if ($success) {
        if (@other) {
            $tagInfo = $et->GetTagInfo($tagTablePtr, '_other_info');
            $et->FoundTag($tagInfo, \@other);
        }
    } else {
        $et->Warn("Can't parse Kodak TextualInfo data", 1);
    }
    return $success;
}

#------------------------------------------------------------------------------
# Process Kodak IFD (with leading byte order mark)
# Inputs: 0) ExifTool object ref, 1) dirInfo hash ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessKodakIFD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dirStart = $$dirInfo{DirStart} || 0;
    return 1 if $dirStart <= 0 or $dirStart + 2 > $$dirInfo{DataLen};
    my $byteOrder = substr(${$$dirInfo{DataPt}}, $dirStart, 2);
    unless (Image::ExifTool::SetByteOrder($byteOrder)) {
        $et->Warn("Invalid Kodak $$dirInfo{Name} directory");
        return 1;
    }
    $$dirInfo{DirStart} += 2;   # skip byte order mark
    $$dirInfo{DirLen} -= 2;
    if ($$et{HTML_DUMP}) {
        my $base = $$dirInfo{Base} + $$dirInfo{DataPos};
        $et->HDump($dirStart+$base, 2, "Byte Order Mark");
    }
    return Image::ExifTool::Exif::ProcessExif($et, $dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Write Kodak IFD (with leading byte order mark)
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: Exif data block (may be empty if no Exif data) or undef on error
sub WriteKodakIFD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dirStart = $$dirInfo{DirStart} || 0;
    return '' if $dirStart <= 0 or $dirStart + 2 > $$dirInfo{DataLen};
    my $byteOrder = substr(${$$dirInfo{DataPt}}, $dirStart, 2);
    return '' unless Image::ExifTool::SetByteOrder($byteOrder);
    $$dirInfo{DirStart} += 2;   # skip byte order mark
    $$dirInfo{DirLen} -= 2;
    my $buff = Image::ExifTool::Exif::WriteExif($et, $dirInfo, $tagTablePtr);
    return $buff unless defined $buff and length $buff;
    # apply one-time fixup for length of byte order mark
    if ($$dirInfo{Fixup}) {
        $dirInfo->{Fixup}->{Shift} += 2;
        $$dirInfo{Fixup}->ApplyFixup(\$buff);
        delete $$dirInfo{Fixup};
    }
    return Image::ExifTool::GetByteOrder() . $buff;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Kodak - Kodak EXIF maker notes and APP3 "Meta" tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Kodak maker notes EXIF meta information.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<Image::MetaData::JPEG|Image::MetaData::JPEG>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/meta.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item (...plus lots of testing with my daughter's CX4200!)

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Kodak Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
