#------------------------------------------------------------------------------
# File:         Nikon.pm
#
# Description:  Nikon EXIF maker notes tags
#
# Revisions:    12/09/2003 - P. Harvey Created
#               05/17/2004 - P. Harvey Added information from Joseph Heled
#               09/21/2004 - P. Harvey Changed tag 2 to ISOUsed & added PrintConv
#               12/01/2004 - P. Harvey Added default PRINT_CONV
#               01/01/2005 - P. Harvey Decode preview image and preview IFD
#               03/35/2005 - T. Christiansen additions
#               05/10/2005 - P. Harvey Decode encrypted lens data
#               [ongoing]  - P. Harvey Constantly decoding new information
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Joseph Heled private communication (tests with D70)
#               3) Thomas Walter private communication (tests with Coolpix 5400)
#               4) http://www.cybercom.net/~dcoffin/dcraw/
#               5) Brian Ristuccia private communication (tests with D70)
#               6) Danek Duvall private communication (tests with D70)
#               7) Tom Christiansen private communication (tests with D70)
#               8) Robert Rottmerhusen private communication
#               9) http://members.aol.com/khancock/pilot/nbuddy/
#              10) Werner Kober private communication (D2H, D2X, D100, D70, D200, D90)
#              11) http://www.rottmerhusen.com/objektives/lensid/thirdparty.html
#              12) http://libexif.sourceforge.net/internals/mnote-olympus-tag_8h-source.html
#              13) Roger Larsson private communication (tests with D200)
#              14) http://homepage3.nifty.com/kamisaka/makernote/makernote_nikon.htm (2007/09/15)
#              15) http://tomtia.plala.jp/DigitalCamera/MakerNote/index.asp
#              16) Jeffrey Friedl private communication (D200 with firmware update)
#              17) http://www.wohlberg.net/public/software/photo/nstiffexif/
#                  and Brendt Wohlberg private communication
#              18) Anonymous user private communication (D70, D200, D2x)
#              19) Bruce Stevens private communication
#              20) Vladimir Sauta private communication (D80)
#              21) Gregor Dorlars private communication (D300)
#              22) Tanel Kuusk private communication
#              23) Alexandre Naaman private communication (D3)
#              24) Geert De Soete private communication
#              26) Bozi (http://www.cpanforum.com/posts/8983)
#              27) Jens Kriese private communication
#              28) Warren Hatch private communication (D3v2.00 with SB-800 and SB-900)
#              29) Anonymous contribution 2011/05/25 (D700, D7000)
#              30) http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3833.30.html
#              31) Michael Relt private communication
#              32) Stefan http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,4494.0.html
#              34) Stewart Bennett private communication (D4S, D810)
#              35) David Puschel private communication
#              IB) Iliah Borg private communication (LibRaw)
#              JD) Jens Duttke private communication
#              NJ) Niels Kristian Bech Jensen private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Nikon;

use strict;
use vars qw($VERSION %nikonLensIDs %nikonTextEncoding);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '3.54';

sub LensIDConv($$$);
sub ProcessNikonAVI($$$);
sub ProcessNikonMOV($$$);
sub FormatString($);
sub ProcessNikonCaptureEditVersions($$$);
sub PrintAFPoints($$);
sub PrintAFPointsInv($$);
sub PrintAFPointsGrid($$);
sub PrintAFPointsGridInv($$$);
sub GetAFPointGrid($$;$);

