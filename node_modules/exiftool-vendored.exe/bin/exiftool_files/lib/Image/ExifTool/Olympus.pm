#------------------------------------------------------------------------------
# File:         Olympus.pm
#
# Description:  Olympus/Epson EXIF maker notes tags
#
# Revisions:    12/09/2003 - P. Harvey Created
#               11/11/2004 - P. Harvey Added Epson support
#
# References:   1) http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html
#               2) http://www.cybercom.net/~dcoffin/dcraw/
#               3) http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html
#               4) Markku Hanninen private communication (tests with E-1)
#               5) Remi Guyomarch from http://forums.dpreview.com/forums/read.asp?forum=1022&message=12790396
#               6) Frank Ledwon private communication (tests with E/C-series cameras)
#               7) Michael Meissner private communication
#               8) Shingo Noguchi, PhotoXP (http://www.daifukuya.com/photoxp/)
#               9) Mark Dapoz private communication
#              10) Lilo Huang private communication (E-330)
#              11) http://olypedia.de/Olympus_Makernotes (May 30, 2013)
#              12) Ioannis Panagiotopoulos private communication (E-510)
#              13) Chris Shaw private communication (E-3)
#              14) Viktor Lushnikov private communication (E-400)
#              15) Yrjo Rauste private communication (E-30)
#              16) Godfrey DiGiorgi private communication (E-P1) + http://forums.dpreview.com/forums/read.asp?message=33187567
#              17) Martin Hibers private communication
#              18) Tomasz Kawecki private communication
#              19) Brad Grier private communication
#              22) Herbert Kauer private communication
#              23) Daniel Pollock private communication (PEN-F)
#              24) Sebastian private communication (E-M1 Mark III)
#              25) Karsten Gieselmann private communication (OM series)
#              IB) Iliah Borg private communication (LibRaw)
#              NJ) Niels Kristian Bech Jensen private communication
#              KG) Karsten Gieselmann private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Olympus;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::APP12;

$VERSION = '2.93';

sub PrintLensInfo($$$);

my %offOn = ( 0 => 'Off', 1 => 'On' );

# lookup for Olympus LensType values
# (as of ExifTool 9.15, this was the complete list of chipped lenses at www.four-thirds.org)
my %olympusLensTypes = (
    Notes => q{
        The numerical values below are given in hexadecimal.  (Prior to ExifTool
        9.15 these were in decimal.)
    },
    '0 00 00' => 'None',
    # Olympus lenses (also Kenko Tokina)
    '0 01 00' => 'Olympus Zuiko Digital ED 50mm F2.0 Macro',
    '0 01 01' => 'Olympus Zuiko Digital 40-150mm F3.5-4.5', #8
    '0 01 10' => 'Olympus M.Zuiko Digital ED 14-42mm F3.5-5.6', #PH (E-P1 pre-production)
    '0 02 00' => 'Olympus Zuiko Digital ED 150mm F2.0',
    '0 02 10' => 'Olympus M.Zuiko Digital 17mm F2.8 Pancake', #PH (E-P1 pre-production)
    '0 03 00' => 'Olympus Zuiko Digital ED 300mm F2.8',
    '0 03 10' => 'Olympus M.Zuiko Digital ED 14-150mm F4.0-5.6 [II]', #11 (The second version of this lens seems to have the same lens ID number as the first version #NJ)
    '0 04 10' => 'Olympus M.Zuiko Digital ED 9-18mm F4.0-5.6', #11
    '0 05 00' => 'Olympus Zuiko Digital 14-54mm F2.8-3.5',
    '0 05 01' => 'Olympus Zuiko Digital Pro ED 90-250mm F2.8', #9
    '0 05 10' => 'Olympus M.Zuiko Digital ED 14-42mm F3.5-5.6 L', #11 (E-PL1)
    '0 06 00' => 'Olympus Zuiko Digital ED 50-200mm F2.8-3.5',
    '0 06 01' => 'Olympus Zuiko Digital ED 8mm F3.5 Fisheye', #9
    '0 06 10' => 'Olympus M.Zuiko Digital ED 40-150mm F4.0-5.6', #PH
    '0 07 00' => 'Olympus Zuiko Digital 11-22mm F2.8-3.5',
    '0 07 01' => 'Olympus Zuiko Digital 18-180mm F3.5-6.3', #6
    '0 07 10' => 'Olympus M.Zuiko Digital ED 12mm F2.0', #PH
    '0 08 01' => 'Olympus Zuiko Digital 70-300mm F4.0-5.6', #7 (seen as release 1 - PH)
    '0 08 10' => 'Olympus M.Zuiko Digital ED 75-300mm F4.8-6.7', #PH
    '0 09 10' => 'Olympus M.Zuiko Digital 14-42mm F3.5-5.6 II', #PH (E-PL2)
    '0 10 01' => 'Kenko Tokina Reflex 300mm F6.3 MF Macro', #NJ
    '0 10 10' => 'Olympus M.Zuiko Digital ED 12-50mm F3.5-6.3 EZ', #PH
    '0 11 10' => 'Olympus M.Zuiko Digital 45mm F1.8', #17
    '0 12 10' => 'Olympus M.Zuiko Digital ED 60mm F2.8 Macro', #NJ
    '0 13 10' => 'Olympus M.Zuiko Digital 14-42mm F3.5-5.6 II R', #PH/NJ
    '0 14 10' => 'Olympus M.Zuiko Digital ED 40-150mm F4.0-5.6 R', #19
  # '0 14 10.1' => 'Olympus M.Zuiko Digital ED 14-150mm F4.0-5.6 II', #11 (questionable & unconfirmed -- all samples I can find are '0 3 10' - PH)
    '0 15 00' => 'Olympus Zuiko Digital ED 7-14mm F4.0',
    '0 15 10' => 'Olympus M.Zuiko Digital ED 75mm F1.8', #PH
    '0 16 10' => 'Olympus M.Zuiko Digital 17mm F1.8', #NJ
    '0 17 00' => 'Olympus Zuiko Digital Pro ED 35-100mm F2.0', #7
    '0 18 00' => 'Olympus Zuiko Digital 14-45mm F3.5-5.6',
    '0 18 10' => 'Olympus M.Zuiko Digital ED 75-300mm F4.8-6.7 II', #NJ
    '0 19 10' => 'Olympus M.Zuiko Digital ED 12-40mm F2.8 Pro', #PH
    '0 20 00' => 'Olympus Zuiko Digital 35mm F3.5 Macro', #9
    '0 20 10' => 'Olympus M.Zuiko Digital ED 40-150mm F2.8 Pro', #NJ
    '0 21 10' => 'Olympus M.Zuiko Digital ED 14-42mm F3.5-5.6 EZ', #NJ
    '0 22 00' => 'Olympus Zuiko Digital 17.5-45mm F3.5-5.6', #9
    '0 22 10' => 'Olympus M.Zuiko Digital 25mm F1.8', #NJ
    '0 23 00' => 'Olympus Zuiko Digital ED 14-42mm F3.5-5.6', #PH
    '0 23 10' => 'Olympus M.Zuiko Digital ED 7-14mm F2.8 Pro', #NJ
    '0 24 00' => 'Olympus Zuiko Digital ED 40-150mm F4.0-5.6', #PH
    '0 24 10' => 'Olympus M.Zuiko Digital ED 300mm F4.0 IS Pro', #NJ
    '0 25 10' => 'Olympus M.Zuiko Digital ED 8mm F1.8 Fisheye Pro', #NJ
    '0 26 10' => 'Olympus M.Zuiko Digital ED 12-100mm F4.0 IS Pro', #IB/NJ
    '0 27 10' => 'Olympus M.Zuiko Digital ED 30mm F3.5 Macro', #IB/NJ
    '0 28 10' => 'Olympus M.Zuiko Digital ED 25mm F1.2 Pro', #IB/NJ
    '0 29 10' => 'Olympus M.Zuiko Digital ED 17mm F1.2 Pro', #IB
    '0 30 00' => 'Olympus Zuiko Digital ED 50-200mm F2.8-3.5 SWD', #7
    '0 30 10' => 'Olympus M.Zuiko Digital ED 45mm F1.2 Pro', #IB
    '0 31 00' => 'Olympus Zuiko Digital ED 12-60mm F2.8-4.0 SWD', #7
    '0 32 00' => 'Olympus Zuiko Digital ED 14-35mm F2.0 SWD', #PH
    '0 32 10' => 'Olympus M.Zuiko Digital ED 12-200mm F3.5-6.3', #IB
    '0 33 00' => 'Olympus Zuiko Digital 25mm F2.8', #PH
    '0 33 10' => 'Olympus M.Zuiko Digital 150-400mm F4.5 TC1.25x IS Pro', #IB
    '0 34 00' => 'Olympus Zuiko Digital ED 9-18mm F4.0-5.6', #7
    '0 34 10' => 'Olympus M.Zuiko Digital ED 12-45mm F4.0 Pro', #IB
    '0 35 00' => 'Olympus Zuiko Digital 14-54mm F2.8-3.5 II', #PH
    '0 35 10' => 'Olympus M.Zuiko 100-400mm F5.0-6.3', #IB (also OM System M.Zuiko Digital ED 100-400mm F5.0-6.3 IS II", forum2833)
    '0 36 10' => 'Olympus M.Zuiko Digital ED 8-25mm F4 Pro', #IB
    '0 37 10' => 'Olympus M.Zuiko Digital ED 40-150mm F4.0 Pro', #forum3833
    '0 38 10' => 'Olympus M.Zuiko Digital ED 20mm F1.4 Pro',
    '0 39 10' => 'Olympus M.Zuiko Digital ED 90mm F3.5 Macro IS Pro', #forum3833
    '0 40 10' => 'Olympus M.Zuiko Digital ED 150-600mm F5.0-6.3', #forum15652
    '0 41 10' => 'OM System M.Zuiko Digital ED 50-200mm F2.8 IS Pro', #github#352
    # Sigma lenses
    '1 01 00' => 'Sigma 18-50mm F3.5-5.6 DC', #8
    '1 01 10' => 'Sigma 30mm F2.8 EX DN', #NJ
    '1 02 00' => 'Sigma 55-200mm F4.0-5.6 DC',
    '1 02 10' => 'Sigma 19mm F2.8 EX DN', #NJ
    '1 03 00' => 'Sigma 18-125mm F3.5-5.6 DC',
    '1 03 10' => 'Sigma 30mm F2.8 DN | A', #NJ
    '1 04 00' => 'Sigma 18-125mm F3.5-5.6 DC', #7
    '1 04 10' => 'Sigma 19mm F2.8 DN | A', #NJ
    '1 05 00' => 'Sigma 30mm F1.4 EX DC HSM', #10
    '1 05 10' => 'Sigma 60mm F2.8 DN | A', #NJ
    '1 06 00' => 'Sigma APO 50-500mm F4.0-6.3 EX DG HSM', #6
    '1 06 10' => 'Sigma 30mm F1.4 DC DN | C', #NJ
    '1 07 00' => 'Sigma Macro 105mm F2.8 EX DG', #PH
    '1 07 10' => 'Sigma 16mm F1.4 DC DN | C (017)', #IB
    '1 08 00' => 'Sigma APO Macro 150mm F2.8 EX DG HSM', #PH
    '1 09 00' => 'Sigma 18-50mm F2.8 EX DC Macro', #NJ
    '1 10 00' => 'Sigma 24mm F1.8 EX DG Aspherical Macro', #PH
    '1 11 00' => 'Sigma APO 135-400mm F4.5-5.6 DG', #11
    '1 12 00' => 'Sigma APO 300-800mm F5.6 EX DG HSM', #11
    '1 13 00' => 'Sigma 30mm F1.4 EX DC HSM', #11
    '1 14 00' => 'Sigma APO 50-500mm F4.0-6.3 EX DG HSM', #11
    '1 15 00' => 'Sigma 10-20mm F4.0-5.6 EX DC HSM', #11
    '1 16 00' => 'Sigma APO 70-200mm F2.8 II EX DG Macro HSM', #11
    '1 17 00' => 'Sigma 50mm F1.4 EX DG HSM', #11
    # Panasonic/Leica lenses
    '2 01 00' => 'Leica D Vario Elmarit 14-50mm F2.8-3.5 Asph.', #11
    '2 01 10' => 'Lumix G Vario 14-45mm F3.5-5.6 Asph. Mega OIS', #16
    '2 02 00' => 'Leica D Summilux 25mm F1.4 Asph.', #11
    '2 02 10' => 'Lumix G Vario 45-200mm F4.0-5.6 Mega OIS', #16
    '2 03 00' => 'Leica D Vario Elmar 14-50mm F3.8-5.6 Asph. Mega OIS', #11
    '2 03 01' => 'Leica D Vario Elmar 14-50mm F3.8-5.6 Asph.', #14 (L10 kit)
    '2 03 10' => 'Lumix G Vario HD 14-140mm F4.0-5.8 Asph. Mega OIS', #16
    '2 04 00' => 'Leica D Vario Elmar 14-150mm F3.5-5.6', #13
    '2 04 10' => 'Lumix G Vario 7-14mm F4.0 Asph.', #PH (E-P1 pre-production)
    '2 05 10' => 'Lumix G 20mm F1.7 Asph.', #16
    '2 06 10' => 'Leica DG Macro-Elmarit 45mm F2.8 Asph. Mega OIS', #PH
    '2 07 10' => 'Lumix G Vario 14-42mm F3.5-5.6 Asph. Mega OIS', #NJ
    '2 08 10' => 'Lumix G Fisheye 8mm F3.5', #PH
    '2 09 10' => 'Lumix G Vario 100-300mm F4.0-5.6 Mega OIS', #11
    '2 10 10' => 'Lumix G 14mm F2.5 Asph.', #17
    '2 11 10' => 'Lumix G 12.5mm F12 3D', #NJ (H-FT012)
    '2 12 10' => 'Leica DG Summilux 25mm F1.4 Asph.', #NJ
    '2 13 10' => 'Lumix G X Vario PZ 45-175mm F4.0-5.6 Asph. Power OIS', #NJ
    '2 14 10' => 'Lumix G X Vario PZ 14-42mm F3.5-5.6 Asph. Power OIS', #NJ
    '2 15 10' => 'Lumix G X Vario 12-35mm F2.8 Asph. Power OIS', #PH
    '2 16 10' => 'Lumix G Vario 45-150mm F4.0-5.6 Asph. Mega OIS', #NJ
    '2 17 10' => 'Lumix G X Vario 35-100mm F2.8 Power OIS', #PH
    '2 18 10' => 'Lumix G Vario 14-42mm F3.5-5.6 II Asph. Mega OIS', #NJ
    '2 19 10' => 'Lumix G Vario 14-140mm F3.5-5.6 Asph. Power OIS', #NJ
    '2 20 10' => 'Lumix G Vario 12-32mm F3.5-5.6 Asph. Mega OIS', #NJ
    '2 21 10' => 'Leica DG Nocticron 42.5mm F1.2 Asph. Power OIS', #NJ
    '2 22 10' => 'Leica DG Summilux 15mm F1.7 Asph.', #NJ
    '2 23 10' => 'Lumix G Vario 35-100mm F4.0-5.6 Asph. Mega OIS', #NJ
    '2 24 10' => 'Lumix G Macro 30mm F2.8 Asph. Mega OIS', #NJ
    '2 25 10' => 'Lumix G 42.5mm F1.7 Asph. Power OIS', #NJ
    '2 26 10' => 'Lumix G 25mm F1.7 Asph.', #NJ
    '2 27 10' => 'Leica DG Vario-Elmar 100-400mm F4.0-6.3 Asph. Power OIS', #NJ
    '2 28 10' => 'Lumix G Vario 12-60mm F3.5-5.6 Asph. Power OIS', #NJ
    '2 29 10' => 'Leica DG Summilux 12mm F1.4 Asph.', #IB
    '2 30 10' => 'Leica DG Vario-Elmarit 12-60mm F2.8-4 Asph. Power OIS', #IB
    '2 31 10' => 'Lumix G Vario 45-200mm F4.0-5.6 II', #forum3833
    '2 32 10' => 'Lumix G Vario 100-300mm F4.0-5.6 II', #PH
    '2 33 10' => 'Lumix G X Vario 12-35mm F2.8 II Asph. Power OIS', #IB
    '2 34 10' => 'Lumix G Vario 35-100mm F2.8 II', #forum3833
    '2 35 10' => 'Leica DG Vario-Elmarit 8-18mm F2.8-4 Asph.', #IB
    '2 36 10' => 'Leica DG Elmarit 200mm F2.8 Power OIS', #IB
    '2 37 10' => 'Leica DG Vario-Elmarit 50-200mm F2.8-4 Asph. Power OIS', #IB
    '2 38 10' => 'Leica DG Vario-Summilux 10-25mm F1.7 Asph.', #IB
    '2 39 10' => 'Leica DG Summilux 25mm F1.4 II Asph.', #forum15345
    '2 40 10' => 'Leica DG Vario-Summilux 25-50mm F1.7 Asph.', #IB (H-X2550)
    '2 41 10' => 'Leica DG Summilux 9mm F1.7 Asph.', #forum15345
    '3 01 00' => 'Leica D Vario Elmarit 14-50mm F2.8-3.5 Asph.', #11
    '3 02 00' => 'Leica D Summilux 25mm F1.4 Asph.', #11
    # Tamron lenses
    '5 01 10' => 'Tamron 14-150mm F3.5-5.8 Di III', #NJ (model C001)
  # '65535 07 40' - Seen for LUMIX S 16-35/F4 on Panasonic DC-S1H (ref PH)
    # Other makes
    '24 01 10' => 'Venus Optics Laowa 50mm F2.8 2x Macro', #DonKomarechka
    '247 03 10' => 'LAOWA C&D-Dreamer MFT 7.5mm F2.0', #forum3833
    '247 10 10' => 'LAOWA C&D-Dreamer MFT 6.0mm F2.0', #KG
    '65522 02 10' => 'Xiaoyi 42.5mm F1.8', #github363
);

