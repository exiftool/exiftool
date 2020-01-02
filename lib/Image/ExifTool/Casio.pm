#------------------------------------------------------------------------------
# File:         Casio.pm
#
# Description:  Casio EXIF maker notes tags
#
# Revisions:    12/09/2003 - P. Harvey Created
#               09/10/2004 - P. Harvey Added MakerNote2 (thanks to Joachim Loehr)
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Joachim Loehr private communication
#               3) http://homepage3.nifty.com/kamisaka/makernote/makernote_casio.htm
#               4) http://gvsoft.homedns.org/exif/makernote-casio-type1.html
#               5) Robert Chi private communication (EX-F1)
#               6) https://exiftool.org/forum/index.php/topic,3701.html
#               JD) Jens Duttke private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Casio;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.38';

# older Casio maker notes (ref 1)
%Image::ExifTool::Casio::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0001 => {
        Name => 'RecordingMode' ,
        Writable => 'int16u',
        PrintConv => {
            1 => 'Single Shutter',
            2 => 'Panorama',
            3 => 'Night Scene',
            4 => 'Portrait',
            5 => 'Landscape',
            7 => 'Panorama', #4
            10 => 'Night Scene', #4
            15 => 'Portrait', #4
            16 => 'Landscape', #4
        },
    },
    0x0002 => {
        Name => 'Quality',
        Writable => 'int16u',
        PrintConv => { 1 => 'Economy', 2 => 'Normal', 3 => 'Fine' },
    },
    0x0003 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            2 => 'Macro',
            3 => 'Auto',
            4 => 'Manual',
            5 => 'Infinity',
            7 => 'Spot AF', #4
        },
    },
    0x0004 => [
        {
            Name => 'FlashMode',
            Condition => '$self->{Model} =~ /^QV-(3500EX|8000SX)/',
            Writable => 'int16u',
            PrintConv => {
                1 => 'Auto',
                2 => 'On',
                3 => 'Off',
                4 => 'Off', #4
                5 => 'Red-eye Reduction', #4
            },
        },
        {
            Name => 'FlashMode',
            Writable => 'int16u',
            PrintConv => {
                1 => 'Auto',
                2 => 'On',
                3 => 'Off',
                4 => 'Red-eye Reduction',
            },
        },
    ],
    0x0005 => {
        Name => 'FlashIntensity',
        Writable => 'int16u',
        PrintConv => {
            11 => 'Weak',
            12 => 'Low', #4
            13 => 'Normal',
            14 => 'High', #4
            15 => 'Strong',
        },
    },
    0x0006 => {
        Name => 'ObjectDistance',
        Writable => 'int32u',
        ValueConv => '$val / 1000', #4
        ValueConvInv => '$val * 1000',
        PrintConv => '"$val m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    0x0007 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto',
            2 => 'Tungsten',
            3 => 'Daylight',
            4 => 'Fluorescent',
            5 => 'Shade',
            129 => 'Manual',
        },
    },
    # 0x0009 Bulb? (ref unknown)
    0x000a => {
        Name => 'DigitalZoom',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x10000 => 'Off',
            0x10001 => '2x',
            0x19999 => '1.6x', #4
            0x20000 => '2x', #4
            0x33333 => '3.2x', #4
            0x40000 => '4x', #4
        },
    },
    0x000b => {
        Name => 'Sharpness',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
            16 => 'Normal', #4
            17 => '+1', #4
            18 => '-1', #4
         },
    },
    0x000c => {
        Name => 'Contrast',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
            16 => 'Normal', #4
            17 => '+1', #4
            18 => '-1', #4
        },
    },
    0x000d => {
        Name => 'Saturation',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
            16 => 'Normal', #4
            17 => '+1', #4
            18 => '-1', #4
        },
    },
    0x0014 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
    0x0015 => { #JD (Similar to Type2 0x2001)
        Name => 'FirmwareDate',
        Writable => 'string',
        Format => 'undef', # the 'string' contains nulls
        Count => 18,
        PrintConv => q{
            $_ = $val;
            if (/^(\d{2})(\d{2})\0\0(\d{2})(\d{2})\0\0(\d{2})(.{2})\0{2}$/) {
                my $yr = $1 + ($1 < 70 ? 2000 : 1900);
                my $sec = $6;
                $val = "$yr:$2:$3 $4:$5";
                $val .= ":$sec" if $sec=~/^\d{2}$/;
                return $val;
            }
            tr/\0/./;  s/\.+$//;
            return "Unknown ($_)";
        },
        PrintConvInv => q{
            $_ = $val;
            if (/^(19|20)(\d{2}):(\d{2}):(\d{2}) (\d{2}):(\d{2})$/) {
                return "$2$3\0\0$4$5\0\0$6\0\0\0\0";
            } elsif (/^Unknown\s*\((.*)\)$/i) {
                $_ = $1;  tr/./\0/;
                return $_;
            } else {
                return undef;
            }
        },
    },
    0x0016 => { #4
        Name => 'Enhancement',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Off',
            2 => 'Red',
            3 => 'Green',
            4 => 'Blue',
            5 => 'Flesh Tones',
        },
    },
    0x0017 => { #4
        Name => 'ColorFilter',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Off',
            2 => 'Black & White',
            3 => 'Sepia',
            4 => 'Red',
            5 => 'Green',
            6 => 'Blue',
            7 => 'Yellow',
            8 => 'Pink',
            9 => 'Purple',
        },
    },
    0x0018 => { #4
        Name => 'AFPoint',
        Writable => 'int16u',
        Notes => 'may not be valid for all models', #JD
        PrintConv => {
            1 => 'Center',
            2 => 'Upper Left',
            3 => 'Upper Right',
            4 => 'Near Left/Right of Center',
            5 => 'Far Left/Right of Center',
            6 => 'Far Left/Right of Center/Bottom',
            7 => 'Top Near-left',
            8 => 'Near Upper/Left',
            9 => 'Top Near-right',
            10 => 'Top Left',
            11 => 'Top Center',
            12 => 'Top Right',
            13 => 'Center Left',
            14 => 'Center Right',
            15 => 'Bottom Left',
            16 => 'Bottom Center',
            17 => 'Bottom Right',
        },
    },
    0x0019 => { #4
        Name => 'FlashIntensity',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Normal',
            2 => 'Weak',
            3 => 'Strong',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        # crazy I know, but the offset for this value is entry-based
        # (QV-2100, QV-2900UX, QV-3500EX and QV-4000) even though the
        # offsets for other values isn't
        EntryBased => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);