# nikon lens ID numbers (ref 8/11)
%nikonLensIDs = (
    Notes => q{
        The Nikon LensID is constructed as a Composite tag from the raw hex values
        of 8 other tags: LensIDNumber, LensFStops, MinFocalLength, MaxFocalLength,
        MaxApertureAtMinFocal, MaxApertureAtMaxFocal, MCUVersion and LensType, in
        that order.  (source:
        L<http://www.rottmerhusen.com/objektives/lensid/thirdparty.html>.) Multiple
        lenses with the same LensID are differentiated by decimal values in the list
        below.  The user-defined "Lenses" list may be used to specify the lens for
        ExifTool to choose in these cases (see the
        L<sample config file|../config.html> for details).
    },
    OTHER => \&LensIDConv,
    # Note: Sync this list with Robert's Perl version at
    # http://www.rottmerhusen.com/objektives/lensid/files/exif/fmountlens.p.txt
    # (hex digits must be uppercase in keys below)
    '01 58 50 50 14 14 02 00' => 'AF Nikkor 50mm f/1.8',
    '01 58 50 50 14 14 05 00' => 'AF Nikkor 50mm f/1.8',
    '02 42 44 5C 2A 34 02 00' => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5',
    '02 42 44 5C 2A 34 08 00' => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5',
    '03 48 5C 81 30 30 02 00' => 'AF Zoom-Nikkor 70-210mm f/4',
    '04 48 3C 3C 24 24 03 00' => 'AF Nikkor 28mm f/2.8',
    '05 54 50 50 0C 0C 04 00' => 'AF Nikkor 50mm f/1.4',
    '06 54 53 53 24 24 06 00' => 'AF Micro-Nikkor 55mm f/2.8',
    '07 40 3C 62 2C 34 03 00' => 'AF Zoom-Nikkor 28-85mm f/3.5-4.5',
    '08 40 44 6A 2C 34 04 00' => 'AF Zoom-Nikkor 35-105mm f/3.5-4.5',
    '09 48 37 37 24 24 04 00' => 'AF Nikkor 24mm f/2.8',
    '0A 48 8E 8E 24 24 03 00' => 'AF Nikkor 300mm f/2.8 IF-ED',
    '0A 48 8E 8E 24 24 05 00' => 'AF Nikkor 300mm f/2.8 IF-ED N',
    '0B 48 7C 7C 24 24 05 00' => 'AF Nikkor 180mm f/2.8 IF-ED',
    '0D 40 44 72 2C 34 07 00' => 'AF Zoom-Nikkor 35-135mm f/3.5-4.5',
    '0E 48 5C 81 30 30 05 00' => 'AF Zoom-Nikkor 70-210mm f/4',
    '0F 58 50 50 14 14 05 00' => 'AF Nikkor 50mm f/1.8 N',
    '10 48 8E 8E 30 30 08 00' => 'AF Nikkor 300mm f/4 IF-ED',
    '11 48 44 5C 24 24 08 00' => 'AF Zoom-Nikkor 35-70mm f/2.8',
    '11 48 44 5C 24 24 15 00' => 'AF Zoom-Nikkor 35-70mm f/2.8', #Jakob Dettner
    '12 48 5C 81 30 3C 09 00' => 'AF Nikkor 70-210mm f/4-5.6',
    '13 42 37 50 2A 34 0B 00' => 'AF Zoom-Nikkor 24-50mm f/3.3-4.5',
    '14 48 60 80 24 24 0B 00' => 'AF Zoom-Nikkor 80-200mm f/2.8 ED',
    '15 4C 62 62 14 14 0C 00' => 'AF Nikkor 85mm f/1.8',
    '17 3C A0 A0 30 30 0F 00' => 'Nikkor 500mm f/4 P ED IF',
    '17 3C A0 A0 30 30 11 00' => 'Nikkor 500mm f/4 P ED IF',
    '18 40 44 72 2C 34 0E 00' => 'AF Zoom-Nikkor 35-135mm f/3.5-4.5 N',
    '1A 54 44 44 18 18 11 00' => 'AF Nikkor 35mm f/2',
    '1B 44 5E 8E 34 3C 10 00' => 'AF Zoom-Nikkor 75-300mm f/4.5-5.6',
    '1C 48 30 30 24 24 12 00' => 'AF Nikkor 20mm f/2.8',
    '1D 42 44 5C 2A 34 12 00' => 'AF Zoom-Nikkor 35-70mm f/3.3-4.5 N',
    '1E 54 56 56 24 24 13 00' => 'AF Micro-Nikkor 60mm f/2.8',
    '1F 54 6A 6A 24 24 14 00' => 'AF Micro-Nikkor 105mm f/2.8',
    '20 48 60 80 24 24 15 00' => 'AF Zoom-Nikkor 80-200mm f/2.8 ED',
    '21 40 3C 5C 2C 34 16 00' => 'AF Zoom-Nikkor 28-70mm f/3.5-4.5',
    '22 48 72 72 18 18 16 00' => 'AF DC-Nikkor 135mm f/2',
    '23 30 BE CA 3C 48 17 00' => 'Zoom-Nikkor 1200-1700mm f/5.6-8 P ED IF',
    '24 48 60 80 24 24 1A 02' => 'AF Zoom-Nikkor 80-200mm f/2.8D ED',
    '25 48 44 5C 24 24 1B 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D',
    '25 48 44 5C 24 24 3A 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D',
    '25 48 44 5C 24 24 52 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D',
    '26 40 3C 5C 2C 34 1C 02' => 'AF Zoom-Nikkor 28-70mm f/3.5-4.5D',
    '27 48 8E 8E 24 24 1D 02' => 'AF-I Nikkor 300mm f/2.8D IF-ED',
    '27 48 8E 8E 24 24 F1 02' => 'AF-I Nikkor 300mm f/2.8D IF-ED + TC-14E',
    '27 48 8E 8E 24 24 E1 02' => 'AF-I Nikkor 300mm f/2.8D IF-ED + TC-17E',
    '27 48 8E 8E 24 24 F2 02' => 'AF-I Nikkor 300mm f/2.8D IF-ED + TC-20E',
    '28 3C A6 A6 30 30 1D 02' => 'AF-I Nikkor 600mm f/4D IF-ED',
    '28 3C A6 A6 30 30 F1 02' => 'AF-I Nikkor 600mm f/4D IF-ED + TC-14E',
    '28 3C A6 A6 30 30 E1 02' => 'AF-I Nikkor 600mm f/4D IF-ED + TC-17E',
    '28 3C A6 A6 30 30 F2 02' => 'AF-I Nikkor 600mm f/4D IF-ED + TC-20E',
    '2A 54 3C 3C 0C 0C 26 02' => 'AF Nikkor 28mm f/1.4D',
    '2B 3C 44 60 30 3C 1F 02' => 'AF Zoom-Nikkor 35-80mm f/4-5.6D',
    '2C 48 6A 6A 18 18 27 02' => 'AF DC-Nikkor 105mm f/2D',
    '2D 48 80 80 30 30 21 02' => 'AF Micro-Nikkor 200mm f/4D IF-ED',
    '2E 48 5C 82 30 3C 22 02' => 'AF Nikkor 70-210mm f/4-5.6D',
    '2E 48 5C 82 30 3C 28 02' => 'AF Nikkor 70-210mm f/4-5.6D',
    '2F 48 30 44 24 24 29 02.1' => 'AF Zoom-Nikkor 20-35mm f/2.8D IF',
    '30 48 98 98 24 24 24 02' => 'AF-I Nikkor 400mm f/2.8D IF-ED',
    '30 48 98 98 24 24 F1 02' => 'AF-I Nikkor 400mm f/2.8D IF-ED + TC-14E',
    '30 48 98 98 24 24 E1 02' => 'AF-I Nikkor 400mm f/2.8D IF-ED + TC-17E',
    '30 48 98 98 24 24 F2 02' => 'AF-I Nikkor 400mm f/2.8D IF-ED + TC-20E',
    '31 54 56 56 24 24 25 02' => 'AF Micro-Nikkor 60mm f/2.8D',
    '32 54 6A 6A 24 24 35 02.1' => 'AF Micro-Nikkor 105mm f/2.8D',
    '33 48 2D 2D 24 24 31 02' => 'AF Nikkor 18mm f/2.8D',
    '34 48 29 29 24 24 32 02' => 'AF Fisheye Nikkor 16mm f/2.8D',
    '35 3C A0 A0 30 30 33 02' => 'AF-I Nikkor 500mm f/4D IF-ED',
    '35 3C A0 A0 30 30 F1 02' => 'AF-I Nikkor 500mm f/4D IF-ED + TC-14E',
    '35 3C A0 A0 30 30 E1 02' => 'AF-I Nikkor 500mm f/4D IF-ED + TC-17E',
    '35 3C A0 A0 30 30 F2 02' => 'AF-I Nikkor 500mm f/4D IF-ED + TC-20E',
    '36 48 37 37 24 24 34 02' => 'AF Nikkor 24mm f/2.8D',
    '37 48 30 30 24 24 36 02' => 'AF Nikkor 20mm f/2.8D',
    '38 4C 62 62 14 14 37 02' => 'AF Nikkor 85mm f/1.8D',
    '3A 40 3C 5C 2C 34 39 02' => 'AF Zoom-Nikkor 28-70mm f/3.5-4.5D',
    '3B 48 44 5C 24 24 3A 02' => 'AF Zoom-Nikkor 35-70mm f/2.8D N',
    '3C 48 60 80 24 24 3B 02' => 'AF Zoom-Nikkor 80-200mm f/2.8D ED', #NJ
    '3D 3C 44 60 30 3C 3E 02' => 'AF Zoom-Nikkor 35-80mm f/4-5.6D',
    '3E 48 3C 3C 24 24 3D 02' => 'AF Nikkor 28mm f/2.8D',
    '3F 40 44 6A 2C 34 45 02' => 'AF Zoom-Nikkor 35-105mm f/3.5-4.5D',
    '41 48 7C 7C 24 24 43 02' => 'AF Nikkor 180mm f/2.8D IF-ED',
    '42 54 44 44 18 18 44 02' => 'AF Nikkor 35mm f/2D',
    '43 54 50 50 0C 0C 46 02' => 'AF Nikkor 50mm f/1.4D',
    '44 44 60 80 34 3C 47 02' => 'AF Zoom-Nikkor 80-200mm f/4.5-5.6D',
    '45 40 3C 60 2C 3C 48 02' => 'AF Zoom-Nikkor 28-80mm f/3.5-5.6D',
    '46 3C 44 60 30 3C 49 02' => 'AF Zoom-Nikkor 35-80mm f/4-5.6D N',
    '47 42 37 50 2A 34 4A 02' => 'AF Zoom-Nikkor 24-50mm f/3.3-4.5D',
    '48 48 8E 8E 24 24 4B 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED',
    '48 48 8E 8E 24 24 F1 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED + TC-14E',
    '48 48 8E 8E 24 24 E1 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED + TC-17E',
    '48 48 8E 8E 24 24 F2 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED + TC-20E',
    '49 3C A6 A6 30 30 4C 02' => 'AF-S Nikkor 600mm f/4D IF-ED',
    '49 3C A6 A6 30 30 F1 02' => 'AF-S Nikkor 600mm f/4D IF-ED + TC-14E',
    '49 3C A6 A6 30 30 E1 02' => 'AF-S Nikkor 600mm f/4D IF-ED + TC-17E',
    '49 3C A6 A6 30 30 F2 02' => 'AF-S Nikkor 600mm f/4D IF-ED + TC-20E',
    '4A 54 62 62 0C 0C 4D 02' => 'AF Nikkor 85mm f/1.4D IF',
    '4B 3C A0 A0 30 30 4E 02' => 'AF-S Nikkor 500mm f/4D IF-ED',
    '4B 3C A0 A0 30 30 F1 02' => 'AF-S Nikkor 500mm f/4D IF-ED + TC-14E',
    '4B 3C A0 A0 30 30 E1 02' => 'AF-S Nikkor 500mm f/4D IF-ED + TC-17E',
    '4B 3C A0 A0 30 30 F2 02' => 'AF-S Nikkor 500mm f/4D IF-ED + TC-20E',
    '4C 40 37 6E 2C 3C 4F 02' => 'AF Zoom-Nikkor 24-120mm f/3.5-5.6D IF',
    '4D 40 3C 80 2C 3C 62 02' => 'AF Zoom-Nikkor 28-200mm f/3.5-5.6D IF',
    '4E 48 72 72 18 18 51 02' => 'AF DC-Nikkor 135mm f/2D',
    '4F 40 37 5C 2C 3C 53 06' => 'IX-Nikkor 24-70mm f/3.5-5.6',
    '50 48 56 7C 30 3C 54 06' => 'IX-Nikkor 60-180mm f/4-5.6',
    '53 48 60 80 24 24 57 02' => 'AF Zoom-Nikkor 80-200mm f/2.8D ED',
    '53 48 60 80 24 24 60 02' => 'AF Zoom-Nikkor 80-200mm f/2.8D ED',
    '54 44 5C 7C 34 3C 58 02' => 'AF Zoom-Micro Nikkor 70-180mm f/4.5-5.6D ED',
    '54 44 5C 7C 34 3C 61 02' => 'AF Zoom-Micro Nikkor 70-180mm f/4.5-5.6D ED',
    '56 48 5C 8E 30 3C 5A 02' => 'AF Zoom-Nikkor 70-300mm f/4-5.6D ED',
    '59 48 98 98 24 24 5D 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED',
    '59 48 98 98 24 24 F1 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED + TC-14E',
    '59 48 98 98 24 24 E1 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED + TC-17E',
    '59 48 98 98 24 24 F2 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED + TC-20E',
    '5A 3C 3E 56 30 3C 5E 06' => 'IX-Nikkor 30-60mm f/4-5.6',
    '5B 44 56 7C 34 3C 5F 06' => 'IX-Nikkor 60-180mm f/4.5-5.6',
    '5D 48 3C 5C 24 24 63 02' => 'AF-S Zoom-Nikkor 28-70mm f/2.8D IF-ED',
    '5E 48 60 80 24 24 64 02' => 'AF-S Zoom-Nikkor 80-200mm f/2.8D IF-ED',
    '5F 40 3C 6A 2C 34 65 02' => 'AF Zoom-Nikkor 28-105mm f/3.5-4.5D IF',
    '60 40 3C 60 2C 3C 66 02' => 'AF Zoom-Nikkor 28-80mm f/3.5-5.6D', #(http://www.exif.org/forum/topic.asp?TOPIC_ID=16)
    '61 44 5E 86 34 3C 67 02' => 'AF Zoom-Nikkor 75-240mm f/4.5-5.6D',
    '63 48 2B 44 24 24 68 02' => 'AF-S Nikkor 17-35mm f/2.8D IF-ED',
    '64 00 62 62 24 24 6A 02' => 'PC Micro-Nikkor 85mm f/2.8D',
    '65 44 60 98 34 3C 6B 0A' => 'AF VR Zoom-Nikkor 80-400mm f/4.5-5.6D ED',
    '66 40 2D 44 2C 34 6C 02' => 'AF Zoom-Nikkor 18-35mm f/3.5-4.5D IF-ED',
    '67 48 37 62 24 30 6D 02' => 'AF Zoom-Nikkor 24-85mm f/2.8-4D IF',
    '68 42 3C 60 2A 3C 6E 06' => 'AF Zoom-Nikkor 28-80mm f/3.3-5.6G',
    '69 48 5C 8E 30 3C 6F 06' => 'AF Zoom-Nikkor 70-300mm f/4-5.6G',
    '6A 48 8E 8E 30 30 70 02' => 'AF-S Nikkor 300mm f/4D IF-ED',
    '6B 48 24 24 24 24 71 02' => 'AF Nikkor ED 14mm f/2.8D',
    '6D 48 8E 8E 24 24 73 02' => 'AF-S Nikkor 300mm f/2.8D IF-ED II',
    '6E 48 98 98 24 24 74 02' => 'AF-S Nikkor 400mm f/2.8D IF-ED II',
    '6F 3C A0 A0 30 30 75 02' => 'AF-S Nikkor 500mm f/4D IF-ED II',
    '70 3C A6 A6 30 30 76 02' => 'AF-S Nikkor 600mm f/4D IF-ED II',
    '72 48 4C 4C 24 24 77 00' => 'Nikkor 45mm f/2.8 P',
    '74 40 37 62 2C 34 78 06' => 'AF-S Zoom-Nikkor 24-85mm f/3.5-4.5G IF-ED',
    '75 40 3C 68 2C 3C 79 06' => 'AF Zoom-Nikkor 28-100mm f/3.5-5.6G',
    '76 58 50 50 14 14 7A 02' => 'AF Nikkor 50mm f/1.8D',
    '77 48 5C 80 24 24 7B 0E' => 'AF-S VR Zoom-Nikkor 70-200mm f/2.8G IF-ED',
    '78 40 37 6E 2C 3C 7C 0E' => 'AF-S VR Zoom-Nikkor 24-120mm f/3.5-5.6G IF-ED',
    '79 40 3C 80 2C 3C 7F 06' => 'AF Zoom-Nikkor 28-200mm f/3.5-5.6G IF-ED',
    '7A 3C 1F 37 30 30 7E 06.1' => 'AF-S DX Zoom-Nikkor 12-24mm f/4G IF-ED',
    '7B 48 80 98 30 30 80 0E' => 'AF-S VR Zoom-Nikkor 200-400mm f/4G IF-ED',
    '7D 48 2B 53 24 24 82 06' => 'AF-S DX Zoom-Nikkor 17-55mm f/2.8G IF-ED',
    '7F 40 2D 5C 2C 34 84 06' => 'AF-S DX Zoom-Nikkor 18-70mm f/3.5-4.5G IF-ED',
    '80 48 1A 1A 24 24 85 06' => 'AF DX Fisheye-Nikkor 10.5mm f/2.8G ED',
    '81 54 80 80 18 18 86 0E' => 'AF-S VR Nikkor 200mm f/2G IF-ED',
    '82 48 8E 8E 24 24 87 0E' => 'AF-S VR Nikkor 300mm f/2.8G IF-ED',
    '83 00 B0 B0 5A 5A 88 04' => 'FSA-L2, EDG 65, 800mm F13 G',
    '89 3C 53 80 30 3C 8B 06' => 'AF-S DX Zoom-Nikkor 55-200mm f/4-5.6G ED',
    '8A 54 6A 6A 24 24 8C 0E' => 'AF-S VR Micro-Nikkor 105mm f/2.8G IF-ED', #10
    # when the TC-20 III 2x teleconverter is used with the above lens, the following have been observed:
    # 8A 4D 6A 6A 24 24 8C 0E
    # 8A 4E 6A 6A 24 24 8C 0E
    # 8A 50 6A 6A 24 24 8C 0E
    # 8A 51 6A 6A 24 24 8C 0E
    # 8A 52 6A 6A 24 24 8C 0E
    # 8A 53 6A 6A 24 24 8C 0E
    # 8A 54 6A 6A 24 24 8C 0E (same as without the TC)
    '8B 40 2D 80 2C 3C 8D 0E' => 'AF-S DX VR Zoom-Nikkor 18-200mm f/3.5-5.6G IF-ED',
    '8B 40 2D 80 2C 3C FD 0E' => 'AF-S DX VR Zoom-Nikkor 18-200mm f/3.5-5.6G IF-ED [II]', #20
    '8C 40 2D 53 2C 3C 8E 06' => 'AF-S DX Zoom-Nikkor 18-55mm f/3.5-5.6G ED',
    '8D 44 5C 8E 34 3C 8F 0E' => 'AF-S VR Zoom-Nikkor 70-300mm f/4.5-5.6G IF-ED', #10
    '8F 40 2D 72 2C 3C 91 06' => 'AF-S DX Zoom-Nikkor 18-135mm f/3.5-5.6G IF-ED',
    '90 3B 53 80 30 3C 92 0E' => 'AF-S DX VR Zoom-Nikkor 55-200mm f/4-5.6G IF-ED',
    '92 48 24 37 24 24 94 06' => 'AF-S Zoom-Nikkor 14-24mm f/2.8G ED',
    '93 48 37 5C 24 24 95 06' => 'AF-S Zoom-Nikkor 24-70mm f/2.8G ED',
    '94 40 2D 53 2C 3C 96 06' => 'AF-S DX Zoom-Nikkor 18-55mm f/3.5-5.6G ED II', #10 (D40)
    '95 4C 37 37 2C 2C 97 02' => 'PC-E Nikkor 24mm f/3.5D ED',
    '95 00 37 37 2C 2C 97 06' => 'PC-E Nikkor 24mm f/3.5D ED', #JD
    '96 48 98 98 24 24 98 0E' => 'AF-S VR Nikkor 400mm f/2.8G ED',
    '97 3C A0 A0 30 30 99 0E' => 'AF-S VR Nikkor 500mm f/4G ED',
    '98 3C A6 A6 30 30 9A 0E' => 'AF-S VR Nikkor 600mm f/4G ED',
    '99 40 29 62 2C 3C 9B 0E' => 'AF-S DX VR Zoom-Nikkor 16-85mm f/3.5-5.6G ED',
    '9A 40 2D 53 2C 3C 9C 0E' => 'AF-S DX VR Zoom-Nikkor 18-55mm f/3.5-5.6G',
    '9B 54 4C 4C 24 24 9D 02' => 'PC-E Micro Nikkor 45mm f/2.8D ED',
    '9B 00 4C 4C 24 24 9D 06' => 'PC-E Micro Nikkor 45mm f/2.8D ED',
    '9C 54 56 56 24 24 9E 06' => 'AF-S Micro Nikkor 60mm f/2.8G ED',
    '9D 54 62 62 24 24 9F 02' => 'PC-E Micro Nikkor 85mm f/2.8D',
    '9D 00 62 62 24 24 9F 06' => 'PC-E Micro Nikkor 85mm f/2.8D',
    '9E 40 2D 6A 2C 3C A0 0E' => 'AF-S DX VR Zoom-Nikkor 18-105mm f/3.5-5.6G ED', #PH/10
    '9F 58 44 44 14 14 A1 06' => 'AF-S DX Nikkor 35mm f/1.8G', #27
    'A0 54 50 50 0C 0C A2 06' => 'AF-S Nikkor 50mm f/1.4G',
    'A1 40 18 37 2C 34 A3 06' => 'AF-S DX Nikkor 10-24mm f/3.5-4.5G ED',
    'A2 48 5C 80 24 24 A4 0E' => 'AF-S Nikkor 70-200mm f/2.8G ED VR II',
    'A3 3C 29 44 30 30 A5 0E' => 'AF-S Nikkor 16-35mm f/4G ED VR',
    'A4 54 37 37 0C 0C A6 06' => 'AF-S Nikkor 24mm f/1.4G ED',
    'A5 40 3C 8E 2C 3C A7 0E' => 'AF-S Nikkor 28-300mm f/3.5-5.6G ED VR',
    'A6 48 8E 8E 24 24 A8 0E' => 'AF-S Nikkor 300mm f/2.8G IF-ED VR II',
    'A7 4B 62 62 2C 2C A9 0E' => 'AF-S DX Micro Nikkor 85mm f/3.5G ED VR',
    'A8 48 80 98 30 30 AA 0E' => 'AF-S Zoom-Nikkor 200-400mm f/4G IF-ED VR II', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3218.msg15495.html#msg15495
    'A9 54 80 80 18 18 AB 0E' => 'AF-S Nikkor 200mm f/2G ED VR II',
    'AA 3C 37 6E 30 30 AC 0E' => 'AF-S Nikkor 24-120mm f/4G ED VR',
    'AC 38 53 8E 34 3C AE 0E' => 'AF-S DX Nikkor 55-300mm f/4.5-5.6G ED VR',
    'AD 3C 2D 8E 2C 3C AF 0E' => 'AF-S DX Nikkor 18-300mm f/3.5-5.6G ED VR',
    'AE 54 62 62 0C 0C B0 06' => 'AF-S Nikkor 85mm f/1.4G',
    'AF 54 44 44 0C 0C B1 06' => 'AF-S Nikkor 35mm f/1.4G',
    'B0 4C 50 50 14 14 B2 06' => 'AF-S Nikkor 50mm f/1.8G',
    'B1 48 48 48 24 24 B3 06' => 'AF-S DX Micro Nikkor 40mm f/2.8G', #27
    'B2 48 5C 80 30 30 B4 0E' => 'AF-S Nikkor 70-200mm f/4G ED VR', #35
    'B3 4C 62 62 14 14 B5 06' => 'AF-S Nikkor 85mm f/1.8G',
    'B4 40 37 62 2C 34 B6 0E' => 'AF-S Zoom-Nikkor 24-85mm f/3.5-4.5G IF-ED VR', #30
    'B5 4C 3C 3C 14 14 B7 06' => 'AF-S Nikkor 28mm f/1.8G', #30
    'B6 3C B0 B0 3C 3C B8 0E' => 'AF-S VR Nikkor 800mm f/5.6E FL ED',
    'B6 3C B0 B0 3C 3C B8 4E' => 'AF-S VR Nikkor 800mm f/5.6E FL ED', #PH
    'B7 44 60 98 34 3C B9 0E' => 'AF-S Nikkor 80-400mm f/4.5-5.6G ED VR',
    'B8 40 2D 44 2C 34 BA 06' => 'AF-S Nikkor 18-35mm f/3.5-4.5G ED',
    'A0 40 2D 74 2C 3C BB 0E' => 'AF-S DX Nikkor 18-140mm f/3.5-5.6G ED VR', #PH
    'A1 54 55 55 0C 0C BC 06' => 'AF-S Nikkor 58mm f/1.4G', #IB
    'A2 40 2D 53 2C 3C BD 0E' => 'AF-S DX Nikkor 18-55mm f/3.5-5.6G VR II',
    'A4 40 2D 8E 2C 40 BF 0E' => 'AF-S DX Nikkor 18-300mm f/3.5-6.3G ED VR',
    'A5 4C 44 44 14 14 C0 06' => 'AF-S Nikkor 35mm f/1.8G ED', #35 ("ED" ref 11)
    'A6 48 98 98 24 24 C1 0E' => 'AF-S Nikkor 400mm f/2.8E FL ED VR',
    'A7 3C 53 80 30 3C C2 0E' => 'AF-S DX Nikkor 55-200mm f/4-5.6G ED VR II', #IB
    'A8 48 8E 8E 30 30 C3 4E' => 'AF-S Nikkor 300mm f/4E PF ED VR', #35
    'A8 48 8E 8E 30 30 C3 0E' => 'AF-S Nikkor 300mm f/4E PF ED VR', #30
    'A9 4C 31 31 14 14 C4 06' => 'AF-S Nikkor 20mm f/1.8G ED', #30
    'AA 48 37 5C 24 24 C5 4E' => 'AF-S Nikkor 24-70mm f/2.8E ED VR',
    'AA 48 37 5C 24 24 C5 0E' => 'AF-S Nikkor 24-70mm f/2.8E ED VR',
    'AB 3C A0 A0 30 30 C6 4E' => 'AF-S Nikkor 500mm f/4E FL ED VR',
    'AC 3C A6 A6 30 30 C7 4E' => 'AF-S Nikkor 600mm f/4E FL ED VR', #PH
    'AD 48 28 60 24 30 C8 4E' => 'AF-S DX Nikkor 16-80mm f/2.8-4E ED VR',
    'AD 48 28 60 24 30 C8 0E' => 'AF-S DX Nikkor 16-80mm f/2.8-4E ED VR', #PH
    'AE 3C 80 A0 3C 3C C9 4E' => 'AF-S Nikkor 200-500mm f/5.6E ED VR', #PH
    'AE 3C 80 A0 3C 3C C9 0E' => 'AF-S Nikkor 200-500mm f/5.6E ED VR',
    'A0 40 2D 53 2C 3C CA 8E' => 'AF-P DX Nikkor 18-55mm f/3.5-5.6G', #Yang You pvt communication
    'A0 40 2D 53 2C 3C CA 0E' => 'AF-P DX Nikkor 18-55mm f/3.5-5.6G VR', #PH
    'AF 4C 37 37 14 14 CC 06' => 'AF-S Nikkor 24mm f/1.8G ED', #IB
    'A3 38 5C 8E 34 40 CE 8E' => 'AF-P DX Nikkor 70-300mm f/4.5-6.3G ED VR',
    'A3 38 5C 8E 34 40 CE 0E' => 'AF-P DX Nikkor 70-300mm f/4.5-6.3G ED',
    'A4 48 5C 80 24 24 CF 4E' => 'AF-S Nikkor 70-200mm f/2.8E FL ED VR',
    'A4 48 5C 80 24 24 CF 0E' => 'AF-S Nikkor 70-200mm f/2.8E FL ED VR',
    'A5 54 6A 6A 0C 0C D0 46' => 'AF-S Nikkor 105mm f/1.4E ED', #IB
    'A5 54 6A 6A 0C 0C D0 06' => 'AF-S Nikkor 105mm f/1.4E ED', #IB
    'A6 48 2F 2F 30 30 D1 46' => 'PC Nikkor 19mm f/4E ED',
    'A6 48 2F 2F 30 30 D1 06' => 'PC Nikkor 19mm f/4E ED',
    'A7 40 11 26 2C 34 D2 46' => 'AF-S Fisheye Nikkor 8-15mm f/3.5-4.5E ED',
    'A7 40 11 26 2C 34 D2 06' => 'AF-S Fisheye Nikkor 8-15mm f/3.5-4.5E ED',
    'A8 38 18 30 34 3C D3 8E' => 'AF-P DX Nikkor 10-20mm f/4.5-5.6G VR', #Yang You pvt communication
    'A8 38 18 30 34 3C D3 0E' => 'AF-P DX Nikkor 10-20mm f/4.5-5.6G VR',
    'A9 48 7C 98 30 30 D4 4E' => 'AF-S Nikkor 180-400mm f/4E TC1.4 FL ED VR', #IB
    'A9 48 7C 98 30 30 D4 0E' => 'AF-S Nikkor 180-400mm f/4E TC1.4 FL ED VR',
    'AA 48 88 A4 3C 3C D5 4E' => 'AF-S Nikkor 180-400mm f/4E TC1.4 FL ED VR + 1.4x TC', #IB
    'AA 48 88 A4 3C 3C D5 0E' => 'AF-S Nikkor 180-400mm f/4E TC1.4 FL ED VR + 1.4x TC',
    'AB 44 5C 8E 34 3C D6 CE' => 'AF-P Nikkor 70-300mm f/4.5-5.6E ED VR',
    'AB 44 5C 8E 34 3C D6 0E' => 'AF-P Nikkor 70-300mm f/4.5-5.6E ED VR',
    'AC 54 3C 3C 0C 0C D7 46' => 'AF-S Nikkor 28mm f/1.4E ED',
    'AC 54 3C 3C 0C 0C D7 06' => 'AF-S Nikkor 28mm f/1.4E ED',
    'AD 3C A0 A0 3C 3C D8 0E' => 'AF-S Nikkor 500mm f/5.6E PF ED VR',
    'AD 3C A0 A0 3C 3C D8 4E' => 'AF-S Nikkor 500mm f/5.6E PF ED VR',
    '01 00 00 00 00 00 02 00' => 'TC-16A',
    '01 00 00 00 00 00 08 00' => 'TC-16A',
    '00 00 00 00 00 00 F1 0C' => 'TC-14E [II] or Sigma APO Tele Converter 1.4x EX DG or Kenko Teleplus PRO 300 DG 1.4x',
    '00 00 00 00 00 00 F2 18' => 'TC-20E [II] or Sigma APO Tele Converter 2x EX DG or Kenko Teleplus PRO 300 DG 2.0x',
    '00 00 00 00 00 00 E1 12' => 'TC-17E II',
    'FE 47 00 00 24 24 4B 06' => 'Sigma 4.5mm F2.8 EX DC HSM Circular Fisheye', #JD
    '26 48 11 11 30 30 1C 02' => 'Sigma 8mm F4 EX Circular Fisheye',
    '79 40 11 11 2C 2C 1C 06' => 'Sigma 8mm F3.5 EX Circular Fisheye', #JD
    'DC 48 19 19 24 24 4B 06' => 'Sigma 10mm F2.8 EX DC HSM Fisheye',
    'C2 4C 24 24 14 14 4B 06' => 'Sigma 14mm F1.8 DG HSM | A', #IB
    '48 48 24 24 24 24 4B 02' => 'Sigma 14mm F2.8 EX Aspherical HSM',
    '02 3F 24 24 2C 2C 02 00' => 'Sigma 14mm F3.5',
    '26 48 27 27 24 24 1C 02' => 'Sigma 15mm F2.8 EX Diagonal Fisheye',
    'EA 48 27 27 24 24 1C 02' => 'Sigma 15mm F2.8 EX Diagonal Fisheye', #30
    '26 58 31 31 14 14 1C 02' => 'Sigma 20mm F1.8 EX DG Aspherical RF',
    '79 54 31 31 0C 0C 4B 06' => 'Sigma 20mm F1.4 DG HSM | A', #Rolf Probst
    '26 58 37 37 14 14 1C 02' => 'Sigma 24mm F1.8 EX DG Aspherical Macro',
    'E1 58 37 37 14 14 1C 02' => 'Sigma 24mm F1.8 EX DG Aspherical Macro',
    '02 46 37 37 25 25 02 00' => 'Sigma 24mm F2.8 Super Wide II Macro',
    '26 58 3C 3C 14 14 1C 02' => 'Sigma 28mm F1.8 EX DG Aspherical Macro',
    '48 54 3E 3E 0C 0C 4B 06' => 'Sigma 30mm F1.4 EX DC HSM',
    'F8 54 3E 3E 0C 0C 4B 06' => 'Sigma 30mm F1.4 EX DC HSM', #JD
    '91 54 44 44 0C 0C 4B 06' => 'Sigma 35mm F1.4 DG HSM', #30
    'DE 54 50 50 0C 0C 4B 06' => 'Sigma 50mm F1.4 EX DG HSM',
    '88 54 50 50 0C 0C 4B 06' => 'Sigma 50mm F1.4 DG HSM | A',
    '02 48 50 50 24 24 02 00' => 'Sigma Macro 50mm F2.8', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,4027.0.html
    '32 54 50 50 24 24 35 02' => 'Sigma Macro 50mm F2.8 EX DG',
    'E3 54 50 50 24 24 35 02' => 'Sigma Macro 50mm F2.8 EX DG', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3215.0.html
    '79 48 5C 5C 24 24 1C 06' => 'Sigma Macro 70mm F2.8 EX DG', #JD
    '9B 54 62 62 0C 0C 4B 06' => 'Sigma 85mm F1.4 EX DG HSM',
    'C8 54 62 62 0C 0C 4B 46' => 'Sigma 85mm F1.4 DG HSM | A', #JamiBradley
    '02 48 65 65 24 24 02 00' => 'Sigma Macro 90mm F2.8',
    '32 54 6A 6A 24 24 35 02.2' => 'Sigma Macro 105mm F2.8 EX DG', #JD
    'E5 54 6A 6A 24 24 35 02' => 'Sigma Macro 105mm F2.8 EX DG',
    '97 48 6A 6A 24 24 4B 0E' => 'Sigma Macro 105mm F2.8 EX DG OS HSM',
    '48 48 76 76 24 24 4B 06' => 'Sigma APO Macro 150mm F2.8 EX DG HSM',
    'F5 48 76 76 24 24 4B 06' => 'Sigma APO Macro 150mm F2.8 EX DG HSM', #24
    '99 48 76 76 24 24 4B 0E' => 'Sigma APO Macro 150mm F2.8 EX DG OS HSM', #(Christian Hesse)
    '48 4C 7C 7C 2C 2C 4B 02' => 'Sigma APO Macro 180mm F3.5 EX DG HSM',
    '48 4C 7D 7D 2C 2C 4B 02' => 'Sigma APO Macro 180mm F3.5 EX DG HSM',
    '94 48 7C 7C 24 24 4B 0E' => 'Sigma APO Macro 180mm F2.8 EX DG OS HSM', #MichaelTapes (HSM from ref 8)
    '48 54 8E 8E 24 24 4B 02' => 'Sigma APO 300mm F2.8 EX DG HSM',
    'FB 54 8E 8E 24 24 4B 02' => 'Sigma APO 300mm F2.8 EX DG HSM', #26
    '26 48 8E 8E 30 30 1C 02' => 'Sigma APO Tele Macro 300mm F4',
    '02 2F 98 98 3D 3D 02 00' => 'Sigma APO 400mm F5.6',
    '26 3C 98 98 3C 3C 1C 02' => 'Sigma APO Tele Macro 400mm F5.6',
    '02 37 A0 A0 34 34 02 00' => 'Sigma APO 500mm F4.5', #19
    '48 44 A0 A0 34 34 4B 02' => 'Sigma APO 500mm F4.5 EX HSM',
    'F1 44 A0 A0 34 34 4B 02' => 'Sigma APO 500mm F4.5 EX DG HSM',
    '02 34 A0 A0 44 44 02 00' => 'Sigma APO 500mm F7.2',
    '02 3C B0 B0 3C 3C 02 00' => 'Sigma APO 800mm F5.6',
    '48 3C B0 B0 3C 3C 4B 02' => 'Sigma APO 800mm F5.6 EX HSM',
    '9E 38 11 29 34 3C 4B 06' => 'Sigma 8-16mm F4.5-5.6 DC HSM',
    'A1 41 19 31 2C 2C 4B 06' => 'Sigma 10-20mm F3.5 EX DC HSM',
    '48 3C 19 31 30 3C 4B 06' => 'Sigma 10-20mm F4-5.6 EX DC HSM',
    'F9 3C 19 31 30 3C 4B 06' => 'Sigma 10-20mm F4-5.6 EX DC HSM', #JD
    '48 38 1F 37 34 3C 4B 06' => 'Sigma 12-24mm F4.5-5.6 EX DG Aspherical HSM',
    'F0 38 1F 37 34 3C 4B 06' => 'Sigma 12-24mm F4.5-5.6 EX DG Aspherical HSM',
    '96 38 1F 37 34 3C 4B 06' => 'Sigma 12-24mm F4.5-5.6 II DG HSM', #Jurgen Sahlberg
    'C1 48 24 37 24 24 4B 46' => 'Sigma 14-24mm F2.8 DG HSM | A', #30
    '26 40 27 3F 2C 34 1C 02' => 'Sigma 15-30mm F3.5-4.5 EX DG Aspherical DF',
    '48 48 2B 44 24 30 4B 06' => 'Sigma 17-35mm F2.8-4 EX DG  Aspherical HSM',
    '26 54 2B 44 24 30 1C 02' => 'Sigma 17-35mm F2.8-4 EX Aspherical',
    '9D 48 2B 50 24 24 4B 0E' => 'Sigma 17-50mm F2.8 EX DC OS HSM',
    '8F 48 2B 50 24 24 4B 0E' => 'Sigma 17-50mm F2.8 EX DC OS HSM', #http://dev.exiv2.org/boards/3/topics/1747
    '7A 47 2B 5C 24 34 4B 06' => 'Sigma 17-70mm F2.8-4.5 DC Macro Asp. IF HSM',
    '7A 48 2B 5C 24 34 4B 06' => 'Sigma 17-70mm F2.8-4.5 DC Macro Asp. IF HSM',
    '7F 48 2B 5C 24 34 1C 06' => 'Sigma 17-70mm F2.8-4.5 DC Macro Asp. IF',
    '8E 3C 2B 5C 24 30 4B 0E' => 'Sigma 17-70mm F2.8-4 DC Macro OS HSM | C',
    'A0 48 2A 5C 24 30 4B 0E' => 'Sigma 17-70mm F2.8-4 DC Macro OS HSM', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,5170.0.html
    '8B 4C 2D 44 14 14 4B 06' => 'Sigma 18-35mm F1.8 DC HSM', #30/NJ
    '26 40 2D 44 2B 34 1C 02' => 'Sigma 18-35mm F3.5-4.5 Aspherical',
    '26 48 2D 50 24 24 1C 06' => 'Sigma 18-50mm F2.8 EX DC',
    '7F 48 2D 50 24 24 1C 06' => 'Sigma 18-50mm F2.8 EX DC Macro', #NJ
    '7A 48 2D 50 24 24 4B 06' => 'Sigma 18-50mm F2.8 EX DC Macro',
    'F6 48 2D 50 24 24 4B 06' => 'Sigma 18-50mm F2.8 EX DC Macro',
    'A4 47 2D 50 24 34 4B 0E' => 'Sigma 18-50mm F2.8-4.5 DC OS HSM',
    '26 40 2D 50 2C 3C 1C 06' => 'Sigma 18-50mm F3.5-5.6 DC',
    '7A 40 2D 50 2C 3C 4B 06' => 'Sigma 18-50mm F3.5-5.6 DC HSM',
    '26 40 2D 70 2B 3C 1C 06' => 'Sigma 18-125mm F3.5-5.6 DC',
    'CD 3D 2D 70 2E 3C 4B 0E' => 'Sigma 18-125mm F3.8-5.6 DC OS HSM',
    '26 40 2D 80 2C 40 1C 06' => 'Sigma 18-200mm F3.5-6.3 DC',
    'FF 40 2D 80 2C 40 4B 06' => 'Sigma 18-200mm F3.5-6.3 DC', #30
    '7A 40 2D 80 2C 40 4B 0E' => 'Sigma 18-200mm F3.5-6.3 DC OS HSM',
    'ED 40 2D 80 2C 40 4B 0E' => 'Sigma 18-200mm F3.5-6.3 DC OS HSM', #JD
    '90 40 2D 80 2C 40 4B 0E' => 'Sigma 18-200mm F3.5-6.3 II DC OS HSM', #JohnHelour
    'A5 40 2D 88 2C 40 4B 0E' => 'Sigma 18-250mm F3.5-6.3 DC OS HSM',
  #  LensFStops varies with FocalLength for this lens (ref 2):
    '92 2C 2D 88 2C 40 4B 0E' => 'Sigma 18-250mm F3.5-6.3 DC Macro OS HSM', #2
  # '92 2C 2D 88 2C 40 4B 0E' (250mm)
  # '92 2B 2D 88 2C 40 4B 0E' (210mm)
  # '92 2C 2D 88 2C 40 4B 0E' (185mm)
  # '92 2D 2D 88 2C 40 4B 0E' (155mm)
  # '92 2E 2D 88 2C 40 4B 0E' (130mm)
  # '92 2F 2D 88 2C 40 4B 0E' (105mm)
  # '92 30 2D 88 2C 40 4B 0E' (90mm)
  # '92 32 2D 88 2C 40 4B 0E' (75mm)
  # '92 33 2D 88 2C 40 4B 0E' (62mm)
  # '92 35 2D 88 2C 40 4B 0E' (52mm)
  # '92 37 2D 88 2C 40 4B 0E' (44mm)
  # '92 39 2D 88 2C 40 4B 0E' (38mm)
  # '92 3A 2D 88 2C 40 4B 0E' (32mm)
  # '92 3E 2D 88 2C 40 4B 0E' (22mm)
  # '92 40 2D 88 2C 40 4B 0E' (18mm)
    '26 48 31 49 24 24 1C 02' => 'Sigma 20-40mm F2.8',
    '02 3A 37 50 31 3D 02 00' => 'Sigma 24-50mm F4-5.6 UC',
    '26 48 37 56 24 24 1C 02' => 'Sigma 24-60mm F2.8 EX DG',
    'B6 48 37 56 24 24 1C 02' => 'Sigma 24-60mm F2.8 EX DG',
    'A6 48 37 5C 24 24 4B 06' => 'Sigma 24-70mm F2.8 IF EX DG HSM', #JD
    'C9 48 37 5C 24 24 4B 4E' => 'Sigma 24-70mm F2.8 DG OS HSM | A', #30
    '26 54 37 5C 24 24 1C 02' => 'Sigma 24-70mm F2.8 EX DG Macro',
    '67 54 37 5C 24 24 1C 02' => 'Sigma 24-70mm F2.8 EX DG Macro',
    'E9 54 37 5C 24 24 1C 02' => 'Sigma 24-70mm F2.8 EX DG Macro',
    '26 40 37 5C 2C 3C 1C 02' => 'Sigma 24-70mm F3.5-5.6 Aspherical HF',
    '8A 3C 37 6A 30 30 4B 0E' => 'Sigma 24-105mm F4 DG OS HSM', #IB
    '26 54 37 73 24 34 1C 02' => 'Sigma 24-135mm F2.8-4.5',
    '02 46 3C 5C 25 25 02 00' => 'Sigma 28-70mm F2.8',
    '26 54 3C 5C 24 24 1C 02' => 'Sigma 28-70mm F2.8 EX',
    '26 48 3C 5C 24 24 1C 06' => 'Sigma 28-70mm F2.8 EX DG',
    '79 48 3C 5C 24 24 1C 06' => 'Sigma 28-70mm F2.8 EX DG', #30 ("D" removed)
    '26 48 3C 5C 24 30 1C 02' => 'Sigma 28-70mm F2.8-4 DG',
    '02 3F 3C 5C 2D 35 02 00' => 'Sigma 28-70mm F3.5-4.5 UC',
    '26 40 3C 60 2C 3C 1C 02' => 'Sigma 28-80mm F3.5-5.6 Mini Zoom Macro II Aspherical',
    '26 40 3C 65 2C 3C 1C 02' => 'Sigma 28-90mm F3.5-5.6 Macro',
    '26 48 3C 6A 24 30 1C 02' => 'Sigma 28-105mm F2.8-4 Aspherical',
    '26 3E 3C 6A 2E 3C 1C 02' => 'Sigma 28-105mm F3.8-5.6 UC-III Aspherical IF',
    '26 40 3C 80 2C 3C 1C 02' => 'Sigma 28-200mm F3.5-5.6 Compact Aspherical Hyperzoom Macro',
    '26 40 3C 80 2B 3C 1C 02' => 'Sigma 28-200mm F3.5-5.6 Compact Aspherical Hyperzoom Macro',
    '26 3D 3C 80 2F 3D 1C 02' => 'Sigma 28-300mm F3.8-5.6 Aspherical',
    '26 41 3C 8E 2C 40 1C 02' => 'Sigma 28-300mm F3.5-6.3 DG Macro',
    'E6 41 3C 8E 2C 40 1C 02' => 'Sigma 28-300mm F3.5-6.3 DG Macro', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3301.0.html
    '26 40 3C 8E 2C 40 1C 02' => 'Sigma 28-300mm F3.5-6.3 Macro',
    '02 3B 44 61 30 3D 02 00' => 'Sigma 35-80mm F4-5.6',
    '02 40 44 73 2B 36 02 00' => 'Sigma 35-135mm F3.5-4.5 a',
    'CC 4C 50 68 14 14 4B 06' => 'Sigma 50-100mm F1.8 DC HSM | A', #30
    '7A 47 50 76 24 24 4B 06' => 'Sigma 50-150mm F2.8 EX APO DC HSM',
    'FD 47 50 76 24 24 4B 06' => 'Sigma 50-150mm F2.8 EX APO DC HSM II',
    '98 48 50 76 24 24 4B 0E' => 'Sigma 50-150mm F2.8 EX APO DC OS HSM', #30
    '48 3C 50 A0 30 40 4B 02' => 'Sigma 50-500mm F4-6.3 EX APO RF HSM',
    '9F 37 50 A0 34 40 4B 0E' => 'Sigma 50-500mm F4.5-6.3 DG OS HSM', #16
    '26 3C 54 80 30 3C 1C 06' => 'Sigma 55-200mm F4-5.6 DC',
    '7A 3B 53 80 30 3C 4B 06' => 'Sigma 55-200mm F4-5.6 DC HSM',
    '48 54 5C 80 24 24 4B 02' => 'Sigma 70-200mm F2.8 EX APO IF HSM',
    '7A 48 5C 80 24 24 4B 06' => 'Sigma 70-200mm F2.8 EX APO DG Macro HSM II',
    'EE 48 5C 80 24 24 4B 06' => 'Sigma 70-200mm F2.8 EX APO DG Macro HSM II', #JD
    '9C 48 5C 80 24 24 4B 0E' => 'Sigma 70-200mm F2.8 EX DG OS HSM', #Rolando Ruzic
    '02 46 5C 82 25 25 02 00' => 'Sigma 70-210mm F2.8 APO', #JD
    '02 40 5C 82 2C 35 02 00' => 'Sigma APO 70-210mm F3.5-4.5',
    '26 3C 5C 82 30 3C 1C 02' => 'Sigma 70-210mm F4-5.6 UC-II',
    '26 3C 5C 8E 30 3C 1C 02' => 'Sigma 70-300mm F4-5.6 DG Macro',
    '56 3C 5C 8E 30 3C 1C 02' => 'Sigma 70-300mm F4-5.6 APO Macro Super II',
    'E0 3C 5C 8E 30 3C 4B 06' => 'Sigma 70-300mm F4-5.6 APO DG Macro HSM', #22
    'A3 3C 5C 8E 30 3C 4B 0E' => 'Sigma 70-300mm F4-5.6 DG OS',
    '02 37 5E 8E 35 3D 02 00' => 'Sigma 75-300mm F4.5-5.6 APO',
    '02 3A 5E 8E 32 3D 02 00' => 'Sigma 75-300mm F4.0-5.6',
    '77 44 61 98 34 3C 7B 0E' => 'Sigma 80-400mm F4.5-5.6 EX OS',
    '77 44 60 98 34 3C 7B 0E' => 'Sigma 80-400mm F4.5-5.6 APO DG D OS',
    '48 48 68 8E 30 30 4B 02' => 'Sigma APO 100-300mm F4 EX IF HSM',
    'F3 48 68 8E 30 30 4B 02' => 'Sigma APO 100-300mm F4 EX IF HSM',
    '48 54 6F 8E 24 24 4B 02' => 'Sigma APO 120-300mm F2.8 EX DG HSM',
    '7A 54 6E 8E 24 24 4B 02' => 'Sigma APO 120-300mm F2.8 EX DG HSM',
    'FA 54 6E 8E 24 24 4B 02' => 'Sigma APO 120-300mm F2.8 EX DG HSM', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2787.0.html
    'CF 38 6E 98 34 3C 4B 0E' => 'Sigma APO 120-400mm F4.5-5.6 DG OS HSM',
    'C3 34 68 98 38 40 4B 4E' => 'Sigma 100-400mm F5-6.3 DG OS HSM | C', #JR (017)
    '8D 48 6E 8E 24 24 4B 0E' => 'Sigma 120-300mm F2.8 DG OS HSM Sports',
    '26 44 73 98 34 3C 1C 02' => 'Sigma 135-400mm F4.5-5.6 APO Aspherical',
    'CE 34 76 A0 38 40 4B 0E' => 'Sigma 150-500mm F5-6.3 DG OS APO HSM', #JD
    '81 34 76 A6 38 40 4B 0E' => 'Sigma 150-600mm F5-6.3 DG OS HSM | S', #Jaap Voets
    '82 34 76 A6 38 40 4B 0E' => 'Sigma 150-600mm F5-6.3 DG OS HSM | C',
    '26 40 7B A0 34 40 1C 02' => 'Sigma APO 170-500mm F5-6.3 Aspherical RF',
    'A7 49 80 A0 24 24 4B 06' => 'Sigma APO 200-500mm F2.8 EX DG',
    '48 3C 8E B0 3C 3C 4B 02' => 'Sigma APO 300-800mm F5.6 EX DG HSM',
#
    '00 47 25 25 24 24 00 02' => 'Tamron SP AF 14mm f/2.8 Aspherical (IF) (69E)',
    'E8 4C 44 44 14 14 DF 0E' => 'Tamron SP 35mm f/1.8 Di VC USD (F012)', #35
    'E7 4C 4C 4C 14 14 DF 0E' => 'Tamron SP 45mm f/1.8 Di VC USD (F013)',
    'F4 54 56 56 18 18 84 06' => 'Tamron SP AF 60mm f/2.0 Di II Macro 1:1 (G005)', #24
    '1E 5D 64 64 20 20 13 00' => 'Tamron SP AF 90mm f/2.5 (52E)',
    '20 5A 64 64 20 20 14 00' => 'Tamron SP AF 90mm f/2.5 Macro (152E)',
    '22 53 64 64 24 24 E0 02' => 'Tamron SP AF 90mm f/2.8 Macro 1:1 (72E)',
    '32 53 64 64 24 24 35 02' => 'Tamron SP AF 90mm f/2.8 [Di] Macro 1:1 (172E/272E)',
    'F8 55 64 64 24 24 84 06' => 'Tamron SP AF 90mm f/2.8 Di Macro 1:1 (272NII)',
    'F8 54 64 64 24 24 DF 06' => 'Tamron SP AF 90mm f/2.8 Di Macro 1:1 (272NII)',
    'FE 54 64 64 24 24 DF 0E' => 'Tamron SP 90mm f/2.8 Di VC USD Macro 1:1 (F004)', #Jurgen Sahlberg
    'E4 54 64 64 24 24 DF 0E' => 'Tamron SP 90mm f/2.8 Di VC USD Macro 1:1 (F017)', #Rolf Probst
    '00 4C 7C 7C 2C 2C 00 02' => 'Tamron SP AF 180mm f/3.5 Di Model (B01)',
    '21 56 8E 8E 24 24 14 00' => 'Tamron SP AF 300mm f/2.8 LD-IF (60E)',
    '27 54 8E 8E 24 24 1D 02' => 'Tamron SP AF 300mm f/2.8 LD-IF (360E)',
    'E1 40 19 36 2C 35 DF 4E' => 'Tamron 10-24mm F/3.5-4.5 Di II VC HLD (B023)',
    'F6 3F 18 37 2C 34 84 06' => 'Tamron SP AF 10-24mm f/3.5-4.5 Di II LD Aspherical (IF) (B001)',
    'F6 3F 18 37 2C 34 DF 06' => 'Tamron SP AF 10-24mm f/3.5-4.5 Di II LD Aspherical (IF) (B001)', #30
    '00 36 1C 2D 34 3C 00 06' => 'Tamron SP AF 11-18mm f/4.5-5.6 Di II LD Aspherical (IF) (A13)',
    'E9 48 27 3E 24 24 DF 0E' => 'Tamron SP 15-30mm f/2.8 Di VC USD (A012)', #IB
    'EA 40 29 8E 2C 40 DF 0E' => 'Tamron AF 16-300mm f/3.5-6.3 Di II VC PZD (B016)',
    '07 46 2B 44 24 30 03 02' => 'Tamron SP AF 17-35mm f/2.8-4 Di LD Aspherical (IF) (A05)',
    '00 53 2B 50 24 24 00 06' => 'Tamron SP AF 17-50mm f/2.8 XR Di II LD Aspherical (IF) (A16)', #PH
    '00 54 2B 50 24 24 00 06' => 'Tamron SP AF 17-50mm f/2.8 XR Di II LD Aspherical (IF) (A16NII)',
    'FB 54 2B 50 24 24 84 06' => 'Tamron SP AF 17-50mm f/2.8 XR Di II LD Aspherical (IF) (A16NII)', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3787.0.html
    'F3 54 2B 50 24 24 84 0E' => 'Tamron SP AF 17-50mm f/2.8 XR Di II VC LD Aspherical (IF) (B005)',
    '00 3F 2D 80 2B 40 00 06' => 'Tamron AF 18-200mm f/3.5-6.3 XR Di II LD Aspherical (IF) (A14)',
    '00 3F 2D 80 2C 40 00 06' => 'Tamron AF 18-200mm f/3.5-6.3 XR Di II LD Aspherical (IF) Macro (A14)',
    '00 40 2D 80 2C 40 00 06' => 'Tamron AF 18-200mm f/3.5-6.3 XR Di II LD Aspherical (IF) Macro (A14NII)', #NJ
    'FC 40 2D 80 2C 40 DF 06' => 'Tamron AF 18-200mm f/3.5-6.3 XR Di II LD Aspherical (IF) Macro (A14NII)', #PH (NC)
    'E6 40 2D 80 2C 40 DF 0E' => 'Tamron AF 18-200mm f/3.5-6.3 Di II VC (B018)', #Tanel
    '00 40 2D 88 2C 40 62 06' => 'Tamron AF 18-250mm f/3.5-6.3 Di II LD Aspherical (IF) Macro (A18)',
    '00 40 2D 88 2C 40 00 06' => 'Tamron AF 18-250mm f/3.5-6.3 Di II LD Aspherical (IF) Macro (A18NII)', #JD
    'F5 40 2C 8A 2C 40 40 0E' => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC LD Aspherical (IF) Macro (B003)',
    'F0 3F 2D 8A 2C 40 DF 0E' => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC PZD (B008)',
    'E0 40 2D 98 2C 41 DF 4E' => 'Tamron AF 18-400mm f/3.5-6.3 Di II VC HLD (B028)',
    '07 40 2F 44 2C 34 03 02' => 'Tamron AF 19-35mm f/3.5-4.5 (A10)',
    '07 40 30 45 2D 35 03 02' => 'Tamron AF 19-35mm f/3.5-4.5 (A10)',
    '00 49 30 48 22 2B 00 02' => 'Tamron SP AF 20-40mm f/2.7-3.5 (166D)',
    '0E 4A 31 48 23 2D 0E 02' => 'Tamron SP AF 20-40mm f/2.7-3.5 (166D)',
    'FE 48 37 5C 24 24 DF 0E' => 'Tamron SP 24-70mm f/2.8 Di VC USD (A007)', #24
    'CE 47 37 5C 25 25 DF 4E' => 'Tamron SP 24-70mm f/2.8 Di VC USD G2 (A032)', #forum9110
    '45 41 37 72 2C 3C 48 02' => 'Tamron SP AF 24-135mm f/3.5-5.6 AD Aspherical (IF) Macro (190D)',
    '33 54 3C 5E 24 24 62 02' => 'Tamron SP AF 28-75mm f/2.8 XR Di LD Aspherical (IF) Macro (A09)',
    'FA 54 3C 5E 24 24 84 06' => 'Tamron SP AF 28-75mm f/2.8 XR Di LD Aspherical (IF) Macro (A09NII)', #JD
    'FA 54 3C 5E 24 24 DF 06' => 'Tamron SP AF 28-75mm f/2.8 XR Di LD Aspherical (IF) Macro (A09NII)',
    '10 3D 3C 60 2C 3C D2 02' => 'Tamron AF 28-80mm f/3.5-5.6 Aspherical (177D)',
    '45 3D 3C 60 2C 3C 48 02' => 'Tamron AF 28-80mm f/3.5-5.6 Aspherical (177D)',
    '00 48 3C 6A 24 24 00 02' => 'Tamron SP AF 28-105mm f/2.8 LD Aspherical IF (176D)',
    '4D 3E 3C 80 2E 3C 62 02' => 'Tamron AF 28-200mm f/3.8-5.6 XR Aspherical (IF) Macro (A03N)',
    '0B 3E 3D 7F 2F 3D 0E 00' => 'Tamron AF 28-200mm f/3.8-5.6 (71D)',
    '0B 3E 3D 7F 2F 3D 0E 02' => 'Tamron AF 28-200mm f/3.8-5.6D (171D)',
    '12 3D 3C 80 2E 3C DF 02' => 'Tamron AF 28-200mm f/3.8-5.6 AF Aspherical LD (IF) (271D)',
    '4D 41 3C 8E 2B 40 62 02' => 'Tamron AF 28-300mm f/3.5-6.3 XR Di LD Aspherical (IF) (A061)',
    '4D 41 3C 8E 2C 40 62 02' => 'Tamron AF 28-300mm f/3.5-6.3 XR LD Aspherical (IF) (185D)',
    'F9 40 3C 8E 2C 40 40 0E' => 'Tamron AF 28-300mm f/3.5-6.3 XR Di VC LD Aspherical (IF) Macro (A20)',
    '00 47 53 80 30 3C 00 06' => 'Tamron AF 55-200mm f/4-5.6 Di II LD (A15)',
    'F7 53 5C 80 24 24 84 06' => 'Tamron SP AF 70-200mm f/2.8 Di LD (IF) Macro (A001)',
    'FE 53 5C 80 24 24 84 06' => 'Tamron SP AF 70-200mm f/2.8 Di LD (IF) Macro (A001)',
    'F7 53 5C 80 24 24 40 06' => 'Tamron SP AF 70-200mm f/2.8 Di LD (IF) Macro (A001)',
  # 'FE 54 5C 80 24 24 DF 0E' => 'Tamron SP AF 70-200mm f/2.8 Di VC USD (A009)',
    'FE 54 5C 80 24 24 DF 0E' => 'Tamron SP 70-200mm f/2.8 Di VC USD (A009)', #NJ
    'E2 47 5C 80 24 24 DF 4E' => 'Tamron SP 70-200mm f/2.8 Di VC USD G2 (A025)', #forum9549
    '69 48 5C 8E 30 3C 6F 02' => 'Tamron AF 70-300mm f/4-5.6 LD Macro 1:2 (572D/772D)',
    '69 47 5C 8E 30 3C 00 02' => 'Tamron AF 70-300mm f/4-5.6 Di LD Macro 1:2 (A17N)',
    '00 48 5C 8E 30 3C 00 06' => 'Tamron AF 70-300mm f/4-5.6 Di LD Macro 1:2 (A17NII)', #JD
    'F1 47 5C 8E 30 3C DF 0E' => 'Tamron SP 70-300mm f/4-5.6 Di VC USD (A005)',
    'EB 40 76 A6 38 40 DF 0E' => 'Tamron SP AF 150-600mm f/5-6.3 VC USD (A011)',
    'E3 40 76 A6 38 40 DF 4E' => 'Tamron SP 150-600mm f/5-6.3 Di VC USD G2', #30
    '20 3C 80 98 3D 3D 1E 02' => 'Tamron AF 200-400mm f/5.6 LD IF (75D)',
    '00 3E 80 A0 38 3F 00 02' => 'Tamron SP AF 200-500mm f/5-6.3 Di LD (IF) (A08)',
    '00 3F 80 A0 38 3F 00 02' => 'Tamron SP AF 200-500mm f/5-6.3 Di (A08)',
#
    '00 40 2B 2B 2C 2C 00 02' => 'Tokina AT-X 17 AF PRO (AF 17mm f/3.5)',
    '00 47 44 44 24 24 00 06' => 'Tokina AT-X M35 PRO DX (AF 35mm f/2.8 Macro)',
    '00 54 68 68 24 24 00 02' => 'Tokina AT-X M100 AF PRO D (AF 100mm f/2.8 Macro)',
    '27 48 8E 8E 30 30 1D 02' => 'Tokina AT-X 304 AF (AF 300mm f/4.0)',
    '00 54 8E 8E 24 24 00 02' => 'Tokina AT-X 300 AF PRO (AF 300mm f/2.8)',
    '12 3B 98 98 3D 3D 09 00' => 'Tokina AT-X 400 AF SD (AF 400mm f/5.6)',
    '00 40 18 2B 2C 34 00 06' => 'Tokina AT-X 107 AF DX Fisheye (AF 10-17mm f/3.5-4.5)',
    '00 48 1C 29 24 24 00 06' => 'Tokina AT-X 116 PRO DX (AF 11-16mm f/2.8)',
    '7A 48 1C 29 24 24 7E 06' => 'Tokina AT-X 116 PRO DX II (AF 11-16mm f/2.8)',
    '7A 48 1C 30 24 24 7E 06' => 'Tokina AT-X 11-20 F2.8 PRO DX (AF 11-20mm f/2.8)',
    '00 3C 1F 37 30 30 00 06' => 'Tokina AT-X 124 AF PRO DX (AF 12-24mm f/4)',
    '7A 3C 1F 37 30 30 7E 06.2' => 'Tokina AT-X 124 AF PRO DX II (AF 12-24mm f/4)',
    '7A 3C 1F 3C 30 30 7E 06' => 'Tokina AT-X 12-28 PRO DX (AF 12-28mm f/4)',
    '00 48 29 3C 24 24 00 06' => 'Tokina AT-X 16-28 AF PRO FX (AF 16-28mm f/2.8)',
    '00 48 29 50 24 24 00 06' => 'Tokina AT-X 165 PRO DX (AF 16-50mm f/2.8)',
    '00 40 2A 72 2C 3C 00 06' => 'Tokina AT-X 16.5-135 DX (AF 16.5-135mm F3.5-5.6)',
    '00 3C 2B 44 30 30 00 06' => 'Tokina AT-X 17-35 F4 PRO FX (AF 17-35mm f/4)',
    '2F 40 30 44 2C 34 29 02.2' => 'Tokina AF 193 (AF 19-35mm f/3.5-4.5)',
    '2F 48 30 44 24 24 29 02.2' => 'Tokina AT-X 235 AF PRO (AF 20-35mm f/2.8)',
    '2F 40 30 44 2C 34 29 02.1' => 'Tokina AF 235 II (AF 20-35mm f/3.5-4.5)',
    '00 48 37 5C 24 24 00 06' => 'Tokina AT-X 24-70 F2.8 PRO FX (AF 24-70mm f/2.8)',
    '00 40 37 80 2C 3C 00 02' => 'Tokina AT-X 242 AF (AF 24-200mm f/3.5-5.6)',
    '25 48 3C 5C 24 24 1B 02.1' => 'Tokina AT-X 270 AF PRO II (AF 28-70mm f/2.6-2.8)',
    '25 48 3C 5C 24 24 1B 02.2' => 'Tokina AT-X 287 AF PRO SV (AF 28-70mm f/2.8)',
    '07 48 3C 5C 24 24 03 00' => 'Tokina AT-X 287 AF (AF 28-70mm f/2.8)',
    '07 47 3C 5C 25 35 03 00' => 'Tokina AF 287 SD (AF 28-70mm f/2.8-4.5)',
    '07 40 3C 5C 2C 35 03 00' => 'Tokina AF 270 II (AF 28-70mm f/3.5-4.5)',
    '00 48 3C 60 24 24 00 02' => 'Tokina AT-X 280 AF PRO (AF 28-80mm f/2.8)',
    '25 44 44 8E 34 42 1B 02' => 'Tokina AF 353 (AF 35-300mm f/4.5-6.7)',
    '00 48 50 72 24 24 00 06' => 'Tokina AT-X 535 PRO DX (AF 50-135mm f/2.8)',
    '00 3C 5C 80 30 30 00 0E' => 'Tokina AT-X 70-200 F4 FX VCM-S (AF 70-200mm f/4)',
    '00 48 5C 80 30 30 00 0E' => 'Tokina AT-X 70-200 F4 FX VCM-S (AF 70-200mm f/4)',
    '12 44 5E 8E 34 3C 09 00' => 'Tokina AF 730 (AF 75-300mm F4.5-5.6)',
    '14 54 60 80 24 24 0B 00' => 'Tokina AT-X 828 AF (AF 80-200mm f/2.8)',
    '24 54 60 80 24 24 1A 02' => 'Tokina AT-X 828 AF PRO (AF 80-200mm f/2.8)',
    '24 44 60 98 34 3C 1A 02' => 'Tokina AT-X 840 AF-II (AF 80-400mm f/4.5-5.6)',
    '00 44 60 98 34 3C 00 02' => 'Tokina AT-X 840 D (AF 80-400mm f/4.5-5.6)',
    '14 48 68 8E 30 30 0B 00' => 'Tokina AT-X 340 AF (AF 100-300mm f/4)',
#
    '06 3F 68 68 2C 2C 06 00' => 'Cosina AF 100mm F3.5 Macro',
    '07 36 3D 5F 2C 3C 03 00' => 'Cosina AF Zoom 28-80mm F3.5-5.6 MC Macro',
    '07 46 3D 6A 25 2F 03 00' => 'Cosina AF Zoom 28-105mm F2.8-3.8 MC',
    '12 36 5C 81 35 3D 09 00' => 'Cosina AF Zoom 70-210mm F4.5-5.6 MC Macro',
    '12 39 5C 8E 34 3D 08 02' => 'Cosina AF Zoom 70-300mm F4.5-5.6 MC Macro',
    '12 3B 68 8D 3D 43 09 02' => 'Cosina AF Zoom 100-300mm F5.6-6.7 MC Macro',
#
    '12 38 69 97 35 42 09 02' => 'Promaster Spectrum 7 100-400mm F4.5-6.7',
#
    '00 40 31 31 2C 2C 00 00' => 'Voigtlander Color Skopar 20mm F3.5 SLII Aspherical',
    '00 48 3C 3C 24 24 00 00' => 'Voigtlander Color Skopar 28mm F2.8 SL II',
    '00 54 48 48 18 18 00 00' => 'Voigtlander Ultron 40mm F2 SLII Aspherical',
    '00 54 55 55 0C 0C 00 00' => 'Voigtlander Nokton 58mm F1.4 SLII',
    '00 40 64 64 2C 2C 00 00' => 'Voigtlander APO-Lanthar 90mm F3.5 SLII Close Focus',
#
    '00 40 2D 2D 2C 2C 00 00' => 'Carl Zeiss Distagon T* 3.5/18 ZF.2',
    '00 48 32 32 24 24 00 00' => 'Carl Zeiss Distagon T* 2.8/21 ZF.2',
    '00 54 38 38 18 18 00 00' => 'Carl Zeiss Distagon T* 2/25 ZF.2',
    '00 54 3C 3C 18 18 00 00' => 'Carl Zeiss Distagon T* 2/28 ZF.2',
    '00 54 44 44 0C 0C 00 00' => 'Carl Zeiss Distagon T* 1.4/35 ZF.2',
    '00 54 44 44 18 18 00 00' => 'Carl Zeiss Distagon T* 2/35 ZF.2',
    '00 54 50 50 0C 0C 00 00' => 'Carl Zeiss Planar T* 1.4/50 ZF.2',
    '00 54 50 50 18 18 00 00' => 'Carl Zeiss Makro-Planar T* 2/50 ZF.2',
    '00 54 62 62 0C 0C 00 00' => 'Carl Zeiss Planar T* 1.4/85 ZF.2',
    '00 54 68 68 18 18 00 00' => 'Carl Zeiss Makro-Planar T* 2/100 ZF.2',
    '00 54 72 72 18 18 00 00' => 'Carl Zeiss Apo Sonnar T* 2/135 ZF.2',
    '00 54 53 53 0C 0C 00 00' => 'Zeiss Otus 1.4/55', #IB
    '01 54 62 62 0C 0C 00 00' => 'Zeiss Otus 1.4/85',
    '52 54 44 44 18 18 00 00' => 'Zeiss Milvus 35mm f/2',
    '53 54 50 50 0C 0C 00 00' => 'Zeiss Milvus 50mm f/1.4', #IB
    '54 54 50 50 18 18 00 00' => 'Zeiss Milvus 50mm f/2 Macro',
    '55 54 62 62 0C 0C 00 00' => 'Zeiss Milvus 85mm f/1.4', #IB
    '56 54 68 68 18 18 00 00' => 'Zeiss Milvus 100mm f/2 Macro',
#
    '00 54 56 56 30 30 00 00' => 'Coastal Optical Systems 60mm 1:4 UV-VIS-IR Macro Apo',
#
    'BF 4E 26 26 1E 1E 01 04' => 'Irix 15mm f/2.4 Firefly', #30
    'BF 3C 1B 1B 30 30 01 04' => 'Irix 11mm f/4 Firefly', #30
#
    '4A 40 11 11 2C 0C 4D 02' => 'Samyang 8mm f/3.5 Fish-Eye CS',
    '4A 48 24 24 24 0C 4D 02.1' => 'Samyang 10mm f/2.8 ED AS NCS CS',
    '4A 48 1E 1E 24 0C 4D 02' => 'Samyang 12mm f/2.8 ED AS NCS Fish-Eye', #Jurgen Sahlberg
    '4A 48 24 24 24 0C 4D 02.2' => 'Samyang AE 14mm f/2.8 ED AS IF UMC', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3150.0.html
    '4A 4C 24 24 1E 6C 4D 06' => 'Samyang 14mm f/2.4 Premium',
    '4A 54 29 29 18 0C 4D 02' => 'Samyang 16mm f/2.0 ED AS UMC CS', #Jon Bloom (by email)
    '4A 60 36 36 0C 0C 4D 02' => 'Samyang 24mm f/1.4 ED AS UMC',
    '4A 60 44 44 0C 0C 4D 02' => 'Samyang 35mm f/1.4 AS UMC',
    '4A 60 62 62 0C 0C 4D 02' => 'Samyang AE 85mm f/1.4 AS IF UMC', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2888.0.html
#
    '9A 4C 50 50 14 14 9C 06' => 'Yongnuo YN50mm F1.8N',
#
    '02 40 44 5C 2C 34 02 00' => 'Exakta AF 35-70mm 1:3.5-4.5 MC',
#
    '07 3E 30 43 2D 35 03 00' => 'Soligor AF Zoom 19-35mm 1:3.5-4.5 MC',
    '03 43 5C 81 35 35 02 00' => 'Soligor AF C/D Zoom UMCS 70-210mm 1:4.5',
    '12 4A 5C 81 31 3D 09 00' => 'Soligor AF C/D Auto Zoom+Macro 70-210mm 1:4-5.6 UMCS',
    '12 36 69 97 35 42 09 00' => 'Soligor AF Zoom 100-400mm 1:4.5-6.7 MC',
#
    '00 00 00 00 00 00 00 01' => 'Manual Lens No CPU',
#
    '00 00 48 48 53 53 00 01' => 'Loreo 40mm F11-22 3D Lens in a Cap 9005', #PH
    '00 47 10 10 24 24 00 00' => 'Fisheye Nikkor 8mm f/2.8 AiS',
    '00 47 3C 3C 24 24 00 00' => 'Nikkor 28mm f/2.8 AiS', #35
  # '00 54 44 44 0C 0C 00 00' => 'Nikkor 35mm f/1.4 AiS', comment out in favour of Zeiss with same ID because this lens is rare (requires CPU upgrade)
    '00 57 50 50 14 14 00 00' => 'Nikkor 50mm f/1.8 AI', #35
    '00 48 50 50 18 18 00 00' => 'Nikkor H 50mm f/2',
    '00 48 68 68 24 24 00 00' => 'Series E 100mm f/2.8',
    '00 4C 6A 6A 20 20 00 00' => 'Nikkor 105mm f/2.5 AiS',
    '00 48 80 80 30 30 00 00' => 'Nikkor 200mm f/4 AiS',
    '00 40 11 11 2C 2C 00 00' => 'Samyang 8mm f/3.5 Fish-Eye',
    '00 58 64 64 20 20 00 00' => 'Soligor C/D Macro MC 90mm f/2.5',
);

# text encoding used in LocationInfo (ref PH)
%nikonTextEncoding = (
    0 => 'n/a',
    1 => 'UTF8',
    # UTF16 is a guess here: it could also be Unicode or JIS,
    # but I chose UTF16 due to the similarity with the QuickTime stringEncoding
    2 => 'UTF16',
);

# flash firmware decoding (ref JD)
my %flashFirmware = (
    '0 0' => 'n/a',
    '1 1' => '1.01 (SB-800 or Metz 58 AF-1)',
    '1 3' => '1.03 (SB-800)',
    '2 1' => '2.01 (SB-800)',
    '2 4' => '2.04 (SB-600)',
    '2 5' => '2.05 (SB-600)',
    '3 1' => '3.01 (SU-800 Remote Commander)',
    '4 1' => '4.01 (SB-400)',
    '4 2' => '4.02 (SB-400)',
    '4 4' => '4.04 (SB-400)',
    '5 1' => '5.01 (SB-900)',
    '5 2' => '5.02 (SB-900)',
    '6 1' => '6.01 (SB-700)', #http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,5034.0.html
    '7 1' => '7.01 (SB-910)', #PH
    OTHER => sub {
        my ($val, $inv) = @_;
        return sprintf('%d.%.2d (Unknown model)', split(' ', $val)) unless $inv;
        return "$1 $2" if $val =~ /(\d+)\.(\d+)/;
        return '0 0';
    },
);

# flash Guide Number (GN) distance settings (ref 28)
my %flashGNDistance = (
     0 => 0,        19 => '2.8 m',
     1 => '0.1 m',  20 => '3.2 m',
     2 => '0.2 m',  21 => '3.6 m',
     3 => '0.3 m',  22 => '4.0 m',
     4 => '0.4 m',  23 => '4.5 m',
     5 => '0.5 m',  24 => '5.0 m',
     6 => '0.6 m',  25 => '5.6 m',
     7 => '0.7 m',  26 => '6.3 m',
     8 => '0.8 m',  27 => '7.1 m',
     9 => '0.9 m',  28 => '8.0 m',
    10 => '1.0 m',  29 => '9.0 m',
    11 => '1.1 m',  30 => '10.0 m',
    12 => '1.3 m',  31 => '11.0 m',
    13 => '1.4 m',  32 => '13.0 m',
    14 => '1.6 m',  33 => '14.0 m',
    15 => '1.8 m',  34 => '16.0 m',
    16 => '2.0 m',  35 => '18.0 m',
    17 => '2.2 m',  36 => '20.0 m',
    18 => '2.5 m',  255 => 'n/a',
);

# flash color filter values (ref 28)
my %flashColorFilter = (
    0x00 => 'None',
    1 => 'FL-GL1 or SZ-2FL Fluorescent', # (green) (SZ model ref PH)
    2 => 'FL-GL2',
    9 => 'TN-A1 or SZ-2TN Incandescent', # (orange) (SZ model ref PH)
    10 => 'TN-A2',
    65 => 'Red',
    66 => 'Blue',
    67 => 'Yellow',
    68 => 'Amber',
);

# flash control mode values (ref JD)
my %flashControlMode = (
    0x00 => 'Off',
    0x01 => 'iTTL-BL',
    0x02 => 'iTTL',
    0x03 => 'Auto Aperture',
    0x04 => 'Automatic', #28
    0x05 => 'GN (distance priority)', #28 (Guide Number, but called "GN" in manual)
    0x06 => 'Manual',
    0x07 => 'Repeating Flash',
);

my %retouchValues = ( #PH
     0 => 'None',
     3 => 'B & W',
     4 => 'Sepia',
     5 => 'Trim',
     6 => 'Small Picture',
     7 => 'D-Lighting',
     8 => 'Red Eye',
     9 => 'Cyanotype',
    10 => 'Sky Light',
    11 => 'Warm Tone',
    12 => 'Color Custom',
    13 => 'Image Overlay',
    14 => 'Red Intensifier',
    15 => 'Green Intensifier',
    16 => 'Blue Intensifier',
    17 => 'Cross Screen',
    18 => 'Quick Retouch',
    19 => 'NEF Processing',
    23 => 'Distortion Control',
    25 => 'Fisheye',
    26 => 'Straighten',
    29 => 'Perspective Control',
    30 => 'Color Outline',
    31 => 'Soft Filter',
    32 => 'Resize', #31
    33 => 'Miniature Effect',
    34 => 'Skin Softening', # (S9200)
    35 => 'Selected Frame', #31 (frame exported from MOV)
    37 => 'Color Sketch', #31
    38 => 'Selective Color', # (S9200)
    39 => 'Glamour', # (S3500)
    40 => 'Drawing', # (S9200)
    44 => 'Pop', # (S3500)
    45 => 'Toy Camera Effect 1', # (S3500)
    46 => 'Toy Camera Effect 2', # (S3500)
    47 => 'Cross Process (red)', # (S3500)
    48 => 'Cross Process (blue)', # (S3500)
    49 => 'Cross Process (green)', # (S3500)
    50 => 'Cross Process (yellow)', # (S3500)
    51 => 'Super Vivid', # (S3500)
    52 => 'High-contrast Monochrome', # (S3500)
    53 => 'High Key', # (S3500)
    54 => 'Low Key', # (S3500)
);

# AF point indices for models with 51 focus points, eg. D3 (ref JD/PH)
#        A1  A2  A3  A4  A5  A6  A7  A8  A9
#    B1  B2  B3  B4  B5  B6  B7  B8  B9  B10  B11
#    C1  C2  C3  C4  C5  C6  C7  C8  C9  C10  C11
#    D1  D2  D3  D4  D5  D6  D7  D8  D9  D10  D11
#        E1  E2  E3  E4  E5  E6  E7  E8  E9
my %afPoints51 = (
     1 => 'C6', 11 => 'C5', 21 => 'C9', 31 => 'C11',41 => 'A2', 51 => 'D1',
     2 => 'B6', 12 => 'B5', 22 => 'B9', 32 => 'B11',42 => 'D3',
     3 => 'A5', 13 => 'A4', 23 => 'A8', 33 => 'D11',43 => 'E2',
     4 => 'D6', 14 => 'D5', 24 => 'D9', 34 => 'C4', 44 => 'C2',
     5 => 'E5', 15 => 'E4', 25 => 'E8', 35 => 'B4', 45 => 'B2',
     6 => 'C7', 16 => 'C8', 26 => 'C10',36 => 'A3', 46 => 'A1',
     7 => 'B7', 17 => 'B8', 27 => 'B10',37 => 'D4', 47 => 'D2',
     8 => 'A6', 18 => 'A7', 28 => 'A9', 38 => 'E3', 48 => 'E1',
     9 => 'D7', 19 => 'D8', 29 => 'D10',39 => 'C3', 49 => 'C1',
    10 => 'E6', 20 => 'E7', 30 => 'E9', 40 => 'B3', 50 => 'B1',
);

# AF point indices for models with 39 focus points, eg. D7000 (ref 29)
#                    A1  A2  A3
#    B1  B2  B3  B4  B5  B6  B7  B8  B9  B10  B11
#    C1  C2  C3  C4  C5  C6  C7  C8  C9  C10  C11
#    D1  D2  D3  D4  D5  D6  D7  D8  D9  D10  D11
#                    E1  E2  E3
my %afPoints39 = (
     1 => 'C6', 11 => 'C5', 21 => 'D9', 31 => 'C3',
     2 => 'B6', 12 => 'B5', 22 => 'C10',32 => 'B3',
     3 => 'A2', 13 => 'A1', 23 => 'B10',33 => 'D3',
     4 => 'D6', 14 => 'D5', 24 => 'D10',34 => 'C2',
     5 => 'E2', 15 => 'E1', 25 => 'C11',35 => 'B2',
     6 => 'C7', 16 => 'C8', 26 => 'B11',36 => 'D2',
     7 => 'B7', 17 => 'B8', 27 => 'D11',37 => 'C1',
     8 => 'A3', 18 => 'D8', 28 => 'C4', 38 => 'B1',
     9 => 'D7', 19 => 'C9', 29 => 'B4', 39 => 'D1',
    10 => 'E3', 20 => 'B9', 30 => 'D4',
);

# AF point indices for models with 135 focus points, eg. 1J1 (ref PH)
# - 9 rows (A-I) with 15 columns (1-15), center is E8
# - odd columns, columns 2 and 14, and the remaining corner points are
#   not used in 41-point mode
my %afPoints135 = (
     1 => 'E8', 28 => 'E10', 55 => 'E13',  82 => 'E6', 109 => 'E3',
     2 => 'D8', 29 => 'D10', 56 => 'D13',  83 => 'D6', 110 => 'D3',
     3 => 'C8', 30 => 'C10', 57 => 'C13',  84 => 'C6', 111 => 'C3',
     4 => 'B8', 31 => 'B10', 58 => 'B13',  85 => 'B6', 112 => 'B3',
     5 => 'A8', 32 => 'A10', 59 => 'A13',  86 => 'A6', 113 => 'A3',
     6 => 'F8', 33 => 'F10', 60 => 'F13',  87 => 'F6', 114 => 'F3',
     7 => 'G8', 34 => 'G10', 61 => 'G13',  88 => 'G6', 115 => 'G3',
     8 => 'H8', 35 => 'H10', 62 => 'H13',  89 => 'H6', 116 => 'H3',
     9 => 'I8', 36 => 'I10', 63 => 'I13',  90 => 'I6', 117 => 'I3',
    10 => 'E9', 37 => 'E11', 64 => 'E14',  91 => 'E5', 118 => 'E2',
    11 => 'D9', 38 => 'D11', 65 => 'D14',  92 => 'D5', 119 => 'D2',
    12 => 'C9', 39 => 'C11', 66 => 'C14',  93 => 'C5', 120 => 'C2',
    13 => 'B9', 40 => 'B11', 67 => 'B14',  94 => 'B5', 121 => 'B2',
    14 => 'A9', 41 => 'A11', 68 => 'A14',  95 => 'A5', 122 => 'A2',
    15 => 'F9', 42 => 'F11', 69 => 'F14',  96 => 'F5', 123 => 'F2',
    16 => 'G9', 43 => 'G11', 70 => 'G14',  97 => 'G5', 124 => 'G2',
    17 => 'H9', 44 => 'H11', 71 => 'H14',  98 => 'H5', 125 => 'H2',
    18 => 'I9', 45 => 'I11', 72 => 'I14',  99 => 'I5', 126 => 'I2',
    19 => 'E7', 46 => 'E12', 73 => 'E15', 100 => 'E4', 127 => 'E1',
    20 => 'D7', 47 => 'D12', 74 => 'D15', 101 => 'D4', 128 => 'D1',
    21 => 'C7', 48 => 'C12', 75 => 'C15', 102 => 'C4', 129 => 'C1',
    22 => 'B7', 49 => 'B12', 76 => 'B15', 103 => 'B4', 130 => 'B1',
    23 => 'A7', 50 => 'A12', 77 => 'A15', 104 => 'A4', 131 => 'A1',
    24 => 'F7', 51 => 'F12', 78 => 'F15', 105 => 'F4', 132 => 'F1',
    25 => 'G7', 52 => 'G12', 79 => 'G15', 106 => 'G4', 133 => 'G1',
    26 => 'H7', 53 => 'H12', 80 => 'H15', 107 => 'H4', 134 => 'H1',
    27 => 'I7', 54 => 'I12', 81 => 'I15', 108 => 'I4', 135 => 'I1',
);

# AF point indices for models with 153 focus points, eg. D5,D500 (ref PH)
# - 9 rows (A-I) with 17 columns (1-17), center is E9
# - 55 of these are selectable cross points (odd rows and columns 1,3,4,6,7,9,11,12,14,15,17)
my %afPoints153 = (
     1 => 'E9',  32 => 'A8',  63 => 'I13',  94 => 'B17', 125 => 'H4',
     2 => 'D9',  33 => 'F8',  64 => 'E14',  95 => 'A17', 126 => 'I4',
     3 => 'C9',  34 => 'G8',  65 => 'D14',  96 => 'F17', 127 => 'E3',
     4 => 'B9',  35 => 'H8',  66 => 'C14',  97 => 'G17', 128 => 'D3',
     5 => 'A9',  36 => 'I8',  67 => 'B14',  98 => 'H17', 129 => 'C3',
     6 => 'F9',  37 => 'E7',  68 => 'A14',  99 => 'I17', 130 => 'B3',
     7 => 'G9',  38 => 'D7',  69 => 'F14', 100 => 'E6',  131 => 'A3',
     8 => 'H9',  39 => 'C7',  70 => 'G14', 101 => 'D6',  132 => 'F3',
     9 => 'I9',  40 => 'B7',  71 => 'H14', 102 => 'C6',  133 => 'G3',
    10 => 'E10', 41 => 'A7',  72 => 'I14', 103 => 'B6',  134 => 'H3',
    11 => 'D10', 42 => 'F7',  73 => 'E15', 104 => 'A6',  135 => 'I3',
    12 => 'C10', 43 => 'G7',  74 => 'D15', 105 => 'F6',  136 => 'E2',
    13 => 'B10', 44 => 'H7',  75 => 'C15', 106 => 'G6',  137 => 'D2',
    14 => 'A10', 45 => 'I7',  76 => 'B15', 107 => 'H6',  138 => 'C2',
    15 => 'F10', 46 => 'E12', 77 => 'A15', 108 => 'I6',  139 => 'B2',
    16 => 'G10', 47 => 'D12', 78 => 'F15', 109 => 'E5',  140 => 'A2',
    17 => 'H10', 48 => 'C12', 79 => 'G15', 110 => 'D5',  141 => 'F2',
    18 => 'I10', 49 => 'B12', 80 => 'H15', 111 => 'C5',  142 => 'G2',
    19 => 'E11', 50 => 'A12', 81 => 'I15', 112 => 'B5',  143 => 'H2',
    20 => 'D11', 51 => 'F12', 82 => 'E16', 113 => 'A5',  144 => 'I2',
    21 => 'C11', 52 => 'G12', 83 => 'D16', 114 => 'F5',  145 => 'E1',
    22 => 'B11', 53 => 'H12', 84 => 'C16', 115 => 'G5',  146 => 'D1',
    23 => 'A11', 54 => 'I12', 85 => 'B16', 116 => 'H5',  147 => 'C1',
    24 => 'F11', 55 => 'E13', 86 => 'A16', 117 => 'I5',  148 => 'B1',
    25 => 'G11', 56 => 'D13', 87 => 'F16', 118 => 'E4',  149 => 'A1',
    26 => 'H11', 57 => 'C13', 88 => 'G16', 119 => 'D4',  150 => 'F1',
    27 => 'I11', 58 => 'B13', 89 => 'H16', 120 => 'C4',  151 => 'G1',
    28 => 'E8',  59 => 'A13', 90 => 'I16', 121 => 'B4',  152 => 'H1',
    29 => 'D8',  60 => 'F13', 91 => 'E17', 122 => 'A4',  153 => 'I1',
    30 => 'C8',  61 => 'G13', 92 => 'D17', 123 => 'F4',
    31 => 'B8',  62 => 'H13', 93 => 'C17', 124 => 'G4',
);

my %cropHiSpeed = ( #IB
    0 => 'Off',
    1 => '1.3x Crop', # (1.3x Crop, Large)
    2 => 'DX Crop',
    3 => '5:4 Crop',
    4 => '3:2 Crop',
    6 => '16:9 Crop',
    9 => 'DX Movie Crop', # (DX during movie recording, Large)
    11 => 'FX Uncropped',
    12 => 'DX Uncropped',
    17 => '1:1 Crop',
    OTHER => sub {
        my ($val, $inv, $conv) = @_;
        return undef if $inv;
        my @a = split ' ', $val;
        return "Unknown ($val)" unless @a == 7;
        $a[0] = $$conv{$a[0]} || "Unknown ($a[0])";
        return "$a[0] ($a[1]x$a[2] cropped to $a[3]x$a[4] at pixel $a[5],$a[6])";
    },
);

my %offOn = ( 0 => 'Off', 1 => 'On' );

# common attributes for writable BinaryData directories
my %binaryDataAttrs = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
);