# lookup for Olympus camera types (ref PH)
my %olympusCameraTypes = (
    Notes => q{
        These values are currently decoded only for Olympus models.  Models with
        Olympus-style maker notes from other brands such as Acer, BenQ, Hitachi, HP,
        Premier, Konica-Minolta, Maginon, Ricoh, Rollei, SeaLife, Sony, Supra,
        Vivitar are not listed.
    },
    D4028 => 'X-2,C-50Z',
    D4029 => 'E-20,E-20N,E-20P',
    D4034 => 'C720UZ',
    D4040 => 'E-1',
    D4041 => 'E-300',
    D4083 => 'C2Z,D520Z,C220Z',
    D4106 => 'u20D,S400D,u400D',
    D4120 => 'X-1',
    D4122 => 'u10D,S300D,u300D',
    D4125 => 'AZ-1',
    D4141 => 'C150,D390',
    D4193 => 'C-5000Z',
    D4194 => 'X-3,C-60Z',
    D4199 => 'u30D,S410D,u410D',
    D4205 => 'X450,D535Z,C370Z',
    D4210 => 'C160,D395',
    D4211 => 'C725UZ',
    D4213 => 'FerrariMODEL2003',
    D4216 => 'u15D',
    D4217 => 'u25D',
    D4220 => 'u-miniD,Stylus V',
    D4221 => 'u40D,S500,uD500',
    D4231 => 'FerrariMODEL2004',
    D4240 => 'X500,D590Z,C470Z',
    D4244 => 'uD800,S800',
    D4256 => 'u720SW,S720SW',
    D4261 => 'X600,D630,FE5500',
    D4262 => 'uD600,S600',
    D4301 => 'u810/S810', # (yes, "/".  Olympus is not consistent in the notation)
    D4302 => 'u710,S710',
    D4303 => 'u700,S700',
    D4304 => 'FE100,X710',
    D4305 => 'FE110,X705',
    D4310 => 'FE-130,X-720',
    D4311 => 'FE-140,X-725',
    D4312 => 'FE150,X730',
    D4313 => 'FE160,X735',
    D4314 => 'u740,S740',
    D4315 => 'u750,S750',
    D4316 => 'u730/S730',
    D4317 => 'FE115,X715',
    D4321 => 'SP550UZ',
    D4322 => 'SP510UZ',
    D4324 => 'FE170,X760',
    D4326 => 'FE200',
    D4327 => 'FE190/X750', # (also SX876)
    D4328 => 'u760,S760',
    D4330 => 'FE180/X745', # (also SX875)
    D4331 => 'u1000/S1000',
    D4332 => 'u770SW,S770SW',
    D4333 => 'FE240/X795',
    D4334 => 'FE210,X775',
    D4336 => 'FE230/X790',
    D4337 => 'FE220,X785',
    D4338 => 'u725SW,S725SW',
    D4339 => 'FE250/X800',
    D4341 => 'u780,S780',
    D4343 => 'u790SW,S790SW',
    D4344 => 'u1020,S1020',
    D4346 => 'FE15,X10',
    D4348 => 'FE280,X820,C520',
    D4349 => 'FE300,X830',
    D4350 => 'u820,S820',
    D4351 => 'u1200,S1200',
    D4352 => 'FE270,X815,C510',
    D4353 => 'u795SW,S795SW',
    D4354 => 'u1030SW,S1030SW',
    D4355 => 'SP560UZ',
    D4356 => 'u1010,S1010',
    D4357 => 'u830,S830',
    D4359 => 'u840,S840',
    D4360 => 'FE350WIDE,X865',
    D4361 => 'u850SW,S850SW',
    D4362 => 'FE340,X855,C560',
    D4363 => 'FE320,X835,C540',
    D4364 => 'SP570UZ',
    D4366 => 'FE330,X845,C550',
    D4368 => 'FE310,X840,C530',
    D4370 => 'u1050SW,S1050SW',
    D4371 => 'u1060,S1060',
    D4372 => 'FE370,X880,C575',
    D4374 => 'SP565UZ',
    D4377 => 'u1040,S1040',
    D4378 => 'FE360,X875,C570',
    D4379 => 'FE20,X15,C25',
    D4380 => 'uT6000,ST6000',
    D4381 => 'uT8000,ST8000',
    D4382 => 'u9000,S9000',
    D4384 => 'SP590UZ',
    D4385 => 'FE3010,X895',
    D4386 => 'FE3000,X890',
    D4387 => 'FE35,X30',
    D4388 => 'u550WP,S550WP',
    D4390 => 'FE5000,X905',
    D4391 => 'u5000',
    D4392 => 'u7000,S7000',
    D4396 => 'FE5010,X915',
    D4397 => 'FE25,X20',
    D4398 => 'FE45,X40',
    D4401 => 'XZ-1',
    D4402 => 'uT6010,ST6010',
    D4406 => 'u7010,S7010 / u7020,S7020',
    D4407 => 'FE4010,X930',
    D4408 => 'X560WP',
    D4409 => 'FE26,X21',
    D4410 => 'FE4000,X920,X925',
    D4411 => 'FE46,X41,X42',
    D4412 => 'FE5020,X935',
    D4413 => 'uTough-3000',
    D4414 => 'StylusTough-6020',
    D4415 => 'StylusTough-8010',
    D4417 => 'u5010,S5010',
    D4418 => 'u7040,S7040',
    D4419 => 'u9010,S9010',
    D4423 => 'FE4040',
    D4424 => 'FE47,X43',
    D4426 => 'FE4030,X950',
    D4428 => 'FE5030,X965,X960',
    D4430 => 'u7030,S7030',
    D4432 => 'SP600UZ',
    D4434 => 'SP800UZ',
    D4439 => 'FE4020,X940',
    D4442 => 'FE5035',
    D4448 => 'FE4050,X970',
    D4450 => 'FE5050,X985',
    D4454 => 'u-7050',
    D4464 => 'T10,X27',
    D4470 => 'FE5040,X980',
    D4472 => 'TG-310',
    D4474 => 'TG-610',
    D4476 => 'TG-810',
    D4478 => 'VG145,VG140,D715',
    D4479 => 'VG130,D710',
    D4480 => 'VG120,D705',
    D4482 => 'VR310,D720',
    D4484 => 'VR320,D725',
    D4486 => 'VR330,D730',
    D4488 => 'VG110,D700',
    D4490 => 'SP-610UZ',
    D4492 => 'SZ-10',
    D4494 => 'SZ-20',
    D4496 => 'SZ-30MR',
    D4498 => 'SP-810UZ',
    D4500 => 'SZ-11',
    D4504 => 'TG-615',
    D4508 => 'TG-620',
    D4510 => 'TG-820',
    D4512 => 'TG-1',
    D4516 => 'SH-21',
    D4519 => 'SZ-14',
    D4520 => 'SZ-31MR',
    D4521 => 'SH-25MR',
    D4523 => 'SP-720UZ',
    D4529 => 'VG170',
    D4530 => 'VH210',
    D4531 => 'XZ-2',
    D4535 => 'SP-620UZ',
    D4536 => 'TG-320',
    D4537 => 'VR340,D750',
    D4538 => 'VG160,X990,D745',
    D4541 => 'SZ-12',
    D4545 => 'VH410',
    D4546 => 'XZ-10', #IB
    D4547 => 'TG-2',
    D4548 => 'TG-830',
    D4549 => 'TG-630',
    D4550 => 'SH-50',
    D4553 => 'SZ-16,DZ-105',
    D4562 => 'SP-820UZ',
    D4566 => 'SZ-15',
    D4572 => 'STYLUS1',
    D4574 => 'TG-3',
    D4575 => 'TG-850',
    D4579 => 'SP-100EE',
    D4580 => 'SH-60',
    D4581 => 'SH-1',
    D4582 => 'TG-835',
    D4585 => 'SH-2 / SH-3',
    D4586 => 'TG-4',
    D4587 => 'TG-860',
    D4590 => 'TG-TRACKER',
    D4591 => 'TG-870',
    D4593 => 'TG-5', #IB
    D4603 => 'TG-6', #IB
    D4605 => 'TG-7',
    D4809 => 'C2500L',
    D4842 => 'E-10',
    D4856 => 'C-1',
    D4857 => 'C-1Z,D-150Z',
    DCHC => 'D500L',
    DCHT => 'D600L / D620L',
    K0055 => 'AIR-A01',
    S0003 => 'E-330',
    S0004 => 'E-500',
    S0009 => 'E-400',
    S0010 => 'E-510',
    S0011 => 'E-3',
    S0013 => 'E-410',
    S0016 => 'E-420',
    S0017 => 'E-30',
    S0018 => 'E-520',
    S0019 => 'E-P1',
    S0023 => 'E-620',
    S0026 => 'E-P2',
    S0027 => 'E-PL1',
    S0029 => 'E-450',
    S0030 => 'E-600',
    S0032 => 'E-P3',
    S0033 => 'E-5',
    S0034 => 'E-PL2',
    S0036 => 'E-M5',
    S0038 => 'E-PL3',
    S0039 => 'E-PM1',
    S0040 => 'E-PL1s',
    S0042 => 'E-PL5',
    S0043 => 'E-PM2',
    S0044 => 'E-P5',
    S0045 => 'E-PL6',
    S0046 => 'E-PL7', #IB
    S0047 => 'E-M1',
    S0051 => 'E-M10',
    S0052 => 'E-M5MarkII', #IB
    S0059 => 'E-M10MarkII',
    S0061 => 'PEN-F', #forum7005
    S0065 => 'E-PL8',
    S0067 => 'E-M1MarkII',
    S0068 => 'E-M10MarkIII',
    S0076 => 'E-PL9', #IB
    S0080 => 'E-M1X', #IB
    S0085 => 'E-PL10', #IB
    S0088 => 'E-M10MarkIV',
    S0089 => 'E-M5MarkIII',
    S0092 => 'E-M1MarkIII', #IB
    S0093 => 'E-P7', #IB
    S0094 => 'E-M10MarkIIIS', #forum17050
    S0095 => 'OM-1', #IB
    S0101 => 'OM-5', #IB
    S0121 => 'OM-1MarkII', #forum15652
    S0123 => 'OM-3', #forum17208
    S0130 => 'OM-5MarkII', #forum17465
    SR45 => 'D220',
    SR55 => 'D320L',
    SR83 => 'D340L',
    SR85 => 'C830L,D340R',
    SR852 => 'C860L,D360L',
    SR872 => 'C900Z,D400Z',
    SR874 => 'C960Z,D460Z',
    SR951 => 'C2000Z',
    SR952 => 'C21',
    SR953 => 'C21T.commu',
    SR954 => 'C2020Z',
    SR955 => 'C990Z,D490Z',
    SR956 => 'C211Z',
    SR959 => 'C990ZS,D490Z',
    SR95A => 'C2100UZ',
    SR971 => 'C100,D370',
    SR973 => 'C2,D230',
    SX151 => 'E100RS',
    SX351 => 'C3000Z / C3030Z',
    SX354 => 'C3040Z',
    SX355 => 'C2040Z',
    SX357 => 'C700UZ',
    SX358 => 'C200Z,D510Z',
    SX374 => 'C3100Z,C3020Z',
    SX552 => 'C4040Z',
    SX553 => 'C40Z,D40Z',
    SX556 => 'C730UZ',
    SX558 => 'C5050Z',
    SX571 => 'C120,D380',
    SX574 => 'C300Z,D550Z',
    SX575 => 'C4100Z,C4000Z',
    SX751 => 'X200,D560Z,C350Z',
    SX752 => 'X300,D565Z,C450Z',
    SX753 => 'C750UZ',
    SX754 => 'C740UZ',
    SX755 => 'C755UZ',
    SX756 => 'C5060WZ',
    SX757 => 'C8080WZ',
    SX758 => 'X350,D575Z,C360Z',
    SX759 => 'X400,D580Z,C460Z',
    SX75A => 'AZ-2ZOOM',
    SX75B => 'D595Z,C500Z',
    SX75C => 'X550,D545Z,C480Z',
    SX75D => 'IR-300',
    SX75F => 'C55Z,C5500Z',
    SX75G => 'C170,D425',
    SX75J => 'C180,D435',
    SX771 => 'C760UZ',
    SX772 => 'C770UZ',
    SX773 => 'C745UZ',
    SX774 => 'X250,D560Z,C350Z',
    SX775 => 'X100,D540Z,C310Z',
    SX776 => 'C460ZdelSol',
    SX777 => 'C765UZ',
    SX77A => 'D555Z,C315Z',
    SX851 => 'C7070WZ',
    SX852 => 'C70Z,C7000Z',
    SX853 => 'SP500UZ',
    SX854 => 'SP310',
    SX855 => 'SP350',
    SX873 => 'SP320',
    SX875 => 'FE180/X745', # (also D4330)
    SX876 => 'FE190/X750', # (also D4327)
#   other brands
#    4MP9Q3 => 'Camera 4MP-9Q3'
#    4MP9T2 => 'BenQ DC C420 / Camera 4MP-9T2'
#    5MP9Q3 => 'Camera 5MP-9Q3',
#    5MP9X9 => 'Camera 5MP-9X9',
#   '5MP-9T'=> 'Camera 5MP-9T3',
#   '5MP-9Y'=> 'Camera 5MP-9Y2',
#   '6MP-9U'=> 'Camera 6MP-9U9',
#    7MP9Q3 => 'Camera 7MP-9Q3',
#   '8MP-9U'=> 'Camera 8MP-9U4',
#    CE5330 => 'Acer CE-5330',
#   'CP-853'=> 'Acer CP-8531',
#    CS5531 => 'Acer CS5531',
#    DC500  => 'SeaLife DC500',
#    DC7370 => 'Camera 7MP-9GA',
#    DC7371 => 'Camera 7MP-9GM',
#    DC7371 => 'Hitachi HDC-751E',
#    DC7375 => 'Hitachi HDC-763E / Rollei RCP-7330X / Ricoh Caplio RR770 / Vivitar ViviCam 7330',
#   'DC E63'=> 'BenQ DC E63+',
#   'DC P86'=> 'BenQ DC P860',
#    DS5340 => 'Maginon Performic S5 / Premier 5MP-9M7',
#    DS5341 => 'BenQ E53+ / Supra TCM X50 / Maginon X50 / Premier 5MP-9P8',
#    DS5346 => 'Premier 5MP-9Q2',
#    E500   => 'Konica Minolta DiMAGE E500',
#    MAGINO => 'Maginon X60',
#    Mz60   => 'HP Photosmart Mz60',
#    Q3DIGI => 'Camera 5MP-9Q3',
#    SLIMLI => 'Supra Slimline X6',
#    V8300s => 'Vivitar V8300s',
);

# ArtFilter, ArtFilterEffect and MagicFilter values (ref PH)
my %filters = (
    0 => 'Off',
    1 => 'Soft Focus', # (XZ-1)
    2 => 'Pop Art', # (SZ-10 magic filter 1,SZ-31MR,E-M5,E-PL3)
    3 => 'Pale & Light Color',
    4 => 'Light Tone',
    5 => 'Pin Hole', # (SZ-10 magic filter 2,SZ-31MR,E-PL3)
    6 => 'Grainy Film',
    8 => 'Underwater', #forum17348
    9 => 'Diorama',
    10 => 'Cross Process',
    12 => 'Fish Eye', # (SZ-10 magic filter 3)
    13 => 'Drawing', # (SZ-10 magic filter 4)
    14 => 'Gentle Sepia', # (E-5)
    15 => 'Pale & Light Color II', #forum6269 ('Tender Light' ref 11)
    16 => 'Pop Art II', #11 (E-PL3 "(dark)" - PH)
    17 => 'Pin Hole II', #11 (E-PL3 "(color 2)" - PH)
    18 => 'Pin Hole III', #11 (E-M5, E-PL3 "(color 3)" - PH)
    19 => 'Grainy Film II', #11
    20 => 'Dramatic Tone', # (XZ-1,SZ-31MR)
    21 => 'Punk', # (SZ-10 magic filter 6)
    22 => 'Soft Focus 2', # (SZ-10 magic filter 5)
    23 => 'Sparkle', # (SZ-10 magic filter 7)
    24 => 'Watercolor', # (SZ-10 magic filter 8)
    25 => 'Key Line', # (E-M5)
    26 => 'Key Line II', #forum6269
    27 => 'Miniature', # (SZ-31MR)
    28 => 'Reflection', # (TG-820,SZ-31MR)
    29 => 'Fragmented', # (TG-820,SZ-31MR)
    31 => 'Cross Process II', #forum6269
    32 => 'Dramatic Tone II',  #forum6269 (Dramatic Tone B&W for E-M5)
    33 => 'Watercolor I', # ('Watercolor I' for EM-1 ref forum6269, 'Watercolor II' for E-PM2 ref PH)
    34 => 'Watercolor II', #forum6269
    35 => 'Diorama II', #forum6269
    36 => 'Vintage', #forum6269
    37 => 'Vintage II', #forum6269
    38 => 'Vintage III', #forum6269
    39 => 'Partial Color', #forum6269
    40 => 'Partial Color II', #forum6269
    41 => 'Partial Color III', #forum6269
    42 => 'Bleach Bypass', #forum17348
    43 => 'Bleach Bypass II', #forum17348
    44 => 'Instant Film', #forum17348
);

my %toneLevelType = (
    0 => '0',
    -31999 => 'Highlights',
    -31998 => 'Shadows',
    -31997 => 'Midtones',
);

# tag information for WAV "Index" tags
my %indexInfo = (
    Format => 'int32u',
    RawConv => '$val == 0xffffffff ? undef : $val',
    ValueConv => '$val / 1000',
    PrintConv => 'ConvertDuration($val)',
);

