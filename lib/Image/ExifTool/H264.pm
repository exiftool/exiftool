#------------------------------------------------------------------------------
# File:         H264.pm
#
# Description:  Read meta information from H.264 video
#
# Revisions:    2010/01/31 - P. Harvey Created
#
# References:   1) http://www.itu.int/rec/T-REC-H.264/e (T-REC-H.264-200305-S!!PDF-E.pdf)
#               2) http://miffteevee.co.uk/documentation/development/H264Parser_8cpp-source.html
#               3) http://ffmpeg.org/
#               4) US Patent 2009/0052875 A1
#               5) European Patent (EP2 051 528A1) application no. 07792522.0 filed 08.08.2007
#               6) Dave Nicholson private communication
#               7) http://www.freepatentsonline.com/20050076039.pdf
#               8) Michael Reitinger private communication (RX100)
#
# Glossary:     RBSP = Raw Byte Sequence Payload
#------------------------------------------------------------------------------

package Image::ExifTool::H264;

use strict;
use vars qw($VERSION %convMake);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '1.17';

sub ProcessSEI($$);

my $parsePictureTiming; # flag to enable parsing of picture timing information (test only)

# lookup for camera manufacturer name
%convMake = (
    0x0103 => 'Panasonic',
    0x0108 => 'Sony',
    0x1011 => 'Canon',
    0x1104 => 'JVC', #Rob Lewis
);

# information extracted from H.264 video streams
%Image::ExifTool::H264::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_ID => 1 },
    NOTES => q{
        Tags extracted from H.264 video streams.  The metadata for AVCHD videos is
        stored in this stream.
    },
    ImageWidth => { },
    ImageHeight => { },
    MDPM => { SubDirectory => { TagTable => 'Image::ExifTool::H264::MDPM' } },
);