# Nikon maker note tags
%Image::ExifTool::Nikon::Main = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikon,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikon,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRINT_CONV => \&FormatString,
    0x0001 => { #2
        # the format differs for different models.  for D70, this is a string '0210',
        # but for the E775 it is binary: "\x00\x01\x00\x00"
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
        # convert to string if binary
        ValueConv => '$_=$val; /^[\x00-\x09]/ and $_=join("",unpack("CCCC",$_)); $_',
        ValueConvInv => '$val',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_',
        PrintConvInv => '$_=$val;s/\.//;"0$_"',
    },
    0x0002 => {
        # this is the ISO actually used by the camera
        # (may be different than ISO setting if auto)
        Name => 'ISO',
        Writable => 'int16u',
        Count => 2,
        Priority => 0,  # the EXIF ISO is more reliable
        Groups => { 2 => 'Image' },
        # D300 sets this to undef with 4 zero bytes when LO ISO is used - PH
        RawConv => '$val eq "\0\0\0\0" ? undef : $val',
        # first number is 1 for "Hi ISO" modes (H0.3, H0.7 and H1.0 on D80) - PH
        PrintConv => '$_=$val;s/^0 //;s/^1 (\d+)/Hi $1/;$_',
        PrintConvInv => '$_=$val;/^\d+/ ? "0 $_" : (s/Hi ?//i ? "1 $_" : $_)',
    },
    # Note: we attempt to fix the case of these string values (typically written in all caps)
    0x0003 => { Name => 'ColorMode',    Writable => 'string' },
    0x0004 => { Name => 'Quality',      Writable => 'string' },
    0x0005 => { Name => 'WhiteBalance', Writable => 'string' },
    0x0006 => { Name => 'Sharpness',    Writable => 'string' },
    0x0007 => { Name => 'FocusMode',    Writable => 'string' },
    # FlashSetting (better named FlashSyncMode, ref 28) values:
    #   "Normal", "Slow", "Rear Slow", "RED-EYE", "RED-EYE SLOW"
    0x0008 => { Name => 'FlashSetting', Writable => 'string' },
    # FlashType observed values:
    #   internal: "Built-in,TTL", "Built-in,RPT", "Comdr.", "NEW_TTL"
    #   external: "Optional,TTL", "Optional,RPT", "Optional,M", "Comdr."
    #   both:     "Built-in,TTL&Comdr."
    #   no flash: ""
    0x0009 => { Name => 'FlashType',    Writable => 'string' }, #2 (count varies by model - PH)
    # 0x000a - rational values: 5.6 to 9.33 - found in Coolpix models - PH
    #          (seems constant for a given camera model, but not correlated with scale factor)
    0x000b => { #2
        Name => 'WhiteBalanceFineTune',
        Writable => 'int16s',
        Count => -1, # older models write 1 value, newer DSLR's write 2 - PH
    },
    0x000c => { # (D1X)
        Name => 'WB_RBLevels',
        Writable => 'rational64u',
        Count => 4, # (not sure what the last 2 values are for)
    },
    0x000d => { #15
        Name => 'ProgramShift',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x000e => {
        Name => 'ExposureDifference',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*12 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,12,0);
        },
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => '$val',
    },
    0x000f => { Name => 'ISOSelection', Writable => 'string' }, #2
    0x0010 => {
        Name => 'DataDump',
        Writable => 0,
        Binary => 1,
    },
    0x0011 => {
        Name => 'PreviewIFD',
        Groups => { 1 => 'PreviewIFD', 2 => 'Image' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::PreviewIFD',
            Start => '$val',
        },
    },
    0x0012 => { #2 (camera setting: combination of command dial and menus - PH)
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Writable => 'undef',
        Count => 4,
        # (includes the built-in compensation for FlashType "Built-in,TTL&Comdr.")
        Notes => q{
            may be set even if flash does not fire.  Does not include the effect of
            flash bracketing.
        },
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    # D70 - another ISO tag
    0x0013 => { #2
        Name => 'ISOSetting',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/^0 //;$_',
        PrintConvInv => '"0 $val"',
    },
    0x0014 => [
        { #4
            Name => 'ColorBalanceA',
            Condition => '$format eq "undef" and $count == 2560',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceA',
                ByteOrder => 'BigEndian',
            },
        },
        { #IB
            Name => 'NRWData',
            Condition => '$$valPt =~ /^NRW 0100/',
            Drop => 1,  # 'Drop' because it is large and not found in JPEG images
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceB',
            },
        },
        { #IB
            Name => 'NRWData',
            Condition => '$$valPt =~ /^NRW /',
            Drop => 1,  # 'Drop' because it is large and not found in JPEG images
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceC',
            },
        },
    ],
    # 0x0015 - string[8]: "AUTO   "
    # D70 Image boundary?? top x,y bot-right x,y
    0x0016 => { #2
        Name => 'ImageBoundary',
        Writable => 'int16u',
        Count => 4,
    },
    0x0017 => { #28
        Name => 'ExternalFlashExposureComp', #PH (setting from external flash unit)
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0018 => { #5
        Name => 'FlashExposureBracketValue',
        Writable => 'undef',
        Count => 4,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c4",$a,1,6,0);
        },
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x0019 => { #5
        Name => 'ExposureBracketValue',
        Writable => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x001a => { #PH
        Name => 'ImageProcessing',
        Writable => 'string',
    },
    0x001b => { #15
        Name => 'CropHiSpeed',
        Writable => 'int16u',
        Count => 7,
        PrintConv => \%cropHiSpeed,
    },
    0x001c => { #28 (D3 "the application of CSb6 to the selected metering mode")
        Name => 'ExposureTuning',
        Writable => 'undef',
        Count => 3,
        ValueConv => 'my ($a,$b,$c)=unpack("c3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => q{
            my $a = int($val*6 + ($val>0 ? 0.5 : -0.5));
            $a<-128 or $a>127 ? undef : pack("c3",$a,1,6);
        },
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x001d => { #4
        Name => 'SerialNumber',
        # Note: this has been known to change even if the serial number on the body
        # stays the same if some parts of the camera were replaced by Nikon service
        Writable => 'string',
        Protected => 1,
        Notes => q{
            this value is used as a key to decrypt other information -- writing this tag
            causes the other information to be re-encrypted with the new key
        },
        PrintConv => undef, # disable default PRINT_CONV
    },
    0x001e => { #14
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
    0x001f => { #PH
        Name => 'VRInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::VRInfo' },
    },
    0x0020 => { #16
        Name => 'ImageAuthentication',
        Writable => 'int8u',
        PrintConv => \%offOn,
    },
    0x0021 => { #PH
        Name => 'FaceDetect',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FaceDetect' },
    },
    0x0022 => { #21
        Name => 'ActiveD-Lighting',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            3 => 'Normal',
            5 => 'High',
            7 => 'Extra High', #10
            8 => 'Extra High 1', #PH
            9 => 'Extra High 2', #PH
            10 => 'Extra High 3', #PH
            11 => 'Extra High 4', #PH
            0xffff => 'Auto', #10
        },
    },
    0x0023 => [
        { #PH (D300, but also found in D3,D3S,D3X,D90,D300S,D700,D3000,D5000)
            Condition => '$$valPt =~ /^01/',
            Name => 'PictureControlData',
            Writable => 'undef',
            Permanent => 0,
            Flags => [ 'Binary', 'Protected' ],
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::PictureControl' },
        },{ #28
            Name => 'PictureControlData',
            Writable => 'undef',
            Permanent => 0,
            Flags => [ 'Binary', 'Protected' ],
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::PictureControl2' },
        },
    ],
    0x0024 => { #JD
        Name => 'WorldTime',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::WorldTime',
            # (CaptureNX does flip the byte order of this record)
        },
    },
    0x0025 => { #PH
        Name => 'ISOInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::ISOInfo',
            ByteOrder => 'BigEndian',
        },
    },
    0x002a => { #23 (this tag added with D3 firmware 1.10 -- also written by Nikon utilities)
        Name => 'VignetteControl',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            3 => 'Normal',
            5 => 'High',
        },
    },
    0x002b => { #PH
        Name => 'DistortInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::DistortInfo',
        },
    },
    0x002c => { #29 (D7000)
        Name => 'UnknownInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::UnknownInfo',
            ByteOrder => 'BigEndian', #(NC)
        },
    },
    # 0x2d - "512 0 0","512 3 10","512 1 14",...
    0x0032 => { #PH
        Name => 'UnknownInfo2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::UnknownInfo2',
            ByteOrder => 'BigEndian', #(NC)
        },
    },
    # 0x0034 - Nikon 1 models only, values: 0,16,33
    0x0035 => { #32
        Name => 'HDRInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::HDRInfo' },
    },
    0x0037 => { #XavierJubier
        Name => 'MechanicalShutterCount',
        Writable => 'int32u',
    },
    0x0039 => {
        Name => 'LocationInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::LocationInfo' },
    },
    0x003d => { #IB
        Name => 'BlackLevel',
        Writable => 'int16u',
        Count => 4,
        # (may need to divide by 4 for some images, eg. D3300/D5300, 12 bit - ref IB)
    },
    0x004f => { #IB (D850)
        Name => 'ColorTemperatureAuto',
        Writable => 'int16u',
    },
    0x0080 => { Name => 'ImageAdjustment',  Writable => 'string' },
    0x0081 => { Name => 'ToneComp',         Writable => 'string' }, #2
    0x0082 => { Name => 'AuxiliaryLens',    Writable => 'string' },
    0x0083 => {
        Name => 'LensType',
        Writable => 'int8u',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        PrintConv => q[$_ = $val ? Image::ExifTool::DecodeBits($val,
            {
                0 => 'MF',
                1 => 'D',
                2 => 'G',
                3 => 'VR',
                # bit 4 set for Nikon 1 lenses - PH
                # bit 5 set for FT-1 adapter? - PH
                # bit 6 set for FL lenses? - PH
            }) : 'AF';
            # remove commas and change "D G" to just "G"
            s/,//g; s/\bD G\b/G/; $_
        ],
        PrintConvInv => q[
            my $bits = 0;
            $bits |= 0x01 if $val =~ /\bMF\b/i;
            $bits |= 0x02 if $val =~ /\bD\b/i;
            $bits |= 0x06 if $val =~ /\bG\b/i;
            $bits |= 0x08 if $val =~ /\bVR\b/i;
            return $bits;
        ],
    },
    0x0084 => { #2
        Name => "Lens",
        Writable => 'rational64u',
        Count => 4,
        # short focal, long focal, aperture at short focal, aperture at long focal
        PrintConv => \&Image::ExifTool::Exif::PrintLensInfo,
        PrintConvInv => \&Image::ExifTool::Exif::ConvertLensInfo,
    },
    0x0085 => {
        Name => 'ManualFocusDistance',
        Writable => 'rational64u',
    },
    0x0086 => {
        Name => 'DigitalZoom',
        Writable => 'rational64u',
    },
    0x0087 => { #5
        Name => 'FlashMode',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Did Not Fire',
            1 => 'Fired, Manual', #14
            3 => 'Not Ready', #28
            7 => 'Fired, External', #14
            8 => 'Fired, Commander Mode',
            9 => 'Fired, TTL Mode',
        },
    },
    0x0088 => [
        {
            Name => 'AFInfo',
            Condition => '$$self{Model} =~ /^NIKON D/i',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::AFInfo',
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'AFInfo',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::AFInfo',
                ByteOrder => 'LittleEndian',
            },
        },
    ],
    0x0089 => { #5
        Name => 'ShootingMode',
        Writable => 'int16u',
        # the meaning of bit 5 seems to change:  For the D200 it indicates "Auto ISO" - PH
        Notes => 'for the D70, Bit 5 = Unused LE-NR Slowdown',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        # The (new?) bit 5 seriously complicates our life here: after firmwareB's
        # 1.03, bit 5 turns on when you ask for BUT DO NOT USE the long-range
        # noise reduction feature, probably because even not using it, it still
        # slows down your drive operation to 50% (1.5fps max not 3fps).  But no
        # longer does !$val alone indicate single-frame operation. - TC, D70
        # The following comments are from Warren Hatch:
        # Bits 4,6,8 indicate bracketing mode.
        #  - all 0's => Bracketing Off
        #  - bit 4 on with bits 6,8 off => Exposure Bracketing On
        #  - bits 4,6 on => WB bracketing On
        #  - 4,8 on => ADL Bracketing On
        # Bit 2 gives tethered status:  Off=>Not Tethered; On=Tethered.
        #  - that this simply indicates a camera is connected via a cord to a PC
        #    (doesn't necessarily mean that the shutter was tripped by the computer)
        # Bits 0,1,3,7,9 relate to how the shutter is tripped in concert with the
        #  Release Mode dial [although I cannot cause bit 7 to flip with any of my gear and
        #  I suspect it is no longer used for the D500].  Regardless, the ReleaseMode tag
        #  offers a superior decoding of this information for the D4s, D810 and D500.
        # Bit 5 indicates whether or not AutoISO is enabled.
        PrintConv => q[
            $_ = '';
            unless ($val & 0x87) {
                return 'Single-Frame' unless $val;
                $_ = 'Single-Frame, ';
            }
            return $_ . Image::ExifTool::DecodeBits($val,
            {
                0 => 'Continuous',
                1 => 'Delay',
                2 => 'PC Control',
                3 => 'Self-timer', #forum6281 (NC)
                4 => 'Exposure Bracketing',
                5 => $$self{Model}=~/D70\b/ ? 'Unused LE-NR Slowdown' : 'Auto ISO',
                6 => 'White-Balance Bracketing',
                7 => 'IR Control',
                8 => 'D-Lighting Bracketing', #forum6281 (NC)
            });
        ],
    },
    # 0x008a - called "AutoBracketRelease" by ref 15 [but this seems wrong]
    #   values: 0,255 (when writing NEF only), or 1,2 (when writing JPEG or JPEG+NEF)
    #   --> makes odd, repeating pattern in sequential NEF images (ref 28)
    0x008b => { #8
        Name => 'LensFStops',
        ValueConv => 'my ($a,$b,$c)=unpack("C3",$val); $c ? $a*($b/$c) : 0',
        ValueConvInv => 'my $a=int($val*12+0.5);$a<256 ? pack("C4",$a,1,12,0) : undef',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
        Writable => 'undef',
        Count => 4,
    },
    0x008c => {
        Name => 'ContrastCurve', #JD
        Writable => 'undef',
        Flags => [ 'Binary', 'Protected' ],
    },
    # ColorHue: MODE1/MODE1a=sRGB, MODE2=Adobe RGB, MODE3a=more saturated sRGB
    # --> should really be called ColorSpace or ColorMode, but that would conflict with other tags
    0x008d => { Name => 'ColorHue' ,        Writable => 'string' }, #2
    # SceneMode takes on the following values: PORTRAIT, PARTY/INDOOR, NIGHT PORTRAIT,
    # BEACH/SNOW, LANDSCAPE, SUNSET, NIGHT SCENE, MUSEUM, FIREWORKS, CLOSE UP, COPY,
    # BACK LIGHT, PANORAMA ASSIST, SPORT, DAWN/DUSK
    0x008f => { Name => 'SceneMode',        Writable => 'string' }, #2
    # LightSource shows 3 values COLORED SPEEDLIGHT NATURAL.
    # (SPEEDLIGHT when flash goes. Have no idea about difference between other two.)
    0x0090 => { Name => 'LightSource',      Writable => 'string' }, #2
    0x0091 => [ #18
        { #PH
            Condition => '$$valPt =~ /^0209/',
            Name => 'ShotInfoD40',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD40',
                DecryptStart => 4,
                DecryptLen => 748,
                ByteOrder => 'BigEndian',
            },
        },
        {
            Condition => '$$valPt =~ /^0208/',
            Name => 'ShotInfoD80',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD80',
                DecryptStart => 4,
                DecryptLen => 765,
                # (Capture NX can change the makernote byte order, but this stays big-endian)
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D90, firmware 1.00)
            Condition => '$$valPt =~ /^0213/',
            Name => 'ShotInfoD90',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD90',
                DecryptStart => 4,
                DecryptLen => 0x398,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D3, firmware 0.37 and 1.00)
            Condition => '$$valPt =~ /^0210/ and $count == 5399',
            Name => 'ShotInfoD3a',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD3a',
                DecryptStart => 4,
                DecryptLen => 0x318,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D3, firmware 1.10, 2.00 and 2.01 [count 5408], and 2.02 [count 5412])
            Condition => '$$valPt =~ /^0210/ and ($count == 5408 or $count == 5412)',
            Name => 'ShotInfoD3b',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD3b',
                DecryptStart => 4,
                DecryptLen => 0x321,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D3X, firmware 1.00)
            Condition => '$$valPt =~ /^0214/ and $count == 5409',
            Name => 'ShotInfoD3X',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD3X',
                DecryptStart => 4,
                DecryptLen => 0x323,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D3S, firmware 0.16 and 1.00)
            Condition => '$$valPt =~ /^0218/ and ($count == 5356 or $count == 5388)',
            Name => 'ShotInfoD3S',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD3S',
                DecryptStart => 4,
                DecryptLen => 0x2e9,
                ByteOrder => 'BigEndian',
            },
        },
        { #JD (D300, firmware 0.25 and 1.00)
            # D3 and D300 use the same version number, but the length is different
            Condition => '$$valPt =~ /^0210/ and $count == 5291',
            Name => 'ShotInfoD300a',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD300a',
                DecryptStart => 4,
                DecryptLen => 813,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D300, firmware version 1.10)
            # yet again the same ShotInfoVersion for different data
            Condition => '$$valPt =~ /^0210/ and $count == 5303',
            Name => 'ShotInfoD300b',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD300b',
                DecryptStart => 4,
                DecryptLen => 825,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D300S, firmware version 1.00)
            # yet again the same ShotInfoVersion for different data
            Condition => '$$valPt =~ /^0216/ and $count == 5311',
            Name => 'ShotInfoD300S',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD300S',
                DecryptStart => 4,
                DecryptLen => 827,
                ByteOrder => 'BigEndian',
            },
        },
        # 0225 - D600
        { #29 (D700 firmware version 1.02f)
            Condition => '$$valPt =~ /^0212/ and $count == 5312',
            Name => 'ShotInfoD700',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD700',
                DecryptStart => 4,
                DecryptLen => 0x358,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH (D800 firmware 1.01a)
            Condition => '$$valPt =~ /^0222/',
            Name => 'ShotInfoD800',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD800',
                DecryptStart => 4,
                DecryptLen => 0x720,
                ByteOrder => 'BigEndian',
            },
        },
        { #28 (D810 firmware 1.01)
            Condition => '$$valPt =~ /^0233/',
            Name => 'ShotInfoD810',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD810',
                DecryptStart => 4,
                DecryptLen => 0x36f4 + 12,
                DecryptMore => 'Get32u(\$data, 0x84) + 12',
                ByteOrder => 'LittleEndian',
            },
        },
        { #28 (D850 firmware 1.00b)
            Condition => '$$valPt =~ /^0243/',
            Name => 'ShotInfoD850',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD850',
                DecryptStart => 4,
                # initially only decrypt enough to extract CustomSettingsOffset
                DecryptLen => 0x58,
                # then decrypt through to the end of the custom settings
                DecryptMore => 'Get32u(\$data, 0x58) + 90 + 4',
                ByteOrder => 'LittleEndian',
            },
        },
        # 0217 - D3000
        # 0219 - D3100
        # 0224 - D3200
        { #PH
            Condition => '$$valPt =~ /^0215/ and $count == 6745',
            Name => 'ShotInfoD5000',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD5000',
                DecryptStart => 4,
                DecryptLen => 0x39a,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH
            Condition => '$$valPt =~ /^0221/ and $count == 8902',
            Name => 'ShotInfoD5100',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD5100',
                DecryptStart => 4,
                DecryptLen => 0x430,
                ByteOrder => 'BigEndian',
            },
        },
        { #PH
            Condition => '$$valPt =~ /^0226/ and $count == 11587',
            Name => 'ShotInfoD5200',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD5200',
                DecryptStart => 4,
                DecryptLen => 0xd00,
                ByteOrder => 'BigEndian',
            },
        },
        { #29 (D7000 firmware version 1.01b)
            Condition => '$$valPt =~ /^0220/',
            Name => 'ShotInfoD7000',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD7000',
                DecryptStart => 4,
                DecryptLen => 0x448,
                ByteOrder => 'BigEndian',
            },
        },
        { # (D4 firmware version 1.00g)
            Condition => '$$valPt =~ /^0223/',
            Name => 'ShotInfoD4',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD4',
                DecryptStart => 4,
                DecryptLen => 0x789,
                ByteOrder => 'BigEndian',
            },
        },
        { # (D4S firmware version 1.00d and 1.01a)
            Condition => '$$valPt =~ /^0231/',
            Name => 'ShotInfoD4S',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD4S',
                DecryptStart => 4,
                DecryptLen => 0x3697,
                ByteOrder => 'LittleEndian',
            },
        },
        { #28 (D5 firmware version 1.10a)
            Condition => '$$valPt =~ /^0238/',
            Name => 'ShotInfoD5',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD500',
                DecryptStart => 4,
                DecryptLen => 0x2c24 + 12,
                DecryptMore => 'Get32u(\$data, 0xa0) + 12',
                ByteOrder => 'LittleEndian',
            },
        },
        { # (D500 firmware version 1.00)
            Condition => '$$valPt =~ /^0239/',
            Name => 'ShotInfoD500',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD500',
                DecryptStart => 4,
                DecryptLen => 0x2cb2 + 4,
                DecryptMore => 'Get32u(\$data, 0xa0) + 12',
                ByteOrder => 'LittleEndian',
            },
        },
        { # (D610 firmware version 1.00)
            Condition => '$$valPt =~ /^0232/',
            Name => 'ShotInfoD610',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfoD610',
                DecryptStart => 4,
                DecryptLen => 0x7ff,
                ByteOrder => 'BigEndian',
            },
        },
        # 0227 - D7100
        {
            Condition => '$$valPt =~ /^02/',
            Name => 'ShotInfo02xx',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfo',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
                DecryptLen => 0x251,
                ByteOrder => 'BigEndian',
            },
        },
        {
            Name => 'ShotInfoUnknown',
            Writable => 0,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ShotInfo',
                ByteOrder => 'BigEndian',
            },
        },
    ],
    0x0092 => { #2
        Name => 'HueAdjustment',
        Writable => 'int16s',
    },
    # 0x0093 - ref 15 calls this Saturation, but this is wrong - PH
    0x0093 => { #21
        Name => 'NEFCompression',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Lossy (type 1)', # (older models)
            2 => 'Uncompressed', #JD - D100 (even though TIFF compression is set!)
            3 => 'Lossless',
            4 => 'Lossy (type 2)',
            5 => 'Striped packed 12 bits', #IB
            6 => 'Uncompressed (reduced to 12 bit)', #IB
            7 => 'Unpacked 12 bits', #IB (padded to 16)
            8 => 'Small', #IB
            9 => 'Packed 12 bits', #IB (2 pixels in 3 bytes)
        },
    },
    0x0094 => { Name => 'Saturation',       Writable => 'int16s' },
    0x0095 => { Name => 'NoiseReduction',   Writable => 'string' }, # ("Off" or "FPNR"=long exposure NR)
    0x0096 => {
        Name => 'NEFLinearizationTable', # same table as DNG LinearizationTable (ref JD)
        Writable => 'undef',
        Flags => [ 'Binary', 'Protected' ],
    },
    0x0097 => [ #4
        # (NOTE: these are byte-swapped by NX when byte order changes)
        {
            Condition => '$$valPt =~ /^0100/', # (D100 and Coolpix models)
            Name => 'ColorBalance0100',
            SubDirectory => {
                Start => '$valuePtr + 72',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance1',
            },
        },
        {
            Condition => '$$valPt =~ /^0102/', # (D2H)
            Name => 'ColorBalance0102',
            SubDirectory => {
                Start => '$valuePtr + 10',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
            },
        },
        {
            Condition => '$$valPt =~ /^0103/', # (D70/D70s)
            Name => 'ColorBalance0103',
            # D70:  at file offset 'tag-value + base + 20', 4 16 bits numbers,
            # v[0]/v[1] , v[2]/v[3] are the red/blue multipliers.
            SubDirectory => {
                Start => '$valuePtr + 20',
                TagTable => 'Image::ExifTool::Nikon::ColorBalance3',
            },
        },
        {
            Condition => '$$valPt =~ /^0205/', # (D50)
            Name => 'ColorBalance0205',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
                DecryptLen => 22, # 284 bytes encrypted, but don't need to decrypt it all
                DirOffset => 14,
            },
        },
        {   # (D3/D3X/D300/D700=0209,D300S=0212,D3S=0214)
            Condition => '$$valPt =~ /^02(09|12|14)/',
            Name => 'ColorBalance0209',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance4',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 18, # 324 bytes encrypted, but don't need to decrypt it all
                DirOffset => 10,
            },
        },
        {   # (D2X/D2Xs=0204,D2Hs=0206,D200=0207,D40/D40X/D80=0208,D60=0210)
            Condition => '$$valPt =~ /^02(\d{2})/ and $1 < 11',
            Name => 'ColorBalance02',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 14, # don't need to decrypt it all
                DirOffset => 6,
            },
        },
        {
            Condition => '$$valPt =~ /^0211/', # (D90/D5000)
            Name => 'ColorBalance0211',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance4',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 24, # don't need to decrypt it all
                DirOffset => 16,
            },
        },
        {
            Condition => '$$valPt =~ /^0213/', # (D3000)
            Name => 'ColorBalance0213',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance2',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 18, # don't need to decrypt it all
                DirOffset => 10,
            },
        },
        {   # (D3100=0215,D7000/D5100=0216,D4/D800/D3200=0217)
            Condition => '$$valPt =~ /^021[567]/',
            Name => 'ColorBalance0215',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalance4',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 12, # don't need to decrypt it all
                DirOffset => 4,
            },
        },
        {   # (D5200/D7100=0218, D5300=0219, D610/Df=0220, D3300=0221, CoolpixA=0601)
            Name => 'ColorBalanceUnknown02',
            Condition => '$$valPt =~ /^0[26]/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceUnknown',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 284,
                DecryptLen => 10, # (arbitrary)
            },
        },
        {   # (1J1/1J2/1V1=0400, 1V2=0401, 1J3/1S1=0402, 1AW1=0403)
            Name => 'ColorBalanceUnknown04',
            Condition => '$$valPt =~ /^04/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::ColorBalanceUnknown',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
                DecryptLen => 10, # (arbitrary)
            },
        },
        {
            # (CoolpixP7700/P7800=0500, CoolpixP330/P520=0502)
            Name => 'ColorBalanceUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::ColorBalanceUnknown' },
        },
    ],
    0x0098 => [
        { #8
            Condition => '$$valPt =~ /^0100/', # D100, D1X - PH
            Name => 'LensData0100',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::LensData00' },
        },
        { #8
            Condition => '$$valPt =~ /^0101/', # D70, D70s - PH
            Name => 'LensData0101',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::LensData01' },
        },
        # note: this information is encrypted if the version is 02xx
        { #8
            # 0201 - D200, D2Hs, D2X and D2Xs
            # 0202 - D40, D40X and D80
            # 0203 - D300
            Condition => '$$valPt =~ /^020[1-3]/',
            Name => 'LensData0201',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData01',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        { #PH
            Condition => '$$valPt =~ /^0204/', # D90, D7000
            Name => 'LensData0204',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData0204',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        {
            Condition => '$$valPt =~ /^0400/', # 1J1, 1V1
            Name => 'LensData0400',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData0400',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        {   # (1J1/1V1=0400)
            Name => 'LensDataUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensDataUnknown',
            },
        },
    ],
    0x0099 => { #2/15
        Name => 'RawImageCenter',
        Writable => 'int16u',
        Count => 2,
    },
    0x009a => { #10
        Name => 'SensorPixelSize',
        Writable => 'rational64u',
        Count => 2,
        PrintConv => '$val=~s/ / x /;"$val um"',
        PrintConvInv => '$val=~tr/a-zA-Z/ /;$val',
    },
    0x009c => { #14
        # L2/L3 has these modes (from owner's manual): - PH
        # Portrait Assist: FACE-PRIORITY AF,PORTRAIT,PORTRAIT LEFT,PORTRAIT RIGHT,
        #                  PORTRAIT CLOSE-UP,PORTRAIT COUPLE,PORTRAIT-FIGURE
        # Landscape Assist:LANDSCAPE,SCENIC VIEW,ARCHITECTURE,GROUP RIGHT,GROUP LEFT
        # Sports Assist:   SPORTS,SPORT SPECTATOR,SPORT COMPOSITE
        # P7100 has test modes: - PH
        #  CREATIVE MONOCHROME,PAINTING,CROSS PROCESS,SOFT,NOSTALGIC SEPIA,
        #  HIGH KEY,LOW KEY,SELECTIVE COLOR,ZOOM EXPOSURE EXP.,DEFOCUS DURING
        Name => 'SceneAssist',
        Writable => 'string',
    },
    0x009e => { #JD
        Name => 'RetouchHistory',
        Writable => 'int16u',
        Count => 10,
        # trim off extra "None" values
        ValueConv => '$val=~s/( 0)+$//; $val',
        ValueConvInv => 'my $n=($val=~/ \d+/g);$n < 9 ? $val . " 0" x (9-$n) : $val',
        PrintConvColumns => 2,
        PrintConv => [
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
            \%retouchValues,
        ],
    },
    0x00a0 => { Name => 'SerialNumber',     Writable => 'string' }, #2
    0x00a2 => { # size of compressed image data plus EOI segment (ref 10)
        Name => 'ImageDataSize',
        Writable => 'int32u',
    },
    # 0x00a3 - int8u: 0 (All DSLR's but D1,D1H,D1X,D100)
    # 0x00a4 - version number found only in NEF images from DSLR models except the
    # D1,D1X,D2H and D100.  Value is "0200" for all available samples except images
    # edited by Nikon Capture Editor 4.3.1 W and 4.4.2 which have "0100" - PH
    0x00a5 => { #15
        Name => 'ImageCount',
        Writable => 'int32u',
    },
    0x00a6 => { #15
        Name => 'DeletedImageCount',
        Writable => 'int32u',
    },
    # the sum of 0xa5 and 0xa6 is equal to 0xa7 ShutterCount (D2X,D2Hs,D2H,D200, ref 10)
    0x00a7 => { # Number of shots taken by camera so far (ref 2)
        Name => 'ShutterCount',
        Writable => 'int32u',
        Protected => 1,
        PrintConv => '$val == 4294965247 ? "n/a" : $val',
        PrintConvInv => '$val eq "n/a" ? 4294965247 : $val',
        Notes => q{
            includes both mechanical and electronic shutter activations for models with
            this feature.  This value is used as a key to decrypt other information, and
            writing this tag causes the other information to be re-encrypted with the
            new key
        },
    },
    0x00a8 => [#JD
        {
            Name => 'FlashInfo0100',
            Condition => '$$valPt =~ /^010[01]/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0100' },
        },
        {
            Name => 'FlashInfo0102',
            Condition => '$$valPt =~ /^0102/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0102' },
        },
        {
            Name => 'FlashInfo0103',
            # (0104 for D7000, 0105 for D800)
            Condition => '$$valPt =~ /^010[345]/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0103' },
        },
        {
            Name => 'FlashInfo0106', # (Df, D610, D3300, D5300, D7100, Coolpix A)
            Condition => '$$valPt =~ /^0106/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0106' },
        },
        {
            Name => 'FlashInfo0107', # (0107 for D4S/D750/D810/D5500/D7200, 0108 for D5/D500/D3400)
            Condition => '$$valPt =~ /^010[78]/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0107' },
        },
        {
            Name => 'FlashInfoUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfoUnknown' },
        },
    ],
    0x00a9 => { Name => 'ImageOptimization',Writable => 'string' },#2
    0x00aa => { Name => 'Saturation',       Writable => 'string' }, #2
    0x00ab => { Name => 'VariProgram',      Writable => 'string' }, #2 (scene mode for DSLR's - PH)
    0x00ac => { Name => 'ImageStabilization',Writable=> 'string' }, #14
    0x00ad => { Name => 'AFResponse',       Writable => 'string' }, #14
    0x00b0 => [{ #PH
        Name => 'MultiExposure',
        Condition => '$$valPt =~ /^0100/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::MultiExposure',
            # Note: this endianness varies with model, but Nikon software may change
            # metadata endianness (although it is unknown how it affects this record),
            # so for now don't specify ByteOrder although it may be wrong if the
            # file is rewritten by Nikon software --> see comments for FileInfo
        },
    },{
        Name => 'MultiExposure',
        Condition => '$$valPt =~ /^0101/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::MultiExposure',
            ByteOrder => 'LittleEndian',
        },
    }],
    0x00b1 => { #14/PH/JD (D80)
        Name => 'HighISONoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Minimal', # for high ISO (>800) when setting is "Off"
            2 => 'Low',     # Low,Normal,High take effect for ISO > 400
            3 => 'Medium Low',
            4 => 'Normal',
            5 => 'Medium High',
            6 => 'High',
        },
    },
    # 0x00b2 (string: "NORMAL  ", 0xc3's, 0xff's or 0x20's)
    0x00b3 => { #14
        Name => 'ToningEffect',
        Writable => 'string',
    },
    0x00b6 => { #PH
        Name => 'PowerUpTime',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        # not clear whether "powered up" means "turned on" or "power applied" - PH
        Notes => 'date/time when camera was last powered up',
        Writable => 'undef',
        # must use RawConv so byte order is correct
        RawConv => sub {
            my $val = shift;
            return $val if length $val < 7;
            my $shrt = GetByteOrder() eq 'II' ? 'v' : 'n';
            my @date = unpack("${shrt}C5", $val);
            return sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @date);
        },
        RawConvInv => sub {
            my $val = shift;
            my $shrt = GetByteOrder() eq 'II' ? 'v' : 'n';
            my @date = ($val =~ /\d+/g);
            return pack("${shrt}C6", @date, 0);
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0x00b7 => { #JD
        Name => 'AFInfo2',
        # (this structure may be byte swapped when rewritten by CaptureNX)
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::AFInfo2' },
    },
    0x00b8 => [{ #PH
        Name => 'FileInfo',
        # unfortunately, some newer models write this as little-endian
        # (and CaptureNX can change the byte order of the maker notes,
        #  but leaves this structure unchanged)
        # - it will be an ongoing pain to keep this list of models up-to-date,
        #   so if only one ordering yields valid DirectoryNumber and FileNumber values,
        #   use it, otherwise default to a-priori knowledge of the camera model
        #   (assume that a valid DirectoryNumber is 100-999, and a valid FileNumber
        #   is 0000-9999, although I have some samples with a DirectoryNumber of 99)
        Condition => q{
            if (length($$valPt) >= 0) {
                my ($dir, $file) = unpack('x6vv', $$valPt);
                my $littleEndian = ($dir >= 100 and $dir <= 999 and $file <= 9999);
                ($dir, $file) = unpack('x6nn', $$valPt);
                my $bigEndian = ($dir >= 100 and $dir <= 999 and $file <= 9999);
                return $littleEndian if $littleEndian xor $bigEndian;
            }
            return $$self{Model} =~ /^NIKON (D4S|D750|D810|D3300|D5200|D5300|D5500|D7100)$/;
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::FileInfo',
            ByteOrder => 'LittleEndian',
        },
    },{
        Name => 'FileInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::FileInfo',
            ByteOrder => 'BigEndian',
        },
    }],
    0x00b9 => { #28
        Name => 'AFTune',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::AFTune' },
    },
    # 0x00ba - custom curve data? (ref 28?) (only in NEF images)
    0x00bb => { #forum6281
        Name => 'RetouchInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::RetouchInfo' },
    },
    # 0x00bc - NEFThumbnail? (forum6281)
    0x00bd => { #PH (P6000)
        Name => 'PictureControlData',
        Writable => 'undef',
        Permanent => 0,
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::PictureControl' },
    },
    0x00c3 => {
        Name => 'BarometerInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::BarometerInfo',
            # (little-endian in II EXIF, big-endian in MOV)
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
    # 0x0e01 - In D70 NEF files produced by Nikon Capture, the data for this tag extends 4 bytes
    # past the end of the maker notes.  Very odd.  I hope these 4 bytes aren't useful because
    # they will get lost by any utility that blindly copies the maker notes (not ExifTool) - PH
    0x0e01 => {
        Name => 'NikonCaptureData',
        Writable => 'undef',
        Permanent => 0,
        # (Drop because may be too large for JPEG images)
        Flags => [ 'Binary', 'Protected', 'Drop' ],
        Notes => q{
            this data is dropped when copying Nikon MakerNotes since it may be too large
            to fit in the EXIF segment of a JPEG image, but it may be copied as a block
            into existing Nikon MakerNotes later if desired
        },
        SubDirectory => {
            DirName => 'NikonCapture',
            TagTable => 'Image::ExifTool::NikonCapture::Main',
        },
    },
    # 0x0e05 written by Nikon Capture to NEF files, values of 1 and 2 - PH
    0x0e09 => { #12
        Name => 'NikonCaptureVersion',
        Writable => 'string',
        PrintConv => undef,
    },
    # 0x0e0e is in D70 Nikon Capture files (not out-of-the-camera D70 files) - PH
    0x0e0e => { #PH
        Name => 'NikonCaptureOffsets',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::CaptureOffsets',
            Validate => '$val =~ /^0100/',
            Start => '$valuePtr + 4',
        },
    },
    0x0e10 => { #17
        Name => 'NikonScanIFD',
        Groups => { 1 => 'NikonScan', 2 => 'Image' },
        Flags => 'SubIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::Scan',
            Start => '$val',
        },
    },
    0x0e13 => [{ # PH/http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,2737.0.html
        Name => 'NikonCaptureEditVersions',
        Condition => '$self->Options("ExtractEmbedded")',
        Notes => q{
            the ExtractEmbedded option may be used to decode settings from the stored
            edit versions, otherwise this is extracted as a binary data block
        },
        Writable => 'undef',
        Permanent => 0,
        Drop => 1, # (may be too large for JPEG images)
        SubDirectory => {
            DirName => 'NikonCaptureEditVersions',
            TagTable => 'Image::ExifTool::NikonCapture::Main',
            ProcessProc => \&ProcessNikonCaptureEditVersions,
            WriteProc => sub { return undef }, # (writing not yet supported)
        },
    },{
        Name => 'NikonCaptureEditVersions',
        Writable => 'undef',
        Permanent => 0,
        Flags => [ 'Binary', 'Protected', 'Drop' ],
    }],
    0x0e1d => { #JD
        Name => 'NikonICCProfile',
        Flags => [ 'Binary', 'Protected' ],
        Writable => 'undef', # must be defined here so tag will be extracted if specified
        WriteCheck => q{
            require Image::ExifTool::ICC_Profile;
            return Image::ExifTool::ICC_Profile::ValidateICC(\$val);
        },
        SubDirectory => {
            DirName => 'NikonICCProfile',
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    0x0e1e => { #PH
        Name => 'NikonCaptureOutput',
        Writable => 'undef',
        Permanent => 0,
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::CaptureOutput',
            Validate => '$val =~ /^0100/',
        },
    },
    0x0e22 => { #28
        Name => 'NEFBitDepth',
        Writable => 'int16u',
        Count => 4,
        Protected => 1,
        PrintConv => {
            '0 0 0 0' => 'n/a (JPEG)',
            '8 8 8 0' => '8 x 3', # TIFF RGB
            '16 16 16 0' => '16 x 3', # TIFF 16-bit RGB
            '12 0 0 0' => 12,
            '14 0 0 0' => 14,
        },
    },
);

