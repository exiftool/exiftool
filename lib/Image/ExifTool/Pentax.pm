#------------------------------------------------------------------------------
# File:         Pentax.pm
#
# Description:  Pentax/Asahi EXIF maker notes tags
#
# Revisions:    11/25/2003 - P. Harvey Created
#               02/10/2004 - P. Harvey Completely re-done
#               02/16/2004 - W. Smith Updated (see ref 3)
#               11/10/2004 - P. Harvey Added support for Asahi cameras
#               01/10/2005 - P. Harvey Added LensType with values from ref 4
#               03/30/2005 - P. Harvey Added new tags from ref 5
#               10/04/2005 - P. Harvey Added MOV tags
#               10/22/2007 - P. Harvey Got my new K10D! (more new tags to decode)
#               11/03/2010 - P. Harvey Got my new K-5! (a gold mine of new tags to discover!)
#
# References:   1) Image::MakerNotes::Pentax
#               2) http://johnst.org/sw/exiftags/ (Asahi cameras)
#               3) Wayne Smith private communication (Optio 550)
#               4) http://kobe1995.jp/~kaz/astro/istD.html
#               5) John Francis (http://www.panix.com/~johnf/raw/index.html) (ist-D/ist-DS)
#               6) http://www.cybercom.net/~dcoffin/dcraw/
#               7) Douglas O'Brien private communication (*istD, K10D)
#               8) Denis Bourez private communication
#               9) Kazumichi Kawabata private communication
#              10) David Buret private communication (*istD)
#              11) http://forums.dpreview.com/forums/read.asp?forum=1036&message=17465929
#              12) Derby Chang private communication
#              13) http://homepage3.nifty.com/kamisaka/makernote/makernote_pentax.htm (2007/02/28)
#              14) Ger Vermeulen private communication (Optio S6)
#              15) Barney Garrett private communication (Samsung GX-1S)
#              16) Axel Kellner private communication (K10D)
#              17) Cvetan Ivanov private communication (K100D)
#              18) http://gvsoft.homedns.org/exif/makernote-pentax-type3.html
#              19) Dave Nicholson private communication (K10D)
#              20) Bogdan and yeryry (http://www.cpanforum.com/posts/8037)
#              21) Peter (*istD, http://www.cpanforum.com/posts/8078)
#              22) Bozi (K10D, http://www.cpanforum.com/posts/8480)
#              23) Akos Szalkai (https://rt.cpan.org/Ticket/Display.html?id=43743)
#              24) Albert Bogner private communication
#              25) Niels Kristian Bech Jensen private communication
#              26) http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3444.0.html
#              27) http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,3833.0.html
#              28) Klaus Homeister http://u88.n24.queensu.ca/exiftool/forum/index.php/topic,4803.0.html
#              29) Louis Granboulan private communication (K-5II)
#              30) http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=5433
#              31) Iliah Borg private communication (LibRaw)
#              JD) Jens Duttke private communication
#
# Notes:        See POD documentation at the bottom of this file
#------------------------------------------------------------------------------

package Image::ExifTool::Pentax;

use strict;
use vars qw($VERSION %pentaxLensTypes);
use Image::ExifTool::Exif;
use Image::ExifTool::HP;

$VERSION = '2.89';

sub CryptShutterCount($$);
sub PrintFilter($$$);

# pentax lens type codes (ref 4)
# The first number gives the lens series, and the 2nd gives the model number
# Series numbers: K=1; A=2; F=3; FAJ=4; DFA=4,7; FA=3,4,5,6; FA*=5,6;
#                 DA=3,4,7; DA*=7,8; FA645=11; DFA645=13; Q=21
%pentaxLensTypes = (
    Notes => q{
        The first number gives the series of the lens, and the second identifies the
        lens model.  Note that newer series numbers may not always be properly
        identified by cameras running older firmware versions.  Decimal values have
        been added to differentiate lenses which would otherwise have the same
        LensType, and are used by the Composite LensID tag when attempting to
        identify the specific lens model.
    },
    OTHER => sub {
        my ($val, $inv, $conv) = @_;
        return undef if $inv;
        # *istD may report a series number of 4 for series 7 lenses
        $val =~ s/^4 /7 / and $$conv{$val} and return $$conv{$val} . " ($_[0])";
        # cameras that don't recognize SDM lenses (eg. older K10 firmware)
        # may report series 7 instead of 8
        $val =~ s/^7 /8 / and $$conv{$val} and return $$conv{$val} . " ? ($_[0])";
        return undef;
    },
    '0 0' => 'M-42 or No Lens', #17
    '1 0' => 'K or M Lens',
    '2 0' => 'A Series Lens', #7 (from smc PENTAX-A 400mm F5.6)
    '3 0' => 'Sigma', # (includes 'Sigma 30mm F1.4 EX DC' - PH)
    # (and 'Sigma 105mm F2.8 EX DG Macro', ref 24)
    # (and 'Sigma 18-50mm F2.8 EX Macro')
    # (and 'Sigma 180mm F4.5 EX DG Macro')
    # (and 'Sigma 70mm F2.8 EX DG Macro')
    # (and 'Sigma 50-500mm F4-6.3 DG APO')
    '3 17' => 'smc PENTAX-FA SOFT 85mm F2.8',
    '3 18' => 'smc PENTAX-F 1.7X AF ADAPTER',
    '3 19' => 'smc PENTAX-F 24-50mm F4',
    '3 20' => 'smc PENTAX-F 35-80mm F4-5.6',
    '3 21' => 'smc PENTAX-F 80-200mm F4.7-5.6',
    '3 22' => 'smc PENTAX-F FISH-EYE 17-28mm F3.5-4.5',
    '3 23' => 'smc PENTAX-F 100-300mm F4.5-5.6 or Sigma Lens',
    '3 23.1' => 'Sigma AF 28-300mm F3.5-5.6 DL IF', #JD
    '3 23.2' => 'Sigma AF 28-300mm F3.5-6.3 DG IF Macro', #JD
    '3 23.3' => 'Tokina 80-200mm F2.8 ATX-Pro', #Exiv2
    '3 24' => 'smc PENTAX-F 35-135mm F3.5-4.5',
    '3 25' => 'smc PENTAX-F 35-105mm F4-5.6 or Sigma or Tokina Lens',
    '3 25.1' => 'Sigma AF 28-300mm F3.5-5.6 DL IF', #11
    '3 25.2' => 'Sigma 55-200mm F4-5.6 DC', #JD
    '3 25.3' => 'Sigma AF 28-300mm F3.5-6.3 DL IF', #Exiv2
    '3 25.4' => 'Sigma AF 28-300mm F3.5-6.3 DG IF Macro', #JD
    '3 25.5' => 'Tokina 80-200mm F2.8 ATX-Pro', #12
    '3 26' => 'smc PENTAX-F* 250-600mm F5.6 ED[IF]',
    '3 27' => 'smc PENTAX-F 28-80mm F3.5-4.5 or Tokina Lens',
    '3 27.1' => 'Tokina AT-X Pro AF 28-70mm F2.6-2.8', #JD
    '3 28' => 'smc PENTAX-F 35-70mm F3.5-4.5 or Tokina Lens',
    '3 28.1' => 'Tokina 19-35mm F3.5-4.5 AF', #12
    '3 28.2' => 'Tokina AT-X AF 400mm F5.6', #25
    '3 29' => 'PENTAX-F 28-80mm F3.5-4.5 or Sigma or Tokina Lens',
    '3 29.1' => 'Sigma AF 18-125mm F3.5-5.6 DC', #11
    '3 29.2' => 'Tokina AT-X PRO 28-70mm F2.6-2.8', #22
    '3 30' => 'PENTAX-F 70-200mm F4-5.6',
    '3 31' => 'smc PENTAX-F 70-210mm F4-5.6 or Tokina or Takumar Lens',
    '3 31.1' => 'Tokina AF 730 75-300mm F4.5-5.6',
    '3 31.2' => 'Takumar-F 70-210mm F4-5.6', #JD
    '3 32' => 'smc PENTAX-F 50mm F1.4',
    '3 33' => 'smc PENTAX-F 50mm F1.7',
    '3 34' => 'smc PENTAX-F 135mm F2.8 [IF]',
    '3 35' => 'smc PENTAX-F 28mm F2.8',
    '3 36' => 'Sigma 20mm F1.8 EX DG Aspherical RF',
    '3 38' => 'smc PENTAX-F* 300mm F4.5 ED[IF]',
    '3 39' => 'smc PENTAX-F* 600mm F4 ED[IF]',
    '3 40' => 'smc PENTAX-F Macro 100mm F2.8',
    '3 41' => 'smc PENTAX-F Macro 50mm F2.8 or Sigma Lens', #4
    '3 41.1' => 'Sigma 50mm F2.8 Macro', #16
    '3 44' => 'Sigma or Tamron Lens (3 44)',
    '3 44.1' => 'Sigma AF 10-20mm F4-5.6 EX DC', #JD
    '3 44.2' => 'Sigma 12-24mm F4.5-5.6 EX DG', #12 (added "-5.6", ref 29)
    '3 44.3' => 'Sigma 17-70mm F2.8-4.5 DC Macro', #(Bart Hickman)
    '3 44.4' => 'Sigma 18-50mm F3.5-5.6 DC', #4
    '3 44.5' => 'Tamron 35-90mm F4 AF', #12
    '3 46' => 'Sigma or Samsung Lens (3 46)',
    '3 46.1' => 'Sigma APO 70-200mm F2.8 EX',
    '3 46.2' => 'Sigma EX APO 100-300mm F4 IF', #JD
    '3 46.3' => 'Samsung/Schneider D-XENON 50-200mm F4-5.6 ED', #29
    '3 50' => 'smc PENTAX-FA 28-70mm F4 AL',
    '3 51' => 'Sigma 28mm F1.8 EX DG Aspherical Macro',
    '3 52' => 'smc PENTAX-FA 28-200mm F3.8-5.6 AL[IF] or Tamron Lens',
    '3 52.1' => 'Tamron AF LD 28-200mm F3.8-5.6 [IF] Aspherical (171D)', #JD
    '3 53' => 'smc PENTAX-FA 28-80mm F3.5-5.6 AL',
    '3 247' => 'smc PENTAX-DA FISH-EYE 10-17mm F3.5-4.5 ED[IF]',
    '3 248' => 'smc PENTAX-DA 12-24mm F4 ED AL[IF]',
    '3 250' => 'smc PENTAX-DA 50-200mm F4-5.6 ED',
    '3 251' => 'smc PENTAX-DA 40mm F2.8 Limited',
    '3 252' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL',
    '3 253' => 'smc PENTAX-DA 14mm F2.8 ED[IF]',
    '3 254' => 'smc PENTAX-DA 16-45mm F4 ED AL',
    '3 255' => 'Sigma Lens (3 255)',
    '3 255.1' => 'Sigma 18-200mm F3.5-6.3 DC', #8
    '3 255.2' => 'Sigma DL-II 35-80mm F4-5.6', #12
    '3 255.3' => 'Sigma DL Zoom 75-300mm F4-5.6', #12
    '3 255.4' => 'Sigma DF EX Aspherical 28-70mm F2.8', #12
    '3 255.5' => 'Sigma AF Tele 400mm F5.6 Multi-coated', #JD
    '3 255.6' => 'Sigma 24-60mm F2.8 EX DG', #PH
    '3 255.7' => 'Sigma 70-300mm F4-5.6 Macro', #JD
    '3 255.8' => 'Sigma 55-200mm F4-5.6 DC', #JD
    '3 255.9' => 'Sigma 18-50mm F2.8 EX DC', #JD (also Macro version - PH)
    '4 1' => 'smc PENTAX-FA SOFT 28mm F2.8',
    '4 2' => 'smc PENTAX-FA 80-320mm F4.5-5.6',
    '4 3' => 'smc PENTAX-FA 43mm F1.9 Limited',
    '4 6' => 'smc PENTAX-FA 35-80mm F4-5.6',
    '4 12' => 'smc PENTAX-FA 50mm F1.4', #17
    '4 15' => 'smc PENTAX-FA 28-105mm F4-5.6 [IF]',
    '4 16' => 'Tamron AF 80-210mm F4-5.6 (178D)', #13
    '4 19' => 'Tamron SP AF 90mm F2.8 (172E)',
    '4 20' => 'smc PENTAX-FA 28-80mm F3.5-5.6',
    '4 21' => 'Cosina AF 100-300mm F5.6-6.7', #20
    '4 22' => 'Tokina 28-80mm F3.5-5.6', #13
    '4 23' => 'smc PENTAX-FA 20-35mm F4 AL',
    '4 24' => 'smc PENTAX-FA 77mm F1.8 Limited',
    '4 25' => 'Tamron SP AF 14mm F2.8', #13
    '4 26' => 'smc PENTAX-FA Macro 100mm F3.5 or Cosina Lens',
    '4 26.1' => 'Cosina 100mm F3.5 Macro', #JD
    '4 27' => 'Tamron AF 28-300mm F3.5-6.3 LD Aspherical[IF] Macro (185D/285D)',
    '4 28' => 'smc PENTAX-FA 35mm F2 AL',
    '4 29' => 'Tamron AF 28-200mm F3.8-5.6 LD Super II Macro (371D)', #JD
    '4 34' => 'smc PENTAX-FA 24-90mm F3.5-4.5 AL[IF]',
    '4 35' => 'smc PENTAX-FA 100-300mm F4.7-5.8',
  # '4 36' => 'Tamron AF70-300mm F4-5.6 LD Macro', # both 572D and A17 (Di) - ref JD
    '4 36' => 'Tamron AF 70-300mm F4-5.6 LD Macro 1:2', #25
    '4 37' => 'Tamron SP AF 24-135mm F3.5-5.6 AD AL (190D)', #13
    '4 38' => 'smc PENTAX-FA 28-105mm F3.2-4.5 AL[IF]',
    '4 39' => 'smc PENTAX-FA 31mm F1.8 AL Limited',
    '4 41' => 'Tamron AF 28-200mm Super Zoom F3.8-5.6 Aspherical XR [IF] Macro (A03)',
    '4 43' => 'smc PENTAX-FA 28-90mm F3.5-5.6',
    '4 44' => 'smc PENTAX-FA J 75-300mm F4.5-5.8 AL',
    '4 45' => 'Tamron Lens (4 45)',
    '4 45.1' => 'Tamron 28-300mm F3.5-6.3 Ultra zoom XR',
    '4 45.2' => 'Tamron AF 28-300mm F3.5-6.3 XR Di LD Aspherical [IF] Macro', #JD
    '4 46' => 'smc PENTAX-FA J 28-80mm F3.5-5.6 AL',
    '4 47' => 'smc PENTAX-FA J 18-35mm F4-5.6 AL',
   #'4 49' => 'Tamron SP AF 28-75mm F2.8 XR Di (A09)',
    '4 49' => 'Tamron SP AF 28-75mm F2.8 XR Di LD Aspherical [IF] Macro', #25
    '4 51' => 'smc PENTAX-D FA 50mm F2.8 Macro',
    '4 52' => 'smc PENTAX-D FA 100mm F2.8 Macro',
    '4 55' => 'Samsung/Schneider D-XENOGON 35mm F2', #29
    '4 56' => 'Samsung/Schneider D-XENON 100mm F2.8 Macro', #Alan Robinson
    '4 75' => 'Tamron SP AF 70-200mm F2.8 Di LD [IF] Macro (A001)', #JD
    '4 214' => 'smc PENTAX-DA 35mm F2.4 AL', #PH
    '4 229' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL II', #JD
    '4 230' => 'Tamron SP AF 17-50mm F2.8 XR Di II', #20
    '4 231' => 'smc PENTAX-DA 18-250mm F3.5-6.3 ED AL [IF]', #21
    '4 237' => 'Samsung/Schneider D-XENOGON 10-17mm F3.5-4.5', #JD
    '4 239' => 'Samsung/Schneider D-XENON 12-24mm F4 ED AL [IF]', #23
    '4 242' => 'smc PENTAX-DA* 16-50mm F2.8 ED AL [IF] SDM (SDM unused)', #Pietu Pohjalainen
    '4 243' => 'smc PENTAX-DA 70mm F2.4 Limited', #JD
    '4 244' => 'smc PENTAX-DA 21mm F3.2 AL Limited', #9
    '4 245' => 'Samsung/Schneider D-XENON 50-200mm F4-5.6', #15
    '4 246' => 'Samsung/Schneider D-XENON 18-55mm F3.5-5.6', #15
    '4 247' => 'smc PENTAX-DA FISH-EYE 10-17mm F3.5-4.5 ED[IF]', #10
    '4 248' => 'smc PENTAX-DA 12-24mm F4 ED AL [IF]', #10
    '4 249' => 'Tamron XR DiII 18-200mm F3.5-6.3 (A14)',
    '4 250' => 'smc PENTAX-DA 50-200mm F4-5.6 ED', #8
    '4 251' => 'smc PENTAX-DA 40mm F2.8 Limited', #9
    '4 252' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL', #8
    '4 253' => 'smc PENTAX-DA 14mm F2.8 ED[IF]',
    '4 254' => 'smc PENTAX-DA 16-45mm F4 ED AL',
    '5 1' => 'smc PENTAX-FA* 24mm F2 AL[IF]',
    '5 2' => 'smc PENTAX-FA 28mm F2.8 AL',
    '5 3' => 'smc PENTAX-FA 50mm F1.7',
    '5 4' => 'smc PENTAX-FA 50mm F1.4',
    '5 5' => 'smc PENTAX-FA* 600mm F4 ED[IF]',
    '5 6' => 'smc PENTAX-FA* 300mm F4.5 ED[IF]',
    '5 7' => 'smc PENTAX-FA 135mm F2.8 [IF]',
    '5 8' => 'smc PENTAX-FA Macro 50mm F2.8',
    '5 9' => 'smc PENTAX-FA Macro 100mm F2.8',
    '5 10' => 'smc PENTAX-FA* 85mm F1.4 [IF]',
    '5 11' => 'smc PENTAX-FA* 200mm F2.8 ED[IF]',
    '5 12' => 'smc PENTAX-FA 28-80mm F3.5-4.7',
    '5 13' => 'smc PENTAX-FA 70-200mm F4-5.6',
    '5 14' => 'smc PENTAX-FA* 250-600mm F5.6 ED[IF]',
    '5 15' => 'smc PENTAX-FA 28-105mm F4-5.6',
    '5 16' => 'smc PENTAX-FA 100-300mm F4.5-5.6',
    '5 98' => 'smc PENTAX-FA 100-300mm F4.5-5.6', #JD (pre-production? - PH)
    '6 1' => 'smc PENTAX-FA* 85mm F1.4 [IF]',
    '6 2' => 'smc PENTAX-FA* 200mm F2.8 ED[IF]',
    '6 3' => 'smc PENTAX-FA* 300mm F2.8 ED[IF]',
    '6 4' => 'smc PENTAX-FA* 28-70mm F2.8 AL',
    '6 5' => 'smc PENTAX-FA* 80-200mm F2.8 ED[IF]',
    '6 6' => 'smc PENTAX-FA* 28-70mm F2.8 AL',
    '6 7' => 'smc PENTAX-FA* 80-200mm F2.8 ED[IF]',
    '6 8' => 'smc PENTAX-FA 28-70mm F4AL',
    '6 9' => 'smc PENTAX-FA 20mm F2.8',
    '6 10' => 'smc PENTAX-FA* 400mm F5.6 ED[IF]',
    '6 13' => 'smc PENTAX-FA* 400mm F5.6 ED[IF]',
    '6 14' => 'smc PENTAX-FA* Macro 200mm F4 ED[IF]',
    '7 0' => 'smc PENTAX-DA 21mm F3.2 AL Limited', #13
    '7 58' => 'smc PENTAX-D FA Macro 100mm F2.8 WR', #PH - this bit of information cost me $600 ;)
    '7 75' => 'Tamron SP AF 70-200mm F2.8 Di LD [IF] Macro (A001)', #(Anton Bondar)
    '7 201' => 'smc Pentax-DA L 50-200mm F4-5.6 ED WR', #(Bruce Rusk)
    '7 202' => 'smc PENTAX-DA L 18-55mm F3.5-5.6 AL WR', #29
    '7 203' => 'HD PENTAX-DA 55-300mm F4-5.8 ED WR', #29
    '7 204' => 'HD PENTAX-DA 15mm F4 ED AL Limited', #forum5318
    '7 205' => 'HD PENTAX-DA 35mm F2.8 Macro Limited', #29
    '7 206' => 'HD PENTAX-DA 70mm F2.4 Limited', #29
    '7 207' => 'HD PENTAX-DA 21mm F3.2 ED AL Limited', #forum5327
    '7 208' => 'HD PENTAX-DA 40mm F2.8 Limited', #PH
    '7 212' => 'smc PENTAX-DA 50mm F1.8', #PH
    '7 213' => 'smc PENTAX-DA 40mm F2.8 XS', #PH
    '7 214' => 'smc PENTAX-DA 35mm F2.4 AL', #PH
    '7 216' => 'smc PENTAX-DA L 55-300mm F4-5.8 ED', #PH
    '7 217' => 'smc PENTAX-DA 50-200mm F4-5.6 ED WR', #JD
    '7 218' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL WR', #JD
    '7 220' => 'Tamron SP AF 10-24mm F3.5-4.5 Di II LD Aspherical [IF]', #24
    '7 221' => 'smc PENTAX-DA L 50-200mm F4-5.6 ED', #Ar't
    '7 222' => 'smc PENTAX-DA L 18-55mm F3.5-5.6', #PH (tag 0x003f -- was '7 229' in LensInfo of one test image)
    '7 223' => 'Samsung/Schneider D-XENON 18-55mm F3.5-5.6 II', #PH
    '7 224' => 'smc PENTAX-DA 15mm F4 ED AL Limited', #JD
    '7 225' => 'Samsung/Schneider D-XENON 18-250mm F3.5-6.3', #8/PH
    '7 226' => 'smc PENTAX-DA* 55mm F1.4 SDM (SDM unused)', #PH (NC)
    '7 227' => 'smc PENTAX-DA* 60-250mm F4 [IF] SDM (SDM unused)', #PH (NC)
    '7 228' => 'Samsung 16-45mm F4 ED', #29
    '7 229' => 'smc PENTAX-DA 18-55mm F3.5-5.6 AL II', #JD
    '7 230' => 'Tamron AF 17-50mm F2.8 XR Di-II LD (Model A16)', #JD
    '7 231' => 'smc PENTAX-DA 18-250mm F3.5-6.3 ED AL [IF]', #JD
    '7 233' => 'smc PENTAX-DA 35mm F2.8 Macro Limited', #JD
    '7 234' => 'smc PENTAX-DA* 300mm F4 ED [IF] SDM (SDM unused)', #19 (NC)
    '7 235' => 'smc PENTAX-DA* 200mm F2.8 ED [IF] SDM (SDM unused)', #PH (NC)
    '7 236' => 'smc PENTAX-DA 55-300mm F4-5.8 ED', #JD
    '7 238' => 'Tamron AF 18-250mm F3.5-6.3 Di II LD Aspherical [IF] Macro', #JD
    '7 241' => 'smc PENTAX-DA* 50-135mm F2.8 ED [IF] SDM (SDM unused)', #PH
    '7 242' => 'smc PENTAX-DA* 16-50mm F2.8 ED AL [IF] SDM (SDM unused)', #19
    '7 243' => 'smc PENTAX-DA 70mm F2.4 Limited', #PH
    '7 244' => 'smc PENTAX-DA 21mm F3.2 AL Limited', #16
    '8 0' => 'Sigma 50-150mm F2.8 II APO EX DC HSM', #forum2997
    '8 3' => 'Sigma AF 18-125mm F3.5-5.6 DC', #29
    '8 4' => 'Sigma 50mm F1.4 EX DG HSM', #Artur private communication
    '8 7' => 'Sigma 24-70mm F2.8 IF EX DG HSM', #Exiv2
    '8 8' => 'Sigma 18-250mm F3.5-6.3 DC OS HSM', #27
    '8 11' => 'Sigma 10-20mm F3.5 EX DC HSM', #27
    '8 12' => 'Sigma 70-300mm F4-5.6 DG OS', #forum3382
    '8 13' => 'Sigma 120-400mm F4.5-5.6 APO DG OS HSM', #26
    '8 14' => 'Sigma 17-70mm F2.8-4.0 DC Macro OS HSM', #(Hubert Meier)
    '8 15' => 'Sigma 150-500mm F5-6.3 APO DG OS HSM', #26
    '8 16' => 'Sigma 70-200mm F2.8 EX DG Macro HSM II', #26
    '8 17' => 'Sigma 50-500mm F4.5-6.3 DG OS HSM', #(Heike Herrmann) (also APO, ref 26)
    '8 18' => 'Sigma 8-16mm F4.5-5.6 DC HSM', #forum2998
    '8 21' => 'Sigma 17-50mm F2.8 EX DC OS HSM', #26
    '8 22' => 'Sigma 85mm F1.4 EX DG HSM', #26
    '8 23' => 'Sigma 70-200mm F2.8 APO EX DG OS HSM', #27
    '8 25' => 'Sigma 17-50mm F2.8 EX DC HSM', #Exiv2
    '8 27' => 'Sigma 18-200mm F3.5-6.3 II DC HSM', #27
    '8 28' => 'Sigma 18-250mm F3.5-6.3 DC Macro HSM', #27
    '8 29' => 'Sigma 35mm F1.4 DG HSM', #27
    '8 30' => 'Sigma 17-70mm F2.8-4 DC Macro HSM Contemporary', #27
    '8 31' => 'Sigma 18-35mm F1.8 DC HSM', #27
    '8 32' => 'Sigma 30mm F1.4 DC HSM | A', #27
    '8 59' => 'HD PENTAX-D FA 150-450mm F4.5-5.6 ED DC AW', #29
    '8 60' => 'HD PENTAX-D FA* 70-200mm F2.8 ED DC AW', #29
    '8 198' => 'smc PENTAX-DA L 18-50mm F4-5.6 DC WR RE', #29
    '8 199' => 'HD PENTAX-DA 18-50mm F4-5.6 DC WR RE', #29
    '8 200' => 'HD PENTAX-DA 16-85mm F3.5-5.6 ED DC WR', #29
    '8 209' => 'HD PENTAX-DA 20-40mm F2.8-4 ED Limited DC WR', #29
    '8 210' => 'smc PENTAX-DA 18-270mm F3.5-6.3 ED SDM', #Helmut Schutz
    '8 211' => 'HD PENTAX-DA 560mm F5.6 ED AW', #PH
    '8 215' => 'smc PENTAX-DA 18-135mm F3.5-5.6 ED AL [IF] DC WR', #PH
    '8 226' => 'smc PENTAX-DA* 55mm F1.4 SDM', #JD
    '8 227' => 'smc PENTAX-DA* 60-250mm F4 [IF] SDM', #JD
    '8 232' => 'smc PENTAX-DA 17-70mm F4 AL [IF] SDM', #JD
    '8 234' => 'smc PENTAX-DA* 300mm F4 ED [IF] SDM', #19
    '8 235' => 'smc PENTAX-DA* 200mm F2.8 ED [IF] SDM', #JD
    '8 241' => 'smc PENTAX-DA* 50-135mm F2.8 ED [IF] SDM', #JD
    '8 242' => 'smc PENTAX-DA* 16-50mm F2.8 ED AL [IF] SDM', #JD
    '8 255' => 'Sigma Lens (8 255)',
    '8 255.1' => 'Sigma 70-200mm F2.8 EX DG Macro HSM II', #JD
    '8 255.2' => 'Sigma 150-500mm F5-6.3 DG APO [OS] HSM', #JD (non-OS version has same type, ref 29)
    '8 255.3' => 'Sigma 50-150mm F2.8 II APO EX DC HSM', #forum2997
    '8 255.4' => 'Sigma 4.5mm F2.8 EX DC HSM Circular Fisheye', #PH
    '8 255.5' => 'Sigma 50-200mm F4-5.6 DC OS', #26
    '8 255.6' => 'Sigma 24-70mm F2.8 EX DG HSM', #29
#
# 645 lenses
#
    '9 0' => '645 Manual Lens', #PH (NC)
    '10 0' => '645 A Series Lens', #PH
    '11 1' => 'smc PENTAX-FA 645 75mm F2.8', #PH
    '11 2' => 'smc PENTAX-FA 645 45mm F2.8', #PH
    '11 3' => 'smc PENTAX-FA* 645 300mm F4 ED [IF]', #PH
    '11 4' => 'smc PENTAX-FA 645 45-85mm F4.5', #PH
    '11 5' => 'smc PENTAX-FA 645 400mm F5.6 ED [IF]', #PH
    '11 7' => 'smc PENTAX-FA 645 Macro 120mm F4', #PH
    '11 8' => 'smc PENTAX-FA 645 80-160mm F4.5', #PH
    '11 9' => 'smc PENTAX-FA 645 200mm F4 [IF]', #PH
    '11 10' => 'smc PENTAX-FA 645 150mm F2.8 [IF]', #PH
    '11 11' => 'smc PENTAX-FA 645 35mm F3.5 AL [IF]', #PH
    '11 12' => 'smc PENTAX-FA 645 300mm F5.6 ED [IF]', #29
    '11 14' => 'smc PENTAX-FA 645 55-110mm F5.6', #PH
    '11 16' => 'smc PENTAX-FA 645 33-55mm F4.5 AL', #PH
    '11 17' => 'smc PENTAX-FA 645 150-300mm F5.6 ED [IF]', #PH
    '13 18' => 'smc PENTAX-D FA 645 55mm F2.8 AL [IF] SDM AW', #PH
    '13 19' => 'smc PENTAX-D FA 645 25mm F4 AL [IF] SDM AW', #PH
    '13 20' => 'HD PENTAX-D FA 645 90mm F2.8 ED AW SR', #PH
    '13 253' => 'HD PENTAX-DA 645 28-45mm F4.5 ED AW SR', #Dominique Schrekling email
    # missing:
    # 'smc PENTAX-DA 645 25mm F4.0 AL SDM AW [IF]' ? different than D FA version?
#
# Q-mount lenses (21=auto focus lens, 22=manual focus)
#
    '21 0' => 'Pentax Q Manual Lens', #PH
    '21 1' => '01 Standard Prime 8.5mm F1.9', #PH
    '21 2' => '02 Standard Zoom 5-15mm F2.8-4.5', #PH
    '22 3' => '03 Fish-eye 3.2mm F5.6', #PH
    '22 4' => '04 Toy Lens Wide 6.3mm F7.1', #PH
    '22 5' => '05 Toy Lens Telephoto 18mm F8', #PH
    '21 6' => '06 Telephoto Zoom 15-45mm F2.8', #PH
    '21 7' => '07 Mount Shield 11.5mm F9', #PH (NC)
    '21 8' => '08 Wide Zoom 3.8-5.9mm F3.7-4', #PH (NC)
);

