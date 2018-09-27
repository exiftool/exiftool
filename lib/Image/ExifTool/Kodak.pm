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
#               4) Jim McGarvey private communication
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

$VERSION = '1.44';

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
    0x0000 => { #4
        Name => 'KodakVersion',
        Writable => 'int8u',
        Count => 4,
        PrintConv => '$val =~ tr/ /./; $val',
        PrintConvInv => '$val =~ tr/./ /; $val',
    },
    0x0001 => {
        # (related to EV but exact meaning unknown)
        Name => 'UnknownEV', # ("DeletedTag", ref 4)
        Writable => 'rational64u',
        Unknown => 1,
    },
    # 0x0002: int8u       - values: 0
    0x0003 => { Name => 'ExposureValue',    Writable => 'rational64u' },
    # 0x0004: rational64u - values: 2.875,3.375,3.625,4,4.125,7.25
    # 0x0005: int8u       - values: 0
    # 0x0006: int32u[12]  - ?
    # 0x0007: int32u[3]   - values: "65536 67932 69256"
    0x03e9 => { Name => 'OriginalFileName', Writable => 'string' },
    0x03ea => { Name => 'KodakTag',         Writable => 'int32u' }, #4
    0x03eb => { Name => 'SensorLeftBorder', Writable => 'int16u' }, # ("FinishedImageX", ref 4)
    0x03ec => { Name => 'SensorTopBorder',  Writable => 'int16u' }, # ("FinishedImageY", ref 4)
    0x03ed => { Name => 'SensorImageWidth', Writable => 'int16u' }, # ("FinishedImageWidth", ref 4)
    0x03ee => { Name => 'SensorImageHeight',Writable => 'int16u' }, # ("FinishedImageHeight", ref 4)
    0x03ef => { Name => 'BlackLevelTop',    Writable => 'int16u' }, #4
    0x03f0 => { Name => 'BlackLevelBottom', Writable => 'int16u' }, #4
    0x03f1 => {
        Name => 'TextualInfo', # ("CameraSettingString", ref 4)
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::TextualInfo',
        },
    },
    0x03f2 => { #IB/4
        Name => 'FlashMode',
        Writable => 'int16u',
        Unknown => 1,
        Priority => 0,
    },
    0x03f3 => { #IB/4
        Name => 'FlashCompensation',
        Writable => 'rational64s',
    },
    0x03f4 => { #4
        Name => 'WindMode',
        Writable => 'int16u',
        Unknown => 1,
    },
    0x03f5 => { #4
        Name => 'FocusMode',
        Writable => 'int16u',
        Unknown => 1,
        Priority => 0,
    },
    0x03f8 => { #IB/4
        Name => 'MinAperture',
        Writable => 'rational64u',
    },
    0x03f9 => { #IB/4
        Name => 'MaxAperture',
        Writable => 'rational64u',
    },
    0x03fa => { #4
        Name => 'WhiteBalanceMode',
        Writable => 'int16u',
        Unknown => 1,
    },
    0x03fb => { #4
        Name => 'WhiteBalanceDetected',
        Writable => 'int16u',
        Unknown => 1,
    },
    0x03fc => { #3
        Name => 'WhiteBalance',
        Writable => 'int16u',
        Priority => 0,
        PrintConv => { },   # no values yet known
    },
    0x03fd => [{ #3
        Name => 'Processing',
        Condition => '$count == 72',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Kodak::Processing',
        },
    },{
        Name => 'ProcessingParameters', #4
        Binary => 1,
        # int8u[256]
    }],
    0x03fe => { Name => 'ImageAbsoluteX',       Writable => 'int16s', }, #4
    0x03ff => { Name => 'ImageAbsoluteY',       Writable => 'int16s' }, #4
    0x0400 => { Name => 'ApplicationKeyString', Writable => 'string' }, #4
    0x0401 => {
        Name => 'Time', # ("CaptureTime", ref 4)
        Groups => { 2 => 'Time' },
        Writable => 'string',
    },
    0x0402 => { #4
        Name => 'GPSString',
        Groups => { 2 => 'Location' },
        Writable => 'string',
    },
    0x0403 => { #4
        Name => 'EventLogCapture',
        Binary => 1,
        Unknown => 1,
        # int32u[3072]
    },
    0x0404 => { #4
        Name => 'ComponentTable',
        Binary => 1,
        Unknown => 1,
    },
    0x0405 => { #4
        Name => 'CustomIlluminant',
        Writable => 'int16u',
        Unknown => 1,
    },
    0x0406 => [{ #IB/4
        Name => 'CameraTemperature',
        Condition => '$count == 1',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },{
        Name => 'CameraTemperature',
        # (when count is 2, values seem related to temperature, but are not Celius)
    }],
    0x0407 => { #IB/4
        Name => 'AdapterVoltage',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0x0408 => { #IB/4
        Name => 'BatteryVoltage',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64u',
    },
    0x0409 => { #4
        Name => 'DacVoltages',
        # rational64u[8]
    },
    0x040a => { #4
        Name => 'IlluminantDetectorData',
        Binary => 1,
        Unknown => 1,
    },
    0x040b => { #4
        Name => 'PixelClockFrequency',
        Writable => 'int32u',
    },
    0x040c => { #4
        Name => 'CenterPixel',
        Writable => 'int16u',
        Count => 3,
    },
    0x040d => { #4
        Name => 'BurstCount',
        Writable => 'int16u',
    },
    0x040e => { #4
        Name => 'BlackLevelRough',
        Writable => 'int16u',
    },
    0x040f => { #4
        Name => 'OffsetMapHorizontal',
        Binary => 1,
        Unknown => 1,
        # int16s[1736]
    },
    0x0410 => { #4
        Name => 'OffsetMapVertical',
        Binary => 1,
        Unknown => 1,
        # int16s[1160]
    },
    0x0411 => { #4
        Name => 'Histogram',
        Binary => 1,
        Unknown => 1,
        # int16u[256]
    },
    0x0412 => { #4
        Name => 'VerticalClockOverlaps',
        Writable => 'int16u',
        Count => 2,
    },
    0x0413 => 'SensorTemperature', #4
    0x0414 => { Name => 'XilinxVersion',        Writable => 'string' }, #4
    0x0415 => { Name => 'FirmwareVersion',      Writable => 'int32u' }, #4
    0x0416 => { Name => 'BlackLevelRoughAfter', Writable => 'int16u' }, #4
    0x0417 => 'BrightRowsTop', #4
    0x0418 => 'EventLogProcess', #4
    0x0419 => 'DacVoltagesFlush', #4
    0x041a => 'FlashUsed', #4
    0x041b => 'FlashType', #4
    0x041c => 'SelfTimer', #4
    0x041d => 'AFMode', #4
    0x041e => 'LensType', #4
    0x041f => { Name => 'ImageCropX',           Writable => 'int16s' }, #4
    0x0420 => { Name => 'ImageCropY',           Writable => 'int16s' }, #4
    0x0421 => 'AdjustedTbnImageWidth', #4
    0x0422 => 'AdjustedTbnImageHeight', #4
    0x0423 => { Name => 'IntegrationTime',      Writable => 'int32u' }, #4
    0x0424 => 'BracketingMode', #4
    0x0425 => 'BracketingStep', #4
    0x0426 => 'BracketingCounter', #4
    0x042e => 'HuffmanTableLength', #4 (int8u[16])
    0x042f => 'HuffmanTableValue', #4 (int8u[13])
    0x0438 => { Name => 'MainBoardVersion',     Writable => 'int32u' }, #4
    0x0439 => { Name => 'ImagerBoardVersion',   Writable => 'int32u' }, #4
    0x044c => 'FocusEdgeMap', #4
    0x05e6 => 'IdleTiming', #4
    0x05e7 => 'FlushTiming', #4
    0x05e8 => 'IntegrateTiming', #4
    0x05e9 => 'RegisterReadTiming', #4
    0x05ea => 'FirstLineTransferTiming', #4
    0x05eb => 'ShiftTiming', #4
    0x05ec => 'NormalLineTransferTiming', #4
    0x05ed => 'TestTransferTiming', #4
    # 0x05f0-0x05f9 "TestTiming", ref 4
    0x05fa => 'MinimumFlushRows', #4
    0x05fd => { Name => 'ImagerPowerOnDelayMsec', Writable => 'int32u' }, #4
    0x05fe => 'ImagerInitialTimingCode', #4
    0x05ff => 'ImagerLogicProgram', #4
    0x0600 => { Name => 'ImagerBiasSettlingDelayMsec', Writable => 'int32u' }, #4
    0x0604 => 'IdleSequence', #4
    0x0605 => 'FirstFlushSequence', #4
    0x0606 => 'FinalFlushSequence', #4
    0x0607 => 'SampleBlackSequence', #4
    0x0608 => 'TransferSequence', #4
    0x060e => 'DacCountsPerVolt', #4
    0x060f => 'BlackDacChannel', #4
    0x0610 => 'BlackAdCountsPerDacVolt', #4
    0x0611 => 'BlackTarget', #4
    0x0612 => 'BlackDacSettlingMsec', #4
    # 0x0618-0x062b - reserved for .IF file use, ref 4
    0x07d0 => { #4
        Name => 'StandardMatrixDaylight',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07d1 => { #4
        Name => 'StandardMatrixTungsten',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07d2 => { #4
        Name => 'StandardMatrixFluorescent',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07d3 => { #4
        Name => 'StandardMatrixFlash',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07d4 => { #4 (never used)
        Name => 'StandardMatrixCustom',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07da => { #4
        Name => 'DeviantMatrixDaylight',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07db => { #4
        Name => 'DeviantMatrixTungsten',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07dc => { #4
        Name => 'DeviantMatrixFluorescent',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07dd => { #4
        Name => 'DeviantMatrixFlash',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07de => { #4 (never used)
        Name => 'DeviantMatrixCustom',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07e4 => { #4
        Name => 'UniqueMatrixDaylight',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07e5 => { #4
        Name => 'UniqueMatrixTungsten',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07e6 => { #4
        Name => 'UniqueMatrixFluorescent',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07e7 => { #4
        Name => 'UniqueMatrixFlash',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07e8 => { #4
        Name => 'UniqueMatrixCustom',
        Writable => 'rational64s',
        Count => 9,
    },
    0x07e9 => { #4
        Name => 'UniqueMatrixAuto',
        Writable => 'rational64s',
        Count => 9,
    },
    0x0834 => { #4
        Name => 'StandardWhiteDaylight',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0835 => { #4
        Name => 'StandardWhiteTungsten',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0836 => { #4
        Name => 'StandardWhiteFluorescent',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0837 => { #4
        Name => 'StandardWhiteFlash',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0838 => { #4 (never used)
        Name => 'StandardWhiteCustom',
        Writable => 'rational64s',
        Count => 3,
    },
    0x083e => { #4
        Name => 'DeviantWhiteDaylight',
        Writable => 'rational64s',
        Count => 3,
    },
    0x083f => { #4
        Name => 'DeviantWhiteTungsten',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0840 => { #4
        Name => 'DeviantWhiteFluorescent',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0841 => { #4
        Name => 'DeviantWhiteFlash',
        Writable => 'rational64s',
        Count => 3,
    },
    0x0842 => { #4 (never used)
        Name => 'DeviantWhiteCustom',
        Writable => 'rational64s',
        Count => 3,
    },
    # 0x0843 - rational64u[3]
    # 0x0844 - rational64u[3]
    0x0846 => { #3 ("WhiteBalanceKelvin", ref 4)
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0x0847 => 'WB_RGBLevelsAsShot', #4
    0x0848 => 'WB_RGBLevelsDaylight', #IB (rational64s/u[3]) ("UniqueWhiteDaylight", ref 4)
    0x0849 => 'WB_RGBLevelsTungsten', #IB (rational64s/u[3]) ("UniqueWhiteTungsten", ref 4)
    0x084a => 'WB_RGBLevelsFluorescent', #IB (rational64s/u[3]) ("UniqueWhiteFluorescent", ref 4)
    0x084b => 'WB_RGBLevelsFlash', #IB (rational64s/u[3]) ("UniqueWhiteFlash", ref 4)
    0x084c => 'WB_RGBLevelsCustom', #IB (rational64u[3]) ("UniqueWhiteCustom", ref 4)
    0x084d => 'WB_RGBLevelsAuto', #IB (rational64u[3]) ("UniqueWhiteAuto", ref 4)
    0x0852 => { #3/4
        Name => 'WB_RGBMulDaylight', # ("AdjustWhiteFactorsDaylight", ref 4)
        Writable => 'rational64u',
        Count => 3,
    },
    0x0853 => { #3/4
        Name => 'WB_RGBMulTungsten', # ("AdjustWhiteFactorsTungsten", ref 4)
        Writable => 'rational64u',
        Count => 3,
    },
    0x0854 => { #3/4
        Name => 'WB_RGBMulFluorescent', # ("AdjustWhiteFactorsFluorescent", ref 4)
        Writable => 'rational64u',
        Count => 3,
    },
    0x0855 => { #3/4
        Name => 'WB_RGBMulFlash', # ("AdjustWhiteFactorsFlash", ref 4)
        Writable => 'rational64u',
        Count => 3,
    },
    0x085c => { Name => 'WB_RGBCoeffsDaylight', Binary => 1 }, #3 ("WhiteBalanceParametersDaylight", ref 4)
    0x085d => { Name => 'WB_RGBCoeffsTungsten', Binary => 1 }, #3 ("WhiteBalanceParametersTungsten", ref 4)
    0x085e => { Name => 'WB_RGBCoeffsFluorescent',Binary=>1 }, #3 ("WhiteBalanceParametersFluorescent", ref 4)
    0x085f => { Name => 'WB_RGBCoeffsFlash',    Binary => 1 }, #3 ("WhiteBalanceParametersFlash", ref 4)
    0x0898 => { Name => 'ExposureGainDaylight', Writable => 'rational64s' }, #4
    0x0899 => { Name => 'ExposureGainTungsten', Writable => 'rational64s' }, #4
    0x089a => { Name => 'ExposureGainFluorescent',Writable=>'rational64s' }, #4
    0x089b => { Name => 'ExposureGainFlash',    Writable => 'rational64s' }, #4
    0x089c => { Name => 'ExposureGainCustom',   Writable => 'rational64s' }, #4 (never used)
    0x089d => { Name => 'AnalogISOTable',       Writable => 'rational64u', Count => 3 }, #4
    0x089e => { Name => 'AnalogCaptureISO',     Writable => 'int32u' }, #4
    0x089f => { Name => 'ISOCalibrationGain',   Writable => 'rational64u' }, #4
    0x08a0 => 'ISOCalibrationGainTable', #4
    0x08a1 => 'ExposureHeadroomFactor', #4
    0x08ab => 'LinearitySplineTags', #4 (int16u[24])
    # 0x08ac-0x08fb - LinearitySpline(n) (rational64s[75])
    0x08fc => { #4
        Name => 'MonitorMatrix',
        Writable => 'rational64s',
        Count => 9,
    },
    0x08fd => 'TonScaleTable', #4
    0x08fe => { Name => 'Gamma',                Writable => 'rational64u' }, #4
    0x08ff => 'LogLinTable', #4
    0x0900 => 'LinLogTable', #4
    0x0901 => { Name => 'GammaTable',           Binary => 1 }, #4 (int16u[4096])
    0x0902 => { Name => 'LogScale',             Writable => 'rational64u' }, #4
    0x0903 => { Name => 'BaseISO',              Writable => 'rational64u' }, #IB (ISO before digital gain)
    0x0904 => { Name => 'LinLogCoring',         Writable => 'int16u' }, #4
    0x0905 => { Name => 'PatternGainConversionTable', Binary => 1 }, #4 (int8u[256])
    0x0906 => 'DefectCount', #4
    0x0907 => { Name => 'DefectList',           Binary => 1 }, #4 (undef[48])
    0x0908 => { Name => 'DefectListPacked',     Binary => 1 }, #4 (int16u[296])
    0x0909 => { Name => 'ImageSpace',           Writable => 'int16u' }, #4
    0x090a => { Name => 'ThumbnailCompressionTable',Binary => 1 }, #4 (int8u[4096])
    0x090b => { Name => 'ThumbnailExpansionTable',  Binary => 1 }, #4 (int16u[256])
    0x090c => { Name => 'ImageCompressionTable',    Binary => 1 }, #4 (int16u[4096])
    0x090d => { Name => 'ImageExpansionTable',      Binary => 1 }, #4 (int16u[1024/4096])
    0x090e => 'EighteenPercentPoint', #4
    0x090f => { Name => 'DefectIsoCode',        Writable => 'int16u' }, #4
    0x0910 => { Name => 'BaseISODaylight',      Writable => 'rational64u' }, #4
    0x0911 => { Name => 'BaseISOTungsten',      Writable => 'rational64u' }, #4
    0x0912 => { Name => 'BaseISOFluorescent',   Writable => 'rational64u' }, #4
    0x0913 => { Name => 'BaseISOFlash',         Writable => 'rational64u' }, #4
    0x091a => { Name => 'MatrixSelectThreshold',Writable => 'int16s' }, #4
    0x091b => { Name => 'MatrixSelectK',        Writable => 'rational64u' }, #4
    0x091c => { Name => 'IlluminantDetectTable',Binary => 1 }, #4 (int16u[200])
    0x091d => 'RGTable', #4
    0x091e => { Name => 'MatrixSelectThreshold1', Writable => 'int16s' }, #4
    0x091f => { Name => 'MatrixSelectThreshold2', Writable => 'int16s' }, #4
    0x0924 => 'PortraitMatrix', #4
    0x0925 => 'PortraitToneScaleTable', #4
    0x092e => { Name => 'EnableSharpening',     Writable => 'int16u' }, #4
    0x092f => { #4
        Name => 'SharpeningKernel',
        Writable => 'int16s',
        Count => 25,
    },
    0x0930 => { Name => 'EdgeMapSlope',         Writable => 'int16u' }, #4
    0x0931 => { Name => 'EdgeMapX1',            Writable => 'int16u' }, #4
    0x0932 => { Name => 'EdgeMapX2',            Writable => 'int16u' }, #4
    0x0933 => { #4
        Name => 'KernelDenominators',
        Writable => 'int16u',
        Count => 3,
    },
    0x0934 => { Name => 'EdgeMapX3',            Writable => 'int16u' }, #4
    0x0935 => { Name => 'EdgeMapX4',            Writable => 'int16u' }, #4
    0x0936 => 'SharpenForThumbnail', #4
    0x0937 => 'EdgeSpline', #4
    0x0938 => 'DownSampleBy2Hor', #4 (int16s[4])
    0x0939 => 'DownSampleBy2Ver', #4 (int16s[4])
    0x093a => 'DownSampleBy4Hor', #4 (int16s[6])
    0x093b => 'DownSampleBy4Ver', #4 (int16s[6])
    0x093c => 'DownSampleBy3Hor', #4 (int16s[6])
    0x093d => 'DownSampleBy3Ver', #4 (int16s[6])
    0x093e => 'DownSampleBy6Hor', #4 (int16s[8])
    0x093f => 'DownSampleBy6Ver', #4 (int16s[8])
    0x0940 => 'DownSampleBy2Hor3MPdcr', #4
    0x0941 => 'DownSampleBy2Ver3MPdcr', #4
    0x0942 => 'ThumbnailResizeRatio', #4
    0x0943 => { Name => 'AtCaptureUserCrop',    Writable => 'int32u', Count => 4 }, #4 (Top, Left, Bottom, Right)
    0x0944 => { Name => 'ImageResolution',      Writable => 'int32u' }, #4 (Contains enum for imageDcrRes or imageJpegRes)
    0x0945 => { Name => 'ImageResolutionJpg',   Writable => 'int32u' }, #4 (Contains enum for imageJpegRes)
    0x094c => 'USMParametersLow', #4 (int16s[8])
    0x094d => 'USMParametersMed', #4 (int16s[8])
    0x094e => 'USMParametersHigh', #4 (int16s[8])
    0x094f => 'USMParametersHost', #4 (int16s[10])
    0x0950 => { Name => 'EdgeSplineLow', Binary => 1 }, #4 (rational64s[57])
    0x0951 => { Name => 'EdgeSplineMed', Binary => 1 }, #4 (rational64s[69])
    0x0952 => { Name => 'EdgeSplineHigh',Binary => 1 }, #4 (rational64s[69])
    0x0953 => 'USMParametersHost6MP', #4 (int16s[10])
    0x0954 => 'USMParametersHost3MP', #4 (int16s[10])
    0x0960 => { Name => 'PatternImagerWidth',   Writable => 'int16u' }, #4
    0x0961 => { Name => 'PatternImagerHeight',  Writable => 'int16u' }, #4
    0x0962 => { Name => 'PatternAreaWidth',     Writable => 'int16u' }, #4
    0x0963 => { Name => 'PatternAreaHeight',    Writable => 'int16u' }, #4
    0x0964 => { Name => 'PatternCorrectionGains', Binary => 1 }, #4 (undef[48174])
    0x0965 => 'PatternCorrectionOffsets', #4
    0x0966 => { Name => 'PatternX',             Writable => 'int16u' }, #4
    0x0967 => { Name => 'PatternY',             Writable => 'int16u' }, #4
    0x0968 => { Name => 'PatternCorrectionFactors', Binary => 1 }, #4 (undef[48174])
    0x0969 => { Name => 'PatternCorrectionFactorScale', Writable => 'int16u' }, #4
    0x096a => { Name => 'PatternCropRows1',     Writable => 'int16u' }, #4
    0x096b => { Name => 'PatternCropRows2',     Writable => 'int16u' }, #4
    0x096c => { Name => 'PatternCropCols1',     Writable => 'int16u' }, #4
    0x096d => { Name => 'PatternCropCols2',     Writable => 'int16u' }, #4
    0x096e => 'PixelCorrectionGains', #4
    0x096f => 'StitchRows', #4 (int16u[6])
    0x0970 => 'StitchColumns', #4 (int16u)
    0x0971 => { Name => 'PixelCorrectionScale', Writable => 'int16u' }, #4
    0x0972 => { Name => 'PixelCorrectionOffset',Writable => 'int16u' }, #4
    0x0988 => 'LensTableIndex', #4
    0x0992 => 'DiffTileGains602832', #4
    0x0993 => 'DiffTileGains24t852822', #4 (reserved tags 2450-2459)
    0x099c => 'TileGainDeterminationTable', #4 (int16s[0])
    0x099d => 'NemoBlurKernel', #4 (int16s[14])
    0x099e => 'NemoTileSize', #4 (int16u)
    0x099f => 'NemoGainFactors', #4 (rational64s[4])
    0x09a0 => 'NemoDarkLimit', #4 (int16u)
    0x09a1 => 'NemoHighlight12Limit', #4
    0x09c4 => { Name => 'ImagerFileProductionLevel',Writable => 'int16u' }, #4
    0x09c5 => { Name => 'ImagerFileDateCreated',    Writable => 'int32u' }, #4 (unknown encoding - PH)
    0x09c6 => { Name => 'CalibrationVersion',       Writable => 'string' }, #4
    0x09c7 => { Name => 'ImagerFileTagsVersionStandard', Writable => 'int16u' }, #4
    0x09c8 => { Name => 'IFCameraModel',            Writable => 'string' }, #4
    0x09c9 => { Name => 'CalibrationHistory',       Writable => 'string' }, #4
    0x09ca => { Name => 'CalibrationLog',           Binary => 1 }, #4 (undef[1140])
    0x09ce => { Name => 'SensorSerialNumber', Writable => 'string', Groups => { 2 => 'Camera' } }, #IB/4
    0x09f6 => 'DefectConcealArtCorrectThres', #4 (no longer used)
    0x09f7 => 'SglColDCACThres1', #4
    0x09f8 => 'SglColDCACThres2', #4
    0x09f9 => 'SglColDCACTHres3', #4
    0x0a01 => 'DblColDCACThres1', #4
    0x0a02 => 'DblColDCACThres2', #4
    0x0a0a => { Name => 'DefectConcealThresTable',  Binary => 1 }, #4 (int16u[121/79])
    0x0a28 => 'MonoUniqueMatrix', #4
    0x0a29 => 'MonoMonitorMatrix', #4
    0x0a2a => 'MonoToneScaleTable', #4
    # 0x0a32-0x0a3b "OmenInitialSurfaceRed(n)", ref 4
    # 0x0a3c-0x0a45 "OmenInitialSurfaceGoR(n)", ref 4
    # 0x0a46-0x0a4f "OmenInitialSurfaceBlue(n)", ref 4
    # 0x0a50-0x0a59 "OmenInitialSurfaceGoB(n)", ref 4
    0x0a5a => 'OmenInitialScaling', #4
    0x0a5b => 'OmenInitialRows', #4
    0x0a5c => 'OmenInitialColumns', #4
    0x0a5d => { Name => 'OmenInitialIPFStrength',Writable => 'int32s', Count => 4 }, #4
    0x0a5e => { Name => 'OmenEarlyStrength',     Writable => 'int32s', Count => 4 }, #4
    0x0a5f => { Name => 'OmenAutoStrength',      Writable => 'int32s', Count => 4 }, #4
    0x0a60 => { Name => 'OmenAtCaptureStrength', Writable => 'int32s', Count => 4 }, #4
    0x0a61 => 'OmenAtCaptureMode', #4
    0x0a62 => { Name => 'OmenFocalLengthLimit',  Writable => 'int16s' }, #4
    0x0a64 => { Name => 'OmenSurfaceIndex',      Writable => 'int16s' }, #4 (which InitialSurface to use)
    0x0a65 => 'OmenPercentToRationalLimitsRed', #4 (signed rationals for 0 and 100)
    0x0a66 => 'OmenPercentToRationalLimitsGoR', #4 (signed rationals for 0 and 100)
    0x0a67 => 'OmenPercentToRationalLimitsBlue', #4 (signed rationals for 0 and 100)
    0x0a68 => 'OmenPercentToRationalLimitsGoB', #4 (signed rationals for 0 and 100)
    0x0a6e => 'OmenEarlyGoBSurface', #4
    0x0a6f => 'OmenEarlyGoBRows', #4
    0x0a70 => 'OmenEarlyGoBColumns', #4
    0x0a73 => 'OmenSmoothingKernel', #4
    0x0a74 => 'OmenGradientOffset', #4
    0x0a75 => 'OmenGradientKernel', #4
    0x0a76 => 'OmenGradientKernelTaps', #4
    0x0a77 => 'OmenRatioClipFactors', #4
    0x0a78 => 'OmenRatioExclusionFactors', #4
    0x0a79 => 'OmenGradientExclusionLimits', #4
    0x0a7a => 'OmenROICoordinates', #4
    0x0a7b => 'OmenROICoefficients', #4
    0x0a7c => 'OmenRangeWeighting', #4
    0x0a7d => 'OmenMeanToStrength', #4
    0x0bb8 => 'FactoryWhiteGainsDaylight', #4
    0x0bb9 => 'FactoryWhiteOffsetsDaylight', #4
    0x0bba => 'DacGainsCoarse', #4
    0x0bbb => 'DacGainsFine', #4
    0x0bbc => 'DigitalExposureGains', #4
    0x0bbd => 'DigitalExposureBiases', #4
    0x0bbe => 'BlackClamp', #4
    0x0bbf => 'ChannelCoarseGainAdjust', #4
    0x0bc0 => 'BlackClampOffset', #4
    0x0bf4 => 'DMPixelThresholdFactor', #4 (TIFF_RATIONAL)
    0x0bf5 => 'DMWindowThresholdFactor', #4 (TIFF_RATIONAL)
    0x0bf6 => 'DMTrimFraction', #4 (TIFF_RATIONAL)
    0x0bf7 => 'DMSmoothRejThresh', #4 (TIFF_RATIONAL)
    0x0bf8 => 'DMFillRejThresh', #4 (TIFF_RATIONAL)
    0x0bf9 => 'VMWsize', #4 (TIFF_SHORT)
    0x0bfa => 'DMErodeRadius', #4 (TIFF_SHORT)
    0x0bfb => 'DMNumPatches', #4 (TIFF_SHORT)
    0x0bfc => 'DMNoiseScale', #4 (TIFF_RATIONAL)
    0x0bfe => 'BrightDefectThreshold', #4
    0x0bff => 'BrightDefectIntegrationMS', #4
    0x0c00 => 'BrightDefectIsoCode', #4
    0x0c03 => 'TopDarkRow1', #4 (support 330 dark map generation algorithm)
    0x0c04 => 'TopDarkRow2', #4 (these tags were 3175-3192 prior to 18Jan2001)
    0x0c05 => 'BottomDarkRow1', #4
    0x0c06 => 'BottomDarkRow2', #4
    0x0c07 => 'LeftDarkCol1', #4
    0x0c08 => 'LeftDarkCol2', #4
    0x0c09 => 'RightDarkCol1', #4
    0x0c0a => 'RightDarkCol2', #4
    0x0c0b => 'HMPixThresh', #4
    0x0c0c => 'HMColThresh', #4
    0x0c0d => 'HMWsize', #4
    0x0c0e => 'HMColRejThresh', #4
    0x0c0f => 'VMPixThresh', #4
    0x0c10 => 'VMColThresh', #4
    0x0c11 => 'VMNbands', #4
    0x0c12 => 'VMColDropThresh', #4
    0x0c13 => 'VMPatchResLimit', #4
    0x0c14 => 'MapScale', #4
    0x0c1c => 'Klut', #4
    0x0c1d => 'RimNonlinearity', #4 (Obsolete)
    0x0c1e => 'InverseRimNonlinearity', #4 (Obsolete)
    0x0c1f => 'RembrandtToneScale', #4 (Obsolete)
    0x0c20 => 'RimToNifColorTransform', #4 (Obsolete)
    0x0c21 => 'RimToNifScaleFactor', #4 (Obsolete)
    0x0c22 => 'NifNonlinearity', #4 (Obsolete)
    0x0c23 => 'SBALogTransform', #4 (Obsolete)
    0x0c24 => 'InverseSBALogTransform', #4 (Obsolete)
    0x0c25 => { Name => 'SBABlack',         Writable => 'int16u' }, #4
    0x0c26 => { Name => 'SBAGray',          Writable => 'int16u' }, #4
    0x0c27 => { Name => 'SBAWhite',         Writable => 'int16u' }, #4
    0x0c28 => { Name => 'GaussianWeights',  Binary => 1 }, #4 (int16u[864])
    0x0c29 => { Name => 'SfsBoundary',      Binary => 1 }, #4 (int16u[6561])
    0x0c2a => 'CoringTableBest', #4 (Obsolete)
    0x0c2b => 'CoringTableBetter', #4 (Obsolete)
    0x0c2c => 'CoringTableGood', #4 (Obsolete)
    0x0c2d => 'ExposureReferenceGain', #4 (Obsolete)
    0x0c2e => 'ExposureReferenceOffset', #4 (Obsolete)
    0x0c2f => 'SBARedBalanceLut', #4 (Obsolete)
    0x0c30 => 'SBAGreenBalanceLut', #4 (Obsolete)
    0x0c31 => 'SBABlueBalanceLut', #4 (Obsolete)
    0x0c32 => { Name => 'SBANeutralBAL',        Writable => 'int32s' }, #4
    0x0c33 => { Name => 'SBAGreenMagentaBAL',   Writable => 'int32s' }, #4
    0x0c34 => { Name => 'SBAIlluminantBAL',     Writable => 'int32s' }, #4
    0x0c35 => { Name => 'SBAAnalysisComplete',  Writable => 'int8u' }, #4
    0x0c36 => 'JPEGQTableBest', #4
    0x0c37 => 'JPEGQTableBetter', #4
    0x0c38 => 'JPEGQTableGood', #4
    0x0c39 => 'RembrandtPortraitToneScale', #4 (Obsolete)
    0x0c3a => 'RembrandtConsumerToneScale', #4 (Obsolete)
    0x0c3b => 'CFAGreenThreshold1', #4 (Now CFAGreenThreshold1H)
    0x0c3c => 'CFAGreenThreshold2', #4 (Now CFAGreenThreshold2V)
    0x0c3d => { Name => 'QTableLarge50Pct',     Binary => 1 }, #4 (undef[130])
    0x0c3e => { Name => 'QTableLarge67Pct',     Binary => 1 }, #4 (undef[130])
    0x0c3f => { Name => 'QTableLarge100Pct',    Binary => 1 }, #4 (undef[130])
    0x0c40 => { Name => 'QTableMedium50Pct',    Binary => 1 }, #4 (undef[130])
    0x0c41 => { Name => 'QTableMedium67Pct',    Binary => 1 }, #4 (undef[130])
    0x0c42 => { Name => 'QTableMedium100Pct',   Binary => 1 }, #4 (undef[130])
    0x0c43 => { Name => 'QTableSmall50Pct',     Binary => 1 }, #4 (undef[130])
    0x0c44 => { Name => 'QTableSmall67Pct',     Binary => 1 }, #4 (undef[130])
    0x0c45 => { Name => 'QTableSmall100Pct',    Binary => 1 }, #4 (undef[130])
    0x0c46 => { Name => 'SBAHighGray',          Writable => 'int16u' }, #4
    0x0c47 => { Name => 'SBALowGray',           Writable => 'int16u' }, #4
    0x0c48 => { Name => 'CaptureLook',          Writable => 'int16u' }, #4 (was "ToneScaleFlag")
    0x0c49 => { Name => 'SBAIllOffset',         Writable => 'int16s' }, #4
    0x0c4a => { Name => 'SBAGmOffset',          Writable => 'int16s' }, #4
    0x0c4b => 'NifNonlinearity12Bit', #4 (Obsolete)
    0x0c4c => 'SharpeningOn', #4 (Obsolete)
    0x0c4d => 'NifNonlinearity16Bit', #4 (Obsolete)
    0x0c4e => 'RawHistogram', #4
    0x0c4f => 'RawCFAComponentAverages', #4
    0x0c50 => 'DisableFlagsPresent', #4
    0x0c51 => 'DelayCols', #4
    0x0c52 => 'DummyColsLeft', #4
    0x0c53 => 'TrashColsRight', #4
    0x0c54 => 'BlackColsRight', #4
    0x0c55 => 'DummyColsRight', #4
    0x0c56 => 'OverClockColsRight', #4
    0x0c57 => 'UnusedBlackRowsTopOut', #4
    0x0c58 => 'TrashRowsBottom', #4
    0x0c59 => 'BlackRowsBottom', #4
    0x0c5a => 'OverClockRowsBottom', #4
    0x0c5b => 'BlackColsLeft', #4
    0x0c5c => 'BlackRowsTop', #4
    0x0c5d => 'PartialActiveColsLeft', #4
    0x0c5e => 'PartialActiveColsRight', #4
    0x0c5f => 'PartialActiveRowsTop', #4
    0x0c60 => 'PartialActiveRowsBottom', #4
    0x0c61 => { Name => 'ProcessBorderColsLeft',    Writable => 'int16u' }, #4
    0x0c62 => { Name => 'ProcessBorderColsRight',   Writable => 'int16u' }, #4
    0x0c63 => { Name => 'ProcessBorderRowsTop',     Writable => 'int16u' }, #4
    0x0c64 => { Name => 'ProcessBorderRowsBottom',  Writable => 'int16u' }, #4
    0x0c65 => 'ActiveCols', #4
    0x0c66 => 'ActiveRows', #4
    0x0c67 => 'FirstLines', #4
    0x0c68 => 'UnusedBlackRowsTopIn', #4
    0x0c69 => 'UnusedBlackRowsBottomIn', #4
    0x0c6a => 'UnusedBlackRowsBottomOut', #4
    0x0c6b => 'UnusedBlackColsLeftOut', #4
    0x0c6c => 'UnusedBlackColsLeftIn', #4
    0x0c6d => 'UnusedBlackColsRightIn', #4
    0x0c6e => 'UnusedBlackColsRightOut', #4
    0x0c6f => { Name => 'CFAOffsetRows',            Writable => 'int32u' }, #4
    0x0c70 => { Name => 'ShiftCols',                Writable => 'int16s' }, #4
    0x0c71 => { Name => 'CFAOffsetCols',            Writable => 'int32u' }, #4
    0x0c76 => 'DarkMapScale', #4
    0x0c77 => 'HMapHandling', #4
    0x0c78 => 'VMapHandling', #4
    0x0c79 => 'DarkThreshold', #4
    0x0c7a => { Name => 'DMDitherMatrix',           Writable => 'int16u' }, #4
    0x0c7b => { Name => 'DMDitherMatrixWidth',      Writable => 'int16u' }, #4
    0x0c7c => { Name => 'DMDitherMatrixHeight',     Writable => 'int16u' }, #4
    0x0c7d => { Name => 'MaxPixelValueThreshold',   Writable => 'int16u' }, #4
    0x0c7e => { Name => 'HoleFillDeltaThreshold',   Writable => 'int16u' }, #4
    0x0c7f => { Name => 'DarkPedestal',             Writable => 'int16u' }, #4
    0x0c80 => { Name => 'ImageProcessingFileTagsVersionNumber', Writable => 'int16u' }, #4
    0x0c81 => { Name => 'ImageProcessingFileDateCreated', Writable => 'string', Groups => { 2 => 'Time' } }, #4
    0x0c82 => { Name => 'DoublingMicrovolts',       Writable => 'int32s' }, #4
    0x0c83 => { #4
        Name => 'DarkFrameShortExposure',
        Writable => 'int32u',
        ValueConv => '$val / 1e6', # (microseconds)
        ValueConvInv => '$val * 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
    },
    0x0c84 => { #4
        Name => 'DarkFrameLongExposure',
        Writable => 'int32u',
        ValueConv => '$val / 1e6', # (microseconds)
        ValueConvInv => '$val * 1e6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
    },
    0x0c85 => { Name => 'DarkFrameCountFactor',     Writable => 'rational64u' }, #4
    0x0c88 => { Name => 'HoleFillDarkDeltaThreshold', Writable => 'int16u' }, #4
    0x0c89 => 'FarkleWhiteThreshold', #4
    0x0c8a => { Name => 'ColumnResetOffsets',       Binary => 1 }, #4 (int16u[3012])
    0x0c8b => { Name => 'ColumnGainFactors',        Binary => 1 }, #4 (int16u[3012])
    # 0x0c94-0x0c9d ColumnOffsets (int16u[3012]), ref 4
    0x0c8c => 'Channel0LagKernel', #4
    0x0c8d => 'Channel1LagKernel', #4
    0x0c8e => 'Channel2LagKernel', #4
    0x0c8f => 'Channel3LagKernel', #4
    0x0c90 => 'BluegrassTable', #4
    0x0c91 => 'BluegrassScale1', #4
    0x0c92 => 'BluegrassScale2', #4
    0x0ce4 => 'FinishedFileProcessingRequest', #4
    0x0ce5 => { Name => 'FirmwareVersion',  Writable => 'string', Groups => { 2 => 'Camera' } }, # ("ProcessingSoftware", ref 4)
    0x0ce6 => 'HostSoftwareExportVersion', #4 (ULONG only exists if made by host SW)
    0x0ce7 => { #4
        Name => 'HostSoftwareRendering',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Normal (sRGB)',
            1 => 'Linear (camera RGB)',
            2 => 'Pro Photo RGB',
            3 => 'Unknown',
            4 => 'Other Profile',
        },
    },
    0x0dac => 'DCS3XXProcessingInfoIFD', #4 (Obsolete)
    0x0dad => 'DCS3XXProcessingInfo', #4 (Obsolete)
    0x0dae => { Name => 'IPAVersion',       Writable => 'int32u' }, #4
    0x0db6 => 'FinishIPAVersion', #4
    0x0db7 => 'FinishIPFVersion', #4
    0x0db8 => { #4
        Name => 'FinishFileType',
        Writable => 'int32u',
        PrintConv => {
            0 => 'JPEG Best',
            1 => 'JPEG Better',
            2 => 'JPEG Good',
            3 => 'TIFF RGB',
        },
    },
    0x0db9 => { #4
        Name => 'FinishResolution',
        Writable => 'int32u',
        PrintConv => {
            0 => '100%',
            1 => '67%',
            2 => '50%',
            3 => '25%',
        },
    },
    0x0dba => { #4
        Name => 'FinishNoise',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Strong',
            2 => 'Low',
        },
    },
    0x0dbb => { #4
        Name => 'FinishSharpening',
        Writable => 'int32u',
        PrintConv => {
            0 => 'None',
            1 => 'High',
            2 => 'Medium',
            3 => 'Low',
        },
    },
    0x0dbc => { #4
        Name => 'FinishLook',
        Writable => 'int32u',
        PrintConv => {
            0 => 'Product',
            1 => 'Portrait',
            2 => 'Product Reduced',
            3 => 'Portrait Reduced',
            4 => 'Monochrome Product',
            5 => 'Monochrome Portrait',
            6 => 'Wedding',
            7 => 'Event',
            8 => 'Product Hi Color',
            9 => 'Portrait Hi Color',
            # (past this is not yet implemented)
            10 => 'Product Hi Color Hold',
            11 => 'Portrait Hi Color Hold',
            13 => 'DCS BW Normal',
            14 => 'DCS BW Wratten 8',
            15 => 'DCS BW Wratten 25',
            16 => 'DCS Sepia 1',
            17 => 'DCS Sepia 2',
        },
    },
    0x0dbd => { #4
        Name => 'FinishExposure',
        Writable => 'int32u',
        PrintConv => { 0 => 'Yes', 1 => 'No' },
    },
    0x0e0b => { Name => 'SigmaScalingFactorLowRes', Writable => 'rational64u' }, #4 (for scaling sigma tables in-camera)
    0x0e0c => { Name => 'SigmaScalingFactorCamera', Writable => 'rational64u' }, #4 (for scaling sigma tables in-camera)
    0x0e0d => { Name => 'SigmaImpulseParameters',   Writable => 'int16u', Count => -1 }, #4 (for impulse reduction control)
    0x0e0e => { Name => 'SigmaNoiseThreshTableV2',  Binary => 1 }, #4 (replaces V2 caltable)
    0x0e0f => { Name => 'SigmaSizeTable',           Writable => 'int16u', Count => -1 }, #4
    0x0e10 => 'DacGainsCoarseAdjPreIF41', #4 (Tag not used due to abandoned implementation)
    0x0e11 => { Name => 'SigmaNoiseFilterCalTableV1', Binary => 1 }, #4 (undef[418]) (Defines Version 1 of Sigma Noise Filter table within .IF/.IPF)
    0x0e12 => { Name => 'SigmaNoiseFilterTableV1',  Binary => 1}, #4 (Defines Version 1 of Sigma Noise Filter table within image)
    0x0e13 => 'Lin12ToKlut8', #4
    0x0e14 => 'SigmaNoiseFilterTableV1Version', #4 (int16u/int32u) (This tag describes the version level of the SigmaNoiseFilterTableV1 class of tags)
    0x0e15 => 'Lin12ToKlut12', #4
    0x0e16 => 'Klut12ToLin12', #4
    0x0e17 => { Name => 'NifNonlinearity12To16',    Binary => 1 }, #4 (int16u[4096])
    0x0e18 => { Name => 'SBALog12Transform',        Binary => 1 }, #4 (int16u[4096])
    0x0e19 => { Name => 'InverseSBALog12Transform', Binary=> 1 }, #4 (int16u[3613])
    0x0e1a => { Name => 'ToneScale0',   Binary => 1 }, #4 (int16u[4096]) (Was Portrait12ToneScale on DCS3XX 1.3.1)
    0x0e1b => { Name => 'ToneScale1',   Binary => 1 }, #4 (int16u[4096]) (Was Consumer12ToneScale on DCS3XX 1.3.1)
    0x0e1c => { Name => 'ToneScale2',   Binary => 1 }, #4 (int16u[4096])
    0x0e1d => { Name => 'ToneScale3',   Binary => 1 }, #4 (int16u[4096])
    0x0e1e => { Name => 'ToneScale4',   Binary => 1 }, #4 (int16u[4096])
    0x0e1f => { Name => 'ToneScale5',   Binary => 1 }, #4 (int16u[4096])
    0x0e20 => { Name => 'ToneScale6',   Binary => 1 }, #4 (int16u[4096])
    0x0e21 => { Name => 'ToneScale7',   Binary => 1 }, #4 (int16u[4096])
    0x0e22 => { Name => 'ToneScale8',   Binary => 1 }, #4 (int16u[4096])
    0x0e23 => { Name => 'ToneScale9',   Binary => 1 }, #4 (int16u[4096])
    0x0e24 => 'DayMat0', #4 (Obsolete)
    0x0e25 => 'DayMat1', #4 (Obsolete)
    0x0e26 => 'DayMat2', #4 (Obsolete)
    0x0e27 => 'DayMat3', #4 (Obsolete)
    0x0e28 => 'DayMat4', #4 (Obsolete)
    0x0e29 => 'DayMat5', #4 (Obsolete)
    0x0e2a => 'DayMat6', #4 (Obsolete)
    0x0e2b => 'DayMat7', #4 (Obsolete)
    0x0e2c => 'DayMat8', #4 (Obsolete)
    0x0e2d => 'DayMat9', #4 (Obsolete)
    0x0e2e => 'TungMat0', #4 (Obsolete)
    0x0e2f => 'TungMat1', #4 (Obsolete)
    0x0e30 => 'TungMat2', #4 (Obsolete)
    0x0e31 => 'TungMat3', #4 (Obsolete)
    0x0e32 => 'TungMat4', #4 (Obsolete)
    0x0e33 => 'TungMat5', #4 (Obsolete)
    0x0e34 => 'TungMat6', #4 (Obsolete)
    0x0e35 => 'TungMat7', #4 (Obsolete)
    0x0e36 => 'TungMat8', #4 (Obsolete)
    0x0e37 => 'TungMat9', #4 (Obsolete)
    0x0e38 => 'FluorMat0', #4 (Obsolete)
    0x0e39 => 'FluorMat1', #4 (Obsolete)
    0x0e3a => 'FluorMat2', #4 (Obsolete)
    0x0e3b => 'FluorMat3', #4 (Obsolete)
    0x0e3c => 'FluorMat4', #4 (Obsolete)
    0x0e3d => 'FluorMat5', #4 (Obsolete)
    0x0e3e => 'FluorMat6', #4 (Obsolete)
    0x0e3f => 'FluorMat7', #4 (Obsolete)
    0x0e40 => 'FluorMat8', #4 (Obsolete)
    0x0e41 => 'FluorMat9', #4 (Obsolete)
    0x0e42 => 'FlashMat0', #4 (Obsolete)
    0x0e43 => 'FlashMat1', #4 (Obsolete)
    0x0e44 => 'FlashMat2', #4 (Obsolete)
    0x0e45 => 'FlashMat3', #4 (Obsolete)
    0x0e46 => 'FlashMat4', #4 (Obsolete)
    0x0e47 => 'FlashMat5', #4 (Obsolete)
    0x0e48 => 'FlashMat6', #4 (Obsolete)
    0x0e49 => 'FlashMat7', #4 (Obsolete)
    0x0e4a => 'FlashMat8', #4 (Obsolete)
    0x0e4b => 'FlashMat9', #4 (Obsolete)
    0x0e4c => { #IB
        Name => 'KodakLook', # ("LookNameTable", ref 4)
        Format => 'undef',
        Writable => 'string',
        ValueConv => '$val=~tr/\0/\n/; $val',
        ValueConvInv => '$val=~tr/\n/\0/; $val',
    },
    0x0e4d => { Name => 'IPFCameraModel',   Writable => 'string' }, #4
    0x0e4e => { Name => 'AH2GreenInterpolationThreshold',   Writable => 'int16u' }, #4
    0x0e4f => { Name => 'ResamplingKernelDenominators067',  Writable => 'int16u', Count => 3 }, #4 (table of sharpening denoms; 0=Low, 1=Medium, 2=High)
    0x0e50 => { Name => 'ResamplingKernelDenominators050',  Writable => 'int16u', Count => 3 }, #4 (table of sharpening denoms; 0=Low, 1=Medium, 2=High)
    0x0e51 => { Name => 'ResamplingKernelDenominators100',  Writable => 'int16u', Count => 3 }, #4 (table of sharpening denoms; 0=Low, 1=Medium, 2=High)
    0x0e56 => 'LookMat0', #4 (rational64s[9])
    0x0e57 => 'LookMat1', #4 (rational64s[9])
    0x0e58 => 'LookMat2', #4 (rational64s[9])
    0x0e59 => 'LookMat3', #4 (rational64s[9])
    0x0e5a => 'LookMat4', #4 (rational64s[9])
    0x0e5b => 'LookMat5', #4 (rational64s[9])
    0x0e5c => 'LookMat6', #4 (rational64s[9])
    0x0e5d => 'LookMat7', #4 (rational64s[9])
    0x0e5e => 'LookMat8', #4 (rational64s[9])
    0x0e5f => 'LookMat9', #4 (rational64s[9])
    0x0e60 => { #4
        Name => 'CFAInterpolationAlgorithm',
        Writable => 'int16u',
        PrintConv => { 0 => 'AH2', 1 => 'Karnak' },
    },
    0x0e61 => { #4
        Name => 'CFAInterpolationMetric',
        Writable => 'int16u',
        PrintConv => { 0 => 'Linear12', 1 => 'KLUT12' },
    },
    0x0e62 => { Name => 'CFAZipperFixThreshold',            Writable => 'int16u' }, #4
    0x0e63 => { Name => 'NoiseReductionParametersKhufuRGB', Writable => 'int16u', Count => 9 }, #4
    0x0e64 => { Name => 'NoiseReductionParametersKhufu6MP', Writable => 'int16u', Count => 9 }, #4
    0x0e65 => { Name => 'NoiseReductionParametersKhufu3MP', Writable => 'int16u', Count => 9 }, #4
    0x0e6a => { Name => 'ChromaNoiseHighFThresh',           Writable => 'int32u', Count => 2 }, #4
    0x0e6b => { Name => 'ChromaNoiseLowFThresh',            Writable => 'int32u', Count => 2 }, #4
    0x0e6c => { Name => 'ChromaNoiseEdgeMapThresh',         Writable => 'int32u' }, #4
    0x0e6d => { Name => 'ChromaNoiseColorSpace',            Writable => 'int32u' }, #4
    0x0e6e => { Name => 'EnableChromaNoiseReduction',       Writable => 'int16u' }, #4
    # 9 values for noise reduction parameters:
    #  0 - NRLowType
    #  1 - NRLowRadius
    #  2 - NRLowStrength
    #  3 - NRMediumType
    #  4 - NRMediumRadius
    #  5 - NRMediumStrength
    #  6 - NRHighType
    #  7 - NRHighRadius
    #  8 - NRHighStrength
    # NRType values:
    #  0 = None
    #  1 = SigmaChroma
    #  2 = SigmaOnly
    #  3 = SigmaMoire
    #  4 = SigmaChromaWithRadius
    #  5 = SigmaMoireWithRadius
    #  6 = SigmaExpert (aka Khufu)
    #  7 = SigmaWithRadius
    0x0e6f => { Name => 'NoiseReductionParametersHostRGB',  Writable => 'int16u', Count => 9 }, #4
    0x0e70 => { Name => 'NoiseReductionParametersHost6MP',  Writable => 'int16u', Count => 9 }, #4
    0x0e71 => { Name => 'NoiseReductionParametersHost3MP',  Writable => 'int16u', Count => 9 }, #4
    0x0e72 => { Name => 'NoiseReductionParametersCamera',   Writable => 'int16u', Count => 6 }, #4
    0x0e73 => { #4
        Name => 'NoiseReductionParametersAtCapture',
        Writable => 'int16u',
        Count => 6,
        # 6 values:
        #  0 - Algorithm type
        #  1 - Radius
        #  2 - Strength
        #  3 - Khufu Luma
        #  4 - Reserved 1
        #  5 - Reserved 2
    },
    0x0e74 => { Name => 'LCDMatrix',            Writable => 'rational64s', Count => 9 }, #4
    0x0e75 => { Name => 'LCDMatrixChickFix',    Writable => 'rational64s', Count => 9 }, #4
    0x0e76 => { Name => 'LCDMatrixMarvin',      Writable => 'rational64s', Count => 9 }, #4
    0x0e7c => { Name => 'LCDGammaTableChickFix',Binary => 1 }, #4 (int16u[4096])
    0x0e7d => { Name => 'LCDGammaTableMarvin',  Binary => 1 }, #4 (int16u[4096])
    0x0e7e => { Name => 'LCDGammaTable',        Binary => 1 }, #4 (int16u[4096])
    0x0e7f => 'LCDSharpeningF1', #4 (int16s[4])
    0x0e80 => 'LCDSharpeningF2', #4
    0x0e81 => 'LCDSharpeningF3', #4
    0x0e82 => 'LCDSharpeningF4', #4
    0x0e83 => 'LCDEdgeMapX1', #4
    0x0e84 => 'LCDEdgeMapX2', #4
    0x0e85 => 'LCDEdgeMapX3', #4
    0x0e86 => 'LCDEdgeMapX4', #4
    0x0e87 => 'LCDEdgeMapSlope', #4
    0x0e88 => 'YCrCbMatrix', #4
    0x0e89 => 'LCDEdgeSpline', #4 (rational64s[9])
    0x0e92 => { Name => 'Fac18Per',     Writable => 'int16u' }, #4
    0x0e93 => { Name => 'Fac170Per',    Writable => 'int16u' }, #4
    0x0e94 => { Name => 'Fac100Per',    Writable => 'int16u' }, #4
    0x0e9b => 'ExtraTickLocations', #4 (int16u[7])
    0x0e9c => { Name => 'RGBtoeV0',     Binary => 1 }, #4 (int16s[256])
    0x0e9d => { Name => 'RGBtoeV1',     Binary => 1 }, #4 (int16s[256])
    0x0e9e => { Name => 'RGBtoeV2',     Binary => 1 }, #4 (int16s[256])
    0x0e9f => { Name => 'RGBtoeV3',     Binary => 1 }, #4 (int16s[256])
    0x0ea0 => { Name => 'RGBtoeV4',     Binary => 1 }, #4 (int16s[256])
    0x0ea1 => { Name => 'RGBtoeV5',     Binary => 1 }, #4 (int16s[256])
    0x0ea2 => { Name => 'RGBtoeV6',     Binary => 1 }, #4 (int16s[256])
    0x0ea3 => { Name => 'RGBtoeV7',     Binary => 1 }, #4 (int16s[256])
    0x0ea4 => { Name => 'RGBtoeV8',     Binary => 1 }, #4 (int16s[256])
    0x0ea5 => { Name => 'RGBtoeV9',     Binary => 1 }, #4 (int16s[256])
    0x0ea6 => { Name => 'LCDHistLUT0',  Binary => 1 }, #4 (rational64s[48])
    0x0ea7 => { Name => 'LCDHistLUT1',  Binary => 1 }, #4 (rational64s[57])
    0x0ea8 => { Name => 'LCDHistLUT2',  Binary => 1 }, #4 (rational64s[48])
    0x0ea9 => { Name => 'LCDHistLUT3',  Binary => 1 }, #4 (rational64s[57])
    0x0eaa => { Name => 'LCDHistLUT4',  Binary => 1 }, #4 (rational64s[48])
    0x0eab => { Name => 'LCDHistLUT5',  Binary => 1 }, #4 (rational64s[57])
    0x0eac => { Name => 'LCDHistLUT6',  Binary => 1 }, #4 (rational64s[48])
    0x0ead => { Name => 'LCDHistLUT7',  Binary => 1 }, #4 (rational64s[48])
    0x0eae => { Name => 'LCDHistLUT8',  Binary => 1 }, #4
    0x0eaf => { Name => 'LCDHistLUT9',  Binary => 1 }, #4
    0x0eb0 => 'LCDLinearClipValue', #4
    0x0ece => 'LCDStepYvalues', #4 (int8u[10])
    0x0ecf => 'LCDStepYvaluesChickFix', #4 (int8u[10])
    0x0ed0 => 'LCDStepYvaluesMarvin', #4 (int8u[10])
    0x0ed8 => { Name => 'InterpolationCoefficients', Binary => 1 }, #4 (int16s[69])
    0x0ed9 => 'InterpolationCoefficients6MP', #4
    0x0eda => 'InterpolationCoefficients3MP', #4
    0x0f00 => { Name => 'NoiseReductionParametersHostNormal',  Binary => 1 }, #4 (int16u[140])
    0x0f01 => { Name => 'NoiseReductionParametersHostStrong',  Binary => 1 }, #4 (int16u[140])
    0x0f02 => { Name => 'NoiseReductionParametersHostLow',  Binary => 1 }, #4
    0x0f0a => { Name => 'MariahTextureThreshold',   Writable => 'int16u' }, #4
    0x0f0b => { Name => 'MariahMapLoThreshold',     Writable => 'int16u' }, #4
    0x0f0c => { Name => 'MariahMapHiThreshold',     Writable => 'int16u' }, #4
    0x0f0d => { Name => 'MariahChromaBlurSize',     Writable => 'int16u' }, #4
    0x0f0e => { Name => 'MariahSigmaThreshold',     Writable => 'int16u' }, #4
    0x0f0f => { Name => 'MariahThresholds',         Binary => 1 }, #4
    0x0f10 => { Name => 'MariahThresholdsNormal',   Binary => 1 }, #4 (int16u[140])
    0x0f11 => { Name => 'MariahThresholdsStrong',   Binary => 1 }, #4 (int16u[140])
    0x0f12 => { Name => 'MariahThresholdsLow',      Binary => 1 }, #4
    0x0f14 => 'KhufuLinearRedMixingCoefficient', #4
    0x0f15 => 'KhufuLinearGreenMixingCoefficient', #4
    0x0f16 => 'KhufuLinearBlueMixingCoefficient', #4
    0x0f17 => 'KhufuUSpaceC2MixingCoefficient', #4
    0x0f18 => 'KhufuSigmaGaussianWeights', #4
    0x0f19 => 'KhufuSigmaScalingFactors6MP', #4 (rational64u[6])
    0x0f1a => 'KhufuSigmaScalingFactors3MP', #4 (rational64u[6])
    0x0f1b => 'KhufuSigmaScalingFactors14MP', #4
    # 0x0f1e-0x0f27 - KhufuLinearRGBtoLogRGB(n), (for Khufu) ref 4
    # 0x0f28-0x0f31 - KhufuLogRGBtoLinearRGB(n), (for Khufu) ref 4
    0x0f32 => { Name => 'KhufuI0Thresholds',    Binary => 1 }, #4 (int32s[348])
    0x0f33 => { Name => 'KhufuI1Thresholds',    Binary => 1 }, #4 (int32s[348])
    0x0f34 => { Name => 'KhufuI2Thresholds',    Binary => 1 }, #4 (int32s[348])
    0x0f35 => { Name => 'KhufuI3Thresholds',    Binary => 1 }, #4 (int32s[348])
    0x0f36 => { Name => 'KhufuI4Thresholds',    Binary => 1 }, #4 (int32s[348])
    0x0f37 => { Name => 'KhufuI5Thresholds',    Binary => 1 }, #4 (int32s[348])
    0x0f3c => { Name => 'CondadoDayBVThresh',   Writable => 'int16u' }, #4
    0x0f3d => { Name => 'CondadoNeuRange',      Writable => 'int16u' }, #4
    0x0f3e => { Name => 'CondadoBVFactor',      Writable => 'int16s' }, #4
    0x0f3f => { Name => 'CondadoIllFactor',     Writable => 'int16s' }, #4
    0x0f40 => { Name => 'CondadoTunThresh',     Writable => 'int16s' }, #4
    0x0f41 => { Name => 'CondadoFluThresh',     Writable => 'int16s' }, #4
    0x0f42 => { Name => 'CondadoDayOffsets',    Writable => 'int16s', Count => 2 }, #4
    0x0f43 => { Name => 'CondadoTunOffsets',    Writable => 'int16s', Count => 2 }, #4
    0x0f44 => { Name => 'CondadoFluOffsets',    Writable => 'int16s', Count => 2 }, #4
    0x0f5a => 'ERIMMToCRGB0Spline', #4 (rational64s[33])
    0x0f5b => 'ERIMMToCRGB1Spline', #4 (rational64s[36])
    0x0f5c => 'ERIMMToCRGB2Spline', #4 (rational64s[33])
    0x0f5d => 'ERIMMToCRGB3Spline', #4 (rational64s[33])
    0x0f5e => 'ERIMMToCRGB4Spline', #4 (rational64s[33])
    0x0f5f => 'ERIMMToCRGB5Spline', #4 (rational64s[33])
    0x0f60 => 'ERIMMToCRGB6Spline', #4 (rational64s[33])
    0x0f61 => 'ERIMMToCRGB7Spline', #4 (rational64s[33])
    0x0f62 => 'ERIMMToCRGB8Spline', #4
    0x0f63 => 'ERIMMToCRGB9Spline', #4
    0x0f64 => 'CRGBToERIMM0Spline', #4 (rational64s[27])
    0x0f65 => 'CRGBToERIMM1Spline', #4 (rational64s[54])
    0x0f66 => 'CRGBToERIMM2Spline', #4 (rational64s[27])
    0x0f67 => 'CRGBToERIMM3Spline', #4 (rational64s[54])
    0x0f68 => 'CRGBToERIMM4Spline', #4 (rational64s[27])
    0x0f69 => 'CRGBToERIMM5Spline', #4 (rational64s[54])
    0x0f6a => 'CRGBToERIMM6Spline', #4 (rational64s[27])
    0x0f6b => 'CRGBToERIMM7Spline', #4 (rational64s[27])
    0x0f6c => 'CRGBToERIMM8Spline', #4
    0x0f6d => 'CRGBToERIMM9Spline', #4
    0x0f6e => 'ERIMMNonLinearitySpline', #4 (rational64s[42])
    0x0f6f => 'Delta12To8Spline', #4 (rational64s[12])
    0x0f70 => 'Delta8To12Spline', #4 (rational64s[12])
    0x0f71 => 'InverseMonitorMatrix', #4 (rational64s[9])
    0x0f72 => { Name => 'NifNonlinearityExt', Binary => 1 }, #4 (int16s[8000])
    0x0f73 => { Name => 'InvNifNonLinearity', Binary => 1 }, #4 (int16u[256])
    0x0f74 => 'RIMM13ToERIMM12Spline', #4 (rational64s[51])
    0x0f78 => 'ToneScale0Spline', #4 (rational64s[57])
    0x0f79 => 'ToneScale1Spline', #4 (rational64s[51])
    0x0f7a => 'ToneScale2Spline', #4 (rational64s[57])
    0x0f7b => 'ToneScale3Spline', #4 (rational64s[51])
    0x0f7c => 'ToneScale4Spline', #4 (rational64s[57])
    0x0f7d => 'ToneScale5Spline', #4 (rational64s[51])
    0x0f7e => 'ToneScale6Spline', #4 (rational64s[57])
    0x0f7f => 'ToneScale7Spline', #4 (rational64s[57])
    0x0f80 => 'ToneScale8Spline', #4
    0x0f81 => 'ToneScale9Spline', #4
    0x0f82 => 'ERIMMToneScale0Spline', #4 (rational64s[60])
    0x0f83 => 'ERIMMToneScale1Spline', #4 (rational64s[54])
    0x0f84 => 'ERIMMToneScale2Spline', #4 (rational64s[60])
    0x0f85 => 'ERIMMToneScale3Spline', #4 (rational64s[54])
    0x0f86 => 'ERIMMToneScale4Spline', #4 (rational64s[60])
    0x0f87 => 'ERIMMToneScale5Spline', #4 (rational64s[54])
    0x0f88 => 'ERIMMToneScale6Spline', #4 (rational64s[60])
    0x0f89 => 'ERIMMToneScale7Spline', #4 (rational64s[60])
    0x0f8a => 'ERIMMToneScale8Spline', #4
    0x0f8b => 'ERIMMToneScale9Spline', #4
    0x0f8c => 'RIMMToCRGB0Spline', #4 (rational64s[66])
    0x0f8d => 'RIMMToCRGB1Spline', #4 (rational64s[84])
    0x0f8e => 'RIMMToCRGB2Spline', #4 (rational64s[66])
    0x0f8f => 'RIMMToCRGB3Spline', #4 (rational64s[84])
    0x0f90 => 'RIMMToCRGB4Spline', #4 (rational64s[66])
    0x0f91 => 'RIMMToCRGB5Spline', #4 (rational64s[84])
    0x0f92 => 'RIMMToCRGB6Spline', #4 (rational64s[66])
    0x0f93 => 'RIMMToCRGB7Spline', #4 (rational64s[66])
    0x0f94 => 'RIMMToCRGB8Spline', #4
    0x0f95 => 'RIMMToCRGB9Spline', #4
    0x0fa0 => 'QTableLarge25Pct', #4
    0x0fa1 => 'QTableMedium25Pct', #4
    0x0fa2 => 'QTableSmall25Pct', #4
    0x1130 => 'NoiseReductionKernel', #4 (Noise filter kernel.  No longer needed)
    0x1388 => 'UserMetaData', #4 (undef[0])
    0x1389 => { Name => 'InputProfile',     Writable => 'undef', Binary => 1 }, #IB ("SourceProfile", ref 4)
    0x138a => { Name => 'KodakLookProfile', Writable => 'undef', Binary => 1 }, #IB ("LookProfile", ref 4)
    0x138b => { Name => 'OutputProfile',    Writable => 'undef', Binary => 1 }, #IB ("DestinationProfile", ref 4)
    0x1390 => { Name => 'SourceProfilePrefix',  Writable => 'string' }, #4 (eg. 'DCSProSLRn')
    0x1391 => { Name => 'ToneCurveProfileName', Writable => 'string' }, #4
    0x1392 => { Name => 'InputProfile', SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' } }, #4
    0x1393 => { Name => 'ProcessParametersV2',  Binary => 1 }, #4 (Used by the SDK, Firmware should not use!)
    0x1394 => 'ReservedBlob2', #4
    0x1395 => 'ReservedBlob3', #4
    0x1396 => 'ReservedBlob4', #4
    0x1397 => 'ReservedBlob5', #4
    0x1398 => 'ReservedBlob6', #4
    0x1399 => 'ReservedBlob7', #4
    0x139a => 'ReservedBlob8', #4
    0x139b => 'ReservedBlob9', #4
    0x1770 => { Name => 'ScriptVersion',    Writable => 'int32u' }, #4
    0x177a => 'ImagerTimingData', #4
    0x1784 => { Name => 'ISO',              Writable => 'int32u' }, #3 ("NsecPerIcCode", ref 4)
    0x17a2 => 'Scav11Cols', #4
    0x17a3 => 'Scav12Cols', #4
    0x17a4 => 'Scav21Cols', #4
    0x17a5 => 'Scav22Cols', #4
    0x17a6 => 'ActiveCTEMonitor1Cols', #4
    0x17a7 => 'ActiveCTEMonitor2Cols', #4
    0x17a8 => 'ActiveCTEMonitorRows', #4
    0x17a9 => 'ActiveBuf1Cols', #4
    0x17aa => 'ActiveBuf2Cols', #4
    0x17ab => 'ActiveBuf1Rows', #4
    0x17ac => 'ActiveBuf2Rows', #4
    0x17c0 => 'HRNoiseLines', #4
    0x17c1 => 'RNoiseLines', #4
    0x17c2 => 'ANoiseLines', #4
    0x17d4 => { Name => 'ImagerCols',   Writable => 'int16u' }, #4
    0x17de => { Name => 'ImagerRows',   Writable => 'int16u' }, #4
    0x17e8 => { Name => 'PartialActiveCols1',   Writable => 'int32u' }, #4
    0x17f2 => { Name => 'PartialActiveCols2',   Writable => 'int32u' }, #4
    0x17fc => { Name => 'PartialActiveRows1',   Writable => 'int32u' }, #4
    0x1806 => { Name => 'PartialActiveRows2',   Writable => 'int32u' }, #4
    0x1810 => { Name => 'ElectricalBlackColumns',Writable=> 'int32u' }, #4
    0x181a => { Name => 'ResetBlackSegRows',    Writable => 'int32u' }, #4
    0x1838 => { Name => 'CaptureWidthNormal',   Writable => 'int32u' }, #4
    0x1839 => { Name => 'CaptureHeightNormal',  Writable => 'int32u' }, #4
    0x183a => 'CaptureWidthResetBlackSegNormal', #4
    0x183b => 'CaptureHeightResetBlackSegNormal', #4
    0x183c => 'DarkRefOffsetNormal', #4
    0x1842 => { Name => 'CaptureWidthTest',     Writable => 'int32u' }, #4
    0x1843 => 'CaptureHeightTest', #4
    0x1844 => 'CaptureWidthResetBlackSegTest', #4
    0x1845 => 'CaptureHeightResetBlackSegTest', #4
    0x1846 => 'DarkRefOffsetTest', #4
    0x184c => { Name => 'ImageSegmentStartLine',Writable => 'int32u' }, #4
    0x184d => { Name => 'ImageSegmentLines',    Writable => 'int32u' }, #4
    0x184e => { Name => 'SkipLineTime',         Writable => 'int32u' }, #4
    0x1860 => { Name => 'FastResetLineTime',    Writable => 'int32u' }, #4
    0x186a => { Name => 'NormalLineTime',       Writable => 'int32u' }, #4
    0x1874 => { Name => 'MinIntegrationRows',   Writable => 'int32u' }, #4
    0x187e => { Name => 'PreReadFastResetCount',Writable => 'int32u' }, #4
    0x1888 => { Name => 'TransferTimeNormal',   Writable => 'int32u' }, #4
    0x1889 => { Name => 'TransferTimeTest',     Writable => 'int32u' }, #4
    0x188a => { Name => 'QuietTime',            Writable => 'int32u' }, #4
    0x189c => { Name => 'OverClockCols',        Writable => 'int16u' }, #4
    0x18a6 => { Name => 'H2ResetBlackPixels',   Writable => 'int32u' }, #4
    0x18b0 => { Name => 'H3ResetBlackPixels',   Writable => 'int32u' }, #4
    0x18ba => { Name => 'BlackAcquireRows',     Writable => 'int32u' }, #4
    0x18c4 => { Name => 'OverClockRows',        Writable => 'int16u' }, #4
    0x18ce => { Name => 'H3ResetBlackColumns',  Writable => 'int32u' }, #4
    0x18d8 => { Name => 'DarkBlackSegRows',     Writable => 'int32u' }, #4
    0x1900 => 'CrossbarEnable', #4
    0x1901 => { Name => 'FifoenOnePixelDelay',  Writable => 'int32u' }, #4
    0x1902 => { Name => 'ReadoutTypeRequested', Writable => 'int32u' }, #4
    0x1903 => { Name => 'ReadoutTypeActual',    Writable => 'int32u' }, #4
    0x190a => { Name => 'OffsetDacValue',       Writable => 'int32u' }, #4
    0x1914 => { Name => 'TempAmpGainX100',      Writable => 'int32u' }, #4
    0x191e => { Name => 'VarrayDacNominalValues',Writable=> 'int32u', Count => 3 }, #4
    0x1928 => 'VddimDacNominalValues', #4
    0x1964 => { Name => 'C14Configuration',     Writable => 'int32u' }, #4
    0x196e => { Name => 'TDA1Offset',           Writable => 'int32u', Count => 3 }, #4
    0x196f => { Name => 'TDA1Bandwidth',        Writable => 'int32u' }, #4
    0x1970 => { Name => 'TDA1Gain',             Writable => 'int32u', Count => 3 }, #4
    0x1971 => { Name => 'TDA1EdgePolarity',     Writable => 'int32u' }, #4
    0x1978 => { Name => 'TDA2Offset',           Writable => 'int32u', Count => 3 }, #4
    0x1979 => { Name => 'TDA2Bandwidth',        Writable => 'int32u' }, #4
    0x197a => { Name => 'TDA2Gain',             Writable => 'int32u', Count => 3 }, #4
    0x197b => { Name => 'TDA2EdgePolarity',     Writable => 'int32u' }, #4
    0x1982 => { Name => 'TDA3Offset',           Writable => 'int32u', Count => 3 }, #4
    0x1983 => { Name => 'TDA3Bandwidth',        Writable => 'int32u' }, #4
    0x1984 => { Name => 'TDA3Gain',             Writable => 'int32u', Count => 3 }, #4
    0x1985 => { Name => 'TDA3EdgePolarity',     Writable => 'int32u' }, #4
    0x198c => { Name => 'TDA4Offset',           Writable => 'int32u', Count => 3 }, #4
    0x198d => { Name => 'TDA4Bandwidth',        Writable => 'int32u' }, #4
    0x198e => { Name => 'TDA4Gain',             Writable => 'int32u', Count => 3 }, #4
    0x198f => { Name => 'TDA4EdgePolarity',     Writable => 'int32u' }, #4
    0xfde8 => { Name => 'ComLenBlkSize',        Writable => 'int16u' }, #4
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
    tima => {
        Name => 'Duration',
        Format => 'int32u',
        Priority => 0,  # (only integer seconds)
        PrintConv => 'ConvertDuration($val)',
    },
   'ver '=> { Name => 'KodakVersion' },
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
