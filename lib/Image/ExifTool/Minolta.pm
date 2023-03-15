#------------------------------------------------------------------------------
# File:         Minolta.pm
#
# Description:  Minolta EXIF maker notes tags
#
# Revisions:    04/06/2004 - P. Harvey Created
#               09/09/2005 - P. Harvey Added ability to write MRW files
#
# References:   1) http://www.dalibor.cz/minolta/makernote.htm
#               2) Jay Al-Saadi private communication (testing with A2)
#               3) Shingo Noguchi, PhotoXP (http://www.daifukuya.com/photoxp/)
#               5) http://www.cybercom.net/~dcoffin/dcraw/
#               6) Pedro Corte-Real private communication
#               7) ExifTool forum post by bronek (http://www.cpanforum.com/posts/1118)
#               8) http://www.chauveau-central.net/mrw-format/
#               9) CPAN Forum post by 'geve' (http://www.cpanforum.com/threads/2168)
#              10) http://homepage3.nifty.com/kamisaka/makernote/makernote_km.htm
#              11) http://www.dyxum.com/dforum/forum_posts.asp?TID=6371&PN=1 and
#                  http://www.dyxum.com/dAdmin/lenses/MakerNoteList_Public.asp?stro=makr
#                  http://dyxum.com/dforum/forum_posts.asp?TID=23435&PN=2
#              12) http://www.minolta-forum.de/forum/index.php?showtopic=14914
#              13) http://www.mhohner.de/minolta/lenses.php
#              14) Jeffery Small private communication (tests with 7D)
#              15) http://homepage3.nifty.com/kamisaka/makernote/makernote_sony.htm
#              16) Thomas Kassner private communication
#              17) Mladen Sever private communication
#              18) Olaf Ulrich private communication
#              19) Lukasz Stelmach private communication
#              20) Igal Milchtaich private communication (A100 firmware 1.04)
#              21) Jean-Michel Dubois private communication
#              22) http://www.mi-fo.de/forum/index.php?act=attach&type=post&id=6024
#              23) Marcin Krol private communication
#              24) http://cpanforum.com/threads/12291
#              26) https://exiftool.org/forum/index.php/topic,3521.0.html
#              27) https://exiftool.org/forum/index.php/topic,3833.0.html
#              28) Michael Reitinger private communication (RX100)
#              29) https://exiftool.org/forum/index.php/topic,4086.0.html
#              IB) Iliah Borg private communication (LibRaw)
#              JD) Jens Duttke private communication
#              JR) Jos Roost private communication
#              NJ) Niels Kristian Bech Jensen private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Minolta;

use strict;
use vars qw($VERSION %minoltaLensTypes %minoltaTeleconverters %minoltaColorMode
            %sonyColorMode %minoltaSceneMode %afStatusInfo %metabonesID);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '2.88';

# Full list of product codes for Sony-compatible Minolta lenses
# (ref http://www.kb.sony.com/selfservice/documentLink.do?externalId=C1000570)
# NOTE: Unfortunately, these product codes sometimes do not match the first 4
#       digits of the lens ID
# 2578 AF 16mm F2.8 FISH-EYE
# 2579 AF 20mm F2.8
# 2641 AF 20mm F2.8 NEW
# 2566 AF 24mm F2.8
# 2642 AF 24mm F2.8 NEW
# 2596 AF 28mm F2
# 2668 AF 28mm F2 NEW
# 2557 AF 28mm F2.8
# 2591 AF 35mm F1.4 G
# 2666 AF 35mm F1.4 G NEW
# 2597 AF 35mm F2
# 2667 AF 35mm F2 NEW
# 2562 AF 50mm F1.4
# 2662 AF 50mm F1.4 NEW
# 2550 AF 50mm F1.7
# 2613 AF 50mm F1.7 NEW
# 2592 AF 85mm F1.4
# 2629 AF 85mm F1.4 G
# 2677 AF 85mm F1.4 G (D)
# 2689 AF 85mm F1.4 G (D) Limited
# 2598 AF 100mm F2
# 2648 AF 100mm F2.8 SOFT
# 2556 AF 135mm F2.8
# 2656 STF 135mm F2.8 [T4.5]
# 2593 AF APO 20 0mm F2.8
# 2612 High Speed AF APO 200mm F2.8 G
# 2563 AF APO 300mm F2.8
# 2608 High Speed AF APO 300mm F2.8 G
# 2674 AF APO 300mm F2.8 G(D) SSM
# 2640 AF APO 300mm F4 G
# 2651 AF APO 400mm F4.5 G
# 2572 AF REFLEX 500mm F8
# 2565 AF APO 600mm F4
# 2609 High Speed AF APO 600mm F4 G
# 2564 AF MACRO 50mm F2.8
# 2638 AF MACRO 50mm F2.8 NEW
# 2675 AF MACRO 50mm F2.8 (D)
# 2646 AF MACRO 50mm F3.5
# 2581 AF MACRO 100mm F2.8
# 2639 AF MACRO 100mm F2.8 NEW
# 2676 AF MACRO 100mm F2.8 (D)
# 2658 AF APO TE LE MACRO 200mm F4 G
# 2594 AF MACRO ZOOM 1x-3x F1.7-2.8
# 2695 AF 17-35mm F2.8-4 (D)
# 2654 AF 17-35mm F3.5 G
# 2657 AF 20-35mm F3.5-4.5
# 2558 AF 24-50mm F4
# 2632 AF 24-50mm F4 NEW
# 2636 AF 24-85mm F3.5-4.5
# 2660 AF 24-85mm F3.5-4.5 NEW
# 2672 AF 24-105mm F3.5-4.5 (D)
# 2620 AF 28-70mm F2.8 G
# 2696 AF 28-75mm F2.8 (D)
# 2659 AF 28-80mm F3.5-5.6
# 2670 AF 28-80mm F3.5-5.6 II
# 2683 AF 28-80mm F3.5-5.6 (D)
# 2633 AF 28-80mm F4-5.6
# 2552 AF 28-85mm F3.5-4.5
# 2586 AF 28-85mm F3.5-4.5 NEW
# 2692 AF 28-100mm F3.5-5.6 (D)
# 2635 AF 28-105mm F3.5-4.5
# 2661 AF 28-105mm F3.5-4.5 NEW
# 2553 AF 28-135mm F4-4.5
# 2551 AF 35-70mm F4
# 2643 AF 35-70mm F3.5-4.5
# 2652 AF 35-70mm F3.5-4.5 NEW
# 2605 AF 35-80mm F4-5.6
# 2671 AF 35-80mm F4.5-5.6 II
# 2554 AF 35-105mm F3.5-4.5
# 2585 AF 35-105mm F3.5-4.5
# 2682 AF APO 70-200mm F2.8 G (D) SSM
# 2588 AF 70-210mm F4.5-5.6
# 2555 AF 70-210mm F4
# 2634 AF 70-210mm F4.5-5.6 NEW
# 2669 AF 70-210mm F4.5-5.6 II
# 2561 AF 75-300mm F4.5-5.6
# 2649 AF 75-300mm F4.5-5.6 NEW
# 2665 AF 75-300mm F4.5-5.6 II
# 2684 AF 75-300mm F4.5-5.6 (D)
# 2589 AF APO 80-200mm F2.8
# 2628 High-Speed AF APO 80-200mm F2.8 G
# 2604 AF 80-200mm F4.5-5.6
# 2560 AF 100-200mm F4.5
# 2606 AF 100-300mm F4.5-5.6
# 2631 AF APO 100-300mm F4.5-5.6
# 2681 AF APO 100-300mm F4.5-5.6 (D)
# 2644 AF APO 100-400mm F4.5-6.7
# 2618 AF Xi 28-80mm F4-5.6
# 2615 AF Xi 28-105mm F3.5-4.5
# 2624 AF PZ 35-80mm F4-5.6
# 2616 AF Xi 35-200mm F4.5-5.6
# 2619 AF Xi 80-200mm F4.5-5.6
# 2621 AF Xi 100-300mm F4.5-5.6
# 2698 AF DT 11-18mm F4.5-5.6 (D)
# 2697 AF DT 18-70mm F3.5-5.6 (D)
# 2699 AF DT 18-200mm F3.5-6.3 (D)
# 2590 1.4x TELE CONVERTER APO
# 2601 2x TELE CONVERTER APO
# 2610 1.4x TELE CONVERTER APO II
# 2611 2x TELE CONVERTER APO II
# 2687 1.4x TELE CONVERTER APO (D)
# 2688 2x TELE CONVERTER APO (D)

# high bytes in Sony LensID's identifying Metabones adapters and high bytes of Canon LensID's
%metabonesID = (
    # 0xef00 is used by Metabones, Fotodiox, Sigma and Viltrox adapters (JR)
    0xef00 => \ 'Canon EF Adapter',         # with Canon LensID 0x00xx
    0xf000 => 0xef00,                       # with Canon LensID 0x01xx
    0xf100 => 0xef00,                       # with Canon LensID 0x02xx
    0xff00 => 0xef00,                       # with Canon LensID 0x10xx
    0x7700 => \ 'Metabones Speed Booster',  # with Canon LensID 0x00xx
    0x7800 => 0x7700,                       # with Canon LensID 0x01xx
    0x7900 => 0x7700,                       # with Canon LensID 0x02xx
    0x8700 => 0x7700,                       # with Canon LensID 0x10xx
    0xbc00 => \ 'Metabones Speed Booster Ultra', # with Canon LensID 0x00xx
    0xbd00 => 0xbc00,                       # with Canon LensID 0x01xx
    0xbe00 => 0xbc00,                       # with Canon LensID 0x02xx
    0xcc00 => 0xbc00,                       # with Canon LensID 0x10xx
);