# ref 2:
%Image::ExifTool::Casio::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0002 => {
        Name => 'PreviewImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0x0003 => {
        Name => 'PreviewImageLength',
        Groups => { 2 => 'Image' },
        OffsetPair => 0x0004, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x0004 => {
        Name => 'PreviewImageStart',
        Groups => { 2 => 'Image' },
        Flags => 'IsOffset',
        OffsetPair => 0x0003, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x0008 => {
        Name => 'QualityMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Economy',
           1 => 'Normal',
           2 => 'Fine',
        },
    },
    0x0009 => {
        Name => 'CasioImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        PrintConv => {
            0 => '640x480',
            4 => '1600x1200',
            5 => '2048x1536',
            20 => '2288x1712',
            21 => '2592x1944',
            22 => '2304x1728',
            36 => '3008x2008',
        },
    },
    0x000d => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Normal',
           1 => 'Macro',
        },
    },
    0x0014 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
        PrintConv => {
           3 => 50,
           4 => 64,
           6 => 100,
           9 => 200,
        },
    },
    0x0019 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Auto',
           1 => 'Daylight',
           2 => 'Shade',
           3 => 'Tungsten',
           4 => 'Fluorescent',
           5 => 'Manual',
        },
    },
    0x001d => {
        Name => 'FocalLength',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0x001f => {
        Name => 'Saturation',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Low',
           1 => 'Normal',
           2 => 'High',
        },
    },
    0x0020 => {
        Name => 'Contrast',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Low',
           1 => 'Normal',
           2 => 'High',
        },
    },
    0x0021 => {
        Name => 'Sharpness',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Soft',
           1 => 'Normal',
           2 => 'Hard',
        },
    },
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x2000 => {
        # this image data is also referenced by tags 3 and 4
        # (nasty that they double-reference the image!)
        %Image::ExifTool::previewImageTagInfo,
        Groups => { 2 => 'Preview' },
    },
    0x2001 => { #PH
        # I downloaded images from 12 different EX-Z50 cameras, and they showed
        # only 3 distinct dates here (2004:08:31 18:55, 2004:09:13 14:14, and
        # 2004:11:26 17:07), so I'm guessing this is a firmware version date - PH
        Name => 'FirmwareDate',
        Writable => 'string',
        Format => 'undef', # the 'string' contains nulls
        Count => 18,
        PrintConv => q{
            $_ = $val;
            if (/^(\d{2})(\d{2})\0\0(\d{2})(\d{2})\0\0(\d{2})\0{4}$/) {
                my $yr = $1 + ($1 < 70 ? 2000 : 1900);
                return "$yr:$2:$3 $4:$5";
            }
            tr/\0/./;  s/\.+$//;
            return "Unknown ($_)";
        },
        PrintConvInv => q{
            $_ = $val;
            if (/^(19|20)(\d{2}):(\d{2}):(\d{2}) (\d{2}):(\d{2})$/) {
                return "$2$3\0\0$4$5\0\0$6\0\0\0\0";
            } elsif (/^Unknown\s*\((.*)\)$/i) {
                $_ = $1;  tr/./\0/;
                return $_;
            } else {
                return undef;
            }
        },
    },
    0x2011 => {
        Name => 'WhiteBalanceBias',
        Writable => 'int16u',
        Count => 2,
    },
    0x2012 => {
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Manual',
           1 => 'Daylight', #3
           2 => 'Cloudy', #PH (EX-ZR20, NC)
           3 => 'Shade', #3
           4 => 'Flash?',
           6 => 'Fluorescent', #3
           9 => 'Tungsten?', #PH (EX-Z77)
           10 => 'Tungsten', #3
           12 => 'Flash',
        },
    },
    0x2021 => { #JD (guess)
        Name => 'AFPointPosition',
        Writable => 'int16u',
        Count => 4,
        PrintConv => q{
            my @v = split ' ', $val;
            return 'n/a' if $v[0] == 65535 or not $v[1] or not $v[3];
            sprintf "%.2g %.2g", $v[0]/$v[1], $v[2]/$v[3];
        },
    },
    0x2022 => {
        Name => 'ObjectDistance',
        Writable => 'int32u',
        ValueConv => '$val >= 0x20000000 ? "inf" : $val / 1000',
        ValueConvInv => '$val eq "inf" ? 0x20000000 : $val * 1000',
        PrintConv => '$val eq "inf" ? $val : "$val m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    # 0x2023 looks interesting (values 0,1,2,3,5 in samples) - PH
    #        - 1 for makeup mode shots (portrait?) (EX-Z450)
    0x2034 => {
        Name => 'FlashDistance',
        Writable => 'int16u',
    },
    # 0x203e - normally 62000, but 62001 for anti-shake mode - PH
    0x2076 => { #PH (EX-Z450)
        # ("Enhancement" was taken already, so call this "SpecialEffect" for lack of a better name)
        Name => 'SpecialEffectMode',
        Writable => 'int8u',
        Count => 3,
        PrintConv => {
            '0 0 0' => 'Off',
            '1 0 0' => 'Makeup',
            '2 0 0' => 'Mist Removal',
            '3 0 0' => 'Vivid Landscape',
            # have also seen '1 1 1', '2 2 4', '4 3 3', '4 4 4'
            # '0 0 14' and '0 0 42' - premium auto night shot (EX-Z2300)
            # and '0 0 2' for Art HDR
        },
    },
    0x2089 => [ #PH
        {
            Name => 'FaceInfo1',
            Condition => '$$valPt =~ /^(\0\0|.\x02\x80\x01\xe0)/s', # (EX-H5)
            SubDirectory => {
                TagTable => 'Image::ExifTool::Casio::FaceInfo1',
                ByteOrder => 'BigEndian',
            },
        },{
            Name => 'FaceInfo2',
            Condition => '$$valPt =~ /^\x02\x01/', # (EX-H20G,EX-ZR100)
            SubDirectory => {
                TagTable => 'Image::ExifTool::Casio::FaceInfo2',
                ByteOrder => 'LittleEndian',
            },
        },{
            Name => 'FaceInfoUnknown',
            Unknown => 1,
        },
    ],
    # 0x208a - also some sort of face detection information - PH
    0x211c => { #PH
        Name => 'FacesDetected',
        Format => 'int8u',
    },
    0x3000 => {
        Name => 'RecordMode',
        Writable => 'int16u',
        PrintConv => {
            2 => 'Program AE', #3
            3 => 'Shutter Priority', #3
            4 => 'Aperture Priority', #3
            5 => 'Manual', #3
            6 => 'Best Shot', #3
            17 => 'Movie', #PH (UHQ?)
            19 => 'Movie (19)', #PH (HQ?, EX-P505)
            20 => 'YouTube Movie', #PH
            '2 0' => 'Program AE', #PH (NC)
            '3 0' => 'Shutter Priority', #PH (NC)
            '4 0' => 'Aperture Priority', #PH (NC)
            '5 0' => 'Manual', #PH (NC)
            '6 0' => 'Best Shot', #PH (NC)
        },
    },
    0x3001 => { #3
        Name => 'ReleaseMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Normal',
            3 => 'AE Bracketing',
            11 => 'WB Bracketing',
            13 => 'Contrast Bracketing', #(not sure about translation - PH)
            19 => 'High Speed Burst', #PH (EX-FH25, 40fps)
            # have also seen: 2, 7(common), 14, 18 - PH
        },
    },
    0x3002 => {
        Name => 'Quality',
        Writable => 'int16u',
        PrintConv => {
           1 => 'Economy',
           2 => 'Normal',
           3 => 'Fine',
        },
    },
    0x3003 => {
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
           0 => 'Manual', #(guess at translation)
           1 => 'Focus Lock', #(guess at translation)
           2 => 'Macro', #3
           3 => 'Single-Area Auto Focus',
           5 => 'Infinity', #PH
           6 => 'Multi-Area Auto Focus',
           8 => 'Super Macro', #PH (EX-Z2300)
        },
    },
    0x3006 => {
        Name => 'HometownCity',
        Writable => 'string',
    },
    # unfortunately the BestShotMode numbers are model-dependent - PH
    #http://search.casio-intl.com/search?q=BEST+SHOT+sets+up+the+camera+CASIO+EX+ZR100+BEST+SHOT&btnG=Search&output=xml_no_dtd&oe=UTF-8&ie=UTF-8&site=casio-intl_com&client=search_casio-intl_com&proxystylesheet=search_casio-intl_com
    # NOTE: BestShotMode is not used unless RecordMode is "Best Shot"
    0x3007 => [{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-FC100"',
        Notes => 'EX-FC100',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Portrait',
            3 => 'Scenery',
            4 => 'Portrait with Scenery',
            5 => 'Children',
            6 => 'Sports',
            7 => 'Pet',
            8 => 'Flower',
            9 => 'Natural Green',
            10 => 'Autumn Leaves',
            11 => 'Sundown',
            12 => 'High Speed Night Scene',
            13 => 'Night Scene Portrait',
            14 => 'Fireworks',
            15 => 'High Speed Anti Shake',
            16 => 'Multi-motion Image',
            17 => 'High Speed Best Selection',
            18 => 'Move Out CS',
            19 => 'Move In CS',
            20 => 'Pre-record Movie',
            21 => 'For YouTube',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-FC150"',
        Notes => 'EX-FC150',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Expression CS',
            3 => 'Baby CS',
            4 => 'Child CS',
            5 => 'Pet CS',
            6 => 'Sports CS',
            7 => 'Child High Speed Movie',
            8 => 'Pet High Speed Movie',
            9 => 'Sports High Speed Movie',
            10 => 'Lag Correction',
            11 => 'High Speed Lighting',
            12 => 'High Speed Night Scene',
            13 => 'High Speed Night Scene and Portrait',
            14 => 'High Speed Anti Shake',
            15 => 'High Speed Best Selection',
            16 => 'Portrait',
            17 => 'Scenery',
            18 => 'Portrait With Scenery',
            19 => 'Flower',
            20 => 'Natural Green',
            21 => 'Autumn Leaves',
            22 => 'Sundown',
            23 => 'Fireworks',
            24 => 'Multi-motion Image',
            25 => 'Move Out CS',
            26 => 'Move In CS',
            27 => 'Pre-record Movie',
            28 => 'For YouTube',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-FC200S"',
        Notes => 'EX-FC200S',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Slow Motion Swing (behind)',
            2 => 'Slow Motion Swing (front)',
            3 => 'Self Slow Motion (behind)',
            4 => 'Self Slow Motion (front)',
            5 => 'Swing Burst',
            6 => 'HDR',
            7 => 'HDR Art',
            8 => 'High Speed Night Scene',
            9 => 'High Speed Night Scene and Portrait',
            10 => 'High Speed Anti Shake',
            11 => 'Multi SR Zoom',
            12 => 'Blurred Background',
            13 => 'Wide Shot',
            14 => 'Slide Panorama',
            15 => 'High Speed Best Selection',
            16 => 'Lag Correction',
            17 => 'High Speed CS',
            18 => 'Child CS',
            19 => 'Pet CS',
            20 => 'Sports CS',
            21 => 'Child High Speed Movie',
            22 => 'Pet High Speed Movie',
            23 => 'Sports High Speed Movie',
            24 => 'Portrait',
            25 => 'Scenery',
            26 => 'Portrait with Scenery',
            27 => 'Children',
            28 => 'Sports',
            29 => 'Candlelight Portrait',
            30 => 'Party',
            31 => 'Pet',
            32 => 'Flower',
            33 => 'Natural Green',
            34 => 'Autumn Leaves',
            35 => 'Soft Flowing Water',
            36 => 'Splashing Water',
            37 => 'Sundown',
            38 => 'Fireworks',
            39 => 'Food',
            40 => 'Text',
            41 => 'Collection',
            42 => 'Auction',
            43 => 'Pre-record Movie',
            44 => 'For YouTube',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-FH100"',
        Notes => 'EX-FH100',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Expression CS',
            2 => 'Baby CS',
            3 => 'Child CS',
            4 => 'Pet CS',
            5 => 'Sports CS',
            6 => 'Child High Speed Movie',
            7 => 'Pet High Speed Movie',
            8 => 'Sports High Speed Movie',
            9 => 'Lag Correction',
            10 => 'High Speed Lighting',
            11 => 'High Speed Night Scene',
            12 => 'High Speed Night Scene and Portrait',
            13 => 'High Speed Anti Shake',
            14 => 'High Speed Best Selection',
            15 => 'Portrait',
            16 => 'Scenery',
            17 => 'Portrait With Scenery',
            18 => 'Flower',
            19 => 'Natural Green',
            20 => 'Autumn Leaves',
            21 => 'Sundown',
            22 => 'Fireworks',
            23 => 'Multi-motion Image',
            24 => 'Move Out CS',
            25 => 'Move In CS',
            26 => 'Pre-record Movie',
            27 => 'For YouTube',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-G1"',
        Notes => 'EX-G1',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Auto Best Shot',
            3 => 'Dynamic Photo',
            4 => 'Interval Snapshot',
            5 => 'Interval Movie',
            6 => 'Portrait',
            7 => 'Scenery',
            8 => 'Portrait with Scenery',
            9 => 'Underwater',
            10 => 'Beach',
            11 => 'Snow',
            12 => 'Children',
            13 => 'Sports',
            14 => 'Pet',
            15 => 'Flower',
            16 => 'Sundown',
            17 => 'Night Scene',
            18 => 'Night Scene Portrait',
            19 => 'Fireworks',
            20 => 'Food',
            21 => 'For eBay',
            22 => 'Multi-motion Image',
            23 => 'Pre-record Movie',
            24 => 'For YouTube',
            25 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-S10"',
        Notes => 'EX-S10',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Portrait',
            3 => 'Scenery',
            4 => 'Portrait with Scenery',
            5 => 'Self-portrait (1 person)',
            6 => 'Self-portrait (2 people)',
            7 => 'Children',
            8 => 'Sports',
            9 => 'Candlelight Portrait',
            10 => 'Party',
            11 => 'Pet',
            12 => 'Flower',
            13 => 'Natural Green',
            14 => 'Autumn Leaves',
            15 => 'Soft Flowing Water',
            16 => 'Splashing Water',
            17 => 'Sundown',
            18 => 'Night Scene',
            19 => 'Night Scene Portrait',
            20 => 'Fireworks',
            21 => 'Food',
            22 => 'Text',
            23 => 'Collection',
            24 => 'Auction',
            25 => 'Backlight',
            26 => 'Anti Shake',
            27 => 'High Sensitivity',
            28 => 'Underwater',
            29 => 'Monochrome',
            30 => 'Retro',
            31 => 'Business Cards',
            32 => 'White Board',
            33 => 'Silent',
            34 => 'Pre-record Movie',
            35 => 'For YouTube',
            36 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-S880"',
        Notes => 'EX-S880',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Portrait',
            3 => 'Scenery',
            4 => 'Portrait with Scenery',
            5 => 'Children',
            6 => 'Sports',
            7 => 'Candlelight Portrait',
            8 => 'Party',
            9 => 'Pet',
            10 => 'Flower',
            11 => 'Natural Green',
            12 => 'Autumn Leaves',
            13 => 'Soft Flowing Water', # (wrong in documentation)
            14 => 'Splashing Water',
            15 => 'Sundown',
            16 => 'Night Scene',
            17 => 'Night Scene Portrait',
            18 => 'Fireworks',
            19 => 'Food',
            20 => 'Text',
            21 => 'Collection',
            22 => 'Auction',
            23 => 'Backlight',
            24 => 'Anti Shake',
            25 => 'High Sensitivity',
            26 => 'Monochrome',
            27 => 'Retro',
            28 => 'Twilight',
            29 => 'Layout (2 images)',
            30 => 'Layout (3 images)',
            31 => 'Auto Framing',
            32 => 'Old Photo',
            33 => 'Business Cards',
            34 => 'White Board',
            35 => 'Silent',
            36 => 'Short Movie',
            37 => 'Past Movie',
            38 => 'For YouTube',
            39 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-Z16"',
        Notes => 'EX-Z16',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Portrait',
            3 => 'Scenery',
            4 => 'Portrait with Scenery',
            5 => 'Children',
            6 => 'Sports',
            7 => 'Candlelight Portrait',
            8 => 'Party',
            9 => 'Pet',
            10 => 'Flower',
            11 => 'Soft Flowing Water',
            12 => 'Sundown',
            13 => 'Night Scene',
            14 => 'Night Scene Portrait',
            15 => 'Fireworks',
            16 => 'Food',
            17 => 'Text',
            18 => 'For eBay',
            19 => 'Backlight',
            20 => 'Anti Shake',
            21 => 'High Sensitivity',
            22 => 'For YouTube',
            23 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-Z9"',
        Notes => 'EX-Z9',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Movie',
            3 => 'Portrait',
            4 => 'Scenery',
            5 => 'Children',
            6 => 'Sports',
            7 => 'Candlelight Portrait',
            8 => 'Party',
            9 => 'Pet',
            10 => 'Flower',
            11 => 'Soft Flowing Water',
            12 => 'Sundown',
            13 => 'Night Scene',
            14 => 'Night Scene Portrait',
            15 => 'Fireworks',
            16 => 'Food',
            17 => 'Text',
            18 => 'Auction',
            19 => 'Backlight',
            20 => 'Anti Shake',
            21 => 'High Sensitivity',
            22 => 'For YouTube',
            23 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-Z80"',
        Notes => 'EX-Z80',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Portrait',
            3 => 'Scenery',
            4 => 'Portrait with Scenery',
            5 => 'Pet',
            6 => 'Self-portrait (1 person)',
            7 => 'Self-portrait (2 people)',
            8 => 'Flower',
            9 => 'Food',
            10 => 'Fashion Accessories',
            11 => 'Magazine',
            12 => 'Monochrome',
            13 => 'Retro',
            14 => 'Cross Filter',
            15 => 'Pastel',
            16 => 'Night Scene',
            17 => 'Night Scene Portrait',
            18 => 'Party',
            19 => 'Sports',
            20 => 'Children',
            21 => 'Sundown',
            22 => 'Fireworks',
            23 => 'Underwater',
            24 => 'Backlight',
            25 => 'High Sensitivity',
            26 => 'Auction',
            27 => 'White Board',
            28 => 'Pre-record Movie',
            29 => 'For YouTube',
            30 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} =~ /^EX-Z(100|200)$/',
        Notes => 'EX-Z100 and EX-Z200',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Auto Best Shot',
            3 => 'Portrait',
            4 => 'Scenery',
            5 => 'Portrait with Scenery',
            6 => 'Self-portrait (1 person)',
            7 => 'Self-portrait (2 people)',
            8 => 'Children',
            9 => 'Sports',
            10 => 'Candlelight Portrait',
            11 => 'Party',
            12 => 'Pet',
            13 => 'Flower',
            14 => 'Natural Green',
            15 => 'Autumn Leaves',
            16 => 'Soft Flowing Water',
            17 => 'Splashing Water',
            18 => 'Sundown',
            19 => 'Night Scene',
            20 => 'Night Scene Portrait',
            21 => 'Fireworks',
            22 => 'Food',
            23 => 'Text',
            24 => 'Collection',
            25 => 'Auction',
            26 => 'Backlight',
            27 => 'Anti Shake',
            28 => 'High Sensitivity',
            29 => 'Underwater',
            30 => 'Monochrome',
            31 => 'Retro',
            32 => 'Twilight',
            33 => 'ID Photo',
            34 => 'Business Cards',
            35 => 'White Board',
            36 => 'Silent',
            37 => 'Pre-record Movie',
            38 => 'For YouTube',
            39 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z750" and $$self{FILE_TYPE} eq "JPEG"',
        Notes => 'EX-Z750 JPEG images',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Portrait with Scenery',
            4 => 'Children',
            5 => 'Sports',
            6 => 'Candlelight Portrait',
            7 => 'Party',
            8 => 'Pet',
            9 => 'Flower',
            10 => 'Natural Green',
            11 => 'Soft Flowing Water',
            12 => 'Splashing Water',
            13 => 'Sundown',
            14 => 'Night Scene',
            15 => 'Night Scene Portrait',
            16 => 'Fireworks',
            17 => 'Food',
            18 => 'Text',
            19 => 'Collection',
            20 => 'Backlight',
            21 => 'Anti Shake',
            22 => 'Pastel',
            23 => 'Illustration',
            24 => 'Cross Filter',
            25 => 'Monochrome',
            26 => 'Retro',
            27 => 'Twilight',
            28 => 'Old Photo',
            29 => 'ID Photo',
            30 => 'Business Cards',
            31 => 'White Board',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z750" and $$self{FILE_TYPE} =~ /^(MOV|AVI)$/',
        Notes => 'EX-Z750 movies',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Night Scene',
            4 => 'Fireworks',
            5 => 'Backlight',
            6 => 'Silent',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z850" and $$self{FILE_TYPE} eq "JPEG"',
        Notes => 'EX-Z850 JPEG images',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Portrait with Scenery',
            4 => 'Children',
            5 => 'Sports',
            6 => 'Candlelight Portrait',
            7 => 'Party',
            8 => 'Pet',
            9 => 'Flower',
            10 => 'Natural Green',
            11 => 'Autumn Leaves',
            12 => 'Soft Flowing Water',
            13 => 'Splashing Water',
            14 => 'Sundown',
            15 => 'Night Scene',
            16 => 'Night Scene Portrait',
            17 => 'Fireworks',
            18 => 'Food',
            19 => 'Text',
            20 => 'Collection',
            21 => 'For eBay',
            22 => 'Backlight',
            23 => 'Anti Shake',
            24 => 'High Sensitivity',
            25 => 'Pastel',
            26 => 'Illustration',
            27 => 'Cross Filter',
            28 => 'Monochrome',
            29 => 'Retro',
            30 => 'Twilight',
            31 => 'ID Photo',
            32 => 'Old Photo',
            33 => 'Business Cards',
            34 => 'White Board',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z850" and $$self{FILE_TYPE} =~ /^(MOV|AVI)$/',
        Notes => 'EX-Z850 movies',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Night Scene',
            4 => 'Fireworks',
            5 => 'Backlight',
            6 => 'High Sensitivity',
            7 => 'Silent',
            8 => 'Short Movie',
            9 => 'Past Movie',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z1050"',
        Notes => 'EX-Z1050',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Movie',
            3 => 'Portrait',
            4 => 'Scenery',
            5 => 'Portrait with Scenery',
            6 => 'Children',
            7 => 'Sports',
            8 => 'Candlelight Portrait',
            9 => 'Party',
            10 => 'Pet',
            11 => 'Flower',
            12 => 'Natural Green',
            13 => 'Autumn Leaves',
            14 => 'Soft Flowing Water',
            15 => 'Splashing Water',
            16 => 'Sundown',
            17 => 'Night Scene',
            18 => 'Night Scene Portrait',
            19 => 'Fireworks',
            20 => 'Food',
            21 => 'Text',
            22 => 'Collection',
            23 => 'For eBay',
            24 => 'Backlight',
            25 => 'Anti Shake',
            26 => 'High Sensitivity',
            27 => 'Underwater',
            28 => 'Monochrome',
            29 => 'Retro',
            30 => 'Twilight',
            31 => 'Layout (2 images)',
            32 => 'Layout (3 images)',
            33 => 'Auto Framing',
            34 => 'ID Photo',
            35 => 'Old Photo',
            36 => 'Business Cards',
            37 => 'White Board',
            38 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z1080"',
        Notes => 'EX-Z1080',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Movie',
            3 => 'Portrait',
            4 => 'Scenery',
            5 => 'Portrait with Scenery',
            6 => 'Children',
            7 => 'Sports',
            8 => 'Candlelight Portrait',
            9 => 'Party',
            10 => 'Pet',
            11 => 'Flower',
            12 => 'Natural Green',
            13 => 'Autumn Leaves',
            14 => 'Soft Flowing Water',
            15 => 'Splashing Water',
            16 => 'Sundown',
            17 => 'Night Scene',
            18 => 'Night Scene Portrait',
            19 => 'Fireworks',
            20 => 'Food',
            21 => 'Text',
            22 => 'Collection',
            23 => 'For eBay',
            24 => 'Backlight',
            25 => 'Anti Shake',
            26 => 'High Sensitivity',
            27 => 'Underwater',
            28 => 'Monochrome',
            29 => 'Retro',
            30 => 'Twilight',
            31 => 'Layout (2 images)',
            32 => 'Layout (3 images)',
            33 => 'Auto Framing',
            34 => 'ID Photo',
            35 => 'Old Photo',
            36 => 'Business Cards',
            37 => 'White Board',
            38 => 'Short Movie',
            39 => 'Past Movie',
            40 => 'For YouTube',
            41 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z1200" and $$self{FILE_TYPE} eq "JPEG"',
        Notes => 'EX-Z1200 JPEG images',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Portrait with Scenery',
            4 => 'Children',
            5 => 'Sports',
            6 => 'Candlelight Portrait',
            7 => 'Party',
            8 => 'Pet',
            9 => 'Flower',
            10 => 'Natural Green',
            11 => 'Autumn Leaves',
            12 => 'Soft Flowing Water',
            13 => 'Splashing Water',
            14 => 'Sundown',
            15 => 'Night Scene',
            16 => 'Night Scene Portrait',
            17 => 'Fireworks',
            18 => 'Food',
            19 => 'Text',
            20 => 'Collection',
            21 => 'Auction',
            22 => 'Backlight',
            23 => 'High Sensitivity',
            24 => 'Underwater',
            25 => 'Monochrome',
            26 => 'Retro',
            27 => 'Twilight',
            28 => 'Layout (2 images)',
            29 => 'Layout (3 images)',
            30 => 'Auto Framing',
            31 => 'ID Photo',
            32 => 'Old Photo',
            33 => 'Business Cards',
            34 => 'White Board',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z1200" and $$self{FILE_TYPE} =~ /^(MOV|AVI)$/',
        Notes => 'EX-Z1200 movies',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Night Scene',
            4 => 'Fireworks',
            5 => 'Backlight',
            6 => 'High Sensitivity',
            7 => 'Silent',
            8 => 'Short Movie',
            9 => 'Past Movie',
        },
    },
    # (the following weren't numbered in the documentation:
    #  G1, Z300, Z250, Z85, Z19, Z150, F1, FH20)
    {
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-Z2000"',
        Notes => 'EX-Z2000',
        PrintConvColumns => 3,
        #http://support.casio.com/download_files/001/faq_pdf/Z2000/EXZ2000_BS_US_a.pdf
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Premium Auto',
            3 => 'Dynamic Photo',
            4 => 'Portrait',
            5 => 'Scenery',
            6 => 'Portrait with Scenery',
            7 => 'Children',
            8 => 'Sports',
            9 => 'Candlelight Portrait',
            10 => 'Party',
            11 => 'Pet',
            12 => 'Flower',
            13 => 'Natural Green',
            14 => 'Autumn Leaves',
            15 => 'Soft Flowing Water',
            16 => 'Splashing Water',
            17 => 'Sundown',
            18 => 'Night Scene',
            19 => 'Night Scene Portrait',
            20 => 'Fireworks',
            21 => 'Food',
            22 => 'Text',
            23 => 'Collection',
            24 => 'For eBay',
            25 => 'Backlight',
            26 => 'High Sensitivity',
            27 => 'Oil Painting',
            28 => 'Crayon',
            29 => 'Water Color',
            30 => 'Monochrome',
            31 => 'Retro',
            32 => 'Twilight',
            33 => 'Multi-motion Image',
            34 => 'ID Photo',
            35 => 'Business Cards',
            36 => 'White Board',
            37 => 'Silent',
            38 => 'Pre-record Movie',
            39 => 'For YouTube',
            40 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        # (Movies have different BestShot numbers for this camera)
        Condition => '$$self{Model} eq "EX-Z2300"',
        Notes => 'EX-Z2300',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Premium Auto',
            3 => 'Dynamic Photo',
            4 => 'Portrait',
            5 => 'Scenery',
            6 => 'Portrait with Scenery',
            7 => 'Children',
            8 => 'Sports',
            9 => 'Candlelight Portrait',
            10 => 'Party',
            11 => 'Pet',
            12 => 'Flower',
            13 => 'Natural Green',
            14 => 'Autumn Leaves',
            15 => 'Soft Flowing Water',
            16 => 'Splashing Water',
            17 => 'Sundown',
            18 => 'Night Scene',
            19 => 'Night Scene Portrait',
            20 => 'Fireworks',
            21 => 'Food',
            22 => 'Text',
            23 => 'Collection',
            24 => 'Auction',
            25 => 'Backlight',
            26 => 'High Sensitivity',
            27 => 'Oil Painting',
            28 => 'Crayon',
            29 => 'Water Color',
            30 => 'Monochrome',
            31 => 'Retro',
            32 => 'Twilight',
            33 => 'Multi-motion Image',
            34 => 'ID Photo',
            35 => 'Business Cards',
            36 => 'White Board',
            37 => 'Silent',
            38 => 'Pre-record Movie',
            39 => 'For YouTube',
            40 => 'Voice Recording',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-Z3000"',
        Notes => 'EX-Z3000',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'Portrait',
            2 => 'Scenery',
            3 => 'Portrait With Scenery',
            4 => 'Children',
            5 => 'Sports',
            6 => 'Night Scene',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-ZR100"',
        Notes => 'EX-ZR100',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Child CS',
            2 => 'Pet CS',
            3 => 'Sports CS',
            4 => 'Child High Speed Movie',
            5 => 'Pet High Speed Movie',
            6 => 'Sports High Speed Movie',
            7 => 'Multi SR Zoom',
            8 => 'Lag Correction',
            9 => 'High Speed Night Scene',
            10 => 'High Speed Night Scene and Portrait',
            11 => 'High Speed Anti Shake',
            12 => 'Portrait',
            13 => 'Scenery',
            14 => 'Portrait with Scenery',
            15 => 'Children',
            16 => 'Sports',
            17 => 'Candlelight Portrait',
            18 => 'Party',
            19 => 'Pet',
            20 => 'Flower',
            21 => 'Natural Green',
            22 => 'Autumn Leaves',
            23 => 'Soft Flowing Water',
            24 => 'Splashing Water',
            25 => 'Sundown',
            26 => 'Fireworks',
            27 => 'Food',
            28 => 'Text',
            29 => 'Collection',
            30 => 'For eBay',
            31 => 'Pre-record Movie',
            32 => 'For YouTube',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-ZR200"',
        Notes => 'EX-ZR200',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'High Speed Night Scene',
            2 => 'High Speed Night Scene and Portrait',
            3 => 'High Speed Anti Shake',
            4 => 'Blurred Background',
            5 => 'Wide Shot',
            6 => 'High Speed Best Selection',
            7 => 'Lag Correction',
            8 => 'Child CS',
            9 => 'Pet CS',
            10 => 'Sports CS',
            11 => 'Child High Speed Movie',
            12 => 'Pet High Speed Movie',
            13 => 'Sports High Speed Movie',
            14 => 'Portrait',
            15 => 'Scenery',
            16 => 'Portrait with Scenery',
            17 => 'Children',
            18 => 'Sports',
            19 => 'Candlelight Portrait',
            20 => 'Party',
            21 => 'Pet',
            22 => 'Flower',
            23 => 'Natural Green',
            24 => 'Autumn Leaves',
            25 => 'Soft Flowing Water',
            26 => 'Splashing Water',
            27 => 'Sundown',
            28 => 'Fireworks',
            29 => 'Food',
            30 => 'Text',
            31 => 'Collection',
            32 => 'Auction',
            33 => 'Pre-record Movie',
            34 => 'For YouTube',
        },
    },{ #http://ftp.casio.co.jp/pub/world_manual/qv/en/qv_4000/BS.pdf
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "QV-4000"',
        Notes => 'QV-4000',
        PrintConvColumns => 3,
        PrintConv => {
            0 => 'Off',
            1 => 'People',
            2 => 'Scenery',
            3 => 'Flower',
            4 => 'Night Scene',
            5 => 'Soft Focus',
            # this camera also supports 100 modes that you can apparently load
            # from a CD-ROM, but I don't know how these map into these numbers
        },
    },{ #Manfred, email
        Name => 'BestShotMode',
        Writable => 'int16u',
        Condition => '$$self{Model} eq "EX-ZR300"',
        Notes => 'EX-ZR300',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'High Speed Night Shot',
            2 => 'Blurred Background',
            3 => 'Toy Camera',
            4 => 'Soft Focus',
            5 => 'Light Tone',
            6 => 'Pop',
            7 => 'Sepia',
            8 => 'Monochrome',
            9 => 'Miniature',
            10 => 'Wide Shot',
            11 => 'High Speed Best Selection',
            12 => 'Lag Correction',
            13 => 'High Speed Night Scene',
            14 => 'High Speed Night Scene and Portrait',
            15 => 'High Speed Anti Shake',
            16 => 'Portrait',
            17 => 'Scenery',
            18 => 'Portrait with Scenery',
            19 => 'Children',
            20 => 'Sports',
            21 => 'Candlelight Portrait',
            22 => 'Party',
            23 => 'Pet',
            24 => 'Flower',
            25 => 'Natural Green',
            26 => 'Autumn Leaves',
            27 => 'Soft Flowing Water',
            28 => 'Splashing Water',
            29 => 'Sundown',
            30 => 'Fireworks',
            31 => 'Food',
            32 => 'Text',
            33 => 'Collection',
            34 => 'Auction',
            35 => 'Prerecord (Movie)',
            36 => 'For YouTube',
        },
    },{
        Name => 'BestShotMode',
        Writable => 'int16u',
        Notes => 'other models not yet decoded',
        # so we can't use a lookup as usual - PH
        PrintConv => '$val ? $val : "Off"',
        PrintConvInv => '$val=~/(\d+)/ ? $1 : 0',
    }],
    0x3008 => { #3
        Name => 'AutoISO',
        Writable => 'int16u',
        PrintConv => {
            1 => 'On',
            2 => 'Off',
            7 => 'On (high sensitivity)', #PH
            8 => 'On (anti-shake)', #PH
            10 => 'High Speed', #PH (EX-FC150)
        },
    },
    0x3009 => { #6
        Name => 'AFMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Spot',
            2 => 'Multi',
            3 => 'Face Detection',
            4 => 'Tracking', # (but saw this for "Family First" mode with EX-Z77 - PH)
            5 => 'Intelligent',
        },
    },
    0x3011 => { #3
        Name => 'Sharpness',
        Format => 'int16s',
        Writable => 'undef',
    },
    0x3012 => { #3
        Name => 'Contrast',
        Format => 'int16s',
        Writable => 'undef',
    },
    0x3013 => { #3
        Name => 'Saturation',
        Format => 'int16s',
        Writable => 'undef',
    },
    0x3014 => {
        Name => 'ISO',
        Writable => 'int16u',
        Priority => 0,
    },
    0x3015 => {
        Name => 'ColorMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            2 => 'Black & White', #PH (EX-Z400,FH20)
            3 => 'Sepia', #PH (EX-Z400)
        },
    },
    0x3016 => {
        Name => 'Enhancement',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Scenery', #PH (NC) (EX-Z77)
            3 => 'Green', #PH (EX-Z77)
            5 => 'Underwater', #PH (NC) (EX-Z77)
            9 => 'Flesh Tones', #PH (EX-Z77)
        },
    },
    0x3017 => {
        Name => 'ColorFilter',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Blue', #PH (FH20,Z400)
            3 => 'Green', #PH (FH20)
            4 => 'Yellow', #PH (FH20)
            5 => 'Red', #PH (FH20,Z77)
            6 => 'Purple', #PH (FH20,Z77,Z400)
            7 => 'Pink', #PH (FH20)
        },
    },
    0x301b => { #PH
        Name => 'ArtMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            8 => 'Silent Movie',
            39 => 'HDR', # (EX-ZR10)
            45 => 'Premium Auto', # (EX-2300)
            47 => 'Painting', # (EX-2300)
            49 => 'Crayon Drawing', # (EX-2300)
            51 => 'Panorama', # (EX-ZR10)
            52 => 'Art HDR', # (EX-ZR10,EX-Z3000)
            62 => 'High Speed Night Shot', # (EX-ZR20)
            64 => 'Monochrome', # (EX-ZR20)
            67 => 'Toy Camera', # (EX-ZR20)
            68 => 'Pop Art', # (EX-ZR20)
            69 => 'Light Tone', # (EX-ZR20)
        },
    },
    0x301c => { #3
        Name => 'SequenceNumber', # for continuous shooting
        Writable => 'int16u',
    },
    0x301d => { #3
        Name => 'BracketSequence',
        Writable => 'int16u',
        Count => 2,
    },
    # 0x301e - MultiBracket ? (ref 3)
    0x3020 => { #3
        Name => 'ImageStabilization',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Best Shot',
            3 => 'Movie Anti-Shake', # (EX-V7, EX-TR100)
            # (newer models write 2 numbers here - PH)
            '0 0' => 'Off', #PH
            '16 0' => 'Slow Shutter', #PH (EX-Z77)
            '18 0' => 'Anti-Shake', #PH (EX-Z77)
            '20 0' => 'High Sensitivity', #PH (EX-Z77)
            # EX-Z2000 in 'Auto' mode gives '0 3' or '2 3' (ref 6)
            '0 1' => 'Off (1)', #6
            '0 3' => 'CCD Shift', #PH/6 ("Camera AS" in EX-Z2000 manual)
            '2 1' => 'High Sensitivity', #6
            '2 3' => 'CCD Shift + High Sensitivity', #PH (EX-FC150)
            # have also seen:
            # '2 0' - EX-Z15 1/60s ISO 200, EX-Z77 1/1000s ISO 50
            # '16 1' - EX-Z2300 1/125s ISO 50
        },
    },
    0x302a => { #PH (EX-Z450)
        Name => 'LightingMode', #(just guessing here)
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'High Dynamic Range', # (EX-Z77 anti-blur shot)
            5 => 'Shadow Enhance Low', #(NC)
            6 => 'Shadow Enhance High', #(NC)
        },
    },
    0x302b => { #PH (EX-Z77)
        Name => 'PortraitRefiner',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => '+1',
            2 => '+2',
        },
    },
    0x3030 => { #PH (EX-Z450)
        Name => 'SpecialEffectLevel',
        Writable => 'int16u',
    },
    0x3031 => { #PH (EX-Z450)
        Name => 'SpecialEffectSetting',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Makeup',
            2 => 'Mist Removal',
            3 => 'Vivid Landscape',
            16 => 'Art Shot', # (EX-Z2300)
        },
    },
    0x3103 => { #5
        Name => 'DriveMode',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            OTHER => sub {
                # handle new values of future models
                my ($val, $inv) = @_;
                return $val =~ /(\d+)/ ? $1 : undef if $inv;
                return "Continuous ($val fps)";
            },
            0 => 'Single Shot', #PH (NC)
            1 => 'Continuous Shooting', # (1 fps for the EX-F1)
            2 => 'Continuous (2 fps)',
            3 => 'Continuous (3 fps)',
            4 => 'Continuous (4 fps)',
            5 => 'Continuous (5 fps)',
            6 => 'Continuous (6 fps)',
            7 => 'Continuous (7 fps)',
            10 => 'Continuous (10 fps)',
            12 => 'Continuous (12 fps)',
            15 => 'Continuous (15 fps)',
            20 => 'Continuous (20 fps)',
            30 => 'Continuous (30 fps)',
            40 => 'Continuous (40 fps)', #PH (EX-FH25)
            60 => 'Continuous (60 fps)',
            240 => 'Auto-N',
        },
    },
    0x310b => { #PH (NC)
        Name => 'ArtModeParameters',
        Writable => 'int8u',
        Count => 3,
        # "0 1 0" = Toy camera 1
        # "0 2 0" = Toy camera 1
        # "0 3 0" = Toy camera 1
        # Have also seen "0 0 0" and "2 0 0"
    },
    0x4001 => { #PH (AVI videos)
        Name => 'CaptureFrameRate',
        Writable => 'int16u',
        Count => -1,
        ValueConv => q{
            my @v=split(" ",$val);
            return $val / 1000 if @v == 1;
            return $v[1] ? "$v[1]-$v[0]" : ($v[0] > 10000 ? $v[0] / 1000 : $v[0]);
        },
        ValueConvInv => '$val <= 60 ? $val * 1000 : int($val) . " 0"',
    },
    # 0x4002 - AVI videos, related to video quality or size - PH
    0x4003 => { #PH (AVI and MOV videos)
        Name => 'VideoQuality',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Standard',
            # 2 - could this be LP?
            3 => 'HD (720p)',
            4 => 'Full HD (1080p)', # (EX-ZR10, 30fps 1920x1080)
            5 => 'Low', # used in High Speed modes
        },
    },
);