# Olympus tags
%Image::ExifTool::Olympus::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
#
# Tags 0x0000 through 0x0103 are the same as Konica/Minolta cameras (ref 3)
# (removed 0x0101-0x0103 because they weren't supported by my samples - PH)
#
    0x0000 => {
        Name => 'MakerNoteVersion',
        Writable => 'undef',
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
        SubDirectory => {
            TagTable => 'Image::ExifTool::Minolta::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },
    0x0040 => {
        Name => 'CompressedImageSize',
        Writable => 'int32u',
    },
    0x0081 => {
        Name => 'PreviewImageData',
        Binary => 1,
        Writable => 0,
    },
    0x0088 => {
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x0089, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 0,
        Protected => 2,
    },
    0x0089 => {
        Name => 'PreviewImageLength',
        OffsetPair => 0x0088, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 0,
        Protected => 2,
    },
    0x0100 => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Writable => 'undef',
        WriteCheck => '$self->CheckImage(\$val)',
        Binary => 1,
    },
    0x0104 => { Name => 'BodyFirmwareVersion',    Writable => 'string' }, #11
#
# end Konica/Minolta tags
#
    0x0200 => {
        Name => 'SpecialMode',
        Notes => q{
            3 numbers: 1. Shooting mode: 0=Normal, 2=Fast, 3=Panorama;
            2. Sequence Number; 3. Panorama Direction: 1=Left-right,
            2=Right-left, 3=Bottom-Top, 4=Top-Bottom
        },
        Writable => 'int32u',
        Count => 3,
        PrintConv => sub { #3
            my $val = shift;
            my @v = split ' ', $val;
            return $val unless @v >= 3;
            my @v0 = ('Normal','Unknown (1)','Fast','Panorama');
            my @v2 = ('(none)','Left to Right','Right to Left','Bottom to Top','Top to Bottom');
            $val = $v0[$v[0]] || "Unknown ($v[0])";
            $val .= ", Sequence: $v[1]";
            $val .= ', Panorama: ' . ($v2[$v[2]] || "Unknown ($v[2])");
            return $val;
        },
    },
    0x0201 => {
        Name => 'Quality',
        Writable => 'int16u',
        Notes => q{
            Quality values are decoded based on the CameraType tag. All types
            represent SQ, HQ and SHQ as sequential integers, but in general
            SX-type cameras start with a value of 0 for SQ while others start
            with 1
        },
        # These values are different for different camera types
        # (can't have Condition based on CameraType because it isn't known
        #  when this tag is extracted)
        PrintConv => sub {
            my ($val, $self) = @_;
            my %t1 = ( # all SX camera types except SX151
                0 => 'SQ (Low)',
                1 => 'HQ (Normal)',
                2 => 'SHQ (Fine)',
                6 => 'RAW', #PH - C5050WZ
            );
            my %t2 = ( # all other types (except D4322, ref 22)
                1 => 'SQ (Low)',
                2 => 'HQ (Normal)',
                3 => 'SHQ (Fine)',
                4 => 'RAW',
                5 => 'Medium-Fine', #PH
                6 => 'Small-Fine', #PH
                33 => 'Uncompressed', #PH - C2100Z
            );
            my $conv = $self->{CameraType} =~ /^(SX(?!151\b)|D4322)/ ? \%t1 : \%t2;
            return $$conv{$val} ? $$conv{$val} : "Unknown ($val)";
        },
        # (no PrintConvInv because we don't know CameraType at write time)
    },
    0x0202 => {
        Name => 'Macro',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Super Macro', #6
        },
    },
    0x0203 => { #6
        Name => 'BWMode',
        Description => 'Black And White Mode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            6 => '(none)', #22
        },
    },
    0x0204 => {
        Name => 'DigitalZoom',
        Writable => 'rational64u',
        PrintConv => '$val=~/\./ or $val.=".0"; $val',
        PrintConvInv => '$val',
    },
    0x0205 => { #6
        Name => 'FocalPlaneDiagonal',
        Writable => 'rational64u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0x0206 => { Name => 'LensDistortionParams', Writable => 'int16s', Count => 6 }, #6
    0x0207 => { #PH (was incorrectly FirmwareVersion, ref 1/3)
        Name => 'CameraType',
        Condition => '$$valPt ne "NORMAL"', # FE240, SP510, u730 and u1000 write this
        Writable => 'string',
        DataMember => 'CameraType',
        RawConv => '$self->{CameraType} = $val',
        SeparateTable => 'CameraType',
        ValueConv => '$val =~ s/\s+$//; $val',  # ("SX151 " has trailing space)
        ValueConvInv => '$val',
        PrintConv => \%olympusCameraTypes,
        Priority => 0,
        # 'NORMAL' for some models: u730,SP510UZ,u1000,FE240
    },
    0x0208 => {
        Name => 'TextInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::TextInfo',
        },
    },
    0x0209 => {
        Name => 'CameraID',
        Format => 'string', # this really should have been a string
    },
    0x020b => { Name => 'EpsonImageWidth',  Writable => 'int32u' }, #PH
    0x020c => { Name => 'EpsonImageHeight', Writable => 'int32u' }, #PH
    0x020d => { Name => 'EpsonSoftware',    Writable => 'string' }, #PH
    0x0280 => { #PH
        %Image::ExifTool::previewImageTagInfo,
        Groups => { 2 => 'Preview' },
        Notes => 'found in ERF and JPG images from some Epson models',
        Format => 'undef',
        Writable => 'int8u',
    },
    0x0300 => { Name => 'PreCaptureFrames', Writable => 'int16u' }, #6
    0x0301 => { Name => 'WhiteBoard',       Writable => 'int16u' }, #11
    0x0302 => { #6
        Name => 'OneTouchWB',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'On (Preset)',
        },
    },
    0x0303 => { Name => 'WhiteBalanceBracket',  Writable => 'int16u' }, #11
    0x0304 => { Name => 'WhiteBalanceBias',     Writable => 'int16u' }, #11
   # 0x0305 => 'PrintMatching', ? #11
    0x0400 => { #IB
        Name => 'SensorArea',
        Condition => '$$self{TIFF_TYPE} eq "ERF"',
        Writable => 'undef',
        Format => 'int16u',
        Count => 4,
        Notes => 'found in Epson ERF images',
    },
    0x0401 => { #IB
        Name => 'BlackLevel',
        Condition => '$$self{TIFF_TYPE} eq "ERF"',
        Writable => 'int32u',
        Count => 4,
        Notes => 'found in Epson ERF images',
    },
    # 0x0402 - BitCodedAutoFocus (ref 11)
    0x0403 => { #11
        Name => 'SceneMode',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Normal',
            1 => 'Standard',
            2 => 'Auto',
            3 => 'Intelligent Auto', #PH (guess, u7040)
            4 => 'Portrait',
            5 => 'Landscape+Portrait',
            6 => 'Landscape',
            7 => 'Night Scene',
            8 => 'Night+Portrait',
            9 => 'Sport',
            10 => 'Self Portrait',
            11 => 'Indoor',
            12 => 'Beach & Snow',
            13 => 'Beach',
            14 => 'Snow',
            15 => 'Self Portrait+Self Timer',
            16 => 'Sunset',
            17 => 'Cuisine',
            18 => 'Documents',
            19 => 'Candle',
            20 => 'Fireworks',
            21 => 'Available Light',
            22 => 'Vivid',
            23 => 'Underwater Wide1',
            24 => 'Underwater Macro',
            25 => 'Museum',
            26 => 'Behind Glass',
            27 => 'Auction',
            28 => 'Shoot & Select1',
            29 => 'Shoot & Select2',
            30 => 'Underwater Wide2',
            31 => 'Digital Image Stabilization',
            32 => 'Face Portrait',
            33 => 'Pet',
            34 => 'Smile Shot',
            35 => 'Quick Shutter',
            43 => 'Hand-held Starlight', #PH (SH-21)
            100 => 'Panorama', #PH (SH-21)
            101 => 'Magic Filter', #PH
            103 => 'HDR', #PH (XZ-2)
        },
    },
    0x0404 => { Name => 'SerialNumber', Writable => 'string' }, #PH (D595Z, C7070WZ)
    0x0405 => { Name => 'Firmware',     Writable => 'string' }, #11
    0x0e00 => { # (AFFieldCoord for models XZ-2 and XZ-10, ref 11)
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    # 0x0e80 - undef[256] - offset 0x30: uint16[2] WB_RGBLevels = val[0]*561,65536,val[1]*431 (ref IB)
    0x0f00 => {
        Name => 'DataDump',
        Writable => 0,
        Binary => 1,
    },
    0x0f01 => { #6
        Name => 'DataDump2',
        Writable => 0,
        Binary => 1,
    },
    0x0f04 => {
        Name => 'ZoomedPreviewStart',
        # NOTE: this tag is currently not updated properly when the image is rewritten!
        OffsetPair => 0xf05,
        DataTag => 'ZoomedPreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0f05 => {
        Name => 'ZoomedPreviewLength',
        OffsetPair => 0xf04,
        DataTag => 'ZoomedPreviewImage',
        Writable => 'int32u',
        Protected => 2,
    },
    0x0f06 => {
        Name => 'ZoomedPreviewSize',
        Writable => 'int16u',
        Count => 2,
    },
    0x1000 => { #6
        Name => 'ShutterSpeedValue',
        Writable => 'rational64s',
        Priority => 0,
        ValueConv => 'abs($val)<100 ? 2**(-$val) : 0',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : -100',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x1001 => { #6
        Name => 'ISOValue',
        Writable => 'rational64s',
        Priority => 0,
        ValueConv => '100 * 2 ** ($val - 5)',
        ValueConvInv => '$val>0 ? log($val/100)/log(2)+5 : 0',
        PrintConv => 'int($val * 100 + 0.5) / 100',
        PrintConvInv => '$val',
    },
    0x1002 => { #6
        Name => 'ApertureValue',
        Writable => 'rational64s',
        Priority => 0,
        ValueConv => '2 ** ($val / 2)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x1003 => { #6
        Name => 'BrightnessValue',
        Writable => 'rational64s',
        Priority => 0,
    },
    0x1004 => { #3
        Name => 'FlashMode',
        Writable => 'int16u',
        PrintConv => {
            2 => 'On', #PH
            3 => 'Off', #PH
        },
    },
    0x1005 => { #6
        Name => 'FlashDevice',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'Internal',
            4 => 'External',
            5 => 'Internal + External',
        },
    },
    0x1006 => { #6
        Name =>'ExposureCompensation',
        Writable => 'rational64s',
    },
    0x1007 => { Name => 'SensorTemperature',Writable => 'int16s' }, #6 (E-10, E-20 and C2500L - numbers usually around 30-40)
    0x1008 => { Name => 'LensTemperature',  Writable => 'int16s' }, #6
    0x1009 => { Name => 'LightCondition',   Writable => 'int16u' }, #11
    0x100a => { #11
        Name => 'FocusRange',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Normal',
            1 => 'Macro',
        },
    },
    0x100b => { #6
        Name => 'FocusMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    0x100c => { #6
        Name => 'ManualFocusDistance',
        Writable => 'rational64u',
        PrintConv => '"$val mm"', #11
        PrintConvInv => '$val=~s/\s*mm$//; $val',
    },
    0x100d => { Name => 'ZoomStepCount',    Writable => 'int16u' }, #6
    0x100e => { Name => 'FocusStepCount',   Writable => 'int16u' }, #6
    0x100f => { #6
        Name => 'Sharpness',
        Writable => 'int16u',
        Priority => 0,
        PrintConv => {
            0 => 'Normal',
            1 => 'Hard',
            2 => 'Soft',
        },
    },
    0x1010 => { Name => 'FlashChargeLevel', Writable => 'int16u' }, #6
    0x1011 => { #3
        Name => 'ColorMatrix',
        Writable => 'int16u',
        Format => 'int16s',
        Count => 9,
    },
    0x1012 => { Name => 'BlackLevel',       Writable => 'int16u', Count => 4 }, #3
    0x1013 => { #11
        Name => 'ColorTemperatureBG',
        Writable => 'int16u',
        Unknown => 1, # (doesn't look like a temperature)
    },
    0x1014 => { #11
        Name => 'ColorTemperatureRG',
        Writable => 'int16u',
        Unknown => 1, # (doesn't look like a temperature)
    },
    0x1015 => { #6
        Name => 'WBMode',
        Writable => 'int16u',
        Count => 2,
        PrintConvColumns => 2,
        PrintConv => {
            '1'   => 'Auto',
            '1 0' => 'Auto',
            '1 2' => 'Auto (2)',
            '1 4' => 'Auto (4)',
            '2 2' => '3000 Kelvin',
            '2 3' => '3700 Kelvin',
            '2 4' => '4000 Kelvin',
            '2 5' => '4500 Kelvin',
            '2 6' => '5500 Kelvin',
            '2 7' => '6500 Kelvin',
            '2 8' => '7500 Kelvin',
            '3 0' => 'One-touch',
        },
    },
    0x1017 => { #2
        Name => 'RedBalance',
        Writable => 'int16u',
        Count => 2,
        ValueConv => '$val=~s/ .*//; $val / 256',
        ValueConvInv => '$val*=256;"$val 64"',
    },
    0x1018 => { #2
        Name => 'BlueBalance',
        Writable => 'int16u',
        Count => 2,
        ValueConv => '$val=~s/ .*//; $val / 256',
        ValueConvInv => '$val*=256;"$val 64"',
    },
    0x1019 => { Name => 'ColorMatrixNumber',    Writable => 'int16u' }, #11
    # 0x101a is same as CameraID ("OLYMPUS DIGITAL CAMERA") for C2500L - PH
    0x101a => { Name => 'SerialNumber',         Writable => 'string' }, #3
    0x101b => { #11
        Name => 'ExternalFlashAE1_0',
        Writable => 'int32u',
        Unknown => 1, # (what are these?)
    },
    0x101c => { Name => 'ExternalFlashAE2_0',   Writable => 'int32u', Unknown => 1 }, #11
    0x101d => { Name => 'InternalFlashAE1_0',   Writable => 'int32u', Unknown => 1 }, #11
    0x101e => { Name => 'InternalFlashAE2_0',   Writable => 'int32u', Unknown => 1 }, #11
    0x101f => { Name => 'ExternalFlashAE1',     Writable => 'int32u', Unknown => 1 }, #11
    0x1020 => { Name => 'ExternalFlashAE2',     Writable => 'int32u', Unknown => 1 }, #11
    0x1021 => { Name => 'InternalFlashAE1',     Writable => 'int32u', Unknown => 1 }, #11
    0x1022 => { Name => 'InternalFlashAE2',     Writable => 'int32u', Unknown => 1 }, #11
    0x1023 => { Name => 'FlashExposureComp',    Writable => 'rational64s' }, #6
    0x1024 => { Name => 'InternalFlashTable',   Writable => 'int16u' }, #11
    0x1025 => { Name => 'ExternalFlashGValue',  Writable => 'rational64s' }, #11
    0x1026 => { #6
        Name => 'ExternalFlashBounce',
        Writable => 'int16u',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
    0x1027 => { Name => 'ExternalFlashZoom',    Writable => 'int16u' }, #6
    0x1028 => { Name => 'ExternalFlashMode',    Writable => 'int16u' }, #6
    0x1029 => { #3
        Name => 'Contrast',
        Writable => 'int16u',
        PrintConv => { #PH (works with E1)
            0 => 'High',
            1 => 'Normal',
            2 => 'Low',
        },
    },
    0x102a => { Name => 'SharpnessFactor',      Writable => 'int16u' }, #3
    0x102b => { Name => 'ColorControl',         Writable => 'int16u', Count => 6 }, #3
    0x102c => { Name => 'ValidBits',            Writable => 'int16u', Count => 2 }, #3
    0x102d => { Name => 'CoringFilter',         Writable => 'int16u' }, #3
    0x102e => { Name => 'OlympusImageWidth',    Writable => 'int32u' }, #PH
    0x102f => { Name => 'OlympusImageHeight',   Writable => 'int32u' }, #PH
    0x1030 => { Name => 'SceneDetect',          Writable => 'int16u' }, #11
    0x1031 => { #11
        Name => 'SceneArea',
        Writable => 'int32u',
        Count => 8,
        Unknown => 1, # (numbers don't make much sense?)
    },
    # 0x1032 HAFFINAL? #11
    0x1033 => { #11
        Name => 'SceneDetectData',
        Writable => 'int32u',
        Count => 720,
        Binary => 1,
        Unknown => 1, # (but what does it mean?)
    },
    0x1034 => { Name => 'CompressionRatio',    Writable => 'rational64u' }, #3
    0x1035 => { #6
        Name => 'PreviewImageValid',
        Writable => 'int32u',
        DelValue => 0,
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x1036 => { #6
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x1037, # point to associated byte count
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x1037 => { #6
        # (may contain data from multiple previews - PH, FE320)
        Name => 'PreviewImageLength',
        OffsetPair => 0x1036, # point to associated offset
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x1038 => { Name => 'AFResult',             Writable => 'int16u' }, #11
    0x1039 => { #6
        Name => 'CCDScanMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Interlaced',
            1 => 'Progressive',
        },
    },
    0x103a => { #6
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x103b => { Name => 'FocusStepInfinity',    Writable => 'int16u' }, #6
    0x103c => { Name => 'FocusStepNear',        Writable => 'int16u' }, #6
    0x103d => { Name => 'LightValueCenter',     Writable => 'rational64s' }, #11
    0x103e => { Name => 'LightValuePeriphery',  Writable => 'rational64s' }, #11
    0x103f => { #11
        Name => 'FieldCount',
        Writable => 'int16u',
        Unknown => 1, # (but what does it mean?)
    },
#
# Olympus really screwed up the format of the following subdirectories (for the
# E-1 and E-300 anyway). Not only is the subdirectory value data not included in
# the size, but also the count is 2 bytes short for the subdirectory itself
# (presumably the Olympus programmers forgot about the 2-byte entry count at the
# start of the subdirectory).  This mess is straightened out and these subdirs
# are written properly when ExifTool rewrites the file.  Note that this problem
# has been fixed by Olympus in the new-style IFD maker notes since a standard
# SubIFD offset value is used.  As written by the camera, the old style
# directories have format 'undef' or 'string', and the new style has format
# 'ifd'.  However, some older versions of exiftool may have rewritten the new
# style as 'int32u', so handle both cases. - PH
#
    0x2010 => [ #PH
        {
            Name => 'Equipment',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2, # (so HtmlDump doesn't show these as double-referenced)
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::Equipment',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'EquipmentIFD',
            Groups => { 1 => 'MakerNotes' },    # SubIFD needs group 1 set
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::Equipment',
                Start => '$val',
            },
        },
    ],
    0x2020 => [ #PH
        {
            Name => 'CameraSettings',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::CameraSettings',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'CameraSettingsIFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::CameraSettings',
                Start => '$val',
            },
        },
    ],
    0x2030 => [ #PH
        {
            Name => 'RawDevelopment',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::RawDevelopment',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'RawDevelopmentIFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::RawDevelopment',
                Start => '$val',
            },
        },
    ],
    0x2031 => [ #11
        {
            Name => 'RawDev2',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::RawDevelopment2',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'RawDev2IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::RawDevelopment2',
                Start => '$val',
            },
        },
    ],
    0x2040 => [ #PH
        {
            Name => 'ImageProcessing',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::ImageProcessing',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'ImageProcessingIFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::ImageProcessing',
                Start => '$val',
            },
        },
    ],
    0x2050 => [ #PH
        {
            Name => 'FocusInfo',
            Condition => '$format ne "ifd" and $format ne "int32u" and not $$self{OlympusCAMER}',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FocusInfo',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'FocusInfoIFD',
            Condition => 'not $$self{OlympusCAMER}',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FocusInfo',
                Start => '$val',
            },
        },
        {
            # ASCII-based camera parameters if makernotes starts with "CAMER\0"
            # (or for Sony models starting with "SONY PI\0" or "PREMI\0")
            Name => 'CameraParameters',
            Writable => 'undef',
            Binary => 1,
        },
    ],
    0x2100 => [
        { #11
            Name => 'Olympus2100',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2100IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2200 => [
        { #11
            Name => 'Olympus2200',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2200IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2300 => [
        { #11
            Name => 'Olympus2300',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2300IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2400 => [
        { #11
            Name => 'Olympus2400',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2400IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2500 => [
        { #11
            Name => 'Olympus2500',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2500IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2600 => [
        { #11
            Name => 'Olympus2600',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2600IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2700 => [
        { #11
            Name => 'Olympus2700',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2700IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2800 => [
        { #11
            Name => 'Olympus2800',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2800IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x2900 => [
        { #11
            Name => 'Olympus2900',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'Olympus2900IFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::FETags',
                ByteOrder => 'Unknown',
                Start => '$val',
            },
        },
    ],
    0x3000 => [
        { #6
            Name => 'RawInfo',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::RawInfo',
                ByteOrder => 'Unknown',
            },
        },
        { #PH
            Name => 'RawInfoIFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::RawInfo',
                Start => '$val',
            },
        },
    ],
    0x4000 => [ #PH
        {
            Name => 'MainInfo',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::Main',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'MainInfoIFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::Main',
                Start => '$val',
            },
        },
    ],
    0x5000 => [ #PH
        {
            Name => 'UnknownInfo',
            Condition => '$format ne "ifd" and $format ne "int32u"',
            NestedHtmlDump => 2,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::UnknownInfo',
                ByteOrder => 'Unknown',
            },
        },
        {
            Name => 'UnknownInfoIFD',
            Groups => { 1 => 'MakerNotes' },
            Flags => 'SubIFD',
            FixFormat => 'ifd',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::UnknownInfo',
                Start => '$val',
            },
        },
    ],
);

# TextInfo tags
%Image::ExifTool::Olympus::TextInfo = (
    PROCESS_PROC => \&Image::ExifTool::APP12::ProcessAPP12,
    NOTES => q{
        This information is in text format (similar to APP12 information, but with
        spaces instead of linefeeds).  Below are tags which have been observed, but
        any information found here will be extracted, even if the tag is not listed.
    },
    GROUPS => { 0 => 'MakerNotes', 1 => 'Olympus', 2 => 'Image' },
    Resolution => { },
    Type => {
        Name => 'CameraType',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraType',
        RawConv => '$self->{CameraType} = $val',
        SeparateTable => 'CameraType',
        PrintConv => \%olympusCameraTypes,
    },
);

# Olympus Equipment IFD
%Image::ExifTool::Olympus::Equipment = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'EquipmentVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x100 => { #6
        Name => 'CameraType2',
        Writable => 'string',
        Count => 6,
        SeparateTable => 'CameraType',
        PrintConv => \%olympusCameraTypes,
    },
    0x101 => { #PH
        Name => 'SerialNumber',
        Writable => 'string',
        Count => 32,
        PrintConv => '$val=~s/\s+$//;$val',
        PrintConvInv => 'pack("A31",$val)', # pad with spaces to 31 chars
    },
    0x102 => { #6
        Name => 'InternalSerialNumber',
        Notes => '16 digits: 0-3=model, 4=year, 5-6=month, 8-12=unit number',
        Writable => 'string',
        Count => 32,
    },
    0x103 => { #6
        Name => 'FocalPlaneDiagonal',
        Writable => 'rational64u',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    0x104 => { #6
        Name => 'BodyFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=sprintf("%.3f",$val);$val=~s/\.//;hex($val)',
    },
    0x201 => { #6
        Name => 'LensType',
        Writable => 'int8u',
        Count => 6,
        Notes => q{
            6 numbers: 1. Make, 2. Unknown, 3. Model, 4. Sub-model, 5-6. Unknown.  Only
            the Make, Model and Sub-model are used to identify the lens type
        },
        SeparateTable => 'LensType',
        # Have seen these values for the unknown numbers:
        # 2: 0
        # 5: 0, 2(Olympus lenses for which I have also seen 0 for this number)
        # 6: 0, 16(new Lumix lenses)
        ValueConv => 'my @a=split(" ",$val); sprintf("%x %.2x %.2x",@a[0,2,3])',
        # set unknown values to zero when writing
        ValueConvInv => 'my @a=split(" ",$val); hex($a[0])." 0 ".hex($a[1])." ".hex($a[2])." 0 0"',
        PrintConv => \%olympusLensTypes,
    },
    # apparently the first 3 digits of the lens s/n give the type (ref 4):
    # 010 = 50macro
    # 040 = EC-14
    # 050 = 14-54
    # 060 = 50-200
    # 080 = EX-25
    # 101 = FL-50
    # 272 = EC-20 #7
    0x202 => { #PH
        Name => 'LensSerialNumber',
        Writable => 'string',
        Count => 32,
        PrintConv => '$val=~s/\s+$//;$val',
        PrintConvInv => 'pack("A31",$val)', # pad with spaces to 31 chars
    },
    0x203 => { Name => 'LensModel',         Writable => 'string' }, #17
    0x204 => { #6
        Name => 'LensFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=sprintf("%.3f",$val);$val=~s/\.//;hex($val)',
    },
    0x205 => { #11
        Name => 'MaxApertureAtMinFocal',
        Writable => 'int16u',
        ValueConv => '$val ? sqrt(2)**($val/256) : 0',
        ValueConvInv => '$val>0 ? int(512*log($val)/log(2)+0.5) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x206 => { #5
        Name => 'MaxApertureAtMaxFocal',
        Writable => 'int16u',
        ValueConv => '$val ? sqrt(2)**($val/256) : 0',
        ValueConvInv => '$val>0 ? int(512*log($val)/log(2)+0.5) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x207 => { Name => 'MinFocalLength',    Writable => 'int16u' }, #PH
    0x208 => { Name => 'MaxFocalLength',    Writable => 'int16u' }, #PH
    0x20a => { #9
        Name => 'MaxAperture', # (at current focal length)
        Writable => 'int16u',
        ValueConv => '$val ? sqrt(2)**($val/256) : 0',
        ValueConvInv => '$val>0 ? int(512*log($val)/log(2)+0.5) : 0',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    0x20b => { #11
        Name => 'LensProperties',
        Writable => 'int16u',
        PrintConv => 'sprintf("0x%x",$val)',
        PrintConvInv => '$val',
    },
    0x301 => { #6
        Name => 'Extender',
        Writable => 'int8u',
        Count => 6,
        Notes => q{
            6 numbers: 1. Make, 2. Unknown, 3. Model, 4. Sub-model, 5-6. Unknown.  Only
            the Make and Model are used to identify the extender
        },
        ValueConv => 'my @a=split(" ",$val); sprintf("%x %.2x",@a[0,2])',
        ValueConvInv => 'my @a=split(" ",$val); hex($a[0])." 0 ".hex($a[1])." 0 0 0"',
        PrintConv => {
            '0 00' => 'None',
            '0 04' => 'Olympus Zuiko Digital EC-14 1.4x Teleconverter',
            '0 08' => 'Olympus EX-25 Extension Tube',
            '0 10' => 'Olympus Zuiko Digital EC-20 2.0x Teleconverter', #7
        },
    },
    0x302 => { Name => 'ExtenderSerialNumber',  Writable => 'string', Count => 32 }, #4
    0x303 => { Name => 'ExtenderModel',         Writable => 'string' }, #9
    0x304 => { #6
        Name => 'ExtenderFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=sprintf("%.3f",$val);$val=~s/\.//;hex($val)',
    },
    0x403 => { #http://dev.exiv2.org/issues/870
        Name => 'ConversionLens',
        Writable => 'string',
        # (observed values: '','TCON','FCON','WCON')
    },
    0x1000 => { #6
        Name => 'FlashType',
        Writable => 'int16u',
        PrintConv => {
            0 => 'None',
            2 => 'Simple E-System',
            3 => 'E-System',
            4 => 'E-System (body powered)', #forum9740
        },
    },
    0x1001 => { #6
        Name => 'FlashModel',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'None',
            1 => 'FL-20', # (or subtronic digital or Inon UW flash, ref 11)
            2 => 'FL-50', # (or Metzblitz+SCA or Cullmann 34, ref 11)
            3 => 'RF-11',
            4 => 'TF-22',
            5 => 'FL-36',
            6 => 'FL-50R', #11 (or Metz mecablitz digital)
            7 => 'FL-36R', #11
            9 => 'FL-14', #11
            11 => 'FL-600R', #11
            13 => 'FL-LM3', #forum9740
            15 => 'FL-900R', #7
        },
    },
    0x1002 => { #6
        Name => 'FlashFirmwareVersion',
        Writable => 'int32u',
        PrintConv => '$val=sprintf("%x",$val);$val=~s/(.{3})$/\.$1/;$val',
        PrintConvInv => '$val=sprintf("%.3f",$val);$val=~s/\.//;hex($val)',
    },
    0x1003 => { Name => 'FlashSerialNumber', Writable => 'string', Count => 32 }, #4
);

# Olympus camera settings IFD
%Image::ExifTool::Olympus::CameraSettings = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'CameraSettingsVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x100 => { #6
        Name => 'PreviewImageValid',
        Writable => 'int32u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x101 => { #PH
        Name => 'PreviewImageStart',
        Flags => 'IsOffset',
        OffsetPair => 0x102,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x102 => { #PH
        Name => 'PreviewImageLength',
        OffsetPair => 0x101,
        DataTag => 'PreviewImage',
        Writable => 'int32u',
        WriteGroup => 'MakerNotes',
        Protected => 2,
    },
    0x200 => { #4
        Name => 'ExposureMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Manual',
            2 => 'Program', #6
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Program-shift', #6
        }
    },
    0x201 => { #6
        Name => 'AELock',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x202 => { #PH/4
        Name => 'MeteringMode',
        Writable => 'int16u',
        PrintConv => {
            2 => 'Center-weighted average',
            3 => 'Spot',
            5 => 'ESP',
            261 => 'Pattern+AF', #6
            515 => 'Spot+Highlight control', #6
            1027 => 'Spot+Shadow control', #6
        },
    },
    0x203 => { Name => 'ExposureShift', Writable => 'rational64s' }, #11 (some models only)
    0x204 => { #11 (XZ-1)
        Name => 'NDFilter',
        PrintConv => \%offOn,
    },
    0x300 => { #6
        Name => 'MacroMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            2 => 'Super Macro', #11
        },
    },
    0x301 => { #6
        Name => 'FocusMode',
        Writable => 'int16u',
        Count => -1,
        Notes => '1 or 2 values',
        PrintConv => [{
            0 => 'Single AF',
            1 => 'Sequential shooting AF',
            2 => 'Continuous AF',
            3 => 'Multi AF',
            4 => 'Face Detect', #11
            10 => 'MF',
        }, {
            0 => '(none)',
            BITMASK => { #11
                0 => 'S-AF',
                2 => 'C-AF',
                4 => 'MF',
                5 => 'Face Detect',
                6 => 'Imager AF',
                7 => 'Live View Magnification Frame',
                8 => 'AF sensor',
                9 => 'Starry Sky AF', #24
            },
        }],
    },
    0x302 => { #6
        Name => 'FocusProcess',
        Writable => 'int16u',
        Count => -1,
        Notes => '1 or 2 values',
        PrintConv => [{
            0 => 'AF Not Used',
            1 => 'AF Used',
        }],
        # 2nd value written only by some models (u1050SW, u9000, uT6000, uT6010,
        # uT8000, E-30, E-420, E-450, E-520, E-620, E-P1 and E-P2): - PH
        # observed values when "AF Not Used": 0, 16
        # observed values when "AF Used": 64, 96(face detect on), 256
    },
    0x303 => { #6
        Name => 'AFSearch',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Not Ready',
            1 => 'Ready',
        },
    },
    0x304 => { #PH/4
        Name => 'AFAreas',
        Notes => 'coordinates range from 0 to 255',
        Writable => 'int32u',
        Count => 64,
        PrintConv => 'Image::ExifTool::Olympus::PrintAFAreas($val)',
    },
    0x0305 => { #PH
        Name => 'AFPointSelected',
        Notes => 'coordinates expressed as a percent',
        Writable => 'rational64s',
        Count => 5,
        ValueConv => '$val =~ s/\S* //; $val', # ignore first undefined value
        ValueConvInv => '"undef $val"',
        PrintConv => q{
            return 'n/a' if $val =~ /undef/;
            sprintf("(%d%%,%d%%) (%d%%,%d%%)", map {$_ * 100} split(" ",$val));
        },
        PrintConvInv => q{
            return 'undef undef undef undef' if $val eq 'n/a';
            my @nums = $val =~ /\d+(?:\.\d+)?/g;
            return undef unless @nums == 4;
            join ' ', map {$_ / 100} @nums;
        },
    },
    0x306 => { #11
        Name => 'AFFineTune',
        Writable => 'int8u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x307 => { #15
        Name => 'AFFineTuneAdj',
        Writable => 'int16s',
        Count => 3, # not sure what the 3 values mean
    },
    0x308 => { #forum11578
        Name => 'FocusBracketStepSize',
        Writable => 'int8u',
    },
    0x309 => { #forum13341
        Name => 'AISubjectTrackingMode',
        Writable => 'int16u',
        PrintConv => {             #25 (OM models)
                0 => 'Off',
            0x100 => 'Motorsports; Object Not Found',
            0x101 => 'Motorsports; Racing Car Found',
            0x102 => 'Motorsports; Car Found',
            0x103 => 'Motorsports; Motorcyle Found',
            0x200 => 'Airplanes; Object Not Found',
            0x201 => 'Airplanes; Passenger/Transport Plane Found',
            0x202 => 'Airplanes; Small Plane/Fighter Jet Found',
            0x203 => 'Airplanes; Helicopter Found',
            0x300 => 'Trains; Object Not Found',
            0x301 => 'Trains; Object Found',
            0x400 => 'Birds; Object Not Found',
            0x401 => 'Birds; Object Found',
            0x500 => 'Dogs & Cats; Object Not Found',
            0x501 => 'Dogs & Cats; Object Found',
            0x600 => 'Human; Object Not Found',
            0x601 => 'Human; Object Found',
        },
    },
    0x030a => {
        Name => 'AFTargetInfo',
        Format => 'undef',
        Writable => 'int16u',
        Count => 10,
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::AFTargetInfo' },
    },
    0x030b => {
        Name => 'SubjectDetectInfo',
        Format => 'undef',
        Writable => 'int16u',
        Count => 11,
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::SubjectDetectInfo' },
    },
    0x400 => { #6
        Name => 'FlashMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            BITMASK => {
                0 => 'On',
                1 => 'Fill-in',
                2 => 'Red-eye',
                3 => 'Slow-sync',
                4 => 'Forced On',
                5 => '2nd Curtain',
            },
        },
    },
    0x401 => { Name => 'FlashExposureComp', Writable => 'rational64s' }, #6
    # 0x402 - FlashMode? bit0=TTL, bit1=auto, bit2=SuperFP (ref 11)
    0x403 => { #11
        Name => 'FlashRemoteControl',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            0x01 => 'Channel 1, Low',
            0x02 => 'Channel 2, Low',
            0x03 => 'Channel 3, Low',
            0x04 => 'Channel 4, Low',
            0x09 => 'Channel 1, Mid',
            0x0a => 'Channel 2, Mid',
            0x0b => 'Channel 3, Mid',
            0x0c => 'Channel 4, Mid',
            0x11 => 'Channel 1, High',
            0x12 => 'Channel 2, High',
            0x13 => 'Channel 3, High',
            0x14 => 'Channel 4, High',
        },
    },
    0x404 => { #11
        Name => 'FlashControlMode',
        Writable => 'int16u',
        Count => -1,
        Notes => '3 or 4 values',
        PrintConv => [{
            0 => 'Off',
            3 => 'TTL',
            4 => 'Auto',
            5 => 'Manual',
        }],
    },
    0x405 => { #11
        Name => 'FlashIntensity',
        Writable => 'rational64s',
        Count => -1,
        Notes => '3 or 4 values',
        PrintConv => {
            OTHER => sub { shift },
            'undef undef undef' => 'n/a',
            'undef undef undef undef' => 'n/a (x4)',
        },
    },
    0x406 => { #11
        Name => 'ManualFlashStrength',
        Writable => 'rational64s',
        Count => -1,
        Notes => '3 or 4 values',
        PrintConv => {
            OTHER => sub { shift },
            'undef undef undef' => 'n/a',
            'undef undef undef undef' => 'n/a (x4)',
        },
    },
    0x500 => { #6
        Name => 'WhiteBalance2',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Auto',
            1 => 'Auto (Keep Warm Color Off)', #IB
            16 => '7500K (Fine Weather with Shade)',
            17 => '6000K (Cloudy)',
            18 => '5300K (Fine Weather)',
            20 => '3000K (Tungsten light)',
            21 => '3600K (Tungsten light-like)',
            22 => 'Auto Setup', #IB
            23 => '5500K (Flash)', #IB
            33 => '6600K (Daylight fluorescent)',
            34 => '4500K (Neutral white fluorescent)',
            35 => '4000K (Cool white fluorescent)',
            36 => 'White Fluorescent', #IB
            48 => '3600K (Tungsten light-like)',
            67 => 'Underwater', #IB
            256 => 'One Touch WB 1', #IB
            257 => 'One Touch WB 2', #IB
            258 => 'One Touch WB 3', #IB
            259 => 'One Touch WB 4', #IB
            512 => 'Custom WB 1', #IB
            513 => 'Custom WB 2', #IB
            514 => 'Custom WB 3', #IB
            515 => 'Custom WB 4', #IB
        },
    },
    0x501 => { #PH/4
        Name => 'WhiteBalanceTemperature',
        Writable => 'int16u',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/^\d+$/ ? $val : 0',
    },
    0x502 => {  #PH/4
        Name => 'WhiteBalanceBracket',
        Writable => 'int16s',
    },
    0x503 => { #PH/4/6
        Name => 'CustomSaturation',
        Writable => 'int16s',
        Count => 3,
        Notes => '3 numbers: 1. CS Value, 2. Min, 3. Max',
        PrintConv => q{
            my ($a,$b,$c)=split ' ',$val;
            if ($self->{Model} =~ /^E-1\b/) {
                $a-=$b; $c-=$b;
                return "CS$a (min CS0, max CS$c)";
            } else {
                return "$a (min $b, max $c)";
            }
        },
    },
    0x504 => { #PH/4
        Name => 'ModifiedSaturation',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'CM1 (Red Enhance)',
            2 => 'CM2 (Green Enhance)',
            3 => 'CM3 (Blue Enhance)',
            4 => 'CM4 (Skin Tones)',
        },
    },
    0x505 => { #PH/4
        Name => 'ContrastSetting',
        Writable => 'int16s',
        Count => 3,
        Notes => 'value, min, max',
        PrintConv => 'my @v=split " ",$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=~tr/-0-9 //dc;$val',
    },
    0x506 => { #PH/4
        Name => 'SharpnessSetting',
        Writable => 'int16s',
        Count => 3,
        Notes => 'value, min, max',
        PrintConv => 'my @v=split " ",$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=~tr/-0-9 //dc;$val',
    },
    0x507 => { #PH/4
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => { #6
            0 => 'sRGB',
            1 => 'Adobe RGB',
            2 => 'Pro Photo RGB',
        },
    },
    0x509 => { #6
        Name => 'SceneMode',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Standard',
            6 => 'Auto', #6
            7 => 'Sport',
            8 => 'Portrait',
            9 => 'Landscape+Portrait',
            10 => 'Landscape',
            11 => 'Night Scene',
            12 => 'Self Portrait', #11
            13 => 'Panorama', #6
            14 => '2 in 1', #11
            15 => 'Movie', #11
            16 => 'Landscape+Portrait', #6
            17 => 'Night+Portrait',
            18 => 'Indoor', #11 (Party - PH)
            19 => 'Fireworks',
            20 => 'Sunset',
            21 => 'Beauty Skin', #PH
            22 => 'Macro',
            23 => 'Super Macro', #11
            24 => 'Food', #11
            25 => 'Documents',
            26 => 'Museum',
            27 => 'Shoot & Select', #11
            28 => 'Beach & Snow',
            29 => 'Self Protrait+Timer', #11
            30 => 'Candle',
            31 => 'Available Light', #11
            32 => 'Behind Glass', #11
            33 => 'My Mode', #11
            34 => 'Pet', #11
            35 => 'Underwater Wide1', #6
            36 => 'Underwater Macro', #6
            37 => 'Shoot & Select1', #11
            38 => 'Shoot & Select2', #11
            39 => 'High Key',
            40 => 'Digital Image Stabilization', #6
            41 => 'Auction', #11
            42 => 'Beach', #11
            43 => 'Snow', #11
            44 => 'Underwater Wide2', #6
            45 => 'Low Key', #6
            46 => 'Children', #6
            47 => 'Vivid', #11
            48 => 'Nature Macro', #6
            49 => 'Underwater Snapshot', #11
            50 => 'Shooting Guide', #11
            54 => 'Face Portrait', #11
            57 => 'Bulb', #11
            59 => 'Smile Shot', #11
            60 => 'Quick Shutter', #11
            63 => 'Slow Shutter', #11
            64 => 'Bird Watching', #11
            65 => 'Multiple Exposure', #11
            66 => 'e-Portrait', #11
            67 => 'Soft Background Shot', #11
            142 => 'Hand-held Starlight', #PH (SH-21)
            154 => 'HDR', #PH (XZ-2)
            197 => 'Panning', #forum11631 (EM5iii)
            203 => 'Light Trails', #forum11631 (EM5iii)
            204 => 'Backlight HDR', #forum11631 (EM5iii)
            205 => 'Silent', #forum11631 (EM5iii)
            206 => 'Multi Focus Shot', #forum11631 (EM5iii)
        },
    },
    0x50a => { #PH/4/6
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Noise Reduction',
                1 => 'Noise Filter',
                2 => 'Noise Filter (ISO Boost)',
                3 => 'Auto', #11
            },
        },
    },
    0x50b => { #6
        Name => 'DistortionCorrection',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x50c => { #PH/4
        Name => 'ShadingCompensation',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x50d => { Name => 'CompressionFactor', Writable => 'rational64u' }, #PH/4
    0x50f => { #6
        Name => 'Gradation',
        Writable => 'int16s',
        Notes => '3 or 4 values',
        Count => -1,
        Relist => [ [0..2], 3 ], # join values 0-2 for PrintConv
        PrintConv => [{
           '0 0 0' => 'n/a', #PH (?)
           '-1 -1 1' => 'Low Key',
            '0 -1 1' => 'Normal',
            '1 -1 1' => 'High Key',
        },{
            0 => 'User-Selected',
            1 => 'Auto-Override',
        }],
    },
    0x520 => { #6
        Name => 'PictureMode',
        Writable => 'int16u',
        Notes => '1 or 2 values',
        Count => -1,
        PrintConv => [{
            1 => 'Vivid',
            2 => 'Natural',
            3 => 'Muted',
            4 => 'Portrait',
            5 => 'i-Enhance', #11
            6 => 'e-Portrait', #23
            7 => 'Color Creator', #23
            8 => 'Underwater', #7
            9 => 'Color Profile 1', #23
            10 => 'Color Profile 2', #23
            11 => 'Color Profile 3', #23
            12 => 'Monochrome Profile 1', #23
            13 => 'Monochrome Profile 2', #23
            14 => 'Monochrome Profile 3', #23
            17 => 'Art Mode', #7
            18 => 'Monochrome Profile 4', #7
            256 => 'Monotone',
            512 => 'Sepia',
        }],
    },
    0x521 => { #6
        Name => 'PictureModeSaturation',
        Writable => 'int16s',
        Count => 3,
        Notes => 'value, min, max',
        PrintConv => 'my @v=split " ",$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=~tr/-0-9 //dc;$val',
    },
    0x522 => { #6
        Name => 'PictureModeHue',
        Writable => 'int16s',
        Unknown => 1, # (needs verification)
    },
    0x523 => { #6
        Name => 'PictureModeContrast',
        Writable => 'int16s',
        Count => 3,
        Notes => 'value, min, max',
        PrintConv => 'my @v=split " ",$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=~tr/-0-9 //dc;$val',
    },
    0x524 => { #6
        Name => 'PictureModeSharpness',
        # verified as the Sharpness setting in the Picture Mode menu for the E-410
        Writable => 'int16s',
        Count => 3,
        Notes => 'value, min, max',
        PrintConv => 'my @v=split " ",$val; "$v[0] (min $v[1], max $v[2])"',
        PrintConvInv => '$val=~tr/-0-9 //dc;$val',
    },
    0x525 => { #6
        Name => 'PictureModeBWFilter',
        Writable => 'int16s',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Neutral',
            2 => 'Yellow',
            3 => 'Orange',
            4 => 'Red',
            5 => 'Green',
        },
    },
    0x526 => { #6
        Name => 'PictureModeTone',
        Writable => 'int16s',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'n/a',
            1 => 'Neutral',
            2 => 'Sepia',
            3 => 'Blue',
            4 => 'Purple',
            5 => 'Green',
        },
    },
    0x527 => { #12
        Name => 'NoiseFilter',
        Writable => 'int16s',
        Count => 3,
        PrintConv => {
           '0 0 0' => 'n/a', #PH (?)
           '-2 -2 1' => 'Off',
           '-1 -2 1' => 'Low',
           '0 -2 1' => 'Standard',
           '1 -2 1' => 'High',
        },
    },
    0x529 => { #PH
        Name => 'ArtFilter',
        Writable => 'int16u',
        Count => 4,
        PrintConvColumns => 2,
        PrintConv => [ \%filters ],
    },
    0x52c => { #PH
        Name => 'MagicFilter',
        Writable => 'int16u',
        Count => 4, # (2nd number is 0, 1280 or 1792, 3rd/4th are 0)
        # (1792 observed for E-5 Gentle Sepia and XZ-1 Dramatic Tone)
        PrintConvColumns => 2,
        PrintConv => [ \%filters ],
    },
    0x52d => { #11
        Name => 'PictureModeEffect',
        Writable => 'int16s',
        Count => 3,
        PrintConv => {
           '0 0 0' => 'n/a', #PH (?)
           '-1 -1 1' => 'Low',
           '0 -1 1' => 'Standard',
           '1 -1 1' => 'High',
        },
    },
    0x52e => { #11/PH
        Name => 'ToneLevel',
        PrintConv => [
            \%toneLevelType,
            undef, # (highlights value)
            undef, # (highlights min)
            undef, # (highlights max)
            \%toneLevelType,
            undef, # (shadows value)
            undef, # (shadows min)
            undef, # (shadows max)
            \%toneLevelType,
            undef, # (midtones value)
            undef, # (midtones min)
            undef, # (midtones max)
            \%toneLevelType,
            undef,
            undef,
            undef,
            \%toneLevelType,
            undef,
            undef,
            undef,
            \%toneLevelType,
            undef,
            undef,
            undef,
            \%toneLevelType,
            undef,
            undef,
            undef,
        ]
    },
    0x52f => { #PH
        Name => 'ArtFilterEffect',
        Writable => 'int16u',
        Count => 20,
        PrintHex => 1,
        PrintConvColumns => 2,
        PrintConv => [
            \%filters,
            undef,
            undef,
            '"Partial Color $val"', #23
            {   # there are 5 available art filter effects for the E-PL3...
                0x0000 => 'No Effect',
                0x8010 => 'Star Light',
                0x8020 => 'Pin Hole',
                0x8030 => 'Frame',
                0x8040 => 'Soft Focus',
                0x8050 => 'White Edge',
                0x8060 => 'B&W', # (NC - E-PL2 with "Grainy Film" filter)
                0x8080 => 'Blur Top and Bottom', #23
                0x8081 => 'Blur Left and Right', #23
                # (E-PL2 also has "Pict. Tone" effect)
            },
            undef,
            { #23
                0 => 'No Color Filter',
                1 => 'Yellow Color Filter',
                2 => 'Orange Color Filter',
                3 => 'Red Color Filter',
                4 => 'Green Color Filter',
            },
        ],
    },
    0x532 => { #23
        Name => 'ColorCreatorEffect',
        Writable => 'int16s',
        Count => 6,
        PrintConv => [
            '"Color $val"',
            undef, # (Color min)
            undef, # (Color max)
            '"Strength $val"',
            undef, # (Strength min)
            undef, # (Strength max)
        ],
    },
    0x537 => { #23
        Name => 'MonochromeProfileSettings',
        Writable => 'int16s',
        Count => 6,
        PrintConv => [
            {
                0 => 'No Filter',
                1 => 'Yellow Filter',
                2 => 'Orange Filter',
                3 => 'Red Filter',
                4 => 'Magenta Filter',
                5 => 'Blue Filter',
                6 => 'Cyan Filter',
                7 => 'Green Filter',
                8 => 'Yellow-green Filter',
            },
            undef, # (Filter number min)
            undef, # (Filter number max)
            '"Strength $val"',
            undef, # (Strength min)
            undef, # (Strength max)
        ],
    },
    0x538 => { #23
        Name => 'FilmGrainEffect',
        Writable => 'int16s',
        PrintConv => {
            0 => 'Off',
            1 => 'Low',
            2 => 'Medium',
            3 => 'High',
        },
    },
    0x539 => { #23
        Name => 'ColorProfileSettings',
        Writable => 'int16s',
        Count => 14,
        PrintConv => [
            '"Min $val"',
            '"Max $val"',
            '"Yellow $val"',
            '"Orange $val"',
            '"Orange-red $val"',
            '"Red $val"',
            '"Magenta $val"',
            '"Violet $val"',
            '"Blue $val"',
            '"Blue-cyan $val"',
            '"Cyan $val"',
            '"Green-cyan $val"',
            '"Green $val"',
            '"Yellow-green $val"',
        ],
    },
    0x53a => { #23
        Name => 'MonochromeVignetting',
        Writable => 'int16s',
        Notes => '-5 to +5: positive is white vignetting, negative is black vignetting',
    },
    0x53b => { #23
        Name => 'MonochromeColor',
        Writable => 'int16s',
        PrintConv => {
            0 => '(none)',
            1 => 'Normal',
            2 => 'Sepia',
            3 => 'Blue',
            4 => 'Purple',
            5 => 'Green',
        },
    },
    0x600 => { #PH/4/22
        Name => 'DriveMode',
        Writable => 'int16u',
        Count => -1,
        Notes => q{
            2, 3, 5 or  numbers: 1. Mode, 2. Shot number, 3. Mode bits, 5. Shutter mode,
            6. Shooting mode (E-M1 II and later models)
        },
        PrintConv => q{
            my ($a,$b,$c,$d,$e,$f) = split ' ',$val;
            if ($b) {
                $b = ', Shot ' . $b;
            } else {
                $b = '';
            }
            if (not defined $e or $e == 4) {   #KG: personally, I'd like to skip 'Electronic shutter' since this is the defacto default setting
                $e = '';
            } else {
                $e = '; ' . ({ 0 => 'Mechanical shutter' , 2 => 'Anti-shock' }->{$e} || "Unknown ($e)");
            }
            if ($a == 5 and defined $c) {
                $a = DecodeBits($c, { #6
                    0 => 'AE',
                    1 => 'WB',
                    2 => 'FL',
                    3 => 'MF',
                    4 => 'ISO', #forum8906
                    5 => 'AE Auto', #forum8906
                    6 => 'Focus', #PH
                }) . ' Bracketing';
                $a =~ s/, /+/g;
            } elsif ($f) { #25
                  # for newer models (E-M1 and later) look at byte 6 for other shooting modes
                  my %f = (
                      # Mechanical shutter modes
                      0x01 => 'Single Shot',
                      0x02 => 'Sequential L',
                      0x03 => 'Sequential H',
                      0x07 => 'Sequential',
                      # Anti-shock modes
                      0x11 => 'Single Shot',
                      0x12 => 'Sequential L',
                      0x13 => 'Sequential H',
                      0x14 => 'Self-Timer 12 sec',
                      0x15 => 'Self-Timer 2 sec',
                      0x16 => 'Custom Self-Timer',
                      0x17 => 'Sequential',
                      # Electronical shutter modes
                      0x21 => 'Single Shot',
                      0x22 => 'Sequential L',
                      0x23 => 'Sequential H',
                      0x24 => 'Self-Timer 2 sec',
                      0x25 => 'Self-Timer 12 sec',
                      0x26 => 'Custom Self-Timer',
                      0x27 => 'Sequential',
                      0x28 => 'Sequential SH1',
                      0x29 => 'Sequential SH2',
                      0x30 => 'HighRes Shot',  # only E-M models
                      0x41 => 'ProCap H',
                      0x42 => 'ProCap L',
                      0x43 => 'ProCap',
                      0x48 => 'ProCap SH1',
                      0x49 => 'ProCap SH2',
                  );
                  $a = $f{$f} || "Unknown ($f)";
            } else {
                  my %a = (
                      0 => 'Single Shot',
                      1 => 'Continuous Shooting',
                      2 => 'Exposure Bracketing',
                      3 => 'White Balance Bracketing',
                      4 => 'Exposure+WB Bracketing', #6
                  );
                  $a = $a{$a} || "Unknown ($a)";
            }
            return "$a$b$e";
        },
    },
    0x601 => { #6
        Name => 'PanoramaMode',
        Writable => 'int16u',
        Notes => '2 numbers: 1. Mode, 2. Shot number',
        PrintConv => q{
            my ($a,$b) = split ' ',$val;
            return 'Off' unless $a;
            my %a = (
                1 => 'Left to Right',
                2 => 'Right to Left',
                3 => 'Bottom to Top',
                4 => 'Top to Bottom',
            );
            return(($a{$a} || "Unknown ($a)") . ', Shot ' . $b);
        },
    },
    0x603 => { #PH/4
        Name => 'ImageQuality2',
        Writable => 'int16u',
        PrintConv => {
            1 => 'SQ',
            2 => 'HQ',
            3 => 'SHQ',
            4 => 'RAW',
            5 => 'SQ (5)', # (E-500)
        },
    },
    0x604 => { #PH
        Name => 'ImageStabilization',
        Writable => 'int32u',
        DataMember => 'ImageStabilization',
        RawConv => '$$self{ImageStabilization} = $val',
        PrintConv => {
            0 => 'Off',
            1 => 'On, S-IS1 (All Direction Shake IS)', #25
            2 => 'On, S-IS2 (Vertical Shake IS)', #25
            3 => 'On, S-IS3 (Horizontal Shake IS)', #25
            4 => 'On, S-IS Auto', #25
        },
    },
    0x804 => { #PH (E-M1 with firmware update)
        Name => 'StackedImage',
        Writable => 'int32u',
        Count => 2,
        PrintConv => {
            '0 0' => 'No',
            '1 *' => 'Live Composite (* images)', #24
            '4 *' => 'Live Time/Bulb (* images)', #24
            '3 2' => 'ND2 (1EV)', #IB
            '3 4' => 'ND4 (2EV)', #IB
            '3 8' => 'ND8 (3EV)', #IB
            '3 16' => 'ND16 (4EV)', #IB
            '3 32' => 'ND32 (5EV)', #IB
            '3 64' => 'ND64 (6EV)', #forum13341
            '5 4' => 'HDR1', #forum8906
            '6 4' => 'HDR2', #forum8906
            '8 8' => 'Tripod high resolution', #IB
            '9 *' => 'Focus-stacked (* images)', #IB (* = 2-15)
            '11 12' => 'Hand-held high resolution (11 12)', #forum13341 (OM-1)
            '11 16' => 'Hand-held high resolution (11 16)', #IB (perhaps '11 15' would be possible, ref 24)
            '13 2' => 'GND2 (1EV)', #25
            '13 4' => 'GND4 (2EV)', #25
            '13 8' => 'GND8 (3EV)', #25
            OTHER => sub {
                my ($val, $inv, $conv) = @_;
                if ($inv) {
                    $val = lc $val;
                    return undef unless $val =~ s/(\d+) images/\* images/;
                    my $num = $1;
                    foreach (keys %$conv) {
                        next unless $val eq lc $$conv{$_};
                        ($val = $_) =~ s/\*/$num/ or return undef;
                        return $val;
                    }
                } else {
                    return "Unknown ($_[0])" unless $val =~ s/ (\d+)/ \*/ and $$conv{$val};
                    my $num = $1;
                    ($val = $$conv{$val}) =~ s/\*/$num/;
                    return $val;
                }
            },
        },
    },
    0x0821 => { #25
        Name => 'ISOAutoSettings',
        Writable => 'int16u',
        Count => 2,
        Notes => '2 numbers: 1. Default sensitivty, 2. Maximum sensitivity',
        PrintConv => [{
            0 => 'n/a',
            0x0600 => '200',
            0x0655 => '250',
            0x06aa => '320',
            0x0700 => '400',
            0x0755 => '500',
            0x07aa => '640',
            0x0800 => '800',
            0x0855 => '1000',
            0x08aa => '1250',
            0x0900 => '1600',
            0x0955 => '2000',
            0x09aa => '2500',
            0x0a00 => '3200',
            0x0a55 => '4000',
            0x0aaa => '5000',
            0x0b00 => '6400',
            0x0b55 => '8000',
            0x0baa => '10000',
            0x0c00 => '12800',
            0x0c55 => '16000',
            0x0caa => '20000',
            0x0d00 => '25600',
            0x0d55 => '32000',
            0x0daa => '40000',
            0x0e00 => '51200',
            0x0e55 => '64000',
            0x0eaa => '80000',
            0x0f00 => '102400',
        },{
            0 => 'n/a',
            0x0600 => '200',
            0x0655 => '250',
            0x06aa => '320',
            0x0700 => '400',
            0x0755 => '500',
            0x07aa => '640',
            0x0800 => '800',
            0x0855 => '1000',
            0x08aa => '1250',
            0x0900 => '1600',
            0x0955 => '2000',
            0x09aa => '2500',
            0x0a00 => '3200',
            0x0a55 => '4000',
            0x0aaa => '5000',
            0x0b00 => '6400',
            0x0b55 => '8000',
            0x0baa => '10000',
            0x0c00 => '12800',
            0x0c55 => '16000',
            0x0caa => '20000',
            0x0d00 => '25600',
            0x0d55 => '32000',
            0x0daa => '40000',
            0x0e00 => '51200',
            0x0e55 => '64000',
            0x0eaa => '80000',
            0x0f00 => '102400',
        }],
    },
    0x900 => { #11
        Name => 'ManometerPressure',
        Writable => 'int16u',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => '"$val kPa"',
        PrintConvInv => '$val=~s/ ?kPa//i; $val',
    },
    0x901 => { #PH (u770SW)
        # 2 numbers: 1st looks like meters above sea level, 2nd is usually 3x the 1st (feet?)
        Name => 'ManometerReading',
        Writable => 'int32s',
        Count => 2,
        ValueConv => 'my @a=split(" ",$val); $_ /= 10 foreach @a; "@a"',
        ValueConvInv => 'my @a=split(" ",$val); $_ *= 10 foreach @a; "@a"',
        PrintConv => '$val=~s/(\S+) (\S+)/$1 m, $2 ft/; $val',
        PrintConvInv => '$val=~s/ ?(m|ft)//gi; $val',
    },
    0x902 => { #11
        Name => 'ExtendedWBDetect',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x903 => { #11
        Name => 'RollAngle',
        Notes => 'converted to degrees of clockwise camera rotation',
        Writable => 'int16s',
        Count => 2, # (second value is 0 if level gauge is off)
        # negate to express as clockwise rotation
        ValueConv => '$val=~s/ 1$// ? -$val/10 : "n/a"',
        ValueConvInv => 'IsFloat($val) ? sprintf("%.0f 1",-$val*10) : "0 0"',
    },
    0x904 => { #11
        Name => 'PitchAngle',
        Notes => 'converted to degrees of upward camera tilt',
        Writable => 'int16s',
        Count => 2, # (second value is 0 if level gauge is off)
        ValueConv => '$val =~ s/ 1$// ? $val / 10 : "n/a"',
        ValueConvInv => 'IsFloat($val) ? sprintf("%.0f 1",$val*10) : "0 0"',
    },
    0x908 => { #PH (NC, E-M1)
        Name => 'DateTimeUTC',
        Writable => 'string',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,undef,1)',
    },
);