# lens ID numbers (ref 3)
# ("New" and "II" appear in brackets if original version also has this LensType)
%minoltaLensTypes = (
    Notes => q{
        "New" or "II" appear in brackets if the original version of the lens has the
        same LensType.  Special logic is employed to identify the attached lens when
        a Metabones Canon EF adapter is used.
    },
    OTHER => sub {
        my ($val, $inv) = @_;
        return undef if $inv;
        my $id = $val & 0xff00;
        # Note: Metabones Smart Adapter firmware versions before 31 kill
        # the high byte for 2-byte Canon LensType values, so the reported lens
        # will be incorrect for these
        my $mb = $metabonesID{$id};
        if ($mb) {
            ref $mb or $id = $mb, $mb = $metabonesID{$id};
            require Image::ExifTool::Canon;
            my $lens = $Image::ExifTool::Canon::canonLensTypes{$val - $id};
            return "$lens + $$mb" if $lens;
        } elsif ($val >= 0x4900) { # test for Sigma MC-11 SA-E adapter with Sigma SA-mount lens
            require Image::ExifTool::Sigma;
            my $lens = $Image::ExifTool::Sigma::sigmaLensTypes{$val - 0x4900};
            return "$lens + MC-11 SA-E" if $lens;
        }
        return undef;
    },
    0 => 'Minolta AF 28-85mm F3.5-4.5 New', # New added (ref 13/18)
    1 => 'Minolta AF 80-200mm F2.8 HS-APO G', # white
    2 => 'Minolta AF 28-70mm F2.8 G',
    3 => 'Minolta AF 28-80mm F4-5.6',
    4 => 'Minolta AF 85mm F1.4G', #exiv2 0.23
    5 => 'Minolta AF 35-70mm F3.5-4.5 [II]', # (original and II, ref 13)
    6 => 'Minolta AF 24-85mm F3.5-4.5 [New]', # (original and New, ref 13)
  # 7 => 'AF 100-400mm F4.5-6.7 (D)', ??
    7 => 'Minolta AF 100-300mm F4.5-5.6 APO [New] or 100-400mm or Sigma Lens',
    7.1 => 'Minolta AF 100-400mm F4.5-6.7 APO', #JD
    7.2 => 'Sigma AF 100-300mm F4 EX DG IF', #JD
    8 => 'Minolta AF 70-210mm F4.5-5.6 [II]', # (original and II, ref 13)
    9 => 'Minolta AF 50mm F3.5 Macro',
    10 => 'Minolta AF 28-105mm F3.5-4.5 [New]', # (original and New, ref 13)
    11 => 'Minolta AF 300mm F4 HS-APO G',
    12 => 'Minolta AF 100mm F2.8 Soft Focus',
    13 => 'Minolta AF 75-300mm F4.5-5.6 (New or II)', # (II and New, ref 13)
    14 => 'Minolta AF 100-400mm F4.5-6.7 APO',
    15 => 'Minolta AF 400mm F4.5 HS-APO G',
    16 => 'Minolta AF 17-35mm F3.5 G',
    17 => 'Minolta AF 20-35mm F3.5-4.5',
    18 => 'Minolta AF 28-80mm F3.5-5.6 II',
    19 => 'Minolta AF 35mm F1.4 G', # G added (ref 18), but not New as per ref 13
    20 => 'Minolta/Sony 135mm F2.8 [T4.5] STF',
    # 20 => 'Sony 135mm F2.8 [T4.5] STF (SAL135F28)', (ref JR)
    22 => 'Minolta AF 35-80mm F4-5.6 II', # II added (ref 13)
    23 => 'Minolta AF 200mm F4 Macro APO G',
    24 => 'Minolta/Sony AF 24-105mm F3.5-4.5 (D) or Sigma or Tamron Lens',
    # 24 => 'Sony 24-105mm F3.5-4.5 (SAL24105)', (ref JR)
    24.1 => 'Sigma 18-50mm F2.8',
    24.2 => 'Sigma 17-70mm F2.8-4.5 DC Macro', # (changed "(D)" to "DC Macro", ref JR)
    24.3 => 'Sigma 20-40mm F2.8 EX DG Aspherical IF', #JD/22
    24.4 => 'Sigma 18-200mm F3.5-6.3 DC', #22
    24.5 => 'Sigma DC 18-125mm F4-5,6 D', #exiv2 0.23
  # 24.6 => 'Tamron SP AF 28-75mm F2.8 XR Di (IF) Macro', #JD
    24.6 => 'Tamron SP AF 28-75mm F2.8 XR Di LD Aspherical [IF] Macro', #NJ (Model A09)
    24.7 => 'Sigma 15-30mm F3.5-4.5 EX DG Aspherical', #JR
    25 => 'Minolta AF 100-300mm F4.5-5.6 APO (D) or Sigma Lens',
    25.1 => 'Sigma 100-300mm F4 EX (APO (D) or D IF)', #JD
    25.2 => 'Sigma 70mm F2.8 EX DG Macro', #JD
    25.3 => 'Sigma 20mm F1.8 EX DG Aspherical RF', #19
    25.4 => 'Sigma 30mm F1.4 EX DC', #21/27
    25.5 => 'Sigma 24mm F1.8 EX DG ASP Macro', #Florian Knorn
    # 25 - also seen for an "old Sigma 50mm Macro" (forum2833)
    27 => 'Minolta AF 85mm F1.4 G (D)', # added (D) (ref 13)
    # 27 => 'Venus Optics Laowa 105mm F2 STF', #IB (NC)
    28 => 'Minolta/Sony AF 100mm F2.8 Macro (D) or Tamron Lens',
    # 28 => 'Sony 100mm F2.8 Macro (SAL100M28)', (ref 18/JR)
    28.1 => 'Tamron SP AF 90mm F2.8 Di Macro', #JD (Model 272E)
    28.2 => 'Tamron SP AF 180mm F3.5 Di LD [IF] Macro', #27 (Model B01) ("SP" moved - ref JR)
    29 => 'Minolta/Sony AF 75-300mm F4.5-5.6 (D)', # Sony added (ref 13)
    # 29 => 'Sony 75-300mm F4.5-5.6 (SAL75300)', (ref JR)
    30 => 'Minolta AF 28-80mm F3.5-5.6 (D) or Sigma Lens',
    30.1 => 'Sigma AF 10-20mm F4-5.6 EX DC', #JD
    30.2 => 'Sigma AF 12-24mm F4.5-5.6 EX DG',
    30.3 => 'Sigma 28-70mm EX DG F2.8', #16
    30.4 => 'Sigma 55-200mm F4-5.6 DC', #JD
    31 => 'Minolta/Sony AF 50mm F2.8 Macro (D) or F3.5',
    # 31 => 'Sony 50mm F2.8 Macro (SAL50M28)', (ref JR)
    31.1 => 'Minolta/Sony AF 50mm F3.5 Macro',
    32 => 'Minolta/Sony AF 300mm F2.8 G or 1.5x Teleconverter', #13/18
    # 32 => 'Minolta AF 300mm F2.8 APO G (D) SSM', (ref 13) ("APO" added - ref JR)
    # 32 => 'Sony 300mm F2.8 G (SAL300F28G)', (ref 18/JR)
    33 => 'Minolta/Sony AF 70-200mm F2.8 G',
    # 33 => 'Sony 70-200mm F2.8 G (SAL70200G)', (ref JR)
    # 33 => 'Minolta AF 70-200mm F2.8 APO G (D) SSM' (ref 13) ("APO" added - ref JR)
    35 => 'Minolta AF 85mm F1.4 G (D) Limited',
    36 => 'Minolta AF 28-100mm F3.5-5.6 (D)',
    38 => 'Minolta AF 17-35mm F2.8-4 (D)', # (Konica Minolta, ref 13)
    39 => 'Minolta AF 28-75mm F2.8 (D)', # (Konica Minolta, ref 13)
    40 => 'Minolta/Sony AF DT 18-70mm F3.5-5.6 (D)', # (Konica Minolta, ref 13)
    # 40 => 'Sony DT 18-70mm F3.5-5.6 (SAL1870)', (ref JR)
    #40.1 => 'Sony AF DT 18-200mm F3.5-6.3', #11 (anomaly? - PH)
    41 => 'Minolta/Sony AF DT 11-18mm F4.5-5.6 (D) or Tamron Lens', # (Konica Minolta, ref 13)
    # 41 => 'Sony DT 11-18mm F4.5-5.6 (SAL1118)', (ref JR)
    41.1 => 'Tamron SP AF 11-18mm F4.5-5.6 Di II LD Aspherical IF', #JD (Model A13)
    42 => 'Minolta/Sony AF DT 18-200mm F3.5-6.3 (D)', # Sony added (ref 13) (Konica Minolta, ref 13)
    # 42 => 'Sony DT 18-200mm F3.5-6.3 (SAL18200)', (ref JR)
    43 => 'Sony 35mm F1.4 G (SAL35F14G)', # changed from Minolta to Sony (ref 13/18/JR) (but ref 11 shows both!)
    44 => 'Sony 50mm F1.4 (SAL50F14)', # changed from Minolta to Sony (ref 13/18/JR)
    45 => 'Carl Zeiss Planar T* 85mm F1.4 ZA (SAL85F14Z)', #JR
    46 => 'Carl Zeiss Vario-Sonnar T* DT 16-80mm F3.5-4.5 ZA (SAL1680Z)', #JR
    47 => 'Carl Zeiss Sonnar T* 135mm F1.8 ZA (SAL135F18Z)', #JR
    48 => 'Carl Zeiss Vario-Sonnar T* 24-70mm F2.8 ZA SSM (SAL2470Z) or Other Lens', #11/JR
    48.1 => 'Carl Zeiss Vario-Sonnar T* 24-70mm F2.8 ZA SSM II (SAL2470Z2)', #JR
    48.2 => 'Tamron SP 24-70mm F2.8 Di USD', #IB (A007) (also with id 204)
    49 => 'Sony DT 55-200mm F4-5.6 (SAL55200)', #JD/JR
    50 => 'Sony DT 18-250mm F3.5-6.3 (SAL18250)', #11/JR
    51 => 'Sony DT 16-105mm F3.5-5.6 (SAL16105)', #11/JR
    #51.1 => 'Sony AF DT 55-200mm F4-5.5', #11 (anomaly? - PH)
    # LensType 52 also seen for Fringer Contax_N to E-mount adapter Ver.31 and Ver.21 (ref JR)
    52 => 'Sony 70-300mm F4.5-5.6 G SSM (SAL70300G) or G SSM II or Tamron Lens', #JD
    52.1 => 'Sony 70-300mm F4.5-5.6 G SSM II (SAL70300G2)', #JR
    52.2 => 'Tamron SP 70-300mm F4-5.6 Di USD', #JR,NJ (Model A005)
    53 => 'Sony 70-400mm F4-5.6 G SSM (SAL70400G)', #17(/w correction by Stephen Bishop)/JR
    54 => 'Carl Zeiss Vario-Sonnar T* 16-35mm F2.8 ZA SSM (SAL1635Z) or ZA SSM II', #17/JR
    54.1 => 'Carl Zeiss Vario-Sonnar T* 16-35mm F2.8 ZA SSM II (SAL1635Z2)', #JR
    55 => 'Sony DT 18-55mm F3.5-5.6 SAM (SAL1855) or SAM II', #PH
    55.1 => 'Sony DT 18-55mm F3.5-5.6 SAM II (SAL18552)', #JR
    56 => 'Sony DT 55-200mm F4-5.6 SAM (SAL55200-2)', #22/JR
    57 => 'Sony DT 50mm F1.8 SAM (SAL50F18) or Tamron Lens or Commlite CM-EF-NEX adapter', #22/JR
    57.1 => 'Tamron SP AF 60mm F2 Di II LD [IF] Macro 1:1', # (Model G005) (ref https://exiftool.org/forum/index.php/topic,3858.0.html)
    57.2 => 'Tamron 18-270mm F3.5-6.3 Di II PZD', #27 (Model B008)
    # (note: the Commlite CM-EF-NEX adapter also appears to give LensType 57, ref JR)
    58 => 'Sony DT 30mm F2.8 Macro SAM (SAL30M28)', #22/JR
    59 => 'Sony 28-75mm F2.8 SAM (SAL2875)', #21/JR
    60 => 'Carl Zeiss Distagon T* 24mm F2 ZA SSM (SAL24F20Z)', #17/JR
    61 => 'Sony 85mm F2.8 SAM (SAL85F28)', #17/JR
    62 => 'Sony DT 35mm F1.8 SAM (SAL35F18)', #PH/JR
    63 => 'Sony DT 16-50mm F2.8 SSM (SAL1650)', #17/JR
    64 => 'Sony 500mm F4 G SSM (SAL500F40G)', #29
    65 => 'Sony DT 18-135mm F3.5-5.6 SAM (SAL18135)', #JR
    66 => 'Sony 300mm F2.8 G SSM II (SAL300F28G2)', #29
    67 => 'Sony 70-200mm F2.8 G SSM II (SAL70200G2)', #JR
    68 => 'Sony DT 55-300mm F4.5-5.6 SAM (SAL55300)', #29
    69 => 'Sony 70-400mm F4-5.6 G SSM II (SAL70400G2)', #JR
    70 => 'Carl Zeiss Planar T* 50mm F1.4 ZA SSM (SAL50F14Z)', #JR
    128 => 'Tamron or Sigma Lens (128)',
    128.1 => 'Tamron AF 18-200mm F3.5-6.3 XR Di II LD Aspherical [IF] Macro', #JR (Model A14)
    # was 128.1 => 'Tamron 18-200mm F3.5-6.3',
    128.2 => 'Tamron AF 28-300mm F3.5-6.3 XR Di LD Aspherical [IF] Macro', #JR (Model A061)
    # was 128.2 => 'Tamron 28-300mm F3.5-6.3',
    # (removed -- probably never existed, ref IB) 'Tamron 80-300mm F3.5-6.3',
    128.3 => 'Tamron AF 28-200mm F3.8-5.6 XR Di Aspherical [IF] Macro', #JD (Model A031)
   # also Tamron AF 28-200mm F3.8-5.6 Aspherical', #IB (Model 71D)
   # and 'Tamron AF 28-200mm F3.8-5.6 LD Aspherical [IF] Super', #IB (Model 171D)
    128.4 => 'Tamron SP AF 17-35mm F2.8-4 Di LD Aspherical IF', #JD (Model A05)
    128.5 => 'Sigma AF 50-150mm F2.8 EX DC APO HSM II', #JD
    128.6 => 'Sigma 10-20mm F3.5 EX DC HSM', #11 (Model 202-205)
    128.7 => 'Sigma 70-200mm F2.8 II EX DG APO MACRO HSM', #24
    128.8 => 'Sigma 10mm F2.8 EX DC HSM Fisheye', #Florian Knorn
    # (yes, '128.10'.  My condolences to typed languages that use this database - PH)
    128.9 => 'Sigma 50mm F1.4 EX DG HSM', #Florian Knorn (Model A014, ref IB)
   '128.10' => 'Sigma 85mm F1.4 EX DG HSM', #27
   '128.11' => 'Sigma 24-70mm F2.8 IF EX DG HSM', #27
   '128.12' => 'Sigma 18-250mm F3.5-6.3 DC OS HSM', #27
   '128.13' => 'Sigma 17-50mm F2.8 EX DC HSM', #Exiv2
   '128.14' => 'Sigma 17-70mm F2.8-4 DC Macro HSM', # (no OS for Sony mount, ref JR) (also C013 Model, ref IB)
   '128.15' => 'Sigma 150mm F2.8 EX DG OS HSM APO Macro', #Marcus Holland-Moritz
   '128.16' => 'Sigma 150-500mm F5-6.3 APO DG OS HSM', #IB
   '128.17' => 'Tamron AF 28-105mm F4-5.6 [IF]', #IB (Model 179D)
   '128.18' => 'Sigma 35mm F1.4 DG HSM', #JR
   '128.19' => 'Sigma 18-35mm F1.8 DC HSM', #JR (Model A013, ref IB)
   '128.20' => 'Sigma 50-500mm F4.5-6.3 APO DG OS HSM', #JR
   '128.21' => 'Sigma 24-105mm F4 DG HSM | A', #JR (013)
   '128.22' => 'Sigma 30mm F1.4', #IB
   '128.23' => 'Sigma 35mm F1.4 DG HSM | A', #IB/JR (012)
   '128.24' => 'Sigma 105mm F2.8 EX DG OS HSM Macro', #IB
   '128.25' => 'Sigma 180mm F2.8 EX DG OS HSM APO Macro', #IB
   '128.26' => 'Sigma 18-300mm F3.5-6.3 DC Macro HSM | C', #IB/JR (014)
   '128.27' => 'Sigma 18-50mm F2.8-4.5 DC HSM', #IB
    129 => 'Tamron Lens (129)',
    129.1 => 'Tamron 200-400mm F5.6 LD', #12 (LD ref 23)
    129.2 => 'Tamron 70-300mm F4-5.6 LD', #12
    131 => 'Tamron 20-40mm F2.7-3.5 SP Aspherical IF', #23 (Model 266D)
    135 => 'Vivitar 28-210mm F3.5-5.6', #16
    136 => 'Tokina EMZ M100 AF 100mm F3.5', #JD
    137 => 'Cosina 70-210mm F2.8-4 AF', #11
    138 => 'Soligor 19-35mm F3.5-4.5', #11
    139 => 'Tokina AF 28-300mm F4-6.3', #IB
    # (the following Cosina 70-300mm lens was also marketed as a Phoenix, Vivitar Series 1, and
    # some sort of 3rd-party marketing as a Voightlander 70-300mm F4.5-5.6 SKOPAR AF, ref IB)
    142 => 'Cosina AF 70-300mm F4.5-5.6 MC', #IB (was 'Voigtlander 70-300mm F4.5-5.6', #JD)
    146 => 'Voigtlander Macro APO-Lanthar 125mm F2.5 SL', #JD
    194 => 'Tamron SP AF 17-50mm F2.8 XR Di II LD Aspherical [IF]', #23 (Model A16)
    202 => 'Tamron SP AF 70-200mm F2.8 Di LD [IF] Macro', #JR (Model A001) (see also 255.7)
    203 => 'Tamron SP 70-200mm F2.8 Di USD', #JR (Model A009)
    204 => 'Tamron SP 24-70mm F2.8 Di USD', #JR (Model A007) (also with id 48)
    212 => 'Tamron 28-300mm F3.5-6.3 Di PZD', #JR (Model A010)
    213 => 'Tamron 16-300mm F3.5-6.3 Di II PZD Macro', #JR (Model B016)
    214 => 'Tamron SP 150-600mm F5-6.3 Di USD', #JR (Model A011)
    215 => 'Tamron SP 15-30mm F2.8 Di USD', #JR (Model A012)
    216 => 'Tamron SP 45mm F1.8 Di USD', #forum8320 (F013)
    217 => 'Tamron SP 35mm F1.8 Di USD', #forum8320 (F012)
    218 => 'Tamron SP 90mm F2.8 Di Macro 1:1 USD (F017)', #JR (Model F017)
    220 => 'Tamron SP 150-600mm F5-6.3 Di USD G2', #forum8846 (Model A022)
    224 => 'Tamron SP 90mm F2.8 Di Macro 1:1 USD (F004)', #JR (Model F004)
    255 => 'Tamron Lens (255)',
    255.1 => 'Tamron SP AF 17-50mm F2.8 XR Di II LD Aspherical', # (Model A16)
    255.2 => 'Tamron AF 18-250mm F3.5-6.3 XR Di II LD', #JD (Model A18?)
 #? 225.2 => 'Tamron AF 18-250mm F3.5-6.3 Di II LD Aspherical [IF] Macro', #JR (Model A18)
    255.3 => 'Tamron AF 55-200mm F4-5.6 Di II LD Macro', # (Model A15) (added "LD Macro", ref 23)
    255.4 => 'Tamron AF 70-300mm F4-5.6 Di LD Macro 1:2', # (Model A17)
    255.5 => 'Tamron SP AF 200-500mm F5.0-6.3 Di LD IF', # (Model A08)
    255.6 => 'Tamron SP AF 10-24mm F3.5-4.5 Di II LD Aspherical IF', #22 (Model B001)
    255.7 => 'Tamron SP AF 70-200mm F2.8 Di LD IF Macro', #22 (Model A001)
    255.8 => 'Tamron SP AF 28-75mm F2.8 XR Di LD Aspherical IF', #24 (Model A09)
    255.9 => 'Tamron AF 90-300mm F4.5-5.6 Telemacro', #Fredrik Agert
    18688 => 'Sigma MC-11 SA-E Mount Converter with not-supported Sigma lens',
    # The MC-11 SA-E Mount Converter uses this 18688 offset for not-supported SIGMA mount lenses.
    # The MC-11 EF-E Mount Converter uses the 61184 offset for not-supported CANON mount lenses, as also used by Metabones.
    # Both MC-11 SA-E and EF-E Mount Converters use the 504xx LensType2 values for supported SA-mount or EF-mount Sigma lenses.
    25501 => 'Minolta AF 50mm F1.7', #7
    25511 => 'Minolta AF 35-70mm F4 or Other Lens',
    25511.1 => 'Sigma UC AF 28-70mm F3.5-4.5', #12/16(HighSpeed-AF)
    25511.2 => 'Sigma AF 28-70mm F2.8', #JD
    25511.3 => 'Sigma M-AF 70-200mm F2.8 EX Aspherical', #12
    25511.4 => 'Quantaray M-AF 35-80mm F4-5.6', #JD
    25511.5 => 'Tokina 28-70mm F2.8-4.5 AF', #IB
    25521 => 'Minolta AF 28-85mm F3.5-4.5 or Other Lens', # not New (ref 18)
    25521.1 => 'Tokina 19-35mm F3.5-4.5', #3
    25521.2 => 'Tokina 28-70mm F2.8 AT-X', #7
    25521.3 => 'Tokina 80-400mm F4.5-5.6 AT-X AF II 840', #JD
    25521.4 => 'Tokina AF PRO 28-80mm F2.8 AT-X 280', #JD
    25521.5 => 'Tokina AT-X PRO [II] AF 28-70mm F2.6-2.8 270', #24 (original + II versions)
    25521.6 => 'Tamron AF 19-35mm F3.5-4.5', #JD (Model A10)
    25521.7 => 'Angenieux AF 28-70mm F2.6', #JD
    25521.8 => 'Tokina AT-X 17 AF 17mm F3.5', #27
    25521.9 => 'Tokina 20-35mm F3.5-4.5 II AF', #IB
    25531 => 'Minolta AF 28-135mm F4-4.5 or Other Lens',
    25531.1 => 'Sigma ZOOM-alpha 35-135mm F3.5-4.5', #16
    25531.2 => 'Sigma 28-105mm F2.8-4 Aspherical', #JD
    25531.3 => 'Sigma 28-105mm F4-5.6 UC', #JR
    25531.4 => 'Tokina AT-X 242 AF 24-200mm F3.5-5.6', #IB
    25541 => 'Minolta AF 35-105mm F3.5-4.5', #13
    25551 => 'Minolta AF 70-210mm F4 Macro or Sigma Lens',
    25551.1 => 'Sigma 70-210mm F4-5.6 APO', #7
    25551.2 => 'Sigma M-AF 70-200mm F2.8 EX APO', #6
    25551.3 => 'Sigma 75-200mm F2.8-3.5', #22
    25561 => 'Minolta AF 135mm F2.8',
    25571 => 'Minolta/Sony AF 28mm F2.8', # Sony added (ref 18)
    # 25571 => 'Sony 28mm F2.8 (SAL28F28)', (ref 18/JR)
    25581 => 'Minolta AF 24-50mm F4',
    25601 => 'Minolta AF 100-200mm F4.5',
    25611 => 'Minolta AF 75-300mm F4.5-5.6 or Sigma Lens', #13
    25611.1 => 'Sigma 70-300mm F4-5.6 DL Macro', #12 (also DG version ref 27, and APO version ref JR)
    25611.2 => 'Sigma 300mm F4 APO Macro', #3/7
    25611.3 => 'Sigma AF 500mm F4.5 APO', #JD
    25611.4 => 'Sigma AF 170-500mm F5-6.3 APO Aspherical', #JD
    25611.5 => 'Tokina AT-X AF 300mm F4', #JD
    25611.6 => 'Tokina AT-X AF 400mm F5.6 SD', #22
    25611.7 => 'Tokina AF 730 II 75-300mm F4.5-5.6', #JD
    25611.8 => 'Sigma 800mm F5.6 APO', #https://exiftool.org/forum/index.php/topic,3472.0.html
    25611.9 => 'Sigma AF 400mm F5.6 APO Macro', #27
   '25611.10' => 'Sigma 1000mm F8 APO', #JR
    25621 => 'Minolta AF 50mm F1.4 [New]', # original and New, not Sony (ref 13/18)
    25631 => 'Minolta AF 300mm F2.8 APO or Sigma Lens', # changed G to APO (ref 13)
    25631.1 => 'Sigma AF 50-500mm F4-6.3 EX DG APO', #JD
    25631.2 => 'Sigma AF 170-500mm F5-6.3 APO Aspherical', #JD (also DG version, ref 27)
    25631.3 => 'Sigma AF 500mm F4.5 EX DG APO', #JD
    25631.4 => 'Sigma 400mm F5.6 APO', #22
    25641 => 'Minolta AF 50mm F2.8 Macro or Sigma Lens',
    25641.1 => 'Sigma 50mm F2.8 EX Macro', #11
    25651 => 'Minolta AF 600mm F4 APO', # ("APO" added - ref JR)
    25661 => 'Minolta AF 24mm F2.8 or Sigma Lens',
    25661.1 => 'Sigma 17-35mm F2.8-4 EX Aspherical', #https://exiftool.org/forum/index.php/topic,3789.msg17679.html#msg17679
    25721 => 'Minolta/Sony AF 500mm F8 Reflex',
    # 25721 => 'Sony 500mm F8 Reflex (SAL500F80)', (ref JR)
    25781 => 'Minolta/Sony AF 16mm F2.8 Fisheye or Sigma Lens', # Sony added (ref 13/18)
    # 25781 => 'Sony 16mm F2.8 Fisheye (SAL16F28)', (ref 18/JR)
    25781.1 => 'Sigma 8mm F4 EX [DG] Fisheye',
    25781.2 => 'Sigma 14mm F3.5',
    25781.3 => 'Sigma 15mm F2.8 Fisheye', #JD (writes 16mm to EXIF)
    25791 => 'Minolta/Sony AF 20mm F2.8 or Tokina Lens', # Sony added (ref 11)
    # 25791 => 'Sony 20mm F2.8 (SAL20F28)', (ref JR)
    25791.1 => 'Tokina AT-X Pro DX 11-16mm F2.8', #https://exiftool.org/forum/index.php/topic,3593.0.html
    25811 => 'Minolta AF 100mm F2.8 Macro [New] or Sigma or Tamron Lens', # not Sony (ref 13/18)
    25811.1 => 'Sigma AF 90mm F2.8 Macro', #JD
    25811.2 => 'Sigma AF 105mm F2.8 EX [DG] Macro', #JD
    25811.3 => 'Sigma 180mm F5.6 Macro',
    25811.4 => 'Sigma 180mm F3.5 EX DG Macro', #https://exiftool.org/forum/index.php/topic,3789.msg17679.html#msg17679
    25811.5 => 'Tamron 90mm F2.8 Macro',
    25851 => 'Beroflex 35-135mm F3.5-4.5', #16
    25858 => 'Minolta AF 35-105mm F3.5-4.5 New or Tamron Lens',
    25858.1 => 'Tamron 24-135mm F3.5-5.6', # (Model 190D)
    25881 => 'Minolta AF 70-210mm F3.5-4.5',
    25891 => 'Minolta AF 80-200mm F2.8 APO or Tokina Lens', # black
    25891.1 => 'Tokina 80-200mm F2.8',
    # 25901 - Note: only get this with older 1.4x and lenses with 5-digit LensTypes (ref 27)
    # 25901 - also "Minolta AF 200mm F2.8 HS-APO G + Minolta AF 1.4x APO"
    25901 => 'Minolta AF 200mm F2.8 G APO + Minolta AF 1.4x APO or Other Lens + 1.4x', #26
    25901.1 => 'Minolta AF 600mm F4 HS-APO G + Minolta AF 1.4x APO', #27
    25911 => 'Minolta AF 35mm F1.4', #(from Sony list) (not G as per ref 13)
    25921 => 'Minolta AF 85mm F1.4 G (D)',
    25931 => 'Minolta AF 200mm F2.8 APO', # (not "G", see 26121 - ref JR)
    25941 => 'Minolta AF 3x-1x F1.7-2.8 Macro',
    25961 => 'Minolta AF 28mm F2',
    25971 => 'Minolta AF 35mm F2 [New]', #13
    25981 => 'Minolta AF 100mm F2',
    # 26011 - Note: only get this with older 2x and lenses with 5-digit LensTypes (ref 27)
    # 26011 - also "Minolta AF 200mm F2.8 HS-APO G + Minolta AF 2x APO"
    26011 => 'Minolta AF 200mm F2.8 G APO + Minolta AF 2x APO or Other Lens + 2x', #26
    26011.1 => 'Minolta AF 600mm F4 HS-APO G + Minolta AF 2x APO', #27
    26041 => 'Minolta AF 80-200mm F4.5-5.6',
    26051 => 'Minolta AF 35-80mm F4-5.6', #(from Sony list)
    26061 => 'Minolta AF 100-300mm F4.5-5.6', # not (D) (ref 13/18)
    26071 => 'Minolta AF 35-80mm F4-5.6', #13
    26081 => 'Minolta AF 300mm F2.8 HS-APO G', # HS-APO added (ref 13/18)
    26091 => 'Minolta AF 600mm F4 HS-APO G',
    26121 => 'Minolta AF 200mm F2.8 HS-APO G',
    26131 => 'Minolta AF 50mm F1.7 New',
    26151 => 'Minolta AF 28-105mm F3.5-4.5 xi', # xi, not Power Zoom (ref 13/18)
    26161 => 'Minolta AF 35-200mm F4.5-5.6 xi', # xi, not Power Zoom (ref 13/18)
    26181 => 'Minolta AF 28-80mm F4-5.6 xi', # xi, not Power Zoom (ref 13/18)
    26191 => 'Minolta AF 80-200mm F4.5-5.6 xi', # xi, not Power Zoom (ref 13/18)
    26201 => 'Minolta AF 28-70mm F2.8 G', #11
    26211 => 'Minolta AF 100-300mm F4.5-5.6 xi', # xi, not Power Zoom (ref 13/18)
    26241 => 'Minolta AF 35-80mm F4-5.6 Power Zoom',
    26281 => 'Minolta AF 80-200mm F2.8 HS-APO G', #11 ("HS-APO" added, white, probably same as 1, non-HS is 25891 - ref JR)
    26291 => 'Minolta AF 85mm F1.4 New',
    26311 => 'Minolta AF 100-300mm F4.5-5.6 APO', #11 (does not exist? https://www.dyxum.com/dforum/lens-data-requested_topic23435_page2.html)
    26321 => 'Minolta AF 24-50mm F4 New',
    26381 => 'Minolta AF 50mm F2.8 Macro New',
    26391 => 'Minolta AF 100mm F2.8 Macro',
    26411 => 'Minolta/Sony AF 20mm F2.8 New', # Sony added (ref 13)
    26421 => 'Minolta AF 24mm F2.8 New',
    26441 => 'Minolta AF 100-400mm F4.5-6.7 APO', #11
    26621 => 'Minolta AF 50mm F1.4 New',
    26671 => 'Minolta AF 35mm F2 New',
    26681 => 'Minolta AF 28mm F2 New',
    26721 => 'Minolta AF 24-105mm F3.5-4.5 (D)', #11
    # 30464: newer firmware versions of the Speed Booster report type 30464 (=0x7700)
    # - this is the base to which the Canon LensType is added
    30464 => 'Metabones Canon EF Speed Booster', #Metabones (to this, add Canon LensType)
    45671 => 'Tokina 70-210mm F4-5.6', #22
    45681 => 'Tokina AF 35-200mm F4-5.6 Zoom SD', #IB (model 352)
    45701 => 'Tamron AF 35-135mm F3.5-4.5', #IB (model 40d)
    45711 => 'Vivitar 70-210mm F4.5-5.6', #IB
    45741 => '2x Teleconverter or Tamron or Tokina Lens', #18
    45741.1 => 'Tamron SP AF 90mm F2.5', #JD
    45741.2 => 'Tokina RF 500mm F8.0 x2', #JD
    45741.3 => 'Tokina 300mm F2.8 x2',
    45751 => '1.4x Teleconverter', #18
    45851 => 'Tamron SP AF 300mm F2.8 LD IF', #11
    45861 => 'Tamron SP AF 35-105mm F2.8 LD Aspherical IF', #Fredrik Agert
    45871 => 'Tamron AF 70-210mm F2.8 SP LD', #Fabio Suprani
    # 48128: the Speed Booster Ultra appears to report type 48128 (=0xbc00)
    # - this is the base to which the Canon LensType is added
    48128 => 'Metabones Canon EF Speed Booster Ultra', #JR (to this, add Canon LensType)
    # 61184: older firmware versions of both the Speed Booster and the Smart Adapter
    # report type 61184 (=0xef00), and add only the lower byte of the Canon LensType (ref JR).
    # For newer firmware versions this is only used by the Smart Adapter, and
    # the full Canon LensType code is added - PH
    # the metabones adapter translates Canon L -> G, II -> II, USM -> SSM, IS -> OSS (ref JR)
    # This offset is used by Metabones, Fotodiox, Sigma MC-11 EF-E and Viltrox Canon EF adapters.
    61184 => 'Canon EF Adapter', #JR (to this, add Canon LensType)
    # 65280 = 0xff00
    65280 => 'Sigma 16mm F2.8 Filtermatic Fisheye', #IB
    # all M42-type lenses give a value of 65535 (and FocalLength=0, FNumber=1)
    65535 => 'E-Mount, T-Mount, Other Lens or no lens', #JD/JR
   '65535.1' => 'Arax MC 35mm F2.8 Tilt+Shift', #JD
   '65535.2' => 'Arax MC 80mm F2.8 Tilt+Shift', #JD
   '65535.3' => 'Zenitar MF 16mm F2.8 Fisheye M42', #JD
   '65535.4' => 'Samyang 500mm Mirror F8.0', #19
   '65535.5' => 'Pentacon Auto 135mm F2.8', #19
   '65535.6' => 'Pentacon Auto 29mm F2.8', #19
   '65535.7' => 'Helios 44-2 58mm F2.0', #19
);