# Pentax model ID codes - PH
my %pentaxModelID = (
    0x0000d => 'Optio 330/430',
    0x12926 => 'Optio 230',
    0x12958 => 'Optio 330GS',
    0x12962 => 'Optio 450/550',
    0x1296c => 'Optio S',
    0x12971 => 'Optio S V1.01',
    0x12994 => '*ist D',
    0x129b2 => 'Optio 33L',
    0x129bc => 'Optio 33LF',
    0x129c6 => 'Optio 33WR/43WR/555',
    0x129d5 => 'Optio S4',
    0x12a02 => 'Optio MX',
    0x12a0c => 'Optio S40',
    0x12a16 => 'Optio S4i',
    0x12a34 => 'Optio 30',
    0x12a52 => 'Optio S30',
    0x12a66 => 'Optio 750Z',
    0x12a70 => 'Optio SV',
    0x12a75 => 'Optio SVi',
    0x12a7a => 'Optio X',
    0x12a8e => 'Optio S5i',
    0x12a98 => 'Optio S50',
    0x12aa2 => '*ist DS',
    0x12ab6 => 'Optio MX4',
    0x12ac0 => 'Optio S5n',
    0x12aca => 'Optio WP',
    0x12afc => 'Optio S55',
    0x12b10 => 'Optio S5z',
    0x12b1a => '*ist DL',
    0x12b24 => 'Optio S60',
    0x12b2e => 'Optio S45',
    0x12b38 => 'Optio S6',
    0x12b4c => 'Optio WPi', #13
    0x12b56 => 'BenQ DC X600',
    0x12b60 => '*ist DS2',
    0x12b62 => 'Samsung GX-1S',
    0x12b6a => 'Optio A10',
    0x12b7e => '*ist DL2',
    0x12b80 => 'Samsung GX-1L',
    0x12b9c => 'K100D',
    0x12b9d => 'K110D',
    0x12ba2 => 'K100D Super', #JD
    0x12bb0 => 'Optio T10/T20',
    0x12be2 => 'Optio W10',
    0x12bf6 => 'Optio M10',
    0x12c1e => 'K10D',
    0x12c20 => 'Samsung GX10',
    0x12c28 => 'Optio S7',
    0x12c2d => 'Optio L20',
    0x12c32 => 'Optio M20',
    0x12c3c => 'Optio W20',
    0x12c46 => 'Optio A20',
    0x12c78 => 'Optio E30',
    0x12c7d => 'Optio E35',
    0x12c82 => 'Optio T30',
    0x12c8c => 'Optio M30',
    0x12c91 => 'Optio L30',
    0x12c96 => 'Optio W30',
    0x12ca0 => 'Optio A30',
    0x12cb4 => 'Optio E40',
    0x12cbe => 'Optio M40',
    0x12cc3 => 'Optio L40',
    0x12cc5 => 'Optio L36',
    0x12cc8 => 'Optio Z10',
    0x12cd2 => 'K20D',
    0x12cd4 => 'Samsung GX20', #8
    0x12cdc => 'Optio S10',
    0x12ce6 => 'Optio A40',
    0x12cf0 => 'Optio V10',
    0x12cfa => 'K200D',
    0x12d04 => 'Optio S12',
    0x12d0e => 'Optio E50',
    0x12d18 => 'Optio M50',
    0x12d22 => 'Optio L50',
    0x12d2c => 'Optio V20',
    0x12d40 => 'Optio W60',
    0x12d4a => 'Optio M60',
    0x12d68 => 'Optio E60/M90',
    0x12d72 => 'K2000',
    0x12d73 => 'K-m',
    0x12d86 => 'Optio P70',
    0x12d90 => 'Optio L70',
    0x12d9a => 'Optio E70',
    0x12dae => 'X70',
    0x12db8 => 'K-7',
    0x12dcc => 'Optio W80',
    0x12dea => 'Optio P80',
    0x12df4 => 'Optio WS80',
    0x12dfe => 'K-x',
    0x12e08 => '645D',
    0x12e12 => 'Optio E80',
    0x12e30 => 'Optio W90',
    0x12e3a => 'Optio I-10',
    0x12e44 => 'Optio H90',
    0x12e4e => 'Optio E90',
    0x12e58 => 'X90',
    0x12e6c => 'K-r',
    0x12e76 => 'K-5',
    0x12e8a => 'Optio RS1000/RS1500',
    0x12e94 => 'Optio RZ10',
    0x12e9e => 'Optio LS1000',
    0x12ebc => 'Optio WG-1 GPS',
    0x12ed0 => 'Optio S1',
    0x12ee4 => 'Q',
    0x12ef8 => 'K-01',
    0x12f0c => 'Optio RZ18',
    0x12f16 => 'Optio VS20',
    0x12f2a => 'Optio WG-2 GPS',
    0x12f48 => 'Optio LS465',
    0x12f52 => 'K-30',
    0x12f5c => 'X-5',
    0x12f66 => 'Q10',
    0x12f70 => 'K-5 II',
    0x12f71 => 'K-5 II s', #forum4515
    0x12f7a => 'Q7',
    0x12f84 => 'MX-1',
    0x12f8e => 'WG-3 GPS',
    0x12f98 => 'WG-3',
    0x12fa2 => 'WG-10',
    0x12fb6 => 'K-50',
    0x12fc0 => 'K-3', #29
    0x12fca => 'K-500',
    0x12fe8 => 'WG-4', # (Ricoh)
    0x12fde => 'WG-4 GPS', # (Ricoh)
    0x13006 => 'WG-20', # (Ricoh)
    0x13010 => '645Z',
    0x1301a => 'K-S1',
    0x13024 => 'K-S2', #29 (Ricoh)
    0x1302e => 'Q-S1',
    0x13056 => 'WG-30', # (Ricoh)
);

# Pentax city codes - (PH, Optio WP)
my %pentaxCities = (
    0 => 'Pago Pago',
    1 => 'Honolulu',
    2 => 'Anchorage',
    3 => 'Vancouver',
    4 => 'San Francisco',
    5 => 'Los Angeles',
    6 => 'Calgary',
    7 => 'Denver',
    8 => 'Mexico City',
    9 => 'Chicago',
    10 => 'Miami',
    11 => 'Toronto',
    12 => 'New York',
    13 => 'Santiago',
    14 => 'Caracus',
    15 => 'Halifax',
    16 => 'Buenos Aires',
    17 => 'Sao Paulo',
    18 => 'Rio de Janeiro',
    19 => 'Madrid',
    20 => 'London',
    21 => 'Paris',
    22 => 'Milan',
    23 => 'Rome',
    24 => 'Berlin',
    25 => 'Johannesburg',
    26 => 'Istanbul',
    27 => 'Cairo',
    28 => 'Jerusalem',
    29 => 'Moscow',
    30 => 'Jeddah',
    31 => 'Tehran',
    32 => 'Dubai',
    33 => 'Karachi',
    34 => 'Kabul',
    35 => 'Male',
    36 => 'Delhi',
    37 => 'Colombo',
    38 => 'Kathmandu',
    39 => 'Dacca',
    40 => 'Yangon',
    41 => 'Bangkok',
    42 => 'Kuala Lumpur',
    43 => 'Vientiane',
    44 => 'Singapore',
    45 => 'Phnom Penh',
    46 => 'Ho Chi Minh',
    47 => 'Jakarta',
    48 => 'Hong Kong',
    49 => 'Perth',
    50 => 'Beijing',
    51 => 'Shanghai',
    52 => 'Manila',
    53 => 'Taipei',
    54 => 'Seoul',
    55 => 'Adelaide',
    56 => 'Tokyo',
    57 => 'Guam',
    58 => 'Sydney',
    59 => 'Noumea',
    60 => 'Wellington',
    61 => 'Auckland',
    62 => 'Lima',
    63 => 'Dakar',
    64 => 'Algiers',
    65 => 'Helsinki',
    66 => 'Athens',
    67 => 'Nairobi',
    68 => 'Amsterdam',
    69 => 'Stockholm',
    70 => 'Lisbon', #14
    71 => 'Copenhagen', #25
    72 => 'Warsaw',
    73 => 'Prague',
    74 => 'Budapest',
);

# digital filter tag information (ref PH, K-5)
# (also see %filterSettings below for decoding of filter parameters)
my %digitalFilter = (
    Format => 'undef[17]',
    RawConv => '($val!~/^\\0/ or $$self{OPTIONS}{Unknown}) ? join(" ",unpack("Cc*",$val)) : undef',
    SeparateTable => 'DigitalFilter',
    ValueConvInv => q{
        return "\0" x 17 if $val eq "0";
        $val = pack("Cc*", $val=~/[-+]?\d+/g);
        length($val)==17 or warn("Expecting 17 values\n"), return undef;
        return $val;
    },
    PrintConv => {
        OTHER => \&PrintFilter, # this routine actually converts all values
        0 => 'Off',
        1 => 'Base Parameter Adjust',
        2 => 'Soft Focus',
        3 => 'High Contrast',
        4 => 'Color Filter',
        5 => 'Extract Color',
        6 => 'Monochrome',
        7 => 'Slim',
        9 => 'Fisheye',
        10 => 'Toy Camera',
        11 => 'Retro',
        12 => 'Pastel',
        13 => 'Water Color',
        14 => 'HDR',
        16 => 'Miniature',
        17 => 'Starburst',
        18 => 'Posterization',
        19 => 'Sketch Filter',
        20 => 'Shading', # (Q)
        21 => 'Invert Color', # (Q)
        23 => 'Tone Expansion', #Forum5247
        254 => 'Custom Filter',
    },
);

# digital filter setting names and conversions (ref PH, K-5)
# Note: names must be unique for writing
my %filterSettings = (
    1  => ['Brightness', '%+d'],    # BPA (-8-+8)
    2  => ['Saturation', '%+d'],    # BPA (-3-+3)
    3  => ['Hue', '%+d'],           # BPA (-3-+3)
    4  => ['Contrast', '%+d'],      # BPA (-3-+3)
    5  => ['Sharpness', '%+d'],     # BPA (-3-+3)
    6  => ['SoftFocus', '%d'],      # Soft Focus/Custom (1-3)
    7  => ['ShadowBlur',    { 0=>'Off',1=>'On' }], # Soft Focus
    8  => ['HighContrast', '%d'],   # High Contrast/Custom (1-5)
    9  => ['Color',         { 1=>'Red',2=>'Magenta',3=>'Blue',4=>'Cyan',5=>'Green',6=>'Yellow' }], # Color Filter
    10 => ['Density',       { 1=>'Light',2=>'Standard',3=>'Dark' }], # Color Filter
    11 => ['ExtractedColor',{ 0=>'Off',1=>'Red',2=>'Magenta',3=>'Blue',4=>'Cyan',5=>'Green',6=>'Yellow' }], # ExtractColor [x2]
    12 => ['ColorRange', '%+d'],    # ExtractColor [x2] (-2-+2)
    13 => ['FilterEffect',  { 0=>'Off',1=>'Red',2=>'Green',3=>'Blue',4=>'Infrared'}], # Monochrome
    14 => ['ToningBA', '%+d'],      # Monochrome (-3-+3)
    15 => ['InvertColor',   { 0=>'Off',1=>'On' }], # Custom/Invert Color
    16 => ['Slim', '%+d'],          # Slim (-8-+8)
    17 => ['EffectDensity', { 1=>'Sparse',2=>'Normal',3=>'Dense' }], # Starburst
    18 => ['Size',          { 1=>'Small',2=>'Medium',3=>'Large' }], # Starburst
    19 => ['Angle',         { 0=>'0deg',2=>'30deg',3=>'45deg',4=>'60deg'}], # Starburst (1 is unused)
    20 => ['Fisheye',       { 1=>'Weak',2=>'Medium',3=>'Strong' }], # Fisheye
    21 => ['DistortionType', '%d'], # Custom (1-3)
    22 => ['DistortionLevel',{0=>'Off',1=>'Weak',2=>'Medium',3=>'Strong' }], #Custom
    23 => ['ShadingType', '%d'],    # Custom/Shading (1-6)
    24 => ['ShadingLevel', '%+d'],  # Custom/Shading (-3-+3)
    25 => ['Shading', '%d'],        # Toy Camera (1-3)
    26 => ['Blur',  '%d'],          # Toy Camera (1-3)
    27 => ['ToneBreak',     { 0=>'Off',1=>'Red',2=>'Green',3=>'Blue',4=>'Yellow'}], # Toy Camera/Custom
    28 => ['Toning', '%+d'],        # Retro (-3-+3)
    29 => ['FrameComposite',{ 0=>'None',1=>'Thin',2=>'Medium',3=>'Thick' }], # Retro
    30 => ['PastelStrength',{ 1=>'Weak',2=>'Medium',3=>'Strong' }], # Pastel
    31 => ['Intensity', '%d'],      # Water Color (1-3)
    32 => ['Saturation2',   { 0=>'Off',1=>'Low',2=>'Medium',3=>'High' }], # Water Color
    33 => ['HDR',           { 1=>'Weak',2=>'Medium',3=>'Strong' }], # HDR
    # (34 missing)
    35 => ['FocusPlane', '%+d'],    # Miniature (-3-+3)
    36 => ['FocusWidth',    { 1=>'Narrow',2=>'Middle',3=>'Wide' }], # Miniature
    37 => ['PlaneAngle',    { 0=>'Horizontal',1=>'Vertical',2=>'Positive slope',3=>'Negative slope' }], # Miniature
    38 => ['Blur2', '%d'],          # Miniature (1-3)
    39 => ['Shape',         { 1=>'Cross',2=>'Star',3=>'Snowflake',4=>'Heart',5=>'Note'}], # Starburst
    40 => ['Posterization', '%d'],  # Posterization (1-5)
    41 => ['Contrast2',     { 1=>'Low',2=>'Medium',3=>'High'}], # Sketch Filter
    42 => ['ScratchEffect', { 0=>'Off',1=>'On' }], # Sketch Filter
    45 => ['ToneExpansion', { 1=>'Low',2=>'Medium',3=>'High' }], # Tone Expansion (ref Forum5247)
);

# decoding for Pentax Firmware ID tags - PH
my %pentaxFirmwareID = (
    # the first 2 numbers are the firmware version, I'm not sure what the second 2 mean
    # Note: the byte order may be different for some models
    # which give, for example, version 0.01 instead of 1.00
    ValueConv => sub {
        my $val = shift;
        return $val unless length($val) == 4;
        # (value is encrypted by toggling all bits)
        my @a = map { $_ ^ 0xff } unpack("C*",$val);
        return sprintf('%d %.2d %.2d %.2d', @a);
    },
    ValueConvInv => sub {
        my $val = shift;
        my @a = $val=~/\b\d+\b/g;
        return $val unless @a == 4;
        @a = map { ($_ & 0xff) ^ 0xff } @a;
        return pack("C*", @a);
    },
    PrintConv => '$val=~tr/ /./; $val',
    PrintConvInv => '$val=~s/^(\d+)\.(\d+)\.(\d+)\.(\d+)/$1 $2 $3 $4/ ? $val : undef',
);

# convert 16 or 77 metering segment values to approximate LV equivalent - PH
my %convertMeteringSegments = (
    PrintConv    => sub { join ' ', map(
        { $_==255 ? 'n/a' : $_==0 ? '0' : sprintf '%.1f', $_ / 8 - 6 } split(' ',$_[0])
    ) },
    PrintConvInv => sub { join ' ', map(
        { /^n/i ? 255 : $_==0 ? '0' : int(($_ + 6) * 8 + 0.5) }        split(' ',$_[0])
    ) },
);

# lens code conversions
my %lensCode = (
    Unknown => 1,
    PrintConv => 'sprintf("0x%.2x", $val)',
    PrintConvInv => 'hex($val)',
);

# conversions for tags 0x0053-0x005a
my %colorTemp = (
    Writable => 'undef',
    Count => 4,
    ValueConv => sub {
        my $val = shift;
        return $val unless length $val == 4;
        my @a = unpack 'nCC', $val;
        $a[0] = 53190 - $a[0];
        $a[1] = ($a[2] & 0x0f); $a[1] -= 16 if $a[1] >= 8;
        $a[2] = ($a[2] >> 4);   $a[2] -= 16 if $a[2] >= 8;
        return "@a";
    },
    ValueConvInv => sub {
        my $val = shift;
        my @a = split ' ', $val;
        return undef unless @a == 3;
        return pack 'nCC', 53190 - $a[0], 0, ($a[1] & 0x0f) + (($a[2] & 0x0f) << 4);
    },
    PrintConv => sub {
        $_ = shift;
        s/ ([1-9])/ +$1/g;
        s/ 0/  0/g;
        return $_;
    },
    PrintConvInv => '$val',
);

# conversions for KelvinWB tags
my %kelvinWB = (
    Format => 'int16u[4]',
    ValueConv => sub {
        my @a = split ' ', shift;
        (53190 - $a[0]) . ' ' . $a[1] . ' ' . ($a[2] / 8192) . ' ' . ($a[3] / 8192);
    },
    ValueConvInv => sub {
        my @a = split ' ', shift;
        (53190 - $a[0]) . ' ' . $a[1] . ' ' . int($a[2]*8192+0.5) . ' ' . int($a[3]*8192+0.5);
    },
);

# common attributes for writable BinaryData directories
my %binaryDataAttrs = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    FIRST_ENTRY => 0,
);