# ref 25
%Image::ExifTool::Olympus::AFTargetInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    WRITABLE => 1,
    NOTES => 'Position and size of selected AF Area and focus areas for OM cameras.',
    0 => { Name => 'AFFrameSize', Format => 'int16u[2]' , Notes => 'width/height of the focus/select frame' },
    2 => { Name => 'AFFocusArea', Format => 'int16u[4]' , Notes => 'X Y width height. The center is identical to AFPointSelected' },
    6 => {
        Name => 'AFSelectedArea',
        Format => 'int16u[4]',
        Notes => q{
            X Y width height. Subject and Face Detection OFF: User selected AF target
            area. Subject or Face Detection ON: Area related to detection process.
        },
    },
);

# ref 25
%Image::ExifTool::Olympus::SubjectDetectInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    WRITABLE => 1,
    NOTES => q{
        Subject Detection data for OM cameras. These tags contain the areas of a
        subject and its elements detected by Subject Detection, or the main face and
        eyes detected by Face Detection. These elements can be either L1 details
        (level 1, such as head, chassis, airplane nose, etc.) or L2 details (level
        2, such as eye, driver, airplane cockpit, etc.).
    },
    0 => { Name => 'SubjectDetectFrameSize', Format => 'int16u[2]', Notes => 'width/height of the subject detect frame' },
    2 => { Name => 'SubjectDetectArea',      Format => 'int16u[4]', Notes => 'X Y width height' },
    6 => { Name => 'SubjectDetectDetail',    Format => 'int16u[4]', Notes => 'X Y width height' },
    10 => {
        Name => 'SubjectDetectStatus',
        Notes => q{
            Indicates the presence of data related to subject and face detection, not
            necessarily corresponding to the detection result
        },
        PrintConv => {
              0 => 'No Data',
            257 => 'Subject and L1 Detail Detected', # (head, airplane nose, ...)
            258 => 'Subject and L2 Detail Detected', # (eye, airplane cockpit, ...)
            260 => 'Subject Detected, No Details',
            515 => 'Face and Eye Detected',
            516 => 'Face Detected',
            771 => 'Subject Detail or Eye Detected',
            772 => 'No Subject or Face Detected',
        },
    },
);