%minoltaTeleconverters = (
    0x00 => 'None',
    0x04 => 'Minolta/Sony AF 1.4x APO (D) (0x04)', # (Andy Johnson, A77 APO and APO D)
    0x05 => 'Minolta/Sony AF 2x APO (D) (0x05)', # (Andy Johnson, A77 APO D)
    0x48 => 'Minolta/Sony AF 2x APO (D)',
    # 0x48 => 'Sony 2x Teleconverter (SAL20TC)', (ref JR)
    0x50 => 'Minolta AF 2x APO II',
    0x60 => 'Minolta AF 2x APO',#26
    0x88 => 'Minolta/Sony AF 1.4x APO (D)',
    # 0x88 => 'Sony 1.4x Teleconverter (SAL14TC)', (ref JR)
    0x90 => 'Minolta AF 1.4x APO II',
    0xa0 => 'Minolta AF 1.4x APO',#26
);

%minoltaColorMode = (
    0 => 'Natural color',
    1 => 'Black & White',
    2 => 'Vivid color',
    3 => 'Solarization',
    4 => 'Adobe RGB',
    5 => 'Sepia', #10
    9 => 'Natural', #10
    12 => 'Portrait', #10
    13 => 'Natural sRGB',
    14 => 'Natural+ sRGB',
    15 => 'Landscape', #10
    16 => 'Evening', #10
    17 => 'Night Scene', #10
    18 => 'Night Portrait', #10
    0x84 => 'Embed Adobe RGB',
);