# Pentax makernote tags
%Image::ExifTool::Pentax::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    0x0000 => { #5
        Name => 'PentaxVersion',
        Writable => 'int8u',
        Count => 4,
        PrintConv => '$val=~tr/ /./; $val',
        PrintConvInv => '$val=~tr/./ /; $val',
        # 0.1.0.3 - PENTAX Optio E40
        # 3.0.0.0 - K10D
        # 3.1.0.0 - Optio A40/S10/L36/L40/M40/V10
        # 3.1.2.0 - Optio Z10
        # 4.0.2.0 - Optio E50
        # 4.1.0.0 - Optio S12
        # 4.1.1.0 - Optio M50
        # 4.1.2.0 - K20D, K200D
        # 4.2.0.0 - Optio L50/V20
        # 4.2.1.0 - Optio E60/M90
        # 4.2.2.0 - Optio W60
        # 4.2.3.0 - Optio M60
        # 4.4.0.1 - K-m, K2000
        # 4.5.0.0 - Optio E70/L70
        # 4.5.0.0 - Optio P70
        # 4.6.0.0 - Optio E80/E90/W80
        # 5.0.0.0 - K-7, Optio P80/WS80
        # 5.1.0.0 - K-x
        # 5.2.0.0 - Optio I-10
        # 5.3.0.0 - Optio H90
        # 5.3.2.0 - Optio W90
        # 6.0.0.0 - K-r, 645D
        # 6.1.3.0 - Optio LS1000/RS1000/RS1500/RZ10
        # 7.0.0.0 - K-5
        # 7.1.0.0 - Optio WG-1GPS/WG-10
        # 7.2.0.0 - Optio S1
        # 8.0.0.0 - Q
        # 8.0.1.0 - Optio RZ18
        # 8.0.4.0 - Optio VS20
        # 8.1.0.0 - Optio LS465/WG-2GPS
        # 9.0.0.0 - K-01
        # 9.1.2.0 - X-5
        # 10.0.0.0 - K-30, K-50, K-500, K-5 II
        # 11.0.0.0 - K-3
    },
    0x0001 => { #PH
        Name => 'PentaxModelType',
        Writable => 'int16u',
        # (values of 0-5 seem to group models into 6 categories, ref 13)
    },
    0x0002 => { #PH
        Name => 'PreviewImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$val =~ tr/ /x/; $val',
        PrintConvInv => '$val =~ tr/x/ /; $val',
    },
    0x0003 => { #PH
        Name => 'PreviewImageLength',
        OffsetPair => 0x0004, # point to associated offset
        DataTag => 'PreviewImage',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
        Protected => 2,
    },
    0x0004 => { #PH
        Name => 'PreviewImageStart',
        IsOffset => 2,  # code to use original base
        Protected => 2,
        OffsetPair => 0x0003, # point to associated byte count
        DataTag => 'PreviewImage',
        Groups => { 2 => 'Image' },
        Writable => 'int32u',
    },
    0x0005 => { #13
        Name => 'PentaxModelID',
        Writable => 'int32u',
        PrintHex => 1,
        SeparateTable => 1,
        DataMember => 'PentaxModelID',
        RawConv => '$$self{PentaxModelID} = $val',
        PrintConv => \%pentaxModelID,
    },
    0x0006 => { #5
        # Note: Year is int16u in MM byte ordering regardless of EXIF byte order
        Name => 'Date',
        Groups => { 2 => 'Time' },
        Notes => 'changing either Date or Time will affect ShutterCount decryption',
        Writable => 'undef',
        Count => 4,
        Shift => 'Time',
        DataMember => 'PentaxDate',
        RawConv => '$$self{PentaxDate} = $val', # save to decrypt ShutterCount
        ValueConv => 'length($val)==4 ? sprintf("%.4d:%.2d:%.2d",unpack("nC2",$val)) : "Unknown ($val)"',
        ValueConvInv => q{
            $val =~ s/(\d) .*/$1/;          # remove Time
            my @v = split /:/, $val;
            return pack("nC2",$v[0],$v[1],$v[2]);
        },
    },
    0x0007 => { #5
        Name => 'Time',
        Groups => { 2 => 'Time' },
        Writable => 'undef',
        Count => 3,
        Shift => 'Time',
        DataMember => 'PentaxTime',
        RawConv => '$$self{PentaxTime} = $val', # save to decrypt ShutterCount
        ValueConv => 'length($val)>=3 ? sprintf("%.2d:%.2d:%.2d",unpack("C3",$val)) : "Unknown ($val)"',
        ValueConvInv => q{
            $val =~ s/^[0-9:]+ (\d)/$1/;    # remove Date
            return pack("C3",split(/:/,$val));
        },
    },
    0x0008 => { #2
        Name => 'Quality',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Good',
            1 => 'Better',
            2 => 'Best',
            3 => 'TIFF', #5
            4 => 'RAW', #5
            5 => 'Premium', #PH (K20D)
            65535 => 'n/a', #PH (Q MOV video)
        },
    },
    0x0009 => { #3
        Name => 'PentaxImageSize',
        Groups => { 2 => 'Image' },
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '640x480',
            1 => 'Full', #PH - this can mean 2048x1536 or 2240x1680 or ... ?
            2 => '1024x768',
            3 => '1280x960', #PH (Optio WP)
            4 => '1600x1200',
            5 => '2048x1536',
            8 => '2560x1920 or 2304x1728', #PH (Optio WP) or #14
            9 => '3072x2304', #PH (Optio M30)
            10 => '3264x2448', #13
            19 => '320x240', #PH (Optio WP)
            20 => '2288x1712', #13
            21 => '2592x1944',
            22 => '2304x1728 or 2592x1944', #2 or #14
            23 => '3056x2296', #13
            25 => '2816x2212 or 2816x2112', #13 or #14
            27 => '3648x2736', #PH (Optio A20)
            29 => '4000x3000', #PH (X70)
            30 => '4288x3216', #PH (Optio RS1000)
            31 => '4608x3456', #PH (Optio RZ18)
            129 => '1920x1080', #PH (Optio RZ10)
            135 => '4608x2592', #PH (Q10 stretch filter)
            257 => '3216x3216', #PH (Optio RZ10)
            '0 0' => '2304x1728', #13
            '4 0' => '1600x1200', #PH (Optio MX4)
            '5 0' => '2048x1536', #13
            '8 0' => '2560x1920', #13
            '32 2' => '960x640', #7
            '33 2' => '1152x768', #7
            '34 2' => '1536x1024', #7
            '35 1' => '2400x1600', #7
            '36 0' => '3008x2008 or 3040x2024',  #PH
            '37 0' => '3008x2000', #13
            # 65535 - seen for an X-5 panorama (PH)
        },
    },
    0x000b => { #3
        Name => 'PictureMode',
        Writable => 'int16u',
        Count => -1,
        Notes => q{
            1 or 2 values.  Decimal values differentiate Optio 555 modes which are
            different from other models
        },
        ValueConv => '(IsInt($val) and $val < 4 and $$self{Model} =~ /Optio 555\b/) ? $val + 0.1 : $val',
        ValueConvInv => 'int $val',
        PrintConvColumns => 2,
        PrintConv => [{
            0 => 'Program', #PH
            0.1 => 'Av', #PH (Optio 555)
            1 => 'Shutter Speed Priority', #JD
            1.1 => 'M', #PH (Optio 555)
            2 => 'Program AE', #13
            2.1 => 'Tv', #PH (Optio 555)
            3 => 'Manual', #13
            3.1 => 'USER', #PH (Optio 555)
            5 => 'Portrait',
            6 => 'Landscape',
            8 => 'Sport', #PH
            9 => 'Night Scene',
            # 10 "full mode"? #13
            11 => 'Soft', #PH
            12 => 'Surf & Snow',
            13 => 'Candlelight', #13
            14 => 'Autumn',
            15 => 'Macro',
            17 => 'Fireworks',
            18 => 'Text',
            19 => 'Panorama', #PH
            20 => '3-D', #PH (Optio 555)
            21 => 'Black & White', #PH (Optio 555)
            22 => 'Sepia', #PH (Optio 555)
            23 => 'Red', #PH (Optio 555)
            24 => 'Pink', #PH (Optio 555)
            25 => 'Purple', #PH (Optio 555)
            26 => 'Blue', #PH (Optio 555)
            27 => 'Green', #PH (Optio 555)
            28 => 'Yellow', #PH (Optio 555)
            30 => 'Self Portrait', #PH
            31 => 'Illustrations', #13
            33 => 'Digital Filter', #13
            35 => 'Night Scene Portrait', #25
            37 => 'Museum', #PH
            38 => 'Food', #PH
            39 => 'Underwater', #25
            40 => 'Green Mode', #PH
            49 => 'Light Pet', #PH
            50 => 'Dark Pet', #PH
            51 => 'Medium Pet', #PH
            53 => 'Underwater', #PH
            54 => 'Candlelight', #PH
            55 => 'Natural Skin Tone', #PH
            56 => 'Synchro Sound Record', #PH
            58 => 'Frame Composite', #14
            59 => 'Report', #25
            60 => 'Kids', #13
            61 => 'Blur Reduction', #13
            63 => 'Panorama 2', #PH (X-5)
            65 => 'Half-length Portrait', #JD
            66 => 'Portrait 2', #PH (LS645)
            74 => 'Digital Microscope', #PH (WG-4)
            75 => 'Blue Sky', #PH (LS465)
            80 => 'Miniature', #PH (VS20)
            81 => 'HDR', #PH (LS465)
            83 => 'Fisheye', #PH (VS20)
            221 => 'P', #PH (Optio 555)
            255=> 'PICT', #PH (Optio 555)
        }],
    },
    0x000c => { #PH
        Name => 'FlashMode',
        Writable => 'int16u',
        Count => -1,
        PrintHex => 1,
        PrintConv => [{
            0x000 => 'Auto, Did not fire',
            0x001 => 'Off, Did not fire',
            0x002 => 'On, Did not fire', #19
            0x003 => 'Auto, Did not fire, Red-eye reduction',
            0x005 => 'On, Did not fire, Wireless (Master)', #19
            0x100 => 'Auto, Fired',
            0x102 => 'On, Fired',
            0x103 => 'Auto, Fired, Red-eye reduction',
            0x104 => 'On, Red-eye reduction',
            0x105 => 'On, Wireless (Master)', #19
            0x106 => 'On, Wireless (Control)', #19
            0x108 => 'On, Soft',
            0x109 => 'On, Slow-sync',
            0x10a => 'On, Slow-sync, Red-eye reduction',
            0x10b => 'On, Trailing-curtain Sync',
        },{ #19 (AF-540FGZ flash)
            0x000 => 'n/a - Off-Auto-Aperture', #19
            0x03f => 'Internal',
            0x100 => 'External, Auto',
            0x23f => 'External, Flash Problem', #JD
            0x300 => 'External, Manual',
            0x304 => 'External, P-TTL Auto',
            0x305 => 'External, Contrast-control Sync', #JD
            0x306 => 'External, High-speed Sync',
            0x30c => 'External, Wireless',
            0x30d => 'External, Wireless, High-speed Sync',
        }],
    },
    0x000d => [ #2
        {
            Name => 'FocusMode',
            # (can't test for "PENTAX" because MOV videos don't have Make)
            Condition => '$$self{Make} !~ /^Asahi/',
            Notes => 'Pentax models',
            Writable => 'int16u',
            PrintConvColumns => 2,
            PrintConv => { #PH
                0 => 'Normal',
                1 => 'Macro',
                2 => 'Infinity',
                3 => 'Manual',
                4 => 'Super Macro', #JD
                5 => 'Pan Focus',
                16 => 'AF-S (Focus-priority)', #17
                17 => 'AF-C (Focus-priority)', #17
                18 => 'AF-A (Focus-priority)', #PH (educated guess)
                32 => 'Contrast-detect (Focus-priority)', #PH (K-5)
                33 => 'Tracking Contrast-detect (Focus-priority)', #PH (K-5)
                # bit 8 indicates release priority
                272 => 'AF-S (Release-priority)', #PH (K-5,K-3)
                273 => 'AF-C (Release-priority)', #PH (K-5,K-3)
                274 => 'AF-A (Release-priority)', #PH (K-3)
                288 => 'Contrast-detect (Release-priority)', #PH (K-01)
            },
        },{
            Name => 'FocusMode',
            Writable => 'int16u',
            Notes => 'Asahi models',
            PrintConv => { #2
                0 => 'Normal',
                1 => 'Macro (1)',
                2 => 'Macro (2)',
                3 => 'Infinity',
            },
        },
    ],
    0x000e => [{ #7
        Name => 'AFPointSelected',
        Condition => '$$self{Model} !~ /K-3\b/',
        Writable => 'int16u',
        Notes => 'all models but the K-3',
        PrintConvColumns => 2,
        PrintConv => [{
            # 0 - Contrast-detect AF? - PH (K-5)
            0xffff => 'Auto',
            0xfffe => 'Fixed Center',
            0xfffd => 'Automatic Tracking AF', #JD
            0xfffc => 'Face Detect AF', #JD
            0xfffb => 'AF Select', #PH (Q select from 25-areas)
            0 => 'None', #PH (Q in manual focus mode)
            1 => 'Upper-left',
            2 => 'Top',
            3 => 'Upper-right',
            4 => 'Left',
            5 => 'Mid-left',
            6 => 'Center',
            7 => 'Mid-right',
            8 => 'Right',
            9 => 'Lower-left',
            10 => 'Bottom',
            11 => 'Lower-right',
        },
        # (second number exists for K-5II(s) is usually 0, but is 1 for AF.C with
        # AFPointMode=='Select' and extended tracking focus points are enabled in the settings)
        ],
    },{
        Name => 'AFPointSelected',
        Writable => 'int16u',
        Notes => 'K-3',
        PrintConvColumns => 2,
        PrintConv => [{
            # 0 - Contrast-detect AF? - PH (K-5)
            0xffff => 'Auto',
            0xfffe => 'Fixed Center',
            0xfffd => 'Automatic Tracking AF', #JD
            0xfffc => 'Face Detect AF', #JD
            0xfffb => 'AF Select', #PH (Q select from 25-areas)
            # AF pattern: (ref forum5422)
            #    01 02 03 04 05
            #    06 07 08 09 10
            # 11 12 13 14 15 16 17
            #    18 19 20 21 22
            #    23 24 25 26 27
            0 => 'None',
            1 => 'Top-left',
            2 => 'Top Near-left',
            3 => 'Top',
            4 => 'Top Near-right',
            5 => 'Top-right',
            6 => 'Upper-left',
            7 => 'Upper Near-left',
            8 => 'Upper-middle',
            9 => 'Upper Near-right',
            10 => 'Upper-right',
            11 => 'Far Left',
            12 => 'Left',
            13 => 'Near-left',
            14 => 'Center',
            15 => 'Near-right',
            16 => 'Right',
            17 => 'Far Right',
            18 => 'Lower-left',
            19 => 'Lower Near-left',
            20 => 'Lower-middle',
            21 => 'Lower Near-right',
            22 => 'Lower-right',
            23 => 'Bottom-left',
            24 => 'Bottom Near-left',
            25 => 'Bottom',
            26 => 'Bottom Near-right',
            27 => 'Bottom-right',
            #forum5892
            257 => 'Zone Select Top-left',
            258 => 'Zone Select Top Near-left',
            259 => 'Zone Select Top',
            260 => 'Zone Select Top Near-right',
            261 => 'Zone Select Top-right',
            262 => 'Zone Select Upper-left',
            263 => 'Zone Select Upper Near-left',
            264 => 'Zone Select Upper-middle',
            265 => 'Zone Select Upper Near-right',
            266 => 'Zone Select Upper-right',
            267 => 'Zone Select Far Left',
            268 => 'Zone Select Left',
            269 => 'Zone Select Near-left',
            270 => 'Zone Select Center',
            271 => 'Zone Select Near-right',
            272 => 'Zone Select Right',
            273 => 'Zone Select Far Right',
            274 => 'Zone Select Lower-left',
            275 => 'Zone Select Lower Near-left',
            276 => 'Zone Select Lower-middle',
            277 => 'Zone Select Lower Near-right',
            278 => 'Zone Select Lower-right',
            279 => 'Zone Select Bottom-left',
            280 => 'Zone Select Bottom Near-left',
            281 => 'Zone Select Bottom',
            282 => 'Zone Select Bottom Near-right',
            283 => 'Zone Select Bottom-right',
        },{ #forum5892
            0 => 'Single Point',
            1 => 'Expanded Area 9-point (S)',
            3 => 'Expanded Area 25-point (M)',
            5 => 'Expanded Area 27-point (L)',
        }],
    }],
    0x000f => [{ #PH
        Name => 'AFPointsInFocus',
        Condition => '$$self{Model} !~ /K-3\b/',
        Notes => 'models other than the K-3',
        Writable => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0xffff => 'None',
            0 => 'Fixed Center or Multiple', #PH/14
            1 => 'Top-left',
            2 => 'Top-center',
            3 => 'Top-right',
            4 => 'Left',
            5 => 'Center',
            6 => 'Right',
            7 => 'Bottom-left',
            8 => 'Bottom-center',
            9 => 'Bottom-right',
        },
    },{ #PH
        Name => 'AFPointsInFocus',
        Writable => 'int32u',
        Notes => 'K-3 only',
        PrintHex => 1,
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Top-left',
                1 => 'Top Near-left',
                2 => 'Top',
                3 => 'Top Near-right',
                4 => 'Top-right',
                5 => 'Upper-left',
                6 => 'Upper Near-left',
                7 => 'Upper-middle',
                8 => 'Upper Near-right',
                9 => 'Upper-right',
                10 => 'Far Left',
                11 => 'Left',
                12 => 'Near-left',
                13 => 'Center',
                14 => 'Near-right',
                15 => 'Right',
                16 => 'Far Right',
                17 => 'Lower-left',
                18 => 'Lower Near-left',
                19 => 'Lower-middle',
                20 => 'Lower Near-right',
                21 => 'Lower-right',
                22 => 'Bottom-left',
                23 => 'Bottom Near-left',
                24 => 'Bottom',
                25 => 'Bottom Near-right',
                26 => 'Bottom-right',
            },
        },
    }],
    0x0010 => { #PH
        Name => 'FocusPosition',
        Writable => 'int16u',
        Notes => 'related to focus distance but affected by focal length',
    },
    0x0012 => { #PH
        Name => 'ExposureTime',
        Writable => 'int32u',
        Priority => 0,
        ValueConv => '$val * 1e-5',
        ValueConvInv => '$val * 1e5',
        # value may be 0xffffffff in Bulb mode (ref JD)
        PrintConv => '$val > 42949 ? "Unknown (Bulb)" : Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val=~/(unknown|bulb)/i ? $val : Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0013 => { #PH
        Name => 'FNumber',
        Writable => 'int16u',
        Priority => 0,
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    # ISO Tag - Entries confirmed by W. Smith 12 FEB 04
    0x0014 => {
        Name => 'ISO',
        Writable => 'int16u',
        Notes => 'may be different than EXIF:ISO, which can round to the nearest full stop',
        PrintConvColumns => 4,
        PrintConv => {
            # 1/3 EV step values
            3 => 50,
            4 => 64,
            5 => 80,
            6 => 100,
            7 => 125, #PH
            8 => 160, #PH
            9 => 200,
            10 => 250,
            11 => 320, #PH
            12 => 400,
            13 => 500,
            14 => 640,
            15 => 800,
            16 => 1000,
            17 => 1250,
            18 => 1600, #PH
            19 => 2000, #PH
            20 => 2500, #PH
            21 => 3200, #PH
            22 => 4000,
            23 => 5000,
            24 => 6400, #PH
            25 => 8000, #PH
            26 => 10000, #PH
            27 => 12800, #PH
            28 => 16000, #PH
            29 => 20000, #PH
            30 => 25600, #PH
            31 => 32000, #PH
            32 => 40000, #PH
            33 => 51200, #PH
            34 => 64000, #PH (NC)
            35 => 80000, #PH (NC)
            36 => 102400, #forum3833
            37 => 128000, #PH (NC)
            38 => 160000, #PH (NC)
            39 => 204800, #forum3833
            # Optio 330/430 (oddball)
            50 => 50, #PH
            100 => 100, #PH
            200 => 200, #PH
            400 => 400, #PH
            800 => 800, #PH
            1600 => 1600, #PH
            3200 => 3200, #PH
            # 1/2 EV step values
            258 => 50, #PH (NC)
            259 => 70, #PH (NC)
            260 => 100, #19
            261 => 140, #19
            262 => 200, #19
            263 => 280, #19
            264 => 400, #19
            265 => 560, #19
            266 => 800, #19
            267 => 1100, #19
            268 => 1600, #19
            269 => 2200, #PH
            270 => 3200, #PH
            271 => 4500, #PH
            272 => 6400, #PH
            273 => 9000, #PH
            274 => 12800, #PH
            275 => 18000, #PH
            276 => 25600, #PH
            277 => 36000, #PH
            278 => 51200, #PH
            # 65534 Auto? (Q/Q10/Q7 MOV) PH
            # 65535 Auto? (K-01 MP4) PH
        },
    },
    0x0015 => { #PH
        Name => 'LightReading',
        Format => 'int16s', # (because I may have seen negative numbers)
        Writable => 'int16u',
        # ranges from 0-12 for my Optio WP - PH
        Notes => q{
            calibrated differently for different models.  For the Optio WP, add 6 to get
            approximate Light Value.  May not be valid for some models, eg. Optio S
        },
    },
    0x0016 => { #PH
        Name => 'ExposureCompensation',
        Writable => 'int16u',
        ValueConv => '($val - 50) / 10',
        ValueConvInv => 'int($val * 10 + 50.5)',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    0x0017 => { #3
        Name => 'MeteringMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Multi-segment',
            1 => 'Center-weighted average',
            2 => 'Spot',
            # have seen value of 16 for E70
        },
    },
    0x0018 => { #PH
        Name => 'AutoBracketing',
        Writable => 'int16u',
        Count => -1,
        Notes => q{
            1 or 2 values: exposure bracket step in EV, then extended bracket if
            available.  Extended bracket values are printed as 'WB-BA', 'WB-GM',
            'Saturation', 'Sharpness', 'Contrast', 'Hue' or 'HighLowKey' followed by
            '+1', '+2' or '+3' for step size
        },
        # 1=.3ev, 2=.7, 3=1.0, ... 10=.5ev, 11=1.5, ...
        ValueConv => [ '$val<10 ? $val/3 : $val-9.5' ],
        ValueConvInv => [ 'abs($val-int($val)-.5)>0.05 ? int($val*3+0.5) : int($val+10)' ],
        PrintConv => sub {
            my @v = split(' ', shift);
            $v[0] = sprintf('%.1f', $v[0]) if $v[0];
            if ($v[1]) {
                my %s = (1=>'WB-BA',2=>'WB-GM',3=>'Saturation',4=>'Sharpness',
                         5=>'Contrast',6=>'Hue',7=>'HighLowKey');
                my $t = $v[1] >> 8;
                $v[1] = sprintf('%s+%d', $s{$t} || "Unknown($t)", $v[1] & 0xff);
            } elsif (defined $v[1]) {
                $v[1] = 'No Extended Bracket',
            }
            return join(' EV, ', @v);
        },
        PrintConvInv => sub {
            my @v = split(/, ?/, shift);
            $v[0] =~ s/ ?EV//i;
            if ($v[1]) {
                my %s = ('WB-BA'=>1,'WB-GM'=>2,'Saturation'=>3,'Sharpness'=>4,
                         'Contrast'=>5,'Hue'=>6,'HighLowKey'=>7);
                if ($v[1] =~ /^No\b/i) {
                    $v[1] = 0;
                } elsif ($v[1] =~ /Unknown\((\d+)\)\+(\d+)/i) {
                    $v[1] = ($1 << 8) + $2;
                } elsif ($v[1] =~ /([\w-]+)\+(\d+)/ and $s{$1}) {
                    $v[1] = ($s{$1} << 8) + $2;
                } else {
                    warn "Bad extended bracket\n";
                }
            }
            return "@v";
        },
    },
    0x0019 => { #3
        Name => 'WhiteBalance',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Fluorescent', #2
            4 => 'Tungsten',
            5 => 'Manual',
            6 => 'Daylight Fluorescent', #13
            7 => 'Day White Fluorescent', #13
            8 => 'White Fluorescent', #13
            9 => 'Flash', #13
            10 => 'Cloudy', #13
            11 => 'Warm White Fluorescent', #PH (K-3)
            14 => 'Multi Auto', #PH (K-3)
            15 => 'Color Temperature Enhancement', #PH
            17 => 'Kelvin', #PH
            0xfffe => 'Unknown', #13
            0xffff => 'User-Selected', #13
        },
    },
    0x001a => { #5
        Name => 'WhiteBalanceMode',
        Writable => 'int16u',
        PrintConv => {
            1 => 'Auto (Daylight)',
            2 => 'Auto (Shade)',
            3 => 'Auto (Flash)',
            4 => 'Auto (Tungsten)',
            6 => 'Auto (Daylight Fluorescent)', #19 (NC)
            7 => 'Auto (Day White Fluorescent)', #17 (K100D guess)
            8 => 'Auto (White Fluorescent)', #17 (K100D guess)
            10 => 'Auto (Cloudy)', #17 (K100D guess)
            # 0xfffd observed in K100D (ref 17)
            0xfffe => 'Unknown', #PH (you get this when shooting night sky shots)
            0xffff => 'User-Selected',
        },
    },
    0x001b => { #6
        Name => 'BlueBalance',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x001c => { #6
        Name => 'RedBalance',
        Writable => 'int16u',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + 0.5)',
    },
    0x001d => [
        # Would be nice if there was a general way to determine units for FocalLength...
        {
            # Optio 30, 33WR, 43WR, 450, 550, 555, 750Z, X
            Name => 'FocalLength',
            Condition => '$self->{Model} =~ /^PENTAX Optio (30|33WR|43WR|450|550|555|750Z|X)\b/',
            Writable => 'int32u',
            Priority => 0,
            ValueConv => '$val / 10',
            ValueConvInv => '$val * 10',
            PrintConv => 'sprintf("%.1f mm",$val)',
            PrintConvInv => '$val=~s/\s*mm//;$val',
        },
        {
            # K100D, Optio 230, 330GS, 33L, 33LF, A10, M10, MX, MX4, S, S30,
            # S4, S4i, S5i, S5n, S5z, S6, S45, S50, S55, S60, SV, Svi, W10, WP,
            # *ist D, DL, DL2, DS, DS2
            # (Note: the Optio S6 seems to report the minimum focal length - PH)
            Name => 'FocalLength',
            Writable => 'int32u',
            Priority => 0,
            ValueConv => '$val / 100',
            ValueConvInv => '$val * 100',
            PrintConv => 'sprintf("%.1f mm",$val)',
            PrintConvInv => '$val=~s/\s*mm//;$val',
        },
    ],
    0x001e => { #3
        Name => 'DigitalZoom',
        Writable => 'int16u',
        ValueConv => '$val / 100', #14
        ValueConvInv => '$val * 100', #14
    },
    0x001f => {
        Name => 'Saturation',
        Writable => 'int16u',
        Count => -1,
        Notes => '1 or 2 values',
        PrintConvColumns => 2,
        PrintConv => [{ # the *istD has pairs of values - PH
            0 => '-2 (low)', #PH
            1 => '0 (normal)', #PH
            2 => '+2 (high)', #PH
            3 => '-1 (med low)', #2
            4 => '+1 (med high)', #2
            5 => '-3 (very low)', #PH
            6 => '+3 (very high)', #PH (NC)
            7 => '-4 (minimum)', #PH (NC)
            8 => '+4 (maximum)', #PH (K-5)
            65535 => 'None', #PH (Monochrome)
        }],
    },
    0x0020 => {
        Name => 'Contrast',
        Writable => 'int16u',
        Count => -1,
        Notes => '1 or 2 values',
        PrintConvColumns => 2,
        PrintConv => [{ # the *istD has pairs of values - PH
            0 => '-2 (low)', #PH
            1 => '0 (normal)', #PH
            2 => '+2 (high)', #PH
            3 => '-1 (med low)', #2
            4 => '+1 (med high)', #2
            5 => '-3 (very low)', #PH
            6 => '+3 (very high)', #PH (NC)
            7 => '-4 (minimum)', #PH (NC)
            8 => '+4 (maximum)', #PH (K-5)
            65535 => 'n/a', # got this for a Backlight Silhouette - PH (Q)
        }],
    },
    0x0021 => {
        Name => 'Sharpness',
        Writable => 'int16u',
        Count => -1,
        Notes => '1 or 2 values',
        PrintConvColumns => 2,
        PrintConv => [{ # the *istD has pairs of values - PH
            0 => '-2 (soft)', #PH
            1 => '0 (normal)', #PH
            2 => '+2 (hard)', #PH
            3 => '-1 (med soft)', #2
            4 => '+1 (med hard)', #2
            5 => '-3 (very soft)', #(NC)
            6 => '+3 (very hard)', #(NC)
            7 => '-4 (minimum)', #PH (NC)
            8 => '+4 (maximum)', #PH (NC)
        }],
    },
    0x0022 => { #PH
        Name => 'WorldTimeLocation',
        Groups => { 2 => 'Time' },
        Writable => 'int16u',
        PrintConv => {
            0 => 'Hometown',
            1 => 'Destination',
        },
    },
    0x0023 => { #PH
        Name => 'HometownCity',
        Groups => { 2 => 'Time' },
        Writable => 'int16u',
        SeparateTable => 'City',
        PrintConv => \%pentaxCities,
    },
    0x0024 => { #PH
        Name => 'DestinationCity',
        Groups => { 2 => 'Time' },
        Writable => 'int16u',
        SeparateTable => 'City',
        PrintConv => \%pentaxCities,
    },
    0x0025 => { #PH
        Name => 'HometownDST',
        Groups => { 2 => 'Time' },
        Writable => 'int16u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x0026 => { #PH
        Name => 'DestinationDST',
        Groups => { 2 => 'Time' },
        Writable => 'int16u',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x0027 => { #PH
        Name => 'DSPFirmwareVersion',
        Writable => 'undef',
        # - for K10D, this comes from 4 bytes at offset 0x1c in the firmware file
        %pentaxFirmwareID,
    },
    0x0028 => { #PH
        Name => 'CPUFirmwareVersion',
        Writable => 'undef',
        # - for K10D, this comes from 4 bytes at offset 0x83fbf8 in firmware file
        %pentaxFirmwareID,
    },
    0x0029 => { #5
        Name => 'FrameNumber',
        # - one report that this has a value of 84 for the first image with a *istDS
        # - another report that file number 4 has frameNumber 154 for *istD, and
        #   that framenumber jumped at about 9700 to around 26000
        # - with *istDS firmware 2.0, this tag was removed and ShutterCount was added
        Writable => 'int32u',
    },
    # 0x002b - definitely exposure related somehow - PH
    0x002d => [{ #PH
        Name => 'EffectiveLV',
        Condition => '$format eq "int16u"',
        Notes => 'camera-calculated light value, but includes exposure compensation',
        Writable => 'int16u',
        Format => 'int16s', # (negative values are valid even though Pentax writes int16u)
        ValueConv => '$val/1024',
        ValueConvInv => '$val * 1024',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },{
        Name => 'EffectiveLV',
        Condition => '$format eq "int32u"',
        Writable => 'int32u',
        Format => 'int32s',
        ValueConv => '$val/1024',
        ValueConvInv => '$val * 1024',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    }],
    0x0032 => { #13
        Name => 'ImageEditing',
        Writable => 'undef',
        Format => 'int8u',
        Count => 4,
        PrintConv => {
            '0 0' => 'None', #PH
            '0 0 0 0' => 'None',
            '0 0 0 4' => 'Digital Filter',
            '1 0 0 0' => 'Resized', #PH (K-5)
            '2 0 0 0' => 'Cropped', #PH
            # note: doesn't apply to digital filters applied when picture is taken
            '4 0 0 0' => 'Digital Filter 4', #PH (K10D)
            '6 0 0 0' => 'Digital Filter 6', #PH (K-5)
            '8 0 0 0' => 'Red-eye Correction', #PH (WG-10)
            '16 0 0 0' => 'Frame Synthesis?',
        },
    },
    0x0033 => { #PH (K110D/K100D/K-m)
        Name => 'PictureMode',
        Writable => 'int8u',
        Count => 3,
        Relist => [ [0, 1], 2 ], # join values 0 and 1 for PrintConv
        PrintConvColumns => 2,
        PrintConv => [{
            # Program dial modes (from K110D)
            '0 0'  => 'Program',    # (also on K10D, custom settings: Program Line 1, e-dial in Program 3, 4 or 5)
            '0 1'  => 'Hi-speed Program', #19 (K10D, custom settings: Program Line 2, e-dial in Program 3, 4 or 5)
            '0 2'  => 'DOF Program', #19      (K10D, custom settings: Program Line 3, e-dial in Program 3, 4 or 5)
            '0 3'  => 'MTF Program', #19      (K10D, custom settings: Program Line 4, e-dial in Program 3, 4 or 5)
            '0 4'  => 'Standard', #13
            '0 5'  => 'Portrait',
            '0 6'  => 'Landscape',
            '0 7'  => 'Macro',
            '0 8'  => 'Sport',
            '0 9'  => 'Night Scene Portrait',
            '0 10' => 'No Flash',
            # SCN modes (menu-selected) (from K100D)
            '0 11' => 'Night Scene',
            '0 12' => 'Surf & Snow',
            '0 13' => 'Text',
            '0 14' => 'Sunset',
            '0 15' => 'Kids',
            '0 16' => 'Pet',
            '0 17' => 'Candlelight',
            '0 18' => 'Museum',
            '0 19' => 'Food',
            '0 20' => 'Stage Lighting',
            '0 21' => 'Night Snap',
            '0 23' => 'Blue Sky', # (Q)
            '0 24' => 'Sunset', # (Q)
            '0 26' => 'Night Scene HDR', # (Q)
            '0 27' => 'HDR', # (Q)
            '0 28' => 'Quick Macro', # (Q)
            '0 29' => 'Forest', # (Q)
            '0 30' => 'Backlight Silhouette', # (Q)
            # AUTO PICT modes (auto-selected)
            '1 4'  => 'Auto PICT (Standard)', #13
            '1 5'  => 'Auto PICT (Portrait)', #7 (K100D)
            '1 6'  => 'Auto PICT (Landscape)', # K110D
            '1 7'  => 'Auto PICT (Macro)', #13
            '1 8'  => 'Auto PICT (Sport)', #13
            # *istD modes (ref 7)
            '2 0'  => 'Program (HyP)', #13 (K-5 Normal program line - PH)
            '2 1'  => 'Hi-speed Program (HyP)', #19 (K10D, custom settings: Program Line 2, e-dial in Program 1, 2)
            '2 2'  => 'DOF Program (HyP)', #19      (K10D, custom settings: Program Line 3, e-dial in Program 1, 2)
            '2 3'  => 'MTF Program (HyP)', #19      (K10D, custom settings: Program Line 4, e-dial in Program 1, 2)
            '2 22' => 'Shallow DOF (HyP)', #PH (K-5)
            '3 0'  => 'Green Mode', #16
            '4 0'  => 'Shutter Speed Priority',
            '5 0'  => 'Aperture Priority',
            '6 0'  => 'Program Tv Shift',
            '7 0'  => 'Program Av Shift', #19
            '8 0'  => 'Manual',
            '9 0'  => 'Bulb',
            '10 0' => 'Aperture Priority, Off-Auto-Aperture',
            '11 0' => 'Manual, Off-Auto-Aperture',
            '12 0' => 'Bulb, Off-Auto-Aperture',
            # extra K10D modes (ref 16)
            '13 0' => 'Shutter & Aperture Priority AE',
            '15 0' => 'Sensitivity Priority AE',
            '16 0' => 'Flash X-Sync Speed AE',
            '18 0' => 'Auto Program (Normal)', #PH (K-5)
            '18 1' => 'Auto Program (Hi-speed)', #PH (NC)
            '18 2' => 'Auto Program (DOF)', #PH (K-5)
            '18 3' => 'Auto Program (MTF)', #PH (NC)
            '18 22' => 'Auto Program (Shallow DOF)', #PH (NC)
            '20 22' => 'Blur Control', #PH (Q)
            '254 0' => 'Video', #PH (K-7,K-5)
            '255 0' => 'Video (Auto Aperture)', #PH (K-5)
            '255 4' => 'Video (4)', #PH (K-x,K-01)
        },{
            # EV step size (ref 19)
            0 => '1/2 EV steps',
            1 => '1/3 EV steps',
        }],
    },
    0x0034 => { #7/PH
        Name => 'DriveMode',
        Writable => 'int8u',
        Count => 4,
        PrintConv => [{
            0 => 'Single-frame', # (also Interval Shooting for K-01 - PH)
            1 => 'Continuous', # (K-5 Hi)
            2 => 'Continuous (Lo)', #PH (K-5)
            3 => 'Burst', #PH (K20D)
            4 => 'Continuous (Medium)', #PH (K-3)
            255 => 'Video', #PH (K-x)
        },{
            0 => 'No Timer',
            1 => 'Self-timer (12 s)',
            2 => 'Self-timer (2 s)',
            15 => 'Video', #PH (Q MOV)
            16 => 'Mirror Lock-up', # (K-5)
            255 => 'n/a', #PH (K-x)
        },{
            0 => 'Shutter Button', # (also computer remote control - PH)
            1 => 'Remote Control (3 s delay)', #19
            2 => 'Remote Control', #19
            4 => 'Remote Continuous Shooting', # (K-5)
        },{
            0x00 => 'Single Exposure',
            0x01 => 'Multiple Exposure',
            0x0f => 'Interval Movie', #PH (K-01)
            0x10 => 'HDR', #PH (645D)
            0x20 => 'HDR Strong 1', #PH (NC) (K-5)
            0x30 => 'HDR Strong 2', #PH (K-5)
            0x40 => 'HDR Strong 3', #PH (K-5)
            0xe0 => 'HDR Auto', #PH (K-5)
            0xff => 'Video', #PH (K-x)
        }],
    },
    0x0035 => { #PH
        Name => 'SensorSize',
        Format => 'int16u',
        Count => 2,
        Notes => 'includes masked pixels',
        # values for various models (not sure why this is in 2um increments):
        #  11894 7962 (K10D,K-m)   12012 7987 (*istDS,K100D,K110D)   12012 8019 (*istD),
        #  12061 7988 (K-5)        12053 8005 (K-r,K-x)              14352 9535 (K20D,K-7)
        #  22315 16711 (645)       12080 8008 (K-01)
        ValueConv => 'my @a=split(" ",$val); $_/=500 foreach @a; join(" ",@a)',
        ValueConvInv => 'my @a=split(" ",$val); $_*=500 foreach @a; join(" ",@a)',
        PrintConv => 'sprintf("%.3f x %.3f mm", split(" ",$val))',
        PrintConvInv => '$val=~s/\s*mm$//; $val=~s/\s*x\s*/ /; $val',
    },
    0x0037 => { #13
        Name => 'ColorSpace',
        Writable => 'int16u',
        PrintConv => {
            0 => 'sRGB',
            1 => 'Adobe RGB',
        },
    },
    0x0038 => { #5 (PEF only)
        Name => 'ImageAreaOffset',
        Writable => 'int16u',
        Count => 2,
    },
    0x0039 => { #PH
        Name => 'RawImageSize',
        Writable => 'int16u',
        Count => 2,
        PrintConv => '$_=$val;s/ /x/;$_',
    },
    0x003c => { #7/PH
        Name => 'AFPointsInFocus',
        # not writable because I'm not decoding these 4 bytes fully:
        # Nibble pattern: XSSSYUUU
        # X = unknown (AF focused flag?, 0 or 1)
        # SSS = selected AF point bitmask (0x000 or 0x7ff if unused)
        # Y = unknown (observed 0,6,7,b,e, always 0 if SSS is 0x000 or 0x7ff)
        # UUU = af points used
        Format => 'int32u',
        Notes => '*istD only',
        ValueConv => '$val & 0x7ff', # ignore other bits for now
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            BITMASK => {
                0 => 'Upper-left',
                1 => 'Top',
                2 => 'Upper-right',
                3 => 'Left',
                4 => 'Mid-left',
                5 => 'Center',
                6 => 'Mid-right',
                7 => 'Right',
                8 => 'Lower-left',
                9 => 'Bottom',
                10 => 'Lower-right',
            },
        },
    },
    0x003d => { #31
        Name => 'DataScaling',
        Writable => 'int16u',
        # divide by the second value of Pentax_0x0201 (WhitePoint), usually
        # 8192, to get the floating point normalization factor.
        # One of the examples of how this tag can be used is calculation of
        # baseline exposure compensation (Adobe-style) for a PEF:
        # log2(Pentax_0x007e)-14-0.5+log2(Pentax_0x003d)-13
        # or
        # log2(Pentax_0x007e*(Pentax_0x003d/(2^13))/(2^14))-0.5
        # where
        # makernotes:Pentax_0x003d/(2^13) is the normalization factor. (ref 31)
        # - 8192 for most images, but occasionally 11571 for K100D/K110D,
        #   and 8289 or 8456 for the K-x (ref PH)
    },
    0x003e => { #PH
        Name => 'PreviewImageBorders',
        Writable => 'int8u',
        Count => 4,
        Notes => 'top, bottom, left, right',
    },
    0x003f => { #PH
        Name => 'LensRec',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensRec' },
    },
    0x0040 => { #PH
        Name => 'SensitivityAdjust',
        Writable => 'int16u',
        ValueConv => '($val - 50) / 10',
        ValueConvInv => '$val * 10 + 50',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
        PrintConvInv => '$val',
    },
    0x0041 => { #19
        Name => 'ImageEditCount',
        Writable => 'int16u',
    },
    0x0047 => { #PH
        Name => 'CameraTemperature',
        Writable => 'int8s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?c$//i; $val',
    },
    0x0048 => { #19
        Name => 'AELock',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x0049 => { #13
        Name => 'NoiseReduction',
        Writable => 'int16u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x004d => [{ #PH
        Name => 'FlashExposureComp',
        Condition => '$count == 1',
        Writable => 'int32s',
        ValueConv => '$val / 256',
        ValueConvInv => 'int($val * 256 + ($val > 0 ? 0.5 : -0.5))',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },{ #PH (K-3)
        Name => 'FlashExposureComp',
        Writable => 'int8s',
        Count => 2,     # (don't know what the 2nd number is for)
        ValueConv => [ '$val / 6' ],
        ValueConvInv => [ '$val / 6' ],
        PrintConv => [ '$val ? sprintf("%+.1f", $val) : 0' ],
        PrintConvInv => [ 'Image::ExifTool::Exif::ConvertFraction($val)' ],
    }],
    0x004f => { #PH
        Name => 'ImageTone', # (Called CustomImageMode in K20D manual)
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Natural',
            1 => 'Bright',
            2 => 'Portrait', # (K20D/K200D)
            3 => 'Landscape', # (K20D)
            4 => 'Vibrant', # (K20D)
            5 => 'Monochrome', # (K20D)
            6 => 'Muted', # (645D)
            7 => 'Reversal Film', # (645D)
            8 => 'Bleach Bypass', # (K-5)
            9 => 'Radiant', # (Q)
        },
    },
    0x0050 => { #PH
        Name => 'ColorTemperature',
        Writable => 'int16u',
        RawConv => '$val ? $val : undef',
        ValueConv => '53190 - $val',
        ValueConvInv => '53190 - $val',
    },
    # 0x0053-0x005a - not in JPEG images - PH
    0x0053 => { #28
        Name => 'ColorTempDaylight',
        %colorTemp,
        Notes => '0x0053-0x005a are 3 numbers: Kelvin, shift AB, shift GM',
    },
    0x0054 => { Name => 'ColorTempShade',        %colorTemp }, #28
    0x0055 => { Name => 'ColorTempCloudy',       %colorTemp }, #28
    0x0056 => { Name => 'ColorTempTungsten',     %colorTemp }, #28
    0x0057 => { Name => 'ColorTempFluorescentD', %colorTemp }, #28
    0x0058 => { Name => 'ColorTempFluorescentN', %colorTemp }, #28
    0x0059 => { Name => 'ColorTempFluorescentW', %colorTemp }, #28
    0x005a => { Name => 'ColorTempFlash',        %colorTemp }, #28
    0x005c => [{ #PH
        Name => 'ShakeReductionInfo',
        Condition => '$count == 4', # (2 bytes for the K-3)
        Format => 'undef', # (written as int8u) - do this just to save time converting the value
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::SRInfo' },
    },{
        Name => 'ShakeReductionInfo',
        Format => 'undef', # (written as int8u) - do this just to save time converting the value
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::SRInfo2' },
    }],
    0x005d => { #JD/PH
        # (used by all Pentax DSLR's except *istD and *istDS until firmware 2.0 - PH)
        # Observed values for the first shot of a new K10D are:  81 [PH], 181 [19],
        # 246 [7], and 209 [18 (one of the first 20 shots)], so there must be a number
        # of test images shot in the factory. (But my new K-5 started at 1 - PH)
        # This count includes shutter actuations even if they don't result in a
        # recorded image (eg. manual white balance frame or digital preview), but
        # does not include actuations due to Live View or video recording - PH
        Name => 'ShutterCount',
        Writable => 'undef',
        Count => 4,
        Notes => q{
            Note: May be reset by servicing!  Also, does not include shutter actuations
            for live view or video recording
        },
        # raw value is a big-endian 4-byte integer, encrypted using Date and Time
        RawConv => 'length($val) == 4 ? unpack("N",$val) : undef',
        RawConvInv => q{
            my $val = Image::ExifTool::Pentax::CryptShutterCount($val,$self);
            return pack('N', $val);
        },
        ValueConv => \&CryptShutterCount,
        ValueConvInv => '$val',
    },
    0x0060 => { #PH (K-5)
        Name => 'FaceInfo',
        Format => 'undef', # (written as int8u)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::FaceInfo' },
    },
    0x0062 => { #forum4803
        Name => 'RawDevelopmentProcess',
        Condition => '$$self{Make} =~ /^(PENTAX|RICOH)/', # rules out Kodak, which also use this tag
        Writable => 'int16u',
        PrintConv => {
            1 => '1 (K10D,K200D,K2000,K-m)',
            3 => '3 (K20D)',
            4 => '4 (K-7)',
            5 => '5 (K-x)',
            6 => '6 (645D)',
            7 => '7 (K-r)',
            8 => '8 (K-5,K-5II,K-5IIs)',
            9 => '9 (Q)',
            10 => '10 (K-01,K-30)',
            11 => '11 (Q10)',
            12 => '12 (MX-1)',
            13 => '13 (K-3)',
            14 => '14 (645Z)',
            15 => '15 (K-S1,K-S2)', #PH
        },
    },
    0x0067 => { #PH (K-5)
        Name => 'Hue',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => -2,
            1 => 'Normal',
            2 => 2,
            3 => -1,
            4 => 1,
            5 => -3,
            6 => 3,
            7 => -4,
            8 => 4,
            65535 => 'None', # (Monochrome)
        },
    },
    # 0x0067 - int16u: 1 [and 65535 in Monochrome] (K20D,K200D) - PH
    0x0068 => { #PH
        Name => 'AWBInfo',
        Format => 'undef', # (written as int8u)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::AWBInfo' },
    },
    0x0069 => { #PH (K20D, K-5, K-01 highlights only)
        Name => 'DynamicRangeExpansion',
        Notes => q{
            called highlight correction by Pentax for the K20D, K-5, K-01 and maybe
            other models
        },
        Writable => 'undef',
        Format => 'int8u',
        Count => 4,
        PrintConv => [{
            0 => 'Off',
            1 => 'On',
        },{
            0 => 0,
            1 => 'Enabled', # (K-01)
            2 => 'Auto', # (K-01)
        }],
    },
    0x006b => { #PH (K-5)
        Name => 'TimeInfo',
        Format => 'undef', # (written as int8u)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::TimeInfo' },
    },
    0x006c => { #PH (K-5)
        Name => 'HighLowKeyAdj',
        Description => 'High/Low Key Adj',
        Writable => 'int16s',
        Count => 2,
        PrintConvColumns => 3,
        PrintConv => {
            '-4 0' => -4,
            '-3 0' => -3,
            '-2 0' => -2,
            '-1 0' => -1,
             '0 0' => 0,
             '1 0' => 1,
             '2 0' => 2,
             '3 0' => 3,
             '4 0' => 4,
        },
    },
    0x006d => { #PH (K-5)
        Name => 'ContrastHighlight',
        Writable => 'int16s',
        Count => 2,
        PrintConvColumns => 3,
        PrintConv => {
            '-4 0' => -4,
            '-3 0' => -3,
            '-2 0' => -2,
            '-1 0' => -1,
             '0 0' => 0,
             '1 0' => 1,
             '2 0' => 2,
             '3 0' => 3,
             '4 0' => 4,
        },
    },
    0x006e => { #PH (K-5)
        Name => 'ContrastShadow',
        Writable => 'int16s',
        Count => 2,
        PrintConvColumns => 3,
        PrintConv => {
            '-4 0' => -4,
            '-3 0' => -3,
            '-2 0' => -2,
            '-1 0' => -1,
             '0 0' => 0,
             '1 0' => 1,
             '2 0' => 2,
             '3 0' => 3,
             '4 0' => 4,
        },
    },
    0x006f => { #PH (K-5)
        Name => 'ContrastHighlightShadowAdj',
        Description => 'Contrast Highlight/Shadow Adj',
        Writable => 'int8u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x0070 => { #PH (K-5)
        Name => 'FineSharpness',
        Writable => 'int8u',
        Count => -1,    # 1 for K20/K200, 2 for K-5
        PrintConv => [{
            0 => 'Off',
            1 => 'On',
        },{
            0 => 'Normal',
            2 => 'Extra fine',
        }],
    },
    0x0071 => { #PH (K20D,K-x)
        Name => 'HighISONoiseReduction',
        Format => 'int8u',
        PrintConv => [{
            0 => 'Off',
            1 => 'Weakest',
            2 => 'Weak', # (called "Low" by K-x)
            3 => 'Strong', # (called "High" by K-x)
            4 => 'Medium',
            255 => 'Auto', # (K-5)
        },{
            0 => 'Inactive',
            1 => 'Active',
            2 => 'Active (Weak)', # (K-5)
            3 => 'Active (Strong)', # (K-5)
            4 => 'Active (Medium)', # (K-5)
        },{ # Start ISO level for NR (K-x)
            48 => 'ISO>400',
            56 => 'ISO>800',
            64 => 'ISO>1600',
            72 => 'ISO>3200',
        }],
    },
    0x0072 => { #JD (K20D)
        Name => 'AFAdjustment',
        Writable => 'int16s',
    },
    0x0073 => { #PH (K-5)
        Name => 'MonochromeFilterEffect',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            65535 => 'None',
            1 => 'Green',
            2 => 'Yellow',
            3 => 'Orange',
            4 => 'Red',
            5 => 'Magenta',
            6 => 'Blue',
            7 => 'Cyan',
            8 => 'Infrared',
        },
    },
    0x0074 => { #PH (K-5)
        Name => 'MonochromeToning',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            65535 => 'None',
            0 => -4,
            1 => -3,
            2 => -2,
            3 => -1,
            4 => 0,
            5 => 1,
            6 => 2,
            7 => 3,
            8 => 4,
        },
    },
    0x0076 => { #PH (K-5)
        Name => 'FaceDetect',
        Writable => 'int8u',
        Count => 2,
        # the Optio S12 writes this but not the FacesDetected tag, so get FacesDetected from here
        DataMember => 'FacesDetected',
        RawConv => '$val =~ / (\d+)/ and $$self{FacesDetected} = $1; $val',
        # (the K-3 reports "On" even in phase-detect focus modes)
        PrintConv => [
            '$val ? "On ($val faces max)" : "Off"',
            '"$val faces detected"',
        ],
        PrintConvInv => [
            '$val =~ /(\d+)/ ? $1 : 0',
            '$val =~ /(\d+)/ ? $1 : 0',
        ],
    },
    0x0077 => { #PH (K-5)
        # set by taking a picture with face detect AF,
        # but it isn't reset until camera is turned off? - PH
        Name => 'FaceDetectFrameSize',
        Writable => 'int16u',
        Count => 2,
    },
    # 0x0078 - int16u[2]: '0 0' (K-5,K-7,K-r,K-x)
    0x0079 => { #PH
        Name => 'ShadowCorrection',
        Writable => 'int8u',
        Count => -1,
        PrintConvColumns => 2,
        PrintConv => {
            # (1 value for K-m/K2000, 2 for 645D)
            0 => 'Off',
            1 => 'On',
            2 => 'Auto 2', # (NC, WG-3)
            '0 0' => 'Off',
            '1 1' => 'Weak',
            '1 2' => 'Normal',
            '1 3' => 'Strong',
            '2 4' => 'Auto', # (K-01)
        },
    },
    0x007a => { #PH
        Name => 'ISOAutoParameters',
        Writable => 'int8u',
        Count => 2,
        PrintConv => {
            '1 0' => 'Slow',
            '2 0' => 'Standard',
            '3 0' => 'Fast',
        },
    },
    0x007b => { #PH (K-5)
        Name => 'CrossProcess',
        Writable => 'int8u',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'Random',
            2 => 'Preset 1',
            3 => 'Preset 2',
            4 => 'Preset 3',
            33 => 'Favorite 1',
            34 => 'Favorite 2',
            35 => 'Favorite 3',
        },
    },
    0x007d => { #PH
        Name => 'LensCorr',
        Format => 'undef', # (written as int8u)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensCorr' },
    },
    0x007e => { #31
        Name => 'WhiteLevel', # (with black level already subtracted)
        Writable => 'int32u',
        # 15859,15860,15864,15865,16315 (K-5 PEF/DNG only) - PH
        # 3934, 3935 (Q DNG) - PH
    },
    0x007f => { #PH (K-5)
        Name => 'BleachBypassToning',
        Writable => 'int16u',
        PrintConvColumns => 2,
        PrintConv => {
            65535 => 'Off',
            1 => 'Green',
            2 => 'Yellow',
            3 => 'Orange',
            4 => 'Red',
            5 => 'Magenta',
            6 => 'Purple',
            7 => 'Blue',
            8 => 'Cyan',
        },
    },
    0x0080 => { #PH (Q)
        Name => 'AspectRatio',
        PrintConv => {
            0 => '4:3',
            1 => '3:2',
            2 => '16:9',
            3 => '1:1',
        },
    },
    # 0x0081 - int8u: 0 (Q)
    0x0082 => {
        Name => 'BlurControl',
        Writable => 'int8u',
        Count => 4,
        PrintConv => [
            {
                0 => 'Off',
                1 => 'Low',
                2 => 'Medium',
                3 => 'High',
            },
            undef, # 0 with BlurControl is Off, seen 0,1,3 when on (related to subject distance?)
            undef, # 0 with BlurControl Off, 45 when on
            undef, # always 0
        ],
    },
    # 0x0083 - int8u: 0 (Q DNG)
    # 0x0084 - int8u: 0 (Q)
    0x0085 => { #PH
        Name => 'HDR',
        Format => 'int8u',
        Count => 4,
        PrintConv => [{ # (K-01,K-3)
            0 => 'Off',
            1 => 'HDR Auto',
            2 => 'HDR 1',
            3 => 'HDR 2',
            4 => 'HDR 3',
        },{ # (K-01)
            0 => 'Auto-align Off',
            1 => 'Auto-align On',
        },{
            # not sure about this - PH
            # - you can set HDR "Exposure Bracket Value" with the K-3
            # - guessed from imaging-resource K-3 samples K3OUTBHDR_A{1,2,3}
            0 => 'n/a',
            4 => '1 EV',
            8 => '2 EV',
            12 => '3 EV', # (get this from K-01, but can't set EV)
        },
        # (4th number is always 0)
        ],
    },
    # 0x0086 - int8u: 0, 111[Sport,Pet] (Q) - related to Tracking FocusMode?
    # 0x0087 - int8u: 0 (Q)
    0x0088 => { #PH
        Name => 'NeutralDensityFilter',
        Writable => 'int8u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x008b => { #PH (LS465)
        Name => 'ISO',
        Priority => 0,
        Writable => 'int32u',
    },
    0x0200 => { #5
        Name => 'BlackPoint',
        Writable => 'int16u',
        Count => 4,
    },
    0x0201 => { #5
        # (this doesn't change for different fixed white balances in JPEG images: Daylight,
        # Tungsten, Kelvin, etc -- always "8192 8192 8192 8192", but it varies for these in
        # RAW images, all images in Auto, for different Manual WB settings, and for images
        # taken via Pentax Remote Assistant) - PH
        Name => 'WhitePoint',
        Writable => 'int16u',
        Count => 4,
    },
    # 0x0202: int16u[4]: all 0's in all my samples
    0x0203 => { #JD (not really sure what these mean)
        Name => 'ColorMatrixA',
        Writable => 'int16s',
        Count => 9,
        ValueConv => 'join(" ",map({ $_/8192 } split(" ",$val)))',
        ValueConvInv => 'join(" ",map({ int($_*8192 + ($_<0?-0.5:0.5)) } split(" ",$val)))',
        PrintConv => 'join(" ",map({sprintf("%.5f",$_)} split(" ",$val)))',
        PrintConvInv => '"$val"',
    },
    0x0204 => { #JD
        Name => 'ColorMatrixB',
        Writable => 'int16s',
        Count => 9,
        ValueConv => 'join(" ",map({ $_/8192 } split(" ",$val)))',
        ValueConvInv => 'join(" ",map({ int($_*8192 + ($_<0?-0.5:0.5)) } split(" ",$val)))',
        PrintConv => 'join(" ",map({sprintf("%.5f",$_)} split(" ",$val)))',
        PrintConvInv => '"$val"',
    },
    0x0205 => [{ #19
        Name => 'CameraSettings',
        # size: *istD/*istDs/K100D/K110D=16, K-m/K2000=14, K-7/K-x=19,
        #       K200D/K20D/K-5/645D=20, K-r=21, K10D=22, K-01=25
        Condition => '$count < 25', # (not valid for the K-01)
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::CameraSettings',
            ByteOrder => 'BigEndian',
        },
    },{
        Name => 'CameraSettingsUnknown',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::CameraSettingsUnknown',
            ByteOrder => 'BigEndian',
        },
    }],
    0x0206 => [{ #PH
        Name => 'AEInfo',
        # size: *istD/*istDs/K100D/K110D=14, K10D/K200D/K20D=16, K-m/K2000=20,
        #        K-7/K-x=24, K-5/K-r/645D=25
        Condition => '$count <= 25 and $count != 21 and $$self{AEInfoSize} = $count',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::AEInfo' },
    },{
        Name => 'AEInfo2',
        # size: K-01=21
        Condition => '$count == 21',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::AEInfo2' },
    },{
        Name => 'AEInfo3',
        # size: K-30=48
        Condition => '$count == 48',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::AEInfo3' },
    },{
        Name => 'AEInfoUnknown',
        # size: Q/Q10=34
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::AEInfoUnknown' },
    }],
    0x0207 => [ #PH
        {
            Name => 'LensInfo',
            # the *ist series (and Samsung GX-1) always use the old format, and all
            # other models but the K100D, K110D and K100D Super always use the newer
            # format, and for the K110D/K110D we expect ff or 00 00 at byte 20 if
            # it is the old format.)
            Condition => q{
                $$self{Model}=~/(\*ist|GX-1[LS])/ or
               ($$self{Model}=~/(K100D|K110D)/ and $$valPt=~/^.{20}(\xff|\0\0)/s)
            },
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensInfo' },
        },{
            Name => 'LensInfo',
            Condition => '$count != 90 and $count != 91 and $count != 80 and $count != 128',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensInfo2' },
        },{
            Name => 'LensInfo', # 645D
            Condition => '$count == 90',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensInfo3' },
        },{
            Name => 'LensInfo', # K-r, K-5, K-5II
            Condition => '$count == 91',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensInfo4' },
        },{
            Name => 'LensInfo', # K-01, K-30, K-50, K-500, K-3
            Condition => '$count == 80 or $count == 128',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensInfo5' },
        }
    ],
    0x0208 => [ #PH
        {
            Name => 'FlashInfo',
            Condition => '$count == 27',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::FlashInfo' },
        },
        {
            Name => 'FlashInfoUnknown',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::FlashInfoUnknown' },
        },
    ],
    0x0209 => { #PH
        Name => 'AEMeteringSegments',
        Format => 'int8u',
        Count => -1,
        Notes => q{
            measurements from each of the 16 AE metering segments for models such as the
            K10D, 77 metering segments for models such as the K-5, and 4050 metering
            segments for the K-3, converted to LV
        },
        %convertMeteringSegments,
        #  16 metering segment              77 metering segment
        #  locations (ref JD, K10D)         locations (ref PH, K-5)
        # +-------------------------+
        # |           14            | +----------------------------------+
        # |    +---+---+---+---+    | |  0  1  2  3  4  5  6  7  8  9 10 |
        # |    | 5 | 3/1\ 2| 4 |    | | 11 12 13 14 15 16 17 18 19 20 21 |
        # |  +-+-+-+-+ - +-+-+-+-+  | | 22 23 24 25 26 27 28 29 30 31 32 |
        # +--+ 9 | 7 ||0|| 6 | 8 +--+ | 33 34 35 36 37 38 39 40 41 42 43 |
        # |  +-+-+-+-+ - +-+-+-+-+  | | 44 45 46 47 48 49 50 51 52 53 54 |
        # |    |13 |11\ /10|12 |    | | 55 56 57 58 59 60 61 62 63 64 65 |
        # |    +---+---+---+---+    | | 66 67 68 69 70 71 72 73 74 75 76 |
        # |           15            | +----------------------------------+
        # +-------------------------+
    },
    0x020a => { #PH/JD/19
        Name => 'FlashMeteringSegments',
        Format => 'int8u',
        Count => -1,
        %convertMeteringSegments,
    },
    0x020b => { #PH/JD/19
        Name => 'SlaveFlashMeteringSegments',
        Format => 'int8u',
        Count => -1,
        Notes => 'used in wireless control mode',
        %convertMeteringSegments,
    },
    0x020d => { #PH
        Name => 'WB_RGGBLevelsDaylight',
        Writable => 'int16u',
        Count => 4,
    },
    0x020e => { #PH
        Name => 'WB_RGGBLevelsShade',
        Writable => 'int16u',
        Count => 4,
    },
    0x020f => { #PH
        Name => 'WB_RGGBLevelsCloudy',
        Writable => 'int16u',
        Count => 4,
    },
    0x0210 => { #PH
        Name => 'WB_RGGBLevelsTungsten',
        Writable => 'int16u',
        Count => 4,
    },
    0x0211 => { #PH
        Name => 'WB_RGGBLevelsFluorescentD',
        Writable => 'int16u',
        Count => 4,
    },
    0x0212 => { #PH
        Name => 'WB_RGGBLevelsFluorescentN',
        Writable => 'int16u',
        Count => 4,
    },
    0x0213 => { #PH
        Name => 'WB_RGGBLevelsFluorescentW',
        Writable => 'int16u',
        Count => 4,
    },
    0x0214 => { #PH
        Name => 'WB_RGGBLevelsFlash',
        Writable => 'int16u',
        Count => 4,
    },
    0x0215 => { #PH
        Name => 'CameraInfo',
        Format => 'undef', # (written as int32u)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::CameraInfo' },
    },
    0x0216 => { #PH
        Name => 'BatteryInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::BatteryInfo',
            ByteOrder => 'BigEndian', # have seen makernotes changed to little-endian in DNG!
        },
    },
    # 0x021a - undef[1068] (K-5) - ToneMode/Saturation mapping matrices (ref 28)
    0x021b => { #19
        Name => 'SaturationInfo',
        Flags => [ 'Unknown', 'Binary' ],
        Writable => 0,
        Notes => 'only in PEF and DNG images',
        # K10D values with various Saturation settings (ref 19):
        # Very Low: 000000022820f9a0fe4000802660f92002e0fee01e402c40f880fb40ffc02b20f52002e0fe401ee0
        # Low:      000000022ae0f700fe20ff402840f88001e0fcc021602f60f560fb40fe602d20f48001c0fbc02280
        # Med Low:  000000022dc0f420fe20fe002a20f7e000c0fa8024c032c0f220fb20fce02f60f3c000a0f9202640
        # Normal:   000000023120f0e0fe00fc802c40f740ffa0f7e028803660ee80fb20fb4031c0f300ff60f6202a80
        # Med High: 0000000234e0ed40fde0fae02ea0f680fe60f5002ca03a80ea80fb00f9603480f220fe00f2e02f20
        # High:     0000000238c0e960fde0f9203140f5a0fce0f1e031403f00e600fb00f7803760f120fc60ef403460
        # Very High:000000023d20e520fdc0f7203420f4c0fb60ee6036404400e120fae0f5403aa0f020fac0eb403a00
    },
    # 0x021c - undef[18] (K-5)
    # 0x021d - undef[18] (K-5)
    # 0x021e - undef[8] (K-5, Q)
    0x021f => { #JD
        Name => 'AFInfo',
        SubDirectory => {
            # NOTE: Most of these subdirectories are 'undef' format, and as such the
            # byte ordering is not changed when changed via the Pentax software (which
            # will write a little-endian TIFF on an Intel system).  So we must define
            # BigEndian byte ordering for any of these which contain multi-byte values. - PH
            ByteOrder => 'BigEndian',
            TagTable => 'Image::ExifTool::Pentax::AFInfo',
        },
    },
    0x0220 => { #6
        Name => 'HuffmanTable',
        Flags => [ 'Unknown', 'Binary' ],
        Writable => 0,
        Notes => 'found in K10D, K20D and K2000D PEF images',
    },
    0x0221 => { #28
        Name => 'KelvinWB',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::KelvinWB' },
    },
    0x0222 => { #PH
        Name => 'ColorInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::ColorInfo' },
    },
    # 0x0223 - undef[198] (K-5 PEF/DNG only)
    0x0224 => { #19
        Name => 'EVStepInfo',
        Drop => 200, # drop if larger than 200 bytes (40 kB in Pentax Q and Q10)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::EVStepInfo' },
    },
    0x0226 => { #PH
        Name => 'ShotInfo', # (may want to change this later when more is decoded)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::ShotInfo' },
    },
    0x0227 => { #PH
        Name => 'FacePos',
        Condition => '$$self{FacesDetected}', # ignore if no faces to decode
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::FacePos' },
    },
    0x0228 => { #PH
        Name => 'FaceSize',
        Condition => '$$self{FacesDetected}', # ignore if no faces to decode
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::FaceSize' },
    },
    0x0229 => { #PH (verified) (K-m, K-x, K-7)
        Name => 'SerialNumber',
        Writable => 'string',
        Notes => 'left blank by some cameras',
    },
    0x022a => { #PH (K-5)
        Name => 'FilterInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::FilterInfo',
            ByteOrder => 'BigEndian',
        },
    },
    0x022b => { #PH (K-5)
        Name => 'LevelInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LevelInfo' },
    },
    # 0x022c - undef[46] (K-5)
    0x022d => { #28
        Name => 'WBLevels',
        Condition => '$count == 100', # (just to be safe, but no other counts observed)
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::WBLevels' },
    },
    0x022e => { #PH (K-5 AVI videos)
        Name => 'Artist',
        Groups => { 2 => 'Author' },
        Writable => 'string',
    },
    0x022f => { #PH (K-5 AVI videos)
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
        Writable => 'string',
    },
    0x0230 => { #PH (K-x AVI videos)
        Name => 'FirmwareVersion',
        Notes => 'only in AVI videos',
        # this tag only exists in AVI videos, and for the K-x the value of
        # this tag is "K-x Ver 1.00", which is the same as the EXIF Software
        # tag.  I used a different tag name for this because Pentax uses the
        # AVI Software tag for a different string, "PENTAX K-x".
        Writable => 'string',
    },
    0x0231 => { #PH (K-5)
        Name => 'ContrastDetectAFArea',
        Writable => 'int16u',
        Count => 4,
        Notes => q{
            AF area of the most recent contrast-detect focus operation. Coordinates
            are left, top, width and height in a 720x480 frame, with Y downwards
        },
    },
    0x0235 => { #PH (K-5)
        Name => 'CrossProcessParams',
        # (it would be interesting to know exactly what these mean)
        Writable => 'undef',
        Format => 'int8u',
        Count => 10,
    },
    # 0x0236 - undef[52] (Q)
    # 0x0237 - undef[11] possibly related to smart effect setting? (Q)
    # 0x0238 - undef[9] (Q)
    0x0239 => { #PH
        Name => 'LensInfoQ',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensInfoQ' },
    },
    # 0x023a - undef[10] (Q)
    # 0x023b - undef[9] (K-01)
    #  01a700500000000000, 91a700500000000000, 41a700500000000000, 002700500000000000
    #  c00500400000000000, 400500500000000000, 4004ff420100000000, 4087ff480000000000
    0x03fe => { #PH
        Name => 'DataDump',
        Writable => 0,
        PrintConv => '\$val',
    },
    0x03ff => [ #PH
        {
            Name => 'TempInfo',
            Condition => '$$self{Model} =~ /K-(01|3|30|5|50|500)\b/',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::TempInfo' },
        },{
            Name => 'UnknownInfo',
            SubDirectory => { TagTable => 'Image::ExifTool::Pentax::UnknownInfo' },
        },
    ],
    0x0402 => { #5
        Name => 'ToneCurve',
        PrintConv => '\$val',
    },
    0x0403 => { #5
        Name => 'ToneCurves',
        PrintConv => '\$val',
    },
    # 0x0404 - undef[2086] (K-5)
    0x0405 => { #PH - undef[24200] (K-5 PEF/DNG only), undef[28672] (Q DNG)
        Name => 'UnknownBlock',
        Writable => 'undef',
        Notes => 'large unknown data block in PEF/DNG images but not JPG images',
        Flags => [ 'Unknown', 'Binary', 'Drop' ],
    },
    # 0x0406 - undef[4116] (K-5)
    # 0x0407 - undef[3072] (Q DNG)
    # 0x0408 - undef[1024] (Q DNG)
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);