# Olympus RAW processing IFD (ref 6)
%Image::ExifTool::Olympus::RawDevelopment = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'RawDevVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x100 => { Name => 'RawDevExposureBiasValue',   Writable => 'rational64s' },
    0x101 => { Name => 'RawDevWhiteBalanceValue',   Writable => 'int16u' },
    0x102 => { Name => 'RawDevWBFineAdjustment',    Writable => 'int16s' },
    0x103 => { Name => 'RawDevGrayPoint',           Writable => 'int16u', Count => 3 },
    0x104 => { Name => 'RawDevSaturationEmphasis',  Writable => 'int16s', Count => 3 },
    0x105 => { Name => 'RawDevMemoryColorEmphasis', Writable => 'int16u' },
    0x106 => { Name => 'RawDevContrastValue',       Writable => 'int16s', Count => 3 },
    0x107 => { Name => 'RawDevSharpnessValue',      Writable => 'int16s', Count => 3 },
    0x108 => {
        Name => 'RawDevColorSpace',
        Writable => 'int16u',
        PrintConv => { #11
            0 => 'sRGB',
            1 => 'Adobe RGB',
            2 => 'Pro Photo RGB',
        },
    },
    0x109 => {
        Name => 'RawDevEngine',
        Writable => 'int16u',
        PrintConv => { #11
            0 => 'High Speed',
            1 => 'High Function',
            2 => 'Advanced High Speed',
            3 => 'Advanced High Function',
        },
    },
    0x10a => {
        Name => 'RawDevNoiseReduction',
        Writable => 'int16u',
        PrintConv => { #11
            0 => '(none)',
            BITMASK => {
                0 => 'Noise Reduction',
                1 => 'Noise Filter',
                2 => 'Noise Filter (ISO Boost)',
            },
        },
    },
    0x10b => {
        Name => 'RawDevEditStatus',
        Writable => 'int16u',
        PrintConv => { #11
            0 => 'Original',
            1 => 'Edited (Landscape)',
            6 => 'Edited (Portrait)',
            8 => 'Edited (Portrait)',
        },
    },
    0x10c => {
        Name => 'RawDevSettings',
        Writable => 'int16u',
        PrintConv => { #11
            0 => '(none)',
            BITMASK => {
                0 => 'WB Color Temp',
                1 => 'WB Gray Point',
                2 => 'Saturation',
                3 => 'Contrast',
                4 => 'Sharpness',
                5 => 'Color Space',
                6 => 'High Function',
                7 => 'Noise Reduction',
            },
        },
    },
);