%sonyColorMode = ( #15
    0 => 'Standard',
    1 => 'Vivid', #PH
    2 => 'Portrait',
    3 => 'Landscape',
    4 => 'Sunset',
    5 => 'Night View/Portrait', #(portrait if flash is on)
    6 => 'B&W',
    7 => 'Adobe RGB',
    12 => 'Neutral', # Sony
    13 => 'Clear', #JR (NC)
    14 => 'Deep', #JR
    15 => 'Light', #JR (NC)
    16 => 'Autumn Leaves', #JR (NC)
    17 => 'Sepia', #JR
    18 => 'FL', #JR (7SM3)
    19 => 'Vivid 2', #JR (7SM3)
    20 => 'IN', #JR (7SM3)
    21 => 'SH', #JR (7SM3)
    100 => 'Neutral', #JD
    101 => 'Clear', #JD
    102 => 'Deep', #JD
    103 => 'Light', #JD
    104 => 'Night View', #JD
    105 => 'Autumn Leaves', #JD
    255 => 'Off', #JR (new for ILCE-7SM3, July 2020)
   0xffffffff => 'n/a', #PH
);

%minoltaSceneMode = (
    0 => 'Standard',
    1 => 'Portrait',
    2 => 'Text',
    3 => 'Night Scene',
    4 => 'Sunset',
    5 => 'Sports',
    6 => 'Landscape',
    7 => 'Night Portrait', #JD
    8 => 'Macro',
    9 => 'Super Macro',
    16 => 'Auto', # (RX100 'Intelligent Auto' - PH)
    17 => 'Night View/Portrait',
    18 => 'Sweep Panorama', #PH (SLT-A55V)
    19 => 'Handheld Night Shot', #PH
    20 => 'Anti Motion Blur', #PH
    21 => 'Cont. Priority AE', #PH
    22 => 'Auto+',
    23 => '3D Sweep Panorama', #PH (SLT-A55V)
    24 => 'Superior Auto', #28
    25 => 'High Sensitivity', #28
    26 => 'Fireworks', #28
    27 => 'Food', #28
    28 => 'Pet', #28
    33 => 'HDR', #JR
    0xffff => 'n/a', #PH
);

# tag information for AFStatus tags (ref 20)
%afStatusInfo = (
    Format => 'int16s',
    # 0=in focus, -32768=out of focus, -ve=front focus, +ve=back focus
    PrintConvColumns => 2,
    PrintConv => {
        0 => 'In Focus',
        -32768 => 'Out of Focus',
        OTHER => sub {
            my ($val, $inv) = @_;
            $inv and $val =~ /([-+]?\d+)/, return $1;
            return $val < 0 ? "Front Focus ($val)" : "Back Focus (+$val)";
        },
    },
);

my %exposureIndicator = (
    0 => 'Not Indicated',
    1 => 'Under Scale',
    119 => 'Bottom of Scale',
    120 => '-2.0',
    121 => '-1.7',
    122 => '-1.5',
    123 => '-1.3',
    124 => '-1.0',
    125 => '-0.7',
    126 => '-0.5',
    127 => '-0.3',
    128 => '0',
    129 => '+0.3',
    130 => '+0.5',
    131 => '+0.7',
    132 => '+1.0',
    133 => '+1.3',
    134 => '+1.5',
    135 => '+1.7',
    136 => '+2.0',
    253 => 'Top of Scale',
    254 => 'Over Scale',
);

my %onOff = ( 0 => 'On', 1 => 'Off' );
my %offOn = ( 0 => 'Off', 1 => 'On' );