# face detection information (ref PH) (EX-H5)
%Image::ExifTool::Casio::FaceInfo1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 0 ],
    NOTES => 'Face-detect tags extracted from models such as the EX-H5.',
    0x00 => { # (NC)
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x01 => {
        Name => 'FaceDetectFrameSize',
        Condition => '$$self{FacesDetected} >= 1', # (otherwise zeros)
        Format => 'int16u[2]',
    },
    0x0d => {
        Name => 'Face1Position',
        Condition => '$$self{FacesDetected} >= 1',
        Format => 'int16u[4]',
        Notes => q{
            left, top, right and bottom of detected face in coordinates of
            FaceDetectFrameSize, with increasing Y downwards
        },
    },
    # decoding NOT CONFIRMED (NC) for faces 2-10!
    0x7c => {
        Name => 'Face2Position',
        Condition => '$$self{FacesDetected} >= 2',
        Format => 'int16u[4]',
    },
    0xeb => {
        Name => 'Face3Position',
        Condition => '$$self{FacesDetected} >= 3',
        Format => 'int16u[4]',
    },
    0x15a => {
        Name => 'Face4Position',
        Condition => '$$self{FacesDetected} >= 4',
        Format => 'int16u[4]',
    },
    0x1c9 => {
        Name => 'Face5Position',
        Condition => '$$self{FacesDetected} >= 5',
        Format => 'int16u[4]',
    },
    0x238 => {
        Name => 'Face6Position',
        Condition => '$$self{FacesDetected} >= 6',
        Format => 'int16u[4]',
    },
    0x2a7 => {
        Name => 'Face7Position',
        Condition => '$$self{FacesDetected} >= 7',
        Format => 'int16u[4]',
    },
    0x316 => {
        Name => 'Face8Position',
        Condition => '$$self{FacesDetected} >= 8',
        Format => 'int16u[4]',
    },
    0x385 => {
        Name => 'Face9Position',
        Condition => '$$self{FacesDetected} >= 9',
        Format => 'int16u[4]',
    },
    0x3f4 => {
        Name => 'Face10Position',
        Condition => '$$self{FacesDetected} >= 10',
        Format => 'int16u[4]',
    },
);