# Olympus RAW processing B IFD (ref 11)
%Image::ExifTool::Olympus::RawDevelopment2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => {
        Name => 'RawDevVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x100 => { Name => 'RawDevExposureBiasValue',   Writable => 'rational64s' },
    0x101 => {
        Name => 'RawDevWhiteBalance',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Color Temperature',
            2 => 'Gray Point',
        },
    },
    0x102 => { Name => 'RawDevWhiteBalanceValue',   Writable => 'int16u' },
    0x103 => { Name => 'RawDevWBFineAdjustment',    Writable => 'int16s' },
    0x104 => { Name => 'RawDevGrayPoint',           Writable => 'int16u', Count => 3 },
    0x105 => { Name => 'RawDevContrastValue',       Writable => 'int16s', Count => 3 },
    0x106 => { Name => 'RawDevSharpnessValue',      Writable => 'int16s', Count => 3 },
    0x107 => { Name => 'RawDevSaturationEmphasis',  Writable => 'int16s', Count => 3 },
    0x108 => { Name => 'RawDevMemoryColorEmphasis', Writable => 'int16u' },
    0x109 => {
        Name => 'RawDevColorSpace',
        Writable => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
            2 => 'Pro Photo RGB',
        },
    },
    0x10a => {
        Name => 'RawDevNoiseReduction',
        Writable => 'int16u',
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Noise Reduction',
                1 => 'Noise Filter',
                2 => 'Noise Filter (ISO Boost)',
            },
        },
    },
    0x10b => {
        Name => 'RawDevEngine',
        Writable => 'int16u',
        PrintConv => {
            0 => 'High Speed',
            1 => 'High Function',
        },
    },
    0x10c => {
        Name => 'RawDevPictureMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Vivid',
            2 => 'Natural',
            3 => 'Muted',
            256 => 'Monotone',
            512 => 'Sepia',
        },
    },
    0x10d => { Name => 'RawDevPMSaturation',    Writable => 'int16s', Count => 3 },
    0x10e => { Name => 'RawDevPMContrast',      Writable => 'int16s', Count => 3 },
    0x10f => { Name => 'RawDevPMSharpness',     Writable => 'int16s', Count => 3 },
    0x110 => {
        Name => 'RawDevPM_BWFilter',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Neutral',
            2 => 'Yellow',
            3 => 'Orange',
            4 => 'Red',
            5 => 'Green',
        },
    },
    0x111 => {
        Name => 'RawDevPMPictureTone',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Neutral',
            2 => 'Sepia',
            3 => 'Blue',
            4 => 'Purple',
            5 => 'Green',
        },
    },
    0x112 => { Name => 'RawDevGradation',       Writable => 'int16s', Count => 3 },
    0x113 => { Name => 'RawDevSaturation3',     Writable => 'int16s', Count => 3 }, #(NC Count)
    0x119 => { Name => 'RawDevAutoGradation',   Writable => 'int16u', PrintConv => \%offOn },
    0x120 => { Name => 'RawDevPMNoiseFilter',   Writable => 'int16u' }, #(NC format)
    0x121 => { #PH (E-P5)
        Name => 'RawDevArtFilter',
        Writable => 'int16u',
        Count => 4,
        PrintConvColumns => 2,
        PrintConv => [ \%filters ],
    },
    0x8000 => {
        Name => 'RawDevSubIFD',
        Groups => { 1 => 'MakerNotes' },
        Flags => 'SubIFD',
        FixFormat => 'ifd',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::RawDevSubIFD',
            Start => '$val',
        },
    },
);