# Minolta tag table
%Image::ExifTool::Minolta::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0000 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
    0x0001 => {
        Name => 'MinoltaCameraSettingsOld',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0003 => {
        Name => 'MinoltaCameraSettings',
        # These camera settings are different for the DiMAGE X31
        Condition => '$self->{Model} ne "DiMAGE X31"',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0004 => { #8
        Name => 'MinoltaCameraSettings7D',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings7D',
            ByteOrder => 'BigEndian',
        },
    },
    0x0010 => { #20 (count: 256)
        Name => 'CameraInfoA100',
        Condition => '$$self{Model} eq "DSLR-A100"',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraInfoA100',
            ByteOrder => 'LittleEndian',
        },
    },
    # it appears that image stabilization is on if this tag exists (ref 2),
    # but it is an 8kB binary data block!
    0x0018 => [
        {
            Name => 'ISInfoA100',
            Condition => '$self->{Model} eq "DSLR-A100"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Minolta::ISInfoA100',
                ByteOrder => 'BigEndian',
            },
        },{
            Name => 'ImageStabilization',
            Condition => '$self->{Model} =~ /^DiMAGE (A1|A2|X1)$/',
            Notes => q{
                a block of binary data which exists in DiMAGE A2 (and A1/X1?) images only if
                image stabilization is enabled
            },
            ValueConv => '"On"',
        },
    ],
    0x0020 => {
        Name => 'WBInfoA100',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Notes => 'currently decoded only for the Sony A100',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::WBInfoA100',
            ByteOrder => 'BigEndian',
        },
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        # JPEG preview found in DiMAGE 7 images
        %Image::ExifTool::previewImageTagInfo,
        Groups => { 2 => 'Preview' },
        Permanent => 1,     # don't add this to a file
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
        # Note: Sony also uses this tag in A100 ARW images, but it points
        #       to the same data as JpgFromRaw
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x0100 => { #10
        Name => 'SceneMode',
        Writable => 'int32u',
        PrintConv => \%minoltaSceneMode,
    },
    0x0101 => [
        {
            Name => 'ColorMode',
            Condition => '$self->{Make} !~ /^SONY/',
            Priority => 0, # Other ColorMode is more reliable for A2
            Writable => 'int32u',
            PrintConv => \%minoltaColorMode,
        },
        { #15
            Name => 'ColorMode',
            Writable => 'int32u',
            Notes => 'Sony models',
            PrintConv => \%sonyColorMode,
        },
    ],
    0x0102 => {
        Name => 'MinoltaQuality',
        Writable => 'int32u',
        # PrintConv strings conform with Minolta reference manual (ref NJ)
        # (note that Minolta calls an uncompressed TIFF image "Super fine")
        PrintConv => {
            0 => 'Raw',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra fine',
        },
    },
    # (0x0103 is the same as 0x0102 above) -- this is true for some
    # cameras (A2/7Hi), but not others - PH
    0x0103 => [
        {
            Name => 'MinoltaQuality',
            Writable => 'int32u',
            Condition => '$self->{Model} =~ /^DiMAGE (A2|7Hi)$/',
            Notes => 'quality for DiMAGE A2/7Hi',
            Priority => 0, # lower priority because this doesn't work for A200
            PrintConv => { #NJ
                0 => 'Raw',
                1 => 'Super Fine',
                2 => 'Fine',
                3 => 'Standard',
                4 => 'Economy',
                5 => 'Extra fine',
            },
        },
        { #PH
            Name => 'MinoltaImageSize',
            Writable => 'int32u',
            Condition => '$self->{Model} !~ /^DiMAGE A200$/',
            Notes => 'image size for other models except A200',
            PrintConv => {
                1 => '1600x1200',
                2 => '1280x960',
                3 => '640x480',
                5 => '2560x1920',
                6 => '2272x1704',
                7 => '2048x1536',
            },
        },
    ],
    0x0104 => { #14
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Writable => 'rational64s',
    },
    0x0105 => { #10
        Name => 'Teleconverter',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => \%minoltaTeleconverters,
    },
    0x0107 => { #8
        Name => 'ImageStabilization',
        Writable => 'int32u',
        PrintConv => {
            1 => 'Off',
            5 => 'On',
        },
    },
    0x0109 => { #20
        Name => 'RawAndJpgRecording',
        Writable => 'int32u',
        PrintConv => \%offOn,
    },
    0x010a => {
        Name => 'ZoneMatching',
        Writable => 'int32u',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    0x010b => {
        Name => 'ColorTemperature',
        Writable => 'int32u',
    },
    0x010c => { #3 (Alpha 7)
        Name => 'LensType',
        Writable => 'int32u',
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%minoltaLensTypes,
        PrintInt => 1,
    },
    # 0x010e - WhiteBalance according to ref #10
    0x0111 => { #20
        Name => 'ColorCompensationFilter',
        Writable => 'int32s',
        Notes => 'ranges from -2 for green to +2 for magenta',
    },
    0x0112 => { #PH (from Sony tags, NC)
        Name => 'WhiteBalanceFineTune',
        Format => 'int32s',
        Writable => 'int32u',
    },
    0x0113 => { #PH
        Name => 'ImageStabilization',
        Condition => '$self->{Model} eq "DSLR-A100"',
        Notes => 'valid for Sony A100 only',
        Writable => 'int32u',
        PrintConv => \%offOn,
    },
    0x0114 => [
        { #8
            Name => 'MinoltaCameraSettings5D',
            Condition => '$self->{Model} =~ /^(DYNAX 5D|MAXXUM 5D|ALPHA SWEET)/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Minolta::CameraSettings5D',
                ByteOrder => 'BigEndian',
            },
        },
        { #PH
            Name => 'CameraSettingsA100',
            Condition => '$self->{Model} eq "DSLR-A100"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Minolta::CameraSettingsA100',
                ByteOrder => 'BigEndian', # required because order differs for ARW and JPG images
            },
        },
    ],
    0x0115 => { #20
        Name => 'WhiteBalance',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Auto',
            0x01 => 'Color Temperature/Color Filter',
            0x10 => 'Daylight',
            0x20 => 'Cloudy',
            0x30 => 'Shade',
            0x40 => 'Tungsten',
            0x50 => 'Flash',
            0x60 => 'Fluorescent',
            0x70 => 'Custom',
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
    0x0f00 => {
        Name => 'MinoltaCameraSettings2',
        Writable => 0,
        Binary => 1,
    },
);