# shake reduction information (ref PH)
%Image::ExifTool::Pentax::SRInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Shake reduction information.',
    0 => {
        Name => 'SRResult',
        PrintConv => { #PH/JD
            0 => 'Not stabilized',
            BITMASK => {
                0 => 'Stabilized',
                # have seen 1 and 4 for 0.5 and 0.3 sec exposures with NR on and Bit 0 also set - ref 19
                # have seen bits 1,2,3,4 in K-5 AVI videos - PH
                6 => 'Not ready',
            },
        },
    },
    1 => {
        Name => 'ShakeReduction',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
            4 => 'Off (4)', # (K20D, K200D, K-7, K-5)
            5 => 'On but Disabled', # (K20D, K-5)
            # (can be 5 "On but Disabled" for K-5 with HDR [auto-align off only],
            # Composition Adjust, DriveMode = Self-timer or Remote, and movie with SR off!)
            6 => 'On (Video)', # (K-7)
            7 => 'On (7)', #(NC) (K20D, K200D, K-m, K-5)
            15 => 'On (15)', # (K20D with Tamron 10-20mm @ 10mm)
            39 => 'On (mode 2)', # (K-01) (on during capture and live view)
            135 => 'On (135)', # (K-5IIs)
            167 => 'On (mode 1)', # (K-01) (on during capture only)
        },
    },
    2 => {
        Name => 'SRHalfPressTime',
        # (was SR_SWSToSWRTime: SWS=photometering switch, SWR=shutter release switch)
        # (from http://www.patentstorm.us/patents/6597867-description.html)
        # (here, SR could more accurately mean Shutter Release, not Shake Reduction)
        # (not valid for K-01 - PH)
        Notes => q{
            time from when the shutter button was half pressed to when the shutter was
            released, including time for focusing.  Not valid for some models
        },
        # (constant of 60 determined from times: 2sec=127; 3sec=184,197; 4sec=244,249,243,246 - PH)
        ValueConv => '$val / 60',
        ValueConvInv => 'my $v=$val*60; $v < 255 ? int($v + 0.5) : 255',
        PrintConv => 'sprintf("%.2f s",$val) . ($val > 254.5/60 ? " or longer" : "")',
        PrintConvInv => '$val=~tr/0-9.//dc; $val',
    },
    3 => { #JD
        Name => 'SRFocalLength',
        ValueConv => '$val & 0x01 ? $val * 4 : $val / 2',
        ValueConvInv => '$val <= 127 ? int($val) * 2 : int($val / 4) | 0x01',
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm//;$val',
    },
);