%Image::ExifTool::Olympus::RawDevSubIFD = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# Olympus Image processing IFD
%Image::ExifTool::Olympus::ImageProcessing = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'ImageProcessingVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x100 => {  #6
        Name => 'WB_RBLevels',
        Writable => 'int16u',
        Notes => q{
            These tags store 2 values, red and blue levels, for some models, but 4
            values, presumably RBGG levels, for other models
        },
        Count => -1,
    }, #6
    # 0x101 - in-camera AutoWB unless it is all 0's or all 256's (ref IB)
    0x102 => { Name => 'WB_RBLevels3000K',  Writable => 'int16u', Count => -1 }, #11
    0x103 => { Name => 'WB_RBLevels3300K',  Writable => 'int16u', Count => -1 }, #11
    0x104 => { Name => 'WB_RBLevels3600K',  Writable => 'int16u', Count => -1 }, #11
    0x105 => { Name => 'WB_RBLevels3900K',  Writable => 'int16u', Count => -1 }, #11
    0x106 => { Name => 'WB_RBLevels4000K',  Writable => 'int16u', Count => -1 }, #11
    0x107 => { Name => 'WB_RBLevels4300K',  Writable => 'int16u', Count => -1 }, #11
    0x108 => { Name => 'WB_RBLevels4500K',  Writable => 'int16u', Count => -1 }, #11
    0x109 => { Name => 'WB_RBLevels4800K',  Writable => 'int16u', Count => -1 }, #11
    0x10a => { Name => 'WB_RBLevels5300K',  Writable => 'int16u', Count => -1 }, #11
    0x10b => { Name => 'WB_RBLevels6000K',  Writable => 'int16u', Count => -1 }, #11
    0x10c => { Name => 'WB_RBLevels6600K',  Writable => 'int16u', Count => -1 }, #11
    0x10d => { Name => 'WB_RBLevels7500K',  Writable => 'int16u', Count => -1 }, #11
    0x10e => { Name => 'WB_RBLevelsCWB1',   Writable => 'int16u', Count => -1 }, #11
    0x10f => { Name => 'WB_RBLevelsCWB2',   Writable => 'int16u', Count => -1 }, #11
    0x110 => { Name => 'WB_RBLevelsCWB3',   Writable => 'int16u', Count => -1 }, #11
    0x111 => { Name => 'WB_RBLevelsCWB4',   Writable => 'int16u', Count => -1 }, #11
    0x113 => { Name => 'WB_GLevel3000K',    Writable => 'int16u' }, #11
    0x114 => { Name => 'WB_GLevel3300K',    Writable => 'int16u' }, #11
    0x115 => { Name => 'WB_GLevel3600K',    Writable => 'int16u' }, #11
    0x116 => { Name => 'WB_GLevel3900K',    Writable => 'int16u' }, #11
    0x117 => { Name => 'WB_GLevel4000K',    Writable => 'int16u' }, #11
    0x118 => { Name => 'WB_GLevel4300K',    Writable => 'int16u' }, #11
    0x119 => { Name => 'WB_GLevel4500K',    Writable => 'int16u' }, #11
    0x11a => { Name => 'WB_GLevel4800K',    Writable => 'int16u' }, #11
    0x11b => { Name => 'WB_GLevel5300K',    Writable => 'int16u' }, #11
    0x11c => { Name => 'WB_GLevel6000K',    Writable => 'int16u' }, #11
    0x11d => { Name => 'WB_GLevel6600K',    Writable => 'int16u' }, #11
    0x11e => { Name => 'WB_GLevel7500K',    Writable => 'int16u' }, #11
    0x11f => { Name => 'WB_GLevel',         Writable => 'int16u' }, #11
    # 0x121 = WB preset for flash (about 6000K) (ref IB)
    # 0x125 = WB preset for underwater (ref IB)
    0x200 => { #6
        Name => 'ColorMatrix',
        Writable => 'int16u',
        Format => 'int16s',
        Count => 9,
    },
    # color matrices (ref 11):
    # 0x0201-0x020d are sRGB color matrices
    # 0x020e-0x021a are Adobe RGB color matrices
    # 0x021b-0x0227 are ProPhoto RGB color matrices
    # 0x0228 and 0x0229 are ColorMatrix for E-330
    # 0x0250-0x0252 are sRGB color matrices
    # 0x0253-0x0255 are Adobe RGB color matrices
    # 0x0256-0x0258 are ProPhoto RGB color matrices
    0x300 => { Name => 'Enhancer',          Writable => 'int16u' }, #11
    0x301 => { Name => 'EnhancerValues',    Writable => 'int16u', Count => 7 }, #11
    0x310 => { Name => 'CoringFilter',      Writable => 'int16u' }, #11
    0x311 => { Name => 'CoringValues',      Writable => 'int16u', Count => 7 }, #11
    0x600 => { Name => 'BlackLevel2',       Writable => 'int16u', Count => 4 }, #11
    0x610 => { Name => 'GainBase',          Writable => 'int16u' }, #11
    0x611 => { Name => 'ValidBits',         Writable => 'int16u', Count => 2 }, #4/6
    0x612 => { Name => 'CropLeft',          Writable => 'int16u', Count => 2 }, #11
    0x613 => { Name => 'CropTop',           Writable => 'int16u', Count => 2 }, #11
    0x614 => { Name => 'CropWidth',         Writable => 'int32u' }, #PH/11
    0x615 => { Name => 'CropHeight',        Writable => 'int32u' }, #PH/11
    0x635 => { #PH (data starts with "CMIO\x01\0")
        Name => 'UnknownBlock1',
        Writable => 'undef',
        Notes => 'large unknown data block in ORF images but not JPG images',
        # 'Drop' because too large for APP1 in JPEG images
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x636 => { #PH (data starts with "CMIO\x01\0")
        Name => 'UnknownBlock2',
        Writable => 'undef',
        Notes => 'large unknown data block in ORF images but not JPG images',
        # 'Drop' because too large for APP1 in JPEG images
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    # 0x800 LensDistortionParams, float[9] (ref 11)
    # 0x801 LensShadingParams, int16u[16] (ref 11)
    0x0805 => { #IB
        Name => 'SensorCalibration',
        Notes => '2 numbers: 1. Recommended maximum, 2. Calibration midpoint',
        Writable => 'int16s',
        Count => 2,
    },
    # 0x1010-0x1012 are the processing options used in camera or in
    # Olympus software, which 0x050a-0x050c are in-camera only (ref 6)
    0x1010 => { #PH/4
        Name => 'NoiseReduction2',
        Writable => 'int16u',
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Noise Reduction',
                1 => 'Noise Filter',
                2 => 'Noise Filter (ISO Boost)',
            },
        },
    },
    0x1011 => { #6
        Name => 'DistortionCorrection2',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x1012 => { #PH/4
        Name => 'ShadingCompensation2',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x101c => { #11
        Name => 'MultipleExposureMode',
        Writable => 'int16u',
        Count => 2,
        PrintConv => [{
            0 => 'Off',
            1 => 'Live Composite', #github issue#61
            2 => 'On (2 frames)',
            3 => 'On (3 frames)',
        }],
    },
    0x1103 => { #PH
        Name => 'UnknownBlock3',
        Writable => 'undef',
        Notes => 'large unknown data block in ORF images but not JPG images',
        # 'Drop' because too large for APP1 in JPEG images
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x1104 => { #PH (overlaps data for 0x1103 in E-M5 ORF images)
        Name => 'UnknownBlock4',
        Writable => 'undef',
        Notes => 'large unknown data block in ORF images but not JPG images',
        # 'Drop' because too large for APP1 in JPEG images
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    0x1112 => { #11
        Name => 'AspectRatio',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {
            # '0 0' - have seen this with a 16:9 XZ-1 image - PH
            '1 1' => '4:3',
            '1 4' => '1:1', #PH (E-P5 Storyboard effect, does this indicate 4:3 converted to 6:6?)
            '2 1' => '3:2 (RAW)', #forum6285
            '2 2' => '3:2',
            '3 1' => '16:9 (RAW)', #forum6285
            '3 3' => '16:9',
            '4 1' => '1:1 (RAW)', #forum6285
            '4 4' => '6:6',
            '5 5' => '5:4',
            '6 6' => '7:6',
            '7 7' => '6:5',
            '8 8' => '7:5',
            '9 1' => '3:4 (RAW)', #forum6285
            '9 9' => '3:4',
        },
    },
    0x1113 => { Name => 'AspectFrame',  Writable => 'int16u', Count => 4 }, #11
    0x1200 => { #11/PH
        Name => 'FacesDetected',
        Writable => 'int32u',
        Count => -1,
        Notes => '2 or 3 values',
    },
    0x1201 => { #11/PH
        Name => 'FaceDetectArea',
        Writable => 'int16s',
        Count => -1, # (varies with model)
        Binary => 1, # (too long)
        Notes => q{
            for models with 2 values in FacesDetected this gives X/Y coordinates in the
            FaceDetectFrame for all 4 corners of the face rectangle.  For models with 3
            values in FacesDetected this gives X/Y coordinates, size and rotation angle
            of the face detect square
        },
    },
    0x1202 => { Name => 'MaxFaces',     Writable => 'int32u', Count => 3 }, #PH
    0x1203 => { #PH
        Name => 'FaceDetectFrameSize',
        Writable => 'int16u',
        Count => 6,
        Notes => 'width/height of the full face detect frame',
    },
    0x1207 => { #PH
        Name => 'FaceDetectFrameCrop',
        Writable => 'int16s',
        Count => 12,
        Notes => 'X/Y offset and width/height of the cropped face detect frame',
    },
    0x1306 => { #PH (NC, E-M1)
        Name => 'CameraTemperature',
        Writable => 'int16u',
        Format => 'int16s', #(NC)
        ValueConv => '$val ? $val : undef', # zero for some models (how to differentiate from 0 C?)
        Notes => 'this seems to be in degrees C only for some models',
    },
    0x1900 => { #23
        Name => 'KeystoneCompensation',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {
            '0 0' => 'Off',
            '0 1' => 'On',
        },
    },
    0x1901 => { #23
        Name => 'KeystoneDirection',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {
            0 => 'Vertical',
            1 => 'Horizontal',
        },
    },
    # 0x1905 - focal length (PH, E-M1)
    0x1906 => { #23
        Name => 'KeystoneValue',
        Writable => 'int16s',
        Count => 3,
        # (use in conjunction with KeystoneDirection, -ve is Top or Right, +ve is Bottom or Left)
        Notes => '3 numbers: 1. Keystone Value, 2. Min, 3. Max',
    },
    0x2110 => { #25
        Name => 'GNDFilterType',
        Format => 'int8u',
        PrintConv => { 0 => 'High', 1 => 'Medium', 2 => 'Soft' },
    },
);

# Olympus Focus Info IFD
%Image::ExifTool::Olympus::FocusInfo = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => { #PH
        Name => 'FocusInfoVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x209 => { #PH/4
        Name => 'AutoFocus',
        Writable => 'int16u',
        PrintConv => \%offOn,
        Unknown => 1, #6
    },
    0x210 => { Name => 'SceneDetect',       Writable => 'int16u' }, #11
    0x211 => { #11
        Name => 'SceneArea',
        Writable => 'int32u',
        Count => 8,
        Unknown => 1, # (numbers don't make much sense?)
    },
    0x212 => { #11
        Name => 'SceneDetectData',
        Writable => 'int32u',
        Count => 720,
        Binary => 1,
        Unknown => 1, # (but what does it mean?)
    },
    # 0x214 - int16u: normally 0, but 1 for E-M1 focus-bracketing, and have seen 1 and 256 at other times
    0x300 => { Name => 'ZoomStepCount',     Writable => 'int16u' }, #6
    0x301 => { Name => 'FocusStepCount',    Writable => 'int16u' }, #11
    0x303 => { Name => 'FocusStepInfinity', Writable => 'int16u' }, #11
    0x304 => { Name => 'FocusStepNear',     Writable => 'int16u' }, #11
    0x305 => { #4
        Name => 'FocusDistance',
        Writable => 'rational64u',
        # this rational value looks like it is in mm when the denominator is
        # 1 (E-1), and cm when denominator is 10 (E-300), so if we ignore the
        # denominator we are consistently in mm - PH
        Format => 'int32u',
        Count => 2,
        ValueConv => q{
            my ($a,$b) = split ' ',$val;
            return 0 if $a == 0xffffffff;
            return $a / 1000;
        },
        ValueConvInv => q{
            return '4294967295 1' unless $val;
            $val = int($val * 1000 + 0.5);
            return "$val 1";
        },
        PrintConv => '$val ? "$val m" : "inf"',
        PrintConvInv => '$val eq "inf" ? 0 : $val=~s/\s*m$//, $val',
    },
    0x308 => [ # NEED A BETTER WAY TO DETERMINE WHICH MODELS USE WHICH ENCODING!
        {
            Name => 'AFPoint',
            Condition => '$$self{Model} =~ /E-(3|5|30)\b/',
            Writable => 'int16u',
            PrintHex => 1,
            # decoded by ref 6
            Notes => q{
                for the E-3, E-5 and E-30 the value is separated into 2 parts: low 5 bits
                give AF point, upper bits give AF target selection mode
            },
            ValueConv => '($val & 0x1f) . " " . ($val & 0xffe0)',
            ValueConvInv => 'my @v=split(" ",$val); @v == 2 ? $v[0] + $v[1] : $val',
            PrintConvColumns => 2,
            PrintConv => [
                {
                    0x00 => '(none)',
                    0x01 => 'Top-left (horizontal)',
                    0x02 => 'Top-center (horizontal)',
                    0x03 => 'Top-right (horizontal)',
                    0x04 => 'Left (horizontal)',
                    0x05 => 'Mid-left (horizontal)',
                    0x06 => 'Center (horizontal)',
                    0x07 => 'Mid-right (horizontal)',
                    0x08 => 'Right (horizontal)',
                    0x09 => 'Bottom-left (horizontal)',
                    0x0a => 'Bottom-center (horizontal)',
                    0x0b => 'Bottom-right (horizontal)',
                    0x0c => 'Top-left (vertical)',
                    0x0d => 'Top-center (vertical)',
                    0x0e => 'Top-right (vertical)',
                    0x0f => 'Left (vertical)',
                    0x10 => 'Mid-left (vertical)',
                    0x11 => 'Center (vertical)',
                    0x12 => 'Mid-right (vertical)',
                    0x13 => 'Right (vertical)',
                    0x14 => 'Bottom-left (vertical)',
                    0x15 => 'Bottom-center (vertical)',
                    0x16 => 'Bottom-right (vertical)',
                    0x1f => 'n/a', #PH (NC, E-3)
                },
                {
                    0x00 => 'Single Target',
                    0x40 => 'All Target',
                    0x80 => 'Dynamic Single Target',
                    0xe0 => 'n/a', #PH (NC, E-3)
                }
            ],
        },{ #PH (models with 7-point AF)
            Name => 'AFPoint',
            Condition => '$$self{Model} =~ /E-(520|600|620)\b/',
            Notes => 'models with 7-point AF',
            Writable => 'int16u',
            PrintHex => 1,
            ValueConv => '($val & 0x1f) . " " . ($val & 0xffe0)',
            ValueConvInv => 'my @v=split(" ",$val); @v == 2 ? $v[0] + $v[1] : $val',
            PrintConv => [ # herb values added:
                           # based on code of W.P. in https://exiftool.org/forum/index.php?topic=14144.0
                {
                    # 0x00 => '(none)',
                    # 0x01 => 'Center',
                    # need to fill this in...
                    0x00 => '(none)',
                    0x02 => 'Top-center (horizontal)',
                    0x04 => 'Right (horizontal)',
                    0x05 => 'Mid-right (horizontal)',
                    0x06 => 'Center (horizontal)',
                    0x07 => 'Mid-left (horizontal)',
                    0x08 => 'Left (horizontal)',
                    0x0a => 'Bottom-center (horizontal)',
                    0x0c => 'Top-center (vertical)',
                    0x0f => 'Right (vertical)',
                    0x15 => 'Bottom-center (vertical)',
                    0x10 => 'Mid-right (vertical)',
                    0x11 => 'Center (vertical)',
                    0x12 => 'Mid-left (vertical)',
                    0x13 => 'Left (vertical)',
                },
                {
                    0x00 => 'Single Target',
                    0x40 => 'All Target', # (guess)
                },
            ]
        },{ #herb all camera model except E-Mxxx and OM-x
            Name => 'AFPoint',
            Condition => '$$self{Model} !~ /^(E-M|OM-)/  ',
            Writable => 'int16u',
            Notes => 'models other than E-Mxxx and OM-x',
            RawConv => '($val or $$self{Model} ne "E-P1") ? $val : undef',
            PrintConv => {
                # (E-P1 always writes 0, maybe other models do too - PH)
                0 => 'Left (or n/a)',
                1 => 'Center (horizontal)', #6 (E-510)
                2 => 'Right',
                3 => 'Center (vertical)', #6 (E-510)
                255 => 'None',
            },
        },{ #herb all newer models E-Mxxx and OM-x; we do not know details
            Name => 'AFPoint',
            Writable => 'int16u',
            Notes => 'other models',
        }
    ],
    # 0x31a Continuous AF parameters?
    0x31b => [ #herb, based on investigations of abgestumpft: https://exiftool.org/forum/index.php?topic=14527.0
               # for newer models E-Mxxx and OM-x
        {
            Name => 'AFPointDetails',
            Condition => '$$self{Model} =~ m/^E-M|^OM-/ ',
            Writable => 'int16u',
            Notes => 'models E-Mxxx and OM-x',
            PrintHex => 1,
            ValueConv => '(($val >> 13) & 0x7) . " " . (($val >> 12) & 0x1) . " " .  (($val >> 11) & 0x1) . " " .
            #               subject detect               face and eye                  half press
                          (($val >> 8) & 0x3) . " " . (($val >> 7) & 0x1) . " " . (($val >> 5) & 0x1) . " " .
            #               eye AF                      face detect                 x-AF with MF
                          (($val >> 4) & 0x1) . " " . (($val >> 3) & 0x1) . " " . ($val & 0x7)',
            #               release                     object found               MF...
            PrintConvColumns => 4,
            PrintConv => [
                {
                    # should be identical to AISubjectTrackingMode
                    0 => 'No Subject Detection',
                    1 => 'Motorsports',
                    2 => 'Airplanes',
                    3 => 'Trains',
                    4 => 'Birds',
                    5 => 'Dogs & Cats',
                    6 => 'Human', #forum16072
                },{
                    0 => 'Face Priority',
                    1 => 'Target Priority',
                },{
                    0 => 'Normal AF',
                    1 => 'AF on Half Press',
                },{
                    0 => 'No Eye-AF',
                    1 => 'Right Eye Priority',
                    2 => 'Left Eye Priority',
                    3 => 'Both Eyes Priority',
                },{
                    0 => 'No Face Detection',
                    1 => 'Face Detection',
                },{
                    0 => 'No MF',
                    1 => 'With MF',
                },{
                    0 => 'AF Priority',
                    1 => 'Release Priority',
                },{
                    0 => 'No Object found',
                    1 => 'Object found',
                },{
                    0 => 'MF',
                    1 => 'S-AF',
                    2 => 'C-AF',
                    6 => 'C-AF + TR',
                },
            ],
        },{ # for older models
            Name => 'AFPointDetails',
            Writable => 'int16u',
            Notes => 'other models',
        }
    ],
    0x328 => { #PH
        Name => 'AFInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::AFInfo' },
    },
    # 0x1200-0x1209 Flash information:
    0x1201 => { #6
        Name => 'ExternalFlash',
        Writable => 'int16u',
        Count => 2,
        PrintConv => {
            '0 0' => 'Off',
            '1 0' => 'On',
        },
    },
    0x1203 => { #11
        Name => 'ExternalFlashGuideNumber',
        Writable => 'rational64s',
        Unknown => 1, # (needs verification)
    },
    0x1204 => { #11(reversed)/7
        Name => 'ExternalFlashBounce',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Bounce or Off',
            1 => 'Direct',
        },
    },
    0x1205 => { Name => 'ExternalFlashZoom', Writable => 'rational64u' }, #11 (ref converts to mm using table)
    0x1208 => { #6
        Name => 'InternalFlash',
        Writable => 'int16u',
        Count => -1,
        PrintConv => {
            '0'   => 'Off',
            '1'   => 'On',
            '0 0' => 'Off',
            '1 0' => 'On',
        },
    },
    0x1209 => { #6
        Name => 'ManualFlash',
        Writable => 'int16u',
        Count => 2,
        Notes => '2 numbers: 1. 0=Off, 1=On, 2. Flash strength',
        PrintConv => q{
            my ($a,$b) = split ' ',$val;
            return 'Off' unless $a;
            $b = ($b == 1) ? 'Full' : "1/$b";
            return "On ($b strength)";
        },
    },
    0x120a => { #PH
        Name => 'MacroLED',
        Writable => 'int16u',
        PrintConv => \%offOn,
    },
    0x1500 => [{ #6
        Name => 'SensorTemperature',
        # (Stylus 1 stores values like "34 0 0")
        Condition => '$$self{Model} =~ /E-(1|M5)\b/ || $count != 1',
        Writable => 'int16s',
        PrintConv => '$val=~s/ 0 0$//; "$val C"',
        PrintConvInv => '$val=~s/ ?C$//; $val',
    },{
        Name => 'SensorTemperature',
        Writable => 'int16s',
        RawConv => '($val and $val ne "-32768") ? $val : undef', # ignore 0 and -32768
        # ValueConv => '-2*(($val/135)**2)+55', #11
        ValueConv => '84 - 3 * $val / 26', #https://exiftool.org/forum/index.php/topic,5423.0.html
        ValueConvInv => 'int((84 - $val) * 26 / 3 + 0.5)',
        PrintConv => 'sprintf("%.1f C",$val)',
        PrintConvInv => '$val=~s/ ?C$//; $val',
        # data from test shots by Eric Sibert:
        #    E-510           E-620
        # Raw  Ambient    Raw  Ambient
        # ---  -------    ---  -------
        # 534    22.7     518    22.7
        # 550    20.6     531    19.3
        # 552    20.8     533    17.9
        # 558    19.3     582    17.2
        # 564    19.1     621    12.3
        # 567    17.8     634     9.7
        # 576    18.6     650     8.0
        # 582    17.2     660     7.7
        # 599    13.8     703     3.3
        # 631    10.7     880   -20.6
        # 642    12.4     880   -20.6
        # 652     9.6     892   -24.4
        # 692     5.2     892   -22.7
        # 714     3.3
        # 895   -19.8
        # 895   -19.2
        # 900   -21.7
    }],
    0x1600 => { # ref http://fourthirdsphoto.com/vbb/showpost.php?p=107607&postcount=15
        Name => 'ImageStabilization',
        # (the other value is more reliable, so ignore this totally if the other exists)
        Condition => 'not defined $$self{ImageStabilization}',
        Writable => 'undef',
        # if the first 4 bytes are non-zero, then bit 0x01 of byte 44
        # gives the stabilization mode
        PrintConv => q{
            $val =~ /^\0{4}/ ? 'Off' : 'On, ' .
            (unpack('x44C',$val) & 0x01 ? 'Mode 1' : 'Mode 2')
        },
    },
    # 0x102a same as Subdir4-0x300
    0x2100 => 'AntiShockWaitingTime', #25
);

# AF information (ref PH)
%Image::ExifTool::Olympus::AFInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    # 0x2a - int8u:  ImagerAFMode?  0=Manual, 1=Auto
    # 0x30 - int16u: AFAreaXPosition?
    # 0x32 - int16u: AFAreaWidth? (202)
    # 0x34 - int16u: AFAreaYPosition?
    # 0x36 - int16u: AFAreaHeight? (50)
    #  (AF area positions above give the top-left coordinates of the AF area in the
    #   AF frame. Increasing Y is downwards, and the AF frame size is about 1280x256)
    0x062c => { #25
        Name => 'CAFSensitivity',
        Format => 'int8s',
    },
);

# Olympus raw information tags (ref 6)
%Image::ExifTool::Olympus::RawInfo = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    NOTES => 'These tags are found only in ORF images of some models (eg. C8080WZ).',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x000 => {
        Name => 'RawInfoVersion',
        Writable => 'undef',
        RawConv => '$val=~s/\0+$//; $val',  # (may be null terminated)
        Count => 4,
    },
    0x100 => { Name => 'WB_RBLevelsUsed',           Writable => 'int16u', Count => 2 },
    0x110 => { Name => 'WB_RBLevelsAuto',           Writable => 'int16u', Count => 2 },
    0x120 => { Name => 'WB_RBLevelsShade',          Writable => 'int16u', Count => 2 },
    0x121 => { Name => 'WB_RBLevelsCloudy',         Writable => 'int16u', Count => 2 },
    0x122 => { Name => 'WB_RBLevelsFineWeather',    Writable => 'int16u', Count => 2 },
    0x123 => { Name => 'WB_RBLevelsTungsten',       Writable => 'int16u', Count => 2 },
    0x124 => { Name => 'WB_RBLevelsEveningSunlight',Writable => 'int16u', Count => 2 },
    0x130 => { Name => 'WB_RBLevelsDaylightFluor',  Writable => 'int16u', Count => 2 },
    0x131 => { Name => 'WB_RBLevelsDayWhiteFluor',  Writable => 'int16u', Count => 2 },
    0x132 => { Name => 'WB_RBLevelsCoolWhiteFluor', Writable => 'int16u', Count => 2 },
    0x133 => { Name => 'WB_RBLevelsWhiteFluorescent',Writable => 'int16u', Count => 2 },
    0x200 => {
        Name => 'ColorMatrix2',
        Format => 'int16s',
        Writable => 'int16u',
        Count => 9,
    },
    # 0x240 => 'ColorMatrixDefault', ?
    # 0x250 => 'ColorMatrixSaturation', ?
    # 0x251 => 'ColorMatrixHue', ?
    # 0x252 => 'ColorMatrixContrast', ?
    # 0x300 => sharpness-related
    # 0x301 => list of sharpness-related values
    0x310 => { Name => 'CoringFilter',      Writable => 'int16u' },
    0x311 => { Name => 'CoringValues',      Writable => 'int16u', Count => 11 },
    0x600 => { Name => 'BlackLevel2',       Writable => 'int16u', Count => 4 },
    0x601 => {
        Name => 'YCbCrCoefficients',
        Notes => 'stored as int16u[6], but extracted as rational32u[3]',
        Format => 'rational32u',
    },
    0x611 => { Name => 'ValidPixelDepth',   Writable => 'int16u', Count => 2 },
    0x612 => { Name => 'CropLeft',          Writable => 'int16u' }, #11
    0x613 => { Name => 'CropTop',           Writable => 'int16u' }, #11
    0x614 => { Name => 'CropWidth',         Writable => 'int32u' },
    0x615 => { Name => 'CropHeight',        Writable => 'int32u' },
    0x1000 => {
        Name => 'LightSource',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            16 => 'Shade',
            17 => 'Cloudy',
            18 => 'Fine Weather',
            20 => 'Tungsten (Incandescent)',
            22 => 'Evening Sunlight',
            33 => 'Daylight Fluorescent',
            34 => 'Day White Fluorescent',
            35 => 'Cool White Fluorescent',
            36 => 'White Fluorescent',
            256 => 'One Touch White Balance',
            512 => 'Custom 1-4',
        },
    },
    # the following 5 tags all have 3 values: val, min, max
    0x1001 => { Name => 'WhiteBalanceComp',         Writable => 'int16s', Count => 3 },
    0x1010 => { Name => 'SaturationSetting',        Writable => 'int16s', Count => 3 },
    0x1011 => { Name => 'HueSetting',               Writable => 'int16s', Count => 3 },
    0x1012 => { Name => 'ContrastSetting',          Writable => 'int16s', Count => 3 },
    0x1013 => { Name => 'SharpnessSetting',         Writable => 'int16s', Count => 3 },
    # settings written by Camedia Master 4.x
    0x2000 => { Name => 'CMExposureCompensation',   Writable => 'rational64s' },
    0x2001 => { Name => 'CMWhiteBalance',           Writable => 'int16u' },
    0x2002 => { Name => 'CMWhiteBalanceComp',       Writable => 'int16s' },
    0x2010 => { Name => 'CMWhiteBalanceGrayPoint',  Writable => 'int16u', Count => 3 },
    0x2020 => { Name => 'CMSaturation',             Writable => 'int16s', Count => 3 },
    0x2021 => { Name => 'CMHue',                    Writable => 'int16s', Count => 3 },
    0x2022 => { Name => 'CMContrast',               Writable => 'int16s', Count => 3 },
    0x2023 => { Name => 'CMSharpness',              Writable => 'int16s', Count => 3 },
);