# NikonScan IFD entries (ref 17)
%Image::ExifTool::Nikon::Scan = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITE_GROUP => 'NikonScan',
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 1 => 'NikonScan', 2 => 'Image' },
    VARS => { MINOR_ERRORS => 1 }, # this IFD is non-essential and often corrupted
    NOTES => 'This information is written by the Nikon Scan software.',
    0x02 => { Name => 'FilmType',    Writable => 'string', },
    0x40 => { Name => 'MultiSample', Writable => 'string' },
    0x41 => { Name => 'BitDepth',    Writable => 'int16u' },
    0x50 => {
        Name => 'MasterGain',
        Writable => 'rational64s',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    0x51 => {
        Name => 'ColorGain',
        Writable => 'rational64s',
        Count => 3,
        PrintConv => 'sprintf("%.2f %.2f %.2f",split(" ",$val))',
        PrintConvInv => '$val',
    },
    0x60 => {
        Name => 'ScanImageEnhancer',
        Writable => 'int32u',
        PrintConv => \%offOn,
    },
    0x100 => { Name => 'DigitalICE', Writable => 'string' },
    0x110 => {
        Name => 'ROCInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::ROC' },
    },
    0x120 => {
        Name => 'GEMInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::GEM' },
    },
    0x200 => { Name => 'DigitalDEEShadowAdj',   Writable => 'int32u' },
    0x201 => { Name => 'DigitalDEEThreshold',   Writable => 'int32u' },
    0x202 => { Name => 'DigitalDEEHighlightAdj',Writable => 'int32u' },
);

# ref 17
%Image::ExifTool::Nikon::ROC = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    GROUPS => { 0 => 'MakerNotes', 1 => 'NikonScan', 2 => 'Image' },
    0 => {
        Name => 'DigitalROC',
        ValueConv => '$val / 10',
        ValueConvInv => 'int($val * 10)',
    },
);

# ref 17
%Image::ExifTool::Nikon::GEM = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    GROUPS => { 0 => 'MakerNotes', 1 => 'NikonScan', 2 => 'Image' },
    0 => {
        Name => 'DigitalGEM',
        ValueConv => '$val<95 ? $val/20-1 : 4',
        ValueConvInv => '$val == 4 ? 95 : int(($val + 1) * 20)',
    },
);

# Vibration Reduction information - PH (D300)
%Image::ExifTool::Nikon::VRInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'VRInfoVersion',
        Format => 'undef[4]',
        Writable => 0,
    },
    4 => {
        Name => 'VibrationReduction',
        PrintConv => {
            0 => 'n/a', # (1V1 with a non-VR lens)
            1 => 'On',
            2 => 'Off',
        },
    },
    # 5 - values: 0, 1 (VR On), 2 (VR Off)
    6 => {
        Name => 'VRMode',
        PrintConv => {
            0 => 'Normal',
            # 1 - seen this for 1V1 - PH
            2 => 'Active', # (1J1)
        },
    },
    # 7 - values: 0, 1
);

# Face detection information - PH (S8100)
%Image::ExifTool::Nikon::FaceDetect = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int16u',
    DATAMEMBER => [ 0x03 ],
    0x01 => {
        Name => 'FaceDetectFrameSize',
        Format => 'int16u[2]',
    },
    0x03 => {
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x04 => {
        Name => 'Face1Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
        Notes => q{
            top, left, width and height of face detect area in coordinates of
            FaceDetectFrameSize
        },
    },
    0x08 => {
        Name => 'Face2Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x0c => {
        Name => 'Face3Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x10 => {
        Name => 'Face4Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x14 => {
        Name => 'Face5Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0x18 => {
        Name => 'Face6Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0x1c => {
        Name => 'Face7Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0x20 => {
        Name => 'Face8Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
    0x24 => {
        Name => 'Face9Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 9 ? undef : $val',
    },
    0x28 => {
        Name => 'Face10Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 10 ? undef : $val',
    },
    0x2c => {
        Name => 'Face11Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 11 ? undef : $val',
    },
    0x30 => {
        Name => 'Face12Position',
        Format => 'int16u[4]',
        RawConv => '$$self{FacesDetected} < 12 ? undef : $val',
    },
);

# Picture Control information - PH (D300,P6000)
%Image::ExifTool::Nikon::PictureControl = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'PictureControlVersion',
        Format => 'undef[4]',
        Writable => 0,
    },
    4 => {
        Name => 'PictureControlName',
        Format => 'string[20]',
        # make lower case with a leading capital for each word
        PrintConv => \&FormatString,
        PrintConvInv => 'uc($val)',
    },
    24 => {
        Name => 'PictureControlBase',
        Format => 'string[20]',
        PrintConv => \&FormatString,
        PrintConvInv => 'uc($val)',
    },
    # beginning at byte 44, there is some interesting information.
    # here are the observed bytes for each PictureControlMode:
    #            44 45 46 47 48 49 50 51 52 53 54 55 56 57
    # STANDARD   00 01 00 00 00 80 83 80 80 80 80 ff ff ff
    # NEUTRAL    03 c2 00 00 00 ff 82 80 80 80 80 ff ff ff
    # VIVID      00 c3 00 00 00 80 84 80 80 80 80 ff ff ff
    # MONOCHROME 06 4d 00 01 02 ff 82 80 80 ff ff 80 80 ff
    # Neutral2   03 c2 01 00 02 ff 80 7f 81 00 7f ff ff ff (custom)
    # (note that up to 9 different custom picture controls can be stored)
    # --> bytes 44 and 45 are swapped if CaptureNX changes the byte order
    #
    48 => { #21
        Name => 'PictureControlAdjust',
        PrintConv => {
            0 => 'Default Settings',
            1 => 'Quick Adjust',
            2 => 'Full Control',
        },
    },
    49 => {
        Name => 'PictureControlQuickAdjust',
        # settings: -2 to +2 (n/a for Neutral and Monochrome modes)
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    50 => {
        Name => 'Sharpness',
        # settings: 0 to 9, Auto
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"No Sharpening","%d")',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    51 => {
        Name => 'Contrast',
        # settings: -3 to +3, Auto
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    52 => {
        Name => 'Brightness',
        # settings: -1 to +1
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    53 => {
        Name => 'Saturation',
        # settings: -3 to +3, Auto (n/a for Monochrome mode)
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    54 => {
        Name => 'HueAdjustment',
        # settings: -3 to +3 (n/a for Monochrome mode)
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None")',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    55 => {
        Name => 'FilterEffect',
        # settings: Off,Yellow,Orange,Red,Green (n/a for color modes)
        DelValue => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x80 => 'Off',
            0x81 => 'Yellow',
            0x82 => 'Orange',
            0x83 => 'Red',
            0x84 => 'Green',
            0xff => 'n/a',
        },
    },
    56 => {
        Name => 'ToningEffect',
        # settings: B&W,Sepia,Cyanotype,Red,Yellow,Green,Blue-Green,Blue,
        #           Purple-Blue,Red-Purple (n/a for color modes)
        DelValue => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x80 => 'B&W',
            0x81 => 'Sepia',
            0x82 => 'Cyanotype',
            0x83 => 'Red',
            0x84 => 'Yellow',
            0x85 => 'Green',
            0x86 => 'Blue-green',
            0x87 => 'Blue',
            0x88 => 'Purple-blue',
            0x89 => 'Red-purple',
            0xff => 'n/a',
            # 0x04 - seen for D810 (PH)
        },
    },
    57 => { #21
        Name => 'ToningSaturation',
        # settings: B&W,Sepia,Cyanotype,Red,Yellow,Green,Blue-Green,Blue,
        #           Purple-Blue,Red-Purple (n/a unless ToningEffect is used)
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => '$val==0x7f ? "n/a" : $val',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
);

# Picture Control information V2 (ref 28)
%Image::ExifTool::Nikon::PictureControl2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'PictureControlVersion',
        Format => 'undef[4]',
        Writable => 0,
    },
    4 => {
        Name => 'PictureControlName',
        Format => 'string[20]',
        # make lower case with a leading capital for each word
        PrintConv => \&FormatString,
        PrintConvInv => 'uc($val)',
    },
    24 => {
        Name => 'PictureControlBase',
        Format => 'string[20]',
        PrintConv => \&FormatString,
        PrintConvInv => 'uc($val)',
    },
    # beginning at byte 44, there is some interesting information.
    # here are the observed bytes for each PictureControlMode:
    #            44 45 46 47 48 49 50 51 52 53 54 55 56 57
    # STANDARD   00 01 00 00 00 80 83 80 80 80 80 ff ff ff
    # NEUTRAL    03 c2 00 00 00 ff 82 80 80 80 80 ff ff ff
    # VIVID      00 c3 00 00 00 80 84 80 80 80 80 ff ff ff
    # MONOCHROME 06 4d 00 01 02 ff 82 80 80 ff ff 80 80 ff
    # Neutral2   03 c2 01 00 02 ff 80 7f 81 00 7f ff ff ff (custom)
    # (note that up to 9 different custom picture controls can be stored)
    # --> bytes 44 and 45 are swapped if CaptureNX changes the byte order
    #
    48 => { #21
        Name => 'PictureControlAdjust',
        PrintConv => {
            0 => 'Default Settings',
            1 => 'Quick Adjust',
            2 => 'Full Control',
        },
    },
    49 => {
        Name => 'PictureControlQuickAdjust',
        # settings: -2 to +2 (n/a for Neutral and Monochrome modes)
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    48 => { #21
        Name => 'PictureControlAdjust',
        PrintConv => {
            0 => 'Default Settings',
            1 => 'Quick Adjust',
            2 => 'Full Control',
        },
    },
    49 => {
        Name => 'PictureControlQuickAdjust',
        # settings: -2 to +2 (n/a for Neutral and Monochrome modes)
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    51 => {
        Name => 'Sharpness',
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None","%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val,4)',
    },
    53 => {
        Name => 'Clarity',
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None","%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv2($val,4)',
    },
    55 => {
        Name => 'Contrast',
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None","%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val,4)',
    },
    57 => { #21
        Name => 'Brightness',
        # settings: -1 to +1
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,undef,"%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val,4)',
    },
    59 => {
        Name => 'Saturation',
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None","%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val,4)',
    },
    61 => {
        Name => 'Hue',
        DelValue => 0xff,
        ValueConv => '$val - 0x80',
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None","%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val)',
    },
    63 => {
        Name => 'FilterEffect',
        # settings: Off,Yellow,Orange,Red,Green (n/a for color modes)
        DelValue => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x80 => 'Off',
            0x81 => 'Yellow',
            0x82 => 'Orange',
            0x83 => 'Red',
            0x84 => 'Green',
            0xff => 'n/a',
        },
    },
     64 => {
        Name => 'ToningEffect',
        # settings: B&W,Sepia,Cyanotype,Red,Yellow,Green,Blue-Green,Blue,
        #           Purple-Blue,Red-Purple (n/a for color modes)
        DelValue => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x80 => 'B&W',
            0x81 => 'Sepia',
            0x82 => 'Cyanotype',
            0x83 => 'Red',
            0x84 => 'Yellow',
            0x85 => 'Green',
            0x86 => 'Blue-green',
            0x87 => 'Blue',
            0x88 => 'Purple-blue',
            0x89 => 'Red-purple',
            0xff => 'n/a',
        },
    },
    65 => {
        Name => 'ToningSaturation',
        DelValue => 0xff,
        ValueConv => '$val - 0x80',           #$val == 0x7f (n/a) for "B&W"
        ValueConvInv => '$val + 0x80',
        PrintConv => 'Image::ExifTool::Nikon::PrintPC($val,"None","%.2f",4)',
        PrintConvInv => 'Image::ExifTool::Nikon::PrintPCInv($val,4)',

    },
);

# World Time information - JD (D300)
%Image::ExifTool::Nikon::WorldTime = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Time' },
    0 => {
        Name => 'TimeZone',
        Format => 'int16s',
        PrintConv => q{
            my $sign = $val < 0 ? '-' : '+';
            my $h = int(abs($val) / 60);
            sprintf("%s%.2d:%.2d", $sign, $h, abs($val)-60*$h);
        },
        PrintConvInv => q{
            $val =~ /([-+]?)(\d+):(\d+)/ or return undef;
            return $1 . ($2 * 60 + $3);
        },
    },
    2 => {
        Name => 'DaylightSavings',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    3 => {
        Name => 'DateDisplayFormat',
        PrintConv => {
            0 => 'Y/M/D',
            1 => 'M/D/Y',
            2 => 'D/M/Y',
        },
    },
);

# ISO information - PH (D300)
%Image::ExifTool::Nikon::ISOInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'ISO',
        Notes => 'val = 100 * 2**(raw/12-5)',
        Priority => 0, # because people like to see rounded-off values if they exist
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    # 1 - 0x01
    # 2 - 0x0c (probably the ISO divisor above)
    # 3 - 0x00
    4 => {
        Name => 'ISOExpansion',
        Format => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x000 => 'Off',
            0x101 => 'Hi 0.3',
            0x102 => 'Hi 0.5',
            0x103 => 'Hi 0.7',
            0x104 => 'Hi 1.0',
            0x105 => 'Hi 1.3', # (Hi 1.3-1.7 may be possible with future models)
            0x106 => 'Hi 1.5',
            0x107 => 'Hi 1.7',
            0x108 => 'Hi 2.0', #(NC) - D3 should have this mode
            0x109 => 'Hi 2.3', #IB
            0x10a => 'Hi 2.5', #IB
            0x10b => 'Hi 2.7', #IB
            0x10c => 'Hi 3.0', #IB
            0x10d => 'Hi 3.3', #IB
            0x10e => 'Hi 3.5', #IB
            0x10f => 'Hi 3.7', #IB
            0x110 => 'Hi 4.0', #IB
            0x111 => 'Hi 4.3', #IB
            0x112 => 'Hi 4.5', #IB
            0x113 => 'Hi 4.7', #IB
            0x114 => 'Hi 5.0', #IB
            0x201 => 'Lo 0.3',
            0x202 => 'Lo 0.5',
            0x203 => 'Lo 0.7',
            0x204 => 'Lo 1.0',
        },
    },
    # bytes 6-11 same as 0-4 in my samples (why is this duplicated?)
    6 => {
        Name => 'ISO2',
        Notes => 'val = 100 * 2**(raw/12-5)',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    # 7 - 0x01
    # 8 - 0x0c (probably the ISO divisor above)
    # 9 - 0x00
    10 => {
        Name => 'ISOExpansion2',
        Format => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x000 => 'Off',
            0x101 => 'Hi 0.3',
            0x102 => 'Hi 0.5',
            0x103 => 'Hi 0.7',
            0x104 => 'Hi 1.0',
            0x105 => 'Hi 1.3', # (Hi 1.3-1.7 may be possible with future models)
            0x106 => 'Hi 1.5',
            0x107 => 'Hi 1.7',
            0x108 => 'Hi 2.0', #(NC) - D3 should have this mode
            0x201 => 'Lo 0.3',
            0x202 => 'Lo 0.5',
            0x203 => 'Lo 0.7',
            0x204 => 'Lo 1.0',
        },
    },
    # bytes 12-13: 00 00
);

# distortion information - PH (D5000)
%Image::ExifTool::Nikon::DistortInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'DistortionVersion',
        Format => 'undef[4]',
        Writable => 0,
        Unknown => 1,
    },
    4 => {
        Name => 'AutoDistortionControl',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (underwater)', # (1AW1)
        },
    },
);

# unknown information - PH (D7000)
%Image::ExifTool::Nikon::UnknownInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'UnknownInfoVersion',
        Condition => '$$valPt =~ /^\d{4}/',
        Format => 'undef[4]',
        Writable => 0,
        Unknown => 1,
    },
    # (bytes 6/7 and 8/9 are swapped if CaptureNX changes the byte order)
);

# more unknown information - PH (D7000)
%Image::ExifTool::Nikon::UnknownInfo2 = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'UnknownInfo2Version',
        Condition => '$$valPt =~ /^\d{4}/',
        Format => 'undef[4]',
        Writable => 0,
        Unknown => 1,
    },
    # (byte 4 may be changed from 1 to 0 when rewritten by CaptureNX)
);

# Nikon AF information (ref 13)
%Image::ExifTool::Nikon::AFInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Single Area',
            1 => 'Dynamic Area',
            2 => 'Dynamic Area (closest subject)',
            3 => 'Group Dynamic',
            4 => 'Single Area (wide)',
            5 => 'Dynamic Area (wide)',
        },
    },
    1 => {
        Name => 'AFPoint',
        Notes => 'in some focus modes this value is not meaningful',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Center',
            1 => 'Top',
            2 => 'Bottom',
            3 => 'Mid-left',
            4 => 'Mid-right',
            5 => 'Upper-left',
            6 => 'Upper-right',
            7 => 'Lower-left',
            8 => 'Lower-right',
            9 => 'Far Left',
            10 => 'Far Right',
            # (have also seen values of 11 and 12 when AFPointsInFocus is "(none)" - PH S3500)
        },
    },
    2 => {
        Name => 'AFPointsInFocus',
        Format => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            0x7ff => 'All 11 Points',
            BITMASK => {
                0 => 'Center',
                1 => 'Top',
                2 => 'Bottom',
                3 => 'Mid-left',
                4 => 'Mid-right',
                5 => 'Upper-left',
                6 => 'Upper-right',
                7 => 'Lower-left',
                8 => 'Lower-right',
                9 => 'Far Left',
                10 => 'Far Right',
            },
        },
    },
);