# shake reduction information for the K-3 (ref PH)
%Image::ExifTool::Pentax::SRInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Shake reduction information for the K-3.',
    0 => {
        Name => 'SRResult',
        Unknown => 1,
        PrintConv => { BITMASK => {
            # Bit 0 - have seen this set in a few Pentax samples - PH
            # Bit 6 - usually set when SR is Off, and occasionally when On - PH
            # Bit 7 - set when AA simulation is on - PH
        }},
    },
    1 => {
        Name => 'ShakeReduction',
        PrintConv => { #forum5425
            0 => 'Off', # (NC for K-3)
            1 => 'On', # (NC for K-3)
            4 => 'Off (AA simulation off)',
            5 => 'On but Disabled', # (NC for K-3)
            6 => 'On (Video)', # (NC for K-3)
            7 => 'On (AA simulation off)',
            12 => 'Off (AA simulation type 1)', # (AA linear motion)
            15 => 'On (AA simulation type 1)', # (AA linear motion)
            20 => 'Off (AA simulation type 2)', # (AA circular motion)
            23 => 'On (AA simulation type 2)', # (AA circular motion)
        },
    },
);

# face detection information (ref PH, K-5)
%Image::ExifTool::Pentax::FaceInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 0 ],
    0 => {
        Name => 'FacesDetected',
        RawConv => '$$self{FacesDetected} = $val',
    },
    2 => {
        Name => 'FacePosition',
        Notes => q{
            X/Y coordinates of the center of the main face in percent of frame size,
            with positive Y downwards
        },
        Format => 'int8u[2]',
    },
);

# automatic white balance settings (ref PH, K-5)
%Image::ExifTool::Pentax::AWBInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # 0 - always 1?
    # (data ends here for the K20D, K200D, K-x and K-7)
    0 => {
        Name => 'WhiteBalanceAutoAdjustment',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    1 => { # (exists only for K-5)
        Name => 'TungstenAWB',
        PrintConv => {
            0 => 'Subtle Correction',
            1 => 'Strong Correction',
        },
    },
);

# world time settings (ref PH, K-5)
%Image::ExifTool::Pentax::TimeInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Time' },
    0.1 => {
        Name => 'WorldTimeLocation',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Hometown',
            0x01 => 'Destination',
        },
    },
    0.2 => {
        Name => 'HometownDST',
        Mask => 0x02,
        PrintConv => {
            0x00 => 'No',
            0x02 => 'Yes',
        },
    },
    0.3 => {
        Name => 'DestinationDST',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'No',
            0x04 => 'Yes',
        },
    },
    2 => {
        Name => 'HometownCity',
        SeparateTable => 'City',
        PrintConv => \%pentaxCities,
    },
    3 => {
        Name => 'DestinationCity',
        SeparateTable => 'City',
        PrintConv => \%pentaxCities,
    },
);

