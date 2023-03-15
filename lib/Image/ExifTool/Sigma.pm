#------------------------------------------------------------------------------
# File:         Sigma.pm
#
# Description:  Sigma/Foveon EXIF maker notes tags
#
# Revisions:    04/06/2004 - P. Harvey Created
#               02/20/2007 - PH added SD14 tags
#               24/06/2010 - PH decode some SD15 tags
#
# References:   1) http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html
#               IB) Iliah Borg private communication (LibRaw)
#               NJ) Niels Kristian Bech Jensen
#               JR) Jos Roost
#------------------------------------------------------------------------------

package Image::ExifTool::Sigma;

use strict;
use vars qw($VERSION %sigmaLensTypes);
use Image::ExifTool::Exif;

$VERSION = '1.34';

# sigma LensType lookup (ref IB)
%sigmaLensTypes = (
    Notes => q{
        Sigma LensType values are hexadecimal numbers stored as a string (without
        the leading "0x").
    },
    # 0x0 => 'Sigma 50mm F2.8 EX Macro', (0x0 used for other lenses too)
    # 0x8 - 18-125mm LENSARANGE@18mm=22-4
    0x10, 'Sigma 50mm F2.8 EX DG MACRO',
    # (0x10 = 16)
    16.1 => 'Sigma 70mm F2.8 EX DG Macro',
    16.2 => 'Sigma 105mm F2.8 EX DG Macro',
    0x16 => 'Sigma 18-50mm F3.5-5.6 DC', #PH
    0x103 => 'Sigma 180mm F3.5 EX IF HSM APO Macro',
    0x104 => 'Sigma 150mm F2.8 EX DG HSM APO Macro',
    0x105 => 'Sigma 180mm F3.5 EX DG HSM APO Macro',
    0x106 => 'Sigma 150mm F2.8 EX DG OS HSM APO Macro',
    0x107 => 'Sigma 180mm F2.8 EX DG OS HSM APO Macro',
    # (0x129 = 297)
    0x129 => 'Sigma Lens (0x129)', #PH
    297.1 => 'Sigma 14mm F2.8 EX Aspherical', #PH
    297.2 => 'Sigma 30mm F1.4',
    # (0x131 = 305)
    0x131 => 'Sigma Lens (0x131)',
    305.1 => 'Sigma 17-70mm F2.8-4.5 DC Macro', #PH
    305.2 => 'Sigma 70-200mm F2.8 APO EX HSM',
    305.3 => 'Sigma 120-300mm F2.8 APO EX IF HSM',
    0x134 => 'Sigma 100-300mm F4 EX DG HSM APO',
    0x135 => 'Sigma 120-300mm F2.8 EX DG HSM APO',
    0x136 => 'Sigma 120-300mm F2.8 EX DG OS HSM APO',
    0x137 => 'Sigma 120-300mm F2.8 DG OS HSM | S',
    0x143 => 'Sigma 600mm F8 Mirror',
    # (0x145 = 325)
    0x145 => 'Sigma Lens (0x145)', #PH
    325.1 => 'Sigma 15-30mm F3.5-4.5 EX DG Aspherical', #PH
    325.2 => 'Sigma 18-50mm F2.8 EX DG', #PH (NC)
    325.3 => 'Sigma 20-40mm F2.8 EX DG', #PH
    0x150 => 'Sigma 30mm F1.4 DC HSM',
    # (0x152 = 338)
    0x152 => 'Sigma Lens (0x152)',
    338.1 => 'Sigma APO 800mm F5.6 EX DG HSM',
    338.2 => 'Sigma 12-24mm F4.5-5.6 EX DG ASP HSM',
    338.3 => 'Sigma 10-20mm F4-5.6 EX DC HSM',
    0x165 => 'Sigma 70-200mm F2.8 EX', # ...but what specific model?:
    # 70-200mm F2.8 EX APO - Original version, minimum focus distance 1.8m (1999)
    # 70-200mm F2.8 EX DG - Adds 'digitally optimized' lens coatings to reduce flare (2005)
    # 70-200mm F2.8 EX DG Macro (HSM) - Minimum focus distance reduced to 1m (2006)
    # 70-200mm F2.8 EX DG Macro HSM II - Improved optical performance (2007)
    0x169 => 'Sigma 18-50mm F2.8 EX DC', #PH (NC)
    0x183 => 'Sigma 500mm F4.5 EX HSM APO',
    0x184 => 'Sigma 500mm F4.5 EX DG HSM APO',
    0x185 => 'Sigma 500mm F4 DG OS HSM | S', #JR (NC; based on product number) (016)
    0x194 => 'Sigma 300mm F2.8 EX HSM APO',
    0x195 => 'Sigma 300mm F2.8 EX DG HSM APO',
    0x200 => 'Sigma 12-24mm F4.5-5.6 EX DG ASP HSM',
    0x201 => 'Sigma 10-20mm F4-5.6 EX DC HSM',
    0x202 => 'Sigma 10-20mm F3.5 EX DC HSM',
    0x203 => 'Sigma 8-16mm F4.5-5.6 DC HSM',
    0x204 => 'Sigma 12-24mm F4.5-5.6 DG HSM II',
    0x205 => 'Sigma 12-24mm F4 DG HSM | A', #JR (NC; based on product number) (016)
    0x210 => 'Sigma 18-35mm F1.8 DC HSM | A',
    0x240 => 'Sigma 135mm F1.8 DG HSM | A', #JR (NC; based on product number) (017)
    0x256 => 'Sigma 105mm F2.8 EX Macro',
    0x257 => 'Sigma 105mm F2.8 EX DG Macro',
    0x258 => 'Sigma 105mm F2.8 EX DG OS HSM Macro',
    0x259 => 'Sigma 105mm F1.4 DG HSM | A', #IB (A018)
    0x270 => 'Sigma 70mm F2.8 EX DG Macro', #NJ (SD1)
    0x271 => 'Sigma 70mm F2.8 DG Macro | A', #IB (A018)
    0x300 => 'Sigma 30mm F1.4 EX DC HSM',
    0x301 => 'Sigma 30mm F1.4 DC HSM | A',
    0x302 => 'Sigma 30mm F1.4 DC DN | C', #JR (DN lenses are only for Sony E or MFT mount)
    0x310 => 'Sigma 50mm F1.4 EX DG HSM',
    0x311 => 'Sigma 50mm F1.4 DG HSM | A',
    0x320 => 'Sigma 85mm F1.4 EX DG HSM',
    0x321 => 'Sigma 85mm F1.4 DG HSM | A', #JR (NC; based on product number) (016)
    0x330 => 'Sigma 30mm F2.8 EX DN',
    0x340 => 'Sigma 35mm F1.4 DG HSM',
    0x345 => 'Sigma 50mm F2.8 EX Macro',
    0x346 => 'Sigma 50mm F2.8 EX DG Macro',
    0x350 => 'Sigma 60mm F2.8 DN | A',
    0x400 => 'Sigma 19mm F2.8 EX DN',
    0x401 => 'Sigma 24mm F1.4 DG HSM | A',
    0x411 => 'Sigma 20mm F1.8 EX DG ASP RF',
    0x412 => 'Sigma 20mm F1.4 DG HSM | A',
    0x432 => 'Sigma 24mm F1.8 EX DG ASP Macro',
    0x440 => 'Sigma 28mm F1.8 EX DG ASP Macro',
    0x450 => 'Sigma 14mm F1.8 DH HSM | A', #JR (NC; based on product number) (017)
    0x461 => 'Sigma 14mm F2.8 EX ASP HSM',
    0x475 => 'Sigma 15mm F2.8 EX Diagonal FishEye',
    0x476 => 'Sigma 15mm F2.8 EX DG Diagonal Fisheye',
    0x477 => 'Sigma 10mm F2.8 EX DC HSM Fisheye',
    0x483 => 'Sigma 8mm F4 EX Circular Fisheye',
    0x484 => 'Sigma 8mm F4 EX DG Circular Fisheye',
    0x485 => 'Sigma 8mm F3.5 EX DG Circular Fisheye',
    0x486 => 'Sigma 4.5mm F2.8 EX DC HSM Circular Fisheye',
    0x504 => 'Sigma 70-300mm F4-5.6 Macro Super', #IB
    0x505 => 'Sigma APO 70-300mm F4-5.6 Macro Super', #IB
    0x506 => 'Sigma 70-300mm F4-5.6 APO Macro Super II',
    0x507 => 'Sigma 70-300mm F4-5.6 DL Macro Super II',
    0x508 => 'Sigma 70-300mm F4-5.6 DG APO Macro',
    0x509 => 'Sigma 70-300mm F4-5.6 DG Macro',
    0x510 => 'Sigma 17-35 F2.8-4 EX DG ASP',
    0x512 => 'Sigma 15-30mm F3.5-4.5 EX DG ASP DF',
    0x513 => 'Sigma 20-40mm F2.8 EX DG',
    0x519 => 'Sigma 17-35 F2.8-4 EX ASP HSM',
    0x520 => 'Sigma 100-300mm F4.5-6.7 DL',
    0x521 => 'Sigma 18-50mm F3.5-5.6 DC Macro',
    0x527 => 'Sigma 100-300mm F4 EX IF HSM',
    0x529 => 'Sigma 120-300mm F2.8 EX HSM IF APO',
    0x545 => 'Sigma 28-70mm F2.8 EX ASP DF', #IB
    0x547 => 'Sigma 24-60mm F2.8 EX DG',
    0x548 => 'Sigma 24-70mm F2.8 EX DG Macro',
    0x549 => 'Sigma 28-70mm F2.8 EX DG',
    0x566 => 'Sigma 70-200mm F2.8 EX IF APO',
    0x567 => 'Sigma 70-200mm F2.8 EX IF HSM APO',
    0x568 => 'Sigma 70-200mm F2.8 EX DG IF HSM APO',
    0x569 => 'Sigma 70-200 F2.8 EX DG HSM APO Macro',
    0x571 => 'Sigma 24-70mm F2.8 IF EX DG HSM',
    0x572 => 'Sigma 70-300mm F4-5.6 DG OS',
    0x576 => 'Sigma 24-70mm F2.8 DG OS HSM | A', #JR (NC; based on product number) (017)
    0x579 => 'Sigma 70-200mm F2.8 EX DG HSM APO Macro', # (also II version)
    0x580 => 'Sigma 18-50mm F2.8 EX DC',
    0x581 => 'Sigma 18-50mm F2.8 EX DC Macro', #PH (SD1)
    0x582 => 'Sigma 18-50mm F2.8 EX DC HSM Macro',
    0x583 => 'Sigma 17-50mm F2.8 EX DC OS HSM', #PH (also SD1 Kit, is this HSM? - PH)
    0x588 => 'Sigma 24-35mm F2 DG HSM | A',
    0x589 => 'Sigma APO 70-200mm F2.8 EX DG OS HSM',
    0x594 => 'Sigma 300-800mm F5.6 EX HSM IF APO',
    0x595 => 'Sigma 300-800mm F5.6 EX DG APO HSM',
    0x597 => 'Sigma 200-500mm F2.8 APO EX DG',
    0x5A8 => 'Sigma 70-300mm F4-5.6 APO DG Macro (Motorized)',
    0x5A9 => 'Sigma 70-300mm F4-5.6 DG Macro (Motorized)',
    0x605 => 'Sigma 24-70mm F3.5-5.6 ASP HF', #IB
    0x633 => 'Sigma 28-70mm F2.8-4 HS',
    0x634 => 'Sigma 28-70mm F2.8-4 DG',
    0x635 => 'Sigma 24-105mm F4 DG OS HSM | A',
    0x644 => 'Sigma 28-80mm F3.5-5.6 ASP HF Macro',
    0x659 => 'Sigma 28-80mm F3.5-5.6 Mini Zoom Macro II ASP',
    0x661 => 'Sigma 28-105mm F2.8-4 IF ASP',
    0x663 => 'Sigma 28-105mm F3.8-5.6 IF UC-III ASP',
    0x664 => 'Sigma 28-105mm F2.8-4 IF DG ASP',
    0x667 => 'Sigma 24-135mm F2.8-4.5 IF ASP',
    0x668 => 'Sigma 17-70mm F2.8-4 DC Macro OS HSM',
    0x669 => 'Sigma 17-70mm F2.8-4.5 DC HSM Macro',
    0x684 => 'Sigma 55-200mm F4-5.6 DC',
    0x686 => 'Sigma 50-200mm F4-5.6 DC OS HSM',
    0x689 => 'Sigma 17-70mm F2.8-4.5 DC Macro',
    0x690 => 'Sigma 50-150mm F2.8 EX DC HSM APO',
    0x691 => 'Sigma 50-150mm F2.8 EX DC APO HSM II',
    0x692 => 'Sigma APO 50-150mm F2.8 EX DC OS HSM',
    0x693 => 'Sigma 50-100mm F1.8 DC HSM | A', #JR (NC; based on product number) (016)
    0x709 => 'Sigma 28-135mm F3.8-5.6 IF ASP Macro',
    0x723 => 'Sigma 135-400mm F4.5-5.6 ASP APO',
    0x725 => 'Sigma 80-400mm F4.5-5.6 EX OS',
    0x726 => 'Sigma 80-400mm F4.5-5.6 EX DG OS APO',
    0x727 => 'Sigma 135-400mm F4.5-5.6 DG ASP APO',
    0x728 => 'Sigma 120-400mm F4.5-5.6 DG APO OS HSM',
    0x729 => 'Sigma 100-400mm F5-6.3 DG OS HSM | C', #JR (017)
    0x730 => 'Sigma 60-600mm F4.5-6.3 DG OS HSM | S', #IB (S018)
    0x733 => 'Sigma 170-500mm F5-6.3 ASP APO',
    0x734 => 'Sigma 170-500mm F5-6.3 DG ASP APO',
    0x735 => 'Sigma 50-500mm F4-6.3 EX RF HSM APO',
    0x736 => 'Sigma 50-500mm F4-6.3 EX DG HSM APO',
    0x737 => 'Sigma 150-500mm F5-6.3 APO DG OS HSM',
    0x738 => 'Sigma 50-500mm F4.5-6.3 APO DG OS HSM',
    0x740 => 'Sigma 150-600mm F5-6.3 DG OS HSM | S',
    0x745 => 'Sigma 150-600mm F5-6.3 DG OS HSM | C',
    0x777 => 'Sigma 18-200mm F3.5-6.3 DC',
    0x77D => 'Sigma 18-200mm F3.5-6.3 DC (Motorized)',
    0x785 => 'Sigma 28-200mm F3.5-5.6 DL ASP IF HZM Macro', #IB
    0x787 => 'Sigma 28-200mm F3.5-5.6 Compact ASP HZ Macro',
    0x789 => 'Sigma 18-125mm F3.5-5.6 DC',
    0x790 => 'Sigma 28-300mm F3.5-6.3 DL ASP IF HZM', #IB
    0x793 => 'Sigma 28-300mm F3.5-6.3 Macro',
    0x794 => 'Sigma 28-200mm F3.5-5.6 DG Compact ASP HZ Macro',
    0x795 => 'Sigma 28-300mm F3.5-6.3 DG Macro',
    0x823 => 'Sigma 1.4X TC EX APO',
    0x824 => 'Sigma 1.4X Teleconverter EX APO DG',
    0x853 => 'Sigma 18-125mm F3.8-5.6 DC OS HSM',
    0x861 => 'Sigma 18-50mm F2.8-4.5 DC OS HSM', #NJ (SD1)
    0x870 => 'Sigma 2.0X Teleconverter TC-2001', #JR
    0x875 => 'Sigma 2.0X TC EX APO',
    0x876 => 'Sigma 2.0X Teleconverter EX APO DG',
    0x879 => 'Sigma 1.4X Teleconverter TC-1401', #JR
    0x880 => 'Sigma 18-250mm F3.5-6.3 DC OS HSM',
    0x882 => 'Sigma 18-200mm F3.5-6.3 II DC OS HSM',
    0x883 => 'Sigma 18-250mm F3.5-6.3 DC Macro OS HSM',
    0x884 => 'Sigma 17-70mm F2.8-4 DC OS HSM Macro | C',
    0x885 => 'Sigma 18-200mm F3.5-6.3 DC OS HSM Macro | C',
    0x886 => 'Sigma 18-300mm F3.5-6.3 DC OS HSM Macro | C',
    0x888 => 'Sigma 18-200mm F3.5-6.3 DC OS',
    0x890 => 'Sigma Mount Converter MC-11', #JR
    0x929 => 'Sigma 19mm F2.8 DN | A',
    0x929 => 'Sigma 30mm F2.8 DN | A',
    0x929 => 'Sigma 60mm F2.8 DN | A',
    0x1003 => 'Sigma 19mm F2.8', #PH (DP1 Merrill kit)
    0x1004 => 'Sigma 30mm F2.8', #PH (DP2 Merrill kit)
    0x1005 => 'Sigma 50mm F2.8 Macro', #PH (DP3 Merrill kit)
    0x1006 => 'Sigma 19mm F2.8', #NJ (DP1 Quattro kit)
    0x1007 => 'Sigma 30mm F2.8', #PH (DP2 Quattro kit)
    0x1008 => 'Sigma 50mm F2.8 Macro', #NJ (DP3 Quattro kit)
    0x1009 => 'Sigma 14mm F4', #NJ (DP0 Quattro kit)
    # L-mount lenses?:
    0x4001 => 'Lumix S 24-105mm F4 Macro OIS (S-R24105)', #IB
    0x4002 => 'Lumix S 70-200mm F4 OIS (S-R70200)', #IB
    0x4003 => 'Lumix S 50mm F1.4 (S-X50)', #IB
    0x4006 => 'Lumix S 24-70mm F2.8 (S-E2470)', #IB
    0x4007 => 'Lumix S 16-35mm F4 (S-R1635)', #IB
    0x4008 => 'Lumix S 70-200mm F2.8 OIS (S-E70200)', #IB
    0x4010 => 'Lumix S 35mm F1.8 (S-S35)', #IB
    0x4011 => 'LUMIX S 18mm F1.8 (S-S18)', #IB
    0x400b => 'Lumix S 20-60mm F3.5-5.6 (S-R2060)', #IB
    0x400c => 'Lumix S 85mm F1.8 (S-S85)', #IB
    0x400d => 'Lumix S 70-300 F4.5-5.6 Macro OIS (S-R70300)', #IB
    0x400f => 'Lumix S 24mm F1.8 (S-S24)', #IB
    0x6001 => 'Sigma 150-600mm F5-6.3 DG OS HSM | S', #PH (NC, fp)
    0x6003 => 'Sigma 45mm F2.8 DG DN | C', #PH (NC, fp)
    0x6005 => 'Sigma 14-24mm F2.8 DG DN | A', #IB
    0x6006 => 'Sigma 50mm F1.4 DG HSM | A', #IB (014)
    0x6011 => 'Sigma 24-70mm F2.8 DG DN | A', #IB
    0x6012 => 'Sigma 100-400mm F5-6.3 DG DN OS | C', #IB
    0x6013 => 'Sigma 100-400mm F5-6.3 DG DN OS | C + TC-1411', #IB
    0x6015 => 'Sigma 85mm F1.4 DG DN | A', #IB
    0x6017 => 'Sigma 65mm F2 DG DN | C', #IB
    0x6018 => 'Sigma 35mm F2 DG DN | C', #IB
    0x601a => 'Sigma 28-70mm F2.8 DG DN | C', #IB
    0x601b => 'Sigma 150-600mm F5-6.3 DG DN OS | S', #IB
    0x6020 => 'Sigma 35mm F1.4 DG DN | A', #IB
    0x6021 => 'Sigma 90mm F2.8 DG DN | C', #IB
    0x6023 => 'Sigma 20mm F2 DG DN | C', #IB
    0x6025 => 'Sigma 20mm F1.4 DG DN | A', #IB
    0x6026 => 'Sigma 24mm F1.4 DG DN | A', #IB
    0x602c => "Sigma 50mm F1.4 DG DN | A (2023)", #IB
    0x8005 => 'Sigma 35mm F1.4 DG HSM | A', #PH (012)
    0x8009 => 'Sigma 18-35mm F1.8 DC HSM | A', #PH
    0x8900 => 'Sigma 70-300mm F4-5.6 DG OS', #PH (SD15)
    0xA100 => 'Sigma 24-70mm F2.8 DG Macro', #PH (SD15)
    # 'FFFF' - seen this for a 28-70mm F2.8 lens - PH
);