# Nikon AF information for D3 and D300 (ref JD)
%Image::ExifTool::Nikon::AFInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0, 4, 6 ],
    NOTES => "These tags are written by Nikon DSLR's which have the live view feature.",
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'AFInfo2Version',
        Format => 'undef[4]',
        Writable => 0,
        RawConv => '$$self{AFInfo2Version} = $val',
    },
    4 => { #PH
        Name => 'ContrastDetectAF',
        RawConv => '$$self{ContrastDetectAF} = $val',
        PrintConv => \%offOn,
        Notes => 'this is Off for the hybrid AF used in Nikon 1 models',
    },
    5 => [
        {
            Name => 'AFAreaMode',
            Condition => 'not $$self{ContrastDetectAF}',
            Notes => 'ContrastDetectAF Off',
            PrintConv => {
                0 => 'Single Area', # (called "Single Point" in manual - PH)
                1 => 'Dynamic Area', #PH
                2 => 'Dynamic Area (closest subject)', #PH
                3 => 'Group Dynamic', #PH
                4 => 'Dynamic Area (9 points)', #JD/28
                5 => 'Dynamic Area (21 points)', #28
                6 => 'Dynamic Area (51 points)', #28
                7 => 'Dynamic Area (51 points, 3D-tracking)', #PH/28
                8 => 'Auto-area',
                9 => 'Dynamic Area (3D-tracking)', #PH (D5000 "3D-tracking (11 points)")
                10 => 'Single Area (wide)', #PH
                11 => 'Dynamic Area (wide)', #PH
                12 => 'Dynamic Area (wide, 3D-tracking)', #PH
                13 => 'Group Area', #PH
                14 => 'Dynamic Area (25 points)', #PH
                15 => 'Dynamic Area (72 points)', #PH
                16 => 'Group Area (HL)', #28
                17 => 'Group Area (VL)', #28
                128 => 'Single', #PH (1J1,1J2,1J3,1J4,1S1,1S2,1V2,1V3)
                129 => 'Auto (41 points)', #PH (1J1,1J2,1J3,1J4,1S1,1S2,1V1,1V2,1V3,AW1)
                130 => 'Subject Tracking (41 points)', #PH (1J1,1J4,1J3)
                131 => 'Face Priority (41 points)', #PH (1J1,1J3,1S1,1V2,AW1)
                # 134 - seen for 1V1[PhaseDetectAF=0] (PH)
                # 135 - seen for 1J2[PhaseDetectAF=4] (PH)
            },
        },
        { #PH (D3/D90/D5000)
            Name => 'AFAreaMode',
            Notes => 'ContrastDetectAF On',
            PrintConv => {
                0 => 'Contrast-detect', # (D3)
                1 => 'Contrast-detect (normal area)', # (D90/D5000)
                # (D90 and D5000 give value of 2 when set to 'Face Priority' and
                # 'Subject Tracking', but I didn't have a face to shoot at or a
                #  moving subject to track so perhaps this value changes dynamically)
                2 => 'Contrast-detect (wide area)', # (D90/D5000)
                3 => 'Contrast-detect (face priority)', # (ViewNX)
                4 => 'Contrast-detect (subject tracking)', # (ViewNX)
                128 => 'Single', #PH (1V3)
                129 => 'Auto (41 points)', #PH (NC)
                130 => 'Subject Tracking (41 points)', #PH (NC)
                131 => 'Face Priority (41 points)', #PH (NC)
            },
        },
    ],
    6 => {
        Name => 'PhaseDetectAF', #JD(AutoFocus), PH(PhaseDetectAF)
        Notes => 'PrimaryAFPoint and AFPointsUsed below are only valid when this is On',
        RawConv => '$$self{PhaseDetectAF} = $val',
        PrintConv => {
            # [observed AFAreaMode values in square brackets for each PhaseDetectAF value]
            0 => 'Off',
            1 => 'On (51-point)', #PH
            2 => 'On (11-point)', #PH
            3 => 'On (39-point)', #29 (D7000)
            4 => 'On (73-point)', #PH (1J1[128/129],1J2[128/129/135],1J3/1S1/1V2[128/129/131],1V1[129],AW1[129/131])
            5 => 'On (5)', #PH (1S2[128/129], 1J4/1V3[129])
            6 => 'On (105-point)', #PH (1J4/1V3[128/130])
            7 => 'On (153-point)', #PH (D5/D500/D850)
        },
    },
    7 => [
        { #PH/JD
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} < 2',
            Notes => q{
                models with 51-point AF -- 5 rows (A-E) and 11 columns (1-11): D3, D3S, D3X,
                D4, D4S, D300, D300S, D700, D800, D800e and D810
            },
            PrintConvColumns => 5,
            PrintConv => {
                0 => '(none)',
                %afPoints51,
                1 => 'C6 (Center)', # (add " (Center)" to central point)
            },
        },
        { #10
            Name => 'PrimaryAFPoint',
            Notes => 'models with 11-point AF: D90, D3000, D3100, D5000 and D5100',
            Condition => '$$self{PhaseDetectAF} == 2',
            PrintConvColumns => 2,
            PrintConv => {
                0 => '(none)',
                1 => 'Center',
                2 => 'Top',
                3 => 'Bottom',
                4 => 'Mid-left',
                5 => 'Upper-left',
                6 => 'Lower-left',
                7 => 'Far Left',
                8 => 'Mid-right',
                9 => 'Upper-right',
                10 => 'Lower-right',
                11 => 'Far Right',
            },
        },
        { #29
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} == 3',
            Notes => 'models with 39-point AF: D600 and D7000',
            PrintConvColumns => 5,
            PrintConv => {
                0 => '(none)',
                %afPoints39,
                1 => 'C6 (Center)', # (add " (Center)" to central point)
            },
        },
        { #PH
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} == 4',
            Notes => 'Nikon 1 models with older 135-point AF and 73-point phase-detect AF',
            PrintConvColumns => 5,
            PrintConv => {
                0 => '(none)',
                %afPoints135,
                1 => 'E8 (Center)', # (add " (Center)" to central point)
            },
        },
        { #PH (NC)
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} == 5',
            Notes => q{
                Nikon 1 models with newer 135-point AF and 73-point phase-detect AF -- 9
                rows (B-J) and 15 columns (1-15), inside a grid of 11 rows by 15 columns.
                The points are numbered sequentially, with F8 at the center
            },
            PrintConv => {
                0 => '(none)',
                82 => 'F8 (Center)',
                OTHER => sub {
                    my ($val, $inv) = @_;
                    return GetAFPointGrid($val, 15, $inv);
                },
            },
        },
        { #PH
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} == 6',
            Notes => q{
                Nikon 1 models with 171-point AF and 105-point phase-detect AF -- 9 rows
                (B-J) and 19 columns (2-20), inside a grid of 11 rows by 21 columns.  The
                points are numbered sequentially, with F11 at the center
            },
            PrintConv => {
                0 => '(none)',
                #22 => 'B2 (Top-left)',
                #40 => 'B20 (Top-right)',
                115 => 'F11 (Center)',
                #190 => 'J2 (Bottom-left)',
                #208 => 'J20 (Bottom-right)',
                OTHER => sub {
                    my ($val, $inv) = @_;
                    return GetAFPointGrid($val, 21, $inv);
                },
            },
        },
        { #PH
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} == 7 and $$self{AFInfo2Version} eq "0100"',
            Notes => q{
                Nikon models with 153-point AF -- 9 rows (A-I) and 17 columns (1-17): D5,
                D500 and D850
            },
            PrintConvColumns => 5,
            PrintConv => {
                0 => '(none)',
                %afPoints153,
                1 => 'E9 (Center)',
            },
        },
        {
            Name => 'PrimaryAFPoint',
            Condition => '$$self{AFInfo2Version} eq "0100"',
            Notes => 'future models?...',
            PrintConv => {
                0 => '(none)',
                1 => 'Center',
            },
        },
    ],
    8 => [
        { #JD/PH
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} < 2',
            Notes => q{
                models with 51-point AF -- 5 rows: A1-9, B1-11, C1-11, D1-11, E1-9.  Center
                point is C6
            },
            Format => 'undef[7]',
            ValueConv => 'join(" ", unpack("H2"x7, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => sub { PrintAFPoints(shift, \%afPoints51); },
            PrintConvInv => sub { PrintAFPointsInv(shift, \%afPoints51); },
        },
        { #10
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} == 2',
            Notes => 'models with 11-point AF',
            # read as int16u in little-endian byte order
            Format => 'undef[2]',
            ValueConv => 'unpack("v",$val)',
            ValueConvInv => 'pack("v",$val)',
            PrintConvColumns => 2,
            PrintConv => {
                0 => '(none)',
                0x7ff => 'All 11 Points',
                BITMASK => {
                    0 => 'Center',
                    1 => 'Top',
                    2 => 'Bottom',
                    3 => 'Mid-left',
                    4 => 'Upper-left',
                    5 => 'Lower-left',
                    6 => 'Far Left',
                    7 => 'Mid-right',
                    8 => 'Upper-right',
                    9 => 'Lower-right',
                    10 => 'Far Right',
                },
            },
        },
        { #29/PH
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} == 3',
            Notes => q{
                models with 39-point AF -- 5 rows: A1-3, B1-11, C1-11, D1-11, E1-3.  Center
                point is C6
            },
            Format => 'undef[5]',
            ValueConv => 'join(" ", unpack("H2"x5, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => sub { PrintAFPoints(shift, \%afPoints39); },
            PrintConvInv => sub { PrintAFPointsInv(shift, \%afPoints39); },
        },
        { #PH (1AW1,1J1,1J2,1J3,1S1,1V1,1V2)
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} == 4',
            Notes => q{
                older models with 135-point AF -- 9 rows (A-I) and 15 columns (1-15).
                Center point is E8.  The odd-numbered columns, columns 2 and 14, and the
                remaining corner points are not used for 41-point AF mode
            },
            Format => 'undef[17]',
            ValueConv => 'join(" ", unpack("H2"x17, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => sub { PrintAFPoints(shift, \%afPoints135); },
            PrintConvInv => sub { PrintAFPointsInv(shift, \%afPoints135); },
        },
        { #PH (1S2)
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} == 5',
            Notes => q{
                newer models with 135-point AF -- 9 rows (B-J) and 15 colums (1-15).  Center
                point is F8
            },
            Format => 'undef[21]',
            ValueConv => 'join(" ", unpack("H2"x21, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => sub { PrintAFPointsGrid(shift, 15); },
            PrintConvInv => sub { PrintAFPointsGridInv(shift, 15, 21); },
        },
        { #PH (1J4,1V3)
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} == 6',
            Notes => q{
                models with 171-point AF -- 9 rows (B-J) and 19 columns (2-20).  Center
                point is F10
            },
            Format => 'undef[29]',
            ValueConv => 'join(" ", unpack("H2"x29, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => sub { PrintAFPointsGrid(shift, 21); },
            PrintConvInv => sub { PrintAFPointsGridInv(shift, 21, 29); },
        },
        { #PH (D5,D500)
            Name => 'AFPointsUsed',
            Condition => '$$self{PhaseDetectAF} == 7',
            Notes => q{
                models with 153-point AF -- 9 rows (A-I) and 17 columns (1-17). Center
                point is E9
            },
            Format => 'undef[20]',
            ValueConv => 'join(" ", unpack("H2"x20, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => sub { PrintAFPoints(shift, \%afPoints153); },
            PrintConvInv => sub { PrintAFPointsInv(shift, \%afPoints153); },
        },
        {
            Name => 'AFPointsUsed',
            Format => 'undef[7]',
            ValueConv => 'join(" ", unpack("H2"x7, $val))',
            ValueConvInv => '$val=~tr/ //d; pack("H*",$val)',
            PrintConv => '"Unknown ($val)"',
            PrintConvInv => '$val=~s/Unknown \\((.*)\\)/$1/; $val',
        },
    ],
    0x10 => { #PH (D90 and D5000)
        Name => 'AFImageWidth',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
        Notes => 'this and the following tags are valid only for contrast-detect AF',
    },
    0x12 => { #PH
        Name => 'AFImageHeight',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x14 => { #PH
        Name => 'AFAreaXPosition',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        Notes => 'center of AF area in AFImage coordinates',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x16 => { #PH
        Name => 'AFAreaYPosition',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    # AFAreaWidth/Height for the D90 and D5000:
    #   352x288 (AF normal area),
    #   704x576 (AF face priority, wide area, subject tracking)
    0x18 => { #PH
        Name => 'AFAreaWidth',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        Format => 'int16u',
        Notes => 'size of AF area in AFImage coordinates',
        RawConv => '$val ? $val : undef',
    },
    0x1a => { #PH
        Name => 'AFAreaHeight',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x1c => { #PH
        Name => 'ContrastDetectAFInFocus',
        Condition => '$$self{AFInfo2Version} eq "0100"',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    # 0x1d - always zero (with or without live view)
    0x44 => [
        {
            Name => 'PrimaryAFPoint',
            Condition => '$$self{PhaseDetectAF} == 7 and $$self{AFInfo2Version} eq "0101"',
            PrintConvColumns => 5,
            PrintConv => {
                0 => '(none)',
                %afPoints153,
                1 => 'E9 (Center)',
            },
        },
        {
            Name => 'PrimaryAFPoint',
            Condition => '$$self{AFInfo2Version} eq "0101"',
            Notes => 'future models?...',
            PrintConv => {
                0 => '(none)',
                1 => 'Center',
            },
        },
    ],
    0x46 => {
        Name => 'AFImageWidth',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
        Notes => 'this and the following tags are valid only for contrast-detect AF',
    },
    0x48 => {
        Name => 'AFImageHeight',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x4a => {
        Name => 'AFAreaXPosition',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        Notes => 'center of AF area in AFImage coordinates',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x4c => {
        Name => 'AFAreaYPosition',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x4e => {
        Name => 'AFAreaWidth',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        Format => 'int16u',
        Notes => 'size of AF area in AFImage coordinates',
        RawConv => '$val ? $val : undef',
    },
    0x50 => {
        Name => 'AFAreaHeight',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
    },
    0x52 => {
        Name => 'ContrastDetectAFInFocus',
        Condition => '$$self{ContrastDetectAF} == 1 and $$self{AFInfo2Version} eq "0101"',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
);

# Nikon AF fine-tune information (ref 28)
%Image::ExifTool::Nikon::AFTune = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'AFFineTune',
        PrintConv => {
            0 => 'Off',
            # (don't know what the difference between 1 and 2 is)
            1 => 'On (1)',
            2 => 'On (2)',
        },
    },
    1 => {
        Name => 'AFFineTuneIndex',
        Notes => 'index of saved lens',
        PrintConv => '$val == 255 ? "n/a" : $val',
        PrintConvInv => '$val eq "n/a" ? 255 : $val',
    },
    2 => {
        Name => 'AFFineTuneAdj',
        Priority => 0, # so other value takes priority if it exists
        Notes => 'may only be valid for saved lenses',
        Format => 'int8s',
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
);

# Nikon NEF processing information (ref forum6281)
%Image::ExifTool::Nikon::RetouchInfo = (
    %binaryDataAttrs,
    FORMAT => 'int8s',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    0 => {
        Name => 'RetouchInfoVersion',
        Format => 'undef[4]',
        Writable => 0,
        RawConv => '$$self{RetouchInfoVersion} = $val',
    },
    # 4 - RetouchExposureComp (+$val/6 or -$val/6?)
    5 => {
        Name => 'RetouchNEFProcessing',
        Condition => '$$self{RetouchInfoVersion} ge "0200"',
        PrintConv => {
            -1 => 'Off',
            1 => 'On',
        },
    },
);

# Nikon File information - D60, D3 and D300 (ref PH)
%Image::ExifTool::Nikon::FileInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int16u',
    0 => {
        Name => 'FileInfoVersion',
        Format => 'undef[4]',
        Writable => 0,
    },
    2 => 'MemoryCardNumber',
    3 => {
        Name => 'DirectoryNumber',
        PrintConv => 'sprintf("%.3d", $val)',
        PrintConvInv => '$val',
    },
    4 => {
        Name => 'FileNumber',
        PrintConv => 'sprintf("%.4d", $val)',
        PrintConvInv => '$val',
    },
);

# ref PH
%Image::ExifTool::Nikon::BarometerInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Location' },
    0 => {
        Name => 'BarometerInfoVersion',
        Format => 'undef[4]',
        Writable => 0,
    },
    6 => {
        Name => 'Altitude',
        Format => 'int32s',
        PrintConv => '"$val m"', # (always stored as metres)
        PrintConvInv => '$val=~s/\s*m$//; $val',
    },
    # 10: int16u - values: 0 (display in metres?), 18 (display in feet?)
);

# ref PH
%Image::ExifTool::Nikon::CaptureOffsets = (
    PROCESS_PROC => \&ProcessNikonCaptureOffsets,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'IFD0_Offset',
    2 => 'PreviewIFD_Offset',
    3 => 'SubIFD_Offset',
);

# ref PH (Written by capture NX)
%Image::ExifTool::Nikon::CaptureOutput = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # 1 = 1
    2 => 'OutputImageWidth',
    3 => 'OutputImageHeight',
    4 => 'OutputResolution',
    # 5 = 1
);

# ref IB
%Image::ExifTool::Nikon::ColorBalanceA = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    624 => { #4
        Name => 'WB_RBLevels',
        Notes => 'as shot', #IB
        Format => 'int16u[2]',
        Protected => 1,
    },
    626 => {
        Name => 'WB_RBLevelsAuto',
        Format => 'int16u[2]',
        Protected => 1,
    },
    628 => {
        Name => 'WB_RBLevelsDaylight',
        Notes => 'red/blue levels for 0,+3,+2,+1,-1,-2,-3',
        Format => 'int16u[14]',
        Protected => 1,
    },
    642 => {
        Name => 'WB_RBLevelsIncandescent',
        Format => 'int16u[14]',
        Protected => 1,
    },
    656 => {
        Name => 'WB_RBLevelsFluorescent',
        Format => 'int16u[6]',
        Notes => 'red/blue levels for fluorescent W,N,D',
        Protected => 1,
    },
    662 => {
        Name => 'WB_RBLevelsCloudy',
        Format => 'int16u[14]',
        Protected => 1,
    },
    676 => {
        Name => 'WB_RBLevelsFlash',
        Format => 'int16u[14]',
        Protected => 1,
    },
    690 => {
        Name => 'WB_RBLevelsShade',
        Condition => '$$self{Model} ne "E8700"',
        Notes => 'not valid for E8700',
        Format => 'int16u[14]',
        Protected => 1,
    },
);

my %nrwLevels = (
    Format => 'int32u[4]',
    Protected => 1,
    ValueConv => 'my @a=split " ",$val;$a[0]*=2;$a[3]*=2;"@a"',
    ValueConvInv => 'my @a=split " ",$val;$a[0]/=2;$a[3]/=2;"@a"',
);

# (ref IB)
%Image::ExifTool::Nikon::ColorBalanceB = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Color balance tags used by the P6000.',
    0x0004 => {
        Name => 'ColorBalanceVersion',
        Format => 'undef[4]',
    },
    0x13e8 => { Name => 'WB_RGGBLevels',            %nrwLevels },
    0x13f8 => { Name => 'WB_RGGBLevelsDaylight',    %nrwLevels },
    0x1408 => { Name => 'WB_RGGBLevelsCloudy',      %nrwLevels },
    0x1428 => { Name => 'WB_RGGBLevelsTungsten',    %nrwLevels },
    0x1438 => { Name => 'WB_RGGBLevelsFluorescentW',%nrwLevels },
    0x1448 => { Name => 'WB_RGGBLevelsFlash',       %nrwLevels },
    0x1468 => { Name => 'WB_RGGBLevelsCustom',      %nrwLevels, Notes => 'all zero if preset WB not used' },
    0x1478 => { Name => 'WB_RGGBLevelsAuto',        %nrwLevels },
);

# (ref IB)
%Image::ExifTool::Nikon::ColorBalanceC = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 4 ],
    NOTES => 'Color balance tags used by the P1000, P7000, P7100 and B700.',
    0x0004 => {
        Name => 'ColorBalanceVersion',
        Format => 'undef[4]',
        RawConv => '$$self{ColorBalanceVersion} = $val',
    },
    0x0020 => { Name => 'BlackLevel', Format => 'int16u' },
    0x0038 => { Name => 'WB_RGGBLevels',            %nrwLevels },
    0x004c => { Name => 'WB_RGGBLevelsDaylight',    %nrwLevels },
    0x0060 => { Name => 'WB_RGGBLevelsCloudy',      %nrwLevels },
    0x0074 => {
        Name => 'WB_RGGBLevelsShade',
        Condition => '$$self{ColorBalanceVersion} ge "0104"',
        Notes => 'valid only for some models',
        %nrwLevels,
    },
    0x0088 => { Name => 'WB_RGGBLevelsTungsten',    %nrwLevels },
    0x009c => { Name => 'WB_RGGBLevelsFluorescentW',%nrwLevels },
    0x00b0 => { Name => 'WB_RGGBLevelsFluorescentN',%nrwLevels },
    0x00c4 => { Name => 'WB_RGGBLevelsFluorescentD',%nrwLevels },
    0x00d8 => { Name => 'WB_RGGBLevelsHTMercury',   %nrwLevels },
    0x0100 => { Name => 'WB_RGGBLevelsCustom',      %nrwLevels, Notes => 'all zero if preset WB not used' },
    0x0114 => { Name => 'WB_RGGBLevelsAuto',        %nrwLevels },
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance1 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'WB_RBGGLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance2 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is encrypted for most camera models.',
    0 => {
        Name => 'WB_RGGBLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance3 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'WB_RGBGLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

# ref 4
%Image::ExifTool::Nikon::ColorBalance4 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'WB_GRBGLevels',
        Format => 'int16u[4]',
        Protected => 1,
    },
);

%Image::ExifTool::Nikon::ColorBalanceUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'ColorBalanceVersion',
        Format => 'undef[4]',
    },
);

%Image::ExifTool::Nikon::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0003 => 'Quality',
    0x0004 => 'ColorMode',
    0x0005 => 'ImageAdjustment',
    0x0006 => 'CCDSensitivity',
    0x0007 => 'WhiteBalance',
    0x0008 => 'Focus',
    0x000A => 'DigitalZoom',
    0x000B => 'Converter',
);

# these are standard EXIF tags, but they are duplicated here so we can
# set the family 0 group to 'MakerNotes' and set the MINOR_ERRORS flag
%Image::ExifTool::Nikon::PreviewIFD = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'PreviewIFD', 2 => 'Image'},
    VARS => { MINOR_ERRORS => 1 }, # this IFD is non-essential and often corrupted
    # (these tags are priority 0 by default because PreviewIFD is flagged in LOW_PRIORITY_DIR)
    0xfe => { # (not used by Nikon, but SRW images also use this table)
        Name => 'SubfileType',
        DataMember => 'SubfileType',
        RawConv => '$$self{SubfileType} = $val',
        PrintConv => \%Image::ExifTool::Exif::subfileType,
    },
    0x103 => {
        Name => 'Compression',
        SeparateTable => 'EXIF Compression',
        PrintConv => \%Image::ExifTool::Exif::compression,
    },
    0x11a => 'XResolution',
    0x11b => 'YResolution',
    0x128 => {
        Name => 'ResolutionUnit',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    0x201 => {
        Name => 'PreviewImageStart',
        Flags => [ 'IsOffset', 'Permanent' ],
        OffsetPair => 0x202,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x202 => {
        Name => 'PreviewImageLength',
        Flags => 'Permanent' ,
        OffsetPair => 0x201,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x213 => {
        Name => 'YCbCrPositioning',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
    },
);

# these are duplicated enough times to make it worthwhile to define them centrally
my %nikonApertureConversions = (
    ValueConv => '2**($val/24)',
    ValueConvInv => '$val>0 ? 24*log($val)/log(2) : 0',
    PrintConv => 'sprintf("%.1f",$val)',
    PrintConvInv => '$val',
);

my %nikonFocalConversions = (
    ValueConv => '5 * 2**($val/24)',
    ValueConvInv => '$val>0 ? 24*log($val/5)/log(2) : 0',
    PrintConv => 'sprintf("%.1f mm",$val)',
    PrintConvInv => '$val=~s/\s*mm$//;$val',
);

# Version 100 Nikon lens data
%Image::ExifTool::Nikon::LensData00 = (
    %binaryDataAttrs,
    NOTES => 'This structure is used by the D100, and D1X with firmware version 1.1.',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'undef[4]',
        Writable => 0,
    },
    0x06 => { #8
        Name => 'LensIDNumber',
        Notes => 'see LensID values below',
    },
    0x07 => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x08 => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x09 => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x0a => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x0b => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x0c => 'MCUVersion', #8 (MCU = Micro Controller Unit)
);

# Nikon lens data (note: needs decrypting if LensDataVersion is 020x)
%Image::ExifTool::Nikon::LensData01 = (
    %binaryDataAttrs,
    NOTES => q{
        Nikon encrypts the LensData information below if LensDataVersion is 0201 or
        higher, but  the decryption algorithm is known so the information can be
        extracted.
    },
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => { #8
        Name => 'ExitPupilPosition',
        ValueConv => '$val ? 2048 / $val : $val',
        ValueConvInv => '$val ? 2048 / $val : $val',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//; $val',
    },
    0x05 => { #8
        Name => 'AFAperture',
        %nikonApertureConversions,
    },
    0x08 => { #8
        # this seems to be 2 values: the upper nibble gives the far focus
        # range and the lower nibble gives the near focus range.  The values
        # are in the range 1-N, where N is lens-dependent.  A value of 0 for
        # the far focus range indicates infinity. (ref JD)
        Name => 'FocusPosition',
        PrintConv => 'sprintf("0x%02x", $val)',
        PrintConvInv => '$val',
    },
    0x09 => { #8/9
        # With older AF lenses this does not work... (ref 13)
        # eg) AF Nikkor 50mm f/1.4 => 48 (0x30)
        # AF Zoom-Nikkor 35-105mm f/3.5-4.5 => @35mm => 15 (0x0f), @105mm => 141 (0x8d)
        Notes => 'this focus distance is approximate, and not very accurate for some lenses',
        Name => 'FocusDistance',
        ValueConv => '0.01 * 10**($val/40)', # in m
        ValueConvInv => '$val>0 ? 40*log($val*100)/log(10) : 0',
        PrintConv => '$val ? sprintf("%.2f m",$val) : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s*m$//, $val',
    },
    0x0a => { #8/9
        Name => 'FocalLength',
        Priority => 0,
        %nikonFocalConversions,
    },
    0x0b => { #8
        Name => 'LensIDNumber',
        Notes => 'see LensID values below',
    },
    0x0c => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x0d => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x0e => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x0f => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x10 => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x11 => 'MCUVersion', #8 (MCU = Micro Controller Unit)
    0x12 => { #8
        Name => 'EffectiveMaxAperture',
        %nikonApertureConversions,
    },
);

# Nikon lens data (note: needs decrypting)
%Image::ExifTool::Nikon::LensData0204 = (
    %binaryDataAttrs,
    NOTES => q{
        Nikon encrypts the LensData information below if LensDataVersion is 0201 or
        higher, but  the decryption algorithm is known so the information can be
        extracted.
    },
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => { #8
        Name => 'ExitPupilPosition',
        ValueConv => '$val ? 2048 / $val : $val',
        ValueConvInv => '$val ? 2048 / $val : $val',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//; $val',
    },
    0x05 => { #8
        Name => 'AFAperture',
        %nikonApertureConversions,
    },
    0x08 => { #8
        # this seems to be 2 values: the upper nibble gives the far focus
        # range and the lower nibble gives the near focus range.  The values
        # are in the range 1-N, where N is lens-dependent.  A value of 0 for
        # the far focus range indicates infinity. (ref JD)
        Name => 'FocusPosition',
        PrintConv => 'sprintf("0x%02x", $val)',
        PrintConvInv => '$val',
    },
    # --> extra byte at position 0x09 in this version of LensData (PH)
    0x0a => { #8/9
        # With older AF lenses this does not work... (ref 13)
        # eg) AF Nikkor 50mm f/1.4 => 48 (0x30)
        # AF Zoom-Nikkor 35-105mm f/3.5-4.5 => @35mm => 15 (0x0f), @105mm => 141 (0x8d)
        Notes => 'this focus distance is approximate, and not very accurate for some lenses',
        Name => 'FocusDistance',
        ValueConv => '0.01 * 10**($val/40)', # in m
        ValueConvInv => '$val>0 ? 40*log($val*100)/log(10) : 0',
        PrintConv => '$val ? sprintf("%.2f m",$val) : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s*m$//, $val',
    },
    0x0b => { #8/9
        Name => 'FocalLength',
        Priority => 0,
        %nikonFocalConversions,
    },
    0x0c => { #8
        Name => 'LensIDNumber',
        Notes => 'see LensID values below',
    },
    0x0d => { #8
        Name => 'LensFStops',
        ValueConv => '$val / 12',
        ValueConvInv => '$val * 12',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x0e => { #8/9
        Name => 'MinFocalLength',
        %nikonFocalConversions,
    },
    0x0f => { #8/9
        Name => 'MaxFocalLength',
        %nikonFocalConversions,
    },
    0x10 => { #8
        Name => 'MaxApertureAtMinFocal',
        %nikonApertureConversions,
    },
    0x11 => { #8
        Name => 'MaxApertureAtMaxFocal',
        %nikonApertureConversions,
    },
    0x12 => 'MCUVersion', #8 (MCU = Micro Controller Unit)
    0x13 => { #8
        Name => 'EffectiveMaxAperture',
        %nikonApertureConversions,
    },
);

# Nikon lens data version 0400 (note: needs decrypting) (ref PH)
%Image::ExifTool::Nikon::LensData0400 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Tags extracted from the encrypted lens data of Nikon 1 models.',
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x18a => { #PH
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Unknown Nikon lens data (note: data may need decrypting after byte 4)
%Image::ExifTool::Nikon::LensDataUnknown = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'LensDataVersion',
        Format => 'string[4]',
    },
);

# shot information (encrypted in some cameras) - ref 18
%Image::ExifTool::Nikon::ShotInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    NOTES => q{
        This information is encrypted for ShotInfoVersion 02xx, and some tags are
        only valid for specific models.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
        RawConv => '$$self{ShotInfoVersion} = $val; $val =~ /^\d+$/ ? $val : undef',
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$val =~ /^\d\.\d+.$/ ? $val : undef',
    },
    0x10 => {
        Name => 'DistortionControl',
        Condition => '$$self{Model} =~ /P6000\b/',
        Notes => 'P6000',
        PrintConv => \%offOn,
    },
    0x66 => {
        Name => 'VR_0x66',
        Condition => '$$self{ShotInfoVersion} eq "0204"',
        Format => 'int8u',
        Unknown => 1,
        Notes => 'D2X, D2Xs (unverified)',
        PrintConv => {
            0 => 'Off',
            1 => 'On (normal)',
            2 => 'On (active)',
        },
    },
    # 6a, 6e not correct for 0103 (D70), 0207 (D200)
    0x6a => {
        Name => 'ShutterCount',
        Condition => '$$self{ShotInfoVersion} eq "0204"',
        Format => 'int32u',
        Priority => 0,
        Notes => 'D2X, D2Xs',
    },
    0x6e => {
        Name => 'DeletedImageCount',
        Condition => '$$self{ShotInfoVersion} eq "0204"',
        Format => 'int32u',
        Priority => 0,
        Notes => 'D2X, D2Xs',
    },
    0x75 => { #JD
        Name => 'VibrationReduction',
        Condition => '$$self{ShotInfoVersion} eq "0207"',
        Format => 'int8u',
        Notes => 'D200',
        PrintConv => {
            0 => 'Off',
            # (not sure what the different values represent, but values
            # of 1 and 2 have even been observed for non-VR lenses!)
            1 => 'On (1)', #PH
            2 => 'On (2)', #PH
            3 => 'On (3)', #PH (rare -- only seen once)
        },
    },
    0x82 => { # educated guess, needs verification
        Name => 'VibrationReduction',
        Condition => '$$self{ShotInfoVersion} eq "0204"',
        Format => 'int8u',
        Notes => 'D2X, D2Xs',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x157 => { #JD
        Name => 'ShutterCount',
        Condition => '$$self{ShotInfoVersion} eq "0205"',
        Format => 'undef[2]',
        Priority => 0,
        Notes => 'D50',
        # treat as a 2-byte big-endian integer
        ValueConv => 'unpack("n", $val)',
        ValueConvInv => 'pack("n",$val)',
    },
    0x1ae => { #JD
        Name => 'VibrationReduction',
        Condition => '$$self{ShotInfoVersion} eq "0205"',
        Format => 'int8u',
        Notes => 'D50',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'n/a',
            0x0c => 'Off',
            0x0f => 'On',
        },
    },
    0x24d => { #PH
        Name => 'ShutterCount',
        Condition => '$$self{ShotInfoVersion} eq "0211"',
        Notes => 'D60',
        Format => 'int32u',
        Priority => 0,
    },
    # note: DecryptLen currently set to 0x251
);

# shot information for D40 and D40X (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD40 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 729 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in D40 and D40X images.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    582 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    586.1 => { #JD
        Name => 'VibrationReduction',
        Mask => 0x08,
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    729 => { #JD
        Name => 'CustomSettingsD40',
        Format => 'undef[12]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD40',
        },
    },
    # note: DecryptLen currently set to 748
);

# shot information for D80 (encrypted) - ref JD
%Image::ExifTool::Nikon::ShotInfoD80 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 748 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in D80 images.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    586 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    # split 590 into a few different tags
    590.1 => {
        Name => 'Rotation',
        Mask => 0x07,
        PrintConv => {
            0 => 'Horizontal',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 90 CW',
            3 => 'Rotate 180',
        },
    },
    590.2 => {
        Name => 'VibrationReduction',
        Mask => 0x18,
        PrintConv => {
            0 => 'Off',
            3 => 'On',
        },
    },
    590.3 => {
        Name => 'FlashFired',
        Mask => 0xe0,
        PrintConv => { BITMASK => {
            1 => 'Internal',
            2 => 'External',
        }},
    },
    708 => {
        Name => 'NikonImageSize',
        Mask => 0xf0,
        PrintConv => {
            0 => 'Large (10.0 M)',
            1 => 'Medium (5.6 M)',
            2 => 'Small (2.5 M)',
        },
    },
    708.1 => {
        Name => 'ImageQuality',
        Mask => 0x0f,
        PrintConv => {
            0 => 'NEF (RAW)',
            1 => 'JPEG Fine',
            2 => 'JPEG Normal',
            3 => 'JPEG Basic',
            4 => 'NEF (RAW) + JPEG Fine',
            5 => 'NEF (RAW) + JPEG Normal',
            6 => 'NEF (RAW) + JPEG Basic',
        },
    },
    748 => { #JD
        Name => 'CustomSettingsD80',
        Format => 'undef[17]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD80',
        },
    },
    # note: DecryptLen currently set to 765
);

# shot information for D90 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD90 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x374 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D90 with
        firmware 1.00.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x2b5 => { #JD (same value found at offset 0x39, 0x2bf, 0x346)
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x2d5 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    0x374 => {
        Name => 'CustomSettingsD90',
        Format => 'undef[36]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD90',
        },
    },
    # note: DecryptLen currently set to 0x398
);