# lens distortion correction (ref PH, K-5)
%Image::ExifTool::Pentax::LensCorr = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    0 => {
        Name => 'DistortionCorrection',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    1 => {
        Name => 'ChromaticAberrationCorrection',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    2 => {
        Name => 'VignettingCorrection',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# camera settings (ref 19)
%Image::ExifTool::Pentax::CameraSettings = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PRIORITY => 0,
    NOTES => 'Camera settings information written by Pentax DSLR cameras.',
    0 => {
        Name => 'PictureMode2',
        PrintConv => {
            0 => 'Scene Mode', #PH
            1 => 'Auto PICT', #PH (NC)
            2 => 'Program AE',
            3 => 'Green Mode',
            4 => 'Shutter Speed Priority',
            5 => 'Aperture Priority',
            6 => 'Program Tv Shift', #PH
            7 => 'Program Av Shift',
            8 => 'Manual', #PH
            9 => 'Bulb', #PH
            10 => 'Aperture Priority, Off-Auto-Aperture', #PH (NC)
            11 => 'Manual, Off-Auto-Aperture', #PH
            12 => 'Bulb, Off-Auto-Aperture', #PH (NC)
            13 => 'Shutter & Aperture Priority AE',
            15 => 'Sensitivity Priority AE',
            16 => 'Flash X-Sync Speed AE', #PH
        },
    },
    1.1 => {
        Name => 'ProgramLine',
        # only set to other than Normal when in Program AE mode
        Mask => 0x03,
        PrintConv => {
            0 => 'Normal',
            1 => 'Hi Speed',
            2 => 'Depth',
            3 => 'MTF',
        },
    },
    1.2 => { # (K10D, K-5)
        Name => 'EVSteps',
        Mask => 0x20,
        PrintConv => {
            0x00 => '1/2 EV Steps',
            0x20 => '1/3 EV Steps',
        },
    },
    1.3 => { # (this bit is set for movies with the K-5 - PH)
        Name => 'E-DialInProgram',
        # always set even when not in Program AE mode
        Mask => 0x40,
        PrintConv => {
            0x00 => 'Tv or Av',
            0x40 => 'P Shift',
        },
    },
    1.4 => { # (K10D, K-5)
        Name => 'ApertureRingUse',
        # always set even Aperture Ring is in A mode
        Mask => 0x80,
        PrintConv => {
            0x00 => 'Prohibited',
            0x80 => 'Permitted',
        },
    },
    2 => {
        Name => 'FlashOptions',
        Notes => 'the camera flash options settings, set even if the flash is off',
        Mask => 0xf0,
        ValueConv => '$val>>4',
        ValueConvInv => '$val<<4',
        # Note: These tags correlate with the FlashMode and InternalFlashMode values,
        # and match what is displayed by the Pentax software
        PrintConv => {
            0 => 'Normal', # (this value can occur in Green Mode) - ref 19
            1 => 'Red-eye reduction', # (this value can occur in Green Mode) - ref 19
            2 => 'Auto', # (this value can occur in other than Green Mode) - ref 19
            3 => 'Auto, Red-eye reduction', #PH (this value can occur in other than Green Mode) - ref 19
            5 => 'Wireless (Master)',
            6 => 'Wireless (Control)',
            8 => 'Slow-sync',
            9 => 'Slow-sync, Red-eye reduction',
            10 => 'Trailing-curtain Sync'
        },
    },
    2.1 => {
        Name => 'MeteringMode2',
        Mask => 0x0f,
        Notes => 'may not be valid for some models, eg. *ist D',
        PrintConv => {
            0 => 'Multi-segment',
            BITMASK => {
                0 => 'Center-weighted average',
                1 => 'Spot',
            },
        },
    },
    3 => {
        Name => 'AFPointMode',
        Mask => 0xf0,
        PrintConv => {
            0x00 => 'Auto',
            BITMASK => {
                4 => 'Select',
                5 => 'Fixed Center',
                # have seen bit 6 set in pre-production images (firmware 0.20) - PH
            },
        },
    },
    3.1 => {
        Name => 'FocusMode2',
        Mask => 0x0f,
        PrintConv => {
            0 => 'Manual',
            1 => 'AF-S',
            2 => 'AF-C',
            3 => 'AF-A', #PH
        },
    },
    4 => {
        Name => 'AFPointSelected2',
        Format => 'int16u',
        PrintConv => {
            0 => 'Auto',
            BITMASK => {
                0 => 'Upper-left',
                1 => 'Top',
                2 => 'Upper-right',
                3 => 'Left',
                4 => 'Mid-left',
                5 => 'Center',
                6 => 'Mid-right',
                7 => 'Right',
                8 => 'Lower-left',
                9 => 'Bottom',
                10 => 'Lower-right',
            },
        },
    },
    6 => {
        Name => 'ISOFloor', #PH
        # manual ISO or minimum ISO in Auto ISO mode - PH
        ValueConv => 'int(100*exp(Image::ExifTool::Pentax::PentaxEv($val-32)*log(2))+0.5)',
        ValueConvInv => 'Image::ExifTool::Pentax::PentaxEvInv(log($val/100)/log(2))+32',
    },
    7 => {
        Name => 'DriveMode2',
        PrintConv => {
            0 => 'Single-frame',
            BITMASK => {
                0 => 'Continuous', # (K-5 Hi)
                1 => 'Continuous (Lo)', #PH (K-5)
                2 => 'Self-timer (12 s)', #PH
                3 => 'Self-timer (2 s)', #PH
                4 => 'Remote Control (3 s delay)',
                5 => 'Remote Control',
                6 => 'Exposure Bracket', #PH/19
                7 => 'Multiple Exposure',
            },
        },
    },
    8 => {
        Name => 'ExposureBracketStepSize',
        # This is set even when Exposure Bracket is Off (and the K10D
        # displays Ò---Ó as the step size when you press the EB button) - DaveN
        # because the last value is remembered and if you turn Exposure Bracket
        # on the step size goes back to what it was before.
        PrintConv => {
            3 => '0.3',
            4 => '0.5',
            5 => '0.7',
            8 => '1.0', #PH
            11 => '1.3',
            12 => '1.5',
            13 => '1.7', #(NC)
            16 => '2.0', #PH
        },
    },
    9 => { #PH/19
        Name => 'BracketShotNumber',
        PrintHex => 1,
        PrintConv => {
            0 => 'n/a',
            0x02 => '1 of 2', #PH (K-5)
            0x12 => '2 of 2', #PH (K-5)
            0x03 => '1 of 3',
            0x13 => '2 of 3',
            0x23 => '3 of 3',
            0x05 => '1 of 5',
            0x15 => '2 of 5',
            0x25 => '3 of 5',
            0x35 => '4 of 5',
            0x45 => '5 of 5',
        },
    },
    10 => {
        Name => 'WhiteBalanceSet',
        Mask => 0xf0,
        # Not necessarily the white balance used; for example if the custom menu is set to
        # "WB when using flash" -> "2 Flash", then this tag reports the camera setting while
        # tag 0x0019 reports Flash if the Flash was used.
        PrintConv => {
            0 => 'Auto',
            16 => 'Daylight',
            32 => 'Shade',
            48 => 'Cloudy',
            64 => 'Daylight Fluorescent',
            80 => 'Day White Fluorescent',
            96 => 'White Fluorescent',
            112 => 'Tungsten',
            128 => 'Flash',
            144 => 'Manual',
            # The three Set Color Temperature settings refer to the 3 preset settings which
            # can be saved in the menu (see page 123 of the K10D manual)
            192 => 'Set Color Temperature 1',
            208 => 'Set Color Temperature 2',
            224 => 'Set Color Temperature 3',
        },
    },
    10.1 => {
        Name => 'MultipleExposureSet',
        Mask => 0x0f,
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    13 => {
        Name => 'RawAndJpgRecording',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        # this is actually a bit field: - PH
        # bit 0=JPEG, bit 2=PEF, bit 3=DNG; high nibble: 0x00=best, 0x20=better, 0x40=good
        PrintHex => 1,
        PrintConv => {
            0x01 => 'JPEG (Best)', #PH
            0x04 => 'RAW (PEF, Best)',
            0x05 => 'RAW+JPEG (PEF, Best)',
            0x08 => 'RAW (DNG, Best)', #PH (NC)
            0x09 => 'RAW+JPEG (DNG, Best)', #PH (NC)
            0x21 => 'JPEG (Better)', #PH
            0x24 => 'RAW (PEF, Better)',
            0x25 => 'RAW+JPEG (PEF, Better)', #PH
            0x28 => 'RAW (DNG, Better)', #PH
            0x29 => 'RAW+JPEG (DNG, Better)', #PH (NC)
            0x41 => 'JPEG (Good)',
            0x44 => 'RAW (PEF, Good)', #PH (NC)
            0x45 => 'RAW+JPEG (PEF, Good)', #PH (NC)
            0x48 => 'RAW (DNG, Good)', #PH (NC)
            0x49 => 'RAW+JPEG (DNG, Good)',
            # have seen values of 0,2,34 for other models (not K10D) - PH
        },
    },
    14.1 => { #PH
        Name => 'JpgRecordedPixels',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        Mask => 0x03,
        PrintConv => {
            0 => '10 MP',
            1 => '6 MP',
            2 => '2 MP',
        },
    },
    14.2 => { #PH (K-5)
        Name => 'LinkAEToAFPoint',
        Condition => '$$self{Model} =~ /K-5\b/',
        Notes => 'K-5 only',
        Mask => 0x01,
        PrintConv => {
            0x00 => 'Off',
            0x01 => 'On',
        },
    },
    14.3 => { #PH (K-5)
        Name => 'SensitivitySteps',
        Condition => '$$self{Model} =~ /K-5\b/',
        Notes => 'K-5 only',
        Mask => 0x02,
        PrintConv => {
            0x00 => '1 EV Steps',
            0x02 => 'As EV Steps',
        },
    },
    14.4 => { #PH (K-5)
        Name => 'ISOAuto',
        Condition => '$$self{Model} =~ /K-5\b/',
        Notes => 'K-5 only',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Off',
            0x04 => 'On',
        },
    },
    # 14.5 Mask 0x80 - changes for K-5
    16 => {
        Name => 'FlashOptions2',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only; set even if the flash is off',
        Mask => 0xf0,
        # Note: the Normal and Auto values (0x00 to 0x30) do not tags always
        # correlate with the FlashMode, InternalFlashMode and FlashOptions values
        # however, these values seem to better match the K10D's actual functionality
        # (always Auto in Green mode always Normal otherwise if one of the other options
        # isn't selected) - ref 19
        # (these tags relate closely to InternalFlashMode values - PH)
        PrintConv => {
            0x00 => 'Normal', # (this value never occurs in Green Mode) - ref 19
            0x10 => 'Red-eye reduction', # (this value never occurs in Green Mode) - ref 19
            0x20 => 'Auto',  # (this value only occurs in Green Mode) - ref 19
            0x30 => 'Auto, Red-eye reduction', # (this value only occurs in Green Mode) - ref 19
            0x50 => 'Wireless (Master)',
            0x60 => 'Wireless (Control)',
            0x80 => 'Slow-sync',
            0x90 => 'Slow-sync, Red-eye reduction',
            0xa0 => 'Trailing-curtain Sync'
        },
    },
    16.1 => {
        Name => 'MeteringMode3',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        Mask => 0x0f,
        PrintConv => {
            0 => 'Multi-segment',
            BITMASK => {
                0 => 'Center-weighted average',
                1 => 'Spot',
            },
        },
    },
    # 16 Mask 0x0f - changes when changing EV steps? (K-5)
    17.1 => {
        Name => 'SRActive',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => q{
            K10D only; SR is active only when ShakeReduction is On, DriveMode is not
            Remote or Self-timer, and Internal/ExternalFlashMode is not "On, Wireless"
        },
        Mask => 0x80,
        PrintConv => {
            0x00 => 'No',
            0x80 => 'Yes',
        },
    },
    17.2 => {
        Name => 'Rotation',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        Mask => 0x60,
        PrintConv => {
            0x00 => 'Horizontal (normal)',
            0x20 => 'Rotate 180',
            0x40 => 'Rotate 90 CW',
            0x60 => 'Rotate 270 CW',
        },
    },
    # Bit 0x08 is set on 3 of my 3000 shots to (All 3 were Shutter Priority
    # but this may not mean anything with such a small sample) - ref 19
    17.3 => {
        Name => 'ISOSetting',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        Mask => 0x04,
        PrintConv => {
            0x00 => 'Manual',
            0x04 => 'Auto',
        },
    },
    17.4 => {
        Name => 'SensitivitySteps',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        Mask => 0x02,
        PrintConv => {
            0x00 => '1 EV Steps',
            0x02 => 'As EV Steps',
        },
    },
    # 17 Mask 0x08 - changed when changing Auto ISO range (K-5)
    18 => {
        Name => 'TvExposureTimeSetting',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        ValueConv => 'exp(-Image::ExifTool::Pentax::PentaxEv($val-68)*log(2))',
        ValueConvInv => 'Image::ExifTool::Pentax::PentaxEvInv(-log($val)/log(2))+68',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    19 => {
        Name => 'AvApertureSetting',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        ValueConv => 'exp(Image::ExifTool::Pentax::PentaxEv($val-68)*log(2)/2)',
        ValueConvInv => 'Image::ExifTool::Pentax::PentaxEvInv(log($val)*2/log(2))+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    20 => { #PH
        Name => 'SvISOSetting',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only',
        # ISO setting for sensitivity-priority mode
        # (conversion may not give actual displayed values:)
        # 32 => 100, 35 => 125, 36 => 140, 37 => 160,
        # 40 => 200, 43 => 250, 44 => 280, 45 => 320,
        # 48 => 400, 51 => 500, 52 => 560, 53 => 640,
        # 56 => 800, 59 => 1000,60 => 1100,61 => 1250, 64 => 1600
        ValueConv => 'int(100*exp(Image::ExifTool::Pentax::PentaxEv($val-32)*log(2))+0.5)',
        ValueConvInv => 'Image::ExifTool::Pentax::PentaxEvInv(log($val/100)/log(2))+32',
    },
    21 => { #PH
        Name => 'BaseExposureCompensation',
        Condition => '$$self{Model} =~ /(K10D|GX10)\b/',
        Notes => 'K10D only; exposure compensation without auto bracketing',
        ValueConv => 'Image::ExifTool::Pentax::PentaxEv(64-$val)',
        ValueConvInv => '64-Image::ExifTool::Pentax::PentaxEvInv($val)',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
);

# unknown camera settings (K-01)
%Image::ExifTool::Pentax::CameraSettingsUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'This information has not yet been decoded for models such as the K-01.',
);

# auto-exposure information (ref PH)
%Image::ExifTool::Pentax::AEInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 7 ],
    NOTES => 'Auto-exposure information for most Pentax models.',
    # instead of /8, should these be PentaxEv(), as in CameraSettings? - PH
    0 => {
        Name => 'AEExposureTime',
        Notes => 'val = 24 * 2**((32-raw)/8)',
        ValueConv => '24*exp(-($val-32)*log(2)/8)',
        ValueConvInv => '-log($val/24)*8/log(2)+32',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    1 => {
        Name => 'AEAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    2 => {
        Name => 'AE_ISO',
        Notes => 'val = 100 * 2**((raw-32)/8)',
        ValueConv => '100*exp(($val-32)*log(2)/8)',
        ValueConvInv => 'log($val/100)*8/log(2)+32',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    3 => {
        Name => 'AEXv',
        Notes => 'val = (raw-64)/8',
        ValueConv => '($val-64)/8',
        ValueConvInv => '$val * 8 + 64',
    },
    4 => {
        Name => 'AEBXv',
        Format => 'int8s',
        Notes => 'val = raw / 8',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
    },
    5 => {
        Name => 'AEMinExposureTime', #19
        Notes => 'val = 24 * 2**((32-raw)/8)',
        ValueConv => '24*exp(-($val-32)*log(2)/8)', #JD
        ValueConvInv => '-log($val/24)*8/log(2)+32',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    6 => {
        Name => 'AEProgramMode',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'M, P or TAv',
            1 => 'Av, B or X',
            2 => 'Tv',
            3 => 'Sv or Green Mode',
            8 => 'Hi-speed Program',
            11 => 'Hi-speed Program (P-Shift)', #19
            16 => 'DOF Program', #19
            19 => 'DOF Program (P-Shift)', #19
            24 => 'MTF Program', #19
            27 => 'MTF Program (P-Shift)', #19
            35 => 'Standard',
            43 => 'Portrait',
            51 => 'Landscape',
            59 => 'Macro',
            67 => 'Sport',
            75 => 'Night Scene Portrait',
            83 => 'No Flash',
            91 => 'Night Scene',
            # 96 - seen for Pentax Q10
            99 => 'Surf & Snow',
            104 => 'Night Snap', # (Q)
            107 => 'Text',
            115 => 'Sunset',
            # 116 - seen for Pentax Q (vivid?)
            123 => 'Kids',
            131 => 'Pet',
            139 => 'Candlelight',
            144 => 'SCN', # (Q)
            160 => 'Program', # (Q)
            # 142 - seen for Pentax Q in Program mode
            147 => 'Museum',
            184 => 'Shallow DOF Program', # (K-5)
            216 => 'HDR', # (Q)
        },
    },
    7 => {
        Name => 'AEFlags',
        Writable => 0,
        Hook => '$size > 20 and $varSize += 1',
        Notes => 'indices after this are incremented by 1 for some models',
        # (this tag can't be unknown because the Hook must be evaluated
        #  to shift the following offsets if necessary.  Instead, ignore
        #  the return value unless Unknown option used)
        RawConv => '$$self{OPTIONS}{Unknown} ? $val : undef',
        PrintConv => { #19
            # (seems to be the warnings displayed in the viewfinder for several bits)
            BITMASK => {
                # 0 - seen in extreme low light conditions (e.g. Lens Cap On)
                # 1 - seen in 2 cases, Aperture Priority mode, Auto ISO at 100,
                #     Shutter speed at 1/4000 and aperture opened wider causing under exposure
                # 2 - only (but not always) set in Shutter Speed Priority (seems to be when over/under exposed).
                #     In one case set when auto exposure compensation changed the Tv from 1/250 to 1/80.
                #     In another case set when external flash was in SB mode so did not fire.
                3 => 'AE lock',
                4 => 'Flash recommended?', # not 100% sure of this one
                # 5 - seen lots...
                # 6 - seen lots...
                7 => 'Aperture wide open', # mostly true...  (Set for all my lenses except for DA* 16-50mm)
            },
        },
    },
    # Note: Offsets below shifted by 1 if record size is > 20 bytes
    # (implemented by the Hook above)
    8 => { #30
        Name => 'AEApertureSteps',
        Notes => q{
            number of steps the aperture has been stopped down from wide open.  There
            are roughly 8 steps per F-stop for most lenses, or 18 steps for 645D lenses,
            but it varies slightly by lens
        },
        PrintConv => '$val == 255 ? "n/a" : $val',
        PrintConvInv => '$val eq "n/a" ? 255 : $val',
    },
    9 => { #19
        Name => 'AEMaxAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    10 => { #19
        Name => 'AEMaxAperture2',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    11 => { #19
        Name => 'AEMinAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    12 => { #19
        Name => 'AEMeteringMode',
        PrintConv => {
            0 => 'Multi-segment',
            BITMASK => {
                4 => 'Center-weighted average',
                5 => 'Spot',
            },
        },
    },
    13 => { #30
        Name => 'AEWhiteBalance',
        Condition => '$$self{AEInfoSize} == 24', # (not thoroughly tested for other sizes)
        Notes => 'K7 and Kx',
        Mask => 0xf0,
        PrintConv => {
            0x00 => 'Standard',
            0x10 => 'Daylight',
            0x20 => 'Shade',
            0x30 => 'Cloudy',
            0x40 => 'Daylight Fluorescent',
            0x50 => 'Day White Fluorescent',
            0x60 => 'White Fluorescent',
            0x70 => 'Tungsten',
        },
    },
    13.1 => { #30
        Name => 'AEMeteringMode2',
        Condition => '$$self{AEInfoSize} == 24', # (not thoroughly tested for other sizes)
        Notes => 'K7 and Kx, override for an incompatable metering mode setting',
        Mask => 0x0f,
        PrintConv => {
            0 => 'Multi-segment',
            BITMASK => {
                0 => 'Center-weighted average',
                1 => 'Spot',
                # 2 - seen for K7 AVI movie
            },
        },
    },
    14 => { #19
        Name => 'FlashExposureCompSet',
        Description => 'Flash Exposure Comp. Setting',
        Format => 'int8s',
        Notes => q{
            reports the camera setting, unlike tag 0x004d which reports 0 in Green mode
            or if flash was on but did not fire.  Both this tag and 0x004d report the
            setting even if the flash is off
        },
        ValueConv => 'Image::ExifTool::Pentax::PentaxEv($val)',
        ValueConvInv => 'Image::ExifTool::Pentax::PentaxEvInv($val)',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    21 => { #30
        Name => 'LevelIndicator',
        PrintConv => '$val == 90 ? "n/a" : $val',
        PrintConvInv => '$val eq "n/a" ? 90 : $val',
    },
);

# auto-exposure information for the K-01 (ref PH)
%Image::ExifTool::Pentax::AEInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Auto-exposure information for the K-01.',
    # instead of /8, should these be PentaxEv(), as in CameraSettings? - PH
    2 => {
        Name => 'AEExposureTime',
        Notes => 'val = 24 * 2**((32-raw)/8)',
        ValueConv => '24*exp(-($val-32)*log(2)/8)',
        ValueConvInv => '-log($val/24)*8/log(2)+32',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    3 => {
        Name => 'AEAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    4 => {
        Name => 'AE_ISO',
        Notes => 'val = 100 * 2**((raw-32)/8)',
        ValueConv => '100*exp(($val-32)*log(2)/8)',
        ValueConvInv => 'log($val/100)*8/log(2)+32',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    5 => {
        Name => 'AEXv',
        # this is the negative of exposure compensation, not including bracketing
        Notes => 'val = (raw-64)/8',
        ValueConv => '($val-64)/8',
        ValueConvInv => '$val * 8 + 64',
    },
    6 => {
        Name => 'AEBXv',
        # this is the negative of auto exposure bracketing compensation
        Format => 'int8s',
        Notes => 'val = raw / 8',
        ValueConv => '$val / 8',
        ValueConvInv => '$val * 8',
    },
    8 => {
        Name => 'AEError',
        Format => 'int8s',
        # this is usually zero except in M exposure mode, but it can be non-zero
        # in other modes (eg. if you hit an aperture limit in Tv mode)
        ValueConv => '-($val-64)/8', # (negate to make overexposed positive)
        ValueConvInv => '-$val * 8 + 64',
    },
    11 => {
        Name => 'AEApertureSteps',
        Notes => q{
            number of steps the aperture has been stopped down from wide open.  There
            are roughly 8 steps per F-stop, but it varies slightly by lens
        },
        PrintConv => '$val == 255 ? "n/a" : $val',
        PrintConvInv => '$val eq "n/a" ? 255 : $val',
    },
    15 => {
        Name => 'SceneMode',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Off',
            1 => 'HDR',
            4 => 'Auto PICT',
            5 => 'Portrait',
            6 => 'Landscape',
            7 => 'Macro',
            8 => 'Sport',
            9 => 'Night Scene Portrait',
            10 => 'No Flash',
            11 => 'Night Scene',
            12 => 'Surf & Snow',
            14 => 'Sunset',
            15 => 'Kids',
            16 => 'Pet',
            17 => 'Candlelight',
            18 => 'Museum',
            20 => 'Food',
            21 => 'Stage Lighting',
            22 => 'Night Snap',
            25 => 'Night Scene HDR',
            26 => 'Blue Sky',
            27 => 'Forest',
            29 => 'Backlight Silhouette',
        },
    },
    16 => {
        Name => 'AEMaxAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    17 => {
        Name => 'AEMaxAperture2',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    18 => {
        Name => 'AEMinAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    19 => {
        Name => 'AEMinExposureTime',
        Notes => 'val = 24 * 2**((32-raw)/8)',
        ValueConv => '24*exp(-($val-32)*log(2)/8)',
        ValueConvInv => '-log($val/24)*8/log(2)+32',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
);

# auto-exposure information for the K-30 (ref PH)
%Image::ExifTool::Pentax::AEInfo3 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Auto-exposure information for the K-3, K-30, K-50 and K-500.',
    # instead of /8, should these be PentaxEv(), as in CameraSettings? - PH
    16 => {
        Name => 'AEExposureTime',
        Notes => 'val = 24 * 2**((32-raw)/8)',
        ValueConv => '24*exp(-($val-32)*log(2)/8)',
        ValueConvInv => '-log($val/24)*8/log(2)+32',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    17 => {
        Name => 'AEAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    18 => {
        Name => 'AE_ISO',
        Notes => 'val = 100 * 2**((raw-32)/8)',
        ValueConv => '100*exp(($val-32)*log(2)/8)',
        ValueConvInv => 'log($val/100)*8/log(2)+32',
        PrintConv => 'int($val + 0.5)',
        PrintConvInv => '$val',
    },
    28 => {
        Name => 'AEMaxAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    29 => {
        Name => 'AEMaxAperture2',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.1f",$val)',
        PrintConvInv => '$val',
    },
    30 => {
        Name => 'AEMinAperture',
        Notes => 'val = 2**((raw-68)/16)',
        ValueConv => 'exp(($val-68)*log(2)/16)',
        ValueConvInv => 'log($val)*16/log(2)+68',
        PrintConv => 'sprintf("%.0f",$val)',
        PrintConvInv => '$val',
    },
    31 => {
        Name => 'AEMinExposureTime',
        Notes => 'val = 24 * 2**((32-raw)/8)',
        ValueConv => '24*exp(-($val-32)*log(2)/8)',
        ValueConvInv => '-log($val/24)*8/log(2)+32',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
);

# unknown auto-exposure information (Q, Q10)
%Image::ExifTool::Pentax::AEInfoUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
);

# lens type
%Image::ExifTool::Pentax::LensRec = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This record stores the LensType, plus one or two unknown bytes for some
        models.
    },
    0 => {
        Name => 'LensType',
        Format => 'int8u[2]',
        Priority => 0,
        ValueConvInv => '$val=~s/\.\d+$//; $val',
        PrintConv => \%pentaxLensTypes,
        SeparateTable => 1,
    },
    # this is a binaryData table because some cameras add an extra
    # byte or two here (typically zeros)...
);

# lens information (ref PH)
%Image::ExifTool::Pentax::LensInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 3 ],
    NOTES => 'Pentax lens information structure for models such as the *istD.',
    0 => {
        Name => 'LensType',
        Format => 'int8u[2]',
        Priority => 0,
        ValueConvInv => '$val=~s/\.\d+$//; $val',
        PrintConv => \%pentaxLensTypes,
        SeparateTable => 1,
    },
    3 => {
        Name => 'LensData',
        Format => 'undef[17]',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensData' },
    },
);

# lens information for newer models (ref PH)
%Image::ExifTool::Pentax::LensInfo2 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 4 ],
    NOTES => 'Pentax lens information structure for models such as the K10D and K20D.',
    0 => {
        Name => 'LensType',
        Format => 'int8u[4]',
        Priority => 0,
        ValueConv => q{
            my @v = split(' ',$val);
            $v[0] &= 0x0f;
            $v[1] = $v[2] * 256 + $v[3]; # (always high byte first)
            return "$v[0] $v[1]";
        },
        # just fill in the missing bits/bytes with zeros...
        ValueConvInv => q{
            my @v = split(' ',$val);
            return undef unless @v == 2;
            $v[2] = ($v[1] >> 8) & 0xff;
            $v[3] = $v[1] & 0xff;
            $v[1] = 0;
            return "@v";
        },
        PrintConv => \%pentaxLensTypes,
        SeparateTable => 1,
    },
    4 => {
        Name => 'LensData',
        Format => 'undef[17]',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensData' },
    },
);

# lens information for 645D (ref PH)
%Image::ExifTool::Pentax::LensInfo3 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 13 ],
    NOTES => 'Pentax lens information structure for 645D.',
    1 => {
        Name => 'LensType',
        Format => 'int8u[4]',
        Priority => 0,
        ValueConv => q{
            my @v = split(' ',$val);
            $v[0] &= 0x0f;
            $v[1] = $v[2] * 256 + $v[3]; # (always high byte first)
            return "$v[0] $v[1]";
        },
        # just fill in the missing bits/bytes with zeros...
        ValueConvInv => q{
            my @v = split(' ',$val);
            return undef unless @v == 2;
            $v[2] = ($v[1] >> 8) & 0xff;
            $v[3] = $v[1] & 0xff;
            $v[1] = 0;
            return "@v";
        },
        PrintConv => \%pentaxLensTypes,
        SeparateTable => 1,
    },
    13 => {
        Name => 'LensData',
        Format => 'undef[17]',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensData' },
    },
);

# lens information for K-5, K-r, etc (ref PH)
%Image::ExifTool::Pentax::LensInfo4 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 12 ],
    NOTES => 'Pentax lens information structure for models such as the K-5 and K-r.',
    1 => {
        Name => 'LensType',
        Format => 'int8u[4]',
        Priority => 0,
        ValueConv => q{
            my @v = split(' ',$val);
            $v[0] &= 0x0f;
            $v[1] = $v[2] * 256 + $v[3]; # (always high byte first)
            return "$v[0] $v[1]";
        },
        # just fill in the missing bits/bytes with zeros...
        ValueConvInv => q{
            my @v = split(' ',$val);
            return undef unless @v == 2;
            $v[2] = ($v[1] >> 8) & 0xff;
            $v[3] = $v[1] & 0xff;
            $v[1] = 0;
            return "@v";
        },
        PrintConv => \%pentaxLensTypes,
        SeparateTable => 1,
    },
    12 => {
        Name => 'LensData',
        Format => 'undef[18]',
        Condition => '$$self{NewLensData} = 1', # not really a condition, just used to set flag
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensData' },
    },
);

# lens information for K-01 (ref PH)
%Image::ExifTool::Pentax::LensInfo5 = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    IS_SUBDIR => [ 15 ],
    NOTES => 'Pentax lens information structure for the K-01 and newer models.',
    1 => {
        Name => 'LensType',
        Format => 'int8u[5]',
        Priority => 0,
        ValueConv => q{
            my @v = split(' ',$val);
            $v[0] &= 0x0f;
            $v[1] = $v[3] * 256 + $v[4]; # (always high byte first)
            return "$v[0] $v[1]";
        },
        # just fill in the missing bits/bytes with zeros...
        ValueConvInv => q{
            my @v = split(' ',$val);
            return undef unless @v == 2;
            $v[3] = ($v[1] >> 8) & 0xff;
            $v[4] = $v[1] & 0xff;
            $v[1] = $v[2] = 0;
            return "@v";
        },
        PrintConv => \%pentaxLensTypes,
        SeparateTable => 1,
    },
    15 => {
        Name => 'LensData',
        Format => 'undef[17]',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::LensData' },
    },
);

# lens data information, including lens codes (ref PH)
%Image::ExifTool::Pentax::LensData = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    DATAMEMBER => [ 12.1 ],
    NOTES => q{
        Pentax lens data information.  Some of these tags require interesting binary
        gymnastics to decode them into useful values.
    },
    # this byte comes from the lens electrical contacts
    # (see http://kmp.bdimitrov.de/technology/K-mount/Ka.html)
    0.1 => { #JD
        Name => 'AutoAperture',
        Condition => 'not $$self{NewLensData}',
        Notes => 'not valid for the K-r, K-5 or K-5II', #29
        Mask => 0x01,
        PrintConv => {
            0 => 'On',
            1 => 'Off',
        },
    },
    0.2 => { #JD
        Name => 'MinAperture',
        Condition => 'not $$self{NewLensData}',
        Notes => 'not valid for the K-r, K-5 or K-5II', #29
        Mask => 0x06,
        PrintConv => {
            0x00 => 22,
            0x02 => 32,
            0x04 => 45,
            0x06 => 16,
        },
    },
    0.3 => { #JD
        Name => 'LensFStops',
        Condition => 'not $$self{NewLensData}',
        Notes => 'not valid for the K-r, K-5 or K-5II', #29
        Mask => 0x70,
        ValueConv => '5 + (($val >> 4) ^ 0x07) / 2',
        ValueConvInv => '((($val - 5) * 2) ^ 0x07) << 4',
    },
    # 1-16 look like Lens Codes LC0-LC15, ref patent 5617173 and 5999753 [+notes by PH]
    1 => { # LC0 = lens kind + version data
        Name => 'LensKind',
        %lensCode,
    },
    2 => { # LC1 = lens data (changes with AF setting)
        Name => 'LC1',
        %lensCode,
    },
    # LC2 = distance data
    3 => { #29
        Name => 'MinFocusDistance',
        Notes => 'minimum focus distance for the lens',
        Mask => 0xf8,
        PrintConv => {
            0x00 => '0.13-0.19 m',  # (plus K or M lenses)
            0x08 => '0.20-0.24 m', 
            0x10 => '0.25-0.28 m',
            0x18 => '0.28-0.30 m',
            0x20 => '0.35-0.38 m',
            0x28 => '0.40-0.45 m',
            0x30 => '0.49-0.50 m',  # (plus many Sigma lenses)
            0x38 => '0.6 m',        #PH (NC)
            0x40 => '0.7 m',        # (plus Sigma 55-200)
            0x48 => '0.8-0.9 m',    #PH (NC) Tokina 28-70/2.6-2.8
            0x50 => '1.0 m',        # (plus Sigma 70 macro)
            0x58 => '1.1-1.2 m',
            0x60 => '1.4-1.5 m',
            0x68 => '1.5 m',        # Sigma 70-300/4-5.6 macro
            0x70 => '2.0 m',
            0x78 => '2.0-2.1 m',    #PH (NC)
            0x80 => '2.1 m',        # Sigma 135-400 APO & DG: 2.0-2.2m
            0x88 => '2.2-2.9 m',    #PH (NC)
            0x90 => '3.0 m',        # Sigma 50-500 : 1.0-3.0m depending on the focal length
                                   ## 50mm, 100mm => 1.0m
                                   ## 200mm       => 1.1m
                                   ## 300mm       => 1.5m
                                   ## 400mm       => 2.2m
                                   ## 500mm       => 3.0m
            0x98 => '4-5 m',        #PH (NC)
            0xa0 => '5.6 m',        # Pentax DA 560
            # To check: Sigma 120-400 OS: MFD 1.5m
            # To check: Sigma 150-500 OS: MFD 2.2m
            # To check: Sigma 50-500 has MFD 50-180cm
            # 0xd0 - seen for the Sigma 4.5mm F2.8 EX DC HSM Circular Fisheye (ref PH)
        },
    },
    3.1 => { #29
        Name => 'FocusRangeIndex',
        Mask => 0x07,
        PrintConv => {
            7 => '0 (very close)',
            6 => '1 (close)',
            4 => '2',
            5 => '3',
            1 => '4',
            0 => '5',
            2 => '6 (far)',
            3 => '7 (very far)',
        },
    },
    4 => { # LC3 = K-value data (AF pulses to displace image by unit length)
        Name => 'LC3',
        %lensCode,
    },
    5 => { # LC4 = abberation correction, near distance data
        Name => 'LC4',
        %lensCode,
    },
    6 => { # LC5 = light color abberation correction data
        Name => 'LC5',
        %lensCode,
    },
    7 => { # LC6 = open abberation data
        Name => 'LC6',
        %lensCode,
    },
    8 => { # LC7 = AF minimum actuation condition
        Name => 'LC7',
        %lensCode,
    },
    9 => { # LC8 = focal length data
        Name => 'FocalLength',
        Priority => 0,
        ValueConv => '10*($val>>2) * 4**(($val&0x03)-2)', #JD
        ValueConvInv => q{
            my $range = int(log($val/10)/(2*log(2)));
            warn("Value out of range") and return undef if $range < 0 or $range > 3;
            return $range + (int($val/(10*4**($range-2))+0.5) << 2);
        },
        PrintConv => 'sprintf("%.1f mm", $val)',
        PrintConvInv => '$val=~s/\s*mm//; $val',
    },
    # the following aperture values change with focal length
    10 => { # LC9 = nominal AVmin/AVmax data (open/closed aperture values)
        Name => 'NominalMaxAperture',
        Mask => 0xf0,
        ValueConv => '2**(($val>>4)/4)', #JD
        ValueConvInv => '4*log($val)/log(2) << 4',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    10.1 => { # LC9 = nominal AVmin/AVmax data (open/closed aperture values)
        Name => 'NominalMinAperture',
        Mask => 0x0f,
        ValueConv => '2**(($val+10)/4)', #JD
        ValueConvInv => '4*log($val)/log(2) - 10',
        PrintConv => 'sprintf("%.0f", $val)',
        PrintConvInv => '$val',
    },
    11 => { # LC10 = mv'/nv' data (full-aperture metering error compensation/marginal lumination compensation)
        Name => 'LC10',
        %lensCode,
    },
    12 => { # LC11 = AVC 1/EXP data
        Name => 'LC11',
        %lensCode,
    },
    12.1 => {
        Name => 'NewLensDataHook',
        Hidden => 1,
        Hook => '$varSize += 1 if $$self{NewLensData}',
        RawConv => 'undef',
    },
    13 => { # LC12 = mv1 AVminsif data
        Name => 'LC12',
        Notes => "ID's 13-16 are offset by 1 for the K-r, K-5 and K-5II", #29
        %lensCode,
    },
    # 14 - related to live view for K-5 (normally 3, but 1 or 5 in LV mode)
    14.1 => { # LC13 = AVmin (open aperture value) [MaxAperture=(2**((AVmin-1)/32))]
        Name => 'MaxAperture',
        Condition => '$$self{Model} ne "K-5"',
        Notes => 'effective wide open aperture for current focal length',
        Mask => 0x7f, # (not sure what the high bit indicates)
        # (a value of 1 seems to indicate 'n/a')
        RawConv => '$val > 1 ? $val : undef',
        ValueConv => '2**(($val-1)/32)',
        ValueConvInv => '32*log($val)/log(2) + 1',
        PrintConv => 'sprintf("%.1f", $val)',
        PrintConvInv => '$val',
    },
    15 => { # LC14 = UNT_12 UNT_6 data
        Name => 'LC14',
        %lensCode,
    },
    16 => { # LC15 = incorporated flash suited END data
        Name => 'LC15',
        %lensCode,
    },
);