%Image::ExifTool::Sigma::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 'string',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        These tags are written by Sigma/Foveon cameras.  In the early days Sigma was
        a class leader by releasing their maker note specification to the public,
        but since then they have deviated from this standard and newer camera models
        are less than consistent about their metadata formats.
    },
    0x0002 => 'SerialNumber',
    0x0003 => 'DriveMode',
    0x0004 => 'ResolutionMode',
    0x0005 => 'AFMode',
    0x0006 => 'FocusSetting',
    0x0007 => 'WhiteBalance',
    0x0008 => {
        Name => 'ExposureMode',
        PrintConv => { #PH
            A => 'Aperture-priority AE',
            M => 'Manual',
            P => 'Program AE',
            S => 'Shutter speed priority AE',
        },
    },
    0x0009 => {
        Name => 'MeteringMode',
        PrintConv => { #PH
            A => 'Average',
            C => 'Center-weighted average',
            8 => 'Multi-segment',
        },
    },
    0x000a => 'LensFocalRange',
    0x000b => 'ColorSpace',
    # SIGMA PhotoPro writes these tags as strings, but some cameras (at least) write them as rational
    0x000c => [
        {
            Name => 'ExposureCompensation',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Expo:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Expo:%+.1f",$val) : undef',
        },
        { #PH
            Name => 'ExposureAdjust',
            Writable => 'rational64s',
            Unknown => 1,
        },
    ],
    0x000d => [
        {
            Name => 'Contrast',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Cont:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Cont:%+.1f",$val) : undef',
        },
        { #PH
            Name => 'Contrast',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x000e => [
        {
            Name => 'Shadow',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Shad:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Shad:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Shadow',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x000f => [
        {
            Name => 'Highlight',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/High:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("High:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Highlight',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x0010 => [
        {
            Name => 'Saturation',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Satu:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Satu:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Saturation',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x0011 => [
        {
            Name => 'Sharpness',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Shar:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Shar:%+.1f",$val) : undef',
        },
        { #PH (may be incorrect for the SD1)
            Name => 'Sharpness',
            Writable => 'rational64s',
            Priority => 0,
        },
    ],
    0x0012 => [
        {
            Name => 'X3FillLight',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Fill:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Fill:%+.1f",$val) : undef',
        },
        { #PH
            Name => 'X3FillLight',
            Writable => 'rational64s',
        },
    ],
    0x0014 => [
        {
            Name => 'ColorAdjustment',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/CC:\s*//, $val',
            ValueConvInv => 'IsInt($val) ? "CC:$val" : undef',
        },
        { #PH
            Name => 'ColorAdjustment',
            Writable => 'rational64s',
            Count => 3,
        },
    ],
    0x0015 => 'AdjustmentMode',
    0x0016 => {
        Name => 'Quality',
        ValueConv => '$val =~ s/Qual:\s*//, $val',
        ValueConvInv => 'IsInt($val) ? "Qual:$val" : undef',
    },
    0x0017 => 'Firmware',
    0x0018 => {
        Name => 'Software',
        Priority => 0,
    },
    0x0019 => 'AutoBracket',
    0x001a => [ #PH
        {
            Name => 'PreviewImageStart',
            Condition => '$format eq "int32u"',
            Notes => q{
                Sigma Photo Pro writes ChrominanceNoiseReduction here, but various
                models use this for PreviewImageStart
            },
            IsOffset => 1,
            OffsetPair => 0x001b,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
        },{ # (written by Sigma Photo Pro)
            Name => 'ChrominanceNoiseReduction',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Chro:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Chro:%+.1f",$val) : undef',
        },
        # the SD1 writes something else here (rational64s, value 0/10)
        # (but we can't test by model because Sigma Photo Pro writes this too)
    ],
    0x001b => [ #PH
        {
            Name => 'PreviewImageLength',
            Condition => '$format eq "int32u"',
            Notes => q{
                Sigma Photo Pro writes LuminanceNoiseReduction here, but various models use
                this for PreviewImageLength
            },
            OffsetPair => 0x001a,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
        },{ # (written by Sigma Photo Pro)
            Name => 'LuminanceNoiseReduction',
            Condition => '$format eq "string"',
            ValueConv => '$val =~ s/Luma:\s*//, $val',
            ValueConvInv => 'IsFloat($val) ? sprintf("Luma:%+.1f",$val) : undef',
        },
        # the SD1 writes something else here (rational64s, value 0/10)
    ],
    0x001c => [ #PH
        {
            Name => 'PreviewImageSize',
            Condition => '$$self{MakerNoteSigmaVer} < 3',
            Notes => q{
                PreviewImageStart for the SD1 and Merrill/Quattro models, and
                PreviewImageSize for others
            },
            Writable => 'int16u',
            Count => 2,
            PrintConv => '$val =~ tr/ /x/; $val',
            PrintConvInv => '$val =~ tr/x/ /; $val',
        },{
            Name => 'PreviewImageStart',
            Condition => '$format eq "int32u"',
            IsOffset => 1,
            OffsetPair => 0x001d,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
        },
    ],
    0x001d => [ #PH
        {
            Name => 'MakerNoteVersion',
            Condition => '$$self{MakerNoteSigmaVer} < 3',
            Notes => q{
                PreviewImageLength for the SD1 and Merrill/Quattro models, and
                MakerNoteVersion for others
            },
            Writable => 'undef',
        },{
            Name => 'PreviewImageLength',
            Condition => '$format eq "int32u"',
            OffsetPair => 0x001c,
            DataTag => 'PreviewImage',
            Writable => 'int32u',
            WriteGroup => 'MakerNotes',
            Protected => 2,
        },
    ],
    # 0x001e - int16u: 0, 4, 13 - flash mode for other models?
    0x001e => { #PH
        Name => 'PreviewImageSize',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'only valid for some models',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0x001f => [ #PH
        {
            Name => 'AFPoint', # (NC -- invalid for SD9,SD14?)
            Condition => '$$self{MakerNoteSigmaVer} < 3',
            Notes => q{
                MakerNoteVersion for the SD1 and Merrill/Quattro models, and AFPoint for
                others
            },
            # values: "", "Center", "Center,Center", "Right,Right"
        },{
            Name => 'MakerNoteVersion',
            Writable => 'undef',
        },
    ],
    # 0x0020 - string: " " for most models, or int16u: 4 for the DP3 Merrill
    # 0x0021 - string: " " for most models, or int8u[2]: '3 3' for the DP3 Merrill
    0x0022 => { #PH (NC)
        Name => 'FileFormat',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        # values: "JPG", "JPG-S", "JPG-P", "X3F", "X3F-S"
    },
    # 0x0023 - string: "", 10, 83, 131, 145, 150, 152, 169
    0x0024 => { # (invalid for SD9,SD14?)
        Name => 'Calibration',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
    },
    # 0x0025 - string: "", "0.70", "0.90"
    # 0x0026-2b - int32u: 0
    0x0026 => { #PH (NC)
        Name => 'FileFormat',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        # (also Sigma fp)
    },
    0x0027 => [{ #PH
        Name => 'LensType',
        Condition => '$$self{MakerNoteSigmaVer} >= 3 and $format eq "string"',
        Notes => 'some newer models only',
        ValueConv => '$val =~ /^[0-9a-f]+$/i ? hex($val) : $val',
        # (truncate decimal part and convert hex)
        ValueConvInv => '$val=~s/\.\d+$//;$val=~/^0x/ and $val=hex($val);IsInt($val) ? sprintf("%x",$val) : $val',
        SeparateTable => 'LensType',
        PrintHex => 1,
        PrintConv => \%sigmaLensTypes,
        PrintInt => 1,
    },{ #PH
        Name => 'LensType',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some other models like the fp',
        Writable => 'int16u',
        SeparateTable => 'LensType',
        PrintHex => 1,
        PrintConv => \%sigmaLensTypes,
        PrintInt => 1,
    }],
    0x002a => { #PH
        Name => 'LensFocalRange',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Writable => 'rational64u',
        Count => 2,
        PrintConv => '$val=~s/ / to /; $val',
        PrintConvInv => '$val=~s/to //; $val',
    },
    0x002b => { #PH
        Name => 'LensMaxApertureRange',
        # for most models this gives the max aperture at the long/short focal lengths,
        # but for some models this gives the min/max aperture
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Writable => 'rational64u',
        Count => 2,
        PrintConv => '$val=~s/ / to /; $val',
        PrintConvInv => '$val=~s/to /; $val',
    },
    # 0x002c is rational64u for some models, with a value that may be related to FNumber - PH
    0x002c => { #PH
        Name => 'ColorMode',
        Condition => '$format eq "int32u"',
        Notes => 'not valid for some models',
        Writable => 'int32u',
        # this tag written by Sigma Photo Pro even for cameras that write 'n/a' here
        PrintConv => {
            0 => 'n/a',
            1 => 'Sepia',
            2 => 'B&W',
            3 => 'Standard',
            4 => 'Vivid',
            5 => 'Neutral',
            6 => 'Portrait',
            7 => 'Landscape',
            8 => 'FOV Classic Blue',
        },
    },
    # 0x002d - int32u: 0
    # 0x002e - rational64s: (the negative of FlashExposureComp, but why?)
    # 0x002f - int32u: 0, 1
    0x0030 => [ #PH
        {
            Name => 'LensApertureRange',
            Condition => '$$self{MakerNoteSigmaVer} < 3',
            Notes => q{
                Calibration for the SD1 and Merrill/Quattro models, and LensApertureRange
                for others. Note that LensApertureRange changes with focal length, and some
                models report the maximum aperture here
            },
        },{
            Name => 'Calibration',
        },
    ],
    0x0031 => { #PH
        Name => 'FNumber',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
        Priority => 0,
    },
    0x0032 => { #PH
        Name => 'ExposureTime',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
        Priority => 0,
    },
    0x0033 => { #PH
        Name => 'ExposureTime2',
        Condition => '$$self{Model} !~ / (SD1|SD9|SD15|Merrill|Quattro|fp)$/',
        Notes => 'models other than the SD1, SD9, SD15 and Merrill/Quattro models',
        ValueConv => '$val * 1e-6',
        ValueConvInv => 'int($val * 1e6 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0034 => { #PH
        Name => 'BurstShot',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'int32u',
    },
    # 0x0034 - int32u: 0,1,2,3 or 4
    0x0035 => { #PH
        Name => 'ExposureCompensation',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64s',
        # add a '+' sign to positive values
        PrintConv => '$val and $val =~ s/^(\d)/\+$1/; $val',
        PrintConvInv => '$val',
    },
    # 0x0036 - string: "                    "
    # 0x0037-38 - string: ""
    0x0039 => { #PH (invalid for SD9, SD14?)
        Name => 'SensorTemperature',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        # (string format)
        PrintConv => 'IsInt($val) ? "$val C" : $val',
        PrintConvInv => '$val=~s/ ?C$//; $val',
    },
    0x003a => { #PH
        Name => 'FlashExposureComp',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Writable => 'rational64s',
    },
    0x003b => { #PH (how is this different from other Firmware?)
        Name => 'Firmware',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Priority => 0,
    },
    0x003c => { #PH
        Name => 'WhiteBalance',
        Condition => '$$self{MakerNoteSigmaVer} < 3',
        Notes => 'models other than the SD1 and Merrill/Quattro models',
        Priority => 0,
    },
    0x003d => { #PH (new for SD15 and SD1)
        Name => 'PictureMode',
        Notes => 'same as ColorMode, but "Standard" when ColorMode is Sepia or B&W',
    },
    0x0048 => { #PH
        Name => 'LensApertureRange',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
    },
    0x0049 => { #PH
        Name => 'FNumber',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Writable => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
        Priority => 0,
    },
    0x004a => { #PH
        Name => 'ExposureTime',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Writable => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
        Priority => 0,
    },
    0x004b => [{ #PH
        Name => 'ExposureTime2',
        Condition => '$$self{Model} =~ /^SIGMA (SD1( Merrill)?|DP\d Merrill)$/',
        Notes => 'SD1 and DP Merrill models only',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },{ #PH
        Name => 'ExposureTime2',
        Condition => '$$self{Model} =~ /^SIGMA dp\d Quattro$/i',
        Notes => 'DP Quattro models only',
        ValueConv => '$val / 1000000',
        ValueConvInv => '$val * 1000000',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    }],
    0x004d => { #PH
        Name => 'ExposureCompensation',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Writable => 'rational64s',
        # add a '+' sign to positive values
        PrintConv => '$val and $val =~ s/^(\d)/\+$1/; $val',
        PrintConvInv => '$val',
    },
    # 0x0054 - string: "F20","F23"
    0x0055 => { #PH
        Name => 'SensorTemperature',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        # (string format)
        PrintConv => 'IsInt($val) ? "$val C" : $val',
        PrintConvInv => '$val=~s/ ?C$//; $val',
    },
    0x0056 => { #PH (NC)
        Name => 'FlashExposureComp',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Writable => 'rational64s',
    },
    0x0057 => { #PH (how is this different from other Firmware?)
        Name => 'Firmware2',
        Condition => '$format eq "string"',
        Notes => 'some newer models only',
        Priority => 0,
    },
    0x0058 => { #PH
        Name => 'WhiteBalance',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        Priority => 0,
    },
    0x0059 => { #PH
        Name => 'DigitalFilter',
        Condition => '$$self{MakerNoteSigmaVer} >= 3',
        Notes => 'some newer models only',
        # seen: Standard,Landscape,Monochrome,Neutral,Portrait,Sepia,Vivid
    },
    # 0x005a/b/c - rational64s: 0/10 for the SD1
    0x0084 => { #PH (Quattro models and fp)
        Name => 'Model',
        Description => 'Camera Model Name',
    },
    # 0x0085
    0x0086 => { #PH (Quattro models)
        Name => 'ISO',
        Writable => 'int16u',
    },
    0x0087 => 'ResolutionMode', #PH (Quattro models)
    0x0088 => 'WhiteBalance', #PH (Quattro models)
    0x008c => 'Firmware', #PH (Quattro models)
    0x011f => { #IB (FP DNG images)
        Name => 'CameraCalibration',
        Writable => 'float',
        Count => 9,
    },
    0x0120 => { #IB (FP DNG images)
        Name => 'WBSettings',
        SubDirectory => { TagTable => 'Image::ExifTool::Sigma::WBSettings' },
    },
    0x0121 => { #IB (FP DNG images)
        Name => 'WBSettings2',
        SubDirectory => { TagTable => 'Image::ExifTool::Sigma::WBSettings2' },
    },
);

# WB settings (ref IB)
%Image::ExifTool::Sigma::WBSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0  => { Name => 'WB_RGBLevelsAuto',         Format => 'float[3]' },
    3  => { Name => 'WB_RGBLevelsDaylight',     Format => 'float[3]' },
    6  => { Name => 'WB_RGBLevelsShade',        Format => 'float[3]' },
    9  => { Name => 'WB_RGBLevelsOvercast',     Format => 'float[3]' },
    12 => { Name => 'WB_RGBLevelsIncandescent', Format => 'float[3]' },
    15 => { Name => 'WB_RGBLevelsFluorescent',  Format => 'float[3]' },
    18 => { Name => 'WB_RGBLevelsFlash',        Format => 'float[3]' },
    21 => { Name => 'WB_RGBLevelsCustom1',      Format => 'float[3]' },
    24 => { Name => 'WB_RGBLevelsCustom2',      Format => 'float[3]' },
    27 => { Name => 'WB_RGBLevelsCustom3',      Format => 'float[3]' },
);

# WB settings (ref IB)
%Image::ExifTool::Sigma::WBSettings2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FORMAT => 'float',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0  => { Name => 'WB_RGBLevelsUnknown0', Unknown => 1, Format => 'float[3]' },
    3  => { Name => 'WB_RGBLevelsUnknown1', Unknown => 1, Format => 'float[3]' },
    6  => { Name => 'WB_RGBLevelsUnknown2', Unknown => 1, Format => 'float[3]' },
    9  => { Name => 'WB_RGBLevelsUnknown3', Unknown => 1, Format => 'float[3]' },
    12 => { Name => 'WB_RGBLevelsUnknown4', Unknown => 1, Format => 'float[3]' },
    15 => { Name => 'WB_RGBLevelsUnknown5', Unknown => 1, Format => 'float[3]' },
    18 => { Name => 'WB_RGBLevelsUnknown6', Unknown => 1, Format => 'float[3]' },
    21 => { Name => 'WB_RGBLevelsUnknown7', Unknown => 1, Format => 'float[3]' },
    24 => { Name => 'WB_RGBLevelsUnknown8', Unknown => 1, Format => 'float[3]' },
    27 => { Name => 'WB_RGBLevelsUnknown9', Unknown => 1, Format => 'float[3]' },
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Sigma - Sigma/Foveon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Sigma and Foveon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.x3f.info/technotes/FileDocs/MakerNoteDoc.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Sigma Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