# shot information for the D3 firmware 0.37 and 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD3a = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x301 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D3 with
        firmware 1.00 and earlier.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x256 => { #JD (same value found at offset 0x26b)
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x276 => { #JD
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    723.1 => {
        Name => 'NikonImageSize',
        Mask => 0x18,
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    723.2 => {
        Name => 'ImageQuality',
        Mask => 0x07,
        PrintConv => {
            0 => 'NEF (RAW) + JPEG Fine',
            1 => 'NEF (RAW) + JPEG Norm',
            2 => 'NEF (RAW) + JPEG Basic',
            3 => 'NEF (RAW)',
            4 => 'TIF (RGB)',
            5 => 'JPEG Fine',
            6 => 'JPEG Normal',
            7 => 'JPEG Basic',
        },
    },
    0x301 => { #(NC)
        Name => 'CustomSettingsD3',
        Format => 'undef[24]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 0x318
);

# shot information for the D3 firmware 1.10, 2.00 and 2.01 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD3b = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x30a ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 4 ],
    NOTES => q{
        These tags are extracted from encrypted data in images from the D3 with
        firmware 1.10, 2.00, 2.01 and 2.02.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$$self{FirmwareVersion} = $val',
    },
    0x10 => { #28
        Name => 'ImageArea',
        PrintConv => {
            0 => 'FX (36.0 x 23.9 mm)',
            1 => 'DX (23.5 x 15.6 mm)',
            2 => '5:4 (30.0 x 23.9 mm)',
        },
    },
    0x25d => {
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x27d => {
        Name => 'ShutterCount',
        Condition => '$$self{FirmwareVersion} =~ /^1.01/',
        Notes => 'firmware 1.10',
        Format => 'int32u',
        Priority => 0,
    },
    0x27f => {
        Name => 'ShutterCount',
        Condition => '$$self{FirmwareVersion} =~ /^2.0/',
        Notes => 'firmware 2.00, 2.01 and 2.02',
        Format => 'int32u',
        Priority => 0,
    },
    732.1 => { #28
        Name => 'NikonImageSize',
        Mask => 0x18,
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    732.2 => { #28
        Name => 'ImageQuality',
        Mask => 0x07,
        PrintConv => {
            0 => 'NEF (RAW) + JPEG Fine',
            1 => 'NEF (RAW) + JPEG Norm',
            2 => 'NEF (RAW) + JPEG Basic',
            3 => 'NEF (RAW)',
            4 => 'TIF (RGB)',
            5 => 'JPEG Fine',
            6 => 'JPEG Normal',
            7 => 'JPEG Basic',
        },
    },
    0x28a => { #28
        Name => 'PreFlashReturnStrength',
        Notes => 'valid in TTL and TTL-BL flash control modes',
        # this is used to set the flash power using this relationship
        # for the SB-800 and SB-900:
        # $val < 140 ? 2**(0.08372*$val-12.352) : $val
    },
    0x30a => { # tested with firmware 2.00
        Name => 'CustomSettingsD3',
        Format => 'undef[24]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 0x321
);

# shot information for the D3X firmware 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD3X = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x30b ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D3X with
        firmware 1.00.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x25d => {
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x280 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    0x30b => { #(NC)
        Name => 'CustomSettingsD3X',
        Format => 'undef[24]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 0x323
);

# shot information for the D3S firmware 0.16 and 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD3S = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x2ce ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D3S with
        firmware 1.00 and earlier.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x10 => { #28
        Name => 'ImageArea',
        PrintConv => {
            0 => 'FX (36x24)',
            1 => 'DX (24x16)',
            2 => '5:4 (30x24)',
            3 => '1.2x (30x20)',
        },
    },
    0x221 => {
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x242 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    0x2ce => { #(NC)
        Name => 'CustomSettingsD3S',
        Format => 'undef[27]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 0x2e9
);

# shot information for the D300 firmware 1.00 (encrypted) - ref JD
%Image::ExifTool::Nikon::ShotInfoD300a = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 790 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D300 with
        firmware 1.00 and earlier.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    604 => {
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    633 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    721 => { #PH
        Name => 'AFFineTuneAdj',
        Format => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 3,
        # thanks to Neil Nappe for the samples to decode this!...
        # (have seen various unknown values here when flash is enabled, but
        # these are yet to be decoded: 0x2e,0x619,0xd0d,0x103a,0x2029 - PH)
        PrintConv => {
            0x403e => '+20',
            0x303e => '+19',
            0x203e => '+18',
            0x103e => '+17',
            0x003e => '+16',
            0xe03d => '+15',
            0xc03d => '+14',
            0xa03d => '+13',
            0x803d => '+12',
            0x603d => '+11',
            0x403d => '+10',
            0x203d => '+9',
            0x003d => '+8',
            0xc03c => '+7',
            0x803c => '+6',
            0x403c => '+5',
            0x003c => '+4',
            0x803b => '+3',
            0x003b => '+2',
            0x003a => '+1',
            0x0000 => '0',
            0x00c6 => '-1',
            0x00c5 => '-2',
            0x80c5 => '-3',
            0x00c4 => '-4',
            0x40c4 => '-5',
            0x80c4 => '-6',
            0xc0c4 => '-7',
            0x00c3 => '-8',
            0x20c3 => '-9',
            0x40c3 => '-10',
            0x60c3 => '-11',
            0x80c3 => '-12',
            0xa0c3 => '-13',
            0xc0c3 => '-14',
            0xe0c3 => '-15',
            0x00c2 => '-16',
            0x10c2 => '-17',
            0x20c2 => '-18',
            0x30c2 => '-19',
            0x40c2 => '-20',
        },
    },
    790 => {
        Name => 'CustomSettingsD300',
        Format => 'undef[24]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 813
);

# shot information for the D300 firmware 1.10 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD300b = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    DATAMEMBER => [ 4 ],
    IS_SUBDIR => [ 802 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D300 with
        firmware 1.10.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => { #PH
        Name => 'FirmwareVersion',
        DataMember => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$$self{FirmwareVersion} = $val',
    },
    613 => {
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    644 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    732 => [{
        Name => 'AFFineTuneAdj',
        Condition => '$$self{FirmwareVersion} eq "1.10B"',
        Notes => 'firmware version 1.10B',
        Format => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 3,
        # thanks to Michael Tapes for the samples to decode this!...
        PrintConv => {
            0xe03e => '+20',
            0xc83e => '+19',
            0xb03e => '+18',
            0x983e => '+17',
            0x803e => '+16',
            0x683e => '+15',
            0x503e => '+14',
            0x383e => '+13',
            0x203e => '+12',
            0x083e => '+11',
            0xe03d => '+10',
            0xb03d => '+9',
            0x803d => '+8',
            0x503d => '+7',
            0x203d => '+6',
            0xe03c => '+5',
            0x803c => '+4',
            0x203c => '+3',
            0x803b => '+2',
            0x803a => '+1',
            0x0000 => '0',
            0x80c6 => '-1',
            0x80c5 => '-2',
            0x20c4 => '-3',
            0x80c4 => '-4',
            0xe0c4 => '-5',
            0x20c3 => '-6',
            0x50c3 => '-7',
            0x80c3 => '-8',
            0xb0c3 => '-9',
            0xe0c3 => '-10',
            0x08c2 => '-11',
            0x20c2 => '-12',
            0x38c2 => '-13',
            0x50c2 => '-14',
            0x68c2 => '-15',
            0x80c2 => '-16',
            0x98c2 => '-17',
            0xb0c2 => '-18',
            0xc8c2 => '-19',
            0xe0c2 => '-20',
        },
    },{
        Name => 'AFFineTuneAdj',
        Notes => 'other versions',
        Format => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 3,
        # thanks to Stuart Solomon for the samples to decode this!...
        PrintConv => {
            0x903e => '+20',
            0x7c3e => '+19',
            0x683e => '+18',
            0x543e => '+17',
            0x403e => '+16',
            0x2c3e => '+15',
            0x183e => '+14',
            0x043e => '+13',
            0xe03d => '+12',
            0xb83d => '+11',
            0x903d => '+10',
            0x683d => '+9',
            0x403d => '+8',
            0x183d => '+7',
            0xe03c => '+6',
            0x903c => '+5',
            0x403c => '+4',
            0xe03b => '+3',
            0x403b => '+2',
            0x403a => '+1',
            0x0000 => '0',
            0x40c6 => '-1',
            0x40c5 => '-2',
            0xe0c5 => '-3',
            0x40c4 => '-4',
            0x90c4 => '-5',
            0xe0c4 => '-6',
            0x18c3 => '-7',
            0x40c3 => '-8',
            0x68c3 => '-9',
            0x90c3 => '-10',
            0xb8c3 => '-11',
            0xe0c3 => '-12',
            0x04c2 => '-13',
            0x18c2 => '-14',
            0x2cc2 => '-15',
            0x40c2 => '-16',
            0x54c2 => '-17',
            0x68c2 => '-18',
            0x7cc2 => '-19',
            0x90c2 => '-20',
        },
    }],
    802 => {
        Name => 'CustomSettingsD300',
        Format => 'undef[24]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 825
);

# shot information for the D300S firmware 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD300S = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 804 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D300S with
        firmware 1.00.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    613 => {
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    646 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    804 => { #(NC)
        Name => 'CustomSettingsD300S',
        Format => 'undef[24]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD3',
        },
    },
    # note: DecryptLen currently set to 827
);

# shot information for the D700 firmware 1.02f (encrypted) - ref 29
%Image::ExifTool::Nikon::ShotInfoD700 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 804 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D700 with
        firmware 1.02f.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    613 => { # 0x265
       Name => 'ISO2',
       ValueConv => '100*exp(($val/12-5)*log(2))',
       ValueConvInv => '(log($val/100)/log(2)+5)*12',
       PrintConv => 'int($val + 0.5)',
       PrintConvInv => '$val',
    },
    0x287 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    804 => { # 0x324 (NC)
        Name => 'CustomSettingsD700',
        Format => 'undef[48]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD700',
        },
    },
    # note: DecryptLen currently set to 852
);

# shot information for the D5000 firmware 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD5000 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x378 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D5000 with
        firmware 1.00.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x2b5 => { # (also found at 0x2c0)
        Name => 'ISO2',
        ValueConv => '100*exp(($val/12-5)*log(2))',
        ValueConvInv => '(log($val/100)/log(2)+5)*12',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x2d6 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    0x378 => {
        Name => 'CustomSettingsD5000',
        Format => 'undef[34]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD5000',
        },
    },
    # note: DecryptLen currently set to 0x39a
);

# shot information for the D5100 firmware 1.00f (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD5100 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x407 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x321 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    0x407 => {
        Name => 'CustomSettingsD5100',
        Format => 'undef[34]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD5100',
        },
    },
    # note: DecryptLen currently set to 0x430
);

# shot information for the D5200 firmware 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD5200 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0xcd5 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    # 0x101 - 2=VR Off, 3=VR On
    # 0x13d - 0=VR On, 1=VR Off
    0xbd8 => {
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    # 0xcd2 - 12=VR Off, 15=VR On
    0xcd5 => {
        Name => 'CustomSettingsD5200',
        Format => 'undef[34]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD5200',
        },
    },
    # note: DecryptLen currently set to 0xd00
);

# shot information for the D7000 firmware 1.01d (encrypted) - ref 29
%Image::ExifTool::Nikon::ShotInfoD7000 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 1028 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D7000 with
        firmware 1.01b.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    #613 => {
    #    Name => 'ISO2',
    #    ValueConv => '100*exp(($val/12-5)*log(2))',
    #    ValueConvInv => '(log($val/100)/log(2)+5)*12',
    #    PrintConv => 'int($val + 0.5)',
    #    PrintConvInv => '$val',
    #},
    0x320 => { # 800
        Name => 'ShutterCount',
        Format => 'int32u',
        Priority => 0,
    },
    0x404 => { # 1028 (NC)
        Name => 'CustomSettingsD7000',
        Format => 'undef[48]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD7000',
        },
    },
);

# shot information for the D800 firmware 1.01a (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD800 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x6ec ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in images from the D800.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x4c0 => {
        Name => 'RepeatingFlashOutputExternal',
        ValueConv => '2 ** (-$val/6)',
        ValueConvInv => '$val > 0 ? -6*log($val)/log(2) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x4c2 => {
        Name => 'RepeatingFlashRateExternal',
        DelValue => 0,
        RawConv => '$val || undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    0x4c3 => {
        Name => 'RepeatingFlashCountExternal',
        DelValue => 0,
        RawConv => '$val || undef',
    },
    0x4d2 => {
        Name => 'FlashExposureComp2',
        Notes => 'includes the effect of flash bracketing',
        Format => 'int8s',
        ValueConv => '-$val/6',
        ValueConvInv => '-6 * $val',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    # 0x4d4 - FEC again, doesn't include bracketing this time (internal?)
# (not fully decoded, and duplicated in custom settings)
#    0x4d9 => {
#        Name => 'FlashControlBuilt-in',
#        PrintConv => {
#            1 => 'TTL',
#            6 => 'Manual',
#            7 => 'Repeating Flash',
#        },
#    },
    0x4da => {
        Name => 'RepeatingFlashRateBuilt-in',
        DelValue => 0,
        RawConv => '$val || undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    0x4db => {
        Name => 'RepeatingFlashCountBuilt-in',
        DelValue => 0,
        RawConv => '$val || undef',
    },
#    1294.1 => { # (0x4dc)
#        Name => 'FlashModeBuilt-in',
#        Mask => 0x0f,
#        PrintConv => {
#            0 => 'Front-curtain Sync',
#            1 => 'Red-eye Reduction',
#            2 => 'Redy-eye Reduction with Slow Sync',
#            3 => 'Slow Sync',
#            4 => 'Rear-curtain Sync',
#            5 => 'Rear-curtain Sync 2', # got this in P exposure mode
#        },
#    },
#    1294.2 => { # (0x4dc)
#        Name => 'ExposureMode2',
#        Mask => 0xf0,
#        PrintConv => {
#            0 => 'Program',
#            1 => 'Aperture Priority',
#            3 => 'Manual',
#        },
#    },
    # 0x511 - related to FlashSyncSpeed
    0x51c => 'SequenceNumber',
    # 0x4ba+0x63 - interesting
    # 0x4ba+0x68 - general downward trend
    # 0x4ba+0x7b - FlashControlBuilt-in: 8=TTL, 72=Manual
# (not reliable)
#    1346.1 => { # (0x542)
#        Name => 'RepeatingFlashOutputBuilt-in',
#        DelValue => 112,
#        Mask => 0xfc,
#        RawConv => '$val == 0x1c ? undef : 2 ** ($val/3-7)',
#        ValueConvInv => '$val > 0 ? (log($val)/log(2)+7)*3 : 0',
#        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
#        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
#    },
    0x5fb => {
        Name => 'ShutterCount',
        Format => 'int32u',
    },
    0x6ec => {
        Name => 'CustomSettingsD800',
        Format => 'undef[48]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD800',
        },
    },
    # note: DecryptLen currently set to 0x720
);

# shot information for the D5 firmware 1.10a and D500 firmware 1.01 (encrypted) - ref 28
%Image::ExifTool::Nikon::ShotInfoD500 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    DATAMEMBER => [ 0x04, 0x10, 0x14, 0x2c, 0x50, 0x58, 0xa0, 0xb0,
                    0x07b0, 0x086c, 0x0e7c, 0x0eea, 0x2c23 ],
    IS_SUBDIR => [ 0x0eeb ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in images from the D5 and D500.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        DataMember => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$$self{FirmwareVersion} = $val',
    },
    0x10 => {
        Name => 'RotationInfoOffset',
        DataMember => 'RotationInfoOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{RotationInfoOffset} = $val || 0x10000000; $val', # (ignore if 0)
    },
    0x14 => {
        Name => 'JPGInfoOffset',
        DataMember => 'JPGInfoOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{JPGInfoOffset} = $val || 0x10000000; $val', # (ignore if 0)
    },
    0x2c => {
        Name => 'BracketingInfoOffset',
        DataMember => 'BracketingInfoOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{BracketingInfoOffset} = $val || 0x10000000; $val', # (ignore if 0)
    },
    0x50 => {
        Name => 'ShootingMenuOffset',
        DataMember => 'ShootingMenuOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{ShootingMenuOffset} = $val || 0x10000000; $val', # (ignore if 0)
    },
    0x58 => {
        Name => 'CustomSettingsOffset',
        DataMember => 'CustomSettingsOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{CustomSettingsOffset} = $val || 0x10000000; $val', # (ignore if 0)
    },
    0xa0 => {
        Name => 'OrientationOffset',
        DataMember => 'OrientationOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{OrientationOffset} = $val || 0x10000000; $val', # (ignore if 0)
    },
#
# Tag ID's below are the offsets for a D500 JPEG image, but these offsets change
# for various image types according to the offset table above
#
### 0xb0 - RotationInfo start
    0xb0 => {
        Name => 'Hook1',
        Hidden => 1,
        RawConv => 'undef',
        # account for variable location of Rotation data
        Hook => '$varSize = $$self{RotationInfoOffset} - 0xb0',
    },
    0xca => {
        Name => 'Rotation',
        Mask => 0x03,
        PrintConv => {
            0 => 'Horizontal',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 90 CW',
            3 => 'Rotate 180',
        },
    },
    0x05e2 => {
        Name => 'FlickerReductionIndicator',
        Mask => 0x01,
        PrintConv => { 0 => 'On', 1 => 'Off' },
    },
### 0x07b0 - JPEGInfo start
    0x07b0 => {
        Name => 'Hook2',
        Hidden => 1,
        RawConv => 'undef',
        # account for variable location of Shooting Menu data
        Hook => '$varSize = $$self{JPGInfoOffset} - 0x07b0',
    },
    0x07d4 => {
        Name => 'JPGCompression',
        Mask => 0x01,
        PrintConv => {
            0 => 'Size Priority',
            1 => 'Optimal Quality',
        },
    },
### 0x0830 - ? start
### 0x086c - BracketingInfo start
    0x086c => {
        Name => 'Hook3',
        Hidden => 1,
        RawConv => 'undef',
        # account for variable location of Shooting Menu data
        Hook => '$varSize = $$self{BracketingInfoOffset} - 0x086c',
    },
    0x087b => {
        Name => 'AEBracketingSteps',
        Condition => '$$self{FILE_TYPE} ne "TIFF"', # (covers NEF and TIFF)
        Mask => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => 'AE Bracketing Disabled',
            0x20 => 'AE Bracketing Disabled',
            0x30 => 'AE Bracketing Disabled',
            0x40 => 'AE Bracketing Disabled',
            0x50 => 'AE Bracketing Disabled',
            0x81 => '+3F0.3',
            0x82 => '-3F0.3',
            0x83 => '+2F0.3',
            0x84 => '-2F0.3',
            0x85 => '3F0.3',
            0x86 => '5F0.3',
            0x87 => '7F0.3',
            0x88 => '9F0.3',
            0x91 => '+3F0.5',
            0x92 => '-3F0.5',
            0x93 => '+2F0.5',
            0x94 => '-2F0.5',
            0x95 => '3F0.5',
            0x96 => '5F0.5',
            0x97 => '7F0.5',
            0x98 => '9F0.5',
            0xa1 => '+3F0.7',
            0xa2 => '-3F0.7',
            0xa3 => '+2F0.7',
            0xa4 => '-2F0.7',
            0xa5 => '3F0.7',
            0xa6 => '5F0.7',
            0xa7 => '7F0.7',
            0xa8 => '9F0.7',
            0xb1 => '+3F1',
            0xb2 => '-3F1',
            0xb3 => '+2F1',
            0xb4 => '-2F1',
            0xb5 => '3F1',
            0xb6 => '5F1',
            0xb7 => '7F1',
            0xb8 => '9F1',
            0xc1 => '+3F2',
            0xc2 => '-3F2',
            0xc3 => '+2F2',
            0xc4 => '-2F2',
            0xc5 => '3F2',
            0xc6 => '5F2',
            0xd1 => '+3F3',
            0xd2 => '-3F3',
            0xd3 => '+2F3',
            0xd4 => '-2F3',
            0xd5 => '3F3',
            0xd6 => '5F3',
        },
    },
    0x087c => {
        Name => 'WBBracketingSteps',
        Condition => '$$self{FILE_TYPE} ne "TIFF"', # (covers NEF and TIFF)
        Mask => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => 'WB Bracketing Disabled',
            0x01 => 'b3F 1',
            0x02 => 'A3F 1',
            0x03 => 'b2F 1',
            0x04 => 'A2F 1',
            0x05 => '3F 1',
            0x06 => '5F 1',
            0x07 => '7F 1',
            0x08 => '9F 1',
            0x10 => '0F 2',
            0x11 => 'b3F 2',
            0x12 => 'A3F 2',
            0x13 => 'b2F 2',
            0x14 => 'A2F 2',
            0x15 => '3F 2',
            0x16 => '5F 2',
            0x17 => '7F 2',
            0x18 => '9F 2',
            0x20 => '0F 3',
            0x21 => 'b3F 3',
            0x22 => 'A3F 3',
            0x23 => 'b2F 3',
            0x24 => 'A2F 3',
            0x25 => '3F 3',
            0x26 => '5F 3',
            0x27 => '7F 3',
            0x28 => '9F 3',
            0x22 => 'A3F 3',
            0x23 => 'b2F 3',
            0x24 => 'A2F 3',
            0x25 => '3F 3',
            0x26 => '5F 3',
            0x27 => '7F 3',
            0x28 => '9F 3',
        },
    },
    0x0883 => {
        Name => 'ADLBracketingStep',
        Mask => 0xf0,
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Normal',
            3 => 'High',
            4 => 'Extra High',
            8 => 'Auto',
        },
    },
    0x0884 => {
        Name => 'ADLBracketingType',
        Mask => 0x0f,
        PrintConv => {
            0 => 'Off',
            1 => '2 Shots',
            2 => '3 Shots',
            3 => '4 Shots',
            4 => '5 Shots',
        },
    },
### 0x0887 - ? start
### 0x089f - ? start
### 0x0929 - ? start
### 0x09c9 - ? start
### 0x0ac5 - ? start
### 0x0bc1 - ? start
### 0x0cbd - ? start
### 0x0d98 - ? start
### 0x0e7d - ShootingMenuOffset start
    0x0e7c => {
        Name => 'Hook4',
        Hidden => 1,
        RawConv => 'undef',
        # account for variable location of Shooting Menu data
        Hook => '$varSize = $$self{ShootingMenuOffset} - 0x0e7d',
    },
    0x0e7d => {
        Name => 'PhotoShootingMenuBank',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    0x0e7f => {
        Name => 'PrimarySlot',
        Condition => '$$self{Model} =~ /\bD500\b/',
        Notes => 'D500 only',
        Mask => 0x80,
        PrintConv => {
            0 => 'XQD Card',
            1 => 'SD Card',
        },
    },
    0x0e81 => {
        Name => 'ISOAutoShutterTime',
        Mask => 0x3f,
        PrintConv => {
            0 => '1/4000 s',
            1 => '1/3200 s',
            2 => '1/2500 s',
            3 => '1/2000 s',
            4 => '1/1600 s',
            5 => '1/1250 s',
            6 => '1/1000 s',
            7 => '1/800 s',
            8 => '1/640 s',
            9 => '1/500 s',
            10 => '1/400 s',
            11 => '1/320 s',
            12 => '1/250 s',
            13 => '1/200 s',
            14 => '1/160 s',
            15 => '1/125 s',
            16 => '1/100 s',
            17 => '1/80 s',
            18 => '1/60 s',
            19 => '1/50 s',
            20 => '1/40 s',
            21 => '1/30 s',
            22 => '1/15 s',
            23 => '1/8 s',
            24 => '1/4 s',
            25 => '1/2 s',
            26 => '1 s',
            27 => '2 s',
            28 => '4 s',
            29 => '8 s',
            30 => '15 s',
            31 => '30 s',
            32 => 'Auto (Slowest)',
            33 => 'Auto (Slower)',
            34 => 'Auto',
            35 => 'Auto (Faster)',
            36 => 'Auto (Fastest)',
        },
    },
    0x0e82 => {
        Name => 'ISOAutoHiLimit',
        Mask => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x24 => 'ISO 200',
            0x26 => 'ISO 250',
            0x27 => 'ISO 280',
            0x28 => 'ISO 320',
            0x2a => 'ISO 400',
            0x2c => 'ISO 500',
            0x2d => 'ISO 560',
            0x2e => 'ISO 640',
            0x30 => 'ISO 800',
            0x32 => 'ISO 1000',
            0x33 => 'ISO 1100',
            0x34 => 'ISO 1250',
            0x36 => 'ISO 1600',
            0x38 => 'ISO 2000',
            0x39 => 'ISO 2200',
            0x3a => 'ISO 2500',
            0x3c => 'ISO 3200',
            0x3e => 'ISO 4000',
            0x3f => 'ISO 4500',
            0x40 => 'ISO 5000',
            0x42 => 'ISO 6400',
            0x44 => 'ISO 8000',
            0x45 => 'ISO 9000',
            0x46 => 'ISO 10000',
            0x48 => 'ISO 12800',
            0x4a => 'ISO 16000',
            0x4b => 'ISO 18000',
            0x4c => 'ISO 20000',
            0x4e => 'ISO 25600',
            0x50 => 'ISO 32000',
            0x51 => 'ISO 36000',
            0x52 => 'ISO 40000',
            0x54 => 'ISO 51200',
            0x56 => 'ISO Hi 0.3',
            0x57 => 'ISO Hi 0.5',
            0x58 => 'ISO Hi 0.7',
            0x5a => 'ISO Hi 1.0',
            0x60 => 'ISO Hi 2.0',
            0x66 => 'ISO Hi 3.0',
            0x6c => 'ISO Hi 4.0',
            0x72 => 'ISO Hi 5.0',
        },
    },
    0x0e84 => {
        Name => 'FlickerReduction',
        Mask => 0x20,
        PrintConv => {
            0 => 'Enable',
            1 => 'Disable',
        },
    },
    3716.1 => { # (0x0e84)
        Name => 'PhotoShootingMenuBankImageArea',
        Mask => 0x07,
        PrintConv => {
            0 => 'FX (36x24)',
            1 => 'DX (24x16)',
            2 => '5:4 (30x24)',
            3 => '1.2x (30x20)',
            4 => '1.3x (18x12)',
        },
    },
### 0x0ec4 - ? start
### 0x0eeb - CustomSettings start
    0x0eea => {
        Name => 'Hook5',
        Hidden => 1,
        RawConv => 'undef',
        # account for variable location of CustomSettings data
        Hook => '$varSize = $$self{CustomSettingsOffset} - 0x0eeb',
    },
    0x0eeb => [{
        Name => 'CustomSettingsD5',
        Condition => '$$self{Model} =~ /\bD5\b/',
        Format => 'undef[90]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD5',
        },
    },{
        Name => 'CustomSettingsD500',
        Format => 'undef[90]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD500',
        },
    }],
#    0x0f68 => {  #this decode works, but involves more bits than should be necessary
#        Name => 'ShutterTrigger',
#        Mask => 0xff,
#        PrintConv => {
#           0 => 'Timer',
#           15 => 'Cable Release/Remote',
#           195 => 'Shutter Button',
#       },
#   },
### 0x2c24 - OrientationInfo start (D5 firmware 1.10b)
    0x2c23 => {
        Name => 'Hook6',
        Hidden => 1,
        RawConv => 'undef',
        # account for variable location of OrientationInfo data
        Hook => '$varSize = $$self{OrientationOffset} - 0x2c24',
    },
    0x2c24 => {
        Name => 'RollAngle',
        Format => 'fixed32u',
        Notes => 'converted to degrees of clockwise camera roll',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x2c28 => {
        Name => 'PitchAngle',
        Format => 'fixed32u',
        Notes => 'converted to degrees of upward camera tilt',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x2c2c => {
        Name => 'YawAngle',
        Format => 'fixed32u',
        Notes => 'the camera yaw angle when shooting in portrait orientation',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    # note: DecryptLen currently set to OrientationOffset + 12

    # (not sure about how this moves around)
    #0x2cb2 => {
    #    Name => 'ExtendedPhotoShootingBanks',
    #    Mask => 0x01,
    #    PrintConv => {
    #        0 => 'On',
    #        1 => 'Off',
    #    },
    #},
    # don't decode this because it is duplicate information and moves around with firmware versions
    #0x2ea2 => {
    #    Name => 'Rotation',
    #    Condition => '$$self{Model} =~ /\bD500\b/ and $$self{FirmwareVersion} =~ /^1.1/',
    #    Notes => 'D500 firmware 1.1x',
    #    Mask => 0x30,
    #    PrintConv => {
    #        0 => 'Horizontal',
    #        1 => 'Rotate 270 CW',
    #        2 => 'Rotate 90 CW',
    #        3 => 'Rotate 180',
    #    },
    #},
);
# shot information for the D610 firmware 1.00 (encrypted) - ref PH
%Image::ExifTool::Nikon::ShotInfoD610 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x07cf ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in images from the D610.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x07cf => {
        Name => 'CustomSettingsD610',
        Format => 'undef[48]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD610',
        },
    },
    # note: DecryptLen currently set to 0x7ff
);

# shot information for the D810 firmware 1.00(PH)/1.01 (encrypted) - ref 28
%Image::ExifTool::Nikon::ShotInfoD810 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    DATAMEMBER => [ 0x04, 0x24, 0x40, 0x84, 0x01d0, 0x175e, 0x185d ],
    IS_SUBDIR => [ 0x18ab ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in images from the D810.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        DataMember => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$$self{FirmwareVersion} = $val',
    },
    # 0x0c - number of entries in offset table (= 0x21)
    # 0x10 - int32u[val 0x0c]: offset table
    0x24 => {
        Name => 'BracketingOffset',
        DataMember => 'BracketingOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{BracketingOffset} = $val',
    },
    0x40 => {
        Name => 'CustomSettingsOffset', # (relative offset from start of ShotInfo data)
        DataMember => 'CustomSettingsOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{CustomSettingsOffset} = $val',
    },
    0x84 => {
        Name => 'OrientationOffset',
        DataMember => 'OrientationOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{OrientationOffset} = $val',
    },
    0x01d0 => {
        Name => 'SecondarySlotFunction',
        Mask => 0x03,
        PrintConv => {
            0 => 'Overflow',
            2 => 'Backup',
            3 => 'NEF Primary + JPG Secondary',
        },
        Hook => '$varSize = $$self{BracketingOffset} - 0x1747',
    },
    0x1756 => {
        Name => 'AEBracketingSteps',
        Mask => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => 'AE Bracketing Disabled',
            0x20 => 'AE Bracketing Disabled',
            0x30 => 'AE Bracketing Disabled',
            0x40 => 'AE Bracketing Disabled',
            0x50 => 'AE Bracketing Disabled',
            0x81 => '+3F0.3',
            0x82 => '-3F0.3',
            0x83 => '+2F0.3',
            0x84 => '-2F0.3',
            0x85 => '3F0.3',
            0x86 => '5F0.3',
            0x87 => '7F0.3',
            0x88 => '9F0.3',
            0x91 => '+3F0.5',
            0x92 => '-3F0.5',
            0x93 => '+2F0.5',
            0x94 => '-2F0.5',
            0x95 => '3F0.5',
            0x96 => '5F0.5',
            0x97 => '7F0.5',
            0x98 => '9F0.5',
            0xa1 => '+3F0.7',
            0xa2 => '-3F0.7',
            0xa3 => '+2F0.7',
            0xa4 => '-2F0.7',
            0xa5 => '3F0.7',
            0xa6 => '5F0.7',
            0xa7 => '7F0.7',
            0xa8 => '9F0.7',
            0xb1 => '+3F1',
            0xb2 => '-3F1',
            0xb3 => '+2F1',
            0xb4 => '-2F1',
            0xb5 => '3F1',
            0xb6 => '5F1',
            0xb7 => '7F1',
            0xb8 => '9F1',
            0xc1 => '+3F2',
            0xc2 => '-3F2',
            0xc3 => '+2F2',
            0xc4 => '-2F2',
            0xc5 => '3F2',
            0xc6 => '5F2',
            0xd1 => '+3F3',
            0xd2 => '-3F3',
            0xd3 => '+2F3',
            0xd4 => '-2F3',
            0xd5 => '3F3',
            0xd6 => '5F3',
        },
    },
    0x1757 => {
        Name => 'WBBracketingSteps',
        Condition => '$$self{FILE_TYPE} ne "TIFF"', # (covers NEF and TIFF)
        Mask => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => 'WB Bracketing Disabled',
            0x01 => 'b3F 1',
            0x02 => 'A3F 1',
            0x03 => 'b2F 1',
            0x04 => 'A2F 1',
            0x05 => '3F 1',
            0x06 => '5F 1',
            0x07 => '7F 1',
            0x08 => '9F 1',
            0x10 => '0F 2',
            0x11 => 'b3F 2',
            0x12 => 'A3F 2',
            0x13 => 'b2F 2',
            0x14 => 'A2F 2',
            0x15 => '3F 2',
            0x16 => '5F 2',
            0x17 => '7F 2',
            0x18 => '9F 2',
            0x20 => '0F 3',
            0x21 => 'b3F 3',
            0x22 => 'A3F 3',
            0x23 => 'b2F 3',
            0x24 => 'A2F 3',
            0x25 => '3F 3',
            0x26 => '5F 3',
            0x27 => '7F 3',
            0x28 => '9F 3',
            0x22 => 'A3F 3',
            0x23 => 'b2F 3',
            0x24 => 'A2F 3',
            0x25 => '3F 3',
            0x26 => '5F 3',
            0x27 => '7F 3',
            0x28 => '9F 3',
        },
    },
    0x175e => {
        Name => 'D810MeteringMode',
        Mask => 0x03,
        PrintConv => {
            0 => 'Matrix',
            1 => 'Center',
            2 => 'Spot',
            3 => 'Highlight'
        },
        Hook => '$varSize = $$self{CustomSettingsOffset} - 0x18ab',
    },
    0x18ab => { # (actual offset adjusted by Hook above)
        Name => 'CustomSettingsD810',
        Notes => 'actual offset determined by CustomSettingsOffset',
        Format => 'undef[53]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD810',
        },
    },
    0x185c => {
        Name => 'ISOAutoShutterTime',
        Mask => 0x3f,
        PrintConv => {
            0 => '1/4000 s',
            1 => '1/3200 s',
            2 => '1/2500 s',
            3 => '1/2000 s',
            4 => '1/1600 s',
            5 => '1/1250 s',
            6 => '1/1000 s',
            7 => '1/800 s',
            8 => '1/640 s',
            9 => '1/500 s',
            10 => '1/400 s',
            11 => '1/320 s',
            12 => '1/250 s',
            13 => '1/200 s',
            14 => '1/160 s',
            15 => '1/125 s',
            16 => '1/100 s',
            17 => '1/80 s',
            18 => '1/60 s',
            19 => '1/50 s',
            20 => '1/40 s',
            21 => '1/30 s',
            22 => '1/15 s',
            23 => '1/8 s',
            24 => '1/4 s',
            25 => '1/2 s',
            26 => '1 s',
            27 => '2 s',
            28 => '4 s',
            29 => '8 s',
            30 => '15 s',
            31 => '30 s',
            32 => 'Auto (Slowest)',
            33 => 'Auto (Slower)',
            34 => 'Auto',
            35 => 'Auto (Faster)',
            36 => 'Auto (Fastest)',
        },
    },
    0x185d => {
        Name => 'ISOAutoHiLimit',
        Mask => 0xff,
        PrintHex => 1,
        Hook => '$varSize = $$self{OrientationOffset} - 0x36f4',
        PrintConv => {
            0x24 => 'ISO 200',
            0x26 => 'ISO 250',
            0x27 => 'ISO 280',
            0x28 => 'ISO 320',
            0x2a => 'ISO 400',
            0x2c => 'ISO 500',
            0x2d => 'ISO 560',
            0x2e => 'ISO 640',
            0x30 => 'ISO 800',
            0x32 => 'ISO 1000',
            0x33 => 'ISO 1100',
            0x34 => 'ISO 1250',
            0x36 => 'ISO 1600',
            0x38 => 'ISO 2000',
            0x39 => 'ISO 2200',
            0x3a => 'ISO 2500',
            0x3c => 'ISO 3200',
            0x3e => 'ISO 4000',
            0x3f => 'ISO 4500',
            0x40 => 'ISO 5000',
            0x42 => 'ISO 6400',
            0x44 => 'ISO 8000',
            0x45 => 'ISO 9000',
            0x46 => 'ISO 10000',
            0x48 => 'ISO 12800',
            0x4a => 'ISO 16000',
            0x4b => 'ISO 18000',
            0x4c => 'ISO 20000',
            0x4e => 'ISO 25600',
            0x50 => 'ISO 32000',
            0x51 => 'ISO 36000',
            0x52 => 'ISO 40000',
            0x54 => 'ISO 51200',
            0x56 => 'ISO Hi 0.3',
            0x57 => 'ISO Hi 0.5',
            0x58 => 'ISO Hi 0.7',
            0x5a => 'ISO Hi 1.0',
            0x60 => 'ISO Hi 2.0',
            0x66 => 'ISO Hi 3.0',
            0x6c => 'ISO Hi 4.0',
            0x72 => 'ISO Hi 5.0',
        },
    },
    0x36f4 => {
        Name => 'RollAngle',
        Format => 'fixed32u',
        Notes => 'converted to degrees of clockwise camera roll',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x36f8 => {
        Name => 'PitchAngle',
        Format => 'fixed32u',
        Notes => 'converted to degrees of upward camera tilt',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x36fc => {
        Name => 'YawAngle',
        Format => 'fixed32u',
        Notes => 'the camera yaw angle when shooting in portrait orientation',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    # note: DecryptLen currently set to OrientationOffset + 12

    # (moves around too much and doesn't fit cleanly in the offset table)
    #0x38be => {
    #    Name => 'Rotation',
    #    Condition => '$$self{FirmwareVersion} =~ /^1.0/',
    #    Mask => 0x30,
    #    PrintConv => {
    #        0 => 'Horizontal',
    #        1 => 'Rotate 270 CW',
    #        2 => 'Rotate 90 CW',
    #        3 => 'Rotate 180',
    #    },
    #},
);

# shot information for the D850 firmware 1.00b (encrypted) - ref 28
%Image::ExifTool::Nikon::ShotInfoD850 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    DATAMEMBER => [ 0x04, 0x58, 0x0fbf ],
    IS_SUBDIR => [ 0x1038 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'These tags are extracted from encrypted data in images from the D850.',
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        DataMember => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$$self{FirmwareVersion} = $val',
    },
    0x58 => {
        Name => 'CustomSettingsOffset', # (relative offset from start of ShotInfo data)
        DataMember => 'CustomSettingsOffset',
        Format => 'int32u',
        Writable => 0,
        RawConv => '$$self{CustomSettingsOffset} = $val',
    },
    0x0791 => {
        Name => 'PhotoShootingMenuBankImageArea',
        Mask => 0x07,
        PrintConv => {
            0 => 'FX (36x24)',
            1 => 'DX (24x16)',
            2 => '5:4 (30x24)',
            3 => '1.2x (30x20)',
            4 => '1:1 (24x24)',
        },
    },
    0x0fbd => {
        Name => 'PhotoShootingMenuBank',
        Condition => '$$self{FILE_TYPE} eq "JPEG"',
        Notes => 'valid for JPEG images only',
        Mask => 0x03,
        PrintConv => {
            0 => 'A',
            1 => 'B',
            2 => 'C',
            3 => 'D',
        },
    },
    0x0fbf => {
        Name => 'PrimarySlot',
        Mask => 0x80,
        PrintConv => {
            0 => 'XQD Card',
            1 => 'SD Card',
        },
        Hook => '$varSize = $$self{CustomSettingsOffset} - 0x1038',
    },
    0x1038 => {
        Name => 'CustomSettingsD850',
        Format => 'undef[90]',
        SubDirectory => {
            TagTable => 'Image::ExifTool::NikonCustom::SettingsD850',
        },
    },
    # note: DecryptLen currently set to 94 bytes after CustomSettingsOffset
);
# shot information for the D4 firmware 1.00g (ref PH)
%Image::ExifTool::Nikon::ShotInfoD4 = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    IS_SUBDIR => [ 0x0751 ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D4.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
    },
    0x0751 => { #PH (NC)
        Name => 'CustomSettingsD4',
        # (seems to work for 1.00g and 1.02b)
        Format => 'undef[56]',
        SubDirectory => { TagTable => 'Image::ExifTool::NikonCustom::SettingsD4' },
    },
    # note: DecryptLen currently set to 0x789
);