# flash information (ref PH)
%Image::ExifTool::Pentax::FlashInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Flash information tags for the K10D, K20D and K200D.',
    0 => {
        Name => 'FlashStatus',
        PrintHex => 1,
        PrintConv => { #19
            0x00 => 'Off',
            0x01 => 'Off (1)', #PH (K-5)
            0x02 => 'External, Did not fire', # 0010
            0x06 => 'External, Fired',        # 0110
            0x08 => 'Internal, Did not fire (0x08)',
            0x09 => 'Internal, Did not fire', # 1001
            0x0d => 'Internal, Fired',        # 1101
        },
    },
    1 => {
        Name => 'InternalFlashMode',
        PrintHex => 1,
        PrintConv => {
            0x00 => 'n/a - Off-Auto-Aperture', #19
            0x86 => 'Fired, Wireless (Control)', #19
            0x95 => 'Fired, Wireless (Master)', #19
            0xc0 => 'Fired', # K10D
            0xc1 => 'Fired, Red-eye reduction', # *istDS2, K10D
            0xc2 => 'Fired, Auto', # K100D, K110D
            0xc3 => 'Fired, Auto, Red-eye reduction', #PH
            0xc6 => 'Fired, Wireless (Control), Fired normally not as control', #19 (Remote 3s)
            0xc8 => 'Fired, Slow-sync', # K10D
            0xc9 => 'Fired, Slow-sync, Red-eye reduction', # K10D
            0xca => 'Fired, Trailing-curtain Sync', # K10D
            0xf0 => 'Did not fire, Normal', #19
            0xf1 => 'Did not fire, Red-eye reduction', #19
            0xf2 => 'Did not fire, Auto', #19
            0xf3 => 'Did not fire, Auto, Red-eye reduction', #19
            0xf4 => 'Did not fire, (Unknown 0xf4)', #19
            0xf5 => 'Did not fire, Wireless (Master)', #19
            0xf6 => 'Did not fire, Wireless (Control)', #19
            0xf8 => 'Did not fire, Slow-sync', #19
            0xf9 => 'Did not fire, Slow-sync, Red-eye reduction', #19
            0xfa => 'Did not fire, Trailing-curtain Sync', #19
        },
    },
    2 => {
        Name => 'ExternalFlashMode',
        PrintHex => 1,
        PrintConv => { #19
            0x00 => 'n/a - Off-Auto-Aperture',
            0x3f => 'Off',
            0x40 => 'On, Auto',
            0xbf => 'On, Flash Problem', #JD
            0xc0 => 'On, Manual',
            0xc4 => 'On, P-TTL Auto',
            0xc5 => 'On, Contrast-control Sync', #JD
            0xc6 => 'On, High-speed Sync',
            0xcc => 'On, Wireless',
            0xcd => 'On, Wireless, High-speed Sync',
            0xf0 => 'Not Connected', #PH (K-5)
        },
    },
    3 => {
        Name => 'InternalFlashStrength',
        Notes => 'saved from the most recent flash picture, on a scale of about 0 to 100',
    },
    4 => 'TTL_DA_AUp',
    5 => 'TTL_DA_ADown',
    6 => 'TTL_DA_BUp',
    7 => 'TTL_DA_BDown',
    24.1 => { #19/17
        Name => 'ExternalFlashGuideNumber',
        Mask => 0x1f,
        Notes => 'val = 2**(raw/16 + 4), with a few exceptions',
        ValueConv => q{
            return 0 unless $val;
            $val = -3 if $val == 29;  # -3 is stored as 0x1d
            return 2**($val/16 + 4);
        },
        ValueConvInv => q{
            return 0 unless $val;
            my $raw = int((log($val)/log(2)-4)*16+0.5);
            $raw = 29 if $raw < 0;   # guide number of 14 gives -3 which is stored as 0x1d
            $raw = 31 if $raw > 31;  # maximum value is 0x1f
            return $raw;
        },
        PrintConv => '$val ? int($val + 0.5) : "n/a"',
        PrintConvInv => '$val=~/^n/ ? 0 : $val',
        # observed values for various flash focal lengths/guide numbers:
        #  AF-540FGZ (ref 19)  AF-360FGZ (ref 17)
        #     6 => 20mm/21       29 => 20mm/14   (wide angle panel used)
        #    16 => 24mm/32        6 => 24mm/21
        #    18 => 28mm/35        7 => 28mm/22
        #    21 => 35mm/39       10 => 35mm/25
        #    24 => 50mm/45       14 => 50mm/30
        #    26 => 70mm/50       17 => 70mm/33
        #    28 => 85mm/54       19 => 85mm/36
        # (I have also seen a value of 31 when both flashes are used together
        # in a wired configuration, but I don't know exactly what this means - PH)
    },
    # 24 - have seen bit 0x80 set when 2 external wired flashes are used - PH
    # 24 - have seen bit 0x40 set when wireless high speed sync is used - ref 19
    25 => { #19
        Name => 'ExternalFlashExposureComp',
        PrintConv => {
            0 => 'n/a', # Off or Auto Modes
            144 => 'n/a (Manual Mode)', # Manual Flash Output
            164 => '-3.0',
            167 => '-2.5',
            168 => '-2.0',
            171 => '-1.5',
            172 => '-1.0',
            175 => '-0.5',
            176 => '0.0',
            179 => '0.5',
            180 => '1.0',
        },
    },
    26 => { #17
        Name => 'ExternalFlashBounce',
        Notes => 'saved from the most recent external flash picture', #19
        PrintConv => {
             0 => 'n/a',
            16 => 'Direct',
            48 => 'Bounce',
        },
    },
    # ? => 'ExternalFlashAOutput',
    # ? => 'ExternalFlashBOutput',
);

%Image::ExifTool::Pentax::FlashInfoUnknown = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # 4 - changes with FEC for K-5 - PH
);

# camera manufacture information (ref PH)
%Image::ExifTool::Pentax::CameraInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int32u',
    0 => {
        Name => 'PentaxModelID',
        Priority => 0, # (Optio SVi uses incorrect Optio SV ID here)
        SeparateTable => 1,
        PrintHex => 1,
        PrintConv => \%pentaxModelID,
    },
    1 => {
        Name => 'ManufactureDate',
        Groups => { 2 => 'Time' },
        Notes => q{
            this value, and the values of the tags below, may change if the camera is
            serviced
        },
        ValueConv => q{
            $val =~ /^(\d{4})(\d{2})(\d{2})$/ and return "$1:$2:$3";
            # Optio A10 and A20 leave "200" off the year
            $val =~ /^(\d)(\d{2})(\d{2})$/ and return "200$1:$2:$3";
            return "Unknown ($val)";
        },
        ValueConvInv => '$val=~tr/0-9//dc; $val',
    },
    2 => {
        #(see http://www.pentaxforums.com/forums/pentax-dslr-discussion/25711-k10d-update-model-revision-8-1-yes-no-8.html)
        Name => 'ProductionCode', #(previously ModelRevision)
        Format => 'int32u[2]',
        Note => 'values of 8.x indicate that the camera has been serviced',
        ValueConv => '$val=~tr/ /./; $val',
        ValueConvInv => '$val=~tr/./ /; $val',
        PrintConv => '$val=~/^8\./ ? "$val (camera has been serviced)" : $val',
        PrintConvInv => '$val=~s/\s+.*//s; $val',
    },
    4 => 'InternalSerialNumber',
);

# battery information (ref PH)
%Image::ExifTool::Pentax::BatteryInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
# size of data:
# 4 (K-m,K2000=4xAA), 6 (*istD,K10D,K100D,K110D=2xCR-V3/4xAA),
# 7 (K20D=D-LI50, K200D=4xAA), 8 (645D=D-LI90), 10 (K-r pre-production?),
# 14 (K-7=D-LI90, K-r=D-LI109/4xAA, K-x=4xAA), 26 (K-5=D-LI90)
# battery grips available for:
# BG1 (*istD), BG2 (K10D/K20D), BG3 (K200D), BG4 (K-7,K-5)
# no grip available: K-x
    0.1 => { #19
        Name => 'PowerSource',
        Mask => 0x0f,
        # have seen the upper bit set (value of 0x82) for the
        # *istDS and K100D, but I'm not sure what this means - PH
        # I've also seen: 0x42 (K2000), 0xf2 (K-7,K-r,K-5), 0x12,0x22 (K-x) - PH
        PrintConv => {
            2 => 'Body Battery',
            3 => 'Grip Battery',
            4 => 'External Power Supply', #PH
        },
    },
    1.1 => [
        {
            Name => 'BodyBatteryState',
            Condition => '$$self{Model} =~ /(\*ist|K100D|K200D|K10D|GX10|K20D|GX20|GX-1[LS]?)\b/',
            Notes => '*istD, K100D, K200D, K10D and K20D',
            Mask => 0xf0,
            PrintConv => { #19
                 0x10 => 'Empty or Missing',
                 0x20 => 'Almost Empty',
                 0x30 => 'Running Low',
                 0x40 => 'Full',
            },
        },{
            Name => 'BodyBatteryState',
            Condition => '$$self{Model} !~ /(K110D|K2000|K-m)\b/',
            Notes => 'other models except the K110D, K2000 and K-m',
            Mask => 0xf0,
            PrintConv => {
                 0x10 => 'Empty or Missing',
                 0x20 => 'Almost Empty',
                 0x30 => 'Running Low',
                 0x40 => 'Close to Full',
                 0x50 => 'Full',
            },
        },{
            Name => 'BodyBatteryState',
            Notes => 'decoding unknown for other models',
            Mask => 0xf0,
            ValueConv => '$val >> 4',
            ValueConvInv => '$val << 4',
        },
    ],
    1.2 => [
        {
            Name => 'GripBatteryState',
            Condition => '$$self{Model} =~ /(K10D|GX10|K20D|GX20)\b/',
            Notes => 'K10D and K20D',
            Mask => 0x0f,
            PrintConv => { #19
                 0x01 => 'Empty or Missing',
                 0x02 => 'Almost Empty',
                 0x03 => 'Running Low',
                 0x04 => 'Full',
            },
        },{
            Name => 'GripBatteryState',
            Notes => 'decoding unknown for other models',
            Unknown => 1, # (doesn't appear to be valid for the K-5)
            Mask => 0x0f,
        },
    ],
    # internal and grip battery voltage Analogue to Digital measurements,
    # open circuit and under load
    2 => [
        {
            Name => 'BodyBatteryADNoLoad',
            Description => 'Body Battery A/D No Load',
            Condition => '$$self{Model} =~ /(K10D|GX10|K20D|GX20)\b/',
            Notes => 'roughly calibrated for K10D with a new Pentax battery',
            # rough linear calibration drops quickly below 30% - PH
            # DVM readings: 8.18V=186, 8.42-8.40V=192 (full), 6.86V=155 (empty)
            PrintConv => 'sprintf("%d (%.1fV, %d%%)",$val,$val*8.18/186,($val-155)*100/35)',
            PrintConvInv => '$val=~s/ .*//; $val',
        },
        {
            Name => 'BodyBatteryADNoLoad',
            Description => 'Body Battery A/D No Load',
            Condition => '$$self{Model} =~ /(\*ist|K100D|K200D|GX-1[LS]?)\b/',
        },
        {
            Name => 'BodyBatteryVoltage1', # (static?)
            Condition => '$$self{Model} !~ /(K100D|K110D|K2000|K-m|Q\d*)\b/',
            Format => 'int16u',
            ValueConv => '$val / 100',
            ValueConvInv => '$val * 100',
            PrintConv => 'sprintf("%.2f V", $val)',
            PrintConvInv => '$val =~ s/\s*V$//',
            # For my K-5:          Min (0%) Max (100%) At Meas
            # BodyBatteryVoltage1  6.24 V   7.75 V     7.66 V
            # BodyBatteryVoltage2  5.98 V   7.43 V     7.34 V
            # BodyBatteryVoltage3  6.41 V   7.93 V     7.84 V
            # BodyBatteryVoltage4  6.10 V   7.55 V     7.45 V
            # "Meas" open-circuit voltages with DVM: AB=0V, AC=+8.33V, BC=+8.22V
            # (terminal "C" is closest to edge of battery)
        },
    ],
    3 => [
        {
            Name => 'BodyBatteryADLoad',
            Description => 'Body Battery A/D Load',
            Condition => '$$self{Model} =~ /(K10D|GX10|K20D|GX20)\b/',
            Notes => 'roughly calibrated for K10D with a new Pentax battery',
            # [have seen 187] - PH
            PrintConv => 'sprintf("%d (%.1fV, %d%%)",$val,$val*8.18/186,($val-152)*100/34)',
            PrintConvInv => '$val=~s/ .*//; $val',
        },
        {
            Name => 'BodyBatteryADLoad',
            Description => 'Body Battery A/D Load',
            Condition => '$$self{Model} =~ /(\*ist|K100D|K200D)\b/',
        },
    ],
    4 => [
        {
            Name => 'GripBatteryADNoLoad',
            Description => 'Grip Battery A/D No Load',
            Condition => '$$self{Model} =~ /(\*ist|K10D|GX10|K20D|GX20|GX-1[LS]?)\b/',
        },
        {
            Name => 'BodyBatteryVoltage2', # (less than BodyBatteryVoltage1 -- under load?)
            Condition => '$$self{Model} !~ /(K100D|K110D|K2000|K-m|Q\d*)\b/',
            Format => 'int16u',
            ValueConv => '$val / 100',
            ValueConvInv => '$val * 100',
            PrintConv => 'sprintf("%.2f V", $val)',
            PrintConvInv => '$val =~ s/\s*V$//',
        },
    ],
    5 => {
        Name => 'GripBatteryADLoad',
        Condition => '$$self{Model} =~ /(\*ist|K10D|GX10|K20D|GX20)\b/',
        Description => 'Grip Battery A/D Load',
    },
    6 => {
        Name => 'BodyBatteryVoltage3', # (greater than BodyBatteryVoltage1)
        Condition => '$$self{Model} =~ /(K-5|K-r|645D)\b/',
        Format => 'int16u',
        Notes => 'K-5, K-r and 645D only',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f V", $val)',
        PrintConvInv => '$val =~ s/\s*V$//',
    },
    8 => {
        Name => 'BodyBatteryVoltage4', # (between BodyBatteryVoltage1 and BodyBatteryVoltage2)
        Condition => '$$self{Model} =~ /(K-5|K-r)\b/',
        Format => 'int16u',
        Notes => 'K-5 and K-r only',
        ValueConv => '$val / 100',
        ValueConvInv => '$val * 100',
        PrintConv => 'sprintf("%.2f V", $val)',
        PrintConvInv => '$val =~ s/\s*V$//',
    },
);

# auto focus information
%Image::ExifTool::Pentax::AFInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # AF Info tag names in K10D debugging output - PH:
    # SelectArea, InFocusArea, Predictor, Defocus, IntegTime2msStep,
    # CalFlag, ContrastFlag, PrecalFlag, SelectSensor
    0x00 => { #PH
        Name => 'AFPointsUnknown1',
        Unknown => 1,
        Format => 'int16u',
        ValueConv => '$self->Options("Unknown") ? $val : $val & 0x7ff',
        ValueConvInv => '$val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => '(none)',
            0x07ff => 'All',
            0x0777 => 'Central 9 points',
            BITMASK => {
                0 => 'Upper-left',
                1 => 'Top',
                2 => 'Upper-right',
                3 => 'Left',
                4 => 'Mid-left',
                5 => 'Center',
                6 => 'Mid-right',
                7 => 'Right',
                8 => 'Lower-left',
                9 => 'Bottom',
                10 => 'Lower-right',
                # (bits 12-15 are flags of some sort)
            },
        },
    },
    0x02 => { #PH
        Name => 'AFPointsUnknown2',
        Unknown => 1,
        Format => 'int16u',
        ValueConv => '$self->Options("Unknown") ? $val : $val & 0x7ff',
        ValueConvInv => '$val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Auto',
            BITMASK => {
                0 => 'Upper-left',
                1 => 'Top',
                2 => 'Upper-right',
                3 => 'Left',
                4 => 'Mid-left',
                5 => 'Center',
                6 => 'Mid-right',
                7 => 'Right',
                8 => 'Lower-left',
                9 => 'Bottom',
                10 => 'Lower-right',
                # (bits 12-15 are flags of some sort)
                # bit 15 is set for center focus point only if it is vertical
            },
        },
    },
    0x04 => { #PH (educated guess - predicted amount to drive lens)
        Name => 'AFPredictor',
        Format => 'int16s',
    },
    0x06 => 'AFDefocus', #PH (educated guess - calculated distance from focused)
    0x07 => { #PH
        # effective exposure time for AF sensors in 2 ms increments
        Name => 'AFIntegrationTime',
        Notes => 'times less than 2 ms give a value of 0',
        ValueConv => '$val * 2',
        ValueConvInv => 'int($val / 2)', # (don't round up)
        PrintConv => '"$val ms"',
        PrintConvInv => '$val=~tr/0-9//dc; $val',
    },
    # 0x0a - values: 00,05,0d,15,86,8e,a6,ae
    0x0b => { #JD
        Name => 'AFPointsInFocus',
        Condition => '$$self{Model} !~ /K-3\b/',
        Notes => q{
            models other than the K-3 only.  May report two points in focus even though
            a single AFPoint has been selected, in which case the selected AFPoint is
            the first reported
        },
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'None',
            1 => 'Lower-left, Bottom',
            2 => 'Bottom',
            3 => 'Lower-right, Bottom',
            4 => 'Mid-left, Center',
            5 => 'Center (horizontal)', #PH
            6 => 'Mid-right, Center',
            7 => 'Upper-left, Top',
            8 => 'Top',
            9 => 'Upper-right, Top',
            10 => 'Right',
            11 => 'Lower-left, Mid-left',
            12 => 'Upper-left, Mid-left',
            13 => 'Bottom, Center',
            14 => 'Top, Center',
            15 => 'Lower-right, Mid-right',
            16 => 'Upper-right, Mid-right',
            17 => 'Left',
            18 => 'Mid-left',
            19 => 'Center (vertical)', #PH
            20 => 'Mid-right',
        },
    },
);

# Kelvin white balance information (ref 28, topic 4834)
%Image::ExifTool::Pentax::KelvinWB = (
    %binaryDataAttrs,
    FORMAT => 'int16u',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'White balance Blue/Red gains as a function of color temperature.',
    1  => { Name => 'KelvinWB_Daylight', %kelvinWB },
    5  => { Name => 'KelvinWB_01', %kelvinWB },
    9  => { Name => 'KelvinWB_02', %kelvinWB },
    13 => { Name => 'KelvinWB_03', %kelvinWB },
    17 => { Name => 'KelvinWB_04', %kelvinWB },
    21 => { Name => 'KelvinWB_05', %kelvinWB },
    25 => { Name => 'KelvinWB_06', %kelvinWB },
    29 => { Name => 'KelvinWB_07', %kelvinWB },
    33 => { Name => 'KelvinWB_08', %kelvinWB },
    37 => { Name => 'KelvinWB_09', %kelvinWB },
    41 => { Name => 'KelvinWB_10', %kelvinWB },
    45 => { Name => 'KelvinWB_11', %kelvinWB },
    49 => { Name => 'KelvinWB_12', %kelvinWB },
    53 => { Name => 'KelvinWB_13', %kelvinWB },
    57 => { Name => 'KelvinWB_14', %kelvinWB },
    61 => { Name => 'KelvinWB_15', %kelvinWB },
    65 => { Name => 'KelvinWB_16', %kelvinWB },
);

# color information - PH
%Image::ExifTool::Pentax::ColorInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int8s',
    16 => {
        Name => 'WBShiftAB',
        Notes => 'positive is a shift toward blue',
    },
    17 => {
        Name => 'WBShiftGM',
        Notes => 'positive is a shift toward green',
    },
);

# EV step size information - ref 19
%Image::ExifTool::Pentax::EVStepInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'EVSteps',
        PrintConv => {
            0 => '1/2 EV Steps',
            1 => '1/3 EV Steps',
        },
    },
    1 => {
        Name => 'SensitivitySteps',
        PrintConv => {
            0 => '1 EV Steps',
            1 => 'As EV Steps',
        },
    },
);

# shot information? - ref PH (K-5)
%Image::ExifTool::Pentax::ShotInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # 0: 0xf2/0xf3 (HDR), 0xf0 (otherwise)
    1 => { # (presumably this is from an orientation sensor)
        Name => 'CameraOrientation',
        Condition => '$$self{Model} =~ /K-(5|7|r|x)\b/',
        Notes => 'K-5, K-7, K-r and K-x',
        PrintHex => 1,
        PrintConv => {
            0x10 => 'Horizontal (normal)',
            0x20 => 'Rotate 180',
            0x30 => 'Rotate 90 CW',
            0x40 => 'Rotate 270 CW',
            0x50 => 'Upwards', # (to the sky)
            0x60 => 'Downwards', # (to the ground)
        },
    },
    # 2: 0xd3 (live view), 0xdb (HDR), 0x7b (otherwise)
    # 3: 0xff
    # 4: 0x64, 0x6a, 0x6f, 0xa4, 0xaa, 0xab, 0xbf
    # 5: 0xfe
    # 6: 0x0e
    # 7: 0x02 (live view), 0x06 (otherwise)
    # 8-10: 0x00
);

# face detect positions - ref PH (Optio RZ10)
%Image::ExifTool::Pentax::FacePos = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int16u',
    0 => {
        Name => 'Face1Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
        Notes => 'X/Y coordinates of face center in full-sized image',
    },
    2 => {
        Name => 'Face2Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    4 => {
        Name => 'Face3Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    6 => {
        Name => 'Face4Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    8 => {
        Name => 'Face5Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    10 => {
        Name => 'Face6Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    12 => {
        Name => 'Face7Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    14 => {
        Name => 'Face8Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
    16 => {
        Name => 'Face9Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 9 ? undef : $val',
    },
    18 => {
        Name => 'Face10Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 10 ? undef : $val',
    },
    20 => {
        Name => 'Face11Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 11 ? undef : $val',
    },
    22 => {
        Name => 'Face12Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 12 ? undef : $val',
    },
    24 => {
        Name => 'Face13Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 13 ? undef : $val',
    },
    26 => {
        Name => 'Face14Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 14 ? undef : $val',
    },
    28 => {
        Name => 'Face15Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 15 ? undef : $val',
    },
    30 => {
        Name => 'Face16Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 16 ? undef : $val',
    },
    32 => {
        Name => 'Face17Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 17 ? undef : $val',
    },
    34 => {
        Name => 'Face18Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 18 ? undef : $val',
    },
    36 => {
        Name => 'Face19Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 19 ? undef : $val',
    },
    38 => {
        Name => 'Face20Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 20 ? undef : $val',
    },
    40 => {
        Name => 'Face21Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 21 ? undef : $val',
    },
    42 => {
        Name => 'Face22Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 22 ? undef : $val',
    },
    44 => {
        Name => 'Face23Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 23 ? undef : $val',
    },
    46 => {
        Name => 'Face24Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 24 ? undef : $val',
    },
    48 => {
        Name => 'Face25Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 25 ? undef : $val',
    },
    50 => {
        Name => 'Face26Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 26 ? undef : $val',
    },
    52 => {
        Name => 'Face27Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 27 ? undef : $val',
    },
    54 => {
        Name => 'Face28Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 28 ? undef : $val',
    },
    56 => {
        Name => 'Face29Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 29 ? undef : $val',
    },
    58 => {
        Name => 'Face30Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 30 ? undef : $val',
    },
    60 => {
        Name => 'Face31Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 31 ? undef : $val',
    },
    62 => {
        Name => 'Face32Position',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 32 ? undef : $val',
    },
);