%Image::ExifTool::Minolta::CameraSettings = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0, # not as reliable as other tags
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    NOTES => q{
        There is some variability in CameraSettings information between different
        models (and sometimes even between different firmware versions), so this
        information may not be as reliable as it should be.  Because of this, tags
        in the following tables are set to lower priority to prevent them from
        superseding the values of same-named tags in other locations when duplicate
        tags are disabled.
    },
    1 => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture Priority',
            2 => 'Shutter Priority',
            3 => 'Manual',
        },
    },
    2 => {
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Fill flash',
            1 => 'Red-eye reduction',
            2 => 'Rear flash sync',
            3 => 'Wireless',
            4 => 'Off?', #PH
        },
    },
    3 => {
        Name => 'WhiteBalance',
        PrintConv => 'Image::ExifTool::Minolta::ConvertWhiteBalance($val)',
    },
    4 => {
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Full',
            1 => '1600x1200',
            2 => '1280x960',
            3 => '640x480',
            6 => '2080x1560', #PH (A2)
            7 => '2560x1920', #PH (A2)
            8 => '3264x2176', #PH (A2)
        },
    },
    5 => {
        Name => 'MinoltaQuality',
        PrintConv => { #NJ
            0 => 'Raw',
            1 => 'Super Fine',
            2 => 'Fine',
            3 => 'Standard',
            4 => 'Economy',
            5 => 'Extra Fine',
        },
    },
    6 => {
        Name => 'DriveMode',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            2 => 'Self-timer',
            4 => 'Bracketing',
            5 => 'Interval',
            6 => 'UHS continuous',
            7 => 'HS continuous',
        },
    },
    7 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center-weighted average',
            2 => 'Spot',
        },
    },
    8 => {
        Name => 'ISO',
        ValueConv => '2 ** (($val-48)/8) * 100',
        ValueConvInv => '48 + 8*log($val/100)/log(2)',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    9 => {
        Name => 'ExposureTime',
        ValueConv => '2 ** ((48-$val)/8)',
        ValueConvInv => '48 - 8*log($val)/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    10 => {
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    11 => {
        Name => 'MacroMode',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'Off',
            1 => 'Electronic magnification',
            2 => '2x',
        },
    },
    13 => {
        Name => 'ExposureCompensation',
        ValueConv => '$val/3 - 2',
        ValueConvInv => '($val + 2) * 3',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    14 => {
        Name => 'BracketStep',
        PrintConv => {
            0 => '1/3 EV',
            1 => '2/3 EV',
            2 => '1 EV',
        },
    },
    16 => 'IntervalLength',
    17 => 'IntervalNumber',
    18 => {
        Name => 'FocalLength',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    19 => {
        Name => 'FocusDistance',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => '$val ? "$val m" : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val =~ s/\s*m$//, $val',
    },
    20 => {
        Name => 'FlashFired',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    21 => {
        Name => 'MinoltaDate',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'sprintf("%4d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    22 => {
        Name => 'MinoltaTime',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'sprintf("%.2d:%.2d:%.2d",$val>>16,($val&0xff00)>>8,$val&0xff)',
        ValueConvInv => 'my @a=($val=~/(\d+):(\d+):(\d+)/); @a ? ($a[0]<<16)+($a[1]<<8)+$a[2] : undef',
    },
    23 => {
        Name => 'MaxAperture',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    26 => {
        Name => 'FileNumberMemory',
        PrintConv => \%offOn,
    },
    27 => 'LastFileNumber',
    28 => {
        Name => 'ColorBalanceRed',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    29 => {
        Name => 'ColorBalanceGreen',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    30 => {
        Name => 'ColorBalanceBlue',
        ValueConv => '$val / 256',
        ValueConvInv => '$val * 256',
    },
    31 => {
        Name => 'Saturation',
        ValueConv => '$val - ($self->{Model}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{Model}=~/DiMAGE A2/ ? 5 : 3)',
        %Image::ExifTool::Exif::printParameter,
    },
    32 => {
        Name => 'Contrast',
        ValueConv => '$val - ($self->{Model}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{Model}=~/DiMAGE A2/ ? 5 : 3)',
        %Image::ExifTool::Exif::printParameter,
    },
    33 => {
        Name => 'Sharpness',
        PrintConv => {
            0 => 'Hard',
            1 => 'Normal',
            2 => 'Soft',
        },
    },
    34 => {
        Name => 'SubjectProgram',
        PrintConv => {
            0 => 'None',
            1 => 'Portrait',
            2 => 'Text',
            3 => 'Night portrait',
            4 => 'Sunset',
            5 => 'Sports action',
        },
    },
    35 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        ValueConv => '($val - 6) / 3',
        ValueConvInv => '$val * 3 + 6',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    36 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => 100,
            1 => 200,
            2 => 400,
            3 => 800,
            4 => 'Auto',
            5 => 64,
        },
    },
    37 => {
        Name => 'MinoltaModelID',
        PrintConv => {
            0 => 'DiMAGE 7, X1, X21 or X31',
            1 => 'DiMAGE 5',
            2 => 'DiMAGE S304',
            3 => 'DiMAGE S404',
            4 => 'DiMAGE 7i',
            5 => 'DiMAGE 7Hi',
            6 => 'DiMAGE A1',
            7 => 'DiMAGE A2 or S414',
        },
    },
    38 => {
        Name => 'IntervalMode',
        PrintConv => {
            0 => 'Still Image',
            1 => 'Time-lapse Movie',
        },
    },
    39 => {
        Name => 'FolderName',
        PrintConv => {
            0 => 'Standard Form',
            1 => 'Data Form',
        },
    },
    40 => {
        Name => 'ColorMode',
        PrintConv => {
            0 => 'Natural color',
            1 => 'Black & White',
            2 => 'Vivid color',
            3 => 'Solarization',
            4 => 'Adobe RGB',
        },
    },
    41 => {
        Name => 'ColorFilter',
        ValueConv => '$val - ($self->{Model}=~/DiMAGE A2/ ? 5 : 3)',
        ValueConvInv => '$val + ($self->{Model}=~/DiMAGE A2/ ? 5 : 3)',
    },
    42 => 'BWFilter',
    43 => {
        Name => 'InternalFlash',
        PrintConv => {
            0 => 'No',
            1 => 'Fired',
        },
    },
    44 => {
        Name => 'Brightness',
        ValueConv => '$val/8 - 6',
        ValueConvInv => '($val + 6) * 8',
    },
    45 => 'SpotFocusPointX',
    46 => 'SpotFocusPointY',
    47 => {
        Name => 'WideFocusZone',
        PrintConv => {
            0 => 'No zone',
            1 => 'Center zone (horizontal orientation)',
            2 => 'Center zone (vertical orientation)',
            3 => 'Left zone',
            4 => 'Right zone',
        },
    },
    48 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },
    49 => {
        Name => 'FocusArea',
        PrintConv => {
            0 => 'Wide Focus (normal)',
            1 => 'Spot Focus',
        },
    },
    50 => {
        Name => 'DECPosition',
        PrintConv => {
            0 => 'Exposure',
            1 => 'Contrast',
            2 => 'Saturation',
            3 => 'Filter',
        },
    },
    # 7Hi only:
    51 => {
        Name => 'ColorProfile',
        Condition => '$self->{Model} eq "DiMAGE 7Hi"',
        Notes => 'DiMAGE 7Hi only',
        PrintConv => {
            0 => 'Not Embedded',
            1 => 'Embedded',
        },
    },
    # (the following may be entry 51 for other models?)
    52 => {
        Name => 'DataImprint',
        Condition => '$self->{Model} eq "DiMAGE 7Hi"',
        Notes => 'DiMAGE 7Hi only',
        PrintConv => {
            0 => 'None',
            1 => 'YYYY/MM/DD',
            2 => 'MM/DD/HH:MM',
            3 => 'Text',
            4 => 'Text + ID#',
        },
    },
    63 => { #9
        Name => 'FlashMetering',
        PrintConv => {
            0 => 'ADI (Advanced Distance Integration)',
            1 => 'Pre-flash TTL',
            2 => 'Manual flash control',
        },
    },
);

# Camera settings used by the 7D (ref 8)
%Image::ExifTool::Minolta::CameraSettings7D = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x00 => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture Priority',
            2 => 'Shutter Priority',
            3 => 'Manual',
            4 => 'Auto',
            5 => 'Program-shift A',
            6 => 'Program-shift S',
        },
    },
    0x02 => { #PH
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    0x03 => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'RAW',
            16 => 'Fine', #PH
            32 => 'Normal', #PH
            34 => 'RAW+JPEG',
            48 => 'Economy', #PH
        },
    },
    0x04 => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Cloudy',
            4 => 'Tungsten',
            5 => 'Fluorescent',
            0x100 => 'Kelvin',
            0x200 => 'Manual',
        },
    },
    0x0e => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'AF-S',
            1 => 'AF-C',
            # Note: these two are reversed in ref 8
            3 => 'Manual', #JD
            4 => 'AF-A', #JD
        },
    },
    0x10 => {
        Name => 'AFPoints',
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Center',
                1 => 'Top',
                2 => 'Top-right',
                3 => 'Right',
                4 => 'Bottom-right',
                5 => 'Bottom',
                6 => 'Bottom-left',
                7 => 'Left',
                8 => 'Top-left',
            },
        },
    },
    0x15 => {
        Name => 'Flash',
        PrintConv => \%offOn,
    },
    0x16 => { #10
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Normal',
            1 => 'Red-eye reduction',
            2 => 'Rear flash sync',
        },
    },
    0x1c => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => 'Auto', #10
            1 => 100,
            3 => 200,
            4 => 400,
            5 => 800,
            6 => 1600,
            7 => 3200,
        },
    },
    0x1e => {
        Name => 'ExposureCompensation',
        Format => 'int16s',
        ValueConv => '$val / 24',
        ValueConvInv => '$val * 24',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x25 => {
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'Natural sRGB',
            1 => 'Natural+ sRGB',
            4 => 'Adobe RGB',
        },
    },
    0x26 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x27 => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x28 => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x2d => 'FreeMemoryCardImages',
    0x3f => {
        Format => 'int16s',
        Name => 'ColorTemperature',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x40 => { #10
        Name => 'HueAdjustment',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x46 => {
        Name => 'Rotation',
        PrintConv => {
            72 => 'Horizontal (normal)',
            76 => 'Rotate 90 CW',
            82 => 'Rotate 270 CW',
        },
    },
    0x47 => {
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x48 => {
        Name => 'ExposureTime',
        ValueConv => '2 ** ((48-$val)/8)',
        ValueConvInv => '48 - 8*log($val)/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x4a => 'FreeMemoryCardImages',
    0x5e => {
        Name => 'ImageNumber',
        Notes => q{
            this information may appear at index 98 (0x62), depending on firmware
            version
        },
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x60 => {
        Name => 'NoiseReduction',
        PrintConv => \%offOn,
    },
    0x62 => {
        Name => 'ImageNumber2',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x71 => {
        Name => 'ImageStabilization',
        PrintConv => \%offOn,
    },
    0x75 => {
        Name => 'ZoneMatchingOn',
        PrintConv => \%offOn,
    },
);

# Camera settings used by the 5D (ref 8)
%Image::ExifTool::Minolta::CameraSettings5D = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x0a => {
        Name => 'ExposureMode',
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture Priority',
            2 => 'Shutter Priority',
            3 => 'Manual',
            4 => 'Auto?',
            4131 => 'Connected Copying?',
        },
    },
    0x0c => { #PH
        Name => 'MinoltaImageSize',
        PrintConv => {
            0 => 'Large',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    0x0d => {
        Name => 'MinoltaQuality',
        PrintConv => {
            0 => 'RAW',
            16 => 'Fine', #PH
            32 => 'Normal', #PH
            34 => 'RAW+JPEG',
            48 => 'Economy', #PH
        },
    },
    0x0e => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Shade',
            4 => 'Tungsten',
            5 => 'Fluorescent',
            6 => 'Flash',
            0x100 => 'Kelvin',
            0x200 => 'Manual',
        },
    },
    # 0x0f-0x11 something to do with WB RGB levels as shot? (PH)
    # 0x12-0x17 RGB levels for other WB modes (with G missing)? (PH)
    0x1f => { #PH
        Name => 'Flash',
        PrintConv => {
            0 => 'Did not fire',
            1 => 'Fired',
        },
    },
    0x20 => { #10
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Normal',
            1 => 'Red-eye reduction',
            2 => 'Rear flash sync',
        },
    },
    0x25 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center-weighted average',
            2 => 'Spot',
        },
    },
    0x26 => {
        Name => 'ISOSetting',
        PrintConv => {
            0 => 'Auto',
            1 => 100,
            3 => 200,
            4 => 400,
            5 => 800,
            6 => 1600,
            7 => 3200,
            8 => '200 (Zone Matching High)',
            10 => '80 (Zone Matching Low)',
        },
    },
# looks wrong:
#    0x28 => { #10
#        Name => 'ExposureCompensation',
#        ValueConv => '$val / 24',
#        ValueConvInv => '$val * 24',
#    },
    0x2f => { #10
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'Natural sRGB',
            1 => 'Natural+ sRGB',
            2 => 'Monochrome',
            4 => 'Adobe RGB (ICC)',
            5 => 'Adobe RGB',
        },
    },
    0x30 => {
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x31 => {
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x32 => {
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x35 => { #PH
        Name => 'ExposureTime',
        ValueConv => '2 ** ((48-$val)/8)',
        ValueConvInv => '48 - 8*log($val)/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x36 => { #PH
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x37 => 'FreeMemoryCardImages',
    # 0x38 definitely not related to exposure comp as in ref 8 (PH)
    0x49 => { #PH
        Name => 'ColorTemperature',
        Format => 'int16s',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x4a => { #10
        Name => 'HueAdjustment',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
    },
    0x50 => {
        Name => 'Rotation',
        PrintConv => {
            72 => 'Horizontal (normal)',
            76 => 'Rotate 90 CW',
            82 => 'Rotate 270 CW',
        },
    },
    0x53 => {
        Name => 'ExposureCompensation',
        ValueConv => '$val / 100 - 3',
        ValueConvInv => '($val + 3) * 100',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x54 => 'FreeMemoryCardImages',
    0x65 => { #10
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    # 0x66 maybe program mode or some setting like this? (PH)
    0x6e => { #10
        Name => 'ColorTemperature',
        Format => 'int16s',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x71 => { #10
        Name => 'PictureFinish',
        PrintConv => {
            0 => 'Natural',
            1 => 'Natural+',
            2 => 'Portrait',
            3 => 'Wind Scene',
            4 => 'Evening Scene',
            5 => 'Night Scene',
            6 => 'Night Portrait',
            7 => 'Monochrome',
            8 => 'Adobe RGB',
            9 => 'Adobe RGB (ICC)',
        },
    },
    # 0x95 FlashStrength? (PH)
    # 0xa4 similar information to 0x27, except with different values
    0xae => {
        Name => 'ImageNumber',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0xb0 => {
        Name => 'NoiseReduction',
        PrintConv => \%offOn,
    },
    0xbd => {
        Name => 'ImageStabilization',
        PrintConv => \%offOn,
    },
);

# Camera settings used by the Sony DSLR-A100 (ref 20)
%Image::ExifTool::Minolta::CameraInfoA100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'Camera information for the Sony DSLR-A100.',
    WRITABLE => 1,
    PRIORITY => 0, # may not be as reliable as other information
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    0x01 => { #PH
        Name => 'AFSensorActive',
        PrintConv => {
            0 => 'Top-right',
            1 => 'Bottom-right',
            2 => 'Bottom',
            3 => 'Middle Horizontal',
            4 => 'Center Vertical',
            5 => 'Top',
            6 => 'Top-left',
            7 => 'Bottom-left',
        },
    },
    0x02 => {
        Name => 'AFStatusActiveSensor',
        %afStatusInfo,
        Notes => q{
            the focus status at shutter release.  May not reflect the status after
            focusing if the image is focused then recomposed
        },
    },
    0x04 => { Name => 'AFStatusTop-right',      %afStatusInfo },
    0x06 => { Name => 'AFStatusBottom-right',   %afStatusInfo },
    0x08 => { Name => 'AFStatusBottom',         %afStatusInfo },
    0x0a => {
        Name => 'AFStatusMiddleHorizontal',
        %afStatusInfo,
        Notes => q{
            any of the three horizontal sensors at the middle of the focus frame: Left,
            Center or Right
        },
    },
    0x0c => { Name => 'AFStatusCenterVertical', %afStatusInfo },
    0x0e => { Name => 'AFStatusTop',            %afStatusInfo },
    0x10 => { Name => 'AFStatusTop-left',       %afStatusInfo },
    0x12 => { Name => 'AFStatusBottom-left',    %afStatusInfo },
    0x14 => {
        Name => 'FocusLocked',
        # (Focus can be locked in all modes other than Manual and Continuous,
        # and the latter can be overridden by pushing the Spot AF button)
        PrintConv => {
            0 => 'Manual Focus',
            4 => 'No',
            16 => 'Continuous Focus',
            64 => 'Yes',
        },
    },
    0x15 => {
        Name => 'AFPoint',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto',
            1 => 'Center',
            2 => 'Top',
            3 => 'Top-right',
            4 => 'Right',
            5 => 'Bottom-right',
            6 => 'Bottom',
            7 => 'Bottom-left',
            8 => 'Left',
            9 => 'Top-left',
        },
    },
    0x16 => {
        Name => 'AFMode',
        PrintConv => {
            0 => 'DMF',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A',
        },
    },
    0x2d => { Name => 'AFStatusLeft',            %afStatusInfo },
    0x2f => { Name => 'AFStatusCenterHorizontal',%afStatusInfo },
    0x31 => { Name => 'AFStatusRight',           %afStatusInfo },
    0x33 => {
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
);

# Image stabilization information used by the Sony DSLR-A100 (ref 20)
%Image::ExifTool::Minolta::ISInfoA100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'Image stabilization information for the Sony DSLR-A100.',
    WRITABLE => 1,
    PRIORITY => 0, # may not be as reliable as other information
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    0 => {
        Name => 'ImageStabilization',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x0000 => 'Off',
            0x2784 => 'On',
        },
    },
);

# Camera settings used by the Sony DSLR-A100 (ref PH)
%Image::ExifTool::Minolta::CameraSettingsA100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'Camera settings information for the Sony DSLR-A100.',
    WRITABLE => 1,
    PRIORITY => 0, # may not be as reliable as other information
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    0x00 => { #15
        Name => 'ExposureMode',
        PrintHex => 1,
        PrintConv => {
            0 => 'Program',
            1 => 'Aperture Priority',
            2 => 'Shutter Priority',
            3 => 'Manual',
            4 => 'Auto',
            5 => 'Program Shift A', #20
            6 => 'Program Shift S', #20
            0x1013 => 'Portrait',
            0x1023 => 'Sports', #20
            0x1033 => 'Sunset', #20
            0x1043 => 'Night View/Portrait', #20
            0x1053 => 'Landscape',
            0x1083 => 'Macro', #20
        },
    },
    0x01 => { #15
        Name => 'ExposureCompensationSetting',
        # (differs from ExposureCompensation for exposure bracketing shots, ref 20)
        ValueConv => '$val / 100 - 3',
        ValueConvInv => 'int(($val + 3) * 100 + 0.5)',
    },
    0x05 => { #20 (requires external flash)
        Name => 'HighSpeedSync',
        PrintConv => \%offOn,
    },
    0x06 => { #20
        Name => 'ShutterSpeedSetting',
        Notes => 'used only in M and S exposure modes',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x07 => { #20
        Name => 'ApertureSetting',
        Notes => 'used only in M and A exposure modes',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x08 => { #20
        Name => 'ExposureTime',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x09 => { #15/20
        Name => 'FNumber',
        ValueConv => '2 ** (($val/8 - 1) / 2)',
        ValueConvInv => 'int((log($val) * 2 / log(2) + 1) * 8 + 0.5)',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    0x0a => { #20
        Name => 'DriveMode2', # (one of these is probably DriveModeSetting like Sony - PH)
        PrintHex => 1,
        PrintConv => {
            0x000 => 'Self-timer 10 sec',
            0x001 => 'Continuous',
            0x302 => 'Single-frame Bracketing Low',
            0x702 => 'Single-frame Bracketing High',
            0x303 => 'Continous Bracketing Low',
            0x703 => 'Continuous Bracketing High',
            0x004 => 'Self-timer 2 sec',
            0x005 => 'Single Frame',
            0x008 => 'White Balance Bracketing Low',
            0x009 => 'White Balance Bracketing High',
        },
    },
    0x0b => { #15
        Name => 'WhiteBalance',
        PrintHex => 1,
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Shade',
            4 => 'Tungsten',
            5 => 'Fluorescent',
            6 => 'Flash',
            0x100 => 'Kelvin',
            0x200 => 'Manual',
        },
    },
    0x0c => { #20
        Name => 'FocusMode',
        PrintConv => {
            0 => 'AF-S',
            1 => 'AF-C',
            4 => 'AF-A',
            5 => 'Manual',
            6 => 'DMF',
        },
    },
    0x0d => { #20
        Name => 'AFPointSelected', # (v8.88: renamed from LocalAFAreaPoint)
        # (9-point centre-cross AF system, ref JR)
        PrintConv => {
            1 => 'Center',
            2 => 'Top',
            3 => 'Top-right',
            4 => 'Right',
            5 => 'Bottom-right',
            6 => 'Bottom',
            7 => 'Bottom-left',
            8 => 'Left',
            9 => 'Top-left',
        },
    },
    0x0e => { #20
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Wide',
            1 => 'Local',
            2 => 'Spot',
        },
    },
    0x0f => { #20
        Name => 'FlashMode',
        PrintConv => {
            0 => 'Auto',
            2 => 'Rear Sync',
            3 => 'Wireless',
            4 => 'Fill Flash',
        },
    },
    0x10 => { #20
        Name => 'FlashExposureCompSet',
        Description => 'Flash Exposure Comp. Setting',
        # (may differ from FlashExposureComp for flash bracketing shots)
        ValueConv => '$val / 100 - 3',
        ValueConvInv => 'int(($val + 3) * 100 + 0.5)',
    },
    0x12 => { #15/20
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center-weighted average',
            2 => 'Spot',
        },
    },
    0x13 => { #15/20
        Name => 'ISOSetting',
        PrintConv => {
            0 => 'Auto',
            48 => 100,
            56 => 200,
            64 => 400,
            72 => 800,
            80 => 1600,
            174 => '80 (Zone Matching Low)',
            184 => '200 (Zone Matching High)',
        },
    },
    0x14 => { #15/20
        Name => 'ZoneMatchingMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced',
        },
    },
    0x15 => { #15/20
        Name => 'DynamicRangeOptimizer',
        # this and the Sony tag 0xb025 DynamicRangeOptimizer give the actual mode
        # applied to the image. The Minolta CameraSettingsA100 0x0027 tag gives
        # the setting. There is a longish list of scenarios in which, regardless
        # of the latter, DRO is not applied (ref 20)
        Notes => 'as applied to image',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced',
        },
    },
    0x16 => { #15
        Name => 'ColorMode',
        PrintConv => {
            0 => 'Standard',
            1 => 'Vivid',
            2 => 'Portrait',
            3 => 'Landscape',
            4 => 'Sunset',
            5 => 'Night Scene',
            7 => 'B&W',
            8 => 'Adobe RGB',
        },
    },
    0x17 => { # 15/20
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'sRGB',
            2 => 'B&W', #PH (A100)
            5 => 'Adobe RGB',
        },
    },
    0x18 => { #15
        Name => 'Sharpness',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        %Image::ExifTool::Exif::printParameter,
    },
    0x19 => { #15
        Name => 'Contrast',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        %Image::ExifTool::Exif::printParameter,
    },
    0x1a => { #15
        Name => 'Saturation',
        ValueConv => '$val - 10',
        ValueConvInv => '$val + 10',
        %Image::ExifTool::Exif::printParameter,
    },
    0x1c => { #20
        Name => 'FlashMetering',
        PrintConv => {
            0 => 'ADI (Advanced Distance Integration)',
            1 => 'Pre-flash TTL',
        },
    },
    0x1d => { #20
        Name => 'PrioritySetupShutterRelease',
        PrintConv => {
            0 => 'AF',
            1 => 'Release',
        },
    },
    0x1e => { #PH
        Name => 'DriveMode',
        PrintConv => {
            0 => 'Single Frame',
            1 => 'Continuous',
            2 => 'Self-timer',
            3 => 'Continuous Bracketing',
            4 => 'Single-Frame Bracketing',
            5 => 'White Balance Bracketing',
        },
    },
    0x1f => { #20
        Name => 'SelfTimerTime',
        PrintConv => {
            0 => '10 s',
            4 => '2 s',
        },
    },
    0x20 => { #20
        Name => 'ContinuousBracketing',
        PrintHex => 1,
        PrintConv => {
            0x303 => 'Low',
            0x703 => 'High',
        },
    },
    0x21 => { #20
        Name => 'SingleFrameBracketing',
        PrintHex => 1,
        PrintConv => {
            0x302 => 'Low',
            0x702 => 'High',
        },
    },
    0x22 => { #20
        Name => 'WhiteBalanceBracketing',
        PrintHex => 1,
        PrintConv => {
            0x08 => 'Low',
            0x09 => 'High',
        },
    },
    0x023 => { #20
        Name => 'WhiteBalanceSetting',
        PrintHex => 1,
        # (not sure what bit 0x8000 indicates)
        PrintConv => {
            0 => 'Auto',
            1 => 'Preset',
            2 => 'Custom',
            3 => 'Color Temperature/Color Filter',
            0x8001 => 'Preset',
            0x8002 => 'Custom',
            0x8003 => 'Color Temperature/Color Filter',
        },
    },
    0x24 => { #20
        Name => 'PresetWhiteBalance',
        PrintConv => {
            1 => 'Daylight',
            2 => 'Cloudy',
            3 => 'Shade',
            4 => 'Tungsten',
            5 => 'Fluorescent',
            6 => 'Flash',
        },
    },
    0x25 => { #20
        Name => 'ColorTemperatureSetting',
        PrintConv => {
            0 => 'Temperature',
            2 => 'Color Filter',
        },
    },
    0x26 => { #20
        Name => 'CustomWBSetting',
        PrintConv => {
            0 => 'Setup',
            1 => 'Recall',
        },
    },
    0x27 => { #20
        Name => 'DynamicRangeOptimizerSetting',
        Notes => 'as set in camera',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced',
        },
    },
    0x32 => 'FreeMemoryCardImages', #20
    0x34 => 'CustomWBRedLevel', #20
    0x35 => 'CustomWBGreenLevel', #20
    0x36 => 'CustomWBBlueLevel', #20
    0x37 => { #20
        Name => 'CustomWBError',
        PrintConv => {
            0 => 'OK',
            1 => 'Error',
        },
    },
    0x38 => { #20
        Name => 'WhiteBalanceFineTune',
        Format => 'int16s',
    },
    0x39 => { #20
        Name => 'ColorTemperature',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x3a => { #20
        Name => 'ColorCompensationFilter',
        Format => 'int16s',
        Notes => 'ranges from -2 for green to +2 for magenta',
    },
    0x3b => { #20
        Name => 'SonyImageSize',
        PrintConv => {
            0 => 'Standard',
            1 => 'Medium',
            2 => 'Small',
        },
    },
    0x3c => { #20
        Name => 'SonyQuality',
        PrintConv => {
            0 => 'RAW',
            32 => 'Fine',
            34 => 'RAW + JPEG',
            48 => 'Standard',
        },
    },
    0x3d => { #20
        Name => 'InstantPlaybackTime',
        PrintConv => '"$val s"',
        PrintConvInv => '$val=~s/\s*s//; $val',
    },
    0x3e => { #20
        Name => 'InstantPlaybackSetup',
        PrintConv => {
            0 => 'Image and Information',
            1 => 'Image Only',
            # 2 appears to be unused
            3 => 'Image and Histogram',
        },
    },
    0x3f => { #PH
        Name => 'NoiseReduction',
        PrintConv => \%offOn,
    },
    0x40 => { #20
        Name => 'EyeStartAF',
        PrintConv => \%onOff,
    },
    0x41 => { #20
        Name => 'RedEyeReduction',
        PrintConv => \%offOn,
    },
    0x42 => { #20
        Name => 'FlashDefault',
        PrintConv => {
            0 => 'Auto',
            1 => 'Fill Flash',
        },
    },
    0x43 => { #20
        Name => 'AutoBracketOrder',
        PrintConv => {
            0 => '0 - +',
            1 => '- 0 +',
        },
    },
    0x44 => { #20
        Name => 'FocusHoldButton',
        PrintConv => {
            0 => 'Focus Hold',
            1 => 'DOF Preview',
        },
    },
    0x45 => { #20
        Name => 'AELButton',
        PrintConv => {
            0 => 'Hold',
            1 => 'Toggle',
            2 => 'Spot Hold',
            3 => 'Spot Toggle',
        },
    },
    0x46 => { #20
        Name => 'ControlDialSet',
        PrintConv => {
            0 => 'Shutter Speed',
            1 => 'Aperture',
        },
    },
    0x47 => { #20
        Name => 'ExposureCompensationMode',
        PrintConv => {
            0 => 'Ambient and Flash',
            1 => 'Ambient Only',
        },
    },
    0x48 => { #20
        Name => 'AFAssist',
        PrintConv => \%onOff,
    },
    0x49 => { #20
        Name => 'CardShutterLock',
        PrintConv => \%onOff,
    },
    0x4a => { #20
        Name => 'LensShutterLock',
        PrintConv => \%onOff,
    },
    0x4b => { #20
        Name => 'AFAreaIllumination',
        PrintConv => {
            0 => '0.3 s',
            1 => '0.6 s',
            2 => 'Off',
        },
    },
    0x4c => { #20
        Name => 'MonitorDisplayOff',
        PrintConv => {
            0 => 'Automatic',
            1 => 'Manual',
        },
    },
    0x4d => { #20
        Name => 'RecordDisplay',
        PrintConv => {
            0 => 'Auto Rotate',
            1 => 'Horizontal',
        },
    },
    0x4e => { #20
        Name => 'PlayDisplay',
        PrintConv => {
            0 => 'Auto Rotate',
            1 => 'Manual Rotate',
        },
    },
    0x50 => { #20
        Name => 'ExposureIndicator',
        SeparateTable => 'ExposureIndicator',
        PrintConv => \%exposureIndicator,
    },
    0x51 => { #20
        Name => 'AELExposureIndicator',
        Notes => 'also indicates exposure for next shot when bracketing',
        SeparateTable => 'ExposureIndicator',
        PrintConv => \%exposureIndicator,
    },
    0x52 => { #20
        Name => 'ExposureBracketingIndicatorLast',
        Notes => 'indicator for last shot when bracketing',
        SeparateTable => 'ExposureIndicator',
        PrintConv => \%exposureIndicator,
    },
    0x53 => { #20
        Name => 'MeteringOffScaleIndicator',
        Notes => 'two flashing triangles when under or over metering scale',
        PrintConv => {
            0 => 'Within Range',
            1 => 'Under/Over Range',
            255 => 'Out of Range',
        },
    },
    0x54 => { #20
        Name => 'FlashExposureIndicator',
        SeparateTable => 'ExposureIndicator',
        PrintConv => \%exposureIndicator,
    },
    0x55 => { #20
        Name => 'FlashExposureIndicatorNext',
        Notes => 'indicator for next shot when bracketing',
        SeparateTable => 'ExposureIndicator',
        PrintConv => \%exposureIndicator,
    },
    0x56 => { #20
        Name => 'FlashExposureIndicatorLast',
        Notes => 'indicator for last shot when bracketing',
        SeparateTable => 'ExposureIndicator',
        PrintConv => \%exposureIndicator,
    },
    0x58 => { #20
        Name => 'FocusModeSwitch',
        PrintConv => {
            0 => 'AF',
            1 => 'MF',
        },
    },
    0x59 => { #20
        Name => 'FlashType',
        PrintConv => {
            0 => 'Off',
            1 => 'Built-in', # (also when built-in flash is a trigger in wireless mode)
            2 => 'External',
        },
    },
    0x5a => { #15
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (Normal)',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 90 CW',
        },
    },
    0x5b => { #20
        Name => 'AELock',
        PrintConv => \%offOn,
    },
    0x57 => { #15
        Name => 'ImageStabilization',
        PrintConv => \%offOn,
    },
    0x5e => { #15
        Name => 'ColorTemperature',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    0x5f => { #20
        Name => 'ColorCompensationFilter',
        Format => 'int16s',
        Notes => 'ranges from -2 for green to +2 for magenta',
    },
    0x60 => { #20
        Name => 'BatteryState',
        PrintConv => {
            3 => 'Very Low',
            4 => 'Low',
            5 => 'Half Full',
            6 => 'Sufficient Power Remaining',
        },
    },
);

# white balance information stored by the Sony DSLR-A100 (ref 20)
%Image::ExifTool::Minolta::WBInfoA100 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    NOTES => 'White balance information for the Sony DSLR-A100.',
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    0x0e => {
        Name => 'DriveMode',
        PrintConv => {
            0 => 'Self-timer 10 sec',
            1 => 'Continuous',
            2 => 'Single-frame Exposure Bracketing',
            3 => 'Continuous Exposure Bracketing',
            4 => 'Self-Timer 2 sec',
            5 => 'Single Frame',
            8 => 'White Balance Bracketing Low',
            9 => 'White Balance Bracketing High',
        },
    },
    0x10 => {
        Name => 'Rotation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 90 CW',
        },
    },
    0x14 => {
        Name => 'ImageStabilizationSetting',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x15 => {
        Name => 'DynamicRangeOptimizerMode',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'Advanced',
        },
    },
    0x2a => {
        Name => 'ExposureCompensationMode',
        PrintConv => {
            0 => 'Ambient and Flash',
            1 => 'Ambient Only',
        },
    },
    0x2b => 'WBBracketShotNumber',
    0x2c => {
        Name => 'WhiteBalanceBracketing',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x2d => 'ExposureBracketShotNumber',
    0x31 => {
        Name => 'FlashFunction',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x0000 => 'No flash',
            0x0300 => 'Built-in flash',
            # (the following refers to an external flash)
            0x1205 => 'Manual',
            0x120e => 'Strobe',
            #0x122e => ?
            0x128e => 'Fill flash, Pre-flash TTL',
            0x12ae => 'Bounce flash',
            0x140e => 'Rear sync, ADI',
            0x148e => 'Fill flash, ADI',
            0x1580 => 'Wireless',
            # 0x17ae => ?
            0x178e => 'HSS',
        },
    },
    0x34 => {
        Name => 'ExposureMode',
        Format => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0x0000 => 'Program',
            0x0001 => 'Aperture Priority',
            0x0002 => 'Shutter Priority',
            0x0003 => 'Manual',
            0x0004 => 'Auto',
            0x0005 => 'Program Shift A',
            0x0006 => 'Program Shift S',
            0x1013 => 'Portrait',
            0x1023 => 'Sports',
            0x1033 => 'Sunset',
            0x1043 => 'Night View/Portrait',
            0x1053 => 'Landscape',
            0x1083 => 'Macro',
        },
    },
    0x36 => {
        Name => 'ColorMode',
        Format => 'int16u',
        PrintConv => {
            0x00 => 'Standard',
            0x01 => 'Vivid',
            0x02 => 'Portrait',
            0x03 => 'Landscape',
            0x04 => 'Sunset',
            0x05 => 'Night View',
            0x07 => 'B&W',
            0x08 => 'Adobe RGB',
        },
    },
    0x38 => {
        Name => 'AverageLV',
        Format => 'int16u',
        Notes => 'arithmetic mean of the readings from the 40 honeycomb segments',
        ValueConv => '($val-106)/8',
        ValueConvInv => '$val * 8 + 106',
    },
    # 0x3a - int16u: Approx FocusDistance in metres (0x0f50=inf)
    0x3c => {
        Name => 'FrameNumber',
        # Numbers > 1 appear in continuous and continuous bracketing drive modes,
        # as well as WB bracketing.
    },
    0x96  => { Name => 'WB_RGBLevels',              Format => 'int16u[3]' },
    0xae  => { Name => 'WB_GBRGLevels',             Format => 'int16u[4]' },
    0xc0  => {
        Name => 'WB_RedLevelsTungsten',
        Notes => '7 values for adjustments of -3 through +3',
        Format => 'int16u[7]',
    },
    0xce  => { Name => 'WB_BlueLevelsTungsten',     Format => 'int16u[7]' },
    0xdc  => { Name => 'WB_RedLevelsDaylight',      Format => 'int16u[7]' },
    0xea  => { Name => 'WB_BlueLevelsDaylight',     Format => 'int16u[7]' },
    0xf8  => { Name => 'WB_RedLevelsCloudy',        Format => 'int16u[7]' },
    0x106 => { Name => 'WB_BlueLevelsCloudy',       Format => 'int16u[7]' },
    0x114 => { Name => 'WB_RedLevelsFlash',         Format => 'int16u[7]' },
    0x122 => { Name => 'WB_BlueLevelsFlash',        Format => 'int16u[7]' },
    0x14c => {
        Name => 'WB_RedLevelsFluorescent',
        Format => 'int16u[7]',
        Notes => q{
            white balance red presets for fluorescent -2 through +4:  -2=Fluorescent,
            -1=WhiteFluorescent, 0=CoolWhiteFluorescent, +1=DayWhiteFluorescent and
            +3=DaylightFluorescent
        },
    },
    0x15a => { Name => 'WB_BlueLevelsFluorescent',  Format => 'int16u[7]' },
    0x168 => { Name => 'WB_RedLevelsShade',         Format => 'int16u[7]' },
    0x176 => { Name => 'WB_BlueLevelsShade',        Format => 'int16u[7]' },
    0x188 => { Name => 'WB_RedLevel6500K',          Format => 'int16u' },
    0x18a => { Name => 'WB_BlueLevel6500K',         Format => 'int16u' },
    0x18c => { Name => 'WB_RedLevelCustom',         Format => 'int16u' },
    0x18e => { Name => 'WB_BlueLevelCustom',        Format => 'int16u' },
    0x198 => { Name => 'WB_RedLevel3500K',          Format => 'int16u' },
    0x19a => { Name => 'WB_BlueLevel3500K',         Format => 'int16u' },
    0x1be => {
        Name => 'WB_RedLevelsKelvin',
        Format => 'int16u[75]',
        Notes => 'values for 2500-9900 K, in increments of 100 K',
    },
    0x254 => { Name => 'WB_BlueLevelsKelvin',       Format => 'int16u[75]' },
    0x304 => { Name => 'WB_RBLevelsFlash',          Format => 'int16u[2]' },
    0x308 => { Name => 'WB_RBLevelsCoolWhiteF',     Format => 'int16u[2]' },
    0x3e8 => { Name => 'WB_RBLevelsTungsten',       Format => 'int16u[2]' },
    0x3ec => { Name => 'WB_RBLevelsDaylight',       Format => 'int16u[2]' },
    0x3f0 => { Name => 'WB_RBLevelsCloudy',         Format => 'int16u[2]' },
    0x3f4 => { Name => 'WB_RBLevelsFlash',          Format => 'int16u[2]' },
    0x3fc => { Name => 'WB_RedLevelsFluorescent',   Format => 'int16u[7]' },
    0x40a => { Name => 'WB_BlueLevelsFluorescent',  Format => 'int16u[7]' },
    0x418 => { Name => 'WB_RBLevelsShade',          Format => 'int16u[2]' },
    0x420 => { Name => 'WB_RBLevels6500K',          Format => 'int16u[2]' },
    0x424 => { Name => 'WB_RBLevelsCustom',         Format => 'int16u[2]' },
    0x430 => { Name => 'WB_RBLevels3500K',          Format => 'int16u[2]' },
    0x528 => { Name => 'WB_RBLevelsDaylight',       Format => 'int16u[2]' },
    0x546 => { Name => 'WB_RGBLevels',              Format => 'int16u[3]' },
    0x628 => {
        Name => 'AEMeteringSegments',
        Format => 'int8u[40]',
        Notes => q{
            metering values from the 40 honeycomb segments, converted to LV.  The first
            value is for the outer cell, then the values are given row by row, from top
            to bottom, with each row scanned left-to-right.  The 21st value is the
            middle cell, which gives the spot metering
        },
        ValueConv    => sub { join ' ', map( { ($_ - 106) / 8 } split(' ',$_[0]) ) },
        ValueConvInv => sub { join ' ', map( { int($_ * 8 + 106.5) } split(' ',$_[0]) ) },
    },
    0x690 => {
        Name => 'MeasuredLV',
        Notes => 'measured light value based on MeteringMode',
        ValueConv => '($val-106)/8',
        ValueConvInv => '$val * 8 + 106',
    },
    0x691 => {
        Name => 'BrightnessValue',
        ValueConv => '($val-106)/8',
        ValueConvInv => '$val * 8 + 106',
    },
    # 0x87f - int8u: 33mm Equivalent magnification (FocusDistance = (1.5 * $val + 1) * FocalLength) (255=inf)
    0x104c => { # (9600 bytes: 4 sets of 40x30 int16u values in the range 0-8191)
        Name => 'TiffMeteringImage',
        Format => 'undef[9600]',
        Notes => q{
            13-bit RBGG (?) 40x30 pixels, presumably metering info, converted to a 16-bit
            TIFF image;
        },
        ValueConv => sub {
            my ($val, $et) = @_;
            return undef unless length $val >= 9600;
            return \ "Binary data 7404 bytes" unless $et->Options('Binary');
            my @dat = unpack('n*', $val);  # for Big-endian
            # TIFF header for a 16-bit RGB 10dpi 40x30 image
            $val = Image::ExifTool::MakeTiffHeader(40,30,3,16,10);
            # re-order data to RGB pixels
            my ($i, @val);
            for ($i=0; $i<40*30; ++$i) {
                # data is 13-bit (max 8191), shift left to fill 16 bits
                # (typically, this gives a very dark image since the data should
                # really be anti-logged to convert from EV to perceived brightness)
#                 push @val, $dat[$i]<<3, $dat[$i+2400]<<3, $dat[$i+1200]<<3;
                push @val, int(5041.1*log($dat[$i]+1)/log(2)), int(5041.1*log($dat[$i+2400]+1)/log(2)), int(5041.1*log($dat[$i+1200]+1)/log(2));
            }
            $val .= pack('v*', @val);   # add TIFF strip data
            return \$val;
        },
    },
    0x49b8 => {
        Name => 'ExposureTime',
        ValueConv => '$val ? 2 ** (6 - $val/8) : 0',
        ValueConvInv => '$val ? int((6 - log($val) / log(2)) * 8 + 0.5) : 0',
        PrintConv => '$val ? Image::ExifTool::Exif::PrintExposureTime($val) : "Bulb"',
        PrintConvInv => 'lc($val) eq "bulb" ? 0 : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x49ba => {
        Name => 'ISO',
        ValueConv => '2 ** (($val-48)/8) * 100',
        ValueConvInv => '48 + 8*log($val/100)/log(2)',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    0x49bb => { # (https://exiftool.org/forum/index.php/topic,3688.0.html)
        # if this value is the 35mm equivalent magnification, then the formula could
        # be (1.5 * 2**($val/16-5)+1) * FocalLength, but this tends to underestimate
        # distance by about 18% (ref 20) (255=inf)
        Name => 'FocusDistance',
        ValueConv => '2**(($val-126)/16)',
        ValueConvInv => 'log($val)/log(2)*16+126',
        PrintConv => '$val > 266 ? "inf" : sprintf("%.2f m", $val)',
        PrintConvInv => '$val=~s/ ?m//; $val=~/inf/i ? 267 : $val',
    },
    0x49bd => {
        Name => 'LensType',
        Format => 'int16uRev',
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%minoltaLensTypes,
        PrintInt => 1,
    },
    0x49c0 => {
        Name => 'ExposureCompensation', # (in exposure bracketing, this is the actual value used)
        Format => 'int8s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x49c1 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        Format => 'int8s',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
        PrintConv => '$val ? sprintf("%+.1f",$val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x49c2 => {
        Name => 'ImageStabilization',
        PrintConv => \%offOn,
    },
    0x49c3 => {
        Name => 'BrightnessValue',
        ValueConv => '($val-106)/8',
        ValueConvInv => '$val * 8 + 106',
    },
    0x49c5 => {
        Name => 'MaxAperture',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    # 0x49c6 - gives focal length using same formula as 0x49bb
    0x49c7 => {
        Name => 'FNumber',
        ValueConv => '2 ** (($val-8)/16)',
        ValueConvInv => '8 + 16*log($val)/log(2)',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x49dc => {
        Name => 'InternalSerialNumber',
        Format => 'string[12]',
    },
);

# tags in Konica Minolta MOV videos (ref PH)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Minolta::MOV1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in MOV videos from some Konica Minolta models such
        as the DiMage Z10 and X50.
    },
    0 => {
        Name => 'Make',
        Format => 'string[32]',
    },
    0x20 => {
        Name => 'ModelType',
        Format => 'string[8]',
    },
    # (01 00 at offset 0x28)
    0x2e => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x32 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x3a => {
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    # 0x4c => 'WhiteBalance', ?
    0x50 => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
);

# tags in Minolta MOV videos (ref PH)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Minolta::MOV2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in MOV videos from some Minolta models such as the
        DiMAGE X and Xt.
    },
    0 => {
        Name => 'Make',
        Format => 'string[32]',
    },
    0x18 => {
        Name => 'ModelType',
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
    # 0x44 => 'WhiteBalance', ?
    0x48 => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
);