# shot information for the D4S firmware 1.01a (ref 28, encrypted)
%Image::ExifTool::Nikon::ShotInfoD4S = (
    PROCESS_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    WRITE_PROC => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    VARS => { ID_LABEL => 'Index' },
    DATAMEMBER => [ 4 ],
    IS_SUBDIR => [ 0x189d, 0x193d ],
    WRITABLE => 1,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are extracted from encrypted data in images from the D4S.
    },
    0x00 => {
        Name => 'ShotInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    0x04 => {
        Name => 'FirmwareVersion',
        DataMember => 'FirmwareVersion',
        Format => 'string[5]',
        Writable => 0,
        RawConv => '$$self{FirmwareVersion} = $val',
    },
    0x01d0 => {
        Name => 'SecondarySlotFunction',
        Mask => 0x03,
        PrintConv => {
            0 => 'Overflow',
            2 => 'Backup',
            3 => 'NEF Primary + JPG Secondary',
        },
    },
    0x174c => {
        Name => 'AEBracketingSteps',
        Mask => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => 'AE Bracketing Disabled',
            0x20 => 'AE Bracketing Disabled',
            0x30 => 'AE Bracketing Disabled',
            0x40 => 'AE Bracketing Disabled',
            0x50 => 'AE Bracketing Disabled',
            0x81 => '+3F0.3',
            0x82 => '-3F0.3',
            0x83 => '+2F0.3',
            0x84 => '-2F0.3',
            0x85 => '3F0.3',
            0x86 => '5F0.3',
            0x87 => '7F0.3',
            0x88 => '9F0.3',
            0x91 => '+3F0.5',
            0x92 => '-3F0.5',
            0x93 => '+2F0.5',
            0x94 => '-2F0.5',
            0x95 => '3F0.5',
            0x96 => '5F0.5',
            0x97 => '7F0.5',
            0x98 => '9F0.5',
            0xa1 => '+3F0.7',
            0xa2 => '-3F0.7',
            0xa3 => '+2F0.7',
            0xa4 => '-2F0.7',
            0xa5 => '3F0.7',
            0xa6 => '5F0.7',
            0xa7 => '7F0.7',
            0xa8 => '9F0.7',
            0xb1 => '+3F1',
            0xb2 => '-3F1',
            0xb3 => '+2F1',
            0xb4 => '-2F1',
            0xb5 => '3F1',
            0xb6 => '5F1',
            0xb7 => '7F1',
            0xb8 => '9F1',
            0xc1 => '+3F2',
            0xc2 => '-3F2',
            0xc3 => '+2F2',
            0xc4 => '-2F2',
            0xc5 => '3F2',
            0xc6 => '5F2',
            0xd1 => '+3F3',
            0xd2 => '-3F3',
            0xd3 => '+2F3',
            0xd4 => '-2F3',
            0xd5 => '3F3',
            0xd6 => '5F3',
        },
    },
    0x174d => {
        Name => 'WBBracketingSteps',
        Condition => '$$self{FILE_TYPE} ne "TIFF"', # (covers NEF and TIFF)
        Mask => 0xff,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x00 => 'WB Bracketing Disabled',
            0x01 => 'b3F 1',
            0x02 => 'A3F 1',
            0x03 => 'b2F 1',
            0x04 => 'A2F 1',
            0x05 => '3F 1',
            0x06 => '5F 1',
            0x07 => '7F 1',
            0x08 => '9F 1',
            0x10 => '0F 2',
            0x11 => 'b3F 2',
            0x12 => 'A3F 2',
            0x13 => 'b2F 2',
            0x14 => 'A2F 2',
            0x15 => '3F 2',
            0x16 => '5F 2',
            0x17 => '7F 2',
            0x18 => '9F 2',
            0x20 => '0F 3',
            0x21 => 'b3F 3',
            0x22 => 'A3F 3',
            0x23 => 'b2F 3',
            0x24 => 'A2F 3',
            0x25 => '3F 3',
            0x26 => '5F 3',
            0x27 => '7F 3',
            0x28 => '9F 3',
            0x22 => 'A3F 3',
            0x23 => 'b2F 3',
            0x24 => 'A2F 3',
            0x25 => '3F 3',
            0x26 => '5F 3',
            0x27 => '7F 3',
            0x28 => '9F 3',
        },
    },
    0x184d => {
        Name => 'ReleaseMode',
        Mask => 0xff,
        PrintConv => {
            0 => 'Single Frame',
            1 => 'Continuous High Speed',
            3 => 'Continuous Low Speed',
            4 => 'Timer',
            32 => 'Mirror-Up',
            64 => 'Quiet',
        },
    },
    0x189d => { #PH (NC)
        Name => 'CustomSettingsD4S',
        Condition => '$$self{FirmwareVersion} =~ /^1.00/',
        Notes => 'firmware version 1.00',
        Format => 'undef[56]',
        SubDirectory => { TagTable => 'Image::ExifTool::NikonCustom::SettingsD4' },
    },
    0x18c2 => { # CSf1-c (no idea why it is so far away from the rest of the settings)
        Name => 'MultiSelectorLiveViewMode',
        Groups => { 1 => 'NikonCustom' },
        Condition => '$$self{FirmwareVersion} !~ /^1.00/',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Reset',
            1 => 'Zoom',
            3 => 'None',
        },
    },
    0x18ea => {
        Name => 'ISOAutoShutterTime',
        Mask => 0x3f,
        PrintConv => {
            0 => '1/4000 s',
            1 => '1/3200 s',
            2 => '1/2500 s',
            3 => '1/2000 s',
            4 => '1/1600 s',
            5 => '1/1250 s',
            6 => '1/1000 s',
            7 => '1/800 s',
            8 => '1/640 s',
            9 => '1/500 s',
            10 => '1/400 s',
            11 => '1/320 s',
            12 => '1/250 s',
            13 => '1/200 s',
            14 => '1/160 s',
            15 => '1/125 s',
            16 => '1/100 s',
            17 => '1/80 s',
            18 => '1/60 s',
            19 => '1/50 s',
            20 => '1/40 s',
            21 => '1/30 s',
            22 => '1/15 s',
            23 => '1/8 s',
            24 => '1/4 s',
            25 => '1/2 s',
            26 => '1 s',
            27 => '2 s',
            28 => '4 s',
            29 => '8 s',
            30 => '15 s',
            31 => '30 s',
            32 => 'Auto (Slowest)',
            33 => 'Auto (Slower)',
            34 => 'Auto',
            35 => 'Auto (Faster)',
            36 => 'Auto (Fastest)',
        },
    },
    0x18eb => {
        Name => 'ISOAutoHiLimit',
        Mask => 0xff,
        PrintHex => 1,
        PrintConv => {
            0x24 => 'ISO 200',
            0x26 => 'ISO 250',
            0x27 => 'ISO 280',
            0x28 => 'ISO 320',
            0x2a => 'ISO 400',
            0x2c => 'ISO 500',
            0x2d => 'ISO 560',
            0x2e => 'ISO 640',
            0x30 => 'ISO 800',
            0x32 => 'ISO 1000',
            0x33 => 'ISO 1100',
            0x34 => 'ISO 1250',
            0x36 => 'ISO 1600',
            0x38 => 'ISO 2000',
            0x39 => 'ISO 2200',
            0x3a => 'ISO 2500',
            0x3c => 'ISO 3200',
            0x3e => 'ISO 4000',
            0x3f => 'ISO 4500',
            0x40 => 'ISO 5000',
            0x42 => 'ISO 6400',
            0x44 => 'ISO 8000',
            0x45 => 'ISO 9000',
            0x46 => 'ISO 10000',
            0x48 => 'ISO 12800',
            0x4a => 'ISO 16000',
            0x4b => 'ISO 18000',
            0x4c => 'ISO 20000',
            0x4e => 'ISO 25600',
            0x50 => 'ISO 32000',
            0x51 => 'ISO 36000',
            0x52 => 'ISO 40000',
            0x54 => 'ISO 51200',
            0x56 => 'ISO Hi 0.3',
            0x57 => 'ISO Hi 0.5',
            0x58 => 'ISO Hi 0.7',
            0x5a => 'ISO Hi 1.0',
            0x60 => 'ISO Hi 2.0',
            0x66 => 'ISO Hi 3.0',
            0x6c => 'ISO Hi 4.0',
            0x72 => 'ISO Hi 5.0',
        },
    },
    0x193d => {
        Name => 'CustomSettingsD4S',
        Condition => '$$self{FirmwareVersion} !~ /^1.00/',
        Notes => 'firmware version 1.01',
        Format => 'undef[56]',
        SubDirectory => { TagTable => 'Image::ExifTool::NikonCustom::SettingsD4' },
    },