# face detect sizes - ref PH (Optio RZ10)
%Image::ExifTool::Pentax::FaceSize = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int16u',
    0 => {
        Name => 'Face1Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 1 ? undef : $val',
    },
    2 => {
        Name => 'Face2Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 2 ? undef : $val',
    },
    4 => {
        Name => 'Face3Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 3 ? undef : $val',
    },
    6 => {
        Name => 'Face4Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 4 ? undef : $val',
    },
    8 => {
        Name => 'Face5Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 5 ? undef : $val',
    },
    10 => {
        Name => 'Face6Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 6 ? undef : $val',
    },
    12 => {
        Name => 'Face7Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 7 ? undef : $val',
    },
    14 => {
        Name => 'Face8Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 8 ? undef : $val',
    },
    16 => {
        Name => 'Face9Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 9 ? undef : $val',
    },
    18 => {
        Name => 'Face10Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 10 ? undef : $val',
    },
    20 => {
        Name => 'Face11Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 11 ? undef : $val',
    },
    22 => {
        Name => 'Face12Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 12 ? undef : $val',
    },
    24 => {
        Name => 'Face13Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 13 ? undef : $val',
    },
    26 => {
        Name => 'Face14Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 14 ? undef : $val',
    },
    28 => {
        Name => 'Face15Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 15 ? undef : $val',
    },
    30 => {
        Name => 'Face16Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 16 ? undef : $val',
    },
    32 => {
        Name => 'Face17Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 17 ? undef : $val',
    },
    34 => {
        Name => 'Face18Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 18 ? undef : $val',
    },
    36 => {
        Name => 'Face19Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 19 ? undef : $val',
    },
    38 => {
        Name => 'Face20Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 20 ? undef : $val',
    },
    40 => {
        Name => 'Face21Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 21 ? undef : $val',
    },
    42 => {
        Name => 'Face22Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 22 ? undef : $val',
    },
    44 => {
        Name => 'Face23Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 23 ? undef : $val',
    },
    46 => {
        Name => 'Face24Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 24 ? undef : $val',
    },
    48 => {
        Name => 'Face25Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 25 ? undef : $val',
    },
    50 => {
        Name => 'Face26Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 26 ? undef : $val',
    },
    52 => {
        Name => 'Face27Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 27 ? undef : $val',
    },
    54 => {
        Name => 'Face28Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 28 ? undef : $val',
    },
    56 => {
        Name => 'Face29Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 29 ? undef : $val',
    },
    58 => {
        Name => 'Face30Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 30 ? undef : $val',
    },
    60 => {
        Name => 'Face31Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 31 ? undef : $val',
    },
    62 => {
        Name => 'Face32Size',
        Format => 'int16u[2]',
        RawConv => '$$self{FacesDetected} < 32 ? undef : $val',
    },
);

# digital filter information - ref PH (K-5)
%Image::ExifTool::Pentax::FilterInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FORMAT => 'int8u',
    NOTES => q{
        The parameters associated with each type of digital filter are unique, and
        these settings are also extracted with the DigitalFilter tag.  Information
        is not extracted for filters that are "Off" unless the Unknown option is
        used.
    },
    0 => {
        Name => 'SourceDirectoryIndex',
        Format => 'int16u',
    },
    2 => {
        Name => 'SourceFileIndex',
        Format => 'int16u',
    },
    0x005 => { Name => 'DigitalFilter01', %digitalFilter },
    0x016 => { Name => 'DigitalFilter02', %digitalFilter },
    0x027 => { Name => 'DigitalFilter03', %digitalFilter },
    0x038 => { Name => 'DigitalFilter04', %digitalFilter },
    0x049 => { Name => 'DigitalFilter05', %digitalFilter },
    0x05a => { Name => 'DigitalFilter06', %digitalFilter },
    0x06b => { Name => 'DigitalFilter07', %digitalFilter },
    0x07c => { Name => 'DigitalFilter08', %digitalFilter },
    0x08d => { Name => 'DigitalFilter09', %digitalFilter },
    0x09e => { Name => 'DigitalFilter10', %digitalFilter },
    0x0af => { Name => 'DigitalFilter11', %digitalFilter },
    0x0c0 => { Name => 'DigitalFilter12', %digitalFilter },
    0x0d1 => { Name => 'DigitalFilter13', %digitalFilter },
    0x0e2 => { Name => 'DigitalFilter14', %digitalFilter },
    0x0f3 => { Name => 'DigitalFilter15', %digitalFilter },
    0x104 => { Name => 'DigitalFilter16', %digitalFilter },
    0x115 => { Name => 'DigitalFilter17', %digitalFilter },
    0x126 => { Name => 'DigitalFilter18', %digitalFilter },
    0x137 => { Name => 'DigitalFilter19', %digitalFilter },
    0x148 => { Name => 'DigitalFilter20', %digitalFilter },
);

# electronic level information - ref PH (K-5)
%Image::ExifTool::Pentax::LevelInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FORMAT => 'int8s',
    NOTES => q{
        Tags decoded from the electronic level information for the K-5.  May not be
        valid for other models.
    },
    0 => {
        Name => 'LevelOrientation',
        Mask => 0x0f,
        PrintHex => 0,
        PrintConv => {
            1 => 'Horizontal (normal)',
            2 => 'Rotate 180',
            3 => 'Rotate 90 CW',
            4 => 'Rotate 270 CW',
            9 => 'Horizontal; Off Level',
            10 => 'Rotate 180; Off Level',
            11 => 'Rotate 90 CW; Off Level',
            12 => 'Rotate 270 CW; Off Level',
            13 => 'Upwards',
            14 => 'Downwards',
        },
    },
    0.1 => {
        Name => 'CompositionAdjust',
        Mask => 0xf0,
        PrintConv => {
            0x00 => 'Off',
            0x20 => 'Composition Adjust',
            0xa0 => 'Composition Adjust + Horizon Correction',
            0xc0 => 'Horizon Correction',
        },
    },
    1 => {
        Name => 'RollAngle',
        Notes => 'converted to degrees of clockwise camera rotation',
        ValueConv => '-$val / 2',
        ValueConvInv => '-$val * 2',
    },
    2 => {
        Name => 'PitchAngle',
        Notes => 'converted to degrees of upward camera tilt',
        ValueConv => '-$val / 2',
        ValueConvInv => '-$val * 2',
    },
    # 3,4 - related somehow to horizon correction and composition adjust
    # 5,6,7 - (the notes below refer to how the image moves in the LCD monitor)
    5 => {
        Name => 'CompositionAdjustX',
        Notes => 'steps to the right, 1/16 mm per step',
        ValueConv => '-$val',
        ValueConvInv => '-$val',
    },
    6 => {
        Name => 'CompositionAdjustY',
        Notes => 'steps up, 1/16 mm per step',
        ValueConv => '-$val',
        ValueConvInv => '-$val',
    },
    7 => {
        Name => 'CompositionAdjustRotation',
        Notes => 'steps clockwise, 1/8 degree per step',
        ValueConv => '-$val / 2',
        ValueConvInv => '-$val * 2',
    },
);

# white balance RGGB levels (ref 28)
%Image::ExifTool::Pentax::WBLevels = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # 0 - 11 (number of entries in this table)
    # 1 - 0
    2 => {
        Name => 'WB_RGGBLevelsDaylight',
        Format => 'int16u[4]',
    },
    # 10 - 1
    11 => {
        Name => 'WB_RGGBLevelsShade',
        Format => 'int16u[4]',
    },
    # 19 - 2
    20 => {
        Name => 'WB_RGGBLevelsCloudy',
        Format => 'int16u[4]',
    },
    # 28 - 3
    29 => {
        Name => 'WB_RGGBLevelsTungsten',
        Format => 'int16u[4]',
    },
    # 37 - 4
    38 => {
        Name => 'WB_RGGBLevelsFluorescentD',
        Format => 'int16u[4]',
    },
    # 46 - 5
    47 => {
        Name => 'WB_RGGBLevelsFluorescentN',
        Format => 'int16u[4]',
    },
    # 55 - 6
    56 => {
        Name => 'WB_RGGBLevelsFluorescentW',
        Format => 'int16u[4]',
    },
    # 64 - 7
    65 => {
        Name => 'WB_RGGBLevelsFlash',
        Format => 'int16u[4]',
    },
    # 73 - 8
    74 => {
        Name => 'WB_RGGBLevelsFluorescentL',
        Format => 'int16u[4]',
    },
    # 82 - 0xfe
    83 => {
        Name => 'WB_RGGBLevelsUnknown',
        Format => 'int16u[4]',
        Unknown => 1,
    },
    # 91 - 0xff
    92 => {
        Name => 'WB_RGGBLevelsUserSelected',
        Format => 'int16u[4]',
    },
);

# lens information for Penax Q (ref PH)
# (306 bytes long, I wonder if this contains vignetting information too?)
%Image::ExifTool::Pentax::LensInfoQ = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'More lens information stored by the Pentax Q.',
    0x0c => {
        Name => 'LensModel',
        Format => 'string[30]',
    },
    0x2a => {
        Name => 'LensInfo',
        Format => 'string[20]',
        ValueConv => '$val=~s/mm/mm /; $val',
        ValueConvInv => '$val=~tr/ //d; $val',
    }
);

# temperature information for some models - PH
%Image::ExifTool::Pentax::TempInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        A number of additional temperature readings are extracted from this 256-byte
        binary-data block in images from models such as the K-01, K-3, K-5, K-50 and
        K-500.  It is currently not known where the corresponding temperature
        sensors are located in the camera.
    },
    # (it would be nice to know where these temperature sensors are located,
    #  but since according to the manual the Slow Shutter Speed NR Auto mode
    #  is based on "internal temperature", my guess is that there must be
    #  at least one on the sensor itself.  These temperatures seem to rise
    #  more quickly than CameraTemperature when shooting video.)
    0x0c => {
        Name => 'CameraTemperature2',
        Format => 'int16s',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f C", $val)',
        PrintConvInv => '$val=~s/ ?c$//i; $val',
    },
    0x0e => {
        Name => 'CameraTemperature3',
        Format => 'int16s',
        ValueConv => '$val / 10',
        ValueConvInv => '$val * 10',
        PrintConv => 'sprintf("%.1f C", $val)',
        PrintConvInv => '$val=~s/ ?c$//i; $val',
    },
    0x14 => {
        Name => 'CameraTemperature4',
        Condition => '$$self{Model} =~ /K-5\b/',
        Format => 'int16s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?c$//i; $val',
    },
    0x16 => { # usually the same as CameraTemperature4, but not always
        Name => 'CameraTemperature5',
        Condition => '$$self{Model} =~ /K-5\b/',
        Format => 'int16s',
        PrintConv => '"$val C"',
        PrintConvInv => '$val=~s/ ?c$//i; $val',
    },
    # 0x18,0x1a,0x1c,0x1e = int16u[4] BlackPoint - PH
);

# currently unknown info
%Image::ExifTool::Pentax::UnknownInfo = (
    %binaryDataAttrs,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    # K10D: first 8 bytes seem to be short integers which change with ISO (value
    # is usually close to ISO/100) possibly smoothing or gain parameters? - PH
    # byte 0-1 - Higher for high color temperatures (red boost or red noise suppression?)
    # byte 6-7 - Higher for low color temperatures (blue boost or blue noise suppression?)
    # also changing are bytes 10,11,14,15
);

# Pentax type 2 (Casio-like) maker notes (ref 1)
%Image::ExifTool::Pentax::Type2 = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 'int16u',
    NOTES => q{
        These tags are used by the Pentax Optio 330 and 430, and are similar to the
        tags used by Casio.
    },
    0x0001 => {
        Name => 'RecordingMode',
        PrintConv => {
            0 => 'Auto',
            1 => 'Night Scene',
            2 => 'Manual',
        },
    },
    0x0002 => {
        Name => 'Quality',
        PrintConv => {
            0 => 'Good',
            1 => 'Better',
            2 => 'Best',
        },
    },
    0x0003 => {
        Name => 'FocusMode',
        PrintConv => {
            2 => 'Custom',
            3 => 'Auto',
        },
    },
    0x0004 => {
        Name => 'FlashMode',
        PrintConv => {
            1 => 'Auto',
            2 => 'On',
            4 => 'Off',
            6 => 'Red-eye reduction',
        },
    },
    # Casio 0x0005 is FlashIntensity
    # Casio 0x0006 is ObjectDistance
    0x0007 => {
        Name => 'WhiteBalance',
        PrintConv => {
            0 => 'Auto',
            1 => 'Daylight',
            2 => 'Shade',
            3 => 'Tungsten',
            4 => 'Fluorescent',
            5 => 'Manual',
        },
    },
    0x000a => {
        Name => 'DigitalZoom',
        Writable => 'int32u',
    },
    0x000b => {
        Name => 'Sharpness',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
        },
    },
    0x000c => {
        Name => 'Contrast',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x000d => {
        Name => 'Saturation',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
    },
    0x0014 => {
        Name => 'ISO',
        Priority => 0,
        PrintConv => {
            10 => 100,
            16 => 200,
            50 => 50, #PH
            100 => 100, #PH
            200 => 200, #PH
            400 => 400, #PH
            800 => 800, #PH
            1600 => 1600, #PH
            3200 => 3200, #PH
            # seen 65534 for Q-S1 MOV video - PH
            # seen 65535 for K-S1 MOV video - PH
        },
    },
    0x0017 => {
        Name => 'ColorFilter',
        PrintConv => {
            1 => 'Full',
            2 => 'Black & White',
            3 => 'Sepia',
        },
    },
    # Casio 0x0018 is AFPoint
    # Casio 0x0019 is FlashIntensity
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        Writable => 0,
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
    0x1000 => {
        Name => 'HometownCityCode',
        Writable => 'undef',
        Count => 4,
    },
    0x1001 => { #PH
        Name => 'DestinationCityCode',
        Writable => 'undef',
        Count => 4,
    },
);

# ASCII-based maker notes of Optio E20 and E25 - PH
%Image::ExifTool::Pentax::Type4 = (
    PROCESS_PROC => \&Image::ExifTool::HP::ProcessHP,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        The following few tags are extracted from the wealth of information
        available in maker notes of the Optio E20 and E25.  These maker notes are
        stored as ASCII text in a format very similar to some HP models.
    },
   'F/W Version' => 'FirmwareVersion',
);

# tags in Pentax QuickTime videos (PH - tests with Optio WP)
# (similar information in Kodak,Minolta,Nikon,Olympus,Pentax and Sanyo videos)
%Image::ExifTool::Pentax::MOV = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => 'This information is found in MOV videos from cameras such as the Optio WP.',
    0x00 => {
        Name => 'Make',
        Format => 'string[24]',
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
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
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
        Name => 'ISO',
        Format => 'int16u',
    },
);

# Pentax metadata in AVI videos (PH)
%Image::ExifTool::Pentax::AVI = (
    NOTES => 'Pentax-specific RIFF tags found in AVI videos.',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Video' },
    hymn => {
        Name => 'MakerNotes',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::Main',
            Start => 10,
            Base => '$start',
            ByteOrder => 'BigEndian',
        },
    },
);

# Pentax metadata in S1 AVI maker notes (PH)
%Image::ExifTool::Pentax::S1 = (
    NOTES => 'Tags extracted from the maker notes of AVI videos from the Optio S1.',
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0000 => { #5
        Name => 'MakerNoteVersion',
        Writable => 'undef',
        Count => 4,
    },
);

# Pentax metadata in AVI videos from the RS1000 (PH)
%Image::ExifTool::Pentax::Junk = (
    NOTES => 'Tags found in the JUNK chunk of AVI videos from the RS1000.',
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x0c => {
        Name => 'Model',
        Format => 'string[32]',
    },
);

# PreviewImage information found in PXTH atom of K-01 MOV videos
%Image::ExifTool::Pentax::PXTH = (
    NOTES => 'Tags found in the PXTH atom of MOV videos from the K-01.',
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0x00 => {
        Name => 'PreviewImageLength',
        Format => 'int32u',
    },
    0x04 => {
        Name => 'PreviewImage',
        Format => 'undef[$val{0}]',
        Notes => '640-pixel-wide JPEG preview', # (360 pixels high, may depend on aspect ratio)
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# information in PENT atom of MOV videos from the Optio WG-2 GPS
%Image::ExifTool::Pentax::PENT = (
    NOTES => 'Tags found in the PENT atom of MOV videos from the Optio WG-2 GPS.',
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    0 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x1a => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
    },
    0x38 => { # (NC)
        Name => 'ExposureTime',
        Format => 'int32u',
        ValueConv => '$val ? 10 / $val : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x3c => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
    },
    0x44 => { # (NC)
        Name => 'ExposureCompensation',
        Format => 'rational64s',
        PrintConv => '$val ? sprintf("%+.1f", $val) : 0',
    },
    0x54 => { # (NC)
        Name => 'FocalLength',
        Format => 'int32u',
        PrintConv => '"$val mm"',
    },
    0x71 => {
        Name => 'DateTime1',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0x8b => {
        Name => 'DateTime2',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
    },
    0xa7 => { # (NC)
        Name => 'ISO',
        Format => 'int32u',
    },
    0xc7 => {
        Name => 'GPSVersionID',
        Format => 'undef[8]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        DataMember => 'GPSVersionID',
        RawConv => '$$self{GPSVersionID} = ($val=~s/GPS_// ? join(" ",unpack("C*",$val)) : undef)',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    0xcf => {
        Name => 'GPSLatitudeRef',
        Condition => '$$self{GPSVersionID} and require Image::ExifTool::GPS',
        Format => 'string[2]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            N => 'North',
            S => 'South',
        },
    },
    0xd1 => {
        Name => 'GPSLatitude',
        Condition => '$$self{GPSVersionID}',
        Format => 'rational64u[3]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    0xe9 => {
        Name => 'GPSLongitudeRef',
        Condition => '$$self{GPSVersionID}',
        Format => 'string[2]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            E => 'East',
            W => 'West',
        },
    },
    0xeb => {
        Name => 'GPSLongitude',
        Condition => '$$self{GPSVersionID}',
        Format => 'rational64u[3]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val)',
        PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1)',
    },
    0x103 => {
        Name => 'GPSAltitudeRef',
        Condition => '$$self{GPSVersionID}',
        Format => 'int8u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    0x104 => {
        Name => 'GPSAltitude',
        Condition => '$$self{GPSVersionID}',
        Format => 'rational64u',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => '$val =~ /^(inf|undef)$/ ? $val : "$val m"',
    },
    0x11c => {
        Name => 'GPSTimeStamp',
        Condition => '$$self{GPSVersionID}',
        Groups => { 1 => 'GPS', 2 => 'Time' },
        Format => 'rational64u[3]',
        ValueConv => 'Image::ExifTool::GPS::ConvertTimeStamp($val)',
        PrintConv => 'Image::ExifTool::GPS::PrintTimeStamp($val)',
    },
    0x134 => {
        Name => 'GPSSatellites',
        Condition => '$$self{GPSVersionID}',
        Format => 'string[3]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0x137 => {
        Name => 'GPSStatus',
        Condition => '$$self{GPSVersionID}',
        Format => 'string[2]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            A => 'Measurement Active',
            V => 'Measurement Void',
        },
    },
    0x139 => {
        Name => 'GPSMeasureMode',
        Condition => '$$self{GPSVersionID}',
        Format => 'string[2]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    0x13b => {
        Name => 'GPSMapDatum',
        Condition => '$$self{GPSVersionID}',
        Format => 'string[7]',
        Groups => { 1 => 'GPS', 2 => 'Location' },
    },
    0x142 => {
        Name => 'GPSDateStamp',
        Condition => '$$self{GPSVersionID}',
        Groups => { 1 => 'GPS', 2 => 'Time' },
        Format => 'string[11]',
        ValueConv => 'Image::ExifTool::Exif::ExifDate($val)',
    },
    0x173 => { # (NC)
        Name => 'AudioCodecID',
        Format => 'string[4]',
    },
    0x7d3 => {
        Name => 'PreviewImage',
        Format => 'undef[$size-0x7d3]',
        Notes => '640x480 JPEG preview image', # (black borders pad to 480 pixels high)
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

# tags in Pentax Optio RZ18 AVI videos (ref PH)
# (very similar to Olympus::AVI tags)
%Image::ExifTool::Pentax::Junk2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    NOTES => 'This information is found in AVI videos from the Optio RZ18.',
    0x12 => {
        Name => 'Make',
        Format => 'string[24]',
    },
    0x2c => {
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string[24]',
    },
    0x5e => {
        Name => 'FNumber',
        Format => 'rational64u',
        PrintConv => 'sprintf("%.1f",$val)',
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
    0x12b => {
        Name => 'ThumbnailWidth',
        Format => 'int16u',
    },
    0x12d => {
        Name => 'ThumbnailHeight',
        Format => 'int16u',
    },
    0x12f => {
        Name => 'ThumbnailLength',
        Format => 'int32u',
    },
    0x133 => {
        Name => 'ThumbnailImage',
        Format => 'undef[$val{0x12f}]',
        Notes => '160x120 JPEG thumbnail image',
        RawConv => '$self->ValidateImage(\$val,$tag)',
    },
);

#------------------------------------------------------------------------------
# Convert filter settings (ref PH, K-5)
# Inputs: 0) value to convert, 1) flag for inverse conversion, 2) lookup table
# Returns: converted value
sub PrintFilter($$$)
{
    my ($val, $inv, $conv) = @_;
    my (@vals, @cval, $t, $v);

    if (not $inv) {
        # forward conversion (reading):
        @vals = split ' ',$val;
        $t = shift @vals;
        push @cval, $$conv{$t} || "Unknown ($t)";
        while (@vals) {
            $t = shift @vals;
            $v = shift @vals;
            next unless $t;
            last unless defined $v;
            my $c = $filterSettings{$t};
            if ($c) {
                my $c1 = $$c[1];
                if (ref $c1) {
                    $v = $$c1{$v} || "Unknown($v)";
                } elsif ($v) {
                    $v = sprintf $c1, $v;
                }
                push @cval, "$$c[0]=$v";
            } else {
                push @cval, "Unknown($t)=$v";
            }
        }
        return @cval ? \@cval : undef;
    } else {
        # reverse conversion (writing):
        @vals = split /,\s*/, $val;
        # convert filter name
        delete $$conv{OTHER}; # avoid recursion
        $v = Image::ExifTool::ReverseLookup(shift(@vals), $conv);
        $$conv{OTHER} = \&PrintFilter;
        return undef unless defined $v;
        push @cval, $v;
        # generate a lookup table for the filter setting name
        my %settingNames;
        $settingNames{$_} = $filterSettings{$_}[0] foreach keys %filterSettings;
        # convert filter settings
        foreach $v (@vals) {
            $v =~ /^(.*)=(.*)$/ or return undef;
            ($t, $v) = ($1, $2);
            # look up settings name
            $t = Image::ExifTool::ReverseLookup($t, \%settingNames);
            return undef unless defined $t;
            if (ref $filterSettings{$t}[1]) {
                # look up settings value
                $v = Image::ExifTool::ReverseLookup($v, $filterSettings{$t}[1]);
                return undef unless defined $v;
            } else {
                return undef unless Image::ExifTool::IsInt($v);
            }
            push @cval, $t, $v;
        }
        push @cval, (0) x (17 - @cval) if @cval < 17; # pad with zeros if necessary
        return join(' ', @cval);
    }
}

#------------------------------------------------------------------------------
# Convert Pentax hex-based EV (modulo 8) to real number
# Inputs: 0) value to convert
# eg) 0x00 -> 0
#     0x03 -> 0.33333
#     0x04 -> 0.5
#     0x05 -> 0.66666
#     0x08 -> 1   ...  etc
sub PentaxEv($)
{
    my $val = shift;
    if ($val & 0x01) {
        my $sign = $val < 0 ? -1 : 1;
        my $frac = ($val * $sign) & 0x07;
        if ($frac == 0x03) {
            $val += $sign * ( 8 / 3 - $frac);
        } elsif ($frac == 0x05) {
            $val += $sign * (16 / 3 - $frac);
        }
    }
    return $val / 8;
}

#------------------------------------------------------------------------------
# Convert number to Pentax hex-based EV (modulo 8)
# Inputs: 0) number
# Returns: Pentax EV code
sub PentaxEvInv($)
{
    my $num = shift;
    my $val = $num * 8;
    # extra fudging makes sure 0.3 and 0.33333 both round up to 3, etc
    my $sign = $num < 0 ? -1 : 1;
    my $inum = $num * $sign - int($num * $sign);
    if ($inum > 0.29 and $inum < 0.4) {
        $val += $sign / 3;
    } elsif ($inum > 0.6 and $inum < .71) {
        $val -= $sign / 3;
    }
    return int($val + 0.5 * $sign);
}

#------------------------------------------------------------------------------
# Encrypt or decrypt Pentax ShutterCount (symmetrical encryption) - PH
# Inputs: 0) shutter count value, 1) ExifTool object ref
# Returns: Encrypted or decrypted ShutterCount
sub CryptShutterCount($$)
{
    my ($val, $et) = @_;
    # Pentax Date and Time values are used in the encryption
    return undef unless $$et{PentaxDate} and $$et{PentaxTime} and
        length($$et{PentaxDate})==4 and length($$et{PentaxTime})>=3;
    # get Date and Time as integers (after padding Time with a null byte)
    my $date = unpack('N', $$et{PentaxDate});
    my $time = unpack('N', $$et{PentaxTime} . "\0");
    return $val ^ $date ^ (0xffffffff - $time);
}


1; # end

__END__

=head1 NAME

Image::ExifTool::Pentax - Pentax/Asahi maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Pentax and Asahi maker notes in EXIF information.

=head1 NOTES

I couldn't find a good source for Pentax maker notes information, but I've
managed to discover a fair bit of information by analyzing sample images
downloaded from the internet, and through tests with my own Optio WP,
K10D, and K-5, and with help provided by other ExifTool users (see
L</ACKNOWLEDGEMENTS>).

The Pentax maker notes are stored in standard EXIF format, but the offsets
used for some of their cameras are wacky.  The Optio 330 gives the offset
relative to the offset of the tag in the directory, the Optio WP uses a base
offset in the middle of nowhere, and the Optio 550 uses different (and
totally illogical) bases for different menu entries.  Very weird.  (It
wouldn't surprise me if Pentax can't read their own maker notes!)  Luckily,
there are only a few entries in the maker notes which are large enough to
require offsets, so this doesn't affect much useful information.  ExifTool
attempts to make sense of this fiasco by making an assumption about where
the information should be stored to deduce the correct offsets.

=head1 REFERENCES

=over 4

=item L<Image::MakerNotes::Pentax|Image::MakerNotes::Pentax>

=item L<http://johnst.org/sw/exiftags/> (Asahi models)

=item L<http://kobe1995.jp/~kaz/astro/istD.html>

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item (...plus lots of testing with my Optio WP, K10D and K-5!)

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Wayne Smith, John Francis, Douglas O'Brien Cvetan Ivanov, Jens
Duttke and Dave Nicholson for help figuring out some Pentax tags, Ger
Vermeulen and Niels Kristian Bech Jensen for contributing print conversion
values for some tags, and everyone who helped contribute to the LensType
values.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Pentax Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::Info(3pm)|Image::Info>

=cut
