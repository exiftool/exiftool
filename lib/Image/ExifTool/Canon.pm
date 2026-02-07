#------------------------------------------------------------------------------
# File:         Canon.pm
#
# Description:  Canon EXIF maker notes tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               12/03/2003 - P. Harvey Decode lots more tags and add CanonAFInfo
#               02/17/2004 - Michael Rommel Added IxusAFPoint
#               01/27/2005 - P. Harvey Disable validation of CanonAFInfo
#               01/30/2005 - P. Harvey Added a few more tags (ref 4)
#               02/10/2006 - P. Harvey Decode a lot of new tags (ref 12)
#               [ongoing]  - P. Harvey Constantly decoding new information
#
# Notes:        Must check FocalPlaneX/YResolution values for each new model!
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) Michael Rommel private communication (Digital Ixus)
#               3) Daniel Pittman private communication (PowerShot S70)
#               4) http://www.wonderland.org/crw/
#               5) Juha Eskelinen private communication (20D)
#               6) Richard S. Smith private communication (20D)
#               7) Denny Priebe private communication (1DmkII)
#               8) Irwin Poche private communication
#               9) Michael Tiemann private communication (1DmkII)
#              10) Volker Gering private communication (1DmkII)
#              11) "cip" private communication
#              12) Rainer Honle private communication (5D)
#              13) http://www.cybercom.net/~dcoffin/dcraw/
#              14) (bozi) http://www.cpanforum.com/threads/2476 and /2563
#              15) http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm (2007/11/19)
#                + http://homepage3.nifty.com/kamisaka/makernote/CanonLens.htm (2007/11/19)
#              16) Emil Sit private communication (30D)
#              17) http://www.asahi-net.or.jp/~xp8t-ymzk/s10exif.htm
#              18) Samson Tai private communication (G7)
#              19) Warren Stockton private communication
#              20) Bogdan private communication
#              21) Heiko Hinrichs private communication
#              22) Dave Nicholson private communication (PowerShot S30)
#              23) Magne Nilsen private communication (400D)
#              24) Wolfgang Hoffmann private communication (40D)
#              25) Laurent Clevy private communication
#              26) Steve Balcombe private communication
#              27) Chris Huebsch private communication (40D)
#              28) Hal Williamson private communication (XTi)
#              29) Ger Vermeulen private communication
#              30) David Pitcher private communication (1DmkIII)
#              31) Darryl Zurn private communication (A590IS)
#              32) Rich Taylor private communication (5D)
#              33) D.J. Cristi private communication
#              34) Andreas Huggel and Pascal de Bruijn private communication
#              35) Jan Boelsma private communication
#              36) Karl-Heinz Klotz private communication (http://www.dslr-forum.de/showthread.php?t=430900)
#              37) Vesa Kivisto private communication (30D)
#              38) Kurt Garloff private communication (5DmkII)
#              39) Irwin Poche private communication (5DmkII)
#              40) Jose Oliver-Didier private communication
#              41) http://www.cpanforum.com/threads/10730
#              42) Norbert Wasser private communication
#              43) Karsten Sote private communication
#              44) Hugh Griffiths private communication (5DmkII)
#              45) Mark Berger private communication (5DmkII)
#              46) Dieter Steiner private communication (7D)
#              47) http://www.exiv2.org/
#              48) Tomasz A. Kawecki private communication (550D, firmware 1.0.6, 1.0.8)
#              49) http://www.listware.net/201101/digikam-users/49795-digikam-users-re-lens-recognition.html
#              50) https://exiftool.org/forum/index.php/topic,3833.0.html
#              51) https://exiftool.org/forum/index.php/topic,4110.0.html
#              52) Kai Harrekilde-Petersen private communication
#              53) Anton Reiser private communication
#              54) https://github.com/lclevy/canon_cr3
#              IB) Iliah Borg private communication (LibRaw)
#              JD) Jens Duttke private communication
#              JR) Jos Roost private communication
#              NJ) Niels Kristian Bech Jensen private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Canon;

use strict;
use vars qw($VERSION %canonModelID %canonLensTypes);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

sub WriteCanon($$$);
sub ProcessSerialData($$$);
sub ProcessFilters($$$);
sub ProcessCTMD($$$);
sub ProcessExifInfo($$$);
sub SwapWords($);

$VERSION = '5.03';

# Note: Removed 'USM' from 'L' lenses since it is redundant - PH
# (or is it?  Ref 32 shows 5 non-USM L-type lenses)
# --> have relaxed this for new lenses because Canon has been
#     consistent about keeping "USM" in the model name
%canonLensTypes = ( #4
    -1 => 'n/a',
     1 => 'Canon EF 50mm f/1.8',
     2 => 'Canon EF 28mm f/2.8 or Sigma Lens',
     2.1 => 'Sigma 24mm f/2.8 Super Wide II', #ClaudeJolicoeur
     # (3 removed in current Kamisaka list)
     3 => 'Canon EF 135mm f/2.8 Soft', #15/32
     4 => 'Canon EF 35-105mm f/3.5-4.5 or Sigma Lens', #28
     4.1 => 'Sigma UC Zoom 35-135mm f/4-5.6',
     5 => 'Canon EF 35-70mm f/3.5-4.5', #32
     6 => 'Canon EF 28-70mm f/3.5-4.5 or Sigma or Tokina Lens', #32
     6.1 => 'Sigma 18-50mm f/3.5-5.6 DC', #23
     6.2 => 'Sigma 18-125mm f/3.5-5.6 DC IF ASP',
     6.3 => 'Tokina AF 193-2 19-35mm f/3.5-4.5',
     6.4 => 'Sigma 28-80mm f/3.5-5.6 II Macro', #47
     6.5 => 'Sigma 28-300mm f/3.5-6.3 DG Macro', #IB
     7 => 'Canon EF 100-300mm f/5.6L', #15
     8 => 'Canon EF 100-300mm f/5.6 or Sigma or Tokina Lens', #32
     8.1 => 'Sigma 70-300mm f/4-5.6 [APO] DG Macro', #15 (both APO and non-APO, ref forum2947)
     8.2 => 'Tokina AT-X 242 AF 24-200mm f/3.5-5.6', #15
     9 => 'Canon EF 70-210mm f/4', #32
     9.1 => 'Sigma 55-200mm f/4-5.6 DC', #34
    10 => 'Canon EF 50mm f/2.5 Macro or Sigma Lens', #10 (+ LSC Life Size Converter --> 70mm - PH)
    10.1 => 'Sigma 50mm f/2.8 EX', #4
    10.2 => 'Sigma 28mm f/1.8',
    10.3 => 'Sigma 105mm f/2.8 Macro EX', #15
    10.4 => 'Sigma 70mm f/2.8 EX DG Macro EF', #Jean-Michel Dubois
    11 => 'Canon EF 35mm f/2', #9
    13 => 'Canon EF 15mm f/2.8 Fisheye', #9
    14 => 'Canon EF 50-200mm f/3.5-4.5L', #32
    15 => 'Canon EF 50-200mm f/3.5-4.5', #32
    16 => 'Canon EF 35-135mm f/3.5-4.5', #32
    17 => 'Canon EF 35-70mm f/3.5-4.5A', #32
    18 => 'Canon EF 28-70mm f/3.5-4.5', #32
    20 => 'Canon EF 100-200mm f/4.5A', #32
    21 => 'Canon EF 80-200mm f/2.8L',
    22 => 'Canon EF 20-35mm f/2.8L or Tokina Lens', #32
    22.1 => 'Tokina AT-X 280 AF Pro 28-80mm f/2.8 Aspherical', #15
    23 => 'Canon EF 35-105mm f/3.5-4.5', #32
    24 => 'Canon EF 35-80mm f/4-5.6 Power Zoom', #32
    25 => 'Canon EF 35-80mm f/4-5.6 Power Zoom', #32
    26 => 'Canon EF 100mm f/2.8 Macro or Other Lens',
    26.1 => 'Cosina 100mm f/3.5 Macro AF',
    26.2 => 'Tamron SP AF 90mm f/2.8 Di Macro', #15
    26.3 => 'Tamron SP AF 180mm f/3.5 Di Macro', #15
    26.4 => 'Carl Zeiss Planar T* 50mm f/1.4', #PH
    26.5 => 'Voigtlander APO Lanthar 125mm F2.5 SL Macro', #JR
    26.6 => 'Carl Zeiss Planar T 85mm f/1.4 ZE', #IB
    27 => 'Canon EF 35-80mm f/4-5.6', #32
    # 27 => 'Carl Zeiss Distagon T* 28mm f/2 ZF', #PH (must be with an adapter, because the ZF version is a Nikon mount)
    # 27 => 'EMF adapter for Canon EOS digital cameras', #50 (reports MaxFocalLength of 65535)
    # 27 => optix adapter
    # 27 => Venus Optics Laowa 12mm f2.8 Zero-D or 105mm f2 (T3.2) Smooth Trans Focus (ref IB)
    # 27 => Venus Optics Laowa 105mm f2 STF (ref IB)
    28 => 'Canon EF 80-200mm f/4.5-5.6 or Tamron Lens', #32
    28.1 => 'Tamron SP AF 28-105mm f/2.8 LD Aspherical IF', #15
    28.2 => 'Tamron SP AF 28-75mm f/2.8 XR Di LD Aspherical [IF] Macro', #4
  # 28.3 => 'Tamron AF 70-300mm f/4.5-5.6 Di LD 1:2 Macro Zoom', #11
    28.3 => 'Tamron AF 70-300mm f/4-5.6 Di LD 1:2 Macro', #47
    28.4 => 'Tamron AF Aspherical 28-200mm f/3.8-5.6', #14
    29 => 'Canon EF 50mm f/1.8 II',
    30 => 'Canon EF 35-105mm f/4.5-5.6', #32
    31 => 'Canon EF 75-300mm f/4-5.6 or Tamron Lens', #32
    31.1 => 'Tamron SP AF 300mm f/2.8 LD IF', #15
    32 => 'Canon EF 24mm f/2.8 or Sigma Lens', #10
    32.1 => 'Sigma 15mm f/2.8 EX Fisheye', #11
    33 => 'Voigtlander or Carl Zeiss Lens',
    33.1 => 'Voigtlander Ultron 40mm f/2 SLII Aspherical', #45
    33.2 => 'Voigtlander Color Skopar 20mm f/3.5 SLII Aspherical', #50
    33.3 => 'Voigtlander APO-Lanthar 90mm f/3.5 SLII Close Focus', #50
    33.4 => 'Carl Zeiss Distagon T* 15mm f/2.8 ZE', #PH
    33.5 => 'Carl Zeiss Distagon T* 18mm f/3.5 ZE', #PH
    33.6 => 'Carl Zeiss Distagon T* 21mm f/2.8 ZE', #PH
    33.7 => 'Carl Zeiss Distagon T* 25mm f/2 ZE', #IB
    33.8 => 'Carl Zeiss Distagon T* 28mm f/2 ZE', #PH
    33.9 => 'Carl Zeiss Distagon T* 35mm f/2 ZE', #PH
   '33.10' => 'Carl Zeiss Distagon T* 35mm f/1.4 ZE', #IB
   '33.11' => 'Carl Zeiss Planar T* 50mm f/1.4 ZE', #IB
   '33.12' => 'Carl Zeiss Makro-Planar T* 50mm f/2 ZE', #IB
   '33.13' => 'Carl Zeiss Makro-Planar T* 100mm f/2 ZE', #IB
   '33.14' => 'Carl Zeiss Apo-Sonnar T* 135mm f/2 ZE', #JR
    35 => 'Canon EF 35-80mm f/4-5.6', #32
    36 => 'Canon EF 38-76mm f/4.5-5.6', #32
    37 => 'Canon EF 35-80mm f/4-5.6 or Tamron Lens', #32
    37.1 => 'Tamron 70-200mm f/2.8 Di LD IF Macro', #PH
    37.2 => 'Tamron AF 28-300mm f/3.5-6.3 XR Di VC LD Aspherical [IF] Macro (A20)', #38
    37.3 => 'Tamron SP AF 17-50mm f/2.8 XR Di II VC LD Aspherical [IF]', #34
    37.4 => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC LD Aspherical [IF] Macro', #forum2937
    38 => 'Canon EF 80-200mm f/4.5-5.6 II', #32 (II added ref https://github.com/Exiv2/exiv2/issues/1906)
    39 => 'Canon EF 75-300mm f/4-5.6',
    40 => 'Canon EF 28-80mm f/3.5-5.6',
    41 => 'Canon EF 28-90mm f/4-5.6', #32
    42 => 'Canon EF 28-200mm f/3.5-5.6 or Tamron Lens', #32
    42.1 => 'Tamron AF 28-300mm f/3.5-6.3 XR Di VC LD Aspherical [IF] Macro (A20)', #15
    43 => 'Canon EF 28-105mm f/4-5.6', #10
    44 => 'Canon EF 90-300mm f/4.5-5.6', #32
    45 => 'Canon EF-S 18-55mm f/3.5-5.6 [II]', #PH (same ID for version II, ref 20)
    46 => 'Canon EF 28-90mm f/4-5.6', #32
  # 46 => 'Tamron 28-300mm f/3.5-6.3 Di VC PZD (A010)', # (also possibly?)
    47 => 'Zeiss Milvus 35mm f/2 or 50mm f/2', #IB
    47.1 => 'Zeiss Milvus 50mm f/2 Makro', #IB
    47.2 => 'Zeiss Milvus 135mm f/2 ZE', #IB
    48 => 'Canon EF-S 18-55mm f/3.5-5.6 IS', #20
    49 => 'Canon EF-S 55-250mm f/4-5.6 IS', #23
    50 => 'Canon EF-S 18-200mm f/3.5-5.6 IS',
    51 => 'Canon EF-S 18-135mm f/3.5-5.6 IS', #PH
    52 => 'Canon EF-S 18-55mm f/3.5-5.6 IS II', #PH
    53 => 'Canon EF-S 18-55mm f/3.5-5.6 III', #Jon Charnas
    54 => 'Canon EF-S 55-250mm f/4-5.6 IS II', #47
    60 => 'Irix 11mm f/4 or 15mm f/2.4', #50
    60.1 => 'Irix 15mm f/2.4', #forum15655
    63 => 'Irix 30mm F1.4 Dragonfly', #IB
    80 => 'Canon TS-E 50mm f/2.8L Macro', #42
    81 => 'Canon TS-E 90mm f/2.8L Macro', #42
    82 => 'Canon TS-E 135mm f/4L Macro', #42
    94 => 'Canon TS-E 17mm f/4L', #42
    95 => 'Canon TS-E 24mm f/3.5L II', #43
    103 => 'Samyang AF 14mm f/2.8 EF or Rokinon Lens', #IB
    103.1 => 'Rokinon SP 14mm f/2.4', #IB
    103.2 => 'Rokinon AF 14mm f/2.8 EF', #IB
    106 => 'Rokinon SP / Samyang XP 35mm f/1.2', #IB
    112 => 'Sigma 28mm f/1.5 FF High-speed Prime or other Sigma Lens', #IB
    112.1 => 'Sigma 40mm f/1.5 FF High-speed Prime', #IB
    112.2 => 'Sigma 105mm f/1.5 FF High-speed Prime', #IB
    117 => 'Tamron 35-150mm f/2.8-4.0 Di VC OSD (A043) or other Tamron Lens', #IB
    117.1 => 'Tamron SP 35mm f/1.4 Di USD (F045)', #Exiv2#1064
    124 => 'Canon MP-E 65mm f/2.8 1-5x Macro Photo', #9
    125 => 'Canon TS-E 24mm f/3.5L',
    126 => 'Canon TS-E 45mm f/2.8', #15
    127 => 'Canon TS-E 90mm f/2.8 or Tamron Lens', #15
    127.1 => 'Tamron 18-200mm f/3.5-6.3 Di II VC (B018)', #TomLachecki
    129 => 'Canon EF 300mm f/2.8L USM', #32
    130 => 'Canon EF 50mm f/1.0L USM', #10/15
    131 => 'Canon EF 28-80mm f/2.8-4L USM or Sigma Lens', #32
    131.1 => 'Sigma 8mm f/3.5 EX DG Circular Fisheye', #15
    131.2 => 'Sigma 17-35mm f/2.8-4 EX DG Aspherical HSM', #15
    131.3 => 'Sigma 17-70mm f/2.8-4.5 DC Macro', #PH (NC)
    131.4 => 'Sigma APO 50-150mm f/2.8 [II] EX DC HSM', #15 ([II] ref PH)
    131.5 => 'Sigma APO 120-300mm f/2.8 EX DG HSM', #15
           # 'Sigma APO 120-300mm f/2.8 EX DG HSM + 1.4x', #15
           # 'Sigma APO 120-300mm f/2.8 EX DG HSM + 2x', #15
    131.6 => 'Sigma 4.5mm f/2.8 EX DC HSM Circular Fisheye', #PH
    131.7 => 'Sigma 70-200mm f/2.8 APO EX HSM', #PH (http://www.lensrentals.com/blog/2012/08/canon-illumination-correction-and-third-party-lenses)
    131.8 => 'Sigma 28-70mm f/2.8-4 DG', #IB
    132 => 'Canon EF 1200mm f/5.6L USM', #32
    134 => 'Canon EF 600mm f/4L IS USM', #15
    135 => 'Canon EF 200mm f/1.8L USM',
    136 => 'Canon EF 300mm f/2.8L USM',
    136.1 => 'Tamron SP 15-30mm f/2.8 Di VC USD (A012)', #TomLachecki
    137 => 'Canon EF 85mm f/1.2L USM or Sigma or Tamron Lens', #10
    137.1 => 'Sigma 18-50mm f/2.8-4.5 DC OS HSM', #PH
    137.2 => 'Sigma 50-200mm f/4-5.6 DC OS HSM', #PH
    137.3 => 'Sigma 18-250mm f/3.5-6.3 DC OS HSM', #PH (also Sigma 18-250mm f/3.5-6.3 DC Macro OS HSM)
    137.4 => 'Sigma 24-70mm f/2.8 IF EX DG HSM', #PH
    137.5 => 'Sigma 18-125mm f/3.8-5.6 DC OS HSM', #PH
    137.6 => 'Sigma 17-70mm f/2.8-4 DC Macro OS HSM | C', #forum2819 (Contemporary version has this ID - PH)
    137.7 => 'Sigma 17-50mm f/2.8 OS HSM', #47
    137.8 => 'Sigma 18-200mm f/3.5-6.3 DC OS HSM [II]', #PH
    137.9 => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC PZD (B008)', #forum3090
   '137.10' => 'Sigma 8-16mm f/4.5-5.6 DC HSM', #50-Zwielicht
   '137.11' => 'Tamron SP 17-50mm f/2.8 XR Di II VC (B005)', #50
   '137.12' => 'Tamron SP 60mm f/2 Macro Di II (G005)', #50
   '137.13' => 'Sigma 10-20mm f/3.5 EX DC HSM', #Gerald Erdmann
   '137.14' => 'Tamron SP 24-70mm f/2.8 Di VC USD', #PH
   '137.15' => 'Sigma 18-35mm f/1.8 DC HSM', #David Monro
   '137.16' => 'Sigma 12-24mm f/4.5-5.6 DG HSM II', #IB
   '137.17' => 'Sigma 70-300mm f/4-5.6 DG OS', #IB
    138 => 'Canon EF 28-80mm f/2.8-4L', #32
    139 => 'Canon EF 400mm f/2.8L USM',
    140 => 'Canon EF 500mm f/4.5L USM', #32
    141 => 'Canon EF 500mm f/4.5L USM',
    142 => 'Canon EF 300mm f/2.8L IS USM', #15
    143 => 'Canon EF 500mm f/4L IS USM or Sigma Lens', #15
    143.1 => 'Sigma 17-70mm f/2.8-4 DC Macro OS HSM', #NJ (Exiv2 #1167)
    144 => 'Canon EF 35-135mm f/4-5.6 USM', #26
    145 => 'Canon EF 100-300mm f/4.5-5.6 USM', #32
    146 => 'Canon EF 70-210mm f/3.5-4.5 USM', #32
    147 => 'Canon EF 35-135mm f/4-5.6 USM', #32
    148 => 'Canon EF 28-80mm f/3.5-5.6 USM', #32
    149 => 'Canon EF 100mm f/2 USM', #9
    150 => 'Canon EF 14mm f/2.8L USM or Sigma Lens', #10
    150.1 => 'Sigma 20mm EX f/1.8', #4
    150.2 => 'Sigma 30mm f/1.4 DC HSM', #15
    150.3 => 'Sigma 24mm f/1.8 DG Macro EX', #15
    150.4 => 'Sigma 28mm f/1.8 DG Macro EX', #IB
    150.5 => 'Sigma 18-35mm f/1.8 DC HSM | A', #IB
    151 => 'Canon EF 200mm f/2.8L USM',
    152 => 'Canon EF 300mm f/4L IS USM or Sigma Lens', #15
    152.1 => 'Sigma 12-24mm f/4.5-5.6 EX DG ASPHERICAL HSM', #15
    152.2 => 'Sigma 14mm f/2.8 EX Aspherical HSM', #15
    152.3 => 'Sigma 10-20mm f/4-5.6', #14
    152.4 => 'Sigma 100-300mm f/4', # (ref Bozi)
    152.5 => 'Sigma 300-800mm f/5.6 APO EX DG HSM', #IB
    153 => 'Canon EF 35-350mm f/3.5-5.6L USM or Sigma or Tamron Lens', #PH
    153.1 => 'Sigma 50-500mm f/4-6.3 APO HSM EX', #15
    153.2 => 'Tamron AF 28-300mm f/3.5-6.3 XR LD Aspherical [IF] Macro',
    153.3 => 'Tamron AF 18-200mm f/3.5-6.3 XR Di II LD Aspherical [IF] Macro (A14)', #15
    153.4 => 'Tamron 18-250mm f/3.5-6.3 Di II LD Aspherical [IF] Macro', #PH
    154 => 'Canon EF 20mm f/2.8 USM or Zeiss Lens', #15
    154.1 => 'Zeiss Milvus 21mm f/2.8', #IB
    154.2 => 'Zeiss Milvus 15mm f/2.8 ZE', #IB
    154.3 => 'Zeiss Milvus 18mm f/2.8 ZE', #IB
    155 => 'Canon EF 85mm f/1.8 USM or Sigma Lens',
    155.1 => 'Sigma 14mm f/1.8 DG HSM | A', #IB (A017)
    156 => 'Canon EF 28-105mm f/3.5-4.5 USM or Tamron Lens',
    156.1 => 'Tamron SP 70-300mm f/4-5.6 Di VC USD (A005)', #PH
    156.2 => 'Tamron SP AF 28-105mm f/2.8 LD Aspherical IF (176D)', #JR
    160 => 'Canon EF 20-35mm f/3.5-4.5 USM or Tamron or Tokina Lens',
    160.1 => 'Tamron AF 19-35mm f/3.5-4.5', #44
    160.2 => 'Tokina AT-X 124 AF Pro DX 12-24mm f/4', #49
    160.3 => 'Tokina AT-X 107 AF DX 10-17mm f/3.5-4.5 Fisheye', #PH (http://osdir.com/ml/digikam-devel/2011-04/msg00275.html)
    160.4 => 'Tokina AT-X 116 AF Pro DX 11-16mm f/2.8', #forum3967
    160.5 => 'Tokina AT-X 11-20 F2.8 PRO DX Aspherical 11-20mm f/2.8', #NJ (Exiv2 #1166)
    161 => 'Canon EF 28-70mm f/2.8L USM or Other Lens',
    161.1 => 'Sigma 24-70mm f/2.8 EX',
    161.2 => 'Sigma 28-70mm f/2.8 EX', #PH (http://www.breezesys.com/forum/showthread.php?t=3718)
    161.3 => 'Sigma 24-60mm f/2.8 EX DG', #PH (http://www.lensrentals.com/blog/2012/08/canon-illumination-correction-and-third-party-lenses)
    161.4 => 'Tamron AF 17-50mm f/2.8 Di-II LD Aspherical', #40
    161.5 => 'Tamron 90mm f/2.8',
    161.6 => 'Tamron SP AF 17-35mm f/2.8-4 Di LD Aspherical IF (A05)', #IB
    161.7 => 'Tamron SP AF 28-75mm f/2.8 XR Di LD Aspherical [IF] Macro', #IB/NJ
    161.8 => 'Tokina AT-X 24-70mm f/2.8 PRO FX (IF)', #IB
    162 => 'Canon EF 200mm f/2.8L USM', #32
    163 => 'Canon EF 300mm f/4L', #32
    164 => 'Canon EF 400mm f/5.6L', #32
    165 => 'Canon EF 70-200mm f/2.8L USM',
    166 => 'Canon EF 70-200mm f/2.8L USM + 1.4x',
    167 => 'Canon EF 70-200mm f/2.8L USM + 2x',
    168 => 'Canon EF 28mm f/1.8 USM or Sigma Lens', #15
    168.1 => 'Sigma 50-100mm f/1.8 DC HSM | A', #IB
    169 => 'Canon EF 17-35mm f/2.8L USM or Sigma Lens', #15
    169.1 => 'Sigma 18-200mm f/3.5-6.3 DC OS', #23
    169.2 => 'Sigma 15-30mm f/3.5-4.5 EX DG Aspherical', #4
    169.3 => 'Sigma 18-50mm f/2.8 Macro', #26
    169.4 => 'Sigma 50mm f/1.4 EX DG HSM', #PH
    169.5 => 'Sigma 85mm f/1.4 EX DG HSM', #Rolando Ruzic
    169.6 => 'Sigma 30mm f/1.4 EX DC HSM', #Rodolfo Borges
    169.7 => 'Sigma 35mm f/1.4 DG HSM', #PH (also "| A" version, ref 50)
    169.8 => 'Sigma 35mm f/1.5 FF High-Speed Prime | 017', #IB
    169.9 => 'Sigma 70mm f/2.8 Macro EX DG', #IB
    170 => 'Canon EF 200mm f/2.8L II USM or Sigma Lens', #9
    170.1 => 'Sigma 300mm f/2.8 APO EX DG HSM', #IB
    170.2 => 'Sigma 800mm f/5.6 APO EX DG HSM', #IB
    171 => 'Canon EF 300mm f/4L USM', #15
    172 => 'Canon EF 400mm f/5.6L USM or Sigma Lens', #32
    172.1 =>'Sigma 150-600mm f/5-6.3 DG OS HSM | S', #50
    172.2 => 'Sigma 500mm f/4.5 APO EX DG HSM', #IB
    173 => 'Canon EF 180mm Macro f/3.5L USM or Sigma Lens', #9
    173.1 => 'Sigma 180mm EX HSM Macro f/3.5', #14
    173.2 => 'Sigma APO Macro 150mm f/2.8 EX DG HSM', #14
    173.3 => 'Sigma 10mm f/2.8 EX DC Fisheye', #IB
    173.4 => 'Sigma 15mm f/2.8 EX DG Diagonal Fisheye', #IB
    173.5 => 'Venus Laowa 100mm F2.8 2X Ultra Macro APO', #IB
    174 => 'Canon EF 135mm f/2L USM or Other Lens', #9
    174.1 => 'Sigma 70-200mm f/2.8 EX DG APO OS HSM', #PH (probably version II of this lens)
    174.2 => 'Sigma 50-500mm f/4.5-6.3 APO DG OS HSM', #forum4031
    174.3 => 'Sigma 150-500mm f/5-6.3 APO DG OS HSM', #47
    174.4 => 'Zeiss Milvus 100mm f/2 Makro', #IB
    174.5 => 'Sigma APO 50-150mm f/2.8 EX DC OS HSM', #IB
    174.6 => 'Sigma APO 120-300mm f/2.8 EX DG OS HSM', #IB
    174.7 => 'Sigma 120-300mm f/2.8 DG OS HSM S013', #IB
    174.8 => 'Sigma 120-400mm f/4.5-5.6 APO DG OS HSM', #IB
    174.9 => 'Sigma 200-500mm f/2.8 APO EX DG', #IB
    175 => 'Canon EF 400mm f/2.8L USM', #32
    176 => 'Canon EF 24-85mm f/3.5-4.5 USM',
    177 => 'Canon EF 300mm f/4L IS USM', #9
    178 => 'Canon EF 28-135mm f/3.5-5.6 IS',
    179 => 'Canon EF 24mm f/1.4L USM', #20
    180 => 'Canon EF 35mm f/1.4L USM or Other Lens', #9
    180.1 => 'Sigma 50mm f/1.4 DG HSM | A', #50
    180.2 => 'Sigma 24mm f/1.4 DG HSM | A', #NJ
    180.3 => 'Zeiss Milvus 50mm f/1.4', #IB
    180.4 => 'Zeiss Milvus 85mm f/1.4', #IB
    180.5 => 'Zeiss Otus 28mm f/1.4 ZE', #PH
    180.6 => 'Sigma 24mm f/1.5 FF High-Speed Prime | 017', #IB
    180.7 => 'Sigma 50mm f/1.5 FF High-Speed Prime | 017', #IB
    180.8 => 'Sigma 85mm f/1.5 FF High-Speed Prime | 017', #IB
    180.9 => 'Tokina Opera 50mm f/1.4 FF', #IB
   '180.10' => 'Sigma 20mm f/1.4 DG HSM | A', #IB (015)
    181 => 'Canon EF 100-400mm f/4.5-5.6L IS USM + 1.4x or Sigma Lens', #15
    181.1 => 'Sigma 150-600mm f/5-6.3 DG OS HSM | S + 1.4x', #50
    182 => 'Canon EF 100-400mm f/4.5-5.6L IS USM + 2x or Sigma Lens',
    182.1 => 'Sigma 150-600mm f/5-6.3 DG OS HSM | S + 2x', #PH (NC)
    183 => 'Canon EF 100-400mm f/4.5-5.6L IS USM or Sigma Lens',
    183.1 => 'Sigma 150mm f/2.8 EX DG OS HSM APO Macro', #50
    183.2 => 'Sigma 105mm f/2.8 EX DG OS HSM Macro', #50
    183.3 => 'Sigma 180mm f/2.8 EX DG OS HSM APO Macro', #IB
    183.4 => 'Sigma 150-600mm f/5-6.3 DG OS HSM | C', #47
    183.5 => 'Sigma 150-600mm f/5-6.3 DG OS HSM | S', #forum7109 (Sports 014)
    183.6 => 'Sigma 100-400mm f/5-6.3 DG OS HSM', #PH ("| C" ?)
    183.7 => 'Sigma 180mm f/3.5 APO Macro EX DG IF HSM', #IB
    184 => 'Canon EF 400mm f/2.8L USM + 2x', #15
    185 => 'Canon EF 600mm f/4L IS USM', #32
    186 => 'Canon EF 70-200mm f/4L USM', #9
    187 => 'Canon EF 70-200mm f/4L USM + 1.4x', #26
    188 => 'Canon EF 70-200mm f/4L USM + 2x', #PH
    189 => 'Canon EF 70-200mm f/4L USM + 2.8x', #32
    190 => 'Canon EF 100mm f/2.8 Macro USM', # (+USM ref 42)
    191 => 'Canon EF 400mm f/4 DO IS or Sigma Lens', #9
    191.1 => 'Sigma 500mm f/4 DG OS HSM', #AndrewSheih
    193 => 'Canon EF 35-80mm f/4-5.6 USM', #32
    194 => 'Canon EF 80-200mm f/4.5-5.6 USM', #32
    195 => 'Canon EF 35-105mm f/4.5-5.6 USM', #32
    196 => 'Canon EF 75-300mm f/4-5.6 USM', #15/32
    197 => 'Canon EF 75-300mm f/4-5.6 IS USM or Sigma Lens',
    197.1 => 'Sigma 18-300mm f/3.5-6.3 DC Macro OS HSM', #50
    198 => 'Canon EF 50mm f/1.4 USM or Other Lens',
    198.1 => 'Zeiss Otus 55mm f/1.4 ZE', #JR (seen only on Sony camera)
    198.2 => 'Zeiss Otus 85mm f/1.4 ZE', #JR (NC)
    198.3 => 'Zeiss Milvus 25mm f/1.4', #IB
    198.4 => 'Zeiss Otus 100mm f/1.4', #IB
    198.5 => 'Zeiss Milvus 35mm f/1.4 ZE', #IB
    198.6 => 'Yongnuo YN 35mm f/2', #IB
    199 => 'Canon EF 28-80mm f/3.5-5.6 USM', #32
    200 => 'Canon EF 75-300mm f/4-5.6 USM', #32
    201 => 'Canon EF 28-80mm f/3.5-5.6 USM', #32
    202 => 'Canon EF 28-80mm f/3.5-5.6 USM IV',
    208 => 'Canon EF 22-55mm f/4-5.6 USM', #32
    209 => 'Canon EF 55-200mm f/4.5-5.6', #32 (USM mk I version? ref IB)
    210 => 'Canon EF 28-90mm f/4-5.6 USM', #32
    211 => 'Canon EF 28-200mm f/3.5-5.6 USM', #15
    212 => 'Canon EF 28-105mm f/4-5.6 USM', #15
    213 => 'Canon EF 90-300mm f/4.5-5.6 USM or Tamron Lens',
    213.1 => 'Tamron SP 150-600mm f/5-6.3 Di VC USD (A011)', #forum5565
    213.2 => 'Tamron 16-300mm f/3.5-6.3 Di II VC PZD Macro (B016)', #PH
    213.3 => 'Tamron SP 35mm f/1.8 Di VC USD (F012)', #PH
    213.4 => 'Tamron SP 45mm f/1.8 Di VC USD (F013)', #PH
    214 => 'Canon EF-S 18-55mm f/3.5-5.6 USM', #PH/34
    215 => 'Canon EF 55-200mm f/4.5-5.6 II USM',
    217 => 'Tamron AF 18-270mm f/3.5-6.3 Di II VC PZD', #47
    220 => 'Yongnuo YN 50mm f/1.8', #IB
    224 => 'Canon EF 70-200mm f/2.8L IS USM', #11
    225 => 'Canon EF 70-200mm f/2.8L IS USM + 1.4x', #11
    226 => 'Canon EF 70-200mm f/2.8L IS USM + 2x', #14
    227 => 'Canon EF 70-200mm f/2.8L IS USM + 2.8x', #32
    228 => 'Canon EF 28-105mm f/3.5-4.5 USM', #32
    229 => 'Canon EF 16-35mm f/2.8L USM', #PH
    230 => 'Canon EF 24-70mm f/2.8L USM', #9
    231 => 'Canon EF 17-40mm f/4L USM or Sigma Lens',
    231.1 => 'Sigma 12-24mm f/4 DG HSM A016', #IB
    232 => 'Canon EF 70-300mm f/4.5-5.6 DO IS USM', #15
    233 => 'Canon EF 28-300mm f/3.5-5.6L IS USM', #PH
    234 => 'Canon EF-S 17-85mm f/4-5.6 IS USM or Tokina Lens', #19
    234.1 => 'Tokina AT-X 12-28 PRO DX 12-28mm f/4', #50/NJ
    235 => 'Canon EF-S 10-22mm f/3.5-4.5 USM', #15
    236 => 'Canon EF-S 60mm f/2.8 Macro USM', #15
    237 => 'Canon EF 24-105mm f/4L IS USM', #15
    238 => 'Canon EF 70-300mm f/4-5.6 IS USM', #15 (and version II? ref 42)
    239 => 'Canon EF 85mm f/1.2L II USM or Rokinon Lens', #15
    239.1 => 'Rokinon SP 85mm f/1.2', #IB
    240 => 'Canon EF-S 17-55mm f/2.8 IS USM or Sigma Lens', #15
    240.1 => 'Sigma 17-50mm f/2.8 EX DC OS HSM', #https://github.com/Exiv2/exiv2/issues/397
    241 => 'Canon EF 50mm f/1.2L USM', #15
    242 => 'Canon EF 70-200mm f/4L IS USM', #PH
    243 => 'Canon EF 70-200mm f/4L IS USM + 1.4x', #15
    244 => 'Canon EF 70-200mm f/4L IS USM + 2x', #PH
    245 => 'Canon EF 70-200mm f/4L IS USM + 2.8x', #32
    246 => 'Canon EF 16-35mm f/2.8L II USM', #PH
    247 => 'Canon EF 14mm f/2.8L II USM', #32
    248 => 'Canon EF 200mm f/2L IS USM or Sigma Lens', #42
    248.1 => 'Sigma 24-35mm f/2 DG HSM | A', #JR
    248.2 => 'Sigma 135mm f/2 FF High-Speed Prime | 017', #IB
    248.3 => 'Sigma 24-35mm f/2.2 FF Zoom | 017', #IB
    248.4 => 'Sigma 135mm f/1.8 DG HSM A017', #IB
    249 => 'Canon EF 800mm f/5.6L IS USM', #35
    250 => 'Canon EF 24mm f/1.4L II USM or Sigma Lens', #41
    250.1 => 'Sigma 20mm f/1.4 DG HSM | A', #IB
    250.2 => 'Sigma 20mm f/1.5 FF High-Speed Prime | 017', #IB
    250.3 => 'Tokina Opera 16-28mm f/2.8 FF', #IB
    250.4 => 'Sigma 85mm f/1.4 DG HSM A016', #IB
    251 => 'Canon EF 70-200mm f/2.8L IS II USM',
    251.1 => 'Canon EF 70-200mm f/2.8L IS III USM', #IB
    252 => 'Canon EF 70-200mm f/2.8L IS II USM + 1.4x', #50 (1.4x Mk II)
    252.1 => 'Canon EF 70-200mm f/2.8L IS III USM + 1.4x', #PH (NC)
    253 => 'Canon EF 70-200mm f/2.8L IS II USM + 2x', #PH (NC)
    253.1 => 'Canon EF 70-200mm f/2.8L IS III USM + 2x', #PH (NC)
    # 253.2 => 'Tamron SP 70-200mm f/2.8 Di VC USD G2 (A025) + 2x', #forum9367
    254 => 'Canon EF 100mm f/2.8L Macro IS USM or Tamron Lens', #42
    254.1 => 'Tamron SP 90mm f/2.8 Di VC USD 1:1 Macro (F017)', #PH
    255 => 'Sigma 24-105mm f/4 DG OS HSM | A or Other Lens', #50
    255.1 => 'Sigma 180mm f/2.8 EX DG OS HSM APO Macro', #50
    255.2 => 'Tamron SP 70-200mm f/2.8 Di VC USD', #exiv issue 1202 (A009)
    255.3 => 'Yongnuo YN 50mm f/1.8', #50
    368 => 'Sigma 14-24mm f/2.8 DG HSM | A or other Sigma Lens', #IB (A018)
    368.1 => 'Sigma 20mm f/1.4 DG HSM | A', #50 (newer firmware)
    368.2 => 'Sigma 50mm f/1.4 DG HSM | A', #50
    368.3 => 'Sigma 40mm f/1.4 DG HSM | A', #IB (018)
    368.4 => 'Sigma 60-600mm f/4.5-6.3 DG OS HSM | S', #IB (018)
    368.5 => 'Sigma 28mm f/1.4 DG HSM | A', #IB (A019)
    368.6 => 'Sigma 150-600mm f/5-6.3 DG OS HSM | S', #50
    368.7 => 'Sigma 85mm f/1.4 DG HSM | A', #IB (016)
    368.8 => 'Sigma 105mm f/1.4 DG HSM', #IB (A018)
    368.9 => 'Sigma 14-24mm f/2.8 DG HSM', #IB (A018)
   '368.10' => 'Sigma 35mm f/1.4 DG HSM | A', #PH (012)
   '368.11' => 'Sigma 70mm f/2.8 DG Macro', #IB (A018)
   '368.12' => 'Sigma 18-35mm f/1.8 DC HSM | A', #50
   '368.13' => 'Sigma 24-105mm f/4 DG OS HSM | A', #forum3833
   '368.14' => 'Sigma 18-300mm f/3.5-6.3 DC Macro OS HSM | C', #forum15280 (014)
   '368.15' => 'Sigma 24mm F1.4 DG HSM | A', #50 (015)
    # Note: LensType 488 (0x1e8) is reported as 232 (0xe8) in 7D CameraSettings
    488 => 'Canon EF-S 15-85mm f/3.5-5.6 IS USM', #PH
    489 => 'Canon EF 70-300mm f/4-5.6L IS USM', #Gerald Kapounek
    490 => 'Canon EF 8-15mm f/4L Fisheye USM', #Klaus Reinfeld (PH added "Fisheye")
    491 => 'Canon EF 300mm f/2.8L IS II USM or Tamron Lens', #42
    491.1 => 'Tamron SP 70-200mm f/2.8 Di VC USD G2 (A025)', #IB
    491.2 => 'Tamron 18-400mm f/3.5-6.3 Di II VC HLD (B028)', #IB
    491.3 => 'Tamron 100-400mm f/4.5-6.3 Di VC USD (A035)', #IB
    491.4 => 'Tamron 70-210mm f/4 Di VC USD (A034)', #IB
    491.5 => 'Tamron 70-210mm f/4 Di VC USD (A034) + 1.4x', #IB
    491.6 => 'Tamron SP 24-70mm f/2.8 Di VC USD G2 (A032)',
    492 => 'Canon EF 400mm f/2.8L IS II USM', #PH
    493 => 'Canon EF 500mm f/4L IS II USM or EF 24-105mm f4L IS USM', #PH
    493.1 => 'Canon EF 24-105mm f/4L IS USM', #PH (should recheck this)
    494 => 'Canon EF 600mm f/4L IS II USM', #PH
    495 => 'Canon EF 24-70mm f/2.8L II USM or Sigma Lens', #PH
    495.1 => 'Sigma 24-70mm f/2.8 DG OS HSM | A', #IB (017)
    496 => 'Canon EF 200-400mm f/4L IS USM', #PH
    499 => 'Canon EF 200-400mm f/4L IS USM + 1.4x', #50
    502 => 'Canon EF 28mm f/2.8 IS USM or Tamron Lens', #PH
    502.1 => 'Tamron 35mm f/1.8 Di VC USD (F012)', #forum9757
    503 => 'Canon EF 24mm f/2.8 IS USM', #PH
    504 => 'Canon EF 24-70mm f/4L IS USM', #PH
    505 => 'Canon EF 35mm f/2 IS USM', #PH
    506 => 'Canon EF 400mm f/4 DO IS II USM', #42
    507 => 'Canon EF 16-35mm f/4L IS USM', #42
    508 => 'Canon EF 11-24mm f/4L USM or Tamron Lens', #PH
    508.1 => 'Tamron 10-24mm f/3.5-4.5 Di II VC HLD (B023)', #PH
    624 => 'Sigma 70-200mm f/2.8 DG OS HSM | S or other Sigma Lens', #IB (018)
    624.1 => 'Sigma 150-600mm f/5-6.3 | C', #ChrisSkopec
    747 => 'Canon EF 100-400mm f/4.5-5.6L IS II USM or Tamron Lens', #JR
    747.1 => 'Tamron SP 150-600mm f/5-6.3 Di VC USD G2', #50
    748 => 'Canon EF 100-400mm f/4.5-5.6L IS II USM + 1.4x or Tamron Lens', #JR (1.4x Mk III)
    748.1 => 'Tamron 100-400mm f/4.5-6.3 Di VC USD A035E + 1.4x', #IB
    748.2 => 'Tamron 70-210mm f/4 Di VC USD (A034) + 2x', #IB
    749 => 'Canon EF 100-400mm f/4.5-5.6L IS II USM + 2x or Tamron Lens', #PH
    749.1 => 'Tamron 100-400mm f/4.5-6.3 Di VC USD A035E + 2x', #IB
    750 => 'Canon EF 35mm f/1.4L II USM or Tamron Lens', #42
    750.1 => 'Tamron SP 85mm f/1.8 Di VC USD (F016)', #Exiv2#1072
    750.2 => 'Tamron SP 45mm f/1.8 Di VC USD (F013)', #PH
    751 => 'Canon EF 16-35mm f/2.8L III USM', #42
    752 => 'Canon EF 24-105mm f/4L IS II USM', #42
    753 => 'Canon EF 85mm f/1.4L IS USM', #42
    754 => 'Canon EF 70-200mm f/4L IS II USM', #IB
    757 => 'Canon EF 400mm f/2.8L IS III USM', #IB
    758 => 'Canon EF 600mm f/4L IS III USM', #IB

    1136 => 'Sigma 24-70mm f/2.8 DG OS HSM | A', #IB (017)
    # (STM lenses - 0x10xx)
    4142 => 'Canon EF-S 18-135mm f/3.5-5.6 IS STM',
    4143 => 'Canon EF-M 18-55mm f/3.5-5.6 IS STM or Tamron Lens',
    4143.1 => 'Tamron 18-200mm f/3.5-6.3 Di III VC', #42
    4144 => 'Canon EF 40mm f/2.8 STM', #50
    4145 => 'Canon EF-M 22mm f/2 STM', #34
    4146 => 'Canon EF-S 18-55mm f/3.5-5.6 IS STM', #PH
    4147 => 'Canon EF-M 11-22mm f/4-5.6 IS STM', #42
    4148 => 'Canon EF-S 55-250mm f/4-5.6 IS STM', #42
    4149 => 'Canon EF-M 55-200mm f/4.5-6.3 IS STM', #42
    4150 => 'Canon EF-S 10-18mm f/4.5-5.6 IS STM', #42
    4152 => 'Canon EF 24-105mm f/3.5-5.6 IS STM', #42
    4153 => 'Canon EF-M 15-45mm f/3.5-6.3 IS STM', #PH
    4154 => 'Canon EF-S 24mm f/2.8 STM', #IB
    4155 => 'Canon EF-M 28mm f/3.5 Macro IS STM', #42
    4156 => 'Canon EF 50mm f/1.8 STM', #42
    4157 => 'Canon EF-M 18-150mm f/3.5-6.3 IS STM', #42
    4158 => 'Canon EF-S 18-55mm f/4-5.6 IS STM', #PH
    4159 => 'Canon EF-M 32mm f/1.4 STM', #42
    4160 => 'Canon EF-S 35mm f/2.8 Macro IS STM', #42
    4208 => 'Sigma 56mm f/1.4 DC DN | C or other Sigma Lens', #forum10603
    4208.1 => 'Sigma 30mm F1.4 DC DN | C', #github#83 (016)
    4976 => 'Sigma 16-300mm F3.5-6.7 DC OS | C (025)', #50
    6512 => 'Sigma 12mm F1.4 DC | C', #github#352 (025)
    # (Nano USM lenses - 0x90xx)
    36910 => 'Canon EF 70-300mm f/4-5.6 IS II USM', #42
    36912 => 'Canon EF-S 18-135mm f/3.5-5.6 IS USM', #42
    # (CN-E lenses - 0xf0xx)
    61491 => 'Canon CN-E 14mm T3.1 L F', #PH
    61492 => 'Canon CN-E 24mm T1.5 L F', #PH
  # 61493 - missing CN-E 50mm T1.3 L F ?
    61494 => 'Canon CN-E 85mm T1.3 L F', #PH
    61495 => 'Canon CN-E 135mm T2.2 L F', #PH
    61496 => 'Canon CN-E 35mm T1.5 L F', #PH
#
# see RFLensType tag for master list of 61182 RF lenses
#
    61182 => 'Canon RF 50mm F1.2L USM or other Canon RF Lens',
    61182.1 => 'Canon RF 24-105mm F4L IS USM',
    61182.2 => 'Canon RF 28-70mm F2L USM',
    61182.3 => 'Canon RF 35mm F1.8 MACRO IS STM',
    61182.4 => 'Canon RF 85mm F1.2L USM',
    61182.5 => 'Canon RF 85mm F1.2L USM DS',
    61182.6 => 'Canon RF 24-70mm F2.8L IS USM',
    61182.7 => 'Canon RF 15-35mm F2.8L IS USM',
    61182.8 => 'Canon RF 24-240mm F4-6.3 IS USM',
    61182.9 => 'Canon RF 70-200mm F2.8L IS USM',
   '61182.10' => 'Canon RF 85mm F2 MACRO IS STM',
   '61182.11' => 'Canon RF 600mm F11 IS STM',
   '61182.12' => 'Canon RF 600mm F11 IS STM + RF1.4x',
   '61182.13' => 'Canon RF 600mm F11 IS STM + RF2x',
   '61182.14' => 'Canon RF 800mm F11 IS STM',
   '61182.15' => 'Canon RF 800mm F11 IS STM + RF1.4x',
   '61182.16' => 'Canon RF 800mm F11 IS STM + RF2x',
   '61182.17' => 'Canon RF 24-105mm F4-7.1 IS STM',
   '61182.18' => 'Canon RF 100-500mm F4.5-7.1L IS USM',
   '61182.19' => 'Canon RF 100-500mm F4.5-7.1L IS USM + RF1.4x',
   '61182.20' => 'Canon RF 100-500mm F4.5-7.1L IS USM + RF2x',
   '61182.21' => 'Canon RF 70-200mm F4L IS USM', #42
   '61182.22' => 'Canon RF 100mm F2.8L MACRO IS USM', #42
   '61182.23' => 'Canon RF 50mm F1.8 STM', #42
   '61182.24' => 'Canon RF 14-35mm F4L IS USM', #IB
   '61182.25' => 'Canon RF-S 18-45mm F4.5-6.3 IS STM', #42
   '61182.26' => 'Canon RF 100-400mm F5.6-8 IS USM', #42
   '61182.27' => 'Canon RF 100-400mm F5.6-8 IS USM + RF1.4x', #42
   '61182.28' => 'Canon RF 100-400mm F5.6-8 IS USM + RF2x', #42
   '61182.29' => 'Canon RF-S 18-150mm F3.5-6.3 IS STM', #42
   '61182.30' => 'Canon RF 24mm F1.8 MACRO IS STM', #42
   '61182.31' => 'Canon RF 16mm F2.8 STM', #42
   '61182.32' => 'Canon RF 400mm F2.8L IS USM', #IB
   '61182.33' => 'Canon RF 400mm F2.8L IS USM + RF1.4x', #IB
   '61182.34' => 'Canon RF 400mm F2.8L IS USM + RF2x', #IB
   '61182.35' => 'Canon RF 600mm F4L IS USM', #GiaZopatti
   '61182.36' => 'Canon RF 600mm F4L IS USM + RF1.4x', #42
   '61182.37' => 'Canon RF 600mm F4L IS USM + RF2x', #42
   '61182.38' => 'Canon RF 800mm F5.6L IS USM', #42
   '61182.39' => 'Canon RF 800mm F5.6L IS USM + RF1.4x', #42
   '61182.40' => 'Canon RF 800mm F5.6L IS USM + RF2x', #42
   '61182.41' => 'Canon RF 1200mm F8L IS USM', #42
   '61182.42' => 'Canon RF 1200mm F8L IS USM + RF1.4x', #42
   '61182.43' => 'Canon RF 1200mm F8L IS USM + RF2x', #42
   '61182.44' => 'Canon RF 5.2mm F2.8L Dual Fisheye 3D VR', #PH
   '61182.45' => 'Canon RF 15-30mm F4.5-6.3 IS STM', #42
   '61182.46' => 'Canon RF 135mm F1.8 L IS USM', #42
   '61182.47' => 'Canon RF 24-50mm F4.5-6.3 IS STM', #42
   '61182.48' => 'Canon RF-S 55-210mm F5-7.1 IS STM', #42
   '61182.49' => 'Canon RF 100-300mm F2.8L IS USM', #42
   '61182.50' => 'Canon RF 100-300mm F2.8L IS USM + RF1.4x', #42
   '61182.51' => 'Canon RF 100-300mm F2.8L IS USM + RF2x', #42
   '61182.52' => 'Canon RF 10-20mm F4 L IS STM', #42
   '61182.53' => 'Canon RF 28mm F2.8 STM', #42
   '61182.54' => 'Canon RF 24-105mm F2.8 L IS USM Z', #42
   '61182.55' => 'Canon RF-S 10-18mm F4.5-6.3 IS STM', #42
   '61182.56' => 'Canon RF 35mm F1.4 L VCM', #42
   '61182.57' => 'Canon RF 70-200mm F2.8 L IS USM Z', #42
   '61182.58' => 'Canon RF 70-200mm F2.8 L IS USM Z + RF1.4x', #42
   '61182.59' => 'Canon RF 70-200mm F2.8 L IS USM Z + RF2x', #42
   '61182.60' => 'Canon RF 16-28mm F2.8 IS STM', #42
   '61182.61' => 'Canon RF-S 14-30mm F4-6.3 IS STM PZ', #42
   '61182.62' => 'Canon RF 50mm F1.4 L VCM', #42
   '61182.63' => 'Canon RF 24mm F1.4 L VCM', #42
   '61182.64' => 'Canon RF 20mm F1.4 L VCM', #42
   '61182.65' => 'Canon RF 85mm F1.4 L VCM', #github350
   '61182.66' => 'Canon RF 45mm F1.2 STM', #42
   '61182.67' => 'Canon RF 7-14mm F2.8-3.5 L FISHEYE STM', #42
   '61182.68' => 'Canon RF 14mm F1.4 L VCM', #42
    65535 => 'n/a',
);

# Canon model ID numbers (PH)
%canonModelID = (
    0x1010000 => 'PowerShot A30',
    0x1040000 => 'PowerShot S300 / Digital IXUS 300 / IXY Digital 300',
    0x1060000 => 'PowerShot A20',
    0x1080000 => 'PowerShot A10',
    0x1090000 => 'PowerShot S110 / Digital IXUS v / IXY Digital 200',
    0x1100000 => 'PowerShot G2',
    0x1110000 => 'PowerShot S40',
    0x1120000 => 'PowerShot S30',
    0x1130000 => 'PowerShot A40',
    0x1140000 => 'EOS D30',
    0x1150000 => 'PowerShot A100',
    0x1160000 => 'PowerShot S200 / Digital IXUS v2 / IXY Digital 200a',
    0x1170000 => 'PowerShot A200',
    0x1180000 => 'PowerShot S330 / Digital IXUS 330 / IXY Digital 300a',
    0x1190000 => 'PowerShot G3',
    0x1210000 => 'PowerShot S45',
    0x1230000 => 'PowerShot SD100 / Digital IXUS II / IXY Digital 30',
    0x1240000 => 'PowerShot S230 / Digital IXUS v3 / IXY Digital 320',
    0x1250000 => 'PowerShot A70',
    0x1260000 => 'PowerShot A60',
    0x1270000 => 'PowerShot S400 / Digital IXUS 400 / IXY Digital 400',
    0x1290000 => 'PowerShot G5',
    0x1300000 => 'PowerShot A300',
    0x1310000 => 'PowerShot S50',
    0x1340000 => 'PowerShot A80',
    0x1350000 => 'PowerShot SD10 / Digital IXUS i / IXY Digital L',
    0x1360000 => 'PowerShot S1 IS',
    0x1370000 => 'PowerShot Pro1',
    0x1380000 => 'PowerShot S70',
    0x1390000 => 'PowerShot S60',
    0x1400000 => 'PowerShot G6',
    0x1410000 => 'PowerShot S500 / Digital IXUS 500 / IXY Digital 500',
    0x1420000 => 'PowerShot A75',
    0x1440000 => 'PowerShot SD110 / Digital IXUS IIs / IXY Digital 30a',
    0x1450000 => 'PowerShot A400',
    0x1470000 => 'PowerShot A310',
    0x1490000 => 'PowerShot A85',
    0x1520000 => 'PowerShot S410 / Digital IXUS 430 / IXY Digital 450',
    0x1530000 => 'PowerShot A95',
    0x1540000 => 'PowerShot SD300 / Digital IXUS 40 / IXY Digital 50',
    0x1550000 => 'PowerShot SD200 / Digital IXUS 30 / IXY Digital 40',
    0x1560000 => 'PowerShot A520',
    0x1570000 => 'PowerShot A510',
    0x1590000 => 'PowerShot SD20 / Digital IXUS i5 / IXY Digital L2',
    0x1640000 => 'PowerShot S2 IS',
    0x1650000 => 'PowerShot SD430 / Digital IXUS Wireless / IXY Digital Wireless',
    0x1660000 => 'PowerShot SD500 / Digital IXUS 700 / IXY Digital 600',
    0x1668000 => 'EOS D60',
    0x1700000 => 'PowerShot SD30 / Digital IXUS i Zoom / IXY Digital L3',
    0x1740000 => 'PowerShot A430',
    0x1750000 => 'PowerShot A410',
    0x1760000 => 'PowerShot S80',
    0x1780000 => 'PowerShot A620',
    0x1790000 => 'PowerShot A610',
    0x1800000 => 'PowerShot SD630 / Digital IXUS 65 / IXY Digital 80',
    0x1810000 => 'PowerShot SD450 / Digital IXUS 55 / IXY Digital 60',
    0x1820000 => 'PowerShot TX1',
    0x1870000 => 'PowerShot SD400 / Digital IXUS 50 / IXY Digital 55',
    0x1880000 => 'PowerShot A420',
    0x1890000 => 'PowerShot SD900 / Digital IXUS 900 Ti / IXY Digital 1000',
    0x1900000 => 'PowerShot SD550 / Digital IXUS 750 / IXY Digital 700',
    0x1920000 => 'PowerShot A700',
    0x1940000 => 'PowerShot SD700 IS / Digital IXUS 800 IS / IXY Digital 800 IS',
    0x1950000 => 'PowerShot S3 IS',
    0x1960000 => 'PowerShot A540',
    0x1970000 => 'PowerShot SD600 / Digital IXUS 60 / IXY Digital 70',
    0x1980000 => 'PowerShot G7',
    0x1990000 => 'PowerShot A530',
    0x2000000 => 'PowerShot SD800 IS / Digital IXUS 850 IS / IXY Digital 900 IS',
    0x2010000 => 'PowerShot SD40 / Digital IXUS i7 / IXY Digital L4',
    0x2020000 => 'PowerShot A710 IS',
    0x2030000 => 'PowerShot A640',
    0x2040000 => 'PowerShot A630',
    0x2090000 => 'PowerShot S5 IS',
    0x2100000 => 'PowerShot A460',
    0x2120000 => 'PowerShot SD850 IS / Digital IXUS 950 IS / IXY Digital 810 IS',
    0x2130000 => 'PowerShot A570 IS',
    0x2140000 => 'PowerShot A560',
    0x2150000 => 'PowerShot SD750 / Digital IXUS 75 / IXY Digital 90',
    0x2160000 => 'PowerShot SD1000 / Digital IXUS 70 / IXY Digital 10',
    0x2180000 => 'PowerShot A550',
    0x2190000 => 'PowerShot A450',
    0x2230000 => 'PowerShot G9',
    0x2240000 => 'PowerShot A650 IS',
    0x2260000 => 'PowerShot A720 IS',
    0x2290000 => 'PowerShot SX100 IS',
    0x2300000 => 'PowerShot SD950 IS / Digital IXUS 960 IS / IXY Digital 2000 IS',
    0x2310000 => 'PowerShot SD870 IS / Digital IXUS 860 IS / IXY Digital 910 IS',
    0x2320000 => 'PowerShot SD890 IS / Digital IXUS 970 IS / IXY Digital 820 IS',
    0x2360000 => 'PowerShot SD790 IS / Digital IXUS 90 IS / IXY Digital 95 IS',
    0x2370000 => 'PowerShot SD770 IS / Digital IXUS 85 IS / IXY Digital 25 IS',
    0x2380000 => 'PowerShot A590 IS',
    0x2390000 => 'PowerShot A580',
    0x2420000 => 'PowerShot A470',
    0x2430000 => 'PowerShot SD1100 IS / Digital IXUS 80 IS / IXY Digital 20 IS',
    0x2460000 => 'PowerShot SX1 IS',
    0x2470000 => 'PowerShot SX10 IS',
    0x2480000 => 'PowerShot A1000 IS',
    0x2490000 => 'PowerShot G10',
    0x2510000 => 'PowerShot A2000 IS',
    0x2520000 => 'PowerShot SX110 IS',
    0x2530000 => 'PowerShot SD990 IS / Digital IXUS 980 IS / IXY Digital 3000 IS',
    0x2540000 => 'PowerShot SD880 IS / Digital IXUS 870 IS / IXY Digital 920 IS',
    0x2550000 => 'PowerShot E1',
    0x2560000 => 'PowerShot D10',
    0x2570000 => 'PowerShot SD960 IS / Digital IXUS 110 IS / IXY Digital 510 IS',
    0x2580000 => 'PowerShot A2100 IS',
    0x2590000 => 'PowerShot A480',
    0x2600000 => 'PowerShot SX200 IS',
    0x2610000 => 'PowerShot SD970 IS / Digital IXUS 990 IS / IXY Digital 830 IS',
    0x2620000 => 'PowerShot SD780 IS / Digital IXUS 100 IS / IXY Digital 210 IS',
    0x2630000 => 'PowerShot A1100 IS',
    0x2640000 => 'PowerShot SD1200 IS / Digital IXUS 95 IS / IXY Digital 110 IS',
    0x2700000 => 'PowerShot G11',
    0x2710000 => 'PowerShot SX120 IS',
    0x2720000 => 'PowerShot S90',
    0x2750000 => 'PowerShot SX20 IS',
    0x2760000 => 'PowerShot SD980 IS / Digital IXUS 200 IS / IXY Digital 930 IS',
    0x2770000 => 'PowerShot SD940 IS / Digital IXUS 120 IS / IXY Digital 220 IS',
    0x2800000 => 'PowerShot A495',
    0x2810000 => 'PowerShot A490',
    0x2820000 => 'PowerShot A3100/A3150 IS', # (different cameras, same ID)
    0x2830000 => 'PowerShot A3000 IS',
    0x2840000 => 'PowerShot SD1400 IS / IXUS 130 / IXY 400F',
    0x2850000 => 'PowerShot SD1300 IS / IXUS 105 / IXY 200F',
    0x2860000 => 'PowerShot SD3500 IS / IXUS 210 / IXY 10S',
    0x2870000 => 'PowerShot SX210 IS',
    0x2880000 => 'PowerShot SD4000 IS / IXUS 300 HS / IXY 30S',
    0x2890000 => 'PowerShot SD4500 IS / IXUS 1000 HS / IXY 50S',
    0x2920000 => 'PowerShot G12',
    0x2930000 => 'PowerShot SX30 IS',
    0x2940000 => 'PowerShot SX130 IS',
    0x2950000 => 'PowerShot S95',
    0x2980000 => 'PowerShot A3300 IS',
    0x2990000 => 'PowerShot A3200 IS',
    0x3000000 => 'PowerShot ELPH 500 HS / IXUS 310 HS / IXY 31S',
    0x3010000 => 'PowerShot Pro90 IS',
    0x3010001 => 'PowerShot A800',
    0x3020000 => 'PowerShot ELPH 100 HS / IXUS 115 HS / IXY 210F',
    0x3030000 => 'PowerShot SX230 HS',
    0x3040000 => 'PowerShot ELPH 300 HS / IXUS 220 HS / IXY 410F',
    0x3050000 => 'PowerShot A2200',
    0x3060000 => 'PowerShot A1200',
    0x3070000 => 'PowerShot SX220 HS',
    0x3080000 => 'PowerShot G1 X',
    0x3090000 => 'PowerShot SX150 IS',
    0x3100000 => 'PowerShot ELPH 510 HS / IXUS 1100 HS / IXY 51S',
    0x3110000 => 'PowerShot S100 (new)',
    0x3130000 => 'PowerShot SX40 HS',
    0x3120000 => 'PowerShot ELPH 310 HS / IXUS 230 HS / IXY 600F',
    # the Canon page lists the IXY 32S as "Japan only", but many other
    # sites list the ELPH 500 HS and IXUS 320 HS as being the same model.
    # I haven't been able to find an IXUS 320 sample, and the ELPH 500 HS
    # is already associated with other IXUS and IXY models - PH
    0x3140000 => 'IXY 32S', # (PowerShot ELPH 500 HS / IXUS 320 HS ??)
    0x3160000 => 'PowerShot A1300',
    0x3170000 => 'PowerShot A810',
    0x3180000 => 'PowerShot ELPH 320 HS / IXUS 240 HS / IXY 420F',
    0x3190000 => 'PowerShot ELPH 110 HS / IXUS 125 HS / IXY 220F',
    0x3200000 => 'PowerShot D20',
    0x3210000 => 'PowerShot A4000 IS',
    0x3220000 => 'PowerShot SX260 HS',
    0x3230000 => 'PowerShot SX240 HS',
    0x3240000 => 'PowerShot ELPH 530 HS / IXUS 510 HS / IXY 1',
    0x3250000 => 'PowerShot ELPH 520 HS / IXUS 500 HS / IXY 3',
    0x3260000 => 'PowerShot A3400 IS',
    0x3270000 => 'PowerShot A2400 IS',
    0x3280000 => 'PowerShot A2300',
    0x3320000 => 'PowerShot S100V', #IB
    0x3330000 => 'PowerShot G15', #25
    0x3340000 => 'PowerShot SX50 HS', #25/forum8196
    0x3350000 => 'PowerShot SX160 IS',
    0x3360000 => 'PowerShot S110 (new)',
    0x3370000 => 'PowerShot SX500 IS',
    0x3380000 => 'PowerShot N',
    0x3390000 => 'IXUS 245 HS / IXY 430F', # (no PowerShot)
    0x3400000 => 'PowerShot SX280 HS',
    0x3410000 => 'PowerShot SX270 HS',
    0x3420000 => 'PowerShot A3500 IS',
    0x3430000 => 'PowerShot A2600',
    0x3440000 => 'PowerShot SX275 HS', #forum8199
    0x3450000 => 'PowerShot A1400',
    0x3460000 => 'PowerShot ELPH 130 IS / IXUS 140 / IXY 110F',
    0x3470000 => 'PowerShot ELPH 115/120 IS / IXUS 132/135 / IXY 90F/100F',
    0x3490000 => 'PowerShot ELPH 330 HS / IXUS 255 HS / IXY 610F',
    0x3510000 => 'PowerShot A2500',
    0x3540000 => 'PowerShot G16',
    0x3550000 => 'PowerShot S120',
    0x3560000 => 'PowerShot SX170 IS',
    0x3580000 => 'PowerShot SX510 HS',
    0x3590000 => 'PowerShot S200 (new)',
    0x3600000 => 'IXY 620F', # (no PowerShot or IXUS?)
    0x3610000 => 'PowerShot N100',
    0x3640000 => 'PowerShot G1 X Mark II',
    0x3650000 => 'PowerShot D30',
    0x3660000 => 'PowerShot SX700 HS',
    0x3670000 => 'PowerShot SX600 HS',
    0x3680000 => 'PowerShot ELPH 140 IS / IXUS 150 / IXY 130',
    0x3690000 => 'PowerShot ELPH 135 / IXUS 145 / IXY 120',
    0x3700000 => 'PowerShot ELPH 340 HS / IXUS 265 HS / IXY 630',
    0x3710000 => 'PowerShot ELPH 150 IS / IXUS 155 / IXY 140',
    0x3740000 => 'EOS M3', #IB
    0x3750000 => 'PowerShot SX60 HS', #IB/NJ
    0x3760000 => 'PowerShot SX520 HS', #IB
    0x3770000 => 'PowerShot SX400 IS',
    0x3780000 => 'PowerShot G7 X', #IB
    0x3790000 => 'PowerShot N2',
    0x3800000 => 'PowerShot SX530 HS',
    0x3820000 => 'PowerShot SX710 HS',
    0x3830000 => 'PowerShot SX610 HS',
    0x3840000 => 'EOS M10',
    0x3850000 => 'PowerShot G3 X',
    0x3860000 => 'PowerShot ELPH 165 HS / IXUS 165 / IXY 160',
    0x3870000 => 'PowerShot ELPH 160 / IXUS 160',
    0x3880000 => 'PowerShot ELPH 350 HS / IXUS 275 HS / IXY 640',
    0x3890000 => 'PowerShot ELPH 170 IS / IXUS 170',
    0x3910000 => 'PowerShot SX410 IS',
    0x3930000 => 'PowerShot G9 X',
    0x3940000 => 'EOS M5', #IB
    0x3950000 => 'PowerShot G5 X',
    0x3970000 => 'PowerShot G7 X Mark II',
    0x3980000 => 'EOS M100', #42
    0x3990000 => 'PowerShot ELPH 360 HS / IXUS 285 HS / IXY 650',
    0x4010000 => 'PowerShot SX540 HS',
    0x4020000 => 'PowerShot SX420 IS',
    0x4030000 => 'PowerShot ELPH 190 IS / IXUS 180 / IXY 190',
    0x4040000 => 'PowerShot G1',
    0x4040001 => 'PowerShot ELPH 180 IS / IXUS 175 / IXY 180', #forum10402
    0x4050000 => 'PowerShot SX720 HS',
    0x4060000 => 'PowerShot SX620 HS',
    0x4070000 => 'EOS M6',
    0x4100000 => 'PowerShot G9 X Mark II',
    0x412     => 'EOS M50 / Kiss M', # (yes, no "0000")
    0x4150000 => 'PowerShot ELPH 185 / IXUS 185 / IXY 200',
    0x4160000 => 'PowerShot SX430 IS',
    0x4170000 => 'PowerShot SX730 HS',
    0x4180000 => 'PowerShot G1 X Mark III', #IB
    0x6040000 => 'PowerShot S100 / Digital IXUS / IXY Digital',
    0x801     => 'PowerShot SX740 HS',
    0x804     => 'PowerShot G5 X Mark II',
    0x805     => 'PowerShot SX70 HS',
    0x808     => 'PowerShot G7 X Mark III',
    0x811     => 'EOS M6 Mark II', #IB
    0x812     => 'EOS M200', #25

# (see http://cweb.canon.jp/e-support/faq/answer/digitalcamera/10447-1.html for PowerShot/IXUS/IXY names)

    0x40000227 => 'EOS C50', #github350
    0x4007d673 => 'DC19/DC21/DC22',
    0x4007d674 => 'XH A1',
    0x4007d675 => 'HV10',
    0x4007d676 => 'MD130/MD140/MD150/MD160/ZR850',
    0x4007d777 => 'DC50', # (iVIS)
    0x4007d778 => 'HV20', # (iVIS)
    0x4007d779 => 'DC211', #29
    0x4007d77a => 'HG10',
    0x4007d77b => 'HR10', #29 (iVIS)
    0x4007d77d => 'MD255/ZR950',
    0x4007d81c => 'HF11',
    0x4007d878 => 'HV30',
    0x4007d87c => 'XH A1S',
    0x4007d87e => 'DC301/DC310/DC311/DC320/DC330',
    0x4007d87f => 'FS100',
    0x4007d880 => 'HF10', #29 (iVIS/VIXIA)
    0x4007d882 => 'HG20/HG21', # (VIXIA)
    0x4007d925 => 'HF21', # (LEGRIA)
    0x4007d926 => 'HF S11', # (LEGRIA)
    0x4007d978 => 'HV40', # (LEGRIA)
    0x4007d987 => 'DC410/DC411/DC420',
    0x4007d988 => 'FS19/FS20/FS21/FS22/FS200', # (LEGRIA)
    0x4007d989 => 'HF20/HF200', # (LEGRIA)
    0x4007d98a => 'HF S10/S100', # (LEGRIA/VIXIA)
    0x4007da8e => 'HF R10/R16/R17/R18/R100/R106', # (LEGRIA/VIXIA)
    0x4007da8f => 'HF M30/M31/M36/M300/M306', # (LEGRIA/VIXIA)
    0x4007da90 => 'HF S20/S21/S200', # (LEGRIA/VIXIA)
    0x4007da92 => 'FS31/FS36/FS37/FS300/FS305/FS306/FS307',
    0x4007dca0 => 'EOS C300',
    0x4007dda9 => 'HF G25', # (LEGRIA)
    0x4007dfb4 => 'XC10',
    0x4007e1c3 => 'EOS C200',

    # NOTE: some pre-production models may have a model name of
    # "Canon EOS Kxxx", where "xxx" is the last 3 digits of the model ID below.
    # This has been observed for the 1DSmkIII/K215 and 400D/K236.
    0x80000001 => 'EOS-1D',
    0x80000167 => 'EOS-1DS',
    0x80000168 => 'EOS 10D',
    0x80000169 => 'EOS-1D Mark III',
    0x80000170 => 'EOS Digital Rebel / 300D / Kiss Digital',
    0x80000174 => 'EOS-1D Mark II',
    0x80000175 => 'EOS 20D',
    0x80000176 => 'EOS Digital Rebel XSi / 450D / Kiss X2',
    0x80000188 => 'EOS-1Ds Mark II',
    0x80000189 => 'EOS Digital Rebel XT / 350D / Kiss Digital N',
    0x80000190 => 'EOS 40D',
    0x80000213 => 'EOS 5D',
    0x80000215 => 'EOS-1Ds Mark III',
    0x80000218 => 'EOS 5D Mark II',
    0x80000219 => 'WFT-E1',
    0x80000232 => 'EOS-1D Mark II N',
    0x80000234 => 'EOS 30D',
    0x80000236 => 'EOS Digital Rebel XTi / 400D / Kiss Digital X',
    0x80000241 => 'WFT-E2',
    0x80000246 => 'WFT-E3',
    0x80000250 => 'EOS 7D',
    0x80000252 => 'EOS Rebel T1i / 500D / Kiss X3',
    0x80000254 => 'EOS Rebel XS / 1000D / Kiss F',
    0x80000261 => 'EOS 50D',
    0x80000269 => 'EOS-1D X',
    0x80000270 => 'EOS Rebel T2i / 550D / Kiss X4',
    0x80000271 => 'WFT-E4',
    0x80000273 => 'WFT-E5',
    0x80000281 => 'EOS-1D Mark IV',
    0x80000285 => 'EOS 5D Mark III',
    0x80000286 => 'EOS Rebel T3i / 600D / Kiss X5',
    0x80000287 => 'EOS 60D',
    0x80000288 => 'EOS Rebel T3 / 1100D / Kiss X50',
    0x80000289 => 'EOS 7D Mark II', #IB
    0x80000297 => 'WFT-E2 II',
    0x80000298 => 'WFT-E4 II',
    0x80000301 => 'EOS Rebel T4i / 650D / Kiss X6i',
    0x80000302 => 'EOS 6D', #25
    0x80000324 => 'EOS-1D C', #(NC)
    0x80000325 => 'EOS 70D',
    0x80000326 => 'EOS Rebel T5i / 700D / Kiss X7i',
    0x80000327 => 'EOS Rebel T5 / 1200D / Kiss X70 / Hi',
    0x80000328 => 'EOS-1D X Mark II', #42
    0x80000331 => 'EOS M',
    0x80000350 => 'EOS 80D', #42
    0x80000355 => 'EOS M2',
    0x80000346 => 'EOS Rebel SL1 / 100D / Kiss X7',
    0x80000347 => 'EOS Rebel T6s / 760D / 8000D',
    0x80000349 => 'EOS 5D Mark IV', #42
    0x80000382 => 'EOS 5DS',
    0x80000393 => 'EOS Rebel T6i / 750D / Kiss X8i',
    0x80000401 => 'EOS 5DS R',
    0x80000404 => 'EOS Rebel T6 / 1300D / Kiss X80',
    0x80000405 => 'EOS Rebel T7i / 800D / Kiss X9i',
    0x80000406 => 'EOS 6D Mark II', #IB/42
    0x80000408 => 'EOS 77D / 9000D',
    0x80000417 => 'EOS Rebel SL2 / 200D / Kiss X9', #IB/42
    0x80000421 => 'EOS R5', #PH
    0x80000422 => 'EOS Rebel T100 / 4000D / 3000D', #IB (3000D in China; Kiss? - PH)
    0x80000424 => 'EOS R', #IB
    0x80000428 => 'EOS-1D X Mark III', #IB
    0x80000432 => 'EOS Rebel T7 / 2000D / 1500D / Kiss X90', #IB
    0x80000433 => 'EOS RP',
    0x80000435 => 'EOS Rebel T8i / 850D / X10i', #JR/PH
    0x80000436 => 'EOS SL3 / 250D / Kiss X10', #25
    0x80000437 => 'EOS 90D', #IB
    0x80000450 => 'EOS R3', #42
    0x80000453 => 'EOS R6', #PH
    0x80000464 => 'EOS R7', #42
    0x80000465 => 'EOS R10', #42
    0x80000467 => 'PowerShot ZOOM',
    0x80000468 => 'EOS M50 Mark II / Kiss M2', #IB
    0x80000480 => 'EOS R50', #42
    0x80000481 => 'EOS R6 Mark II', #42
    0x80000487 => 'EOS R8', #42
    0x80000491 => 'PowerShot V10', #25
    0x80000495 => 'EOS R1', #PH
    0x80000496 => 'EOS R5 Mark II', #forum16406
    0x80000497 => 'PowerShot V1', #PH
    0x80000498 => 'EOS R100', #25
    0x80000516 => 'EOS R50 V', #42
    0x80000518 => 'EOS R6 Mark III', #42
    0x80000520 => 'EOS D2000C', #IB
    0x80000560 => 'EOS D6000C', #PH (guess)
);

my %canonQuality = (
    -1 => 'n/a', # (PH, EOS M MOV video)
    1 => 'Economy',
    2 => 'Normal',
    3 => 'Fine',
    4 => 'RAW',
    5 => 'Superfine',
    7 => 'CRAW', #42
    130 => 'Light (RAW)', #github#119
    131 => 'Standard (RAW)', #github#119
);
my %canonImageSize = (
   -1 => 'n/a',
    0 => 'Large',
    1 => 'Medium',
    2 => 'Small',
    5 => 'Medium 1', #PH
    6 => 'Medium 2', #PH
    7 => 'Medium 3', #PH
    8 => 'Postcard', #PH (SD200 1600x1200 with DateStamp option)
    9 => 'Widescreen', #PH (SD900 3648x2048), 22 (HFS200 3264x1840)
    10 => 'Medium Widescreen', #22 (HFS200 1920x1080)
    14 => 'Small 1', #PH
    15 => 'Small 2', #PH
    16 => 'Small 3', #PH
    128 => '640x480 Movie', #PH (7D 60fps)
    129 => 'Medium Movie', #22
    130 => 'Small Movie', #22
    137 => '1280x720 Movie', #PH (S95 24fps; D60 50fps)
    142 => '1920x1080 Movie', #PH (D60 25fps)
    143 => '4096x2160 Movie', #PH (C200)
);
my %canonWhiteBalance = (
    # -1='Click", -2='Pasted' ?? - PH
    0 => 'Auto',
    1 => 'Daylight',
    2 => 'Cloudy',
    3 => 'Tungsten',
    4 => 'Fluorescent',
    5 => 'Flash',
    6 => 'Custom',
    7 => 'Black & White',
    8 => 'Shade',
    9 => 'Manual Temperature (Kelvin)',
    10 => 'PC Set1', #PH
    11 => 'PC Set2', #PH
    12 => 'PC Set3', #PH
    14 => 'Daylight Fluorescent', #3
    15 => 'Custom 1', #PH
    16 => 'Custom 2', #PH
    17 => 'Underwater', #3
    18 => 'Custom 3', #PH
    19 => 'Custom 4', #PH
    20 => 'PC Set4', #PH
    21 => 'PC Set5', #PH
    # 22 - Custom 2?
    23 => 'Auto (ambience priority)', #PH (5DS) (perhaps this needs re-thinking?: forum13295)
    # 30 - Click White Balance?
    # 31 - Shot Settings?
    # 137 - Tungsten?
    # 138 - White Fluorescent?
    # 139 - Fluorescent H?
    # 140 - Manual?
);

# picture styles used by the 5D
# (styles 0x4X may be downloaded from Canon)
# (called "ColorMatrix" in 1D owner manual)
my %pictureStyles = ( #12
    0x00 => 'None', #PH
    0x01 => 'Standard', #15
    0x02 => 'Portrait', #15
    0x03 => 'High Saturation', #15
    0x04 => 'Adobe RGB', #15
    0x05 => 'Low Saturation', #15
    0x06 => 'CM Set 1', #PH
    0x07 => 'CM Set 2', #PH
    # "ColorMatrix" values end here
    0x21 => 'User Def. 1',
    0x22 => 'User Def. 2',
    0x23 => 'User Def. 3',
    # "External" styles currently available from Canon are Nostalgia, Clear,
    # Twilight and Emerald.  The "User Def" styles change to these "External"
    # codes when these styles are installed in the camera
    0x41 => 'PC 1', #PH
    0x42 => 'PC 2', #PH
    0x43 => 'PC 3', #PH
    0x81 => 'Standard',
    0x82 => 'Portrait',
    0x83 => 'Landscape',
    0x84 => 'Neutral',
    0x85 => 'Faithful',
    0x86 => 'Monochrome',
    0x87 => 'Auto', #PH
    0x88 => 'Fine Detail', #PH
    0xff => 'n/a', #PH (guess)
    0xffff => 'n/a', #PH (guess)
);
my %userDefStyles = ( #12/48
    Notes => q{
        Base style for user-defined picture styles.  PC values represent external
        picture styles which may be downloaded from Canon and installed in the
        camera.
    },
    0x41 => 'PC 1',
    0x42 => 'PC 2',
    0x43 => 'PC 3',
    0x81 => 'Standard',
    0x82 => 'Portrait',
    0x83 => 'Landscape',
    0x84 => 'Neutral',
    0x85 => 'Faithful',
    0x86 => 'Monochrome',
    0x87 => 'Auto', #PH
);

# picture style tag information for CameraInfo550D
my %psConv = (
    -559038737 => 'n/a', # = 0xdeadbeef ! LOL
    OTHER => sub { shift },
);
my %psInfo = (
    Format => 'int32s',
    PrintHex => 1,
    PrintConv => \%psConv,
);

# ValueConv that makes long values binary type
my %longBin = (
    ValueConv => 'length($val) > 64 ? \$val : $val',
    ValueConvInv => '$val',
);

# conversions, etc for CameraColorCalibration tags
my %cameraColorCalibration = (
    Format => 'int16s[4]',
    Unknown => 1,
    PrintConv => 'sprintf("%4d %4d %4d (%dK)", split(" ",$val))',
    PrintConvInv => '$val=~s/\s+/ /g; $val=~tr/()K//d; $val',
);

# conversions, etc for PowerShot CameraColorCalibration tags
my %cameraColorCalibration2 = (
    Format => 'int16s[5]',
    Unknown => 1,
    PrintConv => 'sprintf("%4d %4d %4d %4d (%dK)", split(" ",$val))',
    PrintConvInv => '$val=~s/\s+/ /g; $val=~tr/()K//d; $val',
);
# conversions, etc for byte-swapped FocusDistance tags
my %focusDistanceByteSwap = (
    # this is very odd (little-endian number on odd boundary),
    # but it does seem to work better with my sample images - PH
    Format => 'int16uRev',
    ValueConv => '$val / 100',
    ValueConvInv => '$val * 100',
    PrintConv => '$val > 655.345 ? "inf" : "$val m"',
    PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
);

# common attributes for writable BinaryData directories
my %binaryDataAttrs = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
);

my %offOn = ( 0 => 'Off', 1 => 'On' );

#------------------------------------------------------------------------------
# Canon EXIF Maker Notes
%Image::ExifTool::Canon::Main = (
    WRITE_PROC => \&WriteCanon,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x1 => {
        Name => 'CanonCameraSettings',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::CameraSettings',
        },
    },
    0x2 => {
        Name => 'CanonFocalLength',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::FocalLength' },
    },
    0x3 => {
        Name => 'CanonFlashInfo',
        Unknown => 1,
    },
    0x4 => {
        Name => 'CanonShotInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ShotInfo',
        },
    },
    0x5 => {
        Name => 'CanonPanorama',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::Panorama' },
    },
    0x6 => {
        Name => 'CanonImageType',
        Writable => 'string',
        Groups => { 2 => 'Image' },
    },
    0x7 => {
        Name => 'CanonFirmwareVersion',
        Writable => 'string',
    },
    0x8 => {
        Name => 'FileNumber',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
        PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
        PrintConvInv => '$val=~s/-//g;$val',
    },
    0x9 => {
        Name => 'OwnerName',
        Writable => 'string',
        # pad to 32 bytes (including null terminator which will be added)
        # to avoid bug which crashes DPP if length is 4 bytes
        ValueConvInv => '$val .= "\0" x (31 - length $val) if length $val < 31; $val',
    },
    0xa => {
        Name => 'UnknownD30',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::UnknownD30',
        },
    },
    0xc => [   # square brackets for a conditional list
        {
            # D30
            Name => 'SerialNumber',
            Condition => '$$self{Model} =~ /EOS D30\b/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.4x%.5d",$val>>16,$val&0xffff)',
            PrintConvInv => '$val=~/(.*)-?(\d{5})$/ ? (hex($1)<<16)+$2 : undef',
        },
        {
            # serial number of 1D/1Ds/1D Mark II/1Ds Mark II is usually
            # displayed w/o leeding zeros (ref 7) (1D uses 6 digits - PH)
            Name => 'SerialNumber',
            Condition => '$$self{Model} =~ /EOS-1D/',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.6u",$val)',
            PrintConvInv => '$val',
        },
        {
            # all other models (D60,300D,350D,REBEL,10D,20D,etc)
            Name => 'SerialNumber',
            Writable => 'int32u',
            PrintConv => 'sprintf("%.10u",$val)',
            PrintConvInv => '$val',
        },
    ],
    0xd => [
        {
            Name => 'CanonCameraInfo1D',
            # (save size of this record as "CameraInfoCount" for later tests)
            Condition => '($$self{CameraInfoCount} = $count) and $$self{Model} =~ /\b1DS?$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1D' },
        },
        {
            Name => 'CanonCameraInfo1DmkII',
            Condition => '$$self{Model} =~ /\b1Ds? Mark II$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkII' },
        },
        {
            Name => 'CanonCameraInfo1DmkIIN',
            Condition => '$$self{Model} =~ /\b1Ds? Mark II N$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIIN' },
        },
        {
            Name => 'CanonCameraInfo1DmkIII',
            Condition => '$$self{Model} =~ /\b1Ds? Mark III$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIII' },
        },
        {
            Name => 'CanonCameraInfo1DmkIV',
            Condition => '$$self{Model} =~ /\b1D Mark IV$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1DmkIV' },
        },
        {
            Name => 'CanonCameraInfo1DX',
            Condition => '$$self{Model} =~ /EOS-1D X$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1DX' },
        },
        {
            Name => 'CanonCameraInfo5D',
            Condition => '$$self{Model} =~ /EOS 5D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo5D' },
        },
        {
            Name => 'CanonCameraInfo5DmkII',
            Condition => '$$self{Model} =~ /EOS 5D Mark II$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo5DmkII' },
        },
        {
            Name => 'CanonCameraInfo5DmkIII',
            Condition => '$$self{Model} =~ /EOS 5D Mark III$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo5DmkIII' },
        },
        {
            Name => 'CanonCameraInfo6D',
            Condition => '$$self{Model} =~ /EOS 6D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo6D' },
        },
        {
            Name => 'CanonCameraInfo7D',
            Condition => '$$self{Model} =~ /EOS 7D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo7D' },
        },
        {
            Name => 'CanonCameraInfo40D',
            Condition => '$$self{Model} =~ /EOS 40D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo40D' },
        },
        {
            Name => 'CanonCameraInfo50D',
            Condition => '$$self{Model} =~ /EOS 50D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo50D' },
        },
        {
            Name => 'CanonCameraInfo60D',
            Condition => '$$self{Model} =~ /EOS 60D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo60D' },
        },
        {
            Name => 'CanonCameraInfo70D',
            Condition => '$$self{Model} =~ /EOS 70D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo70D' },
        },
        {
            Name => 'CanonCameraInfo80D',
            Condition => '$$self{Model} =~ /EOS 80D$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo80D' },
        },
        {
            Name => 'CanonCameraInfo450D',
            Condition => '$$self{Model} =~ /\b(450D|REBEL XSi|Kiss X2)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo450D' },
        },
        {
            Name => 'CanonCameraInfo500D',
            Condition => '$$self{Model} =~ /\b(500D|REBEL T1i|Kiss X3)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo500D' },
        },
        {
            Name => 'CanonCameraInfo550D',
            Condition => '$$self{Model} =~ /\b(550D|REBEL T2i|Kiss X4)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo550D' },
        },
        {
            Name => 'CanonCameraInfo600D',
            Condition => '$$self{Model} =~ /\b(600D|REBEL T3i|Kiss X5)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo600D' },
        },
        {
            Name => 'CanonCameraInfo650D',
            Condition => '$$self{Model} =~ /\b(650D|REBEL T4i|Kiss X6i)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo650D' },
        },
        {
            Name => 'CanonCameraInfo700D',
            Condition => '$$self{Model} =~ /\b(700D|REBEL T5i|Kiss X7i)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo650D' },
        },
        {
            Name => 'CanonCameraInfo750D',
            Condition => '$$self{Model} =~ /\b(750D|Rebel T6i|Kiss X8i)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo750D' },
        },
        {
            Name => 'CanonCameraInfo760D',
            Condition => '$$self{Model} =~ /\b(760D|Rebel T6s|8000D)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo750D' },
        },
        {
            Name => 'CanonCameraInfo1000D',
            Condition => '$$self{Model} =~ /\b(1000D|REBEL XS|Kiss F)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo1000D' },
        },
        {
            Name => 'CanonCameraInfo1100D',
            Condition => '$$self{Model} =~ /\b(1100D|REBEL T3|Kiss X50)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo600D' },
        },
        {
            Name => 'CanonCameraInfo1200D',
            Condition => '$$self{Model} =~ /\b(1200D|REBEL T5|Kiss X70)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfo60D' },
        },
        {
            Name => 'CanonCameraInfoR6',
            Condition => '$$self{Model} =~ /\bEOS R[56]$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoR6' },
        },
        {
            Name => 'CanonCameraInfoR6m2',
            Condition => '$$self{Model} =~ /\bEOS (R6m2|R8|R50)$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoR6m2' },
        },
        {
            Name => 'CanonCameraInfoR6m3',
            Condition => '$$self{Model} =~ /\bEOS R6 Mark III$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoR6m3' },
        },
        {
            Name => 'CanonCameraInfoG5XII',
            Condition => '$$self{Model} =~ /\bG5 X Mark II$/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoG5XII' },
        },
        {
            Name => 'CanonCameraInfoPowerShot',
            # valid if format is int32u[138] or int32u[148]
            Condition => '$format eq "int32u" and ($count == 138 or $count == 148)',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoPowerShot' },
        },
        {
            Name => 'CanonCameraInfoPowerShot2',
            # valid if format is int32u[162], int32u[167], int32u[171] or int32u[264]
            Condition => q{
                $format eq "int32u" and ($count == 156 or $count == 162 or
                $count == 167 or $count == 171 or $count == 264)
            },
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoPowerShot2' },
        },
        {
            Name => 'CanonCameraInfoUnknown32',
            Condition => '$format =~ /^int32/',
            # (counts of 72, 85, 86, 93, 94, 96, 104) - PH
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoUnknown32' },
        },
        {
            Name => 'CanonCameraInfoUnknown16',
            Condition => '$format =~ /^int16/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoUnknown16' },
        },
        {
            Name => 'CanonCameraInfoUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::CameraInfoUnknown' },
        },
    ],
    0xe => {
        Name => 'CanonFileLength',
        Writable => 'int32u',
        Groups => { 2 => 'Image' },
    },
    0xf => [
        {   # used by 1DmkII, 1DSmkII and 1DmkIIN
            Name => 'CustomFunctions1D',
            Condition => '$$self{Model} =~ /EOS-1D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
            },
        },
        {
            Name => 'CustomFunctions5D',
            Condition => '$$self{Model} =~ /EOS 5D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions5D',
            },
        },
        {
            Name => 'CustomFunctions10D',
            Condition => '$$self{Model} =~ /EOS 10D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions10D',
            },
        },
        {
            Name => 'CustomFunctions20D',
            Condition => '$$self{Model} =~ /EOS 20D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions20D',
            },
        },
        {
            Name => 'CustomFunctions30D',
            Condition => '$$self{Model} =~ /EOS 30D/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions30D',
            },
        },
        {
            Name => 'CustomFunctions350D',
            Condition => '$$self{Model} =~ /\b(350D|REBEL XT|Kiss Digital N)\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions350D',
            },
        },
        {
            Name => 'CustomFunctions400D',
            Condition => '$$self{Model} =~ /\b(400D|REBEL XTi|Kiss Digital X|K236)\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::Functions400D',
            },
        },
        {
            Name => 'CustomFunctionsD30',
            Condition => '$$self{Model} =~ /EOS D30\b/',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsD60',
            Condition => '$$self{Model} =~ /EOS D60\b/',
            SubDirectory => {
                # the stored size in the D60 apparently doesn't include the size word:
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size-2,$size)',
                # (D60 custom functions are basically the same as D30)
                TagTable => 'Image::ExifTool::CanonCustom::FunctionsD30',
            },
        },
        {
            Name => 'CustomFunctionsUnknown',
            SubDirectory => {
                Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
                TagTable => 'Image::ExifTool::CanonCustom::FuncsUnknown',
            },
        },
    ],
    0x10 => { #PH
        Name => 'CanonModelID',
        Writable => 'int32u',
        PrintHex => 1,
        SeparateTable => 1,
        PrintConv => \%canonModelID,
    },
    0x11 => { #PH
        Name => 'MovieInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MovieInfo',
        },
    },
    0x12 => {
        Name => 'CanonAFInfo',
        # not really a condition -- just need to store the count for later
        Condition => '$$self{AFInfoCount} = $count',
        SubDirectory => {
            # this record does not begin with a length word, so it
            # has to be validated differently
            Validate => 'Image::ExifTool::Canon::ValidateAFInfo($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFInfo',
        },
    },
    0x13 => { #PH
        Name => 'ThumbnailImageValidArea',
        # left,right,top,bottom edges of image in thumbnail, or all zeros for full frame
        Notes => 'all zeros for full frame',
        Writable => 'int16u',
        Count => 4,
    },
    0x15 => { #PH
        # display format for serial number
        Name => 'SerialNumberFormat',
        Writable => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0x90000000 => 'Format 1',
            0xa0000000 => 'Format 2',
        },
    },
    0x1a => { #15
        Name => 'SuperMacro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On (1)',
            2 => 'On (2)',
        },
    },
    0x1c => { #PH (A570IS)
        Name => 'DateStampMode',
        Writable => 'int16u',
        Notes => 'used only in postcard mode',
        PrintConv => {
            0 => 'Off',
            1 => 'Date',
            2 => 'Date & Time',
        },
    },
    0x1d => { #PH
        Name => 'MyColors',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MyColors',
        },
    },
    0x1e => { #PH
        Name => 'FirmwareRevision',
        Writable => 'int32u',
        # as a hex number: 0xAVVVRR00, where (a bit of guessing here...)
        #  A = 'a' for alpha, 'b' for beta?
        #  V = version? (100,101 for normal releases, 100,110,120,130,170 for alpha/beta)
        #  R = revision? (01-07, except 00 for alpha/beta releases)
        PrintConv => q{
            my $rev = sprintf("%.8x", $val);
            my ($rel, $v1, $v2, $r1, $r2) = ($rev =~ /^(.)(.)(..)0?(.+)(..)$/);
            my %r = ( a => 'Alpha ', b => 'Beta ', '0' => '' );
            $rel = defined $r{$rel} ? $r{$rel} : "Unknown($rel) ";
            return "$rel$v1.$v2 rev $r1.$r2",
        },
        PrintConvInv => q{
            $_=$val; s/Alpha ?/a/i; s/Beta ?/b/i;
            s/Unknown ?\((.)\)/$1/i; s/ ?rev ?(.)\./0$1/; s/ ?rev ?//;
            tr/a-fA-F0-9//dc; return hex $_;
        },
    },
    # 0x1f - used for red-eye-corrected images - PH (A570IS)
    # 0x22 - values 1 and 2 are 2 and 1 for flash pics, 0 otherwise - PH (A570IS)
    0x23 => { #31
        Name => 'Categories',
        Writable => 'int32u',
        Format => 'int32u', # (necessary to perform conversion for Condition)
        Notes => '2 values: 1. always 8, 2. Categories',
        Count => '2',
        Condition => '$$valPt =~ /^\x08\0\0\0/',
        ValueConv => '$val =~ s/^8 //; $val',
        ValueConvInv => '"8 $val"',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'People',
                1 => 'Scenery',
                2 => 'Events',
                3 => 'User 1',
                4 => 'User 2',
                5 => 'User 3',
                6 => 'To Do',
            },
        },
    },
    0x24 => { #PH
        Name => 'FaceDetect1',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FaceDetect1',
        },
    },
    0x25 => { #PH
        Name => 'FaceDetect2',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::FaceDetect2',
            # (can't validate because this record uses a 1-byte count instead of a 2-byte count)
        },
    },
    0x26 => { #PH (A570IS,1DmkIII)
        Name => 'CanonAFInfo2',
        Condition => '$$valPt !~ /^\0\0\0\0/', # (data may be all zeros in thumbnail of 60D MOV video)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFInfo2',
        },
    },
    0x27 => { #PH
        Name => 'ContrastInfo',
        Condition => '$$valPt =~ /^\x0a\0/', # (seems to be various versions of this information)
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ContrastInfo' },
    },
    # 0x27 - value 1 is 1 for high ISO pictures, 0 otherwise
    #        value 4 is 9 for Flexizone and FaceDetect AF, 1 for Centre AF, 0 otherwise (SX10IS)
    0x28 => { #JD
        # bytes 0-1=sequence number (encrypted), 2-5=date/time (encrypted) (ref JD)
        Name => 'ImageUniqueID',
        Format => 'undef',
        Writable => 'int8u',
        Groups => { 2 => 'Image' },
        RawConv => '$val eq "\0" x 16 ? undef : $val',
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'pack("H*", $val)',
    },
    0x29 => { #IB (G9)
        Name => 'WBInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::WBInfo' },
    },
    # 0x2d - changes with categories (ref 31)
    0x2f => { #PH (G12)
        Name => 'FaceDetect3',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FaceDetect3',
        },
    },
    # 0x32 - if length is 768, starting at offset 4 there are 6 RGGB 1/val int16 records:
    #        daylight,cloudy,tungsten,fluorescent,flash,kelvin (D30 2001, ref IB)
    0x35 => { #PH
        Name => 'TimeInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::TimeInfo',
        },
    },
    0x38 => { #PH
        Name => 'BatteryType',
        Writable => 'undef',
        Condition => '$count == 76',
        RawConv => '$val=~/^.{4}([^\0]+)/s ? $1 : undef',
        RawConvInv => 'substr("\x4c\0\0\0".$val.("\0"x72), 0, 76)',
    },
    0x3c => { #PH (G1XmkII)
        Name => 'AFInfo3',
        Condition => '$$self{AFInfo3} = 1',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFInfo2',
        },
    },
    # 0x44 (ShootInfo)
    # 0x62 (UserSetting)
    0x81 => { #13
        Name => 'RawDataOffset',
        # (can't yet write 1D raw files)
        # Writable => 'int32u',
        # Protected => 2,
    },
    0x82 => { #github219 (found on 1DS)
         Name => 'RawDataLength',
         # (can't yet write 1DS raw files)
         # Writable => 'int32u',
         # Protected => 2,
    },
    0x83 => { #PH
        Name => 'OriginalDecisionDataOffset',
        Writable => 'int32u',
        OffsetPair => 1, # (just used as a flag, since this tag has no pair)
        # this is an offset to the original decision data block
        # (offset relative to start of file in JPEG images, but NOT DNG images!)
        IsOffset => '$val and $$et{FILE_TYPE} ne "JPEG"',
        Protected => 2,
        DataTag => 'OriginalDecisionData',
    },
    0x90 => {   # used by 1D and 1Ds
        Name => 'CustomFunctions1D',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions1D',
        },
    },
    0x91 => { #PH
        Name => 'PersonalFunctions',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::PersonalFuncs',
        },
    },
    0x92 => { #PH
        Name => 'PersonalFunctionValues',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::PersonalFuncValues',
        },
    },
    0x93 => {
        Name => 'CanonFileInfo', # (ShootInfoEx)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FileInfo',
        },
    },
    0x94 => { #PH
        # AF points for 1D (45 points in 5 rows)
        Name => 'AFPointsInFocus1D',
        Notes => 'EOS 1D -- 5 rows: A1-7, B1-10, C1-11, D1-10, E1-7, center point is C6',
        PrintConv => 'Image::ExifTool::Canon::PrintAFPoints1D($val)',
    },
    0x95 => { #PH (observed in 5D sample image)
        Name => 'LensModel', # (LensName)
        Writable => 'string',
    },
    0x96 => [ #PH (CMOSNumber)
        {
            Name => 'SerialInfo',
            Condition => '$$self{Model} =~ /EOS 5D/',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::SerialInfo' },
        },
        {
            Name => 'InternalSerialNumber',
            Writable => 'string',
            # remove trailing 0xff's if they exist (Kiss X3)
            ValueConv => '$val=~s/\xff+$//; $val',
            ValueConvInv => '$val',
        },
    ],
    0x97 => { #PH (also see http://www.freepatentsonline.com/7657116.html)
        Name => 'DustRemovalData', # (DustDeleteData)
        Writable => 'undef',
        Flags => [ 'Binary', 'Protected' ],
        # 0x00: int8u  - Version (0 or 1)
        # 0x01: int8u  - LensInfo ? (1)
        # 0x02: int8u  - AVValue ? (int8u for version 0, int16u for version 1)
        # 0x03: int8u  - POValue ? (int8u for version 0, int16u for version 1)
        # 0x04: int16u - DustCount
        # 0x06: int16u - FocalLength ?
        # 0x08: int16u - LensID ?
        # 0x0a: int16u - Width
        # 0x0c: int16u - Height
        # 0x0e: int16u - RAW_Width
        # 0x10: int16u - RAW_Height
        # 0x12: int16u - PixelPitch [um * 1000]
        # 0x14: int16u - LpfDistance [mm * 1000]
        # 0x16: int8u  - TopOffset
        # 0x17: int8u  - BottomOffset
        # 0x18: int8u  - LeftOffset
        # 0x19: int8u  - RightOffset
        # 0x1a: int8u  - Year [-1900]
        # 0x1b: int8u  - Month
        # 0x1c: int8u  - Day
        # 0x1d: int8u  - Hour
        # 0x1e: int8u  - Minutes
        # 0x1f: int8u  - BrightDiff
        # Table with DustCount entries:
        # 0x22: int16u - DustX
        # 0x24: int16u - DustY
        # 0x26: int16u - DustSize
    },
    0x98 => { #PH
        Name => 'CropInfo', # (ImageSizeOffset)
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CropInfo' },
    },
    0x99 => { #PH (EOS 1D Mark III, 40D, etc)
        Name => 'CustomFunctions2', # (CustomFunEx)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::CanonCustom::Functions2',
        },
    },
    0x9a => { #PH
        Name => 'AspectInfo', # (AspectRatioInfo)
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::AspectInfo' },
    },
    0xa0 => {
        Name => 'ProcessingInfo', # (DevelopParam)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Processing',
        },
    },
    0xa1 => { Name => 'ToneCurveTable', %longBin }, #PH
    0xa2 => { Name => 'SharpnessTable', %longBin }, #PH
    0xa3 => { Name => 'SharpnessFreqTable', %longBin }, #PH
    0xa4 => { Name => 'WhiteBalanceTable', %longBin }, #PH
    0xa9 => {
        Name => 'ColorBalance',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ColorBalance',
        },
    },
    0xaa => {
        Name => 'MeasuredColor', # (PresetWBDS)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MeasuredColor',
        },
    },
    0xae => {
        Name => 'ColorTemperature',
        Writable => 'int16u',
    },
    0xb0 => { #PH
        Name => 'CanonFlags',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Flags',
        },
    },
    0xb1 => { #PH
        Name => 'ModifiedInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::ModifiedInfo',
        },
    },
    0xb2 => { Name => 'ToneCurveMatching', %longBin }, #PH
    0xb3 => { Name => 'WhiteBalanceMatching', %longBin }, #PH
    0xb4 => { #PH
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            65535 => 'n/a',
        },
    },
    0xb6 => {
        Name => 'PreviewImageInfo',
        SubDirectory => {
            # Note: the first word of this block gives the correct block size in bytes, but
            # the size is wrong by a factor of 2 in the IFD, so we must account for this
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size/2)',
            TagTable => 'Image::ExifTool::Canon::PreviewImageInfo',
        },
    },
    0xd0 => { #PH
        Name => 'VRDOffset',
        Writable => 'int32u',
        OffsetPair => 1, # (just used as a flag, since this tag has no pair)
        Protected => 2,
        DataTag => 'CanonVRD',
        Notes => 'offset of VRD "recipe data" if it exists',
    },
    0xe0 => { #12
        Name => 'SensorInfo', # (ImageAreaDesc)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::SensorInfo',
        },
    },
    0x4001 => [ #13 (WBPacket)
        {   # (int16u[582]) - 20D and 350D
            Condition => '$count == 582',
            Name => 'ColorData1',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData1' },
        },
        {   # (int16u[653]) - 1DmkII and 1DSmkII
            Condition => '$count == 653',
            Name => 'ColorData2',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData2' },
        },
        {   # (int16u[796]) - 1DmkIIN, 5D, 30D, 400D
            Condition => '$count == 796',
            Name => 'ColorData3',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData3' },
        },
        {   # (int16u[692|674|702|1227|1250|1251|1337])
            # 40D (692), 1DmkIII (674), 1DSmkIII (702), 450D/1000D (1227)
            # 50D/5DmkII (1250), 500D/7D_pre-prod/1DmkIV_pre-prod (1251),
            # 1DmkIV/7D/550D_pre-prod (1337), 550D (1338), 60D/1100D (1346)
            Condition => q{
                $count == 692  or $count == 674  or $count == 702 or
                $count == 1227 or $count == 1250 or $count == 1251 or
                $count == 1337 or $count == 1338 or $count == 1346
            },
            Name => 'ColorData4',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData4' },
        },
        {   # (int16u[5120]) - G10, G7X
            Condition => '$count == 5120',
            Name => 'ColorData5',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData5' },
        },
        {   # (int16u[1273|1275]) - 600D (1273), 1200D (1275)
            Condition => '$count == 1273 or $count == 1275',
            Name => 'ColorData6',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData6' },
        },
        {   # (int16u[1312|1313|1316])
            # 1DX/5DmkIII/650D/700D/M (1312), 6D/70D/100D (1313),
            # 1DX firmware 1.x (1316), 7DmkII (1506)
            Condition => '$count == 1312 or $count == 1313 or $count == 1316 or
                          $count == 1506',
            Name => 'ColorData7',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData7' },
        },
        {   # (int16u[1560|1592]) - 5DS/5DSR (1560), 80D (1592), 1300D (1353) ref IB
            Condition => '$count == 1560 or $count == 1592 or $count == 1353 or $count == 1602',
            Name => 'ColorData8',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData8' },
        },
        {   # (int16u[1816|1820|1824]) - M50 (1820) ref PH, EOS R (1824), EOS RP, SX70 (1816) ref IB
            Condition => '$count == 1816 or $count == 1820 or $count == 1824',
            Name => 'ColorData9',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData9' },
        },
        {   # (int16u[2024|3656]) - 1DXmkIII (2024) ref IB, R5/R6 (3656) ref PH
            Condition => '$count == 2024 or $count == 3656',
            Name => 'ColorData10',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData10' },
        },
        {   # (int16u[3973]) - R3 ref IB
            Condition => '($count == 3973 or $count == 3778) and $$valPt !~ /^\x41\0/',
            Name => 'ColorData11',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData11' },
        },
        {   # (int16u[4528]) - R1/R5mkII (4528) ref forum16406, R50V (3778) ref PH
            Condition => '$count == 4528 or $count == 3778',
            Name => 'ColorData12',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorData12' },
        },
        {
            Name => 'ColorDataUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorDataUnknown' },
        },
    ],
    0x4002 => { #PH
        # unknown data block in some JPEG and CR2 images
        # (5kB for most models, but 22kb for 5D and 30D, and 43kB for 5DmkII so Drop it)
        Name => 'CRWParam',
        Format => 'undef',
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x4003 => { #PH
        Name => 'ColorInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorInfo' },
    },
    0x4005 => { #PH
        Name => 'Flavor',
        Notes => 'unknown 49kB block, not copied to JPEG images',
        # 'Drop' because not found in JPEG images (too large for APP1 anyway)
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x4008 => { #53
        Name => 'PictureStyleUserDef', # (BasePictStyleOfUser)
        Writable => 'int16u',
        Count => 3, # UserDef1, UserDef2, UserDef3
        PrintHex => 1,
        SeparateTable => 'PictureStyle',
        PrintConv => [\%pictureStyles,\%pictureStyles,\%pictureStyles],
    },
    0x4009 => { #53
        Name => 'PictureStylePC', # (BasePictStyleOfUser)
        Writable => 'int16u',
        Count => 3, # PC1, PC2, PC3
        PrintHex => 1,
        SeparateTable => 'PictureStyle',
        PrintConv => [\%pictureStyles,\%pictureStyles,\%pictureStyles],
    },
    0x4010 => { #forum2933
        Name => 'CustomPictureStyleFileName', # (PictStyleCaption)
        Writable => 'string',
    },
    # 0x4011 (PictStyleAppendInfo)
    # 0x4012 (CustomWBCaption)
    0x4013 => { #PH
        Name => 'AFMicroAdj', # (AFMicroAdjust)
        SubDirectory => {
            # Canon DPP 3.13 is known to truncate this data to 0x14 bytes (from 0x2c),
            # so specifically check for 0x2c to avoid giving a warning in this case
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size,0x2c)',
            TagTable => 'Image::ExifTool::Canon::AFMicroAdj',
        },
    },
    # 0x4014 (similar to 0x83?)
    0x4015 => [{
        Name => 'VignettingCorr', # (LensPacket)
        Condition => '$$valPt =~ /^\0/ and $$valPt !~ /^(\0\0\0\0|\x00\x40\xdc\x05)/', # (data may be all zeros for 60D)
        SubDirectory => {
            # (the size word is at byte 2 in this structure)
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart+2,$size)',
            TagTable => 'Image::ExifTool::Canon::VignettingCorr',
        },
    },{
        Name => 'VignettingCorrUnknown1',
        Condition => '$$valPt =~ /^[\x01\x02\x10\x20]/ and $$valPt !~ /^(\0\0\0\0|\x02\x50\x7c\x04)/',
        SubDirectory => {
            # (the size word is at byte 2 in this structure)
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart+2,$size)',
            TagTable => 'Image::ExifTool::Canon::VignettingCorrUnknown',
        },
    },{
        Name => 'VignettingCorrUnknown2',
        Condition => '$$valPt !~ /^\0\0\0\0/',
        SubDirectory => {
            # (the size word is at byte 4 for version 3 of this structure, but not always!)
            # Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart+4,$size)',
            TagTable => 'Image::ExifTool::Canon::VignettingCorrUnknown',
        },
    }],
    0x4016 => {
        Name => 'VignettingCorr2', # (ImageCorrectActual)
        SubDirectory => {
            # (the size word is actually 4 bytes, but it doesn't matter if little-endian)
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::VignettingCorr2',
        },
    },
    0x4018 => { #PH
        Name => 'LightingOpt', # (ImageCorrect)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::LightingOpt',
        }
    },
    0x4019 => { #20
        Name => 'LensInfo', # (LensInfoForService)
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::LensInfo',
        }
    },
    0x4020 => { #PH
        Name => 'AmbienceInfo',
        Condition => '$$valPt !~ /^\0\0\0\0/', # (data may be all zeros for 60D)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::Ambience',
        }
    },
    0x4021 => { #PH
        Name => 'MultiExp', # (ExifDSTagMultipleExposure)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::MultiExp',
        }
    },
    0x4024 => { #PH
        Name => 'FilterInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FilterInfo',
        }
    },
    0x4025 => { #PH
        Name => 'HDRInfo', # (HighDynamicRange)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::HDRInfo',
        }
    },
    0x4026 => { #github#119
        Name => 'LogInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::LogInfo',
        }
    },
    0x4028 => { #PH
        Name => 'AFConfig', # (AFTabInfo)
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::AFConfig',
        }
    },
  # 0x402b - crop information (forum14904)
    0x403f => { #25
        Name => 'RawBurstModeRoll',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::RawBurstInfo',
        }
    },
  # 0x4049 - related to croping (forum13491) - "8 0 0 0" = no crop, "8 1 0 1" = crop enabled
    0x4053 => { #github380
        Name => 'FocusBracketingInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::FocusBracketingInfo',
        }
    },
    0x4059 => { #forum16111
        Name => 'LevelInfo',
        SubDirectory => {
            Validate => 'Image::ExifTool::Canon::Validate($dirData,$subdirStart,$size)',
            TagTable => 'Image::ExifTool::Canon::LevelInfo',
        }
    },
);

#..............................................................................
# Canon camera settings (MakerNotes tag 0x01)
# BinaryData (keys are indices into the int16s array)
%Image::ExifTool::Canon::CameraSettings = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    DATAMEMBER => [ 22, 25 ],   # necessary for writing
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'MacroMode',
        PrintConv => {
            1 => 'Macro',
            2 => 'Normal',
        },
    },
    2 => {
        Name => 'SelfTimer',
        # Custom timer mode if bit 0x4000 is set - PH (A570IS)
        PrintConv => q{
            return 'Off' unless $val;
            return (($val&0xfff) / 10) . ' s' . ($val & 0x4000 ? ', Custom' : '');
        },
        PrintConvInv => q{
            return 0 if $val =~ /^Off/i;
            $val =~ s/\s*s(ec)?\b//i;
            $val =~ s/,?\s*Custom$//i ? ($val*10) | 0x4000 : $val*10;
        },
    },
    3 => {
        Name => 'Quality',
        PrintConv => \%canonQuality,
    },
    4 => {
        Name => 'CanonFlashMode',
        PrintConv => {
            -1 => 'n/a', # (PH, EOS M MOV video)
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
            3 => 'Red-eye reduction',
            4 => 'Slow-sync',
            5 => 'Red-eye reduction (Auto)',
            6 => 'Red-eye reduction (On)',
            16 => 'External flash', # not set in D30 or 300D
        },
    },
    5 => {
        Name => 'ContinuousDrive',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            2 => 'Movie', #PH
            3 => 'Continuous, Speed Priority', #PH
            4 => 'Continuous, Low', #PH
            5 => 'Continuous, High', #PH
            6 => 'Silent Single', #PH
            8 => 'Continuous, High+', #WolfgangGulcker
            # ref A: https://exiftool.org/forum/index.php/topic,5701.msg27843.html#msg27843
            9 => 'Single, Silent', #A
            10 => 'Continuous, Silent', #A
            # 11 - seen for SX260
            # 32-34 - Self-timer?
        },
    },
    7 => {
        Name => 'FocusMode',
        PrintConv => {
            0 => 'One-shot AF',
            1 => 'AI Servo AF',
            2 => 'AI Focus AF',
            3 => 'Manual Focus (3)',
            4 => 'Single',
            5 => 'Continuous',
            6 => 'Manual Focus (6)',
           16 => 'Pan Focus', #PH
           # 137 - Single?
           256 => 'One-shot AF (Live View)', #PH/forum15637
           257 => 'AI Servo AF (Live View)', #PH/forum15637
           258 => 'AI Focus AF (Live View)', #PH/forum15637
           512 => 'Movie Snap Focus', #48
           519 => 'Movie Servo AF', #PH (NC, EOS M)
        },
    },
    9 => { #PH
        Name => 'RecordMode',
        RawConv => '$val==-1 ? undef : $val', #22
        PrintConv => {
            1 => 'JPEG',
            2 => 'CRW+THM', # (300D,etc)
            3 => 'AVI+THM', # (30D)
            4 => 'TIF', # +THM? (1Ds) (unconfirmed)
            5 => 'TIF+JPEG', # (1D) (unconfirmed)
            6 => 'CR2', # +THM? (1D,30D,350D)
            7 => 'CR2+JPEG', # (S30)
            9 => 'MOV', # (S95 MOV)
            10 => 'MP4', # (SX280 MP4)
            11 => 'CRM', #PH (C200 CRM)
            12 => 'CR3', #PH (EOS R)
            13 => 'CR3+JPEG', #PH (EOS R)
            14 => 'HIF', #PH (NC)
            15 => 'CR3+HIF', #PH (1DXmkIII)
        },
    },
    10 => {
        Name => 'CanonImageSize',
        PrintConvColumns => 2,
        PrintConv => \%canonImageSize,
    },
    11 => {
        Name => 'EasyMode',
        PrintConvColumns => 3,
        PrintConv => {
            # references:
            # A = http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm
            # B = http://www.burren.cx/david/canon.html
            # C = DPP 3.11.26
            0 => 'Full auto',
            1 => 'Manual',
            2 => 'Landscape',
            3 => 'Fast shutter',
            4 => 'Slow shutter',
            5 => 'Night', # (C='Night Scene')
            6 => 'Gray Scale', #PH (A/B/C='Black & White')
            7 => 'Sepia',
            8 => 'Portrait',
            9 => 'Sports',
            10 => 'Macro',
            11 => 'Black & White', #PH (A='Black & White', B/C='Pan focus')
            12 => 'Pan focus', # (A='Pan focus', C='Vivid')
            13 => 'Vivid', #PH (A='Vivid', C='Neutral')
            14 => 'Neutral', #PH (A='Natural', C='Black & White')
            15 => 'Flash Off',  #8 (C=<none>)
            16 => 'Long Shutter', #PH
            17 => 'Super Macro', #PH (C='Macro')
            18 => 'Foliage', #PH
            19 => 'Indoor', #PH
            20 => 'Fireworks', #PH
            21 => 'Beach', #PH
            22 => 'Underwater', #PH
            23 => 'Snow', #PH
            24 => 'Kids & Pets', #PH
            25 => 'Night Snapshot', #PH
            26 => 'Digital Macro', #PH
            27 => 'My Colors', #PH
            28 => 'Movie Snap', #PH
            29 => 'Super Macro 2', #PH
            30 => 'Color Accent', #18
            31 => 'Color Swap', #18
            32 => 'Aquarium', #18
            33 => 'ISO 3200', #18
            34 => 'ISO 6400', #PH
            35 => 'Creative Light Effect', #PH
            36 => 'Easy', #PH
            37 => 'Quick Shot', #PH
            38 => 'Creative Auto', #39
            39 => 'Zoom Blur', #PH
            40 => 'Low Light', #PH
            41 => 'Nostalgic', #PH
            42 => 'Super Vivid', #PH (SD4500)
            43 => 'Poster Effect', #PH (SD4500)
            44 => 'Face Self-timer', #PH
            45 => 'Smile', #PH
            46 => 'Wink Self-timer', #PH
            47 => 'Fisheye Effect', #PH (SX30IS,IXUS240)
            48 => 'Miniature Effect', #PH (SD4500)
            49 => 'High-speed Burst', #PH
            50 => 'Best Image Selection', #PH
            51 => 'High Dynamic Range', #PH (S95)
            52 => 'Handheld Night Scene', #PH
            53 => 'Movie Digest', #PH
            54 => 'Live View Control', #PH
            55 => 'Discreet', #PH
            56 => 'Blur Reduction', #PH
            57 => 'Monochrome', #PH (SX260 B&W,Sepia,Blue tone)
            58 => 'Toy Camera Effect', #51
            59 => 'Scene Intelligent Auto', #PH (T3i) (C='High-speed Burst HQ' !!)
            60 => 'High-speed Burst HQ', #PH (C='High-speed Burst HQ', same as 59)
            61 => 'Smooth Skin', #51
            62 => 'Soft Focus', #PH (SX260,IXUS240)
            68 => 'Food', #PH (250D)
            # 83 - seen for EOS M200 (ref PH)
            84 => 'HDR Art Standard', #PH (80D)
            85 => 'HDR Art Vivid', #PH (80D)
            93 => 'HDR Art Bold', #PH (80D)
            # 83 - seen for EOS M3 night shot (PH)
            257 => 'Spotlight', #PH
            258 => 'Night 2', #PH
            259 => 'Night+',
            260 => 'Super Night', #PH
            261 => 'Sunset', #PH (SX10IS)
            263 => 'Night Scene', #PH
            264 => 'Surface', #PH
            265 => 'Low Light 2', #PH
        },
    },
    12 => {
        Name => 'DigitalZoom',
        PrintConv => {
            0 => 'None',
            1 => '2x',
            2 => '4x',
            3 => 'Other',  # value obtained from 2*$val[37]/$val[36]
        },
    },
    13 => {
        Name => 'Contrast',
        RawConv => '$val == 0x7fff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    14 => {
        Name => 'Saturation',
        RawConv => '$val == 0x7fff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    15 => {
        Name => 'Sharpness',
        RawConv => '$val == 0x7fff ? undef : $val',
        Notes => q{
            some models use a range of -2 to +2 where 0 is normal sharpening, and
            others use a range of 0 to 7 where 0 is no sharpening
        },
        PrintConv => '$val > 0 ? "+$val" : $val',
        PrintConvInv => '$val',
    },
    16 => {
        Name => 'CameraISO',
        RawConv => '$val == 0x7fff ? undef : $val',
        ValueConv => 'Image::ExifTool::Canon::CameraISO($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CameraISO($val,1)',
    },
    17 => {
        Name => 'MeteringMode',
        PrintConv => {
            0 => 'Default', # older Ixus
            1 => 'Spot',
            2 => 'Average', #PH
            3 => 'Evaluative',
            4 => 'Partial',
            5 => 'Center-weighted average',
        },
    },
    18 => {
        # this is always 2 for the 300D - PH
        Name => 'FocusRange',
        PrintConv => {
            0 => 'Manual',
            1 => 'Auto',
            2 => 'Not Known',
            3 => 'Macro',
            4 => 'Very Close', #PH
            5 => 'Close', #PH
            6 => 'Middle Range', #PH
            7 => 'Far Range',
            8 => 'Pan Focus',
            9 => 'Super Macro', #PH
            10=> 'Infinity', #PH
        },
    },
    19 => {
        Name => 'AFPoint',
        Flags => 'PrintHex',
        RawConv => '$val==0 ? undef : $val',
        PrintConv => {
            0x2005 => 'Manual AF point selection',
            0x3000 => 'None (MF)',
            0x3001 => 'Auto AF point selection',
            0x3002 => 'Right',
            0x3003 => 'Center',
            0x3004 => 'Left',
            0x4001 => 'Auto AF point selection',
            0x4006 => 'Face Detect', #PH (A570IS)
        },
    },
    20 => {
        Name => 'CanonExposureMode',
        PrintConv => {
            0 => 'Easy',
            1 => 'Program AE',
            2 => 'Shutter speed priority AE',
            3 => 'Aperture-priority AE',
            4 => 'Manual',
            5 => 'Depth-of-field AE',
            6 => 'M-Dep', #PH
            7 => 'Bulb', #30
            8 => 'Flexible-priority AE', #ArnoldVanOostrum
        },
    },
    22 => { #4
        Name => 'LensType',
        Format => 'int16u',
        RawConv => '$val ? $$self{LensType}=$val : undef', # don't use if value is zero
        Notes => 'this value is incorrect for EOS 7D images with lenses of type 256 or greater',
        SeparateTable => 1,
        DataMember => 'LensType',
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    23 => {
        Name => 'MaxFocalLength',
        Format => 'int16u',
        # this is a bit tricky, but we need the FocalUnits to convert this to mm
        RawConvInv => '$val * ($$self{FocalUnits} || 1)',
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    24 => {
        Name => 'MinFocalLength',
        Format => 'int16u',
        RawConvInv => '$val * ($$self{FocalUnits} || 1)',
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    25 => {
        Name => 'FocalUnits',
        # conversion from raw focal length values to mm
        DataMember => 'FocalUnits',
        RawConv => '$$self{FocalUnits} = $val',
        PrintConv => '"$val/mm"',
        PrintConvInv => '$val=~s/\s*\/?\s*mm//;$val',
    },
    26 => { #9
        Name => 'MaxAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    27 => { #PH
        Name => 'MinAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    28 => {
        Name => 'FlashActivity',
        RawConv => '$val==-1 ? undef : $val',
    },
    29 => {
        Name => 'FlashBits',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Manual', #PH
                1 => 'TTL', #PH
                2 => 'A-TTL', #PH
                3 => 'E-TTL', #PH
                4 => 'FP sync enabled',
                7 => '2nd-curtain sync used',
                11 => 'FP sync used',
                13 => 'Built-in',
                14 => 'External', #(may not be set in manual mode - ref 37)
            },
        },
    },
    32 => {
        Name => 'FocusContinuous',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Single',
            1 => 'Continuous',
            8 => 'Manual', #22
        },
    },
    33 => { #PH
        Name => 'AESetting',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Normal AE',
            1 => 'Exposure Compensation',
            2 => 'AE Lock',
            3 => 'AE Lock + Exposure Comp.',
            4 => 'No AE',
        },
    },
    34 => { #PH
        Name => 'ImageStabilization',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Shoot Only', #15
            3 => 'Panning', # (A570IS)
            4 => 'Dynamic', # (SX30IS) (was 'On, Video')
            # (don't know what bit 0x100 indicates)
            256 => 'Off (2)',
            257 => 'On (2)',
            258 => 'Shoot Only (2)',
            259 => 'Panning (2)',
            260 => 'Dynamic (2)',
        },
    },
    35 => { #PH
        Name => 'DisplayAperture',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    36 => 'ZoomSourceWidth', #PH
    37 => 'ZoomTargetWidth', #PH
    39 => { #22
        Name => 'SpotMeteringMode',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'Center',
            1 => 'AF Point',
        },
    },
    40 => { #PH
        Name => 'PhotoEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Vivid',
            2 => 'Neutral',
            3 => 'Smooth',
            4 => 'Sepia',
            5 => 'B&W',
            6 => 'Custom',
            100 => 'My Color Data',
        },
    },
    41 => { #PH (A570IS)
        Name => 'ManualFlashOutput',
        PrintHex => 1,
        PrintConv => {
            0 => 'n/a',
            0x500 => 'Full',
            0x502 => 'Medium',
            0x504 => 'Low',
            0x7fff => 'n/a', # (EOS models)
        },
    },
    # 41 => non-zero for manual flash intensity - PH (A570IS)
    42 => {
        Name => 'ColorTone',
        RawConv => '$val == 0x7fff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    46 => { #PH
        Name => 'SRAWQuality',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'n/a',
            1 => 'sRAW1 (mRAW)',
            2 => 'sRAW2 (sRAW)',
        },
    },
    # 47 - related to aspect ratio: 100=4:3,70=1:1/16:9,90=3:2,60=4:5 (PH G12)
    #      (roughly image area in percent - 4:3=100%,1:1/16:9=75%,3:2=89%,4:5=60%)
    # 48 - 3 for CR2/CR3, 4 or 7 for JPG, -1 for edited JPG (see forum16127)
    50 => { #github340
        Name => 'FocusBracketing',
        PrintConv => { 0 => 'Disable', 1 => 'Enable' },
    },
    51 => { #forum16036 (EOS R models)
        Name => 'Clarity',
        PrintConv => {
            OTHER => sub { shift },
            0x7fff => 'n/a',
        },
    },
    52 => { #github336
        Name  => 'HDR-PQ',
        PrintConv => { %offOn, -1 => 'n/a' },
    },
);

# focal length information (MakerNotes tag 0x02)
%Image::ExifTool::Canon::FocalLength = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => { #9
        Name => 'FocalType',
        RawConv => '$val ? $val : undef', # don't use if value is zero
        PrintConv => {
            1 => 'Fixed',
            2 => 'Zoom',
        },
    },
    1 => {
        Name => 'FocalLength',
        # the EXIF FocalLength is more reliable, so set this priority to zero
        Priority => 0,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        RawConvInv => q{
            my $focalUnits = $$self{FocalUnits};
            unless ($focalUnits) {
                $focalUnits = 1;
                # (this happens when writing FocalLength to CRW images)
                $self->Warn("FocalUnits not available for FocalLength conversion (1 assumed)");
            }
            return $val * $focalUnits;
        },
        ValueConv => '$val / ($$self{FocalUnits} || 1)',
        ValueConvInv => '$val',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    2 => [ #4
        {
            Name => 'FocalPlaneXSize',
            Notes => q{
                these focal plane sizes are only valid for some models, and are affected by
                digital zoom if applied
            },
            # this conversion is valid only for PowerShot models and these EOS models:
            # D30, D60, 1D, 1DS, 5D, 10D, 20D, 30D, 300D, 350D, and 400D
            Condition => q{
                $$self{Model} !~ /EOS/ or
                $$self{Model} =~ /\b(1DS?|5D|D30|D60|10D|20D|30D|K236)$/ or
                $$self{Model} =~ /\b((300D|350D|400D) DIGITAL|REBEL( XTi?)?|Kiss Digital( [NX])?)$/
            },
            # focal plane image dimensions in 1/1000 inch -- convert to mm
            RawConv => '$val < 40 ? undef : $val',  # must be reasonable
            ValueConv => '$val * 25.4 / 1000',
            ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
            PrintConv => 'sprintf("%.2f mm",$val)',
            PrintConvInv => '$val=~s/\s*mm$//;$val',
        },{
            Name => 'FocalPlaneXUnknown',
            Unknown => 1,
        },
    ],
    3 => [ #4
        {
            Name => 'FocalPlaneYSize',
            Condition => q{
                $$self{Model} !~ /EOS/ or
                $$self{Model} =~ /\b(1DS?|5D|D30|D60|10D|20D|30D|K236)$/ or
                $$self{Model} =~ /\b((300D|350D|400D) DIGITAL|REBEL( XTi?)?|Kiss Digital( [NX])?)$/
            },
            RawConv => '$val < 40 ? undef : $val',  # must be reasonable
            ValueConv => '$val * 25.4 / 1000',
            ValueConvInv => 'int($val * 1000 / 25.4 + 0.5)',
            PrintConv => 'sprintf("%.2f mm",$val)',
            PrintConvInv => '$val=~s/\s*mm$//;$val',
        },{
            Name => 'FocalPlaneYUnknown',
            Unknown => 1,
        },
    ],
);

# Canon shot information (MakerNotes tag 0x04)
# BinaryData (keys are indices into the int16s array)
%Image::ExifTool::Canon::ShotInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    DATAMEMBER => [ 19 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'AutoISO',
        Notes => 'actual ISO used = BaseISO * AutoISO / 100',
        ValueConv => 'exp($val/32*log(2))*100',
        ValueConvInv => '32*log($val/100)/log(2)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    2 => {
        Name => 'BaseISO',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        ValueConv => 'exp($val/32*log(2))*100/32',
        ValueConvInv => '32*log($val*32/100)/log(2)',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    3 => { #9/PH
        Name => 'MeasuredEV',
        Notes => q{
            this is the Canon name for what could better be called MeasuredLV, and
            should be close to the calculated LightValue for a proper exposure with most
            models
        },
        # empirical offset of +5 seems to be good for EOS models, but maybe
        # the offset should be less by up to 1 EV for some PowerShot models
        ValueConv => '$val / 32 + 5',
        ValueConvInv => '($val - 5) * 32',
        PrintConv => 'sprintf("%.2f",$val)',
        PrintConvInv => '$val',
    },
    4 => { #2, 9
        Name => 'TargetAperture',
        RawConv => '$val > 0 ? $val : undef',
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    5 => { #2
        Name => 'TargetExposureTime',
        # ignore obviously bad values (also, -32768 may be used for n/a)
        # (note that a few models always write 0: DC211, and video models)
        RawConv => '($val > -1000 and ($val or $$self{Model}=~/(EOS|PowerShot|IXUS|IXY)/))? $val : undef',
        ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    6 => {
        Name => 'ExposureCompensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    7 => {
        Name => 'WhiteBalance',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    8 => { #PH
        Name => 'SlowShutter',
        PrintConv => {
            -1 => 'n/a',
            0 => 'Off',
            1 => 'Night Scene',
            2 => 'On',
            3 => 'None',
        },
    },
    9 => {
        Name => 'SequenceNumber',
        Description => 'Shot Number In Continuous Burst',
        Notes => 'valid only for some models', #PH (eg. not the 5DmkIII)
    },
    10 => { #PH/17
        Name => 'OpticalZoomCode',
        Groups => { 2 => 'Camera' },
        Notes => 'for many PowerShot models, a this is 0-6 for wide-tele zoom',
        # (for many models, 0-6 represent 0-100% zoom, but it is always 8 for
        #  EOS models, and I have seen values of 16,20,28,32 and 39 too...)
        # - set to 8 for "n/a" by Canon software (ref 22)
        PrintConv => '$val == 8 ? "n/a" : $val',
        PrintConvInv => '$val =~ /[a-z]/i ? 8 : $val',
    },
    # 11 - (8 for all EOS samples, [0,8] for other models - PH)
    12 => { #37
        Name => 'CameraTemperature',
        Condition => '$$self{Model} =~ /EOS/ and $$self{Model} !~ /EOS-1DS?$/',
        Groups => { 2 => 'Camera' },
        Notes => 'newer EOS models only',
        # usually zero if not valid for an EOS model (exceptions: 1D, 1DS)
        RawConv => '$val ? $val : undef',
        ValueConv => '$val - 128',
        ValueConvInv => '$val + 128',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    13 => { #PH
        Name => 'FlashGuideNumber',
        RawConv => '$val==-1 ? undef : $val',
        ValueConv => '$val / 32',
        ValueConvInv => '$val * 32',
    },
    # AF points for Ixus and IxusV cameras - 02/17/04 M. Rommel (also D30/D60 - PH)
    14 => { #2
        Name => 'AFPointsInFocus',
        Notes => 'used by D30, D60 and some PowerShot/Ixus models',
        Groups => { 2 => 'Camera' },
        Flags => 'PrintHex',
        RawConv => '$val==0 ? undef : $val',
        PrintConvColumns => 2,
        PrintConv => {
            0x3000 => 'None (MF)',
            0x3001 => 'Right',
            0x3002 => 'Center',
            0x3003 => 'Center+Right',
            0x3004 => 'Left',
            0x3005 => 'Left+Right',
            0x3006 => 'Left+Center',
            0x3007 => 'All',
        },
    },
    15 => {
        Name => 'FlashExposureComp',
        Description => 'Flash Exposure Compensation',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    16 => {
        Name => 'AutoExposureBracketing',
        PrintConv => {
            -1 => 'On',
            0 => 'Off',
            1 => 'On (shot 1)',
            2 => 'On (shot 2)',
            3 => 'On (shot 3)',
        },
    },
    17 => {
        Name => 'AEBBracketValue',
        ValueConv => 'Image::ExifTool::Canon::CanonEv($val)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv($val)',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    18 => { #22
        Name => 'ControlMode',
        PrintConv => {
            0 => 'n/a',
            1 => 'Camera Local Control',
            # 2 - have seen this for EOS M studio picture
            3 => 'Computer Remote Control',
        },
    },
    19 => {
        Name => 'FocusDistanceUpper',
        DataMember => 'FocusDistanceUpper',
        Format => 'int16u',
        Notes => 'FocusDistance tags are only extracted if FocusDistanceUpper is non-zero',
        RawConv => '($$self{FocusDistanceUpper} = $val) || undef',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '$val > 655.345 ? "inf" : "$val m"',
        PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
    },
    20 => {
        Name => 'FocusDistanceLower', # (seems to be the upper distance for the 400D)
        Condition => '$$self{FocusDistanceUpper}',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '$val > 655.345 ? "inf" : "$val m"',
        PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
    },
    21 => {
        Name => 'FNumber',
        Priority => 0,
        RawConv => '$val ? $val : undef',
        # approximate big translation table by simple calculation - PH
        ValueConv => 'exp(Image::ExifTool::Canon::CanonEv($val)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(log($val)*2/log(2))',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    22 => [
        {
            Name => 'ExposureTime',
            # encoding is different for 20D and 350D (darn!)
            # (but note that encoding is the same for TargetExposureTime - PH)
            Condition => '$$self{Model} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Priority => 0,
            # many models write 0 here in JPEG images (even though 0 is the
            # value for an exposure time of 1 sec), but apparently a value of 0
            # is valid in a CRW image (=1s, D60 sample)
            RawConv => '($val or $$self{FILE_TYPE} eq "CRW") ? $val : undef',
            # approximate big translation table by simple calculation - PH
            ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))*1000/32',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val*32/1000)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
        {
            Name => 'ExposureTime',
            Priority => 0,
            # many models write 0 here in JPEG images (even though 0 is the
            # value for an exposure time of 1 sec), but apparently a value of 0
            # is valid in a CRW image (=1s, D60 sample)
            RawConv => '($val or $$self{FILE_TYPE} eq "CRW") ? $val : undef',
            # approximate big translation table by simple calculation - PH
            ValueConv => 'exp(-Image::ExifTool::Canon::CanonEv($val)*log(2))',
            ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(-log($val)/log(2))',
            PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
            PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
        },
    ],
    23 => { #37
        Name => 'MeasuredEV2',
        Description => 'Measured EV 2',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    24 => {
        Name => 'BulbDuration',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    # 25 - (usually 0, but 1 for 2s timer?, 19 for small AVI, 14 for large
    #       AVI, and -6 and -10 for shots 1 and 2 with stitch assist - PH)
    26 => { #15
        Name => 'CameraType',
        Groups => { 2 => 'Camera' },
        PrintConv => {
            0 => 'n/a',
            248 => 'EOS High-end',
            250 => 'Compact',
            252 => 'EOS Mid-range',
            255 => 'DV Camera', #PH
        },
    },
    27 => {
        Name => 'AutoRotate',
        RawConv => '$val >= 0 ? $val : undef',
        PrintConv => {
           -1 => 'n/a', # (set to -1 when rotated by Canon software)
            0 => 'None',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 180',
            3 => 'Rotate 270 CW',
        },
    },
    28 => { #15
        Name => 'NDFilter',
        PrintConv => { -1 => 'n/a', 0 => 'Off', 1 => 'On' },
    },
    29 => {
        Name => 'SelfTimer2',
        RawConv => '$val >= 0 ? $val : undef',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    33 => { #PH (A570IS)
        Name => 'FlashOutput',
        RawConv => '($$self{Model}=~/(PowerShot|IXUS|IXY)/ or $val) ? $val : undef',
        Notes => q{
            used only for PowerShot models, this has a maximum value of 500 for models
            like the A570IS
        },
    },
);

# Canon panorama information (MakerNotes tag 0x05)
%Image::ExifTool::Canon::Panorama = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # 0 - values: always 1
    # 1 - values: 0,256,512(3 sequential L->R images); 0,-256(2 R->L images)
    2 => 'PanoramaFrameNumber', #(some models this is always 0)
    # 3 - values: 160(SX10IS,A570IS); 871(S30)
    # 4 - values: always 0
    5 => {
        Name => 'PanoramaDirection',
        PrintConv => {
            0 => 'Left to Right',
            1 => 'Right to Left',
            2 => 'Bottom to Top',
            3 => 'Top to Bottom',
            4 => '2x2 Matrix (Clockwise)',
        },
     },
);

# D30 color information (MakerNotes tag 0x0a)
%Image::ExifTool::Canon::UnknownD30 = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

#..............................................................................
# common CameraInfo tag definitions
my %ciFNumber = (
    Name => 'FNumber',
    Format => 'int8u',
    Groups => { 2 => 'Image' },
    RawConv => '$val ? $val : undef',
    ValueConv => 'exp(($val-8)/16*log(2))',
    ValueConvInv => 'log($val)*16/log(2)+8',
    PrintConv => 'sprintf("%.2g",$val)',
    PrintConvInv => '$val',
);
my %ciExposureTime = (
    Name => 'ExposureTime',
    Format => 'int8u',
    Groups => { 2 => 'Image' },
    RawConv => '$val ? $val : undef',
    ValueConv => 'exp(4*log(2)*(1-Image::ExifTool::Canon::CanonEv($val-24)))',
    ValueConvInv => 'Image::ExifTool::Canon::CanonEvInv(1-log($val)/(4*log(2)))+24',
    PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
);
my %ciISO = (
    Name => 'ISO',
    Format => 'int8u',
    Groups => { 2 => 'Image' },
    ValueConv => '100*exp(($val/8-9)*log(2))',
    ValueConvInv => '(log($val/100)/log(2)+9)*8',
    PrintConv => 'sprintf("%.0f",$val)',
    PrintConvInv => '$val',
);
my %ciCameraTemperature = (
    Name => 'CameraTemperature',
    Format => 'int8u',
    ValueConv => '$val - 128',
    ValueConvInv => '$val + 128',
    PrintConv => '"$val C"',
    PrintConvInv => '$val=~s/ ?C//; $val',
);
my %ciMacroMagnification = (
    Name => 'MacroMagnification',
    Notes => 'currently decoded only for the MP-E 65mm f/2.8 1-5x Macro Photo',
    Condition => '$$self{LensType} and $$self{LensType} == 124',
    # 75=1x, 44=5x, log relationship
    ValueConv => 'exp((75-$val) * log(2) * 3 / 40)',
    ValueConvInv => '$val > 0 ? 75 - log($val) / log(2) * 40 / 3 : undef',
    PrintConv => 'sprintf("%.1fx",$val)',
    PrintConvInv => '$val=~s/\s*x//; $val',
);
my %ciFocalLength = (
    Name => 'FocalLength',
    Format => 'int16uRev', # (just to make things confusing, the focal lengths are big-endian)
    # ignore if zero
    RawConv => '$val ? $val : undef',
    PrintConv => '"$val mm"',
    PrintConvInv => '$val=~s/\s*mm//;$val',
);
my %ciMinFocal = (
    Name => 'MinFocalLength',
    Format => 'int16uRev', # byte order is big-endian
    PrintConv => '"$val mm"',
    PrintConvInv => '$val=~s/\s*mm//;$val',
);
my %ciMaxFocal = (
    Name => 'MaxFocalLength',
    Format => 'int16uRev', # byte order is big-endian
    PrintConv => '"$val mm"',
    PrintConvInv => '$val=~s/\s*mm//;$val',
);

#..............................................................................
# Camera information for 1D and 1DS (MakerNotes tag 0x0d)
# (ref 15 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,  # these tags are not reliable since they change with firmware version
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Information in the "CameraInfo" records is tricky to decode because the
        encodings are very different than in other Canon records (even sometimes
        switching endianness between values within a single camera), plus there is
        considerable variation in format from model to model. The first table below
        lists CameraInfo tags for the 1D and 1DS.
    },
    0x04 => { %ciExposureTime }, #9
    0x0a => {
        Name => 'FocalLength',
        Format => 'int16u',
        # ignore if zero
        RawConv => '$val ? $val : undef',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x0d => { #9
        Name => 'LensType',
        Format => 'int16uRev', # value is little-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x0e => {
        Name => 'MinFocalLength',
        Format => 'int16u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x10 => {
        Name => 'MaxFocalLength',
        Format => 'int16u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    0x41 => {
        Name => 'SharpnessFrequency', # PatternSharpness?
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => '1D only',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    0x42 => {
        Name => 'Sharpness',
        Format => 'int8s',
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => '1D only',
    },
    0x44 => {
        Name => 'WhiteBalance',
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => '1D only',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x47 => {
        Name => 'SharpnessFrequency', # PatternSharpness?
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    0x48 => [
        {
            Name => 'ColorTemperature',
            Format => 'int16u',
            Condition => '$$self{Model} =~ /\b1D$/',
            Notes => '1D only',
        },
        {
            Name => 'Sharpness',
            Format => 'int8s',
            Condition => '$$self{Model} =~ /\b1DS$/',
            Notes => '1DS only',
        },
    ],
    0x4a => {
        Name => 'WhiteBalance',
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x4b => {
        Name => 'PictureStyle',
        Condition => '$$self{Model} =~ /\b1D$/',
        Notes => "1D only, called 'Color Matrix' in owner's manual",
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x4e => {
        Name => 'ColorTemperature',
        Format => 'int16u',
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
    },
    0x51 => {
        Name => 'PictureStyle',
        Condition => '$$self{Model} =~ /\b1DS$/',
        Notes => '1DS only',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
);

# Camera information for 1DmkII and 1DSmkII (MakerNotes tag 0x0d)
# (ref 15 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1DmkII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkII and 1DSmkII.',
    0x04 => { %ciExposureTime }, #9
    0x09 => { %ciFocalLength }, #9
    0x0c => { #9
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x11 => { %ciMinFocal }, #9
    0x13 => { %ciMaxFocal }, #9
    0x2d => { #9
        Name => 'FocalType',
        PrintConv => {
           0 => 'Fixed',
           2 => 'Zoom',
        },
    },
    0x36 => {
        Name => 'WhiteBalance',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x37 => {
        Name => 'ColorTemperature',
        Format => 'int16uRev',
    },
    0x39 => {
        Name => 'CanonImageSize',
        Format => 'int16u',
        PrintConvColumns => 2,
        PrintConv => \%canonImageSize,
    },
    0x66 => {
        Name => 'JPEGQuality',
        Notes => 'a number from 1 to 10',
    },
    0x6c => { #12
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x6e => {
        Name => 'Saturation',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x6f => {
        Name => 'ColorTone',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x72 => {
        Name => 'Sharpness',
        Format => 'int8s',
    },
    0x73 => {
        Name => 'Contrast',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x75 => {
        Name => 'ISO',
        Format => 'string[5]',
    },
);

# Camera information for the 1DmkIIN (MakerNotes tag 0x0d)
# (ref 9 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo1DmkIIN = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkIIN.',
    0x04 => { %ciExposureTime },
    0x09 => { %ciFocalLength },
    0x0c => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x11 => { %ciMinFocal },
    0x13 => { %ciMaxFocal },
    0x36 => { #15
        Name => 'WhiteBalance',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x37 => { #15
        Name => 'ColorTemperature',
        Format => 'int16uRev',
    },
    0x73 => { #15
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x74 => { #15
        Name => 'Sharpness',
        Format => 'int8s',
    },
    0x75 => { #15
        Name => 'Contrast',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x76 => { #15
        Name => 'Saturation',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x77 => { #15
        Name => 'ColorTone',
        Format => 'int8s',
        %Image::ExifTool::Exif::printParameter,
    },
    0x79 => { #15
        Name => 'ISO',
        Format => 'string[5]',
    },
);

# Canon camera information for 1DmkIII and 1DSmkIII (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo1DmkIII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x2aa ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the 1DmkIII and 1DSmkIII.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime }, #9
    0x06 => { %ciISO },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #(NC)
    0x1d => { %ciFocalLength },
    0x30 => { # <-- (follows pattern /\xbb\xbb(.{64})?\x01\x01\0\0.{4}/s for all models - Dave Coffin)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #21/24
        Name => 'FocusDistanceUpper',
        # (it looks like the focus distances are also odd-byte big-endian)
        %focusDistanceByteSwap,
    },
    0x45 => { #21/24
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x5e => { #15
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x62 => { #15
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x86 => {
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x111 => { #15
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x113 => { %ciMinFocal },
    0x115 => { %ciMaxFocal },
    0x136 => { #15
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x172 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x176 => {
        Name => 'ShutterCount',
        Notes => 'may be valid only for some 1DmkIII copies, even running the same firmware',
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x17e => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2aa => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
    0x45a => { #29
        Name => 'TimeStamp1',
        Condition => '$$self{Model} =~ /\b1D Mark III$/',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        # observed in 1DmkIII firmware 5.3.1 (pre-production), 1.0.3, 1.0.8
        Notes => 'only valid for some versions of the 1DmkIII firmware',
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x45e => {
        Name => 'TimeStamp',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        # observed in 1DmkIII firmware 1.1.0, 1.1.3 and
        # 1DSmkIII firmware 1.0.0, 1.0.4, 2.1.2, 2.7.1
        Notes => 'valid for the 1DSmkIII and some versions of the 1DmkIII firmware',
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
);

# Canon camera information for 1DmkIV (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo1DmkIV = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x00, 0x56, 0x153 ],
    IS_SUBDIR => [ 0x368 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for the EOS 1D Mark IV.  Indices shown are for firmware
        versions 1.0.x, but they may be different for other firmware versions.
    },
    0x00 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # look ahead to check location of FirmwareVersion string
        Format => 'undef[0x1fd]',
        RawConv => q{
            my $t = substr($val, 0x1e8, 6); # 1 = firmware 4.2.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 1, return undef;
            $t = substr($val, 0x1ed, 6);    # 2 = firmware 1.0.4
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 2, return undef;
            $self->Warn('Unrecognized CameraInfo1DmkIV firmware version');
            $$self{CanonFirm} = 0;
            return undef;   # not a real tag
        },
    },
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x08 => {
        Name => 'MeasuredEV2',
        Description => 'Measured EV 2',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x09 => {
        Name => 'MeasuredEV3',
        Description => 'Measured EV 3',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x15 => {
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x35 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x56 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
        Hook => '$varSize += ($$self{CanonFirm} ? -1 : 0x10000) if $$self{CanonFirm} < 2',
    },
    0x78 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x7c => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x14f => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x151 => { %ciMinFocal },
    0x153 => { %ciMaxFocal,
        Hook => '$varSize -= 4 if $$self{CanonFirm} < 2',
    },
    0x1ed => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x22c => { #(NC)
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x238 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x368 => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
);

# Camera information for 1D X (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo1DX = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x00, 0x1b, 0x8e, 0x1ab ],
    IS_SUBDIR => [ 0x3f4 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for the EOS 1D X.  Indices shown are for firmware version
        1.0.2, but they may be different for other firmware versions.
    },
    0x00 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # look ahead to check location of FirmwareVersion string
        Format => 'undef[0x28b]',
        RawConv => q{
            my $t = substr($val, 0x271, 6); # 1 = firmware 5.7.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 1, return undef;
            $t = substr($val, 0x279, 6);    # 2 = firmware 6.5.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 2, return undef;
            $t = substr($val, 0x280, 6);    # 3 = firmware 0.0.8/1.0.2/1.1.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 3, return undef;
            $t = substr($val, 0x285, 6);    # 4 = firmware 2.1.0
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 4, return undef;
            $self->Warn('Unrecognized CameraInfo1DX firmware version');
            $$self{CanonFirm} = 0;
            return undef;   # not a real tag
        },
    },
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature,
        Hook => '$varSize -= 3 if $$self{CanonFirm} < 3',
    },
    0x23 => { %ciFocalLength },
    0x7d => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x8c => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x8e => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
        Hook => '$varSize -= 4 if $$self{CanonFirm} < 3; $varSize += 5 if $$self{CanonFirm} == 4',
    },
    0xbc => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0xc0 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xf4 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x1a7 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x1a9 => { %ciMinFocal },
    0x1ab => { %ciMaxFocal,
        # add another offset of -8 for firmware 5.7.1, and a large offset
        # to effectively abort processing for unknown firmware
        Hook => '$varSize += ($$self{CanonFirm} ? -8 : 0x10000) if $$self{CanonFirm} < 2',
    },
    0x280 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x2d0 => { # (doesn't seem to work for firmware 2.0.3 - PH)
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x2dc => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x3f4 => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

# Camera information for 5D (MakerNotes tag 0x0d)
# (ref 12 unless otherwise noted)
%Image::ExifTool::Canon::CameraInfo5D = (
    %binaryDataAttrs,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 5D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #9
    0x06 => { %ciISO }, #PH
    0x0c => { #9
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        RawConv => '$val ? $val : undef', # don't use if value is zero
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x17 => { %ciCameraTemperature }, #PH
    0x1b => { %ciMacroMagnification }, #PH
    0x27 => { #PH
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x28 => { %ciFocalLength }, #15
    0x38 => {
        Name => 'AFPointsInFocus5D',
        Format => 'int16uRev',
        PrintConvColumns => 2,
        PrintConv => { 0 => '(none)',
            BITMASK => {
                0 => 'Center',
                1 => 'Top',
                2 => 'Bottom',
                3 => 'Upper-left',
                4 => 'Upper-right',
                5 => 'Lower-left',
                6 => 'Lower-right',
                7 => 'Left',
                8 => 'Right',
                9 => 'AI Servo1',
               10 => 'AI Servo2',
               11 => 'AI Servo3',
               12 => 'AI Servo4',
               13 => 'AI Servo5',
               14 => 'AI Servo6',
           },
        },
    },
    0x54 => { #15
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x58 => { #15
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x6c => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x93 => { %ciMinFocal }, #15
    0x95 => { %ciMaxFocal }, #15
    0x97 => { #15
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xa4 => { #PH
        Name => 'FirmwareRevision',
        Format => 'string[8]',
    },
    0xac => { #PH
        Name => 'ShortOwnerName',
        Format => 'string[16]',
    },
    0xcc => { #PH (NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
    },
    0xd0 => {
        Name => 'FileIndex',
        Format => 'int16u',
        Groups => { 2 => 'Image' },
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0xe8 => 'ContrastStandard',
    0xe9 => 'ContrastPortrait',
    0xea => 'ContrastLandscape',
    0xeb => 'ContrastNeutral',
    0xec => 'ContrastFaithful',
    0xed => 'ContrastMonochrome',
    0xee => 'ContrastUserDef1',
    0xef => 'ContrastUserDef2',
    0xf0 => 'ContrastUserDef3',
    # sharpness values are 0-7
    0xf1 => 'SharpnessStandard',
    0xf2 => 'SharpnessPortrait',
    0xf3 => 'SharpnessLandscape',
    0xf4 => 'SharpnessNeutral',
    0xf5 => 'SharpnessFaithful',
    0xf6 => 'SharpnessMonochrome',
    0xf7 => 'SharpnessUserDef1',
    0xf8 => 'SharpnessUserDef2',
    0xf9 => 'SharpnessUserDef3',
    0xfa => 'SaturationStandard',
    0xfb => 'SaturationPortrait',
    0xfc => 'SaturationLandscape',
    0xfd => 'SaturationNeutral',
    0xfe => 'SaturationFaithful',
    0xff => {
        Name => 'FilterEffectMonochrome',
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x100 => 'SaturationUserDef1',
    0x101 => 'SaturationUserDef2',
    0x102 => 'SaturationUserDef3',
    0x103 => 'ColorToneStandard',
    0x104 => 'ColorTonePortrait',
    0x105 => 'ColorToneLandscape',
    0x106 => 'ColorToneNeutral',
    0x107 => 'ColorToneFaithful',
    0x108 => {
        Name => 'ToningEffectMonochrome',
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x109 => 'ColorToneUserDef1',
    0x10a => 'ColorToneUserDef2',
    0x10b => 'ColorToneUserDef3',
    0x10c => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        PrintHex => 1, # (only needed for one tag)
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0x10e => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0x110 => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0x11c => {
        Name => 'TimeStamp',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        RawConv => '$val ? $val : undef',
        ValueConv => 'ConvertUnixTime($val)',
        ValueConvInv => 'GetUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
);

# Camera information for 5D Mark II (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo5DmkII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x00, 0xea ],
    IS_SUBDIR => [ 0x2f7 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for the EOS 5D Mark II.  Indices shown are for firmware
        version 1.0.6, but they may be different for other firmware versions.
    },
    0x00 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # look ahead to check location of FirmwareVersion string
        Format => 'undef[0x184]',
        RawConv => q{
            my $t = substr($val, 0x15a, 6); # 1 = firmware 3.4.6/3.6.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 1, return undef;
            $t = substr($val, 0x17e, 6);    # 2 = firmware 4.1.1/1.0.6
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 2, return undef;
            $self->Warn('Unrecognized CameraInfo5DmkII firmware version');
            $$self{CanonFirm} = 0;
            return undef;   # not a real tag
        },
    },
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x1b => { %ciMacroMagnification }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, #36
    # 0x1b, 0x1c, 0x1d - same as FileInfo 0x10 - PH
    0x1e => { %ciFocalLength },
    0x31 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x50 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x52 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x73 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xa7 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xbd => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xbf => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xe6 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xe8 => { %ciMinFocal },
    0xea => { %ciMaxFocal,
        # offset changes after this for different firmware versions
        Hook => '$varSize += ($$self{CanonFirm} ? -36 : 0x10000) if $$self{CanonFirm} < 2',
    },
    0x17e => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0, # not writable for logic reasons
        # some firmwares have a null instead of a space after the version number
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1bb => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1c7 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2f7 => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
);

# Camera information for 5D Mark III (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo5DmkIII = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x00, 0x1b, 0x23, 0x8e, 0x157 ],
    IS_SUBDIR => [ 0x3b0 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for the EOS 5D Mark III.  Indices shown are for firmware
        versions 1.0.x, but they may be different for other firmware versions.
    },
    0x00 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # look ahead to check location of FirmwareVersion string
        Format => 'undef[0x24d]',
        RawConv => q{
            my $t = substr($val, 0x22c, 6); # 1 = firmware 4.5.4/4.5.6
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 1, return undef;
            $t = substr($val, 0x22d, 6);    # 2 = firmware 5.2.2/5.3.1/5.4.2
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 2, return undef;
            $t = substr($val, 0x23c, 6);    # 3 = firmware 1.0.3/1.0.7
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 3, return undef;
            $t = substr($val, 0x242, 6);    # 4 = firmware 1.2.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 4, return undef;
            $t = substr($val, 0x247, 6);    # 5 = firmware 1.3.5
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 5, return undef;
            $self->Warn('Unrecognized CameraInfo5DmkIII firmware version');
            $$self{CanonFirm} = 0;
            return undef;   # not a real tag
        },
    },
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature,
        # decrement $varSize for missing byte after this tag with firmware 5.x and earlier
        # (and add large offset to effectively abort processing if unknown firmware)
        Hook => '$varSize += ($$self{CanonFirm} ? -1 : 0x10000) if $$self{CanonFirm} < 3',
    },
    0x23 => { %ciFocalLength,
        Hook => q{
            $varSize -= 3 if $$self{CanonFirm} == 1;
            $varSize -= 2 if $$self{CanonFirm} == 2;
            $varSize += 6 if $$self{CanonFirm} >= 4;
        },
    },
    0x7d => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x8c => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x8e => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
        Hook => q{
            $varSize -= 4 if $$self{CanonFirm} < 3;
            $varSize += 5 if $$self{CanonFirm} > 4;
        },
    },
    0xbc => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0xc0 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xf4 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x153 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x155 => { %ciMinFocal },
    0x157 => { %ciMaxFocal,
        Hook => '$varSize -= 8 if $$self{CanonFirm} < 3',
    },
    0x164 => {
        Name => 'LensSerialNumber',
        Format => 'undef[5]',
        Priority => 0,
        ValueConv => 'unpack("H*",$val)',
        ValueConvInv => 'length($val) < 10 and $val = 0 x (10-length($val)) . $val; pack("H*",$val)',
    },
    0x23c => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    # the 5DmkIII has "User setting1" and "User setting2" file naming options:
    # - with "User setting1" 4 characters are selectable
    # - with "User setting2", 3 characters are selectable, and the 4th character
    # - in the file name corresponds to the image size:
    #   L=large, M=medium, S=small1, T=small2, U=small3, _=movie
    # - as shipped, the first 4 characters of the file name are unique to the camera
    0x28c => { # used for file names like IMG_xxxx.JPG
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x290 => { # used for file names like 2F0Axxxx.JPG and 6T3Cxxxx.JPG
        Name => 'FileIndex2',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x298 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x29c => { #(NC)
        Name => 'DirectoryIndex2',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x3b0 => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

# Camera information for 6D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo6D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x3c6 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 6D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature },
    0x23 => { %ciFocalLength },
    0x83 => { # (5DmkIII + 6)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x92 => { # (5DmkIII + 6)
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x94 => { # (5DmkIII + 6)
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0xc2 => { # (5DmkIII + 6)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0xc6 => { # (5DmkIII + 6)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xfa => { # (5DmkIII + 6)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x161 => { # (5DmkIII + 0x0e)
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x163 => { %ciMinFocal }, # (5DmkIII + 0x0e)
    0x165 => { %ciMaxFocal }, # (5DmkIII + 0x0e)
    0x256 => { # (5DmkIII + 0x1a)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x2aa => { # (5DmkIII + 0x16 or 0x1e)
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x2b6 => { #(NC) (5DmkIII + 0x16 or 0x1e)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x3c6 => { # (5DmkIII + 0x16)
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

# Camera information for 7D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo7D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x00, 0x1e ],
    IS_SUBDIR => [ 0x327 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for the EOS 7D.  Indices shown are for firmware versions
        1.0.x, but they may be different for other firmware versions.
    },
    0x00 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # look ahead to check location of FirmwareVersion string
        Format => 'undef[0x1b2]',
        RawConv => q{
            my $t = substr($val, 0x1a8, 6); # 1 = firmware 3.7.5
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 1, return undef;
            $t = substr($val, 0x1ac, 6);    # 2 = firmware 1.0.7/1.0.8/1.1.0/1.2.1/1.2.2
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 2, return undef;
            $self->Warn('Unrecognized CameraInfo7D firmware version');
            $$self{CanonFirm} = 0;
            return undef;   # not a real tag
        },
    },
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x08 => { #37
        Name => 'MeasuredEV2',
        Description => 'Measured EV 2',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x09 => { #37
        Name => 'MeasuredEV',
        Description => 'Measured EV',
        RawConv => '$val ? $val : undef',
        ValueConv => '$val / 8 - 6',
        ValueConvInv => 'int(($val + 6) * 8 + 0.5)',
    },
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength,
        Hook => '$varSize += ($$self{CanonFirm} ? -4 : 0x10000) if $$self{CanonFirm} < 2',
    },
    0x35 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x56 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x77 => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x7b => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xaf => {
        Name => 'CameraPictureStyle',
        PrintHex => 1,
        PrintConv => {
            0x81 => 'Standard',
            0x82 => 'Portrait',
            0x83 => 'Landscape',
            0x84 => 'Neutral',
            0x85 => 'Faithful',
            0x86 => 'Monochrome',
            0x21 => 'User Defined 1',
            0x22 => 'User Defined 2',
            0x23 => 'User Defined 3',
        },
    },
    0xc9 => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0x112 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x114 => { %ciMinFocal },
    0x116 => { %ciMaxFocal },
    0x1ac => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0, # not writable for logic reasons
        # some firmwares have a null instead of a space after the version number
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1eb => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1f7 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x327 => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
);

# Canon camera information for 40D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo40D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x25b ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 40D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #PH
    0x06 => { %ciISO }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #PH
    0x1d => { %ciFocalLength }, #PH
    0x30 => { #20
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #21/24
        Name => 'FocusDistanceUpper',
        # this is very odd (little-endian number on odd boundary),
        # but it does seem to work better with my sample images - PH
        %focusDistanceByteSwap,
    },
    0x45 => { #21/24
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => { #15
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x73 => { #15
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xd6 => { #15
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xd8 => { %ciMinFocal }, #15
    0xda => { %ciMaxFocal }, #15
    0xff => { #15
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x133 => { #27
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        Notes => 'combined with DirectoryIndex to give the Composite FileNumber tag',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x13f => { #27
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1', # yes, minus (opposite to FileIndex)
        ValueConvInv => '$val + 1',
    },
    0x25b => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
    0x92b => { #33
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Canon camera information for 50D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo50D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    DATAMEMBER => [ 0x00, 0xee ],
    IS_SUBDIR => [ 0x2d7 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for the EOS 50D.  Indices shown are for firmware versions
        1.0.x, but they may be different for other firmware versions.
    },
    0x00 => {
        Name => 'FirmwareVersionLookAhead',
        Hidden => 1,
        # look ahead to check location of FirmwareVersion string
        Format => 'undef[0x164]',
        RawConv => q{
            my $t = substr($val, 0x15a, 6); # 1 = firmware 2.6.1
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 1, return undef;
            $t = substr($val, 0x15e, 6);    # 2 = firmware 2.9.1/3.1.1/1.0.2/1.0.3
            $t =~ /^\d+\.\d+\.\d+/ and $$self{CanonFirm} = 2, return undef;
            $self->Warn('Unrecognized CameraInfo50D firmware version');
            $$self{CanonFirm} = 0;
            return undef;   # not a real tag
        },
    },
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, #36
    0x1e => { %ciFocalLength },
    0x31 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x50 => { #33
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x52 => { #33
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => {
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x73 => { #33
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xa7 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xbd => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xbf => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xea => { #33
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xec => { %ciMinFocal },
    0xee => { %ciMaxFocal,
        Hook => '$varSize += ($$self{CanonFirm} ? -4 : 0x10000) if $$self{CanonFirm} < 2',
    },
    0x15e => { #33
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x19b => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1a7 => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2d7 => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
);

# Canon camera information for 60D/1200D (MakerNotes tag 0x0d) (ref PH)
# NOTE: Can probably borrow more 50D tags here, possibly with an offset
%Image::ExifTool::Canon::CameraInfo60D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x2f9, 0x321 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 60D and 1200D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x36 => {
        Name => 'CameraOrientation',
        Condition => '$$self{Model} =~ /EOS 60D$/', #(NC)
        Notes => '60D only',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x3a => { #IB
        Name => 'CameraOrientation',
        Condition => '$$self{Model} =~ /\b(1200D|REBEL T5|Kiss X70)\b/',
        Notes => '1200D only',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x55 => {
        Name => 'FocusDistanceUpper',
        Condition => '$$self{Model} =~ /EOS 60D$/',
        Notes => '60D only',
        %focusDistanceByteSwap,
    },
    0x57 => {
        Name => 'FocusDistanceLower',
        Condition => '$$self{Model} =~ /EOS 60D$/',
        Notes => '60D only',
        %focusDistanceByteSwap,
    },
    0x7d => {
        Name => 'ColorTemperature',
        Condition => '$$self{Model} =~ /EOS 60D$/',
        Notes => '60D only',
        Format => 'int16u',
    },
    0xe8 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xea => { %ciMinFocal },
    0xec => { %ciMaxFocal },
    0x199 => {  # (at this location for 60D firmware 2.8.1/1.0.5, and 1200D 3.3.1/1.0.0)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x1d9 => {
        Name => 'FileIndex',
        Condition => '$$self{Model} =~ /EOS 60D$/',
        Notes => '60D only',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1e5 => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{Model} =~ /EOS 60D$/',
        Notes => '60D only',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2f9 => {
        Name => 'PictureStyleInfo',
        Condition => '$$self{Model} =~ /\b(1200D|REBEL T5|Kiss X70)\b/',
        Notes => '1200D',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
    0x321 => {
        Name => 'PictureStyleInfo',
        Condition => '$$self{Model} =~ /EOS 60D$/',
        Notes => '60D',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

%Image::ExifTool::Canon::CameraInfoR6 = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS R5 and R6.',
    # (see forum16111 for more notes on these tags)
    # 0x0a5d - some sort of sequence number starting from 1 (ref forum16111)
    0x0af1 => { #forum15210/15579
        Name => 'ShutterCount',
        Format => 'int32u',
        Notes => 'includes electronic + mechanical shutter',
    },
    # 0x0b5a - related to image stabilization (ref forum17239) (R5)
    # 0x0bb7 - counts down during focus stack (ref forum16111)
);

%Image::ExifTool::Canon::CameraInfoR6m2 = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS R6 Mark II.',
    0x0d29 => { #AgostonKapitany
        Name => 'ShutterCount',
        Format => 'int32u',
        Notes => 'includes electronic + mechanical shutter',
    },
);

%Image::ExifTool::Canon::CameraInfoR6m3 = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS R6 Mark II.',
    0x086d => { #forum17745 (+ private email)
        Name => 'ImageCount', # (resets to 0 when SD card is formatted)
        Format => 'int16u',
    },
);

# ref https://exiftool.org/forum/index.php?topic=15356.0
%Image::ExifTool::Canon::CameraInfoG5XII = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the PowerShot G5 X Mark II.',
    0x0293 => {
        Name => 'ShutterCount',
        Condition => '$$self{FileType} eq "JPEG"',
        Format => 'int32u',
        Notes => 'includes electronic + mechanical shutter',
        # - advances by 1 for each photo file, regardless of mechanical or electronic shutter
        # - does not advance for regular video files
        # - advances for time lapse video files
        # - creating a new directory or resetting the counter from the menu doesn't affect this shutter count
    },
    0x0a95 => {
        Name => 'ShutterCount',
        Condition => '$$self{FileType} eq "CR3"',
        Format => 'int32u',
        Notes => 'includes electronic + mechanical shutter',
    },
    0x0b21 => {
        Name => 'DirectoryIndex',
        Condition => '$$self{FileType} eq "JPEG"',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
    },
    0x0b2d => {
        Name => 'FileIndex',
        Condition => '$$self{FileType} eq "JPEG"',
        Format => 'int32u',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
);

# Canon camera information for 70D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo70D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x3cf ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 70D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature },
    0x23 => { %ciFocalLength },
    # 0x36 - focal length again?
    0x84 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x93 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x95 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0xc7 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x166 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x168 => { %ciMinFocal },
    0x16a => { %ciMaxFocal },
    0x25e => {  # (at this location for firmware 6.1.2, 1.0.4 and 1.1.1)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x2b3 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x2bf => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x3cf => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

# Canon camera information for 80D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo80D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 80D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature },
    0x23 => { %ciFocalLength },
    0x96 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0xa5 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0xa7 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x13a => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x189 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x18b => { %ciMinFocal },
    0x18d => { %ciMaxFocal },
    0x45a => {  # (at this location for firmware 1.0.1)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
    },
    0x4ae => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x4ba => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
);

# Canon camera information for 450D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo450D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x263 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 450D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #PH
    0x06 => { %ciISO }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #PH
    0x1d => { %ciFocalLength }, #PH
    0x30 => { #20
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #20
        Name => 'FocusDistanceUpper',
        # this is very odd (little-endian number on odd boundary),
        # but it does seem to work better with my sample images - PH
        %focusDistanceByteSwap,
    },
    0x45 => { #20
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => { #PH
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x73 => { #PH
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xde => { #33
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x107 => { #PH
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x10f => { #20
        Name => 'OwnerName',
        Format => 'string[32]',
    },
    0x133 => { #20
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
    },
    0x13f => { #20
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x263 => { #PH
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
    0x933 => { #33
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Canon camera information for 500D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo500D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x30b ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 500D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => {
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature },
    0x1e => { %ciFocalLength },
    0x31 => {
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x50 => {
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x52 => {
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x73 => { # (50D + 4)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x77 => { # (50D + 4)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xab => { # (50D + 4)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xbc => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xbe => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    0xf6 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xf8 => { %ciMinFocal },
    0xfa => { %ciMaxFocal },
    0x190 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1d3 => {
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1df => { #(NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x30b => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
);

# Canon camera information for 550D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo550D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x31c ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 550D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => { #(NC)
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x15 => { #(NC)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, # (500D + 0)
    0x1e => { %ciFocalLength }, # (500D + 0)
    0x35 => { # (500D + 4)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x54 => { # (500D + 4)
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x56 => { # (500D + 4)
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x78 => { # (500D + 5) (NC)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x7c => { # (500D + 5)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xb0 => { # (500D + 5)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xff => { # (500D + 9)
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x101 => { %ciMinFocal }, # (500D + 9)
    0x103 => { %ciMaxFocal }, # (500D + 9)
    0x1a4 => { # (500D + 0x11)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1e4 => { # (500D + 0x11)
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1f0 => { # (500D + 0x11) (NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x31c => { #48
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
);

# Canon camera information for 600D and 1100D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo600D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x2fb ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 600D and 1100D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x07 => { #(NC)
        Name => 'HighlightTonePriority',
        PrintConv => \%offOn,
    },
    0x15 => { #(NC)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x19 => { %ciCameraTemperature }, # (60D + 0)
    0x1e => { %ciFocalLength }, # (60D + 0)
    0x38 => { # (60D + 2)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x57 => { # (60D + 2, 550D + 3)
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x59 => { # (60D + 2, 550D + 3)
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x7b => { # (550D + 3)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x7f => { # (60D + 2, 550D + 3)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xb3 => { # (550D + 3)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0xea => { # (60D + 2, 550D + 3)
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xec => { %ciMinFocal }, # (60D + 2)
    0xee => { %ciMaxFocal }, # (60D + 2)
    0x19b => { # (60D + 2)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x1db => { # (60D + 2) (NC)
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x1e7 => { # (60D + 2) (NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x2fb => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

# Canon camera information for 650D/700D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo650D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x390 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 650D and 700D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature }, # (1DX/5DmkIII + 0)
    0x23 => { %ciFocalLength }, # (1DX/5DmkIII + 3)
    # 0x35 - seems to be the same as 0x54
    0x7d => { # (1DX/5DmkIII + 3)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x8c => { # (1DX + 3)
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x8e => { # (1DX + 3)
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0xbc => { # (1DX + 7)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0xc0 => { # (1DX + 7)
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xf4 => { # (1DX + 7)
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x127 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x129 => { %ciMinFocal },
    0x12b => { %ciMaxFocal },
    0x21b => { # (650D version 1.0.1)
        Name => 'FirmwareVersion',
        Condition => '$$self{Model} =~ /(650D|REBEL T4i|Kiss X6i)\b/',
        Notes => '650D',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x220 => { # (700D version 1.1.1/2.1.1)
        Name => 'FirmwareVersion',
        Condition => '$$self{Model} =~ /(700D|REBEL T5i|Kiss X7i)\b/',
        Notes => '700D',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x270 => { #(NC)
        Name => 'FileIndex',
        Condition => '$$self{Model} =~ /(650D|REBEL T4i|Kiss X6i)\b/',
        Notes => '650D',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x274 => { #(NC)
        Name => 'FileIndex',
        Condition => '$$self{Model} =~ /(700D|REBEL T5i|Kiss X7i)\b/',
        Notes => '700D',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x27c => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{Model} =~ /(650D|REBEL T4i|Kiss X6i)\b/',
        Notes => '650D',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x280 => { #(NC)
        Name => 'DirectoryIndex',
        Condition => '$$self{Model} =~ /(700D|REBEL T5i|Kiss X7i)\b/',
        Notes => '700D',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val - 1',
        ValueConvInv => '$val + 1',
    },
    0x390 => {
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo2' },
    },
);

# Canon camera information for 750D/760D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo750D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 750D and 760D.',
    0x03 => { %ciFNumber },
    0x04 => { %ciExposureTime },
    0x06 => { %ciISO },
    0x1b => { %ciCameraTemperature }, # (700D + 0)
    0x23 => { %ciFocalLength }, # (700D + 0)
    0x96 => { #IB (700D + 0x19)
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0xa5 => { # (700D + 0x19)
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0xa7 => { # (700D + 0x19)
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x131 => { # (700D + 0x19)
        Name => 'WhiteBalance',
        Format => 'int16u',
        SeparateTable => 1,
        PrintConv => \%canonWhiteBalance,
    },
    0x135 => {
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0x169 => {
        Name => 'PictureStyle',
        Format => 'int8u',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    0x184 => {
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0x186 => { %ciMinFocal },
    0x188 => { %ciMaxFocal },
    0x43d => { # (750D/760D firmware 6.7.2)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
    0x449 => { # (750D/760D firmware 1.0.0)
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        RawConv => '$val=~/^\d+\.\d+\.\d+\s*$/ ? $val : undef',
    },
);

# Canon camera information for 1000D (MakerNotes tag 0x0d) (ref PH)
%Image::ExifTool::Canon::CameraInfo1000D = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    IS_SUBDIR => [ 0x267 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'CameraInfo tags for the EOS 1000D.',
    0x03 => { %ciFNumber }, #PH
    0x04 => { %ciExposureTime }, #PH
    0x06 => { %ciISO }, #PH
    0x15 => { #PH (580 EX II)
        Name => 'FlashMeteringMode',
        PrintConv => {
            0 => 'E-TTL',
            3 => 'TTL',
            4 => 'External Auto',
            5 => 'External Manual',
            6 => 'Off',
        },
    },
    0x18 => { %ciCameraTemperature }, #36
    0x1b => { %ciMacroMagnification }, #PH (NC)
    0x1d => { %ciFocalLength }, #PH
    0x30 => { #20
        Name => 'CameraOrientation',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Rotate 90 CW',
            2 => 'Rotate 270 CW',
        },
    },
    0x43 => { #20
        Name => 'FocusDistanceUpper',
        %focusDistanceByteSwap,
    },
    0x45 => { #20
        Name => 'FocusDistanceLower',
        %focusDistanceByteSwap,
    },
    0x6f => { #PH
        Name => 'WhiteBalance',
        Format => 'int16u',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    0x73 => { #PH
        Name => 'ColorTemperature',
        Format => 'int16u',
    },
    0xe2 => { #PH
        Name => 'LensType',
        Format => 'int16uRev', # value is big-endian
        SeparateTable => 1,
        ValueConvInv => 'int($val)', # (must truncate decimal part)
        PrintConv => \%canonLensTypes,
        PrintInt => 1,
    },
    0xe4 => { %ciMinFocal }, #PH
    0xe6 => { %ciMaxFocal }, #PH
    0x10b => { #PH
        Name => 'FirmwareVersion',
        Format => 'string[6]',
    },
    0x137 => { #PH (NC)
        Name => 'DirectoryIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
    },
    0x143 => { #PH
        Name => 'FileIndex',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
    },
    0x267 => { #PH
        Name => 'PictureStyleInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::PSInfo' },
    },
    0x937 => { #PH
        Name => 'LensModel',
        Format => 'string[64]',
    },
);

# Canon camera information for PowerShot models (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoPowerShot = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for PowerShot models such as the A450, A460, A550, A560,
        A570, A630, A640, A650, A710, A720, G7, G9, S5, SD40, SD750, SD800, SD850,
        SD870, SD900, SD950, SD1000, SX100 and TX1.
    },
    0x00 => {
        Name => 'ISO',
        Groups => { 2 => 'Image' },
        ValueConv => '100*exp((($val-411)/96)*log(2))',
        ValueConvInv => 'log($val/100)/log(2)*96+411',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    0x05 => {
        Name => 'FNumber',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp($val/192*log(2))',
        ValueConvInv => 'log($val)*192/log(2)',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    0x06 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp(-$val/96*log(2))',
        ValueConvInv => '-log($val)*96/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x17 => 'Rotation', # usually the same as Orientation (but not always! why?)
    # 0x25 - flash fired/not fired (ref 37)
    # 0x26 - related to flash mode? (ref 37)
    # 0x37 - related to flash strength (ref 37)
    # 0x38 - pre-flash fired/no fired or flash data collection (ref 37)
    135 => { # [-3] <-- index relative to CameraInfoCount
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 138',
        Notes => 'A450, A460, A550, A630, A640 and A710',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    145 => { #37 [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 148',
        Notes => q{
            A560, A570, A650, A720, G7, G9, S5, SD40, SD750, SD800, SD850, SD870, SD900,
            SD950, SD1000, SX100 and TX1
        },
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
);

# Canon camera information for some PowerShot models (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoPowerShot2 = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        CameraInfo tags for PowerShot models such as the A470, A480, A490, A495,
        A580, A590, A1000, A1100, A2000, A2100, A3000, A3100, D10, E1, G10, G11,
        S90, S95, SD770, SD780, SD790, SD880, SD890, SD940, SD960, SD970, SD980,
        SD990, SD1100, SD1200, SD1300, SD1400, SD3500, SD4000, SD4500, SX1, SX10,
        SX20, SX110, SX120, SX130, SX200 and SX210.
    },
    0x01 => {
        Name => 'ISO',
        Groups => { 2 => 'Image' },
        ValueConv => '100*exp((($val-411)/96)*log(2))',
        ValueConvInv => 'log($val/100)/log(2)*96+411',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    0x06 => {
        Name => 'FNumber',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp($val/192*log(2))',
        ValueConvInv => 'log($val)*192/log(2)',
        PrintConv => 'sprintf("%.2g",$val)',
        PrintConvInv => '$val',
    },
    0x07 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        ValueConv => 'exp(-$val/96*log(2))',
        ValueConvInv => '-log($val)*96/log(2)',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x18 => 'Rotation',
    153 => { # [-3] <-- index relative to CameraInfoCount
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 156',
        Notes => 'A470, A580, A590, SD770, SD790, SD890 and SD1100',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    159 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 162',
        Notes => 'A1000, A2000, E1, G10, SD880, SD990, SX1, SX10 and SX110',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    164 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 167',
        Notes => 'A480, A1100, A2100, D10, SD780, SD960, SD970, SD1200 and SX200',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    168 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 171',
        Notes => q{
            A490, A495, A3000, A3100, G11, S90, SD940, SD980, SD1300, SD1400, SD3500,
            SD4000, SX20, SX120 and SX210
        },
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    261 => { # [-3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 264',
        Notes => 'S95, SD4500 and SX130',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
);

# unknown Canon camera information (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoUnknown32 = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Unknown CameraInfo tags are divided into 3 tables based on format size.',
    # This tag may be uncommented, and is useful for generating
    # lists of models in the "Notes" below...
    # 0 => {
    #     Name => 'CameraInfoCount',
    #     ValueConv => '$$self{CameraInfoCount}',
    # },
    71 => { # [-1] <-- index relative to CameraInfoCount
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 72',
        Notes => 'S1',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    83 => { # [-2]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 85',
        Notes => 'S2',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    91 => { # [-2 or -3]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 93 or $$self{CameraInfoCount} == 94',
        Notes => 'A410, A610, A620, S80, SD30, SD400, SD430, SD450, SD500 and SD550',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    92 => { # [-4]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 96',
        Notes => 'S3',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    100 => { # [-4]
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} == 104',
        Notes => 'A420, A430, A530, A540, A700, SD600, SD630 and SD700',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
    -3 => {
        Name => 'CameraTemperature',
        Condition => '$$self{CameraInfoCount} > 400',
        Notes => '3 entries from end of record for most newer camera models',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?C//; $val',
    },
#    466 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 469',
#        Notes => '100HS, 300HS, 500HS, A1200, A2200, A3200 and A3300',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    503 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 506',
#        Notes => 'A800',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    506 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 509',
#        Notes => 'SX230HS',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    520 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 523',
#        Notes => '310HS, 510HS, G1X, S100 (new), SX40HS and SX150',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    524 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 527',
#        Notes => '110HS, 520HS, A2300, A2400, A3400, A4000, D20 and SX260HS',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    532 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 535',
#        Notes => 'S110 (new), G15, SX50, SX160IS and SX500IS',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    547 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 550',
#        Notes => '130IS, A1400, A2500 and A2600',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    549 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 552',
#        Notes => '115IS, 130IS, SX270, SX280, 330HS and A3500',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    552 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 555',
#        Notes => 'S200 (new)',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    850 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 853',
#        Notes => 'N',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
#    895 => { # [-3]
#        Name => 'CameraTemperature',
#        Condition => '$$self{CameraInfoCount} == 898',
#        Notes => 'G1XmkII, N100, SX600HS and SX700HS',
#        PrintConv => '"$val C"',
#        PrintConvInv => '$val=~s/ ?C//; $val',
#    },
);

# unknown Canon camera information (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoUnknown16 = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# unknown Canon camera information (MakerNotes tag 0x0d) - PH
%Image::ExifTool::Canon::CameraInfoUnknown = (
    %binaryDataAttrs,
    FORMAT => 'int8s',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x16b => {
        Name => 'LensSerialNumber',
        Condition => '$$self{Model} =~ /^Canon EOS 5DS/', # (good for 5DS and 5DSR)
        Format => 'undef[5]',
        Priority => 0,
        ValueConv => 'unpack("H*",$val)',
        ValueConvInv => 'length($val) < 10 and $val = 0 x (10-length($val)) . $val; pack("H*",$val)',
    },
    0x5c1 => {
        Name => 'FirmwareVersion',
        Format => 'string[6]',
        Writable => 0,
        Condition => '$$valPt =~ /^\d\.\d\.\d\0/',
        Notes => 'M50', # (firmware 1.0.0)
    },
);

# Picture Style information for various cameras (ref 48)
%Image::ExifTool::Canon::PSInfo = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom picture style information for various models.',
    # (values expected to be "n/a" are flagged as Unknown)
    0x00 => { Name => 'ContrastStandard',      %psInfo },
    0x04 => { Name => 'SharpnessStandard',     %psInfo },
    0x08 => { Name => 'SaturationStandard',    %psInfo },
    0x0c => { Name => 'ColorToneStandard',     %psInfo },
    0x10 => { Name => 'FilterEffectStandard',  %psInfo, Unknown => 1 },
    0x14 => { Name => 'ToningEffectStandard',  %psInfo, Unknown => 1 },
    0x18 => { Name => 'ContrastPortrait',      %psInfo },
    0x1c => { Name => 'SharpnessPortrait',     %psInfo },
    0x20 => { Name => 'SaturationPortrait',    %psInfo },
    0x24 => { Name => 'ColorTonePortrait',     %psInfo },
    0x28 => { Name => 'FilterEffectPortrait',  %psInfo, Unknown => 1 },
    0x2c => { Name => 'ToningEffectPortrait',  %psInfo, Unknown => 1 },
    0x30 => { Name => 'ContrastLandscape',     %psInfo },
    0x34 => { Name => 'SharpnessLandscape',    %psInfo },
    0x38 => { Name => 'SaturationLandscape',   %psInfo },
    0x3c => { Name => 'ColorToneLandscape',    %psInfo },
    0x40 => { Name => 'FilterEffectLandscape', %psInfo, Unknown => 1 },
    0x44 => { Name => 'ToningEffectLandscape', %psInfo, Unknown => 1 },
    0x48 => { Name => 'ContrastNeutral',       %psInfo },
    0x4c => { Name => 'SharpnessNeutral',      %psInfo },
    0x50 => { Name => 'SaturationNeutral',     %psInfo },
    0x54 => { Name => 'ColorToneNeutral',      %psInfo },
    0x58 => { Name => 'FilterEffectNeutral',   %psInfo, Unknown => 1 },
    0x5c => { Name => 'ToningEffectNeutral',   %psInfo, Unknown => 1 },
    0x60 => { Name => 'ContrastFaithful',      %psInfo },
    0x64 => { Name => 'SharpnessFaithful',     %psInfo },
    0x68 => { Name => 'SaturationFaithful',    %psInfo },
    0x6c => { Name => 'ColorToneFaithful',     %psInfo },
    0x70 => { Name => 'FilterEffectFaithful',  %psInfo, Unknown => 1 },
    0x74 => { Name => 'ToningEffectFaithful',  %psInfo, Unknown => 1 },
    0x78 => { Name => 'ContrastMonochrome',    %psInfo },
    0x7c => { Name => 'SharpnessMonochrome',   %psInfo },
    0x80 => { Name => 'SaturationMonochrome',  %psInfo, Unknown => 1 },
    0x84 => { Name => 'ColorToneMonochrome',   %psInfo, Unknown => 1 },
    0x88 => { Name => 'FilterEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x8c => { Name => 'ToningEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x90 => { Name => 'ContrastUserDef1',      %psInfo },
    0x94 => { Name => 'SharpnessUserDef1',     %psInfo },
    0x98 => { Name => 'SaturationUserDef1',    %psInfo },
    0x9c => { Name => 'ColorToneUserDef1',     %psInfo },
    0xa0 => { Name => 'FilterEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa4 => { Name => 'ToningEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa8 => { Name => 'ContrastUserDef2',      %psInfo },
    0xac => { Name => 'SharpnessUserDef2',     %psInfo },
    0xb0 => { Name => 'SaturationUserDef2',    %psInfo },
    0xb4 => { Name => 'ColorToneUserDef2',     %psInfo },
    0xb8 => { Name => 'FilterEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xbc => { Name => 'ToningEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xc0 => { Name => 'ContrastUserDef3',      %psInfo },
    0xc4 => { Name => 'SharpnessUserDef3',     %psInfo },
    0xc8 => { Name => 'SaturationUserDef3',    %psInfo },
    0xcc => { Name => 'ColorToneUserDef3',     %psInfo },
    0xd0 => { Name => 'FilterEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xd4 => { Name => 'ToningEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    # base picture style names:
    0xd8 => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xda => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xdc => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
);

# Picture Style information for the 60D, etc (ref 48)
%Image::ExifTool::Canon::PSInfo2 = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Custom picture style information for the EOS 5DmkIII, 60D, 600D and 1100D.',
    # (values expected to be "n/a" are flagged as Unknown)
    0x00 => { Name => 'ContrastStandard',      %psInfo },
    0x04 => { Name => 'SharpnessStandard',     %psInfo },
    0x08 => { Name => 'SaturationStandard',    %psInfo },
    0x0c => { Name => 'ColorToneStandard',     %psInfo },
    0x10 => { Name => 'FilterEffectStandard',  %psInfo, Unknown => 1 },
    0x14 => { Name => 'ToningEffectStandard',  %psInfo, Unknown => 1 },
    0x18 => { Name => 'ContrastPortrait',      %psInfo },
    0x1c => { Name => 'SharpnessPortrait',     %psInfo },
    0x20 => { Name => 'SaturationPortrait',    %psInfo },
    0x24 => { Name => 'ColorTonePortrait',     %psInfo },
    0x28 => { Name => 'FilterEffectPortrait',  %psInfo, Unknown => 1 },
    0x2c => { Name => 'ToningEffectPortrait',  %psInfo, Unknown => 1 },
    0x30 => { Name => 'ContrastLandscape',     %psInfo },
    0x34 => { Name => 'SharpnessLandscape',    %psInfo },
    0x38 => { Name => 'SaturationLandscape',   %psInfo },
    0x3c => { Name => 'ColorToneLandscape',    %psInfo },
    0x40 => { Name => 'FilterEffectLandscape', %psInfo, Unknown => 1 },
    0x44 => { Name => 'ToningEffectLandscape', %psInfo, Unknown => 1 },
    0x48 => { Name => 'ContrastNeutral',       %psInfo },
    0x4c => { Name => 'SharpnessNeutral',      %psInfo },
    0x50 => { Name => 'SaturationNeutral',     %psInfo },
    0x54 => { Name => 'ColorToneNeutral',      %psInfo },
    0x58 => { Name => 'FilterEffectNeutral',   %psInfo, Unknown => 1 },
    0x5c => { Name => 'ToningEffectNeutral',   %psInfo, Unknown => 1 },
    0x60 => { Name => 'ContrastFaithful',      %psInfo },
    0x64 => { Name => 'SharpnessFaithful',     %psInfo },
    0x68 => { Name => 'SaturationFaithful',    %psInfo },
    0x6c => { Name => 'ColorToneFaithful',     %psInfo },
    0x70 => { Name => 'FilterEffectFaithful',  %psInfo, Unknown => 1 },
    0x74 => { Name => 'ToningEffectFaithful',  %psInfo, Unknown => 1 },
    0x78 => { Name => 'ContrastMonochrome',    %psInfo },
    0x7c => { Name => 'SharpnessMonochrome',   %psInfo },
    0x80 => { Name => 'SaturationMonochrome',  %psInfo, Unknown => 1 },
    0x84 => { Name => 'ColorToneMonochrome',   %psInfo, Unknown => 1 },
    0x88 => { Name => 'FilterEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x8c => { Name => 'ToningEffectMonochrome',%psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0x90 => { Name => 'ContrastAuto',          %psInfo },
    0x94 => { Name => 'SharpnessAuto',         %psInfo },
    0x98 => { Name => 'SaturationAuto',        %psInfo },
    0x9c => { Name => 'ColorToneAuto',         %psInfo },
    0xa0 => { Name => 'FilterEffectAuto',      %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa4 => { Name => 'ToningEffectAuto',      %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xa8 => { Name => 'ContrastUserDef1',      %psInfo },
    0xac => { Name => 'SharpnessUserDef1',     %psInfo },
    0xb0 => { Name => 'SaturationUserDef1',    %psInfo },
    0xb4 => { Name => 'ColorToneUserDef1',     %psInfo },
    0xb8 => { Name => 'FilterEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xbc => { Name => 'ToningEffectUserDef1',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xc0 => { Name => 'ContrastUserDef2',      %psInfo },
    0xc4 => { Name => 'SharpnessUserDef2',     %psInfo },
    0xc8 => { Name => 'SaturationUserDef2',    %psInfo },
    0xcc => { Name => 'ColorToneUserDef2',     %psInfo },
    0xd0 => { Name => 'FilterEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xd4 => { Name => 'ToningEffectUserDef2',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xd8 => { Name => 'ContrastUserDef3',      %psInfo },
    0xdc => { Name => 'SharpnessUserDef3',     %psInfo },
    0xe0 => { Name => 'SaturationUserDef3',    %psInfo },
    0xe4 => { Name => 'ColorToneUserDef3',     %psInfo },
    0xe8 => { Name => 'FilterEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    0xec => { Name => 'ToningEffectUserDef3',  %psInfo,
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
            -559038737 => 'n/a', # (0xdeadbeef)
        },
    },
    # base picture style names:
    0xf0 => {
        Name => 'UserDef1PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xf2 => {
        Name => 'UserDef2PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
    0xf4 => {
        Name => 'UserDef3PictureStyle',
        Format => 'int16u',
        SeparateTable => 'UserDefStyle',
        PrintConv => \%userDefStyles,
    },
);

# Movie information (MakerNotes tag 0x11) (ref PH)
%Image::ExifTool::Canon::MovieInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    NOTES => 'Tags written by some Canon cameras when recording video.',
    1 => { # (older PowerShot AVI)
        Name => 'FrameRate',
        RawConv => '$val == 65535 ? undef: $val',
        ValueConvInv => '$val > 65535 ? 65535 : $val',
    },
    2 => { # (older PowerShot AVI)
        Name => 'FrameCount',
        RawConv => '$val == 65535 ? undef: $val',
        ValueConvInv => '$val > 65535 ? 65535 : $val',
    },
    # 3 - values: 0x0001 (older PowerShot AVI), 0x4004, 0x4005
    4 => {
        Name => 'FrameCount',
        Format => 'int32u',
    },
    6 => {
        Name => 'FrameRate',
        Format => 'rational32u',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
        PrintConvInv => '$val',
    },
    # 9/10 - same as 6/7 (FrameRate)
    106 => {
        Name => 'Duration',
        Format => 'int32u',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => 'ConvertDuration($val)',
        PrintConvInv => q{
            my @a = ($val =~ /\d+(?:\.\d*)?/g);
            $val  = pop(@a) || 0;         # seconds
            $val += pop(@a) *   60 if @a; # minutes
            $val += pop(@a) * 3600 if @a; # hours
            return $val;
        },
    },
    108 => {
        Name => 'AudioBitrate',
        Groups => { 2 => 'Audio' },
        Format => 'int32u',
        PrintConv => 'ConvertBitrate($val)',
        PrintConvInv => q{
            $val =~ /^(\d+(?:\.\d*)?) ?([kMG]?bps)?$/ or return undef;
            return $1 * {bps=>1,kbps=>1000,Mbps=>1000000,Gbps=>1000000000}->{$2 || 'bps'};
        },
    },
    110 => {
        Name => 'AudioSampleRate',
        Groups => { 2 => 'Audio' },
        Format => 'int32u',
    },
    112 => { # (guess)
        Name => 'AudioChannels',
        Groups => { 2 => 'Audio' },
        Format => 'int32u',
    },
    # 114 - values: 0 (60D), 1 (S95)
    116 => {
        Name => 'VideoCodec',
        Format => 'undef[4]',
        # swap bytes if little endian
        RawConv => 'GetByteOrder() eq "MM" ? $val : pack("N",unpack("V",$val))',
        RawConvInv => 'GetByteOrder() eq "MM" ? $val : pack("N",unpack("V",$val))',
    },
    # 125 - same as 10
);

# AF information (MakerNotes tag 0x12) - PH
%Image::ExifTool::Canon::AFInfo = (
    PROCESS_PROC => \&ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Auto-focus information used by many older Canon models.  The values in this
        record are sequential, and some have variable sizes based on the value of
        NumAFPoints (which may be 1,5,7,9,15,45 or 53).  The AFArea coordinates are
        given in a system where the image has dimensions given by AFImageWidth and
        AFImageHeight, and 0,0 is the image center. The direction of the Y axis
        depends on the camera model, with positive Y upwards for EOS models, but
        apparently downwards for PowerShot models.
    },
    0 => {
        Name => 'NumAFPoints',
    },
    1 => {
        Name => 'ValidAFPoints',
        Notes => 'number of AF points valid in the following information',
    },
    2 => {
        Name => 'CanonImageWidth',
        Groups => { 2 => 'Image' },
    },
    3 => {
        Name => 'CanonImageHeight',
        Groups => { 2 => 'Image' },
    },
    4 => {
        Name => 'AFImageWidth',
        Notes => 'size of image in AF coordinates',
    },
    5 => 'AFImageHeight',
    6 => 'AFAreaWidth',
    7 => 'AFAreaHeight',
    8 => {
        Name => 'AFAreaXPositions',
        Format => 'int16s[$val{0}]',
    },
    9 => {
        Name => 'AFAreaYPositions',
        Format => 'int16s[$val{0}]',
    },
    10 => {
        Name => 'AFPointsInFocus',
        Format => 'int16s[int(($val{0}+15)/16)]',
        PrintConv => 'Image::ExifTool::DecodeBits($val, undef, 16)',
    },
    11 => [
        {
            Name => 'PrimaryAFPoint',
            Condition => q{
                $$self{Model} !~ /EOS/ and
                (not $$self{AFInfoCount} or $$self{AFInfoCount} != 36)
            },
        },
        {
            # (some PowerShot 9-point systems put PrimaryAFPoint after 8 unknown values)
            Name => 'Canon_AFInfo_0x000b',
            Condition => '$$self{Model} !~ /EOS/',
            Format => 'int16u[8]',
            Unknown => 1,
        },
        # (serial processing stops here for EOS cameras)
    ],
    12 => 'PrimaryAFPoint',
);

# newer AF information (MakerNotes tag 0x26 and 0x32) - PH (A570IS,1DmkIII,40D and G1XmkII)
# (Note: this tag is out of sequence in A570IS maker notes)
%Image::ExifTool::Canon::AFInfo2 = (
    PROCESS_PROC => \&ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Newer version of the AFInfo record containing much of the same information
        (and coordinate confusion) as the older version.  In this record, NumAFPoints
        may be 7, 9, 11, 19, 31, 45 or 61, depending on the camera model.
    },
    0 => {
        Name => 'AFInfoSize',
        Unknown => 1, # normally don't print this out
    },
    1 => {
        Name => 'AFAreaMode',
        PrintConv => {
            0 => 'Off (Manual Focus)',
            1 => 'AF Point Expansion (surround)', #PH
            2 => 'Single-point AF',
            # 3 - n/a
            4 => 'Auto', #forum6237 (AiAF on A570IS)
            5 => 'Face Detect AF',
            6 => 'Face + Tracking', #PH (NC, EOS M, live view)
            7 => 'Zone AF', #46
            8 => 'AF Point Expansion (4 point)', #46/PH/forum6237
            9 => 'Spot AF', #46
            10 => 'AF Point Expansion (8 point)', #forum6237
            11 => 'Flexizone Multi (49 point)', #PH (NC, EOS M, live view; 750D 49 points)
            12 => 'Flexizone Multi (9 point)', #PH (750D, 9 points)
            13 => 'Flexizone Single', #PH (EOS M default, live view) (R7 calls this '1-point AF', ref github268)
            14 => 'Large Zone AF', #PH/forum6237 (7DmkII)
            16 => 'Large Zone AF (vertical)', #forum16223
            17 => 'Large Zone AF (horizontal)', #forum16223
            19 => 'Flexible Zone AF 1', #github268 (R7)
            20 => 'Flexible Zone AF 2', #github268 (R7)
            21 => 'Flexible Zone AF 3', #github268 (R7)
            22 => 'Whole Area AF', #github268 (R7)
        },
    },
    2 => {
        Name => 'NumAFPoints',
        RawConv => '$$self{NumAFPoints} = $val', # save for later
    },
    3 => {
        Name => 'ValidAFPoints',
        Notes => 'number of AF points valid in the following information',
    },
    4 => {
        Name => 'CanonImageWidth',
        Groups => { 2 => 'Image' },
    },
    5 => {
        Name => 'CanonImageHeight',
        Groups => { 2 => 'Image' },
    },
    6 => {
        Name => 'AFImageWidth',
        Notes => 'size of image in AF coordinates',
    },
    7 => 'AFImageHeight',
    8 => {
        Name => 'AFAreaWidths',
        Format => 'int16s[$val{2}]',
    },
    9 => {
        Name => 'AFAreaHeights',
        Format => 'int16s[$val{2}]',
    },
    10 => {
        Name => 'AFAreaXPositions',
        Format => 'int16s[$val{2}]',
    },
    11 => {
        Name => 'AFAreaYPositions',
        Format => 'int16s[$val{2}]',
    },
    12 => {
        Name => 'AFPointsInFocus',
        Format => 'int16s[int(($val{2}+15)/16)]',
        PrintConv => 'Image::ExifTool::DecodeBits($val, undef, 16)',
    },
    13 => [
        {
            Name => 'AFPointsSelected',
            Condition => '$$self{Model} =~ /EOS/',
            Format => 'int16s[int(($val{2}+15)/16)]',
            PrintConv => 'Image::ExifTool::DecodeBits($val, undef, 16)',
        },
        {
            Name => 'Canon_AFInfo2_0x000d',
            Format => 'int16s[int(($val{2}+15)/16)+1]',
            Unknown => 1,
        },
    ],
    14 => {
        # usually, but not always, the lowest number AF point in focus
        Name => 'PrimaryAFPoint',
        Condition => '$$self{Model} !~ /EOS/ and not $$self{AFInfo3}', # (not valid for G1XmkII)
    },
);

# contrast information (MakerNotes tag 0x27) - PH
%Image::ExifTool::Canon::ContrastInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    4 => {
        Name => 'IntelligentContrast',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'Off',
            0x08 => 'On',
            0xffff => 'n/a',
            OTHER => sub {
                # DPP shows "On" for any value except 0xffff when bit 0x08 is set
                my ($val, $inv) = @_;
                if ($inv) {
                    $val =~ /(0x[0-9a-f]+)/i or $val =~ /(\d+)/ or return undef;
                    return $1;
                } else {
                    return sprintf("On (0x%.2x)",$val) if $val & 0x08;
                    return sprintf("Off (0x%.2x)",$val);
                }
            },
        },
    },
    # 6 - 0=normal, 257=i-Contrast On
);

# time information (MakerNotes tag 0x35) - PH (1DX, 5DmkIII)
%Image::ExifTool::Canon::TimeInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Time' },
    # 0 - size (16 bytes)
    1 => {
        Name => 'TimeZone',
        PrintConv => 'Image::ExifTool::TimeZoneString($val)',
        PrintConvInv => q{
            $val =~ /Z$/ and return 0;
            $val =~ /([-+])(\d{1,2}):?(\d{2})$/ and return $1 . ($2 * 60 + $3);
            $val =~ /^(\d{2})(\d{2})$/ and return $1 * 60 + $2;
            return undef;
        },
    },
    2 => {
        Name => 'TimeZoneCity',
        PrintConvColumns => 3,
        PrintConv => {
            # [square brackets] = actual time zone for each city
            # (round brackets) = observed time zone values from sample images
            # --> unobserved entries have not been confirmed!
            0 => 'n/a', # (PowerShot models)
            1 => 'Chatham Islands', # [+12:45]
            2 => 'Wellington',      # [+12] (+12:00,DST+0)
            3 => 'Solomon Islands', # [+11]
            4 => 'Sydney',          # [+10] (+11:00,DST+1)
            5 => 'Adelaide',        # [+9:30]
            6 => 'Tokyo',           # [+9] (+09:00,DST+0)
            7 => 'Hong Kong',       # [+8] (+08:00,DST+0)
            8 => 'Bangkok',         # [+7] (+08:00,DST+1)
            9 => 'Yangon',          # [+6:30]
            10 => 'Dhaka',          # [+6] (Canon uses old "Dacca" spelling)
            11 => 'Kathmandu',      # [+5:45]
            12 => 'Delhi',          # [+5:30]
            13 => 'Karachi',        # [+5]
            14 => 'Kabul',          # [+4:30]
            15 => 'Dubai',          # [+4]
            16 => 'Tehran',         # [+3:30]
            17 => 'Moscow',         # [+4] (+03:00,DST+0) (! changed to +4 permanent DST in 2011)
            18 => 'Cairo',          # [+2]
            19 => 'Paris',          # [+1] (+01:10,DST+0; +02:00,DST+1)
            20 => 'London',         # [0]  (+00:00,DST+0)
            21 => 'Azores',         # [-1]
            22 => 'Fernando de Noronha', # [-2]
            23 => 'Sao Paulo',      # [-3]
            24 => 'Newfoundland',   # [-3:30]
            25 => 'Santiago',       # [-4]
            26 => 'Caracas',        # [-4:30]
            27 => 'New York',       # [-5] (-05:00,DST+0; -04:00,DST+1)
            28 => 'Chicago',        # [-6]
            29 => 'Denver',         # [-7]
            30 => 'Los Angeles',    # [-8] (-08:00,DST+0; -07:00,DST+1)
            31 => 'Anchorage',      # [-9]
            32 => 'Honolulu',       # [-10]
            33 => 'Samoa',          # [+13]
            32766 => '(not set)',   #(NC)
        },
    },
    3 => {
        Name => 'DaylightSavings',
        PrintConv => {
            0 => 'Off',
            60 => 'On',
        },
    },
);

# my color mode information (MakerNotes tag 0x1d) - PH (A570IS)
%Image::ExifTool::Canon::MyColors = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x02 => {
        Name => 'MyColorMode',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Positive Film', #15 (SD600)
            2 => 'Light Skin Tone', #15
            3 => 'Dark Skin Tone', #15
            4 => 'Vivid Blue', #15
            5 => 'Vivid Green', #15
            6 => 'Vivid Red', #15
            7 => 'Color Accent', #15 (A610) (NC)
            8 => 'Color Swap', #15 (A610)
            9 => 'Custom',
            12 => 'Vivid',
            13 => 'Neutral',
            14 => 'Sepia',
            15 => 'B&W',
        },
    },
);

# face detect information (MakerNotes tag 0x24) - PH (A570IS)
%Image::ExifTool::Canon::FaceDetect1 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    DATAMEMBER => [ 0x02 ],
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x02 => {
        Name => 'FacesDetected',
        DataMember => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    0x03 => {
        Name => 'FaceDetectFrameSize',
        Format => 'int16u[2]',
    },
    0x08 => {
        Name => 'Face1Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 1 ? undef: $val',
        Notes => q{
            X-Y coordinates for the center of each face in the Face Detect frame at the
            time of focus lock. "0 0" is the center, and positive X and Y are to the
            right and downwards respectively
        },
    },
    0x0a => {
        Name => 'Face2Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    0x0c => {
        Name => 'Face3Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    0x0e => {
        Name => 'Face4Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    0x10 => {
        Name => 'Face5Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    0x12 => {
        Name => 'Face6Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    0x14 => {
        Name => 'Face7Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    0x16 => {
        Name => 'Face8Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
    0x18 => {
        Name => 'Face9Position',
        Format => 'int16s[2]',
        RawConv => '$$self{FacesDetected} < 9 ? undef : $val',
    },
);

# more face detect information (MakerNotes tag 0x25) - PH (A570IS)
%Image::ExifTool::Canon::FaceDetect2 = (
    %binaryDataAttrs,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x01 => 'FaceWidth',
    0x02 => 'FacesDetected',
);

# G9 white balance information (MakerNotes tag 0x29) (ref IB, changed ref forum13640)
%Image::ExifTool::Canon::WBInfo = (
    %binaryDataAttrs,
    NOTES => 'WB tags for the Canon G9.',
    FORMAT => 'int32u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0x02 => { Name => 'WB_GRBGLevelsAuto',        Format => 'int32s[4]' },
    0x0a => { Name => 'WB_GRBGLevelsDaylight',    Format => 'int32s[4]' },
    0x12 => { Name => 'WB_GRBGLevelsCloudy',      Format => 'int32s[4]' },
    0x1a => { Name => 'WB_GRBGLevelsTungsten',    Format => 'int32s[4]' },
    0x22 => { Name => 'WB_GRBGLevelsFluorescent', Format => 'int32s[4]' },
    0x2a => { Name => 'WB_GRBGLevelsFluorHigh',   Format => 'int32s[4]' },
    0x32 => { Name => 'WB_GRBGLevelsFlash',       Format => 'int32s[4]' },
    0x3a => { Name => 'WB_GRBGLevelsUnderwater',  Format => 'int32s[4]' },
    0x42 => { Name => 'WB_GRBGLevelsCustom1',     Format => 'int32s[4]' },
    0x4a => { Name => 'WB_GRBGLevelsCustom2',     Format => 'int32s[4]' },
);

# yet more face detect information (MakerNotes tag 0x2f) - PH (G12)
%Image::ExifTool::Canon::FaceDetect3 = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # 0 - size (34 bytes)
    # 1 - 1=4:3/16:9,2=1:1/3:2/4:5
    # 2 - normally 1 if faces detected, but sometimes 0 (maybe if face wasn't in captured image?)
    3 => 'FacesDetected',
    # 4 - 240=4:3/4:5/1:1,180=16:9,212=3:2
);

# File number information (MakerNotes tag 0x93)
%Image::ExifTool::Canon::FileInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    DATAMEMBER => [ 20 ],
    1 => [
        { #5
            Name => 'FileNumber',
            Condition => '$$self{Model} =~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
            Format => 'int32u',
            # Thanks to Juha Eskelinen for figuring this out:
            # [this is an odd bit mapping -- it looks like the file number exists as
            # a 16-bit integer containing the high bits, followed by an 8-bit integer
            # with the low bits.  But it is more convenient to have this in a single
            # word, so some bit manipulations are necessary... - PH]
            # The bit pattern of the 32-bit word is:
            #   31....24 23....16 15.....8 7......0
            #   00000000 ffffffff DDDDDDDD ddFFFFFF
            #     0 = zero bits (not part of the file number?)
            #     f/F = low/high bits of file number
            #     d/D = low/high bits of directory number
            # The directory and file number are then converted into decimal
            # and separated by a '-' to give the file number used in the 20D
            ValueConv => '(($val&0xffc0)>>6)*10000+(($val>>16)&0xff)+(($val&0x3f)<<8)',
            ValueConvInv => q{
                my $d = int($val/10000);
                my $f = $val - $d * 10000;
                return (($d<<6) & 0xffc0) + (($f & 0xff)<<16) + (($f>>8) & 0x3f);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #16
            Name => 'FileNumber',
            Condition => '$$self{Model} =~ /\b(30D|400D|REBEL XTi|Kiss Digital X|K236)\b/',
            Format => 'int32u',
            Notes => q{
                the location of the upper 4 bits of the directory number is a mystery for
                the EOS 30D, so the reported directory number will be incorrect for original
                images with a directory number of 164 or greater
            },
            # Thanks to Emil Sit for figuring this out:
            # [more insane bit maniplations like the 20D/350D above, but this time we
            # appear to have lost the upper 4 bits of the directory number (this was
            # verified through tests with directory numbers 100, 222, 801 and 999) - PH]
            # The bit pattern for the 30D is: (see 20D notes above for more information)
            #   31....24 23....16 15.....8 7......0
            #   00000000 ffff0000 ddddddFF FFFFFFFF
            # [NOTE: the 4 high order directory bits don't appear in this record, but
            # I have chosen to write them into bits 16-19 since these 4 zero bits look
            # very suspicious, and are a convenient place to store this information - PH]
            ValueConv  => q{
                my $d = ($val & 0xffc00) >> 10;
                # we know there are missing bits if directory number is < 100
                $d += 0x40 while $d < 100;  # (repair the damage as best we can)
                return $d*10000 + (($val&0x3ff)<<4) + (($val>>20)&0x0f);
            },
            ValueConvInv => q{
                my $d = int($val/10000);
                my $f = $val - $d * 10000;
                return ($d << 10) + (($f>>4)&0x3ff) + (($f&0x0f)<<20);
            },
            PrintConv => '$_=$val,s/(\d+)(\d{4})/$1-$2/,$_',
            PrintConvInv => '$val=~s/-//g;$val',
        },
        { #7 (1D, 1Ds)
            Name => 'ShutterCount',
            Condition => 'GetByteOrder() eq "MM"',
            Format => 'int32u',
        },
        { #7 (1DmkII, 1DSmkII, 1DSmkIIN)
            Name => 'ShutterCount',
            # ref http://www.luminous-landscape.com/forum/index.php?topic=36469 :
            Notes => q{
                there are reports that the ShutterCount changed when loading a settings file
                on the 1DSmkII
            },
            Condition => '$$self{Model} =~ /\b1Ds? Mark II\b/',
            Format => 'int32u',
            ValueConv => '($val>>16)|(($val&0xffff)<<16)',
            ValueConvInv => '($val>>16)|(($val&0xffff)<<16)',
        },
        # 5D gives a single byte value (unknown)
        # 40D stores all zeros
    ],
    3 => { #PH
        Name => 'BracketMode',
        PrintConv => {
            0 => 'Off',
            1 => 'AEB',
            2 => 'FEB',
            3 => 'ISO',
            4 => 'WB',
        },
    },
    4 => 'BracketValue', #PH
    5 => 'BracketShotNumber', #PH
    6 => { #PH
        Name => 'RawJpgQuality',
        RawConv => '$val<=0 ? undef : $val',
        PrintConv => \%canonQuality,
    },
    7 => { #PH
        Name => 'RawJpgSize',
        RawConv => '$val<0 ? undef : $val',
        PrintConv => \%canonImageSize,
    },
    8 => { #PH
        Name => 'LongExposureNoiseReduction2',
        Notes => q{
            for some modules this gives the long exposure noise reduction applied to the
            image, but for other models this just reflects the setting independent of
            whether or not it was applied
        },
        RawConv => '$val<0 ? undef : $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On (1D)',
            3 => 'On',
            4 => 'Auto',
        },
    },
    9 => { #PH
        Name => 'WBBracketMode',
        PrintConv => {
            0 => 'Off',
            1 => 'On (shift AB)',
            2 => 'On (shift GM)',
        },
    },
    12 => 'WBBracketValueAB', #PH
    13 => 'WBBracketValueGM', #PH
    14 => { #PH
        Name => 'FilterEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'None',
            1 => 'Yellow',
            2 => 'Orange',
            3 => 'Red',
            4 => 'Green',
        },
    },
    15 => { #PH
        Name => 'ToningEffect',
        RawConv => '$val==-1 ? undef : $val',
        PrintConv => {
            0 => 'None',
            1 => 'Sepia',
            2 => 'Blue',
            3 => 'Purple',
            4 => 'Green',
        },
    },
    16 => { #PH
        %ciMacroMagnification,
        # MP-E 65mm on 5DmkII: 44=5x,52~=3.9x,56~=3.3x,62~=2.6x,75=1x
        # ME-E 65mm on 40D/450D: 72 for all samples (not valid)
        Condition => q{
            $$self{LensType} and $$self{LensType} == 124 and
            $$self{Model} !~ /\b(40D|450D|REBEL XSi|Kiss X2)\b/
        },
        Notes => q{
            currently decoded only for the MP-E 65mm f/2.8 1-5x Macro Photo, and not
            valid for all camera models
        },
    },
    # 17 - values: 0, 3, 4
    # 18 - same as LiveViewShooting for all my samples (5DmkII, 50D) - PH
    19 => { #PH
        # Note: this value is not displayed by Canon ImageBrowser for the following
        # models with the live view feature:  1DmkIII, 1DSmkIII, 40D, 450D, 1000D
        # (this tag could be valid only for some firmware versions:
        # http://www.breezesys.com/forum/showthread.php?p=16980)
        Name => 'LiveViewShooting',
        PrintConv => \%offOn,
    },
    20 => { #47
        Name => 'FocusDistanceUpper',
        DataMember => 'FocusDistanceUpper2',
        Format => 'int16u',
        RawConv => '($$self{FocusDistanceUpper2} = $val) || undef',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '$val > 655.345 ? "inf" : "$val m"',
        PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
    },
    21 => { #47
        Name => 'FocusDistanceLower',
        Condition => '$$self{FocusDistanceUpper2}',
        Format => 'int16u',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => '$val > 655.345 ? "inf" : "$val m"',
        PrintConvInv => '$val =~ s/ ?m$//; IsFloat($val) ? $val : 655.35',
    },
    # 22 - values: 0, 1
    23 => { #JohnMoyer (forum12925)
        Name => 'ShutterMode',
        PrintConv => {
            0 => 'Mechanical',
            1 => 'Electronic First Curtain',
            2 => 'Electronic',
            # 3 => ?
            # 21 => ?
            # 22 => ?
        },
    },
    25 => { #PH
        Name => 'FlashExposureLock',
        PrintConv => \%offOn,
    },
    32 => { #forum16257
        Name => 'AntiFlicker',
        PrintConv => \%offOn,
    },
    0x3d => { #IB
        Name => 'RFLensType',
        Format => 'int16u',
        PrintConv => {
            0 => 'n/a',
            257 => 'Canon RF 50mm F1.2L USM',
            258 => 'Canon RF 24-105mm F4L IS USM',
            259 => 'Canon RF 28-70mm F2L USM',
            260 => 'Canon RF 35mm F1.8 MACRO IS STM',
            261 => 'Canon RF 85mm F1.2L USM',
            262 => 'Canon RF 85mm F1.2L USM DS',
            263 => 'Canon RF 24-70mm F2.8L IS USM',
            264 => 'Canon RF 15-35mm F2.8L IS USM',
            265 => 'Canon RF 24-240mm F4-6.3 IS USM',
            266 => 'Canon RF 70-200mm F2.8L IS USM',
            267 => 'Canon RF 85mm F2 MACRO IS STM',
            268 => 'Canon RF 600mm F11 IS STM',
            269 => 'Canon RF 600mm F11 IS STM + RF1.4x',
            270 => 'Canon RF 600mm F11 IS STM + RF2x',
            271 => 'Canon RF 800mm F11 IS STM',
            272 => 'Canon RF 800mm F11 IS STM + RF1.4x',
            273 => 'Canon RF 800mm F11 IS STM + RF2x',
            274 => 'Canon RF 24-105mm F4-7.1 IS STM',
            275 => 'Canon RF 100-500mm F4.5-7.1L IS USM',
            276 => 'Canon RF 100-500mm F4.5-7.1L IS USM + RF1.4x',
            277 => 'Canon RF 100-500mm F4.5-7.1L IS USM + RF2x',
            278 => 'Canon RF 70-200mm F4L IS USM', #42
            279 => 'Canon RF 100mm F2.8L MACRO IS USM', #42
            280 => 'Canon RF 50mm F1.8 STM', #42
            281 => 'Canon RF 14-35mm F4L IS USM', #42/IB
            282 => 'Canon RF-S 18-45mm F4.5-6.3 IS STM', #42
            283 => 'Canon RF 100-400mm F5.6-8 IS USM', #42
            284 => 'Canon RF 100-400mm F5.6-8 IS USM + RF1.4x', #42
            285 => 'Canon RF 100-400mm F5.6-8 IS USM + RF2x', #42
            286 => 'Canon RF-S 18-150mm F3.5-6.3 IS STM', #42
            287 => 'Canon RF 24mm F1.8 MACRO IS STM', #42
            288 => 'Canon RF 16mm F2.8 STM', #42
            289 => 'Canon RF 400mm F2.8L IS USM', #IB
            290 => 'Canon RF 400mm F2.8L IS USM + RF1.4x', #IB
            291 => 'Canon RF 400mm F2.8L IS USM + RF2x', #IB
            292 => 'Canon RF 600mm F4L IS USM', #GiaZopatti
            293 => 'Canon RF 600mm F4L IS USM + RF1.4x', #42
            294 => 'Canon RF 600mm F4L IS USM + RF2x', #42
            295 => 'Canon RF 800mm F5.6L IS USM', #42
            296 => 'Canon RF 800mm F5.6L IS USM + RF1.4x', #42
            297 => 'Canon RF 800mm F5.6L IS USM + RF2x', #42
            298 => 'Canon RF 1200mm F8L IS USM', #42
            299 => 'Canon RF 1200mm F8L IS USM + RF1.4x', #42
            300 => 'Canon RF 1200mm F8L IS USM + RF2x', #42
            301 => 'Canon RF 5.2mm F2.8L Dual Fisheye 3D VR', #PH
            302 => 'Canon RF 15-30mm F4.5-6.3 IS STM', #42
            303 => 'Canon RF 135mm F1.8 L IS USM', #42
            304 => 'Canon RF 24-50mm F4.5-6.3 IS STM', #42
            305 => 'Canon RF-S 55-210mm F5-7.1 IS STM', #42
            306 => 'Canon RF 100-300mm F2.8L IS USM', #42
            307 => 'Canon RF 100-300mm F2.8L IS USM + RF1.4x', #42
            308 => 'Canon RF 100-300mm F2.8L IS USM + RF2x', #42
            309 => 'Canon RF 200-800mm F6.3-9 IS USM', #42
            310 => 'Canon RF 200-800mm F6.3-9 IS USM + RF1.4x', #42
            311 => 'Canon RF 200-800mm F6.3-9 IS USM + RF2x', #42
            312 => 'Canon RF 10-20mm F4 L IS STM', #42
            313 => 'Canon RF 28mm F2.8 STM', #42
            314 => 'Canon RF 24-105mm F2.8 L IS USM Z', #42
            315 => 'Canon RF-S 10-18mm F4.5-6.3 IS STM', #42
            316 => 'Canon RF 35mm F1.4 L VCM', #42
            317 => 'Canon RF-S 3.9mm F3.5 STM DUAL FISHEYE', #42
            318 => 'Canon RF 28-70mm F2.8 IS STM', #42
            319 => 'Canon RF 70-200mm F2.8 L IS USM Z', #42
            320 => 'Canon RF 70-200mm F2.8 L IS USM Z + RF1.4x', #42
            321 => 'Canon RF 70-200mm F2.8 L IS USM Z + RF2x', #42
            323 => 'Canon RF 16-28mm F2.8 IS STM', #42
            324 => 'Canon RF-S 14-30mm F4-6.3 IS STM PZ', #42
            325 => 'Canon RF 50mm F1.4 L VCM', #42
            326 => 'Canon RF 24mm F1.4 L VCM', #42
            327 => 'Canon RF 20mm F1.4 L VCM', #42
            328 => 'Canon RF 85mm F1.4 L VCM', #42/github350
            330 => 'Canon RF 45mm F1.2 STM', #42
            331 => 'Canon RF 7-14mm F2.8-3.5 L FISHEYE STM', #42
            332 => 'Canon RF 14mm F1.4 L VCM', #42
            # Note: add new RF lenses to %canonLensTypes with ID 61182
        },
    },
);

# Internal serial number information (MakerNotes tag 0x96) (ref PH)
%Image::ExifTool::Canon::SerialInfo = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    9 => {
        Name => 'InternalSerialNumber',
        Format => 'string',
    },
);

# Cropping information (MakerNotes tag 0x98) (ref PH)
%Image::ExifTool::Canon::CropInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => 'CropLeftMargin',  # (NC, may be right)
    1 => 'CropRightMargin',
    2 => 'CropTopMargin',   # (NC, may be bottom)
    3 => 'CropBottomMargin',
);

# Aspect ratio information (MakerNotes tag 0x9a) (ref PH)
%Image::ExifTool::Canon::AspectInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'AspectRatio',
        PrintConv => {
            0 => '3:2',
            1 => '1:1',
            2 => '4:3',
            7 => '16:9',
            8 => '4:5',
            12 => '3:2 (APS-H crop)', #IB
            13 => '3:2 (APS-C crop)', #IB
            258 => '4:3 crop', #PH (NC)
        },
    },
    # (could use better names for these, or the Crop tags above, or both)
    1 => 'CroppedImageWidth',
    2 => 'CroppedImageHeight',
    3 => 'CroppedImageLeft', #forum4138
    4 => 'CroppedImageTop', #ditto
);

# Color information (MakerNotes tag 0xa0)
%Image::ExifTool::Canon::Processing = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => { #PH
        Name => 'ToneCurve',
        PrintConv => {
            0 => 'Standard',
            1 => 'Manual',
            2 => 'Custom',
        },
    },
    2 => { #12
        Name => 'Sharpness', # (unsharp mask strength for the EOS R5)
        Notes => 'all models except the 20D and 350D',
        Condition => '$$self{Model} !~ /\b(20D|350D|REBEL XT|Kiss Digital N)\b/',
        Priority => 0,  # (maybe not as reliable as other sharpness values)
    },
    3 => { #PH
        Name => 'SharpnessFrequency', # PatternSharpness?
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    4 => 'SensorRedLevel', #PH
    5 => 'SensorBlueLevel', #PH
    6 => 'WhiteBalanceRed', #PH
    7 => 'WhiteBalanceBlue', #PH
    8 => { #PH
        Name => 'WhiteBalance',
        RawConv => '$val < 0 ? undef : $val',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 1,
    },
    9 => 'ColorTemperature', #6
    10 => { #12
        Name => 'PictureStyle',
        Flags => ['PrintHex','SeparateTable'],
        PrintConv => \%pictureStyles,
    },
    11 => { #PH
        Name => 'DigitalGain',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
    12 => { #PH
        Name => 'WBShiftAB',
        Notes => 'positive is a shift toward amber',
    },
    13 => { #PH
        Name => 'WBShiftGM',
        Notes => 'positive is a shift toward green',
    },
    14 => 'UnsharpMaskFineness', #forum16036
    15 => 'UnsharpMaskThreshold', #forum16036
);

# Color balance information (MakerNotes tag 0xa9) (ref PH)
%Image::ExifTool::Canon::ColorBalance = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 10D and 300D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # red,green1,green2,blue (ref 2)
    1  => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    5  => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    9  => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    13 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    17 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    21 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    25 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    29 => [{
        Name => 'WB_RGGBLevelsCustom',
        Notes => 'black levels for the D60',
        Condition => '$$self{Model} !~ /EOS D60\b/',
        Format => 'int16s[4]',
    },{ # (black levels for D60, ref IB)
        Name => 'BlackLevels',
        Format => 'int16s[4]',
    }],
    33 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    37 => { Name => 'WB_RGGBBlackLevels',      Format => 'int16s[4]' }, #IB
);

# Measured color levels (MakerNotes tag 0xaa) (ref 37)
%Image::ExifTool::Canon::MeasuredColor = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        # this is basically the inverse of WB_RGGBLevelsMeasured (ref 37)
        Name => 'MeasuredRGGB',
        Format => 'int16u[4]',
    },
    # 5 - observed values: 0, 1 - PH
);

# Flags information (MakerNotes tag 0xb0) (ref PH)
%Image::ExifTool::Canon::Flags = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => 'ModifiedParamFlag',
);

# Modified information (MakerNotes tag 0xb1) (ref PH)
%Image::ExifTool::Canon::ModifiedInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'ModifiedToneCurve',
        PrintConv => {
            0 => 'Standard',
            1 => 'Manual',
            2 => 'Custom',
        },
    },
    2 => {
        Name => 'ModifiedSharpness',
        Notes => '1D and 5D only',
        Condition => '$$self{Model} =~ /\b(1D|5D)/',
    },
    3 => {
        Name => 'ModifiedSharpnessFreq', # ModifiedPatternSharpness?
        PrintConv => {
            0 => 'n/a',
            1 => 'Lowest',
            2 => 'Low',
            3 => 'Standard',
            4 => 'High',
            5 => 'Highest',
        },
    },
    4 => 'ModifiedSensorRedLevel',
    5 => 'ModifiedSensorBlueLevel',
    6 => 'ModifiedWhiteBalanceRed',
    7 => 'ModifiedWhiteBalanceBlue',
    8 => {
        Name => 'ModifiedWhiteBalance',
        PrintConv => \%canonWhiteBalance,
        SeparateTable => 'WhiteBalance',
    },
    9 => 'ModifiedColorTemp',
    10 => {
        Name => 'ModifiedPictureStyle',
        PrintHex => 1,
        SeparateTable => 'PictureStyle',
        PrintConv => \%pictureStyles,
    },
    11 => {
        Name => 'ModifiedDigitalGain',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
    },
);

# Preview image information (MakerNotes tag 0xb6)
# - The 300D writes a 1536x1024 preview image that is accessed
#   through this information - decoded by PH 12/14/03
%Image::ExifTool::Canon::PreviewImageInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32u',
    FIRST_ENTRY => 1,
    IS_OFFSET => [ 5 ],   # tag 5 is 'IsOffset'
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
# the size of the preview block in 2-byte increments
#    0 => {
#        Name => 'PreviewImageInfoWords',
#    },
    1 => {
        Name => 'PreviewQuality',
        PrintConv => \%canonQuality,
    },
    2 => {
        Name => 'PreviewImageLength',
        OffsetPair => 5,   # point to associated offset
        DataTag => 'PreviewImage',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    3 => 'PreviewImageWidth',
    4 => 'PreviewImageHeight',
    5 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 2,  # associated byte count tagID
        DataTag => 'PreviewImage',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    # NOTE: The size of the PreviewImageInfo structure is incorrectly
    # written as 48 bytes (Count=12, Format=int32u), but only the first
    # 6 int32u values actually exist
);

# Sensor information (MakerNotes tag 0xe0) (ref 12)
%Image::ExifTool::Canon::SensorInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    # Note: Don't make these writable because it confuses Canon decoding software
    # if these are changed
    1 => 'SensorWidth',
    2 => 'SensorHeight',
    5 => 'SensorLeftBorder', #2
    6 => 'SensorTopBorder', #2
    7 => 'SensorRightBorder', #2
    8 => 'SensorBottomBorder', #2
    9 => { #22
        Name => 'BlackMaskLeftBorder',
        Notes => q{
            coordinates for the area to the left or right of the image used to calculate
            the average black level
        },
    },
    10 => 'BlackMaskTopBorder', #22
    11 => 'BlackMaskRightBorder', #22
    12 => 'BlackMaskBottomBorder', #22
);

# Color data (MakerNotes tag 0x4001, count=582) (ref 12)
%Image::ExifTool::Canon::ColorData1 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 20D and 350D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x4b ],
    # 0x00: size of record in bytes - PH
    # (dcraw 8.81 uses index 0x19 for WB)
    0x19 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x1d => 'ColorTempAsShot',
    0x1e => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x22 => 'ColorTempAuto',
    0x23 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x27 => 'ColorTempDaylight',
    0x28 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x2c => 'ColorTempShade',
    0x2d => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x31 => 'ColorTempCloudy',
    0x32 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x36 => 'ColorTempTungsten',
    0x37 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16s[4]' },
    0x3b => 'ColorTempFluorescent',
    0x3c => { Name => 'WB_RGGBLevelsFlash',       Format => 'int16s[4]' },
    0x40 => 'ColorTempFlash',
    0x41 => { Name => 'WB_RGGBLevelsCustom1',     Format => 'int16s[4]' },
    0x45 => 'ColorTempCustom1',
    0x46 => { Name => 'WB_RGGBLevelsCustom2',     Format => 'int16s[4]' },
    0x4a => 'ColorTempCustom2',
    0x4b => { #PH
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1, # (all tags are unknown, so we can avoid processing entire directory)
        Notes => 'A, B, C, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
);

# Color data (MakerNotes tag 0x4001, count=653) (ref 12)
%Image::ExifTool::Canon::ColorData2 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 1DmkII and 1DSmkII.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0xa4 ],
    0x18 => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x1c => 'ColorTempAuto',
    0x1d => { Name => 'WB_RGGBLevelsUnknown',    Format => 'int16s[4]', Unknown => 1 },
    0x21 => { Name => 'ColorTempUnknown', Unknown => 1 },
    # (dcraw 8.81 uses index 0x22 for WB)
    0x22 => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x26 => 'ColorTempAsShot',
    0x27 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x2b => 'ColorTempDaylight',
    0x2c => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x30 => 'ColorTempShade',
    0x31 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x35 => 'ColorTempCloudy',
    0x36 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x3a => 'ColorTempTungsten',
    0x3b => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x3f => 'ColorTempFluorescent',
    0x40 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x44 => 'ColorTempKelvin',
    0x45 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x49 => 'ColorTempFlash',
    0x4a => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x4e => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x4f => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x53 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x54 => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x58 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x59 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x5d => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x5e => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x62 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x63 => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x67 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x68 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x6c => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x6d => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x71 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x72 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x76 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x77 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0x7b => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0x7c => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0x80 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0x81 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0x85 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0x86 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0x8a => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0x8b => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0x8f => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0x90 => { Name => 'WB_RGGBLevelsPC1',        Format => 'int16s[4]' },
    0x94 => 'ColorTempPC1',
    0x95 => { Name => 'WB_RGGBLevelsPC2',        Format => 'int16s[4]' },
    0x99 => 'ColorTempPC2',
    0x9a => { Name => 'WB_RGGBLevelsPC3',        Format => 'int16s[4]' },
    0x9e => 'ColorTempPC3',
    0x9f => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xa3 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xa4 => { #PH
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'A, B, C, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x26a => { #PH
        Name => 'RawMeasuredRGGB',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
);

# Color data (MakerNotes tag 0x4001, count=796) (ref 12)
%Image::ExifTool::Canon::ColorData3 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the 1DmkIIN, 5D, 30D and 400D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x85 ],
    0x00 => { #PH
        Name => 'ColorDataVersion',
        PrintConv => {
            1 => '1 (1DmkIIN/5D/30D/400D)',
        },
    },
    # 0x01-0x3e: RGGB coefficients, apparently specific to the
    # individual camera and possibly used for color calibration (ref 37)
    # (dcraw 8.81 uses index 0x3f for WB)
    0x3f => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x43 => 'ColorTempAsShot',
    0x44 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x48 => 'ColorTempAuto',
    # not sure exactly what 'Measured' values mean...
    0x49 => { Name => 'WB_RGGBLevelsMeasured',    Format => 'int16s[4]' },
    0x4d => 'ColorTempMeasured',
    0x4e => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x52 => 'ColorTempDaylight',
    0x53 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x57 => 'ColorTempShade',
    0x58 => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x5c => 'ColorTempCloudy',
    0x5d => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x61 => 'ColorTempTungsten',
    0x62 => { Name => 'WB_RGGBLevelsFluorescent', Format => 'int16s[4]' },
    0x66 => 'ColorTempFluorescent',
    0x67 => { Name => 'WB_RGGBLevelsKelvin',      Format => 'int16s[4]' },
    0x6b => 'ColorTempKelvin',
    0x6c => { Name => 'WB_RGGBLevelsFlash',       Format => 'int16s[4]' },
    0x70 => 'ColorTempFlash',
    0x71 => { Name => 'WB_RGGBLevelsPC1',         Format => 'int16s[4]' },
    0x75 => 'ColorTempPC1',
    0x76 => { Name => 'WB_RGGBLevelsPC2',         Format => 'int16s[4]' },
    0x7a => 'ColorTempPC2',
    0x7b => { Name => 'WB_RGGBLevelsPC3',         Format => 'int16s[4]' },
    0x7f => 'ColorTempPC3',
    0x80 => { Name => 'WB_RGGBLevelsCustom',      Format => 'int16s[4]' },
    0x84 => 'ColorTempCustom',
    0x85 => { #37
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0xc4 => { #IB
        Name => 'PerChannelBlackLevel',
        Format => 'int16u[4]',
    },
    # 0xc8-0x1c7: some sort of color table (ref 37)
    0x248 => { #37
        Name => 'FlashOutput',
        ValueConv => '$val >= 255 ? 255 : exp(($val-200)/16*log(2))',
        ValueConvInv => '$val == 255 ? 255 : 200 + log($val)*16/log(2)',
        PrintConv => '$val == 255 ? "Strobe or Misfire" : sprintf("%.0f%%", $val * 100)',
        PrintConvInv => '$val =~ /^(\d(\.?\d*))/ ? $1 / 100 : 255',
    },
    0x249 => { #37
        Name => 'FlashBatteryLevel',
        # calibration points for external flash: 144=3.76V (almost empty), 192=5.24V (full)
        # - have seen a value of 201 with internal flash
        PrintConv => '$val ? sprintf("%.2fV", $val * 5 / 186) : "n/a"',
        PrintConvInv => '$val=~/^(\d+\.\d+)\s*V?$/i ? int($val*186/5+0.5) : 0',
    },
    0x24a => { #37
        Name => 'ColorTempFlashData',
        # 0 for no external flash, 35980 for 'Strobe or Misfire'
        # (lower than ColorTempFlash by up to 200 degrees)
        RawConv => '($val < 2000 or $val > 12000) ? undef : $val',
    },
    # 0x24b: inverse relationship with flash power (ref 37)
    # 0x286: has value 256 for correct exposure, less for under exposure (seen 96 minimum) (ref 37)
    0x287 => { #37
        Name => 'MeasuredRGGBData',
        Format => 'int32u[4]',
        Notes => 'MeasuredRGGB may be derived from these data values',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
    # 0x297: ranges from -10 to 30, higher for high ISO (ref 37)
);

# Color data (MakerNotes tag 0x4001, count=674|692|702|1227|1250|1251|1337|1338|1346) (ref PH)
%Image::ExifTool::Canon::ColorData4 = (
    %binaryDataAttrs,
    NOTES => q{
        These tags are used by the 1DmkIII, 1DSmkIII, 1DmkIV, 5DmkII, 7D, 40D, 50D,
        60D, 450D, 500D, 550D, 1000D and 1100D.
    },
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0x3f, 0xa8 ],
    DATAMEMBER => [ 0x00 ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            2 => '2 (1DmkIII)',
            3 => '3 (40D)', # (doesn't record SpecularWhiteLevel, ref github#233)
            4 => '4 (1DSmkIII)',
            5 => '5 (450D/1000D)',
            6 => '6 (50D/5DmkII)',
            7 => '7 (500D/550D/7D/1DmkIV)',
            9 => '9 (60D/1100D)',
        },
    },
    # 0x01-0x18: unknown RGGB coefficients (int16s[4]) (50D)
    # (dcraw 8.81 uses index 0x3f for WB)
    0x3f => {
        Name => 'ColorCoefs',
        Format => 'undef[210]', # ColorTempUnknown11 is last entry
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCoefs' }
    },
    0xa8 => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x0e7 => { Name => 'AverageBlackLevel',     Format => 'int16u[4]' }, #IB
    0x280 => { #PH
        Name => 'RawMeasuredRGGB',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
    0x2b4 => { #IB
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == 4 or $$self{ColorDataVersion} == 5',
        Format => 'int16u[4]',
    },
    0x2b8 => { #IB
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 4 or $$self{ColorDataVersion} == 5',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x2b9 => { #IB
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 4 or $$self{ColorDataVersion} == 5',
        Format => 'int16u',
    },
    0x2ba => { #IB
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} == 4 or $$self{ColorDataVersion} == 5',
        Format => 'int16u',
    },
    0x2cb => { #IB
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == 6 or $$self{ColorDataVersion} == 7',
        Format => 'int16u[4]',
    },
    0x2cf => [{ #IB
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 6 or $$self{ColorDataVersion} == 7',
        Format => 'int16u',
        RawConv => '$val || undef',
    },{
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == 9',
        Format => 'int16u[4]',
    }],
    0x2d0 => { #IB
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 6 or $$self{ColorDataVersion} == 7',
        Format => 'int16u',
    },
    0x2d1 => { #IB
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} == 6 or $$self{ColorDataVersion} == 7',
        Format => 'int16u',
    },
    0x2d3 => { #IB
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 9',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x2d4 => { #IB
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 9',
        Format => 'int16u',
    },
    0x2d5 => { #IB
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} == 9',
        Format => 'int16u',
    },
);

# color coefficients (ref PH)
%Image::ExifTool::Canon::ColorCoefs = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x04 => 'ColorTempAsShot',
    0x05 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x09 => 'ColorTempAuto',
    0x0a => { Name => 'WB_RGGBLevelsMeasured',    Format => 'int16s[4]' },
    0x0e => 'ColorTempMeasured',
    # the following Unknown values are set for the 50D and 5DmkII, and the
    # SRAW images of the 40D, and affect thumbnail display for the 50D/5DmkII
    # and conversion for all modes of the 40D
    0x0f => { Name => 'WB_RGGBLevelsUnknown',     Format => 'int16s[4]', Unknown => 1 },
    0x13 => { Name => 'ColorTempUnknown', Unknown => 1 },
    0x14 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x18 => 'ColorTempDaylight',
    0x19 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x1d => 'ColorTempShade',
    0x1e => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x22 => 'ColorTempCloudy',
    0x23 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x27 => 'ColorTempTungsten',
    0x28 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x2c => 'ColorTempFluorescent',
    # (changing the Kelvin values has no effect on image in DPP... why not?)
    0x2d => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x31 => 'ColorTempKelvin',
    0x32 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x36 => 'ColorTempFlash',
    0x37 => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x3b => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x3c => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x40 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x41 => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x45 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x46 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x4a => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x4b => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x4f => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x50 => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x54 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x55 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x59 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x5a => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x5e => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x5f => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x63 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x64 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0x68 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0x69 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0x6d => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0x6e => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0x72 => { Name => 'ColorTempUnknown13', Unknown => 1 },
);

# color coefficients (ref PH/IB)
%Image::ExifTool::Canon::ColorCoefs2 = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => { Name => 'WB_RGGBLevelsAsShot',      Format => 'int16s[4]' },
    0x07 => 'ColorTempAsShot',
    0x08 => { Name => 'WB_RGGBLevelsAuto',        Format => 'int16s[4]' },
    0x0f => 'ColorTempAuto',
    0x10 => { Name => 'WB_RGGBLevelsMeasured',    Format => 'int16s[4]' },
    0x17 => 'ColorTempMeasured',
    0x18 => { Name => 'WB_RGGBLevelsUnknown',     Format => 'int16s[4]', Unknown => 1 },
    0x1f => { Name => 'ColorTempUnknown', Unknown => 1 },
    0x20 => { Name => 'WB_RGGBLevelsDaylight',    Format => 'int16s[4]' },
    0x27 => 'ColorTempDaylight',
    0x28 => { Name => 'WB_RGGBLevelsShade',       Format => 'int16s[4]' },
    0x2f => 'ColorTempShade',
    0x30 => { Name => 'WB_RGGBLevelsCloudy',      Format => 'int16s[4]' },
    0x37 => 'ColorTempCloudy',
    0x38 => { Name => 'WB_RGGBLevelsTungsten',    Format => 'int16s[4]' },
    0x3f => 'ColorTempTungsten',
    0x40 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x47 => 'ColorTempFluorescent',
    0x48 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x4f => 'ColorTempKelvin',
    0x50 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x57 => 'ColorTempFlash',
    0x58 => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x5f => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x60 => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x67 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x68 => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x6f => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x70 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x77 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x78 => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x7f => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x80 => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x87 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x88 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x8f => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x90 => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x97 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x98 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x9f => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0xa0 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xa7 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xa8 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xaf => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xb0 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xb7 => { Name => 'ColorTempUnknown13', Unknown => 1 },
);

# color calibration (ref 37)
%Image::ExifTool::Canon::ColorCalib = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # these coefficients are in a different order compared to older
    # models (A,B,C in ColorData1/2 vs. C,A,B in ColorData3/4) - PH
    # Coefficient A most closely matches the blue curvature, and
    # coefficient B most closely matches the red curvature, but the match
    # is not perfect, and I don't know what coefficient C is for (certainly
    # not a green coefficient) - PH
    NOTES => q{
        Camera color calibration data.  For the 20D, 350D, 1DmkII and 1DSmkII the
        order of the coefficients is A, B, C, Temperature, but for newer models it
        is B, C, A, Temperature.  These tags are extracted only when the L<Unknown|../ExifTool.html#Unknown>
        option is used.
    },
    0x00 => { Name => 'CameraColorCalibration01', %cameraColorCalibration },
    0x04 => { Name => 'CameraColorCalibration02', %cameraColorCalibration },
    0x08 => { Name => 'CameraColorCalibration03', %cameraColorCalibration },
    0x0c => { Name => 'CameraColorCalibration04', %cameraColorCalibration },
    0x10 => { Name => 'CameraColorCalibration05', %cameraColorCalibration },
    0x14 => { Name => 'CameraColorCalibration06', %cameraColorCalibration },
    0x18 => { Name => 'CameraColorCalibration07', %cameraColorCalibration },
    0x1c => { Name => 'CameraColorCalibration08', %cameraColorCalibration },
    0x20 => { Name => 'CameraColorCalibration09', %cameraColorCalibration },
    0x24 => { Name => 'CameraColorCalibration10', %cameraColorCalibration },
    0x28 => { Name => 'CameraColorCalibration11', %cameraColorCalibration },
    0x2c => { Name => 'CameraColorCalibration12', %cameraColorCalibration },
    0x30 => { Name => 'CameraColorCalibration13', %cameraColorCalibration },
    0x34 => { Name => 'CameraColorCalibration14', %cameraColorCalibration },
    0x38 => { Name => 'CameraColorCalibration15', %cameraColorCalibration },
);

# color calibration2
%Image::ExifTool::Canon::ColorCalib2 = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'B, C, A, D, Temperature.',
    0x00 => { Name => 'CameraColorCalibration01', %cameraColorCalibration2 },
    0x05 => { Name => 'CameraColorCalibration02', %cameraColorCalibration2 },
    0x0a => { Name => 'CameraColorCalibration03', %cameraColorCalibration2 },
    0x0f => { Name => 'CameraColorCalibration04', %cameraColorCalibration2 },
    0x14 => { Name => 'CameraColorCalibration05', %cameraColorCalibration2 },
    0x19 => { Name => 'CameraColorCalibration06', %cameraColorCalibration2 },
    0x1e => { Name => 'CameraColorCalibration07', %cameraColorCalibration2 },
    0x23 => { Name => 'CameraColorCalibration08', %cameraColorCalibration2 },
    0x28 => { Name => 'CameraColorCalibration09', %cameraColorCalibration2 },
    0x2d => { Name => 'CameraColorCalibration10', %cameraColorCalibration2 },
    0x32 => { Name => 'CameraColorCalibration11', %cameraColorCalibration2 },
    0x37 => { Name => 'CameraColorCalibration12', %cameraColorCalibration2 },
    0x3c => { Name => 'CameraColorCalibration13', %cameraColorCalibration2 },
    0x41 => { Name => 'CameraColorCalibration14', %cameraColorCalibration2 },
    0x46 => { Name => 'CameraColorCalibration15', %cameraColorCalibration2 },
);

# Color data (MakerNotes tag 0x4001, count=5120) (ref PH)
%Image::ExifTool::Canon::ColorData5 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by many EOS M and PowerShot models.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0x00 ],
    IS_SUBDIR => [ 0x47, 0xba, 0xff ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            -3 => '-3 (M10/M3)', # (and PowerShot G1X/G1XmkII/G10/G11/G12/G15/G16/G3X/G5X/G7X/G9X/S100/S110/S120/S90/S95/SX1IS/SX50HS/SX60HS)
            -4 => '-4 (M100/M5/M6)', # (and PowerShot G1XmkIII/G7XmkII/G9XmkII)
        },
    },
    0x47 => [{
        Name => 'ColorCoefs',
        Condition => '$$self{ColorDataVersion} == -3',
        Format => 'undef[230]', # ColorTempUnknown13 is last entry
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCoefs' }
    },{
        Name => 'ColorCoefs2',
        Condition => '$$self{ColorDataVersion} == -4',
        Format => 'undef[368]',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCoefs2' }
    }],
    0xba => {
        Name => 'ColorCalib2',
        Condition => '$$self{ColorDataVersion} == -3',
        Format => 'undef[150]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib2' }
    },
    0xff => {
        Name => 'ColorCalib2',
        Condition => '$$self{ColorDataVersion} == -4',
        Format => 'undef[150]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib2' }
    },
    0x108=> { #IB
        Name => 'PerChannelBlackLevel', # (or perhaps AverageBlackLevel?, ref github#232)
        Condition => '$$self{ColorDataVersion} == -3',
        Format => 'int16s[4]',
    },
    0x296 => { #github#232
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == -3',
        Format => 'int16u',
    },
    0x14d=> { #IB
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == -4',
        Format => 'int16s[4]',
    },
    0x0569 => { #PH (NC)
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == -4',
        Format => 'int16u',
    },
    0x056a => { #PH (NC)
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == -4',
        Format => 'int16u',
    },
);

# Color data (MakerNotes tag 0x4001, count=1273|1275) (ref PH)
%Image::ExifTool::Canon::ColorData6 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the EOS 600D and 1200D.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 0xbc ],
    0x00 => {
        Name => 'ColorDataVersion',
        PrintConv => {
            10 => '10 (600D/1200D)',
        },
    },
    0x3f => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x43 => 'ColorTempAsShot',
    0x44 => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x48 => 'ColorTempAuto',
    0x49 => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x4d => 'ColorTempMeasured',
    0x4e => { Name => 'WB_RGGBLevelsUnknown',    Format => 'int16s[4]', Unknown => 1 },
    0x52 => { Name => 'ColorTempUnknown', Unknown => 1 },
    0x53 => { Name => 'WB_RGGBLevelsUnknown2',   Format => 'int16s[4]', Unknown => 1 },
    0x57 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x58 => { Name => 'WB_RGGBLevelsUnknown3',   Format => 'int16s[4]', Unknown => 1 },
    0x5c => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x5d => { Name => 'WB_RGGBLevelsUnknown4',   Format => 'int16s[4]', Unknown => 1 },
    0x61 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x62 => { Name => 'WB_RGGBLevelsUnknown5',   Format => 'int16s[4]', Unknown => 1 },
    0x66 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x67 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x6b => 'ColorTempDaylight',
    0x6c => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x70 => 'ColorTempShade',
    0x71 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x75 => 'ColorTempCloudy',
    0x76 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x7a => 'ColorTempTungsten',
    0x7b => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x7f => 'ColorTempFluorescent',
    0x80 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x84 => 'ColorTempKelvin',
    0x85 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0x89 => 'ColorTempFlash',
    0x8a => { Name => 'WB_RGGBLevelsUnknown6',   Format => 'int16s[4]', Unknown => 1 },
    0x8e => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x8f => { Name => 'WB_RGGBLevelsUnknown7',   Format => 'int16s[4]', Unknown => 1 },
    0x93 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x94 => { Name => 'WB_RGGBLevelsUnknown8',   Format => 'int16s[4]', Unknown => 1 },
    0x98 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x99 => { Name => 'WB_RGGBLevelsUnknown9',   Format => 'int16s[4]', Unknown => 1 },
    0x9d => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x9e => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0xa2 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0xa3 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xa7 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xa8 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xac => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xad => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xb1 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xb2 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xb6 => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xb7 => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xbb => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xbc => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x0fb => { Name => 'AverageBlackLevel',     Format => 'int16u[4]' }, #IB
    0x194 => { #PH
        Name => 'RawMeasuredRGGB',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
    0x1df => { Name => 'PerChannelBlackLevel',  Format => 'int16u[4]' }, #IB
    0x1e3 => { Name => 'NormalWhiteLevel',      Format => 'int16u',  RawConv => '$val || undef' }, #IB
    0x1e4 => { Name => 'SpecularWhiteLevel',    Format => 'int16u' }, #IB
    0x1e5 => { Name => 'LinearityUpperMargin',  Format => 'int16u' }, #IB
);

# Color data (MakerNotes tag 0x4001, count=1312,1313,1316) (ref PH)
%Image::ExifTool::Canon::ColorData7 = (
    %binaryDataAttrs,
    NOTES => q{
        These tags are used by the EOS 1DX, 5DmkIII, 6D, 7DmkII, 100D, 650D, 700D,
        8000D, M and M2.
    },
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0x00 ],
    IS_SUBDIR => [ 0xd5 ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            10 => '10 (1DX/5DmkIII/6D/70D/100D/650D/700D/M/M2)',
            11 => '11 (7DmkII/750D/760D/8000D)',
        },
    },
    # not really sure about the AsShot, Auto and Measured values any more - PH
    0x3f => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x43 => 'ColorTempAsShot',
    0x44 => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x48 => 'ColorTempAuto',
    0x49 => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x4d => 'ColorTempMeasured',
    0x4e => { Name => 'WB_RGGBLevelsUnknown',   Format => 'int16s[4]', Unknown => 1 },
    0x52 => { Name => 'ColorTempUnknown',  Unknown => 1 },
    0x53 => { Name => 'WB_RGGBLevelsUnknown2',  Format => 'int16s[4]', Unknown => 1 },
    0x57 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x58 => { Name => 'WB_RGGBLevelsUnknown3',  Format => 'int16s[4]', Unknown => 1 },
    0x5c => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x5d => { Name => 'WB_RGGBLevelsUnknown4',  Format => 'int16s[4]', Unknown => 1 },
    0x61 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x62 => { Name => 'WB_RGGBLevelsUnknown5',  Format => 'int16s[4]', Unknown => 1 },
    0x66 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x67 => { Name => 'WB_RGGBLevelsUnknown6',  Format => 'int16s[4]', Unknown => 1 },
    0x6b => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x6c => { Name => 'WB_RGGBLevelsUnknown7',  Format => 'int16s[4]', Unknown => 1 },
    0x70 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x71 => { Name => 'WB_RGGBLevelsUnknown8',  Format => 'int16s[4]', Unknown => 1 },
    0x75 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x76 => { Name => 'WB_RGGBLevelsUnknown9',  Format => 'int16s[4]', Unknown => 1 },
    0x7a => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x7b => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x7f => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x80 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x84 => 'ColorTempDaylight',
    0x85 => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x89 => 'ColorTempShade',
    0x8a => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x8e => 'ColorTempCloudy',
    0x8f => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x93 => 'ColorTempTungsten',
    0x94 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x98 => 'ColorTempFluorescent',
    0x99 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0x9d => 'ColorTempKelvin',
    0x9e => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0xa2 => 'ColorTempFlash',
    0xa3 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xa7 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xa8 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xac => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xad => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xb1 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xb2 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xb6 => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xb7 => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xbb => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xbc => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xc0 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xc1 => { Name => 'WB_RGGBLevelsUnknown17',  Format => 'int16s[4]', Unknown => 1 },
    0xc5 => { Name => 'ColorTempUnknown17', Unknown => 1 },
    0xc6 => { Name => 'WB_RGGBLevelsUnknown18',  Format => 'int16s[4]', Unknown => 1 },
    0xca => { Name => 'ColorTempUnknown18', Unknown => 1 },
    0xcb => { Name => 'WB_RGGBLevelsUnknown19',  Format => 'int16s[4]', Unknown => 1 },
    0xcf => { Name => 'ColorTempUnknown19', Unknown => 1 },
    0xd0 => { Name => 'WB_RGGBLevelsUnknown20',  Format => 'int16s[4]', Unknown => 1 },
    0xd4 => { Name => 'ColorTempUnknown20', Unknown => 1 },
    0xd5 => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x114 => { Name => 'AverageBlackLevel',     Format => 'int16u[4]' }, #IB
    0x1ad => {
        Name => 'RawMeasuredRGGB',
        Condition => '$$self{ColorDataVersion} == 10',
        Format => 'int32u[4]',
        Notes => 'raw MeasuredRGGB values, before normalization',
        # swap words because the word ordering is big-endian, opposite to the byte ordering
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
    0x1f8 => { #IB
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == 10',
        Format => 'int16u[4]',
    },
    0x1fc => { #IB
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 10',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x1fd => { #IB
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 10',
        Format => 'int16u',
    },
    0x1fe => { #IB
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} == 10',
        Format => 'int16u',
    },
    0x26b => {
        Name => 'RawMeasuredRGGB',
        Condition => '$$self{ColorDataVersion} == 11',
        Format => 'int32u[4]',
        ValueConv => \&SwapWords,
        ValueConvInv => \&SwapWords,
    },
    0x2d8 => {
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == 11',
        Format => 'int16u[4]',
    },
    0x2dc => {
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 11',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x2dd => {
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 11',
        Format => 'int16u',
    },
    0x2de => {
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} == 11',
        Format => 'int16u',
    },
);

# Color data (MakerNotes tag 0x4001, count=1560,etc) (ref IB)
%Image::ExifTool::Canon::ColorData8 = (
    %binaryDataAttrs,
    NOTES => q{
        These tags are used by the EOS 1DXmkII, 5DS, 5DSR, 5DmkIV, 6DmkII, 77D, 80D,
        200D, 800D, 1300D, 2000D, 4000D and 9000D.
    },
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    IS_SUBDIR => [ 0x107 ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            12 => '12 (1DXmkII/5DS/5DSR)',
            13 => '13 (80D/5DmkIV)', #PH
            14 => '14 (1300D/2000D/4000D)', #IB
            15 => '15 (6DmkII/77D/200D/800D,9000D)', #IB
        },
    },
    0x3f => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x43 => 'ColorTempAsShot',
    0x44 => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x48 => 'ColorTempAuto',
    0x49 => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x4d => 'ColorTempMeasured',
    0x4e => { Name => 'WB_RGGBLevelsUnknown',   Format => 'int16s[4]', Unknown => 1 },
    0x52 => { Name => 'ColorTempUnknown',  Unknown => 1 },
    0x53 => { Name => 'WB_RGGBLevelsUnknown2',  Format => 'int16s[4]', Unknown => 1 },
    0x57 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x58 => { Name => 'WB_RGGBLevelsUnknown3',  Format => 'int16s[4]', Unknown => 1 },
    0x5c => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x5d => { Name => 'WB_RGGBLevelsUnknown4',  Format => 'int16s[4]', Unknown => 1 },
    0x61 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x62 => { Name => 'WB_RGGBLevelsUnknown5',  Format => 'int16s[4]', Unknown => 1 },
    0x66 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x67 => { Name => 'WB_RGGBLevelsUnknown6',  Format => 'int16s[4]', Unknown => 1 },
    0x6b => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x6c => { Name => 'WB_RGGBLevelsUnknown7',  Format => 'int16s[4]', Unknown => 1 },
    0x70 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x71 => { Name => 'WB_RGGBLevelsUnknown8',  Format => 'int16s[4]', Unknown => 1 },
    0x75 => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x76 => { Name => 'WB_RGGBLevelsUnknown9',  Format => 'int16s[4]', Unknown => 1 },
    0x7a => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x7b => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x7f => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x80 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0x84 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0x85 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x89 => 'ColorTempDaylight',
    0x8a => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x8e => 'ColorTempShade',
    0x8f => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x93 => 'ColorTempCloudy',
    0x94 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x98 => 'ColorTempTungsten',
    0x99 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0x9d => 'ColorTempFluorescent',
    0x9e => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0xa2 => 'ColorTempKelvin',
    0xa3 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0xa7 => 'ColorTempFlash',
    0xa8 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xac => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xad => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xb1 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xb2 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xb6 => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xb7 => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xbb => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xbc => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xc0 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xc1 => { Name => 'WB_RGGBLevelsUnknown17',  Format => 'int16s[4]', Unknown => 1 },
    0xc5 => { Name => 'ColorTempUnknown17', Unknown => 1 },
    0xc6 => { Name => 'WB_RGGBLevelsUnknown18',  Format => 'int16s[4]', Unknown => 1 },
    0xca => { Name => 'ColorTempUnknown18', Unknown => 1 },
    0xcb => { Name => 'WB_RGGBLevelsUnknown19',  Format => 'int16s[4]', Unknown => 1 },
    0xcf => { Name => 'ColorTempUnknown19', Unknown => 1 },
    0xd0 => { Name => 'WB_RGGBLevelsUnknown20',  Format => 'int16s[4]', Unknown => 1 },
    0xd4 => { Name => 'ColorTempUnknown20', Unknown => 1 },
    0xd5 => { Name => 'WB_RGGBLevelsUnknown21',  Format => 'int16s[4]', Unknown => 1 },
    0xd9 => { Name => 'ColorTempUnknown21', Unknown => 1 },
    0xda => { Name => 'WB_RGGBLevelsUnknown22',  Format => 'int16s[4]', Unknown => 1 },
    0xde => { Name => 'ColorTempUnknown22', Unknown => 1 },
    0xdf => { Name => 'WB_RGGBLevelsUnknown23',  Format => 'int16s[4]', Unknown => 1 },
    0xe3 => { Name => 'ColorTempUnknown23', Unknown => 1 },
    0xe4 => { Name => 'WB_RGGBLevelsUnknown24',  Format => 'int16s[4]', Unknown => 1 },
    0xe8 => { Name => 'ColorTempUnknown24', Unknown => 1 },
    0xe9 => { Name => 'WB_RGGBLevelsUnknown25',  Format => 'int16s[4]', Unknown => 1 },
    0xed => { Name => 'ColorTempUnknown25', Unknown => 1 },
    0xee => { Name => 'WB_RGGBLevelsUnknown26',  Format => 'int16s[4]', Unknown => 1 },
    0xf2 => { Name => 'ColorTempUnknown26', Unknown => 1 },
    0xf3 => { Name => 'WB_RGGBLevelsUnknown27',  Format => 'int16s[4]', Unknown => 1 },
    0xf7 => { Name => 'ColorTempUnknown27', Unknown => 1 },
    0xf8 => { Name => 'WB_RGGBLevelsUnknown28',  Format => 'int16s[4]', Unknown => 1 },
    0xfc => { Name => 'ColorTempUnknown28', Unknown => 1 },
    0xfd => { Name => 'WB_RGGBLevelsUnknown29',  Format => 'int16s[4]', Unknown => 1 },
    0x101 => { Name => 'ColorTempUnknown29', Unknown => 1 },
    0x102 => { Name => 'WB_RGGBLevelsUnknown30',  Format => 'int16s[4]', Unknown => 1 },
    0x106 => { Name => 'ColorTempUnknown30', Unknown => 1 },

    0x107 => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        Notes => 'B, C, A, Temperature',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x146 => { Name => 'AverageBlackLevel', Format => 'int16u[4]' },
    0x22c => {
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} == 14',
        Format => 'int16u[4]',
        Notes => '1300D',
    },
    0x230 => {
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 14',
        Format => 'int16u',
        Notes => '1300D',
        RawConv => '$val || undef',
    },
    0x231 => {
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} == 14',
        Format => 'int16u',
        Notes => '1300D',
    },
    0x232 => {
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} == 14',
        Format => 'int16u',
        Notes => '1300D',
    },
    0x30a => {
        Name => 'PerChannelBlackLevel',
        Condition => '$$self{ColorDataVersion} < 14 or $$self{ColorDataVersion} == 15',
        Format => 'int16u[4]',
        Notes => '5DS, 5DS R, 77D, 80D and 800D',
    },
    0x30e => {
        Name => 'NormalWhiteLevel',
        Condition => '$$self{ColorDataVersion} < 14 or $$self{ColorDataVersion} == 15',
        Format => 'int16u',
        Notes => '5DS, 5DS R, 77D, 80D and 800D',
        RawConv => '$val || undef',
    },
    0x30f => {
        Name => 'SpecularWhiteLevel',
        Condition => '$$self{ColorDataVersion} < 14 or $$self{ColorDataVersion} == 15',
        Format => 'int16u',
        Notes => '5DS, 5DS R, 77D, 80D and 800D',
    },
    0x310 => {
        Name => 'LinearityUpperMargin',
        Condition => '$$self{ColorDataVersion} < 14 or $$self{ColorDataVersion} == 15',
        Format => 'int16u',
        Notes => '5DS, 5DS R, 77D, 80D and 800D',
    },
);

# Color data (MakerNotes tag 0x4001, count=1820,etc) (ref PH)
%Image::ExifTool::Canon::ColorData9 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the M6mkII, M50, M200, EOS R, RP, 90D, 250D and 850D',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    IS_SUBDIR => [ 0x10a ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            16 => '16 (M50)',
            17 => '17 (R)',         # (and PowerShot SX740HS)
            18 => '18 (RP/250D)',   # (and PowerShot SX70HS)
            19 => '19 (90D/850D/M6mkII/M200)',# (and PowerShot G7XmkIII)
        },
    },
    0x47 => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x4b => 'ColorTempAsShot',
    0x4c => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x50 => 'ColorTempAuto',
    0x51 => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x55 => 'ColorTempMeasured',
    0x56 => { Name => 'WB_RGGBLevelsUnknown',   Format => 'int16s[4]', Unknown => 1 },
    0x5a => { Name => 'ColorTempUnknown',  Unknown => 1 },
    0x5b => { Name => 'WB_RGGBLevelsUnknown2',  Format => 'int16s[4]', Unknown => 1 },
    0x5f => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x60 => { Name => 'WB_RGGBLevelsUnknown3',  Format => 'int16s[4]', Unknown => 1 },
    0x64 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x65 => { Name => 'WB_RGGBLevelsUnknown4',  Format => 'int16s[4]', Unknown => 1 },
    0x69 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x6a => { Name => 'WB_RGGBLevelsUnknown5',  Format => 'int16s[4]', Unknown => 1 },
    0x6e => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x6f => { Name => 'WB_RGGBLevelsUnknown6',  Format => 'int16s[4]', Unknown => 1 },
    0x73 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x74 => { Name => 'WB_RGGBLevelsUnknown7',  Format => 'int16s[4]', Unknown => 1 },
    0x78 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x79 => { Name => 'WB_RGGBLevelsUnknown8',  Format => 'int16s[4]', Unknown => 1 },
    0x7d => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x7e => { Name => 'WB_RGGBLevelsUnknown9',  Format => 'int16s[4]', Unknown => 1 },
    0x82 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x83 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x87 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x88 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x8c => 'ColorTempDaylight',
    0x8d => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x91 => 'ColorTempShade',
    0x92 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0x96 => 'ColorTempCloudy',
    0x97 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0x9b => 'ColorTempTungsten',
    0x9c => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0xa0 => 'ColorTempFluorescent',
    0xa1 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0xa5 => 'ColorTempKelvin',
    0xa6 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0xaa => 'ColorTempFlash',
    0xab => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xaf => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xb0 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xb4 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xb5 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xb9 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xba => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xbe => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xbf => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xc3 => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xc4 => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xc8 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xc9 => { Name => 'WB_RGGBLevelsUnknown17',  Format => 'int16s[4]', Unknown => 1 },
    0xcd => { Name => 'ColorTempUnknown17', Unknown => 1 },
    0xce => { Name => 'WB_RGGBLevelsUnknown18',  Format => 'int16s[4]', Unknown => 1 },
    0xd2 => { Name => 'ColorTempUnknown18', Unknown => 1 },
    0xd3 => { Name => 'WB_RGGBLevelsUnknown19',  Format => 'int16s[4]', Unknown => 1 },
    0xd7 => { Name => 'ColorTempUnknown19', Unknown => 1 },
    0xd8 => { Name => 'WB_RGGBLevelsUnknown20',  Format => 'int16s[4]', Unknown => 1 },
    0xdc => { Name => 'ColorTempUnknown20', Unknown => 1 },
    0xdd => { Name => 'WB_RGGBLevelsUnknown21',  Format => 'int16s[4]', Unknown => 1 },
    0xe1 => { Name => 'ColorTempUnknown21', Unknown => 1 },
    0xe2 => { Name => 'WB_RGGBLevelsUnknown22',  Format => 'int16s[4]', Unknown => 1 },
    0xe6 => { Name => 'ColorTempUnknown22', Unknown => 1 },
    0xe7 => { Name => 'WB_RGGBLevelsUnknown23',  Format => 'int16s[4]', Unknown => 1 },
    0xeb => { Name => 'ColorTempUnknown23', Unknown => 1 },
    0xec => { Name => 'WB_RGGBLevelsUnknown24',  Format => 'int16s[4]', Unknown => 1 },
    0xf0 => { Name => 'ColorTempUnknown24', Unknown => 1 },
    0xf1 => { Name => 'WB_RGGBLevelsUnknown25',  Format => 'int16s[4]', Unknown => 1 },
    0xf5 => { Name => 'ColorTempUnknown25', Unknown => 1 },
    0xf6 => { Name => 'WB_RGGBLevelsUnknown26',  Format => 'int16s[4]', Unknown => 1 },
    0xfa => { Name => 'ColorTempUnknown26', Unknown => 1 },
    0xfb => { Name => 'WB_RGGBLevelsUnknown27',  Format => 'int16s[4]', Unknown => 1 },
    0xff => { Name => 'ColorTempUnknown27', Unknown => 1 },
    0x100=> { Name => 'WB_RGGBLevelsUnknown28',  Format => 'int16s[4]', Unknown => 1 },
    0x104=> { Name => 'ColorTempUnknown28', Unknown => 1 },
    0x105=> { Name => 'WB_RGGBLevelsUnknown29',  Format => 'int16s[4]', Unknown => 1 },
    0x109=> { Name => 'ColorTempUnknown29', Unknown => 1 },
    0x10a => { #IB
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x149 => { #IB
        Name => 'PerChannelBlackLevel',
        Format => 'int16u[4]',
    },
    # 0x318 - PerChannelBlackLevel again (ref IB)
    0x31c => { #IB
        Name => 'NormalWhiteLevel',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x31d => { #IB
        Name => 'SpecularWhiteLevel',
        Format => 'int16u',
    },
    0x31e => { #IB
        Name => 'LinearityUpperMargin',
        Format => 'int16u',
    },
);

# Color data (MakerNotes tag 0x4001, count=2024,3656)
# (same as ColorData9 but shifted up by 0x0e, ref PH)
%Image::ExifTool::Canon::ColorData10 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the R5, R5 and EOS 1DXmkIII.',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    IS_SUBDIR => [ 0x118 ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            32 => '32 (1DXmkIII)', #IB
            33 => '33 (R5/R6)',
        },
    },
    0x55 => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x59 => 'ColorTempAsShot',
    0x5a => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x5e => 'ColorTempAuto',
    0x5f => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x63 => 'ColorTempMeasured',
    0x64 => { Name => 'WB_RGGBLevelsUnknown',   Format => 'int16s[4]', Unknown => 1 },
    0x68 => { Name => 'ColorTempUnknown',  Unknown => 1 },
    0x69 => { Name => 'WB_RGGBLevelsUnknown2',  Format => 'int16s[4]', Unknown => 1 },
    0x6d => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x6e => { Name => 'WB_RGGBLevelsUnknown3',  Format => 'int16s[4]', Unknown => 1 },
    0x72 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x73 => { Name => 'WB_RGGBLevelsUnknown4',  Format => 'int16s[4]', Unknown => 1 },
    0x77 => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x78 => { Name => 'WB_RGGBLevelsUnknown5',  Format => 'int16s[4]', Unknown => 1 },
    0x7c => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x7d => { Name => 'WB_RGGBLevelsUnknown6',  Format => 'int16s[4]', Unknown => 1 },
    0x81 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x82 => { Name => 'WB_RGGBLevelsUnknown7',  Format => 'int16s[4]', Unknown => 1 },
    0x86 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x87 => { Name => 'WB_RGGBLevelsUnknown8',  Format => 'int16s[4]', Unknown => 1 },
    0x8b => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0x8c => { Name => 'WB_RGGBLevelsUnknown9',  Format => 'int16s[4]', Unknown => 1 },
    0x90 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0x91 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0x95 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0x96 => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0x9a => 'ColorTempDaylight',
    0x9b => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0x9f => 'ColorTempShade',
    0xa0 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0xa4 => 'ColorTempCloudy',
    0xa5 => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0xa9 => 'ColorTempTungsten',
    0xaa => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0xae => 'ColorTempFluorescent',
    0xaf => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0xb3 => 'ColorTempKelvin',
    0xb4 => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0xb8 => 'ColorTempFlash',
    0xb9 => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xbd => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xbe => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xc2 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xc3 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xc7 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xc8 => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xcc => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xcd => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xd1 => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xd2 => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xd6 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xd7 => { Name => 'WB_RGGBLevelsUnknown17',  Format => 'int16s[4]', Unknown => 1 },
    0xdb => { Name => 'ColorTempUnknown17', Unknown => 1 },
    0xdc => { Name => 'WB_RGGBLevelsUnknown18',  Format => 'int16s[4]', Unknown => 1 },
    0xe0 => { Name => 'ColorTempUnknown18', Unknown => 1 },
    0xe1 => { Name => 'WB_RGGBLevelsUnknown19',  Format => 'int16s[4]', Unknown => 1 },
    0xe5 => { Name => 'ColorTempUnknown19', Unknown => 1 },
    0xe6 => { Name => 'WB_RGGBLevelsUnknown20',  Format => 'int16s[4]', Unknown => 1 },
    0xea => { Name => 'ColorTempUnknown20', Unknown => 1 },
    0xeb => { Name => 'WB_RGGBLevelsUnknown21',  Format => 'int16s[4]', Unknown => 1 },
    0xef => { Name => 'ColorTempUnknown21', Unknown => 1 },
    0xf0 => { Name => 'WB_RGGBLevelsUnknown22',  Format => 'int16s[4]', Unknown => 1 },
    0xf4 => { Name => 'ColorTempUnknown22', Unknown => 1 },
    0xf5 => { Name => 'WB_RGGBLevelsUnknown23',  Format => 'int16s[4]', Unknown => 1 },
    0xf9 => { Name => 'ColorTempUnknown23', Unknown => 1 },
    0xfa => { Name => 'WB_RGGBLevelsUnknown24',  Format => 'int16s[4]', Unknown => 1 },
    0xfe => { Name => 'ColorTempUnknown24', Unknown => 1 },
    0xff => { Name => 'WB_RGGBLevelsUnknown25',  Format => 'int16s[4]', Unknown => 1 },
    0x103=> { Name => 'ColorTempUnknown25', Unknown => 1 },
    0x104=> { Name => 'WB_RGGBLevelsUnknown26',  Format => 'int16s[4]', Unknown => 1 },
    0x108=> { Name => 'ColorTempUnknown26', Unknown => 1 },
    0x109=> { Name => 'WB_RGGBLevelsUnknown27',  Format => 'int16s[4]', Unknown => 1 },
    0x10d=> { Name => 'ColorTempUnknown27', Unknown => 1 },
    0x10e=> { Name => 'WB_RGGBLevelsUnknown28',  Format => 'int16s[4]', Unknown => 1 },
    0x112=> { Name => 'ColorTempUnknown28', Unknown => 1 },
    0x113=> { Name => 'WB_RGGBLevelsUnknown29',  Format => 'int16s[4]', Unknown => 1 },
    0x117=> { Name => 'ColorTempUnknown29', Unknown => 1 },
    0x118 => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x157 => {
        Name => 'PerChannelBlackLevel',
        Format => 'int16u[4]',
    },
    # 0x326 - PerChannelBlackLevel again
    0x32a => {
        Name => 'NormalWhiteLevel',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x32b => {
        Name => 'SpecularWhiteLevel',
        Format => 'int16u',
    },
    0x32c => {
        Name => 'LinearityUpperMargin',
        Format => 'int16u',
    },
);

# Color data (MakerNotes tag 0x4001, count=3973/3778, ref IB)
%Image::ExifTool::Canon::ColorData11 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the EOS R3, R7, R50 and R6mkII',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    IS_SUBDIR => [ 0x12c ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            34 => '34 (R3)', #IB
            48 => '48 (R7/R10/R50/R6mkII)', #IB
        },
    },
    0x69 => { Name => 'WB_RGGBLevelsAsShot',     Format => 'int16s[4]' },
    0x6d => 'ColorTempAsShot',
    0x6e => { Name => 'WB_RGGBLevelsAuto',       Format => 'int16s[4]' },
    0x72 => 'ColorTempAuto',
    0x73 => { Name => 'WB_RGGBLevelsMeasured',   Format => 'int16s[4]' },
    0x77 => 'ColorTempMeasured',
    0x78 => { Name => 'WB_RGGBLevelsUnknown',   Format => 'int16s[4]', Unknown => 1 },
    0x7c => { Name => 'ColorTempUnknown',  Unknown => 1 },
    0x7d => { Name => 'WB_RGGBLevelsUnknown2',  Format => 'int16s[4]', Unknown => 1 },
    0x81 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x82 => { Name => 'WB_RGGBLevelsUnknown3',  Format => 'int16s[4]', Unknown => 1 },
    0x86 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x87 => { Name => 'WB_RGGBLevelsUnknown4',  Format => 'int16s[4]', Unknown => 1 },
    0x8b => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x8c => { Name => 'WB_RGGBLevelsUnknown5',  Format => 'int16s[4]', Unknown => 1 },
    0x90 => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0x91 => { Name => 'WB_RGGBLevelsUnknown6',  Format => 'int16s[4]', Unknown => 1 },
    0x95 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0x96 => { Name => 'WB_RGGBLevelsUnknown7',  Format => 'int16s[4]', Unknown => 1 },
    0x9a => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0x9b => { Name => 'WB_RGGBLevelsUnknown8',  Format => 'int16s[4]', Unknown => 1 },
    0x9f => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0xa0 => { Name => 'WB_RGGBLevelsUnknown9',  Format => 'int16s[4]', Unknown => 1 },
    0xa4 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0xa5 => { Name => 'WB_RGGBLevelsUnknown10',  Format => 'int16s[4]', Unknown => 1 },
    0xa9 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0xaa => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xae => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xaf => { Name => 'WB_RGGBLevelsUnknown11',  Format => 'int16s[4]', Unknown => 1 },
    0xb3 => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xb4 => { Name => 'WB_RGGBLevelsUnknown12',  Format => 'int16s[4]', Unknown => 1 },
    0xb8 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xb9 => { Name => 'WB_RGGBLevelsUnknown13',  Format => 'int16s[4]', Unknown => 1 },
    0xbd => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xbe => { Name => 'WB_RGGBLevelsUnknown14',  Format => 'int16s[4]', Unknown => 1 },
    0xc2 => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xc3 => { Name => 'WB_RGGBLevelsUnknown15',  Format => 'int16s[4]', Unknown => 1 },
    0xc7 => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xc8 => { Name => 'WB_RGGBLevelsUnknown16',  Format => 'int16s[4]', Unknown => 1 },
    0xcc => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xcd => { Name => 'WB_RGGBLevelsDaylight',   Format => 'int16s[4]' },
    0xd1 => 'ColorTempDaylight',
    0xd2 => { Name => 'WB_RGGBLevelsShade',      Format => 'int16s[4]' },
    0xd6 => 'ColorTempShade',
    0xd7 => { Name => 'WB_RGGBLevelsCloudy',     Format => 'int16s[4]' },
    0xdb => 'ColorTempCloudy',
    0xdc => { Name => 'WB_RGGBLevelsTungsten',   Format => 'int16s[4]' },
    0xe0 => 'ColorTempTungsten',
    0xe1 => { Name => 'WB_RGGBLevelsFluorescent',Format => 'int16s[4]' },
    0xe5 => 'ColorTempFluorescent',
    0xe6 => { Name => 'WB_RGGBLevelsKelvin',     Format => 'int16s[4]' },
    0xea => 'ColorTempKelvin',
    0xeb => { Name => 'WB_RGGBLevelsFlash',      Format => 'int16s[4]' },
    0xef => 'ColorTempFlash',
    0xf0 => { Name => 'WB_RGGBLevelsUnknown17',  Format => 'int16s[4]', Unknown => 1 },
    0xf4 => { Name => 'ColorTempUnknown17', Unknown => 1 },
    0xf5 => { Name => 'WB_RGGBLevelsUnknown18',  Format => 'int16s[4]', Unknown => 1 },
    0xf9 => { Name => 'ColorTempUnknown18', Unknown => 1 },
    0xfa => { Name => 'WB_RGGBLevelsUnknown19',  Format => 'int16s[4]', Unknown => 1 },
    0xfe => { Name => 'ColorTempUnknown19', Unknown => 1 },
    0xff => { Name => 'WB_RGGBLevelsUnknown20',  Format => 'int16s[4]', Unknown => 1 },
    0x103 => { Name => 'ColorTempUnknown20', Unknown => 1 },
    0x104 => { Name => 'WB_RGGBLevelsUnknown21',  Format => 'int16s[4]', Unknown => 1 },
    0x108 => { Name => 'ColorTempUnknown21', Unknown => 1 },
    0x109 => { Name => 'WB_RGGBLevelsUnknown22',  Format => 'int16s[4]', Unknown => 1 },
    0x10d => { Name => 'ColorTempUnknown22', Unknown => 1 },
    0x10e => { Name => 'WB_RGGBLevelsUnknown23',  Format => 'int16s[4]', Unknown => 1 },
    0x112 => { Name => 'ColorTempUnknown23', Unknown => 1 },
    0x113 => { Name => 'WB_RGGBLevelsUnknown24',  Format => 'int16s[4]', Unknown => 1 },
    0x117 => { Name => 'ColorTempUnknown24', Unknown => 1 },
    0x118 => { Name => 'WB_RGGBLevelsUnknown25',  Format => 'int16s[4]', Unknown => 1 },
    0x11c => { Name => 'ColorTempUnknown25', Unknown => 1 },
    0x11d => { Name => 'WB_RGGBLevelsUnknown26',  Format => 'int16s[4]', Unknown => 1 },
    0x121 => { Name => 'ColorTempUnknown26', Unknown => 1 },
    0x122 => { Name => 'WB_RGGBLevelsUnknown27',  Format => 'int16s[4]', Unknown => 1 },
    0x126 => { Name => 'ColorTempUnknown27', Unknown => 1 },
    0x12c => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x16b => {
        Name => 'PerChannelBlackLevel',
        Format => 'int16u[4]',
    },
    # 0x27c - PerChannelBlackLevel again
    0x280 => {
        Name => 'NormalWhiteLevel',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x281 => {
        Name => 'SpecularWhiteLevel',
        Format => 'int16u',
    },
    0x282 => {
        Name => 'LinearityUpperMargin',
        Format => 'int16u',
    },
);

# Color data (MakerNotes tag 0x4001, count=4528/3778, ref PH)
%Image::ExifTool::Canon::ColorData12 = (
    %binaryDataAttrs,
    NOTES => 'These tags are used by the EOS R1, R5mkII and R50V',
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    IS_SUBDIR => [ 0x140 ],
    0x00 => {
        Name => 'ColorDataVersion',
        DataMember => 'ColorDataVersion',
        RawConv => '$$self{ColorDataVersion} = $val',
        PrintConv => {
            64 => '64 (R1/R5mkII)',
            65 => '65 (R50V)',
        },
    },
    0x69 => { Name => 'WB_RGGBLevelsAsShot',    Format => 'int16s[4]' }, # (NC)
    0x6d => 'ColorTempAsShot', # (NC)
    0x6e => { Name => 'WB_RGGBLevelsDaylight',  Format => 'int16s[4]' },
    0x72 => 'ColorTempDaylight',
    0x73 => { Name => 'WB_RGGBLevelsShade',     Format => 'int16s[4]' },
    0x77 => 'ColorTempShade',
    0x78 => { Name => 'WB_RGGBLevelsCloudy',    Format => 'int16s[4]' },
    0x7c => 'ColorTempCloudy',
    0x7d => { Name => 'WB_RGGBLevelsTungsten',  Format => 'int16s[4]' },
    0x81 => 'ColorTempTungsten',
    0x82 => { Name => 'WB_RGGBLevelsFluorescent',Format=> 'int16s[4]' },
    0x86 => 'ColorTempFluorescent' ,
    0x87 => { Name => 'WB_RGGBLevelsFlash',     Format => 'int16s[4]' },
    0x8b => 'ColorTempFlash',
    0x8c => { Name => 'WB_RGGBLevelsUnknown2',  Format => 'int16s[4]', Unknown => 1 },
    0x90 => { Name => 'ColorTempUnknown2', Unknown => 1 },
    0x91 => { Name => 'WB_RGGBLevelsUnknown3',  Format => 'int16s[4]', Unknown => 1 },
    0x95 => { Name => 'ColorTempUnknown3', Unknown => 1 },
    0x96 => { Name => 'WB_RGGBLevelsUnknown4',  Format => 'int16s[4]', Unknown => 1 },
    0x9a => { Name => 'ColorTempUnknown4', Unknown => 1 },
    0x9b => { Name => 'WB_RGGBLevelsUnknown5',  Format => 'int16s[4]', Unknown => 1 },
    0x9f => { Name => 'ColorTempUnknown5', Unknown => 1 },
    0xa0 => { Name => 'WB_RGGBLevelsUnknown6',  Format => 'int16s[4]', Unknown => 1 },
    0xa4 => { Name => 'ColorTempUnknown6', Unknown => 1 },
    0xa5 => { Name => 'WB_RGGBLevelsUnknown7',  Format => 'int16s[4]', Unknown => 1 },
    0xa9 => { Name => 'ColorTempUnknown7', Unknown => 1 },
    0xaa => { Name => 'WB_RGGBLevelsUnknown8',  Format => 'int16s[4]', Unknown => 1 },
    0xae => { Name => 'ColorTempUnknown8', Unknown => 1 },
    0xaf => { Name => 'WB_RGGBLevelsUnknown9',  Format => 'int16s[4]', Unknown => 1 },
    0xb3 => { Name => 'ColorTempUnknown9', Unknown => 1 },
    0xb4 => { Name => 'WB_RGGBLevelsUnknown10', Format => 'int16s[4]', Unknown => 1 },
    0xb8 => { Name => 'ColorTempUnknown10', Unknown => 1 },
    0xb9 => { Name => 'WB_RGGBLevelsUnknown11', Format => 'int16s[4]', Unknown => 1 },
    0xbd => { Name => 'ColorTempUnknown11', Unknown => 1 },
    0xbe => { Name => 'WB_RGGBLevelsUnknown12', Format => 'int16s[4]', Unknown => 1 },
    0xc2 => { Name => 'ColorTempUnknown12', Unknown => 1 },
    0xc3 => { Name => 'WB_RGGBLevelsUnknown13', Format => 'int16s[4]', Unknown => 1 },
    0xc7 => { Name => 'ColorTempUnknown13', Unknown => 1 },
    0xc8 => { Name => 'WB_RGGBLevelsUnknown14', Format => 'int16s[4]', Unknown => 1 },
    0xcc => { Name => 'ColorTempUnknown14', Unknown => 1 },
    0xcd => { Name => 'WB_RGGBLevelsUnknown15', Format => 'int16s[4]', Unknown => 1 },
    0xd1 => { Name => 'ColorTempUnknown15', Unknown => 1 },
    0xd2 => { Name => 'WB_RGGBLevelsUnknown16', Format => 'int16s[4]', Unknown => 1 },
    0xd6 => { Name => 'ColorTempUnknown16', Unknown => 1 },
    0xd7 => { Name => 'WB_RGGBLevelsUnknown17', Format => 'int16s[4]', Unknown => 1 },
    0xdb => { Name => 'ColorTempUnknown17', Unknown => 1 },
    0xdc => { Name => 'WB_RGGBLevelsUnknown18', Format => 'int16s[4]', Unknown => 1 },
    0xe0 => { Name => 'ColorTempUnknown18', Unknown => 1 },
    0xe1 => { Name => 'WB_RGGBLevelsUnknown19', Format => 'int16s[4]', Unknown => 1 },
    0xe5 => { Name => 'ColorTempUnknown19', Unknown => 1 },
    0xe6 => { Name => 'WB_RGGBLevelsUnknown20', Format => 'int16s[4]', Unknown => 1 },
    0xea => { Name => 'ColorTempUnknown20', Unknown => 1 },
    0xeb => { Name => 'WB_RGGBLevelsUnknown21', Format => 'int16s[4]', Unknown => 1 },
    0xef => { Name => 'ColorTempUnknown21', Unknown => 1 },
    0xf0 => { Name => 'WB_RGGBLevelsUnknown22', Format => 'int16s[4]', Unknown => 1 },
    0xf4 => { Name => 'ColorTempUnknown22', Unknown => 1 },
    0xf5 => { Name => 'WB_RGGBLevelsUnknown23', Format => 'int16s[4]', Unknown => 1 },
    0xf9 => { Name => 'ColorTempUnknown23', Unknown => 1 },
    0xfa => { Name => 'WB_RGGBLevelsUnknown24', Format => 'int16s[4]', Unknown => 1 },
    0xfe => { Name => 'ColorTempUnknown24', Unknown => 1 },
    0xff => { Name => 'WB_RGGBLevelsUnknown25', Format => 'int16s[4]', Unknown => 1 },
    0x103 => { Name => 'ColorTempUnknown25', Unknown => 1 },
    0x104 => { Name => 'WB_RGGBLevelsUnknown26',Format => 'int16s[4]', Unknown => 1 },
    0x108 => { Name => 'ColorTempUnknown26', Unknown => 1 },
    0x109 => { Name => 'WB_RGGBLevelsUnknown27',Format => 'int16s[4]', Unknown => 1 },
    0x10d => { Name => 'ColorTempUnknown27', Unknown => 1 },
    0x10e => { Name => 'WB_RGGBLevelsUnknown28',Format => 'int16s[4]', Unknown => 1 },
    0x112 => { Name => 'ColorTempUnknown28', Unknown => 1 },
    0x113 => { Name => 'WB_RGGBLevelsUnknown29',Format => 'int16s[4]', Unknown => 1 },
    0x117 => { Name => 'ColorTempUnknown29', Unknown => 1 },
    0x118 => { Name => 'WB_RGGBLevelsUnknown30',Format => 'int16s[4]', Unknown => 1 },
    0x11c => { Name => 'ColorTempUnknown30', Unknown => 1 },
    0x11d => { Name => 'WB_RGGBLevelsUnknown31',Format => 'int16s[4]', Unknown => 1 },
    0x121 => { Name => 'ColorTempUnknown31', Unknown => 1 },
    0x122 => { Name => 'WB_RGGBLevelsUnknown32',Format => 'int16s[4]', Unknown => 1 },
    0x126 => { Name => 'ColorTempUnknown32', Unknown => 1 },
    0x127 => { Name => 'WB_RGGBLevelsUnknown33',Format => 'int16s[4]', Unknown => 1 },
    0x12b => { Name => 'ColorTempUnknown33', Unknown => 1 },
    0x140 => {
        Name => 'ColorCalib',
        Format => 'undef[120]',
        Unknown => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ColorCalib' }
    },
    0x17f => {
        Name => 'PerChannelBlackLevel',
        Format => 'int16u[4]',
    },
    # 0x290 - PerChannelBlackLevel again
    0x294 => {
        Name => 'NormalWhiteLevel',
        Format => 'int16u',
        RawConv => '$val || undef',
    },
    0x295 => {
        Name => 'SpecularWhiteLevel',
        Format => 'int16u',
    },
    0x296 => {
        Name => 'LinearityUpperMargin',
        Format => 'int16u',
    },
);

# Unknown color data (MakerNotes tag 0x4001)
%Image::ExifTool::Canon::ColorDataUnknown = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int16s',
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => 'ColorDataVersion',
);

# Color information (MakerNotes tag 0x4003) (ref PH)
%Image::ExifTool::Canon::ColorInfo = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Condition => '$$self{Model} =~ /EOS-1D/',
        Name => 'Saturation',
        %Image::ExifTool::Exif::printParameter,
    },
    2 => {
        Name => 'ColorTone',
        %Image::ExifTool::Exif::printParameter,
    },
    3 => {
        Name => 'ColorSpace',
        RawConv => '$val ? $val : undef', # ignore tag if zero
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
        },
    },
);

# AF micro-adjustment information (MakerNotes tag 0x4013) (ref PH)
%Image::ExifTool::Canon::AFMicroAdj = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'AFMicroAdjMode',
        PrintConv => {
            0 => 'Disable',
            1 => 'Adjust all by the same amount',
            2 => 'Adjust by lens',
          # 3 - seen this for EOS 77D, which doesn't have an AF Micro Adjust feature - PH
        },
    },
    2 => {
        Name => 'AFMicroAdjValue',
        Format => 'rational64s',
    },
);

# Vignetting correction information (MakerNotes tag 0x4015)
%Image::ExifTool::Canon::VignettingCorr = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is found in images from newer EOS models.',
    0 => {
        Name => 'VignettingCorrVersion',
        Format => 'int8u',
        Writable => 0,
    },
    2 => {
        Name => 'PeripheralLighting',
        PrintConv => \%offOn,
    },
    3 => {
        Name => 'DistortionCorrection',
        PrintConv => \%offOn,
    },
    4 => {
        Name => 'ChromaticAberrationCorr',
        PrintConv => \%offOn,
    },
    5 => {
        Name => 'ChromaticAberrationCorr',
        PrintConv => \%offOn,
    },
    6 => 'PeripheralLightingValue',
    9 => 'DistortionCorrectionValue',
    # 10 - flags?
    11 => {
        Name => 'OriginalImageWidth',
        Notes => 'full size of original image before being rotated or scaled in camera',
    },
    12 => 'OriginalImageHeight',
);

%Image::ExifTool::Canon::VignettingCorrUnknown = (
    %binaryDataAttrs,
    FORMAT => 'int16s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Vignetting correction from PowerShot models.',
    0 => {
        Name => 'VignettingCorrVersion',
        Format => 'int8u',
        Writable => 0,
    },
);

# More Vignetting correction information (MakerNotes tag 0x4016)
%Image::ExifTool::Canon::VignettingCorr2 = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    5 => {
        Name => 'PeripheralLightingSetting',
        PrintConv => \%offOn,
    },
    6 => {
        Name => 'ChromaticAberrationSetting',
        PrintConv => \%offOn,
    },
    7 => {
        Name => 'DistortionCorrectionSetting',
        PrintConv => \%offOn,
    },
    9 => { #forum14286
        Name => 'DigitalLensOptimizerSetting',
        PrintConv => \%offOn,
    },
);

# Auto Lighting Optimizer information (MakerNotes tag 0x4018) (ref PH)
%Image::ExifTool::Canon::LightingOpt = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information is new in images from the EOS 7D.',
    1 => {
        Name => 'PeripheralIlluminationCorr',
        PrintConv => \%offOn,
    },
    2 => {
        Name => 'AutoLightingOptimizer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    3 => {
        Name => 'HighlightTonePriority',
        PrintConv => { %offOn, 2 => 'Enhanced' }, #github339 (Enhanced)
    },
    4 => {
        Name => 'LongExposureNoiseReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    5 => {
        Name => 'HighISONoiseReduction',
        PrintConv => {
            0 => 'Standard',
            1 => 'Low',
            2 => 'Strong',
            3 => 'Off',
        },
    },
    # 6 - related to ChromaticAberrationCorr
    # 7 - related to DistortionCorrection (0=off, 1=On in a 5DmkIV sample)
    # 8 - related to PeripheralIlluminationCorr and ChromaticAberrationCorr
    10 => { #forum14286
        Name => 'DigitalLensOptimizer',
        PrintConv => {
            0 => 'Off',
            1 => 'Standard',
            2 => 'High',
        },
    },
    11 => { #forum15445
        Name => 'DualPixelRaw',
        PrintConv => \%offOn,
    },
);

# Lens information (MakerNotes tag 0x4019) (ref 20)
%Image::ExifTool::Canon::LensInfo = (
    %binaryDataAttrs,
    FIRST_ENTRY => 0,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => { # this doesn't seem to be valid for some models (eg. 550D, 7D?, 1DmkIV?)
        Name => 'LensSerialNumber',
        Notes => q{
            apparently this is an internal serial number because it doesn't correspond
            to the one printed on the lens
        },
        Format => 'undef[5]',
        Priority => 0,
        RawConv => '$val=~/^\0\0\0\0/ ? undef : $val', # (rules out 550D and older lenses)
        ValueConv => 'unpack("H*", $val)',
        ValueConvInv => 'length($val) < 10 and $val = 0 x (10-length($val)) . $val; pack("H*",$val)',
    },
);

# Subject mode ambience information (MakerNotes tag 0x4020) (ref PH)
%Image::ExifTool::Canon::Ambience = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'AmbienceSelection',
        PrintConv => {
            0 => 'Standard',
            1 => 'Vivid',
            2 => 'Warm',
            3 => 'Soft',
            4 => 'Cool',
            5 => 'Intense',
            6 => 'Brighter',
            7 => 'Darker',
            8 => 'Monochrome',
        },
    },
);

# Multi-exposure information (MakerNotes tag 0x4021) (ref PH)
%Image::ExifTool::Canon::MultiExp = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => {
        Name => 'MultiExposure',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (RAW)', #IB
        },
    },
    2 => {
        Name => 'MultiExposureControl',
        PrintConv => {
            0 => 'Additive',
            1 => 'Average',
            2 => 'Bright (comparative)',
            3 => 'Dark (comparative)',
        },
    },
    3 => 'MultiExposureShots',
);

my %filterConv = (
    PrintConv => {
        -1 => 'Off',
        OTHER => sub { my $val=shift; return "On ($val)" },
    },
);
# Creative filter information (MakerNotes tag 0x4024) (ref PH)
%Image::ExifTool::Canon::FilterInfo = (
    PROCESS_PROC => \&ProcessFilters,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Information about creative filter settings.',
    0x101 => {
        Name => 'GrainyBWFilter',
        Description => 'Grainy B/W Filter',
        %filterConv,
    },
    0x201 => { Name => 'SoftFocusFilter',   %filterConv },
    0x301 => { Name => 'ToyCameraFilter',   %filterConv },
    0x401 => { Name => 'MiniatureFilter',   %filterConv },
    0x402 => {
        Name => 'MiniatureFilterOrientation',
        PrintConv => {
            0 => 'Horizontal',
            1 => 'Vertical',
        },
    },
    0x403 => 'MiniatureFilterPosition',
    0x404 => 'MiniatureFilterParameter', # but what is the meaning?
    0x501 => { Name => 'FisheyeFilter',     %filterConv }, # (M2)
    0x601 => { Name => 'PaintingFilter',    %filterConv }, # (M2)
    0x701 => { Name => 'WatercolorFilter',  %filterConv }, # (M2)
);

# HDR information (MakerNotes tag 0x4025) (ref PH)
%Image::ExifTool::Canon::HDRInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    1 => {
        Name => 'HDR',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'On',
        },
    },
    2 => {
        Name => 'HDREffect',
        PrintConv => {
            0 => 'Natural',
            1 => 'Art (standard)',
            2 => 'Art (vivid)',
            3 => 'Art (bold)',
            4 => 'Art (embossed)',
        },
    },
    # 3 - maybe related to AutoImageAlign?
);

# More color information (MakerNotes tag 0x4026) (ref github issue #119)
%Image::ExifTool::Canon::LogInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    PRIORITY => 0,
    4 => {
        Name => 'CompressionFormat',
        PrintConv => {
             0 => 'Editing (ALL-I)',
             1 => 'Standard (IPB)',
             2 => 'Light (IPB)',
             3 => 'Motion JPEG',
             4 => 'RAW', # either Standard or Light, depending on Quality
        },
    },
    6 => {  # 0 to 7
        Name => 'Sharpness',
        RawConv => '$val == 0x7fffffff ? undef : $val',
    },
    7 => {  # -4 to 4
        Name => 'Saturation',
        RawConv => '$val == 0x7fffffff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    8 => {  # -4 to 4
        Name => 'ColorTone',
        RawConv => '$val == 0x7fffffff ? undef : $val',
        %Image::ExifTool::Exif::printParameter,
    },
    9 => {
        Name => 'ColorSpace2',
        RawConv => '$val == 0x7fffffff ? undef : $val',
        PrintConv => {
            0 => 'BT.709',
            1 => 'BT.2020',
            2 => 'CinemaGamut',
        },
    },
    10 => {
        Name => 'ColorMatrix',
        RawConv => '$val == 0x7fffffff ? undef : $val',
        PrintConv => {
            0 => 'EOS Original',
            1 => 'Neutral',
        },
    },
    11 => {
        Name => 'CanonLogVersion', # (increases dynamic range of sensor data)
        RawConv => '$val == 0x7fffffff ? undef : $val',
        PrintConv => {
            0 => 'OFF',
            1 => 'CLogV1',
            2 => 'CLogV2', # (NC)
            3 => 'CLogV3',
        },
    },
);

# AF configuration info (MakerNotes tag 0x4028) (ref PH)
%Image::ExifTool::Canon::AFConfig = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    1 => {
        Name => 'AFConfigTool',
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
        PrintHex => 1,
        PrintConv => {
            11 => 'Case A',  #KG instead of 'Case 11'. Canon use A for Auto
            0x80000000 => 'n/a',
            OTHER => sub { 'Case ' . shift },
        },
        PrintConvInv => '$val=~/(\d+)/ ? $1 : 0x80000000',
    },
    2 => {
        Name => 'AFTrackingSensitivity',
        PrintHex => 1,
        PrintConv => {
            127 => 'Auto', #KG
            0x7fffffff => 'n/a',
            OTHER => sub { shift },
        },
    },
    3 => {
        Name => 'AFAccelDecelTracking',
        Description => 'AF Accel/Decel Tracking',
        PrintHex => 1,
        PrintConv => {
            127 => 'Auto', #KG
            0x7fffffff => 'n/a',
            OTHER => sub { shift },
        },
    },
    4 => {
        Name => 'AFPointSwitching',
        PrintConv => {
            0x7fffffff => 'n/a',
            OTHER => sub { shift },
        },
    },
    5 => { #52
        Name => 'AIServoFirstImage',
        PrintConv => {
             0 => 'Equal Priority',
             1 => 'Release Priority',
             2 => 'Focus Priority',
        },
    },
    6 => { #52
        Name => 'AIServoSecondImage',
        PrintConv => {
             0 => 'Equal Priority',
             1 => 'Release Priority',
             2 => 'Focus Priority',
             3 => 'Release High Priority',
             4 => 'Focus High Priority',
        },
    },
    7 => [{ #forum16068
        Name => 'USMLensElectronicMF',
        Condition => '$$self{Model} =~ /EOS R\d/',
        Notes => 'EOS R models',
        PrintConv => {
             0 => 'Disable After One-Shot',
             1 => 'One-Shot -> Enabled',
             2 => 'One-Shot -> Enabled (magnify)',
             3 => 'Disable in AF Mode',
        },
    },{ #52
        Name => 'USMLensElectronicMF',
        Notes => 'Other models',
        PrintConv => {
             0 => 'Enable After AF',
             1 => 'Disable After AF',
             2 => 'Disable in AF Mode',
        },
    }],
    8 => { #52
        Name => 'AFAssistBeam',
        PrintConv => {
             0 => 'Enable',
             1 => 'Disable',
             2 => 'IR AF Assist Beam Only',
             3 => 'LED AF Assist Beam Only', #forum16068
        },
    },
    9 => { #52
        Name => 'OneShotAFRelease',
        PrintConv => {
             0 => 'Focus Priority',
             1 => 'Release Priority',
        },
    },
    10 => { #52
        Name => 'AutoAFPointSelEOSiTRAF',
        Description => 'Auto AF Point Sel EOS iTR AF',
        # valid for: 1DX, 1DXmkII, 7DmkII, 5DS, 5DSR
        # not valid for: 5DmkIII
        Notes => 'only valid for some models',
        Condition => '$$self{Model} !~ /5D /',
        PrintConv => {
             0 => 'Enable',
             1 => 'Disable',
        },
    },
    11 => { #52
        Name => 'LensDriveWhenAFImpossible',
        PrintConv => {
             0 => 'Continue Focus Search',
             1 => 'Stop Focus Search',
        },
    },
    12 => { #52
        Name => 'SelectAFAreaSelectionMode',
        PrintConv => { BITMASK => {
            0 => 'Single-point AF',
            1 => 'Auto', # (61 point)
            2 => 'Zone AF',
            3 => 'AF Point Expansion (4 point)',
            4 => 'Spot AF',
            5 => 'AF Point Expansion (8 point)',
        }},
    },
    13 => { #52
        Name => 'AFAreaSelectionMethod',
        PrintConv => {
             0 => 'M-Fn Button',
             1 => 'Main Dial',
        },
    },
    14 => { #52
        Name => 'OrientationLinkedAF',
        PrintConv => { # Covers both 1Dx (0-2) and 5D3 (0-1)
             0 => 'Same for Vert/Horiz Points',
             1 => 'Separate Vert/Horiz Points',
             2 => 'Separate Area+Points',
        },
    },
    15 => { #52
        Name => 'ManualAFPointSelPattern',
        PrintConv => {
             0 => 'Stops at AF Area Edges',
             1 => 'Continuous',
        },
    },
    16 => { #52
        Name => 'AFPointDisplayDuringFocus',
        PrintConv => {
             0 => 'Selected (constant)',
             1 => 'All (constant)',
             2 => 'Selected (pre-AF, focused)',
             3 => 'Selected (focused)',
             4 => 'Disabled',
        },
    },
    17 => { #52
        Name => 'VFDisplayIllumination',
        PrintConv => {
             0 => 'Auto',
             1 => 'Enable',
             2 => 'Disable',
        },
    },
    18 => { #52/forum16223
        Name => 'AFStatusViewfinder',
        Condition => '$$self{Model} =~ /EOS-1D X|EOS R/',
        Notes => '1D X and R models',
        PrintConv => {
             0 => 'Show in Field of View',
             1 => 'Show Outside View',
        },
    },
    19 => { #52/forum16223
        Name => 'InitialAFPointInServo',
        Condition => '$$self{Model} =~ /EOS-1D X|EOS R/',
        Notes => '1D X and R models',
        PrintConv => {
             0 => 'Initial AF Point Selected',
             1 => 'Manual AF Point',
             2 => 'Auto', #PH (1DXmkII)
        },
    },
    20 => { #forum16068
        Name => 'SubjectToDetect',
        PrintConv => {
            0 => 'None',
            1 => 'People',
            2 => 'Animals',
            3 => 'Vehicles',
            4 => 'Auto',  #KG (R1, R5m2)
        },
    },
    21 => { #github344 (R6)
        Name => 'SubjectSwitching',
        PrintConv => {
            0 => 'Initial Priority',
            1 => 'On Subject',
            2 => 'Switch Subject',
            0x7fffffff => 'n/a',
        },
    },
    24 => { #forum16068  #KG extensions for 'left' and 'right'
        Name => 'EyeDetection',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Left Eye',
            3 => 'Right Eye',
         },
    },
    # ---------------
    # Entries 25..31 exist for recent models only (R1, R5m2, ...)
    # ---------------
    26 => { #KG
        Name => 'WholeAreaTracking',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    27 => { #KG
        Name => 'ServoAFCharacteristics',
        PrintConv => {
            0 => 'Case Auto',
            1 => 'Case Manual',
        },
    },
    28 => { #KG
        Name => 'CaseAutoSetting',
        PrintConv => {
           -1 => 'Locked On',
            0 => 'Standard',
            1 => 'Responsive',
            0x7fffffff => 'n/a',
        },
    },
    29 => { #KG
        Name => 'ActionPriority',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    30 => { #KG
        Name => 'SportEvents',
        PrintConv => {
            0 => 'Soccer',
            1 => 'Basketball',
            2 => 'Volleyball',
        }
    },
);

# RAW burst mode info (MakerNotes tag 0x403f) (ref 25)
%Image::ExifTool::Canon::RawBurstInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 1,
    1 => 'RawBurstImageNum',
    2 => 'RawBurstImageCount',
);

# level information (ref forum16111, EOS R5)
%Image::ExifTool::Canon::LevelInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    4 => {
        Name => 'RollAngle',
        Notes => 'converted to degrees of clockwise camera rotation',
        ValueConv => '$val > 1800 and $val -= 3600; -$val / 10',
        ValueConvInv => '$val > 0 and $val -= 360; int(-$val * 10 + 0.5)',
    },
    5 => {
        Name => 'PitchAngle',
        Notes => 'converted to degrees of upward camera tilt',
        ValueConv => '$val > 1800 and $val -= 3600; $val / 10',
        ValueConvInv => '$val < 0 and $val += 360; int($val * 10 + 0.5)',
    },
    7 => {
        Name => 'FocalLength',
        ValueConv => '$val / 10',
        ValueConvInv => 'int($val * 10 + 0.5)',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    8 => {
        Name => 'MinFocalLength2',
        Notes => q{
            these seem to be min/max focal length without teleconverter, as opposed to
            MinFocalLength and MaxFocalLength which include the effect of a
            teleconverter
        }, #forum16309
        ValueConv => '$val / 10',
        ValueConvInv => 'int($val * 10 + 0.5)',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
    9 => {
        Name => 'MaxFocalLength2',
        ValueConv => '$val / 10',
        ValueConvInv => 'int($val * 10 + 0.5)',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },

);

#github380
%Image::ExifTool::Canon::FocusBracketingInfo = (
    %binaryDataAttrs,
    FORMAT => 'int32s',
    FIRST_ENTRY => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    1 => {
        Name => 'FocusBracketing',
        PrintConv => \%offOn,
    },
    2 => 'FocusBracketingImageCount', # (value: 1-999)
    3 => 'FocusBracketingFocusIncrement', # (value: 1-10)
    4 => {
        Name => 'FocusBracketingExposureSmoothing',
        PrintConv => \%offOn,
    },
    5 => {
        Name => 'FocusBracketingDepthComposite',
        PrintConv => \%offOn,
    },
    6 => {
        Name => 'FocusBracketingCropDepthComposite',
        PrintConv => \%offOn,
    },
    7 => 'FocusBracketingFlashInterval', # in seconds
);

# Canon UUID atoms (ref PH, SX280)
%Image::ExifTool::Canon::uuid = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Video' },
    WRITE_PROC => 'Image::ExifTool::QuickTime::WriteQuickTime',
    NOTES => q{
        Tags extracted from the uuid atom of MP4 videos from cameras such as the
        SX280, and CR3 images from cameras such as the EOS M50.
    },
    CNCV => {
        Name => 'CompressorVersion',
        # use this to recognize the specific type of Canon RAW (CR3 or CRM)
        RawConv => '$self->OverrideFileType($1) if $val =~ /^Canon(\w{3})/i; $val',
    },
    # CNDM - 4 bytes - 0xff,0xd8,0xff,0xd9
    CNTH => {
        Name => 'CanonCNTH',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CNTH' },
    },
    CCTP => { # (CR3 files)
        Name => 'CanonCCTP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CCTP',
            Start => '12',
        },
    },
    # CTBO - (CR3 files) int32u entry count N, N x (int32u index, int64u offset, int64u size)
    #        index: 1=XMP, 2=PRVW, 3=mdat, 4=?, 5=?
    #        --> ignored when reading, but offsets are updated when writing
    CMT1 => { # (CR3 files)
        Name => 'IFD0',
        PreservePadding => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    CMT2 => { # (CR3 files)
        Name => 'ExifIFD',
        PreservePadding => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    CMT3 => { # (CR3 files)
        Name => 'MakerNoteCanon',
        PreservePadding => 1,
        Writable => 'undef', # (writable directory!)
        # (note that ExifTool 12.68 and earlier lacked the ability to write this as a block,
        #  and would instead add the maker notes the the CMT2 ExifIFD.  To remove these
        #  incorrectly-placed maker notes, use "exiftool -exififd:makernotes= FILE")
        MakerNotes => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Main',
            DirName => 'MakerNotes', # (necessary for mechanism that prevents these from being deleted)
            ProcessProc => \&ProcessCMT3,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    CMT4 => { # (CR3 files)
        Name => 'GPSInfo',
        PreservePadding => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::GPS::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
            DirName => 'GPS',
        },
    },
    THMB => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        PreservePadding => 1,
        RawConv => 'substr($val, 16)',
        Binary => 1,
    },
    CNOP => { #PH (M50)
        Name => 'CanonCNOP',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CNOP' },
    },
);

# Canon top-level uuid atoms (ref PH, written by DPP4)
%Image::ExifTool::Canon::uuid2 = (
    WRITE_PROC => 'Image::ExifTool::QuickTime::WriteQuickTime',
    CNOP => {
        Name => 'CanonVRD',
        PreservePadding => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::CanonVRD::Main',
            WriteProc => 'Image::ExifTool::CanonVRD::WriteCanonDR4',
        },
    },
);

%Image::ExifTool::Canon::UnknownIFD = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# Canon CCTP atoms (ref PH, CR3 files)
%Image::ExifTool::Canon::CCTP = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Video' },
    # CCDT - int32u[3]: 0. 0, 1. decoder type?, 2. 0, 3. index
);

# 'CMP1' atom information (ref 54, CR3 files)
%Image::ExifTool::Canon::CMP1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
    PRIORITY => 0,
    8  => { Name => 'ImageWidth',  Format => 'int32u' },
    10 => { Name => 'ImageHeight', Format => 'int32u' },
    # (the rest of the documented tags don't seem to produced good values with my samples - PH)
);

# 'CDI1' atom information (ref PH, CR3 files)
%Image::ExifTool::Canon::CDI1 = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    IAD1 => { Name => 'IAD1', SubDirectory => { TagTable => 'Image::ExifTool::Canon::IAD1' } },
);

# 'IAD1' atom information (ref 54, CR3 files)
%Image::ExifTool::Canon::IAD1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    FORMAT => 'int16u',
    FIRST_ENTRY => 0,
);

# Canon Timed MetaData (ref PH, CR3 files)
%Image::ExifTool::Canon::CTMD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    PROCESS_PROC => \&ProcessCTMD,
    NOTES => q{
        Canon Timed MetaData tags found in CR3 images.  The L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option
        is automatically applied when reading CR3 files to be able to extract this
        information.
    },
    1 => {
        Name => 'TimeStamp',
        Groups => { 2 => 'Time' },
        RawConv => q{
            my $fmt = GetByteOrder() eq 'MM' ? 'x2nCCCCCC' : 'x2vCCCCCC';
            sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d.%.2d', unpack($fmt, $val));
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
  # 3 - 4 bytes, seen: ff ff ff ff
    4 => {
        Name => 'FocalInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::FocalInfo' },
    },
    5 => {
        Name => 'ExposureInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ExposureInfo' },
    },
    7 => {
        Name => 'ExifInfo7',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ExifInfo' },
    },
    8 => {
        Name => 'ExifInfo8',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ExifInfo' },
    },
    9 => {
        Name => 'ExifInfo9',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::ExifInfo' },
    },
  # 10 - 60 bytes: all zeros with a pair of 0xff's at offset 0x02 (C200 CRM)
  # 11 - 612 bytes: all zero with pairs of 0xff's at offset 0x6e and 0x116 (C200 CRM)
);

# Canon Timed MetaData (ref PH, CR3 files)
%Image::ExifTool::Canon::ExifInfo = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    PROCESS_PROC => \&ProcessExifInfo,
    0x8769 => {
        Name => 'ExifIFD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
        },
    },
    0x927c => {
        Name => 'MakerNoteCanon',
        MakerNotes => 1,
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
        },
    },
);

# timed focal length information (ref PH, CR3 files)
%Image::ExifTool::Canon::FocalInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'FocalLength',
        Format => 'rational32u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
);

# timed exposure information (ref PH, CR3 files)
%Image::ExifTool::Canon::ExposureInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Image' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'FNumber',
        Format => 'rational32u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    1 => {
        Name => 'ExposureTime',
        Format => 'rational32u',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    2 => {
        Name => 'ISO',
        Format => 'int32u',
        ValueConv => '$val & 0x7fffffff',   # (not sure what high bit indicates)
    },
);

%Image::ExifTool::Canon::CNTH = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Video' },
    VARS => { ATOM_COUNT => 1 },    # only one contained atom
    WRITABLE => 1,
    WRITE_PROC => 'Image::ExifTool::QuickTime::WriteQuickTime',
    NOTES => q{
        Canon-specific QuickTime tags found in the CNTH atom of MOV/MP4 videos from
        some cameras.
    },
    CNDA => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef',
        Notes => 'the full THM image, embedded metadata is extracted as the first sub-document',
        SetBase => 1,
        RawConv => q{
            $$self{DOC_NUM} = ++$$self{DOC_COUNT};
            $self->ExtractInfo(\$val, { ReEntry => 1 });
            $$self{DOC_NUM} = 0;
            return \$val;
        },
        RawConvInv => '$val',
    },
);

# Canon CNOP atoms (ref PH)
%Image::ExifTool::Canon::CNOP = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Video' },
    # CNFB - 52 bytes (7DmkII,M50,C200)
    # CNMI - 4 bytes: "0x20000001" (C200)
    # CNCM - 48 bytes: original file name in bytes 24-31 (C200)
);

# 'skip' atom of Canon MOV videos (ref PH)
%Image::ExifTool::Canon::Skip = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'Canon', 2 => 'Video' },
    NOTES => 'Information found in the "skip" atom of Canon MOV videos.',
    CNDB => { Name => 'Unknown_CNDB', Unknown => 1, Binary => 1 },
);

# Canon composite tags
%Image::ExifTool::Canon::Composite = (
    GROUPS => { 2 => 'Camera' },
    DriveMode => {
        Require => {
            0 => 'ContinuousDrive',
            1 => 'SelfTimer',
        },
        ValueConv => '$val[0] ? 0 : ($val[1] ? 1 : 2)',
        PrintConv => {
            0 => 'Continuous Shooting',
            1 => 'Self-timer Operation',
            2 => 'Single-frame Shooting',
        },
    },
    Lens => {
        Require => {
            0 => 'Canon:MinFocalLength',
            1 => 'Canon:MaxFocalLength',
        },
        ValueConv => '$val[0]',
        PrintConv => 'Image::ExifTool::Canon::PrintFocalRange(@val)',
    },
    Lens35efl => {
        Description => 'Lens',
        Require => {
            0 => 'Canon:MinFocalLength',
            1 => 'Canon:MaxFocalLength',
            3 => 'Lens',
        },
        Desire => {
            2 => 'ScaleFactor35efl',
        },
        ValueConv => '$val[3] * ($val[2] ? $val[2] : 1)',
        PrintConv => '$prt[3] . ($val[2] ? sprintf(" (35 mm equivalent: %s)",Image::ExifTool::Canon::PrintFocalRange(@val)) : "")',
    },
    ShootingMode => {
        Require => {
            0 => 'CanonExposureMode',
            1 => 'EasyMode',
        },
        Desire => {
            2 => 'BulbDuration',
        },
        # most Canon models set CanonExposureMode to Manual (4) for Bulb shots,
        # but the 1DmkIII uses a value of 7 for Bulb, so use this for other
        # models too (Note that Canon DPP reports "Manual Exposure" here)
        ValueConv => '$val[0] ? (($val[0] eq "4" and $val[2]) ? 7 : $val[0]) : $val[1] + 10',
        PrintConv => '$val eq "7" ? "Bulb" : ($val[0] ? $prt[0] : $prt[1])',
    },
    FlashType => {
        Notes => q{
            may report "Built-in Flash" for some Canon cameras with external flash in
            manual mode
        },
        Require => {
            0 => 'FlashBits',
        },
        RawConv => '$val[0] ? $val : undef',
        ValueConv => '$val[0]&(1<<14)? 1 : 0',
        PrintConv => {
            0 => 'Built-In Flash',
            1 => 'External',
        },
    },
    RedEyeReduction => {
        Require => {
            0 => 'CanonFlashMode',
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => '($val[0]==3 or $val[0]==4 or $val[0]==6) ? 1 : 0',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    # same as FlashExposureComp, but undefined if no flash
    ConditionalFEC => {
        Description => 'Flash Exposure Compensation',
        Require => {
            0 => 'FlashExposureComp',
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => '$val[0]',
        PrintConv => '$prt[0]',
    },
    # hack to assume 1st curtain unless we see otherwise
    ShutterCurtainHack => {
        Description => 'Shutter Curtain Sync',
        Desire => {
            0 => 'ShutterCurtainSync',
        },
        Require => {
            1 => 'FlashBits',
        },
        RawConv => '$val[1] ? $val : undef',
        ValueConv => 'defined($val[0]) ? $val[0] : 0',
        PrintConv => {
            0 => '1st-curtain sync',
            1 => '2nd-curtain sync',
        },
    },
    WB_RGGBLevels => {
        Require => {
            0 => 'Canon:WhiteBalance',
        },
        Desire => {
            1 => 'WB_RGGBLevelsAsShot',
            # indices of the following entries correspond to Canon:WhiteBalance + 2
            2 => 'WB_RGGBLevelsAuto',
            3 => 'WB_RGGBLevelsDaylight',
            4 => 'WB_RGGBLevelsCloudy',
            5 => 'WB_RGGBLevelsTungsten',
            6 => 'WB_RGGBLevelsFluorescent',
            7 => 'WB_RGGBLevelsFlash',
            8 => 'WB_RGGBLevelsCustom',
           10 => 'WB_RGGBLevelsShade',
           11 => 'WB_RGGBLevelsKelvin',
        },
        ValueConv => '$val[1] ? $val[1] : $val[($val[0] || 0) + 2]',
    },
    ISO => {
        Priority => 0,  # let EXIF:ISO take priority
        Desire => {
            0 => 'Canon:CameraISO',
            1 => 'Canon:BaseISO',
            2 => 'Canon:AutoISO',
        },
        Notes => 'use CameraISO if numerical, otherwise calculate as BaseISO * AutoISO / 100',
        ValueConv => q{
            return $val[0] if $val[0] and $val[0] =~ /^\d+$/;
            return undef unless $val[1] and $val[2];
            return $val[1] * $val[2] / 100;
        },
        PrintConv => 'sprintf("%.0f",$val)',
    },
    DigitalZoom => {
        Require => {
            0 => 'Canon:ZoomSourceWidth',
            1 => 'Canon:ZoomTargetWidth',
            2 => 'Canon:DigitalZoom',
        },
        RawConv => q{
            ToFloat(@val);
            return undef unless $val[2] and $val[2] == 3 and $val[0] and $val[1];
            return $val[1] / $val[0];
        },
        PrintConv => 'sprintf("%.2fx",$val)',
    },
    OriginalDecisionData => {
        Flags => ['Writable','Protected'],
        WriteGroup => 'MakerNotes',
        Require => 'OriginalDecisionDataOffset',
        RawConv => 'Image::ExifTool::Canon::ReadODD($self,$val[0])',
    },
    FileNumber => {
        Groups => { 2 => 'Image' },
        Writable => 1,
        WriteCheck => '$val=~/\d+-\d+/ ? undef : "Invalid format"',
        DelCheck => '"Can\'t delete"',
        Require => {
            0 => 'DirectoryIndex',
            1 => 'FileIndex',
        },
        WriteAlso => {
            DirectoryIndex => '$val=~/(\d+)-(\d+)/; $1',
            FileIndex => '$val=~/(\d+)-(\d+)/; $2',
        },
        ValueConv => q{
            # fix the funny things that these numbers do when they wrap over 9999
            # (it seems that FileIndex and DirectoryIndex actually store the
            #  numbers from the previous image, so we need special logic
            #  to handle the FileIndex wrap properly)
            $val[1] == 10000 and $val[1] = 1, ++$val[0];
            return sprintf("%.3d%.4d",@val);
        },
        PrintConv => '$_=$val;s/(\d+)(\d{4})/$1-$2/;$_',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Canon');

#------------------------------------------------------------------------------
# Return lens name with teleconverter if applicable
# Inputs: 0) lens name string, 1) short focal length
# Returns: lens string with tc if appropriate
sub LensWithTC($$)
{
    my ($lens, $shortFocal) = @_;

    # add teleconverter multiplication factor if applicable
    # (and if the LensType doesn't already include one)
    if (not $lens =~ /x$/ and $lens =~ /(\d+)/) {
        my $sf = $1;    # short focal length
        my $tc;
        foreach $tc (1, 1.4, 2, 2.8) {
            next if abs($shortFocal - $sf * $tc) > 0.9;
            $lens .= " + ${tc}x" if $tc > 1;
            last;
        }
    }
    return $lens;
}

#------------------------------------------------------------------------------
# Attempt to calculate sensor size for Canon cameras
# Inputs: 0) ExifTool ref
# Returns: Sensor diagonal size in mm, or undef
# Notes: This algorithm is fairly reliable, but has been found to give incorrect
#        values for some firmware versions of the EOS 20D, A310, SD40 and IXUS 65
# (ref http://wyw.dcweb.cn/download.asp?path=&file=jhead-2.96-ccdwidth_hack.zip)
sub CalcSensorDiag($)
{
    my $et = shift;
    # calculation is based on the rational value of FocalPlaneX/YResolution
    # (most Canon cameras store the sensor size in the denominator)
    return undef unless $$et{TAG_EXTRA}{FocalPlaneXResolution} and
                        $$et{TAG_EXTRA}{FocalPlaneYResolution};
    my $xres = $$et{TAG_EXTRA}{FocalPlaneXResolution}{Rational};
    my $yres = $$et{TAG_EXTRA}{FocalPlaneYResolution}{Rational};
    return undef unless $xres and $yres;
    # assumptions: 1) numerators are image width/height * 1000
    # 2) denominators are sensor width/height in inches * 1000
    my @xres = split /[ \/]/, $xres;
    my @yres = split /[ \/]/, $yres;
    # verify assumptions as best we can:
        # numerators are always divisible by 1000
    if ($xres[0] % 1000 == 0 and $yres[0] % 1000 == 0 and
        # at least 640x480 pixels (DC models - PH)
        $xres[0] >= 640000 and $yres[0] >= 480000 and
        # ... but not too big!
        $xres[0] < 10000000 and $yres[0] < 10000000 and
        # minimum sensor size is 0.061 inches (DC models - PH)
        $xres[1] >= 61 and $xres[1] < 1500 and
        $yres[1] >= 61 and $yres[1] < 1000 and
        # sensor isn't square (may happen if rationals have been reduced)
        $xres[1] != $yres[1])
    {
        return sqrt($xres[1]*$xres[1] + $yres[1]*$yres[1]) * 0.0254;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Attempt to identify the specific lens if multiple lenses have the same LensType
# Inputs: 0) PrintConv hash ref, 1) LensType, 2) MinFocalLength, 3) MaxFocalLength
#         4) MaxAperture, 5) LensModel
# Notes: PrintConv, LensType, MinFocalLength and MaxFocalLength must be defined.
#        Other inputs are optional.
sub PrintLensID(@)
{
    my ($printConv, $lensType, $shortFocal, $longFocal, $maxAperture, $lensModel) = @_;
    my $lens;
    $lens = $$printConv{$lensType} unless $lensType eq '-1' or $lensType eq '65535';
    if ($lens) {
        # return this lens unless other lenses have the same LensType
        return LensWithTC($lens, $shortFocal) unless $$printConv{"$lensType.1"};
        $lens =~ s/ or .*//s;    # remove everything after "or"
        # make list of all possible matching lenses
        my @lenses = ( $lens );
        my $i;
        for ($i=1; $$printConv{"$lensType.$i"}; ++$i) {
            push @lenses, $$printConv{"$lensType.$i"};
        }
        my ($tc, @user, @maybe, @likely, @matches);
        # look for lens in user-defined lenses
        foreach $lens (@lenses) {
            push @user, $lens if $Image::ExifTool::userLens{$lens};
        }
        my @tcs = (1, 1.4, 2, 2.8);
        @tcs = ( $3 ) if $lensModel =~ / \+ ((EXTENDER )?RF)?(\d+(\.\d*)?)x\b/;
        # attempt to determine actual lens
        foreach $tc (@tcs) {  # loop through teleconverter scaling factors
            foreach $lens (@lenses) {
                next unless $lens =~ /(\d+)(?:-(\d+))?mm.*?(?:[fF]\/?)(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?/;
                # ($1=short focal, $2=long focal, $3=max aperture wide, $4=max aperture tele)
                my ($sf, $lf, $sa, $la) = ($1, $2, $3, $4);
                # see if we can rule out this lens by focal length or aperture
                $lf = $sf if $sf and not $lf;
                $la = $sa if $sa and not $la;
                # account for converter-specific LensType's (ie. end with " + #.#x")
                if ($lens =~ / \+ (\d+(\.\d+)?)x$/) {
                    $sf *= $1;  $lf *= $1;
                    $sa *= $1;  $la *= $1;
                }
                next if abs($shortFocal - $sf * $tc) > 0.9;
                my $tclens = $lens;
                if ($lens =~ /^(.*) \+ (RF)?(\d+(\.\d*)?)x$/) {
                    next unless $3 eq $tc;
                    # remove previous entry if same lens
                    my $lns = $1;
                    pop @maybe if @maybe and $maybe[-1] =~ /^$lns/;
                    pop @likely if @likely and $likely[-1] =~ /^$lns/;
                    pop @matches if @matches and $matches[-1] =~ /^$lns/;
                } elsif ($tc > 1) {
                    $tclens .= " + ${tc}x";
                }
                push @maybe, $tclens;
                next if abs($longFocal  - $lf * $tc) > 0.9;
                push @likely, $tclens;
                if ($maxAperture) {
                    # (not 100% sure that TC affects MaxAperture, but it should!)
                    # (RF 24-105mm F4L IS USM shows a MaxAperture of 4.177)
                    next if $maxAperture < $sa * $tc - 0.18;
                    next if $maxAperture > $la * $tc + 0.18;
                }
                push @matches, $tclens;
            }
            last if @maybe;
        }
        if (@user) {
            # choose the best match if we have more than one
            if (@user > 1) {
                my ($try, @good);
                foreach $try (\@matches, \@likely, \@maybe) {
                    foreach (@$try) {
                        $Image::ExifTool::userLens{$_} and push(@good, $_), next;
                        # check for match with TC string removed
                        next unless /^(.*) \+ \d+(\.\d+)?x$/;
                        $Image::ExifTool::userLens{$1} and push(@good, $_);
                    }
                    return join(' or ', @good) if @good;
                }
            }
            # default to returning the first user-defined lens
            return LensWithTC($user[0], $shortFocal);
        }
        # differentiate Sigma Art/Contemporary/Sports models
        if (@matches > 1 and $lensModel and $lensModel =~ /(\| [ACS])/) {
            my $type = $1;
            my @best;
            foreach $lens (@matches) {
                push @best, $lens if $lens =~ /\Q$type/;
            }
            @matches = @best if @best;
        }
        @matches = @likely unless @matches;
        @matches = @maybe unless @matches;
        Image::ExifTool::Exif::MatchLensModel(\@matches, $lensModel);
        return join(' or ', @matches) if @matches;
    } elsif ($lensModel and $lensModel =~ /\d/) {
        # use lens model as written by the camera
        if ($printConv eq \%canonLensTypes) {
            # add "Canon" to the start since the Canon cameras only understand Canon lenses
            return "Canon $lensModel";
        } else {
            return $lensModel;
        }
    }
    my $str = '';
    if ($shortFocal) {
        $str .= sprintf(' %d', $shortFocal);
        $str .= sprintf('-%d', $longFocal) if $longFocal and $longFocal != $shortFocal;
        $str .= 'mm';
    }
    # (careful because Sigma LensType's may not be integer, so use string comparison)
    return "Unknown$str" if $lensType eq '-1' or $lensType eq '65535';
    return "Unknown ($lensType)$str";
}

#------------------------------------------------------------------------------
# Swap 16-bit words in 32-bit integers
# Inputs: 0) string of integers
# Returns: string of word-swapped integers
sub SwapWords($)
{
    my @a = split(' ', shift);
    $_ = (($_ >> 16) | ($_ << 16)) & 0xffffffff foreach @a;
    return "@a";
}

#------------------------------------------------------------------------------
# Validate first word of Canon binary data
# Inputs: 0) data pointer, 1) offset, 2-N) list of valid values
# Returns: true if data value is the same
sub Validate($$@)
{
    my ($dataPt, $offset, @vals) = @_;
    # the first 16-bit value is the length of the data in bytes
    my $dataVal = Image::ExifTool::Get16u($dataPt, $offset);
    my $val;
    foreach $val (@vals) {
        return 1 if $val == $dataVal;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Validate CanonAFInfo
# Inputs: 0) data pointer, 1) offset, 2) size
# Returns: true if data appears valid
sub ValidateAFInfo($$$)
{
    my ($dataPt, $offset, $size) = @_;
    return 0 if $size < 24; # must be at least 24 bytes long (PowerShot Pro1)
    my $af = Get16u($dataPt, $offset);
    return 0 if $af !~ /^(1|5|7|9|15|45|53)$/; # check NumAFPoints
    my $w1 = Get16u($dataPt, $offset + 4);
    my $h1 = Get16u($dataPt, $offset + 6);
    return 0 unless $h1 and $w1;
    my $f1 = $w1 / $h1;
    # check for normal aspect ratio
    return 1 if abs($f1 - 1.33) < 0.01 or abs($f1 - 1.67) < 0.01;
    # ZoomBrowser can modify this for rotated images (ref Joshua Bixby)
    return 1 if abs($f1 - 0.75) < 0.01 or abs($f1 - 0.60) < 0.01;
    my $w2 = Get16u($dataPt, $offset + 8);
    my $h2 = Get16u($dataPt, $offset + 10);
    return 0 unless $h2 and $w2;
    # compare aspect ratio with AF image size
    # (but the Powershot AFImageHeight is odd, hence the test above)
    return 0 if $w1 eq $h1;
    my $f2 = $w2 / $h2;
    return 1 if abs(1-$f1/$f2) < 0.01;
    return 1 if abs(1-$f1*$f2) < 0.01;
    return 0;
}

#------------------------------------------------------------------------------
# Read original decision data from file (variable length)
# Inputs: 0) ExifTool object ref, 1) offset in file
# Returns: reference to original decision data (or undef if no data)
sub ReadODD($$)
{
    my ($et, $offset) = @_;
    return undef unless $offset;
    my ($raf, $buff, $buf2, $i, $warn);
    return undef unless defined($raf = $$et{RAF});
    # the data block is a variable length and starts with 0xffffffff
    # followed a 4-byte (int32u) version number
    my $pos = $raf->Tell();
    if ($raf->Seek($offset, 0) and $raf->Read($buff, 8)==8 and $buff=~/^\xff{4}.\0\0/s) {
        my $err = 1;
        # must set byte order in case it is different than current byte order
        # (we could be reading this after byte order was changed)
        my $oldOrder = GetByteOrder();
        my $version = Get32u(\$buff, 4);
        if ($version > 20) {
            ToggleByteOrder();
            $version = unpack('N',pack('V',$version));
        }
        if ($version == 1 or   # 1Ds (big endian)
            $version == 2)     # 5D/20D (little endian)
        {
            # this data is structured as follows:
            #  4 bytes: all 0xff
            #  4 bytes: version number (=1 or 2)
            # 20 bytes: sha1
            #  4 bytes: record count
            # for each record:
            # |  4 bytes: record number (beginning at 0)
            # |  4 bytes: block offset
            # |  4 bytes: block length
            # | 20 bytes: block sha1
            if ($raf->Read($buf2, 24) == 24) {
                $buff .= $buf2;
                my $count = Get32u(\$buf2, 20);
                # read all records if the count is reasonable
                if ($count and $count < 20 and
                    $raf->Read($buf2, $count * 32) == $count * 32)
                {
                    $buff .= $buf2;
                    undef $err;
                }
            }
        } elsif ($version == 3) { # newer models (little endian)
            # this data is structured as follows:
            #  4 bytes: all 0xff
            #  4 bytes: version number (=3)
            # 24 bytes: sha1 A length (=20) + sha1 A
            # 24 bytes: sha1 B length (=20) + sha1 B
            #  4 bytes: length of remaining data (including this length word!)
            #  8 bytes: salt length (=4) + salt ?
            #  4 bytes: unknown (=3)
            #  4 bytes: size of file
            #  4 bytes: unknown (=1 for most models, 2 for 5DmkII)
            #  4 bytes: unknown (=1)
            #  4 bytes: unknown (always the same for a given firmware version)
            #  4 bytes: unknown (random)
            #  4 bytes: record count
            # for each record:
            # |  4 bytes: record number (beginning at 1)
            # |  8 bytes: salt length (=4) + salt ?
            # | 24 bytes: sha1 length (=20) + sha1
            # |  4 bytes: block count
            # | for each block:
            # | |  4 bytes: block offset
            # | |  4 bytes: block length
            # followed by zero padding to end of ODD data (~72 bytes)
            for ($i=0; ; ++$i) {
                $i == 3 and undef $err, last; # success!
                $raf->Read($buf2, 4) == 4 or last;
                $buff .= $buf2;
                my $len = Get32u(\$buf2, 0);
                # (the data length includes the length word itself - doh!)
                $len -= 4 if $i == 2 and $len >= 4;
                # make sure records are a reasonable size (<= 64kB)
                $len <= 0x10000 and $raf->Read($buf2, $len) == $len or last;
                $buff .= $buf2;
            }
        } else {
            $warn = "Unsupported original decision data version $version";
        }
        SetByteOrder($oldOrder);
        unless ($err) {
            if ($et->Options('HtmlDump')) {
                $et->HDump($offset, length $buff, '[OriginalDecisionData]', undef);
            }
            $raf->Seek($pos, 0);    # restore original file position
            return \$buff;
        }
    }
    $et->Warn($warn || 'Invalid original decision data');
    $raf->Seek($pos, 0);    # restore original file position
    return undef;
}

#------------------------------------------------------------------------------
# Convert the CameraISO value
# Inputs: 0) value, 1) set for inverse conversion
sub CameraISO($;$)
{
    my ($val, $inv) = @_;
    my $rtnVal;
    my %isoLookup = (
         0 => 'n/a',
        14 => 'Auto High', #PH (S3IS)
        15 => 'Auto',
        16 => 50,
        17 => 100,
        18 => 200,
        19 => 400,
        20 => 800, #PH
    );
    if ($inv) {
        $rtnVal = Image::ExifTool::ReverseLookup($val, \%isoLookup);
        if (not defined $rtnVal and Image::ExifTool::IsInt($val)) {
            $rtnVal = ($val & 0x3fff) | 0x4000;
        }
    } elsif ($val != 0x7fff) {
        if ($val & 0x4000) {
            $rtnVal = $val & 0x3fff;
        } else {
            $rtnVal = $isoLookup{$val} || "Unknown ($val)";
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Print range of focal lengths
# Inputs: 0) short focal, 1) long focal, 2) optional scaling factor
sub PrintFocalRange(@)
{
    my ($short, $long, $scale) = @_;

    $scale or $scale = 1;
    if ($short == $long) {
        return sprintf("%.1f mm", $short * $scale);
    } else {
        return sprintf("%.1f - %.1f mm", $short * $scale, $long * $scale);
    }
}

#------------------------------------------------------------------------------
# Process a serial stream of binary data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: The tagID's for serial stream tags are consecutive indices beginning
#        at 0, and the corresponding values must be contiguous in memory.
#        "Unknown" tags must be used to skip padding or unknown values.
# (does not yet extract Rational values)
sub ProcessSerialData($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $base = $$dirInfo{Base} || 0;
    my $verbose = $et->Options('Verbose');
    my $dataPos = $$dirInfo{DataPos} || 0;

    # temporarily set Unknown option so GetTagInfo() will return existing unknown tags
    # (require to maintain serial data synchronization)
    my $unknown = $et->Options(Unknown => 1);
    # but disable unknown tag generation (because processing ends when we run out of tags)
    $$et{NO_UNKNOWN} = 1;

    $verbose and $et->VerboseDir('SerialData', undef, $size);

    # get default format ('int8u' unless specified)
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';

    my ($index, %val);
    my $pos = 0;
    for ($index=0; $$tagTablePtr{$index} and $pos <= $size; ++$index) {
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $index) or last;
        my $format = $$tagInfo{Format};
        my $count = 1;
        if ($format) {
            if ($format =~ /(.*)\[(.*)\]/) {
                $format = $1;
                $count = $2;
                # evaluate count to allow count to be based on previous values
                #### eval Format (%val, $size)
                $count = eval $count;
                $@ and warn("Format $$tagInfo{Name}: $@"), last;
            } elsif ($format eq 'string') {
                # allow string with no specified count to run to end of block
                $count = ($size > $pos) ? $size - $pos : 0;
            }
        } else {
            $format = $defaultFormat;
        }
        my $len = (Image::ExifTool::FormatSize($format) || 1) * $count;
        last if $pos + $len > $size;
        my $val = ReadValue($dataPt, $pos+$offset, $format, $count, $size-$pos);
        last unless defined $val;
        if ($verbose) {
            $et->VerboseInfo($index, $tagInfo,
                Index  => $index,
                Table  => $tagTablePtr,
                Value  => $val,
                DataPt => $dataPt,
                Size   => $len,
                Start  => $pos+$offset,
                Addr   => $pos+$offset+$base+$dataPos,
                Format => $format,
                Count  => $count,
            );
        }
        $val{$index} = $val;
        if ($$tagInfo{SubDirectory}) {
            my $subTablePtr = GetTagTable($$tagInfo{SubDirectory}{TagTable});
            my %dirInfo = (
                DataPt => \$val,
                DataPos => $dataPos + $pos,
                DirStart => 0,
                DirLen => length($val),
            );
            $et->ProcessDirectory(\%dirInfo, $subTablePtr);
        } elsif (not $$tagInfo{Unknown} or $unknown) {
            # don't extract zero-length information
            my $key = $et->FoundTag($tagInfo, $val) if $count;
            if ($key) {
                $$et{TAG_EXTRA}{$key}{G6} = $format if $$et{OPTIONS}{SaveFormat};
                $$et{TAG_EXTRA}{$key}{BinVal} = substr($$dataPt, $pos+$offset, $len) if $$et{OPTIONS}{SaveBin};
            }
        }
        $pos += $len;
    }
    $et->Options(Unknown => $unknown);    # restore Unknown option
    delete $$et{NO_UNKNOWN};
    return 1;
}

#------------------------------------------------------------------------------
# Print 1D AF points
# Inputs: 0) value to convert
# Focus point pattern:
#            A1  A2  A3  A4  A5  A6  A7
#      B1  B2  B3  B4  B5  B6  B7  B8  B9  B10
#    C1  C2  C3  C4  C5  C6  C7  C9  C9  C10  C11
#      D1  D2  D3  D4  D5  D6  D7  D8  D9  D10
#            E1  E2  E3  E4  E5  E6  E7
sub PrintAFPoints1D($)
{
    my $val = shift;
    return 'Unknown' unless length $val == 8;
    # list of focus point values for decoding the first byte of the 8-byte record.
    # they are the x/y positions of each bit in the AF point mask
    # (y is upper 3 bits / x is lower 5 bits)
    my @focusPts = (0,0,
              0x04,0x06,0x08,0x0a,0x0c,0x0e,0x10,         0,0,
      0x21,0x23,0x25,0x27,0x29,0x2b,0x2d,0x2f,0x31,0x33,
    0x40,0x42,0x44,0x46,0x48,0x4a,0x4c,0x4d,0x50,0x52,0x54,
      0x61,0x63,0x65,0x67,0x69,0x6b,0x6d,0x6f,0x71,0x73,  0,0,
              0x84,0x86,0x88,0x8a,0x8c,0x8e,0x90,   0,0,0,0,0
    );
    my $focus = unpack('C',$val);
    my @bits = split //, unpack('b*',substr($val,1));
    my @rows = split //, '  AAAAAAA  BBBBBBBBBBCCCCCCCCCCCDDDDDDDDDD  EEEEEEE     ';
    my ($focusing, $focusPt, @points);
    my $lastRow = '';
    my $col = 0;
    foreach $focusPt (@focusPts) {
        my $row = shift @rows;
        $col = ($row eq $lastRow) ? $col + 1 : 1;
        $lastRow = $row;
        $focusing = "$row$col" if $focus eq $focusPt;
        push @points, "$row$col" if shift @bits;
    }
    $focusing or $focusing = ($focus == 0xff) ? 'Auto' : sprintf('Unknown (0x%.2x)',$focus);
    return "$focusing (" . join(',',@points) . ')';
}

#------------------------------------------------------------------------------
# Convert Canon hex-based EV (modulo 0x20) to real number
# Inputs: 0) value to convert
# eg) 0x00 -> 0
#     0x0c -> 0.33333
#     0x10 -> 0.5
#     0x14 -> 0.66666
#     0x20 -> 1   ...  etc
sub CanonEv($)
{
    my $val = shift;
    my $sign;
    # temporarily make the number positive
    if ($val < 0) {
        $val = -$val;
        $sign = -1;
    } else {
        $sign = 1;
    }
    my $frac = $val & 0x1f;
    $val -= $frac;      # remove fraction
    # Convert 1/3 and 2/3 codes
    if ($frac == 0x0c) {
        $frac = 0x20 / 3;
    } elsif ($frac == 0x14) {
        $frac = 0x40 / 3;
    }
    return $sign * ($val + $frac) / 0x20;
}

#------------------------------------------------------------------------------
# Convert number to Canon hex-based EV (modulo 0x20)
# Inputs: 0) number
# Returns: Canon EV code
sub CanonEvInv($)
{
    my $num = shift;
    my $sign;
    # temporarily make the number positive
    if ($num < 0) {
        $num = -$num;
        $sign = -1;
    } else {
        $sign = 1;
    }
    my $val = int($num);
    my $frac = $num - $val;
    if (abs($frac - 0.33) < 0.05) {
        $frac = 0x0c
    } elsif (abs($frac - 0.67) < 0.05) {
        $frac = 0x14;
    } else {
        $frac = int($frac * 0x20 + 0.5);
    }
    return $sign * ($val * 0x20 + $frac);
}

#------------------------------------------------------------------------------
# Read CMT3 maker notes from CR3 file
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table ref
# Returns: data block (may be empty if no Exif data) or undef on error
sub ProcessCMT3($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;

    # extract the static maker notes to copying to other file types if requested
    # Note: this won't copy makernotes in the timed metadata since these are stored
    # separately, but the only records they have that aren't in the static maker notes
    # (for the M50) are: ColorData9, Flavor, CanonCameraInfoUnknown,
    # VignettingCorrUnknown1, Canon_0x4033 and Canon_0x402e
    if (($et->Options('MakerNotes') or $$et{REQ_TAG_LOOKUP}{makernotecanon}) and
        $$dirInfo{DirLen} > 8)
    {
        my $dataPt = $$dirInfo{DataPt};
        # remove old (unused) trailer
        $$dataPt =~ s/(II\x2a\0|MM\0\x2a)\0{4,10}$//;
        # remove TIFF header and append as the Canon makernote trailer
        # (so offsets will be interpreted correctly)
        my $val = substr($$dataPt,8) . substr($$dataPt,0,8);
        $et->FoundTag($Image::ExifTool::Canon::uuid{CMT3}, \$val);
    }
    return $et->ProcessTIFF($dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Process CTMD EXIF information
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessExifInfo($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $start = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $start);
    my $dirEnd = $start + $dirLen;
    # loop through TIFF-format EXIF/MakerNote records
    my ($pos, $len, $tag);
    for ($pos = $start; $pos + 8 < $dirEnd; $pos += $len) {
        $len = Get32u($dataPt, $pos);
        $tag = Get32u($dataPt, $pos + 4);
        # test size/tag for valid ExifInfo (not EXIF in CRM files)
        last if $len < 8 or $pos + $len > $dirEnd or not $$tagTablePtr{$tag};
        $et->VerboseDir('ExifInfo', undef, $dirLen) if $pos == $start;
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => $dataPt,
            Base    => $$dirInfo{Base} + $pos + 8, # base for TIFF pointers
            DataPos => -($pos + 8), # (relative to Base)
            Start   => $pos + 8,
            Size    => $len - 8,
        );
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Canon Timed MetaData (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessCTMD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $verbose = $et->Options('Verbose');
    my $dirLen = length $$dataPt;
    my $pos = 0;
    SetByteOrder('II');
    while ($pos + 6 < $dirLen) {
        my $size = Get32u($dataPt, $pos);
        my $type = Get16u($dataPt, $pos + 4);
        # what is the meaning of the 6-byte header of these records?:
        #  type 1 - 00 00 00 01 zz zz - TimeStamp(CR3/CRM); zz=00(CR3),ff(CRM)
        #  type 3 - 00 00 00 01 zz zz - ? "ff ff ff ff"; zz=00(CR3),ff(CRM)
        #  type 4 - 00 00 00 01 ff ff - FocalInfo(CR3/CRM)
        #  type 5 - 00 00 00 01 ff ff - ExposureInfo(CR3/CRM)
        #  type 6 - 00 04 00 01 ff ff - ? "03 04 00 80 e0 15 ff ff"(CRM) [0x15e0 = ColorTemperature?]
        #  type 7 - xx yy 00 01 ff ff - ExifIFD + MakerNotes(CR3), ?(CRM); xxyy=0101(CR3),0004(CRM)
        #  type 8 - 01 yy 00 01 ff ff - MakerNotes(CR3), ?(CRM); yy=01(CR3),04(CRM)
        #  type 9 - 01 yy 00 01 ff ff - MakerNotes(CR3), ?(CRM); yy=01(CR3),00(CRM)
        #  type 10- 01 00 00 01 ff ff - ? (CRM)
        #  type 11- 01 00 00 01 ff ff - ? (CRM)
        # --> maybe yy == 01 for ExifInfo?
        $size < 12 and $et->Warn('Short CTMD record'), last;
        $pos + $size > $dirLen and $et->Warn('Truncated CTMD record'), last;
        $et->VerboseDir("CTMD type $type", undef, $size - 6);
        HexDump($dataPt, 6,     # dump 6-byte header
            Start  => $pos + 6,
            Addr   => $$dirInfo{Base} + $pos + 6,
            Prefix => $$et{INDENT},
            Out    => $et->Options('TextOut'),
        ) if $verbose > 2;
        if ($$tagTablePtr{$type}) {
            $et->HandleTag($tagTablePtr, $type, undef,
                DataPt  => $dataPt,
                Base    => $$dirInfo{Base},
                Start   => $pos + 12,
                Size    => $size - 12,
            );
        } elsif ($verbose) {
            $et->VerboseDump($dataPt, Len=>$size-12, Start=>$pos+12, DataPos=>$$dirInfo{Base});
        }
        $pos += $size;
    }
    $et->Warn('Error parsing Canon CTMD data', 1) if $pos != $dirLen;
    return 1;
}

#------------------------------------------------------------------------------
# Process a creative filter data
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessFilters($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $end = $pos + $dirLen;
    my $verbose = $et->Options('Verbose');

    return 0 if $dirLen < 8;
    my $numFilters = Get32u($dataPt, $pos + 4);
    $verbose and $et->VerboseDir('Creative Filter', $numFilters);
    $pos += 8;
    my ($i, $j, $err);
    for ($i=0; $i<$numFilters; ++$i) {
        # read filter structure:
        # 4 bytes - filter number
        # 4 bytes - filter data length
        # 4 bytes - number of parameters:
        # |  4 bytes - parameter ID
        # |  4 bytes - parameter value count
        # |  4 bytes * count - parameter values (NC)
        $pos + 12 > $end and $err = "Truncated data for filter $i", last;
        my $fnum = Get32u($dataPt, $pos); # (is this an index or an ID?)
        my $size = Get32u($dataPt, $pos + 4);
        my $nparm = Get32u($dataPt, $pos + 8);
        my $nxt = $pos + 4 + $size;
        $nxt > $end and $err = "Invalid size ($size) for filter $i", last;
        $verbose and $et->VerboseDir("Filter $fnum", $nparm, $size);
        $pos += 12;
        for ($j=0; $j<$nparm; ++$j) {
            $pos + 12 > $end and $err = "Truncated data for filter $i param $j", last;
            my $tag = Get32u($dataPt, $pos);
            my $count = Get32u($dataPt, $pos + 4);
            $pos += 8;
            $pos + 4 * $count > $end and $err = "Truncated value for filter $i param $j", last;
            my $val = ReadValue($dataPt, $pos, 'int32s', $count, 4 * $count);
            $et->HandleTag($tagTablePtr, $tag, $val,
                DataPt  => $dataPt,
                DataPos => $dataPos,
                Start   => $pos,
                Size    => 4 * $count,
            );
            $pos += 4 * $count;
        }
        $pos = $nxt;    # step to next filter
    }
    $err and $et->Warn($err, 1);
    return 1;
}

#------------------------------------------------------------------------------
# Write Canon maker notes
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table ref
# Returns: data block (may be empty if no Exif data) or undef on error
sub WriteCanon($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $dirData = Image::ExifTool::Exif::WriteExif($et, $dirInfo, $tagTablePtr);
    # add footer which is written by some Canon models (format of a TIFF header)
    if (defined $dirData and length $dirData and $$dirInfo{Fixup}) {
        $dirData .= GetByteOrder() . Set16u(42) . Set32u(0);
        $$dirInfo{Fixup}->AddFixup(length($dirData) - 4);
    }
    return $dirData;
}

#------------------------------------------------------------------------------
1;  # end

__END__

=head1 NAME

Image::ExifTool::Canon - Canon EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Canon maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.wonderland.org/crw/>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://homepage3.nifty.com/kamisaka/makernote/makernote_canon.htm>

=item (...plus lots of testing with my 300D, A570IS and G12!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks Michael Rommel and Daniel Pittman for information they provided about
the Digital Ixus and PowerShot S70 cameras, Juha Eskelinen and Emil Sit for
figuring out the 20D and 30D FileNumber, Denny Priebe for figuring out a
couple of 1D tags, and Michael Tiemann, Rainer Honle, Dave Nicholson, Chris
Huebsch, Ger Vermeulen, Darryl Zurn, D.J. Cristi, Bogdan, Vesa Kivisto and
Kai Harrekilde-Petersen for decoding a number of new tags.  Also thanks to
everyone who made contributions to the LensType lookup list or the meanings
of other tag values.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Canon Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