#    0x1978 => {        #this decode works, but involves more bits than should be necessary
#        Name => 'ShutterTrigger',
#        Mask => 0xff,
#        PrintConv => {
#           0 => 'Timer',
#           15 => 'Cable Release/Remote',
#           195 => 'Shutter Button',
#       },
#   },
    0x350b => {
        Name => 'RollAngle',
        Format => 'fixed32u',
        Notes => 'converted to degrees of clockwise camera roll',
        ValueConv => '$val < 180 ? -$val : 360 - $val',
        ValueConvInv => '$val <= 0 ? -$val : 360 - $val',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x350f => {
        Name => 'PitchAngle',
        Format => 'fixed32u',
        Notes => 'converted to degrees of upward camera tilt',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x3513 => {
        Name => 'YawAngle',
        Format => 'fixed32u',
        Notes => 'the camera yaw angle when shooting in portrait orientation',
        ValueConv => '$val <= 180 ? $val : $val - 360',
        ValueConvInv => '$val >= 0 ? $val : $val + 360',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    0x3693 => {
        Name => 'Rotation',
        Mask => 0x30,
        PrintConv => {
            0 => 'Horizontal',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 90 CW',
            3 => 'Rotate 180',
        },
    },
    # note: DecryptLen currently set to 0x3697
);

# Flash information (ref JD)
%Image::ExifTool::Nikon::FlashInfo0100 = (
    %binaryDataAttrs,
    DATAMEMBER => [ 9.2, 15, 16 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are used by the D2H, D2Hs, D2X, D2Xs, D50, D70, D70s, D80 and
        D200.
    },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'FlashInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    4 => { #PH
        Name => 'FlashSource',
        PrintConv => {
            0 => 'None',
            1 => 'External',
            2 => 'Internal',
        },
    },
    # 5 - values: 46,48,50,54,78
    6 => {
        Format => 'int8u[2]',
        Name => 'ExternalFlashFirmware',
        SeparateTable => 'FlashFirmware',
        PrintConv => \%flashFirmware,
    },
    8 => {
        Name => 'ExternalFlashFlags',
        PrintConv => { 0 => '(none)',
            BITMASK => {
                0 => 'Fired', #28
                2 => 'Bounce Flash', #PH
                4 => 'Wide Flash Adapter',
                5 => 'Dome Diffuser', #28
            },
        },
    },
    9.1 => {
        Name => 'FlashCommanderMode',
        Mask => 0x80,
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    9.2 => {
        Name => 'FlashControlMode',
        Mask => 0x7f,
        DataMember => 'FlashControlMode',
        RawConv => '$$self{FlashControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    10 => [
        {
            Name => 'FlashOutput',
            Condition => '$$self{FlashControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashCompensation',
            Format => 'int8s',
            Priority => 0,
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
    ],
    11 => {
        Name => 'FlashFocalLength',
        RawConv => '$val ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    12 => {
        Name => 'RepeatingFlashRate',
        RawConv => '$val ? $val : undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    13 => {
        Name => 'RepeatingFlashCount',
        RawConv => '$val ? $val : undef',
    },
    14 => { #PH
        Name => 'FlashGNDistance',
        SeparateTable => 1,
        PrintConv => \%flashGNDistance,
    },
    15 => {
        Name => 'FlashGroupAControlMode',
        Mask => 0x0f,
        DataMember => 'FlashGroupAControlMode',
        RawConv => '$$self{FlashGroupAControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    16 => {
        Name => 'FlashGroupBControlMode',
        Mask => 0x0f,
        DataMember => 'FlashGroupBControlMode',
        RawConv => '$$self{FlashGroupBControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    17 => [
        {
            Name => 'FlashGroupAOutput',
            Condition => '$$self{FlashGroupAControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupACompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    18 => [
        {
            Name => 'FlashGroupBOutput',
            Condition => '$$self{FlashGroupBControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupBCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
);

# Flash information for D40, D40x, D3 and D300 (ref JD)
%Image::ExifTool::Nikon::FlashInfo0102 = (
    %binaryDataAttrs,
    DATAMEMBER => [ 9.2, 16.1, 17.1, 17.2 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are used by the D3 (firmware 1.x), D40, D40X, D60 and D300
        (firmware 1.00).
    },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'FlashInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    4 => { #PH
        Name => 'FlashSource',
        PrintConv => {
            0 => 'None',
            1 => 'External',
            2 => 'Internal',
        },
    },
    # 5 - values: 46,48,50,54,78
    6 => {
        Format => 'int8u[2]',
        Name => 'ExternalFlashFirmware',
        SeparateTable => 'FlashFirmware',
        PrintConv => \%flashFirmware,
    },
    8 => {
        Name => 'ExternalFlashFlags',
        PrintConv => { BITMASK => {
            0 => 'Fired', #28
            2 => 'Bounce Flash', #PH
            4 => 'Wide Flash Adapter',
            5 => 'Dome Diffuser', #28
        }},
    },
    9.1 => {
        Name => 'FlashCommanderMode',
        Mask => 0x80,
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    9.2 => {
        Name => 'FlashControlMode',
        Mask => 0x7f,
        DataMember => 'FlashControlMode',
        RawConv => '$$self{FlashControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    10 => [
        {
            Name => 'FlashOutput',
            Condition => '$$self{FlashControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashCompensation',
            # this is the compensation from the camera (0x0012) for "Built-in" FlashType, or
            # the compensation from the external unit (0x0017) for "Optional" FlashType - PH
            Format => 'int8s',
            Priority => 0,
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
    ],
    12 => {
        Name => 'FlashFocalLength',
        RawConv => '$val ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    13 => {
        Name => 'RepeatingFlashRate',
        RawConv => '$val ? $val : undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    14 => {
        Name => 'RepeatingFlashCount',
        RawConv => '$val ? $val : undef',
    },
    15 => { #PH
        Name => 'FlashGNDistance',
        SeparateTable => 1,
        PrintConv => \%flashGNDistance,
    },
    16.1 => {
        Name => 'FlashGroupAControlMode',
        Mask => 0x0f,
        Notes => 'note: group A tags may apply to the built-in flash settings for some models',
        DataMember => 'FlashGroupAControlMode',
        RawConv => '$$self{FlashGroupAControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    17.1 => {
        Name => 'FlashGroupBControlMode',
        Mask => 0xf0,
        Notes => 'note: group B tags may apply to group A settings for some models',
        DataMember => 'FlashGroupBControlMode',
        RawConv => '$$self{FlashGroupBControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    17.2 => { #PH
        Name => 'FlashGroupCControlMode',
        Mask => 0x0f,
        Notes => 'note: group C tags may apply to group B settings for some models',
        DataMember => 'FlashGroupCControlMode',
        RawConv => '$$self{FlashGroupCControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18 => [
        {
            Name => 'FlashGroupAOutput',
            Condition => '$$self{FlashGroupAControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupACompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    19 => [
        {
            Name => 'FlashGroupBOutput',
            Condition => '$$self{FlashGroupBControlMode} >= 0x60',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupBCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    20 => [ #PH
        {
            Name => 'FlashGroupCOutput',
            Condition => '$$self{FlashGroupCControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupCCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
);

# Flash information for D90 and D700 (ref PH)
# - confirmed in detail for D800 (0105) - PH
%Image::ExifTool::Nikon::FlashInfo0103 = (
    %binaryDataAttrs,
    DATAMEMBER => [ 9.2, 17.1, 18.1, 18.2 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are used by the D3 (firmware 2.x), D3X, D3S, D4, D90, D300
        (firmware 1.10), D300S, D600, D700, D800, D3000, D3100, D3200, D5000, D5100,
        D5200, D7000.
    },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'FlashInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    4 => { #PH
        Name => 'FlashSource',
        PrintConv => {
            0 => 'None',
            1 => 'External',
            2 => 'Internal',
        },
    },
    # 5 - values: 46,48,50,54,78
    6 => {
        Format => 'int8u[2]',
        Name => 'ExternalFlashFirmware',
        SeparateTable => 'FlashFirmware',
        PrintConv => \%flashFirmware,
    },
    8 => {
        Name => 'ExternalFlashFlags',
        PrintConv => { BITMASK => {
            0 => 'Fired', #28
            2 => 'Bounce Flash', #PH
            4 => 'Wide Flash Adapter',
            5 => 'Dome Diffuser', #28
        }},
    },
    9.1 => {
        Name => 'FlashCommanderMode',
        Mask => 0x80,
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    9.2 => {
        Name => 'FlashControlMode',
        Mask => 0x7f,
        DataMember => 'FlashControlMode',
        RawConv => '$$self{FlashControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    10 => [
        {
            Name => 'FlashOutput',
            Condition => '$$self{FlashControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashCompensation',
            # this is the compensation from the camera (0x0012) for "Built-in" FlashType, or
            # the compensation from the external unit (0x0017) for "Optional" FlashType - PH
            Format => 'int8s',
            Priority => 0,
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
    ],
    12 => { #JD
        Name => 'FlashFocalLength',
        RawConv => '($val and $val != 255) ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    13 => { #JD
        Name => 'RepeatingFlashRate',
        RawConv => '($val and $val != 255) ? $val : undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    14 => { #JD
        Name => 'RepeatingFlashCount',
        RawConv => '($val and $val != 255) ? $val : undef',
    },
    15 => { #28
        Name => 'FlashGNDistance',
        SeparateTable => 1,
        PrintConv => \%flashGNDistance,
    },
    16 => { #28
        Name => 'FlashColorFilter',
        SeparateTable => 1,
        PrintConv => \%flashColorFilter,
    },
    17.1 => {
        Name => 'FlashGroupAControlMode',
        Mask => 0x0f,
        Notes => 'note: group A tags may apply to the built-in flash settings for some models',
        DataMember => 'FlashGroupAControlMode',
        RawConv => '$$self{FlashGroupAControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18.1 => {
        Name => 'FlashGroupBControlMode',
        Mask => 0xf0,
        Notes => 'note: group B tags may apply to group A settings for some models',
        DataMember => 'FlashGroupBControlMode',
        RawConv => '$$self{FlashGroupBControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18.2 => { #PH
        Name => 'FlashGroupCControlMode',
        Mask => 0x0f,
        Notes => 'note: group C tags may apply to group B settings for some models',
        DataMember => 'FlashGroupCControlMode',
        RawConv => '$$self{FlashGroupCControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    0x13 => [
        {
            Name => 'FlashGroupAOutput',
            Condition => '$$self{FlashGroupAControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupACompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x14 => [
        {
            Name => 'FlashGroupBOutput',
            Condition => '$$self{FlashGroupBControlMode} >= 0x60',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupBCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x15 => [ #PH
        {
            Name => 'FlashGroupCOutput',
            Condition => '$$self{FlashGroupCControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupCCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x1b => { #PH
        Name => 'ExternalFlashCompensation',
        Format => 'int8s',
        Priority => 0,
        ValueConv => '-$val/6',
        ValueConvInv => '-6 * $val',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x1d => { #PH
        Name => 'FlashExposureComp3',
        Format => 'int8s',
        # (does not include the built-in compensation for FlashType "Built-in,TTL&Comdr.")
        Notes => 'does not include the effect of flash bracketing',
        Priority => 0,
        ValueConv => '-$val/6',
        ValueConvInv => '-6 * $val',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x27 => { #PH (same as ShotInfoD800 0x4d2 but also valid for repeating flash)
        Name => 'FlashExposureComp4',
        Format => 'int8s',
        Notes => 'includes the effect of flash bracketing.  Valid for repeating flash',
        Priority => 0,
        ValueConv => '-$val/6',
        ValueConvInv => '-6 * $val',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    # 0x2b - related to flash power (PH, D800, 96=full,62=1/4,2=1/128)
);

# Flash information for the D7100 (ref PH)
# (this is VERY similar to FlashInfo0107, but there are a few differences that
#  would need to be resolved if these two definitions were to be combined)
%Image::ExifTool::Nikon::FlashInfo0106 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 9.2, 17.1, 18.1, 18.2 ],
    NOTES => 'These tags are used by the Df, D610, D3300, D5300, D7100 and Coolpix A.',
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'FlashInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    4 => {
        Name => 'FlashSource',
        PrintConv => {
            0 => 'None',
            1 => 'External',
            2 => 'Internal',
        },
    },
    6 => {
        Format => 'int8u[2]',
        Name => 'ExternalFlashFirmware',
        SeparateTable => 'FlashFirmware',
        PrintConv => \%flashFirmware,
    },
    8 => {
        Name => 'ExternalFlashFlags',
        PrintConv => { BITMASK => {
            0 => 'Fired',
            2 => 'Bounce Flash',
            4 => 'Wide Flash Adapter',
            5 => 'Dome Diffuser', # (NC, not true for the SB-910 anyway)
          # 7 - ? (set for SB-910 when an advanced option is used, eg. diff pattern)
        }},
    },
    9.1 => { # (NC)
        Name => 'FlashCommanderMode',
        Mask => 0x80,
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    9.2 => {
        Name => 'FlashControlMode',
        Mask => 0x7f,
        DataMember => 'FlashControlMode',
        RawConv => '$$self{FlashControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
  # 10 - similar to 0x27 but zero sometimes when I don't think it should be
    12 => {
        Name => 'FlashFocalLength',
        Notes => 'only valid if flash pattern is "Standard Illumination"',
        RawConv => '($val and $val != 255) ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    13 => {
        Name => 'RepeatingFlashRate',
        RawConv => '($val and $val != 255) ? $val : undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    14 => {
        Name => 'RepeatingFlashCount',
        RawConv => '($val and $val != 255) ? $val : undef',
    },
    15 => { # (NC)
        Name => 'FlashGNDistance',
        SeparateTable => 1,
        PrintConv => \%flashGNDistance,
    },
    16 => {
        Name => 'FlashColorFilter',
        SeparateTable => 1,
        PrintConv => \%flashColorFilter,
    },
    17.1 => {
        Name => 'FlashGroupAControlMode',
        Mask => 0x0f,
        DataMember => 'FlashGroupAControlMode',
        RawConv => '$$self{FlashGroupAControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18.1 => {
        Name => 'FlashGroupBControlMode',
        Mask => 0xf0,
        DataMember => 'FlashGroupBControlMode',
        RawConv => '$$self{FlashGroupBControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18.2 => {
        Name => 'FlashGroupCControlMode',
        Mask => 0x0f,
        DataMember => 'FlashGroupCControlMode',
        RawConv => '$$self{FlashGroupCControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
  # 0x13 - same as 0x28 but not zero when flash group A is Off
  # 0x14 - same as 0x29 but not zero when flash group B is Off
  # 0x15 - same as 0x2a but not zero when flash group B is Off
  # 0x1a - changes with illumination pattern (0=normal,1=narrow,2=wide), but other values seen
  # 0x26 - changes when diffuser is used
    0x27 => [
        {
            Name => 'FlashOutput',
            Condition => '$$self{FlashControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashCompensation',
            Format => 'int8s',
            Priority => 0,
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
    ],
    0x28 => [
        {
            Name => 'FlashGroupAOutput',
            Condition => '$$self{FlashGroupAControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupACompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x29 => [
        {
            Name => 'FlashGroupBOutput',
            Condition => '$$self{FlashGroupBControlMode} >= 0x60',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupBCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x2a => [
        {
            Name => 'FlashGroupCOutput',
            Condition => '$$self{FlashGroupCControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupCCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
);

# Flash information for the D4S/D750/D810/D5500/D7200 (0107)
# and D5/D500/D850/D3400 (0108) (ref 28)
%Image::ExifTool::Nikon::FlashInfo0107 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 17.1, 18.1, 18.2 ],
    NOTES => q{
        These tags are used by the D4S, D750, D810, D5500, D7200 (FlashInfoVersion
        0107) and the D5, D500, D850 and D3400 (FlashInfoVersion 0108).
    },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'FlashInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    4 => {
        Name => 'FlashSource',
        PrintConv => {
            0 => 'None',
            1 => 'External',
            2 => 'Internal',
        },
    },
    6 => {
        Format => 'int8u[2]',
        Name => 'ExternalFlashFirmware',
        SeparateTable => 'FlashFirmware',
        PrintConv => \%flashFirmware,
    },
    8.1 => {
        Name => 'ExternalFlashZoomOverride',
        Mask => 0x80,
        Notes => 'indicates that the user has overridden the flash zoom distance',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    8.2 => {
        Name => 'ExternalFlashStatus',
        Mask => 0x01,
        PrintConv => {
            0 => 'Flash Not Attached',
            1 => 'Flash Attached',
        },
    },
    9.1 => {
        Name => 'ExternalFlashReadyState',
        Mask => 0x07,
        PrintConv => {
            0 => 'n/a',
            1 => 'Ready',
            6 => 'Not Ready',
        },
    },
    10 => {
        Name => 'FlashCompensation',
        # this is the compensation from the camera (0x0012) for "Built-in" FlashType, or
        # the compensation from the external unit (0x0017) for "Optional" FlashType - PH
        Format => 'int8s',
        Priority => 0,
        ValueConv => '-$val/6',
        ValueConvInv => '-6 * $val',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    12 => {
        Name => 'FlashFocalLength',
        Notes => 'only valid if flash pattern is "Standard Illumination"',
        RawConv => '($val and $val != 255) ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    13 => {
        Name => 'RepeatingFlashRate',
        RawConv => '($val and $val != 255) ? $val : undef',
        PrintConv => '"$val Hz"',
        PrintConvInv => '$val=~/(\d+)/; $1 || 0',
    },
    14 => {
        Name => 'RepeatingFlashCount',
        RawConv => '($val and $val != 255) ? $val : undef',
    },
    15 => {
        Name => 'FlashGNDistance',
        SeparateTable => 1,
        PrintConv => \%flashGNDistance,
    },
    17.1 => { #PH
        Name => 'FlashGroupAControlMode',
        Mask => 0x0f,
        Notes => 'note: group A tags may apply to the built-in flash settings for some models',
        DataMember => 'FlashGroupAControlMode',
        RawConv => '$$self{FlashGroupAControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18.1 => { #PH
        Name => 'FlashGroupBControlMode',
        Mask => 0xf0,
        Notes => 'note: group B tags may apply to group A settings for some models',
        DataMember => 'FlashGroupBControlMode',
        RawConv => '$$self{FlashGroupBControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    18.2 => { #PH
        Name => 'FlashGroupCControlMode',
        Mask => 0x0f,
        Notes => 'note: group C tags may apply to group B settings for some models',
        DataMember => 'FlashGroupCControlMode',
        RawConv => '$$self{FlashGroupCControlMode} = $val',
        PrintConv => \%flashControlMode,
        SeparateTable => 'FlashControlMode',
    },
    # 0x13 - very similar to 0x28
    # 0x18 or 0x19 may indicate flash illumination pattern (Standard, Center-weighted, Even)
    0x28 => [ #PH
        {
            Name => 'FlashGroupAOutput',
            Condition => '$$self{FlashGroupAControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupACompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x29 => [ #PH
        {
            Name => 'FlashGroupBOutput',
            Condition => '$$self{FlashGroupBControlMode} >= 0x60',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupBCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
    0x2a => [ #PH
        {
            Name => 'FlashGroupCOutput',
            Condition => '$$self{FlashGroupCControlMode} >= 0x06',
            ValueConv => '2 ** (-$val/6)',
            ValueConvInv => '$val>0 ? -6*log($val)/log(2) : 0',
            PrintConv => '$val>0.99 ? "Full" : sprintf("%.0f%%",$val*100)',
            PrintConvInv => '$val=~/(\d+)/ ? $1/100 : 1',
        },
        {
            Name => 'FlashGroupCCompensation',
            Format => 'int8s',
            ValueConv => '-$val/6',
            ValueConvInv => '-6 * $val',
            PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
            PrintConvInv => '$val',
        },
    ],
);

# Unknown Flash information
%Image::ExifTool::Nikon::FlashInfoUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'FlashInfoVersion',
        Format => 'string[4]',
        Writable => 0,
    },
);

# Multi exposure / image overlay information (ref PH)
%Image::ExifTool::Nikon::MultiExposure = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'MultiExposureVersion',
        Format => 'string[4]',
        Writable => 0,
    },
    1 => {
        Name => 'MultiExposureMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Multiple Exposure',
            2 => 'Image Overlay',
            3 => 'HDR', #31
        },
    },
    2 => 'MultiExposureShots',
    3 => {
        Name => 'MultiExposureAutoGain',
        PrintConv => \%offOn,
    },
);

# HDR information (ref 32)
%Image::ExifTool::Nikon::HDRInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # NOTE: Must set ByteOrder in SubDirectory if any multi-byte integer tags added
    0 => {
        Name => 'HDRInfoVersion',
        Format => 'string[4]',
    },
    4 => {
        Name => 'HDR',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            48 => 'Auto', #PH (NC)
        },
    },
    5 => {
        Name => 'HDRLevel',
        PrintConv => {
            0 => 'Auto',
            1 => '1 EV',
            2 => '2 EV',
            3 => '3 EV',
            # 5 - seen for 1J4
            255 => 'n/a', #PH
        },
    },
    6 => {
        Name => 'HDRSmoothing',
        PrintConv => {
            0 => 'Off',
            1 => 'Normal',
            2 => 'Low',
            3 => 'High',
            48 => 'Auto', #PH (NC)
            255 => 'n/a', #PH
        },
    },
    7 => { #PH (P330, HDRInfoVersion=0101)
        Name => 'HDRLevel2',
        PrintConv => {
            0 => 'Auto',
            1 => '1 EV',
            2 => '2 EV',
            3 => '3 EV',
            255 => 'n/a',
        },
    },
);

# location information (ref PH)
%Image::ExifTool::Nikon::LocationInfo = (
    %binaryDataAttrs,
    DATAMEMBER => [ 4 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Location' },
    NOTES => 'Tags written by some Nikon GPS-equipped cameras like the AW100.',
    0 => {
        Name => 'LocationInfoVersion',
        Format => 'undef[4]',
    },
    4 => {
        Name => 'TextEncoding',
        DataMember => 'TextEncoding',
        RawConv => q{
            $$self{TextEncoding} = $Image::ExifTool::Nikon::nikonTextEncoding{$val} if $val;
            return $val;
        },
        PrintConv => \%Image::ExifTool::Nikon::nikonTextEncoding,
    },
    # (the CountryCode and Location tag names chosen to correspond with XMP::iptcCore)
    5 => {
        Name => 'CountryCode',
        Format => 'undef[3]',
        ValueConv => '$val=~s/\0.*//s; $val', # truncate at null
        ValueConvInv => '$val',
    },
    8 => 'POILevel', #forum5782
    9 => {
        Name => 'Location',
        Format => 'undef[70]',
        RawConv    => '$$self{TextEncoding} ? $self->Decode($val,$$self{TextEncoding},"MM") : $val',
        RawConvInv => '$$self{TextEncoding} ? $self->Encode($val,$$self{TextEncoding},"MM") : $val',
    },
);

# tags in Nikon QuickTime videos (PH - observations with Coolpix S3)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Nikon::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in MOV and QT videos from some Nikon cameras.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[8]',
    },
    # (01 00 at offset 0x20)
    0x26 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x2a => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x32 => {
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    0x44 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
        },
    },
    0x48 => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    0xaf => {
        Name => 'Software',
        Format => 'string[16]',
    },
    0xdf => { # (this is a guess ... could also be offset 0xdb)
        Name => 'ISO',
        Format => 'int16u',
        RawConv => '$val < 50 ? undef : $val', # (not valid for Coolpix L10)
    },
);

# Nikon metadata in AVI videos (PH)
%Image::ExifTool::Nikon::AVI = (
    NOTES => 'Nikon-specific RIFF tags found in AVI videos.',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    nctg => {
        Name => 'NikonTags',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::AVITags' },
    },
    ncth => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    ncvr => {
        Name => 'NikonVers',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::AVIVers' },
    },
    ncvw => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        RawConv => 'length($val) ? $val : undef',
        Binary => 1,
    },
);

# version information in AVI videos (PH)
%Image::ExifTool::Nikon::AVIVers = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    PROCESS_PROC => \&ProcessNikonAVI,
    FORMAT => 'string',
    0x01 => 'MakerNoteType',
    0x02 => {
        Name => 'MakerNoteVersion',
        Format => 'int8u',
        ValueConv => 'my @a = reverse split " ", $val; join ".", @a;',
    },
);

# tags in AVI videos (PH)
%Image::ExifTool::Nikon::AVITags = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessNikonAVI,
    FORMAT => 'string',
    NOTES => q{
        These tags and the AVIVer tags below are found in proprietary-format records
        of Nikon AVI videos.
    },
    0x03 => 'Make',
    0x04 => 'Model',
    0x05 => {
        Name => 'Software',
        Format => 'undef',
        ValueConv => '$val =~ tr/\0//d; $val',
    },
    0x06 => 'Equipment', # "NIKON DIGITAL CAMERA"
    0x07 => { # (guess)
        Name => 'Orientation',
        Format => 'int16u',
        Groups => { 2 => 'Image' },
        PrintConv => \%Image::ExifTool::Exif::orientation,
    },
    0x08 => {
        Name => 'ExposureTime',
        Format => 'rational64u',
        Groups => { 2 => 'Image' },
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x09 => {
        Name => 'FNumber',
        Format => 'rational64u',
        Groups => { 2 => 'Image' },
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x0a => {
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        Groups => { 2 => 'Image' },
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    0x0b => {
        Name => 'MaxApertureValue',
        Format => 'rational64u',
        ValueConv => '2 ** ($val / 2)',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x0c => {
        Name => 'MeteringMode', # (guess)
        Format => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Average',
            2 => 'Center-weighted average',
            3 => 'Spot',
            4 => 'Multi-spot',
            5 => 'Multi-segment',
            6 => 'Partial',
            255 => 'Other',
        },
    },
    0x0d => { # val: 0
        Name => 'Nikon_AVITags_0x000d',
        Format => 'int16u',
        Flags => [ 'Hidden', 'Unknown' ],
    },
    0x0e => { # val: 0
        Name => 'Nikon_AVITags_0x000e',
        Format => 'int16u',
        Flags => [ 'Hidden', 'Unknown' ],
    },
    0x0f => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    0x10 => {
        Name => 'XResolution',
        Format => 'rational64u',
        Groups => { 2 => 'Image' },
    },
    0x11 => {
        Name => 'YResolution',
        Format => 'rational64u',
        Groups => { 2 => 'Image' },
    },
    0x12 => {
        Name => 'ResolutionUnit',
        Format => 'int16u',
        Groups => { 2 => 'Image' },
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    0x13 => {
        Name => 'DateTimeOriginal', # (guess)
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x14 => {
        Name => 'CreateDate', # (guess)
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x15 => {
        Name => 'Nikon_AVITags_0x0015',
        Format => 'int16u',
        Flags => [ 'Hidden', 'Unknown' ],
    },
    0x16 => {
        Name => 'Duration',
        Format => 'rational64u',
        PrintConv => '"$val s"',
    },
    0x17 => { # val: 1
        Name => 'Nikon_AVITags_0x0017',
        Format => 'int16u',
        Flags => [ 'Hidden', 'Unknown' ],
    },
    0x18 => 'FocusMode',
    0x19 => { # vals: -5, -2, 3, 5, 6, 8, 11, 12, 14, 20, 22
        Name => 'Nikon_AVITags_0x0019',
        Format => 'int32s',
        Flags => [ 'Hidden', 'Unknown' ],
    },
    0x1b => { # vals: 1 (640x480), 1.25 (320x240)
        Name => 'DigitalZoom',
        Format => 'rational64u',
    },
    0x1c => { # (same as Nikon_0x000a)
        Name => 'Nikon_AVITags_0x001c',
        Format => 'rational64u',
        Flags => [ 'Hidden', 'Unknown' ],
    },
    0x1d => 'ColorMode',
    0x1e => { # string[8] - val: "AUTO"
        Name => 'Sharpness', # (guess, could also be ISOSelection)
    },
    0x1f => { # string[16] - val: "AUTO"
        Name => 'WhiteBalance', # (guess, could also be ImageAdjustment)
    },
    0x20 => { # string[4] - val: "OFF"
        Name => 'NoiseReduction', # (guess)
    },
    0x801a => { # val: 0 (why is the 0x8000 bit set in the ID?)
        Name => 'Nikon_AVITags_0x801a',
        Format => 'int32s',
        Flags => [ 'Hidden', 'Unknown' ],
    }
);

# Nikon NCDT atoms (ref PH)
%Image::ExifTool::Nikon::NCDT = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Nikon', 2 => 'Video' },
    NOTES => q{
        Nikon-specific QuickTime tags found in the NCDT atom of MOV videos from
        various Nikon models.
    },
    NCHD => {
        Name => 'MakerNoteVersion',
        Format => 'undef',
        ValueConv => q{
            $val =~ s/\0$//;    # remove trailing null
            $val =~ s/([\0-\x1f])/'.'.ord($1)/ge;
            $val =~ s/\./ /; return $val;
        },
    },
    NCTG => {
        Name => 'NikonTags',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::NCTG' },
    },
    NCTH => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
    },
    NCVW => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
    },
    NCDB => { # (often 0 bytes long, or 4 null bytes)
        Name => 'NikonNCDB',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::NCDB' },
    },
    NCM1 => {
        Name => 'PreviewImage1',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
        RawConv => 'length $val ? $val : undef',
    },
    NCM2 => { #PH (guess - have only seen 0 bytes)
        Name => 'PreviewImage2',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Binary => 1,
        RawConv => 'length $val ? $val : undef',
    },
);

# Nikon NCDB tags from MOV videos (ref PH)
%Image::ExifTool::Nikon::NCDB = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Nikon', 2 => 'Video' },
    # the following probably contain encrypted data -- look into decryping these!
    # OP01 - 320 bytes, starts with "0200" (D600,D610,D810,D3200,D5200)
    #      - 638 bytes, starts with "0200" (D7100)
    # OP02 - 2048 bytes, starts with "0200" (D810)
);

# Nikon NCTG tags from MOV videos (ref PH)
%Image::ExifTool::Nikon::NCTG = (
    PROCESS_PROC => \&ProcessNikonMOV,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are found in proprietary-format records of the NCTG atom in MOV
        videos from some Nikon cameras.
    },
    0x01 => 'Make',
    0x02 => 'Model',
    0x03 => 'Software',
    0x11 => {
        Name => 'CreateDate', #(guess, but matches QuickTime CreateDate)
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x12 => {
        Name => 'DateTimeOriginal', #(guess, but time is 1 sec before tag 0x11)
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x13 => {
        Name => 'FrameCount',
        # int32u[2]: "467 0", "1038 0", "1127 0"
        ValueConv => '$val =~ s/ 0$//; $val', # (not sure what the extra "0" is for)
    },
    # 0x14 - int32u[2]: "0 0"
    # 0x15 - int32u[2]: "0 0"
    0x16 => {
        Name => 'FrameRate',
        Groups => { 2 => 'Video' },
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    # 0x17 - rational62u: same value as FrameRate
    # 0x18 - int16u: 1, 2
    0x19 => {
        Name => 'TimeZone',
        Groups => { 2 => 'Time' },
    },
    # 0x21 - int16u: 1, 2
    0x22 => {
        Name => 'FrameWidth',
        Groups => { 2 => 'Video' },
    },
    0x23 => {
        Name => 'FrameHeight',
        Groups => { 2 => 'Video' },
    },
    # 0x24 - int16u: 1, 2
    # 0x31 - int16u: 0, 1, 2
    0x32 => { #(guess)
        Name => 'AudioChannels',
        Groups => { 2 => 'Audio' },
    },
    0x33 => {
        Name => 'AudioBitsPerSample',
        Groups => { 2 => 'Audio' },
    },
    0x34 => {
        Name => 'AudioSampleRate',
        Groups => { 2 => 'Audio' },
    },
    # 0x101 - int16u[4]: "160 120 1280 720", "160 120 3840 2160"
    # 0x102 - int16u[8]: "640 360 0 0 0 0 0 0", "640 360 1920 1080 0 0 0 0"
    # 0x1001 - int16s: 0
    0x1002 => {
        Name => 'NikonDateTime', #?
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    # 0x1011 - int32u: 0
    # 0x1012 - int32u: 0
    0x1013 => { #HayoBaan
        Name => 'ElectronicVR',
        PrintConv => \%offOn,
    },
    # 0x1014 - int16u: 1
    # 0x1021 - int32u[32]: all zeros
#
# 0x110**** tags correspond to 0x**** tags in Exif::Main
#
    0x110829a => { #34
        Name => 'ExposureTime',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x110829d => { #34
        Name => 'FNumber',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    0x1108822 => {
        Name => 'ExposureProgram',
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
          # 9 => 'Bulb', # (non-standard Canon value)
        },
    },
    0x1109204 => {
        Name => 'ExposureCompensation',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    0x1109207 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Average',
            2 => 'Center-weighted average',
            3 => 'Spot',
            4 => 'Multi-spot',
            5 => 'Multi-segment',
            6 => 'Partial',
            255 => 'Other',
        },
    },
    0x110920a => { #34
        Name => 'FocalLength',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    0x110a431 => 'SerialNumber',
    0x110a432 => {
        Name => 'LensInfo',
        PrintConv => \&Image::ExifTool::Exif::PrintLensInfo,
    },
    0x110a433 => 'LensMake',
    0x110a434 => 'LensModel',
    0x110a435 => 'LensSerialNumber',
#
# 0x120**** tags correspond to 0x**** tags in GPS::Main
#
    0x1200000 => {
        Name => 'GPSVersionID',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => '$val =~ tr/ /./; $val',
    },
    0x1200001 => {
        Name => 'GPSLatitudeRef',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0x1200002 => {
        Name => 'GPSLatitude',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        ValueConv => q{
            require Image::ExifTool::GPS;
            Image::ExifTool::GPS::ToDegrees($val);
        },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    0x1200003 => {
        Name => 'GPSLongitudeRef',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0x1200004 => {
        Name => 'GPSLongitude',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        ValueConv => q{
            require Image::ExifTool::GPS;
            Image::ExifTool::GPS::ToDegrees($val);
        },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    0x1200005 => {
        Name => 'GPSAltitudeRef',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    0x1200006 => {
        Name => 'GPSAltitude',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => '$val =~ /^(inf|undef)$/ ? $val : "$val m"',
    },
    0x1200007 => {
        Name => 'GPSTimeStamp',
        Groups => { 1 => 'GPS', 2 => 'Time' },
        ValueConv => q{
            require Image::ExifTool::GPS;
            Image::ExifTool::GPS::ConvertTimeStamp($val);
        },
        PrintConv => 'Image::ExifTool::GPS::PrintTimeStamp($val)',
    },
    0x1200008 => {
        Name => 'GPSSatellites',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0x1200010 => {
        Name => 'GPSImgDirectionRef',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    0x1200011 => {
        Name => 'GPSImgDirection',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0x1200012 => {
        Name => 'GPSMapDatum',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0x120001d => {
        Name => 'GPSDateStamp',
        Groups => { 1 => 'GPS', 2 => 'Time' },
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
#
# 0x200**** tags correspond to 0x**** tags in Nikon::Main
# (must be duplicated here so tagInfo "Table" entry will point to correct table.
#  Also there would be a problem with the PRINT_CONV from the Main table)
#
    0x2000001 => {
        Name => 'MakerNoteVersion',
        PrintConv => '$_=$val;s/^(\d{2})/$1\./;s/^0//;$_',
    },
    0x2000005 => 'WhiteBalance',
    0x2000007 => { Name => 'FocusMode',    Writable => 'string' }, #34
    0x200000b => 'WhiteBalanceFineTune',
    0x200001b => {
        Name => 'CropHiSpeed',
        Writable => 'int16u',
        Count => 7,
        PrintConv => \%cropHiSpeed,
    },
    0x200001e => {
        Name => 'ColorSpace',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
    0x200001f => {
        Name => 'VRInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::VRInfo' },
    },
    0x2000022 => {
        Name => 'ActiveD-Lighting',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            3 => 'Normal',
            5 => 'High',
            7 => 'Extra High',
            8 => 'Extra High 1',
            9 => 'Extra High 2',
            10 => 'Extra High 3',
            11 => 'Extra High 4',
            0xffff => 'Auto',
        },
    },
    0x2000023 => [
        { #PH (D300, but also found in D3,D3S,D3X,D90,D300S,D700,D3000,D5000)
            Condition => '$$valPt =~ /^01/',
            Name => 'PictureControlData',
            Writable => 'undef',
            Permanent => 0,
            Flags => [ 'Binary', 'Protected' ],
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::PictureControl' },
        },{ #28
            Name => 'PictureControlData',
            Writable => 'undef',
            Permanent => 0,
            Flags => [ 'Binary', 'Protected' ],
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::PictureControl2' },
        },
    ],
    0x2000024 => {
        Name => 'WorldTime',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::WorldTime' },
    },
    0x2000025 => { #34
        Name => 'ISOInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::ISOInfo',
            ByteOrder => 'BigEndian', # (BigEndian even for D810, which is a little-endian camera)
        },
    },
    0x200002a => { #23 (this tag added with D3 firmware 1.10 -- also written by Nikon utilities)
        Name => 'VignetteControl',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            3 => 'Normal',
            5 => 'High',
        },
    },
    0x200002c => {
        Name => 'UnknownInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::UnknownInfo' },
    },
    # 0x200002d - int16u[3]: "512 0 0"
    0x2000032 => {
        Name => 'UnknownInfo2',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::UnknownInfo2' },
    },
    0x2000039 => {
        Name => 'LocationInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::LocationInfo' },
    },
    # 0x200003f - rational64s[2]: "0 0"
    # 0x2000042 - undef[6]: "0100\x03\0"
    # 0x2000043 - undef[12]: all zeros
    0x2000083 => {
        Name => 'LensType',
        # credit to Tom Christiansen (ref 7) for figuring this out...
        PrintConv => q[$_ = $val ? Image::ExifTool::DecodeBits($val,
            {
                0 => 'MF',
                1 => 'D',
                2 => 'G',
                3 => 'VR',
            }) : 'AF';
            # remove commas and change "D G" to just "G"
            s/,//g; s/\bD G\b/G/; $_
        ],
    },
    0x2000084 => {
        Name => "Lens",
        # short focal, long focal, aperture at short focal, aperture at long focal
        PrintConv => \&Image::ExifTool::Exif::PrintLensInfo,
    },
    0x2000087 => {
        Name => 'FlashMode',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Did Not Fire',
            1 => 'Fired, Manual', #14
            3 => 'Not Ready', #28
            7 => 'Fired, External', #14
            8 => 'Fired, Commander Mode',
            9 => 'Fired, TTL Mode',
        },
    },
    0x2000098 => [
        { #8
            Condition => '$$valPt =~ /^0100/', # D100, D1X - PH
            Name => 'LensData0100',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::LensData00' },
        },
        { #8
            Condition => '$$valPt =~ /^0101/', # D70, D70s - PH
            Name => 'LensData0101',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::LensData01' },
        },
        # note: this information is encrypted if the version is 02xx
        { #8
            # 0201 - D200, D2Hs, D2X and D2Xs
            # 0202 - D40, D40X and D80
            # 0203 - D300
            Condition => '$$valPt =~ /^020[1-3]/',
            Name => 'LensData0201',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData01',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        { #PH
            Condition => '$$valPt =~ /^0204/', # D90, D7000
            Name => 'LensData0204',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData0204',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        {
            Condition => '$$valPt =~ /^0400/', # 1J1, 1V1
            Name => 'LensData0400',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensData0400',
                ProcessProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                WriteProc => \&Image::ExifTool::Nikon::ProcessNikonEncrypted,
                DecryptStart => 4,
            },
        },
        {   # (1J1/1V1=0400)
            Name => 'LensDataUnknown',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::LensDataUnknown',
            },
        },
    ],
    0x20000a7 => { # Number of shots taken by camera so far (ref 2)
        Name => 'ShutterCount',
        PrintConv => '$val == 4294965247 ? "n/a" : $val',
    },
    0x20000a8 => [
        {
            Name => 'FlashInfo0100',
            Condition => '$$valPt =~ /^010[01]/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0100' },
        },
        {
            Name => 'FlashInfo0102',
            Condition => '$$valPt =~ /^0102/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0102' },
        },
        {
            Name => 'FlashInfo0103',
            # (0104 for D7000, 0105 for D800)
            Condition => '$$valPt =~ /^010[345]/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0103' },
        },
        {
            Name => 'FlashInfo0106', # (0106 for D7100)
            Condition => '$$valPt =~ /^0106/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0106' },
        },
        {
            Name => 'FlashInfo0107', # (0107 for D4S/D750/D810/D5500/D7200, 0108 for D5/D500/D3400)
            Condition => '$$valPt =~ /^010[78]/',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfo0107' },
        },
        {
            Name => 'FlashInfoUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Nikon::FlashInfoUnknown' },
        },
    ],
    0x20000ab => { Name => 'VariProgram', Writable => 'string' }, #2 (scene mode for DSLR's - PH)
    0x20000b1 => { #34
        Name => 'HighISONoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Minimal', # for high ISO (>800) when setting is "Off"
            2 => 'Low',     # Low,Normal,High take effect for ISO > 400
            3 => 'Medium Low',
            4 => 'Normal',
            5 => 'Medium High',
            6 => 'High',
        },
    },
    0x20000b7 => {
        Name => 'AFInfo2',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::AFInfo2' },
    },
    # 0x20000c0 - undef[8]
    0x20000c3 => {
        Name => 'BarometerInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nikon::BarometerInfo',
            # (little-endian in II EXIF, big-endian in MOV)
        },
    },
);

# Nikon composite tags
%Image::ExifTool::Nikon::Composite = (
    GROUPS => { 2 => 'Camera' },
    LensSpec => {
        Require => {
            0 => 'Nikon:Lens',
            1 => 'Nikon:LensType',
        },
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => '"$prt[0] $prt[1]"',
    },
    LensID => {
        SeparateTable => 'Nikon LensID',    # print values in a separate table
        Require => {
            0 => 'Nikon:LensIDNumber',
            1 => 'LensFStops',
            2 => 'MinFocalLength',
            3 => 'MaxFocalLength',
            4 => 'MaxApertureAtMinFocal',
            5 => 'MaxApertureAtMaxFocal',
            6 => 'MCUVersion',
            7 => 'Nikon:LensType',
        },
        # construct lens ID string as per ref 11
        ValueConv => 'sprintf("%.2X"." %.2X"x7, @raw)',
        PrintConv => \%nikonLensIDs,
    },
    AutoFocus => {
        Require => {
            0 => 'Nikon:PhaseDetectAF',
            1 => 'Nikon:ContrastDetectAF',
        },
        ValueConv => '($val[0] or $val[1]) ? 1 : 0',
        PrintConv => \%offOn,
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Nikon');

#------------------------------------------------------------------------------
# Process Nikon AVI tags (D5000 videos)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNikonAVI($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart} || 0;
    my $dirEnd = $pos + $$dirInfo{DirLen};
    $et->VerboseDir($dirInfo, undef, $$dirInfo{DirLen});
    SetByteOrder('II');
    while ($pos + 4 <= $dirEnd) {
        my $tag = Get16u($dataPt, $pos);
        my $size = Get16u($dataPt, $pos + 2);
        $pos += 4;
        last if $pos + $size > $dirEnd;
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => $size,
        );
        $pos += $size;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Print conversion for Nikon AF points
# Inputs: 0) value to convert (as a string of hex bytes),
#         1) lookup for AF point bit number (starting at 1)
sub PrintAFPoints($$)
{
    my ($val, $afPoints) = @_;
    my ($i, $j, @points);
    $val =~ tr/ //d;    # remove spaces from hex string
    my @dat = unpack 'C*', pack 'H*', $val; # convert to array of bytes
    # loop through all bytes to find active AF points
    for ($i=0; $i<=@dat; ++$i) {
        next unless $dat[$i];
        for ($j=0; $j<8; ++$j) {
            next unless $dat[$i] & (1 << $j);
            my $point = $$afPoints{$i*8 + $j + 1};
            push @points, $point if defined $point;
        }
    }
    return '(none)' unless @points;
    # sort the points and return as comma-separated string
    return join ',', sort {
        return $a cmp $b if length($a) == length($b);
        return substr($a,0,1).'0'.substr($a,1,1) cmp $b if length($a) == 2;
        return $a cmp substr($b,0,1).'0'.substr($b,1,1);
    } @points;
}

#------------------------------------------------------------------------------
# Inverse print conversion for AF points
# Inputs: 0) AF point string, 1) AF point lookup
# Returns: AF point data as a string of hex bytes
sub PrintAFPointsInv($$)
{
    my ($val, $afPoints) = @_;
    my @points = ($val =~ /[A-Za-z]\d+/g);
    my $size = int((scalar(keys %$afPoints) + 7) / 8);
    my @dat = (0) x $size;
    if (@points) {
        my (%bitNum, $point);
        $bitNum{$$afPoints{$_}} = $_ foreach keys %$afPoints; # build reverse lookup
        foreach $point (@points) {
            my $bitNum = $bitNum{uc $point} or next;
            my $byte = int(($bitNum - 1) / 8);
            $dat[$byte] |= (1 << (($bitNum - 1) % 8));
        }
    }
    return join(" ", unpack("H2"x$size, pack('C*', @dat)));
}

#------------------------------------------------------------------------------
# Get AF point name for grid-type AF
# Inputs: 0) AF point number, 1) number of columns, 2) true for inverse conversion
# Returns: AF point name, or undef
sub GetAFPointGrid($$;$)
{
    my ($val, $ncol, $inv) = @_;
    if ($inv) {
        return undef unless $val =~ /^([A-J])(\d+)$/i;
        return (ord(uc($1))-65) * $ncol + $2 - 1;
    } else {
        my $row = int(($val + 0.5) / $ncol);
        my $col = $val - $ncol * $row + 1;
        return chr(65+$row) . $col;
    }
}

#------------------------------------------------------------------------------
# Print conversion for grid-type AF points
# Inputs: 0) value to convert (as a string of hex bytes),
#         1) number of columns in grid
sub PrintAFPointsGrid($$)
{
    my ($val, $ncol) = @_;
    my ($i, $j, @points);
    $val =~ tr/ //d;    # remove spaces from hex string
    my @dat = unpack 'C*', pack 'H*', $val; # convert to array of bytes
    # loop through all bytes to find active AF points
    for ($i=0; $i<@dat; ++$i) {
        next unless $dat[$i];
        for ($j=0; $j<8; ++$j) {
            next unless $dat[$i] & (1 << $j);
            my $point = GetAFPointGrid($i*8 + $j, $ncol);
            push @points, $point if defined $point;
        }
    }
    return '(none)' unless @points;
    return join ',', @points;   # return as comma-separated string
}

#------------------------------------------------------------------------------
# Inverse print conversion for AF points
# Inputs: 0) AF point string, 1) number of columns, 2) size of data
# Returns: AF point data as a string of hex bytes
sub PrintAFPointsGridInv($$$)
{
    my ($val, $ncol, $size) = @_;
    my @points = ($val =~ /[A-Za-z]\d+/g);
    my @dat = (0) x $size;
    foreach (@points) {
        my $n = GetAFPointGrid($_, $ncol, 1);
        next unless defined $n;
        my $byte = int($n / 8);
        next if $byte > $size;
        $dat[$byte] |= (1 << ($n - $byte * 8));
    }
    return join(" ", unpack("H2"x$size, pack('C*', @dat)));
}

#------------------------------------------------------------------------------
# Print PictureControl value
# Inputs: 0) value (with 0x80 subtracted),
#         1) 'Normal' (0 value) string (default 'Normal')
#         2) format string for numbers (default '%+d'), 3) v2 divisor
# Returns: PrintConv value
sub PrintPC($;$$$)
{
    my ($val, $norm, $fmt, $div) = @_;
    return $norm || 'Normal' if $val == 0;
    return 'n/a'             if $val == 0x7f;
    return 'Auto'            if $val == -128;
    # -127 = custom curve created in Camera Control Pro (show as "User" by D3) - ref 28
    return 'User'            if $val == -127; #28
    return sprintf($fmt || '%+d', $val / ($div || 1));
}

#------------------------------------------------------------------------------
# Inverse of PrintPC
# Inputs: 0) PrintConv value (after subracting 0x80 from raw value), 1) v2 divisor
# Returns: unconverted value
# Notes: raw values: 0=Auto, 1=User, 0xff=n/a, ... 0x7f=-1, 0x80=0, 0x81=1, ...
sub PrintPCInv($;$)
{
    my ($val, $div) = @_;
    return $val * ($div || 1) if $val =~ /^[-+]?\d+(\.\d+)?$/;
    return 0x7f if $val =~ /n\/a/i;
    return -128 if $val =~ /auto/i;
    return -127 if $val =~ /user/i; #28
    return 0;
}

#------------------------------------------------------------------------------
# Convert unknown LensID values
# Inputs: 0) value, 1) flag for inverse conversion, 2) PrintConv hash ref
sub LensIDConv($$$)
{
    my ($val, $inv, $conv) = @_;
    return undef if $inv;
    # multiple lenses with the same LensID are distinguished by decimal values
    if ($$conv{"$val.1"}) {
        my ($i, @vals, @user);
        for ($i=1; ; ++$i) {
            my $lens = $$conv{"$val.$i"} or last;
            if ($Image::ExifTool::userLens{$lens}) {
                push @user, $lens;
            } else {
                push @vals, $lens;
            }
        }
        return join(' or ', @user) if @user;
        return join(' or ', @vals);
    }
    # Sigma has been changing the LensID on some new lenses
    # and with some Sigma lenses the LensFStops changes! (argh!)
    my $pat = $val;
    $pat =~ s/^\w+ \w+/.. ../;
    my @ids = sort grep /^$pat$/, keys %$conv;
    if (@ids) {
        # first try different LensFStops (2nd value)
        ($pat = $val) =~ s/ \w+/ ../;
        my @good = grep /^$pat$/, @ids;
        return $$conv{$good[0]} if @good;
        # then try different LensType (1st value)
        ($pat = $val) =~ s/^\w+/../;
        @good = grep /^$pat$/, @ids;
        return "Unknown ($val) $$conv{$good[0]} ?" if @good;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Clean up formatting of string values
# Inputs: 0) string value
# Returns: formatted string value
# - removes trailing spaces and changes case to something more sensible
sub FormatString($)
{
    my $str = shift;
    # limit string length (can be very long for some unknown tags)
    if (length($str) > 60) {
        $str = substr($str,0,55) . "[...]";
    } else {
        $str =~ s/\s+$//;   # remove trailing white space
        # Don't change case of non-words (no vowels)
        if ($str =~ /[AEIOUY]/) {
            # change all letters but the first to lower case,
            # but only in words containing a vowel
            if ($str =~ s/\b([AEIOUY])([A-Z]+)/$1\L$2/g) {
                $str =~ s/\bAf\b/AF/;   # patch for "AF"
                # patch for a number of models that write improper string
                # terminator for ImageStabilization (VR-OFF, VR-ON)
                $str =~ s/  +.$//s;
            }
            if ($str =~ s/\b([A-Z])([A-Z]*[AEIOUY][A-Z]*)/$1\L$2/g) {
                $str =~ s/\bRaw\b/RAW/; # patch for "RAW"
            }
        }
    }
    return $str;
}

#------------------------------------------------------------------------------
# decoding tables from ref 4
my @xlat = (
  [ 0xc1,0xbf,0x6d,0x0d,0x59,0xc5,0x13,0x9d,0x83,0x61,0x6b,0x4f,0xc7,0x7f,0x3d,0x3d,
    0x53,0x59,0xe3,0xc7,0xe9,0x2f,0x95,0xa7,0x95,0x1f,0xdf,0x7f,0x2b,0x29,0xc7,0x0d,
    0xdf,0x07,0xef,0x71,0x89,0x3d,0x13,0x3d,0x3b,0x13,0xfb,0x0d,0x89,0xc1,0x65,0x1f,
    0xb3,0x0d,0x6b,0x29,0xe3,0xfb,0xef,0xa3,0x6b,0x47,0x7f,0x95,0x35,0xa7,0x47,0x4f,
    0xc7,0xf1,0x59,0x95,0x35,0x11,0x29,0x61,0xf1,0x3d,0xb3,0x2b,0x0d,0x43,0x89,0xc1,
    0x9d,0x9d,0x89,0x65,0xf1,0xe9,0xdf,0xbf,0x3d,0x7f,0x53,0x97,0xe5,0xe9,0x95,0x17,
    0x1d,0x3d,0x8b,0xfb,0xc7,0xe3,0x67,0xa7,0x07,0xf1,0x71,0xa7,0x53,0xb5,0x29,0x89,
    0xe5,0x2b,0xa7,0x17,0x29,0xe9,0x4f,0xc5,0x65,0x6d,0x6b,0xef,0x0d,0x89,0x49,0x2f,
    0xb3,0x43,0x53,0x65,0x1d,0x49,0xa3,0x13,0x89,0x59,0xef,0x6b,0xef,0x65,0x1d,0x0b,
    0x59,0x13,0xe3,0x4f,0x9d,0xb3,0x29,0x43,0x2b,0x07,0x1d,0x95,0x59,0x59,0x47,0xfb,
    0xe5,0xe9,0x61,0x47,0x2f,0x35,0x7f,0x17,0x7f,0xef,0x7f,0x95,0x95,0x71,0xd3,0xa3,
    0x0b,0x71,0xa3,0xad,0x0b,0x3b,0xb5,0xfb,0xa3,0xbf,0x4f,0x83,0x1d,0xad,0xe9,0x2f,
    0x71,0x65,0xa3,0xe5,0x07,0x35,0x3d,0x0d,0xb5,0xe9,0xe5,0x47,0x3b,0x9d,0xef,0x35,
    0xa3,0xbf,0xb3,0xdf,0x53,0xd3,0x97,0x53,0x49,0x71,0x07,0x35,0x61,0x71,0x2f,0x43,
    0x2f,0x11,0xdf,0x17,0x97,0xfb,0x95,0x3b,0x7f,0x6b,0xd3,0x25,0xbf,0xad,0xc7,0xc5,
    0xc5,0xb5,0x8b,0xef,0x2f,0xd3,0x07,0x6b,0x25,0x49,0x95,0x25,0x49,0x6d,0x71,0xc7 ],
  [ 0xa7,0xbc,0xc9,0xad,0x91,0xdf,0x85,0xe5,0xd4,0x78,0xd5,0x17,0x46,0x7c,0x29,0x4c,
    0x4d,0x03,0xe9,0x25,0x68,0x11,0x86,0xb3,0xbd,0xf7,0x6f,0x61,0x22,0xa2,0x26,0x34,
    0x2a,0xbe,0x1e,0x46,0x14,0x68,0x9d,0x44,0x18,0xc2,0x40,0xf4,0x7e,0x5f,0x1b,0xad,
    0x0b,0x94,0xb6,0x67,0xb4,0x0b,0xe1,0xea,0x95,0x9c,0x66,0xdc,0xe7,0x5d,0x6c,0x05,
    0xda,0xd5,0xdf,0x7a,0xef,0xf6,0xdb,0x1f,0x82,0x4c,0xc0,0x68,0x47,0xa1,0xbd,0xee,
    0x39,0x50,0x56,0x4a,0xdd,0xdf,0xa5,0xf8,0xc6,0xda,0xca,0x90,0xca,0x01,0x42,0x9d,
    0x8b,0x0c,0x73,0x43,0x75,0x05,0x94,0xde,0x24,0xb3,0x80,0x34,0xe5,0x2c,0xdc,0x9b,
    0x3f,0xca,0x33,0x45,0xd0,0xdb,0x5f,0xf5,0x52,0xc3,0x21,0xda,0xe2,0x22,0x72,0x6b,
    0x3e,0xd0,0x5b,0xa8,0x87,0x8c,0x06,0x5d,0x0f,0xdd,0x09,0x19,0x93,0xd0,0xb9,0xfc,
    0x8b,0x0f,0x84,0x60,0x33,0x1c,0x9b,0x45,0xf1,0xf0,0xa3,0x94,0x3a,0x12,0x77,0x33,
    0x4d,0x44,0x78,0x28,0x3c,0x9e,0xfd,0x65,0x57,0x16,0x94,0x6b,0xfb,0x59,0xd0,0xc8,
    0x22,0x36,0xdb,0xd2,0x63,0x98,0x43,0xa1,0x04,0x87,0x86,0xf7,0xa6,0x26,0xbb,0xd6,
    0x59,0x4d,0xbf,0x6a,0x2e,0xaa,0x2b,0xef,0xe6,0x78,0xb6,0x4e,0xe0,0x2f,0xdc,0x7c,
    0xbe,0x57,0x19,0x32,0x7e,0x2a,0xd0,0xb8,0xba,0x29,0x00,0x3c,0x52,0x7d,0xa8,0x49,
    0x3b,0x2d,0xeb,0x25,0x49,0xfa,0xa3,0xaa,0x39,0xa7,0xc5,0xa7,0x50,0x11,0x36,0xfb,
    0xc6,0x67,0x4a,0xf5,0xa5,0x12,0x65,0x7e,0xb0,0xdf,0xaf,0x4e,0xb3,0x61,0x7f,0x2f ]
);

# Decrypt Nikon data block (ref 4)
# Inputs: 0) reference to data block, 1) serial number key, 2) shutter count key
#         4) optional start offset (default 0)
#         5) optional number of bytes to decode (default to the end of the data)
# Returns: data block with specified data decrypted
sub Decrypt($$$;$$)
{
    my ($dataPt, $serial, $count, $start, $len) = @_;
    my ($i, $dat);

    $start or $start = 0;
    my $maxLen = length($$dataPt) - $start;
    $len = $maxLen if not defined $len or $len > $maxLen;
    return $$dataPt if $len <= 0;
    my $key = 0;
    for ($i=0; $i<4; ++$i) {
        $key ^= ($count >> ($i*8)) & 0xff;
    }
    my $ci = $xlat[0][$serial & 0xff];
    my $cj = $xlat[1][$key];
    my $ck = 0x60;
    my @data = unpack("x${start}C$len", $$dataPt);
    foreach $dat (@data) {
        $cj = ($cj + $ci * $ck) & 0xff;
        $ck = ($ck + 1) & 0xff;
        $dat ^= $cj;
    }
    my $end = $start + $len;
    my $pre = $start ? substr($$dataPt, 0, $start) : '';
    my $post = $end < length($$dataPt) ? substr($$dataPt, $end) : '';
    return $pre . pack('C*',@data) . $post;
}

#------------------------------------------------------------------------------
# Get serial number for use as a decryption key
# Inputs: 0) ExifTool object ref, 1) serial number string
# Returns: serial key integer or undef if no serial number provided
sub SerialKey($$)
{
    my ($et, $serial) = @_;
    # use serial number as key if integral
    return $serial if not defined $serial or $serial =~ /^\d+$/;
    return 0x22 if $$et{Model} =~ /\bD50$/; # D50 (ref 8)
    return 0x60; # D200 (ref 10), D40X (ref PH), etc
}

#------------------------------------------------------------------------------
# Read Nikon NCTG tags in MOV videos
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNikonMOV($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $pos = $$dirInfo{DirStart};
    my $end = $pos + $$dirInfo{DirLen};
    $et->VerboseDir($$dirInfo{DirName}, 0, $$dirInfo{DirLen});
    while ($pos + 8 < $end) {
        my $tag = Get32u($dataPt, $pos);
        my $fmt = Get16u($dataPt, $pos + 4); # (same format code as EXIF)
        my $count = Get16u($dataPt, $pos + 6);
        $pos += 8;
        my $fmtStr = $Image::ExifTool::Exif::formatName[$fmt];
        unless ($fmtStr) {
            $et->Warn(sprintf("Unknown format ($fmt) for $$dirInfo{DirName} tag 0x%x",$tag));
            last;
        }
        my $size = $count * $Image::ExifTool::Exif::formatSize[$fmt];
        if ($pos + $size > $end) {
            $et->Warn(sprintf("Truncated data for $$dirInfo{DirName} tag 0x%x",$tag));
            last;
        }
        my $rational;
        my $val = ReadValue($dataPt, $pos, $fmtStr, $count, $size, \$rational);
        my $key = $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Format  => $fmtStr,
            Start   => $pos,
            Size    => $size,
        );
        $$et{RATIONAL}{$key} = $rational if $rational and $key;
        $pos += $size;  # is this padded to an even offset????
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read/Write Nikon Encrypted data block
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success when reading, or new directory when writing (IsWriting set)
sub ProcessNikonEncrypted($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access
    my $serial = $$et{NikonSerialKey};
    my $count = $$et{NikonCountKey};
    unless (defined $serial and defined $count and $serial =~ /^\d+$/ and $count =~ /^\d+$/) {
        if (defined $serial or defined $count) {
            my $msg;
            if (defined $serial and defined $count) {
                $msg = $serial =~ /^\d+$/ ? 'invalid ShutterCount' : 'invalid SerialNumber';
            } else {
                $msg = defined $serial ? 'no ShutterCount' : 'no SerialNumber';
            }
            $et->Warn("Can't decrypt Nikon information ($msg key)");
        }
        delete $$et{NikonSerialKey};
        delete $$et{NikonCountKey};
        return 0;
    }
    my $verbose = $$dirInfo{IsWriting} ? 0 : $et->Options('Verbose');
    my $tagInfo = $$dirInfo{TagInfo};
    my $dirStart = $$dirInfo{DirStart};
    my $data = substr(${$$dirInfo{DataPt}}, $dirStart, $$dirInfo{DirLen});

    my ($start, $len, $more, $offset, $byteOrder, $recrypt, $newSerial, $newCount);

    # must re-encrypt when writing if serial number or shutter count changes
    if ($$dirInfo{IsWriting}) {
        if ($$et{NewNikonSerialKey}) {
            $newSerial = $$et{NewNikonSerialKey};
            $recrypt = 1;
        }
        if ($$et{NewNikonCountKey}) {
            $newCount = $$et{NewNikonCountKey};
            $recrypt = 1;
        }
    }
    if ($tagInfo and $$tagInfo{SubDirectory}) {
        $start = $$tagInfo{SubDirectory}{DecryptStart};
        # may decrypt only part of the information to save time
        if ($verbose < 3 and $et->Options('Unknown') < 2 and not $recrypt) {
            $len = $$tagInfo{SubDirectory}{DecryptLen};
            $more = $$tagInfo{SubDirectory}{DecryptMore};
        }
        $offset = $$tagInfo{SubDirectory}{DirOffset};
        $byteOrder = $$tagInfo{SubDirectory}{ByteOrder};
    }
    $start or $start = 0;
    if (defined $offset) {
        # offset, if specified, is relative to start of encrypted data
        $offset += $start;
    } else {
        $offset = 0;
    }
    my $maxLen = length($data) - $start;
    # decrypt all the data unless DecryptLen is given
    unless ($len and $len < $maxLen) {
        $len = $maxLen;
        undef $more;    # (can't decrypt more than this)
    }

    $data = Decrypt(\$data, $serial, $count, $start, $len);

    # set appropriate byte ordering before evaluating DecryptMore
    my $oldOrder = GetByteOrder();
    SetByteOrder($byteOrder) if $byteOrder;

    if ($more) {
        #### eval DecryptMore ($data)
        my $moreLen = eval $more;
        $moreLen = $maxLen if $moreLen > $maxLen;
        # re-decrypt with new length
        if ($len < $moreLen) {
            $len = $moreLen;
            $data = substr(${$$dirInfo{DataPt}}, $dirStart, $$dirInfo{DirLen});
            $data = Decrypt(\$data, $serial, $count, $start, $len);
        }
    }
    if ($verbose > 2) {
        $et->VerboseDir("Decrypted $$tagInfo{Name}");
        $et->VerboseDump(\$data,
            Prefix  => $$et{INDENT} . '  ',
            # (remove this because it is useful to have decrypted offsets start at 0)
            #DataPos => $dirStart + $$dirInfo{DataPos} + ($$dirInfo{Base} || 0),
        );
    }
    # process the decrypted information
    my %subdirInfo = (
        DataPt   => \$data,
        DirStart => $offset,
        DirLen   => length($data) - $offset,
        DirName  => $$dirInfo{DirName},
        DataPos  => $$dirInfo{DataPos} + $dirStart,
        Base     => $$dirInfo{Base},
    );
    my $rtnVal;
    if ($$dirInfo{IsWriting}) {
        my $changed = $$et{CHANGED};
        $rtnVal = $et->WriteBinaryData(\%subdirInfo, $tagTablePtr);
        # must re-encrypt if serial number or shutter count changes
        if ($recrypt) {
            $serial = $newSerial if defined $newSerial;
            $count = $newCount if defined $newCount;
            ++$$et{CHANGED};
        }
        if ($changed == $$et{CHANGED}) {
            undef $rtnVal;  # nothing changed so use original data
        } else {
            # add back any un-encrypted data at start
            $rtnVal = substr($data, 0, $offset) . $rtnVal if $offset;
            # re-encrypt data (symmetrical algorithm)
            $rtnVal = Decrypt(\$rtnVal, $serial, $count, $start, $len);
        }
    } else {
        $rtnVal = $et->ProcessBinaryData(\%subdirInfo, $tagTablePtr);
    }
    SetByteOrder($oldOrder);
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Pre-scan EXIF directory to extract specific tags
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) required tagID hash ref
# Returns: 1 if directory was scanned successfully
sub PrescanExif($$$)
{
    my ($et, $dirInfo, $tagHash) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dataLen = $$dirInfo{DataLen};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $base = $$dirInfo{Base} || 0;
    my $raf = $$dirInfo{RAF};
    my ($index, $numEntries, $data, $buff);

    # get number of entries in IFD
    if ($dirStart >= 0 and $dirStart <= $dataLen-2) {
        $numEntries = Get16u($dataPt, $dirStart);
        # reset $numEntries to read from file if necessary
        undef $numEntries if $dirStart + 2 + 12 * $numEntries > $dataLen;
    }
    # read IFD from file if necessary
    unless ($numEntries) {
        $raf or return 0;
        $dataPos += $dirStart;  # read data from the start of the directory
        $raf->Seek($dataPos + $base, 0) and $raf->Read($data, 2) == 2 or return 0;
        $numEntries = Get16u(\$data, 0);
        my $len = 12 * $numEntries;
        $raf->Read($buff, $len) == $len or return 0;
        $data .= $buff;
        # update variables for the newly loaded IFD (already updated dataPos)
        $dataPt = \$data;
        $dataLen = length $data;
        $dirStart = 0;
    }
    # loop through necessary IFD entries
    my ($lastTag) = sort { $b <=> $a } keys %$tagHash; # (reverse sort)
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        last if $tagID > $lastTag;  # (assuming tags are in order)
        next unless exists $$tagHash{$tagID};   # only extract required tags
        my $format = Get16u($dataPt, $entry+2);
        next if $format < 1 or $format > 13;
        my $count = Get32u($dataPt, $entry+4);
        my $size = $count * $Image::ExifTool::Exif::formatSize[$format];
        my $formatStr = $Image::ExifTool::Exif::formatName[$format];
        my $valuePtr = $entry + 8;      # pointer to value within $$dataPt
        if ($size > 4) {
            next if $size > 0x1000000;  # set a reasonable limit on data size (16MB)
            $valuePtr = Get32u($dataPt, $valuePtr);
            # convert offset to pointer in $$dataPt
            # (don't yet handle EntryBased or FixOffsets)
            $valuePtr -= $dataPos;
            if ($valuePtr < 0 or $valuePtr+$size > $dataLen) {
                next unless $raf and $raf->Seek($base + $valuePtr + $dataPos,0) and
                                     $raf->Read($buff,$size) == $size;
                $$tagHash{$tagID} = ReadValue(\$buff,0,$formatStr,$count,$size);
                next;
            }
        }
        $$tagHash{$tagID} = ReadValue($dataPt,$valuePtr,$formatStr,$count,$size);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Nikon Capture history data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNikonCaptureEditVersions($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    require Image::ExifTool::NikonCapture;
    return Image::ExifTool::NikonCapture::ProcessNikonCaptureEditVersions($et, $dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Process Nikon Capture Offsets IFD (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: This isn't a normal IFD, but is close...
sub ProcessNikonCaptureOffsets($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $success = 0;
    return 0 unless $dirLen > 2;
    my $count = Get16u($dataPt, $dirStart);
    return 0 unless $count and $count * 12 + 2 <= $dirLen;
    if ($et->Options('Verbose')) {
        $et->VerboseDir('NikonCaptureOffsets', $count);
    }
    my $index;
    for ($index=0; $index<$count; ++$index) {
        my $pos = $dirStart + 12 * $index + 2;
        my $tagID = Get32u($dataPt, $pos);
        my $value = Get32u($dataPt, $pos + 4);
        $et->HandleTag($tagTablePtr, $tagID, $value,
            Index  => $index,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => 12,
        ) and $success = 1;
    }
    return $success;
}

#------------------------------------------------------------------------------
# Read/write Nikon MakerNotes directory
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning when reading
#          or new directory when writing (IsWriting set in dirInfo)
sub ProcessNikon($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access

    # pre-scan IFD to get SerialNumber (0x001d) and ShutterCount (0x00a7) for use in decryption
    my %needTags = ( 0x001d => 0, 0x00a7 => undef );
    PrescanExif($et, $dirInfo, \%needTags);
    $$et{NikonSerialKey} = SerialKey($et, $needTags{0x001d});
    $$et{NikonCountKey} = $needTags{0x00a7};

    # process Nikon makernotes
    my $rtnVal;
    if ($$dirInfo{IsWriting}) {
        # get new decryptino keys if they are being changed
        my $serial = $et->GetNewValue($Image::ExifTool::Nikon::Main{0x001d});
        my $count = $et->GetNewValue($Image::ExifTool::Nikon::Main{0x00a7});
        $$et{NewNikonSerialKey} = SerialKey($et, $serial);
        $$et{NewNikonCountKey} = $count;
        $rtnVal = Image::ExifTool::Exif::WriteExif($et, $dirInfo, $tagTablePtr);
        delete $$et{NewNikonSerialKey};
        delete $$et{NewNikonCountKey};
    } else {
        $rtnVal = Image::ExifTool::Exif::ProcessExif($et, $dirInfo, $tagTablePtr);
    }
    delete $$et{NikonSerialKey};
    delete $$et{NikonCountKey};
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Nikon - Nikon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Nikon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://members.aol.com/khancock/pilot/nbuddy/>

=item L<http://www.rottmerhusen.com/objektives/lensid/thirdparty.html>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_nikon.htm>

=item L<http://www.wohlberg.net/public/software/photo/nstiffexif/>

=item (...plus lots of testing with Best Buy store demos!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Joseph Heled, Thomas Walter, Brian Ristuccia, Danek Duvall, Tom
Christiansen, Robert Rottmerhusen, Werner Kober, Roger Larsson, Jens Duttke,
Gregor Dorlars, Neil Nappe, Alexandre Naaman, Brendt Wohlberg and Warren
Hatch for their help figuring out some Nikon tags, and to everyone who
helped contribute to the LensID list.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nikon Tags>,
L<Image::ExifTool::TagNames/NikonCapture Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