# face detection information (ref PH) (EX-ZR100)
%Image::ExifTool::Casio::FaceInfo2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 2 ],
    NOTES => 'Face-detect tags extracted from models such as the EX-H20G and EX-ZR100.',
    0x02 => {
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x04 => {
        Name => 'FaceDetectFrameSize',
        Condition => '$$self{FacesDetected} >= 1',
        Format => 'int16u[2]',
    },
    0x08 => {
        Name => 'FaceOrientation',
        Condition => '$$self{FacesDetected} >= 1',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
            3 => 'Rotate 180', # (NC)
            # (have seen 64 here, but image had no face)
        },
        Notes => 'orientation of face relative to unrotated image',
    },
    # 0x0a - FaceDetectFrameSize again
    # 0x11 - Face1Detected flag (1=detected)
    0x18 => {
        Name => 'Face1Position',
        Condition => '$$self{FacesDetected} >= 1',
        Format => 'int16u[4]',
        Notes => q{
            left, top, right and bottom of detected face in coordinates of
            FaceDetectFrameSize, with increasing Y downwards
        },
    },
    # 0x45 - Face2Detected, etc...
    0x4c => {
        Name => 'Face2Position',
        Condition => '$$self{FacesDetected} >= 2',
        Format => 'int16u[4]',
    },
    0x80 => {
        Name => 'Face3Position',
        Condition => '$$self{FacesDetected} >= 3',
        Format => 'int16u[4]',
    },
    0xb4 => {
        Name => 'Face4Position',
        Condition => '$$self{FacesDetected} >= 4',
        Format => 'int16u[4]',
    },
    0xe8 => {
        Name => 'Face5Position',
        Condition => '$$self{FacesDetected} >= 5',
        Format => 'int16u[4]',
    },
    0x11c => {
        Name => 'Face6Position',
        Condition => '$$self{FacesDetected} >= 6',
        Format => 'int16u[4]',
    },
    0x150 => {
        Name => 'Face7Position',
        Condition => '$$self{FacesDetected} >= 7',
        Format => 'int16u[4]',
    },
    0x184 => {
        Name => 'Face8Position',
        Condition => '$$self{FacesDetected} >= 8',
        Format => 'int16u[4]',
    },
    0x1b8 => {
        Name => 'Face9Position',
        Condition => '$$self{FacesDetected} >= 9',
        Format => 'int16u[4]',
    },
    0x1ec => {
        Name => 'Face10Position',
        Condition => '$$self{FacesDetected} >= 10',
        Format => 'int16u[4]',
    },
);