# H.264 Supplemental Enhancement Information User Data (ref PH/4)
%Image::ExifTool::H264::MDPM = (
    GROUPS => { 2 => 'Camera' },
    PROCESS_PROC => \&ProcessSEI,
    TAG_PREFIX => 'MDPM',
    NOTES => q{
        The following tags are decoded from the Modified Digital Video Pack Metadata
        (MDPM) of the unregistered user data with UUID
        17ee8c60f84d11d98cd60800200c9a66 in the H.264 Supplemental Enhancement
        Information (SEI).  I<[Yes, this description is confusing, but nothing
        compared to the challenge of actually decoding the data!]>  This information
        may exist at regular intervals through the entire video, but only the first
        occurrence is extracted unless the L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> (-ee) option is used (in
        which case subsequent occurrences are extracted as sub-documents).
    },
    # (Note: all these are explained in IEC 61834-4, but it costs money so it is useless to me)
    # 0x00 - ControlCassetteID (ref 7)
    # 0x01 - ControlTapeLength (ref 7)
    # 0x02 - ControlTimerActDate (ref 7)
    # 0x03 - ControlTimerACS_S_S (ref 7)
    # 0x04-0x05 - ControlPR_StartPoint (ref 7)
    # 0x06 - ControlTagIDNoGenre (ref 7)
    # 0x07 - ControlTopicPageHeader (ref 7)
    # 0x08 - ControlTextHeader (ref 7)
    # 0x09 - ControlText (ref 7)
    # 0x0a-0x0b - ControlTag (ref 7)
    # 0x0c - ControlTeletextInfo (ref 7)
    # 0x0d - ControlKey (ref 7)
    # 0x0e-0x0f - ControlZoneEnd (ref 7)
    # 0x10 - TitleTotalTime (ref 7)
    # 0x11 - TitleRemainTime (ref 7)
    # 0x12 - TitleChapterTotalNo (ref 7)
    0x13 => {
        Name => 'TimeCode',
        Notes => 'hours:minutes:seconds:frames',
        ValueConv => 'sprintf("%.2x:%.2x:%.2x:%.2x",reverse unpack("C*",$val))',
    },
    # 0x14 - TitleBinaryGroup
    # 0x15 - TitleCassetteNo (ref 7)
    # 0x16-0x17 - TitleSoftID (ref 7)
    # (0x18,0x19 listed as TitleTextHeader/TitleText by ref 7)
    0x18 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Notes => 'combined with tag 0x19',
        Combine => 1,   # the next tag (0x19) contains the rest of the date
        # first byte is timezone information:
        #   0x80 - unused
        #   0x40 - DST flag
        #   0x20 - TimeZoneSign
        #   0x1e - TimeZoneValue
        #   0x01 - half-hour flag
        ValueConv => q{
            my ($tz, @a) = unpack('C*',$val);
            return sprintf('%.2x%.2x:%.2x:%.2x %.2x:%.2x:%.2x%s%.2d:%s%s', @a,
                           $tz & 0x20 ? '-' : '+', ($tz >> 1) & 0x0f,
                           $tz & 0x01 ? '30' : '00',
                           $tz & 0x40 ? ' DST' : '');
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # 0x1a-0x1b - TitleStart (ref 7)
    # 0x1c-0x1d - TitleReelID (ref 7)
    # 0x1e-0x1f - TitleEnd (ref 7)
    # 0x20 - ChapterTotalTime (ref 7)
    # 0x42 - ProgramRecDTime (ref 7)
    # 0x50/0x60 - (AAUX/VAUX)Source (ref 7)
    # 0x51/0x61 - (AAUX/VAUX)SourceControl (ref 7)
    # 0x52/0x62 - (AAUX/VAUX)RecDate (ref 7)
    # 0x53/0x63 - (AAUX/VAUX)RecTime (ref 7)
    # 0x54/0x64 - (AAUX/VAUX)BinaryGroup (ref 7)
    # 0x55/0x65 - (AAUX/VAUX)ClosedCaption (ref 7)
    # 0x56/0x66 - (AAUX/VAUX)TR (ref 7)
    0x70 => { # ConsumerCamera1
        Name => 'Camera1',
        SubDirectory => { TagTable => 'Image::ExifTool::H264::Camera1' },
    },
    0x71 => { # ConsumerCamera2
        Name => 'Camera2',
        SubDirectory => { TagTable => 'Image::ExifTool::H264::Camera2' },
    },
    # 0x73 Lens - val: 0x75ffffd3,0x0effffd3,0x59ffffd3,0x79ffffd3,0xffffffd3...
    # 0x74 Gain
    # 0x75 Pedestal
    # 0x76 Gamma
    # 0x77 Detail
    # 0x7b CameraPreset
    # 0x7c Flare
    # 0x7d Shading
    # 0x7e Knee
    0x7f => { # Shutter
        Name => 'Shutter',
        SubDirectory => {
            TagTable => 'Image::ExifTool::H264::Shutter',
            ByteOrder => 'LittleEndian', # weird
        },
    },
    0xa0 => {
        Name => 'ExposureTime',
        Format => 'rational32u',
        Groups => { 2 => 'Image' },
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0xa1 => {
        Name => 'FNumber',
        Format => 'rational32u',
        Groups => { 2 => 'Image' },
    },
    0xa2 => {
        Name => 'ExposureProgram',
        Format => 'int32u', # (guess)
        PrintConv => {
            0 => 'Not Defined',
            1 => 'Manual',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Creative (Slow speed)',
            6 => 'Action (High speed)',
            7 => 'Portrait',
            8 => 'Landscape',
        },
    },
    0xa3 => {
        Name => 'BrightnessValue',
        Format => 'rational32s',
        Groups => { 2 => 'Image' },
    },
    0xa4 => {
        Name => 'ExposureCompensation',
        Format => 'rational32s',
        Groups => { 2 => 'Image' },
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    0xa5 => {
        Name => 'MaxApertureValue',
        Format => 'rational32u',
        ValueConv => '2 ** ($val / 2)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0xa6 => {
        Name => 'Flash',
        Format => 'int32u', # (guess)
        Flags => 'PrintHex',
        SeparateTable => 'EXIF Flash',
        PrintConv =>  \%Image::ExifTool::Exif::flash,
    },
    0xa7 => {
        Name => 'CustomRendered',
        Format => 'int32u', # (guess)
        Groups => { 2 => 'Image' },
        PrintConv => {
            0 => 'Normal',
            1 => 'Custom',
        },
    },
    0xa8 => {
        Name => 'WhiteBalance',
        Format => 'int32u', # (guess)
        Priority => 0,
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0xa9 => {
        Name => 'FocalLengthIn35mmFormat',
        Format => 'rational32u',
        PrintConv => '"$val mm"',
    },
    0xaa => {
        Name => 'SceneCaptureType',
        Format => 'int32u', # (guess)
        PrintConv => {
            0 => 'Standard',
            1 => 'Landscape',
            2 => 'Portrait',
            3 => 'Night',
        },
    },
    # 0xab-0xaf ExifOption
    0xb0 => {
        Name => 'GPSVersionID',
        Format => 'int8u',
        Count => 4,
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => '$val =~ tr/ /./; $val',
    },
    0xb1 => {
        Name => 'GPSLatitudeRef',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0xb2 => {
        Name => 'GPSLatitude',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        Notes => 'combined with tags 0xb3 and 0xb4',
        Combine => 2,   # combine the next 2 tags (0xb2=deg, 0xb3=min, 0xb4=sec)
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    0xb5 => {
        Name => 'GPSLongitudeRef',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0xb6 => {
        Name => 'GPSLongitude',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        Combine => 2,   # combine the next 2 tags (0xb6=deg, 0xb7=min, 0xb8=sec)
        Notes => 'combined with tags 0xb7 and 0xb8',
        ValueConv => 'Image::ExifTool::GPS::ToDegrees($val)',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    0xb9 => {
        Name => 'GPSAltitudeRef',
        Format => 'int32u', # (guess)
        Groups => { 1 => 'GPS', 2 => 'Location' },
        ValueConv => '$val ? 1 : 0', # because I'm not sure about the Format
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    0xba => {
        Name => 'GPSAltitude',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0xbb => {
        Name => 'GPSTimeStamp',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Time' },
        Combine => 2,    # the next tags (0xbc/0xbd) contain the minutes/seconds
        Notes => 'combined with tags 0xbc and 0xbd',
        ValueConv => 'Image::ExifTool::GPS::ConvertTimeStamp($val)',
        PrintConv => 'Image::ExifTool::GPS::PrintTimeStamp($val)',
    },
    0xbe => {
        Name => 'GPSStatus',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            A => 'Measurement Active',
            V => 'Measurement Void',
        },
    },
    0xbf => {
        Name => 'GPSMeasureMode',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0xc0 => {
        Name => 'GPSDOP',
        Description => 'GPS Dilution Of Precision',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0xc1 => {
        Name => 'GPSSpeedRef',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    0xc2 => {
        Name => 'GPSSpeed',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0xc3 => {
        Name => 'GPSTrackRef',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0xc4 => {
        Name => 'GPSTrack',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0xc5 => {
        Name => 'GPSImgDirectionRef',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0xc6 => {
        Name => 'GPSImgDirection',
        Format => 'rational32u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0xc7 => {
        Name => 'GPSMapDatum',
        Format => 'string',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        Combine => 1,    # the next tag (0xc8) contains the rest of the string
        Notes => 'combined with tag 0xc8',
    },
    # 0xc9-0xcf - GPSOption
    0xe0 => {
        Name => 'MakeModel',
        SubDirectory => { TagTable => 'Image::ExifTool::H264::MakeModel' },
    },
    # 0xe1-0xef - MakerOption
    # 0xe1 - val: 0x01000670,0x01000678,0x06ffffff,0x01ffffff,0x01000020,0x01000400...
    # 0xe2-0xe8 - val: 0x00000000 in many samples
    0xe1 => { #6
        Name => 'RecInfo',
        Condition => '$$self{Make} eq "Canon"',
        Notes => 'Canon only',
        SubDirectory => { TagTable => 'Image::ExifTool::H264::RecInfo' },
    },
    0xe4 => { #PH
        Name => 'Model',
        Condition => '$$self{Make} eq "Sony"', # (possibly also Canon models?)
        Description => 'Camera Model Name',
        Notes => 'Sony cameras only, combined with tags 0xe5 and 0xe6',
        Format => 'string',
        Combine => 2, # (not sure about 0xe6, but include it just in case)
        RawConv => '$val eq "" ? undef : $val',
    },
    0xee => { #6 (HFS200)
        Name => 'FrameInfo',
        Condition => '$$self{Make} eq "Canon"',
        Notes => 'Canon only',
        SubDirectory => { TagTable => 'Image::ExifTool::H264::FrameInfo' },
    },
);

# ConsumerCamera1 information (ref PH)
%Image::ExifTool::H264::Camera1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Camera' },
    TAG_PREFIX => 'Camera1',
    PRINT_CONV => 'sprintf("0x%.2x",$val)',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'ApertureSetting',
        PrintHex => 1,
        PrintConv => {
            0xff => 'Auto',
            0xfe => 'Closed',
            OTHER => sub { sprintf('%.1f', 2 ** (($_[0] & 0x3f) / 8)) },
        },
    },
    1 => {
        Name => 'Gain',
        Mask => 0x0f,
        # (0x0f would translate to 42 dB, but this value is used by the Sony
        #  HXR-NX5U for any out-of-range value such as -6 dB or "hyper gain" - PH)
        ValueConv => '($val - 1) * 3',
        PrintConv => '$val==42 ? "Out of range" : "$val dB"',
    },
    1.1 => {
        Name => 'ExposureProgram',
        Mask => 0xf0,
        ValueConv => '$val == 15 ? undef : $val',
        PrintConv => {
            0 => 'Program AE',
            1 => 'Gain', #?
            2 => 'Shutter speed priority AE',
            3 => 'Aperture-priority AE',
            4 => 'Manual',
        },
    },
    2.1 => {
        Name => 'WhiteBalance',
        Mask => 0xe0,
        ValueConv => '$val == 7 ? undef : $val',
        PrintConv => {
            0 => 'Auto',
            1 => 'Hold',
            2 => '1-Push',
            3 => 'Daylight',
        },
    },
    3 => {
        Name => 'Focus',
        ValueConv => '$val == 0xff ? undef : $val',
        PrintConv => q{
            my $foc = ($val & 0x7e) / (($val & 0x01) ? 40 : 400);
            return(($val & 0x80 ? 'Manual' : 'Auto') . " ($foc)");
        },
    },
);

# ConsumerCamera2 information (ref PH)
%Image::ExifTool::H264::Camera2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Camera' },
    TAG_PREFIX => 'Camera2',
    PRINT_CONV => 'sprintf("0x%.2x",$val)',
    FIRST_ENTRY => 0,
    1 => {
        Name => 'ImageStabilization',
        PrintHex => 1,
        PrintConv => {
            0 => 'Off',
            0x3f => 'On (0x3f)', #8
            0xbf => 'Off (0xbf)', #8
            0xff => 'n/a',
            OTHER => sub {
                my $val = shift;
                sprintf("%s (0x%.2x)", $val & 0x10 ? "On" : "Off", $val);
            },
        },
    },
);

# camera info 0x7f (ref PH)
%Image::ExifTool::H264::Shutter = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    TAG_PREFIX => 'Shutter',
    PRINT_CONV => 'sprintf("0x%.2x",$val)',
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    1.1 => { #6
        Name => 'ExposureTime',
        Mask => 0x7fff, # (what is bit 0x8000 for?)
        RawConv => '$val == 0x7fff ? undef : $val', #7
        ValueConv => '$val / 28125', #PH (Vixia HF G30, ref forum5588) (was $val/33640 until 9.49)
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
);

# camera info 0xe0 (ref PH)
%Image::ExifTool::H264::MakeModel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'Make',
        PrintHex => 1,
        RawConv => '$$self{Make} = ($Image::ExifTool::H264::convMake{$val} || "Unknown"); $val',
        PrintConv => \%convMake,
    },
    # 1 => ModelIDCode according to ref 4/5 (I think not - PH)
    # 1 => { Name => 'ModelIDCode', PrintConv => 'sprintf("%.4x",$val)' },
    # vals: 0x0313 - various Pansonic HDC models
    #       0x0345 - Panasonic HC-V7272
    #       0x0414 - Panasonic AG-AF100
    #       0x0591 - various Panasonic DMC models
    #       0x0802 - Panasonic DMC-TZ60 with GPS information off
    #       0x0803 - Panasonic DMC-TZ60 with GPS information on
    #       0x3001 - various Sony DSC, HDR, NEX and SLT models
    #       0x3003 - various Sony DSC models
    #       0x3100 - various Sony DSC, ILCE, NEX and SLT models
    #       0x1000 - Sony HDR-UX1
    #       0x2000 - Canon HF100 (60i)
    #       0x3000 - Canon HF100 (30p)
    #       0x3101 - Canon HFM300 (PH, all qualities and frame rates)
    #       0x3102 - Canon HFS200
    #       0x4300 - Canon HFG30
);

# camera info 0xe1 (ref 6)
%Image::ExifTool::H264::RecInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Camera' },
    FORMAT => 'int8u',
    NOTES => 'Recording information stored by some Canon video cameras.',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'RecordingMode',
        PrintConv => {
            0x02 => 'XP+', # High Quality 12 Mbps
            0x04 => 'SP',  # Standard Play 7 Mbps
            0x05 => 'LP',  # Long Play 5 Mbps
            0x06 => 'FXP', # High Quality 17 Mbps
            0x07 => 'MXP', # High Quality 24 Mbps
        },
    },
);

# camera info 0xee (ref 6)
%Image::ExifTool::H264::FrameInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int8u',
    NOTES => 'Frame rate information stored by some Canon video cameras.',
    FIRST_ENTRY => 0,
    0 => 'CaptureFrameRate',
    1 => 'VideoFrameRate',
    # 2 - 8=60i, 10=PF30, 74=PF24 (PH, HFM300)
);

#==============================================================================
# Bitstream functions (used for H264 video)
#
# Member variables:
#   Mask    = mask for next bit to read (0 when all data has been read)
#   Pos     = byte offset of next word to read
#   Word    = current data word
#   Len     = total data length in bytes
#   DataPt  = data pointer
#..............................................................................

#------------------------------------------------------------------------------
# Read next word from bitstream
# Inputs: 0) BitStream ref
# Returns: true if there is more data (and updates
#          Mask, Pos and Word for first bit in next word)
sub ReadNextWord($)
{
    my $bstr = shift;
    my $pos = $$bstr{Pos};
    if ($pos + 4 <= $$bstr{Len}) {
        $$bstr{Word} = unpack("x$pos N", ${$$bstr{DataPt}});
        $$bstr{Mask} = 0x80000000;
        $$bstr{Pos} += 4;
    } elsif ($pos < $$bstr{Len}) {
        my @bytes = unpack("x$pos C*", ${$$bstr{DataPt}});
        my ($word, $mask) = (shift(@bytes), 0x80);
        while (@bytes) {
            $word = ($word << 8) | shift(@bytes);
            $mask <<= 8;
        }
        $$bstr{Word} = $word;
        $$bstr{Mask} = $mask;
        $$bstr{Pos} = $$bstr{Len};
    } else {
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Create a new BitStream object
# Inputs: 0) data ref
# Returns: BitStream ref, or null if data is empty
sub NewBitStream($)
{
    my $dataPt = shift;
    my $bstr = {
        DataPt => $dataPt,
        Len    => length($$dataPt),
        Pos    => 0,
        Mask   => 0,
    };
    ReadNextWord($bstr) or undef $bstr;
    return $bstr;
}

#------------------------------------------------------------------------------
# Get number of bits remaining in bit stream
# Inputs: 0) BitStream ref
# Returns: number of bits remaining
sub BitsLeft($)
{
    my $bstr = shift;
    my $bits = 0;
    my $mask = $$bstr{Mask};
    while ($mask) {
        ++$bits;
        $mask >>= 1;
    }
    return $bits + 8 * ($$bstr{Len} - $$bstr{Pos});
}

#------------------------------------------------------------------------------
# Get integer from bitstream
# Inputs: 0) BitStream ref, 1) number of bits
# Returns: integer (and increments position in bitstream)
sub GetIntN($$)
{
    my ($bstr, $bits) = @_;
    my $val = 0;
    while ($bits--) {
        $val <<= 1;
        ++$val if $$bstr{Mask} & $$bstr{Word};
        $$bstr{Mask} >>= 1 and next;
        ReadNextWord($bstr) or last;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Get Exp-Golomb integer from bitstream
# Inputs: 0) BitStream ref
# Returns: integer (and increments position in bitstream)
sub GetGolomb($)
{
    my $bstr = shift;
    # first, count the number of zero bits to get the integer bit width
    my $count = 0;
    until ($$bstr{Mask} & $$bstr{Word}) {
        ++$count;
        $$bstr{Mask} >>= 1 and next;
        ReadNextWord($bstr) or last;
    }
    # then return the adjusted integer
    return GetIntN($bstr, $count + 1) - 1;
}

#------------------------------------------------------------------------------
# Get signed Exp-Golomb integer from bitstream
# Inputs: 0) BitStream ref
# Returns: integer (and increments position in bitstream)
sub GetGolombS($)
{
    my $bstr = shift;
    my $val = GetGolomb($bstr) + 1;
    return ($val & 1) ? -($val >> 1) : ($val >> 1);
}

# end bitstream functions
#==============================================================================

#------------------------------------------------------------------------------
# Decode H.264 scaling matrices
# Inputs: 0) BitStream ref
# Reference: http://ffmpeg.org/
sub DecodeScalingMatrices($)
{
    my $bstr = shift;
    if (GetIntN($bstr, 1)) {
        my ($i, $j);
        for ($i=0; $i<8; ++$i) {
            my $size = $i<6 ? 16 : 64;
            next unless GetIntN($bstr, 1);
            my ($last, $next) = (8, 8);
            for ($j=0; $j<$size; ++$j) {
                $next = ($last + GetGolombS($bstr)) & 0xff if $next;
                last unless $j or $next;
            }
        }
    }
}

#------------------------------------------------------------------------------
# Parse H.264 sequence parameter set RBSP (ref 1)
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) data ref
# Notes: All this just to get the image size!
sub ParseSeqParamSet($$$)
{
    my ($et, $tagTablePtr, $dataPt) = @_;
    # initialize our bitstream object
    my $bstr = NewBitStream($dataPt) or return;
    my ($t, $i, $j, $n);
    # the messy nature of H.264 encoding makes it difficult to use
    # data-driven structure parsing, so I code it explicitly (yuck!)
    $t = GetIntN($bstr, 8);         # profile_idc
    GetIntN($bstr, 16);             # constraints and level_idc
    GetGolomb($bstr);               # seq_parameter_set_id
    if ($t >= 100) { # (ref b)
        $t = GetGolomb($bstr);      # chroma_format_idc
        if ($t == 3) {
            GetIntN($bstr, 1);      # separate_colour_plane_flag
            $n = 12;
        } else {
            $n = 8;
        }
        GetGolomb($bstr);           # bit_depth_luma_minus8
        GetGolomb($bstr);           # bit_depth_chroma_minus8
        GetIntN($bstr, 1);          # qpprime_y_zero_transform_bypass_flag
        DecodeScalingMatrices($bstr);
    }
    GetGolomb($bstr);               # log2_max_frame_num_minus4
    $t = GetGolomb($bstr);          # pic_order_cnt_type
    if ($t == 0) {
        GetGolomb($bstr);           # log2_max_pic_order_cnt_lsb_minus4
    } elsif ($t == 1) {
        GetIntN($bstr, 1);          # delta_pic_order_always_zero_flag
        GetGolomb($bstr);           # offset_for_non_ref_pic
        GetGolomb($bstr);           # offset_for_top_to_bottom_field
        $n = GetGolomb($bstr);      # num_ref_frames_in_pic_order_cnt_cycle
        for ($i=0; $i<$n; ++$i) {
            GetGolomb($bstr);       # offset_for_ref_frame[i]
        }
    }
    GetGolomb($bstr);               # num_ref_frames
    GetIntN($bstr, 1);              # gaps_in_frame_num_value_allowed_flag
    my $w = GetGolomb($bstr);       # pic_width_in_mbs_minus1
    my $h = GetGolomb($bstr);       # pic_height_in_map_units_minus1
    my $f = GetIntN($bstr, 1);      # frame_mbs_only_flag
    $f or GetIntN($bstr, 1);        # mb_adaptive_frame_field_flag
    GetIntN($bstr, 1);              # direct_8x8_inference_flag
    # convert image size to pixels
    $w = ($w + 1) * 16;
    $h = (2 - $f) * ($h + 1) * 16;
    # account for cropping (if any)
    $t = GetIntN($bstr, 1);         # frame_cropping_flag
    if ($t) {
        my $m = 4 - $f * 2;
        $w -=  4 * GetGolomb($bstr);# frame_crop_left_offset
        $w -=  4 * GetGolomb($bstr);# frame_crop_right_offset
        $h -= $m * GetGolomb($bstr);# frame_crop_top_offset
        $h -= $m * GetGolomb($bstr);# frame_crop_bottom_offset
    }
    # quick validity checks (just in case)
    return unless $$bstr{Mask};
    if ($w>=160 and $w<=4096 and $h>=120 and $h<=3072) {
        $et->HandleTag($tagTablePtr, ImageWidth => $w);
        $et->HandleTag($tagTablePtr, ImageHeight => $h);
        # (whew! -- so much work just to get ImageSize!!)
    }
    # return now unless interested in picture timing information
    return unless $parsePictureTiming;

    # parse vui parameters if they exist
    GetIntN($bstr, 1) or return;    # vui_parameters_present_flag
    $t = GetIntN($bstr, 1);         # aspect_ratio_info_present_flag
    if ($t) {
        $t = GetIntN($bstr, 8);     # aspect_ratio_idc
        if ($t == 255) {            # Extended_SAR ?
            GetIntN($bstr, 32);     # sar_width/sar_height
        }
    }
    $t = GetIntN($bstr, 1);         # overscan_info_present_flag
    GetIntN($bstr, 1) if $t;        # overscan_appropriate_flag
    $t = GetIntN($bstr, 1);         # video_signal_type_present_flag
    if ($t) {
        GetIntN($bstr, 4);          # video_format/video_full_range_flag
        $t = GetIntN($bstr, 1);     # colour_description_present_flag
        GetIntN($bstr, 24) if $t;   # colour_primaries/transfer_characteristics/matrix_coefficients
    }
    $t = GetIntN($bstr, 1);         # chroma_loc_info_present_flag
    if ($t) {
        GetGolomb($bstr);           # chroma_sample_loc_type_top_field
        GetGolomb($bstr);           # chroma_sample_loc_type_bottom_field
    }
    $t = GetIntN($bstr, 1);         # timing_info_present_flag
    if ($t) {
        return if BitsLeft($bstr) < 65;
        $$et{VUI_units} = GetIntN($bstr, 32); # num_units_in_tick
        $$et{VUI_scale} = GetIntN($bstr, 32); # time_scale
        GetIntN($bstr, 1);          # fixed_frame_rate_flag
    }
    my $hard;
    for ($j=0; $j<2; ++$j) {
        $t = GetIntN($bstr, 1);     # nal_/vcl_hrd_parameters_present_flag
        if ($t) {
            $$et{VUI_hard} = 1;
            $hard = 1;
            $n = GetGolomb($bstr);  # cpb_cnt_minus1
            GetIntN($bstr, 8);      # bit_rate_scale/cpb_size_scale
            for ($i=0; $i<=$n; ++$i) {
                GetGolomb($bstr);   # bit_rate_value_minus1[SchedSelIdx]
                GetGolomb($bstr);   # cpb_size_value_minus1[SchedSelIdx]
                GetIntN($bstr, 1);  # cbr_flag[SchedSelIdx]
            }
            GetIntN($bstr, 5);      # initial_cpb_removal_delay_length_minus1
            $$et{VUI_clen} = GetIntN($bstr, 5); # cpb_removal_delay_length_minus1
            $$et{VUI_dlen} = GetIntN($bstr, 5); # dpb_output_delay_length_minus1
            $$et{VUI_toff} = GetIntN($bstr, 5); # time_offset_length
        }
    }
    GetIntN($bstr, 1) if $hard;     # low_delay_hrd_flag
    $$et{VUI_pic} = GetIntN($bstr, 1);    # pic_struct_present_flag
    # (don't yet decode the rest of the vui data)
}

#------------------------------------------------------------------------------
# Parse H.264 picture timing SEI message (payload type 1) (ref 1)
# Inputs: 0) ExifTool ref, 1) data ref
# Notes: this routine is for test purposes only, and not called unless the
#        $parsePictureTiming flag is set
sub ParsePictureTiming($$)
{
    my ($et, $dataPt) = @_;
    my $bstr = NewBitStream($dataPt) or return;
    my ($i, $t, $n);
    # the specification is very odd on this point: the following delays
    # exist if the VUI hardware parameters are present, or if
    # "determined by the application, by some means not specified" -- WTF??
    if ($$et{VUI_hard}) {
        GetIntN($bstr, $$et{VUI_clen} + 1);   # cpb_removal_delay
        GetIntN($bstr, $$et{VUI_dlen} + 1);   # dpb_output_delay
    }
    if ($$et{VUI_pic}) {
        $t = GetIntN($bstr, 4);     # pic_struct
        # determine NumClockTS ($n)
        $n = { 0=>1, 1=>1, 2=>1, 3=>2, 4=>2, 5=>3, 6=>3, 7=>2, 8=>3 }->{$t};
        $n or return;
        for ($i=0; $i<$n; ++$i) {
            $t = GetIntN($bstr, 1); # clock_timestamp_flag[i]
            next unless $t;
            my ($nu, $s, $m, $h, $o);
            GetIntN($bstr, 2);      # ct_type
            $nu = GetIntN($bstr, 1);# nuit_field_based_flag
            GetIntN($bstr, 5);      # counting_type
            $t = GetIntN($bstr, 1); # full_timestamp_flag
            GetIntN($bstr, 1);      # discontinuity_flag
            GetIntN($bstr, 1);      # cnt_dropped_flag
            GetIntN($bstr, 8);      # n_frames
            if ($t) {
                $s = GetIntN($bstr, 6); # seconds_value
                $m = GetIntN($bstr, 6); # minutes_value
                $h = GetIntN($bstr, 5); # hours_value
            } else {
                $t = GetIntN($bstr, 1); # seconds_flag
                if ($t) {
                    $s = GetIntN($bstr, 6); # seconds_value
                    $t = GetIntN($bstr, 1); # minutes_flag
                    if ($t) {
                        $m = GetIntN($bstr, 6); # minutes_value
                        $t = GetIntN($bstr, 1); # hours_flag
                        $h = GetIntN($bstr, 5) if $t;   # hours_value
                    }
                }
            }
            if ($$et{VUI_toff}) {
                $o = GetIntN($bstr, $$et{VUI_toff});  # time_offset
            }
            last;   # only parse the first clock timestamp found
        }
    }
}

#------------------------------------------------------------------------------
# Process H.264 Supplementary Enhancement Information (ref 1/PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 if we processed payload type 5
# Payload types:
#   0 - buffer period
#   1 - pic timing
#   2 - pan scan rect
#   3 - filler payload
#   4 - user data registered itu t t35
#   5 - user data unregistered
#   6 - recovery point
#   7 - dec ref pic marking repetition
#   8 - spare pic
#   9 - sene info
#  10 - sub seq info
#  11 - sub seq layer characteristics
#  12 - sub seq characteristics
#  13 - full frame freeze
#  14 - full frame freeze release
#  15 - full frame snapshot
#  16 - progressive refinement segment start
#  17 - progressive refinement segment end
#  18 - motion constrained slice group set
sub ProcessSEI($$)
{
    my ($et, $dirInfo) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $end = length($$dataPt);
    my $pos = 0;
    my ($type, $size, $index, $t);

    # scan through SEI payload for type 5 (the unregistered user data)
    for (;;) {
        $type = 0;
        for (;;) {
            return 0 if $pos >= $end;
            $t = Get8u($dataPt, $pos++);    # payload type
            $type += $t;
            last unless $t == 255;
        }
        return 0 if $type == 0x80;  # terminator (ref PH - maybe byte alignment bits?)
        $size = 0;
        for (;;) {
            return 0 if $pos >= $end;
            $t = Get8u($dataPt, $pos++);    # payload data length
            $size += $t;
            last unless $t == 255;
        }
        return 0 if $pos + $size > $end;
        $et->VPrint(1,"    (SEI type $type)\n");
        if ($type == 1) {                   # picture timing information
            if ($parsePictureTiming) {
                my $buff = substr($$dataPt, $pos, $size);
                ParsePictureTiming($et, $dataPt);
            }
        } elsif ($type == 5) {              # unregistered user data
            last; # exit loop to process user data now
        }
        $pos += $size;
    }

    # look for our 16-byte UUID
    # - plus "MDPM" for "ModifiedDVPackMeta"
    # - plus "GA94" for closed-caption data (currently not decoded)
    return 0 unless $size > 20 and substr($$dataPt, $pos, 20) eq
        "\x17\xee\x8c\x60\xf8\x4d\x11\xd9\x8c\xd6\x08\0\x20\x0c\x9a\x66MDPM";
#
# parse the MDPM records in the UUID 17ee8c60f84d11d98cd60800200c9a66
# unregistered user data payload (ref PH)
#
    my $tagTablePtr = GetTagTable('Image::ExifTool::H264::MDPM');
    my $oldIndent = $$et{INDENT};
    $$et{INDENT} .= '| ';
    $end = $pos + $size;    # end of payload
    $pos += 20;             # skip UUID + "MDPM"
    my $num = Get8u($dataPt, $pos++);   # get entry count
    my $lastTag = 0;
    $et->VerboseDir('MDPM', $num) if $et->Options('Verbose');
    # walk through entries in the MDPM payload
    for ($index=0; $index<$num and $pos<$end; ++$index) {
        my $tag = Get8u($dataPt, $pos);
        if ($tag <= $lastTag) { # should be in numerical order (PH)
            $et->Warn('Entries in MDPM directory are out of sequence');
            last;
        }
        $lastTag = $tag;
        my $buff = substr($$dataPt, $pos + 1, 4);
        my $from;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo) {
            # use our own print conversion for Unknown tags
            if ($$tagInfo{Unknown} and not $$tagInfo{SetPrintConv}) {
                $$tagInfo{PrintConv} = 'sprintf("0x%.8x", unpack("N", $val))';
                $$tagInfo{SetPrintConv} = 1;
            }
            # combine with next value(s) if necessary
            my $combine = $$tagTablePtr{$tag}{Combine};
            while ($combine) {
                last if $pos + 5 >= $end;
                my $t =  Get8u($dataPt, $pos + 5);
                last if $t != $lastTag + 1; # must be consecutive tag ID's
                $pos += 5;
                $buff .= substr($$dataPt, $pos + 1, 4);
                $from = $index unless defined $from;
                ++$index;
                ++$lastTag;
                --$combine;
            }
            $et->HandleTag($tagTablePtr, $tag, undef,
                TagInfo => $tagInfo,
                DataPt  => \$buff,
                Size    => length($buff),
                Index   => defined $from ? "$from-$index" : $index,
            );
        }
        $pos += 5;
    }
    $$et{INDENT} = $oldIndent;
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from H.264 video stream
# Inputs: 0) ExifTool ref, 1) data ref
# Returns: 0 = done parsing, 1 = we want to parse more of these
sub ParseH264Video($$)
{
    my ($et, $dataPt) = @_;
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my $tagTablePtr = GetTagTable('Image::ExifTool::H264::Main');
    my %parseNalUnit = ( 0x06 => 1, 0x07 => 1 );    # NAL unit types to parse
    my $foundUserData;
    my $len = length $$dataPt;
    my $pos = 0;
    while ($pos < $len) {
        my ($nextPos, $end);
        # find start of next NAL unit
        if ($$dataPt =~ /(\0{2,3}\x01)/g) {
            $nextPos = pos $$dataPt;
            $end = $nextPos - length $1;
            $pos or $pos = $nextPos, next;
        } else {
            last unless $pos;
            $nextPos = $end = $len;
        }
        last if $pos >= $len;
        # parse NAL unit from $pos to $end
        my $nal_unit_type = Get8u($dataPt, $pos);
        ++$pos;
        # check forbidden_zero_bit
        $nal_unit_type & 0x80 and $et->Warn('H264 forbidden bit error'), last;
        $nal_unit_type &= 0x1f;
        # ignore this NAL unit unless we will parse it
        $parseNalUnit{$nal_unit_type} or $verbose or $pos = $nextPos, next;
        # read NAL unit (and convert all 0x000003's to 0x0000 as per spec.)
        my $buff = '';
        pos($$dataPt) = $pos + 1;
        while ($$dataPt =~ /\0\0\x03/g) {
            last if pos $$dataPt > $end;
            $buff .= substr($$dataPt, $pos, pos($$dataPt)-1-$pos);
            $pos = pos $$dataPt;
        }
        $buff .= substr($$dataPt, $pos, $end - $pos);
        if ($verbose > 1) {
            printf $out "  NAL Unit Type: 0x%x (%d bytes)\n",$nal_unit_type, length $buff;
            $et->VerboseDump(\$buff);
        }
        pos($$dataPt) = $pos = $nextPos;

        if ($nal_unit_type == 0x06) {       # sei_rbsp (supplemental enhancement info)

            if ($$et{GotNAL06}) {
                # process only the first SEI unless ExtractEmbedded is set
                next unless $et->Options('ExtractEmbedded');
                $$et{DOC_NUM} = $$et{GotNAL06};
            }
            $foundUserData = ProcessSEI($et, { DataPt => \$buff } );
            delete $$et{DOC_NUM};
            # keep parsing SEI's until we find the user data
            next unless $foundUserData;
            $$et{GotNAL06} = ($$et{GotNAL06} || 0) + 1;

        } elsif ($nal_unit_type == 0x07) {  # sequence_parameter_set_rbsp

            # process this NAL unit type only once
            next if $$et{GotNAL07};
            $$et{GotNAL07} = 1;
            ParseSeqParamSet($et, $tagTablePtr, \$buff);
        }
        # we were successful, so don't parse this NAL unit type again
        delete $parseNalUnit{$nal_unit_type};
    }
    # parse one extra H264 frame if we didn't find the user data in this one
    # (Panasonic cameras don't put the SEI in the first frame)
    return 0 if $foundUserData or $$et{ParsedH264};
    $$et{ParsedH264} = 1;
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::H264 - Read meta information from H.264 video

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from H.264 video streams.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.itu.int/rec/T-REC-H.264/e>

=item L<http://miffteevee.co.uk/documentation/development/H264Parser_8cpp-source.html>

=item L<http://ffmpeg.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/H264 Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