# Olympus unknown information tags
%Image::ExifTool::Olympus::UnknownInfo = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# Tags found only in some FE models
%Image::ExifTool::Olympus::FETags = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        Some FE models write a large number of tags here, but most of this
        information remains unknown.
    },
    0x0100 => {
        Name => 'BodyFirmwareVersion',
        Writable => 'string',
    },
);

# tags in Olympus QuickTime videos (ref PH)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Olympus::MOV1 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in MOV videos from Olympus models such as the
        D540Z, D595Z, FE100, FE110, FE115, FE170 and FE200.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[8]',
        SeparateTable => 'CameraType',
        PrintConv => \%olympusCameraTypes,
    },
    # (01 00 at offset 0x20)
    0x26 => {
        Name => 'ExposureUnknown',
        Unknown => 1,
        Format => 'int32u',
        # this conversion doesn't work for all models (eg. gives "1/100000")
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x2a => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    0x32 => { #(NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
  # 0x44 => WhiteBalance ?
    0x48 => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
  # 0xb1 => 'ISO', #(I don't think this works - PH)
);

# tags in Olympus QuickTime videos (ref PH)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Olympus::MOV2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in MOV videos from Olympus models such as the
        FE120, FE140 and FE190.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
        Notes => 'the actual model name, no decoding necessary',
    },
    # (01 00 at offset 0x30)
    0x36 => {
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x3a => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    0x42 => { #(NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    0x58 => {
        Name => 'FocalLength',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    0xc1 => {
        Name => 'ISO',
        Format => 'int16u',
    },
);

# tags in Olympus MP4 videos (ref PH)
%Image::ExifTool::Olympus::MP4 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in MP4 videos from Olympus models such as the
        u7040 and u9010.
    },
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x18 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
        Notes => 'oddly different than CameraType values in JPEG images by the same camera',
        PrintConv => {
            SG472 => 'u7040,S7040',
            SG473 => 'u9010,S9010',
            SG475 => 'SP800UZ',
            SG551 => 'SZ-30MR',
            SG553 => 'SP-610UZ',
            SG554 => 'SZ-10',
            SG555 => 'SZ-20',
            SG573 => 'SZ-14',
            SG575 => 'SP-620UZ',
        },
    },
    0x28 => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    0x30 => { #(NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
    },
    # 0x38 - int32u: 3
    # 0x3c - int32u: 1
    # 0x40 - int16u: 5
    # 0x42 - int16u: 0,4,9
    # 0x64 - int32u: 0,6000,12000
    # 0x48 - int32u: 100 (ISO?)
    0x68 => {
        Name => 'MovableInfo',
        Condition => '$$valPt =~ /^DIGI/',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::MovableInfo' },
    },
    0x72 => {
        Name => 'MovableInfo',
        Condition => '$$valPt =~ /^DIGI/',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::MovableInfo' },
    },
);

# yet a different QuickTime TAGS format (PH, E-M5)
%Image::ExifTool::Olympus::MOV3 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'QuickTime information found in the TAGS atom of MOV videos from the E-M5.',
    OLYM => {
        Name => 'OlympusAtom',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::OLYM2' },
    },
);

# yet a different QuickTime OLYM atom format (PH, E-M5)
%Image::ExifTool::Olympus::OLYM2 = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    prms => {
        Name => 'MakerNotes',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::prms' },
    },
    thmb =>{
        Name => 'ThumbInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::thmb2' },
    },
    scrn =>{
        Name => 'PreviewInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::scrn2' },
    },
);

# the "prms" atom in E-M5 MOV videos (PH, E-M5)
%Image::ExifTool::Olympus::prms = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => q{
        Information extracted from the "prms" atom in MOV videos from Olympus models
        such as the OM E-M5.
    },
    0x12 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x2c => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
        SeparateTable => 'CameraType',
        PrintConv => \%olympusCameraTypes,
    },
    0x83 => {
        Name => 'DateTime1',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0x9d => {
        Name => 'DateTime2',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0x17f => {
        Name => 'LensModel',
        Format => 'string[32]'
    },
);

# yet a different "thmb" atom format (PH, E-M5)
%Image::ExifTool::Olympus::thmb2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'ThumbnailWidth',
        Format => 'int16u',
    },
    2 => {
        Name => 'ThumbnailHeight',
        Format => 'int16u',
    },
    4 => {
        Name => 'ThumbnailLength',
        Format => 'int32u',
    },
    8 => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{4}]',
        Notes => '160x120 JPEG thumbnail image',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# yet a different "scrn" atom format (PH, E-M5)
%Image::ExifTool::Olympus::scrn2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # 0 => int16u: 1 - number of preview images?
    2 => {
        Name => 'OlympusPreview',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::scrn' },
    },
);

# movable information found in MP4 videos
%Image::ExifTool::Olympus::MovableInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    0x04 => { #(NC)
        Name => 'ISO',
        Format => 'int32u',
    },
    0x2c => {
        Name => 'EncoderVersion',
        Format => 'string[16]',
    },
    0x3c => {
        Name => 'DecoderVersion',
        Format => 'string[16]',
    },
    0x83 => {
        Name => 'Thumbnail',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::Thumbnail',
            Base => '$start', # (use a separate table because of this)
        },
    },
);

# thumbnail image information found in MP4 videos (similar in Olympus,Samsung,Sanyo) (ref PH)
%Image::ExifTool::Olympus::Thumbnail = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    FORMAT => 'int32u',
    1 => 'ThumbnailWidth',
    2 => 'ThumbnailHeight',
    3 => 'ThumbnailLength',
    4 => { Name => 'ThumbnailOffset', IsOffset => 1 },
);

# thumbnail information found in 'thmb' atom of MP4 videos from the TG-810 (ref PH)
%Image::ExifTool::Olympus::thmb = (
    NOTES => 'Information extracted from the "thmb" atom of Olympus MP4 videos.',
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'ThumbnailLength',
        Format => 'int32u',
    },
    4 => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{0}]',
        Notes => '160x120 JPEG thumbnail image',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# thumbnail information found in 'scrn' atom of MP4 videos from the TG-810 (ref PH)
%Image::ExifTool::Olympus::scrn = (
    NOTES => 'Information extracted from the "scrn" atom of Olympus MP4 videos.',
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'PreviewImageLength',
        Format => 'int32u',
    },
    4 => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{0}]',
        Notes => '640x480 JPEG preview image',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# information in OLYM atom of MP4 videos from the TG-810 (ref PH)
%Image::ExifTool::Olympus::OLYM = (
    NOTES => 'Tags found in the OLYM atom of MP4 videos from the TG-810.',
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0e => {
        Name => 'Make',
        Format => 'string[26]',
    },
    0x28 => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
        SeparateTable => 'CameraType',
        PrintConv => \%olympusCameraTypes,
    },
    0x5a => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    0x7f => {
        Name => 'DateTimeOriginal', #(NC)
        Description => 'Date/Time Original',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x99 => {
        Name => 'DateTime2',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0x109 => {
        Name => 'ThumbnailWidth',
        Format => 'int16u',
    },
    0x10b => {
        Name => 'ThumbnailHeight',
        Format => 'int16u',
    },
);

# tags in Olympus AVI videos (ref PH)
# (very similar to Pentax::Junk2 tags)
%Image::ExifTool::Olympus::AVI = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => 'This information is found in Olympus AVI videos.',
    0x12 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x2c => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
        SeparateTable => 'CameraType',
        PrintConv => \%olympusCameraTypes,
    },
    0x5e => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    0x83 => {
        Name => 'DateTime1',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0x9d => {
        Name => 'DateTime2',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0x129 => {
        Name => 'ThumbInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::thmb2' },
    },
);

# tags in WAV files from Olympus PCM linear recorders (ref 18)
%Image::ExifTool::Olympus::WAV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Audio' },
    FIRST_ENTRY => 0,
    NOTES => q{
        This information is found in WAV files from Olympus PCM linear recorders
        like the LS-5, LS-10, LS-11.
    },
    0x0c => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[16]',
    },
    0x1c => {
        Name => 'FileNumber',
        Format => 'int32u',
        PrintConv => 'sprintf("%.4d", $val)',
    },
    0x26 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Format => 'undef[12]',
        Notes => 'time at start of recording',
        ValueConv => q{
            return undef unless $val =~ /^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
            my $y = $1 < 70 ? "20$1" : "19$1";
            return "$y:$2:$3 $4:$5:$6";
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x32 => {
        Name => 'DateTimeEnd',
        Groups => { 2 => 'Time' },
        Format => 'undef[12]',
        Notes => 'time at end of recording',
        ValueConv => q{
            return undef unless $val =~ /^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
            my $y = $1 < 70 ? "20$1" : "19$1";
            return "$y:$2:$3 $4:$5:$6";
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x3e => {
        Name => 'RecordingTime',
        Format => 'undef[6]',
        ValueConv => '$val =~ s/^(\d{2})(\d{2})/$1:$2:/; $val',
    },
    0x200 => {
        Name => 'Duration',
        Format => 'int32u',
        ValueConv => '$val / 1000',
        PrintConv => 'ConvertDuration($val)',
    },
    0x20a => { Name => 'Index01', %indexInfo },
    0x214 => { Name => 'Index02', %indexInfo },
    0x21e => { Name => 'Index03', %indexInfo },
    0x228 => { Name => 'Index04', %indexInfo },
    0x232 => { Name => 'Index05', %indexInfo },
    0x23c => { Name => 'Index06', %indexInfo },
    0x246 => { Name => 'Index07', %indexInfo },
    0x250 => { Name => 'Index08', %indexInfo },
    0x25a => { Name => 'Index09', %indexInfo },
    0x264 => { Name => 'Index10', %indexInfo },
    0x26e => { Name => 'Index11', %indexInfo },
    0x278 => { Name => 'Index12', %indexInfo },
    0x282 => { Name => 'Index13', %indexInfo },
    0x28c => { Name => 'Index14', %indexInfo },
    0x296 => { Name => 'Index15', %indexInfo },
    0x2a0 => { Name => 'Index16', %indexInfo },
);

# DSS information written by Olympus voice recorders (ref PH)
%Image::ExifTool::Olympus::DSS = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Audio' },
    FIRST_ENTRY => 0,
    NOTES => q{
        Information extracted from DSS/DS2 files and the ID3 XOLY frame of MP3 files
        written by some Olympus voice recorders.
    },
    # 0 - file format:
    #   "\x02dss"(DSS file and XOLY frame in MP3 file)
    #   "\x03ds2"(DS2 file)
    #   "\x03mp3"(ID3 XOLY frame in MP3 file)
    12 => { Name => 'Model', Format => 'string[16]' }, # (name truncated by some models)
    38 => {
        Name => 'StartTime',
        Format => 'string[12]',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1:$2:$3 $4:$5:$6/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    50 => {
        Name => 'EndTime',
        Format => 'string[12]',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/20$1:$2:$3 $4:$5:$6/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    62 => {
        Name => 'Duration',
        Format => 'string[6]',
        ValueConv => '$val =~ /(\d{2})(\d{2})(\d{2})/ ? ($1 * 60 + $2) * 60 + $3 : undef',
        PrintConv => 'ConvertDuration($val)',
    },
    798 => { # (ref http://search.cpan.org/~rgibson/Audio-DSS-0.02/)
        Name => 'Comment',
        Format => 'string[100]',
    },
);

# Olympus composite tags
%Image::ExifTool::Olympus::Composite = (
    GROUPS => { 2 => 'Camera' },
    ExtenderStatus => {
        Notes => q{
            Olympus cameras have the quirk that they may retain the extender settings
            after the extender is removed until the camera is powered off.  This tag is
            an attempt to represent the actual status of the extender.
        },
        Require => {
            0 => 'Olympus:Extender',
            1 => 'Olympus:LensType',
            2 => 'MaxApertureValue',
        },
        ValueConv => 'Image::ExifTool::Olympus::ExtenderStatus($val[0],$prt[1],$val[2])',
        PrintConv => {
            0 => 'Not attached',
            1 => 'Attached',
            2 => 'Removed',
        },
    },
    ZoomedPreviewImage => {
        Groups => { 2 => 'Preview' },
        Require => {
            0 => 'ZoomedPreviewStart',
            1 => 'ZoomedPreviewLength',
        },
        RawConv => q{
            @grps = $self->GetGroup($$val{0});  # set groups from input tag
            Image::ExifTool::Exif::ExtractImage($self,$val[0],$val[1],"ZoomedPreviewImage");
        },
    },
    # this is actually for PanasonicRaw tags, but it uses the lens lookup here
    LensType => {
        Require => {
            0 => 'LensTypeMake',
            1 => 'LensTypeModel',
        },
        Notes => 'based on tags found in some Panasonic RW2 images',
        SeparateTable => 'Olympus LensType',
        ValueConv => '"$val[0] $val[1]"',
        PrintConv => \%olympusLensTypes,
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Olympus');


#------------------------------------------------------------------------------
# Determine if the extender (EX-25/EC-14) was really attached (ref 9)
# Inputs: 0) Extender, 1) LensType string, 2) MaxApertureAtMaxFocal
# Returns: 0=not attached, 1=attached, 2=could have been removed
# Notes: Olympus has a bug in the in-camera firmware which results in the
# extender information being cached and written into the EXIF data even after
# the extender has been removed.  You must power cycle the camera to prevent it
# from writing the cached extender information into the EXIF data.
sub ExtenderStatus($$$)
{
    my ($extender, $lensType, $maxAperture) = @_;
    my @info = split ' ', $extender;
    # validate that extender identifier is reasonable
    return 0 unless @info >= 2 and hex($info[1]);
    # if it's not an EC-14 (id '0 04') then assume it was really attached
    # (other extenders don't seem to affect the reported max aperture)
    return 1 if "$info[0] $info[1]" ne '0 04';
    # get the maximum aperture for this lens (in $1)
    $lensType =~ / F(\d+(\.\d+)?)/ or return 1;
    # If the maximum aperture at the maximum focal length is greater than the
    # known max/max aperture of the lens, then the extender must be attached
    return(($maxAperture - $1 > 0.2) ? 1 : 2);
}

#------------------------------------------------------------------------------
# Print AF points
# Inputs: 0) AF point data (string of integers)
# Notes: I'm just guessing that the 2nd and 4th bytes are the Y coordinates,
# and that more AF points will show up in the future (derived from E-1 images,
# and the E-1 uses just one of 3 possible AF points, all centered in Y) - PH
sub PrintAFAreas($)
{
    my $val = shift;
    my @points = split ' ', $val;
    my %afPointNames = (
        0x36794285 => 'Left',
        0x79798585 => 'Center',
        0xBD79C985 => 'Right',
    );
    $val = '';
    my $pt;
    foreach $pt (@points) {
        next unless $pt;
        $val and $val .= ', ';
        $afPointNames{$pt} and $val .= $afPointNames{$pt} . ' ';
        my @coords = unpack('C4',pack('N',$pt));
        $val .= "($coords[0],$coords[1])-($coords[2],$coords[3])";
    }
    $val or $val = 'none';
    return $val;
}

#------------------------------------------------------------------------------
# Extract information from a DSS/DS2 voice recorder audio file or ID3 XOLY frame
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success
sub ProcessDSS($$;$)
{
    my ($et, $dirInfo) = @_;

    # allow this to be called with either RAF or DataPt
    my $raf = $$dirInfo{RAF};
    if ($raf) {
        my $buff;
        $raf->Read($buff, 898) > 68 or return 0;
        $buff =~ /^(\x02dss|\x03ds2)/ or return 0;
        $dirInfo = { DataPt => \$buff };
        $et->SetFileType(uc substr $buff, 1, 3);
    }
    my $tagTablePtr = GetTagTable('Image::ExifTool::Olympus::DSS');
    return $et->ProcessBinaryData($dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Process ORF file
# Inputs: 0) ExifTool object reference, 1) directory information reference
# Returns: 1 if this looked like a valid ORF file, 0 otherwise
sub ProcessORF($$)
{
    my ($et, $dirInfo) = @_;
    return $et->ProcessTIFF($dirInfo);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Olympus - Olympus/Epson maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Olympus or Epson maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://park2.wakwak.com/~tsuruzoh/Computer/Digicams/exif-e.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://www.ozhiker.com/electronics/pjmt/jpeg_info/olympus_mn.html>

=item L<http://olypedia.de/Olympus_Makernotes>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Markku Hanninen, Remi Guyomarch, Frank Ledwon, Michael Meissner,
Mark Dapoz, Ioannis Panagiotopoulos and Tomasz Kawecki for their help
figuring out some Olympus tags, and Lilo Huang, Chris Shaw and Viktor
Lushnikov for adding to the LensType list.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Olympus Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