# more tags in Minolta MOV videos (ref PH)
%Image::ExifTool::Minolta::MMA = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This information is found in MOV videos from Minolta models such as the
        DiMAGE A2, S414 and 7Hi.
    },
    0 => {
        Name => 'Make',
        Format => 'string[20]',
    },
    20 => {
        Name => 'SoftwareVersion',
        Format => 'string[16]',
    },
);

# basic Minolta white balance lookup
my %minoltaWhiteBalance = (
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    5 => 'Custom',
    7 => 'Fluorescent',
    8 => 'Fluorescent 2',
    11 => 'Custom 2',
    12 => 'Custom 3',
    # the following come from tests with the A2 (ref 2)
    0x0800000 => 'Auto',
    0x1800000 => 'Daylight',
    0x2800000 => 'Cloudy',
    0x3800000 => 'Tungsten',
    0x4800000 => 'Flash',
    0x5800000 => 'Fluorescent',
    0x6800000 => 'Shade',
    0x7800000 => 'Custom1',
    0x8800000 => 'Custom2',
    0x9800000 => 'Custom3',
);

#------------------------------------------------------------------------------
# PrintConv for Minolta white balance
sub ConvertWhiteBalance($)
{
    my $val = shift;
    my $printConv = $minoltaWhiteBalance{$val};
    unless (defined $printConv) {
        if ($val & 0xffff0000) {
            # the A2 values can be shifted by +- 3 settings, where
            # each setting adds or subtracts 0x0010000 (ref 2)
            my $type = ($val & 0xff000000) + 0x800000;
            if ($minoltaWhiteBalance{$type}) {
                $printConv = $minoltaWhiteBalance{$type} .
                             sprintf("%+.8g", ($val - $type) / 0x10000);
            } else {
                $printConv = sprintf("Unknown (0x%x)", $val);
            }
        } else {
            $printConv = sprintf("Unknown ($val)");
        }
    }
    return $printConv;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Minolta - Minolta EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Minolta and Konica-Minolta maker notes in EXIF information, and to read
and write Minolta RAW (MRW) images.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.dalibor.cz/minolta/makernote.htm>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Jay Al-Saadi, Niels Kristian Bech Jensen, Shingo Noguchi, Pedro
Corte-Real, Jeffery Small, Jens Duttke,  Thomas Kassner, Mladen Sever, Olaf
Ulrich, Lukasz Stelmach, Igal Milchtaich, Jos Roost and Michael Reitinger
for the information they provided, and for everyone who helped with the
LensType list.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Minolta Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