# Casio APP1 QVCI segment found in QV-7000SX images (ref PH)
%Image::ExifTool::Casio::QVCI = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in the APP1 QVCI segment of JPEG images from the
        Casio QV-7000SX.
    },
    0x2c => {
        Name => 'CasioQuality',
        PrintConv => {
            1 => 'Economy',
            2 => 'Normal',
            3 => 'Fine',
            4 => 'Super Fine',
        },
    },
    0x37 => {
        Name => 'FocalRange',
        Unknown => 1,
    },
    0x4d => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'string[20]',
        Groups => { 2 => 'Time' },
        ValueConv => '$val=~tr/./:/; $val=~s/(\d+:\d+:\d+):/$1 /; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x62 => {
        Name => 'ModelType',
        Format => 'string[7]',
    },
    0x72 => { # could be serial number or manufacture date in form YYMMDDxx ?
        Name => 'ManufactureIndex',
        Format => 'string[9]',
    },
    0x7c => {
        Name => 'ManufactureCode',
        Format => 'string[9]',
    },
);

# tags in Casio AVI videos (ref PH)
%Image::ExifTool::Casio::AVI = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => 'This information is found in Casio GV-10 AVI videos.',
    0 => {
        Name => 'Software', # (equivalent to RIFF Software tag)
        Format => 'string',
    },
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Casio - Casio EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Casio maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joachim Loehr for adding support for the type 2 maker notes, and
Jens Duttke and Robert Chi for decoding some tags.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Casio Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
